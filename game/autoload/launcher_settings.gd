extends Node
## Preferencias del port, independientes de los recursos y de la partida.
const ASPECTS := ["stretch", "original", "overlay"]
const FRAME_RATES := [30, 60, 0] # 0: frecuencia del monitor actual.
var aspect := "overlay"
var frame_rate := 0
var simulation_speed := 1.0
var fast_play := false
var improved_card_texts := false
var _refresh_clock := 0.0

func _ready() -> void:
	reload_preferences()
	apply_timing()

func reload_preferences() -> void:
	var config := ConfigFile.new()
	config.load(Paths.settings_path())
	aspect = str(config.get_value("launcher", "aspect", "overlay"))
	if aspect not in ASPECTS: aspect = "overlay"
	frame_rate = int(config.get_value("launcher", "fps", 0))
	if frame_rate not in FRAME_RATES: frame_rate = 0
	simulation_speed = float(config.get_value("launcher", "simulation_speed", 1.0))
	if simulation_speed not in [1.0, 2.0]: simulation_speed = 1.0
	fast_play = bool(config.get_value("launcher", "fast_play", false))
	improved_card_texts = bool(config.get_value("launcher", "improved_card_texts", false))

func save_preferences() -> void:
	var config := ConfigFile.new()
	config.load(Paths.settings_path())
	config.set_value("launcher", "aspect", aspect)
	config.set_value("launcher", "fps", frame_rate)
	config.set_value("launcher", "simulation_speed", simulation_speed)
	config.set_value("launcher", "fast_play", fast_play)
	config.set_value("launcher", "improved_card_texts", improved_card_texts)
	var error := config.save(Paths.settings_path())
	if error != OK: push_error("No se pudieron guardar los ajustes: " + error_string(error))
	apply_timing()

func gameplay_aspect() -> int:
	return Window.CONTENT_SCALE_ASPECT_IGNORE if aspect == "stretch" else Window.CONTENT_SCALE_ASPECT_KEEP

func display_fps() -> int:
	if DisplayServer.get_name() == "headless": return 60
	var rate := DisplayServer.screen_get_refresh_rate(get_window().current_screen)
	return roundi(rate) if rate > 0.0 else 60

## --max-fps en la linea de comandos (cotejos con el original a 30 Hz) manda sobre la
## preferencia del launcher. Godot consume ese argumento (no sale en get_cmdline_args) y el
## proyecto no fija max_fps: si ya vale algo al arrancar, viene de la linea de comandos.
var _cmdline_max_fps := Engine.max_fps

func _cmdline_timing() -> bool:
	return _cmdline_max_fps > 0

func apply_timing() -> void:
	if _cmdline_timing(): return
	Engine.max_fps = display_fps() if frame_rate == 0 else frame_rate
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if frame_rate == 0 else DisplayServer.VSYNC_DISABLED)

func _process(delta: float) -> void:
	# Cambiar de monitor tambien actualiza el limite del modo Display.
	_refresh_clock += delta
	if _refresh_clock >= 1.0:
		_refresh_clock = 0.0
		if frame_rate == 0 and not _cmdline_timing(): Engine.max_fps = display_fps()
