shader_type canvas_item;
// @name Edge Plasma Fire
// @description Fiery plasma burning along the edges with rising heat
// @emoji 🔥

uniform vec4 color_hot : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform vec4 color_mid : source_color = vec4(1.0, 0.3, 0.0, 1.0);
uniform vec4 color_cool : source_color = vec4(0.3, 0.0, 0.0, 1.0);
// @range 0.5 6.0 0.1
uniform float scale = 4.0;
// @range 0.1 3.0 0.05
uniform float speed = 1.5;
// @range 0.02 0.35 0.01
uniform float edge_width = 0.12;
// @range 0.5 4.0 0.1
uniform float flame_height = 1.5;
// @range 0.0 1.0 0.01
uniform float turbulence = 0.7;

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;

	// Distance from each edge
	float d_left = uv.x;
	float d_right = 1.0 - uv.x;
	float d_top = uv.y;
	float d_bottom = 1.0 - uv.y;
	float d = min(min(d_left, d_right), min(d_top, d_bottom));

	// Edge mask
	float edge_mask = smoothstep(edge_width, 0.0, d);

	// Flame turbulence — rises away from each edge
	vec2 puv = uv * scale;
	float flame = 0.0;
	flame += sin(puv.x * 3.0 + t * 2.0) * 0.4;
	flame += sin(puv.y * 2.5 - t * 1.7 + sin(puv.x * 1.5 + t)) * 0.3;
	flame += sin((puv.x - puv.y) * 2.0 + t * 1.3) * 0.3 * turbulence;
	flame += sin(length(puv) * 2.5 - t * 2.0) * 0.2 * turbulence;

	// Flame extends inward from edges
	float flame_reach = edge_width * flame_height;
	float flame_mask = smoothstep(flame_reach, 0.0, d);
	float heat = flame_mask * (0.5 + flame * 0.5);
	heat = clamp(heat, 0.0, 1.0);

	// Three-color fire gradient
	vec3 col;
	if (heat > 0.65) {
		col = mix(color_mid.rgb, color_hot.rgb, (heat - 0.65) / 0.35);
	} else if (heat > 0.25) {
		col = mix(color_cool.rgb, color_mid.rgb, (heat - 0.25) / 0.4);
	} else {
		col = color_cool.rgb * (heat / 0.25);
	}

	COLOR = vec4(col, 1.0);
}
