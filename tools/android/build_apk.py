"""Build the tablet APK using the existing Spanish/WebP/OGG data copy.

PC and Android share main: run from PortTesting with python tools/android/build_apk.py.
The staged project gets the Android-only project settings; the PC project is unchanged.
The original PC data is never converted or changed by this command.
"""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
# Certificate of every public APK since the first release; installed apps only accept updates
# signed with it. CI signs with this key (repository secret) and --release enforces it.
PUBLIC_SIGNING_CERTIFICATE = "3ecec96acce26569c77445296b10dd182413957d794f9c84239748ff650015f6"


def release_version(root=ROOT):
    """PC release tag that this APK belongs to (application/config/version)."""
    text = (root / "game/project.godot").read_text(encoding="utf8")
    return "v" + re.search(r'config/version="([^"]+)"', text).group(1)


def android_version_code(root=ROOT):
    """versionCode of the Android Tablet export preset."""
    text = (root / "game/export_presets.cfg").read_text(encoding="utf8").split('name="Android Tablet"', 1)[1]
    return int(re.search(r"^version/code=(\d+)$", text, re.M).group(1))


TAG = release_version()
CODE = android_version_code()
# Optimized data, previous APKs and build evidence are unversioned; until main has its own
# store they stay in the former Android checkout next to it.
OUT = ROOT / "artifacts/android"
if not (OUT / "spanish-data").is_dir() and (ROOT.parent / "PortTesting-Android/artifacts/android/spanish-data").is_dir():
    OUT = ROOT.parent / "PortTesting-Android/artifacts/android"
STAGE = OUT / f"v{CODE}-project"
DATA = OUT / "spanish-data"


def run(command, log, cwd=None, bootstrap=False):
    result = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        text = result.stdout.decode("utf8")
    except UnicodeDecodeError:
        text = result.stdout.decode("cp1252")
    (OUT / log).write_text(text, encoding="utf8")
    if result.returncode or (not bootstrap and ("SCRIPT ERROR" in text or "ERROR:" in text)):
        raise RuntimeError(f"{log}: {text[-5000:]}")
    print("PASS", log, flush=True)
    return text


def android_project(text):
    """Project settings that only the Android export needs (ETC2/ASTC import, landscape)."""
    additions = {"rendering": "textures/vram_compression/import_etc2_astc=true",
                 "display": "window/handheld/orientation=0"}
    lines = text.splitlines()
    for section, setting in additions.items():
        if setting in lines:
            continue
        if f"[{section}]" in lines:
            lines.insert(lines.index(f"[{section}]") + 2, setting)
        else:
            lines += ["", f"[{section}]", "", setting]
    return "\n".join(lines) + "\n"


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def signer_certificate(text):
    """Certificate SHA-256 of the only signer in `apksigner verify --print-certs` output.

    build-tools 35 prints "Signer #1 certificate ...", 36 prints "V3.0 Signer: certificate ...".
    """
    if re.search(r"^Number of signers: (?!1$)", text, re.M):
        raise RuntimeError("The APK must have exactly one signer")
    digests = set(re.findall(r"^(?:Signer #1|V[\d.]+ Signer:) certificate SHA-256 digest: ([0-9a-f]{64})$", text, re.M))
    if len(digests) != 1:
        raise RuntimeError("Could not read a single signing certificate from apksigner")
    return digests.pop()


def verify_signing_key(tools, previous_apk, keystore):
    previous = run([str(tools / "apksigner.bat"), "verify", "--print-certs",
                    str(previous_apk.resolve())], f"v{CODE}-previous-signature.log", cwd=OUT)
    expected = signer_certificate(previous)
    if signing_key_digest(keystore) != expected:
        raise RuntimeError("Keystore differs from the installed APK certificate; use --debug-keystore")
    return expected


