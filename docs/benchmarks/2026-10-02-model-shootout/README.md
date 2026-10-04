# Model shoot-out — 2026-10-02 (Raspberry Pi 5 8GB, llama.cpp CPU, Q4_K_M)

Same pipeline as the device (hybrid retrieval, same prompts, n_ctx 4096,
temperature 0.3 / 0.0 critical), 13 questions: the Phase 4 battery + 2
extra out-of-library refusals + 1 extra child-dose question. Script:
`scripts/eval_models.py`. Raw answers: the `.jsonl` files here.
Verdicts judged by reading every answer against the source passages.

## Speed and memory

| Model | File | Gen tok/s (median) | Time to first word (median) | Whole answer (median / max) | Peak RAM, LLM share |
|---|---|---|---|---|---|
| Qwen2.5-3B (current) | 1.93 GB | 5.36 | 46 s | 96 s / 141 s | 4.2 GB |
| Qwen3-4B-Instruct-2507 | 2.50 GB | 3.28 | 72 s | 188 s / 266 s | 5.4 GB |
| **Gemma 4 E2B** | 3.11 GB | **5.98** | **42 s** | **56 s / 159 s** | 4.1 GB |
| Gemma 4 E4B | 4.98 GB | 3.10 | 84 s | 136 s / 255 s | 6.5 GB |

"LLM share" = process peak RSS minus RSS before the model loaded. It
includes mmap'd model pages (reclaimable) and llama.cpp's ARM repacked
weight copy, so it overstates the true minimum — a real 4 GB-board test is
still needed.

## Answer quality (2 = good, 1 = partly wrong / vague, 0 = wrong)

| # | Question | Qwen2.5-3B | Qwen3-4B | Gemma4 E2B | Gemma4 E4B |
|---|---|---|---|---|---|
| 1 | fire with wet wood | 2 | 2 | 2 | 2 |
| 2 | river water safe to drink | 1 (river-crossing steps, invented salt/sugar advice) | 1 (invented "6-8 in", "24 h" figures) | 1 (no boiling; odd "radioactive") | 2 (seepage holes + boil/strain, as the manual says) |
| 3 | warm shelter, cold forest | 2 | 2 | 1 (mislabels debris hut as tree-pit shelter) | 2 |
| 4 | is a wild plant edible | 2 | 2 | 1 (too thin, no warning signs) | 2 |
| 5 | clean + cover deep cut | 2 | 2 | 2 | 2 |
| 6 | badly infected tooth | 1 (symptom list, no procedure) | 2 | **0 (garbled: "Noma… cancer")** | 2 |
| 7 | bean vs small-seed depth | 1 (self-contradicting) | **0 (invented depths, reversed)** | 2 | 2 |
| 8 | harden a forged knife | 1 ("bright red… not glowing red") | 2 | 2 | **0 (answered about a stone knife)** |
| 9 | aspirin dose, adult (critical) | 1 (figure right, "adults under 12" garble) | 2 (verbatim quote + source) | 2 (exact figure + source) | 2 (verbatim quote + source) |
| 10–12 | 3× not in the library | 6 (all refused) | 6 | 6 | 6 |
| 13 | acetaminophen child 8–12 (critical) | 2 (500 mg, no quote) | 2 (verbatim) | 2 (500 mg, 1 tablet, source) | 2 (verbatim) |
| | **Total /26** | **21** | **23** | **21** | **24** |

Caveats: 13 questions, one judge — differences of 1–3 points are within
noise. Every model refused all out-of-library questions and got both
critical doses numerically right.

## Thermals (finding)
Sustained inference for ~2 h drove the SoC to **84.5 °C** with the active
cooler at full speed (5151 rpm); `get_throttled` = 0xe0008 (soft
temperature limit hit, throttling occurred). Phase 1's 2-minute stress test
peaked at 70 °C — it was too short to show heat soak. All four models ran
under the same conditions, so the comparison is fair, but every number
above is a throttled number.

## Conclusions
- **Gemma 4 E2B is the fastest** (≈1.7× faster complete answers than the
  current model) at equal overall quality — better on doses (cites the
  source, no garbles), worse on two vague medical/survival answers.
- **Gemma 4 E4B is the most accurate** but ~1.4× slower than current and
  needs ~6.5 GB → 8 GB board only (works against the cost-down plan).
- **Qwen3-4B** quotes doses best but is the slowest here and invented
  specific numbers twice — the worst failure mode for this device.
- Published "Pi 5 ≈ 4 tok/s" for Gemma 4 E2B did not hold on this setup
  (measured 6.0).
