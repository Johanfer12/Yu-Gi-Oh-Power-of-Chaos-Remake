class_name JoeyPortI
extends JoeyPortH
## Motor nativo de Joey, lote I de la etapa 2: manejadores de comandos 408730-40a7c0.
## Cada funcion se llama f<direccion de Joey_Pc.exe> (o _c5b9470_XX para los casos del despacho)
## y sobrescribe su declaracion con la misma aridad. Cotejo: re/scripts/joey_specs/port_i.py.
##
## Omisiones de presentacion (FRONTERA_JOEY.md 2.5 y 3): las esperas sobre la lista de efectos
## 5f3280+0x132c..0x1330 cuentan como "nada ocupado"; desaparecen new/delete, los functores y su
## insercion en la lista (40c3b0, 40c3e0, 40c570, 443050, 544120, 40c240), el metodo +0x24 del
## objeto 5f3280+0x3c y el metodo +0x10 del objeto visual del mazo (408b20).

## Lista visual de la mano (this de 41d050; 0x460 bytes por jugador, vector en +4..+8).
const _JI_HAND_OBJ := 0x5f300c
## Carta en transito (5675c0) y objeto de zona del jugador 0 (el 1 suma 0xd44).
const _JI_MOVED := 0xa558b0
const _JI_ZONE := 0xa55d74
## Ids de las cartas del exodia (409ab0, 5 x u32) y de su animacion final (409d00).
const _JI_EXODIA_IDS := 0x5da410
const _JI_EXODIA_END := 0x5da424
const _JI_EXODIA_ANIM := 0x5da424


static func _ji_zone(p: int, z: int) -> int:
	return _JI_ZONE + (p & 1) * JoeyMem.PLAYER_SIZE + z * JoeyMem.ZONE_SIZE


## Cartas de la mano visual de p: ([obj+8] - [obj+4]) >> 4, o 0 si el vector esta vacio. La
## lista vive en la presentacion; sin ella (5f300c a 0) se lee la pagina a cero: vacia.
func _ji_hand_count(p: int) -> int:
	var hand := m.u32(_JI_HAND_OBJ)
	if hand == 0:
		return 0
	var obj := hand + p * 0x460
	var first := m.u32(obj + 4)
	if first == 0:
		return 0
	return _s32((m.u32(obj + 8) - first) & 0xffffffff) >> 4


## Joey FUN_00408730: comando b1, marca con el bit 5 (valor b) la carta de la zona a y, si b no
## es 0 y c si, crea el efecto 452f20 sobre la zona.
func f408730() -> int:
	var p := cmd_p()
	var a := cmd_a()
	var b := cmd_b()
	var c := cmd_c()
	# Espera de la lista de efectos omitida.
	if cmd_step() == 0 and a <= 10 and (m.u32(_ji_zone(p, a)) & 0xfff) != 0:
		f570710(p, a, 5, b)
		if b != 0 and c == 0:
			# Palabra de 452f20: bit 0 jugador, bits 1-5 primera zona del grupo (0, 5 o 10),
			# bits 6-13 posicion en el grupo y 14-15 las banderas de cara y posicion.
			var base := 10
			var rem := 0
			if a < 10:
				base = (a / 5) * 5
				rem = a % 5
			var flags := m.u8(_ji_zone(p, a) + JoeyMem.Z_FLAGS)
			var info := m.local(4)
			m.set_u16(info, ((((flags << 8) | rem) << 6) | ((base & 0x1f) << 1) | (p & 1)) & 0xffff)
			f452f20(0, info)
			# Insercion en la lista de efectos (40c570) omitida.
		cmd_advance()
		return 0
	cmd_finish()
	return 0


## Joey FUN_004089c0: comando 07, busto de reaccion (403d10) y espera de los efectos.
func f4089c0() -> int:
	if cmd_step() == 0:
		f403d10(cmd_p())
		cmd_advance()
		return 0
	# Espera de la lista de efectos omitida.
	cmd_finish()
	return 0


## Joey FUN_00408a40: comando 0a, marcador de cadena (41f530) en (a, b); sin marcador termina;
## con el, el paso avanza hasta 5 y termina.
func f408a40() -> int:
	if cmd_step() == 0:
		if f41f530(cmd_p(), cmd_a(), cmd_b()) == 0:
			cmd_finish()
	var s := m.u32(JoeyMem.CMD_STATE)
	s ^= ((s + 1) ^ s) & 0x7f
	if (s & 0x7f) > 4:
		s &= 0xffffbfff
	m.set_u32(JoeyMem.CMD_STATE, s)
	return 0


