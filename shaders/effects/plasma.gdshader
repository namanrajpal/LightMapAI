shader_type canvas_item;
// @name Plasma
// @description Classic plasma effect with swirling color waves
// @emoji 🌀

// @range 0.5 8.0 0.1
uniform float scale = 3.0;
// @range 0.1 3.0 0.05
uniform float speed = 1.0;
// @range 1.0 6.0 0.5
uniform float complexity = 3.0;
// @range 0.0 1.0 0.01
uniform float saturation = 0.85;
// @range 0.2 0.8 0.01
uniform float brightness = 0.55;
// @range 0.0 360.0 1.0
uniform float hue_shift = 0.0;
// @range 0.0 1.0 0.01
uniform float contrast = 0.5;

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
	vec2 uv = UV * scale;
	float t = TIME * speed;

	// Layer multiple sine waves for plasma pattern
	float v = 0.0;

	// Wave 1: horizontal
	v += sin(uv.x + t);

	// Wave 2: diagonal
	v += sin((uv.y + t) * 0.7);

	// Wave 3: circular
	float cx = uv.x + 0.5 * sin(t * 0.3);
	float cy = uv.y + 0.5 * cos(t * 0.4);
	v += sin(sqrt(cx * cx + cy * cy + 1.0) * 2.0);

	// Wave 4: complex (if complexity > 2)
	if (complexity > 2.0) {
		v += sin(uv.x * sin(t * 0.2) + uv.y * cos(t * 0.3));
	}

	// Wave 5: interference (if complexity > 3)
	if (complexity > 3.0) {
		float dx = uv.x - 0.5 * scale;
		float dy = uv.y - 0.5 * scale;
		v += sin(sqrt(dx * dx + dy * dy) * 3.0 - t * 1.5);
	}

	// Wave 6: turbulence (if complexity > 4)
	if (complexity > 4.0) {
		v += 0.5 * sin(uv.x * 3.0 + sin(uv.y * 2.0 + t));
	}

	// Normalize to 0-1 range
	v = v / (2.0 + min(complexity, 6.0));
	v = v * 0.5 + 0.5;

	// Apply contrast
	v = mix(0.5, v, 1.0 + contrast);
	v = clamp(v, 0.0, 1.0);

	// Map to color via hue
	float hue = mod(v * 360.0 + hue_shift + t * 20.0, 360.0);
	vec3 col = hsl2rgb(hue, saturation, brightness);

	COLOR = vec4(col, 1.0);
}
