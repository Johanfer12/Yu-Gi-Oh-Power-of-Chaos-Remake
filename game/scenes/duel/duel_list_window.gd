extends Node2D
## Ventana de la lista de seleccion del original: objeto de FUN_0042e820 (vtable 0x59b0f8) que
## crea FUN_00407580 en la ranura de los cuadros (DAT_005af76c+0x11ec). Mientras existe el
## motor esta parado (Duel.list_open). La ventana escribe lo mismo que el original con las
## funciones del nucleo: la entrada elegida con FUN_004073a0, las marcas con FUN_00407540 y el
## cierre con FUN_0042fda0 (Duel.list_close); al terminar la animacion de cierre libera la
## ranura (Duel.list_gone).
##
## Vtable 0x59b0f8: +8 0x42dc10 (actualizacion), +0xc 0x42e2c0 (dibujo), +0x14 0x42d7d0
## (entrada desde 0x4378a0), +0x18 0x42de30 (raton sobre la ventana), +0x1c 0x42dbd0 (cartas
## quietas), +0x20 0x42d8f0 (entrada de la lista), +0x24 0x42d850 (mostrar), +0x28 0x42d8a0
## (FUN_00540d80(0)). Base comun de ventanas: 0x42ff70 (apertura y cierre), 0x42fe40 (arrastre).
## Barra de desplazamiento: objeto en +0x1cc (vtable 0x59b068, dibujo 0x42dea0, entrada
## 0x4648d0, zona bajo el raton 0x464780).

## Centro inicial de la ventana (in_ECX[7] = 0x20d, in_ECX[8] = 300 en 0x42e820).
const START := Vector2i(0x20d, 300)
## Carta pequena del tablero (0x5af730/0x5af734).
const CARD := Vector2i(50, 72)
## Separacion entre las cinco cartas visibles (FUN_0042d760: (i - 2) * 0x40).
const SLOT_STEP := 0x40
const SLOTS := 5

var duel: Duel
## Escena del duelo (normal_duel.gd): ficha de detalle de la carta senalada (DAT_005af708).
var scene: Node
var game := "yugi"
var p := 0
var loc := -1
## in_ECX[0xd]: 0 ver, 1 elegir una, 2/3 marcar hasta min(n, 5).
var mode := 0
var native_selection := false
var native_face_down := false
var selection_limit := 5
var allow_early_close := false

## +0x14: 0x100 al crearse; baja 0x20 por fotograma hasta 0 (abierta). Al cerrar pasa a -1 y
## sigue bajando; por debajo de -0xff la ventana se destruye.
var t := 0x100
## +0x19: cierre pedido; se cierra con +0x10 en cuanto las cartas acaban su parpadeo.
var closing := false
var answer := 0
## +0x18 (byte) y +0x24/+0x28: arrastre de la ventana con el raton.
var dragging := false
var drag_off := Vector2i.ZERO
## +0x1c/+0x20 centro; +0x2c/+0x30 tamano de la imagen.
var center := START
var size := Vector2i(421, 170)
## in_ECX[0x72]: marcas hechas (modos 2/3).
var marks := 0
## in_ECX[0x71] (+0x1c4): carta del teclado.
var key_slot := 0
## +0x208: mas de cinco entradas (barra de desplazamiento e imagen/linea 2 del txt).
var has_scroll := false
## Lineas del txt: y del centro de las cartas (sin y con barra) y de la barra, relativas al
## borde superior de la ventana.
var card_y: Array[int] = [89, 81]
var bar_y := 141
var _window_tex: Texture2D
var _window_img: Image

## Barra (objeto +0x1cc). list_scroll.txt: grosor 16, botones 16, caja 16, barra 328.
var SC_THICK := 16
var SC_BUTTON := 16
var SC_BOX := 16
var SC_BAR := 328
var _decorations: Array[Dictionary] = []
var _decoration_tick := 0
## Apertura, cierre y destello de la decoracion mezclados entre ticks.
var _blend := NativeBlend.new()
var _window_open := false   # la ventana dibujada ha terminado de abrirse
var _scroll_items: Array[Dictionary] = []
const SC_PAGE := 5
var row := 0        # +0x54 (in_ECX[0x88])
var row_min := 0    # +0x58
var row_max := 0    # +0x5c
var sc_hover := 0   # [9]  zona bajo el raton (-1/1 botones, -2/2 barra, 3 caja)
var sc_last := 0    # [10]
var sc_active := -1 # [0xb] zona pulsada
var sc_box_drag := 0  # [0xc]
var sc_grab := -1   # [0xd]
var sc_repeat := 0  # [0xe]

