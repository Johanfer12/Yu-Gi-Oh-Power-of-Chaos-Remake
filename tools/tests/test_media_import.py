"""Synthetic compatibility and language-pack regression tests; no game data."""
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
from pocx.executable import PE
from pocx.voices import export_voice


def archive(path: Path, entries: dict[str, bytes]) -> None:
    offset = 12 + 268 * len(entries)
    table, contents = bytearray(), bytearray()
    for name, payload in entries.items():
        encoded = bytes(((c << 4) | (c >> 4)) & 255 for c in name.encode())
        table.extend(encoded.ljust(256, b"\0") + struct.pack("<III", offset, len(payload), len(payload)))
        contents.extend(payload)
        offset += len(payload)
    path.write_bytes(b"KCEJYUGI" + struct.pack("<I", len(entries)) + table + contents)


class MediaImportTests(unittest.TestCase):
    def test_logo_contours_use_alpha_without_copying_rgb(self):
        from PIL import Image
        script = Path(__file__).resolve().parents[1] / "trace_logo_contours.py"
        spec = importlib.util.spec_from_file_location("trace_logo_contours", script)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            paths = [Path(directory) / name for name in ("a.png", "b.png")]
            for path, color in zip(paths, ((255, 0, 0), (0, 255, 255))):
                image = Image.new("RGBA", (8, 8), (*color, 0))
                for y in range(1, 7):
                    for x in range(1, 3 if y < 4 else 7):
                        image.putpixel((x, y), (*color, 255))
                image.save(path)
            self.assertEqual(module.trace(paths[0]), module.trace(paths[1]))
            size, loops = module.trace(paths[0])
            self.assertEqual(size, (8, 8))
            self.assertEqual(len(loops), 1)
            self.assertEqual(set(loops[0]), {(1, 1), (3, 1), (3, 4), (7, 4), (7, 7), (1, 7)})

    def test_two_languages_coexist_without_overwriting(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = {}
            for language, content in (("english", b"English sample"), ("spanish", b"Spanish sample")):
                source = root / f"{language}.dat"
                archive(source, {f"joey/{language}/internal/attack.wav": content})
                export_voice(source, root / "out", "joey", manifest)
            self.assertEqual(manifest["games"]["joey"]["languages"], ["e", "s"])
            self.assertEqual(manifest["games"]["joey"]["default"], "e")
            self.assertEqual((root/"out/joey/voice/e/internal/attack.wav").read_bytes(), b"English sample")
            self.assertEqual((root/"out/joey/voice/s/internal/attack.wav").read_bytes(), b"Spanish sample")

    def test_wrong_game_and_same_language_conflict_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = {}
            source = root / "voice.dat"
            archive(source, {"joey/english/internal/attack.wav": b"first"})
            with self.assertRaisesRegex(ValueError, "no compatible"):
                export_voice(source, root / "out", "yugi", {})
            export_voice(source, root / "out", "joey", manifest)
            archive(source, {"joey/english/internal/attack.wav": b"conflict"})
            with self.assertRaisesRegex(ValueError, "no se sobrescriben"):
                export_voice(source, root / "out", "joey", manifest)
            self.assertEqual((root/"out/joey/voice/e/internal/attack.wav").read_bytes(), b"first")

    def test_resource_rvas_are_relocated_and_content_verified(self):
        raw = bytearray(1024)
        raw[:2] = b"MZ"
        struct.pack_into("<I", raw, 60, 64)
        raw[64:68] = b"PE\0\0"
        struct.pack_into("<HH", raw, 68, 0x14C, 1)
        struct.pack_into("<H", raw, 84, 224)
        struct.pack_into("<H", raw, 88, 0x10B)
        struct.pack_into("<I", raw, 116, 0x400000)
        struct.pack_into("<II", raw, 200, 0x1000, 44)
        struct.pack_into("<4I", raw, 320, 512, 0x1000, 512, 512)
        struct.pack_into("<HH", raw, 524, 0, 1)
        struct.pack_into("<II", raw, 528, 1, 24)
        struct.pack_into("<IIII", raw, 536, 0x1028, 4, 0, 0)
        raw[552:556] = b"TEST"
        expected = bytearray(raw[512:])
        struct.pack_into("<I", expected, 24, 0x65A028)
        digest = hashlib.sha256(expected).hexdigest()
        with patch("pocx.executable.JOEY_RESOURCE_HASH", digest):
            self.assertEqual(PE(bytes(raw)).canonical_resources(), bytes(expected))
            raw[552] ^= 1
            with self.assertRaisesRegex(ValueError, "no coinciden"):
                PE(bytes(raw)).canonical_resources()

    def test_truncated_pe_and_unmapped_reads_are_rejected(self):
        with self.assertRaises(ValueError):
            PE(b"MZ")

    def test_import_dll_names_are_compared_case_insensitively(self):
        from pocx.executable import _lower_dll_names
        # US retail Kaiba writes "KERNEL32.dll"; the local layout "kernel32.dll".
        data = b"\x00FindResourceA\x00KERNEL32.dll\x00\x00wsprintfA\x00USER32.dll\x00"
        self.assertEqual(_lower_dll_names(data),
                         b"\x00FindResourceA\x00kernel32.dll\x00\x00wsprintfA\x00user32.dll\x00")


if __name__ == "__main__":
    unittest.main()
