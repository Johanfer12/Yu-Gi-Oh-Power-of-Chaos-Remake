extends Node
## Imports user-owned files into the launcher's portable profile.
signal voice_requested(game: String)

const DialogTheme = preload("res://scenes/launcher/dialog_theme.gd")
const Store = preload("res://core/save_store.gd")
const REVIEW_SIZE := Vector2i(610, 370)
const FORMATS := {"voice": "Voice.dat", "ydc": ".ydc", "ydr": ".ydr", "save": "system.dat / system.json"}
const LANGUAGES := ["s", "e", "g", "f", "i", "j"]
const LABELS := {
	"resources": ["Importar más recursos", "Import more resources", "Weitere Ressourcen importieren", "Importer plus de ressources", "Importa altre risorse", "リソースを追加でインポート"],
	"game": ["Juego · automático para repeticiones", "Game · auto-detect for replays", "Spiel · Wiederholungen automatisch erkennen", "Jeu · détection des rediffusions", "Gioco · rilevamento automatico dei replay", "ゲーム（リプレイは自動検出）"],
	"game_hint": ["Elige el juego para las voces o para asignar una repetición.", "Choose a game for voices or to assign a replay.", "Wähle ein Spiel für Stimmen oder eine Wiederholung.", "Choisis un jeu pour les voix ou pour classer une rediffusion.", "Scegli un gioco per le voci o per assegnare un replay.", "音声やリプレイの対象ゲームを選択します。"],
	"voice": ["Importar voces", "Import voices", "Stimmen importieren", "Importer des voix", "Importa voci", "音声をインポート"],
	"ydc": ["Importar mazo", "Import deck", "Deck importieren", "Importer un deck", "Importa mazzo", "デッキをインポート"],
	"ydr": ["Importar repetición", "Import replay", "Wiederholung importieren", "Importer une rediffusion", "Importa replay", "リプレイをインポート"],
	"save": ["Importar partida", "Import save data", "Spielstand importieren", "Importer une sauvegarde", "Importa salvataggio", "セーブデータをインポート"],
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
var _voice: Button
var _buttons := {}
var _action_titles := {}
var _voice_games: Array[String] = []
var _selected_kind := ""
var _pending := {}


func _ready() -> void:
	for window: Window in [review, picker, confirm]:
		add_child(window)
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
	_box.add_child(_game_hint)
	_game.item_selected.connect(func(_index: int) -> void: _update_voice())
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 12)
	actions.add_theme_constant_override("v_separation", 9)
	_box.add_child(actions)
	for kind: String in FORMATS:
		var button := _make_action(kind)
		actions.add_child(button)
		_buttons[kind] = button
	_voice = _buttons["voice"]
	_voice.pressed.connect(_choose_voice)
	for kind in ["ydc", "ydr", "save"]:
		_buttons[kind].pressed.connect(_choose.bind(kind))
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
	_game_hint.text = text("game_hint")
	for game in Game.GAMES:
		_game.add_item(Game.TITLES[game])
	_game.select(0)
	review.title = text("resources")
	_heading.text = review.title
	review.ok_button_text = text("close")
	for kind in _buttons:
		var title := text(kind)
		_action_titles[kind].text = title
		_buttons[kind].accessibility_name = title
		_buttons[kind].accessibility_description = FORMATS[kind]
		_buttons[kind].disabled = Paths.storage_error or not Paths.has_data()
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
	review.hide()
	picker.popup_centered_ratio.call_deferred(0.8)


func _return_to_review() -> void:
	_show_review.call_deferred()


func _show_review() -> void:
	_status.visible = not _status.text.is_empty()
	var dialog_size := REVIEW_SIZE
	if _status.visible:
		dialog_size.y += 50
	review.popup_centered_clamped(dialog_size, 0.9)


func _selected(path: String) -> void:
	picker.hide()
	var name := path.get_file()
	var plan := _prepare(_selected_kind, path, _game_id())
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
	return plan.target.get_file() if not plan.has("game") else "%s · %s" % [Game.TITLES[plan.game], plan.target.get_file()]


func _prepare(kind: String, path: String, selected_game: String) -> Dictionary:
	var target := ""
	var plan := {"kind": kind, "source": path}
	var filename := path.get_file().get_basename()
	match kind:
		"ydc":
			if path.get_extension().to_lower() != "ydc": return {}
			var deck := Ydc.load(path)
			if deck.is_empty() or deck.main.size() > 80 or deck.fusion.size() > 15 or deck.side.size() > 15: return {}
			plan["deck"] = deck
			target = Paths.save_dir.path_join("decks").path_join(filename + ".ydc")
		"ydr":
			if path.get_extension().to_lower() != "ydr": return {}
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
			match path.get_extension().to_lower():
				"dat":
					if SystemDat.decode(FileAccess.get_file_as_bytes(path)).is_empty(): return {}
				"json":
					if not Store.valid(Store.read(path)): return {}
				_: return {}
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
	_return_to_review()


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
	return SaveData.import_system_dat(source, true) if source.get_extension().to_lower() == "dat" else SaveData.import_portable_save(source)


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
