extends Control
## ProjectionCanvas — Manages surface instances on the canvas.
## Handles z-order-aware click selection, click cycling for overlapping
## surfaces, right-click context menu, and surface lifecycle.

var surface_scene: PackedScene = preload("res://scenes/projection_surface.tscn")
var surface_nodes: Dictionary = {}  # id -> ProjectionSurface node
var output_only: bool = false

# Click cycling state — tracks which surface was last selected at a point
# so re-clicking the same spot cycles to the next one underneath
var _last_click_pos: Vector2 = Vector2.ZERO
var _last_click_surfaces: Array[String] = []  # sorted by z_index desc
var _last_click_index: int = -1

# Context menu
var _context_menu: PopupMenu
var _context_surface_ids: Array[String] = []  # surfaces at right-click point


func _ready() -> void:
	add_to_group("projection_canvas")
	_build_context_menu()
	if not output_only:
		SurfaceManager.surface_added.connect(_on_surface_added)
		SurfaceManager.surface_removed.connect(_on_surface_removed)
		SurfaceManager.surface_selected.connect(_on_surface_selected)


func initialize_output_mode() -> void:
	output_only = true
	SurfaceManager.surface_added.connect(_on_surface_added)
	SurfaceManager.surface_removed.connect(_on_surface_removed)
	SurfaceManager.surface_updated.connect(_on_surface_updated)
	for s in SurfaceManager.surfaces:
		_on_surface_added(s["id"])


# ---------------------------------------------------------------------------
# Hit testing — z-order aware
# ---------------------------------------------------------------------------

## Get all surface IDs whose polygon contains the given point,
## sorted by z_index descending (topmost first).
func _get_surfaces_at_point(point: Vector2) -> Array[String]:
	var hits: Array[Dictionary] = []
	for sid in surface_nodes:
		var node: Control = surface_nodes[sid]
		if node._point_in_quad(point):
			var s := SurfaceManager.get_surface(sid)
			if not s.is_empty():
				hits.append({"id": sid, "z": s["z_index"]})
	# Sort by z_index descending (topmost first)
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["z"] > b["z"])
	var result: Array[String] = []
	for h in hits:
		result.append(h["id"])
	return result


## Check if the point is on any visible corner handle.
func _is_on_handle(point: Vector2) -> bool:
	for sid in surface_nodes:
		var node: Control = surface_nodes[sid]
		for h in node.corner_handles:
			if h.visible and h.get_global_rect().grow(4.0).has_point(point):
				return true
	return false


# ---------------------------------------------------------------------------
# Input — centralized click handling
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if output_only or SurfaceManager.is_output_mode:
		return

	if not (event is InputEventMouseButton):
		return

	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return

	# Ignore clicks on sidebar (left 250px) and toolbar (top 40px)
	if mb.global_position.x < 260 or mb.global_position.y < 45:
		return

	# Don't interfere with corner handle clicks
	if _is_on_handle(mb.global_position):
		return

	if mb.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(mb)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click(mb)


func _handle_left_click(mb: InputEventMouseButton) -> void:
	var surfaces_here := _get_surfaces_at_point(mb.global_position)

	if surfaces_here.is_empty():
		# Click on void — deselect
		SurfaceManager.select_surface("")
		_last_click_surfaces.clear()
		_last_click_index = -1
		return

	# Check if this is a re-click at roughly the same spot (within 10px)
	var same_spot: bool = _last_click_pos.distance_to(mb.global_position) < 10.0
	var same_set: bool = same_spot and _last_click_surfaces == surfaces_here

	if same_set and surfaces_here.size() > 1:
		# Cycle to next surface underneath
		_last_click_index = (_last_click_index + 1) % surfaces_here.size()
	else:
		# New click location — select topmost
		_last_click_surfaces = surfaces_here
		_last_click_index = 0

	_last_click_pos = mb.global_position
	var target_id: String = surfaces_here[_last_click_index]
	SurfaceManager.select_surface(target_id)

	# Start drag on the selected surface if not locked
	var node: Control = surface_nodes.get(target_id)
	if node:
		var s := SurfaceManager.get_surface(target_id)
		if not s.is_empty() and not s["locked"]:
			node.start_drag(mb.global_position)


func _handle_right_click(mb: InputEventMouseButton) -> void:
	var surfaces_here := _get_surfaces_at_point(mb.global_position)
	_context_surface_ids = surfaces_here
	_build_context_menu_items(surfaces_here)
	_context_menu.position = Vector2i(mb.global_position)
	_context_menu.popup()


# ---------------------------------------------------------------------------
# Context menu
# ---------------------------------------------------------------------------

func _build_context_menu() -> void:
	_context_menu = PopupMenu.new()
	_context_menu.name = "ContextMenu"
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(_context_menu)


