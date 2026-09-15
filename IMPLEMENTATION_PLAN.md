# IMPLEMENTATION PLAN — Offline Survival LLM Device
Target: Raspberry Pi 5 (8GB / 128GB), currently connected to internet + monitor.
GitHub: github.com/barack-hash/offline-survival-llm
Executor: Claude Code (see CLAUDE.md for logging rules that apply to EVERY phase).

Scope of this plan: everything achievable with hardware on hand today
(Pi 5 + Arduino starter kit). Phases blocked on unpurchased hardware
(e-ink module, UPS HAT, enclosure) are included as stubs at the end so
the repo structure anticipates them.

---

## PHASE 0 — Repository + logging scaffolding
Goal: a clean git repo with logging infrastructure BEFORE any build work,
so nothing goes unlogged from the first command onward.

Steps:
1. Create project directory `~/offline-survival-llm` and `git init`.
2. Create this structure:
   ```
   offline-survival-llm/
   ├── README.md
   ├── CLAUDE.md
   ├── IMPLEMENTATION_PLAN.md   (this file)
   ├── BUILD_PLAN.md
   ├── CORPUS_CHECKLIST.md
   ├── docs/
   │   ├── BUILD_LOG.md         (dated session log — template provided)
   │   ├── HARDWARE.md          (every tool & part used — template provided)
   │   └── wiring/              (photos + diagrams, added as hardware phases run)
   ├── corpus/                  (reference texts; see .gitignore rules)
   ├── models/                  (GGUF files; gitignored, too large)
   ├── scripts/
   │   ├── setup.sh
   │   ├── rag_build.py
   │   ├── main.py
   │   ├── verify.py
   │   └── keypad_serial.ino
   └── .gitignore
   ```
3. Write .gitignore (provided) — CRITICAL rules:
   - `models/` — multi-GB files, never committed.
   - `index.faiss`, `chunks.pkl` — regenerated artifacts.
   - `corpus/own/` — any scanned COPYRIGHTED material (e.g. The Knowledge)
     lives only in this subfolder and is NEVER pushed to a public repo.
     Public-domain texts go in `corpus/pd/` and MAY be committed.
   - `venv/`, `__pycache__/`
4. First commit: scaffolding only. Then create the GitHub repo under
   barack-hash and push. (If `gh` CLI is available: `gh repo create
   barack-hash/offline-survival-llm --public --source=. --push`.
   Otherwise create on github.com and add the remote manually.)
5. Log Phase 0 completion in docs/BUILD_LOG.md per CLAUDE.md rules.

Acceptance criteria:
- [ ] Repo exists on GitHub with scaffolding pushed.
- [ ] BUILD_LOG.md has its first dated entry.
- [ ] .gitignore verified by `git status` showing models/ and corpus/own/ untracked.

---

## PHASE 1 — System verification & prep
Goal: confirm the Pi is healthy and configured before heavy installs.

Steps:
1. Record in docs/HARDWARE.md: Pi model, RAM, storage, OS version
   (`cat /etc/os-release`, `uname -a`, `free -h`, `df -h`, `vcgencmd measure_temp`).
2. `sudo apt update && sudo apt full-upgrade -y`.
3. Enable SPI via `sudo raspi-config nonint do_spi 0` (needed for e-ink later).
4. Confirm active cooling works: run `stress` or a build for 2 minutes,
   log idle vs load temperature in BUILD_LOG.md.
5. Commit any config notes; log the session.

Acceptance criteria:
- [ ] OS fully updated; reboot clean.
- [ ] SPI enabled.
- [ ] Idle + load temperatures logged (expect roughly 45-55°C idle, under
      75°C load with the official cooler; log whatever is observed).

---

## PHASE 2 — LLM engine
Goal: llama.cpp built from source, model downloaded, benchmarked, working.

Steps:
1. Run `scripts/setup.sh` (builds llama.cpp, downloads Phi-3 Mini Q4 GGUF
   ~2.3GB, creates Python venv with dependencies).
2. If the model URL 404s (Hugging Face paths change): search Hugging Face
   for "Phi-3-mini-4k-instruct-gguf" Q4 quantization, update the URL in
   setup.sh, and LOG THE CHANGE as a challenge+fix in BUILD_LOG.md.
3. Benchmark: run llama-cli with a fixed test prompt, record tokens/sec
   for prompt processing and generation. Log exact numbers.
4. Log RAM usage during inference (`free -h` in a second terminal).
5. Commit setup.sh if modified; log the session including benchmark table.

Acceptance criteria:
- [ ] Model answers a test question from the command line.
- [ ] Benchmark logged (expect roughly 5-10 tok/s generation; log actuals).
- [ ] RAM headroom confirmed (expect >3GB free during inference).

