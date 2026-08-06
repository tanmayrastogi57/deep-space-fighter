extends CharacterBody3D
class_name PlayerFighter

signal interact_requested
signal destroyed
signal weapon_fired(weapon_name: String)

const MissileScript := preload("res://src/player/homing_missile.gd")

var throttle := 0.32
var flight_assist := true
var landing_gear := false
var controls_enabled := true
var hull := 100.0
var max_hull := 100.0
var shields := 100.0
var max_shields := 100.0
var energy := 100.0
var missiles := 8
var active_weapon := 0
var cannon_cooldown := 0.0
var missile_cooldown := 0.0
var lock_progress := 0.0
var current_target: Node3D
var camera_rig: FighterCameraRig
var model_parts: Dictionary
var last_impact_speed := 0.0

var minimum_speed := 8.0
var maximum_speed := 145.0
var acceleration := 58.0
var pitch_rate := 1.22
var roll_rate := 1.72
var yaw_rate := 0.72


func _ready() -> void:
	name = "PlayerFighter"
	add_to_group("player")
	collision_layer = 1
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.35
	capsule.height = 6.8
	collision.shape = capsule
	collision.rotation_degrees = Vector3(90, 0, 0)
	add_child(collision)
	model_parts = VisualFactory.build_fighter(self)
	_apply_upgrades()
	camera_rig = FighterCameraRig.new()
	get_parent().call_deferred("add_child", camera_rig)
	camera_rig.call_deferred("setup", self)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_camera") and camera_rig:
		camera_rig.cycle_view()
	if event.is_action_pressed("toggle_gear"):
		toggle_landing_gear()
	if event.is_action_pressed("toggle_flight_assist"):
		flight_assist = not flight_assist
		Sound.play_effect("dock", 0.35)
	if event.is_action_pressed("interact"):
		interact_requested.emit()
	if event.is_action_pressed("next_weapon"):
		active_weapon = (active_weapon + 1) % 2
		lock_progress = 0.0
	if event.is_action_pressed("previous_weapon"):
		active_weapon = (active_weapon + 1) % 2
		lock_progress = 0.0


func _physics_process(delta: float) -> void:
	cannon_cooldown = maxf(0.0, cannon_cooldown - delta)
	missile_cooldown = maxf(0.0, missile_cooldown - delta)
	energy = minf(100.0, energy + delta * 8.5)
	shields = minf(max_shields, shields + delta * 1.4)
	if not controls_enabled:
		velocity = velocity.lerp(Vector3.ZERO, clampf(delta * 4.0, 0.0, 1.0))
		move_and_slide()
		return

	throttle = FlightMath.step_throttle(
		throttle,
		Input.get_action_strength("throttle_up"),
		Input.get_action_strength("throttle_down"),
		delta
	)
	var pitch_input := Input.get_axis("pitch_up", "pitch_down")
	var roll_input := Input.get_axis("roll_left", "roll_right")
	var yaw_input := Input.get_axis("yaw_left", "yaw_right")
	var authority := lerpf(0.56, 1.0, throttle)
	rotate_object_local(Vector3.RIGHT, pitch_input * pitch_rate * authority * delta)
	rotate_object_local(Vector3.FORWARD, -roll_input * roll_rate * authority * delta)
	rotate_object_local(Vector3.UP, -yaw_input * yaw_rate * authority * delta)
	transform.basis = transform.basis.orthonormalized()
	var forward := -global_transform.basis.z
	velocity = FlightMath.assisted_velocity(
		velocity,
		forward,
		throttle,
		minimum_speed,
		maximum_speed,
		acceleration,
		delta,
		1.0 if flight_assist else 0.0
	)
	move_and_slide()
	_handle_collisions()
	_update_target_lock(delta)
	if Input.is_action_pressed("fire_weapon"):
		fire_active_weapon()
	Sound.set_engine_throttle(throttle)
	_update_engine_visuals()


func fire_active_weapon() -> void:
	if active_weapon == 0:
		_fire_cannon()
	else:
		_fire_missile()


func _fire_cannon() -> void:
	if cannon_cooldown > 0.0 or energy < 1.8:
		return
	cannon_cooldown = 0.095
	energy -= 1.8
	var origin := global_position - global_transform.basis.z * 3.4
	var end := origin - global_transform.basis.z * 1100.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit.position
		var collider: Object = hit.collider
		if collider.has_method("damage"):
			collider.call("damage", 9.0 + float(Career.data.upgrades.cannon) * 1.8, self)
	_spawn_tracer(origin, end)
	Sound.play_effect("cannon", 0.55)
	weapon_fired.emit("CANNON")


func _fire_missile() -> void:
	if missile_cooldown > 0.0 or missiles <= 0 or current_target == null or lock_progress < 1.0:
		return
	if not is_instance_valid(current_target):
		current_target = null
		return
	missile_cooldown = 0.8
	missiles -= 1
	var missile := MissileScript.new()
	missile.target = current_target
	missile.source = self
	get_parent().add_child(missile)
	missile.global_position = global_position - global_transform.basis.z * 2.5 + global_transform.basis.y * -0.25
	missile.direction = -global_transform.basis.z
	Sound.play_effect("missile", 0.8)
	weapon_fired.emit("MISSILE")
	lock_progress = 0.0


