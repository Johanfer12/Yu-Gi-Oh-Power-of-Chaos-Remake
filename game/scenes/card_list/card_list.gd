extends Node2D
## Lista de cartas (coleccion). Yugi: clase de 0x45f680 (list/list_scene.txt), un tick nativo
## por vuelta de 0x45f840:
##   45e510 carta o boton bajo el puntero | 45e890 teclas (llevan el puntero, 4600f0)
##   443640 objetos (panel de detalle 45fa60) | 45de60 clic | dibujo: panel, 45f060 filtros,
##   45f120 titulo/Back/flechas/paginas, 45ec70 cuadricula (y avance del volteo), 45f2b0 tasa.
##
## list_scene: 0 titulo | 1-2 Back (normal, senalado) | 3-4 cifras de pagina (centro)
##             5-8 flechas izq. (senalada, pulsada), der. (senalada, pulsada): el fondo ya las
##             trae, solo se dibujan al senalarlas | 9 marco de la carta senalada (su posicion
##             es la de la cuadricula) | 10 NEW (5 fotogramas) | 11 tasa (esquina sup. der.)
##             | 12 simbolos "/.%" (anchos 11, 5, 20) | 13-15 filtro "solo", 16-18 "todas"
##             (apagado, senalado, activo)
## list_detail: 0 fondo (posicion de la carta grande) | 1-2 texto (sup. izq., inf. der.)
##             | 3 linea sobre ATK/DEF (X) | 4 barra de desplazamiento
##
## Las cartas son los indices 1..0x45a cuyo CARD_Pack.bin cae en la mascara del juego,
## ordenados por CARD_Sort_<idioma>.bin (0x45e3a0); 50 por pagina en 10x5.

const PER_PAGE := 50                 # 0x32
const COLS := 10
const ROWS := 5
const PITCH := Vector2i(0x37, 0x57)
const MINI := Vector2i(50, 72)       # 0x5af730/0x5af734
const LAST_INDEX := 0x45a
## 0x45e890 y 0x4117a0 (0x538770): 1 arriba, 2 abajo, 3 izquierda, 4 derecha, 6 decidir,
## 0xc cancelar, 0xf/0x10 RePag/AvPag (tabla de 0x45c700).
const KEYS := {KEY_UP: 1, KEY_KP_8: 1, KEY_DOWN: 2, KEY_KP_2: 2, KEY_LEFT: 3, KEY_KP_4: 3,
	KEY_RIGHT: 4, KEY_KP_6: 4, KEY_ENTER: 6, KEY_KP_ENTER: 6, KEY_ESCAPE: 0xc, KEY_INSERT: 0xc,
	KEY_KP_0: 0xc, KEY_PAGEUP: 0xf, KEY_PAGEDOWN: 0x10}
const SORT_LANG := {"s": "spa", "e": "eng", "g": "ger", "f": "fra", "i": "ita", "j": "jpn"}
## Panel de detalle (Yugi 45fa60, Kaiba 461c00, Joey 47cbe0) sobre la clase 412c50: colores
## 0xBBGGRR de nombre, tipo, descripcion y ATK/DEF (412410 los escribe como
## <FONT color="#RRGGBB">). Kaiba no los cambia y quedan los de 412b30.
const DETAIL_COLORS := {
	"yugi": {"name": "#101010", "type": "#612a00", "body": "#4b2f1a", "stats": "#612a00"},
	"kaiba": {"name": "#ffff00", "type": "#00ff00", "body": "#ffffff", "stats": "#ffff00"},
	"joey": {"name": "#574f59", "type": "#50535f", "body": "#67671c", "stats": "#5a3e5f"},
}
## Alto de la linea de ATK/DEF (+0x15c): Kaiba 0xd + 2, Joey el de su clase base.
const STATS_HEIGHT := {"yugi": 0xd, "kaiba": 0xf, "joey": 0xe}
## Kaiba 45fae0: el alto del texto cuenta 6 px mas (sus mascaras tapan arriba y abajo).
const TEXT_EXTRA := {"yugi": 0, "kaiba": 6, "joey": 0}
## Paso de las cifras de pagina (460730): Kaiba pasa 0xc; Yugi y Joey 0 = ancho del glifo.
const PAGE_ADVANCE := {"yugi": 0, "kaiba": 0xc, "joey": 0}
const SCROLL_STEP := 0x13            # 45f560 +0x60
const MUSIC := {
	"yugi": "yugi/voice/stream/kaban.wav",
	"kaiba": "kaiba/voice/stream/m_kaban.wav",
	"joey": "joey/voice/stream/m_kaban.wav",
}

