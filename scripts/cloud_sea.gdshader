shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// The Complex's cloud sea (build_surface.gd, CloudSea): flat layers of haze far below the mesa rim, so the spires and the
// cliff sink into a soft deck instead of ending in mid-air. The lowest layer is solid, the ones above are thinning wisps
// that drift slowly. Soft where they cut through rock (depth fade). Scene fog still lands on them, so far off they melt
// into the horizon haze.

uniform vec3 lit_color : source_color = vec3(0.95, 0.88, 0.78);
uniform vec3 shade_color : source_color = vec3(0.72, 0.69, 0.76);
uniform float cover = 0.45;          // noise level where the cloud starts (lower = more cloud)
uniform float softness = 0.18;
uniform float base_alpha = 0.0;      // alpha in the gaps (1 = solid deck)
uniform float opacity = 1.0;
uniform float scale = 0.006;         // per metre
uniform vec2 drift = vec2(0.6, 0.25); // m/s
uniform float seed = 0.0;
uniform float edge_fade = 8.0;       // metres of soft fade where the layer meets rock
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += vnoise(p) * a;
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = (wp.xz + drift * TIME) * scale + vec2(seed * 17.3, seed * 5.1);
	// warped billows, stretched a little along the drift
	vec2 w = vec2(fbm(p * 0.7 + 4.2), fbm(p * 0.7 + 8.9));
	float n = fbm(p * vec2(1.0, 1.6) + w * 1.3);
	float c = smoothstep(cover - softness, cover + softness, n);
	ALBEDO = mix(shade_color, lit_color, smoothstep(0.3, 0.75, n));
	float a = mix(base_alpha, 1.0, c) * opacity;
	// fade where the layer passes through the cliff / spires
	float d = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float scene_z = -sv.z / sv.w;
	a *= clamp((scene_z + VERTEX.z) / edge_fade, 0.0, 1.0);
	ALPHA = a;
}
