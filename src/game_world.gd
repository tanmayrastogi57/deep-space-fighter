extends Node3D
class_name GameWorld

signal return_to_menu(open_settings: bool)

const StarSystemScript := preload("res://src/world/star_system.gd")
const FighterScript := preload("res://src/player/fighter.gd")
const EnemyScript := preload("res://src/ai/enemy_fighter.gd")
const HUDScript := preload("res://src/ui/hud.gd")
const StreamerScript := preload("res://src/world/sector_streamer.gd")
const Chapter := preload("res://src/systems/first_chapter.gd")

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
var guidance_timer := 0.0
var panel := ""
var board_offers: Array[Dictionary] = []
var docked := false


func configure(game_mode: String, new_career: bool) -> void:
	mode = game_mode
	starting_new = new_career
	world_seed = int(Career.data.get("seed", 7355608))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "FlightSession"
	star_system = StarSystemScript.new()
	star_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	star_system.setup(world_seed, mode)
	star_system.object_destroyed.connect(_on_space_object_destroyed)
	star_system.discovery_reached.connect(_on_discovery)
	add_child(star_system)

	fighter = FighterScript.new()
	fighter.process_mode = Node.PROCESS_MODE_PAUSABLE
	fighter.throttle = 0
	fighter.position = Vector3(0, 3, 24)
	fighter.interact_requested.connect(_on_interact)
	fighter.destroyed.connect(_on_player_destroyed)
	add_child(fighter)
	sector_streamer = StreamerScript.new()
	sector_streamer.process_mode = Node.PROCESS_MODE_PAUSABLE
	sector_streamer.setup(world_seed)
	add_child(sector_streamer)
	sector_streamer.update_stream(fighter.global_position)

	_spawn_hostiles()
	_prepare_contract()
	hud = HUDScript.new()
	hud.setup(fighter, mode, active_contract)
	hud.resume_requested.connect(_set_paused.bind(false))
	hud.exit_requested.connect(_exit_to_menu.bind(false))
	hud.operations_action.connect(_operations_action)
	add_child(hud)
	_refresh_guidance()
	_preflight()


func _exit_tree() -> void:
	if paused and get_tree():
		get_tree().paused = false


func _preflight() -> void:
	panel = "preflight"
	_set_paused(true)
	hud.pause_overlay.hide()
	var text := "%s preset. Flight is on hold until you launch.\n\n" % mode.capitalize()
	text += str(active_contract.get("description", "No assignment. Explore freely.")) + "\n\n"
	text += "Gold diamond: destination. Cyan square: dock.\n" + InputSetup.flight_hints()
	var actions := {"launch": "LAUNCH SORTIE"}
	if active_contract.get("type") == "QUALIFICATION":
		actions.skip = "SKIP QUALIFICATION · Experienced pilot"
	actions.command = "BACK TO COMMAND"
	hud.show_operations("Practice sortie · no save" if Career.sandbox else "Preflight briefing", text, actions)


func _operations_action(action: String) -> void:
	match action:
		"launch":
			docked = false
			panel = ""
			hud.operations.hide()
			_set_paused(false)
			hud.show_toast("Flight released · Esc opens your flight log.")
		"skip":
			_waive_qualification()
			_preflight()
		"command":
			_exit_to_menu()
		"abandon_prompt":
			panel = "abandon"
			hud.pause_overlay.hide()
			hud.show_operations("Abandon assignment?", "Partial progress is discarded. Earned credits stay in your wallet.", {"cancel_abandon": "KEEP ASSIGNMENT", "abandon": "ABANDON"})
		"cancel_abandon":
			if docked:
				_open_board()
				return
			panel = ""
			hud.operations.hide()
			_set_paused(true)
		"abandon":
			if active_contract.get("type") == "QUALIFICATION":
				_waive_qualification()
			_set_assignment({})
			if docked:
				_open_board()
				return
			_operations_action("launch")
			hud.show_toast("Assignment cleared · visit a dock for work.")
		_:
			if panel == "board" and action.begins_with("job:") and active_contract.is_empty():
				var index := action.trim_prefix("job:").to_int()
				if index >= 0 and index < board_offers.size():
					var job := board_offers[index]
					_set_assignment(job)
					_operations_action("launch")
					hud.show_toast("Accepted · " + str(job.description), 5)


