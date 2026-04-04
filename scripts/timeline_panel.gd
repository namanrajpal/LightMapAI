extends VBoxContainer
## TimelinePanel — Bottom dock UI for animation timeline.
## Transport bar + a single custom-draw track area (no dynamic child nodes).
## All track rows, keyframe diamonds, and the playhead are painted in _draw()
## on one Control, eliminating the node lifecycle bugs entirely.

# ---------------------------------------------------------------------------
# References
# ---------------------------------------------------------------------------
var transport_bar: HBoxContainer
var play_pause_btn: Button
var stop_btn: Button
var step_back_btn: Button
var step_fwd_btn: Button
var time_label: Label
var loop_toggle: Button
var speed_selector: OptionButton
var scene_selector: OptionButton
var new_scene_btn: Button
var collapse_btn: Button

var track_area: ScrollContainer
var track_canvas: Control  # single custom-draw surface for all tracks

var new_scene_dialog: ConfirmationDialog
var new_scene_name_input: LineEdit
var new_scene_duration_input: SpinBox

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var _is_collapsed: bool = false
const TRANSPORT_HEIGHT := 40
const ROW_HEIGHT := 26
const LABEL_WIDTH := 160
const DIAMOND_SIZE := 5.0

# Which surfaces are expanded to show property sub-tracks
var _expanded_surfaces: Dictionary = {}  # surface_id -> bool

# Keyframe edit popup
var _edit_popup: PopupPanel
var _edit_vbox: VBoxContainer
var _edit_surface_id: String = ""
var _edit_property: String = ""
var _edit_time: float = 0.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	custom_minimum_size.y = 200
	size_flags_vertical = Control.SIZE_SHRINK_END

	_build_transport_bar()
	_build_track_area()
	_build_new_scene_dialog()
	_connect_signals()
	_refresh_scene_selector()


# ---------------------------------------------------------------------------
# Build UI
# ---------------------------------------------------------------------------

func _build_transport_bar() -> void:
	transport_bar = HBoxContainer.new()
	transport_bar.name = "TransportBar"
	transport_bar.custom_minimum_size.y = TRANSPORT_HEIGHT
	add_child(transport_bar)

	play_pause_btn = _add_btn(transport_bar, "▶", "Play / Pause")
	stop_btn = _add_btn(transport_bar, "■", "Stop")
	step_back_btn = _add_btn(transport_bar, "⏪", "Step Back")
	step_fwd_btn = _add_btn(transport_bar, "⏩", "Step Forward")

	time_label = Label.new()
	time_label.text = "00:00.00"
	time_label.custom_minimum_size = Vector2(80, 0)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	transport_bar.add_child(time_label)

	loop_toggle = Button.new()
	loop_toggle.text = "🔁"
	loop_toggle.tooltip_text = "Loop"
	loop_toggle.toggle_mode = true
	loop_toggle.custom_minimum_size = Vector2(40, 0)
	transport_bar.add_child(loop_toggle)

	speed_selector = OptionButton.new()
	speed_selector.tooltip_text = "Speed"
	speed_selector.custom_minimum_size = Vector2(80, 0)
	var default_idx := -1
	for i in range(40):
		var v := (i + 1) * 0.1
		speed_selector.add_item("%.1fx" % v)
		if absf(v - 1.0) < 0.01:
			default_idx = i
	if default_idx >= 0:
		speed_selector.selected = default_idx
	transport_bar.add_child(speed_selector)

	scene_selector = OptionButton.new()
	scene_selector.tooltip_text = "Scene"
	scene_selector.custom_minimum_size = Vector2(120, 0)
	scene_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transport_bar.add_child(scene_selector)

	new_scene_btn = _add_btn(transport_bar, "+", "New Scene")
	collapse_btn = _add_btn(transport_bar, "▼", "Collapse")


func _add_btn(parent: Control, label: String, tip: String) -> Button:
	var b := Button.new()
	b.text = label
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(40, 0)
	parent.add_child(b)
	return b


func _build_track_area() -> void:
	track_area = ScrollContainer.new()
	track_area.name = "TrackArea"
	track_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(track_area)

	track_canvas = Control.new()
	track_canvas.name = "TrackCanvas"
	track_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	track_area.add_child(track_canvas)

	track_canvas.draw.connect(_on_track_canvas_draw)
	track_canvas.gui_input.connect(_on_track_canvas_input)


