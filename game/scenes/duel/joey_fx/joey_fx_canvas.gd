class_name JoeyFxCanvas
extends RefCounted
## Superficie de destino de los metodos de dibujo portados de Joey (joey_fx_*.gd). Cada metodo
## es una primitiva del original; aqui se dibuja con los sprites de la capa de presentacion.
## Las coordenadas llegan como en el original: esquina superior izquierda para +0xac/+0xb0 y
## centro para 422c00.

const Basic := preload("res://scenes/duel/duel_basic_effects.gd")
const Geometry := preload("res://scenes/duel/duel_geometry.gd")

var owner: Node2D
var event: Dictionary
## Lista de imagenes del .txt del efecto (duel/effect/<efecto>.txt), en su orden.
var sprites: PackedStringArray


func _init(target: Node2D, effect: Dictionary, list: PackedStringArray) -> void:
	owner = target
	event = effect
	sprites = list


## 41f2e0 sobre el objeto de carta del efecto: la carta de la zona girada (grados).
func card_image(degrees: int) -> Dictionary:
	return {"card": true, "angle": degrees * 128 / 90}


func sprite(index: int) -> Dictionary:
	return {"sprite": sprites[index]}


## Metodo +0x38 de la imagen: ancho y alto.
func image_size(image: Dictionary) -> Vector2i:
	if image.has("card"):
		var size := Vector2i(Geometry.FIELD_SIZE)
		return Vector2i(size.y, size.x) if int(image.angle) & 128 else size
	var texture: Texture2D = Assets.texture("%s/duel/effect/%s.png" % [event.get("game", "joey"), image.sprite])
	return Vector2i(texture.get_size()) if texture != null else Vector2i.ZERO


## Selector de la lista de sprites (vtable[0] de +0x70): el indice del .txt.
func frame(index: int) -> int:
	return index


## Metodo +8 de la lista: fija el fotograma; no dibuja.
func pick(_index: int, _value: int) -> void:
	pass


## Vtable +0xac: copia que suma luz con intensidad a/256.
func additive(image: Dictionary, x: int, y: int, a: int, _b: int, _c: int, _d: int) -> void:
	Basic._additive(_draw(image, x, y, a))


## Vtable +0xb0: dibujo mezclado con intensidad a/256 (sumado, como en duel_basic_effects).
func blend(image: Dictionary, x: int, y: int, a: int, _b: int, _c: int, _d: int) -> void:
	Basic._additive(_draw(image, x, y, a))


## 422c00(destino, imagen, x, y, giro, escala x, escala y, alfa): centrado en (x, y).
func card(image: Dictionary, x: int, y: int, spin: int, scale_x: int, _scale_y: int, alpha: int) -> void:
	Basic._asset(owner, image.sprite, Vector2(x, y), scale_x, alpha, spin)


func _draw(image: Dictionary, x: int, y: int, alpha: int) -> CanvasItem:
	var size := Vector2(image_size(image))
	var center := Vector2(x, y) + size / 2
	if image.has("card"):
		return Basic._card(owner, event, center, Geometry.FIELD_SIZE, alpha, int(image.angle), event.get("face", false))
	return Basic._asset(owner, image.sprite, center, 65536, alpha)
