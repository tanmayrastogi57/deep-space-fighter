extends Node3D
class_name StarSystem

signal object_destroyed(kind: String)
signal discovery_reached(discovery_name: String)

const SpaceObjectScript := preload("res://src/world/space_object.gd")
const StationScript := preload("res://src/world/station.gd")

var world_seed := 7355608
var mode := "PATROL"
var rng := RandomNumberGenerator.new()
var dockables: Array[OrbitalStation] = []


func setup(seed_value: int, game_mode: String) -> void:
	world_seed = seed_value
	mode = game_mode
	rng.seed = world_seed


func _ready() -> void:
	_build_environment()
	_build_starfield(720)
	_build_celestial_bodies()
	_build_landmarks()
	_build_asteroid_regions()
	_build_comets()
	_build_discoveries()


func nearest_dock(fighter: PlayerFighter) -> OrbitalStation:
	var nearest: OrbitalStation
	var nearest_distance := INF
	for dockable in dockables:
		if not is_instance_valid(dockable):
			continue
		var distance := dockable.distance_to_dock(fighter)
		if distance < nearest_distance:
			nearest = dockable
			nearest_distance = distance
	return nearest


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "DeepSpaceEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#01030a")
	sky_material.sky_horizon_color = Color("#01030a")
	sky_material.ground_bottom_color = Color("#000106")
	sky_material.ground_horizon_color = Color("#01030a")
	sky_material.sun_angle_max = 1.0
	sky_material.sun_curve = 0.08
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color("#5f7694")
	environment.ambient_light_energy = 0.28
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var star_light := DirectionalLight3D.new()
	star_light.name = "PrimaryStarLight"
	star_light.light_color = Color("#fff2da")
	star_light.light_energy = 1.35
	star_light.shadow_enabled = true
	star_light.rotation_degrees = Vector3(-32, -48, 0)
	add_child(star_light)


func _build_starfield(count: int) -> void:
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.instance_count = count
	var star_mesh := VisualFactory.sphere(0.36, 8, 4)
	var star_material := VisualFactory.material(Color("#dff3ff"), 0.0, 1.0, Color("#b9e8ff"))
	star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mesh.material = star_material
	multi_mesh.mesh = star_mesh
	for index in count:
		var direction := Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)
		).normalized()
		var distance := rng.randf_range(1300.0, 2600.0)
		var size := rng.randf_range(0.35, 1.55)
		multi_mesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), direction * distance))
	var stars := MultiMeshInstance3D.new()
	stars.name = "StellarBackdrop"
	stars.multimesh = multi_mesh
	add_child(stars)


func _build_celestial_bodies() -> void:
	_add_planet("Helios", Vector3(-1180, 320, -2050), 170.0, Color("#ffdf9a"), true)
	var giant := _add_planet("Caligo", Vector3(940, -80, -1750), 135.0, Color("#9a806c"), false)
	var ring := TorusMesh.new()
	ring.inner_radius = 170.0
	ring.outer_radius = 245.0
	ring.rings = 64
	ring.ring_segments = 8
	VisualFactory.add_mesh(giant, ring, Vector3.ZERO, Vector3.ONE, VisualFactory.material(Color(0.61, 0.57, 0.48, 0.62), 0.0, 0.82, Color.BLACK, true), Vector3(70, 12, 0), "PlanetaryRings")
	_add_planet("Nysa", Vector3(-520, 250, -1320), 72.0, Color("#455c68"), false)
	_add_planet("Nysa Moon", Vector3(-390, 285, -1250), 19.0, Color("#aaa69c"), false)


func _add_planet(body_name: String, body_position: Vector3, radius: float, color: Color, emissive: bool) -> Node3D:
	var root := Node3D.new()
	root.name = body_name
	root.position = body_position
	add_child(root)
	var glow := color * 1.4 if emissive else Color.BLACK
	VisualFactory.add_mesh(root, VisualFactory.sphere(radius, 64, 32), Vector3.ZERO, Vector3.ONE, VisualFactory.material(color, 0.05, 0.78, glow), Vector3.ZERO, "Surface")
	if not emissive:
		VisualFactory.add_mesh(root, VisualFactory.sphere(radius * 1.018, 48, 24), Vector3.ZERO, Vector3.ONE, VisualFactory.material(Color(0.24, 0.55, 0.78, 0.09), 0.0, 0.2, Color("#184e73"), true), Vector3.ZERO, "Atmosphere")
	return root


func _build_landmarks() -> void:
	var station := StationScript.new()
	station.setup("Asteria Station", false)
	station.position = Vector3(0, 0, -260)
	add_child(station)
	dockables.append(station)
	var carrier_node := StationScript.new()
	carrier_node.setup("CSV Resolute", true)
	carrier_node.position = Vector3(420, 55, -690)
	carrier_node.rotation_degrees.y = 28.0
	add_child(carrier_node)
	dockables.append(carrier_node)


func _build_asteroid_regions() -> void:
	_spawn_asteroid_field(Vector3(-250, 20, -720), Vector3(410, 180, 380), 34, 2.0, 10.0)
	_spawn_asteroid_field(Vector3(510, -70, -1120), Vector3(260, 160, 310), 18, 3.5, 14.0)


func _spawn_asteroid_field(center: Vector3, spread: Vector3, count: int, minimum_radius: float, maximum_radius: float) -> void:
	for index in count:
		var asteroid := SpaceObjectScript.new()
		var radius := rng.randf_range(minimum_radius, maximum_radius)
		asteroid.configure("ASTEROID", radius, world_seed + index + int(center.z))
		asteroid.position = center + Vector3(
			rng.randf_range(-spread.x, spread.x),
			rng.randf_range(-spread.y, spread.y),
			rng.randf_range(-spread.z, spread.z)
		)
		asteroid.destroyed.connect(_on_space_object_destroyed)
		add_child(asteroid)


func _build_comets() -> void:
	for index in 2:
		var comet := SpaceObjectScript.new()
		comet.configure("COMET", 9.0 + index * 3.0, world_seed + 9000 + index, Vector3(-8.0 - index * 3.0, 0.5, 17.0 + index * 2.0))
		comet.position = Vector3(680 + index * 210, 210 - index * 130, -1450 - index * 260)
		comet.destroyed.connect(_on_space_object_destroyed)
		add_child(comet)


func _build_discoveries() -> void:
	var sites := {
		"The Glass Horizon": Vector3(720, 170, -940),
		"Silent Relay": Vector3(-680, -110, -1040),
		"Caligo Overlook": Vector3(760, 10, -1510)
	}
	for site_name in sites:
		var area := Area3D.new()
		area.name = site_name
		area.position = sites[site_name]
		area.add_to_group("discovery")
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 32.0
		collision.shape = shape
		area.add_child(collision)
		area.body_entered.connect(_on_discovery_body_entered.bind(site_name, area))
		add_child(area)


func _on_space_object_destroyed(object: SpaceObject, _source: Node) -> void:
	object_destroyed.emit(object.object_kind)


func _on_discovery_body_entered(body: Node3D, site_name: String, area: Area3D) -> void:
	if body is PlayerFighter:
		discovery_reached.emit(site_name)
		area.set_deferred("monitoring", false)
