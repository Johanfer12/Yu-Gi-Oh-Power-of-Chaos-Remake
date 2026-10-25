"""Export only the sanitized launcher/engine and bundle its local data converter."""
from __future__ import annotations
import argparse
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from prepare_public import ROOT, allowed, prepare

GODOT_VERSION = "4.7.2"


def audit() -> None:
    raw = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    unexpected = [name for name in raw.decode().split("\0") if name and
                  name not in {".gitignore", "PUBLICATION_MANIFEST.json"} and not allowed(Path(name))]
    if unexpected:
        raise ValueError("El repositorio contiene archivos fuera de la política pública: " + ", ".join(unexpected[:20]))
    print("Índice Git: solo fuentes y recursos propios permitidos.")


def fetch(url: str, destination: Path) -> None:
    with urllib.request.urlopen(url, timeout=120) as response, destination.open("wb") as output:
        shutil.copyfileobj(response, output)


def install_engine(cache: Path, android: bool = False) -> Path:
    cache.mkdir(parents=True, exist_ok=True)
    editor = cache / f"Godot_v{GODOT_VERSION}-stable_win64_console.exe"
    editor_binary = cache / f"Godot_v{GODOT_VERSION}-stable_win64.exe"
    template = cache / "windows_release_x86_64.exe"
    # Android templates come from the same verified archive (build_android.py).
    templates = [template.name, "android_debug.apk", "android_release.apk"]
    if not editor.is_file() or not editor_binary.is_file() or not all((cache/name).is_file() for name in templates):
        base = f"https://github.com/godotengine/godot-builds/releases/download/{GODOT_VERSION}-stable/"
        with tempfile.TemporaryDirectory(prefix="godot-download-") as directory:
            work = Path(directory)
            sums = work / "SHA512-SUMS.txt"
            fetch(base + sums.name, sums)
            hashes = {}
            for line in sums.read_text().splitlines():
                parts = line.split()
                if len(parts) == 2:
                    hashes[parts[1].lstrip("*")] = parts[0]
            for name, members in (
                (f"Godot_v{GODOT_VERSION}-stable_win64.exe.zip", [editor.name, editor_binary.name]),
                (f"Godot_v{GODOT_VERSION}-stable_export_templates.tpz", templates),
            ):
                archive = work / name
                print("Descargando y verificando " + name, flush=True)
                fetch(base + name, archive)
                with archive.open("rb") as stream:
                    digest = hashlib.file_digest(stream, "sha512").hexdigest()
                if digest != hashes.get(name):
                    raise ValueError("SHA-512 de Godot no coincide: " + name)
                with zipfile.ZipFile(archive) as zipped:
                    for member in members:
                        found = next(n for n in zipped.namelist() if Path(n).name == member)
                        with zipped.open(found) as source, (cache/member).open("wb") as target:
                            shutil.copyfileobj(source, target)
    template_dir = Path(os.environ["APPDATA"]) / f"Godot/export_templates/{GODOT_VERSION}.stable"
    template_dir.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(template, template_dir/template.name)
    return editor


