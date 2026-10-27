extends Node2D
signal background_shade_changed(alpha: float, band_progress: int)
const FieldEffects = preload("res://scenes/duel/duel_field_visual.gd")
const BasicEffects = preload("res://scenes/duel/duel_basic_effects.gd")
const SpecialEffects = preload("res://scenes/duel/duel_special_effects.gd")
const PortraitEffects = preload("res://scenes/duel/duel_portrait_effects.gd")
const StartShade = preload("res://scenes/duel/duel_start_shade.gd")
## Presentación determinista: consume eventos, sin escribir memoria ni usar el RNG del duelo.
## El dueño avanza este reloj y detiene el motor mientras haya una secuencia activa.
const SIZE := DuelGeometry.FIELD_SIZE
## Capa del retrato de reaccion, sobre las cifras de dano (capa 100 en duel_basic_effects).
const PORTRAIT_Z := 110
var game: String
var hidden_hand: bool
var pending: Array[Dictionary] = []
var overlays: Array[Dictionary] = []
var active: Dictionary = {}
var frame := 0
var _clock := 0.0
var displayed_lp := [-1, -1]
var played: Dictionary = {}
var _chain: Dictionary = {}
var _phase_player := -1
var hand_positions: Dictionary = {}
var visual_tick := 0
## Campo de prioridad nativa negativa: extrae MT antes de Exodia en cada tick.
var native_field_tick := Callable()
var _visual_clock := 0.0
## Interpolacion entre ticks para dibujar a la frecuencia del monitor sin cambiar la velocidad:
## sprites del tick anterior y del actual (textura, posicion, escala, giro, alfa) y tick en que
## se tomo la instantanea actual. En cada fotograma se mezcla del anterior al actual segun la
## fraccion de tick transcurrida; en los ticks enteros se dibuja exactamente el estado nativo.
var _snap_prev: Array = []
var _snap_cur: Array = []
var _snap_tick := -1
var _restore_music := ""
var _attack_player := -1
## Efectos de sacrificio vivos (FUN_004650d0), por "jugador:zona": contador +0x14, giro +0x18,
## suelto +0x10, centro, defensa (bit 0x4000 de +0x24) y las 8 posiciones de las estrellas.
var _sacrifice := {}
## Motor del duelo (para seguir la carta de los efectos que acompanan a un objeto visual).
var _duel_ref: Duel
## Objetos visuales de las cartas de la mesa (DAT_005af738). Lo que se dibuja sale de aqui, no
## de la memoria del motor: el objeto llega antes de que el comando escriba la zona (405950
## paso 4), sigue en su zona cuando 0x78 la vacia, y la pila solo cambia de imagen al llegar.
var table := DuelCardTable.new()
## Zonas cuyo indice logico retiro el nucleo (0x78 / Joey 405020) mientras el objeto sigue.
var _field_detached: Dictionary = {}
## Punto de descanso para `table.follow_memory`: lo pone el dueño mientras espera al jugador; un
## cambio de fase tambien lo es.
var at_rest := false
var _phase_rest := false
## Ultimo valor del comando 0x11 (0x4359a0 compara con +0x1c).
var _field_value := -1
## Objeto de batalla (DAT_005af6f0, 0x40d4c0): estado +0x10, contador +0x14, jugador +0x18 y
## atacante +0x1c. 0 fuera de la batalla, 1 fase de batalla (0x40ce80/0x40cbe0), 2 atacante
## elegido (0x40cc00), 3 apuntando (0x40cc30), 4 ataque (0x40cc40), 6/7 resultado (0x40cca0).
var _battle := {"state": 0, "counter": 0, "p": 0, "zone": -1}
## Posicion del raton (la usa el estado 3).
var pointer := Vector2.ZERO

func _init(game_id: String, conceal_hand: bool = false) -> void:
	game = game_id
	hidden_hand = conceal_hand
	z_index = 50

func reset(duel: Duel) -> void:
	if _duel_ref != null and _duel_ref != duel and _duel_ref.card_visual_query == Callable(self, "card_object_index"):
		_duel_ref.card_visual_query = Callable()
	_duel_ref = duel
	duel.card_visual_query = Callable(self, "card_object_index")
	table.sync(duel)
	_field_detached.clear()
	_field_value = -1
	_battle = {"state": 0, "counter": 0, "p": 0, "zone": -1}
	_phase_was_battle = false
	_lp_number = {}
	_shade_on = false
	_shade_c = 0
	_start_banner_shade = false
	_shade_draw_c = 0
	_start_banner_last_draw = false
	end_banner = ""
	_finish_music()
	pending.clear()
	overlays.clear()
	active.clear()
	_chain.clear()
	_sacrifice.clear()
	_phase_player = -1
	_attack_player = -1
	frame = 0
	_clock = 0
	visual_tick = 0
	_visual_clock = 0
	PortraitEffects.reset_duel_state(duel)
	for p in 2:
		# Ka45fa40 inicializa +24 del objeto visual en8000 antes del comando10.
		# El motor sigue en cero; se respetan LP explicitos de escenarios/reanudacion.
		var core_lp := duel.m.u16(DuelMem.pl(p))
		displayed_lp[p] = 8000 if game == "kaiba" and duel.executed == 0 and core_lp == 0 else core_lp
	_clear()

## Indice +0x10 que consulta el nucleo; no confundir imagen retenida y zona logica.
## Las pilas existen aunque esten vacias (412f20); una zona vacia no tiene objeto (413170).
func card_object_index(p: int, loc: int) -> int:
	if _duel_ref == null: return -1
	return table.object_index(_duel_ref, p, loc)

func joey_objects_busy() -> bool:
	if busy(): return true
	# El rotulo de fase es el objeto propio de 481040 (espera 4812b0): mientras se desvanece no
	# ocupa los efectos. Contarlo retrasaba ~5 ticks el comando siguiente (0xe6 -> 0xce al
	# invocar tras la fase principal; cotejo del duelo completo, 25-10-2026).
	for overlay in overlays:
		if overlay["event"].get("mode", "") != "phase_native": return true
	return false

## 41cee0: indices de mano; campo suma indice, salvo fallback o copia separada.
func joey_card_object_exists(p: int, loc: int, i: int) -> bool:
	if _duel_ref == null: return false
	if loc == 11:
		return i >= 0 and i < table.hand[p].size()
	if loc < 11:
		# Joey 405020 copia el objeto a una ranura aparte (i > 15) hasta su salida.
		if loc + i > 10 and i > 15: return _field_detached.has("%d:%d" % [p, loc])
		return card_object_index(p, loc + i if loc + i < 11 else loc) >= 0
	return false

func busy() -> bool:
	# 4054b0 no espera la explosion en el contador del paso 2; en el paso 5
	# 403c70 si consulta el objeto 439930 hasta que termina su contador.
	if game == "yugi" and _duel_ref != null and (_duel_ref.cmd_op() & 0xfff) == 0x7a and _duel_ref.step() == 5:
		for overlay in overlays:
			if overlay["event"].get("kind", "") == "cmd7a" and int(overlay["frame"]) < int(overlay["event"]["native_lifetime"]) - 1: return true
	# 405d10 cuenta ocho ticks (paso 2) y mueve el objeto (paso 3) mientras
	# 438c60 sigue vivo; solo el paso 4 consulta 403c70 para esperar su final.
	if game == "yugi" and active.get("kind", "") == "special_summon" and _duel_ref != null and _duel_ref.step() in [2, 3]:
		return false
	if game == "yugi" and active.get("kind", "") == "destroy_effect" and _duel_ref != null and _duel_ref.step() in [2, 3]:
		return false
	# Los objetos se actualizan antes de consultar 403c70: en el tick que
	# alcanza el umbral el motor ya puede terminar el paso 4.
	if game == "yugi" and active.get("kind", "") in ["special_summon", "destroy_effect"] and _duel_ref != null and _duel_ref.step() == 4 and frame >= int(active.get("frames", 0)) - 1:
		return false
	if game == "yugi" and active.get("mode", "") == "lp_total" and _duel_ref != null and (_duel_ref.cmd_op() & 0xfff) in [0x42, 0x43] and _duel_ref.step() == 4 and frame >= int(active.get("frames", 0)) - 1:
		return false
	if game == "yugi" and active.get("mode", "") == "sacrifice_release" and _duel_ref != null and _duel_ref.step() == 2:
		var mark: Dictionary = _sacrifice.get(active["key"], {})
		if not mark.is_empty() and int(mark["counter"]) >= 0xf0: return false
	return not active.is_empty() or not pending.is_empty() or (_start_banner_shade and _shade_moving())

func zone(p: int, z: int) -> Vector2:
	return DuelGeometry.zone(p, z, game)

func hand(p: int, i: int, count: int) -> Vector2:
	return hand_positions.get(p * 256 + i, DuelGeometry.hand(p, i, count))

func packed_position(value: int, duel: Duel) -> Vector2:
	if ((value >> 1) & 15) == 11: return hand(value & 1, (value >> 5) & 511, duel.m.u8(DuelMem.pl(value & 1) + 2))
	var loc := (value >> 1) & 15
	if loc in [12, 13, 14]:
		return pile_object_position(value & 1, loc, (value >> 5) & 511)
	return DuelGeometry.packed(value, duel)

func pile_object_position(p: int, loc: int, index: int) -> Vector2:
	var count := int(table.piles[p][loc]["count"])
	if game == "joey": return preload("res://scenes/duel/joey_pile.gd").object_position(p, loc, index, count)
	return preload("res://scenes/duel/classic_pile.gd").object_position(p, loc, index, count)

