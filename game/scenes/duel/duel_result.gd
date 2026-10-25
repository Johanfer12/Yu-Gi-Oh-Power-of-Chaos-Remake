class_name DuelResult
extends Node2D
## Escena de resultado tras el duelo (indice 4, 0x4633f0; maquina de estados 0x435410). Se
## dibuja sobre el campo congelado y oscurecido por el sombreado (0x464490). Detalle en
## docs/duel/POST_DUELO.md.
## - Estado 1 (0x433e50): victorias/derrotas/empates y racha del juego en el guardado.
## - Estado 6, solo si gana: cartel de resultado que se encoge (0x463160/0x463210) y YOU GET
##   (0x434cc0 elige la carta, 0x433cb0/0x433260/0x433520 la animacion); al acabar, clic o
##   decidir.
## - Estado 5, solo en match: el cartel se encoge a la vez que sale el tablero (0x434810,
##   match_board.gd); se sigue cuando no queda nada activo (0x432c00).
## - Estado 6: YOU GET solo con el resultado global DAT_005af764 == 1 (en match, 3 cartas).
## - Estado 7: fundido (0x532390) y cambio de escena.

signal finished

const CARD_W := 200
const CARD_H := 290
const CARD_Y := 400
const TITLE_Y := 175
const RewardInput = preload("res://core/duel_input.gd")

var game := "yugi"
var result := 0
var _state := 0
var _banner := 0
var _t := 0
var _cards: Array = []  # [{id, new}]
var _sparks: Array = []
var _fade := 0
var _clock := 0.0
## Contadores de cartel, rotulo, cartas, chispas y fundido mezclados entre ticks.
var _blend := NativeBlend.new()
var _clicked := false
var _lang := "s"
var _names: Array[Label] = []
var _match := false
var _outcome := 0
var _owns_banner := true
var _board: Node2D = null
static var _mask_shaders := {}
var _joey_reward_ready := false
var _joey_retry := false
var _joey_wait := 0
var _joey_counter := 0
var _joey_saved := false
var _joey_keys := 0
var _joey_pressed := false
var _joey_released := false
var _joey_left_down := false
var _joey_previous_down := false
var _joey_pointer := Vector2.ZERO
## Joey a54e5c & 0x40 (comando 0x28, 408410): rendición; 446df0 no cuenta el resultado.
var _surrendered := false


## `winner`: 1 gana el jugador, 2 la CPU, 3 empate (0x53d650).
func setup(game_id: String, winner: int, duel_flags: int = 0, surrendered := false) -> void:
	game = game_id
	result = winner
	_surrendered = surrendered
	z_index = 70
	_lang = Assets.lang if Assets.exists("%s/duel/get/you_get_%s1.png" % [game, Assets.lang]) else "e"
	_record()
	_state = 2
	_match = Game.duel_mode == 1
	_owns_banner = winner == 1 or _match
	_outcome = Game.match_outcome if Game.duel_mode in [0, 1, 3] else winner
	if _outcome == 1 and game != "joey":
		_cards = _choose_cards(3 if _match else 1)   # 0x434ba0 en match
		_save_cards()
	# 435410 estado1, DAT_a114b4 bit8. Joey 447000 estado1: tras rendirse (a54e5c & 0x40)
	# tampoco pregunta por la repetición.
	if (duel_flags & 0x100) != 0 or (_surrendered and game == "joey"): _after_replay()


