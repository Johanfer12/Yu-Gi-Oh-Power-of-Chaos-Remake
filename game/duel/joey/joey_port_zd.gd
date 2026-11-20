class_name JoeyPortZD
extends JoeyPortZC
## IA nativa, primera parte: 5ae0a0..5b1360. Fuentes C y ASM de Joey_Pc.exe.


func _jzd_stats(p: int, z: int, mode: int = 0) -> int:
	var out := m.local(12)
	if mode == 1:
		f5add60(p, z, out)
	elif mode == 2:
		f5addc0(p, z, out)
	else:
		f56dd30(p, z, out)
	return out


func _jzd_hand(base: int, p: int, i: int) -> int:
	return base + (p & 1) * 0xd44 + 0x6d0 + i * 4


func f40caa0(index: int) -> int:
	m.set_u16(0xa582a2, index)
	return 0


func f40cc60(index: int, value: int) -> int:
	if _s32(index) < 0x80:
		var a := 0xa584a4 + _s32(index) * 2
		m.set_u16(a, (m.u8(a) & 31) + (value & 0xffff) * 0x100)
	return 0


func f5be190(index: int) -> int:
	var id := f4022e0(index) & 0xffff
	for a in range(0x5efbcc, 0x5efc64, 4):
		if m.u16(a) == id:
			var value := m.u16(a + 2)
			return 1 if m.u8(0xa54dae) == 0 and value == 0 else value
	return 3


func f57f130(p: int, count: int, exclude: int, monster_only: int, trap_only: int) -> int:
	var block := _s32(f5699c0(0x49c))
	for i in range(m.u8(JoeyMem.pl(p) + 8)):
		var a := _jzd_hand(0xa55d64, p, i)
		var index := m.u32(a) & 0xfff
		var valid := exclude != index
		if not valid:
			exclude = 0
		valid = valid and index != 0
		if monster_only != 0 and f402690(index) == 0:
			valid = false
		if trap_only != 0 and (f4025d0(index) & 0xffff) != 0x16:
			valid = false
		if block > 0 and (f4025d0(index) & 0xffff) == 0x16:
			valid = false
		if f570be0(p, a) == 0 and valid:
			count -= 1
	return int(_s32(count) < 1)


func f5ae0a0(p: int, attack: int, defense: int) -> int:
	attack = _s32(attack)
	defense = _s32(defense)
	var other := 1 - p
	var enemy := _s32(f5ade40(other, -1))
	var own_atk := _s32(f5affd0(p, p, -1, 1, 0))
	var own_def := _s32(f5affd0(p, p, -1, 0, 1))
	if f569d50(other) == 0 and m.u16(JoeyMem.pl(other) + 4) <= _s32(f5b0330(p, p)):
		return int(attack == 0)
	if attack == 0:
		return 1
	if f5699a0(p, 0x590) != 0:
		return 0
	if enemy - attack > 999:
		return 1
	if attack < defense:
		if enemy <= attack and attack > 0x6a3:
			return 0
		if maxi(own_atk, own_def) <= defense and defense > 0x5dc:
			return 1
		if f569d90(other, 1, 0) != 0 and enemy <= attack:
			return 0
	else:
		if enemy <= attack:
			return 0
		if enemy - attack < 301 and m.u16(JoeyMem.pl(p) + 4) > 300:
			return 0
	return ((int(enemy <= attack + 300) - 1) & 2) - 1


func f5ae220(index: int) -> int:
	if f567620(index, -1) != 0:
		return 1
	return int((f4022e0(index) & 0xffff) in [0x4db, 0x2df, 0x492, 0x585])


func f5ae270(p: int, index: int, condition: int, fallback: int) -> int:
	if _s32(f5699c0(0x47f)) > 0:
		condition = 1
	var id := f4022e0(index) & 0xffff
	var special := id in [0x4de, 0x2da, 499, 15, 0x77, 0x1ff, 0x455, 0x462,
			0x4d8, 0x534, 0x4e6, 0x536, 0x59a, 0x5f5]
	if id in [0x52e, 0x531] and condition == 0 and f56b220(0x14d) != 0:
		return 0
	if condition == 0:
		if special:
			return 0
		if f5ae220(index) != 0:
			return 1
	var defense := f402800(index) & 0xffff
	var attack := f4027b0(index) & 0xffff
	var result := _s32(f5ae0a0(p, attack, defense))
	return fallback if result == -1 else result


func f5ae390(p: int) -> int:
	return int(_s32(f5699c0(0x436) * 500) < m.u16(JoeyMem.pl(p) + 4))


