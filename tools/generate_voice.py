#!/usr/bin/env python3
"""Generate Zibb's voice clips for every spoken line in the app.

Extracts each speakable line from the content packs and from
ZibbsPlayground/Voice/app-lines.json (including every expansion of the
{world}/{stars}/{word} templates), synthesizes the missing ones with the
OpenAI text-to-speech API, and maintains the content-addressed voice bank
that the app's VoiceBank/Narrator play from:

    ZibbsPlayground/Voice/clips/<textHash16>-<audioHash8>.mp3
    ZibbsPlayground/Voice/<unit>.voice.json     one index per pack + "app"
    packs/manifest.json                         voiceVersion/voiceFile kept in sync

Idempotent and incremental: a clip is regenerated only if its line is new,
its text changed, or the voice changed. Safe to re-run at any time.

Usage:
    OPENAI_API_KEY=... python3 tools/generate_voice.py            # everything
    python3 tools/generate_voice.py --dry-run                     # no API calls
    OPENAI_API_KEY=... python3 tools/generate_voice.py --force    # regenerate all
    OPENAI_API_KEY=... python3 tools/generate_voice.py --voice nova
    OPENAI_API_KEY=... python3 tools/generate_voice.py --audition "Hi Explorer!"
"""

import argparse
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BUNDLED_DIR = REPO_ROOT / "ZibbsPlayground" / "Packs"
SERVER_DIR = REPO_ROOT / "packs"
VOICE_DIR = REPO_ROOT / "ZibbsPlayground" / "Voice"
CLIPS_DIR = VOICE_DIR / "clips"
APP_LINES = VOICE_DIR / "app-lines.json"
MANIFEST = SERVER_DIR / "manifest.json"
CLIPS_PATH_IN_REPO = "ZibbsPlayground/Voice/clips"

API_URL = "https://api.openai.com/v1/audio/speech"
MODEL = "gpt-4o-mini-tts"
DEFAULT_VOICE = "coral"
AUDITION_VOICES = ["coral", "nova", "shimmer", "fable", "alloy"]

# The one voice direction every clip is generated with, across every pack and
# every CI run — keep it stable so clips made months apart still match.
INSTRUCTIONS = (
    "You are Zibb, a friendly little alien narrating a learning game for a "
    "4-to-6-year-old child. Speak warmly and playfully, with gentle "
    "excitement and a smile in your voice. Pace it slow and clear enough for "
    "a preschooler to follow every word - never rushed, never flat."
)

MAX_COUNT = 10  # countTap counts 1..10 (see packs/SCHEMA.md)
STARS = [1, 2, 3]


def normalize(text):
    """Must match VoiceBank.normalize in Swift exactly."""
    return " ".join(text.split())


def text_hash(text):
    return hashlib.sha256(normalize(text).encode("utf-8")).hexdigest()[:16]


# --- Line extraction --------------------------------------------------------

def add(lines, text):
    if isinstance(text, str) and text.strip():
        lines.add(normalize(text))


def pack_lines(pack, app):
    """Every line Zibb speaks while a child plays this pack."""
    lines = set()
    world = pack.get("name", "")
    add(lines, app["mapWelcome"].replace("{world}", world))
    add(lines, app["newWorld"].replace("{world}", world))
    add(lines, app["celebrationFinale"].replace("{world}", world))

    for level in pack.get("levels", []):
        add(lines, level.get("intro"))
        template = level.get("template")
        cfg = level.get(template) or {}

        if template == "tapChoice":
            for rnd in cfg.get("rounds", []):
                add(lines, rnd.get("spoken") or rnd.get("question"))
                add(lines, rnd.get("success"))
                add(lines, rnd.get("hint"))
        elif template == "countTap":
            for rnd in cfg.get("rounds", []):
                add(lines, rnd.get("spoken") or rnd.get("prompt"))
                add(lines, rnd.get("success"))
        elif template == "matchPairs":
            add(lines, cfg.get("spoken") or cfg.get("prompt"))
            for pair in cfg.get("pairs", []):
                add(lines, pair.get("success"))
        elif template == "sortBins":
            add(lines, cfg.get("spoken") or cfg.get("prompt"))
            for item in cfg.get("items", []):
                add(lines, item.get("name"))
        elif template == "orderSequence":
            for rnd in cfg.get("rounds", []):
                add(lines, rnd.get("spoken") or rnd.get("prompt"))
                add(lines, rnd.get("success"))
                for name in rnd.get("names") or []:
                    add(lines, name)
    return lines


