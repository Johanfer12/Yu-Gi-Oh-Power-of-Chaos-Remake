extends "res://scenes/duel/replay_viewer.gd"
## Partida humana: reutiliza el tablero del visor y responde al motor original.
## El mazo activo se lee; esta escena no guarda premios ni modifica la partida.

var _source := ""
var _event_pos := 0
## Peticion ui_request ya avisada (ninguna rutina portada la usa ya; 56a460 usa cursor y cuadros).
var _ui_reported := false
## Clics desde el ultimo fotograma del motor (0x200 izquierdo, 0x100 derecho; ver 0x5407f0).
var _press_bits := 0
## Ventana del cuadro de dialogo que esta mostrando el motor (dialog_open).
var _dialog_box: Node2D = null
## Ventana de la lista de seleccion (duel_list_window.gd) mientras existe.
var _list_window: Node2D = null
## Panel de fases (objeto DAT_005af874, 0x4614b0): phase.txt da las posiciones x*1000+y
## (207,49+82n) de las hojas pha_s_* (2x2 celdas de 40x90) y las tiras de volteo pha_b_*/pha_r_*
## (9 celdas de 40x90) usadas al cambiar de jugador.
const PHASE_NAMES := ["dr", "st", "m1", "ba", "m2", "en"]
const PHASE_ORIGIN := Vector2(207, 49)
const PHASE_STEP := 82
const PHASE_CELL := Vector2(40, 90)
## Estado del objeto: +0x15c jugador, +0x160 fase mostrada, +0x164 fundido de la fase actual,
## +0x168 volteo de entrada, +0x16c ficha iluminada (0x4614b0: 0x15c = DAT_005af770,
## 0x160 = -1, 0x164 = 0x100, 0x168 = 0x200, 0x16c = -1).
var _ph_p := 0
var _ph_phase := -1
var _ph_fade := 0x100
var _ph_intro := 0x200
var _ph_clock := 0.0
var _ph_blend := NativeBlend.new()   # fundido y pulso de la ficha de la fase entre ticks
## Ticks nativos pendientes para el motor (un paso de 53dbf0 por tick).
var _engine_clock := 0.0
## El motor compartido completa op14 al emitirlo; Kaiba aun debe consumir
## la vuelta de acuse405450 despues de retirarse el objeto.
var _start_banner_ack := false
var _ph_drawn := []
var _phase_layer := Node2D.new()
var _phase_mask: Image
## Kaiba (Kaiba_Pc.exe, objeto 0x463600 con vtable 0x59f9a8, mismo estado +0x15c..+0x16c):
## phase.txt trae ph_b_* (jugador 0) y ph_r_* (jugador 1), tiras de 8 celdas de 29 x 65, en
## x=220, y=69+80k, y ph_mask (indice 12). Posiciones [x, y] leidas del .txt por indice.
var _ph_pos: Array[PackedInt32Array] = []

## `start_options`: opciones de 0x5418a0 (bit 0 = quien empieza) que deja el piedra-papel-tijera
## en DAT_005af770; -1 = sin janken (empieza la CPU, como hasta ahora).
var _start_options := -1
var _replay_decks: Array[Dictionary] = []
var _replay_options := 0
var _replay_seed := 0
## Duelo LAN (Game.duel_mode 3 con sesion activa).
var _lan := false
## Cartel de espera del rival en red (Joey 456360).
var _wait_label: DuelWaitLabel = null


func _init(game_id: String, start_options := -1) -> void:
	super(game_id, "demo")
	_start_options = start_options


func _create_duel() -> Duel:
	return Duel.create(Paths.data_dir, game)


func _prepare_duel_decks(decks: Array[Dictionary]) -> Array[Dictionary]:
	return decks

