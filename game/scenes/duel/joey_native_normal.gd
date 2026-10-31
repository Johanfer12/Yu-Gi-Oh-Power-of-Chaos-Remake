extends "res://scenes/duel/normal_duel.gd"
## Interfaz portada compartida; la vista Duel del adaptador nunca gobierna reglas.

var _modal_network_clock := 0.0

func _init(start_options := 0) -> void:
	super("joey", start_options)


func _ready() -> void:
	super._ready()
	if _duel == null or _visual == null:
		return
	if Game.joey_demo:
		var label := DuelDemoLabel.new()
		label.setup("joey")
		add_child(label)
	var adapter := _duel as JoeyPresentationAdapter
	if _lan:
		adapter.quick_messages = preload("res://scenes/duel/joey_native_quick_messages.gd").new()
		add_child(adapter.quick_messages)
	adapter.presentation_visual = _visual
	adapter.engine.visual_busy_query = Callable(adapter, "query_visual_busy")
	adapter.engine.visual_object_query = Callable(adapter, "query_visual_object").bind(_visual)
	adapter.engine.visual_phase_hover_query = Callable(self, "_native_phase_hover")


## El objeto de fase aporta su modo y el hit-test. El predicado de batalla
## pertenece a 481a10 dentro del motor, incluso cuando no se ha hecho clic.
func _native_phase_hover() -> Dictionary:
	var adapter := _duel as JoeyPresentationAdapter
	return {"mode": _ph_phase, "hover": _phase_hover(),
		"pressed": adapter != null and (adapter.frame_pressed & 0x200) != 0}


func _create_duel() -> Duel:
	var adapter := JoeyPresentationAdapter.create_native(Paths.data_dir)
	if adapter != null: adapter.native_normal_kind = 1 if Game.duel_mode == 1 else 0
	if adapter != null and Game.joey_demo:
		# Demostracion (D35): tipo 7, los dos lados de la CPU, jugador local nativo 1.
		adapter.native_normal_kind = 7
		adapter.forced_local_player = 1
	return adapter


func make_replay() -> Ydr:
	var replay := super.make_replay()
	var adapter := _duel as JoeyPresentationAdapter
	replay.local_player = adapter.local_native_player
	replay.commands = adapter.file_recorded.duplicate()
	if _lan:
		# Los comandos usan jugadores absolutos. La cabecera debe describir el
		# mismo orden; host=1, invitado=0, mientras la sala guarda local/rival.
		var local := adapter.local_native_player
		if local == 1: replay.decks.reverse()
		replay.options = (replay.options & ~1) | ((replay.options & 1) ^ local)
	return replay


func _prepare_duel_decks(_decks: Array[Dictionary]) -> Array[Dictionary]:
	if Game.duel_mode == 3 and Lan.active():
		return _decks
	if Game.joey_demo:
		# El lado 0 lleva el mazo FUL que eligio el titulo, no el mazo del jugador.
		var demo: Variant = Assets.read_json(Game.joey_demo_deck)
		if demo is Dictionary:
			_decks[0] = {"main": PackedInt32Array(demo.get("main", [])), "side": PackedInt32Array(demo.get("side", [])),
					"fusion": PackedInt32Array(demo.get("fusion", []))}
		return _decks
	var path := Paths.cmdline_value("native-decks")
	if path != "":
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Array and data.size() == 2:
			var configured: Array[Dictionary] = []
			for deck in data:
				if deck is not Dictionary or deck.get("main", []).size() < 40 or deck.get("main", []).size() > 80:
					push_error("native-decks requiere entre 40 y 80 cartas principales por jugador")
					return []
				configured.append({"main": PackedInt32Array(deck.get("main", [])),
					"side": PackedInt32Array(deck.get("side", [])), "fusion": PackedInt32Array(deck.get("fusion", []))})
			return configured
		push_error("native-decks requiere dos mazos con main/side/fusion")
		return []
	return _decks


## Demostracion: cualquier tecla o clic, o el final del duelo, vuelve al titulo sin resultado.
func _leave_demo() -> void:
	Game.joey_demo = false
	Audio.stop_music()
	Game.open_title("joey")


func _input(event: InputEvent) -> void:
	if Game.joey_demo and _duel != null and ((event is InputEventKey and event.pressed and not event.echo) 			or (event is InputEventMouseButton and event.pressed)):
		get_viewport().set_input_as_handled()
		_leave_demo()
		return
	super._input(event)


func _start_result() -> void:
	if Game.joey_demo:
		if _duel.winner() != 0: _leave_demo()
		return
	super._start_result()


func _waiting_for_player() -> bool:
	return _duel != null and (_duel as JoeyPresentationAdapter).waiting_for_player()


func _collect_visual_events() -> bool:
	if _duel is JoeyPresentationAdapter:
		var adapter := _duel as JoeyPresentationAdapter
		if is_instance_valid(adapter.quick_messages):
			for i in range(_visual_event_pos, _duel.events.size()):
				var e: Dictionary = _duel.events[i]
				if e.get("kind", "") == "quick_message":
					adapter.quick_messages.show_message(int(e.side), int(e.msg), Lan.local_name if int(e.side) == 0 else Lan.remote_name)
	return super._collect_visual_events()


func _process(delta: float) -> void:
	# El padre detiene las fases mientras sus ventanas poseen la entrada. La
	# sesión, como5bc700 antes de40cf20, sigue recibiendo paquetes a30Hz.
	if _duel is JoeyPresentationAdapter and _lan and not _finished:
		var adapter := _duel as JoeyPresentationAdapter
		var paused := not adapter.list_open.is_empty() or (not adapter.dialog_open.is_empty() and int(adapter.dialog_open.get("type", 0)) not in [8, 9])
		if paused:
			_modal_network_clock = minf(_modal_network_clock + NativeClock.ticks(delta), 4.0)
			while _modal_network_clock >= 1.0:
				_modal_network_clock -= 1.0
				if adapter.engine.f5bd2d0() == 0:
					adapter._done = true
					adapter.synchronize_view()
					_finished = true
					break
				adapter._collect_native_events()
		else:
			_modal_network_clock = 0.0
	super._process(delta)
	# 44dd00: 5c0000 modifica las manos antes de45c8b0; el resto de objetos
	# se dibuja con esas coordenadas en el mismo tick de la insercion.
	if _duel != null and _visual != null and not _visual._shade_on and _visual._shade_c == 0:
		if super._advance_hands(delta): _redraw()
		_show_hands(_hand_clock)

func _advance_hands(_delta: float) -> bool:
	# El padre avanza presentacion antes del motor; Joey recoloca despues.
	return false
