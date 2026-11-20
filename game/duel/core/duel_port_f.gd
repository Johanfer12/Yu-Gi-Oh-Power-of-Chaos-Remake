class_name DuelPortF
extends DuelPortE

## FUN_0053de40: respuesta opcional de carta durante preparacion de efectos.
func f53de40(p: int, id: int, z: int) -> int:
	var step := m.u8(0xa13426)
	if step == 0:
		f54eed0(p, f401ad0(id), z)
		m.set_u8(0xa13426, 1)
		return 0
	if step != 1:
		m.set_u16(0xa13428, m.u16(0xa16178))
		return 1
	# Solo 0x489 (mensaje 9) y 0x5ed/0x5ef (mensaje 10) piden el cuadro; con otra carta el
	# original fija el tipo Si/No sin pedirlo (0xa0fb08 queda como estaba) y el paso
	# siguiente lee la respuesta que hubiera en 0xa16178. Se conserva.
	if (id & 0xffff) == 0x489:
		f5417e0(9)
	elif (id & 0xffff) == 0x5ed or (id & 0xffff) == 0x5ef:
		f5417e0(10)
	f540d60(1, 0)
	m.set_u8(0xa13426, 2)
	return 0

## FUN_0053dee0: descarte opcional de magia; la CPU escoge la primera de su mano.
func f53dee0(p: int) -> int:
	var step := m.u8(0xa13426)
	if step == 0:
		m.set_u16(0xa13428, 0)
		var eligible := false
		var a := DuelMem.pl(p & 1)
		for hand in m.u8(a + 2):
			var card := m.u32(a + 0x674 + hand * 4)
			if ctype(card & 0xfff) == 0x16 and (card & 0x40000) == 0:
				eligible = true
				break
		if not eligible:
			return 1
		if p != 0:
			m.set_u16(0xa13428, 1)
			for hand in m.u8(DuelMem.pl(1) + 2):
				if ctype(m.u16(DuelMem.pl(1) + 0x674 + hand * 4) & 0xfff) == 0x16:
					f54e680(1, hand, 1, 1)
					return 1
			m.set_u16(0xa13428, 0)
			return 1
		# Cuadro Si/No con el mensaje 0xb; el paso 1 lee la respuesta.
		f5417e0(0xb)
		f540d60(1, 0)
		m.set_u8(0xa13426, 1)
		return 0
	if step == 1:
		if m.u16(0xa16178) == 0:
			m.set_u16(0xa13428, 0)
			return 1
		f5417e0(0xc)
		m.set_u8(0xa13426, 2)
		return 0
	if (m.u32(0xa114a8) & 0x102) != 0:
		m.set_u8(0xa13426, 0)
		return 0
	if f57a060(1) != 0:
		var hand := m.u32(0xa161ac)
		var card := m.u32(DuelMem.pl(0) + 0x674 + hand * 4)
		if ctype(card & 0xfff) == 0x16 and (card & 0x60000) == 0 and f579890() != 0:
			m.set_u16(0xa13428, 1)
			f54e680(0, hand, 1, 1)
			return 1
	return 0

## FUN_0053f860: cuenta copias del indice en principal y fusion.
func f53f860(index: int) -> int:
	var total := 0
	for pair in [[0xa112c0, 0xa1139c], [0xa1137e, 0xa113a0]]:
		for i in m.u16(pair[1]):
			if m.u16(pair[0] + i * 2) == (index & 0xffff):
				total += 1
	return total

## FUN_0053a400: ejecuta la accion elegida en el menu de una carta.
func f53a400() -> int:
	var action := (m.u32(0xa13408) >> 2) & 0xf
	var p := m.u8(0xa1340f) & 1
	var loc := m.u8(0xa1340f) >> 1
	var z := m.u8(0xa13410)
	var index := m.u16(0xa13404)
	match action:
		0: return invoke_original(0x56e6e0, [1, 0])
		1:
			if loc == 0:
				return f56ffe0()
		2:
			m.set_u8(0xa133f4, 2)
			m.set_u8(0xa1340d, 0)
			m.set_u16(0xa114c0, m.u16(0xa114c0) ^ (((z << 8) ^ m.u16(0xa114c0)) & 0x700))
			m.set_u32(0xa13408, m.u32(0xa13408) & 0xfffffffd)
			return action
		3:
			var packed := m.u16(0xa1340e)
			match loc:
				0:
					var id := f401a70(index)
					if id in [0x186, 0x51, 0x16d]:
						if m.u8(0xa1340d) == 0:
							var result := f54ea40(p, z)
							if result != 0:
								m.set_u8(0xa1340d, 1)
								return result
						elif m.u8(0xa1340d) == 1:
							var id2: int = {0x51: 0x2e5, 0x16d: 0x170, 0x186: 0x187}[id]
							var card := m.local(4)
							if f5428a0(p, id2, card) != 0:
								f57cc50(p, card, 1, 1, 0xd, 0)
								m.set_u8(0xa1340d, 2)
								return 2
						_f_card_action_finish()
						return 0
					var special := id == 0x1a0 or id == 0x243
					var code := ((z + loc) & 0x1f) << 16 | ((packed & (0xffffff08 if special else 0xffffff00)) << 23) | index | (0x4400000 if special else 0x400000)
					var result := f53baa0(code, 0)
					_f_card_action_finish()
					return result
				5:
					if (m.u8(DuelMem.zone(p, z + 5) + 6) & 2) == 0:
						issue((packed & 0xff01) << 7 | 0x91, z + loc, 0, 0)
					# El original consulta z sin sumar cinco en este indicador.
					if (m.u32(DuelMem.zone(p, z)) & 0x40000) != 0:
						f54ef00(p, f401ad0(0x443))
						f54ef90(p, 2000)
				10:
					if (m.u8(DuelMem.zone(p, 10) + 6) & 2) == 0:
						issue((packed & 0xff01) << 7 | 0x91, 10, 0, 0)
				11:
					if ctype(index) < 0x15:
						var id := f401a70(index)
						if id == 0x1a8:
							f56e0b0(p)
							f54e680(p, z, 0, 1)
							var result := f53baa0((packed & 0xffffff00) << 23 | index | 0x6e0000, 0)
							_f_card_action_finish()
							return result
						if id != 0x47:
							_f_card_action_finish()
							return id
						m.set_u8(DuelMem.pl(p) + 8, m.u8(DuelMem.pl(p) + 8) | 0x10)
					return f570040(1, 0, 0)
				_:
					_f_card_action_finish()
					return packed
			var result := f53baa0(((z + (packed >> 9)) & 0x1f) << 16 | ((packed & 0xff00) << 23) | index | 0x200000, 0)
			if (m.u8(0xa133f2) & 0xe) > 2:
				m.set_u8(DuelMem.pl(p) + 0x10, m.u8(DuelMem.pl(p) + 0x10) | 2)
			_f_card_action_finish()
			return result
		4:
			if loc == 11:
				if ctype(index) > 0x14:
					return f570040(0, 0, 0)
				return invoke_original(0x56e6e0, [0, 0])
		5, 6:
			if loc == 0:
				return f570350(action)
		7:
			m.set_u8(0xa133fc, m.u8(0xa133fc) + 1)
		8:
			if m.u8(0xa1340d) == 0:
				# "Capitulas?" (mensaje 6) con Si/No.
				f5417e0(6)
				f540d60(1, 0)
				m.set_u8(0xa1340d, 1)
				return 1
			if m.u8(0xa1340d) - 1 != 0:
				return m.u8(0xa1340d) - 1
			if m.u16(0xa16178) != 0:
				issue(0x40, 1, 0, 0)
				_f_card_action_finish()
				return 0
		9: return invoke_original(0x5703c0)
		10: return invoke_original(0x56e6e0, [1, 1])
		11: return invoke_original(0x56e6e0, [0, 1])
	_f_card_action_finish()
	return action

func _f_card_action_finish() -> void:
	m.set_u32(0xa13408, m.u32(0xa13408) & 0xfffffffd)
	m.set_u8(0xa1340d, 0)

## FUN_005808b0: centinela de estado CPU, el original devuelve uno.
func f5808b0() -> int:
	return 1

## FUN_0053ea40: envia al otro equipo del duelo en red un paquete (tipo u16 + `size` bytes de
## `src`). En Yugi y Kaiba el envio, FUN_005808b0, esta vacio: el paquete se arma en la pila y
## se descarta. Joey lo manda por 5bd090 -> 443e40; el port lo entrega a `net` (D17).
func f53ea40(kind: int, src: int, size: int) -> int:
	if net == null:
		f5808b0()
		return 0
	var packet := PackedByteArray()
	packet.resize(2 + maxi(size, 0))
	packet.encode_u16(0, kind & 0xffff)
	for i in size:
		packet[2 + i] = m.u8(src + i)
	net.send(packet)
	return 0

## FUN_0053ed60: paquete de red de tres u16 (6 bytes) por FUN_0053ea40.
func f53ed60(kind: int, a: int, b: int, c: int) -> int:
	var buf := m.local(6)
	m.set_u16(buf, a)
	m.set_u16(buf + 2, b)
	m.set_u16(buf + 4, c)
	return f53ea40(kind, buf, 6)

## Lado receptor de 5808b0 (en Yugi plegado con el envio en el mismo `return 1`; Joey 444140):
## copia el siguiente paquete recibido a `dst` (tipo en dst, datos desde dst + 2). 0 si no hay.
func _net_receive(dst: int, limit: int) -> int:
	if net == null:
		return 0
	var packet: PackedByteArray = net.receive()
	if packet.size() < 2:
		return 0
	for i in mini(packet.size(), limit):
		m.set_u8(dst + i, packet[i])
	return 1

## 583e00 dentro de 53eda0 (en Yugi plegado con otras funciones que devuelven 0; Joey 444220):
## la sesion sigue con los dos jugadores.
func _net_active() -> bool:
	return net != null and net.active()

## Joey 5bdad0: se espera al rival (cartel de 456360). Joey usa su contador de paquetes en
## curso y el turno del rival; con el protocolo de Yugi del port, lo equivalente es el turno del
## rival o una espera de su respuesta: ventana de cadena enviada (569c30 estado 101, 53bd50
## estado 101) o su eslabon en resolucion (53c2a0 estados 3/5 y 53ca00 estados 6/7 con 53b930).
## No se muestra mientras el jugador local decide (a558ac & 0x4000 en Joey): ventana remota
## 56a460 abierta, cuadro o lista.
func net_waiting() -> bool:
	if (m.u16(0xa16180) & 0x100) == 0:
		return false
	if not dialog_open.is_empty() or not list_open.is_empty():
		return false
	if (m.u32(0xa15a44) & 0x8000) != 0:
		return false
	if (m.u8(0xa133f2) & 1) != 0:
		return true
	if m.u8(0xa16091) == 101 or m.u8(0xa16090) == 101:
		return true
	if (m.u8(0xa15fce) & 1) != 0 and ((m.u8(0xa15fce) >> 1) in [3, 5]) \
			and f53b930(0xa15e80 + m.u8(0xa15fcf) * 0x14) != 0:
		return true
	if (m.u8(0xa15fd0) & 1) != 0 and (((m.u8(0xa15fd0) >> 1) & 0x7f) in [6, 7]) \
			and f53b930(0xa15e6c + m.u16(0xa15fc0) * 0x14) != 0:
		return true
	return false

