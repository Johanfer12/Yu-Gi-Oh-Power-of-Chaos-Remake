extends Node
## Sólo actualiza el ejecutable Windows; la biblioteca y los guardados son externos.
signal changed

const REPOSITORY := "https://github.com/Johanfer12/Yu-Gi-Oh-Power-of-Chaos-Remake"
const API := "https://api.github.com/repos/Johanfer12/Yu-Gi-Oh-Power-of-Chaos-Remake/releases?per_page=100"
const HEADERS := ["Accept: application/vnd.github+json", "User-Agent: PowerOfChaos-Updater"]
const HELPER = preload("res://core/update_helper.gd")
var current := "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
var available := ""
var state := "idle"
var detail := ""
var _http := HTTPRequest.new()
var _asset_url := ""
var _checksum_url := ""
var _expected := ""
var _directory := ""
var _phase := ""
var _checked := false


func _ready() -> void:
	if FileAccess.file_exists("res://build_info.json"):
		var info: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://build_info.json"))
		if info is Dictionary:
			current = str(info.get("version", current))
	_http.timeout = 30
	_http.body_size_limit = 4 * 1024 * 1024
	_http.use_threads = true
	add_child(_http)
	_http.request_completed.connect(_completed)


func supported() -> bool:
	return OS.get_name() == "Windows" and not OS.has_feature("editor")


func check_once() -> void:
	if _checked or not supported() or DisplayServer.get_name() == "headless":
		return
	_checked = true
	check()


func check() -> void:
	if state in ["checking", "downloading", "installing"]:
		return
	available = ""
	_state("checking")
	_request(API, "releases")


func _state(value: String, message := "") -> void:
	state = value
	detail = message
	changed.emit()


func _request(url: String, phase: String) -> void:
	_phase = phase
	if _http.request(url, HEADERS) != OK:
		_fail("No se pudo iniciar la conexión. / Could not connect.")


static func version_parts(tag: String) -> Array:
	var regex := RegEx.new()
	regex.compile("^v?(\\d+)\\.(\\d+)\\.(\\d+)(?:-(alpha|beta|rc)\\.(\\d+))?$")
	var found := regex.search(tag)
	if found == null:
		return []
	return [found.get_string(1).to_int(), found.get_string(2).to_int(), found.get_string(3).to_int(),
		["alpha", "beta", "rc", ""].find(found.get_string(4)), found.get_string(5).to_int()]


static func newer(candidate: String, installed: String) -> bool:
	var a := version_parts(candidate)
	var b := version_parts(installed)
	if a.is_empty() or b.is_empty():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return a[i] > b[i]
	return false


static func trusted_asset(url: String) -> bool:
	return url.begins_with(REPOSITORY + "/releases/download/") and not "?" in url and not "#" in url


func select_release(releases: Array) -> void:
	available = ""
	_asset_url = ""
	_checksum_url = ""
	for release: Variant in releases:
		if not release is Dictionary or release.get("draft", false):
			continue
		var tag := str(release.get("tag_name", ""))
		if not newer(tag, current) or (available != "" and not newer(tag, available)):
			continue
		# Alpha installations follow previews; stable installations stay on stable releases.
		if release.get("prerelease", false) and not "-" in current:
			continue
		var exe := ""
		var checksum := ""
		var assets: Variant = release.get("assets", [])
		if not assets is Array:
			continue
		for asset: Variant in assets:
			if not asset is Dictionary or asset.get("state", "uploaded") != "uploaded":
				continue
			var url := str(asset.get("browser_download_url", ""))
			if not trusted_asset(url) or not url.begins_with(REPOSITORY + "/releases/download/" + tag + "/"):
				continue
			if asset.get("name") == "PowerOfChaos.exe":
				exe = url
			elif asset.get("name") == "PowerOfChaos.exe.sha256":
				checksum = url
		if exe != "" and checksum != "":
			available = tag
			_asset_url = exe
			_checksum_url = checksum
	_state("available" if available != "" else "current")


func download() -> void:
	if not supported() or state != "available" or Paths.storage_error:
		return
	_directory = Paths.storage_dir.path_join("updates")
	if DirAccess.make_dir_recursive_absolute(_directory) != OK:
		_fail("No se puede escribir la actualización. / Cannot write update.")
		return
	_state("downloading")
	_request(_checksum_url, "checksum")


static func checksum_from(text: String) -> String:
	var fields := text.strip_edges().replace("\t", " ").split(" ", false)
	if fields.size() != 2 or fields[1].trim_prefix("*") != "PowerOfChaos.exe":
		return ""
	var hash_value := fields[0].to_lower()
	return hash_value if hash_value.length() == 64 and hash_value.is_valid_hex_number() else ""


func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("Conexión fallida (HTTP %d). Reintenta. / Connection failed; retry." % code)
		return
	match _phase:
		"releases":
			var releases: Variant = JSON.parse_string(body.get_string_from_utf8())
			if not releases is Array:
				_fail("Respuesta de GitHub inválida. / Invalid GitHub response.")
				return
			select_release(releases)
		"checksum":
			_expected = checksum_from(body.get_string_from_utf8())
			if _expected == "":
				_fail("Firma SHA-256 inválida. / Invalid SHA-256 checksum.")
				return
			_http.download_file = _directory.path_join("PowerOfChaos.download")
			_http.body_size_limit = 512 * 1024 * 1024
			_http.timeout = 600
			_request(_asset_url, "executable")
		"executable":
			var downloaded := _http.download_file
			_http.download_file = ""
			if FileAccess.get_sha256(downloaded) != _expected:
				_fail("La descarga no supera SHA-256. / Download checksum mismatch.")
				return
			_install(downloaded)


func cancel() -> void:
	if state != "downloading":
		return
	_http.cancel_request()
	_cleanup_download()
	_state("available")


func _cleanup_download() -> void:
	_http.download_file = ""
	_http.body_size_limit = 4 * 1024 * 1024
	_http.timeout = 30
	if _directory != "":
		for name in ["PowerOfChaos.download", "apply-update.ps1", "update.json"]:
			DirAccess.remove_absolute(_directory.path_join(name))


func _fail(message: String) -> void:
	_cleanup_download()
	_state("error", message)


func _install(downloaded: String) -> void:
	var script := _directory.path_join("apply-update.ps1")
	var settings := _directory.path_join("update.json")
	var output := FileAccess.open(script, FileAccess.WRITE)
	if output == null:
		_fail("No se pudo preparar el actualizador. / Could not prepare updater.")
		return
	output.store_string(HELPER.SCRIPT)
	output.close()
	output = FileAccess.open(settings, FileAccess.WRITE)
	if output == null:
		_fail("No se pudo guardar la actualización. / Could not save update settings.")
		return
	output.store_string(JSON.stringify({"pid": OS.get_process_id(), "target": OS.get_executable_path(),
		"source": downloaded, "sha256": _expected}))
	output.close()
	var shell := OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
	var pid := OS.create_process(shell, ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", script], false)
	if pid == -1:
		_fail("No se pudo iniciar el actualizador. / Could not start updater.")
		return
	_state("installing")
	get_tree().quit()
