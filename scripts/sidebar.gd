extends PanelContainer
## Sidebar — Displays a list of surface cards with editable properties.

@onready var surface_list: VBoxContainer = %SurfaceList
@onready var add_button: Button = %SidebarAddButton

var surface_cards: Dictionary = {}  # id -> card HBoxContainer


func _ready() -> void:
	SurfaceManager.surface_added.connect(_on_surface_added)
	SurfaceManager.surface_removed.connect(_on_surface_removed)
	SurfaceManager.surface_selected.connect(_on_surface_selected)
	SurfaceManager.surface_updated.connect(_on_surface_updated)

	if add_button:
		add_button.pressed.connect(_on_add_pressed)


func _on_add_pressed() -> void:
	SurfaceManager.add_surface()


func _on_surface_added(id: String) -> void:
	var s := SurfaceManager.get_surface(id)
	if s.is_empty():
		return
	_create_surface_card(id, s)


func _on_surface_removed(id: String) -> void:
	if surface_cards.has(id):
		surface_cards[id].queue_free()
		surface_cards.erase(id)


func _on_surface_selected(id: String) -> void:
	for sid in surface_cards:
		var card: PanelContainer = surface_cards[sid]
		var is_selected: bool = (sid == id)
		_update_card_highlight(card, is_selected)
		# Expand/collapse details
		var details := card.get_node("VBox/Details")
		if details:
			details.visible = is_selected
		# Update expand button arrow
		var expand_btn := card.get_node("VBox/Row1/ExpandBtn")
		if expand_btn:
			expand_btn.text = "▼" if is_selected else "▶"


func _on_surface_updated(id: String) -> void:
	if not surface_cards.has(id):
		return
	var s := SurfaceManager.get_surface(id)
	if s.is_empty():
		return
	_update_card_content(surface_cards[id], s)


