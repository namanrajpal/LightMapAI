extends Control
## ProjectionSurface — Manages one warpable surface: quad rendering,
## grid overlay, corner handles.
## Uses direct Polygon2D vertex positioning for reliable rendering.

var surface_id: String = ""
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

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_create_warp_polygon()
	_create_corner_handles()

	SurfaceManager.surface_selected.connect(_on_surface_selected)
	SurfaceManager.surface_updated.connect(_on_surface_updated)
	SurfaceManager.mode_changed.connect(_on_mode_changed)


func initialize(id: String) -> void:
	surface_id = id
	var s := SurfaceManager.get_surface(id)
	if s.is_empty():
		return

	corners = s["corners"].duplicate()
	z_index = s["z_index"]
	visible = s["visible"]
	surface_color = Color.html(s["color"])
	show_grid = s["grid_on"]

	_update_polygon()
	_position_handles()


# ---------------------------------------------------------------------------
# Visual construction
# ---------------------------------------------------------------------------
func _create_warp_polygon() -> void:
	warp_polygon = Polygon2D.new()
	warp_polygon.name = "WarpQuad"
	warp_polygon.color = surface_color
	add_child(warp_polygon)


func _create_corner_handles() -> void:
	for i in range(4):
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
	if corners.size() < 4:
		return

	# Set polygon vertices directly to corner positions (TL, TR, BR, BL)
	warp_polygon.polygon = corners
	warp_polygon.color = surface_color

	# Set UVs for texture mapping (unit square)
	if _test_texture:
		warp_polygon.texture = _test_texture
		warp_polygon.uv = PackedVector2Array([
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)
		])
	else:
		warp_polygon.texture = null

	# Trigger redraw for grid/selection overlays
	queue_redraw()


func _position_handles() -> void:
	for i in range(4):
		if i < corner_handles.size() and i < corners.size():
			corner_handles[i].set_corner_position(corners[i])


# ---------------------------------------------------------------------------
# Custom drawing: grid + selection border
# ---------------------------------------------------------------------------
func _draw() -> void:
	if corners.size() < 4:
		return

	# Draw selection border
	if _is_selected and not SurfaceManager.is_output_mode:
		for i in range(4):
			var a := corners[i]
			var b := corners[(i + 1) % 4]
			draw_line(a, b, SELECTION_BORDER_COLOR, SELECTION_BORDER_WIDTH)

	# Draw grid
	if show_grid and not SurfaceManager.is_output_mode:
		_draw_grid()


func _draw_grid() -> void:
	var tl := corners[0]
	var tr := corners[1]
	var br := corners[2]
	var bl := corners[3]

	# Draw border
	draw_line(tl, tr, GRID_BORDER_COLOR, GRID_BORDER_WIDTH)
	draw_line(tr, br, GRID_BORDER_COLOR, GRID_BORDER_WIDTH)
	draw_line(br, bl, GRID_BORDER_COLOR, GRID_BORDER_WIDTH)
	draw_line(bl, tl, GRID_BORDER_COLOR, GRID_BORDER_WIDTH)

	# Draw interior grid lines using bilinear interpolation
	for i in range(1, GRID_DIVISIONS):
		var t: float = float(i) / float(GRID_DIVISIONS)

		# Horizontal lines: interpolate between left edge and right edge
		var left := tl.lerp(bl, t)
		var right := tr.lerp(br, t)
		draw_line(left, right, GRID_LINE_COLOR, GRID_LINE_WIDTH)

		# Vertical lines: interpolate between top edge and bottom edge
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
	for h in corner_handles:
		h.visible = selected and not SurfaceManager.is_output_mode
	queue_redraw()


func set_test_pattern(texture: Texture2D) -> void:
	_test_texture = texture
	_update_polygon()


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
	if id != surface_id:
		return
	var s := SurfaceManager.get_surface(id)
	if s.is_empty():
		return

	_apply_color(Color.html(s["color"]))
	_update_grid_visibility(s["grid_on"])
	z_index = s["z_index"]
	visible = s["visible"]

	var new_corners: PackedVector2Array = s["corners"]
	if new_corners != corners:
		corners = new_corners.duplicate()
		_update_polygon()
		_position_handles()


func _on_mode_changed(is_output: bool) -> void:
	for h in corner_handles:
		h.visible = !is_output and _is_selected
	queue_redraw()


# ---------------------------------------------------------------------------
# Click detection (for selecting surfaces by clicking on them)
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if SurfaceManager.is_output_mode:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _point_in_quad(mb.global_position):
				if not _any_handle_has_focus():
					SurfaceManager.select_surface(surface_id)


func _point_in_quad(point: Vector2) -> bool:
	if corners.size() < 4:
		return false
	# Cross product winding test for convex polygon
	for i in range(4):
		var a := corners[i]
		var b := corners[(i + 1) % 4]
		var cross_val: float = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
		if cross_val < 0:
			return false
	return true


func _any_handle_has_focus() -> bool:
	for h in corner_handles:
		if h.has_focus():
			return true
	return false
