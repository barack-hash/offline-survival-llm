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
import time

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
TOP_K = 3  # passages per normal question, after reranking (was 4 before L-022)
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

# Retrieval can hand the model passages about a *different* subject than
# the question (e.g. fire-hardening a WOODEN knife when asked about a
# forged steel one — issue #4). The subject-match instruction below makes
# the model filter those out instead of blending them in.
SUBJECT_MATCH_RULE = (
    "The reference text may contain passages about a different subject than "
    "the question — for example a different material, tool, plant, or "
    "ailment than the one asked about. First decide which passages are truly "
    "about the question's subject, and answer ONLY from those. Ignore "
    "passages about a different subject completely; do not mix their steps "
    "or figures into the answer. If none of the passages match the "
    "question's subject, say so plainly. "
)

SYSTEM_PROMPT = (
    "You are an offline reference assistant for survival and rebuilding basic "
    "technology after losing access to modern infrastructure. Answer ONLY using "
    "the reference text provided below. If the reference text doesn't contain "
    "the answer, say so plainly instead of guessing. "
    + SUBJECT_MATCH_RULE + PLAIN_LANGUAGE_RULES
)

CRITICAL_SYSTEM_PROMPT = (
    "You are an offline reference assistant. This question involves a "
    "safety-critical figure (dosage, structural, electrical, or similar). "
    "Do NOT estimate, round, average, or infer any number that is not written "
    "explicitly in the reference text below. If a number isn't stated "
    "verbatim in the text, say 'not stated in available sources' instead of "
    "guessing. Quote the exact figure and cite which source it came from. "
    + SUBJECT_MATCH_RULE +
    "For any surrounding explanation (not the figure itself), still follow "
    "these rules: " + PLAIN_LANGUAGE_RULES
)

