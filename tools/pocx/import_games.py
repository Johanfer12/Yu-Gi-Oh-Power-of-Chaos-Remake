"""Import local user-owned installations/media. Never run game executables."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import uuid

from .__main__ import (GAMES, STARTER_TABLES, _read_va, extract,
                       export_duel_image)
from .archive import Archive
from .executable import validate
from .voices import add_voice
from .compact import optimize_tree
from . import messages
from .messages import UserError, error as user_error, t


class ImportFailure(ValueError):
    """Machine-readable context without guessing the failed game from progress logs."""
    def __init__(self, stage, reason, game=None, source=None, diagnostics=""):
        self.stage, self.reason = stage, str(reason)
        self.game, self.source = game, str(source) if source is not None else None
        self.diagnostics = diagnostics
        super().__init__(self.reason)

    def __str__(self):
        return (f"{self.game}: " if self.game else "") + self.reason

    def payload(self):
        return dict(stage=self.stage, game=self.game, source=self.source,
                    reason=self.reason, diagnostics=self.diagnostics)


@contextmanager
def import_context(stage, game=None, source=None):
    try:
        yield
    except ImportFailure as error:
        if error.game is None:
            error.game = game
        if error.source is None and source is not None:
            error.source = str(source)
        raise
    except UserError as error:
        raise ImportFailure(stage, str(error), game, source) from error
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        # Internal/technical text: translated summary for the stage, original as details.
        raise ImportFailure(stage, t("stage." + stage), game, source, str(error)) from error


class MissingInstallation(UserError):
    """No folder with the expected files: other media layouts may still contain one."""


TITLES = {"yugi": "Yugi the Destiny", "kaiba": "Kaiba the Revenge", "joey": "Joey the Passion"}


def _foreign_data_message(game: str, names: dict[str, Path], archive: Archive) -> str:
    """Say which game the Data.dat beside the executable really belongs to."""
    folder, title = names["data.dat"].parent, TITLES[game]
    owners = [other for other, letter in GAMES.items()
              if other != game and f"{letter}/file/deck_{letter}.txt" in archive.by_name]
    if owners:
        return t("foreign_owner", game=game, folder=folder, title=title,
                 found=", ".join(TITLES[other] for other in owners))
    return t("foreign_unknown", game=game, folder=folder, title=title,
             missing=f"{GAMES[game]}/file/deck_{GAMES[game]}.txt")


def locate(root: Path, game: str) -> dict[str, Path]:
    """Find one coherent installation, accepting mixed-case filenames."""
    exe_name = STARTER_TABLES[game][0].lower()
    matches = []
    for directory, _, files in os.walk(root):
        names = {name.lower(): Path(directory) / name for name in files}
        required = {exe_name, "data.dat", "voice.dat", "region.dat"}
        if required <= names.keys():
            matches.append(names)
    if len(matches) != 1:
        raise MissingInstallation(t("install_count", game=game, exe=exe_name, count=len(matches)))
    names = matches[0]
    for archive_name in ("data.dat", "voice.dat"):
        try:
            archive = Archive(names[archive_name])
        except ValueError as error:
            raise ImportFailure("installation", t("archive_damaged", game=game, name=names[archive_name].name),
                                game, diagnostics=str(error)) from error
        with archive:
            if not archive.entries:
                raise user_error("archive_empty", game=game, name=names[archive_name].name)
            if archive_name == "data.dat" and f"{GAMES[game]}/file/deck_{GAMES[game]}.txt" not in archive.by_name:
                raise UserError(_foreign_data_message(game, names, archive))
    try:
        validate(names[exe_name].read_bytes(), game)
    except ValueError as error:
        raise ImportFailure("installation", t("exe_incompatible", game=game, exe=names[exe_name].name,
                                              title=TITLES[game]), game, diagnostics=str(error)) from error
    return names


def find_sevenzip() -> str:
    bundled = os.environ.get("POC_7ZIP", "")
    if bundled and Path(bundled).is_file():
        return bundled
    for command in ("7z", "7zz"):
        if found := shutil.which(command):
            return found
    for variable in ("ProgramFiles", "ProgramFiles(x86)"):
        if os.environ.get(variable):
            path = Path(os.environ[variable]) / "7-Zip/7z.exe"
            if path.is_file():
                return str(path)
    raise user_error("no_7zip")


def unpack(source: Path, destination: Path) -> Path:
    if source.is_dir():
        return source
    if source.suffix.lower() != ".iso" or not source.is_file():
        raise user_error("select_media")
    sevenzip = find_sevenzip()
    result = subprocess.run([sevenzip, "x", str(source), f"-o{destination}", "-y"],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode != 0:
        details = result.stdout.decode("utf-8", errors="replace").strip()
        reason = (t("iso_truncated") if "Unexpected end of archive" in details else
                  t("iso_failed", code=result.returncode))
        raise ImportFailure("iso", reason, source=source, diagnostics=details)
    return destination


def installation(root: Path, game: str, workspace: Path) -> dict[str, Path]:
    try:
        return locate(root, game)
    except ValueError as error:
        # A specific problem inside the installer media says more than "found: 0" at its root.
        specific = None if isinstance(error, MissingInstallation) else error
        cabinets = [p for p in root.rglob("*") if p.is_file() and p.name.lower() == "data1.cab"]
        for index, cabinet in enumerate(cabinets):
            sevenzip = find_sevenzip()
            destination = workspace / f"cab-{index}"
            # Standard Microsoft CAB embedded in the original MSI discs. No MSI execution.
            result = subprocess.run([sevenzip, "x", str(cabinet), f"-o{destination}", "-y"],
                                    stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
            if result.returncode == 0:
                try:
                    return locate(destination, game)
                except ValueError as inner:
                    specific = specific or (None if isinstance(inner, MissingInstallation) else inner)
        # Only extract recognized Inno installers; never launch setup.exe.
        candidates = [p for p in root.rglob("*") if p.suffix.lower() == ".exe" and p.stem.lower().startswith(("setup", "install"))]
        if not candidates:
            raise specific or error
        inno = shutil.which("innoextract")
        if not inno:
            raise (specific or user_error("installer_needs_inno")) from error
        for index, candidate in enumerate(candidates):
            dest = workspace / f"installer-{index}"
            result = subprocess.run([inno, "--extract", "--output-dir", str(dest), str(candidate)],
                                    stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
            if result.returncode == 0:
                try:
                    return locate(dest, game)
                except ValueError as inner:
                    specific = specific or (None if isinstance(inner, MissingInstallation) else inner)
        raise (specific or user_error("no_compatible_install", game=game)) from error


def export_audio(src: Path, out: Path, games=None) -> None:
    import struct
    tables = {"yugi": (0x5AD3D0, 0x5ADA40), "kaiba": (0x5B03D8, 0x5B0A48),
              "joey": (0x5EFD48, 0x5F0A30)}
    result = {}
    for game in (games if games is not None else GAMES):
        addresses = tables[game]
        exe = (src / game / "app" / STARTER_TABLES[game][0]).read_bytes()
        for kind, address in zip(("internal", "stream"), addresses):
            for index in range(256):
                ptr, loop, channel, volume = struct.unpack("<4I", _read_va(exe, address + index * 16, 16))
                if ptr == 0:
                    break
                name = bytearray()
                for offset in range(256):
                    byte = _read_va(exe, ptr + offset, 1)
                    if byte == b"\0":
                        break
                    name.extend(byte)
                wav = name.decode("ascii").lower()
                if not wav.endswith(".wav") or volume > 127 or channel != (1 if kind == "internal" else 2):
                    raise ValueError(f"{game}: tabla de audio incompatible")
                result[f"{game}/voice/{kind}/{wav}"] = {"volume": volume, "loop": bool(loop)}
            else:
                raise ValueError(f"{game}: tabla de audio sin terminador")
    (out / "common/audio_native.json").write_text(json.dumps(result, indent=2), encoding="utf-8")


def _import_voice(path, output, game):
    with import_context("voices", game, path):
        add_voice(path, output, game)


def import_games(sources: dict[str, Path], output: Path, extra_voices: list[tuple[str, Path]] | None = None, base: Path | None = None,
                 compact: bool = False, replace: bool = False) -> None:
    output = output.resolve()
    if output.exists() and not replace:
        raise user_error("dest_exists_kept")
    if output.is_symlink() or (output.exists() and not (output / "inventory.json").is_file()):
        raise user_error("dest_not_library")
    if (not sources and not (base is not None and (extra_voices or compact))) or not set(sources) <= GAMES.keys():
        raise user_error("select_one_game")
    previous = None
    if base is not None:
        base = base.resolve()
        if output.is_relative_to(base) and not (replace and output == base):
            raise user_error("dest_inside_base")
        previous = json.loads((base / "inventory.json").read_text(encoding="utf-8"))
        if set(sources) & previous["games"].keys():
            raise user_error("game_already")
    output.parent.mkdir(parents=True, exist_ok=True)
    # Same volume: rename publishes only a fully converted installation.
    with tempfile.TemporaryDirectory(prefix=".poc-import-", dir=output.parent) as temporary:
        work = Path(temporary)
        if not sources:
            converted = work / "converted"
            shutil.copytree(base, converted)
            for game, voice_path in extra_voices or []:
                if game not in previous["games"]:
                    raise user_error("prepare_before_voices", game=game)
                _import_voice(voice_path, converted, game)
            _publish(converted, output, compact, replace)
            return
        for game in sources:
            print(t("validating", game=game), flush=True)
            with import_context("iso", game, sources[game]):
                root = unpack(sources[game].resolve(), work / f"media-{game}")
            with import_context("installation", game, sources[game]):
                names = installation(root, game, work / game)
            with import_context("write", game, sources[game]):
                app = work / "sources" / game / "app"
                app.mkdir(parents=True)
                for name in ("Data.dat", "Voice.dat", "Region.dat", STARTER_TABLES[game][0]):
                    shutil.copyfile(names[name.lower()], app / name)
        converted = work / "converted"
        with import_context("conversion"):
            extract(work / "sources", converted)
        for game, voice_path in extra_voices or []:
            if game in sources:
                _import_voice(voice_path, converted, game)
            elif previous is None or game not in previous["games"]:
                raise user_error("unknown_voice_game", game=game)
        with import_context("audio"):
            export_audio(work / "sources", converted, sources)
        if base is None:
            _publish(converted, output, compact, replace)
        else:
            merged = work / "merged"
            shutil.copytree(base, merged)
            current = json.loads((converted / "inventory.json").read_text(encoding="utf-8"))
            old_master = previous.get("master", next(g for g in reversed(GAMES) if g in previous["games"]))
            new_master = current["master"]
            promote = list(GAMES).index(new_master) > list(GAMES).index(old_master)
            # The most recent installed game owns the shared card tables and artwork.
            for path in converted.rglob("*"):
                if not path.is_file():
                    continue
                relative = path.relative_to(converted)
                if relative.parts[0] == "common" and relative.parts[1] != "duel" and not promote:
                    continue
                destination = merged / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, destination)
            for name, field in (("inventory.json", "games"), ("voice_manifest.json", "games")):
                old = json.loads((base / name).read_text(encoding="utf-8"))
                new = json.loads((converted / name).read_text(encoding="utf-8"))
                old[field].update(new[field])
                if name == "inventory.json":
                    if promote:
                        for key in ("card_pools", "cards_total", "cards_with_art"):
                            old[key] = new[key]
                    old["master"] = new_master if promote else old_master
                    old.setdefault("duel_images", {}).update(new.get("duel_images", {}))
                (merged / name).write_text(json.dumps(old, indent=2), encoding="utf-8")
            keys = json.loads((base / "color_keys.json").read_text(encoding="utf-8"))
            incoming_keys = json.loads((converted / "color_keys.json").read_text(encoding="utf-8"))
            keys.update({k: v for k, v in incoming_keys.items() if promote or not k.startswith("common/")})
            (merged / "color_keys.json").write_text(json.dumps(keys, indent=1), encoding="utf-8")
            audio = json.loads((base / "common/audio_native.json").read_text(encoding="utf-8"))
            audio.update(json.loads((converted / "common/audio_native.json").read_text(encoding="utf-8")))
            (merged / "common/audio_native.json").write_text(json.dumps(audio, indent=2), encoding="utf-8")
            for game, voice_path in extra_voices or []:
                if game not in sources:
                    _import_voice(voice_path, merged, game)
            _publish(merged, output, compact, replace)
    print(t("import_done"), flush=True)


def _publish(staging: Path, output: Path, compact: bool, replace: bool) -> None:
    if compact:
        with import_context("compact"):
            optimize_tree(staging)
    with import_context("write", source=output):
        _publish_ready(staging, output, replace)


def _publish_ready(staging: Path, output: Path, replace: bool) -> None:
    backup = output.with_name(".poc-previous-" + uuid.uuid4().hex)
    if output.exists():
        if not replace:
            raise user_error("dest_exists")
        output.rename(backup)
    try:
        staging.rename(output)
    except OSError:
        if backup.exists():
            backup.rename(output)
        raise
    if backup.exists():
        shutil.rmtree(backup)


def _main() -> None:
    # CLI output uses UTF-8; the launcher reads an explicit UTF-8 log on Windows.
    for stream in (sys.stdout, sys.stderr):
        if stream is not None and hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="backslashreplace")
    parser = argparse.ArgumentParser(description=__doc__)
    for game in GAMES:
        parser.add_argument(f"--{game}", type=Path)
    parser.add_argument("--base", type=Path, help="datos existentes que se conservarán")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--replace", action="store_true", help="actualiza atómicamente una biblioteca existente")
    parser.add_argument("--create-apk", action="store_true", help="compila con la copia Android; --out es la carpeta del launcher")
    parser.add_argument("--no-compact", action="store_true", help="conserva PNG/WAV para herramientas de desarrollo")
    parser.add_argument("--voice", action="append", default=[], metavar="GAME=VOICE.DAT",
                        help="añade otro doblaje; repetible, sin reemplazar idiomas distintos")
    parser.add_argument("--lang", default="s", help="idioma del launcher para los mensajes (s = español; otro = inglés)")
    args = parser.parse_args()
    messages.set_language(args.lang)
    try:
        extra = []
        for spec in args.voice:
            if "=" not in spec:
                raise user_error("voice_usage")
            game, path = spec.split("=", 1)
            extra.append((game, Path(path)))
        sources = {game: getattr(args, game) for game in GAMES if getattr(args, game) is not None}
        if args.create_apk:
            from .android_builder import create_apk
            create_apk(sources, args.out, extra, args.base)
        else:
            import_games(sources, args.out, extra, args.base,
                         compact=not args.no_compact, replace=args.replace)
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError, SystemExit) as error:
        failure = (error if isinstance(error, ImportFailure) else
                   ImportFailure("setup", str(error)) if isinstance(error, UserError) else
                   ImportFailure("setup", t("stage.setup"), diagnostics=str(error)))
        print("POC_IMPORT_ERROR " + json.dumps(failure.payload()), file=sys.stderr, flush=True)
        parser.exit(1, t("cli_failed", error=failure) + "\n")


def main() -> None:
    # Windows OS.execute decodes pipes using its active code page. Preserve Unicode
    # through an explicit file, rather than guessing or repairing damaged text.
    if "--output-log" not in sys.argv:
        _main()
        return
    from contextlib import redirect_stdout, redirect_stderr
    args = sys.argv[:]
    index = sys.argv.index("--output-log")
    if index + 1 >= len(sys.argv):
        raise ValueError("--output-log requires a path")
    target = Path(sys.argv[index + 1])
    target.parent.mkdir(parents=True, exist_ok=True)
    del sys.argv[index:index + 2]
    try:
        with target.open("w", encoding="utf-8", newline="\n") as log:
            with redirect_stdout(log), redirect_stderr(log):
                _main()
    finally:
        sys.argv = args


if __name__ == "__main__":
    main()
