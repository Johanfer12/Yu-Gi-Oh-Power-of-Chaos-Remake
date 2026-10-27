class_name JoeyPortG
extends JoeyPortF
## Motor nativo de Joey, lote G de la etapa 2: manejadores de comandos 404460-4063e0.
## Cada funcion se llama f<direccion de Joey_Pc.exe> (o _c5b9470_XX para los casos del despacho)
## y sobrescribe su declaracion con la misma aridad. Cotejo: re/scripts/joey_specs/port_g.py.
##
## Infraestructura omitida (FRONTERA_JOEY.md 2.5 y 3): new/delete, shared_ptr de la lista de
## efectos 5f3280+0x132c..0x1330 y el metodo +0x24 del objeto 5f3280+0x3c. Las esperas
## por vtable+4 consultan visual_busy; sin renderer conservan el contrato no ocupado. Los
## constructores de efecto son eventos de frontera y reciben this = 0 (objeto omitido).

const _JG_A := JoeyMem.CMD + 2      ## u16 argumento a (a550a2)
const _JG_B := JoeyMem.CMD + 4      ## u16 argumento b (a550a4); u32 en a550a4 = b | c << 16
const _JG_C := JoeyMem.CMD + 6      ## u16 argumento c (a550a6)
const _JG_HELD := 0xa558b0          ## entrada retenida por el comando en curso
const _JG_FX_HELD := 0x5f25d8       ## indice retenido para la explosion (fuera del blob)
const _JG_FIELD_OBJ := 0x5f300c     ## objeto de mesa (ECX de 41d160 y 41d050)
const _JG_PHASE_OBJ := 0x5f33f0     ## indicador de fase (ECX de 481230)


## Variable local u16 cuya direccion se pasa a otra rutina.
func _jg_local16(value: int) -> int:
	var at := m.local(4)
	m.set_u16(at, value & 0xffff)
	return at


## Joey FUN_00404460: comando 08. Con el bit 0 de c parpadea la zona 15 ticks (449780 en los
## pasos con el bit 1); si no, espera al objeto visual de la zona b (o de la pila 0xe).
func f404460() -> int:
	var bc := m.u32(_JG_B)
	var hi := (bc >> 8) & 0xff
	var lo := bc & 0xff
	var a := m.u16(_JG_A)
	if (bc & 0x10000) != 0:
		var s := m.u32(JoeyMem.CMD_STATE)
		s ^= ((s + 1) ^ s) & 0x7f
		m.set_u32(JoeyMem.CMD_STATE, s)
		if (s & 0x7f) >= 0xf:
			m.set_u32(JoeyMem.CMD_STATE, s & 0xffffbfff)
			return 0
		if (s & 2) != 0:
			f449780(a, hi + lo)
		return 0
	if lo == 0xe:
		# El original no comprueba el objeto de la pila (siempre existe con pantalla). Sus campos
		# +0x18/+0x1c y su metodo ocupado (vtable+4) son de presentacion: se omiten.
		f41cf60(a, 0xe)
		if (m.u32(JoeyMem.CMD_STATE) & 0x7f) == 0:
			cmd_advance()
			return 0
		if not visual_busy("zone", a, lo):
			cmd_finish()
		return 0
	var obj := f41cee0(a, lo, hi)
	if obj != 0:
		# Con objeto visual: paso 0 fija sus campos +0x18 = 1, +0x1c = 0x100 (omitidos) y despues
		# espera su metodo ocupado mediante visual_busy.
		if (m.u32(JoeyMem.CMD_STATE) & 0x7f) == 0:
			cmd_advance()
			return 0
		if visual_busy("zone", a, lo + hi):
			return 0
	cmd_finish()
	return 0


## Joey FUN_00404580: comando 14. Lanza el efecto 4516a0 (y 455d90 en las partidas de tipo 5 o
## 7, 456100 en red) y espera a la lista de efectos.
func f404580() -> int:
	if (m.u32(JoeyMem.CMD_STATE) & 0x7f) == 0:
		f4516a0(0)
		if f44b990() != 0:
			f455d90(0)
		if f44b980() != 0:
			f456100(0)
		cmd_advance()
		return 0
	if not visual_busy("effects"):
		cmd_finish()
	return 0


## Joey FUN_0044b990: 1 si el tipo de partida (5f3294) es 5 o 7. Dependencia adelantada: solo la
## llama 404580.
func f44b990() -> int:
	var kind := m.u32(GAME_KIND)
	return int(kind == 5 or kind == 7)