func f5ae3e0(p: int, mode: int, card: int) -> int:
	card &= 0xffff
	if card > 15 and card < 21:
		return 1
	if _s32(mode) > 0:
		if card in [0x3f2, 0x403, 0x405, 0x406, 0x420, 0x425, 0x42c,
				0x3f0, 0x29f, 0x2da, 0x3ba, 0x15b, 0x14f, 0x150]:
			return 1
		if card == 0x452 and _s32(f5afe90(p)) > 0:
			return 1
		if card in [0x23d, 0x2f] and mode == 1:
			return 1
	if _s32(mode) < 2:
		return 0
	match card:
		0x1ab: return int(f56a8e0(p, 0x16) == 0)
		0xdf, 0x109, 0x249: return int(f56aa50(1 - p, 0) == 0)
		0x182, 0x18c, 0x18d, 0x1a5, 0x1e7, 0x27a: return int(f5699c0(0x52b) == 0)
		0xf: return int(_s32(f5afe90(p)) > 0)
		0x39, 0x76d: return 1
		0x65: return int(f56a8e0(p, 0x15) == 0)
		0x52e, 0x531:
			if f56b220(0x14d) != 0:
				return 0
			return int(_s32(f56d2c0(p, 0x14d) + f56cbd0(p, 0x14d)) > 0)
		0x4de: return int(f569d90(1 - p, 1, 0) == 0)
		0x27, 0x246:
			var other := 1 - p
			var id := 0x148 if card == 0x27 else 0x15b
			if f5699a0(other, id) != 0:
				return 0
			return int(_s32(f56d2c0(other, id) + f56cbd0(other, id)) > 0)
	return 0


func f5ae8f0(index: int) -> int:
	return int((f4022e0(index) & 0xffff) in [0x414, 0x140, 0x136, 0x2f,
			0x12f, 0x138, 0x139, 0x23d, 0x1cd, 0x1de, 0x412, 0x463,
			0x454, 0x456, 0x45a, 0x45b, 0x45c, 0x45d, 0x45f, 0x460,
			0x4da, 0x4e9, 0x57d])


func f5aecb0(p: int, q: int, z: int, non_token: int) -> int:
	return f56a0d0(p, q, z) if non_token != 0 else f56a140(p, q, z)


func f5ae9c0(p: int, exclude: int, non_token: int) -> int:
	for z in range(5):
		var ref := z << 8 | (1 - p) & 0xff
		if f5aecb0(p, 1 - p, z, non_token) != 0 and exclude != ref:
			return ref
	for z in range(5):
		var entry := m.u32(JoeyMem.zone(p, z))
		if (entry & 0xfff) != 0 and (z << 8 | p & 0xff) != exclude and f56db30(p, z, 0x403) != 0 and f5aecb0(p, p, z, non_token) != 0:
			return z << 8 | p & 0xff
	for z in range(5):
		var entry := m.u32(JoeyMem.zone(p, z))
		if (entry & 0xfff) != 0 and (z << 8 | p & 0xff) != exclude and (entry >> 12 & 1) == p:
			var id := f4022e0(entry & 0xfff) & 0xffff
			if id in [0x2f, 0x23d] and f5aecb0(p, p, z, non_token) != 0:
				return z << 8 | p & 0xff
	for z in range(5):
		if (m.u32(JoeyMem.zone(p, z)) & 0xfff) == 0 or (z << 8 | p & 0xff) == exclude:
			continue
		if f56d790(p, z, 0x60c) != 0 or f56d790(p, z, 0x2df) != 0 or f56d790(p, z, 0x58b) != 0 or f56d790(p, z, 0x4dc) != 0 or f56d790(p, z, 0x15c) != 0:
			return z << 8 | p & 0xff
	if non_token != 0:
		return -1
	var limit := 0x514
	var result := -1
	for z in range(5):
		var index := m.u16(JoeyMem.zone(p, z)) & 0xfff
		var ref := z << 8 | p & 0xff
		if index != 0 and ref != exclude and f5aecb0(p, p, z, 0) != 0 and (f402740(index) & 0xffff) == 0:
			var stats := _jzd_stats(p, z)
			var maximum := maxi(_s32(m.u32(stats + 4)), _s32(m.u32(stats + 8)))
			if (maximum & 0xffffffff) <= limit:
				result = ref
				limit = maximum & 0xffffffff
	return result


func f5aece0(p: int, exclude: int, index: int, normal: int) -> int:
	var ref := f5ae9c0(p, exclude, int(normal == 0))
	if _s32(ref) == -1:
		ref = f5aed60(p, exclude, int(normal == 0))
		if _s32(ref) != -1 and _s32(f56f690(ref & 0xff, ref >> 8 & 0xff)) < (f4027b0(index) & 0xffff):
			return ref
		return -1
	return ref


func f5aed60(p: int, exclude: int, non_token: int) -> int:
	var ref := f5ae9c0(p, exclude, non_token)
	if _s32(ref) != -1:
		return ref
	var best := 0xffffffff
	for z in range(5):
		var index := m.u16(JoeyMem.zone(p, z)) & 0xfff
		var candidate := z << 8 | p & 0xff
		if index != 0 and candidate != exclude and f5aecb0(p, p, z, non_token) != 0:
			var stats := _jzd_stats(p, z)
			var score := (m.u32(stats + 8) + m.u32(stats + 4) * 2) & 0xffffffff
			if (f4022e0(index) & 0xffff) in [0x2da, 0x536]:
				score = 0xfffffffe
			if score < best:
				best = score
				ref = candidate
	return ref