var game: String
var _scene: Layout
var _detail: Layout
var _dir := ""
var _tex: Array[Texture2D] = []

var _cards: Array[Dictionary] = []   # +0x410 (como diccionarios de CardDB)
var _owned_count := 0                # +0x3f8
var _pages := 1                      # +0x400
var _all := false                    # +0x404: mascara de 540430 en vez de 540410
var _has_other := false              # +0x405: hay cartas obtenidas fuera de "solo"
var _page := -1                      # +0x3ec (45f680 lo deja en -1)
var _prev_page := -1                 # +0x3f0
var _flip := 0                       # +0x408: +-0x100 hacia 0 de 8 en 8
var _hover := -9                     # +0x3f4
var _rest := 0                       # +0x3d0
var _last := Vector2i(-1, -1)        # +0x3dc/+0x3e0
var _started := false                # +0x3d8
var _joey_title := 0                 # 47ed50: contador local, dos MT al byte bajo 16
var _kaiba_open := 0                 # 4613d0: 0..184 en pasos8 (24 ticks)
var _origin := Vector2i.ZERO         # +0x3e4/+0x3e8
var _detail_card := 0                # +0x10 del panel: indice (0 = reverso)
var _shown_card := -1                # +0x14

var _mouse := Vector2(-1, -1)
var _released := false
var _keys := {}
var _clock := 0.0
var _left_down := false
var _ops: Array = []
var _layer := 0                      # capa de la orden siguiente (ver _draw_ops)
var _layers: Array[Node2D] = []
var _blend := NativeBlend.new()
var _sort_key := PackedInt32Array()
var _by_index := {}

var _page_font: DigitFont
var _rate_font: DigitFont
var _text := RichTextLabel.new()
var _detail_reveal := preload("res://core/card_detail_reveal.gd").new()
var _stats := Label.new()
var _text_clip := Control.new()
var _scroll: NativeScrollBar
var _text_rect := Rect2i()           # +0x160..+0x16c del panel
var _text_top_padding := 0
var _cursor = preload("res://scenes/duel/duel_cursor_visual.gd").new()


func _init(game_id: String) -> void:
	game = game_id
	_dir = "%s/list/" % game


func _ready() -> void:
	_scene = Assets.layout(_dir + "list_scene.txt")
	_detail = Assets.layout(_dir + "list_detail.txt")
	for i in _scene.items.size():
		_tex.append(Assets.texture(_dir + _scene.resource(i)))
	_origin = _num(_scene, 9)
	_page_font = DigitFont.new(_tex[3], null, "", null, _tex[3].get_width() / 10)
	_rate_font = DigitFont.new(_tex[11], null, "", null, _tex[11].get_width() / 10)
	for card: Dictionary in CardDB.cards:
		_by_index[int(card["index"])] = card
	_load_sort_key()
	_build_detail()
	for which in [1, 2]:
		_layers.append(_Layer.new(self, which))
		add_child(_layers.back())
	_mouse = get_local_mouse_position()
	add_child(_cursor)
	_cursor.update(_mouse, false)
	_rebuild()
	_has_other = _owns_outside_only()
	_set_page(0, true)
	Audio.play_music(MUSIC[game])


## XXXYYY de una linea (el motor divide entre 1000).
static func _num(layout: Layout, i: int) -> Vector2i:
	var v := int(str(layout.value(i)))
	return Vector2i(v / 1000, v % 1000)


func _size(i: int) -> Vector2i:
	return Vector2i(_tex[i].get_size()) if _tex[i] != null else Vector2i.ZERO


func _load_sort_key() -> void:
	var path := Paths.data_dir.path_join("common/bin/card_sort%s.bin" % SORT_LANG.get(Assets.lang, "spa"))
	var bytes := FileAccess.get_file_as_bytes(path)
	_sort_key.resize(bytes.size() / 2)
	for i in _sort_key.size():
		_sort_key[i] = bytes.decode_u16(i * 2)


# --- lista (0x45e3a0, 0x45ddb0) --------------------------------------------------------------

## 0x540410 (solo el juego en curso) o 0x540430 (este y los anteriores).
func _mask(all: bool) -> int:
	var g: int = {"yugi": 0, "kaiba": 1, "joey": 2}[game]
	return (1 << (g + 1)) - 1 if all else 1 << g


