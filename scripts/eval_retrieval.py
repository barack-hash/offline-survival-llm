"""
eval_retrieval.py — retrieval-only benchmark (no LLM, runs in seconds).

For each query we know which source file MUST appear in the top TOP_K
results for the device to have any chance of answering correctly.
Reports hit@k per query and overall. Run from the project root:

    PYTHONPATH=scripts venv/bin/python scripts/eval_retrieval.py

Built for issue #4 (query-phrasing sensitivity). Run before and after
any retrieval change; paste both scores into the BUILD_LOG entry.
"""

import re

from sentence_transformers import SentenceTransformer

from main import load_index, retrieve, select_passages, load_reranker, TOP_K, RERANK_POOL

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


# Passage-level expectations (added 2026-11-14, LEARNINGS L-022): finding the
# right *book* is not enough — the passage that actually holds the answer
# must rank high. A retrieved passage counts as the answer passage when it
# comes from the expected source AND matches this pattern (case-insensitive).
ANSWER_PATTERNS = {
    "How do I start a fire when all the wood around me is wet?": r"tepee|wet wood|damp",
    "How can I make dirty water from a river safe to drink?": r"purif|boil",
    "What kind of shelter should I build to stay warm in a cold forest?": r"ridgepole|lean-to|debris hut|tree-pit|snow cave",
    "How can I tell if a wild plant is safe to eat?": r"edibility test",
    "How should I clean and cover a deep cut so it does not get infected?": r"(wash|clean)\w*.{0,60}(wound|cut)",
    "How do I take out a tooth that is badly infected?": r"take out a tooth|extract",
    "How deep should I plant large seeds like beans compared to small seeds?": r"depth|deep",
    "How do I harden the edge of a knife I forged so it stays sharp?": r"cherry red|knife|blade",
    "What is the correct dose of aspirin for an adult with fever?": r"aspirin.{0,300}(mg|tablet)",
    "how to temper a steel blade after forging it": r"temper",
    "how do I weld two pieces of iron together in a forge": r"weld",
    "my tooth hurts and my gums are swollen, what do I do": r"abscess|swollen|gum",
    "when should seedlings be moved from the seed bed to the field": r"transplant",
    "what should the soil be like before sowing seeds": r"seed.?bed|mellow|fine",
    "how to treat a snake bite": r"snake ?bite",
    "signs that a person is dehydrated and how to rehydrate them": r"dehydrat",
    "what knot should I use to join two ropes of different sizes": r"sheet bend|becket|weaver",
    "how do I splice the ends of a rope together so it holds": r"splice",
    "how can I find my latitude using the sun or stars": r"latitude",
    "how do I use a compass and correct for its errors when navigating": r"deviation|variation",
    "how is soap made from fat and lye": r"soap",
    "how can I make lime by burning limestone and what is it good for": r"lime",
    "how should I carry a wounded person who cannot walk": r"carr(y|ied|ying)|litter|stretcher",
    "what should I do for a sucking chest wound": r"chest",
    "how do I can vegetables so they keep through the winter": r"vegetable",
    "what is the cold-pack method of canning food": r"cold.?pack",
    "how can I build a windmill to generate power": r"dynamo|generat|electric",
    "what size windmill do I need to pump water": r"pump",
    "what joint should I use to join two boards at a corner": r"corner|mitre|miter|dovetail",
    "how do I cut a mortise and tenon joint": r"mortise",
    "how can I make a simple electric battery at home": r"\bcells?\b|battery",
    "how do I wind a coil to make an electromagnet": r"electro.?magnet|coil",
    "how do I build a simple radio receiver": r"receiv",
    "what kind of antenna do I need to receive radio signals": r"antenna|aerial",
}


def is_answer_passage(chunk, expected_source, query):
    pat = ANSWER_PATTERNS.get(query)
    return (chunk["source"] == expected_source and pat is not None
            and re.search(pat, chunk["text"], re.I | re.S) is not None)


def passage_rank(retrieved, expected_source, query):
    """1-based rank of the first answer passage, or None."""
    for i, c in enumerate(retrieved, 1):
        if is_answer_passage(c, expected_source, query):
            return i
    return None


def passage_report(retrieve_fn, embedder, index, chunks, depth=10, verbose=True):
    """Passage hit@1..4 and MRR@depth for any retrieve function."""
    ranks = []
    for q, expected in CASES:
        rank = passage_rank(retrieve_fn(q, embedder, index, chunks, k=depth), expected, q)
        ranks.append(rank)
        if verbose:
            print(f"  rank {rank if rank else '>' + str(depth):>4}  {q}")
    n = len(CASES)
    for k in (1, 2, 3, 4):
        print(f"passage hit@{k}: {sum(1 for r in ranks if r and r <= k)}/{n}")
    print(f"passage MRR@{depth}: {sum(1 / r for r in ranks if r) / n:.3f}")
    return ranks


def select_passages_ranked(q, embedder, index, chunks, reranker, k):
    """Same ordering as select_passages, but returns k passages so the
    rank of the answer passage beyond TOP_K is visible."""
    import main as m
    saved = m.TOP_K
    try:
        m.TOP_K = k
        return m.select_passages(q, embedder, index, chunks, reranker)
    finally:
        m.TOP_K = saved


def main():
    embedder = SentenceTransformer("all-MiniLM-L6-v2")
    reranker = load_reranker()
    index, chunks = load_index()

    hits = 0
    for q, expected in CASES:
        retrieved = select_passages(q, embedder, index, chunks, reranker)
        sources = [r["source"] for r in retrieved]
        hit = expected in sources
        hits += hit
        mark = "PASS" if hit else "MISS"
        print(f"[{mark}] {q[:60]:<60} want={expected.split('.')[0][:28]:<28} got={sorted(set(sources))}")

    print(f"\nhit@{TOP_K}: {hits}/{len(CASES)} = {hits/len(CASES):.0%}")

    print("\nPassage-level, hybrid only (no rerank), for comparison:")
    passage_report(retrieve, embedder, index, chunks, verbose=False)

    # What the device actually uses: rerank the top RERANK_POOL (critical
    # questions bypass reranking inside select_passages).
    def device_order(q, e, ix, ch, k):
        return select_passages_ranked(q, e, ix, ch, reranker, k)
    print(f"\nPassage-level, device path (rerank top {RERANK_POOL}):")
    passage_report(device_order, embedder, index, chunks)


if __name__ == "__main__":
    main()