## FUN_00539ac0: prepara resultado de batalla con modificadores del original.
func f539ac0(p: int, zero_attack: int) -> int:
	var flags := m.u32(0xa114c0)
	var other := (flags >> 1) & 1
	var source := (flags >> 8) & 7
	var target := (flags >> 11) & 7
	for side in 2:
		var owner := (flags & 1) if side == p else other
		var z := source if side == p else target
		var a := DuelMem.zone(owner, z)
		var out := 0xa114c4 + side * 12
		m.copy(0xa114dc + side * 0x94, a, 0x94)
		m.set_u16(out, (m.u16(out) & 0xffe0) | z | ((m.u8(a + 6) & 1) << 4))
		m.set_u16(out + 2, m.u16(a) & 0xfff)
		m.set_u16(out + 4, f547c60(owner, z))
		m.set_u16(out + 6, f547c80(owner, z))
		m.set_u16(out + 10, 0)
	var atk := 0xa114c4 + p * 12
	var def := 0xa114d0 - p * 12
	if (flags & 4) != 0:
		m.set_u16(def + 2, 0)
		m.set_u16(def + 4, 0)
		m.set_u16(def + 6, 0)
	if (flags & 0x40) != 0:
		m.set_u16(atk + 4, 0)
	m.set_u16(atk + 8, m.u16(atk + 4))
	m.set_u16(def + 8, m.u16(def + 4))
	m.set_u8(atk, m.u8(atk) & 0xef)
	if (flags & 4) != 0:
		m.set_u16(def + 10, m.u16(atk + 4))
		m.set_u16(def + 8, 0)
		_f_battle_prevent_damage(def, other)
		_f_battle_prevent_destruction(def, other)
		_f_battle_prevent_destruction(atk, p)
	else:
		var id := f401a70(m.u16(atk + 2))
		if id == 0x1dd and f545e70(other, target) == 6:
			m.set_u16(atk + 4, m.u16(atk + 4) + 1000)
		elif id == 0x4e5 and f545c40(other, target) == 0xf:
			m.set_u16(atk + 4, m.u16(atk + 4) + 2000)
			m.set_u16(atk + 6, m.u16(atk + 6) + 2000)
		var defending_id := f401a70(m.u16(def + 2))
		if defending_id == 0x11f and f545e70(p, source) == 1:
			m.set_u16(def + 6, m.u16(def + 6) >> 1)
		elif defending_id == 0x4e5 and f545c40(p, source) == 0xf:
			m.set_u16(def + 4, m.u16(def + 4) + 2000)
			m.set_u16(def + 6, m.u16(def + 6) + 2000)
		if zero_attack != 0:
			m.set_u16(atk + 4, 0)
		m.set_u16(atk + 8, m.u16(atk + 4))
		m.set_u16(def + 8, m.u16(def + (6 if (m.u16(def) & 0x10) != 0 else 4)))
		m.set_u16(atk + 8, m.u16(atk + 8) + f53fbd0(m.u16(def + 4)) * f545730(p, source, 0x291))
		var attack := m.u16(atk + 8)
		var defense := m.u16(def + 8)
		if attack == defense:
			if (m.u16(def) & 0x10) == 0 and attack != 0:
				m.set_u8(atk, m.u8(atk) | 8)
				m.set_u8(def, m.u8(def) | 8)
		elif attack > defense:
			if f545730(p, source, 0x604) != 0 or id == 0x53d or f545730(p, source, 0x521) != 0 or (m.u16(def) & 0x10) == 0:
				m.set_u16(def + 10, attack - defense)
			m.set_u8(def, m.u8(def) | 8)
		else:
			m.set_u16(atk + 10, defense - attack)
			if (m.u16(def) & 0x10) == 0:
				m.set_u8(atk, m.u8(atk) | 8)
		if id == 0x199 and f545e70(other, target) == 2:
			m.set_u8(def, m.u8(def) | 8)
		elif id == 0x4cf:
			m.set_u16(atk, m.u16(atk) & 0xfff7)
			m.set_u16(atk + 10, 0)
			f54c860(p, m.u16(atk + 2), ((target << 8) | other) & 0x7ff, 3)
		elif id == 0x4e3 and m.u16(def + 4) > 0x76b:
			m.set_u16(atk, m.u16(atk) & 0xfff7)
		if f545730(p, source, 0x49e) != 0 and f545c40(other, target) == 1:
			m.set_u8(def, m.u8(def) | 0x40)
		if f545730(other, target, 0x49e) != 0 and f545c40(p, source) == 1:
			m.set_u8(atk, m.u8(atk) | 0x40)
		if defending_id == 0x4e3 and m.u16(atk + 4) > 0x76b:
			m.set_u16(def, m.u16(def) & 0xfff7)
		# ASM 53a04f/53a072: Waboku limpia destrucción y daño ANTES
		# de copiar el bit 8 al indicador 0x20 en 53a0e5..53a113.
		_f_battle_prevent_destruction(def, other)
		_f_battle_prevent_destruction(atk, p)
		_f_battle_prevent_damage(def, other)
		_f_battle_prevent_damage(atk, p)
		for out in [0xa114c4, 0xa114d0]:
			m.set_u8(out, m.u8(out) ^ (((m.u8(out) * 4) ^ m.u8(out)) & 0x20))
	return 0

func _f_battle_prevent_destruction(out: int, p: int) -> void:
	if (m.u8(DuelMem.pl(p & 1) + 8) & 2) != 0:
		m.set_u16(out, m.u16(out) & 0xfff7)
		m.set_u16(out + 10, 0)

func _f_battle_prevent_damage(out: int, p: int) -> void:
	if m.u16(out + 10) != 0 and f542e60(p, 0x58f, -1) > 0 and f543fc0() == 0x14d:
		m.set_u16(out + 10, 0)

## FUN_00540d60: configura el dialogo de decision del original.
func f540d60(kind: int, value: int) -> int:
	m.set_u32(0xa0fb04, kind)
	m.set_u32(0xa0fb00, value)
	return 0

## FUN_0053e970: detecta una invocacion sin tributos disponible en la mano.
func f53e970(p: int) -> int:
	var a := DuelMem.pl(p & 1)
	for i in m.u8(a + 2):
		var index := m.u16(a + 0x674 + i * 4) & 0xfff
		if f57a490(p, index) == 0 or f5421c0(index) != 0:
			continue
		var prop := f401a20(index)
		var kind := (prop >> 20) & 0x1f
		if (kind > 0x14 and kind < 0x18) or (kind != 0x18 and ((prop >> 25) & 0xf) < 5):
			f53e760(p, 0xd, 0, 0)
			return 1
	return 0

## FUN_0053fc20: firma de ocho bytes de los datos de coleccion.
func f53fc20() -> int:
	m.copy(0xa1129a, 0x5aa748, 8)
	return 0

## FUN_0053fc40: verifica el checksum de coleccion en memoria.
func f53fc40() -> int:
	if m.u16(0xa112a2) != 0xfba5:
		return 0
	var total := 0
	for i in 0x8c2:
		total += m.u16(0xa10120 + i * 2)
	return int(m.u16(0xa112a4) == ((-total) & 0xffff))

## FUN_0053fc90: actualiza el checksum; no escribe archivos de guardado.
func f53fc90() -> int:
	m.set_u16(0xa112a2, 0xfba5)
	var total := 0
	for i in 0x8c2:
		total += m.u16(0xa10120 + i * 2)
	m.set_u16(0xa112a4, -total)
	return 0

## FUN_0053fd00: inicializacion de los datos de coleccion.
func f53fd00() -> int:
	m.clear(0xa10120, 0x1188)
	m.set_u16(0xa10128, 0x10)
	m.set_u16(0xa10126, 0xff)
	f53fc20()
	return 0

## FUN_0053fd30: limite de copias de una carta en los mazos.
func f53fd30(index: int) -> int:
	var id := f401a70(index)
	for row in 50:
		if m.u16(0x5aa758 + row * 4) == id:
			var limit := m.u16(0x5aa75a + row * 4)
			if (m.u8(0xa11298) & 1) == 0 or limit == 0:
				return limit
	return 3

## FUN_0053fd90: nombres equivalentes comparten parte del limite de copias.
func f53fd90(index: int) -> int:
	var own := m.u16(0xa1012c + (index & 0xffff) * 2)
	var total := ((own >> 8) & 3) + ((own >> 10) & 3) + ((own >> 12) & 3)
	var id := f401a70(index)
	var aliases := {
		0: [2000], 2000: [0], 0xe: [0x7de], 0x7de: [0xe],
		0x22: [0x4ba, 0x7f2], 0x4ba: [0x22, 0x7f2], 0x7f2: [0x22, 0x4ba],
		0x25: [0x7f5], 0x7f5: [0x25], 0x28: [0x7f8], 0x7f8: [0x28],
		0x39: [0x76d], 0x76d: [0x39], 0x3d: [0x4e1], 0x4e1: [0x3d],
		0x3f: [0x80f], 0x80f: [0x3f], 0x44: [0x814], 0x814: [0x44],
		0x183: [0x953], 0x953: [0x183], 0x185: [0x955], 0x955: [0x185],
		0x3eb: [0x40a], 0x40a: [0x3eb],
	}
	for alias in aliases.get(id, []):
		var value := m.u16(0xa1012c + (f401ad0(alias) & 0xffff) * 2)
		if id in [0xe, 0x7de, 0x44, 0x814]:
			total += (value >> 12) & 3
		else:
			total += ((value >> 8) & 3) + ((value >> 10) & 3)
	return int(total < f53fd30(index))

## FUN_005402c0: anade al mazo principal de coleccion.
func f5402c0(index: int) -> int:
	if f53fd90(index) != 0 and m.u16(0xa1139c) < 0x50:
		_f_deck_add(index, 0xa1139c, 0xa112c0, 0x100, 0x300)
	return 0

## FUN_00540330: anade al side deck de coleccion.
func f540330(index: int) -> int:
	if f53fd90(index) != 0 and m.u16(0xa1139e) < 0xf:
		_f_deck_add(index, 0xa1139e, 0xa11360, 0x400, 0xc00)
	return 0

## FUN_005403a0: anade al mazo de fusion de coleccion.
func f5403a0(index: int) -> int:
	var value := m.u16(0xa1012c + (index & 0xffff) * 2)
	if ((value >> 12) & 3) < f53fd30(index) and m.u16(0xa113a0) < 0xf:
		_f_deck_add(index, 0xa113a0, 0xa1137e, 0x1000, 0x3000)
	return 0

func _f_deck_add(index: int, counter: int, list: int, increment: int, mask: int) -> void:
	var a := 0xa1012c + (index & 0xffff) * 2
	var value := m.u16(a)
	m.set_u16(a, value ^ ((((value & mask) + increment) ^ value) & mask))
	var count := m.u16(counter)
	m.set_u16(list + count * 2, index)
	m.set_u16(counter, count + 1)

## FUN_00540240: incrementa posesion sin superar el byte original.
func f540240(index: int) -> int:
	var a := 0xa1012c + (index & 0xffff) * 2
	if m.u8(a) != 0xff:
		m.set_u8(a, m.u8(a) + 1)
		m.set_u16(0xa1012a, m.u16(0xa1012a) + 1)
	return 0

## FUN_00540270: garantiza una cantidad de copias.
func f540270(index: int, count: int) -> int:
	var a := 0xa1012c + (index & 0xffff) * 2
	while m.u8(a) < (count & 0xffff):
		m.set_u8(a, m.u8(a) + 1)
		m.set_u16(0xa1012a, m.u16(0xa1012a) + 1)
	return 0

