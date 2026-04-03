shader_type canvas_item;
// @name Edge Glow
// @description Animated glowing border with color cycling and breathing pulse
// @emoji 🔲

// @range 0.0 360.0 1.0
uniform float hue_offset = 0.0;
// @range 0.005 0.15 0.005
uniform float edge_thickness = 0.04;
// @range 0.0 1.0 0.01
uniform float glow_intensity = 0.7;
// @range 0.0 0.3 0.005
uniform float glow_spread = 0.12;
// @range 0.5 5.0 0.1
uniform float pulse_speed = 1.5;
// @range 10.0 80.0 1.0
uniform float color_speed = 30.0;
// @range 0.0 1.0 0.01
uniform float inner_darkness = 0.95;
// @range 1.0 4.0 1.0
uniform float edge_count = 1.0;

vec3 hsl2rgb(float h, float s, float l) {
	float c = (1.0 - abs(2.0 * l - 1.0)) * s;
	float hp = h / 60.0;
	float x = c * (1.0 - abs(mod(hp, 2.0) - 1.0));
	vec3 rgb;
	if (hp < 1.0) rgb = vec3(c, x, 0.0);
	else if (hp < 2.0) rgb = vec3(x, c, 0.0);
	else if (hp < 3.0) rgb = vec3(0.0, c, x);
	else if (hp < 4.0) rgb = vec3(0.0, x, c);
	else if (hp < 5.0) rgb = vec3(x, 0.0, c);
	else rgb = vec3(c, 0.0, x);
	return rgb + vec3(l - c * 0.5);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	// Distance from each edge
	float d_left = uv.x;
	float d_right = 1.0 - uv.x;
	float d_top = uv.y;
	float d_bottom = 1.0 - uv.y;
	float d_edge = min(min(d_left, d_right), min(d_top, d_bottom));

	// Breathing pulse
	float breath = 0.7 + 0.3 * sin(t * pulse_speed);

	// Base hue cycles over time
	float base_hue = mod(t * color_speed + hue_offset, 360.0);

	// Dark interior
	vec3 col = vec3(0.0);

	// Multiple edge layers
	for (float i = 0.0; i < 4.0; i += 1.0) {
		if (i >= edge_count) break;
		float layer_offset = i * edge_thickness * 1.5;
		float layer_d = d_edge - layer_offset;

		// Sharp edge line
		float edge_mask = smoothstep(edge_thickness, edge_thickness * 0.3, layer_d);
		edge_mask *= smoothstep(0.0, edge_thickness * 0.5, layer_d + edge_thickness);

		// Soft glow around edge
		float glow_mask = exp(-layer_d * layer_d / (glow_spread * glow_spread + 0.0001));

		// Per-edge hue variation
		float hue = mod(base_hue + i * 90.0, 360.0);

		// Vary brightness along the perimeter
		float perimeter_pos = 0.0;
		if (d_edge == d_top) perimeter_pos = uv.x;
		else if (d_edge == d_right) perimeter_pos = uv.y;
		else if (d_edge == d_bottom) perimeter_pos = 1.0 - uv.x;
		else perimeter_pos = 1.0 - uv.y;

		float shimmer = 0.7 + 0.3 * sin(perimeter_pos * 12.0 + t * 3.0 + i * 2.0);

		vec3 edge_col = hsl2rgb(hue, 0.9, 0.55) * shimmer;

		col += edge_col * edge_mask * glow_intensity * breath;
		col += edge_col * glow_mask * glow_intensity * 0.4 * breath;
	}

	// Subtle vignette to darken center
	float vignette = smoothstep(0.0, 0.3, d_edge) * inner_darkness;
	col *= mix(1.0, 1.0 - vignette * 0.5, inner_darkness);

	COLOR = vec4(col, 1.0);
}
