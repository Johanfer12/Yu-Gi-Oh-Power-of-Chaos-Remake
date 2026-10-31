class_name JoeyFxCanvas
extends KonamiSurface
## Superficie de destino de los metodos de dibujo portados de Joey (joey_fx_*.gd). Cada metodo
## es una primitiva del original; aqui se dibuja con los sprites de la capa de presentacion.
## Las coordenadas llegan como en el original: esquina superior izquierda para +0xac/+0xb0 y
## centro para 422c00.

const Basic := preload("res://scenes/duel/duel_basic_effects.gd")
const Geometry := preload("res://scenes/duel/duel_geometry.gd")
const ADD := preload("res://scenes/konami/konami_add.gdshader")

var owner: Node2D
var event: Dictionary
## Lista de sprites del efecto (duel/effect/<efecto>.txt, +0x20 del objeto del original).
var list: KonamiSpriteList


func _init(target: Node2D, effect: Dictionary, txt_path: String) -> void:
	owner = target
	event = effect
	list = KonamiSpriteList.open(txt_path, effect.get("game", "joey"))


## 41f2e0 sobre el objeto de carta del efecto: la carta de la zona girada (grados).
func card_image(degrees: int) -> Dictionary:
	return {"card": true, "angle": degrees * 128 / 90}


## Imagen de la entrada de la lista (+0x80 + i*8 + 4 del objeto del original).
func sprite(index: int) -> Dictionary:
	return list.image(index)


## Metodo +0x38 de la imagen: ancho y alto.
func image_size(image: Dictionary) -> Vector2i:
	if image.has("card"):
		var size := Vector2i(Geometry.FIELD_SIZE)
		return Vector2i(size.y, size.x) if int(image.angle) & 128 else size
	var texture: Texture2D = Assets.texture("%s/duel/effect/%s.png" % [event.get("game", "joey"), image.sprite])
	return Vector2i(texture.get_size()) if texture != null else Vector2i.ZERO


## Selector de la lista de sprites (vtable[0] de +0x70): el indice del .txt.
func frame(index: int) -> int:
	return list.select(index)


## Metodo +8 de la lista: carga la entrada si hace falta y fija su prioridad.
func pick(index: int, value: int) -> void:
	list.pick(index, value)


## +0xac (KonamiSurface): suma floor(src * nivel / 255) con saturacion (konami_add.gdshader,
## mismo contrato que KonamiMemorySurface). Las imagenes del juego no tienen alfa (formato 7):
## con nivel 0xff (+0xa0) suman la imagen entera, que es la misma formula.
func slot_ac(image: Variant, x: int, y: int, a: int, _b: Variant, _c: Variant, _d: Variant) -> int:
	_exact_add(_draw(image, x, y, 256), a & 0xff)
	return 0


## +0xb0 (KonamiSurface): mismo contrato que +0xac (nivel 0xff: +0x9c).
func slot_b0(image: Variant, x: int, y: int, a: int, _b: Variant, _c: Variant, _d: Variant) -> int:
	_exact_add(_draw(image, x, y, 256), a & 0xff)
	return 0


func _exact_add(item: CanvasItem, level: int) -> void:
	if item == null:
		return
	var material := ShaderMaterial.new()
	material.shader = ADD
	material.set_shader_parameter("level", level)
	material.set_shader_parameter("key_transparent", true)
	item.material = material


## +0x18 (KonamiSurface, reenvia a +0x7c): mezcla dst + (src - dst) * nivel / 255 de la region
## `rect` de la imagen con su esquina en (x, y). Se dibuja con la mezcla normal de Godot a
## nivel / 255; el contrato exacto (truncado por canal) necesitaria leer el fondo en un shader.
func slot_18(image: Variant, x: int, y: int, level: int, rect: Variant, _c: Variant, _d: Variant) -> int:
	var r: Array = rect if rect is Array else [0, 0] + Array([image_size(image).x, image_size(image).y])
	var size := Vector2(int(r[2]) - int(r[0]), int(r[3]) - int(r[1]))
	var sprite := Basic._asset(owner, image.sprite, Vector2(x, y) + size / 2, 65536, 256)
	if sprite == null:
		return 1
	sprite.region_enabled = true
	sprite.region_filter_clip_enabled = true
	sprite.region_rect = Rect2(int(r[0]), int(r[1]), size.x, size.y)
	sprite.modulate.a = clampi(level, 0, 255) / 255.0
	return 0


## Listas de sprites por nombre: "list" es la del .txt del efecto; "cards", la lista global de
## imagenes de cartas (5f2ff8), que en el port es la carta del evento.
func list_select(name: String, index: int) -> int:
	return list.select(index) if name == "list" else index


func list_pick(name: String, index: int, value: int) -> void:
	if name == "list":
		list.pick(index, value)


func list_image(name: String, index: int) -> Dictionary:
	if name == "cards":
		return {"card": true, "full": true, "angle": 0}
	return list.image(index)


## 422c00(destino, imagen, x, y, giro, escala x, escala y, alfa): centrado en (x, y). Las cartas
## de la lista global son el arte entero (200x290) que se escala.
func card(image: Dictionary, x: int, y: int, spin: int, scale_x: int, _scale_y: int, alpha: int) -> void:
	if image.has("card"):
		Basic._card(owner, event, Vector2(x, y), Vector2(200, 290) * scale_x / 65536.0, alpha, spin,
			bool(int(event.get("flags", 2)) & 2))
		return
	Basic._asset(owner, image.sprite, Vector2(x, y), scale_x, alpha, spin)


func _draw(image: Dictionary, x: int, y: int, alpha: int) -> CanvasItem:
	var size := Vector2(image_size(image))
	var center := Vector2(x, y) + size / 2
	if image.has("card"):
		return Basic._card(owner, event, center, Geometry.FIELD_SIZE, alpha, int(image.angle), event.get("face", false))
	return Basic._asset(owner, image.sprite, center, 65536, alpha)
