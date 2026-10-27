extends RefCounted
## Fórmulas originales de set/summon/explosion/shuffle/activate/attack.
const Math = preload("res://scenes/duel/duel_visual_math.gd")
const Geometry = preload("res://scenes/duel/duel_geometry.gd")
const Portrait = preload("res://scenes/duel/duel_portrait_effects.gd")
static var _white_card: Shader
static var _attacks: Dictionary = {}
static var _break_noise := PackedInt32Array()

static func normalize(event: Dictionary, duel: Duel) -> Dictionary:
	var d := event.duplicate(true)
	var mode: String = d.get("mode", "")
	var p: int = int(d.get("p", 0)) & 1
	if d.get("kind", "") == "token":
		mode = "special"
		d["mode"] = mode
	if mode in ["set", "summon"]:
		var z: int = clampi(int(d.get("zone", 0)), 0, 10)
		if d.get("kind", "") == "cmd":
			z = clampi(int(d.get("args", [0, 0])[1]), 0, 10)
		d["zone"] = z
		# Si el evento trae las banderas (colocar desde la mano: el comando 0xc4/0xc5 las da en
		# su argumento b y aun no ha puesto la carta en la zona) se usan esas.
		var flags: int = int(d["flags"]) if d.has("flags") else duel.m.u8(DuelMem.zone(p, z) + 6)
		d["flags"] = flags
		d["angle"] = ((flags & 1) + p * 2) * 128
		d["center"] = Geometry.zone(p, z, str(d.get("game", "")))
		d["hide"] = [d["center"]]
		if mode == "set":
			var points: Array[Vector2] = []
			for index in 8:
				var radius: int = (Portrait.visual_rand(duel) & 31) + 16
				points.append(d["center"] + Vector2((Math.cos_fx(index * 64) * radius) >> 16,
					(Math.cos_fx(index * 64 - 128) * radius) >> 16))
			d["set_points"] = points
			d["face"] = bool(flags & 2)
			d["hide"] = [d["center"]]
	elif mode == "special":
		# 44fcc0 (Joey) sitúa su efecto en cualquier zona del campo con 45c140; los efectos de
		# Yugi/Kaiba que comparten este modo solo invocan en zonas de monstruo.
		var z: int = clampi(int(d.get("zone", 0)), 0, 10 if d.get("game", "") == "joey" or d.get("kind", "") == "joey_relocate_appear" else 4)
		d["zone"] = z
		# 44fcc0 carries the destination orientation before the rules place the card.
		var flags := int(d.get("flags", duel.m.u8(DuelMem.zone(p, z) + 6)))
		if d.get("kind", "") in ["special_summon", "joey_relocate_appear"]:
			flags = ((int(d.get("a", 0)) >> 9) & 1) | (((int(d.get("a", 0)) >> 8) & 1) << 1)
		d["flags"] = flags
		d["center"] = Geometry.zone(p, z, str(d.get("game", "")))
		d["hide"] = [d["center"]]
		var texture: Texture2D = CardDB.card_texture(d.get("card", 0), true) if flags & 2 else Assets.texture("common/mini/card_ura.png")
		if texture:
			var image := texture.get_image().duplicate() as Image
			var quarter_turns := (flags & 1) + p * 2
			for turn in quarter_turns: image.rotate_90(CLOCKWISE)
			d["special_texture"] = ImageTexture.create_from_image(image)
			# 4394a0 -> 523740 pide _rand() por fila en cada fotograma dibujado entre c64 y c320:
			# es el mismo rand() del CRT que usan las reglas, asi que el efecto avanza la
			# aleatoriedad del duelo (traza Frida 2026-10-08: 2088 llamadas desde 52386c). El
			# motor espera a la animacion, de modo que consumirlas al preparar el efecto deja el
			# generador igual que repartirlas tick a tick (suponiendo que no se salten dibujos).
			var jitters: Array = []
			for tick in 41:
				var offsets := PackedInt32Array()
				var counter := tick * 8
				if counter > 63 and counter < 320:
					var width := Math.cos_fx(counter - 192) >> 13
					for row in image.get_height():
						var offset := 0
						if width > 0:
							offset = duel.rng.rand() % width - width / 2
						offsets.append(offset)
				jitters.append(offsets)
			d["special_jitters"] = jitters
	elif mode in ["joey_hand_shuffle", "joey_field_shuffle"]:
		var objects: Array = []
		var hide: Array = []
		var hand := mode == "joey_hand_shuffle"
		var count := duel.m.u8(DuelMem.pl(p) + DuelMem.P_HAND_N)
		for i in d["objects"]:
			var at := duel.f5419b0(p, 11 if hand else 0, int(i))
			var center: Vector2 = d.get("centers", {}).get(i, Geometry.hand(p, i, count) if hand else Geometry.zone(p, i))
			var flags := int(d["visual_flags"][i]) if not hand else 0
			var card := duel.f401a70(duel.m.u32(at) & 0xfff)
			objects.append({"center":center, "card":card, "before":d["before"][i] if hand else card,
				"angle":(p * 2 + (flags & 1)) * 128, "face":p == 0 if hand else bool(flags & 2)})
			hide.append(center)
		d["shuffle_objects"] = objects
		d["hide"] = hide
	elif mode == "hand_shuffle":
		var count := duel.m.u8(DuelMem.pl(p) + DuelMem.P_HAND_N)
		var cards: Array[int] = []
		var initial: Array[Vector2] = []
		for index in count:
			cards.append(duel.cards.id_of(duel.m.u16(DuelMem.pl(p) + DuelMem.P_HAND + index * 4) & 0xfff))
			initial.append(Geometry.hand(p, index, count))
		var positions: Array = []
		for tick in 33:
			var current: Array[Vector2] = []
			for index in count:
				var target := Geometry.hand(p, index, count, index == (tick / 2) % maxi(1, count))
				var old: Vector2 = initial[index]
				current.append(target + Vector2(Math.trunc_div(int(old.x - target.x) * 3, 4), Math.trunc_div(int(old.y - target.y) * 3, 4)))
			positions.append(current)
			initial = current
		d["hand_cards"] = cards
		d["hand_frames"] = positions
		d["hide"] = []
		for index in count: d["hide"].append(Geometry.hand(p, index, count))
	elif mode == "card_effect":
		var card: int = d.get("card", 0)
		var index := duel.cards.index_of(card)
		d["monster"] = duel.cards.type_of(index) > 0 and duel.cards.type_of(index) < 21
		var loc: int = d.get("loc", 11)
		var slot: int = d.get("c", 0)
		var exists := false
		if d.get("native_activation", false):
			# 450260 recibe el objeto visual; la zona lógica puede estar ya retirada.
			exists = true
			d["center"] = Geometry.location(p, loc, slot, duel.m.u8(DuelMem.pl(p) + 2))
			if loc == 11:
				d["hand_slot"] = slot
				d["effect_size"] = Geometry.HAND_SIZE
		elif loc < 11:
			var z := loc + slot if loc in [0, 5] else loc
			if z < 11:
				exists = (duel.m.u16(DuelMem.zone(p, z)) & 0xfff) == index
				if exists:
					d["flags"] = duel.m.u8(DuelMem.zone(p, z) + 6)
					d["center"] = Geometry.zone(p, z, str(d.get("game", "")))
		elif loc == 14:
			exists = duel.f544a00(p, card) != 0
			if exists: d["center"] = Geometry.GRAVE[p]
		elif loc == 11:
			var count := duel.m.u8(DuelMem.pl(p) + 2)
			for hand_index in count:
				if (duel.m.u16(DuelMem.pl(p) + DuelMem.P_HAND + hand_index * 4) & 0xfff) == index:
					exists = true
					d["center"] = Geometry.hand(p, hand_index, count)
					d["hand_slot"] = hand_index
					d["effect_size"] = Geometry.HAND_SIZE
					break
		d["large_activation"] = not exists
		if not exists: d["center"] = Vector2(525, 300)
		d["effect_size"] = d.get("effect_size", Geometry.FIELD_SIZE) if exists else Geometry.HAND_SIZE
		d["card_size"] = d["effect_size"]
		if exists and loc < 11 and (int(d.get("flags", 0)) & 1):
			var size: Vector2 = d["effect_size"]
			d["effect_size"] = Vector2(size.y, size.x)
		d["hide"] = [d["center"]] if exists else []
	elif mode == "shuffle":
		d["deck_pos"] = Geometry.DECK[p]
	elif mode == "destroy_effect":
		var z: int = d.get("zone", 0)
		var off_field: bool = d.get("native_pile_destroy", false)
		var hand: bool = off_field and int(d.get("loc", 0)) == 11
		var flags: int = int(d.flags) if off_field else duel.m.u8(DuelMem.zone(p, z) + 6)
		if not d.has("card"): d["card"] = duel.cards.id_of(duel.m.u16(DuelMem.zone(p, z)) & 0xfff)
		d["flags"] = flags
		d["hide"] = [d["center"]]
		var texture: Texture2D = CardDB.card_texture(d["card"], not hand) if flags & 2 else Assets.texture("common/card/card_ura.png" if hand else "common/mini/card_ura.png")
		if texture:
			var image := texture.get_image().duplicate() as Image
			if hand: image.resize(int(Geometry.HAND_SIZE.x), int(Geometry.HAND_SIZE.y), Image.INTERPOLATE_NEAREST)
			for turn in (flags & 1) + p * 2: image.rotate_90(CLOCKWISE)
			d["break_texture"] = ImageTexture.create_from_image(image)
		if _break_noise.is_empty():
			# 52d6f0 explicitly calls srand(0), then stores low bytes of rand().
			var state := 0
			for index in 256:
				state = (state * 214013 + 2531011) & 0xffffffff
				_break_noise.append((state >> 16) & 255)
	elif mode == "attack":
		var args: Array = d.get("args", [0, 0, 0])
		d["from_pos"] = Geometry.zone(p, clampi(int(args[0]), 0, 4))
		var defender: int = int(args[2]) - 1 if int(args[2]) > 0 else 1 - p
		d["to_pos"] = Geometry.zone(defender & 1, int(args[1])) if int(args[1]) < 5 else Vector2(525, 64 if p == 0 else 536)
		d["defender"] = defender & 1
		d["source_zone"] = clampi(int(args[0]), 0, 4)
		d["target_zone"] = int(args[1]) if int(args[1]) < 5 else -1
		_attacks[duel.get_instance_id()] = d.duplicate(true)
	elif mode == "battle_result":
		var attack: Dictionary = _attacks.get(duel.get_instance_id(), {})
		if attack.is_empty():
			d["frames"] = 0
			return d
		for key in ["from_pos", "to_pos", "defender", "source_zone", "target_zone", "p"]:
			d[key] = attack[key]
		var args: Array = d.get("args", [0, 0, 0])
		d["result_flags"] = [int(args[2]) & 255, (int(args[2]) >> 8) & 255]
		d["damage"] = [int(args[0]), int(args[1])]
		var defender: int = d["defender"]
		d["reflection"] = bool(d.get("native_reflection", d["target_zone"] >= 0 and (d["result_flags"][defender] & 2) == 0))
		var shakes: Array = []
		for side in 2:
			var z: int = d["source_zone"] if side == d["p"] else d["target_zone"]
			var result := int(d["result_flags"][side])
			# Jo414110: state2 afecta el bit2 o el resultado4 exacto de bits2..4.
			var hit := (result & 2) != 0 or (result & 0x1c) == 4 if d.get("native_impact", false) else (result & 6) != 0
			if z < 0 or not hit: continue
			var at := DuelMem.zone(side, z)
			var flags := duel.m.u8(at + 6)
			shakes.append({"card": duel.cards.id_of(duel.m.u16(at) & 0xfff), "pos": Geometry.zone(side, z), "angle": ((flags & 1) + side * 2) * 128, "face": bool(flags & 2)})
		d["shake_cards"] = shakes
		d["reflection_size"] = Geometry.FIELD_SIZE
		if d["target_zone"] >= 0 and (duel.m.u8(DuelMem.zone(defender, d["target_zone"]) + 6) & 1): d["reflection_size"] = Vector2(Geometry.FIELD_SIZE.y, Geometry.FIELD_SIZE.x)
	var duration := timings(d)
	if duration > 0: d["frames"] = duration
	return d

