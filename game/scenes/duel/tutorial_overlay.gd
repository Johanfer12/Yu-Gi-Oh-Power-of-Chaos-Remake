extends Node2D
## Yugi 468070/4688b0 (retrato), 467fd0/468470/468570/468d00 (globo).
## El núcleo emite eb/ec/ed/ee; la escena espera las transiciones y las páginas.
const DIR := "yugi/tutorial/"
var _dir := DIR
const POSITIONS := [[260, 500, -1], [260, 100, -1], [16, 500, -1],
	[16, 100, -1], [260, 500, 4], [260, 100, 5], [16, 500, 6],
	[16, 100, 7], [260, 100, 4]]
const MOUTH := [0, 1, 1, 2, 2, 2, 1, 1]
const ARROW := [0, 0, 0, 1, 2, 3, 4, 5, 5, 5, 5, 5]
var side := 0
var portrait_visible := false
var counter := 0
var bubble_visible := false
var manual := false
var talking_enabled := true
var pages: PackedStringArray = []
var page := 0
var text_id := -1
var _clock := 0.0
## Entrada y salida del retrato mezcladas entre ticks.
var _blend := NativeBlend.new()
var _ticks := 0
var _blink := 0
var _arrow_tick := 0
var _portrait: Layout
var _popup: Layout
var _dialogs: Array = []
var _text := RichTextLabel.new()
var _at := Vector2.ZERO
var _tail := -1
var _bubble_index := 0
var _top := 0
var _layout_pending := false

func _ready() -> void:
	z_index = 20
	_portrait = Assets.layout(_dir + "bustup_l.txt")
	_popup = Assets.layout(_dir + "popup.txt")
	var dialogs: Variant = Assets.dialog_texts()
	_dialogs = dialogs if dialogs is Array else []
	_text.bbcode_enabled = true
	_text.size.x = Assets.texture(_dir + _popup.resource(0)).get_width() - 64
	_text.fit_content = true
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 468470: familia1=Arial en regiones occidentales (51b890), altura GDI24.
	# Arial tiene3px de leading interno a esa altura: cuerpo21 y línea26 (536330).
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial"])
	var bold := SystemFont.new()
	bold.font_names = font.font_names
	bold.font_weight = 700
	_text.add_theme_font_override("normal_font", font)
	_text.add_theme_font_override("bold_font", bold)
	_text.add_theme_font_size_override("normal_font_size", 21)
	_text.add_theme_font_size_override("bold_font_size", 21)
	_text.add_theme_constant_override("line_separation", 2)
	_text.add_theme_color_override("default_color", Color("080808"))
	add_child(_text)
	reset()

func reset() -> void:
	portrait_visible = false
	counter = 0
	bubble_visible = false
	manual = false
	pages.clear()
	text_id = -1
	_layout_pending = false
	_text.hide()
	_clock = 0
	queue_redraw()

func event(e: Dictionary) -> void:
	match e.get("kind", ""):
		"tutorial_portrait":
			portrait_visible = e["visible"]
			if portrait_visible:
				side = int(e["side"])
				_portrait = Assets.layout(_dir + ("bustup_l.txt" if side == 0 else "bustup_r.txt"))
		"tutorial_bubble":
			text_id = int(e["text"])
			manual = bool(e["manual"])
			var pos: Array = POSITIONS[clampi(int(e["position"]), 0, 8)]
			_at = Vector2(pos[0], pos[1])
			_tail = pos[2]
			pages.clear()
			if text_id >= 0 and text_id < _dialogs.size():
				for part in str(_dialogs[text_id]).split("<HR>", false):
					pages.append(_format(part))
			if pages.is_empty(): pages.append("")
			page = 0
			bubble_visible = true
			_show_page()
		"tutorial_bubble_close":
			bubble_visible = false
			manual = false
			_text.hide()
	queue_redraw()

func _format(raw: String) -> String:
	var text := raw.replace("<BR>", "\n").replace("\r", "").replace("[", "[lb]")
	text = RegEx.create_from_string("@[0-9]").sub(text, "", true)
	text = text.replace("<B>", "[b]").replace("</B>", "[/b]")
	text = RegEx.create_from_string("(?i)<FONT\\s+color=[\"']?(#[0-9a-f]{6})[\"']?>").sub(text, "[color=$1]", true)
	text = text.replace("</FONT>", "[/color]")
	return RegEx.create_from_string("<[^>]+>").sub(text, "", true).strip_edges()

