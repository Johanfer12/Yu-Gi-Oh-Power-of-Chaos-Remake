extends RefCounted
## Recursos y etapas verificadas de los objetos 43eda0,43de50,43dcf0,43eb90,43e040.
## Solo Exodia consume MT visual al dibujar un nuevo tick; nunca el RNG del duelo.
## El dueño limpia sus hijos antes de render().
const EXODIA_CARDS := [20, 18, 16, 17, 19]
const BOARD_CARDS := [1528, 1541, 1542, 1543, 1544]
const CARD_SIZE := Vector2(100, 145)
const MINI_SIZE := Vector2(50, 72)
const Geometry := preload("res://scenes/duel/duel_geometry.gd")
const VisualMath := preload("res://scenes/duel/duel_visual_math.gd")
static var _board_shader: Shader
static var _reflection_shader: Shader
static var _ball_shader: Shader
static var _exodia_wipe_shader: Shader

## 5325a0: tabla coseno de512 entradas, escala65536 y truncado ftoi585f5c.
static func cosine(index: int) -> int:
	return VisualMath.cos_fx(index)

static func coin_state(counter: int, count: int, n: int, result: int, source: Vector2) -> Dictionary:
	var q := counter - n * 128
	var end := counter - (count + 4) * 128
	var dest := Vector2(525 + (100 - count * 100) / 2 + n * 100, 300)
	var pos := source
	if q >= 0 and q <= 256:
		pos = Vector2(int((int(source.x) * (256 - q) + int(dest.x) * q) / 256), int((int(source.y) * (256 - q) + 300 * q) / 256))
	elif q > 256: pos = dest
	var wave := (cosine(q - 128) >> 7) if q >= 0 and q < 256 else 0
	var zoom := wave / 2 + 256
	var alpha := 256
	if q < -64: alpha = q * 4 + 512
	elif end > -64: alpha = -end * 4
	var bit := (result >> n) & 1
	var face := 13 if q > 0 and bit != 0 else 6
	if q > 0 and q < 256: face = (int((70 if bit else 63) * q / 256) + 6) % 14
	return {"q": q, "end": end, "visible": q > -128, "pos": pos, "elevation": int(wave * -50 / 256), "zoom": zoom, "alpha": clampi(alpha, 0, 256), "face": face, "shadow": [1,2,3,3,2,1,0,1,2,3,3,2,1,0][face]}

static func board_state(counter: int, n: int, source: Vector2, complete: bool = true) -> Dictionary:
	var q := counter - n * 72 if complete else counter
	var horizon := 640 - n * 72 if complete else 320
	var travel := clampi(q, 64, 256) - 64
	var x := int((int(source.x) * (192 - travel) + (n + 2) * 100 * travel) / 192)
	var y := int((int(source.y) * (192 - travel) + 300 * travel) / 192) + ((cosine(q * 8 - 128) << 3) >> 16)
	if not complete:
		x = int(source.x)
		y = int(source.y)
	var alpha := mini(q * 4, 256) if q <= horizon else (horizon - q) * 4 + 256
	var bone_tick := int((q - 32) / 4)
	var bone_frame: int = int(bone_tick / 4) if bone_tick < 8 else [2,3,4,3][bone_tick & 3]
	return {"q": q, "visible": q >= 0 and q < horizon + 64, "pos": Vector2(x,y), "alpha": clampi(alpha,0,256), "smoke_scale": mini(q * 4,256), "smoke_frame": int(q / 8) % 5, "bone_frame": clampi(bone_frame,0,4), "bone_y": maxi(0,8 - bone_tick), "letter_width": clampi((q - 64) * 2,0,256), "distortion": maxi(0,16 - ((q - 64) >> 3))}

static func fusion_state(counter: int, count: int) -> Dictionary:
	var rotation := 0
	var angle := -128
	for tick in range(0, counter + 1, 4):
		rotation -= ((cosine(tick - 128) << 3) >> 16) if tick < 128 else 8
		if tick >= 128 and tick < 384: angle += -1 - (((65536 - cosine(int((tick - 128) / 2))) * 64) >> 16)
	var radius := 256
	if counter >= 128: radius = cosine(int((counter - 128) / 2)) >> 8
	var positions: Array[Vector2] = []
	for n in count:
		var a := (128 if count == 2 else 0) + int(n * 512 / count) + angle
		positions.append(Vector2(400 + ((cosine(a) * radius) >> 16),300 + ((cosine(a - 128) * radius) >> 16)))
	var swirl_scale := counter * 512 if counter < 128 else 65536 if counter < 384 else (448 - counter) * 1024 if counter < 448 else 0
	var swirl_alpha := ((cosine(counter - 128) << 8) >> 16) if counter < 128 else 256 if counter < 384 else (cosine(counter * 2 - 256) << 8) >> 16 if counter < 448 else 0
	return {"rotation":rotation,"angle":angle,"radius":radius,"positions":positions,"swirl_scale":swirl_scale,"swirl_alpha":swirl_alpha}

