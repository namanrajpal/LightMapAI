shader_type canvas_item;
// @name Plasma Aurora
// @description Northern lights aurora effect with flowing curtains of color
// @emoji 🌌

// @range 0.5 6.0 0.1
uniform float scale = 2.5;
// @range 0.1 2.0 0.05
uniform float speed = 0.5;
// @range 0.0 1.0 0.01
uniform float intensity = 0.8;
uniform vec4 color_a : source_color = vec4(0.1, 1.0, 0.5, 1.0);
uniform vec4 color_b : source_color = vec4(0.2, 0.4, 1.0, 1.0);
uniform vec4 color_c : source_color = vec4(0.8, 0.2, 0.9, 1.0);
// @range 1.0 8.0 0.5
uniform float curtain_count = 3.0;
// @range 0.0 1.0 0.01
uniform float vertical_fade = 0.6;

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;

	// Aurora curtains — vertical bands that wave horizontally
	float aurora = 0.0;
	for (float i = 1.0; i <= 8.0; i += 1.0) {
		if (i > curtain_count) break;
		float freq = i * 1.5 + 0.5;
		float phase = t * (0.3 + i * 0.15) + i * 1.7;
		float wave = sin(uv.x * scale * freq + phase + sin(uv.x * scale * 0.5 + t * 0.2) * 2.0);
		wave *= exp(-pow((uv.y - 0.3 - wave * 0.1) * 3.0, 2.0));
		aurora += wave * (1.0 / i);
	}

	aurora = aurora * 0.5 + 0.5;
	aurora = pow(aurora, 1.3) * intensity;

	// Vertical fade — aurora is brighter at top
	float vfade = 1.0 - uv.y * vertical_fade;
	aurora *= vfade;

	// Color cycling through three colors based on position and time
	float color_phase = uv.x * 2.0 + t * 0.3;
	float mix1 = sin(color_phase) * 0.5 + 0.5;
	float mix2 = sin(color_phase + 2.094) * 0.5 + 0.5;  // +120 degrees
	float mix3 = sin(color_phase + 4.189) * 0.5 + 0.5;  // +240 degrees
	float total = mix1 + mix2 + mix3 + 0.001;

	vec3 col = (color_a.rgb * mix1 + color_b.rgb * mix2 + color_c.rgb * mix3) / total;
	col *= aurora;

	// Dark sky background
	vec3 sky = vec3(0.01, 0.01, 0.03);
	col = max(col, sky);

	COLOR = vec4(col, 1.0);
}
