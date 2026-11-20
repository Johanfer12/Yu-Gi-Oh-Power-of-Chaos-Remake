class_name DuelPortC
extends DuelPortB
## Modulo del porte del motor de duelo (ver docs/duel/PORTING.md).


# --- Campo: recuentos y vinculos de zona ------------------------------------------------

## FUN_005439a0: cartas boca arriba con ese id en las 11 zonas de p. `base` es el bloque de
## jugadores (siempre 0xa11944 desde FUN_00543a30); la entrada se comprueba ademas en el
## bloque fijo.
func f5439a0(base: int, p: int, card_id: int) -> int:
	var q := (p & 1) * PS
	var count := 0
	for z in 11:
		var zb := base + q + 0x18 + z * 0x94
		var ix := m.u16(zb) & 0xfff
		if ix != 0 and (m.u32(0xa1195c + q + z * 0x94) & 0xfff) != 0 \
				and (m.u8(zb + 6) & 2) != 0 and (m.u8(zb + 0x8f) & 4) == 0:
			if (f401a70(ix) & 0xffff) == (card_id & 0xffff):
				count += 1
	return count


## FUN_00543cf0: cuantos monstruos boca arriba "iguales" (FUN_00541c10) a la carta de la zona
## z de p hay en el campo: todas las zonas 0-4 del rival y las propias salvo z. 0 si la carta
## de z no esta boca arriba.
func f543cf0(p: int, z: int) -> int:
	var zone := 0xa1195c + (p & 1) * PS + z * 0x94
	var ix := m.u16(zone) & 0xfff
	if (m.u8(zone + 6) & 2) == 0:
		return 0
	if ix == 0:
		return 0
	var count := 0
	for i in 2:
		for j in 5:
			var side := p
			if i == 0:
				side = 1 - p
			elif z == j:
				continue
			var at := 0xa1195c + (side & 1) * PS + j * 0x94
			var other := m.u16(at) & 0xfff
			if other != 0 and (m.u8(at + 6) & 2) != 0 and f541c10(other, ix) != 0:
				count += 1
	return count


## FUN_00543e20: anade un vinculo (link, kind) a la zona `where` (bits 8-15 zona, bit 0
## jugador). Si ya existe (y kind no es 10) incrementa su contador (byte alto de +0x48).
func f543e20(where: int, link: int, kind: int) -> int:
	var z := (where >> 8) & 0xff
	var zone := 0xa1195c + (where & 1) * PS + z * 0x94
	var n := m.u16(zone + 0x88)
	if (kind & 0xffff) != 10:
		for i in n:
			if m.u16(zone + 8 + i * 2) == (link & 0xffff) \
					and m.u8(zone + 0x48 + i * 2) == (kind & 0xff):
				m.set_u8(zone + 0x49 + i * 2, m.u8(zone + 0x49 + i * 2) + 1)
				return 0
	m.set_u16(zone + 8 + n * 2, link)
	m.set_u16(zone + 0x48 + n * 2, kind)
	m.set_u16(zone + 0x88, m.u16(zone + 0x88) + 1)
	return 0


## FUN_00543ee0: quita de la zona `where` el primer vinculo de tipo kind (salvo para los
## tipos 4-7 y 9-12 tambien debe coincidir link).
func f543ee0(where: int, link: int, kind: int) -> int:
	var z := (where >> 8) & 0xff
	var zone := 0xa1195c + (where & 1) * PS + z * 0x94
	var n := m.u16(zone + 0x88)
	for i in n:
		if m.u8(zone + 0x48 + i * 2) != (kind & 0xffff):
			continue
		match kind & 0xffff:
			4, 5, 6, 7, 9, 10, 0xb, 0xc:
				pass
			_:
				if m.u16(zone + 8 + i * 2) != (link & 0xffff):
					continue
		f542c70(where & 0xff, z, i)
		return 0
	return 0


## FUN_00543f80: escribe el vinculo i de la zona `where`.
func f543f80(where: int, i: int, link: int, kind: int) -> int:
	var at := 0xa1195c + (where & 1) * PS + ((where >> 8) & 0xff) * 0x94 + i * 2
	m.set_u16(at + 8, link)
	m.set_u16(at + 0x48, kind)
	return 0


## FUN_00543fc0: id de la magia de campo boca arriba (mira primero al jugador 0), o 0.
func f543fc0() -> int:
	for p in 2:
		var zone := 0xa11f24 + p * PS
		var ix := m.u16(zone) & 0xfff
		if (m.u8(zone + 6) & 2) != 0 and ix != 0:
			return f401a70(ix)
	return 0


## FUN_00544000: busca un monstruo boca arriba (ambos jugadores, zonas 0-4) con un vinculo
## de tipo 1, 2, 5, 7 o 10 hacia (z << 8 | p). Devuelve (zona << 8 | jugador) o 0xffff.
## Si la zona z de p esta vacia devuelve 0xffff sin buscar.
func f544000(p: int, z: int) -> int:
	if (m.u32(0xa1195c + (p & 1) * PS + z * 0x94) & 0xfff) == 0:
		return 0xffff
	var target := ((z & 0xff) << 8) | (p & 0xff)
	for pl in 2:
		for j in 5:
			var zone := 0xa1195c + pl * PS + j * 0x94
			if (m.u32(zone) & 0xfff) == 0 or (m.u8(zone + 6) & 2) == 0:
				continue
			for i in m.u16(zone + 0x88):
				match m.u8(zone + 0x48 + i * 2):
					1, 2, 5, 7, 10:
						if m.u16(zone + 8 + i * 2) == target:
							return (j << 8) | pl
	return 0xffff


# --- Excluidas y cementerio -------------------------------------------------------------

## FUN_00544450: excluye la carta con informacion (zona << 8 | 1) y marca el bit de la zona
## en +0x12 del jugador (no limpia el bit 18 de la entrada, a diferencia de FUN_005443a0).
func f544450(entry_addr: int, zone_i: int) -> int:
	var entry := m.u32(entry_addr)
	var owner := (entry >> 12) & 1
	var q := owner * PS
	var dst := 0xa124b8 + q + m.u8(0xa1194a + q) * 4
	if (entry & 0xfff) == 0:
		return 0
	if f401a70(m.u16(entry_addr) & 0xfff) >= 0x780 \
			and f401a70(m.u16(entry_addr) & 0xfff) < 2000:
		return 0
	f541cb0(dst, entry_addr)
	m.set_u16(0xa125f8 + q + m.u8(0xa1194a + q) * 2, ((zone_i & 0xff) << 8) | 1)
	m.set_u8(0xa1194a + q, m.u8(0xa1194a + q) + 1)
	var bit := ((1 << (zone_i & 0x1f)) & 0xff) & 0x1f
	m.set_u16(0xa11956 + q, m.u16(0xa11956 + q) | bit)
	return 0


