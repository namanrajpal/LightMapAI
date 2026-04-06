extends Control
## ProjectionSurface — Manages one warpable surface: quad rendering,
## grid overlay, corner handles.
## Uses direct Polygon2D vertex positioning for reliable rendering.

var surface_id: String = ""
var output_only: bool = false
var corners: PackedVector2Array = PackedVector2Array()
var surface_color: Color = Color(0.267, 0.533, 1.0, 1.0)
var show_grid: bool = false

# Child nodes (created in _ready)
var warp_polygon: Polygon2D
var corner_handles: Array[Control] = []

# Preload
var corner_handle_scene: PackedScene = preload("res://scenes/corner_handle.tscn")

# Grid settings
const GRID_DIVISIONS: int = 10
const GRID_LINE_COLOR := Color(1.0, 1.0, 1.0, 0.4)
const GRID_BORDER_COLOR := Color(1.0, 1.0, 1.0, 0.7)
const GRID_LINE_WIDTH: float = 1.0
const GRID_BORDER_WIDTH: float = 2.0

# Selection
var _is_selected: bool = false
const SELECTION_BORDER_COLOR := Color(1.0, 1.0, 0.0, 0.8)
const SELECTION_BORDER_WIDTH: float = 2.5

# Test pattern
var _test_texture: Texture2D = null

# Media content
var _content_type: String = "color"  # "color", "image", "video", "shader"
var _content_source: String = ""
var _content_texture: Texture2D = null
var _video_player: VideoStreamPlayer = null
var _video_viewport: SubViewport = null
var _video_sprite: Sprite2D = null
var _opacity: float = 1.0
var _fit_mode: String = "stretch"
var _updating: bool = false  # Re-entrancy guard

# Shader effect
var _shader_material: ShaderMaterial = null
var _shader_effect_id: String = ""
var _shader_viewport: SubViewport = null
var _shader_rect: ColorRect = null

# CEF web browser
var _cef_node: Node = null  # GDCEF instance
var _browser_view: Node = null  # GdBrowserView instance
var _browser_texture_rect: TextureRect = null

# Whole-surface drag state
var _is_dragging: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_corners: PackedVector2Array = PackedVector2Array()

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_create_warp_polygon()

	SurfaceManager.surface_selected.connect(_on_surface_selected)
	SurfaceManager.surface_updated.connect(_on_surface_updated)
	if not output_only:
		SurfaceManager.mode_changed.connect(_on_mode_changed)


func initialize(id: String, p_output_only: bool = false) -> void:
	output_only = p_output_only
	surface_id = id
	var s := SurfaceManager.get_surface(id)
	if s.is_empty():
		return

	corners = s["corners"].duplicate()
	z_index = s["z_index"]
	visible = s["visible"]
	surface_color = Color.html(s["color"])
	show_grid = s["grid_on"]
	_opacity = s.get("opacity", 1.0)
	_fit_mode = s.get("fit_mode", "stretch")

	if not output_only:
		_create_corner_handles()

	_update_polygon()
	_position_handles()
	_apply_opacity(_opacity)

	# Load content if specified
	var ct: String = s.get("content_type", "color")
	var cs: String = s.get("content_source", "")
	if ct != "color" and cs != "":
		load_content(ct, cs)


# ---------------------------------------------------------------------------
# Visual construction
# ---------------------------------------------------------------------------
func _create_warp_polygon() -> void:
	warp_polygon = Polygon2D.new()
	warp_polygon.name = "WarpQuad"
	warp_polygon.color = surface_color
	add_child(warp_polygon)


func _create_corner_handles() -> void:
	for i in range(corners.size()):
		var handle: Control = corner_handle_scene.instantiate()
		handle.corner_index = i
		handle.name = "Handle_%d" % i
		handle.corner_moved.connect(_on_corner_moved)
		corner_handles.append(handle)
		add_child(handle)


