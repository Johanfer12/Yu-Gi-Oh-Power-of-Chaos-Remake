class_name DuelPortM
extends DuelPortL
## Modulo del porte del motor de duelo (ver docs/duel/PORTING.md).

## FUN_00575ed0: fase de robo; respeta el indicador que permite saltarla.
func f575ed0() -> int:
	var p := m.u16(0xa133f2) & 1
	var flags := 0xa11950 + p * PS
	if (m.u32(flags) & 4) != 0:
		m.set_u32(flags, m.u32(flags) & 0xfffffffb)
		return 1
	match m.u8(0xa133fc):
		0: issue((m.u16(0xa133f2) << 15) | 0x50, 0, 0, 0)
		1: call("f54f470", p, 1)
		2: f56a380(1 - p, 1, 0)
		_: return 1
	m.set_u8(0xa133fc, m.u8(0xa133fc) + 1)
	return 0

## FUN_00576ba0: limpia el indicador temporal 8 de los cinco monstruos boca arriba.
func f576ba0(p: int) -> int:
	for z in range(5):
		var a := DuelMem.zone(p & 1, z)
		if (m.u32(a) & 0xfff) != 0 and (m.u8(a + 6) & 2) != 0 and (m.u16(a + 0x8e) & 8) != 0:
			m.set_u16(a + 0x8e, m.u16(a + 0x8e) & 0xfff7)
	return 0

## FUN_00576c90: inicio del turno y limpieza de indicadores de invocacion y batalla.
func f576c90() -> int:
	var p := m.u8(0xa133f2) & 1
	var a := DuelMem.pl(p)
	match m.u8(0xa133fc):
		0: pass
		1:
			if (m.u32(a + 0xc) & 8) != 0:
				m.set_u32(a + 0xc, m.u32(a + 0xc) & 0xfffffff7)
				if ((m.u8(0xa16181) & 1) == 0 and p == 0) or (m.u32(0xa114b4) & 0x200) != 0:
					m.set_u8(0xa13438, 0)
					m.set_u8(0xa13439, 0)
				if (m.u8(0xa16181) & 1) != 0:
					f53ed60(0xf002, 0, 0, 0)
				m.set_u8(0xa16180, m.u8(0xa16180) + 5)
				return 1
			issue((m.u16(0xa133f2) << 15) | 1, 0, 0, 0)
		2:
			f576ba0(p)
			f576ba0(1 - p)
		_:
			m.set_u8(a + 0x10, m.u8(a + 0x10) & 0xfc)
			m.set_u8(a + 8, m.u8(a + 8) & 0xcf)
			m.set_u8(a + 0x11, m.u8(a + 0x11) & 0x7f)
			m.set_u8(a + 0x13, m.u8(a + 0x13) & 0xfd)
			return 1
	m.set_u8(0xa133fc, m.u8(0xa133fc) + 1)
	return 0

## FUN_00575e50: despacha los subestados de batalla desde la tabla del original.
func f575e50(p: int) -> int:
	var phase := m.u16(0xa133f2)
	var target := m.u32(0x5ad29c + ((phase & 0x7f80) >> 7) * 4)
	if target != 0:
		if invoke_original(target, [p]) != 0:
			m.set_u8(0xa133f4, 0)
			m.set_u16(0xa133f2, phase ^ (((phase & 0xff80) + 0x80 ^ phase) & 0x7f80))
		return 0
	issue((phase << 15) | 0x54, 0, 0, 0)
	return 1

## FUN_00572070: abre batalla y despues cambia a la fase de batalla.
func f572070(p: int) -> int:
	if m.u8(0xa133f4) != 0:
		issue((m.u16(0xa133f2) << 15) | 0x53, 0, 0, 0)
		return 1
	issue((0x8000 if p != 0 else 0) | 0x32, 1, 0, 0)
	m.set_u8(0xa133f4, m.u8(0xa133f4) + 1)
	return 0

## FUN_005720d0: indica si el jugador es humano en el modo actual.
func f5720d0(p: int) -> int:
	var flags := m.u32(0xa114b4)
	return 0 if ((flags >> 10) & 3) != 2 and ((flags & 0x200) != 0 or p != 0) else 1

## FUN_00572100: fase de batalla. El humano elige atacante y objetivo con el cursor
## (0x571530); el clic derecho fuera de una carta pregunta si termina la batalla (0xdc/0xdd)
## y las fichas de fases pasan a principal 2 o al fin del turno. La CPU decide con 0x57eb90.
func f572100(p: int) -> int:
	m.set_u16(0xa114c0, m.u16(0xa114c0) ^ ((m.u8(0xa114c0) ^ p) & 1))
	var st := m.u8(0xa133f4)
	if st == 0:
		f571c30(H, p, 0, 0)
		m.set_u32(0xa114c0, m.u32(0xa114c0) & 0xffffffb3)
		if p == 0:
			call("f53f7e0", 0, 0, 0)
		issue(0x56, m.u16(0xa11958 + (p & 1) * PS), 0, 0)
		m.set_u8(0xa133f4, st + 1)
		return 0
	if st == 1:
		if p != 0:
			if call("f57eb90", 0) != 0:
				m.set_u16(0xa114c0, ((m.u8(0xa1344c) & 0x70) << 4) | (m.u16(0xa114c0) & 0xf8cf))
				return 1
			m.set_u8(0xa133f4, 0)
			m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x867f) | 0x600)
			return 0
		if f571530() == 0:
			if (m.u32(0xa114a8) & 0x102) != 0:
				f5417e0(0xdc if (m.u8(0xa1194c) & 0x40) != 0 else 0xdd)
				f540d60(3, 2)
				m.set_u8(0xa133f4, 10)
				return 0
			var button := f4613d0()
			if button == 4:
				m.set_u8(0xa13402, m.u8(0xa13402) & 0xfe)
				m.set_u8(0xa133f4, 0)
				m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x867f) | 0x600)
				return 0
			if button == 5:
				m.set_u8(0xa13402, m.u8(0xa13402) | 1)
				m.set_u8(0xa133f4, 0)
				m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x867f) | 0x600)
				return 0
		return 0
	if st != 10:
		var flags := m.u32(0xa114c0)
		m.set_u32(0xa114c0, flags & 0xffffff4f)
		present("battle_cursor", {"zone": (flags >> 8) & 7})
		return 1
	var answer := m.u16(0xa16178)
	if answer == 0:
		m.set_u8(0xa13402, m.u8(0xa13402) & 0xfe)
		m.set_u16(0xa133f4, m.u8(0xa133f5) << 8)
		m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x867f) | 0x600)
	elif answer == 1:
		m.set_u8(0xa13402, m.u8(0xa13402) | 1)
		m.set_u8(0xa133f4, 0)
		m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x867f) | 0x600)
	elif answer == 2:
		m.set_u8(0xa133f4, 1)
	return 0

## FUN_00571d90: comprueba si el ataque necesita repetirse tras cambiar los objetivos.
func f571d90(p: int) -> int:
	var flags := m.u32(0xa114c0)
	var attacker := flags & 1
	var source := (flags >> 8) & 7
	var defender := (flags >> 1) & 1
	var target := (flags >> 11) & 7
	if f571810(attacker, source, 0) != 0:
		var replay := f5431b0(1 - p) != m.u16(0xa11606 - p * 2)
		if (flags & 4) == 0:
			var a := DuelMem.zone(defender, target)
			replay = (m.u32(a) & 0xfff) == 0 or replay
			if (m.u32(a) & 0xfff) != 0 and m.s16(0xa1160a - p * 2) != m.s16(a + 4): replay = true
		elif f5431b0(defender) > 0 and f571600(attacker, source) == 0:
			replay = true
		if (flags & 4) == 0 and f545730(defender, target, 0x422) == 0:
			for z in range(5):
				if z != target and (m.u32(DuelMem.zone(defender, z)) & 0xfff) != 0 and f545730(defender, z, 0x422) != 0:
					replay = true
		if not replay: return 0
		m.set_u8(0xa133f4, 0)
		m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x80ff) | 0x80)
		m.set_u16(0xa114c0, (m.u16(0xa114c0) & 0xfffb) | 0xb0) # ASM 572022: relee y escribe word
		var a := DuelMem.zone(attacker, source)
		m.set_u8(a + 7, m.u8(a + 7) | 2)
		return 1
	var a := DuelMem.zone(attacker, source)
	if f401a70(m.u16(a) & 0xfff) == 0x538 and (m.u16(a + 6) & 0x1000) != 0:
		m.set_u16(a + 6, m.u16(a + 6) & 0xefff)
	else:
		f5715c0(attacker, source)
	m.set_u32(0xa114c0, m.u32(0xa114c0) & 0xfffffffb)
	m.set_u8(0xa133f4, 0)
	m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x80ff) | 0x80)
	return 1

## FUN_00571600: comprueba monstruos que pueden atacar directamente por su efecto.
func f571600(p: int, z: int) -> int:
	var id := f401a70(m.u16(DuelMem.zone(p & 1, z)) & 0xfff)
	match id:
		0x27a, 0x182, 0x18c, 0x18d, 0x1a5, 0x1e7: return 1
		0x2d6, 0x2d7, 0x2d8, 0x2fe: return 1 if f5438c0(1 - p) == 0 else 0
		0x32c: return f543930(1 - p)
	return 0

## FUN_00571d30: comprueba si se puede entrar en batalla este turno.
func f571d30(p: int) -> int:
	if m.u16(0xa133f0) == 0:
		return 0
	var a := DuelMem.pl(p & 1)
	if (m.u8(a + 0x10) & 1) != 0 and (m.u8(a + 8) & 0x40) == 0:
		return 0
	f571c30(H, p, 0, 1)
	return 1 if m.s16(a + 0x14) != 0 else 0

## FUN_00577040: comprueba los efectos opcionales de la fase de espera.
func f577040(p: int, z: int) -> int:
	var a := DuelMem.zone(p & 1, z)
	if (m.u16(a) & 0xfff) == 0:
		return 0
	var id := f401a70(m.u16(a) & 0xfff)
	if id == 0x1a0 or id == 0x243:
		if z > 4 or (m.u8(a + 6) & 2) == 0:
			return 0
	elif id == 0x428:
		if z < 5 or (m.u8(a + 6) & 2) != 0:
			return 0
	else:
		return 0
	return 1 if f551cb0(p, z, 2) != 0 else 0

