"""
eval_retrieval.py — retrieval-only benchmark (no LLM, runs in seconds).

For each query we know which source file MUST appear in the top TOP_K
results for the device to have any chance of answering correctly.
Reports hit@k per query and overall. Run from the project root:

    PYTHONPATH=scripts venv/bin/python scripts/eval_retrieval.py

Built for issue #4 (query-phrasing sensitivity). Run before and after
any retrieval change; paste both scores into the BUILD_LOG entry.
"""

from sentence_transformers import SentenceTransformer

from main import load_index, retrieve, TOP_K

# (query, source file that must appear in top TOP_K)
CASES = [
    # The 10-question battery's implied retrieval targets
    ("How do I start a fire when all the wood around me is wet?", "fm21-76-survival-manual.txt"),
    ("How can I make dirty water from a river safe to drink?", "fm21-76-survival-manual.txt"),
    ("What kind of shelter should I build to stay warm in a cold forest?", "fm21-76-survival-manual.txt"),
    ("How can I tell if a wild plant is safe to eat?", "fm21-76-survival-manual.txt"),
    ("How should I clean and cover a deep cut so it does not get infected?", "where-there-is-no-doctor.pdf"),
    ("How do I take out a tooth that is badly infected?", "where-there-is-no-dentist.pdf"),
    ("How deep should I plant large seeds like beans compared to small seeds?", "first-book-of-farming-1905.txt"),
    # issue #4 case — expected source upgraded to Woodworth 1903 once it
    # was added to the corpus (the 1889 book has no blade-hardening how-to)
    ("How do I harden the edge of a knife I forged so it stays sharp?", "hardening-tempering-steel-1903.txt"),
    ("What is the correct dose of aspirin for an adult with fever?", "where-there-is-no-doctor.pdf"),
    # Phrasing variants and additional single-source topics
    ("how to temper a steel blade after forging it", "hardening-tempering-steel-1903.txt"),
    ("how do I weld two pieces of iron together in a forge", "practical-blacksmithing-1889.txt"),
    ("my tooth hurts and my gums are swollen, what do I do", "where-there-is-no-dentist.pdf"),
    ("when should seedlings be moved from the seed bed to the field", "first-book-of-farming-1905.txt"),
    ("what should the soil be like before sowing seeds", "first-book-of-farming-1905.txt"),
    ("how to treat a snake bite", "where-there-is-no-doctor.pdf"),
    ("signs that a person is dehydrated and how to rehydrate them", "where-there-is-no-doctor.pdf"),
]


def main():
    embedder = SentenceTransformer("all-MiniLM-L6-v2")
    index, chunks = load_index()

    hits = 0
    for q, expected in CASES:
        retrieved = retrieve(q, embedder, index, chunks, k=TOP_K)
        sources = [r["source"] for r in retrieved]
        hit = expected in sources
        hits += hit
        mark = "PASS" if hit else "MISS"
        print(f"[{mark}] {q[:60]:<60} want={expected.split('.')[0][:28]:<28} got={sorted(set(sources))}")

    print(f"\nhit@{TOP_K}: {hits}/{len(CASES)} = {hits/len(CASES):.0%}")


if __name__ == "__main__":
    main()
