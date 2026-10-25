class_name DuelGeometry
extends RefCounted
## Coordenadas absolutas del PE (59ba98..59bbb8), viewport original800x600.
const FIELD_X := 230
const FIELD_SIZE := Vector2(50, 72)
const HAND_SIZE := Vector2(100, 145)
const PREVIEW_RECT := Rect2(5, 72, 200, 290)
const COLUMNS := [369, 447, 525, 603, 681]
const DECK := [Vector2(760, 460), Vector2(290, 140)]
const GRAVE := [Vector2(760, 360), Vector2(290, 240)]

## 540a90 usa200x290 antes de reducir la carta de mano a100x145.
static func hand_cursor_offset(p: int) -> Vector2:
	return Vector2(-50, -72) if p == 0 else Vector2(49, 71)

## Joey 45c280 (tabla 5db5e0) coloca la zona de campo aparte; Yugi y Kaiba comparten la suya.
const JOEY_FIELD := [Vector2(286, 353), Vector2(766, 236)]

static func zone(p: int, z: int, game := "") -> Vector2:
	if z == 10:
		if game == "joey": return JOEY_FIELD[p]
		return Vector2(290, 360) if p == 0 else Vector2(760, 240)
	var column := z if z < 5 else z - 5
	if p == 1: column = 4 - column
	return Vector2(COLUMNS[column], [352, 248][p] if z < 5 else [460, 140][p])

static func hand(p: int, i: int, count: int, raised: bool = false) -> Vector2:
	# 441de0: ancho original/2, centro525 y separación limitada a512.
	var span := mini((int(HAND_SIZE.x) + 8) * count, 512) - int(HAND_SIZE.x)
	var x := 525 - span / 2 * (1 if p == 0 else -1)
	if count > 1: x += (span * i / (count - 1)) * (1 if p == 0 else -1)
	return Vector2(x, (600 if p == 0 else 0) + (-32 if p == 0 else 32) * int(raised))

static func location(p: int, loc: int, i: int = 0, count: int = 1) -> Vector2:
	if loc < 11: return zone(p, loc + i if loc in [0, 5] else loc)
	if loc == 11: return hand(p, i, count)
	if loc == 12: return Vector2(290, 460) if p == 0 else Vector2(760, 140)
	if loc == 13: return DECK[p]
	if loc == 14: return GRAVE[p]
	if loc == 15: return Vector2(760, 298) if p == 0 else Vector2(290, 302)
	return Vector2(525, 300)

static func packed(value: int, duel: Duel) -> Vector2:
	var p := value & 1
	return location(p, (value >> 1) & 15, (value >> 5) & 511, duel.m.u8(DuelMem.pl(p) + 2))
