"""
ingest.py — RAG ingestion pipeline for agricultural knowledge base.

Reads data.md → Markdown-aware semantic chunking → local embeddings → ChromaDB persistent store.
"""

import re
import sys
import hashlib
import os
from pathlib import Path
from typing import List, Dict, Any

# ──────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ──────────────────────────────────────────────────────────────────────────────

DATA_FILE        = Path(__file__).parent / "data.md"
CHROMA_DIR       = Path(__file__).parent / "chroma_db"
COLLECTION_NAME  = "agri_knowledge"

# Embedding model — strong, lightweight, no API key needed
EMBEDDING_MODEL  = "sentence-transformers/all-mpnet-base-v2"

# Chunking parameters (in approximate words; 1 token ≈ 0.75 words)
# data.md sections are mostly 150–300 words; target ~750 words per chunk
# (≈ 1000 tokens) so we group 3–5 small sections together
CHUNK_MAX_WORDS  = 750   # hard ceiling per chunk
CHUNK_OVERLAP_W  = 140   # overlap carried into next chunk (~180 tokens)
MIN_SECTION_WORDS = 5    # skip near-empty sections (part headings)


# ──────────────────────────────────────────────────────────────────────────────
# MARKDOWN PARSER
# ──────────────────────────────────────────────────────────────────────────────

def parse_markdown_sections(text: str) -> List[Dict[str, Any]]:
    """
    Split data.md into individual heading-content pairs.
    Returns list of dicts with keys: level, heading, content, full_text.
    """
    # Split on any heading line (# through ###)
    heading_pattern = re.compile(r'^(#{1,3})\s+(.+)$', re.MULTILINE)
    
    sections = []
    matches = list(heading_pattern.finditer(text))
    
    # Preamble before first heading (if any)
    if matches and matches[0].start() > 0:
        preamble = text[:matches[0].start()].strip()
        if preamble:
            sections.append({
                'level': 1,
                'heading': 'Introduction and Purpose',
                'content': preamble,
                'full_text': preamble,
            })
    
    for i, match in enumerate(matches):
        level = len(match.group(1))
        heading = match.group(2).strip()
        start = match.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        content = text[start:end].strip()
        full_text = f"{match.group(0)}\n\n{content}" if content else match.group(0)
        
        sections.append({
            'level': level,
            'heading': heading,
            'content': content,
            'full_text': full_text,
        })
    
    return sections


# ──────────────────────────────────────────────────────────────────────────────
# SEMANTIC CHUNKER
# ──────────────────────────────────────────────────────────────────────────────

def word_count(text: str) -> int:
    return len(text.split())


