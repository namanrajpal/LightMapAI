shader_type canvas_item;
// @name Electric Cracks
// @description Lightning-like cracks spreading from edges with electric glow
// @emoji ⚡

// @range 0.1 2.0 0.05
uniform float crack_speed = 0.8;
// @range 2.0 12.0 0.5
uniform float crack_density = 6.0;
// @range 0.0 1.0 0.01
uniform float crack_brightness = 0.9;
// @range 0.005 0.06 0.005
uniform float crack_width = 0.015;
// @range 0.0 0.5 0.01
uniform float depth = 0.35;
uniform vec4 crack_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
// @range 0.0 1.0 0.01
uniform float flicker = 0.3;
// @range 0.0 0.15 0.005
uniform float glow_spread = 0.06;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int octaves) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < octaves; i++) {
		val += amp * noise(p);
		p *= 2.1;
		amp *= 0.5;
	}
	return val;
}

// Generate a crack line value — returns intensity (0 = no crack, 1 = on crack)
float crack_line(vec2 uv, float seed, float t) {
	// Warp the UV with noise for organic crack paths
	vec2 warped = uv;
	warped.x += fbm(uv * 3.0 + vec2(seed, t * crack_speed), 4) * 0.3;
	warped.y += fbm(uv * 3.0 + vec2(t * crack_speed, seed + 50.0), 4) * 0.3;

	// Create crack pattern using noise ridges
	float n = fbm(warped * crack_density + vec2(seed * 7.13), 5);
	// Ridge: sharp peak where noise crosses 0.5
	float ridge = abs(n - 0.5);
	float crack = smoothstep(crack_width, crack_width * 0.1, ridge);
	return crack;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	// Distance from nearest edge
	float d_edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));

	// Cracks fade out toward center based on depth
	float edge_mask = smoothstep(depth, 0.0, d_edge);

	// Flicker
	float flick = 1.0 - flicker * (0.5 + 0.5 * sin(t * 17.0 + sin(t * 11.0) * 3.0));

	// Multiple crack layers
	float total_crack = 0.0;
	total_crack += crack_line(uv, 0.0, t) * 1.0;
	total_crack += crack_line(uv, 42.0, t * 0.7) * 0.6;
	total_crack += crack_line(uv, 99.0, t * 1.3) * 0.3;
	total_crack = clamp(total_crack, 0.0, 1.0);

	// Apply edge mask — cracks only near edges
	total_crack *= edge_mask;

	// Apply flicker
	total_crack *= flick;

	// Color
	vec3 col = vec3(0.0);

	// Crack core
	col += crack_color.rgb * total_crack * crack_brightness;

	// White-hot center of cracks
	col += vec3(1.0) * total_crack * total_crack * crack_brightness * 0.5;

	// Glow around cracks
	float glow = total_crack * exp(-d_edge * d_edge / (glow_spread * glow_spread + 0.0001));
	col += crack_color.rgb * glow * 0.4;

	// Subtle edge ambient
	col += crack_color.rgb * edge_mask * 0.02;

	COLOR = vec4(col, 1.0);
}
