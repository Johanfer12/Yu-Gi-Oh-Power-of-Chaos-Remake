extends Node
## Imports user-owned files into the launcher's portable profile.
signal voice_requested(game: String)

const DialogTheme = preload("res://scenes/launcher/dialog_theme.gd")
const Store = preload("res://core/save_store.gd")
const REVIEW_SIZE := Vector2i(610, 430)
const FORMATS := {"voice": "Voice.dat", "ydc": ".ydc", "ydr": ".ydr", "save": "system.dat / system.json",
	"background": "PNG / JPEG / WebP", "default_background": ""}
const MAX_IMAGE_BYTES := 32 * 1024 * 1024
const MAX_BACKGROUND_EDGE := 4096
const LANGUAGES := ["s", "e", "g", "f", "i", "j"]
const LABELS := {
	"resources": ["Importar más recursos", "Import more resources", "Weitere Ressourcen importieren", "Importer plus de ressources", "Importa altre risorse", "リソースを追加でインポート"],
	"game": ["Juego · automático para repeticiones", "Game · auto-detect for replays", "Spiel · Wiederholungen automatisch erkennen", "Jeu · détection des rediffusions", "Gioco · rilevamento automatico dei replay", "ゲーム（リプレイは自動検出）"],
	"game_hint": ["Elige el juego para las voces o para asignar una repetición.", "Choose a game for voices or to assign a replay.", "Wähle ein Spiel für Stimmen oder eine Wiederholung.", "Choisis un jeu pour les voix ou pour classer une rediffusion.", "Scegli un gioco per le voci o per assegnare un replay.", "音声やリプレイの対象ゲームを選択します。"],
	"replay_game": ["Juego para las repeticiones", "Replay destination", "Spiel für Wiederholungen", "Jeu de la rediffusion", "Gioco del replay", "リプレイのゲーム"],
	"automatic": ["Auto", "Auto", "Auto", "Auto", "Auto", "自動"],
	"voice": ["Importar voces", "Import voices", "Stimmen importieren", "Importer des voix", "Importa voci", "音声をインポート"],
	"ydc": ["Importar mazo", "Import deck", "Deck importieren", "Importer un deck", "Importa mazzo", "デッキをインポート"],
	"ydr": ["Importar repetición", "Import replay", "Wiederholung importieren", "Importer une rediffusion", "Importa replay", "リプレイをインポート"],
	"save": ["Importar partida", "Import save data", "Spielstand importieren", "Importer une sauvegarde", "Importa salvataggio", "セーブデータをインポート"],
	"background": ["Importar fondo de duelo", "Import duel background", "Duellhintergrund importieren", "Importer un fond de duel", "Importa sfondo del duello", "デュエル背景をインポート"],
	"default_background": ["Restaurar fondo original", "Restore default background", "Standardhintergrund laden", "Rétablir le fond par défaut", "Ripristina sfondo predefinito", "既定の背景に戻す"],
	"background_name": ["el fondo personalizado", "the custom background", "den eigenen Hintergrund", "le fond personnalisé", "lo sfondo personalizzato", "カスタム背景"],
	"background_applied": ["Fondo aplicado alrededor del tablero en modo Overlay.", "Background applied around the board in Overlay mode.", "Hintergrund im Overlay-Modus um das Spielfeld angewendet.", "Fond appliqué autour du plateau en mode Overlay.", "Sfondo applicato intorno al campo in modalità Overlay.", "オーバーレイモードで盤面の周囲に背景が適用されます。"],
	"background_restored": ["Fondo original restaurado.", "Default background restored.", "Standardhintergrund wiederhergestellt.", "Fond d’origine rétabli.", "Sfondo predefinito ripristinato.", "既定の背景に戻しました。"],
	"choose_replay": ["Elige el juego de esta repetición y vuelve a seleccionar el archivo.", "Choose this replay's game and select the file again.", "Wähle das Spiel und anschließend erneut die Datei.", "Sélectionne le jeu de la rediffusion, puis le fichier.", "Scegli il gioco del replay e seleziona di nuovo il file.", "リプレイのゲームを選んでから、もう一度ファイルを選択してください。"],
	"replace": ["¿Reemplazar %s?", "Replace %s?", "%s ersetzen?", "Remplacer %s ?", "Sostituire %s?", "%s を置き換えますか？"],
	"replace_save": ["Se reemplazarán la colección, los mazos activos y el progreso. Se guardará una copia de la partida anterior.", "The collection, active decks and progress will be replaced. A backup of your current save will be kept.", "Sammlung, aktive Decks und Fortschritt werden ersetzt. Der aktuelle Spielstand wird gesichert.", "La collection, les decks actifs et la progression seront remplacés. La sauvegarde actuelle sera conservée.", "La collezione, i mazzi attivi e i progressi verranno sostituiti. Il salvataggio attuale verrà conservato.", "コレクション、使用中のデッキ、進行状況を置き換えます。現在のデータはバックアップされます。"],
	"continue": ["Reemplazar", "Replace", "Ersetzen", "Remplacer", "Sostituisci", "置き換える"],
	"cancel": ["Cancelar", "Cancel", "Abbrechen", "Annuler", "Annulla", "キャンセル"],
	"close": ["Cerrar", "Close", "Schließen", "Fermer", "Chiudi", "閉じる"],
	"invalid": ["No se pudo leer o importar %s.", "Could not read or import %s.", "%s konnte nicht gelesen oder importiert werden.", "Impossible de lire ou d’importer %s.", "Impossibile leggere o importare %s.", "%s を読み込めないか、インポートできませんでした。"],
	"done": ["Importado: %s", "Imported: %s", "Importiert: %s", "Importé : %s", "Importato: %s", "インポート済み: %s"],
	"changed": ["Uno de los archivos cambió. Selecciona de nuevo el archivo que quieres importar.", "A file changed. Select the file to import again.", "Eine Datei wurde geändert. Wähle die Importdatei erneut.", "Un fichier a changé. Sélectionne de nouveau le fichier à importer.", "Un file è cambiato. Seleziona di nuovo il file da importare.", "ファイルが変更されました。インポートするファイルを選び直してください。"],
}