func f5aee70(p: int, index: int, mode: int) -> int:
	var level := f4026c0(index) & 0xffff
	var count := 0 if level <= 4 else (1 if level <= 6 else 2)
	var ref := -1
	for i in range(count):
		ref = f5aece0(p, ref, index & 0xffff, int(mode == 0))
		if _s32(ref) == -1:
			return 0
	return 1


func f5aef10(p: int) -> int:
	if f5699a0(p, 0x59a) != 0:
		return 2
	return int(_s32(f56d2c0(p, 0x59a) + f56cbd0(p, 0x59a)) < 1)


func f5aef60(base: int, p: int) -> int:
	var result := -1
	for pass_index in range(3):
		var best := 9999
		for i in range(m.u8(JoeyMem.pl(p) + 8)):
			var at := _jzd_hand(0xa55d64 if pass_index == 0 else base, p, i)
			var index := m.u16(at) & 0xfff
			if pass_index < 2 and (index == 0 or (f4025d0(index) & 0xffff) >= 0x15):
				continue
			if pass_index == 0 and (f402740(index) & 0xffff) != 0:
				continue
			if f5ae3e0(p, 1, f4022e0(index)) == 0:
				var defense := f402800(index) & 0xffff
				var value := defense + (f4027b0(index) & 0xffff)
				if value < best:
					best = value
					result = i
		if result >= 0:
			return result
	return result


func f5af1d0(base: int, p: int) -> int:
	var result := -1
	var best := -1
	for pass_index in range(2):
		for i in range(m.u8(JoeyMem.pl(p) + 8)):
			var index := m.u16(_jzd_hand(base, p, i)) & 0xfff
			if index == 0 or (f4025d0(index) & 0xffff) >= 0x15 or f567a00(index) != 0:
				continue
			if f5ae3e0(p, 1, f4022e0(index)) == 0:
				var attack := f4027b0(index) & 0xffff
				if best < attack and (pass_index != 0 or (f4026c0(index) & 0xffff) > 4):
					best = attack
					result = i
		if result >= 0:
			return result
	return result


func f5af370(p: int) -> int:
	if (_s32(f56d340(p, 0x3f0)) >= 0 or _s32(f56d340(p, 0x488)) >= 0 or f5b3c30(p, 0x447) != 0) and _s32(f56a000(p)) > 0:
		var target := _s32(f5af1d0(0xa55d64, p))
		if target >= 0:
			return target
	for i in range(m.u8(JoeyMem.pl(p) + 8)):
		if (f4022e0(m.u16(_jzd_hand(0xa55d64, p, i)) & 0xfff) & 0xffff) == 0x1da:
			return i
	return f5aef60(0xa55d64, p)


func f5af450(p: int, monster_only: int, no_traps: int, trap_only: int) -> int:
	if f57f130(p, 1, 0, monster_only, trap_only) == 0:
		return -1
	var target := _s32(f5af370(p))
	if target < 0:
		target = f5bddb0(m.u8(JoeyMem.pl(p) + 8))
	while true:
		var at := _jzd_hand(0xa55d64, p, target)
		var index := m.u32(at) & 0xfff
		var valid := true
		if monster_only != 0 and f402690(index) == 0:
			valid = false
		if trap_only != 0 and (f4025d0(index) & 0xffff) != 0x16:
			valid = false
		if no_traps != 0 and (f4025d0(index) & 0xffff) == 0x16:
			valid = false
		if f570be0(p, at) == 0 and valid:
			return target
		target = f5bddb0(m.u8(JoeyMem.pl(p) + 8))
	return target


func f5af5a0(p: int, index: int, context: int) -> int:
	if f599e30(p, f4022e0(index), context & 0xffff) == 0:
		return -1
	var target := _s32(f5af600(p, index))
	if target < 0:
		return -1
	f40caa0(target)
	return target


func f5afc10(i: int) -> int:
	return int(_s32(f40cc90(i)) > 0)


func f5afc30(card: int) -> int:
	var index := f402460(card) & 0xffff
	for i in range(m.u16(0xa585a4)):
		if f5afc10(i) == 0 and (m.u32(0xa582a4 + i * 4) & 0xfff) == index:
			return i
	return -1


func f5afca0(card: int) -> int:
	var index := f402460(card) & 0xffff
	var count := 0
	for i in range(m.u16(0xa585a4)):
		if f5afc10(i) == 0 and (m.u32(0xa582a4 + i * 4) & 0xfff) != index:
			count += 1
	if count != 0:
		var selected := f5bddb0(count)
		for i in range(m.u16(0xa585a4)):
			if f5afc10(i) == 0 and (m.u32(0xa582a4 + i * 4) & 0xfff) != index:
				if selected == 0:
					return i
				selected -= 1
		return -1
	for i in range(m.u16(0xa585a4)):
		if f5afc10(i) == 0:
			return i
	return -1


