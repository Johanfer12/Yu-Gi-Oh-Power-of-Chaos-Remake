class_name DuelPortD
extends DuelPortC
## Modulo del porte del motor de duelo (ver docs/duel/PORTING.md).
## Lote D: manejadores de comandos 0x548c00-0x54cbb0 y auxiliares (0x54c8a0, 0x54ca50,
## 0x54cbb0). FUN_00407830 (buzon de animaciones de movimiento de carta), FUN_00403150
## (refresco visual del mazo) y FUN_00437860 (espera de animacion) son presentacion.

const _D_MV := DuelMem.MOVING_CARD
const _D_CS := DuelMem.CMD_STATE


# --- Ayudas del modulo ------------------------------------------------------------------

## state ^ ((state - 1) ^ state) & 0x7f: retrocede un paso.
func _d_prev_step() -> void:
	var s := m.u32(_D_CS)
	m.set_u32(_D_CS, s ^ (((s - 1) ^ s) & 0x7f))


## Local CONCAT22(hi, lo) con los 12 bits bajos (id) cambiados por el indice de la carta.
## Devuelve la direccion de la variable local.
func _d_entry(lo: int, hi: int) -> int:
	var v := ((hi & 0xffff) << 16) | (lo & 0xffff)
	v = v ^ ((f401ad0(lo & 0xfff) ^ v) & 0xfff)
	var t := m.local(4)
	m.set_u32(t, v)
	return t


## Comprobacion de pruebas: la busqueda de la carta del comando en el estado ha fallado.
func _d_expect_found(found: int, card_id: int, what: String) -> void:
	if found == 0:
		mismatches.append("cmd %d op 0x%02x: no esta la carta %d en %s" % [
				executed, cmd_op() & 0xfff, card_id & 0xfff, what])


## FUN_00407830 (presentacion): movimiento de una carta (indice) entre dos sitios.
func _d_move(index: int, src: int, dst: int, grave_inserted: bool = false) -> void:
	present_card_motion(3, index & 0xfff, src, dst, "move", {"index": index & 0xfff,
		"card": f401a70(index & 0xfff), "from": src & 0xffff, "to": dst & 0xffff,
		"grave_inserted": grave_inserted})


# --- Manejadores: banderas de zona -------------------------------------------------------

## 0x87 FUN_00548c00
func f548c00() -> int:
	f543ee0(cmd_b(), cmd_a(), cmd_c())
	finish()
	return 0


## 0x88 FUN_00548c40: bits 11-15 de zona+0x8e = b.
func f548c40() -> int:
	var at := DuelMem.zone(cmd_player(), cmd_a() & 0xff) + 0x8e
	m.set_u16(at, (m.u16(at) & 0x7ff) | (cmd_b() << 11))
	finish()
	return 0


## 0x8c FUN_00548c90: bit 22 de la entrada de la zona = b.
func f548c90() -> int:
	var at := DuelMem.zone(cmd_player(), cmd_a())
	var v := m.u32(at)
	m.set_u32(at, v ^ (((cmd_b() << 22) ^ v) & 0x400000))
	finish()
	return 0


## 0x8a FUN_00548ce0: bits 2-5 de zona+6 = b (si hay carta).
func f548ce0() -> int:
	var zone := DuelMem.zone(cmd_player(), cmd_a())
	if (m.u32(zone) & 0xfff) != 0:
		var v := m.u8(zone + 6)
		m.set_u8(zone + 6, v ^ ((((cmd_b() & 0xff) * 4) ^ v) & 0x3c))
	finish()
	return 0


## 0x89 FUN_00548d40: limpia bits 2-5 de zona+6 y pone b en bits 11-15 de zona+0x8e.
func f548d40() -> int:
	var zone := DuelMem.zone(cmd_player(), cmd_a())
	if (m.u32(zone) & 0xfff) != 0:
		m.set_u8(zone + 6, m.u8(zone + 6) & 0xc3)
		m.set_u16(zone + 0x8e, (m.u16(zone + 0x8e) & 0x7ff) | (cmd_b() << 11))
	finish()
	return 0


## 0x8d / 0xa2 FUN_00548db0: vacia la lista de vinculos de la zona.
func f548db0() -> int:
	m.set_u16(DuelMem.zone(cmd_player(), cmd_a()) + 0x88, 0)
	finish()
	return 0


## 0x8e FUN_00548df0: pasa la lista de vinculos de la zona a a la zona b.
func f548df0() -> int:
	var p := cmd_player()
	var src := DuelMem.zone(p, cmd_a())
	var dst := DuelMem.zone(p, cmd_b())
	m.copy(dst + 0x08, src + 0x08, 0x40)
	m.copy(dst + 0x48, src + 0x48, 0x40)
	m.set_u16(dst + 0x88, m.u16(src + 0x88))
	m.set_u16(src + 0x88, 0)
	finish()
	return 0


## 0x8f: no-op en Yugi; Kaiba aun conserva su frontera explicita.
func f4039b0() -> int:
	if rules_game == "yugi": finish()
	else: return _unported(0x4039b0)
	return 0


## 0x62 FUN_00548fd0: manda al cementerio las a cartas de arriba del mazo.
func f548fd0() -> int:
	var p := cmd_player()
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s == 1:
		if cmd_a() == 0:
			finish()
			return 0
		if f542790(p, 0, _D_MV) == 0:
			finish()
			return 0
		_d_move(m.u32(_D_MV), p | 0x801a, p | 0x803c)
	elif s == 2:
		f544300(_D_MV)
		m.set_u16(0xa14f22, cmd_a() - 1)
		if cmd_a() != 0:
			_d_prev_step()
			return 0
	else:
		finish()
		return 0
	next_step()
	return 0


