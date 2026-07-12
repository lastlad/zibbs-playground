# Content Pack Schema (v1)

A **content pack** is a single JSON file that defines one whole world —
planet card, journey map, and every level — using the app's built-in
**template engines**. The app loads packs from two places (same pack id:
highest `version` wins):

1. **Bundled** — files in `ZibbsPlayground/Packs/` compiled into the app
2. **Downloaded** — fetched by PackSync from `packs/manifest.json` in this repo

A pack that fails validation is skipped silently — the app never crashes or
shows an error over bad content. Validate before shipping:

```bash
python3 tools/validate_pack.py ZibbsPlayground/Packs/world.numbers.json
python3 tools/validate_pack.py --all          # every pack + manifest consistency
```

## Top level

```json
{
  "schemaVersion": 1,
  "id": "world.numbers",
  "version": 1,
  "worldID": "M",
  "name": "Number Nebula",
  "tagline": "Count and play with numbers!",
  "emoji": "🔢",
  "accent": "pink",
  "accentSecondary": "purple",
  "ring": false,
  "levels": [ ... ]
}
```

| Field | Rules |
|---|---|
| `schemaVersion` | Always `1` for now. Apps skip packs with a newer schema than they understand. |
| `id` | Globally unique, stable forever (`world.<topic>`). |
| `version` | Integer. **Bump every time you change the pack** — devices re-download only on version increase. |
| `worldID` | Short unique prefix for level ids, unique across all packs. |
| `emoji` | Shown on the planet card. |
| `accent` / `accentSecondary` | Named theme colors: `green`, `blue`, `purple`, `orange`, `pink`, `yellow`, `ice`, `red`. |
| `ring` | Optional. Draws a Saturn-style ring on the home-screen planet. |
| `levels` | 1–12 levels. Ids must start with `worldID` (`M01`, `M02`, …). Levels unlock in order. |

## Levels

Every level has `id`, `title`, `concept`, `emoji` (map node icon), `intro`
(narrated by Zibb when the level starts), a `template` name, and a config
object **under a key with the same name as the template**:

```json
{
  "id": "M01",
  "title": "Comet Count",
  "concept": "Counting 1 to 4",
  "emoji": "☄️",
  "intro": "Look, comets! Let's count them together!",
  "template": "countTap",
  "countTap": { "rounds": [ ... ] }
}
```

## Visuals

Game pieces are described by a **visual** — exactly one of:

```json
{ "emoji": "🦊" }               // one big emoji
{ "text": "3" }                 // a big glyph (numerals, letters, short words)
{ "emoji": "⭐", "count": 4 }   // a countable cluster (count 1–10)
```

## The five templates

### `tapChoice` — tap the right one

Rounds of a question plus 2–4 tappable options.

```json
"tapChoice": {
  "shuffleOptions": true,          // optional, default true
  "rounds": [{
    "question": "Which one is the number three?",   // shown in the bar
    "spoken": "Can you find the number three?",     // optional narration
    "options": [{ "text": "1" }, { "text": "3" }, { "text": "5" }],
    "answer": 1,                    // index into options (pre-shuffle)
    "success": "Yes! That's three!",// optional, spoken on the right tap
    "hint": "Look for three!"       // optional, spoken on a wrong tap
  }]
}
```

Covers: quizzes, "find the numeral", "which group has more/fewer"
(cluster options; set `shuffleOptions: false` if lines mention sides),
"what comes next" pattern questions.

### `countTap` — tap and count out loud

Each round scatters `count` copies of an emoji; the child taps each one
while Zibb counts, and a big numeral ticks up.

```json
"countTap": {
  "rounds": [{
    "prompt": "Tap each comet and count!",
    "spoken": "optional narration",
    "emoji": "☄️",
    "count": 3,                     // 1–10
    "success": "Three comets!"      // optional
  }]
}
```

### `matchPairs` — drag pieces onto their partners

Targets with empty sockets; drag the loose piece into the right socket.

```json
"matchPairs": {
  "prompt": "Drag each number to its matching group!",
  "spoken": "optional narration",
  "perRound": 3,                    // optional, 2–3, default 3
  "pairs": [{
    "drag":    { "text": "2" },
    "target":  { "emoji": "🌙", "count": 2 },
    "success": "Two moons!"         // optional
  }]
}
```

### `sortBins` — drag items into labeled bins

2–3 bins; items arrive in small waves.

```json
"sortBins": {
  "prompt": "Count each group, then drag it to its number!",
  "spoken": "optional narration",
  "perWave": 3,                     // optional, 2–4, default 4
  "bins":  [{ "label": "Two", "emoji": "2️⃣" }, { "label": "Three", "emoji": "3️⃣" }],
  "items": [{ "emoji": "🍎", "count": 2, "bin": 0, "name": "Two apples!" }]
}
```

Items are flattened visuals plus `bin` (index) and optional `name`
(spoken on a correct drop).

### `orderSequence` — tap them in order

Numbered slots fill left to right as the child taps the next item.

```json
"orderSequence": {
  "rounds": [{
    "prompt": "Tap the numbers in order!",
    "spoken": "optional narration",
    "items": [{ "text": "1" }, { "text": "2" }, { "text": "3" }],   // 3–6, CORRECT order
    "names": ["One!", "Two!", "Three!"],   // optional, spoken as each lands
    "success": "One, two, three!"          // optional
  }]
}
```

Covers: counting up/down, life cycles, size ordering, story sequencing.

## Spoken-key convention (for engine authors)

The voice pipeline finds spoken lines in any template config by key name,
not by template — new engines need no changes in `tools/generate_voice.py`
as long as they keep to the convention:

- In any object, `spoken` overrides a sibling `prompt`/`question`;
  whichever wins is spoken.
- `success`, `hint`, and `name` values, and every element of a `names`
  array, are always spoken.
- Nothing else is ever spoken (`question`-bar text, `label`, `text`,
  `emoji` are display-only unless paired per the rules above).

## Publishing a pack

1. Add the JSON to `ZibbsPlayground/Packs/` (ships in the next app build) —
   or `packs/` for server-only packs.
2. Run `python3 tools/validate_pack.py --all`.
3. Add/update its entry in `packs/manifest.json` — **bump `version`**.
4. Push a branch and open a PR. The Voice bank workflow records Zibb's
   voice for every new line and commits the clips to your branch (it also
   maintains `voiceVersion`/`voiceFile` in the manifest — never edit those
   by hand). Listen via the workflow's `new-voice-clips` artifact.
5. Merge to `main`. Devices pick up the pack and its voice on their next
   foreground sync (bundled packs also ship with the next Xcode build).

Packs never reference audio files. Every `intro`/`spoken`/`success`/`hint`/
`name` line is matched to a clip by a hash of its text — edit a line and
the pipeline records a new clip for it; until a device syncs the clip, the
line falls back to on-device text-to-speech.

## Writing for a 4–5 year old (house rules)

- Zibb narrates everything; write `intro`/`spoken` lines in a warm,
  excited voice, one short sentence or two.
- Wrong answers are never punished — hints should encourage and re-teach.
- 3–5 rounds per level; keep language concrete ("tap the group with three
  moons", not "select the correct quantity").
- Emoji are the entire art budget: pick large, distinct, colorful ones.
