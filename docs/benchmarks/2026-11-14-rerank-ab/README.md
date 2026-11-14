# Rerank (cross-encoder, top 20 → 3) vs current hybrid (4) — Pi 5, 2026-11-14

Reranker: `cross-encoder/ms-marco-MiniLM-L-6-v2` (88 MB, HF cache, runs offline).
Critical questions bypass reranking (8 passages, unchanged — asserted in the run).

## Retrieval (eval_retrieval.py, 34 cases, passage-level)
| | hit@1 | hit@2 | hit@3 | hit@4 | MRR@10 |
|---|---|---|---|---|---|
| Hybrid RRF (current) | 23 | 28 | 31 | 32 | 0.797 |
| Rerank top 10 | 23 | 30 | 30 | 34 | 0.809 (1.1 s/question) |
| **Rerank top 20** | **26** | **30** | **32** | 33 | **0.855** (2.7 s/question) |

Moved up: shelter 4→1, river water 6→2, ropes 6→4, weld 3→1, snake bite 3→1.
Moved down: soil before sowing 2→6, windmill power 1→3.

## Answers (9 non-critical battery questions, temperature 0, fresh KV, alternating order)
| Question | Old first / total | New first / total | Better |
|---|---|---|---|
| Fire, wet wood | 58.2 / 81.4 s | 48.1 / 78.3 s | same (new calls it a lean-to fire; the "burns well wet" line belongs to the tepee) |
| River water | 52.5 / 119.6 s | 45.5 / 111.2 s | **new** (exact boil/iodine figures; old mostly about river crossing) |
| Cold-forest shelter | 56.1 / 99.9 s | 47.0 / 75.0 s | **new** (debris hut + ridgepole steps) |
| Edible plants | 55.2 / 110.2 s | 46.9 / 102.0 s | **old** (new says taste first; old keeps the avoid-list) |
| Deep cut | 56.0 / 108.0 s | 46.4 / 100.7 s | **old** (keeps "<12 h close" rule; new invents Neosporin) |
| Infected tooth | 55.5 / 100.5 s | 47.1 / 93.6 s | old, slightly |
| Bean depth | 54.2 / 73.4 s | 46.6 / 70.9 s | **new** (old misreads the experiment) |
| Forged knife | 56.7 / 131.7 s | 46.4 / 100.9 s | same |
| Car firmware (out of corpus) | 56.3 / 67.6 s | 52.2 / 65.9 s | same (both decline) |
| **Mean** | **55.6 / 99.1 s** | **47.4 / 88.7 s** | 3 new / 3 old / 3 same |

Retrieval (incl. rerank) 2.0–4.2 s; prompt 1058–1275 tokens new vs 1323–1459 old.
`throttled=0xe0000` (soft temperature limit hit).
