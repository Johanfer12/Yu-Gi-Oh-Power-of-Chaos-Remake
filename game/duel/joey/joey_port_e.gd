class_name JoeyPortE
extends JoeyPortD
## Motor nativo de Joey, lote E de la etapa 1: 56dd30 (estadisticas efectivas) y 56f690-56fd40 (M2).
## Cada funcion se llama f<direccion de Joey_Pc.exe> y sobrescribe su declaracion de joey_decl.gd
## con la misma aridad. Cotejo: re/scripts/joey_specs/port_e.py.

const _JE_M32 := 0xffffffff
## Banderas globales del duelo (bits 4, 16, 17 y 20 anulan bonificaciones).
const _JE_RULES := 0xa577ec
## Tipo de campo activo (bits 0-3) que debe coincidir con 569660 de la magia de campo.
const _JE_FIELD_KIND := 0xa577f4
## Filas de 8 s16 (id de carta, valor por atributo 1-7) que suman al ATK segun el atributo.
const _JE_ATTR_TABLE := 0x5dcf98
## Bonos de los campos 0x149-0x14e: 0x18 s16 por campo, indexados por el tipo de monstruo.
const _JE_FIELD_TYPE_TABLE := 0x5dce18
## Bonos de los campos 0x465-0x46a: 8 s16 por campo, indexados por el atributo.
const _JE_FIELD_ATTR_TABLE := 0x5dcf38

# Acumuladores de 56dd30 (variables locales del original).
const _JE_ATK := 0        ## local_24: bonos de ATK propios y de vinculos de tipo 2
const _JE_DEF := 1        ## local_28
const _JE_ATK_EQ := 2     ## local_2c: vinculos de tipo 1 y 4
const _JE_DEF_EQ := 3     ## local_18
const _JE_ATK_LINK := 4   ## local_30: vinculos de tipo 3
const _JE_DEF_LINK := 5   ## local_20
const _JE_FIELD_ATK := 6  ## local_c: bono de campo pendiente (lo cobra un vinculo al campo)
const _JE_FIELD_DEF := 7  ## local_10
const _JE_SPECIAL := 8    ## local_8: 56c460 de la carta

## Ids que 56dd30 pasa a 56fd40 en los vinculos de tipo 1 (equipos y similares).
const _JE_FD40_IDS := [0x12c, 0x12d, 0x12e, 0x12f, 0x130, 0x131, 0x132, 0x133, 0x134, 0x135,
		0x136, 0x137, 0x138, 0x139, 0x13a, 0x13b, 0x13c, 0x13e, 0x140, 0x141, 0x142, 0x143, 0x144,
		0x145, 0x146, 0x147, 0x28a, 0x28d, 0x291, 0x29b, 0x3f4, 0x3f5, 0x412, 0x422, 0x49e, 0x4da,
		0x58c, 0x58e, 0x604]

## 56fd40: equipos de +300/+300 segun el tipo (u8) de la carta.
const _JE_FD40_KIND := {300: 0xf, 0x12e: 3, 0x130: 0xa, 0x133: 0xb, 0x135: 0xd, 0x137: 0x11,
		0x13a: 1, 0x13b: 0x13, 0x13e: 0xc, 0x141: 2, 0x142: 0x12, 0x144: 7, 0x145: 9, 0x146: 0x10,
		0x147: 0xe}
## 56fd40: equipos de +400/-200 segun el atributo (byte alto) de la carta.
const _JE_FD40_ATTR := {0x12d: 0x200, 0x132: 0x100, 0x134: 0x300, 0x143: 0x500, 0x3f4: 0x400,
		0x3f5: 0x600}


## Clave de identidad de una entrada: propietario + identidad * 2.
static func _je_key(entry: int) -> int:
	return ((entry >> 12) & 1) + ((entry >> 24) & 0x7f) * 2


## Carta de un vinculo viva: hay carta, sin el bit 5 de estado y sin las banderas globales 4 y 16.
func _je_link_live(at: int) -> bool:
	if (m.u32(at) & 0xfff) == 0 or (m.u8(at + JoeyMem.Z_STATUS) & 0x20) != 0:
		return false
	var rules := m.u32(_JE_RULES)
	return (rules & 0x10000) == 0 and (rules & 0x10) == 0


