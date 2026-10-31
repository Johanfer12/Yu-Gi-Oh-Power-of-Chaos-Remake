extends Node
## Estado global y navegacion entre pantallas (todas se construyen por codigo).

const GAMES := ["yugi", "kaiba", "joey"]
## Prefijo de carpeta de cada juego dentro de data/ y nombre visible.
const TITLES := {"yugi": "Yugi the Destiny", "kaiba": "Kaiba the Revenge", "joey": "Joey the Passion"}

# El ultimo nodo recibe los atajos antes que las escenas y sus SubViewports.
class WindowShortcuts:
	extends Node
	var _windowed_mode := Window.MODE_WINDOWED
	func _input(event: InputEvent) -> void:
		if not event is InputEventKey: return
		var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if key != KEY_F11 and not (event.alt_pressed and key in [KEY_ENTER, KEY_KP_ENTER]): return
		# Consumir tambien la repeticion: Alt+Enter no confirma una carta o un dialogo.
		get_tree().root.set_input_as_handled()
		if event.pressed and not event.echo:
			var window := get_tree().root
			if window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
				window.mode = _windowed_mode
			else:
				_windowed_mode = window.mode
				window.mode = Window.MODE_FULLSCREEN

var _window_shortcuts := WindowShortcuts.new()
var _mobile_pointer: CanvasLayer

const DUEL_VIEWER_PATH := "res://scenes/duel/replay_viewer.gd"

var current_game := ""
## Mazo del rival elegido al entrar al duelo desde el menu (0x437c60), "" = el de demo1.
var rival_deck := ""
## Modo del duelo (DAT_005af778, 0x437f40): 0 duelo normal, 1 torneo (match al mejor de 3).
var duel_mode := 0
## Match: duelo actual 1..3 (DAT_005af76b), resultado de cada duelo (DAT_005af768[]: 1 gana el
## jugador, 2 el rival, 3 empate) y resultado global (DAT_005af764: 0 sigue, 1/2/3).
var match_duel := 1
var match_results := [0, 0, 0]
var match_outcome := 0
var _screen: Node
var _screen_host: Node
var _scene_wipe: Node
const SCENE_WIPE := preload("res://core/scene_wipe.gd")
## Contador global por vuelta del bucle principal (NativeClock.HZ): Yugi40c140(5aed18), Kaiba40c370(5b1d38).
## Persiste entre escenas; los titulos/tutoriales lo reinician en sus puntos nativos.
var native_tick := 0
var _native_clock := 0.0
## Mezcla entre ticks de lo que se anima con native_tick (las claves llevan el nodo que dibuja).
var native_blend := NativeBlend.new()
## Contadores de inactividad globales, por tick: raton DAT_005af864+0x30 (0x409680: a 0 si
## cambia la posicion o los botones) y teclado DAT_005af850+0x9f8 (0x45c990: a 0 con
## cualquiera de sus 0x58 teclas). Se guardan como tick de la ultima actividad.
var _ticks := 0
var _mouse_active_at := 0
var _key_active_at := 0



func _process(delta: float) -> void:
	_native_clock += NativeClock.ticks(delta)
	var steps := int(_native_clock)
	_native_clock -= steps
	native_tick = (native_tick + steps) & 0xffffffff
	_ticks += steps
	for _i in steps: native_blend.tick()
	native_blend.fraction = _native_clock


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_mouse_active_at = _ticks
	elif (event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton) \
			and event.pressed:
		# Acciones y mando llegan al juego como teclas de 0x538770.
		_key_active_at = _ticks


## 0x4600f0: el puntero solo se lleva solo a un destino si el teclado se ha usado despues que
## el raton (inactividad del teclado <= la del raton; al arrancar ambas valen lo mismo).
func keyboard_drives_pointer() -> bool:
	return _key_active_at >= _mouse_active_at


func reset_native_tick() -> void:
	native_tick = 0


