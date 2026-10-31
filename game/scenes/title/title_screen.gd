extends Node2D
## Pantalla de titulo de cada juego con su menu original.
##
## Funcionamiento del menu, deducido de los graficos y de title.txt:
## - "menu_?_ani0" (o "menu_?_duel" / "menu_?_d_ani0") es el panel en reposo.
## - "menu_?_ani1..6" son fotogramas de brillo del bloque de opciones, con su propia
##   coordenada; las opciones tienen la misma altura, asi que se recorta la franja de la
##   opcion seleccionada y se anima encima del panel.
##
## Yugi sigue la version comercial de la escena 0 (init 0x466e70, update 0x467000):
## - estado 1: franjas de negro a TITLE1 (0x41d320) y de TITLE1 a TITLE2g
##   (0x41d440), 0x80 del contador cada una; despues el panel aparece con alfa hasta 0x13c;
## - estados 2/3 (menu principal / de duelo): seleccion = opcion bajo el puntero (0x4661d0) o
##   -1; brillo con la tabla DAT_0059cb24 cada 3 fotogramas, reiniciado al cambiar (0x466860);
##   pieza del Puzle (item 21) latiendo con DAT_005aed18 (0x4666d0);
## - estado 4: cambio de panel en 0x20 del contador; estado 7: parpadeo y la accion a 0x40.
## Kaiba: entrada/logo/recortes MT cotejados en ASM 0x4687c0 y 0x4694b0. Joey: bandas RGB565 y máscara alfa de 4 bits cotejadas en 0x489170.
## Brillo Kaiba 0x468d10 / Joey 0x489490: tablas y contador nativo cada 3 ticks.

const GLOW_FPS := 15.0
const SPLASH_SECONDS := 1.5
const SPLASH_FADE := 0.5
const EFFECT_FPS := 10.0
## Kaiba DAT59fbfc / Joey DAT5dbd78, leídas como DWORD del PE.
const VARIANT_GLOW := {
	"kaiba": [5, 5, 5, 5, 5, 4, 3, 2, 1, 0, 1, 2, 3, 4],
	"joey": [3, 3, 3, 3, 3, 2, 1, 0, 1, 2],
}
const GLOW_TABLE := [0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 4, 3, 2, 1]   # DAT_0059cb24

## Opciones por menu y juego. Joey anade "Duelo LAN" y la barra de nivel en el de duelo.
const MAIN_ITEMS := ["duel", "deck", "list", "options", "exit"]
const DUEL_ITEMS := {
	"yugi": ["single", "tournament", "replay", "tutorial"],
	"kaiba": ["single", "tournament", "replay", "tutorial"],
	"joey": ["single", "tournament", "level", "replay", "lan"],
}
const MUSIC := {
	"yugi": "yugi/voice/stream/menu.wav",
	"kaiba": "kaiba/voice/stream/m_title.wav",
	"joey": "joey/voice/stream/m_menu.wav",
}

## 0x467000: con el menu quieto (minimo de los contadores de inactividad de raton y teclado,
## DAT_005af864+0x30 y DAT_005af850+0x9f8, > 0x1c2) y el contador del estado (+0x18, +4 por
## fotograma) > 0x707 en el menu (estado 2), pasa a la siguiente demo (0x466f10: demo1..5 por
## turno) en el duelo con el modo 5.
const IDLE_FRAMES := 0x1c3
const MENU_DEMO_FRAMES := 0x708 / 4