def app_lines(app):
    """Lines the app itself speaks, with every template expansion."""
    lines = set()
    for line in app["praise"] + app["retry"]:
        add(lines, line)
    add(lines, app["homeGreeting"])
    add(lines, app["levelLocked"])
    add(lines, app["sortComplete"])

    words = app["countWords"]
    for number in range(1, MAX_COUNT + 1):
        add(lines, words[number].capitalize() + "!")          # "Three!" while counting
        add(lines, app["countSuccess"].replace("{word}", words[number]))
    for template in app["celebration"]:
        for stars in STARS:
            add(lines, template.replace("{stars}", str(stars)))
    return lines


def discover_packs():
    paths = sorted(BUNDLED_DIR.glob("*.json")) + sorted(
        p for p in SERVER_DIR.glob("*.json") if p.name != "manifest.json")
    packs = []
    for path in paths:
        try:
            pack = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            print(f"WARN  skipping unreadable pack: {path}")
            continue
        if isinstance(pack.get("id"), str) and pack.get("levels"):
            packs.append(pack)
    return packs


# --- Synthesis --------------------------------------------------------------

def synthesize(text, voice, api_key):
    body = json.dumps({
        "model": MODEL,
        "voice": voice,
        "input": text,
        "instructions": INSTRUCTIONS,
        "response_format": "mp3",
    }).encode("utf-8")
    request = urllib.request.Request(API_URL, data=body, headers={
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    })
    last_error = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                return response.read()
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", "replace")[:300]
            last_error = f"HTTP {exc.code}: {detail}"
            if exc.code in (400, 401, 403):
                break                      # won't improve with retries
        except (urllib.error.URLError, TimeoutError) as exc:
            last_error = str(exc)
        time.sleep(2 ** attempt)
    raise RuntimeError(f"TTS failed for {text!r}: {last_error}")


# --- Bank maintenance -------------------------------------------------------

PENDING = "<pending>"


def load_index(unit_id):
    path = VOICE_DIR / f"{unit_id}.voice.json"
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def load_bank(voice, force):
    """text → clip filename across every existing index, so a line shared by
    several units (the counting words, say) is recorded exactly once. Only
    clips made with the current voice count; --force starts from scratch."""
    if force:
        return {}
    bank = {}
    for path in sorted(VOICE_DIR.glob("*.voice.json")):
        index = load_index(path.name.removesuffix(".voice.json")) or {}
        if index.get("voice") != voice:
            continue
        for entry in index.get("lines", []):
            if (CLIPS_DIR / entry["file"]).is_file():
                bank.setdefault(entry["text"], entry["file"])
    return bank


def process_unit(unit_id, lines, voice, args, api_key, stats, bank):
    """Bring one unit (a pack id or "app") up to date. Returns its index."""
    old = load_index(unit_id) or {}

    entries = []
    generated = []
    for text in sorted(lines):
        existing = bank.get(text)
        if existing:
            entries.append({"text": text, "file": existing})
            continue
        generated.append(text)
        stats["chars"] += len(text)
        if args.dry_run:
            entries.append({"text": text, "file": PENDING})
            bank[text] = PENDING
            continue
        audio = synthesize(text, voice, api_key)
        audio_hash = hashlib.sha256(audio).hexdigest()[:8]
        filename = f"{text_hash(text)}-{audio_hash}.mp3"
        CLIPS_DIR.mkdir(parents=True, exist_ok=True)
        (CLIPS_DIR / filename).write_bytes(audio)
        entries.append({"text": text, "file": filename})
        bank[text] = filename
        print(f"  + {filename}  {text}")

    changed = (
        [(e["text"], e["file"]) for e in entries]
        != [(e["text"], e["file"]) for e in old.get("lines", [])]
        or old.get("voice") != voice
    )
    index = {
        "schemaVersion": 1,
        "id": unit_id,
        "version": old.get("version", 0) + 1 if changed else old.get("version", 1),
        "voice": voice,
        "clipsPath": CLIPS_PATH_IN_REPO,
        "lines": entries,
    }
    if changed and not args.dry_run:
        VOICE_DIR.mkdir(parents=True, exist_ok=True)
        path = VOICE_DIR / f"{unit_id}.voice.json"
        path.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n",
                        encoding="utf-8")
    stats["units"].append((unit_id, len(entries), len(generated)))
    return index


