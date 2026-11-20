class_name DuelBase
extends RefCounted
## Base del motor de duelo: estado en memoria, generador aleatorio, cola y ejecucion de
## comandos. Las rutinas portadas del original van en las clases hijas
## (DuelPrims -> DuelPortA ... DuelPortO -> DuelCmds -> Duel). Cada funcion portada lleva en su comentario la direccion
## de la original en Yugi_Pc.exe; la documentacion esta en docs/duel/README.md.

## Modos de DAT_005af778 (0x437f40)
const GAME_NORMAL := 0
## Juego 3 de 5418a0: duelo en red (539a60 pone el bit 8 de a16180).
const GAME_NETWORK := 3
const GAME_REPLAY := 4

const MODE_REPLAY := 1   ## bits 12-13 de 0xa114b4
const MODE_NETWORK := 3

var m := DuelMem.new()
var animation_mailbox := preload("res://core/duel_animation_mailbox.gd").new(m)
var rng := MsvcRand.new()
var cards: CardTables
## DAT_005af778: tipo de partida
var game_mode := GAME_NORMAL
## Version del ejecutable que gobierna diferencias contrastadas de reglas/comandos.
var rules_game := "yugi"
## Version del encabezado de repeticion YDR.
var native_version := 100
## Eventos de presentacion (animaciones, sonidos, textos) para la escena del duelo.
var events: Array[Dictionary] = []
## Comandos emitidos en esta partida (lo que el original graba en la repeticion).
var recorded: Array[PackedInt32Array] = []
## Comandos que llegan de fuera (repeticion) y posicion de lectura.
var _incoming: Array[PackedInt32Array] = []
var _incoming_pos := 0
## Incoherencias entre los argumentos de un comando y el estado (solo pruebas).
var mismatches: PackedStringArray = []
## Numero de comandos ejecutados.
var executed := 0
## f53b4e0 va a sacar el comando de cabeza de la cola (solo pruebas: traza frente al original).
signal command_popping
## Ultima etapa de f53dbf0 alcanzada en el fotograma (solo pruebas, ver
## tests/original_trace_replay.gd): 1 53b4e0, 2 540db0, 3 53e370, 4 57c440, 5 53d550,
## 6 56a430, 7 manejador del estado del turno.
var frame_stage := 0
## Respuesta automatica a los cuadros de dialogo (sin interfaz). -1 = no se responde y el
## nucleo espera a que la escena llame a f540d80(respuesta). AUTO_SCRIPT (solo pruebas) recorre
## los menus de los tutoriales: mira las comprobaciones 0xf8 que siguen a la pregunta (saltan a
## la etiqueta a si la respuesta es b) y en cada visita a la misma pregunta prueba otra opcion:
## primero los saltos hacia delante, luego seguir de largo y al final los saltos hacia atras.
const AUTO_SCRIPT := -2
## Estado continuo del botón derecho (+0xc del objeto de entrada original).
## Es distinto del flanco de clic del fotograma y de auto_answer de los ensayos.
var input_right_held_query: Callable

func input_right_held() -> bool:
	return bool(input_right_held_query.call()) if input_right_held_query.is_valid() else false


var auto_answer := -1
## Scene9 de Yugi: f3 consulta el ratón y f7 espera su máscara, sin respuestas automáticas.
var tutorial_interactive := false
var tutorial_pick_mask := 0
var _answer_visits := {}


