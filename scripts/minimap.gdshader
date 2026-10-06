shader_type canvas_item;
// Draws a baked floor plan (scripts/map_info.gd) into the rect: the floor at or below the player in a blue that
// darkens with depth, outlines where the floor drops or ends, and hatching under decks overhead.
// Used by scripts/minimap.gd for the round corner map (rotating) and the M map (north-up).

uniform sampler2D heights : filter_nearest, repeat_disable;
uniform vec2 map_origin;        // world (x, z) of the texture's top-left corner
uniform vec2 map_size = vec2(1.0);
uniform float y_min;
uniform float y_span = 1.0;
uniform vec2 center;            // world (x, z) shown at the middle of the rect
uniform float yaw;              // 0 = north-up (-Z up the screen); the player's yaw keeps their heading up
uniform vec2 half_m = vec2(30.0);   // metres from the middle to the rect's edges
uniform float ref_y;            // player's feet + a margin: the floor drawn is the highest one at or below this
uniform bool round_mask = true;
uniform vec4 near_col : source_color = vec4(0.33, 0.39, 0.62, 1.0);
uniform vec4 far_col : source_color = vec4(0.09, 0.10, 0.22, 1.0);
uniform vec4 edge_col : source_color = vec4(0.88, 0.92, 1.0, 1.0);
uniform vec4 bg_col : source_color = vec4(0.02, 0.025, 0.06, 0.72);
uniform vec4 above_col : source_color = vec4(0.55, 0.6, 0.85, 0.35);

const float NONE = -1e5;

float dec(float v) {
	return v < 0.5 / 255.0 ? -1e6 : y_min + (v * 255.0 - 1.0) / 254.0 * y_span;
}

bool inside(vec2 uv) {
	return uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
}

// the floor at or below ref_y (layers are stored highest first; an empty layer decodes to -1e6)
float floor_at(vec2 uv) {
	if (!inside(uv)) return -1e6;
	vec4 t = texture(heights, uv);
	float h = dec(t.r);
	if (h <= ref_y) return h;
	h = dec(t.g);
	if (h <= ref_y) return h;
	h = dec(t.b);
	if (h <= ref_y) return h;
	return dec(t.a);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * half_m;
	float c = cos(yaw);
	float s = sin(yaw);
	vec2 w = center + vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
	vec2 uv = (w - map_origin) / map_size;
	vec2 tx = 1.0 / vec2(textureSize(heights, 0));

	vec4 col = bg_col;
	float h = floor_at(uv);
	if (h > NONE) {
		col = mix(near_col, far_col, smoothstep(0.8, 14.0, ref_y - h));
		float e = 0.0;
		float hn = floor_at(uv + vec2(tx.x, 0.0));
		e = max(e, step(0.7, abs(hn - h)));
		hn = floor_at(uv - vec2(tx.x, 0.0));
		e = max(e, step(0.7, abs(hn - h)));
		hn = floor_at(uv + vec2(0.0, tx.y));
		e = max(e, step(0.7, abs(hn - h)));
		hn = floor_at(uv - vec2(0.0, tx.y));
		e = max(e, step(0.7, abs(hn - h)));
		// the edge of a drop is bright on the near floor, fainter far below
		col.rgb = mix(col.rgb, edge_col.rgb, e * mix(0.9, 0.35, smoothstep(2.0, 14.0, ref_y - h)));
	}
	// decks overhead: diagonal hatching
	if (inside(uv) && dec(texture(heights, uv).r) > ref_y + 1.6) {
		float hatch = step(0.6, fract((FRAGCOORD.x + FRAGCOORD.y) / 6.0));
		col.rgb = mix(col.rgb, above_col.rgb, above_col.a * hatch);
		col.a = max(col.a, 0.8);
	}

	if (round_mask) {
		float r = length(UV - 0.5) * 2.0;
		col.a *= 1.0 - smoothstep(1.0 - fwidth(r) * 1.5, 1.0, r);
	}
	COLOR = col;
}
