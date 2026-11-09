extends "res://scenes/launcher/launcher.gd"
## Importacion local: Python convierte en un hilo; nunca se suben archivos a la red.

var _sources := {}
var _voice_sources := {}
var _labels := {}
var _buttons: Array[Button] = []
var _dialog := FileDialog.new()
var _status := Label.new()
var _python := LineEdit.new()
var _convert := Button.new()
var _apk := Button.new() # Crea el paquete privado de recursos (.pck) para Android.
var _download_apk := Button.new() # El APK público lo compila GitHub Actions.
var _building_apk := false
var _apk_directory := ""
var _back := Button.new()
var _thread := Thread.new()
var _pending_game := ""
var _pending_voice := false
var _target := ""
var _busy := false
var _bundled_importer := false
var _tools_failed := false
var _error_dialog := AcceptDialog.new()
const DialogTheme = preload("res://scenes/launcher/dialog_theme.gd")
var _error_details := TextEdit.new()
var _error_link := LinkButton.new()
# Extra dubs (another Voice.dat): second action button, not on the game cards.
var _voices := Button.new()
var _voice_menu := PopupMenu.new()
var _error_log_button: Button
var _error_copy_button: Button
var _error_log_path := ""


const COPY := {
	"s": ["SUBE TUS RECURSOS", "Añade un juego y empieza a jugar", "Sin seleccionar", "Voces +", "Extraer para PC", "Pasa el mouse sobre un juego para comenzar.", "Volver", "Licencias", "Preparando tus juegos… Espera a que termine.", "No se pudo importar. Revisa los archivos y vuelve a intentarlo.", "Seleccionado", "Doblajes adicionales"],
	"e": ["ADD YOUR RESOURCES", "Add a game and start playing", "Not selected", "Voices +", "Extract for PC", "Move over a game to get started.", "Back", "Licenses", "Preparing your games… Please wait.", "Could not import. Check your files and try again.", "Selected", "Additional voice packs"],
	"g": ["RESSOURCEN HINZUFÜGEN", "Füge ein Spiel hinzu und leg los", "Nicht ausgewählt", "Stimmen +", "Spiele vorbereiten", "Bewege die Maus über ein Spiel.", "Zurück", "Lizenzen", "Spiele werden vorbereitet… Bitte warten.", "Import fehlgeschlagen. Prüfe die Dateien und versuche es erneut.", "Ausgewählt", "Zusätzliche Sprachpakete"],
	"f": ["AJOUTE TES RESSOURCES", "Ajoute un jeu et commence à jouer", "Non sélectionné", "Voix +", "Préparer les jeux", "Passe la souris sur un jeu pour commencer.", "Retour", "Licences", "Préparation des jeux… Patiente un instant.", "Échec de l’importation. Vérifie les fichiers et réessaie.", "Sélectionné", "Doublages supplémentaires"],
	"i": ["AGGIUNGI LE TUE RISORSE", "Aggiungi un gioco e inizia a giocare", "Non selezionato", "Voci +", "Prepara i giochi", "Passa il mouse su un gioco per iniziare.", "Indietro", "Licenze", "Preparazione dei giochi… Attendi.", "Importazione non riuscita. Controlla i file e riprova.", "Selezionato", "Doppiaggi aggiuntivi"],
	"j": ["リソースを追加", "ゲームを追加してプレイしましょう", "未選択", "音声 +", "ゲームを準備", "ゲームにカーソルを合わせてください。", "戻る", "ライセンス", "ゲームを準備しています… お待ちください。", "インポートできませんでした。ファイルを確認して再試行してください。", "選択済み", "追加音声"]
}
var _subtitle := Label.new()
var _rows: Array[VBoxContainer] = []
var _revealed := {}
var _keyboard_reveal := false
var _pointer := Vector2(-1000, -1000)
var _pointer_inside := true
const LIBRARY := {"s": "TUS JUEGOS", "e": "YOUR GAMES", "g": "DEINE SPIELE", "f": "TES JEUX", "i": "I TUOI GIOCHI", "j": "マイゲーム"}
const LIBRARY_HINT := {"s": "Elige un juego o añade otro", "e": "Choose a game or add another", "g": "Wähle ein Spiel oder füge ein weiteres hinzu", "f": "Choisis un jeu ou ajoute-en un autre", "i": "Scegli un gioco o aggiungine un altro", "j": "ゲームを選ぶか、新しく追加しましょう"}
const TEXTS := preload("res://scenes/launcher/import_texts.gd")
const STORAGE_ERROR := {"s": "Mueve el launcher a una carpeta donde puedas guardar archivos y vuelve a abrirlo.", "e": "Move the launcher to a folder where you can save files, then reopen it.", "g": "Verschiebe den Launcher in einen beschreibbaren Ordner und öffne ihn erneut.", "f": "Déplace le lanceur dans un dossier accessible en écriture, puis rouvre-le.", "i": "Sposta il launcher in una cartella scrivibile e riaprilo.", "j": "書き込み可能なフォルダーにランチャーを移動して、開き直してください。"}


