shader_type canvas_item;

// Inverse homography matrix passed as 3 vec3 uniforms
// (Godot canvas_item shaders don't support mat3 directly)
// H_inv maps screen-space (x, y) -> UV-space (u, v)
uniform vec3 h_row0 = vec3(1.0, 0.0, 0.0);
uniform vec3 h_row1 = vec3(0.0, 1.0, 0.0);
uniform vec3 h_row2 = vec3(0.0, 0.0, 1.0);

// Surface appearance
uniform vec4 surface_color : source_color = vec4(0.267, 0.533, 1.0, 1.0);
uniform sampler2D surface_texture : hint_default_white;
uniform bool use_texture = false;

// Quad bounds in screen space (used to normalize fragment position)
uniform vec2 quad_min = vec2(0.0, 0.0);
uniform vec2 quad_size = vec2(1.0, 1.0);

// Selection highlight
uniform bool is_selected = false;
uniform vec4 selection_border_color : source_color = vec4(1.0, 1.0, 0.0, 0.8);
uniform float border_width = 0.008;

void fragment() {
	// Fragment UV from Polygon2D — we remap through the inverse homography
	// The Polygon2D covers the bounding rect of the quad; UV is [0,1] across that rect.
	vec2 uv_in = UV;

	// Apply inverse homography to get the original UV
	vec3 p = vec3(uv_in, 1.0);
	vec3 result;
	result.x = dot(h_row0, p);
	result.y = dot(h_row1, p);
	result.z = dot(h_row2, p);

	// Perspective divide
	vec2 uv = result.xy / result.z;

	// Discard fragments outside the unit square
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		discard;
	}

	// Sample color or texture
	vec4 col;
	if (use_texture) {
		col = texture(surface_texture, uv);
	} else {
		col = surface_color;
	}

	// Optional selection border highlight
	if (is_selected) {
		float bw = border_width;
		if (uv.x < bw || uv.x > 1.0 - bw || uv.y < bw || uv.y > 1.0 - bw) {
			col = mix(col, selection_border_color, 0.7);
		}
	}

	COLOR = col;
}