func _open_board() -> void:
	panel = "board"
	docked = true
	_set_paused(true)
	hud.pause_overlay.hide()
	var actions := {}
	var brief := "Docked at %s · Hull, shields and stores replenished." % Career.data.docked_at
	board_offers.clear()
	if active_contract.is_empty():
		var sites := 0
		for site in get_tree().get_nodes_in_group("discovery"):
			if str(site.name) not in Career.data.discoveries:
				sites += 1
		var supply := {"DISCOVERY": sites, "COMET": get_tree().get_nodes_in_group("comets").size(), "ESCORT": 1, "ELIMINATION": get_tree().get_nodes_in_group("hostile").size()}
		board_offers = ContractSystem.board(mode, world_seed, int(Career.data.completed_contracts), supply)
		if int(Career.data.chapter_step) == Chapter.LICENSED:
			board_offers.resize(2)
			board_offers.push_front(Chapter.mission(Chapter.LICENSED))
		brief += "\nPick a job to launch, or depart without one. No fee to decline."
		for i in board_offers.size():
			var job := board_offers[i]
			actions["job:%d" % i] = "%s  ·  %d CR\n%s" % [job.title, int(job.reward), job.description]
	else:
		brief += "\n\nCurrent assignment: %s\n%s" % [active_contract.title, active_contract.description]
		actions.launch = "CONTINUE ASSIGNMENT"
		actions.abandon_prompt = "CHANGE ASSIGNMENT…"
	if not actions.has("launch"):
		actions.launch = "DEPART WITHOUT A JOB"
	actions.command = "RETURN TO COMMAND"
	hud.show_operations("Station contract board", brief, actions)


func _waive_qualification() -> void:
	Career.data.qualification_waived = true
	Career.data.chapter_step = Chapter.LICENSED
	_set_assignment(Chapter.mission(Chapter.LICENSED))


func _set_assignment(job: Dictionary) -> void:
	active_contract = job
	Career.data.active_contract = job
	escort_time = 0
	Career.save_atomic()
	# Area enter signals may arrive while the physics server flushes queries.
	call_deferred("_build_objective_markers")
	if hud:
		hud.update_contract(job)


func _advance_chapter(step: int) -> void:
	Career.data.chapter_step = step
	if step == Chapter.LICENSED or step == Chapter.FINISHED:
		Career.data.credits = int(Career.data.credits) + int(active_contract.reward)
	var job := Chapter.mission(step)
	_set_assignment(job)
	if step == Chapter.FINISHED:
		hud.show_toast("Chapter complete · Caligo charted · +1100 CR. Free roam remains open.", 6)
	elif step == Chapter.LICENSED:
		hud.show_toast("Qualified · Survey licence issued · +800 CR", 5)
	else:
		hud.show_toast(job.description, 4)


func _unhandled_input(event: InputEvent) -> void:
	if panel != "":
		if event.is_action_pressed("pause"):
			if panel == "abandon":
				_operations_action("cancel_abandon")
			get_viewport().set_input_as_handled()
		return
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
	if active_contract.get("type") == "QUALIFICATION" and int(Career.data.chapter_step) == 0 and fighter.throttle >= 0.2:
		_advance_chapter(1)
	if active_contract.get("type") == "OVERLOOK":
		var overlook := _objective_target()
		if overlook and fighter.global_position.distance_to(overlook.global_position) < 32:
			_advance_chapter(Chapter.FINISHED)
	_update_docking_prompt()
	_update_escort(delta)
	sector_streamer.update_stream(logical_origin + fighter.global_position)
	_maybe_shift_origin()
	guidance_timer -= delta
	if guidance_timer <= 0:
		_refresh_guidance()
		guidance_timer = 0.15


func _refresh_guidance() -> void:
	if not hud:
		return
	var target := _objective_target()
	var title := ""
	if is_instance_valid(target):
		title = str(target.get_meta("nav_name", target.name))
		if target is OrbitalStation:
			title = "Dock · " + target.station_name if active_contract.get("type") != "ESCORT" else target.station_name
		elif target is EnemyFighter:
			title = "Hostile fighter"
		elif target is SpaceObject:
			title = "Inbound comet"
	hud.set_destination(target, title)