func enqueue(e: Dictionary, duel: Duel) -> void:
	var kind: String = e.get("kind", "")
	var p: int = int(e.get("p", 0)) & 1
	if kind == "lp_popup":
		if not _lp_number.has(p):
			_lp_number[p] = {"zone": -1, "amount": int(e.amount), "start": visual_tick}
		return
	if kind == "lp_popup_clear":
		_lp_number.erase(p)
		return
	if kind == "pile_top":
		var loc := int(e["loc"])
		if table.piles[p].has(loc):
			var center := pile_object_position(p, loc, 1)
			pending.append({"kind":kind, "mode":kind, "p":p, "loc":loc, "card":int(e.card),
				"before":int(table.piles[p][loc].top), "center":center, "hide":[center], "frames":8})
			if active.is_empty(): _begin()
		return
	# Setter absoluto de LP del objeto nativo; no inicia una cuenta animada.
	if kind == "lp_set":
		displayed_lp[p] = int(e["value"])
		return
	if kind in ["joey_field_shuffle", "joey_hand_shuffle"]:
		var effect := e.duplicate(true)
		effect["centers"] = {}
		for i in e["objects"]:
			effect["centers"][i] = hand(p,i,duel.m.u8(DuelMem.pl(p)+DuelMem.P_HAND_N)) if kind == "joey_hand_shuffle" else zone(p,i)
		effect["mode"] = kind
		effect["native_lifetime"] = 32 # 418b60: state5 counter512 decrements16.
		effect = BasicEffects.normalize(effect, duel)
		overlays.append({"event":effect, "frame":0})
		played[kind] = played.get(kind, 0) + 1
		if kind == "joey_field_shuffle":
			# Las cartas se barajan entre los objetos de esas zonas: cada uno toma la de memoria.
			for z in e["objects"]:
				if int(z) < 11 and not table.field[p][int(z)].is_empty():
					table.field[p][int(z)]["card"] = duel.f401a70(duel.m.u32(DuelMem.zone(p, int(z))) & 0xfff)
		else:
			# C6 changes images in the existing slot objects. Moving those objects
			# by card ID would make the hand reflow cross unrelated positions.
			for i in e["objects"]:
				if int(i) < table.hand[p].size():
					table.hand[p][int(i)]["card"] = duel.f401a70(duel.m.u32(duel.f5419b0(p, 11, int(i))) & 0xfff)
			table.revision += 1
		_render_frame()
		return
	if kind == "card_replace":
		var loc: int = e["loc"]
		var i: int = e["i"]
		if loc < 11:
			# Joey: el objeto de la zona cambia de carta sin moverse (40ff60).
			var z := loc + i if loc + i < 11 else loc
			if not table.field[p][z].is_empty(): table.field[p][z]["card"] = e["card"]
		_render_frame()
		return
	if kind == "joey_relocate_appear":
		var effect := e.duplicate(true)
		effect["mode"] = "special"
		effect["native_lifetime"] = 41 # 4500e0: +8, vivo mientras <321.
		effect = BasicEffects.normalize(effect, duel)
		overlays.append({"event":effect, "frame":0})
		played["special"] = played.get("special", 0) + 1
		Audio.play_sfx("%s/voice/internal/reborn.wav" % game)
		_render_frame()
		return
	if kind == "grave_top":
		# 0xdf / 0x72 suben la carta al tope (0x544890) y la pila pasa a mostrarla (estado 6 de
		# 0x42efb0: la carta nueva se desliza y la imagen cambia al final; PENDIENTE D03).
		var pile: Dictionary = table.piles[p][DuelMem.LOC_GRAVE]
		if int(pile["count"]) > 0:
			pile["top"] = int(e.get("card", pile["top"]))
			table.revision += 1
		return
	if kind == "joey_object_place":
		# Joey 40d840 -> 41d160 (buzón tipo 5): el objeto aparece en su zona, sin vuelo.
		var z := int(e["zone"])
		var obj := DuelCardTable.memory_zone(duel, p, z)
		if obj.is_empty():
			obj = {"card": int(e["card"]), "face": bool(e["face"]), "defense": z < 5 and bool(e["defense"]), "owner": p}
		table.place(p, z, 0, obj)
		return
	if kind == "special_summon_place":
		_place_special(e)
		if active.get("kind", "") == "special_summon": active["object_placed"] = true
		return
	if kind == "field_detach":
		# 0x78 / Joey 405020 retiran el indice logico; el objeto visual sigue en la zona hasta
		# que un comando lo mueva (0x7a, 0xb5...). La tabla no cambia.
		_field_detached["%d:%d" % [p, e["zone"]]] = int(e.get("card", -1))
		return
	var d: Dictionary = e.duplicate(true)
	d["mode"] = kind
	d["frames"] = 8 # 410030: +0x20 hasta0x100.
	d["center"] = zone(p, clampi(int(e.get("zone", 0)), 0, 10))
	if kind == "cmd32":
		_attack_player = p
		return
	if kind == "phase" and int(e.get("phase", -1)) == 3: _attack_player = p
	if kind == "phase": _phase_rest = true
	# FUN_00402840: la fase 3 activa el objeto de batalla (0x40ce80) y salir de ella lo apaga
	# (0x40cbd0); el evento sigue luego a la rama de retratos.
	if kind == "phase": _battle_event(kind, e, p)
	# 0xe9 (fusion): antes del efecto, el paso 0 de 0x406450 / 0x406710 pide una reaccion
	# (vacia en Yugi; reaction12 en Kaiba).
	if kind == "cmd" and e.get("op", 0) == 0xe9:
		var reaction := PortraitEffects.normalize(d.merged({"game": game}), duel)
		if not reaction.is_empty():
			pending.append(reaction)
			if active.is_empty(): _begin()
		return # El efecto se crea desde el paso 1 del nucleo, tras esta reaccion.
	if kind in ["reaction_destroy", "reaction_flip", "reaction_lp", "reaction_card", "reaction_activation", "phase"] or (kind == "cmd" and e.get("op", 0) in [0x07, 0xad, 0xe6]):
		d["game"] = game
		if kind == "phase":
			# 0x460b00 -> 0x460a10: mismo jugador y fase de batalla: battle_turn.wav (0x10000011).
			if _phase_player == p and int(e.get("phase", -1)) == 3:
				d["sound_file"] = "battle_turn"
			if _phase_player >= 0 and _phase_player != p:
				pending.append(PortraitEffects.normalize({"kind": "next_turn", "p": _phase_player, "game": game}, duel))
				if game == "yugi":
					# 460bb0: con otro jugador el panel cuenta +0x168 hasta 0x200 (64 ticks) antes de
					# la fase y 460b80 espera todo ese tramo; el dibujo del cambio dura 48.
					pending.append({"mode": "wait", "frames": 16, "center": Vector2(525, 300)})
			_phase_player = p
		d = PortraitEffects.normalize(d, duel)
		if d.is_empty(): return
		if d.get("mode", "") == "phase_native" and game in ["yugi", "joey"]:
			# 402840 espera a 460b80: contador +0x164 > 0x7f (16 ticks; 24 en batalla, que sube
			# de 4 en 4 entre 0x40 y 0x80). El panel sigue hasta 0x100 sin bloquear.
			# Joey 4812b0 (desde 404920) libera igual con +0x14c > 0x7f, que 481370 sube de 8 en 8
			# (de 4 en 4 en batalla); el cotejo del duelo completo (25-10-2026) lo confirma.
			d["native_lifetime"] = d["frames"]
			d["frames"] = 24 if int(d.get("phase", 0)) == 3 else 16
			# En Joey 481370 sube el contador antes de que el motor consulte 4812b0 en el mismo
			# tick: el comando siguiente llega un tick antes que con la espera de Yugi (todas las
			# fases iban +1 en el cotejo del duelo completo).
			if game == "joey": d["frames"] = int(d["frames"]) - 1
		pending.append(d)
		if active.is_empty(): _begin()
		return
	_battle_event(kind, e, p)
	match kind:
		"fusion":
			d["frames"] = SpecialEffects.timings("fusion", d)
			# Kaiba 43f2c0/43f3cc: solo el Dragon definitivo (17b) inicia m_ulti.
			# El resto no activa sonido en el constructor; la musica vuelve via bgm.
			if game == "kaiba" and int(d.get("card", 0)) == 0x17b:
				d["music_once"] = "kaiba/voice/stream/m_ulti.wav"
			if game == "yugi":
				# 0x439d20 (contador = fotograma * 4): fusion1 en 4 (sonido de modo), fusion2 en
				# 0x180; +0x10 es el jugador (0x43eb90, param_1 de 0x406450): el humano oye
				# Yugi_50 en 0x80, la CPU Yugi_12 en 0x40 y Yugi_13 en 0x180.
				var voices: Array = [[32, "yugi_50"]] if p == 0 else [[16, "yugi_12"], [96, "yugi_13"]]
				d["sounds"] = [[96, "yugi/voice/internal/fusion2.wav"]]
				for v: Array in voices:
					d["sounds"].append([v[0], "yugi/voice/internal/%s.wav" % v[1]])
		"zone_marker":
			# FUN_00465480 (tipo 0, al marcar un sacrificio) crea el efecto, que se queda en
			# 0x80 sobre la carta; FUN_00465550 (tipo 1, comando 0x95) lo suelta o lo crea
			# suelto, y el comando espera a que termine (FUN_00403c40).
			if int(e.get("type", 0)) == 2:
				# FUN_00465640 (comando 0x59): efecto de material de fusion (0x4652d0) sobre la
				# carta de la ubicacion `zone` (codigo 0-15) y posicion `value`, si no existe.
				var fkey := "f:%d:%d:%d" % [p, int(e.get("zone", 0)), int(e.get("value", 0))]
				if not _sacrifice.has(fkey):
					_sacrifice[fkey] = {"kind": "fusion", "counter": 0, "rot": 0, "release": false,
							"p": p, "loc": int(e.get("zone", 0)), "index": int(e.get("value", 0)),
							"card": duel.m.u16(duel.f5419b0(p, int(e.get("zone", 0)), int(e.get("value", 0)))) & 0xfff}
				return
			var key := "%d:%d" % [p, int(e.get("zone", 0))]
			if not _sacrifice.has(key):
				_sacrifice[key] = _new_sacrifice(p, int(e.get("zone", 0)), duel)
			if int(e.get("type", 0)) == 1:
				pending.append({"mode": "sacrifice_release", "key": key, "frames": 1 << 20, "p": p})
				if active.is_empty(): _begin()
			return
		"zone_marker_clear":
			# FUN_00464cd0: apaga los efectos que no se han soltado.
			for key in _sacrifice.keys():
				if not _sacrifice[key]["release"]: _sacrifice.erase(key)
			return
		"draw":
			d["mode"] = "move"
			d["from_pos"] = DuelGeometry.DECK[p]
			d["to_pos"] = hand(p, maxi(0, duel.m.u8(DuelMem.pl(p) + 2) - 1), duel.m.u8(DuelMem.pl(p) + 2))
			d["hidden"] = hidden_hand and p == 1
			# 548e80: la memoria ya tiene la carta en la mano; el objeto sale del mazo al final.
			d["src"] = [p, DuelMem.LOC_DECK, 0]
			d["dst"] = [p, DuelMem.LOC_HAND, -1]
		"move":
			d["from_pos"] = packed_position(e["from"], duel)
			d["to_pos"] = packed_position(e["to"], duel)
			var src_p: int = e["from"] & 1
			d["p"] = src_p
			d["from_angle"] = (PI if src_p == 1 else 0) + (PI / 2 if (e["from"] & 0x4000) else 0)
			d["to_angle"] = (PI if (e["to"] & 1) else 0) + (PI / 2 if (e["to"] & 0x4000) else 0)
			var src_loc: int = (e["from"] >> 1) & 15
			d["hidden"] = hidden_hand and src_p == 1 and src_loc not in [14, 15]
			if src_loc < 11:
				var src_z: int = src_loc + ((e["from"] >> 5) & 511) if src_loc in [0, 5] else src_loc
				if src_z < 11 and (duel.m.u8(DuelMem.zone(src_p, src_z) + 6) & 2): d["hidden"] = false
			if e.has("source_flags"): d["hidden"] = (int(e["source_flags"]) & 2) == 0
			d["src"] = _word_loc(int(e["from"]))
			d["dst"] = _word_loc(int(e["to"]))
			d["dst_face"] = (int(e["to"]) & 0x8000) != 0
			d["dst_defense"] = int(d["dst"][1]) < 5 and (int(e["to"]) & 0x4000) != 0
		"hand_to_monster", "hand_to_spell":
			d["mode"] = "move"
			var count := duel.m.u8(DuelMem.pl(p) + 2)
			var i: int = (e["b"] & 0xff) >> 4
			d["from_pos"] = hand(p, i, count)
			d["to_pos"] = d["center"]
			d["hidden"] = true
			d["from_size"] = DuelGeometry.HAND_SIZE
			d["to_size"] = SIZE
			# 410030 gira la carta durante el mismo vuelo: en 0xc4 el bit 9 de b es la posicion
			# de defensa (va a FUN_005422b0 como bit 0 de las banderas de la zona).
			d["from_angle"] = PI if p == 1 else 0.0
			d["to_angle"] = (PI if p == 1 else 0.0) + (PI / 2 if kind == "hand_to_monster" and (e["b"] & 0x200) else 0.0)
			# 405750 / 405950 paso 1: el objeto de la mano va a la zona con la cara de destino
			# (bit 8 de b); la zona se escribe en el paso 4, despues del vuelo.
			d["src"] = [p, DuelMem.LOC_HAND, i]
			d["dst"] = [p, int(e.get("zone", 0)), 0]
			d["dst_face"] = (e["b"] & 0x100) != 0
			d["dst_defense"] = kind == "hand_to_monster" and (e["b"] & 0x200) != 0
			if (e["b"] & 0x100) == 0:
				pending.append(d.duplicate(true))
				d["mode"] = "set"
				d["frames"] = 22 # 438c20: +12 hasta contador >0x100.
				# Banderas de la zona que pondra el comando: bit 9 de b = defensa (solo
				# monstruos), bit 8 = boca arriba (FUN_005422b0 / FUN_005423a0).
				var defense := 1 if kind == "hand_to_monster" and (e["b"] & 0x200) else 0
				d["flags"] = defense | (((e["b"] >> 8) & 1) << 1)
				d["monster"] = kind == "hand_to_monster"
				d.erase("hide")
		"zone_to_grave", "field_to_hand", "field_to_deck", "field_to_banish", "card_to_banish", "zone_to", "zone_lift":
			d["mode"] = "move"
			d["from_pos"] = d["center"]
			var owner := (duel.m.u16(DuelMem.MOVING_CARD) >> 12) & 1
			d["to_pos"] = DuelGeometry.GRAVE[owner]
			if kind == "field_to_hand": d["to_pos"] = hand(owner, duel.m.u8(DuelMem.pl(owner) + 2), duel.m.u8(DuelMem.pl(owner) + 2) + 1)
			if kind == "field_to_deck": d["to_pos"] = DuelGeometry.DECK[owner]
			if kind.contains("banish"): d["to_pos"] = DuelGeometry.location(p, 15)
			if kind == "zone_to" and e.get("b", 0) != 0: d["to_pos"] = DuelGeometry.location(p, 15)
			if kind == "zone_lift":
				var target_p: int = e["b"] & 1
				var target_z: int = e["b"] >> 8
				if target_z < 11: d["to_pos"] = zone(target_p, target_z)
				elif target_z == 13: d["to_pos"] = DuelGeometry.DECK[target_p]
				elif target_z == 14: d["to_pos"] = DuelGeometry.GRAVE[target_p]
				else: d["to_pos"] = DuelGeometry.location(target_p, target_z)
			d["hidden"] = hidden_hand and p == 1 and (duel.m.u8(DuelMem.MOVING_CARD + 6) & 2) == 0
			d["src"] = [p, int(e.get("zone", 0)), 0]
			var dst_p := owner
			var dst_loc := DuelMem.LOC_GRAVE
			if kind == "field_to_hand":
				dst_p = owner
				dst_loc = DuelMem.LOC_HAND
			elif kind == "field_to_deck":
				dst_p = owner
				dst_loc = DuelMem.LOC_DECK
			elif kind.contains("banish") or (kind == "zone_to" and e.get("b", 0) != 0):
				dst_p = p
				dst_loc = DuelMem.LOC_BANISH
			elif kind == "zone_lift":
				dst_p = e["b"] & 1
				dst_loc = (e["b"] >> 8) & 255
			d["dst"] = [dst_p, dst_loc, -1 if dst_loc == DuelMem.LOC_HAND else 0]
			if kind == "card_to_banish":
				d["from_pos"] = DuelGeometry.location(p, 0, int(e.get("c", 0)))
				d["src"] = [p, 0, int(e.get("c", 0))]
			if game in ["kaiba", "joey"] and (kind.contains("banish") or (kind == "zone_to" and e.get("b", 0) != 0)):
				d["mode"] = "exclusion"
				d["center"] = d["from_pos"]
				d["sound_file"] = "ignore"
				if kind == "field_to_banish": d["hidden"] = (int(e.get("flags", 0)) & 2) == 0
		"zone_swap":
			d["from_pos"] = zone(e["a"] & 1, e["a"] >> 8)
			d["to_pos"] = zone(e["b"] & 1, e["b"] >> 8)
			d["cards"] = []
			for packed in [e["a"], e["b"]]:
				var at := DuelMem.zone(packed & 1, packed >> 8)
				d["cards"].append({"id": duel.cards.id_of(duel.m.u16(at) & 0xfff), "flags": duel.m.u8(at + 6), "p": packed & 1})
			d["hide"] = [d["from_pos"], d["to_pos"]]
		"cmd84":
			d["mode"] = "move"
			# 0x406c40 -> 0x43ef70(c, b, a) y 0x43a970: una imagen aparte de la carta de equipo
			# (c) va de la zona de a (la carta de equipo) a la de b (el monstruo equipado); las
			# cartas del campo siguen dibujadas.
			d["from_pos"] = packed_position(((e["a"] >> 8) & 15) * 2 | (e["a"] & 1), duel)
			d["to_pos"] = packed_position(((e["b"] >> 8) & 15) * 2 | (e["b"] & 1), duel)
			d["hide"] = []
			d["frames"] = 24 # 43a970: contador+8 hasta0xc0.
		"zone_counter":
			var flags := duel.m.u16(DuelMem.zone(p, e["zone"]) + 6)
			d["value"] = (flags >> 2) & 15 if e.get("counter_type", 3) == 3 else (flags >> 6) & 7
			# El comando espera (0x4138b0) a que el objeto de la carta acabe su estado 3/4:
			# +0x1c de 0x200 a 0 de 0x10 en 0x10 (32 fotogramas). Lo dibuja DuelCardStats.
			d["frames"] = 32
		"flip", "change_position":
			var at := DuelMem.zone(p, e["zone"])
			d["card"] = duel.cards.id_of(duel.m.u16(at) & 0xfff)
			d["flags"] = duel.m.u8(at + 6)
			d["hide"] = [d["center"]]
			d["frames"] = 8
			if game == "yugi":
				var requested: int = int(e.get("flags", d["flags"])) & 3
				d["native_target_flags"] = (requested ^ 2) if kind == "flip" else ((requested ^ 1) | (2 if int(e.get("b", 0)) != 0 else 0))
		"shuffle":
			# 438dd0: +8 hasta 0x144 (41 ticks); 43a5c0: (contador/8)%5.
			d["frames"] = 41
			d["center"] = Vector2(525, 300)
		"hand_shuffle":
			d["frames"] = 33
			d["center"] = hand(p, 0, 1)
		"set", "summon", "special":
			# Constructores P nativos; BasicEffects conserva sus formulas y duraciones.
			if e.get("native_object_pending", false): table.awaiting[p][int(e.get("zone", 0))] = int(e.get("card", 0))
		"monster_appear", "special_summon", "token":
			d["mode"] = "summon" if kind != "special_summon" else "special"
			d["frames"] = 33 # 438c40: +8, vivo mientras contador <0x101.
		"destroy_effect":
			if e.get("native_pile_destroy", false):
				d["center"] = packed_position((int(e.loc) << 1) | (int(e.slot) << 5) | p, duel)
				if int(e.loc) == 11: d["hand_slot"] = int(e.slot)
			d["frames"] = 26 # 439930: explosión hasta contador 0xd0, +8.
		"card_effect":
			d["frames"] = 33
			var index := duel.cards.index_of(e["card"])
			d["monster"] = duel.cards.type_of(index) < 21
			d["center"] = Vector2(525, 300)
		"zone_move":
			d["mode"] = "move"
			var a: int = e.get("from", (int(e.get("zone", 0)) << 8) | p)
			var owner := (duel.m.u16(DuelMem.MOVING_CARD) >> 12) & 1
			var b: int = e.get("to", (14 << 8) | owner)
			d["from_pos"] = zone(a & 1, (a >> 8) & 255)
			d["to_pos"] = DuelGeometry.location(b & 1, (b >> 8) & 255)
			d["hidden"] = (int(e.get("source_flags", duel.m.u8(DuelMem.zone(a & 1, (a >> 8) & 255) + 6))) & 2) == 0
			d["src"] = [a & 1, (a >> 8) & 255, 0]
			d["dst"] = [b & 1, (b >> 8) & 255, -1 if ((b >> 8) & 255) == DuelMem.LOC_HAND else 0]
		"lp_total":
			d["frames"] = int(e.get("count_delay", 32)) + lp_ticks(absi(e["to"] - e["from"]))
			d["center"] = Vector2(110, 36 if p == 1 else 540)
		"cmd7a":
			d["mode"] = "explosion"
		"cmd34":
			d["p"] = _attack_player if _attack_player >= 0 else p
			d["mode"] = "attack"
			d["args"] = [e["a"], 5, 2 - p]
		"cmd11":
			d["mode"] = "field_change"
			d["game"] = game
			# 0x4359a0: solo si cambia el valor suena scene_change.wav (0x10000012).
			if int(e.get("a", -1)) != _field_value:
				d["sound_file"] = "scene_change"
			_field_value = int(e.get("a", -1))
		"highlight_card":
			# 0x407190: activaciones simultaneas sobre cada copia boca arriba.
			var index := duel.cards.index_of(int(e.get("card", 0)))
			var subs: Array = []
			for q in 2:
				if not e.get("both", 0) and q != p: continue
				for z in 11:
					var at := DuelMem.zone(q, z)
					if (duel.m.u16(at) & 0xfff) != index or (duel.m.u8(at + 6) & 2) == 0 or (duel.m.u8(at + 0x90) & 1) != 0:
						continue
					var loc := 0 if z < 5 else (5 if z < 10 else 10)
					subs.append(BasicEffects.normalize({"kind": "card_effect", "mode": "card_effect", "p": q, "card": int(e.get("card", 0)), "loc": loc, "c": z - loc if loc < 10 else 0, "center": zone(q, z)}, duel))
			if subs.is_empty(): return
			d["mode"] = "multi"
			d["events"] = subs
			d["frames"] = 0
			for sub: Dictionary in subs:
				d["frames"] = maxi(d["frames"], int(sub.get("frames", 17)))
		"voice", "sound":
			# Voz de la tabla de sonidos 0x5ad3d0 (id 0x1000001e + n = Yugi_(n + 1).wav): "voice"
			# 0x10000044/45 (Yugi_39/40) del comando 0x7f (0x4062b0) cuando la CPU cambia de
			# posicion y "sound" 0x10000047 (Yugi_42) de 0x402d30. Kaiba (tabla 0x5b03d8, Ka01 en
			# 0x21) pide en esos mismos sitios la misma voz: 0x10000047/48 = Ka39/40 (0x406570) y
			# 0x1000004a = Ka42 (0x403060).
			var file := str(e.get("native_sound_file", voice_file(int(e.get("id", 0)))))
			if Audio.voice_disabled("%s/voice/internal/%s.wav" % [game, file]): return
			if kind == "sound" and e.has("native_sound_file"):
				if file != "": Audio.play_sfx("%s/voice/internal/%s.wav" % [game, file])
				return # 5c03d0 no crea un objeto que bloquee el motor.
			if file == "": return
			d["mode"] = "voice"
			d["sound_file"] = file
			d["wait_voice"] = kind == "voice"
			# "voice" es el objeto 0x401bc0 (0x4022f0 al colocar, 0x4062b0 al cambiar de
			# posicion): el duelo espera a que acabe la voz. "sound" (0x402d30, fin de turno
			# 0x402710) llama directo a 0x583e10 y no espera.
			d["frames"] = PortraitEffects.voice_frames(game, file) if kind == "voice" else 1
		"bgm", "music_by_lp":
			# El motor emite IDs de Yugi; cada ejecutable elige su propia tabla y modo.
			var mode := Game.duel_mode if duel.game_mode == 0 else duel.game_mode
			if e.has("native_music_mode"): mode = int(e["native_music_mode"])
			if duel.tutorial_interactive: mode = 6
			d["mode"] = "music"
			d["music"] = preload("res://scenes/duel/duel_music.gd").path(game, mode, [duel.m.u16(DuelMem.pl(0)), duel.m.u16(DuelMem.pl(1))])
			if kind == "music_by_lp" and (game == "yugi" or e.has("native_music_mode")):
				# 4376e0 cambia la pista dentro del paso 4; no crea otro objeto que esperar.
				if _restore_music == "": Audio.play_music(d["music"])
				played["music"] = played.get("music", 0) + 1
				return
			d["frames"] = 1
		"chain_disable":
			# 0x43d9b0 / 0x438db0 / 0x43a4f0: 24 fotogramas; cha_mukou((t / 2) % 6 + 1) sobre la
			# carta, girada 90 grados si esta en defensa.
			d["frames"] = 24
		"destiny_board":
			d["center"] = Vector2(400, 300)
			if game == "kaiba":
				# 406b80 crea un objeto 43e760(...,1) por cada carta encontrada.
				# Cada constructor pide uija_all inmediatamente, sin escalonar el audio.
				d["sounds"] = []
				for card in e.get("cards", []):
					d["sounds"].append([0, "kaiba/voice/internal/uija_all.wav"])
		"cmd":
			var args: Array = e["args"]
			match e["op"]:
				0x08:
					if game == "kaiba": return # Ka sin cotejar con su ejecutable.
					if game == "yugi":
						# 4027e0: el objeto de la carta (413170(a, b & 0xff, b >> 8)) pasa al
						# estado 1 con contador 0x100 (-0x10 por tick, 410030) y el comando espera
						# a que vuelva al reposo (411300); 410ca0 la resalta con el bit 5.
						var bp: int = int(args[0]) & 1
						var bloc: int = int(args[1]) & 0xff
						var bz: int = bloc + (int(args[1]) >> 8) if bloc in [0, 5] else bloc
						if bz > 10 or table.field[bp][bz].is_empty(): return
						d["mode"] = "card_blink"
						d["p"] = bp
						d["zone"] = bz
						d["frames"] = 16
						d["center"] = zone(bp, bz)
					else:
						# Joey404460: bit16 del argumento compuesto b|c<<16 marca zona vacia.
						if (int(args[2]) & 1) == 0: return
						var slot := (int(args[1]) & 255) + (int(args[1]) >> 8)
						if slot >= 10: return
						d["mode"] = "zone_marker_joey"
						d["center"] = zone(int(args[0]) & 1, slot)
						d["frames"] = 15 # contador1..14; al15 libera el comando.
				0xe5:
					if game != "kaiba": return
					# 406ab0 -> 43e760(...,0): fijo sobre magia/trampa, sin viaje ni oscilacion.
					d["mode"] = "destiny_letter"
					d["letter"] = int(args[0]) % 5
					d["source_pos"] = zone(p, 5 + int(args[1]) % 5)
					d["sound_file"] = "uija"
					d["frames"] = 98
				0x33:
					if e.get("native_battle", false): d["native_attack_counter"] = clampi(int(_battle["counter"]), 0, 128)
					d["p"] = _attack_player if _attack_player >= 0 else p
					d["mode"] = "attack"
					d["from_pos"] = zone(p, args[0])
					var target_player := int(args[2]) - 1 if args[2] > 0 else 1 - p
					d["to_pos"] = zone(target_player & 1, args[1]) if args[1] < 5 else Vector2(525, 90 if p == 0 else 510)
					d["frames"] = 32 # 40cc40 inicia estado4;40ccf0 suma0x10 hasta>0x1ff.
				0x31:
					d["mode"] = "battle_result"
				0x14:
					d["mode"] = "banner"
					d["asset"] = "duel_start_?"
					d["frames"] = 64
				0x04:
					d["mode"] = "banner"
					d["asset"] = ["duel_win_?", "duel_lose_?", "duel_draw_?"][clampi(args[0], 0, 2)]
					d["frames"] = 64
				0x0a:
					# 4030b0 -> 4156f0/4155d0: crea el objeto del eslabon y el comando termina
					# en el acto; el objeto se anima solo (415150) y suena chain.wav al crearse.
					d["mode"] = "chain"
					d["number"] = args[1]
					d["center"] = zone(p, args[0]) if args[0] < 11 else Vector2(525, 300)
					d["counter"] = 0
					d["released"] = false
					_chain[args[1]] = d
					Audio.play_sfx("%s/voice/internal/chain.wav" % game)
					_render_frame()
					return
				0x5a:
					# 402cd0 -> 464ca0: suelta la marca de material de fusion de esa ubicacion
					# (464c30: jugador y codigo + posicion) y espera mientras alguna marca
					# soltada siga viva (464bf0 -> 464b90).
					for key in _sacrifice:
						var m: Dictionary = _sacrifice[key]
						var here: bool = int(m["loc"]) + int(m["index"]) == int(args[0]) + int(args[1])
						if m.get("kind", "") == "fusion" and int(m["p"]) == p and here:
							m["release"] = true
					d = {"mode": "marker_wait", "kind": "cmd", "p": p, "frames": 0x7fffffff}
				0x0b:
					var number: int = args[1]
					# 4151f0: número!=0 selecciona el eslabón; número0 busca jugador/zona.
					if number == 0:
						for n in _chain:
							if _chain[n].get("p", -1) == p and _chain[n]["args"][0] == args[0]:
								number = n
								break
					if not _chain.has(number): return
					# 4030f0: suelta el eslabon (415120) y espera mientras algun objeto de la
					# cadena entre o salga (4151b0 -> 415130).
					_chain[number]["released"] = true
					d = {"mode": "chain_wait", "kind": "cmd", "p": p, "frames": 0x7fffffff}
				0xe0, 0xe1, 0xe2, 0xe3, 0xe4:
					d["mode"] = "coin" if e["op"] < 0xe2 else "dice"
					d["result"] = args[0]
					d["frames"] = 90
				0xe8:
					return
				0x6f:
					d["mode"] = "summon"
					d["card"] = args[0]
					d["center"] = packed_position((int(args[1]) << 1) | p, duel)
					d["frames"] = 33
				0x73:
					d["mode"] = "card_effect"
					d["card"] = args[0]
					d["monster"] = duel.cards.type_of(duel.cards.index_of(args[0])) < 21
					d["frames"] = 33 # 43e910: -128;438cc0:+16 hasta0x181.
				0x05:
					d["mode"] = "exodia"
					d["frames"] = 180
					if game in ["yugi", "kaiba", "joey"]:
						# 0x43bff0 pide exodia_a..e al empezar cada fase del contador (c = fotograma
						# * 4): 0, 0x13c, 0x1fc, 0x23c y 0x344 (exodia_a ya es el sonido del modo).
						# Kaiba 43c710: mismos umbrales 13c/1fc/23c/344 y paso4.
						d["sounds"] = [[79, "%s/voice/internal/exodia_b.wav" % game], [127, "%s/voice/internal/exodia_c.wav" % game],
								[143, "%s/voice/internal/exodia_d.wav" % game], [209, "%s/voice/internal/exodia_e.wav" % game]]
						# Jo454010: cada pieza tiene su propio sonido (ids13..17).
						if game == "joey":
							for piece in 5: d["sounds"].append([piece * 16, "joey/voice/internal/exodia_a%d.wav" % (piece + 1)])
						if game == "yugi": pending.append(_exodia_hand(p, duel))
				_:
					return
			if d["mode"] not in ["summon", "special", "chain", "zone_marker_joey"]: d["center"] = Vector2(525, 300)
		_:
			return
	if d["mode"] == "move":
		# Algunos comandos de combate repiten la salida después de vaciar la zona: sin objeto en
		# el origen (se comprueba al empezar) el índice vacío 0xffff no es una carta que vuele.
		if int(d.get("card", 0)) == 0xffff and not d.has("src"): return
		var source: Vector2 = d["from_pos"]
		var target: Vector2 = d["to_pos"]
		for owner in 2:
			if target == DuelGeometry.GRAVE[owner]: d["to_angle"] = PI if owner == 1 else 0.0
		d["from_size"] = DuelGeometry.HAND_SIZE if source.y > 525 or source.y < 75 else SIZE
		d["to_size"] = DuelGeometry.HAND_SIZE if target.y > 525 or target.y < 75 else SIZE
		if d.get("instant", false):
			# Buzon tipo 9 (407880 -> 407cb0 -> 414810): el objeto cambia de lista al instante;
			# un fotograma ya en el destino, sin vuelo ni sonido.
			d["from_pos"] = target
			d["from_size"] = d["to_size"]
			if d.has("to_angle"): d["from_angle"] = d["to_angle"]
			d["frames"] = 1
	if d["mode"] == "field_change": d = FieldEffects.normalize(d, duel)
	d["game"] = game # Las geometrías propias de cada juego se resuelven al normalizar.
	d = BasicEffects.normalize(d, duel)
	# Joey44f630 agrega su efecto sin ocultar el objeto418ef0 ya colocado.
	if d.get("native_base_visible", false): d["hide"] = []
	if d["mode"] == "card_effect" and int(d.get("loc", -1)) < 11:
		var loc: int = d.get("loc", 0)
		var z: int = loc + int(d.get("c", 0)) if loc in [0, 5] else loc
		# Carta cuyo indice ya retiro el nucleo (Man-Eater Bug antes de 7a): el efecto sigue
		# sobre su objeto, que conserva cara y posicion.
		var obj: Dictionary = table.field[p][mini(z, 10)]
		if _field_detached.has("%d:%d" % [p, z]) and not obj.is_empty() and int(obj["card"]) == int(d["card"]):
			var flags := int(obj["defense"]) | (int(obj["face"]) << 1)
			d["flags"] = flags
			d["center"] = zone(p, z)
			d["large_activation"] = false
			d["card_size"] = SIZE
			d["effect_size"] = Vector2(SIZE.y, SIZE.x) if flags & 1 else SIZE
			d["hide"] = [d["center"]]
			d["frames"] = 17
	if d["mode"] == "card_effect" and int(d.get("loc", -1)) == 11 and not d.get("large_activation", true):
		var count := duel.m.u8(DuelMem.pl(p) + 2)
		d["center"] = hand(p, int(d["hand_slot"]), count)
		d["hide"] = [d["center"]]
	if int(d.get("frames", 0)) <= 0: return
	d["game"] = game
	d = SpecialEffects.normalize(d, duel)
	if d["mode"] == "destroy_effect":
		d["native_lifetime"] = 16
		d["frames"] = 4 # 43eb60 libera al64; break438d00 dura256.
	elif d["mode"] == "explosion" and d.get("kind", "") == "cmd7a":
		# 4054b0 no espera a la explosion: su paso 2 cuenta 0x700 en pasos de 0x80 (lo hace el
		# motor) y el paso 3 manda la carta a su destino (buzon tipo 9, sin vuelo) mientras
		# 439930 sigue dibujandola hasta 0xd0.
		d["native_lifetime"] = d["frames"]
		d["frames"] = 1
	if game == "yugi" and kind == "draw":
		# 548e80 escribe407830; el siguiente tick407f00 despacha407a60.
		# El vuelo410030 mantiene sus ocho ticks; el buzon añade uno antes de crearlo.
		pending.append({"mode": "wait", "frames": 1, "center": Vector2.ZERO})
	pending.append(d)
	if active.is_empty(): _begin()

