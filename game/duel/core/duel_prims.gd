class_name DuelPrims
extends DuelDecl
## Primitivas del estado del duelo portadas de Yugi_Pc.exe (rango 0x541000-0x546470 y
## auxiliares). Cada funcion se llama f<direccion> como la original; los punteros a la
## memoria del duelo se pasan como direcciones (enteros) de DuelMem.
##
## Convenciones del porte:
## - "p" es el jugador; solo cuenta su bit 0, como en el original ((p & 1) * 0xd54).
## - Las entradas de carta son u32: bits 0-11 indice, bit 12 propietario, resto banderas.
## - Los moldes de C se respetan: (byte) -> & 0xff, (ushort) -> & 0xffff, (short) -> s16().

const H := DuelMem.PLAYER   # 0xa11944
const PS := DuelMem.PLAYER_SIZE


# --- Utilidades de molde de C ----------------------------------------------------------

static func s16(v: int) -> int:
	v &= 0xffff
	return v - 0x10000 if v >= 0x8000 else v


static func s8(v: int) -> int:
	v &= 0xff
	return v - 0x100 if v >= 0x80 else v


# --- Tabla de efectos ---------------------------------------------------------------------

## Tabla de efectos de Yugi (56e540): 0x1ae filas de 24 bytes: u16 id, +4 resolucion,
## +8 objetivo, +0xc condicion, +0x10 y +0x14 selecciones previas a la cadena.
const EFFECT_TABLE := 0x5aaa38
const EFFECT_ROWS := 0x1ae
## Columna `offset` de la fila `row` de 56e540.
func effect_column(row: int, offset: int) -> int:
	if row < 0:
		return 0
	if row >= EFFECT_ROWS:
		return 0
	return m.u32(EFFECT_TABLE + row * 24 + offset)


# --- Tablas de cartas -------------------------------------------------------------------

## FUN_00401a70
func f401a70(index: int) -> int:
	return cards.id_of(index)


## FUN_00401ad0
func f401ad0(card_id: int) -> int:
	return cards.index_of(card_id)


## FUN_00401a20
func f401a20(index: int) -> int:
	return cards.prop(index)

## FUN_00401b50: disponibilidad por juego en CARD_Pack.bin.
func f401b50(index: int) -> int:
	if index < 0 or index >= cards.packs.size():
		return _unported(0x401b50)
	return cards.packs[index]


## Tipo de la carta: bits 20-24 de prop (< 21 monstruo, 21 trampa, 22 magia).
func ctype(index: int) -> int:
	return (cards.prop(index) >> 20) & 0x1f


## FUN_00541950 (indice en ESI): clase de carta para las reglas.
func f541950(index: int) -> int:
	var card_id := f401a70(index)
	if card_id == 0x776:
		return 3
	if card_id > 0x776 and card_id < 0x779:
		return 1
	var t := ctype(index)
	if t == 0x15:
		return 8
	if t == 0x16:
		return 7
	if t == 0x17:
		return 9
	return (f401a20(index) >> 0x12) & 3


## FUN_00541c10: dos cartas "iguales" (mismo id, arte alternativo o parejas conocidas).
func f541c10(a: int, b: int) -> int:
	var u1 := f401a70(a)
	var u2 := f401a70(b)
	if u1 > 1999:
		u1 -= 2000
	if u2 > 1999:
		u2 -= 2000
	if u1 == u2:
		return 1
	if u1 < 0x40b:
		if u1 != 0x40a:
			if u1 == 0x22:
				return 1 if u2 == 0x22 or u2 == 0x4ba else 0
			if u1 == 0x3d:
				return 1 if u2 == 0x3d or u2 == 0x4e1 else 0
			if u1 != 0x3eb:
				return 0
		return 1 if u2 == 0x3eb or u2 == 0x40a else 0
	if u1 == 0x4ba:
		return 1 if u2 == 0x22 or u2 == 0x4ba else 0
	if u1 != 0x4e1:
		return 0
	return 1 if u2 == 0x3d or u2 == 0x4e1 else 0


