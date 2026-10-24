extends Node
## En PC todos los archivos de la aplicación viven en <exe>/PoC Data/.
## Desde el editor, la "carpeta del juego" es la raiz del repositorio (la que contiene game/).
## En Android no se puede escribir junto al APK, asi que se usa el almacenamiento de la app.

var data_dir: String
var save_dir: String
var storage_dir: String
var storage_error := false
var migration_source := ""
var content_pack_persistent := false
var _inventory_root := ""
var _installed := {}


func _init() -> void:
	storage_dir = cmdline_value("storage")
	if storage_dir == "":
		storage_dir = "user://" if OS.has_feature("android") else _base_dir().path_join("PoC Data")
	storage_dir = ProjectSettings.globalize_path(storage_dir)
	storage_error = not _is_writable(storage_dir)
	if not storage_error and not OS.has_feature("android"):
		DirAccess.make_dir_recursive_absolute(storage_dir.path_join("temp"))
		OS.set_environment("TEMP", storage_dir.path_join("temp"))
		OS.set_environment("TMP", storage_dir.path_join("temp"))
		_migrate_preferences_and_saves()
	data_dir = _resolve_data_dir()
	save_dir = _resolve_save_dir()


func has_data() -> bool:
	return FileAccess.file_exists(data_dir.path_join("inventory.json"))


func has_game(game: String) -> bool:
	if not has_data():
		return false
	if _inventory_root != data_dir:
		var inventory: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_dir.path_join("inventory.json")))
		_installed = inventory.get("games", {}) if inventory is Dictionary else {}
		_inventory_root = data_dir
	return _installed.has(game)


func _resolve_data_dir() -> String:
	var override := cmdline_value("data")
	if override != "":
		return override
	# A full private APK mounts its embedded assets and first preserves the pack
	# in app storage. Later engine-only APKs mount that same persistent copy.
	if FileAccess.file_exists("res://bundled_data.pck") and ProjectSettings.load_resource_pack("res://bundled_data.pck", false):
		content_pack_persistent = preserve_embedded_content_pack() if OS.has_feature("android") else false
		if OS.has_feature("android") and not content_pack_persistent:
			push_warning("The game can run from this APK, but its data could not be preserved for an engine-only update.")
		return "res://data"
	if OS.has_feature("android"):
		if mount_user_content_pack():
			return "res://data"
		return "user://data"
	if cmdline_value("mobile-controls") == "true" and mount_user_content_pack():
		return "res://data"
	var portable := resources_path()
	if FileAccess.file_exists(portable.path_join("inventory.json")):
		return portable
	if _allow_legacy():
		var config := ConfigFile.new()
		if config.load(_legacy_root().path_join("content.cfg")) == OK:
			var imported := str(config.get_value("content", "data", ""))
			if FileAccess.file_exists(imported.path_join("inventory.json")):
				migration_source = imported
				return imported
		var previous := _base_dir().path_join("data")
		if FileAccess.file_exists(previous.path_join("inventory.json")):
			migration_source = previous
			return previous
	# Los fixtures/desarrollo no se trasladan automáticamente al abrir el editor.
	if OS.has_feature("editor") and FileAccess.file_exists(_base_dir().path_join("data/inventory.json")):
		return _base_dir().path_join("data")
	return portable


func _resolve_save_dir() -> String:
	var override := cmdline_value("save")
	if override != "":
		return override
	return storage_dir.path_join("saves")


func settings_path() -> String:
	return storage_dir.path_join("content.cfg")


func resources_path() -> String:
	return storage_dir.path_join("resources")


func _legacy_root() -> String:
	var override := cmdline_value("legacy-root")
	return override if override != "" else ProjectSettings.globalize_path("user://")


func _allow_legacy() -> bool:
	return not OS.has_feature("android") and cmdline_value("data") == "" and cmdline_value("save") == "" and (not OS.has_feature("editor") or cmdline_value("legacy-root") != "")


func _migrate_preferences_and_saves() -> void:
	if FileAccess.file_exists(storage_dir.path_join("saves/.reset-complete")):
		return
	if OS.has_feature("editor") and cmdline_value("storage") == "" and cmdline_value("data") == "" and cmdline_value("save") == "":
		if not _copy_missing(_base_dir().path_join("saves"), storage_dir.path_join("saves")):
			storage_error = true
	if not _allow_legacy():
		return
	if not FileAccess.file_exists(settings_path()):
		var config := ConfigFile.new()
		if config.load(_legacy_root().path_join("content.cfg")) == OK:
			config.set_value("content", "data", "resources")
			if config.save(settings_path()) != OK:
				storage_error = true
	var previous_saves := [_legacy_root().path_join("saves")]
	if not OS.has_feature("editor"):
		previous_saves.push_front(_base_dir().path_join("saves"))
	for previous: String in previous_saves:
		if not _copy_missing(previous, storage_dir.path_join("saves")):
			storage_error = true