## Respuesta que se da a un cuadro de dialogo con auto_answer activo.
func scripted_answer() -> int:
	if auto_answer != AUTO_SCRIPT:
		return auto_answer
	var forward: Array[int] = []
	var backward: Array[int] = []
	var i := _incoming_pos
	while i < _incoming.size() and (_incoming[i][0] & 0xfff) != 0xf8:
		if (_incoming[i][0] & 0xfff) in [0xf5, 0xfb, 0xfa, 0xf9]:
			break
		i += 1
	while i < _incoming.size() and (_incoming[i][0] & 0xfff) == 0xf8:
		var label := _incoming[i][1]
		var label_at := -1
		for j in _incoming.size():
			if _incoming[j][0] == 0xfa and _incoming[j][1] == label:
				label_at = j
				break
		(forward if label_at > i else backward).append(_incoming[i][2])
		i += 1
	var through := 0
	while through in forward or through in backward:
		through += 1
	var options: Array[int] = []
	options.append_array(forward)
	options.append(through)
	options.append_array(backward)
	var visits: int = _answer_visits.get(_incoming_pos, 0)
	_answer_visits[_incoming_pos] = visits + 1
	return options[visits % options.size()]


## Transporte del duelo en red (D17): lo pone la escena (autoload Lan) o una prueba. Objeto con
## send(paquete: PackedByteArray) -> bool, receive() -> PackedByteArray (vacio si no hay nada) y
## active() -> bool. Paquete = tipo u16 + datos, como el que arma 53ea40. Sin transporte el envio
## se descarta (5808b0 de Yugi/Kaiba) y la sesion cuenta como perdida (583e00 = 0).
var net: Object = null

## Decision pendiente del jugador humano (la pide el motor, la da la escena). Ver ui_request().
var ui_pending := {}
var _ui_answer := -1

## Entrada de interfaz que el original lee de sus objetos visuales (DAT_005af708 y el objeto de
## raton DAT_005af864). La escena la rellena antes de cada fotograma con set_frame_input().
## Carta visual bajo el cursor: el original devuelve su campo +0x10 (0 = ninguna). FUN_005407b0.
var ui_hover_card := 0
## Hay un objeto (carta, mazo...) bajo el cursor: byte +5 del estado de entrada. FUN_005407e0.
var ui_hover_object := false
## Ficha del panel de fases bajo el cursor (0-5) o -1. FUN_00460f80.
var ui_phase_hover := -1
## Clic izquierdo del objeto de raton en este fotograma (vtable +0x2c de DAT_005af864).
var ui_mouse_click := false
## Clic derecho del objeto de raton (vtable +0x08 de DAT_005af864): respuesta por defecto.
var ui_mouse_right := false
## Accion que muestra el cursor (FUN_00540b90/bb0: 0 = ninguna, accion + 1).
var cursor_action := 0
## Cuadro de dialogo abierto que espera respuesta (tipo, mensaje, argumento). Mientras existe,
## el bucle del duelo no avanza, como cuando la ventana del original esta activa.
var dialog_open := {}
## DAT_005aa1b4: ayuda pedida en este fotograma (FUN_004437a0) o -1.
var help_index := -1
var _dialog_msg := 0
## Ventana de la lista de seleccion (FUN_0042e820) que creo FUN_00407580 en la misma ranura
## que los cuadros (DAT_005af76c+0x11ec). Mientras existe, FUN_00540db0 devuelve 1 y el bucle
## del duelo no avanza. {"p", "loc", "mode"}: modo in_ECX[0xd] (0 solo ver, se cierra con el
## clic derecho; 1 elegir una entrada; 2/3 marcar hasta min(n, 5)). "closing" = la escena ya
## la cerro (FUN_0042fda0) y esta en la animacion de cierre. La escena escribe la eleccion con
## las funciones originales (f4073a0, f407540) y la cierra con list_close() y list_gone().
var list_open := {}
## Modo de cursor de teclado (DAT_005af868 + 0x40, FUN_005407a0): FUN_005798a0 parte entonces
## de la posicion guardada (0xa161b0/b4/b8) y no de la del objeto bajo el raton.
var ui_key_cursor := false
## Sustituciones del texto del cuadro, en el orden en que el original las aplica:
## {"card": indice} (FUN_0053fac0 con FUN_00401010: nombre de la carta en el primer "%s"),
## {"msg": id} (FUN_0053fac0 con un id pequeno: el texto del mensaje id en el primer "%s") y
## {"d": n} (FUN_0053fb40: el numero n en el primer "%d"), {"append": id} (FUN_0053f9f0 con
## "<BR>" y el mensaje id al final) y {"prefix_break": true} (el texto empieza por "<BR>").
var _dialog_subs: Array = []


