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
    # 2026-09-16 corpus additions: knots, navigation, chemistry
    ("what knot should I use to join two ropes of different sizes", "knots-splices-ropework-1912.txt"),
    ("how do I splice the ends of a rope together so it holds", "knots-splices-ropework-1912.txt"),
    ("how can I find my latitude using the sun or stars", "lectures-in-navigation-1917.txt"),
    ("how do I use a compass and correct for its errors when navigating", "lectures-in-navigation-1917.txt"),
    ("how is soap made from fat and lye", "elementary-chemistry-1906.txt"),
    ("how can I make lime by burning limestone and what is it good for", "elementary-chemistry-1906.txt"),
    # 2026-09-16 batch 2: first aid, canning, wind power, carpentry, electricity, radio
    ("how should I carry a wounded person who cannot walk", "first-aid-fm21-11-1943.txt"),
    ("what should I do for a sucking chest wound", "first-aid-fm21-11-1943.txt"),
    ("how do I can vegetables so they keep through the winter", "every-step-in-canning-1920.txt"),
    ("what is the cold-pack method of canning food", "every-step-in-canning-1920.txt"),
    ("how can I build a windmill to generate power", "windmills-wind-motors-1910.txt"),
    ("what size windmill do I need to pump water", "windmills-wind-motors-1910.txt"),
    ("what joint should I use to join two boards at a corner", "woodwork-joints-1921.txt"),
    ("how do I cut a mortise and tenon joint", "woodwork-joints-1921.txt"),
    ("how can I make a simple electric battery at home", "boy-electrician-1913.txt"),
    ("how do I wind a coil to make an electromagnet", "boy-electrician-1913.txt"),
    ("how do I build a simple radio receiver", "radio-amateurs-handbook-1922.txt"),
    ("what kind of antenna do I need to receive radio signals", "radio-amateurs-handbook-1922.txt"),
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
