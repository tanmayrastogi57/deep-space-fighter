extends RefCounted
class_name FlightMath


static func step_throttle(current: float, increase: float, decrease: float, delta: float, rate: float = 0.34) -> float:
	return clampf(current + (increase - decrease) * rate * delta, 0.0, 1.0)


static func assisted_velocity(
	current: Vector3,
	forward: Vector3,
	throttle: float,
	minimum_speed: float,
	maximum_speed: float,
	acceleration: float,
	delta: float,
	assist_strength: float
) -> Vector3:
	var target_speed := lerpf(minimum_speed, maximum_speed, clampf(throttle, 0.0, 1.0))
	var desired := forward.normalized() * target_speed
	if assist_strength <= 0.0:
		return current + forward.normalized() * acceleration * throttle * delta
	var response := clampf(acceleration * delta / maxf(target_speed, 1.0), 0.0, 1.0)
	return current.lerp(desired, response * clampf(assist_strength, 0.0, 1.0))


static func impact_damage(relative_speed: float, object_mass: float, shield_fraction: float) -> float:
	var energy_term := maxf(0.0, relative_speed - 8.0) * sqrt(maxf(object_mass, 0.1)) * 0.085
	return energy_term * lerpf(1.0, 0.38, clampf(shield_fraction, 0.0, 1.0))


static func intercept_direction(origin: Vector3, projectile_speed: float, target_position: Vector3, target_velocity: Vector3) -> Vector3:
	var relative := target_position - origin
	if projectile_speed <= 0.001:
		return relative.normalized()
	var a := target_velocity.length_squared() - projectile_speed * projectile_speed
	var b := 2.0 * relative.dot(target_velocity)
	var c := relative.length_squared()
	var time := 0.0
	if absf(a) < 0.0001:
		time = -c / b if absf(b) > 0.0001 else 0.0
	else:
		var discriminant := b * b - 4.0 * a * c
		if discriminant >= 0.0:
			var root := sqrt(discriminant)
			var first := (-b - root) / (2.0 * a)
			var second := (-b + root) / (2.0 * a)
			if first > 0.0 and second > 0.0:
				time = minf(first, second)
			else:
				time = maxf(first, second)
	if time <= 0.0:
		return relative.normalized()
	return (relative + target_velocity * time).normalized()

