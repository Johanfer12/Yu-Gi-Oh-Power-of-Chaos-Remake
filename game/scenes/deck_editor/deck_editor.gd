extends Node2D
const NATIVE_SORT := preload("res://core/native_card_sort.gd")
const CARD_LIMITS := preload("res://core/native_card_limits.gd")
var _name_ranks := {}
var _deck_criteria := {"main": "default", "side": "default", "fusion": "default"}
var _sort_properties := PackedByteArray()
## Construccion de Deck.
##
## Los recursos salen de los scripts de deck_c/ (kabegami, kaban_list, kaban_detail,
## kaban_bar, font, btn_*, kbtn_*, filter*, export, import...), pero casi ninguno lleva
## coordenadas: el motor las tiene en el codigo. Medidas de Yugi (decompilado y capturas de
## la traza partida_20261008_160134):
## - panel izquierdo en x=0; fondo central en217 (Y459c10, Ka45d523, Jo46e7c2);
## - bolsa: 4538a0 la coloca en 0x2ac + DAT_005af83c, con DAT_005af83c = 0 plegada y -100
##   desplegada; el constructor (457ae0/458410) la deja plegada al entrar. La barra de la
##   derecha no se mueve (captura: x = 769 plegada); el boton de ventana alterna;
## - mazo principal, Side y Fusion: geometria de Y44b3e0 (DECK_ZONES); con 40 cartas, 4 filas
##   de 10 desde (262, 23) con paso 39 y 95; Side en y = 413 y Fusion en y = 520;
## - bolsa (44b8c0/455720): miniatura en (687 + DAT_005af83c, 39 + 56 r), dibujada al 70 %
##   (35x50) anclada arriba a la izquierda; 10 filas visibles;
## - contadores centrados en las casillas de cada fondo (COUNTER_CENTERS), en el orden
##   normal, efecto, magia, trampa, ritual, total, Side y Fusion. Las tapas de color de cada tubo
##   (kbtn_*) filtran la bolsa por ese tipo; la del total (f_all) quita el filtro;
## - bolsa plegada solo ATK/DEF, desplegada nombre, ATK/DEF, atributo, tipo y nivel
##   (posiciones aproximadas, de la miniatura de Kaiba); las cartas sin copias libres se
##   ven translucidas (alfa 0x6e, 44c8a0);
## - cabecera desplegada: etiqueta del filtro (icon_syurui) y orden (icon_sort, abre la
##   ventana w_filter_small con Nombre/Tipo/ATK/Atributo/DEF/Nivel).
## Topes por zona (0x59bc78): escena 8 = 80/15/15, intercambio = 95/30/15. Mazo valido
## para salir: 40-80 y Side hasta 15. Limites y variantes de 53fd30/448e80;
## Joey usa 5be190/4673b0 (docs/duel/LIMITES_EDITOR.md).
##
## Raton y teclado (objeto mazo 0x45a7d0, una vez por tick nativo y solo sin ventanas
## abiertas): no hay clic simple que anada cartas. Pulsar el izquierdo sobre una carta la
## agarra en el mismo tick y se arrastra; soltarla en otra zona la mueve (45a310). Zona por
## la posicion del raton (0x4472b0). Detalle en docs/duel/INTERCAMBIO_BALANCE.md.
##
## Modo intercambio (escena 10 de 0x464220, init 0x459b00 con 0x450390(1) = kaban_swap.txt;
## update 0x459c10): entre los duelos de un torneo, sin bolsa; solo se pasan cartas entre el
## mazo y el Side. Fondo central kabegami (item 0) en x = 0xd9 y kabegami_r (item 0x12) en
## x = 800 - ancho. Al volver: Y448ca0/Ka44a220/Jo4671b0 exige balance0; valido -> el
## mazo pasa a ser el activo (0x448d20) y 0x437f40(2) + escena 7 (janken); si no, aviso 4
## (swapdeckerror) y unable.
## Flechas de intercambio (solo indicador: 459c10 no las pulsa): Y44ee60(800-ancho,280),
## Ka450330(798-ancho,298), Jo476e80(800-ancho,295). Fundido Kaiba16 ticks; Joey
## salida10/entrada15+10. Composición interna cotejada en swap_surface_test.

const CENTER_X := 210.0
const CardMotion := preload("res://core/deck_card_motion.gd")
## Bolsa (4538a0: 0x2ac + DAT_005af83c). La barra de desplazamiento no se mueve.
const KABAN_X := {false: 684.0, true: 584.0}     # bolsa plegada / desplegada
const RIGHT_X := {false: 769.0, true: 769.0}

const CARD_W := 50
const CARD_H := 72
## Colocacion de las zonas del mazo (Y44b3e0, Ka44c940, Jo466290; desplazamientos de zona a 0
## en el constructor Y459ec0): [izquierda, arriba, derecha, abajo, filas, maximo sin apretar].
## Con hasta "maximo" cartas el paso es (ancho/2 + hueco) / 10; si hay mas, Yugi y Kaiba usan
## hueco * filas / cartas y Joey hueco / ((cartas - 1) / filas). Hueco = derecha - izquierda -
## ancho de la carta; se salta de fila cuando el desplazamiento supera el hueco. La bolsa
## (prioridad 2000) tapa las cartas del mazo (prioridad 1..n) al desplegarse.
const DECK_ZONES := {
	"yugi": {"main": [262, 23, 680, 379, 4, 40], "side": [262, 413, 692, 513, 1, 10],
		"fusion": [262, 520, 692, 621, 1, 10]},
	"kaiba": {"main": [262, 23, 676, 379, 4, 40], "side": [262, 413, 688, 513, 1, 10],
		"fusion": [262, 520, 688, 621, 1, 10]},
	"joey": {"main": [262, 23, 670, 379, 4, 40], "side": [262, 412, 670, 512, 1, 10],
		"fusion": [262, 515, 670, 616, 1, 10]},
}
const ZONES := ["main", "side", "fusion"]
const BAG := 3

## 0x4472b0: zonas por la posicion del raton.
const ZONE_LEFT := 217      # 0xd9
const ZONE_BAG_X := 680     # 0x2a8 (+ DAT_005af83c fuera del intercambio)
const ZONE_MAIN_Y := 391    # 0x187
const ZONE_SIDE_Y := 500
## 0x59bc78: topes por zona; fila 0 escena 8, fila 1 intercambio.
const ZONE_CAP := [[80, 15, 15], [95, 30, 15]]

## Centros de las casillas oscuras de kabegami_c (Kaiba: kabegami_c_2), con el fondo
## colocado en (217, 0). Las filas de tipos tienen paso 47, no 46; los tres fondos
## tienen distintas posiciones para el total, Side y Fusion.
const COUNTER_CENTERS := {
	"yugi": [Vector2(238, 87), Vector2(238, 134), Vector2(238, 181),
		Vector2(238, 228), Vector2(238, 275), Vector2(239, 367),
		Vector2(239, 473), Vector2(239, 579)],
	"kaiba": [Vector2(233, 84), Vector2(233, 131), Vector2(233, 178),
		Vector2(233, 225), Vector2(233, 272), Vector2(233, 361),
		Vector2(233, 467), Vector2(233, 571)],
	"joey": [Vector2(235, 88), Vector2(235, 135), Vector2(235, 182),
		Vector2(235, 229), Vector2(235, 276), Vector2(235, 363),
		Vector2(235, 469), Vector2(235, 575)],
}
## Superficies de dos casillas: Y44fdf0, Ka451850, Jo463470.
## Coordenadas acreditadas por glifos bitmap de las capturas retail.
const COUNTER_TOP := {
	"yugi": [248, 80, 357, 463, 569], "kaiba": [244, 78, 355, 461, 565],
	"joey": [244, 78, 353, 459, 565],
}
## Filtros pequenos de la cabecera de la bolsa.
const FILTER_BUTTONS := ["kbtn_all", "kbtn_nor", "kbtn_eff", "kbtn_fus", "kbtn_mag", "kbtn_trp", "kbtn_rit"]
## PE Y59bcd0 / Ka59eda8 / Jo5db6a0; 4538a0 mueve estos7 objetos.
const FILTER_BUTTON_POS := {
	"yugi": [Vector2(623,6), Vector2(652,6), Vector2(678,6), Vector2(705,6), Vector2(652,18), Vector2(678,18), Vector2(705,18)],
	"kaiba": [Vector2(627,6), Vector2(652,6), Vector2(677,6), Vector2(702,6), Vector2(652,18), Vector2(677,18), Vector2(702,18)],
	"joey": [Vector2(628,9), Vector2(653,9), Vector2(678,9), Vector2(703,9), Vector2(653,21), Vector2(678,21), Vector2(703,21)],
}

## 44b8c0/455720: fila r de la bolsa con centro (687 + W/2, 39 + 56 r + H/2) relativo a
## DAT_005af83c; se dibuja y se choca al 70 % desde la esquina superior izquierda (44c6a0).
const BAG_X := 687
const BAG_Y := 39
const TRUNK_PITCH := 56
const TRUNK_ROWS := 10
const THUMB := Vector2(35, 50)
const STATS_RIGHT_COLLAPSED := 74.0        # 44ce00: cache en680, x54 + cuatro glifos6.

## Filtros en el orden de la tira icon_syurui_? (TODOS, NORMAL, EFECTO, FUSION, CONJURO,
## TRAMPA, RITUAL) y su grupo de CardDB.
const FILTERS := ["all", "normal", "effect", "fusion", "spell", "trap", "ritual"]
## Ordenes; posicion en la tira icon_sort (ABC, hacha, escudo, persona, colores, sol, cartas)
const SORTS := ["default", "name", "type", "atk", "attribute", "def", "level"]
const SORT_ICON := {"name": 0, "atk": 1, "def": 2, "type": 3, "attribute": 4, "level": 5, "default": 6}
## Botones de la ventana de orden (filters_btn_*), posiciones medidas en w_filter_small
const SORT_BUTTONS := [
	["name", "filters_btn_nam", Vector2(71, 13)], ["type", "filters_btn_typ", Vector2(224, 13)],
	["atk", "filters_btn_atk", Vector2(71, 46)], ["attribute", "filters_btn_atr", Vector2(208, 46)],
	["def", "filters_btn_def", Vector2(71, 81)], ["level", "filters_btn_lev", Vector2(224, 81)],
]
## Tablas nativas Y59bd50, Ka59ee28, Jo5db720; orden Nombre,Tipo,ATK,Atributo,DEF,Nivel.
const SORT_POS := {
	"yugi": [Vector2(71,13),Vector2(224,13),Vector2(71,46),Vector2(208,46),Vector2(71,81),Vector2(224,81)],
	"kaiba": [Vector2(34,30),Vector2(212,30),Vector2(34,63),Vector2(212,63),Vector2(34,96),Vector2(212,96)],
	"joey": [Vector2(38,23),Vector2(209,23),Vector2(38,61),Vector2(209,61),Vector2(38,99),Vector2(209,99)],
}

const BIG_CARD_POS := Vector2(7, 89)
const TEXT_BOX := {
	"yugi": Rect2(8, 381, 178, 162), "kaiba": Rect2(8, 384, 179, 157), "joey": Rect2(4, 378, 192, 163),
}
## Colores del texto de detalle: los del motor (etiquetas <FONT color> del ejecutable).
## Joey tiene el panel claro, asi que va en oscuro.
const TEXT_COLORS := {
	"yugi": {"name": "#ffff00", "type": "#00ff00", "body": "#ffffff", "stats": "#ffff00"},
	"kaiba": {"name": "#ffff00", "type": "#00ff00", "body": "#ffffff", "stats": "#ffff00"},
	# Jo46f1d0: COLORREF007e3510/0000007e/00101010/00101010.
	"joey": {"name": "#10357e", "type": "#7e0000", "body": "#101010", "stats": "#101010"},
}
## Color del nombre en la bolsa desplegada (papel en Yugi, franjas oscuras en Kaiba y Joey)
const TRUNK_NAME_COLOR := {"yugi": Color8(70, 30, 10), "kaiba": Color.WHITE, "joey": Color.YELLOW}

const MAIN_MIN := 40
const MAIN_MAX := 80
const SIDE_MAX := 15
const SWAP_ARROW_EDGE := {"yugi": Vector2(800, 280), "kaiba": Vector2(798, 298), "joey": Vector2(800, 295)}
const MAX_COPIES := CARD_LIMITS.MAX_COPIES
## IDs CARD_ID (los mismos que .ydc), extraidos de las tablas del PE.
const OLD_FORBIDDEN := CARD_LIMITS.OLD_FORBIDDEN
const OLD_LIMITED := CARD_LIMITS.OLD_LIMITED
const JOEY_FORBIDDEN := CARD_LIMITS.JOEY_FORBIDDEN
const JOEY_LIMITED := CARD_LIMITS.JOEY_LIMITED
## 448e80/44a400/4673b0: las versiones alternativas comparten copias.
const COPY_VARIANTS := CARD_LIMITS.COPY_VARIANTS
const FADED := Color(1, 1, 1, 0x6e / 255.0)   # 44c8a0: alfa 0x6e
const DECKS_DIR := "decks"
## Cursor del raton (objeto DAT_005af868, +0x114): recurso 0xd ("over") si el destino no vale.
const CURSOR_OVER := 0xd

var game: String
var _dir := ""
var _scripts := {}                 # nombre de script -> Layout
var _deck := {"main": [], "side": [], "fusion": []}
var _trunk: Array[Dictionary] = []  # cartas usables que se tienen
var _view: Array[Dictionary] = []   # la bolsa tras filtro y orden
var _filter := "all"
var _sort := "default"
var _expanded := false
var _bag_progress := 0             # Y4538a0 +11c: 0..256, 25 por tick
var _bag_direction := 0            # +118: 1 abre, 2 cierra
var _bag_flights: Array[Dictionary] = []  # 4551b0: objeto temporal, prioridad3000
var _replacement := {}              # 457270 estados1..3: mazo pendiente tras importar
var _replacement_phase := 0
var _trunk_scroll := 0
var _nav_region := 0
var _nav_indices := [0,0,0,0,0]
var _nav_hold_age := 0
var _nav_keys_held := {}
var _focus := "trunk"              # "trunk", "deck" o "none" (navegacion con flechas)
var _trunk_cursor := 0
var _deck_cursor := {"zone": "main", "index": 0}
var _hover := ""                   # boton bajo el raton
var _pressed := ""
var _modal: Node = null
var _new_rows := {}                 # 44f920/447ed0/44ea60: estado NEW por fila
var _dirty := false
var _swap := false
var _swap_initial_main := 0
var _swap_transition := preload("res://scenes/deck_editor/swap_arrow_transition.gd").new()
var _swap_surface_cache := {}
var _detail_flip = preload("res://core/editor_card_flip.gd").new()
var _detail_card := {}             # carta mostrada en el panel izquierdo
var _trunk_sprites: Array[Sprite2D] = []   # fondo de la bolsa, sombra y barra (se mueven)
var _deck_layer := Node2D.new()   # cartas del mazo, por debajo de la bolsa

