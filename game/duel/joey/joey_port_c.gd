class_name JoeyPortC
extends JoeyPortB
## Motor nativo de Joey, lote C de la etapa 1: 56b250-56cbd0 (M2: restricciones y consultas de vinculos).
## Cada funcion se llama f<direccion de Joey_Pc.exe> y sobrescribe su declaracion de joey_decl.gd
## con la misma aridad. Cotejo: re/scripts/joey_specs/port_c.py.

## Base de los objetos de zona (entrada u32 del objeto 0 del jugador 0).
const _JC_ZONES := 0xa55d74
## Cementerio (u32[]) y su contador (u8 en +0xa del jugador); exclusion (u32[]) y su contador (+0xc).
const _JC_GRAVE := 0xa566f0
const _JC_GRAVE_N := 0xa55d6a
const _JC_BANISH := 0xa5686c
const _JC_BANISH_N := 0xa55d6c
## u16[] paralelo a la exclusion (+0xc88 del jugador): la marca de cada carta excluida.
const _JC_BANISH_TAG := 0xa569e8


## Desplazamiento del objeto de zona (p & 1, z) respecto de 0xa55d74, con z sin enmascarar.
static func _jc_zo(p: int, z: int) -> int:
	return ((p & 1) * JoeyMem.PLAYER_SIZE + z * JoeyMem.ZONE_SIZE) & 0xffffffff


## 1 si el objeto de zona at (estado en +0x8c) esta boca arriba y sin los bits 1 y 5 del estado.
func _jc_face_up_live(at: int) -> bool:
	var status := m.u32(at + 0x8c)
	return ((m.u8(at + 6) >> 1) & ~(status >> 5) & ~(status >> 1) & 1) != 0


## Joey FUN_0056b250: busca en los monstruos de ambos lados un vinculo de tipo 1-2/4-8 que
## apunte a (p, z); devuelve zona << 8 | jugador o 0xffff. Si (p, z) esta vacia, EAX conserva
## la mitad alta de z.
func f56b250(p: int, z: int) -> int:
	if (m.u32(_JC_ZONES + _jc_zo(p, z)) & 0xfff) == 0:
		return (z & 0xffff0000) | 0xffff
	var key := ((z & 0xff) << 8) | (p & 0xff)
	for q in 2:
		for i in 5:
			var at := JoeyMem.zone(q, i)
			if (m.u32(at) & 0xfff) == 0 or (m.u8(at + 6) & 2) == 0:
				continue
			var n := m.u16(at + JoeyMem.Z_LINKS_N)
			for k in n:
				match m.u8(at + JoeyMem.Z_LINK_KIND + k * 2) & 0xf:
					1, 2, 4, 5, 6, 7, 8:
						if m.u16(at + JoeyMem.Z_LINK_REF + k * 2) == key:
							return (i << 8) | q
	return 0xffff


## Joey FUN_0056b360: en las zonas 0-10 de ambos lados, cambia por `value` las referencias
## de vinculos de tipo 2/6/7 que apuntan a `ref`.
func f56b360(ref: int, value: int) -> int:
	ref &= 0xffff
	for q in 2:
		for z in 11:
			var at := JoeyMem.zone(q, z)
			if (m.u32(at) & 0xfff) == 0 or m.u16(at + JoeyMem.Z_LINKS_N) == 0:
				continue
			var k := 0
			while k < m.u16(at + JoeyMem.Z_LINKS_N):
				var kind := m.u8(at + JoeyMem.Z_LINK_KIND + k * 2) & 0xf
				if (kind == 2 or (kind > 5 and kind < 8)) and m.u16(at + JoeyMem.Z_LINK_REF + k * 2) == ref:
					m.set_u16(at + JoeyMem.Z_LINK_REF + k * 2, value & 0xffff)
				k += 1
	return 0