## Joey FUN_0056dd30: escribe en out (u16 indice, u8 tipo de 56f6d0, u8 atributo de 56f9e0,
## s32 ATK, s32 DEF) las estadisticas efectivas de la carta de (p, z): efecto propio, atributo,
## campo, vinculos (equipos, contadores, copias), intercambio 0x3c7 y mitades de 0x44b.
func f56dd30(p: int, z: int, out: int) -> int:
	var v := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	v[_JE_SPECIAL] = f56c460(p, z)
	var q := p & 1
	m.set_u16(out + 2, 0)
	m.set_u32(out + 4, 0)
	m.set_u32(out + 8, 0)
	var zo := JoeyMem.zone(q, z)
	var index := m.u16(zo) & 0xfff
	m.set_u16(out, index)
	if index == 0 or _s32(z) >= 5:
		return 0
	m.set_u16(out + 2, f56f6d0(p, z) & 0xff)
	m.set_u16(out + 2, ((f56f9e0(p, z) & 0xff) << 8) | m.u8(out + 2))
	m.set_u32(out + 4, f4027b0(m.u16(out)) & 0xffff)
	m.set_u32(out + 8, f402800(m.u16(out)) & 0xffff)
	if (m.u8(zo + JoeyMem.Z_FLAGS) & 2) == 0:
		return 0
	if (f56b440(m.u16(out), _je_key(m.u32(zo))) & _JE_M32) == 0:
		_je_own_effect(p, z, out, zo, v)
	var attr := m.u16(out + 2)
	if (attr & 0xff) != 0 and (attr & 0xff) < 0x15 and (attr & 0xff) == 0xd:
		v[_JE_ATK] += f569cd0(p, 0x4e4, 1) * 500
		v[_JE_DEF] += f569cd0(p, 0x4e4, 1) * 500
	attr = m.u16(out + 2) & 0xff00
	if attr != 0 and attr < 0x700 and v[_JE_SPECIAL] == 0:
		var column := attr >> 8
		for k in 6:
			var row := _JE_ATTR_TABLE + k * 16
			var bonus := m.s16(row + column * 2)
			# El recuento solo consulta la mesa. Una fila sin bono no aporta nada.
			if bonus != 0:
				v[_JE_ATK] += bonus * f5699c0(m.s16(row) & _JE_M32)
		if attr == 0x300:
			v[_JE_ATK] += f5699c0(0x58e) * -500
	var turn := m.u8(JoeyMem.TURN)
	if (p & _JE_M32) == (turn & 1) and (turn & 0xe) == 6:
		v[_JE_ATK] += f5699a0((1 - p) & _JE_M32, 0x5eb) * -300
	var n_520 := f56d520(p, z)
	v[_JE_ATK] += n_520 * 500
	v[_JE_DEF] += n_520 * 500
	if (m.u32(_JE_RULES) & 0x20000) == 0 and v[_JE_SPECIAL] == 0:
		_je_field_bonus(p, z, out, zo, v)
	var i := 0
	while i < m.u16(zo + JoeyMem.Z_LINKS_N):
		_je_link(p, z, out, zo, i, v)
		i += 1
	# 56daa0 impar (resto de C distinto de 0): intercambia ATK y DEF.
	if (f56daa0(p, z, 0x3c7) & 1) != 0:
		var atk := m.u32(out + 4)
		m.set_u32(out + 4, m.u32(out + 8))
		m.set_u32(out + 8, atk)
	var atk_bonus: int = v[_JE_ATK] + v[_JE_ATK_LINK] + v[_JE_ATK_EQ]
	var def_bonus: int = v[_JE_DEF] + v[_JE_DEF_LINK] + v[_JE_DEF_EQ]
	if (m.u32(_JE_RULES) & 0x100000) == 0:
		m.set_u32(out + 4, m.u32(out + 4) + atk_bonus)
		m.set_u32(out + 8, m.u32(out + 8) + def_bonus)
	else:
		m.set_u32(out + 4, m.u32(out + 4) - atk_bonus)
		m.set_u32(out + 8, m.u32(out + 8) - def_bonus)
	if _s32(m.u32(out + 4)) < 0:
		m.set_u32(out + 4, 0)
	if _s32(m.u32(out + 8)) < 0:
		m.set_u32(out + 8, 0)
	# dec eax / js: n - 1 >= 0 con signo y luego n vueltas (n tomado sin signo).
	var halves := f56d740(p, z, 0x44b) & _JE_M32
	if _s32(halves - 1) >= 0:
		while halves != 0:
			m.set_u32(out + 4, f5be050(m.u32(out + 4)))
			halves -= 1
	return 0


