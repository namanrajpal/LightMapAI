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
	if corners.size() < 4:
		info_label.text = "%s selected" % s["label"]
		return

	var mode_text := "OUTPUT" if SurfaceManager.is_output_mode else "SETUP"
	info_label.text = "%s  |  TL(%d,%d)  TR(%d,%d)  BR(%d,%d)  BL(%d,%d)  |  %s" % [
		s["label"],
		int(corners[0].x), int(corners[0].y),
		int(corners[1].x), int(corners[1].y),
		int(corners[2].x), int(corners[2].y),
		int(corners[3].x), int(corners[3].y),
		mode_text,
	]
