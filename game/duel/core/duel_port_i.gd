class_name DuelPortI
extends DuelPortH
## Modulo del porte del motor de duelo (ver docs/duel/PORTING.md).

## Los manejadores devuelven su siguiente estado en los 16 bits bajos.
## Los bits altos que Ghidra conserva de registros indefinidos no son un estado.

## Las listas de seleccion se abren con FUN_00407580 (f407580), como en el original: crea la
## ventana bloqueante de la lista (DuelBase.list_open) y los estados siguientes leen la entrada
## elegida con FUN_004073b0. La CPU no abre la lista: fija antes la entrada con FUN_004073a0.


## FUN_00445810: ATK impreso; fichas tipo 24 devuelven 4000.
func _i_base_atk(index: int) -> int:
	var prop := f401a20(index)
	var kind := (prop >> 20) & 0x1f
	if kind > 0x14:
		if kind < 0x18: return 0
		if kind == 0x18: return 4000
	return ((prop >> 9) & 0x1ff) * 10

## FUN_005561d0: dano de 500 en contexto de batalla; equipo en otros contextos.
func f5561d0(a: int) -> int:
	if (m.u8(a + 2) & 0xe) != 6: return call("f555f40", a)
	f54ef90(1 - (m.u16(a + 2) & 1), 500)
	return 0

## FUN_00556210: mantenimiento opcional de 500 LP para el efecto de batalla.
func f556210(a: int, _b: int) -> int:
	var flags := m.u16(a + 2)
	var p := flags & 1
	if (flags & 0xe) != 6: return call("f555f40", a)
	match m.u8(0xa15fe0):
		0x80:
			if m.u16(DuelMem.pl(p)) > 500:
				if p != 0: m.set_u16(0xa16178, 1)
				else:
					# Cuadro Si/No: mensaje 0x18 con el nombre de la carta; 0x7f lee la respuesta.
					dialog_format(0x18, [{"card": m.u16(a)}])
					f540d60(1, 0)
				return 0x7f
		0x7f:
			if m.u16(0xa16178) != 0:
				issue((flags << 15) | 0x43, 500, 1, 0)
				issue((m.u16(a + 2) << 15) | 0xd0, f401a70(m.u16(a)), 0, 0)
			return 100
	return 0

## FUN_00556330: retira el monstruo en contexto de batalla o aplica equipo.
func f556330(a: int, _b: int) -> int:
	if (m.u8(a + 2) & 0xe) != 6: return call("f555f40", a)
	issue((m.u16(a + 2) << 15) | 0xd0, f401a70(m.u16(a)), 0, 0)
	return 0