var review := AcceptDialog.new()
var picker := FileDialog.new()
var confirm := ConfirmationDialog.new()
var _box := VBoxContainer.new()
var _heading := Label.new()
var _game_hint := Label.new()
var _status := Label.new()
var _game := OptionButton.new()
var _replay_choices: Array[Button] = []
var _voice: Button
var _buttons := {}
var _action_titles := {}
var _voice_games: Array[String] = []
var _selected_kind := ""
var _pending := {}


func _ready() -> void:
	for window: Window in [review, picker, confirm]:
		add_child(window)
		if window != picker and Paths.android_platform():
			window.window_input.connect(_touch_window.bind(window))
	var backdrop := CanvasLayer.new()
	backdrop.layer = 80
	add_child(backdrop)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.0, 0.02, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(shade)
	backdrop.hide()
	review.visibility_changed.connect(func() -> void: backdrop.visible = review.visible)
	DialogTheme.apply(review)
	DialogTheme.apply(confirm, true)
	review.wrap_controls = false
	review.borderless = true
	var frame: StyleBoxFlat = review.theme.get_stylebox("panel", "AcceptDialog").duplicate()
	frame.border_color = DialogTheme.GOLD.darkened(0.15)
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(14)
	frame.set_content_margin_all(22)
	frame.content_margin_bottom = 14
	review.add_theme_stylebox_override("panel", frame)
	review.add_child(_box)
	_box.add_theme_constant_override("separation", 8)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.add_theme_font_size_override("font_size", 23)
	_heading.add_theme_color_override("font_color", DialogTheme.GOLD)
	_heading.add_theme_color_override("font_outline_color", DialogTheme.OUTLINE)
	_box.add_child(_heading)
	var rule := HBoxContainer.new()
	rule.alignment = BoxContainer.ALIGNMENT_CENTER
	var diamond := Label.new()
	diamond.text = "◆"
	diamond.add_theme_font_size_override("font_size", 10)
	diamond.add_theme_color_override("font_color", DialogTheme.GOLD)
	for item in [HSeparator.new(), diamond, HSeparator.new()]:
		if item is HSeparator:
			var line := StyleBoxLine.new()
			line.color = Color(DialogTheme.GOLD, 0.35)
			item.custom_minimum_size.x = 110
			item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			item.add_theme_stylebox_override("separator", line)
		rule.add_child(item)
	_box.add_child(rule)
	_game.custom_minimum_size.y = 36
	_box.add_child(_game)
	var menu := _game.get_popup()
	var menu_frame: StyleBoxFlat = frame.duplicate()
	menu_frame.border_color = Color(DialogTheme.GOLD, 0.55)
	menu_frame.set_border_width_all(1)
	menu_frame.set_corner_radius_all(6)
	menu_frame.set_content_margin_all(8)
	menu.add_theme_stylebox_override("panel", menu_frame)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(DialogTheme.GOLD, 0.14)
	hover.set_corner_radius_all(4)
	menu.add_theme_stylebox_override("hover", hover)
	menu.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	menu.add_theme_color_override("font_hover_color", Color.WHITE)
	menu.add_theme_constant_override("v_separation", 8)
	_game_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_game_hint.add_theme_font_size_override("font_size", 13)
	_game_hint.add_theme_color_override("font_color", Color(DialogTheme.GOLD_LIGHT, 0.76))
	if not Paths.android_platform():
		_box.add_child(_game_hint)
	_game.item_selected.connect(func(_index: int) -> void: _update_voice())
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 12)
	actions.add_theme_constant_override("v_separation", 9)
	if Paths.android_platform():
		_buttons["save"] = _make_action("save")
		_box.add_child(_buttons["save"])
	_box.add_child(actions)
	for kind: String in FORMATS:
		if _buttons.has(kind): continue
		var button := _make_action(kind)
		actions.add_child(button)
		_buttons[kind] = button
	_voice = _buttons["voice"]
	_voice.visible = not Paths.android_platform()
	_voice.pressed.connect(_choose_voice)
	for kind in ["ydc", "ydr", "save", "background"]:
		_buttons[kind].pressed.connect(_choose.bind(kind))
	_buttons["default_background"].pressed.connect(_restore_background)
	if Paths.android_platform():
		_game.hide()
		_box.add_child(_game_hint)
		var choices := HBoxContainer.new()
		choices.add_theme_constant_override("separation", 8)
		_box.add_child(choices)
		var group := ButtonGroup.new()
		for index in Game.GAMES.size() + 1:
			var choice := Button.new()
			choice.toggle_mode = true
			choice.button_group = group
			choice.custom_minimum_size.y = 40
			choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			choice.pressed.connect(_game.select.bind(index))
			choices.add_child(choice)
			_replay_choices.append(choice)
	_box.add_child(_status)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 14)
	_status.hide()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.use_native_dialog = true
	picker.file_selected.connect(_selected)
	picker.canceled.connect(_return_to_review)
	confirm.wrap_controls = false
	confirm.dialog_autowrap = true
	confirm.confirmed.connect(_commit)
	confirm.canceled.connect(func() -> void:
		_pending.clear()
		_return_to_review())


