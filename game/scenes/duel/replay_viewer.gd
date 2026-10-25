extends Node2D
## Visor de repeticiones del duelo ("Repeticion" y "Tutorial" del submenu de duelo).
##
## Ejecuta las .ydr originales con el nucleo portado (duel/core) y dibuja el estado despues de
## cada comando: campo, manos, LP, fase y los textos de los tutoriales. La cola de presentación
## reproduce los recursos originales y detiene el motor durante cada secuencia visual.
##
## 4379d0: modo4 cancela con la accion0; modo5 sale con entrada de teclado/raton.
## El motor y la presentacion avanzan a ritmo nativo (NativeClock.HZ); al terminar vuelven al titulo.

const FIELD_X := 230
## COLORREF de Joey41be80: nombre101010, tipo1e49b4, descripcion/ATK0b586e.
## Yugi y Kaiba conservan los colores claros de su panel oscuro.
const DETAIL_COLORS := {
	"yugi": {"name": "#ffff00", "type": "#00ff00", "body": "#ffffff", "stats": "#ffff00"},
	"kaiba": {"name": "#ffff00", "type": "#00ff00", "body": "#ffffff", "stats": "#ffff00"},
	"joey": {"name": "#101010", "type": "#b4491e", "body": "#6e580b", "stats": "#6e580b"},
}
const CARD_SIZE := DuelGeometry.FIELD_SIZE
const HAND_SIZE := DuelGeometry.HAND_SIZE
const PHASES := ["Robo", "Espera", "Principal 1", "Batalla", "Principal 2", "Final"]
const SPEEDS := [0.6, 0.3, 0.12, 0.04]
## Comandos del guion de los tutoriales que solo mueven el cursor o esperan: pasan rapido.
const FAST_OPS := [0xeb, 0xec, 0xee, 0xef, 0xf0, 0xf2, 0xf3, 0xf6, 0xf9, 0xfa, 0x12]
const MUSIC := {
	"yugi": ["yugi/voice/stream/stage1.wav", "yugi/voice/stream/tutorial.wav"],
	"kaiba": ["kaiba/voice/stream/m_duel1.wav", "kaiba/voice/stream/m_tuto.wav"],
	"joey": ["joey/voice/stream/m_duel2.wav", "joey/voice/stream/m_duel2.wav"],
}

static var _next_demo := 0

var game: String
var kind: String
var _lesson := 0
var _files: Array[String] = []
var _index := 0
var _duel: Duel
var _dialogs: Array = []
var _replay_clock := 0.0
var _wait := 0.0
var _text := ""
## Paginas pendientes del texto en curso (el original las separa con <HR>).
var _pages: PackedStringArray = []
var _finished := false
var _board := Node2D.new()
var _info: Label
var _log: Label
var _visual: Node2D
var _visual_event_pos := 0
var _preview := Sprite2D.new()
## Texto del panel de detalle (FUN_00412410): nombre, [tipo] y descripcion con sus colores.
var _description := RichTextLabel.new()
var _detail_reveal := preload("res://core/card_detail_reveal.gd").new()
## "ATK/%4d DEF/%4d" de los monstruos, aparte y abajo a la derecha (0x412410, tamano 0xd).
var _detail_stats := Label.new()
var _detail_icons: Node2D
var _preview_card_id := -1
var _preview_hover_point := Vector2(-9999, -9999)
var _preview_hover_ticks := 0
var _oriented_hand_textures := {}
var _hover_card: Dictionary = {}
var _hit_cards: Array[Dictionary] = []
var _hand_positions: Dictionary = {}
## Índices de cartas por hueco: la compactación del núcleo no cambia su posición visual.
var _hand_cards := [[], []]
var _hand_clock := 0.0
## Las manos se recolocan 3/4 por tick: se dibujan mezcladas entre ticks (clave p * 256 + i).
var _hand_blend := NativeBlend.new()
var _hand_sprites: Array = []   # [clave, Sprite2D, posicion del tick]
var _field_visual: Node2D
var _blocked_zones: Node2D
var _card_stats: DuelCardStats
## Iconos de vinculo con el cursor sobre una carta (FUN_00408360, affect.txt).
var _affect: DuelAffect
## Cristal con agua y LP (FUN_0045d890).
var _life: DuelLifePoints
var _stats_clock := 0.0
var _cursor_visual: Node2D
var _pointer_pos := Vector2.ZERO
var _pointer_pressed := false
var _cursor_context: Array = []
var _tutorial: Node2D