## 0x433e50: estadisticas comunes y racha (DAT_00a11218, DAT_00a11215/16).
func _record() -> void:
	if _surrendered and game == "joey":
		# 446df0 con a54e5c & 0x40: sin victorias/derrotas, racha ni nivel; una victoria previa
		# deja la racha a 0.
		SaveData.ensure_game(game)
		var surrendered_stats: Dictionary = SaveData.data["stats"][game]
		if int(surrendered_stats.get("streak_last", 0)) == 1: surrendered_stats["streak"] = 0
		return
	var stats: Dictionary = SaveData.record_result(game, result)
	var last_win := int(stats.get("streak_last", 0)) == 1
	if last_win == (result == 1):
		stats["streak"] = mini(0xff, int(stats.get("streak", 0)) + 1)
	else:
		stats["streak"] = 1
	stats["streak_last"] = 1 if result == 1 else 2
	if game == "joey":
		var adjusted := RivalDeckChoice.joey_after_result(int(stats.get("level", 1)),
			Game.joey_full_cards(), int(stats["streak_last"]), int(stats["streak"]), Game.match_outcome != 0)
		stats["level"] = adjusted.x
		stats["streak"] = adjusted.y
	SaveData.data["stats"][game] = stats
	if game in ["yugi", "kaiba"]:
		var other := "kaiba" if game == "yugi" else "yugi"
		SaveData.data["stats"][other]["streak"] = stats["streak"]
		SaveData.data["stats"][other]["streak_last"] = stats["streak_last"]


## 0x434cc0: n cartas al azar entre las que se ganan en este juego (CARD_Pack.bin, orden de
## indice); 1-3 tiradas segun el % de coleccion (>= 80 %, >= 90 %) hasta que salga una nueva.
func _choose_cards(n: int) -> Array:
	var pool := CardDB.obtainable_in(game)
	pool.sort_custom(func(a, b): return int(a["index"]) < int(b["index"]))
	var owned := 0
	for card in pool:
		if SaveData.card_count(int(card["internal_id"])) > 0:
			owned += 1
	var pct := owned * 100 / maxi(1, pool.size())
	var tries := 1 + int(pct > 79) + int(pct > 89)
	var pick: Array = []
	for attempt in tries:
		pick = []
		var any_new := false
		while pick.size() < n:
			var id := int(pool[UiRandom.draw_mod(pool.size())]["internal_id"])   # 0x434d5d
			if pick.any(func(c): return c["id"] == id):
				continue
			var fresh := SaveData.card_count(id) == 0
			any_new = any_new or fresh
			pick.append({"id": id, "new": fresh})
		if any_new:
			break
	return pick


func _save_cards() -> void:
	for c in _cards:
		if SaveData.card_count(c["id"]) < 255:
			SaveData.add_card(c["id"])
	SaveData.save()


func _input(event: InputEvent) -> void:
	if game == "joey" and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_joey_left_down = event.pressed
	if _state == 5 and _board != null:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) 				or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]):
			_board.click()
			get_viewport().set_input_as_handled()
		return
	if _state != 6:
		return  # el cuadro de repeticion recibe su propia entrada
	if game == "joey":
		if event is InputEventMouse:
			_joey_pointer = get_global_transform_with_canvas().affine_inverse() * event.position
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo:
			_joey_keys |= RewardInput.slots(event, game)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_clicked = true
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_clicked = true
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_clock += NativeClock.ticks(delta)
	while _clock >= 1.0:
		_clock -= 1.0
		_blend.tick()
		_step()
	_blend.fraction = _clock
	if _board != null: _board.show_between(_clock)
	_build_sprites()
	queue_redraw()


## 0x435410 estado 2: 0x456660(1, 400, 428) = deck_c/replay_quest.txt (w_replay_q con
## q_y/q_n). +0x2b4 == 0 (Si) -> estado 3 (guardar la repeticion), si no -> 5.
func _ask_replay() -> void:
	var dir := "%s/deck_c/" % game
	var bg := Assets.texture(dir + Assets.layout(dir + "replay_quest.txt").resource(0))
	if bg == null:
		_after_replay()
		return
	var d := PocDialog.new(bg, (Vector2(400, 428) - bg.get_size() / 2).floor())
	for pair in [["yes", "dlg_replayq_yes"], ["no", "dlg_replayq_no"]]:
		var l := Assets.layout(dir + pair[1] + ".txt")
		d.add_button(pair[0], Vector2(l.position(0)), Assets.texture(dir + l.resource(0)), Assets.texture(dir + l.resource(1)))
	d.cancel_id = "no"
	d.closed.connect(func(id: String) -> void:
		d.queue_free()
		if id == "yes":
			_save_replay()
		else:
			_after_replay())
	add_child(d)


