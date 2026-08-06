extends Node

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	InputSetup.install_defaults()
	Career.data = Career.default_career()
	Career.data.mode = "PATROL"
	var world_script: Script = load("res://src/game_world.gd")
	var world: GameWorld = world_script.new()
	world.configure("PATROL", true)
	add_child(world)
	for _frame in 8:
		await get_tree().process_frame
	_check(world.fighter != null, "Player fighter exists")
	_check(world.fighter.model_parts.get("root") is Node3D, "Player has a real 3D model")
	_check(world.fighter.camera_rig != null, "Camera rig exists")
	_check(world.star_system != null, "Star system exists")
	_check(world.star_system.dockables.size() == 2, "Station and carrier are available")
	_check(get_tree().get_nodes_in_group("hostile").size() == 4, "Patrol mode spawns four hostiles")
	_check(get_tree().get_nodes_in_group("damageable").size() >= 50, "Detailed hazard field is populated")
	_check(world.hud != null, "Flight HUD exists")
	_check(world.sector_streamer.active_sectors.size() == 9, "Nine nearby sectors are streamed")
	_check(not world.active_contract.is_empty(), "Career contract exists")
	world.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS: 3D flight scene smoke test")
		Sound.shutdown()
		await get_tree().process_frame
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		Sound.shutdown()
		await get_tree().process_frame
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
