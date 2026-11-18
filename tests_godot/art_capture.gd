extends Node

# Run with a graphics device. The optional -- --before keeps baseline images separate.
var directory := "res://.godot/art-after"
var world: GameWorld
var errors := 0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _shot(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.save_png(directory.path_join(label + ".png")) != OK:
		errors += 1
	if label == "chase":
		img.convert(Image.FORMAT_L8)
		img.save_png(directory.path_join("chase-values.png"))


func _run() -> void:
	if "--before" in OS.get_cmdline_user_args():
		directory = "res://.godot/art-before"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	InputSetup.install_defaults()
	Career.begin_sandbox("EXPLORER")
	world = GameWorld.new()
	world.configure("EXPLORER", false)
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	world.hud.operations.hide()
	world.hud.pause_overlay.hide()
	var rig := world.fighter.camera_rig
	rig.set_process(false)
	for i in 15:
		rig._process(0.05)
	await _shot("chase")
	world.fighter.throttle = 1.0
	world.fighter._update_engine_visuals()
	await _shot("full-throttle")
	rig.mode = FighterCameraRig.ViewMode.COCKPIT
	for i in 15:
		rig._process(0.05)
	await _shot("cockpit")
	Input.action_press("rear_view")
	for i in 15:
		rig._process(0.05)
	await _shot("rear")
	Input.action_release("rear_view")
	Input.action_press("free_look")
	for yaw in [-2.6, 2.6]:
		rig.look_yaw = yaw
		rig.look_pitch = 0.45
		rig._process(0.05)
		await _shot("left" if yaw < 0 else "right")
	Input.action_release("free_look")
	world.hud.hide()
	var survey_camera := Camera3D.new()
	survey_camera.far = 7000
	world.add_child(survey_camera)
	survey_camera.make_current()
	for site in world.star_system.get_tree().get_nodes_in_group("discovery"):
		var p: Vector3 = site.global_position
		var approach := Vector3(0, 13, 115)
		if str(site.name) == "Caligo Overlook":
			approach = (p - world.star_system.get_node("Caligo").global_position).normalized() * 125
		survey_camera.look_at_from_position(p + approach, p, Vector3.UP)
		await _shot(str(site.name).to_snake_case())
	var comet: Node3D = get_tree().get_first_node_in_group("comets")
	survey_camera.look_at_from_position(comet.global_position + Vector3(30, 25, 125), comet.global_position + Vector3(20,0,0), Vector3.UP)
	await _shot("comet")
	Sound.shutdown()
	world.queue_free()
	await get_tree().process_frame
	Career.end_sandbox()
	print("Captured flight art in ", directory)
	get_tree().quit(errors)
