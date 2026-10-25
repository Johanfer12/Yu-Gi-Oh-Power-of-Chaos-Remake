class_name JoeyPortH
extends JoeyPortG
## Motor nativo de Joey, lote H de la etapa 2: manejadores de comandos 4067d0-4086c0.
## Cada funcion se llama f<direccion de Joey_Pc.exe> (o _c5b9470_XX para los casos del despacho)
## y sobrescribe su declaracion con la misma aridad. Cotejo: re/scripts/joey_specs/port_h.py.
##
## Omisiones de presentacion (FRONTERA_JOEY.md 2.5 y 3): las esperas sobre la lista de efectos
## 5f3280+0x132c..0x1330, la lista de marcadores de 5f3404, los objetos de LP 5f3280+0xe68/0xea8
## y el objeto +0x310 cuentan como "nada ocupado"; desaparecen la infraestructura C++ (new,
## shared_ptr, insercion en la lista) y el metodo +0x24 del objeto 5f3280+0x3c.

## Objeto grafico global, lista de la mano visual (this de 41d050) y retenidos de la explosion 7a.
const _JH_GRAPHICS := 0x5f3280
const _JH_HAND_OBJ := 0x5f300c
const _JH_HELD := 0x5f25d8
## Cementerio del jugador 0 (u8 contador y lista u32; el 1 suma 0xd44) y carta en transito.
const _JH_GRAVE_N := 0xa55d6a
const _JH_GRAVE_LAST := 0xa566ec
const _JH_MOVED := 0xa558b0


## Joey FUN_004067d0: comando 71, invocacion de una carta a la zona con su efecto (cinco pasos:
## efecto de invocacion, pausa de 8 ticks, buzon tipo 4 y colocacion con 568610).
func f4067d0() -> int:
	var op := m.u16(JoeyMem.CMD)
	var a := cmd_a()
	var bc := (cmd_c() << 16) | cmd_b()
	var lo := a & 0xff
	var hi := a >> 8
	var loc := lo & 0xf
	var o4 := lo >> 4
	var p := op >> 15
	var o8 := p
	var oc := hi & 1
	var o10 := (hi >> 1) & 1
	var o18 := hi >> 4
	var card := f402460(bc & 0xfff) & 0xfff
	var entry := card | (bc & 0xfffff000)
	var sel: int
	var low: int
	if _s32(f44baa0()) < 1000:
		if loc == 0xe:
			sel = 1
			low = o4
		else:
			sel = o4
			low = o8
	else:
		if loc == 0xd or loc == 0xc or loc == 0xe:
			o8 = o4
			o4 = 1
		sel = o4
		low = o8
	var step := cmd_step()
	if step > 4:
		return 0
	if step == 0:
		cmd_advance()
		step = 1
	match step:
		1:
			if visual_busy("effects", 0, 0, 0x406913):
				return 0
			var info := m.local(4)
			m.set_u32(info, o18)
			m.set_u16(info, (((((o10 & 1) | (oc << 1)) & 0xff) << 8) | (o18 & 0xff)) << 6 | (p & 1))
			f44fcc0(0, card, info)
			# Insercion en la lista de efectos y metodo +0x24 de 5f3280+0x3c omitidos.
			cmd_advance(0xffffc07f)
		2:
			if (cmd_tick() & 0x3f80) >= 0x400:
				cmd_advance(0xffffc07f)
		3:
			var where := m.local(4)
			m.set_u32(where, (((((sel & 0xff) | (oc << 9)) << 5) | (loc & 0x1f)) << 1 | (low & 1)) & 0xffff)
			var info := m.local(4)
			m.set_u32(info, ((((((o10 & 1) | (oc << 1)) & 0xff) << 8) | (o18 & 0xff)) << 6 | (p & 1)) & 0xffff)
			f40ce10(card, where, info)
			cmd_advance()
		4:
			if visual_busy("effects", 0, 0, 0x406abf):
				return 0
			f56d190(p)
			var at := m.local(4)
			m.set_u32(at, entry)
			f568610(p, o18, at, o10, oc)
			cmd_finish()
	return 0