func _ready() -> void:
	var dialogs: Variant = Assets.dialog_texts()
	_dialogs = dialogs if dialogs is Array else []
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.size = Vector2(800, 600)
	# Sin esto el ColorRect se queda el raton y no llega a las ventanas modales (PocDialog).
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_setup_detail()
	_setup_field()
	#481040: fases0xf0 (Kaiba/Yugi0xff), pilas0x100: las cartas tapan
	#el fondo opaco de las fichas que alcanza los primeros pixeles de las pilas.
	add_child(_phase_layer)
	add_child(_board)
	_setup_cursor()
	_info = _label(Vector2(238, 66), Vector2(552, 22), 12)
	_log = _label(Vector2(240, 280), Vector2(300, 60), 12)
	_log.clip_text = true
	# El original no escribe turno, fase ni mensajes sobre el tablero: solo el panel de
	# fases, los cuadros y el panel de detalle. Estas etiquetas solo se usan si faltan datos.
	_info.visible = false
	_log.visible = false
	_duel = _create_duel()
	if _duel == null:
		_log.text = "Faltan los datos del motor de duelo."
		_log.visible = true
		return
	# Deck.ydc y file/deck_y/k/j.txt convertidos por pocx; Joey no trae demos.ydr.
	var decks: Array[Dictionary] = []
	for name in ["starter_deck", "rival_deck"]:
		var original: Variant = Assets.read_json("%s/file/%s.json" % [game, name])
		if not original is Dictionary:
			push_error("Mazo original no encontrado: %s/file/%s.json" % [game, name])
			_log.text = "Falta el mazo original de " + game + "."
			_log.visible = true
			return
		decks.append({"main": PackedInt32Array(original.get("main", [])), "side": PackedInt32Array(original.get("side", [])), "fusion": PackedInt32Array(original.get("fusion", []))})
	# Mazo de Yugi elegido por 0x437c60 al entrar desde el menu (cpu*.ydc convertido a json).
	var rival: Variant = Assets.read_json(Game.rival_deck) if Game.rival_deck != "" and Paths.cmdline_value("scenario") == "" else null
	if rival is Dictionary:
		decks[1] = {"main": PackedInt32Array(rival.get("main", [])), "side": PackedInt32Array(rival.get("side", [])),
				"fusion": PackedInt32Array(rival.get("fusion", []))}
	var active: Dictionary = SaveData.data.get("decks", {}).get(game, {})
	if active.get("main", []).size() >= 40 and active.get("main", []).size() <= 80:
		decks[0] = {"main": PackedInt32Array(active.get("main", [])), "side": PackedInt32Array(active.get("side", [])), "fusion": PackedInt32Array(active.get("fusion", []))}
		_source = "Tu mazo activo · rival: " + (Game.rival_deck.get_file() if rival is Dictionary else "mazo original")
	else:
		_source = "Mazos originales (sin mazo activo válido)"
	decks = _prepare_duel_decks(decks)
	if decks.size() != 2:
		_log.text = "No se pudieron preparar los dos mazos del duelo."
		_log.visible = true
		set_process(false)
		return
	# Herramienta de desarrollo: --scenario=<nombre> prepara mano y campo (ver DuelScenario).
	var scenario: DuelScenario = null
	var scenario_name := Paths.cmdline_value("scenario")
	if scenario_name != "":
		scenario = DuelScenario.load_named(scenario_name)
		if scenario == null:
			printerr("Escenario no encontrado: ", scenario_name, " (disponibles: ", ", ".join(DuelScenario.list()), ")")
	var first := 1 if _start_options < 0 else _start_options
	# Con --ui-replay, la semilla del duel_start de la traza (la que el original pasa a 5418a0).
	var rand_seed := Debug.next_duel_seed()
	if rand_seed < 0:
		rand_seed = int(Time.get_unix_time_from_system()) & 0x7fffffff
	if scenario != null:
		decks = scenario.build_decks(decks)
		first = scenario.first
		if scenario.seed >= 0:
			rand_seed = scenario.seed
		_source = "Escenario: " + scenario_name
	# Duelo LAN de Joey (D17, modo 3): mazo del rival recibido con 0xf004 y semilla de la
	# sesion (0xf005); cada lado se ve como jugador 0 y el rival llega por la red.
	_lan = Game.duel_mode == 3 and Lan.active()
	if _lan:
		var remote: Dictionary = Game.lan_rival_deck
		decks[1] = {"main": PackedInt32Array(remote.get("main", [])), "side": PackedInt32Array(remote.get("side", [])),
				"fusion": PackedInt32Array(remote.get("fusion", []))}
		rand_seed = Game.lan_seed
		_source = "Duelo LAN contra " + Lan.remote_name
		if scenario != null:
			printerr("Escenario ignorado en el duelo LAN")
			scenario = null
		_duel.start_network(decks, first, rand_seed, Lan)
		_wait_label = DuelWaitLabel.new()
		_wait_label.setup(game)
		add_child(_wait_label)
	else:
		_duel.start_normal(decks, first, rand_seed)
	_replay_decks = decks
	_replay_options = first
	_replay_seed = rand_seed
	if scenario != null:
		for warning in scenario.apply(_duel):
			printerr("Escenario: ", warning)
	_ph_p = _duel.options & 1
	if game in ["kaiba", "joey"]:
		for item in Assets.layout("%s/duel/phase/phase.txt" % game).items:
			_ph_pos.append(Layout.groups(item["value"]))
	# Hoja con la que se comprueba el raton: pha_s_dr en Yugi, ph_b_dr (indice 0) en Kaiba.
	var mask_tex := Assets.texture("kaiba/duel/phase/ph_b_dr.png" if game == "kaiba" else "%s/duel/phase/pha_s_dr.png" % game)
	_phase_mask = mask_tex.get_image() if mask_tex != null else null
	_duel.input_right_held_query = func() -> bool: return PlatformInput.mouse_pressed(MOUSE_BUTTON_RIGHT)
	_setup_presentation(true)
	_help = DuelHelp.new()
	_help.setup(game)
	add_child(_help)
	Audio.play_music(preload("res://scenes/duel/duel_music.gd").path(game, Game.duel_mode, _shown_lp()))
	_redraw()

