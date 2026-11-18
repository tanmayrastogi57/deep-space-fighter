extends Node3D
class_name FighterCameraRig

enum ViewMode { COCKPIT, CLOSE_CHASE, FAR_CHASE }

var target: Node3D
var camera: Camera3D
var mode := ViewMode.CLOSE_CHASE
var look_yaw := 0.0
var look_pitch := -0.08
var mouse_idle := 0.0
var rear_view := false
var base_fov := 78.0
const Frame := preload("res://src/world/airframe.gd")
var interior: Dictionary
var last_view := -1


func setup(fighter: Node3D) -> void:
	target = fighter
	top_level = true
	camera = Camera3D.new()
	camera.name = "FlightCamera"
	camera.current = true
	camera.near = 0.08
	camera.far = 6000.0
	add_child(camera)
	base_fov = float(Settings.data.get("field_of_view", 78.0))
	camera.fov = base_fov
	interior = Frame.cockpit(target)
	camera.cull_mask &= ~Frame.INTERIOR
	interior.root.hide()


func _unhandled_input(event: InputEvent) -> void:
	if target == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var sensitivity := float(Settings.data.get("mouse_sensitivity", 0.0025))
		var invert := -1.0 if bool(Settings.data.get("invert_y", false)) else 1.0
		look_yaw = clampf(look_yaw - event.relative.x * sensitivity, -2.65, 2.65)
		look_pitch = clampf(look_pitch - event.relative.y * sensitivity * invert, -1.15, 0.82)
		mouse_idle = 0.0


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or camera == null:
		return
	rear_view = Input.is_action_pressed("rear_view")
	var view := -2 if rear_view else int(mode)
	var snap := view != last_view
	last_view = view
	var cockpit := mode == ViewMode.COCKPIT and not rear_view
	camera.set_cull_mask_value(2, not cockpit and not rear_view)
	camera.set_cull_mask_value(3, cockpit)
	interior.root.visible = cockpit
	if cockpit and target is PlayerFighter:
		interior.readouts[0].text = "%03d m/s" % roundi(target.velocity.length())
		interior.readouts[1].text = "THR %02d" % roundi(target.throttle * 100)
	mouse_idle += delta
	if mouse_idle > 1.2 and not Input.is_action_pressed("free_look"):
		look_yaw = lerpf(look_yaw, 0.0, clampf(delta * 1.35, 0.0, 1.0))
		look_pitch = lerpf(look_pitch, -0.08, clampf(delta * 1.35, 0.0, 1.0))
	var basis := target.global_transform.basis.orthonormalized()
	var forward := -basis.z
	var right := basis.x
	var up := basis.y
	var desired_position: Vector3
	var focus: Vector3
	if rear_view:
		desired_position = target.global_position + up * 1.25 - forward * 1.0
		focus = target.global_position - forward * 45.0
	elif mode == ViewMode.COCKPIT:
		desired_position = target.global_position + up * 0.62 + forward * 0.72
		focus = desired_position + _look_direction(basis) * 120.0
	else:
		var distance := 10.5 if mode == ViewMode.CLOSE_CHASE else 19.0
		var height := 4.4 if mode == ViewMode.CLOSE_CHASE else 7.0
		var orbit := Basis(up, look_yaw) * Basis(right, look_pitch)
		var offset := orbit * (basis.z * distance + up * height)
		desired_position = target.global_position + offset
		focus = target.global_position + forward * (8.0 if mode == ViewMode.CLOSE_CHASE else 16.0)
	var smoothing := clampf(delta * (16.0 if mode == ViewMode.COCKPIT else 7.0), 0.0, 1.0)
	global_position = desired_position if cockpit or rear_view or snap else global_position.lerp(desired_position, smoothing)
	if global_position.distance_squared_to(focus) > 0.001:
		look_at(focus, up)
	var speed := 0.0
	if target is CharacterBody3D:
		speed = target.velocity.length()
	camera.fov = lerpf(camera.fov, base_fov + clampf(speed / 35.0, 0.0, 9.0), clampf(delta * 3.0, 0.0, 1.0))


func cycle_view() -> void:
	mode = (mode + 1) % ViewMode.size()
	mouse_idle = 2.0


func view_name() -> String:
	match mode:
		ViewMode.COCKPIT:
			return "COCKPIT"
		ViewMode.CLOSE_CHASE:
			return "CHASE"
		_:
			return "FAR CHASE"


func _look_direction(basis: Basis) -> Vector3:
	var direction := -basis.z
	direction = direction.rotated(basis.y, look_yaw)
	direction = direction.rotated(basis.x, look_pitch)
	return direction.normalized()