def make_chunks(sections: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Group sections into semantic chunks:
    - H1 sections (Part headings) act as context labels, not chunk boundaries by themselves.
    - H2/H3 sections are the content units.
    - Group consecutive H2 sections until CHUNK_MAX_WORDS is reached.
    - If a single H2 section exceeds CHUNK_MAX_WORDS, split it on paragraph boundaries.
    - Carry CHUNK_OVERLAP_W words of overlap into the next chunk.
    """
    chunks = []
    chunk_id = 0

    current_part = "Agricultural Knowledge Base"
    current_part_num = ""
    
    # Collect only content sections (H2/H3 + preamble)
    content_sections = []
    for sec in sections:
        if sec['level'] == 1:
            # Extract part number if present
            m = re.search(r'Part\s+(\d+)', sec['heading'])
            current_part = sec['heading']
            current_part_num = f"Part {m.group(1)}" if m else sec['heading']
            # Level-1 headings are tiny title-only entries — skip if near-empty
            if word_count(sec['content']) >= MIN_SECTION_WORDS:
                content_sections.append({**sec, 'part': current_part_num})
        else:
            content_sections.append({**sec, 'part': current_part_num})

    # Now group H2/H3 sections into chunks
    i = 0
    overlap_text = ""  # trailing text carried forward as overlap

    while i < len(content_sections):
        sec = content_sections[i]
        wc = word_count(sec['full_text'])

        # ── Single oversized section → split on paragraph boundaries ─────────
        if wc > CHUNK_MAX_WORDS:
            paragraphs = re.split(r'\n{2,}', sec['content'])
            heading_line = f"## {sec['heading']}\n\n"
            
            buf = heading_line + (overlap_text + "\n\n" if overlap_text else "")
            prev_para = ""
            
            for para in paragraphs:
                para = para.strip()
                if not para:
                    continue
                candidate = buf + para
                if word_count(candidate) <= CHUNK_MAX_WORDS:
                    buf += para + "\n\n"
                    prev_para = para
                else:
                    # Flush current buffer
                    if buf.strip() and word_count(buf.strip()) >= MIN_SECTION_WORDS:
                        chunks.append({
                            'text': buf.strip(),
                            'metadata': {
                                'source': 'data.md',
                                'document': 'agricultural_knowledge',
                                'section': sec['heading'],
                                'part': sec.get('part', ''),
                                'chunk_id': f"chunk_{chunk_id:04d}",
                            }
                        })
                        chunk_id += 1
                        # Overlap: carry last ~CHUNK_OVERLAP_W words
                        all_words = buf.split()
                        overlap_text = " ".join(all_words[-CHUNK_OVERLAP_W:])
                        buf = heading_line + overlap_text + "\n\n" + para + "\n\n"
                    else:
                        buf += para + "\n\n"
                    prev_para = para
            
            # Flush remainder
            if buf.strip() and word_count(buf.strip()) >= MIN_SECTION_WORDS:
                chunks.append({
                    'text': buf.strip(),
                    'metadata': {
                        'source': 'data.md',
                        'document': 'agricultural_knowledge',
                        'section': sec['heading'],
                        'part': sec.get('part', ''),
                        'chunk_id': f"chunk_{chunk_id:04d}",
                    }
                })
                all_words = buf.split()
                overlap_text = " ".join(all_words[-CHUNK_OVERLAP_W:])
                chunk_id += 1
            
            i += 1
            continue

        # ── Accumulate small/medium sections into one chunk ───────────────────
        # Start a new accumulator with optional overlap from previous chunk
        acc_text = ""
        acc_sections = []
        acc_parts = set()

        if overlap_text:
            acc_text = f"[...continued...]\n{overlap_text}\n\n"

        while i < len(content_sections):
            sec = content_sections[i]
            candidate = acc_text + sec['full_text']
            
            if acc_sections and word_count(candidate) > CHUNK_MAX_WORDS:
                # Adding this section would exceed limit → flush first
                break
            
            acc_text += sec['full_text'] + "\n\n"
            acc_sections.append(sec['heading'])
            acc_parts.add(sec.get('part', ''))
            i += 1

            # If we've accumulated enough, flush
            if word_count(acc_text) >= CHUNK_MAX_WORDS * 0.7:
                break
        
        if not acc_sections:
            i += 1
            continue

        # Determine best section label
        primary_section = acc_sections[0] if len(acc_sections) == 1 else \
            f"{acc_sections[0]} + {len(acc_sections)-1} more"
        part_label = next(iter(acc_parts)) if len(acc_parts) == 1 else ", ".join(sorted(acc_parts))
        
        chunk_text = acc_text.strip()
        if word_count(chunk_text) >= MIN_SECTION_WORDS:
            chunks.append({
                'text': chunk_text,
                'metadata': {
                    'source': 'data.md',
                    'document': 'agricultural_knowledge',
                    'section': primary_section,
                    'part': part_label,
                    'chunk_id': f"chunk_{chunk_id:04d}",
                }
            })
            all_words = chunk_text.split()
            overlap_text = " ".join(all_words[-CHUNK_OVERLAP_W:])
            chunk_id += 1

    return chunks


# ──────────────────────────────────────────────────────────────────────────────
# DETERMINISTIC ID
# ──────────────────────────────────────────────────────────────────────────────

def make_doc_id(chunk: Dict[str, Any]) -> str:
    """Deterministic SHA256-based ID from chunk text."""
    content = chunk['text']
    return "doc_" + hashlib.sha256(content.encode('utf-8')).hexdigest()[:16]


# ──────────────────────────────────────────────────────────────────────────────
# MAIN INGESTION
# ──────────────────────────────────────────────────────────────────────────────

def ingest():
    print("=" * 60)
    print("  AGRICULTURAL RAG — INGESTION PIPELINE")
    print("=" * 60)
    print(f"\nSource file       : {DATA_FILE}")
    print(f"Embedding model   : {EMBEDDING_MODEL}")
    print(f"ChromaDB dir      : {CHROMA_DIR}")
    print(f"Collection        : {COLLECTION_NAME}")
    print(f"Chunk max words   : {CHUNK_MAX_WORDS}  (~{int(CHUNK_MAX_WORDS/0.75)} tokens)")
    print(f"Chunk overlap     : {CHUNK_OVERLAP_W} words  (~{int(CHUNK_OVERLAP_W/0.75)} tokens)")
    print()

    # ── 1. Read data.md ───────────────────────────────────────────────────────
    print("Step 1/5: Reading data.md...")
    with open(DATA_FILE, 'r', encoding='utf-8') as f:
        raw_text = f.read()
    print(f"  Loaded {len(raw_text):,} characters, {word_count(raw_text):,} words")

    # ── 2. Parse Markdown ─────────────────────────────────────────────────────
    print("\nStep 2/5: Parsing Markdown structure...")
    sections = parse_markdown_sections(raw_text)
    h1 = [s for s in sections if s['level'] == 1]
    h2 = [s for s in sections if s['level'] == 2]
    h3 = [s for s in sections if s['level'] == 3]
    print(f"  Detected {len(sections)} total headings")
    print(f"  H1 (parts)    : {len(h1)}")
    print(f"  H2 (sections) : {len(h2)}")
    print(f"  H3 (subsec.)  : {len(h3)}")
    
    # Show detected H1 parts
    print("\n  Parts detected:")
    for s in h1:
        print(f"    - {s['heading']}")

    # ── 3. Chunk ──────────────────────────────────────────────────────────────
    print("\nStep 3/5: Generating semantic chunks...")
    chunks = make_chunks(sections)
    print(f"  Total chunks   : {len(chunks)}")
    
    wcs = [word_count(c['text']) for c in chunks]
    print(f"  Min chunk size : {min(wcs)} words")
    print(f"  Max chunk size : {max(wcs)} words")
    print(f"  Mean chunk size: {sum(wcs)//len(wcs)} words")
    
    print("\n  Sample chunk sizes:")
    for i, (c, wc_) in enumerate(zip(chunks[:5], wcs[:5])):
        print(f"    chunk_{i:04d}: [{wc_:4d}w] {c['metadata']['section'][:55]}")

    # ── 4. Load embedding model ───────────────────────────────────────────────
    print(f"\nStep 4/5: Loading embedding model: {EMBEDDING_MODEL}")
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer(EMBEDDING_MODEL)
    embed_dim = model.get_embedding_dimension()
    print(f"  Model loaded. Embedding dimension: {embed_dim}")

    # ── 5. Store in ChromaDB ──────────────────────────────────────────────────
    print(f"\nStep 5/5: Storing chunks in ChromaDB (persistent)...")
    import chromadb
    
    CHROMA_DIR.mkdir(parents=True, exist_ok=True)
    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    
    # Get or create collection
    collection = client.get_or_create_collection(
        name=COLLECTION_NAME,
        metadata={"hnsw:space": "cosine"}
    )

    # Prepare documents
    doc_ids   = [make_doc_id(c) for c in chunks]
    doc_texts = [c['text'] for c in chunks]
    doc_metas = [c['metadata'] for c in chunks]

    # Check existing IDs to avoid duplication
    existing = set()
    try:
        existing_data = collection.get(ids=doc_ids, include=[])
        existing = set(existing_data['ids'])
    except Exception:
        pass

    new_ids   = [d for d in doc_ids   if d not in existing]
    new_texts = [t for d, t in zip(doc_ids, doc_texts) if d not in existing]
    new_metas = [m for d, m in zip(doc_ids, doc_metas) if d not in existing]

    if not new_ids:
        print(f"  ✓ All {len(doc_ids)} chunks already exist — no duplicates added.")
    else:
        print(f"  Embedding {len(new_ids)} new chunks...")
        from tqdm import tqdm
        
        BATCH = 64
        for start in tqdm(range(0, len(new_ids), BATCH), desc="  Embedding"):
            batch_ids   = new_ids[start:start+BATCH]
            batch_texts = new_texts[start:start+BATCH]
            batch_metas = new_metas[start:start+BATCH]
            
            embeddings = model.encode(
                batch_texts,
                show_progress_bar=False,
                convert_to_numpy=True,
                normalize_embeddings=True,
            ).tolist()
            
            collection.upsert(
                ids=batch_ids,
                documents=batch_texts,
                metadatas=batch_metas,
                embeddings=embeddings,
            )
        
        print(f"  ✓ Added {len(new_ids)} new chunks.")

    final_count = collection.count()
    print(f"  ✓ Final document count in collection: {final_count}")

    print("\n" + "=" * 60)
    print("  INGESTION COMPLETE")
    print("=" * 60)
    print(f"\n  ChromaDB path : {CHROMA_DIR.resolve()}")
    print(f"  Collection    : {COLLECTION_NAME}")
    print(f"  Total docs    : {final_count}")
    embed_dim = model.get_embedding_dimension() if hasattr(model, 'get_embedding_dimension') else model.get_sentence_embedding_dimension()
    print(f"  Embedding dim : {embed_dim}")
    print()


if __name__ == "__main__":
    ingest()