## 56dd30: efecto propio segun el id de la carta (salvo si 56b440 la anula).
func _je_own_effect(p: int, z: int, out: int, zo: int, v: Array) -> void:
	var q := p & 1
	var pl := JoeyMem.PLAYER + q * JoeyMem.PLAYER_SIZE
	match f4022e0(m.u16(out)) & 0xffff:
		0x62:
			var flags := m.u16(zo + JoeyMem.Z_FLAGS)
			var count := 4 if (flags & 0x3c) > 0x10 else (flags & 0x3c) >> 2
			v[_JE_ATK] = (count + ((~flags >> 9) & 1)) * 100
			v[_JE_DEF] = v[_JE_ATK]
		0xb:
			v[_JE_ATK] = f569ae0(p, 0x229) * 500
		0xea:
			var a := f569bf0(0, 0xd) * 100
			v[_JE_ATK] = a + f569bf0(1, 0xd) * 100
		0x16f:
			var i := 0
			while i < m.u8(pl + JoeyMem.P_GRAVE_N):
				if (f4025d0(m.u16(pl + JoeyMem.P_GRAVE + i * 4) & 0xfff) & 0xffff) < 0x15:
					v[_JE_ATK] += 100
				i += 1
		0x181:
			var a := f569b00(0x4e1)
			v[_JE_ATK] = (a + f569b00(0x3d)) * 300
			v[_JE_DEF] = v[_JE_ATK]
		0x196:
			var a := f569bf0(0, 7) * 100
			v[_JE_ATK] = a + f569bf0(1, 7) * 100
		0x1ec:
			v[_JE_ATK] = f56d5c0(p, z) * 500
		0x203:
			v[_JE_ATK] = m.u8(pl + JoeyMem.P_HAND_N) * 300
			v[_JE_DEF] = v[_JE_ATK]
		0x229:
			v[_JE_ATK] = f569ae0(p, 0xb) * 500
		0x267:
			if (m.u8(zo + JoeyMem.Z_FLAGS + 1) & 2) != 0:
				return
			var li := _s32(f56da10(p, z, 0x267))
			# Tipo alto del vinculo li de (p, z) igual a 1: ATK y DEF base dobles; si no, mitades.
			if li >= 0 and m.u8(0xa55dc1 + (li + z * 0x48 + q * 0x6a2) * 2) == 1:
				m.set_u32(out + 4, (f4027b0(m.u16(out)) & 0xffff) << 1)
				m.set_u32(out + 8, (f402800(m.u16(out)) & 0xffff) << 1)
			else:
				m.set_u32(out + 4, f5be050(f4027b0(m.u16(out)) & 0xffff))
				m.set_u32(out + 8, f5be050(f402800(m.u16(out)) & 0xffff))
		0x2f7:
			for c in 2:
				var plc := JoeyMem.PLAYER + c * JoeyMem.PLAYER_SIZE
				var i := 0
				while i < m.u8(plc + JoeyMem.P_GRAVE_N):
					var card_id := f4022e0(m.u16(plc + JoeyMem.P_GRAVE + i * 4) & 0xfff) & 0xffff
					if card_id == 0x22 or card_id == 0x2d1 or card_id == 0x4ba or card_id == 0x7f2:
						v[_JE_ATK] += 300
					i += 1
		0x2f9:
			var a := f569bf0(0, 10) * 200
			v[_JE_ATK] = a + f569bf0(1, 10) * 200
		0x328:
			var plo := JoeyMem.PLAYER + ((~p) & 1) * JoeyMem.PLAYER_SIZE
			var i := 0
			while i < m.u8(plo + JoeyMem.P_GRAVE_N):
				if (f4025d0(m.u16(plo + JoeyMem.P_GRAVE + i * 4) & 0xfff) & 0xffff) == 1:
					v[_JE_ATK] += 500
				i += 1
			v[_JE_ATK] += f569bf0((1 - p) & _JE_M32, 1) * 500
		0x457:
			v[_JE_ATK] = m.u8(pl + JoeyMem.P_HAND_N) * -400
			v[_JE_DEF] = v[_JE_ATK]
		0x45e:
			if _s32(f569d50((1 - p) & _JE_M32)) > 0:
				v[_JE_ATK] = -1000
		0x4e6:
			if (f569b00(0x5fa) & _JE_M32) == 0 and (m.u8(zo + JoeyMem.Z_FLAGS + 1) & 2) == 0:
				v[_JE_ATK] = 500
				v[_JE_DEF] = 500
		0x585:
			v[_JE_ATK] = f569d50((1 - p) & _JE_M32) * -200
		0x5ec:
			var turn := m.u8(JoeyMem.TURN)
			if (p & _JE_M32) == (turn & 1) and (turn & 0xe) == 6:
				v[_JE_ATK] = 300
		0x5ee:
			var turn := m.u8(JoeyMem.TURN)
			if (p & _JE_M32) != (turn & 1) and (turn & 0xe) == 6:
				v[_JE_ATK] = 300


