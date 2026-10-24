extends RefCounted
## Recursos y condiciones de Yugi originales; reloj visual separado del RNG del duelo.
static var _voice_ms: Dictionary = {}
static var _fade_shader: Shader
static var _joey_flip_turns: Dictionary = {}

## Estado por duelo de las reacciones (no el MT: el de interfaz es global, ver UiRandom).
static func reset_duel_state(duel: Duel) -> void:
	_joey_flip_turns[duel.get_instance_id()] = 0 # DAT_005eb558: ultimo turno de reaction05.

## FUN_00531140 (Yugi) / 533640 (Kaiba) / 55c140 (Joey): MT de interfaz global, el mismo que
## usan janken, bustos y mazo del rival; no se resiembra por duelo.
static func visual_rand(_duel: Duel = null) -> int:
	return UiRandom.draw()

static func native_cos(angle: int) -> int:
	# 5325a0: cos(angle*pi/256)*65536, __ftol trunca hacia cero.
	return int(cos((angle & 511) * PI / 256.0) * 65536.0)

static func voice_ms(path: String) -> int:
	if not _voice_ms.has(path):
		var resolved: String = Assets.resolve(path)
		var stream: AudioStream = Audio._load(resolved) if resolved != "" else null
		_voice_ms[path] = int(stream.get_length() * 1000) if stream != null else 0
	return _voice_ms[path]

static func animation_index(code: int, group: int, frame: int, voice_duration_ms: int, tick: int) -> int:
	var mode := code % 1000
	var voice_ticks := voice_duration_ms / 33
	if voice_ticks < 1: voice_ticks = 32 # 40d680.
	match mode:
		1, 2:
			if mode == 2 and tick & 0x18: return -1
			var shape := (tick >> 1) & 3
			if shape == 0: return -1
			return group + 1 + (1 if shape == 2 else 0)
		3, 8:
			var elapsed := frame - voice_ticks / 2
			if elapsed < 0: return -1
			return group + 1 + mini(maxi(code / 1000, 2) - 1, elapsed / (2 if mode == 3 else 1))
		4:
			return group + 1 if frame >= voice_ticks / 2 else -1
		7:
			var step := int((frame - 8) / 3)
			return group + 1 + step if step >= 0 else -1
	return -1

static func normalize(event: Dictionary, duel: Duel) -> Dictionary:
	var d: Dictionary = event.duplicate(true)
	var kind: String = d.get("kind", "")
	var p: int = int(d.get("p", 0)) & 1
	if LauncherSettings.fast_play and kind in ["reaction_destroy", "reaction_flip", "reaction_lp", "reaction_card", "reaction_activation", "cmd"]:
		return {}
	if str(d.get("game", "yugi")) == "kaiba" and kind in ["reaction_destroy", "reaction_flip", "reaction_card", "reaction_lp", "cmd"]:
		return _kaiba(d, duel)
	if str(d.get("game", "yugi")) == "joey" and kind in ["reaction_activation", "reaction_destroy", "reaction_flip", "reaction_card", "reaction_lp", "cmd"]:
		return _joey(d, duel)
	var layout := ""
	var voice := ""
	match kind:
		"reaction_destroy":
			var index := duel.cards.index_of(int(d.get("card", 0)))
			var type := duel.cards.type_of(index)
			if type in [21, 22, 23] or (type != 24 and duel.f445810(index) < 2000): return {}
			if p == 0: return _voice(d, 0x2f, false) # 4023d0: Yugi_18 directa, sin bust-up.
			layout = "reaction_o3"
			voice = "yugi_52"
		"reaction_flip":
			var index := duel.cards.index_of(int(d.get("card", 0)))
			# Este evento procede de 4040f0 -> 402630 -> 401e00.
			if p != 0 or duel.cards.type_of(index) != 21: return {}
			layout = "reaction_o2"
			voice = "yugi_%02d" % (46 + (visual_rand(duel) & 1))
		"reaction_card":
			# 0x402610 -> 0x401ca0(p, carta).
			var card := int(d.get("card", 0))
			var index := duel.cards.index_of(card)
			var type := duel.cards.type_of(index)
			if p == 1:
				if card == 0x15b: return _gofu(d, duel)
				if card == 0x3f0: return _voice(d, 0x3c + (visual_rand(duel) & 1))  # Yugi_31/32
				if type == 0x15:
					# Yugi_18..20; con el bit 0 de DAT_00a133f2, Yugi_18 o Yugi_20.
					var r := visual_rand(duel)
					return _voice(d, 0x2f + (r % 3 if (duel.m.u16(0xa133f2) & 1) == 0 else (r & 1) * 2))
				if type == 0x16: return _voice(d, 0x4a if duel.f53b880(index) == 2 else 0x33)  # Yugi_45 / Yugi_22
				return {}
			if type != 22: return {}
			layout = "reaction_o1"
			voice = "yugi_51"
		"cmd":
			var args: Array = d.get("args", [])
			if args.size() < 3: return {}
			match int(d.get("op", 0)):
				0x07: # 0x404430 -> 0x4026d0 -> 0x4025f0: suena 0x10000039 (Yugi_28).
					return {} if duel.game_mode == 6 else _voice(d, 0x39, false)
				0xad: # 0x403e00 -> 0x402680 (p, carta, b del comando que queda en la pila).
					if duel.game_mode == 6: return {}
					if p != 0: return _voice(d, 0x49 - int(int(args[1]) != 0))
					layout = "reaction_o2"
					voice = "yugi_%02d" % (46 + (visual_rand(duel) & 1))
					return _portrait(d, layout, voice)
				0xe9: return {} # 0x4026f0 -> 0x402600, vacia.
			# 0x404070 -> 0x402650 -> 0x402090 (args: carta, -, c).
			if int(d.get("op", 0)) != 0xe6: return {}
			var card := int(args[0])
			var c := int(args[2])
			if p == 1:
				if card in [0x15, 0x22, 0x26, 0x4ba, 0x7f2] and c < 3: return _summon(d, duel)
				# Voces sin retrato de la CPU (ids 0x1000001e + n = Yugi_(n + 1)).
				var id: int = {0x2f7: 0x5a, 0x24: 0x2b, 0x2d1: 0x5b, 0x328: 0x5c, 0x34d: 0x5d, 0x15: 0x27, 0x26: 0x28, 0x22: 0x26, 0x4ba: 0x26, 0x7f2: 0x26}.get(card, 0x46 if c == 3 else 0)
				return _voice(d, id)
			if c == 4: return _voice(d, 0x4b, false) # Suena directamente (0x583e10).
			if c not in [1, 2]: return {}
			var index := duel.cards.index_of(card)
			# Con ATK < 2000 solo la voz 0x4d, sin bust-up.
			if duel.f445810(index) < 2000: return _voice(d, 0x4d)
			layout = "reaction_o4"
			voice = "yugi_48" # Tabla PE: índice 0x4d.
		"reaction_lp":
			var delta: int = int(d.get("delta", 0))
			if p != 1 or delta >= 0: return {}
			var life := duel.m.u16(DuelMem.pl(1))
			if -delta <= 2000 and life > 4000:
				layout = "reaction_d1" if -delta <= 1500 else "reaction_d3"
				voice = "yugi_%02d" % (33 + (2 if (visual_rand(duel) & 1) == 0 else 0)) if -delta <= 1500 else "yugi_34"
			else:
				var choice := visual_rand(duel) % (3 if -delta < life else 2)
				layout = "reaction_d3" if choice == 0 else "reaction_d2"
				voice = "yugi_%02d" % (36 + choice)
		"phase":
			d["mode"] = "phase_native"
			d["frames"] = 40 if int(d.get("phase", 0)) == 3 else 32
			d["center"] = Vector2(525, 300)
			return d
		"next_turn":
			d["mode"] = "next_turn"
			d["frames"] = 48 # 460c40: counter 0..383, avance de ocho.
			d["center"] = Vector2(525, 300)
			return d
		_: return {}
	return _portrait(d, layout, voice)

