shader_type canvas_item;
render_mode unshaded;
uniform float progress = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;
void fragment() {
	int y = int(floor(UV.y * 600.0));
	// Entre ticks llega mezclado; las filas siguen siendo enteras.
	int extent = int(300.0 * progress / 256.0);
	int weight = clamp(min(y - (300 - extent - 32), 300 + extent + 31 - y) * 8, 0, 256);
	if (progress >= 256.0) weight = 256;
	if (progress < 0.0) weight = 0;
	vec3 original = texture(screen_texture, SCREEN_UV).rgb;
	// 4f6900 / LUT546d70: dark snapshot is eight fifteenths, not one half.
	vec3 bits = vec3(31.0, 63.0, 31.0);
	vec3 target = floor(original * bits + vec3(0.5));
	vec3 dark = floor(target * 8.0 / 15.0);
	float level = float(min(15, weight >> 4));
	vec3 mixed = (floor(dark * level / 15.0) + floor(target * (15.0 - level) / 15.0)) / bits;
	COLOR = vec4(weight == 0 ? original : mixed, 1.0);
}
