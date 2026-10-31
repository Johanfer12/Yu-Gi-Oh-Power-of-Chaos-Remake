class_name JoeyPresentationAdapter
extends Duel
## Adaptador de la presentación portada. JoeyEngine es el único propietario de las
## reglas. `m` es una copia de lectura con el formato que usa la mesa existente;
## jamás se copia de vuelta al motor. Las únicas escrituras entrantes son controles.

## 449d50 recibe el comando ya serializado, tanto del emisor local como del
## receptor LAN. El archivo observa ese límite; no interviene en reglas ni colas.
class NativeSessionEngine extends JoeyReplayEngine:
	var recording_owner: WeakRef
	func configure_replay(replay: Ydr, mode := 4) -> void:
		replay_commands = replay.commands.duplicate()
		replay_position = 0
		replay_active = true
		network_transport = null
		events.clear()
		recorded.clear()
		unported_calls.clear()
		m.set_u32(VERSION, replay.duel_version)
		m.set_u32(GAME_KIND, mode)
		# El archivo ordena mazos por jugador absoluto; 569380 consume local/rival.
		for p in 2:
			var at := 0xa54e60 + p * 0xe2
			m.clear(at, 0xe2)
			for row in [["main", 0, 0xdc, 80], ["side", 0xa0, 0xde, 15], ["fusion", 0xbe, 0xe0, 15]]:
				var ids: Variant = replay.decks[p ^ replay.local_player].get(row[0], [])
				assert(ids.size() <= int(row[3]))
				for i in ids.size(): m.set_u16(at + int(row[1]) + i * 2, f402460(int(ids[i])))
				m.set_u16(at + int(row[2]), ids.size())
		f5bfeb0(replay.local_player, replay.options & 1, replay.seed)

	func f5bde30(out: int, source: int) -> int:
		var result := super.f5bde30(out, source)
		events[-1]["native_text"] = {"out": out, "source": source}
		return result

	func f5bde70(out: int, source: int) -> int:
		var result := super.f5bde70(out, source)
		events[-1]["native_text"] = {"out": out, "source": source}
		return result

	func f597b50(out: int) -> int:
		# 597b50 vacía el buffer antes de componer un nuevo aviso de respuesta.
		events.append({"kind": "native_text_clear", "args": [out]})
		return super.f597b50(out)

	func f449d50(buffer: int) -> int:
		var owner: RefCounted = recording_owner.get_ref() if recording_owner != null else null
		if owner != null and owner.file_recording_enabled and not replay_active:
			var command := PackedInt32Array()
			for i in 4: command.append(m.u16(buffer + i * 2))
			owner.file_recorded.append(command)
		return super.f449d50(buffer)

var file_recorded: Array[PackedInt32Array] = []
var file_recording_enabled := false

var joey_player_flags := PackedInt64Array([0, 0])
var joey_next_identity := PackedInt32Array([1, 1])
var joey_zone_counters := PackedInt32Array()
var joey_zone_status := PackedInt64Array()
var engine: JoeyEngine
## Scene supplies normal0 / match1; replay and LAN select their own native kind.
var native_normal_kind := 0
## Jugador local nativo impuesto (la demostracion usa 1, como 5bfeb0(0, 1, semilla)); -1 sin forzar.
var forced_local_player := -1
var native_ticks := 0
var frame_pressed := 0
## Coordenadas de mesa: jugador local siempre abajo; el motor y la red son absolutos.
var local_native_player := 0
var _battle_player := 0
var _battle_attacker := -1
var _done := false
var _native_event_pos := 0
var _native_record_pos := 0
var _mail_stamp := ""
var _query_engine: JoeyEngine
var _stats := {}
var _text_templates := {}
var _last_text_symbol := {}
var _dialog_template := {}
var _lp_held := {}
var _lp_started := {}
var presentation_visual: Node2D
var quick_messages: Node2D
var _lp_targets := [8000, 8000]
## Terreno destino del objeto de campo 5f3244 (+0x1c); 449330 lo crea en 0 con cada duelo.
var _field_target := 0


static func create_native(data_dir: String) -> JoeyPresentationAdapter:
	var tables := CardTables.new()
	if not tables.load_from(data_dir):
		return null
	var native := NativeSessionEngine.new(tables)
	if not native.load_data(data_dir):
		return null
	var image := FileAccess.get_file_as_bytes(data_dir.path_join(Duel.IMAGE_FILE))
	if image.is_empty():
		return null
	var view := JoeyPresentationAdapter.new(native.cards)
	view.engine = native
	native.recording_owner = weakref(view)
	view.rules_game = "joey"
	view.native_version = 1300
	view.m.load_image(image)
	view.joey_zone_counters.resize(24)
	view.joey_zone_status.resize(24)
	return view


func start_normal(decks: Array[Dictionary], opts: int, rand_seed: int, mode := GAME_NORMAL) -> void:
	assert(mode in [GAME_NORMAL, GAME_NETWORK], "La repetición nativa requiere su lector propio")
	file_recorded.clear()
	file_recording_enabled = true
	if engine is JoeyReplayEngine:
		(engine as JoeyReplayEngine).replay_active = false
	# Jugador local nativo del duelo normal: 0 en el port. Las trazas recientes del original
	# llaman a 5bfeb0(1, 1, semilla) (44bee0: 5f3288 = 1) y solo con 1 el duelo completo del
	# cotejo repite sus 179 comandos; la traza D24 indica 0 y tres pruebas del port dependen de
	# 0. Pendiente D36: --joey-local-native=1 lo fija para los cotejos.
	var forced_local := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--joey-local-native="): forced_local = arg.get_slice("=", 1)
	if mode == GAME_NORMAL:
		local_native_player = forced_local.to_int() & 1 if forced_local != "" else 0
		if forced_local_player >= 0: local_native_player = forced_local_player
	else:
		local_native_player = int(engine.network_transport.is_host)
	engine.init_application()
	native_version = engine.f44baa0()
	m.set_u32(0xa114b4, 0)
	if mode == GAME_NORMAL:
		engine.m.set_u32(0x5f3294, native_normal_kind)
		engine.network_transport = null
		net = null
	options = opts
	seed = rand_seed
	game_mode = mode
	events.clear()
	recorded.clear()
	unported_calls.clear()
	mismatches.clear()
	dialog_open.clear()
	list_open.clear()
	_text_templates.clear()
	_dialog_template.clear()
	_last_text_symbol.clear()
	engine.events.clear()
	engine.recorded.clear()
	engine.unported_calls.clear()
	native_ticks = 0
	frame_pressed = 0
	_battle_player = 0
	_battle_attacker = -1
	executed = 0
	_native_event_pos = 0
	_native_record_pos = 0
	_mail_stamp = ""
	_scenario = {}
	_done = false
	for p in 2:
		var address := 0xa54e60 + p * 0xe2
		engine.m.clear(address, 0xe2)
		for row in [["main", 0, 0xdc, 80], ["side", 0xa0, 0xde, 15], ["fusion", 0xbe, 0xe0, 15]]:
			# Mazos logicos [local, rival] en los huecos 0 y 1 de a54e60 tambien con el jugador local
			# nativo 1: 5bfeb0 los reparte. Con mazos distintos (duelo de trampas, 26-10-2026) cambiarlos
			# de hueco daba al jugador el mazo de la CPU.
			var ids: Variant = decks[p].get(row[0], [])
			var count := mini(ids.size(), int(row[3]))
			for i in count:
				engine.m.set_u16(address + int(row[1]) + i * 2, engine.f402460(int(ids[i])))
			engine.m.set_u16(address + int(row[2]), count)
	if mode == GAME_NETWORK:
		engine.start_network(decks, opts, rand_seed, engine.network_transport)
	else:
		# Las opciones vienen del janken ya cruzadas con 5f3288 (janken_joey.gd): son el valor
		# nativo de quien empieza, como el segundo argumento de 48a150.
		engine.f5bfeb0(local_native_player, opts, rand_seed)
	engine.ui_enabled = true
	engine.ui_cursor_ready = false
	engine.ui_busy = false
	engine.lp_projection_enabled = true
	engine.set_lp_projection_state([])
	_lp_held.clear()
	_lp_started.clear()
	for p in 2: _lp_targets[p] = engine.m.u16(JoeyMem.pl(p) + JoeyMem.P_LP)
	synchronize_view()
	_collect_native_events()