## Joey FUN_00406b20: comando 72, una carta del cementerio (o por identidad) vuelve a la cima:
## la reordena, crea el efecto de activacion y espera.
func f406b20() -> int:
	var p := cmd_p()
	var card := f402460(cmd_a()) & 0xffff
	var b := cmd_b()
	var key := (b >> 8) & 0xff
	var loc := b & 0xff
	var idx := cmd_c()
	if key != 0:
		var v := f5687d0(key) & 0xffffffff
		idx = -1
		if (v & 0xff) == p and ((v >> 8) & 0xff) == loc:
			idx = v >> 16
	elif loc == 0xe:
		if f56cbd0(p, f4022e0(card)) == 0:
			idx = -1
	match cmd_step():
		0:
			if loc == 0xe:
				var moved := false
				if key != 0:
					if idx >= 0 and idx != m.u8(_JH_GRAVE_N + (p & 1) * JoeyMem.PLAYER_SIZE) - 1:
						f56c9e0(p, key)
						moved = true
				elif f56cbd0(p, f4022e0(card)) != 0:
					if obj_u32(f41cf60(p, 0xe), 0x10) != card:
						f56c910(p, card)
						moved = true
				if moved:
					f44ef40(7)
					f43c730(f41cf60(p, 0xe), card)
			cmd_advance()
		1:
			if not visual_busy("effects") and f41d050(m.u32(_JH_HAND_OBJ)) & 0xff == 0:
				if f402690(card) != 0:
					f403bf0(p, f4022e0(card) & 0xffff)
				cmd_advance()
		2:
			if visual_busy("effects", 0, 0, 0x406d03):
				return 0
			var obj := f41cf60(p, loc)
			if obj == 0:
				obj = f41cee0(p, loc, idx & 0xffffffff)
				if obj == 0 and loc + idx <= 4:
					obj = f41cee0(p, (loc + idx) & 0xffffffff, 0xff)
			if idx == -1 or obj == 0 or obj_u32(obj, 0x10) != card:
				f450730(0, card)
			else:
				var place := m.local(4)
				m.set_u32(place, key)
				f450260(0, card, f418b50(obj, place))
			# Insercion en la lista de efectos, metodo +0x24 de 5f3280+0x3c y el functor
			# temporal (vtable 5da440) omitidos.
			cmd_advance()
		3:
			if visual_busy("effects", 0, 0, 0x406f34):
				return 0
			cmd_finish()
	return 0


## Joey FUN_00406f70: comando 73, busto de reaccion y efecto de activacion de la carta.
func f406f70() -> int:
	var p := cmd_p()
	var card := f402460(cmd_a()) & 0xffff
	match cmd_step():
		0:
			if f402690(card) != 0:
				f403bf0(p, f4022e0(card) & 0xffff)
			cmd_advance()
		1:
			if visual_busy("effects", 0, 0, 0x406fdb):
				return 0
			f450730(0, card)
			cmd_advance()
		2:
			if visual_busy("effects", 0, 0, 0x407023):
				return 0
			cmd_finish()
	return 0


## Joey FUN_00407120: comandos 6e, 75 y 76; solo llaman al metodo +0x24 de 5f3280+0x3c con el
## indice de la carta (omitido) y terminan.
func f407120() -> int:
	f402460(cmd_a())
	cmd_finish()
	return 0


## Joey FUN_00407160: comando df, pone en la cima del cementerio la carta (por indice o, con b,
## por identidad) si no lo esta ya y espera a la mesa.
func f407160() -> int:
	var p := cmd_p()
	var card := f402460(cmd_a()) & 0xffff
	var b := cmd_b()
	var step := cmd_step()
	if step == 0:
		if b == 0:
			if obj_u32(f41cf60(p, 0xe), 0x10) != card:
				f56c910(p, card)
				f44ef40(7)
				f43c730(f41cf60(p, 0xe), card)
				# Metodo +0x24 de 5f3280+0x3c omitido.
		else:
			var pl := (p & 1) * JoeyMem.PLAYER_SIZE
			var last := m.u32(_JH_GRAVE_LAST + m.u8(_JH_GRAVE_N + pl) * 4 + pl)
			if ((last >> 12) & 1) + ((last >> 24) & 0x7f) * 2 != b:
				f56c9e0(p, b)
				f44ef40(7)
				f43c730(f41cf60(p, 0xe), card)
				# Metodo +0x24 de 5f3280+0x3c omitido.
		cmd_advance()
	elif step != 1:
		return 0
	if f41d050(m.u32(_JH_HAND_OBJ)) & 0xff == 0:
		cmd_finish()
	return 0