func _process(_delta: float) -> void:
	if _duel == null:
		return
	# Ka437f80 / Jo44dd00: los objetos de mascara1 solo avanzan con
	# sombreado apagado y contador0. El tick que crea op14 ya paso por aqui;
	# el que termina de cerrarlo sigue congelado y se reanuda en el siguiente.
	var mask_one_active: bool = _visual == null or not _visual._start_banner_shade
	if mask_one_active:
		_tick_card_stats(_delta)
	if _visual != null:
		_visual.pointer = _pointer_pos
		# Esperando al jugador, la mesa puede adoptar todo lo que el motor cambio sin evento.
		_visual.at_rest = _waiting_for_player() and _duel.dialog_open.is_empty()
	if mask_one_active:
		_ph_clock += NativeClock.ticks(_delta)
		while _ph_clock >= 1.0:
			_ph_clock -= 1.0
			_ph_blend.tick()
			_phase_panel_tick()
			if _duel.dialog_open.is_empty() and _duel.list_open.is_empty():
				_step_pointer()
		_ph_blend.fraction = _ph_clock
		_draw_phase_panel()
	# El original llama a 53dbf0 una vez por vuelta del bucle principal (NativeClock.HZ): el
	# motor da un paso por tick nativo, aunque la pantalla se dibuje mas a menudo.
	_engine_clock = minf(_engine_clock + NativeClock.ticks(_delta), 4.0)
	var steps := int(_engine_clock)
	_engine_clock -= steps
	if _help != null: _help.show_between(_engine_clock)
	var start_shade: bool = _visual != null and _visual._start_banner_shade
	var presenting := _advance_visual(_delta)
	if game == "kaiba" and start_shade and not _visual._start_banner_shade:
		_start_banner_ack = true
	if _wait_label != null:
		# 44ba10: sin cartel mientras hay objetos de presentacion activos.
		_wait_label.waiting = not presenting and _duel.net_waiting()
	if presenting:
		# El motor no lee el raton mientras la presentacion lo detiene: el clic se pierde.
		if steps > 0: _press_bits = 0
		return
	if _start_banner_ack:
		if steps > 0:
			_start_banner_ack = false
			_press_bits = 0
		return
	if _finished:
		# 53eda0 sin sesion (bit 4 de a133f2): el rival se fue; vuelta al titulo (escena 4).
		if _lan and (_duel.m.u8(0xa133f2) & 0x10) != 0 and _duel.winner() == 0:
			set_process(false)
			Game.lan_lost(game)
			return
		_start_result()
		return
	if steps == 0:
		return
	var before := _duel.executed
	if not _duel.dialog_open.is_empty():
		_duel.set_frame_input(_press_bits, 0, _hover_input(), -1)
		_press_bits = 0
		# 53dbf0 ejecuta la cola antes de540db0. Los selectores8/9 emiten
		# descartes/materiales mientras la ventana sigue ocupando la ranura.
		if int(_duel.dialog_open.get("type", 0)) in [8, 9]:
			for _i in range(steps):
				_duel.frame()
			_collect_visual_events()
			_redraw()
		_show_dialog()
		return
	if not _duel.list_open.is_empty():
		_show_list()
		return
	var hover := _hover_input()
	var phase_hover := _phase_hover()
	for _i in range(steps):
		if not _duel.ui_pending.is_empty():
			# No hay menus propios: una peticion asi seria un hueco del porte.
			if not _ui_reported:
				printerr("Peticion de interfaz sin ventana del original: ", _duel.ui_pending)
				_ui_reported = true
			break
		# 0x5407f0: los clics valen para un solo fotograma del motor.
		_duel.set_frame_input(_press_bits, 0, hover, phase_hover)
		var clicked := (_press_bits & 0x200) != 0
		_press_bits = 0
		if not _duel.frame():
			_finished = true
		# FUN_004437b0: ayuda emergente con el indice que ha pedido el motor en este fotograma.
		if _help != null:
			var help_hover := {}
			if not hover.is_empty():
				help_hover = hover.duplicate()
				help_hover["pos"] = _help_pos(hover)
			_help.step(_duel, help_hover, clicked)
		_duel.set_frame_input(0, 0, hover, phase_hover)
		if _collect_visual_events(): break
		if not _duel.unported_calls.is_empty():
			printerr("Rutinas pendientes: ", _duel.unported_calls.keys().map(func(a): return "0x%06x" % a))
			_text = "Esta acción todavía no está disponible en esta versión. Puedes volver al título con Esc."
			_finished = true
			break
		if not _duel.dialog_open.is_empty():
			_show_dialog()
			break
		if not _duel.list_open.is_empty():
			_show_list()
			break
		if _duel.executed != before or _finished or _waiting_for_player():
			break
	_refresh_cursor(true)
	_collect_events()
	if _finished:
		if _duel.unported_calls.is_empty():
			_text = "Fin del duelo: " + ("ganaste" if _duel.winner() == 1 else "ganó la CPU" if _duel.winner() == 2 else "empate")
		_redraw()
		return
	if before != _duel.executed:
		_redraw()