func _rebuild() -> void:
	var mask := _mask(_all)
	_cards.clear()
	for index in range(1, LAST_INDEX + 1):
		var card: Dictionary = _by_index.get(index, {})
		if not card.is_empty() and (int(card["pack"]) & mask) != 0:
			_cards.append(card)
	_owned_count = _cards.filter(_owned).size()
	_pages = (_cards.size() + PER_PAGE - 1) / PER_PAGE
	# qsort con 0x45dd20: CARD_Sort[a] - CARD_Sort[b] (claves distintas para cada carta).
	_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _key_of(a) < _key_of(b))


func _key_of(card: Dictionary) -> int:
	var i := int(card["index"])
	return _sort_key[i] if i < _sort_key.size() else 0


func _owns_outside_only() -> bool:
	var only := _mask(false)
	var all := _mask(true)
	for card: Dictionary in CardDB.cards:
		var i := int(card["index"])
		if i >= 1 and i <= LAST_INDEX and _owned(card):
			var pack := int(card["pack"])
			if (pack & all) != 0 and (pack & only) == 0:
				return true
	return false


func _owned(card: Dictionary) -> bool:
	return SaveData.card_count(int(card["internal_id"])) > 0


## 0x45de20
func _set_page(page: int, forward: bool) -> void:
	_prev_page = _page
	_page = page
	_flip = 0x100 if forward else -0x100


## Carta que se ve en la posicion `i` de la lista: el reverso (0) si no se tiene.
func _shown_at(i: int) -> int:
	if i < 0 or i >= _cards.size():
		return -1
	return int(_cards[i]["index"]) if _owned(_cards[i]) else 0


# --- tick (0x45f840) -------------------------------------------------------------------------

func _process(delta: float) -> void:
	_cursor.advance(delta)
	_clock = minf(_clock + NativeClock.ticks(delta), 4.0)
	while _clock >= 1.0:
		_clock -= 1.0
		_tick()
		_released = false
		_keys.clear()
		if not is_inside_tree():
			return
	_blend.fraction = _clock
	queue_redraw()
	for layer in _layers:
		layer.queue_redraw()


func _tick() -> void:
	_text.visible_characters = _detail_reveal.step()
	_glide_step()
	_blend.tick()
	_ops.clear()
	if not _started:
		if game == "kaiba":
			_frame_kaiba_open()
			_kaiba_open += 8
			if _kaiba_open >= 192:
				_kaiba_open = 256
				_started = true
				_warp(0x33)
			return
		# 0x45f510: primer tick, el puntero va a la flecha derecha y se dibuja sin entrada.
		_started = true
		_warp(0x33)
		_update_detail()
		_frame()
		return
	_hover_step()
	_keys_step()
	_update_detail()
	var leave := false
	if _key(6) or _released:
		leave = _click()
	_frame()
	if leave or _key(preload("res://core/duel_input.gd").cancel_slot(game)):
		_leave()


func _glide_step() -> void:
	var at := PointerGlide.step(self, _mouse)
	if at != _mouse:
		_mouse = at
		_cursor.update(at, false, -1, _left_down)


func _key(code: int) -> bool:
	return _keys.has(code)


## 0x45e510
func _hover_step() -> void:
	var p := Vector2i(PointerGlide.hover(_mouse))
	if p == _last:
		_rest += 1
		if _rest == 4 and _hover >= 0 and _hover < PER_PAGE:
			var shown := _shown_at(_page * PER_PAGE + _hover)
			if shown >= 0:
				_detail_card = shown
	else:
		_rest = 0
	_last = p
	_hover = _hit(p)


func _hit(p: Vector2i) -> int:
	if _has_other:
		if _inside(p, 13): return -3
		if _inside(p, 16): return -2
	if _inside(p, 1): return -1
	if _inside(p, 5): return 0x32
	if _inside(p, 7): return 0x33
	var d := p - _origin
	if d.x >= 0 and d.y >= 0:
		var col := d.x / PITCH.x
		var row := d.y / PITCH.y
		if col < COLS and row < ROWS and d.x % PITCH.x < MINI.x and d.y % PITCH.y < MINI.y:
			return col + row * COLS
	return -9


## 0x45e4a0
func _inside(p: Vector2i, i: int) -> bool:
	if i >= _tex.size():
		return false
	return Rect2i(_num(_scene, i), _size(i)).has_point(p)


