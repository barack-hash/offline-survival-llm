"""
main.py — the core loop of the device.

Flow:
  1. Get a question (typed now; from Arduino serial later).
  2. Retrieve the most relevant chunks from the local index (rag_build.py output).
  3. If the question touches a safety-critical category (dosages, structural
     loads, electrical/gas, etc.), switch to strict mode: show the raw source
     text verbatim, require corroboration from more than one source file, and
     run the model at temperature 0 with no room to "fill in" a number.
  4. Ask the local LLM to answer using ONLY those chunks.
  5. Print the answer (swap print_answer() for e-ink code once the screen arrives).

Run:
    python3 main.py
"""

import pickle
import re

import faiss
from rank_bm25 import BM25Okapi
from sentence_transformers import SentenceTransformer
from llama_cpp import Llama

INDEX_PATH = "index.faiss"
CHUNKS_PATH = "chunks.pkl"
# Qwen2.5-3B-Instruct replaced Phi-3 Mini: llama.cpp renders Phi-3's
# sliding-window attention as gibberish beyond ~2047 tokens, which broke
# critical mode's 8-chunk prompts (see BUILD_LOG 2026-09-16). Qwen2.5-3B
# has 32k native context and answered the same prompt correctly.
MODEL_PATH = "models/Qwen2.5-3B-Instruct-Q4_K_M.gguf"
TOP_K = 4  # how many chunks to retrieve per question
CRITICAL_TOP_K = 8  # pull more candidates when checking for corroboration

PLAIN_LANGUAGE_RULES = (
    "Explain this in plain, everyday language, as if speaking to someone with "
    "no technical background and no tools beyond whatever they can find nearby. "
    "Do not use technical, engineering, or scientific terms (e.g. 'conduit', "
    "'exhaust channel', 'thermal mass', 'combustion chamber'). Instead describe "
    "things by what they look like and how to find or make them (e.g. 'a "
    "straight stick about as long as your arm', 'a hollow tube you could blow "
    "through', 'stack rocks into a small wall'). Break the process into small, "
    "concrete, physical actions in the order you'd actually do them, one action "
    "per step. If you must name something with no simple substitute, say the "
    "name once and immediately describe what it looks like or does in the same "
    "sentence."
)

SYSTEM_PROMPT = (
    "You are an offline reference assistant for survival and rebuilding basic "
    "technology after losing access to modern infrastructure. Answer ONLY using "
    "the reference text provided below. If the reference text doesn't contain "
    "the answer, say so plainly instead of guessing. " + PLAIN_LANGUAGE_RULES
)

CRITICAL_SYSTEM_PROMPT = (
    "You are an offline reference assistant. This question involves a "
    "safety-critical figure (dosage, structural, electrical, or similar). "
    "Do NOT estimate, round, average, or infer any number that is not written "
    "explicitly in the reference text below. If a number isn't stated "
    "verbatim in the text, say 'not stated in available sources' instead of "
    "guessing. Quote the exact figure and cite which source it came from. "
    "For any surrounding explanation (not the figure itself), still follow "
    "these rules: " + PLAIN_LANGUAGE_RULES
)

# Keywords that trigger strict/critical mode. Extend this list as needed.
CRITICAL_KEYWORDS = [
    "dose", "dosage", "mg", "milligram", "ml ", "overdose",
    "load", "load-bearing", "psi", "pressure", "voltage", "amp", "current",
    "gas", "propane", "carbon monoxide", "explosive", "structural", "beam",
    "weight limit", "rated for",
]


def is_critical(question: str) -> bool:
    q = question.lower()
    return any(kw in q for kw in CRITICAL_KEYWORDS)


# --- Input sources -----------------------------------------------------
# INPUT_MODE = "keyboard": type questions at a regular keyboard/terminal.
# INPUT_MODE = "serial":   read characters from the Arduino keypad over
#                          USB-serial (see keypad_serial.ino). Update
#                          SERIAL_PORT to match your Arduino (check with
#                          `ls /dev/ttyACM*` or `ls /dev/ttyUSB*` on the Pi).
INPUT_MODE = "keyboard"
SERIAL_PORT = "/dev/ttyACM0"
SERIAL_BAUD = 9600


class KeyboardInput:
    def get_question(self):
        return input("> ")


class SerialKeypadInput:
    """Reads characters from the Arduino one at a time and assembles them
    into a question, submitted when the encoder button (sends '\\n') is
    pressed. '<' / '>' from the rotary encoder are ignored here — wire
    them up to a menu system once the e-ink screen is in place."""

    def __init__(self, port, baud):
        import serial  # pyserial, installed by setup.sh
        self.ser = serial.Serial(port, baud, timeout=1)

    def get_question(self):
        buffer = ""
        print("> ", end="", flush=True)
        while True:
            char = self.ser.read().decode(errors="ignore")
            if not char:
                continue
            if char == "\n":
                print()
                return buffer
            if char in ("<", ">"):
                continue  # navigation, not text input yet
            buffer += char
            print(char, end="", flush=True)


def get_input_source():
    if INPUT_MODE == "serial":
        return SerialKeypadInput(SERIAL_PORT, SERIAL_BAUD)
    return KeyboardInput()