func _build_new_scene_dialog() -> void:
	new_scene_dialog = ConfirmationDialog.new()
	new_scene_dialog.title = "New Animation Scene"
	new_scene_dialog.ok_button_text = "Create"
	new_scene_dialog.size = Vector2i(350, 150)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	new_scene_dialog.add_child(vb)

	var nr := HBoxContainer.new()
	vb.add_child(nr)
	var nl := Label.new()
	nl.text = "Name:"
	nl.custom_minimum_size.x = 70
	nr.add_child(nl)
	new_scene_name_input = LineEdit.new()
	new_scene_name_input.placeholder_text = "Scene 1"
	new_scene_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nr.add_child(new_scene_name_input)

	var dr := HBoxContainer.new()
	vb.add_child(dr)
	var dl := Label.new()
	dl.text = "Duration:"
	dl.custom_minimum_size.x = 70
	dr.add_child(dl)
	new_scene_duration_input = SpinBox.new()
	new_scene_duration_input.min_value = 0.1
	new_scene_duration_input.max_value = 600.0
	new_scene_duration_input.step = 0.1
	new_scene_duration_input.value = 10.0
	new_scene_duration_input.suffix = "s"
	new_scene_duration_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dr.add_child(new_scene_duration_input)

	new_scene_dialog.confirmed.connect(_on_new_scene_confirmed)
	add_child(new_scene_dialog)

	_build_edit_popup()


func _build_edit_popup() -> void:
	_edit_popup = PopupPanel.new()
	_edit_popup.name = "EditPopup"
	_edit_popup.size = Vector2i(220, 80)
	_edit_vbox = VBoxContainer.new()
	_edit_vbox.add_theme_constant_override("separation", 4)
	_edit_popup.add_child(_edit_vbox)
	add_child(_edit_popup)


# ---------------------------------------------------------------------------
# Signal wiring
# ---------------------------------------------------------------------------

func _connect_signals() -> void:
	play_pause_btn.pressed.connect(func(): 
		if TimelineManager.is_playing(): TimelineManager.pause()
		else: TimelineManager.play())
	stop_btn.pressed.connect(TimelineManager.stop)
	step_back_btn.pressed.connect(TimelineManager.step_backward)
	step_fwd_btn.pressed.connect(TimelineManager.step_forward)
	loop_toggle.toggled.connect(func(p: bool):
		var sn := TimelineManager.get_active_scene_name()
		if not sn.is_empty(): TimelineManager.set_scene_loop_mode(sn, p))
	speed_selector.item_selected.connect(func(i: int):
		TimelineManager.set_speed((i + 1) * 0.1))
	scene_selector.item_selected.connect(func(i: int):
		TimelineManager.set_active_scene(scene_selector.get_item_text(i)))
	new_scene_btn.pressed.connect(func():
		new_scene_name_input.text = ""
		new_scene_duration_input.value = 10.0
		new_scene_dialog.popup_centered())
	collapse_btn.pressed.connect(_toggle_collapse)

	# TimelineManager signals → just redraw the canvas
	TimelineManager.playback_state_changed.connect(func(playing: bool):
		play_pause_btn.text = "⏸" if playing else "▶"
		track_canvas.queue_redraw())
	TimelineManager.playhead_moved.connect(func(t: float):
		_update_time_label(t)
		track_canvas.queue_redraw())
	TimelineManager.animation_scene_changed.connect(func(_n: String):
		_refresh_scene_selector()
		_refresh_loop_toggle()
		# Auto-expand all surfaces when a scene becomes active
		for s in SurfaceManager.surfaces:
			_expanded_surfaces[s["id"]] = true
		track_canvas.queue_redraw())
	TimelineManager.animation_list_changed.connect(_refresh_scene_selector)
	TimelineManager.track_changed.connect(func(_sid: String, _prop: String):
		track_canvas.queue_redraw())

	# Surface changes → redraw
	SurfaceManager.surface_added.connect(func(_id: String): track_canvas.queue_redraw())
	SurfaceManager.surface_removed.connect(func(_id: String): track_canvas.queue_redraw())


func _on_new_scene_confirmed() -> void:
	var sn: String = new_scene_name_input.text.strip_edges()
	if sn.is_empty():
		sn = "Scene %d" % (TimelineManager.get_scene_names().size() + 1)
	TimelineManager.create_scene(sn, new_scene_duration_input.value)
	TimelineManager.set_active_scene(sn)


func _toggle_collapse() -> void:
	_is_collapsed = not _is_collapsed
	track_area.visible = not _is_collapsed
	custom_minimum_size.y = TRANSPORT_HEIGHT if _is_collapsed else 200
	collapse_btn.text = "▲" if _is_collapsed else "▼"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _refresh_scene_selector() -> void:
	scene_selector.clear()
	var names := TimelineManager.get_scene_names()
	var active := TimelineManager.get_active_scene_name()
	var sel := -1
	for i in range(names.size()):
		scene_selector.add_item(names[i])
		if names[i] == active:
			sel = i
	if sel >= 0:
		scene_selector.selected = sel


