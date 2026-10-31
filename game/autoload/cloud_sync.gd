extends Node
## Sincroniza saves/system.json entre PC y Android a traves de Google Drive.
## Como el GDriveBackupManager de SmartTube: flujo OAuth para dispositivos (codigo que se
## introduce en google.com/device), permiso drive.file (solo ve lo que crea el juego) y la
## API REST v3 sin SDK. A diferencia de SmartTube no sobrescribe a ciegas: compara los MD5
## local y remoto con los del ultimo acuerdo y, si cambiaron ambos, pregunta al jugador.

signal changed
signal save_replaced

const SCOPE := "https://www.googleapis.com/auth/drive.file"
const DEVICE_GRANT := "urn:ietf:params:oauth:grant-type:device_code"
const FOLDER_NAME := "Power of Chaos Remake"
const FOLDER_MIME := "application/vnd.google-apps.folder"
const FILE_FIELDS := "id,md5Checksum,modifiedTime,appProperties"
const PENDING := "Hay cambios en Drive; se aplicarán al volver al selector. / Drive changes will apply back at the game selector."
const Store = preload("res://core/save_store.gd")

## off, linking, idle, syncing, conflict, error
var state := "off"
var detail := ""
var user_code := ""
var verification_url := ""
var last_sync := 0
## {"local": resumen, "remote": resumen} mientras state == "conflict".
var conflict := {}
var upload_delay := 5.0

var _oauth := "https://oauth2.googleapis.com"
var _api := "https://www.googleapis.com"
var _client_id := ""
var _client_secret := ""
var _refresh_token := ""
var _access_token := ""
var _access_expiry := 0.0
var _sync := {}
var _remote := {}
var _remote_body := PackedByteArray()
var _busy := false
var _queued := false
var _queued_download := false
var _notice := ""
var _link_serial := 0
var _upload_timer := Timer.new()


func _ready() -> void:
	_client_id = str(ProjectSettings.get_setting("cloud_sync/client_id", ""))
	_client_secret = str(ProjectSettings.get_setting("cloud_sync/client_secret", ""))
	# Cliente propio sin recompilar: PoC Data/cloud.cfg con [client] id y secret.
	var config := ConfigFile.new()
	if config.load(Paths.storage_dir.path_join("cloud.cfg")) == OK:
		_client_id = str(config.get_value("client", "id", _client_id))
		_client_secret = str(config.get_value("client", "secret", _client_secret))
	_upload_timer.one_shot = true
	_upload_timer.timeout.connect(sync_now.bind(false))
	add_child(_upload_timer)
	SaveData.saved.connect(_on_saved)
	reload()


## Relee token y estado del ultimo acuerdo (tambien tras cambiar Paths en pruebas).
func reload() -> void:
	_sync = {}
	var config := ConfigFile.new()
	if config.load(_state_path()) == OK:
		for key in ["folder_id", "file_id", "local_md5", "remote_md5"]:
			_sync[key] = str(config.get_value("sync", key, ""))
		last_sync = int(config.get_value("sync", "last_sync", 0))
	_refresh_token = ""
	_access_token = ""
	var file := FileAccess.open_encrypted_with_pass(_token_path(), FileAccess.READ, _token_key())
	if file != null:
		_refresh_token = file.get_as_text().strip_edges()
	_set_state("idle" if linked() else "off")


## El secreto no esta en las fuentes publicas: GitHub Actions lo anade al compilar
## (GOOGLE_OAUTH_CLIENT_SECRET). En local se usa PoC Data/cloud.cfg.
func available() -> bool:
	return _client_id != "" and _client_secret != "" and not Paths.storage_error


func linked() -> bool:
	return _refresh_token != ""


func _notification(what: int) -> void:
	# Android puede cerrar la app en segundo plano: no esperar al temporizador.
	if what == NOTIFICATION_APPLICATION_PAUSED and not _upload_timer.is_stopped():
		_upload_timer.stop()
		sync_now(false)


func _on_saved() -> void:
	if linked() and state != "linking":
		_upload_timer.start(upload_delay)