func start_replay(replay: Ydr) -> void:
	var replay_mode := game_mode if game_mode in [4, 5, 6] else GAME_REPLAY
	start_normal(replay.decks, replay.options, replay.seed)
	game_mode = replay_mode
	native_version = replay.duel_version
	engine.visual_busy_query = Callable(self, "query_visual_busy")
	(engine as JoeyReplayEngine).configure_replay(replay, replay_mode)
	file_recording_enabled = false
	file_recorded.clear()
	local_native_player = engine.m.u16(JoeyMem.MODE) & 1
	engine.ui_enabled = false
	engine.events.clear()
	engine.recorded.clear()
	events.clear()
	recorded.clear()
	_native_event_pos = 0
	_native_record_pos = 0
	m.set_u32(0xa114b4, m.u32(0xa114b4) | 0x100)
	synchronize_view()


func begin_replay_flow() -> void:
	# 5b9f50 lee el primer comando al avanzar la maquina nativa desde su estado0.
	engine.m.set_u32(JoeyEngine.GAME_KIND, game_mode)


func incoming_left() -> int:
	if engine is JoeyReplayEngine and (engine as JoeyReplayEngine).replay_active:
		var replay := engine as JoeyReplayEngine
		return replay.replay_commands.size() - replay.replay_position
	return 0


func start_network(decks: Array[Dictionary], opts: int, rand_seed: int, transport: Object) -> void:
	engine.network_transport = transport
	net = transport
	start_normal(decks, opts, rand_seed, GAME_NETWORK)


func net_waiting() -> bool:
	return game_mode == GAME_NETWORK and engine.f5bdad0() != 0


func _view_player(p: int) -> int:
	return p ^ local_native_player


func _native_player(p: int) -> int:
	return p ^ local_native_player


func _view_card(word: int) -> int:
	return word ^ (local_native_player << 12) if word & 0xfff else word


## Herramienta --scenario (DuelScenario): mano y LP iniciales sobre el reparto nativo. Se
## aplica en la primera espera del jugador; sin escenario el duelo no cambia.
var _scenario: Dictionary = {}


func apply_scenario(scenario: Dictionary) -> PackedStringArray:
	var warnings := PackedStringArray()
	for key in ["field", "grave"]:
		for row: Variant in scenario.get(key, []):
			if row is Array and not (row as Array).is_empty():
				warnings.append("El motor nativo de Joey solo aplica mano y LP del escenario; se ignora %s." % key)
				break
	_scenario = scenario.duplicate(true)
	return warnings


## Coloca las cartas pedidas en los primeros huecos de la mano intercambiando su número con
## el de otra entrada de la mano o del mazo; cada hueco conserva su identidad y propietario.
func _apply_pending_scenario() -> void:
	if _scenario.is_empty() or not waiting_for_player(): return
	var scenario := _scenario
	_scenario = {}
	var hands: Array = scenario.get("hands", [])
	for p in mini(hands.size(), 2):
		var pl := JoeyMem.pl(p)
		var hand_n := engine.m.u8(pl + JoeyMem.P_HAND_N)
		var deck_n := engine.m.u8(pl + JoeyMem.P_DECK_N)
		var slot := 0
		for wanted: Variant in hands[p]:
			if slot >= hand_n: break
			var target := pl + JoeyMem.P_HAND + slot * 4
			var source := -1
			for k in range(slot, hand_n):
				if engine.f4022e0(engine.m.u32(pl + JoeyMem.P_HAND + k * 4) & 0xfff) & 0xffff == int(wanted):
					source = pl + JoeyMem.P_HAND + k * 4
					break
			if source < 0:
				for k in deck_n:
					if engine.f4022e0(engine.m.u32(pl + JoeyMem.P_DECK + k * 4) & 0xfff) & 0xffff == int(wanted):
						source = pl + JoeyMem.P_DECK + k * 4
						break
			if source < 0: continue
			var a := engine.m.u32(target)
			var b := engine.m.u32(source)
			engine.m.set_u32(target, (a & ~0xfff) | (b & 0xfff))
			engine.m.set_u32(source, (b & ~0xfff) | (a & 0xfff))
			slot += 1
	var lp: Array = scenario.get("lp", [])
	if not lp.is_empty():
		var projection := engine.lp_projection_state()
		for p in mini(lp.size(), 2):
			engine.m.set_u16(JoeyMem.pl(p) + JoeyMem.P_LP, int(lp[p]))
			_lp_targets[p] = int(lp[p])
			if p < projection.size(): projection[p]["visual"] = int(lp[p])
			_emit("lp_set", {"p": p, "value": int(lp[p])})
		engine.set_lp_projection_state(projection)
	synchronize_view()


