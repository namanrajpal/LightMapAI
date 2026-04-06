shader_type canvas_item;
// @name Plasma Electric
// @description High-energy electric plasma with sharp lightning-like patterns
// @emoji ⚡

// @range 0.5 8.0 0.1
uniform float scale = 4.0;
// @range 0.5 5.0 0.1
uniform float speed = 2.0;
uniform vec4 color_core : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform vec4 color_glow : source_color = vec4(0.2, 0.5, 1.0, 1.0);
uniform vec4 color_bg : source_color = vec4(0.0, 0.02, 0.08, 1.0);
// @range 0.5 3.0 0.1
uniform float sharpness = 1.5;
// @range 1.0 6.0 0.5
uniform float branches = 3.0;
// @range 0.0 1.0 0.01
uniform float flicker = 0.3;

void fragment() {
	vec2 uv = UV * scale;
	float t = TIME * speed;

	// Multiple sharp sine wave interference
	float v = 0.0;
	for (float i = 1.0; i <= 6.0; i += 1.0) {
		if (i > branches) break;
		float freq = i * 2.3;
		float phase = t * (1.0 + i * 0.4) + i * 0.9;
		v += sin(uv.x * freq + phase + sin(uv.y * freq * 0.7 + t * i * 0.3) * 1.5) / i;
		v += cos(uv.y * freq * 0.8 + phase * 0.7 + cos(uv.x * freq * 0.5 + t * 0.5) * 1.2) / (i + 0.5);
	}

	// Sharpen the pattern to create lightning-like lines
	v = abs(v);
	v = pow(v, sharpness);
	v = 1.0 - v;
	v = clamp(v, 0.0, 1.0);

	// Flicker
	float flick = 1.0 - flicker * 0.5 * (sin(t * 15.0) * sin(t * 23.0 + 1.0));
	v *= flick;

	// Color: bright core fading to glow fading to background
	vec3 col = color_bg.rgb;
	col = mix(col, color_glow.rgb, smoothstep(0.0, 0.5, v));
	col = mix(col, color_core.rgb, smoothstep(0.5, 0.95, v));

	// Extra brightness at peaks
	col += color_core.rgb * pow(v, 4.0) * 0.5;

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