## 0x45e890
func _keys_step() -> void:
	if game == "joey":
		_keys_step_joey()
		return
	var h := _hover
	if h == -3:
		if _key(4): _warp(-1)
		if _key(2): _warp(-2)
	elif h == -2:
		if _key(4): _warp(-1)
		if _key(1): _warp(-3)
		if _key(2): _warp(8)
	elif h < 0:
		if _key(3): _warp(-3)
		if _key(4): _warp(-1)
		if _key(1): _warp(-1)
		if _key(2): _warp(9)
	elif h < PER_PAGE:
		_keys_step_cards(h)
	else:
		if _key(3): _warp(0x32)
		if _key(4): _warp(0x33)
		if _key(1): _warp(0x31 if _hover != 0x32 else 0x28)
		if _key(2): _warp(-1)


## Joey 47e280: los filtros estan abajo ("todas" a la izquierda, "solo" a la derecha).
func _keys_step_joey() -> void:
	var h := _hover
	if h == -3:
		if _key(3): _warp(0x33)
		if _key(1): _warp(49)
	elif h == -2:
		if _key(4): _warp(0x32)
		if _key(1): _warp(40)
	elif h < 0:
		if _key(4): _warp(-1)
		if _key(1): _warp(-1)
		if _key(2): _warp(9)
	elif h < PER_PAGE:
		_keys_step_cards(h)
	elif h == 0x33:
		if _key(3): _warp(0x32)
		if _key(4): _warp(-3)
		if _key(1): _warp(0x31)
	else:
		if _key(3): _warp(-2)
		if _key(4): _warp(0x33)
		if _key(1): _warp(0x28)


func _keys_step_cards(h: int) -> void:
	if _key(3): h -= 1
	if _key(4): h += 1
	if _key(1): h -= 10
	if _key(2): h += 10
	if h < 0:
		h = -1
	elif h > PER_PAGE - 1:
		h = int(h % 10 > 4) + 0x32
	if h != _hover:
		_warp(h)


## 0x45e7c0 -> 0x45e750 / 0x4600f0: centro del boton o de la carta.
func _warp(target: int) -> void:
	var item := -1
	if _has_other and target == -3:
		item = 13
	elif _has_other and target == -2:
		item = 16
	elif target < 0:
		item = 1
	elif target < PER_PAGE:
		var at := _origin + Vector2i(target % 10, target / 10) * PITCH + MINI / 2
		PointerGlide.request(_mouse, Vector2(at))
		return
	elif target == 0x32:
		item = 5
	elif target == 0x33:
		item = 7
	if item >= 0:
		PointerGlide.request(_mouse, Vector2(_num(_scene, item) + _size(item) / 2))


## 0x45de60: true = salir.
func _click() -> bool:
	if _flip != 0:
		return false
	if _all:
		if _hover == -3:
			_set_page(-1, true)
			_decide()
	elif _hover == -2:
		_set_page(-1, true)
		_decide()
	if _hover == -1:
		_decide()
		return true
	if _hover >= 0 and _hover < PER_PAGE:
		var i := _page * PER_PAGE + _hover
		if i >= 0 and i < _cards.size() and _owned(_cards[i]):
			_detail_card = int(_cards[i]["index"])
			SaveData.mark_seen(int(_cards[i]["internal_id"]))
	elif _hover == 0x32:
		if _page >= 1:
			_set_page(_page - 1, false)
			_decide()
	elif _hover == 0x33:
		if _page < _pages - 1:
			_set_page(_page + 1, true)
			_decide()
	return false


func _decide() -> void:
	Audio.play_sfx("%s/voice/internal/decide.wav" % game)   # 0x10000001


## 0x45f780 guarda. La vuelta al título usa el barrido 532390(0x13, 0x10, 0, 0x100).
func _leave() -> void:
	SaveData.save()
	Game.open_title(game, "list")


# --- panel de detalle (0x45fa60 sobre 0x412c50) ------------------------------------------------

