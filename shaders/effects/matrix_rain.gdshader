shader_type canvas_item;
// @name Matrix Rain
// @description Digital rain effect with falling characters on dark background
// @emoji 💚

// @range 8.0 64.0 4.0
uniform float columns = 32.0;
// @range 0.5 5.0 0.1
uniform float fall_speed = 2.0;
// @range 0.1 1.0 0.01
uniform float density = 0.6;
// @range 0.0 1.0 0.01
uniform float glow_amount = 0.4;
uniform vec4 rain_color : source_color = vec4(0.0, 1.0, 0.3, 1.0);
// @range 0.0 1.0 0.01
uniform float fade_length = 0.4;
// @range 0.0 0.15 0.01
uniform float bg_brightness = 0.02;
// @range 0.5 3.0 0.1
uniform float char_brightness = 1.0;

// Pseudo-random functions
float hash(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Procedural character-like pattern
float character(vec2 uv, float seed) {
	// Create a grid of dots/lines that looks like characters
	vec2 grid = fract(uv * vec2(3.0, 4.0));
	float pattern = hash2(floor(uv * vec2(3.0, 4.0)) + seed);

	// Different "character" shapes based on hash
	float c = 0.0;
	if (pattern < 0.3) {
		// Horizontal bars
		c = step(0.3, grid.x) * step(grid.x, 0.7);
		c *= step(abs(grid.y - 0.5), 0.15 + 0.2 * hash(seed + 1.0));
	} else if (pattern < 0.6) {
		// Vertical bars
		c = step(0.3, grid.y) * step(grid.y, 0.7);
		c *= step(abs(grid.x - 0.5), 0.15 + 0.2 * hash(seed + 2.0));
	} else if (pattern < 0.8) {
		// Cross
		float h = step(abs(grid.x - 0.5), 0.12);
		float v = step(abs(grid.y - 0.5), 0.12);
		c = max(h, v);
	} else {
		// Dot cluster
		float d = length(grid - vec2(0.5));
		c = step(d, 0.25);
	}
	return c;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * fall_speed;

	// Dark background
	vec3 col = vec3(bg_brightness) * rain_color.rgb;

	float cell_w = 1.0 / columns;
	float rows = columns * 2.0;  // Taller cells
	float cell_h = 1.0 / rows;

	// Column index
	float col_idx = floor(uv.x * columns);
	float col_fract = fract(uv.x * columns);

	// Per-column random properties
	float col_seed = hash(col_idx * 7.13);
	float col_speed = 0.5 + col_seed * 1.0;
	float col_offset = col_seed * 100.0;
	float col_active = step(1.0 - density, col_seed);

	if (col_active > 0.0) {
		// Falling position for this column
		float fall_pos = fract(t * col_speed + col_offset);

		// Row index (scrolling)
		float scroll_y = uv.y + fall_pos;
		float row_idx = floor(scroll_y * rows);
		float row_fract = fract(scroll_y * rows);

		// Distance from the "head" of the rain drop
		float head_y = fall_pos;
		float dist_from_head = fract(uv.y - head_y + 1.0);

		// Fade trail
		float trail = smoothstep(fade_length, 0.0, dist_from_head);
		trail *= smoothstep(0.0, 0.05, dist_from_head);  // Fade at very tip

		// Character pattern
		float char_seed = hash2(vec2(col_idx, row_idx));
		// Characters change over time (flickering)
		float flicker_seed = hash2(vec2(col_idx, row_idx + floor(t * 3.0)));
		float char_val = character(vec2(col_fract, row_fract), flicker_seed * 100.0);

		// Brightness: head is brightest (white), trail fades to green
		float head_dist = abs(dist_from_head);
		float is_head = smoothstep(0.03, 0.0, head_dist);

		vec3 char_col = rain_color.rgb * trail * char_brightness;
		// Head glows white
		char_col = mix(char_col, vec3(1.0), is_head * 0.8);

		col += char_col * char_val;

		// Soft glow around characters
		float glow = trail * glow_amount * 0.3;
		col += rain_color.rgb * glow;
	}

	// Add a second rain layer at different speed for depth
	float col_idx2 = floor(uv.x * columns * 0.7 + 5.0);
	float col_seed2 = hash(col_idx2 * 13.37);
	float col_active2 = step(1.0 - density * 0.5, col_seed2);
	if (col_active2 > 0.0) {
		float fall_pos2 = fract(t * (0.3 + col_seed2 * 0.5) + col_seed2 * 50.0);
		float dist2 = fract(uv.y - fall_pos2 + 1.0);
		float trail2 = smoothstep(fade_length * 0.7, 0.0, dist2) * 0.3;
		col += rain_color.rgb * trail2 * 0.15;
	}

	COLOR = vec4(col, 1.0);
}
