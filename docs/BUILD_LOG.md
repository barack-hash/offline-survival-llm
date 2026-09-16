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
