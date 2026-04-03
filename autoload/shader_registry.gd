extends Node
## ShaderRegistry — Autoload Singleton
## Discovers, catalogs, and provides shader effects for surfaces.
## Shaders live in res://shaders/effects/ and are auto-discovered at startup.
## Each shader's uniforms are parsed to auto-generate UI controls.

signal registry_loaded()

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

## Metadata for a single shader uniform (parameter).
class ShaderParam:
	var name: String
	var display_name: String  # Human-readable (underscores → spaces, title case)
	var type: String          # "float", "vec2", "vec3", "vec4", "color", "int", "bool"
	var default_value: Variant
	var min_value: float
	var max_value: float
	var step: float

	func _init(p_name: String, p_type: String, p_default: Variant = null,
			p_min: float = 0.0, p_max: float = 1.0, p_step: float = 0.01) -> void:
		name = p_name
		type = p_type
		default_value = p_default
		min_value = p_min
		max_value = p_max
		step = p_step
		# Generate display name from uniform name
		display_name = p_name.replace("_", " ").capitalize()


## Metadata for a registered shader effect.
class ShaderEffect:
	var id: String            # Unique identifier (filename without extension)
	var name: String          # Display name
	var description: String
	var emoji: String
	var shader_path: String   # res:// path to .gdshader file
	var shader: Shader        # Loaded Shader resource
	var params: Array[ShaderParam]

	func _init() -> void:
		params = []

	func get_default_params() -> Dictionary:
		var defaults := {}
		for p in params:
			defaults[p.name] = p.default_value
		return defaults


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var effects: Dictionary = {}  # id -> ShaderEffect
var _effects_dir: String = "res://shaders/effects/"
var _user_effects_dir: String = "user://shaders/effects/"

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_ensure_user_dir()
	_discover_effects()
	registry_loaded.emit()


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

## Scan the effects directory for .gdshader files and register them.
func _discover_effects() -> void:
	effects.clear()
	# Scan built-in effects
	_scan_directory(_effects_dir)
	# Scan user-added effects
	_scan_directory(_user_effects_dir)
	print("ShaderRegistry: Discovered %d effects" % effects.size())


func _ensure_user_dir() -> void:
	if not DirAccess.dir_exists_absolute(_user_effects_dir):
		DirAccess.make_dir_recursive_absolute(_user_effects_dir)


func _scan_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gdshader"):
			var shader_path := dir_path + file_name
			_register_shader(shader_path)
		file_name = dir.get_next()
	dir.list_dir_end()


## Load a shader file, parse its metadata comment block, and register it.
func _register_shader(shader_path: String) -> void:
	var shader: Shader = null
	var source: String = ""

	if shader_path.begins_with("res://"):
		# Built-in: use resource loader
		shader = load(shader_path)
		if shader == null:
			push_warning("ShaderRegistry: Failed to load shader: %s" % shader_path)
			return
		source = shader.code
	else:
		# User shader (user:// path): read source and create Shader at runtime
		var file := FileAccess.open(shader_path, FileAccess.READ)
		if file == null:
			push_warning("ShaderRegistry: Failed to open shader file: %s" % shader_path)
			return
		source = file.get_as_text()
		file.close()
		shader = Shader.new()
		shader.code = source

	var effect := ShaderEffect.new()
	effect.shader_path = shader_path
	effect.shader = shader
	effect.id = shader_path.get_file().get_basename()
	effect.name = _parse_meta(source, "name", effect.id.replace("_", " ").capitalize())
	effect.description = _parse_meta(source, "description", "")
	effect.emoji = _parse_meta(source, "emoji", "✨")

	# Parse user-facing uniforms (skip internal ones)
	effect.params = _parse_params(source)

	effects[effect.id] = effect
	print("ShaderRegistry: Registered '%s' (%d params)" % [effect.id, effect.params.size()])


# ---------------------------------------------------------------------------
# Metadata parsing from shader comments
# ---------------------------------------------------------------------------