func _ready() -> void:
	var language := Paths.cmdline_value("lang")
	if language == "":
		language = Assets.preferred_language()
	Assets.set_language(language)
	if OS.has_feature("mobile") or Paths.cmdline_value("mobile-controls") == "true":
		_mobile_pointer = preload("res://core/mobile_pointer.gd").new()
		get_tree().root.add_child.call_deferred(_mobile_pointer)
	get_tree().root.add_child.call_deferred(_window_shortcuts)
	# 0x40c66a: el MT de interfaz se siembra una vez al arrancar con GetTickCount (Debug lo
	# resiembra despues si hay --ui-seed o --ui-replay con semilla).
	UiRandom.seed_shared(UiRandom.clock_seed())
	# Acciones propias ademas de las ui_* de Godot
	_add_key_action("pc_switch", KEY_TAB)   # editor de mazos: bolsa <-> mazo
	_add_key_action("pc_side", KEY_S)       # editor de mazos: anadir al Side Deck
	_add_key_action("pc_filter", KEY_F)     # editor de mazos: siguiente filtro de la bolsa
	_add_key_action("pc_sort", KEY_O)       # editor de mazos: ventana de orden
	_add_key_action("pc_window", KEY_W)     # editor de mazos: plegar/desplegar la bolsa


func _add_key_action(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func goto(screen: Node) -> void:
	SaveData.ensure_game(current_game)
	if is_instance_valid(_scene_wipe):
		_scene_wipe.finish()
		_scene_wipe = null
	var effect := _scene_wipe_mode(_screen, screen)
	var old_frame: Texture2D
	# El launcher es propio del port; el primer arranque no tiene snapshot previo.
	if not LauncherSettings.fast_play and current_game != "" and DisplayServer.get_name() != "headless" \
			and is_instance_valid(_screen) and _screen.is_inside_tree() \
			and _screen.get_script().resource_path.get_file() not in ["launcher.gd", "launcher_android.gd", "content_setup.gd"]:
		var old_image := _screen.get_viewport().get_texture().get_image()
		if old_image != null and not old_image.is_empty():
			old_frame = ImageTexture.create_from_image(old_image)
	if is_instance_valid(_screen_host):
		_screen_host.queue_free()
		_screen_host = null
	elif is_instance_valid(_screen):
		_screen.queue_free()
	_screen = screen
	get_tree().root.content_scale_aspect = LauncherSettings.gameplay_aspect()
	Engine.time_scale = LauncherSettings.simulation_speed if current_game != "" else 1.0
	if LauncherSettings.aspect == "overlay" and _is_duel_viewer(screen) and screen.game in ["yugi", "kaiba", "joey"]:
		_screen_host = load("res://scenes/duel/duel_margins.gd").new(screen)
		get_tree().root.add_child.call_deferred(_screen_host)
	else:
		get_tree().root.add_child.call_deferred(screen)
	if is_instance_valid(_mobile_pointer):
		_mobile_pointer.cancel()
		get_tree().root.move_child.call_deferred(_mobile_pointer, -1)
	get_tree().root.move_child.call_deferred(_window_shortcuts, -1)
	if old_frame != null:
		_start_scene_wipe.call_deferred(old_frame, screen, effect)


## Callers acreditados: menus13; bust/bootstrap4b; duelo/janken2a.
func _scene_wipe_mode(previous: Node, following: Node) -> int:
	if not is_instance_valid(previous): return 0x13
	var script: Script = previous.get_script()
	if script == null: return 0x13
	var source := script.resource_path.get_file()
	var target: Script = following.get_script()
	var target_name := target.resource_path.get_file() if target != null else ""
	if source in ["bust_up_scene.gd", "bust_up_rival.gd", "launcher.gd", "launcher_android.gd", "content_setup.gd"]:
		return 0x4b
	if source in ["tutorial_menu.gd", "tutorial_menu_kaiba.gd"] and target_name == "title_screen.gd":
		return 0x4b
	if source in ["normal_duel.gd", "joey_native_normal.gd", "replay_viewer.gd", "janken_scene.gd", "janken_kaiba.gd", "janken_joey.gd"]:
		return 0x2a
	return 0x13


## 531f80 cambia de escena y dibuja una vez el destino antes de la captura40a260.
func _start_scene_wipe(old_frame: Texture2D, screen: Node, effect := 0x13) -> void:
	if not is_instance_valid(screen) or screen != _screen or not screen.is_inside_tree():
		return
	var previous_mode := screen.process_mode
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	if screen.has_method("_process"):
		screen.call("_process", 1.0 / NativeClock.HZ)
	# Cubrir el primer dibujo mientras Godot vacia las ordenes de CanvasItem.
	# El destino nunca se presenta antes de su barrido.
	var wipe := SCENE_WIPE.new(old_frame, old_frame, screen, previous_mode, effect)
	_scene_wipe = wipe
	screen.get_viewport().add_child(wipe)
	wipe.set_process(false)
	await RenderingServer.frame_post_draw
	if not is_instance_valid(wipe) or not is_instance_valid(screen) or screen != _screen:
		return
	wipe.hide()
	RenderingServer.force_draw(false)
	var image := screen.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		wipe.finish()
		return
	wipe.set_destination(ImageTexture.create_from_image(image))
	wipe.show()
	RenderingServer.force_draw(false)
	wipe.set_process(true)



func open_launcher() -> void:
	current_game = ""
	# Android: biblioteca instalada o importador del PCK privado. PC: biblioteca e importador
	# de las copias del usuario (content_setup amplía el launcher de escritorio).
	if Paths.android_platform():
		goto(load("res://scenes/launcher/launcher_android.gd").new() if Paths.has_data() else load("res://scenes/launcher/android_content_setup.gd").new())
	else:
		goto(load("res://scenes/launcher/content_setup.gd").new())


## Al volver de otra pantalla (`focus` = opcion de la que se viene) no se repite la portada
## de Yugi y el cursor queda en esa opcion.
func open_title(game: String, focus := "", launcher_cover: CanvasLayer = null) -> void:
	if not Paths.has_game(game):
		open_launcher()
		return
	current_game = game
	goto(load("res://scenes/title/title_screen.gd").new(game, focus))
	if launcher_cover != null:
		# Cambiar EXPAND a KEEP bajo negro y descubrir solo el primer dibujo del titulo.
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		launcher_cover.queue_free()


## Entradas explícitas de las escenas originales11/1; material visual provisional.
## No se inventa una condición de desbloqueo en el menú comercial.
func open_ending(game: String, mode := "credits") -> void:
	current_game = game
	var scene: Node2D = load("res://scenes/ending/ending_scene.gd").new(game, mode)
	scene.finished.connect(open_title.bind(game), CONNECT_ONE_SHOT)
	goto(scene)


func open_deck_editor(game: String) -> void:
	current_game = game
	goto(load("res://scenes/deck_editor/deck_editor.gd").new(game))


## Visor de repeticiones del duelo: `what` = "demo" (Repeticion) o "tutorial".
func open_duel_replay(game: String, what: String) -> void:
	current_game = game
	if game in ["yugi", "kaiba"] and what.begins_with("lesson:"):
		goto(load("res://scenes/duel/tutorial_lesson.gd").new(game, what))
	else:
		goto(load("res://scenes/duel/replay_viewer.gd").new(game, what))


func open_tutorial(game: String) -> void:
	current_game = game
	# Yugi469550, Kaiba46b730, Joey48dd80.
	reset_native_tick()
	if game == "yugi":
		goto(load("res://scenes/duel/tutorial_menu.gd").new())
	elif game == "kaiba":
		goto(load("res://scenes/duel/tutorial_menu_kaiba.gd").new())
	else:
		open_duel_replay(game, "tutorial")


## Joey 48a150: con el menu inactivo (mismos umbrales que Yugi 467000) elige un mazo FUL con
## 44bbe0 para el lado 0 y abre un duelo de tipo 7 (44bee0(7, mazo)): el motor da los dos
## lados a la CPU (MODE |= 6) y la CPU elige su propio mazo. Sin demoN.ydr (D35).
var joey_demo := false
var joey_demo_deck := ""


func open_joey_demo() -> void:
	duel_mode = 0
	joey_demo = true
	joey_demo_deck = choose_rival_deck("joey")
	rival_deck = choose_rival_deck("joey")
	open_normal_duel("joey", 0)


func open_normal_duel(game: String, start_options := -1) -> void:
	current_game = game
	if game == "joey":
		goto(load("res://scenes/duel/joey_native_normal.gd").new(start_options))
	else:
		goto(load("res://scenes/duel/normal_duel.gd").new(game, start_options))


## Duelo desde el menu: en Yugi pasa antes por la entrada de Yugi (escena 6, DAT_005af6f8 = 0).
## Despues de la entrada va el piedra-papel-tijera (escena 7, DAT_005af6f4 = 7), que decide
## quien empieza (DAT_005af770).
## Menus467000(Yugi),4694b0(Kaiba),48a150(Joey): conservan su musica durante
## la entrada; los constructores de janken ponen la pista siguiente.
func start_normal_duel(game: String, mode := 0) -> void:
	# 0x437f40 casos 0/1: match a cero.
	duel_mode = mode
	match_duel = 1
	match_results = [0, 0, 0]
	match_outcome = 0
	rival_deck = choose_rival_deck(game)
	current_game = game
	if LauncherSettings.fast_play:
		open_janken(game)
		return
	var script: GDScript = load("res://scenes/duel/bust_up_scene.gd") if game == "yugi" else load("res://scenes/duel/bust_up_rival.gd")
	var scene: Node2D = script.new(game)
	scene.finished.connect(open_janken.bind(game), CONNECT_ONE_SHOT)
	goto(scene)


func open_janken(game: String) -> void:
	current_game = game
	var script: GDScript = load({"yugi": "res://scenes/duel/janken_scene.gd", "kaiba": "res://scenes/duel/janken_kaiba.gd", "joey": "res://scenes/duel/janken_joey.gd"}[game])
	var scene: Node2D = script.new()
	# Joey 44b980: el janken va por red en el modo 3 (duelo LAN).
	scene.lan = duel_mode == 3 and Lan.active()
	scene.lost.connect(func() -> void: lan_lost(game), CONNECT_ONE_SHOT)
	scene.finished.connect(func(options: int) -> void: open_normal_duel(game, options), CONNECT_ONE_SHOT)
	goto(scene)


## Duelo LAN de Joey (D17): mazo que mando el rival (0xf004) y semilla de la sesion (0xf005).
var lan_rival_deck := {}
var lan_seed := -1


## Opcion "Duelo LAN" del titulo de Joey: pantalla de conexion (4207d0). Cancelar vuelve al
## titulo en la opcion (escena 2); conectada, janken (escena 7); sin sesion, titulo (escena 4).
func open_lan(game: String) -> void:
	current_game = game
	var scene: Node2D = load("res://scenes/lan/lan_connect.gd").new(game)
	scene.finished.connect(func(next: String) -> void:
		if next == "janken":
			match_duel = 1
			match_results = [0, 0, 0]
			match_outcome = 0
			open_janken(game)
		else:
			Lan.close()
			duel_mode = 0
			open_title(game, "lan"), CONNECT_ONE_SHOT)
	goto(scene)


## Se perdio la sesion fuera del duelo (janken 461370 / sala 5bdac0): titulo (escena 4).
func lan_lost(game: String) -> void:
	Lan.close()
	duel_mode = 0
	Audio.stop_music()
	open_title(game)


## 0x437440 (desde 0x53d9d0 al acabar el duelo): guarda el resultado del duelo y, en match,
## decide el global con victorias - derrotas: +-2 decide; en el tercero, +-1 decide y 0 empata.
func record_duel_result(result: int) -> void:
	if duel_mode not in [0, 1, 3]:
		return
	match_results[match_duel - 1] = result
	if duel_mode != 1:
		match_outcome = result
		return
	var count := [0, 0, 0, 0]
	for i in match_duel:
		count[match_results[i] & 3] += 1
	match count[1] - count[2]:
		0:
			if match_duel == 3: match_outcome = 3
		1:
			if match_duel == 3: match_outcome = 1
		2:
			match_outcome = 1
		-2:
			match_outcome = 2
		-1:
			if match_duel == 3: match_outcome = 2


## Estado 7 de 0x435410 con el match sin decidir: escena 10 (editor en modo intercambio con el
## Side, deck_editor.gd con "swap").
func continue_match(game: String) -> void:
	current_game = game
	goto(load("res://scenes/deck_editor/deck_editor.gd").new(game, "swap"))


## Salida valida de la escena 10 (0x459c10): 0x437f40(2) (siguiente duelo del match) y
## escena 7 (piedra-papel-tijera, que en match elige el perdedor).
func after_swap(game: String) -> void:
	match_duel += 1
	open_janken(game)


## 0x437c60: mazo de Yugi (data/Y/file/cpu<sufijo>.ydc) segun el porcentaje de cartas que se
## tienen de las de este juego (0x45dd50, CARD_Pack con el bit del juego) y la racha
## (DAT_00a11215: 1 gana el jugador, 2 la CPU; DAT_00a11216: duelos seguidos). Sin sufijo
## especial, uno de 01..04 al azar. Los azares son el MT de interfaz (0x531140 / 0x401ba0).
func choose_rival_deck(game: String) -> String:
	var pool := CardDB.obtainable_in(game)
	var owned := 0
	for card in pool:
		owned += int(SaveData.card_count(int(card["internal_id"])) > 0)
	var pct := owned * 100 / maxi(1, pool.size())
	var stats: Dictionary = SaveData.data.get("stats", {}).get(game, {})
	var last := int(stats.get("streak_last", 0))
	var run := int(stats.get("streak", 0))
	if game == "kaiba":
		return RivalDeckChoice.kaiba(pct, last, run, has_previous_cards(game), func(): return UiRandom.draw())
	if game == "joey":
		return RivalDeckChoice.joey(int(stats.get("level", 1)) & 255, joey_full_cards(), func(): return UiRandom.draw())
	var suffix := ""
	var strong := func() -> String: return "kk" if (UiRandom.draw() & 1) != 0 else "k"   # 0x437f1d
	if pct < 45:
		if last == 2 and run >= 2 and (UiRandom.draw() & 1) == 0:
			suffix = "jj"
		if last == 1 and run > 2:
			var n := 4 - int(run > 4)
			if UiRandom.draw_mod(n) == 0:
				suffix = "k"
	elif pct < 60:
		if last == 2 and run >= 2 and UiRandom.draw() % 3 == 0:
			suffix = "jj" if (UiRandom.draw() & 1) != 0 else "j"
		if last == 1 and run > 2:
			var n := 3 - int(run > 4)
			if UiRandom.draw_mod(n) == 0:
				suffix = strong.call()
	elif pct < 90:
		if last == 2 and run >= 3 and UiRandom.draw() % 3 == 0:
			suffix = "j"
		if last == 1 and run > 1:
			var n := 3 - int(run > 3)
			if UiRandom.draw_mod(n) == 0:
				suffix = strong.call()
	elif UiRandom.draw() % 3 == 0:
		suffix = strong.call()
	if suffix == "":
		suffix = ["01", "02", "03", "04"][UiRandom.draw() & 3]
	return "%s/file/cpu%s.json" % [game, suffix]


## Kaiba 45fc70 / Joey 5bedd0: se posee una carta usable sin el bit del juego actual.
## No basta con tener cartas de otro paquete: las compartidas con este no activan la rama.
func has_previous_cards(game: String) -> bool:
	var pack: int = CardDB.PACK_BITS[game]
	var usable: int = 3 if game == "kaiba" else 7
	for card in CardDB.cards:
		if (int(card["pack"]) & usable) != 0 and (int(card["pack"]) & pack) == 0 \
				and SaveData.card_count(int(card["internal_id"])) > 0:
			return true
	return false


## Jo48a150/44bbe0: FULL selecciona FUL y suma2 al nivel; inventario solo habilita el botón.
func joey_full_cards() -> bool:
	return bool(SaveData.data.get("options", {}).get("joey", {}).get(
			"card_set_full", has_previous_cards("joey")))


## Tras el resultado: en Yugi, su salida (escena 6, DAT_005af6f8 = 1) y despues el titulo.
## Tampoco el resultado (0x435410, estado 7) para la musica antes de la salida.
func finish_normal_duel(game: String, winner: int) -> void:
	if duel_mode == 3:
		# Joey 5bd2d0: con el resultado intercambiado (0xf002/0xf003) se cierra la sesion.
		Lan.close()
	if winner == 0:
		Audio.stop_music()
		open_title(game, "duel")
		return
	if LauncherSettings.fast_play:
		open_title(game, "duel")
		return
	var script: GDScript = load("res://scenes/duel/bust_up_scene.gd") if game == "yugi" else load("res://scenes/duel/bust_up_rival.gd")
	var scene: Node2D = script.new(game, winner)
	scene.finished.connect(open_title.bind(game, "duel"), CONNECT_ONE_SHOT)
	goto(scene)


func open_card_list(game: String) -> void:
	current_game = game
	goto(load("res://scenes/card_list/card_list.gd").new(game))


## Reconoce también las subclases sin cargar todo el duelo al arrancar.
func _is_duel_viewer(screen: Node) -> bool:
	var script: Script = screen.get_script()
	while script != null:
		if script.resource_path == DUEL_VIEWER_PATH:
			return true
		script = script.get_base_script()
	return false
