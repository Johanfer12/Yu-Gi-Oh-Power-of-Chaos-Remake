class_name SystemDat
extends RefCounted
## Lectura del system.dat del original (carpeta "Yu-Gi-Oh! Power of Chaos Common"), comun a
## Yugi, Kaiba y Joey. Formato y rutinas (0x4628e0 / 0x4627c0 de Yugi) documentados en
## tools/pocx/systemdat.py y docs/INVENTARIO.md seccion 7. La exportacion escribe solo en la
## ruta elegida; conserva cabecera y campos desconocidos del bloque importado.
##
##   4 bytes de suma por carriles (0x42d510) + 562 grupos de 9 bytes; cada grupo guarda 8
##   valores de 9 bits, cada uno b^5 mod 299 de un byte (se descifra con ^53 mod 299).
##   Lo descifrado: 8 bytes de cabecera (byte 0 = 1) y el bloque de 0x1188 bytes que el
##   juego copia a 0xa10120 (validado por 0x53fc40: 0xfba5 en +0x1182 y suma en +0x1184).

const FILE_SIZE := 5062
const PLAIN_SIZE := 0x1190
const BLOCK_SIZE := 0x1188
const CARD_SLOTS := 0x45b
const SUM_BASE := [0x7d, 0x13, 0x8a, 0xbb]
const EXE_GAME := {"yugi_pc.exe": "yugi", "kaiba_pc.exe": "kaiba", "joey_pc.exe": "joey"}


## system.dat -> bloque de 0x1188 bytes, o vacio si el archivo no es valido.
static func decode(raw: PackedByteArray) -> PackedByteArray:
	var plain := _decode_plain(raw)
	return plain.slice(8) if not plain.is_empty() else PackedByteArray()


static func header(raw: PackedByteArray) -> PackedByteArray:
	var plain := _decode_plain(raw)
	return plain.slice(0, 8) if not plain.is_empty() else PackedByteArray()


static func _decode_plain(raw: PackedByteArray) -> PackedByteArray:
	if raw.size() != FILE_SIZE:
		return PackedByteArray()
	for j in 4:
		var total: int = SUM_BASE[j]
		for i in range(4 + j, PLAIN_SIZE, 4):
			total += raw[i]
		if raw[j] != (-total) & 0xff:
			return PackedByteArray()
	var plain := PackedByteArray()
	plain.resize(PLAIN_SIZE)
	for i in PLAIN_SIZE:
		var bit := 32 + i * 9
		var at := bit >> 3
		var v := (raw[at] | (raw[at + 1] << 8)) >> (bit & 7)
		plain[i] = _pow_mod(v & 0x1ff, 53, 299)
	if plain[0] != 1:
		return PackedByteArray()
	var block := plain.slice(8)
	return plain if block_valid(block) else PackedByteArray()


## 4627c0/442820/42d5e0: cabecera, potencia modular, grupos de nueve bits y suma exterior.
static func encode(block: PackedByteArray, head: PackedByteArray) -> PackedByteArray:
	if not block_valid(block) or head.size() != 8 or head[0] != 1:
		return PackedByteArray()
	var plain := head + block
	var raw := PackedByteArray()
	raw.resize(FILE_SIZE)
	for i in PLAIN_SIZE:
		var value := _pow_mod(plain[i], 5, 299)
		var bit := 32 + i * 9
		var at := bit >> 3
		var shifted := value << (bit & 7)
		raw[at] |= shifted & 0xff
		raw[at + 1] |= (shifted >> 8) & 0xff
	for j in 4:
		var total: int = SUM_BASE[j]
		for i in range(4 + j, PLAIN_SIZE, 4):
			total += raw[i]
		raw[j] = (-total) & 0xff
	return raw


static func seal(block: PackedByteArray) -> void:
	block.encode_u16(0x1182, 0xfba5)
	var total := 0
	for i in 0x8c2:
		total += block.decode_u16(i * 2)
	block.encode_u16(0x1184, (-total) & 0xffff)


