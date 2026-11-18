extends CharacterBody3D
class_name SpaceObject

signal destroyed(object: SpaceObject, source: Node)

var object_kind := "ASTEROID"
var health := 30.0
var radius := 4.0
var seed_value := 1
var drift := Vector3.ZERO
var rotation_axis := Vector3.UP
var rotation_speed := 0.1
var reward := 45
const Art := preload("res://src/world/rock_art.gd")
var composition := Art.FRACTURED
var nucleus: MeshInstance3D
var illuminator: Node3D
var tail_axis: Node3D


func configure(kind: String, object_radius: float, seed_number: int, initial_velocity: Vector3 = Vector3.ZERO, geology: int = Art.FRACTURED) -> void:
	object_kind = kind
	radius = object_radius
	seed_value = seed_number
	drift = initial_velocity
	composition = Art.ICE if kind == "COMET" else geology
	health = radius * (10.0 if kind == "COMET" else 5.0)
	reward = int(radius * (28.0 if kind == "COMET" else 8.0))


func _ready() -> void:
	name = "%s_%d" % [object_kind.capitalize(), seed_value]
	add_to_group("damageable")
	collision_layer = 1
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius * 0.9
	collision.shape = shape
	add_child(collision)
	nucleus = VisualFactory.add_mesh(
		self,
		VisualFactory.asteroid_mesh(seed_value, radius, 12 if radius < 8.0 else 18, 18 if radius < 8.0 else 26),
		Vector3.ZERO,
		Vector3.ONE,
		Art.rock(composition),
		Vector3.ZERO,
		object_kind.capitalize() + "Mesh"
	)
	nucleus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	rotation_axis = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
	rotation_speed = rng.randf_range(0.035, 0.16)
	if object_kind == "COMET":
		_build_comet_tail()


func _physics_process(delta: float) -> void:
	nucleus.rotate(rotation_axis, rotation_speed * delta)
	velocity = drift
	if drift.length_squared() > 0.0:
		move_and_slide()
	if tail_axis:
		_point_tail()


func damage(amount: float, source: Node = null) -> void:
	health -= maxf(0.0, amount)
	if health <= 0.0:
		VisualFactory.spawn_explosion(get_parent(), global_position, radius * 1.6, Color("#9edbe5") if object_kind == "COMET" else Color("#f0a661"))
		Sound.play_effect("impact", clampf(radius / 8.0, 0.35, 1.0))
		destroyed.emit(self, source)
		queue_free()


func _build_comet_tail() -> void:
	tail_axis = Node3D.new()
	tail_axis.name = "AntiSolarAxis"
	add_child(tail_axis)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/comet_tail.gdshader")
	var envelope := VisualFactory.cylinder(1.0, 0.12, 1.0, 24)
	envelope.cap_top = false
	envelope.cap_bottom = false
	var tail := VisualFactory.add_mesh(
		tail_axis, envelope,
		Vector3.UP * radius * 6.0, Vector3(1.8,12.0,1.8)*radius,
		mat, Vector3.ZERO,
		"IonTail"
	)
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_point_tail()


func _point_tail() -> void:
	if is_instance_valid(illuminator):
		var away := illuminator.global_position.direction_to(global_position)
		if away.length_squared() > 0.0:
			tail_axis.global_basis = Basis(Quaternion(Vector3.UP, away))

