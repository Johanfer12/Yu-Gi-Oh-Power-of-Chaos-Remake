extends Control
## Engine-only Android builds import the user's private PC-generated asset pack.
const PACK := preload("res://core/android_content_pack.gd")
var _status: Label
var _choose: Button
var _picker: FileDialog
var _worker: Thread
var _spanish := OS.get_locale_language() == "es"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.035, 0.025, 0.065)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 0)
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)
	var title := Label.new()
	title.text = "Añade tus juegos" if _spanish else "Add your games"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var instructions := Label.new()
	instructions.text = ("Esta aplicación necesita los recursos de tus juegos.\n\nEn el launcher de PC, crea el paquete de recursos para Android y copia el archivo .pck a este dispositivo. Después, selecciónalo aquí.\n\nSólo hace falta importarlo una vez. Tus partidas y recursos se conservan al actualizar la aplicación." if _spanish else "This app needs the resources from your games.\n\nUse the PC launcher to create the Android resource pack and copy the .pck file to this device. Then select it here.\n\nImport it once. App updates keep your game resources and saved games.")
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.custom_minimum_size = Vector2(620, 180)
	box.add_child(instructions)
	_choose = Button.new()
	_choose.text = "Seleccionar paquete .pck" if _spanish else "Select .pck resource pack"
	_choose.custom_minimum_size.y = 64
	_choose.pressed.connect(_select_pack)
	box.add_child(_choose)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(620, 65)
	box.add_child(_status)
	_picker = FileDialog.new()
	_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_picker.access = FileDialog.ACCESS_FILESYSTEM
	_picker.use_native_dialog = true
	_picker.filters = PackedStringArray(["*.pck;" + ("Recursos del juego" if _spanish else "Game resources") + ";application/octet-stream"])
	_picker.file_selected.connect(_import_selected)
	_picker.canceled.connect(_selection_cancelled)
	add_child(_picker)

func _select_pack() -> void:
	_picker.popup_file_dialog()

func _selection_cancelled() -> void:
	_status.text = "Selección cancelada. Puedes intentarlo cuando quieras." if _spanish else "Selection cancelled. You can try again whenever you want."

func _import_selected(source: String) -> void:
	if _worker != null:
		return
	_choose.disabled = true
	_status.text = "Copiando y comprobando tus recursos…" if _spanish else "Copying and checking your resources…"
	_worker = Thread.new()
	var started := _worker.start(PACK.install_pack.bind(source, Paths.user_content_pack_path()))
	if started != OK:
		_worker = null
		_show_error("copy")
		return
	while _worker.is_alive():
		await get_tree().process_frame
	var result: Variant = _worker.wait_to_finish()
	_worker = null
	if not result is Dictionary or not result.get("ok", false):
		_show_error(str(result.get("error", "copy")) if result is Dictionary else "copy")
		return
	if not Paths.mount_user_content_pack():
		_show_error("resources")
		return
	Assets.reindex()
	CardDB.load_db()
	Audio.reload_native_tables()
	SaveData.load_or_create()
	_status.text = "Recursos listos." if _spanish else "Resources ready."
	Game.open_launcher()

func _show_error(reason: String) -> void:
	_choose.disabled = false
	match reason:
		"format", "resources":
			_status.text = "Ese archivo no es un paquete de recursos válido. Crea uno nuevo desde el launcher de PC." if _spanish else "That file is not a valid game resource pack. Create a new one with the PC launcher."
		"installed":
			_status.text = "Ya hay un paquete de recursos guardado. Cierra y abre la aplicación para cargarlo." if _spanish else "A resource pack is already saved. Close and reopen the app to load it."
		_:
			_status.text = "No se pudo copiar el archivo. Comprueba el espacio disponible y vuelve a seleccionarlo." if _spanish else "The file could not be copied. Check available storage and select it again."

func _exit_tree() -> void:
	if _worker != null and _worker.is_started():
		_worker.wait_to_finish()