static func normalize(event: Dictionary, duel) -> Dictionary:
	var result := event.duplicate(true)
	var mode := String(result.get("mode", result.get("kind", "")))
	var args: Array = result.get("args", [])
	var op := int(result.get("op", -1))
	if op in [0xe0, 0xe1]: mode = "coin"
	elif op in [0xe2, 0xe3, 0xe4]: mode = "dice"
	elif op == 0x05: mode = "exodia"
	elif op == 0x06: mode = "destiny_board"
	elif op == 0xe9: mode = "fusion"
	result["mode"] = mode
	if mode == "exodia":
		# 43d22a/43d2ab: no adelantar las extracciones del dibujo al constructor.
		# "visual_seed" permite a las pruebas usar un MT propio.
		if result.has("visual_seed"):
			result["particle_rng"] = UiRandom.new(int(result["visual_seed"]))
		result.get_or_add("particles", [])
		result["particle_frame"] = -1
	var duration := timings(mode, result)
	if duration > 0: result["frames"] = duration
	var p := int(result.get("p", 0)) & 1
	if mode in ["coin", "dice"] and not args.is_empty():
		# 406ff0/4070c0/406f30 empaquetan loc<<1|p, con índice cero.
		var loc := int(args[2] if mode == "coin" else args[1]) & 15
		result["source_pos"] = Geometry.location(p, loc, 0, duel.m.u8(DuelMem.pl(p) + 2))
	elif mode == "destiny_board":
		var sources: Array = []
		for id in BOARD_CARDS:
			var pos := Vector2(400, 300)
			for z in range(5, 10):
				if duel.cards.id_of(duel.m.u16(DuelMem.zone(p, z)) & 0xfff) == id:
					pos = Geometry.zone(p, z)
					break
			sources.append(pos)
		result["sources"] = sources
		if result.get("game", "yugi") == "kaiba":
			# 406b80 solo construye los objetos de las piezas encontradas.
			result["letters"] = []
			for card in result.get("cards", []):
				result["letters"].append(int(card[0]))
				sources[int(card[0])] = Geometry.zone(p, 5 + int(card[1]))
	return result

static func timings(kind: String, event: Dictionary = {}) -> int:
	match kind:
		"exclusion": return 24 # Ka42fad0/Jo43dbe0: 64,+8 hasta256.
		"exodia": return 267 # -4,+4;43bff0 termina contador>=0x429.
		"fusion": return 160 # 438da0 +4;439d20 termina contador>0x27f.
		"dice": return 128 # -256,+8;438fb0 termina contador>=0x300.
		"coin": return 128 if int(event.get("op", 0xe0)) == 0xe1 else 96
		"destiny_board": return 178 if event.get("game", "yugi") == "kaiba" else 176 # Ka439770 setle; Yu43bf2c setl.
		"destiny_letter": return 98 # Ka439770: contador -4,+4; ocupado hasta384 inclusive.
	return 0

static func render(owner: Node2D, event: Dictionary, frame: int) -> bool:
	match String(event.get("mode", event.get("kind", ""))):
		"exclusion": _exclusion(owner, event, frame)
		"exodia": _exodia(owner, event, frame)
		"destiny_board": _board(owner, event, frame)
		"destiny_letter": _board_letter(owner, int(event["letter"]), board_state(frame * 4, int(event["letter"]), event["source_pos"], false))
		"coin": _coin(owner, event, frame)
		"dice": _dice(owner, event, frame)
		"fusion": _fusion(owner, event, frame)
		_: return false
	return true

