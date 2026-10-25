extends Node
## Partida guardada portable (PoC Data/saves/system.json junto al ejecutable).
## Igual que el system.dat de la carpeta "Common" del original: una sola coleccion de cartas
## compartida por los tres juegos, y un mazo activo por juego.

const FILE_NAME := "system.json"
const VERSION := 2
const GAMES := ["yugi", "kaiba", "joey"]
const Store = preload("res://core/save_store.gd")

var data := {}
var persistence_error := ""
var _startup_checked: Dictionary = {}


func _ready() -> void:
	if not Paths.has_data() or Paths.storage_error:
		return # No crear una partida vacia antes de importar las cartas y mazos.
	load_or_create()
	var imported := Paths.cmdline_value("import-system-dat")
	if imported != "":
		if import_system_dat(imported):
			_undo_last_duel()
		else:
			push_error("No se pudo importar %s" % imported)
	if "--unlock-all" in OS.get_cmdline_user_args():
		unlock_all()
	var exported := Paths.cmdline_value("export-system-dat")
	if exported != "":
		var key := Paths.cmdline_value("system-dat-key")
		var header_key := -1 if key == "" else (key.hex_to_int() if key.begins_with("0x") else key.to_int())
		if not export_system_dat(exported, Paths.cmdline_value("start"), header_key):
			push_error("No se pudo exportar %s (cabecera importada o --system-dat-key requerida)" % exported)


func path() -> String:
	return Paths.save_dir.path_join(FILE_NAME)


func load_or_create() -> void:
	_startup_checked.clear()
	var loaded := Store.load_save(path())
	persistence_error = loaded["error"]
	if persistence_error != "":
		push_error(persistence_error)
		data = _new_game()
		return # No sobrescribir una partida incompatible o que no se pudo preservar.
	var parsed: Variant = loaded["data"]
	if parsed is Dictionary:
		data = parsed
		data.get_or_add("seen", {})
		var migrated := int(data.get("version", 0)) == 1
		if migrated:
			_migrate_shared_stats()
			data["version"] = VERSION
		if loaded["recovered"]:
			push_warning("Partida recuperada desde %s.bak; archivos danados conservados como .damaged" % path())
		if migrated or loaded["recovered"]:
			save()
		return
	if FileAccess.file_exists(path()) or FileAccess.file_exists(path() + ".bak"):
		push_warning("Sin partida valida; se crea una nueva tras conservar los archivos danados como .damaged: %s" % path())
	data = _new_game()
	save()


func save() -> bool:
	if persistence_error != "":
		return false
	var err := Store.write_save(path(), data)
	if err != OK:
		push_error("No se pudo guardar %s: %s" % [path(), error_string(err)])
		return false
	return true


## Coleccion compartida: id interno (como texto, por JSON) -> copias.
func card_count(internal_id: int) -> int:
	return int(data["collection"].get(str(internal_id), 0))


func add_card(internal_id: int, copies := 1) -> void:
	data.erase("starter_pending")
	var key := str(internal_id)
	data["collection"][key] = card_count(internal_id) + copies


## Cartas ya vistas en la lista: las que se tienen y no se han visto llevan el "NEW".
func is_seen(internal_id: int) -> bool:
	return data["seen"].has(str(internal_id))

## 442900: flcrc se conserva por coleccion; al crearlo usa time32, no una clave RNG.
## 436ce0(0) exporta esta cabecera, y436bf0/442750 la comprueban al importar.
func deck_file_header() -> PackedByteArray:
	var imported := Marshalls.base64_to_raw(str(data.get("native_system", {}).get("header", "")))
	if imported.size() == 8: return imported
	var head := Marshalls.base64_to_raw(str(data.get("deck_header", "")))
	if head.size() != 8:
		head.resize(8)
		head.encode_u32(0, 1)
		head.encode_u32(4, int(Time.get_unix_time_from_system()) & 0xffffffff)
		data["deck_header"] = Marshalls.raw_to_base64(head)
		save()
	return head


func mark_seen(internal_id: int) -> void:
	data["seen"][str(internal_id)] = true