## Cartas de la ventana (objetos 0x4111b0 en in_ECX+0x5d): existe si la entrada i tenia carta
## al crearse; +0x18/+0x1c parpadeo al elegirla (16 fotogramas).
var slot_exists: Array[bool] = []
var slot_blink: Array[int] = []
## DAT_005af708 (carta senalada) y DAT_005af70c (resaltado aditivo).
var hovered := -1
var highlight := false
var shown := false

## Entrada del raton acumulada hasta el siguiente tick nativo.
var _left := false
var _right := false
var _wheel := 0
var _clock := 0.0
var _keys := 0
## Capas de dibujo: la copia aditiva de la carta senalada y, encima, el marco y las marcas.
var _add_layer := Node2D.new()
var _top_layer := Node2D.new()


func setup(scene_node: Node, the_duel: Duel, game_id: String) -> void:
	scene = scene_node
	duel = the_duel
	game = game_id
	var info: Dictionary = duel.list_open
	p = int(info.get("p", 0))
	loc = int(info.get("loc", -1))
	mode = int(info.get("mode", 0))
	native_face_down = bool(duel.list_open.get("native_face_down", false))
	native_selection = bool(info.get("native_selection", false))
	selection_limit = int(info.get("selection_limit", 5))
	allow_early_close = bool(info.get("allow_early_close", false))
	# 0x42e820: duel/list/<nombre><p + 1>.txt (sin nombre para otras ubicaciones).
	var name: String = {0xc: "fusionlist", 0xd: "selectlist", 0xe: "gravelist", 0xf: "excludelist", -1: "selectlist"}.get(loc, "")
	var n := duel.f4073e0()
	has_scroll = n > SC_PAGE
	if has_scroll:
		row_min = 0
		row_max = n - SC_PAGE
	var layout_p := int(info.get("layout_p", p))
	var lay := Assets.layout("%s/duel/list/%s%d.txt" % [game, name, (layout_p & 0xff) + 1])
	_decorations = lay.items.slice(3)
	# Joey43a060/43ba30 toma el recurso de barra de la tercera entrada:
	# cambia con la ubicacion y, en cementerio/excluidas, con el jugador.
	var scroll_name := "list_scroll.txt"
	if game == "joey" and lay.items.size() >= 3:
		scroll_name = String(lay.items[2].get("resource", scroll_name))
	_scroll_items = Assets.layout("%s/duel/list/%s" % [game, scroll_name]).items
	if not _scroll_items.is_empty():
		var packed := int(str(_scroll_items[0].get("value", 0)))
		SC_THICK = packed / 10000000
		SC_BUTTON = packed / 100000 % 100
		SC_BOX = packed / 1000 % 100
		SC_BAR = packed % 1000
	var res: Array[String] = []
	var vals: Array[int] = []
	for it: Dictionary in lay.items:
		if it.get("resource") != null:
			res.append(String(it["resource"]))
			vals.append(int(str(it.get("value", "0"))))
	if res.size() >= 3:
		card_y = [vals[0], vals[1]]
		bar_y = vals[2]
		_window_tex = Assets.texture("%s/duel/list/%s" % [game, res[1 if has_scroll else 0]])
	if _window_tex != null:
		size = Vector2i(_window_tex.get_size())
		_window_img = _window_tex.get_image()
	for i in SLOTS:
		slot_exists.append(duel.f4073f0(i) != 0)
		slot_blink.append(0)
	z_index = 50
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add_layer.material = add
	add_child(_add_layer)
	add_child(_top_layer)
	_add_layer.draw.connect(_draw_add)
	_top_layer.draw.connect(_draw_top)


## Rectangulo de la ventana.
func _top_left() -> Vector2i:
	return center - size / 2


## FUN_0042d760: centro de la carta i.
func _slot_pos(i: int) -> Vector2i:
	return Vector2i((i - 2) * SLOT_STEP + center.x, card_y[1 if has_scroll else 0] - size.y / 2 + center.y)


## Posicion del raton segun los eventos recibidos (tambien los inyectados por las pruebas).
var _pointer := Vector2i(-1, -1)


