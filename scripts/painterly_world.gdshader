shader_type spatial;
// Painterly surface for the level (painterly_world.gd swaps it in for the glb's PBR materials at runtime): the world
// cousin of creatures/painterly.gdshader. The material's own albedo is smeared along brush strokes and mostly read from
// a blurrier mip (broad patches of colour, a little texture left on top); light comes in soft steps whose edge, and the
// edge of the sun's cast shadow, is broken up by hatching; the shade side picks up a cool violet; a broad soft highlight
// and a faint warm rim. The normal map is kept, but weak.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D brush : filter_linear_mipmap, repeat_enable;
uniform bool use_albedo_tex = false;
uniform bool use_normal_tex = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float normal_depth = 0.35;
uniform float broad_blur = 3.0;      // derivative scale for the broad sample (~log2 mips blurrier)
uniform float detail_amt = 0.35;     // how much of the sharp texture shows over the broad patches
uniform float smear = 0.03;          // UV units the strokes drag the colour
uniform float bands = 3.0;           // light steps
uniform float step_mix = 0.55;       // 0 smooth lambert .. 1 hard steps
uniform float brush_amt = 0.22;      // how much the hatching shifts the light/shadow edge
uniform float shadow_brush = 0.45;   // ... and the sun's cast-shadow edge
uniform float brush_scale = 0.9;     // brush tiles per 4 m
uniform float light_desat = 0.25;    // 0 = lights keep their hue (the gold sun), 1 = they only set value
uniform vec3 shade_color : source_color = vec3(0.34, 0.3, 0.6);
uniform float shade_amt = 0.16;      // cool light in the shade side (per light)
uniform float spec_amt = 0.22;
uniform float rim_amt = 0.05;
uniform vec3 rim_color : source_color = vec3(1.0, 0.86, 0.66);

varying vec3 lp;
varying vec3 ln;
varying float brush_v;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	// hatching in a box projection of the mesh's local space (level meshes are in world metres)
	vec3 an = abs(ln);
	vec2 buv = (an.y > 0.7 ? lp.xz : (an.x > an.z ? lp.zy : lp.xy)) * brush_scale * 0.25;
	brush_v = texture(brush, buv).r;
	float brush_w = texture(brush, buv * 0.71 + vec2(0.37, 0.61)).r;

	vec3 col = tint.rgb;
	if (use_albedo_tex) {
		vec2 uv = UV * uv_scale.xy + uv_offset.xy;
		vec2 suv = uv + (vec2(brush_v, brush_w) - 0.5) * smear;
		vec3 broad = textureGrad(albedo_tex, suv, dFdx(uv) * broad_blur, dFdy(uv) * broad_blur).rgb;
		vec3 sharp = texture(albedo_tex, uv).rgb;
		col *= mix(broad, sharp, detail_amt);
		if (use_normal_tex) {
			NORMAL_MAP = texture(normal_tex, uv).rgb;
			NORMAL_MAP_DEPTH = normal_depth;
		}
	}
	// flat colours get a whisper of stroke value so big plain faces aren't dead flat
	col *= 0.93 + brush_w * 0.14;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.15;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color * fres * rim_amt * (0.6 + brush_v * 0.8) * col;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float w = clamp((ndl + 0.2 + (brush_v - 0.5) * brush_amt) / 1.2, 0.0, 1.0);
	float s = w * bands;
	float stepped = (floor(s) + smoothstep(0.3, 0.7, fract(s))) / bands;
	float lit = mix(w, stepped, step_mix);
	float att = ATTENUATION;
	if (LIGHT_IS_DIRECTIONAL) {
		// the cast shadow gets a painted edge: brushy and fairly firm instead of a blurred PCF ramp
		att = smoothstep(0.25, 0.75, clamp(att + (brush_v - 0.5) * shadow_brush, 0.0, 1.0));
	}
	vec3 lcol = mix(LIGHT_COLOR, vec3(dot(LIGHT_COLOR, vec3(0.3, 0.5, 0.2))), light_desat);
	vec3 lc = lcol * att / PI;
	float reach = LIGHT_IS_DIRECTIONAL ? 1.0 : min(ATTENUATION * 4.0, 1.0);
	DIFFUSE_LIGHT += lc * lit + lcol / PI * shade_color * shade_amt * (1.0 - lit * att) * reach;
	vec3 h = normalize(LIGHT + VIEW);
	float sp = smoothstep(0.88, 0.98, dot(NORMAL, h) + (brush_v - 0.5) * 0.08);
	SPECULAR_LIGHT += lc * sp * spec_amt;
}