func _refresh_loop_toggle() -> void:
	var sn := TimelineManager.get_active_scene_name()
	if sn.is_empty():
		loop_toggle.set_pressed_no_signal(false)
		return
	loop_toggle.set_pressed_no_signal(TimelineManager.get_scene_loop_mode(sn))


func _update_time_label(time: float) -> void:
	var t := maxf(time, 0.0)
	time_label.text = "%02d:%02d.%02d" % [int(t) / 60, int(t) % 60, int((t - floorf(t)) * 100.0)]


# ---------------------------------------------------------------------------
# Build the list of visible rows (computed each draw, no node management)
# ---------------------------------------------------------------------------

## Returns Array of Dictionaries: { "type": "surface"|"property", "surface_id", "label", "property"?, "armed"?, "dimmed"? }
func _get_visible_rows() -> Array:
	var rows: Array = []
	for s in SurfaceManager.surfaces:
		var sid: String = s["id"]
		rows.append({"type": "surface", "surface_id": sid, "label": s.get("label", sid)})
		if _expanded_surfaces.get(sid, false):
			var visible_tracks := TimelineManager.get_visible_tracks(sid)
			for prop in visible_tracks:
				var armed := TimelineManager.is_track_armed(sid, prop)
				var has_keys := TimelineManager.get_keyframes(sid, prop).size() > 0
				rows.append({
					"type": "property",
					"surface_id": sid,
					"property": prop,
					"label": "  " + prop,
					"armed": armed,
					"dimmed": not armed and has_keys,
				})
	return rows


# ---------------------------------------------------------------------------
# Custom draw — the entire track area is painted here, zero child nodes
# ---------------------------------------------------------------------------

func _on_track_canvas_draw() -> void:
	var canvas := track_canvas
	var rows := _get_visible_rows()
	var total_h := maxi(rows.size() * ROW_HEIGHT, int(track_area.size.y))
	canvas.custom_minimum_size.y = total_h

	var w := canvas.size.x
	var strip_x := LABEL_WIDTH  # where the keyframe strip starts
	var strip_w := maxf(w - LABEL_WIDTH, 100.0)
	var duration := TimelineManager.get_duration()

	# Background
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(w, total_h)), Color(0.12, 0.12, 0.14))

	if rows.is_empty():
		# Empty state
		var font := ThemeDB.fallback_font
		var msg := "Press + to create an animation scene" if TimelineManager.get_active_scene_name().is_empty() else "No surfaces"
		canvas.draw_string(font, Vector2(20, 30), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.5, 0.5))
		return

	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var y := i * ROW_HEIGHT
		var is_surface: bool = (row["type"] == "surface")

		# Alternating row background
		var bg_color := Color(0.16, 0.16, 0.19) if i % 2 == 0 else Color(0.14, 0.14, 0.17)
		if is_surface:
			bg_color = Color(0.2, 0.2, 0.24)
		canvas.draw_rect(Rect2(Vector2(0, y), Vector2(w, ROW_HEIGHT)), bg_color)

		# Row separator line
		canvas.draw_line(Vector2(0, y + ROW_HEIGHT), Vector2(w, y + ROW_HEIGHT), Color(0.25, 0.25, 0.28))

		# Label
		var font := ThemeDB.fallback_font
		var font_size := 13
		var text_color := Color(0.85, 0.85, 0.85)
		if not is_surface and row.get("dimmed", false):
			text_color = Color(0.5, 0.5, 0.5)

		var label_text: String = row["label"]
		if is_surface:
			var arrow := "▼ " if _expanded_surfaces.get(row["surface_id"], false) else "▶ "
			label_text = arrow + label_text

		canvas.draw_string(font, Vector2(8, y + ROW_HEIGHT - 8), label_text, HORIZONTAL_ALIGNMENT_LEFT, LABEL_WIDTH - 12, font_size, text_color)

		# Strip background
		canvas.draw_rect(Rect2(Vector2(strip_x, y + 1), Vector2(strip_w, ROW_HEIGHT - 2)), Color(0.1, 0.1, 0.12))

		# Keyframe diamonds (only for property rows with a valid property)
		if not is_surface and duration > 0.0:
			var sid: String = row["surface_id"]
			var prop: String = row["property"]
			var keyframes := TimelineManager.get_keyframes(sid, prop)
			var diamond_color := Color(1.0, 0.8, 0.2) if row.get("armed", true) else Color(0.6, 0.5, 0.2)
			for kf in keyframes:
				var kx: float = strip_x + (kf["time"] / duration) * strip_w
				var ky: float = y + ROW_HEIGHT / 2.0
				var pts := PackedVector2Array([
					Vector2(kx, ky - DIAMOND_SIZE),
					Vector2(kx + DIAMOND_SIZE, ky),
					Vector2(kx, ky + DIAMOND_SIZE),
					Vector2(kx - DIAMOND_SIZE, ky),
				])
				canvas.draw_colored_polygon(pts, diamond_color)

	# Playhead line (spans full height)
	if duration > 0.0:
		var ph_time := TimelineManager.get_playhead_time()
		var ph_x := strip_x + (ph_time / duration) * strip_w
		canvas.draw_line(Vector2(ph_x, 0), Vector2(ph_x, total_h), Color(1.0, 0.3, 0.3), 2.0)