static func timings(event: Dictionary) -> int:
	match event.get("mode", ""):
		"joey_hand_shuffle", "joey_field_shuffle": return 32
		"summon": return 33 # 438c40: +8, vivo mientras <=256.
		"special": return 41 # 438c60: +8, vivo mientras <=320.
		"hand_shuffle": return 33 # 403420 selecciona index=(step>>1)%count.
		"set": return 22 # 438c20: +12.
		"destroy_effect": return 16 # cmd79->43ea60->438d00: +16, alive<256.
		"explosion": return 26 # cmd7a->43d650->40d6c0: +8, 439930 alive<208.
		"shuffle": return 41 # 438dd0 +8 hasta324.
		"card_effect": return 33 if event.get("large_activation", true) else 17
		"attack": return (512 - clampi(int(event.get("native_attack_counter", 0)), 0, 128) + 15) / 16 # Estado4 suma16 hasta512.
		"battle_result": return 64 if event.get("reflection", false) else 32 # Estados6 (+16/512) y7 (+8/256).
		# 0x438d40: el de fin sube +4 hasta 0x200 y ahi se queda (128 fotogramas).
		"banner": return 41 if event.get("op", 0) == 0x14 else 128
	return 0

static func render(owner: Node2D, event: Dictionary, frame: int) -> bool:
	match event.get("mode", ""):
		"joey_hand_shuffle", "joey_field_shuffle": _joey_shuffle(owner, event, frame)
		"pile_top":
			# 43c730 -> 43c870 state7: +32 per tick, commit at256.
			# 43c980 slides the selected card out and back; draw order flips at128.
			var counter := frame * 32
			var offset := ((counter if counter < 128 else 256 - counter) * 50) >> 7
			if event.center.x < 400: offset = -offset
			var target: Vector2 = event.center - Vector2(offset, Math.trunc_div(offset, 4))
			var angle := int(event.p) * 256
			if counter >= 128: _card(owner, {"card":event.before}, event.center, Geometry.FIELD_SIZE, 256, angle)
			_card(owner, event, target, Geometry.FIELD_SIZE, 256, angle)
			if counter < 128: _card(owner, {"card":event.before}, event.center, Geometry.FIELD_SIZE, 256, angle)
		"summon": _summon(owner, event, frame * 8)
		"special": _special(owner, event, frame * 8)
		"hand_shuffle": _hand_shuffle(owner, event, frame)
		"set":
			if event.get("game", "") == "joey": _render_joey_set(owner, event, frame)
			else: _render_set(owner, event, frame * 12)
		"destroy_effect": _break_card(owner, event, frame * 16)
		"explosion": _explosion(owner, event, frame * 8)
		"shuffle": _shuffle(owner, event, frame * 8)
		"card_effect": _activation(owner, event, frame * 16)
		"attack": _attack(owner, event, clampi(int(event.get("native_attack_counter", 0)), 0, 128) + frame * 16)
		"battle_result": _battle_result(owner, event, frame)
		"banner": _banner(owner, event, frame)
		_: return false
	return true


