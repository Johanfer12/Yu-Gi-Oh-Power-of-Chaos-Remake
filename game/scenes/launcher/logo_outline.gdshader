shader_type canvas_item;
uniform float emphasis = 0.0;
uniform float reveal = 0.0;
varying vec4 sprite_tint;
void vertex() {
	sprite_tint = COLOR;
}
void fragment() {
	vec4 tint = sprite_tint;
	vec4 logo = texture(TEXTURE, UV);
	// Contorno en anillos circulares (no una caja), para un borde redondeado y sin escalones.
	float edge = 0.0;
	float glow = 0.0;
	for (int i = 0; i < 16; i++) {
		float angle = float(i) * 0.3926991;
		vec2 dir = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE;
		edge = max(edge, texture(TEXTURE, UV + dir * 1.25).a);
		edge = max(edge, texture(TEXTURE, UV + dir * 2.5).a * 0.8);
		glow += texture(TEXTURE, UV + dir * 4.0).a;
	}
	glow /= 16.0;
	vec3 gold = vec3(1.0, 0.82, 0.3);
	vec3 rgb = mix(gold, logo.rgb * (1.0 - reveal * 0.42), logo.a);
	float ring = max(edge * (0.35 + emphasis * 0.65), glow * emphasis * 0.45);
	COLOR = vec4(rgb, max(logo.a, ring)) * tint;
}
