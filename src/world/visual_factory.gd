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


static func build_fighter(parent: Node3D, hostile: bool = false) -> Dictionary:
	var root := Node3D.new()
	root.name = "FighterModel"
	parent.add_child(root)

	var hull_color := Color("#7c8995") if not hostile else Color("#47383a")
	var panel_color := Color("#253746") if not hostile else Color("#33191d")
	var accent_color := Color("#b8d7e7") if not hostile else Color("#8f292f")
	var hull := material(hull_color, 0.82, 0.29)
	var panels := material(panel_color, 0.72, 0.38)
	var accents := material(accent_color, 0.76, 0.24)
	var dark_metal := material(Color("#101820"), 0.92, 0.22)
	var canopy := material(Color(0.025, 0.16, 0.24, 0.78), 0.45, 0.08, Color("#0d4f70"), true)
	var engine_color := Color("#ff5b35") if hostile else Color("#42d9ff")
	var engine_material := material(Color(engine_color, 0.78), 0.05, 0.12, engine_color, true)

	add_mesh(root, cylinder(0.58, 0.78, 4.4), Vector3(0, 0, 0.2), Vector3.ONE, hull, Vector3(90, 0, 0), "MainHull")
	add_mesh(root, cylinder(0.025, 0.58, 2.9), Vector3(0, 0, -3.42), Vector3.ONE, hull, Vector3(-90, 0, 0), "Nose")
	add_mesh(root, cylinder(0.82, 0.72, 1.75), Vector3(0, 0, 3.12), Vector3.ONE, panels, Vector3(90, 0, 0), "AftHull")
	add_mesh(root, box(Vector3(6.3, 0.16, 2.45)), Vector3(0, -0.08, 0.72), Vector3.ONE, hull, Vector3(0, 0, 0), "MainWing")
	add_mesh(root, box(Vector3(4.9, 0.09, 0.52)), Vector3(0, 0.04, -0.55), Vector3.ONE, accents, Vector3(0, 0, 0), "WingPanel")
	add_mesh(root, box(Vector3(2.4, 0.1, 1.25)), Vector3(0, 0.26, 2.62), Vector3.ONE, panels, Vector3(0, 0, 0), "TailPlane")
	add_mesh(root, box(Vector3(0.12, 1.45, 1.3)), Vector3(0, 0.78, 2.62), Vector3.ONE, accents, Vector3(-12, 0, 0), "VerticalTail")
	add_mesh(root, sphere(0.72, 28, 14), Vector3(0, 0.48, -1.16), Vector3(0.72, 0.52, 1.45), canopy, Vector3.ZERO, "Canopy")

	for side in [-1.0, 1.0]:
		add_mesh(root, cylinder(0.46, 0.52, 3.15), Vector3(side * 1.52, -0.05, 1.34), Vector3.ONE, panels, Vector3(90, 0, 0), "EnginePod")
		add_mesh(root, cylinder(0.37, 0.37, 0.22), Vector3(side * 1.52, -0.05, 2.98), Vector3.ONE, dark_metal, Vector3(90, 0, 0), "EngineNozzle")
		add_mesh(root, cylinder(0.28, 0.42, 2.15), Vector3(side * 1.52, -0.05, 4.05), Vector3.ONE, engine_material, Vector3(90, 0, 0), "EnginePlume")
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

	return {
		"root": root,
		"gear": gear,
		"plumes": root.find_children("EnginePlume", "MeshInstance3D", true, false)
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
	flash.global_position = world_position
	flash.scale = Vector3.ONE * 0.08
	parent.add_child(flash)
	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * radius, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "transparency", 1.0, 0.36)
	tween.chain().tween_callback(flash.queue_free)
