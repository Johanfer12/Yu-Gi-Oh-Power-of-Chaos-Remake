extends RefCounted

## 43d630/43d670: el contador empieza en 0x100 y baja ocho por tick.
static func excluded_flash(pile: Dictionary, tick: int) -> bool:
	if not pile.has("flash_tick"): return false
	var counter := 0x100 - (tick - int(pile["flash_tick"])) * 8
	return counter > 0 and counter < 0x80 and (counter & 0x10) != 0

##43c980: caras laterales y sombra; una sola carta superior, no cartas repetidas.
static func base_position(p: int, loc: int) -> Vector2:
	var base := Vector2(284, 460) if p == 0 else Vector2(766, 140)
	if loc == 13: base = Vector2(760, 460) if p == 0 else Vector2(290, 140)
	if loc == 14: base = Vector2(760, 366) if p == 0 else Vector2(290, 234)
	return base

## 45c140: el indice de la referencia distingue la base y la superficie de pila.
## El mazo usa profundidad con indice0; fusion/cementerio con indice distinto de0.
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