func _setup_presentation(conceal_hand: bool = false) -> void:
	_duel.card_screen_position_query = _native_card_position
	# ATK/DEF de los monstruos (0x410890): sobre las cartas y bajo las animaciones.
	_card_stats = DuelCardStats.new()
	add_child(_card_stats)
	_affect = DuelAffect.new()
	add_child(_affect)
	if _life == null:
		_life = DuelLifePoints.new()
		add_child(_life)
	_life.setup(game)
	_visual = preload("res://scenes/duel/duel_presentation.gd").new(game, conceal_hand)
	add_child(_visual)
	_card_stats.setup(_duel, game)
	_affect.setup(_duel, game)
	_card_stats.hides_at = func(pos: Vector2) -> bool: return _visual.hides(pos)
	_visual_event_pos = 0
	_visual.reset(_duel)
	if _field_visual != null: _field_visual.reset(_duel, game)
	_visual.native_field_tick = func(tick: int) -> void:
		if _field_visual != null: _field_visual.native_tick(_duel, game, tick)
	_visual.hand_positions = _hand_positions

func _native_card_position(p: int, loc: int, i: int) -> Vector2:
	var count := _duel.m.u8(DuelMem.pl(p) + DuelMem.P_HAND_N)
	if loc == 11:
		if i >= count: return Vector2(525,600 if p == 0 else 0)
		return _hand_positions.get(p * 256 + i, DuelGeometry.hand(p,i,count))
	if loc in [12, 13, 14] and _visual != null:
		return _visual.pile_object_position(p, loc, i)
	return DuelGeometry.location(p,loc,i,count)

func _collect_visual_events() -> bool:
	if _visual == null: return false
	_sync_hand_layout()
	while _visual_event_pos < _duel.events.size():
		var event: Dictionary = _duel.events[_visual_event_pos]
		if _tutorial != null: _tutorial.event(event)
		if _tutorial != null and event.get("kind", "") == "tutorial_bubble": _log.hide()
		_visual.enqueue(event, _duel)
		if _cursor_visual != null: _cursor_visual.event(event, _duel)
		_visual_event_pos += 1
	return _visual.busy() or (_tutorial != null and _tutorial.busy())

func _advance_visual(delta: float) -> bool:
	if _cursor_visual != null: _cursor_visual.advance(delta)
	var hands_changed := _advance_hands(delta)
	if _visual == null: return false
	var was_busy: bool = _visual.busy()
	var had_overlays: bool = not _visual.overlays.is_empty()
	_visual.advance(delta)
	if _blocked_zones != null: _blocked_zones.refresh(_duel, _visual.visual_tick)
	var table_changed: bool = _visual.table.revision != _table_revision
	_table_revision = _visual.table.revision
	if was_busy or had_overlays or hands_changed or table_changed or not _hover_card.is_empty(): _redraw()
	_show_hands(_hand_clock)
	if _field_visual != null: _field_visual.show_between(_visual.between())
	return was_busy


## Cartas de la mano entre dos ticks de su recolocacion.
func _show_hands(fraction: float) -> void:
	_hand_blend.fraction = fraction
	for entry: Array in _hand_sprites:
		if is_instance_valid(entry[1]):
			entry[1].position = _hand_blend.at(entry[0], entry[2])


## Repeticiones y lecciones avanzan manos, presentacion y puntero por ticks enteros; entre
## ticks se dibujan con el reloj de la escena.
func _show_between(fraction: float) -> void:
	if not NativeClock.interpolate: return
	_show_hands(fraction)
	_show_stats(fraction)
	if _visual != null: _visual.show_between(fraction)
	if _field_visual != null: _field_visual.show_between(fraction)
	if _cursor_visual != null: _cursor_visual.show_between(fraction)
	if _tutorial != null: _tutorial.show_between(fraction)

func _setup_cursor() -> void:
	_cursor_visual = preload("res://scenes/duel/duel_cursor_visual.gd").new()
	add_child(_cursor_visual)
	_pointer_pos = get_viewport().get_mouse_position()
	_pointer_pos = Debug.replay_pointer_position(_pointer_pos)
	_refresh_cursor(true)

func _cursor_action() -> int:
	return -1

func _refresh_cursor(force: bool = false) -> void:
	if _cursor_visual == null: return
	var action := _cursor_action()
	var context: Array = [not _hover_card.is_empty() or action >= 1, action, _pointer_pressed]
	if force or context != _cursor_context:
		_cursor_context = context
		_cursor_visual.update(_pointer_pos, context[0], action, _pointer_pressed)

func _setup_field() -> void:
	_field_visual = preload("res://scenes/duel/duel_field_visual.gd").new()
	add_child(_field_visual)
	if game == "joey":
		_blocked_zones = preload("res://scenes/duel/duel_blocked_zones.gd").new()
		add_child(_blocked_zones)