# --- estado del raton del original (objeto mazo DAT_005af824) ---------------------------
## Cada carta del mazo lleva un identificador propio (paralelo a _deck) para que marcas,
## carta retenida y animaciones la sigan al reordenar. Las filas de la bolsa usan -(id+1).
var _uids := {"main": [], "side": [], "fusion": []}
var _next_uid := 1
var _marks := {}                   # +0x44: claves marcadas
var _held := 0                     # DAT_005af834 / +0xcc4: carta retenida (0 = ninguna)
var _grab := 0                     # DAT_005af82c: carta senalada o agarrada
var _toggle := false               # +0xcc0
var _dragging := false             # DAT_005af829
var _animating := false            # DAT_005af828: alguna carta se movia en el tick anterior
var _sel_zone := -1                # +0xcac: zona de la seleccion
var _src_zone := -1                # +0x224: zona de origen del arrastre
var _src_index := -1               # +0x220
var _anchor := {"zone": -1, "index": -1}   # +0x1c8 / +0x1c0 (Shift+clic)
var _rect_state := 0               # +0xb2c: rectangulo de seleccion (0..4)
var _rect_active := false
var _rect_start := Vector2.ZERO
var _rect := Rect2()
var _over_zone := -99              # +0x970: ultima zona evaluada para el cursor
var _cursor_over := false
var _offsets := {}                 # +0x94/+0x98: desfase carta - raton al agarrar
var _pos := {}                     # uid -> centro actual (+0x60/+0x64)
var _anim := {}                    # uid -> {from, to, v} (4474a0, 8 pasos)
var _bag_clone := {}               # 455720: copia translucida en la fila de la bolsa
var _held_phase := 0               # +0x124: pulso del marco de la carta retenida
## El original avanza +0x124 en cada dibujo, y dibuja una vez por tick: aqui los dibujos de un
## fotograma parten de _held_phase y el tick siguiente se queda con lo que avanzaron.
var _pulse_phase := 0
## Cartas que se recolocan (4474a0, 8 pasos) mezcladas entre ticks, por uid.
var _blend := NativeBlend.new()
var _undo: Array = []              # 4523a0/4532f0
var _undo_at := 0
var _still := 0                    # +0x5924 (+0x4f8 en el intercambio)
var _last_mouse := Vector2(-1, -1)
var _mouse := Vector2(-1000, -1000)
var _deck_frame: Sprite2D
var _file_dialog: PocDialog
var _latch := {"lp": false, "rp": false, "lr": false, "rr": false}
var _keys_down := {}               # teclas pulsadas en este tick
var _key_override := {}            # pruebas: Key -> mantenida
var _clock := 0.0
var _glide := {}
var _cursor = preload("res://scenes/duel/duel_cursor_visual.gd").new()

var _font_big: DigitFont
var _font_big_red: DigitFont
var _font_small: DigitFont
var _font_stats: DigitFont
var _font_level: DigitFont
var _text_font := SystemFont.new()
var _trunk_name_font := SystemFont.new()
var _detail := RichTextLabel.new()
var _detail_reveal := preload("res://core/card_detail_reveal.gd").new()
var _stats := Label.new()
var _detail_clip: Control
var _detail_scroll: NativeScrollBar
var _trunk_bar: NativeScrollBar
var _detail_height := 0


func _init(game_id: String, mode := "edit") -> void:
	game = game_id
	_swap_transition.variant = game_id
	_swap = mode == "swap"
	_dir = "%s/deck_c/" % game


func _ready() -> void:
	for name in ["kabegami", "kaban_list", "kaban_detail", "kaban_bar", "font", "btn_back",
			"btn_load", "btn_save", "deckerror", "15deckerror", "kbtn_all", "kbtn_win", "kbtn_nor",
			"kbtn_eff", "kbtn_fus", "kbtn_mag", "kbtn_trp", "kbtn_rit", "filter", "export", "import",
			"overwrite", "success", "warning", "dlg_ow_ok", "dlg_ow_cancel", "dlg_ok_ok_export",
			"dlg_ok_ok_derr", "dlg_ok_ok_chgerr", "dlg_ok_ok_cerr", "filters_btn_nam",
			"filters_btn_typ", "filters_btn_atk", "filters_btn_atr", "filters_btn_def",
			"filters_btn_lev", "kaban_swap", "swapdeckerror", "dlg_text_ok", "line"]:
		_scripts[name] = Assets.layout(_dir + name + ".txt")
	# estos scripts van por idioma (Joey solo los trae en ingles): "?" usa el de reserva
	for name in ["dlg_export_ok", "dlg_export_cancel", "dlg_import_ok", "dlg_import_cancel"]:
		_scripts[name] = Assets.layout("%s%s_?.txt" % [_dir, name])
	_text_font.font_names = PackedStringArray(["Arial", "Liberation Sans", "Roboto", "sans-serif"])
	_trunk_name_font.font_names = _text_font.font_names
	_trunk_name_font.font_weight = 700
	# Y457ae0 (constructor de la bolsa) pone a 0 el estado y el progreso del despliegue
	# (+0x118/+0x11c) y Y458410 a 0 DAT_005af83c: se entra siempre con la bolsa plegada.
	_expanded = false
	_mouse = PlatformInput.cursor # el raton nativo conserva la posicion entre escenas.
	# 456e70/458940/463d60 construyen la vista de bolsa con criterio1 (nombre).
	_sort = "name"
	_load_deck()
	_swap_initial_main = _deck["main"].size()
	_build_trunk()
	_build_static()
	if not _swap:
		_trunk_bar = NativeScrollBar.new(game, "kaban_bar")
		# Constructores Y455990/Ka457460/Jo46dfa0, no la bolsa que se desplaza.
		_trunk_bar.position = {"yugi": Vector2(777, 49), "kaiba": Vector2(780, 52), "joey": Vector2(775, 50)}[game]
		_trunk_bar.track = 466 if game == "joey" else 503
		_trunk_bar.step = 5 if game == "joey" else 3
		_trunk_bar._thickness = _trunk_bar._textures[2].get_width()
		_trunk_bar.scrolled.connect(func(value: int): _trunk_scroll = value)
		add_child(_trunk_bar)
	var font: Layout = _scripts["font"]
	_font_big = DigitFont.new(_tex(font.resource(0)), null, "", null, 9 if game == "joey" else 10)
	_font_big_red = DigitFont.new(_tex(font.resource(1)), null, "", null, 9 if game == "joey" else 10)
	_font_small = DigitFont.new(_tex(font.resource(2)), null, "", null, 9)
	_font_stats = DigitFont.new(_tex(font.resource(5)), _tex(_scripts["kaban_list"].resource(4)), "/", "06", 6)
	_build_detail()
	_apply_view()
	_sync_uids()
	_relayout(true)
	if _swap:
		_focus = "deck"
		_move_deck_zone(0)
		_show_detail(_deck_card())
	else:
		# Y45a7d0: la carta senalada (DAT_005af82c) sale de la que hay bajo el puntero y
		# empieza nula, asi que el panel muestra el reverso y la bolsa no lleva marco.
		_focus = "none"
		_show_detail({})
	_cursor.z_index = 4000
	add_child(_cursor)
	Audio.play_music("%s/voice/stream/%s" % [game, "kaban.wav" if game == "yugi" else "m_kaban.wav"])


# --- datos ---------------------------------------------------------------------------------

func _load_deck() -> void:
	var saved := SaveData.deck(game)
	for zone in ["main", "side", "fusion"]:
		var ids: Array = []
		for id in saved.get(zone, []):
			ids.append(int(id))
		_deck[zone] = ids
		_deck_criteria[zone] = "default"
	if not _swap:
		# 458610 ->436e80: Deck.ydc activo tambien figura en el catalogo publico.
		Ydc.save(_decks_dir().path_join("Deck.ydc"), _deck, SaveData.deck_file_header())
	_sort_deck()


func _build_trunk() -> void:
	_trunk.clear()
	for card in CardDB.usable_in(game):
		if card["image"] != null and SaveData.card_count(int(card["internal_id"])) > 0:
			_trunk.append(card)


## Aplica filtro y orden a la bolsa, conservando la carta seleccionada si sigue visible.
func _apply_view() -> void:
	var current := _trunk_card()
	_view.clear()
	for card in _trunk:
		if _filter == "all" or CardDB.group_of(card) == _filter_group(_filter):
			_view.append(card)
	if _sort != "default":
		_sort_records(_view, func(card): return _native_sort_key(card, _sort))
	_trunk_cursor = maxi(0, _view.find(current)) if not current.is_empty() else 0
	_trunk_scroll = clampi(_trunk_cursor - TRUNK_ROWS / 2, 0, maxi(0, _view.size() - TRUNK_ROWS))


func _filter_group(filter: String) -> int:
	match filter:
		"normal":
			return CardDB.Group.NORMAL
		"effect":
			return CardDB.Group.EFFECT
		"fusion":
			return CardDB.Group.FUSION
		"spell":
			return CardDB.Group.SPELL
		"trap":
			return CardDB.Group.TRAP
	return CardDB.Group.RITUAL


## 401860/401060: prioridad de nombre por CARD_ID, no texto Unicode.
func _native_sort_key(card: Dictionary, criterion: String) -> int:
	var index := int(card.get("index", 0))
	var kind := int(card.get("type_id", 0))
	match criterion:
		"name":
			var language: String = Assets.text_language()
			if not _name_ranks.has(language):
				_name_ranks[language] = FileAccess.get_file_as_bytes(Assets.resolve("common/bin/card_sort%s.bin" % language))
			var ranks: PackedByteArray = _name_ranks[language]
			return ranks.decode_u16(index * 2) if index * 2 + 2 <= ranks.size() else 0
		"type": return kind
		"attribute":
			if _sort_properties.is_empty():
				_sort_properties = FileAccess.get_file_as_bytes(Assets.resolve("common/bin/card_prop.bin"))
			return _sort_properties.decode_u32(index * 4) >> 29 if index * 4 + 4 <= _sort_properties.size() else 0
		"atk": return -_native_deck_atk(card)
		"def": return 0 if kind in [21,22,23] else -(4000 if kind == 24 else int(card.get("defense", 0)))
		"level": return 0 if kind in [21,22,23] else -(10 if kind == 24 else int(card.get("level", 0)))
	return _native_deck_group(card)

func _sort_records(items: Array, key: Callable, first := 0, last := -1) -> void:
	if game == "joey": NATIVE_SORT.sort_joey(items, key, first, last)
	else: NATIVE_SORT.sort_records(items, key, first, last)


func _trunk_order(a: Dictionary, b: Dictionary) -> bool:
	return _native_sort_key(a, _sort) < _native_sort_key(b, _sort)


func _copies_used(id: int) -> int:
	var n := 0
	for zone in _deck:
		n += _deck[zone].count(id)
	return n


func _remaining(id: int) -> int:
	return SaveData.card_count(id) - _copies_used(id)


## Ordena cada zona y lleva con cada carta su identificador.
func _sort_deck(zones: Array = ZONES) -> void:
	_sync_uids()
	for zone in zones:
		var selected: String = _deck_criteria[zone]
		# 44ae70 mueve registros (ID,cantidad,offset), luego expande las copias.
		var records: Array = []
		var by_id := {}
		for i in _deck[zone].size():
			var id: int = _deck[zone][i]
			if not by_id.has(id):
				by_id[id] = {"card": CardDB.by_id(id), "id": id, "uids": []}
				records.append(by_id[id])
			by_id[id].uids.append(_uids[zone][i])
		if selected == "name":
			_sort_records(records, func(r): return _native_sort_key(r.card, "name"))
		else:
			_sort_records(records, func(r): return _native_deck_group(r.card))
			var first := 0
			while first < records.size():
				var last := first
				while last + 1 < records.size() and _native_deck_group(records[last + 1].card) == _native_deck_group(records[first].card): last += 1
				var criterion := "atk" if selected == "default" else "name"
				_sort_records(records, func(r): return _native_sort_key(r.card, criterion), first, last)
				first = last + 1
			if selected != "default":
				var monster_end := -1
				while monster_end + 1 < records.size() and _native_deck_group(records[monster_end + 1].card) <= 6: monster_end += 1
				if monster_end >= 1:
					_sort_records(records, func(r): return _native_sort_key(r.card, selected), 0, monster_end)
		_deck[zone] = []
		_uids[zone] = []
		for record in records:
			for uid in record.uids:
				_deck[zone].append(record.id)
				_uids[zone].append(uid)


## Las pruebas (y la importacion) sustituyen _deck entero: se rehacen los identificadores.
func _sync_uids() -> void:
	for zone in _deck:
		if _uids[zone].size() != _deck[zone].size():
			_uids[zone] = []
			for i in _deck[zone].size():
				_uids[zone].append(_next_uid)
				_next_uid += 1


func _deck_order(a: int, b: int) -> bool:
	var ca := CardDB.by_id(a)
	var cb := CardDB.by_id(b)
	# 44fd40/Ka4517a0/Jo4633d0: grupo7, despues ATK2 dentro de cada grupo.
	var ga := _native_deck_group(ca)
	var gb := _native_deck_group(cb)
	if ga != gb:
		return ga < gb
	return _native_deck_atk(ca) > _native_deck_atk(cb)


## 541950: clase2bits, hechizos7/trampas8/tipo23=9; excepciones por CARD_ID.
func _native_deck_group(card: Dictionary) -> int:
	var id := int(card.get("internal_id", -1))
	if id == 0x776:
		return 3
	if id in [0x777, 0x778]:
		return 1
	match int(card.get("type_id", 0)):
		21: return 8
		22: return 7
		23: return 9
	return int(card.get("kind_bits", 0))


