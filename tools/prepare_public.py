"""Build a new source-only publication directory without copying Git history."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TOP = {"docs/ANDROID_UPDATES.md","RELEASE_NOTES.md", "README.md", "README.es.md", "Jugar demo.bat", "THIRD_PARTY_NOTICES.md", ".gitattributes", "docs/LAUNCHER_SETTINGS.md", "docs/REDDIT_POST.en.md", "docs/CARD_TRANSLATIONS.md", "game/translations/spanish-card-catalog.json"}
TOOL_TOP = {"tools/pyproject.toml", "tools/prepare_public.py", "tools/build_windows.py", "tools/importer_entry.py", "tools/trace_logo_contours.py",
            "tools/tests/test_public_import.py", "tools/tests/test_media_import.py",
            "tools/tests/test_compact_import.py", "tools/configure_android_builder.py", "tools/tests/test_android_builder.py", "tools/tests/test_android_toolchain.py", "tools/tests/test_updater.py", "tools/tests/test_card_translations.py", "tools/tests/test_reviewed_card_pack.py",
            "tools/prepare_android_public.py", "tools/public_android/README.md", "tools/public_android/README.es.md",
            ".github/workflows/build-windows.yml", "game/export_presets.cfg"}
OWN_ASSETS = {"game/assets/music/launcher_theme.mp3",
              "game/assets/backgrounds/yugi_duel.jpg",
              "game/assets/backgrounds/joey_duel.png",
              "game/assets/backgrounds/kaiba_duel.png"}
LAUNCHER_ART = {"game/assets/icons/launcher.svg", "game/assets/icons/launcher.ico"}
README_SCREENSHOTS = {"docs/images/launcher-library-en.png", "docs/images/launcher-import-en.png"}


def allowed(relative: Path) -> bool:
    path = relative.as_posix()
    if path in TOP or path in TOOL_TOP or path in OWN_ASSETS or path in LAUNCHER_ART or path in README_SCREENSHOTS:
        return True
    if path == "game/share_smoke.gd":
        return False
    if path.startswith("game/"):
        if any(part in {".godot", "assets", "tests", "artifacts", "temp", "scenarios"} for part in relative.parts):
            return False
        return relative.suffix in {".gd", ".tscn", ".godot", ".gdshader", ".gdshaderinc"}
    if path.startswith("tools/pocx/") and len(relative.parts) == 3:
        return relative.suffix == ".py" or relative.name == "color_key_overrides.json"
    return False


def prepare(output: Path) -> dict:
    output = output.resolve()
    if output == ROOT or output.is_relative_to(ROOT):
        raise ValueError("El destino debe estar fuera del repositorio privado")
    if output.exists():
        raise ValueError("El destino debe ser nuevo; no se sobrescriben archivos")
    selected = sorted(p for p in ROOT.rglob("*") if p.is_file() and allowed(p.relative_to(ROOT)))
    # Reject links before copying to avoid following private content outside this tree.
    for source in selected:
        if source.is_symlink() or not source.resolve().is_relative_to(ROOT):
            raise ValueError(f"Enlace no permitido: {source.relative_to(ROOT)}")
        if source.relative_to(ROOT).as_posix() not in OWN_ASSETS | LAUNCHER_ART | README_SCREENSHOTS:
            source.read_text(encoding="utf-8-sig") # source text or explicitly approved own assets
    output.mkdir(parents=True)
    manifest = {}
    for source in selected:
        relative = source.relative_to(ROOT)
        dest = output / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, dest)
        if relative.as_posix() not in OWN_ASSETS | LAUNCHER_ART | README_SCREENSHOTS:
            dest.write_bytes(dest.read_bytes().replace(b"\r\n", b"\n"))
        manifest[relative.as_posix()] = hashlib.sha256(dest.read_bytes()).hexdigest()
    ignore = ("# Solo fuentes; los recursos y configuraciones privadas nunca se publican\n"
              "data/\nextracted/\nsamples/\nsaves/\nimports/\nartifacts/\nre/\n"
              ".godot/\n__pycache__/\n*.pyc\n*.uid\n*.iso\n*.exe\n*.dat\n*.bin\n"
              "*.pck\n*.apk\n*.keystore\n*.jks\n.env*\n.venv/\n*.egg-info/\n"
              "build/\ndist/\ncontent.cfg\nPoC Data/\nandroid-builder.json\n*.import\n")
    (output / ".gitignore").write_text(ignore, encoding="utf-8", newline="\n")
    manifest[".gitignore"] = hashlib.sha256((output / ".gitignore").read_bytes()).hexdigest()
    (output / ".gitattributes").write_bytes(b"* text=auto eol=lf\n")
    manifest[".gitattributes"] = hashlib.sha256((output / ".gitattributes").read_bytes()).hexdigest()
    report = {"format": 1, "files": manifest, "git_history_included": False,
              "policy": "source and explicit remake asset allowlist; approved launcher screenshots for documentation; no standalone original game assets or native fixtures",
              "documentation_screenshots_requested_by_user": sorted(README_SCREENSHOTS),
              "remake_assets_confirmed_by_user": sorted(OWN_ASSETS),
              "original_launcher_art_created_for_project": sorted(LAUNCHER_ART),
              "derived_logo_outline_geometry_requested_by_user": "game/scenes/launcher/logo_contours.gd",
              "legal_clearance": False}
    (output / "PUBLICATION_MANIFEST.json").write_text(json.dumps(report, indent=2), encoding="utf-8", newline="\n")
    return report


def package(output: Path, report: dict) -> Path:
    """Package exactly the reviewed manifest, excluding editor caches and new files."""
    output = output.resolve()
    archive = output.with_name(output.name + ".zip")
    if archive.exists():
        raise ValueError("El ZIP ya existe; no se sobrescribe")
    for name, expected in report["files"].items():
        if hashlib.sha256((output / name).read_bytes()).hexdigest() != expected:
            raise ValueError(f"Archivo modificado después de preparar la copia: {name}")
    with zipfile.ZipFile(archive, "x", compression=zipfile.ZIP_DEFLATED) as zipped:
        for name in sorted(report["files"]):
            zipped.write(output / name, name)
        zipped.write(output / "PUBLICATION_MANIFEST.json", "PUBLICATION_MANIFEST.json")
    archive.with_name(archive.name + ".sha256").write_text(
        hashlib.sha256(archive.read_bytes()).hexdigest() + "  " + archive.name + "\n", encoding="utf-8")
    return archive


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--zip", action="store_true", help="crea además un ZIP solo con archivos del manifiesto")
    args = parser.parse_args()
    report = prepare(args.out)
    print(f"Preparados {len(report['files'])} archivos de fuentes en {args.out.resolve()}")
    if args.zip:
        print(package(args.out, report))
