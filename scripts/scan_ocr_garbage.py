"""
scan_ocr_garbage.py — find passages whose OCR text is garbled (LEARNINGS L-023/L-026).

OCR turns figures and tables into garbage ("Do r*Ql 6ai tor 5 hcur^"), and the
device then answers from text it cannot read. Run after adding any OCR'd book:

    venv/bin/python scripts/scan_ocr_garbage.py          # from the project root

A token counts as garbage if it mixes letters with symbols/digits inside a word,
or is a non-word seen <= 2 times in the whole corpus (length >= 3).
Score = garbage tokens / tokens. Passages above THRESHOLD are written to
ocr_scan_results.json for a human to review (expect false alarms: name lists,
Latin species names, book indexes).
"""
import collections, json, os, pickle, re, statistics as st
THRESHOLD = 0.15
chunks = pickle.load(open("chunks.pkl", "rb"))
tok = lambda t: re.findall(r"\S+", t)
words = collections.Counter(w.lower() for c in chunks for w in re.findall(r"[A-Za-z]{3,}", c["text"]))
def score(text):
    ts = tok(text); g = 0
    for t in ts:
        core = t.strip(".,;:!?()[]\"'-")
        if not core: continue
        mixed = re.search(r"[A-Za-z][^A-Za-z\s'\-.,][A-Za-z]|[A-Za-z]\d[A-Za-z]|\d[a-z]{2}", core) and not re.fullmatch(r"\d+(st|nd|rd|th|s)", core)
        rare = re.fullmatch(r"[A-Za-z]{3,}", core) and words[core.lower()] <= 2
        g += bool(mixed or rare)
    return g / max(len(ts), 1)
rows = [(score(c["text"]), i, c["source"]) for i, c in enumerate(chunks)]
by = collections.defaultdict(list)
for s, i, src in rows: by[src].append(s)
print("== per source: chunks, median score, chunks with score > THRESHOLD")
for src, v in sorted(by.items(), key=lambda x: -st.median(x[1])):
    print(f"{len(v):5d}  med {st.median(v):.3f}  bad {sum(x > THRESHOLD for x in v):4d}  {src}")
bad = sorted([r for r in rows if r[0] > THRESHOLD], reverse=True)
json.dump([dict(score=round(s, 3), idx=i, source=src, text=chunks[i]["text"]) for s, i, src in bad],
          open("ocr_scan_results.json", "w"), indent=0)
print(f"== {len(bad)} passages with score > THRESHOLD saved to ocr_scan_results.json")
for s, i, src in bad[:12]:
    print(f"{s:.2f} [{i}] {src}: {chunks[i]['text'][:150]!r}")