static func joey_shuffle_pose(center: Vector2, hand: bool, p: int, angle: int, frame: int) -> Dictionary:
	var counter := 512 - frame * 16
	var wave := Math.cos_fx(counter / 2 - 128)
	var size := Geometry.HAND_SIZE if hand else Geometry.FIELD_SIZE
	if (angle / 128) & 1: size = Vector2(size.y, size.x)
	if hand:
		return {"pos":center + Vector2(((525 - int(center.x)) * wave * 2) >> 16,
			((1 if p == 1 else -1) * wave * int(size.y)) >> 16), "size":size, "alpha":256}
	var scale := (wave >> 1) + 65536
	var scaled := Vector2((int(size.x) * scale) >> 16, (int(size.y) * scale) >> 16)
	# Native places integer top-left at center-trunc(size/2).
	return {"pos":center + Vector2(int(scaled.x) & 1, int(scaled.y) & 1) * 0.5, "size":scaled,
		"alpha":maxi(0, Math.cos_fx(counter) >> 8)}


static func _joey_shuffle(owner: Node2D, event: Dictionary, frame: int) -> void:
	var hand: bool = event["mode"] == "joey_hand_shuffle"
	for object: Dictionary in event["shuffle_objects"]:
		var pose := joey_shuffle_pose(object["center"], hand, event["p"], object["angle"], frame)
		var card := object.duplicate()
		# 418ef0 refreshes hand images after drawing counter256 (frame16).
		if hand and frame <= 16: card["card"] = object["before"]
		var size: Vector2 = pose["size"]
		if (int(object["angle"]) / 128) & 1: size = Vector2(size.y, size.x)
		_card(owner, card, pose["pos"], size, pose["alpha"], object["angle"], object["face"])

