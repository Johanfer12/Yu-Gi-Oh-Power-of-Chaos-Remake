extends Node
## Android updates keep user content separate. The launcher downloads the published APK into
## app storage, verifies it against ANDROID_RELEASE.json and opens the system installer, which
## always asks the user to confirm. A failed download or install falls back to the browser.
signal changed
const REPOSITORY := "https://github.com/Johanfer12/Yu-Gi-Oh-Power-of-Chaos-Remake"
const API := "https://api.github.com/repos/Johanfer12/Yu-Gi-Oh-Power-of-Chaos-Remake/releases?per_page=100"
const HEADERS := ["Accept: application/vnd.github+json", "User-Agent: PowerOfChaos-AndroidUpdater"]
const APK := "PowerOfChaos-Android.apk"
var current := "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
var version_code := 0
var certificate := ""
var available := ""
var state := "idle"
var detail := ""
var _http := HTTPRequest.new()
var _asset_url := ""
var _metadata_url := ""
var _phase := ""
var _checked := false
var _expected := ""
var _directory := ""
var _ready_apk := ""
## Inyectables para las pruebas de escritorio: abrir el instalador y pedir el permiso.
var open_file := func(path: String) -> int: return OS.shell_open(path)
var open_url := func(url: String) -> int: return OS.shell_open(url)
var request_install_permission := func() -> bool: return OS.request_permission(INSTALL_PERMISSION)
const INSTALL_PERMISSION := "android.permission.REQUEST_INSTALL_PACKAGES"
const DOWNLOAD_LIMIT := 256 * 1024 * 1024

func _ready() -> void:
	if FileAccess.file_exists("res://build_info.json"):
		var info: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://build_info.json"))
		if info is Dictionary:
			current = str(info.get("version", current))
			version_code = int(info.get("android_version_code", 0))
			certificate = str(info.get("android_signing_sha256", "")).to_lower()
	_http.timeout = 30
	_http.body_size_limit = 4 * 1024 * 1024
	_http.use_threads = true
	add_child(_http)
	_http.request_completed.connect(_completed)
	if supported():
		_directory = get_tree().root.get_node("Paths").storage_dir.path_join("updates")
		_remove_downloads()
		# El permiso de instalar se concede en los ajustes de Android; al volver se continúa.
		get_tree().on_request_permissions_result.connect(_on_permission)

func supported() -> bool:
	return preload("res://autoload/paths.gd").android_platform()

func check_once() -> void:
	if _checked or not supported() or DisplayServer.get_name() == "headless": return
	_checked = true
	check()

func check() -> void:
	if state in ["checking", "validating"]: return
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
		_fail("No se pudo conectar con GitHub. / Could not connect to GitHub.")

static func version_parts(tag: String) -> Array:
	var regex := RegEx.new()
	regex.compile("^v?(\\d+)\\.(\\d+)\\.(\\d+)(?:-(alpha|beta|rc)\\.(\\d+))?$")
	var found := regex.search(tag)
	if found == null: return []
	return [found.get_string(1).to_int(), found.get_string(2).to_int(), found.get_string(3).to_int(), ["alpha", "beta", "rc", ""].find(found.get_string(4)), found.get_string(5).to_int()]

static func newer(candidate: String, installed: String) -> bool:
	var a := version_parts(candidate)
	var b := version_parts(installed)
	if a.is_empty() or b.is_empty(): return false
	for i in a.size():
		if a[i] != b[i]: return a[i] > b[i]
	return false

static func trusted_asset(url: String) -> bool:
	return url.begins_with(REPOSITORY + "/releases/download/") and not "?" in url and not "#" in url

func select_release(releases: Array, request_metadata := true) -> void:
	available = ""
	_asset_url = ""
	_metadata_url = ""
	for release: Variant in releases:
		if not release is Dictionary or release.get("draft", false): continue
		var tag := str(release.get("tag_name", ""))
		if not newer(tag, current) or (available != "" and not newer(tag, available)): continue
		if release.get("prerelease", false) and not "-" in current: continue
		var apk := ""
		var metadata := ""
		var assets: Variant = release.get("assets", [])
		if not assets is Array: continue
		for asset: Variant in assets:
			if not asset is Dictionary or asset.get("state", "uploaded") != "uploaded": continue
			var url := str(asset.get("browser_download_url", ""))
			if not trusted_asset(url) or not url.begins_with(REPOSITORY + "/releases/download/" + tag + "/"): continue
			if asset.get("name") == APK: apk = url
			elif asset.get("name") == "ANDROID_RELEASE.json": metadata = url
		if apk != "" and metadata != "":
			available = tag
			_asset_url = apk
			_metadata_url = metadata
	if available.is_empty():
		_state("current")
	else:
		_state("validating")
		if request_metadata: _request(_metadata_url, "metadata")

