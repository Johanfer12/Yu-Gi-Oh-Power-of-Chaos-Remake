extends Node2D
## Selector de juego: lo unico que no existe en el original. Une los tres juegos en uno
## mostrando el logo de cada uno; el resto del juego es el original.

## Composicion pensada en 800x600; se centra en la pantalla visible, que en el selector se
## estira al formato del monitor (aspecto EXPAND). El resto del juego sigue en 4:3 (KEEP).
const DESIGN := Vector2(800, 600)
const SLOT := Vector2(225, 150)          # caja en la que se encaja cada logo
const SLOT_GAP := 25.0
const LOGO_Y := 365.0                    # centro vertical de la fila de logos (en DESIGN)
const TITLE_Y := 185.0
const TITLE_SIZE := 52
const SELECTED_SCALE := 1.15
const IDLE_SCALE := 0.9
const DIM := Color(0.4, 0.4, 0.45)
const GOLD := Color(1.0, 0.82, 0.3)
const GOLD_LIGHT := Color(1.0, 0.95, 0.7)
const OUTLINE := Color(0.35, 0.08, 0.02)
const BG_TOP := Color(0.03, 0.03, 0.08)
const BG_BOTTOM := Color(0.12, 0.05, 0.16)

## Musica propia del selector (no es del original): arranca de golpe al abrir y despues sale y
## vuelve a entrar con fundido en cada vuelta.
const MUSIC := preload("res://assets/music/launcher_theme.mp3")
const MUSIC_DB := 0.0
const SILENT_DB := -60.0
const LOOP_FADE := 2.5                    # segundos de fundido al empezar y al acabar la vuelta
const EXIT_FADE := 0.4                    # fundido de salida al elegir juego

var _selected := 0
var _music := AudioStreamPlayer.new()
var _controls: Node2D = preload("res://scenes/launcher/launcher_controls.gd").new()
var _leaving := false
var _started := false                     # ya sono la primera vuelta
var _looped := false                      # vuelta actual es una repeticion (entra con fundido)
var _logos: Array[Sprite2D] = []
var _fit: Array[float] = []              # escala que encaja cada logo en SLOT
var _emphasis: Array[float] = []         # 0..1, animado hacia 1 en el seleccionado
var _halo: Sprite2D
var _time := 0.0
var _font := ThemeDB.fallback_font
var _screen := DESIGN                    # pantalla visible
var _language := OptionButton.new()
var _release_footer := preload("res://scenes/launcher/release_footer.gd").new()
var _origin := Vector2.ZERO              # esquina de la composicion DESIGN centrada en ella


func _enter_tree() -> void:
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND


func _exit_tree() -> void:
	_music.stop()
	_music.stream = null


func _ready() -> void:
	_halo = Sprite2D.new()
	_halo.texture = _halo_texture()
	add_child(_halo)
	for game in Game.GAMES:
		var logo := Sprite2D.new()
		if _available(_logos.size()):
			logo.texture = TitleArt.logo_texture(game)
		var size := logo.texture.get_size() if logo.texture != null else SLOT
		_fit.append(minf(SLOT.x / size.x, SLOT.y / size.y))
		_emphasis.append(0.0)
		add_child(logo)
		_logos.append(logo)
		logo.visible = _available(_logos.size() - 1)
	for i in Game.GAMES.size():
		if _available(i):
			_selected = i
			break
	_emphasis[_selected] = 1.0
	_layout()
	get_viewport().size_changed.connect(_layout)
	_halo.position = _logos[_selected].position
	_apply()
	add_child(_controls)
	_controls.exit_requested.connect(func() -> void: get_tree().quit())
	_controls.update_requested.connect(func() -> void: _release_footer.open_update())
	add_child(_release_footer)
	Updates.changed.connect(func() -> void: _controls.update_available = Updates.state == "available")
	_controls.update_available = Updates.state == "available"
	for code in ["s", "e"]:
		_language.add_item(Assets.LANGUAGES[code])
	_language.item_selected.connect(func(index: int) -> void:
		Assets.remember_language(["s", "e"][index])
		_release_footer.refresh()
		queue_redraw())
	_language.select(0 if Assets.lang == "s" else 1)
	_language.tooltip_text = "Idioma / Language"
	_language.add_theme_font_size_override("font_size", 16)
	add_child(_language)
	_layout()

	Audio.stop_music()
	_music.stream = MUSIC
	_music.finished.connect(_start_music)
	add_child(_music)
	_start_music()


## Recoloca los logos al cambiar el tamano visible (ventana redimensionada o maximizada).
func _layout() -> void:
	_screen = get_viewport_rect().size
	_origin = ((_screen - DESIGN) / 2.0).floor()
	var x := _screen.x / 2.0 - (SLOT.x + SLOT_GAP)
	for logo in _logos:
		logo.position = Vector2(x, _origin.y + LOGO_Y)
		x += SLOT.x + SLOT_GAP
	if not _logos.is_empty() and _halo != null:
		_halo.position = _logos[_selected].position
	_language.position = Vector2(_screen.x - 170, 24)
	_language.size = Vector2(146, 38)
	queue_redraw()


func _start_music() -> void:
	if _leaving:
		return
	_looped = _started
	_started = true
	_music.volume_db = SILENT_DB if _looped else _volume_db(1.0)
	_music.play()


## Nivel del fundido (0..1) por el volumen y el silencio elegidos en los botones.
func _volume_db(fade: float) -> float:
	var linear: float = fade * _controls.level()
	return maxf(linear_to_db(maxf(linear, 0.00001)), SILENT_DB) + MUSIC_DB