static func _angle(value: int) -> float:
	return value * TAU / 512.0

static func _asset(owner: Node2D, name: String, pos: Vector2, scale: int = 65536, alpha: int = 256, angle: int = 0) -> Sprite2D:
	return owner._asset(name, pos, scale / 65536.0, clampi(alpha, 0, 256) / 256.0, _angle(angle))

static func _card(owner: Node2D, event: Dictionary, pos: Vector2, size: Vector2, alpha: int, angle: int = 0, face: bool = true) -> Sprite2D:
	var sprite: Sprite2D = owner._card(event.get("card", 0), pos, face, size, _angle(angle))
	if sprite: sprite.modulate.a = clampi(alpha, 0, 256) / 256.0
	return sprite

## Vtable de dibujo +ac/+b0: suma el brillo sobre la carta/fondo, no funde el fondo a negro.
static func _additive(item: CanvasItem) -> void:
	if item == null: return
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	item.material = material

static func _summon(owner: Node2D, event: Dictionary, counter: int) -> void:
	var center: Vector2 = event["center"]
	var scale := (counter + 64) * 256
	if scale <= 32768:
		_card(owner, event, center, Vector2(200, 290) * scale / 65536.0,
			Math.cos_fx(counter + 56) >> 8, event.get("angle", 0), bool(int(event.get("flags", 2)) & 2))
		return
	_card(owner, event, center, Geometry.FIELD_SIZE, 256, event.get("angle", 0), bool(int(event.get("flags", 2)) & 2))
	var alpha := mini(255, (Math.cos_fx(counter - 160) * 3) >> 10)
	var size := Geometry.FIELD_SIZE
	if event.get("flags", 0) & 1: size = Vector2(size.y, size.x)
	var first: Sprite2D = owner._asset("eff_rainbow", center)
	if first == null: return
	var image_height := int(first.texture.get_height())
	var y := (counter * 5 / 8) % image_height
	var first_height := mini(int(size.y), image_height - y)
	first.region_enabled = true
	first.region_filter_clip_enabled = true
	first.region_rect = Rect2(0, y, size.x, first_height)
	first.position = center - size / 2 + Vector2(size.x / 2, first_height / 2.0)
	first.modulate.a = clampi(alpha, 0, 256) / 256.0
	if first_height < size.y:
		var remaining := int(size.y) - first_height
		var second: Sprite2D = owner._asset("eff_rainbow", center)
		second.region_enabled = true
		second.region_filter_clip_enabled = true
		second.region_rect = Rect2(0, 0, size.x, remaining)
		second.position = center - size / 2 + Vector2(size.x / 2, first_height + remaining / 2.0)
		second.modulate.a = first.modulate.a

