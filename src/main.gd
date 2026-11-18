extends Node

const MainMenuScript := preload("res://src/ui/main_menu.gd")
const GameWorldScript := preload("res://src/game_world.gd")

var menu: MainMenu
var game_world: GameWorld


func _ready() -> void:
	Career.load_career()
	InputSetup.install_defaults()
	InputSetup.apply_bindings(Settings.data.get("bindings", {}))
	_show_menu(false)


func _show_menu(open_settings: bool = false) -> void:
	if game_world != null and is_instance_valid(game_world):
		remove_child(game_world)
		game_world.queue_free()
		game_world = null
	Career.end_sandbox()
	menu = MainMenuScript.new()
	menu.start_requested.connect(_start_game)
	menu.quit_requested.connect(_quit)
	add_child(menu)
	if open_settings:
		menu.call_deferred("show_settings")


func _start_game(mode: String, intent: String) -> void:
	if intent == "sandbox":
		Career.begin_sandbox(mode)
	elif intent == "new":
		Career.new_career(mode, int(Time.get_unix_time_from_system()) & 0x7fffffff)
	else:
		Career.data.mode = mode
		Career.save_atomic()
	if menu != null:
		menu.queue_free()
		menu = null
	game_world = GameWorldScript.new()
	game_world.configure(mode, intent == "new")
	game_world.return_to_menu.connect(_show_menu)
	add_child(game_world)


func _quit() -> void:
	Sound.shutdown()
	get_tree().quit()
