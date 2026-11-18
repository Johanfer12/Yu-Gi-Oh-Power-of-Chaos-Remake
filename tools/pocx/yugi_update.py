"""Read the December 2003 Yugi update from the US Kaiba disc as data."""
import hashlib
from pathlib import Path
import struct
import subprocess

from .executable import validate


MSP_NAME = b"UpdateEngE.msp"
DATA_SHA256 = "e4f2c2bdbc1cf4c2c419108a8b7026432a4bd00d6fc0db7d03242d9abdcc4975"
INSTALLSHIELD = b"InstallShield\0"
INSTALLSHIELD_KEY = b"\x13\x35\x86\x07"


def _extract_msp(installer: Path, target: Path) -> None:
    size = installer.stat().st_size
    with installer.open("rb") as source:
        header = source.read(64)
        if len(header) != 64 or header[:2] != b"MZ":
            raise ValueError("Invalid InstallShield executable header")
        source.seek(struct.unpack_from("<I", header, 60)[0])
        coff = source.read(24)
        if len(coff) != 24 or coff[:4] != b"PE\0\0":
            raise ValueError("Invalid InstallShield PE header")
        section_count = int.from_bytes(coff[6:8], "little")
        source.seek(int.from_bytes(coff[20:22], "little"), 1)
        overlay = 0
        for _ in range(section_count):
            section = source.read(40)
            if len(section) != 40:
                raise ValueError("Truncated InstallShield section table")
            length, start = struct.unpack_from("<II", section, 16)
            overlay = max(overlay, start + length)

        source.seek(overlay)
        header = source.read(0x2E)
        if len(header) != 0x2E or not header.startswith(INSTALLSHIELD):
            raise ValueError("Missing InstallShield overlay")
        for _ in range(int.from_bytes(header[14:16], "little")):
            entry = source.read(312)
            if len(entry) != 312:
                raise ValueError("Truncated InstallShield file header")
            name = entry[:260].split(b"\0", 1)[0]
            flags, _, length = struct.unpack_from("<III", entry, 260)
            end = source.tell() + length
            if end > size:
                raise ValueError("Truncated InstallShield file")
            if name.lower() == MSP_NAME.lower():
                if flags != 2:
                    raise ValueError("Unsupported InstallShield encoding for UpdateEngE.msp")
                _decode_msp(source, target, name, length)
                return
            source.seek(end)
    raise ValueError("UpdateEngE.msp is missing from Update.exe")


def _decode_msp(source, target: Path, name: bytes, length: int) -> None:
    key = [char ^ INSTALLSHIELD_KEY[i % len(INSTALLSHIELD_KEY)] for i, char in enumerate(name)]
    tables = [bytes(255 ^ mask ^ ((byte << 4 | byte >> 4) & 255) for byte in range(256)) for mask in key]
    # A chunk spans whole key periods so each column can use a fast byte translation.
    step = len(key)
    chunk_size = step * 65536
    with target.open("wb") as output:
        for start in range(0, length, chunk_size):
            chunk = bytearray(source.read(min(chunk_size, length - start)))
            for i, table in enumerate(tables):
                chunk[i::step] = chunk[i::step].translate(table)
            output.write(chunk)


def _extract_files(sevenzip: str, archive: Path, output: Path, *names: str) -> None:
    result = subprocess.run([sevenzip, "x", str(archive), f"-o{output}", "-y", "-ssc-", *names],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode != 0:
        raise ValueError(result.stdout.decode("utf-8", errors="replace").strip())


def _update_files(root: Path) -> tuple[Path, Path] | None:
    for candidate in root.rglob("*"):
        if candidate.name.lower() != "update.exe" or not candidate.is_file():
            continue
        data = next((path for path in candidate.parent.iterdir()
                     if path.name.lower() == "update.tmp" and path.is_file()), None)
        if data is not None:
            return candidate, data
    return None


def extract_update(root: Path, workspace: Path, sevenzip: str) -> tuple[Path, Path]:
    """Extract the full replacement Yugi executable and catalogue from local media."""
    files = _update_files(root)
    if files is None:
        for index, cabinet in enumerate(root.rglob("*")):
            if cabinet.name.lower() != "data1.cab" or not cabinet.is_file():
                continue
            dest = workspace / f"kaiba-cab-{index}"
            _extract_files(sevenzip, cabinet, dest, "Update.exe", "update.tmp")
            files = _update_files(dest)
            if files is not None:
                break
    if files is None:
        raise ValueError("Update.exe and update.tmp are missing from the selected Kaiba media")
    installer, data = files
    with data.open("rb") as source:
        if hashlib.file_digest(source, "sha256").hexdigest() != DATA_SHA256:
            raise ValueError("update.tmp is not the verified December 2003 Yugi catalogue")
    workspace.mkdir(parents=True, exist_ok=True)
    msp = workspace / MSP_NAME.decode("ascii")
    _extract_msp(installer, msp)
    _extract_files(sevenzip, msp, workspace, "PCW_CAB_Family00")
    _extract_files(sevenzip, workspace / "PCW_CAB_Family00", workspace, "yugi_pc.exe")
    executable = workspace / "yugi_pc.exe"
    if not validate(executable.read_bytes(), "yugi").yugi_us_update:
        raise ValueError("The patch does not contain the verified US Yugi executable")
    return executable, data
