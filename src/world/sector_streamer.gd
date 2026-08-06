extends Node3D
class_name SectorStreamer

const SpaceObjectScript := preload("res://src/world/space_object.gd")

var world_seed := 7355608
var sector_size := 900.0
var radius := 1
var active_sectors: Dictionary = {}
var current_sector := Vector3i(999999, 999999, 999999)


func setup(seed_value: int) -> void:
	world_seed = seed_value


func update_stream(logical_position: Vector3) -> void:
	var next_sector := sector_for(logical_position, sector_size)
	if next_sector == current_sector:
		return
	current_sector = next_sector
	var desired: Dictionary = {}
	for x_offset in range(-radius, radius + 1):
		for z_offset in range(-radius, radius + 1):
			var coordinates := Vector3i(current_sector.x + x_offset, 0, current_sector.z + z_offset)
			desired[sector_key(coordinates)] = coordinates
	for key in active_sectors.keys():
		if not desired.has(key):
			var old_sector: Node = active_sectors[key]
			if is_instance_valid(old_sector):
				old_sector.queue_free()
			active_sectors.erase(key)
	for key in desired:
		if not active_sectors.has(key):
			active_sectors[key] = _build_sector(desired[key])


func set_logical_origin(origin_offset: Vector3) -> void:
	global_position = -origin_offset


static func sector_for(position_value: Vector3, size_value: float) -> Vector3i:
	return Vector3i(
		floori(position_value.x / size_value),
		0,
		floori(position_value.z / size_value)
	)


static func sector_key(coordinates: Vector3i) -> String:
	return "%d:%d" % [coordinates.x, coordinates.z]


func _build_sector(coordinates: Vector3i) -> Node3D:
	var root := Node3D.new()
	root.name = "Sector_%d_%d" % [coordinates.x, coordinates.z]
	root.position = Vector3(coordinates.x * sector_size, 0.0, coordinates.z * sector_size)
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(world_seed + coordinates.x * 73856093 + coordinates.z * 83492791)
	var sparse_count := rng.randi_range(2, 5)
	for index in sparse_count:
		var asteroid := SpaceObjectScript.new()
		var asteroid_seed := int(rng.randi())
		asteroid.configure("ASTEROID", rng.randf_range(1.6, 5.5), asteroid_seed, Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.3, 0.3)))
		asteroid.position = Vector3(
			rng.randf_range(-sector_size * 0.42, sector_size * 0.42),
			rng.randf_range(-180.0, 180.0),
			rng.randf_range(-sector_size * 0.42, sector_size * 0.42)
		)
		root.add_child(asteroid)
	return root