## Joey FUN_00404770: comando 04. Con a < 3 lanza el efecto 451b80; si el comando es del lado
## contrario al local (bit 0 de a54e5c) invierte 0 y 1 y lleva 2 a 2.
func f404770() -> int:
	if (m.u32(JoeyMem.CMD_STATE) & 0x7f) == 0:
		var a := m.u16(_JG_A)
		if a < 3:
			var v := a
			if cmd_p() == ((~m.u8(JoeyMem.MODE)) & 1):
				v = int(a == 0) if a < 2 else 2
			f451b80(0, v, 0)
		cmd_advance()
		return 0
	if not visual_busy("effects"):
		cmd_finish()
	return 0


## Joey FUN_004048c0: comando 03. Cambio de turno: cuenta el turno (a577f8), alterna el jugador
## de a577fa y pone la fase 7, borra a577fe y avisa al indicador de fase.
func f4048c0() -> int:
	m.set_u16(0xa577f8, m.u16(0xa577f8) + 1)
	m.set_u16(0xa577fe, 0)
	m.set_u16(JoeyMem.TURN, (m.u16(JoeyMem.TURN) ^ 1) | 0xe)
	f4811f0(1 - cmd_p(), 0xffffffff)
	cmd_finish()
	return 0


## Joey FUN_00404920: cambio de fase (casos 0x2d-0x32 del despacho). Paso 0: objeto de batalla
## (413a90 al entrar en la fase 3, 413ac0 al salir de la 3), fase en los bits 1-3 de a577fa y
## aviso al indicador; despues espera al indicador (vtable+4 de 5f33f0, visual_busy).
func f404920(phase: int) -> int:
	var p := cmd_p()
	if (m.u32(JoeyMem.CMD_STATE) & 0x7f) == 0:
		cmd_advance()
		if phase == 3:
			f413a90(p)
		elif (m.u8(JoeyMem.TURN) & 0xe) == 6:
			f413ac0()
		m.set_u16(JoeyMem.TURN, ((phase & 7) << 1) | (m.u16(JoeyMem.TURN) & 0xfff1))
		f481230(m.u32(_JG_PHASE_OBJ), p, phase)
		return 0
	if not visual_busy("phase"):
		cmd_finish()
	return 0


## Joey FUN_004049c0: comando 77. Coloca en la zona a & 0xff la carta con id b (568610, cara y
## posicion en los bits 1 y 0 de a >> 8) y la pinta (41d160); 4 ticks.
func f4049c0() -> int:
	var a := m.u16(_JG_A)
	var z := a & 0xff
	var hi := a >> 8
	var face := (hi >> 1) & 1
	var pos := hi & 1
	var p := cmd_p()
	var entry := m.local(4)
	var raw := m.u32(_JG_B)
	m.set_u32(entry, (f402460(raw & 0xfff) & 0xfff) | (raw & 0xfffff000))
	var step := m.u32(JoeyMem.CMD_STATE) & 0x7f
	if step == 0:
		f568610(p, z, entry, face, pos)
		var where := _jg_local16((((face & 1) | (pos * 2)) << 0xd | (z & 0x1f)) << 1 | (p & 1))
		f41d160(m.u32(_JG_FIELD_OBJ), m.u32(entry) & 0xfff, where)
		cmd_advance()
		return 0
	if step == 1 or step == 2:
		if step == 2 and visual_busy("effects"):
			return 0
		# Paso 2: espera a la lista de efectos.
		cmd_advance()
		return 0
	cmd_finish()
	return 0


