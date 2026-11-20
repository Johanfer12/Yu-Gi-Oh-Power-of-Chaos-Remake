class_name JoeyPortY
extends JoeyPortW
## Etapa 4: recorridos reales de mantenimiento de fases y puentes de reglas.
## Fuentes: tablas 5dd010/5dd038 y funciones C/ASM con la direccion del nombre.


func _jy_chain(p: int, z: int, entry: int, kind: int) -> void:
	f5ba490((((z & 0x1f) | (p << 15) | kind) << 16) | (entry & 0xfff), JoeyMem.ident(entry), 0)


func _jy_mark(p: int, z: int, entry: int) -> void:
	f578390(p, entry & 0xfff, z)


func _jy_link(p: int, z: int, ref: int) -> bool:
	if ref & 0xffff == 0xffff:
		return false
	var target := (ref & 0xffff) >> 8
	var link := f56dc10(ref & 0xff, target, p, z)
	return m.u16(0xa55dc0 + (ref & 1) * 0xd44 + target * 0x90 + link * 2) & 0xf == 1


func _jy_trigger(p: int, z: int, entry: int, action: String) -> bool:
	match action:
		"chain820", "chain20":
			_jy_chain(p, z, entry, 0x820 if action == "chain820" else 0x20)
		"final":
			if _s32(f56a400(p)) < 0:
				return false
			_jy_chain(p, z, entry, 0x820)
		"destroy":
			_jy_mark(p, z, entry)
			f5779d0(p, z, 0, 0)
		"return":
			if f569d50(p) != 1:
				return false
			_jy_mark(p, z, entry)
			if m.u8(JoeyMem.zone(p, z) + 6) & 1 == 0:
				f575190(p, z, 0, 0, 0)
			f579990(p, z, 0x11, 1)
		"heal_atk", "heal_def", "heal800":
			var def_mode := m.u8(JoeyMem.zone(p, z) + 6) & 1
			if (action == "heal_atk" and def_mode != 0) or (action == "heal_def" and def_mode == 0):
				return false
			_jy_mark(p, z, entry)
			f5787f0(p, 800 if action == "heal800" else 1000)
		"damage300", "damage_other", "heal_other", "heal_hand":
			if action == "heal_hand" and _s32(f56d240(1 - p)) == -1:
				return false
			_jy_mark(p, z, entry)
			match action:
				"damage300": f5784e0(p, 300)
				"damage_other": f5784e0(1 - p, 500)
				_: f5787f0(1 - p, 1000)
		"linked":
			var ref := f56fb40(p, z) & 0xffff
			if ref == 0xffff:
				return false
			_jy_mark(p, z, entry)
			f5784e0(ref & 0xff, 500)
		"linked_heal", "linked_destroy":
			var ref := f56fb40(p, z)
			if not _jy_link(p, z, ref):
				return false
			if action == "linked_destroy" and m.u8(JoeyMem.zone(p, z) + 6) & 0x3c:
				return false
			_jy_mark(p, z, entry)
			var q := ref & 0xff
			var target := (ref & 0xffff) >> 8
			if action == "linked_heal":
				f5787f0(p, f5be050(f56f690(q, target)))
			elif f56c460(q, target) == 0:
				var damage := f56f690(q, target)
				f577840(q, target, int(q != p), entry & 0xfff)
				f5784e0(1 - p, damage)
			else:
				f577840(p, z, 0, entry & 0xfff)
		"insect":
			var count := _s32(f56ce40(1 - p, 1))
			if count == 0:
				return false
			_jy_mark(p, z, entry)
			f5784e0(1 - p, count * 100)
		"token", "jam":
			if action == "token" and (f570af0(p) == 0 or f56a000(p) == 0):
				return false
			if action == "jam" and (f56db30(p, z, 0x2f9) == 0 or _s32(f56a030(p)) < 0 or f570b40(p) == 0):
				return false
			var at := m.local(4)
			m.set_u32(at, (f402460(0x783 if action == "token" else 0x780) & 0xfff) | ((p & 1) << 12))
			_jy_mark(p, z, entry)
			f5ada20(p, at, 1, 0, 1, 0, 0)
			if action == "jam":
				f574900(p, z, 0x2f9, 0)
				return true
	return true