## 445810/446d30: tipo21..23=0, tipo24=4000; resto bits ATK*10.
func _native_deck_atk(card: Dictionary) -> int:
	var kind := int(card.get("type_id", 0))
	if kind in [21, 22, 23]:
		return 0
	return 4000 if kind == 24 else int(card.get("atk", 0))


func _trunk_card() -> Dictionary:
	return _view[_trunk_cursor] if _trunk_cursor < _view.size() else {}


func _save_settings() -> void:
	var settings: Dictionary = SaveData.data.get_or_add("settings", {})
	settings["deck_sort"] = _sort


# --- construccion --------------------------------------------------------------------------

func _tex(resource: String) -> Texture2D:
	return Assets.texture(_dir + resource)


func _script_tex(script: String, index: int) -> Texture2D:
	return _tex(_scripts[script].resource(index))


func _build_static() -> void:
	var list: Layout = _scripts["kaban_list"]
	if _swap:
		var kabegami: Layout = _scripts["kabegami"]
		# Ka45b7ff/45b80f selecciona21 (kabegami_c), no0 (kabegami_c_2).
		# Y459c10 y Jo4763d2/4763d7 usan0.
		_add_sprite(_tex(kabegami.resource(21 if game == "kaiba" else 0)), Vector2(217, 0))
		var right := _tex(kabegami.resource(0x12))
		_add_sprite(right, Vector2(800 - right.get_width(), 0))
		_add_sprite(_script_tex("kaban_swap", 0), Vector2.ZERO)
		add_child(_deck_layer)   # sin bolsa: el mazo lo dibuja _draw_swap
		return
	# Y459c10, Ka45d523/45d5a7/45d64a y Jo46e7c2: fondo en(217,0).
	_add_sprite(_tex(_scripts["kabegami"].resource(0)), Vector2(217, 0))
	if game == "kaiba":
		# Ka45d579: YGA del tramo derecho del marco, antes de cartas y bolsa.
		_deck_frame = _add_sprite(_tex(_scripts["kabegami"].resource(20)), Vector2(375, 0))
	# las cartas del mazo van entre el fondo y la bolsa, que las tapa al desplegarse
	_deck_layer.show_behind_parent = true
	_deck_layer.draw.connect(func() -> void: _draw_deck(_deck_layer))
	add_child(_deck_layer)
	for i in [0, 3, 1]:   # bolsa, sombra, barra: se recolocan al plegar/desplegar
		# Joey declara una sombra ausente; se conserva el sprite opcional nulo.
		if game == "joey" and i == 3 and not Assets.exists(_dir + list.resource(i)):
			continue
		var s := _add_sprite(_tex(list.resource(i)), Vector2.ZERO)
		if s != null:
			s.set_meta("part", i)
			_trunk_sprites.append(s)
	_add_sprite(_tex(_scripts["kaban_detail"].resource(0)), Vector2.ZERO)
	_place_trunk()


func _place_trunk() -> void:
	if _deck_frame != null:
		_deck_frame.region_enabled = true
		_deck_frame.region_rect = Rect2(-_bag_shift(), 0, _deck_frame.texture.get_width() + _bag_shift(), 600)
	var kx := _kaban_x()
	for s in _trunk_sprites:
		match int(s.get_meta("part")):
			0:
				s.position = Vector2(kx - 4, 0) # cache44d0c0/46ddb0 en680, separado del control684.
			3:
				s.position = Vector2(RIGHT_X[_expanded] - 4, 0) # sombra fija765, vtable+4c.
			1:
				s.position = Vector2(RIGHT_X[_expanded], 0)


func _add_sprite(tex: Texture2D, pos: Vector2) -> Sprite2D:
	if tex == null:   # p. ej. Joey no trae la sombra kaban_kage
		return null
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = pos
	s.show_behind_parent = true   # el _draw() (cartas, cifras) va encima
	add_child(s)
	return s


func _build_detail() -> void:
	var box: Rect2 = TEXT_BOX[game].grow(-4)
	var bold := SystemFont.new()
	bold.font_names = _text_font.font_names
	bold.font_weight = 700
	_detail.position = box.position
	_detail.size = box.size - Vector2(0, 16)
	_detail.bbcode_enabled = true
	_detail.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_detail.scroll_active = false
	_detail.clip_contents = true
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_theme_font_override("normal_font", _text_font)
	_detail.add_theme_font_override("bold_font", bold)
	for key in ["normal_font_size", "bold_font_size"]:
		_detail.add_theme_font_size_override(key, 12)
	_detail.add_theme_constant_override("line_separation", 5)
	add_child(_detail)
	_stats.position = Vector2(box.position.x, box.end.y - 15)
	_stats.size = Vector2(box.size.x, 15)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats.add_theme_font_override("font", _text_font)
	_stats.add_theme_font_size_override("font_size", 12)
	_stats.add_theme_color_override("font_color", Color(TEXT_COLORS[game]["stats"]))
	add_child(_stats)
	if game in ["yugi", "kaiba", "joey"]:
		# Y455b70, Ka457640, Jo46ee40: rectangulo y barra propios.
		var native_box: Rect2 = {"yugi": Rect2(12, 387, 170, 153),
			"kaiba": Rect2(17, 390, 163, 150), "joey": Rect2(17, 390, 163, 148)}[game]
		_detail_clip = Control.new()
		_detail_clip.position = native_box.position
		_detail_clip.size = native_box.size
		_detail_clip.clip_contents = true
		_detail_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_detail_clip)
		_detail.reparent(_detail_clip)
		_detail.position = Vector2.ZERO
		_detail.size = native_box.size
		_detail.fit_content = true
		var stats_height := 14 if game == "joey" else 13
		_stats.position = Vector2(native_box.position.x, native_box.end.y - stats_height)
		_stats.size = Vector2(native_box.size.x, stats_height)
		_detail_scroll = NativeScrollBar.new(game, "detail_bar")
		_detail_scroll.position = {"yugi": Vector2(191, 382),
			"kaiba": Vector2(193, 383), "joey": Vector2(191, 391)}[game]
		_detail_scroll.track = {"yugi": 134, "kaiba": 137, "joey": 110}[game]
		_detail_scroll.step = 19
		_detail_scroll.scrolled.connect(func(value: int): _detail.position.y = -value)
		add_child(_detail_scroll)

func _update_detail_scroll() -> void:
	if _detail_scroll == null: return
	var height := _detail.get_content_height()
	if height != _detail_height:
		_detail_height = height
		_detail_scroll.set_range(height - int(_detail_clip.size.y))


func _show_detail(card: Dictionary) -> void:
	if card == _detail_card: return
	if _detail_scroll != null and card != _detail_card:
		_detail_scroll.set_value(0)
		_detail_height = -1
		var full_height: int = {"yugi": 153, "kaiba": 150, "joey": 148}[game]
		_detail_clip.size.y = full_height - (15 if game == "joey" else 14) \
			if card.get("category", "") == "monster" else full_height
	_detail_flip.request(int(card.get("internal_id", -1)))
	_detail_card = card
	if card.is_empty():
		_detail.text = ""
		_detail_reveal.reset("", false)
		_detail.visible_characters = 0
		_stats.text = ""
		queue_redraw()
		return
	var c: Dictionary = TEXT_COLORS[game]
	_detail.text = "[color=%s][b]%s[/b][/color]\n" % [c["name"], CardDB.text(card, "names")]
	# 412410 solo incluye la linea de tipo para monstruos (tipo nativo1..20).
	if card["category"] == "monster":
		_detail.text += "[color=%s]%s[/color]\n" % [c["type"], CardDB.type_text(card)]
	_detail.text += "[color=%s]%s[/color]" % [c["body"], CardDB.text(card, "descriptions")]
	_detail_reveal.reset(_detail.get_parsed_text(), Assets.lang == "j")
	_detail.visible_characters = 0
	_stats.text = "ATK/%4d DEF/%4d" % [card["atk"], card["defense"]] \
			if card["category"] == "monster" else ""
	SaveData.mark_seen(int(card["internal_id"]))
	queue_redraw()


# --- geometria -------------------------------------------------------------------------

func _kaban_x() -> float:
	return KABAN_X[false] + _bag_shift()


## DAT_005af83c: 0 con la bolsa plegada, -100 desplegada.
func _bag_shift() -> int:
	return -(mini(128, _bag_progress) * 100 / 128)


## Y4538a0/Ka455350: 11 ticks completos; el desplazamiento acaba al sexto.
func _advance_bag() -> void:
	if _bag_direction == 0:
		return
	_bag_progress = clampi(_bag_progress + (25 if _bag_direction == 1 else -25), 0, 256)
	if _bag_progress in [0, 256]:
		_bag_direction = 0
	_place_trunk()


## 0x4472b0: 3 bolsa, -1 panel izquierdo, 0 principal, 1 Side, 2 Fusion. En el intercambio
## (+0x96c = 1) el limite de la bolsa no se desplaza.
func _zone_at(p: Vector2) -> int:
	var x := int(p.x)
	var y := int(p.y)
	if x > ZONE_BAG_X + (0 if _swap else _bag_shift()):
		return BAG
	if x < ZONE_LEFT:
		return -1
	if y < ZONE_MAIN_Y:
		return 0
	return 1 if y < ZONE_SIDE_Y else 2


## Paso horizontal y vertical de una zona y cartas por fila (Y44b3e0 guarda estas en +0x1d4
## para la zona principal: hueco / paso + 1).
func _row_layout(zone: String) -> Dictionary:
	var z: Array = DECK_ZONES.get(game, DECK_ZONES["yugi"])[zone]
	var count: int = maxi(1, _deck[zone].size())
	# 45b6e0 +4a50: el margen derecho pasa a-100 al desplegar (las tres zonas).
	var gap: int = z[2] - z[0] - CARD_W - (100 if _expanded and not _swap else 0)
	var rows: int = z[4]
	var pitch: int
	if count <= z[5]:
		pitch = (CARD_W / 2 + gap) / 10
	elif game == "joey":
		pitch = gap / maxi(1, (count - 1) / rows)
	else:
		pitch = gap * rows / count
	pitch = maxi(1, pitch)
	var row_pitch: int = 0 if rows == 1 else ((rows - 1) / 2 + z[3] - z[1] - CARD_H) / (rows - 1)
	return {"pitch": pitch, "row_pitch": row_pitch, "per_row": gap / pitch + 1, "gap": gap}


## Esquina superior izquierda de destino de la carta index de la zona (44b3e0).
func _deck_card_pos(zone: String, index: int) -> Vector2:
	var z: Array = DECK_ZONES.get(game, DECK_ZONES["yugi"])[zone]
	var l := _row_layout(zone)
	var per_row: int = l["per_row"]
	return Vector2(z[0] + (index % per_row) * int(l["pitch"]), z[1] + (index / per_row) * int(l["row_pitch"]))


## +0x1d4: cartas por fila del mazo principal.
func _per_row() -> int:
	return _row_layout("main")["per_row"]


## Recoloca las cartas (44b8c0 -> 44b3e0): las que cambian de sitio se deslizan.
func _relayout(instant := false) -> void:
	_sync_uids()
	for zone in ZONES:
		var uids: Array = _uids[zone]
		for i in uids.size():
			var uid: int = uids[i]
			var to := _deck_card_pos(zone, i) + Vector2(CARD_W / 2, CARD_H / 2)
			if instant or not _pos.has(uid):
				_pos[uid] = to
				_anim.erase(uid)
			elif _anim.has(uid):
				if _anim[uid]["to"] != to:
					_anim[uid] = {"from": _pos[uid], "to": to, "v": 0}
			elif _pos[uid] != to:
				_anim[uid] = {"from": _pos[uid], "to": to, "v": 0}


## 4474a0 estado 0: +0x20 por tick hasta 0x100 con T[v/2 - 0x80] (coseno, 5325a0).
func _advance_anims() -> void:
	_animating = false
	for uid in _anim.keys():
		var a: Dictionary = _anim[uid]
		if a.has("mode"):
			CardMotion.tick(a)
			_pos[uid] = a.center
			if a.done and a.mode == 1:
				_anim.erase(uid)
			_animating = _animating or not a.done
			continue
		a["v"] += 0x20
		# 4474a0/4484f0/46b090 comparan la posicion del tick anterior.
		# Un salto corto puede llegar por truncado antes del octavo tick.
		if a["v"] >= 0x100 or _pos[uid] == a["to"]:
			_pos[uid] = a["to"]
			_anim.erase(uid)
		else:
			_pos[uid] = DuelVisualMath.interpolate_fx(a["from"], a["to"],
					DuelVisualMath.cos_fx(int(a["v"]) / 2 - 0x80))
			_animating = true
	for i in range(_bag_flights.size() - 1, -1, -1):
		var flight := _bag_flights[i]
		flight.v += 0x20
		if flight.v >= 0x100:
			_bag_flights.remove_at(i)
		else:
			flight.center = DuelVisualMath.interpolate_fx(flight.from, Vector2(900, 300),
				DuelVisualMath.cos_fx(int(flight.v) / 2 - 0x80))
		_animating = true


func _card_center(z: int, index: int) -> Vector2:
	var uid: int = _uids[ZONES[z]][index]
	return _pos.get(uid, _deck_card_pos(ZONES[z], index) + Vector2(CARD_W / 2, CARD_H / 2))


## Centro de la fila r de la bolsa.
func _bag_center(row: int) -> Vector2:
	var origin := Vector2(691, 40) if game == "joey" else Vector2(BAG_X, BAG_Y)
	return origin + Vector2(_bag_shift() + CARD_W / 2, row * _trunk_pitch() + CARD_H / 2)

func _trunk_pitch() -> int:
	return 55 if game == "joey" else TRUNK_PITCH


func _trunk_pos(row: int) -> Vector2:
	return _bag_center(row) - Vector2(CARD_W / 2, CARD_H / 2)


## 44c6a0: caja completa centrada en el mazo; en la bolsa el 70 % desde arriba a la izquierda.
func _hit_box(z: int, center: Vector2) -> Rect2:
	var corner := center - Vector2(CARD_W / 2, CARD_H / 2)
	if z == BAG:
		return Rect2(corner, Vector2(CARD_W * 7 / 10, CARD_H * 7 / 10))
	return Rect2(corner, Vector2(CARD_W, CARD_H))


func _bag_rows() -> int:
	return 0 if _swap else clampi(_view.size() - _trunk_scroll, 0, TRUNK_ROWS)


