extends CanvasLayer
## Manejo exclusivo de movil: menu de clics o toque corto/pulsacion larga.
var _menu := Panel.new()
var _left := Button.new()
var _right := Button.new()
var _target := Vector2.ZERO
var _finger := -1
var _previous_emulation := true
var _pressed_button := MOUSE_BUTTON_NONE
var _dispatching := false
var _hold_time := 0.0
var _holding := false
var _start := Vector2.ZERO
var _generation := 0
var _action_label := Label.new()
var _actions: Array[int] = []
var _choices: Array[Button] = []
var _right_available := false
var _preparing := false
var _pending_release := false
var _confirm_scene: Node
var _confirm_until := 0
var _tribute_hint := Label.new()
var _deck_touch := false
var _drag_starting := false
var _pending_drop := false
var _selected_card := ""
var _touch_card := ""
var _scroll_axis := ""
var _scroll_kind := ""
var _scroll_node: Node
var _scrolling := false
var _scroll_last := Vector2.ZERO
var _scroll_amount := 0.0
const HOLD_SECONDS := 0.5
const ACTION_NAMES := {1: "Invocar", 2: "Voltear", 3: "Atacar", 4: "Activar", 5: "Colocar", 6: "Posición de defensa", 7: "Posición de ataque", 8: "Robar", 9: "Rendirse", 10: "Fusión", 11: "Invocación especial en ataque", 12: "Invocación especial en defensa"}

func _scene_point(point: Vector2) -> Vector2:
	return Game._screen.get_viewport().get_screen_transform().affine_inverse() * _physical(point)

func _has_right_action(point: Vector2) -> bool:
	var scene: Node = Game._screen
	if not is_instance_valid(scene): return false
	var script_path: String = scene.get_script().resource_path
	var local := _scene_point(point)
	if PlatformInput._normal_duel_active():
		if scene._duel == null or _material_selection(scene) or not scene._waiting_for_player() or scene._visual.busy(): return false
		# Los botones Si/No y las fases se eligen directamente. El derecho alterna acciones de cartas.
		if not scene._duel.dialog_open.is_empty() or not scene._duel.list_open.is_empty(): return false
		var hit: Dictionary = scene._hit_card(local)
		return not hit.is_empty() and int(hit.get("p", -1)) == 0 and int(hit.get("loc", -1)) in [0, 5, 11]
	if script_path.ends_with("deck_editor.gd"):
		return scene._modal == null and (scene._button_at(local) == "filter_label" or not scene._hit_at(local).is_empty())
	return false

func _mode() -> String:
	return str(SaveData.data.get("launcher", {}).get("pointer_mode", "menu"))

func _process(delta: float) -> void:
	if is_instance_valid(_confirm_scene) and Game._screen == _confirm_scene and Time.get_ticks_msec() < _confirm_until:
		var question: Dictionary = _confirm_scene._duel.dialog_open
		# Invocar/Colocar ya se eligio: aceptar solo su pregunta redundante de sacrificio.
		if _pressed_button == MOUSE_BUTTON_NONE and not _dispatching and is_instance_valid(_confirm_scene._dialog_box) and not question.get("closing", false) and int(question.get("type", -1)) == 1 and int(question.get("msg", -1)) in [1, 2]:
			_confirm_scene._answer_dialog(1)
			_confirm_scene = null
	_update_tribute_hint()
	if not _holding or _pressed_button != MOUSE_BUTTON_NONE or _scrolling or (_scroll_kind != "" and _scroll_kind != "bag"): return
	if _touch_card == "" and _deck_touch and _mode() == "menu": return
	# Gesture thresholds use real seconds even when gameplay simulation runs at 2x.
	_hold_time += delta / maxf(Engine.time_scale, 0.001)
	if _hold_time >= HOLD_SECONDS:
		_holding = false
		if _touch_card != "" and _selected_card != _touch_card:
			_finish_card_tap(_target)
		elif _touch_card.begins_with("duel:") and _actions.has(5):
			_execute_action.call_deferred(5, _target)
		else: _dispatch_click.call_deferred(MOUSE_BUTTON_RIGHT, _target)

