class_name DuelPortA
extends DuelPrims
## Modulo del porte del motor de duelo (ver docs/duel/PORTING.md).


# --- Ayudas del modulo ----------------------------------------------------------------------

## Avanza el paso borrando el contador de los bits 7-13: (s + 1) & 0x7f | s & 0xffffc000.
func _a_step_clear() -> void:
	var s := m.u32(DuelMem.CMD_STATE)
	m.set_u32(DuelMem.CMD_STATE, ((s + 1) & 0x7f) | (s & 0xffffc000))


## Avanza el paso borrando el contador de los bits 21-27: s &= 0xf01fffff; s ^ ((s+1) ^ s) & 0x7f.
func _a_step_clear_hi() -> void:
	var s := m.u32(DuelMem.CMD_STATE) & 0xf01fffff
	m.set_u32(DuelMem.CMD_STATE, s ^ (((s + 1) ^ s) & 0x7f))


## Espera por fotogramas con el contador de los bits 7-13: un incremento por fotograma, como el
## original (0x43 espera 11 y 0x7a 15 antes de seguir; el ritmo del duelo depende de ello).
func _a_wait_lo(limit: int) -> void:
	var s := m.u32(DuelMem.CMD_STATE)
	s = s ^ ((((s & 0xffffff80) + 0x80) ^ s) & 0x3f80)
	m.set_u32(DuelMem.CMD_STATE, s)
	if (s & 0x3f80) > limit:
		next_step()


## Igual con el contador de los bits 21-27 (hasta pasar de 0xffffff).
func _a_wait_hi() -> void:
	var s := m.u32(DuelMem.CMD_STATE)
	s = s ^ ((((s & 0xffe00000) + 0x200000) ^ s) & 0xfe00000)
	m.set_u32(DuelMem.CMD_STATE, s)
	if (s & 0xfe00000) > 0xffffff:
		_a_step_clear_hi()


## 412f20(p,14)+0x10: carta que muestra el objeto del cementerio.
## La cima visual puede preceder a la escritura logica de una llegada.
func _a_grave_top(p: int) -> int:
	return maxi(visual_card_index(p, 14), 0)


# --- Reacciones (bust-ups) ------------------------------------------------------------------

## FUN_00401ca0: crea el bust-up de reaccion a una carta jugada. Solo presentacion (usa su
## propio generador Mersenne Twister, FUN_00531140, que no es el rand() del duelo).
func f401ca0(p: int, card_id: int, extra: Dictionary = {}) -> int:
	present("reaction_card", {"p": p, "card": card_id}.merged(extra))
	return 0


## FUN_004024c0: bust-up de reaccion a un cambio de LP. Solo presentacion.
func f4024c0(p: int, _a2: int, delta: int) -> int:
	present("reaction_lp", {"p": p, "delta": delta})
	return 0


## FUN_00402610: reaccion a una carta si la partida no es de tipo 6 (llama por la tabla de
## 0x59a4ac, que apunta a FUN_00401ca0).
func f402610(p: int, card_id: int, extra: Dictionary = {}) -> int:
	if game_mode != 6:
		f401ca0(p, card_id, extra)
	return 0


## FUN_004026b0: reaccion a un cambio de LP si la partida no es de tipo 6 (tabla de 0x59a4c4,
## que apunta a FUN_004024c0).
func f4026b0(p: int, delta: int) -> int:
	if game_mode != 6:
		f4024c0(p, 0, delta)
	return 0


# --- Manejadores de comando -----------------------------------------------------------------

## 0x7e FUN_004028d0: excluye la carta del comando (a = carta en bits 0-11, resto banderas).
func f4028d0() -> int:
	var p := cmd_player()
	var entry := (cmd_b() << 16) | cmd_a()
	entry = entry ^ ((f401ad0(cmd_a() & 0xfff) ^ entry) & 0xfff)
	var s := step()
	if s == 0:
		present("card_to_banish", {"p": p, "card": f401a70(entry & 0xfff), "c": cmd_c()})
		var tmp := m.local(4)
		m.set_u32(tmp, entry)
		if (entry & 0xfff) != 0:
			f5443a0(tmp)
		next_step()
	elif s == 1:
		# FUN_00437860: espera a los objetos visuales.
		if not anim_busy(): finish()
	return 0


## 0xdf FUN_00402a00: sube al tope del cementerio la carta a (si no es ya la de arriba).
func f402a00() -> int:
	var p := cmd_player()
	var index := f401ad0(cmd_a()) & 0xffff
	var s := step()
	if s == 0:
		if _a_grave_top(p) != index:
			f544890(p, index)
			present("grave_top", {"p": p, "card": cmd_a()})
			# 5af76c+0x38, metodo +0x24: la carta queda en el panel de detalle.
			present("detail", {"card": f401a70(index)})
		next_step()
	elif s != 1:
		return 0
	# FUN_004138b0: espera de animacion.
	finish()
	return 0


