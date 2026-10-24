extends Node2D
## 460120: puntero original; 45fff0/45ff20 movimiento; 438d00/439c60 onda.
## Coordenadas locales800x600. No escribe memoria ni RNG del duelo.
## Lineas de common/cursor/cursor_<idioma>.txt (lista +0x70 de 460120): recurso y punto activo
## XXXYYY de cada icono. Cambian con el idioma: en ingles y japones los iconos miden 64x64
## (punto 7,14; rendirse 43,15) y en los demas 80x80 (7,30; rendirse 60,30); el espanol usa
## ademas cursor_e_over. Si faltara el archivo, valores del ingles.
const RESOURCES := ["cursor_pow.yga", "cursor00.yga", "cursor01.yga", "cursor_?_summon.yga", "cursor_?_flip.yga", "cursor_?_atk.yga", "cursor_?_act.yga", "cursor_?_set.yga", "cursor_?_setdef.yga", "cursor_?_setatk.yga", "cursor_?_draw.yga", "cursor_?_surrender.yga", "cursor_?_fusion.yga", "cursor_ssummon_a.yga", "cursor_ssummon_d.yga", "cursor_?_over.yga"]
const HOTSPOTS := [Vector2.ZERO, Vector2(7, 14), Vector2(7, 14), Vector2(7, 14), Vector2(7, 14), Vector2(7, 14), Vector2(7, 14), Vector2(7, 14), Vector2(7, 14), Vector2(7, 14), Vector2(7, 14), Vector2(43, 15), Vector2(7, 14), Vector2(7, 30), Vector2(7, 30), Vector2(7, 14)]
static var _entries: Array = []
var pointer_position := Vector2(525, 300)
var hovered := false
var action := -1
var pressed := false
var _sprite := Sprite2D.new()
var _waves: Array[Dictionary] = []
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _move_tick := 6
var _fraction := 0.0
var _scripted := false
## Movimiento por ticks (move_to o PointerGlide): se dibuja mezclado entre ticks. El raton
## fisico se dibuja donde esta.
var _tick_driven := false
var _blend := NativeBlend.new()
static var _mouse_owners := 0
static var _original_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _owns_mouse := false
var hide_system_mouse := true
var show_pointer := not OS.has_feature("mobile")

func _ready() -> void:
	z_index = 4000
	visible = show_pointer
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	if hide_system_mouse:
		if _mouse_owners == 0: _original_mouse_mode = Input.mouse_mode
		_mouse_owners += 1
		_owns_mouse = true
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_refresh()

func _exit_tree() -> void:
	if _owns_mouse:
		_mouse_owners -= 1
		_owns_mouse = false
		if _mouse_owners == 0: Input.mouse_mode = _original_mouse_mode

static func resource_index(action_id: int, is_pressed: bool) -> int:
	return action_id + 2 if action_id in range(1, 14) else 2 if is_pressed else 1

static func entries() -> Array:
	if not _entries.is_empty(): return _entries
	var path: String = Assets.resolve("common/cursor/cursor_?.txt")
	if path != "":
		for line in FileAccess.get_file_as_bytes(path).get_string_from_ascii().split("\n"):
			var tokens := line.split("//")[0].strip_edges().split("\t", false)
			if tokens.is_empty() or not tokens[0].ends_with(".yga"): continue
			var value := tokens[1].strip_edges().to_int() if tokens.size() > 1 else 0
			_entries.append([tokens[0].strip_edges(), Vector2(value / 1000, value % 1000)])
	if _entries.size() != RESOURCES.size():
		_entries.clear()
		for i in RESOURCES.size(): _entries.append([RESOURCES[i], HOTSPOTS[i]])
	return _entries

static func hotspot(index: int) -> Vector2:
	return entries()[index][1]

static func resource(index: int) -> String:
	return entries()[index][0]

static func move_position(start: Vector2, target: Vector2, tick: int) -> Vector2:
	var phase := mini(6, maxi(0, tick)) * 128 / 6
	return DuelVisualMath.interpolate_fx(start, target, DuelVisualMath.cos_fx(phase - 128))

func update(pos: Vector2, is_hovered: bool, action_id: int = -1, is_pressed: bool = false) -> void:
	# Un movimiento físico interrumpe la interpolación programada (460060/45ff70).
	if pos != pointer_position:
		_scripted = false
		_move_tick = 6
		_tick_driven = PointerGlide.drove(pos)
		pointer_position = pos
	hovered = is_hovered
	action = action_id if is_hovered else -1
	pressed = is_pressed
	_refresh()

