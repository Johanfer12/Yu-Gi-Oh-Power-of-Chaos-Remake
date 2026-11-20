extends RefCounted
## Kaiba42f3d0 / Yugi42f0e0: dibujo de pilas ejecutado en classic_pile_oracle.py.
static func base_position(p: int, loc: int) -> Vector2:
	return DuelGeometry.location(p, loc)

## 42efb0: estados de barajado, cambio de cima, vuelta y resaltado.
static func start(pile: Dictionary, state: int, value := -1) -> void:
	pile["animation_state"] = state
	pile["animation_counter"] = 0x140 if state == 5 else 8 if state == 8 else 0
	pile["animation_value"] = value


static func tick(pile: Dictionary) -> bool:
	var state := int(pile.get("animation_state", 0))
	if state == 0: return false
	var counter := int(pile["animation_counter"])
	counter += -8 if state == 5 else -1 if state == 8 else 0x20
	if counter <= 0 or counter >= 0x100 and state in [6, 7]:
		if state == 6: pile["top"] = int(pile["animation_value"])
		if state == 7: pile["face"] = not bool(pile.get("face", false))
		pile.erase("animation_state")
		pile.erase("animation_counter")
		pile.erase("animation_value")
	else:
		pile["animation_counter"] = counter
	return true


static func visible_count(pile: Dictionary) -> int:
	var count := int(pile["count"])
	if int(pile.get("animation_state", 0)) != 5: return count
	var counter := int(pile["animation_counter"])
	if counter < 0x40: return (count * (0x40 - counter)) >> 6
	if counter < 0x100: return 0
	return (count * (counter - 0x100)) >> 6

## Yugi442130 / Kaiba442740: base o superficie segun indice de referencia.
static func object_position(p: int, loc: int, index: int, count: int) -> Vector2:
	var base := base_position(p, loc)
	if (loc == 13 and index != 0) or (loc != 13 and index == 0): return base
	var depth := 10 if count >= 40 else (count - 1) / 4
	return base + Vector2(depth if base.x > 400 else -depth, -depth)

static func plan(p: int, loc: int, count: int) -> Dictionary:
	if count <= 0: return {"top": [], "draws": [], "counter": []}
	var base := base_position(p, loc)
	var depth := 10 if count >= 40 else (count - 1) / 4
	var left := int(base.x) - 25
	var upper := int(base.y) - 36
	var right := base.x > 400
	var wall := [10 - depth, 0, 60, 72 + depth] if right else [60, 0, 110 + depth, 72 + depth]
	var shadow := [0, 72 - depth, 50 + depth, 72 + depth] if right else [0, 0, 50 + depth, 72 + depth]
	return {"counter": [int(base.x) + 7, int(base.y) + 36] if loc in [13, 14] else [], "top": [int(base.x) + (depth if right else -depth), int(base.y) - depth], "draws": [
		{"texture": 1, "x": left, "y": upper + 72 - depth if right else upper, "rect": shadow, "alpha": 128},
		{"texture": 2 if loc == 14 else 0, "x": left if right else left - depth, "y": upper - depth, "rect": wall, "alpha": 256}]}

static func draw(owner: Node2D, textures: Array, p: int, loc: int, count: int) -> Vector2:
	var state := plan(p, loc, count)
	for row in state.draws:
		var sprite := Sprite2D.new()
		sprite.texture = textures[row.texture]
		sprite.centered = false
		sprite.region_enabled = true
		var r: Array = row.rect
		sprite.region_rect = Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])
		sprite.position = Vector2(row.x, row.y)
		sprite.modulate.a = float(row.alpha) / 256.0
		owner.add_child(sprite)
	return Vector2(state.top[0], state.top[1]) if not state.top.is_empty() else Vector2.ZERO
