class_name JoeyPortA
extends JoeyBase
## Motor nativo de Joey, lote A de la etapa 1: 5674a0-569820 (M1: accesores de carta, zona, identidad y recuentos).
## Cada funcion se llama f<direccion de Joey_Pc.exe> y sobrescribe su declaracion de joey_decl.gd
## con la misma aridad. Cotejo: re/scripts/joey_specs/port_a.py.

# Listas del jugador (direcciones del jugador 0; el 1 suma 0xd44).
const _JA_HAND_N := 0xa55d68      ## u8 mano; el u16 lleva el mazo en el byte alto
const _JA_GRAVE_N := 0xa55d6a     ## u8 cementerio; el u16 lleva el mazo de fusion en el byte alto
const _JA_BANISH_N := 0xa55d6c
const _JA_HAND := 0xa56434
const _JA_DECK := 0xa56574
const _JA_FUSION := 0xa566b4
const _JA_GRAVE := 0xa566f0
const _JA_BANISH := 0xa5686c

## Ids del mismo nombre para 5674e0 (tras restar 2000 a los ids altos).
const _JA_SAME_NAME := [[0x22, 0x4ba], [0x3d, 0x4e1], [0x39, 0x76d], [0x3eb, 0x40a], [0x4dd, 0x76e]]
const _JA_567620 := [0x27, 0x52, 0x53, 0x65, 0xaa, 0xdf, 0x109, 0x1ab, 0x1cd, 0x1d4, 0x1e9, 0x1f4,
		0x21b, 0x21c, 0x231, 0x246, 0x249, 0x24e, 0x259, 0x262, 0x2d9, 0x2db, 0x2fa, 0x418, 0x452,
		0x45c, 0x48b, 0x4e6, 0x4e7, 0x4e8, 0x51b, 0x532, 0x539, 0x53a, 0x59b, 0x59c, 0x5e8, 0x5f1, 0x5f4]
const _JA_567A00 := [0x37, 0x38, 0x3e, 0x42, 0x170, 0x175, 0x187, 0x2d6, 0x2d7, 0x2d8, 0x2e5, 0x2fe,
		0x34d, 0x4b2, 0x4e9, 0x5ea, 0x5eb, 0x5ec, 0x5ed, 0x5ee, 0x5ef]
const _JA_567B00 := [0x12c, 0x12d, 0x12e, 0x12f, 0x130, 0x131, 0x132, 0x133, 0x134, 0x135, 0x136,
		0x137, 0x138, 0x139, 0x13a, 0x13b, 0x13c, 0x13e, 0x140, 0x141, 0x142, 0x143, 0x144, 0x145,
		0x146, 0x147, 0x28a, 0x28b, 0x28d, 0x290, 0x291, 0x29b, 0x3c2, 0x3f4, 0x3f5, 0x412, 0x416,
		0x417, 0x422, 0x424, 0x42c, 0x49e, 0x521, 0x58b, 0x58c, 0x58e, 0x5a8, 0x5a9, 0x5aa, 0x604,
		0x60c, 0x60e]
const _JA_567C90 := [0x13f, 0x15c, 0x2a8, 0x2a9, 0x2ac, 0x3ab, 0x3c0, 0x3c9, 0x3de, 0x3ea, 0x3f7,
		0x3f8, 0x3ff, 0x403, 0x413, 0x430, 0x431, 0x433, 0x434, 0x43a, 0x44a, 0x485, 0x49b, 0x4bb,
		0x4be, 0x4c4, 0x4dc, 0x4e0, 0x515, 0x524, 0x525, 0x527, 0x52d, 0x587, 0x594, 0x5ab, 0x5f7,
		0x5fe, 0x60a]
const _JA_567F80 := [0x151, 0x152, 0x153, 0x154, 0x155, 0x156, 0x157, 0x158, 0x159, 0x3c8, 0x3ca,
		0x3ee, 0x3ef, 0x3f2, 0x3f6, 0x401, 0x40f, 0x42e, 0x42f, 0x435]
const _JA_568030 := [0xf, 0x51, 0x58, 0x105, 0x172, 0x173, 0x174, 0x186, 0x191, 0x1a0, 0x1a3, 0x1ac,
		0x1f9, 0x1ff, 0x243, 0x28b, 0x2da, 0x2e6, 0x34d, 0x3f9, 0x458, 0x489, 0x52c, 0x536, 0x594,
		0x596, 0x598, 0x599, 0x59f, 0x5a2, 0x5a4, 0x5e6, 0x5e9, 0x5f5, 0x5fc, 0x60b]