## Joey FUN_00408ab0: comando 0b, quita el marcador de cadena (41f550) y espera a 41f570.
func f408ab0() -> int:
	if cmd_step() == 0:
		f41f550(cmd_p(), cmd_a(), cmd_b())
		cmd_advance()
		return 0
	if f41f570() == 0:
		cmd_finish()
	return 0


## Joey FUN_00408b20: refresca la imagen de la cima del mazo de p (objeto visual de la pila 0xd)
## con el bit de 570420(p, 0xd, 0).
func f408b20(p: int) -> int:
	# El resultado de 570420 se guarda en el byte bajo del propio argumento p y se pasa a 43c550.
	var flag := int(f570420(p, 0xd, 0) != 0)
	f41cf60(p, 0xd)
	# Metodo +0x10 del objeto visual con la carta de la cima (a56574) omitido.
	f43c550(f41cf60(p, 0xd), p, 0xd, flag)
	return 0


## Joey FUN_00408b90: comando 60, baraja el mazo de p (con al menos dos cartas): efecto 4532c0,
## srand(b << 16 | a), 568d80(p, 3) y refresco de la cima.
func f408b90() -> int:
	var p := cmd_p()
	var seed := ((cmd_b() << 16) | cmd_a()) & 0xffffffff
	var step := cmd_step()
	if step == 0:
		if (m.u16(0xa55d68 + (p & 1) * JoeyMem.PLAYER_SIZE) & 0xff00) < 0x200:
			cmd_finish()
			return 0
		f4532c0(0, p)
		# Insercion en la lista de efectos omitida.
		f43c720(f41cf60(p, 0xd))
		cmd_advance()
	elif step == 1:
		# Espera de la lista de efectos omitida.
		rng.srand(seed)  # 5c3bf5 (srand del CRT)
		f568d80(p, 3)
		f408b20(p)
		cmd_finish()
	return 0


## Joey FUN_00408d30: comando b5, retira la carta de la zona (jugador a & 0xff, zona a >> 8):
## buzon tipo 3 (40cdb0) hacia la ubicacion b >> 8 y, un tick despues, borra la zona.
func f408d30() -> int:
	var a := cmd_a()
	var pl := a & 0xff
	var z := (a >> 8) & 0xff
	var b := cmd_b()
	var loc := (b >> 8) & 0xff
	var step := cmd_step()
	if step == 0:
		cmd_advance()
		return 0
	var zone := _ji_zone(pl, z)
	if step != 1:
		f5bddf0(zone, 0x90)
		cmd_finish()
		return 0
	f5675c0(_JI_MOVED, zone)
	var flags := m.u16(zone + JoeyMem.Z_FLAGS)
	var from := ((((((flags << 13) & 0xffff) | (z & 0x1f)) << 1) | (pl & 1))) & 0xffff
	# local_14 no se inicializa: solo se usan bits que quedan fijados (0-5 de b y la ubicacion,
	# 6-13 a cero, 14-15 copiados de `from`).
	var to := (b & 1) | ((loc & 0x1f) << 1) | (from & 0xc000)
	if loc >= 5:
		to &= 0xbfff
	if loc == 0xe or loc == 0xf:
		to = (to & 0xc07f) | 0x8040
	var from_at := m.local(4)
	m.set_u32(from_at, from)
	var to_at := m.local(4)
	m.set_u32(to_at, to)
	f40cdb0(m.u32(_JI_MOVED) & 0xfff, from_at, to_at)
	cmd_advance()
	return 0


## Origen/destino del buzon: ((indice & 0xff) << 5 | ubicacion & 0x1f) << 1 | jugador, con el
## bit 14 de 5703a0 y el 15 de 570420.
func _ji_place_bits(w: int) -> int:
	var r := f5703a0(w & 1, (w >> 1) & 0x1f, (w >> 6) & 0xff)
	w = ((r & 1) << 14) | (w & 0xffffbfff)
	var r2 := f570420(w & 1, (w >> 1) & 0x1f, (w >> 6) & 0xff)
	return (((r2 << 15) & 0xffff) | (w & 0x7fff)) | (w & 0xffff0000)