## FUN_005770d0: efectos automaticos de espera, danos, recuperacion y equipos.
func f5770d0(p: int) -> int:
	var owner := p & 1
	for z in range(5):
		if ((1 << z) & m.u8(DuelMem.pl(owner) + 0x12) & 0x1f) != 0 and (m.u32(DuelMem.zone(owner, z)) & 0xfff) == 0:
			f54ef00(p, f401ad0(0x527))
			issue((0x8000 if p != 0 else 0) | 0xac, z, 1, 0)
	for z in range(5):
		var a := DuelMem.zone(owner, z)
		var index := m.u16(a) & 0xfff
		if index == 0 or (m.u16(a + 6) & 2) == 0: continue
		var id := f401a70(index)
		if (id == 0x59d and (m.u16(a + 6) & 1) == 0) or (id == 0x59e and (m.u16(a + 6) & 1) != 0):
			f54eed0(p, index, z)
			call("f54f0d0", p, 1000)
		elif id == 0x228:
			f54eed0(p, index, z)
			f54ef90(p, 300)
		elif id == 0x459 and f5431b0(p) == 1:
			f54eed0(p, index, z)
			if (m.u16(a + 6) & 1) == 0: call("f54e660", p, z, 0, 0)
			m.set_u8(a + 7, m.u8(a + 7) | 2)
		elif id == 0x5a1:
			f54eed0(p, index, z)
			call("f54f0d0", p, 800)
		var count := f545730(p, z, 0x58b)
		if count != 0:
			f54eed0(p, f401ad0(0x58b), z)
			f54ef90(p, f545730(p, z, 0x58b) * 500)
		if f545620(p, z, 0x2df) != 0:
			var damage := f547c60(p, z)
			f54eed0(p, f401ad0(0x2df), z)
			f54e250(p, z, 1)
			f54ef90(p, damage)
		if f545620(p, z, 0x492) != 0:
			var damage := f547c60(p, z)
			f54eed0(p, f401ad0(0x492), z)
			call("f54f0d0", 1 - p, f545620(p, z, 0x492) * f53fbd0(damage))
	call("f56e460", p)
	for z in range(5, 11):
		var a := DuelMem.zone(owner, z)
		var index := m.u16(a) & 0xfff
		if index == 0 or (m.u8(a + 6) & 2) == 0 or (m.u8(a + 0x8f) & 4) != 0: continue
		var count := f545730(p, z, 0x589)
		if count > 0:
			f54ef00(p, f401ad0(0x589))
			f54ef90(p, count * 500)
		var id := f401a70(index)
		if id == 0x46b:
			# Confirmado en C: compara el parametro jugador con 99, no los LP.
			if p > 99 and m.u16(DuelMem.pl(owner)) != 0:
				f54eed0(p, index, z)
				issue((0x8000 if p != 0 else 0) | 0x43, 100, 1, 0)
		elif id == 0x51f:
			f54eed0(p, index, z)
			f54ef90(p, 500)
	for z in range(5, 10):
		var a := DuelMem.zone((-p - 1) & 1, z)
		var index := m.u16(a) & 0xfff
		if index == 0 or (m.u8(a + 6) & 2) == 0 or (m.u8(a + 0x8f) & 4) != 0: continue
		var id := f401a70(index)
		if id == 0x42c or (id == 0x445 and f544f30(p) != -1):
			f54eed0(1 - p, index, z)
			call("f54f0d0", p, 1000)
		elif id == 0x516 or id == 0x51f:
			f54eed0(1 - p, index, z)
			f54ef90(p, 500)
	var grave_count := f544a00(p, 0x5a6)
	if grave_count > 0:
		f54eed0(p, f401ad0(0x5a6), 0xe)
		call("f54f0d0", p, f544a00(p, 0x5a6) * 200)
	return 0

## FUN_00577000: LP de mantenimiento que pide en cada fase de espera la carta `id`.
func f577000(id: int) -> int:
	match id & 0xffff:
		0x58c: return 1000
		1099: return 2000
		0x482: return 700
		0x590: return 500
	return 0

## FUN_00577670: fase de espera; efectos automaticos, opcionales y mantenimiento.
func f577670() -> int:
	var p := m.u8(0xa133f2) & 1
	var other := 1 - p
	var flags := DuelMem.pl(p) + 0xc
	if (m.u32(flags) & 2) != 0:
		m.set_u32(flags, m.u32(flags) & 0xfffffffd)
		return 1
	var st := m.u8(0xa133fc)
	match st:
		0, 21:
			if st == 0: issue((p << 15) | 0x51, 0, 0, 0)
			m.set_u8(0xa133fc, 20)
			return 0
		1:
			f5770d0(p)
			m.set_u32(0xa133fc, m.u32(0xa133fc) & 0xff)
		2:
			if f56def0(p) == 0: return 0
			m.set_u32(0xa133fc, m.u32(0xa133fc) & 0xff)
		3:
			if (m.u8(DuelMem.pl(p) + 0x12) & 0xe0) != 0:
				issue((p << 15) | 0x4b, 0, 0, 0)
				var tmp := m.local(4)
				m.set_u32(tmp, 0)
				if f543330(p) > 0 and f54daf0(p, 0x57d, tmp) != 0:
					f54eed0(p, f401ad0(0x57d), 0xe)
					call("f57cb60", p, tmp, 1, 1, 0x20, 0xe, p)
					return 0
			m.set_u32(0xa133fc, m.u32(0xa133fc) & 0xffffff)
		4:
			while m.u8(0xa133fe) < m.u8(DuelMem.pl(p) + 6):
				var i := m.u8(0xa133fe)
				if m.s16(0xa125f8 + p * PS + i * 4) == 0x402:
					f54ef00(p, f401ad0(0x3c4))
					issue((p << 15) | 0xcf, i, 1, 0)
					return 0
				m.set_u32(0xa133fc, (m.u32(0xa133fc) & 0xffff) | ((i + 1) << 16))
			m.set_u32(0xa133fc, m.u32(0xa133fc) & 0xff)
		5:
			if f542f30(other, 0x489) == 0 or m.u16(DuelMem.pl(other)) < 500 or m.u8(DuelMem.pl(p) + 2) == 0:
				m.set_u8(0xa133fc, 7)
				return 0
			f53e760(other, 0xf, 0x489, f542da0(other, 0x489))
		6:
			if m.u8(0xa13428) != 0:
				issue((other << 15) | 0x43, 500, 1, 0)
				f53baa0(((f542da0(other, 0x489) & 0x1f | other << 15 | 0x480) << 16) | f401ad0(0x489), 0)
				m.set_u8(0xa133fc, 5)
				return 0
			m.set_u8(0xa133fc, 7)
			return 0
		7:
			if f543010(other, 0x5ed) == 0 or f5431f0(p, 1, 0) < 1:
				m.set_u16(0xa133fc, 0x509)
				return 0
			f53e760(other, 0xf, 0x5ed, f543070(other, 0x5ed))
		8:
			if m.u8(0xa13428) != 0: f53baa0(((f542e00(other, 0x5ed) & 0x1f | other << 15 | 0x440) << 16) | f401ad0(0x5ed), 0)
			m.set_u16(0xa133fc, 0x509)
			return 0
		9:
			while m.u8(0xa133fd) < 10:
				var z := m.u8(0xa133fd)
				var a := DuelMem.zone(p, z)
				if (m.u32(a) & 0xfff) != 0 and (m.u8(a + 6) & 2) != 0 and (m.u16(a + 0x8e) & 0x400) == 0 and f401a70(m.u16(a) & 0xfff) == 0x592 and f543330(p) > 0:
					f54eed0(p, m.u16(a) & 0xfff, z)
					issue((p << 15) | 0xa5, f543360(p), 3, 0)
					m.set_u16(0xa133fc, ((z + 1) << 8) | st)
					return 0
				m.set_u16(0xa133fc, ((z + 1) << 8) | st)
		10:
			for z in range(5):
				var a := DuelMem.zone(p, z)
				if (m.u16(a) & 0xfff) != 0 and (m.u8(a + 6) & 2) != 0 and f401a70(m.u16(a) & 0xfff) == 0x2db and f551cb0(p, z, 2) != 0:
					f53baa0(((z & 0x1f | p << 15 | 0x440) << 16) | f401ad0(0x2db), 0)
			m.set_u32(0xa133fc, m.u8(0xa133fc))
		11:
			if p == 0:
				while m.u8(0xa133fd) < 11:
					var z := m.u8(0xa133fd)
					if f577040(0, z) != 0:
						# Cuadro Si/No: mensaje 0xfa con el nombre de la carta; 12 lee la respuesta.
						dialog_format(0xfa, [{"card": m.u32(DuelMem.zone(0, z)) & 0xfff}])
						f540d60(1, 0)
						m.set_u8(0xa133fc, 12)
						return 0
					m.set_u16(0xa133fc, ((z + 1) << 8) | st)
			m.set_u8(0xa133fc, 100)
			return 0
		12:
			var z := m.u8(0xa133fd)
			var a := DuelMem.zone(p, z)
			if m.u16(0xa16178) != 0:
				if (m.u8(a + 6) & 2) == 0: issue((p << 15) | 0x91, z, 0, 0)
				f53baa0(((z & 0x1f | p << 15 | 0x440) << 16) | (m.u32(a) & 0xfff), 0)
			m.set_u8(0xa133fd, z + 1)
			m.set_u8(0xa133fc, 11)
			return 0
		20:
			for z in range(11):
				var a := DuelMem.zone(p, z)
				if (m.u16(a) & 0xfff) == 0 or (m.u8(a + 6) & 2) == 0 or (m.u8(a + 0x8f) & 4) != 0 or f401a70(m.u16(a) & 0xfff) != 0x600: continue
				var die := rng.rand() % 6 + 1
				f54eed0(p, f401ad0(0x600), z)
				issue((p << 15) | 0xe4, die, z, 0)
				for owner in range(2):
					for monster in range(5):
						var target := DuelMem.zone(owner, monster)
						if (m.u32(target) & 0xfff) == 0 or (m.u8(target + 6) & 2) == 0: continue
						var prop := f401a20(m.u16(target) & 0xfff)
						var kind := (prop >> 20) & 0x1f
						var level := 10 if kind == 0x18 else (0 if kind > 0x14 and kind < 0x18 else ((prop >> 25) & 0xf))
						if level == die or (level > 5 and die == 6): f54e250(owner, monster, 1)
			m.set_u8(0xa133fc, 1)
			return 0
		100, 101:
			if st == 100:
				m.set_u8(0xa133fc, 101)
				m.set_u8(0xa133fd, 0)
			while m.u8(0xa133fd) < 10:
				var z := m.u8(0xa133fd)
				var a := DuelMem.zone(p, z)
				if (m.u32(a) & 0xfff) != 0 and (m.u8(a + 6) & 2) != 0:
					var id := f401a70(m.u16(a) & 0xfff)
					if id in [0x58c, 1099, 0x482, 0x590]:
						if f577000(id) <= m.u16(DuelMem.pl(p)):
							m.set_u8(0xa133fc, 110)
							return 0
						f54e250(p, z, 1)
					elif id == 0x47a or id == 0x597:
						if f543400(p, -1 if id == 0x47a else z) > 0:
							m.set_u8(0xa133fc, 120)
							return 0
						if id == 0x47a: f54e250(p, z, 1)
				m.set_u16(0xa133fc, ((z + 1) << 8) | 101)
		102:
			for z in range(5):
				var a := DuelMem.zone(p, z)
				if (m.u32(a) & 0xfff) != 0 and (m.u8(a + 6) & 2) != 0 and f401a70(m.u16(a) & 0xfff) == 0x52: f56db20(p, z)
			f56dc40(p)
			for z in range(5, 10):
				var a := DuelMem.zone(p, z)
				if (m.u32(a) & 0xfff) != 0 and (m.u8(a + 6) & 2) != 0 and f401a70(m.u16(a) & 0xfff) in [0x416, 0x424]: issue((p << 15) | 0x8b, z, 1, 0)
		110:
			var z := m.u8(0xa133fd)
			var index := m.u16(DuelMem.zone(p, z)) & 0xfff
			var id := f401a70(index)
			var cost: int = f577000(id)
			if p == 0:
				# Cuadro Si/No: mensaje 0xe8 con el nombre de la carta ("%s") y el coste ("%d").
				dialog_format(0xe8, [{"card": index}, {"d": cost}])
				f540d60(1, 0)
			else:
				m.set_u16(0xa16178, 1 if (7000 < m.u16(0xa12698) if id == 1099 else cost + 1000 < m.u16(0xa12698)) else 0)
			f54eed0(p, index, z)
		111:
			var z := m.u8(0xa133fd)
			if m.u16(0xa16178) == 0: f54e250(p, z, 1)
			else: issue((p << 15) | 0x43, f577000(f401a70(m.u16(DuelMem.zone(p, z)) & 0xfff)), 1, 0)
			m.set_u8(0xa133fd, z + 1)
			m.set_u8(0xa133fc, 101)
			return 0
		120:
			# Cuadro Si/No: mensaje 0xe9 con el nombre de la carta; 121 lee la respuesta.
			var z := m.u8(0xa133fd)
			dialog_format(0xe9, [{"card": m.u32(DuelMem.zone(p, z)) & 0xfff}])
			f540d60(1, 0)
		121:
			if m.u16(0xa16178) == 0:
				f54e250(p, m.u8(0xa133fd), 1)
				m.set_u8(0xa133fd, m.u8(0xa133fd) + 1)
				m.set_u8(0xa133fc, 101)
				return 0
			f5417e0(0xec)
		122:

			if f57a060(0xf0) == 0 or f579890() == 0: return 0
			f54ea40(m.u32(0xa161a4), m.u32(0xa161ac))
			m.set_u8(0xa133fd, m.u8(0xa133fd) + 1)
			m.set_u8(0xa133fc, 101)
			return 0
		_: return 1
	m.set_u8(0xa133fc, m.u8(0xa133fc) + 1)
	return 0