func _init() -> void:
	import_mode = true
	logo_y = 280.0
	heading_y = 108.0


func _text(key: String) -> String:
	return TEXTS.text(key, Assets.lang)


func _copy(index: int) -> String:
	return COPY.get(Assets.lang, COPY["e"])[index]


func _heading() -> String:
	return str(LIBRARY[Assets.lang]) if Paths.has_data() else _copy(0)


func _ready() -> void:
	super._ready()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_color", GOLD_LIGHT.darkened(0.15))
	_subtitle.add_theme_font_size_override("font_size", 17)
	add_child(_subtitle)
	for game in Game.GAMES:
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 7)
		column.size = Vector2(SLOT.x, 95)
		add_child(column)
		_rows.append(column)
		var row := HBoxContainer.new()
		row.visible = false
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_child(row)
		for kind in ["ISO", "folder"]:
			var button := Button.new()
			button.name = kind
			_style_control(button)
			button.pressed.connect(_browse.bind(game, kind == "ISO"))
			row.add_child(button)
			_buttons.append(button)
		var path_label := Label.new()
		path_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		path_label.add_theme_font_size_override("font_size", 13)
		path_label.add_theme_color_override("font_color", GOLD_LIGHT)
		path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_child(path_label)
		_labels[game] = path_label
	_python.text = "python"
	_python.placeholder_text = "Python 3.12+ · pocx"
	_style_control(_python)
	add_child(_python)
	var bundled := OS.get_executable_path().get_base_dir().path_join("pocx-import.exe")
	if FileAccess.file_exists(BundledTools.MANIFEST):
		# La extracción y verificación se hacen en el hilo de importación, al necesitarlas.
		_bundled_importer = true
	elif not OS.has_feature("editor") and FileAccess.file_exists(bundled):
		_bundled_importer = true
	if _bundled_importer:
		_python.text = bundled
	_python.visible = not _bundled_importer and not _tools_failed
	_style_control(_convert)
	_convert.disabled = true
	_convert.pressed.connect(_start)
	add_child(_convert)
	_style_control(_apk)
	_apk.tooltip_text = _text("apk_tooltip")
	_apk.pressed.connect(_start.bind(false, true))
	add_child(_apk)
	_style_control(_download_apk)
	_download_apk.tooltip_text = _text("download_tooltip")
	_download_apk.pressed.connect(_open_apk_download)
	add_child(_download_apk)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", GOLD_LIGHT.darkened(0.2))
	_status.add_theme_font_size_override("font_size", 14)
	add_child(_status)
	_style_control(_back)
	_back.visible = false
	_back.pressed.connect(Game.open_launcher)
	add_child(_back)
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.file_selected.connect(_selected)
	_dialog.dir_selected.connect(_selected)
	add_child(_dialog)
	_error_details.editable = false
	_error_details.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_error_details.custom_minimum_size = Vector2(590, 300)
	_error_details.add_theme_font_size_override("font_size", 14)
	_error_dialog.add_child(_error_details)
	_error_copy_button = _error_dialog.add_button("Copiar detalles", false, "copy")
	_error_log_button = _error_dialog.add_button("Abrir registro", false, "log")
	_error_dialog.custom_action.connect(func(action: StringName) -> void:
		if action == "copy":
			DisplayServer.clipboard_set(_error_details.text)
		elif action == "log":
			OS.shell_open(_error_log_path))
	add_child(_error_dialog)
	DialogTheme.apply(_error_dialog)
	_error_link.visible = false
	_error_link.pressed.connect(func() -> void: _error_dialog.popup_centered(Vector2i(650, 400)))
	add_child(_error_link)
	_style_control(_voices)
	_voices.pressed.connect(_open_voice_menu)
	add_child(_voices)
	_voice_menu.id_pressed.connect(func(id: int) -> void: _browse_voice(Game.GAMES[id]))
	var menu_panel := StyleBoxFlat.new()
	menu_panel.bg_color = Color(0.075, 0.05, 0.06)
	menu_panel.border_color = Color(GOLD_LIGHT.darkened(0.15), 0.7)
	menu_panel.set_border_width_all(1)
	menu_panel.set_corner_radius_all(6)
	menu_panel.set_content_margin_all(6)
	var menu_hover := StyleBoxFlat.new()
	menu_hover.bg_color = Color(GOLD_LIGHT, 0.12)
	menu_hover.set_corner_radius_all(4)
	_voice_menu.add_theme_stylebox_override("panel", menu_panel)
	_voice_menu.add_theme_stylebox_override("hover", menu_hover)
	_voice_menu.add_theme_color_override("font_color", GOLD_LIGHT)
	_voice_menu.add_theme_color_override("font_hover_color", Color.WHITE)
	_voice_menu.add_theme_font_size_override("font_size", 15)
	add_child(_voice_menu)

	get_tree().root.close_requested.connect(_close)
	get_tree().root.mouse_exited.connect(_pointer_left_window)
	get_tree().root.mouse_entered.connect(_pointer_entered_window)
	_language_updated()
	_layout()
	if Paths.migration_source != "" and not Paths.storage_error:
		_start.call_deferred(true)