## FUN_00541ce0
func f541ce0(card_id: int) -> int:
	card_id &= 0xffff
	return 1 if card_id > 0x2d5 and (card_id < 0x2d9 or card_id == 0x2fe) else 0


# --- Direcciones ------------------------------------------------------------------------

## FUN_005419b0: direccion de la entrada `i` de la ubicacion `loc` del jugador p.
func f5419b0(p: int, loc: int, i: int) -> int:
	var q := (p & 1) * PS
	match loc:
		0xb:
			return 0xa11fb8 + q + i * 4
		0xc:
			return 0xa12378 + q + i * 4
		0xd:
			return 0xa120f8 + q + i * 4
		0xe:
			return 0xa12238 + q + i * 4
		0xf:
			return 0xa124b8 + q + i * 4
	return 0xa1195c + (loc + i) * 0x94 + q


## FUN_00541a90: indice de la carta en esa entrada.
func f541a90(p: int, loc: int, i: int) -> int:
	return m.u32(f5419b0(p, loc, i)) & 0xfff


# --- Copias -----------------------------------------------------------------------------

## FUN_00541cb0: *dst = *src (u32)
func f541cb0(dst: int, src: int) -> int:
	m.set_u32(dst, m.u32(src))
	return 0


## FUN_00541cc0: intercambia dos u32
func f541cc0(a: int, b: int) -> int:
	var t := m.u32(a)
	m.set_u32(a, m.u32(b))
	m.set_u32(b, t)
	return 0


## FUN_00541b90: resta a un u16 por jugador sin bajar de 0 (puntos de vida).
func f541b90(base: int, p: int, amount: int) -> int:
	var at := base + (p & 1) * PS
	if amount < m.u16(at):
		m.set_u16(at, m.u16(at) - amount)
	else:
		m.set_u16(at, 0)
	return 0


## FUN_00541bd0
func f541bd0(addr: int) -> int:
	m.set_u32(addr, m.u32(addr) & 0xee483fff)
	return 0


## FUN_00541be0
func f541be0(p: int, z: int) -> int:
	f541bd0(DuelMem.zone(p, z))
	return 0


## FUN_0053f980: memset(dst, 0, size).
func f53f980(dst: int, size: int) -> int:
	m.clear(dst, size)
	return 0


## FUN_0053f9a0: memcpy(dst, src, size).
func f53f9a0(dst: int, src: int, size: int) -> int:
	m.copy(dst, src, size)
	return 0


# --- Opciones globales ------------------------------------------------------------------

## FUN_0053fcd0: lee el indicador u16 de 0x5aa750. Solo elige entre las dos copias identicas
## que formatean el "%d" de los mensajes (FUN_0053fb40), asi que no cambia ningun texto.
func f53fcd0() -> int:
	return m.u16(0x5aa750)


## FUN_0053fce0: escribe el indicador de 0x5aa750.
func f53fce0(value: int) -> int:
	m.set_u16(0x5aa750, value & 0xffff)
	return 0


## FUN_0053fcf0: 1 si el indicador de 0x5aa750 vale 0.
func f53fcf0() -> int:
	return int(m.u16(0x5aa750) == 0)


## FUN_00540410: mascara de la ranura de guardado activa, 1 << DAT_005aed1c (FUN_004098b0).
func f540410() -> int:
	return (1 << (m.u8(0x5aed1c) & 0x1f)) & 0xffff


# --- Mazo -------------------------------------------------------------------------------

