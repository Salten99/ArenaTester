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

// How the tile at `cell` (whole-number tile coordinates) is turned, so the grass doesn't repeat
// in a visible grid: a 2x2 matrix applied to the spot inside the tile, around its middle.
// Checkerboard: "white" tiles turn 0 or 90 degrees, "black" ones 180 or 270, each picked at random
// per tile, so side-by-side tiles never face the same way. The tile number alone decides it, so
// it's the same every frame. (Adding a random turn per row and per column instead repeats rows.)
mat2 tile_turn(vec2 cell) {
	float pick = step(0.5, fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453));
	float a = (2.0 * mod(cell.x + cell.y, 2.0) + pick) * PI * 0.5;
	float c = round(cos(a));
	float s = round(sin(a));
	return mat2(vec2(c, s), vec2(-s, c));
}

// The texture seen from above with each tile turned (tile_turn). textureGrad keeps the mipmap
// from the smooth coordinate, else every tile edge would draw a blurry seam.
vec3 turned(sampler2D t, vec2 uv) {
	mat2 m = tile_turn(floor(uv));
	return textureGrad(t, m * (fract(uv) - 0.5) + 0.5, m * dFdx(uv), m * dFdy(uv)).rgb;
}

// Laid from the three sides, so cliffs aren't stretched; `turn` turns the tiles seen from above.
vec3 laid(sampler2D t, float size, bool turn) {
	vec3 w = world_normal / (world_normal.x + world_normal.y + world_normal.z);
	vec3 top = turn ? turned(t, world_pos.xz / size) : texture(t, world_pos.xz / size).rgb;
	return texture(t, world_pos.zy / size).rgb * w.x + top * w.y + texture(t, world_pos.xy / size).rgb * w.z;
}

void fragment() {
	vec3 base = mix(COLOR.rgb / 12.92, pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), COLOR.rgb));
	ALBEDO = base * mix(laid(grit, grit_size, false), laid(grass, grass_size, true) * grass_gain, COLOR.a);
	ROUGHNESS = 1.0;
}
