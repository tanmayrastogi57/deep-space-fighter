extends RefCounted
class_name VisualFactory


static func material(
	color: Color,
	metallic: float = 0.0,
	roughness: float = 0.65,
	emission: Color = Color.BLACK,
	transparent: bool = false
) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	if emission != Color.BLACK:
		result.emission_enabled = true
		result.emission = emission
		result.emission_energy_multiplier = 1.55
	if transparent:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result


static func add_mesh(
	parent: Node3D,
	mesh: Mesh,
	position: Vector3,
	scale_value: Vector3,
	surface_material: Material,
	rotation_degrees_value: Vector3 = Vector3.ZERO,
	name_value: String = "Part"
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name_value
	instance.mesh = mesh
	instance.position = position
	instance.scale = scale_value
	instance.rotation_degrees = rotation_degrees_value
	instance.material_override = surface_material
	parent.add_child(instance)
	return instance


static func cylinder(top_radius: float, bottom_radius: float, height: float, segments: int = 24) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	return mesh


static func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func sphere(radius: float, radial_segments: int = 32, rings: int = 16) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial_segments
	mesh.rings = rings
	return mesh


static func delta_wing_mesh(span: float, length: float, thickness: float) -> ArrayMesh:
	var half_span := span * 0.5
	var half_thickness := thickness * 0.5
	var half_length := length * 0.5
	var footprint := [
		Vector3(0.0, half_thickness, -half_length),
		Vector3(half_span, half_thickness, half_length * 0.72),
		Vector3(0.72, half_thickness, half_length),
		Vector3(-0.72, half_thickness, half_length),
		Vector3(-half_span, half_thickness, half_length * 0.72)
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle in [[0, 1, 2], [0, 2, 3], [0, 3, 4]]:
		_add_triangle(surface, footprint[triangle[0]], footprint[triangle[1]], footprint[triangle[2]], Vector2.ZERO, Vector2.RIGHT, Vector2.ONE)
	for triangle in [[0, 2, 1], [0, 3, 2], [0, 4, 3]]:
		var first: Vector3 = footprint[triangle[0]] - Vector3(0, thickness, 0)
		var second: Vector3 = footprint[triangle[1]] - Vector3(0, thickness, 0)
		var third: Vector3 = footprint[triangle[2]] - Vector3(0, thickness, 0)
		_add_triangle(surface, first, second, third, Vector2.ZERO, Vector2.ONE, Vector2.RIGHT)
	for edge_index in footprint.size():
		var next_index := (edge_index + 1) % footprint.size()
		var top_a: Vector3 = footprint[edge_index]
		var top_b: Vector3 = footprint[next_index]
		var bottom_a := top_a - Vector3(0, thickness, 0)
		var bottom_b := top_b - Vector3(0, thickness, 0)
		_add_triangle(surface, top_a, bottom_a, bottom_b, Vector2.ZERO, Vector2.DOWN, Vector2.ONE)
		_add_triangle(surface, top_a, bottom_b, top_b, Vector2.ZERO, Vector2.ONE, Vector2.RIGHT)
	surface.generate_normals()
	return surface.commit()


static func build_fighter(parent: Node3D, hostile: bool = false) -> Dictionary:
	var root := Node3D.new()
	root.name = "FighterModel"
	parent.add_child(root)

	var hull_color := Color("#7c8995") if not hostile else Color("#47383a")
	var panel_color := Color("#253746") if not hostile else Color("#33191d")
	var accent_color := Color("#b8d7e7") if not hostile else Color("#8f292f")
	var hull := material(hull_color, 0.33, 0.42)
	hull.rim_enabled = true
	hull.rim = 0.20
	hull.cull_mode = BaseMaterial3D.CULL_DISABLED
	var panels := material(panel_color, 0.72, 0.38)
	var accents := material(accent_color, 0.76, 0.24)
	var dark_metal := material(Color("#101820"), 0.92, 0.22)
	var canopy := material(Color(0.025, 0.16, 0.24, 0.78), 0.45, 0.08, Color("#0d4f70"), true)
	var engine_color := Color("#ff5b35") if hostile else Color("#42d9ff")
	var engine_material := ShaderMaterial.new()
	engine_material.shader = preload("res://assets/shaders/exhaust.gdshader")
	engine_material.set_shader_parameter("tint", engine_color)
	var plumes: Array[Node3D] = []
	var frame := preload("res://src/world/airframe.gd")

	add_mesh(root, frame.fuselage(), Vector3.ZERO, Vector3.ONE, hull, Vector3.ZERO, "MainHull")
	add_mesh(root, delta_wing_mesh(9.3, 4.7, 0.18), Vector3(0, -0.08, 0.34), Vector3.ONE, hull, Vector3.ZERO, "MainWing")
	add_mesh(root, box(Vector3(2.4, 0.1, 1.25)), Vector3(0, 0.26, 2.62), Vector3.ONE, panels, Vector3(0, 0, 0), "TailPlane")
	add_mesh(root, sphere(0.72, 28, 14), Vector3(0, 0.48, -1.16), Vector3(0.72, 0.52, 1.45), canopy, Vector3.ZERO, "Canopy")

	for side in [-1.0, 1.0]:
		var fin := add_mesh(root, delta_wing_mesh(1.1,2.3,0.14), Vector3(side*1.19,0.85,1.95), Vector3(2.25,1,1), hull, Vector3(-14,0,side*62), "CantedFin")
		frame.beam(root, Vector3(side*1.4,0.05,1.25),Vector3(side*3.82,0.05,1.61),0.12,0.025,accents,"ElevonTrim")
		frame.beam(root, fin.position + Vector3(side*0.25,0.48,0.40), fin.position + Vector3(side*0.34,0.68,0.43),0.09,0.04,accents,"FinTip")
		add_mesh(root, cylinder(0.46, 0.52, 3.15), Vector3(side * 1.52, -0.05, 1.34), Vector3.ONE, panels, Vector3(90, 0, 0), "EnginePod")
		var cowl := cylinder(0.46,0.52,0.67,16)
		cowl.cap_top = false
		accents.cull_mode = BaseMaterial3D.CULL_DISABLED
		add_mesh(root,cowl, Vector3(side*1.52,-0.05,3.05),Vector3.ONE,accents,Vector3(90,0,0),"NozzleLip")
		add_mesh(root,cylinder(0.34,0.34,0.05,16),Vector3(side*1.52,-0.05,2.98),Vector3.ONE,material(engine_color.darkened(0.55),0.2,0.45,engine_color.darkened(0.42)),Vector3(90,0,0),"HotCore")
		var nozzle := Node3D.new()
		nozzle.name = "ExhaustPort" if side < 0 else "ExhaustStarboard"
		nozzle.position = Vector3(side*1.52,-0.05,3.15)
		root.add_child(nozzle)
		var flame := add_mesh(nozzle,cylinder(0.035,0.32,1.0,16),Vector3(0,0,0.5),Vector3.ONE,engine_material,Vector3(90,0,0),"Plume")
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plumes.append(nozzle)
		add_mesh(root, cylinder(0.1, 0.1, 1.7), Vector3(side * 2.25, -0.22, 0.7), Vector3.ONE, dark_metal, Vector3(90, 0, 0), "WeaponHardpoint")

	var gear := Node3D.new()
	gear.name = "LandingGear"
	root.add_child(gear)
	for gear_position in [Vector3(-1.55, -0.8, 1.2), Vector3(1.55, -0.8, 1.2), Vector3(0, -0.72, -2.25)]:
		add_mesh(gear, cylinder(0.055, 0.055, 0.95, 12), gear_position, Vector3.ONE, dark_metal, Vector3(0, 0, 12), "GearStrut")
		add_mesh(gear, cylinder(0.18, 0.18, 0.12, 16), gear_position + Vector3(0, -0.48, 0), Vector3.ONE, panels, Vector3(0, 0, 90), "GearWheel")
	gear.visible = false

	var navigation_light := OmniLight3D.new()
	navigation_light.name = "NavigationLight"
	navigation_light.light_color = engine_color
	navigation_light.light_energy = 0.7
	navigation_light.omni_range = 7.0
	navigation_light.position = Vector3(0, 0, 2.9)
	root.add_child(navigation_light)

	if not hostile:
		for geom in root.find_children("*", "GeometryInstance3D", true, false):
			geom.layers = frame.EXTERIOR
	return {
		"root": root,
		"gear": gear,
		"plumes": plumes
	}


static func asteroid_mesh(seed_value: int, radius: float, rings: int = 12, segments: int = 18) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring_index in rings:
		var v0 := float(ring_index) / float(rings)
		var v1 := float(ring_index + 1) / float(rings)
		for segment_index in segments:
			var u0 := float(segment_index) / float(segments)
			var u1 := float(segment_index + 1) / float(segments)
			var p00 := _asteroid_point(seed_value, radius, v0, u0)
			var p01 := _asteroid_point(seed_value, radius, v0, u1)
			var p10 := _asteroid_point(seed_value, radius, v1, u0)
			var p11 := _asteroid_point(seed_value, radius, v1, u1)
			_add_triangle(surface, p00, p10, p11, Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1))
			_add_triangle(surface, p00, p11, p01, Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v0))
	surface.generate_normals()
	return surface.commit()


