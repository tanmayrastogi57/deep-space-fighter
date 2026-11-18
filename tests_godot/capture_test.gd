extends Node

const CAPTURE_PATH := "res://.godot/flight_capture.png"
const TEST_SAVE_PATH := "user://capture-career.json"


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	InputSetup.install_defaults()
	Career.save_path = TEST_SAVE_PATH
	Career.data = Career.default_career()
	Career.data.mode = "PATROL"
	var world := GameWorld.new()
	world.configure("PATROL", true)
	add_child(world)
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png("res://.godot/preflight_capture.png")
	world._operations_action("launch")
	for _frame in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if result == OK:
		result = image.save_png(CAPTURE_PATH)
	world._set_paused(true)
	await RenderingServer.frame_post_draw
	if result == OK:
		result = get_viewport().get_texture().get_image().save_png("res://.godot/log_capture.png")
	world._set_assignment({})
	world._open_board()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if result == OK:
		result = get_viewport().get_texture().get_image().save_png("res://.godot/jobs_capture.png")
	if result != OK:
		push_error("Could not save visual smoke capture: %s" % error_string(result))
	world.queue_free()
	Sound.shutdown()
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		var candidate := ProjectSettings.globalize_path(TEST_SAVE_PATH + suffix)
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)
	get_tree().quit(0 if result == OK else 1)