func _bag_key(row: int) -> int:
	return -(int(_view[_trunk_scroll + row]["internal_id"]) + 1)


## Carta bajo el puntero: se recorren las zonas 0..3 en orden y gana la ultima que choca
## (bucle de 45a7d0).
func _hit_at(p: Vector2) -> Dictionary:
	var hit := {}
	for z in 3:
		for i in _deck[ZONES[z]].size():
			var uid: int = _uids[ZONES[z]][i]
			if _anim.has(uid) and not _anim[uid].get("done", false): continue # 44c6a0 rechaza actividad.
			if _hit_box(z, _card_center(z, i)).has_point(p):
				hit = {"key": _uids[ZONES[z]][i], "zone": z, "index": i}
	for r in _bag_rows():
		# 4474a0 con contador256 proyecta target+shift a +60 antes del choque44c6a0.
		if _hit_box(BAG, _bag_center(r)).has_point(p):
			hit = {"key": _bag_key(r), "zone": BAG, "index": r}
	return hit


func _key_id(key: int) -> int:
	if key < 0:
		return -key - 1
	for z in ZONES:
		var i: int = _uids[z].find(key)
		if i != -1:
			return _deck[z][i]
	return -1


func _key_zone(key: int) -> int:
	if key < 0:
		return BAG
	for z in 3:
		if _uids[ZONES[z]].has(key):
			return z
	return -1


## Botones con su rectangulo en pantalla e imagenes On/Push.
func _buttons() -> Dictionary:
	var out := {}
	if _swap:
		var l: Layout = _scripts["btn_back"]
		out["btn_back"] = {"rect": Rect2(Vector2(l.position(0)), _tex(l.resource(0)).get_size()),
				"on": _tex(l.resource(0)), "push": _tex(l.resource(1))}
		var arrow := _script_tex("kaban_swap", 2)
		out["swap_arrow"] = {"rect": Rect2(SWAP_ARROW_EDGE[game] - Vector2(arrow.get_width(), 0), arrow.get_size()),
				"on": null, "push": null}
		return out
	for name in ["btn_back", "btn_load", "btn_save"]:
		var l: Layout = _scripts[name]
		out[name] = {"rect": Rect2(Vector2(l.position(0)), _tex(l.resource(0)).get_size()),
				"on": _tex(l.resource(0)), "push": _tex(l.resource(1))}
	for i in FILTER_BUTTONS.size():
		var control_y := -40 + maxi(0, _bag_progress - 128) * 40 / 128
		var native_pos: Vector2 = FILTER_BUTTON_POS[game][i] + Vector2(100 + _bag_shift(), control_y)
		out[FILTER_BUTTONS[i]] = _cap_button(FILTER_BUTTONS[i], native_pos)
	var win := _script_tex("kbtn_win", 0)
	# Y453b17, Ka4555c7, Jo46d197: el boton tiene su propio origen por variante.
	var win_offset: Vector2 = {"yugi": Vector2(0, 1), "kaiba": Vector2(4, 4), "joey": Vector2(4, 8)}[game]
	out["kbtn_win"] = {"rect": Rect2(Vector2(_kaban_x(), 0) + win_offset, win.get_size()), "on": win,
			"push": _script_tex("kbtn_win", 1)}
	if _bag_progress != 0:
		var control_y := -40 + maxi(0, _bag_progress - 128) * 40 / 128
		out["filter_label"] = {"rect": Rect2(_kaban_x() + 46, 4 + control_y, 90, 22), "on": null, "push": null}
		out["sort"] = {"rect": Rect2(_kaban_x() + 146, control_y, 30, 31), "on": null, "push": null}
	return out


func _cap_button(script: String, pos: Vector2) -> Dictionary:
	var on := _script_tex(script, 0)
	return {"rect": Rect2(pos, on.get_size()), "on": on, "push": _script_tex(script, 1)}


# --- dibujo -----------------------------------------------------------------------------

func _draw() -> void:
	if _swap:
		_draw_swap()
		return
	_draw_counters()
	_draw_trunk_header()
	# sin carta senalada, el reverso (card_ura)
	_draw_detail_card()
	var buttons := _buttons()
	for name in buttons:
		var b: Dictionary = buttons[name]
		var active := _filter_of_button(name) == _filter and _filter != "all"
		var tex: Texture2D = b["push"] if (_pressed == name or active) else (b["on"] if _hover == name else null)
		if tex != null:
			draw_texture(tex, b["rect"].position)
	_draw_top(self)
	_draw_rect_selection()


## Y44ed00/44ed90, Ka450150/4501e0 y Jo476d20/476db0: la flecha refleja
## el balance de cartas movidas, independiente de la carta senalada.
func _swap_balance() -> int:
	return _deck["main"].size() - _swap_initial_main

func _swap_valid() -> bool:
	return _swap_balance() == 0

func _swap_arrow_index() -> int:
	var balance := _swap_balance()
	if game == "joey" and balance == 0: return -1 # 476e80 omite superficie nueva.
	return 2 if balance > 0 else 4 if balance < 0 else 3

func _draw_swap() -> void:
	_draw_deck(self)
	_draw_counters()
	if not _detail_card.is_empty():
		_draw_detail_card()
	var buttons := _buttons()
	var back: Dictionary = buttons["btn_back"]
	var tex: Texture2D = back["push"] if _pressed == "btn_back" else (back["on"] if _hover == "btn_back" else null)
	if tex != null:
		draw_texture(tex, back["rect"].position)
	var index := _swap_arrow_index()
	if game in ["kaiba", "joey"]:
		_draw_swap_composition(self)
	elif game == "yugi":
		var width := _script_tex("kaban_swap", 2).get_width()
		var blend: NativeBlend = _swap_transition.blend
		for layer in _swap_transition.layers(game, width):
			var key := [_swap_transition.generation, layer.slot]
			if layer.get("kind", "") == "alpha":
				draw_rect(Rect2(layer.position, _script_tex("kaban_swap", 2).get_size()), Color(0, 0, 0, float(layer.alpha) / 255.0))
				continue
			if layer.get("kind", "") == "number":
				var strip := _tex(_scripts["font"].resource(layer.index))
				var pitch := 23 if layer.index == 12 else 21
				draw_texture_rect_region(strip, Rect2(layer.position, Vector2(pitch, strip.get_height())), Rect2((layer.value - 1) * pitch, 0, pitch, strip.get_height()))
				continue
			draw_texture(_script_tex("kaban_swap", layer.index), blend.at(key + ["p"], layer.position),
				Color(1, 1, 1, blend.at(key + ["a"], float(layer.alpha)) / 255.0))
	elif index >= 0:
		draw_texture(_script_tex("kaban_swap", index), buttons["swap_arrow"]["rect"].position)
	_draw_top(self)
	_draw_rect_selection()


func _draw_swap_composition(canvas: CanvasItem) -> void:
	var width := _script_tex("kaban_swap", 2).get_width()
	var commands: Array = _swap_transition.composition(game, width)
	for command: Dictionary in commands:
		if game == "kaiba" and command.kind == "number": continue
		var at: Vector2 = _swap_transition.blend.at([_swap_transition.generation, command.key], command.position)
		var tint := Color(1, 1, 1, float(command.alpha)/255.0)
		if command.kind == "number":
			var strip := _tex(_scripts["font"].resource(12))
			var pitch := int(command.pitch)
			canvas.draw_texture_rect_region(strip, Rect2(at, Vector2(pitch, strip.get_height())),
				Rect2((int(command.value)-1)*pitch, 0, pitch, strip.get_height()), tint)
			continue
		var texture := _script_tex("kaban_swap", int(command.index))
		if game == "kaiba" and command.has("group"):
			var numbers: Array = commands.filter(func(op: Dictionary) -> bool: return op.kind == "number" and op.group == command.group)
			if not numbers.is_empty():
				var number: Dictionary = numbers[0]
				var cache_key := Vector2i(int(command.index), int(number.value))
				if not _swap_surface_cache.has(cache_key):
					# El original compone cifra y fondo ANTES de aplicar el alfa de superficie.
					var image := texture.get_image()
					image.convert(Image.FORMAT_RGBA8)
					var strip := _tex(_scripts["font"].resource(12)).get_image()
					strip.convert(Image.FORMAT_RGBA8)
					image.blend_rect(strip, Rect2i((int(number.value)-1)*24, 0, 24, strip.get_height()), Vector2i(number.position-command.position))
					_swap_surface_cache[cache_key] = ImageTexture.create_from_image(image)
				texture = _swap_surface_cache[cache_key]
		var bounds: Array = command.get("rect", [])
		if bounds.is_empty(): canvas.draw_texture(texture, at, tint)
		else:
			var region := Rect2(int(bounds[0]), int(bounds[1]), int(bounds[2])-int(bounds[0]), int(bounds[3])-int(bounds[1]))
			var clipped := region.intersection(Rect2(Vector2.ZERO, texture.get_size()))
			if clipped.has_area():
				canvas.draw_texture_rect_region(texture, Rect2(at+clipped.position-region.position, clipped.size), clipped, tint)


func _draw_detail_card() -> void:
	var visual: Dictionary = _detail_flip.frame()
	if visual.width <= 0: return
	draw_texture_rect(CardDB.card_texture(int(visual.id)),
		Rect2(visual.x, BIG_CARD_POS.y, visual.width, 290), false,
		Color(1, 1, 1, float(visual.alpha) / 255.0))


func _filter_of_button(name: String) -> String:
	return {"kbtn_all": "all", "kbtn_nor": "normal", "kbtn_eff": "effect", "kbtn_fus": "fusion",
		"kbtn_mag": "spell", "kbtn_trp": "trap", "kbtn_rit": "ritual"}.get(name, "")


## Recurso k de kabegami.txt: 2-5 waku_l_4..1, 6-9 wakug_l, 10-13 waku_s, 14-17 wakug_s.
func _waku(k: int) -> Texture2D:
	var kinds := ["waku_l", "wakug_l", "waku_s", "wakug_s"]
	return _tex("kabegami/%s_%d.bmp" % [kinds[clampi((k - 2) / 4, 0, 3)], 4 - (k - 2) % 4])


## 44c7d0: marco de seleccion (recurso iVar1 + 2, 3 pixeles por fuera de la carta). Sin
## retener, iVar1 = 2; la carta retenida late con T[(fase & 0xff) - 0x80] * 4 (tope 3) mas
## `base`, y con `pulse` avanza la fase 0x19 (+0x124) y suma 4.
func _draw_waku(canvas: CanvasItem, center: Vector2, base: int, pulse: bool, key: int) -> void:
	var k := 2
	if key == _held:
		if pulse:
			_pulse_phase += 0x19
			base += 4
		var p := mini(3, (DuelVisualMath.cos_fx((_pulse_phase & 0xff) - 0x80) << 2) >> 16)
		k = p + base
	var tex := _waku(k + 2)
	if tex != null:
		canvas.draw_texture(tex, center - Vector2(CARD_W / 2, CARD_H / 2) - Vector2(3, 3))


## Prioridad de dibujo (+0xc, 4474a0): mazo 1..n, las marcadas o agarradas 1999 si hay
## carta retenida, bolsa 2004.. y lo arrastrado +3000 en raton + desfase (44c8a0).
func _deck_entries() -> Dictionary:
	var low := []
	var mid := []
	var top := []
	for z in 3:
		for i in _deck[ZONES[z]].size():
			var key: int = _uids[ZONES[z]][i]
			var entry := {"key": key, "zone": z, "id": _deck[ZONES[z]][i]}
			if _is_moved(key) and _dragging:
				entry["center"] = _mouse + _offsets.get(key, Vector2.ZERO)
				top.append(entry)
				continue
			entry["center"] = _blend.at(key, _card_center(z, i))
			if _is_moved(key):
				if _held != 0:
					mid.append(entry)
					continue
			low.append(entry)
	return {"low": low, "mid": mid, "top": top}


## Cartas del mazo bajo la bolsa (en _deck_layer, o en el propio nodo en el intercambio).
func _draw_deck(canvas: CanvasItem) -> void:
	var e := _deck_entries()
	for entry in e["low"] + e["mid"]:
		_draw_deck_card(canvas, entry)



## Bolsa y, encima de todo, lo que se arrastra.
func _draw_top(canvas: CanvasItem) -> void:
	var top: Array = _deck_entries()["top"]
	if not _swap:
		_draw_trunk(top)
		_draw_trunk_limits(canvas)
	for e in top:
		if e["zone"] == BAG:
			_draw_bag_card(e, false)
		else:
			_draw_deck_card(canvas, e)
	for flight in _bag_flights:
		canvas.draw_texture(CardDB.card_texture(flight.id, true),
			_blend.at(["bag_flight", flight.uid], flight.center) - Vector2(CARD_W / 2, CARD_H / 2))


func _draw_deck_card(canvas: CanvasItem, e: Dictionary) -> void:
	var center: Vector2 = e["center"]
	var motion: Dictionary = _anim.get(e.key, {})
	if motion.get("mode", 0) == 2:
		canvas.draw_set_transform(center, int(motion.draw_rotation) * PI / 256.0,
			Vector2.ONE * float(motion.scale) / 65536.0)
		canvas.draw_texture(CardDB.card_texture(e["id"], true), -Vector2(CARD_W / 2, CARD_H / 2))
		canvas.draw_set_transform(Vector2.ZERO)
		return
	canvas.draw_texture(CardDB.card_texture(e["id"], true), center - Vector2(CARD_W / 2, CARD_H / 2), _card_tint(e))
	if _marks.has(e["key"]):
		_draw_waku(canvas, center, 0, false, e["key"])
	elif e["key"] == _held:
		_draw_waku(canvas, center, 0, true, e["key"])


## 44c8a0: base y suma0x50 antes de la carta siguiente. Las miniaturas son opacas;
## multiplicar su RGB reproduce la suma sobre si mismas y conserva la oclusion nativa.
func _card_tint(e: Dictionary) -> Color:
	if _anim.has(e.key) or not (_marks.has(e.key) or e.key == _grab): return Color.WHITE
	if e.zone == BAG and (_remaining(e.id) <= 0 or e.key != _grab): return Color.WHITE
	var strength := 1.0 + 80.0 / 255.0
	return Color(strength, strength, strength, 1)