# ---------------------------------------------------------------------------
# Geometry updates
# ---------------------------------------------------------------------------
func _update_polygon() -> void:
	if corners.size() < 3:
		return

	# Set polygon vertices directly to corner positions
	warp_polygon.polygon = corners
	warp_polygon.color = surface_color

	# Determine which texture to use: content > test pattern > none
	var active_texture: Texture2D = null
	if _content_texture:
		active_texture = _content_texture
	elif _test_texture:
		active_texture = _test_texture

	if active_texture:
		warp_polygon.texture = active_texture
		# For shader content on quads, use canonical UVs so edge-distance
		# shaders work correctly regardless of polygon warp shape
		if _shader_material and corners.size() == 4:
			var tex_size := active_texture.get_size()
			warp_polygon.uv = PackedVector2Array([
				Vector2(0, 0),
				Vector2(tex_size.x, 0),
				Vector2(tex_size.x, tex_size.y),
				Vector2(0, tex_size.y),
			])
		else:
			warp_polygon.uv = _compute_fit_uvs(active_texture)
		warp_polygon.color = Color.WHITE
	else:
		warp_polygon.texture = null
		warp_polygon.color = surface_color

	# Trigger redraw for grid/selection overlays
	queue_redraw()


func _position_handles() -> void:
	for i in range(corners.size()):
		if i < corner_handles.size():
			corner_handles[i].set_corner_position(corners[i])


# ---------------------------------------------------------------------------
# Custom drawing: grid + selection border
# ---------------------------------------------------------------------------
func _draw() -> void:
	if corners.size() < 3:
		return

	if output_only:
		return

	# Draw selection border
	if _is_selected and not SurfaceManager.is_output_mode:
		for i in range(corners.size()):
			var a := corners[i]
			var b := corners[(i + 1) % corners.size()]
			draw_line(a, b, SELECTION_BORDER_COLOR, SELECTION_BORDER_WIDTH)

	# Draw grid
	if show_grid and not SurfaceManager.is_output_mode:
		_draw_grid()


func _draw_grid() -> void:
	# Draw border for any polygon
	for i in range(corners.size()):
		var a := corners[i]
		var b := corners[(i + 1) % corners.size()]
		draw_line(a, b, GRID_BORDER_COLOR, GRID_BORDER_WIDTH)

	# Interior grid lines only for quads (4 corners)
	if corners.size() == 4:
		var tl := corners[0]
		var tr := corners[1]
		var br := corners[2]
		var bl := corners[3]
		for i in range(1, GRID_DIVISIONS):
			var t: float = float(i) / float(GRID_DIVISIONS)
			var left := tl.lerp(bl, t)
			var right := tr.lerp(br, t)
			draw_line(left, right, GRID_LINE_COLOR, GRID_LINE_WIDTH)
			var top := tl.lerp(tr, t)
			var bottom := bl.lerp(br, t)
			draw_line(top, bottom, GRID_LINE_COLOR, GRID_LINE_WIDTH)


# ---------------------------------------------------------------------------
# Appearance
# ---------------------------------------------------------------------------
func _apply_color(col: Color) -> void:
	surface_color = col
	if warp_polygon:
		warp_polygon.color = col


func _update_grid_visibility(grid_on: bool) -> void:
	show_grid = grid_on
	queue_redraw()


func set_selected(selected: bool) -> void:
	_is_selected = selected
	if not output_only:
		for h in corner_handles:
			h.visible = selected and not SurfaceManager.is_output_mode
	queue_redraw()


func set_test_pattern(texture: Texture2D) -> void:
	_test_texture = texture
	_update_polygon()


# ---------------------------------------------------------------------------
# Media content loading
# ---------------------------------------------------------------------------
func load_content(content_type: String, source_path: String) -> void:
	# If already showing web and just changing URL, navigate instead of recreating
	if content_type == "web" and _content_type == "web" and _browser_view != null:
		_content_source = source_path
		if _browser_view.has_method("load_url"):
			_browser_view.load_url(source_path)
		return

	# If same shader, skip reload
	if content_type == "shader" and _content_type == "shader" and _shader_effect_id == source_path:
		return

	# Clean up previous content
	_cleanup_video()
	_cleanup_web()
	_cleanup_shader()
	_content_type = content_type
	_content_source = source_path

	match content_type:
		"image":
			_load_image(source_path)
		"video":
			_load_video(source_path)
		"web":
			_load_web(source_path)
		"shader":
			_load_shader(source_path)
		_:
			_content_texture = null
			_update_polygon()


func clear_content() -> void:
	_cleanup_video()
	_cleanup_web()
	_cleanup_shader()
	_content_type = "color"
	_content_source = ""
	_content_texture = null
	_test_texture = null
	_update_polygon()