var game: String
var _layout: Layout
var _splash: Sprite2D
var _menu_root := Node2D.new()
var _panel := Sprite2D.new()
var _panel_other := Sprite2D.new()   # Yugi, estado 4: el panel que se va
var _glow := Sprite2D.new()
var _menus := {}            # "main"/"duel" -> {base, glow_frames, glow_pos, items}
var _menu := ""
var _selected := 0
var _glow_time := 0.0
var _kaiba_background: Node2D
var _joey_background: Node2D
var _effects: Array[Dictionary] = []   # animaciones del fondo (Kaiba): {sprite, frames}
var _effect_time := 0.0
var _idle := 0
var _state_frames := 0
var _tick_clock := 0.0
var _blend := NativeBlend.new()
var _modal: Node = null   # cuadro abierto (lista de repeticiones): el menu no recibe entrada
var _focus := ""    # opcion del menu principal desde la que se vuelve ("" = recien abierto)
# Yugi (version comercial)
var _retail := false
var _phase := ""            # "intro" (estado 1), "menu" (2/3), "switch" (4), "choose" (7)
var _c := 0                 # +0x18: +4 por fotograma
var _glow_counter := 0      # +0x1c
var _puzzle_counter := 0    # DAT_005aed18
var _switch_to := ""
var _intro_node: Node2D
var _half_alpha := [0, 0]   # franjas: alfa de la mitad de arriba y de la de abajo
var _intro_from: Texture2D
var _intro_to: Texture2D
var _puzzle: Sprite2D
var _mouse := Vector2(-1, -1)
## Puntero original (objeto global 0x460120, cursor_?.txt cargado en 0x40a630 al arrancar): el
## original oculta la flecha de Windows (0x539280) y dibuja la manita y la onda del clic
## (+0x119 = 1 en 0x40c8c0) en todas las escenas, tambien en el titulo y sus opciones.
var _cursor = preload("res://scenes/duel/duel_cursor_visual.gd").new()
var _options: Node2D = null
var _options_to := ""       # estado 5: "options" (entrar) o "main" (salir)
var _pending_action := ""   # Native input changes phase after the current tick is drawn.


func _init(game_id: String, focus := "") -> void:
	game = game_id
	_focus = focus
	_retail = game_id == "yugi"


func _ready() -> void:
	_layout = Assets.layout(TitleArt.SCRIPT % game)
	add_child(_cursor)
	_mouse = get_local_mouse_position()
	_cursor.update(_mouse, false)
	if game == "kaiba":
		_kaiba_background = preload("res://scenes/title/kaiba_title_background.gd").new()
		_kaiba_background.setup(_layout)
		add_child(_kaiba_background)
	elif game == "joey":
		_joey_background = preload("res://scenes/title/joey_title_background.gd").new()
		_joey_background.setup(_layout)
		add_child(_joey_background)
	else:
		add_child(TitleArt.build_background(game))
		_build_effects()
	add_child(_menu_root)
	for s in [_panel_other, _panel, _glow]:
		s.centered = false
	_glow.region_enabled = true
	_menu_root.add_child(_panel_other)
	_menu_root.add_child(_panel)
	_menu_root.add_child(_glow)
	_panel_other.visible = false
	_menus["main"] = _read_menu("menu_?_ani0.bmp", "menu_?_ani%d.bmp", MAIN_ITEMS)
	var duel_base := "menu_?_d_ani0.bmp" if game == "joey" else "menu_?_duel.bmp"
	_menus["duel"] = _read_menu(duel_base, "menu_?_d_ani%d.bmp", DUEL_ITEMS[game])
	if game == "joey":
		var level_display := preload("res://scenes/title/joey_level_display.gd").new()
		level_display.setup(self, _layout)
		_menu_root.add_child(level_display)
	if _retail:
		var puz := _layout.index_of("title_puz_?.bmp")
		_puzzle = Sprite2D.new()
		_intro_node = Node2D.new()
		_puzzle.centered = false
		_puzzle.texture = Assets.texture("yugi/title/" + _layout.resource(puz))
		_puzzle.position = Vector2(_layout.position(puz))
		var puzzle_material := ShaderMaterial.new()
		puzzle_material.shader = preload("res://scenes/title/yugi_title_puzzle.gdshader")
		puzzle_material.set_shader_parameter("background_image", Assets.texture("yugi/title/title2g.bmp"))
		puzzle_material.set_shader_parameter("origin", Vector2i(_puzzle.position))
		_puzzle.material = puzzle_material
		_puzzle.visible = false
		add_child(_puzzle)
		# 4666d0 pinta la pieza junto con el fondo (vt+0xc y despues vt+0x18 con su alfa); el
		# panel del menu es un widget que se dibuja despues y la tapa.
		move_child(_puzzle, _menu_root.get_index())
		_intro_node.draw.connect(_draw_intro)
		add_child(_intro_node)
		_build_options()
		_phase = "intro"
		_c = -4
		_menu_root.visible = false
		return
	_build_options()
	Game.reset_native_tick()     # Kaiba469320, Joey488850.
	if game in ["kaiba", "joey"] and _focus == "":
		_phase = game + "_intro"
		_c = -4
		_menu_root.visible = false
		return
	Audio.play_music(MUSIC[game])
	if _kaiba_background != null: _kaiba_background.advance(320, Game.native_tick)
	if _joey_background != null: _joey_background.advance(320, Game.native_tick)
	var splash_tex: Texture2D = null if _focus != "" else TitleArt.splash_texture(game)
	if splash_tex != null:
		_splash = Sprite2D.new()
		_splash.texture = splash_tex
		_splash.centered = false
		add_child(_splash)
		_menu_root.visible = false
		get_tree().create_timer(SPLASH_SECONDS).timeout.connect(_dismiss_splash)
	else:
		_phase = "menu"
		_open_menu("main")
		_selected = maxi(0, MAIN_ITEMS.find(_focus))


