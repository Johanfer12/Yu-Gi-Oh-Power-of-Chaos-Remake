extends Node2D
## Kaiba: 467ad0/467a40/467c80 y 4305d0; recursos propios, altura par,
## apertura con dos escalas y feedback de botones/opciones. Ver VENTANAS_KAIBA.md.
## Ventana de los cuadros de dialogo del duelo (clase base FUN_00465d90/FUN_00465840, dibujo
## de la ventana 0x465a30/0x465c50, botones FUN_004303b0). El motor la mantiene abierta con
## Duel.dialog_open y se contesta con la escena (normal_duel._answer_dialog -> FUN_0042fda0).
##
## Tipos (constructores 0x431db0 mensaje/OK, 0x431ee0 Si/No, 0x432050 N opciones, 0x432240
## posicion, 0x432400 moneda, 0x432570 cartas, 0x4326a0 niveles; vtables 0x59b218, 0x59b250,
## 0x59b288, 0x59b2c0, 0x59b310, 0x59b348, 0x59b39c).
##
## Geometria: centro (0x20d, 300) (0x465d90). yoko_u 410x35, yoko_d 410x22, tate 12x13 (columnas
## a 14 px de los bordes, un tramo cada 13 px) y back 363 px de ancho centrado; el alto de la
## ventana es multiplo de 13 (0x465840: ((alto + 12) / 13) * 13). Los botones de button.txt van
## relativos al centro X y al borde inferior interno (coordenadas (0, -19) para OK, (-+60, -19)
## para Si/No); las opciones de los tipos 2/3 usan sentaku_1/2/3 (normal/foco/pulsado), una
## cada 0x17 px (0x432050).
##
## Arrastre y ciclo compartido: 42fe40/42ff70/42fda0. La respuesta inicia el
## cierre; la ranura se libera ocho ticks despues. Yugi usa 465c50 sin fundido;
## Kaiba usa 467a40 con escalas distintas al abrir y cerrar. La composicion Joey
## sigue pendiente de cotejo especifico (D13). Los tipos8/9 consultan los selectores.

const IconSelector = preload("res://core/joey_icon_selector.gd")
const DialogText = preload("res://scenes/duel/duel_dialog_text.gd")
var _icons: RefCounted
var _icon_layer: Node2D
const CENTER := Vector2i(0x20d, 300)
const WIDTH := 410
const TEXT_WIDTH := 350
const FONT_SIZE := 12
const LINE := 13
const TOP_PAD := 16
const OPTION_STEP := 0x17
const BTN := Vector2i(111, 33)

var scene: Node
var duel: Duel
var game := "yugi"
var type := 0
var data: Dictionary = {}
var _text := ""
var _lines: Array[String] = []   # etiquetas de las opciones (tipos 2/3)
var _height := 0
var _text_height := 0
## +0x14: 0x100 al crearse y baja 0x20 por fotograma hasta 0 (la ventana atiende al raton).
var _t := 0x100
## Tick en que termino de abrirse: el deslizamiento al boton (6 ticks) no admite clics (Yu/Ka).
var _opened_tick := 1 << 30
var _clock := 0.0
## Retener el flanco del clic hasta el siguiente tick nativo, aunque Godot dibuje mas rapido.
var _selection_press_bits := 0
var _pointer := Vector2(-1000, -1000)
var _pressed := -1
## Elementos pulsables: {rect (Rect2 en pantalla), answer, tex [normal, foco, pulsado],
## mask (Image o null), kind ("button", "option", "card", "coin")}.
var _items: Array[Dictionary] = []
var _hover := -1
var _add_layer := Node2D.new()
var _native_tick := 0
var _text_width := TEXT_WIDTH
var _feedback := 0
var _feedback_item := -1
var _interior_width := 358
var _dragging := false
var _drag_offset := Vector2i.ZERO
## Apertura, cierre y pulsacion mezclados entre ticks. El contenido aparece cuando el marco
## dibujado ha terminado de abrirse.
var _blend := NativeBlend.new()


func begin_close() -> void:
	if _t < 0:
		return
	_t = -1
	_dragging = false
	_glide = {}
	PointerGlide.cancel()
	_pressed = -1
	_hover = -1
	queue_redraw()
	if _icon_layer != null: _icon_layer.queue_redraw()
	_add_layer.queue_redraw()


func _request_answer(value: int) -> void:
	if _t < 0:
		return
	begin_close()
	scene._answer_dialog(value)


## 465c50: primero crece el ancho de las tapas; luego el alto interior.
func _frame_geometry() -> Vector2:
	var q := -absi(_t)
	if q + 256 > 127:
		return Vector2(1, DuelVisualMath.trunc_div((q + 128) * _height * 2, 256))
	return Vector2(float(q + 256) / 128.0, 0)


