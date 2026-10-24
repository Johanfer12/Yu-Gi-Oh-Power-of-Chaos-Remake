extends Node2D
## Botones propios del selector: ajustes y sonido abajo a la izquierda, salir a la derecha.
## Medallones dorados. La
## configuracion: musica, aspecto, FPS y velocidad de simulacion.
## Audio en SaveData; aspecto, FPS y simulacion en LauncherSettings (content.cfg).

signal changed
signal exit_requested
signal update_requested
var update_available := false

const RADIUS := 24.0
const MARGIN := 18.0
const ICON_SIZE := 22.0
const GOLD := Color(1.0, 0.82, 0.3)
const GOLD_LIGHT := Color(1.0, 0.95, 0.7)
const GOLD_DARK := Color(0.42, 0.27, 0.06)
const BRONZE := Color(0.62, 0.43, 0.12)
const STONE := Color(0.07, 0.05, 0.04)
const OUTLINE := Color(0.35, 0.08, 0.02)
const PANEL_SIZE := Vector2(540, 490)
const ROW_TOP := 92.0             # primera fila bajo la cabecera del panel
const ROW_PITCH := 50.0
const CONTROL_X := 220.0          # columna de valores, alineada en todas las filas
const KEY_STEP := 0.05

# Iconos de linea estilo Feather (viewBox 24), trazo blanco para tintarlos al dibujar.
const SVG_HEAD := "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='#ffffff' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>"
const SVG_SOUND := SVG_HEAD + "<polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/><path d='M19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07'/></svg>"
const SVG_MUTED := SVG_HEAD + "<polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/><line x1='23' y1='9' x2='17' y2='15'/><line x1='17' y1='9' x2='23' y2='15'/></svg>"
const SVG_GEAR := SVG_HEAD + "<circle cx='12' cy='12' r='3'/><path d='M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z'/></svg>"
const SVG_CLOSE := SVG_HEAD + "<line x1='18' y1='6' x2='6' y2='18'/><line x1='6' y1='6' x2='18' y2='18'/></svg>"
const SVG_EXIT := SVG_HEAD + "<path d='M18.36 6.64a9 9 0 1 1-12.73 0'/><line x1='12' y1='2' x2='12' y2='12'/></svg>"
const SVG_UPDATE := SVG_HEAD + "<path d='M20 7a9 9 0 1 0 1 9'/><polyline points='20 2 20 8 14 8'/></svg>"

const DEFAULT_VOLUME := 0.5
var volume := DEFAULT_VOLUME
var muted := false
var pointer_mode := "menu"
var panel_open := false

var _icons := {}             # nombre -> {tex, offset} (offset = centrado optico medido)
var _hover := ""             # "sound", "settings", "close", "slider", "mute"
var _dragging := false
var _focused_row := 0
var _time := 0.0
var _font := ThemeDB.fallback_font
var _reset_dialog := ConfirmationDialog.new()
var _reset_result := AcceptDialog.new()


func _ready() -> void:
	z_index = 10
	add_child(_reset_dialog)
	add_child(_reset_result)
	_reset_dialog.confirmed.connect(_confirm_reset)
	# Los iconos se rasterizan grandes y se dibujan reducidos: con mipmaps no se ven dentados.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var saved: Dictionary = SaveData.data.get("launcher", {})
	volume = clampf(float(saved.get("music_volume", DEFAULT_VOLUME)), 0.0, 1.0)
	muted = bool(saved.get("music_muted", false))
	pointer_mode = str(saved.get("pointer_mode", "menu"))
	for pair in [["sound", SVG_SOUND], ["muted", SVG_MUTED], ["gear", SVG_GEAR],
			["close", SVG_CLOSE], ["exit", SVG_EXIT], ["update", SVG_UPDATE]]:
		_icons[pair[0]] = _rasterize(pair[1])


## Volumen efectivo de la musica (0..1).
func level() -> float:
	return 0.0 if muted else volume


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# --- geometria -----------------------------------------------------------------------------

## Pantalla visible: el selector se estira al ancho del monitor (aspecto EXPAND), asi que los
## botones van a las esquinas reales y el panel al centro real.
func _screen() -> Vector2:
	return get_viewport_rect().size


func _sound_center() -> Vector2:
	return _settings_center() + Vector2(RADIUS * 2.0 + 14.0, 0)