## 540af0/4600f0: un paso del objeto global por tick; el motor consulta el destino.
func _step_pointer() -> void:
	var at := PointerGlide.step(self, _pointer_pos)
	if at != _pointer_pos:
		_pointer_pos = at
		_hover_card = _hit_card(PointerGlide.hover(at))
		_refresh_cursor(true)

var _help: DuelHelp
var _result: DuelResult


## Repeticion de este duelo (lo que graba 0x436f60): mazos, opciones, semilla y los comandos
## emitidos (DuelBase.recorded). La version del duelo es (DAT_005aed1c + 1) * 100.
func make_replay() -> Ydr:
	var r := Ydr.new()
	r.version = 1
	r.deck_mark = int(Time.get_unix_time_from_system()) & 0xffffffff
	r.duel_version = _duel.native_version if game == "joey" else {"yugi": 100, "kaiba": 200}.get(game, 100)
	r.options = _replay_options
	r.seed = _replay_seed
	r.decks = _replay_decks.duplicate(true)
	r.commands = _duel.recorded.duplicate()
	return r


## 0x4379d0 -> escena de resultado (0x435410) cuando el duelo termina y acaba el cartel.
func _start_result() -> void:
	if _result != null or not _duel.unported_calls.is_empty() or _duel.winner() == 0:
		return
	var winner := _duel.winner()
	# 0x53d9d0 -> 0x437440: resultado del duelo y, en match, el global.
	Game.record_duel_result(winner)
	# 0x435410: el cartel pasa a la escena de resultado (que lo encoge si gana; en match,
	# siempre, junto al tablero).
	if winner == 1 or Game.duel_mode == 1:
		_visual.end_banner = ""
		_visual._render()
	_result = DuelResult.new()
	var surrendered: bool = _duel is JoeyPresentationAdapter and (_duel.engine.m.u16(JoeyMem.MODE) & 0x40) != 0
	_result.setup(game, winner, _duel.m.u32(0xa114b4), surrendered)
	# Estado 7 de 0x435410: match sin decidir -> escena 10 y siguiente duelo; si no, la salida
	# de Yugi con el resultado global. La musica la gestiona Game: en Yugi sigue sonando.
	_result.finished.connect(func() -> void:
		if Game.duel_mode == 1 and Game.match_outcome == 0:
			Game.continue_match(game)
		else:
			Game.finish_normal_duel(game, Game.match_outcome if Game.duel_mode in [0, 1, 3] else winner))
	add_child(_result)


## Posicion actual del objeto de la carta (0x410020): la mano usa su posicion animada.
func _help_pos(h: Dictionary) -> Vector2:
	var p: int = h["p"]
	var loc: int = h["loc"]
	var i: int = h["i"]
	if loc == 11:
		var n := _duel.m.u8(DuelMem.pl(p) + 2)
		return _hand_positions.get(p * 256 + i, DuelGeometry.hand(p, i, n))
	return DuelGeometry.location(p, loc, i)