# ---------------------------------------------------------------------------
# Card creation
# ---------------------------------------------------------------------------
func _create_surface_card(id: String, s: Dictionary) -> void:
	var card := PanelContainer.new()
	card.name = "Card_%s" % id
	card.custom_minimum_size = Vector2(0, 40)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	card.add_child(vbox)

	# Row 1: Label + Color (always visible) + expand toggle
	var row1 := HBoxContainer.new()
	row1.name = "Row1"
	vbox.add_child(row1)

	var expand_btn := Button.new()
	expand_btn.name = "ExpandBtn"
	expand_btn.text = "▶"
	expand_btn.custom_minimum_size = Vector2(28, 28)
	expand_btn.pressed.connect(func():
		SurfaceManager.select_surface(id)
	)
	row1.add_child(expand_btn)

	var label_edit := LineEdit.new()
	label_edit.name = "LabelEdit"
	label_edit.text = s["label"]
	label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_edit.text_submitted.connect(func(new_text: String): _on_label_changed(id, new_text))
	row1.add_child(label_edit)

	var color_btn := ColorPickerButton.new()
	color_btn.name = "ColorBtn"
	color_btn.color = Color.html(s["color"])
	color_btn.custom_minimum_size = Vector2(32, 32)
	color_btn.color_changed.connect(func(col: Color): _on_color_changed(id, col))
	row1.add_child(color_btn)

	# --- Details container (collapsed by default, shown when selected) ---
	var details := VBoxContainer.new()
	details.name = "Details"
	details.visible = false
	vbox.add_child(details)

	# Row 2: Z-order, Grid, Lock, Delete buttons
	var row2 := HBoxContainer.new()
	row2.name = "Row2"
	details.add_child(row2)

	var z_label := Label.new()
	z_label.name = "ZLabel"
	z_label.text = "Z:%d" % s["z_index"]
	z_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(z_label)

	var grid_btn := Button.new()
	grid_btn.name = "GridBtn"
	grid_btn.text = "Grid"
	grid_btn.toggle_mode = true
	grid_btn.button_pressed = s["grid_on"]
	grid_btn.toggled.connect(func(pressed: bool): _on_grid_toggled(id, pressed))
	row2.add_child(grid_btn)

	var lock_btn := Button.new()
	lock_btn.name = "LockBtn"
	lock_btn.text = "🔒" if s["locked"] else "🔓"
	lock_btn.toggle_mode = true
	lock_btn.button_pressed = s["locked"]
	lock_btn.toggled.connect(func(pressed: bool): _on_lock_toggled(id, pressed))
	row2.add_child(lock_btn)

	var del_btn := Button.new()
	del_btn.name = "DelBtn"
	del_btn.text = "🗑"
	del_btn.pressed.connect(func(): SurfaceManager.remove_surface(id))
	row2.add_child(del_btn)

	# Selection is handled by the ▶ expand button and canvas clicks

	# Row 3: Content — Image/Video picker + Clear
	var row3 := HBoxContainer.new()
	row3.name = "Row3"
	details.add_child(row3)

	var img_btn := Button.new()
	img_btn.name = "ImgBtn"
	img_btn.text = "📷"
	img_btn.tooltip_text = "Load image"
	img_btn.pressed.connect(func(): _on_pick_image(id))
	row3.add_child(img_btn)

	var vid_btn := Button.new()
	vid_btn.name = "VidBtn"
	vid_btn.text = "🎬"
	vid_btn.tooltip_text = "Load video"
	vid_btn.pressed.connect(func(): _on_pick_video(id))
	row3.add_child(vid_btn)

	var clear_btn := Button.new()
	clear_btn.name = "ClearBtn"
	clear_btn.text = "✕"
	clear_btn.tooltip_text = "Clear content"
	clear_btn.pressed.connect(func(): _on_clear_content(id))
	row3.add_child(clear_btn)

	var web_btn := Button.new()
	web_btn.name = "WebBtn"
	web_btn.text = "🌐"
	web_btn.tooltip_text = "Load web URL"
	web_btn.pressed.connect(func(): _on_pick_web(id))
	row3.add_child(web_btn)

	var fit_dropdown := OptionButton.new()
	fit_dropdown.name = "FitDropdown"
	fit_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fit_dropdown.add_item("Stretch", 0)
	fit_dropdown.add_item("Fit", 1)
	fit_dropdown.add_item("Fill", 2)
	var current_fit: String = s.get("fit_mode", "stretch")
	match current_fit:
		"stretch": fit_dropdown.selected = 0
		"fit": fit_dropdown.selected = 1
		"fill": fit_dropdown.selected = 2
	fit_dropdown.item_selected.connect(func(idx: int): _on_fit_mode_changed(id, idx))
	row3.add_child(fit_dropdown)

	# Row 4: Opacity slider
	var row4 := HBoxContainer.new()
	row4.name = "Row4"
	details.add_child(row4)

	var opacity_label := Label.new()
	opacity_label.name = "OpacityLabel"
	opacity_label.text = "Opacity:"
	row4.add_child(opacity_label)

	var opacity_slider := HSlider.new()
	opacity_slider.name = "OpacitySlider"
	opacity_slider.min_value = 0.0
	opacity_slider.max_value = 1.0
	opacity_slider.step = 0.01
	opacity_slider.value = s.get("opacity", 1.0)
	opacity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opacity_slider.value_changed.connect(func(val: float): _on_opacity_changed(id, val))
	row4.add_child(opacity_slider)

	# Content source label (shows filename)
	var content_label := Label.new()
	content_label.name = "ContentLabel"
	content_label.text = _content_label_text(s)
	content_label.add_theme_font_size_override("font_size", 10)
	content_label.modulate = Color(0.7, 0.7, 0.7, 1.0)
	details.add_child(content_label)

	# Dimensions (computed, read-only)
	var dims_label := Label.new()
	dims_label.name = "DimsLabel"
	var dims := SurfaceManager.get_surface_dimensions(id)
	dims_label.text = "%d×%d  %s  (%s:1)" % [dims["width"], dims["height"], dims["orientation"], str(dims["aspect"])]
	dims_label.add_theme_font_size_override("font_size", 10)
	dims_label.modulate = Color(0.6, 0.8, 0.6, 1.0)
	details.add_child(dims_label)

	# Description text input
	var desc_edit := TextEdit.new()
	desc_edit.name = "DescEdit"
	desc_edit.text = s.get("description", "")
	desc_edit.placeholder_text = "Describe what this surface should show..."
	desc_edit.custom_minimum_size = Vector2(0, 50)
	desc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	desc_edit.text_changed.connect(func(): _on_description_changed(id, desc_edit.text))
	details.add_child(desc_edit)

	# Copy details button
	var prompt_btn := Button.new()
	prompt_btn.name = "PromptBtn"
	prompt_btn.text = "📋 Copy Details"
	prompt_btn.pressed.connect(func(): _on_copy_prompt(id))
	details.add_child(prompt_btn)

	surface_list.add_child(card)
	surface_cards[id] = card