---

## PHASE 3 — Knowledge corpus + RAG index
Goal: real public-domain reference texts indexed and searchable.

Steps:
1. Create `corpus/pd/` and `corpus/own/` folders.
2. Download public-domain sources per CORPUS_CHECKLIST.md, starting with:
   - U.S. Army Survival Manual FM 21-76 (public domain; archive.org hosts it)
   - At least one more PD text (old farming/blacksmithing manual from archive.org)
   Log EVERY source in docs/BUILD_LOG.md AND a new docs/CORPUS_SOURCES.md:
   filename, origin URL, edition/date, license status (PD/FREE/OWN).
3. Run `scripts/rag_build.py`. Log chunk counts per source and total
   index build time.
4. Spot-check retrieval: query 3 known topics (fire, water purification,
   shelter) and confirm relevant chunks return. Log results.
5. Commit corpus/pd files + CORPUS_SOURCES.md; log the session.

Acceptance criteria:
- [ ] At least 2 PD sources indexed.
- [ ] index.faiss + chunks.pkl generated (untracked by git).
- [ ] 3 spot-check retrievals logged with pass/fail judgment.

---

## PHASE 4 — Main application + verification loop
Goal: full ask→retrieve→answer pipeline working in the terminal, with a
growing test suite.

Steps:
1. Run `scripts/main.py` in keyboard mode. Ask 10 varied questions
   spanning: normal survival topics, a safety-critical topic (to confirm
   strict mode triggers + shows verbatim sources), and a topic NOT in the
   corpus (to confirm it says "not in sources" rather than hallucinating).
2. Log every question + answer + verdict (good / vague / wrong / hallucinated)
   in BUILD_LOG.md. This is the single most valuable log content in the
   whole project.
3. For each failure found, make ONE tuning change at a time (prompt wording,
   TOP_K, chunk size, keyword list), re-test, and log change→effect.
4. Add the best test questions into scripts/verify.py's test_cases list.
5. Commit tuning changes with descriptive messages; log the session.

Acceptance criteria:
- [ ] 10-question evaluation logged with verdicts.
- [ ] Critical mode confirmed triggering and showing raw sources.
- [ ] Out-of-corpus question correctly declined, not hallucinated.
- [ ] verify.py contains at least 5 real test cases and runs clean.

---

## PHASE 5a — Physical input (Arduino keypad)
Goal: questions typed on real hardware buttons instead of a keyboard.

Steps:
1. Wire the starter-kit 4x4 matrix keypad to the Arduino per the pin map
   in scripts/keypad_serial.ino. PHOTOGRAPH the wiring; save to docs/wiring/.
2. Flash keypad_serial.ino via Arduino IDE. Log IDE version, board type,
   any library installs (Keypad library), and any upload problems + fixes.
3. Connect Arduino→Pi via USB. Identify the port (`ls /dev/ttyACM*`).
4. Set INPUT_MODE = "serial" in main.py, run, and type a question on the
   keypad. Log the first successful hardware-typed question verbatim —
   that's a milestone worth recording.
5. Known limitation to log honestly: digits + A-D only until multi-tap
   letter entry is implemented. Create a GitHub issue for multi-tap as
   the next input improvement.
6. Update docs/HARDWARE.md (Arduino board, keypad, cables). Commit; log.

Acceptance criteria:
- [ ] Wiring photo in docs/wiring/.
- [ ] A question asked entirely via keypad receives an answer.
- [ ] Multi-tap letter entry filed as a tracked issue.

---

## PHASE 5b — E-ink display integration  [STUB — awaiting hardware]
When the ELECROW ESP32-S3 2.13" e-paper module arrives:
- Firmware sketch for the ESP32-S3 (serial listener → render text).
- main.py output routed to second serial port.
- Wiring/pairing notes + photos to docs/wiring/.

## PHASE 6 — Power system  [STUB — awaiting hardware]
When the Pi 5 UPS HAT + 18650 cells arrive:
- Runtime measurement vs the theoretical ~5hr estimate; log actuals.
- Wi-Fi/BT disable script + CPU governor for battery mode.
- Safe-shutdown-on-low-battery configuration.

## PHASE 7 — Enclosure  [STUB — awaiting materials]
- Dimension sketch once display size is physically confirmed.
- Steampunk build log with photos at every assembly step.

---

## Definition of "done" for the current hardware scope
Phases 0-5a complete, every acceptance criterion checked, every session
logged, repo pushed, and stub issues created on GitHub for 5b/6/7 so the
project board reflects reality.