## 0x63 FUN_005490e0: excluye las a cartas de arriba del mazo (contador en los bits 7-13
## del estado del comando).
func f5490e0() -> int:
	var p := cmd_player()
	var s := step()
	if s == 0:
		var st := m.u32(_D_CS)
		st = st ^ (((cmd_a() << 7) ^ st) & 0x3f80)
		if (st & 0x3f80) != 0:
			m.set_u32(_D_CS, st ^ (((st + 1) ^ st) & 0x7f))
		else:
			m.set_u32(_D_CS, st & 0xefffffff)
		return 0
	if s == 1:
		if f542790(p, 0, _D_MV) != 0:
			_d_move(m.u32(_D_MV), p | 0x801a, p | 0x803e)
			next_step()
			return 0
	else:
		if s != 2:
			return 0
		if anim_busy():
			return 0
		f5443a0(_D_MV)
		var st := m.u32(_D_CS)
		st = st ^ (((((st >> 7) - 1) * 0x80) ^ st) & 0x3f80)
		m.set_u32(_D_CS, st)
		if (st & 0x3f80) != 0:
			_d_prev_step()
			return 0
	finish()
	return 0


## 0x64 FUN_00549220: saca del mazo (del propietario, bit 12 de a) la carta a|b<<16 y la
## anade a la mano del jugador del comando.
func f549220() -> int:
	var p := cmd_player()
	var e := _d_entry(cmd_a(), cmd_b())
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s != 1:
		finish()
		return 0
	var owner := (m.u32(e) >> 12) & 1
	var found := f542810(owner, e)
	_d_expect_found(found, cmd_a(), "el mazo")
	if found == 0:
		finish()
		return 0
	f544c50(p, e)
	_d_move(m.u32(e), p | 0x1a, ((((m.u8(0xa11946 + p * PS) - 1) & 0x1ff) << 5) | p | 0x16))
	next_step()
	return 0


## 0x65 FUN_00549370: saca la carta del mazo.
func f549370() -> int:
	var p := cmd_player()
	var e := _d_entry(cmd_a(), cmd_b())
	_d_expect_found(f542810(p, e), cmd_a(), "el mazo")
	present("deck_top", {"p": p})   # FUN_00403150
	finish()
	return 0


## 0x66 FUN_005493e0: del mazo a la zona de monstruo c (boca arriba, bit 1 de zona+6).
func f5493e0() -> int:
	var p := cmd_player()
	var z := cmd_c()
	var e := _d_entry(cmd_a(), cmd_b())
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s == 1:
		var found := f542810(p, e)
		_d_expect_found(found, cmd_a(), "el mazo")
		if found != 0:
			f541cb0(_D_MV, e)
			var zz := z
			if z < 10:
				zz = (z / 5) * 5
			_d_move(m.u32(_D_MV), p | 0x801a, (((((z % 5) | 0xfc00) << 4) | (zz & 0xf)) << 1) | p)
			next_step()
			return 0
	else:
		f5422b0(p, z, _D_MV, 0, 1)
	finish()
	return 0


## 0x67 FUN_00549550: del mazo al cementerio.
func f549550() -> int:
	var p := cmd_player()
	var e := _d_entry(cmd_a(), cmd_b())
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s == 1:
		var found := f542810(p, e)
		_d_expect_found(found, cmd_a(), "el mazo")
		if found != 0:
			f541cb0(_D_MV, e)
			_d_move(m.u32(_D_MV), p | 0x801a, p | 0x803c)
			next_step()
			return 0
	else:
		f544300(_D_MV)
	finish()
	return 0


## 0x68 FUN_00549660: del mazo a excluidas.
func f549660() -> int:
	var p := cmd_player()
	var e := _d_entry(cmd_a(), cmd_b())
	var s := step()
	if s == 0:
		next_step()
	elif s == 1:
		var found := f542810(p, e)
		_d_expect_found(found, cmd_a(), "el mazo")
		if found != 0:
			f541cb0(_D_MV, e)
			_d_move(m.u32(_D_MV), p | 0x801a, p | 0x803e)
			next_step()
			return 0
		finish()
	elif s == 2:
		if not anim_busy():
			f5443a0(_D_MV)
			finish()
	return 0


## 0xdd FUN_00549780: del mazo de fusion al cementerio.
func f549780() -> int:
	var p := cmd_player()
	var e := _d_entry(cmd_a(), cmd_b())
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s == 1:
		var found := f542990(p, e)
		_d_expect_found(found, cmd_a(), "el mazo de fusion")
		if found != 0:
			f541cb0(_D_MV, e)
			_d_move(m.u32(_D_MV), p | 0x8018, p | 0x803c)
			next_step()
			return 0
	else:
		f544300(_D_MV)
	finish()
	return 0


## 0x6a FUN_00549890: pone la carta encima del mazo de su propietario (bit 12 de a).
func f549890() -> int:
	var p := cmd_player()
	var e := _d_entry(cmd_a(), cmd_b())
	f542520((m.u32(e) >> 12) & 1, e)
	present("deck_top", {"p": p})   # FUN_00403150
	finish()
	return 0


## 0x6b FUN_00549900: pone la carta debajo del mazo de su propietario.
func f549900() -> int:
	var e := _d_entry(cmd_a(), cmd_b())
	f5425a0((m.u32(e) >> 12) & 1, e)
	finish()
	return 0


