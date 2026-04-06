shader_type canvas_item;
// @name Edge Plasma
// @description Plasma energy that flows along the edges, fading toward center
// @emoji 🔮

uniform vec4 color_a : source_color = vec4(0.2, 0.5, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.8, 0.2, 1.0, 1.0);
// @range 0.5 6.0 0.1
uniform float scale = 3.0;
// @range 0.1 3.0 0.05
uniform float speed = 1.0;
// @range 0.02 0.4 0.01
uniform float edge_width = 0.15;
// @range 0.5 5.0 0.1
uniform float plasma_intensity = 2.0;
// @range 0.0 1.0 0.01
uniform float inner_fade = 0.0;

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;

	// Distance from nearest edge
	float d = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));

	// Edge mask — strong at edges, fading inward
	float edge_mask = smoothstep(edge_width, 0.0, d);
	edge_mask += inner_fade * smoothstep(edge_width * 3.0, edge_width, d) * 0.3;

	// Plasma pattern along the edges
	vec2 puv = uv * scale;
	float plasma = 0.0;
	plasma += sin(puv.x * 3.0 + t * 1.3);
	plasma += sin(puv.y * 2.5 - t * 0.9);
	plasma += sin((puv.x + puv.y) * 2.0 + t * 0.7);
	plasma += sin(length(puv - scale * 0.5) * 3.0 - t * 1.5);
	plasma = plasma * 0.25 + 0.5;

	// Color blend
	vec3 col = mix(color_a.rgb, color_b.rgb, plasma);
	col *= edge_mask * plasma_intensity;

	COLOR = vec4(col, 1.0);
}
