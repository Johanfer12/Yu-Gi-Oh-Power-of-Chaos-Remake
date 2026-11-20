extends Node2D
##41c920/41c980: la columna pasiva permanece dibujada incluso sin texto.
const CELL := 16
const THUMB_TRAVEL := 112
const LINE_STEP := 19
var _texture: Texture2D
var _scroll: ScrollContainer
var _input_area := Control.new()
var _native_input := false
var _press_part := 0
var _drag_offset := 0
var _pointer := Vector2i.ZERO
var _repeat := 0.0


func setup(game: String, scroll: ScrollContainer) -> void:
	_texture = Engine.get_main_loop().root.get_node("Assets").texture("%s/duel/detail/scroll_bar.png" % game)
	_scroll = scroll
	_native_input = game == "joey"
	if _input_area.get_parent() == null:
		_input_area.size = Vector2(CELL, 160)
		_input_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_input_area.mouse_force_pass_scroll_events = false
		_input_area.gui_input.connect(_column_input)
		add_child(_input_area)
	#41c920 Joey;411850 Kaiba /4119b0 Yugi conservan su origen propio.
	position = Vector2(186, 364) if game == "joey" else Vector2(189, 365)


func _process(delta: float) -> void:
	if is_instance_valid(_scroll):
		var maximum := _maximum()
		_input_area.mouse_filter = Control.MOUSE_FILTER_STOP if _native_input and maximum > 0 else Control.MOUSE_FILTER_IGNORE
		if maximum == 0:
			_press_part = 0
		elif _press_part != 0 and _press_part != 3 and _part(_pointer, _scroll.scroll_vertical, maximum) == _press_part:
			_repeat -= NativeClock.ticks(delta)
			if _repeat <= 0:
				var steps := 1 + floori(-_repeat)
				_repeat += steps
				_scroll.scroll_vertical += steps * _part_step(_press_part)
	queue_redraw()


func _maximum() -> int:
	var bar := _scroll.get_v_scroll_bar()
	return maxi(0, int(bar.max_value - bar.page))


## 4867f0/4869a0: flechas de 1 px, pista de 19 px y arrastre del pulgar.
static func _part(at: Vector2i, value: int, maximum: int) -> int:
	if not Rect2i(0, 0, CELL, 160).has_point(at): return 0
	if at.y < CELL: return -1
	if at.y >= 144: return 1
	var thumb := CELL + _thumb_offset(value, maximum)
	if at.y < thumb: return -2
	return 2 if at.y >= thumb + CELL else 3


static func _part_step(part: int) -> int:
	return part if absi(part) == 1 else signi(part) * LINE_STEP


static func _thumb_offset(value: int, maximum: int) -> int:
	return (maximum / 2 + THUMB_TRAVEL * value) / maximum


func _column_input(event: InputEvent) -> void:
	var maximum := _maximum()
	if maximum == 0: return
	if event is InputEventMouseMotion:
		_pointer = Vector2i(event.position.floor())
		if _press_part == 3:
			var thumb := clampi(_pointer.y - CELL - _drag_offset, 0, THUMB_TRAVEL)
			_scroll.scroll_vertical = (THUMB_TRAVEL / 2 + maximum * thumb) / THUMB_TRAVEL
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				_press_part = 0
				return
			_pointer = Vector2i(event.position.floor())
			_press_part = _part(_pointer, _scroll.scroll_vertical, maximum)
			if _press_part == 3:
				_drag_offset = _pointer.y - CELL - _thumb_offset(_scroll.scroll_vertical, maximum)
			elif _press_part != 0:
				_scroll.scroll_vertical += _part_step(_press_part)
				_repeat = 16
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_scroll.scroll_vertical += -LINE_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else LINE_STEP


static func plan(active: bool, value: int, maximum: int, state: int = 0) -> Array:
	if not active: return [{"x":186,"y":364,"rect":[0,0,16,162]}]
	var offset := _thumb_offset(value, maximum)
	return [{"x":186,"y":364,"rect":[32 if state == -1 else 16,0,48 if state == -1 else 32,16]},
		{"x":186,"y":508,"rect":[32 if state == 1 else 16,144,48 if state == 1 else 32,160]},
		{"x":186,"y":380+offset,"rect":[16,16,32,32]}]
func _draw() -> void:
	if _texture == null or not is_instance_valid(_scroll): return
	var bar := _scroll.get_v_scroll_bar()
	var maximum := _maximum()
	var state := _press_part if absi(_press_part) == 1 and maximum > 0 \
			and _part(_pointer, int(bar.value), maximum) == _press_part else 0
	for row in plan(maximum > 0, int(bar.value), maxi(1, maximum), state):
		var r: Array = row.rect
		var rect := Rect2(r[0],r[1],r[2]-r[0],r[3]-r[1])
		draw_texture_rect_region(_texture, Rect2(Vector2(row.x,row.y)-Vector2(186,364),rect.size),rect)
