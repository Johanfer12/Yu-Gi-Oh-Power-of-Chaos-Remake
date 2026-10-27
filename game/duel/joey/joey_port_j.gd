class_name JoeyPortJ
extends JoeyPortI
## Motor nativo de Joey, lote J de la etapa 2: manejadores de comandos 40a900-40ced0 y extraccion de la cola (5b9ca0, 5b9bf0, 5b9370, 5b93f0).
## Cada funcion se llama f<direccion de Joey_Pc.exe> (o _c5b9470_XX para los casos del despacho)
## y sobrescribe su declaracion con la misma aridad. Cotejo: re/scripts/joey_specs/port_j.py.
##
## Omisiones de presentacion (FRONTERA_JOEY.md 2.5 y 3): las esperas sobre la lista de efectos
## 5f3280+0x132c..0x1330, sobre el objeto del tutorial 5f3280+0x133c y sobre la ventana de la
## ranura 5f3280+0x1304/0x1308 cuentan como "nada ocupado"; desaparecen la infraestructura C++
## (new, shared_ptr, insercion en la lista), las escrituras en campos de objetos visuales y del
## tutorial, los metodos +0x10 (imagen) de los objetos de mesa y +0x24 de 5f3280+0x3c.

## Objeto senalado / seleccionado por la interfaz (fuera del blob) y lista de la mano visual.
const _JJ_POINTED := 0x5f2fdc
const _JJ_SELECTED := 0x5f2fe0
const _JJ_HAND_OBJ := 0x5f300c
## Lista de candidatos: tipo/jugador (u16), eleccion (u16), entradas u32[128], ordenes u16[128]
## y numero de entradas.
const _JJ_LIST := 0xa582a0
const _JJ_LIST_CHOICE := 0xa582a2
const _JJ_LIST_ENTRIES := 0xa582a4
const _JJ_LIST_ORDER := 0xa584a4
const _JJ_LIST_N := 0xa585a4
## Respuesta del cuadro o de la lista (u16).
const _JJ_ANSWER := 0xa558b4
## Buzon de animacion: estado (u16), dato (u32), origen y destino (u16).
const _JJ_MAIL := 0xa5506a
const _JJ_MAIL_DATA := 0xa5506c
const _JJ_MAIL_FROM := 0xa55070
const _JJ_MAIL_TO := 0xa55072
## Comando de red pendiente (5b93f0) y su fase (byte bajo de a58294); banderas de red a58260.
const _JJ_NET_CMD := 0xa5828c
const _JJ_NET_PHASE := 0xa58294
const _JJ_NET_FLAGS := 0xa58260
## Fase de la extraccion de la cola (byte alto de a5780e).
const _JJ_QUEUE_PHASE := 0xa5780e

## Campo +0x1c del objeto del tutorial (5f3280+0x133c): 40bf60 lo fija y espera a que vuelva a
## 0. Lo pone a 0 la presentacion del tutorial; sin pantalla nadie lo borra (como el objeto
## simulado del oraculo).
var tutorial_wait := 0


## u16 en la direccion que devuelve una consulta de objeto visual (418b50, 449df0). Sin objeto
## devuelve 0 y se lee como 0, igual que _jh_obj_u32.
func _jj_u16_at(addr: int) -> int:
	if addr == 0:
		return 0
	return m.u16(addr)


## Joey FUN_0040a900: comando e1, efecto de LP (4571d0) con el lado y la zona de c; un tick.
func f40a900() -> int:
	if cmd_step() == 0:
		cmd_advance()
		var info := m.local(4)
		m.set_u16(info, 0x8000 | ((m.u8(JoeyMem.CMD + 6) & 0x1f) << 1) | cmd_p())
		# new(0x134) + 4571d0(&info, ~b, a == 0, 3): los tres ultimos argumentos solo van a la
		# presentacion; shared_ptr e insercion omitidos.
		f4571d0(0, info)
	if visual_busy("effects", 0, 0, 0x40aa15):
		return 0
	cmd_finish()
	return 0


