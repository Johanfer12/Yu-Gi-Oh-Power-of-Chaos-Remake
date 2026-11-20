class_name JoeyPortU
extends JoeyPortT
## Etapa 4, bloque X: acciones, selectores e invocaciones.
## Fuente: re/out/joey/funcs/005aa180.c..005adec0.c; argumentos de pila cotejados en ASM.

const _JU_ACTION := 0xa55080
const _JU_FLAGS := 0xa5508e


func _ju_next() -> void:
	var v := m.u16(_JU_FLAGS)
	m.set_u16(_JU_FLAGS, v ^ (((v & 0xffe0) + 0x20 ^ v) & 0xfe0))


func _ju_step() -> int:
	return (m.u16(_JU_FLAGS) >> 5) & 0x7f


func _ju_at() -> int:
	var a := m.u32(_JU_ACTION)
	return JoeyMem.zone(a & 1, (a >> 1) & 0x1f)


func _ju_ref(with_face: bool = false) -> int:
	var a := m.u32(_JU_ACTION)
	var e := m.u32(_ju_at())
	var ref := ((a & 1) << 8) | (((a >> 1) & 0xf) << 9) | JoeyMem.ident(e)
	if with_face:
		ref |= (m.u8(_ju_at() + 6) & 3) << 13
	else:
		ref |= ((a >> 15) & 1) << 13
	return ref & 0xffff


func _ju_tribute(packed: int) -> int:
	var b := (packed >> 8) & 0xff
	var c := (packed >> 16) & 0xff
	return ((((((((c & 0x10) << 1 | b & 0x10) << 1 | packed & 0x10) << 2 | c & 7) << 2 | c & 0x80) << 1 | b & 0x87) << 1 | packed & 0x80) << 2 | packed & 7) << 16


func _ju_pay_tributes() -> void:
	for i in range(3):
		var a := m.u32(_JU_ACTION)
		if a & (0x2000000 << i):
			f5b9170(((a >> (28 + i)) << 15) | 0x57, (a >> (16 + i * 3)) & 7, 0, 0)
	for i in range(3):
		var a := m.u32(_JU_ACTION)
		if a & (0x2000000 << i):
			f577b30((a >> (28 + i)) & 1, (a >> (16 + i * 3)) & 7)


func f5aa180(p: int, kind: int, z: int, mask: int) -> int:
	var at := JoeyMem.zone(p, kind + z)
	var card_kind := f4025d0(m.u16(at) & 0xfff) if kind < 10 else mask
	var shift := 16 if p == ((~m.u8(JoeyMem.MODE)) & 1) else 0
	match kind:
		0:
			if mask & (0xf0 << shift) and m.u32(at) & 0xfff:
				var flags := m.u8(at + 6)
				var face := (mask & (0x20 << shift) != 0 and flags & 2 != 0) or (mask & (0x10 << shift) != 0 and flags & 2 == 0)
				var pos := (mask & (0x80 << shift) != 0 and flags & 1 != 0) or (mask & (0x40 << shift) != 0 and flags & 1 == 0)
				return int(face and pos)
		5:
			var selected := mask & (0xe << shift)
			if selected and m.u32(at) & 0xfff:
				if m.u8(at + 6) & 2 == 0:
					return int(mask & (2 << shift) != 0)
				if selected != ((2 << shift) & 0xffff):
					return int(mask & ((8 if card_kind == 0x15 else 4) << shift) != 0)
		10:
			at = JoeyMem.zone(p, 10)
			if m.u32(at) & 0xfff:
				return int(mask & ((4 if m.u16(at + 6) & 2 else 2) << shift) != 0)
		11:
			return int(mask & (1 << shift) != 0 and z < m.u8(JoeyMem.pl(p) + 8))
	return 0


func f5aa440(mask: int) -> int:
	if f5beed0():
		return f5aa180(m.u32(0xa55044), _s32(m.u32(0xa55048)), _s32(m.u32(0xa5504c)), mask)
	return 0


func f5aa480() -> int:
	f4182d0()
	return m.u32(0xa54e54) & 0x201