## Fila de la bolsa o carta arrastrada desde ella, al 70 %.
func _draw_bag_card(e: Dictionary, faded: bool) -> void:
	var center: Vector2 = e["center"]
	var id: int = e["id"]
	draw_texture_rect(CardDB.card_texture(id, true), Rect2(center - Vector2(CARD_W / 2, CARD_H / 2), THUMB),
			false, FADED if faded else _card_tint(e))
	if faded:
		if _marks.has(e["key"]):
			_draw_waku(self, center, 8, true, e["key"])
	elif e["key"] == _held:
		_draw_waku(self, center, 8, true, e["key"])


func _draw_counters() -> void:
	var positions: Array = COUNTER_TOP[game]
	var groups := [0, 0, 0, 0, 0]
	for id in _deck["main"]:
		var g := CardDB.group_of(CardDB.by_id(id))
		if g < groups.size():
			groups[g] += 1
	for g in groups.size():
		_font_big.draw_right(self, _counter_text(groups[g]), Vector2(positions[0], positions[1] + g * 47))
	var total: int = _deck["main"].size()
	var total_font := _font_big if total >= MAIN_MIN else _font_big_red
	total_font.draw_right(self, _counter_text(total), Vector2(positions[0], positions[2]))
	_font_big.draw_right(self, _counter_text(_deck["side"].size()), Vector2(positions[0], positions[3]))
	_font_big.draw_right(self, _counter_text(_deck["fusion"].size()), Vector2(positions[0], positions[4]))

func _counter_text(value: int) -> String:
	return "%02d" % value if game == "joey" else str(value)


## Filas de la bolsa. Las que se arrastran se anaden a `dragged` (se dibujan luego, encima).
func _draw_trunk(dragged: Array) -> void:
	var kabegami: Layout = _scripts["kabegami"]
	var new_tex := _tex(kabegami.resource(kabegami.index_of("kabegami/new_anime_?.bmp")))
	var new_h := new_tex.get_height() / 5.0
	var kx := _kaban_x()
	for row in _bag_rows():
		var i := _trunk_scroll + row
		var card := _view[i]
		var id := int(card["internal_id"])
		var key := _bag_key(row)
		var center := _bag_center(row)
		var pos := _trunk_pos(row)
		var left := _remaining(id)
		var entry := {"key": key, "zone": BAG, "id": id, "center": center}
		if _dragging and _is_moved(key):
			# 455720: queda una copia en la fila, translucida si no quedan mas copias libres
			_draw_bag_card(entry, _bag_clone.get("faded", false) if _bag_clone.get("key") == key else false)
			dragged.append({"key": key, "zone": BAG, "id": id,
					"center": _mouse + _offsets.get(key, Vector2.ZERO)})
		else:
			_draw_bag_card(entry, left <= 0)
		if left > 0:
			_font_small.draw_right(self, str(left), pos + Vector2(THUMB.x, THUMB.y - 14))
		if _bag_progress != 0:
			_draw_trunk_details(card, pos)
		elif card["category"] == "monster":
			_font_stats.draw_right(self, str(int(card["atk"])), Vector2(kx + STATS_RIGHT_COLLAPSED, 51 + row * _trunk_pitch()))
			_font_stats.draw_right(self, str(int(card["defense"])), Vector2(kx + STATS_RIGHT_COLLAPSED, (67 if game == "joey" else 68) + row * _trunk_pitch()))
		if not SaveData.is_seen(id):
			var state: Dictionary = _new_rows.get(row, {"frame": 0, "alpha": 0})
			var src := Rect2(0, int(state.frame) * new_h, new_tex.get_width(), new_h)
			draw_texture_rect_region(new_tex, Rect2(Vector2((688 if game == "joey" else 684) + _bag_shift(), (55 if game == "joey" else 54) + row * _trunk_pitch()), src.size),
				src, Color(1, 1, 1, float(state.alpha) / 255.0))



## Bolsa desplegada: nombre, ATK/DEF, atributo, tipo y nivel (iconos de font.txt).
func _draw_trunk_details(card: Dictionary, thumb_pos: Vector2) -> void:
	# 44ce00: el cache de la bolsa empieza cuatro pixeles antes de kaban.bmp.
	var cache_x := _kaban_x() - 4
	var row_y := thumb_pos.y - (40 if game == "joey" else 39)
	var name_size := 14 if game == "joey" else 13
	var name_color: Color = TRUNK_NAME_COLOR[game]
	if game == "joey": name_color = Color8(244,0,0) if _copy_limit(int(card.internal_id)) == 0 else Color8(255,218,71)
	draw_string(_trunk_name_font, Vector2(cache_x + 52, row_y + 48 + _trunk_name_font.get_ascent(name_size)), str(CardDB.text(card, "names")),
			HORIZONTAL_ALIGNMENT_LEFT, 138 if game == "joey" else 130, name_size, name_color)
	var number_y := row_y + (67 if game == "joey" else 68)
	if card["category"] == "monster":
		_font_stats.draw_right(self, str(int(card["atk"])), Vector2(cache_x + 75, number_y))
		_font_stats.draw(self, "/", Vector2(cache_x + 75, number_y))
		_font_stats.draw_right(self, str(int(card["defense"])), Vector2(cache_x + 105, number_y))
	_draw_trunk_icons(self,card,thumb_pos)