func set_frame_input(pressed: int, held: int, hover: Dictionary, phase_hover: int) -> void:
	# La copia permite que las ventanas portadas lean los mismos bits de entrada.
	frame_pressed = pressed
	super.set_frame_input(pressed, held, hover, phase_hover)
	engine.visual_reset_input_ack()
	engine.ui_press(pressed)
	engine.ui_cursor_ready = not hover.is_empty()
	if not hover.is_empty():
		engine.ui_set_cursor(_native_player(int(hover.p)), int(hover.loc), int(hover.i))
	engine.ui_busy = not dialog_open.is_empty() or not list_open.is_empty()
	engine.phase_choice = phase_hover if pressed & 0x201 else 0
	for p in 2:
		var xs := PackedInt32Array()
		for i in engine.m.u8(JoeyMem.pl(p) + JoeyMem.P_HAND_N):
			xs.append(int(card_screen_position(_view_player(p), 11, i).x))
		engine.ui_set_geometry(p, xs)


## Entrada P: sólo objetos que existen en la mesa dibujada, nunca zonas de reglas.
## 4189d0 normaliza las cinco casillas de cada fila en (base, índice).
func query_visual_object(kind: String, p: int, area: int, i: int, visual: Node2D) -> Dictionary:
	if p < 0 or p > 1 or visual == null:
		return {}
	p = _view_player(p)
	var object: Dictionary = {}
	var ref_area := area
	var ref_index := i
	if kind == "pile":
		if area not in [12, 13, 14, 15]: return {}
		var pile: Dictionary = visual.table.piles[p][area]
		var card := int(pile.get("top", -1))
		return {"exists": true, "index": engine.f402460(card) if int(pile.get("count", 0)) > 0 and card >= 0 else 0,
			"ref": _native_player(p) | (area << 1)}
	if kind != "card": return {}
	if area == 11:
		if i < 0 or i >= visual.table.hand[p].size(): return {}
		object = visual.table.hand[p][i]
	elif area >= 0 and area < 11:
		var z := area + i
		var detached := z > 10 and i > 15
		if z > 10:
			z = area
			if i > 15 and not visual._field_detached.has("%d:%d" % [p, area]): return {}
		if z < 0: return {}
		if not detached and visual._field_detached.has("%d:%d" % [p, z]): return {}
		object = visual.table.field[p][z]
		ref_area = (z / 5) * 5 if z < 10 else 10
		ref_index = z % 5 if z < 10 else 0
	else:
		return {}
	if object.is_empty(): return {}
	var card := int(object.get("card", -1))
	var ref := _native_player(p) | (ref_area << 1) | ((ref_index & 255) << 6)
	ref |= int(object.get("defense", false)) << 14
	ref |= int(object.get("face", false)) << 15
	return {"exists": true, "index": engine.f402460(card) if card >= 0 else 0, "ref": ref}


func _presentation_tick() -> int:
	return int(presentation_visual.visual_tick) if is_instance_valid(presentation_visual) else 0


## 47c4b0: el número espera32 ticks incluso retenido; después un held no
## está ocupado. La cuenta liberada sigue ocupada mientras se anima en la mesa.
func query_visual_busy(kind: String, p: int = 0, _zone: int = 0) -> bool:
	if kind == "modifier_shift": return Input.is_key_pressed(KEY_SHIFT)
	if kind == "quick_message": return is_instance_valid(quick_messages) and quick_messages.busy(p)
	if kind == "lp_held": return _lp_held.has(p)
	if kind == "dialog":
		_collect_native_events()
		return not dialog_open.is_empty() or not list_open.is_empty()
	if not is_instance_valid(presentation_visual): return false
	if kind == "effects":
		# Shared objects continue updating independently while their command waits.
		return presentation_visual.joey_objects_busy()
	if kind == "markers":
		return presentation_visual._markers_busy() or presentation_visual.active.get("mode", "") == "sacrifice_release"
	if kind == "field_effect":
		# 403080: byte +0x144 del efecto de campo, activo hasta que 4490c0 supera 0x27f.
		if presentation_visual.active.get("mode", "") == "field_change": return true
		for pending: Dictionary in presentation_visual.pending:
			if pending.get("mode", "") == "field_change": return true
		return false
	if kind != "lp": return false
	if _lp_started.has(p) and _presentation_tick() - int(_lp_started[p]) < 32: return true
	var active: Dictionary = presentation_visual.active
	if active.get("mode", "") == "lp_total" and int(active.get("p", 0)) == _view_player(p): return true
	for pending: Dictionary in presentation_visual.pending:
		if pending.get("mode", "") == "lp_total" and int(pending.get("p", 0)) == _view_player(p): return true
	return false


func frame() -> bool:
	# The UI consumes 5ebee4 once per native tick (45e3d0), independently of rules.
	engine.m.set_u32(0x5ebee4, 0xffffffff)
	if game_mode in [4, 5, 6]:
		engine.m.set_u32(JoeyEngine.GAME_KIND, game_mode)
	if _done:
		return false
	if not list_open.is_empty() or not dialog_open.is_empty():
		if game_mode == GAME_NETWORK and engine.m.u8(JoeyMem.TURN) & 0x10:
			if engine.f5bd2d0() == 0:
				_done = true
				synchronize_view()
				_collect_native_events()
				return false
	if not list_open.is_empty():
		return true
	if not dialog_open.is_empty():
		if int(dialog_open.get("type", 0)) in [8, 9]:
			# 4415e0/441ad0 keep their window alive while the native queue
			# executes the chosen discards/materials. Never reenter a phase here.
			engine.events.clear()
			_native_event_pos = 0
			_dispatch_mail()
			if engine.f40cf20() == 0: engine.f5b9ca0()
			engine.flush_projection()
			native_ticks += 1
			synchronize_view()
			_collect_native_events()
		return true
	engine.events.clear()
	_native_event_pos = 0
	_dispatch_mail()
	_done = engine.f5bc700() != 0
	engine.flush_projection()
	native_ticks += 1
	synchronize_view()
	_collect_native_events()
	_apply_pending_scenario()
	for address in engine.unported_calls:
		unported_calls[address] = engine.unported_calls[address]
	return not _done


func waiting_for_player() -> bool:
	return engine != null and not _done and (engine.m.u8(JoeyMem.TURN) & 1) == local_native_player \
		and not is_running() and engine.m.u16(JoeyMem.QUEUE_COUNT) == 0 \
		and engine.m.u8(0xa577fd) == 1 and engine.m.u8(0xa577ff) in [1, 21]


func is_running() -> bool:
	return engine != null and (engine.m.u32(JoeyMem.CMD_STATE) & JoeyMem.CMD_RUNNING) != 0