func f5aa490() -> int:
	var p := m.u32(0xa55044)
	var kind := _s32(m.u32(0xa55048))
	var z := _s32(m.u32(0xa5504c))
	var keys := m.u32(0xa54e54)
	if f5bee70():
		p = m.u32(0xa55050)
		kind = _s32(m.u32(0xa55054))
		z = _s32(m.u32(0xa55058))
	var other := p == ((~m.u8(JoeyMem.MODE)) & 1)
	m.set_u32(0xa55040, m.u32(0xa55040) | 1)
	if f44b980() == 0:
		for i in range(4):
			if keys & (0x10000 << i):
				var dest: int = [13, 14, 12, 15][i]
				f5bdbd0(p ^ int(kind == dest), dest, 0)
				return 0
	elif f48dd20(0) == 0 and keys & 0xfff0000:
		var i := 0
		while keys & (0x10000 << i) == 0:
			i += 1
		if f479b30():
			i += 12
		f48dd00(0, f402560(i + 0x9c4))
		var local := m.local(2)
		m.set_u16(local, i)
		f5bd090(0xf006, local, 2)
	var direction := -1
	if keys & 0x20:
		direction = 1 if other else 0
	elif keys & 0x10:
		direction = 0 if other else 1
	elif keys & 0x40:
		direction = 3 if other else 2
	elif keys & 0x80:
		direction = 2 if other else 3
	if direction < 0 or kind not in [0, 5, 10, 11, 12, 13, 14, 15]:
		return 0
	if direction < 2:
		if kind == 11:
			var count := m.u8(JoeyMem.pl(p) + 8)
			if count == 0:
				return 0
			z = (z + 1 if z < count - 1 else 0) if direction == 1 else (z - 1 if z > 0 else count - 1)
		elif kind in [0, 5]:
			if direction == 1:
				if z < 4:
					z += 1
				else:
					kind = 14 if kind == 0 else 13
					z = 0
			elif z > 0:
				z -= 1
			else:
				kind = 10 if kind == 0 else 12
				z = 0
		elif direction == 1:
			kind = {10: 0, 12: 5, 13: 12, 14: 10, 15: 10}[kind]
			z = 0
		else:
			kind = {10: 14, 12: 13, 13: 5, 14: 0, 15: 0}[kind]
			z = 4 if kind in [0, 5] else 0
	elif direction == 3:
		if kind == 11:
			z = f5bf300(p, 11, z, 1 - p, 11)
			p = 1 - p
		elif kind in [5, 12, 13]:
				z = f5bf300(p, kind, z, p, 11)
				kind = 11
		else:
			kind = {0: 5, 10: 12, 14: 13, 15: 14}[kind]
			if kind != 5:
				z = 0
	else:
		if kind == 0:
			p = 1 - p
			z = 4 - z
		elif kind == 5:
			kind = 0
		elif kind == 11:
			z = f5bf300(p, 11, z, p, 5)
			kind = 5
		elif kind in [10, 15]:
			p = 1 - p
			kind = 15 if kind == 10 else 10
			z = 0
		else:
			kind = {12: 10, 13: 14, 14: 15}[kind]
			z = 0
	f5bdbd0(p, kind, z)
	f44ef40(0)
	return 0


func f5aab30(p: int, mode: int) -> int:
	if _s32(f56a030(p)) >= 0:
		return 1
	for z in range(5):
		if (f56a0d0(p, p, z) if mode == 0 else f56a140(p, p, z)) and f569e10(p, z):
			return 1
	return 0


func _ju_error(p: int, code: int, value: int = 0) -> int:
	if p == m.u32(JoeyMem.MODE) & 1:
		f45e240(code)
	return value


func f5aab90(p: int, card: int) -> int:
	if card & 0xffff == 0 or f402690(card) == 0:
		return 0
	if f56b440(card & 0xffff, 0xffffffff):
		return _ju_error(p, 0x10)
	if f570a10(p, card & 0xffff) == 0:
		return _ju_error(p, 0x17)
	if f567a00(card):
		return 0
	var normal := 1
	var settable := 0x10
	if f570a70(p) == 0:
		if f5699c0(0x47f):
			settable = 0
		normal = 0
		_ju_error(p, 0x11)
	var result := 0
	if s16(f4022e0(card)) == 0x4e2 and m.u8(JoeyMem.pl(p) + 8) == 1 and f56a000(p):
		result = normal
	var level := f4026c0(card) & 0xffff
	if level <= 4:
		if f56a000(p) == 0:
			return _ju_error(p, 0xb, result)
	else:
		if _s32(f56a200(p, 0xffffffff)) < (1 if level <= 6 else 2):
			return _ju_error(p, 0, result)
		if f5aab30(p, 0) == 0:
			return _ju_error(p, 0xb, result)
	return result | settable | normal