## Joey FUN_00408ee0: comando 8e, mueve la carta de identidad a >> 8 (si sigue en el jugador
## a & 1 y la ubicacion a >> 1) a la ubicacion b >> 1 de b & 1, con buzon tipo 3 (40cdb0).
func f408ee0() -> int:
	var a := cmd_a()
	var p := a & 1
	var src := (a >> 1) & 0x7f
	var v := f5687d0(a >> 8) & 0xffffffff
	var idx := v >> 16
	var b := cmd_b()
	var bp := b & 1
	var bhi := b >> 8
	var c := cmd_c()
	var loc := (b >> 1) & 0x7f
	var step := cmd_step()
	if step == 0:
		if f41d050(m.u32(_JI_HAND_OBJ)) & 0xff != 0:
			return 0
		if (v & 0xff) == p and ((v >> 8) & 0xff) == src:
			var ptr := f5700f0(p, src, idx)
			var w := ((c & 1) << 22) | (m.u32(ptr) & 0xff1fffff)
			m.set_u32(ptr, w)
			if src == 0xb:
				m.set_u32(ptr, ((c & 0x30) << 15) | (w & 0xffe7ffff))
			if loc >= 0xb and loc <= 0xd:
				m.set_u32(ptr, m.u32(ptr) & 0xffe7bfff)
			f5675c0(_JI_MOVED, ptr)
			if loc == 0xb:
				bhi = m.u8(0xa55d68 + (bp & 1) * JoeyMem.PLAYER_SIZE)
			var from := _ji_place_bits(((((idx & 0xff) << 5) | (src & 0x1f)) << 1) | p)
			# Los bits 14-15 de `to` salen de los de la identidad leida (bits 6-7 de src).
			var to := ((((bhi & 0xff) << 5) | (loc & 0x1f)) << 1) | bp | (v & 0xffffc000)
			f570790(from & 1, (from >> 1) & 0x1f, idx)
			var index := 0 if loc == 0xf else (to >> 6) & 0xff
			if c & 0x80:
				index = 0x80
			f5708d0(to & 1, (to >> 1) & 0x1f, index, _JI_MOVED)
			to = _ji_place_bits(to)
			var from_at := m.local(4)
			m.set_u32(from_at, from)
			var to_at := m.local(4)
			m.set_u32(to_at, to)
			f40cdb0(m.u32(_JI_MOVED) & 0xfff, from_at, to_at)
			cmd_advance()
			return 0
	elif step == 1:
		if f41d050(m.u32(_JI_HAND_OBJ)) & 0xff != 0:
			return 0
	else:
		return 0
	cmd_finish()
	return 0