func _build_options() -> void:
	_options = preload("res://scenes/title/title_options.gd").new(game)
	_options.visible = false
	_options.exit_requested.connect(func() -> void:
		_options.save()
		_phase = "options_fade"
		_options_to = "main"
		_c = 0)
	add_child(_options)
	Audio.set_option_volume(_options.volume)


func _dismiss_splash() -> void:
	if _splash == null:
		return
	var splash := _splash
	_splash = null
	Game.reset_native_tick()     # Constructor del menu tras la portada.
	_open_menu("main")
	var tween := create_tween()
	tween.tween_property(splash, "modulate:a", 0.0, SPLASH_FADE)
	tween.tween_callback(splash.queue_free)


func _read_menu(base_name: String, glow_pattern: String, items: Array) -> Dictionary:
	var base_index := _layout.index_of(base_name)
	var frames: Array[Texture2D] = []
	var glow_pos := Vector2.ZERO
	for n in range(1, 7):
		var i := _layout.index_of(glow_pattern % n)
		if i == -1:
			continue
		if frames.is_empty():
			glow_pos = Vector2(_layout.position(i))
		frames.append(Assets.texture("%s/title/%s" % [game, _layout.resource(i)]))
	return {
		"base": Assets.texture("%s/title/%s" % [game, _layout.resource(base_index)]),
		"base_pos": Vector2(_layout.position(base_index)),
		"frames": frames,
		"glow_pos": glow_pos,
		"items": items,
	}


func _open_menu(menu: String) -> void:
	_menu = menu
	_state_frames = 0
	_selected = _hit(PointerGlide.hover(_mouse))
	_glow_counter = 0
	var m: Dictionary = _menus[menu]
	_panel.texture = m["base"]
	_panel.position = m["base_pos"]
	_panel.modulate.a = 1.0
	_menu_root.visible = true
	_update_glow()


func _row_height(m: Dictionary) -> float:
	return m["frames"][0].get_height() / float(m["items"].size())


func _row_rect(index: int) -> Rect2:
	var m: Dictionary = _menus[_menu]
	var w: float = m["frames"][0].get_width()
	var h := _row_height(m)
	return Rect2(m["glow_pos"] + Vector2(0, h * index), Vector2(w, h))