## FUN_005406b0: vacia los tres mazos de la memoria de coleccion.
func f5406b0() -> int:
	for a in range(0xa1012c, 0xa109e2, 2):
		m.set_u8(a + 1, m.u8(a + 1) & 0xc0)
	for a in [0xa1139c, 0xa1139e, 0xa113a0]:
		m.set_u16(a, 0)
	return 0

## FUN_005406f0: contador saturado de victorias por oponente.
func f5406f0(opponent: int) -> int:
	var a := 0xa11218 + opponent * 4
	var value := m.u32(a)
	if (value & 0x7ff) < 0x7ff:
		m.set_u32(a, value ^ (((value + 1) ^ value) & 0x7ff))
	return 0

## FUN_00540720: contador saturado de derrotas.
func f540720(opponent: int) -> int:
	var a := 0xa11218 + opponent * 4
	var value := m.u32(a)
	if (value & 0x3ff800) < 0x3ff800:
		m.set_u32(a, value ^ ((((value & 0xfffff800) + 0x800) ^ value) & 0x3ff800))
	return 0

## FUN_00540760: contador saturado de empates.
func f540760(opponent: int) -> int:
	var a := 0xa11218 + opponent * 4
	var value := m.u32(a)
	if (value & 0xffc00000) < 0xffc00000:
		m.set_u32(a, ((value & 0xffc00000) + 0x400000) ^ (value & 0x3fffff))
	return 0

## FUN_00551990: clase de respuesta; subtipo confirmado en EAX por ensamblador.
func f551990(index: int) -> int:
	var kind := (f401a20(index) >> 20) & 0x1f
	var subtype := (f401a20(index) >> 17) & 7 if kind == 0x15 or kind == 0x16 else 0
	if kind == 0x15:
		return 3 - int(subtype != 1)
	if kind == 0x16:
		return int(subtype == 5) + 1
	if f541950(index) == 1:
		return int(f541d10(f401a70(index), 0) != 0) + 1
	return 0
## Modulo del porte del motor de duelo (ver docs/duel/PORTING.md).


## FUN_0053d970: fija el primer jugador y limpia la bandera de avance del turno.
func f53d970() -> int:
	m.set_u8(0xa133ec, m.u8(0xa133ec) & 0xef)
	m.set_u16(0xa133f2, (m.u16(0xa133f2) & ~1) | (m.u16(0xa114b0) & 1))
	if (m.u16(0xa16180) & 0x100) != 0 and (m.u16(0xa133f2) & 1) != 0:
		m.set_u16(0xa133f0, m.u16(0xa133f0) + 1)
		f53ed60(0xf001, 0, 0, 0)
		m.set_u8(0xa16180, 8)
		return 0
	return 1


## FUN_0053b790: reinicio y reparto inicial; en repeticion recibe comandos externos.
func f53b790() -> int:
	if duel_mode() == 0:
		if m.u8(0xa133fc) == 0:
			issue(0x14, 0, 0, 0)
			issue(0x10, 0, 0, 0)
			var p := m.u16(0xa133f2) & 1
			issue((p << 15) | 0x61, 0, 5, 0)
			issue(((1 - p) << 15) | 0x61, 0, 5, 0)
			m.set_u8(0xa133fc, 1)
			return 0
	else:
		fetch_incoming()
		m.set_u32(0xa114b4, m.u32(0xa114b4) & 0xffffbfff)
	m.set_u8(0xa13438, 0)
	m.set_u8(0xa13439, 0)
	if (m.u32(0xa114b4) & 0x200) == 0 and (m.u16(0xa133f2) & 1) != 0:
		m.set_u8(0xa16180, 8)
		return 0
	return 1


## FUN_0053d650: resultado codificado en las banderas del duelo.
func f53d650() -> int:
	return (m.u16(0xa133f2) & 0x60) >> 5


## FUN_0053dbb0: cambia al estado de fin cuando las reglas detectan un ganador.
func f53dbb0() -> int:
	if f53d730(0) == 0:
		return 0
	m.set_u8(0xa16180, 3 if (m.u32(0xa114b4) & 0x200) != 0 else 9)
	m.set_u8(0xa133fc, 0)
	m.set_u8(0xa133fd, 0)
	return 1


## FUN_0053d9d0: emite el resultado, tras rendicion o desconexion si las hay.
func f53d9d0() -> int:
	var sub := m.u8(0xa133fc)
	if sub != 0:
		if sub != 1:
			return 1
		if m.u16(DuelMem.QUEUE_COUNT) != 0:
			return 0
		if (m.u16(0xa16180) & 0x100) == 0:
			return 1
		# Yugi manda 1 - resultado (ASM 53da0b), que en el rival convierte la victoria en 0 y la
		# derrota en empate: fallo latente de una rama nunca ejecutada. Se manda el resultado
		# visto por el rival como hace Joey (5bd2d0 caso 0xf002: 3 - v; el empate se queda).
		var result := (m.u16(0xa133f2) >> 5) & 3
		f53ed60(0xf003, 3 - result if result in [1, 2] else result, 0, 0)
		m.set_u8(0xa133fc, sub + 1)
		return 0
	var flags0 := m.u16(0xa1194a)
	var flags1 := m.u16(0xa1269e)
	if ((flags0 | flags1) & 0x200) != 0:
		issue(((~(flags0 >> 9)) << 15) | 5, 0, 0, 0)
	if ((flags0 | flags1) & 0x400) != 0:
		issue(((~(flags0 >> 10)) << 15) | 6, 0, 0, 0)
	f53d730(1)
	var result := f53d650()
	present("duel_result", {"winner": result})
	if result >= 1 and result <= 3:
		issue(4, result - 1, 0, 0)
	m.set_u8(0xa133fc, 1)
	return 0


## FUN_0053a130: guarda la posicion del cursor del tablero.
func f53a130() -> int:
	m.set_u32(0xa161bc, m.u32(0xa161a4))
	m.set_u32(0xa161c0, m.u32(0xa161a8))
	m.set_u32(0xa161c4, m.u32(0xa161ac))
	return 0


## FUN_0053a160: indica si el cursor cambio desde la posicion guardada.
func f53a160() -> int:
	return int(m.u32(0xa161bc) != m.u32(0xa161a4) or m.u32(0xa161c0) != m.u32(0xa161a8) or m.u32(0xa161c4) != m.u32(0xa161ac))


## FUN_0053a1a0: accion de la carta bajo el cursor. Paso 0: elige la primera accion
## disponible en el orden de 0x59df1c y la muestra en el cursor. Paso 1: el clic derecho
## sobre la carta (0x100 -> 0x400) pasa a la siguiente accion disponible; el clic izquierdo o
## la tecla de decidir (FUN_00579890, 0x201) la ejecuta.
func f53a1a0() -> int:
	var mask := m.u16(0xa1340a)
	if mask == 0:
		m.set_u32(0xa13408, m.u32(0xa13408) & 0xfffffffe)
		m.set_u8(0xa1340c, 0) # ASM 53a1b3/53a1e1: solo el byte; 0xa1340d-f se conservan
		f540bb0()
		return 0
	if (m.u32(0xa1340c) & 0xff) == 0:
		m.set_u8(0xa161a0, m.u8(0xa161a0) & 0xfe)
		var low := m.u16(0xa13408)
		var cleared := m.u32(0xa13408) & 0xffffffcb
		m.set_u32(0xa13408, cleared | 8)
		for i in 12:
			var action := m.u8(0x59df1c + i * 4)
			if (mask & (1 << (action & 0x1f))) != 0:
				var lowv := ((low & 0xffcb) | 8) ^ ((((action << 2) ^ m.u8(0xa13408)) & 0x3c))
				m.set_u32(0xa13408, (cleared & 0xffff0000) | (lowv & 0xffff))
				break
		f53a130()
		f540b90((m.u32(0xa13408) >> 2) & 0xf)
		m.set_u8(0xa1340c, m.u8(0xa1340c) + 1)
		return 0
	if (m.u32(0xa1340c) & 0xff) != 1:
		m.set_u32(0xa13408, m.u32(0xa13408) & 0xfffffffe)
		m.set_u8(0xa1340c, 0) # ASM 53a1b3/53a1e1: solo el byte; 0xa1340d-f se conservan
		return 0
	if f5407b0() != 0 and (m.u32(0xa114a8) & 0x100) != 0:
		m.set_u32(0xa114a8, (m.u32(0xa114a8) & 0xfffffeff) | 0x400)
	if (m.u32(0xa114a8) & 0x400) != 0:
		var current := (m.u32(0xa13408) >> 2) & 0xf
		var i := 0
		while i < 12:
			if current == m.u32(0x59df1c + i * 4):
				break
			i += 1
		i += 1
		while i < 0x18:
			var action := m.u8(0x59df1c + (i % 12) * 4)
			if ((m.u32(0xa13408) >> 16) & (1 << (action & 0x1f))) != 0:
				var v := m.u32(0xa13408)
				m.set_u32(0xa13408, v ^ (((action << 2) ^ (v & 0xff)) & 0x3c))
				break
			i += 1
		f540b90((m.u32(0xa13408) >> 2) & 0xf)
		present("cursor_action_cycle", {})
	if f579890() != 0:
		m.set_u32(0xa13408, m.u32(0xa13408) | 2)
		# 0x53a30d: solo el paso de la accion (0xa1340d) vuelve a cero; 0xa1340e se conserva
		# (0x53a341-0x53a347). El C de Ghidra parece borrar e/f: el ASM manda.
		m.set_u8(0xa1340d, 0)
		m.set_u16(0xa13404, f5407b0())
		m.set_u8(0xa13410, m.u32(0xa161ac))
		m.set_u8(0xa1340f, ((m.u32(0xa161a8) << 1) | (m.u32(0xa161a4) & 1)) & 0xff)
		m.set_u8(0xa1340c, m.u8(0xa1340c) + 1)
		f540bb0()
		return 0
	return 0