## Fotogramas que vive el objeto de voz 0x401bc0: su update 0x401c60 lo mantiene mientras la
## voz suena (0x583ed0), y como esta registrado (0x438250) el comando espera a que acabe.
static func voice_frames(game: String, sound_file: String) -> int:
	return maxi(1, int(ceil(NativeClock.ticks(voice_ms("%s/voice/internal/%s.wav" % [game, sound_file]) / 1000.0))))

## Voz suelta de la tabla de Yugi (id 0x10000000 + n, n >= 0x1e): Yugi_(n - 0x1d).
## `wait`: true si el original la crea con el objeto 0x401bc0 (el duelo espera a que acabe);
## false si la pide directamente con 0x583e10 (un solo fotograma).
static func _voice(d: Dictionary, n: int, wait := true) -> Dictionary:
	if n < 0x1e: return {}
	d["mode"] = "voice"
	d["sound_file"] = "yugi_%02d" % (n - 0x1d)
	d["wait_voice"] = wait
	d["frames"] = voice_frames("yugi", d["sound_file"]) if wait else 1
	return d

## Voz suelta de la tabla de Kaiba (id 0x10000000 + n, n >= 0x21): Ka(n - 0x20).
static func _ka_voice(d: Dictionary, n: int, wait := true) -> Dictionary:
	if n < 0x21: return {}
	d["mode"] = "voice"
	d["sound_file"] = "ka%02d" % (n - 0x20)
	d["wait_voice"] = wait
	d["frames"] = voice_frames("kaiba", d["sound_file"]) if wait else 1
	return d

static func _portrait(d: Dictionary, layout: String, voice: String) -> Dictionary:
	d["mode"] = "portrait_native"
	d["wait_voice"] = true
	d["layout"] = layout
	d["center"] = Vector2(525, 300)
	var portrait_game: String = str(d.get("game", "yugi"))
	if not Assets.exists("%s/bust_up/%s.layout.json" % [portrait_game, layout]): return {}
	d["portrait_game"] = portrait_game
	d["sound"] = "%s/voice/internal/%s.wav" % [portrait_game, voice]
	d["voice_duration_ms"] = voice_ms(d["sound"])
	var sound_path: String = Assets.resolve(d["sound"])
	var frames := 33 # 40e920: contador>255 y voz terminada; 40d6c0 suma ocho.
	if sound_path != "":
		var stream: AudioStream = Audio._load(sound_path)
		if stream != null: frames = maxi(frames, int(ceil(NativeClock.ticks(stream.get_length()))))
	if d.has("sound_after"):
		d["sound_after_frame"] = maxi(1, int(ceil(NativeClock.ticks(d["voice_duration_ms"] / 1000.0))))
		var after_path: String = Assets.resolve(d["sound_after"])
		if after_path != "":
			var stream: AudioStream = Audio._load(after_path)
			if stream != null: frames = maxi(33, d["sound_after_frame"] + int(ceil(NativeClock.ticks(stream.get_length()))))
	d["frames"] = frames
	return d


## Jo402e00: id0 no crea objeto; retrato0 es solo voz registrada.
static func _jo_reaction(d: Dictionary, portrait: int, id: int, wait := true) -> Dictionary:
	if id < 0x25: return {}
	# Tabla5efd48: la ultima entrada6d salta Joey_73 y apunta a Joey_74.
	var file := "joey_%02d" % (74 if id == 0x6d else id - 0x24)
	if portrait != 0: return _portrait(d, "reaction%02d" % portrait, file)
	d.merge({"mode": "voice", "sound_file": file, "wait_voice": wait, "frames": voice_frames("joey", file) if wait else 1}, true)
	return d