## Joey FUN_00409240: comando 8f, mueve la carta de (a & 1, zona (a >> 1) + (a >> 8) si cabe en
## el campo, o ubicacion a >> 1 e indice a >> 8) a la ubicacion b >> 1 de b & 1 con buzon tipo 3.
func f409240() -> int:
	var a := cmd_a()
	var b := cmd_b()
	var c := cmd_c()
	var bp := b & 1
	var loc := (b >> 1) & 0x7f
	var bhi := b >> 8
	var p := a & 1
	var src := (a >> 1) & 0x7f
	var idx := a >> 8
	if idx + src <= 10:
		src = idx + src
		idx = 0
	var step := cmd_step()
	if step == 1:
		cmd_finish()
		return 0
	if step != 0:
		return 0
	var ptr := f5700f0(p, src, idx)
	var e := m.u32(ptr)
	var w := (((((c & 1) << 3) | ((((c >> 5) & 1) << 1) | ((c >> 4) & 1))) << 19) | (e & 0xff07ffff)) & 0xffffffff
	m.set_u32(ptr, w)
	if p == bp and src < 5 and loc == 0xe:
		if (c & 8) == 0:
			if (f4022e0(w & 0xfff) & 0xffff) < 0x780 or (f4022e0(m.u16(ptr) & 0xfff) & 0xffff) > 0x783:
				var at := 0xa56430 + (p & 1) * JoeyMem.PLAYER_SIZE
				m.set_u32(at, m.u32(at) | 0x1000000)
	elif loc >= 0xb and loc <= 0xd:
		m.set_u32(ptr, w & 0xffe7bfff)
	f5675c0(_JI_MOVED, ptr)
	var pq := (bp & 1) * JoeyMem.PLAYER_SIZE
	match loc:
		0xb:
			bhi = m.u8(0xa55d68 + pq)
			f5706b0(bp, 4, 1)
		0xc:
			if bhi > 0:
				bhi = m.u8(0xa55d6b + pq)
		0xd:
			if bhi > 0:
				bhi = m.u8(0xa55d69 + pq)
		0xe:
			if bhi > 0:
				bhi = m.u8(0xa55d6a + pq)
		0xf:
			if bhi > 0:
				bhi = m.u8(0xa55d6c + pq)
	# La palabra `from` reutiliza una variable sin inicializar: sus bits 14-15 los fijan
	# 5703a0/570420; se modela a 0.
	var from := _ji_place_bits(((((idx & 0xff) << 5) | (src & 0x1f)) << 1) | p)
	var to := ((((bhi & 0xff) << 5) | (loc & 0x1f)) << 1) | bp | (idx & 0xffffc000)
	f570790(from & 1, (from >> 1) & 0x1f, (from >> 6) & 0xff)
	var index := 0 if loc == 0xf else (to >> 6) & 0xff
	if c & 0x40:
		var hi := (((from >> 14) & 1) | ((src << 2) & 0xff)) & 0xff
		hi = (((hi << 1) & 0xff) | ((from >> 15) & 1)) & 0xff
		hi = (((hi << 1) & 0xff) | (p & 0xf)) & 0xff
		index = (hi << 8) | 0x40
	f5708d0(to & 1, (to >> 1) & 0x1f, index, _JI_MOVED)
	to = _ji_place_bits(to)
	var from_at := m.local(4)
	m.set_u32(from_at, from)
	var to_at := m.local(4)
	m.set_u32(to_at, to)
	f40cdb0(m.u32(_JI_MOVED) & 0xfff, from_at, to_at)
	cmd_advance()
	return 0


## Joey FUN_00409700: comando 90, mueve la carta de identidad a >> 8 (sin comprobar donde esta)
## a la ubicacion (b >> 8) + (b >> 1) de b & 1 con el indice c, con buzon tipo 3.
func f409700() -> int:
	var a := cmd_a()
	var p := a & 1
	var src := (a >> 1) & 0x7f
	var idx := (f5687d0(a >> 8) & 0xffffffff) >> 16
	var b := cmd_b()
	var bp := b & 1
	var bhi := b >> 8
	var c := cmd_c()
	var loc := (b >> 1) & 0x7f
	var step := cmd_step()
	if step == 1:
		cmd_finish()
		return 0
	if step != 0:
		return 0
	if f41d050(m.u32(_JI_HAND_OBJ)) & 0xff != 0:
		return 0
	var ptr := f5700f0(p, src, idx)
	m.set_u32(ptr, m.u32(ptr) & 0xff1fffff)
	f5675c0(_JI_MOVED, ptr)
	var from := _ji_place_bits(((((idx & 0xff) << 5) | (src & 0x1f)) << 1) | p)
	# Bits 1-5 de la suma en 8 bits, 14 = c >> 8 y 15 = c & 1; la palabra alta es la de idx.
	var to := ((((bhi + loc) << 1) & 0x3e) | bp | ((((c & 0xff) << 1) | ((c >> 8) & 1)) << 14)) & 0xffff
	to |= idx & 0xffff0000
	f570790(from & 1, (from >> 1) & 0x1f, (from >> 6) & 0xff)
	f5708d0(to & 1, (to >> 1) & 0x1f, c, _JI_MOVED)
	var from_at := m.local(4)
	m.set_u32(from_at, from)
	var to_at := m.local(4)
	m.set_u32(to_at, to)
	f40cdb0(m.u32(_JI_MOVED) & 0xfff, from_at, to_at)
	cmd_advance()
	return 0


## Joey FUN_00409940: comando e5, efecto 4580f0 sobre la zona b % 5 de p y espera.
func f409940() -> int:
	var p := cmd_p()
	var a := cmd_a()
	var b := cmd_b()
	var step := cmd_step()
	if step == 0:
		# Bits 14-15 de una variable sin inicializar (& 0xc00b): se modelan a 0.
		var info := m.local(4)
		m.set_u16(info, ((p & 1) | ((b % 5) << 6) | 10) & 0xffff)
		f4580f0(0, a, info)
		# Insercion en la lista de efectos omitida.
		cmd_advance()
	elif step == 1:
		# Espera de la lista de efectos omitida.
		cmd_finish()
	return 0


