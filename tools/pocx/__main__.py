"""Extrae los tres Power of Chaos a una carpeta data/ unificada y legible por Godot.

Uso:
    poetry run python -m pocx extract --src ../extracted --out ../data
"""
from __future__ import annotations

import argparse
import collections
import json
import struct
import sys
from dataclasses import asdict, replace
from pathlib import Path

from PIL import Image

from .archive import Archive
from .carddb import (LANGS, TEXT_ENCODING, Deck, card_to_dict, load_cards, parse_deck_txt,
                     parse_ydc)
from .images import apply_color_key, decode_bmp, decode_image, detect_color_key
from .layout import layout_to_dict, load_layout
from .logo import build as build_logo
from .replay import parse_dialogs, parse_ydr
from .voices import export_voice

GAMES = {"yugi": "y", "kaiba": "k", "joey": "j"}
# Se elige el juego más reciente disponible para los recursos comunes.
SHARED_DIRS = ("card/", "mini/", "cursor/", "bin#/")
# El arte de las cartas siempre es opaco
OPAQUE_DIRS = ("card/", "mini/")
SKIP_SUFFIXES = (".db", ".sue")
OVERRIDES_FILE = Path(__file__).with_name("color_key_overrides.json")


def _decode_text(raw: bytes) -> str:
    try:
        return raw.decode("cp932")
    except UnicodeDecodeError:
        return raw.decode("cp1252", "replace")


def _load_overrides() -> dict:
    """Excepciones manuales: {"<ruta en data/>.png": [r, g, b] | null}."""
    if not OVERRIDES_FILE.exists():
        return {}
    data = json.loads(OVERRIDES_FILE.read_text(encoding="utf-8"))
    return {k: v for k, v in data.items() if not k.startswith("_")}


def _key_image(rel: str, im, overrides: dict):
    """Decide y aplica el color clave de un BMP ya decodificado (RGB)."""
    key = detect_color_key(im)
    if Path(rel).stem.endswith("_mask"):
        # mascaras que el motor usa para mezclar efectos; se conservan tal cual
        key = replace(key, color=None, rule="mask")
    if rel in overrides:
        color = overrides[rel]
        key = replace(key, color=tuple(color) if color else None, rule="override")
    if key.keyed:
        im = apply_color_key(im, key.color)
    return im, key


def rekey(data_dir: Path) -> None:
    """Recalcula la transparencia de los PNG que vienen de BMP sin volver a extraer nada:
    los pixeles transparentes conservan su color original, asi que se puede rehacer."""
    keys_path = data_dir / "color_keys.json"
    color_keys = json.loads(keys_path.read_text(encoding="utf-8"))
    overrides = _load_overrides()
    changed = 0
    for rel, old in color_keys.items():
        png = data_dir / rel
        rgb = Image.open(png).convert("RGBA").convert("RGB")
        im, key = _key_image(rel, rgb, overrides)
        new = asdict(key)
        if new["color"] != (tuple(old["color"]) if old["color"] else None) or new["rule"] != old["rule"]:
            im.save(png)
            changed += 1
            print(f"  {rel}: {old['rule']} {old['color']} -> {new['rule']} {new['color']}")
        color_keys[rel] = new
    keys_path.write_text(json.dumps(color_keys, indent=1), encoding="utf-8")
    print(f"{changed} imagenes cambiadas de {len(color_keys)}")


def _convert(name: str, data: bytes, out: Path, dest: Path, stats: collections.Counter,
             color_keys: dict, overrides: dict) -> None:
    lower = name.lower()
    dest.parent.mkdir(parents=True, exist_ok=True)
    if lower.endswith(".bmp") and not name.startswith(OPAQUE_DIRS):
        png = dest.with_suffix(".png")
        rel = png.relative_to(out).as_posix()
        im, key = _key_image(rel, decode_bmp(data), overrides)
        if key.keyed:
            stats["png_keyed"] += 1
        color_keys[rel] = asdict(key)
        im.save(png)
        stats["png"] += 1
    elif lower.endswith((".bmp", ".yga")):
        decode_image(name, data).save(dest.with_suffix(".png"))
        stats["png"] += 1
    elif lower.endswith(".txt"):
        text = _decode_text(data).replace("\r\n", "\n")
        dest.write_text(text, encoding="utf-8", newline="\n")
        stats["txt"] += 1
    elif lower.endswith(".ydc"):
        deck = parse_ydc(data)
        dest.with_suffix(".json").write_text(json.dumps(deck.__dict__), encoding="utf-8")
        stats["deck"] += 1
    else:
        dest.write_bytes(data)
        stats["raw"] += 1


