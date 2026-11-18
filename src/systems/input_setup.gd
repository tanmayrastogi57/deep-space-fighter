extends RefCounted
class_name InputSetup


static func install_defaults() -> void:
	_add_key("throttle_up", KEY_SHIFT)
	_add_key("throttle_down", KEY_CTRL)
	_add_key("pitch_down", KEY_W)
	_add_key("pitch_down", KEY_KP_8)
	_add_key("pitch_up", KEY_S)
	_add_key("pitch_up", KEY_KP_5)
	_add_key("roll_left", KEY_A)
	_add_key("roll_left", KEY_KP_4)
	_add_key("roll_right", KEY_D)
	_add_key("roll_right", KEY_KP_6)
	_add_key("yaw_left", KEY_Q)
	_add_key("yaw_right", KEY_E)
	_add_key("toggle_gear", KEY_G)
	_add_key("interact", KEY_F)
	_add_key("rear_view", KEY_C)
	_add_key("cycle_camera", KEY_V)
	_add_key("toggle_flight_assist", KEY_X)
	_add_key("pause", KEY_ESCAPE)
	_add_key("toggle_fullscreen", KEY_F11)
	_add_key("toggle_diagnostics", KEY_F3)
	_add_key("free_look", KEY_ALT)
	_add_key("fire_weapon", KEY_SPACE)
	_add_mouse("fire_weapon", MOUSE_BUTTON_LEFT)
	_add_mouse("target_lock", MOUSE_BUTTON_RIGHT)
	_add_mouse("next_weapon", MOUSE_BUTTON_WHEEL_UP)
	_add_mouse("previous_weapon", MOUSE_BUTTON_WHEEL_DOWN)


static func apply_bindings(bindings: Dictionary) -> void:
	for action_name in bindings:
		if not InputMap.has_action(action_name):
			continue
		var physical_code := int(bindings[action_name]) as Key
		if physical_code == KEY_ESCAPE:
			continue
		for existing in InputMap.action_get_events(action_name):
			if existing is InputEventKey:
				InputMap.action_erase_event(action_name, existing)
		_add_key(action_name, physical_code)


static func key_hint(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
	return str(action)


static func flight_hints() -> String:
	return "%s / %s throttle · %s / %s bank · %s / %s pitch · %s / %s yaw\n%s gear · %s dock · Mouse looks around · Esc opens the flight log" % [
		key_hint("throttle_up"), key_hint("throttle_down"), key_hint("roll_left"), key_hint("roll_right"),
		key_hint("pitch_down"), key_hint("pitch_up"), key_hint("yaw_left"), key_hint("yaw_right"),
		key_hint("toggle_gear"), key_hint("interact")]


static func _add_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


static func _add_mouse(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventMouseButton and existing.button_index == button:
			return
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