## Jo403bf0..403d40: wrappers desactivados en tutorial6/LAN3.
static func _joey(d: Dictionary, duel: Duel) -> Dictionary:
	if duel.game_mode in [3, 6] or duel.tutorial_interactive: return {}
	var p := int(d.get("p", 0)) & 1
	var kind := String(d.get("kind", ""))
	var card := int(d.get("card", -1))
	var index := duel.cards.index_of(card)
	match kind:
		"reaction_activation": # Jo403bc0 ->402be0; distinta de4030f0.
			if p != 1 or card < 0: return {}
			if card in [0x3f0, 0x447, 0x487]: return _jo_reaction(d, 0, 0x43 + (visual_rand(duel) & 1))
			if card in [0x28a, 0x3c7, 0x3de, 0x438, 0x443, 0x4b3, 0x4b4, 0x4de, 0x76e]: return {}
			if card == 0x420: return _jo_reaction(d, 5, 0x37)
			var type := duel.cards.type_of(index)
			if type == 21:
				var flags := duel.m.u8(0xa133f2)
				var count := 6 if (flags & 1) != p and (flags & 14) == 6 else 3
				var choice := visual_rand(duel) % count
				return _jo_reaction(d, [2,0,2,1,5,10][choice], [0x33,0x36,0x38,0x34,0x37,0x39][choice])
			if type == 22: return _jo_reaction(d, 7, 0x51 if duel.csub(index) == 2 else 0x3a)
			return {}
		"reaction_destroy": # Jo403800: humano ATK2400; rival ATK2000 y nivel>4.
			if p == 0:
				return _jo_reaction(d, 0, 0x36) if duel.f445810(index) >= 2400 else {}
			return _jo_reaction(d, 4, 0x58) if duel.f445810(index) >= 2000 and duel.f4457d0(index) > 4 else {}
		"reaction_flip": # Jo403700: contador de turnos, no reloj visual ni comandos.
			if p != 1: return {}
			var turn := duel.m.u16(0xa133f0)
			var old := int(_joey_flip_turns.get(duel.get_instance_id(), 0))
			if turn >= old and turn < old + 8: return {}
			_joey_flip_turns[duel.get_instance_id()] = turn
			return _jo_reaction(d, 5, 0x41)
		"reaction_card": # Jo4030f0.
			if p == 1:
				var choices := {0x420: [0, 0x3f], 0x3de: [7, 0x6c], 0x14f: [0, 0x3b], 0x28a: [2, 0x35], 0x3c7: [7, 0x68], 0x3ea: [0, 0x3e], 0x3f0: [0, 0x3d], 0x403: [0, 0x3c], 0x4b4: [7, 0x6a], 0x438: [2, 0x69], 0x443: [2, 0x6b], 0x4b3: [7, 0x66], 0x4de: [5, 0x6d], 0x76e: [7, 0x67]}
				if not choices.has(card): return {}
				return _jo_reaction(d, choices[card][0], choices[card][1])
			var type := duel.cards.type_of(index)
			if type == 21: return _jo_reaction(d, 4, 0x52 + (visual_rand(duel) & 1))
			if type == 22: return _jo_reaction(d, 4, 0x57)
		"reaction_lp": # Jo403900, tabla5da3c0=[10,10,6,6,12,12].
			var delta := int(d.get("delta", 0))
			var life := int(d.get("native_life_before", duel.m.u16(DuelMem.pl(p))))
			if p != 1 or delta >= 0 or life == 0: return {}
			var choice := 0
			if life + delta < 1: choice = 5
			elif life <= 4000: choice = (3 if -delta <= 1000 else 2) if -delta <= 2000 else 4
			else: choice = clampi(int((-1 - delta) / 500) - 1, 0, 3)
			return _jo_reaction(d, [10, 10, 6, 6, 12, 12][choice], 0x45 + choice)
		"cmd":
			var args: Array = d.get("args", [])
			if args.size() < 3: return {}
			match int(d.get("op", 0)):
				0x07: return _jo_reaction(d, 2, 0x40) if p == 1 else {} # Jo403b20.
				0xad: return _jo_reaction(d, 4, 0x58) if p == 0 else _jo_reaction(d, 5, 0x50 - int(int(args[1]) != 0))
				0xe9: return _jo_reaction(d, 8, 0x30) if p == 1 else {} # Jo403b70, cualquier carta.
			if int(d.get("op", 0)) != 0xe6: return {}
			card = int(args[0])
			index = duel.cards.index_of(card)
			var c := int(args[2])
			if p == 0:
				if c in [1, 2]: return _jo_reaction(d, 1 if duel.f445810(index) >= 2000 else 0, 0x54)
				if c == 4: return _jo_reaction(d, 0, 0x58, false)
				if c == 5: return _jo_reaction(d, 1, 0x55)
				return {}
			# Jo414a20: las dos invocaciones especiales se portan aparte de los retratos comunes.
			if card in [0x51, 0x2e8]:
				d.merge({"mode": "joey_summon", "layout": "summon" if card == 0x51 else "summon2", "counter": 4,
					"sound": "joey/voice/internal/gofuken.wav", "summon_voice": "joey/voice/internal/joey_%02d.wav" % (9 if card == 0x51 else 64),
					"music_once": "joey/voice/stream/m_red.wav"}, true)
				return d
			var id: int = {0xf: 0x61, 0x44: 0x32, 0x4cf: 0x62, 0x2f8: 0x63, 0x2f9: 0x2e, 0x2ef: 0x65 if c in [1, 2] else 0x2f}.get(card, 0x4d if c == 3 else 0)
			if c in [1, 2] and duel.f445810(index) >= 1850:
				var r := visual_rand(duel)
				var special := card in [0x2ef, 0x2f9, 0x52e]
				var voice := 0x29 if special else 0x28 + (r & 1) * 2
				if id == 0: id = 0x2c - int(c != 1)
				if id == 0x65:
					voice = 0x65
					id = 0
				if id != 0: d["sound_after"] = "joey/voice/internal/joey_%02d.wav" % (id - 0x24)
				d["music_once"] = "joey/voice/stream/m_sum.wav"
				return _jo_reaction(d, 8 if special else 13, voice)
			return _jo_reaction(d, 2 if card == 0x44 else 0, id)
	return {}