func _jy_scan(p: int, card: int, offset: int, limit: int, owner: int, action: String) -> int:
	while m.u16(_JS_WORK) & 0x7f00 < limit * 0x100:
		var count := (m.u32(_JS_WORK) >> 8) & 0x7f
		var q := p
		var z := count + offset
		if owner == 1:
			q = 1 - p
		elif owner == 2:
			q = (count / 5) ^ p
			z = count % 5 + offset
		var entry := m.u32(JoeyMem.zone(q, z))
		if f569790(q, z, card) != 0:
			if action == "damage500":
				_jy_mark(q, z, entry)
				f5784e0(p, 500)
				_js_next_zone()
				return 0
			if _jy_trigger(q, z, entry, action):
				# Jam no avanza al crear la ficha; el enlace que retira cambia el siguiente pase.
				if action != "jam":
					_js_next_zone()
				return 0
		_js_next_zone()
	return 1


## Joey FUN_005a4370: recorrido de 0x228, chain820.
func f5a4370(p: int) -> int:
	return _jy_scan(p, 0x228, 0, 5, 0, "chain820")


## Joey FUN_005a4480: recorrido de 0x16, destroy.
func f5a4480(p: int) -> int:
	return _jy_scan(p, 0x16, 0, 5, 0, "destroy")


## Joey FUN_005a4ab0: recorrido de 0x2f9, jam.
func f5a4ab0(p: int) -> int:
	return _jy_scan(p, 0x2f9, 0, 10, 2, "jam")


## Joey FUN_005a4860: recorrido de 0x5f8, final.
func f5a4860(p: int) -> int:
	return _jy_scan(p, 0x5f8, 5, 5, 1, "final")


## Joey FUN_005a4990: recorrido de 0x5ef, chain820.
func f5a4990(p: int) -> int:
	return _jy_scan(p, 0x5ef, 0, 5, 1, "chain820")


## Joey FUN_005a6120: recorrido de 0x459, return.
func f5a6120(p: int) -> int:
	return _jy_scan(p, 0x459, 0, 5, 0, "return")


## Joey FUN_005a6240: recorrido de 0x59d, heal_atk.
func f5a6240(p: int) -> int:
	return _jy_scan(p, 0x59d, 0, 5, 0, "heal_atk")


## Joey FUN_005a6340: recorrido de 0x59e, heal_def.
func f5a6340(p: int) -> int:
	return _jy_scan(p, 0x59e, 0, 5, 0, "heal_def")


## Joey FUN_005a6440: recorrido de 0x5a1, heal800.
func f5a6440(p: int) -> int:
	return _jy_scan(p, 0x5a1, 0, 5, 0, "heal800")


## Joey FUN_005a6630: recorrido de 0x5fd, insect.
func f5a6630(p: int) -> int:
	if m.u16(_JS_WORK) & 0x7f00 == 0:
		m.set_u16(_JS_WORK, (m.u16(_JS_WORK) & 0x85ff) | 0x500)
	return _jy_scan(p, 0x5fd, 0, 10, 0, "insect")


## Joey FUN_005a6870: recorrido de 0x589, linked.
func f5a6870(p: int) -> int:
	return _jy_scan(p, 0x589, 5, 5, 0, "linked")


## Joey FUN_005a6990: recorrido de 0x58b, linked.
func f5a6990(p: int) -> int:
	return _jy_scan(p, 0x58b, 5, 5, 0, "linked")


## Joey FUN_005a7940: recorrido de 0x2db, chain20.
func f5a7940(p: int) -> int:
	return _jy_scan(p, 0x2db, 0, 5, 0, "chain20")


## Joey FUN_005a6030: recorrido de 0x228, damage300.
func f5a6030(p: int) -> int:
	return _jy_scan(p, 0x228, 0, 5, 0, "damage300")


## Joey FUN_005a6760: recorrido de 0x51f, damage500.
func f5a6760(p: int) -> int:
	return _jy_scan(p, 0x51f, 5, 10, 2, "damage500")