func _update_card_content(card: PanelContainer, s: Dictionary) -> void:
	var vbox := card.get_node("VBox")
	if not vbox:
		return

	var z_label: Label = vbox.get_node("Details/Row2/ZLabel")
	if z_label:
		z_label.text = "Z:%d" % s["z_index"]

	var grid_btn: Button = vbox.get_node("Details/Row2/GridBtn")
	if grid_btn:
		grid_btn.set_pressed_no_signal(s["grid_on"])

	var lock_btn: Button = vbox.get_node("Details/Row2/LockBtn")
	if lock_btn:
		lock_btn.text = "🔒" if s["locked"] else "🔓"
		lock_btn.set_pressed_no_signal(s["locked"])

	var opacity_slider: HSlider = vbox.get_node("Details/Row4/OpacitySlider")
	if opacity_slider:
		var op: float = s.get("opacity", 1.0)
		if absf(opacity_slider.value - op) > 0.001:
			opacity_slider.set_value_no_signal(op)

	var content_label: Label = vbox.get_node("Details/ContentLabel")
	if content_label:
		content_label.text = _content_label_text(s)

	var dims_label: Label = vbox.get_node("Details/DimsLabel")
	if dims_label:
		var dims := SurfaceManager.get_surface_dimensions(s["id"])
		dims_label.text = "%d×%d  %s  (%s:1)" % [dims["width"], dims["height"], dims["orientation"], str(dims["aspect"])]

	var fit_dropdown: OptionButton = vbox.get_node("Details/Row3/FitDropdown")
	if fit_dropdown:
		var fm: String = s.get("fit_mode", "stretch")
		var idx: int = 0
		match fm:
			"fit": idx = 1
			"fill": idx = 2
		if fit_dropdown.selected != idx:
			fit_dropdown.selected = idx


func _update_card_highlight(card: PanelContainer, selected: bool) -> void:
	# Simple visual feedback: modulate
	if selected:
		card.modulate = Color(1.2, 1.2, 1.4, 1.0)
	else:
		card.modulate = Color(1.0, 1.0, 1.0, 1.0)


# ---------------------------------------------------------------------------
# Property change callbacks
# ---------------------------------------------------------------------------
func _on_label_changed(id: String, new_text: String) -> void:
	SurfaceManager.update_surface_property(id, "label", new_text)


func _on_color_changed(id: String, col: Color) -> void:
	SurfaceManager.update_surface_property(id, "color", "#" + col.to_html(false))


func _on_grid_toggled(id: String, pressed: bool) -> void:
	SurfaceManager.update_surface_property(id, "grid_on", pressed)


func _on_lock_toggled(id: String, pressed: bool) -> void:
	SurfaceManager.update_surface_property(id, "locked", pressed)


func _on_opacity_changed(id: String, val: float) -> void:
	SurfaceManager.update_surface_property(id, "opacity", val)


func _on_fit_mode_changed(id: String, idx: int) -> void:
	var modes := ["stretch", "fit", "fill"]
	if idx >= 0 and idx < modes.size():
		SurfaceManager.update_surface_property(id, "fit_mode", modes[idx])