## 0x69 FUN_00549960: bits 12-14 de +0x10 del jugador = a.
func f549960() -> int:
	var at := 0xa11954 + cmd_player() * PS
	var v := m.u16(at)
	m.set_u16(at, v ^ (((cmd_a() << 12) ^ v) & 0x7000))
	finish()
	return 0


## 0xdc FUN_005499a0: saca la carta del mazo de fusion.
func f5499a0() -> int:
	var e := _d_entry(cmd_a(), cmd_b())
	_d_expect_found(f542990(cmd_player(), e), cmd_a(), "el mazo de fusion")
	finish()
	return 0


# --- Manejadores: cementerio y excluidas -------------------------------------------------

## 0xd2 FUN_00549a00: del cementerio a la mano (las de fusion a su mazo). El paso 0 sigue
## sin cortar con el cuerpo del paso 1 (confirmado en el desensamblado).
func f549a00() -> int:
	var p := cmd_player()
	var e := _d_entry(cmd_a(), cmd_b())
	var s := step()
	if s == 0:
		next_step()
	elif s != 1:
		f541bd0(e)
		if f541950(m.u32(_D_MV) & 0xfff) == 2:
			f5425e0(p, e)
		else:
			f544c50(p, e)
		finish()
		return 0
	_d_expect_found(f5447d0(p, e), cmd_a(), "el cementerio")
	f541cb0(_D_MV, e)
	_d_move(m.u32(_D_MV), p | 0x803c, (m.u8(0xa11946 + p * PS) << 5) | 0x16
			| ((m.u32(_D_MV) >> 12) & 1))
	next_step()
	return 0


## 0xd0 FUN_00549bc0: del cementerio a lo alto del mazo.
func f549bc0() -> int:
	var p := cmd_player()
	var ix := f401ad0(cmd_a())
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s == 1:
		var found := f544950(p, ix, _D_MV)
		_d_expect_found(found, cmd_a(), "el cementerio")
		if found != 0:
			f5447d0(p, _D_MV)
			_d_move(m.u32(_D_MV), p | 0x803c, p | 0x1a)
			next_step()
			return 0
	else:
		f541bd0(_D_MV)
		f542520(p, _D_MV)
	finish()
	return 0


## 0xd1 FUN_00549ca0: del cementerio al fondo del mazo.
func f549ca0() -> int:
	var p := cmd_player()
	var ix := f401ad0(cmd_a())
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s == 1:
		var found := f544950(p, ix, _D_MV)
		_d_expect_found(found, cmd_a(), "el cementerio")
		if found != 0:
			f5447d0(p, _D_MV)
			_d_move(m.u32(_D_MV), p | 0x803c, p | 0x1a)
			next_step()
			return 0
	else:
		f541bd0(_D_MV)
		f5425a0(p, _D_MV)
	finish()
	return 0


## 0xd4 FUN_00549d80: del cementerio a excluidas.
func f549d80() -> int:
	var p := cmd_player()
	var e := _d_entry(cmd_a(), cmd_b())
	var s := step()
	if s == 0:
		next_step()
	elif s == 1:
		_d_expect_found(f5447d0(p, e), cmd_a(), "el cementerio")
		f541cb0(_D_MV, e)
		_d_move(m.u32(_D_MV), p | 0x803c, p | 0x803e)
		next_step()
	elif s == 2:
		if not anim_busy():
			f5443a0(e)
			finish()
	return 0


## 0xd3 FUN_00549ea0: quita la carta del cementerio de su propietario.
func f549ea0() -> int:
	var e := _d_entry(cmd_a(), cmd_b())
	_d_expect_found(f5447d0((m.u32(e) >> 12) & 1, e), cmd_a(), "el cementerio")
	finish()
	return 0


## 0xd6 FUN_00549f00: devuelve el cementerio entero al mazo (de arriba abajo; las de
## fusion a su mazo). Repite los pasos 1-2 hasta vaciarlo.
func f549f00() -> int:
	var p := cmd_player()
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s == 2:
		f541bd0(_D_MV)
		if f541950(m.u32(_D_MV) & 0xfff) == 2:
			f5425e0(p, _D_MV)
		else:
			f542520(p, _D_MV)
		m.set_u32(_D_CS, (m.u32(_D_CS) & 0xffffff81) | 1)
		return 0
	if s != 1:
		finish()
		return 0
	var n := m.u16(0xa11948 + (p & 1) * PS)
	if (n & 0xff) != 0:
		f544740(p, (n & 0xff) - 1, _D_MV)
		var dst := (((0 if f541950(m.u32(_D_MV) & 0xfff) == 2 else 1) + 0xc) << 1) | (p & 1)
		_d_move(m.u32(_D_MV), (p & 1) | 0x803c, dst)
		next_step()
		return 0
	m.set_u32(_D_CS, (m.u32(_D_CS) & 0xffffff8a) | 10)
	return 0


## 0xd5 FUN_0054a070: del cementerio del rival a la mano del jugador del comando.
func f54a070() -> int:
	var p := cmd_player()
	var other := 1 - p
	var ix := f401ad0(cmd_a())
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s != 1:
		m.set_u32(_D_MV, m.u32(_D_MV) | 0x40000)
		f544c50(p, _D_MV)
		finish()
		return 0
	_d_expect_found(f544950(other, ix, _D_MV), cmd_a(), "el cementerio del rival")
	f544830(other, ix)
	_d_move(m.u32(_D_MV), (other & 1) | 0x803c, (m.u8(0xa11946 + p * PS) << 5) | (p & 1) | 0x16)
	next_step()
	return 0


