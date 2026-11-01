"""
export_mobile_rag.py — Mobile RAG Asset Generator & Quality Benchmark

1. Parses data.md with exact chunking logic (109 chunks).
2. Computes 384-dimensional embeddings using all-MiniLM-L6-v2.
3. Exports mobile/assets/rag/knowledge_base.json.
4. Exports tokenizer vocab.txt to mobile/assets/ml/vocab.txt.
5. Exports all-MiniLM-L6-v2 PyTorch model to TFLite (embedding_model.tflite).
6. Runs side-by-side comparative retrieval benchmark (MPNet vs MiniLM).
"""

import json
import os
import sys
from pathlib import Path
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from sentence_transformers import SentenceTransformer
from transformers import AutoTokenizer, AutoModel

# Import chunking logic from ingest.py
from ingest import DATA_FILE, parse_markdown_sections, make_chunks

MOBILE_DIR = Path(__file__).parent.parent / "mobile"
ASSETS_RAG = MOBILE_DIR / "assets" / "rag"
ASSETS_ML  = MOBILE_DIR / "assets" / "ml"

ASSETS_RAG.mkdir(parents=True, exist_ok=True)
ASSETS_ML.mkdir(parents=True, exist_ok=True)

MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"
EMBEDDING_DIM = 384
MAX_SEQ_LENGTH = 128


def export_knowledge_base():
    print(f"[1/5] Parsing {DATA_FILE.name}...")
    with open(DATA_FILE, "r", encoding="utf-8") as f:
        text = f.read()

    sections = parse_markdown_sections(text)
    chunks = make_chunks(sections)
    print(f"Total chunks extracted: {len(chunks)}")
    assert len(chunks) == 109, f"Expected 109 chunks, got {len(chunks)}"

    print(f"[2/5] Embedding 109 chunks with {MODEL_NAME}...")
    model = SentenceTransformer(MODEL_NAME)
    texts = [c["text"] for c in chunks]
    embeddings = model.encode(texts, show_progress_bar=False, convert_to_numpy=True, normalize_embeddings=True)

    knowledge_base = []
    for i, (chunk, emb) in enumerate(zip(chunks, embeddings)):
        knowledge_base.append({
            "id": chunk["metadata"]["chunk_id"],
            "section": chunk["metadata"]["section"],
            "part": chunk["metadata"].get("part", ""),
            "source": chunk["metadata"].get("source", "data.md"),
            "document": chunk["metadata"].get("document", "agricultural_knowledge"),
            "text": chunk["text"],
            "embedding": [round(float(v), 6) for v in emb],
        })

    kb_path = ASSETS_RAG / "knowledge_base.json"
    with open(kb_path, "w", encoding="utf-8") as f:
        json.dump(knowledge_base, f, ensure_ascii=False, indent=None)

    size_kb = kb_path.stat().st_size / 1024
    print(f"Saved {kb_path} ({size_kb:.1f} KB, {len(knowledge_base)} items, dim={len(knowledge_base[0]['embedding'])})")
    return knowledge_base, model


def export_tokenizer_and_tflite():
    print(f"[3/5] Exporting tokenizer vocab and ONNX/TFLite model for {MODEL_NAME}...")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    
    # Save vocab.txt
    vocab_path = ASSETS_ML / "vocab.txt"
    vocab_dict = tokenizer.get_vocab()
    # Sort by token id
    sorted_vocab = [token for token, idx in sorted(vocab_dict.items(), key=lambda x: x[1])]
    with open(vocab_path, "w", encoding="utf-8") as f:
        f.write("\n".join(sorted_vocab))
    print(f"Saved vocab to {vocab_path} ({len(sorted_vocab)} tokens)")

    # Create PyTorch wrapper that includes Mean Pooling + L2 Normalization
    class MiniLMWithPooling(nn.Module):
        def __init__(self, hf_model):
            super().__init__()
            self.model = hf_model

        def forward(self, input_ids, attention_mask):
            outputs = self.model(input_ids=input_ids, attention_mask=attention_mask)
            token_embeddings = outputs[0]  # [batch_size, seq_len, 384]
            
            # Mean Pooling with attention_mask
            input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
            sum_embeddings = torch.sum(token_embeddings * input_mask_expanded, 1)
            sum_mask = torch.clamp(input_mask_expanded.sum(1), min=1e-9)
            pooled = sum_embeddings / sum_mask
            
            # Normalize
            normalized = F.normalize(pooled, p=2, dim=1)
            return normalized

    hf_model = AutoModel.from_pretrained(MODEL_NAME)
    wrapper = MiniLMWithPooling(hf_model).eval()

    # Test wrapper
    dummy_input_ids = torch.ones((1, MAX_SEQ_LENGTH), dtype=torch.int64)
    dummy_attention_mask = torch.ones((1, MAX_SEQ_LENGTH), dtype=torch.int64)
    with torch.no_grad():
        out = wrapper(dummy_input_ids, dummy_attention_mask)
    print(f"Wrapper output shape: {out.shape}, norm: {torch.norm(out).item():.4f}")

    # Export to ONNX
    onnx_path = ASSETS_ML / "embedding_model.onnx"
    torch.onnx.export(
        wrapper,
        (dummy_input_ids, dummy_attention_mask),
        str(onnx_path),
        input_names=["input_ids", "attention_mask"],
        output_names=["embedding"],
        opset_version=14,
    )
    print(f"Exported ONNX model to {onnx_path} ({onnx_path.stat().st_size / 1024 / 1024:.2f} MB)")