func _update_glow() -> void:
	var m: Dictionary = _menus[_menu]
	var frames: Array = m["frames"]
	if frames.is_empty() or _selected < 0:
		_glow.visible = false
		return
	var frame := 0
	if _retail:
		# 0x466860: ani(1 + tabla[(+0x1c / 3) % 14]); fijo en ani1 al elegir (estado 7).
		frame = 0 if _phase == "choose" else GLOW_TABLE[(_glow_counter / 3) % 14]
	else:
		var table: Array = VARIANT_GLOW[game]
		frame = table[0] if _phase == "choose" else table[(_glow_counter / 3) % table.size()]
		if game == "joey" and _phase == "choose": frame = ((~_c >> 4) & 1) + 4
	# Native rectangles divide integers: top=h*row/n; height=h/n (Kaiba h198).
	var rows: int = m["items"].size()
	var top: int = frames[frame].get_height() * _selected / rows
	var height: int = frames[frame].get_height() / rows
	var row := Rect2(m["glow_pos"] + Vector2(0, top), Vector2(frames[frame].get_width(), height))
	_glow.visible = true
	_glow.texture = frames[frame]
	_glow.position = row.position
	_glow.region_rect = Rect2(Vector2(0, row.position.y - m["glow_pos"].y), row.size)


func _process(delta: float) -> void:
	_blend.restore()
	_tick_clock = minf(_tick_clock + NativeClock.ticks(delta), 4.0)
	while _tick_clock >= 1.0:
		_tick_clock -= 1.0
		_idle += 1
		_state_frames += 1
		_blend.tick()
		var background_tick := maxi(0, Game.native_tick - int(_tick_clock))
		var kaiba_entering := _phase in ["kaiba_intro", "joey_intro"]
		if kaiba_entering:
			_c += 4
			if _c == 8: Audio.play_music(MUSIC[game])
			var render_counter := _c
			var background: Node2D = _kaiba_background if game == "kaiba" else _joey_background
			background.advance(_c, background_tick)
			if _c == 192: _c = 252 if game == "kaiba" else 256
			if render_counter >= 256:
				_open_menu("main")
				_panel.modulate.a = minf(1.0, (_c - 256) * 4 / 256.0)
				_glow.visible = false
			if _c == 316:
				_phase = "menu"
				_c = 0
				Game.reset_native_tick()
				_warp_to(0) # Kaiba4684e0 / Joey488d10: keyboard pointer to first row.
		elif _retail:
			_retail_tick()
		elif _options != null and _phase in ["menu", "switch", "choose", "options_fade", "options"]:
			_retail_tick()
		if _kaiba_background != null and not kaiba_entering:
			_kaiba_background.advance(320, background_tick)
			if _phase == "menu": _panel.modulate.a = 1.0
		if _joey_background != null and not kaiba_entering:
			_joey_background.advance(320, background_tick)
			if _phase == "menu": _panel.modulate.a = 1.0
		if _pending_action != "":
			var action := _pending_action
			_pending_action = ""
			if action == "choose": _retail_choose()
			elif action == "main":
				Audio.play_sfx("%s/voice/internal/return.wav" % game)
				_retail_switch("main")
			elif action == "back": _back()
	_blend.fraction = _tick_clock
	if _retail:
		# Fundidos de 0x466860/0x4666d0/0x4669d0 entre ticks.
		_blend.nodes([_panel, _panel_other])
		_options.draw_alpha = _blend.at("options", _options.alpha)
		if _options.visible: _options.queue_redraw()
		if _intro_node.visible: _intro_node.queue_redraw()
	if not _retail and _options != null and _phase in ["options_fade", "options"]:
		_blend.nodes([_panel])
		_options.draw_alpha = _blend.at("options", _options.alpha)
		_options.queue_redraw()
	# Kaiba 4694b0 comprueba los mismos umbrales que Yugi 467000 (0x1c2 y 0x707) en su menu.
	if (_retail or game == "kaiba") and _phase == "menu" and _menu == "main" and _modal == null \
			and _idle >= IDLE_FRAMES and _state_frames >= MENU_DEMO_FRAMES:
		_idle = 0
		Audio.stop_music()
		Game.open_duel_replay(game, "demo")
		return
	# Joey 48a150: mismos umbrales; su demostracion es un duelo en directo CPU contra CPU (D35).
	if game == "joey" and _phase == "menu" and _menu == "main" and _modal == null 			and _idle >= IDLE_FRAMES and _state_frames >= MENU_DEMO_FRAMES:
		_idle = 0
		Audio.stop_music()
		Game.open_joey_demo()
		return
	_cursor.advance(delta)
	_glow_time += delta
	_effect_time += delta
	for fx in _effects:
		var frames: Array = fx["frames"]
		fx["sprite"].texture = frames[int(_effect_time * EFFECT_FPS) % frames.size()]