## FUN_0053fac0/FUN_0053fb40 + FUN_005417e0: pide el cuadro con el mensaje `msg` formado con
## `subs` (ver _dialog_subs). Formar la cadena es presentacion: el nucleo guarda el mensaje y
## las sustituciones; la escena compone el texto.
func dialog_format(msg: int, subs: Array) -> void:
	call("f5417e0", msg)
	_dialog_subs = subs.duplicate(true)


## Sustituciones listas para la escena: los indices de carta pasan a id de carta.
func dialog_subs_for_scene() -> Array:
	var out: Array = []
	for s: Dictionary in _dialog_subs:
		if s.has("card"):
			out.append({"card": cards.id_of(int(s["card"]))})
		else:
			out.append(s.duplicate())
	return out


## Entrada de un fotograma. `pressed` va a 0xa114a8 (0x200 clic izquierdo, 0x100 clic derecho,
## 1 decidir, 2 cancelar con teclado) y `held` a 0xa114a4. El cursor (jugador, ubicacion,
## posicion) va a 0xa161a4/a8/ac solo si hay un objeto debajo, como en FUN_005407f0.
func set_frame_input(pressed: int, held: int, hover: Dictionary, phase_hover: int) -> void:
	m.set_u32(0xa114a8, pressed)
	m.set_u16(0xa114a4, held)
	ui_hover_object = not hover.is_empty()
	ui_hover_card = int(hover.get("card", 0))
	if ui_hover_object:
		m.set_u32(0xa161a4, int(hover["p"]) & 1)
		m.set_u32(0xa161a8, int(hover["loc"]) & 0xf)
		m.set_u32(0xa161ac, int(hover["i"]) & 0x1ff)
	ui_phase_hover = phase_hover
	ui_mouse_click = (pressed & 0x200) != 0
	ui_mouse_right = (pressed & 0x100) != 0


## FUN_0042fda0 sobre la ventana de la lista: FUN_00540d80(valor) y, por la vtable +0x28
## (0x42d8a0), FUN_00540d80(0). La ventana sigue ocupando la ranura (el motor sigue parado)
## durante la animacion de cierre, hasta list_gone().
func list_close(value: int) -> void:
	if list_open.is_empty() or list_open.get("closing", false):
		return
	list_open["closing"] = true
	call("f540d80", value)
	call("f540d80", 0)


## Fin de la animacion de cierre (0x42ff70: +0x14 < -0xff pone a 0 el byte +4): la ranura
## queda libre y FUN_00540db0 deja de bloquear.
func list_gone() -> void:
	list_open = {}


## La escena contesta el cuadro de dialogo abierto (FUN_0042fda0 -> FUN_00540d80).
func answer_dialog(value: int) -> void:
	if dialog_open.is_empty():
		return
	dialog_open = {}
	call("f540d80", value)
## Respuesta al iniciar el cierre: la ranura sigue ocupada hasta +0x14 < -255.
## answer_dialog conserva la respuesta inmediata usada por simulaciones sin ventana.
func dialog_close(value: int) -> void:
	if dialog_open.is_empty() or dialog_open.get("closing", false):
		return
	dialog_open["closing"] = true
	call("f540d80", value)


func dialog_gone() -> void:
	dialog_open = {}


## Funciones del original que se llamaron sin estar portadas: direccion -> veces.
var unported_calls := {}
var _original_arities := {}


func _init(tables: CardTables) -> void:
	cards = tables


# --- Comando en curso -----------------------------------------------------------------

func cmd_op() -> int:
	return m.u16(DuelMem.CMD)


func cmd_player() -> int:
	return m.u16(DuelMem.CMD) >> 15