func _objective_target() -> Node3D:
	var kind := str(active_contract.get("type", ""))
	if kind == "QUALIFICATION" and int(Career.data.chapter_step) == 2:
		return star_system.dockables[0]
	if kind == "OVERLOOK":
		return star_system.get_node_or_null("Caligo Overlook")
	if kind == "" and not Career.sandbox:
		return star_system.nearest_dock(fighter)
	if kind in ["NAVIGATION", "AEROBATICS", "QUALIFICATION"]:
		for gate in objective_root.get_children():
			if gate.visible:
				return gate
	if kind == "ESCORT":
		return star_system.dockables[1]
	var group := str({"COMET": "comets", "DISCOVERY": "discovery", "ELIMINATION": "hostile"}.get(kind, ""))
	var best: Node3D
	var best_distance := INF
	if group != "":
		for candidate in get_tree().get_nodes_in_group(group):
			if candidate.is_queued_for_deletion() or (kind == "DISCOVERY" and str(candidate.name) in Career.data.discoveries):
				continue
			var distance := fighter.global_position.distance_squared_to(candidate.global_position)
			if distance < best_distance:
				best = candidate
				best_distance = distance
	return best


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
		enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	if int(Career.data.chapter_step) < Chapter.LICENSED:
		active_contract = Chapter.mission(int(Career.data.chapter_step))
	else:
		active_contract = Career.data.active_contract.duplicate(true)
		var kind := str(active_contract.get("type", ""))
		if (mode == "EXPLORER" and kind == "ESCORT") or (mode != "WARZONE" and kind == "ELIMINATION"):
			active_contract = {}
	Career.data.mode = mode
	Career.data.active_contract = active_contract
	Career.save_atomic()
	_build_objective_markers()


func _build_objective_markers() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if objective_root != null and is_instance_valid(objective_root):
		objective_root.queue_free()
	objective_root = Node3D.new()
	objective_root.name = "ContractMarkers"
	add_child(objective_root)
	objective_root.global_position = -logical_origin
	match str(active_contract.get("type", "")):
		"QUALIFICATION":
			if int(Career.data.chapter_step) <= 1:
				_add_gate(Vector3(-120, 32, -260), "TRAINING_GATE", 0, Color("#ffcf66"))
		"NAVIGATION":
			_add_gate(Vector3(-420, 120, -980), "NAV_POINT", 0, Color("#52d8ff"))
		"AEROBATICS":
			var target_count := int(active_contract.target)
			for index in target_count:
				if index < int(active_contract.progress):
					continue
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
	gate.set_meta("nav_name", "Asteria relay" if event_type == "NAV_POINT" else "Gate %d" % (index + 1))
	if event_type == "TRAINING_GATE":
		gate.set_meta("nav_name", "Asteria training gate")
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
	VisualFactory.add_mesh(gate, torus, Vector3.ZERO, Vector3.ONE, VisualFactory.material(Color(color, 0.65), 0.2, 0.2, color, true), Vector3(90, 0, 0), "Gate")
	gate.body_entered.connect(_on_gate_entered.bind(event_type, gate))
	objective_root.add_child(gate)


func _on_gate_entered(body: Node3D, event_type: String, gate: Area3D) -> void:
	if paused or body != fighter or gate.get_parent() != objective_root or not gate.visible or not gate.monitoring:
		return
	if event_type == "TRAINING_GATE":
		if active_contract.get("type") == "QUALIFICATION" and int(Career.data.chapter_step) == 1:
			gate.hide()
			_advance_chapter(2)
		return
	if event_type == "AERO_RING" and _objective_target() != gate:
		return
	gate.set_deferred("monitoring", false)
	gate.visible = false
	_record_contract_event(event_type)


func _on_space_object_destroyed(kind: String) -> void:
	if Career.sandbox:
		hud.show_toast("%s fragmented · Practice" % kind.capitalize())
		return
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
	if not ContractSystem._event_matches(str(active_contract.get("type", "")), event_type):
		return
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
	_set_assignment({})


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
			hud.set_context("%s  DOCK WITH %s" % [InputSetup.key_hint("interact"), nearest.station_name.to_upper()])
		elif not fighter.landing_gear:
			hud.set_context("SLOW BELOW 70 m/s FOR GEAR" if fighter.velocity.length() > 70 else "%s  DEPLOY LANDING GEAR  •  %dm" % [InputSetup.key_hint("toggle_gear"), int(distance)])
		else:
			hud.set_context("REDUCE SPEED BELOW 28 m/s  •  %dm" % int(distance))
	elif str(active_contract.get("type", "")) != "ESCORT":
		hud.set_context("")


func _on_interact() -> void:
	if paused:
		return
	var nearest := star_system.nearest_dock(fighter)
	if nearest != null and nearest.can_dock(fighter):
		fighter.dock_at(nearest.dock_transform())
		Career.data.docked_at = nearest.station_name
		Career.save_atomic()
		if hud:
			hud.show_toast("DOCKED  •  REPAIRED  •  REARMED", 4.0)
		if active_contract.get("type") == "QUALIFICATION" and int(Career.data.chapter_step) == 2 and nearest == star_system.dockables[0]:
			_advance_chapter(Chapter.LICENSED)
		if not Career.sandbox:
			_open_board()


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