## FUN_0053dbf0: bucle del motor por fotograma y despacho de estados del turno.
## Las ventanas y animaciones se sustituyen por eventos y decisiones de la escena.
func f53dbf0() -> int:
	var target := m.u32(m.u32(0xa0faf8) + m.u8(0xa16180) * 4)
	if target == 0:
		m.set_u16(0xa114b0, m.u16(0xa114b0) ^ (((m.u8(0xa133f2) << 1) ^ m.u8(0xa114b0)) & 0xc0))
		m.set_u32(0xa114b4, m.u32(0xa114b4) & 0xffffcfff)
		return 1
	if (m.u16(0xa16180) & 0x100) != 0 and f53eda0() == 0:
		return 1
	# FUN_004077c0: sin ventana viva en DAT_005af76c+0x11ec, cursor de teclado (FUN_005798a0).
	if dialog_open.is_empty() and list_open.is_empty():
		f5798a0()
	frame_stage = 1
	var busy := int(dispatch_animation_mailbox())
	if busy == 0 and (m.u16(0xa16180) & 0x100) != 0:
		# En red: primero el comando que mando el rival (53b650, confirma con 0xf043) y despues
		# la cola propia, que 53b4e0 envia al rival y no suelta hasta su confirmacion.
		if (m.u32(0xa15a44) & 0x2000) != 0:
			busy = f53b650()
		if busy == 0:
			busy = f53b4e0()
	elif busy == 0:
		busy = int(exec_commands())
	if busy == 0:
		frame_stage = 2
		busy = f540db0()
	if (m.u16(0xa13412) & 0x200) != 0:
		if busy == 0:
			frame_stage = 3
			busy = f53e370()
		var action := m.u16(0xa13414) & 0x3f
		if (m.u16(0xa13412) & 0x200) == 0 and action > 0 and action <= 5:
			f56e280((m.u16(0xa13412) & 0x400) >> 10, m.u16(0xa13416))
			busy = 1
	if busy == 0:
		frame_stage = 4
		busy = f57c440()
		if busy == 0:
			frame_stage = 5
			busy = f53d550()
	if f53d730(0) != 0 and duel_mode() == 0:
		m.set_u8(0xa16180, 3 if (m.u32(0xa114b4) & 0x200) != 0 else 9)
		m.set_u8(0xa133fc, 0)
		m.set_u8(0xa133fd, 0)
		return 0
	if (m.u8(0xa133ec) & 0x10) == 0:
		if busy != 0:
			return 0
		frame_stage = 6
		busy = f56a430()
	if busy != 0:
		return 0
	# Las rutinas anteriores pueden cambiar el estado: releer la tabla como el original.
	target = m.u32(m.u32(0xa0faf8) + m.u8(0xa16180) * 4)
	frame_stage = 7
	var done := invoke_original(target)
	if duel_mode() == 0:
		if f53dbb0() != 0:
			return 0
	elif (m.u32(0xa114b4) & 0x4000) != 0 and m.u8(0xa16180) < 9:
		m.set_u8(0xa133fc, 0)
		m.set_u8(0xa133fd, 0)
		m.set_u8(0xa16180, 9)
		return 0
	if done == 0:
		return 0
	var kind := (m.u32(0xa114b4) >> 10) & 3
	var state := m.u8(0xa16180)
	if (kind == 0 and state == 7) or (kind == 1 and state == 2):
		m.set_u16(0xa133f2, m.u16(0xa133f2) ^ 1)
	elif kind == 2 and state == 7:
		m.set_u16(0xa133f2, m.u16(0xa133f2) ^ 1)
		state = 1
	m.set_u8(0xa16180, state + 1)
	m.set_u8(0xa133fc, 0)
	m.set_u8(0xa133fd, 0)
	return 0


## FUN_0053d550: traslada efectos pendientes al bloque de resolucion.
func f53d550() -> int:
	if (m.u16(0xa15fce) & 1) != 0:
		return f53c2a0()
	if (m.u8(0xa15fd0) & 1) != 0:
		return f53ca00()
	var count := m.u16(0xa15fc2)
	if count == 0:
		# Kaiba (53fc20) devuelve el resultado de 53df70; Yugi devuelve 0.
		var busy := f53b8b0()
		return busy if rules_game != "yugi" else 0
	m.set_u16(0xa15fc0, 0)
	for i in count:
		m.copy(0xa15e80 + i * 0x14, 0xa15c00 + i * 0x14, 0x14)
		m.set_u16(0xa15fc0, m.u16(0xa15fc0) + 1)
	m.set_u16(0xa15fc2, 0)
	m.set_u16(0xa15fce, int(m.u16(0xa15fc0) != 0))
	return 1


## FUN_0053b8b0: actualiza efectos continuos y parametros de monstruos en campo.
## Kaiba (53df70) devuelve 1 en cuanto un monstruo vuelve a su dueño (550d90): el resto de
## zonas espera al fotograma siguiente. Yugi lo recorre todo y no devuelve nada.
func f53b8b0() -> int:
	f56a9e0()
	f56dde0(1 - (m.u16(0xa133f2) & 1))
	f56dc40(0xffffffff)
	for p in 2:
		for z in 5:
			if (m.u32(DuelMem.zone(p, z)) & 0xfff) != 0:
				if f54e6b0(p, z) != 0 and rules_game == "kaiba":
					return 1
				f545240(p, z)
	return 0


## FUN_0053aa20: recorre la tabla de estados de la CPU, reinicia al llegar al centinela.
func f53aa20() -> int:
	var target := m.u32(0x5aa6e8 + m.u8(0xa13438) * 4)
	if target == 0:
		m.set_u8(0xa13438, 0)
		return 1
	var done := invoke_original(target)
	if done != 0:
		m.set_u8(0xa133fc, 0)
		m.set_u8(0xa133fd, 0)
		m.set_u8(0xa13438, m.u8(0xa13438) + 1)
		m.set_u8(0xa13439, 0)
	return 0


## FUN_0053b930: limita informacion de efectos en duelo de red.
func f53b930(entry: int) -> int:
	return int((m.u16(0xa16180) & 0x100) != 0 and (m.u8(entry + 2) & 1) != 0 and f401a70(m.u16(entry)) != 0x3b6)


## FUN_0053bac0: inserta una entrada en la lista de efectos activos.
func f53bac0(a: int, b: int) -> int:
	f53b960(1, a, b)
	return 0


## FUN_0053bae0: copia un efecto con jugadores invertidos a la lista elegida.
func f53bae0(active: int, src: int) -> int:
	var counter := 0xa15fc2 if active == 0 else 0xa15fc0
	var dst := (0xa15c00 if active == 0 else 0xa15e80) + m.u16(counter) * 0x14
	m.copy(dst, src, 0x14)
	m.set_u8(dst + 2, m.u8(dst + 2) | 1)
	m.set_u16(dst + 4, (m.u16(dst + 4) & 0xffe3) | 3)
	m.set_u16(dst + 6, (m.u8(src + 7) << 8) | ((1 - m.s8(src + 6)) & 0xff))
	m.set_u16(dst + 8, (m.u8(src + 9) << 8) | ((1 - m.s8(src + 8)) & 0xff))
	m.set_u16(counter, m.u16(counter) + 1)
	return 0


## FUN_0053e370: resuelve la accion solicitada antes de avanzar el turno.
func f53e370() -> int:
	var flags := m.u8(0xa13413)
	if (flags & 2) == 0:
		return 0
	var done := 0
	var p := (m.u16(0xa13412) & 0x400) >> 10
	var a := m.u16(0xa13416)
	var b := m.u16(0xa13418)
	if (flags & 1) != 0 and (flags & 4) != 0:
		done = (m.u32(0xa15a44) >> 20) & 1
	else:
		match m.u16(0xa13414) & 0x3f:
			1: done = f578c40(p, a, b & 1, b & 2)
			2: done = f578da0(p, a, b & 1, b & 4)
			3: done = f578ee0(p, a, b)
			4: done = f578fb0(p, a, b)
			5: done = f579090(p, a, b)
			6: done = f579540(p)
			7: done = f579160(p)
			8: done = f579460()
			9: done = f5794a0()
			10: done = f5794e0()
			11: done = f5808b0()
			12: done = f579fe0()
			13: done = f579260(p)
			14: done = f579370(p, a, b)
			15: done = f53de40(p, a, b)
			16: done = f53e2a0(p, a)
			17: done = f53dee0(p)
			18: done = f53e100(p, a)
			19: done = f53e180(p)
			20: done = f53e220(p, a)
			_: return 0
	if done == 0:
		return 1
	if (flags & 1) != 0 and (flags & 4) == 0:
		f53ea40(0xf0a2, 0xa13428, 0x10)
	m.set_u8(0xa13413, m.u8(0xa13413) & 0xfd)
	return 0


## FUN_0053e6c0: inicia la espera de una accion y prepara su envio en red.
func f53e6c0() -> int:
	m.set_u32(0xa13412, (m.u32(0xa13412) & 0xfffffeff) | 0x200)
	m.set_u16(0xa13426, 0)
	if (m.u32(0xa13412) & 0x400) != 0 and (m.u16(0xa16180) & 0x100) != 0 and (m.u8(0xa13414) & 0x3f) != 3:
		var packet := m.local(0x12)
		m.set_u16(packet, m.u8(0xa13414) & 0x3f)
		m.copy(packet + 2, 0xa13416, 0x10)
		f53ea40(0xf0a1, packet, 0x12)
		m.set_u32(0xa15a44, m.u32(0xa15a44) & 0xffefffff)
		m.set_u32(0xa13412, m.u32(0xa13412) | 0x100)
	return 0


## FUN_0053e760: pide una accion con dos argumentos.
func f53e760(p: int, action: int, a: int, b: int) -> int:
	m.set_u16(0xa13412, (m.u16(0xa13412) & ~0x400) | ((p << 10) & 0x400))
	m.set_u16(0xa13416, a)
	m.set_u16(0xa13418, b)
	m.set_u16(0xa13414, (m.u16(0xa13414) & ~0x3f) | (action & 0x3f))
	return f53e6c0()


## FUN_0053e7c0: pide una accion con hasta ocho argumentos cortos.
func f53e7c0(p: int, action: int, src: int, count: int) -> int:
	m.set_u16(0xa13412, (m.u16(0xa13412) & ~0x400) | ((p << 10) & 0x400))
	m.set_u16(0xa13414, (m.u16(0xa13414) & ~0x3f) | (action & 0x3f))
	m.copy(0xa13416, src, mini(count, 8) * 2)
	return f53e6c0()


## FUN_0053e830: accion 1; aridad confirmada en ensamblador (reenvio por salto).
func f53e830(p: int, a: int, flag1: int, flag2: int) -> int:
	return f53e760(p, 1, a, int(flag1 != 0) | (int(flag2 != 0) << 1))


## FUN_0053e870: accion 2; aridad confirmada en ensamblador (reenvio por salto).
func f53e870(p: int, a: int, flag1: int, flag2: int) -> int:
	return f53e760(p, 2, a, int(flag1 != 0) | (int(flag2 != 0) << 2))


## FUN_0053e8b0: acumula argumentos cuando ya hay una accion 3 pendiente.
func f53e8b0(p: int, a: int, b: int) -> int:
	if (m.u32(0xa13412) & 0x200) != 0 and (m.u8(0xa13414) & 0x3f) == 3:
		m.set_u16(0xa13418, m.u16(0xa13418) + b)
		return 0
	return f53e760(p, 3, a, b)


## FUN_0053e8f0: acumula argumentos cuando ya hay una accion 4 pendiente.
func f53e8f0(p: int, b: int) -> int:
	if (m.u32(0xa13412) & 0x200) != 0 and (m.u8(0xa13414) & 0x3f) == 4:
		m.set_u16(0xa13418, m.u16(0xa13418) + b)
		return 0
	return f53e760(p, 4, 0, b)


## FUN_0053e930: solicita la accion 5.
func f53e930(p: int) -> int:
	return f53e760(p, 5, 0, 1)


## FUN_0053e950: solicita la accion 7.
func f53e950(p: int) -> int:
	return f53e760(p, 7, 0, 0)


## FUN_0053e100: pregunta opcional asociada a una carta; respuesta 0/1.
## Paso 0: cuadro Si/No con el mensaje 0xd y el nombre de la carta; paso 1: respuesta.
func f53e100(_p: int, card: int) -> int:
	if m.u8(0xa13426) == 0:
		m.set_u16(0xa13428, 0)
		if (card & 0xffff) != 0:
			# 53fac0 con 401010(card): nombre de la carta en el "%s" del mensaje 0xd.
			dialog_format(0xd, [{"card": card}])
			f540d60(1, 0)
			m.set_u8(0xa13426, 1)
			return 0
	else:
		m.set_u16(0xa13428, m.u16(0xa16178))
	return 1


## FUN_0053e180: la CPU acepta siempre; el humano decide sobre la carta 0x5f0.
func f53e180(p: int) -> int:
	if p != 0:
		m.set_u16(0xa13428, 1)
		return 1
	if m.u8(0xa13426) != 0:
		m.set_u16(0xa13428, m.u16(0xa16178))
		return 1
	m.set_u16(0xa13428, 0)
	# Cuadro Si/No con el mensaje 0xe y el nombre de la carta 0x5f0.
	dialog_format(0xe, [{"card": f401ad0(0x5f0)}])
	f540d60(1, 0)
	m.set_u8(0xa13426, 1)
	return 0