## Pasos 0-4 de 0x406a30 (comando 0x05, Exodia) antes del efecto 0x43eda0:
## - paso 0: con la CPU suena Yugi_65 (0x1000005e);
## - paso 2: cada 16 fotogramas (subcontador += 0x80, pieza = bits 11-13) busca en la mano la
##   pieza de la tabla 0x59a5cc y crea 0x438df0: la carta sube (CPU: baja) c/4 px y se apaga
##   con alfa 255 - c (update 0x438e90: c += 8, vive mientras c < 0x100; dibujo 0x438eb0);
## - pasos 3-4: esperan a esos objetos y a la voz (objeto 0x401bc0 sin sonido propio).
func _exodia_hand(p: int, duel: Duel) -> Dictionary:
	const PIECES := [0x14, 0x12, 0x10, 0x11, 0x13]
	var q := DuelMem.pl(p) - DuelMem.pl(0)
	var count := duel.m.u8(DuelMem.pl(p) + 2)
	var ghosts: Array = []
	for k in PIECES.size():
		var wanted := duel.cards.index_of(PIECES[k])
		for i in count:
			if (duel.m.u16(0xa11fb8 + q + i * 4) & 0xfff) == wanted:
				ghosts.append({"start": 16 * k, "slot": i, "card": PIECES[k]})
				break
	var frames := 64 + 33
	var d := {"kind": "cmd", "mode": "exodia_hand", "p": p, "ghosts": ghosts, "count": count,
			"center": Vector2(525, 300)}
	if p == 1:
		d["sound_file"] = "yugi_65"
		frames = maxi(frames, PortraitEffects.voice_frames(game, "yugi_65"))
	d["frames"] = frames
	return d


