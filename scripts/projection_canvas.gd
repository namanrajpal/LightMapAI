extends Control
## ProjectionCanvas — Manages surface instances on the canvas.
## Listens to SurfaceManager signals to add/remove/reorder surfaces.

var surface_scene: PackedScene = preload("res://scenes/projection_surface.tscn")
var surface_nodes: Dictionary = {}  # id -> ProjectionSurface node


func _ready() -> void:
	add_to_group("projection_canvas")
	SurfaceManager.surface_added.connect(_on_surface_added)
	SurfaceManager.surface_removed.connect(_on_surface_removed)
	SurfaceManager.surface_selected.connect(_on_surface_selected)


func _input(event: InputEvent) -> void:
	if SurfaceManager.is_output_mode:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# Ignore clicks on the left 250px (sidebar area) and top 40px (toolbar)
			if mb.global_position.x < 260 or mb.global_position.y < 45:
				return
			# Check if click is inside any surface
			for sid in surface_nodes:
				var node: Control = surface_nodes[sid]
				if node._point_in_quad(mb.global_position):
					return  # Click is on a surface, let the surface handle it
			# Click is on void — deselect everything
			SurfaceManager.select_surface("")


func _on_surface_added(id: String) -> void:
	var node: Control = surface_scene.instantiate()
	add_child(node)
	node.initialize(id)
	surface_nodes[id] = node

	# Initially hide handles (will show when selected)
	node.set_selected(false)


func _on_surface_removed(id: String) -> void:
	if surface_nodes.has(id):
		var node: Control = surface_nodes[id]
		node.queue_free()
		surface_nodes.erase(id)


func _on_surface_selected(id: String) -> void:
	# Update selection visuals on all surfaces
	for sid in surface_nodes:
		var node: Control = surface_nodes[sid]
		node.set_selected(sid == id)


func select_corner_on_active_surface(corner_index: int) -> void:
	## Called from app.gd when user presses 1-4 to select a specific corner.
	var sel_id := SurfaceManager.selected_surface_id
	if sel_id.is_empty() or not surface_nodes.has(sel_id):
		return
	var node: Control = surface_nodes[sel_id]
	if corner_index < node.corner_handles.size():
		# Deselect all other handles first
		for h in node.corner_handles:
			h.deselect()
		node.corner_handles[corner_index].select()


func get_surface_node(id: String) -> Control:
	return surface_nodes.get(id, null)
