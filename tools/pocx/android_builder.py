"""Puente del launcher al compilador de la copia Android, sin modificar datos PC."""
from __future__ import annotations

import json
import os
from pathlib import Path
import runpy
import shutil
import sys
import tempfile
from datetime import datetime


def configuration(launcher: Path) -> dict:
    config = launcher / "android-builder.json"
    if config.is_file():
        values = json.loads(config.read_text(encoding="utf8"))
        return {key: str(value) if key in ("mode", "public_apk_sha256") else (launcher / value).resolve()
                for key, value in values.items()}
    if getattr(sys, "frozen", False):
        from .android_toolchain import prepare
        return prepare(launcher)
    # Desarrollo: PC y Android comparten main; el compilador está en este repositorio. Los APK
    # anteriores siguen en el almacén artifacts/android de la copia Android (no versionado).
    repo = Path(__file__).resolve().parents[2]
    for parent in (launcher, *launcher.parents):
        root = repo if (repo / "tools/android/build_apk.py").is_file() else parent / "PortTesting-Android"
        if (root / "tools/android/build_apk.py").is_file() and (parent / "Herramientas").is_dir():
            return dict(root=root, godot=parent / "Herramientas/Godot/godot_console.exe",
                        sdk=parent / "Herramientas/AndroidSdk", java=parent / "Herramientas/JDK21",
                        keystore=parent / "FirmaAndroid/debug.keystore",
                        previous=parent / "PortTesting-Android/artifacts/android/PowerOfChaos-tablet-v17.apk")
    from .android_toolchain import prepare
    return prepare(launcher)


def preflight(config: dict) -> None:
    if "public_apk" in config:
        from .android_toolchain import digest
        for path in (config["root"] / "tools/android/build_apk.py", config["root"] / "game/project.godot",
                     config["godot"], config["public_apk"]):
            if not path.is_file():
                raise ValueError(f"Falta una herramienta o APK público Android: {path}")
        expected = config.get("public_apk_sha256", "")
        if not isinstance(expected, str) or len(expected) != 64 or digest(config["public_apk"]) != expected:
            raise ValueError("El APK público Android no supera la verificación SHA-256")
        return
    for key, relative in (("root", "tools/android/build_apk.py"), ("root", "game/project.godot"),
                          ("java", "bin/keytool.exe"), ("sdk", "build-tools")):
        if not (config[key] / relative).exists():
            raise ValueError(f"Falta una herramienta Android: {config[key] / relative}")
    for key in ("godot", "keystore"):
        if not config[key].is_file():
            raise ValueError(f"Falta {key}: {config[key]}")
    if "previous" in config and not config["previous"].is_file():
        raise ValueError(f"Falta el APK de referencia: {config['previous']}")


