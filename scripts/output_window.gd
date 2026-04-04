class_name OutputWindow
extends Window
## OutputWindow — A secondary window that renders projection surfaces
## fullscreen on a chosen display, with no UI chrome.

signal output_window_closed()

var output_canvas: Control  # ProjectionCanvas instance

func _ready() -> void:
	# Configure window properties
	borderless = true
	unresizable = true
	size = Vector2i(1920, 1080)
	title = "Output"

	# Connect close_requested for OS-level close (X button / Alt+F4)
	close_requested.connect(_on_close_requested)

	# Add black background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Instantiate ProjectionCanvas in output-only mode
	# Set output_only BEFORE add_child so _ready() skips normal signal connections
	var canvas_script := preload("res://scripts/projection_canvas.gd")
	output_canvas = Control.new()
	output_canvas.name = "OutputCanvas"
	output_canvas.set_script(canvas_script)
	output_canvas.output_only = true
	output_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(output_canvas)
	output_canvas.initialize_output_mode()


func open_on_display(display_index: int) -> void:
	var target_pos := DisplayServer.screen_get_position(display_index)
	var target_size := DisplayServer.screen_get_size(display_index)
	position = target_pos
	size = target_size
	show()

	# Only go fullscreen if opening on a different display than the main window.
	# On a single display, stay windowed so the operator can see both windows.
	var main_window_screen := DisplayServer.window_get_current_screen()
	if display_index != main_window_screen:
		mode = Window.MODE_FULLSCREEN
	else:
		# Same display — open large but not fullscreen so it's clearly a second window
		borderless = false
		unresizable = false


func _on_close_requested() -> void:
	output_window_closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_close_requested()
			get_viewport().set_input_as_handled()