func _render_exodia_hand(frame: int) -> void:
	var p: int = active["p"]
	for g: Dictionary in active["ghosts"]:
		var t := frame - int(g["start"])
		if t < 0 or t >= 31:
			continue
		var c := (t + 1) * 8
		var pos := hand(p, int(g["slot"]), int(active["count"])) + Vector2(0, c / 4 if p == 1 else -c / 4)
		var sprite := _card(int(g["card"]), pos, p == 0, DuelGeometry.HAND_SIZE)
		if sprite != null:
			sprite.modulate.a = (255 - c) / 255.0


static func lp_ticks(amount: int) -> int:
	return amount / 100 + (amount % 100) / 10 + amount % 10

## Posiciones de la mesa que un efecto dibuja por su cuenta (temblor, volteo, activacion...).
## Los movimientos no ocultan nada: el objeto ya no esta en su origen (ver `table`).
func hides(pos: Vector2) -> bool:
	for overlay: Dictionary in overlays:
		if _event_hides(overlay["event"], pos): return true
	if active.get("mode", "") == "battle_result":
		var shake_frame := frame - (32 if active.get("reflection", false) else 0)
		if shake_frame >= 0 and shake_frame < 16:
			for card in active.get("shake_cards", []):
				if pos.distance_to(card["pos"]) < 1: return true
	if active.get("mode", "") == "hand_shuffle" and pos.x >= 230:
		if (active.get("p", 0) == 0 and pos.y >= 527) or (active.get("p", 0) == 1 and pos.y <= 73): return true
	return _event_hides(active, pos)