func _setup_detail() -> void:
	var detail := Sprite2D.new()
	detail.texture = Assets.texture("%s/duel/detail/detail.png" % game)
	detail.centered = false
	add_child(detail)
	_preview.centered = false
	#41c6d0 blit directo(2,74) Joey; Kaiba412130/Yugi412280 usan(5,72).
	_preview.position = Vector2(2,74) if game == "joey" else DuelGeometry.PREVIEW_RECT.position
	_preview.texture = Assets.texture("common/card/card_ura.png")
	if _preview.texture: _preview.scale = DuelGeometry.PREVIEW_RECT.size / _preview.texture.get_size()
	add_child(_preview)
	var description_scroll := ScrollContainer.new()
	description_scroll.position = Vector2(8, 365)
	# La ultima linea queda para "ATK/%4d DEF/%4d" (se dibuja aparte).
	description_scroll.size = Vector2(184, 161 - 18)
	description_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	description_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(description_scroll)
	var native_scroll := preload("res://scenes/duel/duel_detail_scroll.gd").new()
	native_scroll.setup(game, description_scroll)
	add_child(native_scroll)
	_description.custom_minimum_size.x = 174
	_description.fit_content = true
	_description.bbcode_enabled = true
	# Componer el parrafo completo evita que las palabras cambien de linea al revelarse.
	_description.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_description.scroll_active = false
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.add_theme_font_size_override("normal_font_size", 12)
	_description.add_theme_font_size_override("bold_font_size", 12)
	_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_scroll.add_child(_description)
	# Medido en el original: el texto acaba en x = 179 (7 px antes de la columna derecha del
	# recuadro) y sus letras ocupan las filas 517-525.
	_detail_stats.position = Vector2(8, 513)
	_detail_stats.size = Vector2(171, 14)
	_detail_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_detail_stats.add_theme_font_size_override("font_size", 11)
	_detail_stats.add_theme_color_override("font_color", Color(DETAIL_COLORS[game]["stats"]))
	_detail_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detail_stats)
	if game == "joey":
		_detail_icons = load("res://scenes/duel/duel_detail_icons.gd").new()
		_detail_icons.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_detail_icons)

func _set_preview(id: int) -> void:
	if id == _preview_card_id: return
	_preview_card_id = id
	_preview.texture = CardDB.card_texture(id) if id >= 0 else Assets.texture("common/card/card_ura.png")
	if _preview.texture: _preview.scale = DuelGeometry.PREVIEW_RECT.size / _preview.texture.get_size()
	var card := CardDB.by_id(id)
	if _detail_icons != null: _detail_icons.show_card(card if id >= 0 else {})
	_description.text = _detail_text(card) if id >= 0 and not card.is_empty() else ""
	_detail_reveal.reset(_description.get_parsed_text(), Assets.lang == "j")
	_description.visible_characters = 0
	if _description.get_parent() is ScrollContainer:
		_description.get_parent().scroll_vertical = 0
	_detail_stats.text = ""
	if id >= 0 and card.get("category", "") == "monster":
		_detail_stats.text = "ATK/%4d DEF/%4d" % [int(card.get("atk", 0)), int(card.get("defense", 0))]


## FUN_00412410: nombre, tipo de monstruo y descripcion con los colores del panel nativo.
func _detail_text(card: Dictionary) -> String:
	var colors: Dictionary = DETAIL_COLORS[game]
	var text := "[color=%s][b]%s[/b][/color]\n" % [colors.name, _bb(CardDB.text(card, "names"))]
	if card.get("category", "") == "monster":
		text += "[color=%s][lb]%s[rb][/color]\n" % [colors.type, _bb(CardDB.type_name(int(card.get("type_id", 0))))]
	return text + "[color=%s]%s[/color]" % [colors.body, _bb(CardDB.text(card, "descriptions"))]


static func _bb(text: String) -> String:
	return text.replace("[", "[lb]")

## Tabla de objetos de la mesa (DAT_005af738) que dibuja la presentacion; sin presentacion, una
## copia sincronizada con la memoria.
var _plain_table: DuelCardTable
var _plain_table_duel: Duel
## Objetos de la mano en el ultimo reparto (para recolocar cada uno desde donde estaba).
var _hand_objects := [[], []]
var _table_revision := -1

func _table() -> DuelCardTable:
	if _visual != null: return _visual.table
	if _plain_table == null or _plain_table_duel != _duel:
		_plain_table = DuelCardTable.new()
		_plain_table.sync(_duel)
		_plain_table_duel = _duel
	_plain_table.follow_memory(_duel, true)
	return _plain_table