## El turno del humano espera su entrada: fase principal o de batalla sin comandos en curso.
func _waiting_for_player() -> bool:
	return (_duel.m.u16(0xa133f2) & 1) == 0 and not _duel.is_running() 			and _duel.m.u16(DuelMem.QUEUE_COUNT) == 0 and _duel.m.u8(0xa16180) >= 2 			and _duel.m.u8(0xa16180) < 8


## Objeto bajo el cursor tal como lo ve el original: jugador, ubicacion, posicion y la carta
## (indice) del objeto visual. El mazo tambien es un objeto (ubicacion 0xd).
func _hover_input() -> Dictionary:
	if _hover_card.is_empty():
		return {}
	var p: int = _hover_card["p"]
	var loc: int = _hover_card["loc"]
	var i: int = _hover_card["i"]
	var card := 0
	if loc != 13:
		card = _duel.m.u16(_duel.f5419b0(p, loc, i)) & 0xfff
	return {"p": p, "loc": loc, "i": i, "card": card}


## 0x460f80: ficha bajo el puntero o -1. No responde mientras el panel anima (vtable +4 =
## 0x460b80). x relativa a la columna (0 <= x < 40, mitad del ancho de la hoja); para cada
## ficha en orden, y relativa a su posicion < 90 (mitad del alto) y el pixel (x, y) de la
## hoja 0 (pha_s_dr) no transparente (vtable +0x6c). Las fichas se solapan 8 px: gana la
## primera con pixel opaco.
func _phase_hover() -> int:
	if _phase_busy() or _phase_mask == null:
		return -1
	var pos := Vector2i(_pointer_pos.floor())
	if game == "kaiba":
		return _phase_hover_kaiba(pos)
	if game == "joey":
		# Jo4812e0: rectangulo 29x54, y relativa en [3,57), sin mascara de pixeles.
		var x := pos.x - _ph_pos[0][0]
		if x < 0 or x >= 29: return -1
		for k in 6:
			var y := pos.y - _ph_pos[k][1]
			if y >= 3 and y < 57: return k
		return -1
	var x := pos.x - int(PHASE_ORIGIN.x)
	if x < 0 or x >= int(PHASE_CELL.x):
		return -1
	for k in 6:
		var y := pos.y - int(PHASE_ORIGIN.y) - PHASE_STEP * k
		if y < int(PHASE_CELL.y) and y >= 0 and _phase_mask.get_pixel(x, y).a > 0.5:
			return k
	return -1


## Kaiba 0x463100: x relativa a la ficha 0 dentro de la primera celda (ancho / 8) y el pixel
## (x, y - y de la ficha k) de ph_b_dr no transparente (vtable +0x6c); gana la primera ficha.
func _phase_hover_kaiba(pos: Vector2i) -> int:
	var cell_w := _phase_mask.get_width() / 8
	var x := pos.x - _ph_pos[0][0]
	if x < 0 or x >= cell_w:
		return -1
	for k in 6:
		var y := pos.y - _ph_pos[k][1]
		if y >= 0 and y < _phase_mask.get_height() and _phase_mask.get_pixel(x, y).a > 0.5:
			return k
	return -1


## 0x460b80: el panel esta animando (volteo de entrada o fundido de la fase actual).
func _phase_busy() -> bool:
	return _ph_intro < 0x200 or _ph_fade < 0x80


## 0x460b00 (desde el comando de fase 0x402840): mismo jugador -> fundido de la nueva fase;
## otro jugador -> volteo de todas las fichas.
func _phase_panel_set(p: int, phase: int) -> void:
	if phase == -1:
		_ph_phase = -1
		_ph_p = p
		return
	if _ph_p != p:
		_ph_intro = 0
	_ph_p = p
	_ph_phase = phase
	_ph_fade = 0


## 0x460bb0, una vez por tick nativo.
func _phase_panel_tick() -> void:
	if _ph_intro < 0x200:
		_ph_intro += 8
	elif _ph_fade < 0x100:
		_ph_fade += 4 if _ph_phase == 3 and _ph_fade >= 0x40 and _ph_fade < 0x80 else 8
	elif game == "joey":
		_ph_fade += 8
		if _ph_fade > 0x3ff: _ph_fade = 0x100