## FUN_00575f80: devuelve al propietario los monstruos de id 22 al final del turno.
func f575f80(p: int) -> int:
	for z in range(5):
		var a := DuelMem.zone(p & 1, z)
		var index := m.u16(a) & 0xfff
		if index != 0 and (m.u8(a + 6) & 2) != 0 and f401a70(index) == 0x16:
			f54eed0(p, index, z)
			f54e420(p, z, 0)
	return 0

## FUN_005761c0: fin de turno, regreso de espiritus y destruccion por id 1322.
func f5761c0(p: int) -> int:
	var vulnerable := false
	for z in range(5):
		var a := DuelMem.zone(p & 1, z)
		var index := m.u16(a) & 0xfff
		if index == 0 or (m.u8(a + 6) & 2) == 0: continue
		var prop := f401a20(index)
		var kind := (prop >> 20) & 0x1f
		if kind == 0x18: continue
		if (kind < 0x15 or kind > 0x18) and ((prop >> 25) & 0xf) > 3: continue
		if (m.u8(a + 7) & 0x80) == 0: vulnerable = true
	if f542f30(0, 0x52a) == 0 and f542f30(1, 0x52a) == 0:
		vulnerable = false
	elif vulnerable:
		issue((0x8000 if p != 0 else 0) | 0x1e, 0x52a, 1, 0)
	for z in range(5):
		var a := DuelMem.zone(p & 1, z)
		var index := m.u16(a) & 0xfff
		if index == 0 or (m.u8(a + 6) & 2) == 0: continue
		var prop := f401a20(index)
		var kind := (prop >> 20) & 0x1f
		var eligible := kind != 0x18 and ((kind >= 0x15 and kind < 0x18) or ((prop >> 25) & 0xf) < 4)
		if eligible and (m.u8(a + 7) & 0x80) == 0 and vulnerable:
			f54e250(p, z, 1)
		else:
			issue((0x8000 if p != 0 else 0) | 0xa8, z, 1, 0)
	return 0

## FUN_00575ff0: efecto opcional de id 552 al terminar el turno (500 LP).
func f575ff0(p: int) -> int:
	match m.u8(0xa133fe):
		0:
			if m.u16(DuelMem.pl(p & 1)) > 499 and f543330(1 - p) != 0:
				while m.u8(0xa133ff) < 5:
					var a := DuelMem.zone(p & 1, m.u8(0xa133ff))
					if (m.u16(a) & 0xfff) != 0 and (m.u8(a + 6) & 2) != 0 and f401a70(m.u16(a) & 0xfff) == 0x228:
						m.set_u8(0xa133fe, 1 if p == 0 else 2)
						if p != 0: m.set_u16(0xa16178, 1)
						return 0
					m.set_u8(0xa133ff, m.u8(0xa133ff) + 1)
			return 1
		1:
			# Cuadro Si/No: mensaje 0xe4 con el nombre de la carta 0x228; 2 lee la respuesta.
			dialog_format(0xe4, [{"card": f401ad0(0x228)}])
			f540d60(1, 0)
		2:

			if m.u16(0xa16178) != 0:
				issue((0x8000 if p != 0 else 0) | 0x43, 500, 1, 0)
				f53baa0(f401ad0(0x228) | ((m.u8(0xa133ff) & 0x1f | p << 15 | 0x840) << 16), 0)
			m.set_u8(0xa133ff, m.u8(0xa133ff) + 1)
			if m.u8(0xa133ff) < 5:
				m.set_u8(0xa133fe, 0)
				return 0
		_: return 1
	m.set_u8(0xa133fe, m.u8(0xa133fe) + 1)
	return 0

## FUN_00572fc0: efectos de dano al declarar un ataque; se aplican una vez.
func f572fc0(p: int) -> int:
	var flags := m.u32(0xa114c0)
	if (flags & 0x20) == 0:
		m.set_u32(0xa114c0, flags | 0x20)
		var attacker := (flags >> 1) & 1
		var count := f542f30(attacker, 0x427)
		if count > 0:
			issue((0x8000 if attacker != 0 else 0) | 0x1e, 0x427, 0, 0)
			f54f4c0(p, count, 1)
		count = f542f30(1, 0x42a) + f542f30(0, 0x42a)
		if count > 0:
			issue((0x8000 if p != 0 else 0) | 0x1e, 0x42a, 1, 0)
			issue((0x8000 if p != 0 else 0) | 0x43, count * 500, 1, 0)
	return 1

## FUN_00573090: captura objetivos y abre la respuesta a la declaracion de ataque.
func f573090(p: int) -> int:
	var flags := m.u32(0xa114c0)
	var defender := (flags >> 1) & 1
	match m.u8(0xa133f4):
		0:
			for owner in range(2):
				var target := (flags >> (8 if owner == p else 11)) & 7
				var player := (flags >> (0 if owner == p else 1)) & 1
				m.set_u16(0xa11604 + owner * 2, f5431b0(owner))
				m.set_u16(0xa11608 + owner * 2, m.u16(DuelMem.zone(player, target) + 4))
		1:
			if f542f30(defender, 0x590) != 0:
				f53baa0(((f542da0(defender, 0x590) & 0x1f | defender << 15 | 0x2020) << 16) | f401ad0(0x590), 0)
				m.set_u8(0xa133f4, 4)
				return 0
		2, 4:
			if f571d90(p) != 0:
				m.set_u8(0xa133f4, 0)
				if f571810(p, (m.u32(0xa114c0) >> 8) & 7, 0) == 0:
					m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x80ff) | 0x80)
				else:
					present("battle_cursor", {"zone": (m.u32(0xa114c0) >> 8) & 7})
					m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x817f) | 0x100)
				return 0
			if m.u8(0xa133f4) == 4: return 1
		3:
			f56a380(defender, 0x10, ((((flags >> 11) & 7) << 8 | defender) << 16) | (((flags >> 8) & 7) << 8) | (p & 0xff))
		_: return 1
	m.set_u8(0xa133f4, m.u8(0xa133f4) + 1)
	return 0

## FUN_00572b00: costes y moneda de los monstruos que declaran un ataque.
func f572b00(p: int) -> int:
	var flags := m.u32(0xa114c0)
	var z := (flags >> 8) & 7
	match m.u8(0xa133f4):
		0:
			if (flags & 0x10) != 0: return 1
			if f571810(p, z, 1) == 0:
				issue((0x8000 if p != 0 else 0) | 0x35, z, 1, 0)
				m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x80ff) | 0x80)
				return 0
			for owner in range(2):
				var player := (flags >> (0 if owner == p else 1)) & 1
				var target := (flags >> (8 if owner == p else 11)) & 7
				m.set_u16(0xa11604 + owner * 2, f5431b0(owner))
				m.set_u16(0xa11608 + owner * 2, m.u16(DuelMem.zone(player, target) + 4))
			m.set_u8(0xa114c0, m.u8(0xa114c0) | 0x10) # ASM 572c21: or byte ptr
			var id := f401a70(m.u16(DuelMem.zone(p & 1, z)) & 0xfff)
			if id == 0x2e8 or id == 0x2f9:
				if p == 0:
					f5417e0(0xe0)
					m.set_u8(0xa133f4, 100)
					return 0
				var tribute: int = call("f57ceb0", z, 0)
				if tribute < 0:
					f5715c0(p, z)
					m.set_u8(0xa133f4, 0)
					var phase := m.u16(0xa133f2)
					m.set_u16(0xa133f2, phase ^ (((phase & 0xff80) + 0x400 ^ phase) & 0x7f80))
					return 0
				f54ea40(p, tribute)
			elif id == 0x16e:
				if p == 0:
					# Ventana de la moneda (tipo 7) con el mensaje 0x38; la CPU elige 0.
					f5417e0(0x38)
					f540d60(7, 0)
				else:
					m.set_u16(0xa16178, 0)
				m.set_u8(0xa133f4, 200)
				return 0
			elif id == 0x226:
				issue((0x8000 if p != 0 else 0) | 0x43, 1000, 1, 0)
			elif id in [0x2d6, 0x2d7, 0x2d8, 0x2fe]:
				issue((0x8000 if p != 0 else 0) | 0x43, 500, 1, 0)
		100:
			if f57a060(0xf0) != 0 and z != m.u32(0xa161ac) and f579890() != 0:
				f54ea40(p, m.u32(0xa161ac))
				m.set_u8(0xa133f4, 101)
			return 0
		101:
			if f571d90(p) == 0: return 1
			m.set_u8(0xa133f4, 0)
			if f571810(p, (m.u32(0xa114c0) >> 8) & 7, 0) != 0:
				present("battle_cursor", {"zone": (m.u32(0xa114c0) >> 8) & 7})
				m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x817f) | 0x100)
			else:
				m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x80ff) | 0x80)
			return 0
		200:
			# 0xa16178: cara elegida en la ventana de la moneda.
			var coin := rng.rand() & 1
			issue((0x8000 if p != 0 else 0) | 0xe0, m.u16(0xa16178), coin, z)
			if coin != m.u16(0xa16178): issue((0x8000 if p != 0 else 0) | 0x43, (m.u16(DuelMem.pl(p & 1)) * 5 + 4) / 10, 1, 0)
	return 1

