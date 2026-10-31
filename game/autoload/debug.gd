extends Node
## Ayudas para probar sin interaccion (argumentos despues de "--"):
##   --start=yugi|kaiba|joey   salta el selector y abre ese juego
##   --keys=down,down,accept   pulsa acciones (ui_*) una cada pocos fotogramas; tambien
##                             wheel_up / wheel_down (rueda del raton en el centro),
##                             click@x:y / rclick@x:y (clic izquierdo/derecho en 800x600),
##                             text@texto (rellena el campo de texto con el foco)
##   --shot=ruta.png           guarda una captura y cierra el juego
##   --shot-frames=N           fotogramas que espera antes de la captura (por defecto 60)
##   --scene=lan               abre la pantalla de conexion LAN de Joey (D17)
##   --unlock-all              da 3 copias de cada carta (como el parche original; se guarda)
##   --save=carpeta            usa otra carpeta de partidas (para pruebas sin tocar la real)
##   --import-system-dat=ruta  sustituye la partida por el system.dat del original y los
##                             Deck.ydc de los juegos instalados (SaveData; solo lectura)
##   --import-minus-card=id,.. con lo anterior, quita esos premios (ids internos) de la
##                             ultima partida; system.dat es el estado de despues
##   --import-minus-win        con lo anterior, resta tambien la victoria y la racha
##   --data=carpeta            usa otra carpeta de datos
##   --window=1600x900         ventana de ese tamano en vez de maximizada (boot.gd); en el
##                             selector las coordenadas de click@ son las de su pantalla
##                             estirada (alto 600, ancho segun el formato)
##   --ui-replay=traza.jsonl   reproduce la entrada grabada del original con
##                             re/scripts/frida/yugi_trace.py --ui (raton, botones, teclas).
##                             Usar con --fixed-fps 30 (un fotograma = un tick nativo) y
##                             --write-movie para guardar cada fotograma. Los ticks se cuentan
##                             desde la primera escena --ui-anchor (2 = menu del titulo) del
##                             original y desde la primera pantalla de titulo del port.
##                             Si la traza trae ui_seed, siembra con ella el MT de interfaz;
##                             cada duel_start siembra el rand() del CRT de un duelo normal.
##   --ui-seed=N               semilla del MT de interfaz (0x531140) en vez del reloj; manda
##                             sobre la de la traza
##   --ui-rand-log             imprime cada numero del MT de interfaz (cotejo con ui_rand)
##   --ui-shots=carpeta        con --ui-replay, guarda solo los fotogramas que corresponden a
##                             las capturas del original (y +-2), con el nombre de --write-movie
##                             (port%08d.png); ui_compare.py los lee igual y no hay que codificar
##                             cada fotograma

const KEY_INTERVAL := 12

var _keys: PackedStringArray = []
var _shot := ""
var _shot_frame := 60
var _frame := 0
## Reproduccion de entrada del original: [tick relativo, x, y, teclas VK pulsadas, cambios de
## escena del original anteriores al evento en la traza].
var _replay: Array = []
var _replay_at := 0
var _replay_anchor := -1
var _replay_down: Array = []
## Reanclaje por escena: ticks (desde el ancla) en que el original cambio de escena y
## fotogramas del port en que cambio de pantalla. Cada entrada se aplica contando desde el
## ultimo cambio de escena que la precede, para que una transicion de distinta duracion no
## desplace el resto.
var _scene_ticks: Array = []
var _port_scene_frames: Array = []
var _last_screen: Node
var _seed_from_trace := false
## Semillas del rand() del CRT de cada duel_start de la traza (lo que el original pasa a
## 5418a0, el mismo valor que el srand de 0x5418bc), en orden: una por duelo.
var _duel_seeds: Array[int] = []
## --ui-shots: capturas del original [tick relativo, cambios de escena anteriores] y carpeta.
var _shots: Array = []
var _shots_dir := ""
var _shots_saved := 0
const SHOT_WINDOW := 2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var keys := Paths.cmdline_value("keys")
	if keys != "":
		_keys = keys.split(",")
	_shot = Paths.cmdline_value("shot")
	var frames := Paths.cmdline_value("shot-frames")
	if frames != "":
		_shot_frame = frames.to_int()
	if _keys.size() > 0:
		_shot_frame += _keys.size() * KEY_INTERVAL
	var replay := Paths.cmdline_value("ui-replay")
	if replay != "":
		_load_replay(replay, Paths.cmdline_value("ui-anchor").to_int() if Paths.cmdline_value("ui-anchor") != "" else 2)
		NativeClock.interpolate = false
	_shots_dir = Paths.cmdline_value("ui-shots")
	if _shots_dir != "" and not _shots.is_empty():
		DirAccess.make_dir_recursive_absolute(_shots_dir)
		RenderingServer.frame_post_draw.connect(_save_shot)
	UiRandom.log_draws = OS.get_cmdline_user_args().has("--ui-rand-log")
	var ui_seed := Paths.cmdline_value("ui-seed")
	if ui_seed != "":
		UiRandom.seed_shared(ui_seed.to_int())
		print("ui-seed: %d (--ui-seed)" % UiRandom.shared_seed)