def extract(src: Path, out: Path) -> None:
    stats: collections.Counter = collections.Counter()
    inventory: dict = {"games": {}}
    color_keys: dict = {}
    overrides = _load_overrides()

    selected = [g for g in GAMES if (src / g / "app/Data.dat").is_file()]
    if not selected:
        raise ValueError("Selecciona al menos un juego")
    master = next(g for g in reversed(GAMES) if g in selected)
    cards = []
    voices = {"format": 1, "games": {}}
    for game in selected:
        prefix = GAMES[game]
        app = src / game / "app"
        with Archive(app / "Data.dat") as data, Archive(app / "Voice.dat") as voice:
            print(f"[{game}] Data.dat: {len(data.entries)} entradas, Voice.dat: {len(voice.entries)}",
                  flush=True)
            for entry in data.entries:
                name = entry.name
                if name.lower().endswith(SKIP_SUFFIXES):
                    continue
                if name.startswith(SHARED_DIRS):
                    if game != master:
                        continue
                    dest = out / "common" / name.replace("bin#/", "bin/")
                else:
                    dest = out / game / name[len(prefix) + 1:]
                _convert(name, data.read(entry), out, dest, stats, color_keys, overrides)

            stats["wav"] += export_voice(app / "Voice.dat", out, game, voices)

            deck_txt = data.read(f"{prefix}/file/deck_{prefix}.txt").decode("cp932")
            rival = parse_deck_txt(deck_txt)
            (out / game / "file").mkdir(parents=True, exist_ok=True)
            (out / game / "file" / "rival_deck.json").write_text(json.dumps(rival.__dict__),
                                                                 encoding="utf-8")
            inventory["games"][game] = {
                "data_entries": len(data.entries),
                "voice_entries": len(voice.entries),
                "region": (app / "Region.dat").read_text(encoding="latin-1"),
            }

            if game == master:
                cards = load_cards(data)

    db_dir = out / "common" / "db"
    db_dir.mkdir(parents=True, exist_ok=True)
    (db_dir / "cards.json").write_text(
        json.dumps([card_to_dict(c) for c in cards], ensure_ascii=False, indent=1), encoding="utf-8")

    pools = {g: sorted(c.index for c in cards if g in c.games) for g in GAMES}
    inventory["card_pools"] = {g: len(v) for g, v in pools.items()}
    inventory["cards_total"] = len(cards)
    inventory["cards_with_art"] = sum(1 for c in cards if c.image)
    inventory["converted"] = dict(stats)
    (out / "color_keys.json").write_text(json.dumps(color_keys, indent=1), encoding="utf-8")
    inventory["layouts"] = export_layouts(out)
    inventory["dialogs"] = export_dialogs(out)
    inventory["master"] = master
    for game in selected:
        inventory.setdefault("duel_images", {})[game] = export_duel_image(src, out, game)
    export_starter_decks(src, out, selected)
    if "yugi" in selected:
        build_logo(out)
    (out / "voice_manifest.json").write_text(json.dumps(voices, indent=2), encoding="utf-8")
    (out / "inventory.json").write_text(json.dumps(inventory, indent=2), encoding="utf-8")
    print(json.dumps(inventory, indent=2))


def export_layouts(data: Path) -> int:
    """Escribe <script>.layout.json junto a cada script de maquetacion de data/<juego>/."""
    count = 0
    for game in GAMES:
        for path in (data / game).rglob("*.txt"):
            if path.parent.name == "file":   # mazos escritos a mano, no maquetacion
                continue
            layout = load_layout(path, data)
            path.with_suffix(".layout.json").write_text(
                json.dumps(layout_to_dict(layout), ensure_ascii=False, indent=1), encoding="utf-8")
            count += 1
    return count


# Ejecutables cuyo motor de duelo se porta: Yugi (game/duel/core) y Joey (motor nativo,
# docs/duel/PLAN_MOTOR_JOEY.md). Las direcciones de cada motor son las de su ejecutable.
DUEL_EXES = {"yugi": ("Yugi_Pc.exe", "1cf221dc312d568c309e649b69b3c3b7"),
             "kaiba": ("Kaiba_Pc.exe", "11c64e931e29b13637a1b617fe2a19a4"),
             "joey": ("Joey_Pc.exe", "6bb361cd96a6a1964a35c00625bad82b")}