## 0xde FUN_0054a1c0: de excluidas (del propietario, bit 12 de a) al cementerio.
func f54a1c0() -> int:
	var owner := (cmd_a() & 0x1000) >> 12
	var e := _d_entry(cmd_a(), cmd_b())
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s != 1:
		f544300(e)
		finish()
		return 0
	f544b20(owner, e)
	f541cb0(_D_MV, e)
	_d_move(m.u32(_D_MV), owner | 0x803e, owner | 0x803c)
	next_step()
	return 0


## 0xd7 FUN_0054a2c0: manda la carta al cementerio de su propietario (sin sacarla de otro sitio).
func f54a2c0() -> int:
	f544300(_d_entry(cmd_a(), cmd_b()))
	finish()
	return 0


## 0xd8 FUN_0054a310: limpia el bit 24 de la carta a del cementerio.
func f54a310() -> int:
	var at := 0xa12238 + cmd_player() * PS + cmd_a() * 4
	m.set_u32(at, m.u32(at) & 0xfeffffff)
	finish()
	return 0


## 0xd9 FUN_0054a350: de la posicion a del cementerio a la primera zona de magia/trampa
## libre del rival (FUN_00543570; la zona se guarda en los bits 7-13 del estado).
func f54a350() -> int:
	var p := cmd_player()
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s != 1:
		f5423a0(1 - p, ((m.u32(_D_CS) >> 7) & 0x7f) - 5, _D_MV, 1)
		var o := (1 - p) & 0xff
		f543e20(((((m.u32(_D_MV) >> 25) & 7) << 8) | o) & 0xffff,
				((((m.u32(_D_CS) >> 7) & 0x7f) << 8) | o) & 0xffff, 10)
		finish()
		return 0
	f544740(p, cmd_a(), _D_MV)
	m.set_u32(_D_MV, m.u32(_D_MV) & 0xfeffffff)
	var r := f543570(1 - p)
	var st := m.u32(_D_CS)
	m.set_u32(_D_CS, st ^ (((r << 7) ^ st) & 0x3f80))
	_d_move(m.u32(_D_MV), (p & 1) | 0x803c,
			((((m.u32(_D_CS) >> 7) & 0x7f) << 5) | ((0xff - p) & 1) | 0x800a))
	next_step()
	return 0


## 0xda FUN_0054a4a0: limpia el bit 28 de la carta a del cementerio.
func f54a4a0() -> int:
	var at := 0xa12238 + cmd_player() * PS + cmd_a() * 4
	m.set_u32(at, m.u32(at) & 0xefffffff)
	finish()
	return 0


## 0xdb FUN_0054a4e0: marca (bit 23) la carta a|b<<16 en el cementerio.
func f54a4e0() -> int:
	var p := cmd_player()
	var q := p * PS
	var v := (cmd_b() << 16) | cmd_a()
	v = v ^ ((f401ad0(cmd_a() & 0xfff) ^ v) & 0xfff)
	if m.u8(0xa11948 + q) != 0:
		var i := 0
		while m.u32(0xa12238 + q + i * 4) != v:
			i += 1
			if m.u8(0xa11948 + q) <= i:
				_d_expect_found(0, cmd_a(), "el cementerio")
				finish()
				return 0
		var at := 0xa12238 + q + i * 4
		m.set_u32(at, m.u32(at) | 0x800000)
	else:
		_d_expect_found(0, cmd_a(), "el cementerio")
	finish()
	return 0


# --- Manejadores: mano ------------------------------------------------------------------

## 0xc0 FUN_0054a590: descarta la carta a de la mano al cementerio (bit 20 = c). Con b == 0
## el original no avanza ni termina el comando.
func f54a590() -> int:
	var p := cmd_player()
	var a := cmd_a()
	var c := cmd_c()
	if cmd_b() == 0:
		return 0
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s == 1:
		var slot := 0xa11fb8 + (p & 1) * PS + a * 4
		f541cb0(_D_MV, slot)
		m.set_u32(slot, m.u32(slot) & 0xfffff000)
		_d_move(m.u32(_D_MV), ((a & 0x1ff) << 5) | (p & 1) | 0x8016,
				((m.u32(_D_MV) >> 12) & 1) | 0x803c)
		next_step()
		return 0
	if s == 2:
		f544e00(p)
		var mv := m.u32(_D_MV)
		m.set_u32(_D_MV, mv ^ (((c << 20) ^ mv) & 0x100000))
		f544300(_D_MV)
	finish()
	return 0


## 0xc1 FUN_0054a6c0: excluye la carta a de la mano (bit 20 = c). Con b == 0 el original
## no avanza ni termina el comando.
func f54a6c0() -> int:
	var p := cmd_player()
	var a := cmd_a()
	var c := cmd_c()
	if cmd_b() == 0:
		return 0
	var s := step()
	if s == 0:
		next_step()
	elif s == 1:
		var slot := 0xa11fb8 + (p & 1) * PS + a * 4
		f541cb0(_D_MV, slot)
		m.set_u32(slot, m.u32(slot) & 0xfffff000)
		_d_move(m.u32(_D_MV), ((a & 0x1ff) << 5) | (p & 1) | 0x8016,
				((m.u32(_D_MV) >> 12) & 1) | 0x803e)
		next_step()
	elif s == 2:
		if not anim_busy():
			if cmd_b() != 0:
				f544e00(p)
			var mv := m.u32(_D_MV)
			m.set_u32(_D_MV, mv ^ (((c << 20) ^ mv) & 0x100000))
			f5443a0(_D_MV)
			finish()
	return 0


