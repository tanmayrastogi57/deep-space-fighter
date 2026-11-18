extends Node

var failures: Array[String] = []
var app: Node


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func press(parent: Node, prefix: String) -> void:
	for button in parent.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and button.text.begins_with(prefix):
			button.pressed.emit()
			return
	check(false, "Missing visible button: " + prefix)


func _run() -> void:
	Career.save_path = "user://menu-flow-%d.json" % OS.get_process_id()
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	press(app.menu, "START GUIDED")
	await get_tree().process_frame
	for button in app.menu.mode_panel.find_children("*", "Button", true, false):
		check(button.get_viewport_rect().encloses(button.get_global_rect()), "Clipped mode control: " + button.text)
	press(app.menu, "BACK")
	press(app.menu, "FREE FLIGHT")
	press(app.menu, "LAUNCH WARZONE")
	check(Career.sandbox and app.game_world.mode == "WARZONE" and app.game_world.active_contract.is_empty(), "Back then practice has no career assignment")
	await get_tree().process_frame
	press(app.game_world.hud.operations, "BACK TO COMMAND")
	check(not Career.has_career(), "Practice does not create a first career")
	press(app.menu, "START GUIDED")
	press(app.menu, "LAUNCH EXPLORER")
	await get_tree().process_frame
	check(app.game_world.active_contract.type == "QUALIFICATION", "Explorer starts the same guided chapter")
	press(app.game_world.hud.operations, "SKIP QUALIFICATION")
	check(app.game_world.paused and app.game_world.active_contract.type == "OVERLOOK" and Career.data.credits == 2500, "Skipping opens survey briefing without payment or automatic launch")
	press(app.game_world.hud.operations, "BACK TO COMMAND")
	var saved := FileAccess.get_file_as_bytes(Career.save_path)
	var backup := FileAccess.get_file_as_bytes(Career.save_path + ".bak")
	press(app.menu, "FREE FLIGHT")
	press(app.menu, "LAUNCH PATROL")
	await get_tree().process_frame
	press(app.game_world.hud.operations, "LAUNCH SORTIE")
	Career.add_credits(555)
	app.game_world._exit_to_menu()
	check(FileAccess.get_file_as_bytes(Career.save_path) == saved and FileAccess.get_file_as_bytes(Career.save_path + ".bak") == backup, "Practice round trip leaves career and backup byte-identical")
	press(app.menu, "CONTINUE: CHART CALIGO")
	press(app.menu, "LAUNCH PATROL")
	await get_tree().process_frame
	check(app.game_world.active_contract.type == "OVERLOOK" and not Career.sandbox, "Continue restores the named assignment")
	app.game_world._exit_to_menu()
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(Career.save_path + suffix):
			DirAccess.remove_absolute(Career.save_path + suffix)
	for message in failures:
		push_error(message)
	if failures.is_empty():
		print("PASS: menu, mode selection, practice isolation, skip and continue")
	get_tree().quit(0 if failures.is_empty() else 1)