## Joey FUN_005a6f90: recorrido de 0x492, linked_heal.
func f5a6f90(p: int) -> int:
	return _jy_scan(p, 0x492, 5, 5, 1, "linked_heal")


## Joey FUN_005a6dc0: recorrido de 0x2df, linked_destroy.
func f5a6dc0(p: int) -> int:
	return _jy_scan(p, 0x2df, 5, 5, 1, "linked_destroy")


## Joey FUN_005a6cc0: recorrido de 0x516, damage_other.
func f5a6cc0(p: int) -> int:
	return _jy_scan(p, 0x516, 5, 5, 1, "damage_other")


## Joey FUN_005a6ab0: recorrido de 0x42c, heal_other.
func f5a6ab0(p: int) -> int:
	return _jy_scan(p, 0x42c, 5, 5, 1, "heal_other")


## Joey FUN_005a6bb0: recorrido de 0x445, heal_hand.
func f5a6bb0(p: int) -> int:
	return _jy_scan(p, 0x445, 5, 5, 1, "heal_hand")


## Joey FUN_005a7800: recorrido de 0x592, token.
func f5a7800(p: int) -> int:
	return _jy_scan(p, 0x592, 5, 5, 0, "token")


## Joey FUN_005a76e0: recorrido de 0x5ed, chain20.
func f5a76e0(p: int) -> int:
	return _jy_scan(p, 0x5ed, 0, 5, 1, "chain20")


## Tabla nativa de 443 filas; reproduce la busqueda binaria, incluido su limite.
func f59dbe0(index: int) -> int:
	var id := f4022e0(index) & 0xffff
	var lo := 0
	var hi := 0x1ba
	var mid := 0xdd
	while true:
		var value := m.u16(0x5ed0a8 + mid * 24)
		if id == value:
			return mid
		if lo == hi:
			return 0xffffffff
		if value < id:
			lo = mid
		if id < value:
			hi = mid
		if (hi + lo) / 2 == mid:
			lo = hi
		mid = (hi + lo) / 2
	return 0xffffffff


## Las columnas E tienen distinta aridad C; los argumentos sobrantes del llamador se ignoran.
var _jy_arities: Dictionary = {}


func _jy_effect(address: int, args: Array) -> int:
	var name := StringName("f%06x" % address)
	if not _jy_arities.has(name):
		if not has_method(name):
			return _unported(address)
		# Consultar el método concreto evita enumerar toda la jerarquía en el turno.
		_jy_arities[name] = get_method_argument_count(name)
	var arity := int(_jy_arities[name])
	var actual := args.slice(0, arity)
	while actual.size() < arity:
		actual.append(0)
	return int(callv(name, actual))


func f59dd90(effect: int, target: int, flag: int) -> int:
	var row := _s32(f59dbe0(m.u16(effect)))
	if row < 0:
		return 0
	var at := 0x5ed0a8 + row * 24
	var filter := m.u32(at + 12)
	if filter != 0:
		var result := _s32(_jy_effect(filter, [effect, target, flag]))
		if result == 0:
			return 0
		if result > 1:
			return 1
	var candidate := m.u32(at + 8)
	if candidate == 0:
		return 1
	for p in 2:
		for z in 11:
			if _jy_effect(candidate, [effect, (z << 8) | p]) != 0:
				return 1
	return 0


func f57e0c0(index: int) -> int:
	f4022e0(index)
	var kind := s16(f4025d0(index))
	f402740(index)
	var subtype := s16(f402700(index))
	if kind == 0x15:
		return 3 - int(subtype != 1)
	if kind == 0x16:
		return int(subtype == 5) + 1
	var id := f4022e0(index) & 0xffff
	return 2 if id in [0x5f5, 0x39, 0x172, 0x173, 0x174, 0x76d] else 1


func f57c450(p: int, index: int) -> int:
	match f4022e0(index) & 0xffff:
		0x191, 0x3ba, 0x406, 0x42e, 0x42f, 0x49f: return 1000
		0x488: return 800
		0x489, 0x3f9: return 500
		0x4bc, 0x404: return f5be070(m.u16(JoeyMem.pl(p) + 4))
		0x1a3: return 5000
		0x1f9: return 3000
	return 0


