extends Node2D
## Tablero del match (duel/match/match.txt). Dibujo Yugi 433090 y Kaiba 433620.
## Detalle en docs/duel/POST_DUELO.md, apartado 2. Lo crea la escena de resultado en
## el estado 5 de 0x435410 tras cada duelo del match; acaba cuando `active` pasa a false.
##   0: el tablero aparece hasta c == 0x20. Kaiba aplica alfa y las otras variantes escalan.
##   1: las marcas del ultimo duelo parpadean (4 pasos si, 4 no) durante 0x20; si el
##      match esta decidido -> 2; si no, espera clic o decidir y se desactiva.
##   2: el rotulo WIN/LOSE/DRAW entra (p = c * 8). En Kaiba el tablero queda fijo.
##   3: reposo; clic o decidir: si gana el match -> 4, si no se desactiva.
##   4: el tablero se desvanece en Kaiba y se pliega en las otras variantes.

const CENTER := Vector2(400, 300)
const MARK_ANCHORS := [Vector2(0.5, 0.5), Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2.ONE]

var game := "yugi"
var active := true
var results := [0, 0, 0]   # DAT_005af768
var duels := 1             # DAT_005af76b
var outcome := 0           # DAT_005af764
var _layout: Layout
var _tex: Array[Texture2D] = []
var _state := 0
var _c := 0
var _clicked := false
var _shake := Vector2.ZERO
var _kaiba_board: CanvasGroup
var _kaiba_base: Node2D
var _kaiba_pulse: Node2D
## Escala, caida y rotulo mezclados entre ticks (el temblor es al azar: no se mezcla).
var _blend := NativeBlend.new()


func setup(game_id: String, match_results: Array, duel_count: int, match_outcome: int) -> void:
	game = game_id
	results = match_results.duplicate()
	duels = duel_count
	outcome = match_outcome
	z_index = 75


func _ready() -> void:
	_layout = Assets.layout("%s/duel/match/match.txt" % game)
	for i in _layout.items.size():
		_tex.append(Assets.texture("%s/duel/match/%s" % [game, _layout.resource(i)]))
	if game == "kaiba":
		# 4335c0 compone las marcas en la superficie del tablero antes del fundido.
		_kaiba_board = CanvasGroup.new()
		_kaiba_board.show_behind_parent = true
		_kaiba_board.self_modulate.a = _scale() / 256.0
		add_child(_kaiba_board)
		_kaiba_base = Node2D.new()
		_kaiba_base.draw.connect(_draw_kaiba_board)
		_kaiba_board.add_child(_kaiba_base)
		_kaiba_pulse = Node2D.new()
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_kaiba_pulse.material = additive
		_kaiba_pulse.draw.connect(_draw_kaiba_pulse)
		add_child(_kaiba_pulse)


func click() -> void:
	_clicked = true


func _v(i: int) -> int:
	return str(_layout.value(i)).to_int() if _layout.value(i) != null else 0


## Un paso del dibujo 0x433090 (la maquina de estados vive en el dibujo).
func step() -> void:
	if not active:
		return
	_blend.tick()
	_c += 1
	match _state:
		0:
			if _c == 0x20:
				_next(1)
		1:
			if _c >= 0x20:
				if outcome != 0:
					_next(2)
				elif _clicked:
					active = false
		2:
			if _c == 0x20:
				_next(3)
		3:
			if _clicked:
				if outcome == 1:
					_next(4)
				else:
					active = false
		4:
			if _c == 0x20:
				active = false
	_clicked = false
	var p := _progress()
	# 0x432eb0: x antes que y, del MT de interfaz.
	if game != "kaiba" and p >= 0x40 and p <= 0x80:
		var x := 0x188 + UiRandom.draw() % 17
		_shake = Vector2(x, 0x124 + UiRandom.draw() % 17)
	else:
		_shake = CENTER
	queue_redraw()
	if _kaiba_board != null:
		_update_kaiba_board_opacity()
		_kaiba_pulse.queue_redraw()


## La escena de resultado lo avanza con su reloj: entre ticks se dibuja con lo que le queda.
func show_between(fraction: float) -> void:
	_blend.fraction = fraction
	if _kaiba_board != null:
		_update_kaiba_board_opacity()
	queue_redraw()


func _next(state: int) -> void:
	_state = state
	_c = 0


func _progress() -> int:
	match _state:
		2: return _c * 8
		3, 4: return 0x100
	return 0


func _scale() -> int:
	match _state:
		0: return DuelVisualMath.cos_fx((4 * _c - 0x80) & 0x1ff) >> 8
		4: return DuelVisualMath.cos_fx((_c & 0x7f) * 4) >> 8
	return 0x100