# Menu item IDs:
# 0-99: select surface by index in _context_surface_ids
# 100: separator (unused)
# 101: Lock/Unlock
# 102: Grid toggle
# 103: Move Forward
# 104: Move Backward
# 105: Add Corner
# 106: Remove Corner
# 107: Delete
# 200: Add Surface (void click)

func _build_context_menu_items(surfaces_here: Array[String]) -> void:
	_context_menu.clear()

	if surfaces_here.is_empty():
		_context_menu.add_item("+ Add Surface", 200)
		return

	# If multiple surfaces overlap, list them all as selectable
	if surfaces_here.size() > 1:
		for i in range(surfaces_here.size()):
			var s := SurfaceManager.get_surface(surfaces_here[i])
			var label: String = s.get("label", surfaces_here[i]) if not s.is_empty() else surfaces_here[i]
			var prefix := "● " if surfaces_here[i] == SurfaceManager.selected_surface_id else "  "
			_context_menu.add_item(prefix + label, i)
		_context_menu.add_separator()

	# Actions for the currently selected (or topmost) surface
	var target_id: String = SurfaceManager.selected_surface_id
	if target_id.is_empty() or target_id not in surfaces_here:
		target_id = surfaces_here[0]

	var s := SurfaceManager.get_surface(target_id)
	if s.is_empty():
		return

	var lock_text := "🔓 Unlock" if s["locked"] else "🔒 Lock"
	var grid_text := "▦ Grid Off" if s["grid_on"] else "▦ Grid On"

	_context_menu.add_item(lock_text, 101)
	_context_menu.add_item(grid_text, 102)
	_context_menu.add_separator()
	_context_menu.add_item("↑ Move Forward", 103)
	_context_menu.add_item("↓ Move Backward", 104)
	_context_menu.add_separator()
	_context_menu.add_item("+ Add Corner", 105)
	if s["corners"].size() > 3:
		_context_menu.add_item("- Remove Corner", 106)
	_context_menu.add_separator()
	_context_menu.add_item("🗑 Delete", 107)


func _on_context_menu_id_pressed(id: int) -> void:
	# Select surface by index (0-99)
	if id >= 0 and id < 100 and id < _context_surface_ids.size():
		SurfaceManager.select_surface(_context_surface_ids[id])
		return

	var target_id: String = SurfaceManager.selected_surface_id
	if target_id.is_empty() and not _context_surface_ids.is_empty():
		target_id = _context_surface_ids[0]

	match id:
		101:  # Lock/Unlock
			var s := SurfaceManager.get_surface(target_id)
			if not s.is_empty():
				SurfaceManager.update_surface_property(target_id, "locked", not s["locked"])
		102:  # Grid
			var s := SurfaceManager.get_surface(target_id)
			if not s.is_empty():
				SurfaceManager.update_surface_property(target_id, "grid_on", not s["grid_on"])
		103:  # Move Forward
			SurfaceManager.move_surface_forward(target_id)
		104:  # Move Backward
			SurfaceManager.move_surface_backward(target_id)
		105:  # Add Corner
			SurfaceManager.add_corner_to_surface(target_id)
		106:  # Remove Corner
			var s := SurfaceManager.get_surface(target_id)
			if not s.is_empty():
				SurfaceManager.remove_corner_from_surface(target_id, s["corners"].size() - 1)
		107:  # Delete
			SurfaceManager.remove_surface(target_id)
		200:  # Add Surface
			SurfaceManager.add_surface()


# ---------------------------------------------------------------------------
# Surface lifecycle
# ---------------------------------------------------------------------------

func _on_surface_added(id: String) -> void:
	var node: Control = surface_scene.instantiate()
	add_child(node)
	node.initialize(id, output_only)
	surface_nodes[id] = node
	node.set_selected(false)


func _on_surface_removed(id: String) -> void:
	if surface_nodes.has(id):
		var node: Control = surface_nodes[id]
		node.queue_free()
		surface_nodes.erase(id)


func _on_surface_updated(_id: String) -> void:
	pass


func _on_surface_selected(id: String) -> void:
	for sid in surface_nodes:
		var node: Control = surface_nodes[sid]
		node.set_selected(sid == id)


func select_corner_on_active_surface(corner_index: int) -> void:
	var sel_id := SurfaceManager.selected_surface_id
	if sel_id.is_empty() or not surface_nodes.has(sel_id):
		return
	var node: Control = surface_nodes[sel_id]
	if corner_index < node.corner_handles.size():
		for h in node.corner_handles:
			h.deselect()
		node.corner_handles[corner_index].select()


func get_surface_node(id: String) -> Control:
	return surface_nodes.get(id, null)