## ABI cdecl con dos argumentos: ECX en Ghidra solo era residuo de registro.
func f57eac0(effect: int, target: int) -> int:
	var bits := m.u16(effect + 2)
	var p := ((bits >> 14) & 1) ^ (bits & 1)
	var special := bits & 0x3e == 0x16
	var id := s16(f4022e0(m.u16(effect)))
	if id != 0x51 and id != 0x186 and f56b440(m.u16(effect), (m.u16(effect + 4) & 0x1fe0) >> 5) != 0:
		if p == m.u32(JoeyMem.MODE) & 1:
			f45e240(0x10)
		return 0
	var kind := s16(f4025d0(m.u16(effect)))
	if (kind == 0x15 and f5699c0(0x2ef) != 0) or (f567620(m.u16(effect), 0xffffffff) != 0 and f5699c0(0x5fa) != 0):
		if p == m.u32(JoeyMem.MODE) & 1:
			f45e240(0x14)
		return 0
	if target != 0 and _s32(f57e0c0(m.u16(effect))) < _s32(f57e0c0(m.u16(target))):
		return 0
	var cost := _s32(f57c450(p, m.u16(effect)))
	if special:
		cost += _s32(f5699c0(0x436)) * 500
	if m.u16(JoeyMem.pl(p) + 4) <= cost:
		if p == m.u32(JoeyMem.MODE) & 1:
			f45e240(0x17)
		return 0
	return f59dd90(effect, target, int(special))


func f57ee80(packed: int, ident: int, data: int) -> int:
	var at := m.local(20)
	var bits := (((((packed >> 24) & 1) << 2) | ((packed >> 21) & 3)) << 6) | ((packed >> 25) & 0x3f)
	bits = (((bits << 5) | ((packed >> 16) & 0x1f)) << 1) & 0xffff
	m.set_u16(at, packed)
	m.set_u16(at + 2, bits | ((packed >> 31) & 1))
	m.set_u16(at + 4, (ident & 0xff) << 5)
	m.set_u32(at + 14, data << 16)
	m.set_u16(at + 18, data >> 16)
	if bits & 0x3000 == 0x1000 and m.u8(at + 2) & 0x3e < 0x15:
		if m.u8(JoeyMem.zone(m.u16(at + 2) & 1, (bits >> 1) & 0x1f) + 0x8c) & 0x20:
			return 0
	return f57eac0(at, 0)


func f581050(effect: int, target: int) -> int:
	var bits := m.u16(effect + 2)
	if bits & 0x3000 == 0x2000:
		var p := bits & 1
		if target != 0 or (bits ^ m.u8(JoeyMem.TURN)) & 1 or m.u32(0xa577ec) & 1:
			return 0
		if f570b40(p) == 0 or f56a000(p) == 0 or m.u32(JoeyMem.pl(p) + 0x6d0) & 0x1000000 == 0:
			return 0
		var id := f4022e0(m.u16(effect))
		if f5709d0(p, id) == 0 or f599e30(p, id, 0) == 0:
			return 0
	return 1


func f582d80(effect: int, target: int) -> int:
	var bits := m.u16(effect + 2)
	if bits & 0x3000 == 0x2000:
		var p := bits & 1
		if target != 0 or (bits ^ m.u8(JoeyMem.TURN)) & 1 or m.u32(0xa577ec) & 1:
			return 0
		var id := f4022e0(m.u16(effect))
		if f5709d0(p, id) == 0 or f599e30(p, id, 0) == 0:
			return 0
	elif f56a140(((bits >> 14) & 1) ^ (bits & 1), bits & 1, (bits >> 1) & 0x1f) == 0:
		return 0
	return 1


func f40cab0() -> int:
	return 0xa582a4 + m.u16(0xa582a2) * 4


func f5929d0() -> int:
	var loc := _s32(m.u32(0xa55048))
	if loc >= 0 and loc < 12:
		f45e240(9)
	return 0


func f5b88a0() -> int:
	m.copy(0xa5505c, 0xa55044, 12)
	return 0


