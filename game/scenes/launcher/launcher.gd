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
var MUSIC: AudioStream
const MUSIC_DB := 0.0
const SILENT_DB := -60.0
const LOOP_FADE := 2.5                    # segundos de fundido al empezar y al acabar la vuelta
const EXIT_FADE := 0.4                    # fundido de salida al elegir juego

var _selected_index := 0
var _music := AudioStreamPlayer.new()
var _controls: Node2D = preload("res://scenes/launcher/launcher_controls.gd").new()
var _leaving := false
var _started := false                     # ya sono la primera vuelta
var _looped := false                      # vuelta actual es una repeticion (entra con fundido)
var _logos: Array[Sprite2D] = []
var _fit: Array[float] = []              # escala que encaja cada logo en SLOT
var _emphasis: Array[float] = []         # 0..1, animado hacia 1 en el seleccionado
var _halo: Sprite2D
var _glow := _radial(Color(0.42, 0.2, 0.55), 0.2, Vector2i(512, 256))
var _time := 0.0
var _font := ThemeDB.fallback_font
var _screen := DESIGN                    # pantalla visible
var _origin := Vector2.ZERO              # esquina de la composicion DESIGN centrada en ella
var import_mode := false
var logo_y := LOGO_Y
var heading_y := TITLE_Y
var _language := OptionButton.new()
var _setup_button := Button.new()
var _release_footer := preload("res://scenes/launcher/release_footer.gd").new()


func _enter_tree() -> void:
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND


func _exit_tree() -> void:
	_music.stop()
	_music.stream = null


func _ready() -> void:
	# Recurso propio del remake, incluido expresamente en la copia publica.
	var music_path := "res://assets/music/launcher_theme.mp3"
	if ResourceLoader.exists(music_path):
		MUSIC = load(music_path)
	_halo = Sprite2D.new()
	# Halo a doble resolucion, dibujado a la mitad: caida suave sin escalones.
	_halo.texture = _radial(Color(1.0, 0.8, 0.4), 0.6, Vector2i(720, 480))
	_halo.scale = Vector2.ONE * 0.5
	add_child(_halo)
	for game in Game.GAMES:
		var logo := Sprite2D.new()
		logo.texture = _smooth(TitleArt.logo_texture(game)) if Paths.has_game(game) else null
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if logo.texture != null:
			var outline := ShaderMaterial.new()
			outline.shader = preload("res://scenes/launcher/logo_outline.gdshader")
			logo.material = outline
		var size := logo.texture.get_size() if logo.texture != null else SLOT
		_fit.append(minf(SLOT.x / size.x, SLOT.y / size.y))
		_emphasis.append(0.0)
		add_child(logo)
		_logos.append(logo)
	_emphasis[_selected_index] = 1.0
	_layout()
	get_viewport().size_changed.connect(_layout)
	_halo.position = _logos[_selected_index].position
	_apply()
	add_child(_controls)
	_controls.exit_requested.connect(_request_exit)
	_controls.update_requested.connect(_request_update)
	add_child(_release_footer)
	Updates.changed.connect(_update_badge)
	_update_badge()
	Audio.stop_music()
	_music.stream = MUSIC
	_music.finished.connect(_start_music)
	add_child(_music)
	_start_music()
	_setup_button.text = "ISO / " + _folder_label()
	_setup_button.position = Vector2(24, 24)
	_setup_button.visible = not import_mode
	_setup_button.pressed.connect(func() -> void: Game.goto(load("res://scenes/launcher/content_setup.gd").new()))
	add_child(_setup_button)
	for key: String in Assets.LANGUAGES:
		_language.add_item(Assets.LANGUAGES[key])
	_language.item_selected.connect(_select_language)
	_style_control(_language)
	add_child(_language)
	_controls.changed.connect(_language_updated)
	_language_updated()
	_layout()