func _event_hides(event: Dictionary, pos: Vector2) -> bool:
	if event.has("hand_slot"):
		var p: int = event.get("p", 0)
		if pos.distance_to(hand(p, int(event["hand_slot"]), table.hand[p].size())) < 1: return true
	if event.get("mode", "") == "multi":
		for sub: Dictionary in event.get("events", []):
			if _event_hides(sub, pos): return true
	for at in event.get("hide", []):
		if pos.distance_to(at) < 1: return true
	return false

## Transiciones del objeto de batalla segun los eventos (se aplican al encolar).
func _battle_event(kind: String, e: Dictionary, p: int) -> void:
	match kind:
		"battle_stop":
			_battle["state"] = 0
			_battle["zone"] = -1
		"phase":
			if int(e.get("phase", -1)) == 3:
				_battle = {"state": 1, "counter": 0, "p": p, "zone": -1}
			elif _battle["state"] != 0 and _phase_was_battle:
				_battle["state"] = 0
			_phase_was_battle = int(e.get("phase", -1)) == 3
		"battle_cursor":
			if int(_battle["zone"]) < 0:
				_battle["counter"] = 0
			_battle["state"] = 2
			_battle["zone"] = int(e.get("zone", 0))
		"battle_aim":
			_battle["state"] = 3
		"cmd34":
			# 0x402b30: ataque directo, 0x40cc00(atacante) y 0x40cc40(rival, -1) -> estado 4.
			_battle["state"] = 4
			_battle["zone"] = int(e.get("a", 0))
		"cmd":
			match int(e.get("op", 0)):
				0x33, 0x34:
					_battle["state"] = 4
					_battle["zone"] = int(e["args"][0])
				0x56:
					_battle["state"] = 1
					_battle["counter"] = 0
					_battle["zone"] = -1
				0x31:
					_battle["state"] = 6


var _phase_was_battle := false
## Número retenido del objeto de LP por jugador: zona, cantidad e inicio del rebote.
var _lp_number := {}


## Sombreado de pantalla (DAT_005af884, modo 0; FUN_00464490): lo activan el rotulo de inicio
## (0x43d740, se apaga cuando su contador pasa de 0x13f) y el de fin de duelo (0x43d810, se queda).
## Al activarse copia la pantalla oscurecida a la mitad (0x4e2db0 con 0x80) y funde con +0x10 el
## primer fotograma y +0x20 los siguientes hasta 0x100; al apagarse deshace el fundido igual.
var _shade_on := false
## Cartel de fin que queda fijo tras su animacion (la escena de resultado lo retoma).
var end_banner := ""
var _shade_c := 0
## 486290 dibuja el contador de entrada y despues lo incrementa/decrementa.
var _shade_draw_c := 0
var _start_banner_last_draw := false
## Jo44dd00: los objetos de mascara2 solo avanzan con el fundido completamente opaco.
var _start_banner_shade := false
var _start_shade_material := ShaderMaterial.new()


func _tick_shade() -> void:
	_shade_draw_c = _shade_c
	if _shade_on:
		if _shade_c < 0x100: _shade_c = mini(0x100, _shade_c + (0x10 if _shade_c == 0 else 0x20))
	elif _shade_c > 0:
		_shade_c = maxi(0, _shade_c - (0x10 if _shade_c == 0x100 else 0x20))


func _shade_moving() -> bool:
	return _shade_c != (0x100 if _shade_on else 0)


## FUN_0040ccf0 (estado 3): +0x10 por fotograma hasta 0x80.
func _tick_battle() -> void:
	if _battle["state"] == 3 and _battle["counter"] < 0x80:
		_battle["counter"] += 0x10


## FUN_0040ced0: con el objeto activo, atk_icon con alfa 0xa0 sobre cada monstruo del jugador
## que puede atacar (0x571810), salvo el atacante en los estados 3-5; en el estado 3 el del
## atacante gira hacia el raton en proporcion al contador.
func _render_battle() -> void:
	var st: int = _battle["state"]
	if st == 0 or _duel_ref == null:
		return
	var p: int = _battle["p"]
	for i in 5:
		if (_duel_ref.m.u16(DuelMem.zone(p, i)) & 0xfff) == 0:
			continue
		if st >= 3 and st <= 5 and i == int(_battle["zone"]):
			continue
		if hides(zone(p, i)):
			continue
		if _duel_ref.f571810(p, i, 1) != 0:
			BasicEffects._asset(self, "atk_icon", zone(p, i), 0x10000, 0xa0, p << 8)
	if st == 3 and int(_battle["zone"]) >= 0:
		var at := zone(p, int(_battle["zone"]))
		var dir := pointer - at
		var angle := int(atan2(dir.x, -dir.y) * 256.0 / PI)
		BasicEffects._asset(self, "atk_icon", at, 0x10000, 256, (angle * mini(int(_battle["counter"]), 0x80)) / 0x80)


## FUN_004650d0: centro de la zona y 8 estrellas a radio (rand & 31) + 16 cada 64 unidades.
func _new_sacrifice(p: int, z: int, duel: Duel) -> Dictionary:
	var center := zone(p, z)
	var points: Array[Vector2] = []
	for index in 8:
		var radius: int = (PortraitEffects.visual_rand(duel) & 31) + 16
		points.append(center + Vector2((DuelVisualMath.cos_fx(index * 64) * radius) >> 16,
				(DuelVisualMath.cos_fx(index * 64 - 128) * radius) >> 16))
	var defense := z < 5 and (duel.m.u8(DuelMem.zone(p, z) + 6) & 1) != 0
	return {"counter": 0, "rot": 0, "release": false, "center": center, "defense": defense, "points": points}


## FUN_00464b00, un fotograma: +8 salvo si no esta suelto y ya paso de 0x7f; vive hasta 0x180;
## en 0x88 suena el efecto 0x1000000c (ikenie).
func _tick_sacrifice() -> void:
	for key in _sacrifice.keys():
		var s: Dictionary = _sacrifice[key]
		if s["release"] or s["counter"] <= 0x7f:
			s["counter"] += 8
		if s["counter"] == 0x88 and s.get("kind", "") != "fusion":
			Audio.play_sfx("%s/voice/internal/ikenie.wav" % game)
		# 464bb0: la marca de fusion vive mientras su contador < 0x180.
		if s["counter"] >= (0x180 if s.get("kind", "") == "fusion" else 0x181):
			_sacrifice.erase(key)


## FUN_00464fe0: fusion_mark girando sobre el objeto de la carta (posicion actual; nada si la
## carta ya no esta en esa ubicacion), con la misma curva que eff_set_y y alfa base 0xa0.
func _render_fusion_mark(s: Dictionary, duel: Duel) -> void:
	var p: int = s["p"]
	var loc: int = s["loc"]
	var index: int = s["index"]
	if (duel.m.u16(duel.f5419b0(p, loc, index)) & 0xfff) != s["card"]:
		return
	var pos: Vector2
	if loc == 11:
		var count := duel.m.u8(DuelMem.pl(p) + 2)
		pos = hand_positions.get(p * 256 + index, DuelGeometry.hand(p, index, count))
	elif loc == 0 or loc == 5:
		pos = zone(p, loc + index)
	else:
		pos = DuelGeometry.location(p, loc, index)
	var c: int = s["counter"]
	var after := c - 0x80
	var scale := 0x10000
	var alpha := 0xa0
	if after < 0:
		var wave := DuelVisualMath.cos_fx(after)
		s["rot"] += (wave << 2) >> 16
		scale = c << 9
		alpha = (wave * 0xa0) >> 16
	elif after == 0:
		s["rot"] += 4
	else:
		s["rot"] += ((DuelVisualMath.cos_fx(DuelVisualMath.trunc_div(after, 2) - 0x80) << 2) >> 16) + 4
		scale = 0x10000 if after < 0x80 else after * 0x200
		alpha = (DuelVisualMath.cos_fx(DuelVisualMath.trunc_div(after, 2)) * 0xb0) >> 16
	BasicEffects._asset(self, "fusion_mark", pos, scale, alpha, -int(s["rot"]))


## FUN_00464d30: brillo card_pika_h, eff_set_y girando y estrellas eff_star0/1_y.
func _render_sacrifice(s: Dictionary) -> void:
	var c: int = s["counter"]
	var center: Vector2 = s["center"]
	var def_bit := 1 if s["defense"] else 0
	var after := c - 0x80
	if after > 0:
		var alpha := mini(DuelVisualMath.cos_fx(c - 0x100) >> 8, 0xff)
		var angle := def_bit << 7
		var scale := 0x10000
		if after >= 0x80:
			scale = (0x180 - after) * 0x100
			angle = (def_bit - 3) * 0x80 + after * 3
			BasicEffects._asset(self, "card_pika_h", center, scale, alpha / 2, angle - DuelVisualMath.trunc_div(c - 0x100, 2))
		BasicEffects._asset(self, "card_pika_h", center, scale, alpha, angle)
	var set_scale := 0x10000
	var set_alpha := 0x80
	if after < 0:
		var wave := DuelVisualMath.cos_fx(after)
		s["rot"] += (wave << 2) >> 16
		set_scale = c << 9
		set_alpha = (wave << 7) >> 16
	elif after == 0:
		s["rot"] += 4
	else:
		s["rot"] += ((DuelVisualMath.cos_fx(DuelVisualMath.trunc_div(after, 2) - 0x80) << 2) >> 16) + 4
		set_scale = 0x10000 if after < 0x80 else after * 0x200
		set_alpha = (DuelVisualMath.cos_fx(DuelVisualMath.trunc_div(after, 2)) * 0xb0) >> 16
	BasicEffects._asset(self, "eff_set_y", center, set_scale, set_alpha, -int(s["rot"]))
	if after > 0:
		var star_alpha := mini(DuelVisualMath.cos_fx(c - 0x100) >> 8, 0xff)
		var e := after
		for point: Vector2 in s["points"]:
			if e >= 0:
				var t := DuelVisualMath.trunc_div(e, 8)
				BasicEffects._asset(self, "eff_star%d_y" % (t & 1), point - Vector2(0, DuelVisualMath.trunc_div(t * t, 16)), 0x10000, star_alpha)
			e -= 0x10


func advance(delta: float) -> void:
	_visual_clock += NativeClock.ticks(maxf(delta, 0))
	var elapsed := int(_visual_clock)
	if elapsed > 0: _start_banner_last_draw = false
	_visual_clock -= elapsed
	visual_tick += elapsed
	var field_tick := visual_tick - elapsed
	_clock += NativeClock.ticks(maxf(delta, 0))
	while _clock >= 1 and (not active.is_empty() or not pending.is_empty() or not overlays.is_empty() or not _sacrifice.is_empty() or _battle["state"] != 0 or _shade_moving() or _chains_busy()):
		_clock -= 1
		if field_tick < visual_tick:
			field_tick += 1
			if native_field_tick.is_valid(): native_field_tick.call(field_tick)
		_tick_sacrifice()
		_tick_battle()
		var start_shade_moving := _start_banner_shade and _shade_moving()
		# 44dd00 actualiza/dibuja la mascara2 antes de486290. En T320 el
		# objeto apaga el sombreado y el mismo tick inicia su cierre256->240.
		var shade_after_object := _start_banner_shade and not start_shade_moving
		if not shade_after_object: _tick_shade()
		if _start_banner_shade and not _shade_on and _shade_c == 0:
			_start_banner_shade = false
			_start_banner_last_draw = true
		if active.get("mode", "") == "sacrifice_release":
			# 464ae0 libera la espera al llegar a248; 464b00 conserva el dibujo hasta384.
			var mark: Dictionary = _sacrifice.get(active["key"], {})
			if mark.is_empty() or int(mark["counter"]) >= (0xf8 if game == "yugi" else 0x181):
				active["frames"] = frame
		_tick_chains()
		if active.get("mode", "") == "chain_wait" and not _chains_busy():
			active["frames"] = frame
		if active.get("mode", "") == "marker_wait" and not _markers_busy():
			active["frames"] = frame
		for i in range(overlays.size() - 1, -1, -1):
			overlays[i]["frame"] += 1
			if overlays[i]["frame"] >= overlays[i]["event"]["native_lifetime"]: overlays.remove_at(i)
		if active.is_empty(): continue
		if start_shade_moving: continue
		frame += 1
		# Simular el dibujo nativo de cada tick aunque delta agrupe varios ticks.
		if active.get("mode", "") == "exodia": SpecialEffects.exodia_particles(active, frame)
		if active.get("mode", "") == "joey_summon": PortraitEffects.tick_joey_summon(active)
		# 0x439a70: el rotulo de inicio apaga el sombreado cuando su contador (+8) pasa de 0x13f.
		if active.get("mode", "") == "banner" and int(active.get("op", 0)) == 0x14 and frame * 8 > 0x13f:
			_shade_on = false
		if shade_after_object: _tick_shade()
		if active.get("mode", "") == "lp_total" and frame > int(active.get("count_delay", 32)):
			var p: int = active["p"]
			var left := int(active["remaining_amount"])
			var step := 100 if absi(left) >= 100 else 10 if absi(left) >= 10 else 1
			var change := mini(step, absi(left)) * signi(left)
			active["remaining_amount"] = left - change
			displayed_lp[p] = maxi(0, int(displayed_lp[p]) + change)
		if _active_finished():
			_finish_objects()
			# 0x43a970: el movimiento del comando 0x84 suena equip.wav al llegar a 0xc0.
			if active.get("kind", "") == "cmd84":
				Audio.play_sfx("%s/voice/internal/equip.wav" % game)
			if active.has("native_lifetime"):
				overlays.append({"event": active.duplicate(true), "frame": frame})
			_finish_music()
			if active.get("mode", "") == "joey_summon":
				var exit := active.duplicate()
				exit["mode"] = "joey_summon_exit"
				exit["frames"] = 9 # 486290:256,240,208,...16; despues restaura el tablero.
				for key in ["sound", "music_once"]: exit.erase(key)
				pending.push_front(exit)
			# El cartel de fin (0x43d810) sigue dibujandose opaco hasta el cambio de escena.
			if active.get("mode", "") == "banner" and int(active.get("op", 0)) == 0x04:
				end_banner = String(active.get("asset", ""))
			active.clear()
			_clear()
			_begin()
	if active.is_empty() and pending.is_empty() and overlays.is_empty() and _sacrifice.is_empty() and _battle["state"] == 0 and not _shade_moving(): _clock = 0
	# El terreno sigue animandose cuando la presentacion no tiene un objeto activo.
	while field_tick < visual_tick:
		field_tick += 1
		if native_field_tick.is_valid(): native_field_tick.call(field_tick)
	follow_memory()
	_render_frame()