func f5aae00(p: int, card: int) -> int:
	if card & 0xffff == 0 or f402690(card) == 0:
		return 0
	var id := f4022e0(card) & 0xffff
	if id != 0x17a and f56b440(card & 0xffff, 0xffffffff):
		return _ju_error(p, 0x10)
	if f570a10(p, card & 0xffff) == 0:
		return _ju_error(p, 0x17)
	if f570b40(p) == 0:
		return _ju_error(p, 0x11)
	var ok := 0
	match id:
		0x37, 0x38, 0x42: ok = f5ab1a0(p, card & 0xffff)
		0x175: ok = f5ab280(p)
		0x17a: ok = int(f56a000(p) != 0 and f5699c0(0x4db) != 0)
		0x2d6, 0x2d7, 0x2d8, 0x2fe:
			if f569cb0(p):
				var level := f4026c0(card) & 0xffff
				if level <= 4:
					ok = f56a000(p)
				else:
					if _s32(f56a290(p, 0xffffffff)) < (1 if level <= 6 else 2):
						return _ju_error(p, 0)
					ok = f5aab30(p, 1)
				if ok == 0:
					return _ju_error(p, 0xb)
		0x34d: ok = f5ab3f0(p)
		0x4e9: ok = f5ab580(p)
		0x546:
			if f56a000(p):
				ok = int(_s32(f569d50(1 - p)) > _s32(f569d50(p)) + 1)
		0x5ea, 0x5eb, 0x5ec, 0x5ed, 0x5ee, 0x5ef: ok = f5ab640(p, card)
		0x5f0: ok = f56a000(p)
	return 0xc00 if ok else 0


func f5ab1a0(p: int, card: int) -> int:
	var local := m.local(20)
	m.set_u16(local, card)
	m.set_u32(local + 2, (p & 1) | 0x16)
	for z in range(5):
		if f579a00(local, (z << 8) | (p & 0xff)):
			if f56a000(p) or f569e10(p, z):
				return 1
	if f56a000(p):
		for z in range(5):
			if f579a00(local, (z << 8) | ((1 - p) & 0xff)):
				return 1
	return 0


func _ju_parts(p: int, ids: Array, grave: bool) -> int:
	var available := f56a000(p)
	if _s32(f5699c0(0x58a)) > 0:
		return 0
	for id: int in ids:
		var index := f402460(id) & 0xffff
		var found := false
		for z in range(5):
			if m.u32(JoeyMem.zone(p, z)) & 0xfff == index and f56a140(p, p, z):
				found = true
				if f569e10(p, z):
					available += 1
		for z in range(5):
			var at := JoeyMem.zone(1 - p, z)
			if m.u32(at) & 0xfff == index and f56a140(p, 1 - p, z) and m.u8(at + 6) & 2:
				found = true
				break
		if grave:
			if f56d2c0(p, id) == 0 and not found:
				return 0
		elif not found:
			return 0
	return int(available != 0)


func f5ab280(p: int) -> int:
	return _ju_parts(p, [0x172, 0x173, 0x174], false)


func f5ab3f0(p: int) -> int:
	return _ju_parts(p, [0x2e1, 0x2f4, 800], true)


func f5ab580(p: int) -> int:
	if _s32(f5699c0(0x58a)) < 1 and _s32(f56a290(p, 0xffffffff)) > 1:
		for q in range(2):
			for z in range(5):
				if f56a140(p, p ^ q, z) and s16(f4022e0(m.u16(JoeyMem.zone(p ^ q, z)) & 0xfff)) in [0x582, 0x584]:
					return 1
	return 0


func f5ab640(p: int, card: int) -> int:
	var field := f5709d0(p, 0x60f)
	if f570b40(p) == 0 or f570bb0(p) == 0:
		return 0
	if f56a000(p) == 0 and field == 0:
		return 0
	var id := s16(f4022e0(card))
	var need := 3 if id == 0x5ea else (2 if id == 0x5eb else 1)
	if field:
		for z in range(5):
			if m.u32(JoeyMem.zone(p, z)) & 0xfff:
				var same := s16(f56f6d0(p, z)) == 3 if id == 0x5ea else s16(f56f9e0(p, z)) == s16(f402650(card))
				if same:
					need -= 1
					if need == 0:
						return 1
		return 0
	return int(need <= _s32(f599e30(p, f4022e0(card), 0)))


func f5ab7a0(card: int) -> int:
	return int((f4022e0(card) & 0xffff) in [0x37, 0x38, 0x42, 0x175, 0x2d6, 0x2d7, 0x2d8, 0x2fe, 0x34d, 0x4b2, 0x4e9, 0x546, 0x5ea, 0x5eb, 0x5ec, 0x5ed, 0x5ee, 0x5ef, 0x5f0])


