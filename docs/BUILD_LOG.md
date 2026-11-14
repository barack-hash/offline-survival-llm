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

## 2026-09-16 — Issue #4 closed: the "generation bug" was a corpus gap
**Goal:** Fix the generation side of issue #4 (model answered the forged-knife question from FM's wooden-knife passage even after retrieval was fixed).
**Done:**
- **Change 1 — subject-match prompt rule** (SUBJECT_MATCH_RULE in main.py, added to both system prompts): tells the model to answer only from passages about the question's actual subject and to say so if none match. Q8-only test: did NOT fix Q8. Full battery (run 5): kept anyway — zero regressions, Q6 (tooth extraction) markedly better, Q10 decline crisper.
- **Diagnosis that mattered:** dumped Q8's retrieved chunks — FM's are stone/bone/wood knife content and the 1889 blacksmithing chunk is about re-entering angles. `grep -ci temper practical-blacksmithing-1889.txt` = 21, mostly anvils/dies. **The corpus never contained usable blade-hardening instructions.** No prompt or retriever can fix a missing book.
- **Change 2 — fill the gap:** added Woodworth, *Hardening, Tempering, Annealing and Forging of Steel* (1903, PD, archive.org OCR text, 382 'temper' mentions). Index rebuilt: **3157 chunks / 6 sources** (Woodworth 356).
- Results: eval_retrieval still **16/16** under a stricter expectation (Woodworth must now surface for both blade queries). Q8 retest: correct bladesmithing answer — heat edge to cherry red, oil-quench the edge then let it down into water, warp-straightening tip. Issue #4 closed.
**Mistakes/Challenges:**
- Spent one change chasing a prompt fix for what was actually missing data. The chunk-dump diagnosis should have come FIRST — 'look at what the model was actually given' is cheaper than any tuning run. Logged as the session's lesson.
- Q9 (aspirin, runs 4-5): the model garbles "adults under 12 years old" when summarizing the fever-chapter table. The quoted figures stay correct and the device shows raw chunks in critical mode, but this is a standing reminder that the summary line is the weakest link — the verbatim display is the safety net.
**Improvements/Decisions:**
- eval_retrieval.py knife/temper cases now expect hardening-tempering-steel-1903.txt (the metric got stricter, intentionally).
- Corpus principle learned: for a reference device, coverage gaps masquerade as model stupidity. When an answer is off-subject, check what was retrievable before tuning anything.
**Hardware/Tools used:** Pi over Tailscale.
**Next:** Phase 5a keypad wiring (owner's hands), or further corpus expansion (knots, celestial navigation, basic chemistry per CORPUS_CHECKLIST).

## 2026-09-16 — Corpus expansion: knots, navigation, chemistry (9 sources, 4310 chunks)
**Goal:** Fill the knots / navigation / chemistry rows of CORPUS_CHECKLIST.md with PD texts.
**Done:**
- Added 3 Project Gutenberg texts (plain UTF-8, no OCR noise):
  - Verrill, *Knots, Splices and Rope Work* 1912 (PG #13510) — 89 chunks
  - Draper, *Lectures in Navigation* (US Navy course) 1917 (PG #27642) — 295 chunks
  - McPherson & Henderson, *An Elementary Study of Chemistry* 1906 (PG #20848) — 769 chunks
- Index rebuilt: **4310 chunks / 9 sources**. All logged in CORPUS_SOURCES.md.
- eval_retrieval.py extended to 22 cases (2 per new source: rope joining/splicing, latitude by sun-stars, compass errors, soap from fat+lye, lime burning): **22/22 = 100%**, no regressions.
- CORPUS_CHECKLIST.md brought up to date: 14 items now checked with what satisfied each.
**Mistakes/Challenges:**
- gutendex.com search API was flaky/slow (two searches returned nothing); archive.org's advancedsearch found the Gutenberg-mirrored navigation text (`lecturesinnaviga27642gut`) which gave the PG id.
- scp brace-expansion `{a,b,c}.txt` failed against the remote path (quotes stopped local expansion) — looped single copies instead.
**Improvements/Decisions:**
- Checklist gaps remaining that are auto-fetchable later: solar/wind primer, food preservation/canning, carpentry/masonry, US military first-aid manual, mechanics primer, electricity primer, fiber/rope-making, radio theory. Herbal medicine deliberately deferred — needs the unverified-folk-knowledge framing decision first.
- *The Knowledge* (Dartnell) remains the owner's OWN-license to-do.
**Hardware/Tools used:** Pi over Tailscale.
**Next:** Phase 5a keypad wiring, or the next corpus batch (first-aid manual + food preservation are highest-value).

## 2026-09-16 — Commit attribution fixed + corpus batch 2 (13 PD sources, 6136 chunks)
**Goal:** (a) Re-attribute all commits from the eiQora company identity to the owner personally; (b) add the remaining auto-fetchable corpus batch: first aid, canning, wind power, carpentry, electricity, radio.
**Done — attribution:**
- All 14 commits were authored `eiQora <yitbarekabegaz@eiqora.com>` — the Mac's *global* git config carried the company identity. Rewrote full history (`git filter-branch --env-filter`) to `Yitbarek Tegene <abegazyitbarek@gmail.com>`, force-pushed (`--force-with-lease` with explicit lease sha), realigned the Pi clone with `git reset --hard origin/main`. Global git config switched to the personal identity; eiQora repos must now set theirs locally.
**Done — corpus batch 2 (all PD, provenance in CORPUS_SOURCES.md):**
- FM 21-11 *First Aid for Soldiers* 1943 (129 chunks) · Gray *Every Step in Canning* 1920 (436) · Powell *Windmills and Wind Motors* 1910 (93) · Fairham *Woodwork Joints* 1921 (250) · Morgan *The Boy Electrician* ©1913 (491; edition year verified in the scan before trusting PD status) · Collins *The Radio Amateur's Hand Book* 1922 (427).
- Index rebuilt: **6136 chunks / 15 files (13 PD + 2 FREE)**. eval_retrieval.py extended to **34 cases: 34/34 = 100%**, no regressions.
- CORPUS_CHECKLIST.md: 20 items checked. Remaining: masonry half of carpentry row, fiber/rope-making, water filtration engineering text, mechanics primer, herbal medicine (deferred pending warning-framing decision), The Knowledge (owner OWN), owner's own build notes.
**Mistakes/Challenges:**
- gutendex.com fully down this session — archive.org advancedsearch + Gutenberg cache URLs used instead; Gutenberg-mirror identifiers (`...NNNNNgut`) are a reliable way to recover PG ids.
- The mid-session `git reset --hard` on the Pi (attribution fix) silently reverted the not-yet-committed 34-case eval_retrieval.py to the 22-case version, so the first suite run after the rebuild tested the wrong file (reported 22/22). Caught because the case count didn't match; re-synced and re-ran → 34/34. Lesson: don't interleave history surgery with uncommitted-file workflows on a second machine.
- `filter-branch` refused to run over unstaged changes (stash → rewrite → pop), and `--force-with-lease` needed an explicit sha because the rewrite had also rewritten the local origin/main ref.
**Improvements/Decisions:**
- The Boy Electrician chosen over post-1929 electricity texts specifically because the 1913 copyright was verifiable inside the scan.
**Hardware/Tools used:** Pi over Tailscale.
**Next:** Phase 5a keypad wiring (owner's hands). Corpus is now broad enough that further additions should be demand-driven (add when an eval question exposes a gap, like the Woodworth case).

## 2026-09-16 — Phase 5a prepared: multi-tap keypad + LCD1602 interim display
**Goal:** Owner asked (a) how a digits-only keypad can type questions, (b) whether the starter-kit display can be used. Prepare everything software-side so wiring day is plug-and-play.
**Done:**
- Kit identified from owner's box photo: **LAFVIN Super Starter Kit for UNO R3** — contains everything Phase 5a needs (UNO R3, 4x4 membrane keypad, LCD1602 parallel + 10K pot, breadboard, jumpers). No purchases needed for 5a; HARDWARE.md updated.
- **keypad_serial.ino rewritten**: old-phone multi-tap text entry (2=abc2 … 9=wxyz9, 1=punctuation, 0=space, *=backspace, A=commit, #=send), 1 s letter timeout, question buffered on the Arduino with live LCD preview, only the finished line sent to the Pi. Removed the rotary-encoder code (kit has none). This supersedes the planned digits-only first version — no reason to ship the crippled input when multi-tap fits in the sketch.
- **LCD1602 as interim display**: Arduino shows incoming serial lines across both LCD rows; main.py's SerialKeypadInput gained display_answer() — answers paged at 32 chars / 3 s so the UNO needs no big buffer (2KB SRAM). Critical answers are prefixed `!CRITICAL! verify vs 2nd source:` on the LCD.
- docs/wiring/phase5a-keypad-lcd.md: full pin map (keypad→D2-D9, LCD 4-bit on D10-D13+A0/A1, pot for contrast), flash steps, typing cheat sheet.
**Mistakes/Challenges:**
- Owner's photo was HEIC and over the read size limit — converted/downscaled with sips first.
**Improvements/Decisions:**
- Multi-tap decoding lives on the Arduino, not the Pi: the Pi's serial protocol stays "one line = one question", so main.py needed no input-side changes and the future e-ink phase only swaps the display half.
- Note for wiring day: this supersedes the "digits+A-D only" limitation the plan expected to log; the multi-tap GitHub issue planned in Phase 5a step 5 is no longer needed.
**Hardware/Tools used:** None physically touched (owner away) — kit contents identified from photo.
**Next:** Wiring day: owner wires per docs/wiring/phase5a-keypad-lcd.md, photographs it, flashes the sketch; then INPUT_MODE="serial" end-to-end test and the first hardware-typed question gets logged verbatim.

## 2026-09-18 — Phase 5a COMPLETE: defective keypad forensics, IR-remote pivot, first hardware question
**Goal:** Wire keypad + LCD, flash, and get the first question asked entirely on device hardware.
**Done:**
- LCD1602 turned out to be the I2C-backpack variant → 4-wire hookup (GND/5V/A4/A5), sketch moved to LiquidCrystal_I2C. Worked first try (address 0x27).
- Toolchain: arduino-cli on the Mac (needed Rosetta 2 — bundled avr-gcc is x86-only), flashing over /dev/cu.usbmodem1101.
- **Keypad forensics** (the night's saga, in order):
  1. First test: phantom 'A' flood + missed presses.
  2. Raw-key diag sketch: ~40 events for 4 presses, mostly 'A'.
  3. Board went totally silent + bootloader 'not in sync' → **power cycle fixed it** (chip was wedged; lesson: power-cycle before suspecting wiring).
  4. Wiring-agnostic pair-scan sketch (drive each of D2-D9 low, watch the rest): pairs **D2-D9 and D4-D6 stream continuously with no key pressed** = keys 'A' and '0' electrically stuck.
  5. Isolation: shorts persist with keypad dangling in air (not table pressure); one-by-one unplug timeline showed shorts follow the keypad wires; all-unplugged = silent (Arduino + jumpers healthy); **only ribbon wires 1+8 reconnected → D2-D9 short returns instantly with no touch. Verdict: membrane internally shorted (lines 1-8, 4-6). Defective from factory.**
- **Pivot: kit's NEC IR remote as input device.** IR receiver (G/R/Y → GND/IOREF/D2, 3 wires). Scanned all 17 buttons (owner pressed sequence; one accidental extra ◀ press was identifiable in the timeline) — codes match the documented LAFVIN/Elegoo NEC map. New scripts/ir_remote_serial.ino: same multi-tap scheme (2=abc...), *=backspace, 0=space, #=send, OK=commit-letter, arrows reserved; NEC repeat frames ignored.
- Standalone proof: owner typed **"fire"** on the remote → arrived verbatim over serial.
- Hiccups on the way: remote's battery pull-tab still in (found via phone-camera IR test), IOREF used as second 5V source (LCD holds the only 5V socket), two Mac serial listeners colliding on the port.
- **MILESTONE:** Arduino moved to the Pi (/dev/ttyACM0), main.py in serial mode. First hardware question: **"fire"** → grounded FM 21-76 answer (tinder/kindling/fuel progression, upwind placement, sawdust/salt-brine reignition), paged on the LCD at 32 chars/3s. On-device perf: prompt 26.5 t/s, generation 5.47 t/s, 82 s total.
- Photos in docs/wiring/ (keypad-era wiring + IR remote). HARDWARE.md updated incl. the defective part.
**Mistakes/Challenges:** all inline above — this session WAS the mistakes. Biggest lessons: (1) a component can be dead from the factory — build the diagnostic before re-wiring in circles; (2) when serial dies AND flashing dies, power-cycle first; (3) `pgrep -f` self-match bit again on the Mac (port cleanup).
**Improvements/Decisions:**
- IR remote is now the primary input (arguably better for the enclosure: sealed pocket, no ribbon passthrough). keypad_serial.ino kept in repo for a future replacement pad.
- Multi-tap GitHub issue from the original plan is moot (implemented from day one).
**Hardware/Tools used:** Arduino UNO R3, LCD1602 (I2C), IR receiver + remote (first use), defective 4x4 membrane keypad (diagnosed), breadboard/jumpers, owner's phone camera as IR detector.
**Next:** Leave device running for daily use; Phase 5b when e-ink arrives; Phase 6 shopping (UPS HAT, 18650s, solar panel). Optional: replacement keypad (issue #6).

## 2026-09-18 — Appliance mode: systemd service, survives power-on unattended
**Goal:** Device must serve its purpose the moment power arrives — no SSH, no manual start.
**Done:**
- scripts/survival-llm.service added to the repo and installed: Restart=always/RestartSec=5 (retries until the Arduino enumerates), TimeoutStartSec=300 for the model load, no network dependencies by design, Nice=-5.
- Killed the old nohup-run main.py, enabled the service, verified `assistant ready` in the journal.
- **Cold-boot test: `sudo reboot` → service auto-started → ready ~60 s after power-on** with zero human involvement.
- Owner's post-reboot question via IR remote: "i am stranded on an island" → full 399-token grounded answer paged on the LCD. Timing measured: prompt 26.5 t/s, generation 5.44 t/s, 127 s total for a maximum-length answer.
**Mistakes/Challenges:**
- First reboot-watcher script had a race (checked the journal before the boot had anything in it) — re-checked manually.
**Improvements/Decisions:**
- Open-ended prompts generate the full 400-token budget (~2 min). Acceptable for now; if field latency ever matters, options are max_tokens reduction or a smaller quant — one change at a time, measured.
- journalctl -u survival-llm is now the device's flight recorder (questions, answers, perf lines all land there).
**Hardware/Tools used:** Pi 5 + full input/display stack (first unattended cold boot of the complete device).
**Next:** Daily-driver period; Phase 5b/6/7 as hardware arrives (issues #1-#3).

## 2026-09-24 — Phase 7 started early: parametric enclosure draft v0.2
**Goal:** Design the enclosure before ordering a 3D print, around the parts chosen in the shopping sessions (Waveshare 4.2" e-ink, M5Stack CardKB, Geekworm X1202 + 4× 18650, Pi 5).
**Done:**
- enclosure/enclosure.scad: fully parametric OpenSCAD model — rear tub (stack guides, M3 insert bosses, intake/exhaust vents, X1202 USB-C + DC-jack cutouts, lanyard tab, grip grooves, rubber-feet pockets, engraved charging + safety text), front bezel (chamfered screen window, keyboard opening with shallow recess, rivet ring, M3 counterbores, alignment lip, engraved label), retainer plate (raised frames clamp screen + keyboard against the bezel, open centres for cables, notch for the CardKB Grove cable).
- Outer size 109.4 × 169.9 × 74.3 mm (+7 mm lanyard tab).
- enclosure/viewer.html: three.js viewer (orbit, explode slider, show/hide parts, ghost electronics) served locally; STLs rendered with OpenSCAD CLI.
- Two iterations: v0.1 (functional shell) → v0.2 after reviewing renders (edge chamfers, grip grooves, larger label, rear engraving, feet pockets).
**Mistakes/Challenges:**
- `brew install --cask openscad` fails: cask disabled 2026-09-01 ("does not pass the macOS Gatekeeper check"). `openscad@snapshot` (2026.09.23) installs and works.
- First viewer render showed the device lying face-up: I rotated the model -90° about X, but OpenSCAD's axes (X width, Y height, Z out of the face) already match three.js's camera frame. Removed the rotation.
- Preview server config had to live at the DoomsDay root `.claude/launch.json`, not inside the repo folder.
- Corrected earlier shopping advice: X1202 needs **unprotected flat-top** 18650s (≤18.5 mm dia, ≤65.3 mm long).
**Improvements/Decisions:**
- Engraved the device's safety rule on the back ("reference aid — not a sole authority for medical dosing, structural or electrical decisions"), matching CLAUDE.md.
- 74 mm depth is driven by the 4-cell X1202 stack (56 mm assumed). Slimming ideas deferred until the real stack is measured.
- Every datasheet-derived size is tagged VERIFY; STLs are explicitly draft until parts are measured with calipers.
**Hardware/Tools used:** None physical. OpenSCAD 2026.09.23 snapshot, three.js 0.160 viewer.
**Next:** When parts arrive: caliper-measure stack height, e-ink module + glass + active area, CardKB thickness, X1202 port positions → update VERIFY params → test-print the bezel only (cheapest fit check) before the full enclosure.

## 2026-09-24 — Enclosure v0.3: real part dimensions + slim stepped profile
**Goal:** Make the enclosure slimmer and size it to the exact screen and keyboard being bought.
**Done:**
- Pulled manufacturer dimensions: Waveshare 4.2" e-Paper Module manual (driver board 103.0 × 78.5 mm, display 84.8 × 63.6 mm, panel 90.1 × 77.0 × 1.18 mm; new units ship V2 with partial refresh), M5Stack store (CardKB v1.1 88.0 × 54.0 × 5.0 mm, I2C 0x5F, $7.95 direct vs $18.99 on the Amazon clone listing).
- CardKB is 4 mm wider and 3.5 mm thinner than v0.2 assumed (84 × 54 × 8.5).
- Re-laid out the enclosure: the Pi/X1202 stack (85 mm tall) sits only behind the screen band; the keyboard section is thin. Depth **74.3 mm → 59.2 mm behind the screen, 11.4 mm at the keyboard.**
- Stack height re-estimated to 48 mm (cells + X1202 + spacers + Pi 5 + cooler; Geekworm's own case is 62.8 mm outside, an upper bound) — still VERIFY.
- Structure changes: screws at the top corners + beside the keyboard; bezel hooks into snap windows along the bottom edge (too thin there for inserts); keyboard held against the bezel by floor rails + 1 mm foam, rails split for the CardKB cable; screen clamped by a slim retainer ring on four bezel posts.
- Viewer: added a Side view (the profile is the point of this revision).
**Mistakes/Challenges:**
- First v0.3 render: the back sloped in one straight line from the stack all the way to the bottom edge, so the keyboard section was nearly full depth. Cause: I built the body with `hull()` of a thick slab and a thin slab — hull is always convex and cannot make the concave "thin, then step up" corner. Fix: body is now a side-profile polygon extruded across the width, intersected with the rounded plan outline. The Side view caught it immediately.
**Improvements/Decisions:**
- Kept the screen landscape (wider text lines) — portrait would save ~5 mm of width but halve line length on a text device.
- Didn't swap the Pi active cooler for a passive heatsink to save height: Phase 1 measured 70 °C at full load *with* the fan; losing it risks throttling during inference.
**Hardware/Tools used:** None physical.
**Next:** Measure the real stack height and screen connector clearance when parts arrive — those two numbers set the final depth.

## 2026-09-24 — Enclosure v0.4: airflow redesign + steampunk styling
**Goal:** Make the enclosure look steampunk and design the airflow so the Pi stays cool inside it.
**Done:**
- **Airflow problem found in v0.3:** the Pi 5 active cooler's fan draws air in through its top, which faced the screen with only ~2.6 mm of clearance — the fan would have been starved and recirculating its own hot air, and the e-paper panel (typically rated to ~50 °C) sat directly over the SoC.
- **Fix: flipped the stack** — Pi + cooler face the back wall, X1202 + 4× 18650 face the screen. Fan now breathes through a porthole intake grille in the back wall (concentric rings + 6 spokes, ~70% open), with a 2 mm fan gap. The battery pack shields the screen from Pi heat and keeps the cells cooler (18650 charging limit ~45 °C).
- Chimney path: cool air in via porthole + low side vents, hot air out via upper side louvers + top-edge vents (all vent bands moved down to the cooler's level at the back). 4 mm domed standoff feet keep the porthole breathing when laid on its back.
- X1202 charge-port height moved to ~29 mm (it's now the front board of the stack) — VERIFY.
- **Steampunk details:** bead frames around screen and keyboard; riveted triangular corner brackets on the screen frame; riveted raised brass nameplates ("OFFLINE SURVIVAL REFERENCE", "FIELD REFERENCE MK I"); framed, riveted steam-vent plates on the side louvers and top vents; rivet line around the back plate; brass gear ring around the porthole as a separate `trim` part for two-colour printing.
- enclosure/render.sh re-renders all parts and writes stl/layout.json; viewer gained Brass trim + Airflow toggles (arrows positioned from the model's own numbers).
- Depth: 61.2 mm behind the screen (+2 mm for the fan gap vs v0.3), 11.4 mm at the keyboard, +4 mm feet.
**Mistakes/Challenges:**
- The v0.3 layout had the thermal problem baked in; I only caught it by asking where the fan actually takes its air from. Lesson for the log: design the air path first, then the shape around it.
- Write tool refused to overwrite enclosure.scad ("modified since read") because an earlier python patch had touched it — re-read, then wrote.
**Improvements/Decisions:**
- Decorative trim as a separate glue-on part so the shell can print in one colour and the brass details in another.
- Assumptions to verify on hardware: fan position on the stack (`cooler_off`), which way the cooler exhausts, and the real stack height.
**Hardware/Tools used:** None physical.
**Next:** When the enclosure is printed: log idle + inference temperatures enclosed vs open-air (Phase 1 baseline: 49 °C idle, 70 °C full load) — that's the acceptance test for this airflow design.

## 2026-09-24 — Enclosure v0.5: copper pipe details
**Goal:** Copper pipe details along both sides (steampunk).
**Done:**
- New printed part `pipes`: one pipe run per side that follows the enclosure's profile — down the thick section at 40 mm depth, a 45° elbow down the sloped step, then along the thin keyboard section. End flanges, elbow collars, 4 riveted pipe clamps per side, a pressure gauge (dial ticks + needle) on the left and a hex-body valve wheel on the right.
- D-profile pipes (flat back against the wall, centreline 0.35 r into the wall) so the part prints flat-back-down without supports and glues on; copper filament intended.
- Placement checked against every side feature: vent plates stop at 23 mm depth (pipe starts at 37.4); DC jack (26.7–35.7 mm deep at y 90.5–99.5) and USB-C (≤33.1 mm deep at y 130–140) clear the pipe and every clamp foot; on the thin section the pipe sits 0.6 mm above the back surface and under the bezel parting line.
- render.sh + viewer updated (pipes grouped with the brass trim toggle).
**Mistakes/Challenges:**
- None this round; the first clamp spacing (every 24 mm from the top) would have put a clamp foot over the DC jack on the right side — caught in the placement check before rendering, clamps moved to y = 146/122/80.
**Improvements/Decisions:**
- Pipes as a separate part (not part of the shell) keeps the shell's walls simple and lets the colour differ.
**Hardware/Tools used:** None physical.
**Next:** Unchanged — measure the real stack, screen connector clearance, fan position and port positions when parts arrive; then test-print the bezel.

## 2026-09-24 — Enclosure v0.6: the pipes become working conduits
**Goal:** Owner: "everything needs to serve a use" — make the copper pipes functional instead of decorative.
**Done:**
- Pipes are now cable conduits: 3/8" OD soft copper tube (7.9 mm bore), buildable from real copper + real 3/8" brass compression elbows/tees, or printed.
- **Left = data line:** USB 2.0 (load new books/manuals from a stick, backups), AUX I2C accessory port (external sensor modules on the same bus as the CardKB), and the gauge's RGB LED.
- **Right = power line:** 6–18 V solar/car DC input (pigtail from the X1202's DC jack) and the power-button wires.
- **Gauge = real status light** (5 mm RGB LED behind a translucent dial; battery level from the X1202 fuel gauge, "thinking" pulse) — faces forward so it's visible while reading. Covers e-ink's weakness at showing activity.
- **Valve wheel = real power button** (6×6 tactile switch in the valve body, wheel is the cap, wired to the Pi 5 J2 header); recessed below the front face so it isn't pressed by accident.
- **Junction box** under the step (behind the thin keyboard section): SOLAR 6-18V / USB / AUX I2C ports on its bottom face, screwed lid with engraved labels, fixed by 2 screws from inside the tub. Protected when held and when lying on its back.
- Lines enter the case through glands in the top face; the loops over the top corners double as roll bars. Top screw bosses moved inboard (x = 22 mm) and the top retainer posts to ±25.5 mm to clear the glands. X1202 DC cutout on the side wall removed (DC now via the junction box); USB-C 5 V 5 A stays direct.
- Model echoes per-side copper tube cut lengths; new parts: fittings, manifold, manifold_lid, gauge_face, valve_cap. docs/wiring/plumbing-conduits.md has the wire-by-wire plan and parts list.
- Size with plumbing ≈ 135 × 189 × 67 mm (from 122 × 177 × 67).
**Mistakes/Challenges:**
- First plumbing draft had the pipe clamps poking ~1 mm into the side wall (clamp radius exceeded the pipe's standoff) and fittings with only a wire bore where the tube needs a socket — both caught reviewing the code before the first render; clamps now clipped to outside the wall, fittings bored to tube OD + 0.15.
- Constraint worked around: USB/DC connectors don't fit a 7.9 mm bore, so the plan uses solderable breakouts soldered after pulling wires through.
**Improvements/Decisions:**
- Real 3/8" copper + brass compression fittings recommended over printed pipes: authentic, far stronger as roll bars, and standard hardware-store parts.
- USB-C charging not extended through a pipe (5 A through an extension is a needless risk).
**Hardware/Tools used:** None physical.
**Next:** Unchanged measurement list, plus: confirm the Pi 5 J2 button behaviour with the X1202 attached, and pick I2C accessory modules whose addresses don't clash.

## 2026-10-02 — Cost-down research: boards, models, enclosure printing
**Goal:** Owner wants to sell the device — find where cost can come down (cheaper boards, Gemma models, voice), and price the enclosure print.
**Done:**
- Three parallel research passes (models on cheap boards, current hardware prices, 3D-print services); results with sources in docs/COSTS.md.
- Measured the v0.6 enclosure STLs: 155 cm³ ≈ 190 g PLA for the full set (rear shell alone 126 g).
- Key findings: Pi prices up 3× since Dec 2025 (Pi 5 8GB $175, 4GB $110, 2GB $65–78); non-Pi boards no cheaper or unavailable in the US; Gemma 4 (2026-04-02) E2B runs ~7 tok/s on Pi 5 in 3.2 GiB but its audio input isn't dependable in llama.cpp yet; Pi 4 and Zero 2 W are dead ends; NPU HATs slower than the Pi 5 CPU for LLMs.
- Tiers: current ≈ $330 core, Pi 5 4GB ≈ $265, lean Pi 5 2GB + 1.5B model ≈ $200–215 (+ plumbing).
- Enclosure: Arlington library PLA $0.05/g ≈ $10/set (local); home A1 ≈ $4–5 filament/set; JLC3DP now carries +40% US duty.
**Mistakes/Challenges:**
- Tried to measure the device's LLM-only RAM to settle the 4GB question; the Pi was unreachable (both LAN and Tailscale timed out) — deferred.
- Research sources disagreed on Pi 5 4GB/8GB prices ($85/$125 Feb-2026 articles vs $110/$175 fetched retailer pages) — used the fetched retailer prices.
**Improvements/Decisions:**
- Biggest lever is RAM tier + model size, not board brand. Cheapest safe path to test first: Pi 5 4GB with the current model if it fits.
**Hardware/Tools used:** None physical.
**Next:** When the Pi is on: measure LLM-only RSS; benchmark Gemma 4 E2B and Qwen2.5-1.5B through the eval battery; bezel fit-test print.

## 2026-10-02/04 — Remote scrolling + Gemma 4 model shoot-out
**Goal:** (1) Arrow keys on the IR remote scroll answers on the 16×2 LCD; (2) research whether Google's Gemma 4 is better/smarter/faster than the current Qwen2.5-3B.
**Done:**
- Scrolling: Pi keeps the word-wrapped answer and sends the 2 lines in view; ▼/▲ one line, ▶/◀ one screen, "-- end --" at the bottom; arrows ignored while typing or while generating. Replaced the 3 s auto-paging. Offline-tested with a fake serial port, then flashed **from the Pi** (installed arduino-cli 1.5.1 + AVR core on the Pi; sketch 36% flash / 49% RAM). Not yet tested by the owner on hardware.
- Research agent (published evidence) + on-device shoot-out of 4 models with scripts/eval_models.py; full results in docs/benchmarks/2026-10-02-model-shootout/.
  | Model | Gen tok/s | Median answer | LLM RAM | Score /26 |
  |---|---|---|---|---|
  | Qwen2.5-3B (current) | 5.36 | 96 s | 4.2 GB | 21 |
  | Qwen3-4B-2507 | 3.28 | 188 s | 5.4 GB | 23 |
  | Gemma 4 E2B | 5.98 | 56 s | 4.1 GB | 21 |
  | Gemma 4 E4B | 3.10 | 136 s | 6.5 GB | 24 |
- All four refused all out-of-library questions and got both critical doses numerically right.
**Mistakes/Challenges:**
- `git push` → `remote: Permission to barack-hash/offline-survival-llm.git denied to eiQora` (403): the active gh account had switched to eiQora. Fixed per-repo (remote URL with barack-hash username + repo-local credential helper calling `gh auth token -u barack-hash`) instead of `gh auth switch`, which would change the owner's global state.
- arduino-cli install script on the Pi failed silently: BINDIR ~/.local/bin didn't exist. Created it, reran.
- **Thermal throttling found:** sustained ~2 h inference reached 84.5 °C with the fan at max (5151 rpm), throttled=0xe0008. Phase 1's 2-minute stress test (70 °C) was too short to show heat soak — a wrong assumption carried since Phase 1. Every shoot-out number is a throttled number (fair across models). Filed as issue #8; affects the enclosure airflow design. (First filed as #7 by mistake from the eiQora gh account — closed as duplicate; gh issue/PR commands for this repo now run with GH_TOKEN=$(gh auth token -u barack-hash).)
- The research agent's "Gemma 4 E2B ≈ 4 tok/s on Pi 5" didn't hold here (measured 6.0) — on-device measurement beats published numbers.
- The local SSH launcher for the shoot-out was killed at its 30-min background limit; the run itself was nohup'd on the Pi and unaffected (by design).
**Improvements/Decisions:**
- No model switch yet — owner decides. Gemma 4 E2B = same quality, ~1.7× faster answers; E4B = most accurate but needs the 8 GB board and is slower.
**Hardware/Tools used:** Pi 5 + Arduino UNO (reflashed from the Pi), IR remote, LCD1602.
**Next:** Owner tests scrolling; decide on model; better cooling before the enclosure.

## 2026-11-12 — Project license: MIT
**Goal:** Give the public repo a license — attribution, limited liability, clear terms for contributors.
**Done:**
- Added `LICENSE` (MIT, © 2026 Yitbarek Tegene) and a License section in README.md stating its scope.
**Mistakes/Challenges:** None.
**Improvements/Decisions:**
- MIT over GPL-3.0: owner's goals were attribution + an "as is" liability shield + low friction for contributors; MIT gives all three and is the most widely accepted license for contributions and reuse. GPL (copyleft — modified versions must stay open) remains a one-file swap if the owner prefers it.
- Scope made explicit: the MIT license covers the project's own code, docs and enclosure design only. `corpus/pd/` texts are public domain (not ours to license); `corpus/free/` and `corpus/own/` are never committed.
**Hardware/Tools used:** None.
**Next:** Unchanged.

## 2026-11-13 — Reconnection guide for the bench setup
**Goal:** Owner disconnected every wire (IR receiver, LCD, Arduino, Pi) and needs an easy visual guide to put the Phase 5a setup back together.
**Done:**
- Built an interactive bench guide (docs/wiring/reconnect-guide.html, also published as a private claude.ai artifact): pin-accurate UNO header drawing, every wire colour-coded, 10 ordered steps that highlight their own wire, remote cheat sheet, troubleshooting from past sessions.
- Wiring taken from the current sketch (scripts/ir_remote_serial.ino) and the 2026-09-18 log: LCD GND→GND, VCC→5V, SDA→A4, SCL→A5; IR G→GND (top row), R→IOREF, Y→D2; Arduino USB-B → any Pi USB-A; Pi power last. No reflash needed (sketch stays in flash).
**Mistakes/Challenges:** None on hardware. In the drawing, bottom-row pin labels were first drawn over the pins (wrong text-anchor after rotation) — fixed before publishing.
**Improvements/Decisions:** The guide is the reconnection reference from now on; update it when the e-ink screen or CardKB replaces the LCD/IR remote.
**Hardware/Tools used:** None this session (guide only; owner rewires).
**Next:** Owner rewires, powers up, tests "fire". Then the outstanding items from 2026-10-04: test arrow-key scrolling, choose the model, improve cooling (issue #8).

## 2026-11-13 — Health check: service crash loop fixed + LEARNINGS.md introduced
**Goal:** Owner asked whether the Pi is OK and running well. Then: create a lessons file (every error, with why and how), make it a rule in CLAUDE.md, and fix and log the problem found.
**Done:**
- Health check over SSH (LAN): Pi 5, idle 45 °C, `throttled=0x0`, 7.2 / 7.9 GB RAM available, SD 31% used (78 GB free), no failed units, no `-p err` journal entries in 24 h, all 6 models + index.faiss + chunks.pkl + venv + llama.cpp present.
- **Found:** `survival-llm.service` crash-looping: 27 restarts in 9 min, `SerialException: could not open port /dev/ttyACM0` because no Arduino was attached (`lsusb` showed only root hubs). Each cycle reloaded the ~1.8 GB LLM first.
- New **docs/LEARNINGS.md**: template, rules and index, seeded with 13 past lessons pulled from this log (L-001…L-013), plus today's L-014…L-016.
- **CLAUDE.md** (repo + DoomsDay root copy): new mandatory item 2 (LEARNINGS.md: exact error, why, how, verification, prevention) and two working-style rules (log in LEARNINGS when something fails; search LEARNINGS before debugging). Later items renumbered 3–6.
- **scripts/main.py:** new `wait_for_serial()`. The serial port is now opened **before** any model loads and waited for in-process (2 s polls, one log line per minute). The model load moved after the input device. `survival-llm.service` is unchanged.
- Deployed to the Pi (scp, then restart) and measured:
  | | Before | After (no Arduino) |
  |---|---|---|
  | Restarts | 27 / 9 min | 0 / 2.5 min |
  | Temp | 51.6 °C, fan on | 46.6 °C, fan off |
  | Load avg 1 min | 0.73 | 0.06 |
  - Simulated port (pty → /dev/ttyACM0): found after 164 s, ready 7 s later.
  - Owner plugged in the real Arduino Uno at 20:52:42 → ready at 20:52:57, service holding /dev/ttyACM0. After: 45.0 °C, `throttled=0x0`, 4.8 GB RAM available with the model loaded.
**Mistakes/Challenges:**
- `ssh pi` → `ssh: connect to host 100.123.242.97 port 22: Operation timed out`. Tailscale was stopped on the Mac (`Tailscale is stopped.`), and the Pi was fine. Used `yitbarek@raspberrypi.local` instead (L-015).
- Root design flaw (L-014): the 2026-09-18 appliance-mode test only covered "Arduino present". With it absent, `Restart=always` retried the most expensive step (the model load) every ~19 s.
- My first Python patch of CLAUDE.md silently skipped the working-style edit: the match string had 3-space indentation and the file uses 2. Caught by reading the result and redone with a direct edit.
- Near miss (L-016): the fake-port test's cleanup `sudo rm -f /dev/ttyACM0` ran 2 s after the owner plugged in the real Arduino. The real node survived, but the method was unsafe.
- Unplug-while-running still costs one restart + model reload (`SerialException: device reports readiness to read but returned no data`, NRestarts=1). Logged as a known limitation in L-014.
**Improvements/Decisions:**
- Wait in-process instead of tuning systemd (e.g. `RestartSec`, `ConditionPathExists`): a condition would skip the start rather than wait, and longer restart delays still reload models. Waiting before the expensive work fixes the cause. `Restart=always` stays as a safety net.
- LEARNINGS.md is separate from BUILD_LOG on purpose: the log is chronological, while learnings are searchable by symptom and track repeats ("Seen again").
**Hardware/Tools used:** Pi 5 over SSH (LAN); Arduino Uno R3 (owner re-connected it during the session).
**Next:** Owner: type a question on the IR remote to confirm end-to-end after the fix. Optional: in-process serial reconnect (L-014 limitation). Optional: `Storage=persistent` journald so crash history survives reboots (no previous-boot logs were available today).

## 2026-11-13 (cont.) — Remote "not writing anything" after rewiring
**Goal:** Owner reported that the IR remote wasn't typing after reconnecting the bench.
**Done:**
- Journal showed no question since the service became ready (20:53:03).
- Paused the service and ran a raw serial capture from the Pi (180 s). Sent an LCD test line and received `^U` at 20:55:58 and the question `bd` at 20:56:08. That proves the remote, IR receiver, sketch and USB link all work. Service restarted and was ready at 20:58:57.
- Owner confirmed: "Yes, it works". The process then used ~5 min CPU answering, the SoC reached 76.8 °C, and `throttled=0x0`.
- LEARNINGS: L-017 (resolved, cause unconfirmed) and L-018 (open: journal output buffered).
**Mistakes/Challenges:**
- Couldn't see what the owner typed: letters stay on the Arduino until `#`, unscrolled arrows aren't logged, and (L-018) stdout to the journal is block-buffered, so even answered questions never showed up. The device's "flight recorder" has been mostly empty since 2026-09-18 without anyone noticing.
**Improvements/Decisions:**
- Raw serial capture is now the first diagnostic after any rewiring (recorded in L-017).
**Hardware/Tools used:** Arduino Uno R3, IR receiver + remote, LCD1602 (I2C): the owner's rewired bench.
**Next:** Fix L-018 (`PYTHONUNBUFFERED=1` in the unit). Then the speed work: stream answers to the LCD, and Gemma 4 E2B. Each change measured separately.

## 2026-11-13 (cont.) — L-018 fixed: questions and answers now reach the journal live
**Goal:** Make the journal a working flight recorder (owner: "Yes, fix it").
**Done:**
- `scripts/survival-llm.service`: added `Environment=PYTHONUNBUFFERED=1`. Installed to /etc/systemd/system, daemon-reload, restart at 21:12; env confirmed in /proc.
- Verified with a real remote question: `> fire making` logged at 21:14:12, answer + perf at 21:16:02.
  | Measure | Value |
  |---|---|
  | Prompt | 1371 tokens, 51.7 s, 26.5 tok/s |
  | Generation | 317 tokens, 58.1 s, 5.46 tok/s |
  | Total | 110 s |
  | Temp after answer | 47.7 °C (idle again) |
- Note for the speed work: reading the prompt is 47% of total time, before the first word is ready. That confirms passage length and live text on the LCD as the first levers.
**Mistakes/Challenges:**
- Restarted the service while it was at 47.5% CPU, possibly cutting off an answer the owner was waiting for. Should have checked first (recorded in L-018).
- The background `journalctl -f | grep | head` watcher over SSH captured nothing, even though the lines were in the journal. Likely output buffering in the remote pipe. Checked the journal directly instead.
**Improvements/Decisions:**
- Env var in the unit rather than `python -u`: it's documented next to the reason, and it covers any subprocess Python too.
**Hardware/Tools used:** Pi 5, Arduino + IR remote (owner asked the test question).
**Next:** Speed work, one change at a time: (1) stream answers to the LCD, (2) Gemma 4 E2B.

## 2026-11-13 (cont.) — Speed work #1: answers stream onto the LCD as they're written
**Goal:** Owner asked for faster answers that still save battery. The first change (per the one-change-at-a-time rule) is to show words on the LCD while the model writes, instead of after the whole answer.
**Done:**
- `scripts/main.py`:
  - `generate_answer(..., on_text=None)` streams when given a callback. Same messages, temperature and max_tokens, and the non-streaming path (verify.py, eval scripts) is unchanged.
  - `SerialKeypadInput.stream_answer()` shows the newest two wrapped lines, throttled to 2 updates/s. Critical mode pins `!CRITICAL!verify` on the top row.
  - The finished answer still switches to the normal scrollable view with `-- end --`.
  - New journal line: `[timing] first words on LCD X s, full answer Y s`.
- Tested on the Pi in a separate process, with a fake serial port recording every LCD write:
  | Question | First words on LCD | Full answer | Before (LCD blank until done) |
  |---|---|---|---|
  | "fire making" | **53.1 s** | 116.2 s | 110 s (owner's run, 21:14) |
  | "what is the dose of aspirin for an adult" (critical) | 131.3 s | 138.0 s | 135.9 s |
- Consistency at temperature 0 (fresh `llm.reset()` before each run): plain vs plain **identical**, streamed vs plain **identical**.
- Every-frame check: 113/113 critical frames carry the warning, and all frames are exactly 32 characters.
- Deployed at 22:03:57 after confirming the service was idle (0% CPU, no question in the last 3 min). NRestarts=0.
**Mistakes/Challenges:**
- **L-019 (safety, caught before deploy):** the first test showed `verify vs 2nd   source. The` as the first critical frame. The `!CRITICAL!` prefix had already scrolled off the follow-the-newest-lines view. Fixed by pinning the warning row.
- **L-020:** the first stream vs non-stream comparison said "differs", but the non-stream run took 7.2 s because llama-cpp-python reused the identical prompt's KV cache. Re-ran with `llm.reset()` plus an A-vs-A baseline, and the answers are identical.
- The first launch over SSH hung the local command until its 60 s timeout (nohup'd process inherited the SSH session's stdio). Fixed by running it in a subshell with `< /dev/null`.
- Thermal: `throttled=0x80000` after test 1 and `0xe0000` after test 2 (soft temperature limit + frequency capping/throttling occurred since boot; peak read 78.5 °C). Back-to-back critical prompts reproduce issue #8. Timings above may be slightly throttled.
**Improvements/Decisions:**
- Streaming makes no difference for critical questions (first words at 131 s of 138 s): reading the 8-chunk prompt is ~95% of their time. For normal questions it halves the wait to first words. The next lever is prompt length (fewer or shorter chunks), which helps both and saves battery. Critical mode's 8 verbatim chunks stay, per the safety rules; only chunk size could change there.
- Throttle at 0.5 s: about 2 LCD redraws per second keeps up with ~5.5 tok/s without flicker or overrunning 9600 baud (33 bytes ≈ 34 ms per frame).
**Hardware/Tools used:** Pi 5 (test runs + deploy).
**Next:** Owner confirms on the real LCD. Then speed work #2: Gemma 4 E2B or prompt length, measured on its own.

## 2026-11-13 (cont.) — Streaming confirmed on the real LCD
**Goal:** Owner hardware check of speed work #1.
**Done:**
- Owner asked "fly" on the IR remote at 22:18:55 and confirmed: "Yes, words stream".
- Journal (new `[timing]` line working): **first words on LCD 52.7 s, full answer 86.8 s**. Prompt 1380 tokens in 51.9 s (26.6 tok/s), generation 186 tokens in 33.8 s (5.50 tok/s). Matches the bench test (53.1 s).
- Temperature after: 59.8 °C. `throttled=0xe0000` is the sticky since-boot flag from the earlier back-to-back tests.
**Mistakes/Challenges:** None.
**Improvements/Decisions:** Speed work #1 accepted on hardware.
**Hardware/Tools used:** Pi 5, Arduino Uno + IR remote + LCD1602.
**Next:** Speed work #2, one change only: shorter prompt (chunk size/count for normal mode) or Gemma 4 E2B. Measure the first-words time and run eval_retrieval / the question battery for quality.

## 2026-11-14 — Speed work #2 (measured, not deployed): 3 passages instead of 4
**Goal:** Owner chose "shorter prompt" as the next speed change. One change only: TOP_K 4 → 3 for normal questions (critical stays at 8).
**Done:**
- Token breakdown (Qwen tokenizer): system prompt 289 tokens (critical 344); passages mean 285 tokens (median 266, max 676). Mean prompt: k=4 1439, **k=3 1163**, k=2 877, k=1 594.
- Retrieval suite: 34/34 at k=3 and k=4, 31/34 at k=2, 28/34 at k=1.
- Answer A/B on the Pi (9 non-critical battery questions, fresh KV each run, alternating order). Full table and raw answers in docs/benchmarks/2026-11-14-topk-ab/.
  - First words 55.0 → **43.6 s (−21%)**. Full answer 99.5 → **79.6 s (−20%)**.
  - Quality: k=4 better on 3 (shelter, deep cut, tooth), k=3 better on 3 (water, plants, knife), same on 3.
- Passage dump (L-007 rule): tooth steps are passage #1 in both arms, so that loss is sampling noise. Shelter build steps are passage #4, ranked below two junk passages, so that loss is real (L-022).
- System-prompt reuse measured: a normal question right after another normal one reads its prompt in 42.4 s vs 51.7 s fresh (−9.3 s, no quality risk). Lost after a critical question (53.7 s) and on the first question after boot.
- Pi had rebooted overnight (uptime 1:31 at 09:21). The service came back on its own (new PID 740), as appliance mode should.
**Mistakes/Challenges:**
- L-021: a Python heredoc over SSH printed nothing (quoting + `2>/dev/null` hid the SyntaxError). Same root cause as Phase 3; the lesson wasn't searchable until now.
- L-022: eval_retrieval's 34/34 hid that the right *passage* can rank 4th behind junk. Book-level metrics overstate retrieval quality.
- Single-sample A/B at temperature 0.3 is noisy (tooth case). A quality verdict needs either temperature 0 for the A/B or several samples per question.
**Improvements/Decisions:**
- **Not deployed.** A 21% speed-up with a mixed quality result (one real information loss) is a trade-off for the owner to decide, not a free win. TOP_K stays 4 for now.
- Options with no quality risk found along the way: (a) warm the system prompt at boot and restore it after critical questions (saves ~9 s on those questions); (b) fix ranking (L-022) so 3 good passages beat 4 mixed ones.
**Hardware/Tools used:** Pi 5 (A/B runs, 71–76 °C, soft temperature limit flag set).
**Next:** Owner decision: deploy k=3 now, or fix ranking first (L-022), then shorten.