## Joey FUN_00404b40: comando 79. Mueve la carta de (p, a >> 8, a & 0xff) al destino de b
## (0x10: 0xf, si no 0xe) con el estado de c (bit 0 boca arriba, bit 3 conserva 0x4000): efecto
## 450c30, flags del objeto, marca a56430, 570790/5708d0, buzon 40ce10 y reaccion 403cb0.
func f404b40() -> int:
	var hi := m.u8(_JG_A + 1)
	var lo := m.u8(_JG_A)
	var p := cmd_p()
	var to_banish := int(m.u16(_JG_B) == 0x10)
	var c := m.u16(_JG_C)
	var keep := c & 8
	match m.u32(JoeyMem.CMD_STATE) & 0x7f:
		0:
			cmd_advance()
		1:
			var card := f570230(p, hi, lo) & 0xffff
			if card == 0:
				cmd_finish()
			else:
				var r1 := f570420(p, hi, lo)
				var r2 := f5703a0(p, hi, lo)
				var idx := 0
				if hi == 0xd:
					idx = 0
				elif hi >= 0xc:
					idx = 1
				else:
					idx = lo
				var high := ((r2 & 1) | ((r1 << 1) & 0xff)) & 0xff
				var where := _jg_local16(((((high << 8) | (idx & 0xff)) << 5 | (hi & 0x1f)) << 1) | (p & 1))
				f450c30(0, card, where)
			cmd_advance()
		2:
			var ptr := f5700f0(p, hi, lo)
			var v := (((c & 1) | 2) << 0x16) | (m.u32(ptr) & 0xff9fffff)
			m.set_u32(ptr, v)
			if keep != 0:
				m.set_u32(ptr, v & 0xffffbfff)
			if p == ((m.u32(ptr) >> 12) & 1) and hi < 5 and to_banish == 0 and keep == 0:
				if (f4022e0(m.u16(ptr) & 0xfff) & 0xffff) < 0x780 \
						or (f4022e0(m.u16(ptr) & 0xfff) & 0xffff) > 0x783:
					var flags := JoeyMem.pl(p) + 0x6d0
					m.set_u32(flags, m.u32(flags) | 0x1000000)
			f5675c0(_JG_HELD, ptr)
			var from := (((lo << 5) | (hi & 0x1f)) << 1 | ((((p ^ keep) & 1) ^ keep) & 0xc001)) & 0xffff
			from = ((f5703a0(p, hi, lo) & 1) << 0xe) | (from & 0xbfff)
			from = ((f570420(p, hi, lo) << 0xf) | (from & 0x7fff)) & 0xffff
			# Destino: los bits 6, 14 y 15 vienen de la pila del tick anterior; el 6 se fuerza a 1
			# y el 14 y el 15 se reescriben abajo, asi que no influyen.
			var to := ((m.u32(_JG_HELD) >> 12) & 1) | ((((to_banish + 0xe) & 0x1f) | 0x20) << 1)
			f570790(from & 1, (from >> 1) & 0x1f, lo)
			f5708d0(to & 1, (to >> 1) & 0x1f, 0 if to_banish != 0 else (to >> 6) & 0xff, _JG_HELD)
			to = ((f5703a0(to & 1, (to >> 1) & 0x1f, (to >> 6) & 0xff) & 1) << 0xe) | (to & 0xbfff)
			to = ((f570420(to & 1, (to >> 1) & 0x1f, (to >> 6) & 0xff) << 0xf) | (to & 0x7fff)) & 0xffff
			f40ce10(m.u32(_JG_HELD) & 0xfff, _jg_local16(from), _jg_local16(to))
			cmd_advance()
		3:
			if (c & 1) != 0 and lo + hi <= 0xa:
				f403cb0(p, f4022e0(m.u32(_JG_HELD) & 0xfff) & 0xffff)
			cmd_advance()
		4:
			if not visual_busy("effects"):
				cmd_finish()
	return 0


## Joey FUN_00405020: comando 3c. Separa el objeto de la zona a de p: buzon 40ce10 (paso 0) y
## despues 56a490, copia del objeto al hueco b de a57864, zona a cero y bit de a577f0 libre.
func f405020() -> int:
	var p := cmd_p()
	var b := m.u16(_JG_B)
	var a := m.u16(_JG_A)
	var at := JoeyMem.zone(p, a)
	match m.u32(JoeyMem.CMD_STATE) & 0x7f:
		0:
			var from := ((((m.u8(at + 6) << 8) | (a & 0xff)) << 6) | p) & 0xffff
			# El original parte de una local sin iniciar, pero solo conserva sus bits 14-15 y los
			# toma de `from`.
			var to := (from & 0xc000) | 0x3fc0 | ((a & 0x1f) << 1) | p
			f40ce10(m.u16(at) & 0xfff, _jg_local16(from), _jg_local16(to))
			cmd_advance()
		1:
			f56a490(p, a)
			# 5bde10 (memcpy del CRT) y 5bddf0 (memset).
			m.copy(JoeyMem.DETACHED + b * JoeyMem.ZONE_SIZE, at, JoeyMem.ZONE_SIZE)
			f5bddf0(at, JoeyMem.ZONE_SIZE)
			m.set_u32(0xa577f0, m.u32(0xa577f0) & ~(1 << (((p << 4) + a) & 0x1f)))
			cmd_finish()
	return 0


