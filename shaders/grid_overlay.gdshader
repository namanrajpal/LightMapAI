shader_type canvas_item;

// Same inverse homography as the warp shader
uniform vec3 h_row0 = vec3(1.0, 0.0, 0.0);
uniform vec3 h_row1 = vec3(0.0, 1.0, 0.0);
uniform vec3 h_row2 = vec3(0.0, 0.0, 1.0);

// Grid appearance
uniform float grid_spacing = 0.1;       // 10 divisions per axis
uniform float line_width = 0.004;
uniform vec4 grid_color : source_color = vec4(1.0, 1.0, 1.0, 0.4);

// Border line
uniform float border_line_width = 0.006;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.7);

void fragment() {
	vec2 uv_in = UV;

	// Apply inverse homography
	vec3 p = vec3(uv_in, 1.0);
	vec3 result;
	result.x = dot(h_row0, p);
	result.y = dot(h_row1, p);
	result.z = dot(h_row2, p);

	vec2 uv = result.xy / result.z;

	// Discard outside quad
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		discard;
	}

	// Border lines
	float bw = border_line_width;
	bool is_border = uv.x < bw || uv.x > 1.0 - bw || uv.y < bw || uv.y > 1.0 - bw;

	// Grid lines
	float gx = abs(fract(uv.x / grid_spacing + 0.5) - 0.5);
	float gy = abs(fract(uv.y / grid_spacing + 0.5) - 0.5);
	float line = min(gx, gy);

	if (is_border) {
		COLOR = border_color;
	} else if (line < line_width) {
		COLOR = grid_color;
	} else {
		COLOR = vec4(0.0);
	}
}
