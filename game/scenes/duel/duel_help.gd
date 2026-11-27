class_name DuelHelp
extends Node2D
## Ayuda emergente del duelo (objeto de FUN_004439c0, duel/help/help.txt: helpNN_?.yga con el
## motivo por el que la carta senalada no puede hacer nada: necesita sacrificio, ya invoco,
## turno de colocacion...). El motor pide el indice cada fotograma con FUN_004437a0
## (DuelBase.help_index, DAT_005aa1b4).
## FUN_004437b0 (cada fotograma): +0x14 sube 4 hasta 0x100. Con un objeto bajo el cursor, si no
## hay ayuda visible y hay una pedida (indice 9 o carta del jugador 0), un clic (o decidir) la
## muestra sobre esa carta desde +0x14 = 0; si hay una visible sigue mientras se pida la misma
## para la misma carta; en otro caso se quita. La peticion se borra siempre.
## FUN_00443880: imagen centrada en x sobre la carta (sin pasar de x = 800 - ancho / 2) y por
## encima de su borde superior (alto de carta 72, o 145 en la mano; nunca fuera por arriba);
## mientras +0x14 < 0x10 se despliega en vertical con alto * T[c * 8 - 0x80] / 256.

var _game := "yugi"
var _shown := -1
var _counter := 0x100
var _target := {}
var _blend := NativeBlend.new()   # despliegue entre ticks


func setup(game: String) -> void:
	_game = game
	_shown = -1
	z_index = 60
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## Un fotograma del motor. `hover`: {p, loc, i, pos} de la carta bajo el cursor (vacio si no
## hay); `click`: clic izquierdo o decidir en este fotograma.
func step(duel: Duel, hover: Dictionary, click: bool) -> void:
	_blend.tick()
	_counter += 4 if _counter < 0x100 else 0
	var wanted := duel.help_index
	duel.help_index = -1
	if hover.is_empty():
		_shown = -1
		queue_redraw()
		return
	if _shown < 0:
		if wanted >= 0 and (wanted == 9 or int(hover["p"]) == 0) and click:
			_shown = wanted
			_target = hover.duplicate()
			_counter = 0
	elif not (wanted == _shown and int(hover["p"]) == int(_target["p"]) and int(hover["loc"]) == int(_target["loc"]) and int(hover["i"]) == int(_target["i"])):
		_shown = -1
	queue_redraw()


## El duelo la avanza por fotogramas del motor: entre ellos se dibuja con lo que le queda.
func show_between(fraction: float) -> void:
	_blend.fraction = fraction
	if _shown >= 0 and _counter < 0x14: queue_redraw()


func _draw() -> void:
	if _shown < 0:
		return
	var tex := Assets.texture("%s/duel/help/help%02d_?.yga" % [_game, _shown + 1])
	if tex == null:
		return
	var w := int(tex.get_width())
	var h := int(tex.get_height())
	var pos: Vector2 = _target["pos"]
	var card_h := 145 if int(_target["loc"]) == 11 else 72
	var card_top := int(pos.y) - card_h / 2
	var cx := mini(int(pos.x), 800 - w / 2)
	var scale := 0x100
	if _counter < 0x10:
		scale = DuelVisualMath.cos_fx(_counter * 8 - 0x80) >> 8
	var shown_h: float = _blend.at([_shown, str(_target)], (h * scale) >> 8)
	var center_y := maxi(card_top, h) - h / 2
	var top := center_y - shown_h / 2
	# El original dibuja la imagen entera con un alto reducido (despliegue vertical).
	draw_texture_rect(tex, Rect2(cx - w / 2, top, w, shown_h), false)