func f5afd90(p: int, card: int) -> int:
	var index := f402460(card) & 0xffff
	for i in range(m.u16(0xa585a4)):
		var entry := m.u32(0xa582a4 + i * 4)
		if f5afc10(i) == 0 and (entry & 0xfff) == index and (entry >> 12 & 1) == p:
			return i
	return -1


func f5af600(p: int, index: int) -> int:
	var count := m.u16(0xa585a4)
	if count == 0:
		return -1
	var card := f4022e0(index) & 0xffff
	if f5b0540(p, 0x14) != 0:
		if card in [0x447, 0x3f0, 0x45c, 0x487, 0x488, 0x41e, 0x463]:
			for preferred in [0x2f, 0x23d]:
				var target := _s32(f5afd90(p, preferred))
				if target >= 0:
					return target
			if card in [0x41e, 0x463]:
				return f5afca0(0x14)
		elif card == 0x439:
			for preferred in [0x11, 0x12, 0x13]:
				var target := _s32(f5afc30(preferred))
				if target >= 0:
					return target
			return f5afca0(0x14)
		elif card in [0x2f, 0x23d, 0x47b]:
			for preferred in range(0x10, 0x15):
				var target := _s32(f5afc30(preferred))
				if target >= 0:
					return target
	if card == 0x443:
		for i in range(count - 1, -1, -1):
			if f5afc10(i) == 0 and (m.u32(0xa582a4 + i * 4) & 0xfff) == m.u16(0xa579a4):
				return i
	if card == 0x400:
		var first := 0
		while first < count:
			if f5afc10(first) == 0 and (m.u32(0xa582a4 + first * 4) >> 12 & 1) != 1 - p:
				break
			first += 1
		count = first
		if count == 0:
			return -1
	if card in [0x443, 0x65, 0x1ab]:
		for a in range(0x5efaf4, 0x5efb1c, 2):
			for i in range(count):
				if f5afc10(i) == 0 and (f4022e0(m.u16(0xa582a4 + i * 4) & 0xfff) & 0xffff) == m.u16(a):
					return i
	if card in [0x5ea, 0x5eb, 0x5ec, 0x5ed, 0x5ee, 0x5ef, 0x5fc]:
		var result := -1
		var best := -1
		for i in range(count):
			if f5afc10(i) == 0:
				var candidate := m.u16(0xa582a4 + i * 4) & 0xfff
				var defense := f402800(candidate) & 0xffff
				var attack := f4027b0(candidate) & 0xffff
				var maximum := maxi(defense, attack)
				if best < 0 or maximum < best:
					best = maximum
					result = i
		return result
	if card == 0x45c and f5699c0(0x47f) == 0:
		for i in range(count):
			if f5afc10(i) == 0 and (m.u16(0xa582a4 + i * 4) & 0xfff) == (index & 0xffff):
				return i
	if count < 1:
		return -1
	if card not in [0x447, 0x488]:
		var enemy_atk := 0
		var enemy_def := 0
		for z in range(5):
			var stats := _jzd_stats(1 - p, z)
			enemy_atk = maxi(enemy_atk, _s32(m.u32(stats + 4)))
			enemy_def = maxi(enemy_def, _s32(m.u32(stats + 8)))
		var result := -1
		var best := 0
		for i in range(count):
			if f5afc10(i) != 0:
				continue
			var candidate := m.u16(0xa582a4 + i * 4) & 0xfff
			var defense := f402800(candidate) & 0xffff
			var attack := f4027b0(candidate) & 0xffff
			var maximum := maxi(defense, attack)
			if best < maximum and (enemy_atk <= (f4027b0(candidate) & 0xffff) or enemy_def < (f4027b0(candidate) & 0xffff) or enemy_atk <= (f402800(candidate) & 0xffff)):
				best = maximum
				result = i
		if result >= 0:
			return result
	var best := 0
	var result := -1
	var available := 0
	for i in range(count):
		if f5afc10(i) == 0:
			var candidate := m.u16(0xa582a4 + i * 4) & 0xfff
			if best < f4027b0(candidate):
				best = f4027b0(candidate) & 0xffff
				result = i
			available += 1
	if result >= 0:
		return result
	var selected := _s32(f5bddb0(available))
	for i in range(count):
		if f5afc10(i) == 0:
			if selected == 0:
				return i
			selected -= 1
	return count


func f5afe10(p: int, index: int, context: int, limit: int) -> int:
	var candidates := _s32(f599e30(p, f4022e0(index), context & 0xffff))
	var count := 0
	while count < _s32(limit) and count < candidates:
		var selected := _s32(f5af600(p, index))
		if selected < 0:
			break
		f40caa0(selected)
		count += 1
		f40cc60(selected, count)
	m.set_u16(0xa558b4, count)
	return count