static func _render_set(owner: Node2D, event: Dictionary, counter: int) -> void:
	var center: Vector2 = event["center"]
	var wave := Math.cos_fx(counter - 128)
	var alpha := (wave * 176) >> 16
	var color := "y" if event.get("monster", false) else "b"
	# La carta ya llego desde la mano; el nucleo aun no ha escrito la zona mientras espera
	# este objeto. Representar su imagen base durante toda la espera y sumar la copia
	# luminosa de 4390d0 (Yugi) / 439810 (Kaiba), llamada de dibujo +ac.
	_card(owner, event, center, Geometry.FIELD_SIZE, 256, event.get("angle", 0), event.get("face", false))
	_additive(_card(owner, event, center, Geometry.FIELD_SIZE, wave >> 9, event.get("angle", 0), event.get("face", false)))
	var scale := 65536 if counter < 128 else counter << 9
	_asset(owner, "eff_set_" + color, center, scale, alpha, (-Math.cos_fx(counter / 2)) >> 8)
	var points: Array = event.get("set_points", [])
	for index in points.size():
		var elapsed := counter - index * 16
		if elapsed < 0: continue
		var tick := elapsed / 8
		var pos: Vector2 = points[index] - Vector2(0, tick * tick / 16)
		_additive(_asset(owner, "eff_star%d_%s" % [tick & 1, color], pos, 65536, alpha))

## Joey 44efd0: dibujo portado funcion a funcion (JoeyFxSet: 44f370/44f390). La carta base no
## es de este objeto: la mesa aun no ha escrito la zona mientras espera, igual que en _render_set.
static func _render_joey_set(owner: Node2D, event: Dictionary, frame: int) -> void:
	var center: Vector2 = event["center"]
	_card(owner, event, center, Geometry.FIELD_SIZE, 256, event.get("angle", 0), event.get("face", false))
	var fx := JoeyFxSet.new()
	fx.center = Vector2i(center)
	var flags := int(event.get("flags", 0))
	# Palabra de 452f20 en coordenadas de la vista (jugador local 0): bit 14 posicion, bit 15 cara.
	fx.ref = (int(event.get("p", 0)) & 1) | ((flags & 1) << 14) | (((flags >> 1) & 1) << 15)
	fx.monster = bool(event.get("monster", false))
	for point: Vector2 in event.get("set_points", []): fx.points.append(Vector2i(point))
	for i in frame: fx.f44f370()
	var canvas := JoeyFxCanvas.new(owner, event, PackedStringArray(["eff_set_y", "eff_set_b", "eff_star0_y", "eff_star1_y", "eff_star0_b", "eff_star1_b"]))
	fx.f44f390(canvas, 0)

