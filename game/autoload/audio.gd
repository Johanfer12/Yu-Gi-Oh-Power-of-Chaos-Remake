extends Node
## Musica y efectos del original (WAV PCM en data/<juego>/voice/{stream,internal}).

var _music := AudioStreamPlayer.new()
var _sfx: Array[AudioStreamPlayer] = []
## Las voces KaNN comparten un interlocutor. Las llamadas directas del motor no
## esperan al buffer, por lo que deben conservar el orden aunque avance el duelo.
var _speech := AudioStreamPlayer.new()
var _speech_queue: Array[Dictionary] = []
var _cache := {}
var _music_path := ""
var _music_rel_path := ""
## Segundo campo de la tabla de musica (0x5ada40): 1 en bucle (escenario, menu...), 0 una sola
## vez (j_win, j_lose, j_get, j_bm).
var _music_loop := true

const SFX_CHANNELS := 6
## Niveles del volumen de opciones (0..15) a 0..127: DAT_005adb40.
const LEVELS := [0, 35, 65, 85, 95, 104, 107, 110, 113, 115, 117, 119, 121, 123, 125, 127]

## Nivel general (DAT_005adb80, 0..127). 0x5841d0: cada sonido suena a volumen*nivel/127, que
## 0x584c20 pasa a centesimas de dB de DirectSound: v * 10000 / 127 - 10000.
var level := 127
## Tablas originales de los tres ejecutables, exportadas por re/scripts/export_audio_tables.py.
## Clave por juego/canal/nombre: decide.wav de Joey tiene116, Yugi/Kaiba124.
var _native := {}
## Joey5c0460: solo buffers clase2 (tablas stream), incluidos los de canales SFX.
var _fades := {}
var _fade_clock := 0.0


## Reproducciones del original (--ui-replay): el fin de cada sonido se mide en fotogramas del
## juego (un tick nativo cada uno), no en tiempo real. La reproduccion puede ir mas rapida o mas
## lenta que el reloj (capturas, motor sin tope) y una voz no debe durar mas o menos ticks por ello.
var game_clock := false
## Cotejo por valores (joey_full_duel_capture.gd): nombres de archivo pedidos, como ui_values.js
## registra las llamadas a 583e10/5865b0/5c03d0 del original.
var played_log: Array[String] = []
var log_played := false
var _game_ends := {}
var _game_speech_end := 0


func _ready() -> void:
	reload_native_tables()
	_setup_players()
	game_clock = Paths.cmdline_value("ui-replay") != ""


func reload_native_tables() -> void:
	_native.clear()
	var table := Paths.data_dir.path_join("common/audio_native.json")
	if FileAccess.file_exists(table):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(table))
		if parsed is Dictionary: _native = parsed


func _setup_players() -> void:
	_music.bus = "Master"
	_music.finished.connect(func() -> void:
		if _music_loop: _music.play())
	add_child(_music)
	for i in SFX_CHANNELS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)
	add_child(_speech)
	_speech.finished.connect(_advance_speech)
	_sfx.append(_speech)


func play_music(rel_path: String, loop := true) -> void:
	if log_played: played_log.append(rel_path.get_file().to_lower())
	var path := Assets.resolve(rel_path)
	if path == "" or path == _music_path:
		return
	_music_loop = loop and bool(_native.get(rel_path.to_lower(), {}).get("loop", true))
	_music_path = path
	_music_rel_path = rel_path
	_music.stream = _load(path)
	_fades.erase(_music)
	_music.set_meta("native_audio_class", 2 if "/voice/stream/" in rel_path else 1)
	_music.volume_db = _db(rel_path)
	_music.play()


func music_path() -> String:
	return _music_rel_path


func stop_music() -> void:
	_fades.erase(_music)
	_music_rel_path = ""
	_music_path = ""
	_music.stop()


func stop_all() -> void:
	stop_music()
	_speech_queue.clear()
	for p in _sfx:
		_fades.erase(p)
		p.stop()
		p.stream = null
	_music.stream = null


func voice_disabled(rel_path: String) -> bool:
	var path := rel_path.replace("\\", "/").to_lower()
	return LauncherSettings.fast_play and (path.begins_with("yugi/voice/internal/yugi_") or path.begins_with("joey/voice/internal/joey_") or _is_kaiba_speech(path))


func play_sfx(rel_path: String) -> void:
	if log_played: played_log.append(rel_path.get_file().to_lower())
	if voice_disabled(rel_path): return
	if level == 0: return # 583d40/583e10: sonido deshabilitado.
	var path := Assets.resolve(rel_path)
	if path == "":
		return
	if game_clock:
		_note_game_end(path, rel_path)
	if _is_kaiba_speech(rel_path):
		var stream := _load(path)
		if stream == null: return
		_speech_queue.append({"path": path, "rel_path": rel_path, "stream": stream})
		if not _speech.playing: _advance_speech()
		return
	for p in _sfx:
		if p == _speech: continue
		if not p.playing:
			_fades.erase(p)
			p.set_meta("native_audio_class", 2 if "/voice/stream/" in rel_path else 1)
			p.stream = _load(path)
			p.volume_db = _db(rel_path)
			p.play()
			return