## 56dd30: magia de campo boca arriba (primera de los dos lados cuyo 569660 coincide con
## a577f4). Si no esta vinculada a la carta se suma ya; si lo esta, queda pendiente.
func _je_field_bonus(p: int, z: int, out: int, zo: int, v: Array) -> void:
	for c in 2:
		var fz := JoeyMem.zone(c, 10)
		var fi := m.u16(fz) & 0xfff
		if fi == 0 or (m.u8(fz + JoeyMem.Z_STATUS) & 0x20) != 0 or (m.u8(fz + JoeyMem.Z_FLAGS) & 2) == 0:
			continue
		if (f569660(f4022e0(fi)) & 0xffff) != (m.u8(_JE_FIELD_KIND) & 0xf):
			continue
		var field_id := f4022e0(fi) & 0xffff
		if field_id == 0x42d:
			if (m.u8(zo + JoeyMem.Z_FLAGS) & 1) != 0:
				v[_JE_FIELD_DEF] = 500
		elif field_id >= 0x149 and field_id <= 0x14e:
			var kind := m.u16(out + 2) & 0xff
			if kind != 0 and kind < 0x15:
				v[_JE_FIELD_ATK] = m.s16(_JE_FIELD_TYPE_TABLE
						+ (m.u8(out + 2) + ((f4022e0(fi) & 0xffff) - 0x149) * 0x18) * 2)
				v[_JE_FIELD_DEF] = m.s16(_JE_FIELD_TYPE_TABLE
						+ (m.u8(out + 2) + ((f4022e0(fi) & 0xffff) - 0x149) * 0x18) * 2)
		elif field_id >= 0x465 and field_id <= 0x46a:
			var attr := m.u16(out + 2) & 0xff00
			if attr != 0 and attr < 0x700:
				v[_JE_FIELD_ATK] = m.s16(_JE_FIELD_ATTR_TABLE
						+ ((m.u16(out + 2) >> 8) + (f4022e0(fi) & 0xffff) * 8 - 9000) * 2) * 500
				v[_JE_FIELD_DEF] = m.s16(_JE_FIELD_ATTR_TABLE
						+ ((m.u16(out + 2) >> 8) + (f4022e0(fi) & 0xffff) * 8 - 9000) * 2) * -400
		if (f56dc10(p, z, c, 10) & _JE_M32) == _JE_M32:
			v[_JE_DEF] += v[_JE_FIELD_DEF]
			v[_JE_ATK] += v[_JE_FIELD_ATK]
			v[_JE_FIELD_ATK] = 0
			v[_JE_FIELD_DEF] = 0
		return


