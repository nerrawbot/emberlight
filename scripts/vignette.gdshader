shader_type canvas_item;
// Painterly framing: dark purple vignette plus faint grain.
uniform float strength = 0.75;
uniform float inner = 0.32;
uniform float outer = 0.85;
uniform vec4 tint : source_color = vec4(0.015, 0.01, 0.035, 1.0);
uniform float grain = 0.025;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= 1.35;
	float v = smoothstep(inner, outer, length(uv)) * strength;
	float n = (hash(UV * 731.0 + fract(TIME) * 17.0) - 0.5) * grain;
	COLOR = vec4(tint.rgb + n, clamp(v + n, 0.0, 1.0));
}
