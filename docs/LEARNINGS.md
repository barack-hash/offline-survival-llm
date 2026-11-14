# Learnings — Offline Survival LLM Device

Every hiccup, error and wrong assumption we hit, with **why** it happened
and **how** it was fixed. The aim is that each problem is solved only once
and makes the device better.

How this file relates to the others:
- **BUILD_LOG.md** is the diary: what happened in each session, in order.
- **LEARNINGS.md** (this file) is the lessons: one entry per problem, by
  topic, written so it can be reused. A problem in the build log's
  Mistakes/Challenges section gets an entry here as well.

## Rules for adding an entry

1. Add the entry **before or while** fixing, not afterwards from memory.
   Paste the exact error text.
2. Fill in every field. If the root cause isn't known yet, write
   "Unknown — suspected: …" and keep the status **Open**.
3. "Why" means the real root cause, not the symptom. Keep asking "why"
   until you reach something we can change.
4. "Prevention" means what stops it happening again: a code guard, a
   check, a test, a doc note, or a habit. If nothing can, say so.
5. If the same problem happens again, don't add a duplicate. Add a
   "Seen again" line to the existing entry, because a repeat means the
   prevention didn't work.
6. Add a row to the index, newest at the bottom.

### Entry template

```
### L-NNN — <short title>
- **Date:** YYYY-MM-DD   **Area:** software | hardware | model | retrieval | corpus | tooling | ops | enclosure
- **Status:** Fixed | Workaround | Open   **Severity:** device-down | degraded | dev-only
- **Symptom:** what was seen (exact error text)
- **Why (root cause):** the real cause
- **How (fix):** what was changed, and where (file/commit)
- **Verified by:** the measured check that proved the fix worked
- **Prevention / lesson:** what stops it recurring, and the general rule
- **Links:** BUILD_LOG date, issue #, commit
```

---

## Index