# ---------------------------------------------------------------------------
# Input on the track canvas
# ---------------------------------------------------------------------------

func _on_track_canvas_input(event: InputEvent) -> void:
	var rows := _get_visible_rows()
	if rows.is_empty():
		return

	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return

	var row_idx := int(event.position.y) / ROW_HEIGHT
	var on_strip: bool = event.position.x >= LABEL_WIDTH

	# --- Mouse button events ---
	if event is InputEventMouseButton and event.pressed:
		if row_idx < 0 or row_idx >= rows.size():
			return
		var row: Dictionary = rows[row_idx]

		# LEFT CLICK
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Double-click on a property strip → add keyframe at that time
			if event.double_click and on_strip and row["type"] == "property":
				var time := _mouse_x_to_time(event.position.x)
				if time >= 0.0:
					var value: Variant = _get_current_property_value(row["surface_id"], row["property"])
					TimelineManager.add_keyframe(row["surface_id"], row["property"], time, value)
					track_canvas.queue_redraw()
					get_viewport().set_input_as_handled()
					return

			# Single click on label area → toggle expand for surface rows
			if not on_strip and row["type"] == "surface":
				var sid: String = row["surface_id"]
				_expanded_surfaces[sid] = not _expanded_surfaces.get(sid, false)
				track_canvas.queue_redraw()
				get_viewport().set_input_as_handled()
				return

			# Single click on strip area → seek playhead
			if on_strip:
				_seek_from_mouse(event.position.x)
				get_viewport().set_input_as_handled()
				return

		# RIGHT CLICK on a property strip → context: edit or delete nearest keyframe
		if event.button_index == MOUSE_BUTTON_RIGHT and on_strip and row["type"] == "property":
			var time := _mouse_x_to_time(event.position.x)
			if time >= 0.0:
				var nearest := _find_nearest_keyframe(row["surface_id"], row["property"], time)
				if nearest >= 0.0:
					_show_keyframe_edit_popup(row["surface_id"], row["property"], nearest, track_canvas.get_global_transform() * event.position)
					get_viewport().set_input_as_handled()
					return

	# --- Mouse drag (left button held) → seek ---
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if on_strip:
			_seek_from_mouse(event.position.x)
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Input helpers
# ---------------------------------------------------------------------------

func _mouse_x_to_time(mouse_x: float) -> float:
	var duration := TimelineManager.get_duration()
	if duration <= 0.0:
		return -1.0
	var strip_w := maxf(track_canvas.size.x - LABEL_WIDTH, 100.0)
	return clampf((mouse_x - LABEL_WIDTH) / strip_w * duration, 0.0, duration)


func _seek_from_mouse(mouse_x: float) -> void:
	var t := _mouse_x_to_time(mouse_x)
	if t >= 0.0:
		TimelineManager.seek(t)


## Find the nearest keyframe within click tolerance (10px). Returns time or -1.
func _find_nearest_keyframe(surface_id: String, property: String, click_time: float) -> float:
	var keyframes := TimelineManager.get_keyframes(surface_id, property)
	if keyframes.is_empty():
		return -1.0
	var duration := TimelineManager.get_duration()
	if duration <= 0.0:
		return -1.0
	var strip_w := maxf(track_canvas.size.x - LABEL_WIDTH, 100.0)
	var tolerance_time := (10.0 / strip_w) * duration  # 10px tolerance

	var best_time := -1.0
	var best_dist := tolerance_time
	for kf in keyframes:
		var dist := absf(kf["time"] - click_time)
		if dist < best_dist:
			best_dist = dist
			best_time = kf["time"]
	return best_time


