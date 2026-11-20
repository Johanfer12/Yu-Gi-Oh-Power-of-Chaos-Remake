extends "res://scenes/duel/janken_scene.gd"
## 446490/445ab0: misma maquina0..7 que Yugi. Cambia443d0 (centro),
## 444db0 (muros) y445540/4457d0 (orbitas de los botones).
var _rotation := 400

func _init() -> void:
	super("kaiba")

## 4694b0 pone el reloj a cero y el bucle original lo incrementa al final de
## ese mismo tick. Game lo incrementa antes de que el título lo reinicie.
## Si hay varios pasos pendientes, 4443d0/445540 leen el reloj de este paso.
func _draw_tick() -> int:
	return (Game.native_tick + 1 - int(_clock)) & 0xffffffff


func _middle_draw(v: int) -> void:
	if _state > 3: return
	if v >= 256:
		_blit(7, Vector2(X1, Y1))
		for index in [33, 34]:
			var size := Vector2i(_tex[index].get_size())
			var pos := Vector2(400 - size.x / 2, 300 - size.y / 2)
			if v < 512:
				# 444c02..444d3e: deformación inversa, no fundido de alpha.
				var amount := v - 256
				var width := size.x * (amount if index == 33 else 512 - amount) / 256
				var height := size.y * (512 - amount if index == 33 else amount) / 256
				if width > 0 and height > 0:
					_cmds.append(["scaled", index, Rect2i(400 - width / 2, 300 - height / 2, width, height)])
				continue
			_blit(index, pos)
			# 44469f/444991: tres filas desplazadas al azar, recorren el alto de la imagen.
			var row := _draw_tick() % (size.y * 3 / 2) - size.y / 2 # 44469f/444991: DAT5b1d38 global.
			for spread in [6, 4, 2]:
				if row >= 0 and row < size.y:
					var dx: int = UiRandom.draw() % (spread * 2 + 1) - spread   # MT 533640
					_cmds.append(["region", index, pos + Vector2(dx, row), Rect2(0, row, size.x, 1)])
				row -= 1
	elif v > 0:
		_blit(7, Vector2(X1, Y1), v / 256.0)

func _strips_draw() -> void:
	super._strips_draw()
	if _state <= 4: return
	var displacement := W * (256 - _t) / 256 if _state == 5 else 0
	for y in [Y0, Y2]:
		_blit(35, Vector2(-displacement, y))
		_blit(35, Vector2(X2 + displacement, y))

func _buttons_draw() -> void:
	if _state == 5: _rotation = 400
	elif _state in [6, 7]: _rotation += int(_button == 1) - int(_button == 0)
	super._buttons_draw()

func _button_blit(which: int, pos: Vector2, alpha: int) -> void:
	super._button_blit(which, pos, alpha)
	if alpha < 256 or _state == 5: return
	var selected := _button == which
	var index := 36 + which * 3 + int(selected) + int(selected and (_draw_tick() & 16) != 0) # 445540.
	var size := Vector2i(_tex[index].get_size())
	var offset := Vector2i(_layout.position(index))
	var radius := 300 - offset.y - size.y / 2 - Y0 if which == 0 else offset.y + size.y / 2 + Y2 - 300
	var center := Vector2(400, pos.y + (H + (Y2 - Y1) / 2 if which == 0 else -(Y2 - Y1) / 2))
	# ASM445614..44562c pasa [x,y,x+2*W,y+H] a415cc0: órbita recortada al botón.
	var clip := Rect2i(Vector2i(pos), Vector2i(W * 2, H))
	for n in 3:
		var angle := _rotation + n * 170
		var at := center + Vector2(DuelVisualMath.cos_fx(angle) * radius / 65536, DuelVisualMath.cos_fx(angle - 128) * radius / 65536)
		_cmds.append(["rot", index, at, angle + (128 if which == 0 else -128), clip])