func _input(event: InputEvent) -> void:
	if duel == null:
		return
	if event is InputEventMouse:
		_pointer = Vector2i((event as InputEventMouse).position.floor())
		if event is InputEventMouseMotion and not PointerGlide.drove(event.position): PointerGlide.cancel()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			match mb.button_index:
				MOUSE_BUTTON_LEFT:
					if preload("res://core/touch_input.gd").outside(event, Rect2i(_top_left(), size).has_point(_pointer)):
						_right = true
					else:
						_left = true
				MOUSE_BUTTON_RIGHT: _right = true
				MOUSE_BUTTON_WHEEL_UP: _wheel += 1
				MOUSE_BUTTON_WHEEL_DOWN: _wheel -= 1
		# La ventana se queda con los botones: no llegan al tablero ni al motor.
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		# FUN_00538770: 3 izquierda, 4 derecha, 6 decidir, 0xc cancelar.
		var groups: int = preload("res://core/duel_input.gd").slots(event, game)
		var bit: int = groups & (0x1e | (1 << 6))
		if groups & (1 << preload("res://core/duel_input.gd").cancel_slot(game)): bit |= 1 << 12
		if bit != 0:
			_keys |= bit
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if duel == null:
		return
	_clock += NativeClock.ticks(delta)
	var ticks := 0
	while _clock >= 1.0 and ticks < 8:
		_clock -= 1.0
		ticks += 1
		_blend.tick()
		_frame()
		if not is_inside_tree() or is_queued_for_deletion():
			return
	if _clock >= 1.0:
		_clock = 0.0
	_blend.fraction = _clock
	queue_redraw()
	_add_layer.queue_redraw()
	_top_layer.queue_redraw()


func _key(k: int) -> bool:
	return (_keys & (1 << k)) != 0


func _mouse() -> Vector2i:
	if _pointer.x < 0:
		_pointer = Vector2i(get_viewport().get_mouse_position().floor())
	return Vector2i(PointerGlide.hover(Vector2(_pointer)))


## Un fotograma: entrada (0x4378a0 -> +0x14) y actualizacion (+8).
func _frame() -> void:
	_pointer = Vector2i(PointerGlide.step(self, Vector2(_pointer)))
	if scene != null and "_pointer_pos" in scene:
		scene._pointer_pos = Vector2(_pointer)
		if scene.has_method("_refresh_cursor"): scene._refresh_cursor(true)
	hovered = -1
	highlight = false
	if t == 0:
		_input_frame()
	_left = false
	_right = false
	_wheel = 0
	_update()
	_keys = 0


## 0x42d7d0 / 0x42fe40.
func _input_frame() -> void:
	if closing:
		return
	if has_scroll:
		_scroll_input()
	var mouse := _mouse()
	if not dragging:
		_list_input()
		if _over_window(mouse) and _left:
			drag_off = mouse - center
			dragging = true
			_left = false
		return
	if PlatformInput.mouse_pressed(MOUSE_BUTTON_LEFT):
		var at := mouse - drag_off
		# Limites del original: un cuarto de la ventana puede salir de la pantalla 800x600.
		var lim_x := size.x / 4
		var lim_y := size.y / 4
		at.x = clampi(at.x, -lim_x, lim_x + 800)
		at.y = clampi(at.y, -lim_y, lim_y + 600)
		center = at
	else:
		dragging = false


## 0x42de30: pixel opaco de la imagen de la ventana bajo el raton.
func _over_window(mouse: Vector2i) -> bool:
	if _window_img == null:
		return false
	var rel := mouse - _top_left()
	if rel.x < 0 or rel.y < 0 or rel.x >= size.x or rel.y >= size.y:
		return false
	return _window_img.get_pixel(rel.x, rel.y).a > 0.5