func _drag_to(mouse: Vector2) -> void:
	var center := Vector2i(mouse.floor()) - _drag_offset
	var width := _interior_width
	var lim_x: int = width / 4
	var lim_y: int = _height / 4
	center.x = clampi(center.x, -lim_x, 800 + lim_x)
	center.y = clampi(center.y, -lim_y, 600 + lim_y)
	position = Vector2(center - CENTER)



func setup(scene_node: Node, the_duel: Duel, game_id: String, text: String) -> void:
	scene = scene_node
	duel = the_duel
	game = game_id
	data = duel.dialog_open
	type = int(data.get("type", 0))
	_text = text
	z_index = 60
	var lines := text.split("\n")
	var n := int(data.get("buttons", 0))
	if (type == 2 or type == 3) and n > 0 and lines.size() > n:
		for k in n:
			_lines.append(DialogText.strip_marks(lines[lines.size() - n + k]).strip_edges())
		_text = "\n".join(lines.slice(0, lines.size() - n)).strip_edges()
	elif type == 2 or type == 3:
		type = 0
	else:
		_text = text.strip_edges()
	var font := ThemeDB.fallback_font
	if game == "joey": _text_width = 372 #488140: 412 - 2*16 -8.
	if game == "kaiba": _text_width = 322 # 467ad0: 368 - 15*2 - 8; texto resta otros8.
	var plain := DialogText.strip_marks(_text)
	var size := font.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_CENTER, _text_width, FONT_SIZE)
	_text_height = ceili(size.y / font.get_height(FONT_SIZE)) * LINE if plain != "" else 0
	# 0x465840: alto redondeado a multiplos de 13; extra por tipo (0x432240 +100, 0x432400 +50,
	# 0x432570 y 0x4326a0 +40) y los botones debajo del texto.
	var extra: int = {0: 40, 1: 40, 6: 100, 7: 50, 8: 40, 9: 40}.get(type, 0)
	if type == 2 or type == 3:
		extra = _lines.size() * OPTION_STEP + 4
	_height = (TOP_PAD + 13 + _text_height + extra + 12) / 13 * 13
	if game == "kaiba":
		_height = _text_height + 12 + (16 if type == 1 else 0)
		_height += _lines.size() * OPTION_STEP if type in [2, 3] else {6: 100, 7: 50, 8: 40, 9: 40}.get(type, 0)
		_height += _height & 1 # 467ad0: alto par.
	if game == "joey":
		if type in [4, 5]:
			extra = 96 if type == 4 else 64
			_icons = IconSelector.new()
			_icons.setup(type, int(data.get("icon_arg", 0)))
		_interior_width = 380
		_height = _text_height + 12 + extra
		_height += _height & 1
	elif game == "kaiba":
		_interior_width = 330 #467ad0: ancho de win_top menos dos márgenes15 y ocho.
	else:
		var up := _tex("yoko_u")
		var side := _tex("tate")
		if up and side:
			_interior_width = up.get_width() - 2 * (14 + side.get_width())
	_build_items()
	if _icons != null:
		_icon_layer = Node2D.new()
		_icon_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_icon_layer)
		_icon_layer.draw.connect(_draw_icons)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add_layer.material = add
	add_child(_add_layer)
	_add_layer.draw.connect(_draw_add)


func _top() -> int:
	return CENTER.y - _height / 2


func _bottom() -> int:
	return CENTER.y + _height / 2


func _tex(name: String) -> Texture2D:
	return Assets.texture("%s/duel/dialog/%s.png" % [game, name])


## button.txt: sufijo del idioma seleccionado si existe el PNG, si no _e.
func _button_tex(base: String, state: String) -> Texture2D:
	if game == "joey":
		var lang: String = Assets.lang if Assets.exists("joey/duel/dialog/%s_%s_out.png" % [base, Assets.lang]) else "e"
		return _tex("%s_%s_%s" % [base, lang, "out" if state == "n" else "over"])
	if game == "kaiba":
		if state == "n": return _tex("null")
		var lang: String = Assets.lang if Assets.exists("kaiba/duel/dialog/%s_%s01.png" % [base, Assets.lang]) else "e"
		return _tex("%s_%s%02d" % [base, lang, 2 if state == "d" else 1])
	var lang: String = Assets.lang if Assets.exists("%s/duel/dialog/%s_%s_%s.png" % [game, base, Assets.lang, state]) else "e"
	return _tex("%s_%s_%s" % [base, lang, state])