## Parse a metadata value from a comment block at the top of the shader.
## Format: // @key value
func _parse_meta(source: String, key: String, fallback: String) -> String:
	var tag := "// @%s " % key
	for line in source.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with(tag):
			return trimmed.substr(tag.length()).strip_edges()
	return fallback


## Parse uniform declarations to extract user-controllable parameters.
## Uniforms prefixed with _ are considered internal and skipped.
## Supports hint comments: // @range min max step
func _parse_params(source: String) -> Array[ShaderParam]:
	var params: Array[ShaderParam] = []
	var lines := source.split("\n")

	for i in range(lines.size()):
		var line := lines[i].strip_edges()
		if not line.begins_with("uniform "):
			continue

		# Skip internal uniforms (prefixed with _)
		var tokens := line.split(" ")
		if tokens.size() < 3:
			continue

		var u_type := tokens[1]
		var u_name := tokens[2].rstrip(";").split("=")[0].split(":")[0].strip_edges()

		# Skip internal uniforms
		if u_name.begins_with("_"):
			continue

		# Map GLSL types to our type system
		var param_type := _glsl_type_to_param_type(u_type)
		if param_type == "":
			continue

		# Parse default value from the line
		var default_val: Variant = _parse_default_value(line, param_type)

		# Check for range hint in preceding comment: // @range min max step
		var p_min: float = 0.0
		var p_max: float = 1.0
		var p_step: float = 0.01
		if i > 0:
			var prev := lines[i - 1].strip_edges()
			if prev.begins_with("// @range"):
				var range_parts := prev.substr(9).strip_edges().split(" ")
				if range_parts.size() >= 2:
					p_min = float(range_parts[0])
					p_max = float(range_parts[1])
				if range_parts.size() >= 3:
					p_step = float(range_parts[2])

		# Check for source_color hint — treat as color type
		if ": source_color" in line:
			param_type = "color"

		var param := ShaderParam.new(u_name, param_type, default_val, p_min, p_max, p_step)
		params.append(param)

	return params


func _glsl_type_to_param_type(glsl_type: String) -> String:
	match glsl_type:
		"float": return "float"
		"int": return "int"
		"bool": return "bool"
		"vec2": return "vec2"
		"vec3": return "vec3"
		"vec4": return "vec4"
	return ""


func _parse_default_value(line: String, param_type: String) -> Variant:
	# Try to extract default from "= value" in the uniform declaration
	var eq_pos := line.find("=")
	if eq_pos < 0:
		match param_type:
			"float": return 0.0
			"int": return 0
			"bool": return false
			"color": return Color.WHITE
			"vec2": return Vector2.ZERO
			"vec3": return Vector3.ZERO
			"vec4": return Color.WHITE
		return null

	var val_str := line.substr(eq_pos + 1).split(";")[0].strip_edges()

	match param_type:
		"float":
			return float(val_str)
		"int":
			return int(val_str)
		"bool":
			return val_str == "true"
		"vec2":
			var nums := _extract_numbers(val_str)
			if nums.size() >= 2:
				return Vector2(nums[0], nums[1])
			return Vector2.ZERO
		"vec3":
			var nums := _extract_numbers(val_str)
			if nums.size() >= 3:
				return Vector3(nums[0], nums[1], nums[2])
			return Vector3.ZERO
		"vec4", "color":
			var nums := _extract_numbers(val_str)
			if nums.size() >= 4:
				return Color(nums[0], nums[1], nums[2], nums[3])
			elif nums.size() >= 3:
				return Color(nums[0], nums[1], nums[2], 1.0)
			return Color.WHITE

	return null


func _extract_numbers(s: String) -> Array[float]:
	var nums: Array[float] = []
	# Remove vec2(...), vec3(...), vec4(...) wrapper
	var open := s.find("(")
	var close := s.rfind(")")
	if open >= 0 and close > open:
		s = s.substr(open + 1, close - open - 1)
	for part in s.split(","):
		var trimmed := part.strip_edges()
		if trimmed != "":
			nums.append(float(trimmed))
	return nums


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Get a list of all effect IDs.
func get_effect_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in effects:
		ids.append(key)
	ids.sort()
	return ids


