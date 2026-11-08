"""Preserve language identity when importing user-supplied Voice.dat packs."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
from .archive import Archive
from .messages import error as user_error

LANGUAGES = {"spanish": "s", "english": "e", "french": "f", "german": "g", "italian": "i", "japanese": "j"}


def export_voice(source: Path, output: Path, game: str, manifest: dict) -> int:
    pack = manifest.setdefault("games", {}).setdefault(game, {"languages": [], "sources": []})
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if digest in pack["sources"]:
        return 0
    raw_files = pack.setdefault("raw_files", {})
    languages = set()
    count = 0
    with Archive(source) as archive:
        for entry in archive.entries:
            if not entry.name.lower().endswith(".wav"):
                continue
            parts = entry.name.lower().split("/")
            if len(parts) != 4 or parts[0] != game or parts[1] not in LANGUAGES or parts[2] not in ("internal", "stream"):
                raise user_error("voice_path_bad", game=game, name=entry.name)
            language = LANGUAGES[parts[1]]
            languages.add(language)
            destination = output / game / "voice" / language / parts[2] / parts[3]
            raw = archive.read(entry)
            relative = destination.relative_to(output).as_posix()
            raw_hash = hashlib.sha256(raw).hexdigest()
            if destination.with_suffix(".ogg").exists():
                if raw_files.get(relative) != raw_hash:
                    raise user_error("voice_duplicate", game=game, language=language)
                count += 1
                continue
            if destination.exists() and destination.read_bytes() != raw:
                raise user_error("voice_duplicate", game=game, language=language)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(raw)
            raw_files[relative] = raw_hash
            count += 1
    if not languages:
        raise user_error("voice_empty", game=game)
    pack.setdefault("default", sorted(languages)[0])
    pack["languages"] = sorted(set(pack["languages"]) | languages)
    if digest not in pack["sources"]:
        pack["sources"].append(digest)
    return count


def add_voice(source: Path, output: Path, game: str) -> int:
    path = output / "voice_manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    count = export_voice(source, output, game, manifest)
    path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return count
