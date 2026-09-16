# Build Log — Offline Survival LLM Device

Every session gets an entry. Mistakes and challenges are the most
valuable content here — never sanitized, never skipped.

Template:

## YYYY-MM-DD — Session title
**Goal:**
**Done:**
**Mistakes/Challenges:**
**Improvements/Decisions:**
**Hardware/Tools used:**
**Next:**

---
(entries begin below)

## 2026-09-15 — Phase 0: repo + logging scaffolding
**Goal:** Stand up the git repo, logging infrastructure, and GitHub remote before any build work (Phase 0 of IMPLEMENTATION_PLAN.md).
**Done:**
- Scaffolding (README, CLAUDE.md, IMPLEMENTATION_PLAN.md, BUILD_PLAN.md, CORPUS_CHECKLIST.md, docs/, corpus/pd + corpus/own, scripts/ with setup.sh, rag_build.py, main.py, verify.py, keypad_serial.ino, .gitignore) already existed on disk; this session put it under version control.
- `git init -b main` in the project folder on the owner's Mac (not the Pi — see Mistakes).
- Verified .gitignore with `git check-ignore -v`: models/, corpus/own/, venv/, index.faiss, chunks.pkl all correctly ignored.
- First commit of scaffolding; created public repo barack-hash/offline-survival-llm via `gh repo create` and pushed.
**Mistakes/Challenges:**
- `git add -A` staged macOS `.DS_Store` files (root and corpus/). The provided .gitignore didn't cover them because the plan assumed work happens on the Pi (Linux). Fix: appended `.DS_Store` to .gitignore and `git rm --cached` the staged copies.
- Environment mismatch: this session runs on the owner's Mac, but Phases 1+ (apt, raspi-config, vcgencmd, llama.cpp build) must run on the Pi 5 itself. Decision: do Phase 0 here where `gh` is already authenticated; the Pi will `git clone` the repo to start Phase 1.
**Improvements/Decisions:**
- Repo created public, as the plan specifies — safe because .gitignore keeps models and copyrighted scans (corpus/own/) local by construction.
**Hardware/Tools used:** Owner's Mac only (git, gh CLI). No Pi or Arduino hardware touched.
**Next:** Phase 1 on the Raspberry Pi 5: clone the repo, record system info in docs/HARDWARE.md, apt full-upgrade, enable SPI, log idle/load temperatures.

## 2026-09-15 — Phase 1: system verification & prep (via SSH from Mac)
**Goal:** Confirm the Pi 5 is healthy and configured before heavy installs: record specs, full OS upgrade, enable SPI, log idle/load temperatures.
**Done:**
- Enabled classic SSH on the Pi (owner ran `raspi-config nonint do_ssh 0` via Raspberry Pi Connect remote shell) and installed the Mac's ed25519 public key; all Phase 1 commands ran over SSH as `yitbarek@raspberrypi.local` (10.0.0.228).
- Recorded specs: Raspberry Pi 5 Model B Rev 1.1, 8GB RAM, 117GB SD (7% used), Debian 13 (trixie).
- `sudo apt update && apt full-upgrade -y` — large upgrade incl. kernel 6.12.47 → 6.18.50; clean reboot onto the new kernel confirmed.
- SPI enabled: `raspi-config nonint do_spi 0`, `get_spi` returns 0 (enabled); `dtparam=spi=on` in config.txt.
- Thermal benchmark (`stress --cpu 4 --timeout 120`):
  | State | Temp | Fan RPM |
  |---|---|---|
  | Idle (fresh boot) | 49.4–50.5°C | ~1150 |
  | Load t+15s | 65.3°C | 2337 |
  | Load plateau (t+75–105s) | 69–70°C | ~3600 |
  | 5s after load | 58.7°C | — |
  `vcgencmd get_throttled` = 0x0 (no throttling, no undervoltage ever).
**Mistakes/Challenges:**
- **Fan not detected at boot.** First readings showed idle temp 70–76°C and NO `cooling_fan` hwmon device; `/proc/device-tree/cooling_fan/status` = `disabled`. Root cause: Pi 5 firmware probes the FAN header only at power-on, and the fan connector was not fully seated when the Pi was first powered. Fix: clean shutdown, owner re-seated the fan connector, power cycle → status `okay`, fan spinning, idle temp dropped ~25°C. Lesson: always verify `cooling_fan/status = okay` after any re-assembly.
- **apt full-upgrade died on a conffile prompt.** `rpi-chromium-mods` hit an interactive prompt for locally-modified `/etc/chromium/master_preferences` under non-interactive stdin: `end of file on stdin at conffile prompt`. Fix: `sudo dpkg --configure -a --force-confold` (keep existing config); `apt-get check` clean afterwards.
- Early network probing from the Mac was misleading: `ping raspberrypi.local` reported "No route to host" while the Pi was actually up (mDNS resolved fine; ICMP blocked/mac local-network permission). Lesson: test the actual port (`nc -z host 22`), not ping.
**Improvements/Decisions:**
- SSH-from-Mac chosen as the working mode (key auth, no passwords); Raspberry Pi Connect kept as fallback/console access.
- Repo not yet cloned on the Pi — docs are maintained in the Mac working copy and pushed. Phase 2 will clone the repo on the Pi.
**Hardware/Tools used:** Raspberry Pi 5 (first hands-on session), active cooler fan (re-seated), owner's Mac as SSH client.
**Next:** Phase 2 — clone repo on the Pi, run scripts/setup.sh (build llama.cpp, download Phi-3 Mini Q4 GGUF), benchmark tokens/sec and RAM.

