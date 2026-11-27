extends Node2D
## Joey4497d0/449850: diez estados de3 bits; entrada1..7, dibujo chinka[q/2].
## El adaptador de Joey consulta los bloqueos nativos con 569e10. Las repeticiones
## con motor compartido leen las marcas y los vínculos de su propio estado.
var states := PackedInt32Array()
var _sprites: Array[Sprite2D] = []
var _textures: Array[Texture2D] = []
var _last_tick := -1

func _init() -> void:
	states.resize(10)
	for index in 10:
		var sprite := Sprite2D.new()
		sprite.position = DuelGeometry.zone(index / 5, index % 5)
		sprite.visible = false
		add_child(sprite)
		_sprites.append(sprite)

func _ready() -> void:
	for index in 4: _textures.append(Assets.texture("joey/duel/effect/chinka%d.yga" % (index + 1)))

static func blocked(duel: Duel, p: int, z: int) -> bool:
	if duel is JoeyPresentationAdapter:
		return duel.engine.f569e10(p ^ duel.local_native_player, z) == 0
	if (duel.m.u8(DuelMem.pl(p) + 0x12) & (1 << z)) != 0: return true
	var at := DuelMem.zone(p, z)
	for index in duel.m.u16(at + 0x88):
		if duel.m.u8(at + 0x48 + index * 2) != 2: continue
		var link := duel.m.u16(at + 8 + index * 2)
		var source := DuelMem.zone(link & 1, (link >> 8) & 255)
		var card := duel.m.u16(source) & 4095
		if card == 0 or duel.cards.id_of(card) != 0x528: continue
		# 569e10: Colapso del terreno boca arriba, sin bits de anulacion1/5.
		var flags := duel.m.u8(source + 0x90)
		if (duel.m.u8(source + 6) & 2) != 0 and (flags & 0x22) == 0: return true
	return false

static func mask_for(duel: Duel) -> int:
	var mask := 0
	for p in 2:
		for z in 5:
			if blocked(duel, p, z): mask |= 1 << (p * 5 + z)
	return mask

func refresh(duel: Duel, tick: int) -> void:
	var elapsed := maxi(0, tick - _last_tick) if _last_tick >= 0 else 0
	if tick < _last_tick: states.fill(0)
	_last_tick = tick
	var mask := mask_for(duel)
	for index in 10:
		var enabled := (mask & (1 << index)) != 0
		if not enabled: states[index] = 0
		elif states[index] == 0: states[index] = 1
		else: states[index] = mini(7, states[index] + elapsed)
		_sprites[index].visible = enabled
		if enabled and _textures.size() == 4: _sprites[index].texture = _textures[states[index] / 2]
