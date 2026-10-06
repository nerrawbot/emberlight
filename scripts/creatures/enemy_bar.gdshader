shader_type spatial;
// Floating enemy health bar (enemy.gd): a camera-facing quad with a cream frame, a dark back, a pale damage trail
// and the coloured fill. Unshaded and fog-free so it reads in the haze.
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled, blend_mix;

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float trail : hint_range(0.0, 1.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.95, 0.3, 0.18, 1.0);
uniform vec2 size = vec2(1.0, 0.11);   // the quad's size in metres (for an even frame)
uniform float frame = 0.016;

void vertex() {
	// billboard that keeps the node's scale
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * size;
	bool edge = p.x < frame || p.x > size.x - frame || p.y < frame || p.y > size.y - frame;
	float x = (p.x - frame) / (size.x - 2.0 * frame);
	vec3 c = vec3(0.035, 0.03, 0.045);
	float a = 0.72;
	if (x < trail) {
		c = vec3(1.0, 0.9, 0.72);
		a = 0.95;
	}
	if (x < fill) {
		c = fill_color.rgb * (UV.y < 0.45 ? 1.15 : 0.82);   // a lit top half reads as a bevel
		a = 1.0;
	}
	if (edge) {
		c = vec3(0.93, 0.9, 0.82);
		a = 1.0;
	}
	ALBEDO = c;
	ALPHA = a * alpha;
}