func _sync_hand_layout() -> bool:
	if _duel == null: return false
	var changed := false
	var table := _table()
	for p in 2:
		var cards: Array[int] = []
		for obj: Dictionary in table.hand[p]: cards.append(int(obj["card"]))
		var count := cards.size()
		var previous: Array = _hand_cards[p]
		var previous_objects: Array = _hand_objects[p]
		var same_objects: bool = previous_objects.size() == count
		for i in mini(count, previous_objects.size()):
			same_objects = same_objects and is_same(previous_objects[i], table.hand[p][i])
		if cards == previous and same_objects: continue
		changed = true
		# 4422e0 / 4426f0: al quitar o insertar un objeto las demas cartas se recolocan desde
		# donde estaban; las copias identicas mantienen el orden.
		var positions := {}
		var old_hover: int = int(_hover_card.get("i", -1)) if _hover_card.get("p", -1) == p and _hover_card.get("loc", -1) == 11 else -1
		var new_hover := -1
		var used := {}
		var renamed := {}
		var fresh := []
		for i in count:
			var old_slot := -1
			# Mismo objeto; si la tabla se rehizo, la primera copia libre del mismo id.
			for j in previous_objects.size():
				if is_same(previous_objects[j], table.hand[p][i]) and not used.has(j):
					old_slot = j
					break
			if old_slot < 0:
				for j in previous.size():
					if previous[j] == cards[i] and not used.has(j):
						old_slot = j
						break
			if old_slot >= 0: used[old_slot] = true
			var target := DuelGeometry.hand(p, i, count)
			positions[p * 256 + i] = _hand_positions.get(p * 256 + old_slot, target) if old_slot >= 0 else target
			if old_slot >= 0: renamed[p * 256 + old_slot] = p * 256 + i
			else: fresh.append(p * 256 + i)
			if old_slot >= 0 and old_slot == old_hover: new_hover = i
		_hand_blend.rename(renamed)
		for key in fresh: _hand_blend.cut(key)
		for key in _hand_positions.keys():
			if int(key) / 256 == p: _hand_positions.erase(key)
		_hand_positions.merge(positions)
		_hand_cards[p] = cards
		_hand_objects[p] = table.hand[p].duplicate()
		if old_hover >= 0:
			if new_hover < 0: _hover_card.clear()
			else: _hover_card["i"] = new_hover
	return changed

func _advance_hands(delta: float) -> bool:
	if _duel == null: return false
	var changed := _sync_hand_layout()
	_hand_clock += NativeClock.ticks(delta)
	while _hand_clock >= 1:
		_hand_clock -= 1
		_description.visible_characters = _detail_reveal.step()
		_tick_preview_hover()
		_hand_blend.tick()
		for p in 2:
			var count: int = _hand_cards[p].size()
			for i in count:
				var key := p * 256 + i
				var raised: bool = _hover_card.get("p", -1) == p and _hover_card.get("loc", -1) == 11 and _hover_card.get("i", -1) == i
				var target := DuelGeometry.hand(p, i, count, raised)
				var previous: Vector2 = _hand_positions.get(key, target)
				var next := target + Vector2(int((previous.x - target.x) * 3) / 4, int((previous.y - target.y) * 3) / 4)
				changed = changed or previous != next
				_hand_positions[key] = next
	return changed

##Jo44dbc0/Ka437e50/Yu4378a0: cuatro consultas inmoviles; el reparto no selecciona.
func _tick_preview_hover() -> void:
	if _visual != null and (_visual._shade_on or _visual._shade_c != 0): return
	if _pointer_pos != _preview_hover_point:
		_preview_hover_point = _pointer_pos
		_preview_hover_ticks = 0
	else:
		_preview_hover_ticks += 1
	if _preview_hover_ticks != 4: return
	var hover := _hit_card(_pointer_pos)
	if not hover.is_empty(): _set_preview(int(hover.id) if hover.known else -1)

func _hit_card(point: Vector2) -> Dictionary:
	for i in range(_hit_cards.size() - 1, -1, -1):
		if _hit_cards[i]["rect"].has_point(point): return _hit_cards[i]
	return {}

func _hit_zone(point: Vector2) -> Dictionary:
	# Selección sobre zonas vacías: mismos centros que el dibujo y el motor.
	for p in 2:
		for z in 11:
			if Rect2(DuelGeometry.zone(p, z, game) - Vector2(39, 48), Vector2(78, 96)).has_point(point):
				return {"p": p, "loc": 0 if z < 5 else 5 if z < 10 else 10, "i": z if z < 5 else z - 5 if z < 10 else 0, "id": 0, "known": false}
	return {}

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_pointer_pos = event.position
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_pointer_pressed = event.pressed
			if event.pressed and _cursor_visual != null: _cursor_visual.click(_pointer_pos, true)
	if event is InputEventMouseMotion and _duel != null:
		var hover := _hit_card(event.position)
		if hover != _hover_card:
			_hover_card = hover
			_redraw()
	if event is InputEventMouseMotion or event is InputEventMouseButton: _refresh_cursor(true)