func start_override() -> String:
	return Paths.cmdline_value("start")


## Semilla del siguiente duelo de la traza de --ui-replay, o -1 si no queda ninguna (entonces
## el duelo usa la hora, como fuera de la reproduccion).
func next_duel_seed() -> int:
	if _duel_seeds.is_empty():
		return -1
	var s: int = _duel_seeds.pop_front()
	print("duel-seed: %d (traza)" % s)
	return s


func _process(_delta: float) -> void:
	_frame += 1
	if not _replay.is_empty():
		_step_replay()
	var key_index := _frame / KEY_INTERVAL - 2
	if _frame % KEY_INTERVAL == 0 and key_index >= 0 and key_index < _keys.size():
		var key := _keys[key_index]
		if key.begins_with("wheel_"):
			_wheel(key == "wheel_up")
		elif key.begins_with("text@"):
			var focus := get_viewport().gui_get_focus_owner()
			if focus is LineEdit:
				focus.text = key.get_slice("@", 1)
		elif key.begins_with("click@") or key.begins_with("rclick@"):
			var xy := key.get_slice("@", 1).split(":")
			_click(Vector2(xy[0].to_float(), xy[1].to_float()), key.begins_with("r"))
		else:
			_press("ui_" + key)
	if _shot != "" and _frame == _shot_frame:
		var image := get_viewport().get_texture().get_image()
		image.save_png(_shot)
		print("captura: ", _shot)
		Audio.stop_all()
		get_tree().quit.call_deferred()


## --ui-shots: tras dibujar el fotograma _frame, lo guarda si alguna captura del original cae a
## SHOT_WINDOW o menos (mismo reanclaje por escena que la entrada).
func _save_shot() -> void:
	if _replay_anchor < 0:
		return
	for shot: Array in _shots:
		var at := _port_frame_for(int(shot[0]), int(shot[1]))
		if at >= 0 and absi(_frame - at) <= SHOT_WINDOW:
			get_viewport().get_texture().get_image().save_png(_shots_dir.path_join("port%08d.png" % _frame))
			_shots_saved += 1
			return


