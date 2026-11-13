extends Node2D
## Tablero del match (duel/match/match.txt, constructor 0x434810, update 0x433030, dibujo
## 0x433090). Detalle en docs/duel/POST_DUELO.md, apartado 2. Lo crea la escena de resultado en
## el estado 5 de 0x435410 tras cada duelo del match; acaba cuando `active` pasa a false.
##   0: aparece con escala cos_fx((4c - 0x80) & 0x1ff) >> 8 hasta c == 0x20.
##   1: las marcas del ultimo duelo parpadean (4 pasos si, 4 no) con 0x40 durante 0x20; si el
##      match esta decidido -> 2; si no, espera clic o decidir y se desactiva.
##   2: el rotulo WIN/LOSE/DRAW entra (p = c * 8) con el tablero temblando y bajando.
##   3: reposo; clic o decidir: si gana el match -> 4, si no se desactiva.
##   4: el tablero se pliega (cos_fx((c & 0x7f) * 4) >> 8) y se desactiva a 0x20.

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
	if p >= 0x40 and p <= 0x80:
		var x := 0x188 + UiRandom.draw() % 17
		_shake = Vector2(x, 0x124 + UiRandom.draw() % 17)
	else:
		_shake = Vector2(400, 300)
	queue_redraw()


## La escena de resultado lo avanza con su reloj: entre ticks se dibuja con lo que le queda.
func show_between(fraction: float) -> void:
	_blend.fraction = fraction
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
	var board := _tex[0]
	var p := _progress()
	var center := _shake
	var d := 0.0
	if p > 0x80:
		d = _blend.at("drop", p - 0x80)
		center = Vector2(400, 300 + floorf(d / 2))
	var k: float = _blend.at("scale", _scale() / 256.0)
	var size := board.get_size() * k
	var top_left := center - size / 2
	draw_texture_rect(board, Rect2(top_left, size), false)
	# 0x433030: marcas de los duelos jugados dentro del tablero (centradas en su punto).
	for i in duels:
		_marks(top_left, k, i, 1.0)
	if _state == 1 and _c < 0x20 and (_c & 4) == 0:
		_marks(top_left, k, duels - 1, 0x40 / 256.0)
	if p != 0 and outcome >= 1 and outcome <= 3:
		var label := _tex[outcome + 4 + _extra()]
		var text_scale := 0x100
		if p < 0x40:
			text_scale = 0x180 - (DuelVisualMath.cos_fx((2 * p - 0x80) & 0x1ff) >> 9)
		var ls: Vector2 = label.get_size() * _blend.at("label", text_scale) / 256.0
		draw_texture_rect(label, Rect2(Vector2(400 - ls.x / 2, 300 - ls.y / 2 - d), ls), false)


func _marks(top_left: Vector2, k: float, i: int, alpha: float) -> void:
	if i < 0 or i >= 3:
		return
	var x := _v(1) + (_v(3) % 1000) * i
	var y := _v(2)
	var row := _v(4) % 1000
	# Yugi/Kaiba: pwin, cwin, lose, draw. Joey añade close_m (PIERDES rosa de la fila rival)
	# tras plose_m (azul, fila propia), asi que draw y los rotulos van un indice despues.
	var extra := _extra()
	match int(results[i]):
		1:
			_mark(3 + extra, top_left, Vector2(x, y), k, alpha)
			_mark(1, top_left, Vector2(x, y + row), k, alpha)
		2:
			_mark(2, top_left, Vector2(x, y), k, alpha)
			_mark(3, top_left, Vector2(x, y + row), k, alpha)
		3:
			_mark(4 + extra, top_left, Vector2(x, y + row / 2), k, alpha)


## 1 si el layout trae close_m (Joey), 0 si no.
func _extra() -> int:
	return 1 if _layout != null and _layout.index_of("close_m_?.bmp") >= 0 else 0


func _mark(index: int, top_left: Vector2, center: Vector2, k: float, alpha: float) -> void:
	var tex := _tex[index]
	var size := tex.get_size() * k
	draw_texture_rect(tex, Rect2(top_left + center * k - size / 2, size), false, Color(1, 1, 1, alpha))