## FUN_00542b50: copia el mazo de la partida (0xa112c0) a las listas del duelo.
func f542b50(p: int) -> int:
	var q := (p & 1) * PS
	var owner := (p & 1) << 12
	m.clear(0xa120f8 + p * PS, 0x140)
	var deck := DuelMem.DECKS + p * DuelMem.DECK_SIZE
	var n := m.u16(deck + 0xdc)
	m.set_u8(0xa11947 + q, 0)
	for i in n:
		var at := 0xa120f8 + q + i * 4
		m.set_u32(at, (m.u16(deck + i * 2) & 0xfff) | (m.u32(at) & 0xffffe000) | owner)
		m.set_u8(0xa11947 + q, m.u8(0xa11947 + q) + 1)
	n = m.u16(deck + 0xe0)
	m.set_u8(0xa11949 + q, 0)
	for i in n:
		var at := 0xa12378 + q + i * 4
		m.set_u32(at, (m.u16(deck + 0xbe + i * 2) & 0xfff) | (m.u32(at) & 0xffffe000) | owner)
		m.set_u8(0xa11949 + q, m.u8(0xa11949 + q) + 1)
	return 0


## FUN_005426d0: baraja con n * mult intercambios; al jugador 1 le sube las piezas de Exodia.
func f5426d0(p: int, mult: int) -> int:
	var q := (p & 1) * PS
	var count_at := 0xa11947 + q
	if m.u8(count_at) == 0:
		return 0
	var swaps := m.u8(count_at) * mult
	while swaps > 0:
		var a := rng.rand()
		var n := m.u8(count_at)
		var b := rng.rand()
		var ai := a % n
		var bi := b % n
		var aa := 0xa120f8 + q + ai * 4
		var ba := 0xa120f8 + q + bi * 4
		f541cc0(aa, ba)
		swaps -= 1
	if p != 0:
		for piece in range(0x10, 0x15):
			f542630(1, piece, 0x14)
	return 0


## FUN_00542630: lleva la primera carta con ese id a una posicion al azar entre las `limit` de arriba.
func f542630(p: int, card_id: int, limit: int) -> int:
	p &= 1
	var q := p * PS
	var n := m.u8(0xa11947 + q)
	if n == 0:
		return 0
	var i := 0
	while s16(f401a70(m.u16(0xa120f8 + q + i * 4) & 0xfff)) != s16(card_id):
		i += 1
		if m.u8(0xa11947 + q) <= i:
			return 0
	var lim := limit & 0xffff
	if m.u8(0xa11947 + q) <= lim:
		lim = m.u8(0xa11947 + q)
	var r := rng.rand()
	var index := r % lim
	f541cc0(0xa120f8 + q + index * 4, 0xa120f8 + q + i * 4)
	return 0


## FUN_00542520: pone la carta encima del mazo.
func f542520(p: int, entry_addr: int) -> int:
	p &= 1
	var q := p * PS
	var n := m.u8(0xa11947 + q)
	var at := 0xa120f8 + q + n * 4
	while n != 0:
		f541cb0(at, at - 4)
		n -= 1
		at -= 4
	m.set_u8(0xa11947 + q, m.u8(0xa11947 + q) + 1)
	m.set_u32(entry_addr, m.u32(entry_addr) & 0xfffbffff)
	f541cb0(0xa120f8 + q, entry_addr)
	return 0


## FUN_005425a0: pone la carta debajo del mazo.
func f5425a0(p: int, entry_addr: int) -> int:
	var q := (p & 1) * PS
	f541cb0(0xa120f8 + q + m.u8(0xa11947 + q) * 4, entry_addr)
	m.set_u8(0xa11947 + q, m.u8(0xa11947 + q) + 1)
	return 0


## FUN_005425e0: devuelve la carta al mazo de fusion.
func f5425e0(p: int, entry_addr: int) -> int:
	var q := (p & 1) * PS
	f541cb0(0xa12378 + m.u8(0xa11949 + q) * 4 + q, entry_addr)
	m.set_u8(0xa11949 + q, m.u8(0xa11949 + q) + 1)
	return 0