## Joey FUN_0056b440: 1 si un 0x48a activo en las zonas 5-10 de algun lado afecta a la carta
## (indice, identidad): todos sus vinculos de tipo 9 la cubren (5674e0) y ninguno de tipo 0xb
## del propio 0x48a lleva esa identidad. Con identidad 0, 0.
func f56b440(index: int, ident: int) -> int:
	if ident == 0:
		return 0
	for q in 2:
		for z in range(5, 11):
			var at := JoeyMem.zone(q, z)
			if (m.u8(at + JoeyMem.Z_FLAGS) & 2) == 0:
				continue
			if (f4022e0(m.u16(at) & 0xfff) & 0xffff) != 0x48a or not _jc_face_up_live(at):
				continue
			var k := 0
			while true:
				if k >= m.u16(at + JoeyMem.Z_LINKS_N):
					return 1
				var link := at + JoeyMem.Z_LINK_REF + k * 2
				var kind := m.u8(at + JoeyMem.Z_LINK_KIND + k * 2) & 0xf
				if kind == 9:
					if f5674e0(index, m.u16(link)) == 0:
						break
					if _s32(ident) < 0:
						return 1
				elif kind == 0xb and m.u16(link) == (f402460(0x48a) & 0xffff):
					if m.u8(at + JoeyMem.Z_LINK_KIND + k * 2 + 1) == ident:
						break
				k += 1
	return 0


## Joey FUN_0056b5a0: 1 si el monstruo de (p, z) puede cambiar de posicion; si no, muestra
## la ayuda 3 (ya cambiado), 0x12 (impedido) o 0x10 (0x48a) cuando p es el jugador local.
func f56b5a0(p: int, z: int) -> int:
	var off := _jc_zo(p, z)
	if (m.u32(_JC_ZONES + off) & 0xfff) == 0:
		return 0
	if (m.u32(0xa55e00 + off) & 0x20000) != 0:
		if p == (m.u32(JoeyMem.MODE) & 1):
			f45e240(3)
		return 0
	var blocked := true
	if f5709d0(p, 0x3ca) == 0 and f56d790(p, z, 0x15c) == 0 and f56d790(p, z, 0x4dc) == 0:
		var own := int((f4022e0(m.u16(_JC_ZONES + off) & 0xfff) & 0xffff) == 0x536)
		if _s32(f5699c0(0x536) - own) <= 0 and f56db30(p, z, 0x540) == 0:
			if _s32(f5699c0(0x148)) <= 0 or (m.u8(0xa55d7a + off) & 2) == 0 \
					or (f56f6d0(p, z) & 0xffff) != 1:
				blocked = false
	if blocked:
		if p == (m.u32(JoeyMem.MODE) & 1):
			f45e240(0x12)
		return 0
	var entry := m.u32(_JC_ZONES + off)
	if f56b440(entry & 0xfff, JoeyMem.ident(entry)) == 0:
		return 1
	if p == (m.u32(JoeyMem.MODE) & 1):
		f45e240(0x10)
	return 0


## Joey FUN_0056b730: 1 si el monstruo boca arriba de (p, z) puede atacar (boca abajo solo el
## 0x31c) y no ha atacado ya (bit z de +0x10 del jugador); el resto lo decide 56b7d0.
func f56b730(p: int, z: int, check: int) -> int:
	var off := _jc_zo(p, z)
	var index := m.u32(_JC_ZONES + off) & 0xfff
	if index == 0:
		return 0
	var flags := m.u16(0xa55d7a + off)
	if (flags & 2) == 0:
		return 0
	if (flags & 1) != 0 and (f4022e0(index) & 0xffff) != 0x31c:
		return 0
	if ((1 << (z & 0x1f)) & m.u16(JoeyMem.pl(p) + 0x10)) != 0:
		return 0
	return f56b7d0(p, z, check)


## Joey FUN_0056b7d0: 1 si el monstruo de (p, z) puede atacar segun los efectos en juego; con
## `check` tambien comprueba el ataque directo (LP, mazo, 0x226/0x2d6...). Si no, ayuda 0x13
## (0x10 por 0x48a) cuando p es el jugador local.
func f56b7d0(p: int, z: int, check: int) -> int:
	return _jc_can_attack(p, z, check, 0)