## Proyecta los campos conocidos y conserva todos los demas del bloque importado.
## Devuelve vacio si las copias no caben: no truncar una coleccion ni un mazo al exportar.
static func from_save(save: Dictionary, by_index: Dictionary, game: String) -> PackedByteArray:
	var native: Dictionary = save.get("native_system", {})
	var block := Marshalls.base64_to_raw(str(native.get("block", "")))
	if block.size() != BLOCK_SIZE:
		block.resize(BLOCK_SIZE)
		for i in 8:
			block[0x117a + i] = "YUGIOH01".unicode_at(i)
	var deck: Dictionary = save.get("decks", {}).get(game, {})
	var total := 0
	for index in range(1, CARD_SLOTS):
		if not by_index.has(index):
			continue
		var id := int(by_index[index])
		var copies := int(save.get("collection", {}).get(str(id), 0))
		if copies < 0 or copies > 255:
			return PackedByteArray()
		var entry := block.decode_u16(0xc + index * 2) & 0x8000
		entry |= copies
		for pair in [["main", 8], ["side", 10], ["fusion", 12]]:
			var count := 0
			for card in deck.get(pair[0], []):
				count += int(int(card) == id)
			if count > 3:
				return PackedByteArray()
			entry |= count << int(pair[1])
		if save.get("seen", {}).has(str(id)):
			entry |= 0x4000
		block.encode_u16(0xc + index * 2, entry)
		total += copies
	if total > 0xffff:
		return PackedByteArray()
	block.encode_u16(0xa, total)
	var options: Dictionary = save.get("options", {})
	var current: Dictionary = options.get(game, {})
	var volume := clampi(int(current.get("volume", 15)), 0, 15)
	if volume != mini(15, block.decode_u16(6) >> 4):
		block.encode_u16(6, volume << 4)
	block.encode_u16(8, int(current.get("display", 0)))
	block.encode_u16(0x1178, int(native.get("limit_flags", 0)))
	var joey_options: Dictionary = options.get("joey", {})
	block[0x10ee] = int(joey_options.get("limited", block[0x10ee] != 0))
	block[0x10f4] = int(joey_options.get("card_set_full", block[0x10f4] != 0))
	var stats: Dictionary = save.get("stats", {})
	var common: Dictionary = stats.get(game, {})
	var wins := clampi(int(common.get("wins", 0)), 0, 0x7ff)
	var losses := clampi(int(common.get("losses", 0)), 0, 0x7ff)
	var draws := clampi(int(common.get("draws", 0)), 0, 0x3ff)
	block.encode_u32(0x10f8, wins | (losses << 11) | (draws << 22))
	var old: Dictionary = stats.get("yugi", {})
	block[0x10f5] = clampi(int(old.get("streak_last", 0)), 0, 255)
	block[0x10f6] = clampi(int(old.get("streak", 0)), 0, 255)
	var joey: Dictionary = stats.get("joey", {})
	block[0x10ef] = clampi(int(joey.get("streak_last", 0)), 0, 255)
	block[0x10f0] = clampi(int(joey.get("streak", 0)), 0, 255)
	block[0x10f1] = int(joey.get("started", joey.has("level")))
	if joey.has("level"):
		block[0x10f2] = int(joey.get("shown_level", joey["level"])) & 0xff
		block[0x10f3] = int(joey["level"]) & 0xff
	seal(block)
	return block


static func block_valid(block: PackedByteArray) -> bool:
	if block.size() != BLOCK_SIZE or block.decode_u16(0x1182) != 0xfba5:
		return false
	var total := 0
	for i in 0x8c2:
		total += block.decode_u16(i * 2)
	return block.decode_u16(0x1184) == (-total) & 0xffff


static func _pow_mod(base: int, exponent: int, modulus: int) -> int:
	var result := 1
	base %= modulus
	while exponent > 0:
		if exponent & 1:
			result = result * base % modulus
		base = base * base % modulus
		exponent >>= 1
	return result