def export_duel_image(src: Path, data: Path, game: str = "yugi") -> int:
    """Copia .rdata y .data del ejecutable a common/duel/<juego>_image.bin (desde el inicio de
    .rdata: 0x59a000 en Yugi, 0x5da000 en Joey).

    El nucleo del duelo carga esta imagen en su modelo de memoria para que las rutinas
    portadas lean las tablas y globales en las mismas direcciones que el original."""
    from .executable import duel_image
    exe_name = STARTER_TABLES[game][0]
    exe = (src / game / "app" / exe_name).read_bytes()
    image = duel_image(exe, game)
    dest = data / "common" / "duel" / f"{game}_image.bin"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(bytes(image))
    return len(image)


# Mazo inicial de cada juego: tabla del .exe que lee la funcion que lo carga
# (Yugi 53f8b0, Kaiba 541f80, Joey 5bdc50). El Deck.ydc instalado no sirve: es el mazo
# actual del jugador, y el instalador de Kaiba trae el de Joey.
STARTER_TABLES = {"yugi": ("Yugi_Pc.exe", 0x59df50), "kaiba": ("Kaiba_Pc.exe", 0x5a1030),
                  "joey": ("Joey_Pc.exe", 0x5dd9b4)}


def _read_va(exe: bytes, addr: int, size: int) -> bytes:
    pe_off = struct.unpack_from("<I", exe, 0x3C)[0]
    n_sections = struct.unpack_from("<H", exe, pe_off + 6)[0]
    opt_size = struct.unpack_from("<H", exe, pe_off + 20)[0]
    image_base = struct.unpack_from("<I", exe, pe_off + 24 + 28)[0]
    for i in range(n_sections):
        o = pe_off + 24 + opt_size + i * 40
        _vsize, vaddr, raw_size, raw_ptr = struct.unpack_from("<4I", exe, o + 8)
        rel = addr - image_base - vaddr
        if 0 <= rel and rel + size <= raw_size:
            return exe[raw_ptr + rel:raw_ptr + rel + size]
    raise ValueError(f"0x{addr:x} fuera de las secciones del exe")


def parse_starter_table(exe: bytes, addr: int) -> Deck:
    """u32 n, n entradas u32 (id en la mitad baja), u32 m fusiones y m entradas u32."""
    def word(i: int) -> int:
        return struct.unpack("<I", _read_va(exe, addr + 4 * i, 4))[0]
    n = word(0)
    m = word(n + 1)
    if not (0 < n <= 80 and m <= 30):
        raise ValueError(f"tabla de mazo inicial invalida en 0x{addr:x} ({n}, {m})")
    main = [word(1 + i) & 0xFFFF for i in range(n)]
    fusion = [word(n + 2 + i) & 0xFFFF for i in range(m)]
    return Deck(main, fusion, [])


def export_starter_decks(src: Path, data: Path, games=None) -> dict:
    """Escribe <juego>/file/starter_deck.json desde la tabla del mazo inicial de cada .exe."""
    sizes = {}
    for game in (games if games is not None else GAMES):
        exe_name, addr = STARTER_TABLES[game]
        executable = (src / game / "app" / exe_name).read_bytes()
        if game == "yugi":
            from .executable import validate
            from .yugi_image import US_STARTER_TABLE
            if validate(executable, game).yugi_us_update:
                addr = US_STARTER_TABLE
        deck = parse_starter_table(executable, addr)
        dest = data / game / "file" / "starter_deck.json"
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(json.dumps(deck.__dict__), encoding="utf-8")
        sizes[game] = (len(deck.main), len(deck.fusion))
    return sizes