## 0x42d8f0: entrada de la lista.
func _list_input() -> void:
	var mouse := _mouse()
	if _over_window(mouse):
		if _wheel < 0:
			if has_scroll:
				row += int(row < row_max)
		elif _wheel > 0:
			if has_scroll:
				row -= int(row_min < row)
		for i in SLOTS:
			if not slot_exists[i] or not Rect2i(_slot_pos(i) - CARD / 2, CARD).has_point(mouse):
				continue
			hovered = i
			key_slot = i
			var index := row + i
			_preview(index)
			if mode == 1:
				highlight = true
				if _left or _key(6):
					slot_blink[i] = 0x100
					closing = true
					answer = index
					duel.f4073a0(index)
					_left = false
					return
			elif mode >= 2 and mode <= 3 and native_selection and duel.f407570(index) != 0:
				if _left or _key(6):
					var previous := duel.f407570(index)
					duel.f407540(index, 0)
					for k in duel.f4073e0():
						var order := duel.f407570(k)
						if order > previous: duel.f407540(k, order - 1)
					marks -= 1
					_left = false
					return
			elif mode >= 2 and mode <= 3 and duel.f407570(index) == 0:
				highlight = true
				if _left or _key(6):
					slot_blink[i] = 0x100
					marks += 1
					duel.f407540(index, marks)
					if mini(duel.f4073e0(), selection_limit) <= marks:
						closing = true
						answer = marks if native_selection else 1
					_left = false
					return
			break
	if _right or _key(0xc):
		if mode == 0:
			_close(0)
		elif native_selection:
			if allow_early_close and marks > 0: _close(marks)
		elif mode >= 2 and mode <= 3 and marks != 0:
			for k in duel.f4073e0():
				if duel.f407570(k) == marks:
					duel.f407540(k, 0)
					marks -= 1
					break
		_right = false


## Ficha de detalle de la carta senalada (DAT_005af708).
func _preview(index: int) -> void:
	if scene != null and scene.has_method("_set_preview"):
		var ix := duel.f4073f0(index)
		scene._set_preview(duel.cards.id_of(ix) if ix != 0 and not native_face_down else -1)


## FUN_0042fda0: FUN_00540d80(valor) y la vtable +0x28 (FUN_00540d80(0)); empieza a cerrar.
func _close(value: int) -> void:
	t = -1
	answer = value
	duel.list_close(value)


## 0x42dc10 (+8) con la base 0x42ff70 y las cartas (0x410030).
func _update() -> void:
	if t == 0:
		_decoration_tick += 1 # Ka42dbf0 +0x40, tambien con cierre solicitado.
		if closing and _cards_idle():
			_close(answer)
	else:
		t -= 0x20
		if t == 0:
			shown = true
		if t < -0xff:
			duel.list_gone()
			queue_free()
			return
	if t == 0 and not closing:
		if _key(4):
			if key_slot == 4:
				if has_scroll:
					row += int(row < row_max)
			elif key_slot < duel.f4073e0() - 1:
				key_slot += 1
		if _key(3):
			if key_slot == 0:
				if has_scroll:
					row -= int(row_min < row)
			else:
				key_slot -= 1
		if _key(1) or _key(2) or _key(3) or _key(4): _warp_to_key_slot()
	# 0x410030: el parpadeo de la carta elegida baja 0x10 por fotograma.
	for i in SLOTS:
		if slot_blink[i] > 0:
			slot_blink[i] -= 0x10


func _warp_to_key_slot() -> void:
	PointerGlide.start(Vector2(_pointer), Vector2(_slot_pos(key_slot)), game)


## 0x42dbd0: ninguna carta parpadea.
func _cards_idle() -> bool:
	for i in SLOTS:
		if slot_exists[i] and slot_blink[i] > 0:
			return false
	return true


# --- Barra de desplazamiento ---------------------------------------------------------------

func _bar_origin() -> Vector2i:
	# 0x42d810 con (0, bar_y - alto/2): x = centro - (barra + 2 botones)/2, y = - grosor/2.
	return Vector2i(center.x - (SC_BAR + SC_BUTTON * 2) / 2, center.y + bar_y - size.y / 2 - SC_THICK / 2)


## FUN_004116f0: posicion de la caja.
func _box_pos() -> int:
	if sc_active == 3:
		return sc_box_drag
	var span := row_max - row_min
	if span <= 0:
		return 0
	return (span / 2 + (SC_BAR - SC_BOX) * (row - row_min)) / span