## 56dd30: vinculo i de la carta (tipo en el nibble bajo; el byte alto del tipo es un dato).
func _je_link(p: int, z: int, out: int, zo: int, i: int, v: Array) -> void:
	var kind := m.u8(zo + JoeyMem.Z_LINK_KIND + i * 2) & 0xf
	var data := m.u8(zo + JoeyMem.Z_LINK_KIND + i * 2 + 1)
	var ref := m.u16(zo + JoeyMem.Z_LINK_REF + i * 2)
	var rp := ref & 0xff
	var tz := JoeyMem.zone(rp & 1, ref >> 8)
	match kind:
		1:
			_je_link_equip(p, z, out, rp, tz, v)
		2, 6, 7, 8:
			var entry := m.u32(tz)
			if (entry & 0xfff) == 0 or (m.u8(tz + JoeyMem.Z_STATUS) & 0x20) != 0:
				return
			if (f56b440(entry & 0xfff, _je_key(entry)) & _JE_M32) != 0:
				return
			var card_id := f4022e0(m.u16(tz) & 0xfff) & 0xffff
			if (card_id >= 0x465 and card_id <= 0x46a) or (card_id >= 0x149 and card_id <= 0x14e) \
					or card_id == 0x42d:
				v[_JE_ATK] += v[_JE_FIELD_ATK]
				v[_JE_DEF] += v[_JE_FIELD_DEF]
				v[_JE_FIELD_DEF] = 0
				v[_JE_FIELD_ATK] = 0
			elif card_id == 0x52:
				if m.u8(out + 2) == 2:
					v[_JE_ATK] += 200
					v[_JE_DEF] += 200
			elif card_id == 0x4dc:
				v[_JE_ATK] -= 700
			elif card_id == 0x590:
				v[_JE_ATK_LINK] = 0
				v[_JE_ATK_EQ] = 0
				m.set_u32(out + 4, 0)
				v[_JE_ATK] = 0
		3, 0xb, 0xc:
			_je_link_card(out, kind, data, ref, v)
		4:
			if _je_link_live(tz):
				v[_JE_ATK_EQ] += 200
		5:
			var own := f4022e0(m.u16(out)) & 0xffff
			if own != 0x2da and own != 0x536:
				return
			if (m.u8(tz + JoeyMem.Z_FLAGS) & 2) != 0:
				m.set_u32(out + 4, f4027b0(m.u16(tz) & 0xfff) & 0xffff)
				m.set_u32(out + 8, f402800(m.u16(tz) & 0xfff) & 0xffff)
			else:
				m.set_u32(out + 4, 0)
				m.set_u32(out + 8, 0)
			v[_JE_DEF_LINK] = 0
			v[_JE_ATK_LINK] = 0


## 56dd30: vinculo de tipo 1 a la carta de tz (equipos y efectos continuos que la apuntan).
func _je_link_equip(p: int, z: int, out: int, rp: int, tz: int, v: Array) -> void:
	if _je_link_live(tz) and (m.u8(tz + JoeyMem.Z_FLAGS) & 2) != 0 \
			and (v[_JE_SPECIAL] == 0 or (f4025d0(m.u16(tz) & 0xfff) & 0xffff) == 0x15):
		var card_id := f4022e0(m.u16(tz) & 0xfff) & 0xffff
		var level := (m.u8(tz + JoeyMem.Z_FLAGS) >> 2) & 0xf
		if card_id in _JE_FD40_IDS:
			var acc := m.local(8)
			m.set_u32(acc, v[_JE_ATK_EQ])
			m.set_u32(acc + 4, v[_JE_DEF_EQ])
			f56fd40(out, m.u32(tz) & 0xfff, acc, acc + 4)
			v[_JE_ATK_EQ] = m.u32(acc)
			v[_JE_DEF_EQ] = m.u32(acc + 4)
		else:
			match card_id:
				0x416:
					if m.u8(out + 2) != 7:
						v[_JE_ATK_EQ] += level * -300
				0x290:
					# LP del propietario del vinculo frente al rival: menos LP dobla, mas LP divide.
					var own_lp := m.u16(JoeyMem.PLAYER + (rp & 1) * JoeyMem.PLAYER_SIZE + JoeyMem.P_LP)
					var other_lp := m.u16(JoeyMem.PLAYER + ((~rp) & 1) * JoeyMem.PLAYER_SIZE + JoeyMem.P_LP)
					if own_lp < other_lp:
						m.set_u32(out + 4, (f4027b0(m.u16(out)) & 0xffff) << 1)
					if own_lp > other_lp:
						m.set_u32(out + 4, f5be050(f4027b0(m.u16(out)) & 0xffff))
				0x3c2:
					if m.u8(out + 2) == 7:
						var counter := m.u16(tz + JoeyMem.Z_COUNTER)
						if counter == 1:
							v[_JE_ATK_EQ] += 700
						elif counter == 2:
							v[_JE_DEF_EQ] += 700
				0x424:
					v[_JE_ATK_EQ] += 700 - level * 200
				0x5a9:
					v[_JE_ATK_EQ] += f569d90(rp, 1, 0) * 800
					v[_JE_DEF_EQ] += f569d90(rp, 1, 0) * 800
				0x5aa:
					v[_JE_ATK_EQ] += f56a320(rp, 0, 0, 1) * 500
					v[_JE_DEF_EQ] += f56a320(rp, 0, 0, 1) * 500
				0x60e:
					if (f56f6f0(p, z, m.u16(tz + 4)) & 0xffff) == 0xf:
						v[_JE_ATK_EQ] += 500
						v[_JE_DEF_EQ] += 500
	if (f4022e0(m.u16(out)) & 0xffff) == 0x115 and (f4022e0(m.u16(tz) & 0xfff) & 0xffff) == 0x47:
		m.set_u32(out + 4, 0)
		m.set_u32(out + 8, 2000)


