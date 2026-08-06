extends Node

const SectorStreamerScript := preload("res://src/world/sector_streamer.gd")

var failures: Array[String] = []
var checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	InputSetup.install_defaults()
	_test_flight_math()
	_test_contracts()
	_test_input_setup()
	_test_mesh_generation()
	_test_settings_validation()
	_test_sector_streaming_math()
	if failures.is_empty():
		print("PASS: %d deterministic checks" % checks)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %d of %d checks failed" % [failures.size(), checks])
		get_tree().quit(1)


func _test_flight_math() -> void:
	_expect_equal(FlightMath.step_throttle(0.95, 1.0, 0.0, 1.0), 1.0, "Throttle clamps at one")
	_expect_equal(FlightMath.step_throttle(0.05, 0.0, 1.0, 1.0), 0.0, "Throttle clamps at zero")
	var velocity := FlightMath.assisted_velocity(Vector3.ZERO, Vector3.FORWARD, 1.0, 5.0, 100.0, 50.0, 0.2, 1.0)
	_expect(velocity.z < 0.0, "Assisted velocity follows the supplied forward vector")
	_expect(velocity.length() <= 100.0, "Assisted velocity stays beneath target speed")
	_expect(FlightMath.impact_damage(6.0, 8.0, 0.0) == 0.0, "Low-speed contact is forgiven")
	_expect(FlightMath.impact_damage(80.0, 8.0, 0.0) > FlightMath.impact_damage(80.0, 8.0, 1.0), "Shields reduce impact damage")
	var lead := FlightMath.intercept_direction(Vector3.ZERO, 100.0, Vector3(0, 0, -100), Vector3(20, 0, 0))
	_expect(lead.x > 0.0 and lead.z < 0.0, "Intercept direction leads a moving target")


func _test_contracts() -> void:
	for seed_value in 30:
		var explorer := ContractSystem.generate("EXPLORER", seed_value, seed_value)
		_expect(str(explorer.type) not in ["ESCORT", "ELIMINATION"], "Explorer never generates combat contract")
	var contract := {
		"type": "AEROBATICS",
		"progress": 0,
		"target": 2
	}
	_expect(not ContractSystem.record_progress(contract, "AERO_RING"), "First gate does not prematurely complete contract")
	_expect(ContractSystem.record_progress(contract, "AERO_RING"), "Final gate completes contract")
	_expect_equal(int(contract.progress), 2, "Contract progress is capped at target")


func _test_input_setup() -> void:
	InputSetup.install_defaults()
	var before := InputMap.action_get_events("fire_weapon").size()
	InputSetup.install_defaults()
	var after := InputMap.action_get_events("fire_weapon").size()
	_expect_equal(after, before, "Installing defaults is idempotent")
	_expect(InputMap.has_action("toggle_gear"), "Landing gear action exists")
	_expect(InputMap.has_action("cycle_camera"), "Camera-cycle action exists")


func _test_mesh_generation() -> void:
	var first := VisualFactory.asteroid_mesh(1234, 5.0, 8, 12)
	var second := VisualFactory.asteroid_mesh(1234, 5.0, 8, 12)
	_expect(first.get_surface_count() == 1, "Asteroid has one render surface")
	_expect_equal(first.surface_get_array_len(0), second.surface_get_array_len(0), "Seeded asteroid topology is deterministic")
	var first_arrays := first.surface_get_arrays(0)
	var second_arrays := second.surface_get_arrays(0)
	_expect(first_arrays[Mesh.ARRAY_VERTEX][17].is_equal_approx(second_arrays[Mesh.ARRAY_VERTEX][17]), "Seeded asteroid vertices are deterministic")


func _test_settings_validation() -> void:
	var original := Settings.data.duplicate(true)
	Settings.data.frame_cap = 71
	Settings.data.field_of_view = 300.0
	Settings.data.mouse_sensitivity = -2.0
	Settings.call("_validate_in_place")
	_expect_equal(int(Settings.data.frame_cap), 60, "Frame cap resolves to a supported value")
	_expect_equal(float(Settings.data.field_of_view), 110.0, "Field of view is bounded")
	_expect_equal(float(Settings.data.mouse_sensitivity), 0.0005, "Mouse sensitivity is bounded")
	Settings.data = original


func _test_sector_streaming_math() -> void:
	_expect_equal(SectorStreamerScript.sector_for(Vector3(0, 100, 0), 900.0), Vector3i.ZERO, "Origin maps to the central sector")
	_expect_equal(SectorStreamerScript.sector_for(Vector3(901, 0, -1), 900.0), Vector3i(1, 0, -1), "Sector mapping handles positive and negative coordinates")
	_expect_equal(SectorStreamerScript.sector_key(Vector3i(-2, 0, 4)), "-2:4", "Sector keys are stable")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])