## 2026-09-15 — Phase 2: LLM engine built, model running, benchmarked
**Goal:** llama.cpp built from source on the Pi, Phi-3 Mini Q4 downloaded, first answer generated, benchmarks recorded.
**Done:**
- Cloned barack-hash/offline-survival-llm to `~/offline-survival-llm` on the Pi.
- `scripts/setup.sh` ran end-to-end: deps installed, llama.cpp built (build b10991-930e2fa59, -j4, ~15 min), Phi-3-mini-4k-instruct-q4.gguf downloaded (2.3GB, no URL 404), venv created with sentence-transformers/faiss-cpu/pypdf/llama-cpp-python/pyserial.
- First on-device answer: bow-drill fire question → coherent, correct 3-step answer.
- Benchmarks (llama-bench, CPU, 4 threads):
  | Test | Result |
  |---|---|
  | pp512 (prompt processing) | 18.69 ± 0.34 t/s |
  | tg128 (generation) | 4.74 ± 0.01 t/s |
  | RAM during inference | 4.4GB used, **3.5GB available** (>3GB criterion met) |
  | Temp during inference | 68.6°C, fan active, no throttling |
- Fixed setup.sh quick-test to pass `-st` (single-turn); committed.
**Mistakes/Challenges:**
- **setup.sh hung forever at the quick test.** Current llama-cli defaults to interactive chat mode; run detached with no stdin it looped printing `> ` prompts. Symptom: log filled with blank prompts, and the log file eventually grew to **3.9GB**, eating SD space. Fix: killed it, trimmed the log, added `-st` to setup.sh. Lesson: never assume CLI flags/behavior are stable in fast-moving projects; run smoke tests with explicit non-interactive flags.
- `-no-cnv` (the old non-interactive flag) is gone in build b10991: `error: invalid argument: -no-cnv`. Current flag is `-st, --single-turn`.
- Self-inflicted: `pgrep -f "llama-cli|setup.sh"` over SSH matches the SSH session's *own* command line, and a `kill` based on it killed my own shell (ssh exit 255, looked like the Pi crashed). Lesson: use `pgrep -x` / `pgrep -fx` for exact matches.
**Improvements/Decisions:**
- Generation is 4.74 t/s — slightly under the 5–10 t/s expectation for Pi 5 + Q4 3.8B. Acceptable for now; potential later tunings (one at a time, per rules): Q4_0 quant with ARM dot-product kernels, `-t 4 --mlock`, or a smaller model if Phase 4 latency feels bad.
**Hardware/Tools used:** Raspberry Pi 5 (all work over SSH). No new physical hardware.
**Next:** Phase 3 — download public-domain corpus texts (FM 21-76 + one more), log them in CORPUS_SOURCES.md, build the RAG index, spot-check retrieval.

## 2026-09-15 — Phase 3: corpus downloaded, RAG index built, retrieval verified
**Goal:** At least 2 public-domain sources in corpus/pd/, indexed with rag_build.py, retrieval spot-checked on fire / water / shelter.
**Done:**
- Downloaded 3 PD texts straight onto the Pi (all as OCR/plain text, verified by reading headers — no 404s; archive.org metadata API used to find exact filenames instead of guessing URLs):
  - fm21-76-survival-manual.txt (559KB) — FM 21-76 US Army Survival Manual
  - first-book-of-farming-1905.txt (403KB) — Goodrich 1905, Project Gutenberg #16900
  - practical-blacksmithing-1889.txt (315KB) — Richardson 1889, archive.org
- All three logged in docs/CORPUS_SOURCES.md with URL/edition/license.
- `rag_build.py`: **1310 chunks** (FM 585, farming 415, blacksmithing 310), index build **2m20s** on the Pi (embedding ~1.9s/batch of 32). index.faiss + chunks.pkl generated, correctly untracked by git.
- Spot-checks (top-3 by L2 distance) — all **PASS**:
  - "start a fire without matches" → FM fire-starting methods + char cloth chunks (dist 0.85–0.94)
  - "purify water for drinking" → FM WATER PURIFICATION + seepage-basin filtration (dist 0.63–0.94)
  - "build a shelter in the wilderness" → FM shelter-site/types + snow shelter (dist 0.62–0.72)
**Mistakes/Challenges:**
- Heredoc-over-SSH with escaped quotes inside an f-string broke (`SyntaxError: unexpected character after line continuation character`). Fix: write the spot-check script to a file and `scp` it — stop fighting three layers of shell quoting.
- Gutenberg search for "blacksmithing" returned nothing; found *Practical Blacksmithing* via archive.org advanced-search API instead.
**Improvements/Decisions:**
- Preferred `_djvu.txt` OCR text over PDFs where available — cleaner input for chunking than pypdf extraction, and 5-10x smaller.
- Corpus files copied back into the Mac working copy so corpus/pd/ is committed (PD texts are allowed in the public repo per .gitignore policy).
- Still missing, needs owner action (licensing — cannot be auto-downloaded): *Where There Is No Doctor* / *Where There Is No Dentist* (FREE, hesperian.org), *The Knowledge* (OWN — buy + scan, goes in corpus/own/, never committed).
**Hardware/Tools used:** Raspberry Pi 5 over SSH. No new physical hardware.
**Next:** Phase 4 — run main.py in keyboard mode, 10-question evaluation with verdicts, confirm critical mode + out-of-corpus refusal.