func f5aff10(p: int, attack_out: int, defense_out: int, face_up_only: int) -> int:
	m.set_u32(attack_out, 0)
	m.set_u32(defense_out, 0)
	for z in range(5):
		var a := JoeyMem.zone(p, z)
		if (m.u32(a) & 0xfff) == 0:
			continue
		var hidden := (m.u16(a + 6) & 2) == 0
		if hidden and face_up_only != 0:
			continue
		if hidden:
			m.set_u16(a + 6, m.u16(a + 6) | 2)
		var stats := _jzd_stats(p, z)
		if hidden:
			m.set_u16(a + 6, m.u16(a + 6) & 0xfffd)
		m.set_u32(attack_out, maxi(_s32(m.u32(attack_out)), _s32(m.u32(stats + 4))))
		m.set_u32(defense_out, maxi(_s32(m.u32(defense_out)), _s32(m.u32(stats + 8))))
	return 0


func f5afe90(p: int) -> int:
	var out := m.local(16)
	f5aff10(1 - p, out, out + 4, 1)
	f5aff10(p, out + 8, out + 12, 0)
	var enemy_atk := _s32(m.u32(out))
	var enemy_def := _s32(m.u32(out + 4))
	var own_atk := _s32(m.u32(out + 8))
	var own_def := _s32(m.u32(out + 12))
	if maxi(enemy_atk, enemy_def) < own_atk:
		return 2
	return (int(enemy_atk <= maxi(own_atk, own_def)) - 1) & 0xfffffffe


func _jzd_best(p: int, q: int, excluded: int, attack: int, defense: int, return_zone: bool) -> int:
	var best := -1
	var result := -1
	for z in range(5):
		if z == _s32(excluded) or (m.u32(JoeyMem.zone(q, z)) & 0xfff) == 0:
			continue
		var stats := _jzd_stats(q, z, 1 if p == q else 2)
		var value := 0
		var atk := _s32(m.u32(stats + 4))
		var defe := _s32(m.u32(stats + 8))
		if attack != 0 and atk >= 0:
			value = atk
		if defense != 0 and value <= defe:
			value = defe
		if best < value:
			best = value
			result = z
	return result if return_zone else best


func f5affd0(p: int, q: int, excluded: int, attack: int, defense: int) -> int:
	return _jzd_best(p, q, excluded, attack, defense, false)


func f5b0090(p: int, q: int, excluded: int, attack: int, defense: int) -> int:
	return _jzd_best(p, q, excluded, attack, defense, true)


func f5b0150(effect: int, p: int, exclude: int, fallback: int) -> int:
	var best := -1
	var result := -1
	for z in range(5):
		var a := JoeyMem.zone(p, z)
		if z == _s32(exclude) or (m.u32(a) & 0xfff) == 0 or (m.u8(a + 6) & 2) == 0 or f57a470(effect, z << 8 | p & 0xff) == 0:
			continue
		var attack := _s32(f56f690(p, z))
		if f56db30(p, z, 0x403) == 0 and f56b7d0(p, z, 1) != 0:
			var card := f4022e0(m.u16(a) & 0xfff) & 0xffff
			if card == 0x1ec:
				attack += 500
			elif card in [0x51, 0x186] and (f4022e0(m.u16(effect)) & 0xffff) == 0x291:
				return z
			elif card == 0x547:
				attack = -1
			if best < attack:
				best = attack
				result = z
	if fallback != 0 and result == -1:
		for z in range(5):
			var a := JoeyMem.zone(p, z)
			if z != _s32(exclude) and (m.u32(a) & 0xfff) != 0 and (m.u8(a + 6) & 2) != 0 and f57a470(effect, z << 8 | p & 0xff) != 0:
				return z
	return result


func f5b0330(p: int, q: int) -> int:
	var total := 0
	for z in range(5):
		var stats := _jzd_stats(q, z, 1 if p == q else 2)
		total = _s32(total + m.u32(stats + 4))
	return total


func f5b0380(p: int, index: int) -> int:
	if (f402700(index) & 0xffff) == 2:
		return int((m.u16(JoeyMem.zone(p, 10)) & 0xfff) != (index & 0xffff))
	var empty := 0
	for z in range(5, 10):
		var current := m.u32(JoeyMem.zone(p, z)) & 0xfff
		if current == (index & 0xffff):
			return 0
		if current == 0:
			empty += 1
	return int(empty > 1)


func f5b0420(p: int) -> int:
	p &= 1
	for i in range(m.u8(JoeyMem.pl(p) + 8)):
		if _s32(f5be190(m.u16(_jzd_hand(0xa55d64, p, i)) & 0xfff)) < 3:
			return i
	for a in range(0x5efb1c, 0x5efb4e, 2):
		for i in range(m.u8(JoeyMem.pl(p) + 8)):
			if (f4022e0(m.u16(_jzd_hand(0xa55d64, p, i)) & 0xfff) & 0xffff) == m.u16(a):
				return i
	return -1


func f5b04f0(p: int) -> int:
	var result := _s32(f5b0420(1 - p))
	return f5bddb0(m.u8(JoeyMem.pl(1 - p) + 8)) if result == -1 else result


