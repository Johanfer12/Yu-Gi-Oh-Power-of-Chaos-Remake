class_name JoeyBase
extends JoeyFrontier
## Base del motor de duelo nativo de Joey (docs/duel/PLAN_MOTOR_JOEY.md, etapa 0): memoria
## nativa, lectores de las tablas de cartas (bloque K), RNG, cola de comandos y frontera de
## presentacion. Las rutinas se llaman f<direccion de Joey_Pc.exe>, como en el motor de Yugi.
##
## Frontera de presentacion: JoeyFrontier (generada por re/scripts/joey_frontier.py) emite como
## evento lo que el original pinta, suena o espera, con el mismo valor para las reglas.

const IMAGE_FILE := "common/duel/joey_image.bin"

var m := JoeyMem.new()

## Consulta optativa del renderer: espera de objetos de presentacion, no reglas.
## El contrato sin pantalla conserva el valor por defecto (ningun objeto ocupado).
var visual_busy_query: Callable
var visual_busy_site := 0
## Objetos propiedad del renderer: {} si no existe; {exists,index,ref} si existe.
## kind es card (41cee0) o pile (41cf60). No se derivan cartas de las reglas.
var visual_object_query: Callable
## Estado del widget de fase y ficha bajo el raton, propiedad del renderer.
var visual_phase_hover_query: Callable
const _VISUAL_ARENA := JoeyMem.STACK + JoeyMem.STACK_SIZE
const _VISUAL_OBJECT_SIZE := 0x40
const _VISUAL_OBJECT_MAX := 512
var _visual_object_slots: Dictionary = {}


func visual_busy(kind: String, player: int = 0, zone: int = 0, native_site: int = 0) -> bool:
	var previous := visual_busy_site
	visual_busy_site = native_site
	var result := bool(visual_busy_query.call(kind, player, zone)) if visual_busy_query.is_valid() else false
	visual_busy_site = previous
	return result


## Entrada del escaneo de cursor del renderer (44dbc0): comienza otro ciclo
## de reconocimiento. 4182d0 marca este byte al consumir un boton del jugador.
func visual_reset_input_ack() -> void:
	m.set_u8(0x5f2fe0, 0)


## 41b050: metodo +0x24 del objeto de detalle (5f3280+0x3c); guarda el indice de la carta en
## +0x10 y el panel la muestra. Lo llaman los comandos que ponen una carta en juego o la activan
## (4061b0, 4063e0, 4067d0, 406b20, 407120, 407160, 40a3c0, 40aa40) y el cursor (44dbc0).
func f41b050(index: int) -> int:
	present("41b050", {"args": [index]})
	return 0


func _visual_object_from_renderer(kind: String, player: int, area: int, index: int) -> int:
	if not visual_object_query.is_valid():
		return 0
	var value: Variant = visual_object_query.call(kind, player, area, index)
	if not value is Dictionary or value.is_empty() or not bool(value.get("exists", true)):
		return 0
	var key := "%s/%d/%d/%d" % [kind, player, area, index]
	if not _visual_object_slots.has(key):
		if _visual_object_slots.size() >= _VISUAL_OBJECT_MAX:
			push_error("Demasiados objetos de presentacion proyectados")
			return 0
		_visual_object_slots[key] = _VISUAL_ARENA + _visual_object_slots.size() * _VISUAL_OBJECT_SIZE
		var size := _VISUAL_ARENA - JoeyMem.BASE + _VISUAL_OBJECT_MAX * _VISUAL_OBJECT_SIZE
		if m.bytes.size() < size:
			m.bytes.resize(size)
	var pointer := int(_visual_object_slots[key])
	m.clear(pointer, _VISUAL_OBJECT_SIZE)
	m.set_u32(pointer + 0x10, int(value.get("index", 0)))
	m.set_u16(pointer + 0x24, int(value.get("ref", 0)))
	return pointer