## FUN_0053e220: selecciona otra zona propia y devuelve su indice.
## Paso 0: mensaje 0xf; paso 1: el humano senala con el cursor otra zona de monstruo propia
## (mascara 0xf0) y hace clic.
func f53e220(_p: int, excluded: int) -> int:
	if m.u8(0xa13426) == 0:
		m.set_u16(0xa13428, 0)
		f5417e0(0xf)
		m.set_u8(0xa13426, 1)
		return 0
	if m.u8(0xa13426) != 1:
		return 1
	if f57a060(0xf0) != 0 and m.u32(0xa161ac) != (excluded & 0xffffffff):
		if f579890() != 0:
			m.set_u8(0xa13426, 2)
			m.set_u16(0xa13428, m.u32(0xa161ac))
			return 0
	return 0


## FUN_0053e2a0: CPU toma la primera zona ocupada; humano elige otra zona enemiga.
func f53e2a0(p: int, excluded: int) -> int:
	if m.u8(0xa13426) == 0:
		if p != 0:
			for z in 5:
				if z != excluded and (m.u32(DuelMem.zone((~p) & 1, z)) & 0xfff) != 0:
					m.set_u16(0xa13428, z)
					return 1
			return 1
		m.set_u16(0xa13428, 0)
		f5417e0(0x10)
		m.set_u8(0xa13426, 1)
		return 0
	if m.u8(0xa13426) != 1:
		return 1
	# El humano senala con el cursor otra zona de monstruo enemiga (mascara 0xf00000).
	if f57a060(0xf00000) != 0 and m.u32(0xa161ac) != (excluded & 0xffffffff) and f579890() != 0:
		m.set_u8(0xa13426, 2)
		m.set_u16(0xa13428, m.u32(0xa161ac))
		return 0
	return 0


## FUN_00542e00: primera copia boca arriba del monstruo con el ID indicado.
func f542e00(p: int, id: int) -> int:
	for z in 5:
		var zone := DuelMem.zone(p & 1, z)
		var index := m.u16(zone) & 0xfff
		if index != 0 and (m.u8(zone + 6) & 2) != 0 and f401a70(index) == s16(id):
			return z
	return -1


## FUN_00543070: misma busqueda de monstruo boca arriba que 0x542e00.
func f543070(p: int, id: int) -> int:
	return f542e00(p, id)


## FUN_005430d0: cuenta copias del monstruo en las cinco zonas, incluso boca abajo.
func f5430d0(p: int, id: int) -> int:
	var count := 0
	for z in 5:
		var index := m.u16(DuelMem.zone(p & 1, z)) & 0xfff
		if index != 0 and f401a70(index) == s16(id):
			count += 1
	return count


## FUN_005435a0: magia de campo o hueco disponible en las zonas de magia/trampa.
func f5435a0(p: int, index: int) -> int:
	var prop := f401a20(index)
	var kind := (prop >> 20) & 0x1f
	if kind > 0x14 and kind < 0x17 and ((prop >> 17) & 7) == 2:
		return 1
	for z in range(5, 10):
		if (m.u32(DuelMem.zone(p & 1, z)) & 0xfff) == 0:
			return 1
	return 0


## FUN_004073a0: indice de la entrada actual de la cadena.
func f4073a0(index: int) -> int:
	m.set_u16(0xa11622, index)
	return 0


## FUN_004073b0: direccion de la entrada actual de la cadena.
func f4073b0() -> int:
	return 0xa11624 + m.u16(0xa11622) * 4


## FUN_004073c0: tipo de la entrada actual de la cadena (5 bits bajos de 0xa11824).
func f4073c0() -> int:
	return m.u8(0xa11824 + m.u16(0xa11622) * 2) & 0x1f


## FUN_00541d10: clasifica los efectos de volteo, con excepciones segun el modo.
func f541d10(id: int, mode: int) -> int:
	id &= 0xffff
	if id == 0x280:
		return int(mode == 0)
	if id == 0x2df or id == 0x492:
		return mode & 0xffffffff
	return int(id in [0x27, 0x52, 0x53, 0x65, 0xaa, 0xdf, 0x109, 0x1ab, 0x1cd, 0x1d4,
		0x1e9, 500, 0x21b, 0x21c, 0x231, 0x246, 0x249, 0x24e, 0x259, 0x262, 0x267,
		0x2d9, 0x2db, 0x2fa, 0x418, 0x452, 0x45c, 0x48b, 0x4e6, 0x4e7, 0x4e8,
		0x51b, 0x532, 0x539, 0x53a, 0x59b, 0x59c, 0x5e8, 0x5f1, 0x5f4])


## FUN_00547c60: ATK calculado por 0x546470, segundo entero de su salida.
func f547c60(p: int, z: int) -> int:
	var out := m.local(12)
	f546470(p, z, out)
	return m.u32(out + 4)


## FUN_00547c80: DEF calculada por 0x546470, tercer entero de su salida.
func f547c80(p: int, z: int) -> int:
	var out := m.local(12)
	f546470(p, z, out)
	return m.u32(out + 8)


## FUN_00403010: emite la numeracion de la cadena o su ultimo eslabon.
func f403010(entries: int, resolving: int) -> int:
	var count := m.u16(entries + 0x140)
	if resolving == 0:
		for i in count:
			var flags := m.u16(entries + 2 + i * 0x14)
			issue((flags << 15) | 10, (flags >> 4) & 0x3f, i + 1, 0)
	else:
		var flags := m.u16(entries - 0x12 + count * 0x14)
		issue((flags << 15) | 0xb, (flags >> 4) & 0x3f, count, 0)
	return 0


## FUN_004030a0: la animacion de cadena ya no esta ocupada.
func f4030a0() -> int:
	return int(not anim_busy())


func _f_chain_advance(delta: int = 2) -> void:
	var flags := m.u8(0xa15fce)
	m.set_u8(0xa15fce, (flags & 1) | (((flags & 0xfe) + delta) & 0xfe))


## FUN_0053c2a0: prepara efectos, ofrece respuestas en prioridad y monta la cadena.
func f53c2a0() -> int:
	var state := m.u8(0xa15fce) >> 1
	if state == 0:
		m.set_u16(0xa15fce, m.u16(0xa15fce) & 0xff)
		_f_chain_advance()
		state = 1
	var entry := 0xa15e80 + m.u8(0xa15fcf) * 0x14
	if state == 1:
		var at := f56e540(m.u16(entry))
		m.set_u32(0xa16080, 0 if at == -1 else effect_column(at, 0x10))
		m.set_u32(0xa16084, 0 if at == -1 else effect_column(at, 0x14))
		if (m.u8(entry + 4) & 1) != 0:
			m.set_u32(0xa16080, 0)
		if (m.u8(entry + 4) & 2) != 0:
			m.set_u32(0xa16084, 0)
		f54eed0(m.u16(entry + 2) & 1, m.u16(entry), (m.u16(entry + 2) >> 4) & 0x3f)
		m.set_u32(0xa15a44, m.u32(0xa15a44) & 0xfebfffff)
		m.set_u16(0xa15fe4, 0)
		_f_chain_advance()
		return 1
	if state == 2 or state == 4:
		var target := m.u32(0xa16080 if state == 2 else 0xa16084)
		if target == 0:
			_f_chain_advance(4)
			return 1
		if f53b930(entry) != 0:
			f53ea40(0xf091 if state == 2 else 0xf081, entry, 0x14)
		_f_chain_advance()
		state += 1
	if state == 3 or state == 5:
		var done_flag := 0x1000000 if state == 3 else 0x400000
		if f53b930(entry) == 0:
			var previous := 0 if m.u16(0xa15fc0) < 2 else 0xa15e58 + m.u16(0xa15fc0) * 0x14
			var target := m.u32(0xa16080 if state == 3 else 0xa16084)
			var done := invoke_original(target, [entry, previous])
			if done != 0:
				m.set_u32(0xa15a44, m.u32(0xa15a44) | done_flag)
		if (m.u32(0xa15a44) & done_flag) != 0:
			_f_chain_advance()
		return 1
	if state == 6:
		m.set_u8(0xa15fcf, m.u8(0xa15fcf) + 1)
		if m.u8(0xa15fcf) < m.u16(0xa15fc0):
			m.set_u16(0xa15fce, (m.u16(0xa15fce) & 0xff03) | 2)
			return 1
		_f_chain_advance()
		state = 7
	if state == 7:
		if m.u16(0xa15fc0) < 2:
			m.set_u16(0xa15fce, (m.u16(0xa15fce) & 0xff17) | 0x16)
			return 1
		if (m.u16(0xa16180) & 0x100) != 0:
			var count := m.u16(0xa15fc0)
			f53ed60(0xf061, count, 0, 0)
			var packet := m.local(0x16)
			for i in count:
				m.set_u16(packet, i)
				m.copy(packet + 2, 0xa15e80 + i * 0x14, 0x14)
				f53ea40(0xf062, packet, 0x16)
			f53ed60(0xf063, count, 0, 0)
			m.set_u32(0xa15a44, m.u32(0xa15a44) & 0xefffffff)
		_f_chain_advance()
		return 1
	if state == 8:
		f403010(0xa15e80, 0)
		_f_chain_advance()
		return 1
	if state == 9:
		if f4030a0() != 0:
			_f_chain_advance()
		return 1
	if state == 10:
		if (m.u16(0xa16180) & 0x100) != 0 and (m.u32(0xa15a44) & 0x10000000) == 0:
			return 1
		m.set_u8(0xa16088, m.u8(0xa16088) & 0xfe)
		_f_chain_advance()
		state = 11
	var last := 0xa15e6c + m.u16(0xa15fc0) * 0x14
	if state == 11 or state == 13:
		var player := m.u8(last + 2) & 1
		if state == 11:
			player = 1 - player
		if f552090(last, player) == 0:
			_f_chain_advance()
		else:
			m.set_u8(0xa16092, m.u8(0xa16092) & 0x7f)
			m.set_u8(0xa16090, 0)
		_f_chain_advance()
		return 1
	if state == 12 or state == 14:
		var player := m.u8(last + 2) & 1
		if state == 12:
			player = 1 - player
		if f53bd50(last, player) == 0:
			return 1
		if m.s8(0xa16092) < 0:
			m.set_u16(0xa15fce, (m.u16(0xa15fce) & 0xff03) | 2)
			return 1
		_f_chain_advance()
		return 1
	m.set_u16(0xa15fce, m.u16(0xa15fce) & 0xfffe)
	m.set_u16(0xa15fd0, 1)
	return 1


## FUN_0053bb70: el efecto usa una magia/trampa que debe abandonar su ubicacion al resolverse.
## El descriptor se recibe en ESI, confirmado en ensamblador.
func f53bb70(entry: int) -> int:
	var index := m.u16(entry)
	var kind := ctype(index)
	if (m.u8(entry + 2) & 0xe) == 6 and kind != 0x15:
		return 0
	if kind < 0x15:
		return 0
	var subtype := csub(index) if kind <= 0x16 else 0
	if subtype < 2 or subtype > 4:
		if f401a70(index) not in [0x4ce, 0x47, 0x15b, 0x291, 0x4ea, 0x609]:
			return 1
	return (m.u8(entry + 4) & 8) >> 3