## Joey FUN_00405190: comando 7c. Devuelve al campo el objeto separado (a57864 si coincide con
## el de a57840, si no el vacio a578f4): efecto 4511d0, pausa de 15 ticks, flags, marca a56430,
## 570790/5708d0, buzon 40ce10, reaccion 403cb0 y espera.
func f405190() -> int:
	var sel := m.u16(JoeyMem.BATTLE)
	var a := m.u16(_JG_A)
	var p := cmd_p()
	var b1 := m.u16(_JG_B) & 1
	var c1 := m.u8(_JG_C) & 1
	var obj := JoeyMem.DETACHED_EMPTY
	if p == (sel & 1) and a == ((sel >> 8) & 7):
		obj = JoeyMem.DETACHED
	match m.u32(JoeyMem.CMD_STATE) & 0x7f:
		0:
			# El original mezcla la local con basura de la pila, pero el resultado es `here` entero.
			var here := (((((m.u16(obj + 6) << 0xd) & 0xffff) | (a & 0x1f) | 0x1fe0) << 1) | p) & 0xffff
			f4511d0(0, m.u32(obj) & 0xfff, _jg_local16(here))
			var s := m.u32(JoeyMem.CMD_STATE)
			m.set_u32(JoeyMem.CMD_STATE, (s ^ (((s + 1) ^ s) & 0x7f)) & 0xffffc07f)
		1:
			if (cmd_tick() & 0x3f80) > 0x700:
				cmd_advance()
		2:
			var v := (c1 << 0x16) | (m.u32(obj) & 0xffbfffff) | 0xa00000
			m.set_u32(obj, v)
			if p == ((v >> 12) & 1) and a < 5 and b1 == 0:
				if (f4022e0(m.u16(obj) & 0xfff) & 0xffff) < 0x780 \
						or (f4022e0(m.u16(obj) & 0xfff) & 0xffff) > 0x783:
					var flags := JoeyMem.pl(p) + 0x6d0
					m.set_u32(flags, m.u32(flags) | 0x1000000)
			f5675c0(_JG_HELD, obj)
			var here := (((((m.u16(obj + 6) << 0xd) & 0xffff) | (a & 0x1f) | 0x1fe0) << 1) | p) & 0xffff
			# Destino: bits 14-15 de la pila, reescritos abajo por 5703a0/570420.
			var to := ((m.u32(_JG_HELD) >> 12) & 1) | ((((int(b1 != 0) + 0xe) & 0x1f) | 0x20) << 1)
			f570790(here & 1, (here >> 1) & 0x1f, (here >> 6) & 0xff)
			f5708d0(to & 1, (to >> 1) & 0x1f, (to >> 6) & 0xff, _JG_HELD)
			to = ((f5703a0(to & 1, (to >> 1) & 0x1f, (to >> 6) & 0xff) & 1) << 0xe) | (to & 0xbfff)
			to = ((f570420(to & 1, (to >> 1) & 0x1f, (to >> 6) & 0xff) << 0xf) | (to & 0x7fff)) & 0xffff
			f40ce10(m.u32(_JG_HELD) & 0xfff, _jg_local16(here), _jg_local16(to))
			cmd_advance()
		3:
			f403cb0(p, f4022e0(m.u32(_JG_HELD) & 0xfff) & 0xffff)
			cmd_advance()
		4:
			if not visual_busy("effects"):
				cmd_finish()
	return 0


