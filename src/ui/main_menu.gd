extends CanvasLayer
class_name MainMenu

signal start_requested(mode: String, start_new: bool)
signal quit_requested

var home_panel: Control
var mode_panel: Control
var settings_panel: Control
var hangar_panel: Control
var starting_new := false
var status_label: Label
var credits_label: Label
var upgrade_buttons: Dictionary = {}
var rebind_buttons: Dictionary = {}
var rebind_status: Label
var waiting_for_action := ""

const REBIND_ACTIONS := {
	"throttle_up": "Throttle up",
	"throttle_down": "Throttle down",
	"pitch_down": "Pitch down",
	"pitch_up": "Pitch up",
	"roll_left": "Roll left",
	"roll_right": "Roll right",
	"yaw_left": "Yaw left",
	"yaw_right": "Yaw right",
	"toggle_gear": "Landing gear",
	"interact": "Dock / interact",
	"cycle_camera": "Cycle camera",
	"rear_view": "Rear view",
	"toggle_flight_assist": "Flight assist"
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_background()
	_build_home()
	_build_mode_picker()
	_build_settings()
	_build_hangar()
	show_home()


func show_home() -> void:
	home_panel.visible = true
	mode_panel.visible = false
	settings_panel.visible = false
	hangar_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_settings() -> void:
	home_panel.visible = false
	mode_panel.visible = false
	settings_panel.visible = true
	hangar_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_hangar() -> void:
	home_panel.visible = false
	mode_panel.visible = false
	settings_panel.visible = false
	hangar_panel.visible = true
	_refresh_hangar()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _show_modes(new_career: bool) -> void:
	starting_new = new_career
	home_panel.visible = false
	mode_panel.visible = true
	settings_panel.visible = false
	hangar_panel.visible = false


func _select_mode(mode: String) -> void:
	start_requested.emit(mode, starting_new)


func _build_background() -> void:
	var background := ColorRect.new()
	background.color = Color("#030812")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var horizon := ColorRect.new()
	horizon.color = Color(0.035, 0.14, 0.23, 0.72)
	horizon.set_anchors_preset(Control.PRESET_CENTER)
	horizon.position = Vector2(-900, -4)
	horizon.size = Vector2(1800, 8)
	background.add_child(horizon)
	for index in 90:
		var star := ColorRect.new()
		var hash_x := float((index * 83 + 17) % 997) / 997.0
		var hash_y := float((index * 191 + 41) % 991) / 991.0
		var size_value := 1.0 + float(index % 3)
		star.color = Color(0.62, 0.86, 1.0, 0.28 + float(index % 5) * 0.1)
		star.position = Vector2(hash_x * 1900.0, hash_y * 1000.0)
		star.size = Vector2.ONE * size_value
		background.add_child(star)


func _build_home() -> void:
	home_panel = Control.new()
	home_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(home_panel)
	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	stack.position = Vector2(92, -280)
	stack.size = Vector2(480, 560)
	stack.add_theme_constant_override("separation", 14)
	home_panel.add_child(stack)
	var eyebrow := _label("ORBITAL FLIGHT COMMAND", 15, Color("#62dfff"))
	stack.add_child(eyebrow)
	var title := _label("DEEP SPACE\nFIGHTER", 54, Color("#e7f7ff"))
	title.add_theme_constant_override("line_spacing", -4)
	stack.add_child(title)
	var subtitle := _label("REALISTIC FREE-ROAM SPACE FLIGHT", 16, Color("#829faf"))
	stack.add_child(subtitle)
	stack.add_child(HSeparator.new())
	var continue_button := _button("CONTINUE CAREER")
	continue_button.disabled = not Career.has_career()
	continue_button.pressed.connect(_show_modes.bind(false))
	stack.add_child(continue_button)
	var new_button := _button("NEW CAREER")
	new_button.pressed.connect(_show_modes.bind(true))
	stack.add_child(new_button)
	var hangar_button := _button("HANGAR / UPGRADES")
	hangar_button.disabled = not Career.has_career()
	hangar_button.pressed.connect(show_hangar)
	stack.add_child(hangar_button)
	var free_button := _button("FREE FLIGHT")
	free_button.pressed.connect(_select_mode.bind("EXPLORER"))
	stack.add_child(free_button)
	var settings_button := _button("SETTINGS")
	settings_button.pressed.connect(show_settings)
	stack.add_child(settings_button)
	var quit_button := _button("QUIT")
	quit_button.pressed.connect(quit_requested.emit)
	stack.add_child(quit_button)
	status_label = _label("Godot 4.7  •  DEEP SPACE BUILD", 13, Color("#527386"))
	stack.add_child(status_label)
	if Career.recovery_message != "":
		status_label.text = Career.recovery_message


func _build_mode_picker() -> void:
	mode_panel = Control.new()
	mode_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(mode_panel)
	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_CENTER)
	stack.position = Vector2(-520, -300)
	stack.size = Vector2(1040, 600)
	stack.add_theme_constant_override("separation", 18)
	mode_panel.add_child(stack)
	var title := _label("SELECT FLIGHT MODE", 38, Color("#e4f6ff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var subtitle := _label("The same persistent system. You decide how dangerous it becomes.", 17, Color("#89a9b8"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	stack.add_child(cards)
	_add_mode_card(cards, "EXPLORER", "NO HOSTILES", "Vistas, aerobatics, discoveries,\nmeteors and comet interception.", Color("#54d5eb"))
	_add_mode_card(cards, "PATROL", "MODERATE THREAT", "Explorer activities plus drones,\nlight fighters and rescue work.", Color("#f0c369"))
	_add_mode_card(cards, "WARZONE", "SEVERE THREAT", "Hostile groups, heavy fighters,\ncapital encounters and pursuit.", Color("#ff655c"))
	var back := _button("BACK")
	back.custom_minimum_size = Vector2(260, 50)
	back.pressed.connect(show_home)
	stack.add_child(back)


func _add_mode_card(parent: HBoxContainer, mode: String, danger: String, description: String, accent: Color) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 330)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.075, 0.94)
	style.border_color = Color(accent, 0.65)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)
	var title := _label(mode, 30, Color("#f1fbff"))
	content.add_child(title)
	var threat := _label(danger, 14, accent)
	content.add_child(threat)
	var description_label := _label(description, 16, Color("#9eb6c2"))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size.y = 130
	content.add_child(description_label)
	var launch := _button("LAUNCH " + mode)
	launch.pressed.connect(_select_mode.bind(mode))
	content.add_child(launch)