## `stats` recibe las estadísticas efectivas si el llamador también las necesita.
func _jc_can_attack(p: int, z: int, check: int, stats: int) -> int:
	var off := _jc_zo(p, z)
	var index := m.u32(_JC_ZONES + off) & 0xfff
	var shield := f56c460(p, z)
	var r := _jc_attack_eval(p, z, check, off, index, shield, stats)
	if r < 0 and p == (m.u32(JoeyMem.MODE) & 1):
		f45e240(0x13)
	return int(r == 1)


## Cuerpo de 56b7d0: 1 permite, 0 rechaza sin ayuda (56a290, o 0x48a ya avisado), -1 rechaza
## con la ayuda 0x13.
func _jc_attack_eval(p: int, z: int, check: int, off: int, index: int, shield: int, stats: int) -> int:
	if (m.u32(0xa55e00 + off) & 0x40000) != 0:
		return -1
	if f56b440(index, JoeyMem.ident(m.u32(_JC_ZONES + off))) != 0:
		if p == (m.u32(JoeyMem.MODE) & 1):
			f45e240(0x10)
		return 0
	var info := m.local(12) if stats == 0 else stats
	f56dd30(p, z, info)
	var kind := m.u8(info + 2)
	var value := m.u32(info + 4)
	if shield == 0:
		if f569b30(p, 0x4ce, 2) != 0 or f569b30(1 - p, 0x4ce, 2) != 0:
			return -1
		if f56d790(p, z, 0x60c) != 0 or f56d790(p, z, 0x58b) != 0:
			return -1
	for card_id in [0x4dc, 0x15c, 0x2d9, 0x534]:
		if f56d790(p, z, card_id) != 0:
			return -1
	if _s32(f5699c0(0x52b)) > 0 and (f4026c0(index) & 0xffff) >= 4:
		return -1
	if (f4022e0(index) & 0xffff) == 0x5f3 and f569d50(1 - p) == 0:
		return -1
	var own := int((f4022e0(index) & 0xffff) == 0x536)
	if _s32(f5699c0(0x536) - own) > 0:
		return -1
	if f56db30(p, z, 0x261) != 0:
		return -1
	if f5699c0(0x602) != 0:
		var at := f5709f0(p, 0x602)
		if _s32(at) >= 0:
			var slot := (0xa563f1 + (at + (p & 1) * 0x6a2) * 2) & 0xffffffff
			if m.u8(slot) != JoeyMem.ident(m.u32(_JC_ZONES + off)):
				return -1
	if check == 0:
		return 1
	if shield == 0:
		if f569b30(1 - p, 0x15b, 3) != 0:
			return -1
		if f56d790(p, z, 0x417) != 0 and kind != 7:
			return -1
		if _s32(f5699c0(0x46b)) > 0 and value >= 0x5dc:
			return -1
		if _s32(f5699a0(1 - p, 0x548)) > 0 and kind == 10:
			return -1
	if f56bce0(kind) != 0:
		return -1
	var need := 0
	match f4022e0(index) & 0xffff:
		0x226:
			need = 1000
		0x2d6, 0x2d7, 0x2d8, 0x2fe:
			need = 500
		0x2e8, 0x2f9:
			if f56a290(p, ((z & 0xff) << 8) | (p & 0xff)) == 0:
				return 0
	if shield == 0:
		if (m.u16(0xa55d68 + (p & 1) * JoeyMem.PLAYER_SIZE) >> 8) < _s32(f5699a0(1 - p, 0x427)):
			return -1
		need = _s32(need + f5699c0(0x42a) * 500)
	if m.u16(0xa55d64 + (p & 1) * JoeyMem.PLAYER_SIZE) > need:
		return 1
	return -1