func _update_target_lock(delta: float) -> void:
	if active_weapon != 1 or not Input.is_action_pressed("target_lock"):
		lock_progress = maxf(0.0, lock_progress - delta * 1.3)
		return
	if current_target == null or not is_instance_valid(current_target) or not _target_in_lock_cone(current_target):
		current_target = _best_target()
		lock_progress = 0.0
	if current_target != null:
		var sensor_level := int(Career.data.upgrades.sensors)
		lock_progress = minf(1.0, lock_progress + delta * (0.72 + sensor_level * 0.1))


func _best_target() -> Node3D:
	var best: Node3D
	var best_score := INF
	for candidate in get_tree().get_nodes_in_group("hostile"):
		if not candidate is Node3D or not is_instance_valid(candidate):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance > 900.0:
			continue
		var direction := global_position.direction_to(candidate.global_position)
		var angle := (-global_transform.basis.z).angle_to(direction)
		var score := angle * 500.0 + distance * 0.15
		if angle < 0.48 and score < best_score:
			best = candidate
			best_score = score
	return best


func _target_in_lock_cone(candidate: Node3D) -> bool:
	var direction := global_position.direction_to(candidate.global_position)
	return global_position.distance_to(candidate.global_position) < 950.0 and (-global_transform.basis.z).angle_to(direction) < 0.62


func _spawn_tracer(origin: Vector3, end: Vector3) -> void:
	var distance := origin.distance_to(end)
	var tracer := MeshInstance3D.new()
	tracer.mesh = VisualFactory.cylinder(0.025, 0.025, distance, 8)
	tracer.material_override = VisualFactory.material(Color("#b8f7ff"), 0.0, 0.1, Color("#58dcff"), true)
	get_parent().add_child(tracer)
	tracer.global_position = origin.lerp(end, 0.5)
	tracer.look_at(end, Vector3.UP)
	tracer.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var tween := tracer.create_tween()
	tween.tween_property(tracer, "transparency", 1.0, 0.085)
	tween.tween_callback(tracer.queue_free)


func _handle_collisions() -> void:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var impact_speed := velocity.length()
		if impact_speed > last_impact_speed + 4.0:
			apply_damage(FlightMath.impact_damage(impact_speed, 4.0, shields / max_shields))
			Sound.play_effect("impact", clampf(impact_speed / maximum_speed, 0.25, 1.0))
		last_impact_speed = impact_speed
	last_impact_speed = move_toward(last_impact_speed, 0.0, 1.0)


func apply_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	var shield_absorb := minf(shields, amount)
	shields -= shield_absorb
	hull -= maxf(0.0, amount - shield_absorb)
	if hull <= 0.0:
		hull = 0.0
		controls_enabled = false
		VisualFactory.spawn_explosion(get_parent(), global_position, 8.0, Color("#ff7845"))
		destroyed.emit()


func toggle_landing_gear() -> void:
	if velocity.length() > 70.0 and not landing_gear:
		return
	landing_gear = not landing_gear
	if model_parts.has("gear"):
		model_parts.gear.visible = landing_gear
	Sound.play_effect("dock", 0.28)


func dock_at(dock_transform: Transform3D) -> void:
	controls_enabled = false
	velocity = Vector3.ZERO
	global_transform = dock_transform
	hull = max_hull
	shields = max_shields
	energy = 100.0
	missiles = 8 + int(Career.data.upgrades.missiles) * 2
	Career.data.hull = hull
	Career.data.shields = shields
	Career.data.missiles = missiles
	Career.data.docked_at = "Asteria Station"
	Career.save_atomic()
	Sound.play_effect("dock", 0.9)
	await get_tree().create_timer(1.0).timeout
	controls_enabled = true


func _apply_upgrades() -> void:
	var upgrades: Dictionary = Career.data.get("upgrades", {})
	maximum_speed += float(upgrades.get("engine", 0)) * 12.0
	acceleration += float(upgrades.get("engine", 0)) * 4.0
	pitch_rate += float(upgrades.get("thrusters", 0)) * 0.08
	roll_rate += float(upgrades.get("thrusters", 0)) * 0.11
	max_hull += float(upgrades.get("hull", 0)) * 14.0
	max_shields += float(upgrades.get("shields", 0)) * 13.0
	hull = max_hull
	shields = max_shields
	missiles = 8 + int(upgrades.get("missiles", 0)) * 2


func _update_engine_visuals() -> void:
	for plume in model_parts.get("plumes", []):
		if plume is Node3D:
			plume.scale = Vector3(lerpf(0.62, 1.0, throttle), lerpf(0.62, 1.0, throttle), lerpf(0.45, 1.35, throttle))


func weapon_name() -> String:
	return "CANNON" if active_weapon == 0 else "HOMING MISSILE"


func camera_name() -> String:
	return camera_rig.view_name() if camera_rig else "CHASE"

