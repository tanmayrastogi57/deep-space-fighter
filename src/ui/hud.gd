extends CanvasLayer
class_name FlightHUD

signal resume_requested
signal exit_requested
signal settings_requested
signal operations_action(action: String)

var fighter: PlayerFighter
var mode := "PATROL"
var contract: Dictionary = {}
var left_status: Label
var right_status: Label
var objective: Label
var context_prompt: Label
var toast_label: Label
var diagnostic_label: Label
var pause_overlay: Control
var pause_settings_overlay: Control
var reticle: FlightReticle
var radar: FlightRadar
var toast_time := 0.0
var diagnostics_visible := false
var navigation := preload("res://src/ui/navigation_overlay.gd").new()
var destination := ""
var recent_radio := "Flight command standing by."
var log_label: Label
var operations: ColorRect
var operations_body: VBoxContainer
var abandon_button: Button


func setup(player: PlayerFighter, game_mode: String, active_contract: Dictionary) -> void:
	fighter = player
	mode = game_mode
	contract = active_contract
	_build_interface()


func _process(delta: float) -> void:
	if fighter == null or not is_instance_valid(fighter):
		return
	left_status.text = (
		"VELOCITY  %03d m/s\nTHROTTLE   %3d%%\nASSIST     %s\nSHIELD     %3d%%\nHULL       %3d%%"
		% [
			int(fighter.velocity.length()),
			int(fighter.throttle * 100.0),
			"ON" if fighter.flight_assist else "DRIFT",
			int(100.0 * fighter.shields / fighter.max_shields),
			int(100.0 * fighter.hull / fighter.max_hull)
		]
	)
	var target_text := "NO TARGET"
	if fighter.current_target != null and is_instance_valid(fighter.current_target):
		target_text = "%s  %dm" % [fighter.current_target.name.to_upper(), int(fighter.global_position.distance_to(fighter.current_target.global_position))]
	right_status.text = (
		"%s\n%s\nAMMO  %s\nENERGY  %3d%%\nVIEW  %s"
		% [
			mode,
			target_text,
			"∞" if fighter.active_weapon == 0 else str(fighter.missiles),
			int(fighter.energy),
			fighter.camera_name()
		]
	)
	if contract.is_empty():
		objective.text = "FREE FLIGHT · UNSAVED" if Career.sandbox else "NO ASSIGNMENT · Dock at the marked station for work."
	else:
		objective.text = "%s  ·  %d/%d  ·  %d CR\n%s" % [
			str(contract.title).to_upper(), int(contract.progress), int(contract.target), int(contract.reward), contract.description
		]
	reticle.set_locked(fighter.lock_progress >= 1.0)
	diagnostic_label.text = "FPS %d\nOBJECTS %d\nORIGIN %s" % [Engine.get_frames_per_second(), get_tree().get_node_count(), str(fighter.global_position.round())]
	if toast_time > 0.0:
		toast_time -= delta
		toast_label.modulate.a = clampf(toast_time, 0.0, 1.0)


func set_context(message: String) -> void:
	context_prompt.text = message


func show_toast(message: String, duration: float = 3.0) -> void:
	recent_radio = message
	toast_label.text = message
	toast_label.modulate.a = 1.0
	toast_time = duration


func update_contract(value: Dictionary) -> void:
	contract = value


func set_destination(target: Node3D, caption: String) -> void:
	navigation.target = target
	navigation.destination = caption
	radar.target = target
	destination = caption


func set_paused(value: bool) -> void:
	if value:
		abandon_button.visible = not contract.is_empty() and not Career.sandbox
		var fallback := "Explore at your own pace." if Career.sandbox else "Dock at the marked station to choose work."
		log_label.text = "FLIGHT LOG\n%s\nDestination: %s\n%s\nLast radio: %s" % [contract.get("description", fallback), destination if destination != "" else "None assigned", InputSetup.flight_hints(), recent_radio]
	pause_overlay.visible = value
	if not value and pause_settings_overlay:
		pause_settings_overlay.visible = false


func toggle_diagnostics() -> void:
	diagnostics_visible = not diagnostics_visible
	diagnostic_label.visible = diagnostics_visible


func _build_interface() -> void:
	var root := Control.new()
	root.name = "FlightInterface"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	navigation.fighter = fighter
	root.add_child(navigation)

	left_status = _make_label(root, 18, Color("#bfefff"))
	left_status.position = Vector2(28, 26)
	left_status.size = Vector2(350, 180)
	left_status.add_theme_constant_override("line_spacing", 5)

	right_status = _make_label(root, 18, Color("#bfefff"))
	right_status.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_status.position = Vector2(-390, 26)
	right_status.size = Vector2(360, 180)
	right_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_status.add_theme_constant_override("line_spacing", 5)

	objective = _make_label(root, 17, Color("#f5cf7a"))
	objective.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective.position = Vector2(-350, 24)
	objective.size = Vector2(700, 42)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	reticle = FlightReticle.new()
	reticle.set_anchors_preset(Control.PRESET_CENTER)
	reticle.position = Vector2(-36, -36)
	reticle.size = Vector2(72, 72)
	reticle.high_contrast = bool(Settings.data.get("high_contrast_targets", false))
	root.add_child(reticle)

	radar = FlightRadar.new()
	radar.fighter = fighter
	radar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	radar.position = Vector2(24, -198)
	radar.size = Vector2(172, 172)
	root.add_child(radar)

	context_prompt = _make_label(root, 17, Color("#f5cf7a"))
	context_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	context_prompt.position = Vector2(-330, -86)
	context_prompt.size = Vector2(660, 36)
	context_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	toast_label = _make_label(root, 21, Color.WHITE)
	toast_label.set_anchors_preset(Control.PRESET_CENTER)
	toast_label.position = Vector2(-350, 86)
	toast_label.size = Vector2(700, 44)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0

	diagnostic_label = _make_label(root, 14, Color("#9eddf0"))
	diagnostic_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	diagnostic_label.position = Vector2(-270, -112)
	diagnostic_label.size = Vector2(240, 90)
	diagnostic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	diagnostic_label.visible = false

	pause_overlay = _build_pause_overlay(root)
	pause_settings_overlay = _build_pause_settings(root)
	operations = ColorRect.new()
	operations.color = Color("#081420f5")
	operations.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	operations.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(operations)
	var center := CenterContainer.new()
	operations.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	operations_body = VBoxContainer.new()
	operations_body.custom_minimum_size.x = 710
	operations_body.add_theme_constant_override("separation", 12)
	center.add_child(operations_body)
	operations.hide()


