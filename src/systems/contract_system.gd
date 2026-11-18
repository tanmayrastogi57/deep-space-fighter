extends RefCounted
class_name ContractSystem

const CONTRACT_TYPES := ["NAVIGATION", "AEROBATICS", "DISCOVERY", "COMET", "ESCORT", "ELIMINATION"]


static func generate(mode: String, seed_value: int, completed_count: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + completed_count * 7919
	var available := CONTRACT_TYPES.duplicate()
	if mode == "EXPLORER":
		available = ["NAVIGATION", "AEROBATICS", "DISCOVERY", "COMET"]
	elif mode == "PATROL":
		available.erase("ELIMINATION")
	var kind: String = available[rng.randi_range(0, available.size() - 1)]
	var tier := clampi(1 + completed_count / 3, 1, 5)
	var target_count := 1
	match kind:
		"AEROBATICS":
			target_count = 3 + tier
		"DISCOVERY":
			target_count = 1 + tier / 2
		"ESCORT":
			target_count = 1
		"ELIMINATION":
			target_count = 2 + tier
	var title := _title_for(kind)
	return {
		"id": "%s-%d-%d" % [kind, seed_value, completed_count],
		"type": kind,
		"title": title,
		"description": _description_for(kind, target_count),
		"progress": 0,
		"target": target_count,
		"reward": 650 + tier * 350 + target_count * 110,
		"tier": tier
	}


static func record_progress(contract: Dictionary, event_type: String, amount: int = 1) -> bool:
	if contract.is_empty() or not _event_matches(str(contract.get("type", "")), event_type):
		return false
	contract.progress = mini(int(contract.progress) + amount, int(contract.target))
	return int(contract.progress) >= int(contract.target)


static func _event_matches(contract_type: String, event_type: String) -> bool:
	match contract_type:
		"NAVIGATION":
			return event_type == "NAV_POINT"
		"AEROBATICS":
			return event_type == "AERO_RING"
		"DISCOVERY":
			return event_type == "DISCOVERY"
		"COMET":
			return event_type == "COMET_DESTROYED"
		"ESCORT":
			return event_type == "ESCORT_COMPLETE"
		"ELIMINATION":
			return event_type == "HOSTILE_DESTROYED"
	return false


static func _title_for(kind: String) -> String:
	return {
		"NAVIGATION": "Outer-system courier run",
		"AEROBATICS": "Flight qualification circuit",
		"DISCOVERY": "Uncharted signal survey",
		"COMET": "High-velocity comet intercept",
		"ESCORT": "Civilian convoy escort",
		"ELIMINATION": "Warzone fighter suppression"
	}.get(kind, "Open contract")


static func _description_for(kind: String, target_count: int) -> String:
	match kind:
		"NAVIGATION":
			return "Fly through the gold marker at Asteria Relay."
		"AEROBATICS":
			return "Fly cleanly through %d maneuver gates." % target_count
		"DISCOVERY":
			return "Pass within 32 m of %d uncharted signal(s) to scan." % target_count
		"COMET":
			return "Intercept and fragment the marked comet."
		"ESCORT":
			return "Hold formation within 145 m of CSV Resolute for 25 seconds."
		"ELIMINATION":
			return "Destroy %d hostile fighters." % target_count
	return "Explore the system."

