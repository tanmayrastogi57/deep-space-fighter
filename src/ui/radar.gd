extends Control
class_name FlightRadar

var fighter: PlayerFighter
var range_meters := 650.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(172, 172)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	draw_circle(center, radius, Color(0.01, 0.055, 0.09, 0.72))
	for fraction in [0.33, 0.66, 1.0]:
		draw_arc(center, radius * fraction, 0.0, TAU, 48, Color(0.25, 0.78, 0.95, 0.34), 1.0, true)
	draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), Color(0.25, 0.78, 0.95, 0.24), 1.0)
	draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), Color(0.25, 0.78, 0.95, 0.24), 1.0)
	var ship := PackedVector2Array([center + Vector2(0, -8), center + Vector2(-6, 6), center, center + Vector2(6, 6)])
	draw_polyline(ship, Color("#72e6ff"), 2.0, true)
	if fighter == null or not is_instance_valid(fighter):
		return
	for hostile in get_tree().get_nodes_in_group("hostile"):
		if hostile is not Node3D:
			continue
		var local: Vector3 = fighter.global_transform.basis.inverse() * (hostile.global_position - fighter.global_position)
		var distance := Vector2(local.x, local.z).length()
		if distance > range_meters:
			continue
		var blip := center + Vector2(local.x, local.z) / range_meters * radius
		draw_circle(blip, 3.5, Color("#ff5a55"))
	for dockable in get_tree().get_nodes_in_group("dockable"):
		if dockable is not Node3D:
			continue
		var local: Vector3 = fighter.global_transform.basis.inverse() * (dockable.global_position - fighter.global_position)
		var distance := Vector2(local.x, local.z).length()
		if distance <= range_meters:
			var blip := center + Vector2(local.x, local.z) / range_meters * radius
			draw_rect(Rect2(blip - Vector2.ONE * 3.5, Vector2.ONE * 7.0), Color("#58d8ff"), false, 1.5)