func winner() -> int:
	# Native result bits are 6/7; the scene API calls player 0 winner 1.
	if engine == null: return 0
	# f002 ya transforma el resultado del rival (3-value); siempre es local.
	return (engine.m.u8(JoeyMem.TURN) >> 6) & 3


func synchronize_view() -> void:
	help_index = JoeyBase._s32(engine.m.u32(0x5ebee4))
	_stats.clear()
	_query_engine = null
	for p in 2:
		var source := JoeyMem.pl(p)
		var view_p := _view_player(p)
		var dest := DuelMem.pl(view_p)
		m.set_u16(dest, engine.m.u16(source + JoeyMem.P_LP))
		for offsets in [[2, 8], [3, 9], [4, 10], [5, 11], [6, 12]]:
			m.set_u8(dest + int(offsets[0]), engine.m.u8(source + int(offsets[1])))
		for row in [[DuelMem.P_HAND, JoeyMem.P_HAND, 80], [DuelMem.P_DECK, JoeyMem.P_DECK, 80],
			[DuelMem.P_GRAVE, JoeyMem.P_GRAVE, 80], [DuelMem.P_FUSION, JoeyMem.P_FUSION, 15],
			[DuelMem.P_BANISH, JoeyMem.P_BANISH, 80]]:
			for i in int(row[2]):
				m.set_u32(dest + int(row[0]) + i * 4, _view_card(engine.m.u32(source + int(row[1]) + i * 4)))
		for z in 11:
			var src := JoeyMem.zone(p, z)
			var dst := DuelMem.zone(view_p, z)
			m.set_u32(dst, _view_card(engine.m.u32(src)))
			m.set_u16(dst + 4, engine.m.u16(src + 4))
			m.set_u16(dst + 6, engine.m.u16(src + 6))
			# La presentación común espera referencias/tipos/contador en este orden.
			m.set_u16(dst + 0x88, engine.m.u16(src + JoeyMem.Z_LINKS_N))
			for i in 32:
				m.set_u16(dst + 8 + i * 2, engine.m.u16(src + JoeyMem.Z_LINK_REF + i * 2) ^ local_native_player)
				m.set_u16(dst + 0x48 + i * 2, engine.m.u16(src + JoeyMem.Z_LINK_KIND + i * 2))
			joey_zone_counters[view_p * 12 + z] = engine.m.u16(src + JoeyMem.Z_COUNTER)
			joey_zone_status[view_p * 12 + z] = engine.m.u32(src + JoeyMem.Z_STATUS)
		joey_player_flags[view_p] = engine.m.u32(source + 0x6d0)
		joey_next_identity[view_p] = engine.m.u16(source + 6)
	m.set_u16(0xa133f2, engine.m.u16(JoeyMem.TURN) ^ local_native_player)
	m.set_u16(0xa133f0, engine.m.u16(0xa577f8))
	# Sin el autoload Paths: las pruebas pueden precargar el adaptador antes de crearlo.
	if OS.has_feature("mobile") or "--mobile-controls=true" in OS.get_cmdline_user_args():
		# Vista táctil de solo lectura: acciones y estado del selector nativo (mobile_pointer).
		var native_action := engine.m.u32(0xa57804)
		m.set_u32(0xa13408, (native_action & 3) | (((native_action >> 3) & 15) << 2))
		m.set_u16(0xa1340a, engine.m.u16(0xa57806))
		m.set_u8(0xa1340d, engine.m.u8(0xa57809))
		for action_i in 12:
			m.set_u8(0x59df1c + action_i * 4, engine.m.u8(0x5dd980 + action_i * 4))
	m.set_u8(0xa16180, engine.m.u8(0xa577fd))
	m.set_u16(DuelMem.QUEUE_COUNT, engine.m.u16(JoeyMem.QUEUE_COUNT))
	m.set_u32(DuelMem.CMD_STATE, DuelMem.CMD_RUNNING if is_running() else 0)
	for i in 4:
		m.set_u16(DuelMem.CMD + i * 2, engine.m.u16(JoeyMem.CMD + i * 2) ^ ((local_native_player << 15) if i == 0 else 0))
	m.set_u32(DuelMem.MOVING_CARD, _view_card(engine.m.u32(0xa558b0)))
	# The existing ritual window draws its remaining stars from this mirror.
	m.set_u8(0xa15fe1, engine.f599840())
	while _native_record_pos < engine.recorded.size():
		recorded.append(engine.recorded[_native_record_pos].duplicate())
		_native_record_pos += 1
	# Executed denotes consumed commands to the presentation, not emitted commands.
	executed = recorded.size() - engine.m.u16(JoeyMem.QUEUE_COUNT)


func _emit(kind: String, data: Dictionary = {}) -> void:
	if local_native_player != 0:
		if data.has("p"): data.p = _view_player(int(data.p))
		if kind == "move":
			data.from = int(data.from) ^ 1
			data.to = int(data.to) ^ 1
			if data.has("detached_key"):
				var parts: PackedStringArray = str(data.detached_key).split(":")
				data.detached_key = "%d:%s" % [_view_player(int(parts[0])), parts[1]]
		if kind == "cmd84":
			data.a = int(data.a) ^ 1
			data.b = int(data.b) ^ 1
		if kind == "cmd" and int(data.get("op", 0)) == 0x33 and data.get("native_battle", false):
			data.args[2] = 3 - int(data.args[2])
		if kind == "cmd" and int(data.get("op", 0)) == 0x31 and data.get("native_impact", false):
			var damage := int(data.args[0])
			data.args[0] = data.args[1]
			data.args[1] = damage
			data.args[2] = ((int(data.args[2]) & 255) << 8) | ((int(data.args[2]) >> 8) & 255)
	data["kind"] = kind
	data["cmd"] = executed
	events.append(data)


## Los operandos pequeños son IDs; los buffers son plantillas ya compuestas.
func _native_text_template(token: int) -> Dictionary:
	if _text_templates.has(token): return _text_templates[token].duplicate(true)
	if token < 0x20000: return {"msg": token, "subs": []}
	var literal := ""
	if token >= JoeyMem.BASE and token < JoeyMem.END:
		var bytes := PackedByteArray()
		for offset in 4096:
			if token + offset >= JoeyMem.END: break
			var byte := engine.m.u8(token + offset)
			if byte == 0: break
			bytes.append(byte)
		literal = bytes.get_string_from_utf8()
	return {"literal": literal, "msg": -1, "subs": []}