## Joey FUN_00409ab0: comando 06, victoria por exodia: efecto 458d00 y, por cada una de las
## cinco cartas de 5da410 presente en una de las zonas 5-9 de p, el efecto 4580f0.
func f409ab0() -> int:
	var p := cmd_p()
	var step := cmd_step()
	if step == 0:
		f458d00(0)
		# Insercion en la lista de efectos omitida.
		cmd_advance()
		return 0
	if step != 1:
		# Espera de la lista de efectos omitida.
		cmd_finish()
		return 0
	# Variable sin inicializar (& 0xffcb | 0xa): sus bits 6-15 solo se leen tras fijar los 6-13
	# con la zona; los 14-15 se modelan a 0.
	var info := (p & 1) | 10
	var k := 0
	var at := _JI_EXODIA_IDS
	while at < _JI_EXODIA_END:
		var z := 0
		while z < 5:
			var card := f402460(m.u16(at)) & 0xffff
			# Recorre a56044: las zonas 5-9 del jugador, no las 0-4.
			if (m.u32(_ji_zone(p, z + 5)) & 0xfff) == card:
				info = (((z & 0xff) << 6) | (info & 0xc03f)) & 0xffff
				var info_at := m.local(4)
				m.set_u16(info_at, info)
				f4580f0(0, k, info_at)
				# Insercion en la lista de efectos omitida.
				break
			z += 1
		at += 4
		k += 1
	cmd_advance()
	return 0


## Joey FUN_00409d00: comando 05, final de la victoria por exodia: busto (403f00), espera a
## 40a0a0, 80 ticks resaltando en la mano las cartas de 5da424, y los efectos 45cf80 y 453b60.
func f409d00() -> int:
	var p := cmd_p()
	var s := m.u32(JoeyMem.CMD_STATE)
	match s & 0x7f:
		0:
			if (s & 0x3f80) == 0:
				f403f00(p)
			cmd_advance()
		1:
			if f40a0a0(m.u32(0x5f3280) + 0x1324) & 0xff == 0:
				cmd_advance()
		2:
			if (s & 0x780) == 0:
				var n := _ji_hand_count(p)
				var i := 0
				while i < n:
					var obj := f41cee0(p, 0xb, i)
					var want := f402460(m.u16(_JI_EXODIA_ANIM + ((s >> 11) & 7) * 4)) & 0xffff
					if obj_u32(obj, 0x10) == want:
						# Byte +0x20 del objeto visual a 0 (presentacion).
						f453830(0, obj)
						# Insercion en la lista de efectos omitida.
						break
					i += 1
			if (cmd_tick() & 0x3f80) >= 0x2800:
				cmd_advance()
		3:
			# Espera de la lista de efectos omitida.
			f45cf80(0, 1)
			# Insercion en la lista de efectos omitida.
			cmd_advance()
		4:
			# Espera de la lista de efectos omitida.
			cmd_advance()
		5:
			f453b60(0)
			# Insercion en la lista de efectos omitida.
			cmd_advance()
		6:
			# Espera de la lista de efectos omitida.
			cmd_finish()
	return 0


## Joey FUN_0040a0d0: comando 84, efecto 456490 de la carta c entre (a) y (b) y, al acabar, el
## vinculo de tipo 1 de la zona b a la a (56ab60).
func f40a0d0() -> int:
	var card := f402460(cmd_c()) & 0xffff
	if cmd_step() == 0:
		cmd_advance()
		var a := cmd_a()
		var b := cmd_b()
		var from := m.local(4)
		m.set_u16(from, ((a >> 7) & 0x3e) | (a & 1))
		var to := m.local(4)
		m.set_u16(to, ((b >> 7) & 0x3e) | (b & 1))
		f456490(0, card, to, from)
		# Insercion en la lista de efectos omitida.
		return 0
	if visual_busy("effects"): return 0
	f56ab60(cmd_b(), cmd_a(), 1)
	cmd_finish()
	return 0