func _load_image(path: String) -> void:
	var img := Image.new()
	var err: Error
	if path.begins_with("res://") or path.begins_with("user://"):
		# Godot resource path
		var tex := load(path) as Texture2D
		if tex:
			_content_texture = tex
			_update_polygon()
			return
	# Absolute file path — load from disk
	err = img.load(path)
	if err != OK:
		push_error("ProjectionSurface: Failed to load image: %s (error %d)" % [path, err])
		return
	_content_texture = ImageTexture.create_from_image(img)
	_update_polygon()


func _load_video(path: String) -> void:
	# Create a SubViewport to render the video into
	_video_viewport = SubViewport.new()
	_video_viewport.name = "VideoViewport"
	_video_viewport.size = Vector2i(1024, 1024)
	_video_viewport.transparent_bg = false
	_video_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_video_viewport)

	_video_player = VideoStreamPlayer.new()
	_video_player.name = "VideoPlayer"
	_video_player.autoplay = true
	_video_player.loop = true
	_video_player.volume_db = -80.0  # Muted
	_video_player.expand = true

	# Load the video stream
	if path.begins_with("res://") or path.begins_with("user://"):
		_video_player.stream = load(path)
	else:
		# For absolute paths, try loading as a resource
		var stream := VideoStreamTheora.new()
		stream.file = path
		_video_player.stream = stream

	_video_viewport.add_child(_video_player)
	_video_player.play()

	# The video texture will be grabbed each frame in _process
	set_process(true)


func _cleanup_video() -> void:
	if _video_player:
		_video_player.stop()
		_video_player.queue_free()
		_video_player = null
	if _video_viewport:
		_video_viewport.queue_free()
		_video_viewport = null
	_video_sprite = null
	set_process(false)


func _load_web(url: String) -> void:
	# Create a GDCEF node if the class exists
	if not ClassDB.class_exists("GdCEF"):
		push_error("ProjectionSurface: GdCEF class not found — is the gdcef extension loaded?")
		return

	_cef_node = ClassDB.instantiate("GdCEF")
	_cef_node.name = "CEF_%s" % surface_id
	add_child(_cef_node)

	# Initialize CEF
	var settings := {
		"locale": "en-US",
		"enable_media_stream": false,
		"remote_debugging_port": 0,
	}
	if not _cef_node.initialize(settings):
		push_error("ProjectionSurface: Failed to initialize GDCEF")
		_cleanup_web()
		return

	# Create a TextureRect to receive the browser output
	_browser_texture_rect = TextureRect.new()
	_browser_texture_rect.name = "BrowserTarget"
	_browser_texture_rect.visible = false  # Hidden — we just grab its texture
	_browser_texture_rect.custom_minimum_size = Vector2(1024, 768)
	_browser_texture_rect.size = Vector2(1024, 768)
	add_child(_browser_texture_rect)

	# Create the browser
	var browser_settings := {"javascript": true, "javascript_close_windows": false}
	_browser_view = _cef_node.create_browser(url, _browser_texture_rect, browser_settings)

	if _browser_view == null:
		push_error("ProjectionSurface: Failed to create CEF browser for URL: %s" % url)
		_cleanup_web()
		return

	# Start grabbing the browser texture each frame
	set_process(true)


func _cleanup_web() -> void:
	if _browser_view:
		# Close the browser before freeing nodes
		if _browser_view.has_method("close"):
			_browser_view.close()
		_browser_view = null
	if _browser_texture_rect:
		_browser_texture_rect.queue_free()
		_browser_texture_rect = null
	if _cef_node:
		if _cef_node.has_method("shutdown"):
			_cef_node.shutdown()
		_cef_node.queue_free()
		_cef_node = null