## FUN_00542790: saca la carta `i` del mazo y la copia en out_addr. 1 si habia carta.
func f542790(p: int, i: int, out_addr: int) -> int:
	var q := (p & 1) * PS
	var count_at := 0xa11947 + q
	if i >= m.u8(count_at):
		return 0
	var at := 0xa120f8 + q + i * 4
	f541cb0(out_addr, at)
	var n := m.u8(count_at)
	m.set_u8(count_at, n - 1)
	if i < ((n - 1) & 0xff):
		while i < m.u8(count_at):
			f541cb0(at, at + 4)
			i += 1
			at += 4
	return 1


## FUN_00542810: saca del mazo la entrada igual a la de entry_addr.
func f542810(p: int, entry_addr: int) -> int:
	p &= 1
	var q := p * PS
	var n := m.u8(0xa11947 + q)
	for i in n:
		if m.u32(entry_addr) == m.u32(0xa120f8 + q + i * 4):
			m.set_u8(0xa11947 + q, n - 1)
			var j := i
			var at := 0xa120f8 + q + j * 4
			while j < m.u8(0xa11947 + q):
				f541cb0(at, at + 4)
				j += 1
				at += 4
			return 1
	return 0


## FUN_005428a0: saca del mazo la primera carta con ese id y la copia en out_addr.
func f5428a0(p: int, card_id: int, out_addr: int) -> int:
	p &= 1
	var q := p * PS
	if m.u8(0xa11947 + q) == 0:
		return 0
	var i := 0
	while true:
		if s16(f401a70(m.u16(0xa120f8 + q + i * 4) & 0xfff)) == s16(card_id):
			var at := 0xa120f8 + q + i * 4
			f541cb0(out_addr, at)
			m.set_u8(0xa11947 + q, m.u8(0xa11947 + q) - 1)
			while i < m.u8(0xa11947 + q):
				f541cb0(at, at + 4)
				i += 1
				at += 4
			return 1
		i += 1
		if i >= m.u8(0xa11947 + q):
			return 0
	return 0


## FUN_00542960: roba una carta.
func f542960(p: int) -> int:
	var tmp := m.local(4)
	if f542790(p, 0, tmp) != 0:
		f544c50(p, tmp)
	return 0


## FUN_00542990: saca del mazo de fusion la entrada igual a la de entry_addr.
func f542990(p: int, entry_addr: int) -> int:
	p &= 1
	var q := p * PS
	var n := m.u8(0xa11949 + q)
	for i in n:
		if m.u32(entry_addr) == m.u32(0xa12378 + q + i * 4):
			m.set_u8(0xa11949 + q, n - 1)
			var j := i
			var at := 0xa12378 + q + j * 4
			while j < m.u8(0xa11949 + q):
				f541cb0(at, at + 4)
				j += 1
				at += 4
			return 1
	return 0


# --- Mano ---------------------------------------------------------------------------------

## FUN_00544c50: anade la carta a la mano (las de fusion vuelven a su mazo; las de id
## 1920-1999 no se anaden).
func f544c50(p: int, entry_addr: int) -> int:
	var q := (p & 1) * PS
	var n := m.u8(0xa11946 + q)
	var entry := m.u32(entry_addr)
	if (entry & 0xfff) == 0:
		return 0
	if f401a70(entry & 0xfff) >= 0x780 and f401a70(entry & 0xfff) < 2000:
		return 0
	if f541950(entry & 0xfff) == 2:
		f5425e0((entry >> 12) & 1, entry_addr)
		return 0
	f541cb0(0xa11fb8 + n * 4 + q, entry_addr)
	m.set_u8(0xa11946 + q, m.u8(0xa11946 + q) + 1)
	return 0


## FUN_00544d10: saca de la mano la entrada igual a la de entry_addr.
func f544d10(p: int, entry_addr: int) -> int:
	p &= 1
	var q := p * PS
	var i := 0
	while i < m.u8(0xa11946 + q):
		if m.u32(0xa11fb8 + q + i * 4) == m.u32(entry_addr):
			m.set_u8(0xa11946 + q, m.u8(0xa11946 + q) - 1)
			var at := 0xa11fb8 + q + i * 4
			while i < m.u8(0xa11946 + q):
				f541cb0(at, at + 4)
				i += 1
				at += 4
			return 1
		i += 1
	return 0