## FUN_00576e40: fase principal del humano. Las cartas se juegan con el cursor (0x571530); el
## clic derecho fuera de una carta (o la tecla de cancelar) pregunta si se termina la fase
## (dialogos 0xe5/0xe6) y las fichas del panel de fases (0x4613d0) pasan a batalla o al fin.
func f576e40() -> int:
	var st := m.u8(0xa133fc)
	if st == 0:
		issue(0x52, 0, 0, 0)
		m.set_u8(0xa13408, m.u8(0xa13408) & 0xfc)
		m.set_u8(0xa133fc, st + 1)
		return 0
	if st == 10:
		if f571d30(m.u8(0xa133f2) & 1) == 0:
			f5417e0(0xe6)
			f540d60(1, 0)
			m.set_u8(0xa133fc, st + 1)
			return 0
		f5417e0(0xe5)
		f540d60(3, 2)
		m.set_u8(0xa133fc, 0x14)
		return 0
	if st == 0xb:
		if m.u16(0xa16178) != 0:
			return 1
		m.set_u8(0xa133fc, 1)
		return 0
	if st == 0x14:
		if m.u16(0xa16178) == 0:
			m.set_u8(0xa13402, m.u8(0xa13402) & 0xfe)
			m.set_u16(0xa133f2, m.u16(0xa133f2) & 0x807f)
			m.set_u8(0xa133fc, st + 1)
			return 0
		if m.u16(0xa16178) == 1:
			return 1
		m.set_u8(0xa133fc, 1)
		return 0
	if st == 0x15:
		if f575e50(m.u8(0xa133f2) & 1) != 0:
			if (m.u8(0xa13402) & 1) != 0:
				return 1
			m.set_u8(0xa133fc, 1)
		return 0
	if f571530() == 0:
		if (m.u32(0xa114a8) & 0x102) != 0:
			m.set_u8(0xa133fc, 10)
		var button := f4613d0()
		if button == 3:
			m.set_u8(0xa13402, m.u8(0xa13402) & 0xfe)
			m.set_u16(0xa133f2, m.u16(0xa133f2) & 0x807f)
			m.set_u8(0xa133fc, 0x15)
			return 0
		if button == 5:
			return 1
	return 0

## FUN_00576350: fase final y efectos de final del turno en su orden original.
func f576350() -> int:
	var p := m.u8(0xa133f2) & 1
	var other := 1 - p
	var st := m.u8(0xa133fc)
	match st:
		0:
			issue((p << 15) | 0x55, 0, 0, 0)
			m.set_u32(0xa133fc, m.u32(0xa133fc) & 0xffff)
			f56a380(other, 3, 0)
		1:
			if f575ff0(p) == 0: return 0
			if (m.u8(DuelMem.pl(p) + 8) & 0x40) != 0: issue((p << 15) | 0x47, 0, 0, 0)
			f575f80(p)
		2:
			f5761c0(p)
			m.set_u16(0xa133fc, 0x503)
			return 0
		3:
			while m.u8(0xa133fd) < 10:
				var z := m.u8(0xa133fd)
				var a := DuelMem.zone(p, z)
				if (m.u32(a) & 0xfff) != 0 and (m.u8(a + 6) & 2) != 0 and f401a70(m.u16(a) & 0xfff) == 0x47:
					if (m.u8(a + 0x8f) & 4) == 0 and f542f30(0, 0x601) == 0 and f542f30(1, 0x601) == 0 and (m.u8(0xa133ed) & 1) == 0 and m.s8(0xa133ec) >= 0:
						issue((p << 15) | 0x8b, z, 1, 0)
						m.set_u16(0xa133fc, ((z + 1) << 8) | st)
						return 0
				m.set_u16(0xa133fc, ((z + 1) << 8) | st)
			m.set_u16(0xa133fc, 0x504)
			return 0
		4:
			while m.u8(0xa133fd) <= 9:
				var z := m.u8(0xa133fd)
				var a := DuelMem.zone(other, z)
				if (m.u32(a) & 0xfff) != 0 and (m.u8(a + 6) & 2) != 0:
					var id := f401a70(m.u16(a) & 0xfff)
					if id == 0x15b or id == 0x4ce:
						issue((other << 15) | 0x8b, z, 1, 0)
						if (m.u8(a + 6) & 0x3c) > (7 if id == 0x15b else 3): f54e250(other, z, 1)
						m.set_u8(0xa133fd, z + 1)
						return 0
					if id == 0x5f8 and f543570(other) >= 0 and (m.u8(a + 0x8f) & 4) == 0:
						f53baa0(((z & 0x1f | other << 15 | 0x880) << 16) | f401ad0(0x5f8), 0)
						m.set_u8(0xa133fd, z + 1)
						return 0
				m.set_u16(0xa133fc, ((z + 1) << 8) | st)
		5:
			if f543010(other, 0x5ef) != 0 and f5431f0(p, 1, 0) > 0:
				f53e760(other, 0xf, 0x5ef, f543070(other, 0x5ef))
			else:
				m.set_u8(0xa133fc, 10)
				return 0
		6:
			if m.u8(0xa13428) != 0: f53baa0(((f542e00(other, 0x5ef) & 0x1f | other << 15 | 0x440) << 16) | f401ad0(0x5ef), 0)
			m.set_u8(0xa133fc, 10)
			return 0
		10:
			# ASM 5767ff: solo borra el byte 0xa133fd (Ghidra lo muestra como escritura de
			# 32 bits); 0xa133fe/ff conservan el recorrido de f575ff0. Traza Frida de 2026-10-08.
			m.set_u8(0xa133fd, 0)
			while m.u8(0xa133fd) < 5:
				var z := m.u8(0xa133fd)
				var a := DuelMem.zone(p, z)
				if (m.u32(a) & 0xfff) != 0 and (m.u8(a + 6) & 2) != 0:
					var link := f545890(p, z, 0x60c)
					if link >= 0:
						var ref := m.u16(a + 8 + link * 2)
						var owner := ref & 1
						var target := ref >> 8
						var equipped := DuelMem.zone(owner, target)
						if (m.u8(equipped + 0x8f) & 4) == 0:
							issue((0x8000 if (ref & 0xff) != 0 else 0) | 0x8b, target, 1, 0)
							if (m.u8(equipped + 6) & 0x3c) > 3:
								f54eed0(ref & 0xff, f401ad0(0x60c), target)
								f54e420(ref & 0xff, target, 0)
								m.set_u8(0xa133fc, 11)
								return 0
				m.set_u16(0xa133fc, ((z + 1) << 8) | st)
			m.set_u8(0xa133fc, 20)
			return 0
		11:
			f54e250(p, m.u8(0xa133fd), 1)
			m.set_u8(0xa133fc, 10)
			return 0
		20:
			# El bit 23 de db indica retirada al final del turno.
			for i in range(m.u8(DuelMem.pl(p) + 4)):
				var card := m.u32(0xa12238 + p * PS + i * 4)
				if (card & 0x800000) != 0: issue((p << 15) | 0xd2, card & 0xffff, card >> 16, 0)
		21:
			if (m.u8(DuelMem.pl(p) + 0x13) & 1) != 0:
				issue((p << 15) | 0x4c, 0, 0, 0)
				if f5431f0(other, 1, 0) > 0:
					f53baa0(f401ad0(0x5ea) | (p << 31) | 0x266e0000, 0)
		22:
			if (m.u8(DuelMem.pl(other) + 0x13) & 1) != 0:
				issue((other << 15) | 0x4c, 0, 0, 0)
				if f5431f0(p, 1, 0) > 0: f53baa0(f401ad0(0x5ea) | (other << 31) | 0x266e0000, 0)
		_:
			if f542f30(0, 0x593) < 1 and f542f30(1, 0x593) < 1 and m.u8(DuelMem.pl(p) + 2) > 6:
				f53e830(p, m.u8(DuelMem.pl(p) + 2) - 6, 0, 0)
			return 1
	m.set_u8(0xa133fc, m.u8(0xa133fc) + 1)
	return 0

## FUN_00574c50: efecto del monstruo defensor al recibir un ataque.
func f574c50(p: int) -> int:
	var flags := m.u32(0xa114c0)
	var owner := (flags >> 1) & 1
	if (flags & 8) != 0:
		var index := flags >> 16
		var allowed: int = call("f551c40", owner, index, (flags >> 11) & 7)
		if (f401a70(index) != 0x2fa or (m.u8(0xa114d0 - p * 6) & 8) == 0) and allowed != 0:
			issue((0x8000 if owner != 0 else 0) | 0xad, f401a70(index), 1, 0)
			f53baa0((((flags & 0x3800) | owner << 26 | 0x1220000) << 5 | index) & 0xffffffff, 0)
	return 1

## FUN_00575750: aplica el efecto id 1538 que extiende los objetivos de ataque.
func f575750(p: int) -> int:
	var flags := m.u32(0xa114c0)
	var owner := (flags >> 1) & 1
	if f53d730(1) != 0: return 1
	f56e1c0(owner, (flags >> 11) & 7)
	var active := f542f30(p, 0x602) != 0 or f542f30(owner, 0x602) != 0
	var target := (flags >> 8) & 7
	if f571810(p, target, 0) == 0:
		if active:
			issue((0x8000 if p != 0 else 0) | 0x1e, 0x602, 1, 0)
			return 1
	elif active:
		for z in range(5):
			if z != target and f571810(p, z, 0) != 0:
				issue((0x8000 if p != 0 else 0) | 0x35, z, 1, 0)
	m.set_u8(0xa133f4, 0)
	m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x80ff) | 0x80)
	return 0