## Joey FUN_0040aa40: comando 1e, activacion de la carta a: busto, efecto sobre cada copia boca
## arriba en el campo (monstruos o magias segun 402690) o efecto generico, y espera.
func f40aa40() -> int:
	var p := cmd_p()
	var card := f402460(cmd_a()) & 0xffff
	var b := cmd_b()
	match cmd_step():
		0:
			if f402690(card) != 0:
				f403bf0(p, f4022e0(card) & 0xffff)
			cmd_advance()
		1:
			if visual_busy("effects", 0, 0, 0x40aac2):
				return 0
			var created := 0
			var first := 5
			var last := 10
			if f402690(card) != 0:
				first = 0
				last = 4
			for q in 2:
				if b == 0 and q != p:
					continue
				for z in range(first, last + 1):
					var at := JoeyMem.zone(q, z)
					var status := m.u32(at + 0x8c)
					if (m.u32(at) & 0xfff) != card:
						continue
					if ((m.u8(at + 6) >> 1) & ~(status >> 5) & ~(status >> 1) & 1) == 0:
						continue
					var obj := f41cee0(q, z, 0)
					if obj == 0:
						continue
					# new(300) + 450260(card, ubicacion del objeto); insercion omitida.
					var place := m.local(4)
					f450260(0, card, f418b50(obj, place))
					created += 1
			if created == 0:
				f450730(0, card)
			f41b050(card) # Metodo +0x24 de 5f3280+0x3c: panel de detalle.
			cmd_advance()
		2:
			if visual_busy("effects", 0, 0, 0x40ab0b):
				return 0
			cmd_finish()
	return 0


## Joey FUN_0040ad90: comando 1f, resalta la carta b de la mano (objeto visual), marca 0x10 en
## +0x6d0 del jugador si existe y espera a la mesa.
func f40ad90() -> int:
	var p := cmd_p()
	f402460(cmd_a())
	var obj := f41cee0(p, 0xb, cmd_b())
	match cmd_step():
		0:
			if obj != 0:
				var loc := m.local(4)
				var where := _jj_u16_at(f418b50(obj, loc + 2)) | 0x8000
				m.set_u16(loc, where)
				f4189d0(obj, loc)
				# obj+0x18 = 1 y obj+0x1c = 0x200 omitidos.
				var flags := JoeyMem.PLAYER + 0x6d0 + (p & 1) * JoeyMem.PLAYER_SIZE
				m.set_u32(flags, m.u32(flags) | 0x10)
			cmd_advance()
		1:
			if obj != 0:
				m.set_u32(_JJ_POINTED, obj)
			if f41d050(m.u32(_JJ_HAND_OBJ)) & 0xff == 0:
				cmd_finish()
	return 0


## Joey FUN_0040ae80: comando 20, sonido y resalte de la pila b del jugador (41cf60) y espera.
func f40ae80() -> int:
	var p := cmd_p()
	f402460(cmd_a())
	match cmd_step():
		0:
			var obj := f41cf60(p, cmd_b())
			if obj != 0:
				f44ef40(6)
				f43c750(obj)
			cmd_advance()
		1:
			if f41d050(m.u32(_JJ_HAND_OBJ)) & 0xff == 0:
				cmd_finish()
	return 0


## Joey FUN_0040af10: comando 21, la CPU senala cartas de su mano al azar (paso >> 1) durante
## 0x21 ticks; con menos de dos cartas termina.
func f40af10() -> int:
	var p := cmd_p()
	var n := m.u8(JoeyMem.PLAYER + JoeyMem.P_HAND_N + (p & 1) * JoeyMem.PLAYER_SIZE)
	if n < 2:
		cmd_finish()
		return 0
	var s := m.u32(JoeyMem.CMD_STATE)
	if (s & 0x7f) > 0x20:
		cmd_finish()
		return 0
	var i := ((s >> 1) & 0x3f) % n
	cmd_advance()
	var obj := f41cee0(p, 0xb, i)
	if obj != 0:
		m.set_u32(_JJ_POINTED, obj)
		m.set_u8(_JJ_SELECTED, 1)
	return 0


