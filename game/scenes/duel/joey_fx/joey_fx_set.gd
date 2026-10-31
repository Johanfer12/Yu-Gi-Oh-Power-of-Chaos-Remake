class_name JoeyFxSet
extends RefCounted
## Efecto de colocar carta de Joey: clase de 44efd0 (vtable 5db2c4). Port funcion a funcion de
## sus metodos por tick: 44f370 (vtable+8, avanza) y 44f390 (vtable+0xc, dibuja). El dibujo pasa
## por la superficie de la libreria de Konami (KonamiSurface, +0xac y +0xb0); el oraculo
## generico las registra y compara (re/scripts/presentation_specs/joey_set.py, presentation_oracle_test.gd).

const Math := preload("res://scenes/duel/duel_visual_math.gd")

var counter := 0          # +0x10
var center := Vector2i()  # +0x14, +0x18 (45c140 de la zona)
var ref := 0              # +0x1c: palabra de 452f20 (bit 0 jugador, bit 14 posicion, bit 15 cara)
var monster := false      # +0x1e: 402690 de la carta (monstruo: marco amarillo)
var alive := true         # +4
var points: Array[Vector2i] = []  # +0x104: ocho destellos (x, y)


## 44efd0, bucle final: ocho puntos a radio (MT & 31) + 16 alrededor del centro.
func place_points(draw: Callable) -> void:
	points.clear()
	for step in range(0, 0x1000, 0x200):
		var radius := (int(draw.call()) & 31) + 16
		var angle := Math.trunc_div(step, 8)
		points.append(center + Vector2i((Math.cos_fx(angle) * radius) >> 16, (Math.cos_fx(angle - 0x80) * radius) >> 16))


## 44f370: +0xc por tick; sigue vivo mientras el contador no pase de 0x100.
func f44f370() -> void:
	counter += 0xc
	alive = counter < 0x101


## 44f390(destino): copia luminosa de la carta, el marco que gira y crece (422c00: giro, escala
## x/y, alfa) y los destellos que caen.
func f44f390(s: Object, mode: int) -> void:
	var c := counter
	var spin := (-Math.cos_fx(Math.trunc_div(c, 2) & 0x1ff)) >> 8
	var scale := 0x10000 if c < 0x80 else c << 9
	var light := (Math.cos_fx((c - 0x80) & 0x1ff) * 0xb0) >> 16
	# Giro de 41f2e0 en grados: bit 14 de la palabra y lado respecto del jugador local.
	var side := ((~mode) & 1) ^ ((~ref) & 1)
	var card: Variant = s.card_image((((ref >> 14) & 1) + side * 2) * 90)
	var card_size: Vector2i = s.image_size(card)
	s.slot_ac(card, center.x - Math.trunc_div(card_size.x, 2), center.y - Math.trunc_div(card_size.y, 2),
		Math.cos_fx((c - 0x80) & 0x1ff) >> 9, 0, 0, 0)
	var frame: int = s.frame(int(not monster))
	s.pick(frame, -1)
	s.card(s.sprite(frame), center.x, center.y, spin, scale, scale, light)
	frame = s.frame(2)
	s.pick(frame, -1)
	var star_size: Vector2i = s.image_size(s.sprite(frame))
	for k in 8:
		var d := c - k * 0x10
		var q := Math.trunc_div(d, 8)
		if d < 0: continue
		frame = s.frame((q & 1) + 2 + int(not monster) * 2)
		s.pick(frame, -1)
		var at := points[k]
		s.slot_b0(s.sprite(frame), at.x - Math.trunc_div(star_size.x, 2),
			at.y - Math.trunc_div(q * q, 16) - Math.trunc_div(star_size.y, 2), light, 0, 0, 0)
