extends Node3D
class_name GameWorld

signal return_to_menu(open_settings: bool)

const StarSystemScript := preload("res://src/world/star_system.gd")
const FighterScript := preload("res://src/player/fighter.gd")
const EnemyScript := preload("res://src/ai/enemy_fighter.gd")
const HUDScript := preload("res://src/ui/hud.gd")
const StreamerScript := preload("res://src/world/sector_streamer.gd")

var mode := "PATROL"
var starting_new := false
var world_seed := 7355608
var star_system: StarSystem
var fighter: PlayerFighter
var hud: FlightHUD
var active_contract: Dictionary = {}
var logical_origin := Vector3.ZERO
var paused := false
var escort_time := 0.0
var objective_root: Node3D
var sector_streamer: SectorStreamer


func configure(game_mode: String, new_career: bool) -> void:
	mode = game_mode
	starting_new = new_career
	world_seed = int(Career.data.get("seed", 7355608))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "FlightSession"
	star_system = StarSystemScript.new()
	star_system.setup(world_seed, mode)
	star_system.object_destroyed.connect(_on_space_object_destroyed)
	star_system.discovery_reached.connect(_on_discovery)
	add_child(star_system)

	fighter = FighterScript.new()
	fighter.position = Vector3(0, 3, 24)
	fighter.interact_requested.connect(_on_interact)
	fighter.destroyed.connect(_on_player_destroyed)
	add_child(fighter)
	sector_streamer = StreamerScript.new()
	sector_streamer.setup(world_seed)
	add_child(sector_streamer)
	sector_streamer.update_stream(fighter.global_position)

	_spawn_hostiles()
	_prepare_contract()
	hud = HUDScript.new()
	hud.setup(fighter, mode, active_contract)
	hud.resume_requested.connect(_set_paused.bind(false))
	hud.exit_requested.connect(_exit_to_menu.bind(false))
	add_child(hud)
	hud.show_toast("%s MODE  •  SHIFT/CTRL THROTTLE  •  V CAMERA" % mode, 5.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_set_paused(not paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_fullscreen"):
		Settings.data.fullscreen = not bool(Settings.data.fullscreen)
		Settings.save()
	elif event.is_action_pressed("toggle_diagnostics") and hud:
		hud.toggle_diagnostics()


func _process(delta: float) -> void:
	if paused or fighter == null or not is_instance_valid(fighter):
		return
	_update_docking_prompt()
	_update_escort(delta)
	sector_streamer.update_stream(logical_origin + fighter.global_position)
	_maybe_shift_origin()


func _spawn_hostiles() -> void:
	var count := 0
	if mode == "PATROL":
		count = 4
	elif mode == "WARZONE":
		count = 8
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 4401
	for index in count:
		var enemy := EnemyScript.new()
		enemy.setup(fighter, world_seed + 500 + index, mode == "WARZONE" and index >= 5)
		enemy.position = Vector3(
			rng.randf_range(-360.0, 360.0),
			rng.randf_range(-120.0, 160.0),
			rng.randf_range(-980.0, -430.0)
		)
		enemy.destroyed.connect(_on_enemy_destroyed)
		add_child(enemy)


func _prepare_contract() -> void:
	if Career.sandbox:
		active_contract = {}
		_build_objective_markers()
		return
	if starting_new or Career.data.get("active_contract", {}).is_empty():
		active_contract = ContractSystem.generate(mode, world_seed, int(Career.data.get("completed_contracts", 0)))
	else:
		active_contract = Career.data.active_contract.duplicate(true)
	Career.data.mode = mode
	Career.data.active_contract = active_contract
	Career.save_atomic()
	_build_objective_markers()


func _build_objective_markers() -> void:
	if objective_root != null and is_instance_valid(objective_root):
		objective_root.queue_free()
	objective_root = Node3D.new()
	objective_root.name = "ContractMarkers"
	add_child(objective_root)
	match str(active_contract.get("type", "")):
		"NAVIGATION":
			_add_gate(Vector3(-420, 120, -980), "NAV_POINT", 0, Color("#52d8ff"))
		"AEROBATICS":
			var target_count := int(active_contract.target)
			for index in target_count:
				var angle := float(index) * 0.65
				_add_gate(Vector3(sin(angle) * 170.0, 35.0 + cos(angle) * 75.0, -360.0 - index * 125.0), "AERO_RING", index, Color("#f6c65b"))
		"DISCOVERY":
			pass
		"COMET":
			pass
		"ESCORT":
			_add_gate(Vector3(420, 55, -690), "ESCORT_ZONE", 0, Color("#7ce8cf"))
		"ELIMINATION":
			pass


func _add_gate(gate_position: Vector3, event_type: String, index: int, color: Color) -> void:
	var gate := Area3D.new()
	gate.name = "%s_%d" % [event_type, index]
	gate.position = gate_position
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 15.0
	collision.shape = shape
	gate.add_child(collision)
	var torus := TorusMesh.new()
	torus.inner_radius = 10.5
	torus.outer_radius = 13.0
	torus.rings = 32
	torus.ring_segments = 8
	VisualFactory.add_mesh(gate, torus, Vector3.ZERO, Vector3.ONE, VisualFactory.material(Color(color, 0.65), 0.2, 0.2, color, true), Vector3.ZERO, "Gate")
	gate.body_entered.connect(_on_gate_entered.bind(event_type, gate))
	objective_root.add_child(gate)


func _on_gate_entered(body: Node3D, event_type: String, gate: Area3D) -> void:
	if body != fighter or not gate.monitoring:
		return
	gate.set_deferred("monitoring", false)
	gate.visible = false
	_record_contract_event(event_type)


func _on_space_object_destroyed(kind: String) -> void:
	if kind == "COMET":
		_record_contract_event("COMET_DESTROYED")
	else:
		Career.add_credits(30)
	if hud:
		hud.show_toast("%s FRAGMENTED  +%d CR" % [kind, 120 if kind == "COMET" else 30])


func _on_enemy_destroyed(_enemy: EnemyFighter, source: Node) -> void:
	if source == fighter:
		Career.add_credits(110)
		_record_contract_event("HOSTILE_DESTROYED")
		if hud:
			hud.show_toast("HOSTILE DESTROYED  +110 CR")


func _on_discovery(site_name: String) -> void:
	var discoveries: Array = Career.data.discoveries
	if site_name not in discoveries:
		discoveries.append(site_name)
		Career.data.discoveries = discoveries
		Career.add_credits(180)
		_record_contract_event("DISCOVERY")
		if hud:
			hud.show_toast("DISCOVERED: %s  +180 CR" % site_name)


func _record_contract_event(event_type: String) -> void:
	if ContractSystem.record_progress(active_contract, event_type):
		_complete_contract()
	else:
		Career.data.active_contract = active_contract
		Career.save_atomic()
		if hud:
			hud.update_contract(active_contract)


func _complete_contract() -> void:
	var reward := int(active_contract.reward)
	Career.data.credits = int(Career.data.credits) + reward
	Career.data.completed_contracts = int(Career.data.completed_contracts) + 1
	if hud:
		hud.show_toast("CONTRACT COMPLETE  +%d CR" % reward, 5.0)
	active_contract = ContractSystem.generate(mode, world_seed, int(Career.data.completed_contracts))
	Career.data.active_contract = active_contract
	Career.save_atomic()
	if hud:
		hud.update_contract(active_contract)
	_build_objective_markers()


func _update_escort(delta: float) -> void:
	if str(active_contract.get("type", "")) != "ESCORT":
		return
	var carrier_node := star_system.dockables[1] if star_system.dockables.size() > 1 else null
	if carrier_node and fighter.global_position.distance_to(carrier_node.global_position) < 145.0:
		escort_time += delta
		if hud:
			hud.set_context("ESCORT FORMATION  %d%%" % int(clampf(escort_time / 25.0, 0.0, 1.0) * 100.0))
		if escort_time >= 25.0:
			escort_time = 0.0
			_record_contract_event("ESCORT_COMPLETE")


func _update_docking_prompt() -> void:
	var nearest := star_system.nearest_dock(fighter)
	if nearest == null:
		hud.set_context("")
		return
	var distance := nearest.distance_to_dock(fighter)
	if distance < 95.0:
		if nearest.can_dock(fighter):
			hud.set_context("F  DOCK WITH %s" % nearest.station_name.to_upper())
		elif not fighter.landing_gear:
			hud.set_context("G  DEPLOY LANDING GEAR  •  %dm" % int(distance))
		else:
			hud.set_context("REDUCE SPEED BELOW 28 m/s  •  %dm" % int(distance))
	elif str(active_contract.get("type", "")) != "ESCORT":
		hud.set_context("")


func _on_interact() -> void:
	var nearest := star_system.nearest_dock(fighter)
	if nearest != null and nearest.can_dock(fighter):
		fighter.dock_at(nearest.dock_transform())
		Career.data.docked_at = nearest.station_name
		Career.save_atomic()
		if hud:
			hud.show_toast("DOCKED  •  REPAIRED  •  REARMED", 4.0)


func _on_player_destroyed() -> void:
	if hud:
		hud.show_toast("FIGHTER LOST — RECOVERY IN PROGRESS", 4.0)
	await get_tree().create_timer(3.0).timeout
	var nearest := star_system.nearest_dock(fighter)
	if nearest:
		fighter.hull = fighter.max_hull
		fighter.shields = fighter.max_shields
		fighter.controls_enabled = true
		fighter.dock_at(nearest.dock_transform())


func _maybe_shift_origin() -> void:
	if fighter.global_position.length() < 1500.0:
		return
	var offset := fighter.global_position
	logical_origin += offset
	for child in get_children():
		if child is Node3D:
			child.global_position -= offset
	sector_streamer.set_logical_origin(logical_origin)
	if hud:
		hud.show_toast("NAVIGATION FRAME RECENTERED", 1.5)


func _set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	if hud:
		hud.set_paused(value)


func _exit_to_menu(open_settings: bool = false) -> void:
	_set_paused(false)
	Career.data.hull = fighter.hull if fighter else 100.0
	Career.data.shields = fighter.shields if fighter else 100.0
	Career.save_atomic()
	return_to_menu.emit(open_settings)
