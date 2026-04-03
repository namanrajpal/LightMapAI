extends Control
## App — Main application controller.
## Manages mode toggling, global keyboard shortcuts, and top-level layout.
##
## Layout: Canvas is always full-window (1920×1080).
## UI (toolbar, sidebar, status bar) overlays on top via UILayer.
## In Output Mode, UILayer hides — canvas stays in place.

@onready var ui_layer: VBoxContainer = %UILayer
@onready var projection_canvas: Control = %ProjectionCanvas
@onready var canvas_bg: ColorRect = %CanvasBG

var _pre_output_window_mode: DisplayServer.WindowMode

func _ready() -> void:
	# Try loading default config on first launch
	SurfaceManager.load_default_config()

	# If no surfaces loaded, add one
	if SurfaceManager.surfaces.is_empty():
		SurfaceManager.add_surface()

	# Connect mode signal
	SurfaceManager.mode_changed.connect(_on_mode_changed)

	# Select the first surface
	if not SurfaceManager.surfaces.is_empty():
		SurfaceManager.select_surface(SurfaceManager.surfaces[0]["id"])


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey

		# Mode toggles
		if key.keycode == KEY_F11 or key.keycode == KEY_TAB:
			SurfaceManager.toggle_output_mode()
			get_viewport().set_input_as_handled()
			return

		if key.keycode == KEY_ESCAPE and SurfaceManager.is_output_mode:
			SurfaceManager.set_output_mode(false)
			get_viewport().set_input_as_handled()
			return

		# Global shortcuts with Ctrl
		if key.ctrl_pressed:
			match key.keycode:
				KEY_S:
					SurfaceManager.quick_save()
					get_viewport().set_input_as_handled()
				KEY_O:
					SurfaceManager.quick_load()
					get_viewport().set_input_as_handled()
				KEY_N:
					SurfaceManager.add_surface()
					get_viewport().set_input_as_handled()
			return

		# Shortcuts when a surface is selected (no Ctrl)
		var sel_id := SurfaceManager.selected_surface_id
		if sel_id.is_empty():
			return

		match key.keycode:
			KEY_DELETE:
				SurfaceManager.remove_surface(sel_id)
				get_viewport().set_input_as_handled()
			KEY_G:
				var s := SurfaceManager.get_surface(sel_id)
				if not s.is_empty():
					SurfaceManager.update_surface_property(sel_id, "grid_on", !s["grid_on"])
				get_viewport().set_input_as_handled()
			KEY_L:
				var s := SurfaceManager.get_surface(sel_id)
				if not s.is_empty():
					SurfaceManager.update_surface_property(sel_id, "locked", !s["locked"])
				get_viewport().set_input_as_handled()
			KEY_BRACKETRIGHT:
				SurfaceManager.move_surface_forward(sel_id)
				get_viewport().set_input_as_handled()
			KEY_BRACKETLEFT:
				SurfaceManager.move_surface_backward(sel_id)
				get_viewport().set_input_as_handled()
			KEY_1:
				_select_corner(0)
				get_viewport().set_input_as_handled()
			KEY_2:
				_select_corner(1)
				get_viewport().set_input_as_handled()
			KEY_3:
				_select_corner(2)
				get_viewport().set_input_as_handled()
			KEY_4:
				_select_corner(3)
				get_viewport().set_input_as_handled()


func _select_corner(index: int) -> void:
	if projection_canvas:
		projection_canvas.select_corner_on_active_surface(index)


func _on_mode_changed(is_output: bool) -> void:
	# Simply hide/show the entire UI overlay — canvas stays in place
	ui_layer.visible = !is_output

	if is_output:
		# Remember current window mode before going fullscreen
		_pre_output_window_mode = DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		# Restore whatever window mode we had before output mode
		DisplayServer.window_set_mode(_pre_output_window_mode)