## FUN_00544db0: posicion en la mano de la entrada igual a la de entry_addr, o -1.
func f544db0(p: int, entry_addr: int) -> int:
	var q := (p & 1) * PS
	for i in m.u8(0xa11946 + q):
		if m.u32(0xa11fb8 + q + i * 4) == m.u32(entry_addr):
			return i
	return -1


## FUN_00544e00: compacta la mano quitando los huecos (entradas con indice 0).
func f544e00(p: int) -> int:
	var q := (p & 1) * PS
	var count_at := 0xa11946 + q
	var i := 0
	var at := 0xa11fb8 + q
	while i < m.u8(count_at):
		if (m.u32(at) & 0xfff) == 0:
			m.set_u8(count_at, m.u8(count_at) - 1)
			var j := i
			var at2 := at
			while j < m.u8(count_at):
				f541cb0(at2, at2 + 4)
				j += 1
				at2 += 4
		else:
			i += 1
			at += 4
	return 0


# --- Cementerio y excluidas -------------------------------------------------------------

## FUN_00544300: manda la carta al cementerio de su propietario.
func f544300(entry_addr: int) -> int:
	var entry := m.u32(entry_addr)
	var owner := (entry >> 12) & 1
	var q := owner * PS
	var n := m.u8(0xa11948 + q)
	if (entry & 0xfff) == 0:
		return 0
	if f401a70(entry & 0xfff) > 0x77f and f401a70(entry & 0xfff) < 2000:
		return 0
	m.set_u32(entry_addr, m.u32(entry_addr) & 0xfffbffff)
	f541cb0(0xa12238 + n * 4 + q, entry_addr)
	m.set_u8(0xa11948 + q, m.u8(0xa11948 + q) + 1)
	return 0


## FUN_005443a0: excluye la carta (con informacion 0).
func f5443a0(entry_addr: int) -> int:
	var entry := m.u32(entry_addr)
	var owner := (entry >> 12) & 1
	var count_at := 0xa1194a + owner * PS
	var n := m.u8(count_at)
	if (entry & 0xfff) == 0:
		return 0
	if f401a70(entry & 0xfff) > 0x77f and f401a70(entry & 0xfff) < 2000:
		return 0
	m.set_u32(entry_addr, m.u32(entry_addr) & 0xfffbffff)
	f541cb0(0xa124b8 + n * 4 + owner * PS, entry_addr)
	m.set_u16(0xa125f8 + (m.u8(count_at) + owner * 0x6aa) * 2, 0)
	m.set_u8(count_at, m.u8(count_at) + 1)
	return 0


## FUN_005446c0: quita la carta `i` del cementerio.
func f5446c0(p: int, i: int) -> int:
	var q := (p & 1) * PS
	var count_at := 0xa11948 + q
	if i >= m.u8(count_at):
		return 0
	m.set_u8(count_at, m.u8(count_at) - 1)
	var at := 0xa12238 + q + i * 4
	while i < m.u8(count_at):
		f541cb0(at, at + 4)
		i += 1
		at += 4
	return 1


## FUN_00544740: saca la carta `i` del cementerio y la copia en out_addr.
func f544740(p: int, i: int, out_addr: int) -> int:
	var q := (p & 1) * PS
	var count_at := 0xa11948 + q
	if i >= m.u8(count_at):
		return 0
	var at := 0xa12238 + q + i * 4
	f541cb0(out_addr, at)
	var n := m.u8(count_at)
	m.set_u8(count_at, n - 1)
	if i < ((n - 1) & 0xff):
		while i < m.u8(count_at):
			f541cb0(at, at + 4)
			i += 1
			at += 4
	return 1


## FUN_005447d0: quita del cementerio (buscando desde arriba) la entrada igual a la de entry_addr.
func f5447d0(p: int, entry_addr: int) -> int:
	var q := (p & 1) * PS
	var i := m.u8(0xa11948 + q) - 1
	while i >= 0:
		if m.u32(entry_addr) == m.u32(0xa12238 + q + i * 4):
			return f5446c0(p, i)
		i -= 1
	return 0


