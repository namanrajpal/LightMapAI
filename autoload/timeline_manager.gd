extends Node
## TimelineManager — Autoload Singleton
## Hosts an AnimationPlayer and one SurfaceProxy child per surface.
## Manages animation scenes, keyframe editing, playback, and serialization.
## Phase 1: core structure and proxy lifecycle.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal playback_state_changed(is_playing: bool)
signal playhead_moved(time: float)
signal animation_scene_changed(scene_name: String)
signal animation_list_changed()
signal track_changed(surface_id: String, property: String)

# ---------------------------------------------------------------------------
# Internal references
# ---------------------------------------------------------------------------
var _animation_player: AnimationPlayer
var _animation_library: AnimationLibrary

# ---------------------------------------------------------------------------
# Playback state
# ---------------------------------------------------------------------------
var _current_speed: float = 1.0
var _is_paused: bool = false

# ---------------------------------------------------------------------------
# Animation scene state
# ---------------------------------------------------------------------------
# Maps scene name -> { "duration": float, "loop_mode": String, "armed_tracks": Dictionary }
# armed_tracks maps surface_id -> Array[String] of armed property names
var _scenes: Dictionary = {}
var _active_scene_name: String = ""

# ---------------------------------------------------------------------------
# Easing data
# ---------------------------------------------------------------------------
# Parallel dictionary storing easing strings for keyframes.
# Key format: "{scene_name}/{track_path}/{time}" -> easing string
# This is needed because Godot's transition float doesn't cleanly
# bidirectionally map to our 5 named easing types.
var _keyframe_easing: Dictionary = {}

# Valid easing types
const VALID_EASINGS: Array[String] = ["linear", "ease_in", "ease_out", "ease_in_out", "cubic"]

# Easing string -> Godot transition float mapping
const EASING_TO_TRANSITION: Dictionary = {
	"linear": 1.0,
	"ease_in": 0.4,
	"ease_out": 2.5,
	"ease_in_out": -2.0,
	"cubic": -0.4,
}

# Approximate time tolerance for finding keys
const KEY_TIME_EPSILON: float = 0.001

# All animatable properties (used for track visibility checks)
const ANIMATABLE_PROPERTIES: Array[String] = [
	"opacity", "color", "visible_prop", "z_index_prop",
	"corner_tl", "corner_tr", "corner_br", "corner_bl", "fit_mode",
]

# Default armed properties for new surfaces
const DEFAULT_ARMED_PROPERTIES: Array[String] = ["opacity", "color", "visible_prop", "z_index_prop"]

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Create the AnimationPlayer child
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)

	# Set root_node to TimelineManager itself so track paths like
	# "SurfaceProxy_{id}:opacity" resolve correctly.
	_animation_player.root_node = _animation_player.get_path_to(self)

	# Create and add the default AnimationLibrary
	_animation_library = AnimationLibrary.new()
	_animation_player.add_animation_library("", _animation_library)

	# Connect AnimationPlayer animation_finished signal for one-shot stop
	_animation_player.animation_finished.connect(_on_animation_finished)

	# Connect to SurfaceManager signals for proxy lifecycle
	SurfaceManager.surface_added.connect(_on_surface_added)
	SurfaceManager.surface_removed.connect(_on_surface_removed)

	# Create proxies for any surfaces that already exist
	for s in SurfaceManager.surfaces:
		_on_surface_added(s["id"])

# ---------------------------------------------------------------------------
# Proxy lifecycle
# ---------------------------------------------------------------------------

func _on_surface_added(id: String) -> void:
	# Instantiate a SurfaceProxy node
	var proxy := Node.new()
	proxy.set_script(load("res://scripts/surface_proxy.gd"))
	proxy.surface_id = id
	proxy.name = "SurfaceProxy_%s" % id
	add_child(proxy)
	proxy.sync_from_surface()

	# Add default armed tracks for this surface in all existing scenes
	for scene_name in _scenes:
		var armed: Dictionary = _scenes[scene_name]["armed_tracks"]
		if not armed.has(id):
			armed[id] = DEFAULT_ARMED_PROPERTIES.duplicate()


