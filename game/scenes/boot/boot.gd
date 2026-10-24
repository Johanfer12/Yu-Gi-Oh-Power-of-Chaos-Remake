extends Node2D
## Arranque: comprueba que existe data/ y abre el selector de juego.


func _ready() -> void:
	# Herramienta de desarrollo Android: prueba de compartir sin abrir el juego.
	if Paths.cmdline_value("share-smoke") == "true":
		get_tree().root.add_child.call_deferred(load("res://share_smoke.gd").new())
		queue_free()
		return
	_apply_window_override()
	# Sin recursos: el importador de la plataforma (PC: copias del usuario; Android: PCK).
	if not Paths.has_data() or Paths.storage_error:
		Game.open_launcher()
		queue_free()
		return
	var start := Debug.start_override()
	var ending := Paths.cmdline_value("scene")
	if ending in ["credits", "video"]:
		Game.open_ending(start if start in Game.GAMES else "yugi", ending)
	elif ending == "joey-native":
		Game.current_game = "joey"
		Game.goto(load("res://scenes/duel/joey_native_normal.gd").new())
	elif ending == "joey-engine-harness":
		Game.current_game = "joey"
		Game.goto(load("res://scenes/duel/joey_native_duel.tscn").instantiate())
	elif ending == "lan":
		# Herramienta de desarrollo: --scene=lan abre la pantalla de conexion de Joey (D17).
		Game.open_lan("joey")
	elif Paths.cmdline_value("scenario") != "":
		# Herramienta de desarrollo: --scenario=<nombre o ruta> abre el duelo preparado.
		Game.open_normal_duel(start if start in Game.GAMES else "yugi")
	elif start in Game.GAMES:
		Game.open_title(start)
	else:
		Game.open_launcher()
	queue_free()


## El modo maximizado se configura al crear la ventana en project.godot.
## Solo --window=ANCHOxALTO fuerza un tamano distinto para herramientas/pruebas.
func _apply_window_override() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("mobile"):
		return
	var forced := Paths.cmdline_value("window").split("x")
	if forced.size() == 2 and forced[0].is_valid_int() and forced[1].is_valid_int():
		var size := Vector2i(forced[0].to_int(), forced[1].to_int())
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(size)
		var screen := DisplayServer.window_get_current_screen()
		DisplayServer.window_set_position(DisplayServer.screen_get_position(screen)
				+ (DisplayServer.screen_get_size(screen) - size) / 2)
		return
