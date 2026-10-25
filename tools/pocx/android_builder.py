"""Puente del launcher al empaquetador Android, sin modificar datos PC.

Por defecto solo crea el paquete privado de recursos (.pck): el APK público lo compila
GitHub Actions y se descarga aparte. Una configuración con clave propia
(android-builder.json con keystore) sigue compilando un APK personal completo.
"""
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
        return {key: str(value) if key in ("mode", "version") else (launcher / value).resolve()
                for key, value in values.items()}
    if getattr(sys, "frozen", False):
        from .android_toolchain import prepare
        return prepare(launcher)
    # Desarrollo: el empaquetador está en este repositorio y Godot en Herramientas.
    repo = Path(__file__).resolve().parents[2]
    for parent in (launcher, *launcher.parents):
        if (repo / "tools/android/build_apk.py").is_file() and (parent / "Herramientas").is_dir():
            return dict(root=repo, godot=parent / "Herramientas/Godot/godot_console.exe")
    from .android_toolchain import prepare
    return prepare(launcher)


def content_only(config: dict) -> bool:
    return "keystore" not in config


def preflight(config: dict) -> None:
    if content_only(config):
        for path in (config["root"] / "tools/android/build_apk.py", config["root"] / "game/project.godot",
                     config["godot"]):
            if not path.is_file():
                raise ValueError(f"Falta una herramienta Android: {path}")
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
    public_mode = content_only(config)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    evidence = launcher / "PoC Data/android/builds" / stamp
    evidence.mkdir(parents=True, exist_ok=False)
    if public_mode:
        target = launcher / "PoC Data/android/pck" / f"PowerOfChaos-resources-{stamp}.pck"
    else:
        target = launcher / "PoC Data/android/apks" / f"PowerOfChaos-Android-{stamp}.apk"
    target.parent.mkdir(parents=True, exist_ok=True)
    # Publicar solo el archivo completamente verificado. Un fallo no deja nada a medias.
    staged = evidence / target.name
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
                raise ValueError("Selecciona un ISO o prepara un juego antes de crear los recursos")
            sys.argv = [str(config["root"] / "tools/android/build_apk.py"),
                        "--data", str(data), "--work", str(evidence / "build"),
                        "--godot", str(config["godot"])]
            if public_mode:
                sys.argv += ["--content-only", "--content-output", str(staged)]
            else:
                sys.argv += ["--output", str(staged), "--sdk", str(config["sdk"]),
                             "--debug-keystore", str(config["keystore"])]
                if "previous" in config:
                    sys.argv += ["--previous-apk", str(config["previous"])]
                else:
                    sys.argv += ["--first-build"]
            print("Preparando tus recursos privados para Android…" if public_mode else
                  "Compilando con los controles de la copia Android…", flush=True)
            runpy.run_path(sys.argv[0], run_name="__main__")
        manifests = list((evidence / "build").glob("*-build-manifest.json"))
        if len(manifests) != 1:
            raise ValueError("La compilación no generó un único informe de validación")
        manifest = manifests[0]
        report = json.loads(manifest.read_text(encoding="utf8"))
        if public_mode:
            from .android_toolchain import digest
            if (not staged.is_file() or Path(report.get("content_pack", "")).resolve() != staged.resolve()
                    or digest(staged) != report.get("sha256")):
                raise ValueError("El paquete privado de recursos no supera la validación SHA-256")
            report.update(content_pack=str(target), content_pack_sha256=digest(staged))
            if config.get("version"):
                report["public_apk_version"] = config["version"]
        else:
            report["apk"] = str(target)
        report["android_source"] = str(config["root"])
        manifest.write_text(json.dumps(report, indent=2), encoding="utf8")
        staged_manifest = evidence / target.with_suffix(".json").name
        shutil.copyfile(manifest, staged_manifest)
        outputs = [(staged_manifest, target.with_suffix(".json")), (staged, target)]
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
        if public_mode:
            print(f"Recursos privados: {target}\nInstala el APK público y selecciona este archivo .pck una sola vez al abrirlo. "
                  "Las actualizaciones conservarán tus recursos y partidas.", flush=True)
        else:
            print(f"APK creado: {target}", flush=True)
        return target
    finally:
        sys.argv = old_argv
        for key, value in old_env.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        staged.unlink(missing_ok=True)
        # Solo la copia generada por esta llamada. Los registros y manifiestos quedan.
        project = evidence / "build/project"
        if project.is_dir() and project.resolve().parent == (evidence / "build").resolve():
            shutil.rmtree(project)
        for validation in (evidence / "build").glob("*-validation"):
            for name in ("pack-save", "bundle-save"):
                save = validation / name
                if save.is_dir() and save.resolve().parent == validation.resolve():
                    shutil.rmtree(save)
