shader_type canvas_item;
// @name Neon Pulse
// @description Color-cycling neon borders with pulsing glow, traveling lights, and random flashes
// @emoji 🔴

// --- User parameters ---

// @range 0.0 360.0 1.0
uniform float hue_offset = 0.0;
// @range 10.0 120.0 1.0
uniform float cycle_speed = 40.0;
// @range 0.0 1.0 0.01
uniform float border_intensity = 0.7;
// @range 4.0 40.0 1.0
uniform float border_width = 16.0;
// @range 0.0 1.0 0.01
uniform float glow_strength = 0.5;
// @range 50.0 500.0 10.0
uniform float travel_speed = 250.0;
// @range 0.0 1.0 0.01
uniform float flash_probability = 0.12;
// @range 0.0 1.0 0.01
uniform float center_pulse_strength = 0.3;

// --- Internal ---
uniform vec2 _resolution = vec2(1920.0, 1080.0);

// HSL to RGB conversion
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
	float m = l - c * 0.5;
	return rgb + vec3(m);
}

// Simple pseudo-random
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float base_hue = mod(t * cycle_speed + hue_offset, 360.0);

	// Dark background with shifting hue
	vec3 bg = hsl2rgb(base_hue, 0.6, 0.05);
	vec3 col = bg;

	// Center radial pulse
	float dist_center = length(uv - vec2(0.5));
	float pulse = center_pulse_strength + sin(t * 2.0) * 0.2;
	vec3 center_col = hsl2rgb(mod(base_hue + 20.0, 360.0), 0.8, 0.25);
	col += center_col * pulse * smoothstep(0.7, 0.0, dist_center);

	// Edge glow — 4 edges with phase-shifted hues
	float edge_norm = border_width / _resolution.x;  // Approximate normalized edge width
	float edge_depth = edge_norm * 4.0;

	// Top edge
	float top_pulse = 0.5 + sin(t * 3.0) * 0.4;
	vec3 top_col = hsl2rgb(mod(base_hue, 360.0), 1.0, 0.6);
	col += top_col * top_pulse * glow_strength * smoothstep(edge_depth, 0.0, uv.y);

	// Bottom edge
	float bot_pulse = 0.5 + sin(t * 3.0 + 1.1) * 0.4;
	vec3 bot_col = hsl2rgb(mod(base_hue + 90.0, 360.0), 1.0, 0.6);
	col += bot_col * bot_pulse * glow_strength * smoothstep(edge_depth, 0.0, 1.0 - uv.y);

	// Left edge
	float left_pulse = 0.5 + sin(t * 3.0 + 2.2) * 0.4;
	vec3 left_col = hsl2rgb(mod(base_hue + 180.0, 360.0), 1.0, 0.6);
	col += left_col * left_pulse * glow_strength * smoothstep(edge_depth, 0.0, uv.x);

	// Right edge
	float right_pulse = 0.5 + sin(t * 3.0 + 3.3) * 0.4;
	vec3 right_col = hsl2rgb(mod(base_hue + 270.0, 360.0), 1.0, 0.6);
	col += right_col * right_pulse * glow_strength * smoothstep(edge_depth, 0.0, 1.0 - uv.x);

	// Neon border — thick outer + thin inner
	float bw = border_width / _resolution.x;
	float bh = border_width / _resolution.y;
	float border_mask = 0.0;
	if (uv.x < bw || uv.x > 1.0 - bw || uv.y < bh || uv.y > 1.0 - bh) {
		border_mask = 1.0;
	}
	float border_pulse_val = border_intensity + sin(t * 2.5) * 0.3;
	vec3 border_col = hsl2rgb(mod(base_hue + 180.0, 360.0), 1.0, 0.6);
	col = mix(col, border_col, border_mask * border_pulse_val);

	// Thin inner border
	float inner_off = bw * 2.5;
	float inner_off_h = bh * 2.5;
	float inner_w = bw * 0.3;
	float inner_h = bh * 0.3;
	float inner_mask = 0.0;
	if ((uv.x > inner_off - inner_w && uv.x < inner_off + inner_w) ||
		(uv.x > 1.0 - inner_off - inner_w && uv.x < 1.0 - inner_off + inner_w) ||
		(uv.y > inner_off_h - inner_h && uv.y < inner_off_h + inner_h) ||
		(uv.y > 1.0 - inner_off_h - inner_h && uv.y < 1.0 - inner_off_h + inner_h)) {
		inner_mask = 1.0;
	}
	vec3 inner_col = hsl2rgb(mod(base_hue + 220.0, 360.0), 1.0, 0.5);
	col = mix(col, inner_col, inner_mask * 0.35);

	// Traveling light along the perimeter
	// Map perimeter position: top(0..1) -> right(1..2) -> bottom(2..3) -> left(3..4)
	float perim_t = mod(t * travel_speed / (_resolution.x + _resolution.y), 4.0);
	vec2 light_pos;
	if (perim_t < 1.0) {
		light_pos = vec2(perim_t, 0.0);
	} else if (perim_t < 2.0) {
		light_pos = vec2(1.0, perim_t - 1.0);
	} else if (perim_t < 3.0) {
		light_pos = vec2(1.0 - (perim_t - 2.0), 1.0);
	} else {
		light_pos = vec2(0.0, 1.0 - (perim_t - 3.0));
	}
	float light_dist = length(uv - light_pos);
	vec3 light_col = hsl2rgb(mod(base_hue + 90.0, 360.0), 1.0, 0.7);
	col += light_col * 0.9 * smoothstep(0.08, 0.0, light_dist);
	col += light_col * 0.4 * smoothstep(0.15, 0.0, light_dist);

	// Random flash (time-based pseudo-random)
	float flash_seed = hash(vec2(floor(t * 15.0), 0.0));
	if (flash_seed > 1.0 - flash_probability) {
		float flash_hue = mod(base_hue + flash_seed * 180.0, 360.0);
		col += hsl2rgb(flash_hue, 1.0, 0.5) * (0.06 + flash_seed * 0.1);
	}

	COLOR = vec4(col, 1.0);
}