## 0x34 FUN_00402b30: presentacion (FUN_0040cc00/0040cc40); limpia el bit 0 de 0xa161a0.
func f402b30() -> int:
	if step() == 0:
		m.set_u8(0xa161a0, m.u8(0xa161a0) & 0xfe)
		present("cmd34", {"p": cmd_player(), "a": cmd_a()})
		next_step()
	# FUN_0040cc90: espera de animacion.
	finish()
	return 0


## 0x57 FUN_00402c00: solo presentacion (FUN_00465720).
func f402c00() -> int:
	f465720(cmd_player(), cmd_a())
	finish()
	return 0


## 0x58 FUN_00402c30: solo presentacion (FUN_00465740 con zona a + b).
func f402c30() -> int:
	if step() == 0:
		f465740(cmd_player(), cmd_b() + cmd_a())
		next_step()
	# FUN_00464bf0: espera de animacion.
	finish()
	return 0


## 0x59 FUN_00402c90: solo presentacion (FUN_00465760).
func f402c90() -> int:
	f465760(cmd_player(), cmd_a(), cmd_b())
	finish()
	return 0


## 0x80 FUN_00402d30: voltea la carta de la zona a (bit 1 de las banderas). Si queda boca
## arriba recibe numero de colocacion; si queda boca abajo se limpian banderas y algunas
## cartas (0x62, 0x1cd, 0x458, 0x45c) marcan el bit 4 del byte +7.
func f402d30() -> int:
	var p := cmd_player()
	var zone := DuelMem.zone(p, cmd_a())
	if (m.u32(zone) & 0xfff) == 0:
		finish()
		return 0
	var s := step()
	if s == 0:
		if p != 0 and cmd_c() != 0:
			present("sound", {"id": 0x10000047})
		next_step()
	elif s == 1:
		present("flip", {"p": p, "zone": cmd_a(), "flags": m.u8(zone + 6)})
		next_step()
	elif s == 2:
		var f := m.u16(zone + 6)
		f = f ^ ((((~(f >> 1)) << 1) ^ f) & 2)
		m.set_u16(zone + 6, f)
		if (f & 2) != 0:
			m.set_u16(zone + 4, m.u16(DuelMem.PLACE_SEQ))
			m.set_u16(DuelMem.PLACE_SEQ, m.u16(DuelMem.PLACE_SEQ) + 1)
			finish()
			return 0
		m.set_u16(zone + 6, f & 0xfe03)
		var cid := f401a70(m.u32(zone) & 0xfff) & 0xffff
		if cid == 0x458 or cid == 0x62 or cid == 0x1cd or cid == 0x45c:
			m.set_u8(zone + 7, m.u8(zone + 7) | 0x10)
		finish()
	return 0


## 0x40 FUN_00402f20: los LP del jugador pasan a 0 y se marca el fin (0xa114b5 |= 0x41).
func f402f20() -> int:
	var p := cmd_player()
	m.set_u16(0xa11944 + (p & 1) * PS, 0)
	present("lp_zero", {"p": p})
	m.set_u8(0xa114b5, m.u8(0xa114b5) | 0x41)
	finish()
	return 0


## 0x11 FUN_00402fa0: copia los 4 bits bajos de a en 0xa133ec (presentacion aparte).
func f402fa0() -> int:
	var a := cmd_a()
	var v := m.u16(0xa133ec)
	m.set_u16(0xa133ec, v ^ (((v & 0xff) ^ a) & 0xf))
	if step() == 0:
		next_step()
		present("cmd11", {"a": a})
		return 0
	# Espera del objeto visual de 0x5af76c + 0x2bc.
	finish()
	return 0


## FUN_00403150: actualiza el objeto visual del mazo de p con la carta de arriba. Solo
## presentacion.
func f403150(p: int) -> int:
	present("deck_top", {"p": p & 1})
	return 0


## 0xb5 FUN_00403180: levanta la carta de la zona (a >> 8) del jugador (a & 1): la copia en
## 0xa15730 y vacia la zona.
func f403180() -> int:
	var a := cmd_a()
	var z := a >> 8
	var zone := DuelMem.zone(a & 1, z)
	var s := step()
	if s == 0:
		next_step()
		return 0
	if s != 1:
		m.clear(zone, 0x94)
		finish()
		return 0
	f541cb0(DuelMem.MOVING_CARD, zone)
	present("zone_lift", {"p": a & 1, "zone": z, "b": cmd_b(),
			"card": f401a70(m.u32(DuelMem.MOVING_CARD) & 0xfff)})
	next_step()
	return 0


