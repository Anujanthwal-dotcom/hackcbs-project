"""
query.py — RAG retrieval layer for the agricultural knowledge base.

Exposes: query_rag(query: str, top_k: int = 5) -> list[dict]

Each returned dict contains:
  - text     : retrieved chunk text
  - metadata : source, section, part, chunk_id, document
  - distance : cosine distance (lower = more similar)
  - score    : 1 - distance  (higher = more relevant, 0–1)
"""

from pathlib import Path
from typing import List, Dict, Any

# ── Configuration (must match ingest.py) ──────────────────────────────────────
CHROMA_DIR       = Path(__file__).parent / "chroma_db"
COLLECTION_NAME  = "agri_knowledge"
EMBEDDING_MODEL  = "sentence-transformers/all-mpnet-base-v2"

# ── Module-level singletons (lazy-loaded on first call) ───────────────────────
_model      = None
_collection = None


def _load():
    """Lazy-load the embedding model and ChromaDB collection once."""
    global _model, _collection

    if _model is None:
        from sentence_transformers import SentenceTransformer
        _model = SentenceTransformer(EMBEDDING_MODEL)

    if _collection is None:
        import chromadb
        if not CHROMA_DIR.exists():
            raise FileNotFoundError(
                f"ChromaDB not found at {CHROMA_DIR}. "
                "Run  python ingest.py  first."
            )
        client = chromadb.PersistentClient(path=str(CHROMA_DIR))
        _collection = client.get_collection(name=COLLECTION_NAME)


def query_rag(query: str, top_k: int = 5) -> List[Dict[str, Any]]:
    """
    Retrieve the most semantically relevant chunks for a farmer's question.

    Parameters
    ----------
    query  : Natural-language question from a farmer or the calling system.
    top_k  : Number of results to return (default 5).

    Returns
    -------
    List of dicts, ordered by relevance (most relevant first):
        {
            "text"     : str,
            "metadata" : dict  (source, document, section, part, chunk_id),
            "distance" : float (cosine distance; lower = more similar),
            "score"    : float (1 - distance; higher = more relevant),
        }
    """
    _load()

    # Embed the query using the same model used during ingestion
    query_embedding = _model.encode(
        query,
        show_progress_bar=False,
        convert_to_numpy=True,
        normalize_embeddings=True,
    ).tolist()

    # Search ChromaDB
    results = _collection.query(
        query_embeddings=[query_embedding],
        n_results=top_k,
        include=["documents", "metadatas", "distances"],
    )

    # Unpack and structure results
    output = []
    docs      = results["documents"][0]
    metadatas = results["metadatas"][0]
    distances = results["distances"][0]

    for doc, meta, dist in zip(docs, metadatas, distances):
        output.append({
            "text"    : doc,
            "metadata": meta,
            "distance": round(float(dist), 6),
            "score"   : round(1.0 - float(dist), 6),
        })

    return output


# ── CLI convenience ────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import sys

    q = " ".join(sys.argv[1:]).strip()
    if not q:
        q = "What should I do if my soybean leaves have spots?"

    print(f"\nQUERY: {q}\n")
    results = query_rag(q)

    for i, r in enumerate(results, 1):
        print(f"── RESULT {i} {'─'*50}")
        print(f"  Section  : {r['metadata'].get('section','')}")
        print(f"  Part     : {r['metadata'].get('part','')}")
        print(f"  Score    : {r['score']:.4f}  (distance: {r['distance']:.4f})")
        print(f"  Chunk ID : {r['metadata'].get('chunk_id','')}")
        print()
        # Print first 600 chars
        preview = r['text'][:600].replace('\n', '\n  ')
        print(f"  {preview}{'...' if len(r['text']) > 600 else ''}")
        print()