func _language_updated() -> void:
	super._language_updated()
	_subtitle.text = str(LIBRARY_HINT[Assets.lang]) if Paths.has_data() else _copy(1)
	_convert.text = _copy(4)
	_convert.visible = true
	_apk.text = {"s": "Crear .pck", "e": "Create .pck", "g": ".pck erstellen", "f": "Créer le .pck", "i": "Crea .pck", "j": ".pckを作成"}.get(Assets.lang, "Create .pck")
	_download_apk.text = {"s": "Descargar APK", "e": "Download APK", "g": "APK herunterladen", "f": "Télécharger l'APK", "i": "Scarica APK", "j": "APKをダウンロード"}.get(Assets.lang, "Download APK")
	_download_apk.disabled = _busy
	_voices.text = _copy(3)
	_voices.tooltip_text = _copy(11)
	_update_voices()
	_apk.disabled = _busy or _tools_failed or Paths.storage_error or (not _has_pending() and not Paths.has_data())
	if not _busy:
		_status.text = _copy(5)
	_back.text = _copy(6)
	for i in _rows.size():
		var game: String = Game.GAMES[i]
		var buttons := _rows[i].get_child(0)
		buttons.get_node("ISO").text = "ISO"
		buttons.get_node("folder").text = _folder_label()
		var installed := Paths.has_game(game)
		buttons.get_node("ISO").visible = not installed
		buttons.get_node("folder").visible = not installed
		_labels[game].text = _sources[game].get_file() if _sources.has(game) else "+ " + _copy(2)
		_labels[game].visible = not installed
	if _tools_failed:
		_status.text = _copy(9)
	if Paths.storage_error:
		_status.text = str(STORAGE_ERROR[Assets.lang])
		_convert.disabled = true
	_layout.call_deferred()


func _layout() -> void:
	super._layout()
	_subtitle.position = _origin + Vector2(20, 152)
	_subtitle.size = Vector2(760, 30)
	for i in _rows.size():
		var row: Control = _rows[i].get_child(0)
		var center := _import_center(i)
		_rows[i].position = center - Vector2(SLOT.x / 2.0, row.get_combined_minimum_size().y / 2.0)
		var label: Label = _labels[Game.GAMES[i]]
		label.position = _logos[i].position + Vector2(-SLOT.x / 2.0, 88)
		label.size = Vector2(SLOT.x, 22)
	# Bloque de acciones pegado a los logos y separado del pie, centrado en la pantalla real.
	# Sin el campo de Python (version publicada) los botones suben a ocupar su hueco.
	var actions_y := 446.0 if _python.visible else 414.0
	_python.position = _origin + Vector2(250, 404)
	_python.size = Vector2(300, 32)
	# Four actions in one row: extract, extra dubs, Android .pck and APK download.
	for index in 4:
		var action: Button = [_convert, _voices, _apk, _download_apk][index]
		action.position = _origin + Vector2(20 + index * 195, actions_y)
		action.size = Vector2(175, 42)
	_status.position = _origin + Vector2(90, actions_y + 52)
	_status.size = Vector2(620, 24)
	if _error_link.visible:
		_status.size.x = 510
	_error_link.position = _origin + Vector2(622, actions_y + 55)
	_back.position = Vector2(24, 24)