## 0x21 FUN_00403420: animacion de barajar la mano (mueve el cursor por las cartas durante
## 0x21 fotogramas). Solo presentacion; con menos de 2 cartas termina sin mas.
func f403420() -> int:
	var p := cmd_player()
	if m.u8(0xa11946 + p * PS) >= 2:
		present("hand_shuffle", {"p": p})
	finish()
	return 0


## 0x8b FUN_004034c0: suma b al contador de los bits 2-5 de las banderas de la zona a
## (maximo 15), solo si413170 devuelve objeto. Espera4138b0 despues de actualizarlo.
func f4034c0() -> int:
	var p := cmd_player()
	var z := cmd_a()
	var zone := DuelMem.zone(p, z)
	if (m.u32(zone) & 0xfff) == 0:
		finish()
		return 0
	var s := step()
	if s == 0:
		if visual_card_index(p, z) >= 0:
			var f := m.u16(zone + 6)
			var v := ((f >> 2) & 0xf) + cmd_b()
			if v >= 0x10:
				v = 0xf
			m.set_u16(zone + 6, f ^ (((v * 4) ^ f) & 0x3c))
			present("zone_counter", {"p": p, "zone": z, "counter_type": 3})
		next_step()
	elif s == 1:
		# FUN_004138b0: espera de animacion.
		if not anim_busy(): finish()
	return 0


## 0x97 FUN_004035a0: fija el contador de los bits 6-8 de las banderas de la zona a en b (si
## es 0 o mayor que b), solo si413170 devuelve objeto. Espera igual que0x8b.
func f4035a0() -> int:
	var p := cmd_player()
	var z := cmd_a()
	var zone := DuelMem.zone(p, z)
	var v := (m.u16(zone + 6) & 0x1c0) >> 6
	if v == 0 or cmd_b() < v:
		v = cmd_b()
	if (m.u32(zone) & 0xfff) == 0:
		finish()
		return 0
	var s := step()
	if s == 0:
		if visual_card_index(p, z) >= 0:
			var f := m.u16(zone + 6)
			m.set_u16(zone + 6, f ^ (((v << 6) ^ f) & 0x1c0))
			present("zone_counter", {"p": p, "zone": z, "counter_type": 4})
		next_step()
	elif s == 1:
		if not anim_busy(): finish()
	return 0


## 0xf3 FUN_004036c0: guion de tutorial; espera a que el cursor (DAT_005af708) este en la
## posicion (p, b, c) y, si a es 1 o 2, a que se pulse un boton (bits de 0xa114a8). En el
## núcleo sin interfaz la condición se da por cumplida; scene9 consulta la entrada real.
func f4036c0() -> int:
	if tutorial_interactive:
		if not ui_hover_object:
			if cmd_b() < 16: return 0
		elif m.u32(0xa161a4) != cmd_player() or m.u32(0xa161a8) != cmd_b() or m.u32(0xa161ac) != cmd_c():
			return 0
		if cmd_a() != 0 and (f540a50() if cmd_a() == 1 else f540a70()) == 0: return 0
		finish()
		return 0
	present("tutorial_wait_cursor", {"p": cmd_player(), "button": cmd_a(), "loc": cmd_b(),
			"index": cmd_c()})
	finish()
	return 0


## 0xf4 FUN_00403760: guion de tutorial; pone directamente la carta b en la zona a del
## jugador (0-4 monstruo con posicion c % 10 y boca abajo si c >= 10; 5-10 magia/trampa,
## boca abajo si c != 0).
func f403760() -> int:
	var p := cmd_player()
	var z := cmd_a()
	var c := cmd_c()
	var q := p & 1
	var tmp := m.local(4)
	m.set_u32(tmp, (f401ad0(cmd_b()) & 0xfff) | ((((q | 6) << 1) | q) << 12))
	if z < 5:
		present("tutorial_place", {"p": p, "zone": z, "card": cmd_b(), "c": c})
		f5422b0(p, z % 5, tmp, c % 10, 1 if c < 10 else 0)
	elif z < 0xb:
		present("tutorial_place", {"p": p, "zone": z, "card": cmd_b(), "c": c})
		f5423a0(p, z % 5, tmp, 1 if c == 0 else 0)
	finish()
	return 0


