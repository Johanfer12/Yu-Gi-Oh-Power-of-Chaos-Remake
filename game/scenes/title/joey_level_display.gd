extends Node2D
## Jo489490: estrellas, cambio de nivel y aviso. Bytes db2/db3 consumidos sin signo.
var title: Node2D
var _layout: Layout
var mixed := false
var _texture: Texture2D
var _origin := Vector2.ZERO
var _step := 26
var _frames: Array[Texture2D] = []
var _labels: Array[Texture2D] = []
var _label_origin := Vector2.ZERO
var _clock := 0.0
var _counter := 0
var _was_visible := false

func setup(screen: Node2D, layout: Layout) -> void:
	visible = false
	title = screen
	_layout = layout
	mixed = Game.joey_full_cards()
	var base := layout.index_of("d_lv0.bmp")
	_origin = Vector2(layout.position(base))
	_step = int(layout.value(layout.index_of("d_lv_d1.bmp")))
	_texture = Assets.texture("joey/title/" + layout.resource(base))
	for offset in range(1, 5): _frames.append(Assets.texture("joey/title/" + layout.resource(base + offset)))
	for offset in range(5, 7): _labels.append(Assets.texture("joey/title/" + layout.resource(base + offset)))
	_label_origin = Vector2(layout.position(base + 5))

static func effective_level(level: int, full_cards: bool) -> int:
	return mini((level & 0xff) + int(full_cards) * 2, 9)

func _levels() -> Vector2i:
	var stats: Dictionary = SaveData.data.get("stats", {}).get("joey", {})
	mixed = Game.joey_full_cards()
	return Vector2i((int(stats.get("shown_level", stats.get("level", 1))) & 255) + int(mixed) * 2,
			(int(stats.get("level", 1)) & 255) + int(mixed) * 2)

func tiles() -> int:
	var levels := _levels()
	return mini(levels.y, 9) - int(levels.x < levels.y)

func animation(counter := _counter) -> Dictionary:
	var levels := _levels()
	if levels.x == levels.y: return {}
	var weight := mini(counter * 4, 256)
	var blink := (~counter >> 4) & 1
	var at := _origin + Vector2(tiles() * _step, 0)
	if levels.y < levels.x:
		at.y += (65536 - DuelVisualMath.cos_fx(weight / 2)) >> 12
		return {"texture": _frames[blink], "at": at, "alpha": (256 - weight) / 256.0,
				"label": _labels[0], "label_alpha": weight / 256.0}
	at.y -= DuelVisualMath.cos_fx(weight - 128) >> 13
	return {"texture": _frames[2 + blink] if counter < 256 else _texture,
			"at": at, "alpha": weight / 256.0, "label": _labels[1], "label_alpha": weight / 256.0}

func _process(delta: float) -> void:
	visible = title != null and title._menu == "duel" and title._menu_root.visible
	if visible and not _was_visible:
		_counter = 0
		_clock = 0
	_was_visible = visible
	if not visible: return
	_clock += NativeClock.ticks(delta)
	while _clock >= 1:
		_clock -= 1
		_counter += 4
	queue_redraw()

func _draw() -> void:
	if _texture == null: return
	for i in tiles(): draw_texture(_texture, _origin + Vector2(i * _step, 0))
	var change := animation()
	# Entre ticks se mezcla el anterior hacia el actual, como la presentacion del duelo.
	if not change.is_empty() and NativeClock.interpolate and _counter >= 4:
		var previous := animation(_counter - 4)
		var t := clampf(_clock, 0.0, 1.0)
		change.at = (previous.at as Vector2).lerp(change.at, t)
		change.alpha = lerpf(previous.alpha, change.alpha, t)
		change.label_alpha = lerpf(previous.label_alpha, change.label_alpha, t)
	if not change.is_empty():
		draw_texture(change.texture, change.at, Color(1, 1, 1, change.alpha))
		draw_texture(change.label, _label_origin, Color(1, 1, 1, change.label_alpha))
