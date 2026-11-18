extends Node


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	InputSetup.install_defaults()
	Career.save_path = "user://menu-capture-%d.json" % OS.get_process_id()
	var menu := MainMenu.new()
	add_child(menu)
	for _frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png("res://.godot/menu_capture.png")
	menu._show_modes("sandbox")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	result = result if result != OK else get_viewport().get_texture().get_image().save_png("res://.godot/modes_capture.png")
	menu.show_settings()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	result = result if result != OK else get_viewport().get_texture().get_image().save_png("res://.godot/settings_capture.png")
	menu.show_hangar()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	result = result if result != OK else get_viewport().get_texture().get_image().save_png("res://.godot/hangar_capture.png")
	Sound.shutdown()
	get_tree().quit(0 if result == OK else 1)