static func _asteroid_point(seed_value: int, radius: float, latitude: float, longitude: float) -> Vector3:
	var theta := latitude * PI
	var phi := longitude * TAU
	var variation := (
		1.0
		+ sin(phi * 3.0 + float(seed_value) * 0.017) * 0.095
		+ sin(theta * 5.0 - phi * 2.0 + float(seed_value) * 0.031) * 0.072
		+ cos(theta * 7.0 + phi * 4.0 + float(seed_value) * 0.007) * 0.045
	)
	return Vector3(
		sin(theta) * cos(phi),
		cos(theta),
		sin(theta) * sin(phi)
	) * radius * variation


static func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	surface.set_uv(uv_a)
	surface.add_vertex(a)
	surface.set_uv(uv_b)
	surface.add_vertex(b)
	surface.set_uv(uv_c)
	surface.add_vertex(c)


static func spawn_explosion(parent: Node, world_position: Vector3, radius: float, color: Color = Color("#ff9c45")) -> void:
	var flash := MeshInstance3D.new()
	flash.name = "Explosion"
	flash.mesh = sphere(1.0, 20, 10)
	flash.material_override = material(Color(color, 0.52), 0.0, 0.15, color, true)
	flash.scale = Vector3.ONE * 0.08
	parent.add_child(flash)
	flash.global_position = world_position
	var debris := GPUParticles3D.new()
	debris.name = "ExplosionDebris"
	debris.amount = 42
	debris.lifetime = 0.82
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.randomness = 0.72
	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = radius * 0.12
	particle_material.direction = Vector3.UP
	particle_material.spread = 180.0
	particle_material.initial_velocity_min = radius * 2.2
	particle_material.initial_velocity_max = radius * 5.0
	particle_material.gravity = Vector3.ZERO
	particle_material.scale_min = 0.35
	particle_material.scale_max = 1.4
	particle_material.color = color
	debris.process_material = particle_material
	var particle_mesh := sphere(maxf(0.035, radius * 0.035), 6, 3)
	particle_mesh.material = material(color, 0.05, 0.25, color)
	debris.draw_pass_1 = particle_mesh
	parent.add_child(debris)
	debris.global_position = world_position
	debris.emitting = true
	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * radius, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "transparency", 1.0, 0.36)
	tween.chain().tween_callback(flash.queue_free)
	var debris_timer := debris.get_tree().create_timer(1.25)
	debris_timer.timeout.connect(debris.queue_free)