const _JA_568310 := [0x51, 0x186, 0x28b, 0x34d, 0x596, 0x599, 0x59f, 0x5a4, 0x60b]
const _JA_5683F0_13 := [0x28a, 0x291, 0x2b0, 0x3f7, 0x3f8, 0x433, 0x434, 0x43a, 0x49a, 0x4b3, 0x4b4,
		0x4dc, 0x522, 0x587, 0x5fe]


## Contador u16 tras sacar una carta del byte alto: (~bajo & 0xff) ^ ((u16 & 0xff00) - 1).
static func _ja_dec_high(v: int) -> int:
	return (((~v) & 0xff) ^ ((v & 0xff00) - 1)) & 0xffff


## Joey FUN_005674a0: limpia los bits 14 y 19-23 de la entrada.
func f5674a0(entry: int) -> int:
	m.set_u32(entry, m.u32(entry) & 0xff07bfff)
	return 0


## Joey FUN_005674b0: 5674a0 sobre la entrada del objeto de zona.
func f5674b0(p: int, z: int) -> int:
	f5674a0(JoeyMem.zone(p, z))
	return 0


## Joey FUN_005674e0: 1 si las dos cartas tienen el mismo nombre (id igual tras restar 2000 a
## los ids altos, o parejas de ids equivalentes).
func f5674e0(a: int, b: int) -> int:
	var u1 := f4022e0(a) & 0xffff
	var u2 := f4022e0(b) & 0xffff
	if u1 > 1999:
		u1 -= 2000
	if u2 > 1999:
		u2 -= 2000
	if u1 == u2:
		return 1
	for pair in _JA_SAME_NAME:
		if u1 in pair:
			return int(u2 in pair)
	return 0


## Joey FUN_005675c0: copia una entrada u32.
func f5675c0(dst: int, src: int) -> int:
	m.set_u32(dst, m.u32(src))
	return 0


## Joey FUN_005675f0: 1 si es una carta toon (0x2d6-0x2d8, 0x2fe).
func f5675f0(index: int) -> int:
	var card_id := f4022e0(index) & 0xffff
	return int((card_id > 0x2d5 and card_id < 0x2d9) or card_id == 0x2fe)


## Joey FUN_00567620: 1 si el id esta en la lista fija; 0x280 solo si el segundo argumento no es 1.
func f567620(index: int, mode: int) -> int:
	var card_id := f4022e0(index) & 0xffff
	if card_id == 0x280:
		return int(mode != 1)
	return int(card_id in _JA_567620)


## Joey FUN_00567990: monstruo con clase de marco 1 o de la lista fija.
func f567990(index: int) -> int:
	if (f4025d0(index) & 0xffff) >= 0x15:
		return 0
	var frame1 := int(s16(f402740(index)) == 1)
	var card_id := f4022e0(index) & 0xffff
	if card_id in [0x2da, 0x32c, 0x4d9, 0x536, 0x5f6]:
		return 1
	return frame1


## Joey FUN_00567a00: monstruo con clase de marco 2-3, o con marco y de la lista fija.
func f567a00(index: int) -> int:
	if (f4025d0(index) & 0xffff) >= 0x15:
		return 0
	var frame := f402740(index) & 0xffff
	if frame == 0:
		return 0
	if frame > 1 and frame < 4:
		return 1
	return int((f4022e0(index) & 0xffff) in _JA_567A00)


## Joey FUN_00567ad0: monstruo con clase de marco 2.
func f567ad0(index: int) -> int:
	if (f4025d0(index) & 0xffff) < 0x15 and s16(f402740(index)) == 2:
		return 1
	return 0


## Joey FUN_00567b00: 1 si el id esta en la lista fija.
func f567b00(index: int) -> int:
	return int((f4022e0(index) & 0xffff) in _JA_567B00)


## Joey FUN_00567c90: sobre una entrada (u16 indice): 567b00 (0x28a solo si el u16 en +0xa no
## es 2) o la lista fija.
func f567c90(entry: int) -> int:
	if f567b00(m.u16(entry)) != 0:
		if (f4022e0(m.u16(entry)) & 0xffff) == 0x28a:
			return int(m.u16(entry + 0xa) != 2)
		return 1
	return int((f4022e0(m.u16(entry)) & 0xffff) in _JA_567C90)


