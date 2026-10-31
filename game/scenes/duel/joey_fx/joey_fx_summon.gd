class_name JoeyFxSummon
extends RefCounted
## Efecto de invocar de Joey: clase de 44f630 (vtable 5db2d4). Port funcion a funcion de sus
## metodos por tick: 44f9f0 (vtable+8, avanza) y 44fa10 (vtable+0xc, dibuja). Dibuja por la
## superficie de Konami (KonamiSurface +0x18) y las listas de sprites; el oraculo generico lo
## compara con el original (re/scripts/presentation_specs/joey_summon.py, presentation_oracle_test.gd).

const Math := preload("res://scenes/duel/duel_visual_math.gd")

var counter := 0          # +0x10
var center := Vector2i()  # +0x14, +0x18 (45c140 de la zona)
var ref := 0              # +0x1c: palabra de la carta (bit 0 jugador, bit 14 posicion)
var index := 0            # +0x20: entrada de la lista global de imagenes de cartas (5f2ff8)
var card_size := Vector2i(50, 72)  # 5f3004, 5f3008: tamano de la carta en el campo
var alive := true         # +4


## 44f9f0: +8 por tick; sigue vivo mientras el contador no pase de 0x100.
func f44f9f0() -> void:
	counter += 8
	alive = counter < 0x101


## 44fa10(destino): la carta crece girada hasta escala 0x8000 (422c00) y despues el arco iris de
## summon.txt baja por el hueco de la carta con +0x18 (rectangulo de origen que da la vuelta).
func f44fa10(s: Object, mode: int) -> void:
	var c := counter
	var scale := (c + 0x40) << 8
	# Giro en unidades de 512 por vuelta: bit 14 de la palabra y lado respecto del jugador local.
	var side := ((~mode) & 1) ^ ((~ref) & 1)
	var angle := (((ref >> 14) & 1) + side * 2) << 7
	if scale <= 0x8000:
		var alpha := Math.cos_fx((c + 0x38) & 0x1ff) >> 8
		var card: int = s.list_select("cards", index)
		s.list_pick("cards", card, -1)
		s.card(s.list_image("cards", card), center.x, center.y, angle, scale, scale, alpha)
		return
	var level := mini((Math.cos_fx((c - 0xa0) & 0x1ff) * 3) >> 10, 0xff)
	var entry: int = s.frame(0)
	s.pick(entry, -1)
	var rainbow_height: int = s.image_size(s.sprite(entry)).y
	var offset := Math.trunc_div(c * 5, 8) % rainbow_height
	var w := card_size.x
	var h := card_size.y
	if ref & 0x4000:
		w = card_size.y
		h = card_size.x
	var end := (offset + h) % rainbow_height
	var top := [0, offset, w, end]
	var left := center.x - Math.trunc_div(w, 2)
	var y := center.y - Math.trunc_div(h, 2)
	if end < offset:
		# La franja da la vuelta: primero lo que falta desde la fila 0, debajo del primer tramo.
		entry = s.frame(0)
		s.pick(entry, -1)
		s.slot_18(s.sprite(entry), left, y - offset + rainbow_height, level, [0, 0, w, end], null, null)
		top[3] = rainbow_height
	entry = s.frame(0)
	s.pick(entry, -1)
	s.slot_18(s.sprite(entry), left, y, level, top, null, null)