## 0xfc FUN_004039c0: guion de tutorial; si a == 1 busca en la lista de seleccion (0xa11624)
## la entrada con byte de tipo b y guarda su id en 0xa16178.
func f4039c0() -> int:
	var b := cmd_b()
	if cmd_a() == 1:
		var i := 0
		if f4073e0() > 0:
			while f407570(i) != b:
				i += 1
				if i >= f4073e0():
					finish()
					return 0
			m.set_u16(0xa16178, f401a70(f4073f0(i)))
	finish()
	return 0


## 0xf8 FUN_00403a60: guion de tutorial; si 0xa16178 == b salta al comando 0xfa (FUN_00403960).
func f403a60() -> int:
	if m.u16(0xa16178) == cmd_b():
		f403960()
	finish()
	return 0


## 0x77 FUN_00403cb0: pone la carta b en la zona de monstruo (a & 0xff); el bit 9 de a es la
## posicion y el bit 8 el de boca arriba (los dos de FUN_005422b0).
func f403cb0() -> int:
	var p := cmd_player()
	var a := cmd_a()
	var z := a & 0xff
	var s := step()
	if s == 0:
		var entry := (cmd_c() << 16) | cmd_b()
		entry = entry ^ ((f401ad0(cmd_b() & 0xfff) ^ entry) & 0xfff)
		var tmp := m.local(4)
		m.set_u32(tmp, entry)
		f5422b0(p, z, tmp, (a >> 9) & 1, (a >> 8) & 1)
		present("monster_appear", {"p": p, "zone": z, "card": f401a70(entry & 0xfff), "a": a})
		next_step()
	elif s == 1:
		next_step()
	elif s == 2:
		# FUN_00403c70: espera de animacion.
		next_step()
	else:
		finish()
	return 0


## 0x95 FUN_00403ea0: levanta la carta de la zona a (copia en 0xa15730) y la manda a su
## destino con FUN_00543610(p, a, b).
func f403ea0() -> int:
	var p := cmd_player()
	var z := cmd_a()
	var b := cmd_b()
	match step():
		0:
			# FUN_00403c40: espera a los objetos visuales.
			next_step()
		1:
			# FUN_00465740: suelta el efecto de sacrificio de la zona (o lo crea ya suelto); el
			# paso 2 (FUN_00403c40) espera a que termine antes de mandar la carta a su destino.
			f465740(p, z)
			_a_step_clear()
		2:
			next_step()
		3:
			f541cb0(DuelMem.MOVING_CARD, DuelMem.zone(p, z))
			f543610(p, z, b)
			# 407880 (buzon tipo 9 -> 407cb0/414810): el objeto pasa al destino sin vuelo.
			present("zone_to", {"p": p, "zone": z, "b": b, "instant": true,
					"card": f401a70(m.u32(DuelMem.MOVING_CARD) & 0xfff)})
			next_step()
		_:
			finish()
	return 0


## 0x91 FUN_004040f0: voltea la carta de la zona a (bit 1); si queda boca arriba recibe
## numero de colocacion.
func f4040f0() -> int:
	var p := cmd_player()
	var z := cmd_a()
	var zone := DuelMem.zone(p, z)
	var index := m.u32(zone) & 0xfff
	if index == 0:
		finish()
		return 0
	match step():
		0:
			f402610(p, f401a70(index))
			next_step()
		1:
			# FUN_00403c70: espera de animacion.
			present("flip", {"p": p, "zone": z, "flags": m.u8(zone + 6)})
			next_step()
		2:
			var f := m.u16(zone + 6)
			f = (f ^ ((((~(f >> 1)) << 1) ^ f) & 2))
			m.set_u16(zone + 6, f)
			if (f & 2) != 0:
				m.set_u16(zone + 4, m.u16(DuelMem.PLACE_SEQ))
				m.set_u16(DuelMem.PLACE_SEQ, m.u16(DuelMem.PLACE_SEQ) + 1)
			# FUN_00402630: bust-up de reaccion.
			present("reaction_flip", {"p": p, "card": f401a70(index)})
			next_step()
		3:
			finish()
	return 0


## 0x42/0x43 FUN_00404270: animacion del cambio de LP (a = cantidad; 0x43 la resta). Solo
## presentacion: los LP ya los cambian las reglas. Si c != 0 hay bust-up de reaccion.
func f404270(gain: int) -> int:
	var p := cmd_player()
	var amount := cmd_a()
	if gain == 0:
		amount = -amount
	match step():
		0:
			present("lp_change", {"p": p, "amount": amount})
			next_step()
		1:
			if cmd_c() != 0:
				f4026b0(p, amount)
			_a_step_clear()
		2:
			_a_wait_lo(0x500)
		3:
			# FUN_0045d840 sobre el contador de LP del jugador (0x5af76c + 0xd04 + p * 0x40):
			# libera la cantidad retenida (la del paso 0 o la del dano de batalla, que es la
			# misma) y el contador la descuenta fotograma a fotograma con FUN_0054b910 hasta
			# que el paso 4 ve los contadores parados. El neto es la cantidad del comando.
			f54b910(p, amount)
			next_step()
		4:
			# FUN_004376e0: musica segun los LP.
			present("music_by_lp", {})
			finish()
	return 0


