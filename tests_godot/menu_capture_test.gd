extends Node


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	InputSetup.install_defaults()
	var menu := MainMenu.new()
	add_child(menu)
	for _frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png("res://.godot/menu_capture.png")
	menu.show_settings()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	result = result if result != OK else get_viewport().get_texture().get_image().save_png("res://.godot/settings_capture.png")
	menu.show_hangar()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	result = result if result != OK else get_viewport().get_texture().get_image().save_png("res://.godot/hangar_capture.png")
	get_tree().quit(0 if result == OK else 1)
