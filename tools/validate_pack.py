#!/usr/bin/env python3
"""Validate Zibb's Playground content packs (see packs/SCHEMA.md).

Mirrors the checks the app performs in PackModels.swift — a pack that fails
here would be silently skipped on device, so run this before publishing.

Usage:
    python3 tools/validate_pack.py path/to/pack.json [more.json ...]
    python3 tools/validate_pack.py --all     # every pack + manifest consistency
"""

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BUNDLED_DIR = REPO_ROOT / "ZibbsPlayground" / "Packs"
MANIFEST = REPO_ROOT / "packs" / "manifest.json"

CURRENT_SCHEMA = 1
COLORS = {"green", "blue", "purple", "orange", "pink", "yellow", "ice", "red"}
TEMPLATES = {"tapChoice", "sortBins", "matchPairs", "countTap", "orderSequence"}
RESERVED_WORLD_IDS = set()   # no built-in worlds; all ids are packs


def is_valid_visual(v):
    if not isinstance(v, dict):
        return False
    emoji, text, count = v.get("emoji"), v.get("text"), v.get("count")
    if count is not None:
        return (
            isinstance(count, int)
            and 1 <= count <= 10
            and isinstance(emoji, str)
            and emoji
            and text is None
        )
    has_emoji = isinstance(emoji, str) and bool(emoji)
    has_text = isinstance(text, str) and bool(text)
    return has_emoji != has_text


def require(errors, condition, message):
    if not condition:
        errors.append(message)


def check_tap_choice(errors, level_id, cfg):
    rounds = cfg.get("rounds")
    require(errors, isinstance(rounds, list) and rounds, f"{level_id}: tapChoice needs rounds")
    for i, rnd in enumerate(rounds or [], 1):
        where = f"{level_id} round {i}"
        require(errors, isinstance(rnd.get("question"), str) and rnd["question"],
                f"{where}: missing question")
        options = rnd.get("options")
        require(errors, isinstance(options, list) and 2 <= len(options) <= 4,
                f"{where}: needs 2-4 options")
        answer = rnd.get("answer")
        require(errors, isinstance(answer, int) and options and 0 <= answer < len(options or []),
                f"{where}: answer index out of range")
        for j, opt in enumerate(options or [], 1):
            require(errors, is_valid_visual(opt), f"{where} option {j}: invalid visual")


def check_sort_bins(errors, level_id, cfg):
    bins = cfg.get("bins")
    items = cfg.get("items")
    require(errors, isinstance(bins, list) and 2 <= len(bins) <= 3,
            f"{level_id}: sortBins needs 2-3 bins")
    for i, b in enumerate(bins or [], 1):
        require(errors, isinstance(b.get("label"), str) and isinstance(b.get("emoji"), str),
                f"{level_id} bin {i}: needs label and emoji")
    require(errors, isinstance(items, list) and items, f"{level_id}: sortBins needs items")
    require(errors, isinstance(cfg.get("prompt"), str) and cfg["prompt"],
            f"{level_id}: sortBins needs a prompt")
    for i, item in enumerate(items or [], 1):
        where = f"{level_id} item {i}"
        require(errors, isinstance(item.get("bin"), int) and 0 <= item["bin"] < len(bins or []),
                f"{where}: bin index out of range")
        visual = {k: item.get(k) for k in ("emoji", "text", "count") if item.get(k) is not None}
        require(errors, is_valid_visual(visual), f"{where}: invalid visual")
    per_wave = cfg.get("perWave")
    require(errors, per_wave is None or (isinstance(per_wave, int) and 2 <= per_wave <= 4),
            f"{level_id}: perWave must be 2-4")


def check_match_pairs(errors, level_id, cfg):
    pairs = cfg.get("pairs")
    require(errors, isinstance(pairs, list) and pairs, f"{level_id}: matchPairs needs pairs")
    require(errors, isinstance(cfg.get("prompt"), str) and cfg["prompt"],
            f"{level_id}: matchPairs needs a prompt")
    for i, pair in enumerate(pairs or [], 1):
        where = f"{level_id} pair {i}"
        require(errors, is_valid_visual(pair.get("drag")), f"{where}: invalid drag visual")
        require(errors, is_valid_visual(pair.get("target")), f"{where}: invalid target visual")
    per_round = cfg.get("perRound")
    require(errors, per_round is None or (isinstance(per_round, int) and 2 <= per_round <= 3),
            f"{level_id}: perRound must be 2 or 3")


def check_count_tap(errors, level_id, cfg):
    rounds = cfg.get("rounds")
    require(errors, isinstance(rounds, list) and rounds, f"{level_id}: countTap needs rounds")
    for i, rnd in enumerate(rounds or [], 1):
        where = f"{level_id} round {i}"
        require(errors, isinstance(rnd.get("prompt"), str) and rnd["prompt"],
                f"{where}: missing prompt")
        require(errors, isinstance(rnd.get("emoji"), str) and rnd["emoji"],
                f"{where}: missing emoji")
        require(errors, isinstance(rnd.get("count"), int) and 1 <= rnd["count"] <= 10,
                f"{where}: count must be 1-10")