## 0xf5 FUN_00404890: guion de tutorial; muestra el texto b (dlg_text) en un cuadro de tipo a.
## Para a == 8 guarda el bit 8 de c en 0xa13418 y su byte bajo en 0xa16101. El cuadro se da
## por cerrado al momento sólo cuando auto_answer está activo; en escena espera la ventana.
func f404890() -> int:
	var a := cmd_a()
	var b := cmd_b()
	var c := cmd_c()
	if step() == 0:
		next_step()
		# El texto (b; compuesto con 0xcc si b esta en [0xa9, 0xcb], o con el nombre de la
		# carta c si b == 0x8c) solo es presentacion: FUN_005417e0 recibe aqui el id b.
		present("tutorial_text", {"text": b, "kind": a, "c": c})
		f5417e0(b)
		if b >= 0xa9 and b <= 0xcb:
			_dialog_subs.append({"append": 0xcc})
		elif b == 0x8c:
			_dialog_subs.append({"card": f401a70(f401ad0(c))})
		if a == 8:
			m.set_u16(0xa13418, m.u16(0xa13418) | ((c >> 8) & 1))
			m.set_u8(0xa16101, c)
		# FUN_00540d60
		m.set_u32(0xa0fb04, a)
		m.set_u32(0xa0fb00, c)
		f540db0()
	if dialog_open.is_empty(): finish()
	return 0


## 0xfb FUN_00404a40: guion de tutorial; abre la lista de seleccion (FUN_00407580 con -1) y,
## cuando la ventana deja de existir, guarda el resultado (0xa11622) en 0xa16178. Con
## auto_answer no hay ventana y el resultado es el que deje FUN_00407580 (0).
func f404a40() -> int:
	if step() == 0:
		next_step()
		f407580(cmd_player(), -1, cmd_a(), cmd_b())
		return 0
	if not list_open.is_empty():
		return 0
	finish()
	m.set_u16(0xa16178, m.u16(0xa11622))
	return 0


## 0x79 FUN_004052b0: manda la carta de la zona a a donde corresponda (FUN_00543740); guarda
## su indice logico en0x5aed08 para el bust-up. Si (b &0xff)!=0 y413170 no
## devuelve objeto, termina sin moverla; el efecto usa el indice visual del objeto.
func f4052b0() -> int:
	var p := cmd_player()
	var z := cmd_a()
	var zone := DuelMem.zone(p, z)
	match step():
		0:
			m.set_u32(0x5aed08, m.u32(zone) & 0xfff)
		1:
			if (cmd_b() & 0xff) != 0:
				if visual_card_index(p, z) < 0:
					finish()
				else:
					present("destroy_effect", {"p": p, "zone": z, "card": f401a70(visual_card_index(p, z))})
		2:
			f541cb0(DuelMem.MOVING_CARD, zone)
			m.set_u32(zone, m.u32(zone) & 0xfffbffff)
			f543740(p, z)
			# 407880 (buzon tipo 9 -> 407cb0/414810): sin vuelo; el comando dura 7 fotogramas y
			# la carta ya esta en el cementerio mientras sigue la explosion (traza del 10 oct).
			present("zone_to_grave", {"p": p, "zone": z, "instant": true,
					"card": f401a70(m.u32(DuelMem.MOVING_CARD) & 0xfff)})
			next_step()
			return 0
		3:
			# FUN_00402690: bust-up de reaccion.
			present("reaction_destroy", {"p": p, "card": f401a70(m.u16(0x5aed08))})
			next_step()
			return 0
		4:
			finish()
			return 0
		_:
			return 0
	next_step()
	return 0