## 0xc3 FUN_0054a810: devuelve la carta a de la mano al mazo de su propietario (b != 0
## encima, b == 0 debajo). El paso 0 sigue sin cortar con el paso 1 (desensamblado).
func f54a810() -> int:
	var p := cmd_player()
	var a := cmd_a()
	var s := step()
	if s == 0:
		next_step()
	elif s != 1:
		if s == 2:
			f544e00(p)
			var owner := (m.u32(_D_MV) >> 12) & 1
			if cmd_b() != 0:
				f542520(owner, _D_MV)
				finish()
				return 0
			f5425a0(owner, _D_MV)
		finish()
		return 0
	var slot := 0xa11fb8 + (p & 1) * PS + a * 4
	f541cb0(_D_MV, slot)
	m.set_u32(slot, m.u32(slot) & 0xfffff000)
	_d_move(m.u32(_D_MV), ((a & 0x1ff) << 5) | p | 0x8016,
			((1 if cmd_b() == 0 else 0) << 5) | ((m.u32(_D_MV) >> 12) & 1) | 0x1a)
	next_step()
	return 0


## 0xc2 FUN_0054a960: quita la carta de la mano.
func f54a960() -> int:
	var e := _d_entry(cmd_a(), cmd_b())
	_d_expect_found(f544d10(cmd_player(), e), cmd_a(), "la mano")
	finish()
	return 0


## 0xca FUN_0054a9c0: compacta la mano.
func f54a9c0() -> int:
	f544e00(cmd_player())
	finish()
	return 0


## 0xcb FUN_0054a9f0: anade la carta a la mano.
func f54a9f0() -> int:
	f544c50(cmd_player(), _d_entry(cmd_a(), cmd_b()))
	finish()
	return 0


## 0xce FUN_0054aa50: saca la carta a de la mano (FUN_00544610; compacta si b != 0).
func f54aa50() -> int:
	var p := cmd_player()
	var a := cmd_a()
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s != 1:
		if s == 2:
			if cmd_b() != 0:
				f544e00(p)
			f544610(_D_MV)
		finish()
		return 0
	var slot := 0xa11fb8 + p * PS + a * 4
	f541cb0(_D_MV, slot)
	m.set_u32(slot, m.u32(slot) & 0xfffff000)
	_d_move(m.u32(_D_MV), ((a & 0x1ff) << 5) | p | 0x8016, ((m.u32(_D_MV) >> 12) & 1) | 0x3e)
	next_step()
	return 0


## 0xcf FUN_0054ab60: de la posicion a de excluidas a la mano.
func f54ab60() -> int:
	var p := cmd_player()
	var a := cmd_a()
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s != 1:
		if s == 2:
			f544c50(p, 0xa124b8 + p * PS + a * 4)
			f544a80(p, a)
		finish()
		return 0
	_d_move(1, p | 0x1e, (m.u8(0xa11946 + p * PS) << 5) | p | 0x16)
	next_step()
	return 0


## 0xc7 FUN_0054ac50: intercambia la carta b de la mano del rival con la carta a de la mano
## del jugador del comando.
func f54ac50() -> int:
	var p := cmd_player()
	var o := (-p - 1) & 1
	match step():
		0:
			f544c50(p, 0xa11fb8 + o * PS + cmd_b() * 4)
			_d_move(1, ((cmd_b() & 0x1ff) << 5) | o | 0x16,
					(((m.u8(0xa11946 + p * PS) - 1) & 0x1ff) << 5) | p | 0x16)
			next_step()
		1:
			f544d10(1 - p, 0xa11fb8 + o * PS + cmd_b() * 4)
			next_step()
		2:
			f544c50(1 - p, 0xa11fb8 + p * PS + cmd_a() * 4)
			_d_move(1, ((cmd_a() & 0x1ff) << 5) | p | 0x16,
					(((m.u8(0xa11946 + o * PS) - 1) & 0x1ff) << 5) | o | 0x16)
			next_step()
		3:
			f544d10(p, 0xa11fb8 + p * PS + cmd_a() * 4)
			next_step()
		_:
			finish()
	return 0


## 0xcc FUN_0054af20: 0xc0 con c = 1.
func f54af20() -> int:
	m.set_u16(0xa14f26, 1)
	f54a590()
	return 0


## 0xcd FUN_0054af30: 0xc1 con c = 1.
func f54af30() -> int:
	m.set_u16(0xa14f26, 1)
	f54a6c0()
	return 0


# --- Manejadores: zonas ------------------------------------------------------------------

## 0xb0 FUN_0054af40: marca (bit 2, y bit 3 si a != 0) la entrada actual de la tabla de
## 0xa15e5c (0x14 bytes por entrada; indice u16 en 0xa15fc0). PENDIENTE: que es esa tabla.
func f54af40() -> int:
	if ((m.u8(0xa16181) & 1) == 0 or (m.u8(0xa133f2) & 1) == 0) and m.u16(0xa15fc0) > 1:
		var at := 0xa15e5c + m.u16(0xa15fc0) * 0x14
		m.set_u8(at, m.u8(at) | 4)
		if cmd_a() != 0:
			m.set_u16(at, m.u16(at) | 8)
	finish()
	return 0