## Sin animacion en curso, la tabla adopta lo que el motor cambio sin evento (ver
## DuelCardTable.follow_memory).
func follow_memory() -> void:
	if _duel_ref == null or not active.is_empty() or not pending.is_empty(): return
	var rest := at_rest or _phase_rest
	# Una zona retenida deja de estarlo cuando otra carta la ocupa en memoria.
	for key in _field_detached.keys():
		var parts: PackedStringArray = String(key).split(":")
		var index := _duel_ref.m.u16(DuelMem.zone(int(parts[0]), mini(int(parts[1]), 10))) & 0xfff
		# 405020 mueve el objeto antes de limpiar STATE en el siguiente paso.
		# La misma carta aun presente no equivale a un nuevo ocupante.
		if index != 0 and _duel_ref.cards.id_of(index) != int(_field_detached[key]): _field_detached.erase(key)
	table.follow_memory(_duel_ref, rest, _field_detached)
	if rest: _phase_rest = false


## 401c60 y 40e920 consultan el audio real; el contador no sustituye esa consulta.
func _active_finished() -> bool:
	# 451980/43a1b0: el objeto desaparece en T320; el sombreado conserva su espera.
	if game in ["kaiba", "joey"] and active.get("mode", "") == "banner" and int(active.get("op", 0)) == 0x14: return frame >= 40
	if active.get("mode", "") == "joey_summon": return int(active["counter"]) > 0x1005f
	if active.has("native_turn"):
		DuelCardTable.field_turn_at(active.native_turn, frame)
		return not DuelCardTable.field_turn_busy(active.native_turn)
	if active.get("wait_voice", false):
		var path: String = active.get("sound", "%s/voice/internal/%s.wav" % [game, active.get("sound_file", "")])
		if active.get("mode", "") == "portrait_native":
			if frame < 33: return false
			if active.has("sound_after"):
				if not active.get("sound_after_played", false): return false
				path = active["sound_after"]
		return Audio.sfx_finished(path)
	return frame >= active.get("frames", 0)


# --- objetos de la mesa (0x414190, 0x410030, 0x4135f0) -------------------------------------

## Cara que se ve de un objeto en una ubicacion: bit 15 de su palabra. En la mano lo fija
## 0x4135f0 con 0x5450e0 (la del rival, oculta); mazo y mazo de fusion boca abajo.
func _shown_face(p: int, loc: int, obj: Dictionary) -> bool:
	if loc == DuelMem.LOC_HAND: return not (hidden_hand and p == 1)
	if loc in [DuelMem.LOC_DECK, DuelMem.LOC_FUSION]: return false
	if loc in [DuelMem.LOC_GRAVE, DuelMem.LOC_BANISH]: return true
	return bool(obj.get("face", true))


static func _word_loc(word: int) -> Array:
	return [word & 1, (word >> 1) & 15, (word >> 5) & 511]


## Al empezar un movimiento el objeto sale del origen y queda en el destino (o en el hueco de
## vuelo de la pila) marcado como en movimiento: la mesa no lo dibuja y lo dibuja el evento.
func _begin_objects() -> void:
	if _duel_ref == null: return
	var mode: String = active.get("mode", "")
	if mode in ["move", "exclusion"] and active.has("src"):
		var src: Array = active["src"]
		var dst: Array = active["dst"]
		# Las referencias del buzon consultan45c140 antes de sacar el objeto.
		# Resolver al comenzar, no al encolar: otros vuelos pueden cambiar la pila.
		if src[1] in [12, 13, 14]: active["from_pos"] = pile_object_position(src[0], src[1], src[2])
		if dst[1] in [12, 13, 14]: active["to_pos"] = pile_object_position(dst[0], dst[1], dst[2])
		if active.get("instant", false): active["from_pos"] = active["to_pos"]
		_field_detached.erase("%d:%d" % [src[0], src[1] + (src[2] if src[1] in [0, 5] else 0)])
		var obj := table.take(_duel_ref, src[0], src[1], src[2])
		if obj.is_empty() or int(obj.get("card", -1)) < 0:
			if int(active.get("card", -1)) in [-1, 0xffff]:
				# Sin objeto ni carta (salida repetida tras vaciar la zona): nada que mover.
				active["frames"] = 0
				return
			obj = {"card": int(active["card"]), "face": not active.get("hidden", false), "defense": false, "owner": src[0]}
		# El mazo se dibuja boca abajo: su imagen no se conoce; la carta es la del evento.
		if src[1] in [DuelMem.LOC_DECK, DuelMem.LOC_FUSION] and not int(active.get("card", -1)) in [-1, 0xffff]:
			obj["card"] = int(active["card"])
		active["card"] = int(obj["card"])
		var dst_loc: int = dst[1]
		if dst_loc in DuelCardTable.PILES and int(obj["card"]) >= 0x780 and int(obj["card"]) < 2000:
			# 407cb0: una ficha que va a una pila no se mueve; 413a40 borra su objeto.
			active["frames"] = 0
			return
		var face_to: bool
		# El bit 15 de la palabra de destino solo decide en el campo: en la mano manda 5450e0
		# (4135f0) y el cementerio y las excluidas se ven boca arriba.
		if active.has("dst_face") and dst[1] < 11: face_to = active["dst_face"]
		elif dst_loc in [DuelMem.LOC_GRAVE, DuelMem.LOC_BANISH, DuelMem.LOC_HAND]: face_to = true
		elif dst_loc in [DuelMem.LOC_DECK, DuelMem.LOC_FUSION]: face_to = false
		else: face_to = bool(obj.get("face", true))
		var defense: bool = active.get("dst_defense", dst_loc < 5 and bool(obj.get("defense", false)))
		var placed := {"card": int(obj["card"]), "face": face_to, "defense": defense, "owner": obj.get("owner", src[0]), "moving": true}
		active["face_from"] = _shown_face(src[0], src[1], obj)
		active["face_to"] = _shown_face(dst[0], dst_loc, placed)
		if active.get("instant", false): active["face_from"] = active["face_to"]
		active["placed"] = placed
		table.place(dst[0], dst_loc, dst[2], placed)
	elif mode in ["flip", "change_position"]:
		var obj: Dictionary = table.field[active["p"]][clampi(int(active.get("zone", 0)), 0, 10)]
		if not obj.is_empty():
			active["card"] = int(obj["card"])
			active["flags"] = int(obj["defense"]) | (int(obj["face"]) << 1)
			if active.has("native_target_flags"):
				var turn := DuelCardTable.field_turn(int(active.flags), int(active.native_target_flags), int(active.p))
				active["native_turn"] = turn
				obj["native_turn"] = turn
				var estimate: Dictionary = turn.duplicate()
				while DuelCardTable.field_turn_busy(estimate): DuelCardTable.field_turn_tick(estimate)
				active["frames"] = int(estimate.tick)
			obj["moving"] = true
			active["placed"] = obj


## Al terminar: el objeto queda en reposo; en una pila suma la carta y cambia la imagen.
func _finish_objects() -> void:
	if _duel_ref == null: return
	var mode: String = active.get("mode", "")
	var placed: Dictionary = active.get("placed", {})
	placed.erase("moving")
	if mode == "pile_top":
		table.piles[active.p][active.loc]["top"] = int(active.card)
		table.revision += 1
	elif mode in ["move", "exclusion"] and active.has("dst"):
		var dst: Array = active["dst"]
		if dst[1] in DuelCardTable.PILES:
			table.land(dst[0], dst[1], dst[1] != DuelMem.LOC_DECK or int(dst[2]) == 0)
	elif active.has("native_turn") and not placed.is_empty():
		var flags: int = int(active.native_turn.target)
		placed["face"] = (flags & 2) != 0
		placed["defense"] = (flags & 1) != 0
		placed.erase("native_turn")
	elif mode == "flip" and not placed.is_empty():
		placed["face"] = not bool(placed["face"])
	elif mode == "change_position" and not placed.is_empty():
		placed["defense"] = not bool(placed["defense"])
		if active.get("b", 0) != 0: placed["face"] = true
	elif mode == "zone_swap":
		var a: int = active["a"]
		var b: int = active["b"]
		var za := mini((a >> 8) & 255, 10)
		var zb := mini((b >> 8) & 255, 10)
		var tmp: Dictionary = table.field[a & 1][za]
		table.field[a & 1][za] = table.field[b & 1][zb]
		table.field[b & 1][zb] = tmp
	elif mode == "special" and active.get("kind", "") == "special_summon" and not active.get("object_placed", false):
		_place_special(active)

	elif mode == "summon" and active.get("kind", "") in ["token", "monster_appear"]:
		# 0xa5 / 0x77: el objeto se crea en la zona al terminar el efecto (tipo 5).
		var z := clampi(int(active.get("zone", 0)), 0, 10)
		var face := true
		var defense := false
		if active.get("kind", "") == "token":
			face = int(active.get("face", 1)) != 0
			defense = int(active.get("pos", 0)) != 0
		else:
			face = (int(active.get("a", 0)) & 0x100) != 0
			defense = (int(active.get("a", 0)) & 0x200) != 0
		table.field[active["p"]][z] = {"card": int(active.get("card", 0)), "face": face, "defense": defense, "owner": active["p"]}


func _place_special(event: Dictionary) -> void:
	# 0x405d10 paso 3: el objeto pasa al instante de su origen a la zona (tipo 4).
	var a: int = event.get("a", 0)
	var obj := table.take(_duel_ref, event["p"], a & 0xf, (a & 0xff) >> 4)
	# Conserva su propietario (bit 12): una carta del rival revivida sigue siendo suya.
	obj = {"card": int(event.get("card", obj.get("card", 0))), "face": (a & 0x100) != 0,
			"defense": (a & 0x200) != 0, "owner": int(obj.get("owner", event["p"]))}
	table.place(event["p"], (a >> 12) & 15, 0, obj)


