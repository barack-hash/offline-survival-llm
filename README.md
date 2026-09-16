# Offline Survival LLM Device

A portable, fully offline reference device: Raspberry Pi 5 running a
local LLM (Qwen2.5-3B-Instruct via llama.cpp) grounded in a curated library of
public-domain survival and rebuilding manuals via RAG. Physical keypad
input (Arduino), e-ink display, battery + solar power. Built for use
during outages and disasters — no internet required after setup.

**This device is a reference aid, not a sole authority.** For anything
safety-critical (medical dosing, structural loads, electrical work), it
shows verbatim source text and warns when only one source backs a claim —
and you should still cross-check against a second source before acting.

## Project documents
- `IMPLEMENTATION_PLAN.md` — phase-by-phase build plan with acceptance criteria
- `CLAUDE.md` — operating + logging rules for Claude Code
- `BUILD_PLAN.md` — original architecture and design decisions
- `CORPUS_CHECKLIST.md` — the knowledge library gathering checklist
- `docs/BUILD_LOG.md` — dated journal of every session: mistakes, fixes, decisions
- `docs/HARDWARE.md` — every tool and component used
- `docs/CORPUS_SOURCES.md` — provenance of every reference text

## Status
Phases 0-5a in progress (software brain + keypad input). Awaiting
hardware for: e-ink display (5b), UPS battery (6), enclosure (7).