# --- Yugi: version comercial ---------------------------------------------------------------

func _retail_tick() -> void:
	var puzzle_phase := _phase   # 0x4666d0 dibuja antes de transicionar el estado.
	var glided := PointerGlide.step(self, _mouse)
	if glided != _mouse:
		_mouse = glided
		_cursor.update(_mouse, false, -1, PlatformInput.mouse_pressed(MOUSE_BUTTON_LEFT))
	_c += 4
	_puzzle_counter += 1
	match _phase:
		"intro":
			if _c == 8:
				Audio.play_music(MUSIC[game])   # 0x20000002
			# 0x4666d0: cada mitad se actualiza en fotogramas alternos (paridad de c / 4).
			var t := _c if _c < 0x80 else _c - 0x80
			var alpha := ((t / 4) >> 1) << 4
			var bottom := ((t / 4) & 1) != 0
			_half_alpha[1 if bottom else 0] = alpha
			if _c == 0x80:
				_half_alpha = [0, 0]
			if _c < 0x80:
				# 41d320 con alfa0 limpia la salida; 4e2db0 multiplica TITLE1
				# por el alfa. La primera fase parte de negro, sin mezclar el duelo.
				_intro_from = null
				_intro_to = Assets.texture("yugi/title/title1.bmp")
			else:
				_intro_from = Assets.texture("yugi/title/title1.bmp")
				_intro_to = Assets.texture("yugi/title/title2g.bmp")
			if _c >= 0x100:
				_intro_node.visible = false
				var m: Dictionary = _menus["main"]
				_panel.texture = m["base"]
				_panel.position = m["base_pos"]
				_panel.modulate.a = clampi(_c * 4 - 0x400, 0, 0x100) / 256.0
				_menu_root.visible = true
				_glow.visible = false
			if _c == 0x13c:
				_phase = "menu"
				Game.reset_native_tick()     # Yugi467000, DAT5aed18.
				_puzzle_counter = 0
				_c = 0
				_open_menu("main")
				_panel.modulate.a = 240.0 / 256.0 # Last state1 drawing, before state2 next tick.
				_glow.visible = false
				_warp_to(0)                  # 0x46731f: 0x4663f0(2, 0)
			_intro_node.queue_redraw()
		"menu":
			# 0x4661d0 en cada tick: opcion bajo el puntero (o bajo su destino si se desliza).
			if _modal == null:
				_set_selected(_hit(PointerGlide.hover(_mouse)))
			_update_glow()
			_glow_counter += 1
		"switch":
			# Estado 4: 0x466860 con alfa (destino de duelo: c * 8; de vuelta: (0x20 - c) * 8).
			var t := (_c if _switch_to == "duel" else 0x20 - _c) * 8
			_panel_other.visible = true
			_panel_other.texture = _menus["main"]["base"]
			_panel_other.position = _menus["main"]["base_pos"]
			_panel_other.modulate.a = (0x100 - t) / 256.0
			_panel.texture = _menus["duel"]["base"]
			_panel.position = _menus["duel"]["base_pos"]
			_panel.modulate.a = t / 256.0
			_glow.visible = false
			if _c == 0x20:
				_panel_other.visible = false
				_phase = "menu"
				_c = 0
				_open_menu(_switch_to)
				_glow.visible = false # State4 draws panels without highlight on its last tick.
				_warp_to(0)                  # 0x4675b7: 0x4663f0(estado nuevo, 0)
		"options_fade":
			# Estado 5: 0x466860(-1) con alfa 0x100 - t y 0x4669d0 con t; t = c * 8 al entrar
			# y (0x20 - c) * 8 al salir. Al acabar, 0x4663f0 lleva el puntero a volver (7) o a
			# la opcion Opciones (3).
			var t := (_c if _options_to == "options" else 0x20 - _c) * 8
			_menu_root.visible = true
			_panel.texture = _menus["main"]["base"]
			_panel.position = _menus["main"]["base_pos"]
			_panel.modulate.a = (0x100 - t) / 256.0
			_glow.visible = false
			_options.visible = true
			_options.alpha = t / 256.0
			_options.queue_redraw()
			if _c == 0x20:
				_c = 0
				if _options_to == "options":
					_phase = "options"
					_menu_root.visible = false
					_options.alpha = 1.0
					_options._mouse = _mouse
					_options._warp(_options.last_index())
				else:
					_phase = "menu"
					_options.visible = false
					_open_menu("main")
					_warp_to(3)
		"options":
			_options._mouse = _mouse
			_options.tick()
		"choose":
			# 46793f..467957: alfa256 o255, NO0.466860 solo dibuja el brillo con256.
			_menu_root.visible = true
			_panel.modulate.a = (256.0 if (_c & 8) == 0 else 255.0) / 256.0
			_update_glow()
			if (_c & 8) != 0 and game != "joey": _glow.visible = false
			if _c >= 0x40:
				_menu_root.visible = true
				_panel.modulate.a = 1.0
				_phase = "menu"
				_c = 0
				_run_selected()
	if _retail:
		# 0x4666d0, estados 2-4 y 7: pieza del Puzle con alfa cos((n * 4 & 0xff) - 0x80) >> 8.
		var a: int = preload("res://scenes/title/yugi_title_puzzle.gd").alpha(_puzzle_counter)
		_puzzle.visible = puzzle_phase in ["menu", "switch", "choose"] and a > 0
		_puzzle.material.set_shader_parameter("alpha8", a)


