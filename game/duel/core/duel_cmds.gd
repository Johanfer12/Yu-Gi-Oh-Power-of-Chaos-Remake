class_name DuelCmds
extends DuelPortO
## Despachador de comandos (FUN_0053aca0) y manejadores portados fuera de los modulos
## DuelPort*. Los manejadores que solo hacen presentacion (animaciones, voces, guion de los
## tutoriales) terminan al momento y dejan un evento para la escena del duelo.

## opcode & 0xfff -> [funcion, argumentos]. Generado a partir del switch de 0x53aca0.
const DISPATCH := {
	0x01: ["f54bab0", []],
	0x02: ["f54bdb0", []],
	0x03: ["f4039b0", []],
	0x04: ["f405230", []],
	0x05: ["f406a30", []],
	0x06: ["f4068c0", []],
	0x07: ["f404430", []],
	0x08: ["f4027e0", []],
	0x09: ["f54c6a0", []],
	0x0a: ["f4030b0", []],
	0x0b: ["f4030f0", []],
	0x10: ["f54c570", []],
	0x11: ["f402fa0", []],
	0x12: ["f4039b0", []],
	0x13: ["f4039b0", []],
	0x14: ["f405190", []],
	0x15: ["f54b950", []],
	0x16: ["f54b950", []],
	0x17: ["f54b950", []],
	0x18: ["f54b950", []],
	0x19: ["f54b950", []],
	0x1a: ["f54b950", []],
	0x1b: ["f54b950", []],
	0x1c: ["f54c440", []],
	0x1d: ["f54c460", []],
	0x1e: ["f407190", []],
	0x1f: ["f4032e0", []],
	0x20: ["f403390", []],
	0x21: ["f403420", []],
	0x30: ["f4039b0", []],
	0x31: ["f402ba0", []],
	0x32: ["f547ca0", []],
	0x33: ["f402ad0", []],
	0x34: ["f402b30", []],
	0x35: ["f547d40", []],
	0x36: ["f547d70", []],
	0x37: ["f547dd0", []],
	0x38: ["f547e50", []],
	0x39: ["f547ec0", []],
	0x3a: ["f547f30", []],
	0x3b: ["f547f50", []],
	0x40: ["f402f20", []],
	0x41: ["f4039b0", []],
	0x42: ["f404270", [1]],
	0x43: ["f404270", [0]],
	0x44: ["f54c2a0", []],
	0x45: ["f54c2d0", []],
	0x46: ["f54c300", []],
	0x47: ["f54c330", []],
	0x48: ["f54c370", []],
	0x49: ["f54c3b0", []],
	0x4a: ["f54c400", []],
	0x4b: ["f54c490", []],
	0x4c: ["f54c530", []],
	0x4d: ["f548bb0", []],
	0x50: ["f402840", [0]],
	0x51: ["f402840", [1]],
	0x52: ["f402840", [2]],
	0x53: ["f402840", [3]],
	0x54: ["f402840", [4]],
	0x55: ["f402840", [5]],
	0x56: ["f402ab0", []],
	0x57: ["f402c00", []],
	0x58: ["f402c30", []],
	0x59: ["f402c90", []],
	0x5a: ["f402cd0", []],
	0x60: ["f406710", []],
	0x61: ["f548e80", []],
	0x62: ["f548fd0", []],
	0x63: ["f5490e0", []],
	0x64: ["f549220", []],
	0x65: ["f549370", []],
	0x66: ["f5493e0", []],
	0x67: ["f549550", []],
	0x68: ["f549660", []],
	0x69: ["f549960", []],
	0x6a: ["f549890", []],
	0x6b: ["f549900", []],
	0x6e: ["f4029d0", []],
	0x6f: ["f405c10", []],
	0x71: ["f405d10", []],
	0x72: ["f405f90", []],
	0x73: ["f4061c0", []],
	0x74: ["f4039b0", []],
	0x75: ["f4029d0", []],
	0x76: ["f4029d0", []],
	0x77: ["f403cb0", []],
	0x78: ["f547fc0", []],
	0x79: ["f4052b0", []],
	0x7a: ["f4054b0", []],
	0x7b: ["f548060", []],
	0x7c: ["f548140", []],
	0x7d: ["f548000", []],
	0x7e: ["f4028d0", []],
	0x7f: ["f4062b0", []],
	0x80: ["f402d30", []],
	0x81: ["f548280", []],
	0x82: ["f5484b0", []],
	0x83: ["f548730", []],
	0x84: ["f406c40", []],
	0x85: ["f548910", []],
	0x86: ["f548b70", []],
	0x87: ["f548c00", []],
	0x88: ["f548c40", []],
	0x89: ["f548d40", []],
	0x8a: ["f548ce0", []],
	0x8b: ["f4034c0", []],
	0x8c: ["f548c90", []],
	0x8d: ["f548db0", []],
	0x8e: ["f548df0", []],
	0x8f: ["f4039b0", []],
	0x90: ["f4039b0", []],
	0x91: ["f4040f0", []],
	0x92: ["f54afa0", []],
	0x93: ["f54b050", []],
	0x94: ["f54b0f0", []],
	0x95: ["f403ea0", []],
	0x96: ["f54b140", []],
	0x97: ["f4035a0", []],
	0x98: ["f54b300", []],
	0x99: ["f54b2b0", []],
	0x9a: ["f54b270", []],
	0x9b: ["f4039b0", []],
	0x9c: ["f4039b0", []],
	0x9d: ["f4039b0", []],
	0x9e: ["f4039b0", []],
	0x9f: ["f4039b0", []],
	0xa0: ["f4039b0", []],
	0xa1: ["f4039b0", []],
	0xa2: ["f548db0", []],
	0xa3: ["f54b350", []],
	0xa4: ["f54b3a0", []],
	0xa5: ["f406d20", []],
	0xa6: ["f54b3e0", []],
	0xa7: ["f54b7c0", []],
	0xa8: ["f54b8c0", []],
	0xa9: ["f54b460", []],
	0xaa: ["f54b500", []],
	0xab: ["f54b610", []],
	0xac: ["f54b710", []],
	0xad: ["f403e00", []],
	0xb0: ["f54af40", []],
	0xb1: ["f406540", []],
	0xb2: ["f4039b0", []],
	0xb5: ["f403180", []],
	0xc0: ["f54a590", []],
	0xc1: ["f54a6c0", []],
	0xc2: ["f54a960", []],
	0xc3: ["f54a810", []],
	0xc4: ["f405750", []],
	0xc5: ["f405950", []],
	0xc7: ["f54ac50", []],
	0xca: ["f54a9c0", []],
	0xcb: ["f54a9f0", []],
	0xcc: ["f54af20", []],
	0xcd: ["f54af30", []],
	0xce: ["f54aa50", []],
	0xcf: ["f54ab60", []],
	0xd0: ["f549bc0", []],
	0xd1: ["f549ca0", []],
	0xd2: ["f549a00", []],
	0xd3: ["f549ea0", []],
	0xd4: ["f549d80", []],
	0xd5: ["f54a070", []],
	0xd6: ["f549f00", []],
	0xd7: ["f54a2c0", []],
	0xd8: ["f54a310", []],
	0xd9: ["f54a350", []],
	0xda: ["f54a4a0", []],
	0xdb: ["f54a4e0", []],
	0xdc: ["f5499a0", []],
	0xdd: ["f549780", []],
	0xde: ["f54a1c0", []],
	0xdf: ["f402a00", []],
	0xe0: ["f406ff0", []],
	0xe1: ["f4070c0", []],
	0xe2: ["f406f30", []],
	0xe3: ["f406f30", []],
	0xe4: ["f406f30", []],
	0xe5: ["f4067f0", []],
	0xe6: ["f404070", []],
	0xe8: ["f402ec0", []],
	0xe9: ["f406450", []],
	0xea: ["f402f70", []],
	0xeb: ["f404480", []],
	0xec: ["f4044e0", []],
	0xed: ["f404530", []],
	0xee: ["f404660", []],
	0xef: ["f4046b0", []],
	0xf0: ["f4047d0", []],
	0xf1: ["f403680", []],
	0xf2: ["f404820", []],
	0xf3: ["f4036c0", []],
	0xf4: ["f403760", []],
	0xf5: ["f404890", []],
	0xf6: ["f403940", []],
	0xf7: ["f4049b0", []],
	0xf8: ["f403a60", []],
	0xf9: ["f403960", []],
	0xfa: ["f4039b0", []],
	0xfb: ["f404a40", []],
	0xfc: ["f4039c0", []],
	0x100: ["f404a10", []],
}