## Joey FUN_00567f80: 1 si el id esta en la lista fija.
func f567f80(index: int) -> int:
	return int((f4022e0(index) & 0xffff) in _JA_567F80)


## Joey FUN_00568030: 1 si el id esta en la lista fija.
func f568030(index: int) -> int:
	return int((f4022e0(index) & 0xffff) in _JA_568030)


## Joey FUN_005682d0: 1 para los ids 0x39, 0x47, 0x1a8 y 0x76d.
func f5682d0(index: int) -> int:
	return int((f4022e0(index) & 0xffff) in [0x39, 0x47, 0x1a8, 0x76d])


## Joey FUN_00568310: 1 si el id esta en la lista fija.
func f568310(index: int) -> int:
	return int((f4022e0(index) & 0xffff) in _JA_568310)


## Joey FUN_005683f0: 1 para los ids fijos y, segun la ubicacion (0xd, 0xe, 0x13, 0x15), su lista.
func f5683f0(index: int, loc: int) -> int:
	var card_id := f4022e0(index) & 0xffff
	if card_id in [0x404, 0x405, 0x406, 0x529, 0x5f5, 0x5fb]:
		return 1
	match loc & 0xffffffff:
		0xd:
			card_id = f4022e0(index) & 0xffff
			return int((card_id > 0x171 and card_id < 0x175) or card_id == 0x5ff)
		0xe:
			return int((f4022e0(index) & 0xffff) in [0x474, 0x49b, 0x518])
		0x13:
			return int((f4022e0(index) & 0xffff) in _JA_5683F0_13)
		0x15:
			return int((f4022e0(index) & 0xffff) in [0x3b6, 0x515])
	return 0


## Joey FUN_00568580: 1 para los ids 0x6c, 0x101, 0x10c y 0x281.
func f568580(index: int) -> int:
	return int((f4022e0(index) & 0xffff) in [0x6c, 0x101, 0x10c, 0x281])


## Joey FUN_005685c0: 1 para 0x605-0x608 o si 5709d0(0, 0x520); si no, 56b440(indice, -1).
func f5685c0(index: int) -> int:
	var card_id := f4022e0(index) & 0xffff
	if card_id >= 0x605 and card_id <= 0x608:
		return 1
	if f5709d0(0, 0x520) != 0:
		return 1
	return f56b440(index, 0xffffffff)


## Joey FUN_00568610: coloca la entrada en la zona con numero de colocacion, cara (b4) y
## posicion (b5), marca 0x20000 en el estado y libera la zona en la mascara de +0x10.
func f568610(p: int, z: int, entry: int, face: int, position: int) -> int:
	var at := JoeyMem.zone(p, z)
	f5bddf0(at, 0x90)
	f5675c0(at, entry)
	m.set_u16(at + 4, m.u16(JoeyMem.PLAYER))
	m.set_u16(JoeyMem.PLAYER, m.u16(JoeyMem.PLAYER) + 1)
	m.set_u16(at + 6, ((m.u16(at + 6) & 0xfffc) ^ (face & 1)) | ((position & 1) << 1) | 0x200)
	m.set_u32(at + 0x8c, m.u32(at + 0x8c) | 0x20000)
	f570710(p, z, 0, int((p & 0xffffffff) != ((m.u32(entry) >> 12) & 1)))
	var mask := JoeyMem.PLAYER + 0x10 + (p & 1) * JoeyMem.PLAYER_SIZE
	m.set_u16(mask, m.u16(mask) & ~(1 << (z & 0x1f)))
	return 0


## Joey FUN_005686e0: coloca la entrada en la zona (numero de colocacion, bit 1 = flag) y, si
## flag es 0 y es una magia no de campo (402700 != 5) sin 0x49c en juego, marca el bit 10.
func f5686e0(p: int, z: int, entry: int, flag: int) -> int:
	var at := JoeyMem.zone(p, z)
	var index := m.u16(entry) & 0xfff
	f5bddf0(at, 0x90)
	f5675c0(at, entry)
	m.set_u16(at + 4, m.u16(JoeyMem.PLAYER))
	m.set_u16(JoeyMem.PLAYER, m.u16(JoeyMem.PLAYER) + 1)
	m.set_u16(at + 8, 0)
	m.set_u16(at + 6, ((flag & 1) << 1) | (m.u16(at + 6) & 0xfbc0))
	f570710(p, z, 0, int((p & 0xffffffff) != ((m.u32(entry) >> 12) & 1)))
	if flag & 0xffffffff == 0 and s16(f4025d0(index)) == 0x16 and s16(f402700(index)) != 5:
		if f5699c0(0x49c) == 0:
			m.set_u8(at + 7, m.u8(at + 7) | 4)
	return 0