## FUN_00556680: cambia la posicion del objetivo; revela previamente id 1201.
func f556680(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0 or (m.u8(a + 10) & 7) != 1: return 0
	var p := m.u8(a + 12)
	var z := m.u8(a + 13)
	var zone := DuelMem.zone(p & 1, z)
	var flags := m.u16(zone + 6)
	if f401a70(m.u16(zone) & 0xfff) == 0x4b1 and (flags & 2) == 0 and (flags & 1) != 0:
		issue((0x8000 if p != 0 else 0) | 0x80, z, 0, 0)
		f54eed0(p, m.u16(zone) & 0xfff, z)
		return 0
	if m.u8(0xa15fe0) == 0x80:
		if (flags & 1) != 0: call("f54e660", p, z, 0 if (flags & 2) != 0 else 1, 1)
		return 0x7f
	return 0

## FUN_00556770: cambia a defensa los monstruos boca arriba cuya posicion lo permite.
func f556770(a: int) -> int:
	var flags := m.u16(a + 2)
	if (m.u16(a + 4) & 0xc) != 0 or (m.u32(DuelMem.zone(flags & 1, (flags >> 4) & 0x3f)) & 0xfff) == 0: return 0
	for p in range(2):
		for z in range(5):
			var zone := DuelMem.zone(p, z)
			if (m.u16(zone + 6) & 3) == 2 and (m.u32(zone) & 0xfff) != 0 and f545c40(p, z) == 1:
				call("f54e660", p, z, 0, 0)
	return 0

## FUN_00556820: sustituye la carta de campo y actualiza su terreno.
func f556820(a: int) -> int:
	var p := m.u8(a + 2) & 1
	var other := 1 - p
	if (m.u32(DuelMem.zone(p, 10)) & 0xfff) != 0:
		var zone := DuelMem.zone(other, 10)
		if (m.u32(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 2) != 0:
			f54e250(other, 10, 0)
			if f401a70(m.u16(zone) & 0xfff) == 0x14d and f401a70(m.u16(a)) != 0x14d:
				f54cbb0(0, 0x58f)
				f54cbb0(1, 0x58f)
		issue((m.u16(a + 2) << 15) | 0x11, f542ce0(f401a70(m.u16(a))), 1, 0)
	return 0

## FUN_00556910: cambia el control siguiendo el jugador del turno.
func f556910(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0 and m.u8(0xa15fe0) == 0x80:
		call("f54cc10", m.u8(a + 2) & 1, m.u8(0xa133f2) & 1, 1, 0, 1)
		return 0x7f
	return 0

## FUN_00556950: cambia el control al adversario.
func f556950(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0 and m.u8(0xa15fe0) == 0x80:
		var p := m.u8(a + 2) & 1
		call("f54cc10", p, 1 - p, 0, 0, 1)
		return 0x7f
	return 0

## FUN_00556990: recuperacion de LP de las cuatro cartas de curacion.
func f556990(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var amount := 0
	match f401a70(m.u16(a)):
		0x154: amount = 800
		0x151: amount = 200
		0x153: amount = 600
		0x3ee: amount = 400
		_: return 0
	if m.u16(a + 12) <= 1:
		var p := m.u8(a + 2) & 1
		call("f54f0d0", p if m.u16(a + 12) == 0 else 1 - p, amount)
	return 0

## FUN_00556a30: recupera 500/1000 LP, con opcion de ambos jugadores.
func f556a30(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var p := m.u8(a + 2) & 1
	match f401a70(m.u16(a)):
		0x152: call("f54f0d0", p, 500)
		0x155: call("f54f0d0", p, 1000)
		0x523:
			call("f54f0d0", p, 1000)
			call("f54f0d0", 1 - p, 1000)
	return 0

## FUN_00556ad0: dano fijo, combinado o proporcional a la mano adversaria.
func f556ad0(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var p := m.u8(a + 2) & 1
	var amount := 0
	match f401a70(m.u16(a)):
		0x156: amount = 200
		0x157: amount = 500
		0x158: amount = 600
		0x159: amount = 800
		0x15a:
			f54ef90(1 - p, 1000)
			f54ef90(p, 500)
			return 0
		0x3ef: amount = 300
		0x40f: amount = m.u8(DuelMem.pl(1 - p) + 2) * 200
	if amount != 0: f54ef90(1 - p, amount)
	return 0

## FUN_00556c30: revela los monstruos adversarios y despues procesa efectos de volteo.
func f556c30(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0:
		if m.u8(0xa15fe0) == 0x80: return f556c4c(a)
		call("f56e120")
	return 0

## FUN_00556c4c: bloque de revelado de los cinco monstruos adversarios.
func f556c4c(a: int) -> int:
	var p := 1 - (m.u8(a + 2) & 1)
	for z in range(5):
		var zone := DuelMem.zone(p, z)
		if (m.u32(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 2) == 0:
			call("f54e640", p, z, 1)
			call("f54ef60", p, m.u16(zone) & 0xfff)
	return 0x7f

## FUN_00556cd0: enlaza el equipo con su objetivo unico, o invalida el efecto.
func f556cd0(a: int) -> int:
	if (m.u8(a + 10) & 7) == 1:
		var target := m.u16(a + 12)
		if (m.u32(DuelMem.zone(target & 1, target >> 8)) & 0xfff) != 0:
			var flags := m.u16(a + 2)
			call("f54c860", flags & 1, (((flags >> 4) & 0x3f) << 8) | (flags & 1), target, 2)
			return 0
	m.set_u8(a + 4, m.u8(a + 4) | 8)
	return 0

## FUN_00556d40: revela los monstruos adversarios sin procesar aun efectos.
func f556d40(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0:
		var p := 1 - (m.u8(a + 2) & 1)
		for z in range(5):
			var zone := DuelMem.zone(p, z)
			if (m.u32(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 2) == 0: call("f54e640", p, z, 1)
	return 0

## FUN_00556db0: busca y envia al cementerio las cartas id 1003 o 1034.
func f556db0(a: int) -> int:
	var p := m.u8(a + 2) & 1
	if f54da50(p, 0x3eb) == 0: f54da50(p, 0x40a)
	return 0

## FUN_005572c0: efecto de batalla de 5000 dano o recuperacion de 3000 fuera de ella.
func f5572c0(a: int) -> int:
	var flags := m.u16(a + 2)
	if (flags & 0xe) == 6: f54ef90(flags & 1, 5000)
	elif (m.u8(a + 4) & 4) == 0:
		call("f54f0d0", flags & 1, 3000)
		issue((flags << 15) | 0x94, (flags >> 4) & 0x3f, 0, 0)
	return 0

## FUN_00557330: roba dos cartas.
func f557330(a: int) -> int:
	call("f54f470", m.u8(a + 2) & 1, 2)
	return 0

## FUN_00557440: emite la retirada de la carta fuente.
func f557440(a: int) -> int:
	issue((m.u16(a + 2) << 15) | 0xd0, f401a70(m.u16(a)), 0, 0)
	return 0

## FUN_005577b0: inflige 1000 LP al adversario.
func f5577b0(a: int) -> int:
	f54ef90(1 - (m.u8(a + 2) & 1), 1000)
	return 0

## FUN_005577e0: devuelve el objetivo al propietario.
func f5577e0(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0 and (m.u8(a + 10) & 7) == 1:
		var p := m.u8(a + 12)
		var z := m.u8(a + 13)
		if (m.u16(DuelMem.zone(p & 1, z)) & 0xfff) != 0: f54e420(p, z, 0)
	return 0

## FUN_005578c0: hace descartar cinco cartas al adversario.
func f5578c0(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0: f54f4c0(1 - (m.u8(a + 2) & 1), 5, 1)
	return 0

## FUN_00557ab0: destruye dos objetivos boca abajo.
func f557ab0(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0 and (m.u16(a + 10) & 7) == 2:
		for i in range(m.u8(a + 10) & 7):
			var p := m.u8(a + 12 + i * 2)
			var z := m.u8(a + 13 + i * 2)
			var zone := DuelMem.zone(p & 1, z)
			if (m.u32(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 2) == 0: f54e250(p, z, 1)
	return 0

## FUN_00557b30: descarta ambas manos y roba cinco cartas por jugador.
func f557b30(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var p := m.u8(a + 2) & 1
	match m.u8(0xa15fe0):
		0x80:
			if m.u8(DuelMem.pl(p) + 2) == 0: return 0x7f
			f54e680(p, 0, 0, 1)
			return 0x80
		0x7f:
			if m.u8(DuelMem.pl(1 - p) + 2) == 0: return 0x7e
			f54e680(1 - p, 0, 1, 1)
			return 0x7f
		0x7e:
			call("f54f470", p, 5)
			call("f54f470", 1 - p, 5)
			return 0x7d
	return 0

## FUN_00557c10: devuelve hasta dos objetivos al propietario.
func f557c10(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0:
		for i in range(mini(2, m.u8(a + 10) & 7)):
			var p := m.u8(a + 12 + i * 2)
			var z := m.u8(a + 13 + i * 2)
			if (m.u16(DuelMem.zone(p & 1, z)) & 0xfff) != 0: f54e420(p, z, 0)
	return 0

## FUN_00557c80: toma nota de tres cartas del mazo adversario y las mueve.
func f557c80(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0 and m.u8(0xa15fe0) == 0x80:
		var p := 1 - (m.u8(a + 2) & 1)
		m.set_u8(0xa15fe1, mini(3, m.u8(DuelMem.pl(p) + 3)))
		m.set_u8(0xa15fe2, m.u8(DuelMem.pl(p) + 2))
		call("f54f140", p, 3, 1)
		return 0x7f
	return 0

## FUN_00558270: destruye las magias y trampas adversarias, incluida la zona de campo.
func f558270(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0 or m.u8(0xa15fe0) != 0x80: return 0
	var p := 1 - (m.u8(a + 2) & 1)
	for z in range(5, 11):
		var index := m.u32(DuelMem.zone(p, z)) & 0xfff
		if index == 0: continue
		if (m.u8(a + 4) & 0x10) != 0 and ctype(index) == 0x15: continue
		f54e250(p, z, 1)
	return 0x7f

## FUN_00558470: emite el indicador global del efecto id 0x1c.
func f558470(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0: issue((m.u16(a + 2) << 15) | 0x1c, 1, 0, 0)
	return 0

## FUN_00557350: destruye el objetivo que no sea trampa, revelandolo primero.
func f557350(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0 or (m.u8(a + 10) & 7) != 1: return 0
	var p := m.u8(a + 12)
	var z := m.u8(a + 13)
	var zone := DuelMem.zone(p & 1, z)
	var index := m.u16(zone) & 0xfff
	if index == 0: return 0
	if (m.u8(zone + 6) & 2) == 0:
		issue((0x8000 if p != 0 else 0) | 0x80, z, 0, 0)
		call("f54ef60", p, index)
		issue((0x8000 if p != 0 else 0) | 0xf1, 0xf, 0, 0)
		if ctype(index) == 0x15: issue((0x8000 if p != 0 else 0) | 0x80, z, 0, 0)
	if ctype(index) != 0x15: f54e250(p, z, 1)
	return 0

## FUN_00557480: paga 2000 para infligir 1000; CPU aplica el umbral original.
func f557480(a: int) -> int:
	var flags := m.u16(a + 2)
	var p := flags & 1
	if p == 0:
		if m.u8(0xa15fe0) == 0x80:
			# Cuadro Si/No con el mensaje 0x1d; 0x7f lee la respuesta.
			f5417e0(0x1d)
			f540d60(1, 0)
			return 0x7f
		if m.u8(0xa15fe0) == 0x7f:
			if m.u16(0xa16178) != 0:
				issue((flags << 15) | 0x43, 2000, 1, 0)
				f54ef90(1 - p, 1000)
			return 0x7e
	elif m.u16(0xa11944) < 1000 and m.u16(0xa12698) > 2000:
		issue((flags << 15) | 0x43, 2000, 1, 0)
		f54ef90(1 - p, 1000)
	return 0

## FUN_00557550: permite devolver una carta de la mano al mazo.
func f557550(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0 or (m.u16(a + 2) & 1) != 0: return 0
	match m.u8(0xa15fe0):
		0x80:
			if m.u8(DuelMem.pl(0) + 2) != 0:
				# Cuadro Si/No con el mensaje 0x1e; 0x7e lee la respuesta.
				f5417e0(0x1e)
				f540d60(1, 0)
				return 0x7e

		0x7e:
			if m.u16(0xa16178) != 0:
				if (m.u32(0xa114a8) & 0x102) != 0: return 0x80
				if f57a060(1) != 0 and f579890() != 0:
					f54d900(0, m.u32(0xa161ac), 0)
					return 0x80
				return 0x7e
	return 0

## FUN_00557600: destruye el objetivo unico si pasa el filtro original.
func f557600(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0 and (m.u8(a + 10) & 7) == 1 and call("f550530", a, m.u16(a + 12)) != 0:
		f555570(m.u8(a + 12), m.u8(a + 13))
		call("f56e3b0", m.u8(a + 2) & 1, m.u8(a + 12), m.u8(a + 13))
	return 0

## FUN_00557660: destruye el objetivo; invalida otro efecto que use esa misma fuente.
func f557660(a: int, b: int) -> int:
	if (m.u8(a + 4) & 4) != 0 or (m.u8(a + 10) & 7) != 1: return 0
	var p := m.u8(a + 12)
	var z := m.u8(a + 13)
	var zone := DuelMem.zone(p & 1, z)
	var index := m.u16(zone) & 0xfff
	if index == 0: return 0
	if f401a70(m.u16(a)) in [0x3ff, 0x4bb] and f401a70(index) == 0x4b1 and (m.u16(zone + 6) & 3) == 1:
		issue((0x8000 if p != 0 else 0) | 0x80, z, 0, 0)
		f54eed0(p, index, z)
		return 0
	if ctype(m.u16(a)) == 0x16 and z < 5 and f54f9f0(p, z) == 0: return 0
	f555570(p, z)
	call("f56e3b0", m.u8(a + 2) & 1, p, z)
	if b != 0 and (m.u16(b + 2) & 1) == p and ((m.u16(b + 2) >> 4) & 0x3f) == z:
		m.set_u8(b + 4, m.u8(b + 4) | 8)
	return 0

## FUN_00557830: enlaza Hombre de hongo 2 a ambos mazos para su efecto de fin.
func f557830(a: int) -> int:
	var flags := m.u16(a + 2)
	var p := flags & 1
	var source := (((flags >> 4) & 0x3f) << 8) | p
	call("f54c880", p, f401ad0(0x228), source, 0xd)
	call("f54c860", p, f401ad0(0x228), source, ((1 - p) << 8) | 0xd)
	return 0

## FUN_005578f0: revela una carta adversaria boca abajo y vuelve a ocultarla.
func f5578f0(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0 or (m.u8(a + 10) & 7) != 1: return 0
	var p := m.u8(a + 12)
	var z := m.u8(a + 13)
	var zone := DuelMem.zone(p & 1, z)
	var index := m.u16(zone) & 0xfff
	if index != 0 and p != (m.u8(a + 2) & 1) and (m.u8(zone + 6) & 2) == 0:
		issue((0x8000 if p != 0 else 0) | 0x80, z, 0, 0)
		f54eea0(p, index)
		issue((0x8000 if p != 0 else 0) | 0xf1, 0xf, 0, 0)
		issue((m.u16(a + 2) << 15) | 0x94, (m.u16(a + 2) >> 4) & 0x3f, 0, 0)
		issue((0x8000 if p != 0 else 0) | 0x80, z, 0, 0)
	return 0

## FUN_005579e0: destruye las Espadas de luz reveladora adversarias.
func f5579e0(a: int) -> int:
	var p := 1 - (m.u8(a + 2) & 1)
	var found := false
	for z in range(5, 10):
		var zone := DuelMem.zone(p, z)
		var index := m.u16(zone) & 0xfff
		if index != 0 and (m.u8(zone + 6) & 2) != 0 and f401a70(index) == 0x15b:
			f54e250(p, z, 1)
			found = true
	if found: issue((m.u16(a + 2) << 15) | 0x47, 1, 0, 0)
	return 0

## FUN_00557d10: intercambia el control de la fuente y su objetivo adversario.
func f557d10(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var flags := m.u16(a + 2)
	var p := flags & 1
	var z := (flags >> 4) & 0x3f
	var zone := DuelMem.zone(p, z)
	if (m.u32(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 2) != 0 and (m.u8(a + 10) & 7) == 1 and m.u8(0xa15fe0) == 0x80:
		var other := m.u8(a + 12)
		var target := m.u8(a + 13)
		if p != other and (m.u32(DuelMem.zone(other & 1, target)) & 0xfff) != 0:
			var src := (z << 8) | p
			var dst := (target << 8) | other
			call("f54c880", p, m.u16(a), src, 0xd)
			call("f54c880", other, m.u16(a), dst, 0xd)
			call("f54c860", p, m.u16(a), src, (other << 8) | 0xd)
			call("f54c860", other, m.u16(a), dst, (p << 8) | 0xd)
			f54d6c0(p, src, dst)
		return 1
	return 0

## FUN_00557e80: cambia posicion del objetivo de batalla y enlaza el objetivo propio.
func f557e80(a: int) -> int:
	var flags := m.u16(a + 2)
	if (flags & 0xfc00) == 0x4000:
		var p := m.u8(a + 6)
		var z := m.u8(a + 7)
		var zone := DuelMem.zone(p & 1, z)
		if (m.u32(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 1) == 0 and (flags & 1) != p: call("f54e660", p, z, 0, 0)
	if (m.u8(a + 10) & 7) == 1:
		var target := m.u16(a + 12)
		var zone := DuelMem.zone(target & 1, target >> 8)
		if (m.u32(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 2) != 0 and (flags & 1) == m.u8(a + 12):
			f54e730(flags & 1, (((flags >> 4) & 0x3f) << 8) | (flags & 1), target)
			return 0
		m.set_u8(a + 4, m.u8(a + 4) | 8)
	return 0

## FUN_00557f60: destruye los monstruos de ambos jugadores que pasan el filtro.
func f557f60(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0:
		var owner := m.u8(a + 2) & 1
		for p in [1 - owner, owner]:
			for z in range(5):
				if call("f550660", a, (z << 8) | p) != 0:
					f555570(p, z)
					call("f56e3b0", owner, p, z)
	return 0

## FUN_00558750: enlaza equipo cuando fuente y objetivo siguen presentes.
func f558750(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0 and (m.u8(a + 10) & 7) == 1:
		var flags := m.u16(a + 2)
		var target := m.u16(a + 12)
		if (m.u32(DuelMem.zone(flags & 1, (flags >> 4) & 0x3f)) & 0xfff) != 0 and (m.u32(DuelMem.zone(target & 1, target >> 8)) & 0xfff) != 0:
			call("f54c860", flags & 1, (((flags >> 4) & 0x3f) << 8) | (flags & 1), target, 2)
	return 0

## FUN_005589a0: sacrifica la fuente y suma ATK de los monstruos para el dano.
func f5589a0(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var flags := m.u16(a + 2)
	var p := flags & 1
	if ((flags ^ m.u8(0xa133f2)) & 1) == 0 and (flags & 0xfc00) == 0x800:
		if m.u8(0xa15fe0) == 0x7f:
			var amount := 0
			for z in range(5):
				if (m.u32(DuelMem.zone(p, z)) & 0xfff) != 0: amount += f547c60(p, z)
			call("f54cc10", p, p, 0, 0, 0)
			f54ef90(1 - p, f53fbd0(amount))
		elif m.u8(0xa15fe0) == 0x80:
			f54ea40(p, (flags >> 4) & 0x3f)
			return 0x7f
	else: issue((flags << 15) | 0x94, (flags >> 4) & 0x3f, 0, 0)
	return 0

## FUN_00558d50: devuelve la fuente al mazo contrario y lo baraja.
func f558d50(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0:
		var flags := m.u16(a + 2)
		issue((flags << 15) | 0x96, (flags >> 4) & 0x3f, 1 - (flags & 1), 0)
		issue(((1 - (flags & 1)) << 15) | 0x60, 0, 0, 0)
	return 0

## FUN_00558f10: destruye el objetivo boca arriba y aplica dano o ajuste de LP.
func f558f10(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0 or (m.u8(a + 10) & 7) != 1: return 0
	var p := m.u8(a + 12)
	var z := m.u8(a + 13)
	var zone := DuelMem.zone(p & 1, z)
	if (m.u16(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 2) != 0:
		var amount := f547c60(p, z)
		f555570(p, z)
		call("f56e3b0", m.u8(a + 2) & 1, p, z)
		match f401a70(m.u16(a)):
			0x3ab:
				f54ef90(1 - (m.u8(a + 2) & 1), amount)
				issue((m.u16(a + 2) << 15) | 0x43, amount, 1, 0)
			0x5ab: issue((m.u16(a + 2) << 15) | 0x44, 0, 0, 0)
	return 0

## FUN_005595f0: cancela el ataque y termina la batalla.
func f5595f0(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0:
		issue((0x8000 if m.u8(a + 6) != 0 else 0) | 0x35, m.u8(a + 7), 1, 0)
		issue((m.u16(a + 2) << 15) | 0x37, 0, 0, 0)
	return 0

## FUN_00559640: emite el cierre de batalla forzado.
func f559640(a: int) -> int:
	issue((m.u16(a + 2) << 15) | 0x37, 1, 0, 0)
	return 0

## FUN_00559670: solicita descartar una carta de la mano adversaria.
func f559670(a: int) -> int:
	var p := 1 - (m.u8(a + 2) & 1)
	if (m.u8(a + 4) & 4) == 0 and m.u8(DuelMem.pl(p) + 2) != 0: f53e930(p)
	return 0

## FUN_005599a0: alterna el indicador global del efecto.
func f5599a0(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0: issue((m.u16(a + 2) << 15) | 0x1d, (~(m.u16(0xa133ec) >> 13)) & 1, 0, 0)
	return 0

## FUN_005599e0: roba tres y descarta hasta conservar una carta adicional.
func f5599e0(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var p := m.u8(a + 2) & 1
	match m.u8(0xa15fe0):
		0x80:
			m.set_u8(0xa15fe1, m.u8(DuelMem.pl(p) + 2))
			call("f54f470", p, 3)
			return 0x7f
		0x7f:
			var count := m.u8(DuelMem.pl(p) + 2) - m.u8(0xa15fe1) - 1
			if count > 0: f53e830(p, count, 0, 0)
			return 0x7e
	return 0

## FUN_00559be0: emite el indicador 0x48 para el adversario.
func f559be0(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0: issue(((1 - (m.u8(a + 2) & 1)) << 15) | 0x48, 1, 0, 0)
	return 0

## FUN_00559c20: toma control del objetivo validado y lo marca.
func f559c20(a: int, b: int) -> int:
	if (m.u8(a + 4) & 4) == 0 and call("f553710", a, b, 0) != 0 and (m.u8(a + 10) & 7) == 1 and call("f550970", a, m.u16(a + 12)) != 0:
		var p := m.u8(a + 2) & 1
		m.set_u16(a + 14, ((f543360(p) & 0xff) << 8) | p)
		issue((m.u16(a + 2) << 15) | 0xa4, m.u16(a + 12), 1, 0)
		f54d570(p, m.u16(a + 12), m.u16(a + 14))
		issue((m.u16(a + 2) << 15) | 0x38, m.u16(a + 14), 1, 0)
	return 0

## FUN_00559f00: destruye el objetivo de contexto 5/6 segun ATK o DEF.
func f559f00(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0 or (m.u16(a + 2) >> 10) not in [5, 6]: return 0
	var p := m.u8(a + 6)
	var z := m.u8(a + 7)
	if (m.u32(DuelMem.zone(p & 1, z)) & 0xfff) == 0 or f54f910(m.u16(a), p, z) == 0: return 0
	match f401a70(m.u16(a)):
		0x2a8:
			if f547c80(p, z) >= 501: return 0
		0x2a9:
			if f547c60(p, z) >= 501: return 0
		0x3ea:
			if f547c60(p, z) <= 999: return 0
	f555570(p, z)
	call("f56e3b0", m.u8(a + 2) & 1, p, z)
	return 0

## FUN_0055a000: destruye una trampa boca arriba.
func f55a000(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0 and (m.u8(a + 10) & 7) == 1:
		var p := m.u8(a + 12)
		var z := m.u8(a + 13)
		var zone := DuelMem.zone(p & 1, z)
		var index := m.u16(zone) & 0xfff
		if index != 0 and ctype(index) == 0x15 and (m.u8(zone + 6) & 2) != 0: f54e250(p, z, 1)
	return 0

## FUN_0055a080: destruye exactamente tres objetivos si siguen presentes los tres.
func f55a080(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0 or (m.u16(a + 10) & 7) != 3: return 0
	for i in range(3):
		if (m.u32(DuelMem.zone(m.u8(a + 12 + i * 2) & 1, m.u8(a + 13 + i * 2))) & 0xfff) == 0: return 0
	for i in range(m.u8(a + 10) & 7):
		var p := m.u8(a + 12 + i * 2)
		var z := m.u8(a + 13 + i * 2)
		f555570(p, z)
		call("f56e3b0", m.u8(a + 2) & 1, p, z)
	return 0

## FUN_0055a230: robo de una o dos cartas al resolver el efecto.
func f55a230(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0 or m.u8(0xa15fe0) != 0x80: return 0
	match f401a70(m.u16(a)):
		0x21b, 0x5a7: call("f54f470", m.u8(a + 2) & 1, 1)
		0x3f2: call("f54f470", m.u8(a + 2) & 1, 2)
	return 0x7f

## FUN_0055a4e0: enlaza el efecto a un objetivo boca arriba.
func f55a4e0(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0 and (m.u8(a + 10) & 7) == 1:
		var target := m.u16(a + 12)
		var zone := DuelMem.zone(target & 1, target >> 8)
		if (m.u8(zone + 6) & 2) != 0 and (m.u32(zone) & 0xfff) != 0: call("f54c860", m.u8(a + 2) & 1, m.u16(a), target, 3)
	return 0

## FUN_0055afa0: destruye los monstruos marcados con el indicador 0x2000.
func f55afa0(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0:
		var owner := m.u8(a + 2) & 1
		for p in [1 - owner, owner]:
			for z in range(5):
				if (m.u8(DuelMem.zone(p, z) + 7) & 0x20) != 0:
					f555570(p, z)
					call("f56e3b0", owner, p, z)
	return 0

## FUN_0055b030: enlaza la fuente con una carta adversaria; excepcion id 1201.
func f55b030(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0 or (m.u8(a + 10) & 7) != 1: return 0
	var p := m.u8(a + 12)
	var z := m.u8(a + 13)
	if p == (m.u8(a + 2) & 1): return 0
	var zone := DuelMem.zone(p & 1, z)
	var index := m.u32(zone) & 0xfff
	if index != 0:
		if f401a70(index) == 0x4b1 and (m.u16(zone + 6) & 3) == 1:
			issue((0x8000 if p != 0 else 0) | 0x80, z, 0, 0)
			f54eed0(p, index, z)
			return 0
		call("f54c880", p, m.u16(a), (z << 8) | p, 3)
		call("f54c860", p, m.u16(a), (z << 8) | p, ((m.u8(a + 2) & 1) << 8) | 3)
	return 0

## FUN_0055b290: impide y despues destruye la invocacion indicada en el contexto.
func f55b290(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0:
		var p := m.u8(a + 6)
		var z := m.u8(a + 7)
		if m.u8(0xa15fe0) == 0x80:
			issue((0x8000 if p != 0 else 0) | 0x93, z, 7, 0)
			return 0x7f
		if m.u8(0xa15fe0) == 0x7f:
			issue((0x8000 if p != 0 else 0) | 0xb1, z, 1, 0)
			f54e250(p, z, 1)
			return 1
	return 0

## FUN_0055b320: inflige 500 por cada monstruo adversario.
func f55b320(a: int) -> int:
	var p := 1 - (m.u8(a + 2) & 1)
	var count := f5431b0(p)
	if (m.u8(a + 4) & 4) == 0 and count > 0: f54ef90(p, count * 500)
	return 0

## FUN_0055b370: busca las cartas id 1003/1034 y despues baraja.
func f55b370(a: int) -> int:
	var flags := m.u16(a + 2)
	if m.u8(0xa15fe0) == 100:
		issue((flags << 15) | 0x60, 0, 0, 0)
		return 1
	if m.u8(0xa15fe0) != 0x80: return 0
	if call("f54dc60", flags & 1, 0x3eb) == 0 and call("f54dc60", flags & 1, 0x40a) == 0 and (flags & 1) == 0: f5417e0(0x15)
	return 100

## FUN_0055b400: pasa el objetivo unico a defensa si estaba en ataque.
func f55b400(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0 and (m.u8(a + 10) & 7) == 1:
		var p := m.u8(a + 12)
		var z := m.u8(a + 13)
		if (m.u8(DuelMem.zone(p & 1, z) + 6) & 1) == 0: call("f54e660", p, z, 0, 0)
	return 0

## FUN_0055b5f0: devuelve al propietario la carta indicada en el contexto.
func f55b5f0(a: int) -> int:
	f54e420(m.u8(a + 6), m.u8(a + 7), 0)
	return 0

## FUN_0055b710: emite el efecto global del comando 0x36.
func f55b710(a: int) -> int:
	issue((m.u16(a + 2) << 15) | 0x36, 1, 1, 0)
	return 0

## FUN_0055bac0: solicita un sacrificio al adversario si tiene monstruos validos.
func f55bac0(a: int) -> int:
	var p := 1 - (m.u8(a + 2) & 1)
	if (m.u8(a + 4) & 4) == 0 and f543400(p, -1) != 0: f53e950(p)
	return 0

## FUN_0055bb10: destruye todas las magias/trampas; adversario primero.
func f55bb10(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0 or m.u8(0xa15fe0) != 0x80: return 0
	var result := f558270(a)
	var p := m.u8(a + 2) & 1
	for z in range(5, 11):
		if (m.u32(DuelMem.zone(p, z)) & 0xfff) != 0: f54e250(p, z, 1)
	return result

## FUN_0055bbf0: cambia las posiciones de ambos campos y marca el adversario.
func f55bbf0(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0:
		var owner := m.u8(a + 2) & 1
		for p in [owner, 1 - owner]:
			for z in range(5):
				var zone := DuelMem.zone(p, z)
				if (m.u32(zone) & 0xfff) != 0: call("f54e660", p, z, 1 if (m.u16(zone + 6) & 3) == 1 else 0, 1)
		issue((m.u16(a + 2) << 15) | 0x48, 1, 0, 0)
	return 0

## FUN_00556df0: sacrifica la fuente y destruye hasta dos objetivos validados.
func f556df0(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0:
		var flags := m.u16(a + 2)
		f54ea40(flags & 1, (flags >> 4) & 0x3f)
		for i in range(mini(2, m.u8(a + 10) & 7)):
			var target := m.u16(a + 12 + i * 2)
			var p := target & 0xff
			var z := target >> 8
			if (m.u16(DuelMem.zone(p & 1, z)) & 0xfff) != 0 and call("f550400", a, target) != 0:
				f555570(p, z)
				call("f56e3b0", flags & 1, p, z)
	return 0

## FUN_00558310: revela un defensor y lo destruye si su DEF no supera 2000.
func f558310(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0 or (m.u8(a + 10) & 7) != 1: return 0
	var p := m.u8(a + 12)
	var z := m.u8(a + 13)
	var zone := DuelMem.zone(p & 1, z)
	var index := m.u16(zone) & 0xfff
	match m.u8(0xa15fe0):
		0x80:
			if index != 0 and (m.u16(zone + 6) & 3) == 1:
				call("f54e640", p, z, 1)
				return 0x7f
		0x7f:
			call("f54ef30", p, index)
			issue((0x8000 if p != 0 else 0) | 0xf1, 0xf, 0, 0)
			if f401a70(index) in [0x1cd, 0x45c]: issue((0x8000 if p != 0 else 0) | 0x94, z, 0, 0)
			f56dc40(-1)
			return 0x7e
		0x7e:
			if f547c80(p, z) > 2000: call("f54e640", p, z, 0)
			else:
				f555570(p, z)
				call("f56e3b0", m.u8(a + 2) & 1, p, z)
			return 1
	return 0

## FUN_005584a0: protege trampas propias ante una carta adversaria de destruccion.
func f5584a0(a: int, b: int) -> int:
	if (m.u16(a + 4) & 4) != 0 or b == 0 or ((m.u8(b + 2) ^ m.u8(a + 2)) & 1) == 0 or (m.u16(a + 4) & 8) != 0: return 0
	var id := f401a70(m.u16(b))
	var owner := m.u8(a + 2) & 1
	if id in [0x29f, 0x425, 0x426, 0x42b]:
		for z in range(5, 11):
			var zone := DuelMem.zone(owner, z)
			var index := m.u16(zone) & 0xfff
			if index != 0 and ctype(index) == 0x15 and (m.u8(zone + 6) & 2) == 0:
				call("f54e640", owner, z, 0)
				call("f54ef30", owner, index)
				issue((m.u16(a + 2) << 15) | 0xf1, 0xf, 0, 0)
				call("f54e640", owner, z, 0)
		m.set_u8(b + 4, m.u8(b + 4) | 0x10)
	elif id in [0x53, 0xdf, 0x3ec, 0x437, 0x46e, 0x46f]:
		var p := m.u8(b + 12)
		var z := m.u8(b + 13)
		var zone := DuelMem.zone(p & 1, z)
		var index := m.u16(zone) & 0xfff
		if index != 0 and (p != owner or z != ((m.u16(a + 2) >> 4) & 0x3f)) and ctype(index) == 0x15:
			if (m.u8(zone + 6) & 2) == 0:
				call("f54e640", p, z, 0)
				call("f54ef30", owner, index)
				issue((m.u16(a + 2) << 15) | 0xf1, 0xf, 0, 0)
				call("f54e640", p, z, 0)
			issue((m.u16(a + 2) << 15) | 0xb0, 1, 0, 0)
	return 0

## FUN_005587f0: toma control del objetivo hacia una zona libre y lo enlaza.
func f5587f0(a: int) -> int:
	var owner := m.u8(a + 2) & 1
	var slot := f543570(owner)
	if (m.u8(a + 4) & 4) != 0: return 0
	issue((m.u16(a + 2) << 15) | 0x94, (m.u16(a + 2) >> 4) & 0x3f, 0, 0)
	if (m.u8(a + 10) & 7) != 1 or slot < 0: return 0
	var flags := m.u16(a + 2)
	var z := (flags >> 4) & 0x3f
	var zone := DuelMem.zone(owner, z)
	var target := m.u16(a + 12)
	if (m.u32(zone) & 0xfff) != 0 and f401a70(m.u32(zone) & 0xfff) in [0x2da, 0x536] and (m.u8(zone + 6) & 2) != 0 and (m.u16(DuelMem.zone(target & 1, target >> 8)) & 0xfff) != 0:
		f54ca50(target & 0xff, target >> 8, 0)
		issue((flags << 15) | 0x8d, slot, 1, 0)
		call("f54c860", owner, (slot << 8) | owner, (z << 8) | owner, 5)
		f54d570(owner, target, (slot << 8) | owner)
	return 0

## FUN_00558dc0: resucita las tres piezas de la combinacion id 737/756/800.
func f558dc0(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var p := m.u8(a + 2) & 1
	var state := m.u8(0xa15fe0)
	if state == 0x80:
		if f543330(p) <= 1 or f544a00(p, 0x2e1) == 0 or f544a00(p, 0x2f4) == 0 or f544a00(p, 800) == 0: return 0
		m.set_u32(0xa15fe0, (m.u32(0xa15fe0) & 0xffff0000) | 0x7f)
	elif state != 0x7f: return 0
	var ids := [0x2e1, 0x2f4, 800]
	var i := m.u8(0xa15fe1)
	var tmp := m.local(8)
	if i < 3 and f544950(p, f401ad0(ids[i]), tmp) != 0:
		issue((m.u16(a + 2) << 15) | 0xd3, m.u16(tmp), m.u16(tmp + 2), 0)
		call("f57cc50", p, tmp, 1, 0x20, 0xe, p)
	m.set_u8(0xa15fe1, i + 1)
	return 0x7f if m.u8(0xa15fe1) < 3 else 0x7e

## FUN_005593f0: resucita los monstruos destruidos en la batalla, de ambos cementerios.
func f5593f0(a: int) -> int:
	var state := m.u8(0xa15fe0)
	if (m.u8(a + 4) & 4) != 0 or state < 0x7f or state > 0x80: return 0
	var owner := m.u8(a + 2) & 1
	var p := owner if state == 0x80 else 1 - owner
	var index := m.u16(0xa114c6 + p * 12)
	var allowed := f541ce0(f401a70(index)) == 0 or f542fb0(p) != 0
	var flags := m.u8(0xa114c4 + p * 12)
	if (flags & 0x20) != 0 and allowed and f543360(p) >= 0:
		var tmp := m.local(8)
		for source in [p, 1 - p]:
			if f544950(source, index, tmp) != 0 and f5449b0(source, tmp) != 0:
				issue(((owner if source == p else 1 - owner) << 15) | 0xd3, m.u16(tmp), m.u16(tmp + 2), 0)
				m.set_u32(tmp, m.u32(tmp) & 0xffdfffff)
				call("f57cb60", p, tmp, 1, (flags & 0x10) >> 4, 0x20, 0xe, source)
	m.set_u8(0xa114c4 + p * 12, flags & 0xdf)
	return m.u8(0xa15fe0) - 1

## FUN_00559a70: elimina de la mano cartas iguales al objetivo y repone desde el mazo.
func f559a70(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var p := m.u8(a + 6)
	var index := m.u16(DuelMem.zone(p & 1, m.u8(a + 7))) & 0xfff
	match m.u8(0xa15fe0):
		0x80:
			if index == 0: return 0
			m.set_u32(0xa15fe0, (m.u32(0xa15fe0) & 0xffff0000) | 0x7f)
		0x7f: pass
		0x7e:
			call("f54f5f0", p, f401a70(index), 1)
			return 0x7d
		0x7d:
			issue((0x8000 if p != 0 else 0) | 0x60, 0, 0, 0)
			return 0x78
		_: return 0
	while m.u8(0xa15fe1) < m.u8(DuelMem.pl(p & 1) + 2):
		var i := m.u8(0xa15fe1)
		if f541c10(m.u16(0xa11fb8 + (p & 1) * PS + i * 4) & 0xfff, index) != 0:
			f54e680(p, i, 1, 1)
			return 0x7f
		m.set_u8(0xa15fe1, i + 1)
	return 0x7e

## FUN_00559cf0: destruye el monstruo adversario de ATK minimo; desempate humano.
func f559cf0(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var owner := m.u8(a + 2) & 1
	var p := 1 - owner
	var lowest := 99999
	var targets: Array[int] = []
	for z in range(5):
		var zone := DuelMem.zone(p, z)
		if (m.u32(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 2) != 0:
			var atk := f547c60(p, z)
			if atk < lowest:
				lowest = atk
				targets.clear()
			if atk == lowest: targets.append(z)
	if targets.is_empty(): return 0
	var z := targets[0]
	if targets.size() > 1:
		if m.u8(0xa15fe0) == 0x7f:
			call("f564e20")
			if f57a060(0xe00000) == 0: return 0x7f
			z = m.u32(0xa161ac) + m.u32(0xa161a8)
			if f547c60(m.u32(0xa161a4), z) != lowest or f579890() == 0: return 0x7f
			issue((m.u16(a + 2) << 15) | 8, m.u32(0xa161a4) & 0xffff, ((m.u32(0xa161ac) & 0xff) << 8) | (m.u32(0xa161a8) & 0xff), 0)
		elif m.u8(0xa15fe0) == 0x80 and owner == 0:
			f5417e0(100)
			return 0x7f
	if f54f9f0(p, z) != 0:
		f555570(p, z)
		call("f56e3b0", owner, p, z)
	elif (m.u32(DuelMem.zone(p, z)) & 0xfff) != 0:
		f54eed0(p, m.u32(DuelMem.zone(p, z)) & 0xfff, z)
	return 0

## FUN_0055a120: resucita la carta de cementerio seleccionada con marca 0x30.
func f55a120(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0 or m.u8(0xa15fe0) != 0x80: return 0
	if f401a70(m.u16(a)) == 0x3f0 and (f543a30(0, 0x402) > 0 or f543a30(1, 0x402) > 0): return 0
	var p := m.u8(a + 2) & 1
	if (m.u8(a + 10) & 7) == 2 and f543330(p) > 0:
		var card := m.u32(a + 12)
		var owner := (card >> 12) & 1
		var tmp := m.local(4)
		if f544950(owner, card & 0xfff, tmp) != 0:
			issue((m.u16(a + 2) << 15) | 0xd3, m.u16(a + 12), m.u16(a + 14), 0)
			m.set_u32(tmp, card)
			call("f57cc50", p, tmp, 1, 0x30, 0xe, owner)
		return 0x7f
	return 0

## FUN_0055a420: permite mostrar una carta de la mano del adversario.
func f55a420(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0 and m.u8(DuelMem.pl(m.u8(a + 2) & 1) + 2) != 0:
		if f57a060(0x10000) != 0 and f579890() != 0:
			issue((m.u16(a + 2) << 15) | 8, m.u32(0xa161a4), ((m.u32(0xa161ac) & 0xff) << 8) | (m.u32(0xa161a8) & 0xff), 0)
			var p := m.u8(a + 2) & 1
			f54eea0(p, m.u16(0xa11fb8 + (1 - p) * PS + m.u32(0xa161ac) * 4) & 0xfff)
		else: return 0x80
	return 0

## FUN_0055aa80: niega la carta o efecto precedente segun la trampa fuente.
func f55aa80(a: int, b: int) -> int:
	if (m.u8(a + 4) & 4) != 0 or b == 0 or m.u8(0xa15fe0) != 0x80: return 0
	var id := f401a70(m.u16(a))
	var other := f401a70(m.u16(b))
	var enemy := ((m.u8(b + 2) ^ m.u8(a + 2)) & 1) != 0
	var kind := ctype(m.u16(b))
	var p := m.u8(a + 2) & 1
	if id == 0x426:
		if other == 0x29f and enemy:
			issue((m.u16(a + 2) << 15) | 0xb0, 1, 0, 0)
			issue((m.u16(b + 2) << 15) | 0xb1, (m.u16(b + 2) >> 4) & 0x3f, 1, 0)
			for z in range(5, 11):
				var index := m.u32(DuelMem.zone(1 - p, z)) & 0xfff
				if index != 0 and ((m.u8(a + 4) & 0x10) == 0 or ctype(index) != 0x15): f54e250(1 - p, z, 1)
		return 1
	if id == 0x5fa:
		if kind > 0x14 or (call("f541d10", other, 1) == 0 and call("f541d10", other, 0) == 0): return 0
		issue((m.u16(a + 2) << 15) | 0xb0, 1, 0, 0)
		return 1
	if id == 0x5fb:
		if kind != 0x16 or call("f554910", m.u16(b)) == 0: return 0
	elif id == 0x406:
		if kind != 0x15: return 0
	elif id == 0x405:
		if kind != 0x16: return 0
	elif id == 0x3fd:
		if other != 0x3f0 or not enemy: return 0
	elif id == 0x3fb or id == 0x3fe:
		if other != (0x14f if id == 0x3fb else 0x150) or not enemy: return 0
	else: return 0
	issue((m.u16(a + 2) << 15) | 0xb0, 1, 0, 0)
	issue((m.u16(b + 2) << 15) | 0xb1, (m.u16(b + 2) >> 4) & 0x3f, 1, 0)
	if id == 0x3fb or id == 0x3fe: call("f54cc10", p, 1 - p, 0, 0, 0)
	return 1

## FUN_0055b150: niega magia/trampa o destruye una invocacion de contexto 31 a 33.
func f55b150(a: int, b: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	if b != 0 and ctype(m.u16(b)) > 0x14 and ctype(m.u16(b)) < 0x17:
		issue((m.u16(b + 2) << 15) | 0xb1, (m.u16(b + 2) >> 4) & 0x3f, 1, 0)
		issue((m.u16(a + 2) << 15) | 0xb0, 1, 0, 0)
		return 0
	var context := m.u16(a + 2) >> 10
	var p := m.u8(a + 6)
	var z := m.u8(a + 7)
	if context > 0x1e and context < 0x22 and (m.u32(DuelMem.zone(p & 1, z)) & 0xfff) != 0:
		if m.u8(0xa15fe0) != 0x80:
			issue((0x8000 if p != 0 else 0) | 0xb1, z, 1, 0)
			f54e250(p, z, 1)
		elif call("f5533d0", a, 0, 0) != 0:
			issue((0x8000 if p != 0 else 0) | 0x93, z, 7, 0)
			return 0x7f
	return 0

## FUN_0055b450: muestra todas las cartas boca abajo y las oculta en orden inverso.
func f55b450(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var owner := m.u8(a + 2) & 1
	var marked: Array[int] = []
	marked.resize(22)
	for p in [1 - owner, owner]:
		for z in range(11):
			var zone := DuelMem.zone(p, z)
			if (m.u32(zone) & 0xfff) == 0 or (m.u8(zone + 6) & 2) != 0: continue
			marked[p * 11 + z] = 1
			issue((m.u16(a + 2) << 15) | 8, p, z << 8, 0)
			issue((p << 15) | 0x80, z, 0, 0)
			issue((p << 15) | 0xf1, 0xf, 0, 0)
	issue((m.u16(a + 2) << 15) | 0xf1, 0x1e, 0, 0)
	for p in [owner, 1 - owner]:
		for z in range(10, -1, -1):
			if marked[p * 11 + z] != 0: issue((p << 15) | 0x80, z, 0, 0)
	return 0

## FUN_0055b740: destruccion/curacion/reactividad de los objetivos del contexto.
func f55b740(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0 or m.u8(0xa15fe0) == 1: return 0
	var p := m.u8(a + 6)
	var z := m.u8(a + 7)
	var owner := m.u8(a + 2) & 1
	var id := f401a70(m.u16(a))
	if id == 0x2ad:
		if m.u8(0xa15fe0) == 0x78:
			if f57a060(0xf0 << ((p & 1) << 4)) != 0 and f547c60(p, m.u32(0xa161ac)) == m.u16(0xa16148) and f579890() != 0:
				f555570(p, m.u32(0xa161ac))
				call("f56e3b0", owner, p, m.u32(0xa161ac))
				return 1
			return 0x78
		if m.u8(0xa15fe0) == 0x80:
			var highest := -1
			var targets: Array[int] = []
			for slot in range(5):
				var zone := DuelMem.zone(p & 1, slot)
				if (m.u32(zone) & 0xfff) == 0 or (m.u16(zone + 6) & 3) != 2: continue
				var atk := f547c60(p, slot)
				if atk > highest:
					highest = atk
					targets.clear()
				if atk == highest: targets.append(slot)
			if not targets.is_empty():
				if targets.size() > 1 and owner == 0:
					dialog_format(0x2a, [{"d": highest}])
					m.set_u8(0xa15fe0, 0x78)
					m.set_u16(0xa16148, highest)
					return 0x78
				f555570(p, targets[0])
				call("f56e3b0", owner, p, targets[0])
		return 0
	if id == 0x420:
		for slot in range(5):
			var zone := DuelMem.zone(p & 1, slot)
			if (m.u32(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 1) == 0:
				f555570(p, slot)
				call("f56e3b0", owner, p, slot)
		return 1
	var zone := DuelMem.zone(p & 1, z)
	if id == 0x44a:
		if (m.u32(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 2) != 0:
			call("f54f0d0", owner, f547c60(p, z))
			return 1
		return 0
	if id == 0x4be:
		if (m.u32(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 2) != 0:
			issue((0x8000 if p != 0 else 0) | 0x3b, z, 0, 0)
			f54ef90(p, f547c60(p, z))
	elif id == 0x587:
		if (m.u32(zone) & 0xfff) != 0 and (m.u8(zone + 6) & 2) != 0:
			call("f54c860", owner, m.u16(a), m.u16(a + 6), 3)
			return 1
	else: return 0
	return 1

## FUN_00556380: invocacion especial de cartas id 61/62/1249 desde mano o mazo.
func f556380(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var p := m.u8(a + 2) & 1
	match m.u8(0xa15fe0):
		0x7c:
			if f4073c0() == 2: issue((m.u16(a + 2) << 15) | 0x60, 0, 0, 0)
			return 100
		0x7e:
			var selected := f4073b0()
			var kind := f4073c0()
			if kind == 1:
				var index := f544db0(p, selected)
				issue((m.u16(a + 2) << 15) | 0xc2, m.u16(selected), m.u16(selected + 2), 0)
				call("f57cc50", p, selected, 1, 1, 0xb, index)
			elif kind == 2:
				issue((m.u16(a + 2) << 15) | 0x65, m.u16(selected), m.u16(selected + 2), 0)
				call("f57cc50", p, selected, 1, 1, 0xd, 0)
			return 0x7c
		0x7f:
			f407580(p, -1, f401a70(m.u16(a)), 0)
			return 0x7e
		0x80:
			if f542f30(0, 0x3d) != 0 or f542f30(1, 0x3d) != 0 or f542f30(0, 0x4e1) != 0 or f542f30(1, 0x4e1) != 0:
				var count: int = call("f56ba50", p, 0x13d, 0)
				if count == 0:
					if p == 0:
						f5417e0(0x15)
						return 1
				elif f543330(p) != 0:
					if p == 0:
						f5417e0(0x19)
						return 0x7f
					count = call("f56ba50", 1, 0x13d, 0)
					for id in [0x3e, 0x4e1, 0x3d]:
						for i in range(count):
							if f401a70(m.u16(0xa11624 + i * 4) & 0xfff) == id:
								m.set_u16(0xa11622, i)
								return 0x7e
					call("f57d330", m.u16(a))
					m.set_u16(0xa11622, m.u16(0xa14f02))
					return 0x7e
	return 0

## FUN_00556eb0: elige una fusion desde la lista, con tratamiento de id 505.
func f556eb0(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var p := m.u8(a + 2) & 1
	var id := f401a70(m.u16(a))
	match m.u8(0xa15fe0):
		0x7d:
			var selected := 0xa11624 + m.u16(0xa11622) * 4
			if id == 0x1a3:
				call("f57cb60", p, selected, 1, 0, 0, 0xc, 0)
				return 100
			if id == 0x1f9:
				issue((m.u16(a + 2) << 15) | 0x7d, m.u16(selected), m.u16(selected + 2), 0)
				call("f56e2e0", p, 1)
		0x7e:
			var selected := f4073b0()
			issue((m.u16(a + 2) << 15) | 0xdc, m.u16(selected), m.u16(selected + 2), 0)
			return 0x7d
		0x7f:
			f407580(p, -1, id, 0)
			return 0x7e
		0x80:
			if m.u8(DuelMem.pl(p) + 5) != 0 and (id == 0x1f9 or (id == 0x1a3 and f543330(p) != 0)):
				if p == 0:
					f5417e0(0x1a if id == 0x1a3 else 0x1b)
					return 0x7f
				call("f57d330", m.u16(a))
				m.set_u16(0xa11622, m.u16(0xa14f02))
				return 0x7e
	return 0

## FUN_00557070: busca dos cartas id 424 en el mazo y baraja al terminar.
func f557070(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var p := m.u16(a + 2) & 1
	match m.u8(0xa15fe0):
		100:
			issue((m.u16(a + 2) << 15) | 0x60, 0, 0, 0)
			return 10
		0x6e:
			if p != 0 and m.u8(DuelMem.pl(p) + 3) != 0: f407580(p, 0xd, 0, 0)
			return 100
		0x6f:
			if p != 0 and m.u8(DuelMem.pl(p) + 3) != 0: f5417e0(0xf9)
			return 0x6e
		0x7d:
			# Respuesta del cuadro de 0x7e (la CPU la fija a 1).
			return 0x7f if m.u16(0xa16178) != 0 else 100
		0x7e:
			if call("f56ba50", p, f401a70(m.u16(a)), 0) > 0:
				if p != 0:
					m.set_u16(0xa16178, 1)
					return 0x7d
				# Cuadro Si/No: mensaje 0x1c con el nombre de la carta 0x1a8.
				dialog_format(0x1c, [{"card": f401ad0(0x1a8)}])
				f540d60(1, 0)
				return 0x7d
		0x7f:
			if call("f54dc60", p, 0x1a8) != 0:
				issue((m.u16(a + 2) << 15) | 0x1f, 0x1a8, m.u8(DuelMem.pl(p) + 2), 0)
				m.set_u8(0xa15fe1, m.u8(0xa15fe1) - 1)
				return 0x7e if m.u8(0xa15fe1) != 0 else 100
			return 0x6f
		0x80:
			m.set_u8(0xa15fe1, 2)
			return 0x7f
		_:
			# Original: default -> 0. Sin esto el estado 10 (tras barajar) caia al
			# return 100 y la CPU barajaba sin fin tras el efecto (issue 2 publico).
			return 0
	return 100

## FUN_00557ff0: destruye monstruos adversarios de ATK >=1500 y descarta de la mano.
func f557ff0(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var owner := m.u8(a + 2) & 1
	var p := 1 - owner
	match m.u8(0xa15fe0):
		0x80:
			for z in range(5):
				var zone := DuelMem.zone(p, z)
				var index := m.u16(zone) & 0xfff
				if index == 0: continue
				var hidden := (m.u8(zone + 6) & 2) == 0
				issue((m.u16(a + 2) << 15) | 8, p, z << 8, 0)
				if hidden:
					issue((p << 15) | 0x80, z, 0, 0)
					call("f54ef30", p, index)
					issue((p << 15) | 0xf1, 0x1e, 0, 0)
				var atk := _i_base_atk(index) if hidden else f547c60(p, z)
				if atk >= 1500:
					f555570(p, z)
					call("f56e3b0", owner, p, z)
				elif hidden: issue((p << 15) | 0x80, z, 0, 0)
			m.set_u16(0xa15fe0, m.u8(0xa15fe0))
			return 0x7f
		0x7f:
			var i := m.u8(0xa15fe1)
			if m.u8(DuelMem.pl(p) + 2) <= i: return 0x7e
			var index := m.u16(0xa11fb8 + p * PS + i * 4) & 0xfff
			call("f54ef30", p, index)
			issue((p << 15) | 0x1f, f401a70(index), i, 0)
			if ctype(index) < 0x15 and _i_base_atk(index) >= 1500:
				f54e680(p, i, 1, 1)
				return 0x7f
			m.set_u8(0xa15fe1, i + 1)
			return 0x7f
		_:
			issue((p << 15) | 0x69, 3, 0, 0)
	return 0

## FUN_00558ac0: niega cartas continuas por clase y recorrido de ambos campos.
func f558ac0(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var flags := m.u16(a + 2)
	var owner := flags & 1
	var source := (flags >> 4) & 0x3f
	if (m.u32(DuelMem.zone(owner, source)) & 0xfff) == 0: return 0
	var id := f401a70(m.u16(a))
	match m.u8(0xa15fe0):
		0x80:
			m.set_u8(0xa16114, 0)
			return 0x7f
		0x7f:
			m.set_u8(0xa16115, 5)
			return 0x7e
		0x7d:
			m.set_u8(0xa16115, m.u8(0xa16115) + 1)
			if m.u8(0xa16115) > 10:
				m.set_u8(0xa16114, m.u8(0xa16114) + 1)
				return 0x7f if m.u8(0xa16114) < 2 else 0x78
			return 0x7e
		0x7e:
			var p := 1 - owner if m.u8(0xa16114) == 0 else owner
			var z := m.u8(0xa16115)
			var zone := DuelMem.zone(p & 1, z)
			var index := m.u16(zone) & 0xfff
			if index == 0 or (p == owner and z == source) or (m.u8(zone + 6) & 2) == 0: return 0x7d
			var kind := ctype(index)
			if id == 0x482:
				if kind == 0x15: return 0x7d
			elif id == 0x2ef or id == 0x409:
				if kind != 0x15: return 0x7d
			elif id == 0x601:
				if kind == 0x16:
					if call("f53b880") != 3: return 0x7d
				elif kind == 0x15: return 0x7d
			else: return 0x7d
			issue((0x8000 if p != 0 else 0) | 0xb1, z, 1, 0)
			return 0x7d
		0x78:
			if id == 0x482: issue((flags << 15) | 0x1a, 1, 0, 0)
			elif id == 0x2ef or id == 0x409: issue((flags << 15) | 0x19, 1, 0, 0)
			elif id == 0x601: issue((flags << 15) | 0x1b, 1, 0, 0)
	return 0

## FUN_0055a2a0: recupera hasta dos/cinco cartas excluidas seleccionadas.
func f55a2a0(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var p := m.u8(a + 2) & 1
	var id := f401a70(m.u16(a))
	match m.u8(0xa15fe0):
		0x7b:
			# Respuesta del cuadro de 0x7c.
			return 0x7f if m.u16(0xa16178) != 0 else 0
		0x7c:
			if call("f56ba50", p, id, 0) != 0:
				# Cuadro Si/No con el mensaje 0x26.
				f5417e0(0x26)
				f540d60(1, 0)
				return 0x7b
		0x7d:
			var selected := f4073b0()
			issue(((m.u32(selected) >> 12) << 15) | 0xd4, m.u16(selected), m.u16(selected + 2), 0)
			m.set_u8(0xa15fe1, m.u8(0xa15fe1) - 1)
			return 0x7c if m.u8(0xa15fe1) != 0 else 0
		0x7e:
			f407580(p, -1, id, 0)
			return 0x7d
		0x80:
			if id == 0x3f3: m.set_u8(0xa15fe1, 2)
			elif id == 0x400: m.set_u8(0xa15fe1, 5)
			m.set_u8(0xa15fe0, m.u8(0xa15fe0) - 1)
			if call("f56ba50", p, id, 0) > 0:
				f5417e0(0x25)
				return 0x7e
		0x7f:
			if call("f56ba50", p, id, 0) > 0:
				f5417e0(0x25)
				return 0x7e

	return 0

## FUN_0055aa20: prepara y muestra la lista de cartas del efecto fuente.
func f55aa20(a: int) -> int:
	if (m.u8(a + 4) & 4) == 0:
		call("f56ba50", m.u8(a + 2) & 1, f401a70(m.u16(a)), 0)
		f407580(m.u8(a + 2) & 1, -1, f401a70(m.u16(a)), 0)
	return 0

## FUN_0055ae30: descarta hasta tres monstruos de la mano, con confirmacion por carta.
func f55ae30(a: int, b: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var p := m.u8(a + 2) & 1
	match m.u8(0xa15fe0):
		0x80:
			m.set_u8(0xa15fe1, 3)
			f5417e0(0x29)
			return 0x7d
		0x7d:
			if f57a060(1) != 0 and ctype(m.u16(0xa11fb8 + p * PS + m.u32(0xa161ac) * 4) & 0xfff) < 0x15 and f579890() != 0:
				issue((m.u16(a + 2) << 15) | 8, m.u32(0xa161a4), ((m.u32(0xa161ac) & 0xff) << 8) | (m.u32(0xa161a8) & 0xff), 0)
				f54e680(p, m.u32(0xa161ac), 1, 1)
				m.set_u8(0xa15fe1, m.u8(0xa15fe1) - 1)
				return 0x7f
			return 0x7d
		0x7f:
			if m.u8(0xa15fe1) != 0 and call("f553300", a, b, 0) != 0:
				# Cuadro Si/No con el mensaje 0x28; 0x7e lee la respuesta.
				f5417e0(0x28)
				f540d60(1, 0)
				return 0x7e
		0x7e:
			return 0x7d if m.u16(0xa16178) != 0 else 0
	return 0

## FUN_0055b610: invoca una carta del mazo seleccionada y baraja al terminar.
func f55b610(a: int, b: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var p := m.u8(a + 2) & 1
	match m.u8(0xa15fe0):
		0x80:
			if call("f5536a0", a, b, 0) != 0:
				f407580(p, -1, f401a70(m.u16(a)), 0)
				return 0x7f
		0x7f:
			var selected := f4073b0()
			issue((m.u16(a + 2) << 15) | 0x65, m.u16(selected), m.u16(selected + 2), 0)
			return 0x7e
		0x7e:
			call("f57cc50", p, 0xa11624 + m.u16(0xa11622) * 4, 1, 0, 0xd, 0)
			return 0x7d
		0x7d:
			issue((m.u16(a + 2) << 15) | 0x60, 0, 0, 0)
			return 100
	return 0

## FUN_00559010: selecciona cartas del mazo y un monstruo, mezcla tres entradas e invoca.
func f559010(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var p := m.u8(a + 2) & 1
	var target_player := m.u8(a + 12)
	var target_zone := m.u8(a + 13)
	match m.u8(0xa15fe0):
		0x80:
			if (m.u8(a + 10) & 7) == 1 and call("f56ba50", p, f401a70(m.u16(a)), 0) > 1 and (m.u32(DuelMem.zone(target_player & 1, target_zone)) & 0xfff) != 0 and p == target_player and call("f553710", a, 0, 0) != 0:
				f5417e0(0x20)
				return 0x7f
		0x7f:
			f407580(p, -1, f401a70(m.u16(a)), 0)
			return 0x7e
		0x7e:
			var selected := f4073b0()
			f541cb0(0xa1614c, selected)
			issue((m.u16(a + 2) << 15) | 0x65, m.u16(selected), m.u16(selected + 2), 0)
			f5417e0(0x21)
			return 0x7d
		0x7d:
			f407580(p, -1, f401a70(m.u16(a)), 0)
			return 0x7c
		0x7c:
			var selected := f4073b0()
			f541cb0(0xa16150, selected)
			issue((m.u16(a + 2) << 15) | 0x65, m.u16(selected), m.u16(selected + 2), 0)
			var zone := DuelMem.zone(target_player & 1, target_zone)
			f541cb0(0xa16154, zone)
			m.copy(0xa15fec, zone, 0x94)
			issue((0x8000 if target_player != 0 else 0) | 0x78, target_zone, 8, 0)
			issue((0x8000 if target_player != 0 else 0) | 0x8e, target_zone, 10, 0)
			return 0x7b
		0x7b:
			for i in range(16):
				var left := rng.rand() % 3
				var right := rng.rand() % 3
				while left == right:
					left = rng.rand() % 3
					right = rng.rand() % 3
				f541cb0(0xa15fe8, 0xa1614c + left * 4)
				f541cb0(0xa1614c + left * 4, 0xa1614c + right * 4)
				f541cb0(0xa1614c + right * 4, 0xa15fe8)
			m.set_u16(0xa15fe0, m.u8(0xa15fe0))
			return 0x7a
		0x7a:
			var slot := f543360(p)
			var i := m.u8(0xa15fe1)
			var extra := 1 if f542f30(0, 0x47f) != 0 or f542f30(1, 0x47f) != 0 else 0
			issue((m.u16(a + 2) << 15) | 0xaa, (slot & 0xff) | (extra << 8) | 0x200, m.u16(0xa1614c + i * 4), m.u16(0xa1614e + i * 4))
			if ctype(m.u16(0xa1614c + i * 4) & 0xfff) < 0x15: issue((0x8000 if target_player != 0 else 0) | 0x8e, 10, slot, 0)
			m.set_u8(0xa15fe1, i + 1)
			return 0x7a if m.u8(0xa15fe1) < 3 else 0x79
		0x79:
			issue((m.u16(a + 2) << 15) | 0x60, 0, 0, 0)
			return 0x78
	return 0

## FUN_005596c0: invoca hasta dos monstruos de tipo 1 desde la mano.
func f5596c0(a: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var p := m.u8(a + 2) & 1
	var state := m.u8(0xa15fe0)
	match state:
		0x80, 0x7f:
			if state == 0x80: m.set_u16(0xa15fe0, 0x7f)
			if f543330(p) != 0 and call("f552bb0", a, 0, 0) != 0:
				# Cuadro Si/No: mensaje 0x22 con el texto del mensaje 0x1f5 en su "%s".
				dialog_format(0x22, [{"msg": 0x1f5}])
				f540d60(1, 0)
				return 0x7c
		0x7c:
			if m.u16(0xa16178) != 0:
				# Mensaje 0x24 (con el texto 0x1f5) y se elige con el cursor en 0x7e.
				dialog_format(0x24, [{"msg": 0x1f5}])
				return 0x7e
		0x7e:
			if (m.u32(0xa114a8) & 0x102) != 0:
				# Cancelar vuelve a preguntar con el cuadro de 0x7f.
				dialog_format(0x22, [{"msg": 0x1f5}])
				f540d60(1, 0)
				return 0x7c
			if f57a060(1) == 0: return 0x7e
			var index := m.u32(0xa161ac)
			var src := 0xa11fb8 + p * PS + index * 4
			var card := m.u16(src) & 0xfff
			if ctype(card) != 1 or (f541ce0(f401a70(card)) != 0 and f542fb0(p) == 0) or f579890() == 0: return 0x7e
			issue((m.u16(a + 2) << 15) | 0xc2, m.u16(src), m.u16(src + 2), 0)
			call("f57cc50", p, src, 1, 0, 0xb, index)
			return 0x7d
		0x7d:
			m.set_u8(0xa15fe1, m.u8(0xa15fe1) + 1)
			if m.u8(0xa15fe1) != 2 and f543330(p) != 0:
				for i in range(m.u8(DuelMem.pl(p) + 2)):
					if ctype(m.u16(0xa11fb8 + p * PS + i * 4) & 0xfff) == 1:
						# Cuadro Si/No con el mensaje 0x23; 0x7c lee la respuesta.
						f5417e0(0x23)
						f540d60(1, 0)
						return 0x7c

	return 0

## FUN_0055a550: invocacion normal adicional con seleccion fiel de uno/dos tributos.
func f55a550(a: int, b: int) -> int:
	if (m.u8(a + 4) & 4) != 0: return 0
	var flags := m.u16(a + 2)
	var p := flags & 1
	if (m.u32(DuelMem.zone(p, (flags >> 4) & 0x3f)) & 0xfff) == 0: return 0
	var state := m.u8(0xa15fe0)
	match state:
		100:
			call("f57c9a0", p, m.u16(a + 12), m.u16(a + 14), m.u16(a + 16))
			if b != 0 and m.u16(a + 16) != 0:
				for tribute in [m.u8(a + 16), m.u8(a + 17)]:
					if (tribute & 0x80) == 0: continue
					var target: int = ((tribute >> 4) & 1) | ((tribute & 7) << 8)
					for i in range(m.u8(b + 10) & 7):
						if target == m.u16(b + 12 + i * 2): m.set_u8(b + 4, m.u8(b + 4) | 4)
					if target == m.u16(b + 6) or target == m.u16(b + 8): m.set_u8(b + 4, m.u8(b + 4) | 4)
			return 10
		0x6e, 0x78:
			# Cuadro Si/No con el mensaje guardado en DAT_005ad288/28c; 0x6d/0x77 leen la respuesta.
			f5417e0(m.u32(0x5ad288 if state == 0x6e else 0x5ad28c))
			f540d60(1, 0)
			return 0x6d if state == 0x6e else 0x77

		0x6d, 0x77:
			if m.u16(0xa16178) == 0: return 0x80
			return _i_tribute_select(a, 0x6c if state == 0x6d else 0x76)
		0x6c, 0x74, 0x75, 0x76:
			return _i_tribute_select(a, state)
		0x7f:
			if f57a060(1) != 0:
				var i := m.u32(0xa161ac)
				var card := m.u16(0xa11fb8 + p * PS + i * 4) & 0xfff
				if call("f57a490", p, card) != 0 and f5421c0(card) == 0 and f579890() != 0:
					m.set_u16(a + 12, i)
					var prop := f401a20(card)
					var kind := (prop >> 20) & 0x1f
					var level := 10 if kind == 0x18 else (0 if kind > 0x14 and kind < 0x18 else ((prop >> 25) & 0xf))
					if level in [1, 2, 3, 4]:
						m.set_u16(a + 14, f543360(p))
						m.set_u16(a + 16, 0)
						return 100
					if level == 5 or level == 6: return 0x6e
					return 0x78
			return 0x7f
		0x80:
			for i in range(m.u8(DuelMem.pl(p) + 2)):
				var card := m.u16(0xa11fb8 + p * PS + i * 4) & 0xfff
				if call("f57a490", p, card) != 0 and f5421c0(card) == 0:
					f5417e0(0x27)
					return 0x7f
	return 0

## Seleccion de tributos de FUN_0055a550; cursor y validacion del original.
func _i_tribute_select(a: int, state: int) -> int:
	if f57a060(0xf0) != 0 and f544210(m.u32(0xa161a4), m.u32(0xa161ac)) != 0 and f579890() != 0:
		var z := m.u32(0xa161ac)
		if state in [0x74, 0x75] and z == m.u16(a + 14): return 0x74
		# 0x55a550: FUN_00465720, marcador de sacrificio sobre la carta elegida.
		f465720(m.u32(0xa161a4), m.u32(0xa161a8) + z)
		if state in [0x74, 0x75]:
			m.set_u16(a + 16, m.u16(a + 16) | ((z & 0xff) | 0x80))
			return 100
		m.set_u16(a + 14, z)
		m.set_u16(a + 16, ((z & 0xff) << 8) | 0x8000 if state == 0x76 else ((z & 0xff) | 0x80))
		return 0x75 if state == 0x76 else 100
	return 0x74 if state in [0x74, 0x75] else state


