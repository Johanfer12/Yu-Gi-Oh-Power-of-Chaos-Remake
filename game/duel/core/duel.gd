class_name Duel
extends DuelCmds
## Motor de duelo: preparacion de la partida y ejecucion de comandos.
##
## Uso para reproducir una repeticion:
##     var duel := Duel.create(data_dir)
##     duel.start_replay(Ydr.load_file(ruta))
##     duel.run_until_idle()

const IMAGE_FILE := "common/duel/yugi_image.bin"

## DAT_005af770 / DAT_005af774: opciones y semilla de la partida (cabecera del .ydr).
var options := 0
var seed := 0


## Carga tablas de cartas e imagen de datos. Devuelve null si falta algo en data/.
static func create(data_dir: String, game_id: String = "yugi") -> Duel:
	if game_id not in ["yugi", "kaiba", "joey"]:
		push_error("Version de duelo desconocida: " + game_id)
		return null
	if game_id == "joey":
		return load("res://scenes/duel/joey_presentation_adapter.gd").create_native(data_dir)
	var tables := CardTables.new()
	if not tables.load_from(data_dir):
		return null
	var image_path := data_dir.path_join("common/duel/kaiba_image.bin") if game_id == "kaiba" else data_dir.path_join(IMAGE_FILE)
	if not FileAccess.file_exists(image_path):
		image_path = data_dir.path_join(IMAGE_FILE)
		if not FileAccess.file_exists(image_path):
			image_path = data_dir.path_join("common/duel/kaiba_image.bin")
	var image := FileAccess.get_file_as_bytes(image_path)
	if image.is_empty():
		return null
	var duel := Duel.new(tables)
	duel.rules_game = game_id
	duel.native_version = 100
	if not duel.m.load_image(image):
		return null
	return duel


## Prepara una repeticion como el original (0x4371a0 -> 0x4388b0): mazos, opciones y semilla
## de la cabecera, modo repeticion y barajado inicial.
func start_replay(replay: Ydr) -> void:
	game_mode = GAME_REPLAY
	native_version = replay.duel_version
	options = replay.options
	seed = replay.seed
	for p in 2:
		_load_deck(p, replay.decks[p])
	_incoming = replay.commands.duplicate()
	_incoming_pos = 0
	f5418a0(options, seed)


## Prepara una partida normal con los mismos mazos, opciones y semilla que el original.
## Todavia requiere completar las rutinas de efectos y decisiones marcadas sin portar.
## Duelo en red (D17, juego 3 de 5418a0): como start_normal, con el bit 8 de a16180 puesto por
## 539a60 y `transport` como `net`. Los dos lados usan la misma semilla (f005 de la sala) y se
## ven a si mismos como jugador 0; `decks[1]` es el mazo que mando el rival con f004.
func start_network(decks: Array[Dictionary], opts: int, rand_seed: int, transport: Object) -> void:
	net = transport
	start_normal(decks, opts, rand_seed, GAME_NETWORK)


func start_normal(decks: Array[Dictionary], opts: int, rand_seed: int, mode := GAME_NORMAL) -> void:
	assert(decks.size() == 2, "La partida necesita dos mazos")
	game_mode = mode
	native_version = 100
	options = opts
	seed = rand_seed
	_incoming.clear()
	_incoming_pos = 0
	recorded.clear()
	events.clear()
	headless_detached.clear()
	mismatches.clear()
	unported_calls.clear()
	ui_pending.clear()
	_ui_answer = -1
	dialog_open = {}
	list_open = {}
	executed = 0
	for p in 2:
		_load_deck(p, decks[p])
	f5418a0(options, seed)


