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
| L-018 | 2026-11-13 | software | Journal never shows questions/answers (stdout buffered) | Open |

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
- **Status:** Open   **Severity:** degraded (no flight recorder)
- **Symptom:** The owner asked questions successfully after 20:58:57, but `journalctl -u survival-llm` showed no `> question`, no answer and no `llama_perf` lines. Only output from before the first `flush=True` ever appeared.
- **Why:** When Python's stdout goes to a pipe (systemd → journal) rather than a terminal, Python buffers output in large blocks. The unit sets no `PYTHONUNBUFFERED`, and most `print()` calls in main.py don't flush. Questions and answers therefore stay in memory, and a crash or power loss loses them. The 2026-09-18 decision ("journalctl is the device's flight recorder") silently doesn't work for most output.
- **How (fix):** Proposed: add `Environment=PYTHONUNBUFFERED=1` to `scripts/survival-llm.service` (or run `python -u`), reinstall, restart, then confirm a question appears in the journal within a second.
- **Prevention / lesson:** For any long-running service, check that its logs appear live (`journalctl -f` while exercising it), not just at startup.
- **Links:** BUILD_LOG 2026-11-13, L-017