## FUN_00544520: devuelve a la zona z la carta excluida con informacion (z << 8 | 1) y
## limpia el bit de la zona en +0x12.
func f544520(p: int, z: int) -> int:
	var q := (p & 1) * PS
	var n := m.u8(0xa1194a + q)
	for i in n:
		var v := m.u16(0xa125f8 + q + i * 2)
		if (v & 0xff) != 1 or (v >> 8) != z:
			continue
		var at := 0xa124b8 + q + i * 4
		f541cb0(0xa1195c + z * 0x94 + q, at)
		m.set_u8(0xa1194a + q, m.u8(0xa1194a + q) - 1)
		var j := i
		while j < m.u8(0xa1194a + q):
			f541cb0(at, at + 4)
			j += 1
			at += 4
		m.set_u16(0xa11956 + q, m.u16(0xa11956 + q) & (~(1 << (z & 0x1f)) | 0xffe0))
		return 0
	return 0


## FUN_00544610: excluye la carta con informacion 2 (sin limpiar el bit 18 de la entrada).
func f544610(entry_addr: int) -> int:
	var entry := m.u32(entry_addr)
	var owner := (entry >> 12) & 1
	var q := owner * PS
	var count_at := 0xa1194a + q
	var n := m.u8(count_at)
	if (entry & 0xfff) == 0:
		return 0
	if f401a70(entry & 0xfff) >= 0x780 and f401a70(m.u16(entry_addr) & 0xfff) < 2000:
		return 0
	f541cb0(0xa124b8 + q + n * 4, entry_addr)
	m.set_u16(0xa125f8 + q + m.u8(count_at) * 2, 2)
	m.set_u8(count_at, m.u8(count_at) + 1)
	return 0


## FUN_00544890: lleva arriba del cementerio de p la ultima carta con ese indice (la
## intercambia con la entrada siguiente a la ultima y desplaza; el contador no cambia).
func f544890(p: int, index: int) -> int:
	var q := (p & 1) * PS
	var n := m.u8(0xa11948 + q)
	var i := n - 1
	while i >= 0:
		if (m.u32(0xa12238 + q + i * 4) & 0xfff) == (index & 0xffff):
			break
		i -= 1
	if i < 0:
		return 0
	var at := 0xa12238 + q + i * 4
	f541cc0(at, 0xa12238 + q + n * 4)
	while i < m.u8(0xa11948 + q):
		f541cb0(at, at + 4)
		i += 1
		at += 4
	return 0


## FUN_00544950: copia en out_addr la primera carta del cementerio con ese indice. 1 si la hay.
func f544950(p: int, index: int, out_addr: int) -> int:
	var q := (p & 1) * PS
	for i in m.u8(0xa11948 + q):
		var at := 0xa12238 + q + i * 4
		if (m.u32(at) & 0xfff) == (index & 0xffff):
			f541cb0(out_addr, at)
			return 1
	return 0


## FUN_00544a00: cartas con ese id en el cementerio de p.
func f544a00(p: int, card_id: int) -> int:
	var q := (p & 1) * PS
	var count := 0
	var i := 0
	while i < m.u8(0xa11948 + q):
		if (f401a70(m.u16(0xa12238 + q + i * 4) & 0xfff) & 0xffff) == (card_id & 0xffff):
			count += 1
		i += 1
	return count


## FUN_00544a80: quita la carta excluida i (y su informacion). 1 si existia.
func f544a80(p: int, i: int) -> int:
	var q := (p & 1) * PS
	var count_at := 0xa1194a + q
	if i >= m.u8(count_at):
		return 0
	m.set_u8(count_at, m.u8(count_at) - 1)
	var at := 0xa124b8 + q + i * 4
	var info := 0xa125f8 + q + i * 2
	while i < m.u8(count_at):
		f541cb0(at, at + 4)
		m.set_u16(info, m.u16(info + 2))
		i += 1
		at += 4
		info += 2
	return 1


## FUN_00544b20: quita de las excluidas la entrada igual a la de entry_addr.
func f544b20(p: int, entry_addr: int) -> int:
	var q := (p & 1) * PS
	for i in m.u8(0xa1194a + q):
		if m.u32(entry_addr) == m.u32(0xa124b8 + q + i * 4):
			return f544a80(p, i)
	return 0


# --- Condiciones --------------------------------------------------------------------------

## FUN_005450e0: 1 salvo si p != 0, sin el bit 0 del byte +0x0c del jugador, y sin las cartas
## 0x445 (rival), 0x461 (cualquiera) ni, en su turno, 0x480 en el campo. Siempre 1 si los
## bits 10-11 de 0xa114b4 valen 2. PENDIENTE: significado.
func f5450e0(p: int) -> int:
	if (m.u32(0xa114b4) & 0xc00) == 0x800:
		return 1
	if p == 0 or (m.u8(0xa11950 + (p & 1) * PS) & 1) != 0:
		return 1
	var other := 1 - p
	if f543a30(other, 0x445) > 0 or f543a30(p, 0x461) > 0 or f543a30(other, 0x461) > 0:
		return 1
	if p != (m.u8(0xa133f2) & 1):
		return 0
	if f543a30(p, 0x480) > 0 or f543a30(other, 0x480) > 0:
		return 1
	return 0


## FUN_005451a0: si hay en el campo la carta 0x49a y el monstruo de (p, z) tiene "iguales"
## (FUN_00543cf0), devuelve cuantas 0x49a hay; si no, 0.
func f5451a0(p: int, z: int) -> int:
	var c1 := f542f30(1, 0x49a)
	var c0 := f542f30(0, 0x49a)
	if c1 + c0 > 0 and f543cf0(p, z) > 0:
		return c1 + c0
	return 0


## FUN_00545730: como FUN_00545620 pero solo con los vinculos de tipo 1, 2, 10 (carta de la
## zona enlazada) y 3 (el propio valor del vinculo como indice); ignora las zonas enlazadas
## con el bit 2 de +0x8f.
func f545730(p: int, z: int, card_id: int) -> int:
	var zone := 0xa1195c + (p & 1) * PS + z * 0x94
	var count := 0
	var i := 0
	while i < m.u16(zone + 0x88):
		var link := m.u16(zone + 8 + i * 2)
		var kind := m.u8(zone + 0x48 + i * 2)
		var lzone := 0xa1195c + (link & 1) * PS + ((link >> 8) & 0xff) * 0x94
		if (m.u8(lzone + 0x8f) & 4) == 0:
			var ix := -1
			match kind:
				1, 2, 10:
					ix = m.u16(lzone) & 0xfff
				3:
					ix = link
			if ix >= 0 and (f401a70(ix) & 0xffff) == (card_id & 0xffff):
				count += 1
		i += 1
	return count


