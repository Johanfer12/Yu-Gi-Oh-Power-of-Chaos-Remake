class_name DuelCardStats
extends Node2D
## ATK/DEF de los monstruos del campo (FUN_00410890, metodo de dibujo de la carta del campo).
## Bajo la carta del jugador 0 (encima en la del 1) se escriben "ATK / DEF" con la fuente
## duel_fontm de duel/font/number.txt: cuadro 1 (blanca) si el valor mostrado es el base,
## 2 (duel_fontm_b) si es mayor y 3 (duel_fontm_r) si es menor. El valor mostrado se acerca al
## real cada fotograma (actual + (mostrado - actual) * 7 / 8, truncando hacia cero) y mientras
## difiere aparece la flecha yaji_ue (sube) o yaji_sita (baja) de duel/card/card.txt, que
## alterna sus dos imagenes con el bit 2 del contador de fotogramas DAT_005aed18 y oscila con
## sus bits 1-2. El valor de la posicion actual va opaco y el otro con alfa 0xa0.
## Las cartas boca abajo de la CPU no muestran valores; las propias si.

## Ancho de cada cifra: duel_fontm mide 77 px con 11 glifos ("0123456789/"); _b y _r 70 con 10.
const GLYPH := 7
const HEIGHT := 10

var _duel: Duel
var _game := "yugi"
## Valores mostrados por zona (p * 5 + z): [indice de carta, ATK, DEF] (+0x10, +0x4c, +0x50).
var _shown := {}
var _tick := 0
var _fonts: Array[Texture2D] = []
var _arrows: Array[Texture2D] = []
## Contadores de las cartas del campo (FUN_004103e0 reloj de arena, bits 2-5 de las banderas;
## FUN_00410640 calavera, bits 6-8). Por zona (p * 11 + z): [contadores, turnos, estado 3/4,
## +0x1c]. Al cambiar uno, el objeto de la carta pasa al estado 3 o 4 con +0x1c = 0x200, que
## baja 0x10 por fotograma (FUN_00410030; comandos 0x8b/0x97 en 0x4034c0/0x4035a0).
var _counters := {}
var _card_objects: DuelCardTable
var _suna: Texture2D
var _skul: Texture2D
var _eff: Texture2D
var _eff2: Texture2D
var _yellow: Texture2D
## Zonas que no se dibujan (la carta esta en una animacion de la presentacion).
var hides_at: Callable


func setup(duel: Duel, game: String, card_objects: DuelCardTable = null) -> void:
	_duel = duel
	_game = game
	_card_objects = card_objects if game in ["yugi", "kaiba"] else null
	_shown.clear()
	_fonts = [
		Assets.texture("%s/duel/font/duel_fontm.png" % game),
		Assets.texture("%s/duel/font/duel_fontm_b.png" % game),
		Assets.texture("%s/duel/font/duel_fontm_r.png" % game),
	]
	_arrows = [
		Assets.texture("%s/duel/card/yaji_ue1.png" % game),
		Assets.texture("%s/duel/card/yaji_ue2.png" % game),
		Assets.texture("%s/duel/card/yaji_sita1.png" % game),
		Assets.texture("%s/duel/card/yaji_sita2.png" % game),
	]
	_counters.clear()
	_suna = Assets.texture("%s/duel/card/pas_eff_suna.png" % game)
	_skul = Assets.texture("%s/duel/card/pas_eff_skul.png" % game)
	_eff = Assets.texture("%s/duel/card/pas_eff.png" % game)
	_eff2 = Assets.texture("%s/duel/card/pas_eff2.png" % game)
	_yellow = Assets.texture("%s/duel/font/duel_fontm_y.png" % game)
	queue_redraw()


func _step_counters() -> void:
	for p in 2:
		for z in 11:
			var key := p * 11 + z
			var at := DuelMem.zone(p, z)
			if (_duel.m.u16(at) & 0xfff) == 0:
				_counters.erase(key)
				continue
			var flags := _duel.m.u16(at + 6)
			var counters := (flags >> 2) & 15
			var turns := (flags >> 6) & 7
			if _card_objects != null:
				var object: Dictionary = _card_objects.field[p][z]
				var animation: Vector2i = object.get("counter_animation", Vector2i.ZERO)
				_counters[key] = [counters, turns, animation.x, animation.y]
				continue
			var st: Array = _counters.get(key, [counters, turns, 0, 0])
			if counters != st[0]:
				st = [counters, turns, 3, 0x200]
			elif turns != st[1]:
				st = [counters, turns, 4, 0x200]
			elif st[2] != 0:
				st[3] -= 0x10
				if st[3] <= 0:
					st[2] = 0
					st[3] = 0
			_counters[key] = st


