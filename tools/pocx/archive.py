"""Lector de los archivos KCEJYUGI (Data.dat / Voice.dat) de Yu-Gi-Oh! Power of Chaos."""
from __future__ import annotations

import struct
from dataclasses import dataclass
from pathlib import Path

MAGIC = b"KCEJYUGI"
ENTRY_SIZE = 0x10C
NAME_SIZE = 256


def _nibble_swap(data: bytes) -> bytes:
    return bytes(((c << 4) | (c >> 4)) & 0xFF for c in data)


@dataclass(frozen=True)
class Entry:
    name: str
    offset: int
    size: int          # tamano descomprimido
    stored_size: int   # tamano en el archivo

    @property
    def compressed(self) -> bool:
        return self.size != self.stored_size


class Archive:
    def __init__(self, path: str | Path):
        self.path = Path(path)
        self._fh = open(self.path, "rb")
        try:
            self._load_index()
        except Exception:
            self._fh.close()
            raise

    def _load_index(self) -> None:
        header = self._fh.read(12)
        if len(header) != 12 or header[:8] != MAGIC:
            raise ValueError(f"{self.path}: no es un archivo KCEJYUGI")
        (count,) = struct.unpack("<I", header[8:])
        file_size = self.path.stat().st_size
        index_end = 12 + count * ENTRY_SIZE
        if index_end > file_size:
            raise ValueError(f"{self.path}: índice de recursos truncado")
        raw = self._fh.read(count * ENTRY_SIZE)
        self.entries: list[Entry] = []
        for i in range(count):
            e = raw[i * ENTRY_SIZE:(i + 1) * ENTRY_SIZE]
            name = _nibble_swap(e[:NAME_SIZE].split(b"\0", 1)[0]).decode("latin-1")
            off, size, stored = struct.unpack("<III", e[NAME_SIZE:])
            if off < index_end or off + stored > file_size:
                raise ValueError(f"{self.path}: recurso fuera de los límites del archivo")
            name = name.replace("\\", "/")
            if name.startswith("/") or ":" in name or any(part == ".." for part in name.split("/")):
                raise ValueError("Ruta no segura dentro del archivo de recursos")
            self.entries.append(Entry(name, off, size, stored))
        self.by_name = {e.name.lower(): e for e in self.entries}

    def read_raw(self, entry: Entry) -> bytes:
        self._fh.seek(entry.offset)
        return self._fh.read(entry.stored_size)

    def read(self, entry: Entry | str) -> bytes:
        if isinstance(entry, str):
            entry = self.by_name[entry.lower().replace("\\", "/")]
        data = self.read_raw(entry)
        if entry.compressed:
            data = lzss_decompress(data, entry.size)
        return data

    def close(self) -> None:
        self._fh.close()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()


def folder_names(folder: Path) -> dict[str, Path]:
    """Loose resources of an unpacked Data.dat: archive-style lower-case name -> file."""
    return {path.relative_to(folder).as_posix().lower(): path
            for path in sorted(folder.rglob("*")) if path.is_file()}


def pack_folder(folder: Path, destination: Path) -> int:
    """Write the loose files of an unpacked Data.dat back as an uncompressed KCEJYUGI
    archive, so the rest of the import reads it like the original. Returns the count."""
    files = folder_names(folder)
    if not files:
        raise ValueError(f"{folder}: carpeta de recursos vacía")
    offset = 12 + len(files) * ENTRY_SIZE
    index = bytearray()
    for name, path in files.items():
        encoded = _nibble_swap(name.encode("latin-1"))
        if len(encoded) >= NAME_SIZE:
            raise ValueError(f"Nombre de recurso demasiado largo: {name}")
        size = path.stat().st_size
        index += encoded.ljust(NAME_SIZE, b"\0") + struct.pack("<III", offset, size, size)
        offset += size
    with open(destination, "wb") as output:
        output.write(MAGIC + struct.pack("<I", len(files)) + index)
        for path in files.values():
            with open(path, "rb") as source:
                while chunk := source.read(1 << 20):
                    output.write(chunk)
    return len(files)


def lzss_decompress(src: bytes, out_size: int) -> bytes:
    """LZSS estilo Okumura: flag bit 1 = literal; referencia = 12 bits de posicion
    en ventana de 4096 (inicio 0xFEE, relleno con ceros) + 4 bits de longitud (+3)."""
    window = bytearray(4096)
    wpos = 0xFEE
    out = bytearray()
    i = 0
    n = len(src)
    while i < n and len(out) < out_size:
        flags = src[i]
        i += 1
        for bit in range(8):
            if i >= n or len(out) >= out_size:
                break
            if flags & (1 << bit):
                c = src[i]
                i += 1
                out.append(c)
                window[wpos] = c
                wpos = (wpos + 1) & 0xFFF
            else:
                if i + 1 >= n:
                    i = n
                    break
                lo, hi = src[i], src[i + 1]
                i += 2
                pos = lo | ((hi & 0xF0) << 4)
                length = (hi & 0x0F) + 3
                for k in range(length):
                    c = window[(pos + k) & 0xFFF]
                    out.append(c)
                    window[wpos] = c
                    wpos = (wpos + 1) & 0xFFF
    return bytes(out)
