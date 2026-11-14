# Corpus OCR scan — 2026-11-14

**Why:** L-023 showed that FM 21-76's Universal Edibility Test (Figure 9-5) was
OCR garbage, so the device made up its own test. This scan looks for the same
problem across all 6,140 indexed passages.

**How:** `scripts/scan_ocr_garbage.py` scores each passage by the share of
"garbage" tokens (letters mixed with symbols/digits inside a word, or non-words
seen ≤ 2 times in the whole corpus). 42 passages scored above 0.15. All 42 were
reviewed by hand. **Check of the method:** it found the Figure 9-5 passage
(score 0.29) without being told about it.

## Per source

| Source | Passages | Median score | Flagged |
|---|---|---|---|
| hardening-tempering-steel-1903.txt | 356 | 0.030 | 13 |
| fm21-76-survival-manual.txt | 585 | 0.020 | 19 |
| where-there-is-no-doctor.pdf | 1150 | 0.010 | 6 |
| where-there-is-no-dentist.pdf | 341 | 0.005 | 3 |
| windmills-wind-motors-1910.txt | 93 | 0.020 | 1 |
| 11 other sources (Gutenberg plain text, first-aid, etc.) | 3,615 | 0.000–0.015 | 0 |

Project Gutenberg texts are clean (human-proofread), so the problem is limited
to archive.org OCR scans, and in practice mostly to **figures and tables**.

## Real garbled content, ranked by safety value

| # | What | Where | Why it matters | Can it be fixed from the OCR alone? |
|---|---|---|---|---|
| 1 | **Fig 6-2: effects of substitute fluids** (alcohol, urine, blood, seawater) | FM 21-76 p.55, passage 2375 | "Can I drink seawater/urine?" The readable text elsewhere only says "Do not drink seawater"; the *why* and the numbers (seawater ~4% salt, ~2 L body fluid lost per 1 L drunk; urine ~2% salt) are garbled | Mostly; numbers partly readable. Should be checked against the page image |
| 2 | **Fig 6-1: water sources by environment** (frigid, at sea, beach, desert…) | FM 21-76 pp.53–55, passages 2371–2374 | Where to find water, plus "do not drink seawater without desalting" | No, too garbled. Needs the page image |
| 3 | **Fig 13-2: daily water needs graph** (litres/day by temperature × workload) | FM 21-76 ch.13, passage 2552 | Desert water rationing; even the worked example's number is unreadable ("?5 liters") | No, it's a graph. Needs the page image |
| 4 | **Fig 19-6/19-7: ground-to-air signal codes** | FM 21-76 pp.205–206, passages 2735–2737 | Signalling rescuers; the symbols are drawings | No, symbols are shapes. Needs the page image |
| 5 | Fig 7-4: fire materials (tinder/kindling/fuel lists) | FM 21-76, passage 2391 | Lists are partly readable and the body text covers fire well | Mostly |
| 6 | Metric ↔ English conversion tables | hardening-tempering-steel-1903, passages 3084–3085 | Low; units are covered elsewhere | No |
| — | ~10 back-of-book **index pages** | hardening-tempering-steel-1903, passages 3144–3170 | Pure page-number noise; they only waste retrieval slots | Better to drop from the index |
| ✅ | Fig 9-5: Universal Edibility Test | FM 21-76 p.102 | Fixed 2026-11-14 (clean transcription + critical mode) | Done |

## False alarms (no action)

Acknowledgement/credit name lists (WTIND, WTIND-dentist), Latin snake species
names (FM 21-76 passage 2502), the antivenom distributor list, a 1910 book
advert, and several normal passages that just use rare words.

## Recommendation

Items 1–4 are all FM 21-76 figures. The reliable way to transcribe them is to
read the **page images**, not the OCR. Our source is archive.org's OCR text of
the June 1992 reprint; the same archive.org item also holds the scanned PDF.
With that PDF the figures can be read directly and transcribed like Figure 9-5,
each one checked against the image, with provenance in CORPUS_SOURCES.md.
Dropping the steel book's index pages is a separate, small retrieval clean-up.