func _choose(index: int) -> void:
	if _busy or Paths.storage_error:
		return
	if Paths.has_game(Game.GAMES[index]):
		super._choose(index)
	else:
		_browse(Game.GAMES[index], true)


func _has_pending() -> bool:
	if not _sources.is_empty():
		return true
	for game: String in _voice_sources:
		if Paths.has_game(game):
			return true
	return false


func _card_revealed(index: int) -> bool:
	return _revealed.get(index, false)


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer = event.position
		_keyboard_reveal = false
	elif event is InputEventKey and event.pressed:
		_keyboard_reveal = true


func _pointer_left_window() -> void:
	_pointer_inside = false
	_keyboard_reveal = false


func _pointer_entered_window() -> void:
	_pointer_inside = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_keyboard_reveal = false
	elif event is InputEventKey and event.pressed:
		_keyboard_reveal = true
	super._unhandled_input(event)


func _browse(game: String, iso: bool) -> void:
	_pending_game = game
	_pending_voice = false
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if iso else FileDialog.FILE_MODE_OPEN_DIR
	_dialog.filters = PackedStringArray(["*.iso ; ISO"]) if iso else PackedStringArray()
	_dialog.title = Game.TITLES[game]
	_dialog.popup_centered_ratio(0.8)


## A dub belongs to a game that is prepared or selected in this same import.
func _voice_games() -> Array[String]:
	var games: Array[String] = []
	for game: String in Game.GAMES:
		if Paths.has_game(game) or _sources.has(game):
			games.append(game)
	return games


func _update_voices() -> void:
	_voices.disabled = _busy or _tools_failed or Paths.storage_error or _voice_games().is_empty()


func _open_voice_menu() -> void:
	_voice_menu.clear()
	for game in _voice_games():
		_voice_menu.add_item(Game.TITLES[game], Game.GAMES.find(game))
	var at := _voices.get_screen_position() + Vector2(0, _voices.size.y + 4)
	_voice_menu.popup(Rect2i(Vector2i(at), Vector2i.ZERO))


func _browse_voice(game: String) -> void:
	_pending_game = game
	_pending_voice = true
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.filters = PackedStringArray(["*.dat ; Voice.dat"])
	_dialog.title = "%s · %s" % [Game.TITLES[game], _copy(11)]
	_dialog.popup_centered_ratio(0.8)


func _selected(path: String) -> void:
	if _pending_voice:
		var packs: Array = _voice_sources.get_or_add(_pending_game, [])
		if not packs.has(path):
			packs.append(path)
		_status.text = "%s · %s: %s" % [Game.TITLES[_pending_game], _copy(11), packs.size()]
		_convert.disabled = not _has_pending() or _tools_failed
		_convert.visible = true
		_apk.disabled = _tools_failed or Paths.storage_error or not _has_pending()
		return
	_sources[_pending_game] = path
	_labels[_pending_game].text = path.get_file()
	_labels[_pending_game].tooltip_text = path
	_convert.disabled = _tools_failed or not _has_pending()
	_convert.visible = true
	_apk.disabled = _tools_failed or Paths.storage_error or not _has_pending()
	_status.text = "%s: %s" % [_copy(10), _sources.size()]
	_update_voices()


