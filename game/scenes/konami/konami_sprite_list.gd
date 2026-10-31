class_name KonamiSpriteList
extends RefCounted
## Lista de sprites de la libreria de Konami (vtable 5da4b0; los efectos usan la derivada 5da45c,
## que carga los nombres con "?" sustituido por el idioma y, si falla, por el de respaldo, como
## Assets.resolve). Es una cache: cada entrada del .txt tiene cargada (+0x10), prioridad (+0x1c) y
## edad (+0x28). Los metodos llevan la direccion de Joey; los verifica konami_sprite_list_test.gd
## contra el original ejecutado en Unicorn (re/scripts/konami_sprite_list_oracle.py).
## La imagen de la entrada i es siempre la linea i del .txt: la cache decide cuando se carga, no que
## se dibuja. El selector por defecto de la lista (+0x50, vtable 5dc9f4, ret 4) deja el indice igual.

var names: PackedStringArray = []   # recursos del .txt, en su orden
var loaded := PackedByteArray()     # +0x10
var priority := PackedInt32Array()  # +0x1c
var age := PackedInt32Array()       # +0x28
var images: Array = []              # +0x60: imagen cargada de cada entrada (null si no lo esta)
var game := "joey"
var _dir := ""


## 481d00: lee el .txt (Layout ya separa comentarios y lineas vacias) y prepara las entradas.
static func open(path: String, game_id := "joey") -> KonamiSpriteList:
	var list := KonamiSpriteList.new()
	list.game = game_id
	list._dir = path.get_base_dir()
	var names := PackedStringArray()
	var assets: Node = (Engine.get_main_loop() as SceneTree).root.get_node("Assets")
	for item: Dictionary in assets.layout(path).items:
		names.append(String(item.resource))
	list.set_names(names)
	return list


## +0x04 549840 y +0x38 5497e0: entradas nuevas, todas sin cargar, prioridad y edad a cero.
func set_names(list: PackedStringArray) -> void:
	names = list
	loaded.resize(list.size())
	loaded.fill(0)
	priority.resize(list.size())
	priority.fill(0)
	age.resize(list.size())
	age.fill(0)
	images.resize(list.size())
	images.fill(null)


## Selector por defecto (+0x50, 43a5d0): el indice no cambia.
func select(index: int) -> int:
	return index


## +0x08 549ba0: con prioridad distinta de -1 la fija y pone la edad a cero; si no estaba cargada,
## la marca y la carga (+0x40).
func pick(index: int, value: int) -> void:
	if value != -1:
		priority[index] = value
		age[index] = 0
	if loaded[index] != 0:
		return
	loaded[index] = 1
	_load(index)


## +0x0c 549be0: si estaba cargada, la descarga (+0x3c) y pone la edad a cero.
func release(index: int) -> void:
	if loaded[index] == 0:
		return
	loaded[index] = 0
	age[index] = 0
	_unload(index)


## +0x10 549c30: suelta las entradas [desde, hasta) con prioridad <= p.
func release_priority(from: int, to: int, p: int) -> void:
	for i in range(from, to):
		if priority[i] <= p:
			release(i)


## +0x14 549c10: +0x10 sobre toda la lista.
func release_priority_all(p: int) -> void:
	release_priority(0, names.size(), p)


## +0x18 549c90: suelta las entradas [desde, hasta) con edad >= a.
func release_age(from: int, to: int, a: int) -> void:
	for i in range(from, to):
		if a <= age[i]:
			release(i)


## +0x1c 549c70: +0x18 sobre toda la lista.
func release_age_all(a: int) -> void:
	release_age(0, names.size(), a)


## +0x20 549cd0: todas las entradas envejecen un tick.
func tick() -> void:
	for i in names.size():
		age[i] += 1


## Imagen de la entrada (+0x60 + i*8 + 4).
func image(index: int) -> Variant:
	return images[index]


## +0x40 481ad0: carga la imagen de la entrada (en Godot, la textura del recurso).
func _load(index: int) -> void:
	images[index] = {"sprite": names[index].get_basename(), "path": _dir.path_join(names[index])}


## +0x3c: descarga la imagen.
func _unload(index: int) -> void:
	images[index] = null