## 0x4648d0 con la zona de 0x464780.
func _scroll_input() -> void:
	var rel := _mouse() - _bar_origin()
	sc_hover = 0
	if rel.y >= 0 and rel.y < SC_THICK and rel.x >= 0 and rel.x < SC_BAR + SC_BUTTON * 2:
		var box := _box_pos()
		if rel.x < SC_BUTTON:
			sc_hover = -1
		elif rel.x >= SC_BAR + SC_BUTTON:
			sc_hover = 1
		elif rel.x < SC_BUTTON + box:
			sc_hover = -2
		elif rel.x >= SC_BOX + SC_BUTTON + box:
			sc_hover = 2
		else:
			sc_hover = 3
			sc_box_drag = box
	sc_last = 0
	if not PlatformInput.mouse_pressed(MOUSE_BUTTON_LEFT) and not _left:
		sc_active = 0
		sc_box_drag = 0
		sc_grab = -1
		return
	if sc_active == 3:
		sc_hover = 3
		_drag_box(rel.x - (SC_BUTTON + sc_grab))
		return
	if sc_hover != 0 and _left:
		_left = false
		sc_active = sc_hover
		sc_repeat = 0
		if sc_hover == 3:
			sc_grab = rel.x - SC_BUTTON - _box_pos()
	if sc_active == sc_hover:
		if (sc_repeat & 0xf) == 0:
			match sc_hover:
				1: row += int(row < row_max)
				2: row = mini(row + SC_PAGE, row_max)
				-2: row = maxi(row - SC_PAGE, row_min)
				-1: row -= int(row_min < row)
		sc_last = sc_hover
		sc_repeat += int(sc_repeat < 0x10)


## FUN_00464720: arrastre de la caja.
func _drag_box(x: int) -> void:
	var span := SC_BAR - SC_BOX
	if x < 1:
		sc_box_drag = 0
		row = row_min
	elif span <= x:
		sc_box_drag = span
		row = row_max
	else:
		sc_box_drag = x
		row = (span / 2 + (row_max - row_min) * x) / span + row_min


# --- Dibujo (0x42e2c0) ---------------------------------------------------------------------

func _draw() -> void:
	if duel == null or _window_tex == null:
		return
	# Apertura/cierre: la imagen escala desde la ubicacion de origen (FUN_00442130) con la
	# tabla de cosenos 0xa0f2c0. Con t = 0, k = 256: la ventana entera en su sitio.
	var tt := t if t <= 0 else -t
	var grow := DuelVisualMath.cos_fx(((tt + 0x100) / 2 - 0x80) & 0x1ff) >> 8
	var from := Vector2i(DuelGeometry.location(p & 1, loc, 0, duel.m.u8(DuelMem.pl(p & 1) + 2)))
	if game == "joey" and loc == DuelMem.LOC_BANISH: from = Vector2i(DuelGeometry.JOEY_EXCLUDED[p & 1])
	var c := Vector2i((center.x - from.x) * grow >> 8, (center.y - from.y) * grow >> 8) + from
	var s := Vector2i((size.x * grow) >> 8, (size.y * grow) >> 8)
	var shown: Rect2 = _blend.at("window", Rect2(c - s / 2, s))
	_window_open = t == 0 and shown == Rect2(Vector2(_top_left()), Vector2(size))
	if not _window_open:
		if shown.size.x > 0 and shown.size.y > 0:
			draw_texture_rect(_window_tex, shown, false)
		return
	draw_texture(_window_tex, Vector2(_top_left()))
	if game == "kaiba": _draw_native_decoration()
	if has_scroll:
		_draw_scroll()
	if not shown:
		return
	for i in SLOTS:
		if not slot_exists[i]:
			continue
		var index := row + i
		var at := _slot_pos(i)
		var ix := duel.f4073f0(index)
		var bits := duel.f407440(index)
		# Barra propio/rival y los iconos de origen y estado, centrados 8 px sobre la carta.
		var owner_mask := 0x800 if native_selection else 0x400
		var icons := JOEY_ICONS if native_selection else ICONS
		var bar := Assets.texture("%s/duel/list_icon/%s.png" % [game, "list_oppo" if (bits & owner_mask) != 0 else "list_myself"])
		if bar != null:
			var bs := Vector2i(bar.get_size())
			draw_texture(bar, Vector2(at.x - bs.x / 2, -(bs.y / 2) - CARD.y / 2 - 8 + at.y))
		var rest := bits & ~owner_mask
		var hand_icon := Assets.texture("%s/duel/list_icon/list_hand.png" % game)
		var iw := int(hand_icon.get_size().x) if hand_icon != null else 16
		var ih := int(hand_icon.get_size().y) if hand_icon != null else 16
		var x := at.x - (_popcount(rest) * iw) / 2
		var k := 2
		while rest != 0:
			if (rest & 1) != 0:
				var ic := Assets.texture("%s/duel/list_icon/%s.png" % [game, icons[k - 2]])
				if ic != null:
					draw_texture(ic, Vector2(x, -(ih / 2) - CARD.y / 2 - 8 + at.y))
				x += iw
			k += 1
			rest >>= 1
		# ATK/DEF de los monstruos bajo la carta (fuente 0 de number.txt).
		var prop := duel.f401a20(ix)
		var kind := (prop >> 20) & 0x1f
		if kind != 0 and kind < 0x15:
			var y := CARD.y / 2 + 4 + at.y
			_glyph(0, 11, 10, at.x + 3 - 6, y)
			_number(0, 11, at.x - 3, y, ((prop >> 9) & 0x1ff) * 10)
			_number(0, 11, at.x + 0x1b, y, (prop & 0x1ff) * 10)
		_draw_card(ix, at)