## Carpeta de repeticiones guardadas (el original usa CommonDir; aqui, junto a la partida).
static func replays_dir(game_id: String) -> String:
	return Paths.save_dir.path_join("replays").path_join(game_id)


static func replay_files(game_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := replays_dir(game_id)
	if DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			if f.get_extension().to_lower() == "ydr":
				out.append(f.get_basename())
	out.sort()
	return out


## Estado 3: lista de guardado 0x4587d0(4). Al cerrarla se pasa a 5; con Aceptar se escribe
## (0x4370b0 -> 0x436f60) y, si falla, el estado 4 avisa (0x459550) y vuelve a la lista.
## Si el nombre ya existe se confirma con el modo 2 del mismo cuadro (deck_c/overwrite.txt).
func _save_replay() -> void:
	var d: PocDialog = load("res://scenes/deck_editor/deck_file_dialog.gd").for_replay(game, 4, replay_files(game))
	d.closed.connect(func(id: String) -> void:
		if id == "ok":
			_write_replay(d.chosen_name)
		else:
			Audio.play_sfx("%s/voice/internal/return.wav" % game)
			_after_replay())
	Audio.play_sfx("%s/voice/internal/decide.wav" % game)
	add_child(d)


func _write_replay(name: String, confirmed := false) -> void:
	var path := replays_dir(game).path_join(name + ".ydr")
	if FileAccess.file_exists(path) and not confirmed:
		var dir := "%s/deck_c/" % game
		var d := PocDialog.new(Assets.texture(dir + Assets.layout(dir + "overwrite.txt").resource(0)))
		for pair in [["ok", "dlg_ow_ok"], ["cancel", "dlg_ow_cancel"]]:
			var l := Assets.layout(dir + pair[1] + ".txt")
			d.add_button(pair[0], Vector2(l.position(0)), Assets.texture(dir + l.resource(0)), Assets.texture(dir + l.resource(1)))
		d.closed.connect(func(id: String) -> void:
			if id == "ok":
				_write_replay(name, true)
			else:
				_save_replay())
		add_child(d)
		return
	var duel := get_parent()
	if duel != null and duel.has_method("make_replay") and duel.make_replay().save(path):
		_after_replay()
	else:
		Audio.play_sfx("%s/voice/internal/unable.wav" % game)
		_replay_save_error()

## ASM4356d7..435703: centro400,300; texto102c y clase459550 (warning/dlg_text_ok).
func _replay_save_error() -> void:
	_state = 41
	var dir := "%s/deck_c/" % game
	var layout := Assets.layout(dir + "warning.txt")
	var dialog := PocDialog.new(Assets.texture(dir + layout.resource(0)))
	var button := Assets.layout(dir + "dlg_text_ok.txt")
	dialog.add_button("ok", Vector2(button.position(0)), Assets.texture(dir + button.resource(0)), Assets.texture(dir + button.resource(1)))
	var texts: Variant = Assets.dialog_texts()
	dialog.lines = PackedStringArray([String(texts[0x102c])])
	dialog.text_rect = Rect2(54, 44, 223, 102) # 454b60: ancho df, area visible66.
	dialog.closed.connect(func(_id: String) -> void: _save_replay())
	add_child(dialog)


## Estado 5: en match, tablero y cartel; sin match pasa a 6 si gana el jugador, si no a 7.
func _after_replay() -> void:
	if _match:
		_state = 5
		_board = preload("res://scenes/duel/match_board.gd").new()
		_board.setup(game, Game.match_results, Game.match_duel, _outcome)
		add_child(_board)
		return
	_state = 6 if _offers_cards() else 7


## Joey 447000 estado 6: sin oferta de cartas en red (44b980, modo 3) ni tras rendirse
## (a54e5c & 0x40), aunque gane el jugador.
func _offers_cards() -> bool:
	return _outcome == 1 and not (game == "joey" and (Game.duel_mode == 3 or _surrendered))


func _step() -> void:
	if game == "joey": _joey_sample_input()
	match _state:
		2:
			_state = 21
			_ask_replay()
		5:
			if _banner < 0x100:
				_banner += 0x10
			if _board != null:
				_board.step()
				if not _board.active and _banner >= 0x100:
					_board.queue_free()
					_board = null
					_state = 6 if _offers_cards() else 7
		6:
			if _banner < 0x100:
				# 0x463210: +0x10 por paso; el cartel se dibuja a escala 0x100 - contador.
				_banner += 0x10
			else:
				if game == "joey":
					_joey_reward_step()
					return
				if _t == 0:
					_build_names()
				_t += 8
				if game == "joey":
					# 0x445a10: el premio común retiene T en (n+4)*256 hasta decidir.
					_t = mini(_t, (_cards.size() + 4) * 0x100)
				if _t == 8:
					Audio.play_music("%s/voice/stream/%s.wav" % [game, "j_get" if game == "yugi" else "m_get"], false)
				for s in _sparks:
					s["f"] += 0x10
				_sparks = _sparks.filter(func(s): return s["f"] < 0x100)
				_spawn_sparks()
				if _t >= (_cards.size() + 4) * 0x100 and _clicked:
					_state = 7
		7:
			for label in _names:
				label.visible = false
			_fade += 0x10
			if _fade >= 0x100:
				_state = 8
				finished.emit()
	_clicked = false
	_joey_keys = 0

func _joey_sample_input() -> void:
	_joey_pressed = _joey_left_down and not _joey_previous_down
	_joey_released = not _joey_left_down and _joey_previous_down
	_joey_previous_down = _joey_left_down

## Jo444eb0/445640: una oferta completa; el MT extra depende del estado persistente.
func _joey_choose_reward() -> void:
	_cards = _choose_cards(3 if _match else 1)
	_joey_counter = SaveData.native_option_byte(0x10ed)
	if _joey_retry:
		_joey_counter = 0
		_joey_retry = false
	else:
		var r := UiRandom.draw()
		_joey_counter += (r & 7) + 3 if _match else r % 10 + 1
		if _joey_counter >= 20:
			if _cards.any(func(c): return c["new"]): _joey_counter = 17
			else:
				_joey_counter = 0
				_joey_retry = true
	for label in _names: label.free()
	_names.clear()
	_sparks.clear()
	_build_names()
	_t = 0 #4453d0 reconstruye el premio; 445a4a apaga retry después de repetir.
	_joey_reward_ready = true

func _joey_dialog_factor() -> int:
	return mini(256, _joey_wait * 4) if _joey_wait > 0 else clampi((_t - (_cards.size() + 4) * 256) * 4, 0, 256)

func _joey_button_rect(index: int) -> Rect2:
	var texture := _tex("retry_%s1_%s" % ["y" if index == 0 else "n", _lang])
	var y := 600 - (600 - 450) * _joey_dialog_factor() / 256
	return Rect2(Vector2(176 + (116 if index == 0 else 234), y + 80), texture.get_size() if texture != null else Vector2.ZERO)

func _joey_focus(index: int) -> void:
	_joey_pointer = _joey_button_rect(index).get_center().floor()
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		get_viewport().warp_mouse(get_global_transform_with_canvas() * _joey_pointer)

func _joey_accept() -> void:
	if not _joey_saved:
		SaveData.set_native_option_byte(0x10ed, _joey_counter)
		_save_cards()
		_joey_saved = true
	_state = 7

func _joey_reward_step() -> void:
	if not _joey_reward_ready:
		if _cards.is_empty(): _joey_choose_reward()
		else:
			_joey_reward_ready = true # fixtures con oferta explícita.
			_build_names()
	var limit := (_cards.size() + 4) * 256
	if _joey_wait > 0:
		_joey_wait -= 8
		if _joey_wait == 0:
			_joey_choose_reward()
			_joey_retry = false
	elif _t != limit:
		_t += 8
	if _t == 8: Audio.play_music("joey/voice/stream/m_get.wav", false)
	for s in _sparks: s["f"] += 16
	_sparks = _sparks.filter(func(s): return s["f"] < 256)
	_spawn_sparks()
	_joey_decide(limit)
	_joey_keys = 0
	_joey_pressed = false
	_joey_released = false
	_clicked = false

## Jo446a59..446dd4: soltar al límite; pulsar/Enter en los botones de repetir.
func _joey_decide(limit: int) -> void:
	if _t == limit and (_joey_released or _joey_keys & (1 << 6)):
		if not _joey_retry:
			_joey_accept()
			return
		Audio.play_sfx("joey/voice/internal/decide.wav")
		_t += 8
	if not _joey_retry or _t <= limit: return
	if _joey_wait == 0 and _t == limit + 64: _joey_focus(0)
	if _joey_dialog_factor() != 256: return
	var choice := -1
	if _joey_pressed or _joey_keys & (1 << 6):
		for index in 2:
			if _joey_button_rect(index).has_point(_joey_pointer): choice = index
	if _joey_keys & (1 << 3): _joey_focus(0)
	elif _joey_keys & (1 << 4): _joey_focus(1)
	if _joey_keys & (1 << 20): choice = 1
	if choice == 0:
		_joey_wait = 64
		Audio.fade_native(8)
	elif choice == 1: _joey_accept()


func _card_x(k: int) -> int:
	return 400 if _cards.size() == 1 else [160, 400, 640][k]


func _build_names() -> void:
	for k in _cards.size():
		var label := Label.new()
		label.text = CardDB.name_of(_cards[k]["id"])
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(0x10a, 18)
		label.position = Vector2(_card_x(k) - 0x10a / 2, CARD_Y - CARD_H / 2 - 0x10 - 9)
		label.visible = false
		add_child(label)
		_names.append(label)


## 0x433b4a: con 0x280 <= tC < 0x300, una chispa cada 0x10 de T en un punto de la carta nueva.
func _spawn_sparks() -> void:
	for k in _cards.size():
		if not _cards[k]["new"]:
			continue
		var tc := _t - 0x100 * k
		if tc >= 0x280 and tc < 0x300 and (tc - 0x280) % 16 == 0:
			# 0x433b63 (x) y 0x433b8e (y), en ese orden.
			var x := _card_x(k) + UiRandom.draw_mod(CARD_W) - CARD_W / 2
			_sparks.append({"pos": Vector2(x, CARD_Y + UiRandom.draw_mod(CARD_H) - CARD_H / 2), "f": 0})


func _tex(name: String) -> Texture2D:
	var path := "%s/duel/get/%s.png" % [game, name]
	return Assets.texture(path) if Assets.exists(path) else null


func _banner_visible() -> bool:
	return _owns_banner and _banner < 0x100 and _state in [2, 21, 3, 4, 5, 6]


func _draw() -> void:
	# El cartel transferido desde el duelo sigue visible durante la pregunta
	# de repeticion; despues se encoge desde esa misma imagen sin reaparecer.
	if _banner_visible():
		_draw_banner()
	if _state == 6:
		if _banner >= 0x100 and _t > 0:
			_draw_title()
			for k in _cards.size():
				_draw_card(k)
			for s in _sparks:
				_draw_spark(s)
			if game == "joey" and _joey_retry and _t > (_cards.size() + 4) * 256:
				_draw_joey_retry()
	if _fade > 0:
		draw_rect(Rect2(0, 0, 800, 600), Color(0, 0, 0, minf(1.0, _blend.at("fade", _fade) / 256.0)))

func _draw_joey_retry() -> void:
	var factor := _joey_dialog_factor()
	var bg := _tex("retry_w_%s" % _lang)
	if bg != null: draw_texture(bg, Vector2(176, 600 - 150 * factor / 256))
	for index in 2:
		var rect := _joey_button_rect(index)
		var pressed := rect.has_point(_joey_pointer) and PlatformInput.mouse_pressed(MOUSE_BUTTON_LEFT)
		var texture := _tex("retry_%s%d_%s" % ["y" if index == 0 else "n", 2 if pressed else 1, _lang])
		if texture != null: draw_texture(texture, rect.position)


## 0x463210: duel_win/lose/draw centrado en (400, 300) a escala 0x100 - contador.
func _draw_banner() -> void:
	var name: String = ["duel_win_%s", "duel_lose_%s", "duel_draw_%s"][clampi(result - 1, 0, 2)]
	var path := "%s/duel/effect/%s.png" % [game, name % _lang]
	if not Assets.exists(path):
		path = "%s/duel/effect/%s.png" % [game, name % "e"]
	var tex := Assets.texture(path)
	if tex == null:
		return
	var s: float = _blend.at("banner", float(0x100 - _banner) / 256.0)
	var size := tex.get_size() * s
	draw_texture_rect(tex, Rect2(Vector2(400, 300) - size / 2, size), false)


func _masked(src: Texture2D, mask: Texture2D, size: Vector2, shift: float, repeat: bool, additive: bool) -> ShaderMaterial:
	var key := 1 if additive else 0
	if not _mask_shaders.has(key):
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;
" + ("render_mode blend_add;
" if additive else "") + """
uniform sampler2D src : repeat_enable;
uniform sampler2D mask_tex;
uniform vec2 dst_size;
uniform vec2 src_size;
uniform float shift;
uniform bool wrap;
void fragment() {
	vec2 p = UV * dst_size - vec2(shift, 0.0);
	vec4 c = vec4(0.0);
	if (wrap || (p.x >= 0.0 && p.x < src_size.x && p.y >= 0.0 && p.y < src_size.y))
		c = texture(src, p / src_size);
	c.a *= texture(mask_tex, UV).b * COLOR.a;
	COLOR = c;
}"""
		_mask_shaders[key] = sh
	var mat := ShaderMaterial.new()
	mat.shader = _mask_shaders[key]
	mat.set_shader_parameter("src", src)
	mat.set_shader_parameter("mask_tex", mask)
	mat.set_shader_parameter("dst_size", size)
	mat.set_shader_parameter("src_size", src.get_size())
	mat.set_shader_parameter("shift", shift)
	mat.set_shader_parameter("wrap", repeat)
	return mat


## Capas con mascara (vtable+0x94): brillo del rotulo (aditivo, +0xa0) y arcoiris de NEW.
func _build_sprites() -> void:
	for c in get_children():
		if c is Sprite2D:
			c.free()
	if _state != 6 or _banner < 0x100 or _t <= 0:
		return
	var stem := "you_get_%s" % _lang if _cards.size() == 1 else "you_gets_%s" % _lang
	var normal := _tex(stem + "2")
	var mask := _tex(stem + "_mask")
	var ref := _tex("you_get_ref1")
	if normal != null and mask != null and ref != null and _t >= 0x100 and _t < 0x200:
		var size := normal.get_size()
		var shift: float = _blend.at("shine", ((ref.get_width() + size.x) * (_t - 0x100) / 256) - ref.get_width())
		_sprite(normal, Rect2(Vector2(400, TITLE_Y) - size / 2, size), 1.0, _masked(ref, mask, size, shift, false, true))
	# 0x4337a8: reflejo ref2 sobre la carta, aditivo (+0xa0) y recortado a la carta.
	var ref2 := _tex("you_get_ref2")
	for k in _cards.size():
		var tb := _t - 0x100 * k
		if ref2 == null or tb <= 0x200 or tb > 0x300:
			continue
		var x: float = _blend.at(["ref2", k], ((ref2.get_width() + CARD_W) * (tb - 0x200) / 256) - ref2.get_width())
		var left := maxf(0, x)
		var src_x := maxf(0, -x)
		var w := minf(ref2.get_width() - src_x, CARD_W - left)
		if w <= 0:
			continue
		var s := Sprite2D.new()
		s.texture = ref2
		s.centered = false
		s.region_enabled = true
		s.region_rect = Rect2(src_x, 0, w, mini(CARD_H, ref2.get_height()))
		s.position = Vector2(_card_x(k) - CARD_W / 2 + left, CARD_Y - CARD_H / 2)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = add
		add_child(s)
	for k in _cards.size():
		var tc := _t - 0x100 * k
		if not _cards[k]["new"] or tc <= 0x300 or tc > 0x500:
			continue
		var label := _tex("card_new_%s" % _lang)
		var nmask := _tex("card_new_%s_mask" % _lang)
		var rain := _tex("card_new_rain")
		if label == null or nmask == null or rain == null:
			continue
		var u := tc & 0xff
		# El arcoiris se repite: se mezcla el desplazamiento sin envolver, para que al volver a
		# empezar no recorra todo su ancho en un tick.
		var shift2: float = _blend.at(["rain", k], -(((0x100 - u) * rain.get_width()) >> 8) + (tc >> 8) * rain.get_width())
		_sprite(label, _blend.at(["new", k], _new_rect(k, tc, label)), _blend.at(["new_alpha", k], _new_alpha(tc)) / 255.0, _masked(rain, nmask, label.get_size(), shift2, true, false))


func _sprite(tex: Texture2D, rect: Rect2, alpha: float, mat: Material) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = rect.position
	s.scale = rect.size / tex.get_size()
	s.modulate.a = alpha
	s.material = mat
	add_child(s)


## 0x433260: rotulo YOU GET (base 0 con 1 carta, 3 con tres).
func _draw_title() -> void:
	var stem := "you_get_%s" % _lang if _cards.size() == 1 else "you_gets_%s" % _lang
	var white := _tex(stem + "1")
	var normal := _tex(stem + "2")
	if white == null or normal == null:
		return
	var size := normal.get_size()
	var rect := Rect2(Vector2(400, TITLE_Y) - size / 2, size)
	if _t <= 0x80:
		_draw_scattered(white, rect.position, _blend.at("scatter", _t * 2))
	elif _t < 0x100:
		draw_texture_rect(normal, rect, false)
		draw_texture_rect(white, rect, false, Color(1, 1, 1, _blend.at("white", (0x100 - _t) * 2) / 256.0))
	else:
		draw_texture_rect(normal, rect, false)


## Tabla de 0x52daa0/0x52d6f0: 256 bytes de rand() de MSVC tras srand(0).
static var _scatter_table := PackedByteArray()

static func _scatter_bytes() -> PackedByteArray:
	if _scatter_table.is_empty():
		var hold := 0
		_scatter_table.resize(256)
		for i in 256:
			hold = (hold * 214013 + 2531011) & 0xffffffff
			_scatter_table[i] = ((hold >> 16) & 0x7fff) & 0xff
	return _scatter_table


## 0x52deb0 (modo 3, vtable+0x4c): la imagen en bloques de 4x2 desplazados hacia fuera del
## centro; el desplazamiento es tabla * direccion * k >> 16, con la direccion normalizada a 256
## (raiz truncada, 0x585f5c) y k = (w + h) - ((w + h) * p >> 8). Con p > 0xff, entera.
## `p` llega mezclado entre ticks: los desplazamientos se calculan en coma flotante y se
## redondean hacia abajo como el >> 16 del original, iguales en los ticks enteros.
func _draw_scattered(tex: Texture2D, origin: Vector2, p: float) -> void:
	if p <= 0:
		return
	var w := tex.get_width()
	var h := tex.get_height()
	if p > 0xff:
		draw_texture(tex, origin)
		return
	var table := _scatter_bytes()
	var k := (w + h) - floorf((w + h) * p / 256.0)
	var seed_x := 0
	var seed_y := 1
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var dx := x - w / 2
			var dy := y - h / 2
			var length := int(sqrt(float(dx * dx + dy * dy)))
			if length != 0:
				dx = int(float(dx * 0x100) / length)
				dy = int(float(dy * 0x100) / length)
			var bw := mini(4, w - x)
			var bh := mini(2, h - y)
			var ox := floorf(table[(seed_x + x) & 0xff] * dx * k / 65536.0)
			var oy := floorf(table[(seed_y + x) & 0xff] * dy * k / 65536.0)
			draw_texture_rect_region(tex, Rect2(origin + Vector2(x + ox, y + oy), Vector2(bw, bh)), Rect2(x, y, bw, bh))
			x += 4
		y += 2
		seed_y += 0x26
		seed_x += 0x1a


## 0x433520: aparicion del reverso, giro, reflejo y nombre de la carta k.
func _draw_card(k: int) -> void:
	var ta := _t - 0x40 * k
	var tb := _t - 0x100 * k
	var cx := _card_x(k)
	var back := Assets.texture("common/card/card_ura.png")
	var face := CardDB.card_texture(_cards[k]["id"])
	var rect := Rect2(cx - CARD_W / 2, CARD_Y - CARD_H / 2, CARD_W, CARD_H)
	if ta <= 0x80:
		return
	if ta < 0x100:
		draw_texture_rect(back, rect, false, Color(1, 1, 1, _blend.at(["back", k], 2 * ta - 0x100) / 256.0))
		return
	if tb <= 0x180:
		draw_texture_rect(back, rect, false)
		return
	if tb <= 0x200:
		var a := 2 * tb - 0x300
		var w: float = _blend.at(["flip", k], absi((DuelVisualMath.cos_fx(a & 0x1ff) * CARD_W) >> 16))
		draw_texture_rect(back if a < 0x80 else face, Rect2(cx - w / 2, rect.position.y, w, CARD_H), false)
		return
	draw_texture_rect(face, rect, false)
	if tb <= 0x300:
		pass  # reflejo aditivo en _build_sprites
	elif k < _names.size():
		_names[k].visible = true
	if _cards[k]["new"]:
		_draw_new(k, tb)


## 0x433a86: etiqueta NEW: aparece, se queda y se amplia (el arcoiris va en _build_sprites).
func _new_alpha(tc: int) -> int:
	if tc <= 0x380 or tc >= 0x480:
		return clampi(DuelVisualMath.cos_fx(((tc & 0xff) - 0x80) & 0x1ff) >> 8, 0, 255)
	return 255


func _new_rect(k: int, tc: int, label: Texture2D) -> Rect2:
	var size := label.get_size()
	if tc > 0x480:
		# (u - 0x40) / 0x40: de 1x (u = 0x80) a casi 3x, sin salto.
		size *= float((tc & 0xff) - 0x40) / 0x40
	return Rect2(Vector2(_card_x(k), CARD_Y) - size / 2, size)


func _draw_new(k: int, tc: int) -> void:
	if tc <= 0x300 or tc > 0x500:
		return
	var label := _tex("card_new_%s" % _lang)
	if label != null:
		draw_texture_rect(label, _blend.at(["new", k], _new_rect(k, tc, label)), false, Color(1, 1, 1, _blend.at(["new_alpha", k], _new_alpha(tc)) / 255.0))


## 0x432810: chispa que crece y se apaga en 16 pasos.
func _draw_spark(s: Dictionary) -> void:
	var tex := _tex("card_new_hikari")
	if tex == null:
		return
	var f: int = s["f"]
	var sz: float = _blend.at(["spark", s["pos"]], mini(0xff, 2 * (0x80 - absi(f - 0x80))))
	var size := tex.get_size() * sz / 256.0
	draw_texture_rect(tex, Rect2(s["pos"] - size / 2, size), false, Color(1, 1, 1, sz / 255.0))