## FUN_00575880: cierre de batalla, efectos de cementerio y cambio a principal 2.
func f575880(p: int) -> int:
	match m.u8(0xa133f4):
		0:
			for z in range(5):
				var a := DuelMem.zone(p & 1, z)
				var index := m.u16(a) & 0xfff
				var flags := m.u16(a + 6)
				if index != 0 and f401a70(index) == 0x540 and (flags & 0x1000) == 0 and (flags & 1) == 0 and (flags & 2) != 0:
					f54eed0(p, index, z)
					call("f54e660", p, z, 0, 0)
				for owner in range(2):
					if f545810(owner, z, 0x49e) != 0:
						f54ef00(owner, f401ad0(0x49e))
						f54e250(owner, z, 1)
			m.set_u8(0xa133f4, 1)
			return 0
		1:
			for owner in range(2):
				for i in range(m.u8(DuelMem.pl(owner) + 4)):
					var card := m.u32(0xa12238 + owner * PS + i * 4)
					if (card & 0x1000000) != 0:
						var z := (card >> 25) & 7
						var target := DuelMem.zone(1 - owner, z)
						var enabled := (m.u8(target + 6) & 2) != 0 and (m.u16(target) & 0xfff) != 0 and f543570(1 - owner) >= 0 and f401a70(m.u16(target) & 0xfff) == 0x52f
						f56e350(owner, i, 1 if enabled else 0)
						return 0
			m.set_u8(0xa133f4, 2)
			return 0
		2, 3:
			if m.u8(0xa133f4) == 2:
				m.set_u8(0xa133f4, 3)
				m.set_u8(0xa133f5, 0)
				m.set_u8(0xa133f6, 0)
			var owner := m.u8(0xa133f5)
			var i := m.u8(0xa133f6)
			while owner < 2:
				while i < m.u8(DuelMem.pl(owner & 1) + 4):
					var card := m.u32(0xa12238 + (owner & 1) * PS + i * 4)
					if (card & 0x10000000) != 0 and (card & 0xfff) != 0:
						m.set_u8(0xa133f5, owner)
						m.set_u8(0xa133f6, i)
						m.set_u8(0xa133f4, 5)
						return 0
					i += 1
				owner += 1
				# El original conserva f6 al avanzar al segundo jugador.
				i = m.u8(0xa133f6)
			m.set_u8(0xa133f4, 4)
			return 0
		5:
			if f543360(1 - m.u8(0xa133f5)) != -1:
				f54ef00(p, f401ad0(0x53c))
				m.set_u8(0xa133f4, 6)
				return 0
			issue((0x8000 if m.u8(0xa133f5) != 0 else 0) | 0xda, m.u8(0xa133f6), 1, 0)
		6:
			var owner := 1 - m.u8(0xa133f5)
			if owner != 0 and (m.u8(0xa16181) & 1) == 0:
				m.set_u8(0xa13428, 1)
				m.set_u8(0xa133f4, 8)
				return 0
			var card := m.u16(0xa12238 + (m.u8(0xa133f5) & 1) * PS + m.u8(0xa133f6) * 4)
			f53e760(owner, 0x12, card & 0xfff, 0)
			m.set_u8(0xa133f4, 7)
			return 0
		7:
			var owner := m.u8(0xa133f5)
			var i := m.u8(0xa133f6)
			if m.u8(0xa13428) != 0:
				var a := 0xa12238 + (owner & 1) * PS + i * 4
				issue((0x8000 if owner != 0 else 0) | 0xd3, m.u16(a), m.u16(a + 2), 0)
				f541cb0(0xa133f8, a)
				m.set_u8(0xa133f4, 8)
				return 0
			issue((0x8000 if owner != 0 else 0) | 0xda, i, 1, 0)
		8:
			m.set_u32(0xa133f8, m.u32(0xa133f8) & 0xefffffff)
			call("f57cc50", 1 - m.u8(0xa133f5), 0xa133f8, 1, 0x20, 0xe, m.u8(0xa133f5))
		_:
			var a := DuelMem.pl(p & 1)
			if (m.u8(a + 8) & 0x40) != 0:
				issue((0x8000 if p != 0 else 0) | 0x47, 0, 0, 0)
				m.set_u16(0xa133f2, m.u16(0xa133f2) & 0x807f)
				m.set_u8(0xa133f4, 0)
				return 0
			m.set_u8(a + 0x10, m.u8(a + 0x10) | 1)
			return 1
	m.set_u8(0xa133f6, m.u8(0xa133f6) + 1)
	m.set_u8(0xa133f4, 3)
	return 0

## FUN_00575d50: destruye o devuelve el control de los monstruos marcados.
func f575d50(p: int) -> int:
	for owner in range(2):
		for z in range(5):
			var a := DuelMem.zone(owner, z)
			if (m.u32(a) & 0xfff) == 0: continue
			if (m.u16(a + 0x8e) & 1) != 0:
				f54e250(owner, z, 1)
				return 0
			if (m.u16(a + 0x8e) & 2) != 0:
				var slot := f543360(1 - owner)
				var source := (z << 8) | owner
				issue((0x8000 if p != 0 else 0) | 0xa4, source, 0, 0)
				if slot >= 0: f54d570(p, source, (slot << 8) | (1 - owner))
				else: f54e250(owner, z, 1)
				return 0
	return 1

## Sustituye el índice de la carta bajo el cursor que la interfaz C guardaba en su objeto.
func _m_hover_index() -> int:
	var p := m.u32(0xa161a4) & 1
	var loc := m.u32(0xa161a8)
	var n := m.u32(0xa161ac)
	if loc in [0, 5, 10]: return m.u16(DuelMem.zone(p, loc + n)) & 0xfff
	var bases := {11: 0xa11fb8, 12: 0xa12378, 13: 0xa120f8, 14: 0xa12238, 15: 0xa124b8}
	if bases.has(loc): return m.u16(int(bases[loc]) + p * 0xd54 + n * 4) & 0xfff
	return 0

func f5712b0() -> int:
	var index := _m_hover_index()
	if f583e00(index) != 0: return 0
	if ((m.u32(0xa114b4) >> 10) & 3) != 2:
		if (m.u8(0xa133f2) & 1) != 0: return f571080(0, index)
		return f5710d0(0, 0, index)
	var mask := f5710d0(1, 0, index)
	return mask | f571080(mask, index)

func f571330(p: int, loc: int) -> int:
	var index := _m_hover_index()
	if loc == 13 and f583e00(index) == 0: return 0
	if loc not in [12, 13, 14, 15]: return 0
	if loc in [12, 13] and p != 0 and f583e00(index) == 0: return 0
	m.set_u8(0xa13408, m.u8(0xa13408) & ~1)
	m.set_u8(0xa1340c, 0)
	m.set_u16(0xa1340a, 0)
	if f579890() != 0:
		# FUN_00413140 (resalta el objeto, presentacion) y la lista en modo 0 (solo ver).
		present("pile_highlight", {"p": p, "loc": loc})
		f407580(p, loc, 0, 0)
	return 0

func f5713b0() -> int:
	var p := m.u32(0xa161a4)
	var loc := m.u32(0xa161a8)
	var index := _m_hover_index()
	var eligible := false
	if loc in [0, 5, 10]:
		eligible = index != 0 and (p == 0 or (m.u8(DuelMem.zone(p & 1, loc + m.u32(0xa161ac)) + 6) & 2) != 0)
	elif loc == 11: eligible = (p == 0 or f5450e0(p) != 0) and index != 0
	if eligible:
		m.set_u8(0xa1340c, 0)
		var mask := f5712b0()
		m.set_u16(0xa1340a, mask)
		m.set_u8(0xa13408, (m.u8(0xa13408) & ~1) | int(mask != 0))
		return 1
	if loc == 13 and f583e00(index) == 0 and p == 0 and f579890() != 0:
		m.set_u8(0xa13408, m.u8(0xa13408) | 1)
		m.set_u8(0xa1340c, 0)
		m.set_u16(0xa1340a, 0x100)
		present("card_actions", {"mask": 0x100})
		return 1
	if loc in [12, 13, 14, 15]: f571330(p, loc)
	return 0

func f571510() -> int:
	if f5713b0() == 0:
		m.set_u8(0xa13408, m.u8(0xa13408) & ~1)
		m.set_u8(0xa1340c, 0)
		m.set_u16(0xa1340a, 0)
	return 0

## FUN_00571530: interaccion del jugador humano con la carta bajo el cursor (ver 0x53a1a0) y
## ejecucion de la accion elegida (0x53a400).
func f571530() -> int:
	if (m.u8(0xa13408) & 2) == 0:
		f583e00(0)
		if f5407e0() == 0 or (m.u8(0xa114a8) & 2) != 0:
			m.set_u8(0xa13408, m.u8(0xa13408) & 0xfe)
			m.set_u8(0xa1340c, 0)
			f540bb0()
			return 0
		if f53a160() != 0 or (m.u8(0xa13408) & 1) == 0:
			m.set_u8(0xa1340c, 0)
			f540bb0()
			f571510()
		f53a130()
		if (m.u8(0xa13408) & 1) == 0:
			m.set_u8(0xa1340c, 0)
			f540bb0()
		else:
			f53a1a0()
		if (m.u8(0xa13408) & 2) == 0:
			return 1
	invoke_original(0x53a400)
	return 1

func f570850(index: int, z: int, p: int = -1) -> int:
	if p < 0: p = m.u32(0xa161a4)
	var id := f401a70(index)
	var allowed := (m.u16(DuelMem.zone(p & 1, z) + 6) >> 12) & 1
	if id in [0x58, 0x105, 0x1ff]: allowed = int(f543400(p, z if id == 0x105 else -1) > 0)
	elif id in [0x51, 0x186, 0x16d]:
		allowed = 0
		if f545620(p, z, 0x28b if id == 0x16d else 0x291) != 0:
			var wanted := 0x2e5 if id == 0x51 else (0x187 if id == 0x186 else 0x170)
			for n in range(m.u8(DuelMem.pl(p) + 3)):
				if f401a70(m.u16(0xa120f8 + p * 0xd54 + n * 4) & 0xfff) == wanted and f542f30(0, 0x58a) < 1 and f542f30(1, 0x58a) < 1: return 1
	elif id == 0x1a0 or id == 0x243:
		allowed = f551cb0(p, z, 2) if (m.u8(0xa133f2) & 0xe) == 2 else 0
	elif id == 0x5e9:
		if allowed != 0:
			for n in range(m.u8(DuelMem.pl(p) + 4)):
				if ((f401a20(m.u16(0xa12238 + p * 0xd54 + n * 4) & 0xfff) >> 20) & 31) < 21: return 1
		allowed = 0
	elif id == 0x2da or id == 0x536:
		var enabled := allowed
		allowed = 0
		if f5451f0(p, z) == -1 and f543570(p) != -1:
			for target in range(5):
				if f54f910(index, 1 - p, target) != 0:
					allowed = enabled
					break
	elif id in [0xf, 0x191, 0x1a3, 0x1ac, 0x1f9, 0x2e6, 0x34d, 0x458, 0x596, 0x598, 0x599, 0x59f, 0x5a2, 0x5a4, 0x5e6]: allowed = f551cb0(p, z, 0)
	else: return 0
	if allowed != 0:
		return allowed
	# 0x5708f5: carta con efecto que ahora no se puede usar -> ayuda 4 (help05).
	if (f541950(index) & 0xffff) != 0:
		f4437a0(4)
	return 0

