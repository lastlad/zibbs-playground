# Letters glyphs + first letters world

**Status:** Blocked on trace-glyph-engine.md.

**What:** Grow `ZibbsPlayground/Trace/glyphs.json` with uppercase A–Z
(lowercase later, if the uppercase world lands well), then `/make-pack` a
letters world mixing traceGlyph levels with the existing engines
(tapChoice for letter recognition, orderSequence for simple words).

**Why zero Swift:** the trace engine reads any glyph in the library, and
`validate_pack.py` picks up new names from the same JSON automatically.

## Notes

- Glyph geometry: adapt Hershey single-stroke fonts; keep stroke order and
  direction consistent with how letters are actually taught.
- The glyphs ship in the app bundle → letters packs need a TestFlight build
  carrying the grown library before the pack merges (same rollout rule as
  the engine itself).
- Voice: nothing to do — pack lines are recorded by CI like any other pack.