## FUN_00544830: quita del cementerio la primera carta con ese indice.
func f544830(p: int, index: int) -> int:
	var q := (p & 1) * PS
	for i in m.u8(0xa11948 + q):
		if (m.u32(0xa12238 + q + i * 4) & 0xfff) == (index & 0xffff):
			return f5446c0(p, i)
	return 0


# --- Campo --------------------------------------------------------------------------------

## FUN_00542c40 (jugador en EAX, zona en ECX): vacia la zona.
func f542c40(p: int, z: int) -> int:
	m.clear(DuelMem.zone(p, z), 0x94)
	headless_detached.erase("%d:%d" % [p & 1, z])
	return 0


## FUN_005422b0: coloca una carta en la zona de monstruo z.
## a4 va al bit 0 de las banderas de la zona y a5 al bit 1 (significado pendiente).
func f5422b0(p: int, z: int, entry_addr: int, a4: int, a5: int) -> int:
	var zone := 0xa1195c + z * 0x94 + (p & 1) * PS
	m.clear(zone, 0x94)
	f541cb0(zone, entry_addr)
	m.set_u16(zone + 4, m.u16(DuelMem.PLACE_SEQ))
	m.set_u16(DuelMem.PLACE_SEQ, m.u16(DuelMem.PLACE_SEQ) + 1)
	m.set_u16(zone + 6, ((((a5 & 1) | 0x900) << 1) | (a4 & 1) | (m.u16(zone + 6) & 0xfffc)))
	var not_owner := 1 if (p != ((m.u32(entry_addr) >> 12) & 1)) else 0
	m.set_u16(zone + 0x90, m.u16(zone + 0x90) ^ ((((not_owner << 1) ^ m.u8(zone + 0x90)) & 2)))
	if (a4 == 0 and a5 != 0):
		var flags := 0xa1195a + (p & 1) * PS
		m.set_u16(flags, m.u16(flags) & ~(1 << (z & 0x1f)))
	if f541ce0(f401a70(m.u16(entry_addr) & 0xfff)) != 0:
		m.set_u8(zone + 0x8e, m.u8(zone + 0x8e) | 8)
	return 0


## Subtipo de magia o trampa: bits 17-19 de prop (2 = magia de campo).
func csub(index: int) -> int:
	return (cards.prop(index) >> 17) & 7


## FUN_005423a0: coloca una carta en la zona de magia/trampa z (0-4); las magias de campo
## van a la zona 10. a4 va al bit 1 de las banderas de la zona.
func f5423a0(p: int, z: int, entry_addr: int, a4: int) -> int:
	var q := (p & 1) * PS
	var zone := 0xa11c40 + z * 0x94 + q
	var index := m.u16(entry_addr) & 0xfff
	if ctype(index) == 0x16:
		var t := ctype(index)
		if t > 0x14 and t < 0x17 and csub(index) == 2:
			zone = 0xa11f24 + q
	f541cb0(zone, entry_addr)
	m.set_u16(zone + 4, m.u16(DuelMem.PLACE_SEQ))
	m.set_u16(DuelMem.PLACE_SEQ, m.u16(DuelMem.PLACE_SEQ) + 1)
	m.set_u8(zone + 0x90, m.u8(zone + 0x90) & 0xfe)
	m.set_u16(zone + 6, ((a4 & 1) << 1) | (m.u16(zone + 6) & 0xffc0))
	m.set_u16(zone + 0x8e, (m.u8(zone + 0x8e) & 0x1f) | 0x1e0)
	var not_owner := 1 if p != ((m.u32(entry_addr) >> 12) & 1) else 0
	m.set_u16(zone + 0x90, (not_owner << 1) | (m.u16(zone + 0x90) & 0xfff9))
	if a4 == 0 and ctype(index) == 0x16:
		var t := ctype(index)
		if t > 0x14 and t < 0x17 and csub(index) == 5:
			return 0
		if f542f30(0, 0x49c) == 0 and f542f30(1, 0x49c) == 0:
			m.set_u8(zone + 0x8f, m.u8(zone + 0x8f) | 2)
	return 0