## Manejadores que solo son presentacion (re/scripts/callgraph.py) y 0x404070 (reaccion: solo
## lee los LP para elegir la musica).
const PRESENTATION := [
	"f4027e0", "f4029d0", "f402ab0", "f402ad0", "f402ba0", "f402cd0", "f402f70",
	"f4030b0", "f4030f0", "f4032e0", "f403390", "f4039b0",
	"f405190", "f405230", "f405c10", "f4061c0", "f4067f0",
	"f406a30", "f406f30", "f406ff0", "f4070c0", "f404070",
]


## FUN_0053aca0
func dispatch() -> void:
	m.set_u8(0xa161a0, m.u8(0xa161a0) & 0xfe)
	var op := cmd_op() & 0xfff
	var entry: Array = DISPATCH.get(op, [])
	if entry.is_empty():
		finish()
		return
	var fn: String = entry[0]
	if fn in PRESENTATION:
		present("cmd", {"op": op, "p": cmd_player(), "args": [cmd_a(), cmd_b(), cmd_c()]})
		finish()
		return
	callv(fn, entry[1])


# --- Envoltorios de emision ---------------------------------------------------------------

## FUN_0053aa70
func f53aa70(op: int, a: int, b: int, c: int) -> int:
	issue(op, a, b, c)
	return 0