## Joey FUN_004072b0: comando d8, saca del cementerio la ultima carta y la coloca en la zona
## (cima, buzon tipo 3 desde el cementerio y 5686e0).
func f4072b0() -> int:
	var p := cmd_p()
	var card := f402460(cmd_a()) & 0xffff
	var b := cmd_b()
	var z := (b >> 8) & 0xff
	var owner := b & 0xff
	match cmd_step():
		0:
			if obj_u32(f41cf60(p, 0xe), 0x10) != card:
				f56c910(p, card)
				f44ef40(7)
				f43c730(f41cf60(p, 0xe), card)
			cmd_advance()
		1:
			if f41d050(m.u32(_JH_HAND_OBJ)) & 0xff == 0:
				f56c7c0(p, (m.u8(_JH_GRAVE_N + (p & 1) * JoeyMem.PLAYER_SIZE) - 1) & 0xffffffff, _JH_MOVED)
				# local_8 en +0 y local_6 en +2, contiguas como en la pila del original.
				var both := m.local(4)
				m.set_u16(both + 2, (p & 1) | 0x805c)
				m.set_u16(both, (((z % 5) & 0xff) << 6) | (owner & 1) | 0x800a)
				f40cdb0(m.u32(_JH_MOVED) & 0xfff, both + 2, both)
				cmd_advance()
		2:
			f5686e0(owner, z, _JH_MOVED, 1)
			cmd_finish()
	return 0


## Joey FUN_00407440: comando ad, busto de reaccion (403c80) y espera de los efectos.
func f407440() -> int:
	var p := cmd_p()
	var card := f402460(cmd_a()) & 0xffff
	var b := cmd_b()
	if cmd_step() == 0:
		f403c80(p, f4022e0(card) & 0xffff, b)
		cmd_advance()
	if visual_busy("effects", 0, 0, 0x4074cc):
		return 0
	cmd_finish()
	return 0


## Joey FUN_004074f0: comando 95, sacrificio: suelta el marcador y manda la carta de la zona al
## cementerio (o a excluidas con b) con buzon tipo 4.
func f4074f0() -> int:
	var p := cmd_p()
	var a := cmd_a()
	var b := cmd_b()
	match cmd_step():
		0:
			if visual_busy("markers", 0, 0, 0x40754f):
				return 0
			cmd_advance()
		1:
			# local_4 (sin uso posterior en este tick): ((banderas << 8 | a) << 6 | p).
			f486cc0(p, a)
			cmd_advance(0xffffc07f)
		2:
			if visual_busy("markers", 0, 0, 0x4075f6):
				return 0
			cmd_advance()
		3:
			var ptr := f5700f0(p, a, 0)
			var e := m.u32(ptr) & 0xff1fffff
			m.set_u32(ptr, e)
			if p == ((e >> 12) & 1) and a < 5 and b == 0:
				if (f4022e0(e & 0xfff) & 0xffff) < 0x780 or (f4022e0(m.u16(ptr) & 0xfff) & 0xffff) > 0x783:
					var at := 0xa56430 + (p & 1) * JoeyMem.PLAYER_SIZE
					m.set_u32(at, m.u32(at) | 0x1000000)
			f5675c0(_JH_MOVED, ptr)
			var flags := m.u16(JoeyMem.zone(p, a) + JoeyMem.Z_FLAGS)
			var from := (((((flags << 13) & 0xffff) | (a & 0x1f)) << 1) | (p & 1)) & 0xffff
			# local_c no se inicializa: sus bits 6-13 y 14-15 que se usan quedan fijados abajo
			# (bit 6 siempre 1, 14 y 15 los reescriben 5703a0 y 570420); se modela a 0.
			var to := (((m.u32(_JH_MOVED) >> 12) & 1) & 0xc041) | ((((int(b != 0) + 0xe) & 0x1f) | 0x20) << 1)
			f570790(p & 1, a & 0x1f, 0)
			var index := 0 if b != 0 else (to >> 6) & 0xff
			f5708d0(to & 1, (to >> 1) & 0x1f, index, _JH_MOVED)
			var r := f5703a0(to & 1, (to >> 1) & 0x1f, (to >> 6) & 0xff)
			to = ((r & 1) << 14) | (to & 0xbfff)
			var r2 := f570420(to & 1, (to >> 1) & 0x1f, (to >> 6) & 0xff)
			to = ((r2 << 15) & 0xffff) | (to & 0x7fff)
			var from_at := m.local(4)
			m.set_u32(from_at, from)
			var to_at := m.local(4)
			m.set_u32(to_at, to)
			f40ce10(m.u32(_JH_MOVED) & 0xfff, from_at, to_at)
			cmd_advance()
		_:
			cmd_finish()
	return 0


