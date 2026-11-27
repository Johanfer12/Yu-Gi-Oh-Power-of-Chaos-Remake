extends Button

const Store := preload("res://core/duel_checkpoint_store.gd")
const DialogTheme := preload("res://scenes/launcher/dialog_theme.gd")
const RIVALS := {"yugi": "Yugi", "kaiba": "Kaiba", "joey": "Joey"}
var _saved := {}
var _discard := ConfirmationDialog.new()
var _open_game := Callable()


func _ready() -> void:
	name = "ContinueDuel"
	theme = DialogTheme.theme()
	custom_minimum_size = Vector2(264, 58)
	_saved = Store.read(Paths.save_dir)
	refresh()
	pressed.connect(func() -> void:
		disabled = true
		Game.resume_duel(_saved))
	DialogTheme.apply(_discard, true)
	_discard.unresizable = true
	_discard.confirmed.connect(_confirm_discard)
	add_child(_discard)


func refresh() -> void:
	if not _saved.is_empty() and not Store.exists(Paths.save_dir):
		_saved = {}
	visible = not _saved.is_empty() and Paths.has_game(_saved.game)
	if visible:
		var title := "Continuar" if Assets.lang == "s" else "Continue"
		var you := "Tú" if Assets.lang == "s" else "You"
		text = "%s\n%s: %d LP    %s: %d LP" % [title, you, _saved.lp[0], RIVALS[_saved.game], _saved.lp[1]]


func choose_game(open_game: Callable) -> void:
	refresh()
	if _saved.is_empty():
		open_game.call()
		return
	if _discard.visible:
		return
	_open_game = open_game
	var spanish := Assets.lang == "s"
	_discard.title = "Duelo en curso" if spanish else "Duel in progress"
	_discard.dialog_text = ("Si eliges un juego, perderás el duelo en curso.\n¿Quieres seguir?" if spanish
			else "Choosing a game will discard the duel in progress.\nDo you want to proceed?")
	_discard.ok_button_text = "Descartar duelo" if spanish else "Discard duel"
	_discard.cancel_button_text = "Cancelar" if spanish else "Cancel"
	_discard.popup_centered(Vector2i(480, 126))
	_discard.get_cancel_button().grab_focus()


func _confirm_discard() -> void:
	if Store.clear(Paths.save_dir) != OK:
		var dialog := AcceptDialog.new()
		dialog.title = _discard.title
		dialog.dialog_text = ("No se pudo descartar el duelo en curso." if Assets.lang == "s"
				else "The duel in progress could not be discarded.")
		DialogTheme.apply(dialog)
		add_child(dialog)
		dialog.confirmed.connect(dialog.queue_free)
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered.call_deferred(Vector2i(430, 108))
		return
	_saved = {}
	hide()
	_open_game.call()