## Joey FUN_005687d0: busca la carta por identidad (propietario + identidad * 2): zonas
## (z << 8 | p), cementerio 0xe, excluidas 0xf, mazo 0xd, fusion 0xc, mano 0xb
## (i << 16 | ubic << 8 | p) y cartas separadas (0xffff0000 | datos de a57840); 0x1000 si no esta.
func f5687d0(key: int) -> int:
	key &= 0xffffffff
	for p in 2:
		for z in 11:
			var e := m.u32(JoeyMem.zone(p, z))
			if (e & 0xfff) != 0 and JoeyMem.ident(e) == key:
				return (z << 8) | p
	for p in 2:
		var pl := p * JoeyMem.PLAYER_SIZE
		var counts := m.u16(_JA_GRAVE_N + pl)
		for i in counts & 0xff:
			if JoeyMem.ident(m.u32(_JA_GRAVE + pl + i * 4)) == key:
				return (i << 16) | 0xe00 | p
		for i in m.u8(_JA_BANISH_N + pl):
			if JoeyMem.ident(m.u32(_JA_BANISH + pl + i * 4)) == key:
				return (i << 16) | 0xf00 | p
		for i in m.u16(_JA_HAND_N + pl) >> 8:
			if JoeyMem.ident(m.u32(_JA_DECK + pl + i * 4)) == key:
				return (i << 16) | 0xd00 | p
		for i in counts >> 8:
			if JoeyMem.ident(m.u32(_JA_FUSION + pl + i * 4)) == key:
				return (i << 16) | 0xc00 | p
	for p in 2:
		var pl := p * JoeyMem.PLAYER_SIZE
		for i in m.u8(_JA_HAND_N + pl):
			if JoeyMem.ident(m.u32(_JA_HAND + pl + i * 4)) == key:
				return (i << 16) | 0xb00 | p
	for slot in 2:
		if JoeyMem.ident(m.u32(JoeyMem.DETACHED + slot * JoeyMem.ZONE_SIZE)) == key:
			var battle := m.u32(JoeyMem.BATTLE) & 0xffff
			if slot == 0:
				return 0xffff0000 | (((battle >> 8) & 7) << 8) | (battle & 1)
			return 0xffff0000 | (((battle >> 0xb) & 7) << 8) | ((battle >> 1) & 1)
	return 0x1000


## Joey FUN_00568ad0: posicion en el cementerio de p de la identidad, o -1.
func f568ad0(p: int, key: int) -> int:
	var pl := (p & 1) * JoeyMem.PLAYER_SIZE
	for i in m.u8(_JA_GRAVE_N + pl):
		if JoeyMem.ident(m.u32(_JA_GRAVE + pl + i * 4)) == key & 0xffffffff:
			return i
	return -1


## Joey FUN_00568b30: posicion en la mano de p de la identidad, o -1.
func f568b30(p: int, key: int) -> int:
	var pl := (p & 1) * JoeyMem.PLAYER_SIZE
	for i in m.u8(_JA_HAND_N + pl):
		if JoeyMem.ident(m.u32(_JA_HAND + pl + i * 4)) == key & 0xffffffff:
			return i
	return -1


## Joey FUN_00568b90: u16 que 570230 da para la ubicacion de la identidad (5687d0); 0 si no esta.
func f568b90(key: int) -> int:
	var at := f5687d0(key)
	if at == 0x1000:
		return 0
	return f570230(at & 0xff, (at >> 8) & 0xff, at >> 16) & 0xffff


## Joey FUN_00568bd0: con 567a00 del indice, el bit 14 de la entrada; si no, 1.
func f568bd0(entry: int) -> int:
	if f567a00(m.u16(entry) & 0xfff) != 0:
		return (m.u32(entry) >> 0xe) & 1
	return 1


## Joey FUN_00568c00: pone la entrada encima del mazo de p (desplaza el resto sin acotar).
func f568c00(p: int, src: int) -> int:
	var pl := (p & 1) * JoeyMem.PLAYER_SIZE
	var n := m.u16(_JA_HAND_N + pl) >> 8
	while n > 0:
		f5675c0(_JA_DECK + pl + n * 4, _JA_DECK + pl + (n - 1) * 4)
		n -= 1
	var v := m.u16(_JA_HAND_N + pl)
	m.set_u16(_JA_HAND_N + pl, ((v & 0xff00) + 0x100) ^ (v & 0xff))
	f5675c0(_JA_DECK + pl, src)
	return 0


