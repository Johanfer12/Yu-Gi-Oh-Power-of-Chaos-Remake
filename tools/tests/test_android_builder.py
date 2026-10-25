"""Contratos del puente Android: aislado, publicacion tras validar y fallos seguros."""
import json
import hashlib
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from pocx.android_builder import configuration, create_apk, preflight


class AndroidBuilderTests(unittest.TestCase):
    def test_missing_kit_fails_before_import(self):
        with tempfile.TemporaryDirectory() as temporary, patch("pocx.import_games.import_games") as importer, \
             patch("pocx.android_builder.configuration", side_effect=ValueError("Falta el kit")):
            with self.assertRaisesRegex(ValueError, "Falta el kit"):
                create_apk({"yugi": Path("source.iso")}, Path(temporary))
            importer.assert_not_called()

    def test_relative_configuration(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            (root / "android-builder.json").write_text(json.dumps({"root": "kit/source"}))
            self.assertEqual(configuration(root)["root"], root / "kit/source")

    def test_content_configuration_keeps_version_as_text(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            (root / "android-builder.json").write_text(json.dumps({"root": "source", "godot": "godot.exe",
                                                                  "version": "v0.1.0-alpha.19"}))
            self.assertEqual(configuration(root)["version"], "v0.1.0-alpha.19")
            self.assertEqual(configuration(root)["root"], root / "source")

    def test_content_missing_packer_fails_before_extracting_private_games(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "tools/android").mkdir(parents=True)
            (root / "tools/android/build_apk.py").touch()
            (root / "game").mkdir()
            (root / "game/project.godot").touch()
            config = dict(root=root, godot=root / "absent-godot.exe")
            with patch("pocx.android_builder.configuration", return_value=config), \
                 patch("pocx.import_games.import_games") as importer:
                with self.assertRaisesRegex(ValueError, "Falta una herramienta"):
                    create_apk({"yugi": root / "private.iso"}, root)
                importer.assert_not_called()
            self.assertFalse((root / "PoC Data/android/builds").exists())

    def _content_build(self, failure=None):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            original = root / "pc-resources"
            original.mkdir()
            original_text = '{"games":{"yugi":{}}}'
            (original / "inventory.json").write_text(original_text)
            config = dict(root=root / "source", godot=root / "godot.exe", version="v0.1.0-alpha.19")
            (config["root"] / "tools/android").mkdir(parents=True)
            (config["root"] / "tools/android/build_apk.py").touch()
            (config["root"] / "game").mkdir()
            (config["root"] / "game/project.godot").touch()
            config["godot"].touch()
            preflight(config)  # No SDK, Java, signing key, license or APK exists.
            outputs = root / "PoC Data/android/pck"
            outputs.mkdir(parents=True)
            old_pack = outputs / "existing-resources.pck"
            old_pack.write_bytes(b"preserve earlier private pack")
            key = root / "PoC Data/android/signing/debug.keystore"
            key.parent.mkdir()
            key.write_bytes(b"preserve personal signing key")
            content = b"synthetic validated private PCK"

            def build(*_args, **_kwargs):
                import sys
                args = sys.argv
                self.assertIn("--content-only", args)
                self.assertNotIn("--debug-keystore", args)
                self.assertNotIn("--sdk", args)
                self.assertNotIn("--output", args)
                target = Path(args[args.index("--content-output") + 1])
                target.write_bytes(content)
                work = Path(args[args.index("--work") + 1])
                work.mkdir()
                self.assertEqual(list(outputs.iterdir()), [old_pack])
                if failure == "build":
                    raise RuntimeError("packing failed")
                report = {"content_pack": str(target), "sha256": hashlib.sha256(content).hexdigest()}
                if failure == "hash":
                    report["sha256"] = "0" * 64
                (work / "content-build-manifest.json").write_text(json.dumps(report))

            before_env = dict(os.environ)
            real_rename = Path.rename
            def rename(source, target):
                if failure == "publish" and source.suffix == ".pck":
                    raise OSError("PCK destination unavailable")
                return real_rename(source, target)

            with patch("pocx.android_builder.configuration", return_value=config), \
                 patch("pocx.compact.optimize_tree"), \
                 patch("pocx.android_builder.runpy.run_path", side_effect=build), \
                 patch.object(Path, "rename", rename):
                if failure:
                    with self.assertRaises((RuntimeError, ValueError, OSError)):
                        create_apk({}, root, base=original)
                    self.assertEqual(list(outputs.iterdir()), [old_pack])
                else:
                    target = create_apk({}, root, base=original)
                    self.assertEqual(target.suffix, ".pck")
                    self.assertEqual(target.read_bytes(), content)
                    self.assertEqual(sorted(p.suffix for p in outputs.iterdir()), [".json", ".pck", ".pck"])
                    report = json.loads(target.with_suffix(".json").read_text())
                    self.assertEqual(report["content_pack_sha256"], hashlib.sha256(content).hexdigest())
                    self.assertEqual(report["public_apk_version"], "v0.1.0-alpha.19")
                    self.assertNotIn("apk", report)
                    self.assertFalse((root / "PoC Data/android/apks").exists())
            self.assertEqual(dict(os.environ), before_env)
            self.assertEqual((original / "inventory.json").read_text(), original_text)
            self.assertEqual(key.read_bytes(), b"preserve personal signing key")
            self.assertEqual(old_pack.read_bytes(), b"preserve earlier private pack")
            self.assertFalse(list(root.rglob("resources-*")))

    def test_content_pack_only_and_personal_key_untouched(self):
        self._content_build()

    def test_content_pack_failure_publishes_nothing(self):
        self._content_build("build")

    def test_content_pack_bad_hash_publishes_nothing(self):
        self._content_build("hash")

    def test_content_pack_publication_failure_rolls_back(self):
        self._content_build("publish")

    def _build(self, fail, first=False):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            original = root / "pc-resources"
            original.mkdir()
            (original / "inventory.json").write_text('{"games":{"yugi":{}}}')
            before = (original / "inventory.json").read_bytes()
            env_before = os.environ.get("JAVA_HOME")
            config = {key: root / key for key in ("root", "godot", "sdk", "java", "keystore", "previous")}

            if first:
                config.pop("previous")

            def build(*_args, **_kwargs):
                import sys
                args = sys.argv
                self.assertEqual("--first-build" in args, first)
                self.assertEqual("--previous-apk" in args, not first)
                apk = Path(args[args.index("--output") + 1])
                apk.write_bytes(b"validated-apk")
                self.assertFalse(list(root.glob("*.apk")))
                work = Path(args[args.index("--work") + 1])
                (work / "v18-validation/bundle-save").mkdir(parents=True)
                if fail:
                    raise RuntimeError("firma rechazada")
                work = Path(args[args.index("--work") + 1])
                (work / "project").mkdir(parents=True)
                (work / "v18-build-manifest.json").write_text('{"signature_verified":true}')

            with patch("pocx.android_builder.configuration", return_value=config), \
                 patch("pocx.android_builder.preflight"), \
                 patch("pocx.compact.optimize_tree"), \
                 patch("pocx.android_builder.runpy.run_path", side_effect=build):
                if fail:
                    with self.assertRaisesRegex(RuntimeError, "firma rechazada"):
                        create_apk({}, root, base=original)
                    self.assertFalse(list(root.glob("*.apk")))
                else:
                    output = create_apk({}, root, base=original)
                    self.assertEqual(output.parent, root / "PoC Data/android/apks")
                    self.assertEqual(output.read_bytes(), b"validated-apk")
                    self.assertTrue(output.with_suffix(".json").is_file())
            self.assertEqual((original / "inventory.json").read_bytes(), before)
            self.assertEqual(os.environ.get("JAVA_HOME"), env_before)
            self.assertFalse(list(root.rglob("project")))
            self.assertFalse(list(root.rglob("resources-*")))
            self.assertFalse(list(root.rglob("bundle-save")))

    def test_success_preserves_pc_and_cleans_generated_resources(self):
        self._build(False)

    def test_first_install_uses_own_key_without_previous_apk(self):
        self._build(False, first=True)

    def test_failure_does_not_publish_apk_or_change_pc(self):
        self._build(True)


if __name__ == "__main__":
    unittest.main()