## Un tick nativo (NativeClock.HZ): `tick` es DAT_005aed18.
func step(tick: int) -> void:
	_tick = tick
	if _duel == null:
		return
	_step_counters()
	for p in 2:
		for z in 5:
			var key := p * 5 + z
			var ix := _duel.m.u16(DuelMem.zone(p, z)) & 0xfff
			if ix == 0:
				_shown.erase(key)
				continue
			var now := _current(p, z)
			if not _shown.has(key) or _shown[key][0] != ix:
				# Fuera de la zona de monstruo la carta guarda sus valores base (0x410890).
				_shown[key] = [ix, _duel.f445810(ix) & 0xffff, _duel.f445850(ix) & 0xffff]
			var s: Array = _shown[key]
			# Diferencias antes de acercarse (las flechas) y valores mostrados del fotograma.
			_shown[key] = [ix, _ease(s[1], now[0]), _ease(s[2], now[1]), now[0] - int(s[1]), now[1] - int(s[2])]
	queue_redraw()


## ATK y DEF reales de la carta de la zona (FUN_00546470).
func _current(p: int, z: int) -> Array[int]:
	var buf := _duel.m.local(0x10)
	_duel.f546470(p, z, buf)
	return [_s32(_duel.m.u32(buf + 4)), _s32(_duel.m.u32(buf + 8))]


static func _s32(v: int) -> int:
	return v - 0x100000000 if v >= 0x80000000 else v


## (a - b) * 7 / 8 + b con la division entera de C (trunca hacia cero).
static func _ease(shown: int, real: int) -> int:
	var d := (shown - real) * 7
	return (d / 8 if d >= 0 else -((-d) / 8)) + real


func _draw() -> void:
	if _duel == null or _fonts.is_empty() or _fonts[0] == null:
		return
	_draw_counters()
	for key in _shown.keys():
		var s: Array = _shown[key]
		if s.size() < 5:
			continue
		var p: int = key / 5
		var z: int = key % 5
		var flags := _duel.m.u16(DuelMem.zone(p, z) + 6)
		var face_up := (flags & 2) != 0
		var defense := (flags & 1) != 0
		var atk_delta: int = s[3]
		var def_delta: int = s[4]
		if p == 1 and not face_up:
			continue
		var center := DuelGeometry.zone(p, z)
		if hides_at.is_valid() and hides_at.call(center):
			continue
		var cx := int(center.x)
		var y := int(center.y) + (-0x5c if p == 1 else 0) + 0x2e - HEIGHT / 2
		var ix: int = s[0]
		var shown_atk: int = s[1]
		var shown_def: int = s[2]
		var right_x := cx + GLYPH / 2 + (GLYPH * 5) / 2
		var left_x := cx - GLYPH / 2 - (GLYPH * 5) / 2
		# DEF: opaca en defensa, alfa 0xa0 en ataque.
		_number(_font_for(shown_def, _duel.f445850(ix) & 0xffff), right_x, y, shown_def, 1.0 if defense else 0xa0 / 255.0)
		_arrow(def_delta, right_x, y)
		_glyph(_fonts[0], 10, cx + GLYPH / 2 - GLYPH, y, 0xa0 / 255.0)
		_number(_font_for(shown_atk, _duel.f445810(ix) & 0xffff), left_x, y, shown_atk, 0xa0 / 255.0 if defense else 1.0)
		_arrow(atk_delta, left_x, y)


