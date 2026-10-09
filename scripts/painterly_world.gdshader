shader_type spatial;
// Painterly surface for the level (painterly_world.gd swaps it in for the glb's PBR materials at runtime): the world
// cousin of creatures/painterly.gdshader. The material's own albedo is smeared along brush strokes and mostly read from
// a blurrier mip (broad patches of colour, a little texture left on top); light comes in soft steps whose edge, and the
// edge of the sun's cast shadow, is broken up by hatching; the shade side picks up a cool violet; a broad soft highlight
// and a faint warm rim. The normal map is kept, but weak.
// v18 weathering (world space, so the merged level meshes vary too): broad patches of value and warm/cool hue, grime and
// damp creeping up from the ground (height above the terrain from assets/map/surface_ground.res, baked by
// tools/bake_ground.gd), and rain streaks down vertical faces. `weather` scales all of it per material (0 on plants).

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
// --- v18 weathering
uniform sampler2D weather_noise : filter_linear_mipmap, repeat_enable;     // seamless value noise (painterly_world.gd)
uniform sampler2D ground_tex : filter_linear, repeat_disable;               // terrain height (m) per metre of x, z
uniform bool use_ground = false;
uniform vec4 ground_rect = vec4(0.0, 0.0, 1.0, 1.0);                       // x0, z0, width, depth (m)
uniform float weather = 1.0;
uniform float vary_amt = 0.2;       // value patches (+-)
uniform float hue_amt = 0.07;        // warm/cool patches
uniform float grime_height = 1.7;    // metres the grime reaches up the walls (ragged)
uniform float grime_amt = 0.6;
uniform vec3 grime_color : source_color = vec3(0.32, 0.26, 0.24);
uniform vec3 damp_color : source_color = vec3(0.26, 0.3, 0.2);
uniform float streak_amt = 0.42;
uniform vec3 streak_color : source_color = vec3(0.45, 0.36, 0.32);

varying vec3 lp;
varying vec3 ln;
varying vec3 wp;
varying vec3 wn;
varying float brush_v;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float wnoise(vec2 p) {
	return texture(weather_noise, p).r;
}

vec3 weathered(vec3 col) {
	if (weather <= 0.0) {
		return col;
	}
	// broad patches: value and a warm/cool shift
	float n1 = wnoise(wp.xz / 41.0 + wp.y / 97.0);
	float n2 = wnoise(wp.xz / 17.0 + vec2(0.37, 0.71) + wp.y / 53.0);
	col *= 1.0 + (n1 - 0.5) * 2.0 * vary_amt * weather;
	vec3 warm = vec3(1.07, 1.0, 0.9);
	vec3 cool = vec3(0.92, 0.96, 1.08);
	col *= mix(vec3(1.0), mix(cool, warm, n2), clamp(hue_amt * 7.0 * weather, 0.0, 1.0));
	float vert = 1.0 - smoothstep(0.55, 0.9, abs(wn.y));
	// rain streaks down vertical faces: noise stretched tall, along the wall
	float along = abs(wn.x) > abs(wn.z) ? wp.z : wp.x;
	float s = wnoise(vec2(along * 0.37, wp.y * 0.022 + along * 0.003));
	float s2 = wnoise(vec2(along * 1.3 + 0.5, wp.y * 0.05));
	float streak = smoothstep(0.52, 0.78, s) * (0.55 + 0.45 * s2) * vert;
	col = mix(col, col * streak_color * 1.4, streak * streak_amt * weather);
	// grime and damp from the ground up
	if (use_ground) {
		vec2 guv = (wp.xz - ground_rect.xy) / ground_rect.zw;
		float gy = texture(ground_tex, guv).r;
		float h = wp.y - gy;
		float edge = wnoise(vec2(along * 0.21, wp.y * 0.11) + wp.xz * 0.013);
		float reach = grime_height * (0.45 + 1.1 * edge);
		float g = (1.0 - smoothstep(0.0, reach, h)) * step(-3.0, h);
		g *= mix(0.35, 1.0, vert);            // floors and tops: lighter
		float damp = smoothstep(0.55, 0.75, wnoise(wp.xz / 6.0 + 0.2));
		vec3 gc = mix(grime_color, damp_color, damp);
		col = mix(col, col * gc * 1.6, g * grime_amt * weather);
	}
	return col;
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
	col = weathered(col);
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