func _ready() -> void:
	layer = 100
	_tribute_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tribute_hint.add_theme_color_override("font_color", Color.YELLOW)
	_tribute_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_tribute_hint.add_theme_constant_override("shadow_offset_x", 2)
	_tribute_hint.add_theme_constant_override("shadow_offset_y", 2)
	_tribute_hint.add_theme_font_size_override("font_size", 20)
	_tribute_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tribute_hint.hide()
	add_child(_tribute_hint)
	_previous_emulation = Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = false
	_menu.size = Vector2(264, 82)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.visible = false
	add_child(_menu)
	_action_label.position = Vector2(4, 2)
	_action_label.size = Vector2(256, 24)
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(_action_label)
	_action_label.text = "Acciones"
	_choices.assign([_left, _right])
	for button in _choices:
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu.add_child(button)

func _exit_tree() -> void:
	Input.emulate_mouse_from_touch = _previous_emulation
	_release()

func cancel() -> void:
	_menu.hide()
	_tribute_hint.hide()
	_selected_card = ""
	_touch_card = ""
	_scroll_kind = ""
	_scrolling = false
	_confirm_scene = null
	_finger = -1
	_holding = false
	_preparing = false
	_drag_starting = false
	_generation += 1
	_release()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
		if event.index == _finger and _holding:
			_target = event.position
			if _scroll_drag(_target): return
			if _drag_starting: return
			if _pressed_button == MOUSE_BUTTON_NONE and _target.distance_to(_start) > 12:
				_begin_drag(_start)
				return
			_move_mouse(_target)
		return
	if event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
		if event.canceled:
			cancel()
			return
		if not event.pressed:
			if event.index == _finger:
				_finger = -1
				if _scrolling:
					_scrolling = false
					_scroll_kind = ""
					_holding = false
					_selected_card = ""
					return
				_scroll_kind = ""
				if _drag_starting:
					_pending_drop = true
					return
				if _preparing:
					_pending_release = true
					return
				if _holding:
					_holding = false
					if _pressed_button == MOUSE_BUTTON_NONE:
						if _touch_card != "": _finish_card_tap(_target)
						elif _deck_touch and _mode() == "menu": _show_at(_target)
						else: _dispatch_click.call_deferred(MOUSE_BUTTON_LEFT, _target)
					else: _release()
			return
		if _dispatching or _preparing or (_finger != -1 and _finger != event.index): return
		_finger = event.index
		if _menu.visible:
			_choose(event.position)
			return
		_actions.clear()
		_touch_card = _card_identity(event.position)
		if _touch_card == "": _selected_card = ""
		_deck_touch = Game._screen.get_script().resource_path.ends_with("deck_editor.gd") and Game._screen._modal == null and not Game._screen._hit_at(_scene_point(event.position)).is_empty()
		_right_available = _has_right_action(event.position)
		_target = event.position
		_start = _target
		_hold_time = 0.0
		_pending_release = false
		_pending_drop = false
		_scroll_candidate(_target)
		_move_mouse(_target)
		if _scroll_kind != "":
			_holding = true
			return
		if _right_available and PlatformInput._normal_duel_active():
			_prepare_card(_target)
			return
		_begin_touch(_target)
	elif event is InputEventMouseButton and _menu.visible:
		get_viewport().set_input_as_handled()
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT: _choose(event.position)

func _prepare_card(point: Vector2) -> void:
	_preparing = true
	var generation := _generation
	# Dar tiempo a que el motor calcule las acciones de la carta recien senalada.
	await get_tree().create_timer(0.10).timeout
	if generation != _generation: return
	_preparing = false
	var mask: int = Game._screen._duel.m.u16(0xa1340a)
	_right_available = _has_right_action(point) and mask != 0 and (mask & (mask - 1)) != 0
	_actions.clear()
	if _right_available:
		var d = Game._screen._duel
		var ordered: Array[int] = []
		for i in 12:
			var action: int = d.m.u8(0x59df1c + i * 4)
			if mask & (1 << action): ordered.append(action + 1)
		var first := ordered.find(d.cursor_action)
		for i in ordered.size(): _actions.append(ordered[(maxi(0, first) + i) % ordered.size()])
	_begin_touch(point)

func _begin_touch(point: Vector2) -> void:
	if _touch_card != "":
		_holding = true
		if _pending_release:
			_holding = false
			_finish_card_tap(point)
	elif _deck_touch:
		# Esperar movimiento antes de abrir opciones; el arrastre tiene prioridad en ambos modos.
		_holding = true
	elif not _right_available:
		_holding = true
		_press(MOUSE_BUTTON_LEFT, _target)
		if _pending_release:
			_holding = false
			_release()
	elif _mode() == "hold":
		_holding = true
		if _pending_release:
			_holding = false
			_dispatch_click.call_deferred(MOUSE_BUTTON_LEFT, point)
	else: _show_at(point)

