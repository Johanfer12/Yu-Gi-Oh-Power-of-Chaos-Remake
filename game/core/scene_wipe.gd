extends CanvasLayer
## D10: Y532390/40a260/530e30 -> PE5aa590[13]=525bf0.
## Dos snapshots; el destino queda sin actualizacion/entrada durante16 ticks.
const CLOCK := preload("res://core/native_clock.gd")
const SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D next_frame : filter_nearest;
uniform int progress = 0;
uniform int mode = 19;
void fragment() {
	int row = int(floor(UV.y * 600.0)) % 4;
	int x = int(floor(UV.x * 800.0));
	int phase = row == 0 || row == 2 ? progress : progress - 128;
	int extent = (800 * phase) / 128;
	bool left = row == 0 || row == 1;
	bool visible = phase > 0 && (left ? x < min(800, extent) : x >= max(0, 800 - extent - 1));
	if (mode == 30 || mode == 32) {
		int dy = int(floor(UV.y * 600.0)) - 300;
		int diameter = ((mode == 30 ? 1708 : 1400) * progress) / 256;
		int half_height = diameter / 2;
		int span_squared = (diameter * diameter) / 4 - dy * dy;
		int span = int(sqrt(float(max(0, span_squared))) * (mode == 30 ? 1.0 : 2.0));
		int start = mode == 30 ? 0 : max(0, 400 - span / 2);
		visible = dy >= -half_height && dy < half_height && x >= start && x < start + span;
	} else if (mode == 42) {
		visible = progress > 0 && ((int(floor(UV.y * 600.0)) & 15) <= (progress >> 4));
	} else if (mode == 75) {
		int y = int(floor(UV.y * 600.0));
		int band = y / 16;
		int total = (600 + 17) / 16;
		int length = min(16, ((total + 16) * progress) / 256 - band);
		int bottom = band * 16 + length;
		// 52d5fb..52d606: el extremo exclusivo que excede600 se recorta a599.
		if (bottom > 600) { bottom = 599; }
		visible = progress > 0 && y < bottom;
	}
	COLOR = visible ? texture(next_frame, UV) : texture(TEXTURE, UV);
}
"""
var mode := 0x13
var progress := 0
var _clock := 0.0
var _first_frame_after_capture := false
var _screen: Node
var _previous_mode: int
var _old: Texture2D
var _new: Texture2D
var _material := ShaderMaterial.new()
var _frame: TextureRect
var _waves: Array[Node2D] = []

func _init(old_frame: Texture2D, new_frame: Texture2D, screen: Node = null, previous_mode := 0, effect := 0x13) -> void:
	mode = effect
	_old = old_frame
	_new = new_frame
	_screen = screen
	_previous_mode = previous_mode

func _ready() -> void:
	layer = 1000
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material.shader = shader
	_material.set_shader_parameter("mode", mode)
	_material.set_shader_parameter("next_frame", _new)
	_frame = TextureRect.new()
	_frame.texture = _old
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.size = Vector2(800, 600)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.material = _material
	add_child(_frame)

func add_waves(waves: Array[Node2D]) -> void:
	_waves = waves
	for wave in _waves: add_child(wave)

## El cursor del original sigue leyendo clics mientras el destino está congelado.
func click(point: Vector2) -> void:
	if _waves.is_empty():
		var layer: Node2D = load("res://scenes/duel/duel_cursor_visual.gd").new(true)
		layer._fraction = _clock
		_waves.append(layer)
		add_child(layer)
	_waves.back().click(point, true)

func set_destination(texture: Texture2D) -> void:
	_new = texture
	_material.set_shader_parameter("next_frame", _new)
	_first_frame_after_capture = true

func _process(delta: float) -> void:
	if _first_frame_after_capture:
		# El primer delta puede incluir la captura previa a la fase cero.
		delta = minf(delta, Engine.time_scale / CLOCK.HZ)
		_first_frame_after_capture = false
	for i in range(_waves.size() - 1, -1, -1):
		var wave := _waves[i]
		wave.advance(delta)
		if not wave.has_active_waves():
			wave.queue_free()
			_waves.remove_at(i)
	if progress == 256:
		if _waves.is_empty(): finish()
		return
	_clock += CLOCK.ticks(delta)
	while _clock >= 1.0 and progress < 256:
		_clock -= 1.0
		tick()

func tick() -> void:
	progress = mini(256, progress + 16)
	_material.set_shader_parameter("progress", progress)
	# 40a260 dibuja240 y312b0 termina ese mismo tick: el destino vuelve en el siguiente.
	if progress == 240:
		_release_screen()
	if progress == 256:
		if _waves.is_empty(): finish()
		else: _frame.hide()

func _release_screen() -> void:
	if is_instance_valid(_screen):
		_screen.process_mode = _previous_mode
		_screen = null

func finish() -> void:
	_release_screen()
	hide()
	queue_free()

## ASM525ce3/525de4/525f2d: izquierdaN pixeles; derechaN+1 por el -1.
static func revealed(x: int, y: int, p: int, width := 800) -> bool:
	if p >= 256:
		return true
	var row := y & 3
	var phase := p if row in [0, 2] else p - 128
	if phase <= 0:
		return false
	var extent := (width * phase) >> 7
	return x < mini(width, extent) if row in [0, 1] else x >= maxi(0, width - extent - 1)

## 52d470: bandas16, longitud decreciente; 5288e0: filasmod16 inclusivas.
static func revealed_mode(x: int, y: int, p: int, effect: int, width := 800, height := 600) -> bool:
	if p >= 256: return true
	if p <= 0: return false
	# 529ec0 / 52a430: radios centrados en y, con origen en el borde o el centro.
	if effect in [0x1e, 0x20]:
		var full_diameter := width + height
		if effect == 0x1e:
			full_diameter = int(2.0 * sqrt(width * width + (height * height >> 2)))
		var diameter := (full_diameter * p) >> 8
		var half_height := diameter >> 1
		var dy := y - (height >> 1)
		if dy < -half_height or dy >= half_height: return false
		var radius := sqrt((diameter * diameter >> 2) - dy * dy)
		var span := int(radius) if effect == 0x1e else int(radius * 2.0)
		var start := 0 if effect == 0x1e else maxi(0, (width >> 1) - (span >> 1))
		return x >= start and x < start + span
	if effect == 0x2a: return (y & 15) <= (p >> 4)
	if effect == 0x4b:
		var bands := (height + 17) / 16
		var length := mini(16, ((bands + 16) * p >> 8) - y / 16)
		var bottom := y / 16 * 16 + length
		if bottom > height: bottom = height - 1
		return y < bottom
	return revealed(x, y, p, width)

func _exit_tree() -> void:
	if is_instance_valid(_screen):
		_screen.process_mode = _previous_mode
		_screen = null