## Joey FUN_00405620: comando 7a (explosion). Guarda la imagen del objeto visual de la zona a en
## 5f25d8, efecto 4511d0, pausa de 15 ticks, buzon 40ce10, reaccion 403cb0 y espera.
func f405620() -> int:
	var a := m.u16(_JG_A)
	var p := cmd_p()
	var b1 := m.u16(_JG_B) & 1
	var at := JoeyMem.zone(p, a)
	match m.u32(JoeyMem.CMD_STATE) & 0x7f:
		0:
			var obj := f41cee0(p, a, 0)
			# Con objeto visual se guarda su imagen (obj + 0x10, memoria de presentacion).
			m.set_u32(_JG_FX_HELD, 0 if obj == 0 else m.u32(obj + 0x10))
			cmd_advance()
		1:
			# Igual que en 405190, la mezcla con la pila deja el valor entero.
			var here := ((((m.u8(at + 6) << 8) | (a & 0xff)) << 6) | (p & 1)) & 0xffff
			f4511d0(0, m.u32(_JG_FX_HELD), _jg_local16(here))
			var s := m.u32(JoeyMem.CMD_STATE)
			m.set_u32(JoeyMem.CMD_STATE, (s ^ (((s + 1) ^ s) & 0x7f)) & 0xffffc07f)
		2:
			if (cmd_tick() & 0x3f80) > 0x700:
				cmd_advance()
		3:
			f5675c0(_JG_HELD, at)
			var here := ((((m.u8(at + 6) << 8) | (a & 0xff)) << 6) | (p & 1)) & 0xffff
			var to := (((((int(b1 != 0) + 0xe) & 0x1f) | 0xc020) << 1) | ((m.u32(_JG_HELD) >> 12) & 1)) & 0xffff
			f40ce10(m.u32(_JG_HELD) & 0xfff, _jg_local16(here), _jg_local16(to))
			cmd_advance()
		4:
			# El argumento lleva en la mitad alta la de a558ac (4022e0 solo usa el ushort).
			f403cb0(p, f4022e0((m.u32(JoeyMem.CMD_STATE) & 0xffff0000) | m.u16(_JG_FX_HELD)) & 0xffff)
			cmd_advance()
		5:
			if not visual_busy("effects"):
				cmd_finish()
	return 0


## Joey FUN_00405960: comando c4. En el paso 0 desempaqueta b y c (mano = b & 0xff -> b: indice
## en b >> 4, zona en b & 0xf; c: boca arriba y posicion) y sigue como 4059c0.
func f405960() -> int:
	if (m.u8(JoeyMem.CMD_STATE) & 0x7f) == 0:
		var b0 := m.u8(_JG_B)
		var b1 := m.u8(_JG_B + 1)
		m.set_u16(_JG_B, ((b0 & 0xf) << 8) | (b0 >> 4))
		m.set_u16(_JG_C, (((b1 >> 1) & 1) << 8) | (b1 & 1))
	return f4059c0()


## Joey FUN_004059c0: comando ce. Coloca la carta b & 0xff de la mano de p en la zona b >> 8
## (568610 con c >> 8 y c & 0xff, 570790 sobre la mano, buzon 40cdb0, 570710 si c & 0xff) y
## si c & 0xff es 0 lanza el efecto 44efd0; 4 ticks.
func f4059c0() -> int:
	var p := cmd_p()
	var card := f402460(m.u16(_JG_A))
	var b_lo := m.u8(_JG_B)
	var b_hi := m.u8(_JG_B + 1)
	var c_lo := m.u8(_JG_C)
	var c_hi := m.u8(_JG_C + 1)
	match m.u32(JoeyMem.CMD_STATE) & 0x7f:
		0:
			cmd_advance()
		1:
			f5675c0(_JG_HELD, JoeyMem.pl(p) + JoeyMem.P_HAND + b_lo * 4)
			var from := ((((b_lo | (c_lo << 9)) << 6) | (p & 1)) | 0x16) & 0xffff
			var to := ((((((c_hi & 1) | (c_lo << 1)) & 0xff) << 8) | b_hi) << 6 | (p & 1)) & 0xffff
			f570790(from & 1, (from >> 1) & 0x1f, (from >> 6) & 0xff)
			f568610(p, b_hi, _JG_HELD, c_hi, c_lo)
			f40cdb0(card, _jg_local16(from), _jg_local16(to))
			if c_lo != 0:
				f570710(p, b_hi, 1, 1)
			cmd_advance()
		2:
			if c_lo == 0:
				var where := _jg_local16(((((c_hi & 1) << 8) | b_hi) << 6) | (p & 1))
				f44efd0(0, card & 0xffff, where)
			cmd_advance()
		3:
			if not visual_busy("effects"):
				cmd_finish()
	return 0


## Joey FUN_00405c60: comando c5. En el paso 0 desempaqueta b (indice en b >> 4, zona en b & 0xf)
## y c (c & 0xff pasa a c >> 8, bit 0 de b >> 8 a c & 0xff) y sigue como 405cb0.
func f405c60() -> int:
	if (m.u8(JoeyMem.CMD_STATE) & 0x7f) == 0:
		var b0 := m.u8(_JG_B)
		var b1 := m.u8(_JG_B + 1)
		var c0 := m.u8(_JG_C)
		m.set_u16(_JG_B, ((b0 & 0xf) << 8) | (b0 >> 4))
		m.set_u16(_JG_C, (c0 << 8) | (b1 & 1))
	return f405cb0()