## FUN_00545c40: tipo efectivo (bits 20-24 de prop) del monstruo de la zona z de p. Si esta
## boca arriba en una zona 0-4 lo cambian, por orden de colocacion mas reciente: la carta
## 0x2fa propia con el bit 17 (tipo 10), la magia/trampa 0x479 boca arriba de cualquier
## jugador (tipo en los bits 11-15 de su +0x8e, si no tiene el bit 10) y un vinculo de tipo
## 1 a la carta 0x60e (tipo 1, salvo con 0x601 en el campo o los bits 8/7 de 0xa133ec).
## 0 si la zona esta vacia.
func f545c40(p: int, z: int) -> int:
	var q := (p & 1) * PS
	var zone := 0xa1195c + q + z * 0x94
	var ix := m.u16(zone) & 0xfff
	if ix == 0:
		return 0
	var result := (f401a20(ix) >> 0x14) & 0x1f
	if z >= 5 or (m.u8(zone + 6) & 2) == 0:
		return result
	var best := 0
	for j in 5:
		var mz := 0xa1195c + q + j * 0x94
		if (m.u32(mz) & 0xfff) != 0:
			if (f401a70(m.u16(mz) & 0xfff) & 0xffff) == 0x2fa and (m.u32(mz) & 0x20000) != 0 \
					and (m.u8(mz + 6) & 2) != 0 and m.u16(mz + 4) > best:
				best = m.u16(mz + 4)
				result = 10
		for pl in 2:
			var sz := 0xa11c40 + pl * PS + j * 0x94
			if (m.u32(sz) & 0xfff) == 0:
				continue
			if (f401a70(m.u16(sz) & 0xfff) & 0xffff) != 0x479 or (m.u8(sz + 6) & 2) == 0:
				continue
			var fl := m.u16(sz + 0x8e)
			if (fl & 0x400) == 0 and m.u16(sz + 4) > best:
				best = m.u16(sz + 4)
				result = fl >> 0xb
	var i := 0
	while i < m.u16(zone + 0x88):
		var link := m.u16(zone + 8 + i * 2)
		var lzone := 0xa1195c + (link & 1) * PS + ((link >> 8) & 0xff) * 0x94
		var lix := m.u16(lzone) & 0xfff
		if m.u8(zone + 0x48 + i * 2) == 1 and lix != 0 and (m.u8(lzone + 0x8f) & 4) == 0:
			if f542f30(0, 0x601) == 0 and f542f30(1, 0x601) == 0 \
					and (m.u16(0xa133ec) & 0x100) == 0 and (m.u8(0xa133ec) & 0x80) == 0:
				if (f401a70(lix) & 0xffff) == 0x60e and m.u16(lzone + 4) > best:
					result = 1
		i += 1
	return result & 0xffff


# --- Ataque y defensa -------------------------------------------------------------------

## Entero de 32 bits con signo (lo que guarda un int de C).
static func _s32c(v: int) -> int:
	v &= 0xffffffff
	return v - 0x100000000 if v >= 0x80000000 else v


## FUN_0053fbd0: mitad redondeada hacia arriba ((x * 5 + 5) / 10, division de C). Fuera del lote C.
func f53fbd0(x: int) -> int:
	return _s32c(_s32c(x * 5 + 5) / 10)


## FUN_00542ce0: numero de magia de campo (1-6 para 0x149-0x14e, 7 para 0x42d, 8-13 para
## 0x465-0x46a, 14 para 0x60b); en otro caso la parte alta de un resto (los 16 bits bajos a 0).
## Fuera del lote C.
func f542ce0(card_id: int) -> int:
	var v := card_id & 0xffff
	if v <= 0x42d:
		if v == 0x42d:
			return 7
		v = (v - 0x149) & 0xffffffff
		if v <= 5:
			return v + 1
	else:
		if v > 0x60b:
			return v & 0xffff0000
		if v == 0x60b:
			return 0xe
		v = (v - 0x465) & 0xffffffff
		if v <= 5:
			return v + 8
	return v & 0xffff0000


## FUN_005460a0: bonificacion de una carta equipada (index) al monstruo descrito en out
## (u16 indice, byte +2 tipo/atributo). Suma a los int de atk_addr y def_addr. Fuera del lote C.
func f5460a0(out: int, index: int, atk_addr: int, def_addr: int) -> int:
	var da := 0
	var dd := 0
	var t := m.u8(out + 2) & 0x1f
	var at := m.u8(out + 2) & 0xe0
	var hit300 := false
	var hit400 := false
	match f401a70(index) & 0xffff:
		0x12c:
			hit300 = t == 0xf
		0x12d:
			hit400 = at == 0x40
		0x12e:
			hit300 = t == 3
		0x12f:
			da = 1000
		0x130:
			hit300 = t == 10
		0x131:
			if t == 10:
				da = 700
		0x132:
			hit400 = at == 0x20
		0x133:
			hit300 = t == 0xb
		0x134:
			hit400 = at == 0x60
		0x135:
			hit300 = t == 0xd
		0x136, 0x28a:
			da = 500
		0x137:
			hit300 = t == 0x11
		0x138:
			dd = 800
		0x139:
			da = 700
			dd = 700
		0x13a:
			hit300 = t == 1
		0x13b:
			hit300 = t == 0x13
		0x13c:
			var own := f401a70(m.u16(out)) & 0xffff
			if own == 0x3d or own == 0x3e or own == 0x4e1:
				da = 500
		0x13e:
			hit300 = t == 0xc
		0x140:
			da = 700
		0x141:
			hit300 = t == 2
		0x142:
			hit300 = t == 0x12
		0x143:
			hit400 = at == 0xa0
		0x144:
			hit300 = t == 7
		0x145:
			hit300 = t == 9
		0x146:
			hit300 = t == 0x10
		0x147:
			hit300 = t == 0xe
		0x28d:
			if at == 0x80:
				da = 700
		0x291:
			hit300 = true
		0x29b:
			if at == 0x20:
				da = 700
		0x3f4:
			hit400 = at == 0x80
		0x3f5:
			hit400 = at == 0xc0
		0x412:
			da = 500
			dd = 500
		0x422:
			da = -500
			dd = -500
		0x49e:
			if t == 0xf:
				da = 700
		0x4da:
			da = -500
		0x58c:
			da = 1000
			dd = -1000
		0x58e:
			if t == 0xf:
				da = 800
		0x604:
			if (f401a70(m.u16(out)) & 0xffff) == 0x53b:
				da = 300
	if hit300:
		da = 300
		dd = 300
	if hit400:
		da = 400
		dd = -200
	m.set_u32(atk_addr, m.u32(atk_addr) + da)
	m.set_u32(def_addr, m.u32(def_addr) + dd)
	return 0