## FUN_0053ac40
func f53ac40(op: int, a: int, b: int, c: int) -> int:
	enqueue(op, a, b, c)
	return 0


## FUN_0054c880: emite 0x87 (el decompilado pierde los argumentos; ver el desensamblado).
func f54c880(p: int, a: int, b: int, c: int) -> int:
	issue((0x8000 if p != 0 else 0) | 0x87, a, b, c)
	return 0


## FUN_0054eed0: emite 0x72 con el id de la carta.
func f54eed0(p: int, index: int, b: int) -> int:
	issue((0x8000 if p != 0 else 0) | 0x72, f401a70(index), b, 0)
	return 0


# --- Manejadores --------------------------------------------------------------------------

## 0x07 FUN_00404430: 4026d0 crea la reaccion y vuelve; 403c70 se consulta a partir
## del siguiente paso. La escena consume el evento y detiene el motor mientras se reproduce.
func f404430() -> int:
	if step() == 0:
		present("cmd", {"op": 0x07, "p": cmd_player(), "args": [cmd_a(), cmd_b(), cmd_c()]})
		next_step()
		return 0
	if not anim_busy():
		finish()
	return 0


## 0xad FUN_00403e00: 402680 crea voz/retrato solo al entrar. El recorrido de objetos
## 1210..1214 equivale a 403c70; a diferencia de 0x07, consulta la espera en la misma llamada.
func f403e00() -> int:
	if step() == 0:
		present("cmd", {"op": 0xad, "p": cmd_player(), "args": [cmd_a(), cmd_b(), cmd_c()]})
		next_step()
	if not anim_busy():
		finish()
	return 0


## 0xe8 FUN_00402ec0: los tres materiales se guardan como indices para 43eb90.
## No son estado privado de la presentacion: otros comandos tambien usan estas globales.
func f402ec0() -> int:
	m.set_u32(0x5aed08, f401ad0(cmd_a()) & 0xffff)
	m.set_u32(0x5aed0c, f401ad0(cmd_b()) & 0xffff)
	m.set_u32(0x5aed10, f401ad0(cmd_c()) & 0xffff)
	present("cmd", {"op": 0xe8, "p": cmd_player(), "args": [cmd_a(), cmd_b(), cmd_c()]})
	finish()
	return 0