func _build_settings() -> void:
	settings_panel = Control.new()
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(settings_panel)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-360, -350)
	panel.size = Vector2(720, 700)
	settings_panel.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	panel.add_child(stack)
	var title := _label("FLIGHT SETTINGS", 34, Color("#e7f7ff"))
	stack.add_child(title)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = bool(Settings.data.fullscreen)
	stack.add_child(fullscreen)
	var vsync := CheckButton.new()
	vsync.text = "Vertical sync"
	vsync.button_pressed = bool(Settings.data.vsync)
	stack.add_child(vsync)
	var contrast := CheckButton.new()
	contrast.text = "High-contrast targeting"
	contrast.button_pressed = bool(Settings.data.high_contrast_targets)
	stack.add_child(contrast)
	var reduced := CheckButton.new()
	reduced.text = "Reduced flashes and camera effects"
	reduced.button_pressed = bool(Settings.data.reduced_flashes)
	stack.add_child(reduced)
	var fov := _slider_row(stack, "Field of view", 55.0, 110.0, float(Settings.data.field_of_view), 1.0)
	var sensitivity := _slider_row(stack, "Mouse sensitivity", 0.0005, 0.01, float(Settings.data.mouse_sensitivity), 0.0001)
	var shake := _slider_row(stack, "Camera shake", 0.0, 1.0, float(Settings.data.camera_shake), 0.05)
	var effects := _slider_row(stack, "Effects volume", 0.0, 1.0, float(Settings.data.effects_volume), 0.05)
	var controls := _label("KEY BINDINGS", 15, Color("#86a9ba"))
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(controls)
	var binding_grid := GridContainer.new()
	binding_grid.columns = 4
	binding_grid.add_theme_constant_override("h_separation", 16)
	binding_grid.add_theme_constant_override("v_separation", 6)
	stack.add_child(binding_grid)
	for action_name in REBIND_ACTIONS:
		var binding_label := _label(str(REBIND_ACTIONS[action_name]), 13, Color("#9db7c4"))
		binding_label.custom_minimum_size.x = 112
		binding_grid.add_child(binding_label)
		var binding_button := Button.new()
		binding_button.text = _binding_text(action_name)
		binding_button.custom_minimum_size = Vector2(118, 30)
		binding_button.pressed.connect(_begin_rebind.bind(action_name))
		binding_grid.add_child(binding_button)
		rebind_buttons[action_name] = binding_button
	rebind_status = _label("Escape always remains the pause fallback.", 13, Color("#6f98aa"))
	stack.add_child(rebind_status)
	var save_button := _button("APPLY SETTINGS")
	save_button.custom_minimum_size.y = 40
	save_button.pressed.connect(func() -> void:
		Settings.data.fullscreen = fullscreen.button_pressed
		Settings.data.vsync = vsync.button_pressed
		Settings.data.high_contrast_targets = contrast.button_pressed
		Settings.data.reduced_flashes = reduced.button_pressed
		Settings.data.field_of_view = fov.value
		Settings.data.mouse_sensitivity = sensitivity.value
		Settings.data.camera_shake = shake.value
		Settings.data.effects_volume = effects.value
		Settings.save()
		show_home()
	)
	stack.add_child(save_button)
	var cancel := _button("CANCEL")
	cancel.custom_minimum_size.y = 40
	cancel.pressed.connect(show_home)
	stack.add_child(cancel)