def command(args: list[str], log: Path, cwd: Path | None = None) -> None:
    result = subprocess.run(args, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log.write_bytes(result.stdout)
    text = result.stdout.decode("utf-8", "replace")
    if result.returncode != 0 or "SCRIPT ERROR:" in text or "Parse Error:" in text:
        raise RuntimeError(f"Falló {args[0]}: {log}\n" + text[-4000:])


def bundle_archiver(work: Path, bundled: Path, logs: Path) -> None:
    from pocx.import_games import find_sevenzip
    downloads = (
        ("7z2604-x64.exe", "d54bf805f9f3704d1e8db2fa3498ae7ef2df0312b40b558e7c71c734430a665d"),
        ("7z2604-src.7z", "6bcfd2679d178174df06d09d50147dd7b5980d7beac896136689dfc9d51e0fd9"),
    )
    for name, expected in downloads:
        path = work/name
        fetch("https://github.com/ip7z/7zip/releases/download/26.04/" + name, path)
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError("No coincide el SHA-256 de 7-Zip: " + name)
    tools = bundled/"tools"
    command([find_sevenzip(), "x", str(work/"7z2604-x64.exe"), f"-o{tools}",
             "7z.exe", "7z.dll", "License.txt", "-y"], logs/"7zip-extract.log")
    command([str(tools/"7z.exe"), "i"], logs/"7zip-test.log")
    licenses = bundled/"licenses"
    shutil.copyfile(tools/"License.txt", licenses/"7ZIP_LICENSE.txt")
    shutil.copyfile(work/"7z2604-src.7z", licenses/"7ZIP_SOURCE_26.04.7z")
    (licenses/"7ZIP_NOTICE.txt").write_text(
        "This application includes unmodified 7-Zip 26.04 command-line components.\n"
        "7-Zip is licensed under GNU LGPL, with additional restrictions/notices in 7ZIP_LICENSE.txt.\n"
        "Project and source: https://www.7-zip.org/\n"
        "Matching source is included as 7ZIP_SOURCE_26.04.7z.\n", encoding="utf-8")


def build(godot: Path, output: Path, with_android: bool = False, android: Path | None = None) -> Path:
    output = output.resolve()
    if output.exists():
        raise ValueError("El destino debe ser nuevo")
    version = subprocess.check_output([str(godot), "--version"], text=True).strip()
    if not version.startswith(GODOT_VERSION + ".stable"):
        raise ValueError(f"Se requiere Godot {GODOT_VERSION}; recibido {version}")
    output.mkdir(parents=True)
    logs = output / "logs"
    logs.mkdir()
    executable = output / "PowerOfChaos.exe"
    with tempfile.TemporaryDirectory(prefix="poc-launcher-build-") as directory:
        work = Path(directory)
        source = work / "source"
        receipt = prepare(source) # Never export the private working project's res://.
        project = source / "game"
        # Tagged builds identify themselves exactly, including alpha/beta releases.
        ref = os.environ.get("GITHUB_REF_NAME", "")
        import re
        configured = re.search(r'config/version="([^"]+)"', (project/"project.godot").read_text(encoding="utf-8"))
        release_version = ref if re.fullmatch(r"v\d+\.\d+\.\d+(?:-(?:alpha|beta|rc)\.\d+)?", ref) else "v" + configured.group(1)
        (project/"build_info.json").write_text(json.dumps({"version": release_version}), encoding="utf-8")
        receipt["version"] = release_version
        bundled = project/"bundled"
        bundled.mkdir()
        android_data = []
        if android:
            # APK and source snapshot built from this same commit by build_android.py.
            from pocx.android_toolchain import bundle_source, digest
            android_release = json.loads((android/"ANDROID_RELEASE.json").read_text(encoding="utf-8"))
            android_apk = android/"PowerOfChaos-Android.apk"
            if android_release.get("version") != release_version or digest(android_apk) != android_release.get("sha256"):
                raise ValueError("El APK Android no corresponde a esta versión: " + str(android_release.get("version")))
            android_source = work/"android-source.zip"
            android_release["source_manifest_sha256"] = bundle_source(android/"source", android_source)
            android_info = work/"android-release.json"
            android_info.write_text(json.dumps(android_release, indent=2), encoding="utf-8")
            # The APK is published beside the EXE; the launcher only needs its source to pack PCKs.
            for name in ("PowerOfChaos-Android.apk", "PowerOfChaos-Android.apk.sha256", "ANDROID_RELEASE.json"):
                shutil.copyfile(android/name, output/name)
            for path in (android_source, android_info):
                android_data += ["--add-data", str(path) + os.pathsep + "pocx"]
            receipt["android_source_manifest_sha256"] = android_release["source_manifest_sha256"]
            receipt["android_apk_sha256"] = android_release["sha256"]
        # Bundle the Android source snapshot and the small color-key configuration.
        command([sys.executable, "-m", "PyInstaller", "--onefile", "--noupx", "--name", "pocx-import",
                 "--distpath", str(bundled), "--workpath", str(work/"pyinstaller"), "--specpath", str(work),
                 "--paths", str(source/"tools"), "--add-data",
                 str(source/"tools/pocx/color_key_overrides.json") + os.pathsep + "pocx",
                 *android_data,
                 str(source/"tools/importer_entry.py")], logs/"converter.log", cwd=work)
        command([str(bundled/"pocx-import.exe"), "--help"], logs/"converter-help.log")
        licenses = bundled / "licenses"
        licenses.mkdir()
        for name in ("README.md", "THIRD_PARTY_NOTICES.md"):
            shutil.copyfile(source/name, licenses/name)
        fetch("https://raw.githubusercontent.com/godotengine/godot/" + GODOT_VERSION + "-stable/COPYRIGHT.txt", licenses/"GODOT_COPYRIGHT.txt")
        fetch("https://raw.githubusercontent.com/python/cpython/3.13/LICENSE", licenses/"PYTHON_LICENSE.txt")
        for package in ("numpy", "pillow", "pyinstaller", "soundfile", "cffi"):
            distribution = importlib.metadata.distribution(package)
            for relative in distribution.files or []:
                if "license" in str(relative).lower() or "copying" in str(relative).lower():
                    path = Path(distribution.locate_file(relative))
                    if path.is_file():
                        destination = licenses/package/str(relative).replace("..", "_")
                        destination.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copyfile(path, destination)
        import soundfile
        if soundfile.__libsndfile_version__ != "1.2.2":
            raise ValueError("Se requiere libsndfile 1.2.2 para las fuentes correspondientes incluidas")
        snd_source = licenses/"LIBSNDFILE_SOURCE_1.2.2.tar.xz"
        fetch("https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz", snd_source)
        if hashlib.sha256(snd_source.read_bytes()).hexdigest() != "3799ca9924d3125038880367bf1468e53a1b7e3686a934f098b7e1d286cdb80e":
            raise ValueError("No coincide el SHA-256 de las fuentes libsndfile")
        for codec, codec_version in (("vorbis", "v1.3.7"), ("ogg", "v1.3.5")):
            fetch(f"https://raw.githubusercontent.com/xiph/{codec}/{codec_version}/COPYING", licenses/(codec.upper()+"_COPYING.txt"))
        bundle_archiver(work, bundled, logs)
        files = {p.relative_to(bundled).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in sorted(bundled.rglob("*")) if p.is_file()}
        manifest_path = bundled/"manifest.json"
        manifest_path.write_text(json.dumps(files, indent=2), encoding="utf-8")
        command([str(godot), "--headless", "--editor", "--path", str(project), "--import", "--quit"], logs/"import.log")
        command([str(godot), "--headless", "--path", str(project), "--export-release", "Windows Launcher",
                 str(executable)], logs/"export.log")
        # QA cache lives in the temporary build directory, never the user's actual data.
        previous_cache = os.environ.get("POC_TOOL_CACHE")
        os.environ["POC_TOOL_CACHE"] = str(work/"tools-cache")
        try:
            command([str(executable), "--headless", "--quit-after", "20", "--",
                     "--storage=" + str(work/"isolated-store"),
                     "--data=" + str(work/"absent-data"), "--save=" + str(work/"isolated-save")], logs/"boot.log", cwd=output)
            if (work/"tools-cache").exists():
                raise ValueError("El arranque del menú no debe extraer las herramientas")
            # Exercise the actual packed implementation explicitly; conversion is now lazy.
            probe = work/"verify_tools.gd"
            probe.write_text('extends SceneTree\nfunc _init() -> void:\n\t_run.call_deferred()\nfunc _run() -> void:\n'
                             '\tvar translations = root.get_node("CardTranslations")\n'
                             '\tif translations.total != 771 or translations.busy:\n\t\tquit(1)\n\t\treturn\n'
                             '\tvar importer: String = load("res://core/bundled_tools.gd").prepare()\n'
                             '\tquit(int(importer == ""))\n', encoding="utf-8")
            command([str(godot), "--headless", "--main-pack", str(executable),
                     "--script", str(probe), "--quit-after", "30", "--", "--storage=" + str(work/"isolated-store"),
                     "--data=" + str(work/"absent-data"), "--save=" + str(work/"isolated-save")], logs/"prepare-tools.log", cwd=output)
        finally:
            if previous_cache is None:
                os.environ.pop("POC_TOOL_CACHE", None)
            else:
                os.environ["POC_TOOL_CACHE"] = previous_cache
        key = hashlib.sha256(manifest_path.read_bytes()).hexdigest()[:16]
        installed = work/"tools-cache"/key
        for name, digest in files.items():
            if not (installed/name).is_file() or hashlib.sha256((installed/name).read_bytes()).hexdigest() != digest:
                raise ValueError("No se extrajo correctamente desde el EXE: " + name)
        command([str(installed/"pocx-import.exe"), "--help"], logs/"embedded-converter.log")
        command([str(installed/"tools/7z.exe"), "i"], logs/"embedded-7zip.log")
        receipt.update({"godot": version, "python": sys.version, "commit": os.environ.get("GITHUB_SHA", "local"),
                        "dependencies": {p: importlib.metadata.version(p) for p in ("numpy", "pillow", "pyinstaller", "soundfile", "cffi")},
                        "original_game_data_included": False, "converter_help_passed": True, "empty_boot_passed": True,
                        "single_executable": True, "embedded_tools_verified": True, "bundled_7zip": "26.04"})
        receipt["menu_boot_without_tool_extraction"] = True
        receipt["android_tools_prepared_by_launcher"] = True
        if not receipt["godot"].startswith(GODOT_VERSION + ".stable"):
            raise ValueError("El manifiesto no identifica correctamente la versión del motor")
        (output/"BUILD_MANIFEST.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    if with_android:
        from configure_android_builder import configure
        configure(output)
        receipt["android_builder_configured"] = True
        receipt["android_builder_requires_local_toolchain"] = True
        (output/"BUILD_MANIFEST.json").write_text(json.dumps(receipt, indent=2), encoding="utf8")
    executable.with_suffix(".exe.sha256").write_text(hashlib.sha256(executable.read_bytes()).hexdigest() + "  " + executable.name + "\n")
    print(executable)
    return executable


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--with-android", action="store_true", help="conecta la copia Android y SDK/JDK locales")
    parser.add_argument("--audit", action="store_true")
    parser.add_argument("--engine-cache", type=Path)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--android", type=Path, help="salida de build_android.py de este mismo commit")
    args = parser.parse_args()
    if args.audit:
        audit()
    if args.out:
        engine = install_engine(args.engine_cache) if args.engine_cache else args.godot
        if not engine:
            parser.error("Usa --godot o --engine-cache")
        build(engine.resolve(), args.out, args.with_android, args.android.resolve() if args.android else None)