func _exit_center() -> Vector2:
	return Vector2(_screen().x - MARGIN - RADIUS, _screen().y - MARGIN - RADIUS)


func _update_center() -> Vector2:
	return _exit_center() - Vector2(RADIUS * 2.0 + 14.0, 0)


func _settings_center() -> Vector2:
	return Vector2(MARGIN + RADIUS, _screen().y - MARGIN - RADIUS)


func _panel_rect() -> Rect2:
	var panel_size := Vector2(540, 540) if _mobile_controls() else PANEL_SIZE
	return Rect2((_screen() - panel_size) / 2.0, panel_size)


func _mobile_controls() -> bool:
	return OS.has_feature("mobile") or Paths.cmdline_value("mobile-controls") == "true"


func _mode_rect(mode: String) -> Rect2:
	var box := _control_rect(6)
	var width := (box.size.x - 8.0) / 2.0
	return Rect2(box.position + Vector2(width + 8.0 if mode == "menu" else 0.0, 0), Vector2(width, box.size.y))


func _reset_row() -> int:
	return 7 if _mobile_controls() else 6


func _close_center() -> Vector2:
	var r := _panel_rect()
	return Vector2(r.end.x - 34, r.position.y + 36)


## Fila completa del panel: 0 = musica, 1..5 = selectores.
func _row_rect(row: int) -> Rect2:
	var r := _panel_rect()
	return Rect2(r.position.x + 18, r.position.y + ROW_TOP + row * ROW_PITCH, r.size.x - 36, ROW_PITCH - 6)


## Caja de valor de una fila, con la misma columna y anchura para musica y selectores.
func _control_rect(row: int) -> Rect2:
	var line := _row_rect(row)
	var x := _panel_rect().position.x + CONTROL_X
	return Rect2(x, line.get_center().y - 17, line.end.x - 14 - x, 34)


func _slider_rect() -> Rect2:
	var box := _control_rect(0)
	return Rect2(box.position.x + 14, box.get_center().y - 4, box.size.x - 86, 8)


func _option_rect(row: int) -> Rect2:
	return _control_rect(row + 1)


func _hit(pos: Vector2) -> String:
	if panel_open:
		if _control_rect(_reset_row()).has_point(pos):
			return "reset"
		if _mobile_controls():
			for mode in ["hold", "menu"]:
				if _mode_rect(mode).has_point(pos):
					return mode
		if pos.distance_to(_close_center()) <= 16:
			return "close"
		if _slider_rect().grow_individual(8, 12, 8, 12).has_point(pos):
			return "slider"
		for row in 5:
			if _option_rect(row).has_point(pos):
				return ["aspect", "fps", "speed", "fast_play", "translations"][row]
		return "panel" if _panel_rect().has_point(pos) else "outside"
	if pos.distance_to(_sound_center()) <= RADIUS:
		return "sound"
	if pos.distance_to(_settings_center()) <= RADIUS:
		return "settings"
	if pos.distance_to(_exit_center()) <= RADIUS:
		return "exit"
	if update_available and pos.distance_to(_update_center()) <= RADIUS:
		return "update"
	return ""


# --- entrada -------------------------------------------------------------------------------