## Escenario de prueba (herramienta de desarrollo, no existe en el original): se aplica justo
## despues de start_normal(), antes del reparto. `hands[p]` son ids de carta que se suben al
## tope del mazo ya barajado en orden de robo (las cinco primeras forman la mano inicial y la
## sexta es el primer robo). `field[p]` son {"card": id, "zone": z, "c": c} que se colocan
## con el comando 0xf4 de los guiones de tutorial (FUN_00403760, sin grabarlo): zona 0-4
## monstruo con posicion c % 10 (0 ataque, 1 defensa) y boca abajo si c >= 10; zona 5-9
## magia/trampa boca abajo si c != 0; 10 magia de campo. Devuelve los avisos (cartas que no
## estaban en el mazo, etc.).
func apply_scenario(scenario: Dictionary) -> PackedStringArray:
	var warnings: PackedStringArray = []
	var hands: Array = scenario.get("hands", [])
	for p in mini(hands.size(), 2):
		var deck := DuelMem.pl(p) + DuelMem.P_DECK
		var count := m.u8(DuelMem.pl(p) + DuelMem.P_DECK_N)
		var top := 0
		for wanted in hands[p]:
			var found := -1
			for k in range(top, count):
				if cards.id_of(m.u16(deck + k * 4) & 0xfff) == int(wanted):
					found = k
					break
			if found < 0:
				warnings.append("jugador %d: la carta 0x%x no esta en el mazo" % [p, int(wanted)])
				continue
			var a := m.u32(deck + top * 4)
			m.set_u32(deck + top * 4, m.u32(deck + found * 4))
			m.set_u32(deck + found * 4, a)
			top += 1
		# Reservar las cartas del cementerio al fondo antes del reparto. Si la mano no esta
		# fijada, el robo aleatorio podia consumirlas y dejar incompleto el escenario.
		var grave: Array = scenario.get("grave", [])
		var reserved := 0
		if p < grave.size():
			for wanted in grave[p]:
				for k in range(top, count - reserved):
					if cards.id_of(m.u16(deck + k * 4) & 0xfff) != int(wanted): continue
					var end := count - 1 - reserved
					var value := m.u32(deck + end * 4)
					m.set_u32(deck + end * 4, m.u32(deck + k * 4))
					m.set_u32(deck + k * 4, value)
					reserved += 1
					break
	# El reparto empieza con el comando 0x10, que vacia el campo: las cartas se colocan cuando
	# el reparto ha terminado (ver frame()).
	_scenario_field.clear()
	# `grave[p]`: cartas del mazo que van al cementerio tras el reparto con el comando 0x67
	# (FUN_00549550), que busca la entrada por su valor (ver _place_scenario_field).
	_scenario_grave.clear()
	var graves: Array = scenario.get("grave", [])
	for p in mini(graves.size(), 2):
		for wanted in graves[p]:
			_scenario_grave.append(PackedInt32Array([p, int(wanted)]))
	_scenario_lp = scenario.get("lp", []).duplicate()
	var field: Array = scenario.get("field", [])
	for p in mini(field.size(), 2):
		for entry: Dictionary in field[p]:
			_scenario_field.append(PackedInt32Array([(p << 15) | 0xf4, int(entry.get("zone", 0)), int(entry["card"]), int(entry.get("c", 0))]))
	return warnings


## Comandos 0xf4 del escenario pendientes de colocar tras el reparto.
var _scenario_field: Array[PackedInt32Array] = []
## LP del escenario que se fijan tras el reparto (el comando 0x10 los pone a 8000).
var _scenario_lp: Array = []
## Cartas [jugador, id] del escenario que pasan del mazo al cementerio tras el reparto.
var _scenario_grave: Array[PackedInt32Array] = []


## Coloca el campo del escenario en cuanto el reparto ha terminado (estado del turno >= 2,
## cola vacia y ningun comando en curso). Los comandos se ejecutan en el flujo normal.
func _place_scenario_field() -> void:
	if (_scenario_field.is_empty() and _scenario_grave.is_empty() and _scenario_lp.is_empty()) or m.u8(0xa16180) < 2 or is_running() or m.u16(DuelMem.QUEUE_COUNT) != 0:
		return
	for p in mini(_scenario_lp.size(), 2):
		m.set_u16(DuelMem.pl(p), clampi(int(_scenario_lp[p]), 1, 0xffff))
	_scenario_lp.clear()
	var used := {}
	for g in _scenario_grave:
		var p := g[0]
		var deck := DuelMem.pl(p) + DuelMem.P_DECK
		var found := -1
		for k in m.u8(DuelMem.pl(p) + DuelMem.P_DECK_N):
			if not used.has(p * 256 + k) and cards.id_of(m.u16(deck + k * 4) & 0xfff) == g[1]:
				found = k
				break
		if found < 0:
			push_warning("Escenario: jugador %d: la carta 0x%x no esta en el mazo" % [p, g[1]])
			continue
		used[p * 256 + found] = true
		var entry := m.u32(deck + found * 4)
		# El comando lleva el id de la carta en los 12 bits bajos (el manejador lo pasa a indice).
		enqueue((p << 15) | 0x67, (entry & 0xf000) | (f401a70(entry & 0xfff) & 0xfff), (entry >> 16) & 0xffff, 0)
	_scenario_grave.clear()
	for c in _scenario_field:
		enqueue(c[0], c[1], c[2], c[3])
	_scenario_field.clear()


## FUN_00436900 (lectura): ids del archivo -> indices en 0xa112c0, rellenando con ceros.
func _load_deck(p: int, deck: Dictionary) -> void:
	var at := DuelMem.DECKS + p * DuelMem.DECK_SIZE
	m.clear(at, DuelMem.DECK_SIZE)
	var main: PackedInt32Array = deck["main"]
	var fusion: PackedInt32Array = deck["fusion"]
	var side: PackedInt32Array = deck["side"]
	m.set_u16(at + 0xdc, main.size())
	for i in mini(main.size(), 80):
		m.set_u16(at + i * 2, cards.index_of(main[i]))
	m.set_u16(at + 0xe0, fusion.size())
	for i in mini(fusion.size(), 15):
		m.set_u16(at + 0xbe + i * 2, cards.index_of(fusion[i]))
	m.set_u16(at + 0xde, side.size())
	for i in mini(side.size(), 15):
		m.set_u16(at + 0xa0 + i * 2, cards.index_of(side[i]))