# Keywords that trigger strict/critical mode. Extend this list as needed.
CRITICAL_KEYWORDS = [
    "dose", "dosage", "mg", "milligram", "ml ", "overdose",
    "load", "load-bearing", "psi", "pressure", "voltage", "amp", "current",
    "gas", "propane", "carbon monoxide", "explosive", "structural", "beam",
    "weight limit", "rated for",
    # Plant edibility / poisoning (LEARNINGS L-023, 2026-11-14): in normal
    # mode the model invented tests ("if it floats, it's probably safe to
    # eat"); in critical mode — verbatim passages, temperature 0 — it gave
    # FM 21-76's Universal Edibility Test in the correct order.
    "edible", "safe to eat", "poison", "toxic", "mushroom",
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
INPUT_MODE = "serial"
SERIAL_PORT = "/dev/ttyACM0"
SERIAL_BAUD = 9600
SERIAL_RETRY_S = 2          # how often to look for the Arduino
SERIAL_WAIT_LOG_S = 60      # how often to log "still waiting" (keeps the journal quiet)


def wait_for_serial(port, baud):
    """Open the Arduino's serial port, waiting for it if it isn't there yet.

    Done in-process, before any model is loaded: a missing Arduino used to
    crash main.py *after* the ~1 min model load, and systemd's Restart=always
    turned that into a reload-every-19-s loop (LEARNINGS L-014)."""
    import time
    import serial  # pyserial, installed by setup.sh

    waited, last_log = 0, None
    while True:
        try:
            ser = serial.Serial(port, baud, timeout=1)
            if waited:
                print(f"Serial port {port} found after {waited} s.", flush=True)
            return ser
        except serial.SerialException as e:
            if last_log is None or waited - last_log >= SERIAL_WAIT_LOG_S:
                print(f"Waiting for the Arduino on {port} (plug it in): {e}", flush=True)
                last_log = waited
            time.sleep(SERIAL_RETRY_S)
            waited += SERIAL_RETRY_S


class KeyboardInput:
    def get_question(self):
        return input("> ")


class SerialKeypadInput:
    """Talks to the Arduino (ir_remote_serial.ino / keypad_serial.ino).

    The Arduino buffers the whole question locally (multi-tap decoding,
    backspace, LCD preview) and sends one finished line per question.
    Arrow keys arrive as control lines: ^U / ^D scroll the answer one LCD
    line, ^L / ^R one full screen. The answer is word-wrapped to 16-char
    lines here and the Pi sends whichever two lines are in view — the
    Arduino's 2 KB of RAM can't hold a whole answer."""

    LCD_COLS = 16
    LCD_ROWS = 2
    SCROLL = {"^U": -1, "^D": 1, "^L": -2, "^R": 2}

    def __init__(self, port, baud):
        self.ser = wait_for_serial(port, baud)
        self.lines = []
        self.top = 0
        self._buf = b""

    def _read_line(self):
        while b"\n" not in self._buf:
            self._buf += self.ser.read(64) or b""
        line, self._buf = self._buf.split(b"\n", 1)
        return line.decode(errors="ignore").strip()

    def _show(self):
        rows = [(self.lines[i] if i < len(self.lines) else "").ljust(self.LCD_COLS)
                for i in range(self.top, self.top + self.LCD_ROWS)]
        self.ser.write(("".join(rows) + "\n").encode())
        self.ser.flush()

    def get_question(self):
        print("> ", end="", flush=True)
        while True:
            line = self._read_line()
            if line in self.SCROLL:
                if self.lines:
                    last_top = max(len(self.lines) - self.LCD_ROWS, 0)
                    self.top = min(max(self.top + self.SCROLL[line], 0), last_top)
                    self._show()
                continue
            if line:
                print(line)
                return line

    STREAM_MIN_INTERVAL_S = 0.5  # LCD refresh cap while streaming (~2/s)
    CRITICAL_PREFIX = "!CRITICAL! verify vs 2nd source. "
    CRITICAL_PIN = "!CRITICAL!verify"  # exactly 16 chars: one full LCD row

    def stream_answer(self, text, critical=False):
        """Live view while the model is still writing: show the newest two
        wrapped lines, so the first words appear right after prompt reading
        instead of after the whole answer. Throttled so 9600 baud and the
        LCD's clear+redraw keep up."""
        import textwrap
        import time
        now = time.monotonic()
        if now - getattr(self, "_last_stream", 0.0) < self.STREAM_MIN_INTERVAL_S:
            return
        self._last_stream = now
        lines = textwrap.wrap(text, self.LCD_COLS, break_long_words=True)
        if critical:
            # Safety rule: the warning must stay visible while the answer is
            # being written. Following the newest lines scrolled a text
            # prefix off-screen on the first update (LEARNINGS L-019), so it
            # is pinned to the top row and the answer streams on the bottom.
            self.lines = [self.CRITICAL_PIN, lines[-1] if lines else ""]
            self.top = 0
        else:
            self.lines = lines
            self.top = max(len(lines) - self.LCD_ROWS, 0)
        self._show()

    def display_answer(self, text, critical=False):
        import textwrap
        self._last_stream = 0.0
        if critical:
            text = self.CRITICAL_PREFIX + text
        self.lines = textwrap.wrap(text, self.LCD_COLS, break_long_words=True) + ["-- end --"]
        self.top = 0
        # drop arrow presses made while the answer was still generating
        self.ser.reset_input_buffer()
        self._buf = b""
        self._show()


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


# Reranking (LEARNINGS L-022): hybrid fusion rewards shared keywords, so
# passages that merely share words ("cold", "shelter") outranked the one
# holding the answer (shelter build steps came 4th, water purification 6th).
# A cross-encoder reads question + passage together and reorders the top 20.
# Measured on the Pi (eval_retrieval passage-level, 34 cases):
#   hybrid only:   answer passage in top 3 = 31/34, MRR 0.797
#   + rerank 20:   answer passage in top 3 = 32/34, MRR 0.855, ~2.7 s/question
# so 3 reranked passages cover what 4 un-reranked ones did, in a ~20% shorter
# prompt. Critical questions are deliberately NOT reranked yet: their
# 8-passage verbatim path is unchanged until it has its own safety test.
RERANK_MODEL = "cross-encoder/ms-marco-MiniLM-L-6-v2"
RERANK_POOL = 20


def load_reranker():
    from sentence_transformers import CrossEncoder
    return CrossEncoder(RERANK_MODEL, max_length=512)


def select_passages(question, embedder, index, chunks, reranker, critical=None):
    """Single entry point for choosing the passages the model sees —
    main loop, verify.py and the eval scripts all call this so they can
    never drift apart."""
    if critical is None:
        critical = is_critical(question)
    if critical:
        return retrieve(question, embedder, index, chunks, k=CRITICAL_TOP_K)
    candidates = retrieve(question, embedder, index, chunks, k=RERANK_POOL)
    scores = reranker.predict([(question, c["text"]) for c in candidates])
    order = sorted(range(len(candidates)), key=lambda i: -scores[i])
    return [candidates[i] for i in order[:TOP_K]]


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


def generate_answer(llm, question, retrieved, critical=False, max_tokens=400,
                    on_text=None):
    """Single entry point for generation — main loop, verify.py and
    eval_questions.py all call this so they can never drift apart.

    on_text: optional callback, called with the answer-so-far as tokens
    arrive (streaming). Same messages, temperature and token limit either
    way, so streaming changes only *when* text is seen, not what is said."""
    messages = build_messages(question, retrieved, critical=critical)
    params = dict(
        messages=messages,
        max_tokens=max_tokens,
        temperature=0.0 if critical else 0.3,
    )
    if on_text is None:
        output = llm.create_chat_completion(**params)
        return output["choices"][0]["message"]["content"]

    text = ""
    for chunk in llm.create_chat_completion(stream=True, **params):
        piece = chunk["choices"][0]["delta"].get("content")
        if piece:
            text += piece
            on_text(text)
    return text


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
    # Input device first: it's the cheap, likely-to-be-missing resource.
    # In serial mode this blocks until the Arduino is plugged in, so the
    # expensive model loads below happen once, not on every retry (L-014).
    input_source = get_input_source()

    print("Loading embedding model...")
    embedder = SentenceTransformer("all-MiniLM-L6-v2")

    print("Loading reranker...")
    reranker = load_reranker()

    print("Loading local index...")
    index, chunks = load_index()

    print("Loading LLM (this can take a moment on first load)...")
    # n_ctx=4096: the model is a 4k-context model, and critical mode's
    # 8-chunk retrieval overflows 2048 (crashed with "Requested tokens
    # (3470) exceed context window of 2048" in the Phase 4 eval).
    llm = Llama(model_path=MODEL_PATH, n_ctx=4096, n_threads=4)

    print("\nOffline reference assistant ready. Type a question, or 'quit' to exit.\n")

    while True:
        question = input_source.get_question().strip()
        if question.lower() in ("quit", "exit"):
            break
        if not question:
            continue

        t0 = time.monotonic()
        critical = is_critical(question)
        retrieved = select_passages(question, embedder, index, chunks,
                                    reranker, critical=critical)

        on_text = None
        first_text = []
        if isinstance(input_source, SerialKeypadInput):
            def on_text(text):
                if not first_text:
                    first_text.append(time.monotonic() - t0)
                input_source.stream_answer(text, critical=critical)
        answer = generate_answer(llm, question, retrieved, critical=critical,
                                 on_text=on_text)
        total = time.monotonic() - t0
        if first_text:
            print(f"[timing] first words on LCD {first_text[0]:.1f} s, "
                  f"full answer {total:.1f} s")
        else:
            print(f"[timing] full answer {total:.1f} s")

        sources = corroboration_check(retrieved) if critical else None
        print_answer(answer, critical=critical, sources=sources, raw_chunks=retrieved if critical else None)
        if isinstance(input_source, SerialKeypadInput):
            input_source.display_answer(answer, critical=critical)


if __name__ == "__main__":
    main()