func _build_items() -> void:
	if type in [8, 9]: return # No tienen botones ni mascaras de entrada.
	var mask := _tex("ok_e_out" if game == "joey" else "ok_e01" if game == "kaiba" else "mask")
	var mask_img: Image = mask.get_image() if mask != null else null
	var bottom := _bottom()
	match type:
		4, 5:
			if game != "joey": return
			var atlas := Assets.texture("joey/duel/card/icon_syuzoku.png" if type == 4 else "joey/duel/card/icon_zokusei.png")
			if atlas == null: return
			var cells := 20 if type == 4 else 10
			var cell := Vector2i(atlas.get_width() / cells, atlas.get_height())
			for i in (20 if type == 4 else 6):
				_items.append({"rect": Rect2(IconSelector.origin(type,i),cell * 2), "answer": i,"kind": "icon","atlas": atlas,"src": Rect2(i * cell.x,0,cell.x,cell.y)})
		0:
			_add_button(0, "ok", 0, mask_img)
		1:
			_add_button(-60, "yes", 1, mask_img)
			_add_button(60, "no", 0, mask_img)
		2, 3:
			var s1 := _tex("3taku_mask" if game == "joey" else "3taku_off" if game == "kaiba" else "sentaku_1")
			var img: Image = s1.get_image() if s1 != null else null
			var n := _lines.size()
			for i in n:
				var cy := bottom + (i - n) * OPTION_STEP + 11
				if game == "kaiba": cy = _top() + _text_height + 14 + i * OPTION_STEP
				var dimensions := s1.get_size() if s1 else Vector2(340, 21)
				_items.append({"rect": Rect2(Vector2(CENTER.x, cy) - dimensions / 2, dimensions), "answer": i, "kind": "option",
						"tex": [s1, s1 if game in ["kaiba", "joey"] else _tex("sentaku_2"), s1 if game in ["kaiba", "joey"] else _tex("sentaku_3")], "mask": img, "label": _lines[i]})
		6:
			var cy := bottom - 50
			for i in 2:
				var vertical := i == 0
				var w := 59.0 if vertical else 86.0
				var h := 86.0 if vertical else 59.0
				_items.append({"rect": Rect2(CENTER.x + (i * 2 - 1) * 50 - w / 2, cy - h / 2, w, h), "answer": i, "kind": "card"})
		7:
			var coin := Assets.texture("%s/duel/effect/coin_rotate.png" % game)
			var img: Image = coin.get_image() if coin != null else null
			var cell := int(coin.get_size().x) / 14 if coin != null else 40
			for i in 2:
				var c := 13 if i == 1 else 6
				_items.append({"rect": Rect2(CENTER.x + (i * 2 - 1) * 50 - cell / 2.0, bottom - 25 - cell / 2.0, cell, cell),
						"answer": i, "kind": "coin", "tex": [coin], "cell": c, "mask": img})


func _add_button(dx: int, base: String, answer: int, mask_img: Image) -> void:
	var cy := bottom_y() - 19
	var dimensions := Vector2(BTN)
	if game in ["kaiba", "joey"]:
		var index: int = {"ok": 0, "yes": 4, "no": 8}[base]
		var layout := Assets.layout("joey/duel/dialog/button_s.txt" if game == "joey" else "kaiba/duel/dialog/button.txt")
		dx = int(str(layout.items[index].get("value", 0)))
		cy = bottom_y() + int(str(layout.items[index + 1].get("value", 0)))
		var tex := _button_tex(base, "b")
		if tex:
			dimensions = tex.get_size()
			mask_img = tex.get_image()
	_items.append({"rect": Rect2(Vector2(CENTER.x + dx, cy) - dimensions / 2, dimensions), "answer": answer,
			"kind": "button", "tex": [_button_tex(base, "n"), _button_tex(base, "b"), _button_tex(base, "d")], "mask": mask_img})


func bottom_y() -> int:
	return _bottom()


## Desplazamiento del puntero (0x45fff0 / 0x460060 / 0x45ff20): desde la posicion actual al
## centro del elemento; interpolador lineal 0 -> 0x80 en 6 pasos (0x51d610) y posicion =
## inicio + delta * T[v - 0x80] >> 16 (frenada en seno). Opcion DAT_005aed20+0xef5, activa por
## defecto. Se abandona si el jugador mueve el raton (0x45ff70).
var _glide := {}
var _keys := 0
var _key_item := 0


func _glide_start(index := 0, keyboard := false) -> void:
	if _items.is_empty(): return
	var from := _pointer + position if _pointer.x > -999 else get_viewport().get_mouse_position()
	var r: Rect2 = _items[index]["rect"]
	if keyboard:
		PointerGlide.request(from, r.get_center() + position, game)
	else:
		PointerGlide.start(from, r.get_center() + position, game)
	_glide = {"at": from} if PointerGlide.active else {}


func _glide_step() -> void:
	if _glide.is_empty():
		return
	var mouse := _pointer + position if _pointer.x > -999 else Vector2(_glide["at"])
	var at := PointerGlide.step(self, mouse)
	PointerGlide.note(at)
	_pointer = at - position
	_hover = _pick(PointerGlide.hover(at) - position)
	if scene != null and "_pointer_pos" in scene:
		scene._pointer_pos = at
		if scene.has_method("_refresh_cursor"): scene._refresh_cursor(true)
	_glide["at"] = at
	if not PointerGlide.active:
		_glide = {}