## _input: va antes que el _unhandled_input del selector, que asi no mueve la seleccion
## ni abre un juego mientras se usan estos botones o el panel.
func _input(event: InputEvent) -> void:
	if _reset_dialog.visible or _reset_result.visible:
		return
	var local_pos := Vector2.ZERO
	if event is InputEventMouse:
		local_pos = get_global_transform_with_canvas().affine_inverse() * event.position
	if event is InputEventMouseMotion:
		_hover = _hit(local_pos)
		if _dragging:
			_set_volume_from(local_pos.x)
		if panel_open or _hover != "":
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			if _dragging:
				_dragging = false
				_save()
			if panel_open:
				get_viewport().set_input_as_handled()
			return
		match _hit(local_pos):
			"sound":
				_toggle_mute()
			"settings":
				_open_panel(true)
			"exit":
				exit_requested.emit()
			"update":
				update_requested.emit()
			"reset":
				_focused_row = _reset_row()
				_request_reset()
			"hold", "menu":
				pointer_mode = _hit(local_pos)
				_focused_row = 6
				_save()
			"close", "outside":
				_open_panel(false)
			"slider":
				_focused_row = 0
				_dragging = true
				_set_volume_from(local_pos.x)
			"aspect", "fps", "speed", "fast_play", "translations":
				_focused_row = ["aspect", "fps", "speed", "fast_play", "translations"].find(_hit(local_pos)) + 1
				_cycle_option(_focused_row - 1, 1)
			"panel":
				pass
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if not panel_open:
		return
	# Arriba/abajo eligen fila; izquierda/derecha cambian su valor.
	if event.is_action_pressed("ui_cancel"):
		_open_panel(false)
	elif event.is_action_pressed("ui_up"):
		_focused_row = wrapi(_focused_row - 1, 0, _reset_row() + 1)
	elif event.is_action_pressed("ui_down"):
		_focused_row = wrapi(_focused_row + 1, 0, _reset_row() + 1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		var step := -1 if event.is_action_pressed("ui_left") else 1
		if _focused_row == 0:
			_set_volume(volume + KEY_STEP * step)
			_save()
		elif _focused_row < _reset_row():
			_cycle_option(_focused_row - 1, step)
	elif event.is_action_pressed("ui_accept"):
		if _focused_row == _reset_row():
			_request_reset()
		elif _focused_row >= 1:
			_cycle_option(_focused_row - 1, 1)
	get_viewport().set_input_as_handled()


func _request_reset() -> void:
	var spanish := Assets.lang == "s"
	_reset_dialog.title = "Reiniciar juego" if spanish else "Reset game"
	_reset_dialog.dialog_text = ("¿Volver al estado inicial?\nSe reiniciarán cartas, barajas, resultados, progreso, repeticiones y ajustes.\nLas tres barajas iniciales quedarán listas. Tus recursos importados se conservan.\nSe guardará una copia de seguridad del estado anterior."
		if spanish else "Return to the initial state?\nCards, decks, results, progress, replays and settings will be reset.\nAll three starter decks will be ready. Imported resources are preserved.\nA backup of the previous state will be kept.")
	_reset_dialog.ok_button_text = "Reiniciar" if spanish else "Reset"
	_reset_dialog.cancel_button_text = "Cancelar" if spanish else "Cancel"
	_reset_dialog.popup_centered()
	_reset_dialog.get_cancel_button().grab_focus()


func _confirm_reset() -> void:
	var spanish := Assets.lang == "s"
	var result := SaveData.reset_game()
	if result.error == "":
		LauncherSettings.reload_preferences()
		LauncherSettings.apply_timing()
		Assets.set_language(Assets.preferred_language())
		volume = DEFAULT_VOLUME
		muted = false
		pointer_mode = "menu"
		if is_instance_valid(Game._mobile_pointer):
			Game._mobile_pointer.cancel()
		_dragging = false
		_focused_row = 0
		changed.emit()
	_reset_result.title = ("Juego reiniciado" if spanish else "Game reset") if result.error == "" else ("Error al reiniciar" if spanish else "Reset failed")
	_reset_result.dialog_text = (("Estado inicial restaurado.\nCopia de seguridad: " if spanish else "Initial state restored.\nBackup: ") + result.backup) if result.error == "" else str(result.error)
	_reset_result.popup_centered()


func _cycle_option(row: int, step: int) -> void:
	match row:
		0:
			var choices := LauncherSettings.ASPECTS
			LauncherSettings.aspect = choices[wrapi(choices.find(LauncherSettings.aspect) + step, 0, choices.size())]
		1:
			var choices := LauncherSettings.FRAME_RATES
			LauncherSettings.frame_rate = choices[wrapi(choices.find(LauncherSettings.frame_rate) + step, 0, choices.size())]
		2:
			LauncherSettings.simulation_speed = 2.0 if LauncherSettings.simulation_speed == 1.0 else 1.0
		3:
			LauncherSettings.fast_play = not LauncherSettings.fast_play
		4:
			LauncherSettings.improved_card_texts = not LauncherSettings.improved_card_texts
		5:
			pointer_mode = "hold" if pointer_mode == "menu" else "menu"
			_save()
	LauncherSettings.save_preferences()
	if row == 4 and LauncherSettings.improved_card_texts:
		CardTranslations.ensure_spanish_pack()
	queue_redraw()


func _open_panel(open: bool) -> void:
	panel_open = open
	_dragging = false
	_hover = ""


func _toggle_mute() -> void:
	muted = not muted
	_save()


func _set_volume_from(x: float) -> void:
	var r := _slider_rect()
	_set_volume((x - r.position.x) / r.size.x)


func _set_volume(v: float) -> void:
	volume = snappedf(clampf(v, 0.0, 1.0), 0.01)
	# Subir el volumen desde el panel quita el silencio, como en cualquier mezclador.
	if volume > 0.0 and muted:
		muted = false
	changed.emit()


func _save() -> void:
	var saved: Dictionary = SaveData.data.get("launcher", {})
	saved.merge({"music_volume": volume, "music_muted": muted, "pointer_mode": pointer_mode}, true)
	SaveData.data["launcher"] = saved
	if Paths.has_data():
		SaveData.save()
	changed.emit()


# --- dibujo --------------------------------------------------------------------------------

func _draw() -> void:
	_medallion(_settings_center(), RADIUS, "gear", _hover == "settings" or panel_open)
	_medallion(_sound_center(), RADIUS, "muted" if muted else "sound", _hover == "sound")
	_medallion(_exit_center(), RADIUS, "exit", _hover == "exit")
	if update_available:
		_medallion(_update_center(), RADIUS, "update", _hover == "update")
		draw_circle(_update_center() + Vector2(17, -17), 5, GOLD_LIGHT)
	if update_available and _hover == "update" and not panel_open:
		var text := ("Actualizar desde GitHub" if Assets.lang == "s" else "Update from GitHub")
		if update_available:
			text += " · " + Updates.available
		var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var pos := Vector2(_screen().x - MARGIN - width, _update_center().y - RADIUS - 12)
		var bubble := Rect2(pos - Vector2(7, 20), Vector2(width + 14, 28))
		draw_rect(bubble, Color(0.04, 0.03, 0.05, 0.97))
		draw_rect(bubble, Color(GOLD, 0.45), false, 1.0)
		_label(text, pos)
	if _hover == "exit" and not panel_open:
		var text: String = {"s": "Salir", "e": "Exit", "g": "Beenden", "f": "Quitter", "i": "Esci", "j": "終了"}.get(Assets.lang, "Exit")
		var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		_label(text, _exit_center() + Vector2(-width / 2.0, -RADIUS - 10))
	if panel_open:
		_draw_panel()


## Medallon dorado: sombra, aro de oro con bisel y brillo superior, fondo de piedra oscura.
func _medallion(c: Vector2, r: float, icon: String, hot: bool) -> void:
	var s := r * (1.08 if hot else 1.0)
	if hot:
		for k in 4:
			draw_circle(c, s + 10 - k * 2.5, Color(GOLD, 0.06 + k * 0.04), true, -1.0, true)
	draw_circle(c + Vector2(1.5, 2.5), s + 0.5, Color(0, 0, 0, 0.5), true, -1.0, true)
	draw_circle(c, s, GOLD_DARK, true, -1.0, true)
	draw_circle(c, s - 1.5, GOLD if hot else BRONZE.lerp(GOLD, 0.6), true, -1.0, true)
	draw_circle(c, s - 4.5, GOLD_DARK, true, -1.0, true)
	draw_circle(c, s - 6.0, STONE, true, -1.0, true)
	draw_arc(c, s - 3.0, PI * 1.15, PI * 1.85, 16, Color(GOLD_LIGHT, 0.85), 1.5, true)
	draw_arc(c, s - 8.5, PI * 0.15, PI * 0.85, 16, Color(GOLD, 0.18), 3.0, true)
	_draw_icon(icon, c, ICON_SIZE * (1.08 if hot else 1.0), GOLD_LIGHT if hot else GOLD)


func _draw_icon(name: String, center: Vector2, size: float, color: Color) -> void:
	var icon: Dictionary = _icons[name]
	var tex: Texture2D = icon["tex"]
	var k := size / tex.get_width()
	var rect := Rect2(center - tex.get_size() * k / 2.0 + icon["offset"] * size, tex.get_size() * k)
	draw_texture_rect(tex, rect, false, color)


func _draw_panel() -> void:
	draw_rect(Rect2(Vector2.ZERO, _screen()), Color(0.01, 0.0, 0.02, 0.72))
	var r := _panel_rect()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.075, 0.05, 0.06)
	frame.border_color = GOLD.darkened(0.15)
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(14)
	frame.shadow_color = Color(0, 0, 0, 0.6)
	frame.shadow_size = 18
	frame.shadow_offset = Vector2(0, 6)
	draw_style_box(frame, r)
	var inner := StyleBoxFlat.new()
	inner.draw_center = false
	inner.border_color = Color(GOLD, 0.22)
	inner.set_border_width_all(1)
	inner.set_corner_radius_all(9)
	draw_style_box(inner, r.grow(-7))
	# Cabecera: titulo y filete con rombo, igual que el titulo de la biblioteca.
	_title_text(Assets.port_label(1), Vector2(r.get_center().x, r.position.y + 48), 24)
	_rule(r.get_center().x, r.position.y + 68, r.size.x / 2.0 - 40)
	_medallion(_close_center(), 15.0, "close", _hover == "close")
	var spanish := Assets.lang == "s"
	var names := [Assets.port_label(2)]
	names.append_array(["Aspecto", "FPS", "Simulación", "Juego rápido", "Traducciones"] if spanish else ["Aspect", "FPS", "Simulation", "Quick play", "Translations"])
	var aspects := ["Estirado", "Original sin fondo", "Overlay"] if spanish else ["Stretched", "Original, no background", "Overlay"]
	var values := [str(aspects[LauncherSettings.ASPECTS.find(LauncherSettings.aspect)]),
		("Display (%d Hz)" % LauncherSettings.display_fps()) if LauncherSettings.frame_rate == 0 else str(LauncherSettings.frame_rate),
		"Normal" if LauncherSettings.simulation_speed == 1.0 else "2×",
		("Activado" if LauncherSettings.fast_play else "Desactivado") if spanish else ("On" if LauncherSettings.fast_play else "Off"),
		("Mejoradas (ES)" if spanish else "Enhanced (ES)") if LauncherSettings.improved_card_texts else ("Originales" if spanish else "Original")]
	var keys := ["slider", "aspect", "fps", "speed", "fast_play", "translations"]
	for row in 6:
		var line := _row_rect(row)
		var hot: bool = _focused_row == row or _hover == keys[row] or (row == 0 and _dragging)
		if _focused_row == row:
			_round_rect(line, Color(GOLD, 0.07), 8)
		_label_mid(names[row], Vector2(r.position.x + 36, line.get_center().y), 17, GOLD_LIGHT)
		var box := _control_rect(row)
		_round_rect(box, Color(0.035, 0.025, 0.03), 7, GOLD if hot else Color(GOLD, 0.35))
		if row == 0:
			_draw_slider()
		else:
			_draw_selector(box, values[row - 1], hot)
	if _mobile_controls():
		_label_mid("Control táctil" if spanish else "Touch controls", Vector2(r.position.x + 36, _control_rect(6).get_center().y), 17, GOLD_LIGHT)
		for mode in ["hold", "menu"]:
			var box := _mode_rect(mode)
			var selected: bool = pointer_mode == mode
			_round_rect(box, Color(GOLD, 0.16) if selected else STONE, 7, GOLD if selected else Color(GOLD, 0.35))
			var label := ("Mantener" if spanish else "Hold") if mode == "hold" else ("Menú" if spanish else "Menu")
			var width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			_label_mid(label, box.get_center() - Vector2(width / 2.0, 0), 16, GOLD_LIGHT if selected else GOLD)
	var reset_box := _control_rect(_reset_row())
	var reset_hot := _hover == "reset" or _focused_row == _reset_row()
	_label_mid("Partida" if spanish else "Save data", Vector2(r.position.x + 36, reset_box.get_center().y), 17, GOLD_LIGHT)
	_round_rect(reset_box, Color(0.20, 0.035, 0.03), 7, GOLD if reset_hot else Color(GOLD, 0.35))
	_label_mid("Reiniciar juego…" if spanish else "Reset game…", reset_box.position + Vector2(16, 17), 16, GOLD_LIGHT)
	var foot := r.end.y - 34
	draw_line(Vector2(r.position.x + 36, foot - 16), Vector2(r.end.x - 36, foot - 16), Color(GOLD, 0.18), 1.0, true)
	var status: String = CardTranslations.status_text(spanish) if LauncherSettings.improved_card_texts else ("Traducciones: solo nombres y descripciones de cartas" if spanish else "Translations: card names and descriptions only")
	var width := minf(_font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, r.size.x - 72)
	draw_string(_font, Vector2(r.get_center().x - width / 2.0, foot + _baseline(13)), status,
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 72, 13, Color(GOLD_LIGHT, 0.6))