## Joey FUN_00568ca0: pone la entrada al fondo del mazo de p.
func f568ca0(p: int, src: int) -> int:
	var pl := (p & 1) * JoeyMem.PLAYER_SIZE
	f5675c0(_JA_DECK + pl + (m.u16(_JA_HAND_N + pl) >> 8) * 4, src)
	var v := m.u16(_JA_HAND_N + pl)
	m.set_u16(_JA_HAND_N + pl, ((v & 0xff00) + 0x100) ^ (v & 0xff))
	return 0


## Joey FUN_00568d10: anade la entrada al final del mazo de fusion de p.
func f568d10(p: int, src: int) -> int:
	var pl := (p & 1) * JoeyMem.PLAYER_SIZE
	f5675c0(_JA_FUSION + pl + (m.u16(_JA_GRAVE_N + pl) >> 8) * 4, src)
	var v := m.u16(_JA_GRAVE_N + pl)
	m.set_u16(_JA_GRAVE_N + pl, ((v & 0xff00) + 0x100) ^ (v & 0xff))
	return 0


## Joey FUN_00568fa0: copia en out la primera entrada del mazo de p con ese indice; 1 si la hay.
func f568fa0(p: int, index: int, out: int) -> int:
	var pl := (p & 1) * JoeyMem.PLAYER_SIZE
	var n := m.u16(_JA_HAND_N + pl) >> 8
	for i in n:
		if (m.u32(_JA_DECK + pl + i * 4) & 0xfff) == (index & 0xffff):
			f5675c0(out, _JA_DECK + pl + i * 4)
			return 1
	return 0


## Joey FUN_00569010: saca la carta i del mazo de p (copiada en out) y cierra el hueco.
## Compara i con signo: un i negativo pasa y sigue desplazando.
func f569010(p: int, i: int, out: int) -> int:
	var pl := (p & 1) * JoeyMem.PLAYER_SIZE
	var count := _JA_HAND_N + pl
	i = _s32(i)
	if i >= m.u16(count) >> 8:
		return 0
	var at := _JA_DECK + pl + i * 4
	f5675c0(out, at)
	m.set_u16(count, _ja_dec_high(m.u16(count)))
	while i < m.u16(count) >> 8:
		f5675c0(at, at + 4)
		i += 1
		at += 4
	return 1


## Saca de la lista la primera entrada igual a la de `entry` (antes de la version 1001, por
## indice) y cierra el hueco; el contador va en el byte alto del u16 `count`.
func _ja_remove(count: int, list: int, entry: int) -> int:
	if m.u16(count) & 0xff00 == 0:
		return 0
	var i := 0
	while true:
		var same: bool
		if _s32(f44baa0()) < 0x3e9:
			same = ((m.u32(list + i * 4) ^ m.u32(entry)) & 0xfff) == 0
		else:
			same = m.u32(entry) == m.u32(list + i * 4)
		if same:
			m.set_u16(count, _ja_dec_high(m.u16(count)))
			while i < m.u16(count) >> 8:
				f5675c0(list + i * 4, list + i * 4 + 4)
				i += 1
			return 1
		i += 1
		if i >= m.u16(count) >> 8:
			return 0
	return 0


## Joey FUN_005690d0: saca del mazo de p la entrada; 1 si estaba.
func f5690d0(p: int, entry: int) -> int:
	var pl := (p & 1) * JoeyMem.PLAYER_SIZE
	return _ja_remove(_JA_HAND_N + pl, _JA_DECK + pl, entry)


## Joey FUN_005691d0: roba la carta de arriba del mazo de p y la lleva a la mano (56cef0).
func f5691d0(p: int) -> int:
	var card := m.local(4)
	m.set_u32(card, p)
	if f569010(p, 0, card) != 0:
		f56cef0(p, card)
	return 0


## Joey FUN_00569200: saca del mazo de fusion de p la entrada; 1 si estaba.
func f569200(p: int, entry: int) -> int:
	var pl := (p & 1) * JoeyMem.PLAYER_SIZE
	return _ja_remove(_JA_GRAVE_N + pl, _JA_FUSION + pl, entry)