func _on_surface_removed(id: String) -> void:
	var proxy := get_proxy(id)
	if proxy:
		proxy.queue_free()

	# Clean up armed_tracks entries for this surface in all scenes
	for scene_name in _scenes:
		var armed: Dictionary = _scenes[scene_name]["armed_tracks"]
		armed.erase(id)

# ---------------------------------------------------------------------------
# Proxy access
# ---------------------------------------------------------------------------

func get_proxy(surface_id: String) -> Node:
	var proxy_name := "SurfaceProxy_%s" % surface_id
	for child in get_children():
		if child.name == proxy_name:
			return child
	return null

# ---------------------------------------------------------------------------
# Animation scene management
# ---------------------------------------------------------------------------

func create_scene(scene_name: String, duration: float) -> void:
	if _scenes.has(scene_name):
		push_warning("TimelineManager: scene '%s' already exists." % scene_name)
		return

	# Create a new Animation resource
	var anim := Animation.new()
	anim.length = duration
	_animation_library.add_animation(scene_name, anim)

	# Build default armed_tracks for all existing surfaces
	var armed_tracks: Dictionary = {}
	for child in get_children():
		if child.name.begins_with("SurfaceProxy_"):
			var sid: String = child.surface_id
			armed_tracks[sid] = DEFAULT_ARMED_PROPERTIES.duplicate()

	# Store metadata
	_scenes[scene_name] = {
		"duration": duration,
		"loop_mode": "none",
		"armed_tracks": armed_tracks,
	}

	animation_list_changed.emit()


func delete_scene(scene_name: String) -> void:
	if not _scenes.has(scene_name):
		push_warning("TimelineManager: cannot delete non-existent scene '%s'." % scene_name)
		return

	_animation_library.remove_animation(scene_name)
	_scenes.erase(scene_name)

	if _active_scene_name == scene_name:
		_active_scene_name = ""

	animation_list_changed.emit()


func rename_scene(old_name: String, new_name: String) -> void:
	if not _scenes.has(old_name):
		push_warning("TimelineManager: cannot rename non-existent scene '%s'." % old_name)
		return
	if _scenes.has(new_name):
		push_warning("TimelineManager: cannot rename to '%s' — name already exists." % new_name)
		return

	# Move the Animation resource in the library
	var anim: Animation = _animation_library.get_animation(old_name)
	_animation_library.remove_animation(old_name)
	_animation_library.add_animation(new_name, anim)

	# Move metadata
	_scenes[new_name] = _scenes[old_name]
	_scenes.erase(old_name)

	# Update active scene reference
	if _active_scene_name == old_name:
		_active_scene_name = new_name

	animation_list_changed.emit()


func set_active_scene(scene_name: String) -> void:
	if not _scenes.has(scene_name):
		push_warning("TimelineManager: cannot activate non-existent scene '%s'." % scene_name)
		return

	_active_scene_name = scene_name
	_animation_player.assigned_animation = scene_name

	animation_scene_changed.emit(scene_name)


func get_active_scene_name() -> String:
	return _active_scene_name


func get_scene_names() -> Array[String]:
	var names: Array[String] = []
	for key in _scenes.keys():
		names.append(key)
	return names


func set_scene_duration(scene_name: String, duration: float) -> void:
	if not _scenes.has(scene_name):
		push_warning("TimelineManager: cannot set duration on non-existent scene '%s'." % scene_name)
		return

	var anim: Animation = _animation_library.get_animation(scene_name)
	anim.length = duration
	_scenes[scene_name]["duration"] = duration


func set_scene_loop_mode(scene_name: String, loop: bool) -> void:
	if not _scenes.has(scene_name):
		push_warning("TimelineManager: cannot set loop mode on non-existent scene '%s'." % scene_name)
		return

	var anim: Animation = _animation_library.get_animation(scene_name)
	if loop:
		anim.loop_mode = Animation.LOOP_LINEAR
		_scenes[scene_name]["loop_mode"] = "loop"
	else:
		anim.loop_mode = Animation.LOOP_NONE
		_scenes[scene_name]["loop_mode"] = "none"


