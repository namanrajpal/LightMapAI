shader_type canvas_item;
// @name Edge Plasma Electric
// @description Electric arcs crackling along the edges with sharp lightning
// @emoji ⚡

uniform vec4 color_arc : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform vec4 color_glow : source_color = vec4(0.1, 0.3, 0.8, 1.0);
// @range 0.5 8.0 0.1
uniform float scale = 5.0;
// @range 0.5 5.0 0.1
uniform float speed = 2.5;
// @range 0.02 0.3 0.01
uniform float edge_width = 0.1;
// @range 0.5 3.0 0.1
uniform float sharpness = 1.8;
// @range 0.0 1.0 0.01
uniform float flicker = 0.4;
// @range 1.0 5.0 0.5
uniform float arc_count = 3.0;

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;

	float d = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));

	// Edge proximity — arcs only near edges
	float edge_mask = smoothstep(edge_width * 2.5, 0.0, d);

	// Lightning interference pattern
	vec2 puv = uv * scale;
	float arc = 0.0;
	for (float i = 1.0; i <= 5.0; i += 1.0) {
		if (i > arc_count) break;
		float freq = i * 2.5;
		float phase = t * (1.5 + i * 0.5) + i * 1.1;
		arc += sin(puv.x * freq + phase + sin(puv.y * freq * 0.6 + t * i * 0.4) * 2.0) / i;
		arc += cos(puv.y * freq * 0.9 + phase * 0.6 + cos(puv.x * freq * 0.4) * 1.5) / (i + 0.5);
	}

	// Sharpen into lightning bolts
	arc = abs(arc);
	arc = pow(arc, sharpness);
	arc = 1.0 - arc;
	arc = clamp(arc, 0.0, 1.0);
	arc *= edge_mask;

	// Flicker
	float flick = 1.0 - flicker * 0.5 * (sin(t * 17.0) * sin(t * 29.0 + 0.5));
	arc *= flick;

	// Color
	vec3 col = mix(vec3(0.0), color_glow.rgb, smoothstep(0.0, 0.4, arc));
	col = mix(col, color_arc.rgb, smoothstep(0.4, 0.9, arc));
	col += color_arc.rgb * pow(arc, 5.0) * 0.8;  // Bright core

	COLOR = vec4(col, 1.0);
}