func _touch_window(event: InputEvent, window: Window) -> void:
	# Embedded windows receive touch directly, outside the launcher's pointer adapter.
	if not event is InputEventScreenTouch or event.index != 0: return
	var root := get_tree().root
	var point: Vector2 = root.get_screen_transform().affine_inverse() * (window.get_screen_transform() * event.position)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input.call_deferred(motion, true)
	var click := InputEventMouseButton.new()
	click.position = point
	click.global_position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if event.pressed else 0
	click.pressed = event.pressed
	click.canceled = event.canceled
	root.push_input.call_deferred(click, true)


func _make_action(kind: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 60
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inset := MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.add_theme_constant_override("margin_left", 16)
	inset.add_theme_constant_override("margin_right", 12)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(inset)
	var labels := VBoxContainer.new()
	labels.alignment = BoxContainer.ALIGNMENT_CENTER
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(labels)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 16)
	labels.add_child(title)
	_action_titles[kind] = title
	var format := Label.new()
	format.text = FORMATS[kind]
	format.visible = not format.text.is_empty()
	format.add_theme_font_size_override("font_size", 13)
	format.add_theme_color_override("font_color", Color(DialogTheme.GOLD_LIGHT, 0.70))
	labels.add_child(format)
	return button


func text(key: String) -> String:
	var index := LANGUAGES.find(Assets.lang)
	return LABELS[key][index if index >= 0 else 1]


