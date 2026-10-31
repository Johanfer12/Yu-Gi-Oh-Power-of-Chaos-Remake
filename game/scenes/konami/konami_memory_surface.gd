class_name KonamiMemorySurface
extends KonamiSurface
## Superficie de memoria de la libreria de Konami (4aba00) con los copiadores de pixeles del
## original sobre un destino de 32 bits (formato 7, XRGB). Las imagenes origen pueden ser de
## formato 7 o 12 (con alfa, +0x78). Contrato sacado de Joey y comprobado pixel a pixel contra
## los copiadores ejecutados en Unicorn (re/scripts/konami_pixel_oracle.py, konami_pixels_test.gd).
## La profundidad de 16 bits del original es una diferencia aceptada (D18).
##
## Argumentos opcionales de los copiadores, como en el original (puntero nulo = null o 0):
## rectangulo de origen [izq, arr, der, aba], tamano escalado [ancho, alto] y recorte del destino.
## El recorte se ajusta al rectangulo del destino; el escalado es el de 547180 (Bresenham por eje).

const FORMAT_XRGB := 7
const FORMAT_ALPHA := 12

var format := FORMAT_XRGB
var pixels := PackedByteArray()  # B, G, R, X/A por pixel; paso width * 4


static func create(w: int, h: int, fmt: int, data := PackedByteArray()) -> KonamiMemorySurface:
	var s := KonamiMemorySurface.new()
	s.width = w
	s.height = h
	s.format = fmt
	s.flag_78 = fmt > 9
	s.pixels = data if not data.is_empty() else PackedByteArray()
	if s.pixels.is_empty():
		s.pixels.resize(w * h * 4)
	return s


## +0x08 4b1760: copia opaca: el RGB del origen y el cuarto byte a cero.
func slot_08(src: Variant, x: int, y: int, a4: Variant, a5: Variant, a6: Variant) -> int:
	return _blit(src, x, y, a4, a5, a6, &"copy", 255)


## +0x0c 4ad9c0: mismo resultado que +0x08 en los casos del oraculo.
func slot_0c(src: Variant, x: int, y: int, a4: Variant, a5: Variant, a6: Variant) -> int:
	return _blit(src, x, y, a4, a5, a6, &"copy", 255)


## +0x78 4c8500: mezcla dst + trunc((src - dst) * e / 255), e = nivel (o nivel * alfa / 255).
func slot_78(src: Variant, x: int, y: int, alpha: int, a5: Variant, a6: Variant, a7: Variant) -> int:
	return _blit(src, x, y, a5, a6, a7, &"mix", alpha)


## +0x7c 4c7830: igual que +0x78.
func slot_7c(src: Variant, x: int, y: int, alpha: int, a5: Variant, a6: Variant, a7: Variant) -> int:
	return _blit(src, x, y, a5, a6, a7, &"mix", alpha)


## +0x8c 4cb740: mezcla con el alfa de la imagen; solo imagenes con alfa (si no, devuelve 2).
func slot_8c(src: Variant, x: int, y: int, a4: Variant, a5: Variant, a6: Variant) -> int:
	if not (src as KonamiMemorySurface).flag_78:
		return 2
	return _blit(src, x, y, a4, a5, a6, &"mix", 255)


## +0x90 4cbe20: mezcla con nivel * alfa / 255; solo imagenes con alfa (si no, devuelve 2).
func slot_90(src: Variant, x: int, y: int, alpha: int, a5: Variant, a6: Variant, a7: Variant) -> int:
	if not (src as KonamiMemorySurface).flag_78:
		return 2
	return _blit(src, x, y, a5, a6, a7, &"mix", alpha)


## +0x9c 4ef870: suma con saturacion (con alfa: src * alfa / 255).
func slot_9c(src: Variant, x: int, y: int, a4: Variant, a5: Variant, a6: Variant) -> int:
	return _blit(src, x, y, a4, a5, a6, &"add", 255)


## +0xa0 4eec70: igual que +0x9c.
func slot_a0(src: Variant, x: int, y: int, a4: Variant, a5: Variant, a6: Variant) -> int:
	return _blit(src, x, y, a4, a5, a6, &"add", 255)


## +0xa4 4f23c0: resta con saturacion (con alfa: src * alfa / 255).
func slot_a4(src: Variant, x: int, y: int, a4: Variant, a5: Variant, a6: Variant) -> int:
	return _blit(src, x, y, a4, a5, a6, &"sub", 255)


## +0xa8 4f17b0: igual que +0xa4.
func slot_a8(src: Variant, x: int, y: int, a4: Variant, a5: Variant, a6: Variant) -> int:
	return _blit(src, x, y, a4, a5, a6, &"sub", 255)


## +0xac 4f0860: suma src * nivel / 255 con saturacion; el alfa de la imagen no cuenta. Nivel
## 0xff (char -1) llama a +0xa0.
func slot_ac(src: Variant, x: int, y: int, a: int, b: Variant, c: Variant, d: Variant) -> int:
	if a & 0xff == 0xff:
		return slot_a0(src, x, y, b, c, d)
	return _blit(src, x, y, b, c, d, &"add_level", a & 0xff)


