extends Control
## CornerHandle — A draggable handle for one corner of a projection surface.
## Emits `corner_moved` when the user drags or nudges it.

signal corner_moved(corner_index: int, new_position: Vector2)

## Which corner this handle represents (0=TL, 1=TR, 2=BR, 3=BL)
@export var corner_index: int = 0

const HANDLE_RADIUS: float = 8.0
const HANDLE_OUTLINE: float = 2.0

var is_dragging: bool = false
var is_hovered: bool = false
var is_selected: bool = false
var drag_offset: Vector2 = Vector2.ZERO

# Colors
var color_normal := Color(1.0, 1.0, 1.0, 0.9)
var color_hovered := Color(1.0, 1.0, 0.0, 1.0)
var color_selected := Color(0.0, 1.0, 0.5, 1.0)
var color_outline := Color(0.0, 0.0, 0.0, 0.8)

const CORNER_LABELS := ["TL", "TR", "BR", "BL"]


func _ready() -> void:
	# The handle is a small control; we position its center at the corner
	custom_minimum_size = Vector2(HANDLE_RADIUS * 2 + 4, HANDLE_RADIUS * 2 + 4)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_MOVE


func set_corner_position(pos: Vector2) -> void:
	## Position the handle so its center aligns with the corner point.
	position = pos - size / 2.0


func get_corner_position() -> Vector2:
	return position + size / 2.0


func _draw() -> void:
	var center := size / 2.0
	var col: Color
	if is_selected:
		col = color_selected
	elif is_hovered:
		col = color_hovered
	else:
		col = color_normal

	# Outline
	draw_circle(center, HANDLE_RADIUS + HANDLE_OUTLINE, color_outline)
	# Fill
	draw_circle(center, HANDLE_RADIUS, col)

	# Corner label
	if is_selected or is_hovered:
		var label_text: String = CORNER_LABELS[corner_index] if corner_index < CORNER_LABELS.size() else "?"
		var font := ThemeDB.fallback_font
		var font_size := 11
		var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := center - text_size / 2.0 + Vector2(0, text_size.y * 0.35)
		draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click:
					# Double-click: select for keyboard nudging without dragging
					is_selected = true
					is_dragging = false
					grab_focus()
					queue_redraw()
					accept_event()
					return
				is_dragging = true
				is_selected = true
				drag_offset = get_corner_position() - mb.global_position
				grab_focus()
				queue_redraw()
				accept_event()
			else:
				is_dragging = false
				accept_event()

	elif event is InputEventMouseMotion and is_dragging:
		var mm := event as InputEventMouseMotion
		var new_pos: Vector2 = mm.global_position + drag_offset
		# Clamp to canvas bounds
		new_pos.x = clampf(new_pos.x, 0.0, 1920.0)
		new_pos.y = clampf(new_pos.y, 0.0, 1080.0)
		set_corner_position(new_pos)
		corner_moved.emit(corner_index, new_pos)
		accept_event()

	elif event is InputEventKey and event.pressed and is_selected:
		# Handle arrow keys here in _gui_input so they fire BEFORE
		# Godot's built-in focus navigation consumes them
		var key := event as InputEventKey
		var nudge := Vector2.ZERO
		var step: float = 10.0 if key.shift_pressed else 1.0

		match key.keycode:
			KEY_LEFT:
				nudge = Vector2(-step, 0)
			KEY_RIGHT:
				nudge = Vector2(step, 0)
			KEY_UP:
				nudge = Vector2(0, -step)
			KEY_DOWN:
				nudge = Vector2(0, step)
			_:
				return

		var new_pos := get_corner_position() + nudge
		new_pos.x = clampf(new_pos.x, 0.0, 1920.0)
		new_pos.y = clampf(new_pos.y, 0.0, 1080.0)
		set_corner_position(new_pos)
		corner_moved.emit(corner_index, new_pos)
		accept_event()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			is_hovered = true
			queue_redraw()
		NOTIFICATION_MOUSE_EXIT:
			is_hovered = false
			queue_redraw()
		NOTIFICATION_FOCUS_EXIT:
			is_selected = false
			queue_redraw()


func select() -> void:
	is_selected = true
	grab_focus()
	queue_redraw()


func deselect() -> void:
	is_selected = false
	queue_redraw()