func _show_page() -> void:
	_text.text = pages[page]
	_text.visible_characters = 0
	_text.show()
	_layout_pending = true
	_layout_bubble.call_deferred()

func _layout_bubble() -> void:
	if not bubble_visible: return
	var height := _text.get_content_height()
	_bubble_index = int(height > int(_popup.value(0))) + int(height > int(_popup.value(1)))
	var texture := Assets.texture(_dir + _popup.resource(_bubble_index))
	_top = int(_at.y) - texture.get_height() / 2
	_text.position = Vector2(_at.x + 32, _at.y - int(height / 2))
	_layout_pending = false
	queue_redraw()

func text_done() -> bool:
	return not _layout_pending and _text.visible_characters >= _text.get_total_character_count()

func busy() -> bool:
	return counter != (256 if portrait_visible else 0) or (bubble_visible and
		(not text_done() or manual or page + 1 < pages.size()))

func accept() -> void:
	# 467fd0 sólo recibe clic/Intro una vez terminado el texto de la página.
	if not bubble_visible or not text_done(): return
	if page + 1 < pages.size():
		page += 1
		_show_page()
	elif manual:
		bubble_visible = false
		manual = false
		_text.hide()
	queue_redraw()

func advance(delta: float) -> void:
	_clock += NativeClock.ticks(delta)
	while _clock >= 1:
		_clock -= 1
		counter = mini(counter + 16, 256) if portrait_visible else maxi(counter - 16, 0)
		_ticks = (_ticks + 1) & 255
		_blink += 1
		if (UiRandom.draw() & 63) == 0: _blink = 0   # 0x4680b9
		_arrow_tick = (_arrow_tick + 1) % 36
		# 45d580: cuatro glifos por llamada step(1), independiente de velocidad del visor.
		if bubble_visible and not _layout_pending:
			_text.visible_characters = mini(_text.visible_characters + 4, _text.get_total_character_count())
		_blend.tick()
	_blend.fraction = _clock
	queue_redraw()


## Avanzado por ticks enteros (lecciones): se dibuja con el reloj de quien lo avanza.
func show_between(fraction: float) -> void:
	_blend.fraction = fraction
	queue_redraw()

func _feature(index: int, frame: int, base: Vector2) -> void:
	if frame == 0: return
	var tex := Assets.texture(_dir + _portrait.resource(index))
	var size := Vector2(tex.get_width(), tex.get_height() / 2)
	draw_texture_rect_region(tex, Rect2(base + Vector2(_portrait.position(index)), size),
		Rect2(Vector2(0, (frame - 1) * size.y), size))

func _draw() -> void:
	if _portrait == null: return
	if counter > 16:
		var pos := Vector2(_portrait.position(0))
		var tex := Assets.texture(_dir + _portrait.resource(0))
		var distance := int(pos.x) + tex.get_width() if pos.x + tex.get_width() / 2 < 400 else 800 - int(pos.x)
		var shift := int((65536 - DuelVisualMath.cos_fx(counter / 2 - 128)) * distance / 65536)
		pos.x = _blend.at("portrait", pos.x + (-shift if side == 0 else shift))
		draw_texture(tex, pos)
		if _blink < 4:
			_feature(1, [1, 2, 2, 1][_blink], pos)
			_feature(2, [1, 2, 2, 1][_blink], pos)
		if talking_enabled and bubble_visible and not text_done(): _feature(3, MOUTH[_ticks & 7], pos)
	_draw_bubble()

func _draw_bubble() -> void:
	if bubble_visible and not _layout_pending:
		var tex := Assets.texture(_dir + _popup.resource(_bubble_index))
		draw_texture(tex, Vector2(_at.x, _top))
		if _tail >= 0:
			var tail := Assets.texture(_dir + _popup.resource((_tail & 3) + 3))
			var x := tex.get_width() - 2 if (_tail & 2) != 0 else 2 - tail.get_width()
			var y := _top + tex.get_height() / 2 - tail.get_height() / 2 + (32 if (_tail & 1) != 0 else -32)
			draw_texture(tail, Vector2(_at.x + x, y))
		if text_done() and (manual or page + 1 < pages.size()):
			var arrow := Assets.texture(_dir + _popup.resource(7))
			var size := Vector2(arrow.get_width(), arrow.get_height() / 6)
			draw_texture_rect_region(arrow, Rect2(Vector2(_at.x + tex.get_width() - 40, _top + tex.get_height() - 32), size),
				Rect2(Vector2(0, ARROW[_arrow_tick / 3] * size.y), size))
