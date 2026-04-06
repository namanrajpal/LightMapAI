shader_type canvas_item;
// @name Plasma Ocean
// @description Deep ocean plasma with flowing water caustics
// @emoji 🌊

// @range 0.5 8.0 0.1
uniform float scale = 3.0;
// @range 0.1 3.0 0.05
uniform float speed = 0.6;
// @range 0.0 1.0 0.01
uniform float depth = 0.7;
uniform vec4 color_shallow : source_color = vec4(0.1, 0.8, 0.9, 1.0);
uniform vec4 color_deep : source_color = vec4(0.0, 0.1, 0.4, 1.0);
// @range 0.0 1.0 0.01
uniform float caustic_strength = 0.5;
// @range 1.0 5.0 0.5
uniform float wave_layers = 3.0;

void fragment() {
	vec2 uv = UV * scale;
	float t = TIME * speed;

	// Layered caustic waves
	float caustic = 0.0;
	for (float i = 1.0; i <= 5.0; i += 1.0) {
		if (i > wave_layers) break;
		float s = i * 0.7;
		vec2 p = uv * s + vec2(t * 0.3 * i, t * 0.2 * (i + 1.0));
		caustic += sin(p.x + sin(p.y + t * 0.5)) * (1.0 / i);
		caustic += cos(p.y * 1.3 + cos(p.x * 0.8 + t * 0.4)) * (0.7 / i);
	}

	caustic = caustic * 0.5 + 0.5;
	caustic = pow(caustic, 1.5) * caustic_strength;

	// Depth gradient
	float d = mix(0.3, 1.0, depth);
	float gradient = UV.y * d;

	// Color mixing
	vec3 base = mix(color_shallow.rgb, color_deep.rgb, gradient);
	vec3 highlight = color_shallow.rgb * 1.3;

	vec3 col = base + highlight * caustic * 0.6;

	// Subtle shimmer
	float shimmer = sin(uv.x * 8.0 + t * 2.0) * sin(uv.y * 6.0 - t * 1.5) * 0.05;
	col += vec3(shimmer);

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
