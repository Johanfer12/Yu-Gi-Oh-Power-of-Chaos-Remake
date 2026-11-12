extends Node
## Base de datos de cartas (data/common/db/cards.json, generada por pocx).
##
## Reparto por juego, como en el original (card_pack.bin es un campo de bits):
## - se GANAN solo las cartas del juego al que se esta jugando;
## - se pueden USAR las del juego en curso y las de los anteriores:
##   Yugi=1, Kaiba=3, Joey=7 (mascaras acumulativas del validador nativo).

## type_id de card_prop.bin (deducido de cartas conocidas, ver docs/INVENTARIO.md 4)
const TYPE_NAMES := {
	1: "Dragón", 2: "Zombi", 3: "Demonio", 4: "Piro", 5: "Serpiente Marina", 6: "Roca",
	7: "Máquina", 8: "Pez", 9: "Dinosaurio", 10: "Insecto", 11: "Bestia",
	12: "Guerrero-Bestia", 13: "Planta", 14: "Aqua", 15: "Guerrero", 16: "Bestia Alada",
	17: "Hada", 18: "Lanzador de Conjuros", 19: "Trueno", 20: "Reptil",
}
const KIND_SUFFIX := {"effect": "/Efecto", "fusion": "/Fusión", "ritual": "/Ritual"}

## Grupos del editor de mazos, en el orden de las gemas del original:
## oro = normal, rojo = efecto, verde = magia, rosa = trampa, azul = ritual.
enum Group { NORMAL, EFFECT, SPELL, TRAP, RITUAL, FUSION }

const PACK_BITS := {"yugi": 1, "kaiba": 2, "joey": 4}
const USABLE_BITS := {"yugi": 1, "kaiba": 1 | 2, "joey": 1 | 2 | 4}

var cards: Array[Dictionary] = []
var _by_internal_id := {}
var _type_labels := {}


func _ready() -> void:
	load_db()


func load_db() -> void:
	cards.clear()
	_by_internal_id.clear()
	_type_labels.clear()
	var data: Variant = Assets.read_json("common/db/cards.json")
	if data == null:
		return
	for card: Dictionary in data:
		cards.append(card)
		_by_internal_id[int(card["internal_id"])] = card


func by_id(internal_id: int) -> Dictionary:
	return _by_internal_id.get(internal_id, {})


func name_of(internal_id: int, lang := "") -> String:
	var card := by_id(internal_id)
	return text(card, "names", lang) if card else "?"


func text(card: Dictionary, field: String, language := "") -> String:
	if language == "":
		language = Assets.text_language()
	var improved := CardTranslations.text(card, field, language)
	if improved != "":
		return improved
	var values: Dictionary = card.get(field, {})
	return str(values.get(language, values.get("eng", values.get("spa", ""))))


func obtainable_in(game: String) -> Array[Dictionary]:
	return _filter(PACK_BITS[game])


func usable_in(game: String) -> Array[Dictionary]:
	return _filter(USABLE_BITS[game])


func is_usable(internal_id: int, game: String) -> bool:
	var card := by_id(internal_id)
	return not card.is_empty() and (int(card["pack"]) & USABLE_BITS[game]) != 0


func card_texture(internal_id: int, mini := false) -> Texture2D:
	var card := by_id(internal_id)
	if card.is_empty() or card["image"] == null:
		return Assets.texture("common/card/card_ura.png")
	return Assets.texture(("common/mini/" if mini else "common/card/") + str(card["image"]))


func group_of(card: Dictionary) -> Group:
	match str(card["category"]):
		"spell":
			return Group.SPELL
		"trap":
			return Group.TRAP
	match str(card.get("monster_kind", "normal")):
		"effect":
			return Group.EFFECT
		"fusion":
			return Group.FUSION
		"ritual":
			return Group.RITUAL
	return Group.NORMAL


## Rotulos nativos dlg_text: tipos501..524 y sufijos550..554, en los seis idiomas.
func type_name(type_id: int) -> String:
	return _dialog_label(500 + type_id, TYPE_NAMES.get(type_id, "?")) if type_id >= 1 and type_id <= 24 else "?"


func _dialog_label(index: int, fallback: String) -> String:
	if not _type_labels.has(Assets.lang):
		_type_labels[Assets.lang] = Assets.dialog_texts()
	var labels: Variant = _type_labels[Assets.lang]
	if labels is Array and index < labels.size():
		return str(labels[index])
	return fallback


func type_text(card: Dictionary) -> String:
	match str(card["category"]):
		"spell":
			return "[%s]" % type_name(22)
		"trap":
			return "[%s]" % type_name(21)
	var kind := str(card.get("monster_kind", ""))
	var suffix_index: int = {"effect": 550, "fusion": 551, "ritual": 552}.get(kind, -1)
	var suffix := _dialog_label(suffix_index, KIND_SUFFIX.get(kind, "")) if suffix_index >= 0 else ""
	return "[%s%s]" % [type_name(int(card["type_id"])), suffix]


func _filter(bits: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for card in cards:
		if int(card["pack"]) & bits:
			out.append(card)
	return out