func _begin_drag(start: Vector2) -> void:
	var generation := _generation
	_drag_starting = true
	_menu.hide()
	_press(MOUSE_BUTTON_LEFT, start)
	# El editor toma la carta al siguiente tick: no mover el raton al destino antes de agarrarla.
	await get_tree().create_timer(2.0 / NativeClock.HZ).timeout
	if generation != _generation: return
	_drag_starting = false
	_move_mouse(_target)
	if _pending_drop:
		_holding = false
		_release(_target)


func _show_at(point: Vector2) -> void:
	_target = point
	var count := maxi(2, _actions.size())
	while _choices.size() < count:
		var extra := Button.new()
		extra.focus_mode = Control.FOCUS_NONE
		extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu.add_child(extra)
		_choices.append(extra)
	_menu.size = Vector2(360, 30 + 56 * int(ceil(count / 2.0)))
	_action_label.size.x = 352
	for i in _choices.size():
		var button := _choices[i]
		button.visible = i < count
		button.position = Vector2(4 + 178 * (i % 2), 28 + 56 * int(i / 2))
		button.size = Vector2(174, 52)
		button.add_theme_font_size_override("font_size", 14)
		button.text = ACTION_NAMES.get(_actions[i], "Elegir") if i < _actions.size() else ("Clic" if i == 0 else "Clic derecho")
		if _actions.is_empty() and Game._screen.get_script().resource_path.ends_with("deck_editor.gd"):
			button.text = "Seleccionar" if i == 0 else "Soltar selección" if Game._screen._held != 0 else "Ordenar"
			if Game._screen._button_at(_scene_point(point)) == "filter_label": button.text = "Siguiente filtro" if i == 0 else "Filtro anterior"
	var bounds := get_viewport().get_visible_rect()
	var x := clampf(point.x - _menu.size.x * 0.5, bounds.position.x + 4, bounds.end.x - _menu.size.x - 4)
	var y := point.y - _menu.size.y - 16
	if y < bounds.position.y + 4: y = point.y + 16
	y = clampf(y, bounds.position.y + 4, bounds.end.y - _menu.size.y - 4)
	_menu.position = Vector2(x, y)
	_menu.show()
	# La opcion elegida selecciona y ejecuta la accion nativa en un solo paso.
	_move_mouse(point)

func _choose(point: Vector2) -> void:
	var chosen := -1
	for i in _choices.size():
		if _choices[i].visible and _choices[i].get_global_rect().has_point(point): chosen = i
	_menu.hide()
	if chosen < 0: return
	if chosen < _actions.size(): _execute_action.call_deferred(_actions[chosen], _target)
	else: _dispatch_click.call_deferred(MOUSE_BUTTON_LEFT if chosen == 0 else MOUSE_BUTTON_RIGHT, _target)

func _execute_action(action: int, point: Vector2) -> void:
	if action in [1, 5]:
		_confirm_scene = Game._screen
		_confirm_until = Time.get_ticks_msec() + 5000
	var generation := _generation
	_dispatching = true
	_move_mouse(point)
	var d = Game._screen._duel
	for attempt in 12:
		if generation != _generation: break
		if d.cursor_action == action:
			# El derecho solo selecciona en el original; el izquierdo ejecuta sin otra interaccion.
			_press(MOUSE_BUTTON_LEFT, point)
			await get_tree().create_timer(2.0 / NativeClock.HZ).timeout
			_release(point)
			break
		var previous: int = d.cursor_action
		_press(MOUSE_BUTTON_RIGHT, point)
		await get_tree().create_timer(2.0 / NativeClock.HZ).timeout
		_release(point)
		var deadline := Time.get_ticks_msec() + 1000
		while generation == _generation and d.cursor_action == previous and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		if d.cursor_action == previous: break
	_dispatching = false