func _collect_visual_events() -> bool:
	for n in range(_visual_event_pos, _duel.events.size()):
		var e: Dictionary = _duel.events[n]
		if e.get("kind", "") == "phase":
			_phase_panel_set(int(e.get("p", 0)) & 1, int(e.get("phase", 0)))
	return super._collect_visual_events()


## Ventana de la lista de seleccion del original (FUN_0042e820) mientras el motor la tiene
## abierta (Duel.list_open); se crea al aparecer y se libera sola al cerrarse.
func _show_list() -> void:
	if _list_window != null and is_instance_valid(_list_window):
		return
	_list_window = preload("res://scenes/duel/duel_list_window.gd").new()
	_list_window.setup(self, _duel, game)
	add_child(_list_window)


func _cursor_action() -> int:
	if _duel == null or not _duel.dialog_open.is_empty() or not _duel.list_open.is_empty():
		return -1
	return _duel.cursor_action if _duel.cursor_action > 0 else -1


func _input(event: InputEvent) -> void:
	super._input(event)
	if event is InputEventMouseButton and event.pressed and _duel != null:
		if not _duel.dialog_open.is_empty() and int(_duel.dialog_open.get("type", 0)) not in [8, 9]:
			return  # la ventana del cuadro atiende sus propios clics
		if event.button_index == MOUSE_BUTTON_LEFT:
			_press_bits |= 0x200
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_press_bits |= 0x100


## Ventana del cuadro de dialogo del original (duel_dialog_window.gd; 431db0, 431ee0, 432050,
## 432240, 432400, 432570, 4326a0). El texto lo compone _dialog_text.
func _show_dialog() -> void:
	if _dialog_box != null:
		return
	var window: Node2D = preload("res://scenes/duel/duel_dialog_window.gd").new()
	window.setup(self, _duel, game, _dialog_text(_duel.dialog_open))
	add_child(window)
	_dialog_box = window


## Texto del cuadro con las sustituciones del motor (DuelBase._dialog_subs): el nombre de una
## carta o el texto de otro mensaje en el primer "%s" (0x53fac0), un numero en el primer "%d"
## (0x53fb40) y "<BR>" + otro mensaje al final (0x53f9f0).
func _dialog_text(d: Dictionary) -> String:
	return preload("res://scenes/duel/duel_dialog_text.gd").format(_dialogs, d, true)


func _answer_dialog(value: int) -> void:
	if _dialog_box != null:
		_dialog_box.begin_close()
		_duel.dialog_close(value)
	else:
		_duel.answer_dialog(value)
	_refresh_cursor(true)


func _dialog_gone(window: Node2D) -> void:
	if _dialog_box != window:
		return
	_dialog_box = null
	_duel.dialog_gone()
	_refresh_cursor(true)


func _collect_events() -> void:
	while _event_pos < _duel.events.size():
		var e: Dictionary = _duel.events[_event_pos]
		_event_pos += 1
		var data: Dictionary = e
		if data.get("kind", "") == "detail":
			# Joey 41b050: los comandos que ponen o activan una carta la muestran en el panel.
			_set_preview(int(data["card"]))
			_detail_this_tick = true
		if data.get("kind", "") == "cursor" and _duel.ui_key_cursor:
			# FUN_0053f7e0 -> FUN_00540bd0/00540af0: el teclado desliza el puntero.
			var at := DuelGeometry.location(int(data["p"]) & 1, int(data["loc"]), int(data["i"]), _duel.m.u8(DuelMem.pl(int(data["p"]) & 1) + 2))
			if int(data["loc"]) == 11: at += DuelGeometry.hand_cursor_offset(int(data["p"]) & 1)
			PointerGlide.request(_pointer_pos, at, game)
			_hover_card = _hit_card(PointerGlide.hover(_pointer_pos))
			if not _hover_card.is_empty():
				_set_preview(_hover_card["id"] if _hover_card["known"] else -1)
		var message: int = int(data.get("message", data.get("msg", -1)))
		if message >= 0:
			var pages := _dialog(message)
			if not pages.is_empty():
				_text = "\n".join(pages)

func _redraw() -> void:
	if _duel == null:
		return
	super._redraw()
	for p in 2:
		if _duel.m.u8(0xa11947 + p * DuelMem.PLAYER_SIZE) > 0:
			_register_card(DuelGeometry.DECK[p], CARD_SIZE, p, 13, 0, 0, false)
	_draw_phase_panel()
	var turn := _duel.m.u16(0xa133f2)
	var phase := (turn >> 1) & 7
	_info.text = "Turno: %s · %s" % ["CPU" if turn & 1 else "tuyo", PHASES[phase] if phase < 6 else "-"]
	_refresh_cursor()