## Clic (pulsar y soltar) en coordenadas de la pantalla de 800x600, con movimiento previo.
func _click(pos: Vector2, right: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		get_viewport().push_input(ev, true)


## Rueda del raton en el centro de la pantalla de 800x600.
func _wheel(up: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.position = Vector2(500, 300)
	get_viewport().push_input(ev, true)


func _press(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


# --- Reproduccion de la entrada del original (--ui-replay) ------------------------------------

## Teclas virtuales de Windows (GetAsyncKeyState) que usa la interfaz -> teclas de Godot.
const VK_KEYS := {0x08: KEY_BACKSPACE, 0x09: KEY_TAB, 0x0d: KEY_ENTER, 0x10: KEY_SHIFT,
	0x11: KEY_CTRL, 0x12: KEY_ALT, 0x1b: KEY_ESCAPE, 0x20: KEY_SPACE, 0x21: KEY_PAGEUP,
	0x22: KEY_PAGEDOWN, 0x23: KEY_END, 0x24: KEY_HOME, 0x25: KEY_LEFT, 0x26: KEY_UP,
	0x27: KEY_RIGHT, 0x28: KEY_DOWN, 0x2e: KEY_DELETE}


func _vk_key(vk: int) -> Key:
	if VK_KEYS.has(vk): return VK_KEYS[vk]
	if vk >= 0x30 and vk <= 0x39: return (KEY_0 + vk - 0x30) as Key
	if vk >= 0x41 and vk <= 0x5a: return (KEY_A + vk - 0x41) as Key
	if vk >= 0x70 and vk <= 0x7b: return (KEY_F1 + vk - 0x70) as Key
	return KEY_NONE


func _load_replay(path: String, anchor_scene: int) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("ui-replay: no se puede abrir ", path)
		return
	# Reloj del original: vueltas del bucle principal ("tick", trazas nuevas) o presentaciones
	# ("frame"). No la hora: durante una carga el reloj avanza pero el juego no.
	var anchor := -1
	var events: Array = []
	var legacy := false
	while not f.eof_reached():
		var line := f.get_line()
		if line.contains("\"ui_seed\""):
			var s: Dictionary = JSON.parse_string(line)
			# 0x40c66a siembra el objeto 0x5aed28 una vez; la autosiembra 0x1105 de 531140 no
			# llega a darse tras ella.
			if not _seed_from_trace:
				UiRandom.seed_shared(int(s["seed"]))
				_seed_from_trace = true
				print("ui-seed: %d (traza)" % UiRandom.shared_seed)
			continue
		if line.contains("\"duel_start\""):
			var d: Dictionary = JSON.parse_string(line)
			if d.get("ev") == "duel_start" and d.has("seed"):
				_duel_seeds.append(int(d["seed"]))
			continue
		if line.contains("\"ui_shot\"") and anchor >= 0:
			var s: Dictionary = JSON.parse_string(line)
			_shots.append([int(s.get("tick", s.get("frame", 0))) - anchor, _scene_ticks.size()])
			continue
		if line == "" or not (line.contains("ui_frame") or line.contains("ui_scene")):
			continue
		var e: Dictionary = JSON.parse_string(line)
		var clock := int(e.get("tick", e.get("frame", 0)))
		if e["ev"] == "ui_scene" and anchor < 0 and int(e["id"]) == anchor_scene:
			anchor = clock
		elif e["ev"] == "ui_scene" and anchor >= 0:
			_scene_ticks.append(clock - anchor)
		elif e["ev"] == "ui_frame" and anchor >= 0:
			var down: Array = []
			for k in e["down"]: down.append(int(k))
			# La escena del evento sale del orden de la traza, no del tick: una entrada muestreada
			# en el mismo tick en que cambia la escena (ui_frame antes de ui_scene) es de la
			# escena que se va.
			events.append([clock - anchor, int(e["x"]), int(e["y"]), down, _scene_ticks.size()])
			legacy = legacy or not e.has("src")
	# Trazas antiguas: el raton se leia con GetAsyncKeyState al presentar y un clic rapido cuyo
	# WM_LBUTTONUP el juego ya habia procesado (cambiando de escena) aparece despues del cambio.
	# Ese soltar se adelanta al tick anterior al cambio de escena.
	if legacy:
		for scene_tick in _scene_ticks:
			for i in range(1, events.size()):
				var e: Array = events[i]
				if int(e[0]) < int(scene_tick) or int(e[0]) > int(scene_tick) + 2:
					continue
				var before: Array = events[i - 1]
				var was_down: bool = 0x01 in before[3] or 0x02 in before[3]
				var is_up: bool = not (0x01 in e[3] or 0x02 in e[3])
				if int(before[0]) < int(scene_tick) and int(before[0]) >= int(scene_tick) - 3 \
						and was_down and is_up:
					e[0] = maxi(int(before[0]), int(scene_tick) - 1)
					e[4] = before[4]
				break
	_replay = events
	print("ui-replay: %d cambios de entrada desde la escena %d" % [events.size(), anchor_scene])


func _step_replay() -> void:
	if _replay_anchor < 0:
		var screen: Node = Game._screen
		if screen == null or not screen.get_script().resource_path.ends_with("title_screen.gd"):
			return
		_replay_anchor = _frame
		_last_screen = screen
		print("ui-anchor: ", _frame)
	if Game._screen != _last_screen and Game._screen != null:
		_last_screen = Game._screen
		_port_scene_frames.append(_frame)
		print("ui-port-scene: %d %d %s" % [_port_scene_frames.size(), _frame,
				_last_screen.get_script().resource_path.get_file()])
	while _replay_at < _replay.size():
		var at := _port_frame_for(int(_replay[_replay_at][0]), int(_replay[_replay_at][4]))
		if at < 0 or _frame < at:
			break
		_apply_input(_replay[_replay_at])
		_replay_at += 1


## Fotograma del port para el tick T del original, que ocurre tras `n` cambios de escena, o -1
## si el port aun no ha llegado a esa escena.
func _port_frame_for(t: int, n: int) -> int:
	if n == 0:
		return _replay_anchor + t
	if n > _port_scene_frames.size():
		return -1
	return int(_port_scene_frames[n - 1]) + t - int(_scene_ticks[n - 1])


const REPLAY_DEVICE := 31 # Marca de sondas; las sesiones normales no filtran por device.

## Una escena nueva hereda el punto nativo de la repetición. Input global puede
## contener la posición física aunque ReplayOnly haya descartado ese evento.
func replay_pointer_position(fallback: Vector2) -> Vector2:
	if _replay_at <= 0 or _replay.is_empty(): return fallback
	var entry: Array = _replay[_replay_at - 1]
	return Vector2(entry[1], entry[2])

func _apply_input(e: Array) -> void:
	var pos := Vector2(e[1], e[2])
	# ui_frame graba coordenadas nativas800x600; parse_input_event recibe el root.
	# Ademas actualiza Input global para las consultas sostenidas del motor.
	if is_instance_valid(Game._screen_host) and Game._screen_host.get("_container") != null:
		var container: Control = Game._screen_host.get("_container")
		pos = container.get_global_transform_with_canvas() * pos
	pos = get_viewport().get_final_transform() * pos
	var motion := InputEventMouseMotion.new()
	motion.device = REPLAY_DEVICE
	motion.position = pos
	motion.global_position = pos
	Input.parse_input_event(motion)
	var down: Array = e[3]
	for vk in [0x01, 0x02]:
		if (vk in down) != (vk in _replay_down):
			var ev := InputEventMouseButton.new()
			ev.device = REPLAY_DEVICE
			ev.button_index = MOUSE_BUTTON_LEFT if vk == 0x01 else MOUSE_BUTTON_RIGHT
			ev.pressed = vk in down
			ev.position = pos
			ev.global_position = pos
			Input.parse_input_event(ev)
	for vk in down + _replay_down:
		if vk in [0x01, 0x02, 0x04]: continue
		var now: bool = vk in down
		if now == (vk in _replay_down): continue
		var key := _vk_key(vk)
		if key == KEY_NONE: continue
		var kev := InputEventKey.new()
		# InputMap teclado usa device0; conserva coincidencia ui_* y marca metadato.
		kev.set_meta("debug_replay", true)
		kev.keycode = key
		kev.physical_keycode = key
		kev.pressed = now
		Input.parse_input_event(kev)
	# La entrada grabada pertenece a este tick; evitar acumulacion hasta el siguiente.
	Input.flush_buffered_events()
	_replay_down = down
