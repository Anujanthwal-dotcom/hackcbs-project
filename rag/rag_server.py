"""
rag_server.py — FastAPI HTTP wrapper around the existing RAG retrieval pipeline.

Exposes:
  POST /query  {"query": str, "top_k": int = 5}  → retrieved agricultural chunks
  GET  /health                                    → server status + doc count

Usage:
  pip install fastapi uvicorn
  uvicorn rag_server:app --host 0.0.0.0 --port 5050

Flutter Android emulator calls: http://10.0.2.2:5050
Flutter physical device calls:  http://<YOUR_LAN_IP>:5050
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional
import logging

# Import the existing RAG query function — no duplication
from query import query_rag, COLLECTION_NAME, CHROMA_DIR, EMBEDDING_MODEL

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("rag_server")

app = FastAPI(
    title="Krishi AI — RAG Retrieval Server",
    description="Agricultural knowledge retrieval for Krishi AI mobile app",
    version="1.0.0",
)

# Allow Flutter app to call from any origin during development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Request / Response models ────────────────────────────────────────────────

class QueryRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=1000, description="Farmer's natural-language question")
    top_k: int = Field(default=5, ge=1, le=10, description="Number of chunks to retrieve")


class ChunkResult(BaseModel):
    text: str
    section: str
    part: str
    chunk_id: str
    source: str
    score: float
    distance: float


class QueryResponse(BaseModel):
    query: str
    results: List[ChunkResult]
    total: int


class HealthResponse(BaseModel):
    status: str
    collection: str
    collection_docs: int
    embedding_model: str
    chroma_dir: str


# ── Endpoints ────────────────────────────────────────────────────────────────

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Check server status and ChromaDB collection size."""
    try:
        import chromadb
        client = chromadb.PersistentClient(path=str(CHROMA_DIR))
        collection = client.get_collection(name=COLLECTION_NAME)
        doc_count = collection.count()
        return HealthResponse(
            status="ok",
            collection=COLLECTION_NAME,
            collection_docs=doc_count,
            embedding_model=EMBEDDING_MODEL,
            chroma_dir=str(CHROMA_DIR.resolve()),
        )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=503, detail=f"RAG system unavailable: {e}")


@app.post("/query", response_model=QueryResponse)
async def retrieve(request: QueryRequest):
    """
    Retrieve the most semantically relevant agricultural knowledge chunks.
    
    Called by the Flutter AssistantService when building LLM context.
    """
    try:
        logger.info(f"Query: {request.query[:80]!r} (top_k={request.top_k})")
        raw_results = query_rag(request.query, top_k=request.top_k)

        chunks = [
            ChunkResult(
                text=r["text"],
                section=r["metadata"].get("section", ""),
                part=r["metadata"].get("part", ""),
                chunk_id=r["metadata"].get("chunk_id", ""),
                source=r["metadata"].get("source", "data.md"),
                score=r["score"],
                distance=r["distance"],
            )
            for r in raw_results
        ]

        logger.info(f"Returning {len(chunks)} chunks. Top score: {chunks[0].score:.4f}" if chunks else "No results.")
        return QueryResponse(query=request.query, results=chunks, total=len(chunks))

    except Exception as e:
        logger.error(f"Query failed: {e}")
        raise HTTPException(status_code=500, detail=f"Retrieval error: {e}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5050, log_level="info")
