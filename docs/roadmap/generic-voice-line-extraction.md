# Generic voice-line extraction

**Status:** Ready to build. Small, standalone; ideally lands before (or
with) the next new engine.

**What:** Replace the per-template branches in `tools/generate_voice.py`
(`pack_lines()`) with a generic walker over any template config, keyed by
naming convention:

- In any dict: `spoken` overrides a sibling `prompt`/`question`; whichever
  wins is a spoken line.
- `success`, `hint`, `name` values and `names` array elements are spoken.
- Level `intro` is spoken (already generic).

**Why:** New engines then need zero generator changes — the convention
becomes the contract. Document it in `packs/SCHEMA.md` as a house rule for
engine authors.

## Invariants

- Normalization (`" ".join(text.split())`) and hashing are untouched — they
  must keep matching `VoiceBank.swift`.
- Acceptance test: `--dry-run` before and after the refactor must report
  identical line counts per unit (app 43, world.dinosaurs 100,
  world.numbers 113 as of 2026-07) and zero clips to generate on the
  existing bank.
