class_name KonamiSurface
extends RefCounted
## Frontera con la libreria de Konami: la superficie sobre la que dibujan todas las pantallas
## (docs/FRONTERA_KONAMI.md). Las imagenes cargadas tambien son superficies. La clase base tiene
## 57 metodos virtuales con la misma disposicion en los tres juegos; aqui cada uno se llama
## slot_<desplazamiento> y lleva la direccion de Joey (vtable 5dc6ec; Yugi 59ac68, Kaiba 59dc88).
##
## Los metodos que solo reenvian a otro metodo o devuelven un campo se portan tal cual del
## desensamblado. Los copiadores de pixeles (+0x08, +0x0c, +0x78..+0x98, +0x9c..+0xb8) son las
## hojas: los implementa cada destino (JoeyFxCanvas dibuja con sprites de Godot). Una hoja que el
## destino no implementa avisa una vez y no dibuja.
## Estado de cada metodo en su comentario: verificada (oraculo del original), implementada o
## PENDIENTE; re/scripts/konami_frontier.py lo lee para el inventario.

var width := 0      # +0x3c
var height := 0     # +0x40
var field_4c := 0   # +0x4c: +0x3c pregunta si no es cero
var field_64 := 0   # +0x64: lo devuelve +0x74
var flag_78 := false  # +0x78: lo devuelve +0x40; +0x48/+0x4c eligen copiador con el de la imagen origen

var _warned := {}


## +0x04 41ac10: devuelve 3. verificada (konami_surface_test)
func slot_04() -> int:
	return 3


## +0x08 41ad50: copia opaca (envuelve 4b1760 con los seis argumentos). verificada en 32 bits (konami_pixels_test, KonamiMemorySurface)
func slot_08(src: Variant, x: int, y: int, a4: Variant, a5: Variant, a6: Variant) -> int:
	return _leaf(0x08, [src, x, y, a4, a5, a6])


## +0x0c 41ad20: envuelve 4ad9c0 con los seis argumentos. verificada en 32 bits (konami_pixels_test, KonamiMemorySurface)
func slot_0c(src: Variant, x: int, y: int, a4: Variant, a5: Variant, a6: Variant) -> int:
	return _leaf(0x0c, [src, x, y, a4, a5, a6])


## +0x10 41ada0: reenvia los siete argumentos a +0x78. verificada (konami_surface_test)
func slot_10(src: Variant, x: int, y: int, alpha: int, a5: Variant, a6: Variant, a7: Variant) -> int:
	return slot_78(src, x, y, alpha, a5, a6, a7)


## +0x14 41ad90: devuelve 1 (ocho argumentos). verificada (konami_surface_test)
func slot_14(_a1: Variant = null, _a2 := 0, _a3 := 0, _a4 := 0, _a5 := 0, _a6 := 0, _a7 := 0, _a8 := 0) -> int:
	return 1


## +0x18 41add0: reenvia los siete argumentos a +0x7c. verificada (konami_surface_test)
func slot_18(src: Variant, x: int, y: int, alpha: int, a5: Variant, a6: Variant, a7: Variant) -> int:
	return slot_7c(src, x, y, alpha, a5, a6, a7)


## +0x1c 41ad90: mismo cuerpo que +0x14. verificada (konami_surface_test)
func slot_1c(_a1: Variant = null, _a2 := 0, _a3 := 0, _a4 := 0, _a5 := 0, _a6 := 0, _a7 := 0, _a8 := 0) -> int:
	return 1


## +0x20 41ac60: reenvia los siete argumentos a +0x90. verificada (konami_surface_test)
func slot_20(src: Variant, x: int, y: int, alpha: int, a5: Variant, a6: Variant, a7: Variant) -> int:
	return slot_90(src, x, y, alpha, a5, a6, a7)


## +0x24 41ab30: devuelve 0 (ocho argumentos). verificada (konami_surface_test)
func slot_24(_a1: Variant = null, _a2 := 0, _a3 := 0, _a4 := 0, _a5 := 0, _a6 := 0, _a7 := 0, _a8 := 0) -> int:
	return 0


## +0x28 41ae00: reenvia los seis argumentos a +0x8c. verificada (konami_surface_test)
func slot_28(src: Variant, x: int, y: int, a4: Variant, a5: Variant, a6: Variant) -> int:
	return slot_8c(src, x, y, a4, a5, a6)


## +0x2c 41ae30: +0x90 con los cuatro argumentos y tres ceros. verificada (konami_surface_test)
func slot_2c(src: Variant, x: int, y: int, alpha: int) -> int:
	return slot_90(src, x, y, alpha, null, null, null)


## +0x38 4a9fb0: ancho y alto (+0x3c, +0x40). verificada (konami_surface_test)
func slot_38() -> Vector2i:
	return Vector2i(width, height)