## 0x7a FUN_004054b0: animacion sobre la carta de la zona a: la copia en 0xa15730 y borra el
## bit18 de la entrada de la zona en Yugi/Kaiba.
## 0x5aed08 recibe el indice del objeto visual
## (o0 si no existe), incluso cuando la imagen retenida difiere de la zona logica.
func f4054b0() -> int:
	var p := cmd_player()
	var z := cmd_a()
	var zone := DuelMem.zone(p, z)
	match step():
		0:
			m.set_u32(0x5aed08, maxi(visual_card_index(p, z), 0))
			next_step()
		1:
			present("cmd7a", {"p": p, "zone": z})
			_a_step_clear()
		2:
			_a_wait_lo(0x700)
		3:
			f541cb0(DuelMem.MOVING_CARD, zone)
			m.set_u32(zone, m.u32(zone) & 0xfffbffff)
			var owner := (m.u32(DuelMem.MOVING_CARD) >> 12) & 1
			var destination := 14
			# Paso 3 de 4054b0: 407880 (buzon tipo 9), sin vuelo.
			present("zone_move", {"p": p, "zone": z, "to": (destination << 8) | owner,
					"card": f401a70(m.u32(DuelMem.MOVING_CARD) & 0xfff), "instant": true})
			next_step()
		4:
			# FUN_00402690: bust-up de reaccion.
			present("reaction_destroy", {"p": p, "card": f401a70(m.u16(0x5aed08))})
			next_step()
		5:
			finish()
	return 0


## 0x71 FUN_00405d10: invoca la carta b en la zona de monstruo (a >> 12) desde la ubicacion
## (a & 0xf); bits 8 y 9 de a = boca arriba y posicion. Compacta la mano (FUN_00544e00).
func f405d10() -> int:
	var p := cmd_player()
	var a := cmd_a()
	var dst := a >> 12
	var entry := (cmd_c() << 16) | cmd_b()
	entry = entry ^ ((f401ad0(cmd_b() & 0xfff) ^ entry) & 0xfff)
	var s := step()
	if s == 0:
		next_step()
		s = 1
	match s:
		1:
			present("special_summon", {"p": p, "card": f401a70(entry & 0xfff), "from": a & 0xf,
					"index": (a & 0xff) >> 4, "zone": dst, "a": a})
			present("detail", {"card": f401a70(entry & 0xfff)}) # 5af76c+0x38, metodo +0x24.
			_a_step_clear_hi()
		2:
			_a_wait_hi()
		3:
			if rules_game == "yugi":
				present("special_summon_place", {"p": p, "a": a, "card": f401a70(entry & 0xfff)})
			next_step()
		4:
			f544e00(p)
			var tmp := m.local(4)
			m.set_u32(tmp, entry)
			f5422b0(p, dst, tmp, (a >> 9) & 1, (a >> 8) & 1)
			finish()
	return 0


## 0x72 FUN_00405f90: animacion de una carta (a) que activa su efecto desde la ubicacion b.
## Si esta en el cementerio y no es la de arriba, la sube al tope (FUN_00544890).
func f405f90() -> int:
	var p := cmd_player()
	var index := f401ad0(cmd_a()) & 0xffff
	var loc := cmd_b()
	match step():
		0:
			if loc == 0xe:
				if f544a00(p, f401a70(index)) != 0 and _a_grave_top(p) != index:
					f544890(p, index)
					present("grave_top", {"p": p, "card": f401a70(index)})
			next_step()
		1:
			if ctype(index) != 0 and ctype(index) < 0x15:
				# FUN_00402630 -> Yu401e00 / Ka406250 -> 402620 (reaction_flip): voz de la CPU por carta
				# (Trap Hole -> Yugi_26, 0x4db -> Ka64; cotejo por valores, 30-10-2026).
				present("reaction_flip", {"p": p, "card": f401a70(index), "cmd_72": true})
			next_step()
		2:
			present("card_effect", {"p": p, "card": f401a70(index), "loc": loc, "c": cmd_c()})
			present("detail", {"card": f401a70(index)}) # 5af76c+0x38, metodo +0x24.
			next_step()
		3:
			finish()
	return 0


## 0x7f FUN_004062b0: cambia la posicion de la carta de la zona a (bit 0); si b != 0 la deja
## ademas boca arriba (bit 1).
func f4062b0() -> int:
	var p := cmd_player()
	var z := cmd_a()
	var zone := DuelMem.zone(p, z)
	if (m.u16(zone) & 0xfff) == 0:
		finish()
		return 0
	match step():
		0:
			if p != 0 and cmd_c() != 0:
				present("voice", {"id": 0x10000044 + (1 if (m.u8(zone + 6) & 1) != 1 else 0)})
			next_step()
		1:
			present("change_position", {"p": p, "zone": z, "flags": m.u8(zone + 6),
					"b": cmd_b()})
			next_step()
		2:
			var f := m.u16(zone + 6) ^ 1
			m.set_u16(zone + 6, f)
			if cmd_b() != 0 and (f & 2) == 0:
				m.set_u16(zone + 6, f | 2)
			finish()
	return 0