## Volumen segun la posicion en la vuelta: sube al empezar y baja antes del final. Se
## interpola en lineal (no en dB) para que el fundido se oiga uniforme.
func _update_music() -> void:
	if _leaving or not _music.playing:
		return
	var pos := _music.get_playback_position()
	var length := MUSIC.get_length()
	# La primera vuelta entra de golpe al abrir el launcher; las siguientes, con fundido.
	var fade_in := LOOP_FADE if _looped else 0.0
	var level := clampf((length - pos) / LOOP_FADE, 0.0, 1.0)
	if fade_in > 0.0:
		level = minf(level, pos / fade_in)
	_music.volume_db = _volume_db(level)


func _available(index: int) -> bool:
	var inventory: Variant = JSON.parse_string(FileAccess.get_file_as_string(Paths.data_dir.path_join("inventory.json")))
	return inventory is Dictionary and inventory.get("games", {}).has(Game.GAMES[index])


func _choose(index: int) -> void:
	if _leaving or not _available(index):
		return
	_leaving = true
	var cover := CanvasLayer.new()
	cover.layer = 100
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.modulate.a = 0.0
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(black)
	# Sobrevive al launcher: el cambio de formato ocurre completamente bajo negro.
	get_tree().root.add_child(cover)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_music, "volume_db", SILENT_DB, EXIT_FADE)
	tween.tween_property(black, "modulate:a", 1.0, EXIT_FADE)
	tween.chain().tween_callback(Game.open_title.bind(Game.GAMES[index], "", cover))


func _process(delta: float) -> void:
	_time += delta
	_update_music()
	var k := 1.0 - exp(-delta * 12.0)
	for i in _logos.size():
		_emphasis[i] = lerpf(_emphasis[i], 1.0 if i == _selected else 0.0, k)
	_halo.position = _halo.position.lerp(_logos[_selected].position, k)
	_apply()
	queue_redraw()


func _apply() -> void:
	var pulse := 1.0 + 0.03 * sin(_time * 3.0)
	for i in _logos.size():
		var e := _emphasis[i]
		var s := lerpf(IDLE_SCALE, SELECTED_SCALE * pulse, e)
		_logos[i].scale = Vector2.ONE * _fit[i] * s
		_logos[i].modulate = DIM.lerp(Color.WHITE, e)
	_halo.modulate.a = 0.75 + 0.25 * sin(_time * 3.0)


func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(_screen.x, 0), _screen, Vector2(0, _screen.y)]),
			PackedColorArray([BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM]))
	_draw_title()


## Titulo dorado con contorno, sombra, brillo que recorre las letras y filete decorativo.
func _draw_title() -> void:
	var title := Assets.port_label(0)
	var width := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	var x := (_screen.x - width) / 2.0
	var title_y := _origin.y + TITLE_Y
	var base := Vector2(x, title_y)
	draw_string_outline(_font, base + Vector2(4, 5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE,
			10, Color(0, 0, 0, 0.6))
	draw_string_outline(_font, base, title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, 10, OUTLINE)
	draw_string_outline(_font, base, title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, 4, GOLD.darkened(0.3))
	# Letra a letra para que el destello avance de izquierda a derecha.
	var shine := fmod(_time * 0.6, 1.6) - 0.3
	var cx := x
	for ch in title:
		var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
		var t := (cx + w / 2.0 - x) / width
		var glow := clampf(1.0 - absf(t - shine) * 5.0, 0.0, 1.0)
		draw_string(_font, Vector2(cx, title_y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE,
				GOLD.lerp(GOLD_LIGHT, glow))
		cx += w
	# Filete: dos lineas que se desvanecen hacia fuera y un rombo en el centro.
	var y := title_y + 24.0
	var half := width / 2.0 + 60.0
	var mid := _screen.x / 2.0
	for dir in [-1.0, 1.0]:
		var pts := PackedVector2Array([Vector2(mid + dir * 12.0, y), Vector2(mid + dir * half, y)])
		draw_polyline_colors(pts, PackedColorArray([GOLD, Color(GOLD, 0.0)]), 2.0, true)
	var d := 6.0
	draw_colored_polygon(PackedVector2Array([Vector2(mid, y - d), Vector2(mid + d, y),
			Vector2(mid, y + d), Vector2(mid - d, y)]), GOLD_LIGHT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_move(-1)
	elif event.is_action_pressed("ui_right"):
		_move(1)
	elif event.is_action_pressed("ui_accept"):
		_choose(_selected)
	elif event is InputEventMouseMotion:
		var hit := _hit(event.position)
		if hit != -1:
			_selected = hit
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _hit(event.position)
		if hit != -1:
			_choose(hit)


func _move(step: int) -> void:
	for unused in _logos.size():
		_selected = wrapi(_selected + step, 0, _logos.size())
		if _available(_selected):
			break


## Cada juego responde en toda su ranura, no solo sobre los pixeles del logo.
func _hit(screen_pos: Vector2) -> int:
	var local := get_global_transform_with_canvas().affine_inverse() * screen_pos
	for i in _logos.size():
		if _available(i) and Rect2(_logos[i].position - SLOT / 2.0, SLOT).has_point(local):
			return i
	return -1


func _halo_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.85, 0.45, 0.45))
	gradient.set_color(1, Color(1.0, 0.6, 0.2, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 360
	tex.height = 240
	return tex