## FUN_00546470: calcula el monstruo efectivo de la zona z de p en out (8+4 bytes):
## u16 indice, byte +2 tipo (bits 0-4) y atributo (bits 5-7), int +4 ATK, int +8 DEF.
## Aplica los vinculos de la zona (equipos, contadores...), los efectos propios de la carta,
## la magia de campo y los modificadores globales de 0xa133ec.
func f546470(p: int, z: int, out: int) -> int:
	var q := (p & 1) * PS
	var zoff := z * 0x94 + q
	var zone := 0xa1195c + zoff
	m.set_u8(out + 2, 0)
	var acc := m.local(8)   # local_44 (+0) y local_38 (+4): se pasan por direccion
	var l24 := 0
	var l20 := 0
	var l8 := 0
	var lc := 0
	var l10 := 0
	var l48 := 0
	var l40 := 0
	var l50 := 0
	var l4c := 0
	var field_flag := 0   # local_1c
	m.set_u32(out + 4, 0)
	m.set_u32(out + 8, 0)
	var ix := m.u16(zone) & 0xfff
	m.set_u16(out, ix)
	if ix == 0:
		return 0
	m.set_u8(out + 2, (m.u8(out + 2) & 0xe0) | ((f401a20(ix) >> 0x14) & 0x1f))
	m.set_u8(out + 2, (m.u8(out + 2) & 0x1f) | (((f401a20(m.u16(out)) >> 0x1d) << 5) & 0xe0))
	m.set_u32(out + 4, f445810(m.u16(out)))
	m.set_u32(out + 8, f445850(m.u16(out)))
	if z >= 5:
		return 0
	if (m.u8(zone + 6) & 2) == 0:
		return 0
	match f401a70(m.u16(out)) & 0xffff:
		0x458:
			if (m.u16(zone + 6) & 0x1000) == 0:
				m.set_u32(out + 4, m.u32(out + 4) << 1)
		0x4e6:
			if (m.u16(zone + 6) & 0x1000) == 0:
				l50 = 500
				l4c = 500
		0x52e, 0x531:
			if (f543fc0() & 0xffff) == 0x14d:
				field_flag = 1
	# Cambios de tipo por colocacion mas reciente (como FUN_00545c40).
	var best := 0
	for j in 5:
		var mz := 0xa1195c + q + j * 0x94
		if (m.u32(mz) & 0xfff) != 0:
			if (f401a70(m.u16(mz) & 0xfff) & 0xffff) == 0x2fa and (m.u32(mz) & 0x20000) != 0 \
					and (m.u8(mz + 6) & 2) != 0 and m.u16(mz + 4) > best:
				best = m.u16(mz + 4)
				m.set_u16(out + 2, (m.u16(out + 2) & 0xffea) | 0xa)
		for pl in 2:
			var sz := 0xa11c40 + pl * PS + j * 0x94
			if (m.u32(sz) & 0xfff) == 0:
				continue
			if (f401a70(m.u16(sz) & 0xfff) & 0xffff) != 0x479 or (m.u8(sz + 6) & 2) == 0:
				continue
			var fl := m.u16(sz + 0x8e)
			if (fl & 0x400) == 0 and m.u16(sz + 4) > best:
				best = m.u16(sz + 4)
				m.set_u16(out + 2, (fl >> 0xb) | (m.u16(out + 2) & 0xffe0))
	# Vinculos de la zona.
	var i := 0
	while i < m.u16(zone + 0x88):
		var link := m.u16(zone + 8 + i * 2)
		var cnt := m.u8(zone + 0x49 + i * 2)
		var kind := m.u8(zone + 0x48 + i * 2)
		var lp := link & 0xff
		var lzone := 0xa1195c + ((link >> 8) & 0xff) * 0x94 + (link & 1) * PS
		var lix := m.u16(lzone) & 0xfff
		match kind:
			1:
				if lix != 0 and (m.u8(lzone + 0x8f) & 4) == 0 and f542f30(0, 0x601) == 0 \
						and f542f30(1, 0x601) == 0 and (m.u32(0xa133ec) & 0x100) == 0 \
						and (m.u8(0xa133ec) & 0x80) == 0 \
						and (field_flag == 0 or ((f401a20(lix) >> 0x14) & 0x1f) != 0x16):
					var lid := f401a70(lix) & 0xffff
					if (lid >= 0x12c and lid <= 0x13c) or lid == 0x13e \
							or (lid >= 0x140 and lid <= 0x147) \
							or lid in [0x28a, 0x28d, 0x291, 0x29b, 0x3f4, 0x3f5, 0x412, 0x422,
									0x49e, 0x4da, 0x58c, 0x58e, 0x604]:
						f5460a0(out, lix & 0xffff, acc, acc + 4)
					else:
						match lid:
							0x290:
								var other := (~lp) & 1
								var lp_own := m.u16(0xa11944 + (link & 1) * PS)
								var lp_other := m.u16(0xa11944 + other * PS)
								if lp_own < lp_other:
									m.set_u32(out + 4, f445810(m.u16(out)) << 1)
								if lp_own > lp_other:
									m.set_u32(out + 4, f53fbd0(f445810(m.u16(out))))
								l50 = 0
								l48 = 0
							0x3c2:
								if (m.u8(out + 2) & 0x1f) == 7:
									match m.u16(lzone + 0x8e) >> 0xb:
										1:
											m.set_u32(acc, m.u32(acc) + 700)
										2:
											m.set_u32(acc + 4, m.u32(acc + 4) + 700)
							0x416:
								if (m.u8(out + 2) & 0x1f) != 7:
									m.set_u32(acc, m.u32(acc) + ((m.u8(lzone + 6) >> 2) & 0xf) * -300)
							0x424:
								m.set_u32(acc, m.u32(acc) + 700 - ((m.u8(lzone + 6) >> 2) & 0xf) * 200)
							0x5a8:
								m.set_u8(out + 2, (m.u8(out + 2) & 0x1f) | ((m.u16(lzone + 0x8e) >> 6) & 0xe0))
							0x5a9:
								m.set_u32(acc, m.u32(acc) + f5431f0(lp, 1, 0) * 800)
								m.set_u32(acc + 4, m.u32(acc + 4) + f5431f0(lp, 1, 0) * 800)
							0x5aa:
								m.set_u32(acc, m.u32(acc) + f543480(lp, 0, 0, 1) * 500)
								m.set_u32(acc + 4, m.u32(acc + 4) + f543480(lp, 0, 0, 1) * 500)
							0x60e:
								if (m.u8(out + 2) & 0x1f) == 0xf:
									m.set_u16(out + 2, (m.u16(out + 2) & 0xffe1) | 1)
									m.set_u32(acc, m.u32(acc) + 500)
									m.set_u32(acc + 4, m.u32(acc + 4) + 500)
								if m.u16(lzone + 4) > best:
									m.set_u16(out + 2, (m.u16(out + 2) & 0xffe1) | 1)
				if (f401a70(m.u16(out)) & 0xffff) == 0x115 and (f401a70(lix) & 0xffff) == 0x47:
					m.set_u32(out + 4, 0)
					m.set_u32(out + 8, 2000)
				if lix != 0:
					l10 += 1
			2:
				if lix != 0 and (m.u8(lzone + 0x8f) & 4) == 0:
					match f401a70(lix) & 0xffff:
						0x52:
							if (m.u8(out + 2) & 0x1f) == 2:
								var n := mini(cnt + 1, 5)
								l50 += n * 200
								l4c += n * 200
						0x44b:
							if lp != p:
								l24 += 1
						0x4dc:
							l50 -= 700
			3:
				if field_flag == 0 or ((f401a20(link) >> 0x14) & 0x1f) != 0x16:
					match f401a70(link) & 0xffff:
						0x105, 0x433:
							l48 += 700 + cnt * 700
						0x1ac:
							if cnt == 0:
								l24 += 1
							else:
								l20 += 1
						0x3f7:
							l48 += 500 + cnt * 500
						0x3f8:
							l40 += 500 + cnt * 500
						0x434:
							l40 += 700 + cnt * 700
						0x43a:
							l40 += -500 - cnt * 500
						0x4b3:
							l48 += cnt * 100
							l40 += cnt * 100
						0x4b4:
							l48 -= cnt * 100
							l40 -= cnt * 100
						0x4cf:
							l48 += -500 - cnt * 500
						0x522:
							l20 += 1
						0x587:
							l48 += -700 - cnt * 700
						0x5fe:
							# El original reutiliza el contador del bucle de vinculos: queda a
							# 0 si el cementerio esta vacio o en su numero de cartas.
							i = 0
							while i < m.u8(0xa11948 + q):
								if ((f401a20(m.u16(0xa12238 + q + i * 4) & 0xfff) >> 0x14) & 0x1f) < 0x15:
									l48 += 100
								i += 1
			4:
				if field_flag == 0:
					m.set_u32(out + 4, m.u32(out + 4) + link)
			5:
				var own := f401a70(m.u16(out)) & 0xffff
				if own == 0x2da or own == 0x536:
					m.set_u32(out + 4, 0)
					m.set_u32(out + 8, 0)
					if (m.u8(lzone + 6) & 2) != 0:
						m.set_u32(out + 4, f445810(lix))
						m.set_u32(out + 8, f445850(lix))
			8:
				l50 += f445810(link)
				l4c += f445850(link)
			9:
				l50 += -500 - cnt * 500
				l4c += -500 - cnt * 500
			10:
				m.set_u32(acc, m.u32(acc) + 200)
			11:
				m.set_u32(acc, m.u32(acc) + cnt * 300)
			12:
				l50 += cnt * -200
		i += 1
	# Efectos propios de la carta.
	match f401a70(m.u16(out)) & 0xffff:
		0xb:
			l50 += f542f30(p, 0x229) * 500
		0x62:
			var fl := m.u16(zone + 6)
			var n := (fl >> 2) & 0xf
			if n > 4:
				n = 4
			var up := (~(fl >> 0xc)) & 1
			l50 += (n + up) * 100
			l4c += (n + up) * 100
		0xea:
			l50 += f542f50(0, 0xd) * 100
			l50 += f542f50(1, 0xd) * 100
		0x16f:
			var j := 0
			while j < m.u8(0xa11948 + q):
				if ((f401a20(m.u16(0xa12238 + q + j * 4) & 0xfff) >> 0x14) & 0x1f) < 0x15:
					l50 += 100
				j += 1
		0x181:
			var n := (f542f30(1, 0x4e1) + f542f30(0, 0x4e1) + f542f30(1, 0x3d) \
					+ f542f30(0, 0x3d)) * 300
			l50 += n
			l4c += n
		0x196:
			l50 += f542f50(0, 7) * 100
			l50 += f542f50(1, 7) * 100
		0x1ec:
			l50 += l10 * 500
		0x203:
			l50 += m.u8(0xa11946 + q) * 300
			l4c += m.u8(0xa11946 + q) * 300
		0x229:
			l50 += f542f30(p, 0xb) * 500
		0x267:
			if (m.u8(zone + 6) & 0x3c) < 8:
				l24 += 1
				l8 = 1
			else:
				l20 += 1
				lc = 1
		0x2f7:
			for pl in 2:
				var pq := pl * PS
				var j := 0
				while j < m.u8(0xa11948 + pq):
					var gid := f401a70(m.u16(0xa12238 + pq + j * 4) & 0xfff) & 0xffff
					if gid == 0x4ba or gid == 0x22 or gid == 0x2d1 or gid == 0x7f2:
						l50 += 300
					j += 1
		0x2f9:
			l50 += f542f50(0, 10) * 200
			l50 += f542f50(1, 10) * 200
		0x328:
			var oq := ((~p) & 1) * PS
			var j := 0
			while j < m.u8(0xa11948 + oq):
				if ((f401a20(m.u16(0xa12238 + oq + j * 4) & 0xfff) >> 0x14) & 0x1f) == 1:
					l50 += 500
				j += 1
			l50 += f542f50(1 - p, 1) * 500
		0x457:
			l50 -= m.u8(0xa11946 + q) * 400
			l4c -= m.u8(0xa11946 + q) * 400
		0x45e:
			if f5431b0(1 - p) > 0:
				l50 -= 1000
		0x585:
			l50 += f5431b0(1 - p) * -200
		0x5ec:
			if p == (m.u8(0xa133f2) & 1) and (m.u8(0xa133f2) & 0xe) == 6:
				l50 += 300
		0x5ee:
			if p != (m.u8(0xa133f2) & 1) and (m.u8(0xa133f2) & 0xe) == 6:
				l50 += 300
	if (m.u8(out + 2) & 0x1f) == 0xd:
		l50 += f543130(p, 0x4e4, 1) * 500
		l4c += f543130(p, 0x4e4, 1) * 500
	# Tabla 0x59e3e8: 6 filas de 8 s16 (id de carta y modificador por atributo).
	for r in 6:
		var row := 0x59e3e8 + r * 0x10
		var cid := m.s16(row)
		var n := f543010(1, cid) + f543010(0, cid)
		l50 += m.s16(row + ((m.u8(out + 2) >> 5) & 7) * 2) * n
	if (m.u8(out + 2) & 0xe0) == 0x60:
		l50 += (f542f30(1, 0x58e) + f542f30(0, 0x58e)) * -500
	# Magia de campo.
	if (m.u32(0xa133ec) & 0x200) == 0 and field_flag == 0:
		for pl in 2:
			var fz := 0xa11f24 + pl * PS
			var fix := m.u16(fz) & 0xfff
			if fix == 0 or (m.u8(fz + 0x8f) & 4) != 0 or (m.u8(fz + 6) & 2) == 0:
				continue
			if (m.u8(0xa133ec) & 0xf) != (f542ce0(f401a70(fix)) & 0xffff):
				continue
			var fid := f401a70(fix) & 0xffff
			if fid == 0x42d:
				if (m.u8(zone + 6) & 1) != 0:
					l4c += 500
			elif fid >= 0x149 and fid <= 0x14e:
				var v := m.s16(0x59e268 + ((m.u8(out + 2) & 0x1f) + (fid - 0x149) * 0x18) * 2)
				l50 += v
				l4c += v
			elif fid >= 0x465 and fid <= 0x46a:
				var v := m.s16(0x59e388 + (((m.u8(out + 2) >> 5) & 7) + fid * 8 - 9000) * 2)
				l50 += v * 500
				l4c += v * -400
			break
	if p == (m.u8(0xa133f2) & 1) and (m.u8(0xa133f2) & 0xe) == 6 \
			and f543010(1 - p, 0x5eb) != 0:
		l50 -= 300
	l50 += f5451a0(p, z) * 500
	l4c += f5451a0(p, z) * 500
	var a44 := _s32c(m.u32(acc))
	var a38 := _s32c(m.u32(acc + 4))
	var atk := 0
	var def := 0
	var g := m.u32(0xa133ec)
	var reverse_modifiers := ((g & 0x1000) != 0 and (g & 0x40) == 0)
	if not reverse_modifiers:
		atk = _s32c(m.u32(out + 4)) + l50 + l48 + a44
		def = _s32c(m.u32(out + 8)) + l4c + l40 + a38
	else:
		atk = _s32c(m.u32(out + 4)) - (l50 + l48 + a44)
		def = _s32c(m.u32(out + 8)) - (l4c + l40 + a38)
	m.set_u32(out + 4, atk)
	m.set_u32(out + 8, def)
	if _s32c(atk) < 0:
		m.set_u32(out + 4, 0)
	if _s32c(m.u32(out + 8)) < 0:
		m.set_u32(out + 8, 0)
	# Duplicar o reducir a la mitad segun los contadores.
	var halves := l24
	if (m.u8(zone + 0x8e) & 0x10) != 0:
		halves += 1
	if halves < l20:
		var v := _s32c(m.u32(out + 4))
		for k in l20 - halves:
			v = _s32c(v * 2)
		m.set_u32(out + 4, v)
	if l20 < halves:
		for k in halves - l20:
			m.set_u32(out + 4, f53fbd0(_s32c(m.u32(out + 4))))
	if l8 < lc:
		var v := _s32c(m.u32(out + 8))
		for k in lc - l8:
			v = _s32c(v * 2)
		m.set_u32(out + 8, v)
	if lc < l8:
		for k in l8 - lc:
			m.set_u32(out + 8, f53fbd0(_s32c(m.u32(out + 8))))
	if (g & 0x2000) != 0 and (g & 0x20) == 0 and field_flag == 0:
		var t := m.u32(out + 4)
		m.set_u32(out + 4, m.u32(out + 8))
		m.set_u32(out + 8, t)
	return 0


