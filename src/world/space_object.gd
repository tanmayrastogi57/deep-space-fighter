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


func configure(kind: String, object_radius: float, seed_number: int, initial_velocity: Vector3 = Vector3.ZERO) -> void:
	object_kind = kind
	radius = object_radius
	seed_value = seed_number
	drift = initial_velocity
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
	var rock_color := Color("#7e817f") if object_kind != "COMET" else Color("#a8cbd2")
	var rock := VisualFactory.add_mesh(
		self,
		VisualFactory.asteroid_mesh(seed_value, radius, 12 if radius < 8.0 else 18, 18 if radius < 8.0 else 26),
		Vector3.ZERO,
		Vector3.ONE,
		VisualFactory.material(rock_color, 0.12, 0.88),
		Vector3.ZERO,
		object_kind.capitalize() + "Mesh"
	)
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	rotation_axis = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
	rotation_speed = rng.randf_range(0.035, 0.16)
	if object_kind == "COMET":
		_build_comet_tail()


func _physics_process(delta: float) -> void:
	rotate(rotation_axis, rotation_speed * delta)
	velocity = drift
	if drift.length_squared() > 0.0:
		move_and_slide()


func damage(amount: float, source: Node = null) -> void:
	health -= maxf(0.0, amount)
	if health <= 0.0:
		VisualFactory.spawn_explosion(get_parent(), global_position, radius * 1.6, Color("#9edbe5") if object_kind == "COMET" else Color("#f0a661"))
		Sound.play_effect("impact", clampf(radius / 8.0, 0.35, 1.0))
		destroyed.emit(self, source)
		queue_free()


func _build_comet_tail() -> void:
	var tail := VisualFactory.add_mesh(
		self,
		VisualFactory.cylinder(0.1, radius * 0.62, radius * 8.0, 18),
		Vector3(0, 0, radius * 4.4),
		Vector3.ONE,
		VisualFactory.material(Color(0.35, 0.78, 1.0, 0.22), 0.0, 0.1, Color("#4cbfe9"), true),
		Vector3(90, 0, 0),
		"IonTail"
	)
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