## 0x461350 (+0x16c): ficha que el motor ilumina al consultar el panel. Solo lo consulta en
## la espera de la fase principal o de batalla del humano cuando no hay ningun objeto bajo el
## cursor (0x571530 devuelve 0); entonces vale BP desde principal 1 si se puede atacar
## (0x571d30), principal 2 desde batalla y EP. 0x461080 la borra tras dibujarla.
func _phase_glow() -> int:
	if _duel == null or _finished or not _duel.dialog_open.is_empty() or not _hover_card.is_empty():
		return -1
	if (_duel.m.u16(0xa133f2) & 1) != 0 or not _waiting_for_player() or (_visual != null and _visual.busy()):
		return -1
	if (_duel.m.u8(0xa13408) & 2) != 0:
		return -1
	var hover := _phase_hover()
	if _ph_phase == 2 and hover == 3 and _duel.f571d30(0) != 0:
		return 3
	if _ph_phase == 3 and hover == 4:
		return 4
	if hover == 5:
		return 5
	return -1


## 0x461080. Tras el volteo (+0x168 >= 0x200) cada ficha es la celda (columna, fila) de su hoja
## pha_s_*: fila 1 si el jugador +0x15c no es 0; columna 1 para la fase actual, que aparece
## con un fundido sobre la columna 0 (alfa +0x164*2) hasta +0x164 = 0x80. La ficha iluminada
## repite la columna 0 sumada con 0x40 (vtable +0xb0). Durante el volteo la ficha k espera
## hasta +0x168 = 24k+64 con la celda de la fila del jugador anterior y despues muestra la
## columna 8 - min(t,64)/8 de su tira (pha_b_* para el jugador 0, pha_r_* para el 1), 3 px
## mas abajo.
func _draw_phase_panel() -> void:
	if game == "kaiba":
		_draw_phase_panel_kaiba()
		return
	var glow := _phase_glow()
	var fade_alpha: float = _ph_blend.at(["fade", _ph_p, _ph_phase], (_ph_fade << 1) & 0xff) if _ph_fade < 0x80 else 0.0
	# Jo4817e2: pulsa desde256 hasta768, alfa255 hasta reiniciar1024.
	var pulse_alpha: float = 255.0
	if game == "joey" and _ph_fade >= 0x100 and _ph_fade < 0x300:
		pulse_alpha = _ph_blend.at(["pulse", _ph_p, _ph_phase], 127 + absi(DuelVisualMath.cos_fx((_ph_fade - 256) / 2) >> 9))
	var state := [_ph_p, _ph_phase, _ph_fade if game == "joey" or _ph_fade < 0x80 else 0x80, _ph_intro, glow, fade_alpha, pulse_alpha]
	if state == _ph_drawn:
		return
	_ph_drawn = state
	for c in _phase_layer.get_children():
		c.free()
	var row := 1 if _ph_p != 0 else 0
	for k in 6:
		var at := Vector2(_ph_pos[k][0], _ph_pos[k][1]) if game == "joey" else PHASE_ORIGIN + Vector2(0, PHASE_STEP * k)
		var sheet := "%s/duel/phase/pha_s_%s.png" % [game, PHASE_NAMES[k]]
		if _ph_intro < 0x200:
			var t := _ph_intro - k * 24 - 0x40
			if t < 0:
				_phase_cell(sheet, at, Vector2(0, 1 - row), 1.0)
			else:
				var strip := "%s/duel/phase/pha_%s_%s.png" % [game, "b" if _ph_p == 0 else "r", PHASE_NAMES[k]]
				_phase_cell(strip, at + Vector2(0, 3), Vector2(8 - (mini(t, 0x40) >> 3), 0), 1.0)
			continue
		if k == _ph_phase:
			if _ph_fade < 0x80:
				_phase_cell(sheet, at, Vector2(0, row), 1.0)
				_phase_cell(sheet, at, Vector2(1, row), fade_alpha / 255.0)
			elif game == "joey" and _ph_fade >= 0x100:
				_phase_cell(sheet, at, Vector2(0, row), 1.0)
				_phase_cell(sheet, at, Vector2(1, row), pulse_alpha / 255.0)
			else:
				_phase_cell(sheet, at, Vector2(1, row), 1.0)
			continue
		_phase_cell(sheet, at, Vector2(0, row), 1.0)
		if k == glow:
			_phase_cell(sheet, at, Vector2(0, row), 64.0 / 255.0, true)


