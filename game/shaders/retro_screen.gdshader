shader_type canvas_item;
// Retro look, crisp pixel style (user, 2026-11-09, like the Fire Lance's pixel art; was PS2 style, soft):
// redraws the 3D world at a low resolution with square pixels, fewer shades and a light dot pattern. The HUD
// and menus are drawn after it, so they stay sharp. Tune the numbers in tuning/retro_screen.tres.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// Pixels from top to bottom (the PS2 drew 448; the PS1 drew 240).
uniform float pixel_height : hint_range(120.0, 900.0, 1.0) = 448.0;
// 0 = crisp square pixels (PS1), 1 = soft blend between pixels (PS2).
uniform float softness : hint_range(0.0, 1.0, 0.05) = 1.0;
// Shades per color channel (PS2: 256, i.e. no bands; PS1: 32).
uniform float color_levels : hint_range(4.0, 256.0, 1.0) = 256.0;
// Dot pattern that hides color bands: 0 = off (PS2), 1 = PS1 strength.
uniform float dither : hint_range(0.0, 2.0, 0.05) = 0.0;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

vec3 cell(vec2 c, float px, vec2 to_uv) {
	return texture(screen_tex, (c + 0.5) * px * to_uv).rgb;
}

void fragment() {
	float px = max(1.0, 1.0 / SCREEN_PIXEL_SIZE.y / pixel_height);  // screen pixels per low-res pixel
	vec2 p = FRAGCOORD.xy / px - 0.5;  // position in low-res pixels (centers on whole numbers)
	vec2 base = floor(p);
	vec2 f = mix(step(0.5, fract(p)), fract(p), softness);  // nearest pixel, or blend of the 4 around
	vec3 c = mix(mix(cell(base, px, SCREEN_PIXEL_SIZE), cell(base + vec2(1, 0), px, SCREEN_PIXEL_SIZE), f.x),
			mix(cell(base + vec2(0, 1), px, SCREEN_PIXEL_SIZE), cell(base + vec2(1, 1), px, SCREEN_PIXEL_SIZE), f.x), f.y);
	vec2 dot = floor(FRAGCOORD.xy / px);
	float t = (BAYER[int(mod(dot.y, 4.0)) * 4 + int(mod(dot.x, 4.0))] / 16.0 - 0.47) * dither;
	float steps = color_levels - 1.0;
	COLOR = vec4(clamp(floor(c * steps + 0.5 + t) / steps, 0.0, 1.0), 1.0);
}
