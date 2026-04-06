shader_type canvas_item;
// @name Edge Plasma Pulse
// @description Pulsing plasma waves that ripple inward from the edges
// @emoji 💜

uniform vec4 color_a : source_color = vec4(0.8, 0.1, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.1, 0.8, 0.6, 1.0);
// @range 0.1 2.0 0.05
uniform float speed = 0.8;
// @range 2.0 15.0 0.5
uniform float ring_count = 6.0;
// @range 0.02 0.3 0.01
uniform float edge_width = 0.15;
// @range 0.0 1.0 0.01
uniform float ring_sharpness = 0.5;
// @range 0.0 1.0 0.01
uniform float color_cycle_speed = 0.3;

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;

	float d = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));

	// Concentric rings rippling inward from edges
	float rings = sin((d - t * 0.1) * ring_count * 3.14159 * 2.0);
	rings = mix(rings, sign(rings), ring_sharpness);  // Sharpen rings
	rings = rings * 0.5 + 0.5;

	// Fade toward center
	float edge_mask = smoothstep(edge_width * 3.0, 0.0, d);

	// Breathing pulse
	float pulse = 0.7 + 0.3 * sin(t * 2.0);

	// Color cycling
	float color_mix = sin(d * 10.0 + t * color_cycle_speed * 5.0) * 0.5 + 0.5;
	vec3 col = mix(color_a.rgb, color_b.rgb, color_mix);

	col *= rings * edge_mask * pulse;

	COLOR = vec4(col, 1.0);
}