func move_to(pos: Vector2) -> void:
	_from = pointer_position
	_to = pos
	_move_tick = 0
	_scripted = true
	_tick_driven = true
	visible = show_pointer
	_refresh()

func click(pos: Vector2 = pointer_position, from_input := false) -> void:
	if not show_pointer: return
	var sprite := Sprite2D.new()
	sprite.centered = false
	# 460120 dibuja las ondas existentes antes del puntero.
	sprite.show_behind_parent = true
	sprite.texture = Assets.texture("common/cursor/cursor_pow.yga")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	copy.show_behind_parent = true
	sprite.add_child(copy)
	var material := ShaderMaterial.new()
	material.shader = preload("res://scenes/duel/cursor_wave.gdshader")
	sprite.material = material
	sprite.position = pos
	add_child(sprite)
	_waves.append({"sprite": sprite, "counter": 0, "origin": pos, "skip_first_tick": from_input})
	_refresh_wave(_waves.back())

func advance(delta: float) -> void:
	_blend.restore()
	_fraction += NativeClock.ticks(delta)
	var ticks := int(_fraction)
	_fraction -= ticks
	for _i in ticks: _blend.tick()
	_blend.fraction = _fraction
	if _scripted:
		_move_tick = mini(6, _move_tick + ticks)
		pointer_position = move_position(_from, _to, _move_tick)
	for i in range(_waves.size() - 1, -1, -1):
		# 460120 registra el clic de entrada después de actualizar/dibujar existentes.
		var wave_ticks := ticks
		if ticks > 0 and _waves[i]["skip_first_tick"]:
			wave_ticks -= 1
			_waves[i]["skip_first_tick"] = false
		_waves[i]["counter"] += wave_ticks * 16
		if _waves[i]["counter"] >= 256:
			_waves[i]["sprite"].free()
			_waves.remove_at(i)
		else: _refresh_wave(_waves[i])
	_refresh()
	_blend.nodes(_waves.map(func(w: Dictionary) -> Sprite2D: return w["sprite"]))


## Quien avanza el puntero por ticks enteros (repeticiones) dibuja con su propio reloj.
func show_between(fraction: float) -> void:
	_blend.restore()
	_blend.fraction = fraction
	_refresh()
	_blend.nodes(_waves.map(func(w: Dictionary) -> Sprite2D: return w["sprite"]))

func event(e: Dictionary, duel: Duel) -> bool:
	var kind := str(e.get("kind", ""))
	if kind not in ["cursor", "tutorial_wait_cursor"]: return false
	if kind == "tutorial_wait_cursor" and duel.tutorial_interactive: return false
	var p := int(e.get("p", 0)) & 1
	var loc := int(e.get("loc", 0))
	var index := int(e.get("i", e.get("index", 0)))
	# 53f7e0 convierte posiciones5..9 de location0 en location5;10 en campo.
	if loc == 0 and index == 10:
		loc = 10
		index = 0
	elif loc == 0 and index > 4:
		loc = 5
		index -= 5
	var target := duel.card_screen_position(p, loc, index)
	if loc == 11:
		target += DuelGeometry.hand_cursor_offset(p)
	move_to(target)
	if kind == "tutorial_wait_cursor" and int(e.get("button", 0)) == 1: click(target)
	return true

func _refresh() -> void:
	var index := resource_index(action, pressed)
	var path: String = "common/cursor/" + resource(index)
	_sprite.texture = Assets.texture(path) if Assets.exists(path) else null
	var shown: Vector2 = _blend.at("pointer", pointer_position)
	_sprite.position = (shown if _tick_driven else pointer_position) - hotspot(index)

func _refresh_wave(wave: Dictionary) -> void:
	var sprite: Sprite2D = wave["sprite"]
	if sprite.texture == null: return
	var counter: int = wave["counter"]
	var size := sprite.texture.get_size()
	var scaled := Vector2(int(size.x) * counter >> 8, int(size.y) * counter >> 8)
	sprite.position = Vector2(wave["origin"]) - Vector2(int(scaled.x) / 2, int(scaled.y) / 2)
	sprite.scale = scaled / size
	sprite.modulate.a = mini(255, DuelVisualMath.cos_fx(counter / 2) >> 8) / 255.0