## Bufer pasado a una rutina diferida (5bd090): sus bytes, para el evento del oraculo.
func _deferred_bytes(address: int, size: int) -> String:
	if size <= 0 or size >= 0x1000:
		return ""
	return m.bytes.slice((address & 0xffffffff) - JoeyMem.BASE, (address & 0xffffffff) - JoeyMem.BASE + size).hex_encode()
var cards: CardTables
## rand()/srand() del CRT (5c3c02/5c3bf5): mismo algoritmo que MsvcRand (cotejado).
var rng := MsvcRand.new()
## Argumentos de entrada de cada llamada a 5b9170 (opcode, a, b, c), como los anota el oraculo.
var recorded: Array[PackedInt32Array] = []


func _init(tables: CardTables) -> void:
	cards = tables


## Carga la imagen nativa y los globales de arranque de la aplicacion.
func load_data(data_dir: String) -> bool:
	var image := FileAccess.get_file_as_bytes(data_dir.path_join(IMAGE_FILE))
	if image.is_empty() or not m.load_image(image):
		return false
	init_application()
	return true


static func s16(v: int) -> int:
	v &= 0xffff
	return v - 0x10000 if v >= 0x8000 else v


# --- K: lectores de las tablas de cartas (402290-402fb0) ----------------------------------
# Cargan data/bin/CARD_*.bin la primera vez (402340): en el port, CardTables.

## FUN_004022e0: id de la carta del indice; 0xffff por encima de 0x45b.
func f4022e0(index: int) -> int:
	index &= 0xffff
	if index > 0x45b or index >= cards.ids.size():
		return 0xffff
	return cards.ids[index]


## FUN_00402460: indice del id. Por encima de 3999 deja a 0 la mitad baja de EAX (los
## llamadores solo usan el ushort).
func f402460(card_id: int) -> int:
	card_id &= 0xffff
	if card_id > 3999:
		return 0
	return cards.int_ids[card_id % 2000] + int(card_id > 1999)


## FUN_004024e0: paquete del indice (card_pack.bin; 1 Yugi, 2 Kaiba, 4 Joey).
func f4024e0(index: int) -> int:
	index &= 0xffffffff
	return cards.packs[index] if index < cards.packs.size() else 0


## FUN_004025f0: propiedades del indice (indice & 0x7ff).
func f4025f0(index: int) -> int:
	return cards.prop(index & 0x7ff)


## FUN_004025d0: tipo (bits 20-24): < 0x15 monstruo, 0x15 trampa, 0x16 magia.
func f4025d0(index: int) -> int:
	return (f4025f0(index) >> 0x14) & 0x1f


## FUN_00402650: atributo (bits 29-31); 9 las trampas y 8 las magias.
func f402650(index: int) -> int:
	var kind := s16(f4025d0(index))
	if kind == 0x15:
		return 9
	if kind == 0x16:
		return 8
	return f4025f0(index) >> 0x1d


## FUN_00402690: 1 si es monstruo (tipo distinto de 0 y menor que 0x15).
func f402690(index: int) -> int:
	if s16(f4025d0(index)) != 0 and (f4025d0(index) & 0xffff) < 0x15:
		return 1
	return 0


## FUN_004026c0: nivel (bits 25-28); 0 en magias/trampas/0x17 y 10 en el tipo 0x18.
func f4026c0(index: int) -> int:
	var kind := f4025d0(index) & 0xffff
	if kind > 0x14:
		if kind < 0x18:
			return 0
		if kind == 0x18:
			return 10
	return (f4025f0(index) >> 0x19) & 0xf


## FUN_00402700: subtipo de magia/trampa (bits 17-19); 0 en el resto.
func f402700(index: int) -> int:
	var kind := f4025d0(index) & 0xffff
	if kind > 0x14 and kind < 0x17:
		return (f4025f0(index) >> 0x11) & 7
	return 0


