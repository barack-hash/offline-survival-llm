# CLAUDE.md — Operating rules for Claude Code on this project

You are executing IMPLEMENTATION_PLAN.md for the offline-survival-llm
device (Raspberry Pi 5 + local LLM + RAG survival library). The owner's
core requirement: **EVERYTHING gets logged.** This project is as much a
documented build journal as it is a device.

## Mandatory logging discipline (applies to every phase, no exceptions)

1. **docs/BUILD_LOG.md** — append an entry for EVERY work session:
   ```
   ## YYYY-MM-DD — <short session title>
   **Goal:** what this session set out to do
   **Done:** what actually got done (commands run, files changed)
   **Mistakes/Challenges:** every error hit, wrong assumption, dead end —
     with the exact error message where applicable, and how it was resolved
   **Improvements/Decisions:** anything tuned or decided, and WHY
   **Hardware/Tools used:** anything physical touched this session
   **Next:** the immediate next step
   ```
   Mistakes are not embarrassing — they are the most valuable content in
   this log. Never omit or sanitize them.

2. **docs/HARDWARE.md** — the moment any tool, board, cable, or component
   is used for the first time, add it: name, model, source, cost if known,
   what it's used for.

3. **docs/CORPUS_SOURCES.md** — every document added to corpus/ gets a
   row: filename, origin URL, edition/date, license (PD/FREE/OWN).

4. **Git discipline:**
   - One logical change per commit, descriptive message
     (e.g. "phase3: index FM 21-76, 412 chunks" not "update").
   - Commit + push at the end of every session, always including the
     BUILD_LOG.md entry for that session.
   - NEVER commit: models/, index.faiss, chunks.pkl, venv/, corpus/own/
     (copyrighted scans stay local only — this is a legal requirement,
     not a preference).

5. **Benchmarks are log entries too:** tokens/sec, RAM usage, temperatures,
   battery runtimes — always record actual measured numbers, never just
   "it works".

## Working style
- Follow IMPLEMENTATION_PLAN.md phase order. Do not skip acceptance
  criteria — check each one explicitly before declaring a phase done.
- When something fails (URL 404, library conflict, wiring issue): fix it,
  but ALWAYS log the failure + fix as a Mistakes/Challenges entry first.
- One tuning change at a time during Phase 4 evaluation, so cause and
  effect stay traceable in the log.
- For hardware steps you cannot perform (physical wiring, photographing),
  give the owner precise instructions, then wait for confirmation +
  their observations, and log what they report.
- Create GitHub issues for deferred work (multi-tap input, phases 5b/6/7)
  so nothing lives only in someone's head.

## Safety rules baked into the product (do not weaken these)
- Critical-mode behavior in main.py (verbatim sources, corroboration
  warnings, temperature 0) exists because this device may be trusted in
  emergencies. Changes may strengthen it; never remove it.
- The corpus README should state plainly: this device is a reference
  aid, not a sole authority for medical dosing, structural, or
  electrical decisions.
