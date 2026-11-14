# TOP_K 4 vs 3 (normal questions), Pi 5, Qwen2.5-3B Q4_K_M — 2026-11-14

9 non-critical questions from `eval_questions.py`. Each run starts from a fresh KV
cache (`llm.reset()`), arm order alternates per question, temperature 0.3, streaming
on. Raw answers: `answers.jsonl`. Temperature during runs: 71–76 °C;
`throttled=0x80000` (soft temperature limit hit).

| Question | k=4 prompt tok | k=4 first words / total | k=3 prompt tok | k=3 first words / total | Better |
|---|---|---|---|---|---|
| Fire, wet wood | 1459 | 57.9 / 78.5 s | 1182 | 45.8 / 74.9 s | same |
| River water | 1323 | 51.8 / 121.9 s | 1076 | 41.5 / 69.1 s | k=3 (k=4 rambled: "dry your clothes / raft") |
| Cold-forest shelter | 1400 | 55.2 / 119.4 s | 1116 | 43.1 / 69.1 s | k=4 (build steps were passage #4) |
| Edible plants | 1375 | 54.1 / 110.2 s | 1128 | 43.6 / 97.2 s | k=3 (k=4 invented a "20-minute" test) |
| Deep cut | 1392 | 54.8 / 103.1 s | 1108 | 42.8 / 101.4 s | k=4 (kept "<12 h close" rule) |
| Infected tooth | 1374 | 54.1 / 110.5 s | 1093 | 42.2 / 72.5 s | k=4 (k=3 said "manual has no steps"; steps were passage #1 in both, so this is sampling noise) |
| Bean seed depth | 1343 | 52.7 / 78.7 s | 1101 | 42.6 / 65.8 s | same |
| Forged knife | 1450 | 57.4 / 103.7 s | 1179 | 45.7 / 109.6 s | k=3 (correct cherry-red + oil-on-water) |
| Car firmware (out of corpus) | 1449 | 57.3 / 69.6 s | 1171 | 45.4 / 56.8 s | same (both declined) |
| **Mean** | **1396** | **55.0 / 99.5 s** | **1128** | **43.6 / 79.6 s** | 3 / 3 / 3 |

Retrieval suite (book-level): 34/34 at k=3 and k=4; 31/34 at k=2; 28/34 at k=1.

System-prompt reuse (prompt reading only, max_tokens=1): fresh 51.7 s, right after
another normal question **42.4 s**, right after a critical question 53.7 s.