func _draw_intro() -> void:
	if _phase != "intro" or _c >= 0x100:
		return
	for half in 2:
		var rect := Rect2(0, 300 * half, 800, 300)
		if _intro_from != null:
			_intro_node.draw_texture_rect_region(_intro_from, rect, rect)
		else:
			_intro_node.draw_rect(rect, Color.BLACK)
		var alpha: float = _blend.at([half, _intro_to], _half_alpha[half]) if _intro_to != null else 0.0
		if alpha > 0:
			_intro_node.draw_texture_rect_region(_intro_to, rect, rect, Color(1, 1, 1, alpha / 256.0))


func _retail_switch(menu: String) -> void:
	_phase = "switch"
	_switch_to = menu
	_c = 0


func _retail_choose() -> void:
	Audio.play_sfx("%s/voice/internal/decide.wav" % game)
	_phase = "choose"
	_c = 0


## 0x4663f0 -> 0x4600f0: lleva el puntero a la opcion (x 400, ultima fila de la opcion) solo
## si se esta usando el teclado; la opcion se elige en el tick siguiente por el destino.
func _warp_to(index: int) -> void:
	var m: Dictionary = _menus[_menu]
	var height: int = m["frames"][0].get_height() / m["items"].size()
	PointerGlide.request(_mouse, Vector2(400, m["glow_pos"].y + (index + 1) * height - 1))


func _set_selected(index: int) -> void:
	if index != _selected:
		_selected = index
		_glow_counter = 0
	_update_glow()


# --- entrada -------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		_idle = 0
	if event is InputEventMouse:
		_mouse = get_global_transform_with_canvas().affine_inverse() * event.position
		var left := PlatformInput.mouse_pressed(MOUSE_BUTTON_LEFT)
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			left = event.pressed
			if event.pressed: _cursor.click(_mouse, true)
		_cursor.update(_mouse, false, -1, left)


