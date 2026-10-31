extends AcceptDialog
## Ventana de Google Drive del selector: vincular, sincronizar, desconectar y elegir partida
## cuando este dispositivo y Drive cambiaron por separado.

var _buttons: Array[Button] = []
var _copied_code := ""


func _ready() -> void:
	title = "Google Drive"
	min_size = Vector2i(470, 0)
	dialog_autowrap = true
	CloudSync.changed.connect(_refresh)
	custom_action.connect(_action)
	about_to_popup.connect(_refresh)


func _refresh() -> void:
	for button in _buttons:
		remove_button(button)
		button.queue_free()
	_buttons.clear()
	var spanish := Assets.lang == "s"
	get_ok_button().text = "Cerrar" if spanish else "Close"
	var lines := PackedStringArray()
	if not CloudSync.available():
		lines.append("La sincronización no está configurada en esta versión (falta el cliente OAuth)." if spanish
				else "Sync is not configured in this build (missing OAuth client).")
	else:
		match CloudSync.state:
			"off":
				lines.append("Sincroniza cartas, barajas y resultados entre PC y Android con tu Google Drive. El juego solo puede ver los archivos que crea él mismo." if spanish
						else "Sync cards, decks and results between PC and Android through your Google Drive. The game can only see the files it creates.")
				_add("Conectar" if spanish else "Connect", "link")
			"linking":
				if CloudSync.user_code == "":
					lines.append("Conectando con Google…" if spanish else "Contacting Google…")
				else:
					if _copied_code != CloudSync.user_code:
						_copied_code = CloudSync.user_code
						DisplayServer.clipboard_set(CloudSync.user_code)
					lines.append_array(["1. Abre %s" % CloudSync.verification_url, "2. Escribe este código (ya copiado):",
						"        %s" % CloudSync.user_code, "3. Elige tu cuenta y permite el acceso. Esta ventana se actualizará sola."] if spanish
						else ["1. Open %s" % CloudSync.verification_url, "2. Enter this code (already copied):",
						"        %s" % CloudSync.user_code, "3. Choose your account and allow access. This window updates by itself."])
					_add("Abrir página" if spanish else "Open page", "open")
				_add("Cancelar" if spanish else "Cancel", "cancel")
			"conflict":
				lines.append("Esta partida y la de Drive cambiaron por separado. ¿Cuál conservar? La descartada sigue disponible: aquí como respaldo .bak y en Drive en su historial de versiones." if spanish
						else "This save and the Drive save changed separately. Which one to keep? The other stays available: here as a .bak backup and in Drive's version history.")
				lines.append("")
				lines.append(_describe(CloudSync.conflict.local, "Este dispositivo" if spanish else "This device", spanish))
				lines.append(_describe(CloudSync.conflict.remote, "Drive", spanish))
				_add("Usar la de Drive" if spanish else "Use Drive save", "remote")
				_add("Usar la de este dispositivo" if spanish else "Use this device", "local")
			_:
				match CloudSync.state:
					"syncing":
						lines.append("Sincronizando…" if spanish else "Syncing…")
					"error":
						lines.append(("Error: " if spanish else "Error: ") + CloudSync.detail)
					_:
						lines.append(("Conectado. Última sincronización: %s" if spanish else "Connected. Last sync: %s")
								% (_date(CloudSync.last_sync) if CloudSync.last_sync > 0 else ("nunca" if spanish else "never")))
						if CloudSync.detail != "":
							lines.append(CloudSync.detail)
				_add("Sincronizar ahora" if spanish else "Sync now", "sync")
				_add("Desconectar" if spanish else "Disconnect", "unlink")
		if CloudSync.state == "off" and CloudSync.detail != "":
			lines.append(CloudSync.detail)
	dialog_text = "\n".join(lines)
	reset_size()


func _add(text: String, action: String) -> void:
	_buttons.append(add_button(text, false, action))


func _action(action: StringName) -> void:
	match action:
		"link":
			CloudSync.link()
		"open":
			OS.shell_open(CloudSync.verification_url)
		"cancel":
			CloudSync.cancel_link()
		"sync":
			CloudSync.sync_now(true)
		"unlink":
			CloudSync.unlink()
		"local", "remote":
			CloudSync.resolve_conflict(action)


static func _describe(side: Dictionary, label: String, spanish: bool) -> String:
	return ("%s (%s, %s): %d cartas, %d distintas, %d victorias, %d derrotas" if spanish
			else "%s (%s, %s): %d cards, %d distinct, %d wins, %d losses") % [label, side.device, _date(side.time),
			side.cards, side.distinct, side.wins, side.losses]


static func _date(unix: int) -> String:
	var local := unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_datetime_string_from_unix_time(local, true).left(16)