def prune_orphans(indexes, dry_run):
    """Delete clips no index references (old audio after a re-record)."""
    referenced = {entry["file"] for index in indexes for entry in index["lines"]}
    removed = 0
    for clip in CLIPS_DIR.glob("*.mp3") if CLIPS_DIR.is_dir() else []:
        if clip.name not in referenced:
            removed += 1
            if not dry_run:
                clip.unlink()
    return removed


def update_manifest(indexes, dry_run):
    """Record each bank's version/path in packs/manifest.json so PackSync
    knows to fetch it. Bundled-only packs simply aren't listed — their clips
    still ship inside the app."""
    try:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        print("WARN  packs/manifest.json unreadable; voice versions not recorded")
        return
    by_id = {index["id"]: index for index in indexes}
    changed = False

    for entry in manifest.get("packs", []):
        index = by_id.get(entry.get("id"))
        if not index:
            continue
        voice_file = f"ZibbsPlayground/Voice/{index['id']}.voice.json"
        if entry.get("voiceVersion") != index["version"] or entry.get("voiceFile") != voice_file:
            entry["voiceVersion"] = index["version"]
            entry["voiceFile"] = voice_file
            changed = True

    app_index = by_id.get("app")
    if app_index:
        app_voice = {"version": app_index["version"],
                     "file": "ZibbsPlayground/Voice/app.voice.json"}
        if manifest.get("appVoice") != app_voice:
            manifest["appVoice"] = app_voice
            changed = True

    if changed and not dry_run:
        MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
                            encoding="utf-8")


# --- Entry point ------------------------------------------------------------

def audition(text, api_key):
    out = REPO_ROOT / "voice-audition"
    out.mkdir(exist_ok=True)
    for voice in AUDITION_VOICES:
        audio = synthesize(text, voice, api_key)
        path = out / f"{voice}.mp3"
        path.write_bytes(audio)
        print(f"  {path.relative_to(REPO_ROOT)}")
    print("\nListen with:  afplay voice-audition/<voice>.mp3")


def summarize(stats, pruned, voice, dry_run):
    minutes = stats["chars"] / 900          # ~15 spoken chars/second
    cost = minutes * 0.015                  # gpt-4o-mini-tts audio pricing
    verb = "would generate" if dry_run else "generated"
    lines = [f"### Voice bank {'(dry run)' if dry_run else 'updated'}", ""]
    lines += [f"| unit | lines | {verb} |", "|---|---|---|"]
    lines += [f"| {unit} | {total} | {new} |" for unit, total, new in stats["units"]]
    lines += ["", f"Voice `{voice}` · ~{stats['chars']} chars {verb} "
                  f"(~{minutes:.1f} min audio, ~${cost:.2f}) · {pruned} orphaned clips pruned"]
    text = "\n".join(lines)
    print("\n" + text)
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as handle:
            handle.write(text + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true",
                        help="process everything (the default; kept for readability in CI)")
    parser.add_argument("--dry-run", action="store_true",
                        help="report what would be generated without calling the API")
    parser.add_argument("--force", action="store_true",
                        help="regenerate every clip, even ones that exist")
    parser.add_argument("--voice", default=DEFAULT_VOICE,
                        help=f"OpenAI voice name (default: {DEFAULT_VOICE}); "
                             "changing it regenerates every affected bank")
    parser.add_argument("--audition", metavar="TEXT",
                        help="synthesize TEXT in several candidate voices to voice-audition/")
    args = parser.parse_args()

    api_key = os.environ.get("OPENAI_API_KEY", "")
    if not api_key and not args.dry_run:
        sys.exit("OPENAI_API_KEY is not set (use --dry-run to preview without it)")

    if args.audition:
        audition(args.audition, api_key)
        return

    try:
        app = json.loads(APP_LINES.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        sys.exit(f"cannot read {APP_LINES}: {exc}")

    stats = {"chars": 0, "units": []}
    bank = load_bank(args.voice, args.force)
    indexes = [process_unit("app", app_lines(app), args.voice, args, api_key, stats, bank)]
    for pack in discover_packs():
        indexes.append(process_unit(pack["id"], pack_lines(pack, app),
                                    args.voice, args, api_key, stats, bank))

    pruned = prune_orphans(indexes, args.dry_run)
    update_manifest(indexes, args.dry_run)
    summarize(stats, pruned, args.voice, args.dry_run)


if __name__ == "__main__":
    main()