## Joey FUN_00407860: comando 56, apaga el objeto de batalla (413ad0).
func f407860() -> int:
	f413ad0()
	cmd_finish()
	return 0


## Joey FUN_00407880: comando 33, ataque: fija atacante (a), objetivo (b) y bando en a57840 y
## lanza el objeto de batalla.
func f407880() -> int:
	var p := cmd_p()
	var a := cmd_a()
	var b := cmd_b()
	var c := cmd_c()
	if cmd_step() == 0:
		var w := m.u16(JoeyMem.BATTLE) & 0xfffb
		w ^= ((w & 0xff) ^ p) & 1
		m.set_u16(JoeyMem.BATTLE, w)
		var side := c - 1 if c != 0 else 1 - p
		var bits := ((((((b & 7) << 3) | (a & 7)) << 7) | (side & 1)) << 1) | (m.u32(JoeyMem.BATTLE) & 0xc0fd)
		m.set_u16(JoeyMem.BATTLE, bits)
		f413af0(a)
		f413b30((c - 1) & 0xffffffff, b)
		cmd_advance()
	if f413b80() == 0:
		cmd_finish()
	return 0


## Joey FUN_00407960: comando 34, ataque directo: a57840 con el bit 2, atacante a y bando.
func f407960() -> int:
	var p := cmd_p()
	var a := cmd_a()
	if cmd_step() == 0:
		m.set_u8(JoeyMem.BATTLE, m.u8(JoeyMem.BATTLE) | 4)
		var w := m.u16(JoeyMem.BATTLE)
		w ^= ((w & 0xff) ^ p) & 1
		m.set_u16(JoeyMem.BATTLE, w)
		# imul de 8 bits: (p + 1) * -2, del que solo queda el bit 1.
		var side := (((p + 1) & 0xff) * 0xfe) & 2
		m.set_u16(JoeyMem.BATTLE, (side ^ (m.u32(JoeyMem.BATTLE) & 0xe8fd)) | ((((a & 7) | 0x28) & 0xff) << 8))
		f413af0(a)
		f413b30(1 - p, 0xffffffff)
		cmd_advance()
	if f413b80() == 0:
		cmd_finish()
	return 0


## Joey FUN_00407a20: comando 31, dano de batalla: 5b8210(0) y el objeto de batalla con los
## valores de a57850/a57860 leidos antes de la llamada.
func f407a20() -> int:
	var c := cmd_c()
	var v60 := m.u32(0xa57860)
	var v50 := m.u32(0xa57850)
	if cmd_step() == 0:
		f5b8210(0)
		f413ba0(v50, v60, c & 0xff, c >> 8)
		cmd_advance()
	if f413b80() == 0:
		cmd_finish()
	return 0


## Joey FUN_00407a90: comando 57, crea el marcador de sacrificio en la zona a.
func f407a90() -> int:
	f486ca0(cmd_p(), cmd_a())
	cmd_finish()
	return 0


## Joey FUN_00407ac0: comando 58, suelta el marcador de la zona a + b y espera a los marcadores.
func f407ac0() -> int:
	if cmd_step() == 0:
		f486cc0(cmd_p(), cmd_b() + cmd_a())
		cmd_advance()
	if f486d30() == 0:
		cmd_finish()
	return 0


## Joey FUN_00407b30: comando 59, marcador de material en (a, b).
func f407b30() -> int:
	f486ce0(cmd_p(), cmd_a(), cmd_b())
	cmd_finish()
	return 0


## Joey FUN_00407b70: comando 5a, otro marcador en (a, b) y espera a los marcadores.
func f407b70() -> int:
	if cmd_step() == 0:
		f486d00(cmd_p(), cmd_a(), cmd_b())
		cmd_advance()
	if f486d30() == 0:
		cmd_finish()
	return 0


## Joey FUN_00407be0: comando e6, busto de reaccion (403c20), espera y musica segun LP.
func f407be0() -> int:
	if cmd_step() == 0:
		f403c20(cmd_p(), cmd_a(), cmd_c())
		cmd_advance()
	if visual_busy("effects", 0, 0, 0x407c4d):
		return 0
	f44ba00()
	cmd_finish()
	return 0


