shader_type canvas_item;
// @name Breathing Frame
// @description Soft pulsing border that gently breathes in and out
// @emoji 🫧

uniform vec4 frame_color : source_color = vec4(0.9, 0.4, 0.1, 1.0);
// @range 0.01 0.15 0.005
uniform float min_thickness = 0.03;
// @range 0.02 0.25 0.005
uniform float max_thickness = 0.1;
// @range 0.2 3.0 0.1
uniform float breath_speed = 0.8;
// @range 0.0 1.0 0.01
uniform float softness = 0.5;
// @range 0.0 1.0 0.01
uniform float brightness = 1.0;
// @range 0.0 0.5 0.01
uniform float inner_glow = 0.1;
// @range 0.0 1.0 0.01
uniform float corner_rounding = 0.0;

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	// Breathing cycle — smooth sine
	float breath = 0.5 + 0.5 * sin(t * breath_speed * 3.14159);
	float thickness = mix(min_thickness, max_thickness, breath);

	// Distance from edge (with optional rounding)
	float d_edge;
	if (corner_rounding > 0.0) {
		float r = corner_rounding * 0.5;
		vec2 p = abs(uv - 0.5) - (0.5 - r);
		d_edge = -(length(max(p, vec2(0.0))) - r);
	} else {
		d_edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	}

	// Frame mask
	float soft_edge = thickness * softness;
	float frame = smoothstep(thickness + soft_edge, thickness - soft_edge, d_edge);
	frame *= smoothstep(-0.01, soft_edge * 0.5, d_edge);  // Fade at outer edge

	// Inner glow — fades deeper into the surface
	float inner = exp(-d_edge * d_edge / (inner_glow * inner_glow + 0.0001)) * inner_glow;

	// Brightness modulation with breath
	float breath_bright = 0.7 + 0.3 * breath;

	vec3 col = vec3(0.0);
	col += frame_color.rgb * frame * brightness * breath_bright;
	col += frame_color.rgb * inner * 0.5 * breath_bright;

	// Subtle white highlight at the very edge
	float edge_highlight = smoothstep(thickness * 0.3, 0.0, abs(d_edge - thickness * 0.5));
	col += vec3(1.0) * edge_highlight * 0.2 * breath_bright;

	COLOR = vec4(col, 1.0);
}