func _build_detail() -> void:
	var tl := _num(_detail, 1)
	var br := _num(_detail, 2)
	_text_rect = Rect2i(tl.x + 3, tl.y + 1, br.x - 5 - (tl.x + 3), br.y - (tl.y + 1))
	# La mascara superior de Kaiba cubre seis filas del rectangulo nativo.
	# Reservarlas evita que el nombre empiece detras de la cabecera DESCRIPCION.
	_text_top_padding = TEXT_EXTRA[game]
	_text_clip.position = Vector2(_text_rect.position) + Vector2(0, _text_top_padding)
	_text_clip.size = Vector2(_text_rect.size) - Vector2(0, _text_top_padding)
	_text_clip.clip_contents = true
	_text_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text_clip)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial", "Liberation Sans", "Roboto", "sans-serif"])
	var bold := SystemFont.new()
	bold.font_names = font.font_names
	bold.font_weight = 700
	_text.bbcode_enabled = true
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.scroll_active = false
	_text.fit_content = true
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size = Vector2(_text_rect.size.x, 0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_override("normal_font", font)
	_text.add_theme_font_override("bold_font", bold)
	for key in ["normal_font_size", "bold_font_size"]:
		_text.add_theme_font_size_override(key, 12)
	_text_clip.add_child(_text)
	_stats.add_theme_font_override("font", font)
	_stats.add_theme_font_size_override("font_size", 11)
	_stats.add_theme_color_override("font_color", Color(DETAIL_COLORS[game]["stats"]))
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats.position = Vector2(_text_rect.position.x, _text_rect.end.y - STATS_HEIGHT[game])
	_stats.size = Vector2(_text_rect.size.x, STATS_HEIGHT[game])
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stats)
	# Kaiba 45fee0: mascaras de arriba y abajo (list_detail 5 y 6) encima del texto.
	if game == "kaiba":
		for i in [5, 6]:
			var mask := Sprite2D.new()
			mask.texture = Assets.texture(_dir + _detail.resource(i))
			mask.centered = false
			mask.position = Vector2(_num(_detail, i))
			add_child(mask)
	_scroll = NativeScrollBar.new(game, "list/detail_scroll")
	_scroll.position = Vector2(_num(_detail, 4))
	_scroll.step = SCROLL_STEP
	_scroll.scrolled.connect(func(value: int): _text.position.y = -value)
	add_child(_scroll)


static func _is_monster(card: Dictionary) -> bool:
	return str(card.get("category", "")) == "monster"


## 0x45e090/0x4117a0 y 0x412410/0x4118a0: rueda en toda la pantalla y RePag/AvPag desplazan el
## texto; al cambiar de carta se rehace el texto y la barra vuelve arriba.
func _update_detail() -> void:
	if _key(0xf): _scroll.set_value(_scroll.value - SCROLL_STEP)
	elif _key(0x10): _scroll.set_value(_scroll.value + SCROLL_STEP)
	if _detail_card == _shown_card:
		return
	_shown_card = _detail_card
	var card: Dictionary = _by_index.get(_detail_card, {}) if _detail_card > 0 else {}
	var text := ""
	_stats.text = ""
	if not card.is_empty():
		text = "[color=%s][b]%s[/b][/color]\n" % [DETAIL_COLORS[game]["name"], _bb(CardDB.text(card, "names"))]
		if _is_monster(card):
			text += "[color=%s][lb]%s[rb][/color]\n" % [DETAIL_COLORS[game]["type"],
					_bb(CardDB.type_name(int(card.get("type_id", 0))))]
			_stats.text = "ATK/%4d DEF/%4d" % [int(card["atk"]), int(card["defense"])]
		text += "[color=%s]%s[/color]" % [DETAIL_COLORS[game]["body"], _bb(CardDB.text(card, "descriptions"))]
	_text.text = text
	_detail_reveal.reset(_text.get_parsed_text(), Assets.lang == "j")
	_text.visible_characters = 0
	_text_clip.size.y = _text_rect.size.y - _text_top_padding - (1 + STATS_HEIGHT[game] if _is_monster(card) else 0)
	_scroll.set_value(0)
	# El margen de la mascara ya esta descontado del area visible, una sola vez.
	_scroll.set_range(maxi(0, int(_text.get_content_height()) + TEXT_EXTRA[game] - _text_top_padding - int(_text_clip.size.y)))


static func _bb(text: String) -> String:
	return text.replace("[", "[lb]")


# --- ordenes de dibujo de un tick -------------------------------------------------------------

func _op(tex: Texture2D, rect: Rect2, src := Rect2(), alpha := 1.0, add := false, key: Variant = null) -> void:
	if tex == null:
		return
	if add:
		_layer = 1
	elif _layer == 1:
		_layer = 2
	_ops.append({"tex": tex, "rect": rect, "src": src, "alpha": alpha, "layer": _layer, "key": key})


func _put(i: int, at: Vector2i) -> void:
	if i < _tex.size() and _tex[i] != null:
		_op(_tex[i], Rect2(Vector2(at), _tex[i].get_size()))


func _frame() -> void:
	_layer = 0
	_frame_detail()
	_frame_filters()
	_frame_buttons()
	_frame_grid()
	_frame_rate()