## 4304f0/4306e0/4309e0/430b40 y 430ef0: grupos3/4 en pares;1/2 en opciones.
func _keyboard_tick() -> void:
	if _t != 0 or _feedback > 0 or _items.is_empty() or (_icons != null and _icons.complete):
		_keys = 0
		return
	var previous := 1 if type in [2, 3] else 3
	var following := 2 if type in [2, 3] else 4
	if (_keys & ((1 << previous) | (1 << following))) != 0:
		if type in [4, 5]:
			_key_item = (_items.size() - 1 if _hover < 1 else _hover - 1) if _keys & (1 << previous) else (0 if _hover >= _items.size() - 1 else _hover + 1)
		elif type in [2, 3]:
			_key_item = clampi(_key_item + (-1 if _keys & (1 << previous) else 1), 0, _items.size() - 1)
		else:
			_key_item = 0 if _keys & (1 << previous) else mini(1, _items.size() - 1)
		_glide_start(_key_item, true)
	if _keys & (1 << 6):
		var picked := _pick(PointerGlide.hover(_pointer + position) - position)
		if picked >= 0: _activate_item(picked)
	if _keys & (1 << preload("res://core/duel_input.gd").cancel_slot(game)):
		if type == 1: _request_answer(0)
		elif type == 3 and int(data.get("default", -1)) >= 0:
			_request_answer(int(data["default"]))
	_keys = 0


func _activate_item(index: int) -> void:
	if _icons != null:
		if _icons.select(index) and _icons.complete:
			_glide = {}
			PointerGlide.cancel()
		return
	if game in ["kaiba", "joey"] and _items[index].kind in ["button", "option"]:
		_feedback_item = index
		_feedback = 256
	else:
		_request_answer(int(_items[index].answer))


func _process(delta: float) -> void:
	if _t == 0 and type in [8, 9]:
		_selection_press_bits |= duel.m.u32(0xa114a8)
	_clock += NativeClock.ticks(delta)
	while _clock >= 1.0:
		_clock -= 1.0
		_native_tick += 1
		_blend.tick()
		if _icons != null and _t == 0 and _icons.tick():
			_request_answer(_icons.answer)
			return
		if _feedback > 0:
			var option: bool = _items[_feedback_item].kind == "option"
			_feedback -= (64 if option else 32) if game == "joey" else (32 if option else 64)
			if _feedback <= 0:
				_request_answer(int(_items[_feedback_item].answer))
				return
		if _t != 0:
			_t -= 0x20
			# 0x42ff70: al terminar de aparecer llama a la ranura +0x24 (0x430600 en OK y Si/No,
			# 0x430dc0 en N botones: primera opcion), que lleva el puntero al boton (0x45fff0).
			if _t == 0: _opened_tick = _native_tick
			if _t == 0 and type <= 5 and not _items.is_empty():
				_glide_start()
			if _t < -255:
				if scene.has_method("_dialog_gone"):
					scene._dialog_gone(self)
				queue_free()
				return
		_glide_step()
		_keyboard_tick()
		if _t == 0 and type in [8, 9]:
			# Y430bc0/430bf0: estas ventanas leen seleccion del tablero y se cierran
			# cuando 578be0/56b290 termina; no tienen boton ni cierre por clic vacio.
			var hover: Dictionary = scene._hit_card(scene._pointer_pos)
			if not hover.is_empty(): hover["card"] = duel.f5419b0(hover["p"], hover["loc"], hover["i"])
			duel.set_frame_input(_selection_press_bits, 0, hover, -1)
			_selection_press_bits = 0
			var complete: int = duel.f578be0() if type == 8 else duel.f56b290()
			duel.set_frame_input(0, 0, hover, -1)
			if complete != 0:
				_request_answer(0)
				return
	_blend.fraction = _clock
	queue_redraw()
	if _icon_layer != null: _icon_layer.queue_redraw()
	_add_layer.queue_redraw()


## Elemento bajo el puntero (vtable +0x18 de cada boton: pixel del mask no transparente).
func _pick(pos: Vector2) -> int:
	if _t != 0:
		return -1
	for i in _items.size():
		var it := _items[i]
		var r: Rect2 = it["rect"]
		if not r.has_point(pos):
			continue
		var local := Vector2i(pos - r.position)
		var kind: String = it["kind"]
		if kind == "coin":
			var img: Image = it["mask"]
			if img != null:
				var x := local.x + int(it["cell"]) * int(r.size.x)
				if x < img.get_width() and img.get_pixel(x, local.y).a < 0.5:
					continue
		elif kind == "button" or kind == "option":
			var img: Image = it["mask"]
			if img != null and local.x < img.get_width() and local.y < img.get_height() and img.get_pixel(local.x, local.y).a <= 0.0:
				continue
		return i
	return -1