## Bloque -> campos de SaveData. by_index: indice de carta (CARD_ID) -> id interno.
static func to_save(block: PackedByteArray, by_index: Dictionary) -> Dictionary:
	var collection := {}
	var seen := {}
	for index in range(1, CARD_SLOTS):
		if not by_index.has(index):
			continue
		var entry := block.decode_u16(0xc + index * 2)
		var key := str(int(by_index[index]))
		if entry & 0xff:
			collection[key] = entry & 0xff     # bits 8-13: mazo cargado en el editor
		if entry & 0x4000:
			seen[key] = true
	# 0x10f8: ranura 0 (DAT_005aed1c), la misma en los tres juegos
	var record := block.decode_u32(0x10f8)
	var stats := {}
	for game in ["yugi", "kaiba", "joey"]:
		var s := {"wins": record & 0x7ff, "losses": (record >> 11) & 0x7ff, "draws": record >> 22}
		var last := block[0x10ef] if game == "joey" else block[0x10f5]
		if last != 0:
			s["streak_last"] = last
			s["streak"] = block[0x10f0] if game == "joey" else block[0x10f6]
		stats[game] = s
	if block[0x10f1] != 0:
		stats["joey"]["started"] = true
		stats["joey"]["level"] = block[0x10f3]
		stats["joey"]["shown_level"] = block[0x10f2]
	var options := {}
	for game in ["yugi", "kaiba", "joey"]:
		options[game] = {"volume": mini(15, block.decode_u16(6) >> 4), "display": block.decode_u16(8)}
	options["joey"]["card_set_full"] = block[0x10f4] != 0
	options["joey"]["limited"] = block[0x10ee] != 0
	return {
		"collection": collection,
		"seen": seen,
		"stats": stats,
		"options": options,
		"native_system": {
			"block": Marshalls.raw_to_base64(block),
			"limit_flags": block.decode_u16(0x1178),
			"total_cards": block.decode_u16(0xa),
		},
	}


## Deshace los premios de la ultima partida sobre una partida ya importada: resta una copia
## por cada id interno de "cards" (sin bajar de 0; si queda en 0 deja de estar vista) y
## "wins" victorias de la ranura comun. Los mazos solo se tocan si alguno lleva mas copias
## de las que quedan: se quitan las sobrantes empezando por fusion y side, nunca del
## principal (su tamano no debe cambiar). La racha solo se puede deshacer si la partida se
## queda sin duelos o la racha de victorias era mayor que 1. Devuelve avisos.
static func undo_duel(save: Dictionary, cards: Array[int], wins: int) -> Array[String]:
	var warnings: Array[String] = []
	for id in cards:
		var key := str(id)
		var have := int(save["collection"].get(key, 0))
		if have == 0:
			warnings.append("La carta %d no esta en la coleccion" % id)
			continue
		if have == 1:
			save["collection"].erase(key)
			save["seen"].erase(key)
		else:
			save["collection"][key] = have - 1
		for game in save["decks"]:
			var deck: Dictionary = save["decks"][game]
			for zone in ["fusion", "side", "main"]:
				var used := 0
				for zid in ["main", "side", "fusion"]:
					used += deck.get(zid, []).count(id) + deck.get(zid, []).count(float(id))
				if used <= have - 1:
					break
				if zone == "main":
					warnings.append("%s: el mazo principal lleva mas copias de %d de las que quedan" % [game, id])
					break
				var zone_ids: Array = deck.get(zone, [])
				var at := zone_ids.rfind(id)
				if at < 0:
					at = zone_ids.rfind(float(id))
				if at >= 0:
					zone_ids.remove_at(at)
	if wins > 0:
		for game in save["stats"]:
			var s: Dictionary = save["stats"][game]
			s["wins"] = maxi(0, int(s["wins"]) - wins)
			if game == "joey":
				continue
			if int(s["wins"]) + int(s["losses"]) + int(s["draws"]) == 0:
				s.erase("streak")
				s.erase("streak_last")
			elif int(s.get("streak_last", 0)) == 1 and int(s.get("streak", 0)) > wins:
				s["streak"] = int(s["streak"]) - wins
			else:
				warnings.append("%s: no se puede saber la racha anterior" % game)
	return warnings


## Deck.ydc de cada juego instalado junto a la carpeta Common (se reconoce por su exe).
static func find_decks(system_dat: String) -> Dictionary:
	var found := {}
	var root := system_dat.get_base_dir().get_base_dir()
	for folder in DirAccess.get_directories_at(root):
		var files := {}
		for name in DirAccess.get_files_at(root.path_join(folder)):
			files[name.to_lower()] = root.path_join(folder).path_join(name)
		for exe in EXE_GAME:
			if files.has(exe) and files.has("deck.ydc"):
				found[EXE_GAME[exe]] = files["deck.ydc"]
	return found
