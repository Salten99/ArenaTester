shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
// A second pass over a model (CharacterModel._overlay): blood patches that spread as it's hurt
// (user, 2026-11-05: models get bloodier with every hit), and the flash/tint color on top.
// The patches are fixed to the model (its own space), so they stay where the wounds are.

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float blood : hint_range(0.0, 1.0) = 0.0;
varying vec3 here;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	here = VERTEX;
}

void fragment() {
	float n = noise(here * 5.0) * 0.65 + noise(here * 13.0) * 0.35;
	float wet = blood > 0.0 ? smoothstep(1.0 - blood * 0.85, 1.04 - blood * 0.85, n) : 0.0;
	vec3 red = mix(vec3(0.42, 0.02, 0.02), vec3(0.22, 0.0, 0.0), noise(here * 31.0));
	ALBEDO = mix(red, tint.rgb, tint.a);
	ALPHA = max(tint.a, wet * 0.92);
}