func _draw() -> void:
	if not active or _tex.is_empty():
		return
	var p := _progress()
	var d := 0.0
	if game != "kaiba":
		var center := _shake
		if p > 0x80:
			d = _blend.at("drop", p - 0x80)
			center = CENTER + Vector2(0, floorf(d / 2))
		var k: float = _blend.at("scale", _scale() / 256.0)
		var size := _tex[0].get_size() * k
		var top_left := center - size / 2
		draw_texture_rect(_tex[0], Rect2(top_left, size), false)
		for i in duels:
			_marks(self, top_left, k, i, 1.0)
		if _marks_pulse():
			_marks(self, top_left, k, duels - 1, 0x40 / 256.0)
	if p != 0 and outcome >= 1 and outcome <= 3:
		var label := _tex[outcome + 4 + _extra()]
		if game == "kaiba":
			var region := _kaiba_label_region(label.get_size(), p, _scale())
			var rect: Rect2 = _blend.at("kaiba_label_rect", region[0])
			var alpha: float = _blend.at("kaiba_label_alpha", region[1])
			draw_texture_rect(label, rect, false, Color(1.0, 1.0, 1.0, alpha))
			return
		var text_scale := 0x100
		if p < 0x40:
			text_scale = 0x180 - (DuelVisualMath.cos_fx((2 * p - 0x80) & 0x1ff) >> 9)
		var ls: Vector2 = label.get_size() * _blend.at("label", text_scale) / 256.0
		draw_texture_rect(label, Rect2(Vector2(400 - ls.x / 2, 300 - ls.y / 2 - d), ls), false)


## 4334a0: conserva el ancho, escala la altura y mezcla el rótulo en el centro.
static func _kaiba_label_region(size: Vector2, p: int, board_scale: int) -> Array:
	var height := int(size.y)
	var opacity := 0x100
	if p < 0x40:
		var wave := DuelVisualMath.cos_fx(2 * p - 0x80)
		height = height * (wave >> 8) >> 8
		opacity = 0x80 + (wave >> 9)
	elif p > 0x80:
		opacity = (0x100 + 3 * (0x80 - p) / 2) * board_scale >> 8
	var scaled_size := Vector2(size.x, height)
	return [Rect2(CENTER - (scaled_size / 2).floor(), scaled_size), opacity / 256.0]


func _update_kaiba_board_opacity() -> void:
	_kaiba_board.visible = active
	_kaiba_board.self_modulate.a = _blend.at("kaiba_board_alpha", _scale() / 256.0)


func _draw_kaiba_board() -> void:
	var top_left := CENTER - (_tex[0].get_size() / 2).floor()
	_kaiba_base.draw_texture(_tex[0], top_left)
	for i in duels:
		_marks(_kaiba_base, top_left, 1.0, i, 1.0)


func _marks_pulse() -> bool:
	return active and _state == 1 and _c < 0x20 and (_c & 4) == 0


## 433620 / 4f6dd0: la marca del último duelo recibe una pasada aditiva.
func _draw_kaiba_pulse() -> void:
	if _marks_pulse():
		var top_left := CENTER - (_tex[0].get_size() / 2).floor()
		_marks(_kaiba_pulse, top_left, 1.0, duels - 1, 0x20 / 256.0)


func _marks(target: CanvasItem, top_left: Vector2, k: float, i: int, alpha: float) -> void:
	if i < 0 or i >= 3:
		return
	var pos := Vector2(_v(1) + (_v(3) % 1000) * i, _v(2))
	var row := Vector2(0, _v(4) % 1000)
	if game == "kaiba":
		# 433300: los dos grupos de tres dígitos codifican los desplazamientos.
		pos.y += (_v(3) / 1000) * i
		row.x = _v(4) / 1000
	# Yugi/Kaiba: pwin, cwin, lose, draw. Joey añade close_m (PIERDES rosa de la fila rival)
	# tras plose_m (azul, fila propia), asi que draw y los rotulos van un indice despues.
	var extra := _extra()
	match int(results[i]):
		1:
			_mark(target, 3 + extra, top_left, pos, k, alpha)
			_mark(target, 1, top_left, pos + row, k, alpha)
		2:
			_mark(target, 2, top_left, pos, k, alpha)
			_mark(target, 3, top_left, pos + row, k, alpha)
		3:
			if game == "kaiba":
				_mark(target, 4, top_left, pos, k, alpha)
				_mark(target, 4, top_left, pos + row, k, alpha)
			else:
				_mark(target, 4 + extra, top_left, pos + Vector2(0, int(row.y) / 2), k, alpha)


## 1 si el layout trae close_m (Joey), 0 si no.
func _extra() -> int:
	return 1 if _layout != null and _layout.index_of("close_m_?.bmp") >= 0 else 0


func _mark(target: CanvasItem, index: int, top_left: Vector2, center: Vector2, k: float, alpha: float) -> void:
	var tex := _tex[index]
	var size := tex.get_size() * k
	var offset := size / 2
	if game == "kaiba":
		var mode := _v(0)
		offset = (tex.get_size() * MARK_ANCHORS[mode]).floor() * k if mode >= 0 and mode < MARK_ANCHORS.size() else Vector2.ZERO
	target.draw_texture_rect(tex, Rect2(top_left + center * k - offset, size), false, Color(1, 1, 1, alpha))