static func _kaiba(d: Dictionary, duel: Duel) -> Dictionary:
	var p: int = int(d.get("p", 0)) & 1
	var kind: String = str(d.get("kind", ""))
	var card: int = int(d.get("card", 0))
	var index := duel.cards.index_of(card)
	var type := duel.cards.type_of(index)
	match kind:
		"reaction_destroy": # 402460, umbral CPU 2000; humano solo voz con umbral 2400.
			if type in [21, 22, 23]: return {}
			if p == 0:
				return {} if type != 24 and duel.f445810(index) < 2400 else _ka_voice(d, 0x24)
			if type != 24 and duel.f445810(index) < 2000: return {}
			return _portrait(d, "reaction03", "ka52")
		"reaction_flip": # 402620 -> tabla 59d4b0 -> 401e40.
			if p == 0:
				if type == 21: return _portrait(d, "reaction11", "ka46")
				if type == 22: return _portrait(d, "reaction03" if card == 0x3f0 else "reaction11", "ka48" if card == 0x3f0 else "ka51")
			elif card == 0x3c0: return _portrait(d, "reaction12", "ka68")
			elif type == 21:
				var voice: String = {0x150: "ka23", 0x294: "ka17", 0x3ab: "ka27", 0x3ea: "ka24", 0x403: "ka25", 0x420: "ka26", 0x4be: "ka66", 0x4db: "ka64"}.get(card, "ka21")
				if card not in [0x290, 0x3ca]: return _portrait(d, "reaction09", voice)
		"reaction_card": # 402600 -> tabla 59d4ac -> 401c80. Humano no retrato.
			if p == 0 or card == 0x3c0: return {}
			if card in [0x290, 0x294, 0x3ca, 0x3f0] and type != 22: return {}
			if type == 21:
				var variant := (visual_rand(duel) & 1) * 2 if duel.m.u8(0xa133f2) & 1 else visual_rand(duel) % 3
				return _portrait(d, "reaction05", "ka%02d" % (18 + variant))
			if type == 22:
				var voice := "ka%02d" % (31 + (visual_rand(duel) & 1)) if card == 0x3f0 else "ka%02d" % (15 + (visual_rand(duel) & 1)) if card == 0x294 else "ka65" if card == 0x290 else "ka67" if card == 0x3ca else "ka45" if duel.game_mode == 2 else "ka22"
				return _portrait(d, "reaction09", voice)
		"reaction_lp": # 4028e0, selección determinista exacta sin RNG.
			var delta: int = int(d.get("delta", 0))
			var life := duel.m.u16(DuelMem.pl(1))
			if p != 1 or delta >= 0 or life == 0: return {}
			var damage := -delta
			var selection: int
			if life + delta <= 0: selection = 5
			elif life <= 4000: selection = 4 if damage > 2000 else 3 if damage <= 1000 else 2
			else: selection = clampi((damage - 1) / 1000 - 1, 0, 3)
			return _portrait(d, "reaction%02d" % [2, 6, 10, 10, 3, 7][selection], "ka%02d" % (33 + selection))
		"cmd": # 402640 (args: carta, -, c). Voces de la tabla 0x5b03d8: 0x10000020 + n = Ka(n).
			var args: Array = d.get("args", [])
			if args.size() < 3 or duel.game_mode == 6: return {}
			card = int(args[0])
			match int(d.get("op", 0)):
				0x07: return _portrait(d, "reaction01", "ka28") # 0x404760 -> 0x4026c0 -> 0x402570.
				0xad: # 0x404130 -> 0x402670 (p, carta, b del comando).
					if p == 0: return _portrait(d, "reaction11", "ka46")
					return _ka_voice(d, 0x4c - int(int(args[1]) != 0))
				0xe9: # 0x406710 -> 0x4026e0 -> 0x4025b0.
					return _portrait(d, "reaction12", "ka12") if p != 0 and card == 0x17b else {}
			if int(d.get("op", 0)) != 0xe6: return {}
			var c := int(args[2])
			index = duel.cards.index_of(card)
			if p == 0:
				if c == 4: return _ka_voice(d, 0x4e, false) # Suena directamente (0x5865b0).
				if c not in [1, 2]: return {}
				if duel.f445810(index) < 2000: return _ka_voice(d, 0x4f)
				return _portrait(d, "reaction03", "ka47")
			if card in [0, 0x7d0]: return _blueeyes(d, duel) # 40f0f0.
			var id: int = {0x17b: 0x2e, 0x179: 0x2b, 0x20: 0x2a, 0x17a: 0x5f, 0x345: 0x5d, 0x581: 0x5e}.get(card, 0)
			if id == 0 and c == 3: return _ka_voice(d, 0x49)
			if c in [1, 2] and duel.f445810(index) >= 2000:
				# reaction08 con primera voz MT % 3 (Ka04-06) y despues la de la carta (Ka08/Ka07
				# segun c si no tiene propia).
				if id == 0: id = 0x28 - int(c != 1)
				d["sound_after"] = "kaiba/voice/internal/ka%02d.wav" % (id - 0x20)
				# Antes del retrato suena 0x2000000e (m_summon, sin bucle); el comando 0xe6 acaba
				# con 0x4376e0, que vuelve a poner la musica segun los LP.
				d["music_once"] = "kaiba/voice/stream/m_summon.wav"
				return _portrait(d, "reaction08", "ka%02d" % (4 + visual_rand(duel) % 3))
			return _ka_voice(d, id)
	return {}