## FUN_00402740: clase de marco: 3 para 0x776, 1 para 0x777-0x778, 8 trampa, 7 magia,
## 9 tipo 0x17 y bits 18-19 en monstruos.
func f402740(index: int) -> int:
	var card_id := f4022e0(index) & 0xffff
	if card_id == 0x776:
		return 3
	if card_id > 0x776 and card_id < 0x779:
		return 1
	var kind := s16(f4025d0(index))
	if kind == 0x15:
		return 8
	if kind == 0x16:
		return 7
	if kind == 0x17:
		return 9
	return (f4025f0(index) >> 0x12) & 3


## FUN_004027b0: ATK base (bits 9-17 x 10); 0 en magias/trampas/0x17 y 4000 en 0x18.
func f4027b0(index: int) -> int:
	var kind := f4025d0(index) & 0xffff
	if kind > 0x14:
		if kind < 0x18:
			return 0
		if kind == 0x18:
			return 4000
	return ((f4025f0(index) >> 9) & 0x1ff) * 10


## FUN_00402800: DEF base (bits 0-8 x 10), con las mismas excepciones que el ATK.
func f402800(index: int) -> int:
	var kind := f4025d0(index) & 0xffff
	if kind > 0x14:
		if kind < 0x18:
			return 0
		if kind == 0x18:
			return 4000
	return (f4025f0(index) & 0x1ff) * 10


# --- Cola de comandos ---------------------------------------------------------------------

## FUN_005b9170: emite un comando. En repeticion (modo & 0x180 == 0x80) no hace nada. Traduce
## a id los indices de los argumentos que el original guarda como id, roba la semilla de 0x60
## con rand() y lo anade a la cola si cabe. 449d50 (escucha de la presentacion) es un evento.
func f5b9170(op: int, a: int, b: int, c: int) -> int:
	recorded.append(PackedInt32Array([op & 0xffff, a & 0xffff, b & 0xffff, c & 0xffff]))
	if (m.u32(JoeyMem.MODE) & 0x180) == 0x80:
		return 0
	op &= 0xffff
	match op & 0xfff:
		0x60:
			a = rng.rand()
			b = a >> 16
		0x64, 0x65, 0x66, 0x67, 0x68, 0x6a, 0x6b, 0x7d, 0x7e, 0xc2, 0xcb, 0xd2, 0xd3, 0xd4, \
				0xd7, 0xdc, 0xdd, 0xde:
			a = (f4022e0(a & 0xfff) & 0xfff) | (a & 0xf000)
		0x71, 0x77, 0xa5, 0xa6, 0xaa:
			b = (f4022e0(b & 0xfff) & 0xfff) | (b & 0xf000)
	var command := PackedInt32Array([op, a & 0xffff, b & 0xffff, c & 0xffff])
	var n := m.u16(JoeyMem.QUEUE_COUNT)
	if n < JoeyMem.QUEUE_MAX:
		var at := JoeyMem.QUEUE + n * 8
		for i in 4:
			m.set_u16(at + i * 2, command[i])
		m.set_u16(JoeyMem.QUEUE_COUNT, n + 1)
	var copy := m.local(8)
	for i in 4:
		m.set_u16(copy + i * 2, command[i])
	f449d50(copy)
	return 0


# --- Arranque del duelo -------------------------------------------------------------------
# Globales de la aplicacion fuera del estado del duelo que lee el motor.

## Version nativa (44baa0): el arranque la deriva del PE como (u32 5eb600 + 11) * 100 = 1300.
const VERSION := 0x5f3284
## Tipo de partida (44b980 / 5bfeb0): 3 red, 4 demostracion, 7 ...
const GAME_KIND := 0x5f3294
## Mazos de la partida: 0xe2 bytes por lado (local y rival); principal u16[80] en +0,
## fusion u16[15] en +0xbe, contadores en +0xdc (principal) y +0xe0 (fusion).
const DECKS := 0xa54e60
const DECK_SIZE := 0xe2

## Valores que el arranque de la aplicacion deja antes del duelo.
func init_application() -> void:
	m.set_u32(VERSION, (m.u32(0x5eb600) + 11) * 100)


## FUN_0044baa0: version nativa.
func f44baa0() -> int:
	return m.u32(VERSION)