func _start(migrate := false, build_apk := false) -> void:
	if _busy or _tools_failed or Paths.storage_error or (not migrate and not _has_pending() and not (build_apk and Paths.has_data())):
		return
	_building_apk = build_apk
	_error_dialog.hide()
	_error_link.hide()
	_status.tooltip_text = ""
	_apk_directory = ProjectSettings.globalize_path("res://").path_join("..").simplify_path() if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	var launcher_override := Paths.cmdline_value("launcher-dir")
	if launcher_override != "":
		_apk_directory = launcher_override
	_target = Paths.resources_path()
	var args := PackedStringArray() if _bundled_importer else PackedStringArray(["-m", "pocx.import_games"])
	args.append_array(PackedStringArray(["--out", _apk_directory if build_apk else _target, "--lang", Assets.lang]))
	if build_apk:
		args.append("--create-apk")
	if FileAccess.file_exists(_target.path_join("inventory.json")):
		args.append("--replace")
	if Paths.has_data():
		args.append_array(PackedStringArray(["--base", Paths.data_dir]))
	for game in _sources:
		args.append("--" + game)
		args.append(str(_sources[game]))
	for game in _voice_sources:
		# A dub needs its game: already prepared or selected in this same import.
		if not Paths.has_game(game) and not _sources.has(game):
			continue
		for voice_path in _voice_sources[game]:
			args.append("--voice")
			args.append(game + "=" + str(voice_path))
	_busy = true
	set_process(true)
	get_tree().auto_accept_quit = false
	for button in _buttons:
		button.disabled = true
	_convert.disabled = true
	_apk.disabled = true
	_download_apk.disabled = true
	_voices.disabled = true
	_back.disabled = true
	_python.editable = false
	_status.text = _text("apk_preparing") if build_apk else _copy(8)
	_language.disabled = true
	var output_log := Paths.storage_dir.path_join("converter-output.log")
	args.append_array(PackedStringArray(["--output-log", output_log]))
	var executable := _python.text.strip_edges()
	var error := _thread.start(func() -> Dictionary:
		var importer := executable
		if FileAccess.file_exists(BundledTools.MANIFEST):
			importer = BundledTools.prepare()
			if importer == "":
				return {"code": -1, "output": "No se pudieron preparar las herramientas de importación."}
		if FileAccess.file_exists(output_log) and DirAccess.remove_absolute(output_log) != OK:
			return {"code": -1, "output": "No se pudo preparar el registro de conversión. / Could not prepare conversion log."}
		var output: Array = []
		var code := OS.execute(importer, args, output, true)
		var text := FileAccess.get_file_as_string(output_log) if FileAccess.file_exists(output_log) else "\n".join(output)
		return {"code": code, "output": text})
	if error != OK:
		_finish({"code": -1, "output": "No se pudo iniciar el hilo de importación."})


func _process(_delta: float) -> void:
	super._process(_delta)
	# Poll the viewport as other controls may consume mouse motion before _input.
	var pointer := _pointer if DisplayServer.get_name() == "headless" else get_viewport().get_mouse_position()
	var hit := _hit(pointer) if _pointer_inside and not _controls.panel_open else -1
	if hit >= 0 and not _keyboard_reveal:
		_selected_index = hit
	for i in _rows.size():
		var available: bool = not Paths.has_game(Game.GAMES[i]) and not _controls.panel_open
		var reveal: bool = available and (hit == i or (_keyboard_reveal and i == _selected_index))
		var row := _rows[i].get_child(0)
		for button: Button in row.get_children():
			if available and _keyboard_reveal and button.has_focus():
				reveal = true
			elif not _keyboard_reveal and hit != i and button.has_focus():
				button.release_focus()
		_revealed[i] = reveal
		row.visible = reveal
		for button: Button in row.get_children():
			button.mouse_filter = Control.MOUSE_FILTER_STOP if reveal else Control.MOUSE_FILTER_IGNORE
		if _logos[i].material != null:
			_logos[i].material.set_shader_parameter("reveal", 1.0 if reveal else 0.0)
	if _busy and _thread.is_started() and not _thread.is_alive():
		_finish(_thread.wait_to_finish())
	elif _busy and _building_apk:
		var progress := _apk_directory.path_join("PoC Data/android/progress.json")
		if FileAccess.file_exists(progress):
			var parser := JSON.new()
			if parser.parse(FileAccess.get_file_as_string(progress)) == OK and parser.data is Dictionary:
				_status.text = str(parser.data.get("message", _status.text))