func _physical(point: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * point

func _move_mouse(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _physical(point)
	motion.global_position = motion.position
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if _pressed_button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT if _pressed_button == MOUSE_BUTTON_RIGHT else 0
	Input.parse_input_event(motion)

func _dispatch_click(button: MouseButton, point: Vector2) -> void:
	var generation := _generation
	_dispatching = true
	_move_mouse(point)
	await get_tree().process_frame
	if generation != _generation:
		_dispatching = false
		return
	_press(button, point)
	await get_tree().process_frame
	_release(point)
	_dispatching = false

func _press(button: MouseButton, point: Vector2) -> void:
	_pressed_button = button
	var press := InputEventMouseButton.new()
	press.position = _physical(point)
	press.global_position = press.position
	press.button_index = button
	press.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	press.pressed = true
	press.set_meta("platform_touch", true)
	Input.parse_input_event(press)

func _release(point: Vector2 = _target) -> void:
	if _pressed_button == MOUSE_BUTTON_NONE: return
	var release := InputEventMouseButton.new()
	release.position = _physical(point)
	release.global_position = release.position
	release.button_index = _pressed_button
	release.pressed = false
	release.set_meta("platform_touch", true)
	Input.parse_input_event(release)
	_pressed_button = MOUSE_BUTTON_NONE


# Solo regiones desplazables: el resto conserva clic, opciones y arrastre.
func _scroll_candidate(point: Vector2) -> void:
	_scroll_kind = ""
	_scroll_node = null
	_scrolling = false
	_scroll_amount = 0.0
	_scroll_axis = ""
	_scroll_last = _scene_point(point)
	var scene: Node = Game._screen
	var path: String = scene.get_script().resource_path
	var local := _scroll_last
	if path.ends_with("deck_editor.gd"):
		if is_instance_valid(scene._modal):
			if scene._modal.get_script().resource_path.ends_with("deck_warning_dialog.gd"):
				var body: Control = scene._modal._body.get_parent()
				if body.get_global_rect().has_point(local):
					_scroll_kind = "bar"
					_scroll_node = scene._modal._scroll
			elif scene._modal.get_script().resource_path.ends_with("deck_file_dialog.gd") and scene._modal._list_rect.has_point(local - scene._modal.position):
				_scroll_kind = "files"
				_scroll_node = scene._modal
			return
		if local.x < 224 and local.y >= 370 and is_instance_valid(scene._detail_scroll):
			_scroll_kind = "bar"
			_scroll_node = scene._detail_scroll
		elif not scene._swap and scene._zone_at(local) == scene.BAG and scene._button_at(local) == "":
			_scroll_kind = "bag"
			_scroll_node = scene
	elif path.ends_with("card_list.gd"):
		if scene._text_clip.get_rect().has_point(local):
			if scene.has_method("_scroll_text"):
				_scroll_kind = "text"
				_scroll_node = scene
			else:
				_scroll_kind = "bar"
				_scroll_node = scene._scroll
		elif scene.has_method("_hit_slot"):
			if scene._hit_slot(local) != -1:
				_scroll_kind = "pages"
				_scroll_node = scene
		elif scene._hit(Vector2i(local)) >= 0 and scene._hit(Vector2i(local)) < scene.PER_PAGE:
			_scroll_kind = "pages"
			_scroll_node = scene
	elif PlatformInput._normal_duel_active():
		var list: Node = scene._list_window
		if is_instance_valid(list) and list.has_scroll and Rect2(Vector2(list.center) - Vector2(list.size) / 2, Vector2(list.size)).has_point(local):
			_scroll_kind = "list"
			_scroll_node = list
	if _scroll_kind == "":
		_scroll_node = _scroll_control(scene, local)
		if _scroll_node != null: _scroll_kind = "control"

func _scroll_control(node: Node, point: Vector2) -> Node:
	for child in node.get_children():
		var found := _scroll_control(child, point)
		if found != null: return found
	if node is ScrollContainer and node.is_visible_in_tree() and node.get_global_rect().has_point(point): return node
	return null

func _scroll_drag(point: Vector2) -> bool:
	if _scroll_kind == "" or not is_instance_valid(_scroll_node): return false
	var local := _scene_point(point)
	var distance := local - _scene_point(_start)
	var horizontal := _scroll_kind in ["pages", "list"]
	if not _scrolling:
		if distance.length() < 12: return true
		# En bolsa, gesto vertical recorre la lista; horizontal arrastra la carta.
		if _scroll_kind == "bag" and absf(distance.x) > absf(distance.y):
			_scroll_kind = ""
			return false
		_scrolling = true
		_selected_card = ""
		_scroll_axis = "x" if horizontal and absf(distance.x) > absf(distance.y) else "y"
		_menu.hide()
		_release()
	var delta := _scroll_last - local
	_scroll_last = local
	match _scroll_kind:
		"bar", "control":
			_scroll_amount += delta.y
			var pixels := int(_scroll_amount)
			_scroll_amount -= pixels
			if _scroll_kind == "bar": _scroll_node.set_value(_scroll_node.value + pixels)
			else: _scroll_node.scroll_vertical += pixels
		"text": _scroll_node._scroll_text(delta.y)
		_:
			_scroll_amount += delta.x if _scroll_axis == "x" else delta.y
			var pitch := 80.0 if _scroll_kind == "pages" else 32.0
			while absf(_scroll_amount) >= pitch:
				var step := 1 if _scroll_amount > 0 else -1
				_scroll_amount -= step * pitch
				if _scroll_kind == "pages":
					if _scroll_node.has_method("_turn_page"): _scroll_node._turn_page(step)
					else:
						var page := clampi(_scroll_node._page + step, 0, maxi(0, _scroll_node._pages - 1))
						if page != _scroll_node._page: _scroll_node._set_page(page, step > 0)
				elif _scroll_kind == "bag": _scroll_node._trunk_scroll = clampi(_scroll_node._trunk_scroll + step, 0, maxi(0, _scroll_node._view.size() - _scroll_node.TRUNK_ROWS))
				elif _scroll_kind == "files":
					_scroll_node._scroll = clampi(_scroll_node._scroll + step, 0, maxi(0, _scroll_node._files.size() - _scroll_node._visible_rows()))
					_scroll_node.queue_redraw()
				else:
					_scroll_node.row = clampi(_scroll_node.row + step, _scroll_node.row_min, _scroll_node.row_max)
					_scroll_node.queue_redraw()
	return true


func _card_identity(point: Vector2) -> String:
	var scene: Node = Game._screen
	var path: String = scene.get_script().resource_path
	var at := _scene_point(point)
	if path.ends_with("deck_editor.gd") and scene._modal == null:
		var hit: Dictionary = scene._hit_at(at)
		if not hit.is_empty(): return "deck:%s" % hit["key"]
	if PlatformInput._normal_duel_active() and scene._duel != null and scene._duel.dialog_open.is_empty() and scene._duel.list_open.is_empty() and not _material_selection(scene):
		var hit: Dictionary = scene._hit_card(at)
		if not hit.is_empty(): return "duel:%s:%s:%s:%s" % [hit["p"], hit["loc"], hit["i"], hit["id"]]
	return ""

func _finish_card_tap(point: Vector2) -> void:
	if _selected_card != _touch_card:
		_selected_card = _touch_card
		var scene: Node = Game._screen
		if _deck_touch:
			var hit: Dictionary = scene._hit_at(_scene_point(point))
			if not hit.is_empty(): scene._show_detail(CardDB.by_id(scene._key_id(hit["key"])))
		return
	if _touch_card.begins_with("duel:") and not _actions.is_empty():
		_execute_action.call_deferred(1 if _actions.has(1) else _actions[0], point)
	else: _dispatch_click.call_deferred(MOUSE_BUTTON_LEFT, point)



func _material_selection(scene: Node) -> bool:
	if scene._duel == null: return false
	var action: int = scene._duel.m.u32(0xa13408)
	return (action & 2) != 0

func _update_tribute_hint() -> void:
	_tribute_hint.hide()
	var scene: Node = Game._screen
	if not is_instance_valid(scene) or not PlatformInput._normal_duel_active() or scene._duel == null: return
	var d = scene._duel
	var action: int = d.m.u32(0xa13408)
	if not _material_selection(scene) or ((action >> 2) & 15) not in [0, 4] or not d.dialog_open.is_empty(): return
	var state: int = d.m.u8(0xa1340d)
	if state not in [2, 3, 4, 5, 10, 11]: return
	_tribute_hint.text = "Toca un monstruo para sacrificarlo" if state in [10, 11] else "Selecciona el primer sacrificio" if state in [2, 3] else "Selecciona el segundo sacrificio"
	var bounds := get_viewport().get_visible_rect()
	_tribute_hint.position = bounds.position + Vector2(4, 8)
	_tribute_hint.size = Vector2(bounds.size.x - 8, 36)
	_tribute_hint.show()