## Get the current value of a surface property (for inserting keyframes).
func _get_current_property_value(surface_id: String, property: String) -> Variant:
	var proxy := TimelineManager.get_proxy(surface_id)
	if proxy == null:
		return null
	match property:
		"opacity": return proxy.opacity
		"color": return proxy.color
		"visible_prop": return proxy.visible_prop
		"z_index_prop": return proxy.z_index_prop
		"corner_tl": return proxy.corner_tl
		"corner_tr": return proxy.corner_tr
		"corner_br": return proxy.corner_br
		"corner_bl": return proxy.corner_bl
		"fit_mode": return proxy.fit_mode
	return null


# ---------------------------------------------------------------------------
# Keyframe value editor popup
# ---------------------------------------------------------------------------

func _show_keyframe_edit_popup(surface_id: String, property: String, time: float, global_pos: Vector2) -> void:
	_edit_surface_id = surface_id
	_edit_property = property
	_edit_time = time

	# Clear previous editor contents
	for child in _edit_vbox.get_children():
		_edit_vbox.remove_child(child)
		child.free()

	# Get current keyframe value
	var keyframes := TimelineManager.get_keyframes(surface_id, property)
	var current_value: Variant = null
	for kf in keyframes:
		if absf(kf["time"] - time) < 0.001:
			current_value = kf["value"]
			break

	# Header label
	var header := Label.new()
	header.text = "%s @ %.2fs" % [property, time]
	header.add_theme_font_size_override("font_size", 12)
	_edit_vbox.add_child(header)

	# Build appropriate editor based on property type
	match property:
		"opacity":
			var slider := HSlider.new()
			slider.min_value = 0.0
			slider.max_value = 1.0
			slider.step = 0.01
			slider.value = current_value if current_value is float else 1.0
			slider.custom_minimum_size = Vector2(180, 20)
			slider.value_changed.connect(func(v: float): _apply_keyframe_value(v))
			_edit_vbox.add_child(slider)

		"color":
			var picker := ColorPickerButton.new()
			picker.color = current_value if current_value is Color else Color.WHITE
			picker.custom_minimum_size = Vector2(180, 30)
			picker.color_changed.connect(func(c: Color): _apply_keyframe_value(c))
			_edit_vbox.add_child(picker)

		"visible_prop":
			var check := CheckButton.new()
			check.text = "Visible"
			check.button_pressed = current_value if current_value is bool else true
			check.toggled.connect(func(v: bool): _apply_keyframe_value(v))
			_edit_vbox.add_child(check)

		"z_index_prop":
			var spin := SpinBox.new()
			spin.min_value = -100
			spin.max_value = 100
			spin.value = current_value if current_value is int or current_value is float else 0
			spin.value_changed.connect(func(v: float): _apply_keyframe_value(int(v)))
			_edit_vbox.add_child(spin)

		"corner_tl", "corner_tr", "corner_br", "corner_bl":
			var vec: Vector2 = current_value if current_value is Vector2 else Vector2.ZERO
			var hb := HBoxContainer.new()
			_edit_vbox.add_child(hb)
			var sx := SpinBox.new()
			sx.prefix = "x:"
			sx.min_value = -9999
			sx.max_value = 9999
			sx.value = vec.x
			sx.custom_minimum_size.x = 90
			hb.add_child(sx)
			var sy := SpinBox.new()
			sy.prefix = "y:"
			sy.min_value = -9999
			sy.max_value = 9999
			sy.value = vec.y
			sy.custom_minimum_size.x = 90
			hb.add_child(sy)
			sx.value_changed.connect(func(v: float): _apply_keyframe_value(Vector2(v, sy.value)))
			sy.value_changed.connect(func(v: float): _apply_keyframe_value(Vector2(sx.value, v)))

		"fit_mode":
			var opt := OptionButton.new()
			opt.add_item("stretch")
			opt.add_item("fit")
			opt.add_item("fill")
			var cur: String = current_value if current_value is String else "stretch"
			for j in range(opt.item_count):
				if opt.get_item_text(j) == cur:
					opt.selected = j
			opt.item_selected.connect(func(i: int): _apply_keyframe_value(opt.get_item_text(i)))
			_edit_vbox.add_child(opt)

	# Delete button
	var del_btn := Button.new()
	del_btn.text = "🗑 Delete Keyframe"
	del_btn.pressed.connect(func():
		TimelineManager.remove_keyframe(_edit_surface_id, _edit_property, _edit_time)
		_edit_popup.hide()
		track_canvas.queue_redraw())
	_edit_vbox.add_child(del_btn)

	_edit_popup.popup(Rect2i(Vector2i(global_pos), _edit_popup.size))


func _apply_keyframe_value(value: Variant) -> void:
	TimelineManager.update_keyframe_value(_edit_surface_id, _edit_property, _edit_time, value)
	track_canvas.queue_redraw()