## 4613d0/416490: tres vistas aparecen por contornos; no se atiende entrada.
func _frame_kaiba_open() -> void:
	_layer = 0
	# ASM4613dd..461428: fondo19 en0,0 y titulo0 en coordenada de layout.
	_put(19, Vector2i.ZERO)
	_put(0, _num(_scene, 0))
	_frame_filters()
	_put(1 + int(_hover == -1), _num(_scene, 1))
	if _kaiba_open > 64:
		_put(20, _num(_scene, 20))
	if _kaiba_open > 128:
		_put(21, _num(_scene, 21))
	var stage := mini(2, _kaiba_open / 64)
	var sources := [Rect2i(753, 185, 23, 31), Rect2i(752, 237, 26, 32), Rect2i(752, 290, 26, 32)]
	var targets := [Rect2i(0, 376, 239, 224), Rect2i(0, 67, 237, 332), Rect2i(220, 82, 580, 500)]
	if _kaiba_open & 16:
		_put(22 + stage, _num(_scene, 22 + stage))
	var weight := (_kaiba_open & 63) * 4
	for delay in [0, 32, 64]:
		if weight > delay:
			var a: Rect2i = sources[stage]
			var b: Rect2i = targets[stage]
			var t: int = weight - delay
			var from := Vector2i((a.position.x * (256 - t) + b.position.x * t) / 256,
				(a.position.y * (256 - t) + b.position.y * t) / 256)
			var end := Vector2i((a.end.x * (256 - t) + b.end.x * t) / 256,
				(a.end.y * (256 - t) + b.end.y * t) / 256)
			_ops.append({"outline": Rect2(from, end - from), "layer": 0})


## 0x45e110 + composicion de la carta grande (0x45e090 -> 49c770) + 0x4479b0 (linea de ATK/DEF).
func _frame_detail() -> void:
	var bg := Assets.texture(_dir + _detail.resource(0))
	_op(bg, Rect2(Vector2.ZERO, bg.get_size()))
	var big: Texture2D = CardDB.card_texture(int(_by_index[_detail_card]["internal_id"])) \
			if _by_index.has(_detail_card) else Assets.texture("common/card/card_ura.png")
	_op(big, Rect2(Vector2(_num(_detail, 0)), big.get_size()))
	var card: Dictionary = _by_index.get(_detail_card, {}) if _detail_card > 0 else {}
	if _is_monster(card):
		var line := Assets.texture(_dir + _detail.resource(3))
		_op(line, Rect2(Vector2(int(str(_detail.value(3))), _text_rect.end.y - STATS_HEIGHT[game] - 1), line.get_size()))


## 0x45f060
func _frame_filters() -> void:
	if not _has_other:
		return
	var only := 2 if not _all else int(_hover == -3)
	_put(13 + only, _num(_scene, 13 + only))
	var all := 2 if _all else int(_hover == -2)
	_put(16 + all, _num(_scene, 16 + all))


## 0x45f120
func _frame_buttons() -> void:
	if game == "joey":
		_frame_joey_title()
	else:
		_put(0, _num(_scene, 0))
	_put(1 + int(_hover == -1), _num(_scene, 1))
	if _hover == 0x32 and _page > 0:
		_put(5 + int(_left_down), _num(_scene, 5))
	if _hover == 0x33 and _page < _pages - 1:
		_put(7 + int(_left_down), _num(_scene, 7))
	var page := _page if _page >= 0 else _prev_page
	_number_centered(_page_font, page + 1, _num(_scene, 3), PAGE_ADVANCE[game])
	_number_centered(_page_font, _pages, _num(_scene, 4), PAGE_ADVANCE[game])


## 47ed50/ASM47ed6e..ee04: tabla de 32 valores en pila, 8 por forma.
func _frame_joey_title() -> void:
	const PATTERN := [0,0,0,0,0,0,0,0, 2,2,0,1,0,1,0,1,
		1,0,1,0,1,0,1,0, 2,2,2,2,0,2,1,2]
	_joey_title += 1
	if (_joey_title & 255) == 16:
		var shape := UiRandom.draw() & 3
		var pause := UiRandom.draw() & 127
		_joey_title += shape * 256 + pause
	var frame := 0
	if (_joey_title & 255) < 16:
		var value: int = PATTERN[((_joey_title >> 1) & 127) + ((_joey_title >> 8) & 3) * 8]
		if value != 0:
			frame = 18 + value
	_put(frame, _num(_scene, frame))
	if frame == 0:
		var alpha := mini(255, (DuelVisualMath.cos_fx(Game.native_tick * 8 - 128) >> 9) + 128)
		_op(_tex[19], Rect2(Vector2(_num(_scene, 19)), _tex[19].get_size()),
			Rect2(), alpha / 255.0)