func open(voice_games: Array[String]) -> void:
	_voice_games = voice_games
	_game.clear()
	_game.add_item(text("game"))
	_game_hint.text = text("replay_game" if Paths.android_platform() else "game_hint")
	for game in Game.GAMES:
		_game.add_item(Game.TITLES[game])
	_game.select(0)
	if not _replay_choices.is_empty():
		_replay_choices[0].text = text("automatic")
		_replay_choices[0].set_pressed_no_signal(true)
		for index in Game.GAMES.size():
			_replay_choices[index + 1].text = str(Game.GAMES[index]).capitalize()
	review.title = text("resources")
	_heading.text = review.title
	review.ok_button_text = text("close")
	for kind in _buttons:
		var title := text(kind)
		_action_titles[kind].text = title
		_buttons[kind].accessibility_name = title
		_buttons[kind].accessibility_description = FORMATS[kind]
		_buttons[kind].disabled = Paths.storage_error or (kind not in ["background", "default_background"] and not Paths.has_data())
		_buttons[kind].modulate.a = 0.48 if _buttons[kind].disabled else 1.0
	_update_voice()
	_status.text = ""
	_show_review()


func _game_id() -> String:
	return Game.GAMES[_game.selected - 1] if _game.selected > 0 else ""


func _update_voice() -> void:
	_voice.disabled = not _voice_games.has(_game_id())
	_voice.modulate.a = 0.48 if _voice.disabled else 1.0


func _choose_voice() -> void:
	review.hide()
	call_deferred("emit_signal", "voice_requested", _game_id())


func _choose(kind: String) -> void:
	_selected_kind = kind
	picker.title = text(kind)
	picker.filters = PackedStringArray(["*.dat, *.json ; system.dat / system.json"] if kind == "save" else ["*.%s ; %s" % [kind, kind.to_upper()]])
	if kind == "background":
		picker.clear_filters()
		picker.add_filter("*.png,*.jpg,*.jpeg,*.webp", FORMATS[kind], "image/png,image/jpeg,image/webp")
	review.hide()
	if OS.has_feature("android"):
		# Binary save/deck formats can be reported as different MIME types by document providers.
		if kind != "background": picker.clear_filters()
		picker.popup_file_dialog.call_deferred()
	else:
		picker.popup_centered_ratio.call_deferred(0.8)


func _return_to_review() -> void:
	_show_review.call_deferred()


func _show_review() -> void:
	var restore: Button = _buttons["default_background"]
	restore.disabled = Paths.storage_error or not FileAccess.file_exists(Paths.duel_background_path())
	restore.modulate.a = 0.48 if restore.disabled else 1.0
	_status.visible = not _status.text.is_empty()
	var dialog_size := REVIEW_SIZE
	if _status.visible:
		dialog_size.y += 50
	review.popup_centered_clamped(dialog_size, 0.9)