## Y457ae0/4538a0, Ka4595b0/455350 y Jo46bae0/46cee0: atlas y posiciones nativos.
func _trunk_icon_ops(card: Dictionary, thumb_pos: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _sort_properties.is_empty():
		_sort_properties = FileAccess.get_file_as_bytes(Assets.resolve("common/bin/card_prop.bin"))
	var index := int(card.index)
	var prop := _sort_properties.decode_u32(index*4)
	var kind := (prop >> 20) & 31
	var attribute := 9 if kind == 21 else 8 if kind == 22 else prop >> 29
	var subtype := (prop >> 17) & 7 if kind in [21,22] else 0
	var origin := Vector2(_kaban_x()-4, thumb_pos.y-(40 if game == "joey" else 39))
	result.append({"font":7,"index":attribute-1,"pitch":16,"position":origin+Vector2(113 if game == "joey" else 111,66)})
	if kind > 0 and kind < 21:
		result.append({"font":8,"index":kind-1,"pitch":16,"position":origin+Vector2(129 if game == "joey" else 128,66)})
		result.append({"font":-1,"index":0,"pitch":19,"position":origin+Vector2(151 if game == "joey" else 148,66)})
		result.append({"font":6,"index":((prop >> 25)&15)-1,"pitch":14 if game == "yugi" else 11,"position":origin+Vector2(169 if game == "joey" else 167,68 if game == "yugi" else 70)})
	elif subtype > 0:
		result.append({"font":9,"index":subtype-1,"pitch":16,"position":origin+Vector2(129 if game == "joey" else 128,66)})
	return result


func _draw_trunk_icons(canvas: CanvasItem, card: Dictionary, thumb_pos: Vector2) -> void:
	for op: Dictionary in _trunk_icon_ops(card,thumb_pos):
		var texture := _tex(_scripts["font"].resource(int(op.font))) if int(op.font)>=0 else _script_tex("kaban_list",5)
		if int(op.index)<0: continue
		var src := Rect2(int(op.index)*int(op.pitch),0,int(op.pitch),texture.get_height())
		canvas.draw_texture_rect_region(texture,Rect2(op.position,src.size),src)


## Joey46d980 consulta5be190; 46fe30 recorta icon_seigen en celdas16×16.
## 46ddb0 coloca el objeto sobre la miniatura; conserva el límite aunque no queden copias.
func _trunk_limit_icons() -> Array[Dictionary]:
	var icons: Array[Dictionary] = []
	if game != "joey" or _swap:
		return icons
	for row in _bag_rows():
		var id := int(_view[_trunk_scroll + row]["internal_id"])
		var limit := _copy_limit(id)
		if limit == MAX_COPIES:
			continue
		icons.append({"row": row, "id": id,
			"rect": Rect2(690 + _bag_shift(), 38 + row * 55, 16, 16),
			"src": Rect2(limit * 16, 0, 16, 16)})
	return icons


func _draw_trunk_limits(canvas: CanvasItem) -> void:
	if game != "joey" or _swap:
		return
	var strip := _tex(_scripts["font"].resource(14))
	for icon: Dictionary in _trunk_limit_icons():
		canvas.draw_texture_rect_region(strip, icon.rect, icon.src)


func _draw_icon(strip: Texture2D, index: int, size: int, pos: Vector2) -> void:
	if strip == null or index < 0 or (index + 1) * size > strip.get_width():
		return
	draw_texture_rect_region(strip, Rect2(pos, Vector2(size, strip.get_height())),
			Rect2(index * size, 0, size, strip.get_height()))


## Fondo: Joey46ddb0 recorre39px; Y44d0c0/Ka44e610 recorre40 y acaba enY2.
func _trunk_header_background_y() -> int:
	var travel := 39 if game == "joey" else 40
	return -travel + maxi(0, _bag_progress - 128) * travel / 128 + (0 if game == "joey" else 2)


func _draw_trunk_header() -> void:
	if _bag_progress == 0:
		return
	var control_y := -40 + maxi(0, _bag_progress - 128) * 40 / 128
	var font: Layout = _scripts["font"]
	# 44d0c0/44e610/46ddb0: fondo con gemas, fijo en620; los botones son capas On/Push.
	draw_texture(_script_tex("kaban_list", 2), Vector2(620, _trunk_header_background_y()))
	var sort_strip := _tex(font.resource(11))  # icon_sort: 14 iconos de 30
	var active: int = SORT_ICON[_sort]
	var sw := sort_strip.get_width() / 14.0
	draw_texture_rect_region(sort_strip, Rect2(Vector2(_kaban_x() + 146, control_y), Vector2(sw, sort_strip.get_height())),
			Rect2(active * sw, 0, sw, sort_strip.get_height()))


## 453560: rectangulo con las lineas de deck_c/line.txt (blancas de 1 pixel).
func _draw_rect_selection() -> void:
	if not _rect_active or _rect.size.x <= 0 or _rect.size.y <= 0:
		return
	var line_x := _script_tex("line", 0)
	var line_y := _script_tex("line", 1)
	if line_x == null or line_y == null:
		return
	var r := _rect
	draw_texture_rect_region(line_x, Rect2(r.position, Vector2(r.size.x, 1)), Rect2(0, 0, r.size.x, 1))
	draw_texture_rect_region(line_x, Rect2(Vector2(r.position.x, r.end.y), Vector2(r.size.x, 1)), Rect2(0, 0, r.size.x, 1))
	draw_texture_rect_region(line_y, Rect2(r.position, Vector2(1, r.size.y)), Rect2(0, 0, 1, r.size.y))
	draw_texture_rect_region(line_y, Rect2(Vector2(r.end.x, r.position.y), Vector2(1, r.size.y)), Rect2(0, 0, 1, r.size.y))


func _process(delta: float) -> void:
	if _swap: _swap_transition.advance(delta)
	_clock += NativeClock.ticks(delta)
	while _clock >= 1.0:
		_clock -= 1.0
		_detail.visible_characters = _detail_reveal.step()
		_blend.tick()
		_native_tick()
	_blend.fraction = _clock
	_cursor.advance(delta)
	_pulse_phase = _held_phase
	if _trunk_bar != null:
		_trunk_bar.set_range(_view.size() - TRUNK_ROWS)
		_trunk_bar.set_value(_trunk_scroll)
	_update_detail_scroll()
	_cursor.update(_mouse, _cursor_over, CURSOR_OVER, PlatformInput.mouse_pressed(MOUSE_BUTTON_LEFT))
	queue_redraw()
	_deck_layer.queue_redraw()


# --- edicion ----------------------------------------------------------------------------

func _deck_card() -> Dictionary:
	var ids: Array = _deck[_deck_cursor["zone"]]
	return CardDB.by_id(ids[_deck_cursor["index"]]) if _deck_cursor["index"] < ids.size() else {}


func _deck_valid(deck: Dictionary) -> bool:
	var main: int = deck["main"].size()
	return main >= MAIN_MIN and main <= MAIN_MAX and deck["side"].size() <= SIDE_MAX


func _leave() -> void:
	if _swap:
		if not _swap_valid():
			_message("swapdeckerror", "dlg_text_ok")
			return
		SaveData.set_deck(game, _deck.duplicate(true))
		SaveData.save()
		Audio.play_sfx("%s/voice/internal/decide.wav" % game)   # 0x10000001
		Game.after_swap(game)
		return
	if not _deck_valid(_deck):
		_message("deckerror", "dlg_ok_ok_derr")
		return
	if _dirty:
		SaveData.set_deck(game, _deck.duplicate(true))
	_save_settings()
	SaveData.save()
	Audio.play_sfx("%s/voice/internal/return.wav" % game)
	Game.open_title(game, "deck")


func _set_filter(filter: String) -> void:
	_filter = filter
	_apply_view()
	Audio.play_sfx("%s/voice/internal/decide.wav" % game)


func _toggle_window() -> void:
	# 447800 elige cerrar siempre que +11c sea distinto de cero, incluso a mitad.
	_bag_direction = 2 if _bag_progress != 0 else 1
	_expanded = _bag_direction == 1
	_relayout()
	Audio.play_sfx("%s/voice/internal/decide.wav" % game)


# --- reglas del original -------------------------------------------------------------------

## Y53fd30/Ka542400 leen bit0 de +1178; Jo5be190 lee byte +10ee.
func _copy_limit(id: int) -> int:
	return CARD_LIMITS.copy_limit(game, id, SaveData.data.get("native_system", {}))


## Cuenta todas las zonas del ID propio, pero solo main/side de sus variantes
## (las dos parejas de Fusion cuentan la variante solo en Fusion).
func _copy_limit_used(id: int) -> int:
	var used := _copies_used(id)
	for variants in COPY_VARIANTS:
		if id not in variants:
			continue
		for other in variants:
			if other == id:
				continue
			if id in [14, 2014, 68, 2068]:
				used += _deck.fusion.count(other)
			else:
				used += _deck.main.count(other) + _deck.side.count(other)
		return used
	return used

## 449450: si la carta id puede pasar de la zona src a dest.
func _rule_ok(id: int, src: int, dest: int) -> bool:
	if src == dest:
		return false
	if dest != BAG and not (src in [0, 1, 2] and dest in [0, 1, 2]):
		# 448e80: copias en el mazo por debajo del limite (53fd30).
		if _copy_limit_used(id) >= _copy_limit(id):
			return false
	# 541950 == 2: las fusiones solo van a Fusion o a la bolsa; el resto a cualquiera salvo Fusion.
	if CardDB.group_of(CardDB.by_id(id)) == CardDB.Group.FUSION:
		return dest == 2 or dest == BAG
	return dest != 2


## 448090: caben `count` cartas mas en dest.
func _capacity_ok(dest: int, count: int) -> bool:
	if dest == -1:
		return false
	if dest == BAG:
		return true
	return _deck[ZONES[dest]].size() + count <= ZONE_CAP[1 if _swap else 0][dest]


func _is_moved(key: int) -> bool:
	return key != 0 and (_marks.has(key) or key == _grab)


## Cartas de la zona z que se moverian (marcadas o la agarrada), en orden de la lista.
func _moved_keys(z: int) -> Array:
	var out := []
	if z == BAG:
		for r in _bag_rows():
			if _is_moved(_bag_key(r)):
				out.append(_bag_key(r))
	elif z >= 0:
		for key in _uids[ZONES[z]]:
			if _is_moved(key):
				out.append(key)
	return out


## 448bb0: borra marcas de las zonas del mazo, la carta retenida y el ancla.
func _clear_selection() -> void:
	_held = 0
	_anchor = {"zone": -1, "index": -1}
	for key in _marks.keys():
		if key > 0:
			_marks.erase(key)


## 45a310: mueve a dest las cartas marcadas o agarradas de la zona de origen.
func _drop(dest: int, by_mouse: bool, shift: bool) -> void:
	var src := _src_zone
	var keys := _moved_keys(src)
	var count := 0
	for key in keys:
		if _rule_ok(_key_id(key), src, dest):
			count += 1
	var fits := _capacity_ok(dest, count)
	if _swap and not _swap_balance_ok(dest, count):
		return
	if not fits:
		return
	var moved := []
	for key in keys:
		var id := _key_id(key)
		if not _rule_ok(id, src, dest):
			continue
		_marks.erase(key)
		var start: Vector2
		if by_mouse:
			start = _mouse + _offsets.get(key, Vector2.ZERO)
		elif src == BAG:
			start = _bag_center(_bag_row_of(key))
		else:
			start = _pos.get(key, Vector2.ZERO)
		_move_one(key, src, dest, start, not by_mouse)
		moved.append(id)
	if moved.is_empty():
		return
	_undo.resize(_undo_at)
	_undo.append({"from": src, "to": dest, "ids": moved})
	_undo_at = _undo.size()
	_relayout()
	if not shift:
		_held = 0
	_dirty = true
	if _swap:
		_swap_transition.set_balance(_swap_balance())
	Audio.play_sfx("%s/voice/internal/card_move.wav" % game)


## 45a280: en el intercambio no se va a la bolsa y el balance no pasa de 15; si no cabe,
## 4597a0(6) = aviso 15deckerror (tabla 0x459abc -> 456800 con el indice 3 de 0x5aa230).
func _swap_balance_ok(dest: int, count: int) -> bool:
	if dest == BAG:
		return false
	# +0xb0 crece al pasar cartas fuera del principal: es -_swap_balance().
	var balance := -_swap_balance() + (count if dest != 0 else -count)
	if balance < 16 and balance > -16:
		return true
	_message("15deckerror", "dlg_ok_ok_chgerr")
	_cursor_over = false
	return false


func _bag_row_of(key: int) -> int:
	for r in _bag_rows():
		if _bag_key(r) == key:
			return r
	return 0


## 455860: una carta a dest. Desde la bolsa nace una carta nueva; a la bolsa desaparece.
func _move_one(key: int, src: int, dest: int, start: Vector2, fly_to_bag := false) -> void:
	var id := _key_id(key)
	var uid := key
	if src != BAG:
		var i: int = _uids[ZONES[src]].find(key)
		_deck[ZONES[src]].remove_at(i)
		_uids[ZONES[src]].remove_at(i)
	else:
		uid = _next_uid
		_next_uid += 1
	if dest == BAG:
		if fly_to_bag:
			_bag_flights.append({"uid": uid, "id": id, "from": start, "center": start, "v": 0})
		_pos.erase(uid)
		_anim.erase(uid)
		return
	# 455600: anadir invalida el criterio del destino, sin reordenarlo.
	_deck_criteria[ZONES[dest]] = "default"
	_deck[ZONES[dest]].append(id)
	_uids[ZONES[dest]].append(uid)
	_pos[uid] = start
	_anim.erase(uid)


## 45a560: deshacer (redo = false) o rehacer el ultimo movimiento, sin reglas ni sonido.
func _undo_step(redo: bool) -> void:
	var e: Dictionary
	var from: int
	var to: int
	if redo:
		if _undo_at >= _undo.size():
			return
		e = _undo[_undo_at]
		_undo_at += 1
		from = e["from"]
		to = e["to"]
	else:
		if _undo_at == 0:
			return
		_undo_at -= 1
		e = _undo[_undo_at]
		from = e["to"]
		to = e["from"]
	for k in e["ids"].size():
		var id: int = e["ids"][k]
		var start := Vector2(900, 300)
		var key := -(int(id) + 1)
		if from != BAG:
			# 45a560 enumera las copias y toma la primera de las N ultimas
			# del grupo consecutivo restante; asi conserva su orden visual.
			var remaining := 0
			for next in range(k + 1, e["ids"].size()):
				if int(e["ids"][next]) != id: break
				remaining += 1
			var matches: Array[int] = []
			for slot in _deck[ZONES[from]].size():
				if int(_deck[ZONES[from]][slot]) == id: matches.append(slot)
			var i: int = matches[matches.size() - 1 - remaining] if matches.size() > remaining else -1
			if i == -1:
				continue
			key = _uids[ZONES[from]][i]
			start = _pos.get(key, start)
		_move_one(key, from, to, start, true)
	_relayout()
	_dirty = true
	if _swap:
		_swap_transition.set_balance(_swap_balance())


## Mueve la carta index de la zona como Intro + flecha sobre ella (45a310 sin raton).
func _move_card(zone: String, index: int, dest: int) -> void:
	_sync_uids()
	_src_zone = ZONES.find(zone)
	_src_index = index
	_grab = _uids[zone][index]
	_drop(dest, false, false)
	_clear_selection()


## Ventana de orden. Con `at`, 4597a0(5, 400, 300) -> 455380: centrada en ese punto, sin
## sonido al abrir y con el puntero llevado al primer boton.
func _open_sort(at := Vector2(-1, -1)) -> void:
	var bg := _script_tex("filter", 0)
	var pos := Vector2(800 - 31 - 385, 32)
	if at.x >= 0:
		pos = Vector2(int(at.x) - bg.get_width() / 2, int(at.y) - bg.get_height() / 2)
	var d := PocDialog.new(bg, pos)
	d.cancel_id = "cancel"
	for i in SORT_BUTTONS.size():
		var b: Array = SORT_BUTTONS[i]
		var location: Vector2 = SORT_POS.get(game, SORT_POS.yugi)[i]
		d.add_button(b[0], location, _script_tex(b[1], 0), _script_tex(b[1], 1))
	d.closed.connect(func(id: String) -> void:
		_modal = null
		if id == "cancel":
			Audio.play_sfx("%s/voice/internal/return.wav" % game)
		else:
			if at.x < 0: _sort = id
			var changed: Array = []
			for zone in ZONES:
				if _deck_criteria[zone] != id:
					_deck_criteria[zone] = id
					changed.append(zone)
			_sort_deck(changed)
			_relayout()
			_apply_view()
			Audio.play_sfx("%s/voice/internal/decide.wav" % game))
	if at.x < 0:
		Audio.play_sfx("%s/voice/internal/decide.wav" % game)
	_open_modal(d)
	if at.x >= 0 and preload("res://core/duel_input.gd").pointer_motion(game):
		# 45fff0 (opcion DAT_005aed20+0xef5, activa por defecto)
		var first: Texture2D = _script_tex(SORT_BUTTONS[0][1], 0)
		_glide = {"from": _mouse, "delta": pos + SORT_POS.get(game, SORT_POS.yugi)[0] + first.get_size() / 2.0 - _mouse,
				"k": 0, "at": _mouse}


## 45fff0/51d610: el puntero va al destino en 6 pasos con frenada en coseno; se abandona si
## el jugador mueve el raton.
func _glide_step() -> void:
	if _glide.is_empty():
		return
	if not preload("res://core/duel_input.gd").pointer_motion(game):
		_glide = {}
		return
	if _mouse.distance_to(_glide["at"]) > 1.0:
		_glide = {}
		return
	_glide["k"] += 1
	var f := DuelVisualMath.cos_fx(0x80 * int(_glide["k"]) / 6 - 0x80)
	var d: Vector2 = _glide["delta"]
	var at: Vector2 = _glide["from"] + Vector2((int(d.x) * f) >> 16, (int(d.y) * f) >> 16)
	_glide["at"] = at
	_mouse = at
	PointerGlide.note(at)
	if is_inside_tree() and PointerGlide.may_warp():
		get_viewport().warp_mouse(at)
	if _glide["k"] >= 6:
		_glide = {}


# --- ventanas modales -----------------------------------------------------------------------

func _open_modal(dialog: Node) -> void:
	if dialog is PocDialog: dialog.enable_native_editor()
	_modal = dialog
	_hover = ""
	_pressed = ""
	add_child(dialog)
	if dialog is PocDialog: dialog.sync_native_visibility()


## Aviso de una sola imagen con boton OK (deckerror, 15deckerror, success...).
func _message(bg_script: String, ok_script: String, top_left := Vector2(-1, -1),
		lines := PackedStringArray(), on_close := Callable()) -> void:
	Audio.play_sfx("%s/voice/internal/%s.wav" % [game, "decide" if bg_script == "success" else "unable"])
	var d: PocDialog
	if bg_script == "warning":
		d = preload("res://scenes/deck_editor/deck_warning_dialog.gd").new(_script_tex(bg_script, 0), top_left, lines, game)
	else:
		d = PocDialog.new(_script_tex(bg_script, 0), top_left)
		d.lines = lines
	var ok: Layout = _scripts[ok_script]
	d.add_button("ok", Vector2(ok.position(0)), _tex(ok.resource(0)), _tex(ok.resource(1)))
	d.text_rect = Rect2(54, 44, 236, 100)
	d.closed.connect(func(_id: String) -> void:
		_modal = null
		if on_close.is_valid():
			on_close.call())
	_open_modal(d)


func _decks_dir() -> String:
	return Paths.save_dir.path_join(DECKS_DIR)


func _deck_files() -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(_decks_dir()):
		return out
	for f in DirAccess.get_files_at(_decks_dir()):
		if f.get_extension().to_lower() == "ydc":
			out.append(f.get_basename())
	out.sort()
	return out


func _open_file_dialog(mode: String) -> void:
	var bg := _script_tex(mode, 0)
	var d := preload("res://scenes/deck_editor/deck_file_dialog.gd").new(
			bg, mode, _deck_files(), _script_tex(mode, 1), _script_tex(mode, 2), game)
	d.keep_after_confirm = mode == "export"
	_file_dialog = d
	var ok: Layout = _scripts["dlg_%s_ok" % mode]
	var cancel: Layout = _scripts["dlg_%s_cancel" % mode]
	d.add_button("ok", Vector2(ok.position(0)), _tex(ok.resource(0)), _tex(ok.resource(1)))
	d.add_button("cancel", Vector2(cancel.position(0)), _tex(cancel.resource(0)), _tex(cancel.resource(1)))
	d.closed.connect(func(id: String) -> void:
		if id == "ok" and mode == "export":
			_export(d.chosen_name)
			return
		_modal = null
		_file_dialog = null
		if id == "ok":
			_import(d.chosen_name)
		else:
			Audio.play_sfx("%s/voice/internal/return.wav" % game))
	Audio.play_sfx("%s/voice/internal/decide.wav" % game)
	_open_modal(d)


func _export(name: String, confirmed := false) -> void:
	var path := _decks_dir().path_join(name + ".ydc")
	if FileAccess.file_exists(path) and not confirmed:
		var d := PocDialog.new(_script_tex("overwrite", 0))
		var ok: Layout = _scripts["dlg_ow_ok"]
		var cancel: Layout = _scripts["dlg_ow_cancel"]
		d.add_button("ok", Vector2(ok.position(0)), _tex(ok.resource(0)), _tex(ok.resource(1)))
		d.add_button("cancel", Vector2(cancel.position(0)), _tex(cancel.resource(0)), _tex(cancel.resource(1)))
		d.closed.connect(func(id: String) -> void:
			_modal = null
			if id == "ok":
				_export(name, true)
			else:
				_resume_file_dialog())
		_open_modal(d)
		return
	if Ydc.save(path, _deck, SaveData.deck_file_header()):
		_message("success", "dlg_ok_ok_export", Vector2(-1,-1), PackedStringArray(), func():
			if is_instance_valid(_file_dialog): _file_dialog.queue_free()
			_file_dialog = null)
	else:
		Audio.play_sfx("%s/voice/internal/unable.wav" % game)
		_resume_file_dialog()


func _resume_file_dialog() -> void:
	if not is_instance_valid(_file_dialog): return
	_modal = _file_dialog
	_file_dialog.confirming = false
	_file_dialog._name.mouse_filter = Control.MOUSE_FILTER_STOP


## 436bf0 -> 540450: carga incluso mazos incompletos; las cartas retiradas generan
## un aviso. 45ba80 caso4 recoge el mazo anterior solo al aceptar ese aviso.
func _import(name: String) -> void:
	var path := _decks_dir().path_join(name + ".ydc")
	var deck := Ydc.load(path)
	var head := Ydc.header(path)
	var expected := SaveData.deck_file_header()
	if head.size() == 8 and not Ydc.header_matches(head, expected):
		_import_error(0x102b, "dlg_ok_ok_chgerr")
		return
	if deck.is_empty() or deck.main.size() > MAIN_MAX or deck.side.size() > SIDE_MAX or deck.fusion.size() > 15:
		_import_error(0x1029, "dlg_ok_ok_derr")
		return
	var cleaned := preload("res://core/native_deck_import.gd").filter(deck, game, SaveData.data.collection, _copy_limit, COPY_VARIANTS, CardDB.by_id)
	var missing := PackedStringArray()
	for id in cleaned.removed:
		var card := CardDB.by_id(id)
		var label: String = CardDB.text(card, "names") if not card.is_empty() else "#%d" % id
		missing.append("%s  x%d" % [label, int(cleaned.removed[id])])
	if not missing.is_empty():
		var w: Layout = _scripts["warning"]
		_message("warning", "dlg_ok_ok_cerr", Vector2(w.position(0)), missing,
			func(): _accept_import(cleaned.deck))
		return
	_accept_import(cleaned.deck)

func _import_error(message_id: int, ok_script: String) -> void:
	var labels: Variant = Assets.dialog_texts()
	var text := str(labels[message_id]) if labels != null and message_id < labels.size() else ""
	_message("warning", ok_script, Vector2(-1, -1), PackedStringArray([text]))

func _accept_import(deck: Dictionary) -> void:
	_begin_replacement(deck)
	_clear_selection()
	_marks.clear()
	_undo.clear()
	_undo_at = 0
	_dirty = true
	_deck_cursor = {"zone": "main", "index": 0}
	Audio.play_sfx("%s/voice/internal/decide.wav" % game)


## Y45ba80 inicia +1cc=1; 457270 recoge las cartas antiguas antes de recargar.
func _begin_replacement(deck: Dictionary) -> void:
	_replacement = deck.duplicate(true)
	_replacement_phase = 1
	_sync_uids()
	_anim.clear()
	for z in 3:
		for uid in _uids[ZONES[z]]:
			_anim[uid] = CardMotion.gather(_pos[uid], _gather_center(z))

func _gather_center(zone: int) -> Vector2:
	var limits: Array = DECK_ZONES[game][ZONES[zone]]
	return Vector2(262 + (int(limits[2]) - 262 + _bag_shift()) / 2,
		(int(limits[3]) - int(limits[1])) / 2 + int(limits[1]))

func _replacement_tick() -> void:
	if _replacement_phase == 0:
		return
	for a in _anim.values():
		if a.has("mode") and not a.done:
			return
	if _replacement_phase == 1:
		# 457270 caso2 solo pasa a3; la recarga ocurre en la siguiente actualizacion.
		_replacement_phase = 2
		return
	_anim.clear()
	for z in 3:
		var zone: String = ZONES[z]
		_deck[zone] = _replacement.get(zone, []).duplicate()
		_uids[zone] = []
		# 457270 caso3 -> 456e70 -> 44fd40: grupo/ATK y criterio0.
		_deck_criteria[zone] = "default"
	_sort_deck()
	_relayout(true)
	_sort = "name"
	_view.clear()
	_build_trunk()
	_apply_view()
	_trunk_scroll = 0
	_trunk_cursor = 0
	# 457270 conserva el panel de detalle y limpia solo la seleccion fisica.
	_grab = 0
	_marks.clear()
	for z in 3:
		var zone: String = ZONES[z]
		for uid in _uids[zone]:
			_anim[uid] = CardMotion.settle(_gather_center(z), _pos[uid])
			_pos[uid] = _gather_center(z)
	_replacement = {}
	_replacement_phase = 0


# --- entrada ----------------------------------------------------------------------------

## Teclas mantenidas (0x538710). Las pruebas las fijan con _key_override.
func _key_held(key: Key) -> bool:
	if _key_override.has(key):
		return _key_override[key]
	return PlatformInput.key_pressed(key)


## Tabla 0x45c700: Shift 0xd, Ctrl 0xe, cancelar 0xc (Esc o Insert), Intro 6.
func _shift() -> bool:
	return _key_held(KEY_SHIFT)


func _ctrl() -> bool:
	return _key_held(KEY_CTRL)


func _cancel_held() -> bool:
	return _key_held(KEY_ESCAPE) or _key_held(KEY_INSERT)


func _enter_held() -> bool:
	return _key_held(KEY_ENTER) or _key_held(KEY_KP_ENTER)


func _key_pressed(key: Key) -> bool:
	return _keys_down.has(key)


## La posicion del raton se sigue aunque haya una ventana abierta (el cursor es propio).
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
		var native_key := preload("res://core/duel_input.gd").slots(event, game) != 0 or code in [KEY_SHIFT, KEY_CTRL, KEY_PAGEUP, KEY_PAGEDOWN, KEY_KP_SUBTRACT, KEY_KP_ADD]
		if event.pressed and native_key: _nav_keys_held[code] = true
		else: _nav_keys_held.erase(code)
	if event is InputEventMouse:
		_mouse = event.position
	# Onda del clic del puntero global (0x460120, +0x119 en 0x40c8c0), tambien con un cuadro
	# abierto.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_cursor.click(event.position, true)


func _unhandled_input(event: InputEvent) -> void:
	if _modal != null:
		return
	if _trunk_bar != null and _trunk_bar.handle(event):
		get_viewport().set_input_as_handled()
		return
	if _detail_scroll != null:
		if _detail_scroll.handle(event):
			get_viewport().set_input_as_handled()
			return
		# Y4478c0/Ka448910/Jo46f230: rueda solo a la izquierda de224.
		var step := 0
		if event is InputEventMouseButton and event.pressed and event.position.x < 224:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP: step = -19
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: step = 19
		if step != 0 and _detail_scroll.maximum > 0:
			_detail_scroll.set_value(_detail_scroll.value + step)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion:
		_mouse = event.position
		_hover = _button_at(event.position)
		return
	if event is InputEventMouseButton:
		_on_mouse_button(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_keys_down[event.keycode] = true
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		# 434450: accion6 activa el boton solo con el puntero dentro de su rectangulo.
		var pointed := _button_at(_mouse)
		if pointed != "":
			_click_button(pointed)
			return
	if _enter_held():
		return   # Intro mantenido: las flechas mueven la carta senalada (45a7d0)
	if _navigate_event(event):
		return
	if _swap:
		return
	elif event.is_action_pressed("pc_filter"):
		_set_filter(FILTERS[wrapi(FILTERS.find(_filter) + 1, 0, FILTERS.size())])
	elif event.is_action_pressed("pc_sort"):
		_open_sort()
	elif event.is_action_pressed("pc_window"):
		if _nav_region == 4:
			_set_focus("deck")
		_toggle_window()


## 44bb30:+1d8, despues12 repite y retrocede a9 (cada4 ticks).
func _navigation_repeat() -> void:
	if _modal != null or _enter_held():
		_nav_hold_age = 0
		return
	var held := not _nav_keys_held.is_empty()
	# 45c990 muestrea grupos mantenidos, incluso si se pulsaron antes de entrar.
	var native := preload("res://core/duel_input.gd")
	var defaults: Array = native.JOEY_DEFAULTS if game == "joey" else native.DEFAULTS
	var bindings: Dictionary = native.options(game).get("keys", {})
	for slot in defaults.size():
		for key in bindings.get(str(slot), defaults[slot]): held = held or _key_held(int(key))
	for key in [KEY_SHIFT, KEY_CTRL, KEY_PAGEUP, KEY_PAGEDOWN, KEY_KP_SUBTRACT, KEY_KP_ADD]:
		held = held or _key_held(key)
	_nav_hold_age = ((_nav_hold_age + 1) & 255) if held else 0
	if _nav_hold_age <= 12: return
	_nav_hold_age = 9
	for slot in [1, 2, 3, 4]:
		var group: Array = bindings.get(str(slot), defaults[slot])
		var fresh := false
		for key in group: fresh = fresh or _key_pressed(int(key))
		if fresh: continue # 44bb30 combina pulsacion/repeticion con OR, no dos movimientos.
		for key in group:
			if _key_held(int(key)):
				var event := InputEventKey.new()
				event.keycode = int(key)
				event.physical_keycode = int(key)
				event.pressed = true
				_navigate_event(event)
				break


## 447220/447260: cinco regiones, con saltos asimetricos de intercambio/bolsa.
func _change_nav_region(backwards: bool) -> void:
	if backwards:
		_nav_region = wrapi(_nav_region - 1, 0, 5)
		if _swap and _nav_region == 0: _nav_region = 1
		if _bag_shift() == 0 and _nav_region == 4: _nav_region = 3
	else:
		_nav_region = (_nav_region + 1) % 5
		if (_swap and _nav_region == 2) or (_bag_shift() == 0 and _nav_region == 4): _nav_region = 0
	if _nav_region == 1 and not (_swap and backwards) and _deck["main"].is_empty() and _deck["side"].is_empty() and _deck["fusion"].is_empty():
		_change_nav_region(backwards)
		return
	_set_focus(["header", "deck", "trunk", "win", "filters"][_nav_region])

func _navigate_event(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo: return false
	var native_slots: int = preload("res://core/duel_input.gd").slots(event, game)
	if (native_slots & (1 << (19 if game == "joey" else 11))) != 0:
		_change_nav_region(event.shift_pressed)
		return true
	var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if code == KEY_KP_SUBTRACT:
		if _nav_region == 4: _set_focus("deck")
		_toggle_window()
		return true
	if code in [KEY_PAGEUP, KEY_PAGEDOWN] and _focus == "trunk" and not _swap:
		_trunk_scroll = clampi(_trunk_scroll + (-1 if code == KEY_PAGEUP else 1) * (5 if game == "joey" else 3), 0, maxi(0, _view.size() - TRUNK_ROWS))
		_trunk_cursor = _trunk_scroll + _nav_indices[2]
		_show_detail(_trunk_card())
		return true
	var horizontal := -1 if native_slots & (1 << 3) else (1 if native_slots & (1 << 4) else 0)
	var vertical := -1 if native_slots & (1 << 1) else (1 if native_slots & (1 << 2) else 0)
	if horizontal == 0 and vertical == 0: return false
	if _focus == "none": _set_focus("header")
	if _focus == "deck":
		if horizontal != 0: _move_deck_horizontal(horizontal)
		else: _move(vertical)
	elif _focus == "trunk":
		if horizontal != 0:
			_trunk_scroll = clampi(_trunk_scroll + horizontal * (5 if game == "joey" else 3), 0, maxi(0, _view.size() - TRUNK_ROWS))
			_trunk_cursor = _trunk_scroll + _nav_indices[2]
			_show_detail(_trunk_card())
			_keyboard_pointer()
		else:
			var row: int = _trunk_cursor - _trunk_scroll
			var desired := row + vertical
			row = clampi(desired, 0, TRUNK_ROWS - 1)
			if desired != row:
				_trunk_scroll = clampi(_trunk_scroll + vertical, 0, maxi(0, _view.size() - TRUNK_ROWS))
			_trunk_cursor = _trunk_scroll + row
			_show_detail(_trunk_card())
			_keyboard_pointer()
		_nav_indices[2] = _trunk_cursor - _trunk_scroll
	else:
		var region := 4 if _focus == "filters" else 0
		if _focus != "win":
			_nav_indices[region] = wrapi(_nav_indices[region] + horizontal + vertical, 0, 7 if region == 4 else (1 if _swap else 3))
		_keyboard_pointer()
	return true


func _on_mouse_button(event: InputEventMouseButton) -> void:
	_mouse = event.position
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if event.pressed and not _swap:
			var step := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			if _button_at(event.position) == "filter_label":
				_set_filter(FILTERS[wrapi(FILTERS.find(_filter) + step, 0, FILTERS.size())])
			else:
				_trunk_scroll = clampi(_trunk_scroll + step, 0, maxi(0, _view.size() - TRUNK_ROWS))
		return
	if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	var left := event.button_index == MOUSE_BUTTON_LEFT
	# pulsados y soltados del tick (vt+0x14 / vt+0x30 del objeto raton DAT_005af864)
	if event.pressed:
		_latch["lp" if left else "rp"] = true
	else:
		_latch["lr" if left else "rr"] = true
	if not event.pressed:
		if _pressed != "" and _pressed == _button_at(event.position):
			_click_button(_pressed, not left)
		_pressed = ""
		return
	var button := _button_at(event.position)
	if button != "":
		_pressed = button


func _set_focus(focus: String) -> void:
	_focus = focus
	var regions := ["header", "deck", "trunk", "win", "filters"]
	if regions.has(focus): _nav_region = regions.find(focus)
	if focus == "deck" and _deck[_deck_cursor["zone"]].is_empty():
		_move_deck_zone(1)
	_show_detail(_trunk_card() if focus == "trunk" else _deck_card())
	_keyboard_pointer()
	Audio.play_sfx("%s/voice/internal/cursor.wav" % game)


func _move(step: int) -> void:
	if _focus == "trunk" and not _swap:
		_trunk_cursor = clampi(_trunk_cursor + step, 0, maxi(0, _view.size() - 1))
		if _trunk_cursor < _trunk_scroll:
			_trunk_scroll = _trunk_cursor
		elif _trunk_cursor >= _trunk_scroll + TRUNK_ROWS:
			_trunk_scroll = _trunk_cursor - TRUNK_ROWS + 1
		_show_detail(_trunk_card())
	else:
		var zone: String = _deck_cursor["zone"]
		# ASM44bd8b: el stride+1d4 es comun a las tres zonas.
		var target: int = _deck_cursor["index"] + step * _per_row()
		if target >= 0 and target < _deck[zone].size():
			_deck_cursor["index"] = target
		else:
			_deck_cursor["index"] = 0
			_move_deck_zone(step)
		_show_detail(_deck_card())
	_keyboard_pointer()
	Audio.play_sfx("%s/voice/internal/cursor.wav" % game)


func _move_deck_horizontal(step: int) -> void:
	var ids: Array = _deck[_deck_cursor["zone"]]
	var target: int = _deck_cursor["index"] + step
	if ids.is_empty():
		return
	# 44bb30 caso1: derecha/izquierda envuelven dentro de la zona.
	_deck_cursor["index"] = wrapi(target, 0, ids.size())
	_show_detail(_deck_card())
	_keyboard_pointer()
	Audio.play_sfx("%s/voice/internal/cursor.wav" % game)


## 44bb30 lleva el puntero a esquina(+2,alto-2), bolsa(707+shift,67+56r).
func _keyboard_pointer() -> void:
	if not preload("res://core/duel_input.gd").pointer_motion(game):
		return
	var target: Vector2
	if _focus in ["header", "win", "filters"]:
		var name: String = ["btn_back", "btn_load", "btn_save"][_nav_indices[0]] if _focus == "header" else ("kbtn_win" if _focus == "win" else FILTER_BUTTONS[_nav_indices[4]])
		var buttons := _buttons()
		if not buttons.has(name): return
		var bounds: Rect2 = buttons[name].rect
		target = bounds.position + Vector2(int(bounds.size.x) / 2, int(bounds.size.y) / 2)
	elif _focus == "trunk":
		target = Vector2((711 if game == "joey" else 707) + _bag_shift(), (68 if game == "joey" else 67) + (_trunk_cursor - _trunk_scroll) * _trunk_pitch())
	else:
		if _deck[_deck_cursor.zone].is_empty():
			return
		target = _deck_card_pos(_deck_cursor.zone, _deck_cursor.index) + Vector2(2, CARD_H - 2)
	_glide = {"from": _mouse, "delta": target - _mouse, "k": 0, "at": _mouse}


## Pasa a la zona siguiente/anterior con cartas (principal -> side -> fusion).
func _move_deck_zone(step: int) -> void:
	var zones := ["main", "side", "fusion"]
	var i := zones.find(_deck_cursor["zone"])
	for n in range(1, 3):
		var z: String = zones[wrapi(i + step * n, 0, 3)]
		if not _deck[z].is_empty():
			_deck_cursor = {"zone": z, "index": 0}
			return


func _button_at(pos: Vector2) -> String:
	var buttons := _buttons()
	for name in buttons:
		if name == "swap_arrow":
			continue   # 459c10 solo dibuja la flecha
		if buttons[name]["rect"].has_point(pos):
			return name
	return ""


func _click_button(name: String, right := false) -> void:
	match name:
		"btn_back":
			_leave()
		"btn_save":
			_open_file_dialog("export")
		"btn_load":
			_open_file_dialog("import")
		"kbtn_win":
			_toggle_window()
		"kbtn_all":
			_set_filter("all")
		"filter_label":
			_set_filter(FILTERS[wrapi(FILTERS.find(_filter) + (-1 if right else 1), 0, FILTERS.size())])
		"sort":
			_open_sort()
		_:
			var filter := _filter_of_button(name)
			if filter != "":
				# pulsar el filtro activo lo quita
				_set_filter("all" if filter == _filter else filter)


# --- tick nativo (45b6e0 / 459c10 -> 45a7d0) ---------------------------------------------

func _native_tick() -> void:
	if _modal is PocDialog: _modal.native_tick()
	_navigation_repeat()
	_held_phase = _pulse_phase
	_advance_bag()
	_replacement_tick()
	_glide_step()
	# 45b6e0: con el raton quieto, al 4.o tick (+0x5924) muestra la carta senalada; 459c10
	# (+0x4f8) en cuanto esta quieto y hay carta senalada.
	if _replacement_phase == 0 and _mouse == _last_mouse:
		var still := _still
		_still += 1
		if _grab != 0 and (_swap or still == 3):
			var id := _key_id(_grab)
			if id >= 0 and int(_detail_card.get("internal_id", -1)) != id:
				_show_detail(CardDB.by_id(id))
	else:
		_still = 0
	_last_mouse = _mouse
	if _modal == null:
		_deck_tick()
	_latch = {"lp": false, "rp": false, "lr": false, "rr": false}
	_keys_down.clear()
	_advance_anims()
	_advance_new()
	_detail_flip.tick()


## 0x45a7d0: raton y teclado del mazo en un tick.
func _deck_tick() -> void:
	if _replacement_phase != 0:
		return
	var pos := _mouse
	var lp: bool = _latch["lp"]
	var rp: bool = _latch["rp"]
	var lr: bool = _latch["lr"]
	var rr: bool = _latch["rr"]
	var shift := _shift()
	var ctrl := _ctrl()
	var cancel := _cancel_held()
	var zone := _zone_at(pos)
	if _held == 0:
		_grab = 0
	# Ctrl+Z deshace (con Shift rehace) y Ctrl+Y rehace (45a560)
	if not _animating and ctrl:
		if _key_pressed(KEY_Z):
			_undo_step(shift)
		elif _key_pressed(KEY_Y):
			_undo_step(true)
	var hit := _hit_at(pos)
	if not _dragging and not hit.is_empty() and _held == 0:
		_grab = hit["key"]
	var was_dragging := _dragging
	var just_held := false
	if lp and not _animating:
		if hit.is_empty():
			# hueco: empieza el rectangulo (fuera de la bolsa) y sin Ctrl borra la seleccion
			if zone != BAG:
				_rect_state = 1
				if not ctrl:
					_sel_zone = zone
			_toggle = false
			if zone in [0, 1, 2]:
				if not ctrl:
					_clear_selection()
				elif _held != 0:
					_marks[_held] = true
					_held = 0
		else:
			var key: int = hit["key"]
			var src: int = hit["zone"]
			SaveData.mark_seen(_key_id(key))
			if _sel_zone != zone:
				_clear_selection()
			if not ctrl:
				_sel_zone = zone
			if src == BAG:
				# desde la bolsa hace falta alguna copia libre y no llevar Shift
				var free := _remaining(_key_id(key))
				if free != 0 and not shift:
					_dragging = true
				_bag_clone = {"key": key, "faded": free < 2}
			elif not shift and not ctrl:
				_dragging = true
			_src_zone = src
			_src_index = hit["index"]
			if not shift and not ctrl and key == _grab:
				if _marks.is_empty() and _held == 0:
					_held = key
					just_held = true
					_anchor = {"zone": src, "index": hit["index"]}
			if key != _held:
				_toggle = false
			if shift and src != BAG:
				_range_select(hit, was_dragging)
				if _held != 0 and not just_held:
					_marks[_held] = true
					_held = 0
			elif not ctrl or src == BAG:
				# sobre una no marcada: se borran las marcas y se agarra solo esa
				if not was_dragging and _held != key and not _marks.has(key):
					_clear_selection()
					_held = key
					_grab = key
					_anchor = {"zone": src, "index": hit["index"]}
					_show_detail(CardDB.by_id(_key_id(key)))
			elif not was_dragging and _sel_zone == src:
				# Ctrl+clic alterna la marca
				if _held != 0 and not just_held:
					_marks[_held] = true
					_held = 0
				if _marks.has(key):
					_marks.erase(key)
				else:
					_marks[key] = true
				_dragging = false
				_show_detail(CardDB.by_id(_key_id(key)))
	if cancel:
		_held = 0
		_toggle = false
		_clear_selection()
	if not _animating and _enter_held() and not hit.is_empty():
		_enter_move(hit, shift)
	if lr:
		# soltar sobre la propia carta retenida alterna +0xcc0 (sigue retenida)
		if not hit.is_empty() and hit["key"] == _held:
			_toggle = not _toggle
		if not _toggle:
			_held = 0
		_dragging = false
		_bag_clone = {}
		_rect_state = 3
	if rp or _key_pressed(KEY_KP_ADD):
		if not _animating:
			if _held == 0 and not _dragging and _rect_state == 0:
				_open_sort(Vector2(400, 300))
			else:
				# cancelar: suelta todo sin sonido
				_held = 0
				_dragging = false
				_clear_selection()
				_rect_state = 3
				_toggle = false
	_update_cursor(zone, was_dragging, cancel)
	if not rp and not lp and not rr and not lr:
		if not _animating and _held != 0 and ctrl and _key_pressed(KEY_A):
			_select_all()
	if lr and _src_zone != -1 and _src_zone != zone and zone != -1:
		if (shift and _src_zone == BAG and _held != 0 and _bag_free(_src_index) != 0) or was_dragging:
			_drop(zone, true, shift)
			_toggle = false
			if _src_zone == BAG:
				_grab = 0
	if lp:
		# 44c8a0: desfase carta - raton de lo que se arrastra, al pulsar
		for key in _moved_keys(_src_zone):
			var center: Vector2 = _bag_center(_bag_row_of(key)) if key < 0 else _pos.get(key, Vector2.ZERO)
			_offsets[key] = center - pos
	_rect_tick(pos, ctrl)


func _bag_free(row: int) -> int:
	if row < 0 or row >= _bag_rows():
		return 0
	return _remaining(_key_id(_bag_key(row)))


## Shift+clic: marca desde el ancla (+0x1c0) hasta la carta, en la zona de esta.
func _range_select(hit: Dictionary, was_dragging: bool) -> void:
	if was_dragging:
		return
	var same_zone: bool = _held != 0 and hit["key"] != _held and _key_zone(_held) == hit["zone"]
	if not (same_zone or (_anchor["index"] != -1 and _held == 0)):
		return
	for key in _uids[ZONES[_src_zone]]:
		_marks.erase(key)
	var uids: Array = _uids[ZONES[hit["zone"]]]
	var from: int = _anchor["index"]
	if from < 0 or from >= uids.size():
		return
	var to: int = hit["index"]
	for i in range(mini(from, to), maxi(from, to) + 1):
		_marks[uids[i]] = true


## Ctrl+A con una carta retenida: marca toda la zona del ancla.
func _select_all() -> void:
	var z: int = _anchor["zone"]
	if z == BAG:
		for r in _bag_rows():
			_marks[_bag_key(r)] = true
	elif z >= 0:
		for key in _uids[ZONES[z]]:
			_marks[key] = true
	_marks[_held] = true
	_rect_state = 3
	_toggle = false
	_held = 0


## Intro mantenido + flecha (0x538770): izquierda principal, arriba Side, derecha Fusion,
## abajo bolsa, con la carta bajo el puntero.
func _enter_move(hit: Dictionary, shift: bool) -> void:
	var dest := -1
	if _key_pressed(KEY_LEFT):
		dest = 0
	if _key_pressed(KEY_UP):
		dest = 1
	if _key_pressed(KEY_RIGHT):
		dest = 2
	if _key_pressed(KEY_DOWN):
		dest = BAG
	if dest == -1:
		return
	SaveData.mark_seen(_key_id(hit["key"]))
	_src_index = hit["index"]
	_src_zone = hit["zone"]
	if hit["zone"] != BAG or _remaining(_key_id(hit["key"])) != 0:
		_drop(dest, false, shift)
	_clear_selection()


## Cursor "over" si lo agarrado no puede ir a la zona del puntero; se evalua solo al
## cambiar de zona (+0x970) y con la primera carta que se mueve.
func _update_cursor(zone: int, was_dragging: bool, cancel: bool) -> void:
	if not was_dragging:
		_cursor_over = false
		return
	if _over_zone == zone:
		return
	var src := _src_zone
	var keys := _moved_keys(src)
	var over := cancel
	if not keys.is_empty():
		over = true
		if zone != src and _capacity_ok(zone, keys.size()) and _rule_ok(_key_id(keys[0]), src, zone):
			over = false
	if _swap:
		var balance := -_swap_balance() + (keys.size() if zone != 0 else -keys.size())
		over = over or zone == BAG or balance > 15 or balance < -15
	_cursor_over = over and zone != src
	_over_zone = zone


## 453560: rectangulo de seleccion (+0xb2c: 1 empezar, 2 activo, 3 terminar, 4 con marcas).
func _rect_tick(pos: Vector2, ctrl: bool) -> void:
	var x := int(pos.x)
	var y := int(pos.y)
	var right := 679 + (0 if _swap else _bag_shift())
	if _rect_active:
		x = clampi(x, ZONE_LEFT, right)
		y = clampi(y, 0, 599)
		_rect = Rect2(_rect_start, Vector2.ZERO).expand(Vector2(x, y))
		_rect_mark(ctrl)
	if _rect_state == 1:
		if x > ZONE_LEFT and x < right:
			_rect_start = Vector2(x, y)
			_rect = Rect2(_rect_start, Vector2.ZERO)
			_rect_active = true
			_rect_state = 2
		else:
			_rect_state = 0
	elif _rect_state == 3:
		_rect_active = false
		_rect_state = 4 if _marks.keys().any(func(k): return k > 0) else 0


## Marca las cartas de la zona de la seleccion que tocan el rectangulo; sin Ctrl las demas
## se desmarcan. El ancho util de cada carta llega hasta la siguiente (la ultima de cada
## fila usa el ancho entero); en vertical solo se miran tres casos, como el original.
func _rect_mark(ctrl: bool) -> void:
	var z := _sel_zone
	if z < 0 or z > 2:
		return
	var uids: Array = _uids[ZONES[z]]
	var per_row := _per_row() if z == 0 else uids.size()
	var l := int(_rect.position.x)
	var r := int(_rect.end.x)
	var t := int(_rect.position.y)
	var b := int(_rect.end.y)
	var in_row := 0
	for i in uids.size():
		var c := _card_center(z, i)
		var width := CARD_W
		in_row += 1
		if i == uids.size() - 1 or in_row == per_row:
			in_row = 0
		else:
			width = int(_card_center(z, i + 1).x) - int(c.x)
		if not ctrl:
			_marks.erase(uids[i])
		var left := int(c.x) - CARD_W / 2
		var right := left + width
		var top := int(c.y) - CARD_H / 2
		var bottom := int(c.y) + CARD_H / 2
		var horizontal := (l < left and left < r) or (l < right and right < r) \
				or (left < l and l < right) or (left < r and r < right)
		var vertical := (t < top and top < b) or (t < bottom and bottom < b) or (top < t and t < bottom)
		if horizontal and vertical:
			_marks[uids[i]] = true


## 44f920 crea el objeto de fila; 447ed0 baja5 de2 en2 y avanza al llegar0.
## 44ea60 dibuja con fase0..255 (paso4); no se modifica al interpolar/redibujar.
func _advance_new() -> void:
	var active := {}
	if _swap:
		return
	for row in _bag_rows():
		var id := int(_view[_trunk_scroll + row]["internal_id"])
		if SaveData.is_seen(id):
			continue
		active[row] = true
		var a: Dictionary
		if not _new_rows.has(row):
			a = {"frame": 0, "counter": 5, "phase": 0, "alpha": 0}
			_new_rows[row] = a
		else:
			a = _new_rows[row]
			if a.counter == 0:
				a.counter = 5
				a.frame = (int(a.frame) + 1) % 5
			else:
				a.counter = maxi(0, int(a.counter) - 2)
		var phase: int = a.phase
		a.alpha = 255
		if phase < 64:
			a.alpha = DuelVisualMath.cos_fx(phase * 2 - 128) >> 8
		elif phase >= 192:
			a.alpha = DuelVisualMath.cos_fx((phase - 192) * 2) >> 8
		a.phase = (phase + 4) & 255
	for row in _new_rows.keys():
		if not active.has(row):
			_new_rows.erase(row)
