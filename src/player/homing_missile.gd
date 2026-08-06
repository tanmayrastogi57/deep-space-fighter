extends Node3D

var target: Node3D
var source: Node3D
var direction := Vector3.FORWARD
var speed := 82.0
var turn_rate := 2.6
var life := 10.0


func _ready() -> void:
	name = "HomingMissile"
	var body := VisualFactory.add_mesh(
		self,
		VisualFactory.cylinder(0.08, 0.14, 1.25, 12),
		Vector3.ZERO,
		Vector3.ONE,
		VisualFactory.material(Color("#d5dde2"), 0.75, 0.25),
		Vector3(90, 0, 0),
		"MissileBody"
	)
	var plume := VisualFactory.add_mesh(
		self,
		VisualFactory.cylinder(0.035, 0.12, 1.4, 10),
		Vector3(0, 0, 1.15),
		Vector3.ONE,
		VisualFactory.material(Color(0.3, 0.85, 1.0, 0.7), 0.0, 0.1, Color("#31cfff"), true),
		Vector3(90, 0, 0),
		"MissilePlume"
	)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if target != null and is_instance_valid(target):
		var target_velocity: Vector3 = target.velocity if target is CharacterBody3D else Vector3.ZERO
		var desired := FlightMath.intercept_direction(global_position, speed, target.global_position, target_velocity)
		direction = direction.slerp(desired, clampf(turn_rate * delta, 0.0, 1.0)).normalized()
		if global_position.distance_to(target.global_position) < 3.0:
			if target.has_method("damage"):
				target.call("damage", 48.0 + float(Career.data.upgrades.missiles) * 6.0, source)
			VisualFactory.spawn_explosion(get_parent(), global_position, 3.2)
			Sound.play_effect("impact", 0.8)
			queue_free()
			return
	global_position += direction * speed * delta
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)