func _collect_native_events() -> void:
	var combat_lp_sound := false
	while _native_event_pos < engine.events.size():
		var event: Dictionary = engine.events[_native_event_pos]
		_native_event_pos += 1
		var args: Array = event.get("args", [])
		match str(event.get("kind", "")):
			"native_hand_shuffle":
				var before := {}
				for i in event.before:
					before[i] = engine.f4022e0(int(event.before[i])) & 0xffff
				_emit("joey_hand_shuffle", {"p": int(event.p), "objects": before.keys(), "before": before})
			"449740":
				# 449740: solo un terreno distinto reinicia el fondo (+0x18 -> +0x1c, 449850) y
				# activa el efecto +0x140 (4490c0/449120) con scene_change (0x10000012).
				var terrain := int(args[1])
				if terrain != _field_target:
					_field_target = terrain
					# duel_field_visual lee el terreno de la vista, como en Yugi (0xa133ec).
					m.set_u16(0xa133ec, (m.u16(0xa133ec) & 0xfff0) | (terrain & 15))
					_emit("cmd11", {"p": 0, "a": terrain})
			"native_field_shuffle":
				_emit("joey_field_shuffle", {"p": int(event.p), "objects": event.objects.duplicate(),
					"visual_flags": event.visual_flags.duplicate()})
			"43c730":
				var object := int(args[0])
				if object != 0:
					var ref := engine.m.u16(object + 0x24)
					_emit("pile_top", {"p": ref & 1, "loc": (ref >> 1) & 31,
						"card": engine.f4022e0(int(args[1])) & 0xffff})
			"native_text_clear": _text_templates[int(args[0])] = {"literal": "", "msg": -1, "subs": []}
			"5bde30", "5bde70":
				var text: Dictionary = event.native_text
				var source := _native_text_template(int(text.source))
				if str(event.kind) == "5bde30":
					_text_templates[int(text.out)] = source
				else:
					var template := _native_text_template(int(text.out))
					var suffixes: Array = template.get("suffixes", []).duplicate(true)
					suffixes.append(source)
					template["suffixes"] = suffixes
					_text_templates[int(text.out)] = template
			"402290": _last_text_symbol = {"card": engine.f4022e0(int(args[0])) & 0xffff}
			"402560": _last_text_symbol = {"msg": int(args[0])}
			"48dd00":
				_emit("quick_message", {"side": int(args[0]), "msg": int(_last_text_symbol.get("msg", -1))})
			"5bdf40":
				var text: Dictionary = event.get("native_text", {"out": int(args[0]), "base": int(args[1]), "value": int(args[2])})
				var base: Dictionary = _text_templates.get(int(text.base), {"msg": int(text.base), "subs": []})
				var template := base.duplicate(true)
				var subs: Array = template.subs
				if int(text.value) == 0 and not _last_text_symbol.is_empty():
					subs.append(_last_text_symbol.duplicate(true))
				else:
					subs.append({"msg": int(text.value)})
				_text_templates[int(text.out)] = template
			"5bdfc0":
				var text: Dictionary = event.get("native_text", {"out": int(args[0]), "base": int(args[1]), "value": int(args[2])})
				var base: Dictionary = _text_templates.get(int(text.base), {"msg": int(text.base), "subs": []})
				var template := base.duplicate(true)
				template.subs.append({"d": JoeyBase._s32(int(text.value))})
				_text_templates[int(text.out)] = template
			"43a060": _open_native_list(int(args[1]), int(args[2]))
			"481230": _emit("phase", {"p": int(args[1]), "phase": int(args[2])})
			"4811f0": _emit("phase", {"p": int(args[0]), "phase": JoeyBase._s32(int(args[1]))})
			"413ac0": _emit("battle_stop")
			"413a90":
				_battle_player = int(args[0]) & 1
				_battle_attacker = -1
			"413ad0":
				_battle_attacker = -1
				_emit("cmd", {"p": _battle_player, "op": 0x56, "args": [0, 0, 0]})
			"413af0":
				_battle_attacker = int(args[0])
				_emit("battle_cursor", {"p": _battle_player, "zone": _battle_attacker})
			"413b20": _emit("battle_aim", {"p": _battle_player})
			"413b30":
				var defender := JoeyBase._s32(int(args[0]))
				if defender < 0: defender = 1 - _battle_player
				var target := JoeyBase._s32(int(args[1]))
				_emit("cmd", {"p": _battle_player, "op": 0x33,
					"args": [_battle_attacker, 5 if target < 0 else target, defender + 1], "native_battle": true})
			"413ba0":
				_emit("cmd", {"p": _battle_player, "op": 0x31,
					"args": [int(args[0]), int(args[1]), (int(args[2]) & 255) | ((int(args[3]) & 255) << 8)],
					"native_reflection": _native_reflection(args), "native_impact": true})
			"44efd0", "44f630", "44fcc0", "450c30":
				var kinds := {"44efd0": "set", "44f630": "summon", "44fcc0": "special", "450c30": "destroy_effect"}
				var ref := engine.m.u16(int(args[2]))
				var area := (ref >> 1) & 31
				var index := (ref >> 6) & 255
				var zone := area + index if area + index < 11 else area
				if str(event.kind) == "450c30" and area in [11, 12, 13, 14, 15]:
					# 404b40 also destroys hand/deck copies (Chain Destruction).
					# These references name a visual object, never a field zone.
					_emit("destroy_effect", {"p": ref & 1, "loc": area, "slot": index,
						"flags": int(ref & 0x4000 != 0) | (int(ref & 0x8000 != 0) << 1),
						"card": engine.f4022e0(int(args[1])) & 0xffff, "native_pile_destroy": true})
				elif area >= 11:
					# Estas variantes fuera del campo requieren su geometría original.
					_unported(("0x" + str(event.kind)).hex_to_int())
				else:
					var effect := {"p": ref & 1, "zone": zone,
						"flags": int(ref & 0x4000 != 0) | (int(ref & 0x8000 != 0) << 1),
						"card": engine.f4022e0(int(args[1])) & 0xffff}
					if str(event.kind) == "44f630": effect["native_base_visible"] = true
					# a5 (40a3c0) escribe la zona en el paso0 y crea su objeto con el buzón5 tras
					#8 ticks que en el original transcurren durante el efecto.
					if str(event.kind) == "44fcc0" and engine.m.u16(JoeyMem.CMD) & 0x7fff == 0xa5:
						effect["native_object_pending"] = true
					_emit(kinds[str(event.kind)], effect)
			"450260":
				var ref := engine.m.u16(int(args[2]))
				_emit("card_effect", {"p": ref & 1, "loc": (ref >> 1) & 31, "c": (ref >> 6) & 255,
					"card": engine.f4022e0(int(args[1])) & 0xffff, "native_activation": true,
					"flags": int(ref & 0x4000 != 0) | (int(ref & 0x8000 != 0) << 1)})
			"450730":
				# El constructor usa una referencia sintética de mano para la carta grande.
				_emit("card_effect", {"p": 0, "loc": 15, "card": engine.f4022e0(int(args[1])) & 0xffff})
			"4568c0", "4571d0":
				var ref := engine.m.u16(int(args[1]))
				_emit("cmd", {"p": ref & 1, "op": engine.m.u16(JoeyMem.CMD) & 0x7fff,
					"args": [cmd_a(), cmd_b(), cmd_c()]})
			"4511d0":
				var ref := engine.m.u16(int(args[2]))
				var area := (ref >> 1) & 31
				var index := (ref >> 6) & 255
				var zone := area + index if area + index < 11 else area
				_emit("cmd7a", {"p": ref & 1, "zone": zone, "card": engine.f4022e0(int(args[1])) & 0xffff})
			"456490":
				var target := engine.m.u16(int(args[2]))
				var source := engine.m.u16(int(args[3]))
				var from_zone := ((source >> 1) & 31) + ((source >> 6) & 255)
				var to_zone := ((target >> 1) & 31) + ((target >> 6) & 255)
				_emit("cmd84", {"p": source & 1, "a": (from_zone << 8) | (source & 1),
					"b": (to_zone << 8) | (target & 1), "card": engine.f4022e0(int(args[1])) & 0xffff})
			"5bf490": cursor_action = int(args[0]) + 1
			"5bf4b0": cursor_action = 0
			"5bf800":
				_dialog_msg = int(args[0])
				_dialog_template = _text_templates.get(_dialog_msg, {"msg": _dialog_msg, "subs": []}).duplicate(true)
				_open_native_dialog()
			"5bf9a0":
				if not dialog_open.is_empty(): _open_native_dialog()
			"5bf9c0": pass
			"5c03d0":
				# 47c4f0 vuelve a pedir damage al crear el contador del comando42.
				# El popup retenido de413ba0 ya lo reprodujo en el impacto.
				if not (combat_lp_sound and int(args[0]) == 0x10000009): _native_sound(int(args[0]))
				combat_lp_sound = false
			"44ef40":
				var sound_ids := {6: 0x10000010, 7: 0x1000000f, 9: 0x10000009, 0x19: 0x1000000a}
				if sound_ids.has(int(args[0])): _native_sound(sound_ids[int(args[0])])
			"44ba00": _emit("music_by_lp", {"native_music_mode": engine.m.u32(0x5f3294)})
			"41b050":
				# Panel de detalle: indice de la carta del comando (0 = reverso, como 44dbc0).
				var index := int(args[0]) & 0xfff
				_emit("detail", {"card": engine.f4022e0(index) & 0xffff if index != 0 else -1})
			"403ce0":
				if _native_reactions_enabled():
					var p := int(args[0]) & 1
					_emit("reaction_lp", {"p": p, "delta": JoeyBase._s32(int(args[1])), "native_life_before": int(_lp_targets[p])})
			"403c20":
				if _native_reactions_enabled():
					_emit("cmd", {"p": int(args[0]) & 1, "op": 0xe6, "args": [int(args[1]), 0, int(args[2])]})
			"403ec0":
				if _native_reactions_enabled() and int(args[0]) == ((~engine.m.u32(JoeyMem.MODE)) & 1):
					_native_sound(0x10000042)
			"403e10":
				if _native_reactions_enabled() and int(args[0]) == ((~engine.m.u32(JoeyMem.MODE)) & 1):
					_native_sound(0x1000004b + int(int(args[1]) != 0), true)
			"403cb0": _emit("reaction_destroy", {"p": int(args[0]), "card": int(args[1])})
			"403c50": _emit("reaction_flip", {"p": int(args[0]), "card": int(args[1])})
			"403bc0": _emit("reaction_activation", {"p": int(args[0]), "card": int(args[1])})
			"403bf0": _emit("reaction_card", {"p": int(args[0]), "card": int(args[1])})
			"403d10": _emit("cmd", {"p": int(args[0]), "op": 7, "args": [cmd_a(), cmd_b(), cmd_c()]})
			"47c4f0":
				var side := _lp_side(int(args[0]))
				combat_lp_sound = is_instance_valid(presentation_visual) and presentation_visual._lp_number.has(_view_player(side)) and (int(args[3]) & 255) != 0
				if _lp_held.has(side):
					# The second callback only releases the previous amount; its
					# new amount/argument are ignored by native47c4f0.
					var amount := int(_lp_held[side])
					_lp_held.erase(side)
					_lp_release(side, amount)
				elif int(args[3]) & 255:
					_lp_started[side] = _lp_popup_start(side)
					_lp_held[side] = JoeyBase._s32(int(args[1]))
					_emit("lp_popup", {"p": side, "amount": JoeyBase._s32(int(args[1]))})
				else:
					_lp_started[side] = _presentation_tick()
					_lp_release(side, JoeyBase._s32(int(args[1])))
			"47c4d0":
				var side := _lp_side(int(args[0]))
				_lp_targets[side] = clampi(JoeyBase._s32(int(args[1])), 0, 0xffff)
				_emit("lp_set", {"p": side, "value": int(_lp_targets[side])})
			"47c550":
				var side := _lp_side(int(args[0]))
				_lp_held.erase(side)
				_emit("lp_popup_clear", {"p": side})
			"4532c0": _emit("shuffle", {"p": int(args[1])})
			"4516a0": _emit("cmd", {"op": 0x14, "p": (engine.m.u16(JoeyMem.CMD) >> 15) & 1, "args": [0, 0, 0]})
			"451b80": _emit("cmd", {"op": 4, "p": (engine.m.u16(JoeyMem.CMD) >> 15) & 1, "args": [int(args[1]), 0, 0]})
			"486ca0": _emit("zone_marker", {"type": 0, "p": int(args[0]), "zone": int(args[1])})
			"486e50": _emit("zone_marker_clear")
			"486cc0": _emit("zone_marker", {"type": 1, "p": int(args[0]), "zone": int(args[1])})
			"486d00": _emit("cmd", {"op": 0x5a, "p": int(args[0]), "args": [int(args[1]), int(args[2]), 0]})
			"486ce0": _emit("zone_marker", {"type": 2, "p": int(args[0]), "zone": int(args[1]), "value": int(args[2])})
			"486d20": _emit("zone_marker_clear")
			"5bf230", "5bee80": _emit("cursor", {"p": int(args[0]), "loc": int(args[1]), "i": int(args[2])})
	# La petición queda atendida por la ventana portada, no por un menú del arnés.
	engine.ui_busy = not dialog_open.is_empty() or not list_open.is_empty()


