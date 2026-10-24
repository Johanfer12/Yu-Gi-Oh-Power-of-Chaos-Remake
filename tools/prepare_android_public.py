"""Exporta fuentes Android a una rama pública independiente, sin historia privada.

PC y Android comparten main: por defecto la fuente es este mismo repositorio.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from prepare_public import ROOT, OWN_ASSETS, LAUNCHER_ART, allowed

ANDROID_LAUNCHER_ART = {
    "game/assets/icons/launcher-adaptive-foreground.svg",
    "game/assets/icons/launcher-adaptive-background.svg",
    "game/assets/icons/launcher-adaptive-monochrome.svg",
}


def prepare_android(source: Path, output: Path) -> dict:
    source, output = source.resolve(), output.resolve()
    if output.exists() or output.is_relative_to(source) or output.is_relative_to(ROOT):
        raise ValueError("Usa un destino nuevo fuera de las copias privadas")
    selected = []
    for path in sorted(source.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(source)
        name = relative.as_posix()
        if (name.startswith("game/") and allowed(relative)) or name in ANDROID_LAUNCHER_ART or name in {
                "tools/android/build_apk.py", "tools/android/pack_data.gd",
                "game/tests/android_bundle_test.gd", "game/tests/android_engine_bundle_test.gd"}:
            if path.is_symlink() or not path.resolve().is_relative_to(source):
                raise ValueError("Enlace no publicable: " + name)
            if name in OWN_ASSETS or name in LAUNCHER_ART:
                if path.read_bytes() != (ROOT / relative).read_bytes():
                    raise ValueError("Recurso distinto al aprobado: " + name)
            else:
                path.read_text(encoding="utf-8-sig")
            selected.append((path, relative))
    output.mkdir(parents=True)
    for path, relative in selected:
        dest = output / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, dest)
    # Icono propio aprobado en lugar del icono antiguo de la copia privada.
    for name in LAUNCHER_ART:
        dest = output / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, dest)
    project = output / "game/project.godot"
    import importlib.util
    spec = importlib.util.spec_from_file_location("build_apk", ROOT / "tools/android/build_apk.py")
    build_apk = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(build_apk)
    # El APK se exporta con los ajustes Android del proyecto; la instantánea los refleja.
    project.write_text(build_apk.android_project(project.read_text(encoding="utf8").replace(
        'config/icon="res://assets/icon.svg"', 'config/icon="res://assets/icons/launcher.svg"')), encoding="utf8")
    for name in ("README.md", "README.es.md"):
        shutil.copyfile(ROOT / "tools/public_android" / name, output / name)
    shutil.copyfile(ROOT / "THIRD_PARTY_NOTICES.md", output / "THIRD_PARTY_NOTICES.md")
    (output / ".gitignore").write_text(
        "data/\nartifacts/\nsaves/\n.godot/\n__pycache__/\n*.pyc\n*.uid\n*.import\n"
        "*.apk\n*.pck\n*.iso\n*.exe\n*.dat\n*.bin\n*.keystore\n*.jks\n.env*\n", encoding="utf8")
    (output / ".gitattributes").write_bytes(b"* text=auto eol=lf\n")
    for path in output.rglob("*"):
        if path.is_file() and path.relative_to(output).as_posix() not in OWN_ASSETS | LAUNCHER_ART:
            path.write_bytes(path.read_bytes().replace(b"\r\n", b"\n"))
    manifest = {path.relative_to(output).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in sorted(output.rglob("*")) if path.is_file()}
    report = {"format": 1, "files": manifest, "git_history_included": False,
              "policy": "Android source allowlist; approved remake assets and launcher icon only",
              "original_game_data_included": False, "private_signing_key_included": False,
              "legal_clearance": False}
    (output / "PUBLICATION_MANIFEST.json").write_text(json.dumps(report, indent=2), encoding="utf8", newline="\n")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--android-root", type=Path, default=ROOT)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    print(len(prepare_android(args.android_root, args.out)["files"]), "archivos publicables")