func _selected(path: String) -> void:
	picker.hide()
	var name := _document_name(path)
	var plan := _prepare(_selected_kind, path, _game_id(), name)
	if plan.is_empty():
		_status.text = text("invalid") % name
		_return_to_review()
		return
	if plan.get("needs_game", false):
		_status.text = text("choose_replay")
		_return_to_review()
		return
	_pending = plan
	if plan.exists:
		confirm.title = text("continue")
		confirm.dialog_text = text("replace") % _destination_label(plan)
		if _selected_kind == "save": confirm.dialog_text += "\n" + text("replace_save")
		confirm.ok_button_text = text("continue")
		confirm.cancel_button_text = text("cancel")
		confirm.popup_centered.call_deferred(Vector2i(550, 172))
		confirm.get_cancel_button().grab_focus.call_deferred()
	else:
		_commit()


func _destination_label(plan: Dictionary) -> String:
	if plan.kind == "background": return text("background_name")
	return plan.target.get_file() if not plan.has("game") else "%s · %s" % [Game.TITLES[plan.game], plan.target.get_file()]


func _document_name(path: String) -> String:
	if path.begins_with("content://") and Engine.has_singleton("AndroidRuntime"):
		var runtime := Engine.get_singleton("AndroidRuntime")
		var uri_class: Object = Engine.get_singleton("JavaClassWrapper").wrap("android.net.Uri")
		var uri: Object = uri_class.parse(path)
		var resolver: Object = runtime.getApplicationContext().getContentResolver()
		var cursor: Object = resolver.query(uri, PackedStringArray(["_display_name"]), null, null, null)
		if cursor != null:
			var name: String = str(cursor.getString(0)) if cursor.moveToFirst() and not cursor.isNull(0) else ""
			cursor.close()
			if not name.is_empty(): return name.replace("\\", "/").get_file()
	return path.get_file().uri_decode().replace("\\", "/").get_file() if path.begins_with("content://") else path.get_file()


func _prepare(kind: String, path: String, selected_game: String, name := "") -> Dictionary:
	var target := ""
	var plan := {"kind": kind, "source": path}
	if name.is_empty(): name = path.get_file()
	var filename := name.get_basename()
	var extension := name.get_extension().to_lower()
	match kind:
		"background":
			plan["raw"] = _background_bytes(path)
			if plan.raw.is_empty(): return {}
			target = Paths.duel_background_path()
		"ydc":
			if extension != "ydc": return {}
			var deck := Ydc.load(path)
			if deck.is_empty() or deck.main.size() > 80 or deck.fusion.size() > 15 or deck.side.size() > 15: return {}
			plan["deck"] = deck
			target = Paths.save_dir.path_join("decks").path_join(filename + ".ydc")
		"ydr":
			if extension != "ydr": return {}
			var raw := FileAccess.get_file_as_bytes(path)
			var replay: RefCounted = load("res://duel/core/ydr.gd").parse(raw)
			if replay == null: return {}
			var game: String = {100: "yugi", 200: "kaiba"}.get(replay.duel_version, "")
			if replay.duel_version >= 1000: game = "joey"
			# Older Joey replays can share Yugi's version; a manual choice takes priority.
			if Game.GAMES.has(selected_game): game = selected_game
			if game.is_empty(): return {"needs_game": true}
			plan["raw"] = raw
			plan["game"] = game
			target = Paths.save_dir.path_join("replays").path_join(game).path_join(filename + ".ydr")
		"save":
			plan["source_digest"] = FileAccess.get_sha256(path)
			if plan.source_digest.is_empty(): return {}
			if path.begins_with("content://") and extension not in ["dat", "json"]:
				extension = "dat" if not SystemDat.decode(FileAccess.get_file_as_bytes(path)).is_empty() else "json"
			match extension:
				"dat":
					if SystemDat.decode(FileAccess.get_file_as_bytes(path)).is_empty(): return {}
				"json":
					if not Store.valid(Store.read(path)): return {}
				_: return {}
			plan["save_format"] = extension
			target = SaveData.path()
		_: return {}
	var source_path := path.simplify_path()
	var target_path := target.simplify_path()
	if OS.get_name() == "Windows":
		source_path = source_path.to_lower()
		target_path = target_path.to_lower()
	if source_path == target_path or DirAccess.dir_exists_absolute(target):
		return {}
	plan["target"] = target
	plan["exists"] = FileAccess.file_exists(target)
	plan["digest"] = FileAccess.get_sha256(target) if plan.exists else ""
	if plan.exists and plan.digest.is_empty(): return {}
	return plan