func _native_reactions_enabled() -> bool:
	return engine.m.u32(0x5f3294) not in [3, 6]


## Tabla de nombres de5c0b60; no aplicar el desplazamiento de voces Yugi a Joey.
func native_sound_file(id: int) -> String:
	if id & 0xf0000000 != 0x10000000: return ""
	var index := id & 0xfff
	if index > 255: return ""
	var address := engine.m.u32(0x5efd48 + index * 16)
	if address < JoeyMem.BASE or address >= JoeyMem.END: return ""
	var name := PackedByteArray()
	for i in 128:
		if address + i >= JoeyMem.END: return ""
		var value := engine.m.u8(address + i)
		if value == 0: return name.get_string_from_ascii().get_basename().to_lower()
		name.append(value)
	return ""


func _native_sound(id: int, wait := false) -> void:
	var file := native_sound_file(id)
	if file != "": _emit("voice" if wait else "sound", {"id": id, "native_sound_file": file})


## C4140b0 sólo usa el estado6 de reflejo si el defensor tampoco recibe daño.
func _native_reflection(args: Array) -> bool:
	var battle := engine.m.u16(JoeyMem.BATTLE)
	var defender := (battle >> 1) & 1
	var target := (battle >> 11) & 7
	return target < 5 and (int(args[defender + 2]) & 2) == 0 and int(args[defender]) == 0