## FUN_004103e0 y FUN_00410640 para las cartas boca arriba del campo.
func _draw_counters() -> void:
	for key in _counters:
		var st: Array = _counters[key]
		var p: int = key / 11
		var z: int = key % 11
		if (_duel.m.u16(DuelMem.zone(p, z) + 6) & 2) == 0:
			continue
		var center := DuelGeometry.zone(p, z)
		if hides_at.is_valid() and hides_at.call(center):
			continue
		var cx := int(center.x)
		var y := int(center.y) + (-1 if p == 1 else 1) * (72 / 2 - 5)
		var c: int = st[3]
		if (st[0] != 0 or st[2] == 3) and _suna != null:
			var fw := _suna.get_width() / 6
			var k := ((c >> 6) + 2) if st[2] == 3 and c < 0x100 else ((_tick >> 4) % 3)
			var x := cx - 25
			draw_texture_rect_region(_suna, Rect2(x, y - (_suna.get_height() + 1) / 2, fw, _suna.get_height()), Rect2(k * fw, 0, fw, _suna.get_height()))
			x += fw
			_number_on(_yellow, x + 6, y, st[0])
			if st[2] == 3 and c >= 0x100 and _eff != null:
				var ew := _eff.get_width() / 8
				draw_texture_rect_region(_eff, Rect2(x - ew / 2 + 6, y - _eff.get_height() / 2, ew, _eff.get_height()), Rect2(((-c >> 4) & 7) * ew, 0, ew, _eff.get_height()))
		if (st[1] != 0 or st[2] == 4) and _skul != null:
			var fw := _skul.get_width() / 4
			var k := (c >> 6) if st[2] == 4 and c < 0x100 else 0
			var right := cx + 50 / 2 - 3
			draw_texture_rect_region(_skul, Rect2(right - fw - 8, y - _skul.get_height() / 2, fw, _skul.get_height()), Rect2(k * fw, 0, fw, _skul.get_height()))
			_number_right(_yellow, right, y - HEIGHT / 2, st[1])
			if st[2] == 4 and c >= 0x100 and _eff2 != null:
				var ew := _eff2.get_width() / 8
				draw_texture_rect_region(_eff2, Rect2(right - ew / 2 - 4, y - _eff2.get_height() / 2, ew, _eff2.get_height()), Rect2(((-c >> 4) & 7) * ew, 0, ew, _eff2.get_height()))


## FUN_00460730: numero centrado en x y en y.
func _number_on(font: Texture2D, center_x: int, center_y: int, value: int) -> void:
	_number(font, center_x, center_y - HEIGHT / 2, value, 1.0)


## FUN_004604f0: numero con el borde derecho en `right`.
func _number_right(font: Texture2D, right: int, top: int, value: int) -> void:
	if font == null:
		return
	var v := absi(value)
	var x := right
	while true:
		x -= GLYPH
		_glyph(font, v % 10, x, top, 1.0)
		v /= 10
		if v == 0:
			break


## 0x4103a0: 1 base, 2 mayor (azul), 3 menor (rojo).
func _font_for(value: int, base: int) -> Texture2D:
	if base < value:
		return _fonts[1]
	if value < base:
		return _fonts[2]
	return _fonts[0]


## 0x4605f0: cifras de derecha a izquierda; el numero queda centrado en `center_x`
## (0x460360 da su ancho).
func _number(font: Texture2D, center_x: int, y: int, value: int, alpha: float) -> void:
	if font == null:
		return
	var v := absi(value)
	var digits := 0
	var t := v
	while true:
		digits += 1
		t /= 10
		if t == 0:
			break
	var x := center_x + (digits * GLYPH) / 2
	while true:
		x -= GLYPH
		_glyph(font, v % 10, x, y, alpha)
		v /= 10
		if v == 0:
			break


func _glyph(font: Texture2D, index: int, x: int, y: int, alpha: float) -> void:
	draw_texture_rect_region(font, Rect2(x, y, GLYPH, HEIGHT), Rect2(index * GLYPH, 0, GLYPH, HEIGHT), Color(1, 1, 1, alpha))


## Flecha centrada sobre el numero mientras el valor mostrado alcanza al real.
func _arrow(delta: int, x: int, y: int) -> void:
	if delta == 0:
		return
	var bob := (_tick >> 1) & 3
	var frame := (_tick >> 2) & 1
	var tex: Texture2D
	var top: int
	if delta > 0:
		tex = _arrows[frame]
		top = y - bob - 7
	else:
		tex = _arrows[2 + frame]
		top = y + bob - 9
	if tex != null:
		draw_texture(tex, Vector2(x, top) - tex.get_size() / 2)