## Joey FUN_0040afc0: comando ae, baraja los monstruos de las zonas de la mascara c (semilla
## b << 16 | a): permuta los objetos de zona y reescribe los vinculos que los apuntan.
func f40afc0() -> int:
	var p := cmd_p()
	var c := cmd_c()
	match cmd_step():
		0:
			# Pila del original: A = [esp+0x1c] (5 huecos) seguida de B = [esp+0x30]; un indice
			# de 5bddb0 igual a n (rand() == 0x7fff con version >= 1000) lee el hueco siguiente.
			var slots := PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
			var n := 0
			for i in 5:
				if (c >> i) & 1:
					slots[n] = i
					slots[5 + n] = i
					n += 1
			if n < 2:
				cmd_finish()
				return 0
			rng.srand(((cmd_b() << 16) | cmd_a()) & 0xffffffff)
			var k := n - 1
			while k > 0:
				var r := f5bddb0(k + 1)
				var t := slots[k]
				slots[k] = slots[r]
				slots[r] = t
				k -= 1
			# Pose previa de cada objeto: 418b60 gira el objeto sin cambiar su cara/posicion.
			var visual_flags: Array[int] = []
			for z in 5:
				visual_flags.append(m.u16(JoeyMem.zone(p, z) + JoeyMem.Z_FLAGS))
			var p2 := (p + 2) & 0xff
			for j in n:
				var from := slots[5 + j] << 8
				f56b360(from | p, from | p2)
			var buf := m.local(0x2d0)
			for j in n:
				m.copy(buf + slots[5 + j] * JoeyMem.ZONE_SIZE, JoeyMem.zone(p, slots[5 + j]), JoeyMem.ZONE_SIZE)
			for j in n:
				m.copy(JoeyMem.zone(p, slots[j]), buf + slots[5 + j] * JoeyMem.ZONE_SIZE, JoeyMem.ZONE_SIZE)
			for j in n:
				f56b360((slots[5 + j] << 8) | p2, (slots[j] << 8) | p)
			# Metodo +0x10 (imagen de la carta que ahora ocupa la zona) y obj+0x18 = 5,
			# obj+0x1c = 0x200 (418b60, 32 ticks) en cada objeto existente de la mascara.
			var objects: Array[int] = []
			for i in 5:
				if (c >> i) & 1:
					var obj := f41cee0(p, 0, i)
					if obj != 0:
						objects.append(i)
			if not objects.is_empty():
				present("native_field_shuffle", {"p": p, "objects": objects, "visual_flags": visual_flags})
			cmd_advance()
		1:
			if not visual_busy("effects") and f41d050(m.u32(_JJ_HAND_OBJ)) & 0xff == 0:
				cmd_finish()
	return 0


## Joey FUN_0040b270: comando 8b, suma b al contador de 4 bits (+6 bits 2-5) de la zona a, con
## tope 15, solo si hay objeto visual; termina si la zona esta vacia.
func f40b270() -> int:
	var p := cmd_p()
	var z := cmd_a()
	var at := JoeyMem.zone(p, z)
	if m.u32(at) & 0xfff == 0:
		cmd_finish()
		return 0
	match cmd_step():
		0:
			if f41cee0(p, z, 0) != 0:
				var v := m.u16(at + 6)
				var n := ((v >> 2) & 0xf) + cmd_b()
				if n > 0xf:
					n = 0xf
				m.set_u16(at + 6, ((n & 0xf) << 2) | (v & 0xffc3))
				# obj+0x18 = 3 y obj+0x1c = 0x200 omitidos.
			cmd_advance()
		1:
			if f41d050(m.u32(_JJ_HAND_OBJ)) & 0xff == 0:
				cmd_finish()
	return 0


## Joey FUN_0040b370: comando 97, fija el contador de 3 bits (+6 bits 6-8) de la zona a al
## minimo de b y el actual (b si es 0), solo si hay objeto visual.
func f40b370() -> int:
	var p := cmd_p()
	var z := cmd_a()
	var at := JoeyMem.zone(p, z)
	var n := (m.u16(at + 6) >> 6) & 7
	var b := cmd_b()
	if n == 0 or n > b:
		n = b
	if m.u32(at) & 0xfff == 0:
		cmd_finish()
		return 0
	match cmd_step():
		0:
			if f41cee0(p, z, 0) != 0:
				m.set_u16(at + 6, ((n & 7) << 6) | (m.u16(at + 6) & 0xfe3f))
				# obj+0x18 = 4 y obj+0x1c = 0x200 omitidos.
			cmd_advance()
		1:
			if f41d050(m.u32(_JJ_HAND_OBJ)) & 0xff == 0:
				cmd_finish()
	return 0


## Joey FUN_0040b470: comando 0c, pone (b != 0) o quita el bit a de a577ec.
func f40b470() -> int:
	var bit := 1 << (cmd_a() & 0x1f)
	var v := m.u32(0xa577ec)
	if cmd_b() != 0:
		v |= bit
	else:
		v &= ~bit
	cmd_finish()
	m.set_u32(0xa577ec, v & 0xffffffff)
	return 0


## Joey FUN_0040b4d0: comando 0d, pone (b != 0) o quita el bit a de +0x6d0 del jugador.
func f40b4d0() -> int:
	var at := JoeyMem.PLAYER + 0x6d0 + (cmd_p() & 1) * JoeyMem.PLAYER_SIZE
	var bit := 1 << (cmd_a() & 0x1f)
	if cmd_b() != 0:
		m.set_u32(at, m.u32(at) | bit)
	else:
		m.set_u32(at, m.u32(at) & ~bit & 0xffffffff)
	cmd_finish()
	return 0