func _begin() -> void:
	if pending.is_empty(): return
	active = pending.pop_front()
	frame = 0
	_begin_objects()
	if active["mode"] == "sacrifice_release":
		if _sacrifice.has(active["key"]): _sacrifice[active["key"]]["release"] = true
	var mode: String = active["mode"]
	# 5bc700 consume el buzon antes de44dd00->45d040. La carta creada por
	# 40cdb0 recibe418b60 (+32) en esa misma vuelta, antes del primer dibujo.
	# Los eventos del adaptador ya llegan despues de avanzar el reloj visual.
	if game == "joey" and mode == "move" and active.get("native_silent", false) and not active.get("instant", false):
		frame = 1
	if mode == "joey_summon" and DisplayServer.get_name() != "headless":
		var snapshot: Texture2D = preload("res://core/native_snapshot.gd").capture(get_viewport())
		if snapshot != null: active["snapshot"] = snapshot
	played[mode] = played.get(mode, 0) + 1
	if mode == "lp_total": displayed_lp[active["p"]] = active["from"]
	# FUN_0040ccf0 -> FUN_0045d840(-dano, zona, 1): el numero del objeto de LP de cada jugador
	# se queda sobre la carta del combate; el comando de LP (0x404270) no lo mueve mientras esta
	# retenido (+0x30) y lo descuenta alli mismo.
	if mode == "battle_result" and active.has("damage"):
		active["draw_damage"] = false # El objeto de LP conserva las cifras entre comandos.
		for side in 2:
			if int(active["damage"][side]) == 0: continue
			var z: int = active["source_zone"] if side == active["p"] else active["target_zone"]
			if active.get("native_impact", false) and (int(active["result_flags"][side]) & 0x18) != 0: z = -1
			_lp_number[side] = {"zone": -1 if int(active["target_zone"]) == -1 else z,
				"amount": -int(active["damage"][side]), "start": visual_tick + (32 if active.get("reflection", false) else 0)}
	var settled := false
	if mode == "lp_total":
		active["number_zone"] = _lp_number.get(active["p"], {}).get("zone", -1)
		settled = _lp_number.has(active["p"])
		active["settled"] = settled
		# 45d840 conserva el popup retenido del combate; 45d750 cuenta el daño
		# completo aunque los LP lleguen a cero antes de terminar el descuento.
		active["remaining_amount"] = int(_lp_number[active["p"]]["amount"]) if settled else int(active.get("amount", int(active["to"]) - int(active["from"])))
		# 45d750 solo descuenta cuando +0x34 (+8 por tick desde que se fija la cifra) llega a
		# 0x100: la cifra del combate ya lleva ese tiempo a la vista y empieza a contar en el acto.
		var delay := int(active.get("count_delay", 32))
		if settled and not active.has("count_delay"): delay = clampi(32 - (visual_tick - int(_lp_number[active["p"]].get("start", visual_tick))), 0, 32)
		active["count_delay"] = delay
		active["frames"] = delay + lp_ticks(absi(int(active["remaining_amount"])))
		_lp_number.erase(active["p"])
	var sound: String = {"move": "card_move", "flip": "card_open", "change_position": "card_move", "shuffle": "card_move", "summon": "card_open", "set": "card_move", "special": "reborn", "destroy_effect": "card_normal_brake", "explosion": "card_attacked_brake", "card_effect": "magic_active", "attack": "attack", "chain": "chain", "coin": "coin", "dice": "dice", "next_turn": "turn_change", "banner": "start", "exodia": "exodia_a", "fusion": "fusion1"}.get(mode, "")
	if mode == "fusion" and game == "kaiba": sound = "" # Sin fusion1 en 43f2c0.
	if mode == "set": sound = "" # Y43e280/Ka43e9b0: el constructor no reproduce audio.
	if mode == "move" and int(active.get("frames", 0)) == 0: sound = "" # Sin objeto que mover.
	if mode == "move" and active.get("instant", false): sound = "" # 414810 no suena.
	if mode == "exodia" and game == "joey": sound = "" # Jo453b60 no pide exodia_a.
	if mode == "lp_total": sound = "" if settled else "life_up" if active["to"] > active["from"] else "damage"
	if mode == "battle_result" and active.has("damage"):
		# 40ccf0, estado7: damage.wav tambien suena con flags&6 aunque no se pierdan LP.
		# Con reflejo, el impacto espera los32 ticks del estado6 antes de la sacudida.
		var hit: bool = not active.get("shake_cards", []).is_empty()
		var damage := int(active["damage"][0]) != 0 or int(active["damage"][1]) != 0
		if hit or damage:
			active["sounds"] = [[32 if active.get("reflection", false) else 0, "%s/voice/internal/damage.wav" % game]]
	if mode == "banner":
		_shade_on = true
		# Joey 451b80 (fin) prepara el sombreado de 5f3400 igual que 4516a0 (inicio): el cartel
		# espera a que se abra desde el centro (cotejo del duelo normal, 26-10-2026).
		if (game in ["kaiba", "joey"] and int(active.get("op", 0)) == 0x14) or (game == "joey" and int(active.get("op", 0)) == 0x04):
			_start_banner_shade = true
			# 44dd00 llama486290 despues de crear el objeto: captura y primer paso16.
			_tick_shade()
		if int(active.get("op", 0)) == 0x04:
			# 0x43d810: con el sombreado suena 0x20000008 (j_win, resultado 0) o 0x20000009 (j_lose).
			sound = ""
			# Kaiba y Joey: m_win / m_lose (ids 0xa/0xb y 9/0xa de sus tablas).
			var win := int(active.get("args", [0])[0]) == 0
			var track := ("j_win" if win else "j_lose") if game == "yugi" else ("m_win" if win else "m_lose")
			Audio.play_music("%s/voice/stream/%s.wav" % [game, track], false)
	if active.get("native_silent", false): sound = ""
	if sound != "": Audio.play_sfx("%s/voice/internal/%s.wav" % [game, sound])
	if active.get("sound_file", "") != "": Audio.play_sfx("%s/voice/internal/%s.wav" % [game, active["sound_file"]])
	if mode == "music" and _restore_music == "":
		Audio.play_music(active["music"])
	if active.get("music_once", "") != "": Audio.play_music(active["music_once"], false)
	if mode in ["summon_portrait", "blueeyes_portrait", "gofu_portrait"]:
		_restore_music = Audio.music_path()
		Audio.play_music(active["sound"])
	elif active.get("sound", "") != "": Audio.play_sfx(active["sound"])
	_render_frame()

## Archivo de voice/internal de una voz que el nucleo (el de Yugi) pide con su id de la tabla
## 0x5ad3d0. Solo para los sitios comprobados en el ejecutable de cada juego (ver "voice").
func voice_file(id: int) -> String:
	var n := (id & 0xffff) - 0x1e
	if n < 0: return ""
	match game:
		"yugi": return "yugi_%02d" % (n + 1)
		"kaiba": return "ka%02d" % (n + 1)
		"joey": return "joey_%02d" % (n + 1)
	return ""

func _finish_music() -> void:
	if active.get("mode", "") == "joey_summon" and _duel_ref != null:
		Audio.play_music(load("res://scenes/duel/duel_music.gd").path(game, _duel_ref.game_mode if _duel_ref.game_mode != 0 else Game.duel_mode, [displayed_lp[0], displayed_lp[1]]))
	if active.get("mode", "") in ["summon_portrait", "blueeyes_portrait", "gofu_portrait"]:
		Audio.stop_music()
		if _restore_music != "": Audio.play_music(_restore_music)
	_restore_music = ""

func _clear() -> void:
	for node in get_children(): node.free()

func _asset(name: String, center: Vector2, scale_factor: float = 1.0, alpha: float = 1.0, rotation_value: float = 0.0, folder: String = "effect") -> Sprite2D:
	var path := "%s/duel/%s/%s.png" % [game, folder, name]
	var texture := Assets.texture(path)
	if texture == null: return null
	var sprite := Sprite2D.new()
	sprite.texture = texture
	# Las espadas nativas impares evitan suavizar texeles vecinos al centrarse.
	if name in ["atk_icon", "atk_icon2"]:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = center
	sprite.scale = Vector2.ONE * maxf(0.001, scale_factor)
	sprite.modulate.a = clampf(alpha, 0, 1)
	sprite.rotation = rotation_value
	add_child(sprite)
	return sprite