const ICONS := ["list_hand", "list_deck", "list_grave", "list_fusion", "list_exception",
		"list_board", "list_summon", "list_material", "list_hole", "list_fusatu"]
const JOEY_ICONS := ["list_hand", "list_deck", "list_grave", "list_fusion", "list_exception",
		"list_board", "list_summon", "list_material", "list_gate", "list_hole", "list_fusatu"]
const FONTS := ["duel_fonts", "duel_fontm", "duel_fontm_b", "duel_fontm_r", "duel_fontm_k",
		"duel_fontl", "damage00", "damage01", "duel_fontm_y"]


static func _popcount(v: int) -> int:
	var n := 0
	while v != 0:
		n += v & 1
		v >>= 1
	return n


## Carta de la ventana (vtable +0xc de 0x4111b0): imagen pequena boca arriba (dorso si la
## entrada no tiene carta visible, FUN_004073f0 = 0).
func _card_tex(ix: int) -> Texture2D:
	return CardDB.card_texture(duel.cards.id_of(ix), true) if ix != 0 and not native_face_down else Assets.texture("common/mini/card_ura.png")


func _draw_card(ix: int, at: Vector2i) -> void:
	var tex := _card_tex(ix)
	if tex != null:
		draw_texture_rect(tex, Rect2(at - CARD / 2, CARD), false)


## Parpadeo de la carta elegida (+0x18 = 1): bit 5 del contador +0x1c.
func _blinking(i: int) -> bool:
	return slot_blink[i] > 0 and ((slot_blink[i] >> 5) & 1) != 0


func _visible_slots() -> bool:
	return duel != null and _window_tex != null and t == 0 and _window_open and shown


## Copia aditiva con alfa 0x40 (vtable +0xac del dibujante) de la carta senalada cuando hay
## DAT_005af70c, o de la que parpadea.
func _draw_add() -> void:
	if not _visible_slots():
		return
	for i in SLOTS:
		if slot_exists[i] and ((hovered == i and highlight) or _blinking(i)):
			var tex := _card_tex(duel.f4073f0(row + i))
			if tex != null:
				_add_layer.draw_texture_rect(tex, Rect2(_slot_pos(i) - CARD / 2, CARD), false, Color(1, 1, 1, 64.0 / 255.0))


## Marco card_waku de la carta senalada o que parpadea y, en los modos 2/3, el orden de cada
## entrada marcada (FUN_00460730 con la fuente 7, centrado en la carta).
func _draw_top() -> void:
	if not _visible_slots():
		return
	for i in SLOTS:
		if not slot_exists[i]:
			continue
		var index := row + i
		var at := _slot_pos(i)
		if hovered == i or _blinking(i):
			# card_waku#s (propio) o #s2 segun el bit 12 de la entrada (0, 0, indice): es lo
			# que lee el original para un objeto de la lista (su +0x24 vale indice << 5).
			var owner := (duel.m.u32(duel.f5419b0(0, 0, index)) >> 12) & 1
			var frame := Assets.texture("%s/duel/card/%s.png" % [game, "card_waku#s2" if owner != 0 else "card_waku#s"])
			if frame != null:
				_top_layer.draw_texture(frame, Vector2(at) - frame.get_size() / 2)
		if mode >= 2 and mode <= 3 and duel.f407570(index) != 0:
			var order := duel.f407570(index)
			var tex := _font(7)
			if tex != null:
				var w := _number_width(7, 12, order)
				_number(7, 12, at.x + w / 2, at.y - int(tex.get_size().y) / 2, order, _top_layer)


func _font(f: int) -> Texture2D:
	return Assets.texture("%s/duel/font/%s.png" % [game, FONTS[f]])