static func _explosion(owner: Node2D, event: Dictionary, counter: int) -> void:
	var center: Vector2 = event["center"]
	if counter > 31 and counter < 144:
		_asset(owner, "expl2", center, (counter + 96) * 256, mini(counter + 96, 255))
	if counter > 127 and counter < 208:
		var image := (counter * 5 - 640) / 64 + 2
		if image <= 6: _asset(owner, "expl%d" % (image + 1), center)
	if counter < 128:
		_asset(owner, "expl1", center, (counter + 128) * 256, mini(255, Math.cos_fx(counter - 64) >> 8), counter)

static func _break_card(owner: Node2D, event: Dictionary, counter: int) -> void:
	var center: Vector2 = event["center"]
	var radius := counter / 8
	for index in 5:
		var angle := index * 512 / 5
		# 4397c0 dibuja los cinco destellos con la vtable +ac: suman luz (ver _additive).
		_additive(_asset(owner, "shine", center + Vector2((Math.cos_fx(angle) * radius) >> 16, (Math.sin_fx(angle) * radius) >> 16), 65536, 255 - counter))
	if not event.has("break_texture"): return
	var texture: Texture2D = event["break_texture"]
	var size := Vector2i(texture.get_size())
	var progress := 256 - (Math.cos_fx(counter / 2 - 128) >> 8)
	var spread := size.x + size.y - (((size.x + size.y) * progress) >> 8)
	for y in range(0, size.y, 2):
		for x in range(0, size.x, 4):
			var dx := x - size.x / 2
			var dy := y - size.y / 2
			var distance := int(sqrt(dx * dx + dy * dy))
			if distance != 0:
				dx = Math.trunc_div(dx * 256, distance)
				dy = Math.trunc_div(dy * 256, distance)
			var row := y / 2
			var offset := Vector2((_break_noise[(row * 26 + x) & 255] * dx * spread) >> 16, (_break_noise[(row * 38 + 1 + x) & 255] * dy * spread) >> 16)
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.centered = false
			sprite.region_enabled = true
			sprite.region_rect = Rect2(x, y, mini(4, size.x - x), mini(2, size.y - y))
			sprite.position = center - Vector2(size / 2) + Vector2(x, y) + offset
			owner.add_child(sprite)

static func _shuffle(owner: Node2D, event: Dictionary, counter: int) -> void:
	var center := Vector2(525, 300)
	if counter > 63 and counter < 257:
		_asset(owner, "deck_shuf_waku_?", center)
		_asset(owner, "deck_shuf%d" % (counter / 8 % 5 + 1), Vector2(525, 326))
		return
	var transition := 320 - counter if counter > 256 else counter
	var weight := 256 - transition * 4
	var deck: Vector2 = event.get("deck_pos", Geometry.DECK[int(event.get("p", 0)) & 1])
	var pos := center + Vector2(Math.trunc_div(int(deck.x - center.x) * weight, 256), Math.trunc_div(int(deck.y - center.y) * weight, 256))
	_asset(owner, "deck_shuf_waku_?", pos, (128 + transition * 2) * 256, transition * 4)

static func _activation(owner: Node2D, event: Dictionary, counter: int) -> void:
	var large: bool = event.get("large_activation", true)
	var center: Vector2 = event["center"]
	var size: Vector2 = event.get("effect_size", Geometry.FIELD_SIZE)
	if large:
		counter -= 128
		var card_scale := (Math.cos_fx(counter) >> 9) if counter < 0 else 128
		var card_alpha := card_scale * 2 if counter < 256 else Math.cos_fx(counter - 256) >> 8
		_card(owner, event, center, Vector2(200, 290) * card_scale / 256.0, card_alpha)
		if counter < 0 or counter > 256: return
	else:
		_card(owner, event, center, event.get("card_size", size), 256, ((int(event.get("flags", 0)) & 1) + (int(event.get("p", 0)) & 1) * 2) * 128)
	var wave := Math.cos_fx(counter - 128)
	var color := "y" if event.get("monster", false) else "b"
	_asset(owner, "kouka_sita_" + color, center, wave, mini(255, wave >> 8), counter / 2)
	# El original dibuja el rectángulo blanco entre las dos capas (alpha wave>>9).
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([-size / 2, Vector2(size.x / 2, -size.y / 2), size / 2, Vector2(-size.x / 2, size.y / 2)])
	flash.position = center
	flash.color = Color(1, 1, 1, clampi(wave >> 9, 0, 256) / 256.0)
	owner.add_child(flash)
	_asset(owner, "kouka_ue_" + color, center, wave, mini(255, wave >> 8), counter)