func cmd_a() -> int:
	return m.u16(DuelMem.CMD + 2)


func cmd_b() -> int:
	return m.u16(DuelMem.CMD + 4)


func cmd_c() -> int:
	return m.u16(DuelMem.CMD + 6)


## Paso de la maquina de estados del comando (bits 0-6 de 0xa1572c).
func step() -> int:
	return m.u32(DuelMem.CMD_STATE) & 0x7f


## state ^ ((state + 1) ^ state) & 0x7f: avanza el paso sin tocar el resto de bits.
func next_step() -> void:
	var s := m.u32(DuelMem.CMD_STATE)
	m.set_u32(DuelMem.CMD_STATE, s ^ (((s + 1) ^ s) & 0x7f))


func set_step(value: int) -> void:
	var s := m.u32(DuelMem.CMD_STATE)
	m.set_u32(DuelMem.CMD_STATE, (s & ~0x7f) | (value & 0x7f))


## state &= 0xefffffff: el comando ha terminado.
func finish() -> void:
	m.set_u32(DuelMem.CMD_STATE, m.u32(DuelMem.CMD_STATE) & 0xefffffff)


func is_running() -> bool:
	return (m.u32(DuelMem.CMD_STATE) & DuelMem.CMD_RUNNING) != 0


## Bits 12-13 de 0xa114b4.
func duel_mode() -> int:
	return (m.u32(0xa114b4) >> 12) & 3


func commands_from_outside() -> bool:
	var mode := duel_mode()
	return mode == MODE_REPLAY or mode == MODE_NETWORK


# --- Cola de comandos -------------------------------------------------------------------

## FUN_0053aa70: emite un comando. En repeticion o red no hace nada (llegan de fuera).
func issue(op: int, a: int, b: int, c: int) -> void:
	if commands_from_outside():
		return
	match op & 0xfff:
		0x60:
			a = rng.rand()
			b = a >> 16
		0x64, 0x65, 0x66, 0x67, 0x68, 0x6a, 0x6b, 0x7d, 0x7e, 0xc2, 0xcb, 0xd2, 0xd3, 0xd4, \
				0xd7, 0xdb, 0xdc, 0xdd, 0xde:
			a = (a & ~0xfff) | (cards.id_of(a & 0xfff) & 0xfff)
		0x71, 0x77, 0xa6, 0xaa:
			b = (b & ~0xfff) | (cards.id_of(b & 0xfff) & 0xfff)
	enqueue(op, a, b, c)
	recorded.append(PackedInt32Array([op & 0xffff, a & 0xffff, b & 0xffff, c & 0xffff]))


## FUN_0053ac40: anade un comando a la cola sin grabarlo.
func enqueue(op: int, a: int, b: int, c: int) -> void:
	var n := m.u16(DuelMem.QUEUE_COUNT)
	if n >= DuelMem.QUEUE_MAX:
		return
	var at := DuelMem.QUEUE + n * 8
	m.set_u16(at, op)
	m.set_u16(at + 2, a)
	m.set_u16(at + 4, b)
	m.set_u16(at + 6, c)
	m.set_u16(DuelMem.QUEUE_COUNT, n + 1)


## FUN_0053db50(0): pasa el siguiente comando de la repeticion a la cola; si no quedan,
## marca la repeticion como agotada (bit 14 de 0xa114b4).
func fetch_incoming() -> void:
	if _incoming_pos >= _incoming.size():
		m.set_u8(0xa114b5, m.u8(0xa114b5) | 0x40)
		return
	var c := _incoming[_incoming_pos]
	_incoming_pos += 1
	enqueue(c[0], c[1], c[2], c[3])


func incoming_left() -> int:
	return _incoming.size() - _incoming_pos