## Fotograma del juego en que acaba el sonido; las frases de Kaiba van en cola, una tras otra.
func _note_game_end(path: String, rel_path: String) -> void:
	var stream := _load(path)
	if stream == null: return
	var start := Engine.get_process_frames()
	if _is_kaiba_speech(rel_path):
		start = maxi(start, _game_speech_end)
	_game_ends[path] = start + int(ceil(stream.get_length() * NativeClock.HZ))
	if _is_kaiba_speech(rel_path):
		_game_speech_end = _game_ends[path]


func _is_kaiba_speech(rel_path: String) -> bool:
	var rel := rel_path.replace("\\", "/").to_lower()
	if not rel.begins_with("kaiba/voice/internal/"): return false
	var file := rel.get_file().get_basename()
	return file.length() == 4 and file.begins_with("ka") and file.substr(2).is_valid_int()


func _advance_speech() -> void:
	if _speech_queue.is_empty(): return
	var next: Dictionary = _speech_queue.pop_front()
	_fades.erase(_speech)
	_speech.set_meta("native_audio_class", 1)
	_speech.stream = next.stream
	_speech.volume_db = _db(next.rel_path)
	_speech.play()


## 583ed0/584290: terminado cuando el buffer ya no reproduce; sin sonido devuelve1.
func sfx_finished(rel_path: String) -> bool:
	if voice_disabled(rel_path): return true
	if level == 0: return true
	var path := Assets.resolve(rel_path)
	if game_clock:
		return Engine.get_process_frames() >= int(_game_ends.get(path, 0))
	for queued in _speech_queue:
		if queued.path == path: return false
	var stream: AudioStream = _cache.get(path)
	if stream == null: return true
	for player in _sfx:
		if player.stream == stream and player.playing: return false
	return true


## Nivel de opciones 0..15 (DAT_00a10124 >> 4). Con 0 el original apaga el sonido (0x583d40).
func set_option_volume(v: int) -> void:
	level = LEVELS[clampi(v, 0, 15)]
	_music.volume_db = _db(_music_rel_path)
	if level == 0:
		_speech_queue.clear()
		for p in _sfx:
			p.stop()
			_fades.erase(p)
		_fades.erase(_music)


## 5c1960/5c0a90: centesimas dB enteras, minimo5, contador duracion+1.
## No alarga un fundido existente. A -5000 o menos se detiene inmediatamente.
func fade_native(duration: int) -> void:
	for player in [_music] + _sfx:
		if not player.playing or int(player.get_meta("native_audio_class", 1)) != 2: continue
		var pending: Dictionary = _fades.get(player, {})
		if not pending.is_empty() and duration + 1 > int(pending.remaining): continue
		var volume := roundi(player.volume_db * 100.0)
		if volume <= -5000:
			_stop_faded(player)
			continue
		var span := maxi(5, duration)
		_fades[player] = {"volume":volume,"step":int(float(-5000-volume)/span),"remaining":span+1}


func _process(delta: float) -> void:
	if _fades.is_empty():
		_fade_clock = 0.0
		return
	_fade_clock += NativeClock.ticks(delta)
	while _fade_clock >= 1.0:
		_fade_clock -= 1.0
		_native_fade_tick()


## 5c0610/5c12b0: aplicar paso, descontar contador y parar al llegar a0.
func _native_fade_tick() -> void:
	for player in _fades.keys():
		var fade: Dictionary = _fades[player]
		fade.volume = clampi(roundi(player.volume_db*100.0)+int(fade.step),-10000,0)
		player.volume_db = int(fade.volume)/100.0
		fade.remaining = int(fade.remaining)-1
		if fade.remaining == 0: _stop_faded(player)


func _stop_faded(player: AudioStreamPlayer) -> void:
	_fades.erase(player)
	player.stop()
	if player == _music:
		_music_path = ""
		_music_rel_path = ""


func _db(rel_path: String) -> float:
	if level <= 0:
		return -80.0
	var own: int = _native.get(rel_path.to_lower(), {}).get("volume", 127)
	var v := own * level / 127
	return (v * 10000 / 127 - 10000) / 100.0


func _load(path: String) -> AudioStream:
	if not _cache.has(path):
		if path.get_extension().to_lower() == "ogg":
			var ogg := AudioStreamOggVorbis.load_from_file(path)
			if ogg != null:
				ogg.loop = false
			_cache[path] = ogg
			return ogg
		# install.wav tiene smpl sin bucles (numSampleLoops=0). El lector de Godot4.7
		# lo trata como bucle0..0: playing=true pero no avanza ni se oye. Los originales
		# controlan los bucles desde sus tablas/DirectSound, no desde smpl.
		var data := FileAccess.get_file_as_bytes(path)
		if data.size() >= 12 and data.slice(0, 4).get_string_from_ascii() == "RIFF":
			var pcm := data.slice(0, 12)
			var offset := 12
			while offset + 8 <= data.size():
				var length := int(data.decode_u32(offset + 4))
				var end := offset + 8 + length + (length & 1)
				if end > data.size(): break
				if data.slice(offset, offset + 4).get_string_from_ascii() != "smpl":
					pcm.append_array(data.slice(offset, end))
				offset = end
			pcm.encode_u32(4, pcm.size() - 8)
			_cache[path] = AudioStreamWAV.load_from_buffer(pcm)
		else:
			_cache[path] = AudioStreamWAV.load_from_file(path)
		if _cache[path] != null:
			_cache[path].loop_mode = AudioStreamWAV.LOOP_DISABLED
	return _cache[path]