func f5b0540(p: int, card: int) -> int:
	if f569300(p, card) != 0 or f56d2c0(p, card) != 0 or f56cbd0(p, card) != 0:
		return 1
	return int(f569300(p, card) != 0)


func f5b05a0(p: int, attacker: int, target: int, caution: int) -> int:
	var other := 1 - p
	var card := f4022e0(m.u16(JoeyMem.zone(p, attacker)) & 0xfff) & 0xffff
	if card in [0x2f9, 0x2e8]:
		if caution != 0:
			var attack := _s32(f56f690(p, attacker))
			var found := false
			for z in range(5):
				if (m.u32(JoeyMem.zone(p, z)) & 0xfff) != 0 and _s32(f56f690(p, z)) < attack:
					found = true
			if not found:
				return 0
	elif card == 0x16e:
		if (f56bf20(p, attacker) == 0 or _s32(f56f690(p, attacker)) < m.u16(JoeyMem.pl(other) + 4)) and caution != 0 and m.u16(JoeyMem.pl(p) + 4) > 4000:
			return 0
	var attack := 0
	if _s32(target) > 4:
		attack = _s32(f56f690(p, attacker))
		if m.u16(JoeyMem.pl(other) + 4) <= attack or f56b5a0(p, attacker) == 0:
			return 1
		attack = _s32(f56f690(p, attacker))
		if attack < 300:
			return 0
		attack = _s32(f56f690(p, attacker))
		target = -1
	else:
		var a := JoeyMem.zone(other, target)
		if card == 0x540:
			if (m.u8(a + 6) & 2) == 0:
				return 0
			var value := _s32(f56f690(other, target)) if (m.u8(a + 6) & 1) == 0 else _s32(f56f6b0(other, target))
			if value < (0x76c if (m.u8(a + 6) & 1) == 0 else 2000):
				return 0
		if (f4022e0(m.u16(a) & 0xfff) & 0xffff) == 0x5f2 and (m.u8(a + 6) & 2) != 0:
			for z in range(5):
				var zone := JoeyMem.zone(other, z)
				if (m.u32(zone) & 0xfff) != 0 and ((m.u8(zone + 6) & 2) == 0 or (f4022e0(m.u16(zone) & 0xfff) & 0xffff) != 0x5f2):
					return 0
		if f56b5a0(p, attacker) == 0:
			return 1
		attack = _s32(f56f690(p, attacker))
	return int(_s32(f5ade40(other, target)) < attack + 1000)


func f5b08e0(p: int) -> int:
	m.set_u16(0xa579ae, m.u16(JoeyMem.pl(p) + 0xe))
	m.set_u16(0xa579b0, m.u16(JoeyMem.pl(p) + 0x10))
	m.copy(0xa579b4, 0xa55d74, 0x2d0)
	m.copy(0xa57c84, 0xa56ab8, 0x2d0)
	return 0


func f5b0950(p: int) -> int:
	m.set_u16(0xa579ac, m.u16(JoeyMem.pl(p) + 0x10))
	m.set_u16(JoeyMem.pl(p) + 0xe, m.u16(0xa579ae))
	m.set_u16(JoeyMem.pl(p) + 0x10, m.u16(0xa579b0))
	m.copy(0xa55d74, 0xa579b4, 0x2d0)
	m.copy(0xa56ab8, 0xa57c84, 0x2d0)
	return 0


func f5b09c0(p: int) -> int:
	for z in range(5):
		var a := JoeyMem.zone(p, z)
		var entry := m.u16(a)
		if (entry & 0xfff) == 0:
			continue
		if (m.u16(a + 6) & 2) == 0:
			if f570a70(p) == 0:
				continue
			if (m.u16(a + 6) & 2) == 0 and f567620(entry & 0xfff, 0) != 0:
				continue
		if (m.u16(a + 6) & 1) != 0 and f56b5a0(p, z) != 0:
			m.set_u16(a + 6, m.u16(a + 6) & 0xfffe | 2)
	return 0


func f5b0b90(p: int) -> int:
	m.set_u16(0xa579a6, m.u16(0xa579a6) & 0xf3f9)
	m.set_u16(0xa579a8, 0)
	var attackers: Array[int] = []
	for z in range(5):
		if f56b730(p, z, 1) != 0:
			attackers.append(z)
	# Los ATK no cambian al ordenar. Conserva los intercambios y desempates nativos.
	var scores: Array[int] = []
	for z in attackers:
		var attack := f56f690(p, z)
		var id := f4022e0(m.u16(JoeyMem.zone(p, z)) & 0xfff) & 0xffff
		var priority := 3 if id in [0x2f9, 0x226, 0x2e8] else (1 if id == 0x5f3 else 2)
		scores.append(priority << 16 | attack & 0xffff)
	for i in range(attackers.size() - 1):
		var best := 0xffffffff
		var chosen := i
		for j in range(i, attackers.size()):
			var score := scores[j]
			if score < best:
				best = score
				chosen = j
		var swap := attackers[i]
		attackers[i] = attackers[chosen]
		attackers[chosen] = swap
		scores[chosen] = scores[i]
		scores[i] = best
	var out := m.local(4)
	m.set_u32(out, p)
	for z in attackers:
		if f5b0d90(p, z, 1, out) != 0:
			m.copy(0xa579a6, out, 4)
			m.set_u16(0xa579a6, m.u16(0xa579a6) | 4)
			return 1
	return 0