func _commit() -> void:
	var plan := _pending
	_pending = {}
	if plan.is_empty(): return
	var target: String = plan.target
	if (FileAccess.file_exists(target) != plan.exists
			or (plan.exists and FileAccess.get_sha256(target) != plan.digest)
			or (plan.has("source_digest") and FileAccess.get_sha256(plan.source) != plan.source_digest)):
		_status.text = text("changed")
		_return_to_review()
		return
	var imported := false
	if not Paths.storage_error:
		imported = _replace_save(plan) if plan.kind == "save" else _write_file(plan)
	_status.text = text("done") % _destination_label(plan) if imported else text("invalid") % target.get_file()
	if imported and plan.kind == "background":
		LauncherSettings.aspect = "overlay"
		LauncherSettings.save_preferences()
		_status.text = text("background_applied")
	_return_to_review()


func _restore_background() -> void:
	var target := Paths.duel_background_path()
	var restored := not Paths.storage_error and DirAccess.remove_absolute(target) == OK
	_status.text = text("background_restored") if restored else text("invalid") % target.get_file()
	_show_review()


func _background_bytes(path: String) -> PackedByteArray:
	# Decode from bytes so Android providers can return extensionless content URIs.
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return PackedByteArray()
	var bytes := file.get_buffer(mini(file.get_length(), MAX_IMAGE_BYTES + 1))
	file.close()
	if bytes.size() < 12 or bytes.size() > MAX_IMAGE_BYTES: return PackedByteArray()
	var image := Image.new()
	var error := ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0x89 and bytes.slice(1, 4).get_string_from_ascii() == "PNG":
		error = image.load_png_from_buffer(bytes)
	elif bytes[0] == 0xff and bytes[1] == 0xd8:
		error = image.load_jpg_from_buffer(bytes)
	elif bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		error = image.load_webp_from_buffer(bytes)
	if error != OK or image.is_empty(): return PackedByteArray()
	var size := image.get_size()
	var edge := maxi(size.x, size.y)
	if edge > MAX_BACKGROUND_EDGE:
		var fitted := Vector2i((Vector2(size) * MAX_BACKGROUND_EDGE / edge).round())
		image.resize(maxi(1, fitted.x), maxi(1, fitted.y), Image.INTERPOLATE_LANCZOS)
	return image.save_webp_to_buffer()


func _replace_save(plan: Dictionary) -> bool:
	var target: String = plan.target
	if plan.exists:
		var backup := target.get_base_dir().path_join("system.before-import-%s.json" % Time.get_ticks_usec())
		if FileAccess.file_exists(backup) or DirAccess.copy_absolute(target, backup) != OK:
			return false
		if FileAccess.get_sha256(backup) != plan.digest:
			DirAccess.remove_absolute(backup)
			return false
	var source: String = plan.source
	return SaveData.import_system_dat(source, true) if plan.save_format == "dat" else SaveData.import_portable_save(source)


func _write_file(plan: Dictionary) -> bool:
	var target: String = plan.target
	if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK: return false
	var staging := target + ".import-%s" % Time.get_ticks_usec()
	var written := false
	if plan.kind == "ydc":
		var header := SaveData.deck_file_header(true)
		if header.is_empty(): return false
		written = Ydc.save(staging, plan.deck, header) and Ydc.load(staging) == plan.deck and Ydc.header(staging) == header
	else:
		var file := FileAccess.open(staging, FileAccess.WRITE)
		if file != null:
			file.store_buffer(plan.raw)
			file.flush()
			written = file.get_error() == OK
			file.close()
	if written and DirAccess.rename_absolute(staging, target) == OK:
		return true
	if FileAccess.file_exists(staging): DirAccess.remove_absolute(staging)
	return false