## FUN_00542e60: cuantas cartas boca arriba con ese id hay en el campo de p (monstruos si el
## id es de monstruo, magia/trampa si no), sin contar la zona `skip`.
func f542e60(p: int, card_id: int, skip: int) -> int:
	var index := f401ad0(card_id)
	var z0 := 0
	var z1 := 4
	if ctype(index) >= 0x15:
		z0 = 5
		z1 = 10
	var count := 0
	var z := z0
	while z <= z1:
		var zone := DuelMem.zone(p, z)
		var ix := m.u16(zone) & 0xfff
		if ix != 0 and z != skip and (m.u8(zone + 6) & 2) != 0 and (m.u8(zone + 0x8f) & 4) == 0:
			if ctype(ix) < 0x15 or (m.u8(zone + 0x90) & 1) == 0:
				if s16(f401a70(ix)) == s16(card_id):
					# Consumidor69820: consultar identidad propia, no solo el ID.
					count += 1
		z += 1
	return count


## FUN_00542f30
func f542f30(p: int, card_id: int) -> int:
	return f542e60(p, card_id, -1)


## FUN_00542da0: zona de magia/trampa (5-10) con esa carta boca arriba, o -1.
func f542da0(p: int, card_id: int) -> int:
	for z in range(5, 11):
		var zone := DuelMem.zone(p, z)
		if (m.u16(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 2) != 0:
			if s16(f401a70(m.u16(zone) & 0xfff)) == s16(card_id):
				return z
	return -1


## FUN_005439a0 / FUN_00543a30: cartas boca arriba con ese id en las 11 zonas de p.
func f543a30(p: int, card_id: int) -> int:
	var count := 0
	for z in 11:
		var zone := DuelMem.zone(p, z)
		var ix := m.u16(zone) & 0xfff
		if ix != 0 and (m.u32(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 2) != 0 \
				and (m.u8(zone + 0x8f) & 4) == 0:
			if s16(f401a70(ix)) == s16(card_id):
				count += 1
	return count


## FUN_00545060: cartas con ese id en la mano de p.
func f545060(p: int, card_id: int) -> int:
	var q := (p & 1) * PS
	var count := 0
	for i in m.u8(0xa11946 + q):
		if s16(f401a70(m.u16(0xa11fb8 + q + i * 4) & 0xfff)) == s16(card_id):
			count += 1
	return count


## FUN_00545620: cuantos vinculos de la zona (lista en +0x08/+0x48) son de una carta con ese id.
func f545620(p: int, z: int, card_id: int) -> int:
	p &= 1
	var zone := DuelMem.zone(p, z)
	var count := 0
	var n := m.u16(zone + 0x88)
	for i in n:
		var link := m.u16(zone + 0x08 + i * 2)
		var kind := m.u8(zone + 0x48 + i * 2)
		var lz := (link >> 8) & 0xff
		var other := m.u16(DuelMem.zone(link & 1, lz)) & 0xfff
		if (card_id != 0x15c and card_id != 0x422 and card_id != 0x4dc) \
				or (m.u8(DuelMem.zone(link & 1, lz) + 0x8f) & 4) == 0:
			match kind:
				1, 2, 10:
					pass
				3, 0xd, 0xe:
					other = link
				_:
					continue
			if s16(f401a70(other)) == s16(card_id):
				count += 1
	return count


## FUN_0053d660: tiene las cinco piezas de Exodia en la mano.
func f53d660(p: int) -> int:
	for piece in range(0x10, 0x15):
		if f545060(p, piece) == 0:
			return 0
	return 1


## FUN_0053d6c0: victoria alternativa por cartas en el campo (ids 0x5f8 y 0x605-0x608).
func f53d6c0(p: int) -> int:
	if f542f30(p, 0x5f8) == 0:
		return 0
	for card_id in range(0x605, 0x609):
		if f542da0(p, card_id) < 0:
			return 0
	return 1


## FUN_0053d730: comprueba si el duelo ha terminado; fija el ganador en los bits 5-6 de
## 0xa133f2 (1 = gana el jugador 0, 2 = el 1, 3 = empate) y devuelve 1 si ha terminado.
func f53d730(force: int) -> int:
	var state := m.u8(0xa16180)
	var checking := false
	if (m.u32(0xa114b4) & 0x200) == 0:
		checking = state > 1 and state < 9
	else:
		checking = state == 2
	if not checking and force == 0:
		return 0
	if (m.u32(0xa16180) & 0x100) != 0 and (m.u16(0xa133f2) & 1) != 0:
		return 0
	var lp0 := m.u16(0xa11944)
	var lp1 := m.u16(0xa12698)
	var turn := m.u16(0xa133f2)
	if lp0 == 0 or lp1 == 0:
		turn |= 0x60
		if lp1 < lp0:
			turn = (turn & 0xffbf) | 0x20
		if lp0 < lp1:
			turn = (turn & 0xffdf) | 0x40
		m.set_u16(0xa133f2, turn)
		m.set_u8(0xa133ec, m.u8(0xa133ec) | 0x10)
		return 1
	var f0 := m.u16(0xa1194a)
	var f1 := m.u16(0xa1269e)
	var loser_flag := 0
	var p0_lost := false
	if (f0 & 0x100) == 0 and (f1 & 0x100) == 0:
		f0 = f0 ^ ((((1 if f53d660(0) != 0 else 0) << 9) ^ f0) & 0x200)
		m.set_u16(0xa1194a, f0)
		f1 = f1 ^ ((((1 if f53d660(1) != 0 else 0) << 9) ^ f1) & 0x200)
		m.set_u16(0xa1269e, f1)
		var s := (f0 & 0x200) >> 9
		if s == 0 and (f1 & 0x200) == 0:
			f0 = f0 ^ ((((1 if f53d6c0(0) != 0 else 0) << 10) ^ f0) & 0x400)
			m.set_u16(0xa1194a, f0)
			f1 = f1 ^ ((((1 if f53d6c0(1) != 0 else 0) << 10) ^ f1) & 0x400)
			m.set_u16(0xa1269e, f1)
			s = (f0 & 0x400) >> 10
			if s == 0 and (f1 & 0x400) == 0:
				return 0
			loser_flag = f1 & 0x400
		else:
			loser_flag = f1 & 0x200
		turn |= 0x60
		if loser_flag == 0:
			turn = (turn & 0xffbf) | 0x20
		p0_lost = s == 0
	else:
		turn |= 0x60
		if (f0 & 0x100) == 0:
			turn = (turn & 0xffbf) | 0x20
		p0_lost = (f1 & 0x100) == 0
	if p0_lost:
		turn = (turn & 0xffdf) | 0x40
	m.set_u16(0xa133f2, turn)
	m.set_u8(0xa133ec, m.u8(0xa133ec) | 0x10)
	return 1


## FUN_0054b910: suma `amount` a los LP de p (si es negativo resta sin bajar de 0). La llama
## el contador visual de LP en trozos de 100/10/1; el resultado neto es el mismo.
func f54b910(p: int, amount: int) -> int:
	var before := m.u16(DuelMem.pl(p & 1))
	if amount >= 0:
		var at := 0xa11944 + (p & 1) * PS
		m.set_u16(at, m.u16(at) + amount)
	else:
		f541b90(0xa11944, p, -amount)
	# El sonido sale al preparar el cambio (paso 0 de 404270/4045a0).
	present("lp_total", {"p": p & 1, "from": before, "to": m.u16(DuelMem.pl(p & 1)), "amount": amount, "native_silent": true})
	return 0