func f5b0a50(p: int) -> int:
	m.set_u16(0xa579aa, m.u16(0xa579aa) & 0xffc0)
	m.set_u16(JoeyMem.pl(p) + 0x10, 0)
	var total := 0
	if f5a0dd0(p) != 0:
		while f5b0b90(p) != 0:
			var flags := m.u16(0xa579a6)
			var z := flags >> 4 & 7
			m.set_u16(JoeyMem.pl(p) + 0x10, m.u16(JoeyMem.pl(p) + 0x10) | (1 << z))
			if flags & 0x400:
				var a := JoeyMem.zone(p, z)
				m.set_u32(a, m.u32(a) & 0xfffff000)
				m.set_u8(0xa579aa, m.u8(0xa579aa) ^ ((m.u8(0xa579aa) + 1 ^ m.u8(0xa579aa)) & 7))
			if flags & 0x800:
				var a := JoeyMem.zone(1 - p, flags >> 7 & 7)
				m.set_u32(a, m.u32(a) & 0xfffff000)
				var old := m.u8(0xa579aa)
				m.set_u8(0xa579aa, old ^ (((old & 0xf8) + 8 ^ old) & 0x38))
			total = _s32(total + m.s16(0xa579a8))
	return total


func f5b08b0(p: int) -> int:
	f5b08e0(p)
	f5b09c0(p)
	var value := f5b0a50(p)
	f5b0950(p)
	return value


func f5b0f40(p: int, attacker: int, target: int, out: int) -> int:
	var other := 1 - p
	var mode := m.u8(JoeyMem.zone(other, target) + 6)
	var own := _jzd_stats(p, attacker, 1)
	var enemy := _jzd_stats(other, target, 2)
	var attack := _s32(m.u32(own + 4))
	var own_defense := _s32(m.u32(own + 8))
	var enemy_attack := _s32(m.u32(enemy + 4))
	var enemy_defense := _s32(m.u32(enemy + 8))
	var card := f4022e0(m.u32(own)) & 0xffff
	if card == 0x1dd and m.u8(enemy + 2) == 6:
		attack = _s32(attack + 1000)
	elif card == 0x4e5 and m.u8(enemy + 2) == 15:
		attack = _s32(attack + 2000)
		own_defense = _s32(own_defense + 2000)
	var enemy_card := f4022e0(m.u32(enemy)) & 0xffff
	if enemy_card == 0x11f and m.u8(own + 2) == 1:
		enemy_defense = _s32(f5be050(enemy_defense))
	elif enemy_card == 0x4e5 and m.u8(own + 2) == 15:
		enemy_attack = _s32(enemy_attack + 2000)
		enemy_defense = _s32(enemy_defense + 2000)
	var links := f56d790(p, attacker, 0x291)
	attack = _s32(attack + links * f5be050(enemy_attack))
	var flags := (((target & 7) << 3 | attacker & 7) << 4) | m.u16(out) & 0xf005
	m.set_u16(out, flags)
	m.set_u16(out + 2, 0)
	var enemy_value := enemy_attack if (mode & 1) == 0 else enemy_defense
	var to_enemy := 0
	var to_self := 0
	if attack == enemy_value:
		if (mode & 1) == 0 and attack > 0:
			m.set_u16(out, flags | 0xc00)
	elif enemy_value < attack:
		var difference := _s32(attack - enemy_value)
		if (mode & 1) == 0:
			m.set_u8(out + 1, m.u8(out + 1) | 8)
			to_enemy = difference
		else:
			if (f4022e0(m.u32(own)) & 0xffff) == 0x53d or f56d8d0(p, attacker, 0x521, p) != 0 or f56d8d0(p, attacker, 0x604, p) != 0:
				to_enemy = difference
			if f56d8d0(p, attacker, 0x521, other) != 0 or f56d8d0(p, attacker, 0x604, other) != 0:
				to_self = difference
			m.set_u8(out + 1, m.u8(out + 1) | 8)
	else:
		to_self = _s32(enemy_value - attack)
		if (mode & 1) == 0:
			m.set_u16(out, flags | 0x400)
	if m.u32(JoeyMem.pl(other) + 0x6d0) & 0x400000:
		m.set_u16(out, m.u16(out) & 0xf7ff)
		to_enemy = 0
	if m.u32(JoeyMem.pl(p) + 0x6d0) & 0x400000:
		m.set_u16(out, m.u16(out) & 0xfbff)
		to_self = 0
	if to_enemy > 0 and _s32(f5699a0(other, 0x58f)) > 0 and f56b220(0x14d) != 0:
		to_enemy = 0
	if to_self > 0 and _s32(f5699a0(p, 0x58f)) > 0 and f56b220(0x14d) != 0:
		to_self = 0
	card = f4022e0(m.u32(own)) & 0xffff
	if card == 0x199 and m.u8(enemy + 3) == 2:
		m.set_u8(out + 1, m.u8(out + 1) | 8)
	elif card == 0x4cf:
		m.set_u16(out, m.u16(out) & 0xfbff)
		to_self = 0
		to_enemy = 0 if (mode & 1) != 0 else 500
	elif card == 0x4e3 and enemy_attack > 0x76b:
		m.set_u16(out, m.u16(out) & 0xfbff)
	var score := s16(to_enemy - to_self)
	m.set_u16(out + 2, score)
	var useful := score > 0 or (m.u16(out) >> 1 & 0x400) > (m.u16(out) & 0x400)
	m.set_u16(out, int(useful) << 3 | m.u16(out) & 0xfff7)
	return 0