static func _attack(owner: Node2D, event: Dictionary, counter: int) -> void:
	var source: Vector2 = event["from_pos"]
	var target: Vector2 = event["to_pos"]
	var direction := target - source
	# x87 fpatan + _ftol2 truncates the signed angle before interpolation.
	var angle := int(atan2(direction.x, -direction.y) * 256.0 / PI)
	if counter <= 128:
		var initial := 0
		var difference := angle
		if int(event.get("defender", 1)) == 0:
			initial = 256
			difference = int(-atan2(direction.x, direction.y) * 256.0 / PI)
		_asset(owner, "atk_icon", source, 65536, 256, initial + Math.trunc_div(difference * counter, 128))
	elif counter < 256:
		var weight := 256 - (Math.cos_fx(counter - 128) >> 8)
		var point := Math.interpolate(source, target, weight)
		_asset(owner, "atk_icon", point, 65536, 256, angle)
	elif counter < 512:
		var alpha := maxi(0, (512 - counter) * 2)
		_asset(owner, "atk_eff", target, (counter - 256) * 512, alpha)
		_asset(owner, "atk_icon2", target, 65536, alpha, angle)

static func _battle_result(owner: Node2D, event: Dictionary, frame: int) -> void:
	var shake_frame := frame
	if event.get("reflection", false):
		shake_frame -= 32
		if frame < 16:
			var size: Vector2 = event["reflection_size"]
			var center: Vector2 = event["to_pos"]
			var sprite := _asset(owner, "dmg_ref", center)
			if sprite:
				var image_size := sprite.texture.get_size()
				var counter := frame * 16
				var left := int(center.x) - int(size.x) / 2
				var right := left + int(size.x)
				var moving_left := Math.trunc_div((int(center.x) + int(size.x) / 2) * (256 - counter) + (left - int(image_size.x)) * counter, 256)
				var visible_left := maxi(left, moving_left)
				var visible_right := mini(right, moving_left + int(image_size.x))
				if visible_right <= visible_left:
					sprite.free()
				else:
					sprite.region_enabled = true
					var visible_height := mini(int(size.y), int(image_size.y))
					var crop_y := maxi(0, (int(image_size.y) - visible_height) / 2)
					sprite.region_rect = Rect2(visible_left - moving_left, crop_y, visible_right - visible_left, visible_height)
					sprite.position = Vector2((visible_left + visible_right) / 2.0, center.y)
	if shake_frame < 0: return
	if shake_frame < 16:
		var value := 16 - shake_frame
		if value & 1: value = -value
		var offset := Math.trunc_div(value, 2)
		for card in event.get("shake_cards", []):
			_card(owner, card, card["pos"] + Vector2(offset, 0), Geometry.FIELD_SIZE, 256, card["angle"], card["face"])
	if not event.get("draw_damage", true): return
	for side in 2:
		var damage: int = event["damage"][side]
		if damage == 0: continue
		var zone: int = event["source_zone"] if side == event["p"] else event["target_zone"]
		if event["target_zone"] == -1: zone = -1
		var pos := Geometry.zone(side, 7) if zone < 0 else Geometry.zone(side, zone)
		_damage_number(owner, -damage, pos, shake_frame * 16)

static func _damage_number(owner: Node2D, amount: int, center: Vector2, progress: int) -> void:
	# 45d890 and460790: native12glyph bitmap, right-to-left staggered bounce.
	var digits := str(absi(amount))
	var count := digits.length() + 1
	var step := Math.trunc_div(64, count - 1)
	var sprite: Sprite2D = owner._asset("damage00" if amount < 0 else "damage01", center, 1, 1, 0, "font")
	if sprite == null: return
	var texture: Texture2D = sprite.texture
	sprite.free()
	var width := int(texture.get_width()) / 12
	var height := texture.get_height()
	var right := int(center.x) + count * width / 2
	var top := int(center.y) - height / 2
	for index in count:
		var value := progress - index * step
		right -= width
		if value < 0: continue
		var y := top
		if value < 128:
			y -= (Math.cos_fx(value * 2 - 128) * height) >> 16
		elif value < 192:
			y -= (Math.cos_fx(value * 4 - 128) * (height / 4)) >> 16
		var glyph := int(digits[digits.length() - index - 1]) if index < digits.length() else 11 if amount < 0 else 10
		var digit := Sprite2D.new()
		# Las cifras quedan por encima de la carta sacudida y del vuelo al cementerio.
		digit.z_index = 100
		digit.texture = texture
		digit.centered = false
		digit.region_enabled = true
		digit.region_rect = Rect2(glyph * width, 0, width, height)
		digit.position = Vector2(right, y)
		owner.add_child(digit)