def export_dialogs(data: Path) -> int:
    """Escribe common/db/dlg_<idioma>.json con los mensajes del duelo (indice = id del mensaje)."""
    for lang in LANGS:
        bin_dir = data / "common" / "bin"
        texts = parse_dialogs((bin_dir / f"dlg_indx{lang[:3]}.bin").read_bytes(),
                              (bin_dir / f"dlg_text{lang[:3]}.bin").read_bytes(),
                              TEXT_ENCODING.get(lang, "cp1252"))
        (data / "common" / "db" / f"dlg_{lang}.json").write_text(
            json.dumps(texts, ensure_ascii=False, indent=0), encoding="utf-8")
    return len(texts)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="pocx")
    sub = parser.add_subparsers(dest="cmd", required=True)
    ex = sub.add_parser("extract", help="convierte los .dat originales a data/")
    ex.add_argument("--src", type=Path, required=True,
                    help="carpeta con yugi/, kaiba/, joey/ (salida de innoextract)")
    ex.add_argument("--out", type=Path, required=True)
    lay = sub.add_parser("layouts", help="regenera los .layout.json de una data/ ya extraida")
    lay.add_argument("--data", type=Path, required=True)
    rk = sub.add_parser("rekey", help="recalcula la transparencia de los PNG de una data/ ya extraida")
    rk.add_argument("--data", type=Path, required=True)
    di = sub.add_parser("duelimage", help="copia la imagen de datos del ejecutable para el nucleo del duelo")
    di.add_argument("--src", type=Path, required=True)
    di.add_argument("--data", type=Path, required=True)
    di.add_argument("--game", choices=sorted(DUEL_EXES), default="yugi")
    sd = sub.add_parser("starters", help="exporta el mazo inicial de cada .exe a <juego>/file/starter_deck.json")
    sd.add_argument("--src", type=Path, required=True)
    sd.add_argument("--data", type=Path, required=True)
    dl = sub.add_parser("dialogs", help="exporta los mensajes del duelo a common/db/dlg_*.json")
    dl.add_argument("--data", type=Path, required=True)
    gf = sub.add_parser("gdifont", help="genera con GDI la fuente del texto de los cuadros del duelo (Windows)")
    gf.add_argument("--data", type=Path, required=True)
    lg = sub.add_parser("logo", help="recorta el logo de Yugi del splash para el selector de juego")
    lg.add_argument("--data", type=Path, required=True)
    yd = sub.add_parser("ydr", help="vuelca una repeticion .ydr a JSON legible")
    yd.add_argument("files", type=Path, nargs="+")
    yd.add_argument("--out", type=Path, help="carpeta de salida (por defecto, junto al .ydr)")
    sy = sub.add_parser("import-system",
                        help="convierte el system.dat del original (y sus Deck.ydc) al system.json del port")
    sy.add_argument("system_dat", type=Path)
    sy.add_argument("--data", type=Path, required=True, help="data/ con common/db/cards.json")
    sy.add_argument("--out", type=Path, required=True, help="system.json de salida")
    ex = sub.add_parser("export-system", help="exporta system.json a una ruta system.dat explicita")
    ex.add_argument("system_json", type=Path)
    ex.add_argument("--data", type=Path, required=True)
    ex.add_argument("--out", type=Path, required=True)
    ex.add_argument("--game", choices=["yugi", "kaiba", "joey"], default="yugi")
    ex.add_argument("--system-dat-key", type=lambda s: int(s, 0), help="flcrc de la instalacion; si falta, usa cabecera importada")
    args = parser.parse_args(argv)
    if args.cmd == "extract":
        extract(args.src, args.out)
    elif args.cmd == "layouts":
        print(f"{export_layouts(args.data)} scripts de maquetacion exportados")
    elif args.cmd == "rekey":
        rekey(args.data)
    elif args.cmd == "duelimage":
        print(f"{export_duel_image(args.src, args.data, args.game)} bytes")
    elif args.cmd == "starters":
        print(export_starter_decks(args.src, args.data))
    elif args.cmd == "dialogs":
        print(f"{export_dialogs(args.data)} mensajes por idioma")
    elif args.cmd == "gdifont":
        from .gdi_font import build
        build(args.data)
    elif args.cmd == "logo":
        print(build_logo(args.data))
    elif args.cmd == "ydr":
        for path in args.files:
            replay = parse_ydr(path.read_bytes())
            dest = (args.out or path.parent) / (path.stem + ".ydr.json")
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(json.dumps(replay.to_dict(), indent=1), encoding="utf-8")
            print(f"{path.name}: {len(replay.commands)} comandos -> {dest}")
    elif args.cmd == "import-system":
        from .systemdat import import_system
        cards = json.loads((args.data / "common/db/cards.json").read_text(encoding="utf-8"))
        save = import_system(args.system_dat, cards)
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(save, indent="\t"), encoding="utf-8")
        print(f"{len(save['collection'])} cartas, mazos {sorted(save['decks'])} -> {args.out}")
    elif args.cmd == "export-system":
        from .systemdat import export_system
        cards = json.loads((args.data / "common/db/cards.json").read_text(encoding="utf-8"))
        save = json.loads(args.system_json.read_text(encoding="utf-8"))
        raw = export_system(save, cards, args.game, args.system_dat_key)
        args.out.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.out.with_name(args.out.name + ".tmp")
        temporary.write_bytes(raw)
        temporary.replace(args.out)
        print(f"{len(raw)} bytes -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
