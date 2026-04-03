extends HBoxContainer
## Toolbar — Top bar with Add Surface, Test Pattern, Grid, Save, Load, Output Mode.

@onready var add_btn: Button = %ToolbarAddBtn
@onready var pattern_btn: OptionButton = %PatternBtn
@onready var grid_btn: CheckButton = %ToolbarGridBtn
@onready var save_btn: Button = %SaveBtn
@onready var load_btn: Button = %LoadBtn
@onready var output_btn: Button = %OutputBtn

# Test pattern textures (loaded on ready)
var test_patterns: Dictionary = {}


func _ready() -> void:
	# Connect buttons
	if add_btn:
		add_btn.pressed.connect(_on_add_pressed)
	if save_btn:
		save_btn.pressed.connect(_on_save_pressed)
	if load_btn:
		load_btn.pressed.connect(_on_load_pressed)
	if output_btn:
		output_btn.pressed.connect(_on_output_pressed)
	if grid_btn:
		grid_btn.toggled.connect(_on_grid_toggled)
	if pattern_btn:
		_setup_pattern_dropdown()
		pattern_btn.item_selected.connect(_on_pattern_selected)

	# Update grid button when surface selection changes
	SurfaceManager.surface_selected.connect(_on_surface_selected)
	SurfaceManager.surface_updated.connect(_on_surface_updated)


func _setup_pattern_dropdown() -> void:
	pattern_btn.clear()
	pattern_btn.add_item("None", 0)
	pattern_btn.add_item("Checkerboard", 1)
	pattern_btn.add_item("Color Bars", 2)
	pattern_btn.add_item("Crosshair", 3)
	pattern_btn.add_item("White Flood", 4)


func _on_add_pressed() -> void:
	SurfaceManager.add_surface()


func _on_save_pressed() -> void:
	SurfaceManager.quick_save()


func _on_load_pressed() -> void:
	SurfaceManager.quick_load()


func _on_output_pressed() -> void:
	SurfaceManager.set_output_mode(true)


func _on_grid_toggled(pressed: bool) -> void:
	var sel_id := SurfaceManager.selected_surface_id
	if sel_id.is_empty():
		return
	SurfaceManager.update_surface_property(sel_id, "grid_on", pressed)


func _on_pattern_selected(index: int) -> void:
	var sel_id := SurfaceManager.selected_surface_id
	if sel_id.is_empty():
		return

	# Get the projection canvas to find the surface node
	var canvas := get_tree().get_first_node_in_group("projection_canvas")
	if not canvas:
		# Fallback: walk up tree to find it
		return

	var surface_node: Control = canvas.get_surface_node(sel_id)
	if not surface_node:
		return

	match index:
		0:  # None
			surface_node.set_test_pattern(null)
		1:  # Checkerboard
			var tex := _load_or_generate_pattern("checkerboard")
			surface_node.set_test_pattern(tex)
		2:  # Color Bars
			var tex := _load_or_generate_pattern("color_bars")
			surface_node.set_test_pattern(tex)
		3:  # Crosshair
			var tex := _load_or_generate_pattern("crosshair")
			surface_node.set_test_pattern(tex)
		4:  # White Flood
			var tex := _generate_solid_white()
			surface_node.set_test_pattern(tex)


func _load_or_generate_pattern(pattern_name: String) -> Texture2D:
	if test_patterns.has(pattern_name):
		return test_patterns[pattern_name]

	var path := "res://resources/test_patterns/%s.png" % pattern_name
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		test_patterns[pattern_name] = tex
		return tex

	# Generate procedurally as fallback
	match pattern_name:
		"checkerboard":
			return _generate_checkerboard()
		"color_bars":
			return _generate_color_bars()
		"crosshair":
			return _generate_crosshair()

	return _generate_checkerboard()


func _generate_checkerboard() -> ImageTexture:
	var img := Image.create(512, 512, false, Image.FORMAT_RGB8)
	var tile_size := 32
	for y in range(512):
		for x in range(512):
			var is_white: bool = ((x / tile_size) + (y / tile_size)) % 2 == 0
			img.set_pixel(x, y, Color.WHITE if is_white else Color.BLACK)
	var tex := ImageTexture.create_from_image(img)
	test_patterns["checkerboard"] = tex
	return tex


func _generate_color_bars() -> ImageTexture:
	var img := Image.create(512, 512, false, Image.FORMAT_RGB8)
	var colors: Array[Color] = [
		Color.WHITE, Color.YELLOW, Color.CYAN, Color.GREEN,
		Color.MAGENTA, Color.RED, Color.BLUE, Color.BLACK,
	]
	var bar_width := 512.0 / colors.size()
	for y in range(512):
		for x in range(512):
			var idx := int(x / bar_width)
			idx = clampi(idx, 0, colors.size() - 1)
			img.set_pixel(x, y, colors[idx])
	var tex := ImageTexture.create_from_image(img)
	test_patterns["color_bars"] = tex
	return tex


func _generate_crosshair() -> ImageTexture:
	var img := Image.create(512, 512, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	var line_color := Color.WHITE
	# Horizontal center line
	for x in range(512):
		img.set_pixel(x, 255, line_color)
		img.set_pixel(x, 256, line_color)
	# Vertical center line
	for y in range(512):
		img.set_pixel(255, y, line_color)
		img.set_pixel(256, y, line_color)
	# Quarter lines (thinner)
	for x in range(512):
		img.set_pixel(x, 128, Color(1, 1, 1, 0.5))
		img.set_pixel(x, 384, Color(1, 1, 1, 0.5))
	for y in range(512):
		img.set_pixel(128, y, Color(1, 1, 1, 0.5))
		img.set_pixel(384, y, Color(1, 1, 1, 0.5))
	var tex := ImageTexture.create_from_image(img)
	test_patterns["crosshair"] = tex
	return tex


func _generate_solid_white() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	return tex


func _on_surface_selected(_id: String) -> void:
	_sync_grid_button()


func _on_surface_updated(id: String) -> void:
	if id == SurfaceManager.selected_surface_id:
		_sync_grid_button()


func _sync_grid_button() -> void:
	if not grid_btn:
		return
	var s := SurfaceManager.get_selected_surface()
	if s.is_empty():
		grid_btn.set_pressed_no_signal(false)
	else:
		grid_btn.set_pressed_no_signal(s["grid_on"])