| ID | Date | Area | Title | Status |
|---|---|---|---|---|
| L-001 | 2026-09-15 | hardware | Fan not detected: connector unseated at power-on | Fixed |
| L-002 | 2026-09-15 | ops | apt upgrade died on a conffile prompt | Fixed |
| L-003 | 2026-09-15 | tooling | `ping` said the Pi was down when it was up | Fixed |
| L-004 | 2026-09-15 | tooling | llama-cli hung in interactive mode, 3.9 GB log | Fixed |
| L-005 | 2026-09-15 | tooling | `pgrep -f` matched and killed my own SSH session | Fixed (recurred ×2) |
| L-006 | 2026-09-16 | model | Phi-3 output gibberish past ~2k tokens | Fixed |
| L-007 | 2026-09-16 | corpus | "Model bug" was really a missing book | Fixed |
| L-008 | 2026-09-16 | tooling | `git reset --hard` on the Pi wiped uncommitted work | Fixed |
| L-009 | 2026-09-18 | hardware | Keypad defective from the factory | Workaround (IR remote) |
| L-010 | 2026-09-18 | hardware | Arduino wedged: no serial, no flashing | Fixed |
| L-011 | 2026-09-24 | enclosure | Fan intake faced the screen with 2.6 mm gap | Fixed (design) |
| L-012 | 2026-10-04 | hardware | Thermal throttling under sustained inference | Open (issue #8) |
| L-013 | 2026-10-04 | tooling | git push 403: wrong GitHub account active | Fixed |
| L-014 | 2026-11-13 | software | Service crash-looped with the Arduino unplugged | Fixed |
| L-015 | 2026-11-13 | ops | `ssh pi` timed out: Tailscale off on the Mac | Workaround |
| L-016 | 2026-11-13 | tooling | Fake-port test could have deleted the real device node | Fixed (method) |
| L-017 | 2026-11-13 | hardware | "Remote not writing anything" after rewiring | Resolved (cause unconfirmed) |
| L-018 | 2026-11-13 | software | Journal never shows questions/answers (stdout buffered) | Fixed |
| L-019 | 2026-11-13 | software | Streaming scrolled the CRITICAL warning off the LCD | Fixed |
| L-020 | 2026-11-13 | tooling | Unfair A/B test: second run reused the cached prompt | Fixed (method) |
| L-021 | 2026-11-14 | tooling | Python heredoc over SSH printed nothing (quoting) | Fixed (method) |
| L-022 | 2026-11-14 | retrieval | Retrieval ranks junk passages above useful ones | Fixed (partly) |
| L-023 | 2026-11-14 | corpus | Edible-plant answer says "taste first" (OCR-garbled figure) | Fixed (berries open) |
| L-024 | 2026-11-14 | tooling | Test copies left in the Pi repo blocked `git pull` | Fixed (method) |
| L-025 | 2026-11-14 | tooling | Background rebuild never started; waited 9 min for it | Fixed (method) |
| L-026 | 2026-11-14 | corpus | More FM 21-76 figures are OCR garbage (water, signals) | Open |

---

## Entries

### L-001 — Fan not detected: connector unseated at power-on
- **Date:** 2026-09-15   **Area:** hardware
- **Status:** Fixed   **Severity:** degraded
- **Symptom:** Idle temperature was 70–76 °C, there was no `cooling_fan` hwmon device, and `/proc/device-tree/cooling_fan/status` read `disabled`.
- **Why:** The Pi 5 firmware checks the FAN header only at power-on. The connector wasn't fully seated at first boot, so the fan was disabled for the whole session.
- **How:** Shut down cleanly, re-seated the connector, and power-cycled. Status became `okay` and idle temperature dropped about 25 °C.
- **Verified by:** `cooling_fan/status = okay` and an idle reading of 49–50 °C.
- **Prevention / lesson:** After any re-assembly, check that `cooling_fan/status` reads `okay` before trusting temperature readings. A reboot is not enough after re-seating; it needs a full power cycle.
- **Links:** BUILD_LOG 2026-09-15 Phase 1

### L-002 — apt upgrade died on a conffile prompt
- **Date:** 2026-09-15   **Area:** ops
- **Status:** Fixed   **Severity:** dev-only
- **Symptom:** `end of file on stdin at conffile prompt` (from `rpi-chromium-mods`).
- **Why:** A locally modified `/etc/chromium/master_preferences` triggered an interactive prompt, but the upgrade was running non-interactively over SSH.
- **How:** Ran `sudo dpkg --configure -a --force-confold`, which keeps the existing config.
- **Verified by:** `apt-get check` came back clean.
- **Prevention / lesson:** Run unattended upgrades with `-o Dpkg::Options::=--force-confold`.
- **Links:** BUILD_LOG 2026-09-15 Phase 1

### L-003 — `ping` said the Pi was down when it was up
- **Date:** 2026-09-15   **Area:** tooling
- **Status:** Fixed   **Severity:** dev-only
- **Symptom:** `ping raspberrypi.local` returned "No route to host" while the Pi was running fine.
- **Why:** ICMP was being blocked (macOS local-network permission), but mDNS still resolved the name.
- **How:** Tested the port that actually matters instead: `nc -z host 22`.
- **Prevention / lesson:** To check whether a service is up, test that service's port, not ping.
- **Links:** BUILD_LOG 2026-09-15 Phase 1

### L-004 — llama-cli hung in interactive mode, 3.9 GB log
- **Date:** 2026-09-15   **Area:** tooling
- **Status:** Fixed   **Severity:** dev-only
- **Symptom:** setup.sh never finished. The log filled with blank `> ` prompts and grew to 3.9 GB. The old `-no-cnv` flag failed with `error: invalid argument: -no-cnv`.
- **Why:** Newer llama-cli starts in chat mode by default. With no input, it looped forever printing prompts.
- **How:** Added `-st` (`--single-turn`) to the smoke test in setup.sh.
- **Prevention / lesson:** Fast-moving tools change their flags. Run smoke tests with explicit non-interactive flags and a timeout.
- **Links:** BUILD_LOG 2026-09-15 Phase 2

### L-005 — `pgrep -f` matched and killed my own SSH session
- **Date:** 2026-09-15   **Area:** tooling
- **Status:** Fixed (recurred 2026-09-16 and 2026-09-18)   **Severity:** dev-only
- **Symptom:** The SSH session exited with 255, which looked like the Pi had crashed.
- **Why:** `pgrep -f "llama-cli|setup.sh"` matches against full command lines, including the SSH command that contained the same text. The `kill` then hit my own shell.
- **How:** Use exact matches (`pgrep -x` / `pgrep -fx`) or PIDs read from the service.
- **Prevention / lesson:** Never `kill $(pgrep -f pattern)` when the pattern also appears in your own command line.
- **Seen again:** 2026-09-16 (watcher script, caught in time) and 2026-09-18 (Mac serial-port cleanup). A habit alone didn't stop it; prefer `systemctl` or a PID file.
- **Seen again:** 2026-11-14. A wait loop `ssh pi '… pgrep -f "scripts/rag_build.py" …'` matched its own SSH command line, so it never saw the build exit and reported `STILL-RUNNING` after the build had finished (log: `Saved index.faiss … real 8m53.919s`). Harmless here, but the loop waited its full timeout. Fix going forward: record `$!` as a PID file at launch and wait on `kill -0 $PID`.
- **Links:** BUILD_LOG 2026-09-15, 09-16, 09-18

### L-006 — Phi-3 output gibberish past ~2k tokens
- **Date:** 2026-09-16   **Area:** model
- **Status:** Fixed   **Severity:** device-down (critical mode)
- **Symptom:** First a crash: `Requested tokens (3470) exceed context window of 2048`. After raising n_ctx, critical-mode answers came out as word salad, even at temperature 0.
- **Why:** llama.cpp mishandles Phi-3's sliding-window attention (window 2047) on longer prompts, and critical mode's 8-chunk prompts are longer than that. Eliminated first: the chat template, the GGUF file, and the runtime.
- **How:** Raised n_ctx to 4096 and switched the model to Qwen2.5-3B-Instruct.
- **Verified by:** The same 3.4k-token prompt quoted the dose verbatim. The 10-question battery passed.
- **Prevention / lesson:** Test any candidate model at the longest prompt the device will send (critical mode), not only with short questions.
- **Links:** BUILD_LOG 2026-09-16 Phase 4

### L-007 — "Model bug" was really a missing book
- **Date:** 2026-09-16   **Area:** corpus
- **Status:** Fixed   **Severity:** degraded
- **Symptom:** The knife-hardening question was answered from a passage about wooden knives. A prompt-rule fix didn't help.
- **Why:** The corpus contained no usable blade-hardening instructions, so the model had nothing correct to work from.
- **How:** Added Woodworth 1903 (*Hardening, Tempering…*). Index rebuilt.
- **Verified by:** eval_retrieval 16/16 under a stricter expectation, and a correct Q8 answer.
- **Prevention / lesson:** When an answer is off-subject, first look at the chunks the model was actually given, before tuning anything.
- **Links:** BUILD_LOG 2026-09-16, issue #4

### L-008 — `git reset --hard` on the Pi wiped uncommitted work
- **Date:** 2026-09-16   **Area:** tooling
- **Status:** Fixed   **Severity:** dev-only
- **Symptom:** The eval suite reported 22/22 when it should have run 34 cases.
- **Why:** The history rewrite plus `reset --hard` on the Pi silently reverted an uncommitted file.
- **How:** Re-synced the file and re-ran the suite: 34/34.
- **Prevention / lesson:** Commit or stash on every machine before rewriting history. Check that test counts match what you expect.
- **Links:** BUILD_LOG 2026-09-16 attribution session

### L-009 — Keypad defective from the factory
- **Date:** 2026-09-18   **Area:** hardware
- **Status:** Workaround (IR remote; issue #6 for a replacement)   **Severity:** device-down (input)
- **Symptom:** A flood of phantom 'A' presses and missed key presses.
- **Why:** The membrane was shorted internally on lines 1–8 and 4–6. The shorts stayed with the keypad dangling free, which proves the fault is in the part, not the wiring.
- **How:** Switched to the kit's NEC IR remote (`ir_remote_serial.ino`).
- **Prevention / lesson:** Write a diagnostic sketch that doesn't depend on wiring before re-wiring in circles. Parts can be dead on arrival.
- **Links:** BUILD_LOG 2026-09-18, issue #6

### L-010 — Arduino wedged: no serial, no flashing
- **Date:** 2026-09-18   **Area:** hardware
- **Status:** Fixed   **Severity:** dev-only
- **Symptom:** No serial output, and flashing failed with the bootloader `not in sync`.
- **Why:** The chip had locked up.
- **How:** Power-cycled it (unplugged USB).
- **Prevention / lesson:** When serial and flashing both fail, power-cycle before suspecting the wiring.
- **Links:** BUILD_LOG 2026-09-18

### L-011 — Fan intake faced the screen with 2.6 mm gap
- **Date:** 2026-09-24   **Area:** enclosure
- **Status:** Fixed (design v0.4)   **Severity:** degraded (would have been)
- **Symptom:** Found during design review; never printed.
- **Why:** The layout was drawn shape-first. The cooler draws air through its top, which faced the e-paper panel.
- **How:** Flipped the stack so the Pi faces the back wall, and added a porthole intake.
- **Prevention / lesson:** Design the air path first, then the shape around it.
- **Links:** BUILD_LOG 2026-09-24 v0.4

### L-012 — Thermal throttling under sustained inference
- **Date:** 2026-10-04   **Area:** hardware
- **Status:** Open (issue #8)   **Severity:** degraded
- **Symptom:** Reached 84.5 °C with the fan at max (5151 rpm), and `throttled=0xe0008`.
- **Why:** About 2 hours of continuous inference causes heat soak. The 2-minute stress test in Phase 1 was too short to show it.
- **How:** Not fixed yet. Better cooling is needed before the enclosure.
- **Prevention / lesson:** Thermal tests must match the real duty cycle, not a short burst.
- **Links:** BUILD_LOG 2026-10-02/04, issue #8

### L-013 — git push 403: wrong GitHub account active
- **Date:** 2026-10-04   **Area:** tooling
- **Status:** Fixed   **Severity:** dev-only
- **Symptom:** `remote: Permission to barack-hash/offline-survival-llm.git denied to eiQora`.
- **Why:** The active gh account had switched to the company identity.
- **How:** Set a repo-local remote URL with `barack-hash@` and a repo-local credential helper. For issues, use `GH_TOKEN=$(gh auth token -u barack-hash)`.
- **Prevention / lesson:** Pin identity per repo. Don't rely on the global active account.
- **Links:** BUILD_LOG 2026-10-02/04

### L-014 — Service crash-looped with the Arduino unplugged
- **Date:** 2026-11-13   **Area:** software
- **Status:** Fixed   **Severity:** device-down
- **Symptom:** `survival-llm.service` had restarted 12 times within about 5 minutes of boot and never reached "ready". From the journal:
  `serial.serialutil.SerialException: [Errno 2] could not open port /dev/ttyACM0: [Errno 2] No such file or directory: '/dev/ttyACM0'`, then
  `survival-llm.service: Main process exited, code=exited, status=1/FAILURE`. `lsusb` showed only the root hubs: no Arduino was attached.
- **Why:**
  1. *Immediate cause:* the Arduino wasn't plugged in, so `/dev/ttyACM0` didn't exist.
  2. *Why it became a loop:* `main()` loaded the embedder, the index and the ~1.8 GB LLM **first**, and only then opened the serial port. A missing port therefore crashed the process after all the expensive work. systemd's `Restart=always` (designed on 2026-09-18 to "retry until the Arduino enumerates") then repeated the whole load every ~19 s. That kept the CPU busy and warmed the board while the device did nothing useful.
  3. *Why it wasn't caught:* the appliance-mode test (2026-09-18) was only run with the Arduino attached. The "accessory missing" case was never tested. The retry design worked as written, but it retried the most expensive possible step.
- **How:** `scripts/main.py` now opens the serial port **before** loading any models. If the port is missing, it waits in-process (checking every 2 s, logging a "waiting" line once a minute). The models load once, after the input device is confirmed. The systemd unit is unchanged; `Restart=always` remains as the last-resort safety net.
- **Verified by:** Measured on the Pi, 2026-11-13:
  | | Old code (crash loop) | New code (Arduino absent) |
  |---|---|---|
  | systemd restarts | 27 in 9 min since boot | **0** in 2.5 min |
  | Model loads | one every ~19 s | **none** until the port appears |
  | Temperature | 45.0 → 51.6 °C, fan running | **46.6 °C**, fan off (cooling state 0) |
  | Load average (1 min) | 0.73 | **0.06** |
  | Journal noise | ~40-line traceback per cycle | **1 "Waiting…" line per minute** |
  - *Port appears* (simulated with a pty symlinked to `/dev/ttyACM0`): `Serial port /dev/ttyACM0 found after 164 s`, then ready **7 s** later, with 0 restarts.
  - *Real Arduino Uno plugged in* (owner, 20:52:42): service ready at 20:52:57 and holding `/dev/ttyACM0` (fd 22). After the fix, temperature was 45.0 °C and `throttled=0x0`.
- **Known remaining limitation:** if the Arduino is unplugged **while running**, `_read_line` raises `SerialException: device reports readiness to read but returned no data`. The process then exits and systemd restarts it once (measured: NRestarts=1). The fresh process waits cheaply, but it reloads the models once the port returns. Possible improvement: reconnect inside `SerialKeypadInput` instead of exiting.
- **Prevention / lesson:**
  - Acquire cheap, likely-to-be-missing resources (devices, files, ports) before expensive ones (model loads). Fail or wait early, not late.
  - For every peripheral, test the "unplugged at boot" and "unplugged while running" cases, not only the happy path.
  - A systemd restart loop is a fallback, not a strategy for waiting on hardware.
- **Links:** BUILD_LOG 2026-11-13

### L-015 — `ssh pi` timed out: Tailscale off on the Mac
- **Date:** 2026-11-13   **Area:** ops
- **Status:** Workaround   **Severity:** dev-only
- **Symptom:** `ssh: connect to host 100.123.242.97 port 22: Operation timed out`.
- **Why:** `tailscale status` on the Mac returned "Tailscale is stopped." The `pi` SSH alias points at the Tailscale IP, so it only works while Tailscale is running on the Mac. The Pi itself was up and on the tailnet.
- **How:** On the home network, connect directly with `ssh yitbarek@raspberrypi.local` (10.0.0.228).
- **Prevention / lesson:** If `ssh pi` fails, first check `tailscale status` on **both** ends, then try `raspberrypi.local`. Don't assume the Pi is down.
- **Links:** BUILD_LOG 2026-11-13

### L-016 — Fake-port test could have deleted the real device node
- **Date:** 2026-11-13   **Area:** tooling
- **Status:** Fixed (method)   **Severity:** dev-only (near miss)
- **Symptom:** To test L-014 without hardware, a script symlinked a pty to `/dev/ttyACM0` and then ran `sudo rm -f /dev/ttyACM0` when it finished. The owner plugged in the real Arduino 2 s before that cleanup ran (dmesg `cdc_acm 1-2:1.0: ttyACM0` at 20:52:42). The real node survived (`crw-rw---- 166,0`), but the cleanup could have deleted it, leaving the Arduino attached with no port until it was replugged.
- **Why:** The test used the real device path in `/dev`, which udev owns. It also assumed nobody would touch the hardware during the test.
- **How:** Nothing was broken. For future tests, don't put fakes at real `/dev` paths. Either point `SERIAL_PORT` at a pty path for the test run, or delete only if it's still our symlink (`[ -L /dev/ttyACM0 ] && rm`).
- **Prevention / lesson:** Never `rm -f` a path that the system or a user can recreate as something real. Check that it is still your file first. Also tell the owner before simulating hardware they might be handling at the same time.
- **Links:** BUILD_LOG 2026-11-13

### L-017 — "Remote not writing anything" after rewiring
- **Date:** 2026-11-13   **Area:** hardware
- **Status:** Resolved, cause unconfirmed   **Severity:** device-down (input)
- **Symptom:** After rewiring the whole bench, the owner reported that the remote was "not writing anything". The service had been ready and holding `/dev/ttyACM0` since 20:53:03, and no question line reached the Pi between then and 20:55.
- **Diagnostics so far:**
  - Paused the service and opened the port directly from the Pi (20:55:44). Sent a 32-character test line to the LCD, then listened for 180 s.
  - Received `^U` (▲) at 20:55:58 and `bd` + newline (a typed question sent with `#`) at 20:56:08. So the remote, IR receiver, sketch and serial link to the Pi were all working at that point.
- **Why:** Unknown. Suspected (to confirm with the owner's observations of the LCD and the "L" LED): a loose IR or LCD jumper that settled during handling, typing never being sent with `#` (the Pi only sees whole questions and arrows), or the LCD not showing typing (contrast or I2C wiring).
- **Observability gap found:** the Pi can't see letters until `#` is pressed, and main.py ignores arrows when there's no answer to scroll, without logging them. "Nothing arrived" therefore can't be told apart from "keys arrived but weren't logged". Possible fix: log every received serial line (including arrows) to the journal.
- **How (fix):** No change was made on the Pi side. It worked from the diagnostic run onwards (20:55), and the owner confirmed "Yes, it works" with the service running after 20:58:57. The service process then used about 5 min of CPU time (answering) and the SoC reached 76.8 °C. The exact cause wasn't pinned down; the likeliest is a jumper that settled or a question not sent with `#`.
- **Verified by:** Raw serial capture (`^U`, `bd`) plus the owner's confirmation.
- **Prevention / lesson:** After any rewiring, run the raw serial capture first. It splits "Arduino/IR side" from "Pi side" in one minute. Note that the journal could not confirm what happened, because of L-018.
- **Links:** BUILD_LOG 2026-11-13, L-018

### L-018 — Journal never shows questions/answers (stdout buffered)
- **Date:** 2026-11-13   **Area:** software
- **Status:** Fixed   **Severity:** degraded (no flight recorder)
- **Symptom:** The owner asked questions successfully after 20:58:57, but `journalctl -u survival-llm` showed no `> question`, no answer and no `llama_perf` lines. Only output from before the first `flush=True` ever appeared.
- **Why:** When Python's stdout goes to a pipe (systemd → journal) rather than a terminal, Python buffers output in large blocks. The unit sets no `PYTHONUNBUFFERED`, and most `print()` calls in main.py don't flush. Questions and answers therefore stay in memory, and a crash or power loss loses them. The 2026-09-18 decision ("journalctl is the device's flight recorder") silently doesn't work for most output.
- **How (fix):** Added `Environment=PYTHONUNBUFFERED=1` to `scripts/survival-llm.service`, copied it to `/etc/systemd/system/`, then `daemon-reload` + restart (21:12). Confirmed in `/proc/<pid>/environ`.
- **Verified by:**
  - Startup lines now carry distinct timestamps (21:12:19.97 → 21:12:21.26 → 21:12:26.89). Before, all were stamped 20:58:57, the moment the buffer was written out at once.
  - Owner asked "fire making" on the remote: `> fire making` was logged at **21:14:12.0**, and the answer plus `llama_perf` lines at 21:16:02.9, both live. Timings: prompt 1371 tok in 51.7 s (26.5 tok/s), generation 317 tok in 58.1 s (5.46 tok/s), total 110 s.
- **Side effect:** the restart came while the service was at 47.5% CPU, so it may have cut off an answer in progress. Lesson: check the journal/CPU and ask the owner before restarting a device that's in use.
- **Prevention / lesson:** For any long-running service, check that its logs appear live (`journalctl -f` while exercising it), not just at startup.
- **Links:** BUILD_LOG 2026-11-13, L-017

### L-019 — Streaming scrolled the CRITICAL warning off the LCD
- **Date:** 2026-11-13   **Area:** software
- **Status:** Fixed   **Severity:** safety (caught in test, never deployed)
- **Symptom:** In the first streaming test, the critical question "what is the dose of aspirin for an adult" showed `verify vs 2nd   source. The` as its first live LCD update at 132.2 s. The `!CRITICAL!` part of the warning was already off-screen.
- **Why:** The live view follows the newest two wrapped lines. The warning was added as a text prefix (2 LCD lines). By the first update (throttled to 0.5 s), more text had arrived, so the prefix had scrolled off. The finished-answer view starts at the top, so this had never been a problem before streaming.
- **How (fix):** In critical mode, `stream_answer` now pins `!CRITICAL!verify` (exactly 16 characters, one full row) to the top row and streams the answer on the bottom row. The finished view is unchanged (it starts at the top with the full warning).
- **Verified by:** On the Pi, the full critical answer was fed to `stream_answer` one character at a time with the throttle off. **113/113 frames** start with `!CRITICAL!verify`, and all are exactly 32 characters. In the real-model run, live frames read `!CRITICAL!verifyAccording`, `…reference`, `…the`. The finished view still opens with `!CRITICAL!      verify vs 2nd`.
- **Prevention / lesson:** Any change to how text reaches the screen must be tested with a critical question, and the test must assert that the warning is visible in **every** frame, not just the first or last one.
- **Links:** BUILD_LOG 2026-11-13

### L-020 — Unfair A/B test: second run reused the cached prompt
- **Date:** 2026-11-13   **Area:** tooling
- **Status:** Fixed (method)   **Severity:** dev-only
- **Symptom:** The streamed and non-streamed critical answers (temperature 0) differed: `CRITICAL stream == non-stream: False`. The non-streamed run took only **7.2 s** against 142.6 s.
- **Why:** llama-cpp-python reuses the KV cache when a new prompt shares a prefix with the previous one. The second run asked the identical prompt, so it skipped the 8-chunk prompt reading entirely. Prompt reading done in different batch shapes can produce slightly different floating-point results, so even greedy (temperature 0) decoding can diverge. The comparison wasn't like for like.
- **How (fix):** Call `llm.reset()` before every run, and add a determinism baseline (plain run twice) before comparing streamed against plain.
- **Result after fixing the method:** plain1 == plain2 (determinism baseline) **True**, and stream == plain1 **True**. Streaming does not change the critical answer.
- **Prevention / lesson:** In A/B tests, reset all caches between arms and measure the baseline variance (A vs A) before claiming A vs B differs. A suspiciously fast second run is a sign that a cache was used.
- **Links:** BUILD_LOG 2026-11-13, L-019

### L-021 — Python heredoc over SSH printed nothing (quoting)
- **Date:** 2026-11-14   **Area:** tooling
- **Status:** Fixed (method)   **Severity:** dev-only
- **Symptom:** A chunk-dump script sent as `ssh pi '… python - <<EOF … f"{r[\"source\"]}" … EOF'` produced **no output at all**. The error was hidden because the command also ran with `2>/dev/null`.
- **Why:** Three layers of quoting (local shell → single-quoted SSH command → unquoted heredoc → Python f-string with escaped quotes) mangled the f-string into a SyntaxError, and stderr was thrown away.
- **How:** Wrote the script to a file in the scratchpad, copied it with `scp`, ran it, then deleted it. Output appeared at once.
- **Prevention / lesson:** For anything beyond a one-liner, write a file and `scp` it. Never use `2>/dev/null` on a command you haven't seen succeed yet.
- **Seen before:** 2026-09-15 Phase 3 had the same root cause (`SyntaxError: unexpected character after line continuation character`), and the same lesson was in the build log but not in this file, so it wasn't searchable. Now it is.
- **Links:** BUILD_LOG 2026-09-15 Phase 3, 2026-11-14

### L-022 — Retrieval ranks junk passages above useful ones
- **Date:** 2026-11-14   **Area:** retrieval
- **Status:** Fixed (partly)   **Severity:** degraded
- **Symptom:** "What kind of shelter should I build to stay warm in a cold forest?": ranks 2 and 3 are unrelated FM 21-76 text (insect bites/diarrhoea, flash-flood site selection). The actual build steps (ridgepole, ribbing) are rank **4**. With TOP_K=3 the answer lost the build steps.
- **Why:** Hybrid BM25 + vector RRF rewards keyword overlap ("cold", "shelter", "warm"), so passages sharing words but not subject rank high. eval_retrieval only checks that the right **book** is in the top k, not the right **passage**, so this was invisible (34/34 at both k=3 and k=4).
- **How (fix):**
  1. `eval_retrieval.py` now checks passages, not just books: `ANSWER_PATTERNS` per case, reporting passage hit@1–4 and MRR@10.
  2. `main.select_passages()` reranks the hybrid top 20 with `cross-encoder/ms-marco-MiniLM-L-6-v2` and keeps 3 (TOP_K 4 → 3). Critical questions bypass it (8 passages, unchanged). All callers (main, verify, eval_*) use `select_passages`. Deployed 2026-11-14 10:15 (commit 99da336).
- **Verified by:**
  | | hit@1 | hit@3 | MRR@10 |
  |---|---|---|---|
  | Before (hybrid) | 23/34 | 31/34 | 0.797 |
  | After (rerank 20 → 3) | 26/34 | 32/34 | 0.855 |
  - Shelter answer passage 4 → **1**, river water 6 → **2**. Rerank costs 2.0–4.2 s per question.
  - Answer A/B (temperature 0, 9 questions): first words 55.6 → 47.4 s, full answer 99.1 → 88.7 s. Quality 3 better / 3 worse / 3 same; see docs/benchmarks/2026-11-14-rerank-ab/.
  - Reranker and embedder load from cache with `HF_HUB_OFFLINE=1` (12.0 s cold), so it works with no network.
- **Still open:** soil-before-sowing got worse (2 → 6), and passages that used to sit at #3/#4 (plant avoid-list, wound "<12 h" closing rule) can now be dropped. The patterns marked "broad" in eval_retrieval are lenient and overstate those cases.
- **Prevention / lesson:** "Right book found" is not "right passage found". Retrieval metrics must check the passage that actually holds the answer.
- **Links:** BUILD_LOG 2026-11-14, docs/benchmarks/2026-11-14-topk-ab/

### L-023 — Edible-plant answer says "taste first" (wrong test order)
- **Date:** 2026-11-14   **Area:** corpus (first logged as model)
- **Status:** Fixed for "is this plant safe to eat"; berries still open   **Severity:** safety
- **Symptom:** In the rerank A/B (temperature 0), the deployed setup answered "How can I tell if a wild plant is safe to eat?" with step 1 "Crush a small piece of the plant and taste it". FM 21-76's Universal Edibility Test starts with skin contact and only later moves to lips and mouth. The old setup also invented timings ("20 minutes", "30 minutes") but kept contact before taste and the manual's avoid-list.
- **Why (first guess, wrong):** a model problem, i.e. the 3B model reordering a multi-step procedure.
- **Why (root cause, found by reading the source per L-007):** in our FM 21-76 text the Universal Edibility Test is **Figure 9-5**, an image, and the OCR turned it into garbage, e.g. `1 Test fmly [me pail of a FMlenta^ Jood plant at a bme`, `4 Do r*Ql 6ai tor 5 hcur^ beloffl sta/ling tho test`, `12 y/ait 3 ngur?`. The device never had a readable version of the step order, so every model would guess. Old answers' invented timings ("20 minutes", "30 minutes") came from the same gap.
- **How (fix):** two separate, measured changes:
  1. Corpus: add a clean transcription of Figure 9-5 (PD), checked line by line against the OCR, as `corpus/pd/fm21-76-fig9-5-universal-edibility-test.txt`.
  2. Safety: make edibility/poisoning questions critical (verbatim passages, temperature 0, warning banner). This only strengthens the safety rules.
  Then add the question to verify.py with the correct order as the expected answer.
- **Verified by** (Pi, 2026-11-14, rebuilt index of 6,140 chunks, automatic order check skin → lip → tongue → chew → swallow):
  | Question | Mode | Transcription sent | Result |
  |---|---|---|---|
  | Wild plant safe to eat? | normal (change 1 only) | no, the reranker skipped it | ❌ invented "**if it floats, it's probably safe to eat**", tastes first |
  | Wild plant safe to eat? | **critical** | yes (+ FM 21-76 corroborates) | ✅ all 5 stages in order, 15 min / 3 min / 15 min / 15 min / 8 h / 8 h, full avoid-list. Still adds "wrap in cloth" and omits the 1/4-cup step |
  | Berries poisonous? | normal | no | ❌ invented "20 minutes" test |
  | Berries poisonous? | critical | no | ⚠ no procedure invented; general caution only |
  - Retrieval regression after rebuild: unchanged (book 34/34, passage hit@3 32/34, MRR 0.855).
  - Keyword check: only the plant/mushroom/berry/toxic questions flip to critical; snake bite, fire and the rest stay normal.
  - Deployed 10:58:45 (commits 1c3b411 + corpus commit), NRestarts=0.
- **Still open:** for "berries" the transcription isn't in the hybrid top 8, so the answer is cautious but has no test steps. The critical prompt is written for figures, not step order; a "keep steps in source order" rule would strengthen it further. Other figures in OCR'd manuals may be garbled the same way; a scan for garbage-heavy chunks is worth doing.
- **Prevention / lesson:** Step order matters as much as numbers for safety procedures; verification should check order, not just figures. Second time (after L-007) that a "model problem" was really a corpus problem, so read the source passage before blaming the model. OCR'd figures and tables are a known blind spot.
- **Links:** BUILD_LOG 2026-11-14, docs/benchmarks/2026-11-14-rerank-ab/

### L-024 — Test copies left in the Pi repo blocked `git pull`
- **Date:** 2026-11-14   **Area:** tooling
- **Status:** Fixed (method)   **Severity:** dev-only
- **Symptom:** `error: Your local changes to the following files would be overwritten by merge: scripts/eval_retrieval.py … Aborting`.
- **Why:** For a quick test I had `scp`'d the new eval_retrieval.py straight into the Pi's repo. The later commit made the same change, so git saw an uncommitted local modification.
- **How:** `git checkout -- scripts/eval_retrieval.py`, then `git pull --ff-only`.
- **Prevention / lesson:** Put test copies in a separate folder (as done for `~/rr_test`), never into the live repo or the service's working directory. That also stops a reboot from silently running untested code.
- **Links:** BUILD_LOG 2026-11-14

### L-025 — Background rebuild never started; waited 9 min for it
- **Date:** 2026-11-14   **Area:** tooling
- **Status:** Fixed (method)   **Severity:** dev-only (lost ~9 min)
- **Symptom:** The index rebuild was launched as `nohup bash -c "… /usr/bin/time -v venv/bin/python scripts/rag_build.py" &`, and a wait loop watched the log for "Elapsed (wall". After 9 minutes the index files were still dated Sep 16. The log contained only `bash: line 1: /usr/bin/time: No such file or directory`.
- **Why:** GNU `time` isn't installed on Raspberry Pi OS (only the shell keyword `time` exists). The launch command printed "launched" because the `nohup … &` wrapper itself succeeded. The wait loop only checked for success text, never for failure or "process gone".
- **How:** Relaunched with the bash `time` keyword, and checked `pgrep` 15 s after launch: `RUNNING`.
- **Prevention / lesson:** After any background launch, check within seconds that the process exists and the log has started. Wait loops must also exit when the process is gone, not only when success text appears.
- **Links:** BUILD_LOG 2026-11-14

### L-026 — More FM 21-76 figures are OCR garbage (water, signals)
- **Date:** 2026-11-14   **Area:** corpus
- **Status:** Open   **Severity:** degraded / safety-adjacent (water)
- **Symptom:** A corpus-wide garbage scan (`scripts/scan_ocr_garbage.py`, 6,140 passages, 42 flagged, all reviewed by hand) found more figures that are unreadable, like Figure 9-5 was. Example, Fig 6-2 "effects of substitute fluids": `Is about 4 percent sart. H tshes a^>oul 2 rfer? r/ bc-^ty f.ui:^^`. Example, Fig 13-2 water-needs graph: `water requirements … will be approximately ?5 liters`.
- **Why:** archive.org's OCR handles running text well but fails on figures, tables and graphs. FM 21-76 puts much of its most practical content (water sources, substitute fluids, water needs, signal codes) in figures. Project Gutenberg texts are human-proofread and came out clean.
- **How (fix):** Pending. Ranked list in docs/corpus-ocr-scan-2026-11-14.md: (1) Fig 6-2 substitute fluids, (2) Fig 6-1 water sources, (3) Fig 13-2 daily water needs, (4) Fig 19-6/19-7 ground-to-air codes. Transcribe from the scanned PDF's page images (same archive.org item), checked against the image as was done for Fig 9-5. Separately: drop ~10 index-page passages from the steel book.
- **Verified by:** The scan found Fig 9-5 (score 0.29) unprompted, so the method catches the known case.
- **Prevention / lesson:** Run `scan_ocr_garbage.py` after adding any OCR'd book, and review figures and tables first. Prefer human-proofread texts (Gutenberg) where an edition exists.
- **Links:** docs/corpus-ocr-scan-2026-11-14.md, L-023, BUILD_LOG 2026-11-14