func _unhandled_input(event: InputEvent) -> void:
	if _phase in ["kaiba_intro", "joey_intro"]: return
	if _retail or (_options != null and _phase in ["menu", "switch", "choose", "options_fade", "options"]):
		_retail_input(event)
		return
	if _splash != null:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") \
				or (event is InputEventMouseButton and event.pressed):
			_dismiss_splash()
		return
	if _menu == "" or _modal != null:
		return
	if event is InputEventMouseButton:
		var over_panel := Rect2(_panel.position, _panel.texture.get_size()).has_point(event.position)
		if preload("res://core/touch_input.gd").outside(event, over_panel):
			_back()
			return
	if event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("ui_down"):
		_move(1)
	elif event.is_action_pressed("ui_accept"):
		_activate()
	elif event.is_action_pressed("ui_cancel"):
		_back()
	elif event is InputEventMouseMotion:
		var hit := _hit(event.position)
		if hit != -1 and hit != _selected:
			_set_selected(hit)
			Audio.play_sfx("%s/voice/internal/cursor.wav" % game)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _hit(event.position) != -1:
			_set_selected(_hit(event.position))
			_activate()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_back()


## Estados 2/3 de 0x467000 (0x4661d0 seleccion, 0x466550 teclado).
func _retail_input(event: InputEvent) -> void:
	if _phase == "options":
		_options.handle_input(event)
		return
	if _phase != "menu" or _modal != null:
		return
	if preload("res://core/touch_input.gd").outside(event, Rect2(_panel.position, _panel.texture.get_size()).has_point(_mouse)):
		_pending_action = "main" if _menu == "duel" else "back"
		return
	var rows: int = _menus[_menu]["items"].size()
	if event is InputEventMouseMotion:
		_set_selected(_hit(PointerGlide.hover(_mouse)))
	elif event.is_action_pressed("ui_up"):
		_warp_to(maxi(0, _selected - 1))
	elif event.is_action_pressed("ui_down"):
		_warp_to(mini(rows - 1, _selected + 1) if _selected >= 0 else 0)
	elif event.is_action_pressed("ui_accept"):
		if _selected < 0:
			_warp_to(0)
		else:
			_pending_action = "choose"
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_selected(_hit(_mouse))
		if _selected >= 0:
			_pending_action = "choose"
	elif event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_RIGHT):
		if _menu == "duel":
			_pending_action = "main"
		else:
			_pending_action = "back"


func _hit(pos: Vector2) -> int:
	if _menu == "":
		return -1
	var items: Array = _menus[_menu]["items"]
	for i in items.size():
		if _row_rect(i).has_point(pos):
			return i
	return -1


func _move(step: int) -> void:
	_set_selected(clampi(_selected + step, 0, _menus[_menu]["items"].size() - 1))
	Audio.play_sfx("%s/voice/internal/cursor.wav" % game)


func _activate() -> void:
	match _menus[_menu]["items"][_selected]:
		"duel", "list", "deck", "replay", "tutorial", "single", "exit", "options":
			Audio.play_sfx("%s/voice/internal/%s.wav" % [game, "return" if _menus[_menu]["items"][_selected] == "exit" else "decide"])
	_run_selected()


## Accion de la opcion elegida (casos de +0x20 en el estado 7 de 0x467000).
func _run_selected() -> void:
	var item: String = _menus[_menu]["items"][_selected]
	match item:
		"duel":
			_retail_switch("duel")
		"list":
			Game.open_card_list(game)
		"deck":
			Game.open_deck_editor(game)
		"replay":
			_open_replay_list()
		"tutorial":
			Audio.stop_music()
			Game.open_tutorial(game)
		"single":
			if not _duel_deck_ready(): return
			_acknowledge_joey_level()
			# Los tres menus mantienen su musica durante la entrada.
			Game.start_normal_duel(game)
		"tournament":
			if not _duel_deck_ready(): return
			_acknowledge_joey_level()
			# Y437f40, Ka469fc4->4386a0 y Jo48ae2d->44bee0: modo1.
			Game.start_normal_duel(game, 1)
		"level" when game == "joey":
			pass # Jo48a150 caso3 excluye seleccion7 de la activacion.
		"lan" when game == "joey":
			# Jo48a150: decidir (0x10000001) y pantalla de conexion LAN (4207d0, D17).
			Audio.play_sfx("%s/voice/internal/decide.wav" % game)
			Game.open_lan(game)
		"exit":
			Audio.stop_music()
			Game.open_launcher()
		"options" when _options != null:
			_phase = "options_fade"
			_options_to = "options"
			_c = 0
		_:
			# Pantallas aun no implementadas.
			Audio.play_sfx("%s/voice/internal/unable.wav" % game)