func _build_hangar() -> void:
	hangar_panel = Control.new()
	hangar_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hangar_panel)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-490, -330)
	panel.size = Vector2(980, 660)
	hangar_panel.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	panel.add_child(stack)
	var heading := _label("ASTERIA FIGHTER HANGAR", 34, Color("#e7f7ff"))
	stack.add_child(heading)
	credits_label = _label("", 19, Color("#f1ca72"))
	stack.add_child(credits_label)
	var summary := _label("One airframe. Eight upgrade paths. Maximum level 5.", 15, Color("#829fab"))
	stack.add_child(summary)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	stack.add_child(grid)
	for upgrade_id in Career.default_career().upgrades:
		var upgrade_button := _button("")
		upgrade_button.custom_minimum_size = Vector2(450, 62)
		upgrade_button.pressed.connect(_purchase_upgrade.bind(upgrade_id))
		grid.add_child(upgrade_button)
		upgrade_buttons[upgrade_id] = upgrade_button
	var back := _button("BACK TO COMMAND")
	back.pressed.connect(show_home)
	stack.add_child(back)


func _refresh_hangar() -> void:
	if credits_label == null:
		return
	credits_label.text = "AVAILABLE CREDITS  %d CR" % int(Career.data.credits)
	for upgrade_id in upgrade_buttons:
		var level := int(Career.data.upgrades.get(upgrade_id, 0))
		var button: Button = upgrade_buttons[upgrade_id]
		if level >= 5:
			button.text = "%s   LEVEL 5  •  MAXIMUM" % str(upgrade_id).to_upper()
			button.disabled = true
		else:
			var price := Career.upgrade_price(upgrade_id)
			button.text = "%s   LEVEL %d → %d   •   %d CR" % [str(upgrade_id).to_upper(), level, level + 1, price]
			button.disabled = int(Career.data.credits) < price


func _purchase_upgrade(upgrade_id: String) -> void:
	if Career.purchase_upgrade(upgrade_id):
		_refresh_hangar()


func _unhandled_input(event: InputEvent) -> void:
	if waiting_for_action == "" or event is not InputEventKey or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var key_event := event as InputEventKey
	if key_event.physical_keycode == KEY_ESCAPE:
		rebind_status.text = "Escape is reserved as the pause fallback."
		_finish_rebind(false)
		return
	for action_name in REBIND_ACTIONS:
		if action_name == waiting_for_action:
			continue
		for existing in InputMap.action_get_events(action_name):
			if existing is InputEventKey and existing.physical_keycode == key_event.physical_keycode:
				rebind_status.text = "%s is already assigned to %s." % [OS.get_keycode_string(key_event.physical_keycode), REBIND_ACTIONS[action_name]]
				_finish_rebind(false)
				return
	for existing in InputMap.action_get_events(waiting_for_action):
		if existing is InputEventKey:
			InputMap.action_erase_event(waiting_for_action, existing)
	InputMap.action_add_event(waiting_for_action, key_event)
	Settings.data.bindings[waiting_for_action] = int(key_event.physical_keycode)
	Settings.save()
	rebind_status.text = "%s assigned to %s." % [OS.get_keycode_string(key_event.physical_keycode), REBIND_ACTIONS[waiting_for_action]]
	_finish_rebind(true)


func _begin_rebind(action_name: String) -> void:
	waiting_for_action = action_name
	rebind_buttons[action_name].text = "PRESS A KEY"
	rebind_status.text = "Waiting for %s…" % REBIND_ACTIONS[action_name]


func _finish_rebind(success: bool) -> void:
	var action_name := waiting_for_action
	waiting_for_action = ""
	if rebind_buttons.has(action_name):
		rebind_buttons[action_name].text = _binding_text(action_name)
	if success:
		rebind_buttons[action_name].release_focus()


func _binding_text(action_name: String) -> String:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
	return "UNBOUND"


func _slider_row(parent: VBoxContainer, title: String, minimum: float, maximum: float, value: float, step: float) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _label(title, 15, Color("#b8d7e4"))
	label.custom_minimum_size.x = 220
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(400, 34)
	row.add_child(slider)
	return slider


func _label(text_value: String, size_value: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(460, 52)
	button.add_theme_font_size_override("font_size", 16)
	return button
