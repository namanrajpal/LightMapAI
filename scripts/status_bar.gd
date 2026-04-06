extends PanelContainer
## StatusBar — Shows selected surface info and corner coordinates.

@onready var info_label: Label = %InfoLabel

func _ready() -> void:
	SurfaceManager.surface_selected.connect(_on_surface_selected)
	SurfaceManager.surface_updated.connect(_on_surface_updated)
	SurfaceManager.mode_changed.connect(_on_mode_changed)
	_update_display()


func _on_surface_selected(_id: String) -> void:
	_update_display()


func _on_surface_updated(id: String) -> void:
	if id == SurfaceManager.selected_surface_id:
		_update_display()


func _on_mode_changed(is_output: bool) -> void:
	if not is_output:
		_update_display()


func _update_display() -> void:
	if not info_label:
		return

	var s := SurfaceManager.get_selected_surface()
	if s.is_empty():
		info_label.text = "No surface selected"
		return

	var corners: PackedVector2Array = s["corners"]
	if corners.size() < 3:
		info_label.text = "%s selected" % s["label"]
		return

	var mode_text := "OUTPUT" if SurfaceManager.is_output_mode else "SETUP"
	var corner_labels := ["TL", "TR", "BR", "BL"]
	var parts: PackedStringArray = PackedStringArray()
	for i in range(corners.size()):
		var label: String = corner_labels[i] if i < corner_labels.size() else str(i + 1)
		parts.append("%s(%d,%d)" % [label, int(corners[i].x), int(corners[i].y)])
	info_label.text = "%s  |  %s  |  %s  |  %d pts" % [s["label"], "  ".join(parts), mode_text, corners.size()]