## Joey FUN_00569300: copias del id en el mazo de p.
func f569300(p: int, card_id: int) -> int:
	var pl := (p & 1) * JoeyMem.PLAYER_SIZE
	if m.u16(_JA_HAND_N + pl) & 0xff00 == 0:
		return 0
	var n := 0
	var i := 0
	while true:
		if (f4022e0(m.u16(_JA_DECK + pl + i * 4) & 0xfff) & 0xffff) == (card_id & 0xffff):
			n += 1
		i += 1
		if i >= m.u16(_JA_HAND_N + pl) >> 8:
			break
	return n


## Joey FUN_005695e0: quita el vinculo k del objeto de zona (referencia y tipo) y cierra el hueco.
func f5695e0(p: int, z: int, k: int) -> int:
	var at := JoeyMem.zone(p, z)
	k = _s32(k)
	if k >= m.u16(at + 0xa):
		return 0
	m.set_u16(at + 0xa, m.u16(at + 0xa) - 1)
	while k < m.u16(at + 0xa):
		var ref := at + 0xc + k * 2
		m.set_u16(ref, m.u16(ref + 2))
		m.set_u16(ref + 0x40, m.u16(ref + 0x42))
		k += 1
	return 0


## Joey FUN_00569660: numero (1-14) de los ids 0x149-0x14e, 0x42d, 0x465-0x46a y 0x60b; 0 en el
## resto (con la mitad alta de id - base, como deja EAX el original).
func f569660(card_id: int) -> int:
	var v := card_id & 0xffff
	if v == 0x42d:
		return 7
	if v == 0x60b:
		return 0xe
	if v > 0x60b:
		return 0
	var d := 0
	var first := 0
	if v < 0x42d:
		d = (v - 0x149) & 0xffffffff
		first = 1
	else:
		d = (v - 0x465) & 0xffffffff
		first = 8
	if d <= 5:
		return first + d
	return d & 0xffff0000


## Joey FUN_00569720: primera zona de magia/trampa (5-10) de p boca arriba con ese id, o -1.
func f569720(p: int, card_id: int) -> int:
	for z in range(5, 11):
		var at := JoeyMem.zone(p, z)
		var index := m.u16(at) & 0xfff
		if index != 0 and (m.u8(at + 6) & 2) != 0:
			if (f4022e0(index) & 0xffff) == (card_id & 0xffff):
				return z
	return -1


## Joey FUN_00569790: 1 si la zona tiene ese id boca arriba, sin los bits 1 y 5 del estado y
## sin bloqueo de 56b440.
func f569790(p: int, z: int, card_id: int) -> int:
	var at := JoeyMem.zone(p, z)
	if (f4022e0(m.u16(at) & 0xfff) & 0xffff) != (card_id & 0xffffffff):
		return 0
	if (m.u8(at + 6) & 2) == 0 or (m.u8(at + 0x8c) & 0x22) != 0:
		return 0
	var e := m.u32(at)
	if f56b440(e & 0xfff, JoeyMem.ident(e)) == 0:
		return 1
	return 0


## Joey FUN_00569820: cartas de p con ese id boca arriba y utilizables (bits 1 y 5 del estado a
## 0, sin bloqueo de 56b440), salvo la zona `skip`: monstruos (0-4, ademas libres en a577f0) si
## el id es de monstruo y zonas 5-10 si no.
func f569820(p: int, card_id: int, skip: int) -> int:
	var count := 0
	var monster := (f4025d0(f402460(card_id)) & 0xffff) < 0x15
	var first := 0 if monster else 5
	var last := 5 if monster else 11
	var excluded := skip & 0xffffffff
	var id := card_id & 0xffff
	for z in range(first, last):
		var at := JoeyMem.zone(p, z)
		var entry := m.u32(at)
		var index := entry & 0xfff
		if index == 0 or z == excluded:
			continue
		if (f4022e0(index) & 0xffff) != id:
			continue
		var status := m.u32(at + 0x8c)
		if ((m.u8(at + 6) >> 1) & ~(status >> 5) & ~(status >> 1) & 1) == 0:
			continue
		# El desplazamiento usa p sin acotar: (p << 4) + z, modulo 32.
		if monster and ((1 << (((p << 4) + z) & 0x1f)) & m.u32(0xa577f0)) != 0:
			continue
		if f56b440(index, JoeyMem.ident(entry)) == 0:
			count += 1
	return count