func get_scene_loop_mode(scene_name: String) -> bool:
	if not _scenes.has(scene_name):
		push_warning("TimelineManager: cannot get loop mode for non-existent scene '%s'." % scene_name)
		return false

	return _scenes[scene_name]["loop_mode"] == "loop"


# ---------------------------------------------------------------------------
# Keyframe editing
# ---------------------------------------------------------------------------

## Build the easing dictionary key for a given scene, track path, and time.
func _easing_key(scene_name: String, track_path: String, time: float) -> String:
	return "%s/%s/%.4f" % [scene_name, track_path, snapped(time, 0.0001)]


## Build the track path for a surface property.
func _track_path(surface_id: String, property: String) -> String:
	return "SurfaceProxy_%s:%s" % [surface_id, property]


## Get the transition float for an easing string. Defaults to linear (1.0).
func _easing_to_transition(easing: String) -> float:
	if EASING_TO_TRANSITION.has(easing):
		return EASING_TO_TRANSITION[easing]
	return EASING_TO_TRANSITION["linear"]


## Find the track index for a given path in an Animation resource.
## Returns -1 if not found.
func _find_track(anim: Animation, path: String) -> int:
	var track_count := anim.get_track_count()
	for i in range(track_count):
		if str(anim.track_get_path(i)) == path:
			return i
	return -1


## Find the key index at a given time on a track (within epsilon tolerance).
## Returns -1 if not found.
func _find_key_at_time(anim: Animation, track_idx: int, time: float) -> int:
	var key_count := anim.track_get_key_count(track_idx)
	for i in range(key_count):
		if absf(anim.track_get_key_time(track_idx, i) - time) < KEY_TIME_EPSILON:
			return i
	return -1


## Find or create a value track for the given path in the active animation.
## Returns the track index.
func _find_or_create_track(anim: Animation, path: String) -> int:
	var idx := _find_track(anim, path)
	if idx >= 0:
		return idx
	# Create a new value track
	idx = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(idx, NodePath(path))
	return idx


## Get the active Animation resource, or null if no active scene.
func _get_active_animation() -> Animation:
	if _active_scene_name.is_empty() or not _scenes.has(_active_scene_name):
		return null
	return _animation_library.get_animation(_active_scene_name)


func add_keyframe(surface_id: String, property: String, time: float, value: Variant, easing: String = "linear") -> void:
	var anim := _get_active_animation()
	if anim == null:
		push_warning("TimelineManager: no active scene for add_keyframe.")
		return

	# Validate easing, fall back to linear
	if easing not in VALID_EASINGS:
		push_warning("TimelineManager: unknown easing '%s', falling back to linear." % easing)
		easing = "linear"

	# Clamp time to [0.0, duration]
	var duration: float = anim.length
	time = clampf(time, 0.0, duration)

	var path := _track_path(surface_id, property)
	var track_idx := _find_or_create_track(anim, path)

	# Remove existing key at this time if present (to avoid duplicates)
	var existing_key := _find_key_at_time(anim, track_idx, time)
	if existing_key >= 0:
		# Clean up old easing entry
		var old_easing_key := _easing_key(_active_scene_name, path, anim.track_get_key_time(track_idx, existing_key))
		_keyframe_easing.erase(old_easing_key)
		anim.track_remove_key(track_idx, existing_key)

	# Insert the key with transition value
	var transition := _easing_to_transition(easing)
	anim.track_insert_key(track_idx, time, value, transition)

	# Store easing string in parallel dictionary
	_keyframe_easing[_easing_key(_active_scene_name, path, time)] = easing

	track_changed.emit(surface_id, property)


