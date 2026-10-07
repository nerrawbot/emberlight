shader_type spatial;
// Painterly surface for the Sphaeroid (sphaeroid.gd _paint_model()): a hand-painted map (art_src/v13_paint.py)
// projected in the part's local space, soft-stepped light whose shadow edge is broken up by brush hatching, a cool
// violet in the shade, a broad soft highlight and a faint rim. No normal maps: the strokes carry the detail.
//   proj 0: round the local Y axis (u = angle, v = height)   hull, steel
//   proj 1: round the local Z axis (u = along -Z, v = angle)  cannon barrel
//   proj 2: box sides (u = x or z by the normal, v = height)  pylon leg, skid
//   proj 3: planar on local XY                                star faceplate
//   proj 4: the mesh's own UV                                 decals (hazard, rust)

uniform sampler2D paint : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D brush : filter_linear_mipmap, repeat_enable;
uniform bool use_paint = true;
uniform int proj = 0;
uniform float u_repeat = 1.0;        // tiles round the axis (proj 0/1), or per metre (proj 2/3)
uniform float v_scale = 0.28;        // tiles per metre along the linear axis
uniform float v_offset = 0.5;
uniform vec2 uv_scale = vec2(1.0);   // proj 4
uniform vec4 tint : source_color = vec4(1.0);
uniform float bands = 3.0;           // light steps
uniform float step_mix = 0.65;       // 0 smooth lambert .. 1 hard steps
uniform float brush_amt = 0.2;       // how much the hatching shifts the shadow edge
uniform float brush_scale = 0.6;
uniform float light_desat = 0.65;    // lights mostly set value, not hue, so the painted colours hold
uniform vec3 shade_color : source_color = vec3(0.32, 0.26, 0.58);
uniform float shade_amt = 0.18;      // a little cool light in the shadow side (per light)
uniform float spec_amt = 0.35;
uniform float rim_amt = 0.06;
uniform vec3 rim_color : source_color = vec3(0.55, 0.5, 0.85);
uniform float emission_amt = 0.0;    // flat self-light (the eye's iris etc.)
uniform vec3 emission_color : source_color = vec3(0.0);

varying vec3 lp;
varying vec3 ln;
varying float brush_v;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

// sample with derivatives taken from an unwrapped angle, so the atan seam doesn't flash a mip-0 line
vec4 tex_wrap(sampler2D t, vec2 uv, bool wrap_u, bool wrap_v) {
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	if (wrap_u) {
		dx.x -= round(dx.x / u_repeat) * u_repeat;
		dy.x -= round(dy.x / u_repeat) * u_repeat;
	}
	if (wrap_v) {
		dx.y -= round(dx.y / u_repeat) * u_repeat;
		dy.y -= round(dy.y / u_repeat) * u_repeat;
	}
	return textureGrad(t, uv, dx, dy);
}

void fragment() {
	vec2 uv;
	bool wu = false;
	bool wv = false;
	if (proj == 0) {
		uv = vec2(atan(lp.x, lp.z) / TAU * u_repeat, -lp.y * v_scale + v_offset);
		wu = true;
	} else if (proj == 1) {
		uv = vec2(-lp.z * v_scale + v_offset, (atan(lp.x, lp.y) / TAU + 0.25) * u_repeat);  // v 0.25 = the top
		wv = true;
	} else if (proj == 2) {
		float side = abs(ln.x) > abs(ln.z) ? lp.z : lp.x;
		uv = vec2(side * u_repeat, -lp.y * v_scale + v_offset);
	} else if (proj == 3) {
		uv = vec2(lp.x, -lp.y) * u_repeat + 0.5;
	} else {
		uv = UV * uv_scale;
	}
	vec3 col = tint.rgb;
	if (use_paint) {
		col *= tex_wrap(paint, uv, wu, wv).rgb;
	}
	// brush hatching in a projection that doesn't care about the paint's seams
	vec2 buv = (proj == 1 ? lp.zx : (abs(ln.y) > 0.7 ? lp.xz : (abs(ln.x) > abs(ln.z) ? lp.zy : lp.xy))) * brush_scale * 0.25;
	brush_v = texture(brush, buv).r;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.12;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color * fres * rim_amt * (0.6 + brush_v * 0.8) + emission_color * emission_amt;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float w = clamp((ndl + 0.25 + (brush_v - 0.5) * brush_amt) / 1.25, 0.0, 1.0);
	float s = w * bands;
	float stepped = (floor(s) + smoothstep(0.3, 0.7, fract(s))) / bands;
	float lit = mix(w, stepped, step_mix);
	vec3 lcol = mix(LIGHT_COLOR, vec3(dot(LIGHT_COLOR, vec3(0.3, 0.5, 0.2))), light_desat);
	vec3 lc = lcol * ATTENUATION / PI;
	DIFFUSE_LIGHT += lc * lit + lcol / PI * shade_color * shade_amt * (1.0 - lit) * min(ATTENUATION * 4.0, 1.0);
	vec3 h = normalize(LIGHT + VIEW);
	float sp = smoothstep(0.86, 0.97, dot(NORMAL, h) + (brush_v - 0.5) * 0.08);
	SPECULAR_LIGHT += lc * sp * spec_amt;
}
