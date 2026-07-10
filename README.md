# 🛸 Zibb's Playground

The template-driven sibling of **Star Explorers**: a STEM learning iPad app
for little explorers (ages 4–6) where **every world is data**. Zibb the
alien hosts planets full of mini-games, and each planet is a single JSON
**content pack** played by the app's reusable **game engines** — so new
topics ("numbers", "letters", "dinosaurs") ship without writing a line of
Swift, and reach the iPad over the air without a rebuild.

**Offline-first.** Narration is on-device text-to-speech, sound effects are
synthesized in code, art is procedural graphics + emoji. No ads, no
tracking, and everything plays with zero internet. When the iPad happens to
be online, the app quietly checks this repo for new packs.

The division of labor between the two apps:

| | Zibb's Playground (this repo) | Star Explorers |
|---|---|---|
| Games | 5 reusable template engines | 20 hand-crafted mini-games |
| Worlds | JSON content packs | Swift, bespoke |
| New content | Push JSON to `main` → over the air | Xcode rebuild |
| Grows by | New packs (and occasionally new engines) | New one-of-a-kind games |

## The game engines

Every level in a pack is an instance of one of these:

| Template | The child... |
|---|---|
| `tapChoice` | ...taps the right one of 2–4 options (quizzes, more/fewer, find-the-numeral) |
| `countTap` | ...taps each item while Zibb counts out loud, numeral ticking up alongside |
| `matchPairs` | ...drags pieces onto the partner they belong with |
| `sortBins` | ...drags items into 2–3 labeled bins, in small waves |
| `orderSequence` | ...taps shuffled items in their correct order to fill a slot rail |

All the polish lives once in the engines — narration, gentle wrong-answer
encouragement, stars, celebrations — so every pack level feels hand-made.

## Content packs

A pack is one JSON file defining a whole world: planet card, journey map,
all levels, every narrated line. The format is documented in
[`packs/SCHEMA.md`](packs/SCHEMA.md). The first world, **Number Nebula**
(counting, numerals, more/less, ordering — 10 levels), is bundled at
`ZibbsPlayground/Packs/world.numbers.json`.

Packs reach the iPad two ways:

1. **Bundled** — files in `ZibbsPlayground/Packs/` ship inside the app.
2. **Over the air** — the app checks [`packs/manifest.json`](packs/manifest.json)
   on this repo's `main` branch when it comes to the foreground online, and
   downloads new or newer-versioned packs. Sync is silent: no connection,
   no errors, the child never notices.

### Adding a new world

1. In a Claude Code session on this repo, run **`/make-pack <topic>`** —
   it designs 8–10 levels, writes the JSON, and validates it. (Or write the
   JSON by hand following `packs/SCHEMA.md`.)
2. Check it: `python3 tools/validate_pack.py --all`
3. Add an entry to `packs/manifest.json` (bump `version` when updating an
   existing pack — devices only re-download on version increase).
4. Merge to `main`. Every iPad picks it up next time the app opens with
   Wi-Fi.

Bad packs can't hurt anything — the app validates every file and silently
skips ones that don't pass, and star progress is keyed by level id so pack
updates never wipe earned stars.

### Adding a new game *type*

That's the one thing that still takes Swift: an engine view in
`ZibbsPlayground/Games/Engines/`, a config + case in
`ZibbsPlayground/Core/PackModels.swift`, a route in `GameCatalog.swift`,
and matching checks in `tools/validate_pack.py` + docs in
`packs/SCHEMA.md`. Ships with the next Xcode build; older app versions
skip packs that use templates they don't know.

## Building & installing on your iPad

Same drill as Star Explorers — a Mac with **Xcode 16+**, targeting
**iPadOS 16+**, landscape:

1. Open `ZibbsPlayground.xcodeproj`, select the target → *Signing &
   Capabilities* → check **Automatically manage signing** and pick your
   **Team** (a free Apple ID works).
2. Plug in the iPad, pick it as the destination, press **Run**.
3. First time: trust your developer certificate under *Settings → General →
   VPN & Device Management* on the iPad.

> ⏳ Free Apple ID installs expire after 7 days — press Run again to
> refresh. **Guided Access** (triple-click the top button) is great for
> locking the iPad into the app for small hands.

## Architecture

```
├── ZibbsPlayground.xcodeproj   # Xcode 16 project (folder-synced)
├── packs/
│   ├── manifest.json           # What the OTA sync checks on main
│   └── SCHEMA.md               # Full content-pack format reference
├── tools/validate_pack.py      # Validate packs before publishing
├── .claude/skills/make-pack/   # "/make-pack <topic>" generates a world
└── ZibbsPlayground/
    ├── ZibbsPlaygroundApp.swift  # Entry + screen router + sync trigger
    ├── Core/                     # AppState, pack models, library, sync,
    │                             #   GameContext contract, GameCatalog
    ├── Audio/                    # Offline TTS + synthesized sound effects
    ├── DesignSystem/             # Theme, starfield, shared components
    ├── Mascot/ZibbView.swift     # Procedural animated Zibb
    ├── Screens/                  # Home, world map, level host, celebration
    ├── Games/Engines/            # The five template engines
    └── Packs/                    # Bundled content packs (JSON worlds)
```