func validate_metadata(info: Variant) -> bool:
	if not info is Dictionary or info.get("package") != "org.porttesting.powerofchaos" or info.get("version") != available or info.get("apk") != APK or info.get("original_game_data_included", true):
		_fail("Información Android inválida. / Invalid Android release metadata.")
		return false
	var sha := str(info.get("sha256", "")).to_lower()
	if sha.length() != 64 or not sha.is_valid_hex_number():
		_fail("SHA-256 Android inválido. / Invalid Android SHA-256.")
		return false
	if int(info.get("version_code", 0)) <= version_code:
		available = ""
		_state("current")
		return false
	if certificate.is_empty() or str(info.get("signing_certificate_sha256", "")).to_lower() != certificate:
		_state("manual", "Este APK usa otra firma. Genera la actualización con tu firma original desde PC. / This APK uses a different signing key. Build an update with your original key on PC.")
		return false
	_expected = sha
	_state("available")
	return true

func download() -> void:
	if not supported(): return
	# APK ya verificado (permiso pendiente o instalador cerrado): reabrir sin descargar.
	if state in ["ready", "opened"] and not _ready_apk.is_empty():
		_install()
		return
	if state != "available": return
	# Never replace a content-bearing APK before a persistent copy is ready.
	var paths: Node = get_tree().root.get_node("Paths")
	if not paths.content_pack_persistent and not FileAccess.file_exists(paths.storage_dir.path_join("data/inventory.json")):
		_fail("Primero importa o conserva tus recursos en la aplicación. / Import or preserve your game content first.")
		return
	_directory = paths.storage_dir.path_join("updates")
	if _expected.is_empty() or DirAccess.make_dir_recursive_absolute(_directory) != OK:
		_fallback("No se puede guardar la descarga. / Cannot store the download.")
		return
	_remove_downloads()
	_http.download_file = _directory.path_join(APK.get_basename() + ".download")
	_http.body_size_limit = DOWNLOAD_LIMIT
	_http.timeout = 600
	_state("downloading")
	_request(_asset_url, "apk")

## Fracción descargada (0..1) o -1 si el servidor no informa el tamaño.
func progress() -> float:
	var total := _http.get_body_size()
	return float(_http.get_downloaded_bytes()) / total if state == "downloading" and total > 0 else -1.0

func _downloaded(path: String) -> void:
	_reset_http()
	if FileAccess.get_sha256(path) != _expected:
		DirAccess.remove_absolute(path)
		_fallback("La descarga no supera SHA-256. / Download checksum mismatch.")
		return
	# El instalador de Android reconoce el paquete por su extensión .apk.
	_ready_apk = _directory.path_join(APK)
	if DirAccess.rename_absolute(path, _ready_apk) != OK:
		_fallback("No se pudo preparar el APK. / Could not prepare the APK.")
		return
	_state("ready", "APK verificado. / APK verified.")
	_install()

func _install() -> void:
	if _ready_apk.is_empty() or FileAccess.get_sha256(_ready_apk) != _expected:
		_fallback("El APK descargado ya no es válido. / The downloaded APK is no longer valid.")
		return
	if not request_install_permission.call():
		_state("ready", "Permite instalar apps desde Power of Chaos y vuelve; después pulsa Actualizar. / Allow installing apps from Power of Chaos, return and press Update.")
		return
	if open_file.call(_ready_apk) != OK:
		_fallback("No se pudo abrir el instalador. / Could not open the installer.")
		return
	_state("opened", "Confirma la actualización en el instalador de Android. No desinstales la aplicación. / Confirm the update in the Android installer. Do not uninstall the application.")

func _on_permission(permission: String, granted: bool) -> void:
	if permission == INSTALL_PERMISSION and granted and state == "ready":
		_install()

## Respaldo: la página de descarga en el navegador, como antes de la descarga integrada.
func _fallback(reason: String) -> void:
	_reset_http()
	if _asset_url.is_empty() or open_url.call(_asset_url) != OK:
		_fail(reason)
		return
	_state("opened", reason + " Descarga el APK en el navegador y confirma la actualización. / Download the APK in the browser and confirm the update.")

func _reset_http() -> void:
	_http.download_file = ""
	_http.body_size_limit = 4 * 1024 * 1024
	_http.timeout = 30

func _remove_downloads() -> void:
	if _directory.is_empty(): return
	for name in [APK, APK.get_basename() + ".download"]:
		if FileAccess.file_exists(_directory.path_join(name)):
			DirAccess.remove_absolute(_directory.path_join(name))
	_ready_apk = ""

func _completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _phase == "apk":
		var path := _http.download_file
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			DirAccess.remove_absolute(path)
			_fallback("Descarga fallida (HTTP %d). / Download failed." % code)
			return
		_downloaded(path)
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("Conexión fallida (HTTP %d). / Connection failed." % code)
		return
	var value: Variant = JSON.parse_string(body.get_string_from_utf8())
	if _phase == "releases":
		if value is Array: select_release(value)
		else: _fail("Respuesta de GitHub inválida. / Invalid GitHub response.")
	elif _phase == "metadata": validate_metadata(value)

func cancel() -> void:
	if state in ["checking", "validating"]:
		_http.cancel_request()
		_state("idle")
	elif state == "downloading":
		_http.cancel_request()
		var partial := _http.download_file
		_reset_http()
		if partial != "": DirAccess.remove_absolute(partial)
		_state("available")

func _fail(message: String) -> void:
	_state("error", message)