## 0xb1 FUN_00406540: copia el bit 0 de b en el bit 10 de la palabra +0x8e de la zona a.
## Antes espera a los objetos visuales (no hay en el nucleo).
func f406540() -> int:
	var p := cmd_player()
	var z := cmd_a()
	var b := cmd_b()
	if step() == 0 and z < 0xb and (m.u32(DuelMem.zone(p, z)) & 0xfff) != 0:
		var at := DuelMem.zone(p, z) + 0x8e
		m.set_u16(at, m.u16(at) ^ (((b << 10) ^ m.u16(at)) & 0x400))
		if b != 0 and cmd_c() == 0:
			# FUN_0043d9b0: efecto de anulacion (duel/chain/disable.txt) sobre la carta; el
			# comando espera a que termine (primer bucle de 0x406540).
			present("chain_disable", {"p": p, "zone": z, "defense": (m.u8(DuelMem.zone(p, z) + 6) & 1) if z < 5 else 0})
		next_step()
		return 0
	finish()
	return 0


## 0x06 FUN_004068c0: animacion de la victoria por Destiny Board (resalta las cartas de la
## tabla de 0x59a5b8 en las zonas de magia/trampa). Solo presentacion.
func f4068c0() -> int:
	var p := cmd_player()
	match step():
		0:
			next_step()
		1:
			var found := []
			for k in 5:
				var index := f401ad0(m.u16(0x59a5b8 + k * 4))
				for z in 5:
					if (m.u16(0xa11c40 + p * PS + z * 0x94) & 0xfff) == index:
						found.append([k, z])
						break
			present("destiny_board", {"p": p, "cards": found})
			next_step()
		_:
			finish()
	return 0


## 0x84 FUN_00406c40: animacion con la carta c y luego FUN_00543e20(b, a, 1).
func f406c40() -> int:
	if step() == 0:
		next_step()
		present("cmd84", {"card": cmd_c(), "a": cmd_a(), "b": cmd_b()})
		return 0
	f543e20(cmd_b(), cmd_a(), 1)
	finish()
	return 0


## 0xa5 FUN_00406d20: crea una ficha (id 0x780 + b) en la zona de monstruo (a & 0xff), boca
## arriba; b = 1 o 2 en defensa, 0 o 3 en ataque. Otros b no hacen nada.
func f406d20() -> int:
	var p := cmd_player()
	var z := cmd_a() & 0xff
	var b := cmd_b()
	var index := f401ad0(b + 0x780)
	var pos := 0
	match b:
		0, 3:
			pos = 0
		1, 2:
			pos = 1
		_:
			finish()
			return 0
	match step():
		0:
			var q := p & 1
			var tmp := m.local(4)
			m.set_u32(tmp, ((((q | 10) << 1) | q) << 12) | (index & 0xfff))
			f5422b0(p, z, tmp, pos, 1)
			var at := p * PS + 0xa11963 + z * 0x94
			m.set_u8(at, m.u8(at) | 2)
			present("token", {"p": p, "zone": z, "card": b + 0x780, "pos": pos})
			present("detail", {"card": b + 0x780}) # 5af76c+0x38, metodo +0x24.
			_a_step_clear_hi()
		1:
			_a_wait_hi()
		2:
			next_step()
		3:
			finish()
	return 0


## 0x1e FUN_00407190: animacion de la carta a (resalta sus copias boca arriba en el campo).
## Solo presentacion.
func f407190() -> int:
	var index := f401ad0(cmd_a()) & 0xffff
	if ctype(index) != 0 and ctype(index) < 0x15:
		# Paso 0: FUN_00402630, bust-up de reaccion para los monstruos.
		present("reaction_card", {"p": cmd_player(), "card": f401a70(index)})
	# Paso 1: un efecto de activacion (FUN_0043d490) sobre cada copia boca arriba del jugador
	# (o de los dos si b != 0) sin el bit 0 de +0x90; el paso 2 espera a que terminen.
	present("highlight_card", {"p": cmd_player(), "card": cmd_a(), "both": cmd_b()})
	present("detail", {"card": f401a70(index)}) # 5af76c+0x38, metodo +0x24.
	finish()
	return 0


# --- Lista de seleccion (0xa11620) ----------------------------------------------------------

## FUN_004073e0: numero de entradas de la lista de seleccion.
func f4073e0() -> int:
	return m.u16(0xa11924)


## FUN_004073f0: indice de la carta de la entrada i (0 si la lista es la de tipo 0x1e del
## jugador 1 y la informacion de excluida de esa posicion vale 2).
func f4073f0(i: int) -> int:
	var head := m.u32(0xa11620)
	var entry := m.u32(0xa11624 + i * 4)
	if (head & 1) != 0 and (head & 0xfffe) == 0x1e:
		if m.u8(0xa125f8 + (((entry >> 12) & 1) * 0x6aa + i) * 2) == 2:
			return 0
	return entry & 0xfff