## Ka42fad0 y Jo43dbe0 incrementan el contador antes de dibujar.
static func exclusion_state(frame: int) -> Dictionary:
	var counter := 64 + (frame + 1) * 8
	var wave := cosine(counter - 128)
	return {"counter": counter, "card": counter < 128,
		"beam": counter <= 128, "beam_alpha": cosine(counter * 2 - 256) >> 8,
		"glow": counter >= 96, "glow_alpha": (cosine(counter * 4) if counter <= 128 else wave) >> 8,
		"scale": 256 if counter <= 128 else 128 + (wave >> 9),
		"particle": counter > 128, "particle_frame": (counter / 8) % 6 + 1,
		"particle_alpha": wave >> 7}

static func _exclusion(owner: Node2D, event: Dictionary, frame: int) -> void:
	var state := exclusion_state(frame)
	var center: Vector2 = event["center"]
	if state.card:
		owner._card(event.get("card", 0), center, not event.get("hidden", false), MINI_SIZE, PI if event.get("p", 0) == 1 else 0.0)
	if state.particle:
		_exclusion_asset(owner, "jyoga_ryusi%d" % state.particle_frame, center, state.scale, state.scale, state.particle_alpha)
	if state.beam:
		for n in 3:
			var beam := _exclusion_asset(owner, "jyoga_hikatate", center, state.beam_alpha, 256, state.beam_alpha)
			if beam:
				beam.position.x += (n - 1) * (beam.texture.get_width() + 1)
	if state.glow:
		_exclusion_asset(owner, "jyoga_hikacard", center, state.scale, state.scale, state.glow_alpha)

static func _exclusion_asset(owner: Node2D, asset: String, center: Vector2, sx: int, sy: int, alpha: int) -> Sprite2D:
	var sprite: Sprite2D = owner._asset(asset, center, 1.0, clampi(alpha, 0, 255) / 256.0)
	if sprite:
		var size := sprite.texture.get_size()
		var scaled := Vector2((int(size.x) * sx) >> 8, (int(size.y) * sy) >> 8)
		sprite.scale = scaled / size
		# El original coloca la esquina con division entera hacia cero.
		sprite.position += scaled / 2 - Vector2(int(scaled.x / 2), int(scaled.y / 2))
	return sprite

static func _sheet(owner: Node2D, name: String, count: int, index: int, pos: Vector2, scale_value: float = 1.0, alpha: float = 1.0) -> Sprite2D:
	var sprite: Sprite2D = owner._asset(name, pos, scale_value, alpha)
	if sprite:
		sprite.hframes = count
		sprite.frame = posmod(index, count)
	return sprite

static func _background(owner: Node2D, color: Color = Color.BLACK) -> void:
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(800, 0), Vector2(800, 600), Vector2(0, 600)])
	background.color = color
	owner.add_child(background)

static func exodia_card_position(n: int) -> Vector2:
	var angle := int(n * 512 / 5)
	return Vector2(400 + int(cosine(angle+128)*200/65536),300-int(cosine(angle)*200/65536))

static func exodia_ball_state(counter: int) -> Dictionary:
	if counter < 644:
		var q := counter-572
		var blink := (q / 8) & 1
		return {"scale":((q-(4 if blink==0 else 0))*2+112)/256.0,"alpha":clampi(q*4-32,0,255)/256.0}
	if counter < 836:
		return {"scale":0.875 if ((counter-644)/8&1)==0 else 1.0,"alpha":1.0}
	return {"scale":(counter-828)/8.0,"alpha":1.0,"hole_radius":int((counter-836)*15/4)}

## 43bff0: dos extracciones por pieza durante el barrido, en orden de dibujo.
## Repetir el dibujo para interpolar el mismo tick no crea mas objetos ni consume MT.
static func exodia_particles(event: Dictionary, frame: int) -> void:
	if int(event.get("particle_frame", -1)) == frame:
		return
	event["particle_frame"] = frame
	var counter := frame * 4
	if counter < 316 or counter >= 444:
		return
	var scan := (counter - 316) * 2
	var height := int(201 * scan / 256)
	if height <= 28 or height >= scan - 28:
		return
	var visual_rng: UiRandom = event.get("particle_rng")
	var particles: Array = event.get_or_add("particles", [])
	for n in 5:
		var center := exodia_card_position(n)
		for pair in 2:
			var x := int((visual_rng.next() if visual_rng else UiRandom.draw()) % 100) - 50
			particles.append({"birth": frame, "pos": center + Vector2(x, height - int(scan / 2))})

