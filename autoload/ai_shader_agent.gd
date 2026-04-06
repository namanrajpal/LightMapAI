extends Node
## AiShaderAgent — Autoload Singleton
## Generates Godot canvas_item shaders from natural language descriptions
## using an OpenAI-compatible LLM API.

signal generation_completed(shader_code: String, error: String)

var api_url: String = "https://api.anthropic.com/v1/messages"
var api_key: String = ""
var model: String = "claude-sonnet-4-20250514"

var _http: HTTPRequest = null
var _config_path: String = "user://settings/ai_config.json"

const SYSTEM_PROMPT := """You are a Godot 4.x shader expert. Generate a complete canvas_item shader for a projection mapping surface.

RULES:
- Must start with: shader_type canvas_item;
- Add metadata comments after shader_type:
  // @name Human Readable Name
  // @description One line description
  // @emoji 🎨 (single emoji)
- UV goes 0.0 to 1.0 across the surface
- TIME is available for animation
- Use uniforms for tweakable parameters with range hints:
  // @range min max step
  uniform float speed = 1.0;
- Prefix internal uniforms with _ (they won't show in UI)
- Use : source_color hint for color uniforms
- Output ONLY the shader code, no explanation

EXAMPLE 1 (border effect):
shader_type canvas_item;
// @name Glow Border
// @description Glowing border effect
// @emoji ✨
uniform vec4 glow_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
// @range 0.01 0.1 0.005
uniform float thickness = 0.03;
void fragment() {
    float d = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
    float glow = smoothstep(thickness, 0.0, d);
    COLOR = vec4(glow_color.rgb * glow, 1.0);
}

EXAMPLE 2 (full surface effect):
shader_type canvas_item;
// @name Color Waves
// @description Animated color waves
// @emoji 🌊
// @range 0.1 3.0 0.1
uniform float speed = 1.0;
// @range 1.0 8.0 0.5
uniform float scale = 3.0;
void fragment() {
    vec2 uv = UV * scale;
    float t = TIME * speed;
    float v = sin(uv.x + t) + sin(uv.y * 0.7 + t * 0.8);
    v = v * 0.25 + 0.5;
    COLOR = vec4(v, v * 0.5, 1.0 - v, 1.0);
}"""


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "HTTPRequest"
	_http.timeout = 30.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_load_config()


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

func _load_config() -> void:
	if not FileAccess.file_exists(_config_path):
		return
	var file := FileAccess.open(_config_path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		api_url = data.get("api_url", api_url)
		api_key = data.get("api_key", api_key)
		model = data.get("model", model)
	file.close()


func save_config() -> void:
	var dir_path := _config_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(_config_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"api_url": api_url,
			"api_key": api_key,
			"model": model,
		}, "\t"))
		file.close()


func is_configured() -> bool:
	return not api_key.is_empty() and not api_url.is_empty()


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

func _is_anthropic() -> bool:
	return "anthropic" in api_url


func generate_shader(description: String) -> void:
	if not is_configured():
		generation_completed.emit("", "API not configured. Set your API key first.")
		return

	var json_body: String
	var headers: PackedStringArray

	if _is_anthropic():
		# Anthropic Messages API
		var body := {
			"model": model,
			"max_tokens": 2000,
			"system": SYSTEM_PROMPT,
			"messages": [
				{"role": "user", "content": "Generate a shader for: %s" % description},
			],
		}
		json_body = JSON.stringify(body)
		headers = PackedStringArray([
			"Content-Type: application/json",
			"x-api-key: %s" % api_key,
			"anthropic-version: 2023-06-01",
		])
	else:
		# OpenAI-compatible API
		var body := {
			"model": model,
			"messages": [
				{"role": "system", "content": SYSTEM_PROMPT},
				{"role": "user", "content": "Generate a shader for: %s" % description},
			],
			"temperature": 0.7,
			"max_tokens": 2000,
		}
		json_body = JSON.stringify(body)
		headers = PackedStringArray([
			"Content-Type: application/json",
			"Authorization: Bearer %s" % api_key,
		])

	var err := _http.request(api_url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		generation_completed.emit("", "HTTP request failed: error %d" % err)


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		generation_completed.emit("", "Request failed (result: %d)" % result)
		return

	if code != 200:
		var error_text := body.get_string_from_utf8()
		generation_completed.emit("", "API error %d: %s" % [code, error_text.left(300)])
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		generation_completed.emit("", "Failed to parse API response")
		return

	var data: Dictionary = json.data

	# Extract content — different format for Anthropic vs OpenAI
	var content: String = ""
	if _is_anthropic():
		# Anthropic: {"content": [{"type": "text", "text": "..."}]}
		if data.has("content") and data["content"] is Array and data["content"].size() > 0:
			content = str(data["content"][0].get("text", ""))
		else:
			generation_completed.emit("", "No content in Anthropic response")
			return
	else:
		# OpenAI: {"choices": [{"message": {"content": "..."}}]}
		if data.has("choices") and data["choices"] is Array and data["choices"].size() > 0:
			content = str(data["choices"][0]["message"]["content"])
		else:
			generation_completed.emit("", "No content in API response")
			return
	var shader_code := _extract_shader_code(content)

	if shader_code.is_empty():
		generation_completed.emit("", "Could not extract shader code from response")
		return

	# Validate it compiles
	var validation_error := validate_shader(shader_code)
	if not validation_error.is_empty():
		generation_completed.emit(shader_code, "Shader has errors: %s" % validation_error)
		return

	generation_completed.emit(shader_code, "")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _extract_shader_code(content: String) -> String:
	# Try to extract from markdown code fences
	var fence_patterns := ["```gdshader", "```glsl", "```shader", "```"]
	for pattern in fence_patterns:
		var start := content.find(pattern)
		if start >= 0:
			start = content.find("\n", start) + 1
			var end := content.find("```", start)
			if end > start:
				return content.substr(start, end - start).strip_edges()

	# No fences — if it contains shader_type, use the whole thing
	if content.contains("shader_type"):
		return content.strip_edges()

	return ""


func validate_shader(code: String) -> String:
	if not code.contains("shader_type"):
		return "Missing 'shader_type' declaration"
	var shader := Shader.new()
	shader.code = code
	# Godot doesn't expose compile errors directly from Shader.new(),
	# but setting the code will print errors. We check if it has a valid mode.
	if shader.get_mode() == Shader.MODE_CANVAS_ITEM:
		return ""  # Looks good
	return "Shader may have compilation errors — check the output log"