## 56dd30: vinculo de tipo 3, 0xb o 0xc: ref es un indice de carta con modo en los bits 13-15
## (0 efecto por id, 0x4000 suma/fija ATK x5, 0x6000 copia ATK/DEF base, 0x8000 fija ATK x10).
func _je_link_card(out: int, kind: int, data: int, ref: int, v: Array) -> void:
	var mode := ref & 0xe000
	if mode == 0x6000:
		m.set_u32(out + 4, f4027b0(ref & 0x1fff) & 0xffff)
		m.set_u32(out + 8, f402800(ref & 0x1fff) & 0xffff)
	elif mode == 0x4000:
		var atk := (ref & 0x1fff) * 5
		if data == 0:
			v[_JE_ATK_LINK] = 0
			v[_JE_ATK_EQ] = 0
			v[_JE_ATK] = 0
			m.set_u32(out + 4, atk)
		else:
			m.set_u32(out + 4, m.u32(out + 4) + atk)
	elif mode == 0x8000:
		m.set_u32(out + 4, (ref & 0x1fff) * 10)
		v[_JE_ATK_LINK] = 0
		v[_JE_ATK_EQ] = 0
		v[_JE_ATK] = 0
	elif mode == 0:
		match f4022e0(ref) & 0xffff:
			0x458:
				m.set_u32(out + 4, (f4027b0(m.u16(out)) & 0xffff) << 1)
			0x3f8:
				v[_JE_DEF_LINK] += 500
			0x1ac:
				var total: int = m.u32(out + 4) + v[_JE_ATK] + v[_JE_ATK_LINK] + v[_JE_ATK_EQ]
				if data == 0:
					m.set_u32(out + 4, f5be050(total & _JE_M32))
				else:
					m.set_u32(out + 4, total * 2)
				v[_JE_ATK_LINK] = 0
				v[_JE_ATK_EQ] = 0
				v[_JE_ATK] = 0
			0x62:
				v[_JE_ATK] += 100
				v[_JE_DEF] += 100
			0x105, 0x433:
				v[_JE_ATK_LINK] += 700
			0x3f7:
				v[_JE_ATK_LINK] += 500
			0x434:
				v[_JE_DEF_LINK] += 700
			0x43a:
				v[_JE_DEF_LINK] -= 500
			0x587:
				v[_JE_ATK_LINK] -= 700
			0x4b3:
				v[_JE_ATK_LINK] += data * 100
				v[_JE_DEF_LINK] += data * 100
			0x4b4:
				v[_JE_ATK_LINK] -= data * 100
				v[_JE_DEF_LINK] -= data * 100
			0x4cf:
				v[_JE_ATK_LINK] -= 500
			0x4e6, 0x4e7, 0x4e8:
				if kind == 0xb:
					v[_JE_ATK_LINK] -= 500
					v[_JE_DEF_LINK] -= 500
			0x5e9:
				v[_JE_ATK_LINK] += data * 300
			0x5f3:
				v[_JE_ATK_LINK] -= 200
			0x5fe:
				v[_JE_ATK_LINK] += data * 100


## Joey FUN_0056f690: ATK efectivo de la carta de (p, z) (56dd30).
func f56f690(p: int, z: int) -> int:
	var stats := m.local(12)
	f56dd30(p, z, stats)
	return m.u32(stats + 4)


## Joey FUN_0056f6b0: DEF efectiva de la carta de (p, z) (56dd30).
func f56f6b0(p: int, z: int) -> int:
	var stats := m.local(12)
	f56dd30(p, z, stats)
	return m.u32(stats + 8)