func _card(id: int, pos: Vector2, face: bool, size: Vector2 = SIZE, angle: float = 0.0) -> Sprite2D:
	var sprite := Sprite2D.new()
	# Muestrear el arte completo una sola vez al tamaño final, también durante el vuelo.
	sprite.texture = CardDB.card_texture(id) if face and id >= 0 else Assets.texture("common/card/card_ura.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if sprite.texture == null:
		sprite.free()
		return null
	sprite.position = pos
	sprite.scale = size / sprite.texture.get_size()
	sprite.rotation = angle
	add_child(sprite)
	return sprite

static func _rotation_between(source: float, target: float, counter: int) -> float:
	var src := roundi(source * 512 / TAU) & 511
	var dst := roundi(target * 512 / TAU) & 511
	if src == dst: return dst * TAU / 512.0
	var offset := counter if (src ^ dst) == 256 else counter / 2 if ((dst - src) & 511) <= 256 else -(counter / 2)
	return ((src + offset) & 511) * TAU / 512.0

func _render_frame() -> void:
	_render()
	_interpolate()


## Quien avanza la presentacion por ticks enteros (repeticiones, demostraciones, lecciones) la
## dibuja entre ticks con su propio reloj: `fraction` es lo que le queda hasta el siguiente.
func show_between(fraction: float) -> void:
	_visual_clock = clampf(fraction, 0.0, 0.999999)
	_render_frame()


## Lo que le queda hasta el siguiente tick (visual_tick).
func between() -> float:
	return _visual_clock


func _snapshot() -> Array:
	var out := []
	_snapshot_children(self, out)
	return out


## Sprites y poligonos (carta girada de los retratos, destellos, mascaras); los sprites dentro
## de una mascara (destellos del retrato) van en coordenadas de la mascara.
func _snapshot_children(parent: Node, out: Array) -> void:
	for node in parent.get_children():
		if node is Sprite2D:
			# Una region es otra pieza: los trozos de una carta rota comparten textura. Una pieza
			# animada por fotogramas (marcas de cadena) lleva su propia clave: su textura cambia
			# cada tick y otra igual, un tick mas joven, la heredaria.
			var piece: Variant = node.texture
			if node.has_meta("blend_key"): piece = node.get_meta("blend_key")
			elif node.region_enabled: piece = [node.texture, node.region_rect]
			out.append([node, piece, node.position, node.scale, node.rotation, node.modulate.a])
		elif node is Polygon2D:
			out.append([node, ["polygon", node.texture, node.polygon.size()], node.position, node.polygon, node.color])
			_snapshot_children(node, out)


## Dibuja el tick anterior mezclado hacia el actual (un tick de retraso, como la interpolacion
## fisica de Godot). Cada sprite se empareja con el del tick anterior de la misma textura que
## estaba mas cerca, sin repetir: el orden de los sprites cambia cuando una carta se destruye o
## llega al cementerio, y emparejar por orden deslizaba una carta hasta la zona de otra.
## Lo que no tiene pareja se dibuja como en el tick actual.
func _interpolate() -> void:
	var cur := _snapshot()
	if visual_tick != _snap_tick:
		_snap_prev = _snap_cur
		_snap_tick = visual_tick
	_snap_cur = cur
	var t := clampf(_visual_clock, 0.0, 1.0)
	if not NativeClock.interpolate or _snap_prev.is_empty() or t >= 1.0:
		return
	for pair in _pairs(_snap_prev, cur):
		var a: Array = _snap_prev[pair[0]]
		var b: Array = cur[pair[1]]
		if b[0] is Polygon2D:
			var polygon: Polygon2D = b[0]
			polygon.position = (a[2] as Vector2).lerp(b[2], t)
			var points := PackedVector2Array()
			for k in (b[3] as PackedVector2Array).size():
				points.append((a[3][k] as Vector2).lerp(b[3][k], t))
			polygon.polygon = points
			polygon.color = (a[4] as Color).lerp(b[4], t)
			continue
		var sprite: Sprite2D = b[0]
		sprite.position = (a[2] as Vector2).lerp(b[2], t)
		sprite.scale = (a[3] as Vector2).lerp(b[3], t)
		sprite.rotation = lerp_angle(a[4], b[4], t)
		sprite.modulate.a = lerpf(a[5], b[5], t)


## Parejas [indice anterior, indice actual] con la misma textura; cada sprite se usa una vez.
## Ver NativeBlend.pairs.
static func _pairs(prev: Array, cur: Array) -> Array:
	return NativeBlend.pairs(prev, cur)


func _render() -> void:
	_clear()
	var start_shade_draw := _start_banner_shade or _start_banner_last_draw
	var shade_progress := _shade_draw_c if start_shade_draw else _shade_c
	# La ilustracion exterior vive en otro viewport; comparte el estado del dibujo.
	var margin_alpha := 0.5 * shade_progress / 256.0
	if active.get("mode", "") in ["fusion", "exodia"]: margin_alpha = 1.0 - (1.0 - margin_alpha) * 0.5
	background_shade_changed.emit(margin_alpha, shade_progress if start_shade_draw else -1)
	if shade_progress > 0:
		var shade := ColorRect.new()
		shade.size = Vector2(800, 600)
		shade.color = Color(0, 0, 0, 0.5 * shade_progress / 256.0)
		if start_shade_draw:
			_start_shade_material.shader = StartShade.SHADER
			_start_shade_material.set_shader_parameter("progress", shade_progress)
			shade.material = _start_shade_material
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
	if end_banner != "":
		BasicEffects._asset(self, end_banner, Vector2(400, 300))
	_render_chains()
	_render_battle()
	for key in _sacrifice:
		if _sacrifice[key].get("kind", "") == "fusion":
			if _duel_ref != null: _render_fusion_mark(_sacrifice[key], _duel_ref)
		else:
			_render_sacrifice(_sacrifice[key])
	for overlay in overlays:
		if overlay["event"].get("mode", "") == "phase_native":
			PortraitEffects.render(self, overlay["event"], overlay["frame"])
		else:
			BasicEffects.render(self, overlay["event"], overlay["frame"])
	for p in _lp_number:
		var number: Dictionary = _lp_number[p]
		var progress := (visual_tick - int(number["start"])) * 16
		if progress < 0: continue
		var z: int = number["zone"]
		BasicEffects._damage_number(self, number["amount"], zone(p, z) if z >= 0 else zone(p, 7), progress)
	# El comando 0x95 solo espera al efecto de sacrificio, que ya se ha dibujado arriba.
	if active.is_empty() or active["mode"] == "sacrifice_release": return
	if active["mode"] == "multi":
		for sub: Dictionary in active["events"]: BasicEffects.render(self, sub, frame)
		return
	# Sonidos con fotograma propio de los efectos ("sounds": [[fotograma, wav]]), p. ej. fusion.
	if active.has("sounds"): PortraitEffects._timed_sounds(active, frame)
	if active["mode"] == "exodia_hand":
		_render_exodia_hand(frame)
		return
	if SpecialEffects.render(self, active, frame): return
	if BasicEffects.render(self, active, frame): return
	if FieldEffects.render(self, active, frame): return
	if active["mode"] in ["portrait_native", "phase_native", "next_turn", "summon_portrait", "blueeyes_portrait", "gofu_portrait", "joey_summon", "joey_summon_exit"]:
		var before := get_child_count()
		PortraitEffects.render(self, active, frame)
		if active["mode"] == "portrait_native":
			# Retrato de reaccion 0x40f780: prioridad 0xf01 (0x40f80d), por encima del indicador
			# de LP (0x45dc60, 0x180) que dibuja las cifras de dano (capa 100 aqui).
			for i in range(before, get_child_count()):
				var node := get_child(i)
				if node is CanvasItem: (node as CanvasItem).z_index = PORTRAIT_Z
		return
	var mode: String = active["mode"]
	var t := clampf(float(frame) / active["frames"], 0, 1)
	var center: Vector2 = active["center"]
	match mode:
		"zone_marker_joey":
			# 449850: dos marcas contrarrotando con el reloj global de dibujo.
			if frame < 15 and ((frame + 1) & 2) != 0:
				BasicEffects._asset(self, "chinka_mark2", center, 65536, 256, -4 * visual_tick)
				BasicEffects._asset(self, "chinka_mark1", center, 65536, 256, -8 * visual_tick)
		"move":
			var from: Vector2 = active["from_pos"]
			var to: Vector2 = active["to_pos"]
			var size_from: Vector2 = active["from_size"]
			var size_to: Vector2 = active["to_size"]
			if active.get("kind", "") == "cmd84":
				var counter := frame * 8
				var scale_fx := (DuelVisualMath.trunc_div(DuelVisualMath.cos_fx(counter - 128 if counter < 128 else (counter - 128) * 2), 256) + 256) * 64
				var transfer := 0 if counter < 128 else (counter - 128) * 4
				_card(active.get("card", 0), DuelVisualMath.interpolate(from, to, transfer), true, Vector2(200, 290) * scale_fx / 65536.0, PI if (active.get("a", 0) & 1) else 0)
				return
			var weight := DuelVisualMath.cos_fx(mini(frame * 32, 256) / 2 - 128)
			var angle_from: float = active.get("from_angle", PI if active.get("p", 0) == 1 else 0)
			var angle_to: float = active.get("to_angle", angle_from)
			var counter := mini(frame * 32, 256)
			var face: bool = not active.get("hidden", false)
			var squeeze := 1.0
			if active.has("face_from"):
				# 410030: con cara distinta en origen y destino, +0x48 = contador (hacia boca
				# arriba) o 0x100 - contador; 410ca0 dibuja el dorso por debajo de 0x80 y estrecha
				# la carta en horizontal por T[+0x48].
				var flip := counter if bool(active["face_to"]) else 0x100 - counter
				if bool(active["face_from"]) == bool(active["face_to"]): flip = 0x100 if bool(active["face_to"]) else 0
				face = flip >= 0x80
				if bool(active["face_from"]) != bool(active["face_to"]):
					squeeze = absf(DuelVisualMath.cos_fx(flip) / 65536.0)
			var moving := _card(active.get("card", 0), DuelVisualMath.interpolate_fx(from, to, weight), face, size_from.lerp(size_to, t), _rotation_between(angle_from, angle_to, counter))
			if moving:
				moving.z_index = 20
				moving.scale.x *= maxf(squeeze, 0.001)
		"zone_swap":
			var from: Vector2 = active["from_pos"]
			var to: Vector2 = active["to_pos"]
			for i in 2:
				var card: Dictionary = active["cards"][i]
				var weight := DuelVisualMath.cos_fx(frame * 16 - 128)
				var pos := DuelVisualMath.interpolate_fx(from, to, weight) if i == 0 else DuelVisualMath.interpolate_fx(to, from, weight)
				_card(card["id"], pos, (card["flags"] & 2) != 0, SIZE, (PI if card["p"] == 1 else 0) + (PI / 2 if (card["flags"] & 1) else 0))
		"flip", "change_position":
			if active.has("native_turn"):
				var turn: Dictionary = active.native_turn
				DuelCardTable.field_turn_at(turn, frame)
				var phase: int = int(turn.face_phase)
				var folded := 256 - phase if phase > 128 else phase
				var card := _card(active.card, center, phase >= 128, SIZE, int(turn.angle) * TAU / 512.0)
				if card: card.scale.x *= float(DuelVisualMath.cos_fx(folded)) / 65536.0
				return
			var flags: int = active["flags"]
			var angle := PI / 2 if (flags & 1) else 0.0
			if active.get("p", 0) == 1: angle += PI
			if mode == "change_position":
				_card(active["card"], center, (flags & 2) != 0 or active.get("b", 0) != 0, SIZE, _rotation_between(angle, angle + (PI / 2 if (flags & 1) == 0 else -PI / 2), frame * 32))
			else:
				var sprite := _card(active["card"], center, ((flags & 2) != 0) if t < 0.5 else ((flags & 2) == 0), SIZE, angle)
				if sprite: sprite.scale.x *= absf(DuelVisualMath.cos_fx(mini(frame * 32, 256))) / 65536.0
		"card_blink":
			_draw_card_blink(active, 0x100 - frame * 16)
		"chain_disable":
			_asset("cha_mukou%d" % ((frame / 2) % 6 + 1), center, 1.0, 1.0, PI / 2 if active.get("defense", 0) else 0.0, "chain")
		"lp_total":
			_draw_lp_amount(active["p"], int(active["remaining_amount"]))

## FUN_0045d890 (primer bloque): la cantidad pendiente del cambio de LP (+0x28) sobre la
## ubicacion 5, posicion 2 del jugador (0x442130), con damage00 (resta, cuadro 6 de
## duel/font/number.txt) o damage01 (suma, cuadro 7): 12 glifos de 16 x 40, signo + (10) o - (11)
## a la izquierda; centrada en x y en y; va bajando con los LP (FUN_0045d750) hasta 0.
## Tras un combate se queda sobre la carta (zona retenida en _lp_number).
func _draw_lp_amount(p: int, amount: int) -> void:
	if amount == 0:
		return
	# FUN_00460790 con +0x34 * 2 (+0x34 sube 8 por fotograma hasta 0x100): rebote de las cifras;
	# si viene del combate ya ha rebotado y se dibuja quieto.
	var z: int = active.get("number_zone", -1)
	var center := zone(p, z) if z >= 0 else zone(p, 7)
	BasicEffects._damage_number(self, amount, center, 512 if active.get("settled", false) else frame * 16)

func _render_chains() -> void:
	for n in _chain:
		_draw_chain(_chain[n], int(_chain[n]["counter"]))


## 415150: +4 por tick hasta 0x80 (entrada) y ahi se queda; suelto, sigue hasta 0xc0 y muere.
func _tick_chains() -> void:
	for n in _chain.keys():
		var c: Dictionary = _chain[n]
		if c["released"] or int(c["counter"]) < 0x80: c["counter"] = int(c["counter"]) + 4
		if int(c["counter"]) >= 0xc0: _chain.erase(n)


## 410ca0, estado 1: con el bit 5 del contador, copia de la carta sumando luz (vtable +0xac,
## alfa 0x40) y el marco card_waku (#s propio, #s2 del rival; tumbado en defensa).
func _draw_card_blink(e: Dictionary, counter: int) -> void:
	if counter <= 0 or ((counter >> 5) & 1) == 0: return
	var p: int = e["p"]
	var z: int = e["zone"]
	var obj: Dictionary = table.field[p][z]
	if obj.is_empty() or int(obj.get("card", -1)) < 0: return
	var center := zone(p, z)
	var defense := z < 5 and bool(obj.get("defense", false))
	var angle := (PI / 2 if defense else 0.0) + (PI if p == 1 else 0.0)
	var copy := _card(int(obj["card"]), center, bool(obj.get("face", true)), SIZE, angle)
	if copy:
		copy.modulate.a = 64.0 / 255.0
		BasicEffects._additive(copy)
	var owner := int(obj.get("owner", p)) & 1
	var frame_sprite := _asset("card_waku#s2" if owner != 0 else "card_waku#s", center, 1, 1,
			PI / 2 if defense else 0.0, "card")
	if frame_sprite: frame_sprite.z_index = 1


## 464b90: alguna marca de material soltada que aun no ha terminado.
func _markers_busy() -> bool:
	for m in _sacrifice.values():
		if m.get("kind", "") == "fusion" and m["release"]: return true
	return false


## 415130: algun eslabon vivo entrando (contador != 0x80) o saliendo (suelto).
func _chains_busy() -> bool:
	for c in _chain.values():
		if c["released"] or int(c["counter"]) != 0x80: return true
	return false

func _draw_chain(entry: Dictionary, counter: int) -> void:
	if counter == 0: return # 415280 no dibuja en contador0.
	var center: Vector2 = entry["center"]
	var tick := counter / 4 if counter <= 128 else (counter - 128) / 4
	var index := mini(tick, 25) if counter <= 128 else maxi(1, 15 - tick)
	var asset := "cha_ani_?%02d" % index if index <= 15 else "cha_hyou_?%d" % (index - 15) if index < 25 else "cha_ani_?15"
	var marker := _asset(asset, center + Vector2(0, -16), 1, 1, 0, "chain")
	if marker: marker.set_meta("blend_key", ["chain", entry.get("number", 0), 0])
	var reveal := maxi(0, tick - 16) if counter <= 128 else 16 - tick
	var number := _asset("chain_font", center + Vector2(0, 16), (32 - reveal) / 16.0, clampf((reveal << 4) / 255.0, 0, 1), 0, "chain")
	if number:
		number.set_meta("blend_key", ["chain", entry.get("number", 0), 1])
		number.hframes = 10
		number.frame = clampi(entry.get("number", 0), 0, 9)
