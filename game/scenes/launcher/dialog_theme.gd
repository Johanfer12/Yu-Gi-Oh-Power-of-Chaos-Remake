extends RefCounted
## Estilo dorado de las ventanas del selector (reiniciar, Google Drive, actualizar, errores),
## igual que el panel de ajustes: fondo oscuro, marco dorado, titulo dorado y botones con borde.

const GOLD := Color(1.0, 0.82, 0.3)
const GOLD_LIGHT := Color(1.0, 0.95, 0.7)
const OUTLINE := Color(0.35, 0.08, 0.02)
const BACKGROUND := Color(0.075, 0.05, 0.06)
const DANGER := Color(0.20, 0.035, 0.03)
const TITLE_HEIGHT := 46
const CLOSE_SVG := "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='#%s' stroke-width='2.4' stroke-linecap='round'><line x1='18' y1='6' x2='6' y2='18'/><line x1='6' y1='6' x2='18' y2='18'/></svg>"

static var _theme: Theme


## Aplica el tema a una ventana de dialogo. danger: el boton Aceptar destruye algo (rojo).
static func apply(dialog: AcceptDialog, danger := false) -> void:
	dialog.theme = theme()
	# Sin fondo propio: las esquinas redondeadas del contenido dejan ver el marco, no negro.
	dialog.transparent_bg = true
	dialog.get_ok_button().focus_mode = Control.FOCUS_ALL
	if danger:
		for state in ["normal", "hover", "pressed"]:
			var style := _button(state)
			style.bg_color = DANGER.lightened(0.12) if state != "normal" else DANGER
			dialog.get_ok_button().add_theme_stylebox_override(state, style)


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var mobile := OS.has_feature("mobile") or Paths.cmdline_value("mobile-controls") == "true"
	_theme = Theme.new()
	_theme.default_font_size = 17
	# Marco de la ventana incrustada: el margen superior deja sitio a la barra de titulo.
	var border := StyleBoxFlat.new()
	border.bg_color = BACKGROUND
	border.border_color = GOLD.darkened(0.15)
	border.set_border_width_all(2)
	border.set_corner_radius_all(14)
	border.shadow_color = Color(0, 0, 0, 0.6)
	border.shadow_size = 18
	border.shadow_offset = Vector2(0, 6)
	border.expand_margin_left = 14
	border.expand_margin_right = 14
	border.expand_margin_bottom = 14
	border.expand_margin_top = TITLE_HEIGHT + 6
	border.anti_aliasing = true
	_theme.set_stylebox("embedded_border", "Window", border)
	_theme.set_stylebox("embedded_unfocused_border", "Window", border)
	_theme.set_constant("title_height", "Window", TITLE_HEIGHT)
	_theme.set_color("title_color", "Window", GOLD)
	_theme.set_font_size("title_font_size", "Window", 21)
	_theme.set_constant("title_outline_size", "Window", 6)
	_theme.set_color("title_outline_modulate", "Window", OUTLINE)
	_theme.set_icon("close", "Window", _close_icon(GOLD))
	_theme.set_icon("close_pressed", "Window", _close_icon(GOLD_LIGHT))
	_theme.set_constant("close_h_offset", "Window", 22)
	_theme.set_constant("close_v_offset", "Window", 32)
	# Contenido: filete dorado tenue, como el marco interior del panel de ajustes.
	var panel := StyleBoxFlat.new()
	panel.bg_color = BACKGROUND
	panel.border_color = Color(GOLD, 0.22)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(9)
	panel.set_content_margin_all(18)
	panel.content_margin_bottom = 14
	panel.anti_aliasing = true
	_theme.set_stylebox("panel", "AcceptDialog", panel)
	_theme.set_constant("buttons_separation", "AcceptDialog", 16)
	_theme.set_constant("buttons_min_width", "AcceptDialog", 128)
	_theme.set_constant("buttons_min_height", "AcceptDialog", 48 if mobile else 38)
	_theme.set_color("font_color", "Label", GOLD_LIGHT)
	_theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.7))
	_theme.set_constant("outline_size", "Label", 3)
	_theme.set_constant("line_spacing", "Label", 4)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_theme.set_stylebox(state, "Button", _button(state))
	_theme.set_color("font_color", "Button", GOLD_LIGHT)
	_theme.set_color("font_hover_color", "Button", Color.WHITE)
	_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	_theme.set_color("font_focus_color", "Button", Color.WHITE)
	_theme.set_color("font_disabled_color", "Button", Color(GOLD_LIGHT, 0.35))
	_theme.set_font_size("font_size", "Button", 16)
	return _theme


static func _button(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.075, 0.12, 0.96) if state in ["hover", "pressed"] else Color(0.035, 0.025, 0.03)
	style.border_color = Color(GOLD, 0.25) if state == "disabled" else (Color(GOLD, 0.35) if state == "normal" else GOLD)
	style.draw_center = state != "focus"
	style.set_border_width_all(2 if state == "focus" else 1)
	style.set_corner_radius_all(7)
	style.anti_aliasing = true
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


static func _close_icon(color: Color) -> ImageTexture:
	var image := Image.new()
	image.load_svg_from_string(CLOSE_SVG % color.to_html(false), 0.9)
	return ImageTexture.create_from_image(image)
