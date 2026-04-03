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
		_update_card_highlight(card, sid == id)


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
	card.custom_minimum_size = Vector2(0, 80)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	card.add_child(vbox)

	# Row 1: Label + Color
	var row1 := HBoxContainer.new()
	row1.name = "Row1"
	vbox.add_child(row1)

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

	# Row 2: Z-order, Grid, Lock, Delete buttons
	var row2 := HBoxContainer.new()
	row2.name = "Row2"
	vbox.add_child(row2)

	var z_label := Label.new()
	z_label.name = "ZLabel"
	z_label.text = "Z:%d" % s["z_index"]
	z_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(z_label)

	var grid_btn := Button.new()
	grid_btn.name = "GridBtn"
	grid_btn.text = "Grid" if s["grid_on"] else "Grid"
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

	# Click on card to select
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				SurfaceManager.select_surface(id)
	)

	surface_list.add_child(card)
	surface_cards[id] = card


func _update_card_content(card: PanelContainer, s: Dictionary) -> void:
	var vbox := card.get_node("VBox")
	if not vbox:
		return

	var z_label: Label = vbox.get_node("Row2/ZLabel")
	if z_label:
		z_label.text = "Z:%d" % s["z_index"]

	var grid_btn: Button = vbox.get_node("Row2/GridBtn")
	if grid_btn:
		grid_btn.set_pressed_no_signal(s["grid_on"])

	var lock_btn: Button = vbox.get_node("Row2/LockBtn")
	if lock_btn:
		lock_btn.text = "🔒" if s["locked"] else "🔓"
		lock_btn.set_pressed_no_signal(s["locked"])


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