static func _banner(owner: Node2D, event: Dictionary, frame: int) -> void:
	var start: bool = int(event.get("op", 0)) == 0x14
	var counter := frame * (8 if start else 4)
	if start and event.get("game", "yugi") == "kaiba":
		var sprite := _asset(owner, event.get("asset", "duel_start_?"), Vector2(400,300))
		if sprite != null:
			var plan := kaiba_start_banner(counter, Vector2i(sprite.texture.get_size()))
			sprite.centered = false
			sprite.position = Vector2(plan.x, plan.y)
			sprite.scale = Vector2(plan.width, plan.height) / sprite.texture.get_size()
			sprite.modulate.a = clampi(plan.alpha, 0, 256) / 256.0
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return
	var scale := 65536
	var alpha := 255
	if start:
		if counter < 64:
			# 439a70 ASM: escala (256 + trunc(trunc(T[2c]/256)/2))/256.
			if event.get("game", "yugi") != "kaiba":
				scale = (256 + Math.trunc_div(Math.trunc_div(Math.cos_fx(counter * 2), 256), 2)) * 256
			alpha = Math.cos_fx(counter * 2 - 128) >> 8
		elif counter > 256:
			alpha = Math.cos_fx(counter * 2) >> 8
	else:
		# 0x439bd0: aparece en 0x80 y se queda opaco (el contador no pasa de 0x200).
		if counter < 128: alpha = Math.cos_fx(counter - 128) >> 8
	_asset(owner, event.get("asset", "duel_start_?"), Vector2(400, 300), scale, alpha)

##43a1b0 ASM43a1f0..43a2df: zoom inicial, dimensiones truncadas y ancla entera.
## El decompilado omite este calculo; kaiba_start_banner_oracle.py ejecuta el PE.
static func kaiba_start_banner(counter: int, source: Vector2i) -> Dictionary:
	var scale := 256
	if counter < 64: scale += Math.trunc_div(Math.trunc_div(Math.cos_fx(counter * 2), 256), 2)
	var width := Math.trunc_div(source.x * scale, 256)
	var height := Math.trunc_div(source.y * scale, 256)
	var alpha := 256
	if counter < 64: alpha = Math.cos_fx(counter * 2 - 128) >> 8
	elif counter > 256: alpha = Math.cos_fx(counter * 2) >> 8
	return {"x":400-width/2, "y":300-height/2, "width":width, "height":height, "alpha":alpha}

static func _special(owner: Node2D, event: Dictionary, counter: int) -> void:
	var center: Vector2 = event["center"]
	# El último cuadro ya no tiene distorsión; el núcleo escribe la zona después de la espera.
	if counter >= 320:
		var flags: int = event.get("flags", 0)
		_card(owner, event, center, Geometry.FIELD_SIZE, 256, ((flags & 1) + int(event.get("p", 0)) * 2) * 128, bool(flags & 2))
	if counter > 63 and counter < 320 and event.has("special_texture"):
		var texture: Texture2D = event["special_texture"]
		if _white_card == null:
			_white_card = Shader.new()
			_white_card.code = "shader_type canvas_item; void fragment() { vec4 c = texture(TEXTURE, UV); COLOR = vec4(mix(c.rgb, vec3(1.0), 0.25), c.a); }"
		var material := ShaderMaterial.new()
		material.shader = _white_card
		var rows: PackedInt32Array = event["special_jitters"][counter / 8]
		var size := texture.get_size()
		for row in int(size.y):
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.material = material
			sprite.region_enabled = true
			sprite.region_filter_clip_enabled = true
			sprite.region_rect = Rect2(0, row, size.x, 1)
			sprite.position = center - size / 2 + Vector2(size.x / 2 + rows[row], row + 0.5)
			owner.add_child(sprite)
	if counter < 192:
		var color := "d" if int(event.get("flags", 0)) & 1 else "a"
		_asset(owner, "sp_sum_%s%d" % [color, counter / 16 % 4 + 1], center, 65536, mini(255, Math.cos_fx(counter - 96) >> 8))

static func _hand_shuffle(owner: Node2D, event: Dictionary, frame: int) -> void:
	var cards: Array = event.get("hand_cards", [])
	var positions: Array = event.get("hand_frames", [])[mini(frame, 32)]
	var p: int = int(event.get("p", 0)) & 1
	for index in cards.size():
		var card := event.duplicate()
		card["card"] = cards[index]
		_card(owner, card, positions[index], Geometry.HAND_SIZE, 256, p * 256, p == 0 or not owner.hidden_hand)
