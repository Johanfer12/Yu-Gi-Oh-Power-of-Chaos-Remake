extends Node
## D28: adaptador portable. Emite la entrada de raton/teclado de las escenas;
## no modifica comandos, memoria ni reglas del motor.
const DEADZONE := 0.2
const CURSOR_SPEED := 480.0
const NativeInput := preload("res://core/duel_input.gd")
const BUTTON_KEYS := {JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
	JOY_BUTTON_DPAD_LEFT: KEY_LEFT, JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT,
	JOY_BUTTON_X: KEY_ENTER, JOY_BUTTON_Y: KEY_TAB, JOY_BUTTON_START: KEY_ESCAPE}

class Pointer:
	extends Node2D
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 7, Color(0, 0, 0, 0.8))
		draw_arc(Vector2.ZERO, 6, 0, TAU, 24, Color.WHITE, 2, true)
		draw_line(Vector2(-10, 0), Vector2(10, 0), Color.WHITE)
		draw_line(Vector2(0, -10), Vector2(0, 10), Color.WHITE)

var cursor := Vector2(400, 300)
var _axis := Vector2.ZERO
var _buttons := 0
var _primary_touch := -1
var _secondary_touch := -1
var _pointer := Pointer.new()
var _layer := CanvasLayer.new()
var _controller := -1
var _keys := {}
var _dispatching_touch := false


func mouse_pressed(button: MouseButton) -> bool:
	return bool(_buttons & (1 << (button - 1))) or Input.is_mouse_button_pressed(button)


func key_pressed(code: Key) -> bool:
	return _keys.has(code) or Input.is_key_pressed(code)


func _ready() -> void:
	_layer.layer = 100
	add_child(_layer)
	_layer.add_child(_pointer)
	_pointer.hide()
	Input.joy_connection_changed.connect(_joy_connection_changed)


func _joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and device == _controller:
		_axis = Vector2.ZERO
		for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if _buttons & (1 << (button - 1)):
				_mouse_button(button, false)
		for key in _keys.keys():
			var event := InputEventKey.new()
			event.keycode = key
			event.pressed = false
			_dispatch(event)
		_keys.clear()
		_pointer.hide()
		_controller = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree():
		_primary_touch = -1
		_secondary_touch = -1
		_joy_connection_changed(_controller, false)


func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and is_instance_valid(Game._mobile_pointer):
		return
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		_pointer.hide()
		cursor = _touch_position(event.position)
	if event is InputEventScreenTouch or event is InputEventScreenDrag \
			or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		consume(event)


## Separado de _input para comprobar eventos sinteticos sin hardware fisico.
func consume(event: InputEvent) -> void:
	_dispatching_touch = event is InputEventScreenTouch or event is InputEventScreenDrag
	if event is InputEventScreenTouch:
		if event.pressed:
			if _primary_touch < 0:
				_primary_touch = event.index
				cursor = _touch_position(event.position)
				_motion()
				_mouse_button(MOUSE_BUTTON_LEFT, true)
			elif _secondary_touch < 0:
				_secondary_touch = event.index
				_mouse_button(MOUSE_BUTTON_LEFT, false)
				_mouse_button(MOUSE_BUTTON_RIGHT, true)
		elif event.index == _primary_touch:
			cursor = _touch_position(event.position)
			_motion()
			_mouse_button(MOUSE_BUTTON_LEFT, false)
			_primary_touch = -1
		elif event.index == _secondary_touch:
			_mouse_button(MOUSE_BUTTON_RIGHT, false)
			_secondary_touch = -1
	elif event is InputEventScreenDrag and event.index == _primary_touch:
		cursor = _touch_position(event.position)
		_motion()
	elif event is InputEventJoypadMotion:
		_controller = event.device
		if event.axis == JOY_AXIS_LEFT_X: _axis.x = event.axis_value
		if event.axis == JOY_AXIS_LEFT_Y: _axis.y = event.axis_value
	elif event is InputEventJoypadButton:
		_controller = event.device
		_pointer.show()
		if event.button_index in BUTTON_KEYS:
			_key(BUTTON_KEYS[event.button_index], event.pressed)
		elif event.button_index in [JOY_BUTTON_A, JOY_BUTTON_B]:
			_motion()
			_mouse_button(MOUSE_BUTTON_LEFT if event.button_index == JOY_BUTTON_A else MOUSE_BUTTON_RIGHT, event.pressed)
		elif event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			var wheel := MOUSE_BUTTON_WHEEL_UP if event.button_index == JOY_BUTTON_LEFT_SHOULDER else MOUSE_BUTTON_WHEEL_DOWN
			_mouse_button(wheel, true)
			_mouse_button(wheel, false)
	_dispatching_touch = false