## Joey FUN_0040b560: comando 0e, pone (c != 0) o quita el bit b del estado +0x8c de la zona a.
func f40b560() -> int:
	var at := JoeyMem.zone(cmd_p(), cmd_a()) + 0x8c
	var bit := 1 << (cmd_b() & 0x1f)
	if cmd_c() != 0:
		m.set_u32(at, m.u32(at) | bit)
	else:
		m.set_u32(at, m.u32(at) & ~bit & 0xffffffff)
	cmd_finish()
	return 0


## Joey FUN_0040b610: comando eb, bocadillo a del tutorial (48cbd0) y espera.
func f40b610() -> int:
	if cmd_step() == 0:
		cmd_advance()
		f48cbd0(0, cmd_a())
		return 0
	# Espera del objeto del tutorial omitida.
	cmd_finish()
	return 0


## Joey FUN_0040b670: comando ec, apaga el foco del tutorial (+0xc4) y espera.
func f40b670() -> int:
	if cmd_step() == 0:
		cmd_advance()
		# Escritura del objeto del tutorial (+0xc4 = 0) omitida.
		return 0
	cmd_finish()
	return 0


## Joey FUN_0040b6c0: comando ed, busto del tutorial (48c3a0) con el texto a y la posicion b
## de la tabla de la pila; c = 0 lo muestra de frente.
func f40b6c0() -> int:
	if cmd_step() == 0:
		var table := [0x104, 500, 0xffffffff, 0x104, 100, 0xffffffff, 0x10, 500, 0xffffffff,
				0x10, 100, 0xffffffff, 0x104, 500, 4, 0x104, 100, 5, 0x10, 500, 6, 0x10, 100, 7,
				0x104, 100, 4]
		cmd_advance()
		var b := cmd_b()
		var c_zero := int(cmd_c() == 0)
		var text := f402560(cmd_a())
		# Con b > 8 el original lee la pila fuera de la tabla (solo argumentos de presentacion).
		var row := [0, 0, 0]
		for i in 3:
			if b * 3 + i < table.size():
				row[i] = table[b * 3 + i]
		f48c3a0(0, row[0], row[1], text, row[2], c_zero)
		return 0
	cmd_finish()
	return 0


## Joey FUN_0040b800: comando ee, quita el busto del tutorial (+0x170) y espera.
func f40b800() -> int:
	if cmd_step() == 0:
		cmd_advance()
		# Escritura del objeto del tutorial (+0x170 = 0) omitida.
		return 0
	cmd_finish()
	return 0


## Joey FUN_0040b850: comando ef, mueve el foco del tutorial: con el bit de jugador interpola
## entre dos puntos empaquetados en a, b, c (48d0f0); si no, va a (a, b) en c ticks (48d190).
func f40b850() -> int:
	if cmd_step() != 0:
		cmd_finish()
		return 0
	cmd_advance()
	var a := cmd_a()
	var b := cmd_b()
	var c := cmd_c()
	var to := m.local(8)
	if m.u16(JoeyMem.CMD) & 0x8000:
		var x0 := a / 10
		var y0 := b / 100 + (a % 10) * 100
		var dx := _cdiv(c / 1000 + (b % 100) * 10 - x0, 2)
		var dy := _cdiv(c % 1000 - y0, 2)
		var step := m.local(8)
		m.set_u32(to, x0 + dx)
		m.set_u32(to + 4, y0 + dy)
		m.set_u32(step, dx & 0xffffffff)
		m.set_u32(step + 4, dy & 0xffffffff)
		f48d0f0(0, to, step)
		return 0
	m.set_u32(to, a)
	m.set_u32(to + 4, b)
	f48d190(0, to, c)
	return 0


## Joey FUN_0040b9c0: comando f0, cierra el tutorial (48d230) y espera.
func f40b9c0() -> int:
	if cmd_step() == 0:
		cmd_advance()
		f48d230(0)
		return 0
	cmd_finish()
	return 0


## Joey FUN_0040ba20: comando f1, pausa de a ticks: avanza el paso y termina cuando el paso
## previo llega a a (el paso da la vuelta en 0x7f).
func f40ba20() -> int:
	var s := m.u32(JoeyMem.CMD_STATE)
	var next := s ^ (((s + 1) ^ s) & 0x7f)
	if (s & 0x7f) >= cmd_a():
		next &= 0xffffbfff
	m.set_u32(JoeyMem.CMD_STATE, next)
	return 0


## Joey FUN_0040ba60: comando f2, fija la carta y la ubicacion senaladas por el tutorial.
func f40ba60() -> int:
	# Escrituras del objeto del tutorial (+0x18 = a, +0x10 = ubicacion con CX del llamador)
	# omitidas.
	cmd_finish()
	return 0