func _f_resolve_advance() -> void:
	var flags := m.u8(0xa15fd0)
	m.set_u8(0xa15fd0, (flags & 1) | (((flags & 0xfe) + 2) & 0xfe))


func _f_resolve_finish_effect() -> void:
	m.set_u32(0xa15fd0, (m.u32(0xa15fd0) & 0xffffffc9) | 200)


## Retira la carta usada por un efecto (bloques de 0x53ca00 antes y despues de su rutina).
func _f_resolve_remove(entry: int, negated: bool) -> void:
	var moving := m.u32(0xa15fdc)
	if (moving & 0xfff) == 0:
		return
	var flags := m.u16(entry + 2)
	var p := flags & 1
	var loc := (flags >> 4) & 0x3f
	var alternate := f543010(0, 0x453) > 0 or f543010(1, 0x453) > 0
	if alternate:
		issue((flags << 15) | 0x7e, moving & 0xffff, moving >> 16, loc)
	else:
		if negated:
			issue((flags << 15) | 0x79, loc, 1, 0)
		else:
			issue((flags << 15) | 0xb5, ((loc & 0xff) << 8) | p, 0xe00 | ((moving >> 12) & 1), 0)
		issue((flags << 15) | 0x7d, moving & 0xffff, moving >> 16, 0)
	var id := f401a70(moving & 0xfff)
	if negated and id == 0x14d:
		f54cbb0(p, 0x58f)
		f54cbb0(1 - p, 0x58f)
	elif not alternate and id == 0x412:
		f53baa0((((moving & 0xfffff78d) << 19) | (moving & 0xfff) | 0x3c6e0000) & 0xffffffff, 0)
	if not alternate:
		f56e2e0((moving >> 12) & 1, 1)


## FUN_0053ca00: resuelve eslabones en orden inverso, con negacion y efectos continuos.
func f53ca00() -> int:
	var state := (m.u32(0xa15fd0) >> 1) & 0x7f
	var count := m.u16(0xa15fc0)
	var entry := 0xa15e6c + count * 0x14
	match state:
		0:
			if (m.u16(0xa16180) & 0x100) != 0:
				f53ed60(0xf061, count, 0, 0)
				var packet := m.local(0x16)
				for i in count:
					m.set_u16(packet, i)
					m.copy(packet + 2, 0xa15e80 + i * 0x14, 0x14)
					f53ea40(0xf062, packet, 0x16)
				f53ed60(0xf064, count, 0, 0)
				m.set_u32(0xa15a44, m.u32(0xa15a44) & 0xefffffff)
		1:
			f403010(0xa15e80, 1)
		2:
			if f4030a0() == 0:
				return 1
		3:
			if (m.u16(0xa16180) & 0x100) != 0 and (m.u32(0xa15a44) & 0x10000000) == 0:
				return 1
		4:
			var at := f56e540(m.u16(entry))
			m.set_u16(0xa15fd4, at) # ASM 53cb59: mov word ptr; 0xa15fd6 se conserva
			if at < 0:
				_f_resolve_finish_effect()
				return 1
			m.set_u32(0xa15fd8, effect_column(at, 0x4))
			if m.u32(0xa15fd8) == 0:
				_f_resolve_finish_effect()
				return 1
			var index := m.u16(entry)
			var kind := ctype(index)
			if kind < 0x15:
				var id := f401a70(index)
				if (f541d10(id, 1) != 0 or f541d10(id, 0) != 0) and (m.u8(entry + 4) & 4) != 0:
					_f_resolve_finish_effect()
					return 1
			else:
				var flags := m.u16(entry + 2)
				var suppressed := false
				if (flags & 0xe) != 6 and (m.u8(DuelMem.zone(flags & 1, (flags >> 4) & 0x3f) + 0x8f) & 4) != 0:
					suppressed = true
				var subtype := f53b880(index)
				var global := m.u32(0xa133ec)
				if subtype == 2 and (global & 0x200) != 0:
					suppressed = true
				if subtype == 3 and (global & 0x180) != 0:
					suppressed = true
				if kind == 0x15:
					suppressed = suppressed or (global & 0x40) != 0 or (subtype == 4 and (global & 0x800) != 0)
				elif kind == 0x16:
					suppressed = suppressed or (global & 0x20) != 0 or (subtype == 4 and (global & 0x400) != 0)
				if f401a70(index) == 0x603:
					m.set_u8(entry + 4, m.u8(entry + 4) & 0xfb)
				elif suppressed:
					issue((flags << 15) | 0xb1, (flags >> 4) & 0x3f, 1, 0)
					m.set_u8(entry + 4, m.u8(entry + 4) | 4)
			var flags := m.u16(entry + 2)
			var last := m.u8(0xa11948 + (flags & 1) * PS) - 1 if (flags & 0x3f0) == 0xe0 else 0
			f541cb0(0xa15fdc, f5419b0(flags & 1, (flags >> 4) & 0x3f, last))
			if f53bb70(entry) != 0:
				issue((flags << 15) | 0x78, (flags >> 4) & 0x3f, 0, 0)
			if (m.u16(entry + 4) & 0xc) == 0xc:
				_f_resolve_remove(entry, true)
				_f_resolve_finish_effect()
				return 1
			m.set_u16(0xa15fe0, 0x80)
		5:
			if f53b930(entry) != 0:
				var packet := m.local(0x2c)
				m.set_u16(packet, count)
				m.set_u16(packet + 2, int(count >= 2))
				m.copy(packet + 4, entry, 0x14)
				if count >= 2:
					m.copy(packet + 0x18, entry - 0x14, 0x14)
				f53ea40(0xf071, packet, 0x2c)
			m.set_u32(0xa15a44, m.u32(0xa15a44) & 0xfbffffff)
		6:
			if f53b930(entry) != 0:
				# Eslabon del rival en red: lo resuelve el y avisa con 0xf073 (bit 0x4000000),
				# que espera el estado 7. Yugi devuelve 1 sin avanzar (ASM 53d1f2 -> 53d4a5) y se
				# quedaria aqui para siempre: fallo latente de una rama nunca ejecutada. Joey
				# (5bb720 caso 6) avanza al 7, que espera su bit 0x100000; el port hace lo mismo.
				_f_resolve_advance()
				return 1
			var target := m.u32(0xa15fd8)
			var result := invoke_original(target, [entry, 0 if count < 2 else entry - 0x14])
			m.set_u8(0xa15fe0, result)
			if m.u8(0xa15fe0) != 0:
				return 1
			m.set_u32(0xa15a44, m.u32(0xa15a44) | 0x4000000)
		7:
			if (m.u32(0xa15a44) & 0x4000000) == 0:
				return 1
			if f53bb70(entry) != 0:
				_f_resolve_remove(entry, false)
			_f_resolve_finish_effect()
			return 1
		100:
			var flags := m.u16(entry + 2)
			if (flags & 0x3f0) <= 0xa0:
				var at := 0xa119ec + (flags & 1) * PS + ((flags >> 4) & 0x3f) * 0x94
				m.set_u8(at, m.u8(at) & 0xfe)
			# Kaiba (53f0d0) repite este estado mientras 53df70 devuelva 1.
			if f53b8b0() != 0 and rules_game == "kaiba":
				return 1
			m.set_u16(0xa15fc0, count - 1)
			if m.u16(0xa15fc0) != 0:
				m.set_u32(0xa15fd0, m.u32(0xa15fd0) & 0xffffff01)
				return 1
			m.set_u32(0xa15fd0, m.u32(0xa15fd0) & 0xfffffffe)
			return 1
		_:
			m.set_u32(0xa15fd0, m.u32(0xa15fd0) & 0xfffffffe)
			return 1
	_f_resolve_advance()
	return 1


## FUN_0053b4e0: cola local y confirmación de comandos remotos.
func f53b4e0() -> int:
	var phase := m.u8(0xa13412)
	if phase == 0:
		var count := m.u16(DuelMem.QUEUE_COUNT)
		if count == 0:
			return 0
		command_popping.emit()
		m.copy(DuelMem.CMD, DuelMem.QUEUE, 8)
		count -= 1
		m.set_u16(DuelMem.QUEUE_COUNT, count)
		if count != 0:
			m.copy(DuelMem.QUEUE, DuelMem.QUEUE + 8, count * 8)
		m.set_u32(0xa15a44, m.u32(0xa15a44) | 0x4000)
		m.set_u32(DuelMem.CMD_STATE, m.u32(DuelMem.CMD_STATE) | DuelMem.CMD_RUNNING)
		if m.u8(0xa16181) & 1:
			f53ea40(0xf041, DuelMem.CMD, 8)
			m.set_u32(0xa15a44, m.u32(0xa15a44) & 0xffffbfff)
			m.set_u16(0xa15940, 0)
			m.set_u16(0xa15942, 0)
		m.set_u32(DuelMem.CMD_STATE, m.u32(DuelMem.CMD_STATE) & 0xf01fc000)
		m.set_u8(0xa13412, 1)
		executed += 1
		phase = 1
	if phase == 1:
		dispatch()
		if is_running():
			return 1
		m.set_u8(0xa13412, 2)
	elif phase != 2:
		return 0
	if m.u32(0xa15a44) & 0x4000:
		m.set_u16(0xa15942, 0)
		m.set_u8(0xa13412, 0)
		if commands_from_outside() and not is_running():
			if m.u16(DuelMem.QUEUE_COUNT) != 0:
				return 1
			f53db50(0)
		if m.u16(DuelMem.QUEUE_COUNT) == 0:
			return 0
	return 1


func f53b650() -> int:
	var state := m.u8(0xa15bca)
	if state == 0:
		m.copy(DuelMem.CMD, 0xa15bc2, 8)
		m.set_u32(DuelMem.CMD_STATE, (m.u32(DuelMem.CMD_STATE) & 0xf01fff80) | DuelMem.CMD_RUNNING)
		m.set_u8(0xa15bca, 1)
	elif state != 1:
		if state != 2:
			m.set_u32(0xa15a44, m.u32(0xa15a44) & 0xffffdfff)
			return 0
		f53ed60(0xf043, 0, 0, 0)
		m.set_u8(0xa15bca, state + 1)
		return 1
	dispatch()
	if not is_running():
		m.set_u8(0xa15bca, m.u8(0xa15bca) + 1)
	return 1