## 4658d0: tapa superior/inferior por mascara; cuerpo entre las columnas.
func _over_window(at: Vector2) -> bool:
	if game == "joey":
		var texture := _tex("dial_base" if at.y < _bottom() else "dial_bott")
		if texture == null: return false
		var origin := Vector2(CENTER.x - texture.get_width() / 2, _top() - 36 if at.y < _bottom() else _bottom() - 22)
		var pixel := Vector2i((at - origin).floor())
		if pixel.x < 0 or pixel.y < 0 or pixel.x >= texture.get_width() or pixel.y >= texture.get_height(): return false
		return texture.get_image().get_pixelv(pixel).a > 0
	if game == "kaiba":
		return Rect2(CENTER.x - _interior_width / 2, _top(), _interior_width, _height).has_point(at)
	var name := "yoko_u" if at.y < _top() + 13 else "yoko_d"
	if at.y >= _top() + 13 and at.y < _bottom():
		var side := _tex("tate")
		var extra := side.get_width() if side else 12
		return at.x >= CENTER.x - _interior_width / 2 - extra and at.x < CENTER.x + _interior_width / 2 + extra
	var texture := _tex(name)
	if texture == null: return false
	var origin := Vector2(CENTER.x - texture.get_width() / 2, _top() + 13 - texture.get_height() if name == "yoko_u" else _bottom())
	var pixel := Vector2i((at - origin).floor())
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= texture.get_width() or pixel.y >= texture.get_height(): return false
	return texture.get_image().get_pixelv(pixel).a > 0


func _input(event: InputEvent) -> void:
	if _feedback > 0 or _t != 0 or (_icons != null and _icons.complete): return
	# Yu/Ka: durante los 6 ticks del deslizamiento al boton (45fff0) el clic no cuenta. En la tanda variada
	# el original ignoro un clic 11 ticks despues de abrirse el cuadro y acepto el de los 23; el port
	# cerraba con el primero y el segundo elegia un objetivo propio (Hane-Hane, 30-10-2026).
	# Solo los clics sobre un boton: arrastrar el cuadro por el marco sigue valiendo.
	if game in ["yugi", "kaiba"] and _native_tick - _opened_tick < 6 and event is InputEventMouseButton 			and _pick(event.position - position) >= 0: return
	if event is InputEventKey and event.pressed and not event.echo and type not in [8, 9]:
		# La ventana consume el evento antes de que llegue al autoload: anotar su actividad.
		Game._input(event)
		_keys |= preload("res://core/duel_input.gd").slots(event, game)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if not PointerGlide.drove(event.position):
			PointerGlide.cancel()
			_glide = {}
		if _dragging:
			_drag_to(event.position)
		_pointer = event.position - position
		_hover = -1 if _dragging else _pick(_pointer)
	elif event is InputEventMouseButton:
		_pointer = event.position - position
		_hover = _pick(_pointer)
		var cancellable := type == 1 or (type == 3 and int(data.get("default", -1)) >= 0)
		var outside := cancellable and preload("res://core/touch_input.gd").outside(event, _over_window(_pointer) or _hover >= 0)
		if event.button_index == MOUSE_BUTTON_LEFT and not outside:
			if event.pressed:
				if _icons != null and _hover >= 0:
					_activate_item(_hover)
					get_viewport().set_input_as_handled()
					return
				_pressed = _hover
				if _hover < 0 and _over_window(_pointer):
					_dragging = true
					_drag_offset = Vector2i(event.position.floor()) - CENTER - Vector2i(position)
			else:
				if _dragging:
					_dragging = false
					_pressed = -1
					get_viewport().set_input_as_handled()
					return
				var was := _pressed
				_pressed = -1
				# Los botones contestan al soltar sobre ellos; cartas y monedas al pulsar.
				if was >= 0 and was == _hover:
					_activate_item(was)
		elif (event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) or outside:
			# Ranura +0x20 de cada ventana: 0x430650 (Si/No) contesta 0 = No, 0x430e10 (N botones)
			# su respuesta por defecto si la tiene; 0x431e40 (OK) no reacciona al clic derecho.
			if type == 1:
				_request_answer(0)
			elif type == 3 and int(data.get("default", -1)) >= 0:
				_request_answer(int(data["default"]))
			if outside:
				get_viewport().set_input_as_handled()
				return
	# Solo los botones se quedan en la ventana: el movimiento sigue llegando a la escena para
	# que el cursor de mano se mueva, como en el original.
	if event is InputEventMouseButton and (type not in [8, 9] or _dragging or _over_window(_pointer)):
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if game == "joey":
		_draw_joey()
		return
	if game == "kaiba":
		_draw_kaiba()
		return
	modulate.a = 1.0
	var geometry: Vector2 = _blend.at("frame", _frame_geometry())
	var height := int(geometry.y)
	var zoom := Vector2(geometry.x, 1)
	draw_set_transform(Vector2(CENTER) * (Vector2.ONE - zoom), 0, zoom)
	var cx := CENTER.x
	var top: int = CENTER.y - height / 2
	var back := _tex("back")
	if back != null:
		var x := cx - _interior_width / 2
		var y := top + 13
		var left := height - 13
		while left > 0:
			var seg := mini(left, int(back.get_size().y))
			draw_texture_rect_region(back, Rect2(x, y, _interior_width, seg), Rect2(0, 0, _interior_width, seg))
			y += seg
			left -= seg
	var tate := _tex("tate")
	if tate != null:
		var y := top + 13
		while y < top + height:
			var seg := mini(13, top + height - y)
			for x in [cx - WIDTH / 2 + 14, cx + WIDTH / 2 - 14 - int(tate.get_size().x)]:
				draw_texture_rect_region(tate, Rect2(x, y, tate.get_size().x, seg), Rect2(0, 0, tate.get_size().x, seg))
			y += 13
	var up := _tex("yoko_u")
	if up != null:
		var cut := maxi(13 - height, 0)
		draw_texture_rect_region(up, Rect2(cx - WIDTH / 2, top + 13 - up.get_height(), up.get_width(), up.get_height() - cut), Rect2(0, 0, up.get_width(), up.get_height() - cut))
	var down := _tex("yoko_d")
	if down != null:
		draw_texture(down, Vector2(cx - WIDTH / 2, top + height))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if _t != 0 or geometry != _frame_geometry(): return
	var font := ThemeDB.fallback_font
	if _text != "":
		_draw_text(font, _text, Vector2(cx - TEXT_WIDTH / 2.0, top + 13 + 3), TEXT_WIDTH)
	for i in _items.size():
		_draw_item(i, font)
	match type:
		8:
			_draw_cards()
		9:
			_draw_stars()

