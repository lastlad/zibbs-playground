---
name: make-pack
description: Create a new Zibb's Playground content pack (a JSON world of levels) for a given topic, e.g. "/make-pack letters and first words" or "/make-pack dinosaurs". Use whenever asked to add a new world, new levels, or teach a new topic without writing Swift.
---

# Make a Content Pack

Create one JSON file that defines a whole new world for the Zibb's Playground
app — no Swift, no Xcode. The app's five template engines play it.

## Steps

1. **Read `packs/SCHEMA.md`** end to end. It defines the format, the five
   templates (`tapChoice`, `countTap`, `matchPairs`, `sortBins`,
   `orderSequence`), and the house rules for writing for a 4–5 year old.
2. **Read `ZibbsPlayground/Packs/world.numbers.json`** as the reference for
   tone, narration style, difficulty ramp, and structure.
3. **Design the world**: 8–10 levels, easy → hard, mixing templates so no
   two consecutive levels feel the same. Level 1 must be winnable by a
   4-year-old on the first try; the last level is a celebratory review.
   Pick an unused `worldID` letter (check every pack in
   `ZibbsPlayground/Packs/` and `packs/`) and a unique pack id `world.<topic>`.
4. **Write the pack** to `ZibbsPlayground/Packs/world.<topic>.json` with
   `"version": 1` (bundled + publishable). If the user wants it
   over-the-air only, put it in `packs/` instead.
5. **Validate**: `python3 tools/validate_pack.py --all` — must print OK.
   Fix and re-run until clean.
6. **Publish**: add an entry to `packs/manifest.json` (`id`, `version`,
   `file` path relative to repo root). If updating an existing pack instead
   of creating one, bump `version` in BOTH the pack and the manifest.
7. Commit and push to the branch you're asked to work on. Once merged to
   `main`, online devices pick the pack up automatically on their next
   launch; bundled packs also ship with the next Xcode build.

## Constraints

- Emoji are the entire art budget — choose big, distinct, colorful ones.
- Every visual is exactly one of `{"emoji"}`, `{"text"}`, or
  `{"emoji","count" (1–10)}`.
- Zibb speaks every `intro`/`spoken`/`success`/`hint` line out loud via
  text-to-speech: keep lines short, warm, and phonetic (write "Whoooosh!",
  not "*whoosh sfx*"; no emoji inside spoken strings).
- Wrong answers must never punish: hints re-teach ("Count each side!"),
  never scold.
- `accent`/`accentSecondary` come from the named palette in SCHEMA.md;
  pick a combination not already used by another world.
