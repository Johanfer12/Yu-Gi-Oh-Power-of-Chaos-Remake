class_name Layout
extends RefCounted
## Script de maquetacion del original, ya convertido por pocx a <script>.layout.json.
## El motor original lee las lineas por posicion; aqui se conservan en orden y solo las que
## tienen recurso. Que significa cada numero depende de la pantalla (ver docs/INVENTARIO.md 3.2).

var path := ""
var items: Array[Dictionary] = []   # {line, resource, value, comment}


static func from_json(text: String, source_path: String) -> Layout:
	var layout := Layout.new()
	layout.path = source_path
	var data: Variant = JSON.parse_string(text)
	if data == null:
		push_error("Layout invalido: %s" % source_path)
		return layout
	for entry: Dictionary in data["entries"]:
		if entry["resource"] != null:
			layout.items.append(entry)
	return layout


## Divide un numero en grupos de `size` digitos contando desde la derecha
## ("95188" -> [95, 188]): el motor pierde los ceros iniciales en algunos scripts.
static func groups(value: Variant, size := 3) -> PackedInt32Array:
	var out := PackedInt32Array()
	if value == null:
		return out
	var digits := str(value).trim_prefix("-")
	while digits.length() > 0:
		var cut := maxi(0, digits.length() - size)
		out.insert(0, digits.substr(cut).to_int())
		digits = digits.substr(0, cut)
	return out


## Indice del primer recurso que coincide (sin distinguir mayusculas), desde `from`.
func index_of(resource: String, from := 0) -> int:
	var wanted := resource.to_lower()
	for i in range(from, items.size()):
		if str(items[i]["resource"]).to_lower() == wanted:
			return i
	return -1


func resource(index: int) -> String:
	return str(items[index]["resource"])


func value(index: int) -> Variant:
	return items[index]["value"]


## Posicion XXXYYY de la linea. Las lineas sin numero heredan la de la anterior que lo
## tenga: asi se escriben las secuencias de fotogramas (ani1 con coordenadas, ani2..6 sin).
func position(index: int) -> Vector2i:
	for i in range(index, -1, -1):
		var g := groups(items[i]["value"])
		if g.size() == 2:
			return Vector2i(g[0], g[1])
	return Vector2i.ZERO
