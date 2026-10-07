shader_type sky;
render_mode use_debanding;
// The Complex's sky (build_surface.gd): a painted late-afternoon sky. Warm cream-gold at the horizon on the sun's side,
// a dusty peach band, a cool lilac-blue zenith (the shadows' colour, so lit and shade read as one palette); a gold
// halo round the sun (Sun light = LIGHT0); long strata of cloud with stepped, brushy edges, gold-lit toward the sun and
// lilac in their bellies; below the horizon a haze the far spires sink into. Static (no TIME): the radiance map only
// renders once.

uniform vec3 zenith_color : source_color = vec3(0.5, 0.52, 0.7);
uniform vec3 upper_color : source_color = vec3(0.92, 0.77, 0.66);
uniform vec3 horizon_sun : source_color = vec3(1.0, 0.88, 0.66);
uniform vec3 horizon_away : source_color = vec3(0.86, 0.83, 0.82);
uniform vec3 below_color : source_color = vec3(0.82, 0.74, 0.66);
uniform float horizon_curve = 0.32;
uniform float zenith_curve = 0.55;
uniform float energy = 1.0;
uniform vec3 glow_color : source_color = vec3(1.0, 0.76, 0.4);
uniform float glow_wide = 0.45;        // broad warm halo
uniform float glow_tight = 1.4;        // close bright halo
uniform float sun_size = 1.6;          // degrees
uniform float sun_energy = 9.0;
uniform sampler2D brush : filter_linear_mipmap, repeat_enable;
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.9, 0.74);
uniform vec3 cloud_shade : source_color = vec3(0.6, 0.55, 0.7);
uniform float cloud_cover = 0.36;       // 0 overcast .. 1 clear
uniform float cloud_scale = 1.6;
uniform float cloud_alpha = 0.95;
uniform float cloud_yaw = 0.35;        // radians: which way the strata run

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

void sky() {
	vec3 d = EYEDIR;
	vec3 sun = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(0.6, 0.4, 0.7));
	float sd = dot(d, sun);
	float toward = pow(clamp(dot(normalize(d.xz + 1e-4), normalize(sun.xz + 1e-4)) * 0.5 + 0.5, 0.0, 1.0), 2.0);
	float e = d.y;

	// gradient: horizon (warm on the sun side) -> peach band -> lilac zenith
	vec3 hz = mix(horizon_away, horizon_sun, toward);
	float up = clamp(e, 0.0, 1.0);
	vec3 col = mix(hz, upper_color, pow(smoothstep(0.0, 0.45, up), horizon_curve * 2.0));
	col = mix(col, zenith_color, pow(smoothstep(0.12, 1.0, up), zenith_curve));
	col = mix(col, below_color, smoothstep(0.0, -0.25, e));

	// halo
	float s01 = max(sd, 0.0);
	col += glow_color * (pow(s01, 6.0) * glow_wide + pow(s01, 48.0) * glow_tight) * (0.6 + 0.4 * toward);

	// cloud strata on a flat layer overhead: banks (a slow mask) of long streaks along cloud_yaw, soft-stepped fills
	// like the painterly surfaces, edges nudged by a blurred read of the brush map (dragged strokes, not scratches)
	if (e > 0.0) {
		vec2 q = d.xz / (e + 0.08);
		float cy = cos(cloud_yaw);
		float sy = sin(cloud_yaw);
		vec2 p = vec2(q.x * cy - q.y * sy, q.x * sy + q.y * cy) * cloud_scale;
		float bank = smoothstep(0.32, 0.5, fbm(p * 0.2 + 11.0));
		vec2 ps = p * vec2(0.32, 0.9);
		float n = fbm(ps + vec2(fbm(ps * 0.5 + 3.1), 0.0) * 1.4);
		float br = textureLod(brush, p * vec2(0.05, 0.25), 2.5).r;
		n += (br - 0.5) * 0.06;
		float dens = smoothstep(cloud_cover, cloud_cover + 0.2, n) * bank;
		float st = dens * 3.0;
		dens = mix(dens, (floor(st) + smoothstep(0.2, 0.8, fract(st))) / 3.0, 0.4);
		// lit from the sun's side: thin edges and clouds near the sun go gold, thick bellies lilac
		float thick = smoothstep(cloud_cover + 0.08, cloud_cover + 0.3, n);
		float sunlit = clamp(0.3 + toward * 0.45 - thick * 0.35 + pow(s01, 6.0) * 0.6, 0.0, 1.0);
		vec3 cc = mix(cloud_shade, cloud_lit, sunlit);
		cc += glow_color * pow(s01, 10.0) * (1.0 - thick) * 1.2;   // gold lining near the sun
		float fade = smoothstep(0.04, 0.35, e);                        // sink into the horizon haze
		col = mix(col, cc, dens * cloud_alpha * fade);
	}

	// the sun disk sits over the clouds' thin edges (fog and the halo hide the join)
	float disk = smoothstep(cos(radians(sun_size)), cos(radians(sun_size * 0.6)), sd);
	col += mix(glow_color, vec3(1.0, 0.95, 0.85), 0.6) * disk * sun_energy;

	COLOR = col * energy;
}
