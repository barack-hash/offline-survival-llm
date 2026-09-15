# Offline "Civilization Restart" Device — Build Plan
Raspberry Pi 5 (8GB RAM / 128GB storage) + local LLM + e-ink text screen

## What you already have
- Raspberry Pi 5, 8GB RAM, 128GB storage, official heatsink+fan case
- Arduino starter kit (Uno-class board + basic sensors/buttons/breadboard)

This is enough to start on software today, before any parts arrive.

---

## Phase 0 — What to buy
| Item | Why | Notes |
|---|---|---|
| E-ink display (Waveshare 2.13"–4.2" e-Paper HAT, SPI) | "Calculator screen" text reader; holds text with zero power once drawn | 2.13" is cheap/small, 4.2" is much more readable for paragraphs |
| Small USB or matrix keypad | Input without a full keyboard | Your Arduino kit can drive a matrix keypad and send keystrokes to the Pi over serial/USB |
| USB power bank or LiFePO4 pack + solar panel (10-20W) | Runs the device through an outage | Pi 5 draws ~5-8W under load; a 20,000mAh bank gives many hours |
| Solar charge controller / UPS HAT (e.g. PiJuice, Waveshare UPS HAT) | Handles charging + safe shutdown on power loss | Optional but strongly recommended for a "disaster" device |
| MicroSD or USB drive backup of everything | Redundancy | Your 128GB is plenty for OS + model + full text corpus |

You can build and test 100% of the software (Phases 1–4) on the Pi right now using just a monitor/keyboard over SSH, then add the e-ink screen and power system once parts arrive.

---

## Phase 1 — Base OS setup
1. Flash **Raspberry Pi OS Lite (64-bit)** — no desktop, saves RAM for the model.
2. Enable SSH + set a static hostname during imaging (Raspberry Pi Imager lets you do this headlessly).
3. `sudo apt update && sudo apt full-upgrade -y`
4. Enable SPI (needed for the e-ink screen later): `sudo raspi-config` → Interface Options → SPI → Enable.

---

## Phase 2 — Local LLM engine
On an 8GB Pi 5, the sweet spot is a **3–4B parameter model, Q4 quantized**, which gives usable speed (5–10 tokens/sec) and decent reasoning. Recommended: **Phi-3 Mini 3.8B (Q4_K_M GGUF)**. Gemma 2 2B is a faster/lighter fallback; Llama 3 8B Q4 works but will feel noticeably slower.

Run `setup.sh` (included) — it installs `llama.cpp` compiled for ARM, and downloads a starting model. You can swap models later; nothing else in the stack changes.

**Important design decision:** don't rely on the raw model's memory for technical "how to build X" instructions — small quantized models hallucinate on step-by-step technical detail (measurements, ratios, sequences). Instead, use it as a **reading/explaining engine on top of a real text library** (Phase 3). This is far more trustworthy for something you might actually depend on.

---

## Phase 3 — The offline knowledge library (RAG)
This is the actual "kickstart civilization" content. Two tiers:

**Tier 1 — public domain, safe to download directly, no copyright issue:**
- U.S. Army Survival Manual, FM 21-76 (fire, water, shelter, edible plants, first aid)
- U.S. Army Field Manuals on basic engineering, knots, land navigation
- Where There Is No Doctor / Where There Is No Dentist (Hesperian Health Guides — free for humanitarian/personal use)
- Old public-domain chemistry, blacksmithing, and mechanics textbooks (archive.org has many pre-1929 texts that are fully public domain)

**Tier 2 — the best single resource for this exact goal, but copyrighted:**
- *"The Knowledge: How to Rebuild Civilization in the Aftermath of a Cataclysm"* by Lewis Dartnell. It's essentially a written version of what you're describing — fire, metallurgy, chemistry, agriculture, medicine, from scratch. **Buy a copy**; if you own it, you can scan/OCR your personal copy for your own offline device. I can't provide a download of the copyrighted text itself, but the RAG pipeline below will index whatever text files you legally add to the `corpus/` folder — that includes your own scanned copy once you own it.

Run `rag_build.py` (included) to turn a folder of `.txt`/`.pdf` files into a searchable local vector index using a small embedding model (`all-MiniLM-L6-v2`, ~90MB, runs fine on the Pi). This gives you fast, accurate, grounded lookups instead of hallucinated answers.

---

## Phase 4 — Main application loop
`main.py` (included) does:
1. Take a typed question (from keyboard now, keypad later).
2. Retrieve the most relevant passages from your indexed library.
3. Feed those passages + the question to the local LLM, asking it to answer *using only the retrieved text*.
4. Print the answer to the terminal (Phase 4) or the e-ink screen (Phase 5).

This keeps responses grounded in real reference material while still letting you ask natural-language follow-up questions.

---

## Phase 5 — Screen + input (Arduino's role)
Two good options, both use your existing Arduino kit:

**Option A — Arduino as input controller only (simplest):**
- Wire a matrix keypad to the Arduino.
- Arduino sketch reads keypresses and sends them over USB-serial to the Pi as plain text.
- Pi's `main.py` reads from the serial port instead of a keyboard.
- E-ink display connects directly to the Pi's SPI/GPIO pins (Waveshare provides a Python library for this — no Arduino needed for the display side).

**Option B — Arduino as full front-end controller:**
- Arduino drives the keypad AND a small character LCD (like a 16x2 or Nokia 5110) directly, if you want the e-ink display reserved for longer "read mode" pages later.
- Pi does all the thinking, sends short text back to Arduino over serial, Arduino displays it.

Start with Option A — it's less wiring and uses the e-ink screen's real strength (long, readable, power-free text).

---

## Phase 6 — Power system
- Pi 5 pulls roughly 3-5W idle, up to 8-12W during LLM inference (CPU maxed on all 4 cores).
- A 20-30W solar panel + a LiFePO4 power bank (10,000-20,000mAh) rated for at least 3A output will keep it running through daylight outages and store enough for overnight use.
- Add a UPS HAT if you want safe automatic shutdown when the battery gets low, to avoid SD card corruption.
- e-ink displays draw power only when refreshing the screen, not while showing static text — this is the biggest power win in the whole design, so lean on it (update the screen only when there's a new answer, not continuously).

---

## Phase 7 — Enclosure & assembly
- Keep the official heatsink/fan case; LLM inference will run the CPU hot for sustained periods.
- 3D print or hand-build a simple two-layer enclosure: Pi + battery on the bottom, e-ink screen + keypad on top, similar to a chunky calculator or a Game Boy.
- Route the fan intake/exhaust so it's not blocked by the enclosure.

---

## Suggested build order (what to actually do first)
1. Today: flash the Pi, SSH in, run `setup.sh`, confirm the model answers questions in the terminal.
2. This week: gather Tier 1 public-domain texts, run `rag_build.py`, confirm grounded answers work better than raw model answers.
3. When display arrives: wire up e-ink, get `main.py` printing to it instead of the terminal.
4. When keypad/Arduino wiring is ready: swap keyboard input for serial input from the Arduino.
5. Last: add solar + battery, test a full day unplugged.