## Kaiba 0x4631e0. Tras el volteo cada ficha k es una celda de ph_b_k (jugador 0) o ph_r_k
## (jugador 1): la fase actual recorre las celdas 1-7 con (DAT_005b1d38 >> 2) & 15 < 7 y si no
## se queda en la 1; la ficha iluminada (+0x16c) es la celda 1; el resto, la 0. No hay
## fundido (+0x164 solo retrasa el fin de la animacion). Durante el volteo (+0x168 < 0x200) la
## ficha k, con t = +0x168 - 24k - 64, muestra la tira del jugador anterior hasta t = 0x80 y
## despues la del nuevo; con 0 < t < 0x100 la celda 0 se dibuja recortada por la izquierda
## (0x80 - max(|t - 0x80|, 0x40)) * 17 / 64 px sin moverla y encima va ph_mask una linea
## mas arriba.
func _draw_phase_panel_kaiba() -> void:
	if _ph_pos.size() < 12:
		return
	var tick: int = _visual.visual_tick if _visual != null else 0
	var glow := _phase_glow()
	var state := [_ph_p, _ph_phase, _ph_intro, glow, (tick >> 2) & 0xf if _ph_intro >= 0x200 else 0]
	if state == _ph_drawn:
		return
	_ph_drawn = state
	for c in _phase_layer.get_children():
		c.free()
	for k in 6:
		if _ph_intro < 0x200:
			var t := _ph_intro - k * 24 - 0x40
			var index := k + 6 * (int(t < 0x80) ^ _ph_p)
			var at := Vector2(_ph_pos[index][0], _ph_pos[index][1])
			if t > 0 and t < 0x100:
				var left := ((0x80 - maxi(absi(t - 0x80), 0x40)) * 0x11) / 64
				_phase_strip(index, at, 0, left)
				var mask := Assets.texture("kaiba/duel/phase/ph_mask.png")
				if mask != null:
					var s := Sprite2D.new()
					s.texture = mask
					s.centered = false
					s.position = at - Vector2(0, 1)
					_phase_layer.add_child(s)
			else:
				_phase_strip(index, at, 0)
			continue
		var index := k + 6 * _ph_p
		var cell := 0
		if k == _ph_phase:
			var c := (tick >> 2) & 0xf
			cell = c + 1 if c < 7 else 1
		elif k == glow:
			cell = 1
		_phase_strip(index, Vector2(_ph_pos[index][0], _ph_pos[index][1]), cell)


## Celda `cell` (de 8) de la tira ph_* de indice `index`, sin sus `left` primeros px.
func _phase_strip(index: int, at: Vector2, cell: int, left := 0) -> void:
	var tex := Assets.texture("kaiba/duel/phase/ph_%s_%s.png" % ["b" if index < 6 else "r", PHASE_NAMES[index % 6]])
	if tex == null:
		return
	var w := tex.get_width() / 8
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(cell * w + left, 0, w - left, tex.get_height())
	s.position = at
	_phase_layer.add_child(s)


func _phase_cell(path: String, at: Vector2, cell: Vector2, alpha: float, add := false) -> void:
	var tex := Assets.texture(path)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	var cell_size := Vector2(40, 75) if game == "joey" else PHASE_CELL
	s.region_rect = Rect2(cell * cell_size, cell_size)
	s.position = at
	s.modulate.a = alpha
	if add:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = mat
	_phase_layer.add_child(s)


func _card(card_id: int, center: Vector2, size: Vector2, face_up: bool, sideways: bool, flipped: bool) -> Sprite2D:
	# La mano rival permanece oculta, aunque el visor de repeticiones muestra ambas.
	return super._card(card_id, center, size, false if size == HAND_SIZE and flipped else face_up, sideways, flipped)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _duel == null:
		Audio.stop_music()
		Game.open_title(game, "duel")
	elif event is InputEventKey and event.pressed and not event.echo and _duel != null:
		var bit: int = preload("res://core/duel_input.gd").bits(event, game)
		if bit != 0:
			_press_bits |= bit
			if bit & 0xfff00f0:
				_duel.ui_key_cursor = true
	elif event is InputEventMouseMotion and _duel != null:
		if not PointerGlide.drove(event.position):
			PointerGlide.cancel()
			_duel.ui_key_cursor = false
