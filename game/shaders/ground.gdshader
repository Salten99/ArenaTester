shader_type spatial;
// The valley ground (ValleyWorld): each biome's color (the vertex color) shaded by a texture laid
// in world space, the RetroLook grit, or the user's grass picture where the vertex alpha says
// grass (ValleyTerrain.color: biomes with enough grass `cover`).

uniform sampler2D grit : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D grass : source_color, filter_nearest_mipmap, repeat_enable;
uniform float grit_size = 1.92;  // m one grit texture covers
uniform float grass_size = 2.0;  // m one grass picture covers (the Blender camera's Orthographic Scale)
// Divides out the picture's average color, so it shades the biome color like the grit does.
uniform vec3 grass_gain = vec3(1.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
}

#include "res://shaders/laid.gdshaderinc"

void fragment() {
	vec3 base = mix(COLOR.rgb / 12.92, pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), COLOR.rgb));
	ALBEDO = base * mix(laid(grit, grit_size, false), laid(grass, grass_size, true) * grass_gain, COLOR.a);
	ROUGHNESS = 1.0;
}