## FUN_0044b980: 1 en partida de red.
func f44b980() -> int:
	return int(m.u32(GAME_KIND) == 3)


## FUN_005bddf0: memset(direccion, 0, tamano).
func f5bddf0(address: int, size: int) -> int:
	m.clear(address, size)
	return 0


## Ficha (id 0x780-0x783 segun 4022e0 del indice). Lee 4022e0 dos veces, como los llamadores
## del original; el segundo valor solo se mira si el primero es >= 0x780.
func is_token(index: int) -> bool:
	if f4022e0(index) & 0xffff < 0x780:
		return false
	return f4022e0(index) & 0xffff <= 0x783


## FUN_005bde10: memcpy del CRT (dwords y luego bytes, hacia delante); devuelve el destino.
func f5bde10(dst: int, src: int, size: int) -> int:
	var i := 0
	while i + 4 <= size:
		m.set_u32(dst + i, m.u32(src + i))
		i += 4
	while i < size:
		m.set_u8(dst + i, m.u8(src + i))
		i += 1
	return dst


## FUN_005675d0: intercambia dos u32.
func f5675d0(a: int, b: int) -> int:
	var t := m.u32(a)
	m.set_u32(a, m.u32(b))
	m.set_u32(b, t)
	return 0


## FUN_005bddb0: numero en [0, n) con rand(): modulo antes de la version 1000, escalado despues.
func f5bddb0(n: int) -> int:
	if _s32(f44baa0()) < 1000:
		return _cdiv_rem(rng.rand(), n)
	return _cdiv(rng.rand() * n, 0x7fff)


## FUN_00568ed0: lleva la primera carta con ese id del mazo de p a una posicion al azar
## entre las `limit` primeras.
func f568ed0(p: int, card_id: int, limit: int) -> int:
	p &= 1
	var count := m.u8(JoeyMem.pl(p) + JoeyMem.P_DECK_N)
	if count == 0:
		return 0
	var deck := JoeyMem.pl(p) + JoeyMem.P_DECK
	var i := 0
	while s16(f4022e0(m.u16(deck + i * 4) & 0xfff)) != s16(card_id):
		i += 1
		if count <= i:
			return 0
	limit &= 0xffff
	if count <= limit:
		limit = count
	f5675d0(deck + f5bddb0(limit) * 4, deck + i * 4)
	return 0


## FUN_00568d80: baraja el mazo de p. Desde la version 1001, Fisher-Yates desde el final;
## antes, n * cartas intercambios al azar y, si p es local, coloca 0x10-0x14 entre las 20 primeras.
func f568d80(p: int, n: int) -> int:
	var q := p & 1
	var count := m.u8(JoeyMem.pl(q) + JoeyMem.P_DECK_N)
	if count == 0:
		return 0
	var deck := JoeyMem.pl(q) + JoeyMem.P_DECK
	if _s32(f44baa0()) < 0x3e9:
		var swaps := count * n
		while swaps > 0:
			var a := f5bddb0(count)
			var b := f5bddb0(count)
			f5675d0(deck + a * 4, deck + b * 4)
			swaps -= 1
		if (((m.u16(JoeyMem.MODE) >> 1) & 3) >> (p & 0x1f) & 1) != 0:
			for card_id in range(0x10, 0x15):
				f568ed0(1, card_id, 0x14)
		return 0
	var k := count
	while k > 0:
		f5675d0(deck + (k - 1) * 4, deck + f5bddb0(k) * 4)
		k -= 1
	return 0