## Joey FUN_0056f6d0: tipo efectivo de la carta de (p, z) (56f6f0 sin excluir colocacion).
func f56f6d0(p: int, z: int) -> int:
	return f56f6f0(p, z, _JE_M32)


## Joey FUN_0056f6f0: tipo de monstruo efectivo de (p, z): el de la tabla, cambiado por el
## ultimo 0x2fa (dragon, 10) o 0x479 (su contador) colocado y por un 0x60e vinculado (1).
## skip excluye un numero de colocacion. Devuelve un ushort (la mitad alta de EAX es basura).
func f56f6f0(p: int, z: int, skip: int) -> int:
	var q := p & 1
	var zo := JoeyMem.zone(q, z)
	var index := m.u16(zo) & 0xfff
	var special := f56c460(p, z)
	if index == 0:
		return 0
	var result := f4025d0(index) & 0xffff
	if _s32(z) >= 5 or (m.u8(zo + JoeyMem.Z_FLAGS) & 2) == 0:
		return result
	var best := 0
	for c in 2:
		for i in 5:
			var at := JoeyMem.zone(c, i)
			if (m.u32(at) & 0xfff) != 0 and (f4022e0(m.u32(at) & 0xfff) & 0xffff) == 0x2fa \
					and (m.u8(at + JoeyMem.Z_FLAGS) & 2) != 0:
				var li := _s32(f56da10(c, i, 0x2fa))
				if li >= 0 and m.u8(0xa55dc1 + (i * 0x48 + c * 0x6a2 + li) * 2) == (p & _JE_M32):
					var placed := m.u16(at + 4)
					if placed > best and placed != (skip & _JE_M32):
						best = placed
						result = 10
			# 0x479 en la zona de magia/trampa de enfrente, boca arriba y sin los bits 1 y 5.
			var st := at + 5 * JoeyMem.ZONE_SIZE
			if (m.u32(st) & 0xfff) != 0 and (f4022e0(m.u32(st) & 0xfff) & 0xffff) == 0x479:
				var flags := m.u16(st + JoeyMem.Z_FLAGS)
				var status := m.u32(st + JoeyMem.Z_STATUS)
				if (flags & 2) != 0 and ((flags >> 1) & ~(status >> 5) & ~(status >> 1) & 1) != 0:
					var placed := m.u16(st + 4)
					if placed > best and placed != (skip & _JE_M32) and m.u16(st + JoeyMem.Z_COUNTER) != 0:
						best = placed
						result = m.u16(st + JoeyMem.Z_COUNTER)
	var i := 0
	while i < m.u16(zo + JoeyMem.Z_LINKS_N):
		var ref := m.u16(zo + JoeyMem.Z_LINK_REF + i * 2)
		var at := JoeyMem.zone(ref & 1, ref >> 8)
		if (m.u8(zo + JoeyMem.Z_LINK_KIND + i * 2) & 0xf) == 1 and _je_link_live(at) \
				and (special == 0 or (f4025d0(m.u16(at) & 0xfff) & 0xffff) == 0x15) \
				and (f4022e0(m.u16(at) & 0xfff) & 0xffff) == 0x60e:
			var placed := m.u16(at + 4)
			if placed > best and placed != (skip & _JE_M32):
				result = 1
		i += 1
	return result


## Joey FUN_0056f9e0: atributo efectivo de (p, z): el de la tabla, o el contador de un 0x5a8
## vinculado (tipo 1). Devuelve un ushort (la mitad alta de EAX es basura).
func f56f9e0(p: int, z: int) -> int:
	var q := p & 1
	var zo := JoeyMem.zone(q, z)
	var index := m.u16(zo) & 0xfff
	var special := f56c460(p, z)
	if index == 0:
		return 0
	var result := f402650(index) & 0xffff
	if _s32(z) >= 5 or (m.u8(zo + JoeyMem.Z_FLAGS) & 2) == 0:
		return result
	var i := 0
	while i < m.u16(zo + JoeyMem.Z_LINKS_N):
		var ref := m.u16(zo + JoeyMem.Z_LINK_REF + i * 2)
		var at := JoeyMem.zone(ref & 1, ref >> 8)
		if (m.u8(zo + JoeyMem.Z_LINK_KIND + i * 2) & 0xf) == 1 and _je_link_live(at) \
				and (special == 0 or (f4025d0(m.u16(at) & 0xfff) & 0xffff) == 0x15) \
				and (f4022e0(m.u16(at) & 0xfff) & 0xffff) == 0x5a8:
			result = m.u16(at + JoeyMem.Z_COUNTER)
		i += 1
	return result


