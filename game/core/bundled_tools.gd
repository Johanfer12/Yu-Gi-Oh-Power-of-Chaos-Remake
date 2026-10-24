class_name BundledTools
extends RefCounted
## Materializa herramientas propias/de terceros incluidas en el EXE. Nunca datos del juego.
const MANIFEST := "res://bundled/manifest.json"
static var directory := ""

static func prepare(licenses_only := false) -> String:
	if not FileAccess.file_exists(MANIFEST):
		return ""
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not manifest is Dictionary:
		push_error("Manifiesto de herramientas no válido")
		return ""
	var base := OS.get_environment("POC_TOOL_CACHE")
	if base == "":
		base = Paths.storage_dir.path_join("tools")
	directory = base.path_join(FileAccess.get_sha256(MANIFEST).left(16))
	for relative: String in manifest:
		if licenses_only and not relative.begins_with("licenses/"):
			continue
		if relative.is_absolute_path() or ":" in relative or ".." in relative.split("/"):
			push_error("Ruta de herramientas no válida")
			return ""
		var target := directory.path_join(relative)
		var expected := str(manifest[relative])
		if FileAccess.file_exists(target) and FileAccess.get_sha256(target) == expected:
			continue
		if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK:
			push_error("No se puede preparar el directorio de herramientas")
			return ""
		var source := FileAccess.open("res://bundled/" + relative, FileAccess.READ)
		var output := FileAccess.open(target + ".tmp", FileAccess.WRITE)
		if source == null or output == null:
			push_error("No se puede preparar la herramienta " + relative)
			return ""
		while source.get_position() < source.get_length():
			output.store_buffer(source.get_buffer(1024 * 1024))
		source.close()
		output.close()
		if FileAccess.get_sha256(target + ".tmp") != expected:
			push_error("La herramienta no supera la verificación: " + relative)
			return ""
		if DirAccess.rename_absolute(target + ".tmp", target) != OK:
			push_error("No se puede activar la herramienta " + relative)
			return ""
	var receipt := FileAccess.open(directory.path_join("cache-manifest.json"), FileAccess.WRITE)
	if receipt != null:
		receipt.store_string(JSON.stringify(manifest))
		receipt.close()
		_retire_previous(base)
	if licenses_only:
		return directory.path_join("licenses")
	OS.set_environment("POC_7ZIP", directory.path_join("tools/7z.exe"))
	print("bundled_tools: ready")
	return directory.path_join("pocx-import.exe")


static func _retire_previous(base: String) -> void:
	var root := DirAccess.open(base)
	for name in root.get_directories():
		var previous := base.path_join(name)
		if previous == directory or name.length() != 16 or not name.is_valid_hex_number() or root.is_link(name):
			continue
		var marker := previous.path_join("cache-manifest.json")
		if not FileAccess.file_exists(marker):
			continue
		var files: Variant = JSON.parse_string(FileAccess.get_file_as_string(marker))
		if not files is Dictionary:
			continue
		var pending := false
		for relative: String in files:
			if not relative.is_absolute_path() and not ":" in relative and not ".." in relative.split("/"):
				DirAccess.remove_absolute(previous.path_join(relative))
				pending = pending or FileAccess.file_exists(previous.path_join(relative))
		if pending:
			continue
		DirAccess.remove_absolute(marker)
		_prune_empty(previous)


static func _prune_empty(path: String) -> void:
	var folder := DirAccess.open(path)
	for child in folder.get_directories():
		if not folder.is_link(child):
			_prune_empty(path.path_join(child))
	# Only empty directories are removed; unrelated files are preserved.
	DirAccess.remove_absolute(path)