# --- vinculacion ---------------------------------------------------------------------------

func link() -> void:
	if not available() or state == "linking":
		return
	_link_serial += 1
	var serial := _link_serial
	user_code = ""
	verification_url = ""
	_set_state("linking")
	var response := await _post_form(_oauth + "/device/code", {"client_id": _client_id, "scope": SCOPE})
	if serial != _link_serial:
		return
	var data := _json(response)
	if response.code != 200 or not data.has("device_code"):
		_set_state("off", _error_text(response, data))
		return
	user_code = str(data.get("user_code", ""))
	verification_url = str(data.get("verification_url", data.get("verification_uri", "https://www.google.com/device")))
	changed.emit()
	var interval := float(data.get("interval", 5))
	var deadline := Time.get_unix_time_from_system() + float(data.get("expires_in", 1800))
	while Time.get_unix_time_from_system() < deadline:
		await get_tree().create_timer(interval).timeout
		if serial != _link_serial:
			return
		response = await _post_form(_oauth + "/token", {"client_id": _client_id, "client_secret": _client_secret,
				"device_code": data.device_code, "grant_type": DEVICE_GRANT})
		if serial != _link_serial:
			return
		var token := _json(response)
		match str(token.get("error", "")):
			"authorization_pending":
				continue
			"slow_down":
				interval += 5.0
				continue
			"":
				if response.code == 200 and token.has("refresh_token"):
					_accept_token(token)
					if not _store_token(str(token.refresh_token)):
						_set_state("off", "No se pudo guardar la sesión. / Could not store the session.")
						return
					_sync = {}
					user_code = ""
					_set_state("idle")
					sync_now(true)
					return
		_set_state("off", _error_text(response, token))
		return
	if serial == _link_serial:
		_set_state("off", "El código caducó. / The code expired.")


func cancel_link() -> void:
	if state == "linking":
		_link_serial += 1
		user_code = ""
		_set_state("off")


func unlink() -> void:
	_link_serial += 1
	_upload_timer.stop()
	if _refresh_token != "":
		_post_form(_oauth + "/revoke", {"token": _refresh_token}) # sin esperar: basta con olvidarlo aqui
	_forget_session()
	_set_state("off")


func _forget_session() -> void:
	_refresh_token = ""
	_access_token = ""
	_sync = {}
	conflict = {}
	DirAccess.remove_absolute(_token_path())
	DirAccess.remove_absolute(_state_path())


# --- sincronizacion ------------------------------------------------------------------------

## allow_download: solo desde el selector de juegos, donde reemplazar la partida es seguro.
## Tras un guardado en mitad del juego solo se sube; lo remoto espera al selector.
func sync_now(allow_download := true) -> void:
	if not linked() or not available() or state in ["linking", "conflict"]:
		return
	if _busy:
		_queued = true
		_queued_download = _queued_download or allow_download
		return
	_busy = true
	_upload_timer.stop()
	_notice = ""
	_set_state("syncing")
	var error := await _sync_once(allow_download)
	_busy = false
	if not linked():
		return # la sesion se revoco durante la sincronizacion
	if state == "syncing":
		_set_state("error" if error != "" else "idle", error if error != "" else _notice)
	if _queued:
		_queued = false
		var download := _queued_download
		_queued_download = false
		sync_now(download)