func f5ab820() -> int:
	if m.u16(_JU_FLAGS) & 1 == 0:
		return 0
	var a := m.u32(_JU_ACTION)
	if m.u16(_JU_FLAGS) & 2 == 0 or m.u32(JoeyMem.MODE) & 1 == a & 1:
		var action := (m.u8(_JU_FLAGS) >> 2) & 7
		var done := 1
		match action:
			1: done = f5abd00()
			2: done = f5ac870()
			3: done = f5ac990()
			4: done = f5acf10()
			5: done = f5ad210()
			6: done = f5ad350()
		if done == 0:
			return 1
	elif m.u8(0xa58260) & 0x40 == 0:
		return 1
	m.set_u16(_JU_FLAGS, m.u16(_JU_FLAGS) & 0xfffe)
	a = m.u32(_JU_ACTION)
	var at := _ju_at()
	var entry := m.u32(at)
	if entry & 0xfff:
		var face := m.u8(at + 6) & 2
		var card := entry & 0xfff
		var ref := _ju_ref() | (((a >> 14) & 1) << 14)
		var action := (m.u8(_JU_FLAGS) >> 2) & 7
		var event := 7
		if action in [1, 2]:
			event = 5 if a & 0x4000 else 8
		elif action == 3:
			event = 7 if f5675f0(card) else 6
		if m.u8(0xa5508c) & 0x20:
			var owner := (entry >> 12) & 1
			for z in range(5, 10):
				var e := m.u32(JoeyMem.zone(owner, z))
				if s16(f4022e0(e & 0xfff)) == 0x595:
					if m.u8(0xa55c94) == 0:
						f5ba490(((((event & 0x3f) | (owner << 6)) << 9 | z | 0x20) << 16) | (e & 0xfff), JoeyMem.ident(e), ref)
					else:
						f5b9170(_jq_op(owner, 0x88), z, 1, 0)
		if face:
			if f56c460(a & 1, (a >> 1) & 0x1f) == 0 and f5699c0(0x610):
				f5b9170((a << 15) | 0x1e, 0x610, 1, 0)
				f579990(a & 1, (a >> 1) & 0x1f, 0x12, 1)
			if f56b440(card, JoeyMem.ident(m.u32(_ju_at()))) == 0:
				match f4022e0(card) & 0xffff:
					0x2d6, 0x2d7, 0x2d8, 0x2fe:
						f579990(a & 1, (a >> 1) & 0x1f, 0x12, 1)
					0x2ef:
						f578390(a & 1, f402460(0x2ef), (a >> 1) & 0x1f)
						f59ccf0()
		f598590(m.u16(JoeyMem.TURN) & 1, event, ref)
	if m.u16(_JU_FLAGS) & 2 and m.u32(JoeyMem.MODE) & 1 == m.u32(_JU_ACTION) & 1:
		f5bd050(0xf05b, 0, 0, 0)
	return m.u8(_JU_FLAGS) & 1


func f5abd00() -> int:
	var a := m.u32(_JU_ACTION)
	var phase := _ju_step()
	if phase == 0:
		m.set_u16(_JU_FLAGS, (m.u16(_JU_FLAGS) & 0xf03f) | 0x20)
		phase = 1
	match phase:
		1:
			if a & 0x4000:
				f5b9170((a << 15) | 0xe6, f4022e0(m.u16(0xa55084)), 0, ((a >> 26) & 1) + ((a >> 25) & 1))
			_ju_pay_tributes()
			a = m.u32(_JU_ACTION)
			f5b9170((a << 15) | 0xce, f4022e0(m.u16(0xa55084)), (((a >> 1) & 0x1f) << 8) | ((a >> 6) & 0xff), (((a >> 15) & 1) << 8) | ((a >> 14) & 1))
			_ju_next()
			return 0
		2:
			if a & 0x4000:
				f5b9170((a << 15) | 0x6f, f4022e0(m.u16(0xa55084)), (a >> 1) & 0x1f, 0)
				m.set_u16(_JU_FLAGS, (m.u16(_JU_FLAGS) & 0xf07f) | 0x60)
			else:
				m.set_u16(_JU_FLAGS, (m.u16(_JU_FLAGS) & 0xf15f) | 0x140)
			return 0
		3, 4, 5, 6, 7:
			return f5ac310(0x20)
		8:
			if m.u32(_ju_at()) & 0xfff == 0:
				return 1
			f5b9170((a << 15) | 0x92, (a >> 1) & 0x1f, m.u16(0xa5508c) | (m.u32(_ju_at()) & 0xffff0000), 0)
			f59cb10(a & 1, (a >> 1) & 0x1f)
			a = m.u32(_JU_ACTION)
			var card := m.u16(0xa55084)
			if a & 0x4000 and f56b440(card, JoeyMem.ident(m.u32(_ju_at()))) == 0:
				var ref := _ju_ref()
				var id := f4022e0(card) & 0xffff
				if id in [0x1f3, 0x267, 0x455, 0x462, 0x4d8, 0x4de, 0x534]:
					f5ba490((((a & 0x3e) | (a << 16) | 0x1440) << 15) | card, JoeyMem.ident(m.u32(_ju_at())), ref)
				elif id == 0x31c and a & 0x8000 == 0:
					f575190(a & 1, (a >> 1) & 0x1f, 0, 0, 0)
				elif id in [0x45e, 0x585]:
					f578390(a & 1, card, (a >> 1) & 0x1f)
					f577840(a & 1, (a >> 1) & 0x1f, 0, card)
			_ju_next()
			return 0
	return 1