func _init(game_id: String, what: String) -> void:
	game = game_id
	kind = what


func _ready() -> void:
	var dialogs: Variant = Assets.dialog_texts()
	_dialogs = dialogs if dialogs is Array else []
	if kind.begins_with("lesson:"):
		_lesson = kind.substr(7).to_int()
		_files.append(Paths.data_dir.path_join(game + "/file/tutorial%d.ydr" % _lesson))
		kind = "tutorial"
	if kind.begins_with("file:"):
		# Repeticion guardada elegida en la lista de carga (0x4587d0(3)).
		_files.append(kind.substr(5))
		kind = "replay"
	for g in ([] if kind == "replay" or _lesson > 0 else [game]):
		var dir := Paths.data_dir.path_join(g).path_join("file")
		var names := Array(DirAccess.get_files_at(dir)).filter(
				func(f: String) -> bool: return f.begins_with(kind) and f.ends_with(".ydr"))
		names.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
		for f in names:
			_files.append(dir.path_join(f))
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.size = Vector2(800, 600)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_setup_detail()
	_setup_field()
	add_child(_board)
	_setup_cursor()
	_info = _label(Vector2(238, 66), Vector2(552, 26), 12)
	_log = _label(Vector2(238, 276), Vector2(552, 68), 12)
	_log.clip_text = true
	_info.hide()
	_log.hide()
	if kind == "tutorial" and game in ["yugi", "kaiba"]:
		_tutorial = (preload("res://scenes/duel/tutorial_overlay.gd") if game == "yugi" else preload("res://scenes/duel/tutorial_overlay_kaiba.gd")).new()
		add_child(_tutorial)
		_cursor_visual.z_index = 30
		_info.hide()
		_log.hide()
	if _files.is_empty():
		_log.text = "No hay repeticiones de este tipo en data/."
		_log.show()
		return
	_index = (_next_demo % _files.size()) if kind == "demo" else 0
	if kind == "demo":
		# Demostracion (modo 5): rotulo "DEMOSTRACION" del comando 0x14 (0x43dbe0).
		var label := DuelDemoLabel.new()
		label.setup(game)
		add_child(label)
		_next_demo += 1
	var music: Array = MUSIC.get(game, MUSIC["yugi"])
	Audio.play_music(music[1] if kind == "tutorial" else music[0])
	_start(_index)


