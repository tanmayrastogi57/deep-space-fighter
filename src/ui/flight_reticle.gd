extends Control
class_name FlightReticle

var locked := false
var high_contrast := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(64, 64)


func _draw() -> void:
	var center := size * 0.5
	var color := Color("#ffcb54") if locked else Color("#79dfff")
	if high_contrast:
		color = Color.WHITE if not locked else Color("#ffed44")
	draw_arc(center, 15.0, 0.0, TAU, 28, Color(color, 0.78), 1.5, true)
	draw_line(center + Vector2(-28, 0), center + Vector2(-10, 0), color, 2.0)
	draw_line(center + Vector2(10, 0), center + Vector2(28, 0), color, 2.0)
	draw_line(center + Vector2(0, -28), center + Vector2(0, -10), color, 2.0)
	draw_line(center + Vector2(0, 10), center + Vector2(0, 28), color, 2.0)
	if locked:
		draw_arc(center, 25.0, -PI * 0.25, PI * 0.25, 8, color, 2.5, true)
		draw_arc(center, 25.0, PI * 0.75, PI * 1.25, 8, color, 2.5, true)


func set_locked(value: bool) -> void:
	if locked != value:
		locked = value
		queue_redraw()