## +0x3c 41ad00: +0x4c distinto de cero. verificada (konami_surface_test)
func slot_3c() -> bool:
	return field_4c != 0


## +0x40 41ad10: byte +0x78. verificada (konami_surface_test)
func slot_40() -> bool:
	return flag_78


## +0x48 41ab90: dibujo con alfa. Desde 0xff es opaco (+0x4c sin el alfa); si no, +0x20 cuando la
## imagen origen tiene +0x78 y +0x10 cuando no. verificada (konami_surface_test)
func slot_48(src: Variant, x: int, y: int, alpha: int, a5: Variant, a6: Variant, a7: Variant) -> int:
	if alpha >= 0xff:
		return slot_4c(src, x, y, a5, a6, a7)
	elif _src_flag(src):
		return slot_20(src, x, y, alpha, a5, a6, a7)
	else:
		return slot_10(src, x, y, alpha, a5, a6, a7)


## +0x4c 41ab40: dibujo opaco: +0x28 si la imagen origen tiene +0x78, +0x08 si no. verificada (konami_surface_test)
func slot_4c(src: Variant, x: int, y: int, a4: Variant, a5: Variant, a6: Variant) -> int:
	if _src_flag(src):
		return slot_28(src, x, y, a4, a5, a6)
	else:
		return slot_08(src, x, y, a4, a5, a6)


## +0x60 41ac20: +0x70 con el color empaquetado (r | g << 8 | b << 16, un byte cada uno). verificada (konami_surface_test)
func slot_60(r: int, g: int, b: int) -> int:
	return slot_70((r & 0xff) | (g & 0xff) << 8 | (b & 0xff) << 16)


## +0x70 4ac140: color empaquetado. PENDIENTE
func slot_70(color: int) -> int:
	return _leaf(0x70, [color])


## +0x74 41ac50: campo +0x64. verificada (konami_surface_test)
func slot_74() -> int:
	return field_64


## +0x78 4c8500: copiador con alfa sin canal propio. verificada en 32 bits (konami_pixels_test, KonamiMemorySurface)
func slot_78(src: Variant, x: int, y: int, alpha: int, a5: Variant, a6: Variant, a7: Variant) -> int:
	return _leaf(0x78, [src, x, y, alpha, a5, a6, a7])


## +0x7c 4c7830: copiador. verificada en 32 bits (konami_pixels_test, KonamiMemorySurface)
func slot_7c(src: Variant, x: int, y: int, alpha: int, a5: Variant, a6: Variant, a7: Variant) -> int:
	return _leaf(0x7c, [src, x, y, alpha, a5, a6, a7])


## +0x88 41ac60: mismo cuerpo que +0x20 (reenvia a +0x90). verificada (konami_surface_test)
func slot_88(src: Variant, x: int, y: int, alpha: int, a5: Variant, a6: Variant, a7: Variant) -> int:
	return slot_90(src, x, y, alpha, a5, a6, a7)


## +0x8c 4cb740: copiador opaco de imagen con canal +0x78. verificada en 32 bits (konami_pixels_test, KonamiMemorySurface)
func slot_8c(src: Variant, x: int, y: int, a4: Variant, a5: Variant, a6: Variant) -> int:
	return _leaf(0x8c, [src, x, y, a4, a5, a6])


## +0x90 4cbe20: copiador con alfa de imagen con canal +0x78. verificada en 32 bits (konami_pixels_test, KonamiMemorySurface)
func slot_90(src: Variant, x: int, y: int, alpha: int, a5: Variant, a6: Variant, a7: Variant) -> int:
	return _leaf(0x90, [src, x, y, alpha, a5, a6, a7])


## +0x94 41ac90: +0x98 con diez argumentos. Sin rectangulo (a6 = 0) completa con ceros; con
## rectangulo pasa sus dos primeras palabras y el propio puntero. verificada (konami_surface_test)
func slot_94(src: Variant, x: int, y: int, a4: int, a5: int, rect: Variant) -> int:
	if rect == null:
		return slot_98(src, x, y, a4, a5, 0, 0, null, 0, 0)
	else:
		return slot_98(src, x, y, a4, a5, rect[0], rect[1], rect, 0, 0)


## +0x98 4ccd40: copiador con mascara. PENDIENTE
func slot_98(src: Variant, x: int, y: int, a4: int, a5: int, a6: int, a7: int, rect: Variant, a9: int, a10: int) -> int:
	return _leaf(0x98, [src, x, y, a4, a5, a6, a7, rect, a9, a10])


## +0x9c 4ef870: copia que suma con saturacion (seis argumentos; +0xb0 con nivel 0xff). verificada en 32 bits (konami_pixels_test, KonamiMemorySurface)
func slot_9c(src: Variant, x: int, y: int, a4: Variant, a5: Variant, a6: Variant) -> int:
	return _leaf(0x9c, [src, x, y, a4, a5, a6])