# ---------------------------------------------------------------------------
# Shader effect content
# ---------------------------------------------------------------------------
func _load_shader(effect_id: String) -> void:
	_shader_effect_id = effect_id
	var effect = ShaderRegistry.get_effect(effect_id)
	if effect == null:
		push_error("ProjectionSurface: Shader effect not found: %s" % effect_id)
		return

	# Size the viewport to match the polygon's bounding box aspect ratio
	# so the shader renders at correct proportions before being mapped
	var bbox := _get_corners_bbox()
	var vp_w := int(clampf(bbox.size.x, 128, 2048))
	var vp_h := int(clampf(bbox.size.y, 128, 2048))

	_shader_viewport = SubViewport.new()
	_shader_viewport.name = "ShaderViewport"
	_shader_viewport.size = Vector2i(vp_w, vp_h)
	_shader_viewport.transparent_bg = false
	_shader_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_shader_viewport)

	_shader_rect = ColorRect.new()
	_shader_rect.name = "ShaderRect"
	_shader_rect.anchors_preset = Control.PRESET_FULL_RECT
	_shader_rect.size = Vector2(vp_w, vp_h)

	_shader_material = ShaderRegistry.create_material(effect_id)
	if _shader_material:
		_shader_material.set_shader_parameter("_resolution", Vector2(vp_w, vp_h))
		_shader_rect.material = _shader_material
	_shader_viewport.add_child(_shader_rect)

	# Apply any saved params from the surface data
	var s := SurfaceManager.get_surface(surface_id)
	if not s.is_empty():
		var saved_params: Dictionary = s.get("shader_params", {})
		for key in saved_params:
			if _shader_material:
				_shader_material.set_shader_parameter(key, saved_params[key])

	set_process(true)


func _cleanup_shader() -> void:
	if _shader_rect:
		_shader_rect.queue_free()
		_shader_rect = null
	if _shader_viewport:
		_shader_viewport.queue_free()
		_shader_viewport = null
	_shader_material = null
	_shader_effect_id = ""


## Update a shader parameter at runtime (called from sidebar sliders).
func set_shader_param(param_name: String, value: Variant) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter(param_name, value)
	# Persist to surface data
	var s := SurfaceManager.get_surface(surface_id)
	if not s.is_empty():
		if not s.has("shader_params"):
			s["shader_params"] = {}
		s["shader_params"][param_name] = value


## Get the current ShaderMaterial (for external param queries).
func get_shader_material() -> ShaderMaterial:
	return _shader_material


func _exit_tree() -> void:
	_cleanup_web()
	_cleanup_video()
	_cleanup_shader()


func _process(_delta: float) -> void:
	# Grab the video viewport texture each frame
	if _video_viewport and _video_player and _video_player.is_playing():
		_content_texture = _video_viewport.get_texture()
		_update_polygon()

	# Grab the CEF browser texture each frame
	if _browser_texture_rect and _browser_texture_rect.texture:
		_content_texture = _browser_texture_rect.texture
		_update_polygon()

	# Grab the shader viewport texture each frame
	if _shader_viewport:
		_content_texture = _shader_viewport.get_texture()
		_update_polygon()


# ---------------------------------------------------------------------------
# Opacity
# ---------------------------------------------------------------------------
func _apply_opacity(opacity: float) -> void:
	_opacity = clampf(opacity, 0.0, 1.0)
	self_modulate.a = _opacity


func set_opacity(opacity: float) -> void:
	_apply_opacity(opacity)
	SurfaceManager.update_surface_property(surface_id, "opacity", _opacity)


# ---------------------------------------------------------------------------
# Fit modes
# ---------------------------------------------------------------------------
func _compute_fit_uvs(texture: Texture2D) -> PackedVector2Array:
	## Compute UV coordinates based on fit mode and texture aspect ratio.
	## For N-point polygons, maps UVs using bounding-box normalization.
	if not texture:
		# Default: normalize corners to [0,1] range via bounding box
		return _compute_bbox_uvs(Vector2(1, 1))

	var tex_size := texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return _compute_bbox_uvs(Vector2(1, 1))

	var w: float = tex_size.x
	var h: float = tex_size.y

	match _fit_mode:
		"stretch":
			return _compute_bbox_uvs(tex_size)
		"fit":
			return _compute_bbox_uvs(tex_size)
		"fill":
			# Compute bounding box aspect
			var bbox := _get_corners_bbox()
			var bbox_w: float = bbox.size.x
			var bbox_h: float = bbox.size.y
			if bbox_w <= 0 or bbox_h <= 0:
				return _compute_bbox_uvs(tex_size)
			var quad_aspect: float = bbox_w / bbox_h
			var tex_aspect: float = w / h
			if tex_aspect > quad_aspect:
				var visible_w: float = h * quad_aspect
				var offset_x: float = (w - visible_w) / 2.0
				return _compute_bbox_uvs_with_crop(tex_size, Rect2(offset_x, 0, visible_w, h))
			else:
				var visible_h: float = w / quad_aspect
				var offset_y: float = (h - visible_h) / 2.0
				return _compute_bbox_uvs_with_crop(tex_size, Rect2(0, offset_y, w, visible_h))

	return _compute_bbox_uvs(tex_size)