def load_index():
    index = faiss.read_index(INDEX_PATH)
    with open(CHUNKS_PATH, "rb") as f:
        chunks = pickle.load(f)
    return index, chunks


# Hybrid retrieval (issue #4): pure vector search missed sources when the
# query's *keywords* mattered more than its overall phrasing ("harden a
# knife I forged" ranked the blacksmithing book 7th-10th). BM25 keyword
# scores fused with vector ranks fix that without any per-query LLM cost.
RRF_K = 60          # standard reciprocal-rank-fusion constant
CANDIDATE_POOL = 20  # candidates taken from each retriever before fusion

_bm25_cache = {}


def _tokenize(text):
    return re.findall(r"[a-z0-9]+", text.lower())


def _get_bm25(chunks):
    """Build (once per corpus) a BM25 index over the chunk texts.
    ~2 s for 2801 chunks on the Pi, cached for the process lifetime."""
    key = id(chunks)
    if key not in _bm25_cache:
        _bm25_cache.clear()
        _bm25_cache[key] = BM25Okapi([_tokenize(c["text"]) for c in chunks])
    return _bm25_cache[key]


def retrieve(question, embedder, index, chunks, k=TOP_K):
    # Dense (semantic) candidates
    q_emb = embedder.encode([question], convert_to_numpy=True)
    _, vec_ids = index.search(q_emb, CANDIDATE_POOL)

    # Sparse (keyword) candidates
    bm25 = _get_bm25(chunks)
    kw_scores = bm25.get_scores(_tokenize(question))
    kw_ids = sorted(range(len(chunks)), key=lambda i: -kw_scores[i])[:CANDIDATE_POOL]

    # Reciprocal rank fusion
    fused = {}
    for rank, i in enumerate(vec_ids[0]):
        if i != -1:
            fused[i] = fused.get(i, 0.0) + 1.0 / (RRF_K + rank + 1)
    for rank, i in enumerate(kw_ids):
        fused[i] = fused.get(i, 0.0) + 1.0 / (RRF_K + rank + 1)

    top = sorted(fused, key=fused.get, reverse=True)[:k]
    return [chunks[i] for i in top]


def build_messages(question, retrieved, critical=False):
    """Chat-format messages. Using the model's own chat template (via
    create_chat_completion) instead of a raw completion prompt — raw
    prompts produced template artifacts and duplicated answers with
    instruct-tuned models in the Phase 4 eval."""
    context = "\n\n".join(
        f"[Source: {r['source']}]\n{r['text']}" for r in retrieved
    )
    system = CRITICAL_SYSTEM_PROMPT if critical else SYSTEM_PROMPT
    return [
        {"role": "system", "content": system},
        {"role": "user", "content": f"REFERENCE TEXT:\n{context}\n\nQUESTION: {question}"},
    ]


def generate_answer(llm, question, retrieved, critical=False, max_tokens=400):
    """Single entry point for generation — main loop, verify.py and
    eval_questions.py all call this so they can never drift apart."""
    messages = build_messages(question, retrieved, critical=critical)
    output = llm.create_chat_completion(
        messages=messages,
        max_tokens=max_tokens,
        temperature=0.0 if critical else 0.3,
    )
    return output["choices"][0]["message"]["content"]


def corroboration_check(retrieved):
    """Returns the set of distinct source files backing this answer.
    Fewer than 2 distinct sources means the figure is uncorroborated."""
    return {r["source"] for r in retrieved}


def print_answer(answer, critical=False, sources=None, raw_chunks=None):
    # Swap this out for e-ink drawing code once the display is wired up.
    print("\n" + "=" * 60)
    if critical:
        print("⚠ SAFETY-CRITICAL QUESTION — verify against a second source before acting.\n")
        if sources and len(sources) < 2:
            print("⚠ Only ONE source in your library backs this — treat with extra caution.\n")
        if raw_chunks:
            print("--- Raw source text (verbatim, for you to check yourself) ---")
            for r in raw_chunks:
                print(f"[{r['source']}]: {r['text']}\n")
            print("--- Model's summary of the above ---")
    print(answer.strip())
    print("=" * 60 + "\n")


def main():
    print("Loading embedding model...")
    embedder = SentenceTransformer("all-MiniLM-L6-v2")

    print("Loading local index...")
    index, chunks = load_index()

    print("Loading LLM (this can take a moment on first load)...")
    # n_ctx=4096: the model is a 4k-context model, and critical mode's
    # 8-chunk retrieval overflows 2048 (crashed with "Requested tokens
    # (3470) exceed context window of 2048" in the Phase 4 eval).
    llm = Llama(model_path=MODEL_PATH, n_ctx=4096, n_threads=4)

    input_source = get_input_source()
    print("\nOffline reference assistant ready. Type a question, or 'quit' to exit.\n")

    while True:
        question = input_source.get_question().strip()
        if question.lower() in ("quit", "exit"):
            break
        if not question:
            continue

        critical = is_critical(question)
        k = CRITICAL_TOP_K if critical else TOP_K
        retrieved = retrieve(question, embedder, index, chunks, k=k)
        answer = generate_answer(llm, question, retrieved, critical=critical)

        sources = corroboration_check(retrieved) if critical else None
        print_answer(answer, critical=critical, sources=sources, raw_chunks=retrieved if critical else None)


if __name__ == "__main__":
    main()