## Joey FUN_0040bad0: comando f3, el tutorial espera un clic: sobre el objeto senalado en la
## ubicacion (b, c) o, sin objeto, con b >= 0x10; a = 1/2 exige ademas 5bf180/5bf1a0.
func f40bad0() -> int:
	var p := cmd_p()
	var a := cmd_a()
	var b := cmd_b()
	var c := cmd_c()
	var obj := m.u32(_JJ_POINTED)
	if obj == 0:
		if b < 0x10:
			return 0
	else:
		var loc := m.local(4)
		var where := _jj_u16_at(f418b50(obj, loc))
		if (where & 1) != p or ((where >> 1) & 0x1f) != b or ((where >> 6) & 0xff) != c:
			return 0
		m.set_u8(_JJ_SELECTED, 1)
	if a != 0:
		var ok := f5bf180() if a == 1 else f5bf1a0()
		if ok == 0:
			return 0
	cmd_finish()
	return 0


## Joey FUN_0040bbb0: comando f4, coloca la carta b del jugador en la zona a (monstruo con cara
## c % 10 y posicion c / 10 == 0, o magia con c == 0) con nueva identidad.
func f40bbb0() -> int:
	var p := cmd_p()
	var a := cmd_a()
	var b := cmd_b()
	var c := cmd_c()
	var entry := m.local(4)
	m.set_u32(entry, (f402460(b) & 0xfff) | ((p & 1) << 12) | 0x4000)
	var where := m.local(4)
	var slot: int
	if a < 5:
		var face := c % 10
		var up := int(c / 10 == 0)
		var code := ((((((face & 1) | (up << 1)) << 8) | (a % 5)) << 5) | ((a / 5) * 5 & 0x1f)) << 1
		m.set_u16(where, (code | (p & 1)) & 0xffff)
		f41d160(m.u32(_JJ_HAND_OBJ), f402460(b) & 0xffff, where)
		f568610(p, a % 5, entry, face, up)
		slot = f5700f0(p, a, 0)
	elif a > 10:
		cmd_finish()
		return 0
	else:
		var down := int(c == 0)
		var col := 0
		var base := a
		if a < 10:
			col = a % 5
			base = (a / 5) * 5
		var code := (((((col & 0xff) | (down << 9)) << 5) | (base & 0x1f)) << 1) | (p & 1)
		m.set_u16(where, code & 0xffff)
		f41d160(m.u32(_JJ_HAND_OBJ), f402460(b) & 0xffff, where)
		f5686e0(p, a, entry, down)
		slot = f5700f0(p, a, 0)
	# Identidad: contador u16 en +6 del jugador (p sin enmascarar).
	var ident := JoeyMem.PLAYER + p * JoeyMem.PLAYER_SIZE + 6
	m.set_u32(slot, ((m.u8(ident) & 0x7f) << 24) | (m.u32(slot) & 0x80ffffff))
	m.set_u16(ident, m.u16(ident) + 1)
	cmd_finish()
	return 0


## Joey FUN_0040be00: comando f5, abre el cuadro de mensaje b (con variantes para 0xa9-0xcb y
## 0x8c) del tipo a con argumento c; el tipo 8 guarda c en a55d3c y a57814.
func f40be00() -> int:
	var a := cmd_a()
	var b := cmd_b()
	var c := cmd_c()
	if cmd_step() == 0:
		cmd_advance()
		if b < 0xa9 or b > 0xcb:
			if b == 0x8c:
				var text := m.local(0x100)
				f5bdf40(text, 0x8c, f402290(f402460(c)))
				f5bf800(text)
			else:
				f5bf800(b)
		else:
			var text := m.local(0x100)
			f5bde30(text, b)
			f5bde70(text, 0x5eb5d8)
			f5bde70(text, 0xcc)
			f5bf800(text)
		if a == 8:
			var v := m.u32(0xa55d3c)
			m.set_u32(0xa55d3c, v ^ ((v ^ c) & 0xff))
			m.set_u16(0xa57814, m.u16(0xa57814) | ((c >> 8) & 1))
		f5bf9a0(a, c)
		f5bf9c0()
	if visual_busy("dialog", 0, 0, 0x40bf17): return 0
	cmd_finish()
	return 0


## Joey FUN_0040bf30: comando f6, objeto de batalla (413af0 con a, 413b20).
func f40bf30() -> int:
	f413af0(cmd_a())
	f413b20()
	cmd_finish()
	return 0


## Joey FUN_0040bf60: comando f7, fija el temporizador del tutorial (b << 16 + a) y espera a
## que vuelva a 0.
func f40bf60() -> int:
	if cmd_step() == 0:
		cmd_advance()
		tutorial_wait = ((cmd_b() << 16) + cmd_a()) & 0xffffffff
		return 0
	if tutorial_wait == 0:
		cmd_finish()
	return 0