## Equivalente al parche "Desbloquear todas las cartas": 3 copias de cada carta con arte.
func unlock_all() -> void:
	data.erase("starter_pending")
	for card in CardDB.cards:
		if card["image"] != null and int(card["pack"]) != 0:
			var key := str(int(card["internal_id"]))
			data["collection"][key] = maxi(3, card_count(int(card["internal_id"])))
	save()


## Sustituye la partida por la del original: system.dat (coleccion, vistas, estadisticas,
## progreso de Joey y opciones) y el Deck.ydc de cada juego instalado junto a la carpeta
## Common; si falta uno, el mazo inicial. Yugi y Kaiba lo validan como al arrancar
## (_startup_decks). Conserva las preferencias propias del port (launcher, settings).
## Solo lee los archivos del original.
func import_system_dat(system_dat: String) -> bool:
	var raw := FileAccess.get_file_as_bytes(system_dat)
	var block := SystemDat.decode(raw)
	if block.is_empty():
		return false
	var by_index := {}
	for card in CardDB.cards:
		by_index[int(card["index"])] = int(card["internal_id"])
	var head := SystemDat.header(raw)
	var startup := _startup_decks(block, head, SystemDat.find_decks(system_dat))
	block = startup["block"]
	var fresh := _new_game()
	fresh.merge(SystemDat.to_save(block, by_index), true)
	fresh.erase("starter_pending")
	fresh["native_system"]["header"] = Marshalls.raw_to_base64(head)
	for game in startup["decks"]:
		fresh["decks"][game] = startup["decks"][game]
	for key in ["launcher", "settings"]:
		if data.has(key):
			fresh[key] = data[key]
	data = fresh
	_startup_checked.clear()
	return save()


## Carga de Deck.ydc al arrancar (Yugi 436e80 -> 436db0 -> 436bf0; Kaiba 437430, mismas
## rutinas desplazadas). Si el archivo no se lee, su cabecera no es la del system.dat
## (442750 -> 10), 540450 quita alguna carta (fuera de la mascara del juego, ilegal o sin
## copias; -> 0xb) o el principal no esta en 40..80, o fusion o side pasan de 15, se usa el
## mazo inicial: 53f8b0 (que sube las copias de la coleccion y las marca vistas) y 540450.
## Se ejecutan las rutinas portadas sobre la memoria modelada con el bloque importado; la
## coleccion resultante vuelve al bloque. 436ce0 reescribiria Deck.ydc: el port guarda el
## mazo en su partida y no toca los archivos del original.
## Joey (44aa00) no se valida aqui: ante 0xb o tamanos fuera de rango conserva el mazo ya
## podado por su 5bea80, que usa su propia lista de limites (5be190), y el Deck.ydc de Joey
## instalado no lleva la cabecera del system.dat (la compara 45cd20 con su propio objeto);
## f540450 no lo reproduce.
## Devuelve {block, decks}: el bloque (actualizado si cambio) y el mazo de cada juego.
## El motor de Yugi se carga al validar mazos: tiparlo aquí lo compilaba entero (cientos de
## milisegundos en PC, varios segundos en Android) antes de mostrar el launcher.
static func _duel_script() -> Script:
	return load("res://duel/core/duel.gd")


