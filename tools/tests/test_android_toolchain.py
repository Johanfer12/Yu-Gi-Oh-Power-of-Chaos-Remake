"""Safety and offline reuse contracts for the launcher-managed Android kit."""
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from pocx import android_toolchain as kit


def release_info(directory: Path, source_hash: str, apk_hash: str) -> Path:
    """android-release.json as build_windows.py embeds it next to the toolchain."""
    info = directory / "android-release.json"
    info.write_text(json.dumps({"version": "v0.1.0-alpha.19", "sha256": apk_hash,
                                "source_manifest_sha256": source_hash, "original_game_data_included": False}))
    return info


class AndroidToolchainTests(unittest.TestCase):
    def test_license_required_before_network_or_install(self):
        with tempfile.TemporaryDirectory() as temporary, patch.object(kit.urllib.request, "urlopen") as network:
            with self.assertRaisesRegex(ValueError, "licencia"):
                kit.prepare(Path(temporary), private_build=True)
            network.assert_not_called()

    def test_corrupted_download_never_activated_and_partial_removed(self):
        with tempfile.TemporaryDirectory() as temporary:
            response = io.BytesIO(b"bad download")
            response.headers = {}
            target = Path(temporary) / "tool.zip"
            with patch.object(kit.urllib.request, "urlopen", return_value=response):
                with self.assertRaisesRegex(ValueError, "SHA-256"):
                    kit.fetch("https://example.invalid/tools.zip", target, "0" * 64)
            self.assertFalse(target.exists())
            self.assertFalse(target.with_suffix(".part").exists())

    def test_archive_cannot_escape_kit(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for unsafe in ("../outside", "/absolute", "C:/drive", "file:stream", "..\\outside"):
                archive = root / "bad.zip"
                with zipfile.ZipFile(archive, "w") as zipped:
                    zipped.writestr(unsafe, "bad")
                with self.assertRaises(ValueError):
                    kit.extract(archive, root / "kit")
            self.assertFalse((root / "outside").exists())

    def test_bundled_source_keeps_audited_manifest_for_runtime_verification(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            payload = b"synthetic source file"
            snapshot = root / "snapshot"
            (snapshot / "game").mkdir(parents=True)
            (snapshot / "game/project.godot").write_bytes(payload)
            manifest = json.dumps({"files": {"game/project.godot": hashlib.sha256(payload).hexdigest()}}).encode()
            (snapshot / "PUBLICATION_MANIFEST.json").write_bytes(manifest)
            output = root / "android-source.zip"
            self.assertEqual(kit.bundle_source(snapshot, output), hashlib.sha256(manifest).hexdigest())
            kit.extract(output, root / "unpacked")
            kit._verify_source(root / "unpacked", hashlib.sha256(manifest).hexdigest())
            (snapshot / "game/project.godot").write_bytes(b"changed after the manifest")
            with self.assertRaisesRegex(ValueError, "Fuente Android no válida"):
                kit.bundle_source(snapshot, root / "other.zip")

    def test_installed_tools_and_signing_key_reused_without_network(self):
        with tempfile.TemporaryDirectory() as temporary:
            launcher = Path(temporary)
            storage = launcher / "PoC Data/android"
            root = storage / "tools/kit-1"
            root.mkdir(parents=True)
            (storage / "sdk-license.accepted").write_text("accepted")
            locations = {"templates": f"godot/editor_data/export_templates/{kit.VERSION}.stable",
                         "build-tools": "sdk/build-tools/35.0.1", "platform-tools": "sdk/platform-tools"}
            for name, (_, expected) in kit.PACKAGES.items():
                component = root / locations.get(name, name)
                component.mkdir(parents=True, exist_ok=True)
                (component / ".verified").write_text(expected)
                required = {"godot": [f"Godot_v{kit.VERSION}-stable_win64_console.exe", f"Godot_v{kit.VERSION}-stable_win64.exe"],
                            "templates": ["android_debug.apk", "android_release.apk"], "java": ["bin/keytool.exe"],
                            "build-tools": ["apksigner.bat", "zipalign.exe", "aapt.exe"], "platform-tools": ["adb.exe"]}
                for relative in required[name]:
                    path = component / relative
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.touch()
            source = root / ("source-" + "a" * 12)
            source.mkdir()
            key = storage / "signing/debug.keystore"
            key.parent.mkdir()
            key.write_bytes(b"existing unique signing key")
            info = release_info(launcher, "a" * 64, "b" * 64)
            with patch.object(kit, "RELEASE_INFO", info), \
                 patch.object(kit.urllib.request, "urlopen") as network, patch.object(kit.subprocess, "run") as execute:
                execute.return_value.stdout = b"existing certificate"
                config = kit.prepare(launcher, private_build=True)
            network.assert_not_called()
            self.assertEqual(execute.call_count, 1)  # Verify identity; do not regenerate the key.
            self.assertIn("-exportcert", execute.call_args.args[0])
            self.assertEqual(config["keystore"].read_bytes(), b"existing unique signing key")
            self.assertTrue(all(p.is_relative_to(storage) for p in config.values()))
            self.assertEqual(config["root"], source)
            self.assertFalse((storage / "progress.json").exists())
            # Losing or replacing the key must never silently generate a new identity.
            key.unlink()
            with patch.object(kit, "RELEASE_INFO", info), \
                 patch.object(kit.urllib.request, "urlopen") as network, patch.object(kit.subprocess, "run") as execute:
                with self.assertRaisesRegex(ValueError, "firma Android anterior"):
                    kit.prepare(launcher, private_build=True)
                network.assert_not_called()
                execute.assert_not_called()
            key.write_bytes(b"replacement key")
            with patch.object(kit, "RELEASE_INFO", info), patch.object(kit.subprocess, "run") as execute:
                execute.return_value.stdout = b"a different certificate"
                with self.assertRaisesRegex(ValueError, "firma Android cambió"):
                    kit.prepare(launcher, private_build=True)

    def _public_fixture(self, launcher):
        storage = launcher / "PoC Data/android"
        root = storage / "tools/kit-1"
        godot = root / "godot" / f"Godot_v{kit.VERSION}-stable_win64_console.exe"
        godot.parent.mkdir(parents=True)
        godot.touch()
        (godot.parent / ".verified").write_text(kit.PACKAGES["godot"][1])
        staged = root / "staged-source"
        (staged / "game").mkdir(parents=True)
        (staged / "game/project.godot").write_text("synthetic audited source")
        manifest = staged / "PUBLICATION_MANIFEST.json"
        manifest.write_text(json.dumps({"files": {"game/project.godot": kit.digest(staged / "game/project.godot")}}))
        source = root / ("source-" + kit.digest(manifest)[:12])
        staged.rename(source)
        manifest = source / "PUBLICATION_MANIFEST.json"
        apk = storage / "official" / "PowerOfChaos-Android-v0.1.0-alpha.19.apk"
        apk.parent.mkdir()
        apk.write_bytes(b"public APK from stable maintainer signing key")
        key = storage / "signing/debug.keystore"
        key.parent.mkdir()
        key.write_bytes(b"personal key must remain untouched")
        info = release_info(launcher, kit.digest(manifest), kit.digest(apk))
        return storage, source, apk, key, info

    def test_public_default_reuses_verified_sources_and_apk_without_sdk_or_signing(self):
        with tempfile.TemporaryDirectory() as temporary:
            launcher = Path(temporary)
            storage, source, apk, key, info = self._public_fixture(launcher)
            apk_hash = kit.digest(apk)
            with patch.object(kit, "RELEASE_INFO", info), \
                 patch.object(kit, "fetch") as fetch, patch.object(kit.subprocess, "run") as execute:
                config = kit.prepare(launcher)
            fetch.assert_not_called()
            execute.assert_not_called()
            self.assertEqual(config["root"], source)
            self.assertEqual(config["public_apk"], apk)
            self.assertEqual(config["public_apk_sha256"], apk_hash)
            self.assertNotIn("keystore", config)
            self.assertFalse((storage / "sdk-license.accepted").exists())
            self.assertFalse((storage / "tools/kit-1/sdk").exists())
            self.assertFalse((storage / "progress.json").exists())
            self.assertEqual(key.read_bytes(), b"personal key must remain untouched")

    def test_public_missing_apk_downloads_only_pinned_public_file(self):
        with tempfile.TemporaryDirectory() as temporary:
            launcher = Path(temporary)
            storage, _, apk, key, info = self._public_fixture(launcher)
            apk_hash = kit.digest(apk)
            payload = apk.read_bytes()
            apk.unlink()
            def fetched(url, target, expected, progress=None):
                self.assertEqual(url, kit.RELEASES + "v0.1.0-alpha.19/PowerOfChaos-Android.apk")
                self.assertEqual(expected, apk_hash)
                target.write_bytes(payload)
            with patch.object(kit, "RELEASE_INFO", info), \
                 patch.object(kit, "fetch", side_effect=fetched) as fetch, \
                 patch.object(kit.subprocess, "run") as execute:
                config = kit.prepare(launcher)
            self.assertEqual(fetch.call_count, 1)
            execute.assert_not_called()
            self.assertEqual(kit.digest(config["public_apk"]), apk_hash)
            self.assertEqual(key.read_bytes(), b"personal key must remain untouched")

    def test_public_source_tampering_is_rejected_before_apk_fetch(self):
        with tempfile.TemporaryDirectory() as temporary:
            launcher = Path(temporary)
            _, source, _, _, info = self._public_fixture(launcher)
            (source / "game/project.godot").write_text("modified source")
            with patch.object(kit, "RELEASE_INFO", info), patch.object(kit, "fetch") as fetch:
                with self.assertRaisesRegex(ValueError, "Fuente Android no válida"):
                    kit.prepare(launcher)
            fetch.assert_not_called()

    def test_public_missing_audited_hash_fails_before_any_download(self):
        with tempfile.TemporaryDirectory() as temporary, patch.object(kit, "fetch") as fetch:
            info = release_info(Path(temporary), "a" * 64, "PENDING")
            with patch.object(kit, "RELEASE_INFO", info), self.assertRaisesRegex(ValueError, "SHA-256 auditado"):
                kit.prepare(Path(temporary))
            with patch.object(kit, "RELEASE_INFO", Path(temporary) / "absent.json"), \
                 self.assertRaisesRegex(ValueError, "no incluye el APK"):
                kit.prepare(Path(temporary))
            fetch.assert_not_called()


if __name__ == "__main__":
    unittest.main()