func f570cb0(index: int, p: int) -> int:
	var z := m.u32(0xa161ac)
	if ((m.u32(0xa114b4) >> 10) & 3) != 2 and p != 0: return 0
	var phase := (m.u8(0xa133f2) >> 1) & 7
	var face := m.u16(DuelMem.zone(p & 1, z) + 6)
	if phase == 1:
		if (face & 2) != 0 and f401a70(m.u16(DuelMem.zone(p & 1, z)) & 0xfff) in [0x1a0, 0x243] and f551cb0(p, z, 2) != 0: return 8
		return 0
	if phase == 2 or phase == 4:
		var mask := 0
		if f544100(p, z) == 0:
			# Ya cambio de posicion este turno (bit 1 del byte +7): ayuda 4 (help04).
			if (m.u8(DuelMem.zone(p & 1, z) + 7) & 2) != 0:
				f4437a0(3)
		else:
			if (face & 2) == 0:
				if (face & 1) == 0: mask = 0x20
				if f56e600(0) != 0: mask |= 2
			else: mask = 0x20 if (face & 1) == 0 else 0x40
		if (face & 2) != 0 and f570850(index, z, p) != 0: mask |= 8
		return mask
	if phase == 3:
		if (m.u16(0xa1195a + (p & 1) * 0xd54) & (1 << (z & 31))) == 0:
			if f571810(p, z, 1) == 0:
				f4437a0(7)
				return 0
			return 4
		# Ya ataco: ayuda 9 (help09).
		f4437a0(8)
	return 0

func f570e50(p: int = -1, z: int = -1, index: int = -1) -> int:
	if p < 0: p = m.u32(0xa161a4)
	if z < 0: z = m.u32(0xa161ac)
	if index < 0: index = m.u16(DuelMem.zone(p & 1, z + 5)) & 0xfff
	if p != 0: return 0
	var a := DuelMem.zone(0, z + 5)
	var type := (f401a20(index) >> 20) & 31
	var phase := (m.u8(0xa133f2) >> 1) & 7
	var mask := 0
	if type == 22:
		# 0x570e50: boca abajo -> ayuda 4 (help05, no se puede activar) antes de mirar el
		# turno de colocacion; 10 si es una magia de velocidad 3 y 5 en la fase de batalla.
		if (m.u8(a + 6) & 2) == 0:
			f4437a0(4)
			if (m.u8(a + 0x8f) & 2) != 0:
				var speed := f53b880(index)
				if ((phase == 2 or phase == 4) and (m.u8(0xa133f2) & 1) == 0) or speed == 5:
					if f53b880(index) == 3:
						f4437a0(10)
					if f551c40(0, index, z + 5) != 0: mask = 8
				elif phase == 3:
					f4437a0(5)
		if phase == 1:
			var id := f401a70(index)
			if (m.u8(0xa133f2) & 1) == 0:
				if id == 0x428 and (m.u8(a + 6) & 2) == 0 and f551cb0(0, z + 5, 2) != 0: mask = 8
			elif id == 0x489 and f551cb0(1, z + 5, 2) != 0: mask = 8
	elif type == 21:
		if f401a70(index) in [0x594, 0x3f9, 0x52c, 0x5fc] or (m.u8(a + 6) & 2) == 0:
			# Ayuda 4 y, si aun es el turno en que se coloco, ayuda 1 (help02).
			f4437a0(4)
			if (m.u8(a + 0x8f) & 2) == 0:
				f4437a0(1)
			elif f551cb0(0, z + 5, 0) != 0:
				mask = 8
	if type > 20 and type < 23 and (m.u16(0xa1194a) & 0xc000) != 0: mask = 0
	return mask

func f571080(mask: int, index: int) -> int:
	if m.u32(0xa161a8) == 5 and f551990(index) > 1 and m.u32(0xa161a4) == 0: return mask | f570e50(0, m.u32(0xa161ac), index)
	return mask

func f5710d0(opponent: int, mask: int, index: int) -> int:
	var loc := m.u32(0xa161a8)
	var owner := m.u32(0xa161a4)
	if loc in [0, 5, 10, 11]:
		if (index & 0xffff) == 0: return 0
		if owner == 0 or opponent != 0:
			if loc == 0: return mask | f570cb0(index, owner)
			if loc == 11: return mask | int(invoke_original(0x570450, [owner, m.u32(0xa161ac), index]))
			return mask | f570e50(owner, 5 if loc == 10 else m.u32(0xa161ac), index)
	elif loc == 12:
		var phase := (m.u8(0xa133f2) >> 1) & 7
		if f543fc0() == 0x60b and (phase == 2 or phase == 4):
			var e := m.local(20)
			m.clear(e, 20)
			m.set_u16(e, f401ad0(0x60b))
			if f552e00(e) != 0: return mask | 0x200
	elif loc == 13: return 0x80 if (m.u8(0xa133f2) & 0xe) == 0 else 0
	return mask

func f574d20(p: int) -> int:
	var flags := m.u32(0xa114c0)
	if flags & 4: return 1
	var defender := (flags >> 1) & 1
	var source := (flags >> 8) & 7
	var target := (flags >> 11) & 7
	var own_index := m.u16(0xa114c6 + p * 12)
	var other_index := m.u16(0xa114d2 - p * 12)
	var own_id := f401a70(own_index)
	var other_id := f401a70(other_index)
	var own_snapshot := 0xa114dc + p * 0x94
	var other_snapshot := 0xa11570 - p * 0x94
	var own_destroyed := (m.u8(0xa114c4 + p * 12) & 8) != 0
	var other_destroyed := (m.u8(0xa114d0 - p * 12) & 8) != 0
	var refs := (((target << 8) | defender) << 16) | (source << 8) | p
	var state := m.u8(0xa133f4)
	if state == 1:
		if own_id == 0xff or other_id == 0xff:
			if m.u16(0xa1160c) != 0xffff: f54cec0(p, source, own_snapshot)
			if m.u16(0xa1160e) != 0xffff: f54cec0(defender, target, other_snapshot)
			m.set_u16(0xa1160c, 0xffff)
			m.set_u16(0xa1160e, 0xffff)
		else:
			if m.u16(0xa1160c) != 0xffff: f54cf50(defender, p, source, own_snapshot)
			if m.u16(0xa1160e) != 0xffff: f54cf50(p, defender, target, other_snapshot)
		m.set_u8(0xa133f4, 2)
		return 0
	if state == 2:
		if m.u16(0xa1160c) != 0xffff or m.u16(0xa1160e) != 0xffff: f56a380(defender, 0x13, m.u16(0xa1160c) | (m.u16(0xa1160e) << 16))
		return 1
	if own_id == 0x18e or own_id == 0x188:
		if f583e00(p) == 0:
			f54eed0(p, own_index, source)
			issue((defender << 15) | 0x97, target, 5, 0)
	elif own_id == 0xff: f53baa0(((flags & 0x700 | p << 23 | 0x244000) << 8) | own_index, refs)
	elif own_id == 0x199:
		if f583e00(p) == 0: f54eed0(p, own_index, source)
	elif own_id == 0x5f3 and other_destroyed and (m.u32(DuelMem.zone(p, source)) & 0xfff) != 0:
		f54eed0(p, own_index, source)
		f54c860(p, (source << 8) | p, (source << 8) | p, 0x10c)
	m.set_u16(0xa1160c, 0xffff)
	if own_destroyed:
		_m_battle_destroy(p, source, own_id, own_index, defender, target, other_id, own_snapshot, 0xa1160c, (flags << 14) & 0xe000000)
	if other_id == 0x419:
		if f583e00(p) == 0 and not own_destroyed: f53baa0(((flags & 0x3800 | defender << 26 | 0x1220000) << 5) | other_index, refs)
	elif other_id == 0xff: f53baa0(((flags & 0x700 | defender << 23 | 0x244000) << 8) | other_index, refs)
	elif other_id == 0x189:
		if f583e00(p) == 0 and f545c40(p, source) != 7:
			f54eed0(defender, other_index, target)
			issue((p << 15) | 0x97, source, 3, 0)
	elif other_id == 0x261:
		if f583e00(p) == 0 and f545c40(p, source) != 2:
			f54eed0(defender, other_index, target)
			issue((p << 15) | 0x99, source, 1, 0)
	elif other_id == 0x4b1:
		if not other_destroyed and (m.u8(DuelMem.zone(defender, target) + 6) & 1) != 0:
			f54eed0(defender, other_index, target)
			issue((defender << 15) | 0x7f, target, 0, 0)
	elif other_id == 0x5f3 and own_destroyed and (m.u32(DuelMem.zone(defender, target)) & 0xfff) != 0:
		f54eed0(defender, other_index, target)
		f54c860(defender, (target << 8) | defender, (target << 8) | defender, 0x10c)
	m.set_u16(0xa1160e, 0xffff)
	if other_destroyed:
		_m_battle_destroy(defender, target, other_id, other_index, p, source, own_id, other_snapshot, 0xa1160e, (flags << 17) & 0xe000000)
	m.set_u8(0xa133f4, state + 1)
	return 0

func _m_battle_destroy(owner: int, z: int, id: int, index: int, opponent: int, other_z: int, other_id: int, snapshot: int, dest: int, owner_bits: int) -> void:
	if other_id == 0x2f9: m.set_u8(DuelMem.pl(opponent) + 8, m.u8(DuelMem.pl(opponent) + 8) | 8)
	if (id == 0x2da or id == 0x536) and f5451f0(owner, z) != -1:
		f54e9e0(owner, z)
		issue((owner << 15) | 0xa6, z, m.u16(snapshot), m.u16(snapshot + 2))
		return
	if other_id != 0xff and id != 0xff:
		if id > 0x4e5 and id < 0x4e9:
			f54eed0(owner, index, z)
			f54c860(owner, index, (other_z << 8) | opponent, 9)
		if other_id == 0x52f:
			m.set_u32(snapshot, (m.u32(snapshot) | 0x1000000) & ~0xe000000 | owner_bits)
		elif other_id == 0x53c: m.set_u32(snapshot, m.u32(snapshot) | 0x10000000)
	m.set_u16(dest, (z << 8) | owner)

func _m_damage_trigger(p: int, defender: int, source: int, target: int, recipient: int, damage: int, first: bool) -> void:
	var owner := defender if first else p
	var z := target if first else source
	var index := m.u16(0xa114d2 - p * 12) if first else m.u16(0xa114c6 + p * 12)
	var id := f401a70(index)
	if id in [0x20a, 0x71, 0xdb]:
		f54eed0(owner, index, z)
		if id == 0x20a: f54f470(recipient, 2)
		elif id == 0x71: f53e8b0(recipient, 1, 1)
		else: f54f470(owner, 1)
	elif id == 0x530 or id == 0x5e7:
		var code := ((((m.u32(0xa114c0) & 0x3800) | (defender << 26) | 0xe20000) << 5) | index) if first else ((((m.u32(0xa114c0) & 0x700) | (p << 23) | 0x1a4000) << 8) | index)
		var refs := (((target << 4) | defender) << 8) | (source << 4) | p
		if not first: refs = (((source << 4) | p) << 8) | (target << 4) | defender
		f53baa0(code, (refs << 16) | damage)

