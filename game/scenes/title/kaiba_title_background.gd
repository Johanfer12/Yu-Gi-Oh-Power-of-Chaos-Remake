extends Node2D
## 4687c0, ASM: fondo, expansión del logo, tres recortes MT y efectos por tick.
var layout: Layout
var counter := -4
var tick := 0
var half_alpha := [0, 0]
var rays: Array[Dictionary] = []
var textures := {}
## Fundido de las mitades y crecimiento del logo entre ticks (title_screen fija `fraction`).
var blend := NativeBlend.new()
func setup(value: Layout) -> void:
	layout = value
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func tex(index: int) -> Texture2D:
	if not textures.has(index): textures[index] = Assets.texture("kaiba/title/" + layout.resource(index))
	return textures[index]
static func logo_size(c: int, original: Vector2i) -> Vector2i:
	if c >= 160: return original
	var x: int
	var y: int
	if c * 8 - 1024 <= 128:
		x = (DuelVisualMath.cos_fx(c * 8 - 1152) >> 8) * 2
		y = 8
	else:
		y = DuelVisualMath.cos_fx(c * 8 - 1280) >> 8
		x = 512 - y
	return Vector2i((original.x * x) >> 8, (original.y * y) >> 8)
func advance(c: int, native_tick: int) -> void:
	blend.tick()
	counter = c
	tick = native_tick
	rays.clear()
	if c < 128:
		half_alpha[(c / 4) & 1] = ((c / 4) >> 1) << 4
	else:
		half_alpha = [256, 256]
		if c >= 160:
			var h := tex(6).get_height()
			var row := (tick * 2) % (h * 3 / 2) - h / 2
			# JS468a41 keeps flags from SUB468a30; LEA(row+1) does not change them.
			for i in 3:
				var source_y := row - i
				if source_y >= 0:
					rays.append({"row": source_y, "dx": UiRandom.draw() % (13 - i * 4) - (6 - i * 2)})
	queue_redraw()
func _draw() -> void:
	if layout == null: return
	var bg := tex(5)
	for half in 2:
		var rect := Rect2(0, half * 300, 800, 300)
		draw_rect(rect, Color.BLACK)
		draw_texture_rect_region(bg, rect, rect, Color(1, 1, 1, blend.at(["half", half], float(half_alpha[half])) / 256.0))
	if counter < 128: return
	var logo := tex(6)
	var size: Vector2 = blend.at("logo", Vector2(logo_size(counter, Vector2i(logo.get_size()))))
	var origin := Vector2(layout.position(6)) - (size / 2).floor()
	draw_texture_rect(logo, Rect2(origin, size), false)
	if counter >= 160:
		for ray in rays:
			if ray.row < 0 or ray.row >= logo.get_height(): continue
			var source := Rect2(0, ray.row, logo.get_width(), 1)
			draw_texture_rect_region(logo, Rect2(origin + Vector2(ray.dx, ray.row), source.size), source)
	if counter <= 160: return
	for group in range(97, 108):
		if group < 104 and (group - 97) % 3 != ((tick >> 1) / 6) % 3: continue
		var index := 44 if group == 107 else (tick >> (1 if group < 104 else 2)) % 6 - 561 + group * 6
		if group == 100 and (tick >> 1) % 6 == 5: continue
		var alpha := mini(255, DuelVisualMath.cos_fx((tick * 4 & 255) - 128) >> 8) if group == 107 else 256
		var shown: float = blend.at(["pulse", group], float(alpha)) if group == 107 else float(alpha)
		draw_texture(tex(index), Vector2(layout.position(index)), Color(1, 1, 1, shown / 256.0))
