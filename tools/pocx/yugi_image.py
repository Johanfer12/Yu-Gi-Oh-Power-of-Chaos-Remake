"""Adapt the verified December 2003 US update to the existing Yugi memory model."""
import struct

# Inclusive ranges of dispatch targets in the validated US tables. Each range
# shares one displacement to the corresponding identity in the supported port.
DISPATCH_OFFSETS = (
    (0x53B2B0, 0x53B2B0, 0x4E0),
    (0x53D460, 0x53D4C0, 0x510),
    (0x54F5D0, 0x5514C0, 0x490),
    (0x551DC0, 0x553CC0, 0x4A0),
    (0x553D60, 0x5550C0, 0x460),
    (0x555200, 0x578650, 0x420),
    (0x580420, 0x583970, 0x490),
)
BASE = 0x59A000
US_STARTER_TABLE = 0x59DF60


def build_us_update(pe) -> bytes:
    output = bytearray(0x15000)
    constants = bytearray(pe.read(0x59DF2C, 0x61C))
    for address in range(0x59E148, 0x59E170, 4):
        offset = address - 0x59DF1C
        pointer, = struct.unpack_from("<I", constants, offset)
        struct.pack_into("<I", constants, offset, pointer + (8 if address == 0x59E148 else -16))
    dispatch = bytearray(pe.read(0x5AA6E8, 0x2CE8))
    for offset in range(0, len(dispatch), 4):
        if 0x5AA890 <= 0x5AA6E8 + offset < 0x5AAA38:
            continue  # Los IDs de materiales de fusión están empaquetados de dos en dos.
        word, = struct.unpack_from("<I", dispatch, offset)
        if 0x59E010 <= word <= 0x59E0A8:
            struct.pack_into("<I", dispatch, offset, word - 16)
        elif 0x401000 <= word < BASE:
            for first, last, delta in DISPATCH_OFFSETS:
                if first <= word <= last:
                    struct.pack_into("<I", dispatch, offset, word + delta)
                    break
    for address, data in ((0x59A59C, pe.read(0x59A594, 0x30)),
                          (0x59DF1C, constants), (0x5AA6E8, dispatch)):
        start = address - BASE
        output[start:start + len(data)] = data
    return bytes(output)