# --- Vinculos: renombrar ----------------------------------------------------------------

## FUN_00548690: en todas las zonas ocupadas de ambos jugadores, cambia los vinculos de tipo
## 2 que apuntan a `old` (zona << 8 | jugador, byte bajo completo) por `new`.
func f548690(old: int, new: int) -> int:
	var lo := old & 0xff
	var hi := (old >> 8) & 0xff
	for pl in 2:
		for z in 11:
			var zone := 0xa1195c + pl * PS + z * 0x94
			if (m.u32(zone) & 0xfff) == 0:
				continue
			var i := 0
			while i < m.u16(zone + 0x88):
				var at := zone + 8 + i * 2
				var link := m.u16(at)
				if m.u8(zone + 0x48 + i * 2) == 2 and (link & 0xff) == lo and (link >> 8) == hi:
					m.set_u16(at, new)
				i += 1
	return 0


# --- Manejadores de comando ---------------------------------------------------------------

## 0x32 FUN_00547ca0: en los monstruos de p pasa el bit 2 de +0x8e al bit 3 y limpia el bit 0;
## la carta 0x538 recibe el bit 4 de +0x07. Despues FUN_00571c30(0xa11944, p, 0, 1).
func f547ca0() -> int:
	var p := cmd_player()
	# En normal40ce80 lo llama la interfaz; en replay, este manejador.
	# La escena común necesita el asiento atacante en ambos modos.
	present("cmd32", {"p": p})
	for z in 5:
		var zone := 0xa1195c + (p & 1) * PS + z * 0x94
		var fl := m.u16(zone + 0x8e)
		if (fl & 4) != 0:
			m.set_u16(zone + 0x8e, (fl & 0xfffb) | 8)
		m.set_u8(zone + 0x8e, m.u8(zone + 0x8e) & 0xfe)
		if (f401a70(m.u16(zone) & 0xfff) & 0xffff) == 0x538:
			m.set_u8(zone + 7, m.u8(zone + 7) | 0x10)
	f571c30(0xa11944, p, 0, 1)
	finish()
	return 0