def create_apk(sources: dict, launcher: Path, extra_voices=None, base: Path | None = None) -> Path:
    from .import_games import import_games
    from .compact import optimize_tree

    launcher = launcher.resolve()
    config = configuration(launcher)
    preflight(config)  # Fallar antes de extraer ISO grandes.
    public_mode = "public_apk" in config
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    evidence = launcher / "PoC Data/android/builds" / stamp
    evidence.mkdir(parents=True, exist_ok=False)
    target = launcher / "PoC Data/android/apks" / f"PowerOfChaos-Android-{stamp}.apk"
    target.parent.mkdir(parents=True, exist_ok=True)
    # Publicar solo el APK completamente verificado. Un fallo no deja un APK instalable.
    staged_apk = evidence / target.name
    content_target = target.with_name(target.stem + "-resources.pck")
    staged_content = evidence / content_target.name
    published: list[Path] = []
    old_env = {key: os.environ.get(key) for key in ("JAVA_HOME", "ANDROID_HOME", "ANDROID_SDK_ROOT", "PATH")}
    old_argv = sys.argv[:]
    try:
        if not public_mode:
            os.environ.update(JAVA_HOME=str(config["java"]), ANDROID_HOME=str(config["sdk"]),
                              ANDROID_SDK_ROOT=str(config["sdk"]))
            os.environ["PATH"] = str(config["java"] / "bin") + os.pathsep + os.environ.get("PATH", "")
        with tempfile.TemporaryDirectory(prefix="resources-", dir=evidence) as temporary:
            data = Path(temporary) / "data"
            if sources or extra_voices:
                import_games(sources, data, extra_voices, base=base, compact=True)
            elif base is not None:
                shutil.copytree(base, data)
                optimize_tree(data)
            else:
                raise ValueError("Selecciona un ISO o prepara un juego antes de crear el APK")
            sys.argv = [str(config["root"] / "tools/android/build_apk.py"),
                        "--data", str(data), "--work", str(evidence / "build"),
                        "--godot", str(config["godot"])]
            if public_mode:
                sys.argv += ["--content-only", "--content-output", str(staged_content)]
            else:
                sys.argv += ["--output", str(staged_apk), "--sdk", str(config["sdk"]),
                             "--debug-keystore", str(config["keystore"])]
                if "previous" in config:
                    sys.argv += ["--previous-apk", str(config["previous"])]
                else:
                    sys.argv += ["--first-build"]
            print("Preparando tus recursos para el APK público Android…" if public_mode else
                  "Compilando con los controles de la copia Android…", flush=True)
            runpy.run_path(sys.argv[0], run_name="__main__")
        manifests = list((evidence / "build").glob("*-build-manifest.json"))
        if len(manifests) != 1:
            raise ValueError("La compilación no generó un único informe de validación")
        manifest = manifests[0]
        report = json.loads(manifest.read_text(encoding="utf8"))
        if public_mode:
            from .android_toolchain import digest
            if (not staged_content.is_file() or Path(report.get("content_pack", "")).resolve() != staged_content.resolve()
                    or digest(staged_content) != report.get("sha256")):
                raise ValueError("El paquete privado de recursos no supera la validación SHA-256")
            shutil.copyfile(config["public_apk"], staged_apk)
            if digest(staged_apk) != config["public_apk_sha256"]:
                raise ValueError("El APK público cambió durante la preparación")
            report.update(content_pack=str(content_target), content_pack_sha256=digest(staged_content),
                          apk_sha256=config["public_apk_sha256"], apk_original_game_data_included=False,
                          public_apk_unchanged=True)
        report["apk"] = str(target)
        report["android_source"] = str(config["root"])
        manifest.write_text(json.dumps(report, indent=2), encoding="utf8")
        staged_manifest = evidence / target.with_suffix(".json").name
        shutil.copyfile(manifest, staged_manifest)
        outputs = [(staged_content, content_target)] if public_mode else []
        outputs += [(staged_manifest, target.with_suffix(".json")), (staged_apk, target)]
        try:
            for source, destination in outputs:
                if destination.exists():
                    raise ValueError(f"Ya existe una salida Android: {destination}")
                source.rename(destination)
                published.append(destination)
        except BaseException:
            for destination in reversed(published):
                destination.unlink(missing_ok=True)
            raise
        print(f"APK creado: {target}", flush=True)
        if public_mode:
            print(f"Recursos privados: {content_target}\nInstala el APK y selecciona ese archivo .pck una sola vez al abrirlo. "
                  "Las actualizaciones públicas conservarán tus recursos y partidas.", flush=True)
        return target
    finally:
        sys.argv = old_argv
        for key, value in old_env.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        if staged_apk.exists():
            staged_apk.unlink()
        staged_content.unlink(missing_ok=True)
        # Solo la copia generada por esta llamada. Los registros y manifiestos quedan.
        project = evidence / "build/project"
        if project.is_dir() and project.resolve().parent == (evidence / "build").resolve():
            shutil.rmtree(project)
        for validation in (evidence / "build").glob("*-validation"):
            for name in ("pack-save", "bundle-save"):
                save = validation / name
                if save.is_dir() and save.resolve().parent == validation.resolve():
                    shutil.rmtree(save)
