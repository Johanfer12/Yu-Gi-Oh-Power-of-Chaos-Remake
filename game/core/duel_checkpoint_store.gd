extends RefCounted
## Estado temporal del duelo, separado de la colección y los mazos.

const VERSION := 1
const MAX_BYTES := 16 * 1024 * 1024


static func _path(directory: String) -> String:
	return directory.path_join("duel-in-progress.bin")


static func exists(directory: String) -> bool:
	return FileAccess.file_exists(_path(directory))


static func read(directory: String) -> Dictionary:
	var path := _path(directory)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 41 or file.get_length() > MAX_BYTES:
		return {}
	if file.get_32() != VERSION:
		return {}
	var size := file.get_32()
	if size < 4 or size > MAX_BYTES:
		return {}
	var digest := file.get_buffer(32)
	var compressed := file.get_buffer(file.get_length() - file.get_position())
	if digest != _hash(compressed):
		return {}
	var payload := compressed.decompress(size, FileAccess.COMPRESSION_FASTLZ)
	if payload.size() != size:
		return {}
	var value: Variant = bytes_to_var(payload)
	if not value is Dictionary or value.get("game") not in ["yugi", "kaiba", "joey"]:
		return {}
	var lp: Variant = value.get("lp")
	var match_state: Variant = value.get("match")
	if not lp is Array or lp.size() != 2 or not match_state is Array or match_state.size() != 5 \
			or not value.get("initial") is bool:
		return {}
	return value


static func write(directory: String, value: Dictionary) -> Error:
	var path := _path(directory)
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		return err
	var payload := var_to_bytes(value)
	if payload.size() > MAX_BYTES:
		return ERR_OUT_OF_MEMORY
	var compressed := payload.compress(FileAccess.COMPRESSION_FASTLZ)
	if compressed.is_empty() or compressed.size() + 40 > MAX_BYTES:
		return ERR_INVALID_DATA
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_32(VERSION)
	file.store_32(payload.size())
	file.store_buffer(_hash(compressed))
	file.store_buffer(compressed)
	file.flush()
	err = file.get_error()
	file.close()
	if err != OK:
		return err
	return DirAccess.rename_absolute(temporary, path)


static func clear(directory: String) -> Error:
	var path := _path(directory)
	return DirAccess.remove_absolute(path) if FileAccess.file_exists(path) else OK


static func _hash(payload: PackedByteArray) -> PackedByteArray:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(payload)
	return context.finish()
