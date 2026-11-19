extends Node2D
## Opciones Yugi/Kaiba (title/option.txt): estados 5/6 de 467000 y 4694b0.
## Kaiba: init 468000, seleccion 4683f0, teclado 468640, dibujo 468e80.
## Joey: init48bc20, seleccion488bc0, teclado488f50, dibujo489d50; estado8 de48a150.
## - 0x4669d0: placa (0), modo actual (1 ventana; 2 completa y 3 con el tercio de los bits) y,
##   bajo el puntero, el marco del elemento (4..9).
## - 0x466300: elemento bajo el puntero: 2 ventana, 3 completa, 4/5/6 = 16/24/32 bits,
##   7 volver; 0/1 = izquierda/derecha del deslizador.
## - Deslizador de volumen (objeto +0x154, clase de 0x42dea0; init 0x465f10): 0..15 desde
##   x = item 10, recorrido = item11.x - item10.x - int(_piece_size().x), pieza op_sound (item 12: 21x15).
## - Aceptar (tecla 6 o clic): decide.wav y la accion (tabla 0x467eac); Cancelar o clic
##   derecho: return.wav y salir. Al salir se guardan volumen (DAT_00a10124) y modo
##   (DAT_00a10128 = DAT_005aa178).
## La profundidad de color no tiene efecto en el remake: se guarda y se muestra como la eligio.

signal exit_requested

const MUSIC := {"yugi": "menu.wav", "kaiba": "m_title.wav", "joey": "m_menu.wav"}

var game := "yugi"
var _dir := "yugi/title/"

var alpha := 1.0          # estado 5: 0x4669d0 con alfa
var draw_alpha := 1.0     # el de arriba mezclado entre ticks por el titulo
var selected := -1        # +0x20
var volume := 15          # +0x54 del deslizador
var card_set_full := false
var limited := false
var bits := 0             # DAT_005aa178: 0 ventana, 16/24/32 completa
var _layout: Layout
var _tex: Array[Texture2D] = []
var _dragging := false
var _mouse := Vector2(-1, -1)


func _init(game_id := "yugi") -> void:
	game = game_id
	_dir = game + "/title/"


func _ready() -> void:
	_layout = Assets.layout(_dir + "option.txt")
	for i in _layout.items.size():
		_tex.append(Assets.texture(_dir + _layout.resource(i)))
	var saved: Dictionary = SaveData.data.get("options", {}).get(game, {})
	volume = clampi(int(saved.get("volume", 15)), 0, 15)
	bits = int(saved.get("display", 0))
	if game == "joey":
		card_set_full = bool(saved.get("card_set_full", Game.has_previous_cards("joey")))
		limited = bool(saved.get("limited", false))


func _pos(i: int) -> Vector2:
	var v := str(_layout.value(i)).to_int()
	return Vector2(v / 1000, v % 1000)


## 465f10/468000/48bc20: item12 = ancho de botón y ancho de pieza.
## Atlas Y/K57x42 (filas21); Joey67x23 (una fila).
func _piece_size() -> Vector2:
	return Vector2(_pos(12).y, _tex[12].get_height() if game == "joey" else _pos(12).x)


func _travel() -> int:
	return int(_pos(11).x - _pos(10).x - _pos(12).x - _piece_size().x)


func _thumb_x() -> int:
	return int(_pos(10).x + _pos(12).x) + (7 + _travel() * volume) / 15


## 0x466300: elemento bajo el puntero.
func _hit(p: Vector2) -> int:
	var thumb := Rect2(Vector2(_thumb_x(), _pos(10).y), _piece_size())
	var bar := Rect2(_pos(10), Vector2(_pos(11).x - _pos(10).x + _pos(12).x, _piece_size().y))
	if bar.has_point(p) and not thumb.has_point(p):
		return 0 if p.x < thumb.position.x else 1
	for k in (8 if game == "joey" else 6):
		var item := k + (1 if game == "joey" else 4)
		if game == "joey" and k == 5 and not Game.has_previous_cards("joey"):
			continue # 488bc0: FULL no responde sin cartas previas propias.
		if Rect2(_pos(item), _tex[item].get_size()).has_point(p):
			return k + 2
	return -1