func f5b88d0() -> int:
	return int(m.u32(0xa55064) != m.u32(0xa5504c) or m.u32(0xa5505c) != m.u32(0xa55044) or m.u32(0xa55060) != m.u32(0xa55048))


func f5bdbd0(p: int, loc: int, n: int) -> int:
	m.set_u32(0xa55050, p)
	m.set_u32(0xa55054, loc)
	m.set_u32(0xa55058, n)
	if loc == 0:
		if n == 10:
			m.set_u32(0xa55054, n)
			m.set_u32(0xa55058, loc)
			f5bee80(p, 0, 10)
			return 0
		if _s32(n) > 4:
			m.set_u32(0xa55058, n - 5)
			m.set_u32(0xa55054, 5)
	f5bee80(p, loc, n)
	return 0


func f5a0cd0() -> int:
	if f5beed0() != 0 and m.u8(0xa54e54) & 2 == 0:
		if f5b88d0() != 0 or m.u16(0xa57804) & 1 == 0:
			m.set_u16(0xa57808, m.u16(0xa57808) & 0xff00)
			f5bf4b0()
			f5a0090()
		f5b88a0()
		if m.u16(0xa57804) & 1 == 0:
			m.set_u16(0xa57808, m.u16(0xa57808) & 0xff00)
			f5bf4b0()
		elif f5b8910() != 0:
			m.set_u16(0xa57804, m.u16(0xa57804) | 4)
			return 1
		return 1
	m.set_u16(0xa57804, m.u16(0xa57804) & 0xfffe)
	m.set_u16(0xa57808, m.u16(0xa57808) & 0xff00)
	f5bf4b0()
	return 0


func f5a0dd0(p: int) -> int:
	if m.u16(0xa577f8) == 0 or m.u32(JoeyMem.pl(p) + 0x6d0) & 0x40000:
		return 0
	f5a0d60(0xa55d64, p, 0, 1)
	return int(m.u16(JoeyMem.pl(p) + 0xe) != 0)


func f5a0d60(base: int, p: int, _unused: int, fresh: int) -> int:
	var at := base + (p & 1) * 0xd44
	var old := m.u16(at + 12)
	m.set_u16(at + 10, 0)
	if fresh != 0:
		m.set_u16(at + 12, 0)
	for z in 5:
		if f56b730(p, z, 1) != 0:
			m.set_u16(at + 10, m.u16(at + 10) | (1 << z))
	m.set_u16(at + 12, old)
	return 0


func _jy_windows(effect: int, target: int) -> int:
	if m.u32(0xa55c94) & 0x7f00 == 0:
		return int(f57e880(effect, target) != 0 and f57eac0(effect, target) != 0)
	var i := 0
	while i < ((m.u32(0xa55c94) >> 8) & 0x7f):
		m.set_u16(effect + 2, ((m.u8(0xa55c96 + i) & 0x3f) << 6) | (m.u16(effect + 2) & 0xf03f))
		m.copy(effect + 16, 0xa55ca8 + i * 4, 4)
		if f57e880(effect, target) != 0 and f57eac0(effect, target) != 0:
			return 1
		i += 1
	return 0


func f57e490(effect: int, target: int) -> int:
	if (m.u8(JoeyMem.MODE) ^ m.u8(effect + 2)) & 1 == 0:
		f45e240(4)
	if m.u16(effect) == 0:
		return 0
	var bits := (m.u16(effect + 2) & 0xdfff) | 0x1000
	m.set_u16(effect + 2, bits)
	if m.u8(JoeyMem.zone(bits & 1, (bits >> 1) & 0x1f) + 6) & 2 == 0 or f568030(m.u16(effect)) == 0:
		return 0
	if m.u8(effect + 3) & 0x40 and f568310(m.u16(effect)) == 0:
		return 0
	if f402690(m.u16(effect)) == 0:
		if m.u8(effect + 2) & 0x3e < 10:
			return 0
		if f5709d0(0, 0x520) != 0 and (((m.u16(effect + 2) >> 14) & 1) ^ (m.u16(effect + 2) & 1)) == m.u8(JoeyMem.MODE) & 1:
			f45e240(0x14)
	elif m.u8(effect + 2) & 0x3e > 9:
		return 0
	return _jy_windows(effect, target)