## 0x35 FUN_00547d40
func f547d40() -> int:
	f5715c0(cmd_player(), cmd_a())
	finish()
	return 0


## 0x36 FUN_00547d70: banderas 0 (si a) y 1 (si b) del byte +0x08 del jugador.
func f547d70() -> int:
	var p := cmd_player()
	if cmd_a() != 0:
		m.set_u8(0xa1194c + (p & 1) * PS, m.u8(0xa1194c + (p & 1) * PS) | 1)
	if cmd_b() != 0:
		m.set_u8(0xa1194c + (p & 1) * PS, m.u8(0xa1194c + (p & 1) * PS) | 2)
	finish()
	return 0


## 0x37 FUN_00547dd0: (salvo en red en el turno del jugador 1) limpia +0x14 de ambos
## jugadores, con a limpia el bit 6 del byte +0x08 del rival, y en 0xa133f2 limpia los bits
## 7-8 y 11-14 y pone los bits 9-10 (PENDIENTE: significado).
func f547dd0() -> int:
	var p := cmd_player()
	if (m.u8(0xa16181) & 1) == 0 or (m.u8(0xa133f2) & 1) == 0:
		m.set_u16(0xa11958, 0)
		m.set_u16(0xa126ac, 0)
		if cmd_a() != 0:
			var at := 0xa1194c + ((-p - 1) & 1) * PS
			m.set_u8(at, m.u8(at) & 0xbf)
		m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x867f) | 0x600)
	finish()
	return 0