## 4884c0: entrada vertical con rebote; cierre coseno hasta -600.
func _joey_vertical_offset() -> int:
	if _t <= 0:
		var angle := DuelVisualMath.trunc_div(_t + 256, 2) - 128
		return ((DuelVisualMath.cos_fx(angle) * 600) >> 16) - 600
	var v := 256 - _t
	if v < 128:
		return DuelVisualMath.trunc_div((v * 3 - 384) * 200, 128)
	return (DuelVisualMath.cos_fx(512 - 2 * _t) * -32) >> 16


## 488350: recorta dial_base a alto+36 y superpone dial_bott desde fondo-22.
func _draw_joey() -> void:
	modulate.a = 1
	var offset: float = _blend.at("joey", _joey_vertical_offset())
	var top := _top() + offset
	var base := _tex("dial_base")
	var bottom := _tex("dial_bott")
	if base:
		var height := mini(_height + 36, base.get_height())
		draw_texture_rect_region(base, Rect2(CENTER.x - base.get_width() / 2, top - 36, base.get_width(), height), Rect2(0, 0, base.get_width(), height))
	if bottom: draw_texture(bottom, Vector2(CENTER.x - bottom.get_width() / 2, top + _height - 22))
	if _t != 0 or offset != _joey_vertical_offset(): return
	var font := ThemeDB.fallback_font
	if _text != "": _draw_text(font, _text, Vector2(CENTER.x - _text_width / 2.0, top + 6), _text_width)
	for i in _items.size(): _draw_item(i, font)
	if _icons != null and _hover >= 0:
		var label: String = str(Assets.dialog_texts()[501 + _hover if type == 4 else 531 + _hover])
		_draw_text(font,label,Vector2(CENTER.x - _text_width / 2.0,CENTER.y + (40 if type == 4 else 24)),_text_width)
	if type == 8: _draw_cards()
	if type == 9: _draw_stars()