## Joey FUN_00407c70: comando 7f, voltea la carta de la zona a (buzon tipo 1) y cambia su
## posicion segun b.
func f407c70() -> int:
	var p := cmd_p()
	var a := cmd_a()
	var b := cmd_b()
	var c := cmd_c()
	var z := JoeyMem.zone(p, a)
	if (m.u16(z) & 0xfff) == 0:
		cmd_finish()
		return 0
	match cmd_step():
		0:
			if c != 0 and b == 0:
				f403e10(p, 1 - (m.u8(z + 6) & 1))
			cmd_advance()
		1:
			if visual_busy("effects", 0, 0, 0x407d86):
				return 0
			var f := m.u8(z + 6)
			var hi := ((((f >> 1) & 1) ^ b) & 0xff) << 8 | ((1 - (f & 1)) & 0xff)
			f40cd70(1, (hi << 16) | ((a & 0xff) << 8) | (p & 0xff))
			if c != 0 and b != 0:
				f570710(p, a, 1, 1)
			cmd_advance()
		2:
			var flags := m.u16(z + 6)
			var w := ((((b & 1) << 1) ^ (flags & 2)) | ((flags ^ 1) & 0xfffd)) & 0xffff
			m.set_u16(z + 6, w)
			if (w & 2) == 0 and b != 0:
				f56af90(p, a)
			cmd_finish()
	return 0


## Joey FUN_00407e60: comando 80, voltea boca arriba o abajo la carta de la zona a (buzon tipo
## 2); sin c >> 8 alterna el bit 1 y renumera la colocacion.
func f407e60() -> int:
	var p := cmd_p()
	var a := cmd_a()
	var b := cmd_b()
	var c := cmd_c()
	var z := JoeyMem.zone(p, a)
	if (m.u32(z) & 0xfff) == 0:
		cmd_finish()
		return 0
	match cmd_step():
		0:
			if c & 1:
				f403dd0(p)
			cmd_advance()
		1:
			var f := m.u8(z + 6)
			var hi: int
			if (c >> 8) != 0:
				hi = ((b & 0xff) << 8) | (f & 1)
			else:
				hi = (((1 - ((f >> 1) & 1)) & 0xff) << 8) | (f & 1)
			f40cd70(2, (hi << 16) | ((a & 0xff) << 8) | (p & 0xff))
			if c & 2:
				f570710(p, a, 1, 1)
			cmd_advance()
		2:
			if (c >> 8) == 0:
				var w := m.u16(z + 6) ^ 2
				m.set_u16(z + 6, w)
				if w & 2:
					m.set_u16(z + 4, m.u16(JoeyMem.PLAYER))
					m.set_u16(JoeyMem.PLAYER, m.u16(JoeyMem.PLAYER) + 1)
					cmd_finish()
					return 0
				f56af90(p, a)
			cmd_finish()
	return 0


## Joey FUN_00408030: comando 91, pone boca arriba la carta de la zona a (buzon tipo 2 si
## estaba boca abajo), renumera la colocacion y muestra el busto.
func f408030() -> int:
	var p := cmd_p()
	var a := cmd_a()
	var z := JoeyMem.zone(p, a)
	var card := m.u32(z) & 0xfff
	if card == 0:
		cmd_finish()
		return 0
	match cmd_step():
		0:
			f403bc0(p, f4022e0(card) & 0xffff)
			cmd_advance()
		1:
			if visual_busy("effects", 0, 0, 0x4080ee):
				return 0
			var w := m.u16(z + 6)
			if (w & 2) == 0:
				var hi := (((1 - ((w >> 1) & 1)) & 0xff) << 8) | (m.u8(z + 6) & 1)
				f40cd70(2, (hi << 16) | ((a & 0xff) << 8) | (p & 0xff))
			cmd_advance()
		2:
			m.set_u8(z + 6, m.u8(z + 6) | 2)
			m.set_u16(z + 4, m.u16(JoeyMem.PLAYER))
			m.set_u16(JoeyMem.PLAYER, m.u16(JoeyMem.PLAYER) + 1)
			f570710(p, a, 1, 1)
			f403bf0(p, f4022e0(card) & 0xffff)
			cmd_advance()
		3:
			if visual_busy("effects", 0, 0, 0x4081d1):
				return 0
			cmd_finish()
	return 0


