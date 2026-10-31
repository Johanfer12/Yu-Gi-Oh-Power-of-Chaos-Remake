// Copiadores aditivos de la superficie de Konami en pantalla (docs/FRONTERA_KONAMI.md):
// +0xac/+0xb0 suman floor(src * nivel / 255) por canal y +0xa0/+0x9c (nivel 0xff de los
// anteriores) suman floor(src * alfa / 255) con imagenes de alfa, o src sin el. La saturacion
// min(dst + v, 255) la hace la mezcla aditiva del framebuffer de 8 bits.
// Contrato verificado en KonamiMemorySurface; konami_add_shader_test.gd compara este shader con el.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform int level = 255;
// Imagen con canal alfa (formato > 9) dibujada con nivel 0xff: +0xa0/+0x9c usan el alfa.
uniform bool use_alpha = false;
// Imagenes del juego con color clave: el texel transparente es el color clave del BMP. Para los
// efectos es negro, que no suma nada; se toma como 0 aunque la copia compacta cambie su RGB.
uniform bool key_transparent = false;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 s = round(t.rgb * 255.0);
	if (key_transparent && t.a <= 0.0) {
		s = vec3(0.0);
	}
	float k = use_alpha ? round(t.a * 255.0) : float(level);
	// floor(n / 255) exacto para n entero: el medio texel de margen no cruza otro multiplo.
	vec3 v = floor((s * k + 0.5) / 255.0);
	COLOR = vec4(v / 255.0, 1.0);
}