## 467c80: las tres piezas se componen alrededor del rectangulo interior.
func _draw_kaiba() -> void:
	modulate.a = 1.0
	# Con _t = 0 las dos escalas valen 256: la ventana abierta.
	var q := -absi(_t)
	var small := (DuelVisualMath.cos_fx(q + 128) >> 8) * 2 if q + 256 < 129 else 512 - (DuelVisualMath.cos_fx(q) >> 8)
	var large := 8 if q + 256 < 129 else DuelVisualMath.cos_fx(q) >> 8
	var zoom: Vector2 = _blend.at("kaiba", (Vector2(large, small) if _t > 0 else Vector2(small, large)) / 256.0)
	if _t != 0 or zoom != Vector2.ONE:
		draw_set_transform(Vector2(CENTER) * (Vector2.ONE - zoom), 0, zoom)
	var top := _top()
	var up := _tex("win_top")
	var mid := _tex("win_mid")
	var lang: String = Assets.lang if type == 1 and Assets.exists("%s/duel/dialog/win_bot_yes_%s.png" % [game, Assets.lang]) else "e"
	var bottom_name := "win_bot_yes_%s" % lang if type == 1 else "win_bot_ok_e" if type == 0 else "win_bot_non"
	var down := _tex(bottom_name)
	if up: draw_texture(up, Vector2(CENTER.x - up.get_width() / 2, top - up.get_height() + 8))
	if mid:
		var height := _height + 8
		draw_texture_rect_region(mid, Rect2(CENTER.x - mid.get_width() / 2, top - 8, mid.get_width(), height), Rect2(0, mid.get_height() - height, mid.get_width(), height))
	# 467c80 -> 4e51b0(0x60): conservar 6/15 del fondo interior (LUT de16 pesos).
	# Las piezas usan color clave; este sombreado no viene incluido en sus PNG.
	draw_rect(Rect2(CENTER.x - 169, top, 338, _height), Color(0, 0, 0, 1.0 - 6.0 / 15.0))
	if down: draw_texture(down, Vector2(CENTER.x - down.get_width() / 2, _bottom() - 25))
	if _t != 0 or zoom != Vector2.ONE: return
	var font := ThemeDB.fallback_font
	if _text != "": _draw_text(font, _text, Vector2(CENTER.x - _text_width / 2.0, top + 6), _text_width)
	for i in _items.size(): _draw_item(i, font)
	if type == 8: _draw_cards()
	if type == 9: _draw_stars()


