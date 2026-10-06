shader_type spatial;
// The mesa (surface.tscn, S5_Mesa-col): blends graded Poly Haven layers by the 'TerrainMask' vertex colour painted in
// art_src/v5_surface.py paint_mask():  R gravel, G moss, B cracked dirt, A strata (which cliff rock).
// Flat ground is projected from above; steep faces switch to two triplanar rocks. Height maps (ORM red) sharpen the
// transitions so layers break up along stones and cracks rather than fading. A huge-scale sample of the moss texture
// breaks up tiling across the whole plateau.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D ground_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_orm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_orm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_orm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D moss_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_orm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D cliff_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff_orm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D cliff2_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff2_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cliff2_orm : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform float ground_tile = 3.0;      // metres per repeat
uniform float gravel_tile = 2.2;
uniform float dirt_tile = 4.0;
uniform float moss_tile = 14.0;       // an aerial scan: large
uniform float cliff_tile = 9.0;
uniform float cliff2_tile = 5.0;
uniform float macro_tile = 170.0;
uniform float macro_strength = 0.35;
uniform float ground_desat = 0.35;    // the original ground grade is a very saturated blue
uniform float normal_strength = 0.9;
uniform float specular_amount = 0.12; // low: the dark rock otherwise reflects the cream sky and goes brown
uniform vec3 tint = vec3(1.0);

varying vec3 w_pos;
varying vec3 w_nrm;
varying vec4 mask;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	mask = COLOR;
}

vec3 unpack_n(vec3 c) {
	return c * 2.0 - 1.0;
}

// planar (from above): albedo, normal offset in world XZ, orm
void top(sampler2D a, sampler2D n, sampler2D o, float tile, out vec3 alb, out vec2 nofs, out vec3 orm) {
	vec2 uv = w_pos.xz / tile;
	alb = texture(a, uv).rgb;
	vec3 t = unpack_n(texture(n, uv).rgb);
	nofs = vec2(t.x, -t.y);
	orm = texture(o, uv).rgb;
}

// triplanar: albedo, world-space normal offset, orm
void tri(sampler2D a, sampler2D n, sampler2D o, float tile, vec3 bw, out vec3 alb, out vec3 nofs, out vec3 orm) {
	vec2 ux = w_pos.zy / tile;
	vec2 uy = w_pos.xz / tile;
	vec2 uz = w_pos.xy / tile;
	alb = texture(a, ux).rgb * bw.x + texture(a, uy).rgb * bw.y + texture(a, uz).rgb * bw.z;
	orm = texture(o, ux).rgb * bw.x + texture(o, uy).rgb * bw.y + texture(o, uz).rgb * bw.z;
	vec3 tx = unpack_n(texture(n, ux).rgb);
	vec3 ty = unpack_n(texture(n, uy).rgb);
	vec3 tz = unpack_n(texture(n, uz).rgb);
	nofs = vec3(0.0, tx.y, tx.x) * bw.x + vec3(ty.x, 0.0, -ty.y) * bw.y + vec3(tz.x, tz.y, 0.0) * bw.z;
}

// height-aware blend weight: w = painted amount, h = the incoming layer's height
float hblend(float w, float h) {
	float t = w + (h - 0.5) * 0.7 * (1.0 - abs(w * 2.0 - 1.0));
	return smoothstep(0.3, 0.7, t);
}

void fragment() {
	vec3 n0 = normalize(w_nrm);
	vec3 bw = pow(abs(n0), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);

	// --- ground layers
	vec3 alb; vec2 nofs; vec3 orm;
	top(ground_alb, ground_nrm, ground_orm, ground_tile, alb, nofs, orm);
	alb = mix(alb, vec3(dot(alb, vec3(0.3, 0.59, 0.11))), ground_desat);
	vec3 la; vec2 ln; vec3 lo; float w;
	top(dirt_alb, dirt_nrm, dirt_orm, dirt_tile, la, ln, lo);
	w = hblend(mask.b, lo.r);
	alb = mix(alb, la, w); nofs = mix(nofs, ln, w); orm = mix(orm, lo, w);
	top(gravel_alb, gravel_nrm, gravel_orm, gravel_tile, la, ln, lo);
	w = hblend(mask.r, lo.r);
	alb = mix(alb, la, w); nofs = mix(nofs, ln, w); orm = mix(orm, lo, w);
	top(moss_alb, moss_nrm, moss_orm, moss_tile, la, ln, lo);
	w = hblend(mask.g, lo.r);
	alb = mix(alb, la, w); nofs = mix(nofs, ln, w); orm = mix(orm, lo, w);
	vec3 n_ground = normalize(n0 + vec3(nofs.x, 0.0, nofs.y) * normal_strength);

	// --- rock on steep faces: two rocks in strata bands
	vec3 ra; vec3 rn; vec3 ro;
	tri(cliff_alb, cliff_nrm, cliff_orm, cliff_tile, bw, ra, rn, ro);
	vec3 ra2; vec3 rn2; vec3 ro2;
	tri(cliff2_alb, cliff2_nrm, cliff2_orm, cliff2_tile, bw, ra2, rn2, ro2);
	float s = hblend(mask.a, ro2.r);
	ra = mix(ra, ra2, s); rn = mix(rn, rn2, s); ro = mix(ro, ro2, s);
	vec3 n_rock = normalize(n0 + rn * normal_strength);

	float steep = 1.0 - smoothstep(0.78, 0.93, n0.y);     // ~23 deg and up is rock (top projection stretches beyond)
	float rw = hblend(steep, ro.r);
	alb = mix(alb, ra, rw);
	orm = mix(orm, ro, rw);
	vec3 nw = normalize(mix(n_ground, n_rock, rw));

	// --- macro variation: one huge, faint sample so the plateau doesn't read as a repeating tile
	float macro = dot(texture(moss_alb, w_pos.xz / macro_tile).rgb, vec3(0.3, 0.59, 0.11));
	alb *= mix(1.0, 0.65 + macro * 1.1, macro_strength);

	ALBEDO = alb * tint;
	ROUGHNESS = clamp(orm.g, 0.35, 1.0);
	METALLIC = 0.0;
	SPECULAR = specular_amount;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
