shader_type canvas_item;
// @name Scan Lines
// @description Retro CRT scan lines sweeping across the surface with edge emphasis
// @emoji 📺

uniform vec4 line_color : source_color = vec4(0.0, 1.0, 0.5, 1.0);
// @range 20.0 200.0 5.0
uniform float line_count = 80.0;
// @range 0.0 5.0 0.1
uniform float scroll_speed = 1.5;
// @range 0.1 0.9 0.01
uniform float line_opacity = 0.5;
// @range 0.0 1.0 0.01
uniform float edge_boost = 0.6;
// @range 0.01 0.15 0.005
uniform float edge_width = 0.05;
// @range 0.0 1.0 0.01
uniform float flicker_amount = 0.1;
// @range 0.0 0.1 0.005
uniform float bg_brightness = 0.02;
// @range 0.0 1.0 0.01
uniform float sweep_intensity = 0.3;

float hash(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	// Scan lines
	float scan_y = uv.y * line_count + t * scroll_speed * line_count;
	float scan = 0.5 + 0.5 * sin(scan_y * 3.14159 * 2.0);
	scan = pow(scan, 2.0);  // Sharpen

	// Sweep bar — a brighter band that moves down
	float sweep_pos = fract(t * scroll_speed * 0.3);
	float sweep_dist = abs(uv.y - sweep_pos);
	sweep_dist = min(sweep_dist, 1.0 - sweep_dist);  // Wrap
	float sweep = exp(-sweep_dist * sweep_dist / 0.01) * sweep_intensity;

	// Edge distance
	float d_edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float edge_mask = smoothstep(edge_width, 0.0, d_edge);

	// Flicker
	float flick = 1.0 - flicker_amount * hash(floor(t * 30.0));

	// Compose
	vec3 col = vec3(bg_brightness) * line_color.rgb;

	// Scan lines across the whole surface
	col += line_color.rgb * scan * line_opacity * flick;

	// Sweep highlight
	col += line_color.rgb * sweep * flick;

	// Edge emphasis — brighter scan lines near edges
	col += line_color.rgb * scan * edge_mask * edge_boost * flick;

	// Edge border glow
	float border = smoothstep(edge_width * 0.5, 0.0, d_edge);
	col += line_color.rgb * border * 0.3;

	COLOR = vec4(col, 1.0);
}
