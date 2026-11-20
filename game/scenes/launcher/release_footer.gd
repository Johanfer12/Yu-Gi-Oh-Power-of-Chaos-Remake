extends Control
## Small shared footer for the library and the import screen.
var _version := Label.new()
var _status := Label.new()
var _github := LinkButton.new()
var _licenses := LinkButton.new()
var _row := HBoxContainer.new()
var _dialog := ConfirmationDialog.new()
var _review := VBoxContainer.new()
var _scroll := ScrollContainer.new()
var _notes := RichTextLabel.new()
var _update_message := Label.new()
var _change_history := LinkButton.new()
var _reviewed_release := ""
const RELEASES_URL := Updates.REPOSITORY + "/releases"
const HISTORY_LABELS := {
	"s": "Historial de cambios", "e": "Changelog", "g": "Änderungsverlauf",
	"f": "Historique des modifications", "i": "Cronologia delle modifiche", "j": "変更履歴",
}
const Tips = preload("res://scenes/launcher/tooltip_texts.gd")
const DialogTheme = preload("res://scenes/launcher/dialog_theme.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 14)
	_row.add_child(_version)
	_row.add_child(_github)
	_row.add_child(_licenses)
	add_child(_row)
	add_child(_status)
	add_child(_dialog)
	DialogTheme.apply(_dialog)
	for control in [_version, _status, _github, _licenses]:
		control.add_theme_font_size_override("font_size", 12)
		control.add_theme_color_override("font_color", Color(0.85, 0.77, 0.57))
	_github.text = "GitHub ↗"
	_github.pressed.connect(func() -> void: OS.shell_open(Updates.REPOSITORY))
	_licenses.pressed.connect(_open_licenses)
	_setup_review()
	_dialog.confirmed.connect(_confirm)
	_dialog.canceled.connect(func() -> void:
		_reviewed_release = ""
		Updates.cancel())
	Updates.changed.connect(refresh)
	get_viewport().size_changed.connect(_layout)
	refresh()
	Updates.check_once()


func _spanish() -> bool:
	return Assets.lang == "s"


func hint() -> String:
	match Updates.state:
		"validating", "checking": return "Buscando actualizaciones…" if _spanish() else "Checking for updates…"
		"available": return ("Disponible %s · Pulsa actualizar" if _spanish() else "%s available · Press update") % Updates.available
		"current": return "Tienes la versión más reciente" if _spanish() else "You have the latest version"
		"downloading": return "Descargando y verificando…" if _spanish() else "Downloading and verifying…"
		"installing": return "Actualizando…" if _spanish() else "Installing update…"
		# Android: el sistema confirma la instalación del APK descargado.
		"ready": return "Actualización descargada · Pulsa actualizar para instalar" if _spanish() else "Update downloaded · Press update to install"
		"opened": return "Confirma la instalación en Android" if _spanish() else "Confirm installation in Android"
		"manual": return "Actualización con otra firma: consulta el aviso" if _spanish() else "Different signing key: see details"
		"error": return "No se pudo comprobar o completar la actualización" if _spanish() else "Could not check or complete the update"
	return "Actualizaciones desde GitHub" if _spanish() else "Updates from GitHub"


func refresh() -> void:
	_version.text = ("Versión " if _spanish() else "Version ") + Updates.current
	_licenses.text = "Licencias" if _spanish() else "Licenses"
	_github.tooltip_text = Tips.text("github", Assets.lang)
	_licenses.tooltip_text = Tips.text("licenses", Assets.lang)
	_status.text = hint()
	_status.tooltip_text = Updates.detail
	if _reviewed_release != "" and (Updates.state != "available" or Updates.available != _reviewed_release):
		_reviewed_release = ""
		_dialog.hide()
	_layout.call_deferred()


func _layout() -> void:
	if not is_inside_tree():
		return
	var screen := get_viewport_rect().size
	_row.size = _row.get_combined_minimum_size()
	_row.position = Vector2((screen.x - _row.size.x) / 2.0, screen.y - 54)
	_status.size = _status.get_minimum_size()
	_status.position = Vector2((screen.x - _status.size.x) / 2.0, screen.y - 31)


func open_update() -> void:
	if not Updates.supported():
		OS.shell_open(RELEASES_URL)
		return
	if Paths.android_platform() and Updates.state in ["ready", "opened"]:
		Updates.download() # Reabre el instalador con el APK ya verificado.
		return
	if Updates.state != "available":
		Updates.check()
		return
	_show_release()


func _setup_review() -> void:
	# El alto lo fija la ventana y solo las notas pueden crecer dentro del scroll.
	_dialog.wrap_controls = false
	_dialog.dialog_autowrap = true
	_dialog.dialog_hide_on_ok = false
	_dialog.add_child(_review)
	_review.add_theme_constant_override("separation", 14)
	_review.hide()
	_review.add_child(_scroll)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_child(_notes)
	_notes.fit_content = true
	_notes.scroll_active = false
	_notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notes.add_theme_color_override("default_color", DialogTheme.GOLD_LIGHT)
	_notes.add_theme_constant_override("line_separation", 5)
	_change_history.uri = RELEASES_URL
	_change_history.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_change_history.custom_minimum_size.y = 32
	_change_history.add_theme_color_override("font_color", DialogTheme.GOLD)
	_review.add_child(_change_history)
	_review.add_child(_update_message)


func _show_release() -> void:
	_reviewed_release = Updates.available
	_change_history.text = HISTORY_LABELS.get(Assets.lang, HISTORY_LABELS["e"])
	_dialog.title = ("Actualizar a %s" if _spanish() else "Update to %s") % _reviewed_release
	_dialog.dialog_text = ""
	_dialog.get_ok_button().text = "Actualizar" if _spanish() else "Update"
	_dialog.get_ok_button().show()
	_dialog.get_cancel_button().text = "Cancelar" if _spanish() else "Cancel"
	_update_message.text = ("Android te pedirá confirmar la instalación." if _spanish()
		else "Android will ask you to confirm installation.") if Paths.android_platform() else (
		"El juego se reiniciará al instalar la actualización." if _spanish()
		else "The game will restart to install the update.")
	var notes: String = Updates.release_notes
	_fill_notes(notes if not notes.is_empty() else ("GitHub no publicó notas para esta versión." if _spanish()
		else "GitHub did not publish notes for this release."))
	_review.show()
	_dialog.popup_centered_clamped(Vector2i(680, 460), 0.80)
	_scroll.scroll_vertical = 0


## Las notas son Markdown. Dibujamos títulos, listas y negrita como texto local.
func _fill_notes(notes: String) -> void:
	_notes.clear()
	var bold := RegEx.create_from_string("\\*\\*([^*]+)\\*\\*")
	for line: String in notes.replace("\r\n", "\n").split("\n"):
		var heading := line.begins_with("#") and line.lstrip("#").begins_with(" ")
		if heading:
			line = line.lstrip("#").strip_edges()
			_notes.push_color(DialogTheme.GOLD)
			_notes.push_bold()
		elif line.begins_with("- ") or line.begins_with("* "):
			line = "• " + line.substr(2)
		var end := 0
		for span in bold.search_all(line):
			_notes.add_text(line.substr(end, span.get_start() - end))
			_notes.push_bold()
			_notes.add_text(span.get_string(1))
			_notes.pop()
			end = span.get_end()
		_notes.add_text(line.substr(end) + "\n")
		if heading:
			_notes.pop()
			_notes.pop()


func _confirm() -> void:
	if _reviewed_release.is_empty() or Updates.state != "available" or Updates.available != _reviewed_release:
		return
	_reviewed_release = ""
	Updates.download()
	if Updates.state != "downloading":
		_dialog.hide()
		return
	_review.hide()
	_dialog.get_ok_button().hide()
	_dialog.dialog_text = hint()
	var previous_size := _dialog.size
	_dialog.size = Vector2i(490, 132)
	_dialog.position += (previous_size - _dialog.size) / 2
	_dialog.get_cancel_button().grab_focus()


func _process(_delta: float) -> void:
	if Updates.state == "downloading":
		var mb: float = Updates._http.get_downloaded_bytes() / 1048576.0
		var fraction: float = Updates.progress()
		_dialog.dialog_text = hint() + (" (%d %%, %.1f MB)" % [roundi(fraction * 100.0), mb] if fraction >= 0.0 else " (%.1f MB)" % mb)
	elif _dialog.visible and not _dialog.get_ok_button().visible:
		_dialog.hide()


func _open_licenses() -> void:
	# Android no lleva las herramientas de escritorio: abre los avisos publicados.
	var directory := "" if Paths.android_platform() else BundledTools.prepare(true)
	OS.shell_open(directory if directory != "" else Updates.REPOSITORY + "/blob/main/THIRD_PARTY_NOTICES.md")
