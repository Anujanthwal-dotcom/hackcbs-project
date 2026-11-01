"""
test_query.py — Manual retrieval quality evaluation for the agricultural RAG.

Covers:
  - simple identification questions
  - symptom questions
  - management questions
  - severity questions
  - organic/cultural management
  - escalation / laboratory questions
  - weather-related questions
  - unknown/uncertain conditions
"""

from query import query_rag

# ──────────────────────────────────────────────────────────────────────────────
# TEST QUESTIONS
# ──────────────────────────────────────────────────────────────────────────────

TEST_QUESTIONS = [
    # 1. Simple identification
    "What are the signs of soybean bacterial blight?",

    # 2. Symptom question (farmer language)
    "My soybean leaves have small insects underneath and the leaves are getting damaged. What should I do?",

    # 3. Cotton pest symptom
    "I see small holes in my cotton bolls and some pink caterpillars inside. What is this?",

    # 4. Management question
    "How do I manage whitefly on my soybean crop?",

    # 5. Severity / should I spray?
    "A few plants in my field have bacterial blight symptoms. Is this serious? Should I spray?",

    # 6. Organic / no chemicals
    "What can I do for soybean pests without using any chemical pesticides?",

    # 7. Escalation / when to call expert
    "My cotton crop has been treated twice but the disease keeps spreading. What should I do now?",

    # 8. Laboratory / confirmation
    "When should I send a sample to a laboratory for crop disease testing?",

    # 9. Weather-related
    "It rained heavily for three days. Should I be worried about disease spreading in my soybean field?",

    # 10. Nutrition / non-disease
    "Some of my soybean leaves are turning yellow but I don't see any insects or spots. What could be causing this?",

    # 11. Unknown condition / uncertainty
    "The ML model gave me a result but I don't think it looks right. The plant doesn't match the description.",

    # 12. Monitoring after treatment
    "I sprayed my field last week. How do I know if the treatment is working?",
]

TOP_K = 3  # return 3 results per query for readability

# ──────────────────────────────────────────────────────────────────────────────
# RUNNER
# ──────────────────────────────────────────────────────────────────────────────

def run_tests():
    print("=" * 70)
    print("  AGRICULTURAL RAG — RETRIEVAL QUALITY TEST")
    print("=" * 70)
    print(f"  Queries : {len(TEST_QUESTIONS)}")
    print(f"  Top-K   : {TOP_K} results per query")
    print("=" * 70)

    for qi, question in enumerate(TEST_QUESTIONS, 1):
        print(f"\n{'═'*70}")
        print(f"  QUERY {qi}/{len(TEST_QUESTIONS)}")
        print(f"{'═'*70}")
        print(f"\n  {question}\n")

        results = query_rag(question, top_k=TOP_K)

        for ri, r in enumerate(results, 1):
            print(f"  ── RESULT {ri} {'─'*55}")
            print(f"    Section  : {r['metadata'].get('section', 'N/A')}")
            print(f"    Part     : {r['metadata'].get('part', 'N/A')}")
            print(f"    Score    : {r['score']:.4f}  (distance: {r['distance']:.4f})")
            print(f"    Chunk ID : {r['metadata'].get('chunk_id', 'N/A')}")
            print()
            # Preview first 500 chars of retrieved text
            preview = r['text'][:500].strip().replace('\n', '\n    ')
            print(f"    {preview}")
            if len(r['text']) > 500:
                print(f"    ... [{len(r['text'])-500} more chars]")
            print()

    print("=" * 70)
    print("  TEST COMPLETE")
    print("=" * 70)


if __name__ == "__main__":
    run_tests()
