# traceGlyph — finger-tracing engine

**Status:** Designed, not started. Two open decisions below need the owner's
call before implementation.

**What:** Sixth template engine: the child traces a numeral/shape/letter
along a guided path. Unlocks handwriting and pre-writing packs.

## Design (settled)

- **Glyph library, app-owned:** `ZibbsPlayground/Trace/glyphs.json` — per
  glyph, ordered `strokes`, each a pre-sampled polyline of normalized
  `[x, y]` points in a unit box. Packs reference glyphs **by name only**.
  Adapt geometry from Hershey single-stroke fonts (public domain).
- **Pack config:** `"traceGlyph": { "rounds": [{ "glyph": "3", "prompt":
  ..., "spoken": ..., "success": ... }] }` — 3–5 rounds, standard spoken-key
  conventions so the voice pipeline needs nothing new.
- **Interaction:** pulsing start star; dashed guide path; ink fills as the
  finger advances monotonically along the polyline within a ~48pt tolerance
  corridor. Straying pauses ink at the last checkpoint (never resets, never
  punishes); lifting mid-stroke resumes. Stall for a few seconds →
  `context.tryAgain()`. Multi-stroke glyphs trace in order with numbered
  start dots. Finish = 3 stars, like every engine.
- **Feedback/narration:** all via `GameContext` — no new audio code.

## Touchpoints (the standard six — see README "Adding a new game type")

1. `Games/Engines/TraceGlyphEngine.swift`
2. `Core/PackModels.swift`: `TraceGlyphConfig` + case + decode/encode;
   `validate` checks glyph names against the bundled library
3. `Core/GameCatalog.swift`: route the case
4. `tools/validate_pack.py`: mirror checks; read `glyphs.json` for names
5. `tools/generate_voice.py`: extraction (moot if generic extraction lands first)
6. `packs/SCHEMA.md` + `.claude/skills/make-pack/SKILL.md`

## Rollout rule (important)

Old app builds silently skip any pack containing an unknown template. So:
merge the engine and get it onto devices via TestFlight **before** the first
tracing pack merges, and put tracing levels only in **new** packs — never
retrofit into existing ones.

## Open decisions

1. **v1 glyph set** — recommendation: digits 0–9 + circle, square, triangle,
   star, heart. Letters are a follow-up (see letters-glyph-pack.md).
2. **Stroke direction** — recommendation: enforce (start star + one-way
   progress; builds writing habits) vs. allow tracing from either end.

## Verify

Build for iPad simulator; `validate_pack.py --all` with a test pack that
references a bad glyph name (must FAIL); trace a digit end-to-end in the
simulator including stray-and-resume and multi-stroke.