## Joey FUN_00405cb0: comando cf. Coloca boca abajo la carta b & 0xff de la mano en la zona de
## magia (b >> 8, menos 5 si es >= 5; el campo 10 para las magias de campo): reaccion 403c50/
## 403bc0, 570790, 5686e0, buzon 40cdb0, 570710 y, si c & 0xff es 0, efecto 44efd0.
func f405cb0() -> int:
	var p := cmd_p()
	var card := f402460(m.u16(_JG_A))
	var col := m.u8(_JG_B + 1)
	var c_lo := m.u8(_JG_C)
	var c_hi := m.u8(_JG_C + 1)
	var b_lo := m.u8(_JG_B)
	var base := 5
	if col >= 5:
		col -= 5
	if (f4025d0(card) & 0xffff) == 0x16 and (f402700(card) & 0xffff) == 2:
		base = 10
		col = 0
	match m.u32(JoeyMem.CMD_STATE) & 0x7f:
		0:
			if c_hi == 0:
				if c_lo == 0:
					f403c50(p, f4022e0(card) & 0xffff)
				else:
					f403bc0(p, f4022e0(card) & 0xffff)
			cmd_advance()
		1:
			if visual_busy("effects"):
				return 0
			# Espera a la lista de efectos mediante visual_busy.
			f5675c0(_JG_HELD, JoeyMem.pl(p) + JoeyMem.P_HAND + b_lo * 4)
			var from := ((((b_lo | (c_lo << 9)) << 6) | (p & 1)) | 0x16) & 0xffff
			var to := (((((col & 0xff) | (c_lo << 9)) << 5 | (base & 0x1f)) << 1) | (p & 1)) & 0xffff
			f570790(from & 1, (from >> 1) & 0x1f, (from >> 6) & 0xff)
			var z := base + col
			f5686e0(p, z, _JG_HELD, c_lo)
			f40cdb0(card, _jg_local16(from), _jg_local16(to))
			if c_hi == 0 and c_lo != 0:
				f570710(p, z, 1, 1)
			cmd_advance()
		2:
			if c_lo == 0:
				var where := _jg_local16((((col & 0xff) << 5 | (base & 0x1f)) << 1) | (p & 1))
				f44efd0(0, card & 0xffff, where)
			elif c_hi == 0:
				f403bf0(p, f4022e0(card) & 0xffff)
			cmd_advance()
		3:
			if not visual_busy("effects"):
				cmd_finish()
	return 0


## Joey FUN_00406060: comando c6. Siembra rand() con (b << 16) | a, baraja la mano de p
## (56d460) y si cambio marca los objetos visuales de la mano; borra el bit 4 de a56430 y
## espera al objeto de mesa (41d050).
func f406060() -> int:
	var p := cmd_p()
	match m.u32(JoeyMem.CMD_STATE) & 0x7f:
		0:
			if visual_busy("effects"):
				return 0
			# Espera a la lista de efectos mediante visual_busy.
			rng.srand((m.u16(_JG_B) << 16) | m.u16(_JG_A))  # 5c3bf5 (srand del CRT)
			if f56d460(p) != 0:
				var before := {}
				var count := JoeyMem.pl(p) + JoeyMem.P_HAND_N
				var i := 0
				if m.u8(count) != 0:
					while true:
						var obj := f41cee0(p, 0xb, i)
						if obj != 0:
							before[i] = m.u32(obj + 0x10)
						i += 1
						if i >= m.u8(count):
							break
				if not before.is_empty():
					present("native_hand_shuffle", {"p": p, "before": before})
			var flags := JoeyMem.pl(p) + 0x6d0
			m.set_u32(flags, m.u32(flags) & 0xffffffef)
			cmd_advance()
		1:
			if not visual_busy("effects") and f41d050(m.u32(_JG_FIELD_OBJ)) == 0:
				cmd_finish()
	return 0


