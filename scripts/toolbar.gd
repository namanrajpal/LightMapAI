extends HBoxContainer
## Toolbar — Top bar with Save, Load, Output Mode, Generate.

@onready var save_btn: Button = %SaveBtn
@onready var load_btn: Button = %LoadBtn
@onready var output_btn: Button = %OutputBtn
@onready var generate_btn: Button = %GenerateBtn
@onready var save_status: Label = %SaveStatus

var _save_fade_tween: Tween = null


func _ready() -> void:
	if save_btn:
		save_btn.pressed.connect(_on_save_pressed)
	if load_btn:
		load_btn.pressed.connect(_on_load_pressed)
	if output_btn:
		output_btn.pressed.connect(_on_output_pressed)
	if generate_btn:
		generate_btn.pressed.connect(_on_generate_pressed)


func _on_save_pressed() -> void:
	var err := SurfaceManager.quick_save()
	if err == OK:
		_show_save_status("✓ Saved", Color(0.5, 0.9, 0.5, 1.0))
	else:
		_show_save_status("✗ Save failed", Color(1.0, 0.4, 0.4, 1.0))


func _on_load_pressed() -> void:
	# Show a confirmation dialog before loading (overwrites current state)
	var dialog := ConfirmationDialog.new()
	dialog.title = "Load Configuration"
	dialog.dialog_text = "Load saved configuration?\nThis will replace all current surfaces."
	dialog.ok_button_text = "Load"
	dialog.confirmed.connect(func():
		var err := SurfaceManager.quick_load()
		if err == OK:
			_show_save_status("✓ Loaded", Color(0.5, 0.9, 0.5, 1.0))
		else:
			_show_save_status("✗ Load failed", Color(1.0, 0.4, 0.4, 1.0))
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _show_save_status(text: String, color: Color) -> void:
	if not save_status:
		return
	save_status.text = text
	save_status.modulate = color

	# Fade out after 2 seconds
	if _save_fade_tween:
		_save_fade_tween.kill()
	_save_fade_tween = create_tween()
	_save_fade_tween.tween_interval(2.0)
	_save_fade_tween.tween_property(save_status, "modulate:a", 0.0, 0.5)


func _on_output_pressed() -> void:
	SurfaceManager.set_output_mode(true)


func _on_generate_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "✨ Generate Content for Surfaces"
	dialog.size = Vector2i(550, 450)
	dialog.ok_button_text = "📋 Copy All as Prompt"

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 350)
	dialog.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var checkboxes: Array[Dictionary] = []

	for s in SurfaceManager.surfaces:
		var dims := SurfaceManager.get_surface_dimensions(s["id"])
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)

		var row := HBoxContainer.new()
		var cb := CheckBox.new()
		cb.button_pressed = true
		cb.text = "%s  (%d×%d, %s)" % [s["label"], dims["width"], dims["height"], dims["orientation"]]
		row.add_child(cb)
		card.add_child(row)

		var desc_text: String = s.get("description", "")
		var desc_label := Label.new()
		desc_label.text = desc_text if desc_text != "" else "(no description)"
		desc_label.modulate = Color(0.7, 0.7, 0.7, 1.0) if desc_text == "" else Color(1, 1, 1, 1)
		desc_label.add_theme_font_size_override("font_size", 11)
		card.add_child(desc_label)

		var sep := HSeparator.new()
		card.add_child(sep)

		vbox.add_child(card)
		checkboxes.append({"id": s["id"], "checkbox": cb})

	dialog.confirmed.connect(func():
		var lines: PackedStringArray = PackedStringArray()
		var count := 0
		for entry in checkboxes:
			if entry["checkbox"].button_pressed:
				count += 1
		lines.append("Generate Three.js scenes for a projection mapping setup with %d surfaces:\n" % count)
		for entry in checkboxes:
			if not entry["checkbox"].button_pressed:
				continue
			var s := SurfaceManager.get_surface(entry["id"])
			if s.is_empty():
				continue
			var dims := SurfaceManager.get_surface_dimensions(entry["id"])
			lines.append("## %s" % s["label"])
			lines.append("- Dimensions: %d×%d pixels (%s, %s:1)" % [dims["width"], dims["height"], dims["orientation"], str(dims["aspect"])])
			if s.get("description", "") != "":
				lines.append("- Description: %s" % s["description"])
			var tags: Array = s.get("tags", [])
			if tags.size() > 0:
				lines.append("- Tags: %s" % ", ".join(PackedStringArray(tags)))
			lines.append("")
		lines.append("Requirements for all scenes:")
		lines.append("- Black background (#000), full-screen effects filling the entire viewport, no UI elements")
		lines.append("- Each scene runs at its own route in a React + Vite app")
		lines.append("- Use Three.js with the useThreeScene hook pattern")
		lines.append("- Scenes will be displayed inside warped quads on projection surfaces")
		var prompt := "\n".join(lines)
		DisplayServer.clipboard_set(prompt)
		print("Copied generation prompt for %d surfaces to clipboard" % count)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()
