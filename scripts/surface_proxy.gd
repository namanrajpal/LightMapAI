extends Node
## SurfaceProxy — Bridge between AnimationPlayer and SurfaceManager.
## One instance per surface, child of TimelineManager.
## Exported properties are targeted by AnimationPlayer value tracks;
## setters forward changes to SurfaceManager.

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------
var surface_id: String = ""

# ---------------------------------------------------------------------------
# Local corner cache (4 × Vector2)
# ---------------------------------------------------------------------------
var _corners: Array = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]

# ---------------------------------------------------------------------------
# Animatable properties with forwarding setters
# ---------------------------------------------------------------------------

@export var opacity: float = 1.0:
	set(value):
		opacity = value
		_set_property("opacity", value)

@export var color: Color = Color.WHITE:
	set(value):
		color = value
		_set_property("color", "#" + value.to_html(false))

@export var visible_prop: bool = true:
	set(value):
		visible_prop = value
		_set_property("visible", value)

@export var z_index_prop: int = 0:
	set(value):
		z_index_prop = value
		_set_property("z_index", value)

@export var corner_tl: Vector2 = Vector2.ZERO:
	set(value):
		corner_tl = value
		_set_corner(0, value)

@export var corner_tr: Vector2 = Vector2.ZERO:
	set(value):
		corner_tr = value
		_set_corner(1, value)

@export var corner_br: Vector2 = Vector2.ZERO:
	set(value):
		corner_br = value
		_set_corner(2, value)

@export var corner_bl: Vector2 = Vector2.ZERO:
	set(value):
		corner_bl = value
		_set_corner(3, value)

@export var fit_mode: String = "stretch":
	set(value):
		fit_mode = value
		_set_property("fit_mode", value)

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _set_property(key: String, value: Variant) -> void:
	if surface_id.is_empty():
		return
	if SurfaceManager.get_surface(surface_id).is_empty():
		return
	SurfaceManager.update_surface_property(surface_id, key, value)


func _set_corner(index: int, value: Vector2) -> void:
	_corners[index] = value
	if surface_id.is_empty():
		return
	if SurfaceManager.get_surface(surface_id).is_empty():
		return
	SurfaceManager.update_corners(surface_id, PackedVector2Array(_corners))

# ---------------------------------------------------------------------------
# Sync from SurfaceManager → proxy (used on creation & when animation stops)
# ---------------------------------------------------------------------------

func sync_from_surface() -> void:
	if surface_id.is_empty():
		return
	var s: Dictionary = SurfaceManager.get_surface(surface_id)
	if s.is_empty():
		return

	# Read scalar properties. Setters will fire and write back the same
	# values to SurfaceManager (harmless no-op, keeps proxy in sync).
	opacity = s.get("opacity", 1.0)
	color = Color.html(s.get("color", "#FFFFFF"))
	visible_prop = s.get("visible", true)
	z_index_prop = int(s.get("z_index", 0))
	fit_mode = str(s.get("fit_mode", "stretch"))

	# Read corners
	var corners: PackedVector2Array = s.get("corners", PackedVector2Array())
	if corners.size() >= 4:
		_corners = [corners[0], corners[1], corners[2], corners[3]]
		corner_tl = corners[0]
		corner_tr = corners[1]
		corner_br = corners[2]
		corner_bl = corners[3]