func remove_keyframe(surface_id: String, property: String, time: float) -> void:
	var anim := _get_active_animation()
	if anim == null:
		push_warning("TimelineManager: no active scene for remove_keyframe.")
		return

	var path := _track_path(surface_id, property)
	var track_idx := _find_track(anim, path)
	if track_idx < 0:
		push_warning("TimelineManager: track not found for %s:%s." % [surface_id, property])
		return

	var key_idx := _find_key_at_time(anim, track_idx, time)
	if key_idx < 0:
		push_warning("TimelineManager: no keyframe at time %.4f on %s." % [time, path])
		return

	# Clean up easing entry
	var actual_time := anim.track_get_key_time(track_idx, key_idx)
	_keyframe_easing.erase(_easing_key(_active_scene_name, path, actual_time))

	anim.track_remove_key(track_idx, key_idx)
	track_changed.emit(surface_id, property)


func move_keyframe(surface_id: String, property: String, old_time: float, new_time: float) -> void:
	var anim := _get_active_animation()
	if anim == null:
		push_warning("TimelineManager: no active scene for move_keyframe.")
		return

	var path := _track_path(surface_id, property)
	var track_idx := _find_track(anim, path)
	if track_idx < 0:
		push_warning("TimelineManager: track not found for %s:%s." % [surface_id, property])
		return

	var key_idx := _find_key_at_time(anim, track_idx, old_time)
	if key_idx < 0:
		push_warning("TimelineManager: no keyframe at time %.4f on %s." % [old_time, path])
		return

	# Preserve value and easing
	var value: Variant = anim.track_get_key_value(track_idx, key_idx)
	var actual_old_time := anim.track_get_key_time(track_idx, key_idx)
	var old_easing_key := _easing_key(_active_scene_name, path, actual_old_time)
	var easing: String = _keyframe_easing.get(old_easing_key, "linear")

	# Remove old key and easing entry
	_keyframe_easing.erase(old_easing_key)
	anim.track_remove_key(track_idx, key_idx)

	# Clamp new time to [0.0, duration]
	new_time = clampf(new_time, 0.0, anim.length)

	# Insert at new time with preserved value and easing
	var transition := _easing_to_transition(easing)
	anim.track_insert_key(track_idx, new_time, value, transition)

	# Store easing at new time
	_keyframe_easing[_easing_key(_active_scene_name, path, new_time)] = easing

	track_changed.emit(surface_id, property)


func update_keyframe_value(surface_id: String, property: String, time: float, value: Variant) -> void:
	var anim := _get_active_animation()
	if anim == null:
		push_warning("TimelineManager: no active scene for update_keyframe_value.")
		return

	var path := _track_path(surface_id, property)
	var track_idx := _find_track(anim, path)
	if track_idx < 0:
		push_warning("TimelineManager: track not found for %s:%s." % [surface_id, property])
		return

	var key_idx := _find_key_at_time(anim, track_idx, time)
	if key_idx < 0:
		push_warning("TimelineManager: no keyframe at time %.4f on %s." % [time, path])
		return

	anim.track_set_key_value(track_idx, key_idx, value)
	track_changed.emit(surface_id, property)


func update_keyframe_easing(surface_id: String, property: String, time: float, easing: String) -> void:
	var anim := _get_active_animation()
	if anim == null:
		push_warning("TimelineManager: no active scene for update_keyframe_easing.")
		return

	# Validate easing, fall back to linear
	if easing not in VALID_EASINGS:
		push_warning("TimelineManager: unknown easing '%s', falling back to linear." % easing)
		easing = "linear"

	var path := _track_path(surface_id, property)
	var track_idx := _find_track(anim, path)
	if track_idx < 0:
		push_warning("TimelineManager: track not found for %s:%s." % [surface_id, property])
		return

	var key_idx := _find_key_at_time(anim, track_idx, time)
	if key_idx < 0:
		push_warning("TimelineManager: no keyframe at time %.4f on %s." % [time, path])
		return

	# Update transition float on the key
	var transition := _easing_to_transition(easing)
	anim.track_set_key_transition(track_idx, key_idx, transition)

	# Update easing in parallel dictionary
	var actual_time := anim.track_get_key_time(track_idx, key_idx)
	_keyframe_easing[_easing_key(_active_scene_name, path, actual_time)] = easing

	track_changed.emit(surface_id, property)