def check_sequence(errors, level_id, cfg):
    rounds = cfg.get("rounds")
    require(errors, isinstance(rounds, list) and rounds, f"{level_id}: orderSequence needs rounds")
    for i, rnd in enumerate(rounds or [], 1):
        where = f"{level_id} round {i}"
        require(errors, isinstance(rnd.get("prompt"), str) and rnd["prompt"],
                f"{where}: missing prompt")
        items = rnd.get("items")
        require(errors, isinstance(items, list) and 3 <= len(items) <= 6,
                f"{where}: needs 3-6 items")
        for j, item in enumerate(items or [], 1):
            require(errors, is_valid_visual(item), f"{where} item {j}: invalid visual")
        names = rnd.get("names")
        require(errors, names is None or (isinstance(names, list) and len(names) == len(items or [])),
                f"{where}: names must have one entry per item")


TEMPLATE_CHECKS = {
    "tapChoice": check_tap_choice,
    "sortBins": check_sort_bins,
    "matchPairs": check_match_pairs,
    "countTap": check_count_tap,
    "orderSequence": check_sequence,
}


def validate_pack(path):
    errors = []
    try:
        pack = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return None, [f"cannot parse: {exc}"]

    require(errors, pack.get("schemaVersion") == CURRENT_SCHEMA,
            f"schemaVersion must be {CURRENT_SCHEMA}")
    require(errors, isinstance(pack.get("id"), str) and pack["id"], "missing pack id")
    require(errors, isinstance(pack.get("version"), int) and pack["version"] >= 1,
            "version must be an integer >= 1")
    world_id = pack.get("worldID")
    require(errors, isinstance(world_id, str) and world_id and world_id not in RESERVED_WORLD_IDS,
            "worldID missing or reserved")
    for key in ("name", "tagline", "emoji"):
        require(errors, isinstance(pack.get(key), str) and pack[key], f"missing {key}")
    for key in ("accent", "accentSecondary"):
        require(errors, pack.get(key) in COLORS,
                f"{key} must be one of: {', '.join(sorted(COLORS))}")

    levels = pack.get("levels")
    require(errors, isinstance(levels, list) and 1 <= len(levels) <= 12, "needs 1-12 levels")
    seen_ids = set()
    for level in levels or []:
        level_id = level.get("id", "<no id>")
        require(errors, level_id not in seen_ids, f"duplicate level id {level_id}")
        seen_ids.add(level_id)
        require(errors, isinstance(level_id, str) and world_id and level_id.startswith(world_id),
                f"level id {level_id} must start with worldID '{world_id}'")
        for key in ("title", "concept", "emoji", "intro"):
            require(errors, isinstance(level.get(key), str) and level[key],
                    f"{level_id}: missing {key}")
        template = level.get("template")
        if template not in TEMPLATES:
            errors.append(f"{level_id}: unknown template '{template}'")
            continue
        cfg = level.get(template)
        if not isinstance(cfg, dict):
            errors.append(f"{level_id}: missing config object under key '{template}'")
            continue
        TEMPLATE_CHECKS[template](errors, level_id, cfg)

    return pack, errors


def validate_manifest(packs_by_path):
    errors = []
    try:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest: cannot parse: {exc}"]

    require(errors, manifest.get("schemaVersion") == CURRENT_SCHEMA,
            f"manifest: schemaVersion must be {CURRENT_SCHEMA}")
    for entry in manifest.get("packs", []):
        file = entry.get("file", "")
        path = REPO_ROOT / file
        if not path.is_file():
            errors.append(f"manifest: file not found: {file}")
            continue
        pack, pack_errors = validate_pack(path)
        if pack_errors:
            errors.append(f"manifest: {file} is not a valid pack")
            continue
        if pack["id"] != entry.get("id"):
            errors.append(f"manifest: id '{entry.get('id')}' != pack id '{pack['id']}' in {file}")
        if pack["version"] != entry.get("version"):
            errors.append(
                f"manifest: version {entry.get('version')} != pack version "
                f"{pack['version']} in {file} (keep them in sync)")
        packs_by_path.pop(path.resolve(), None)
    return errors


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        print(__doc__)
        return 0

    if argv[1] == "--all":
        paths = sorted(BUNDLED_DIR.glob("*.json")) + sorted(
            p for p in (REPO_ROOT / "packs").glob("*.json") if p.name != "manifest.json")
    else:
        paths = [Path(p) for p in argv[1:]]

    failed = False
    unclaimed = {p.resolve(): p for p in paths}
    for path in paths:
        _, errors = validate_pack(path)
        if errors:
            failed = True
            print(f"FAIL  {path}")
            for error in errors:
                print(f"      - {error}")
        else:
            print(f"OK    {path}")

    if argv[1] == "--all":
        manifest_errors = validate_manifest(unclaimed)
        if manifest_errors:
            failed = True
            for error in manifest_errors:
                print(f"FAIL  {error}")
        else:
            print(f"OK    {MANIFEST.relative_to(REPO_ROOT)}")
        for path in unclaimed.values():
            print(f"NOTE  {path.relative_to(REPO_ROOT)} is not listed in packs/manifest.json "
                  "(bundled-only pack; add it to publish over the air)")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
