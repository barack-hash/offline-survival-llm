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