## Joey FUN_00408210: comando e8, guarda en 5f25d8/dc/e0 los indices de los ids a, b y c (los
## lee la explosion de 408270).
func f408210() -> int:
	m.set_u32(_JH_HELD, f402460(cmd_a()) & 0xffff)
	m.set_u32(_JH_HELD + 4, f402460(cmd_b()) & 0xffff)
	m.set_u32(_JH_HELD + 8, f402460(cmd_c()) & 0xffff)
	cmd_finish()
	return 0


## Joey FUN_00408270: comando e9, busto (403d40) y efecto con las tres cartas retenidas en
## 5f25d8 (4520e0).
func f408270() -> int:
	var p := cmd_p()
	var card := f402460(cmd_a()) & 0xffff
	var step := cmd_step()
	if step == 0:
		f403d40(p, f4022e0(card) & 0xffff)
		cmd_advance()
		return 0
	if step != 1:
		if visual_busy("effects", 0, 0, 0x4082d5):
			return 0
		cmd_finish()
		return 0
	if visual_busy("effects", 0, 0, 0x408319):
		return 0
	# Efecto con p, la carta y los tres indices retenidos; la insercion en la lista se omite.
	f4520e0(0, p, card, m.u32(_JH_HELD), m.u32(_JH_HELD + 4), m.u32(_JH_HELD + 8))
	cmd_advance()
	return 0


## Joey FUN_00408410: comando 40, LP del jugador a 0, contador de LP y fin del duelo (0x240).
func f408410() -> int:
	var p := cmd_p()
	m.set_u16(0xa55d64 + (p & 1) * JoeyMem.PLAYER_SIZE, 0)
	f47c4d0(m.u32(_JH_GRAPHICS) + 0xe68 + (p << 6), 0)
	m.set_u16(JoeyMem.MODE, m.u16(JoeyMem.MODE) | 0x240)
	cmd_finish()
	return 0


## Joey FUN_00408470: cambio de LP de los comandos 42 (gain = 0, resta a) y 43 (suma a):
## contador de LP, busto si c es 0, pausa de 11 ticks y musica segun LP.
func f408470(gain: int) -> int:
	var p := cmd_p()
	var amount := cmd_a()
	if gain == 0:
		amount = (-amount) & 0xffffffff
	var this_lp := m.u32(_JH_GRAPHICS) + 0xe68 + (p << 6)
	match cmd_step():
		0:
			# 408470 lee primero graphics+ed8 y luego +e98 (LP held+30).
			if not visual_busy("lp_held", 1) and not visual_busy("lp_held", 0):
				f47c4f0(this_lp, amount, 0xffffffff, 1)
			cmd_advance()
		1:
			# Ambas consultas originales se ejecutan antes del AND de resultados.
			var busy1 := visual_busy("lp", 1)
			var busy0 := visual_busy("lp", 0)
			if busy1 or busy0:
				return 0
			if cmd_c() != 0:
				f403ce0(p, amount)
			cmd_advance(0xffffc07f)
		2:
			if visual_busy("effects", 0, 0, 0x40858a):
				return 0
			if (cmd_tick() & 0x3f80) > 0x500:
				cmd_advance()
		3:
			f47c4f0(this_lp, amount, 0xffffffff, 0)
			cmd_advance()
		4:
			var busy0 := visual_busy("lp", 0)
			var busy1 := visual_busy("lp", 1)
			if busy0 or busy1:
				return 0
			f44ba00()
			cmd_finish()
	return 0


## Joey FUN_00408670: comando ea, borra el dano de batalla del bando (a57860 o a57850) y apaga
## los dos contadores de LP.
func f408670() -> int:
	m.set_u32(0xa57860 - (m.u32(JoeyMem.BATTLE) & 1) * 16, 0)
	f47c550(m.u32(_JH_GRAPHICS) + 0xe68)
	f47c550(m.u32(_JH_GRAPHICS) + 0xea8)
	cmd_finish()
	return 0


## Joey FUN_004086c0: comando 11, fija el terreno (nibble bajo de a577f4) con a, lo pasa al
## objeto de campo (449740) y espera su efecto (+0x140, vtable+4 = 403080).
func f4086c0() -> int:
	var a := cmd_a()
	var w := m.u16(0xa577f4)
	m.set_u16(0xa577f4, w ^ (((w & 0xff) ^ (a & 0xff)) & 0xf))
	if cmd_step() == 0:
		cmd_advance()
		f449740(m.u32(_JH_GRAPHICS) + 0x310, a)
		return 0
	if visual_busy("field_effect", 0, 0, 0x40871d): return 0
	cmd_finish()
	return 0

