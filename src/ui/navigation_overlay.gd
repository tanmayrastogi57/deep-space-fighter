extends Control

const GOLD := Color("#ffcf66")
const CYAN := Color("#79dbe9")
var fighter: PlayerFighter
var target: Node3D
var destination := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


# Screen bearing from camera space works behind the camera too; never project
# a point on the camera plane. Keep enough margin for the range caption.
static func edge_point(direction: Vector2, bounds: Vector2) -> Vector2:
	var half_box := (bounds * 0.5 - Vector2(110, 100)).max(Vector2(10, 10))
	var bearing := direction.normalized() if direction.length_squared() > 0.00001 else Vector2.DOWN
	var divisor := maxf(absf(bearing.x) / half_box.x, absf(bearing.y) / half_box.y)
	return bounds * 0.5 + bearing / divisor


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(fighter) or not camera:
		return
	for dock in get_tree().get_nodes_in_group("dockable"):
		if not camera.is_position_behind(dock.global_position) and dock != target:
			var pos := camera.unproject_position(dock.global_position)
			if Rect2(Vector2.ZERO, size).grow(-45).has_point(pos):
				draw_rect(Rect2(pos - Vector2(7, 7), Vector2(14, 14)), CYAN, false, 2)
				_caption(pos + Vector2(0, -17), "DOCK  " + dock.station_name, CYAN)
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	var location := target.global_position
	var local := camera.to_local(location)
	var on_screen := false
	var p := Vector2.ZERO
	if local.z < -camera.near:
		p = camera.unproject_position(location)
		on_screen = Rect2(Vector2(100, 85), size - Vector2(200, 170)).has_point(p)
	var suffix := ""
	if on_screen:
		draw_polyline(PackedVector2Array([p + Vector2(0,-12), p + Vector2(12,0), p + Vector2(0,12), p + Vector2(-12,0), p + Vector2(0,-12)]), GOLD, 2, true)
	else:
		p = edge_point(Vector2(local.x, -local.y), size)
		var d := (p - size * 0.5).normalized()
		draw_colored_polygon(PackedVector2Array([p + d * 13, p - d * 8 + d.orthogonal() * 7, p - d * 8 - d.orthogonal() * 7]), GOLD)
		if local.z >= 0:
			suffix = " · AFT"
	_caption(p + Vector2(0, 31), "%s  %d m%s" % [destination, roundi(fighter.global_position.distance_to(location)), suffix], GOLD)


func _caption(p: Vector2, value: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var start := Vector2(clampf(p.x - w * 0.5, 8, maxf(8, size.x - w - 8)), p.y)
	draw_string_outline(font, start, value, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color("#081017"))
	draw_string(font, start, value, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