## 0x92 FUN_0054afa0: pone banderas (bits 14-17 y 29-30) en la entrada de la zona a.
func f54afa0() -> int:
	var b := cmd_b() & 0xff
	var a := cmd_a()
	var p := cmd_player()
	var zone := DuelMem.zone(p, a)
	if (b & 1) != 0:
		m.set_u32(zone, m.u32(zone) | 0x4000)
	if (b & 2) != 0:
		m.set_u32(zone, m.u32(zone) | 0x8000)
	if (b & 4) != 0:
		m.set_u32(zone, m.u32(zone) | 0x10000)
	if (b & 8) != 0:
		m.set_u32(zone, m.u32(zone) | 0x20000)
	if (b & 0x10) != 0:
		m.set_u8(zone + 7, m.u8(zone + 7) | 0x20)
	if (b & 0x20) != 0:
		m.set_u8(zone + 7, m.u8(zone + 7) | 0x40)
	if (m.u8(0xa133f2) & 0xe) == 6 and p == (m.u8(0xa133f2) & 1):
		var at := 0xa1195a + p * PS
		m.set_u16(at, m.u16(at) & ~(1 << (a & 0x1f)))
	finish()
	return 0


## 0x93 FUN_0054b050: quita esas banderas (en el paso 1).
func f54b050() -> int:
	var b := cmd_b() & 0xff
	var zone := DuelMem.zone(cmd_player(), cmd_a())
	if step() != 0:
		if (b & 1) != 0:
			m.set_u32(zone, m.u32(zone) & 0xffffbfff)
		if (b & 2) != 0:
			m.set_u32(zone, m.u32(zone) & 0xffff7fff)
		if (b & 4) != 0:
			m.set_u32(zone, m.u32(zone) & 0xfffeffff)
		if (b & 8) != 0:
			m.set_u32(zone, m.u32(zone) & 0xfffdffff)
		if (b & 0x10) != 0:
			m.set_u8(zone + 7, m.u8(zone + 7) & 0xdf)
		if (b & 0x20) != 0:
			m.set_u8(zone + 7, m.u8(zone + 7) & 0xbf)
		finish()
		return 0
	next_step()
	return 0


## 0x94 FUN_0054b0f0: bit 12 de zona+6 = b.
func f54b0f0() -> int:
	var at := DuelMem.zone(cmd_player(), cmd_a()) + 6
	var v := m.u16(at)
	m.set_u16(at, v ^ (((cmd_b() << 12) ^ v) & 0x1000))
	finish()
	return 0


## 0x96 FUN_0054b140: de la zona a a lo alto del mazo de (jugador - 1) & 1.
func f54b140() -> int:
	var p := cmd_player()
	var a := cmd_a()
	var zone := DuelMem.zone(p, a)
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s != 1:
		f542520(p - 1, _D_MV)
		m.set_u32(zone, m.u32(zone) & 0xfffff000)
		finish()
		return 0
	f541cb0(_D_MV, zone)
	var src := ((((m.u16(zone + 6) << 9) & 0xffff) | (a & 0x1ff)) << 5) | p
	var index := m.u32(_D_MV) & 0xfff
	m.set_u32(_D_MV, m.u32(_D_MV) | 0x20000)
	_d_move(index, src, ((p - 1) & 1) | 0x801a)
	next_step()
	return 0


## 0x9a FUN_0054b270: bit 4 de zona+0x8e.
func f54b270() -> int:
	var at := DuelMem.zone(cmd_player(), cmd_a()) + 0x8e
	m.set_u8(at, m.u8(at) | 0x10)
	finish()
	return 0


## 0x99 FUN_0054b2b0: bit 2 de zona+0x8e = b.
func f54b2b0() -> int:
	var at := DuelMem.zone(cmd_player(), cmd_a()) + 0x8e
	var v := m.u16(at)
	m.set_u16(at, v ^ (((cmd_b() << 2) ^ v) & 4))
	finish()
	return 0


## 0x98 FUN_0054b300: bit 3 de zona+0x8e = b.
func f54b300() -> int:
	var at := DuelMem.zone(cmd_player(), cmd_a()) + 0x8e
	var v := m.u16(at)
	m.set_u16(at, v ^ (((cmd_b() << 3) ^ v) & 8))
	finish()
	return 0


## 0xa3 FUN_0054b350: bit 9 de zona+6 = b.
func f54b350() -> int:
	var at := DuelMem.zone(cmd_player(), cmd_a()) + 6
	var v := m.u16(at)
	m.set_u16(at, v ^ (((cmd_b() << 9) ^ v) & 0x200))
	finish()
	return 0


## 0xa4 FUN_0054b3a0: bit 1 de zona+0x8e = b; a = zona << 8 | jugador.
func f54b3a0() -> int:
	var a := cmd_a()
	var at := DuelMem.zone(a & 1, a >> 8) + 0x8e
	var v := m.u16(at)
	m.set_u16(at, v ^ (((cmd_b() << 1) ^ v) & 2))
	finish()
	return 0


## 0xa6 FUN_0054b3e0: escribe la carta b|c<<16 en la zona a (sin mas).
func f54b3e0() -> int:
	var e := _d_entry(cmd_b(), cmd_c())
	f541cb0(DuelMem.zone(cmd_player(), cmd_a() & 0xff), e)
	finish()
	return 0


## 0xa9 FUN_0054b460: mueve el contenido de la zona a a la zona b (boca abajo).
func f54b460() -> int:
	var p := cmd_player()
	if step() != 0:
		finish()
		return 0
	var src := DuelMem.zone(p, cmd_a())
	var dst := DuelMem.zone(p, cmd_b())
	m.copy(dst, src, 0x94)
	m.set_u16(dst + 6, (m.u16(dst + 6) & 0xfffd) | 1)
	m.set_u32(src, m.u32(src) & 0xfffff000)
	next_step()
	return 0