static func render(owner: Node2D, event: Dictionary, frame: int) -> void:
	var mode: String = str(event.get("mode", ""))
	if mode in ["joey_summon", "joey_summon_exit"]:
		_render_joey_summon(owner, event, frame)
		return
	if mode == "summon_portrait":
		_render_summon(owner, event, frame)
		return
	if mode == "blueeyes_portrait":
		_render_blueeyes(owner, event, frame)
		return
	if mode == "gofu_portrait":
		_render_gofu(owner, event, frame)
		return
	if mode == "next_turn":
		var counter := frame * 8
		var color := "b" if int(event.get("p", 0)) == 0 else "r"
		var name := "nex_?_" + color
		var offset := 0.0
		if counter < 64: offset = (64 - counter) * 2.0
		elif counter <= 320: name += str(clampi((counter - 64) / 16 + 1, 1, 8))
		else:
			name = "nex_?_" + ("r" if color == "b" else "b")
			offset = (320 - counter) * 2.0
		_turn_banner(owner, name, int(offset)) # 4158d0: giro trapezoidal, no traslación.
		return
	if mode == "phase_native":
		var phase: int = clampi(int(event.get("phase", 0)), 0, 5)
		var counter := frame * 8
		if phase == 3 and frame > 8: counter = 64 + (frame - 8) * 4 if frame <= 24 else 128 + (frame - 24) * 8
		var name: String = "?_%s_%s" % [["dr", "st", "m1", "ba", "m2", "en"][phase], "b" if int(event.get("p", 0)) == 0 else "r"]
		if counter < 64:
			var offset := native_cos(counter * 2) >> 10
			for sign_value in [-1, 1]: owner._asset(name, Vector2(525 + sign_value * offset, 300), 1, counter * 3 / 255.0, 0, "phase_name")
		elif counter <= 128:
			if phase == 3: name += str(clampi((counter - 64) / 8 + 1, 1, 7))
			owner._asset(name, Vector2(525, 300), 1, 1, 0, "phase_name")
		else: owner._asset(name, Vector2(525, 300), 1, (native_cos(counter - 128) >> 8) / 256.0, 0, "phase_name")
		return
	if mode != "portrait_native": return
	if event.has("sound_after") and Audio.sfx_finished(event["sound"]) and not event.get("sound_after_played", false):
		Audio.play_sfx(event["sound_after"])
		event["sound_after_played"] = true
	var portrait_game: String = str(event.get("portrait_game", "yugi"))
	var path := "%s/bust_up/%s.txt" % [portrait_game, event.get("layout", "")]
	if not Assets.exists(path.trim_suffix(".txt") + ".layout.json"): return
	var layout := Assets.layout(path)
	if layout.items.is_empty(): return
	var origin := Vector2(layout.position(0))
	# 40e920 dibuja solo el cuadrilátero de la imagen base. El mask evita los
	# rectángulos negros que quedan fuera del recorte en los BMP convertidos.
	var canvas: Node2D = owner
	if layout.items.size() >= 5:
		var mask := Polygon2D.new()
		mask.polygon = PackedVector2Array([Vector2(layout.position(1)), Vector2(layout.position(2)), Vector2(layout.position(4)), Vector2(layout.position(3))])
		mask.position = origin
		mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		owner.add_child(mask)
		canvas = mask
		origin = Vector2.ZERO
	_sprite(canvas, portrait_game, layout.resource(0), origin)
	var visual_tick: Variant = owner.get("visual_tick")
	var tick := int(visual_tick) if visual_tick != null else int(event.get("visual_tick_origin", 0)) + frame
	var duration_ms: int = int(event.get("voice_duration_ms", voice_ms(event.get("sound", ""))))
	if event.get("sound_after_played", false): duration_ms = voice_ms(event["sound_after"])
	for group in range(5, mini(layout.items.size(), 14), 3):
		if group + 2 >= layout.items.size(): continue
		var full_code := int(layout.value(group))
		var code := full_code % 1000
		var index := animation_index(full_code, group, frame, duration_ms, tick)
		match code:
			5:
				var a := origin + Vector2(layout.position(group + 1))
				var b := origin + Vector2(layout.position(group + 2))
				for offset in [0, 64]:
					var phase: int = frame * 4 + int(offset)
					var weight := native_cos((phase & 127) - 128) >> 8
					var alpha := native_cos((phase * 2 & 255) - 128) >> 8
					var sprite := _sprite(canvas, portrait_game, layout.resource(group + 1), Vector2.ZERO)
					if sprite != null:
						var size := sprite.texture.get_size()
						var width: int = int(size.x) * ((phase & 127) + 128) >> 8
						var height: int = int(size.y) * ((phase & 127) + 128) >> 8
						var x := (int(a.x) * weight + int(b.x) * (256 - weight)) >> 8
						var y := (int(a.y) * weight + int(b.y) * (256 - weight)) >> 8
						sprite.position = Vector2(x - width / 2, y - height / 2)
						sprite.scale = Vector2(width, height) / size
						sprite.modulate.a = clampf(alpha / 256.0, 0, 1)
			6:
				var copy := BackBufferCopy.new()
				copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
				canvas.add_child(copy)
				var sprite := _sprite(canvas, portrait_game, layout.resource(group + 1), origin)
				if sprite != null:
					# 42c6d0 -> 418370 -> LUT 5eb1d0; cada canal565 se trunca
					# por separado antes de sumar origen y fondo, con 16 pesos.
					if _fade_shader == null:
						_fade_shader = Shader.new()
						_fade_shader.code = """shader_type canvas_item;
render_mode unshaded;
uniform sampler2D back : hint_screen_texture, repeat_disable, filter_nearest;
uniform float level = 0.0;
void fragment() {
 vec4 source = texture(TEXTURE, UV);
 vec3 target = texture(back, SCREEN_UV).rgb;
 vec3 bits = vec3(31.0, 63.0, 31.0);
 vec3 src565 = floor(source.rgb * bits + vec3(0.5));
 vec3 dst565 = floor(target * bits + vec3(0.5));
 vec3 blended = floor(src565 * level / 15.0) + floor(dst565 * (15.0 - level) / 15.0);
 COLOR = vec4(blended / bits, source.a);
}"""
					var material := ShaderMaterial.new()
					material.shader = _fade_shader
					material.set_shader_parameter("level", mini(15, (frame * 4) >> 4))
					sprite.material = material
			7:
				if index >= 0: index = mini(layout.items.size() - 1, index)
		if index >= 0: _sprite(canvas, portrait_game, layout.resource(index), origin + Vector2(layout.position(index)))

static func _turn_banner(owner: Node2D, name: String, angle: int) -> void:
	var source: Sprite2D = owner._asset(name, Vector2(525, 300), 1, 1, 0, "phase_name")
	if source == null: return
	var texture := source.texture
	source.free()
	var size := texture.get_size()
	var width := int(native_cos(angle) * int(size.x) / 65536)
	if width == 0: return
	var sine := native_cos(angle - 128)
	var right_height := int(round(size.y * 65536 / (65536 + sine / 2)))
	var left_height := int(round(size.y * 65536 / (65536 - sine / 2)))
	var polygon := Polygon2D.new()
	polygon.texture = texture
	polygon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	polygon.uv = PackedVector2Array([Vector2.ZERO, Vector2(size.x - 1, 0), size - Vector2.ONE, Vector2(0, size.y - 1)])
	polygon.polygon = PackedVector2Array([Vector2(-width / 2, -left_height / 2), Vector2(width - width / 2 - 1, -right_height / 2), Vector2(width - width / 2 - 1, right_height - right_height / 2 - 1), Vector2(-width / 2, left_height - left_height / 2 - 1)])
	polygon.position = Vector2(525, 300)
	owner.add_child(polygon)

static func _sprite(owner: Node2D, game: String, name: String, position: Vector2) -> Sprite2D:
	if name.to_lower() == "null.bmp": return null
	var path := "%s/bust_up/%s" % [game, name]
	if not Assets.exists(path): return null
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = Assets.texture(path)
	sprite.position = position
	owner.add_child(sprite)
	return sprite