static func _exodia(owner: Node2D, event: Dictionary, frame: int) -> void:
	var counter := maxi(0, frame * 4)
	exodia_particles(event, frame)
	# 43bff0 copies surface2 (the shaded duel), never a black clear.
	_background(owner, Color(0, 0, 0, 0.5))
	if counter < 572:
		for n in 5:
			var pos := exodia_card_position(n)
			if counter < 316:
				var alpha := clampi(counter*16-n*1024,0,255)
				owner._asset("card_hikari",pos+Vector2(0,int((256-alpha)/4)),1,alpha/256.0,0,"exodia")
			else:
				var factor := 1.0
				var alpha := 1.0
				if counter >= 508:
					factor += (counter-508)/128.0
					alpha = (255-(counter-508)*4)/256.0
				var card: Sprite2D = owner._card(EXODIA_CARDS[n],pos,true,CARD_SIZE*factor)
				if card: card.modulate.a=clampf(alpha,0,1)
				if counter < 444:
					var scan := (counter-316)*2
					var texture := _texture(owner,"card_hikari","exodia")
					var glow: Sprite2D = owner._asset("card_hikari",pos,1,1,0,"exodia")
					if glow:
						var visible_height := int(texture.get_height()*scan/256)
						glow.region_enabled=true
						glow.region_rect=Rect2(0,0,texture.get_width(),visible_height)
						glow.position.y=pos.y-int(scan/2)+int(visible_height/2)
		for particle in event.get("particles",[]):
			var age := frame-int(particle.birth)
			if age>=0 and age<6:
				var sprite: Sprite2D=owner._asset("effe_hikari",particle.pos,1,1,0,"exodia")
				if sprite:
					sprite.hframes=6
					sprite.frame=age
		return
	if counter >= 1060: return
	var first_part := owner.get_child_count()
	# 43c633..43c95a keeps pose1 in surface1 and overlays pose2 on alternate
	# ticks. The small luminous pieces are highlights, not replacement limbs.
	var stage := 3 if counter >= 836 else 1
	_exodia_pose(owner, stage, counter)
	if counter >= 644 and counter < 836 and ((counter - 644) / 8 % 2) != 0:
		_exodia_pose(owner, 2, counter)
	var drop := int((255-clampi((counter-572)*4,0,255))/4) if counter<644 else 0
	if counter >= 836:
		# 43c249..43c34a stores pose3 AND the original-size ball in surface1.
		# The four clipped enlarged copies are drawn onto that retained image.
		owner._asset("exo_ball",Vector2(400,409),1,1,0,"exodia")
	else:
		var ball := exodia_ball_state(counter)
		owner._asset("exo_ball",Vector2(400,409+drop),ball.scale,ball.alpha,0,"exodia")
	if counter >= 836:
		if _ball_shader == null:
			_ball_shader = Shader.new()
			_ball_shader.code = "shader_type canvas_item; varying vec2 screen_pos; uniform float hole_radius; void vertex(){screen_pos=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;} void fragment(){vec2 d=abs(screen_pos-vec2(400.0,409.0)); if(d.x<hole_radius && d.y<hole_radius){discard;} COLOR=texture(TEXTURE,UV)*COLOR; }"
		# Surface1 is NOT cleared between attack ticks. Reconstruct its retained
		# draws, or the growing clip exposes a rectangular hole in the attack.
		for birth in range(836, mini(counter, 1024) + 1, 4):
			var ball := exodia_ball_state(birth)
			var sprite: Sprite2D = owner._asset("exo_ball",Vector2(400,409),ball.scale,1,0,"exodia")
			if sprite == null: continue
			sprite.set_meta("blend_key", ["exodia-ball", birth])
			var material := ShaderMaterial.new()
			material.shader = _ball_shader
			material.set_shader_parameter("hole_radius",int(ball.hole_radius))
			sprite.material = material
	if counter >= 1028:
		# 43c0f0 -> 4160a0: close the retained attack toward the centre with
		# two 32-row feathered bands, revealing surface2; no white flash.
		if _exodia_wipe_shader == null:
			_exodia_wipe_shader = Shader.new()
			_exodia_wipe_shader.code = "shader_type canvas_item; render_mode unshaded; uniform sampler2D retained : hint_screen_texture, repeat_disable, filter_nearest; varying float logical_y; uniform float wipe_half_height; void vertex(){logical_y=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).y;} void fragment(){vec4 c=textureLod(retained,SCREEN_UV,0.0); if(c.a>0.0001){c.rgb/=c.a;} COLOR*=c; COLOR.a*=clamp((wipe_half_height+32.0-abs(logical_y-300.0))/32.0,0.0,1.0); }"
		# Blend the retained surface once, including the overlapping ball draws.
		var parts := owner.get_children().slice(first_part)
		var group := CanvasGroup.new()
		var material := ShaderMaterial.new()
		material.shader = _exodia_wipe_shader
		material.set_shader_parameter("wipe_half_height", (1060-counter)*300/32.0)
		group.material = material
		owner.add_child(group)
		for part in parts: part.reparent(group)