## Joey FUN_0040bfc0: comando f8, si la respuesta a558b4 es b salta a la marca a de la
## grabacion (40bff0).
func f40bfc0() -> int:
	if m.u16(_JJ_ANSWER) == cmd_b():
		f40bff0()
	cmd_finish()
	return 0


## Joey FUN_0040bff0: comando f9, busca en la lista grabada la marca 0xfa con argumento a; si no
## la encuentra vuelve el cursor al principio.
func f40bff0() -> int:
	var a := cmd_a()
	f449e10()
	var end := f449e20()
	while end == 0:
		f449e00()
		if _jj_u16_at(f449df0()) == 0xfa and _jj_u16_at(f449df0() + 2) == a:
			cmd_finish()
			return 0
		end = f449e20()
	f449e10()
	cmd_finish()
	return 0


## Joey FUN_0040c050: comandos 12, 13, 41, 74, a1 y fa (marca), sin efecto: termina.
func f40c050() -> int:
	cmd_finish()
	return 0


## Joey FUN_0040c060: comando 100, ajuste a del tutorial (48d6a0).
func f40c060() -> int:
	f48d6a0(0, cmd_a())
	cmd_finish()
	return 0


## Joey FUN_0040c090: comando fb, abre la lista de candidatos (40c940) de tipo c (6, o 0xb si
## a es 0xaa) y, al cerrarse la ventana, copia la eleccion a558b4.
func f40c090() -> int:
	var c := m.u16(JoeyMem.CMD + 6)
	if cmd_step() != 0:
		if visual_busy("dialog", 0, 0, 0x40c112): return 0
		cmd_finish()
		m.set_u16(_JJ_ANSWER, m.u16(_JJ_LIST_CHOICE))
		return 0
	cmd_advance()
	if c == 0:
		c = 0xb if cmd_a() == 0xaa else 6
	f40c940(cmd_p(), c, cmd_a(), cmd_b())
	return 0


## Joey FUN_0040c140: comando fc, con a = 1 busca en la lista la entrada de orden b y deja su
## id en a558b4.
func f40c140() -> int:
	var b := cmd_b()
	if cmd_a() == 1:
		var i := 0
		if _s32(f40cae0()) > 0:
			while f40cc90(i) != b:
				i += 1
				if i >= _s32(f40cae0()):
					cmd_finish()
					return 0
			m.set_u16(_JJ_ANSWER, f4022e0(f40caf0(i)) & 0xffff)
	cmd_finish()
	return 0


## Joey FUN_0040c1b0: comando ff, cambia la carta de la entrada (a & 0xff, a >> 8) por b si
## hay objeto visual.
func f40c1b0() -> int:
	var a := cmd_a()
	var loc := a & 0xff
	var i := a >> 8
	var p := cmd_p()
	var card := f402460(cmd_b()) & 0xffff
	if f41cee0(p, loc, i) != 0:
		# Metodo +0x10 (imagen) del objeto omitido.
		var at := f5700f0(p, loc, i)
		var v := m.u32(at)
		m.set_u32(at, ((v ^ card) & 0xfff) ^ v)
	cmd_finish()
	return 0


## Joey FUN_0040c940: prepara la lista de candidatos de tipo n para p (599e30); si p es CPU y
## n >= 6 elige con la IA (5af5a0 para 6, 5afe10 para 7-0x16 y 0x18-0x27); si no, abre la
## ventana de la lista (43a060).
func f40c940(p: int, n: int, a: int, b: int) -> int:
	m.set_u16(_JJ_LIST, ((n * 2) | (p & 1)) & 0xffff)
	m.set_u16(_JJ_LIST_CHOICE, 0)
	f5bddf0(_JJ_LIST_ENTRIES, 0x200)
	f5bddf0(_JJ_LIST_ORDER, 0x100)
	var sn := _s32(n)
	if sn < 6 or ((((m.u8(JoeyMem.MODE) >> 1) & 3) >> (p & 0x1f)) & 1) == 0:
		f599e30(p, a, b)
		# new(0x2b4) + 43a060 (ventana; 0 sin pantalla), metodo +4 de 5f3280+0x1304 y alta en
		# +0x1308 omitidos.
		f43a060(0, p, n)
		return 0
	if sn == 6:
		f5af5a0(p, f402460(a), b)
		return 0
	if sn > 6 and sn <= 0x16:
		f5afe10(p, f402460(a), b, sn - 6)
	elif sn > 0x17 and sn <= 0x27:
		f5afe10(p, f402460(a), b, sn - 0x17)
	return 0


## Joey FUN_0040cae0: numero de entradas de la lista de candidatos.
func f40cae0() -> int:
	return m.u16(_JJ_LIST_N)