## Joey FUN_0040a230: comando b2, efecto 456490 de la carta de la zona (a & 1, a >> 8) hacia
## (b) y, al acabar, el vinculo (a, c) en la zona b (56ab60).
func f40a230() -> int:
	var a := cmd_a()
	var p := a & 1
	if cmd_step() == 0:
		cmd_advance()
		var z := a >> 8
		var zone := _ji_zone(p, z)
		var card := m.u32(zone) & 0xfff
		var from := m.local(4)
		m.set_u16(from, ((((((m.u16(zone + JoeyMem.Z_FLAGS) & 0xfffe) << 13) | (z & 0x1f)) << 1) | p) & 0xffff))
		var b := cmd_b()
		var to := m.local(4)
		m.set_u16(to, ((b >> 7) & 0x3e) | (b & 1))
		f456490(0, card, to, from)
		# Insercion en la lista de efectos omitida.
		return 0
	if visual_busy("effects"): return 0
	f56ab60(cmd_b(), a, cmd_c())
	cmd_finish()
	return 0


## Joey FUN_0040a3c0: comando a5, invoca la carta b en la zona a >> 12 (cara y posicion en los
## bits 8-9 de a): 568610, estado 0x20008, identidad nueva, efecto 44fcc0, pausa de 8 ticks y
## buzon tipo 4 (40ce70).
func f40a3c0() -> int:
	var hi := (cmd_a() >> 8) & 0xff
	var z := hi >> 4
	var pos := hi & 1
	var face := (hi >> 1) & 1
	var bc := ((cmd_c() << 16) | cmd_b()) & 0xffffffff
	var p := cmd_p()
	var card := f402460(bc & 0xfff) & 0xfff
	var entry := card | (bc & 0xfffff000)
	match cmd_step():
		0:
			var at := m.local(4)
			m.set_u32(at, entry)
			f568610(p, z, at, face, pos)
			var st := 0xa55e00 + z * JoeyMem.ZONE_SIZE + (p & 1) * JoeyMem.PLAYER_SIZE
			m.set_u32(st, m.u32(st) | 0x20008)
			var ptr := f5700f0(p, z, 0)
			var serial := 0xa55d66 + p * JoeyMem.PLAYER_SIZE
			m.set_u32(ptr, ((m.u8(serial) & 0x7f) << 24) | (m.u32(ptr) & 0x80ffffff))
			m.set_u16(serial, (m.u16(serial) + 1) & 0xffff)
			var info := m.local(4)
			m.set_u16(info, (((((pos << 1) | (face & 1)) & 0xff) << 8 | (z & 0xff)) << 6 | (p & 1)) & 0xffff)
			f44fcc0(0, card, info)
			# Insercion en la lista de efectos y metodo +0x24 de 5f3280+0x3c omitidos.
			cmd_advance(0xffffc07f)
		1:
			if (cmd_tick() & 0x3f80) >= 0x400:
				cmd_advance(0xffffc07f)
		2:
			var info := m.local(4)
			m.set_u16(info, (((((pos << 1) | (face & 1)) & 0xff) << 8 | (z & 0xff)) << 6 | (p & 1)) & 0xffff)
			f40ce70(card, info)
			cmd_advance()
		3:
			# Espera de la lista de efectos omitida.
			cmd_finish()
	return 0


## Joey FUN_0040a690: comandos e2 y e3, salto a 40a6a0.
func f40a690() -> int:
	return f40a6a0()


## Joey FUN_0040a6a0: comando e4 (y e2/e3), efecto 4568c0 sobre la zona b de p con el valor a;
## termina en el mismo tick si no hay efectos pendientes.
func f40a6a0() -> int:
	if cmd_step() == 0:
		cmd_advance()
		var info := m.local(4)
		m.set_u16(info, (((0xc000 | (cmd_b() & 0x1f)) << 1) | cmd_p()) & 0xffff)
		f4568c0(0, info)
		# Insercion en la lista de efectos omitida.
	# Espera de la lista de efectos omitida.
	cmd_finish()
	return 0


## Joey FUN_0040a7c0: comando e0, efecto 4571d0 sobre la zona c de p (con a == 0 y b == 0);
## termina en el mismo tick si no hay efectos pendientes.
func f40a7c0() -> int:
	if cmd_step() == 0:
		cmd_advance()
		var info := m.local(4)
		m.set_u16(info, (((0xc000 | (cmd_c() & 0x1f)) << 1) | cmd_p()) & 0xffff)
		# 4571d0(info, b == 0, a == 0, 1): la frontera solo recibe el primero.
		f4571d0(0, info)
		# Insercion en la lista de efectos omitida.
	# Espera de la lista de efectos omitida.
	cmd_finish()
	return 0