static func _exodia_pose(owner: Node2D, stage: int, counter: int) -> void:
	var face := Vector2(400+(2 if stage==2 else 1),271 if stage==2 else 178)
	var arm_x := 101 if stage==2 else 233 if stage==3 else 167
	var arm_y := 370 if stage==2 else 315 if stage==3 else 289
	var alpha := clampi((counter-572)*4,0,255)
	var drop := int((255-alpha)/4) if counter<644 else 0
	owner._asset("exo_arm%d"%stage,Vector2(400-arm_x,arm_y+drop),1,alpha/256.0,0,"exodia")
	owner._asset("exo_arml%d"%stage,Vector2(400+arm_x,arm_y),1,alpha/256.0,0,"exodia")
	owner._asset("exo_face%d"%stage,face+Vector2(0,drop),1,alpha/256.0,0,"exodia")

static func _coin(owner: Node2D, event: Dictionary, frame: int) -> void:
	var args: Array = event.get("args", [])
	var count := 3 if int(event.get("op", 0xe0)) == 0xe1 else 1
	var result := int(event.get("result", 0))
	var choice := 1
	if not args.is_empty():
		result = ~int(args[1]) if count == 3 else int(int(args[1]) == 0)
		choice = int(int(args[0]) == 0)
	var origin: Vector2 = event.get("source_pos", event.get("center", Vector2(525, 300)))
	var counter := -128 + frame * 8
	for n in count:
		var state := coin_state(counter, count, n, result, origin)
		if not state.visible: continue
		var pos: Vector2 = state.pos
		var alpha := int(state.alpha) / 256.0
		var zoom := int(state.zoom)
		var q := int(state.q)
		if q > 0 and q < 256:
			_sheet(owner, "coin_sha", 4, state.shadow, pos + Vector2.ONE * int(zoom * 25 / 256), minf(1, zoom / 256.0), alpha)
		else: _sheet(owner, "coin_sha", 4, 0, pos + Vector2.ONE, 1, alpha)
		_sheet(owner, "coin_rotate", 14, state.face, pos + Vector2(0, state.elevation), zoom / 256.0, alpha)
		if q >= 256 and q < 320:
			owner._asset("coin_ripple", pos, (2 * q - 256) / 256.0, (320 - q) / 64.0)
		if ((result >> n) & 1) != choice: continue
		var end := int(state.end)
		if end >= -320 and end < -192:
			var reflection: Sprite2D = owner._asset("coin_mask", pos, 1, alpha)
			if reflection:
				if _reflection_shader == null:
					_reflection_shader = Shader.new()
					_reflection_shader.code = "shader_type canvas_item; uniform sampler2D shine; uniform float shift; void fragment(){ vec4 tint=COLOR; float mask=texture(TEXTURE,UV).b; float x=(UV.x*40.0-shift)/69.0; vec3 fill=texture(shine,vec2(clamp(x,0.0,1.0),UV.y)).rgb; float inside=step(0.0,x)*step(x,1.0); COLOR=vec4(fill*tint.rgb,mask*tint.a*inside); }"
				var material := ShaderMaterial.new()
				material.shader = _reflection_shader
				material.set_shader_parameter("shine", _texture(owner,"coin_ref"))
				material.set_shader_parameter("shift", int(109 * (end + 320) * 2 / 256) - 69)
				reflection.material = material
		for star in 5:
			var sparkle := end + 256 - star * 16
			if sparkle >= 0 and sparkle < 64:
				var star_frame: int = [3,2,1,0,0,1,2,3][sparkle / 8]
				var offset := Vector2(int(sparkle * star / 4) - int(star / 2), int(((sparkle + star * 2) & 7) * 14 / 8) - 14)
				_sheet(owner, "coin_kirari", 4, star_frame, pos + offset)