## 0xe9 FUN_00406450: reaccion 4026f0, espera 403c70, objeto 43eb90/405100,
## segunda espera. Los objetos nativos se representan como eventos para la cola visual.
func f406450() -> int:
	var index := f401ad0(cmd_a())
	match step():
		0:
			present("cmd", {"op": 0xe9, "p": cmd_player(), "args": [f401a70(index), cmd_b(), cmd_c()]})
			next_step()
		1:
			if not anim_busy():
				present("fusion", {"p": cmd_player(), "card": f401a70(index),
						"materials": [f401a70(m.u32(0x5aed08)), f401a70(m.u32(0x5aed0c)), f401a70(m.u32(0x5aed10))]})
				next_step()
		_:
			if not anim_busy():
				finish()
	return 0


## 0x01 FUN_0054bab0: inicio de turno.
func f54bab0() -> int:
	var p := cmd_player()
	var other := (-p - 1) & 1
	m.set_u8(0xa1194c + other * PS, m.u8(0xa1194c + other * PS) & 0xf7)
	m.set_u8(0xa1194c + p * PS, m.u8(0xa1194c + p * PS) & 0xf7)
	var u4 := m.u16(0xa1194a)
	if (u4 >> 14) != 0:
		u4 = (((u4 >> 14) - 1) * 0x4000) | (u4 & 0x3fff)
		m.set_u16(0xa1194a, u4)
	var u3 := m.u16(0xa1269e)
	if (u3 >> 14) != 0:
		u3 = (((u3 >> 14) - 1) * 0x4000) | (u3 & 0x3fff)
		m.set_u16(0xa1269e, u3)
	if (m.u32(0xa1194a) & 0xc000) == 0 or (m.u32(0xa1269e) & 0xc000) == 0:
		m.set_u16(0xa1194a, u4 & 0x3fff)
		m.set_u16(0xa1269e, u3 & 0x3fff)
	for pl in 2:
		for z in 5:
			var zone := DuelMem.zone(pl, z)
			if (m.u8(zone + 6) & 2) != 0:
				var cid := f401a70(m.u16(zone) & 0xfff)
				if cid in [0x2da, 0xf, 0x1ac, 0x243, 0x2e6, 0x458, 0x536]:
					m.set_u8(zone + 7, m.u8(zone + 7) | 0x10)
	for pl in 2:
		var c1 := f542f30(1, 0x49c)
		var c0 := f542f30(0, 0x49c)
		for z in range(5, 11):
			var zone := DuelMem.zone(pl, z)
			if (m.u16(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 2) == 0:
				var t := ctype(m.u16(zone) & 0xfff)
				if t == 0x15 or (t == 0x16 and (pl == p or c1 + c0 == 0)):
					m.set_u8(zone + 0x8f, m.u8(zone + 0x8f) | 2)
	for z in 5:
		var zone := DuelMem.zone(p, z)
		var ix := m.u16(zone) & 0xfff
		if ix == 0:
			continue
		m.set_u8(zone + 7, m.u8(zone + 7) & 0xfd)
		if (m.u16(zone + 6) & 2) == 0:
			continue
		var cid := s16(f401a70(ix))
		if cid == 0x267:
			issue((0x8000 if p != 0 else 0) | 0x8b, z, 1, 0)
		elif cid == 0x540:
			if (m.u16(zone + 6) & 0x1000) == 0:
				m.set_u16(zone + 6, m.u16(zone + 6) | 0x1200)
		elif cid == 0x5e9:
			m.set_u8(zone + 7, m.u8(zone + 7) | 0x10)
			f54c880(p, ix, (z << 8) | p, 0xb)
	var q := p * PS
	for i in m.u8(0xa1194a + q):
		var at := 0xa125f8 + q + i * 2
		var v := m.u16(at)
		if (v & 0xff) == 2 and (v >> 8) < 5:
			m.set_u16(at, (((v >> 8) + 1) << 8) | 2)
	finish()
	return 0


## 0x02 FUN_0054bdb0: fin de turno.
func f54bdb0() -> int:
	var p := cmd_player()
	var q := p * PS
	# FUN_00402710: si termina la CPU suena su voz 0x1000003b (Yugi_30), sin mirar el modo.
	if p != 0:
		present("sound", {"id": 0x1000003b})
	var pbit := 0x8000 if p != 0 else 0
	var v := m.u16(0xa11954 + q)
	if ((v >> 12) & 7) != 0:
		m.set_u16(0xa11954 + q, ((((v >> 12) - 1) * 0x1000 ^ v) & 0x7000) ^ v)
	for z in 5:
		var flags := m.u16(DuelMem.zone(p, z) + 6)
		var turns := (flags & 0x1c0) >> 6
		if turns != 0:
			issue(pbit | 0x97, z, turns - 1, 0)
			if ((m.u8(0xa16181) & 1) == 0 or (m.u16(0xa133f2) & 1) == 0) and turns - 1 == 0:
				f54e250(p, z, 1)
	for pl in 2:
		var at := 0xa1194a + pl * PS
		m.set_u16(at, m.u16(at) & 0xe7ff)
		m.set_u16(at + 2, m.u16(at + 2) & 0xfff8)
	m.set_u8(0xa1194b + q, m.u8(0xa1194b + q) & 0xdf)
	m.set_u8(0xa133ed, m.u8(0xa133ed) & 0xc0)
	for pl in 2:
		var pq := pl * PS
		for list in [[0xa11946, 0xa11fb8], [0xa11947, 0xa120f8], [0xa11949, 0xa12378],
				[0xa11948, 0xa12238], [0xa1194a, 0xa124b8]]:
			for i in m.u8(list[0] + pq):
				var at: int = list[1] + pq + i * 4
				m.set_u32(at, m.u32(at) & 0xff9fffff)
	for pl in 2:
		for z in 5:
			var at := DuelMem.zone(pl, z) + 0x8e
			m.set_u16(at, m.u16(at) & 0xffef)
	if (m.u8(0xa16181) & 1) == 0 or (m.u16(0xa133f2) & 1) == 0:
		for pl in 2:
			var pq := pl * PS
			for z in 5:
				var zone := DuelMem.zone(pl, z)
				var ix := m.u16(zone) & 0xfff
				if ix == 0:
					continue
				var destroy := s16(f401a70(ix)) == 0x458 and (m.u16(zone + 6) & 2) != 0 \
						and (m.u16(zone + 6) & 0x1000) == 0
				if f545620(pl, z, 0x522) != 0:
					destroy = true
				if f545620(pl, z, 0x5e8) != 0 or destroy:
					f54e250(pl, z, 1)
					continue
				var where := (z << 8) | pl
				var any4 := false
				for i in m.u16(zone + 0x88):
					if m.u8(zone + 0x48 + i * 2) == 4:
						any4 = true
				if any4:
					f54c880(pl, 0, where, 4)
				for i in 12:
					var cid := m.u16(0x5aa874 + i * 2)
					if f545620(pl, z, cid) != 0:
						f54c880(pl, f401ad0(cid), where, 3)
				if f545620(pl, z, 0x403) != 0:
					f54c880(pl, f401ad0(0x403), where, 3)
				if pl == cmd_player() and f545620(pl, z, 0x4e7) != 0:
					f54c880(pl, f401ad0(0x4e7), where, (0xb if pl != 0 else 0) + 3)
				if s16(f401a70(ix)) == 0x2f9 and (m.u8(0xa1194c + pq) & 8) != 0:
					if f543330(pl) > 0:
						var free := f543360(pl)
						f54eed0(pl, ix, z)
						issue((0x8000 if pl != 0 else 0) | 0xa5, (z << 8) | (free & 0xff), 0, 0)
	finish()
	return 0


## 0x10 FUN_0054c570: reinicia el duelo conservando mazo y mazo de fusion; LP 8000.
func f54c570() -> int:
	var save := m.local(0x500)
	var counts: Array[int] = [0, 0, 0, 0]
	for pl in 2:
		counts[pl + 2] = m.u8(0xa11947 + pl * PS)
		m.copy(save + pl * 0x140, 0xa120f8 + pl * PS, 0x140)
		counts[pl] = m.u8(0xa11949 + pl * PS)
		m.copy(save + 0x280 + pl * 0x140, 0xa12378 + pl * PS, 0x140)
	m.clear(0xa15c00, 0x574)
	m.clear(0xa11944, 0x1aac)
	for pl in 2:
		m.set_u8(0xa11947 + pl * PS, counts[pl + 2])
		m.copy(0xa120f8 + pl * PS, save + pl * 0x140, 0x140)
		m.set_u8(0xa11949 + pl * PS, counts[pl])
		m.copy(0xa12378 + pl * PS, save + 0x280 + pl * 0x140, 0x140)
	m.set_u8(0xa133f2, m.u8(0xa133f2) | 0xe)
	m.set_u16(0xa11944, 8000)
	m.set_u16(0xa12698, 8000)
	finish()
	return 0


## 0x50-0x55 FUN_00402840: cambio de fase (bits 1-3 de 0xa133f2).
func f402840(phase: int) -> int:
	if step() == 0:
		next_step()
		m.set_u32(0xa133f2, m.u32(0xa133f2) ^ (((phase * 2) ^ m.u32(0xa133f2)) & 0xe))
		present("phase", {"p": cmd_player(), "phase": phase})
		return 0
	if not anim_busy():
		finish()
	return 0


## 0x60 FUN_00406710: barajar con la semilla del comando.
func f406710() -> int:
	var p := cmd_player()
	var seed := m.u32(0xa14f22)
	if step() == 0:
		if m.u8(0xa11947 + p * PS) == 0:
			finish()
			return 0
		present("shuffle", {"p": p})
		next_step()
	elif step() == 1:
		if not anim_busy():
			rng.srand(seed)
			f5426d0(p, 3)
			finish()
	return 0


## 0x61 FUN_00548e80: robar b cartas (si el mazo esta vacio marca la derrota).
func f548e80() -> int:
	var p := cmd_player()
	var q := p * PS
	var s := step()
	if s == 0:
		next_step()
		if m.u8(0xa11947 + q) != 0:
			return 0
		m.set_u8(0xa1194b + q, m.u8(0xa1194b + q) | 1)
	elif s == 1:
		f541cb0(DuelMem.MOVING_CARD, 0xa120f8 + q)
		f542960(p)
		present("draw", {"p": p, "card": f401a70(m.u32(DuelMem.MOVING_CARD) & 0xfff)})
		next_step()
		return 0
	elif s == 2:
		m.set_u16(0xa14f24, m.u16(0xa14f24) - 1)
		if m.u16(0xa14f24) != 0:
			var st := m.u32(DuelMem.CMD_STATE) & 0xf01fffff
			m.set_u32(DuelMem.CMD_STATE, st ^ (((st - 1) ^ st) & 0x7f))
			return 0
	finish()
	return 0


## 0xc4 FUN_00405750: colocar o invocar un monstruo desde la mano.
func f405750() -> int:
	var p := cmd_player()
	var b := cmd_b()
	var bit8 := (b >> 8) & 1
	var z := b & 0xf
	var hand_i := (b & 0xff) >> 4
	var bit9 := (b >> 9) & 1
	match step():
		0:
			next_step()
		1:
			var slot := 0xa11fb8 + p * PS + hand_i * 4
			expect_card(cmd_a(), m.u32(slot), "mano[%d]" % hand_i)
			f541cb0(DuelMem.MOVING_CARD, slot)
			m.set_u32(slot, m.u32(slot) & 0xfffff000)
			present("hand_to_monster", {"p": p, "card": cmd_a(), "zone": z, "b": b})
			next_step()
		2:
			next_step()
		3:
			if not anim_busy():
				next_step()
		4:
			f544e00(p)
			f5422b0(p, z, DuelMem.MOVING_CARD, bit9, bit8)
			finish()
		_:
			finish()
	return 0


## 0xc5 FUN_00405950: activar o colocar una magia/trampa desde la mano.
func f405950() -> int:
	var p := cmd_player()
	var b := cmd_b()
	var index := f401ad0(cmd_a())
	var z := b & 0xf
	var bit8 := (b >> 8) & 1
	var hand_i := (b & 0xff) >> 4
	if z > 4:
		z -= 5
	if ctype(index) == 0x16:
		var t := ctype(index)
		if t > 0x14 and t < 0x17 and csub(index) == 2:
			z = 0
	match step():
		0:
			# Con c == 0: colocarla (bit 8 a 0) -> FUN_00402660 -> FUN_004022f0, voz 0x1000003a
			# (Yugi_29) si es la CPU; activarla -> FUN_00402610, reaccion a la carta. Ninguna en
			# el modo 6 (FUN_004373e0).
			if cmd_c() == 0:
				if bit8 == 0:
					if game_mode != 6 and p != 0:
						present("voice", {"id": 0x1000003a})
				else:
					f402610(p, f401a70(index), {"cmd_c5": true})
			next_step()
		1:
			if not anim_busy():
				var slot := 0xa11fb8 + p * PS + hand_i * 4
				expect_card(cmd_a(), m.u32(slot), "mano[%d]" % hand_i)
				f541cb0(DuelMem.MOVING_CARD, slot)
				m.set_u32(slot, m.u32(slot) & 0xfffff000)
				# zona del campo (0-10): magia/trampa = 5 + z, magia de campo = 10
				var field_zone := 10 if ctype(index) == 0x16 and csub(index) == 2 else z + 5
				present("hand_to_spell", {"p": p, "card": cmd_a(), "zone": field_zone, "b": b})
				next_step()
		2:
			# Al activarla (bit 8) con c == 0: FUN_00402630, bust-up de reaccion (no en modo 6).
			if bit8 != 0 and cmd_c() == 0 and game_mode != 6:
				present("reaction_flip", {"p": p, "card": f401a70(index)})
			next_step()
		3:
			if not anim_busy():
				next_step()
		4:
			f544e00(p)
			f5423a0(p, z, DuelMem.MOVING_CARD, bit8)
			finish()
		_:
			finish()
	return 0


## 0xf9 FUN_00403960: salto del guion de los tutoriales. Rebobina la repeticion y avanza
## hasta el comando 0xfa con el mismo argumento (FUN_004360e0/f0/d0, FUN_00435ff0 son el
## iterador de la repeticion).
func f403960() -> int:
	var target := cmd_a()
	_incoming_pos = 0
	while _incoming_pos < _incoming.size():
		_incoming_pos += 1
		if _incoming_pos >= _incoming.size():
			break
		var c := _incoming[_incoming_pos]
		if c[0] == 0xfa and c[1] == target:
			finish()
			return 0
	_incoming_pos = 0
	finish()
	return 0


## 0xf7 FUN_004049b0: guion de tutorial; pide elegir con el cursor (mascara b << 16 | a en el
## objeto de seleccion de la interfaz) y espera a que la interfaz responda, que deja la
## eleccion en 0xa16178 (FUN_00540d80). Sin interfaz se responde con auto_answer.
func f4049b0() -> int:
	if step() == 0:
		next_step()
		tutorial_pick_mask = (cmd_b() << 16) + cmd_a()
		present("pick_zone", {"mask": tutorial_pick_mask})
		return 0
	if auto_answer != -1:
		f540d80(scripted_answer())
		tutorial_pick_mask = 0
		finish()
	elif tutorial_pick_mask == 0:
		finish()
	return 0


# --- Entrada de interfaz del original ---------------------------------------------------------
# Estas funciones leen objetos de la interfaz (carta visual bajo el cursor, raton, panel de
# fases). La escena los describe con set_frame_input() antes de cada fotograma.

## FUN_005407b0: campo +0x10 de la carta visual bajo el cursor (0 si no hay).
func f5407b0() -> int:
	return ui_hover_card


## FUN_005407e0: byte +5 del estado de entrada: hay un objeto bajo el cursor.
func f5407e0() -> int:
	return 1 if ui_hover_object else 0


## FUN_00540b90: el cursor muestra la accion `action` (guarda accion + 1).
func f540b90(action: int) -> int:
	cursor_action = action + 1
	return 0


## FUN_00540bb0: cursor normal, sin accion.
func f540bb0() -> int:
	cursor_action = 0
	return 0


## FUN_0040fe20: marca DAT_005af70c (onda de clic del cursor); solo presentacion.
func f40fe20() -> int:
	return 0


## FUN_00460f80: ficha del panel de fases bajo el cursor (0-5) o -1.
func f460f80() -> int:
	return ui_phase_hover
