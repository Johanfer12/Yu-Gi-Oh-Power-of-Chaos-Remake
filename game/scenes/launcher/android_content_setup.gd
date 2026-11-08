extends Control
## Engine-only Android builds import the user's private PC-generated asset pack.
const PACK := preload("res://core/android_content_pack.gd")
const TEXTS := preload("res://scenes/launcher/import_texts.gd")
var _status: Label
var _choose: Button
var _picker: FileDialog
var _worker: Thread
var _lang := TEXTS.device_language()

func _text(key: String) -> String:
	return TEXTS.text(key, _lang)

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
	title.text = _text("pack_title")
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var instructions := Label.new()
	instructions.text = _text("pack_instructions")
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.custom_minimum_size = Vector2(620, 180)
	box.add_child(instructions)
	_choose = Button.new()
	_choose.text = _text("pack_choose")
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
	_picker.filters = PackedStringArray(["*.pck;" + _text("pack_filter") + ";application/octet-stream"])
	_picker.file_selected.connect(_import_selected)
	_picker.canceled.connect(_selection_cancelled)
	add_child(_picker)

func _select_pack() -> void:
	_picker.popup_file_dialog()

func _selection_cancelled() -> void:
	_status.text = _text("pack_cancelled")

func _import_selected(source: String) -> void:
	if _worker != null:
		return
	_choose.disabled = true
	_status.text = _text("pack_copying")
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
		_show_error(str(result.get("error", "copy")) if result is Dictionary else "copy", str(result.get("game", "")) if result is Dictionary else "")
		return
	if not Paths.mount_user_content_pack():
		_show_error("resources")
		return
	Assets.reindex()
	CardDB.load_db()
	Audio.reload_native_tables()
	SaveData.load_or_create()
	_status.text = _text("pack_ready")
	Game.open_launcher()

func _show_error(reason: String, game := "") -> void:
	_choose.disabled = false
	match reason:
		"engine":
			var title: String = {"yugi": "Yugi", "kaiba": "Kaiba", "joey": "Joey"}.get(game, game)
			_status.text = _text("pack_engine") % title
		"format", "resources":
			_status.text = _text("pack_invalid")
		"installed":
			_status.text = _text("pack_installed")
		_:
			_status.text = _text("pack_copy_failed")

func _exit_tree() -> void:
	if _worker != null and _worker.is_started():
		_worker.wait_to_finish()
