shader_type canvas_item;
// @name Plasma Fire
// @description Fiery plasma with hot color palette — reds, oranges, yellows
// @emoji 🔥

// @range 0.5 8.0 0.1
uniform float scale = 4.0;
// @range 0.1 3.0 0.05
uniform float speed = 1.2;
// @range 1.0 5.0 0.5
uniform float turbulence = 3.0;
// @range 0.0 1.0 0.01
uniform float intensity = 0.8;
uniform vec4 color_hot : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform vec4 color_mid : source_color = vec4(1.0, 0.3, 0.0, 1.0);
uniform vec4 color_cool : source_color = vec4(0.2, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = UV * scale;
	float t = TIME * speed;

	// Rising flame distortion
	float flame = 0.0;
	flame += sin(uv.x * 2.0 + t * 1.3) * 0.5;
	flame += sin(uv.x * 3.5 - t * 0.7 + uv.y * 1.5) * 0.3;
	flame += sin(uv.y * 2.0 - t * 2.0 + sin(uv.x * 1.5 + t)) * 0.4;

	if (turbulence > 1.5) {
		flame += sin(uv.x * 5.0 + uv.y * 3.0 - t * 1.8) * 0.2;
	}
	if (turbulence > 2.5) {
		flame += sin(length(uv - vec2(scale * 0.5)) * 4.0 - t * 2.5) * 0.25;
	}

	// Vertical gradient — hotter at bottom
	float heat = 1.0 - UV.y;
	flame = flame * 0.5 + 0.5;
	flame *= heat;
	flame = clamp(flame * intensity * 1.5, 0.0, 1.0);

	// Three-color gradient
	vec3 col;
	if (flame > 0.6) {
		col = mix(color_mid.rgb, color_hot.rgb, (flame - 0.6) / 0.4);
	} else if (flame > 0.2) {
		col = mix(color_cool.rgb, color_mid.rgb, (flame - 0.2) / 0.4);
	} else {
		col = color_cool.rgb * (flame / 0.2);
	}

	COLOR = vec4(col, 1.0);
}