func _draw_text(font: Font, text: String, at: Vector2, width: float) -> void:
	var base := at + Vector2(0, font.get_ascent(FONT_SIZE))
	var plain := DialogText.strip_marks(text)
	draw_multiline_string(font, base + Vector2(1, 1), plain, HORIZONTAL_ALIGNMENT_CENTER, width, FONT_SIZE, -1, Color(0, 0, 0, 0.8))
	if plain == text:
		draw_multiline_string(font, base, text, HORIZONTAL_ALIGNMENT_CENTER, width, FONT_SIZE, -1, Color(1, 1, 1))
		return
	# 5415c0: marcas @n como etiquetas de color. Mismo corte de lineas que el texto plano; cada
	# linea se centra y se dibuja por tramos de color.
	var colors: Array[Color] = []
	for run: Array in DialogText.runs(text, game):
		for c in String(run[0]).length():
			colors.append(run[1])
	var paragraph := TextParagraph.new()
	paragraph.add_string(plain, font, FONT_SIZE)
	paragraph.width = width
	for line in paragraph.get_line_count():
		var span := paragraph.get_line_range(line)
		var x := base.x + (width - font.get_string_size(plain.substr(span.x, span.y - span.x).strip_edges(false, true), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x) / 2.0
		var y := base.y + line * font.get_height(FONT_SIZE)
		var from := span.x
		while from < span.y:
			var to := from + 1
			while to < span.y and colors[to] == colors[from]:
				to += 1
			var piece := plain.substr(from, to - from)
			draw_string(font, Vector2(x, y), piece, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, colors[from])
			x += font.get_string_size(piece, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			from = to


func _draw_item(i: int, font: Font) -> void:
	var it := _items[i]
	var r: Rect2 = it["rect"]
	var state := 0
	if _hover == i:
		state = 2 if _pressed == i else 1
	if _feedback > 0 and _feedback_item == i: state = 2
	match String(it["kind"]):
		"icon":
			pass # La capa de iconos conserva la ampliacion discreta16->32.
		"button":
			var tex: Texture2D = it["tex"][state]
			if tex != null:
				draw_texture(tex, r.position)
			if game == "joey" and _feedback > 0 and _feedback_item == i:
				var frame := clampi(DuelVisualMath.trunc_div(224 - _feedback, 32), 0, 3) + 1
				var circle := _tex("y_n_cir%d" % frame)
				if circle: draw_texture(circle, r.get_center() - circle.get_size() / 2 + Vector2(-10, 0))
		"option":
			var tex: Texture2D = it["tex"][state]
			if game == "joey":
				var frame := _tex("3taku_waku2" if state == 2 else "3taku_waku")
				if frame: draw_texture(frame, r.get_center() - frame.get_size() / 2)
				if state != 0:
					var glow := _tex("3taku_on2" if state == 2 else "3taku_on")
					if glow: draw_texture(glow, r.get_center() - glow.get_size() / 2)
			elif game == "kaiba" and state != 0:
				_draw_kaiba_option(r, i)
			elif tex != null:
				draw_texture(tex, r.position)
			var label := String(it["label"])
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			var at := Vector2(r.position.x + (r.size.x - w) / 2.0, r.position.y + (r.size.y + font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) / 2.0)
			draw_string(font, at + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(0, 0, 0, 0.8))
			draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(1, 1, 1))
		"card":
			var tex := _card_tex(int(it["answer"]))
			if tex != null:
				_draw_card(self, tex, r, int(it["answer"]) == 1, Color(1, 1, 1))
		"coin":
			var tex: Texture2D = it["tex"][0]
			if tex != null:
				# FUN_004312f0: opaca la senalada, el resto con alfa 0x80.
				var a := 1.0 if _hover == i else 128.0 / 255.0
				draw_texture_rect_region(tex, r, Rect2(int(it["cell"]) * r.size.x, 0, r.size.x, r.size.y), Color(1, 1, 1, a))

## 4305d0: seis franjas verticales con recorrido de ida y vuelta; 12 planetas horizontales.
func _draw_kaiba_option(rect: Rect2, index: int) -> void:
	var tick: int = scene._visual.visual_tick if scene != null and scene.get("_visual") != null else _native_tick
	var counter := _feedback if _feedback_item == index and _feedback > 0 else 0
	var frame := (tick >> 2) % 11
	if frame >= 6: frame = 11 - frame
	var glow := _tex("3taku_on")
	var center := rect.get_center()
	if glow and ((counter / 32) & 2) == 0:
		var size := Vector2(glow.get_width(), glow.get_height() / 6)
		draw_texture_rect_region(glow, Rect2(center - size / 2, size), Rect2(0, frame * size.y, size.x, size.y))
	var planet := _tex("planet")
	if planet:
		var q := maxi(counter - 128, 0) if counter > 0 else 256
		var cell := Vector2(planet.get_width() / 12, planet.get_height())
		var scaled: Vector2 = _blend.at(["planet", index], Vector2(DuelVisualMath.trunc_div((DuelVisualMath.trunc_div(DuelVisualMath.cos_fx(q / 2), 64) + 256) * int(cell.x), 256), int(cell.y) * q / 256))
		for side in [-1, 1]:
			var x: float = center.x + side * (int(glow.get_width() / 2) + int(cell.y / 2) - 9) - int(scaled.x / 2)
			draw_texture_rect_region(planet, Rect2(x, center.y - int(scaled.y / 2), scaled.x, scaled.y), Rect2(((tick >> 1) % 12) * cell.x, 0, cell.x, cell.y))


func _card_tex(i: int) -> Texture2D:
	if i == 1 and bool(data.get("defense_face_down", false)):
		return Assets.texture("common/card/card_ura.png")
	return CardDB.card_texture(int(data.get("card", 0)))


## Carta en vertical (ataque) o tumbada (defensa, giro de 90 grados como en el tablero).
func _draw_card(canvas: CanvasItem, tex: Texture2D, r: Rect2, sideways: bool, color: Color) -> void:
	if sideways:
		canvas.draw_set_transform(r.get_center(), PI / 2, Vector2.ONE)
		canvas.draw_texture_rect(tex, Rect2(-Vector2(r.size.y, r.size.x) / 2, Vector2(r.size.y, r.size.x)), false, color)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		canvas.draw_texture_rect(tex, r, false, color)


## La carta senalada se repite en aditivo con alfa 0x40 (como la lista de seleccion).
func _draw_add() -> void:
	if _t != 0: return
	if type == 6 and _hover >= 0:
		var tex := _card_tex(_hover)
		if tex != null:
			_draw_card(_add_layer, tex, _items[_hover]["rect"], _hover == 1, Color(1, 1, 1, 64.0 / 255.0))


## 0x431470: icono de carta de 25x36 por cada carta pedida (0xa16101), desde x = centro - 167
## cada 36 px (menos si no caben en el ancho - 100); y = borde inferior - 43.
func _draw_cards() -> void:
	var count: int = duel.f578bd0()
	var tex := Assets.texture("common/mini/card_ura.png")
	if tex == null or count <= 0:
		return
	var step := 36
	var width := 330 if game == "kaiba" else WIDTH
	if width - 100 < count * step:
		step = (width - 100) / count
	for i in count:
		draw_texture_rect(tex, Rect2(CENTER.x - width / 2 + 50 - 12 + i * step, _bottom() - 43, 25, 36), false)


## 0x431590: una estrella por nivel; las ultimas FUN_0056aef0 (byte 0xa15fe1) con level2.
func _draw_stars() -> void:
	var level := int(data.get("level", 0))
	var rest := duel.m.u8(0xa15fe1)
	var star := _tex("level")
	var star2 := _tex("level2")
	if star == null or level <= 0:
		return
	var w := int(star.get_size().x)
	var step := w + 2
	var x0 := CENTER.x - (level * step - 2) / 2
	for i in level:
		var tex := star2 if level - rest <= i and star2 != null else star
		draw_texture(tex, Vector2(x0 + i * step, _bottom() - 35))


func _draw_icons() -> void:
	if _t != 0: return
	var offset: float = _blend.at("joey", _joey_vertical_offset())
	if offset != _joey_vertical_offset(): return
	for i in _items.size():
		var it: Dictionary = _items[i]
		_icon_layer.draw_texture_rect_region(it.atlas, it.rect, it.src, Color(1,1,1,float(_icons.alpha(i,_hover))/256.0))