func _sync_once(allow_download: bool) -> String:
	if SaveData.data.is_empty() or SaveData.persistence_error != "":
		return "" # sin partida cargada no hay nada que comparar
	if not await _ensure_token():
		return detail
	var lookup := await _find_remote()
	if lookup.has("error"):
		return lookup.error
	_remote = lookup.get("file", {})
	var local_md5 := FileAccess.get_md5(SaveData.path()) if FileAccess.file_exists(SaveData.path()) else ""
	var remote_md5 := str(_remote.get("md5Checksum", ""))
	match decide(local_md5, remote_md5, _sync.get("local_md5", ""), _sync.get("remote_md5", "")):
		"none":
			_record(local_md5, remote_md5)
			return ""
		"upload":
			return await _upload()
		"download":
			if not allow_download:
				_notice = PENDING
				return ""
			var body := await _download()
			if body.has("error"):
				return body.error
			return _apply_remote(body.data, remote_md5)
		"conflict":
			if not allow_download:
				_notice = PENDING
				return ""
			var body := await _download()
			if body.has("error"):
				return body.error
			var parsed: Variant = JSON.parse_string(body.data.get_string_from_utf8())
			if not Store.valid(parsed):
				return _invalid_remote(parsed)
			_remote_body = body.data
			conflict = {
				"local": summary(SaveData.data, device_name(), FileAccess.get_modified_time(SaveData.path())),
				"remote": summary(parsed, str(_remote.get("appProperties", {}).get("device", "?")),
						int(Time.get_unix_time_from_datetime_string(str(_remote.get("modifiedTime", "")).left(19)))),
			}
			_set_state("conflict")
	return ""


## Decision pura a partir de los MD5 actuales y los del ultimo acuerdo. Se guardan ambos
## porque la partida descargada se reescribe con las preferencias locales del launcher y
## su MD5 local ya no coincide con el remoto.
static func decide(local_md5: String, remote_md5: String, last_local: String, last_remote: String) -> String:
	if remote_md5 == "":
		return "upload" if local_md5 != "" else "none"
	if local_md5 == "":
		return "download"
	var local_changed := local_md5 != last_local
	var remote_changed := remote_md5 != last_remote
	if local_changed and remote_changed:
		return "none" if local_md5 == remote_md5 else "conflict"
	if local_changed:
		return "upload"
	return "download" if remote_changed else "none"


## keep: "local" sube esta partida sobre Drive; "remote" aplica la de Drive aqui.
func resolve_conflict(keep: String) -> void:
	if state != "conflict" or _busy:
		return
	_busy = true
	_set_state("syncing")
	var error := ""
	if not await _ensure_token():
		error = detail
	elif keep == "remote":
		error = _apply_remote(_remote_body, str(_remote.get("md5Checksum", "")))
	else:
		error = await _upload()
	conflict = {}
	_remote_body = PackedByteArray()
	_busy = false
	if linked():
		_set_state("error" if error != "" else "idle", error)


## Nombre visible en el aviso de conflicto del otro dispositivo.
static func device_name() -> String:
	if OS.has_feature("mobile"):
		return OS.get_model_name()
	var host := OS.get_environment("COMPUTERNAME")
	return host if host != "" else OS.get_name()


static func summary(save: Dictionary, device: String, time: int) -> Dictionary:
	var cards := 0
	for key in save.get("collection", {}):
		cards += int(save.collection[key])
	var stats: Dictionary = save.get("stats", {}).get("yugi", {})
	return {"device": device, "time": time, "cards": cards, "distinct": save.get("collection", {}).size(),
		"wins": int(stats.get("wins", 0)), "losses": int(stats.get("losses", 0))}


func _apply_remote(body: PackedByteArray, remote_md5: String) -> String:
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not Store.valid(parsed):
		return _invalid_remote(parsed)
	# Volumen, silencio y modo tactil son de cada dispositivo.
	if SaveData.data.has("launcher"):
		parsed["launcher"] = SaveData.data["launcher"]
	else:
		parsed.erase("launcher")
	var err := Store.write_save(SaveData.path(), parsed)
	if err != OK:
		return "No se pudo escribir la partida: %s" % error_string(err)
	SaveData.load_or_create()
	_upload_timer.stop() # la recarga puede guardar (migracion); no es un cambio propio
	_record(FileAccess.get_md5(SaveData.path()), remote_md5)
	save_replaced.emit()
	return ""


func _invalid_remote(parsed: Variant) -> String:
	if parsed is Dictionary and parsed.has("version") and not Store.supported_version(parsed["version"]):
		return "La partida de Drive es de una versión más nueva: actualiza el juego. / The Drive save is newer: update the game."
	return "La partida de Drive no es válida; no se aplicó. / The Drive save is invalid; it was not applied."


