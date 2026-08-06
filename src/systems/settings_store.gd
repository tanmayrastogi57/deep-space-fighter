extends Node

const SETTINGS_PATH := "user://settings.json"

var data: Dictionary = {}


func _ready() -> void:
	load_settings()
	apply_window_settings()


func defaults() -> Dictionary:
	return {
		"fullscreen": false,
		"vsync": true,
		"frame_cap": 60,
		"graphics": "HIGH",
		"mouse_sensitivity": 0.0025,
		"invert_y": false,
		"field_of_view": 78.0,
		"camera_shake": 0.65,
		"hud_scale": 1.0,
		"high_contrast_targets": false,
		"reduced_flashes": false,
		"aim_assist": 0.35,
		"master_volume": 0.8,
		"music_volume": 0.55,
		"effects_volume": 0.85
		,"bindings": {}
	}


func load_settings() -> void:
	data = defaults()
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if parsed is Dictionary:
		for key in parsed:
			if data.has(key):
				data[key] = parsed[key]
	_validate_in_place()


func save() -> bool:
	_validate_in_place()
	var temp_path := SETTINGS_PATH + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.flush()
	file.close()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)
	var result := DirAccess.rename_absolute(temp_path, SETTINGS_PATH)
	if result == OK:
		apply_window_settings()
	return result == OK


func reset_defaults() -> void:
	data = defaults()
	save()


func apply_window_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if bool(data.fullscreen)
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if bool(data.vsync)
		else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = int(data.frame_cap)


func _validate_in_place() -> void:
	data.frame_cap = _nearest_frame_cap(int(data.get("frame_cap", 60)))
	data.graphics = str(data.get("graphics", "HIGH")) if str(data.get("graphics", "HIGH")) in ["LOW", "MEDIUM", "HIGH", "ULTRA"] else "HIGH"
	data.mouse_sensitivity = clampf(float(data.get("mouse_sensitivity", 0.0025)), 0.0005, 0.01)
	data.field_of_view = clampf(float(data.get("field_of_view", 78.0)), 55.0, 110.0)
	data.camera_shake = clampf(float(data.get("camera_shake", 0.65)), 0.0, 1.0)
	data.hud_scale = clampf(float(data.get("hud_scale", 1.0)), 0.75, 1.5)
	data.aim_assist = clampf(float(data.get("aim_assist", 0.35)), 0.0, 1.0)
	for volume_key in ["master_volume", "music_volume", "effects_volume"]:
		data[volume_key] = clampf(float(data.get(volume_key, 0.8)), 0.0, 1.0)
	if data.get("bindings", null) is not Dictionary:
		data.bindings = {}


func _nearest_frame_cap(value: int) -> int:
	var options := [30, 60, 120, 144, 240]
	var best: int = options[0]
	for option in options:
		if absi(option - value) < absi(best - value):
			best = option
	return best