static func _texture(owner: Node2D, name: String, folder: String = "effect") -> Texture2D:
	var path := "%s/duel/%s/%s.png" % [owner.game,folder,name]
	var assets := owner.get_node("/root/Assets")
	return assets.texture(path)

static func dice_state(counter: int, result: int, source: Vector2) -> Dictionary:
	var upper := source.y < 300
	var pos := source
	for q in range(8, mini(counter,384) + 1, 8):
		var rest := int((384 - q) / 8)
		pos = Vector2(int((int(pos.x) - 525) * rest / (rest + 1)) + 525, int((int(pos.y) - (236 if upper else 364)) * rest / (rest + 1)) + (236 if upper else 364))
	if counter > 384 and counter <= 448: pos = Vector2(525,counter - 148 if upper else 748 - counter)
	elif counter > 448: pos = Vector2(525,300)
	var wave := (cosine(counter - 128) >> 7) if counter >= 0 and counter < 256 else (cosine((counter * 2 & 255) - 128) >> 9) if counter >= 256 and counter < 384 else 0
	var zoom := 256 + int(wave / 2)
	if counter < -192: zoom = counter * 4 + 1024
	var selector: int = 0 if counter <= 256 else [4,4,2,2,2,4][clampi(result,1,6) - 1]
	var offset: int = [8,4,8,0,4,0][clampi(result,1,6) - 1]
	var pattern := int(counter / 8) + 256 + offset if upper else 255 - int(counter / 8) - offset
	return {"pos":pos,"wave":wave,"zoom":zoom,"selector":selector,"pattern":posmod(pattern,6 if selector == 0 else 16),"shadow_pattern":posmod(pattern,6 if selector == 0 else 4),"alpha":clampi((768-counter)*4 if counter>704 else 256,0,256)}

static func _dice(owner: Node2D, event: Dictionary, frame: int) -> void:
	var counter := -256 + frame * 8
	var source: Vector2 = event.get("source_pos", event.get("center", Vector2(525,300)))
	var result := clampi(int(event.get("result", 1)), 1, 6)
	var args: Array = event.get("args", [])
	if not args.is_empty(): result = clampi(int(args[0]),1,6)
	var state := dice_state(counter,result,source)
	var pos: Vector2 = state.pos
	var alpha := int(state.alpha) / 256.0
	var zoom := int(state.zoom)
	if counter < 448:
		var selector := int(state.selector)
		var wave := int(state.wave)
		var offset := Vector2(int(zoom * 7 / 256) + int(wave * 25 / 256),int(zoom * 9 / 256) + int(wave * 25 / 256))
		_sheet(owner,"dice_shadow" if selector == 0 else "dice_shadow2",6 if selector == 0 else 4,state.shadow_pattern,pos+offset,minf(1,zoom/256.0),alpha)
		var sheet := "dice_random" if selector == 0 else "dice_ani_2453" if selector == 2 else "dice_ani_5621"
		_sheet(owner,sheet,6 if selector == 0 else 16,state.pattern,pos+Vector2(0,int(wave * -50 / 256)),zoom/256.0,alpha)
	else:
		owner._asset("dice_dci_sha",pos,1,alpha)
		owner._asset("dice_decide%d" % result,pos,1,alpha)