func _glyph(f: int, count: int, g: int, x: int, y: int, canvas: CanvasItem = null) -> void:
	var tex := _font(f)
	if tex == null:
		return
	var w := int(tex.get_size().x) / count
	(canvas if canvas != null else self).draw_texture_rect_region(tex, Rect2(x, y, w, tex.get_size().y), Rect2(g * w, 0, w, tex.get_size().y))


## FUN_004604f0: digitos de derecha a izquierda; el borde derecho queda en x.
func _number(f: int, count: int, x: int, y: int, value: int, canvas: CanvasItem = null) -> void:
	var tex := _font(f)
	if tex == null:
		return
	var w := int(tex.get_size().x) / count
	var v := absi(value)
	while true:
		x -= w
		_glyph(f, count, v % 10, x, y, canvas)
		v /= 10
		if v == 0:
			break


func _number_width(f: int, count: int, value: int) -> int:
	var tex := _font(f)
	var w := int(tex.get_size().x) / count if tex != null else 0
	var n := 0
	var v := value
	while true:
		n += w
		v /= 10
		if v == 0:
			break
	return n


## 0x42dea0: barra, botones (1 = resaltado) y caja.
func _draw_scroll() -> void:
	var o := _bar_origin()
	if game in ["kaiba", "joey"] and _scroll_items.size() >= 6:
		var left := 2 + 2 * int(sc_hover == -1 and sc_last != -1)
		var right := 3 + 2 * int(sc_hover == 1 and sc_last != 1)
		# Joey43ba30 lee ocho imagenes: normal, over y pulsada (izquierda/derecha).
		if game == "joey" and _scroll_items.size() >= 8:
			left = 2 + 2 * (2 if sc_last == -1 else 1 if sc_hover == -1 else 0)
			right = 3 + 2 * (2 if sc_last == 1 else 1 if sc_hover == 1 else 0)
		for index in [0, left, right, 1]:
			var item: Dictionary = _scroll_items[index]
			var tex := Assets.texture("%s/duel/list/%s" % [game, item.resource])
			var packed := int(str(item.get("value", 0))) if index != 0 else 0
			var offset := Vector2i(packed / 1000, packed % 1000)
			var x := SC_BUTTON if index == 0 else SC_BUTTON + _box_pos() if index == 1 else SC_BUTTON + SC_BAR if index in [3, 5, 7] else 0
			if tex: draw_texture(tex, Vector2(o + Vector2i(x, 0) - offset))
		return
	var bar := Assets.texture("%s/duel/list/scroll_bar.png" % game)
	if bar != null:
		draw_texture(bar, Vector2(o.x + SC_BUTTON, o.y))
	var left := Assets.texture("%s/duel/list/scroll_left%d.png" % [game, 1 if sc_hover == -1 and sc_last != -1 else 0])
	if left != null:
		draw_texture(left, Vector2(o))
	var right := Assets.texture("%s/duel/list/scroll_right%d.png" % [game, 1 if sc_hover == 1 and sc_last != 1 else 0])
	if right != null:
		draw_texture(right, Vector2(o.x + SC_BUTTON + SC_BAR, o.y))
	var box := Assets.texture("%s/duel/list/scroll_box.png" % game)
	if box != null:
		draw_texture(box, Vector2(o.x + SC_BUTTON + _box_pos(), o.y))

## Ka42e2a0: animaciones del txt, coordenadas X*1000+Y relativas a la esquina.
func _draw_native_decoration() -> void:
	var indices: Array[int] = []
	var alpha := 1.0
	if loc in [12, 14]:
		var frames := _decorations.size() / 4
		if frames <= 0: return
		for group in 4: indices.append((_decoration_tick / 2) % frames + group * frames)
	elif loc == 15:
		for i in _decorations.size(): indices.append(i)
		alpha = _blend.at("decoration", clampi(DuelVisualMath.cos_fx((_decoration_tick & 63) * 4 - 128) >> 8, 0, 255) / 256.0)
	else:
		indices = [(_decoration_tick / 6) % 7, (_decoration_tick / 6) % 7 + 7, (_decoration_tick / 4) % 6 + 14]
	for index in indices:
		if index >= _decorations.size(): continue
		var item: Dictionary = _decorations[index]
		var tex := Assets.texture("%s/duel/list/%s" % [game, item.resource])
		var packed := int(str(item.get("value", 0)))
		if tex: draw_texture(tex, Vector2(_top_left() + Vector2i(packed / 1000, packed % 1000)), Color(1, 1, 1, alpha))
