extends Control
## Small shared footer for the library and the import screen.
var _version := Label.new()
var _status := Label.new()
var _github := LinkButton.new()
var _licenses := LinkButton.new()
var _row := HBoxContainer.new()
var _dialog := ConfirmationDialog.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 14)
	_row.add_child(_version)
	_row.add_child(_github)
	_row.add_child(_licenses)
	add_child(_row)
	add_child(_status)
	add_child(_dialog)
	for control in [_version, _status, _github, _licenses]:
		control.add_theme_font_size_override("font_size", 12)
		control.add_theme_color_override("font_color", Color(0.85, 0.77, 0.57))
	_github.text = "GitHub ↗"
	_github.tooltip_text = Updates.REPOSITORY
	_github.pressed.connect(func() -> void: OS.shell_open(Updates.REPOSITORY))
	_licenses.pressed.connect(_open_licenses)
	_dialog.confirmed.connect(_confirm)
	_dialog.canceled.connect(func() -> void: Updates.cancel())
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
	_status.text = hint()
	_status.tooltip_text = Updates.detail
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
		OS.shell_open(Updates.REPOSITORY + "/releases")
		return
	if Paths.android_platform() and Updates.state in ["ready", "opened"]:
		Updates.download() # Reabre el instalador con el APK ya verificado.
		return
	if Updates.state != "available":
		Updates.check()
		return
	_dialog.title = "Actualizar" if _spanish() else "Update"
	if Paths.android_platform():
		_dialog.dialog_text = (("Descargar %s aquí?\nAndroid te pedirá confirmar la instalación. No desinstales la aplicación.\nSe conservan tus recursos, partidas y ajustes." if _spanish()
			else "Download %s here?\nAndroid will ask you to confirm installation. Do not uninstall the app.\nYour resources, saves and settings are preserved.") % Updates.available)
	else:
		_dialog.dialog_text = (("Descargar %s y reiniciar el juego?\nSe conservan tus recursos, partidas y ajustes." if _spanish()
			else "Download %s and restart the game?\nYour resources, saves and settings are preserved.") % Updates.available)
	_dialog.get_ok_button().text = "Actualizar" if _spanish() else "Update"
	_dialog.get_ok_button().show()
	_dialog.get_cancel_button().text = "Cancelar" if _spanish() else "Cancel"
	_dialog.popup_centered()


func _confirm() -> void:
	Updates.download()
	if Updates.state == "downloading":
		_dialog.hide_on_ok = false
		_dialog.get_ok_button().hide()
		_dialog.popup_centered.call_deferred()


func _process(_delta: float) -> void:
	if Updates.state == "downloading":
		var mb: float = Updates._http.get_downloaded_bytes() / 1048576.0
		var fraction: float = Updates.progress()
		_dialog.dialog_text = hint() + (" (%d %%, %.1f MB)" % [roundi(fraction * 100.0), mb] if fraction >= 0.0 else " (%.1f MB)" % mb)
	elif _dialog.visible and not _dialog.get_ok_button().visible:
		_dialog.hide()
		_dialog.hide_on_ok = true


func _open_licenses() -> void:
	# Android no lleva las herramientas de escritorio: abre los avisos publicados.
	var directory := "" if Paths.android_platform() else BundledTools.prepare(true)
	OS.shell_open(directory if directory != "" else Updates.REPOSITORY + "/blob/main/THIRD_PARTY_NOTICES.md")
