"""
verify.py — run a small set of known-answer questions through the device
BEFORE you trust it, and whenever you change the model or the corpus.

How to use:
  1. Fill in test_cases below with real questions and the correct answer
     (look these up now, while you still have internet, from a source you trust).
  2. Run: python3 verify.py
  3. Read each answer yourself and judge pass/fail — this is not automatic
     grading, it's a structured way to force yourself to actually check.
"""

from main import (
    load_index, retrieve, generate_answer, is_critical,
    CRITICAL_TOP_K, TOP_K, MODEL_PATH,
)
from sentence_transformers import SentenceTransformer
from llama_cpp import Llama

# Add real test cases here. Keep expanding this list over time.
# Cases below were validated against the corpus during the Phase 4
# evaluation (2026-09-16) — known answers quote what the sources say.
test_cases = [
    {
        "question": "What are the three things needed to start a fire?",
        "known_correct_answer": "Heat, fuel, and oxygen (the fire triangle).",
    },
    {
        "question": "What temperature kills most waterborne pathogens when boiling water?",
        "known_correct_answer": "Water reaching a rolling boil (100C / 212F at sea level) for at least 1 minute.",
    },
    {
        # Safety-critical: must trigger strict mode (keyword 'dose'),
        # show verbatim chunks, and quote the figure exactly.
        "question": "What is the correct dose of aspirin for an adult with fever?",
        "known_correct_answer": "Adults: 1 or 2 tablets (300 to 600 mg) every 4 to 6 hours "
                                "(WTIND 2010 Green Pages; do not give to children under 12).",
    },
    {
        "question": "How can I tell if a wild plant is safe to eat?",
        "known_correct_answer": "FM 21-76 rules: avoid milky/discolored sap, beans/bulbs/seeds "
                                "in pods, bitter or soapy taste, spines/fine hairs/thorns, almond "
                                "scent; never eat mushrooms without positive identification.",
    },
    {
        "question": "How do I take out a tooth that is badly infected?",
        "known_correct_answer": "Clean the cavity, rinse with warm salt water, pain medicine, "
                                "antibiotics if severe (penicillin/sulfonamide/tetracycline per "
                                "WTIND); pull the tooth if pain/swelling persists or returns.",
    },
    {
        # Out-of-corpus canary: the device must decline, not invent.
        "question": "How do I update the firmware on a modern car's engine computer?",
        "known_correct_answer": "NOT in corpus — device must say the sources don't cover this.",
    },
]


def main():
    embedder = SentenceTransformer("all-MiniLM-L6-v2")
    index, chunks = load_index()
    llm = Llama(model_path=MODEL_PATH, n_ctx=4096, n_threads=4)

    for case in test_cases:
        question = case["question"]
        critical = is_critical(question)
        k = CRITICAL_TOP_K if critical else TOP_K
        retrieved = retrieve(question, embedder, index, chunks, k=k)
        answer = generate_answer(llm, question, retrieved, critical=critical,
                                 max_tokens=300).strip()

        print("=" * 70)
        print(f"Q: {question}")
        print(f"KNOWN CORRECT: {case['known_correct_answer']}")
        print(f"DEVICE SAID:   {answer}")
        print(f"Critical mode: {critical}")
        print("Sources used:", {r['source'] for r in retrieved})
        print()


if __name__ == "__main__":
    main()
