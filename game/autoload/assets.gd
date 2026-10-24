extends Node
## Acceso a data/ (fuera de res://, porque los assets de Konami no van en el proyecto).
## - Busqueda sin distinguir mayusculas: los scripts dicen "TITLE1.bmp" y el archivo es
##   "title1.png"; en Android el sistema de archivos si distingue.
## - ".bmp"/".yga" se resuelven al ".png" convertido.
## - "?" es la letra de idioma; si el recurso no existe en ese idioma se usa el ingles.

const LANG_FALLBACK := "e"
const LANGUAGES := {"s": "Español", "e": "English", "g": "Deutsch", "f": "Français", "i": "Italiano", "j": "日本語"}
const TEXT_LANGUAGES := {"s": "spa", "e": "eng", "g": "ger", "f": "fra", "i": "ita", "j": "jpn"}
# Rotulos propios del selector; traducciones del port, no recursos del original.
const PORT_LABELS := {
	"s": ["ELIGE JUEGO", "CONFIGURACIÓN", "Música", "Silenciar", "Idioma"],
	"e": ["CHOOSE GAME", "SETTINGS", "Music", "Mute", "Language"],
	"g": ["SPIEL WÄHLEN", "EINSTELLUNGEN", "Musik", "Stumm", "Sprache"],
	"f": ["CHOISIR UN JEU", "PARAMÈTRES", "Musique", "Muet", "Langue"],
	"i": ["SCEGLI GIOCO", "IMPOSTAZIONI", "Musica", "Silenzia", "Lingua"],
	"j": ["ゲームを選択", "設定", "音楽", "ミュート", "言語"],
}

func port_label(index: int) -> String:
	return str(PORT_LABELS.get(lang, PORT_LABELS[LANG_FALLBACK])[index])


var lang := "s"
var _index := {}        # ruta relativa en minusculas -> ruta absoluta
var _textures := {}     # ruta absoluta -> Texture2D
var _layouts := {}      # ruta absoluta -> Layout
var _missing := {}      # Un aviso por recurso ausente, aunque se solicite cada fotograma.
var _voice_packs := {}


func _ready() -> void:
	reindex()


func reindex() -> void:
	_index.clear()
	_textures.clear()
	_layouts.clear()
	_missing.clear()
	if DirAccess.dir_exists_absolute(Paths.data_dir):
		_scan(Paths.data_dir, "")
	_voice_packs.clear()
	var voices: Variant = read_json("voice_manifest.json")
	if voices is Dictionary:
		_voice_packs = voices.get("games", {})


func voice_language(game: String) -> String:
	var pack: Dictionary = _voice_packs.get(game, {})
	var available: Array = pack.get("languages", [])
	if available.has(lang):
		return lang
	return str(pack.get("default", ""))


## Preferencia del port; los originales se instalaban con un idioma fijo.
func set_language(value: String) -> bool:
	if not LANGUAGES.has(value):
		return false
	lang = value
	return true


func system_language(locale: String = OS.get_locale_language()) -> String:
	return {"es": "s", "en": "e", "de": "g", "fr": "f", "it": "i", "ja": "j"}.get(locale.replace("-", "_").get_slice("_", 0).to_lower(), "e")


func preferred_language() -> String:
	var config := ConfigFile.new()
	config.load(Paths.settings_path())
	var value := str(config.get_value("preferences", "language", SaveData.data.get("settings", {}).get("language", system_language())))
	return value if LANGUAGES.has(value) else system_language()


func remember_language(value: String) -> void:
	if not set_language(value):
		return
	var config := ConfigFile.new()
	config.load(Paths.settings_path())
	config.set_value("preferences", "language", value)
	config.save(Paths.settings_path())
	if Paths.has_data():
		SaveData.data.get_or_add("settings", {})["language"] = value
		SaveData.save()


func text_language() -> String:
	return TEXT_LANGUAGES.get(lang, "spa")


func dialog_texts() -> Variant:
	var texts: Variant = read_json("common/db/dlg_%s.json" % text_language())
	return texts if texts != null else read_json("common/db/dlg_eng.json")


## Ruta absoluta de un recurso, o "" si no existe.
func resolve(rel_path: String) -> String:
	var rel := rel_path.replace("\\", "/").to_lower()
	var parts := rel.split("/")
	if parts.size() == 4 and parts[1] == "voice" and parts[2] in ["stream", "internal"]:
		var pack: Dictionary = _voice_packs.get(parts[0], {})
		var choices: Array = [lang, pack.get("default", ""), "e"]
		choices.append_array(pack.get("languages", []))
		for language in choices:
			var localized := "%s/voice/%s/%s/%s" % [parts[0], language, parts[2], parts[3]]
			var voice := _lookup(localized)
			if voice != "":
				return voice
	for ext in [".bmp", ".yga"]:
		if rel.ends_with(ext):
			rel = rel.trim_suffix(ext) + ".png"
	if rel.contains("?"):
		var found: String = _lookup(rel.replace("?", lang))
		if found == "":
			found = _lookup(rel.replace("?", LANG_FALLBACK))
		return found
	return _lookup(rel)


func _lookup(rel: String) -> String:
	var path: String = _index.get(rel, "")
	# La copia optimizada conserva los nombres WAV en scripts y tablas nativas.
	if path == "" and rel.ends_with(".wav"):
		path = _index.get(rel.trim_suffix(".wav") + ".ogg", "")
	if path == "" and rel.ends_with(".png"):
		path = _index.get(rel.trim_suffix(".png") + ".webp", "")
	return path


func exists(rel_path: String) -> bool:
	return resolve(rel_path) != ""


func texture(rel_path: String) -> Texture2D:
	var path := resolve(rel_path)
	if path == "":
		if not _missing.has(rel_path):
			_missing[rel_path] = true
			push_warning("Recurso no encontrado: %s" % rel_path)
		return null
	if not _textures.has(path):
		var image := Image.load_from_file(path)
		if image == null:
			push_error("No se pudo cargar %s" % path)
			return null
		# Equivale a la opcion de importacion fix_alpha_border: evita que el color clave que
		# queda bajo los pixeles transparentes "sangre" al escalar con filtrado.
		image.fix_alpha_edges()
		_textures[path] = ImageTexture.create_from_image(image)
	return _textures[path]


func layout(rel_txt_path: String) -> Layout:
	var rel := rel_txt_path.trim_suffix(".txt") + ".layout.json"
	var path := resolve(rel)
	if path == "":
		push_error("Script de maquetacion no encontrado: %s" % rel_txt_path)
		return Layout.new()
	if not _layouts.has(path):
		_layouts[path] = Layout.from_json(FileAccess.get_file_as_string(path), rel_txt_path)
	return _layouts[path]


func read_json(rel_path: String) -> Variant:
	var path := resolve(rel_path)
	if path == "":
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _scan(abs_dir: String, rel_dir: String) -> void:
	var dir := DirAccess.open(abs_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var abs_path := abs_dir.path_join(name)
		var rel := name if rel_dir == "" else rel_dir + "/" + name
		if dir.current_is_dir():
			_scan(abs_path, rel)
		else:
			_index[rel.to_lower()] = abs_path
		name = dir.get_next()