## Joey FUN_0040caf0: indice (12 bits) de la entrada i; en listas de tipo 8 del rival comprueba
## antes con 570420 que la carta siga en excluidas (si no, 0).
func f40caf0(i: int) -> int:
	var at := _JJ_LIST_ENTRIES + i * 4
	var owner := (m.u32(at) >> 12) & 1
	if (m.u16(_JJ_LIST) & 0xfffe) == 8 and owner == ((~m.u8(JoeyMem.MODE)) & 1):
		if f570420(owner, 0xf, i) == 0:
			return 0
	return m.u32(at) & 0xfff


## Joey FUN_0040cc90: orden de la entrada i (byte alto de a584a4[i]).
func f40cc90(i: int) -> int:
	return m.u16(_JJ_LIST_ORDER + i * 2) >> 8


## Joey FUN_0040cd70: buzon tipo t (valor (t & 0x7f) << 1 | 1) con el dato d.
func f40cd70(t: int, d: int) -> int:
	m.set_u32(_JJ_MAIL_DATA, d & 0xffffffff)
	m.set_u16(_JJ_MAIL, ((t & 0x7f) << 1) | 1)
	return 0


## Joey FUN_0040cdb0: buzon tipo 3 (valor 7): carta v de la ubicacion *from a *to.
func f40cdb0(v: int, from: int, to: int) -> int:
	m.set_u32(_JJ_MAIL_DATA, v & 0xffff)
	m.set_u16(_JJ_MAIL_FROM, m.u16(from))
	m.set_u16(_JJ_MAIL_TO, m.u16(to))
	m.set_u16(_JJ_MAIL, 7)
	return 0


## Joey FUN_0040ce10: buzon tipo 4 (valor 9): carta v de *from a *to.
func f40ce10(v: int, from: int, to: int) -> int:
	m.set_u32(_JJ_MAIL_DATA, v & 0xffff)
	m.set_u16(_JJ_MAIL_FROM, m.u16(from))
	m.set_u16(_JJ_MAIL_TO, m.u16(to))
	m.set_u16(_JJ_MAIL, 9)
	return 0


## Joey FUN_0040ce70: buzon tipo 5 (valor 0xb): carta v con la ubicacion *at como origen y
## destino.
func f40ce70(v: int, at: int) -> int:
	m.set_u32(_JJ_MAIL_DATA, v & 0xffff)
	var where := m.u16(at)
	m.set_u16(_JJ_MAIL_FROM, where)
	m.set_u16(_JJ_MAIL_TO, where)
	m.set_u16(_JJ_MAIL, 0xb)
	return 0


## Joey FUN_0040ced0: buzon tipo 6 (valor 0xd): ubicaciones *from y *to, conserva el dato.
func f40ced0(from: int, to: int) -> int:
	m.set_u16(_JJ_MAIL_FROM, m.u16(from))
	m.set_u16(_JJ_MAIL_TO, m.u16(to))
	m.set_u16(_JJ_MAIL, 0xd)
	return 0


## Joey FUN_005b9370: anade el comando (op, a, b, c) al final de la cola si cabe (< 0x100).
func f5b9370(op: int, a: int, b: int, c: int) -> int:
	var n := m.u16(JoeyMem.QUEUE_COUNT)
	if n >= JoeyMem.QUEUE_MAX:
		return 0
	m.set_u16(JoeyMem.QUEUE + n * 8, op)
	m.set_u16(JoeyMem.QUEUE + m.u16(JoeyMem.QUEUE_COUNT) * 8 + 2, a)
	m.set_u16(JoeyMem.QUEUE + m.u16(JoeyMem.QUEUE_COUNT) * 8 + 4, b)
	m.set_u16(JoeyMem.QUEUE + m.u16(JoeyMem.QUEUE_COUNT) * 8 + 6, c)
	m.set_u16(JoeyMem.QUEUE_COUNT, m.u16(JoeyMem.QUEUE_COUNT) + 1)
	return 0


## Joey FUN_005b93f0: comando recibido por red: lo deja pendiente en a5828c (fase 0, bandera
## 0x80 de a58260) y lo graba (449d50).
func f5b93f0(op: int, a: int, b: int, c: int) -> int:
	m.set_u16(_JJ_NET_PHASE, m.u16(_JJ_NET_PHASE) & 0xff00)
	m.set_u16(_JJ_NET_CMD, op)
	m.set_u16(_JJ_NET_CMD + 2, a)
	m.set_u16(_JJ_NET_CMD + 4, b)
	m.set_u16(_JJ_NET_CMD + 6, c)
	m.set_u32(_JJ_NET_FLAGS, m.u32(_JJ_NET_FLAGS) | 0x80)
	var copy := m.local(8)
	m.set_u16(copy, op)
	m.set_u16(copy + 2, a)
	m.set_u16(copy + 4, b)
	m.set_u16(copy + 6, c)
	f449d50(copy)
	return 0