func _record(local_md5: String, remote_md5: String) -> void:
	_sync["local_md5"] = local_md5
	_sync["remote_md5"] = remote_md5
	last_sync = int(Time.get_unix_time_from_system())
	_save_state()


# --- Drive ---------------------------------------------------------------------------------

func _find_remote() -> Dictionary:
	if _sync.get("file_id", "") != "":
		var response := await _api_request(HTTPClient.METHOD_GET, "%s/drive/v3/files/%s?fields=%s,trashed" % [_api, _sync.file_id, FILE_FIELDS])
		var meta := _json(response)
		if response.code == 200 and not meta.get("trashed", false):
			return {"file": meta}
		if response.code not in [404, 200]:
			return {"error": _error_text(response, meta)}
		_sync.erase("file_id") # borrado o en la papelera: buscar de nuevo
	var folder := await _query("name = '%s' and mimeType = '%s' and trashed = false" % [FOLDER_NAME, FOLDER_MIME], "id")
	if folder.has("error"):
		return folder
	if folder.files.is_empty():
		_sync.erase("folder_id")
		return {}
	_sync["folder_id"] = str(folder.files[0].id)
	var found := await _query("name = '%s' and '%s' in parents and trashed = false" % [SaveData.FILE_NAME, _sync.folder_id], FILE_FIELDS)
	if found.has("error"):
		return found
	if found.files.is_empty():
		return {}
	_sync["file_id"] = str(found.files[0].id)
	_save_state()
	return {"file": found.files[0]}


func _query(q: String, fields: String) -> Dictionary:
	var url := "%s/drive/v3/files?q=%s&orderBy=modifiedTime%%20desc&fields=%s&spaces=drive" % [_api, q.uri_encode(), ("files(%s)" % fields).uri_encode()]
	var response := await _api_request(HTTPClient.METHOD_GET, url)
	var data := _json(response)
	if response.code != 200 or not data.get("files") is Array:
		return {"error": _error_text(response, data)}
	return {"files": data.files}


func _upload() -> String:
	var content := FileAccess.get_file_as_bytes(SaveData.path())
	if content.is_empty():
		return "No se pudo leer la partida local. / Could not read the local save."
	var properties := {"device": device_name(), "platform": OS.get_name()}
	var response: Dictionary
	if _sync.get("file_id", "") != "":
		response = await _multipart(HTTPClient.METHOD_PATCH, "/" + str(_sync.file_id), {"appProperties": properties}, content)
	else:
		if _sync.get("folder_id", "") == "":
			var created := await _api_request(HTTPClient.METHOD_POST, _api + "/drive/v3/files?fields=id",
					["Content-Type: application/json"], JSON.stringify({"name": FOLDER_NAME, "mimeType": FOLDER_MIME}).to_utf8_buffer())
			var folder := _json(created)
			if created.code != 200 or not folder.has("id"):
				return _error_text(created, folder)
			_sync["folder_id"] = str(folder.id)
		response = await _multipart(HTTPClient.METHOD_POST, "", {"name": SaveData.FILE_NAME, "parents": [_sync.folder_id],
				"mimeType": "application/json", "appProperties": properties}, content)
	var meta := _json(response)
	if response.code != 200 or not meta.has("md5Checksum"):
		return _error_text(response, meta)
	_sync["file_id"] = str(meta.id)
	_remote = meta
	_record(FileAccess.get_md5(SaveData.path()), str(meta.md5Checksum))
	return ""


func _multipart(method: int, suffix: String, metadata: Dictionary, content: PackedByteArray) -> Dictionary:
	var boundary := "poc-%d" % randi()
	return await _api_request(method, "%s/upload/drive/v3/files%s?uploadType=multipart&fields=%s" % [_api, suffix, FILE_FIELDS],
			["Content-Type: multipart/related; boundary=" + boundary], multipart_body(metadata, content, boundary))


static func multipart_body(metadata: Dictionary, content: PackedByteArray, boundary: String) -> PackedByteArray:
	var body := ("--%s\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n%s\r\n--%s\r\nContent-Type: application/json\r\n\r\n"
			% [boundary, JSON.stringify(metadata), boundary]).to_utf8_buffer()
	body.append_array(content)
	body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
	return body