def signing_key_digest(keystore):
    exported = subprocess.run(["keytool", "-exportcert", "-keystore", str(keystore),
                               "-storepass", "android", "-alias", "androiddebugkey"],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    return hashlib.sha256(exported.stdout).hexdigest()


def main():
    global STAGE
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=shutil.which("godot_console") or "godot_console")
    parser.add_argument("--sdk", type=Path, default=Path(os.environ.get("ANDROID_HOME") or Path(os.environ["LOCALAPPDATA"]) / "Android/Sdk"))
    # Codex de Microsoft Store conserva el certificado establecido en Roaming virtualizado.
    established_key = Path(os.environ["LOCALAPPDATA"]) / "Packages/OpenAI.Codex_2p2nqsd0c76g0/LocalCache/Roaming/Godot/keystores/debug.keystore"
    parser.add_argument("--debug-keystore", type=Path, default=established_key if established_key.is_file()
                        else Path(os.environ["APPDATA"]) / "Godot/keystores/debug.keystore")
    parser.add_argument("--previous-apk", type=Path, default=OUT / f"PowerOfChaos-tablet-v{CODE - 1}.apk")
    parser.add_argument("--data", type=Path, default=DATA)
    parser.add_argument("--work", type=Path, help="directorio nuevo para proyecto y evidencias")
    parser.add_argument("--output", type=Path, default=OUT / f"PowerOfChaos-tablet-v{CODE}.apk")
    parser.add_argument("--first-build", action="store_true", help="primera instalación con tu propia firma, sin APK previo")
    parser.add_argument("--release", action="store_true", help="APK público: exige el certificado publicado, sin APK previo")
    parser.add_argument("--engine-only", action="store_true", help="public APK without original game content")
    parser.add_argument("--content-only", action="store_true", help="export private content PCK, without building/signing an APK")
    parser.add_argument("--content-output", type=Path)
    args = parser.parse_args()
    # Los valores históricos siguen siendo los predeterminados del flujo Android.
    data = args.data.resolve()
    work = args.work.resolve() if args.work else OUT
    STAGE = work / "project" if args.work else STAGE
    apk = args.output.resolve()
    apk.parent.mkdir(parents=True, exist_ok=True)
    if args.work:
        if work.exists():
            raise RuntimeError(f"El directorio de compilación debe ser nuevo: {work}")
        work.mkdir(parents=True)
    # run() conserva todos los registros dentro de esta compilación.
    globals()["OUT"] = work
    if apk.resolve() == args.previous_apk.resolve():
        raise RuntimeError("Output APK must differ from the previous APK")
    if apk.exists():
        raise RuntimeError(f"Inspect the existing APK before replacing {apk}")
    if args.content_only:
        if not args.content_output or args.content_output.exists():
            raise RuntimeError("Use a new --content-output path")
        if not (data / "inventory.json").is_file():
            raise RuntimeError("Missing game inventory")
        globals()["OUT"] = work
        pack_project = work / "pack-project"
        pack_project.mkdir(parents=True)
        (pack_project / "project.godot").write_text('config_version=5\n[autoload]\nPaths="*res://paths.gd"\n', encoding='utf8')
        (pack_project / "paths.gd").write_text('extends Node\nvar data_dir := cmdline_value("data")\nstatic func cmdline_value(key: String) -> String:\n\tfor arg in OS.get_cmdline_user_args():\n\t\tif arg.begins_with("--"+key+"="): return arg.substr(key.length()+3)\n\treturn ""\n', encoding='utf8')
        args.content_output.parent.mkdir(parents=True, exist_ok=True)
        run([args.godot, "--headless", "--path", str(pack_project), "--script", str(ROOT / "tools/android/pack_data.gd"), "--", "--data="+str(data), "--pack-output="+str(args.content_output)], f"v{CODE}-content-pack.log")
        report = dict(content_pack=str(args.content_output), sha256=digest(args.content_output), original_game_data_included=True)
        (work / f'v{CODE}-build-manifest.json').write_text(json.dumps(report, indent=2), encoding='utf8')
        return
    assert args.debug_keystore.is_file(), "Missing established Android debug keystore"
    if not args.first_build and not args.release:
        assert args.previous_apk.is_file(), "Missing previous APK for certificate comparison"
    if not args.engine_only:
        assert (data / "inventory.json").is_file(), "Missing optimized data"
    if STAGE.exists():
        raise RuntimeError(f"Inspect the previous build before replacing {STAGE}")
    OUT.mkdir(parents=True, exist_ok=True)
    tools = sorted((p for p in (args.sdk / "build-tools").iterdir() if re.fullmatch(r"\d+(\.\d+)*", p.name)),
                   key=lambda p: tuple(map(int, p.name.split('.'))))[-1]
    if args.release:
        signing_certificate = signing_key_digest(args.debug_keystore)
        if signing_certificate != PUBLIC_SIGNING_CERTIFICATE:
            raise RuntimeError("Keystore differs from the published APK certificate; installed apps could not update")
    else:
        signing_certificate = (signing_key_digest(args.debug_keystore) if args.first_build else
                               verify_signing_key(tools, args.previous_apk, args.debug_keystore))
    shutil.copytree(ROOT / "game", STAGE, ignore=shutil.ignore_patterns(
        ".godot", "tests", "temp", "artifacts", "unused", "*.uid", "share_smoke.gd"))
    validation = OUT / f"v{CODE}-validation"
    validation.mkdir(exist_ok=True)
    # El empaquetado solo necesita Paths, sin arrancar los autoloads del juego.
    # Permite compilar recursos nuevos incluso sin una importación previa local.
    project = STAGE / "project.godot"
    project.write_text(android_project((ROOT / "game/project.godot").read_text(encoding="utf8")), encoding="utf8", newline="\n")
    original_project = project.read_bytes()
    if not args.engine_only:
        project.write_text('config_version=5\n[autoload]\nPaths="*res://autoload/paths.gd"\n', encoding='utf8')
    (STAGE / "build_info.json").write_text(json.dumps({"version": TAG, "android_version_code": CODE, "android_signing_sha256": signing_certificate}), encoding="utf8")
    if not args.engine_only:
        try:
            run([args.godot, "--headless", "--path", str(STAGE), "--script",
                 str(ROOT / "tools/android/pack_data.gd"), "--", f"--data={data.as_posix()}",
                 f"--pack-output={(STAGE / 'bundled_data.pck').as_posix()}",
                 f"--save={(validation / 'pack-save').as_posix()}"], f"v{CODE}-pack.log")
        finally:
            project.write_bytes(original_project)
    run([args.godot, "--headless", "--path", str(STAGE), "--editor", "--import"], f"v{CODE}-bootstrap.log", bootstrap=True)
    run([args.godot, "--headless", "--path", str(STAGE), "--editor", "--import"], f"v{CODE}-import.log")
    if not args.engine_only:
        (STAGE / "bundled_data.sha256").write_text(digest(STAGE / "bundled_data.pck"), encoding="ascii")
    run([args.godot, "--headless", "--path", str(STAGE), "--export-debug", "Android Tablet", str(apk)], f"v{CODE}-export.log")
    run([args.godot, "--headless", "--path", str(STAGE), "--script",
         str(ROOT / ("game/tests/android_engine_bundle_test.gd" if args.engine_only else "game/tests/android_bundle_test.gd")), "--",
         f"--save={(validation / 'bundle-save').as_posix()}",
         f"--storage={(validation / 'bundle-save').as_posix()}",
         f"--report={(validation / 'bundle.json').as_posix()}", "--platform=android"], f"v{CODE}-bundle.log")
    # Conservar el certificado existente aunque cambie el Godot instalado.
    run([str(tools / "apksigner.bat"), "sign", "--ks", str(args.debug_keystore.resolve()),
         "--ks-key-alias", "androiddebugkey", "--ks-pass", "pass:android",
         "--key-pass", "pass:android", str(apk)], f"v{CODE}-sign.log", cwd=OUT)
    signed = run([str(tools / "apksigner.bat"), "verify", "--verbose", "--print-certs", str(apk)], f"v{CODE}-signature.log", cwd=OUT)
    previous = "" if args.first_build or args.release else run([str(tools / "apksigner.bat"), "verify", "--print-certs", str(args.previous_apk.resolve())], f"v{CODE}-previous-signature.log", cwd=OUT)
    assert signer_certificate(signed) == signing_certificate, "Unexpected signing certificate"
    if previous:
        assert signer_certificate(signed) == signer_certificate(previous), "Certificate changed; update would require uninstalling"
    run([str(tools / "zipalign.exe"), "-c", "-P", "16", "-v", "4", str(apk)], f"v{CODE}-alignment.log")
    run([str(tools / "aapt.exe"), "dump", "badging", str(apk)], f"v{CODE}-package.log", cwd=OUT)
    with zipfile.ZipFile(apk) as archive:
        assert archive.testzip() is None
        if args.engine_only:
            assert not any("bundled_data.pck" in n or n.startswith("assets/data/") for n in archive.namelist())
        else:
            with archive.open("assets/bundled_data.pck") as stream:
                assert hashlib.file_digest(stream, "sha256").hexdigest() == digest(STAGE / "bundled_data.pck")
    source_hashes = {}
    for path in sorted(STAGE.rglob('*')):
        if path.is_file() and '.godot' not in path.relative_to(STAGE).parts and path.suffix in ['.gd', '.cfg', '.godot', '.svg']:
            source = ROOT / 'game' / path.relative_to(STAGE)
            if source.name == "project.godot" and source.parent == ROOT / "game":
                expected = hashlib.sha256(android_project(source.read_text(encoding="utf8")).encode("utf8")).hexdigest()
            else:
                expected = digest(source)
            assert digest(path) == expected, f"Stale source: {path}"
            source_hashes[source.relative_to(ROOT).as_posix()] = digest(path)
    data_files = [] if args.engine_only else [p for p in data.rglob('*') if p.is_file()]
    report = dict(version=CODE, engine_only=args.engine_only, original_game_data_included=not args.engine_only, apk=apk.as_posix(), bytes=apk.stat().st_size,
                  sha256=digest(apk), optimized_data_files=len(data_files),
                  optimized_data_bytes=sum(p.stat().st_size for p in data_files),
                  data_format='Selected local games; lossless WebP, OGG and short WAV',
                  source_sha256=source_hashes, signature_verified=True, same_signing_certificate_as_previous=True if previous or args.release else None, alignment_16kb_verified=True,
                  signing_certificate_sha256=signing_certificate, device_tested=False)
    (OUT / f'v{CODE}-build-manifest.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    apk.with_suffix('.apk.sha256').write_text(digest(apk)+"  "+apk.name+"\n", encoding='ascii')
    if args.engine_only:
        metadata = dict(package='org.porttesting.powerofchaos', apk='PowerOfChaos-Android.apk', version=TAG, version_code=CODE, sha256=digest(apk), signing_certificate_sha256=signing_certificate, original_game_data_included=False, content_format=1)
        (OUT / 'ANDROID_RELEASE.json').write_text(json.dumps(metadata, indent=2), encoding='utf8')
    for temporary in [validation / 'pack-save', validation / 'bundle-save']:
        assert temporary.resolve().parent == validation.resolve()
        if temporary.exists():
            shutil.rmtree(temporary)
    print(json.dumps({key: value for key, value in report.items() if key != 'source_sha256'}, indent=2), flush=True)


if __name__ == '__main__':
    main()