static func _summon(d: Dictionary, duel: Duel) -> Dictionary:
	# 40f250 -> update40d720/draw40d900. Un solo MT determina voz y cinco haces.
	var random := visual_rand(duel)
	var args: Array = d["args"]
	var intro := "yugi/voice/internal/yugi_%02d.wav" % (4 + random % 3)
	var second := "yugi/voice/internal/yugi_%02d.wav" % (8 if int(args[2]) == 1 else 7)
	var final_voice := "yugi/voice/internal/yugi_%02d.wav" % (11 if int(args[0]) == 0x26 else 10 if int(args[0]) == 0x15 else 9)
	var second_frame := maxi(65, 32 + int(ceil(NativeClock.ticks(voice_ms(intro) / 1000.0))))
	var final_frame := second_frame + maxi(33, int(ceil(NativeClock.ticks(voice_ms(second) / 1000.0))))
	d.merge({"mode": "summon_portrait", "random": random, "second_frame": second_frame, "final_frame": final_frame, "frames": final_frame + 33, "sound": "yugi/voice/stream/j_bm.wav", "sounds": [[32, intro], [second_frame, second], [final_frame, final_voice]]}, true)
	return d

static func _blueeyes(d: Dictionary, duel: Duel) -> Dictionary:
	# Vtable59db74 prueba que el constructor40f0f0 usa40dd00/40de30.
	var random := visual_rand(duel) & 1
	var voice := "kaiba/voice/internal/ka09.wav"
	var exit_frame := maxi(177, 16 + int(ceil(NativeClock.ticks(voice_ms(voice) / 1000.0))))
	d.merge({"mode": "blueeyes_portrait", "random": random, "exit_frame": exit_frame, "frames": exit_frame + 9, "sound": "kaiba/voice/stream/m_blue.wav", "sounds": [[0, "kaiba/voice/internal/gofuken.wav"], [16, voice]]}, true)
	return d

## 0x40f500 (vtable 0x59ab30, update 0x40e040, dibujo 0x40e1b0): retrato de Yugi al activar la
## CPU Espadas de Luz Reveladora (0x15b). Para la musica (0x583ea0) y pone j_hg (0x2000000b);
## al acabar, 0x4376e0 repone la del duelo. Contador +0x14: el update suma 4 antes de mirarlo.
##   c == 4 (primer update): gofuken (0x1000000b).
##   c == 0x40: bocadillo 9 + r en la superficie y Yugi_15 + r (0x1000002c + r), r = rand & 1.
##   c > 0x140 y la voz acabada: c = 0x10000 y Yugi_17 (0x1000002e).
##   c > 0x10080 y Yugi_17 acabada: c = 0x20000; termina al dibujar con c >= 0x20020.
static func _gofu(d: Dictionary, duel: Duel) -> Dictionary:
	var random := visual_rand(duel) & 1
	var first := "yugi/voice/internal/yugi_%02d.wav" % (15 + random)
	var second := "yugi/voice/internal/yugi_17.wav"
	var second_frame := maxi(80, 15 + int(ceil(NativeClock.ticks(voice_ms(first) / 1000.0))))
	var final_frame := second_frame + maxi(33, int(ceil(NativeClock.ticks(voice_ms(second) / 1000.0))))
	d.merge({"mode": "gofu_portrait", "random": random, "second_frame": second_frame,
			"final_frame": final_frame, "frames": final_frame + 9,
			"sound": "yugi/voice/stream/j_hg.wav",
			"sounds": [[0, "yugi/voice/internal/gofuken.wav"], [15, first], [second_frame, second]]}, true)
	return d

## Contador del dibujo en el fotograma `frame` (0 = primer update, c = 4).
static func gofu_counter(event: Dictionary, frame: int) -> int:
	if frame >= int(event["final_frame"]): return 0x20000 + (frame - int(event["final_frame"])) * 4
	if frame >= int(event["second_frame"]): return 0x10000 + (frame - int(event["second_frame"])) * 4
	return (frame + 1) * 4

static func _render_gofu(owner: Node2D, event: Dictionary, frame: int) -> void:
	_timed_sounds(event, frame)
	var layout := Assets.layout("yugi/bust_up/activate.txt")
	var c := gofu_counter(event, frame)
	var texture := Assets.texture("yugi/bust_up/" + layout.resource(0))
	if c < 0x40:
		# El update copia a la superficie las filas ya asentadas (< c*16 - 424) y el dibujo deja
		# caer las 424 siguientes con el coseno de 0xa0f2c0.
		var extent := c * 16
		var first := maxi(0, extent - 424)
		for y in mini(600, first): _strip(owner, texture, Rect2(0, y, 800, 1), Vector2(0, y))
		for y in range(first, mini(600, extent)):
			var angle := ((y - extent + 424) * 128) / 424
			_strip(owner, texture, Rect2(0, y, 800, 1), Vector2(0, y + ((65536 - native_cos(angle)) * 600 >> 16)))
		return
	_sprite(owner, "yugi", layout.resource(0), Vector2.ZERO)
	var speech := 9 + int(event["random"])
	_sprite(owner, "yugi", layout.resource(speech), Vector2(layout.position(speech)))
	var open := int(c != 0x40)
	for index in [1 + open, 3 + open]:
		if layout.value(index) != null and int(layout.value(index)) != 0:
			_sprite(owner, "yugi", layout.resource(index), Vector2(layout.position(index)))
	var mouth: int = [0, 5, 6, 5][(c >> 3) & 3]   # DAT_0059aad8
	if mouth != 0 and c < 0x20000:
		_sprite(owner, "yugi", layout.resource(mouth), Vector2(layout.position(mouth)))
	if c >= 0x10000:
		# Espada (7) desde la derecha y rotulo (8) desde la izquierda, con el coseno.
		var t := mini(c - 0x10000, 0x40)
		var off := 800 - (native_cos((2 * t - 0x80) & 0x1ff) * 800 >> 16)
		_sprite(owner, "yugi", layout.resource(7), Vector2(layout.position(7)) + Vector2(off, 0))
		_sprite(owner, "yugi", layout.resource(8), Vector2(layout.position(8)) - Vector2(off, 0))