## Selector: valor centrado entre dos chevrones que indican que se puede cambiar.
func _draw_selector(box: Rect2, value: String, hot: bool) -> void:
	var color := GOLD_LIGHT if hot else GOLD
	var y := box.get_center().y
	for side: float in [-1.0, 1.0]:
		var x := box.get_center().x + side * (box.size.x / 2.0 - 16)
		draw_polyline(PackedVector2Array([Vector2(x - side * 3.5, y - 6), Vector2(x + side * 2.5, y), Vector2(x - side * 3.5, y + 6)]),
				Color(color, 0.9 if hot else 0.55), 2.0, true)
	var width := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_label_mid(value, Vector2(box.get_center().x - width / 2.0, y), 16, Color.WHITE if hot else GOLD_LIGHT)


func _draw_slider() -> void:
	var t := _slider_rect()
	var on := not muted
	_round_rect(t, Color(0.0, 0.0, 0.0, 0.6), 4, Color(GOLD, 0.3))
	if volume > 0.0:
		_round_rect(Rect2(t.position, Vector2(maxf(t.size.x * volume, 8.0), t.size.y)), GOLD if on else Color(0.4, 0.35, 0.3), 4)
	var knob := Vector2(t.position.x + t.size.x * volume, t.get_center().y)
	var hot := _hover == "slider" or _dragging
	var radius := 9.0 if hot else 8.0
	draw_circle(knob + Vector2(1, 2), radius, Color(0, 0, 0, 0.5), true, -1.0, true)
	draw_circle(knob, radius, GOLD_DARK, true, -1.0, true)
	draw_circle(knob, radius - 1.5, GOLD_LIGHT if hot else GOLD, true, -1.0, true)
	draw_circle(knob, 3, GOLD_DARK, true, -1.0, true)
	var text := "%d%%" % roundi(volume * 100)
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_label_mid(text, Vector2(_control_rect(0).end.x - 16 - width, t.get_center().y), 16, GOLD_LIGHT)


