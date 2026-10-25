extends SceneTree

var rows: Array = []
func _init():

    _run.call_deferred()
func _finish(ok: bool, message: String):
    var file := FileAccess.open(root.get_node("Paths").cmdline_value("report"), FileAccess.WRITE)
    file.store_string(JSON.stringify({"ok": ok, "message": message, "games": rows, "data_dir": root.get_node("Paths").data_dir}, "  "))
    file.close()
    root.get_node("Audio").stop_all()
    quit(0 if ok else 1)
func _run():
    await process_frame
    print("paquete smoke: inicio")
    var paths := root.get_node("Paths")
    if not paths.has_data() or paths.data_dir != "res://data":
        _finish(false, "No se cargaron los datos internos del paquete")
        return
    root.get_node("Audio").set_option_volume(0)
    var game := root.get_node("Game")
    game.open_launcher()
    await process_frame
    var inventory: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(paths.data_dir.path_join("inventory.json")))
    for game_id in ["yugi", "kaiba", "joey"]:
        if not inventory.get("games", {}).has(game_id):
            continue
        if root.get_node("Assets").texture(game_id + "/duel/field/fie_normal.png") == null:
            _finish(false, "Falta tablero: " + game_id)
            return
        game.open_normal_duel(game_id)
        await process_frame
        await process_frame
        var scene: Node = game._screen
        if scene._duel == null:
            _finish(false, "No inicia duelo: " + game_id)
            return
        scene.set_process(false)
        for tick in 100: scene._process(1.0 / 30.0)
        rows.append(game_id)
    _finish(not rows.is_empty(), "Launcher y duelos de los juegos incluidos funcionan con datos del paquete")