func _startup_decks(block: PackedByteArray, head: PackedByteArray, paths: Dictionary) -> Dictionary:
	var decks := {}
	var duel: Object = null
	if paths.has("yugi") or paths.has("kaiba"):
		duel = _duel_script().create(Paths.data_dir)
		if duel == null:
			push_warning("Sin imagen del motor de duelo: Deck.ydc se importa sin validar")
		else:
			for i in block.size():
				duel.m.set_u8(0xa10120 + i, block[i])
	for game in GAMES:
		if not paths.has(game):
			continue
		var loaded := Ydc.load(paths[game])
		if game == "joey" or duel == null:
			if not loaded.is_empty():
				decks[game] = loaded
			continue
		var deck_head := Ydc.header(paths[game])
		var header_matches := deck_head.size() == 8 and head.size() == 8 \
				and deck_head[0] == head[0] and deck_head.decode_u32(4) == head.decode_u32(4)
		decks[game] = _resolve_startup_deck(duel, game, loaded, header_matches)
	if duel != null:
		var updated := block.duplicate()
		for index in range(1, SystemDat.CARD_SLOTS):
			var at := 0xc + index * 2
			# bits 8-13 (copias en el mazo) se quedan como se importaron
			updated.encode_u16(at, (duel.m.u16(0xa10120 + at) & 0xc0ff) | (block.decode_u16(at) & 0x3f00))
		updated.encode_u16(0xa, duel.m.u16(0xa1012a))
		if updated != block:
			SystemDat.seal(updated)
			block = updated
	return {"block": block, "decks": decks}


## El mismo arranque de 436e80/437430 para importaciones y partidas del port.
func _resolve_startup_deck(duel: Object, game: String, loaded: Dictionary, header_matches := true) -> Dictionary:
	var game_index := GAMES.find(game)
	var ok: bool = header_matches and not loaded.is_empty() and loaded.get("main", []).size() >= 40 \
		and loaded.get("main", []).size() <= 80 and loaded.get("fusion", []).size() <= 15 \
		and loaded.get("side", []).size() <= 15
	if ok:
		_write_startup_deck(duel, loaded)
		ok = duel.f540450(game_index) == 0
	if ok:
		return loaded
	if game == "yugi":
		duel.f53f8b0()
	else:
		_kaiba_starter(duel, Assets.read_json("kaiba/file/starter_deck.json"))
	duel.f540450(game_index)
	return _read_startup_deck(duel)


