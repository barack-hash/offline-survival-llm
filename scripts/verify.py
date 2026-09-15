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

from main import load_index, retrieve, build_prompt, is_critical, CRITICAL_TOP_K, TOP_K
from sentence_transformers import SentenceTransformer
from llama_cpp import Llama

MODEL_PATH = "models/Phi-3-mini-4k-instruct-q4.gguf"

# Add real test cases here. Keep expanding this list over time.
test_cases = [
    {
        "question": "What are the three things needed to start a fire?",
        "known_correct_answer": "Heat, fuel, and oxygen (the fire triangle).",
    },
    {
        "question": "What temperature kills most waterborne pathogens when boiling water?",
        "known_correct_answer": "Water reaching a rolling boil (100C / 212F at sea level) for at least 1 minute.",
    },
    # Add safety-critical examples specific to your corpus, e.g. dosages
    # or structural figures, so you know exactly how the strict mode behaves.
]


def main():
    embedder = SentenceTransformer("all-MiniLM-L6-v2")
    index, chunks = load_index()
    llm = Llama(model_path=MODEL_PATH, n_ctx=2048, n_threads=4)

    for case in test_cases:
        question = case["question"]
        critical = is_critical(question)
        k = CRITICAL_TOP_K if critical else TOP_K
        retrieved = retrieve(question, embedder, index, chunks, k=k)
        prompt = build_prompt(question, retrieved, critical=critical)

        output = llm(prompt, max_tokens=300, temperature=0.0 if critical else 0.3, stop=["QUESTION:"])
        answer = output["choices"][0]["text"].strip()

        print("=" * 70)
        print(f"Q: {question}")
        print(f"KNOWN CORRECT: {case['known_correct_answer']}")
        print(f"DEVICE SAID:   {answer}")
        print(f"Critical mode: {critical}")
        print("Sources used:", {r['source'] for r in retrieved})
        print()


if __name__ == "__main__":
    main()
