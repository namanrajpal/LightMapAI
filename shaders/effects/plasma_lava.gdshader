shader_type canvas_item;
// @name Plasma Lava
// @description Slow-moving lava lamp blobs with smooth organic motion
// @emoji 🫧

// @range 0.5 6.0 0.1
uniform float scale = 2.0;
// @range 0.05 1.5 0.05
uniform float speed = 0.3;
uniform vec4 color_blob : source_color = vec4(1.0, 0.2, 0.5, 1.0);
uniform vec4 color_bg : source_color = vec4(0.05, 0.0, 0.15, 1.0);
// @range 0.1 1.0 0.05
uniform float blob_size = 0.5;
// @range 2.0 8.0 1.0
uniform float blob_count = 4.0;
// @range 0.0 1.0 0.01
uniform float glow = 0.4;

float blob(vec2 uv, vec2 center, float radius) {
	float d = length(uv - center);
	return radius / (d * d + 0.01);
}

void fragment() {
	vec2 uv = (UV - 0.5) * scale;
	float t = TIME * speed;

	float field = 0.0;

	// Generate metaball-like blobs
	for (float i = 0.0; i < 8.0; i += 1.0) {
		if (i >= blob_count) break;
		float angle = i * 2.399 + t * (0.5 + i * 0.1);  // Golden angle spacing
		float radius_offset = 0.3 + 0.2 * sin(t * 0.7 + i * 1.3);
		vec2 center = vec2(
			sin(angle + sin(t * 0.3 + i)) * radius_offset,
			cos(angle * 0.7 + cos(t * 0.4 + i * 0.8)) * radius_offset
		);
		field += blob(uv, center, blob_size * 0.15);
	}

	// Threshold for blob boundaries
	float threshold = 1.0;
	float edge = smoothstep(threshold - 0.3, threshold + 0.1, field);

	// Glow around blobs
	float glow_mask = smoothstep(threshold * 0.3, threshold, field) * glow;

	// Color
	vec3 col = mix(color_bg.rgb, color_blob.rgb, edge);
	col += color_blob.rgb * glow_mask * 0.5;

	// Subtle internal variation
	float internal = sin(field * 8.0 + t) * 0.1 * edge;
	col += vec3(internal);

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