## Joey FUN_0056bce0: 1 si hay un 0x47a activo en magia/trampa de algun lado cuyo contador
## (+8) vale `value`.
func f56bce0(value: int) -> int:
	for q in 2:
		for z in range(5, 10):
			var at := JoeyMem.zone(q, z)
			if (m.u32(at) & 0xfff) == 0 or not _jc_face_up_live(at):
				continue
			if (f4022e0(m.u16(at) & 0xfff) & 0xffff) == 0x47a \
					and m.u16(at + JoeyMem.Z_COUNTER) == (value & 0xffff):
				return 1
	return 0


## Joey FUN_0056bd80: 1 si el monstruo de (p, z) puede atacar al de (q, w) (0x52e, 0x422,
## proteccion de 5675f0/56a780).
func f56bd80(p: int, z: int, q: int, w: int) -> int:
	var own_at := _JC_ZONES + _jc_zo(p, z)
	var own := m.u32(own_at) & 0xfff
	var target_off := _jc_zo(q, w)
	var target := m.u32(_JC_ZONES + target_off) & 0xfff
	if target == 0:
		return 0
	if (f4022e0(target) & 0xffff) == 0x52e and f56b220(0x14d) != 0 \
			and (m.u8(0xa55d7a + target_off) & 2) != 0 \
			and f56b440(target, JoeyMem.ident(m.u32(_JC_ZONES + target_off))) == 0:
		return 0
	if f56c460(p, z) == 0 and _s32(f56dcc0(q, 0x422)) > 0:
		return f56d740(q, w, 0x422)
	if f5675f0(own) != 0 and f56b440(own, JoeyMem.ident(m.u32(own_at))) == 0 and f56a780(q) != 0:
		if (m.u8(0xa55d7a + target_off) & 2) == 0 or f5675f0(target) == 0:
			return 0
		if f56b440(target, JoeyMem.ident(m.u32(_JC_ZONES + target_off))) != 0:
			return 0
	return 1


## Joey FUN_0056bf20: 1 si los monstruos del rival son todos 0x52e boca arriba bajo 0x14d (o
## no hay) y la carta de (p, z) no es 0x5f3.
func f56bf20(p: int, z: int) -> int:
	var rival := (-1 - p) & 1
	for i in 5:
		var at := JoeyMem.zone(rival, i)
		var index := m.u32(at) & 0xfff
		if index == 0:
			continue
		if (f4022e0(index) & 0xffff) != 0x52e or f56b220(0x14d) == 0 or (m.u8(at + 6) & 2) == 0:
			return 0
	return int((f4022e0(m.u16(_JC_ZONES + _jc_zo(p, z)) & 0xfff) & 0xffff) != 0x5f3)


## Joey FUN_0056bfd0: 1 si la carta de (p, z) puede atacar directamente por su propio efecto
## (0x182, 0x27a...; 0x2d6-0x2d8/0x2fe sin monstruos rivales; 0x32c segun 56a810).
func f56bfd0(p: int, z: int) -> int:
	var entry := m.u32(_JC_ZONES + _jc_zo(p, z))
	if f56b440(entry & 0xfff, JoeyMem.ident(entry)) != 0:
		return 0
	match f4022e0(entry & 0xfff) & 0xffff:
		0x182, 0x18c, 0x18d, 0x1a5, 0x1e7, 0x27a:
			return 1
		0x2d6, 0x2d7, 0x2d8, 0x2fe:
			return int(f56a780(1 - p) == 0)
		0x32c:
			return f56a810(1 - p)
	return 0


## Joey FUN_0056c180: marca el monstruo de (p, z) como ya cambiado de posicion (estado
## 0x20000) y como ya atacado (bit z de +0x10), salvo el 0x538 con la bandera 0x200, que la
## gasta en su lugar.
func f56c180(p: int, z: int) -> int:
	var off := _jc_zo(p, z)
	m.set_u32(0xa55e00 + off, m.u32(0xa55e00 + off) | 0x20000)
	if (f4022e0(m.u16(_JC_ZONES + off) & 0xfff) & 0xffff) == 0x538:
		var flags := m.u16(0xa55d7a + off)
		if (flags & 0x200) != 0:
			m.set_u16(0xa55d7a + off, flags & 0xfdff)
			return 0
	var at := JoeyMem.pl(p) + 0x10
	m.set_u16(at, m.u16(at) | ((1 << (z & 0x1f)) & 0xffff))
	return 0


