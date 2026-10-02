# Cost analysis — hardware tiers, models, and enclosure printing

Researched 2026-10-02. Prices move monthly (RAM shortage) — re-check before
any order. **(U)** = seen only in search snippets / listings, not confirmed
on the seller's page. **(E)** = my estimate, not researched.

## 1. Why the build is expensive
Raspberry Pi prices were raised three times (Dec 2025, Feb 2026, Apr 2026)
because of memory costs. The Pi 5 8GB is $175 at PiShop (fetched; launch
price was $80) — about half of the whole bill of materials. Alternatives
(Orange Pi 5, Radxa Rock 5C) are either as expensive, sold out, or can't
ship to the US right now. **The cost lever is a smaller-RAM Pi with a
smaller model, not a different brand of board.**

## 2. Which models fit which board (llama.cpp, Q4, CPU)

| Board (price) | Model | Gen tok/s | RAM | Notes |
|---|---|---|---|---|
| Pi 5 8GB ($175) | Qwen2.5-3B (current) | 5.4 measured | 4.4 GB measured* | what we run today |
| Pi 5 | Gemma 4 E2B | 7.0 | 3.2 GiB peak | [pi5-llm-arena](https://github.com/leemailto2008/pi5-llm-arena) |
| Pi 5 | Gemma 3 4B QAT | ~5 | 2.8 GB | [benchmark](https://www.kunalganglani.com/blog/gemma-3-raspberry-pi-5-benchmark) |
| Pi 5 | Gemma 3n E2B | ~6 | 2.5 GB | same |
| Pi 5 | Qwen2.5-1.5B / Qwen2 1.5B | 11–12 | ~1.8 GB | [Geerling](https://www.jeffgeerling.com/blog/2026/raspberry-pi-ai-hat-2/) |
| Pi 5 | Gemma 3 1B QAT | ~11 | ~0.9 GB | benchmark above |
| Pi 4 4GB ($100) | 1B–3B | ~1–3.4 (U) | — | slower **and** barely cheaper than Pi 5 4GB — skip |
| Pi Zero 2 W ($15) | any | — | 512 MB | doesn't fit — not viable |

\* 4.4 GB is the whole process (LLM + embedding model + FAISS index + OS
share). **TODO:** measure the LLM alone on the device — that decides
whether a 4GB board can keep the 3B model.

**Gemma 4** (released 2026-04-02, Apache 2.0): E2B/E4B accept audio
(≤30 s clips). Audio works in llama.cpp only via `llama-mtmd-cli`, with
open bugs (transcription loops/hallucination; llama-server rejects audio).
**Not yet a dependable speech-to-text replacement.**

**Voice interface (optional):** Moonshine STT (Pi 5 latency ~237 ms for
Tiny Streaming vs ~5.9 s Whisper Tiny, vendor figure) + Piper TTS (~5×
faster than real time on Pi 5). Hardware: INMP441 I2S mic ($1.59–4.95 U),
MAX98357A amp ($5.95), small speaker (~$2) ≈ **$10–13**. Realistically
needs a 4GB board alongside the LLM.

**NPU add-ons:** Hailo-10H / AI HAT+ 2 ($130) is *slower* than the Pi 5 CPU
for LLMs (Geerling: 5.9 vs 11.3 tok/s) — not a cost saver.

## 3. Hardware tiers (single-unit retail, per device)

| Part | Tier 1 — current | Tier 2 — Pi 5 4GB | Tier 3 — lean |
|---|---|---|---|
| Board | Pi 5 8GB **$175** | Pi 5 4GB **$110** | Pi 5 2GB **$65–78** |
| Model | Qwen2.5-3B | 3B if RAM allows, else Gemma 4 E2B / 1.5B | Qwen2.5-1.5B / Gemma 3 1B (faster, weaker) |
| Cooling | Active Cooler $10.95 | $10.95 | passive $5.95 (U) — only if thermal test passes |
| microSD | 64GB endurance ~$22 (U) | ~$22 | 32GB ~$10–15 (E) |
| UPS board | X1202 4-cell $51 | $51 | X1200 2-cell $45 (half the runtime) |
| 18650 cells | 4× Samsung 35E $24 (U) | $24 | 2× $12 (U) |
| Display | Waveshare 4.2" e-paper $28.99 | $28.99 | $28.99 |
| Keyboard | CardKB $7.95 | $7.95 | $7.95 |
| Enclosure (PLA) | ~$10 (library) | ~$10 | ~$10 |
| **Core subtotal** | **≈ $330** | **≈ $265** | **≈ $200–215** |
| Plumbing (real copper + brass fittings, ports, LED, switch, wire) | +$40–50 (E) | +$40–50 (E) | printed pipes +$15–20 (E) |

NCR18650B (the model Geekworm recommends) is sold out at
18650batterystore; Samsung 35E / Molicel P28A are the in-stock
equivalents — check they meet the X1202's "unprotected flat-top,
≤18.5 × 65.3 mm" rule.

**Volume (100 units):** no published Pi bulk price (quote-only via
Farnell/RS/DigiKey/Mouser). Published tiers: Waveshare e-paper $27.63 at
50–99, Adafruit ~−20% at 100+. Expect only modest savings at 100 units.

## 4. Printing the enclosure

Measured from the v0.6 STLs: **155 cm³ total ≈ 190 g PLA** (rear shell
101 cm³ / 126 g, bezel 23 cm³ / 28 g, all small parts ~30 cm³). Without
printed pipes (real copper): 146 cm³ ≈ 181 g.

| Option | Cost for one full set | Shipping | Notes |
|---|---|---|---|
| **Arlington Public Library "The Shop"** | PLA $0.05/g → **≈ $10** | local pickup | staff print; one job at a time; confirm bed fits the 177 mm shell ([APL](https://library.arlingtonva.libguides.com/theshop/3DPrinting)) |
| Home Bambu A1 ($299–399) | filament ≈ **$4–5** (PLA ~$20/kg; silk copper ~$17–20/kg) | — | pays for itself after ~6–10 sets; A1 mini's 180 mm bed is too tight for the 177 mm shell |
| Slant 3D (US print farm) | instant per-part quote, no minimum | domestic, no tariff | best for 10–100+ units without owning printers |
| Makelab (Brooklyn) | median for 150–250 mm parts **$71** — set likely ≈ $90–120 (E) | ships US | finished-quality FDM/SLA |
| Craftcloud | compares many vendors | free over $50 | watch import duty from overseas vendors |
| JLC3DP (resin / MJF) | instant quote, from $0.30/part | DHL/UPS at checkout | **+40% US duty prepaid since 2026-03-17**; budget +$25–40 |
| PCBWay | quote, **$25 minimum** + $5–20 setup | DHL/FedEx | — |

**Injection molding** only pays off past ~500–1,000 units: aluminium
tooling ≈ $6k–12k for a 2-part shell; ~$4.20/part at 1,000/yr.

## 5. Recommendations
1. **Don't print the real enclosure yet** — stack height, connector and
   port positions are still unmeasured. First print only the **bezel**
   as a fit test (28 g ≈ $1.40 at the library).
2. Measure the LLM's own RAM on the device; if Qwen2.5-3B + RAG fits
   under ~3.5 GB, **Tier 2 (Pi 5 4GB) saves $65/unit with no quality
   loss.**
3. Tier 3 (≈ $200–215) is viable for a cheaper model line, but the 1.5B
   models are noticeably weaker — re-run the Phase 4 eval battery and
   eval_retrieval before committing to it. Critical mode's verbatim
   sources still protect safety-critical answers.
4. Voice (Gemma 4 audio) — wait; Moonshine + Piper is the dependable
   route today if voice becomes a requirement.
