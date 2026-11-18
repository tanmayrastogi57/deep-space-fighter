extends Node

var failures: Array[String] = []
var checks := 0


func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	InputSetup.install_defaults()
	Career.begin_sandbox("EXPLORER")
	var world := GameWorld.new()
	world.configure("EXPLORER",false)
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var fighter := world.fighter
	var rig := fighter.camera_rig
	var plumes: Array = fighter.model_parts.plumes
	expect(plumes.size() == 2, "Two exhaust anchors, independent of auto-generated node names")
	var idle_front: Vector3 = plumes[0].position
	for throttle in [0.0,0.5,1.0]:
		fighter.throttle = throttle
		fighter._update_engine_visuals()
		expect(plumes[0].scale == plumes[1].scale and plumes[0].position == idle_front, "Both exhausts grow from their nozzles")
		expect(is_equal_approx(plumes[0].scale.z,lerpf(.32,2.4,throttle)),"Plume scales along ship's aft axis")
	for view in [FighterCameraRig.ViewMode.COCKPIT,FighterCameraRig.ViewMode.FAR_CHASE,FighterCameraRig.ViewMode.CLOSE_CHASE]:
		rig.mode = view
		rig._process(.016)
		var inside: bool = view == FighterCameraRig.ViewMode.COCKPIT
		expect(rig.camera.get_cull_mask_value(2) != inside and rig.camera.get_cull_mask_value(3) == inside, "View sees exactly one pilot model")
		expect(rig.camera.get_cull_mask_value(1), "Other ships and landmarks remain visible")
	Input.action_press("rear_view")
	rig._process(.016)
	expect(not rig.camera.get_cull_mask_value(2) and not rig.camera.get_cull_mask_value(3),"Rear sightline excludes both pilot models")
	Input.action_release("rear_view")
	var system := world.star_system
	var surfaces := []
	for body in ["Nysa","Nysa Moon","Caligo","Helios"]:
		surfaces.append(system.get_node(body+"/Surface").material_override.get_shader_parameter("kind"))
	expect(surfaces == [0,1,2,3], "Four distinct celestial treatments")
	var ring: MeshInstance3D = system.get_node("Caligo/PlanetaryRings")
	expect(ring.mesh.get_aabb().size.y < .01 and ring.rotation.length() > .1,"Thin tilted annulus, not a torus")
	expect(system.has_node("Helios/Corona"),"Helios has a separate soft corona")
	var comet: SpaceObject = get_tree().get_first_node_in_group("comets")
	var expected := comet.illuminator.global_position.direction_to(comet.global_position)
	var initial_basis := comet.nucleus.basis
	var initial_drift := comet.drift
	comet.drift = Vector3.ZERO
	for i in 60:
		comet._physics_process(.125)
	expect(not comet.nucleus.basis.is_equal_approx(initial_basis) and comet.tail_axis.global_basis.y.dot(expected) > .9999, "Rotating comet nucleus does not swing the anti-solar tail")
	comet.drift = initial_drift
	var materials := {}
	for rock in get_tree().get_nodes_in_group("damageable"):
		if rock is SpaceObject:
			if materials.has(rock.composition) and materials[rock.composition] != rock.nucleus.material_override:
				failures.append("Duplicate geology material")
			materials[rock.composition] = rock.nucleus.material_override
	expect(materials.size() == 3, "Three shared geological families")
	for site in get_tree().get_nodes_in_group("discovery"):
		expect(site.has_node("Landmark") and not site.get_node("Landmark").find_children("*","GeometryInstance3D",true,false).is_empty(),str(site.name)+" is visibly authored")
	expect(system.get_node("DepartureLights").get_child_count() == 20,"Ten paired lane fixtures, without extra physics bodies")

	# Fly for two simulated minutes through the actual physics/stream/rebase loop.
	world._operations_action("launch")
	fighter.global_basis = Basis(Vector3.RIGHT,PI/2.0)
	fighter.velocity = Vector3.UP*fighter.maximum_speed
	fighter.throttle = 1.0
	var streamer := world.sector_streamer
	var initial_rock: SpaceObject = streamer.active_sectors["0:0:0"].get_child(0)
	var rock_seed := initial_rock.seed_value
	var max_population := 0
	var valid_neighborhood := true
	for second in 120:
		for tick in 60:
			await get_tree().physics_frame
		var count := 0
		for cell in streamer.active_sectors.values():
			count += cell.get_child_count()
		max_population = maxi(max_population,count)
		valid_neighborhood = valid_neighborhood and streamer.active_sectors.size() == 27 and count >= 27
	var altitude := (world.logical_origin+fighter.global_position).y
	expect(altitude > 16000 and streamer.current_sector.y >= 17 and world.logical_origin.y > 10000,"Vertical flight remains populated beyond multiple origin shifts")
	expect(valid_neighborhood and max_population <= 35,"Bounded 3D neighborhood during ascent")
	streamer.update_stream(Vector3.ZERO)
	expect(streamer.active_sectors["0:0:0"].get_child(0).seed_value == rock_seed,"Revisiting a cell regenerates its original seeded geometry")
	print("Ascent: %.0f m in 120 simulated seconds; maximum %d active streamed rocks" % [altitude,max_population])
	world.queue_free()
	await get_tree().process_frame
	Career.end_sandbox()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: %d flight art and long-distance checks" % checks)
	get_tree().quit(0 if failures.is_empty() else 1)