## FUN_0053b4e0: ejecuta comandos. Devuelve true si hay trabajo en curso.
## Sub-estado en el byte 0xa13412: 0 tomar comando, 1 ejecutar, 2 despues de ejecutar.
func exec_commands() -> bool:
	if dispatch_animation_mailbox():
		return true
	var phase := m.u8(0xa13412)
	if phase == 0:
		var n := m.u16(DuelMem.QUEUE_COUNT)
		if n == 0:
			return false
		command_popping.emit()
		m.copy(DuelMem.CMD, DuelMem.QUEUE, 8)
		n -= 1
		m.set_u16(DuelMem.QUEUE_COUNT, n)
		if n > 0:
			m.copy(DuelMem.QUEUE, DuelMem.QUEUE + 8, n * 8)
		m.set_u32(0xa15a44, m.u32(0xa15a44) | 0x4000)
		m.set_u32(DuelMem.CMD_STATE, m.u32(DuelMem.CMD_STATE) | DuelMem.CMD_RUNNING)
		# (bit 8 de 0xa16180: duelo en red, el original envia aqui el comando al rival)
		m.set_u32(DuelMem.CMD_STATE, m.u32(DuelMem.CMD_STATE) & 0xf01fc000)
		executed += 1
		phase = 1
		m.set_u8(0xa13412, phase)
	if phase == 1:
		dispatch()
		if is_running():
			return true
		phase = 2
		m.set_u8(0xa13412, phase)
	if phase != 2:
		return false
	if (m.u32(0xa15a44) & 0x4000) != 0:
		m.set_u16(0xa15942, 0)
		m.set_u8(0xa13412, 0)
		if commands_from_outside() and not is_running():
			if m.u16(DuelMem.QUEUE_COUNT) != 0:
				return true
			fetch_incoming()
		if m.u16(DuelMem.QUEUE_COUNT) == 0:
			return false
	return true


## Despachador (FUN_0053aca0); lo implementa DuelCmds.
func dispatch() -> void:
	finish()


## El motor necesita que el jugador humano decida algo que en el original se lee de la
## interfaz (cursor, menu de la carta, botones, lista de seleccion). `kind` describe la
## decision y `data` las opciones. Mientras no haya respuesta devuelve -1 y la rutina debe
## comportarse como el original mientras la interfaz espera (normalmente, volver sin avanzar).
## La escena responde con ui_answer(valor); el valor es el que el original obtendria de la
## interfaz.
func ui_request(kind: String, data := {}) -> int:
	if _ui_answer != -1 and ui_pending.get("kind", "") == kind:
		var v := _ui_answer
		_ui_answer = -1
		ui_pending = {}
		return v
	if ui_pending.is_empty():
		data["kind"] = kind
		ui_pending = data
		present("ui_request", data.duplicate())
	return -1


func ui_answer(value: int) -> void:
	_ui_answer = value


## Cuerpo de las declaraciones de funciones aun no portadas (duel_decl.gd).
## Termina el comando en curso para que la prueba siga y liste todo lo que falta.
func _unported(addr: int) -> int:
	unported_calls[addr] = unported_calls.get(addr, 0) + 1
	finish()
	return 0


## Las tablas del ejecutable llaman rutinas C que pueden ignorar argumentos sobrantes.
## GDScript exige la aridad exacta: solo se recortan los sobrantes, nunca se inventan datos.
## Solo pruebas: si no es null, invoke_original anota cada direccion invocada por tabla.
var invoke_log = null


func invoke_original(addr: int, arguments: Array = []) -> int:
	if invoke_log != null: invoke_log.append(addr)
	var name := "f%06x" % (addr & 0xffffff)
	if _original_arities.is_empty():
		for method in get_method_list():
			var method_name: String = method["name"]
			if method_name.begins_with("f") and method_name.length() == 7:
				_original_arities[method_name] = method["args"].size()
	if not _original_arities.has(name):
		present("unported_function", {"address": addr, "reason": "sin declaracion"})
		return _unported(addr)
	var needed: int = _original_arities[name]
	if arguments.size() < needed:
		present("unported_function", {"address": addr, "reason": "faltan argumentos", "needed": needed, "provided": arguments.size()})
		return _unported(addr)
	return int(callv(name, arguments.slice(0, needed)))