## FUN_00569380: copia el mazo principal y el de fusion de p desde DECKS (el del lado local
## si p es el jugador local) a sus listas, con el propietario y, desde la version 1001, la
## identidad (bits 24-30) correlativa; deja la siguiente identidad en +6 del jugador.
func f569380(p: int) -> int:
	var local := int(p == ((~m.u16(JoeyMem.MODE)) & 1))
	var source := DECKS + local * DECK_SIZE
	var q := p & 1
	var pl := JoeyMem.pl(q)
	var identity := 1
	# Limpia con p sin enmascarar; el resto usa p & 1.
	f5bddf0(JoeyMem.PLAYER + p * JoeyMem.PLAYER_SIZE + JoeyMem.P_DECK, 0x140)
	m.set_u8(pl + JoeyMem.P_DECK_N, 0)
	for i in m.u16(source + 0xdc):
		var at := pl + JoeyMem.P_DECK + i * 4
		m.set_u32(at, (m.u16(source + i * 2) & 0xfff) | (m.u32(at) & 0xffffe000) | (q << 12))
		if _s32(f44baa0()) > 1000:
			m.set_u32(at, ((identity & 0x7f) << 24) | (m.u32(at) & 0x80ffffff))
			identity += 1
		m.set_u8(pl + JoeyMem.P_DECK_N, m.u8(pl + JoeyMem.P_DECK_N) + 1)
	m.set_u8(pl + JoeyMem.P_FUSION_N, 0)
	for i in m.u16(source + 0xe0):
		var at := pl + JoeyMem.P_FUSION + i * 4
		m.set_u32(at, (m.u16(source + 0xbe + i * 2) & 0xfff) | (m.u32(at) & 0xffffe000) | (q << 12))
		if _s32(f44baa0()) > 1000:
			m.set_u32(at, ((identity & 0x7f) << 24) | (m.u32(at) & 0x80ffffff))
			identity += 1
		m.set_u8(pl + JoeyMem.P_FUSION_N, m.u8(pl + JoeyMem.P_FUSION_N) + 1)
	# El original escribe aqui con p sin enmascarar (p * 0xd44).
	m.set_u16(JoeyMem.PLAYER + p * JoeyMem.PLAYER_SIZE + 6, identity)
	return 0


## FUN_005b9e50: limpia el estado del duelo, carga y baraja los mazos y pone 8000 LP.
func f5b9e50() -> int:
	f5bddf0(JoeyMem.PLAYER, 0x1ad4)
	f5bddf0(0xa55040, 0x34)
	f5bddf0(0xa582a0, 0x308)
	f5bddf0(0xa558b4, 2)
	f5bddf0(JoeyMem.CMD, 0x814)
	f5bddf0(0xa55080, 0x14)
	f5bddf0(0xa558c0, 0x48c)
	f5bddf0(JoeyMem.BATTLE, 0x14c)
	f5bddf0(0xa579a0, 0x5b4)
	if f44b980() == 0:
		f5bddf0(0xa57f60, 0x33c)
	else:
		m.set_u8(JoeyMem.TURN, m.u8(JoeyMem.TURN) | 0x10)
	f569380(0)
	f569380(1)
	var first := (m.u16(JoeyMem.MODE) >> 3) & 1
	f568d80(first, 8)
	f568d80(1 - first, 8)
	m.set_u16(JoeyMem.pl(0) + JoeyMem.P_LP, 8000)
	m.set_u16(JoeyMem.pl(1) + JoeyMem.P_LP, 8000)
	return 1


## FUN_005bfeb0: arranque del duelo. a = lado local (bit 0), b = quien empieza (bit 0),
## seed = srand. Compone el modo en a54e5c segun la version y el tipo de partida.
func f5bfeb0(a: int, b: int, seed: int) -> int:
	rng.srand(seed)
	m.set_u32(0xa54e50, 0)
	m.set_u32(0xa54e54, 0)
	m.set_u32(0xa54e58, 0)
	var low := (((b & 1) << 3) ^ (a & 1)) & 0xffff
	var players := (((1 << ((1 - (low & 1)) & 0x1f)) & 0xff) & 3) << 1
	var mode := players | low
	if _s32(f44baa0()) < 1000:
		mode = (players & 0xfffd) | low | 4
	m.set_u16(JoeyMem.MODE, mode)
	match m.u32(GAME_KIND):
		3:
			m.set_u16(JoeyMem.MODE, mode & 0xfe79)
		4, 5, 6:
			m.set_u16(JoeyMem.MODE, m.u16(JoeyMem.MODE) | 0x80)
		7:
			m.set_u16(JoeyMem.MODE, m.u16(JoeyMem.MODE) | 6)
	m.set_u16(JoeyMem.MODE + 2, 0)
	f5b9e50()
	if m.u32(GAME_KIND) == 4 and f479b30() != 0:
		m.set_u16(JoeyMem.MODE, m.u16(JoeyMem.MODE) ^ 1)
	return 0