## Copia con mipmaps: los logos se dibujan reducidos y sin ellos se ven dentados.
func _smooth(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _folder_label() -> String:
	return {"s": "Carpeta", "e": "Folder", "g": "Ordner", "f": "Dossier", "i": "Cartella", "j": "フォルダー"}.get(Assets.lang, "Folder")


func _request_exit() -> void:
	get_tree().quit()


func _request_update() -> void:
	if not _leaving:
		_release_footer.open_update()


func _update_badge() -> void:
	_controls.update_available = Updates.state == "available"


func _style_control(control: Control) -> void:
	control.add_theme_color_override("font_color", GOLD_LIGHT)
	control.add_theme_font_size_override("font_size", 14)
	control.add_theme_color_override("font_hover_color", Color.WHITE)
	control.add_theme_color_override("font_disabled_color", Color(GOLD_LIGHT, 0.35))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.11, 0.075, 0.12, 0.96) if state in ["hover", "pressed"] else Color(0.06, 0.045, 0.08, 0.92)
		style.border_color = Color(GOLD, 0.25) if state == "disabled" else (GOLD.darkened(0.45) if state == "normal" else GOLD)
		style.draw_center = state != "focus"
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.anti_aliasing = true
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		control.add_theme_stylebox_override(state, style)


func _select_language(index: int) -> void:
	Assets.remember_language(Assets.LANGUAGES.keys()[index])
	_language_updated()


func _language_updated() -> void:
	_language.select(Assets.LANGUAGES.keys().find(Assets.lang))
	_language.tooltip_text = Assets.port_label(4)
	_setup_button.text = "ISO / " + _folder_label()
	if _release_footer.is_node_ready():
		_release_footer.refresh()
	queue_redraw()


func _heading() -> String:
	return Assets.port_label(0)


## Recoloca los logos al cambiar el tamano visible (ventana redimensionada o maximizada).
func _layout() -> void:
	_screen = get_viewport_rect().size
	_origin = ((_screen - DESIGN) / 2.0).floor()
	var x := _screen.x / 2.0 - (SLOT.x + SLOT_GAP)
	for logo in _logos:
		logo.position = Vector2(x, _origin.y + logo_y)
		x += SLOT.x + SLOT_GAP
	if not _logos.is_empty() and _halo != null:
		_halo.position = _logos[_selected_index].position
	_language.position = Vector2(_screen.x - 170, 24)
	_language.size = Vector2(146, 34)
	queue_redraw()


func _start_music() -> void:
	if _leaving or MUSIC == null:
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


func _choose(index: int) -> void:
	if not Paths.has_game(Game.GAMES[index]):
		Game.open_launcher()
		return
	if _leaving:
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
		_emphasis[i] = lerpf(_emphasis[i], 1.0 if i == _selected_index else 0.0, k)
	_halo.position = _halo.position.lerp(_logos[_selected_index].position, k)
	_apply()
	queue_redraw()


func _apply() -> void:
	var pulse := 1.0 + 0.03 * sin(_time * 3.0)
	for i in _logos.size():
		var e := _emphasis[i]
		var s := lerpf(IDLE_SCALE, SELECTED_SCALE * pulse, e)
		_logos[i].scale = Vector2.ONE * _fit[i] * s
		_logos[i].modulate = DIM.lerp(Color.WHITE, e)
		if _logos[i].material != null:
			_logos[i].material.set_shader_parameter("emphasis", e)
	_halo.modulate.a = 0.75 + 0.25 * sin(_time * 3.0)


func _draw() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(_screen.x, 0), _screen, Vector2(0, _screen.y)]),
			PackedColorArray([BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM]))
	# Luz tenue detras de la fila de logos para que no floten sobre un fondo plano.
	var glow_size := Vector2(maxf(_screen.x * 1.1, 900.0), 560.0)
	draw_texture_rect(_glow, Rect2(Vector2(_screen.x / 2.0, _origin.y + logo_y) - glow_size / 2.0, glow_size), false)
	_draw_title()
	for i in _logos.size():
		if _logos[i].texture == null:
			_draw_game_card(i)
	var voice_language := Assets.voice_language(Game.GAMES[_selected_index])
	if voice_language != "" and not import_mode:
		draw_string(_font, Vector2(_origin.x + 26, _origin.y + 520),
				"Voces: " + str(Assets.LANGUAGES.get(voice_language, voice_language)),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, GOLD_LIGHT)