## +0xa0 4eec70: copia que suma con saturacion (seis argumentos; +0xac con nivel 0xff). verificada en 32 bits (konami_pixels_test, KonamiMemorySurface)
func slot_a0(src: Variant, x: int, y: int, a4: Variant, a5: Variant, a6: Variant) -> int:
	return _leaf(0xa0, [src, x, y, a4, a5, a6])


## +0xa4 4f23c0: copia que resta con saturacion (seis argumentos; +0xb8 con nivel 0xff). verificada en 32 bits (konami_pixels_test, KonamiMemorySurface)
func slot_a4(src: Variant, x: int, y: int, a4: Variant, a5: Variant, a6: Variant) -> int:
	return _leaf(0xa4, [src, x, y, a4, a5, a6])


## +0xa8 4f17b0: copia que resta con saturacion (seis argumentos; +0xb4 con nivel 0xff). verificada en 32 bits (konami_pixels_test, KonamiMemorySurface)
func slot_a8(src: Variant, x: int, y: int, a4: Variant, a5: Variant, a6: Variant) -> int:
	return _leaf(0xa8, [src, x, y, a4, a5, a6])


## +0xac 4f0860: copia que suma luz con intensidad a/255 (siete argumentos); la dibuja
## JoeyFxCanvas con konami_add.gdshader (exacto en la GPU, konami_add_shader_test); verificada en 32 bits (konami_pixels_test, KonamiMemorySurface)
func slot_ac(src: Variant, x: int, y: int, a: int, b: Variant, c: Variant, d: Variant) -> int:
	return _leaf(0xac, [src, x, y, a, b, c, d])


## +0xb0 4f4300: copia que suma con intensidad a/255, como +0xac (siete argumentos); la dibuja
## JoeyFxCanvas con konami_add.gdshader (exacto en la GPU, konami_add_shader_test); verificada en 32 bits (konami_pixels_test, KonamiMemorySurface)
func slot_b0(src: Variant, x: int, y: int, a: int, b: Variant, c: Variant, d: Variant) -> int:
	return _leaf(0xb0, [src, x, y, a, b, c, d])

## +0xb4 4f33b0: resta con intensidad (siete argumentos). verificada en 32 bits (konami_pixels_test, KonamiMemorySurface)
func slot_b4(src: Variant, x: int, y: int, a: int, b: Variant, c: Variant, d: Variant) -> int:
	return _leaf(0xb4, [src, x, y, a, b, c, d])


## +0xb8 4f53f0: resta con intensidad (siete argumentos). verificada en 32 bits (konami_pixels_test, KonamiMemorySurface)
func slot_b8(src: Variant, x: int, y: int, a: int, b: Variant, c: Variant, d: Variant) -> int:
	return _leaf(0xb8, [src, x, y, a, b, c, d])



## Los metodos sin portar (+0x00, +0x30, +0x34, +0x44, +0x50..+0x6c, +0x80, +0x84, +0xbc..+0xe0) se anaden al portar la primera pantalla que los use.
## +0x00 41ae60 PENDIENTE
## +0x30 4cc3d0 PENDIENTE
## +0x34 4cc9c0 PENDIENTE
## +0x44 41ad80 PENDIENTE
## +0x50 54d820 PENDIENTE
## +0x54 4aa4b0 PENDIENTE
## +0x58 45b300 PENDIENTE
## +0x5c 4a9e80 PENDIENTE
## +0x64 4ac170 PENDIENTE
## +0x68 4abdd0 PENDIENTE
## +0x6c 4aaa50 PENDIENTE
## +0x80 4ca570 PENDIENTE
## +0x84 4c9540 PENDIENTE
## +0xbc 4cd770 PENDIENTE
## +0xc0 4cdb70 PENDIENTE
## +0xc4 4cdb80 PENDIENTE
## +0xc8 4ee1e0 PENDIENTE
## +0xcc 4ee7e0 PENDIENTE
## +0xd0 4a9fd0 PENDIENTE
## +0xd4 4a9d80 PENDIENTE
## +0xd8 4aa4a0 PENDIENTE
## +0xdc 4aabc0 PENDIENTE
## +0xe0 4abc10 PENDIENTE


## +0x40 de la imagen origen; las imagenes que no son superficies (diccionarios de los destinos
## con sprites) lo llevan en "flag_78".
func _src_flag(src: Variant) -> bool:
	if src is KonamiSurface:
		return src.slot_40()
	return src is Dictionary and src.get("flag_78", false)


## Hoja sin implementar en este destino: avisa una vez y devuelve 1 (sin dibujar).
func _leaf(slot: int, _args: Array) -> int:
	if not _warned.has(slot):
		_warned[slot] = true
		push_error("KonamiSurface: +0x%02x sin implementar en %s" % [slot, get_script().resource_path])
	return 1