func _download() -> Dictionary:
	var response := await _api_request(HTTPClient.METHOD_GET, "%s/drive/v3/files/%s?alt=media" % [_api, _remote.id])
	if response.code != 200:
		return {"error": _error_text(response, _json(response))}
	return {"data": response.body}


# --- OAuth y HTTP --------------------------------------------------------------------------

func _ensure_token() -> bool:
	if _access_token != "" and Time.get_unix_time_from_system() < _access_expiry - 60.0:
		return true
	var response := await _post_form(_oauth + "/token", {"client_id": _client_id, "client_secret": _client_secret,
			"refresh_token": _refresh_token, "grant_type": "refresh_token"})
	var data := _json(response)
	if response.code == 200 and data.has("access_token"):
		_accept_token(data)
		return true
	if str(data.get("error", "")) == "invalid_grant":
		# Acceso retirado desde la cuenta de Google o sesion caducada: volver a vincular.
		_forget_session()
		_set_state("off", "Sesión de Google caducada; vuelve a conectar. / Google session expired; connect again.")
		return false
	detail = _error_text(response, data)
	return false


func _accept_token(data: Dictionary) -> void:
	_access_token = str(data.access_token)
	_access_expiry = Time.get_unix_time_from_system() + float(data.get("expires_in", 3600))


func _api_request(method: int, url: String, headers: Array = [], body := PackedByteArray()) -> Dictionary:
	for attempt in 2:
		var response := await _request(method, url, headers + ["Authorization: Bearer " + _access_token], body)
		if response.code != 401 or attempt == 1:
			return response
		_access_token = "" # caducado antes de tiempo: renovar una vez
		if not await _ensure_token():
			return response
	return {}


func _post_form(url: String, fields: Dictionary) -> Dictionary:
	var parts := PackedStringArray()
	for key in fields:
		parts.append("%s=%s" % [key, str(fields[key]).uri_encode()])
	return await _request(HTTPClient.METHOD_POST, url, ["Content-Type: application/x-www-form-urlencoded"], "&".join(parts).to_utf8_buffer())


func _request(method: int, url: String, headers: Array, body: PackedByteArray) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 30
	http.body_size_limit = 16 * 1024 * 1024
	add_child(http)
	var result := {"code": 0, "body": PackedByteArray()}
	if http.request_raw(url, PackedStringArray(headers), method, body) == OK:
		var done: Array = await http.request_completed
		if done[0] == HTTPRequest.RESULT_SUCCESS:
			result = {"code": done[1], "body": done[3]}
	http.queue_free()
	return result


func _json(response: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(response.get("body", PackedByteArray()).get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


func _error_text(response: Dictionary, data: Dictionary) -> String:
	if response.get("code", 0) == 0:
		return "Sin conexión con Google. / Cannot reach Google."
	var message: Variant = data.get("error_description", data.get("error", ""))
	if message is Dictionary:
		message = message.get("message", "")
	return "Google %d: %s" % [response.code, message]


# --- estado local --------------------------------------------------------------------------

func _set_state(value: String, message := "") -> void:
	state = value
	detail = message
	changed.emit()


func _state_path() -> String:
	return Paths.storage_dir.path_join("cloud_sync.cfg")


func _token_path() -> String:
	return Paths.storage_dir.path_join("cloud_token.dat")


## Ofuscacion local: el refresh token no queda en claro y no sirve copiado a otro equipo.
func _token_key() -> String:
	return "poc-remake-drive:" + OS.get_unique_id()


func _store_token(token: String) -> bool:
	var file := FileAccess.open_encrypted_with_pass(_token_path(), FileAccess.WRITE, _token_key())
	if file == null:
		return false
	file.store_string(token)
	file.close()
	_refresh_token = token
	return true


func _save_state() -> void:
	var config := ConfigFile.new()
	for key in _sync:
		config.set_value("sync", key, _sync[key])
	config.set_value("sync", "last_sync", last_sync)
	config.save(_state_path())