## Joey FUN_0056c210: controlador de la carta de (p, z): propietario xor bit 0 del estado,
## cambiado por los vinculos de control (tipo 1: 0x42c/0x5ea/0x4ea; tipos 3/0xd: cartas de
## cambio de control).
func f56c210(p: int, z: int) -> int:
	var entry_at := f5700f0(p, 0, z)
	var off := _jc_zo(p, z)
	var owner := ((m.u32(entry_at) >> 12) & 1) ^ (m.u32(0xa55e00 + off) & 1)
	var shield := f56c460(p, z)
	var at := _JC_ZONES + off
	# El original pasa como indice EBX entero: mitad alta del desplazamiento, baja la referencia.
	var high := off & 0xffff0000
	var k := 0
	while k < m.u16(at + JoeyMem.Z_LINKS_N):
		var ref := m.u16(at + JoeyMem.Z_LINK_REF + k * 2)
		var kind := m.u8(at + JoeyMem.Z_LINK_KIND + k * 2)
		var extra := m.u8(at + JoeyMem.Z_LINK_KIND + k * 2 + 1)
		var arg := high | ref
		match kind & 0xf:
			1:
				var other := (((ref & 0xff) & 1) * JoeyMem.PLAYER_SIZE + (ref >> 8) * JoeyMem.ZONE_SIZE)
				var other_index := m.u32(_JC_ZONES + other) & 0xfff
				if other_index != 0 and (m.u8(0xa55d7a + other) & 2) != 0 \
						and (m.u8(0xa55e00 + other) & 0x20) == 0 \
						and (m.u32(0xa577ec) & 0x10000) == 0 and (m.u32(0xa577ec) & 0x10) == 0 \
						and (shield == 0 or (f4025d0(m.u16(_JC_ZONES + other) & 0xfff) & 0xffff) == 0x15):
					match f4022e0(m.u16(_JC_ZONES + other) & 0xfff) & 0xffff:
						0x42c, 0x5ea:
							owner = ref & 0xff
						0x4ea:
							owner = m.u16(0xa55d7c + other)
			3, 0xd:
				if (shield == 0 or (f4025d0(arg) & 0xffff) != 0x16) \
						and (f567620(arg, 0xffffffff) == 0 or f569b00(0x5fa) == 0):
					match f4022e0(arg) & 0xffff:
						0x228, 0x280, 0x3de, 0x403, 0x42c, 0x4bd, 0x4e7, 0x4ea, 0x5ea:
							owner = extra & 1
		k += 1
	return owner


## Joey FUN_0056c460: 1 si la carta de (p, z) es un 0x52e/0x531 boca arriba en zona de
## monstruo con 0x14d en juego y sin el 0x48a encima.
func f56c460(p: int, z: int) -> int:
	var off := _jc_zo(p, z)
	var index := m.u16(_JC_ZONES + off) & 0xfff
	if index == 0:
		return 0
	var card_id := f4022e0(index) & 0xffff
	if card_id != 0x52e and card_id != 0x531:
		return 0
	if f56b220(0x14d) == 0 or _s32(z) >= 5 or (m.u8(0xa55d7a + off) & 2) == 0:
		return 0
	if f56b440(index, JoeyMem.ident(m.u32(_JC_ZONES + off))) != 0:
		return 0
	return 1


## Joey FUN_0056c510: 1 si hay carta en (p, z) y no la bloquea 0x2e4 (monstruo boca arriba
## cuya 56f6d0 da 1).
func f56c510(p: int, z: int) -> int:
	var off := _jc_zo(p, z)
	if (m.u32(_JC_ZONES + off) & 0xfff) == 0:
		return 0
	if (m.u8(0xa55d7a + off) & 2) != 0 and _s32(z) < 5 and f5699c0(0x2e4) != 0:
		return int((f56f6d0(p, z) & 0xffff) != 1)
	return 1