func f53bc40(effect: int, p: int, loc: int, index: int) -> int:
	if loc == 0:
		var zone := DuelMem.zone(p & 1, index)
		if (m.u32(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 2) != 0 and f401a70(m.u16(zone) & 0xfff) == 0x5f5:
			if ((f401a20(m.u16(effect)) >> 20) & 31) == 0x16 and f542f30(0, 0x58a) == 0 and f542f30(1, 0x58a) == 0 and f401a70(m.u16(effect)) != 0x603:
				return 8
	elif loc == 5:
		return 8 if f551dc0(effect, p, index + 5) != 0 else 0
	elif loc == 11:
		return 8 if f551f50(effect, p, index) != 0 else 0
	return 0


## FUN_0053db50: archivo de repetición; la fuente es el flujo cargado por el núcleo.
func f53db50(all_commands: int) -> int:
	while true:
		if incoming_left() == 0:
			m.set_u8(0xa114b5, m.u8(0xa114b5) | 0x40)
			return 0
		fetch_incoming()
		if all_commands == 0:
			return 0
	return 0


## FUN_0053ea90: refleja un comando recibido al punto de vista local.
func f53ea90() -> int:
	var a := m.u16(0xa15744)
	var b := m.u16(0xa15746)
	var c := m.u16(0xa15748)
	m.set_u16(0xa15bc2, m.u16(0xa15742) ^ 0x8000)
	m.set_u16(0xa15bc4, a)
	m.set_u16(0xa15bc6, b)
	m.set_u16(0xa15bc8, c)
	match m.u16(0xa15bc2) & 0xfff:
		4:
			if a < 2:
				a = 1 - a
			m.set_u32(0xa15a44, m.u32(0xa15a44) | 0x400)
		8:
			a = 1 - a
		0x30, 0x31:
			m.set_u16(0xa15bc6, a)
			a = b
			if (m.u16(0xa15bc2) & 0xfff) == 0x31:
				m.set_u16(0xa15bc8, ((c & 255) << 8) | (c >> 8))
		0x64, 0x65, 0x66, 0x67, 0x68, 0x6a, 0x7d, 0x7e, 0xc2, 0xcb, 0xd2, 0xd3, 0xd4, 0xd7, 0xdb, 0xdc, 0xdd, 0xde:
			a ^= 0x1000
		0x77, 0xaa:
			m.set_u16(0xa15bc6, b ^ 0x1000)
		0x71:
			# Invocacion especial: 405d10 coloca la entrada (c << 16) | b con su bit 12 (dueno).
			# Yugi no lo invierte (fallo latente de su red): el rival veria la carta como suya.
			m.set_u16(0xa15bc6, b ^ 0x1000)
		0x83, 0x84, 0x85, 0xb5:
			a = (a & 0xff00) | ((1 - (a & 255)) & 255)
			m.set_u16(0xa15bc6, (b & 0xff00) | ((1 - (b & 255)) & 255))
		0x86, 0x87:
			m.set_u16(0xa15bc6, (b & 0xff00) | ((1 - (b & 255)) & 255))
			if (c & 255) == 0 or ((c & 255) > 2 and (c & 255) != 5):
				return 0
			a = (a & 0xff00) | ((1 - (a & 255)) & 255)
		0xa4:
			a = (a & 0xff00) | ((1 - (a & 255)) & 255)
	m.set_u16(0xa15bc4, a)
	return 0


## FUN_0053eda0: receptor del duelo en red, un paquete por fotograma en 0xa15740 (tipo) y
## 0xa15742 (datos). En Yugi 583e00 devuelve cero y todo lo que sigue es inalcanzable; Joey usa
## los mismos tipos en 5bd2d0, pero con indices de jugador absolutos. El port conserva el
## protocolo espejado de Yugi (cada lado es el jugador 0 y 53ea90/f062/f051... invierten el
## jugador), que es el que entiende el motor portado. Sin sesion, bit 4 de a133f2.
func f53eda0() -> int:
	if not _net_active():
		m.set_u8(0xa133f2, m.u8(0xa133f2) | 0x10)
		return 0
	if (m.u32(0xa15a44) & 0x100) != 0:
		return 1
	m.set_u16(0xa15740, 0xf000)
	if _net_receive(0xa15740, 0x300) == 0:
		return 1
	var kind := m.u16(0xa15740)
	match kind:
		0xf000:
			return 1
		0xf001:
			# 53d970 lo envia al ceder el inicio del turno, pero el receptor de Yugi no tiene
			# caso (ASM 53ee36 salta al de error) y Joey no lo envia: fallo latente de una rama
			# nunca ejecutada. Es solo un aviso; el port lo ignora en vez de cortar la sesion.
			return 1
		0xef00:
			m.set_u8(0xa133f2, m.u8(0xa133f2) | 0x10)
			return 0
		0xf002:
			_net_flag(0x80)
		0xf003:
			# Resultado del rival (53d9d0): bits 5-6 de a133f2.
			_net_flag(0x100)
			var flags := m.u8(0xa133f2)
			m.set_u16(0xa133f2, m.u16(0xa133f2) ^ ((((m.u8(0xa15742) << 5) & 0xff) ^ flags) & 0x60))
		0xf004:
			# Mazo del rival (5bd210 de Joey): cuentas en los dos bytes y las cartas detras.
			var main := m.u8(0xa15742)
			var fusion := m.u8(0xa15743)
			m.set_u16(0xa11482, fusion)
			m.set_u16(0xa1147e, main)
			m.set_u16(0xa11480, 0)
			for i in main:
				m.set_u16(0xa113a2 + i * 2, m.u16(0xa15744 + i * 2))
			for i in fusion:
				m.set_u16(0xa11460 + i * 2, m.u16(0xa15744 + (main + i) * 2))
			_net_flag(0x20)
		0xf005:
			# 4373f0: semilla de la sesion (la usa el siguiente duelo; la reparte la sala).
			net_seed = m.u16(0xa15742) | (m.u16(0xa15744) << 16)
			_net_flag(0x40)
		0xf006:
			# Joey 5bd2d0: mensaje rapido del rival (texto 0x9c4 + n) a la ventana de conversacion
			# (48dd00). Yugi no tiene caso; la ventana aun no esta portada (D17).
			present("lan_chat", {"message": m.u16(0xa15742)})
		0xf041:
			f53ea90()
			_net_flag(0x2000)
			m.set_u8(0xa15bca, 0)
		0xf042:
			m.set_u16(0xa15942, 0)
		0xf043:
			_net_flag(0x4000)
		0xf051:
			m.copy(0xa160be, 0xa15742, 0x14)
			m.set_u16(0xa160c0, m.u16(0xa160c0) ^ 1)
			match m.u16(0xa160c0) >> 10:
				5, 6, 7, 8, 0x10, 0x11, 0x14, 0x15, 0x19, 0x1a, 0x1b, 0x1d, 0x1e:
					m.set_u16(0xa160c4, m.u16(0xa160c4) ^ 1)
					m.set_u16(0xa160c6, m.u16(0xa160c6) ^ 1)
				0xd, 0xe:
					m.set_u16(0xa160c6, m.u16(0xa160c6) ^ 0x101)
				0xf:
					m.set_u16(0xa160c6, m.u16(0xa160c6) ^ 1)
				0x13:
					if m.u16(0xa160c4) != 0xffff:
						m.set_u16(0xa160c4, m.u16(0xa160c4) ^ 1)
					if m.u16(0xa160c6) != 0xffff:
						m.set_u16(0xa160c6, m.u16(0xa160c6) ^ 1)
			m.set_u8(0xa16093, m.u8(0xa16093) & 1)
			m.set_u8(0xa16094, m.u8(0xa16094) & 0xfe)
			_net_flag(0x8000)
		0xf052, 0xf055:
			_net_flag(0x10000)
		0xf053, 0xf056:
			f53bae0(0 if kind == 0xf053 else 1, 0xa15742)
			m.set_u8(0xa16092, m.u8(0xa16092) | 0x80)
			_net_flag(0x10000)
		0xf054:
			m.copy(0xa160d2, 0xa15742, 0x14)
			m.set_u16(0xa160d4, m.u16(0xa160d4) ^ 1)
			m.set_u8(0xa160d8, (1 - m.u8(0xa160d8)) & 0xff)
			m.set_u8(0xa160da, (1 - m.u8(0xa160da)) & 0xff)
			m.copy(0xa160be, 0xa160d2, 0x14)
			m.set_u8(0xa16093, m.u8(0xa16093) & 1)
			m.set_u8(0xa16094, m.u8(0xa16094) | 1)
			_net_flag(0x8000)
		0xf057:
			m.set_u32(0xa15b8c, m.u32(0xa15b8c) | 1)
			m.set_u16(0xa15b96, m.u16(0xa15746))
			m.set_u16(0xa15b90, 0)
			m.set_u16(0xa15b92, m.u16(0xa15742))
			m.set_u16(0xa15b94, m.u16(0xa15744))
		0xf058:
			m.set_u32(0xa15b8c, m.u32(0xa15b8c) | 2)
			m.set_u16(0xa15b98, m.u16(0xa15742))
		0xf059:
			_net_notice()
		0xf05a:
			m.copy(0xa15be0, 0xa15742, 0x14)
			f57c7a0()
		0xf05b:
			_net_flag(0x1000)
		0xf061:
			m.set_u16(0xa15b88, m.u16(0xa15742))
		0xf062:
			var at := 0xa15a48 + m.u16(0xa15742) * 0x14
			m.copy(at, 0xa15744, 0x14)
			m.set_u16(at + 2, m.u16(at + 2) ^ 1)
		0xf063, 0xf064:
			f403010(0xa15a48, 0 if kind == 0xf063 else 1)
			_net_flag(0x8000000)
		0xf065:
			_net_flag(0x10000000)
		0xf071:
			m.copy(0xa15b9a, 0xa15746, 0x28)
			m.set_u8(0xa15bcd, 0)
			var low := m.u8(0xa15bce)
			low ^= ((m.u8(0xa15742) << 1) ^ low) & 0xfe
			low ^= (low ^ m.u8(0xa15744)) & 1
			m.set_u8(0xa15bce, low)
			_net_flag(0x2000000)
		0xf072:
			f53b960(m.u16(0xa15742), (m.u16(0xa15746) << 16) | m.u16(0xa15744),
					(m.u16(0xa1574a) << 16) | m.u16(0xa15748))
		0xf073:
			_net_flag(0x4000000)
		0xf081, 0xf091:
			m.copy(0xa15b9a, 0xa15742, 0x28)
			m.set_u8(0xa15b9c, m.u8(0xa15b9c) & 0xfe)
			m.set_u8(0xa15bcc if kind == 0xf081 else 0xa15bcb, 0)
			m.set_u16(0xa15bb0, m.u16(0xa15bb0) ^ 1)
			_net_flag(0x200000 if kind == 0xf081 else 0x800000)
		0xf082, 0xf092:
			m.set_u32(0xa15a44, (m.u32(0xa15a44) & 0xfffff7ff) | (0x400000 if kind == 0xf082 else 0x1000000))
			m.copy(0xa15e80 + m.u8(0xa15fcf) * 0x14, 0xa15742, 0x14)
		0xf0a1:
			f53e7c0(0, m.u16(0xa15742), 0xa15744, 8)
			m.set_u16(0xa13412, m.u16(0xa13412) | 0x100)
		0xf0a2:
			m.copy(0xa13428, 0xa15742, 0x10)
			m.set_u32(0xa15a44, (m.u32(0xa15a44) & 0xfffff7ff) | 0x100000)
		0xf0b1:
			var code := (m.u16(0xa15744) << 16) | m.u16(0xa15742)
			f53baa0(code, code)
		_:
			# Tipo desconocido: se avisa al rival y la sesion se da por perdida.
			f53ed60(0xef00, 0, 0, 0)
			m.set_u8(0xa133f2, m.u8(0xa133f2) | 0x10)
			return 0
	return 1

## Semilla recibida con 0xf005 (4373f0); -1 si no ha llegado ninguna.
var net_seed := -1

func _net_flag(bit: int) -> void:
	m.set_u32(0xa15a44, m.u32(0xa15a44) | bit)

## Caso 0xf059 de 53eda0: aviso que el rival deja para el jugador local (56a380 remoto). Los
## datos llegan con el punto de vista del rival: se invierten los jugadores segun el aviso.
func _net_notice() -> void:
	var p := m.u16(0xa15742)
	var kind := m.u16(0xa15744)
	var low := m.u16(0xa15746)
	var high := m.u16(0xa15748)
	match kind:
		5, 6, 7, 8, 0x10, 0x11, 0x19, 0x1a, 0x1b, 0x1d, 0x1e:
			high = (high & 0xff00) | ((1 - (high & 0xff)) & 0xff)
			low = (low & 0xff00) | ((1 - (low & 0xff)) & 0xff)
		0xd, 0xe:
			high = ((high & 0xff) << 8) | (high >> 8)
		0xf:
			high = (1 - high) & 0xffff
		0x13:
			var swap := low
			low = high
			high = swap
	f56a380(p, kind, (high << 16) | low)


## FUN_0053bd50: decisión de respuesta humana/CPU en una cadena.
func f53bd50(effect: int, p: int) -> int:
	var state := m.u8(0xa16090)
	if state == 0:
		m.set_u16(0xa16088, m.u16(0xa16088) | 1)
		if (m.u32(0xa16090) & 0x400000) != 0 and m.u16(0xa1608a) == (m.u16(effect + 2) >> 10):
			m.set_u32(0xa16090, m.u32(0xa16090) & 0xffbfffff)
		m.set_u8(0xa16090, 1)
		state = 1
	match state:
		1:
			if p != 0:
				m.set_u8(0xa16090, 100 if (m.u8(0xa16181) & 1) != 0 else 200)
				return 0
			# Cuadro Si/No: mensaje 7 (monstruo) u 8 con el nombre de la carta (53fac0/401010).
			var template := 7 if ((f401a20(m.u16(effect)) >> 20) & 31) < 0x15 else 8
			dialog_format(template, [{"card": m.u16(effect)}])
			f540d60(1, 0)
			m.set_u8(0xa16090, 2)
			return 0
		2:
			if m.u16(0xa16178) != 0:
				m.set_u16(0xa13408, m.u16(0xa13408) & 0xfffc)
				m.set_u8(0xa16090, 10)
				return 0
			return 1
		10:
			# 53bd50 caso 10: llama a 57a060 pero decide solo por el objeto bajo el cursor
			# (5407e0); sin objeto, o con la tecla 2, borra la accion y el clic derecho vuelve
			# a la pregunta Si/No (estado 1). Traza Frida 2026-10-08, comando 514.
			f57a060(0xee if (m.u16(0xa133f2) & 1) != 0 else 0xf)
			if f5407e0() != 0 and (m.u32(0xa114a8) & 2) == 0:
				var owner := m.u32(0xa161a4)
				var loc := m.u32(0xa161a8)
				var index := m.u32(0xa161ac)
				if f53a160() != 0 or (m.u16(0xa13408) & 1) == 0:
					m.set_u8(0xa1340c, 0)
					present("card_menu_close")
					if loc == 0 or loc == 5 or loc == 10 or loc == 11:
						if owner == 0 and f5407b0() != 0:
							var mask := f53bc40(effect, 0, loc, index)
							m.set_u16(0xa1340a, mask)
							m.set_u16(0xa13408, (m.u16(0xa13408) & 0xfffe) | int(mask != 0))
					elif loc >= 12 and loc <= 15:
						f571330(owner, loc)
				f53a130()
				if (m.u16(0xa13408) & 1) == 0:
					m.set_u8(0xa1340c, 0)
					present("card_menu_close")
				else:
					f53a1a0()
				if m.u16(0xa13408) & 2:
					m.set_u8(0xa16090, 11)
				return 0
			m.set_u16(0xa13408, m.u16(0xa13408) & 0xfffe)
			m.set_u8(0xa1340c, 0)
			present("card_menu_close")
			if m.u32(0xa114a8) & 0x102:
				m.set_u8(0xa16090, 1)
			return 0
		11:
			var descriptor := m.u16(0xa1340e)
			var loc := descriptor >> 9
			if loc == 0 or loc == 5:
				m.set_u16(0xa13408, m.u16(0xa13408) & 0xfffd)
				var zone_index := m.u8(0xa13410) + loc
				if (m.u8(DuelMem.zone((descriptor >> 8) & 1, zone_index) + 6) & 2) == 0:
					issue(((descriptor & 0xff01) << 7) | 0x91, zone_index, 0, 0)
					descriptor = m.u16(0xa1340e)
				var code := ((((descriptor & 0xffffff03) << 8) | m.u16(effect + 2)) & 0xfffffc40) | 0x40
				code = (code << 15) | (((m.u8(0xa13410) + (descriptor >> 9)) & 31) << 16) | m.u16(0xa13404)
				f53bac0(code, m.u32(effect + 6))
			elif loc == 11:
				f570040(1, 1, effect)
				if m.u16(0xa13408) & 2:
					return 0
			m.set_u32(0xa16090, (m.u32(0xa16090) & 0xffbfffff) | 0x800000)
			return 1
		100:
			f53ea40(0xf054, effect, 20)
			m.set_u8(0xa16090, 101)
			m.set_u32(0xa16090, m.u32(0xa16090) & 0xff7fffff)
			m.set_u32(0xa15a44, m.u32(0xa15a44) & 0xfffeffff)
			return 0
		101:
			return (m.u32(0xa15a44) >> 16) & 1
		200:
			if f57fb00(effect) != 0:
				m.set_u32(0xa16090, m.u32(0xa16090) | 0x800000)
	return 1

## FUN_00404070: reacción de retrato del comando; objetos gráficos pasan a present().
func f404070() -> int:
	var state := m.u32(0xa1572c)
	if (state & 0x7f) == 0:
		present("portrait_reaction", {"player": m.u16(0xa14f20) >> 15, "card_id": m.u16(0xa14f22), "reaction": m.u16(0xa14f26)})
		m.set_u32(0xa1572c, state ^ (((state + 1) ^ state) & 0x7f))
	# Las animaciones nativas se entregan al sistema de presentación del porte.
	# El estado de reglas no depende de los objetos de la ventana de Windows.
	f4376e0()
	m.set_u32(0xa1572c, m.u32(0xa1572c) & 0xefffffff)
	return 0

## FUN_00461350: panel de fases del original. Con un clic sobre una ficha devuelve 3 (pasar a
## batalla desde principal 1, si se puede atacar), 4 (principal 2 desde batalla) o 5 (fin de
## turno); si no, -1. La fase que muestra el panel (+0x160) es la actual.
func f461350() -> int:
	var shown := (m.u8(0xa133f2) >> 1) & 7
	var hover := f460f80()
	var result := -1
	if shown == 2 and hover == 3 and f571d30(0) != 0:
		result = 3
	if shown == 3 and hover == 4:
		result = 4
	elif hover == 5:
		result = 5
	if ui_mouse_click:
		return result
	return -1

## FUN_004613d0: cola de llamada original conserva el resultado EAX de461350.
func f4613d0() -> int:
	return f461350()

## FUN_0053f8b0: mazo inicial y copias de colección desde la tabla59df50.
func f53f8b0() -> int:
	m.set_u16(0xa1139e, 0)
	m.set_u16(0xa113a0, 0)
	m.set_u16(0xa1139c, 0)
	for i in range(1, 41):
		var index := f401ad0(m.u16(0x59df50 + i * 4))
		var count := m.u16(0xa1139c)
		m.set_u16(0xa112c0 + count * 2, index)
		m.set_u16(0xa1139c, count + 1)
		f540270(index, f53f860(index))
		var a := 0xa1012c + index * 2
		m.set_u16(a, m.u16(a) | 0x4000)
	var fusion_count := m.u32(0x59df50 + 41 * 4)
	if fusion_count & 0x80000000:
		return 0
	for i in range(fusion_count):
		var index := f401ad0(m.u16(0x59df50 + (42 + i) * 4))
		var count := m.u16(0xa113a0)
		m.set_u16(0xa1137e + count * 2, index)
		m.set_u16(0xa113a0, count + 1)
		f540270(index, f53f860(index))
		var a := 0xa1012c + index * 2
		m.set_u16(a, m.u16(a) | 0x4000)
	return 0

## FUN_0053fc10: checksum en memoria, guardado externalizado sin acceso a archivos.
func f53fc10() -> int:
	f53fc90()
	present("collection_save_requested", {"address": 0xa10120, "size": 0x1188})
	return 0

## FUN_00540430: máscara de juegos;4098b0 leía la selección de la interfaz.
## La escena aporta su índice de juego (Yugi0, Kaiba1, Joey2), sin valor por defecto.
func f540430(game_index: int) -> int:
	var shift := (game_index + 1) & 31
	return ((1 << shift) - 1) & 0xffff

## FUN_00540450: retira cartas incompatibles, ilegales o excedentes de posesión.
func f540450(game_index: int) -> int:
	for i in range(2048):
		var a := 0xa1012c + i * 2
		m.set_u16(a, m.u16(a) & 0xc0ff)
	var changed := 0
	for part in [[0xa112c0, 0xa1139c, 8], [0xa1137e, 0xa113a0, 12], [0xa11360, 0xa1139e, 10]]:
		var i := 0
		var base: int = part[0]
		var count_addr: int = part[1]
		var shift: int = part[2]
		while i < m.u16(count_addr):
			var index := m.u16(base + i * 2)
			var allowed := (f401b50(index) & f540430(game_index)) != 0
			if allowed:
				allowed = f53fd90(index) != 0
			var a := 0xa1012c + index * 2
			var value := m.u16(a)
			if not allowed or (value & 0xff) <= ((value >> shift) & 3):
				var count := m.u16(count_addr) - 1
				m.set_u16(count_addr, count)
				m.set_u16(base + i * 2, m.u16(base + count * 2))
				changed = 1
			else:
				var field_mask := 3 << shift
				m.set_u16(a, value ^ ((((value & field_mask) + (1 << shift)) ^ value) & field_mask))
				i += 1
	return changed

## La frontera de5407f0 entrega resultados del teclado/ratón de la escena.
## pressed yheld usan las mismas máscaras originales de input, no índices de cartas.
var _f_gui_input_packet: Array[int] = []

func submit_original_input(pressed: int, held: int, player: int, location: int, position: int) -> void:
	_f_gui_input_packet.assign([pressed, held, player, location, position])

## FUN_005407f0: polling de input original, adaptado a los resultados de la escena.
func f5407f0() -> int:
	if _f_gui_input_packet.size() != 5:
		# Sin ratón/teclado nativo ni paquete de escena no se inventa una entrada.
		return _unported(0x5407f0)
	var config := f5407d0()
	m.set_u32(config + 8, _f_gui_input_packet[0])
	m.set_u16(config + 4, _f_gui_input_packet[1])
	m.set_u32(0xa161a4, _f_gui_input_packet[2])
	m.set_u32(0xa161a8, _f_gui_input_packet[3])
	m.set_u32(0xa161ac, _f_gui_input_packet[4])
	_f_gui_input_packet.clear()
	return 0

## FUN_00541890: un fotograma original de interfaz seguido del motor.
func f541890() -> int:
	f5407f0()
	if not unported_calls.is_empty():
		return 0
	return f53dbf0()

## FUN_00542a20: anuncia y roba hasta cinco entradas por orden de selección.
func f542a20(p: int) -> int:
	var count := mini(f4073e0(), 5)
	var ordered: Array[int] = []
	for rank in range(count):
		var selected := -1
		for i in range(f4073e0()):
			if f407570(i) == rank + 1:
				selected = 0xa11624 + i * 4
		if selected < 0:
			# El original leería una ranura de pila sin inicializar si falta un rango.
			return _unported(0x542a20)
		ordered.append(selected)
	for op in [0x65, 0x6a]:
		for i in range(count - 1, -1, -1):
			var entry := ordered[i]
			issue((0x8000 if p != 0 else 0) | op, m.u16(entry), m.u16(entry + 2), 0)
	return 0