# --- Presentacion -------------------------------------------------------------------------

## Lectura de objetos 413170 (campo) / 412f20 (pilas), campo +0x10.
## La presentacion devuelve -1 si no existe objeto, 0 si existe objeto con indice vacio.
## Sin presentacion se conserva la proyeccion logica para simulaciones headless.
var card_visual_query := Callable()

## 413250: espera los objetos de cartas. Se conecta al abrir una mesa animada.
var card_objects_busy_query := Callable()
var _animation_request: Dictionary = {}

func animation_request_pending() -> bool:
	return card_objects_busy_query.is_valid() and animation_mailbox.pending()


func dispatch_animation_mailbox() -> bool:
	if not animation_request_pending(): return false
	return animation_mailbox.dispatch({0x4079c0: _dispatch_card_turn, 0x407a60: _dispatch_card_motion,
		0x407cb0: _dispatch_card_motion, 0x407df0: _dispatch_card_motion, 0x407e40: _dispatch_card_motion})


## 4077f0 (Kaiba 407a90): jugador, zona, posición y cara en cuatro bytes.
func present_card_turn(kind: int, p: int, z: int, flags: int, reveal := 0) -> void:
	if not card_objects_busy_query.is_valid():
		present("change_position" if kind == 1 else "flip", {"p": p, "zone": z, "flags": flags, "b": reveal})
		return
	var target := ((flags ^ 1) | (2 if reveal != 0 else 0)) if kind == 1 else flags ^ 2
	var payload := (p & 1) | ((z & 15) << 8) | ((target & 1) << 16) | ((target & 2) << 23)
	animation_mailbox.f4077f0(kind, payload)


static func animation_location(p: int, loc: int, index := 0, flags := 0) -> int:
	return (p & 1) | ((loc & 15) << 1) | ((index & 511) << 5) | ((flags & 3) << 14)


static func animation_field_location(p: int, zone: int, flags := 0) -> int:
	var group := zone - zone % 5
	return animation_location(p, group, zone % 5, flags)


## 407830/407880/4078d0/407920. El consumidor lee las dos ubicaciones
## del buzón. El evento conserva el contexto gráfico particular del comando.
func present_card_motion(request: int, index: int, source: int, destination: int, event: String, data: Dictionary) -> void:
	if not card_objects_busy_query.is_valid():
		present(event, data)
		return
	var locations := m.local(4)
	m.set_u16(locations, source)
	m.set_u16(locations + 2, destination)
	match request:
		3: animation_mailbox.f407830(index, locations, locations + 2)
		4: animation_mailbox.f407880(index, locations, locations + 2)
		5: animation_mailbox.f4078d0(index, locations + 2)
		6: animation_mailbox.f407920(locations, locations + 2)
	_animation_request = {"event": event, "data": data}


func _dispatch_card_motion(mailbox: RefCounted) -> void:
	var phase := m.u8(mailbox.PHASE)
	var travel: bool = mailbox.kind() == 3
	if travel and phase == 0:
		var source := m.u16(mailbox.SOURCE)
		var index := m.u16(mailbox.PAYLOAD)
		if ((source >> 1) & 15) == DuelMem.LOC_GRAVE and visual_card_index(source & 1, DuelMem.LOC_GRAVE) != index:
			# 407a60: eleva la carta y deja pasar el cambio de cima antes de retirarla.
			call("f544890", source & 1, index)
			present("grave_top", {"p": source & 1, "card": cards.id_of(index)})
			m.set_u8(mailbox.PHASE, 1)
			return
		phase = 0x10
		m.set_u8(mailbox.PHASE, phase)
	if travel and phase < 0x10:
		m.set_u8(mailbox.PHASE, phase + 1)
	elif phase == (0x10 if travel else 0):
		if travel and card_objects_busy_query.call(): return
		m.set_u8(mailbox.PHASE, phase + 1)
		var data: Dictionary = _animation_request["data"]
		data["source_word"] = m.u16(mailbox.SOURCE)
		data["destination_word"] = m.u16(mailbox.DESTINATION)
		data["from_mailbox"] = true
		present(_animation_request["event"], data)
	elif not card_objects_busy_query.call():
		mailbox.acknowledge()
		_animation_request = {}