func f5ac310(event: int) -> int:
	var ref := _ju_ref(true)
	var phase := _ju_step()
	var work := m.u32(0xa55090)
	if phase == 3:
		if m.u16(0xa55c80) > 1:
			m.set_u16(_JU_FLAGS, (m.u16(_JU_FLAGS) & 0xf11f) | 0x100)
			return 0
		if m.u32(JoeyMem.zone((ref >> 8) & 1, (ref >> 9) & 0xf)) & 0xfff == 0:
			return 1
		m.set_u16(0xa55c94, m.u16(0xa55c94) & 0x80ff)
		m.set_u16(0xa55090, (work & 0x8000) | (m.u16(JoeyMem.TURN) & 1))
		m.set_u8(0xa57822, 0)
		_ju_next()
		phase = 4
	if phase == 4:
		while m.u32(0xa55090) & 0x7f80 < 0x100:
			work = m.u32(0xa55090)
			var p := work & 0x7f
			var id := m.u16(0x5dd0a4 + (((work & 0xffff) >> 7) & 0xff) * 2)
			if f56aa50(p, id):
				var local := m.local(20)
				m.set_u16(local, f402460(id))
				var zone := f56a9e0(p, id)
				m.set_u16(local + 2, ((((event & 0x3f) << 5) | (zone & 0x1f)) << 1) | (p & 1))
				m.set_u16(local + 4, JoeyMem.ident(m.u32(JoeyMem.zone(work & 1, (zone & 0x1f)))) << 5)
				m.set_u16(local + 16, ref)
				if f57e650(local, 0):
					f5bcf40(p, id)
					_ju_next()
					return 0
			var v := m.u16(0xa55090)
			m.set_u16(0xa55090, v ^ (((v & 0xff80) + 0x80 ^ v) & 0x7f80))
		work = m.u32(0xa55090)
		var toggled := work ^ (((1 - (work & 0x7f)) ^ work) & 0x7f)
		m.set_u32(0xa55090, toggled & 0xffff807f)
		if m.u16(JoeyMem.TURN) & 1 == toggled & 0x7f:
			m.set_u16(_JU_FLAGS, (m.u16(_JU_FLAGS) & 0xf11f) | 0x100)
		return 0
	match phase:
		5:
			if m.u8(0xa57822) == 0:
				var v := m.u16(0xa55090)
				m.set_u16(0xa55090, v ^ (((v & 0xff80) + 0x80 ^ v) & 0x7f80))
				v = m.u16(_JU_FLAGS)
				m.set_u16(_JU_FLAGS, v ^ (((v & 0xffe0) - 1 ^ v) & 0xfe0))
			else:
				_ju_next()
			return 0
		6:
			var p := work & 0x7f
			var z := f56a9e0(p, m.u16(0x5dd0a4 + (((work & 0xffff) >> 7) & 0xff) * 2))
			f5b9170(_jq_op(p, 0x91), z, 0, 0)
			var e := m.u32(JoeyMem.zone(work & 1, z))
			f5ba490(((((p << 6) | (event & 0x3f)) << 9) | (z & 0x1f)) << 16 | (e & 0xfff), JoeyMem.ident(e), ref)
			_ju_next()
			return 0
		7:
			if f5bbe40() == 0:
				m.set_u16(_JU_FLAGS, (m.u16(_JU_FLAGS) & 0xf11f) | 0x100)
			return 0
	return 1


func _ju_position_prompt() -> void:
	var a := m.u32(_JU_ACTION)
	if ((m.u32(JoeyMem.MODE) >> 1) >> (a & 1)) & 1:
		m.set_u16(0xa558b4, f5ae270(a & 1, m.u16(0xa55084), (a >> 14) & 1, 0))
	else:
		f5bf800(0xf7)
		f5bf9a0(6, (f4022e0(m.u16(0xa55084)) & 0xffff) | (((~a >> 14) & 1) << 16))
	_ju_next()


func _ju_position_answer() -> void:
	var a := m.u32(_JU_ACTION)
	a = (a & 0xffff7fff) | ((m.u8(0xa558b4) & 1) << 15)
	if m.u16(0xa558b4) & 1 == 0:
		a |= 0x4000
	m.set_u32(_JU_ACTION, a)


func f5ac870() -> int:
	var phase := _ju_step()
	if phase == 0:
		_ju_position_prompt()
		return 0
	if phase == 1:
		_ju_position_answer()
	return f5abd00()


