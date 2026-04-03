extends Node
## SurfaceManager — Autoload Singleton
## Central data store for all projection surfaces.
## Manages CRUD, selection, serialization, and mode state.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal surface_added(id: String)
signal surface_removed(id: String)
signal surface_selected(id: String)
signal surface_updated(id: String)
signal mode_changed(is_output: bool)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var surfaces: Array[Dictionary] = []
var selected_surface_id: String = ""
var is_output_mode: bool = false

# Default colors to cycle through when creating new surfaces
const SURFACE_COLORS: Array[String] = [
	"#4488FF", "#FF8833", "#44DD66", "#DD44AA",
	"#FFDD33", "#33DDDD", "#AA66FF", "#FF4444",
]

var _next_color_index: int = 0
var _current_save_path: String = ""

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	pass

# ---------------------------------------------------------------------------
# Surface CRUD
# ---------------------------------------------------------------------------

## Creates a new surface with default values and returns its id.
func add_surface() -> String:
	var id := generate_id()
	var idx := surfaces.size()
	var color_hex: String = SURFACE_COLORS[_next_color_index % SURFACE_COLORS.size()]
	_next_color_index += 1

	# Default: centered 400×300 quad
	var cx: float = 960.0
	var cy: float = 540.0
	var hw: float = 200.0
	var hh: float = 150.0

	var surface := {
		"id": id,
		"label": "Surface %d" % (idx + 1),
		"color": color_hex,
		"z_index": idx,
		"visible": true,
		"locked": false,
		"grid_on": false,
		"corners": PackedVector2Array([
			Vector2(cx - hw, cy - hh),  # TL
			Vector2(cx + hw, cy - hh),  # TR
			Vector2(cx + hw, cy + hh),  # BR
			Vector2(cx - hw, cy + hh),  # BL
		]),
	}

	surfaces.append(surface)
	surface_added.emit(id)
	return id


## Removes a surface by id.
func remove_surface(id: String) -> void:
	for i in range(surfaces.size()):
		if surfaces[i]["id"] == id:
			surfaces.remove_at(i)
			if selected_surface_id == id:
				selected_surface_id = ""
				surface_selected.emit("")
			surface_removed.emit(id)
			return


## Selects a surface by id. Pass "" to deselect.
func select_surface(id: String) -> void:
	selected_surface_id = id
	surface_selected.emit(id)


## Returns the surface dictionary for the given id, or an empty dict.
func get_surface(id: String) -> Dictionary:
	for s in surfaces:
		if s["id"] == id:
			return s
	return {}


## Returns the currently selected surface dictionary, or empty dict.
func get_selected_surface() -> Dictionary:
	return get_surface(selected_surface_id)


## Updates the corner positions for a surface.
func update_corners(id: String, corners: PackedVector2Array) -> void:
	for s in surfaces:
		if s["id"] == id:
			s["corners"] = corners
			surface_updated.emit(id)
			return


## Updates an arbitrary property on a surface.
func update_surface_property(id: String, key: String, value: Variant) -> void:
	for s in surfaces:
		if s["id"] == id:
			s[key] = value
			surface_updated.emit(id)
			return


## Move surface forward in z-order.
func move_surface_forward(id: String) -> void:
	var s := get_surface(id)
	if s.is_empty():
		return
	var max_z: int = 0
	for surf in surfaces:
		if surf["z_index"] > max_z:
			max_z = surf["z_index"]
	if s["z_index"] < max_z:
		# Swap with the surface one z-level above
		var target_z: int = s["z_index"] + 1
		for surf in surfaces:
			if surf["z_index"] == target_z:
				surf["z_index"] = s["z_index"]
				surface_updated.emit(surf["id"])
				break
		s["z_index"] = target_z
		surface_updated.emit(id)


## Move surface backward in z-order.
func move_surface_backward(id: String) -> void:
	var s := get_surface(id)
	if s.is_empty():
		return
	if s["z_index"] > 0:
		var target_z: int = s["z_index"] - 1
		for surf in surfaces:
			if surf["z_index"] == target_z:
				surf["z_index"] = s["z_index"]
				surface_updated.emit(surf["id"])
				break
		s["z_index"] = target_z
		surface_updated.emit(id)


