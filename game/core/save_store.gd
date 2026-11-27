extends RefCounted
## Guardado portable: conserva la generacion anterior y comprueba cada reemplazo.

static func supported_version(version: Variant) -> bool:
	return (version is int or version is float) and int(version) in [1, 2] and version == int(version)


static func valid(value: Variant) -> bool:
	if not value is Dictionary or not supported_version(value.get("version")):
		return false
	for key in ["collection", "decks", "stats"]:
		if not value.get(key) is Dictionary:
			return false
	for decks in [value["decks"], value.get("deck_drafts", {})]:
		if not decks is Dictionary:
			return false
		for deck in decks.values():
			if not deck is Dictionary:
				return false
			for zone in ["main", "fusion", "side"]:
				if not deck.get(zone) is Array:
					return false
	for row in value["stats"].values():
		if not row is Dictionary:
			return false
	return not value.has("seen") or value["seen"] is Dictionary


static func read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parser := JSON.new()
	return parser.data if parser.parse(FileAccess.get_file_as_string(path)) == OK else null


static func load_save(path: String) -> Dictionary:
	var current: Variant = read(path)
	if valid(current):
		return {"data": current, "error": "", "recovered": false}
	# Una version posterior puede contener progreso que una version antigua no entiende.
	for candidate in [path, path + ".bak"]:
		var value: Variant = read(candidate)
		if value is Dictionary and value.has("version") and not supported_version(value["version"]):
			return {"data": null, "error": "Version de partida no compatible: %s" % candidate}
		if FileAccess.file_exists(candidate) and not valid(value):
			var err := preserve(candidate)
			if err != OK:
				return {"data": null, "error": "No se pudo conservar %s: %s" % [candidate, error_string(err)]}
	var backup: Variant = read(path + ".bak")
	return {"data": backup if valid(backup) else null, "error": "", "recovered": valid(backup)}


## La copia danada permanece disponible para recuperacion manual, sin sobrescribir otra.
static func preserve(path: String) -> Error:
	var digest := FileAccess.get_sha256(path)
	if digest == "":
		return ERR_CANT_OPEN
	var target := path + ".damaged"
	var suffix := 0
	while FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(target):
		if FileAccess.file_exists(target) and digest == FileAccess.get_sha256(target):
			return OK
		suffix += 1
		target = path + ".damaged.%d" % suffix
	var err := DirAccess.copy_absolute(path, target)
	if err != OK:
		return err
	return OK if digest == FileAccess.get_sha256(target) else ERR_FILE_CORRUPT


static func write_save(path: String, value: Dictionary) -> Error:
	if not valid(value):
		return ERR_INVALID_DATA
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		return err
	# Tambien proteger danos aparecidos mientras el programa estaba abierto.
	for candidate in [path, path + ".bak"]:
		if FileAccess.file_exists(candidate) and not valid(read(candidate)):
			var value_on_disk: Variant = read(candidate)
			if value_on_disk is Dictionary and value_on_disk.has("version") and not supported_version(value_on_disk["version"]):
				return ERR_INVALID_DATA
			err = preserve(candidate)
			if err != OK:
				return err
	var temporary := path + ".tmp"
	var serialized := JSON.stringify(value, "\t")
	err = write_text(temporary, serialized)
	if err != OK:
		return err
	# Verificar lo realmente escrito antes de tocar la partida y su respaldo.
	if FileAccess.get_file_as_string(temporary) != serialized or not valid(read(temporary)):
		return ERR_FILE_CORRUPT
	if valid(read(path)):
		var backup_tmp := path + ".bak.tmp"
		var digest := FileAccess.get_sha256(path)
		if digest == "":
			return ERR_CANT_OPEN
		err = DirAccess.copy_absolute(path, backup_tmp)
		if err == OK and digest != FileAccess.get_sha256(backup_tmp):
			err = ERR_FILE_CORRUPT
		if err == OK:
			err = DirAccess.rename_absolute(backup_tmp, path + ".bak")
		if err != OK:
			return err
	# El original nunca se borra antes del reemplazo; ante error sigue en su sitio.
	return DirAccess.rename_absolute(temporary, path)


static func write_text(path: String, content: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(content)
	file.flush()
	var err := file.get_error()
	file.close()
	return err