func get_keyframes(surface_id: String, property: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var anim := _get_active_animation()
	if anim == null:
		return result

	var path := _track_path(surface_id, property)
	var track_idx := _find_track(anim, path)
	if track_idx < 0:
		return result

	var key_count := anim.track_get_key_count(track_idx)
	for i in range(key_count):
		var t := anim.track_get_key_time(track_idx, i)
		var v: Variant = anim.track_get_key_value(track_idx, i)
		var easing_key := _easing_key(_active_scene_name, path, t)
		var easing: String = _keyframe_easing.get(easing_key, "linear")
		result.append({"time": t, "value": v, "easing": easing})

	return result


# ---------------------------------------------------------------------------
# Playback controls
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _animation_player.is_playing():
		playhead_moved.emit(_animation_player.current_animation_position)


func play() -> void:
	if _active_scene_name.is_empty():
		push_warning("TimelineManager: no active scene — play() is a no-op.")
		return

	if _is_paused:
		# Resume from paused state
		_is_paused = false
		_animation_player.speed_scale = _current_speed
		playback_state_changed.emit(true)
		return

	if _animation_player.is_playing():
		# Already playing, nothing to do
		return

	# Start fresh playback from current position
	_animation_player.speed_scale = _current_speed
	_animation_player.play(_active_scene_name)
	playback_state_changed.emit(true)


func pause() -> void:
	if not _animation_player.is_playing() and not _is_paused:
		return

	_is_paused = true
	_animation_player.speed_scale = 0.0
	playback_state_changed.emit(false)


func stop() -> void:
	_is_paused = false
	_animation_player.stop()
	# Seek to beginning and apply values
	if _active_scene_name != "":
		_animation_player.play(_active_scene_name)
		_animation_player.seek(0.0, true)
		_animation_player.stop()
	# Pick up any manual edits made while stopped (Req 8.1, 8.2)
	_sync_all_proxies()
	playback_state_changed.emit(false)
	playhead_moved.emit(0.0)


func seek(time: float) -> void:
	if _active_scene_name.is_empty():
		return

	var duration := get_duration()
	time = clampf(time, 0.0, duration)

	# If not currently playing, we need to briefly play to allow seeking
	var was_playing := _animation_player.is_playing() and not _is_paused
	if not _animation_player.is_playing():
		_animation_player.play(_active_scene_name)
		_animation_player.seek(time, true)
		if not was_playing:
			_animation_player.stop()
	else:
		_animation_player.seek(time, true)

	playhead_moved.emit(time)


func step_forward() -> void:
	var current := get_playhead_time()
	var duration := get_duration()
	var new_time := minf(current + 1.0 / 60.0, duration)
	seek(new_time)


func step_backward() -> void:
	var current := get_playhead_time()
	var new_time := maxf(current - 1.0 / 60.0, 0.0)
	seek(new_time)


func set_speed(multiplier: float) -> void:
	_current_speed = clampf(multiplier, 0.1, 4.0)
	# Apply immediately if currently playing (and not paused)
	if _animation_player.is_playing() and not _is_paused:
		_animation_player.speed_scale = _current_speed


func get_speed() -> float:
	return _current_speed


func is_playing() -> bool:
	return _animation_player.is_playing() and not _is_paused


func get_playhead_time() -> float:
	if _active_scene_name.is_empty():
		return 0.0
	if _animation_player.current_animation == "":
		return 0.0
	return _animation_player.current_animation_position


func get_duration() -> float:
	if _active_scene_name.is_empty() or not _scenes.has(_active_scene_name):
		return 0.0
	return _scenes[_active_scene_name]["duration"]


# ---------------------------------------------------------------------------
# Track armability
# ---------------------------------------------------------------------------

func set_track_armed(surface_id: String, property: String, armed: bool) -> void:
	if _active_scene_name.is_empty() or not _scenes.has(_active_scene_name):
		push_warning("TimelineManager: no active scene for set_track_armed.")
		return

	var armed_tracks: Dictionary = _scenes[_active_scene_name]["armed_tracks"]
	if not armed_tracks.has(surface_id):
		armed_tracks[surface_id] = [] as Array[String]

	var props: Array = armed_tracks[surface_id]
	if armed:
		if property not in props:
			props.append(property)
	else:
		props.erase(property)

	track_changed.emit(surface_id, property)


func is_track_armed(surface_id: String, property: String) -> bool:
	if _active_scene_name.is_empty() or not _scenes.has(_active_scene_name):
		return false

	var armed_tracks: Dictionary = _scenes[_active_scene_name]["armed_tracks"]
	if not armed_tracks.has(surface_id):
		return false

	return property in armed_tracks[surface_id]


func get_armed_tracks(surface_id: String) -> Array[String]:
	var result: Array[String] = []
	if _active_scene_name.is_empty() or not _scenes.has(_active_scene_name):
		return result

	var armed_tracks: Dictionary = _scenes[_active_scene_name]["armed_tracks"]
	if not armed_tracks.has(surface_id):
		return result

	for prop in armed_tracks[surface_id]:
		result.append(prop)
	return result


func get_visible_tracks(surface_id: String) -> Array[String]:
	var result: Array[String] = []
	if _active_scene_name.is_empty() or not _scenes.has(_active_scene_name):
		return result

	var armed: Array[String] = get_armed_tracks(surface_id)

	# Check all animatable properties for keyframes in the active scene
	var has_keyframes_set: Array[String] = []
	var anim := _get_active_animation()
	if anim != null:
		for prop in ANIMATABLE_PROPERTIES:
			var path := _track_path(surface_id, prop)
			var track_idx := _find_track(anim, path)
			if track_idx >= 0 and anim.track_get_key_count(track_idx) > 0:
				has_keyframes_set.append(prop)

	# A track is visible if it's armed OR has keyframes
	for prop in ANIMATABLE_PROPERTIES:
		if prop in armed or prop in has_keyframes_set:
			result.append(prop)

	return result


# ---------------------------------------------------------------------------
# Proxy sync helper
# ---------------------------------------------------------------------------

## Re-sync all SurfaceProxy children from SurfaceManager.
## Called when playback stops so proxies pick up any manual edits
## made while the animation was not running (Req 8.1, 8.2).
func _sync_all_proxies() -> void:
	for child in get_children():
		if child.name.begins_with("SurfaceProxy_"):
			child.sync_from_surface()


# ---------------------------------------------------------------------------
# Animation finished handler
# ---------------------------------------------------------------------------

func _on_animation_finished(_anim_name: StringName) -> void:
	# For one-shot (non-looping) animations, leave playhead at end
	if _active_scene_name.is_empty():
		return

	var loop_mode: String = _scenes.get(_active_scene_name, {}).get("loop_mode", "none")
	if loop_mode == "none":
		_is_paused = false
		# Playhead stays at end position — don't reset to 0
		var duration := get_duration()
		# Pick up any manual edits made while stopped (Req 8.1, 8.2)
		_sync_all_proxies()
		playback_state_changed.emit(false)
		playhead_moved.emit(duration)


# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

# Property name → expected type for deserialization
const PROPERTY_TYPE_MAP: Dictionary = {
	"opacity": "float",
	"color": "Color",
	"visible_prop": "bool",
	"z_index_prop": "int",
	"corner_tl": "Vector2",
	"corner_tr": "Vector2",
	"corner_br": "Vector2",
	"corner_bl": "Vector2",
	"fit_mode": "String",
}


## Serialize a single value to a JSON-compatible type.
func _serialize_value(value: Variant) -> Variant:
	if value is Color:
		return "#" + value.to_html(false)
	if value is Vector2:
		return [value.x, value.y]
	# float, int, bool, String pass through as-is (JSON-compatible)
	return value


## Deserialize a JSON value back to the correct GDScript type based on property name.
func _deserialize_value(property: String, json_value: Variant) -> Variant:
	var expected_type: String = PROPERTY_TYPE_MAP.get(property, "")
	match expected_type:
		"float":
			return float(json_value)
		"Color":
			if json_value is String:
				return Color.html(json_value)
			push_warning("TimelineManager: expected hex string for Color property '%s', got %s." % [property, typeof(json_value)])
			return Color.WHITE
		"Vector2":
			if json_value is Array and json_value.size() >= 2:
				return Vector2(float(json_value[0]), float(json_value[1]))
			push_warning("TimelineManager: expected [x,y] array for Vector2 property '%s'." % property)
			return Vector2.ZERO
		"bool":
			return bool(json_value)
		"int":
			return int(json_value)
		"String":
			return str(json_value)
		_:
			# Unknown property type — return as-is
			push_warning("TimelineManager: unknown property type for '%s', passing value through." % property)
			return json_value


## Serialize all animation scenes to a Dictionary (version:1 envelope).
func serialize_animations() -> Dictionary:
	var scenes_array: Array = []

	for scene_name in _scenes:
		var meta: Dictionary = _scenes[scene_name]
		var anim: Animation = _animation_library.get_animation(scene_name)
		if anim == null:
			continue

		var tracks_array: Array = []
		var track_count := anim.get_track_count()
		for t_idx in range(track_count):
			var path_str := str(anim.track_get_path(t_idx))
			# Parse "SurfaceProxy_{id}:{property}" from the track path
			var colon_pos := path_str.find(":")
			if colon_pos < 0:
				continue
			var node_part := path_str.substr(0, colon_pos)
			var property := path_str.substr(colon_pos + 1)
			if not node_part.begins_with("SurfaceProxy_"):
				continue
			var surface_id := node_part.substr("SurfaceProxy_".length())

			var keys_array: Array = []
			var key_count := anim.track_get_key_count(t_idx)
			for k_idx in range(key_count):
				var time := anim.track_get_key_time(t_idx, k_idx)
				var value: Variant = anim.track_get_key_value(t_idx, k_idx)
				var easing_key := _easing_key(scene_name, path_str, time)
				var easing: String = _keyframe_easing.get(easing_key, "linear")
				keys_array.append({
					"time": time,
					"value": _serialize_value(value),
					"easing": easing,
				})

			tracks_array.append({
				"surface_id": surface_id,
				"property": property,
				"track_type": "value",
				"keys": keys_array,
			})

		# Serialize armed_tracks
		var armed_dict: Dictionary = {}
		var armed_tracks: Dictionary = meta.get("armed_tracks", {})
		for sid in armed_tracks:
			var props: Array = armed_tracks[sid]
			var props_copy: Array = []
			for p in props:
				props_copy.append(p)
			armed_dict[sid] = props_copy

		scenes_array.append({
			"name": scene_name,
			"duration": meta["duration"],
			"loop_mode": meta["loop_mode"],
			"armed_tracks": armed_dict,
			"tracks": tracks_array,
		})

	return {
		"version": 1,
		"active_scene": _active_scene_name,
		"scenes": scenes_array,
	}


## Deserialize animation data from a Dictionary.
## Clears all existing scenes and rebuilds from the provided data.
## Handles malformed data gracefully (logs errors, inits empty).
func deserialize_animations(data: Variant) -> void:
	# --- Validate top-level structure ---
	if data == null or not (data is Dictionary):
		if data != null:
			push_error("TimelineManager: deserialize_animations received non-Dictionary data, initializing empty.")
		_clear_all_animations()
		return

	var dict: Dictionary = data

	# Handle missing or empty data gracefully (Req 9.6)
	if dict.is_empty():
		_clear_all_animations()
		return

	if not dict.has("scenes"):
		# Missing "scenes" key — not necessarily an error if the whole
		# animations block is just absent. Init empty, no error (Req 9.6).
		_clear_all_animations()
		return

	if not (dict["scenes"] is Array):
		push_error("TimelineManager: 'scenes' is not an Array, initializing empty.")
		_clear_all_animations()
		return

	# --- Clear existing state ---
	_clear_all_animations()

	# --- Rebuild from data ---
	var scenes_data: Array = dict["scenes"]
	for scene_data in scenes_data:
		if not (scene_data is Dictionary):
			push_warning("TimelineManager: skipping non-Dictionary scene entry.")
			continue

		var scene_name: String = str(scene_data.get("name", ""))
		if scene_name.is_empty():
			push_warning("TimelineManager: skipping scene with empty name.")
			continue

		var duration: float = float(scene_data.get("duration", 0.0))
		if duration <= 0.0:
			push_warning("TimelineManager: scene '%s' has duration <= 0, clamping to 0.1." % scene_name)
			duration = 0.1

		var loop_mode_str: String = str(scene_data.get("loop_mode", "none"))

		# Create the Animation resource
		var anim := Animation.new()
		anim.length = duration
		if loop_mode_str == "loop":
			anim.loop_mode = Animation.LOOP_LINEAR
		else:
			anim.loop_mode = Animation.LOOP_NONE
			loop_mode_str = "none"

		_animation_library.add_animation(scene_name, anim)

		# Rebuild armed_tracks
		var armed_tracks: Dictionary = {}
		if scene_data.has("armed_tracks") and scene_data["armed_tracks"] is Dictionary:
			var armed_data: Dictionary = scene_data["armed_tracks"]
			for sid in armed_data:
				if armed_data[sid] is Array:
					var props: Array = []
					for p in armed_data[sid]:
						props.append(str(p))
					armed_tracks[str(sid)] = props

		# Store scene metadata
		_scenes[scene_name] = {
			"duration": duration,
			"loop_mode": loop_mode_str,
			"armed_tracks": armed_tracks,
		}

		# Rebuild tracks and keyframes
		if scene_data.has("tracks") and scene_data["tracks"] is Array:
			var tracks_data: Array = scene_data["tracks"]
			for track_data in tracks_data:
				if not (track_data is Dictionary):
					push_warning("TimelineManager: skipping non-Dictionary track entry in scene '%s'." % scene_name)
					continue

				var surface_id: String = str(track_data.get("surface_id", ""))
				var property: String = str(track_data.get("property", ""))

				if surface_id.is_empty() or property.is_empty():
					push_warning("TimelineManager: skipping track with empty surface_id or property in scene '%s'." % scene_name)
					continue

				# Validate surface exists in SurfaceManager (Req 12.1)
				var surface_dict := SurfaceManager.get_surface(surface_id)
				if surface_dict.is_empty():
					push_warning("TimelineManager: surface '%s' not found in SurfaceManager, skipping track for '%s' in scene '%s'." % [surface_id, property, scene_name])
					continue

				var path := _track_path(surface_id, property)

				if track_data.has("keys") and track_data["keys"] is Array:
					var keys_data: Array = track_data["keys"]
					for key_data in keys_data:
						if not (key_data is Dictionary):
							push_warning("TimelineManager: skipping non-Dictionary keyframe in track '%s:%s' scene '%s'." % [surface_id, property, scene_name])
							continue

						var time: float = float(key_data.get("time", 0.0))
						time = clampf(time, 0.0, duration)

						var json_value: Variant = key_data.get("value", null)
						var value: Variant = _deserialize_value(property, json_value)

						# Validate easing (Req 12.2)
						var easing: String = str(key_data.get("easing", "linear"))
						if easing not in VALID_EASINGS:
							push_warning("TimelineManager: unknown easing '%s' in scene '%s' track '%s:%s', falling back to linear." % [easing, scene_name, surface_id, property])
							easing = "linear"

						# Find or create the track
						var track_idx := _find_or_create_track(anim, path)

						# Insert the keyframe
						var transition := _easing_to_transition(easing)
						anim.track_insert_key(track_idx, time, value, transition)

						# Store easing in parallel dictionary
						_keyframe_easing[_easing_key(scene_name, path, time)] = easing

	# Set active scene if specified and exists
	var active_name: String = str(dict.get("active_scene", ""))
	if not active_name.is_empty() and _scenes.has(active_name):
		_active_scene_name = active_name
		_animation_player.assigned_animation = active_name
		animation_scene_changed.emit(active_name)

	animation_list_changed.emit()


## Clear all animation scenes, metadata, and easing data.
func _clear_all_animations() -> void:
	# Remove all animations from the library
	for anim_name in _animation_library.get_animation_list():
		_animation_library.remove_animation(anim_name)

	_scenes.clear()
	_keyframe_easing.clear()
	_active_scene_name = ""
