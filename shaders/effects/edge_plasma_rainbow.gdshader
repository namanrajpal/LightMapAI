shader_type canvas_item;
// @name Edge Plasma Rainbow
// @description Rainbow plasma flowing along the edges with smooth color cycling
// @emoji 🌈

// @range 0.5 6.0 0.1
uniform float scale = 3.0;
// @range 0.1 3.0 0.05
uniform float speed = 0.8;
// @range 0.02 0.35 0.01
uniform float edge_width = 0.15;
// @range 0.5 4.0 0.1
uniform float glow_intensity = 2.0;
// @range 0.5 1.0 0.01
uniform float saturation = 0.9;
// @range 0.3 0.7 0.01
uniform float lightness = 0.55;
// @range 10.0 120.0 5.0
uniform float color_speed = 40.0;

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
	float t = TIME * speed;

	float d = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));

	// Edge mask with soft glow
	float edge_mask = smoothstep(edge_width, 0.0, d);
	float glow_mask = smoothstep(edge_width * 3.0, 0.0, d) * 0.4;

	// Plasma pattern for variation
	vec2 puv = uv * scale;
	float plasma = 0.0;
	plasma += sin(puv.x * 2.5 + t * 1.2);
	plasma += sin(puv.y * 2.0 - t * 0.8);
	plasma += sin((puv.x + puv.y) * 1.5 + t);
	plasma = plasma / 3.0;

	// Perimeter position for color flow — hue travels around the border
	float perimeter = 0.0;
	if (d == uv.y) perimeter = uv.x;                          // top edge
	else if (d == 1.0 - uv.x) perimeter = 1.0 + uv.y;        // right edge
	else if (d == 1.0 - uv.y) perimeter = 2.0 + (1.0 - uv.x); // bottom edge
	else perimeter = 3.0 + (1.0 - uv.y);                       // left edge
	perimeter /= 4.0;  // Normalize to 0-1

	// Rainbow hue based on perimeter position + time
	float hue = mod(perimeter * 360.0 + t * color_speed + plasma * 60.0, 360.0);
	vec3 col = hsl2rgb(hue, saturation, lightness);

	col *= (edge_mask * glow_intensity + glow_mask);

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