## Se conserva el mazo personalizado antes de que el arranque nativo lo sustituya.
func _preserve_startup_deck(game: String, deck_data: Dictionary, reason := "native_startup_fallback") -> bool:
	var payload := JSON.stringify({"game": game, "reason": reason, "deck": deck_data}, "\t")
	var directory := Paths.save_dir.path_join("recovered-decks")
	var destination := directory.path_join("%s-%s.json" % [game, payload.sha256_text()])
	if FileAccess.file_exists(destination):
		return FileAccess.get_file_as_string(destination) == payload
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return false
	var file := FileAccess.open(destination + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(payload)
	var result := file.get_error()
	file.close()
	if result != OK or FileAccess.get_file_as_string(destination + ".tmp") != payload:
		return false
	return DirAccess.rename_absolute(destination + ".tmp", destination) == OK


## Validar una vez por juego y sesion; abrir otra pantalla no vuelve a regalar cartas.
func _ensure_startup_deck(game: String) -> bool:
	if _startup_checked.has(game) or game not in GAMES or persistence_error != "":
		return false
	var by_index := {}
	for card: Dictionary in CardDB.cards:
		by_index[int(card["index"])] = int(card["internal_id"])
	# El mazo se valida aparte: sus contadores pueden ser precisamente los invalidos.
	var source := data.duplicate()
	source["decks"] = {}
	var block := SystemDat.from_save(source, by_index, game)
	if block.is_empty():
		push_warning("No se pudo proyectar la coleccion para validar el mazo de " + game)
		return false
	if game == "joey":
		# 44aa00: ante 0xb se conserva la poda; no se concede el mazo inicial.
		var native: Dictionary = data.get("native_system", {}).duplicate()
		native["block"] = Marshalls.raw_to_base64(block)
		var previous: Dictionary = data.decks[game]
		var result: Dictionary = preload("res://core/native_deck_startup.gd").resolve_joey(previous, data.collection, native)
		if result.deck == previous:
			_startup_checked[game] = true
			return false
		if not _preserve_startup_deck(game, previous, "native_startup_prune"):
			persistence_error = "No se pudo preservar el mazo anterior de " + game
			push_error(persistence_error)
			return false
		data["decks"][game] = result.deck
		_startup_checked[game] = true
		return true
	var duel: Object = _duel_script().create(Paths.data_dir)
	if duel == null:
		push_warning("Sin imagen nativa para validar el mazo de " + game)
		return false
	for i in block.size():
		duel.m.set_u8(0xa10120 + i, block[i])
	var previous: Dictionary = data.decks[game]
	var resolved := _resolve_startup_deck(duel, game, previous)
	for i in block.size():
		block[i] = duel.m.u8(0xa10120 + i)
	SystemDat.seal(block)
	var projected := SystemDat.to_save(block, by_index)
	if resolved == previous and projected.collection == data.collection and projected.seen == data.get("seen", {}):
		_startup_checked[game] = true
		return false
	if resolved != previous and not _preserve_startup_deck(game, previous):
		persistence_error = "No se pudo preservar el mazo anterior de " + game
		push_error(persistence_error)
		return false
	data["collection"] = projected.collection
	data["seen"] = projected.seen
	data["decks"][game] = resolved
	var native: Dictionary = data.get_or_add("native_system", {})
	native.merge(projected.native_system, true)
	_startup_checked[game] = true
	return true


## 436900: lee las tres listas en 0xa112c0 (principal +0x00, side +0xa0, fusion +0xbe;
## contadores +0xdc, +0xde, +0xe0) como indices de carta (401ad0) y rellena con ceros.
func _write_startup_deck(duel: Object, deck_data: Dictionary) -> void:
	for zone in [["main", 0x00, 0xdc, 80], ["side", 0xa0, 0xde, 15], ["fusion", 0xbe, 0xe0, 15]]:
		var ids: Array = deck_data[zone[0]]
		duel.m.set_u16(0xa112c0 + int(zone[2]), ids.size())
		for i in int(zone[3]):
			duel.m.set_u16(0xa112c0 + int(zone[1]) + i * 2, duel.f401ad0(int(ids[i])) if i < ids.size() else 0)


func _read_startup_deck(duel: Object) -> Dictionary:
	var result := {}
	for zone in [["main", 0x00, 0xdc], ["side", 0xa0, 0xde], ["fusion", 0xbe, 0xe0]]:
		var ids: Array = []
		for i in duel.m.u16(0xa112c0 + int(zone[2])):
			ids.append(duel.f401a70(duel.m.u16(0xa112c0 + int(zone[1]) + i * 2)))
		result[zone[0]] = ids
	return result


## Kaiba 541f80: el mismo bucle que 53f8b0 sobre su tabla 0x5a1030, que no esta en la imagen
## modelada (la de Yugi); el mazo inicial del port ocupa su lugar.
func _kaiba_starter(duel: Object, starter: Dictionary) -> void:
	for count_addr in [0xa1139e, 0xa113a0, 0xa1139c]:
		duel.m.set_u16(count_addr, 0)
	for zone in [["main", 0xa112c0, 0xa1139c], ["fusion", 0xa1137e, 0xa113a0]]:
		for id in starter.get(zone[0], []):
			var index: int = duel.f401ad0(int(id))
			var count: int = duel.m.u16(int(zone[2]))
			duel.m.set_u16(int(zone[1]) + count * 2, index)
			duel.m.set_u16(int(zone[2]), count + 1)
			duel.f540270(index, duel.f53f860(index))
			var at := 0xa1012c + index * 2
			duel.m.set_u16(at, duel.m.u16(at) | 0x4000)


## system.dat solo guarda el estado posterior a la ultima partida. Para reproducir una traza
## del original hace falta el de antes: --import-minus-card=id[,id...] quita esos premios
## (ids internos) y --import-minus-win resta la victoria (SystemDat.undo_duel).
func _undo_last_duel() -> void:
	var ids: Array[int] = []
	for part in Paths.cmdline_value("import-minus-card").split(",", false):
		ids.append(part.to_int())
	var wins := int("--import-minus-win" in OS.get_cmdline_user_args())
	if ids.is_empty() and wins == 0:
		return
	for warning in SystemDat.undo_duel(data, ids, wins):
		push_warning(warning)
	save()


func deck(game: String) -> Dictionary:
	ensure_game(game)
	return data["decks"][game]


func set_deck(game: String, deck_data: Dictionary) -> void:
	data["decks"][game] = deck_data


func _new_game(initial_game := "") -> Dictionary:
	var fresh := {"version": VERSION, "collection": {}, "decks": {}, "stats": {}, "seen": {}}
	for game in GAMES:
		fresh["stats"][game] = {"wins": 0, "losses": 0, "draws": 0}
	# En el primer inicio del launcher todos los mazos deben poder jugarse.
	# initial_game permite modelar por separado un arranque del original.
	for game in GAMES:
		var starter: Variant = Assets.read_json("%s/file/starter_deck.json" % game)
		if starter == null:
			continue
		fresh["decks"][game] = starter
		fresh["stats"][game] = {"wins": 0, "losses": 0, "draws": 0}
		if initial_game != "" and game != initial_game:
			continue
		for part in ["main", "fusion", "side"]:
			for id in starter[part]:
				var key := str(int(id))
				fresh["collection"][key] = maxi(int(fresh["collection"].get(key, 0)),
						_copies_in(starter, int(id)))
	# las cartas iniciales no cuentan como nuevas
	for key in fresh["collection"]:
		fresh["seen"][key] = true
	return fresh


## Reinicio explicito desde el launcher; el estado anterior queda fuera de saves/.
func reset_game() -> Dictionary:
	if Paths.storage_error or not Paths.has_data():
		return {"error": "No hay recursos o almacenamiento disponible.", "backup": ""}
	var result := preload("res://core/game_reset.gd").reset(Paths.save_dir, Paths.settings_path(), _new_game())
	if result.error == "":
		data = result.data
		persistence_error = ""
		_startup_checked.clear()
	return result


func ensure_game(game: String, validate_startup := true) -> void:
	if game not in GAMES or not Paths.has_game(game):
		return
	var changed := false
	var decks: Dictionary = data.get_or_add("decks", {})
	var stats: Dictionary = data.get_or_add("stats", {})
	if not decks.has(game):
		var starter: Variant = Assets.read_json("%s/file/starter_deck.json" % game)
		if starter == null:
			return
		decks[game] = starter
		changed = true
		if game == "joey":
			# 44aa00 ->5bdc50: archivo ausente, distinto de un mazo existente podado.
			var initial := _new_game("joey")
			for key: String in initial.collection:
				data.collection[key] = maxi(int(data.collection.get(key, 0)), int(initial.collection[key]))
				data.get_or_add("seen", {})[key] = true
	for key in GAMES:
		stats.get_or_add(key, {"wins": 0, "losses": 0, "draws": 0})
	if data.get("starter_pending", false):
		var fresh := _new_game(game)
		data["collection"] = fresh["collection"]
		data["seen"] = fresh["seen"]
		data.erase("starter_pending")
		changed = true
	var joey: Dictionary = stats.get_or_add("joey", {})
	if game == "joey" and not joey.get("started", joey.has("level")):
		var previous := false
		for key in data["collection"]:
			var card := CardDB.by_id(int(key))
			if int(data["collection"][key]) > 0 and (int(card.get("pack", 0)) & 3) != 0 \
					and (int(card.get("pack", 0)) & 4) == 0:
				previous = true
				break
		var options: Dictionary = data.get_or_add("options", {})
		var own: Dictionary = options.get_or_add("joey", {})
		# 5bee30 calcula db2/db3 con db4 (cartas anteriores) ANTES de recalcularlo con 5bedd0:
		# en una partida nueva aún vale 0 y el nivel empieza en 1. Escribe un byte; los
		# consumidores 489784/44bc15 lo extienden sin signo.
		joey["level"] = (1 - 2 * int(bool(own.get("card_set_full", false)))) & 0xff
		joey["shown_level"] = joey["level"]
		joey["started"] = true
		own["card_set_full"] = previous
		own["limited"] = false
		changed = true
	if game == "joey" and int(joey.get("level", 1)) == 0xff and not joey.get("level_start_checked", false):
		# Hasta alpha.22 el port calculaba el nivel inicial con db4 ya recalculado: quien tenía
		# cartas de Yugi/Kaiba empezaba en 0xff, nivel que ni sube ni baja. Se lleva una vez
		# al nivel 1 con el que empieza el original.
		joey["level"] = 1
		joey["shown_level"] = 1
		joey["level_start_checked"] = true
		changed = true
	if validate_startup:
		changed = _ensure_startup_deck(game) or changed
	if changed:
		save()


## Conserva la ranura comun del original. Version 1 separaba totales por juego:
## se suman partidas propias; si hubo importacion, la base duplicada se cuenta una vez.
func _migrate_shared_stats() -> void:
	var stats: Dictionary = data.get_or_add("stats", {})
	var native: Dictionary = data.get("native_system", {})
	var block := Marshalls.base64_to_raw(str(native.get("block", "")))
	var imported := block.decode_u32(0x10f8) if block.size() == SystemDat.BLOCK_SIZE else 0
	for pair in [["wins", 0x7ff, imported & 0x7ff], ["losses", 0x7ff, (imported >> 11) & 0x7ff], ["draws", 0x3ff, imported >> 22]]:
		var total := int(pair[2])
		for game in GAMES:
			var row: Dictionary = stats.get_or_add(game, {})
			total += maxi(0, int(row.get(pair[0], 0)) - int(pair[2]))
		for game in GAMES:
			stats[game][pair[0]] = mini(int(pair[1]), total)


## 5406f0/540720/540760: todos los juegos actualizan la misma ranura +10f8.
func record_result(game: String, result: int) -> Dictionary:
	ensure_game(game)
	var stats: Dictionary = data["stats"][game]
	var key := {1: "wins", 2: "losses", 3: "draws"}.get(result, "") as String
	if key != "":
		var count := mini(0x3ff if result == 3 else 0x7ff, int(stats.get(key, 0)) + 1)
		for id in GAMES:
			data["stats"][id][key] = count
	return stats


func native_option_byte(offset: int) -> int:
	var block := Marshalls.base64_to_raw(str(data.get("native_system", {}).get("block", "")))
	return block[offset] if offset >= 0 and offset < block.size() else 0

func set_native_option_byte(offset: int, value: int) -> void:
	if offset < 0 or offset >= SystemDat.BLOCK_SIZE:
		return
	var native: Dictionary = data.get_or_add("native_system", {})
	var block := Marshalls.base64_to_raw(str(native.get("block", "")))
	if block.size() != SystemDat.BLOCK_SIZE:
		block.resize(SystemDat.BLOCK_SIZE)
		for i in 8:
			block[0x117a + i] = "YUGIOH01".unicode_at(i)
	block[offset] = value & 0xff
	SystemDat.seal(block)
	native["block"] = Marshalls.raw_to_base64(block)


## Exporta en ruta explicita. La cabecera requiere el flcrc de la instalacion original;
## se conserva al importar o se aporta como --system-dat-key, nunca se inventa.
func export_system_dat(destination: String, game := "", header_key := -1) -> bool:
	if game not in GAMES:
		game = "yugi"
	# Exportar es serializar, no arrancar el juego ni sustituir el mazo del usuario.
	ensure_game(game, false)
	var head := Marshalls.base64_to_raw(str(data.get("native_system", {}).get("header", "")))
	if header_key >= 0:
		head.resize(8)
		head[0] = 1
		head.encode_u32(4, header_key & 0xffffffff)
	if head.size() != 8:
		return false
	var by_index := {}
	for card in CardDB.cards:
		by_index[int(card["index"])] = int(card["internal_id"])
	var block := SystemDat.from_save(data, by_index, game)
	var raw := SystemDat.encode(block, head)
	if raw.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var file := FileAccess.open(destination + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(raw)
	file.close()
	return DirAccess.rename_absolute(destination + ".tmp", destination) == OK


static func _copies_in(deck_data: Dictionary, id: int) -> int:
	var n := 0
	for part in ["main", "fusion", "side"]:
		for x in deck_data[part]:
			if int(x) == id:
				n += 1
	return n
