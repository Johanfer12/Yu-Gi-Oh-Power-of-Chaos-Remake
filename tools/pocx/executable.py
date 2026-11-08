"""Read compatible PE data tables without running or modifying executable code."""
from __future__ import annotations
import hashlib
import re
import struct

# Only hashes/addresses, never original game bytes. Profiles verified against local and CD media.
PROFILES = {
    "yugi": ((0x59A000, 65536, "4d4b409abc2ba74c81daa35cf95bef3066729b457155b8e575da3485d97aa27e"),
             (0x5AA000, 20480, "2437138ff57f1e79d4a32c111b63324b624e082dcc2e20d7a3924b0a42e1762a")),
    "kaiba": ((0x59D000, 65536, "c093441a6628767dbc7ad0505ca7a55d75a2710076beb385cc976b769be4da1b"),
              (0x5AD000, 20480, "f2584b419fa327be3eedd6791d6367bdbd7628bfb64dd7b2c74495e4960935e8")),
    "joey": ((0x5DA000, 69632, "36742e92a8b16909413990cc1e92afce147053e73bf6dd4c3d14c66a5e92e1ce"),
             (0x5EB000, 32768, "f03246bf8dfd003a2769e484b04bf96fed59b9abf8532e6b80e1cb3775aeff02")),
}
KAIBA_LOCAL_MD5 = "11c64e931e29b13637a1b617fe2a19a4"
# Engine tables of that local layout. The US retail disc (Konami of America, 2004) has
# the same bytes except the case of the import DLL names ("KERNEL32.dll"), which the
# port never reads; names are lower-cased before hashing.
KAIBA_LOCAL_TABLES = ((0x59D000, 65536, "2fb4cd4ac200d3ca1905078f497f5c12087b336c96a52a7fac4e8ae411f74802"),
                      (0x5AD000, 20480, "b68e6d6f14bdb6dcd67b945f02c4fae3d6d498772cd3e45475442b60c6e2dc34"))


def _lower_dll_names(data: bytes) -> bytes:
    return re.sub(rb"[A-Za-z0-9_]+\.dll\x00", lambda match: match.group(0).lower(), data)
JOEY_RESOURCE_HASH = "534d03a19a8f71a55a40163805396f0917b8294ff254a010b624eaf63a8a9f84"


class PE:
    def __init__(self, raw: bytes):
        self.raw = raw
        try:
            if raw[:2] != b"MZ":
                raise ValueError("No es un ejecutable PE")
            pe = struct.unpack_from("<I", raw, 60)[0]
            machine, count = struct.unpack_from("<HH", raw, pe + 4)
            opt_size = struct.unpack_from("<H", raw, pe + 20)[0]
            opt = pe + 24
            if raw[pe:pe+4] != b"PE\0\0" or machine != 0x14C or struct.unpack_from("<H", raw, opt)[0] != 0x10B:
                raise ValueError("Se requiere PE x86 de 32 bits")
            self.base = struct.unpack_from("<I", raw, opt + 28)[0]
            if self.base != 0x400000 or not 1 <= count <= 96 or opt_size < 120:
                raise ValueError("Cabecera PE no compatible")
            self.resource_rva, self.resource_size = struct.unpack_from("<II", raw, opt + 112)
            self.sections = []
            for index in range(count):
                offset = opt + opt_size + index * 40
                virtual_size, rva, size, pointer = struct.unpack_from("<4I", raw, offset + 8)
                if pointer + size > len(raw):
                    raise ValueError("Sección PE truncada")
                self.sections.append((rva + self.base, size, pointer))
        except struct.error as error:
            raise ValueError("Cabecera PE truncada") from error

    def read(self, address: int, size: int) -> bytes:
        if size < 0:
            raise ValueError("Tamaño inválido")
        for start, length, pointer in self.sections:
            relative = address - start
            if 0 <= relative and relative + size <= length:
                return self.raw[pointer+relative:pointer+relative+size]
        raise ValueError(f"0x{address:x} fuera de los datos del ejecutable")

    def canonical_resources(self) -> bytes:
        # The original CD and local Joey have byte-identical resources after relocating
        # IMAGE_RESOURCE_DATA_ENTRY RVAs to the memory model's resource address.
        start = self.base + self.resource_rva
        raw_size = next((length for address, length, _ in self.sections if address == start), 0)
        if not raw_size or raw_size > 1024 * 1024:
            raise ValueError("Sección de recursos no compatible")
        data = bytearray(self.read(start, raw_size))
        visited = set()
        def walk(offset: int, depth: int = 0) -> None:
            if offset in visited or depth > 8 or offset + 16 > len(data):
                raise ValueError("Directorio de recursos no válido")
            visited.add(offset)
            named, ids = struct.unpack_from("<HH", data, offset + 12)
            if offset + 16 + (named + ids) * 8 > len(data):
                raise ValueError("Directorio de recursos truncado")
            for index in range(named + ids):
                child = struct.unpack_from("<I", data, offset + 20 + index * 8)[0]
                if child & 0x80000000:
                    walk(child & 0x7FFFFFFF, depth + 1)
                else:
                    if child + 16 > len(data):
                        raise ValueError("Entrada de recursos truncada")
                    rva, size = struct.unpack_from("<II", data, child)
                    if rva < self.resource_rva or rva - self.resource_rva + size > len(data):
                        raise ValueError("Contenido de recursos fuera de rango")
                    struct.pack_into("<I", data, child, rva - self.resource_rva + 0x65A000)
        walk(0)
        if hashlib.sha256(data).hexdigest() != JOEY_RESOURCE_HASH:
            raise ValueError("Los recursos de memoria de Joey no coinciden con el perfil compatible")
        return bytes(data)


def validate(raw: bytes, game: str) -> PE:
    pe = PE(raw)
    if game == "kaiba" and hashlib.md5(raw).hexdigest() == KAIBA_LOCAL_MD5:
        return pe # Existing verified local layout has rewritten section names/imports.
    if game == "kaiba" and all(
            hashlib.sha256(_lower_dll_names(pe.read(address, size))).hexdigest() == expected
            for address, size, expected in KAIBA_LOCAL_TABLES):
        return pe # US retail disc: local tables; only its import DLL names are upper case.
    for address, size, expected in PROFILES[game]:
        if hashlib.sha256(pe.read(address, size)).hexdigest() != expected:
            raise ValueError(f"{game}: tablas del motor no compatibles en 0x{address:x}")
    if game == "joey":
        pe.canonical_resources()
    return pe


def duel_image(raw: bytes, game: str) -> bytes:
    pe = validate(raw, game)
    if game == "kaiba":
        from .kaiba_image import build
        return build(pe)
    spans = [(address, pe.read(address, size)) for address, size, _ in PROFILES[game]]
    if game == "joey":
        spans.append((0xA5A000, pe.canonical_resources()))
    base = spans[0][0]
    output = bytearray()
    for address, data in spans:
        output.extend(bytes(address - base - len(output)))
        output.extend(data)
    return bytes(output)