## FUN_00407570: byte alto de la palabra de tipo de la entrada i.
func f407570(i: int) -> int:
	return m.u8(0xa11825 + i * 2)


## FUN_00407580: prepara la lista de seleccion. loc = -1: la rellena FUN_0056ba50(p, a3, a4);
## loc 0xc-0xf: copia el mazo de fusion, mazo, cementerio o excluidas de p con su tipo (8, 2,
## 4, 0x10). Despues crea la ventana de la lista (FUN_0042e820) en la ranura de los cuadros
## (DAT_005af76c+0x11ec): FUN_00540db0 devuelve 1 mientras exista, asi que el motor queda
## bloqueado hasta que la escena la cierra (DuelBase.list_open). Modo de la ventana
## (in_ECX[0xd]): 1 si loc = -1 (3 si a3 = 0xaa, 2 si a3 = 0x439) y 0 en los demas casos.
## Con auto_answer (repeticiones, sin interfaz) no se abre ventana y queda la entrada 0.
func f407580(p: int, loc: int, a3: int, a4: int) -> int:
	var q := (p & 1) * PS
	m.set_u16(0xa11620, (loc * 2) | (p & 1))
	m.set_u16(0xa11622, 0)
	m.clear(0xa11624, 0x200)
	m.clear(0xa11824, 0x100)
	if loc == -1:
		f56ba50(p, a3, a4)
	else:
		var src := -1
		var kind := 0
		match loc:
			0xc:
				m.set_u16(0xa11924, m.u8(0xa11949 + q))
				src = 0xa12378 + q
				kind = 8
			0xd:
				m.set_u16(0xa11924, m.u8(0xa11947 + q))
				src = 0xa120f8 + q
				kind = 2
			0xe:
				m.set_u16(0xa11924, m.u8(0xa11948 + q))
				src = 0xa12238 + q
				kind = 4
			0xf:
				m.set_u16(0xa11924, m.u8(0xa1194a + q))
				src = 0xa124b8 + q
				kind = 0x10
		# PENDIENTE: con otro loc el original copia desde la direccion loc con el contador que
		# hubiera en 0xa11924; no se usa.
		if src >= 0:
			for i in m.u16(0xa11924):
				f541cb0(0xa11624 + i * 4, src + i * 4)
				m.set_u16(0xa11824 + i * 2, kind)
	var mode := 0
	if loc == -1:
		mode = 3 if a3 == 0xaa else 2 if a3 == 0x439 else 1
	if auto_answer == -1:
		list_open = {"p": p, "loc": loc, "mode": mode}
		present("list_open", list_open.duplicate())
	return 0


## FUN_00407540: marca la entrada i con el orden n (byte alto de su palabra de tipo; 0 = sin
## marcar). La usa la ventana de la lista en los modos 2 y 3.
func f407540(i: int, n: int) -> int:
	m.set_u16(0xa11824 + i * 2, (m.u8(0xa11824 + i * 2) & 0x1f) + n * 0x100)
	return 0


## FUN_00407440: iconos de la entrada i en la ventana de la lista. Bits 0-4: tipo de origen
## (mano, mazo, cementerio, fusion, excluida); 0x20 carta con el bit 0x80000; 0x40 monstruo del
## cementerio o excluido que no se puede revivir (FUN_005421c0) sin invocacion propia; 0x80 bit
## 0x100000; 0x100/0x200 excluida con la marca 1/2 de 0xa125f8; 0x400 duena el jugador 1.
func f407440(i: int) -> int:
	var kind := m.u8(0xa11824 + i * 2) & 0x1f
	var entry := m.u32(0xa11624 + i * 4)
	var bits := kind
	if (entry & 0x80000) != 0:
		bits |= 0x20
	var prop := f401a20(entry & 0xfff)
	if ((prop >> 20) & 0x1f) != 0 and ((prop >> 20) & 0x1f) < 0x15 and kind in [0x10, 4]:
		if call("f5421c0", entry & 0xfff) != 0 and (entry & 0xc000) == 0:
			bits |= 0x40
		if (entry & 0x100000) != 0:
			bits |= 0x80
	if kind == 0x10:
		var mark := m.u8(0xa125f8 + (((entry >> 12) & 1) * 0x6aa + i) * 2)
		if mark == 1:
			bits |= 0x100
		elif mark == 2:
			bits |= 0x200
	if (entry & 0x1000) != 0:
		bits |= 0x400
	return bits


## FUN_00413f50 (objeto de la interfaz en ECX): crea el objeto visual de la carta en la
## ubicacion codificada en el u16 de loc_addr. Solo presentacion.
func f413f50(_index: int, _loc_addr: int) -> int:
	return 0