## 0xaa FUN_0054b500: coloca la carta b|c<<16 en la zona de monstruo (a & 0xff); bit 8 de a
## = boca arriba (forzado para ids 0x780-0x7cf); las no monstruo marcan el bit 0 de +0x8e.
func f54b500() -> int:
	var p := cmd_player()
	var a := cmd_a()
	var face := (a >> 8) & 1
	var e := _d_entry(cmd_b(), cmd_c())
	var cid := f401a70(m.u32(e) & 0xfff) & 0xffff
	if cid > 0x77f:
		if (f401a70(m.u32(e) & 0xfff) & 0xffff) < 2000:
			face = 1
	if step() != 0:
		finish()
		return 0
	f5422b0(p, a & 0xff, e, 1, face)
	if ((f401a20(m.u32(e) & 0xfff) >> 20) & 0x1f) > 0x14:
		var at := DuelMem.zone(p, a & 0xff) + 0x8e
		m.set_u8(at, m.u8(at) | 1)
	next_step()
	return 0


## 0xab FUN_0054b610: saca la carta de la zona a (FUN_00544450).
func f54b610() -> int:
	var p := cmd_player()
	var a := cmd_a()
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s != 1:
		f544450(_D_MV, a)
		finish()
		return 0
	var zone := DuelMem.zone(p, a)
	f541cb0(_D_MV, zone)
	m.set_u32(zone, m.u32(zone) & 0xfffff000)
	_d_move(m.u32(_D_MV), ((((a & 0x1ff) | 0xfc00) << 5) | p) & 0xffff,
			((m.u32(_D_MV) >> 12) & 1) | 0x3e)
	next_step()
	return 0


## 0xac FUN_0054b710: FUN_00544520(jugador, a) tras la animacion.
func f54b710() -> int:
	var p := cmd_player()
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s != 1:
		f544520(p, cmd_a())
		finish()
		return 0
	_d_move(1, p | 0x3e, ((cmd_a() & 0x1ff) << 5) | p)
	next_step()
	return 0


## 0xa7 FUN_0054b7c0: marca (bit 20) la carta de la zona a y la manda al cementerio
## (b == 0) o a excluidas (b != 0) con FUN_00543610.
func f54b7c0() -> int:
	var p := cmd_player()
	var a := cmd_a()
	var b := cmd_b()
	if step() != 0:
		finish()
		return 0
	var zone := DuelMem.zone(p, a)
	m.set_u32(zone, m.u32(zone) | 0x100000)
	f541cb0(_D_MV, zone)
	f543610(p, a, b)
	var src := ((((m.u16(zone + 6) << 9) & 0xffff) | (a & 0x1ff)) << 5) | p
	var dst := ((((1 if b != 0 else 0) + 0xe) | 0xc010) << 1) | ((m.u32(_D_MV) >> 12) & 1)
	_d_move(m.u32(_D_MV), src, dst, b == 0)
	next_step()
	return 0


## 0xa8 FUN_0054b8c0: bit 15 de zona+6 = b.
func f54b8c0() -> int:
	var at := DuelMem.zone(cmd_player(), cmd_a()) + 6
	m.set_u16(at, (m.u16(at) & 0x7fff) | (cmd_b() << 15))
	finish()
	return 0


# --- Manejadores: banderas globales y del jugador ---------------------------------------

## 0x15-0x1b FUN_0054b950: un bit de 0xa133ec (segun el comando) = bit 0 de a.
func f54b950() -> int:
	var a := cmd_a()
	var v := m.u16(0xa133ec)
	match cmd_op() & 0xfff:
		0x15:
			v ^= (((a & 0xff) << 8) ^ v) & 0x100
		0x16:
			v ^= ((a << 9) ^ v) & 0x200
		0x17:
			v ^= ((a << 11) ^ v) & 0x800
		0x18:
			v ^= ((a << 10) ^ v) & 0x400
		0x19:
			v ^= ((a << 6) ^ v) & 0x40
		0x1a:
			v ^= ((a << 5) ^ v) & 0x20
		0x1b:
			v ^= ((a << 7) ^ v) & 0x80
		_:
			finish()
			return 0
	m.set_u16(0xa133ec, v)
	finish()
	return 0


## 0x44 FUN_0054c2a0: bit 2 de +0x0c del jugador.
func f54c2a0() -> int:
	var at := 0xa11950 + cmd_player() * PS
	m.set_u32(at, m.u32(at) | 4)
	finish()
	return 0


## 0x45 FUN_0054c2d0: bit 1 de +0x0c del jugador.
func f54c2d0() -> int:
	var at := 0xa11950 + cmd_player() * PS
	m.set_u32(at, m.u32(at) | 2)
	finish()
	return 0


## 0x46 FUN_0054c300: bit 3 de +0x0c del jugador.
func f54c300() -> int:
	var at := 0xa11950 + cmd_player() * PS
	m.set_u32(at, m.u32(at) | 8)
	finish()
	return 0


## 0x47 FUN_0054c330: bit 6 de +0x08 del jugador = a.
func f54c330() -> int:
	var at := 0xa1194c + cmd_player() * PS
	var v := m.u16(at)
	m.set_u16(at, v ^ (((cmd_a() << 6) ^ v) & 0x40))
	finish()
	return 0