static func _fusion(owner: Node2D, event: Dictionary, frame: int) -> void:
	var counter := frame * 4
	# Mantener visible la mesa bajo el mismo velo semitransparente del resultado.
	_background(owner, Color(0, 0, 0, 0.5))
	var materials: Array = []
	for id in event.get("materials",[]):
		if id >= 0 and id != 0xffff: materials.append(id)
	var state := fusion_state(counter,materials.size())
	var center := Vector2(400,300)
	var rotation := int(state.rotation) * TAU / 512.0
	owner._asset("fusion_uzu",center,absf(int(state.swirl_scale)/65536.0),clampf(int(state.swirl_alpha)/256.0,0,1),rotation)
	if counter >= 384 and counter < 448:
		owner._asset("fusion_cir",center,absf((cosine(counter*2+128)*2+32768)/65536.0),clampf((cosine(counter*2-256)>>8)/256.0,0,1),rotation)
	var trail := mini(counter & ~31,256)
	var radius_tick := counter-trail
	var patterns := [3,4,5,4,3,0,6,7,8,7,6,0]
	while trail > 0:
		if radius_tick < 128:
			var radius := cosine(radius_tick) >> 7
			for n in 4:
				var resource: int = patterns[posmod(int(counter/4)-trail+counter+n,12)]
				if resource != 0:
					var angle := n*128+trail*2-counter+int(state.rotation)
					var pos := Vector2(400+((cosine(angle)*radius)>>16),300+((cosine(angle-128)*radius)>>16))
					owner._asset("fu_kira_%s%d" % ["a" if resource<6 else "b",resource-2 if resource<6 else resource-5],pos)
		trail-=32
		radius_tick+=32
	if counter < 384:
		var size := MINI_SIZE
		if counter < 32: size = Vector2(int(50*counter/32),144-int(72*counter/32))
		for n in materials.size(): owner._card(materials[n],state.positions[n],true,size)
	else:
		var card: Sprite2D = owner._card(int(event.get("card",0)),center,true,MINI_SIZE)
		if card and counter < 512:
			var glow: Sprite2D = owner._card(int(event.get("card",0)),center,true,MINI_SIZE)
			if glow:
				glow.modulate.a=clampf((512-counter)*2/256.0,0,1)
				var add := CanvasItemMaterial.new()
				add.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
				glow.material=add

static func _board(owner: Node2D, event: Dictionary, frame: int) -> void:
	_background(owner)
	var sources: Array=event.get("sources",[])
	for n in event.get("letters", [0, 1, 2, 3, 4]):
		var source: Vector2=sources[n] if n<sources.size() else Vector2(400,300)
		var state:=board_state(frame*4,n,source)
		_board_letter(owner, n, state)

static func _board_letter(owner: Node2D, n: int, state: Dictionary) -> void:
	if not state.visible: return
	var q:=int(state.q)
	var pos: Vector2=state.pos
	var alpha:=int(state.alpha)/256.0
	_sheet(owner,"vija_smoke",5,state.smoke_frame,pos-Vector2(0,4),int(state.smoke_scale)/256.0,alpha)
	if q>=64:
		# 43bbxx composición máscara y color desplazado; 43bcf3 por filas.
		var letter_pos:=pos+Vector2(0,49.5)
		_sheet(owner,"vija_moji_smo",8,int(q/8)%8,letter_pos,1,alpha)
		var letter:=_sheet(owner,"vija_moji_mask",5,n,letter_pos,1,alpha)
		if letter:
			# El original traslada cada fila hasta16px fuera del rectángulo de32px.
			# Ampliar el quad conserva esos extremos; el shader limita la letra fuente.
			letter.hframes=1
			letter.frame=0
			letter.region_enabled=true
			letter.region_rect=Rect2(n*32-16,0,64,37)
			letter.scale.x=int(state.letter_width)/256.0
			if _board_shader==null:
				_board_shader=Shader.new()
				_board_shader.code="shader_type canvas_item; uniform sampler2D ink; uniform float counter; uniform float amplitude; uniform float width_scale; uniform float letter_index; void fragment(){vec4 tint=COLOR; float row=floor(UV.y*37.0); float angle=mod((counter-64.0)*8.0-128.0+row*16.0,512.0); float fx=trunc(cos(angle*3.141592653589793/256.0)*65536.0); float shift=floor(fx*amplitude/65536.0); vec2 uv=vec2(UV.x-shift/(160.0*max(width_scale,0.001)),UV.y); float inside=step(letter_index/5.0,uv.x)*step(uv.x,(letter_index+1.0)/5.0); float mask=texture(TEXTURE,uv).b*inside; vec3 fill=texture(ink,vec2(fract(uv.x-counter/160.0),uv.y)).rgb; COLOR=vec4(fill*tint.rgb,mask*tint.a);}"
			var material:=ShaderMaterial.new()
			material.shader=_board_shader
			material.set_shader_parameter("ink",_texture(owner,"vija_moji_iro"))
			material.set_shader_parameter("counter",q)
			material.set_shader_parameter("amplitude",int(state.distortion))
			material.set_shader_parameter("width_scale",int(state.letter_width)/256.0)
			material.set_shader_parameter("letter_index",n)
			letter.material=material
	if q>=32:
		_sheet(owner,"vija_skel",5,state.bone_frame,pos+Vector2(0,24.5+int(state.bone_y)),1,alpha)
