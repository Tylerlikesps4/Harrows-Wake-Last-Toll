shader_type canvas_item;
// Full-screen PS1 post effect: 15-bit colour with Bayer dithering,
// optional scanlines, vignette, film grain, a panic wobble/red tint,
// a grab "distort" (tear + chromatic split) and the wardrobe "slit" view.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float color_depth = 31.0;
uniform float scanlines = 0.12;
uniform float panic = 0.0;
uniform float fade = 0.0;
uniform float distort = 0.0;
uniform float slit = 0.0;      // 0 = off, 1 = peering through wardrobe doors
uniform float grain = 0.05;
uniform float vignette = 1.5;
uniform float gamma = 1.0;      // brightness setting (>1 lifts the shadows)

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[y * 4 + x] / 16.0 - 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (panic > 0.01) {
		uv.x += sin(uv.y * 30.0 + TIME * 7.0) * 0.003 * panic;
	}
	if (distort > 0.01) {
		float band = step(0.82, hash(vec2(floor(uv.y * 24.0), floor(TIME * 18.0))));
		uv.x += (hash(vec2(floor(uv.y * 60.0), TIME)) - 0.5) * 0.06 * distort * band;
		uv.y += sin(TIME * 40.0) * 0.004 * distort;
	}
	vec3 c = texture(screen_tex, uv).rgb;
	if (distort > 0.01) {
		float o = 0.008 * distort;
		c.r = texture(screen_tex, uv + vec2(o, 0.0)).r;
		c.b = texture(screen_tex, uv - vec2(o, 0.0)).b;
	}
	c = pow(max(c, vec3(0.0)), vec3(1.0 / gamma)) * mix(1.0, 1.08, clamp(gamma - 1.0, 0.0, 1.0));
	c += (hash(FRAGCOORD.xy + fract(TIME) * 100.0) - 0.5) * grain;
	c += bayer4(FRAGCOORD.xy) / color_depth;
	c = floor(c * color_depth + 0.5) / color_depth;
	c = mix(c, c * vec3(1.25, 0.55, 0.5), panic * 0.55);
	c = mix(c, c * vec3(1.4, 0.4, 0.4), distort * 0.5);
	if (mod(FRAGCOORD.y, 2.0) < 1.0) {
		c *= 1.0 - scanlines;
	}
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - dot(d, d) * vignette;
	if (slit > 0.01) {
		// Two wardrobe doors left ajar: only a thin vertical gap shows the room.
		float gap = smoothstep(0.075, 0.045, abs(SCREEN_UV.x - 0.5 + sin(TIME * 0.7) * 0.004));
		float slats = step(0.5, fract(SCREEN_UV.y * 14.0)) * 0.12;
		c *= mix(1.0, gap + slats * (1.0 - gap), slit);
	}
	c *= 1.0 - fade;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
