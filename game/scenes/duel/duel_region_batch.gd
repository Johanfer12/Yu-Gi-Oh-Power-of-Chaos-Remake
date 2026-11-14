extends Node2D
## Muchas regiones de una misma textura dibujadas desde un solo nodo. La rotura de cartas
## (450 fragmentos de 4x2) y las caidas fila a fila de las viñetas (hasta 600 filas) creaban un
## Sprite2D por trozo en cada fotograma, y eso daba tirones al destruir un monstruo (issue 5).
## Dibuja lo mismo que aquellos sprites: region sin centrar en su posicion, sin filtro extra.

var texture: Texture2D
var regions: Array[Rect2] = []
var positions := PackedVector2Array()


func add(region: Rect2, at: Vector2) -> void:
	regions.append(region)
	positions.append(at)


func _draw() -> void:
	if texture == null:
		return
	for i in regions.size():
		draw_texture_rect_region(texture, Rect2(positions[i], regions[i].size), regions[i])