func _label(pos: Vector2, size: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	add_child(l)
	return l


func _start(i: int) -> void:
	if _tutorial != null: _tutorial.reset()
	_pages.clear()
	_duel = Duel.create(Paths.data_dir, game)
	if _duel == null:
		_log.text = "Faltan datos del duelo. Ejecuta: poetry run python -m pocx duelimage --src ../extracted --data ../data"
		_files.clear()
		return
	# Las preguntas de los tutoriales se responden solas siguiendo el guion
	_duel.auto_answer = Duel.AUTO_SCRIPT
	_duel.game_mode = 6 if kind == "tutorial" else 5 if kind == "demo" else 4
	_duel.start_replay(Ydr.load_file(_files[i]))
	_duel.game_mode = 6 if kind == "tutorial" else 5 if kind == "demo" else 4
	_duel.begin_replay_flow()
	if _visual == null: _setup_presentation()
	else:
		_visual_event_pos = 0
		_visual.reset(_duel)
		if _field_visual != null: _field_visual.reset(_duel, game)
		_card_stats.setup(_duel, game)
		_affect.setup(_duel, game)
	if _duel is JoeyPresentationAdapter:
		var adapter := _duel as JoeyPresentationAdapter
		adapter.presentation_visual = _visual
		adapter.engine.visual_busy_query = Callable(adapter, "query_visual_busy")
		adapter.engine.visual_object_query = Callable(adapter, "query_visual_object").bind(_visual)
	_finished = false
	_hand_positions.clear()
	_hand_cards = [[], []]
	_hand_objects = [[], []]
	_hover_card.clear()
	_set_preview(-1)
	_text = ""
	_wait = 0.0
	_replay_clock = 0.0
	_redraw()


## LP que muestra cada jugador: los de la animacion del cambio de LP mientras dura.
func _shown_lp() -> Array:
	var out := []
	for p in 2:
		var value := _duel.m.u16(DuelMem.pl(p))
		# Inicio Kaiba: op14 precede a op10. El objeto45fa40 ya tiene8000,
		# pero el motor aun conserva cero. Tras op10 vuelven a mandar sus LP,
		# incluidos los escenarios que escriben el valor sin evento visual.
		var initial_kaiba := game == "kaiba" and value == 0 and _duel.executed <= 1 and (_duel.cmd_op() & 0xfff) != 0x10
		if _visual != null and (initial_kaiba or (_visual.active.get("mode", "") == "lp_total" and _visual.active.get("p", -1) == p)):
			value = _visual.displayed_lp[p]
		out.append(value)
	return out


## Avanza a ritmo nativo (NativeClock.HZ) los valores de ATK/DEF que se muestran (DAT_005aed18 = visual_tick).
func _tick_card_stats(delta: float) -> void:
	if _card_stats == null:
		return
	_stats_clock += NativeClock.ticks(delta)
	while _stats_clock >= 1.0:
		_stats_clock -= 1.0
		_card_stats.step(_visual.visual_tick if _visual != null else 0)
		if _affect != null:
			_affect.step(_hover_card)
		if _life != null and _duel != null:
			_life.step(_shown_lp())
	_show_stats(_stats_clock)


func _show_stats(fraction: float) -> void:
	if _affect != null: _affect.show_between(fraction)
	if _life != null: _life.show_between(fraction)


func _process(delta: float) -> void:
	if _duel == null or _files.is_empty(): return
	if kind != "tutorial":
		_replay_clock += NativeClock.ticks(delta)
		while _replay_clock >= 1.0:
			_replay_clock -= 1.0
			_tick_card_stats(1.0 / NativeClock.HZ)
			if _advance_visual(1.0 / NativeClock.HZ): continue
			if _finished:
				_leave_replay()
				return
			if not _duel.frame(): _finished = true
			_collect_visual_events()
			_redraw()
		_show_between(_replay_clock)
		return
	_tick_card_stats(delta)
	if _tutorial != null:
		_tutorial.advance(delta)
		if _tutorial.busy():
			if _cursor_visual != null: _cursor_visual.advance(delta)
			return
	if _advance_visual(delta): return
	_wait -= delta
	if _wait > 0.0:
		return
	if not _pages.is_empty():
		_show_page()
		return
	if _finished:
		if _lesson > 0:
			Audio.stop_music()
			Game.open_tutorial(game)
			_files.clear()
			return
		if kind == "replay":
			# Repeticion guardada: al acabar se vuelve al menu de duelo.
			Audio.stop_music()
			Game.open_title(game, "duel")
			_files.clear()
			return
		# como en el original, al terminar pasa a la siguiente
		_index = (_index + 1) % _files.size()
		_start(_index)
	else:
		_step()


## Ejecuta hasta que termina el siguiente comando y redibuja.
func _step() -> void:
	if _tutorial != null and _tutorial.busy(): return
	var before := _duel.executed
	for i in 20000:
		var busy := _duel.frame()
		if _collect_visual_events():
			_redraw()
			return
		if _duel.executed != before and not _duel.is_running():
			break
		if not busy:
			_finished = true
			break
	var op := _duel.cmd_op() & 0xfff
	_wait = SPEEDS[1]
	if op in FAST_OPS:
		_wait *= 0.2
	match op:
		0xed:
			if _tutorial == null:
				_pages = _dialog(_duel.cmd_a())
				_show_page()
		0xf5:
			_log.show() # Diálogo genérico aún provisional, separado de los globos ed.
			_pages = _dialog(_duel.cmd_b())
			_show_page()
		0xf1:
			_wait = _duel.cmd_a() / NativeClock.HZ
		0x04:
			_finished = true
	if _finished:
		_wait = 4.0
		_text += "\n\nFin del duelo."
	_redraw()


## Texto de dlg_text en paginas, sin las marcas de color (@N) ni de formato.
func _dialog(id: int) -> PackedStringArray:
	var pages: PackedStringArray = []
	if id < 0 or id >= _dialogs.size():
		return pages
	var re := RegEx.create_from_string("@[0-9]")
	for page in String(_dialogs[id]).split("<HR>", false):
		page = re.sub(page.replace("<BR>", "\n").replace("\r", ""), "", true).strip_edges()
		if page != "":
			pages.append(page)
	return pages


func _show_page() -> void:
	if _pages.is_empty():
		return
	_text = _pages[0]
	_pages.remove_at(0)
	_wait = 1.0 + _text.length() * 0.04
	_log.text = _text


func _redraw() -> void:
	_sync_hand_layout()
	_refresh_cursor()
	if _field_visual != null and _duel != null:
		_field_visual.refresh(_duel, game, _visual.visual_tick if _visual != null else 0)
	if _blocked_zones != null and _duel != null:
		_blocked_zones.refresh(_duel, _visual.visual_tick if _visual != null else 0)
	_hit_cards.clear()
	for c in _board.get_children():
		# Son nodos de dibujo sin callbacks. Liberarlos aquí evita acumular un tablero
		# por tick en pruebas manuales y al avanzar varias animaciones por fotograma.
		c.free()
	_hand_sprites.clear()
	var m := _duel.m
	var table := _table()
	for p in 2:
		# 410ca0: cada objeto en reposo; los que se mueven los dibuja la presentacion.
		for z in 11:
			var obj: Dictionary = table.field[p][z]
			if obj.is_empty() or obj.has("moving") or int(obj["card"]) < 0:
				continue
			var pos := DuelGeometry.zone(p, z, game)
			var face_up := bool(obj["face"])
			# bit 14 de la palabra: posicion de defensa (va tumbada)
			var defense := z < 5 and bool(obj["defense"])
			_card(int(obj["card"]), pos, CARD_SIZE, face_up, defense, p == 1)
			_register_card(pos, Vector2(CARD_SIZE.y, CARD_SIZE.x) if defense else CARD_SIZE, p, 0 if z < 5 else 5 if z < 10 else 10, z if z < 5 else z - 5 if z < 10 else 0, int(obj["card"]), face_up or p == 0)
			# Los contadores de la carta los dibuja DuelCardStats (0x4103e0 / 0x410640).
		# 42f0e0: una pila vacia no se dibuja; durante un vuelo sigue la imagen anterior.
		var fusion: Dictionary = table.piles[p][DuelMem.LOC_FUSION]
		if int(fusion["count"]) > 0:
			# Jo44c3e0 ->43c550(p,12,0): existe desde la construccion de la mesa.
			var fusion_top := _pile_position(p, DuelMem.LOC_FUSION, int(fusion["count"]))
			_card(0, fusion_top, CARD_SIZE, false, false, p == 1)
			_register_card(fusion_top, CARD_SIZE, p, 12, int(fusion["count"]) - 1, int(fusion["top"]), p == 0)
		var deck: Dictionary = table.piles[p][DuelMem.LOC_DECK]
		if int(deck["count"]) > 0:
			_card(0, _pile_position(p, DuelMem.LOC_DECK, int(deck["count"])), CARD_SIZE, false, false, p == 1)
			_count(DuelGeometry.DECK[p], int(deck["count"]))
		var grave: Dictionary = table.piles[p][DuelMem.LOC_GRAVE]
		if int(grave["count"]) > 0:
			var grave_top := _pile_position(p, DuelMem.LOC_GRAVE, int(grave["count"]))
			_card(int(grave["top"]), grave_top, CARD_SIZE, true, false, p == 1)
			_register_card(grave_top, CARD_SIZE, p, 14, int(grave["count"]) - 1, int(grave["top"]), true)
			_count(preload("res://scenes/duel/joey_pile.gd").base_position(p, 14) if game == "joey" else DuelGeometry.GRAVE[p], int(grave["count"]))
		if game == "kaiba" and int(table.piles[p][DuelMem.LOC_BANISH]["count"]) > 0:
			_excluded_pile(p, int(table.piles[p][DuelMem.LOC_BANISH]["count"]))
		# 441d90: ambas manos centradas525, parcialmente fuera de los bordes600/0.
		var hand_n: int = table.hand[p].size()
		for i in hand_n:
			var obj: Dictionary = table.hand[p][i]
			if obj.has("moving"): continue
			var hid := int(obj["card"])
			var pos: Vector2 = _hand_positions.get(p * 256 + i, DuelGeometry.hand(p, i, hand_n))
			var sprite := _card(hid, pos, HAND_SIZE, true, false, p == 1)
			if sprite != null:
				sprite.position = _hand_blend.at(p * 256 + i, pos)
				_hand_sprites.append([p * 256 + i, sprite, pos])
			_register_card(pos, HAND_SIZE, p, 11, i, hid, p == 0 or _visual == null or not _visual.hidden_hand)
	var turn := m.u16(0xa133f2)
	var phase := (turn >> 1) & 7
	if _info.visible and not _files.is_empty():
		_info.text = "%s  %d/%d · Turno: %s · %s" % [
			_files[_index].get_file().get_basename(), _index + 1, _files.size(),
			"rival" if (turn & 1) != 0 else "jugador",
			PHASES[phase] if phase < PHASES.size() else "-"]
	_log.text = _text


func _label_on_board(pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	_board.add_child(l)
	return l


## FUN_0042f0e0 (solo mazo 0xd y cementerio 0xe): FUN_004604f0 escribe el numero de cartas con
## duel_fonts (cuadro 0 de duel/font/number.txt: 11 glifos de 6 x 8) de derecha a izquierda con
## paso 7, desde x = centro + 7 y con la parte de arriba en el borde inferior de la carta.
func _pile_position(p: int, loc: int, count: int) -> Vector2:
	var textures := [Assets.texture("%s/duel/card/deck.png" % game), Assets.texture("%s/duel/card/deck_shadow.png" % game), Assets.texture("%s/duel/card/grave.png" % game)]
	if game == "joey": return preload("res://scenes/duel/joey_pile.gd").draw(_board, textures, p, loc, count)
	return preload("res://scenes/duel/classic_pile.gd").draw(_board, textures, p, loc, count)

func _count(center: Vector2, n: int, centered := false) -> void:
	var font := Assets.texture("%s/duel/font/duel_fonts.png" % game)
	if font == null:
		return
	var glyph := int(font.get_width() / 11)
	var x := int(center.x) + 7
	var y := int(center.y) + 36
	if centered:
		x = int(center.x) + str(absi(n)).length() * 7 / 2
		y = int(center.y) - 1 - font.get_height() / 2
	var v := absi(n)
	while true:
		x -= 7
		var s := Sprite2D.new()
		s.texture = font
		s.centered = false
		s.region_enabled = true
		s.region_rect = Rect2((v % 10) * glyph, 0, glyph, font.get_height())
		s.position = Vector2(x, y)
		_board.add_child(s)
		v /= 10
		if v == 0:
			break


## Kaiba 42f950: boton de excluidas, sin rotacion, contador centrado (4628b0).
func _excluded_pile(p: int, count: int) -> void:
	var center := DuelGeometry.location(p, 15)
	var hover: bool = _hover_card.get("p", -1) == p and _hover_card.get("loc", -1) == 15
	var tex := Assets.texture("kaiba/duel/card/jyogai_%s%d.png" % ["ji" if p == 0 else "ai", 3 if hover and _pointer_pressed else 1])
	if tex == null: return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.position = center
	_board.add_child(sprite)
	if hover:
		var add := Sprite2D.new()
		add.texture = tex
		add.position = center
		add.modulate = Color(1, 1, 1, 0.25)
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		add.material = material
		_board.add_child(add)
	_count(center, count, true)
	_register_card(center, tex.get_size(), p, 15, 0, 0, false)


func _register_card(pos: Vector2, size: Vector2, p: int, loc: int, i: int, id: int, known: bool) -> void:
	if _visual != null and _visual.hides(pos): return
	_hit_cards.append({"rect": Rect2(pos - size / 2, size), "p": p, "loc": loc, "i": i, "id": id, "known": known})

## Todas las posiciones de cartas son absolutas, compartidas con hitboxes y animaciones.
func _card(card_id: int, center: Vector2, size: Vector2, face_up: bool, sideways: bool,
		flipped: bool) -> Sprite2D:
	if _visual != null and _visual.hides(center): return null
	# Conservar el arte completo hasta el raster final: las minis y la cache de
	# mano reducida descartan detalle antes de ampliar la ventana del duelo.
	var tex: Texture2D = CardDB.card_texture(card_id) if face_up and card_id >= 0 \
			else Assets.texture("common/card/card_ura.png")
	if tex == null:
		return null
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.scale = size / tex.get_size()
	s.position = center
	s.rotation = (PI / 2 if sideways else 0.0) + (PI if flipped else 0.0)
	if size == HAND_SIZE and not sideways:
		# Mantener la orientacion y el anclaje nativos, sin reducir la imagen.
		if flipped:
			var key := tex.get_instance_id()
			if not _oriented_hand_textures.has(key):
				var image: Image = tex.get_image().duplicate()
				image.flip_x()
				image.flip_y()
				_oriented_hand_textures[key] = ImageTexture.create_from_image(image)
			s.texture = _oriented_hand_textures[key]
		s.rotation = 0
		s.centered = false
		s.offset = Vector2(-50,-72) / s.scale
	_board.add_child(s)
	return s


func _leave_replay() -> void:
	_files.clear()
	Audio.stop_music()
	Game.open_title(game, "duel")


func _unhandled_input(event: InputEvent) -> void:
	var key_pressed: bool = event is InputEventKey and event.pressed and not event.echo
	var button_pressed: bool = event is InputEventMouseButton and event.pressed
	if kind == "demo" and (key_pressed or button_pressed):
		_leave_replay()
		get_viewport().set_input_as_handled()
		return
	if kind == "replay":
		if event.is_action_pressed("ui_cancel"):
			_leave_replay()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or (button_pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		Audio.stop_music()
		if _lesson > 0: Game.open_tutorial(game)
		else: Game.open_title(game, "duel")
	elif _tutorial != null and ((event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey
			and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER])):
		_tutorial.accept()
		get_viewport().set_input_as_handled()