## 0x38 FUN_00547e50: bits 11-13 de 0xa114c0 = bits 8-10 de a; con b, ademas 0xa133f4 = 0
## y en 0xa133f2 limpia los bits 7 y 10-14 y pone los bits 8-9.
func f547e50() -> int:
	if (m.u8(0xa16181) & 1) == 0 or (m.u8(0xa133f2) & 1) == 0:
		m.set_u16(0xa114c0, ((m.u8(0xa14f23) & 7) << 0xb) | (m.u32(0xa114c0) & 0xc7ff))
		if cmd_b() != 0:
			m.set_u8(0xa133f4, 0)
			m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x837f) | 0x300)
	finish()
	return 0


## 0x39 FUN_00547ec0: como 0x38 pero en los bits 8-10 de 0xa114c0.
func f547ec0() -> int:
	if (m.u8(0xa16181) & 1) == 0 or (m.u8(0xa133f2) & 1) == 0:
		m.set_u16(0xa114c0, ((m.u8(0xa14f23) & 7) << 8) | (m.u32(0xa114c0) & 0xf8ff))
		if cmd_b() != 0:
			m.set_u8(0xa133f4, 0)
			m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x837f) | 0x300)
	finish()
	return 0


## 0x3a FUN_00547f30
func f547f30() -> int:
	m.set_u8(0xa114c0, m.u8(0xa114c0) | 0x40)
	finish()
	return 0


## 0x3b FUN_00547f50: (salvo en red en el turno del jugador 1) 0xa133f4 = 0 y en 0xa133f2
## limpia los bits 9 y 11-14 y pone los bits 7, 8 y 10; despues FUN_005715c0(p, a).
func f547f50() -> int:
	var p := cmd_player()
	var a := cmd_a()
	if (m.u8(0xa16181) & 1) == 0 or (m.u8(0xa133f2) & 1) == 0:
		m.set_u8(0xa133f4, 0)
		m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x85ff) | 0x580)
	f5715c0(p, a)
	finish()
	return 0


## 0x78 FUN_00547fc0: borra el indice de la carta de la zona a de p (deja las banderas).
func f547fc0() -> int:
	var at := 0xa1195c + (cmd_player() & 1) * PS + cmd_a() * 0x94
	if cmd_a() < 10 and (m.u16(at) & 0xfff) != 0:
		# La carta lógica sale antes del efecto de volteo; el objeto visual vive hasta 7a.
		# En magias/trampas (zonas 5-9) el objeto visual sigue en su zona hasta que 0xb5 lo
		# levanta (p. ej. Polimerizacion tras la invocacion de fusion).
		present("field_detach", {"p": cmd_player(), "zone": cmd_a(),
			"card": f401a70(m.u16(at) & 0xfff), "flags": m.u8(at + 6),
			"owner": (m.u16(at) >> 12) & 1, "hold": cmd_a() >= 5})
		headless_detached["%d:%d" % [cmd_player() & 1, cmd_a()]] = m.u16(at) & 0xfff
	m.set_u32(at, m.u32(at) & 0xfffff000)
	finish()
	return 0


## 0x7d FUN_00548000: crea la carta a (id) con banderas de b y la manda al cementerio.
func f548000() -> int:
	var tmp := m.local(4)
	var v := (cmd_b() << 16) | cmd_a()
	v = v ^ ((f401ad0(cmd_a() & 0xfff) ^ v) & 0xfff)
	m.set_u32(tmp, v)
	if (v & 0xfff) != 0:
		f544300(tmp)
	finish()
	return 0


## 0x7b FUN_00548060: excluye la carta de la zona a de p.
func f548060() -> int:
	var p := cmd_player()
	var z := cmd_a()
	match step():
		0:
			var zone := 0xa1195c + (p & 1) * PS + z * 0x94
			if (m.u32(zone) & 0xfff) == 0:
				finish()
				return 0
			f541cb0(DuelMem.MOVING_CARD, zone)
			f543780(p, z)
			var entry := m.u16(DuelMem.MOVING_CARD)
			present_card_motion(3, entry & 0xfff, animation_location(p, 0, z),
				animation_location((entry >> 12) & 1, DuelMem.LOC_BANISH, 1, 2), "field_to_banish",
				{"p": p, "zone": z, "card": f401a70(entry & 0xfff), "flags": m.u8(DuelMem.MOVING_CARD + 6)})
			next_step()
		1:
			if not anim_busy():   # FUN_00437860
				finish()
	return 0


## 0x7c FUN_00548140: excluye la carta de la zona a de p (con el bit 20 de la entrada).
func f548140() -> int:
	var p := cmd_player()
	var z := cmd_a()
	var zone := 0xa1195c + (p & 1) * PS + z * 0x94
	match step():
		0:
			if (m.u32(zone) & 0xfff) != 0:
				next_step()
				return 0
		1:
			next_step()
			return 0
		2:
			m.set_u32(zone, m.u32(zone) | 0x100000)
			f541cb0(DuelMem.MOVING_CARD, zone)
			f543780(p, z)
			var flags := m.u8(DuelMem.MOVING_CARD + 6)
			var index := m.u16(DuelMem.MOVING_CARD) & 0xfff
			present_card_motion(3, index, animation_location(p, 0, z, flags),
				animation_location(p, DuelMem.LOC_BANISH, 1, 2), "field_to_banish",
				{"p": p, "zone": z, "card": f401a70(index), "flags": flags})
			next_step()
			return 0
	finish()
	return 0