func _lp_side(this_: int) -> int:
	return int(this_ == engine.m.u32(0x5f3280) + 0xea8)


func _lp_popup_start(side: int) -> int:
	if is_instance_valid(presentation_visual) and presentation_visual._lp_number.has(_view_player(side)):
		return int(presentation_visual._lp_number[_view_player(side)].start)
	return _presentation_tick()


func _lp_release(side: int, amount: int) -> void:
	var before := int(_lp_targets[side])
	var after := clampi(before + amount, 0, 0xffff)
	_lp_targets[side] = after
	var delay := clampi(32 - (_presentation_tick() - int(_lp_started.get(side, _presentation_tick()))), 0, 32)
	_emit("lp_total", {"p": side, "from": before, "to": after, "amount": amount, "count_delay": delay, "native_silent": true})


func _open_native_dialog() -> void:
	var kind := engine.m.u32(0xa53770)
	var argument := engine.m.u32(0xa53758)
	# Native constructors43f740/43fd20 consume a held right button immediately;
	# icon and material windows retain their independent original input rules.
	if input_right_held() and (kind not in [0, 2, 3, 4, 5, 6, 7, 8, 9] or (kind == 3 and JoeyBase._s32(argument) >= 0)):
		engine.f5bfcc0(argument if kind == 3 else 0)
		dialog_open = {}
		engine.ui_busy = false
		return
	dialog_open = _dialog_template.duplicate(true)
	dialog_open.merge({"type": kind, "msg": int(_dialog_template.get("msg", _dialog_msg)), "subs": _dialog_template.get("subs", []),
		"buttons": {0: 0, 1: 2, 2: 2, 3: 3, 6: 2, 7: 2}.get(kind, 0),
		"default": JoeyBase._s32(argument) if kind == 3 else -1}, true)
	if kind in [4, 5]: dialog_open["icon_arg"] = argument
	if kind == 6:
		dialog_open["card"] = argument & 0xffff
		dialog_open["defense_face_down"] = argument >> 16 != 0
	if kind == 9: dialog_open["level"] = argument
	engine.ui_busy = true


func answer_dialog(value: int) -> void:
	engine.f5bfcc0(value)
	dialog_open = {}
	engine.ui_busy = false


func dialog_close(value: int) -> void:
	engine.f5bfcc0(value)
	dialog_open["closing"] = true
	engine.ui_busy = true


func dialog_gone() -> void:
	dialog_open = {}
	engine.ui_busy = false


func _packed_location(native_ref: int) -> int:
	var area := (native_ref >> 1) & 31
	var index := (native_ref >> 6) & 255
	if area < 11 and area + index > 10: index = 0
	# Existing packed locations have four area bits and nine position bits.
	# Native descriptors instead have five area bits and eight position bits.
	return (native_ref & 1) | ((area & 15) << 1) | (index << 5) | (native_ref & 0xc000)


## 40cf20 atiende el buzón una sola vez: activo (bit0) y aún sin despachar (byte alto0). El
## motor lo marca después como terminado (0x1106) y una retraducción duplicaría el movimiento.
func _dispatch_mail() -> void:
	var active_mail := engine.m.u16(0xa5506a)
	if active_mail & 1 and active_mail >> 8 == 0:
		_translate_mail()
	elif active_mail & 1 == 0:
		_mail_stamp = ""


func _mail_key() -> String:
	return "%d:%d:%d:%d" % [engine.m.u8(0xa5506a), engine.m.u32(0xa5506c), engine.m.u16(0xa55070), engine.m.u16(0xa55072)]


## 40cf20 despacha el buzón al tick siguiente de escribirlo (antes de la cola5b9ca0); hasta
## entonces la memoria proyectada ya tiene la carta en su zona, pero el objeto de la mesa no
## existe todavía: la tabla no debe adoptarla o aparece antes de su vuelo.
func pending_mail_destination(view_p: int, z: int) -> bool:
	var flag := engine.m.u8(0xa5506a)
	if flag & 1 == 0 or engine.m.u8(0xa5506b) != 0 or (flag >> 1) not in [3, 4, 5]: return false
	if _mail_key() == _mail_stamp: return false
	var dest := engine.m.u16(0xa55072)
	var area := (dest >> 1) & 31
	var index := (dest >> 6) & 255
	if area >= 11 or index == 255: return false
	return _view_player(dest & 1) == view_p and (area + index if area + index < 11 else area) == z