# ---------------------------------------------------------------------------
# Mode
# ---------------------------------------------------------------------------

## Toggle between Setup and Output mode.
func set_output_mode(enabled: bool) -> void:
	is_output_mode = enabled
	mode_changed.emit(enabled)


func toggle_output_mode() -> void:
	set_output_mode(!is_output_mode)


# ---------------------------------------------------------------------------
# Serialization — Save / Load
# ---------------------------------------------------------------------------

func save_config(path: String) -> Error:
	var data := {
		"version": 1,
		"app": {
			"canvas_size": [1920, 1080],
		},
		"surfaces": [],
	}

	for s in surfaces:
		var corners: PackedVector2Array = s["corners"]
		data["surfaces"].append({
			"id": s["id"],
			"label": s["label"],
			"color": s["color"],
			"z_index": s["z_index"],
			"visible": s["visible"],
			"locked": s["locked"],
			"grid_on": s["grid_on"],
			"corners": {
				"tl": [corners[0].x, corners[0].y],
				"tr": [corners[1].x, corners[1].y],
				"br": [corners[2].x, corners[2].y],
				"bl": [corners[3].x, corners[3].y],
			},
		})

	var json_string := JSON.stringify(data, "\t")

	# Ensure directory exists
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SurfaceManager: Failed to open file for writing: %s" % path)
		return FileAccess.get_open_error()

	file.store_string(json_string)
	file.close()
	_current_save_path = path
	print("SurfaceManager: Config saved to %s" % path)
	return OK


func load_config(path: String) -> Error:
	if not FileAccess.file_exists(path):
		push_error("SurfaceManager: File not found: %s" % path)
		return ERR_FILE_NOT_FOUND

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_string)
	if err != OK:
		push_error("SurfaceManager: JSON parse error: %s" % json.get_error_message())
		return err

	var data: Dictionary = json.data
	if not data.has("surfaces"):
		push_error("SurfaceManager: Invalid config — missing 'surfaces' key")
		return ERR_INVALID_DATA

	# Clear current state
	var old_ids: Array[String] = []
	for s in surfaces:
		old_ids.append(s["id"])
	for oid in old_ids:
		remove_surface(oid)

	# Rebuild
	_next_color_index = 0
	for sd in data["surfaces"]:
		var corners_dict: Dictionary = sd["corners"]
		var corners := PackedVector2Array([
			Vector2(corners_dict["tl"][0], corners_dict["tl"][1]),
			Vector2(corners_dict["tr"][0], corners_dict["tr"][1]),
			Vector2(corners_dict["br"][0], corners_dict["br"][1]),
			Vector2(corners_dict["bl"][0], corners_dict["bl"][1]),
		])

		var surface := {
			"id": sd.get("id", generate_id()),
			"label": sd.get("label", "Surface"),
			"color": sd.get("color", "#4488FF"),
			"z_index": int(sd.get("z_index", 0)),
			"visible": bool(sd.get("visible", true)),
			"locked": bool(sd.get("locked", false)),
			"grid_on": bool(sd.get("grid_on", false)),
			"corners": corners,
		}
		surfaces.append(surface)
		surface_added.emit(surface["id"])

	_current_save_path = path
	print("SurfaceManager: Config loaded from %s (%d surfaces)" % [path, surfaces.size()])
	return OK


## Convenience: quick-save to last path or default.
func quick_save() -> Error:
	if _current_save_path.is_empty():
		_current_save_path = "user://configs/config.json"
	return save_config(_current_save_path)


## Convenience: quick-load from last path or default.
func quick_load() -> Error:
	if _current_save_path.is_empty():
		_current_save_path = "user://configs/config.json"
	return load_config(_current_save_path)


## Try loading the default config shipped with the project.
func load_default_config() -> Error:
	return load_config("res://data/default_config.json")


# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

func generate_id() -> String:
	# Simple unique id: timestamp + random hex
	var t := int(Time.get_unix_time_from_system() * 1000)
	var r := randi() % 0xFFFF
	return "%x%04x" % [t, r]


## Get the current save path (for display in status bar, etc.)
func get_current_save_path() -> String:
	return _current_save_path