func f5b0d90(p: int, attacker: int, caution: int, out: int) -> int:
	if f56bf20(p, attacker) != 0 or f56bfd0(p, attacker) != 0:
		if f5b05a0(p, attacker, 5, caution) == 0:
			return 0
		m.set_u8(out, m.u8(out) | 2)
		var attack := f56f690(p, attacker) & 0xffff
		m.set_u16(out, (attacker & 7) << 4 | m.u16(out) & 0xf38f)
		m.set_u16(out + 2, attack)
		return int(s16(attack) > 0)
	m.set_u16(out, m.u16(out) & 0xfff5)
	m.set_u16(out + 2, 0)
	var other := 1 - p
	var local := m.local(4)
	m.set_u32(local, p)
	for target in range(5):
		if f56bd80(p, attacker, other, target) == 0 or f5b05a0(p, attacker, target, caution) == 0:
			continue
		f5b0f40(p, attacker, target, local)
		if (m.u32(local) & 8) == 0:
			continue
		var old := m.u16(out)
		var copy := (old & 8) == 0 or m.s16(out + 2) < m.s16(local + 2)
		if not copy and m.u16(local + 2) == m.u16(out + 2):
			var new_target := m.u32(local) >> 7 & 7
			copy = true
			if m.u8(JoeyMem.zone(other, new_target) + 6) & 2:
				copy = _s32(f56f6b0(other, new_target)) > _s32(f56f6b0(other, old >> 7 & 7))
		if copy:
			m.copy(out, local, 4)
	return m.u8(out) >> 3 & 1


func f5b1310(p: int) -> int:
	return f5b0b90(p)


func f5b1320(p: int, attacker: int) -> int:
	var result := f5b0d90(p, attacker, 0, 0xa579a6) & 1
	m.set_u16(0xa579a6, result << 2 | m.u16(0xa579a6) & 0xfffb)
	return result


func f5b1360(p: int, mode: int) -> int:
	var result := -1
	var best := _s32(f5b08b0(p))
	var killed := m.u8(0xa579aa) >> 3 & 7
	var tribute_refs := m.local(4)
	m.set_u32(tribute_refs, p)
	for i in range(m.u8(JoeyMem.pl(p) + 8)):
		var index := m.u16(_jzd_hand(0xa55d64, p, i)) & 0xfff
		if f5aab90(p, index) == 0 or f5ae3e0(p, 2, f4022e0(index)) != 0 or f5ae220(index) != 0:
			continue
		var level := f4026c0(index) & 0xffff
		var tributes := 0
		if level in [1, 2, 3, 4]:
			if mode == 1:
				continue
		elif level in [5, 6]:
			if mode == 0:
				continue
			var ref := f5aece0(p, -1, index, 0) & 0xffff
			m.set_u16(tribute_refs, ref)
			if ref == 0xffff:
				continue
			tributes = 1
		else:
			if mode == 0:
				continue
			var ref := f5aece0(p, -1, index, 0) & 0xffff
			m.set_u16(tribute_refs, ref)
			ref = f5aece0(p, ref, index, 0) & 0xffff
			m.set_u16(tribute_refs + 2, ref)
			if ref == 0xffff:
				continue
			tributes = 2
		f5b08e0(p)
		f5b09c0(p)
		var placed := f5b1610(p, index, tributes, tribute_refs)
		var stats := _jzd_stats(p, placed)
		var attack := _s32(m.u32(stats + 4))
		var score := _s32(f5b0a50(p))
		var count := f569d50(p)
		m.set_u16(0xa579aa, (count & 7) << 6 | m.u16(0xa579aa) & 0xfe3f)
		count = f569d50(1 - p)
		m.set_u16(0xa579aa, (count & 7) << 9 | m.u16(0xa579aa) & 0xf1ff)
		f5b0950(p)
		var new_killed := m.u8(0xa579aa) >> 3 & 7
		if attack > 899 and (m.u16(0xa579ac) & (1 << (placed & 31))) != 0 and ((score == best and killed < new_killed and (m.u16(0xa579aa) & 0x1c0) != 0) or best < score):
			killed = new_killed
			result = i
			best = score
	return result