## 0x48 FUN_0054c370: bit 13 de +0x06 del jugador = a.
func f54c370() -> int:
	var at := 0xa1194a + cmd_player() * PS
	var v := m.u16(at)
	m.set_u16(at, v ^ (((cmd_a() << 13) ^ v) & 0x2000))
	finish()
	return 0


## 0x49 FUN_0054c3b0: bits 11 (a) y 12 (b) de +0x06 del jugador.
func f54c3b0() -> int:
	var at := 0xa1194a + cmd_player() * PS
	m.set_u16(at, ((((cmd_b() & 1) << 1) | (cmd_a() & 1)) << 11) | (m.u16(at) & 0xe7ff))
	finish()
	return 0


## 0x4a FUN_0054c400: bits 14-15 de +0x06 del jugador = a (turnos de excluidas).
func f54c400() -> int:
	var at := 0xa1194a + cmd_player() * PS
	m.set_u16(at, (m.u16(at) & 0x3fff) | (cmd_a() << 14))
	finish()
	return 0


## 0x1c FUN_0054c440: bit 12 de 0xa133ec.
func f54c440() -> int:
	m.set_u8(0xa133ed, m.u8(0xa133ed) | 0x10)
	finish()
	return 0


## 0x1d FUN_0054c460: bit 13 de 0xa133ec = a.
func f54c460() -> int:
	var v := m.u16(0xa133ec)
	m.set_u16(0xa133ec, v ^ (((cmd_a() << 13) ^ v) & 0x2000))
	finish()
	return 0


## 0x4b FUN_0054c490: contador de 3 bits (5-7) de +0x12 del jugador: a != 0 suma 1
## (modulo 8), a == 0 resta 1 sin bajar de 0.
func f54c490() -> int:
	var at := 0xa11956 + cmd_player() * PS
	var v := m.u16(at)
	if cmd_a() != 0:
		var lo := v & 0xff
		m.set_u16(at, ((((lo & 0xe0) + 0x20) ^ lo) & 0xe0) ^ v)
	elif ((v >> 5) & 7) != 0:
		m.set_u16(at, (((((v >> 5) - 1) * 0x20) ^ v) & 0xe0) ^ v)
	finish()
	return 0


## 0x4c FUN_0054c530: bit 8 de +0x12 del jugador = a.
func f54c530() -> int:
	var at := 0xa11956 + cmd_player() * PS
	var v := m.u16(at)
	m.set_u16(at, v ^ ((((cmd_a() & 0xff) << 8) ^ v) & 0x100))
	finish()
	return 0


## 0x09 FUN_0054c6a0
func f54c6a0() -> int:
	m.set_u8(0xa161a0, m.u8(0xa161a0) | 1)
	f53f7e0(cmd_player(), cmd_a(), cmd_b())
	finish()
	return 0


# --- Auxiliares ----------------------------------------------------------------------------

## FUN_0054c8a0: por cada vinculo de tipo 2 de la zona (p1, z) que apunte a (pl, zz), emite
## 0x87 (FUN_0054c880) con el vinculo y la zona de origen.
func f54c8a0(p1: int, z: int, pl: int, zz: int) -> int:
	var zone := 0xa1195c + (p1 & 1) * PS + z * 0x94
	var i := 0
	while i < m.u16(zone + 0x88):
		var link := m.u16(zone + 0x08 + i * 2)
		if m.u8(zone + 0x48 + i * 2) == 2 and (link & 0xff) == pl and (link >> 8) == zz:
			f54c880(pl, link, ((z & 0xff) << 8) | (p1 & 0xff), 2)
		i += 1
	return 0


## FUN_0054ca50: al dejar la zona (p, z), destruye (FUN_0054e250) las cartas vinculadas
## segun el tipo de vinculo (1/10 si siguen en el campo, 5/6 siempre, 2 solo ciertos ids;
## `flag` habilita los ids 0x15c, 0x447 y 0x589). Si z es de monstruo, avisa con 0x87 de los
## vinculos de tipo 2 que apuntaban a ella.
func f54ca50(p: int, z: int, flag: int) -> int:
	var zone := DuelMem.zone(p, z)
	var i := 0
	while i < m.u16(zone + 0x88):
		var link := m.u16(zone + 0x08 + i * 2)
		var lp := link & 0xff
		var lz := (link >> 8) & 0xff
		var other := DuelMem.zone(lp & 1, lz)
		var ix := m.u16(other) & 0xfff
		var kill := false
		match m.u8(zone + 0x48 + i * 2):
			1, 10:
				kill = ix != 0
			2:
				var cid := f401a70(ix) & 0xffff
				if cid == 0x4dc:
					kill = (m.u8(other + 0x8f) & 4) == 0
				elif cid == 0x15c or cid == 0x447 or cid == 0x589:
					kill = (m.u8(other + 0x8f) & 4) == 0 and flag != 0
			5, 6:
				kill = true
		if kill:
			f54e250(lp, lz, 1)
		i += 1
	if z < 5:
		for a in 2:
			for b in 5:
				f54c8a0(a, b, p, z)
	return 0


## FUN_0054cbb0: destruye las cartas boca arriba de p con ese id (las 11 zonas).
func f54cbb0(p: int, card_id: int) -> int:
	for z in 11:
		var zone := DuelMem.zone(p, z)
		if (m.u16(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 2) != 0:
			if s16(f401a70(m.u16(zone) & 0xfff)) == s16(card_id):
				f54e250(p, z, 1)
	return 0
