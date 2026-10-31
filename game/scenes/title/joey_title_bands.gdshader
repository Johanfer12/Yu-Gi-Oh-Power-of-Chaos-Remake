shader_type canvas_item;
render_mode unshaded;
uniform float counter = 0.0; // mezclado entre ticks
uniform sampler2D layer1 : filter_nearest;
uniform sampler2D layer2 : filter_nearest;
uniform sampler2D mask_image : filter_nearest;
uniform ivec2 origin1 = ivec2(120, 10);
uniform ivec2 origin2 = ivec2(150, 10);
ivec3 rgb565(vec3 c) { return ivec3(floor(c * vec3(255.0) + vec3(0.01))) / ivec3(8, 4, 8); }
ivec3 band(ivec3 background, sampler2D image, ivec2 size, ivec2 origin, int weight, ivec2 pixel) {
    int left = ((origin.x - 310) * weight + (origin.x + 560) * (256 - weight)) / 256;
    ivec2 local = pixel - ivec2(left, origin.y);
    ivec2 at = pixel - origin;
    if (local.x < 0 || local.x >= 155 || local.y < 0 || local.y >= 312 ||
        at.x < 0 || at.x >= size.x || at.y < 0 || at.y >= size.y) return background;
    vec4 source = texture(image, (vec2(at) + vec2(0.5)) / vec2(size));
    if (source.a == 0.0) return background;
    int blue5 = int(floor(texture(mask_image, (vec2(local) + vec2(0.5)) / vec2(155, 312)).b * 255.0 + 0.01)) / 8;
    int alpha4 = blue5 / 2;
    ivec3 contribution = rgb565(source.rgb) * alpha4 / 15;
    return min(ivec3(31, 63, 31), background + contribution);
}
void fragment() {
    ivec2 pixel = ivec2(floor(UV * vec2(800, 600)));
    ivec3 value = rgb565(texture(TEXTURE, UV).rgb);
    value = band(value, layer1, ivec2(560, 310), origin1, int(counter * 2.0), pixel);
    value = band(value, layer2, ivec2(500, 300), origin2, int(counter * 2.0) + 16, pixel);
    COLOR = vec4(vec3(value) / vec3(31.0, 63.0, 31.0), 1.0);
}