func f5ac990() -> int:
	var a := m.u32(_JU_ACTION)
	var card := m.u16(0xa55084)
	match _ju_step():
		0:
			f5b9170((a << 15) | 0xe6, f4022e0(card), 0, 3)
			if m.u8(_ju_at() + 6) & 1:
				f5b9170((a << 15) | 0x7f, (a >> 1) & 0x1f, 1, 1)
				m.set_u16(0xa55092, (m.u16(0xa55092) & 0xff01) | 1)
			else:
				f5b9170((a << 15) | 0x80, (a >> 1) & 0x1f, 1, 2)
				m.set_u16(0xa55092, m.u16(0xa55092) & 0xff00)
		1:
			var effect := f5675f0(card)
			f5b9170((a << 15) | 0x6f, f4022e0(card), (a >> 1) & 0x1f, int(effect != 0) + 1)
		2:
			if f4026c0(card) & 0xffff < 3 and _s32(f5699c0(0x2ae)) > 0:
				f5b9170((a << 15) | 0x1e, 0x2ae, 1, 0)
				var count := f5699a0(1 - (a & 1), 0x2ae)
				f577840(a & 1, (a >> 1) & 0x1f, int(_s32(count) > 0), card)
				return 1
		3, 4, 5, 6, 7:
			return f5ac310(0x21)
		8:
			if m.u32(_ju_at()) & 0xfff == 0:
				return 1
			f5b9170((a << 15) | 0x92, (a >> 1) & 0x1f, m.u16(0xa5508c), 0)
			f579990(a & 1, (a >> 1) & 0x1f, 0x11, 1)
			f59cb10(a & 1, (a >> 1) & 0x1f)
			var ref := _ju_ref()
			var id := f4022e0(card) & 0xffff
			if id in [0x1f3, 0x267, 0x455, 0x462, 0x4d8, 0x4de, 0x534] or (id == 0x5e and m.u8(0xa55092)):
				f5ba490((((a & 0x3e) | (a << 16) | 0x1840) << 15) | card, ref & 0xff, ref)
			elif id == 0x31c and a & 0x8000 == 0:
				f575190(a & 1, (a >> 1) & 0x1f, 0, 0, 0)
			if f567620(card, 0):
				var packed := (((a & 0x3e) | (a << 16) | 0x1840) << 15) | card
				if f57ee80(packed, ref & 0xff, ref):
					f5b9170((a << 15) | 0xad, f4022e0(card), 0, 0)
					f5ba490(packed, ref & 0xff, ref)
			_ju_next()
			return 0
		_:
			return 1
	_ju_next()
	return 0


func _ju_relocate_command() -> void:
	var a := m.u32(_JU_ACTION)
	f5b9170(0x70, (((a >> 1) & 0x1f) << 8) | (a & 1), JoeyMem.ident(m.u32(0xa55088)), (((a >> 15) & 1) << 8) | ((a >> 14) & 1))


func _ju_relocate_finish() -> int:
	var a := m.u32(_JU_ACTION)
	if m.u32(_ju_at()) & 0xfff == 0:
		return 1
	f5b9170((a << 15) | 0x92, (a >> 1) & 0x1f, (m.u32(_ju_at()) & 0xffff0000) | m.u16(0xa5508c), 0)
	if a & 0x4000:
		var ref := _ju_ref()
		if s16(f4022e0(m.u16(0xa55084))) in [0x4de, 0x5f6]:
			f5ba490((((a & 0x3e) | (a << 16) | 0x1c40) << 15) | m.u16(0xa55084), ref & 0xff, ref)
	_ju_next()
	return 0


func f5acf10() -> int:
	var a := m.u32(_JU_ACTION)
	var phase := _ju_step()
	if phase == 0:
		m.set_u16(_JU_FLAGS, (m.u16(_JU_FLAGS) & 0xf05f) | 0x40)
		phase = 2
	match phase:
		2:
			if a & 0x4000:
				f5b9170((a << 15) | 0xe6, f4022e0(m.u16(0xa55084)), 0, 4)
			_ju_next()
			return 0
		3:
			var id := f4022e0(m.u16(0xa55084)) & 0xffff
			if id >= 0x780 and (f4022e0(m.u16(0xa55084)) & 0xffff) < 0x784:
				f5b9170((a << 15) | 0xa5, (((((a >> 15) & 1) | (((a >> 1) & 0xff) << 3)) << 1 | ((a >> 14) & 1)) & 0xff) << 8, m.u16(0xa55088), m.u16(0xa5508a))
			else:
				_ju_relocate_command()
			_ju_next()
			return 0
		4:
			return _ju_relocate_finish()
	return 1


func f5ad210() -> int:
	var phase := _ju_step()
	if phase == 0:
		_ju_position_prompt()
		return 0
	if phase == 1:
		_ju_position_answer()
		_ju_next()
	return f5acf10()