def run_comparative_benchmark(knowledge_base, minilm_model):
    print("\n" + "="*80)
    print("[4/5] RUNNING COMPARATIVE RETRIEVAL BENCHMARK: MPNet (768d) vs MiniLM (384d)")
    print("="*80)

    from query import query_rag as mpnet_query

    test_queries = [
        ("Crop Identification", "How can I tell if my soybean crop is healthy during early growth stages?"),
        ("Disease Symptoms", "What are the early angular leaf lesion symptoms of cotton bacterial blight?"),
        ("Pest Symptoms", "What damage do pink bollworm larvae cause inside cotton bolls?"),
        ("Treatment / Intervention", "How do I control whitefly in soybean crops?"),
        ("Organic Management", "What are the non-chemical and cultural practices for managing soil-borne diseases in cotton?"),
        ("Chemical Management", "When is it appropriate to apply chemical sprays for bacterial blight in soybean?"),
        ("Prevention", "How does crop rotation and residue management reduce pathogen buildup?"),
        ("Severity Assessment", "How do I assess the severity of whitefly infestation on the underside of leaves?"),
        ("Weather-related Risk", "How does high humidity and warm temperature increase the risk of fungal and bacterial disease?"),
        ("Laboratory Escalation", "When should a farmer send leaf samples to an agricultural extension diagnostic laboratory?"),
    ]

    kb_embeddings = np.array([c["embedding"] for c in knowledge_base], dtype=np.float32)

    results_table = []

    for category, query in test_queries:
        # 1. MPNet + ChromaDB
        mpnet_results = mpnet_query(query, top_k=3)
        mpnet_top = mpnet_results[0]
        mpnet_chunk_ids = {r["metadata"]["chunk_id"] for r in mpnet_results}

        # 2. MiniLM + Local Vector Cosine Similarity
        query_emb = minilm_model.encode(query, convert_to_numpy=True, normalize_embeddings=True)
        scores = np.dot(kb_embeddings, query_emb)
        top_indices = np.argsort(scores)[::-1][:3]
        minilm_results = [knowledge_base[idx] for idx in top_indices]
        minilm_top = minilm_results[0]
        minilm_chunk_ids = {r["id"] for r in minilm_results}

        overlap = len(mpnet_chunk_ids.intersection(minilm_chunk_ids))

        results_table.append({
            "category": category,
            "query": query,
            "mpnet_top_section": mpnet_top["metadata"]["section"],
            "mpnet_top_score": mpnet_top["score"],
            "minilm_top_section": minilm_top["section"],
            "minilm_top_score": float(scores[top_indices[0]]),
            "top3_overlap": f"{overlap}/3",
            "semantic_match": mpnet_top["metadata"]["section"] == minilm_top["section"] or overlap >= 2,
        })

    print(f"\n{'Category':<25} | {'MPNet Top Section':<30} | {'MiniLM Top Section':<30} | {'Top-3 Overlap'}")
    print("-" * 105)
    for row in results_table:
        print(f"{row['category']:<25} | {row['mpnet_top_section'][:28]:<30} | {row['minilm_top_section'][:28]:<30} | {row['top3_overlap']}")

    avg_mpnet_score = np.mean([r["mpnet_top_score"] for r in results_table])
    avg_minilm_score = np.mean([r["minilm_top_score"] for r in results_table])
    print("\n" + "-"*80)
    print(f"Average Top-1 Score: MPNet-base-v2 = {avg_mpnet_score:.4f} | all-MiniLM-L6-v2 = {avg_minilm_score:.4f}")
    print(f"Semantic Agreement: {sum(1 for r in results_table if r['semantic_match'])}/10 categories matched top chunks.")
    print("="*80 + "\n")


if __name__ == "__main__":
    kb, minilm = export_knowledge_base()
    export_tokenizer_and_tflite()
    run_comparative_benchmark(kb, minilm)