## Jo48a150 ->44aa00: el duelo sólo empieza si la validación del mazo retorna cero.
func _duel_deck_ready() -> bool:
	if game != "joey":
		return true
	# Jo48a150 ->44aa00: pruning returns 0xb, as do invalid deck sizes.
	# Keep Title/editor accessible instead of starting a duel or granting cards.
	var deck: Dictionary = SaveData.deck(game)
	var resolved := preload("res://core/native_deck_startup.gd").resolve_joey(
		deck, SaveData.data.get("collection", {}), SaveData.data.get("native_system", {}))
	if resolved.removed.is_empty() and deck.main.size() >= 40 and deck.main.size() <= 80 \
			and deck.side.size() <= 15 and deck.fusion.size() <= 15:
		return true
	if _modal != null:
		return false
	_phase = "menu"
	_c = 0
	_pending_action = ""
	Audio.play_sfx("joey/voice/internal/unable.wav")
	var dir := "joey/deck_c/"
	var background := Assets.layout(dir + "deckerror.txt")
	var ok := Assets.layout(dir + "dlg_ok_ok_derr.txt")
	var dialog := PocDialog.new(Assets.texture(dir + background.resource(0)))
	dialog.add_button("ok", Vector2(ok.position(0)), Assets.texture(dir + ok.resource(0)), Assets.texture(dir + ok.resource(1)))
	_modal = dialog
	dialog.closed.connect(func(_answer: String) -> void: _modal = null)
	add_child(dialog)
	return false


## Jo48a150 caso3: al activar duelo/match se reconoce db2=db3 y se guarda.
func _acknowledge_joey_level() -> void:
	if game != "joey": return
	var stats: Dictionary = SaveData.data.get("stats", {}).get("joey", {})
	if int(stats.get("shown_level", stats.get("level", 1))) != int(stats.get("level", 1)):
		stats["shown_level"] = int(stats.get("level", 1)) & 255
		SaveData.save()


## 0x467000 caso 7: lista de repeticiones (434f20 +4587d0(3)); Cancelar vuelve al menú.
func _open_replay_list() -> void:
	var d: PocDialog = load("res://scenes/deck_editor/deck_file_dialog.gd").for_replay(
			game, 3, DuelResult.replay_files(game))
	_modal = d
	d.closed.connect(func(id: String) -> void:
		_modal = null
		if id == "ok":
			Audio.play_sfx("%s/voice/internal/decide.wav" % game)
			Audio.stop_music()
			Game.open_duel_replay(game, "file:" + DuelResult.replays_dir(game).path_join(d.chosen_name + ".ydr"))
		else:
			Audio.play_sfx("%s/voice/internal/return.wav" % game))
	add_child(d)


func _back() -> void:
	Audio.play_sfx("%s/voice/internal/return.wav" % game)
	if _menu == "duel":
		_open_menu("main")
	else:
		Audio.stop_music()
		Game.open_launcher()


## Kaiba anima el fondo del titulo con secuencias "ti_ef_<letra>_NN" (ver title.txt).
func _build_effects() -> void:
	var groups := {}
	for i in _layout.items.size():
		var res := _layout.resource(i).to_lower()
		if not res.begins_with("ti_ef_"):
			continue
		var key := res.get_slice("_", 2).get_basename()   # "a", "b"... o "k"
		if not groups.has(key):
			groups[key] = {"pos": Vector2(_layout.position(i)), "frames": []}
		groups[key]["frames"].append(Assets.texture("%s/title/%s" % [game, _layout.resource(i)]))
	for key in groups:
		var s := Sprite2D.new()
		s.centered = false
		s.position = groups[key]["pos"]
		s.texture = groups[key]["frames"][0]
		add_child(s)
		_effects.append({"sprite": s, "frames": groups[key]["frames"]})