func _dispatch_card_turn(mailbox: RefCounted) -> void:
	if m.u8(mailbox.PHASE) == 0:
		m.set_u8(mailbox.PHASE, 1)
		var payload := m.u32(mailbox.PAYLOAD)
		present("change_position" if mailbox.kind() == 1 else "flip", {
			"p": payload & 1, "zone": (payload >> 8) & 15,
			"native_target_flags": ((payload >> 16) & 1) | ((payload >> 23) & 2),
			"from_mailbox": true})
	elif not card_objects_busy_query.call():
		mailbox.acknowledge()


## 442130: posición actual de la carta, usada por la navegación horizontal.
var card_screen_position_query := Callable()

func card_screen_position(p: int, loc: int, i: int) -> Vector2:
	if card_screen_position_query.is_valid(): return card_screen_position_query.call(p, loc, i)
	var count := m.u8(DuelMem.pl(p & 1) + DuelMem.P_HAND_N)
	if loc == 11 and i >= count: return Vector2(525, 600 if p == 0 else 0)
	return DuelGeometry.location(p, loc, i, count)

## Proyeccion sin presentacion de los objetos que 0x78 deja en su zona tras retirar el indice
## logico ("p:z" -> indice). En el original el objeto sigue en la mesa hasta que un comando lo
## mueve: 0x79 sobre esa zona lo encuentra (413170) y la vacia. Se olvida al vaciar la zona
## (542c40) o al mover la carta desde ella (eventos zone_*/field_*).
var headless_detached := {}

func visual_card_index(p: int, loc: int) -> int:
	if card_visual_query.is_valid():
		return int(card_visual_query.call(p, loc))
	if loc >= 0 and loc < 11:
		var index := m.u16(DuelMem.zone(p, loc)) & 0xfff
		if index == 0: return int(headless_detached.get("%d:%d" % [p & 1, loc], -1))
		return index
	if loc == 14:
		var count := m.u8(DuelMem.pl(p) + DuelMem.P_GRAVE_N)
		return m.u16(DuelMem.pl(p) + DuelMem.P_GRAVE + (count - 1) * 4) & 0xfff if count > 0 else 0
	return -1


## Las esperas de animacion (FUN_00403c70 y similares) siempre terminan al momento en el
## nucleo; la escena del duelo reproduce los eventos con sus propios tiempos.
func anim_busy() -> bool:
	return false


## 4138b0: espera 413250 y también los cuatro objetos de pila de cada jugador.
func card_and_pile_objects_busy() -> bool:
	if card_objects_busy_query.is_valid(): return bool(card_objects_busy_query.call(true))
	return anim_busy()


func present(kind: String, data := {}) -> void:
	if (kind.begins_with("zone_") or kind.begins_with("field_to")) and data.has("zone"):
		headless_detached.erase("%d:%d" % [int(data.get("p", 0)) & 1, int(data["zone"])])
	data["kind"] = kind
	data["cmd"] = executed
	events.append(data)


## Comprobacion de pruebas: el comando dice que la carta es `expected_id` y el estado
## tiene `entry` (u32 con el indice en los 12 bits bajos).
func expect_card(expected_id: int, entry: int, what: String) -> void:
	var got := cards.id_of(entry & 0xfff)
	if got != (expected_id & 0xffff):
		mismatches.append("cmd %d op 0x%02x: %s es %d y el comando dice %d" % [
				executed, cmd_op() & 0xfff, what, got, expected_id])