## Compute UVs by normalizing corner positions within their bounding box,
## then scaling to texture pixel coordinates.
func _compute_bbox_uvs(tex_size: Vector2) -> PackedVector2Array:
	var bbox := _get_corners_bbox()
	var uvs := PackedVector2Array()
	for c in corners:
		var u: float = (c.x - bbox.position.x) / maxf(bbox.size.x, 1.0) * tex_size.x
		var v: float = (c.y - bbox.position.y) / maxf(bbox.size.y, 1.0) * tex_size.y
		uvs.append(Vector2(u, v))
	return uvs


func _compute_bbox_uvs_with_crop(tex_size: Vector2, crop: Rect2) -> PackedVector2Array:
	var bbox := _get_corners_bbox()
	var uvs := PackedVector2Array()
	for c in corners:
		var norm_x: float = (c.x - bbox.position.x) / maxf(bbox.size.x, 1.0)
		var norm_y: float = (c.y - bbox.position.y) / maxf(bbox.size.y, 1.0)
		uvs.append(Vector2(crop.position.x + norm_x * crop.size.x, crop.position.y + norm_y * crop.size.y))
	return uvs


func _get_corners_bbox() -> Rect2:
	if corners.is_empty():
		return Rect2()
	var min_pt := corners[0]
	var max_pt := corners[0]
	for c in corners:
		min_pt.x = minf(min_pt.x, c.x)
		min_pt.y = minf(min_pt.y, c.y)
		max_pt.x = maxf(max_pt.x, c.x)
		max_pt.y = maxf(max_pt.y, c.y)
	return Rect2(min_pt, max_pt - min_pt)


## Generate a grayscale texture where each pixel stores the normalized
## distance from the nearest polygon edge. Used by border shaders to
## follow the actual polygon shape instead of assuming a rectangle.
func _generate_edge_distance_texture(width: int, height: int) -> ImageTexture:
	if corners.size() < 3:
		return null
	var bbox := _get_corners_bbox()
	if bbox.size.x <= 0 or bbox.size.y <= 0:
		return null

	# Build polygon in UV space (normalized 0-1 within bounding box)
	var poly_uv := PackedVector2Array()
	for c in corners:
		poly_uv.append(Vector2(
			(c.x - bbox.position.x) / bbox.size.x,
			(c.y - bbox.position.y) / bbox.size.y
		))

	# Use a lower resolution for the distance field (faster to compute)
	var res_w := mini(width, 256)
	var res_h := mini(height, 256)

	var img := Image.create(res_w, res_h, false, Image.FORMAT_L8)

	# For each pixel, compute distance to nearest polygon edge
	var max_dist := 0.0
	var distances := PackedFloat32Array()
	distances.resize(res_w * res_h)

	for y in range(res_h):
		for x in range(res_w):
			var uv := Vector2((float(x) + 0.5) / float(res_w), (float(y) + 0.5) / float(res_h))
			var min_d := 999.0
			for i in range(poly_uv.size()):
				var a := poly_uv[i]
				var b := poly_uv[(i + 1) % poly_uv.size()]
				var d := _point_to_segment_distance(uv, a, b)
				min_d = minf(min_d, d)
			distances[y * res_w + x] = min_d
			max_dist = maxf(max_dist, min_d)

	# Normalize and write to image
	if max_dist > 0.0:
		for y in range(res_h):
			for x in range(res_w):
				var d := distances[y * res_w + x] / max_dist
				img.set_pixel(x, y, Color(d, d, d, 1.0))

	var tex := ImageTexture.create_from_image(img)
	return tex