static func _s32(v: int) -> int:
	v &= 0xffffffff
	return v - 0x100000000 if v >= 0x80000000 else v


## Division y resto de C (truncan hacia cero).
static func _cdiv(a: int, b: int) -> int:
	var q := absi(a) / absi(b)
	return q if (a < 0) == (b < 0) else -q


static func _cdiv_rem(a: int, b: int) -> int:
	return a - _cdiv(a, b) * b


# --- Dependencias adelantadas de M3 y de la interfaz -----------------------------------------
# Las llaman M1/M2 (etapa 1); su bloque es M3 o la frontera, pero son hojas pequenas.

## FUN_0045e240: pide la ayuda `index` al jugador local (la guarda en 5ebee4; la lee 45e3d0).
func f45e240(index: int) -> int:
	m.set_u32(0x5ebee4, index)
	return 0


## FUN_005700f0: direccion de la entrada i de la ubicacion loc de p: listas 0xb-0xf, campo si
## loc + i < 11 y, si no, la carta separada (a57864) cuando a57840 la situa ahi, o el objeto
## vacio a578f4.
func f5700f0(p: int, loc: int, i: int) -> int:
	var q := (p & 1) * JoeyMem.PLAYER_SIZE
	match loc & 0xffffffff:
		0xb: return JoeyMem.PLAYER + q + JoeyMem.P_HAND + i * 4
		0xc: return JoeyMem.PLAYER + q + JoeyMem.P_FUSION + i * 4
		0xd: return JoeyMem.PLAYER + q + JoeyMem.P_DECK + i * 4
		0xe: return JoeyMem.PLAYER + q + JoeyMem.P_GRAVE + i * 4
		0xf: return JoeyMem.PLAYER + q + JoeyMem.P_BANISH + i * 4
	if _s32(loc + i) < 0xb:
		return JoeyMem.zone(p, 0) + (loc + i) * JoeyMem.ZONE_SIZE
	if (p & 0xffffffff) == (m.u32(JoeyMem.BATTLE) & 1) and (loc & 0xffffffff) == ((m.u32(JoeyMem.BATTLE) >> 8) & 7):
		return JoeyMem.DETACHED
	return JoeyMem.DETACHED_EMPTY


## FUN_00570230: indice (12 bits) de esa misma entrada (como 5700f0, pero leyendola).
func f570230(p: int, loc: int, i: int) -> int:
	return m.u32(f5700f0(p, loc, i)) & 0xfff


## FUN_005709d0: 1 si la ranura del jugador (zona 11) tiene un vinculo 3/11-13 de esa carta.
func f5709d0(p: int, card_id: int) -> int:
	return int(_s32(f56da10(p, 0xb, card_id)) >= 0)


## FUN_005709f0: posicion de ese vinculo en la ranura del jugador (Ghidra la da como void, pero
## deja en EAX el resultado de 56da10).
func f5709f0(p: int, card_id: int) -> int:
	return f56da10(p, 0xb, card_id)


## FUN_00570710: pone (value != 0) o quita el bit `bit` del estado +0x8c de la zona z de p.
func f570710(p: int, z: int, bit: int, value: int) -> int:
	var at := JoeyMem.zone(p, 0) + 0x8c + z * JoeyMem.ZONE_SIZE
	if value != 0:
		m.set_u32(at, m.u32(at) | (1 << (bit & 0x1f)))
	else:
		m.set_u32(at, m.u32(at) & ~(1 << (bit & 0x1f)))
	return 0


## FUN_005be050: redondeo (x * 5 + 5) / 10 con aritmetica int32 de C.
func f5be050(x: int) -> int:
	return _cdiv(_s32(x * 5 + 5), 10)