static func _timed_sounds(event: Dictionary, frame: int) -> void:
	if event.get("mute", false): return
	var played: Dictionary = event.get("played_sounds", {})
	var sounds: Array = event.get("sounds", [])
	# Por posicion en la lista: dos sonidos pueden caer en el mismo fotograma (fusion2 y Yugi_13).
	for k in sounds.size():
		var entry: Array = sounds[k]
		if frame >= int(entry[0]) and not played.has(k):
			Audio.play_sfx(str(entry[1]))
			played[k] = true
	event["played_sounds"] = played

static func summon_counter(event: Dictionary, frame: int) -> int:
	if frame >= int(event["final_frame"]): return 0x20000 + (frame - int(event["final_frame"])) * 4
	if frame >= int(event["second_frame"]): return 0x10000 + (frame - int(event["second_frame"])) * 4
	return frame * 4

static func _render_summon(owner: Node2D, event: Dictionary, frame: int) -> void:
	_timed_sounds(event, frame)
	var layout := Assets.layout("yugi/bust_up/summon.txt")
	var counter := summon_counter(event, frame)
	var random: int = event["random"]
	_sprite(owner, "yugi", layout.resource(0), Vector2(layout.position(0)))
	if counter >= 128:
		# El fondo guardado conserva las viñetas; la introductoria se dibuja otra vez después.
		var speech := 8 + random % 3
		_sprite(owner, "yugi", layout.resource(speech), Vector2(layout.position(speech)))
		if counter >= 65536:
			var second := 12 if int(event["args"][2]) == 1 else 11
			_sprite(owner, "yugi", layout.resource(second), Vector2(layout.position(second)))
	for row in 5:
		var beam := _sprite(owner, "yugi", layout.resource(2), Vector2.ZERO)
		if beam != null:
			var offset := (((random >> (row * 4)) & 3) + row * 8) * 100
			beam.position = Vector2(800 - (offset + frame * 96) % (int(beam.texture.get_width()) + 800), layout.position(0).y + 20 + row * 70)
	if counter > 63:
		var origin := Vector2(layout.position(3)) + Vector2(mini((counter - 96) * 16, 0), 0)
		_sprite(owner, "yugi", layout.resource(3), origin)
		if counter > 127:
			var eyes := 4 if counter == 128 else 5
			_sprite(owner, "yugi", layout.resource(eyes), origin + Vector2(layout.position(eyes)))
			var mouth := (counter >> 3) & 3
			if mouth != 0 and counter < 0x30000:
				var index: int = [0, 6, 7, 6][mouth]
				_sprite(owner, "yugi", layout.resource(index), origin + Vector2(layout.position(index)))
	if counter > 127:
		var speech := 8 + random % 3
		_sprite(owner, "yugi", layout.resource(speech), Vector2(layout.position(speech)))
	if counter >= 0x20000 and counter < 0x20080:
		var label := _sprite(owner, "yugi", layout.resource(1), Vector2.ZERO)
		if label != null:
			var scale_fixed := maxi(65536, (counter - 0x1ffc0) * 512)
			var width := scale_fixed * label.texture.get_width() >> 16
			# ASM40dbc9 multiplica ambos tamaños devueltos por get_size; el600
			# sugerido por Ghidra procede de una variable de pila mal reconstruida.
			var height := scale_fixed * label.texture.get_height() >> 16
			label.position = Vector2(layout.position(1)) - Vector2((width - label.texture.get_width()) / 2, (height - label.texture.get_height()) / 2)
			label.scale = Vector2(width, height) / label.texture.get_size()
			label.modulate.a = mini(255, native_cos(counter - 0x20000) >> 8) / 255.0

static var _column_reveal_shader: Shader
static var _eye_shine_shader: Shader
static var _summon_background_shader: Shader

## Jo414cf0/414dc0: contador +4, voz en96, salida solo tras352 y el buffer terminado.
static func tick_joey_summon(event: Dictionary) -> void:
	var counter := int(event["counter"]) + 4
	if counter == 96: Audio.play_sfx(event["summon_voice"])
	if counter > 352 and counter < 65536 and Audio.sfx_finished(event["summon_voice"]): counter = 65536
	event["counter"] = counter

static func _render_joey_summon(owner: Node2D, event: Dictionary, frame: int) -> void:
	var counter := int(event["counter"])
	if counter == 4: return # 486290 captura primero;414dc0 no dibuja en este paso.
	var layout := Assets.layout("joey/bust_up/%s.txt" % event["layout"])
	var background := _sprite(owner, "joey", layout.resource(0), Vector2.ZERO)
	var exiting: bool = event.get("mode", "") == "joey_summon_exit"
	var progress := (256 if frame == 0 else maxi(0, 272 - frame * 32)) if exiting else mini(256, 16 + (frame - 1) * 32)
	if background != null and progress < 256:
		if _summon_background_shader == null:
			_summon_background_shader = Shader.new()
			_summon_background_shader.code = """shader_type canvas_item;
render_mode unshaded;
uniform sampler2D snapshot : filter_nearest, repeat_disable;
uniform float progress;
void fragment() {
 vec4 source = texture(TEXTURE, UV);
 vec3 target = texture(snapshot, UV).rgb;
 float y = floor(UV.y * 600.0);
 float distance = y < 300.0 ? 300.0 - y : y - 299.0;
 float extent = floor(300.0 * progress / 256.0);
 float level = clamp(floor((extent + 32.0 - distance) / 2.0), 0.0, 15.0);
 vec3 bits = vec3(31.0, 63.0, 31.0);
 vec3 a = floor(mix(target, source.rgb, source.a) * bits + vec3(0.5));
 vec3 b = floor(target * bits + vec3(0.5));
 COLOR = vec4((floor(a * level / 15.0) + floor(b * (15.0 - level) / 15.0)) / bits, 1.0);
}"""
		if event.has("snapshot"):
			var material := ShaderMaterial.new()
			material.shader = _summon_background_shader
			material.set_shader_parameter("snapshot", event["snapshot"])
			material.set_shader_parameter("progress", progress)
			background.material = material
	if exiting: return
	if counter > 31:
		var origin := Vector2(layout.position(2))
		_sprite(owner, "joey", layout.resource(2), origin)
		var mouth := (counter / 8) & 3
		if mouth != 0 and counter < 65536:
			var index: int = [0, 5, 6, 5][mouth] # tabla5da768.
			_sprite(owner, "joey", layout.resource(index), origin + Vector2(layout.position(index)))
		if counter < 96:
			var mask := _sprite(owner, "joey", layout.resource(1), Vector2(layout.position(1)))
			if mask != null: mask.modulate.a = clampf((native_cos(counter * 2 - 64) >> 8) / 255.0, 0, 1)
	if counter > 255:
		var label := _sprite(owner, "joey", layout.resource(7), Vector2.ZERO)
		if label != null:
			var size := label.texture.get_size()
			label.position = Vector2(400 - int(size.x) / 2, 592 - int(size.y))
			_column_reveal(label, counter * 4 - 1024) # Jo424e80 = Ka416a70.

