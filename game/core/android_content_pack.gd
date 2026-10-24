extends RefCounted
## Asset-only, unencrypted Godot 4 PCKs produced by tools/android/pack_data.gd.
## Inspect before mounting: a content pack must never replace application code.
const MAX_BYTES := 4 * 1024 * 1024 * 1024
const MAX_FILES := 100000

static func validate_pack(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "open"}
	var length := file.get_length()
	if length < 100 or length > MAX_BYTES or file.get_32() != 0x43504447:
		return {"ok": false, "error": "format"}
	var version := file.get_32()
	var major := file.get_32()
	var minor := file.get_32()
	file.get_32() # patch
	var flags := file.get_32()
	var base := file.get_64()
	if version not in [2, 3, 4] or major != 4 or minor > int(Engine.get_version_info().minor) or flags & ~2 or base < 0 or base > length:
		return {"ok": false, "error": "format"}
	if version >= 3:
		var directory := file.get_64()
		if directory < 40 or directory > length - 4:
			return {"ok": false, "error": "format"}
		file.seek(directory)
	else:
		file.seek(96)
	var count := file.get_32()
	if count < 2 or count > MAX_FILES:
		return {"ok": false, "error": "format"}
	var entries: Dictionary = {}
	for index: int in range(count):
		if file.get_position() > length - 4:
			return {"ok": false, "error": "format"}
		var path_length := file.get_32()
		if path_length < 1 or path_length > 2048 or file.get_position() + path_length + 36 > length:
			return {"ok": false, "error": "format"}
		var path_buffer := file.get_buffer(path_length)
		var terminator := path_buffer.find(0)
		if terminator >= 0:
			path_buffer.resize(terminator)
		var packed_path := path_buffer.get_string_from_utf8()
		if packed_path.begins_with("data/"):
			packed_path = "res://" + packed_path
		var offset := file.get_64()
		var size := file.get_64()
		file.get_buffer(16) # MD5 stored by PCKPacker
		var entry_flags := file.get_32()
		if not packed_path.begins_with("res://data/") or packed_path != packed_path.simplify_path() or packed_path.contains("\\") \
			or packed_path.get_extension().to_lower() not in ["json", "bin", "txt", "png", "webp", "ogg", "wav", "ydr", "ydc"] \
			or entries.has(packed_path) or entry_flags != 0 or offset < 0 or size < 0 or base + offset < 0 or base + offset > length - size:
			return {"ok": false, "error": "format"}
		entries[packed_path] = {"offset": base + offset, "size": size}
	if not entries.has("res://data/inventory.json") or not entries.has("res://data/common/db/cards.json"):
		return {"ok": false, "error": "resources"}
	var inventory_entry: Dictionary = entries["res://data/inventory.json"]
	if inventory_entry.size < 2 or inventory_entry.size > 1024 * 1024:
		return {"ok": false, "error": "resources"}
	file.seek(inventory_entry.offset)
	var inventory: Variant = JSON.parse_string(file.get_buffer(inventory_entry.size).get_string_from_utf8())
	if not inventory is Dictionary or not inventory.get("games") is Dictionary or inventory.games.is_empty():
		return {"ok": false, "error": "resources"}
	for game: String in inventory.games:
		if game not in ["yugi", "kaiba", "joey"]:
			return {"ok": false, "error": "resources"}
		var field := "res://data/" + game + "/duel/field/fie_normal"
		if not entries.has(field + ".webp") and not entries.has(field + ".png"):
			return {"ok": false, "error": "resources"}
	var cards_entry: Dictionary = entries["res://data/common/db/cards.json"]
	if cards_entry.size < 2 or cards_entry.size > 32 * 1024 * 1024:
		return {"ok": false, "error": "resources"}
	file.seek(cards_entry.offset)
	var cards: Variant = JSON.parse_string(file.get_buffer(cards_entry.size).get_string_from_utf8())
	if not cards is Array or cards.is_empty():
		return {"ok": false, "error": "resources"}
	return {"ok": true, "files": count, "inventory": inventory}

static func install_pack(source: String, target: String) -> Dictionary:
	if source.is_empty():
		return {"ok": false, "error": "cancelled"}
	if FileAccess.file_exists(target) and validate_pack(target).ok:
		return {"ok": false, "error": "installed"}
	var input := FileAccess.open(source, FileAccess.READ)
	if input == null:
		return {"ok": false, "error": "open"}
	if input.get_length() < 100 or input.get_length() > MAX_BYTES:
		return {"ok": false, "error": "format"}
	if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK:
		return {"ok": false, "error": "copy"}
	var temporary := target + ".importing"
	var output := FileAccess.open(temporary, FileAccess.WRITE)
	if output == null:
		return {"ok": false, "error": "copy"}
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	while input.get_position() < input.get_length():
		var chunk := input.get_buffer(mini(1024 * 1024, input.get_length() - input.get_position()))
		if chunk.is_empty():
			output.close()
			DirAccess.remove_absolute(temporary)
			return {"ok": false, "error": "copy"}
		digest.update(chunk)
		output.store_buffer(chunk)
		if output.get_error() != OK:
			output.close()
			DirAccess.remove_absolute(temporary)
			return {"ok": false, "error": "copy"}
	output.close()
	input.close()
	if digest.finish().hex_encode() != FileAccess.get_sha256(temporary):
		DirAccess.remove_absolute(temporary)
		return {"ok": false, "error": "copy"}
	var inspected := validate_pack(temporary)
	if not inspected.ok:
		DirAccess.remove_absolute(temporary)
		return inspected
	# Invalid previous files are preserved, never overwritten silently.
	var previous := ""
	if FileAccess.file_exists(target):
		previous = target + ".previous-" + str(Time.get_ticks_usec())
		if DirAccess.rename_absolute(target, previous) != OK:
			DirAccess.remove_absolute(temporary)
			return {"ok": false, "error": "copy"}
	if DirAccess.rename_absolute(temporary, target) != OK:
		if not previous.is_empty():
			DirAccess.rename_absolute(previous, target)
		DirAccess.remove_absolute(temporary)
		return {"ok": false, "error": "copy"}
	return {"ok": true, "files": inspected.files, "previous": previous}