func _finish(result: Dictionary) -> void:
	_busy = false
	_language.disabled = false
	get_tree().auto_accept_quit = true
	for button in _buttons:
		button.disabled = false
	_convert.disabled = not _has_pending() or _tools_failed
	_apk.disabled = _tools_failed or Paths.storage_error or (not _has_pending() and not Paths.has_data())
	_download_apk.disabled = false
	_update_voices()
	_back.disabled = false
	_python.editable = true
	if int(result["code"]) != 0:
		_show_import_error(result)
		return
	if _building_apk:
		_status.text = _text("apk_ready")
		_status.tooltip_text = str(result["output"])
		if DisplayServer.get_name() != "headless":
			OS.shell_open(_apk_directory.path_join("PoC Data/android/pck"))
		return
	var config := ConfigFile.new()
	config.load(Paths.settings_path())
	config.set_value("content", "data", "resources")
	var error := config.save(Paths.settings_path())
	if error != OK:
		var reason := _text("settings_failed") + error_string(error)
		_show_import_error({"code": error, "output": "POC_IMPORT_ERROR " + JSON.stringify({"stage": "write", "source": Paths.settings_path(), "reason": reason})})
		return
	Paths.data_dir = _target
	Paths.migration_source = ""
	Assets.reindex()
	CardDB.load_db()
	Audio.reload_native_tables()
	SaveData.load_or_create()
	Assets.remember_language(Assets.lang)
	Game.open_launcher()


func _show_import_error(result: Dictionary) -> void:
	var output := str(result.get("output", ""))
	var failure := {}
	for line: String in output.split("\n"):
		var marker := line.find("POC_IMPORT_ERROR ")
		if marker >= 0:
			var parser := JSON.new()
			if parser.parse(line.substr(marker + 17).strip_edges()) == OK and parser.data is Dictionary:
				failure = parser.data
	var title := _text("title_apk_failed" if _building_apk else "title_import_failed")
	var game := str(failure.get("game", "")) if failure.get("game") != null else ""
	var game_label := game.capitalize() if game in Game.GAMES else ""
	var stage_key := "stage_" + str(failure.get("stage", ""))
	var stage := _text(stage_key if TEXTS.TEXT.has(stage_key) else "stage_process")
	var heading := title + (" · " + game_label if game_label != "" else "")
	var reason := str(failure.get("reason", ""))
	if reason == "":
		reason = _text("process_failed") % str(result.get("code", -1))
	var source := str(failure.get("source", "")) if failure.get("source") != null else ""
	_error_log_path = Paths.storage_dir.path_join("apk-last-error.log" if _building_apk else "import-last-error.log")
	var log_file := FileAccess.open(_error_log_path, FileAccess.WRITE)
	var saved := log_file != null
	if saved:
		log_file.store_string(output)
		log_file.close()
	var detail := heading + "\n" + stage + "\n\n" + reason
	if source != "":
		detail += "\n\n" + _text("source_label") + source
	var diagnostics := str(failure.get("diagnostics", ""))
	if diagnostics == "":
		diagnostics = output
	if diagnostics != "":
		detail += "\n\n" + _text("details_label") + "\n" + diagnostics
	detail += "\n\n" + _text("log_label") + _error_log_path
	if not saved:
		detail += "\n" + _text("log_not_saved")
	_error_details.text = detail
	_error_dialog.title = heading
	_error_dialog.get_ok_button().text = _text("close")
	_error_copy_button.text = _text("copy_details")
	_error_log_button.text = _text("open_log")
	_error_log_button.disabled = not saved
	_status.text = heading + " · " + stage
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.tooltip_text = detail
	_error_link.text = _text("view_error")
	_error_link.show()
	_layout()
	_error_dialog.popup_centered(Vector2i(650, 400))


func _close() -> void:
	if _busy:
		if not _building_apk:
			_status.text = _copy(8)


func _open_apk_download() -> void:
	# Release de esta misma versión: su APK acepta el formato del .pck que crea este launcher.
	OS.shell_open(Updates.REPOSITORY + "/releases/download/%s/PowerOfChaos-Android.apk" % Updates.current)


func _open_licenses() -> void:
	var directory := BundledTools.prepare(true)
	if directory != "":
		OS.shell_open(directory)
	else:
		_status.text = _copy(9)


func _request_exit() -> void:
	if _busy:
		_close()
	else:
		super._request_exit()


func _request_update() -> void:
	if not _busy:
		super._request_update()


func _exit_tree() -> void:
	super._exit_tree()
	if _thread.is_started():
		_thread.wait_to_finish()
	get_tree().auto_accept_quit = true