## +0xb0 4f4300: como +0xac; nivel 0xff llama a +0x9c.
func slot_b0(src: Variant, x: int, y: int, a: int, b: Variant, c: Variant, d: Variant) -> int:
	if a & 0xff == 0xff:
		return slot_9c(src, x, y, b, c, d)
	return _blit(src, x, y, b, c, d, &"add_level", a & 0xff)


## +0xb4 4f33b0: resta src * nivel / 255 con saturacion; nivel 0xff llama a +0xa8.
func slot_b4(src: Variant, x: int, y: int, a: int, b: Variant, c: Variant, d: Variant) -> int:
	if a & 0xff == 0xff:
		return slot_a8(src, x, y, b, c, d)
	return _blit(src, x, y, b, c, d, &"sub_level", a & 0xff)


## +0xb8 4f53f0: como +0xb4; nivel 0xff llama a +0xa4.
func slot_b8(src: Variant, x: int, y: int, a: int, b: Variant, c: Variant, d: Variant) -> int:
	if a & 0xff == 0xff:
		return slot_a4(src, x, y, b, c, d)
	return _blit(src, x, y, b, c, d, &"sub_level", a & 0xff)


## Recorte (547180) y bucle de pixeles comun a los copiadores.
func _blit(src_value: Variant, x: int, y: int, src_rect: Variant, scale: Variant, clip: Variant,
		op: StringName, level: int) -> int:
	var src := src_value as KonamiMemorySurface
	var sr: Array = src_rect if src_rect is Array else [0, 0, src.width, src.height]
	var size: Array = scale if scale is Array else [int(sr[2]) - int(sr[0]), int(sr[3]) - int(sr[1])]
	var box: Array = clip if clip is Array else [0, 0, width, height]
	var lo := Vector2i(maxi(int(box[0]), 0), maxi(int(box[1]), 0))
	var hi := Vector2i(mini(int(box[2]), width), mini(int(box[3]), height))
	var rows := _axis(y, int(sr[1]), int(sr[3]) - int(sr[1]), int(size[1]), lo.y, hi.y)
	var cols := _axis(x, int(sr[0]), int(sr[2]) - int(sr[0]), int(size[0]), lo.x, hi.x)
	var with_alpha := src.flag_78
	var s := src.pixels
	for row in rows:
		var d_row := row.x * width * 4
		var s_row := row.y * src.width * 4
		for col in cols:
			var di := d_row + col.x * 4
			var si := s_row + col.y * 4
			var a := s[si + 3] if with_alpha else 255
			match op:
				&"copy":
					for c in 3:
						pixels[di + c] = s[si + c]
					pixels[di + 3] = 0
				&"mix":
					var e := (level * a) / 255 if with_alpha else level
					for c in 3:
						var dst := pixels[di + c]
						var diff := s[si + c] - dst
						var m := (absi(diff) * e) / 255
						pixels[di + c] = dst + (m if diff >= 0 else -m)
				&"add":
					for c in 3:
						var v := (s[si + c] * a) / 255 if with_alpha else s[si + c]
						pixels[di + c] = mini(pixels[di + c] + v, 255)
				&"sub":
					for c in 3:
						var v := (s[si + c] * a) / 255 if with_alpha else s[si + c]
						pixels[di + c] = maxi(pixels[di + c] - v, 0)
				&"add_level":
					for c in 3:
						pixels[di + c] = mini(pixels[di + c] + (s[si + c] * level) / 255, 255)
				&"sub_level":
					for c in 3:
						pixels[di + c] = maxi(pixels[di + c] - (s[si + c] * level) / 255, 0)
	return 0


## Un eje del copiador: pares (coordenada del destino, coordenada del origen). Sin escalado,
## recorte directo. Con escalado, el Bresenham de 547180: error inicial -D (mas el recorte por la
## izquierda) menos 1; por pixel suma S mod D, avanza uno si llega a 0 (restando D), dibuja y
## avanza S div D.
static func _axis(pos: int, src0: int, src_size: int, dest_size: int, lo: int, hi: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if dest_size == src_size:
		for at in range(maxi(pos, lo), mini(pos + src_size, hi)):
			out.append(Vector2i(at, src0 + at - pos))
		return out
	var left := pos
	var err := -dest_size
	var s := src0
	if lo - left > 0:
		err += (lo - left) * src_size
		if err > 0:
			var k := err / dest_size + 1
			s += k
			err -= k * dest_size
		left = lo
	var right := mini(pos + dest_size, hi)
	err -= 1
	for at in range(left, right):
		err += src_size % dest_size
		if err >= 0:
			s += 1
			err -= dest_size
		out.append(Vector2i(at, s))
		s += src_size / dest_size
	return out