## Joey FUN_0056fb40: primera zona (q, i) con un vinculo a la carta de (p, z) (56dc10),
## como q | i << 8; 0xffff si no hay carta o vinculo.
func f56fb40(p: int, z: int) -> int:
	if (m.u32(JoeyMem.zone(p, z)) & 0xfff) != 0:
		for q in 2:
			for i in 11:
				if _s32(f56dc10(q, i, p, z)) >= 0:
					return (i << 8) | q
	return 0xffff


## Joey FUN_0056fbc0: tipo (nibble bajo) del primer vinculo que apunta a la carta de (p, z);
## 0 si no hay. La mitad alta de EAX es la del indice del vinculo, como en el original.
func f56fbc0(p: int, z: int) -> int:
	if (m.u32(JoeyMem.zone(p, z)) & 0xfff) == 0:
		return 0
	var last := 0
	for q in 2:
		for i in 11:
			last = f56dc10(q, i, p, z) & _JE_M32
			if _s32(last) >= 0:
				var slot := (last + i * 0x48) & _JE_M32
				return (slot & 0xffff0000) | (m.u8(0xa55dc0 + (slot + (q & 1) * 0x6a2) * 2) & 0xf)
	return last & 0xffff0000


## Joey FUN_0056fc50: arma la carta de (p, z) (indice, ubicacion, clave) y la pasa a 579ce0,
## o a 57a4b0 si su primer vinculo entrante es de tipo 5, con a | b << 8.
func f56fc50(p: int, z: int, a: int, b: int) -> int:
	var zo := JoeyMem.zone(p, z)
	var card := m.local(0x14)
	m.set_u16(card, m.u16(zo) & 0xfff)
	m.set_u16(card + 2, (p & 1) | ((z & 0x1f) << 1))
	m.set_u16(card + 4, (_je_key(m.u32(zo)) << 5) & 0x1fe0)
	var arg := ((b & 0xff) << 8) | (a & 0xff)
	if (f56fbc0(p, z) & 0xffff) != 5:
		return f579ce0(card, arg)
	# ASM conserva EAX de ambos predicados; 590ba0/595690 consumen el resultado.
	return f57a4b0(card, arg)


## Joey FUN_0056fd40: suma a *atk y *def el bono del equipo con indice dado sobre la carta de
## stats (u16 indice, u8 tipo, u8 atributo, de 56dd30).
func f56fd40(stats: int, index: int, atk: int, def: int) -> int:
	var a := 0
	var d := 0
	var kind := m.u8(stats + 2)
	var attr := m.u16(stats + 2) & 0xff00
	var card_id := f4022e0(index) & 0xffff
	if _JE_FD40_KIND.has(card_id):
		if kind == _JE_FD40_KIND[card_id]:
			a = 300
			d = 300
	elif _JE_FD40_ATTR.has(card_id):
		if attr == _JE_FD40_ATTR[card_id]:
			a = 400
			d = -200
	else:
		match card_id:
			0x12f:
				a = 1000
			0x131:
				if kind == 0xa:
					a = 700
			0x136, 0x28a:
				a = 500
			0x138:
				d = 800
			0x139:
				a = 700
				d = 700
			0x13c:
				if (f4022e0(m.u16(stats)) & 0xffff) in [0x3d, 0x3e, 0x4e1]:
					a = 500
			0x140:
				a = 700
			0x28d:
				if attr == 0x400:
					a = 700
			0x291:
				a = 300
				d = 300
			0x29b:
				if attr == 0x100:
					a = 700
			0x412:
				a = 500
				d = 500
			0x422:
				a = -500
				d = -500
			0x49e:
				if kind == 0xf:
					a = 700
			0x4da:
				a = -500
			0x58c:
				a = 1000
				d = -1000
			0x58e:
				if kind == 0xf:
					a = 800
			0x604:
				if (f4022e0(m.u16(stats)) & 0xffff) == 0x53b:
					a = 300
	m.set_u32(atk, m.u32(atk) + a)
	m.set_u32(def, m.u32(def) + d)
	return 0
