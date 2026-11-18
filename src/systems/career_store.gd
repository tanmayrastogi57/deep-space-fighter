extends Node

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://career.json"

var save_path := DEFAULT_PATH
var data: Dictionary = {}
var recovery_message := ""
var sandbox := false
var _parked_career: Dictionary


func _ready() -> void:
	data = default_career()


func begin_sandbox(mode: String) -> void:
	if sandbox:
		return
	_parked_career = data
	sandbox = true
	data = default_career()
	data.mode = mode


func end_sandbox() -> void:
	if sandbox:
		data = _parked_career
		_parked_career = {}
		sandbox = false


func default_career() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"created_at": Time.get_datetime_string_from_system(true),
		"credits": 2500,
		"mode": "PATROL",
		"seed": 7355608,
		"docked_at": "Asteria Station",
		"hull": 100.0,
		"shields": 100.0,
		"missiles": 8,
		"discoveries": [],
		"completed_contracts": 0,
		"chapter_step": 0,
		"qualification_waived": false,
		"active_contract": {},
		"upgrades": {
			"engine": 0,
			"thrusters": 0,
			"hull": 0,
			"shields": 0,
			"energy": 0,
			"cannon": 0,
			"missiles": 0,
			"sensors": 0
		}
	}


func has_career() -> bool:
	return FileAccess.file_exists(save_path)


func new_career(mode: String = "PATROL", seed_value: int = 7355608) -> void:
	data = default_career()
	data.mode = mode
	data.seed = seed_value
	save_atomic()


func load_career() -> bool:
	recovery_message = ""
	if not FileAccess.file_exists(save_path):
		data = default_career()
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if parsed is Dictionary and _validate(parsed):
		data = _merge_defaults(parsed)
		return true
	var broken_path := save_path + ".corrupt-" + str(Time.get_unix_time_from_system())
	DirAccess.rename_absolute(save_path, broken_path)
	var backup_path := save_path + ".bak"
	if FileAccess.file_exists(backup_path):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(backup_path))
		if parsed is Dictionary and _validate(parsed):
			data = _merge_defaults(parsed)
			recovery_message = "Recovered the previous career backup."
			save_atomic()
			return true
	data = default_career()
	recovery_message = "The damaged career was quarantined; a new career is ready."
	return false


func save_atomic() -> bool:
	if sandbox:
		return true
	if not _validate(data):
		push_error("Career data failed validation; refusing to save.")
		return false
	var temp_path := save_path + ".tmp"
	var backup_path := save_path + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open temporary career save.")
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.flush()
	file.close()
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	if FileAccess.file_exists(save_path):
		var backup_error := DirAccess.rename_absolute(save_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_path)
			return false
	var replace_error := DirAccess.rename_absolute(temp_path, save_path)
	if replace_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, save_path)
		return false
	return true


func add_credits(amount: int) -> void:
	data.credits = maxi(0, int(data.get("credits", 0)) + amount)
	save_atomic()


func purchase_upgrade(upgrade_id: String) -> bool:
	if not data.upgrades.has(upgrade_id):
		return false
	var current_level := int(data.upgrades[upgrade_id])
	if current_level >= 5:
		return false
	var price := upgrade_price(upgrade_id)
	if int(data.credits) < price:
		return false
	data.credits = int(data.credits) - price
	data.upgrades[upgrade_id] = current_level + 1
	save_atomic()
	return true


func upgrade_price(upgrade_id: String) -> int:
	var level := int(data.get("upgrades", {}).get(upgrade_id, 0))
	return 800 * (level + 1) * (level + 1)


func _validate(candidate: Dictionary) -> bool:
	var credits: Variant = candidate.get("credits")
	var whole_credits: bool = credits is int or (credits is float and is_finite(credits) and credits == floor(credits))
	return (
		int(candidate.get("version", 0)) >= 1
		and whole_credits
		and candidate.get("upgrades", null) is Dictionary
		and str(candidate.get("mode", "")) in ["EXPLORER", "PATROL", "WARZONE"]
	)


func _merge_defaults(candidate: Dictionary) -> Dictionary:
	var merged := default_career()
	for key in candidate:
		if key == "upgrades" and candidate[key] is Dictionary:
			for upgrade_id in candidate[key]:
				if merged.upgrades.has(upgrade_id):
					merged.upgrades[upgrade_id] = clampi(int(candidate[key][upgrade_id]), 0, 5)
		else:
			merged[key] = candidate[key]
	merged.credits = int(merged.credits)
	# Existing careers keep their assignment and gain access to the survey.
	merged.chapter_step = clampi(int(candidate.get("chapter_step", 3)), 0, 4)
	return merged
