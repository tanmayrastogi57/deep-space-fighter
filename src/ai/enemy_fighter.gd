extends CharacterBody3D
class_name EnemyFighter

signal destroyed(enemy: EnemyFighter, source: Node)

enum State { PATROL, PURSUE, ATTACK, EVADE, RETREAT }

var target: PlayerFighter
var state := State.PATROL
var health := 64.0
var speed := 74.0
var turn_rate := 1.15
var fire_cooldown := 0.8
var seed_value := 0
var patrol_point := Vector3.ZERO


func setup(player: PlayerFighter, seed_number: int, heavy: bool = false) -> void:
	target = player
	seed_value = seed_number
	if heavy:
		health = 115.0
		speed = 63.0
		turn_rate = 0.82


func _ready() -> void:
	name = "HostileFighter_%d" % seed_value
	add_to_group("hostile")
	add_to_group("damageable")
	collision_layer = 1
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.2
	capsule.height = 6.2
	collision.shape = capsule
	collision.rotation_degrees = Vector3(90, 0, 0)
	add_child(collision)
	VisualFactory.build_fighter(self, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	patrol_point = global_position + Vector3(rng.randf_range(-120, 120), rng.randf_range(-60, 60), rng.randf_range(-120, 120))


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	var distance := global_position.distance_to(target.global_position)
	_update_state(distance)
	var desired_direction := -global_transform.basis.z
	match state:
		State.PATROL:
			desired_direction = global_position.direction_to(patrol_point)
		State.PURSUE, State.ATTACK:
			desired_direction = FlightMath.intercept_direction(global_position, speed, target.global_position, target.velocity)
		State.EVADE:
			desired_direction = global_position.direction_to(target.global_position).cross(global_transform.basis.y).normalized()
		State.RETREAT:
			desired_direction = target.global_position.direction_to(global_position)
	var current_forward := -global_transform.basis.z
	var steered := current_forward.slerp(desired_direction, clampf(turn_rate * delta, 0.0, 1.0)).normalized()
	if steered.length_squared() > 0.0:
		look_at(global_position + steered, global_transform.basis.y)
	velocity = steered * speed
	move_and_slide()
	if state == State.ATTACK and fire_cooldown <= 0.0 and current_forward.angle_to(global_position.direction_to(target.global_position)) < 0.18:
		fire_cooldown = 1.15
		target.apply_damage(5.5)
		Sound.play_effect("cannon", 0.28)


func _update_state(distance: float) -> void:
	if health < 18.0:
		state = State.RETREAT
	elif distance < 42.0:
		state = State.EVADE
	elif distance < 180.0:
		state = State.ATTACK
	elif distance < 520.0:
		state = State.PURSUE
	else:
		state = State.PATROL


func damage(amount: float, source: Node = null) -> void:
	health -= maxf(0.0, amount)
	if health <= 0.0:
		VisualFactory.spawn_explosion(get_parent(), global_position, 5.5, Color("#ff573b"))
		Sound.play_effect("impact", 0.75)
		destroyed.emit(self, source)
		queue_free()