func show_operations(heading: String, brief: String, actions: Dictionary) -> void:
	for child in operations_body.get_children():
		operations_body.remove_child(child)
		child.queue_free()
	_make_label(operations_body, 15, Color("#7bcee3")).text = "ASTERIA  /  FLIGHT COMMAND"
	_make_label(operations_body, 32, Color.WHITE).text = heading
	var text_label := _make_label(operations_body, 19, Color("#cfdfeb"))
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.text = brief
	operations.show()
	var first := true
	for action in actions:
		var button := Button.new()
		button.text = actions[action]
		button.custom_minimum_size = Vector2(0, 48)
		operations_body.add_child(button)
		button.pressed.connect(operations_action.emit.bind(action))
		if first:
			button.grab_focus()
			first = false


func _build_pause_overlay(root: Control) -> Control:
	var overlay := ColorRect.new()
	overlay.name = "PauseOverlay"
	overlay.color = Color(0.005, 0.012, 0.022, 0.91)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	root.add_child(overlay)
	var menu := VBoxContainer.new()
	menu.set_anchors_preset(Control.PRESET_CENTER)
	menu.position = Vector2(-365, -285)
	menu.size = Vector2(730, 570)
	menu.add_theme_constant_override("separation", 14)
	overlay.add_child(menu)
	var title := _make_label(menu, 38, Color("#dff7ff"))
	title.text = "FLIGHT PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _make_label(menu, 15, Color("#80a8bc"))
	subtitle.text = "Deep Space Fighter"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(HSeparator.new())
	log_label = _make_label(menu, 17, Color("#c3dce2"))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_menu_button(menu, "RESUME FLIGHT", resume_requested.emit)
	_add_menu_button(menu, "SETTINGS", _open_pause_settings)
	_add_menu_button(menu, "ABANDON ASSIGNMENT…", operations_action.emit.bind("abandon_prompt"))
	abandon_button = menu.get_child(-1)
	_add_menu_button(menu, "RETURN TO COMMAND", exit_requested.emit)
	overlay.visible = false
	return overlay


func _build_pause_settings(root: Control) -> Control:
	var overlay := ColorRect.new()
	overlay.name = "PauseSettingsOverlay"
	overlay.color = Color(0.005, 0.012, 0.022, 0.94)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	root.add_child(overlay)
	var menu := VBoxContainer.new()
	menu.set_anchors_preset(Control.PRESET_CENTER)
	menu.position = Vector2(-310, -280)
	menu.size = Vector2(620, 560)
	menu.add_theme_constant_override("separation", 14)
	overlay.add_child(menu)
	var title := _make_label(menu, 34, Color("#dff7ff"))
	title.text = "LIVE FLIGHT SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = bool(Settings.data.fullscreen)
	menu.add_child(fullscreen)
	var contrast := CheckButton.new()
	contrast.text = "High-contrast targeting"
	contrast.button_pressed = bool(Settings.data.high_contrast_targets)
	menu.add_child(contrast)
	var reduced := CheckButton.new()
	reduced.text = "Reduced flashes and camera effects"
	reduced.button_pressed = bool(Settings.data.reduced_flashes)
	menu.add_child(reduced)
	var fov := _pause_slider(menu, "Field of view", 55.0, 110.0, float(Settings.data.field_of_view), 1.0)
	var shake := _pause_slider(menu, "Camera shake", 0.0, 1.0, float(Settings.data.camera_shake), 0.05)
	var effects := _pause_slider(menu, "Effects volume", 0.0, 1.0, float(Settings.data.effects_volume), 0.05)
	_add_menu_button(menu, "APPLY", func() -> void:
		Settings.data.fullscreen = fullscreen.button_pressed
		Settings.data.high_contrast_targets = contrast.button_pressed
		Settings.data.reduced_flashes = reduced.button_pressed
		Settings.data.field_of_view = fov.value
		Settings.data.camera_shake = shake.value
		Settings.data.effects_volume = effects.value
		Settings.save()
		reticle.high_contrast = contrast.button_pressed
		reticle.queue_redraw()
		if fighter and fighter.camera_rig:
			fighter.camera_rig.base_fov = fov.value
		pause_settings_overlay.visible = false
		pause_overlay.visible = true
	)
	_add_menu_button(menu, "CANCEL", func() -> void:
		pause_settings_overlay.visible = false
		pause_overlay.visible = true
	)
	overlay.visible = false
	return overlay


func _open_pause_settings() -> void:
	pause_overlay.visible = false
	pause_settings_overlay.visible = true


func _pause_slider(parent: VBoxContainer, title: String, minimum: float, maximum: float, value: float, step: float) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _make_label(row, 15, Color("#b8d7e4"))
	label.text = title
	label.custom_minimum_size.x = 190
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(390, 34)
	row.add_child(slider)
	return slider


func _make_label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label


func _add_menu_button(parent: Node, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(340, 54)
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