func _target() -> Viewport:
	if is_instance_valid(Game._screen) and Game._screen.is_inside_tree():
		return Game._screen.get_viewport()
	return get_viewport()


func _touch_position(position: Vector2) -> Vector2:
	if is_instance_valid(Game._screen_host) and Game._screen_host.get("_container") != null:
		var container: Control = Game._screen_host.get("_container")
		return container.get_global_transform_with_canvas().affine_inverse() * position
	return position


func _process(delta: float) -> void:
	if _axis.length() > DEADZONE:
		var speed := (_axis.length() - DEADZONE) / (1.0 - DEADZONE)
		cursor += _axis.normalized() * minf(speed, 1.0) * CURSOR_SPEED * delta
		var area := _target().get_visible_rect()
		cursor = cursor.clamp(area.position, area.end - Vector2.ONE)
		_motion()
		_pointer.show()
	_pointer.position = cursor
	if is_instance_valid(Game._screen_host) and Game._screen_host.get("_container") != null:
		var container: Control = Game._screen_host.get("_container")
		_pointer.position = container.get_global_transform_with_canvas() * cursor


func _dispatch(event: InputEvent) -> void:
	if _dispatching_touch: event.set_meta("platform_touch", true)
	if event is InputEventMouse: event.device = InputEvent.DEVICE_ID_EMULATION
	var viewport := _target()
	if viewport != get_viewport(): Game._input(event)
	viewport.push_input(event, true)


func _motion() -> void:
	var event := InputEventMouseMotion.new()
	event.position = cursor
	event.global_position = cursor
	event.button_mask = _buttons
	_dispatch(event)


func _mouse_button(button: MouseButton, pressed: bool) -> void:
	var mask := 1 << (button - 1)
	if button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if pressed: _buttons |= mask
		else: _buttons &= ~mask
	var event := InputEventMouseButton.new()
	event.position = cursor
	event.global_position = cursor
	event.button_index = button
	event.button_mask = _buttons
	event.pressed = pressed
	_dispatch(event)


func _normal_duel_active() -> bool:
	if not is_instance_valid(Game._screen): return false
	var scene_script: Script = Game._screen.get_script()
	while scene_script != null:
		if scene_script.resource_path.ends_with("normal_duel.gd"): return true
		scene_script = scene_script.get_base_script()
	return false


func _key(code: Key, pressed: bool) -> void:
	# Respeta reasignaciones del duelo; el resto de menus conserva sus ui_*.
	if _normal_duel_active():
		var slot: int = {KEY_UP: 1, KEY_DOWN: 2, KEY_LEFT: 3, KEY_RIGHT: 4, KEY_ENTER: 6,
			KEY_TAB: 19 if Game.current_game == "joey" else 11,
			KEY_ESCAPE: NativeInput.cancel_slot(Game.current_game)}.get(code, -1)
		var keys: Array = NativeInput.options(Game.current_game).get("keys", {}).get(str(slot), [code])
		if keys.is_empty(): return
		code = int(keys[0]) as Key
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	if pressed: _keys[code] = true
	else: _keys.erase(code)
	_dispatch(event)
