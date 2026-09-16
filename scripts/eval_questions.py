"""
eval_questions.py — Phase 4 evaluation battery.

Runs a fixed set of questions through the EXACT same pipeline as main.py
(same retrieval, same prompts, same critical-mode logic, same temperatures)
but non-interactively, so the results can be logged and compared across
tuning changes. Run from the project root:

    venv/bin/python scripts/eval_questions.py

The verdict column in BUILD_LOG.md is judged by a human (or the build
assistant) reading this output — this script does not self-grade.
"""

import time

from main import (
    load_index, retrieve, generate_answer, is_critical,
    corroboration_check, TOP_K, CRITICAL_TOP_K, MODEL_PATH,
)
from sentence_transformers import SentenceTransformer
from llama_cpp import Llama

# Categories: normal (in-corpus), critical (must trigger strict mode),
# out_of_corpus (must decline, not hallucinate).
QUESTIONS = [
    ("normal",        "How do I start a fire when all the wood around me is wet?"),
    ("normal",        "How can I make dirty water from a river safe to drink?"),
    ("normal",        "What kind of shelter should I build to stay warm in a cold forest?"),
    ("normal",        "How can I tell if a wild plant is safe to eat?"),
    ("normal",        "How should I clean and cover a deep cut so it does not get infected?"),
    ("normal",        "How do I take out a tooth that is badly infected?"),
    ("normal",        "How deep should I plant large seeds like beans compared to small seeds?"),
    ("normal",        "How do I harden the edge of a knife I forged so it stays sharp?"),
    ("critical",      "What is the correct dose of aspirin for an adult with fever?"),
    ("out_of_corpus", "How do I update the firmware on a modern car's engine computer?"),
]


def main():
    print("Loading models + index...")
    embedder = SentenceTransformer("all-MiniLM-L6-v2")
    index, chunks = load_index()
    llm = Llama(model_path=MODEL_PATH, n_ctx=4096, n_threads=4, verbose=False)

    for i, (category, question) in enumerate(QUESTIONS, 1):
        critical = is_critical(question)
        k = CRITICAL_TOP_K if critical else TOP_K
        retrieved = retrieve(question, embedder, index, chunks, k=k)
        sources = corroboration_check(retrieved)

        t0 = time.time()
        answer = generate_answer(llm, question, retrieved, critical=critical).strip()
        elapsed = time.time() - t0

        print("=" * 70)
        print(f"[{i}/10] category={category} critical_mode={critical} "
              f"time={elapsed:.0f}s")
        print(f"Q: {question}")
        print(f"Sources retrieved: {sorted(sources)}")
        if critical and len(sources) < 2:
            print("⚠ CORROBORATION WARNING would fire (only one source)")
        print(f"A: {answer}")
        print()


if __name__ == "__main__":
    main()