## Joey FUN_004061b0: comando 6f. Muestra la carta del id a (efecto 44fcc0 si c = 2, si no
## 44f630) con la ubicacion del objeto visual de la zona b; 2 ticks.
func f4061b0() -> int:
	var p := cmd_p()
	var card := f402460(m.u16(_JG_A)) & 0xffff
	var b := m.u16(_JG_B)
	var c := m.u16(_JG_C)
	var step := m.u32(JoeyMem.CMD_STATE) & 0x7f
	if step == 0:
		cmd_advance()
	elif step == 2:
		if not visual_busy("effects", 0, 0, 0x406230):
			cmd_finish()
		return 0
	elif step != 1:
		return 0
	# Paso 1 (el 0 sigue aqui en el mismo tick): espera a la lista de efectos.
	if visual_busy("effects", 0, 0, 0x40628e):
		return 0
	# 418b50 (thiscall sobre el objeto de 41cee0) copia la ubicacion obj+0x24 en la local que
	# 41cee0 deja en la pila y devuelve su direccion.
	var spot := m.local(4)
	var obj := f41cee0(p, b, 0)
	var where := f418b50(obj, spot)
	# Sin objeto visual la frontera devuelve 0 y el original leeria la direccion 0 (en el arnes,
	# pagina a cero). La ubicacion solo llega a los eventos 44fcc0/44f630.
	var loc := _jg_local16(0 if where == 0 else m.u16(where))
	if c == 2:
		f44fcc0(0, card, loc)
	else:
		f44f630(0, card, loc)
	# Metodo +0x24 del objeto 5f3280+0x3c (41b050): el panel de detalle muestra la carta.
	f41b050(card)
	cmd_advance()
	return 0


## Joey FUN_004063e0: comando 70. Saca la carta de la clave b (568b90 -> efecto 44fcc0), pausa
## de 8 ticks y la lleva a (a & 0xff, a >> 8, c) con 5687d0/5700f0, 570790/5708d0, buzon 40ce10
## y 570710.
func f4063e0() -> int:
	var a_lo := m.u8(_JG_A)
	var z := m.u8(_JG_A + 1)
	var b := m.u16(_JG_B)
	var c_lo := m.u8(_JG_C)
	var c_hi := m.u8(_JG_C + 1)
	match m.u32(JoeyMem.CMD_STATE) & 0x7f:
		0:
			if visual_busy("effects"):
				return 0
			# Espera a la lista de efectos mediante visual_busy.
			var card := f568b90(b)
			var where := _jg_local16((((c_lo * 2) | (c_hi & 1)) << 0xd | (z & 0x1f)) << 1 | (a_lo & 1))
			f44fcc0(0, card, where)
			f41b050(card) # Metodo +0x24 de 5f3280+0x3c: panel de detalle.
			var s := m.u32(JoeyMem.CMD_STATE) & 0xffffc07f
			m.set_u32(JoeyMem.CMD_STATE, s ^ (((s + 1) ^ s) & 0x7f))
		1:
			var s := cmd_tick()
			if (s & 0x3f80) >= 0x400:
				s &= 0xffffc07f
				m.set_u32(JoeyMem.CMD_STATE, s ^ (((s + 1) ^ s) & 0x7f))
		2:
			var key := f5687d0(b)
			var ptr := f5700f0(key & 0xff, (key >> 8) & 0xff, (key >> 16) & 0xffff)
			f5675c0(_JG_HELD, ptr)
			# Origen: los bits 14-15 vienen de la pila y los reescriben 5703a0/570420.
			var from := (((((key >> 8) & 0x1f) | (((key >> 16) & 0xff) << 5)) << 1) | (key & 1)) & 0xffff
			from = ((f5703a0(from & 1, (from >> 1) & 0x1f, (from >> 6) & 0xff) & 1) << 0xe) | (from & 0xbfff)
			from = ((f570420(from & 1, (from >> 1) & 0x1f, (from >> 6) & 0xff) << 0xf) | (from & 0x7fff)) & 0xffff
			var to := ((((c_lo * 2) | (c_hi & 1)) << 0xd | (z & 0x1f)) << 1 | (a_lo & 1)) & 0xffff
			f570790(from & 1, (from >> 1) & 0x1f, (from >> 6) & 0xff)
			f5708d0(to & 1, (to >> 1) & 0x1f, (c_hi << 8) | c_lo, _JG_HELD)
			f40ce10(m.u32(_JG_HELD) & 0xfff, _jg_local16(from), _jg_local16(to))
			f570710(a_lo, z, 1, 1)
			cmd_advance()
		3:
			if not visual_busy("effects"):
				cmd_finish()
	return 0
