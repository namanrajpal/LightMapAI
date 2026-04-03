shader_type canvas_item;
// @name Candle Flame
// @description Flickering flame particles rising from the bottom with warm glow
// @emoji 🕯️

// --- User parameters ---

// @range 0.1 3.0 0.1
uniform float flame_speed = 1.0;
// @range 0.0 1.0 0.01
uniform float flame_intensity = 0.8;
// @range 0.1 2.0 0.05
uniform float flame_width = 0.6;
// @range 0.0 1.0 0.01
uniform float flicker_amount = 0.3;
uniform vec4 tip_color : source_color = vec4(1.0, 0.3, 0.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
// @range 0.0 1.0 0.01
uniform float glow_radius = 0.5;
// @range 0.0 1.0 0.01
uniform float smoke_amount = 0.15;

// --- Internal ---
uniform vec2 _resolution = vec2(1920.0, 1080.0);

// Noise functions
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		val += amp * noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return val;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * flame_speed;

	// Aspect correction
	float aspect = _resolution.x / _resolution.y;
	vec2 centered = (uv - vec2(0.5)) * vec2(aspect, 1.0);

	// Black background
	vec3 col = vec3(0.0);

	// --- Flame shape ---
	// Flame is centered horizontally, rises from bottom
	vec2 flame_uv = vec2(centered.x, uv.y);

	// Vertical position: 0 at bottom, 1 at top
	float vy = 1.0 - uv.y;

	// Flame envelope — wider at bottom, narrow at top
	float envelope_width = flame_width * (0.15 + 0.85 * pow(1.0 - vy, 1.5));

	// Add noise-based distortion for organic movement
	float noise_x = fbm(vec2(flame_uv.x * 3.0 + t * 0.5, vy * 4.0 - t * 2.0)) - 0.5;
	float noise_y = fbm(vec2(flame_uv.x * 2.0 + 100.0, vy * 3.0 - t * 1.5)) - 0.5;

	float distorted_x = centered.x + noise_x * 0.15 * vy;
	float dist_from_center = abs(distorted_x) / max(envelope_width, 0.001);

	// Flame density — strongest at center-bottom, fading outward and upward
	float flame = smoothstep(1.0, 0.0, dist_from_center);
	flame *= smoothstep(0.0, 0.15, vy);  // Fade in from very bottom
	flame *= smoothstep(1.0, 0.3, vy);   // Fade out toward top

	// Add turbulence
	float turb = fbm(vec2(distorted_x * 8.0, vy * 6.0 - t * 3.0));
	flame *= 0.6 + 0.4 * turb;

	// Flicker
	float flicker = 1.0 - flicker_amount * (0.5 + 0.5 * sin(t * 12.0 + sin(t * 7.0) * 3.0));
	flame *= flicker;

	// Color gradient: white-hot core → orange → red tip
	vec3 flame_col;
	if (vy < 0.3) {
		// Bottom: hot white/yellow core
		flame_col = mix(core_color.rgb, vec3(1.0, 1.0, 0.9), smoothstep(0.3, 0.0, vy));
	} else if (vy < 0.6) {
		// Middle: orange
		float mt = (vy - 0.3) / 0.3;
		flame_col = mix(core_color.rgb, tip_color.rgb, mt);
	} else {
		// Top: red/dark tip
		float mt = (vy - 0.6) / 0.4;
		flame_col = mix(tip_color.rgb, tip_color.rgb * 0.3, mt);
	}

	col += flame_col * flame * flame_intensity;

	// --- Inner core glow (additive) ---
	float core_dist = length(vec2(centered.x, (uv.y - 0.85)) * vec2(1.0, 0.6));
	float core_glow = exp(-core_dist * core_dist * 20.0) * 0.6 * flicker;
	col += vec3(1.0, 0.95, 0.8) * core_glow;

	// --- Outer warm glow ---
	float glow_dist = length(vec2(centered.x, (uv.y - 0.7)) * vec2(0.8, 0.5));
	float outer_glow = exp(-glow_dist * glow_dist / (glow_radius * glow_radius + 0.001)) * 0.15;
	col += tip_color.rgb * outer_glow;

	// --- Smoke wisps above flame ---
	if (smoke_amount > 0.0 && vy > 0.5) {
		float smoke_noise = fbm(vec2(centered.x * 4.0 + t * 0.3, vy * 3.0 - t * 0.8));
		float smoke_mask = smoothstep(0.5, 0.9, vy) * smoothstep(1.0, 0.7, vy);
		smoke_mask *= smoothstep(0.3, 0.0, abs(centered.x));
		float smoke = smoke_noise * smoke_mask * smoke_amount;
		col += vec3(0.15, 0.12, 0.1) * smoke;
	}

	// --- Ember particles (pseudo-random dots) ---
	for (int i = 0; i < 8; i++) {
		float seed = float(i) * 1.618;
		float ember_t = fract(t * 0.3 + seed * 0.7);
		float ex = (hash12(vec2(seed, 1.0)) - 0.5) * flame_width * 0.8;
		ex += sin(t * 2.0 + seed * 5.0) * 0.05;
		float ey = 1.0 - ember_t;  // Rise from bottom to top
		vec2 ember_pos = vec2(ex / aspect, ey);
		float ember_dist = length((uv - vec2(0.5, 0.0) - ember_pos) * vec2(aspect, 1.0));
		float ember_brightness = smoothstep(0.01, 0.0, ember_dist) * (1.0 - ember_t);
		col += vec3(1.0, 0.6, 0.1) * ember_brightness * flame_intensity;
	}

	COLOR = vec4(col, 1.0);
}