func f574420(p: int) -> int:
	var flags := m.u32(0xa114c0)
	var defender := (flags >> 1) & 1
	var source := (flags >> 8) & 7
	var target := (flags >> 11) & 7
	var own_damage := m.u16(0xa114ce + p * 12)
	var other_damage := m.u16(0xa114da - p * 12)
	# ASM 574420: &a1194a + jugador*d54 + 2 = base del jugador +8.
	var own_prevent := m.u16(DuelMem.pl(p) + 8) & 3
	var other_prevent := m.u16(DuelMem.pl(defender) + 8) & 3
	var state := m.u8(0xa133f4)
	match state:
		0:
			if own_damage != 0 and own_prevent == 0:
				f54efe0(p, own_damage, (source << 8) | p, (target << 8) | defender)
				if p != defender: _m_damage_trigger(p, defender, source, target, p, own_damage, true)
				if f401a70(m.u16(0xa114c6 + p * 12)) == 0x2da and f5451f0(p, source) != -1 and other_prevent == 0: f54ef90(1 - p, own_damage)
			m.set_u8(0xa133f4, 1)
			return 0
		1:
			if other_damage != 0 and other_prevent == 0 and f545060(defender, 0x76d) + f545060(defender, 0x39) != 0:
				m.set_u8(0xa133f4, 10)
			else: m.set_u8(0xa133f4, 2)
			return 0
		2:
			if other_damage != 0 and other_prevent == 0:
				f54efe0(defender, other_damage, (source << 8) | p, (target << 8) | defender)
				if p != defender: _m_damage_trigger(p, defender, source, target, defender, other_damage, false)
				if f401a70(m.u16(0xa114d2 - p * 12)) == 0x2da and f5451f0(defender, target) != -1 and own_prevent == 0: f54ef90(1 - defender, other_damage)
			m.set_u8(0xa133f4, 3)
			return 0
		10:
			if defender == 0:
				# Cuadro Si/No: mensaje 0xe3 con el nombre de la carta 0x39; 12 lee la respuesta.
				dialog_format(0xe3, [{"card": f401ad0(0x39)}])
				f540d60(1, 0)
				m.set_u8(0xa133f4, 12)

			elif (m.u8(0xa16181) & 1) == 0:
				m.set_u16(0xa16178, 1) # ASM 574976: mov word ptr
				m.set_u8(0xa133f4, 12)
			else:
				f53ed60(0xf057, f401ad0(0x39), 0, 0)
				m.set_u32(0xa15b8c, m.u32(0xa15b8c) & ~2)
				m.set_u8(0xa133f4, 11)
			return 0
		11:
			if (m.u32(0xa15b8c) & 2) == 0: return 0
			m.set_u16(0xa16178, m.u16(0xa15b98)) # ASM 5749da: mov word ptr
			m.set_u8(0xa133f4, 12)
			return 0
		12:
			if m.u16(0xa16178) != 0: # ASM 5749f3: cmp word ptr
				for n in range(m.u8(DuelMem.pl(defender) + 2)):
					var id := f401a70(m.u16(0xa11fb8 + defender * 0xd54 + n * 4) & 0xfff)
					if id == 0x39 or id == 0x76d:
						issue((defender << 15) | 0x72, id, 0xb, n)
						if f54f880(defender, id) != 0:
							m.set_u16(0xa114da - p * 12, 0)
							issue((defender << 15) | 0xea, 0, 0, 0)
							f56e0b0(defender)
						break
			m.set_u8(0xa133f4, 2)
			return 0
		_:
			for owner in range(2): m.set_u16(DuelMem.pl(owner) + 8, m.u16(DuelMem.pl(owner) + 8) & ~1)
			if f401a70(m.u16(0xa114d2 - p * 12)) == 0x4b1 and (m.u8(0xa114d0 - p * 12) & 8) == 0 and (m.u8(DuelMem.zone(defender, target) + 6) & 1) != 0:
				f54eed0(defender, m.u16(0xa114d2 - p * 12), target)
				f54e660(defender, target, 0, 0)
			for owner in range(2):
				var record := m.u16(0xa114c4 + owner * 12)
				if (record & 0x40) != 0 and (record & 8) == 0:
					var ref := ((source << 8) | p) if owner == p else ((target << 8) | defender)
					f54c860(p, f401ad0(0x49e), ref, 3)
			return 1

func f5736f0(p: int) -> int:
	var flags := m.u32(0xa114c0)
	var attacker := flags & 1
	var defender := (flags >> 1) & 1
	var source := (flags >> 8) & 7
	var target := (flags >> 11) & 7
	var source_a := DuelMem.zone(attacker, source)
	var target_a := DuelMem.zone(defender, target)
	var state := m.u8(0xa133f4)
	match state:
		0:
			var id := f401a70(m.u16(source_a) & 0xfff)
			if id == 0x538 and (m.u8(source_a + 7) & 0x10) != 0:
				issue((attacker << 15) | 0x94, source, 0, 0)
			else:
				if id == 0x540: issue((attacker << 15) | 0x94, source, 0, 0)
				issue((attacker << 15) | 0x35, source, 1, 0)
			for z in range(5, 10):
				var a := DuelMem.zone(defender, z)
				if (m.u32(a) & 0xfff) != 0 and (m.u8(a + 6) & 2) != 0 and (m.u16(a + 0x8e) & 0x400) == 0 and f401a70(m.u16(a) & 0xfff) == 1099:
					f54c860(defender, (z << 8) | defender, flags & 0x701, 2)
			if (flags & 4) == 0:
				for n in range(m.u16(source_a + 0x88)):
					var ref := m.u16(source_a + 8 + n * 2)
					var a := DuelMem.zone(ref & 1, (ref >> 8) & 0xff)
					if (m.u8(a + 0x8f) & 4) == 0 and f401a70(m.u16(a) & 0xfff) == 0x291:
						f54eed0(ref & 0xff, m.u16(a) & 0xfff, ref >> 8)
			m.set_u8(0xa133f4, 1)
			return 0
		1:
			f539ac0(attacker, 0)
			if (flags & 4) == 0 and attacker != defender and (m.u8(target_a + 6) & 2) != 0:
				var id := f401a70(m.u16(target_a) & 0xfff)
				if id == 0x4db and f401a70(flags >> 16) == 0x4db and (m.u8(target_a + 6) & 1) != 0 and f5431b0(attacker) > 1:
					m.set_u8(0xa133f4, 30)
					return 0
				if id > 0x171 and id < 0x175 and (m.u8(target_a + 7) & 0x10) != 0:
					m.set_u8(0xa133f4, 10)
					return 0
				if id == 0x5f2 and f5431b0(defender) > 1:
					m.set_u8(0xa133f4, 20)
					return 0
			m.set_u8(0xa133f4, 2)
			issue((attacker << 15) | 0x30, m.u16(0xa114c6), m.u16(0xa114d2), 0)
			m.set_u8(0xa133f4, 3)
			return 0
		2:
			issue((attacker << 15) | 0x30, m.u16(0xa114c6), m.u16(0xa114d2), 0)
			m.set_u8(0xa133f4, 3)
			return 0
		3:
			var a := (int(m.u16(0xa114ce) != 0) << 2) | ((m.u8(0xa114c4) >> 3 & 1) << 1) | (m.u8(0xa114c4) >> 4 & 1)
			var b := (int(m.u16(0xa114da) != 0) << 2) | ((m.u8(0xa114d0) >> 3 & 1) << 1) | (m.u8(0xa114d0) >> 4 & 1)
			issue((attacker << 15) | 0x31, m.u16(0xa114ce), m.u16(0xa114da), a | (b << 8))
			m.set_u8(0xa133f4, 4)
			return 0
		4:
			for owner in range(2):
				var record := m.u16(0xa114c4 + owner * 12)
				if record & 8: issue(((attacker if owner == attacker else defender) << 15) | 0x78, record & 7, 0, 0)
			return 1
		10, 30:
			if defender == 0:
				# Cuadro Si/No: mensaje 0xe1/0xe2 con el nombre del monstruo atacado.
				dialog_format(0xe1 if state == 10 else 0xe2, [{"card": m.u16(target_a) & 0xfff}])
				f540d60(1, 0)
				m.set_u8(0xa133f4, state + 2)

			elif (m.u8(0xa16181) & 1) != 0:
				f53ed60(0xf057, m.u16(target_a) & 0xfff, 0, 0)
				m.set_u32(0xa15b8c, m.u32(0xa15b8c) & ~2)
				m.set_u8(0xa133f4, state + 1)
			else:
				m.set_u16(0xa16178, 1) # ASM 573ced: mov word ptr
				m.set_u8(0xa133f4, state + 2)
			return 0
		11, 31:
			if (m.u32(0xa15b8c) & 2) != 0:
				m.set_u16(0xa16178, m.u16(0xa15b98)) # ASM 573d86: mov word ptr
				m.set_u8(0xa133f4, state + 1)
			return 0
		12:
			if m.u16(0xa16178) != 0: # ASM 573d97: cmp word ptr
				f54eed0(defender, m.u16(target_a) & 0xfff, target)
				issue((defender << 15) | 0x94, target, 0, 0)
				issue((attacker << 15) | 0x3a, 0, 0, 0)
				f539ac0(attacker, 1)
			m.set_u8(0xa133f4, 2)
			return 0
		20:
			f54eed0(defender, m.u16(target_a) & 0xfff, target)
			f53e760(defender, 0x14, target, 0)
			m.set_u8(0xa133f4, 21)
			return 0
		21:
			issue((defender << 15) | 8, defender, m.u8(0xa13428) << 8, 0)
			issue((attacker << 15) | 0x33, source, target, defender + 1)
			issue((defender << 15) | 0x38, defender, 0, 0)
			m.set_u8(0xa133f4, 0)
			var phase := m.u16(0xa133f2)
			m.set_u16(0xa133f2, (phase & ~0x7f80) | ((((phase >> 7) - 1) * 0x80) & 0x7f80))
			return 0
		32:
			if m.u16(0xa16178) == 0: # ASM 5740a9: cmp word ptr
				m.set_u8(0xa133f4, 2)
			else:
				f54eed0(defender, m.u16(target_a) & 0xfff, target)
				f53e760(defender, 0x10, source, 0)
				m.set_u8(0xa133f4, 33)
			return 0
		33:
			issue(((1 - defender) << 15) | 8, 1 - defender, m.u8(0xa13428) << 8, 0)
			flags = (flags & ~0x3802) | ((1 - defender) << 1) | ((m.u8(0xa13428) & 7) << 11)
			m.set_u32(0xa114c0, flags)
			m.set_u16(0xa1160a - p * 2, m.u16(DuelMem.zone((flags >> 1) & 1, (flags >> 11) & 7) + 4))
			issue((attacker << 15) | 0x33, source, (flags >> 11) & 7, ((flags >> 1) & 1) + 1)
			m.set_u8(0xa133f4, 34)
			return 0
		34:
			flags = ((m.u16(target_a) << 16) | (flags & 0xffff)) & 0xfffffff
			if (m.u8(target_a + 6) & 2) == 0:
				f54d2d0(defender, target, 0, 1)
				f54ef60(defender, m.u16(target_a) & 0xfff)
				f56dd40(defender)
				flags = (flags & ~8) | ((f541d10(f401a70(flags >> 16), 1) & 1) << 3)
				if f542f30(0, 0x5fa) != 0 or f542f30(1, 0x5fa) != 0: flags &= ~8
			else: flags &= ~8
			m.set_u32(0xa114c0, flags)
			m.set_u8(0xa133f4, 35)
			return 0
		35:
			f539ac0(attacker, 0)
			m.set_u8(0xa133f4, 2)
			return 0
		_:
			if f53d730(1) != 0:
				m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x86ff) | 0x680)
				m.set_u8(0xa13402, m.u8(0xa13402) | 1)
			return 1

