extends Node

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	InputSetup.install_defaults()
	Career.save_path = "user://smoke-%d.json" % OS.get_process_id()
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
	_check(world.sector_streamer.active_sectors.size() == 27, "A bounded 3D neighborhood is streamed")
	_check(not world.active_contract.is_empty(), "Career contract exists")
	_check(world.paused and world.hud.operations.visible and not world.fighter.can_process(), "Preflight holds the ship")
	var enemy: Node3D = get_tree().get_first_node_in_group("hostile")
	var start := world.fighter.position
	var enemy_start := enemy.position
	Input.action_press("throttle_up")
	for i in 12:
		await get_tree().physics_frame
	_check(world.fighter.position == start and world.fighter.throttle == 0 and enemy.position == enemy_start, "Briefing is safe without a timeout")
	world._operations_action("launch")
	for i in 45:
		await get_tree().physics_frame
	Input.action_release("throttle_up")
	_check(int(Career.data.chapter_step) == 1, "Throttle lesson advances to the gate")
	var gate := world._objective_target()
	_check(gate != null and world.hud.destination == "Asteria training gate", "Gate is named in navigation")
	world.fighter.global_position = gate.global_position
	for i in 5:
		await get_tree().physics_frame
	_check(int(Career.data.chapter_step) == 2, "Physical gate entry advances the lesson")
	var station := world.star_system.dockables[0]
	world.fighter.global_position = station.dock_transform().origin
	world.fighter.velocity = Vector3.ZERO
	world.fighter.landing_gear = true
	world._on_interact()
	_check(int(Career.data.chapter_step) == 3 and Career.data.credits == 3300, "Dock earns the licence and qualification payout")
	_check(world.panel == "board" and world.paused, "Docking opens the station board safely")
	world._operations_action("launch")
	var overlook := world._objective_target()
	_check(overlook != null and overlook.name == "Caligo Overlook", "Chapter has a named final destination")
	world.fighter.global_position = overlook.global_position
	world._process(0.016)
	_check(int(Career.data.chapter_step) == 4 and world.active_contract.is_empty(), "Survey finishes the chapter without ending free roam")
	_check(Career.load_career() and int(Career.data.chapter_step) == 4, "Chapter milestones survive a real reload")
	world._open_board()
	_check(world.board_offers.size() in [2,3], "Dock offers a choice of reachable jobs")
	world._operations_action("job:1")
	await get_tree().process_frame
	_check(world.active_contract.get("type") == "AEROBATICS" and not world.paused, "Accepting a board offer starts the chosen route")
	world._record_contract_event("AERO_RING")
	var wallet: int = Career.data.credits
	world._set_paused(true)
	world._operations_action("abandon_prompt")
	world._operations_action("cancel_abandon")
	_check(int(world.active_contract.progress) == 1, "Cancelling abandonment retains partial progress")
	world._operations_action("abandon_prompt")
	world._operations_action("abandon")
	_check(world.active_contract.is_empty() and Career.data.credits == wallet, "Abandon clears the partial job without charging credits")
	world.queue_free()
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(Career.save_path + suffix):
			DirAccess.remove_absolute(Career.save_path + suffix)
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