func f57e650(effect: int, target: int) -> int:
	if m.u16(effect) == 0:
		return 0
	if (m.u8(effect + 2) ^ m.u8(JoeyMem.MODE)) & 1 == 0:
		f45e240(4)
	m.set_u16(effect + 2, m.u16(effect + 2) & 0xcfff)
	var bits := m.u16(effect + 2)
	if bits & 0x4000:
		return 0
	if bits & 0x3e == 0x16:
		if f402690(m.u16(effect)) == 0:
			if f56a430(bits & 1, m.u16(effect)) == 0 or (bits ^ m.u8(JoeyMem.TURN)) & 1:
				return 0
			if s16(f4025d0(m.u16(effect))) != 0x16 or f5699c0(0x49c) != 0:
				return 0
		elif f5682d0(m.u16(effect)) == 0:
			return 0
	else:
		if f402690(m.u16(effect)) != 0 or bits & 0x3e < 10:
			return 0
		var flags := m.u16(JoeyMem.zone(bits & 1, (bits >> 1) & 0x1f) + 6)
		if flags & 2 or flags & 0x400 == 0:
			return 0
	if f402690(m.u16(effect)) == 0 and f5709d0(0, 0x520) != 0 and (((m.u16(effect + 2) >> 14) & 1) ^ (m.u16(effect + 2) & 1)) == m.u8(JoeyMem.MODE) & 1:
		f45e240(0x14)
	return _jy_windows(effect, target)


func f57e880(effect: int, target: int) -> int:
	var bits := m.u16(effect + 2)
	var p := ((bits >> 14) & 1) ^ (bits & 1)
	if target == 0:
		if _s32(f57e0c0(m.u16(effect))) < 2:
			var valid := false
			if bits & 0xfc0 == 0 or (f402690(m.u16(effect)) != 0 and m.u8(effect + 2) & 0x3e != 0x16):
				var id := f4022e0(m.u16(effect)) & 0xffff
				valid = id in [0x428, 0x1a0, 0x243, 0x489]
				valid = valid or (m.u8(JoeyMem.TURN) & 1 == p and m.u32(JoeyMem.TURN) & 0xe in [4, 8])
			if not valid:
				if p == m.u32(JoeyMem.MODE) & 1:
					f45e240(0x16)
				return 0
	else:
		if _s32(f57e0c0(m.u16(effect))) < _s32(f57e0c0(m.u16(target))) or _s32(f57e0c0(m.u16(effect))) < 2:
			return 0
		if f57ea00(bits & 1, (bits >> 1) & 0x1f) != 0:
			return 0
	if m.u32(0xa577ec) & 1 and f5683f0(m.u16(effect), (m.u16(effect + 2) & 0xfc0) >> 6) == 0:
		if p == m.u32(JoeyMem.MODE) & 1:
			f45e240(0x15)
		return 0
	return 1


func f59de30(effect: int, target: int) -> int:
	var row := _s32(f59dbe0(m.u16(effect)))
	if row < 0:
		return 1
	var address := m.u32(0x5ed0b8 + row * 24)
	return 1 if address == 0 else _jy_effect(address, [effect, target])


func f59de70(effect: int, target: int) -> int:
	var row := _s32(f59dbe0(m.u16(effect)))
	if row < 0:
		return 1
	var address := m.u32(0x5ed0bc + row * 24)
	return 1 if address == 0 else _jy_effect(address, [effect, target])


func f59deb0(effect: int, target: int) -> int:
	var row := _s32(f59dbe0(m.u16(effect)))
	if row < 0:
		return 0
	var address := m.u32(0x5ed0ac + row * 24)
	return 0 if address == 0 else _jy_effect(address, [effect, target]) & 0xffff


## Puentes de presentacion: conservan las escrituras de reglas; el texto y las ventanas
## son eventos. El controlador sin pantalla aporta las mismas elecciones que la interfaz.
var phase_choice := 0