## Byte bajo de a58294 + 1 (fase del comando de red), sin tocar el alto.
func _jj_next_net_phase() -> void:
	var v := m.u16(_JJ_NET_PHASE)
	m.set_u16(_JJ_NET_PHASE, v ^ (((v + 1) ^ (v & 0xff)) & 0xff))


## Byte alto de a5780e + 1 (fase de la extraccion), conservando el bajo.
func _jj_next_queue_phase() -> void:
	var v := m.u16(_JJ_QUEUE_PHASE)
	m.set_u16(_JJ_QUEUE_PHASE, (((v & 0xff00) + 0x100) ^ (v & 0xff)) & 0xffff)


## Joey FUN_005b9bf0: ejecuta el comando de red pendiente: fase 0 lo copia como comando en
## curso, fase 1 lo despacha hasta que termina y fase 2 confirma (0xf042) y baja la bandera.
func f5b9bf0() -> int:
	var phase := m.u8(_JJ_NET_PHASE)
	if phase > 2:
		return 1
	if phase == 0:
		m.copy(JoeyMem.CMD, _JJ_NET_CMD, 8)
		m.set_u32(JoeyMem.CMD_STATE, (m.u32(JoeyMem.CMD_STATE) & 0xffffff80) | 0x4000)
		_jj_next_net_phase()
		phase = 1
	if phase == 1:
		f5b9470()
		if m.u32(JoeyMem.CMD_STATE) & 0x4000:
			return 1
		_jj_next_net_phase()
	f5bd050(0xf042, 0, 0, 0)
	m.set_u32(_JJ_NET_FLAGS, m.u32(_JJ_NET_FLAGS) & 0xffffff7f)
	return 1


## Joey FUN_005b9ca0: un tick de la cola: saca el siguiente comando (fase 0), lo despacha hasta
## que termina (fase 1) y cierra (fase 2); en red atiende antes el comando recibido (5b9bf0) y en
## repeticion con la cola vacia reinyecta lo grabado (5bc580). 1 si hay trabajo en curso.
func f5b9ca0() -> int:
	if m.u8(JoeyMem.TURN) & 0x10 and m.u32(_JJ_NET_FLAGS) & 0x80:
		return f5b9bf0()
	var phase := m.u16(_JJ_QUEUE_PHASE) >> 8
	if phase > 2:
		return 0
	if phase == 0:
		if m.u16(JoeyMem.QUEUE_COUNT) == 0:
			return 0
		m.copy(JoeyMem.CMD, JoeyMem.QUEUE, 8)
		m.set_u16(JoeyMem.QUEUE_COUNT, m.u16(JoeyMem.QUEUE_COUNT) - 1)
		if m.u16(JoeyMem.QUEUE_COUNT) != 0:
			var i := 0
			var at := JoeyMem.QUEUE
			while true:
				m.copy(at, at + 8, 8)
				i += 1
				at += 8
				if i >= m.u16(JoeyMem.QUEUE_COUNT):
					break
		m.set_u32(_JJ_NET_FLAGS, m.u32(_JJ_NET_FLAGS) | 0x100)
		m.set_u32(JoeyMem.CMD_STATE, m.u32(JoeyMem.CMD_STATE) | 0x4000)
		if m.u8(JoeyMem.TURN) & 0x10:
			f5bd090(0xf041, JoeyMem.CMD, 8)
			m.set_u32(_JJ_NET_FLAGS, m.u32(_JJ_NET_FLAGS) & 0xfffffeff)
		m.set_u32(JoeyMem.CMD_STATE, m.u32(JoeyMem.CMD_STATE) & 0xffffc000)
		_jj_next_queue_phase()
		phase = 1
	if phase == 1:
		f5b9470()
		if m.u32(JoeyMem.CMD_STATE) & 0x4000:
			return 1
		_jj_next_queue_phase()
	if m.u32(_JJ_NET_FLAGS) & 0x100 == 0:
		return 1
	m.set_u16(_JJ_QUEUE_PHASE, m.u16(_JJ_QUEUE_PHASE) & 0xff)
	if m.u16(JoeyMem.QUEUE_COUNT) != 0:
		return 1
	if (m.u32(JoeyMem.MODE) & 0x180) == 0x80 and m.u32(JoeyMem.CMD_STATE) & 0x4000 == 0:
		f5bc580(0)
		return 1
	return 0