## FUN_0057a4b0: 1 si la carta e (+2 bit0 = jugador) puede quedar unida a ref = (z << 8) | p:
## monstruo boca arriba del mismo jugador que sea 0x2da o 0x536 y sin vinculo 56d560 previo.
func f57a4b0(e: int, ref: int) -> int:
	var z := (ref >> 8) & 0xff
	if z > 4:
		return 0
	var p := ref & 1
	var at := JoeyMem.zone(p, z)
	if (m.u32(at) & 0xfff) == 0 or (m.u8(at + 6) & 2) == 0:
		return 0
	if (m.u8(e + 2) & 1) != (ref & 0xff):
		return 0
	var card_id := s16(f4022e0(m.u16(at) & 0xfff))
	if card_id != 0x2da and card_id != 0x536:
		return 0
	return int(s16(f56d560(ref & 0xff, z)) == -1)


## FUN_00579ce0: 1 si el equipo e puede ir sobre el monstruo ref = (z << 8) | p, segun el id del
## equipo: tipo (56f6f0), atributo (56f9e0), carta concreta o jugador del objetivo.
func f579ce0(e: int, ref: int) -> int:
	var z := (ref >> 8) & 0xff
	var low := ref & 0xff
	var p := ref & 1
	var desc := m.u16(e + 2)
	var target := m.u16(JoeyMem.zone(p, 0) + z * JoeyMem.ZONE_SIZE) & 0xfff
	var seq := 0
	if (desc & 0x3e) < 0x15:
		seq = m.u16(JoeyMem.zone(desc & 1, (desc >> 1) & 0x1f) + 4)
	var kind := s16(f56f6f0(low, z, seq))
	var attr := s16(f56f9e0(low, z))
	if z >= 5:
		return 0
	var at := JoeyMem.zone(p, 0) + z * JoeyMem.ZONE_SIZE
	if (m.u32(at) & 0xfff) == 0 or (m.u8(at + 6) & 2) == 0:
		return 0
	var own := m.u8(e + 2) & 1
	var card_id := f4022e0(m.u16(e)) & 0xffff
	match card_id:
		0x147: return int(kind == 0xe)
		0x138, 0x139, 0x12f, 0x136, 0x140, 0x290, 0x291, 0x412, 0x424, \
				0x4da, 0x4e9, 0x4ea, 0x521, 0x58b, 0x58c, 0x5a8, 0x5a9, 0x5aa, 0x60c:
			return 1
		0x47:
			if s16(f4022e0(target)) == 0x115 and own == low:
				return int(f56d660(low, z, 0x47) == 0)
			return 0
		0x12c, 0x49e, 0x58e, 0x60e: return int(kind == 0xf)
		0x12d: return int(attr == 2)
		0x12e: return int(kind == 3)
		0x130, 0x131: return int(kind == 10)
		0x132, 0x29b: return int(attr == 1)
		0x133: return int(kind == 0xb)
		0x134: return int(attr == 3)
		0x135: return int(kind == 0xd)
		0x137: return int(kind == 0x11)
		0x13a: return int(kind == 1)
		0x13b: return int(kind == 0x13)
		0x13c:
			var other := f4022e0(target) & 0xffff
			return int(other == 0x3d or other == 0x3e or other == 0x4e1)
		0x13e: return int(kind == 0xc)
		0x141: return int(kind == 2)
		0x142: return int(kind == 0x12)
		0x143: return int(attr == 5)
		0x144, 0x3c2: return int(kind == 7)
		0x145: return int(kind == 9)
		0x146: return int(kind == 0x10)
		0x28a, 0x422: return int(own == low)
		0x28b: return int(s16(f4022e0(target)) == 0x16d)
		0x28d, 0x3f4: return int(attr == 4)
		0x3f5: return int(attr == 6)
		0x416, 0x417: return int(kind != 7)
		0x42c, 0x5ea: return int(own != low)
		0x604: return int(s16(f4022e0(target)) == 0x53b)
	return 0