func _label(text: String, pos: Vector2) -> void:
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color(0, 0, 0, 0.8))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, GOLD_LIGHT)


## Texto centrado verticalmente en `left_mid.y` (por altura de letra, no por linea base).
func _label_mid(text: String, left_mid: Vector2, size: int, color: Color) -> void:
	var pos := Vector2(left_mid.x, left_mid.y + _baseline(size))
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.7))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _baseline(size: int) -> float:
	return (_font.get_ascent(size) - _font.get_descent(size)) / 2.0


func _round_rect(rect: Rect2, fill: Color, radius: int, border := Color.TRANSPARENT) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	if border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(1)
	draw_style_box(box, rect)


## Filete: dos lineas que se desvanecen hacia fuera y un rombo en el centro.
func _rule(mid: float, y: float, half: float) -> void:
	for dir: float in [-1.0, 1.0]:
		draw_polyline_colors(PackedVector2Array([Vector2(mid + dir * 10.0, y), Vector2(mid + dir * half, y)]),
				PackedColorArray([Color(GOLD, 0.8), Color(GOLD, 0.0)]), 1.5, true)
	_diamond(Vector2(mid, y), 5.0, GOLD_LIGHT)


func _title_text(text: String, center: Vector2, size: int) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(center.x - w / 2.0, center.y)
	draw_string_outline(_font, pos + Vector2(2, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, 0.6))
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, OUTLINE)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, GOLD)


func _diamond(c: Vector2, d: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0),
			c + Vector2(0, d), c + Vector2(-d, 0)]), color)


## Rasteriza el SVG a 4x y mide su centroide de alfa: `offset` (en fracciones del tamano)
## desplaza el icono para que su centro visual, no su caja, quede en el centro del medallon.
static func _rasterize(svg: String) -> Dictionary:
	var image := Image.new()
	image.load_svg_from_string(svg, 4.0)
	var sum := Vector2.ZERO
	var total := 0.0
	for y in image.get_height():
		for x in image.get_width():
			var a := image.get_pixel(x, y).a
			if a > 0.0:
				sum += Vector2(x + 0.5, y + 0.5) * a
				total += a
	var size := Vector2(image.get_size())
	var centroid := sum / total if total > 0.0 else size / 2.0
	return {"tex": ImageTexture.create_from_image(image), "offset": (size / 2.0 - centroid) / size.x}