func _m_battle_direct(p: int, source: int) -> int:
	issue((p << 15) | 0x34, source, 1, 0)
	m.set_u32(0xa114c0, (m.u32(0xa114c0) & 0xffffefff) | 0x2804)
	return 1

func _m_battle_cancel(p: int, source: int, reset: bool) -> void:
	m.set_u8(0xa133f4, 0)
	var phase := m.u16(0xa133f2)
	if reset:
		m.set_u16(0xa133f2, (phase & 0x80ff) | 0x80)
	else:
		m.set_u16(0xa133f2, (phase & ~0x7f80) | ((((phase >> 7) - 1) * 0x80) & 0x7f80))
	if reset or (m.u8(0xa114c0) & 0x80) != 0: f5715c0(p, source)

func f572340(p: int) -> int:
	var flags := m.u32(0xa114c0)
	var other := 1 - p
	var source := (flags >> 8) & 7
	flags = (flags & ~2) | (other << 1)
	if f5431b0(other) == 0: flags |= 4
	m.set_u32(0xa114c0, flags)
	if flags & 4: return _m_battle_direct(p, source)
	var state := m.u8(0xa133f4)
	if state == 0:
		var forced := f5459b0(other, 0x422)
		if forced > 0:
			issue((other << 15) | 0x1e, 0x422, 0, 0)
			if p != 0:
				var target := f545a10(other, 0x422)
				var strength := f547c80(other, target) if (m.u8(DuelMem.zone(other, target) + 6) & 1) != 0 else f547c60(other, target)
				if strength >= f547c60(p, source):
					_m_battle_cancel(p, source, true)
					return 0
			if p != 0 or forced == 1:
				m.set_u32(0xa114c0, (flags & ~0x3800) | ((f545a10(other, 0x422) << 11) & 0x3800))
				m.set_u8(0xa133f4, 4)
			else: m.set_u8(0xa133f4, 20)
			return 0
		state = 1
		m.set_u8(0xa133f4, state)
	if state == 1:
		if f541ce0(f401a70(m.u16(DuelMem.zone(p, source)) & 0xfff)) != 0 and f5438c0(other) != 0:
			m.set_u8(0xa133f4, 30)
			return 0
		if f571600(p, source) != 0:
			m.set_u8(0xa133f4, 10)
			return 0
		state = 2
		m.set_u8(0xa133f4, state)
	if state == 2:
		if p != 0:
			if f57eb90(0) == 0:
				issue(0x8035, source, 1, 0)
				m.set_u8(0xa133f4, 0)
				m.set_u16(0xa133f2, (m.u16(0xa133f2) & 0x80ff) | 0x80)
				return 0
			if m.u32(0xa1344c) & 2: return _m_battle_direct(p, source)
			flags = (flags & ~0x3800) | ((m.u32(0xa1344c) << 4) & 0x3800)
			m.set_u32(0xa114c0, flags)
			issue(0x8033, source, (flags >> 11) & 7, other + 1)
			return 1
		# FUN_0040cc30: el objeto de batalla pasa al estado 3 (el icono apunta al raton).
		present("battle_aim", {})
		f53f7e0(1, 0, 0)
		m.set_u8(0xa133f4, 3)
		return 0
	if state == 4:
		issue((p << 15) | 0x33, source, (flags >> 11) & 7, ((flags >> 1) & 1) + 1)
		return 1
	if state == 10:
		# "Atacar directamente?" (0xdf) con Si/No; la CPU ataca directamente sin preguntar.
		if p != 0: return _m_battle_direct(p, source)
		f5417e0(0xdf)
		f540d60(1, 0)
		m.set_u8(0xa133f4, state + 1)
		return 0
	if state == 11:
		if m.u16(0xa16178) != 0: return _m_battle_direct(p, source)
		m.set_u8(0xa133f4, 2)
		return 0
	if state == 3:
		# Objetivo con el cursor: monstruos del rival (mascara 0xf0 desplazada al jugador).
		if f57a060(0xf0 << (((~m.u16(0xa133f2)) & 1) << 4)) != 0:
			var z := m.u32(0xa161ac)
			var at := DuelMem.zone(1, z)
			if (m.u8(at + 6) & 2) != 0 and (m.u32(at) & 0xfff) != 0 					and f401a70(m.u16(at) & 0xfff) == 0x52e and f543fc0() == 0x14d:
				return 0
			if f579890() != 0:
				m.set_u16(0xa114c0, m.u16(0xa114c0) ^ (((z << 11) ^ m.u16(0xa114c0)) & 0x3800))
				m.set_u8(0xa133f4, state + 1)
		if (m.u32(0xa114a8) & 0x102) != 0:
			f53f7e0(p, 0, (m.u32(0xa114c0) >> 8) & 7)
			_m_battle_back(p)
		return 0
	if state == 20:
		if f57a060(0xe00000) != 0 and f545620(other, m.u32(0xa161ac), 0x422) != 0 and f579890() != 0:
			m.set_u16(0xa114c0, m.u16(0xa114c0) ^ (((m.u32(0xa161ac) << 11) ^ m.u16(0xa114c0)) & 0x3800))
			m.set_u8(0xa133f4, 4)
		if (m.u32(0xa114a8) & 0x102) != 0:
			m.set_u8(0xa133f4, 0)
			var ph := m.u32(0xa133f2)
			m.set_u32(0xa133f2, ph ^ ((((ph >> 7) - 1) * 0x80 ^ ph) & 0x7f80))
		return 0
	if state == 30:
		if (m.u16(0xa114b4) & 0x200) == 0 and p == 0:
			if f57a060(0xf00000) != 0:
				var id := f401a70(m.u16(DuelMem.zone(1, m.u32(0xa161ac))) & 0xfff)
				if f541ce0(id) != 0 and f579890() != 0:
					m.set_u16(0xa114c0, m.u16(0xa114c0) ^ (((m.u32(0xa161ac) << 11) ^ m.u16(0xa114c0)) & 0x3800))
					m.set_u8(0xa133f4, 3)
			if (m.u32(0xa114a8) & 0x102) != 0:
				m.set_u8(0xa133f4, 0)
				var ph := m.u32(0xa133f2)
				m.set_u32(0xa133f2, ph ^ ((((ph >> 7) - 1) * 0x80 ^ ph) & 0x7f80))
		return 0
	return 1

## Cancelacion del ataque en el estado 3 de 0x572340: vuelve al paso anterior de la fase y,
## si el atacante ya estaba marcado (bit 7 de 0xa114c0), lo libera con 0x5715c0.
func _m_battle_back(p: int) -> void:
	m.set_u8(0xa133f4, 0)
	var ph := m.u32(0xa133f2)
	m.set_u32(0xa133f2, ph ^ ((((ph >> 7) - 1) * 0x80 ^ ph) & 0x7f80))
	if (m.u8(0xa114c0) & 0x80) != 0:
		f5715c0(p, (m.u32(0xa114c0) >> 8) & 7)

func f5732e0() -> int:
	var flags := m.u32(0xa114c0)
	if flags & 4: return 1
	var owner := (flags >> 1) & 1
	var target := (flags >> 11) & 7
	var source := (flags >> 8) & 7
	var p := flags & 1
	var state := m.u8(0xa133f4)
	if state == 0:
		if (m.u8(DuelMem.zone(owner, target) + 6) & 2) == 0:
			f54d2d0(owner, target, 0, 1)
			f54ef60(owner, m.u32(DuelMem.zone(owner, target)) & 0xfff)
			f56dd40(owner)
			m.set_u8(0xa133f4, 1)
			return 0
		m.set_u32(0xa114c0, flags & 0xffff)
		m.set_u8(0xa133f4, 2)
		return 0
	if state == 1:
		flags = ((m.u16(DuelMem.zone(owner, target)) << 16) | (flags & 0xffff)) & 0xfffffff
		var id := f401a70(flags >> 16)
		flags = (flags & ~8) | ((f541d10(id, 1) & 1) << 3)
		if f542f30(0, 0x5fa) != 0 or f542f30(1, 0x5fa) != 0: flags &= ~8
		m.set_u32(0xa114c0, flags)
		if id == 0x2df or id == 0x492:
			if (m.u8(DuelMem.zone(owner, target) + 6) & 1) != 0 and f542f30(0, 0x5fa) == 0 and f542f30(1, 0x5fa) == 0 and f5435a0(owner, m.u32(DuelMem.zone(owner, target)) & 0xfff) != 0:
				var slot := f543570(owner)
				f54eed0(owner, flags >> 16, target)
				f54d570(owner, (target << 8) | owner, (slot << 8) | owner)
				f54e730(owner, (slot << 8) | owner, (source << 8) | p)
				issue((p << 15) | 0x35, source, 1, 0)
				f539ac0(p, 0)
				m.set_u16(0xa114c4, m.u16(0xa114c4) & ~8)
				m.set_u16(0xa114d0, m.u16(0xa114d0) & ~8)
				m.set_u16(0xa114ce, 0)
				m.set_u16(0xa114da, 0)
				m.set_u32(0xa114c0, flags & ~8)
				m.set_u8(0xa133f4, 0)
				var phase := m.u16(0xa133f2)
				m.set_u16(0xa133f2, (phase & ~0x7f80) | (((phase & 0xff80) + 0x200) & 0x7f80))
				return 0
			m.set_u32(0xa114c0, flags & ~8)
		m.set_u8(0xa133f4, 2)
		return 0
	if state == 2:
		f56a380(1 - p, 0x11, (((target << 8) | owner) << 16) | (source << 8) | p)
		m.set_u8(0xa133f4, 3)
		return 0
	return 1