## Joey FUN_0056c590: anade la entrada *ptr al cementerio de su propietario (salvo los ids
## 0x780-0x783).
func f56c590(ptr: int) -> int:
	var entry := m.u32(ptr)
	var q := (entry >> 12) & 1
	var count_at := _JC_GRAVE_N + q * JoeyMem.PLAYER_SIZE
	var dst := _JC_GRAVE + q * JoeyMem.PLAYER_SIZE + m.u8(count_at) * 4
	if (entry & 0xfff) == 0:
		return 0
	if (f4022e0(entry & 0xfff) & 0xffff) >= 0x780 and (f4022e0(m.u16(ptr) & 0xfff) & 0xffff) <= 0x783:
		return 0
	f5675c0(dst, ptr)
	_jc_bump_low(count_at, 1)
	return 0


## Suma delta al byte bajo del u16 de at sin tocar el alto (el original: (b+1 ^ b) ^ u16).
func _jc_bump_low(at: int, delta: int) -> int:
	var v := m.u16(at)
	v = (v & 0xff00) | ((v + delta) & 0xff)
	m.set_u16(at, v)
	return v


## Joey FUN_0056c640: anade la entrada *ptr a la exclusion de su propietario con la marca
## `tag` (salvo los ids 0x780-0x783).
func f56c640(ptr: int, tag: int) -> int:
	var entry := m.u32(ptr)
	var q := (entry >> 12) & 1
	var count_at := _JC_BANISH_N + q * JoeyMem.PLAYER_SIZE
	var n := m.u8(count_at)
	if (entry & 0xfff) == 0:
		return 0
	if (f4022e0(entry & 0xfff) & 0xffff) >= 0x780 and (f4022e0(m.u16(ptr) & 0xfff) & 0xffff) <= 0x783:
		return 0
	f5675c0(_JC_BANISH + q * JoeyMem.PLAYER_SIZE + n * 4, ptr)
	m.set_u16(_JC_BANISH_TAG + q * JoeyMem.PLAYER_SIZE + n * 2, tag & 0xffff)
	_jc_bump_low(count_at, 1)
	return 0


## Joey FUN_0056c720: quita la carta i del cementerio de p, corriendo las siguientes.
func f56c720(p: int, i: int) -> int:
	var count_at := _JC_GRAVE_N + (p & 1) * JoeyMem.PLAYER_SIZE
	if _s32(i) >= (m.u16(count_at) & 0xff):
		return 0
	var n := _jc_bump_low(count_at, -1) & 0xff
	var j := _s32(i)
	if j < n:
		var at := (_JC_GRAVE + (p & 1) * JoeyMem.PLAYER_SIZE + j * 4) & 0xffffffff
		while true:
			f5675c0(at, at + 4)
			j += 1
			at += 4
			if j >= m.u8(count_at):
				break
	return 1


## Joey FUN_0056c7c0: copia en *dst la carta i del cementerio de p y la quita.
func f56c7c0(p: int, i: int, dst: int) -> int:
	var count_at := _JC_GRAVE_N + (p & 1) * JoeyMem.PLAYER_SIZE
	if _s32(i) >= m.u8(count_at):
		return 0
	var j := _s32(i)
	var at := (_JC_GRAVE + (p & 1) * JoeyMem.PLAYER_SIZE + j * 4) & 0xffffffff
	f5675c0(dst, at)
	var n := _jc_bump_low(count_at, -1) & 0xff
	if j < n:
		while true:
			f5675c0(at, at + 4)
			j += 1
			at += 4
			if j >= m.u8(count_at):
				break
	return 1


## Compara una entrada con *ptr: entera desde la version 1001, solo el indice antes.
func _jc_same_entry(entry_at: int, ptr: int) -> bool:
	if _s32(f44baa0()) > 1000:
		return m.u32(ptr) == m.u32(entry_at)
	return ((m.u32(entry_at) ^ m.u32(ptr)) & 0xfff) == 0