## Get a ShaderEffect by id, or null.
func get_effect(id: String) -> ShaderEffect:
	if effects.has(id):
		return effects[id]
	return null


## Create a ShaderMaterial configured for the given effect with default params.
func create_material(effect_id: String) -> ShaderMaterial:
	var effect := get_effect(effect_id)
	if effect == null:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = effect.shader
	# Set defaults
	for p in effect.params:
		if p.default_value != null:
			mat.set_shader_parameter(p.name, p.default_value)
	return mat


## Update a single parameter on an existing ShaderMaterial.
func set_param(mat: ShaderMaterial, param_name: String, value: Variant) -> void:
	if mat:
		mat.set_shader_parameter(param_name, value)


# ---------------------------------------------------------------------------
# User shader management
# ---------------------------------------------------------------------------

## Save a new shader effect from user-provided code.
## Returns the effect id on success, or "" on failure.
func add_user_shader(shader_name: String, description: String, emoji: String, shader_code: String) -> String:
	# Generate a safe filename from the name
	var safe_name := shader_name.to_lower().strip_edges()
	safe_name = safe_name.replace(" ", "_")
	# Remove non-alphanumeric chars (keep underscores)
	var cleaned := ""
	for c in safe_name:
		if c == "_" or (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			cleaned += c
	safe_name = cleaned
	if safe_name.is_empty():
		safe_name = "custom_%d" % (randi() % 9999)

	# Avoid id collisions
	var base_name := safe_name
	var counter := 1
	while effects.has(safe_name):
		safe_name = "%s_%d" % [base_name, counter]
		counter += 1

	# Prepend metadata comment block if not already present
	var code := shader_code.strip_edges()
	if not code.contains("// @name "):
		var header := "// @name %s\n" % shader_name
		header += "// @description %s\n" % description
		header += "// @emoji %s\n" % (emoji if emoji != "" else "✨")
		# Ensure shader_type is first non-comment line
		if code.begins_with("shader_type"):
			code = header + code
		else:
			# Insert after any existing shader_type line
			var lines := code.split("\n")
			var inserted := false
			var result_lines: PackedStringArray = PackedStringArray()
			for line in lines:
				result_lines.append(line)
				if not inserted and line.strip_edges().begins_with("shader_type"):
					result_lines.append(header.strip_edges())
					inserted = true
			if not inserted:
				code = header + code
			else:
				code = "\n".join(result_lines)

	# Validate: must contain shader_type
	if not code.contains("shader_type"):
		push_error("ShaderRegistry: Shader code must contain 'shader_type' declaration")
		return ""

	# Write to user effects directory
	_ensure_user_dir()
	var file_path := _user_effects_dir + safe_name + ".gdshader"
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("ShaderRegistry: Failed to write shader file: %s" % file_path)
		return ""
	file.store_string(code)
	file.close()

	# Register it live
	_register_shader(file_path)

	print("ShaderRegistry: Added user shader '%s' at %s" % [safe_name, file_path])
	return safe_name


## Delete a user-added shader effect. Returns true on success.
## Only shaders in user:// can be deleted; built-in shaders are protected.
func delete_user_shader(effect_id: String) -> bool:
	var effect := get_effect(effect_id)
	if effect == null:
		return false
	if not effect.shader_path.begins_with("user://"):
		push_warning("ShaderRegistry: Cannot delete built-in shader: %s" % effect_id)
		return false

	# Delete the file
	var err := DirAccess.remove_absolute(effect.shader_path)
	if err != OK:
		push_error("ShaderRegistry: Failed to delete shader file: %s" % effect.shader_path)
		return false

	effects.erase(effect_id)
	print("ShaderRegistry: Deleted user shader '%s'" % effect_id)
	return true


## Check if an effect is user-added (deletable) vs built-in.
func is_user_shader(effect_id: String) -> bool:
	var effect := get_effect(effect_id)
	if effect == null:
		return false
	return effect.shader_path.begins_with("user://")
