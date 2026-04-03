shader_type canvas_item;
// @name Neon Border
// @description Steady neon glow border with inner and outer bloom — no animation
// @emoji 💡

uniform vec4 glow_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
// @range 0.005 0.1 0.005
uniform float border_thickness = 0.02;
// @range 0.0 0.3 0.005
uniform float bloom_size = 0.08;
// @range 0.5 5.0 0.1
uniform float bloom_intensity = 2.0;
// @range 0.0 1.0 0.01
uniform float inner_fill = 0.0;
// @range 0.0 1.0 0.01
uniform float corner_radius = 0.0;

void fragment() {
	vec2 uv = UV;

	// Distance from each edge
	float d_left = uv.x;
	float d_right = 1.0 - uv.x;
	float d_top = uv.y;
	float d_bottom = 1.0 - uv.y;

	// Rounded corner SDF
	float d_edge;
	if (corner_radius > 0.0) {
		float r = corner_radius * 0.5;
		vec2 p = abs(uv - 0.5) - (0.5 - r);
		d_edge = length(max(p, vec2(0.0))) - r;
		// Remap so 0 = on the edge, positive = inside
		d_edge = -d_edge;
	} else {
		d_edge = min(min(d_left, d_right), min(d_top, d_bottom));
	}

	// Hard border line
	float border_mask = 0.0;
	if (d_edge > 0.0 && d_edge < border_thickness) {
		border_mask = 1.0;
	}

	// Soft bloom around the border
	float bloom_center = border_thickness * 0.5;
	float dist_from_border = abs(d_edge - bloom_center);
	float bloom = exp(-dist_from_border * dist_from_border / (bloom_size * bloom_size + 0.0001));

	// Combine
	vec3 col = vec3(0.0);

	// Inner fill
	if (d_edge > border_thickness) {
		col = glow_color.rgb * inner_fill * 0.1;
	}

	// Bloom
	col += glow_color.rgb * bloom * bloom_intensity * 0.3;

	// Hard border on top
	col += glow_color.rgb * border_mask;

	// Bright core of the border
	float core_dist = abs(d_edge - bloom_center);
	float core = smoothstep(border_thickness * 0.5, 0.0, core_dist);
	col += vec3(1.0) * core * 0.4;  // White-hot center

	COLOR = vec4(col, 1.0);
}
