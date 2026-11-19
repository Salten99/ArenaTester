shader_type spatial;
// The gladiator arena model (models/gen/world/arena.glb, one mesh painted with vertex colors):
// the user's grass picture shading the sand color where it is painted sand, their stone picture
// shading a sandstone/marble color where it is painted grey stone, the RetroLook grit over everything else (banners, gold trim, dark gates).

uniform sampler2D grit : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D grass : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D stone : source_color, filter_nearest_mipmap, repeat_enable;
uniform float grit_size = 1.92;  // m one grit texture covers
uniform float grass_size = 2.0;  // m one grass picture covers
uniform float stone_size = 3.0;  // m one stone picture covers (as on the valley's Old Towers)
// The stone's color: a pale sandstone/marble (the picture only adds its pattern).
uniform vec3 stone_color : source_color = vec3(0.86, 0.79, 0.66);
// Divide out each picture's average color (set by Arena), so only its pattern shades the color.
uniform vec3 grass_gain = vec3(1.0);
uniform vec3 stone_gain = vec3(1.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
}

#include "res://shaders/laid.gdshaderinc"

void fragment() {
	vec3 c = COLOR.rgb;
	// Sand: light and warm (the gold trim is warm too, but has almost no blue).
	bool sand = c.r > 0.6 && c.b > 0.2;
	// Stone: mid grey-brown, its red and blue close together (banners and gates fall outside).
	bool grey = c.r > 0.15 && c.r < 0.45 && c.b > 0.1 && c.r - c.b < 0.12;
	vec3 base = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
	if (sand) {
		ALBEDO = base * laid(grass, grass_size, true) * grass_gain;
	} else if (grey) {
		ALBEDO = stone_color * laid(stone, stone_size, false) * stone_gain;
	} else {
		ALBEDO = base * laid(grit, grit_size, false);
	}
	ROUGHNESS = 1.0;
}