func handle_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse = get_global_transform_with_canvas().affine_inverse() * event.position
	if preload("res://core/touch_input.gd").outside(event, Rect2(_pos(0), _tex[0].get_size()).has_point(_mouse)):
		_dragging = false
		Audio.play_sfx("%s/voice/internal/return.wav" % game)
		exit_requested.emit()
		return
	var thumb := Rect2(Vector2(_thumb_x(), _pos(10).y), _piece_size())
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and thumb.has_point(_mouse):
			_dragging = true
			return
		if not event.pressed:
			_dragging = false
	if event is InputEventMouseMotion:
		if _dragging:
			var v := roundi(float(_mouse.x - _piece_size().x / 2.0 - _pos(10).x - _pos(12).x) * 15 / _travel())
			_set_volume(clampi(v, 0, 15))
		selected = _hit(PointerGlide.hover(_mouse))
	elif event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_RIGHT):
		Audio.play_sfx("%s/voice/internal/return.wav" % game)   # 0x10000002
		exit_requested.emit()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_navigate(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_navigate(1)
	elif event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		if event is InputEventMouseButton:
			selected = _hit(_mouse)
		if selected < 0:
			_warp(last_index())
			return
		if selected >= 0:
			Audio.play_sfx("%s/voice/internal/decide.wav" % game)   # 0x10000001
		match selected:
			0: _set_volume(volume - int(volume > 0))       # 0x42d6e0
			1: _set_volume(volume + int(volume < 15))      # 0x42d6c0
			2: _set_display(0)                             # 0x409930(0)
			3, 4: _set_display(16)
			5: _set_display(24)
			6: _set_display(32)
			7:
				if game == "joey":
					card_set_full = true
				else:
					exit_requested.emit()
			8: card_set_full = false
			9: limited = not limited
		if game == "joey": _store()
	queue_redraw()


## Estado 6 de 0x467000, cada tick: 0x466300 elige el elemento bajo el puntero o bajo el
## destino del deslizamiento.
func last_index() -> int:
	return 9 if game == "joey" else 7


func _navigate(step: int) -> void:
	var index := clampi(selected + step, 0, last_index()) if selected >= 0 else last_index()
	if game == "joey" and index == 7 and not Game.has_previous_cards("joey"):
		index += step
	_warp(index)


func tick() -> void:
	if not _dragging:
		selected = _hit(PointerGlide.hover(_mouse))
	queue_redraw()


## 0x4663f0 (estado 6) -> 0x4600f0: el puntero a la mitad del elemento (0/1: extremos del
## deslizador), solo si se esta usando el teclado.
func _warp(index: int) -> void:
	var target: Vector2
	if index > 1:
		var item := index - 1 if game == "joey" else index + 2
		target = _pos(item) + _tex[item].get_size() / 2
	else:
		target = _pos(10 + index) + _pos(12) / 2
	PointerGlide.request(_mouse, target)


func _set_volume(v: int) -> void:
	var was := volume
	volume = clampi(v, 0, 15)
	if volume != was:
		Audio.set_option_volume(volume)
		if was == 0:
			Audio.play_music("%s/voice/stream/%s" % [game, MUSIC[game]])   # vuelve el sonido: 0x20000002


func _set_display(b: int) -> void:
	bits = b
	if b == 0:
		LauncherSettings.set_display_mode(get_tree().root, Window.MODE_MAXIMIZED)
	else:
		LauncherSettings.set_display_mode(get_tree().root, Window.MODE_EXCLUSIVE_FULLSCREEN)


func _store() -> void:
	var options: Dictionary = SaveData.data.get("options", {})
	# Los tres ejecutables guardan volumen/modo en +6/+8 de la misma ranura Common.
	for id in ["yugi", "kaiba", "joey"]:
		var common: Dictionary = options.get(id, {})
		common.merge({"volume": volume, "display": bits}, true)
		options[id] = common
	var saved: Dictionary = options.get(game, {})
	if game == "joey":
		saved.merge({"card_set_full": card_set_full, "limited": limited}, true)
	options[game] = saved
	SaveData.data["options"] = options


func save() -> void:
	_store()
	if game == "joey":
		SaveData.set_native_option_byte(0x10f4, int(card_set_full))
		SaveData.set_native_option_byte(0x10ee, int(limited))
	SaveData.save()


func _draw() -> void:
	if alpha <= 0.0:
		return
	var tint := Color(1, 1, 1, draw_alpha if alpha < 1.0 else alpha)
	draw_texture(_tex[0], _pos(0), tint)
	if alpha < 1.0:
		return
	if game == "joey":
		_draw_joey_controls()
	elif bits == 0:
		draw_texture(_tex[1], _pos(1))
	else:
		draw_texture(_tex[2], _pos(2))
		var w := _tex[3].get_width()
		var x := (bits / 8 - 2) * w / 3
		draw_texture_rect_region(_tex[3], Rect2(_pos(3) + Vector2(x, 0), Vector2(w / 3, _tex[3].get_height())),
				Rect2(x, 0, w / 3, _tex[3].get_height()))
	if game != "joey" and selected > 1:
		draw_texture(_tex[selected + 2], _pos(selected + 2))
	# 42dea0: dos columnas de flechas y una pieza; Y/K segunda fila señalada.
	var size := _piece_size()
	var button := _pos(12).x
	var hover := Rect2(Vector2(_thumb_x(), _pos(10).y), size).has_point(_mouse) or _dragging
	var row := button if game != "joey" and hover else 0.0
	draw_texture_rect_region(_tex[12], Rect2(Vector2(_thumb_x(), _pos(10).y), size),
			Rect2(Vector2(button * 2, row), size))
	if selected in [0, 1]:
		var arrow_size := Vector2(button, size.y)
		draw_texture_rect_region(_tex[12], Rect2(_pos(10 + selected), arrow_size),
				Rect2(Vector2(button * selected, button if game != "joey" else 0.0), arrow_size))



## 489d50: imagen separada de bits, selector de cardset y LIMITED; hover con alfa128.
func _draw_joey_controls() -> void:
	if bits == 0:
		draw_texture(_tex[1], _pos(1))
	else:
		draw_texture(_tex[2], _pos(2))
		var item := bits / 8 + 1
		draw_texture(_tex[item], _pos(item))
	var set_item := 6 if card_set_full else 7
	draw_texture(_tex[set_item], _pos(set_item))
	if limited: draw_texture(_tex[8], _pos(8))
	if selected > 1:
		var item := selected - 1
		draw_texture(_tex[item], _pos(item), Color(1, 1, 1, 0.5))