func f481a10() -> int:
	return _frontier(0x481a10, [], phase_choice)


func f5bf800(text: int) -> int:
	m.set_u16(0xa558b4, 0)
	m.set_u32(0xa53770, 0)
	m.set_u8(0xa53774, 1)
	return _frontier(0x5bf800, [text], 0)


func f5bf9a0(kind: int, argument: int) -> int:
	m.set_u32(0xa53770, kind)
	m.set_u32(0xa53758, argument)
	return _frontier(0x5bf9a0, [kind, argument], 0)


func f5bf9c0() -> int:
	return _frontier(0x5bf9c0, [], 0)


## Coincidencia de carta en las colas de activacion/resolucion (20bytes por entrada).
func f57ea00(p: int, z: int) -> int:
	var spell_zone := _s32(z) >= 5 and _s32(z) <= 10
	for pair in [[0xa55c80, 0xa55b42], [0xa55c84, 0xa558c2]]:
		for i in range(m.u16(pair[0])):
			var bits := m.u16(pair[1] + i * 20)
			if (bits & 1) == p and (bits >> 1 & 31) == z and (not spell_zone or (bits & 0x3000) == 0):
				return 1
	return 0


## Cabecera u16 seguida de la carga; el transporte 443e40 pertenece a la red.
func f5bd090(op: int, source: int, count: int) -> int:
	var packet := m.local(256)
	m.set_u16(packet, op)
	if _s32(count) > 0:
		m.copy(packet + 2, source, count)
	f5bd0f0(op & 0xffff, 1)
	f443e40(packet, (count + 2) & 0xffffffff)
	return 0


## Contador de ACK de cuatro bits: solo cambia a58260[21:24], con desbordamiento.
func f5bd0f0(op: int, sent: int) -> int:
	if op in [0xf002, 0xf003, 0xf041, 0xf042, 0xf051, 0xf052, 0xf053,
			0xf054, 0xf055, 0xf056, 0xf05a, 0xf05b, 0xf071, 0xf073,
			0xf081, 0xf082, 0xf091, 0xf092, 0xf0a1, 0xf0a2]:
		var state := m.u32(0xa58260)
		var signed_counter := _s32((state & 0xffe00000) << 7) >> 7
		var delta := 0x200000 if sent != 0 else -0x200000
		m.set_u32(0xa58260, state ^ ((signed_counter + delta ^ state) & 0x1e00000))
	return 0


## Resultado del duelo en el estado de la aplicacion (44b9e0 -> 44baf0).
## No persiste archivos: registra tambien la diferencia de victorias de un match.
func f44b9e0(result: int) -> int:
	return f44baf0(result)


func f44baf0(result: int) -> int:
	var kind := m.u32(0x5f3294)
	if kind not in [0, 1, 3]:
		return 0
	m.set_u8(0x5f3257 + m.u8(0x5f325b), result)
	if kind != 1:
		m.set_u32(0x5f3254, result)
		return 0
	var count := m.u8(0x5f325b)
	var wins := [0, 0, 0, 0]
	for i in range(count):
		wins[m.u8(0x5f3258 + i) & 3] += 1
	var lead: int = wins[1] - wins[2]
	if lead == 2 or (count == 3 and lead == 1):
		m.set_u32(0x5f3254, 1)
	elif lead == -2 or (count == 3 and lead == -1):
		m.set_u32(0x5f3254, 2)
	elif count == 3 and lead == 0:
		m.set_u32(0x5f3254, 3)
	return 0


## Wrappers de5b9470 que el decompilado fusiona con otras ramas: ASM5b9570..5b95cc.
func _c5b9470_2a() -> int:
	return f408470(1)


func _c5b9470_2b() -> int:
	return f408470(0)


func _c5b9470_2d() -> int:
	return f404920(0)


func _c5b9470_2e() -> int:
	return f404920(1)


func _c5b9470_2f() -> int:
	return f404920(2)


func _c5b9470_30() -> int:
	return f404920(3)


func _c5b9470_31() -> int:
	return f404920(4)


func _c5b9470_32() -> int:
	return f404920(5)