func _on_pick_image(id: String) -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.png;PNG", "*.jpg;JPEG", "*.jpeg;JPEG", "*.webp;WebP", "*.bmp;BMP"])
	dialog.title = "Select Image"
	dialog.size = Vector2i(800, 500)
	dialog.file_selected.connect(func(path: String):
		SurfaceManager.update_surface_property(id, "content_type", "image")
		SurfaceManager.update_surface_property(id, "content_source", path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _on_pick_video(id: String) -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.ogv;OGV Theora", "*.webm;WebM"])
	dialog.title = "Select Video"
	dialog.size = Vector2i(800, 500)
	dialog.file_selected.connect(func(path: String):
		SurfaceManager.update_surface_property(id, "content_type", "video")
		SurfaceManager.update_surface_property(id, "content_source", path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _on_clear_content(id: String) -> void:
	var s := SurfaceManager.get_surface(id)
	if s.is_empty():
		return
	s["content_type"] = "color"
	s["content_source"] = ""
	SurfaceManager.surface_updated.emit(id)


func _on_pick_web(id: String) -> void:
	# Fetch scene list from the Vite dev server, then show picker
	var base_url := "http://localhost:5173"
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			# Fallback to manual URL entry if server not running
			_show_url_input_dialog(id, base_url)
			return
		var json := JSON.new()
		var err := json.parse(body.get_string_from_utf8())
		if err != OK:
			_show_url_input_dialog(id, base_url)
			return
		var scenes: Array = json.data
		_show_scene_picker(id, base_url, scenes)
	)
	http.request(base_url + "/scenes.json")


func _show_scene_picker(id: String, base_url: String, scenes: Array) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Select Web Scene"
	dialog.size = Vector2i(400, 380)
	dialog.ok_button_text = "Cancel"

	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)

	for s in scenes:
		var btn := Button.new()
		btn.text = "%s  %s" % [s.get("emoji", ""), s.get("name", "Unknown")]
		btn.tooltip_text = s.get("description", "")
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var scene_url: String = base_url + s.get("path", "/")
		btn.pressed.connect(func():
			SurfaceManager.update_surface_property(id, "content_type", "web")
			SurfaceManager.update_surface_property(id, "content_source", scene_url)
			dialog.queue_free()
		)
		vbox.add_child(btn)

	# Separator
	vbox.add_child(HSeparator.new())

	# Generate with AI button
	var ai_btn := Button.new()
	ai_btn.text = "✨ Generate New Scene Using AI"
	ai_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	ai_btn.pressed.connect(func():
		dialog.queue_free()
		_on_generate_ai_scene(id)
	)
	vbox.add_child(ai_btn)

	# Custom URL button
	var custom_btn := Button.new()
	custom_btn.text = "🔗 Custom URL..."
	custom_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_btn.pressed.connect(func():
		dialog.queue_free()
		_show_url_input_dialog(id, base_url)
	)
	vbox.add_child(custom_btn)

	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.confirmed.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _show_url_input_dialog(id: String, default_url: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Enter Web URL"
	dialog.size = Vector2i(500, 120)

	var url_input := LineEdit.new()
	url_input.placeholder_text = "http://localhost:5173/candle"
	url_input.text = default_url
	dialog.add_child(url_input)

	dialog.confirmed.connect(func():
		var url: String = url_input.text.strip_edges()
		if url != "":
			if not url.begins_with("http://") and not url.begins_with("https://"):
				url = "https://" + url
			SurfaceManager.update_surface_property(id, "content_type", "web")
			SurfaceManager.update_surface_property(id, "content_source", url)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _content_label_text(s: Dictionary) -> String:
	var ct: String = s.get("content_type", "color")
	var cs: String = s.get("content_source", "")
	if ct == "color" or cs == "":
		return "Content: Solid Color"
	return "Content: %s" % cs.get_file()


func _on_description_changed(id: String, text: String) -> void:
	# Update without triggering a full surface_updated cycle
	var s := SurfaceManager.get_surface(id)
	if not s.is_empty():
		s["description"] = text


func _on_copy_prompt(id: String) -> void:
	var prompt := SurfaceManager.generate_surface_prompt(id)
	DisplayServer.clipboard_set(prompt)
	print("Copied details for surface %s to clipboard" % id)


func _on_generate_ai_scene(id: String) -> void:
	var prompt := SurfaceManager.generate_surface_prompt(id)
	DisplayServer.clipboard_set(prompt)

	var dialog := AcceptDialog.new()
	dialog.title = "✨ Generate with AI"
	dialog.size = Vector2i(450, 200)

	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)

	var info := Label.new()
	info.text = "Surface context copied to clipboard!"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info)

	var info2 := Label.new()
	info2.text = "Paste into your AI assistant to generate\na custom Three.js scene for this surface."
	info2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info2.modulate = Color(0.7, 0.7, 0.7, 1.0)
	vbox.add_child(info2)

	vbox.add_child(HSeparator.new())

	var dims := SurfaceManager.get_surface_dimensions(id)
	var s := SurfaceManager.get_surface(id)
	var preview := Label.new()
	preview.text = "%s  •  %d×%d %s" % [s.get("label", ""), dims["width"], dims["height"], dims["orientation"]]
	var desc_text: String = s.get("description", "")
	if desc_text != "":
		preview.text += "\n\"%s\"" % desc_text
	preview.add_theme_font_size_override("font_size", 11)
	preview.modulate = Color(0.6, 0.9, 0.6, 1.0)
	vbox.add_child(preview)

	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.confirmed.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()