func f5ad350() -> int:
	var a := m.u32(_JU_ACTION)
	match _ju_step():
		0:
			if a & 0x4000:
				f5b9170((a << 15) | 0xe6, f4022e0(m.u16(0xa55084)), 0, 5)
			_ju_pay_tributes()
			_ju_next()
			return 0
		1:
			_ju_relocate_command()
			if f5ab7a0(m.u16(0xa55084)) == 0:
				m.set_u16(_JU_FLAGS, (m.u16(_JU_FLAGS) & 0xf11f) | 0x100)
			else:
				m.set_u16(_JU_FLAGS, (m.u16(_JU_FLAGS) & 0xf07f) | 0x60)
			return 0
		3, 4, 5, 6, 7:
			return f5ac310(0x22)
		8:
			return _ju_relocate_finish()
	return 1


func f5ad710() -> int:
	m.set_u16(0xa55090, m.u16(0xa55090) & 0x8000)
	m.set_u16(0xa55092, m.u16(0xa55092) & 0xff00)
	m.set_u16(_JU_FLAGS, (m.u16(_JU_FLAGS) & 0xf01f) | 3)
	return 0


func f5ad740(p: int, hand: int, dest: int, tributes: int, face: int) -> int:
	if _s32(dest) < 0:
		return 0
	var a := (((hand & 0xff) << 5) | (dest & 0x1f)) << 1
	var old := (m.u32(_JU_ACTION) & 0xffffc000) ^ (p & 1)
	a |= (old & 0xffffbfff) | 0x8000 if face == 0 else (old & 0xffff7fff) | 0x4000
	if f5699c0(0x47f):
		a |= 0x4000
	a = (a & 0xf1ffffff) if tributes == 0 else (_ju_tribute(tributes) | (a & 0x8000ffff))
	m.set_u32(_JU_ACTION, a)
	m.set_u16(0xa5508c, 2)
	m.set_u16(_JU_FLAGS, (m.u16(_JU_FLAGS) & 0xffe7) | 4)
	m.set_u16(0xa55084, m.u32(0xa56434 + hand * 4 + (p & 1) * 0xd44) & 0xfff)
	f59d040(p)
	f5ad8c0()
	return 0


func f5ad8c0() -> int:
	m.set_u16(0xa55090, m.u16(0xa55090) & 0x8000)
	m.set_u16(0xa55092, m.u16(0xa55092) & 0xff00)
	m.set_u16(_JU_FLAGS, (m.u16(_JU_FLAGS) & 0xf01d) | 1)
	var a := m.u32(_JU_ACTION)
	if a & 0x4000 or m.u8(0xa5508c) & 4:
		f579930(a & 1, 0x10, 1)
	if m.u16(JoeyMem.TURN) & 0x10 and (~m.u8(JoeyMem.MODE)) & 1 == a & 1:
		m.set_u16(_JU_FLAGS, m.u16(_JU_FLAGS) | 2)
		f5bd090(0xf05a, _JU_ACTION, 0x14)
		m.set_u32(0xa58260, m.u32(0xa58260) & 0xffffffbf)
	return 0


func f5ad960(p: int, z: int) -> int:
	p &= 1
	m.set_u16(0xa5508c, 2)
	m.set_u32(_JU_ACTION, ((((0x100 | (z & 0xff)) << 5) | (z & 0x1f)) << 1) | ((m.u32(_JU_ACTION) & 0xf1ff4000) ^ p))
	m.set_u16(0xa55084, m.u32(JoeyMem.zone(p, z)) & 0xfff)
	m.set_u16(_JU_FLAGS, (m.u16(_JU_FLAGS) & 0xffef) | 0xc)
	if f5675f0(m.u16(JoeyMem.zone(p, z)) & 0xfff):
		m.set_u16(0xa5508c, 4)
	f5ad8c0()
	return 0


func f5ada20(p: int, src: int, face: int, defense: int, flags: int, kind: int, z: int) -> int:
	var dest := _s32(f56a030(p))
	if dest >= 0:
		if _s32(kind) == -1:
			kind = 0
			dest = z
		var force := f5699c0(0x47f)
		var actual := 1 if force else face
		m.set_u32(_JU_ACTION, ((((z * 0x10 + kind) & 0xff) << 6) ^ (((m.u32(_JU_ACTION) & 0xffffff00) ^ (p & 1)) & 0xf1ff003f | ((dest & 0x1f) << 1))) | ((((defense & 1) << 1) | (actual & 1)) << 14))
		m.set_u16(0xa55084, m.u32(src) & 0xfff)
		f5675c0(0xa55088, src)
		m.set_u16(_JU_FLAGS, (m.u16(_JU_FLAGS) & 0xfff3) | 0x10)
		m.set_u16(0xa5508c, flags | 4 | (0x20 if kind == 14 else 0))
		f5ad8c0()
	return 0


