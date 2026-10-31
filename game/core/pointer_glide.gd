class_name PointerGlide
## Objeto que desliza el puntero hasta un destino (Yugi DAT_005af868, Kaiba DAT_005b2888).
## - 0x45fff0 (Kaiba 0x462170) lo arranca desde la posicion actual con 0x51d610(0, 0x80, 6):
##   seis pasos con frenada en coseno, si la opcion DAT_005aed20+0xef5 esta activa (lo esta por
##   defecto; preferencia portable options.<juego>.pointer_motion). Lo usan el editor
##   y las listas del duelo.
## - 0x4600f0 (Kaiba 0x462270) solo lo arranca si el teclado se ha usado despues que el raton
##   (Game.keyboard_drives_pointer): asi lo piden titulo, opciones, menus de tutorial y janken.
##   Con el raton, la manita se queda donde esta.
## - Mientras esta activo (+0x40), las pantallas eligen la opcion por el destino (+0x44/+0x48
##   desde +0x4c/+0x50) y no por donde va el puntero: 0x4661d0, 0x466300, 0x469140 y Kaiba
##   0x46b7c0.
## - Si el jugador mueve el raton, se abandona.
## Un solo deslizamiento a la vez, como el objeto global del original. Cada pantalla que lo use
## llama a step() una vez por tick nativo.

static var active := false
static var _from := Vector2.ZERO
static var _delta := Vector2.ZERO
static var _k := 0
static var _at := Vector2.ZERO
static var _noted := Vector2.INF
static var _game_id := ""


## 0x4600f0: solo si manda el teclado.
static func request(from: Vector2, target: Vector2, game_id := "") -> void:
	var game := (Engine.get_main_loop() as SceneTree).root.get_node("Game")
	if game.keyboard_drives_pointer():
		start(from, target, game_id)


## 0x45fff0: siempre.
static func start(from: Vector2, target: Vector2, game_id := "") -> void:
	if not preload("res://core/duel_input.gd").pointer_motion(game_id):
		cancel()
		return
	active = true
	_game_id = game_id
	# El PE guarda coordenadas enteras; el escalado de Godot puede entregar fracciones.
	_from = from.round()
	_delta = target.round() - _from
	_k = 0
	_at = from


static func cancel() -> void:
	active = false


## `pos` es donde el ultimo deslizamiento dejo el puntero en un tick (no un movimiento del
## raton): el puntero dibujado puede mezclarse entre ticks.
static func drove(pos: Vector2) -> bool:
	return (_k > 0 and pos.distance_to(_at) <= 1.0) or pos.distance_to(_noted) <= 1.0


## Los deslizamientos propios de una pantalla (editor de mazos, ventanas del duelo) avisan de
## cada paso para que drove() los reconozca igual.
static func note(at: Vector2) -> void:
	_noted = at


## Un tick: devuelve la nueva posicion del puntero (en coordenadas de 800x600 de `node`) y la
## lleva tambien al puntero del sistema.
static func step(node: CanvasItem, mouse: Vector2) -> Vector2:
	if active and not preload("res://core/duel_input.gd").pointer_motion(_game_id): cancel()
	if not active:
		return mouse
	if mouse.distance_to(_at) > 1.0:
		active = false
		return mouse
	_k += 1
	var f := DuelVisualMath.cos_fx(0x80 * _k / 6 - 0x80)
	_at = _from + Vector2((int(_delta.x) * f) >> 16, (int(_delta.y) * f) >> 16)
	if node.is_inside_tree() and may_warp():
		node.get_viewport().warp_mouse(node.get_global_transform_with_canvas() * _at)
	if _k >= 6:
		active = false
	return _at


## Punto con el que se elige la opcion: el destino mientras se desliza, si no el raton.
static func hover(mouse: Vector2) -> Vector2:
	if active and mouse.distance_to(_at) <= 1.0:
		return _from + _delta
	return mouse


## El puntero nativo se desliza moviendo el cursor del sistema. En reproducciones y cotejos
## (--ui-replay, arneses con --capture-dir) no: moveria el raton real del usuario.
static func may_warp() -> bool:
	if DisplayServer.get_name() == "headless": return false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ui-replay=") or arg.begins_with("--capture-dir="): return false
	return true
