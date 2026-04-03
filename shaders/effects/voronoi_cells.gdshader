shader_type canvas_item;
// @name Voronoi Cells
// @description Animated voronoi pattern with glowing cell edges
// @emoji 🔷

// @range 2.0 20.0 1.0
uniform float cell_count = 8.0;
// @range 0.1 2.0 0.05
uniform float animation_speed = 0.5;
// @range 0.0 1.0 0.01
uniform float edge_glow = 0.8;
// @range 0.005 0.08 0.005
uniform float edge_width = 0.03;
// @range 0.0 1.0 0.01
uniform float cell_fill = 0.15;
// @range 0.0 360.0 1.0
uniform float hue_offset = 200.0;
// @range 10.0 60.0 1.0
uniform float color_speed = 25.0;
// @range 0.0 1.0 0.01
uniform float pulse_amount = 0.3;

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

vec2 hash2v(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

void fragment() {
	vec2 uv = UV * cell_count;
	float t = TIME * animation_speed;

	// Voronoi calculation
	vec2 i_uv = floor(uv);
	vec2 f_uv = fract(uv);

	float min_dist = 10.0;
	float second_dist = 10.0;
	vec2 closest_cell = vec2(0.0);
	float closest_id = 0.0;

	// Check 3x3 neighborhood
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 cell = i_uv + neighbor;

			// Animated cell center
			vec2 point = hash2v(cell);
			point = 0.5 + 0.4 * sin(t + 6.2831 * point);

			vec2 diff = neighbor + point - f_uv;
			float dist = length(diff);

			if (dist < min_dist) {
				second_dist = min_dist;
				min_dist = dist;
				closest_cell = cell;
				closest_id = hash2v(cell).x;
			} else if (dist < second_dist) {
				second_dist = dist;
			}
		}
	}

	// Edge detection: difference between closest and second closest
	float edge = second_dist - min_dist;

	// Base color: dark
	vec3 col = vec3(0.0);

	// Cell fill color (subtle, per-cell hue)
	float cell_hue = mod(closest_id * 360.0 + hue_offset + TIME * color_speed, 360.0);
	float pulse = 1.0 - pulse_amount + pulse_amount * sin(t * 2.0 + closest_id * 6.28);
	vec3 fill_col = hsl2rgb(cell_hue, 0.6, 0.15) * pulse;
	col += fill_col * cell_fill;

	// Edge glow
	float edge_mask = smoothstep(edge_width, edge_width * 0.2, edge);
	float soft_glow = exp(-edge * edge / (edge_width * edge_width * 8.0));

	float edge_hue = mod(hue_offset + TIME * color_speed, 360.0);
	vec3 edge_col = hsl2rgb(edge_hue, 0.9, 0.6);

	col += edge_col * edge_mask * edge_glow;
	col += edge_col * soft_glow * edge_glow * 0.3;

	// Bright dots at cell centers
	float center_dot = smoothstep(0.08, 0.02, min_dist);
	vec3 dot_col = hsl2rgb(cell_hue, 0.8, 0.7);
	col += dot_col * center_dot * 0.6 * pulse;

	COLOR = vec4(col, 1.0);
}
