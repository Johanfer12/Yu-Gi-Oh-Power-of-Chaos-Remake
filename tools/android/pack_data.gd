extends SceneTree
## Uso: godot --headless --path game -s <este-script> -- --data=<copia> --pack-output=<archivo>
var _count := 0
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var paths := root.get_node("Paths")
	var source: String = ProjectSettings.globalize_path(paths.data_dir)
	var output: String = paths.cmdline_value("pack-output")
	if output == "" or not DirAccess.dir_exists_absolute(source):
		printerr("Se requieren --data y --pack-output validos")
		quit(1)
		return
	var pack := PCKPacker.new()
	var error := pack.pck_start(output)
	if error == OK: error = _add_dir(pack, source, "res://data")
	if error == OK: error = pack.flush()
	print("Datos empaquetados: ", _count, "; error=", error)
	quit(0 if error == OK else 1)
func _add_dir(pack: PCKPacker, source: String, target: String) -> Error:
	var dir := DirAccess.open(source)
	if dir == null: return ERR_CANT_OPEN
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var error: Error
		if dir.current_is_dir(): error = _add_dir(pack, source.path_join(name), target.path_join(name))
		else:
			error = pack.add_file(target.path_join(name), source.path_join(name))
			_count += 1
		if error != OK: return error
		name = dir.get_next()
	return OK
