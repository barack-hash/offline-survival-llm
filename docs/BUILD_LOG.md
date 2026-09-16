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

## 2026-09-16 — Phase 4 (overnight): eval, engine swap, all criteria pass
**Goal:** 10-question evaluation with verdicts; critical mode verified with verbatim sources; out-of-corpus refusal verified; verify.py with ≥5 real cases running clean. Owner asleep — full permission to test and fix.
**Done:**
- Added Hesperian books (owner-supplied PDFs): corpus/free/where-there-is-no-doctor.pdf + where-there-is-no-dentist.pdf. corpus/free/ gitignored (FREE license ≠ PD). Index rebuilt: **2801 chunks** total (Doctor 1150, FM 585, farming 415, dentist 341, blacksmithing 310), 4m53s.
- Built scripts/eval_questions.py (fixed 10-question battery through main.py's exact pipeline) — 3 full runs + diagnostics.
- **Run 1** (Phi-3, n_ctx 2048): 8/10 answered, template artifacts ('[Response]:', duplicated answers), then **crash** on the critical question.
- **Run 2** (n_ctx 4096): critical question produced **complete gibberish** (word salad at temp 0); out-of-corpus rambled but didn't invent.
- Diagnostics: gibberish reproduced with (a) chat template, (b) fresh Phi-3.1 GGUF, (c) the source-built llama-cli binary → NOT the runtime, NOT the file, NOT the prompt format. Root cause: **llama.cpp renders Phi-3's sliding-window attention (window 2047) as garbage past ~2k tokens** — exactly what critical mode's 8-chunk prompts hit.
- **Engine swap: Qwen2.5-3B-Instruct Q4_K_M** (1.8GB, 32k native ctx) + all generation moved to main.generate_answer() using the model's chat template. Same 3.4k-token prompt now answers correctly, quoting "adults: 1 or 2 tablets (300 to 600 mg.)" verbatim from WTIND.
- **Run 3 verdicts (Qwen):** Q1 fire/wet wood GOOD · Q2 water purification GOOD · Q3 cold shelter GOOD · Q4 edible plants GOOD · Q5 wound care GOOD · Q6 infected tooth GOOD · Q7 seed depth VAGUE (right chunks retrieved, model garbles the 1905 experiment's conclusion) · Q8 forged-knife hardening WRONG-TARGET (retrieval, see below) · Q9 aspirin dose **CRITICAL PASS** · Q10 car firmware **DECLINE PASS**.
- End-to-end main.py keyboard-mode test (piped stdin): ⚠ safety-critical banner, all 8 raw chunks printed verbatim, corroboration = 2 sources (no warning, correct), summary quotes exact dose. **Acceptance criterion met.**
- verify.py: 6 real test cases (incl. critical dose + out-of-corpus canary); full run clean, all sane.
- Filed issue #4: retrieval query-phrasing sensitivity — probe showed 'harden a knife I forged' ranks blacksmithing chunks 7-10 (so TOP_K=6 wouldn't fix it), while 'harden and temper steel in a forge' ranks them 1-10. Deferred with concrete options (query expansion, hybrid BM25+vector, better embedder, header-aware chunking).
**Mistakes/Challenges:**
- The model swap ate the night: n_ctx crash → gibberish → 3 rounds of hypothesis elimination (template? GGUF? runtime?) before landing on the SWA/llama.cpp architecture issue. Each wrong hypothesis is logged above because the elimination order is the useful part.
- Ran a diagnostic from /tmp: `ModuleNotFoundError: No module named 'main'` — scripts importing main.py must run with PYTHONPATH=scripts or from the scripts dir.
- Repeated the pgrep self-match mistake from Phase 2 in a watcher (pattern matched the SSH session's own command line) — caught before it burned anything this time.
**Improvements/Decisions:**
- Qwen2.5-3B-Instruct is the device model now; both Phi-3 GGUFs kept in models/ (gitignored) as evidence/fallback. Qwen research license: fine for personal device use.
- Timings (Qwen, Pi 5): normal answers 65–140s, critical (8-chunk) 160s. Prompt processing 22.3 t/s, generation ~3 t/s at long ctx.
- Known limitations logged rather than over-tuned at 1am: Q7 summarization garble, Q8 phrasing-sensitive retrieval (issue #4). One-change-at-a-time discipline held: n_ctx fix → model+template swap → nothing else.
**Hardware/Tools used:** Raspberry Pi 5 over SSH all night. No physical hardware touched.
**Next:** Phase 5a — Arduino keypad: owner wires the 4x4 keypad per keypad_serial.ino pin map, photographs wiring, flashes the sketch; then serial-mode test + multi-tap issue.

## 2026-09-16 — Remote access: Tailscale, so tuning can continue from anywhere
**Goal:** Owner wants to keep tuning/testing the Pi from work (different network) before the wiring phase.
**Done:**
- Installed Tailscale on the Pi (`curl -fsSL https://tailscale.com/install.sh | sh`, `sudo tailscale up`), owner authorized it; Pi is `raspberrypi` / 100.123.242.97 on the tailnet.
- Owner installed the Tailscale macOS app and signed in (brew cask needed an admin password, so this step was theirs).
- Verified SSH end-to-end over Tailscale; added `Host pi` alias to the Mac's ~/.ssh/config → `ssh pi` now works from any network where both machines are signed in.
**Mistakes/Challenges:**
- `brew install --cask tailscale` fails non-interactively (`installer -pkg` needs sudo) — Mac-side GUI installs need the owner.
**Improvements/Decisions:**
- Tailscale over port-forwarding/dynamic-DNS: no SSH exposed to the internet, no router config. Raspberry Pi Connect kept as an independent browser-based backup door.
- Requirement for remote sessions: Pi powered on at home; both devices signed into the tailnet.
**Hardware/Tools used:** None physical.
**Next:** Phase 5a keypad wiring (owner's hands) — or continued remote eval/tuning sessions (issue #4 retrieval robustness is the queued tuning work).

## 2026-09-16 — Issue #4: hybrid BM25+vector retrieval, hit@4 94%→100%
**Goal:** Fix query-phrasing-sensitive retrieval (issue #4) with ONE measured change.
**Done:**
- Built scripts/eval_retrieval.py: 16 queries with required-source labels (the 10-question battery's targets + 6 phrasing variants), runs in seconds with no LLM. This is the retrieval regression suite now.
- **Baseline (vector-only): 15/16 = 94%** — sole miss is the issue #4 case ('harden the edge of a knife I forged' → blacksmithing book absent from top 4).
- **Change: hybrid retrieval in main.py.** BM25 (rank_bm25) over chunk tokens + FAISS vectors, each contributing a top-20 candidate pool, merged by reciprocal rank fusion (RRF k=60). BM25 index builds in ~2 s at startup, cached. rank-bm25 added to setup.sh.
- **After: 16/16 = 100%**, no regressions on the other 15 queries.
- Full 10-question generation battery re-run (run 4): no regressions Q1–6, Q7 improved (now conveys the too-deep-beans caveat), Q10 still declines, Q9 critical still quotes grounded figures. Q8: blacksmithing source now retrieved, **but the 3B model still synthesizes from FM's wooden-knife chunk** — retrieval layer fixed, generation source-selection remains (noted on issue #4).
**Mistakes/Challenges:**
- None new this session; the probe-first discipline (measure whether TOP_K would even help before touching it — it wouldn't) paid off.
**Improvements/Decisions:**
- RRF over score-mixing: rank-based fusion needs no score normalization between L2 distances and BM25 scores.
- Q9 observation: the critical answer alternates between two grounded passages (Green Pages dosage table vs fever chapter) across runs — both correct quotes; the on-device verbatim chunk display is the real safety net.
**Hardware/Tools used:** Pi over Tailscale (`ssh pi`) — first tuning session through the new remote path.
**Next:** Remaining issue #4 scope (generation prefers wrong retrieved chunk): candidate single changes are source-diversity ordering in the prompt, or a rerank step. Or proceed to Phase 5a when owner is home.
