extends "res://scenes/duel/replay_viewer.gd"
## Scene3 modo6 + objeto scene9 (4375c0/468e30): comandos a ritmo nativo, entrada real.
var _lesson_clock := 0.0
var _press_bits := 0
var _dialog_box: Node2D
var _list_window: Node2D
var _background := Sprite2D.new()
var _back_layout: Layout
var _cursor_target: Dictionary = {}
var _spotlight: Node2D

func _init(game_id: String, what: String) -> void:
	super(game_id, what)

func _ready() -> void:
	super._ready()
	_back_layout = Assets.layout(game + "/tutorial/back.txt")
	_background.centered = false
	_background.z_index = 5
	add_child(_background)
	_spotlight = preload("res://scenes/duel/tutorial_spotlight.gd").new()
	add_child(_spotlight)
	var first: PackedInt32Array = _duel._incoming[0]
	if first[0] == 0x100: _set_background(first[1])

func _start(i: int) -> void:
	super._start(i)
	_duel.auto_answer = -1
	_duel.tutorial_interactive = true
	_wait = 0

func _set_background(index: int) -> void:
	_background.texture = Assets.texture(game + "/tutorial/" + _back_layout.resource(index - 1)) if index > 0 else null
	_background.visible = index > 0

func _process(delta: float) -> void:
	if _duel == null or _files.is_empty(): return
	_lesson_clock += NativeClock.ticks(delta)
	while _lesson_clock >= 1:
		_lesson_clock -= 1
		_tick_card_stats(1.0 / NativeClock.HZ)
		_tutorial.advance(1.0 / NativeClock.HZ)
		if _spotlight != null: _spotlight.advance()
		var visual_busy := _advance_visual(1.0 / NativeClock.HZ)
		if _cursor_visual._scripted:
			_pointer_pos = _cursor_visual.pointer_position
			if PointerGlide.may_warp(): get_viewport().warp_mouse(_pointer_pos)
		_visual.pointer = _pointer_pos
		_update_hover()
		var hover := _hover_card.duplicate()
		if not hover.is_empty():
			hover["card"] = _duel.f5419b0(hover["p"], hover["loc"], hover["i"])
		_duel.set_frame_input(_press_bits, 0, hover, -1)
		if _tutorial.busy() or visual_busy or (_spotlight != null and _spotlight.busy()):
			_press_bits = 0
			continue
		if not _duel.dialog_open.is_empty():
			_show_dialog()
			_press_bits = 0
			continue
		if not _duel.list_open.is_empty():
			_show_list()
			_press_bits = 0
			continue
		if _duel.tutorial_pick_mask != 0 and not hover.is_empty():
			var choice := int(hover["p"]) * 16 + int(hover["loc"]) + int(hover["i"])
			if (_duel.tutorial_pick_mask & (1 << (choice & 31))) != 0 and _duel.f540a50() != 0:
				_duel.f540d80(choice)
				_duel.tutorial_pick_mask = 0
		_step()
		_press_bits = 0
		if _finished:
			_files.clear()
			Game.open_tutorial(game)
			return
	_show_between(_lesson_clock)
	if _spotlight != null and NativeClock.interpolate: _spotlight.show_between(_lesson_clock)

func _step() -> void:
	if _tutorial.busy(): return
	var busy := _duel.frame()
	_collect_visual_events()
	if not _duel.dialog_open.is_empty(): _show_dialog()
	if not _duel.list_open.is_empty(): _show_list()
	if not busy: _finished = true
	_redraw()

func _collect_visual_events() -> bool:
	for i in range(_visual_event_pos, _duel.events.size()):
		var event: Dictionary = _duel.events[i]
		match event.get("kind", ""):
			"tutorial_background": _set_background(int(event["index"]))
			"tutorial_cursor_action": _cursor_target = event
			"tutorial_spotlight", "tutorial_spotlight_close":
				if _spotlight != null: _spotlight.event(event)
	return super._collect_visual_events()

func _update_hover() -> void:
	_hover_card = _hit_card(_pointer_pos)
	if _hover_card.is_empty() and _duel.tutorial_pick_mask != 0: _hover_card = _hit_zone(_pointer_pos)
	_refresh_cursor(true)

func _cursor_action() -> int:
	if _cursor_target.is_empty() or _hover_card.is_empty(): return -1
	if _hover_card["p"] == _cursor_target["p"] and _hover_card["loc"] == _cursor_target["loc"] and _hover_card["i"] == _cursor_target["i"]:
		return int(_cursor_target["action"])
	return -1

func _redraw() -> void:
	super._redraw()
	for p in 2:
		if _duel.m.u8(DuelMem.pl(p) + 3) > 0:
			_register_card(DuelGeometry.DECK[p], CARD_SIZE, p, 13, 0, 0, false)
		_register_card(DuelGeometry.location(p, 12), CARD_SIZE, p, 12, 0, 0, false)

func _show_dialog() -> void:
	if is_instance_valid(_dialog_box): return
	_dialog_box = preload("res://scenes/duel/duel_dialog_window.gd").new()
	# El compositor es común al duelo: 5417e0, sustituciones y anexos nativos de f5.
	_dialog_box.setup(self, _duel, game, preload("res://scenes/duel/duel_dialog_text.gd").format(_dialogs, _duel.dialog_open, true))
	add_child(_dialog_box)

func _answer_dialog(value: int) -> void:
	if is_instance_valid(_dialog_box): _dialog_box.queue_free()
	_dialog_box = null
	_duel.answer_dialog(value)

func _show_list() -> void:
	if is_instance_valid(_list_window): return
	_list_window = preload("res://scenes/duel/duel_list_window.gd").new()
	_list_window.setup(self, _duel, game)
	add_child(_list_window)

func _input(event: InputEvent) -> void:
	super._input(event)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: _press_bits |= 0x200
		elif event.button_index == MOUSE_BUTTON_RIGHT: _press_bits |= 0x100
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER]: _press_bits |= 1
		elif event.keycode == KEY_ESCAPE: _press_bits |= 2

func _unhandled_input(event: InputEvent) -> void:
	if not _duel.dialog_open.is_empty() or not _duel.list_open.is_empty(): return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]):
		var reading: bool = _tutorial.busy()
		_tutorial.accept()
		if reading: _press_bits = 0
		get_viewport().set_input_as_handled()