static func _column_reveal(sprite: Sprite2D, progress: int) -> void:
	if _column_reveal_shader == null:
		_column_reveal_shader = Shader.new()
		_column_reveal_shader.code = """shader_type canvas_item;
render_mode unshaded;
uniform float progress;
uniform float width;
void fragment() {
 vec4 source = texture(TEXTURE, UV);
 float quarter = floor(width / 4.0);
 float extent = floor((width + quarter) * progress / 256.0);
 float alpha = clamp(floor((extent - floor(UV.x * width)) * 255.0 / quarter), 0.0, 255.0) / 255.0;
 COLOR = vec4(source.rgb, source.a * alpha);
}"""
	var material := ShaderMaterial.new()
	material.shader = _column_reveal_shader
	material.set_shader_parameter("progress", progress)
	material.set_shader_parameter("width", sprite.texture.get_width())
	sprite.material = material

static func _render_blueeyes(owner: Node2D, event: Dictionary, frame: int) -> void:
	_timed_sounds(event, frame)
	var layout := Assets.layout("kaiba/bust_up/activate.txt")
	var counter := frame * 4 if frame < int(event["exit_frame"]) else 65536 + (frame - int(event["exit_frame"])) * 4
	# Antes64,40de30 mueve filas individuales.40dd00 conserva las filas ya asentadas.
	var base := _sprite(owner, "kaiba", layout.resource(0), Vector2.ZERO)
	if base != null and counter < 64:
		base.free()
		var texture := Assets.texture("kaiba/bust_up/" + layout.resource(0))
		var extent := counter * 16
		var first := maxi(0, extent - 424)
		for y in mini(600, first): _strip(owner, texture, Rect2(0, y, 800, 1), Vector2(0, y))
		for y in range(first, mini(600, extent)):
			var angle := ((y - extent + 424) * 128) / 424
			var destination := y + ((65536 - native_cos(angle)) * 600 >> 16)
			_strip(owner, texture, Rect2(0, y, 800, 1), Vector2(0, destination))
	if counter >= 64:
		for pair in [[1, 2], [3, 4]]:
			var index: int = pair[0] if counter == 64 else pair[1]
			if layout.value(index) != null and int(layout.value(index)) != 0: _sprite(owner, "kaiba", layout.resource(index), Vector2(layout.position(index)))
		var mouth := (counter >> 3) & 3
		if mouth != 0 and counter < 0x20000:
			var index: int = [0, 5, 6, 5][mouth]
			_sprite(owner, "kaiba", layout.resource(index), Vector2(layout.position(index)))
	if counter >= 96 and counter < 160:
		var mask_texture := Assets.texture("kaiba/bust_up/" + layout.resource(11))
		var shine_texture := Assets.texture("kaiba/bust_up/" + layout.resource(12))
		var shine := _sprite(owner, "kaiba", layout.resource(11), Vector2(layout.position(11)))
		if shine != null:
			if _eye_shine_shader == null:
				_eye_shine_shader = Shader.new()
				_eye_shine_shader.code = """shader_type canvas_item;
render_mode unshaded;
uniform sampler2D shine : filter_nearest, repeat_disable;
uniform vec2 mask_size;
uniform vec2 shine_size;
uniform float shift_x;
void fragment() {
 vec4 mask = texture(TEXTURE, UV);
 vec2 p = UV * mask_size - vec2(shift_x, 0.0);
 vec4 light = texture(shine, p / shine_size);
 if (p.x < 0.0 || p.x >= shine_size.x) light = vec4(0.0);
 COLOR = vec4(light.rgb, light.a * mask.b);
}"""
			var material := ShaderMaterial.new()
			material.shader = _eye_shine_shader
			material.set_shader_parameter("shine", shine_texture)
			material.set_shader_parameter("mask_size", mask_texture.get_size())
			material.set_shader_parameter("shine_size", shine_texture.get_size())
			material.set_shader_parameter("shift_x", mask_texture.get_width() - (mask_texture.get_width() + shine_texture.get_width()) * (counter * 4 - 384) / 256)
			shine.material = material
	elif counter >= 160 and counter < 192:
		var star := _sprite(owner, "kaiba", layout.resource(14), Vector2.ZERO)
		if star != null:
			var scale_fixed := native_cos(counter * 8 + 128) >> 8
			var size := star.texture.get_size()
			var scaled := Vector2(int(size.x) * scale_fixed >> 8, int(size.y) * scale_fixed >> 8)
			star.position = Vector2(layout.position(14)) - scaled / 2
			star.scale = scaled / size
	elif counter >= 192:
		var label := _sprite(owner, "kaiba", layout.resource(7), Vector2.ZERO)
		if label != null:
			var size := label.texture.get_size()
			label.position = Vector2(400 - int(size.x) / 2, 592 - int(size.y))
			if _column_reveal_shader == null:
				_column_reveal_shader = Shader.new()
				_column_reveal_shader.code = """shader_type canvas_item;
render_mode unshaded;
uniform float progress;
uniform float width;
void fragment() {
 vec4 source = texture(TEXTURE, UV);
 float quarter = floor(width / 4.0);
 float extent = floor((width + quarter) * progress / 256.0);
 float alpha = clamp(floor((extent - floor(UV.x * width)) * 255.0 / quarter), 0.0, 255.0) / 255.0;
 COLOR = vec4(source.rgb, source.a * alpha);
}"""
			var material := ShaderMaterial.new()
			material.shader = _column_reveal_shader
			material.set_shader_parameter("progress", counter * 4 - 1792)
			material.set_shader_parameter("width", size.x)
			label.material = material

static func _strip(owner: Node2D, texture: Texture2D, rect: Rect2, position: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = rect
	sprite.position = position
	owner.add_child(sprite)