## 0x81 FUN_00548280: devuelve a la mano la carta de la zona a de p.
func f548280() -> int:
	var p := cmd_player()
	var z := cmd_a()
	var zone := 0xa1195c + (p & 1) * PS + z * 0x94
	match step():
		0:
			if (m.u32(zone) & 0xfff) == 0:
				finish()
				return 0
			next_step()
		1:
			f541cb0(DuelMem.MOVING_CARD, zone)
			f541be0(p, z)
			var entry := m.u16(DuelMem.MOVING_CARD)
			var index := entry & 0xfff
			var cid := f401a70(index)
			if not (cid > 0x77f and cid < 2000):
				var owner := (entry >> 12) & 1
				var to := animation_location(owner, DuelMem.LOC_FUSION, 1) if f542280(index) != 0 else \
					animation_location(owner, DuelMem.LOC_HAND, m.u8(DuelMem.pl(owner) + DuelMem.P_HAND_N), f5450e0(owner) << 1)
				present_card_motion(3, index, animation_location(p, 0, z, m.u8(zone + 6)), to,
					"field_to_hand", {"p": p, "zone": z, "card": cid})
			else:
				present("field_remove", {"p": p, "zone": z})
			next_step()
		_:
			f5437c0(p, z)
			finish()
	return 0


## 0x82 FUN_005484b0: devuelve encima del mazo la carta de la zona a de p.
func f5484b0() -> int:
	var p := cmd_player()
	var z := cmd_a()
	var zone := 0xa1195c + (p & 1) * PS + z * 0x94
	match step():
		0:
			if (m.u32(zone) & 0xfff) == 0:
				finish()
				return 0
			next_step()
		1:
			f541cb0(DuelMem.MOVING_CARD, zone)
			m.set_u32(zone, m.u32(zone) & 0xfffbffff)
			var entry := m.u16(DuelMem.MOVING_CARD)
			var index := entry & 0xfff
			var cid := f401a70(index)
			if not (cid > 0x77f and cid < 2000):
				var fusion := f542280(index) != 0
				present_card_motion(3, index, animation_location(p, 0, z, m.u8(zone + 6)),
					animation_location((entry >> 12) & 1, DuelMem.LOC_FUSION if fusion else DuelMem.LOC_DECK, int(fusion)),
					"field_to_deck", {"p": p, "zone": z, "card": cid})
			else:
				present("field_remove", {"p": p, "zone": z})
			next_step()
		_:
			f541be0(p, z)
			f543840(p, z)
			finish()
	return 0


## 0x83 FUN_00548730: mueve la carta (con toda su zona) de a (zona << 8 | jugador) a b.
func f548730() -> int:
	var sp := cmd_a() & 0xff
	var sz := cmd_a() >> 8
	var dp := cmd_b() & 0xff
	var dz := cmd_b() >> 8
	match step():
		0:
			if sz < 0xb and dz < 0xb:
				next_step()
			else:
				finish()
		1:
			var source := f5419b0(sp, sz, 0)
			var flags := m.u8(source + 6)
			f541cb0(DuelMem.MOVING_CARD, source)
			var index := m.u16(DuelMem.MOVING_CARD) & 0xfff
			present_card_motion(3, index, animation_location(sp, sz, 0, flags),
				animation_location(dp, dz, 0, flags & (3 if dz < 5 else 2)), "zone_move",
				{"from": cmd_a(), "to": cmd_b(), "card": f401a70(index)})
			next_step()
		_:
			var dst := 0xa1195c + (dp & 1) * PS + dz * 0x94
			var src := 0xa1195c + (sp & 1) * PS + sz * 0x94
			m.copy(dst, src, 0x94)
			f541cb0(dst, DuelMem.MOVING_CARD)
			m.clear(src, 0x94)
			m.set_u8(dst + 7, m.u8(dst + 7) & 0xfd)
			if dz >= 5:
				m.set_u16(dst + 6, m.u16(dst + 6) & 0xfffe)
			f548690((sz << 8) | sp, (dz << 8) | dp)
			finish()
	return 0


## 0x85 FUN_00548910: intercambia las zonas a y b (zona << 8 | jugador) y sus vinculos.
func f548910() -> int:
	var ap := cmd_a() & 0xff
	var az := cmd_a() >> 8
	var bp := cmd_b() & 0xff
	var bz := cmd_b() >> 8
	var za := 0xa1195c + (ap & 1) * PS + az * 0x94
	var zb := 0xa1195c + (bp & 1) * PS + bz * 0x94
	match step():
		0:
			if (m.u32(za) & 0xfff) != 0 and (m.u32(zb) & 0xfff) != 0:
				next_step()
			else:
				finish()
		1:
			f541cb0(DuelMem.MOVING_CARD, za)
			present_card_motion(6, 0,
				animation_field_location(ap, az, m.u8(zb + 6) & (3 if bz < 5 else 2)),
				animation_field_location(bp, bz, m.u8(za + 6)), "zone_swap", {"a": cmd_a(), "b": cmd_b()})
			next_step()
		_:
			var tmp := m.local(0x94)
			m.copy(tmp, zb, 0x94)
			m.copy(zb, za, 0x94)
			m.copy(za, tmp, 0x94)
			m.set_u16(za + 6, m.u16(za + 6) & 0xfdff)
			m.set_u16(zb + 6, m.u16(zb + 6) & 0xfdff)
			var a := (az << 8) | ap
			var b := (bz << 8) | bp
			var t := (bz << 8) | ((bp + 2) & 0xff)   # marca temporal
			f548690(a, t)
			f548690(b, a)
			f548690(t, b)
			finish()
	return 0


## 0x86 FUN_00548b70: anade el vinculo (a, c) a la zona b.
func f548b70() -> int:
	f543e20(cmd_b(), cmd_a(), cmd_c())
	finish()
	return 0


## 0x4d FUN_00548bb0: escribe el vinculo (a >> 8) de la zona (a & 0xff) de p con (b, c).
func f548bb0() -> int:
	f543f80(((cmd_a() & 0xff) << 8) | cmd_player(), cmd_a() >> 8, cmd_b(), cmd_c())
	finish()
	return 0