func _draw_game_card(index: int) -> void:
	var rect := Rect2(_logos[index].position - SLOT / 2.0, SLOT)
	var color: Color = [Color("9659c4"), Color("489bd0"), Color("cf8543")][index]
	for outline: PackedVector2Array in _logo_contours(index):
		draw_colored_polygon(outline, color.darkened(0.88))
		var closed := outline.duplicate()
		closed.append(outline[0])
		draw_polyline(closed, GOLD if index == _selected_index else Color(GOLD, 0.5), 1.6, true)
	var title: String = ["YUGI", "KAIBA", "JOEY"][index]
	var subtitle: String = ["THE DESTINY", "THE REVENGE", "THE PASSION"][index]
	var reveal := _card_revealed(index)
	var lines := [[title, 27, -27]] if reveal else [[title, 34, -5], [subtitle, 14, 22]]
	for pair in lines:
		var width := _font.get_string_size(pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, pair[1]).x
		draw_string(_font, Vector2(rect.get_center().x - width / 2, rect.get_center().y + pair[2]), pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, pair[1], GOLD_LIGHT)


func _logo_contours(index: int) -> Array[PackedVector2Array]:
	var shape: Dictionary = LogoContours.DATA[Game.GAMES[index]]
	var dimensions: Vector2 = shape["size"]
	var fit := minf(SLOT.x / dimensions.x, SLOT.y / dimensions.y)
	var pulse := 1.0 + 0.03 * sin(_time * 3.0)
	fit *= lerpf(IDLE_SCALE, SELECTED_SCALE * pulse, _emphasis[index])
	var contours: Array[PackedVector2Array] = []
	for points: Array in shape["loops"]:
		var outline := PackedVector2Array()
		for point: Vector2 in points:
			outline.append(_logos[index].position + (point - dimensions / 2.0) * fit)
		contours.append(outline)
	return contours


func _import_center(index: int) -> Vector2:
	var largest := 0.0
	var center := _logos[index].position
	for contour: PackedVector2Array in _logo_contours(index):
		var cross_sum := 0.0
		var weighted := Vector2.ZERO
		for i in contour.size():
			var a := contour[i] - _logos[index].position
			var b := contour[(i + 1) % contour.size()] - _logos[index].position
			var cross := a.cross(b)
			cross_sum += cross
			weighted += (a + b) * cross
		if absf(cross_sum) > largest:
			largest = absf(cross_sum)
			center = _logos[index].position + weighted / (3.0 * cross_sum)
	return center


func _card_revealed(_index: int) -> bool:
	return false


## Titulo dorado con contorno, sombra, brillo que recorre las letras y filete decorativo.
func _draw_title() -> void:
	var title := _heading()
	var natural_width := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	var title_size := mini(TITLE_SIZE, int(700.0 * TITLE_SIZE / maxf(natural_width, 1.0)))
	var width := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var x := (_screen.x - width) / 2.0
	var title_y := _origin.y + heading_y
	var base := Vector2(x, title_y)
	draw_string_outline(_font, base + Vector2(4, 5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size,
			10, Color(0, 0, 0, 0.6))
	draw_string_outline(_font, base, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, 10, OUTLINE)
	draw_string_outline(_font, base, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, 4, GOLD.darkened(0.3))
	# Letra a letra para que el destello avance de izquierda a derecha.
	var shine := fmod(_time * 0.6, 1.6) - 0.3
	var cx := x
	for ch in title:
		var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
		var t := (cx + w / 2.0 - x) / width
		var glow := clampf(1.0 - absf(t - shine) * 5.0, 0.0, 1.0)
		draw_string(_font, Vector2(cx, title_y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size,
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
		_choose(_selected_index)
	elif event is InputEventMouseMotion:
		var hit := _hit(event.position)
		if hit != -1:
			_selected_index = hit
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _hit(event.position)
		if hit != -1:
			_choose(hit)


func _move(step: int) -> void:
	_selected_index = wrapi(_selected_index + step, 0, _logos.size())


## Cada juego responde en toda su ranura, no solo sobre los pixeles del logo.
func _hit(screen_pos: Vector2) -> int:
	var local := get_global_transform_with_canvas().affine_inverse() * screen_pos
	for i in _logos.size():
		for contour: PackedVector2Array in _logo_contours(i):
			if Geometry2D.is_point_in_polygon(local, contour):
				return i
	return -1


## Degradado radial con caida suave hasta cero (varias paradas) para evitar bandas visibles al escalar.
static func _radial(color: Color, alpha: float, size: Vector2i) -> GradientTexture2D:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in 9:
		var t := i / 8.0
		offsets.append(t)
		colors.append(Color(color, alpha * pow(1.0 - t, 1.6)))
	gradient.offsets = offsets
	gradient.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size.x
	tex.height = size.y
	return tex