func _copy_missing(source: String, target: String) -> bool:
	if not DirAccess.dir_exists_absolute(source):
		return true
	if DirAccess.make_dir_recursive_absolute(target) != OK:
		return false
	var dir := DirAccess.open(source)
	for folder in dir.get_directories():
		if not _copy_missing(source.path_join(folder), target.path_join(folder)):
			return false
	for file in dir.get_files():
		var original := source.path_join(file)
		var destination := target.path_join(file)
		if FileAccess.file_exists(destination):
			continue
		var temporary := destination + ".migration-tmp"
		if DirAccess.copy_absolute(original, temporary) != OK or FileAccess.get_sha256(original) != FileAccess.get_sha256(temporary):
			return false
		if DirAccess.rename_absolute(temporary, destination) != OK:
			return false
	return true


func _base_dir() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	return OS.get_executable_path().get_base_dir()


func _is_writable(dir: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	var probe := dir.path_join(".probe")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true


## Lee "--nombre=valor" de los argumentos de usuario (los que van despues de "--").
static func cmdline_value(name: String) -> String:
	var prefix := "--%s=" % name
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""


## Interfaz de la versión Android (launcher, importador, actualizador). En PC las pruebas y la
## compilación del APK la simulan con --platform=android; el almacenamiento real del
## dispositivo sigue dependiendo solo de OS.has_feature("android").
static func android_platform() -> bool:
	return OS.has_feature("android") or cmdline_value("platform") == "android"


func user_content_pack_path() -> String:
	return storage_dir.path_join("content/bundled_data.pck")


func mount_user_content_pack() -> bool:
	var source := user_content_pack_path()
	if not FileAccess.file_exists(source):
		return false
	var validator: Script = load("res://core/android_content_pack.gd")
	if validator == null:
		return false
	var result: Dictionary = validator.validate_pack(source)
	if not result.get("ok", false) or not ProjectSettings.load_resource_pack(source, false):
		return false
	data_dir = "res://data"
	_inventory_root = ""
	_installed.clear()
	content_pack_persistent = FileAccess.file_exists("res://data/inventory.json")
	return content_pack_persistent


func preserve_embedded_content_pack(source := "res://bundled_data.pck") -> bool:
	var target := user_content_pack_path()
	var meta_path := target.get_base_dir().path_join("embedded-content.cfg")
	var digest := ""
	if source == "res://bundled_data.pck" and FileAccess.file_exists("res://bundled_data.sha256"):
		digest = FileAccess.get_file_as_string("res://bundled_data.sha256").strip_edges().split(" ")[0].to_lower()
	if digest.length() != 64 or not digest.is_valid_hex_number(false):
		digest = FileAccess.get_sha256(source)
	var input := FileAccess.open(source, FileAccess.READ)
	if input == null or digest.is_empty():
		return false
	var size := input.get_length()
	var meta := ConfigFile.new()
	if meta.load(meta_path) == OK and FileAccess.file_exists(target):
		var existing := FileAccess.open(target, FileAccess.READ)
		if existing != null and existing.get_length() == size and str(meta.get_value("content", "sha256", "")) == digest:
			return true
	if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK:
		push_warning("Game data runs from the APK, but its persistent copy could not be prepared. Updates require writable storage.")
		return false
	var temporary := target + ".tmp"
	var output := FileAccess.open(temporary, FileAccess.WRITE)
	if output == null:
		return false
	while input.get_position() < size:
		var chunk := input.get_buffer(mini(1024 * 1024, size - input.get_position()))
		if chunk.is_empty():
			output.close()
			DirAccess.remove_absolute(temporary)
			return false
		output.store_buffer(chunk)
	var result := output.get_error()
	output.close()
	input.close()
	if result != OK or FileAccess.get_sha256(temporary) != digest:
		DirAccess.remove_absolute(temporary)
		return false
	if DirAccess.rename_absolute(temporary, target) != OK:
		DirAccess.remove_absolute(temporary)
		return false
	meta.set_value("content", "sha256", digest)
	meta.set_value("content", "bytes", size)
	if meta.save(meta_path + ".tmp") != OK or DirAccess.rename_absolute(meta_path + ".tmp", meta_path) != OK:
		return false
	return true