func f5adb10(p: int, src: int, face: int, flags: int, kind: int, z: int) -> int:
	var dest := _s32(f56a030(p))
	if dest >= 0:
		if _s32(kind) == -1:
			kind = 0
			dest = z
		var force := f5699c0(0x47f)
		var actual := 1 if force else face
		m.set_u32(_JU_ACTION, ((((z * 0x10 + kind) & 0xff) << 6) ^ (((m.u32(_JU_ACTION) & 0xffffff00) ^ (p & 1)) & 0xf1ff003f | ((dest & 0x1f) << 1))) | ((actual & 1) << 14))
		m.set_u16(0xa55084, m.u32(src) & 0xfff)
		f5675c0(0xa55088, src)
		m.set_u16(_JU_FLAGS, (m.u16(_JU_FLAGS) & 0xfff7) | 0x14)
		m.set_u16(0xa5508c, flags | 4 | (0x20 if kind == 14 else 0))
		f5ad8c0()
	return 0


func f5adbf0(p: int, hand: int, dest: int, tributes: int, defense: int) -> int:
	if _s32(dest) < 0:
		return 0
	var packed := (((((0x200 if defense == 0 else 0) | (hand & 0xff) | 0x100) << 5) | (dest & 0x1f)) << 1)
	var a := (m.u32(_JU_ACTION) & 0xffff4000) ^ (p & 1)
	if tributes == 0:
		a = packed | (a & 0xf1ffffff)
	else:
		a = _ju_tribute(tributes) | packed | (a & 0x8000ffff)
	m.set_u32(_JU_ACTION, a)
	var src := 0xa56434 + hand * 4 + (p & 1) * 0xd44
	m.set_u16(0xa55084, m.u32(src) & 0xfff)
	f5675c0(0xa55088, src)
	m.set_u16(_JU_FLAGS, (m.u16(_JU_FLAGS) & 0xfffb) | 0x18)
	m.set_u16(0xa5508c, 5)
	f59d040(p)
	f5ad8c0()
	return 0


func f5add60(p: int, z: int, out: int) -> int:
	var at := JoeyMem.zone(p, z) + 6
	var hidden := m.u16(at) & 2 == 0
	if hidden:
		m.set_u16(at, m.u16(at) | 2)
	f56dd30(p, z, out)
	if hidden:
		m.set_u16(at, m.u16(at) & 0xfffd)
	return 0


func f5addc0(p: int, z: int, out: int) -> int:
	var at := JoeyMem.zone(p, z)
	if m.u8(at + 6) & 2 == 0:
		var stat := 1000 if (f4026c0(m.u16(at) & 0xfff) & 0xffff) <= 4 else 1900
		m.set_u32(out + 4, stat)
		m.set_u32(out + 8, stat)
		m.set_u16(out + 2, 0)
		m.set_u16(out, 0)
	else:
		f56dd30(p, z, out)
	return 0


func f5ade40(p: int, excluded: int) -> int:
	var maximum := -1
	var local := m.local(12)
	for z in range(5):
		var zone := JoeyMem.zone(p, z)
		if z == excluded or (m.u32(zone) & 0xfff) == 0 or _jc_can_attack(p, z, 1, local) == 0:
			continue
		# Solo una carta oculta necesita la estimación de la IA en lugar del ATK efectivo.
		if (m.u8(zone + JoeyMem.Z_FLAGS) & 2) == 0:
			f5addc0(p, z, local)
		maximum = maxi(maximum, _s32(m.u32(local + 4)))
	return maximum


func f5adec0(p: int, z: int) -> int:
	var at := JoeyMem.zone(p, z)
	var entry := m.u32(at)
	var id := f4022e0(entry & 0xfff) & 0xffff
	var hidden := m.u8(at + 6) & 2 == 0
	if id in [0x4db, 0x2df, 0x492] and hidden:
		return 1
	if id == 0x59e and not hidden and f569d50(1 - p) == 0 and _s32(f569d50(p)) > 1:
		return 1
	if id == 0x5e6 and hidden:
		# Campo +0x8c de los cinco monstruos, con stride de jugador 0xd44.
		var enemy := false
		for i in range(5):
			var ptr := 0xa55e00 + ((-p - 1) & 1) * 0xd44 + i * 0x90
			if m.u32(ptr - 0x8c) & 0xfff and m.u8(ptr) & 8:
				enemy = true
		if enemy:
			var own := false
			for i in range(5):
				var ptr := 0xa55e00 + (p & 1) * 0xd44 + i * 0x90
				if m.u32(ptr - 0x8c) & 0xfff and m.u8(ptr) & 8:
					own = true
			if not own:
				return 0
	if f567620(entry & 0xfff, 0xffffffff) and hidden:
		return 1
	var local := m.local(12)
	f5add60(p, z, local)
	return f5ae0a0(p, m.u32(local + 4), m.u32(local + 8))