func _translate_mail() -> void:
	var flag := engine.m.u8(0xa5506a)
	var stamp := _mail_key()
	if stamp == _mail_stamp: return
	_mail_stamp = stamp
	var kind := flag >> 1
	var index := engine.m.u32(0xa5506c) & 0xfff
	var source := engine.m.u16(0xa55070)
	var dest := engine.m.u16(0xa55072)
	if kind in [1, 2]:
		var p := engine.m.u8(0xa5506c) & 1
		var zone := engine.m.u8(0xa5506d)
		var position := engine.m.u8(0xa5506e) & 1
		var face := engine.m.u8(0xa5506f) & 1
		_emit("change_position" if kind == 1 else "flip", {"p": p, "zone": zone,
			"flags": engine.m.u8(JoeyMem.zone(p, zone) + 6),
			"native_target_flags": position | face << 1, "b": face, "native_silent": true})
	if kind in [3, 4]:
		var source_area := (source >> 1) & 31
		var dest_area := (dest >> 1) & 31
		if dest_area < 11 and ((dest >> 6) & 255) == 255:
			_emit("field_detach", {"p": dest & 1, "zone": dest_area,
				"card": engine.f4022e0(index) & 0xffff, "flags": engine.m.u16(JoeyMem.zone(dest & 1, dest_area) + 6)})
			return
		var from := _packed_location(source)
		var to := _packed_location(dest)
		var data := {"card": engine.f4022e0(index) & 0xffff, "index": index,
			"p": source & 1, "from": from, "to": to, "instant": kind == 4, "native_silent": true}
		if source_area < 11 and ((source >> 6) & 255) == 255:
			data["detached_key"] = "%d:%d" % [source & 1, source_area]
		if (source >> 1) & 31 == 11: data["hand_i"] = (source >> 6) & 255
		_emit("move", data)
	elif kind == 5:
		# 40d840 -> 41d160: crea el objeto en su ubicación, sin vuelo (fichas de a5, por ejemplo).
		var area := (dest >> 1) & 31
		var slot := (dest >> 6) & 255
		if area < 11:
			_emit("joey_object_place", {"p": dest & 1, "zone": area + slot if area + slot < 11 else area,
				"card": engine.f4022e0(index) & 0xffff, "face": dest & 0x8000 != 0, "defense": dest & 0x4000 != 0})


## Lecturas de presentación que deben consultar la disposición nativa.
func _queries() -> JoeyEngine:
	if _query_engine == null:
		_query_engine = JoeyEngine.new(engine.cards)
		_query_engine.m.bytes = engine.m.bytes.duplicate()
	return _query_engine


func f546470(p: int, z: int, out: int) -> int:
	var key := p * 16 + z
	if not _stats.has(key):
		var copy := _queries()
		var temp := copy.m.local(12)
		copy.f56dd30(_native_player(p), z, temp)
		_stats[key] = [copy.m.u32(temp), copy.m.u32(temp + 4), copy.m.u32(temp + 8)]
		for address in copy.unported_calls: unported_calls[address] = copy.unported_calls[address]
	for i in 3: m.set_u32(out + i * 4, int(_stats[key][i]))
	return 0


## Jo4142c0 consulta56b730 con check1 para las espadas disponibles; la máscara
## de ataques Joey está en player+10. El lector Yugi del espejo no es equivalente.
func f571810(p: int, z: int, _check: int) -> int:
	return _queries().f56b730(_native_player(p), z, 1)


func f571d30(p: int) -> int:
	return _queries().f5a0dd0(_native_player(p))


func f578be0() -> int:
	var done := engine.f5a9060()
	synchronize_view()
	_collect_native_events()
	return done


func f56b290() -> int:
	var done := engine.f5995e0()
	synchronize_view()
	_collect_native_events()
	return done


func f578bd0() -> int:
	return engine.f5a9050()


var _declaration_cards: Array = []


func _open_native_list(p: int, kind: int) -> void:
	_declaration_cards.clear()
	#43a930 builds these lists from the complete enabled card catalogue.
	if kind >= 42 and kind <= 46:
		var pack_mask := (1 << ((engine.m.u32(0x5eb600) + 1) & 31)) - 1
		for index in range(1, 0x45b):
			if engine.f4024e0(index) & pack_mask == 0: continue
			var frame := engine.f402740(index)
			if (kind == 42 and frame == 0) or (kind == 43 and frame == 1) or (kind == 44 and frame in [2, 3]) or (kind == 45 and frame == 7) or (kind == 46 and frame == 8):
				_declaration_cards.append(index)
		#47dcb0 compares402540 language ranks, with the native CRT tie ordering.
		var ui_root: Node = Engine.get_main_loop().root
		var language: String = {"s": "spa", "e": "eng", "g": "ger", "f": "fra", "i": "ita", "j": "jpn"}.get(ui_root.get_node("Assets").lang, "spa")
		var ranks := FileAccess.get_file_as_bytes(ui_root.get_node("Paths").data_dir.path_join("common/bin/card_sort%s.bin" % language))
		preload("res://core/native_card_sort.gd").sort_joey(_declaration_cards, func(index: int) -> int: return ranks.decode_u16(index * 2))
	var mode := 0 if kind < 6 else 1
	var limit := 1
	if kind >= 7 and kind <= 39:
		mode = 3 if kind >= 24 else 2
		limit = maxi(1, kind - (23 if kind > 22 else 6))
	list_open = {"p": _view_player(p), "loc": {1: 12, 2: 13, 3: 14, 4: 15}.get(kind, -1),
		"layout_p": int(p == ((~engine.m.u8(JoeyMem.MODE)) & 1)),
		"mode": mode, "native_kind": kind, "selection_limit": limit,
		"native_selection": true, "native_face_down": kind == 41,
		"allow_early_close": kind >= 24 and kind <= 39}
	engine.ui_busy = true


func f4073e0() -> int:
	if int(list_open.get("native_kind", 0)) in range(42, 47): return _declaration_cards.size()
	return engine.f40cae0()


func f4073f0(i: int) -> int:
	if int(list_open.get("native_kind", 0)) in range(42, 47): return int(_declaration_cards[i]) if i >= 0 and i < _declaration_cards.size() else 0
	return engine.f40caf0(i)


func f4073a0(i: int) -> int:
	engine.f40cc60(i, 1) #43ad90 marks the single choice as well as the selected row.
	return engine.f40caa0(i)


func f407540(i: int, order: int) -> int:
	return engine.f40cc60(i, order)


func f407570(i: int) -> int:
	return engine.f40cc90(i)


func f407440(i: int) -> int:
	if int(list_open.get("native_kind", 0)) in range(42, 47): return 0
	return engine.f40cb50(i)


func list_close(value: int) -> void:
	if list_open.is_empty() or list_open.get("closing", false): return
	list_open["closing"] = true
	#43a8f0 returns the catalogue index for declaration lists, not its row.
	if int(list_open.get("native_kind", 0)) in range(42, 47): value = f4073f0(value)
	# Joey43ac50 only retires card objects. Unlike the common core, it does
	# not acknowledge a second zero answer after43e0a0/5bfcc0(value).
	engine.f5bfcc0(value)


func list_gone() -> void:
	list_open = {}
	engine.ui_busy = false