## Joey FUN_0056c870: quita del cementerio de p la ultima carta igual a *ptr; 1 si la hay.
func f56c870(p: int, ptr: int) -> int:
	var i := m.u8(_JC_GRAVE_N + (p & 1) * JoeyMem.PLAYER_SIZE) - 1
	while i >= 0:
		if _jc_same_entry(_JC_GRAVE + (p & 1) * JoeyMem.PLAYER_SIZE + i * 4, ptr):
			return f56c720(p, i)
		i -= 1
	return 0


## Mueve la carta i del cementerio de p al final: la cambia por la casilla siguiente a la
## ultima y corre las demas (56c910/56c9e0).
func _jc_grave_to_end(p: int, i: int) -> void:
	var count_at := _JC_GRAVE_N + (p & 1) * JoeyMem.PLAYER_SIZE
	var grave := _JC_GRAVE + (p & 1) * JoeyMem.PLAYER_SIZE
	var at := grave + i * 4
	f5675d0(at, grave + m.u8(count_at) * 4)
	while i < m.u8(count_at):
		f5675c0(at, at + 4)
		i += 1
		at += 4


## Joey FUN_0056c910: lleva al final del cementerio de p la ultima carta con ese indice.
func f56c910(p: int, index: int) -> int:
	var grave := _JC_GRAVE + (p & 1) * JoeyMem.PLAYER_SIZE
	var i := m.u8(_JC_GRAVE_N + (p & 1) * JoeyMem.PLAYER_SIZE) - 1
	while i >= 0:
		if (m.u32(grave + i * 4) & 0xfff) == (index & 0xffff):
			_jc_grave_to_end(p, i)
			return 0
		i -= 1
	return 0


## Joey FUN_0056c9e0: lleva al final del cementerio de p la ultima carta con esa identidad.
func f56c9e0(p: int, ident: int) -> int:
	var grave := _JC_GRAVE + (p & 1) * JoeyMem.PLAYER_SIZE
	var i := m.u8(_JC_GRAVE_N + (p & 1) * JoeyMem.PLAYER_SIZE) - 1
	while i >= 0:
		if JoeyMem.ident(m.u32(grave + i * 4)) == (ident & 0xffff):
			_jc_grave_to_end(p, i)
			return 0
		i -= 1
	return 0


## Joey FUN_0056cac0: copia en *dst la ultima carta del cementerio de p con ese indice; 1 si
## la hay.
func f56cac0(p: int, index: int, dst: int) -> int:
	var grave := _JC_GRAVE + (p & 1) * JoeyMem.PLAYER_SIZE
	var i := m.u8(_JC_GRAVE_N + (p & 1) * JoeyMem.PLAYER_SIZE) - 1
	while i >= 0:
		if (m.u32(grave + i * 4) & 0xfff) == (index & 0xffff):
			f5675c0(dst, grave + i * 4)
			return 1
		i -= 1
	return 0


## Joey FUN_0056cb40: posicion (desde 1) de la primera carta del cementerio de p igual a
## *ptr; 0 si no esta.
func f56cb40(p: int, ptr: int) -> int:
	var count_at := _JC_GRAVE_N + (p & 1) * JoeyMem.PLAYER_SIZE
	var grave := _JC_GRAVE + (p & 1) * JoeyMem.PLAYER_SIZE
	var i := 0
	while i < m.u8(count_at):
		if _jc_same_entry(grave + i * 4, ptr):
			return i + 1
		i += 1
	return 0


## Joey FUN_0056cbd0: cuantas cartas con ese id hay en el cementerio de p.
func f56cbd0(p: int, card_id: int) -> int:
	var count_at := _JC_GRAVE_N + (p & 1) * JoeyMem.PLAYER_SIZE
	var grave := _JC_GRAVE + (p & 1) * JoeyMem.PLAYER_SIZE
	var found := 0
	var i := 0
	while i < m.u8(count_at):
		if (f4022e0(m.u16(grave + i * 4) & 0xfff) & 0xffff) == (card_id & 0xffff):
			found += 1
		i += 1
	return found