## 0x45ec70: cada casilla gira 180 grados con su propio retraso; antes de la mitad muestra la
## pagina anterior (+0x3f0) y despues la nueva. Al acabar el giro hacia la pagina -1 se cambia
## el filtro y se vuelve a la pagina 0.
func _frame_grid() -> void:
	var new_tex := _tex[10]
	var frames := maxi(1, int(str(_scene.value(10))))
	for row in ROWS:
		for col in COLS:
			var v := 0
			if _flip < 0:
				v = _flip - (row * 0x780 + col * 0x1440) / 0x140
			else:
				v = (-0xb640 - row * 0x780 + col * 0x1440) / 0x140 - _flip
			var u := v + 0x100
			var page := _prev_page
			if u > 0x40:
				u = 0x40
				page = _page
			elif u < 0:
				u = 0
			elif u > 0x1f:
				page = _page
			var slot := row * COLS + col
			var shown := _shown_at(page * PER_PAGE + slot)
			if shown < 0:
				continue
			var tex := _mini(shown)
			var cx := _origin.x + col * PITCH.x + MINI.x / 2
			var cy := _origin.y + row * PITCH.y + MINI.y / 2
			if (u & 0x3f) == 0:
				var tl := Vector2(cx - MINI.x / 2, cy - MINI.y / 2)
				_op(tex, Rect2(tl, Vector2(MINI)), Rect2(), 1.0, false, ["card", slot])
				if _hover == slot:
					# vtable +0xac con 0x40: copia aditiva de la carta y el marco card_waku_s.
					_op(tex, Rect2(tl, Vector2(MINI)), Rect2(), 64.0 / 255.0, true)
					_put(9, Vector2i(tl) - Vector2i(4, 4))
				if shown > 0 and not SaveData.is_seen(int(_by_index[shown]["internal_id"])):
					_frame_new(new_tex, frames, row, col)
			else:
				var p := DuelVisualMath.cos_fx((u * 4) & 0x1ff) * MINI.x
				var s := -1 if p < 0 else 0
				var w := ((p >> 16) ^ s) - s
				var lift := (DuelVisualMath.cos_fx((u * 4 - 0x80) & 0x1ff) << 5) >> 16
				_op(tex, Rect2(cx - w / 2, cy - lift - MINI.y / 2, w, MINI.y), Rect2(), 1.0, false,
						["card", slot])
	if _flip != 0:
		_flip -= 8 if _flip > 0 else -8
		if _flip == 0 and _page < 0:
			_all = not _all
			_rebuild()
			_set_page(0, true)


func _mini(index: int) -> Texture2D:
	if index > 0 and _by_index.has(index):
		return CardDB.card_texture(int(_by_index[index]["internal_id"]), true)
	return Assets.texture("common/mini/card_ura.png")


## 0x45ea90: ciclo de 64 ticks (entra en 16, se queda 32, sale en 16); fotograma cada 4 ticks.
## Va a la izquierda de la carta: el original resta y suma la mitad del ancho del NEW.
func _frame_new(tex: Texture2D, frames: int, row: int, col: int) -> void:
	var tick := Game.native_tick
	var a := (tick * 4) & 0xff
	var alpha := 0x100
	if a < 0x40:
		alpha = DuelVisualMath.cos_fx((a * 2 - 0x80) & 0x1ff) >> 8
	elif a > 0xc0:
		alpha = DuelVisualMath.cos_fx((a * 2 + 0x80) & 0x1ff) >> 8
	var w := tex.get_width()
	var h := tex.get_height() / frames
	var frame := (tick >> 2) % frames
	var at := Vector2(_origin.x + MINI.x / 2 - w / 2 + col * PITCH.x, _origin.y + MINI.y / 2 + row * PITCH.y - h / 2)
	_op(tex, Rect2(at, Vector2(w, h)), Rect2(0, frame * h, w, h), alpha / 256.0, false, ["new", row * COLS + col])