## FUN_005418a0: empieza el duelo.
func f5418a0(opts: int, rand_seed: int) -> int:
	m.clear(0xa114a0, 0x18)
	rng.srand(rand_seed)
	f541850(opts)
	match game_mode:
		0, 1, 3:
			m.set_u32(0xa114b4, m.u32(0xa114b4) & 0xffffcfff)
		4:
			m.set_u32(0xa114b4, (m.u32(0xa114b4) & 0xffffdfff) | 0x1000)
		5, 6:
			m.set_u32(0xa114b4, m.u32(0xa114b4) | 0x3000)
	f539a60()
	return 0


## FUN_00541850
func f541850(opts: int) -> int:
	m.clear(0xa114a0, 0x18)
	f53b6f0()
	m.set_u32(0xa114b0, m.u32(0xa114b0) ^ ((m.u32(0xa114b0) ^ opts) & 1))
	f53db10(0)
	return 0


## FUN_0053b6f0: limpia el estado del duelo.
func f53b6f0() -> int:
	_animation_request.clear()
	m.clear(0xa16180, 8)
	m.clear(0xa11940, 0x1af8)
	m.clear(0xa161a0, 0x34)
	m.clear(0xa11620, 0x308)
	m.clear(0xa16178, 6)
	m.clear(0xa14f20, 0x814)
	m.clear(0xa15be0, 0x14)
	m.clear(0xa15c00, 0x574)
	m.clear(0xa15740, 0x490)
	m.clear(0xa114c0, 0x150)
	return 0


## FUN_0053db10: tabla de estados del turno (0x5aa704 normal, 0x5aa730 con el bit 9).
func f53db10(kind: int) -> int:
	if kind != 1:
		m.set_u32(0xa0faf8, 0x5aa704)
		m.set_u32(0xa114b4, (m.u32(0xa114b4) & 0xfffff1ff) | ((kind & 3) << 10))
		return 0
	m.set_u32(0xa114b4, m.u32(0xa114b4) | 0x200)
	m.set_u32(0xa0faf8, 0x5aa730)
	return 0


## FUN_00539a60: carga y baraja los mazos (primero el del jugador que empieza).
func f539a60() -> int:
	var network := 1 if game_mode == GAME_NETWORK else 0
	m.set_u16(0xa16180, m.u16(0xa16180) ^ (((network << 8) ^ m.u16(0xa16180)) & 0x100))
	var first := m.u32(0xa114b0) & 1
	f542b50(first)
	f5426d0(first, 8)
	f542b50(1 - first)
	f5426d0(1 - first, 8)
	return 0


## Estados 0 y 1 del turno en modo repeticion (FUN_0053d970 y FUN_0053b790): fija el jugador
## del turno y pide el primer comando de la repeticion.
func begin_replay_flow() -> void:
	if f53d970() == 0:
		return
	m.set_u8(0xa16180, 1)
	# 53b790 / Kaiba53de80 devuelve 0 y fija estado8 si empieza la CPU.
	# Reutilizar los manejadores conserva esa rama y el consumo de la cola.
	if f53b790() != 0:
		m.set_u8(0xa16180, 2)


## Ejecuta fotogramas (la parte de reglas de FUN_0053dbf0) hasta que no queda nada en la cola
## ni en la repeticion. `max_frames` evita bucles infinitos si un manejador no termina.
func run_until_idle(max_frames := 1000000) -> bool:
	for i in max_frames:
		if not frame():
			return unported_calls.is_empty()
	return false


## Un fotograma del duelo: ejecuta comandos y, como el original, comprueba la victoria en
## cada fotograma (FUN_0053d730(0), que tambien fija banderas). Devuelve true si hay trabajo.
func frame() -> bool:
	if game_mode == GAME_NORMAL or game_mode == GAME_NETWORK:
		# Una rutina pendiente no puede simularse como exito en una partida interactiva.
		if not unported_calls.is_empty():
			return false
		_place_scenario_field()
		return f53dbf0() == 0
	var busy := exec_commands()
	f53d730(0)
	return busy


## Comprobacion de victoria (FUN_0053d730 con param 1): 0 sin decidir, 1 gana el jugador 0,
## 2 gana el jugador 1, 3 empate; es lo que el estado 9 emite como argumento del comando 0x04
## (menos uno).
func winner() -> int:
	f53d730(1)
	return (m.u16(0xa133f2) & 0x60) >> 5
