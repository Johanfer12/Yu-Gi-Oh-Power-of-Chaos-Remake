extends RefCounted
## Formato y despacho del buzón clásico en la memoria normalizada del duelo.
const FLAGS := 0xa161ca
const PHASE := FLAGS + 1
const PAYLOAD := 0xa161cc
const SOURCE := 0xa161d0
const DESTINATION := 0xa161d2
const HANDLERS := {1:0x4079c0, 2:0x4079c0, 3:0x407a60, 4:0x407cb0, 5:0x407df0, 6:0x407e40}
var m: DuelMem
func _init(memory: DuelMem) -> void: m = memory

##4077f0: u32 entero y tipo truncado7bits. Todos los escritores reinician +cb.
func f4077f0(kind: int, payload: int) -> void:
	m.set_u32(PAYLOAD, payload)
	m.set_u16(FLAGS, ((kind << 1) & 0xfe) | 1)

##407830/407880 reciben punteros a ubicaciones compactas u16, no indices de zona.
func f407830(card_index: int, source_pointer: int, destination_pointer: int) -> void:
	_post_card(7, card_index, source_pointer, destination_pointer)
func f407880(card_index: int, source_pointer: int, destination_pointer: int) -> void:
	_post_card(9, card_index, source_pointer, destination_pointer)
func _post_card(flags: int, card_index: int, source_pointer: int, destination_pointer: int) -> void:
	m.set_u32(PAYLOAD, card_index & 0xffff)
	_post_locations(flags, source_pointer, destination_pointer)

func f4078d0(card_index: int, location_pointer: int) -> void:
	_post_card(0xb, card_index, location_pointer, location_pointer)

##407920 conserva PAYLOAD anterior.
func f407920(source_pointer: int, destination_pointer: int) -> void:
	_post_locations(0xd, source_pointer, destination_pointer)

func _post_locations(flags: int, source_pointer: int, destination_pointer: int) -> void:
	# ASM conserva fase y pending hasta las ultimas escrituras (importa con alias).
	m.set_u16(FLAGS, (m.u16(FLAGS) & (0xff00 | flags)) | (flags & 0xfe))
	m.set_u16(SOURCE, m.u16(source_pointer))
	var destination := m.u16(destination_pointer)
	m.set_u8(FLAGS, m.u8(FLAGS) | 1)
	m.set_u16(DESTINATION, destination)
	m.set_u8(PHASE, 0)

func pending() -> bool: return (m.u8(FLAGS) & 1) != 0
func kind() -> int: return m.u8(FLAGS) >> 1
func acknowledge() -> void: m.set_u8(FLAGS, m.u8(FLAGS) & 0xfe)

##407f00 devuelve1 aunque el handler borre pending en ese tick.
##El handler gobierna PHASE y acknowledge; despachar no consume automaticamente.
func dispatch(handlers: Dictionary) -> bool:
	if not pending(): return false
	var operation := kind()
	if operation == 7: return true
	if not HANDLERS.has(operation): return false
	var handler: Callable = handlers.get(HANDLERS[operation], Callable())
	if handler.is_valid(): handler.call(self)
	return true