## 0x45f2b0: cada 0x40 ticks alterna "obtenidas/total" y el tanto por mil "xx.x%". Los
## simbolos suben (alto simbolos - alto cifras) / 2.
func _frame_rate() -> void:
	var right := _num(_scene, 11)
	var widths := Layout.groups(_scene.value(12), 2)   # "/", ".", "%"
	var sym := _tex[12]
	var lift := -((sym.get_height() - _tex[11].get_height()) / 2)
	var y := right.y
	var total := maxi(1, _cards.size())
	if (Game.native_tick & 0x40) != 0:
		var x := _number_right(_rate_font, _cards.size(), right.x, y) - widths[0]
		_op(sym, Rect2(x, y + lift, widths[0], sym.get_height()), Rect2(0, 0, widths[0], sym.get_height()))
		_number_right(_rate_font, _owned_count, x, y)
		return
	var permille := _owned_count * 1000 / total
	var x := right.x - widths[2]
	var pct_from := widths[0] + widths[1]
	_op(sym, Rect2(x, y + lift, widths[2], sym.get_height()), Rect2(pct_from, 0, widths[2], sym.get_height()))
	x = _number_right(_rate_font, permille % 10, x, y) - widths[1]
	_op(sym, Rect2(x, y + lift, widths[1], sym.get_height()), Rect2(widths[0], 0, widths[1], sym.get_height()))
	_number_right(_rate_font, permille / 10, x, y)


## 0x4604f0: cifras de derecha a izquierda acabando en `right`; devuelve el borde izquierdo.
## `advance` 0 = el ancho del glifo.
func _number_right(font: DigitFont, value: int, right: int, top: int, advance := 0) -> int:
	var n := absi(value)
	var gw := int(font.glyph_width)
	var step := advance if advance > 0 else gw
	var h := font.digits.get_height()
	while true:
		right -= step
		_op(font.digits, Rect2(right, top, gw, h), Rect2((n % 10) * gw, 0, gw, h))
		n /= 10
		if n == 0:
			break
	return right


## 0x460730: centrado con la mitad entera del ancho y del alto.
func _number_centered(font: DigitFont, value: int, center: Vector2i, advance := 0) -> void:
	var digits := str(absi(value)).length()
	var w := digits * (advance if advance > 0 else int(font.glyph_width))
	_number_right(font, value, center.x + w / 2, center.y - font.digits.get_height() / 2, advance)


func _draw() -> void:
	_draw_ops(self, 0)


## Godot no cambia la mezcla por orden de dibujo: lo aditivo va en una capa hija y lo que se
## dibuja despues (marco, NEW, tasa) en otra encima, en el mismo orden que el original.
func _draw_ops(canvas: CanvasItem, layer: int) -> void:
	for op: Dictionary in _ops:
		if op["layer"] != layer:
			continue
		if op.has("outline"):
			var r: Rect2 = op.outline
			canvas.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color.WHITE)
			canvas.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Color.WHITE)
			canvas.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), Color.WHITE)
			canvas.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), Color.WHITE)
			continue
		var rect: Rect2 = op["rect"]
		if op["key"] != null:
			rect = _blend.at(op["key"], rect)
		var color := Color(1, 1, 1, op["alpha"])
		if op["key"] is Array and op["key"][0] == "new":
			color.a = _blend.at([op["key"], "a"], op["alpha"])
		if op["src"] == Rect2():
			canvas.draw_texture_rect(op["tex"], rect, false, color)
		else:
			canvas.draw_texture_rect_region(op["tex"], rect, op["src"], color)


class _Layer extends Node2D:
	var list: Node2D
	var layer := 0

	func _init(owner_list: Node2D, which: int) -> void:
		list = owner_list
		layer = which
		if which == 1:
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			material = mat

	func _draw() -> void:
		list._draw_ops(self, layer)


# --- entrada ---------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _scroll.handle(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse:
		_mouse = get_global_transform_with_canvas().affine_inverse() * event.position
		_left_down = PlatformInput.mouse_pressed(MOUSE_BUTTON_LEFT)
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_left_down = event.pressed
			if event.pressed:
				_cursor.click(_mouse, true)
			else:
				_released = true   # vtable +0x38 de DAT_005af864: el boton se suelta
		_cursor.update(_mouse, false, -1, _left_down)
		if event is InputEventMouseButton and event.pressed:
			# 0x4117a0: la rueda desplaza el texto del detalle este donde este el puntero.
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_scroll.set_value(_scroll.value - SCROLL_STEP)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_scroll.set_value(_scroll.value + SCROLL_STEP)
	elif event is InputEventKey and event.pressed and not event.echo:
		var input := preload("res://core/duel_input.gd")
		var groups: int = input.slots(event, game)
		for code in [1, 2, 3, 4, 6, input.cancel_slot(game)]:
			if groups & (1 << code):
				_keys[code] = true
		# RePag/AvPag son23/24 en Joey (4797e0),15/16 en Yugi; el panel consume
		# las teclas fisicas de4117a0, por lo que conserva sus codigos internos.
		var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if key in [KEY_PAGEUP, KEY_PAGEDOWN]:
			_keys[KEYS[key]] = true
	get_viewport().set_input_as_handled()