## Distance from point p to line segment a→b.
func _point_to_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ap := p - a
	var t := clampf(ap.dot(ab) / maxf(ab.dot(ab), 0.00001), 0.0, 1.0)
	var closest := a + ab * t
	return p.distance_to(closest)


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------
func _on_corner_moved(corner_index: int, new_position: Vector2) -> void:
	if corner_index < corners.size():
		corners[corner_index] = new_position
		_update_polygon()
		_position_handles()
		SurfaceManager.update_corners(surface_id, corners)


func _on_surface_selected(id: String) -> void:
	set_selected(id == surface_id)


func _on_surface_updated(id: String) -> void:
	if id != surface_id or _updating:
		return
	_updating = true
	var s := SurfaceManager.get_surface(id)
	if s.is_empty():
		_updating = false
		return

	_apply_color(Color.html(s["color"]))
	_update_grid_visibility(s["grid_on"])
	z_index = s["z_index"]
	visible = s["visible"]

	# Opacity
	var new_opacity: float = s.get("opacity", 1.0)
	if new_opacity != _opacity:
		_apply_opacity(new_opacity)

	# Fit mode
	var new_fit: String = s.get("fit_mode", "stretch")
	if new_fit != _fit_mode:
		_fit_mode = new_fit
		_update_polygon()

	# Content
	var new_ct: String = s.get("content_type", "color")
	var new_cs: String = s.get("content_source", "")
	if new_ct != _content_type or new_cs != _content_source:
		if new_ct == "color" or new_cs == "":
			clear_content()
		else:
			load_content(new_ct, new_cs)

	var new_corners: PackedVector2Array = s["corners"]
	var corners_changed: bool = new_corners.size() != corners.size()
	if not corners_changed:
		for i in range(new_corners.size()):
			if new_corners[i] != corners[i]:
				corners_changed = true
				break
	if corners_changed:
		corners = new_corners.duplicate()
		if not output_only:
			_sync_handle_count()
		_update_polygon()
		_position_handles()

	_updating = false


## Ensure the number of corner handles matches the number of corners.
func _sync_handle_count() -> void:
	while corner_handles.size() < corners.size():
		var i := corner_handles.size()
		var handle: Control = corner_handle_scene.instantiate()
		handle.corner_index = i
		handle.name = "Handle_%d" % i
		handle.corner_moved.connect(_on_corner_moved)
		handle.visible = _is_selected and not SurfaceManager.is_output_mode
		corner_handles.append(handle)
		add_child(handle)
	while corner_handles.size() > corners.size():
		var handle: Control = corner_handles.pop_back()
		handle.queue_free()


func _on_mode_changed(is_output: bool) -> void:
	for h in corner_handles:
		h.visible = !is_output and _is_selected
	queue_redraw()


# ---------------------------------------------------------------------------
# Whole-surface dragging (selection is handled by ProjectionCanvas)
# ---------------------------------------------------------------------------

## Called by ProjectionCanvas to initiate a drag on this surface.
func start_drag(mouse_pos: Vector2) -> void:
	# Deselect any focused corner handle
	for h in corner_handles:
		if h.has_focus():
			h.deselect()
			h.release_focus()
	_is_dragging = true
	_drag_start_mouse = mouse_pos
	_drag_start_corners = corners.duplicate()


func _input(event: InputEvent) -> void:
	if output_only or SurfaceManager.is_output_mode:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if _is_dragging:
				_is_dragging = false

	elif event is InputEventMouseMotion and _is_dragging:
		var mm := event as InputEventMouseMotion
		var delta := mm.global_position - _drag_start_mouse

		var new_corners := PackedVector2Array()
		for i in range(_drag_start_corners.size()):
			var c := _drag_start_corners[i] + delta
			c.x = clampf(c.x, 0.0, 1920.0)
			c.y = clampf(c.y, 0.0, 1080.0)
			new_corners.append(c)

		corners = new_corners
		_update_polygon()
		_position_handles()
		SurfaceManager.update_corners(surface_id, corners)


func _point_in_quad(point: Vector2) -> bool:
	if corners.size() < 3:
		return false
	return Geometry2D.is_point_in_polygon(point, corners)


func _any_handle_has_focus() -> bool:
	for h in corner_handles:
		if h.has_focus():
			return true
	return false


func _click_on_handle(point: Vector2) -> bool:
	for h in corner_handles:
		if h.visible and h.get_global_rect().has_point(point):
			return true
	return false
