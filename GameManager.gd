extends Node

# SIGNALS
signal game_over
signal game_restarted
signal game_won
signal tutorial_completed

# STATES
enum GameState { MENU, PLAYING, PAUSED, GAME_OVER, VICTORY, TUTORIAL }
var current_state : GameState = GameState.MENU

# UI REFERENCES
var game_over_ui : CanvasLayer = null
var game_won_ui : Control = null

# --- GAME SETTINGS ---
# Global Knuckles counter
var knuckles = 0
# the goal needed to win
@export var win_threshold: int = 15

# PATHS
@export var main_menu_path : String = "res://scenes/ui/main_menu.tscn"
@export var game_scene_path : String = "res://main.tscn"
@export var tutorial_scene_path : String = "res://scenes/tutorial.tscn"

# SAVE SYSTEM CONSTANTS
const SAVE_PATH = "user://game_settings.cfg"
const SAVE_SECTION = "Progress"
const SAVE_KEY_TUTORIAL = "tutorial_complete"

# PERSISTENT DATA
var has_completed_tutorial : bool = false

func _ready():
	# Load saved data immediately
	_load_data()
	
	# Wait for scene tree to stabilize
	await get_tree().process_frame
	
	# Determine Initial State based on the current scene
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.name != "MainMenu":
		# Check if we are in the tutorial scene file
		if current_scene.scene_file_path == tutorial_scene_path:
			current_state = GameState.TUTORIAL
		else:
			current_state = GameState.PLAYING
		
		# Initialize systems
		_setup_gameplay_connections()

# GAME FLOW CONTROL 

func start_game():
	print("Initiating game sequence...")
	
	# ROUTING LOGIC: Tutorial vs Main Game
	if not has_completed_tutorial:
		print("First time detected. Loading Tutorial.")
		current_state = GameState.TUTORIAL
		get_tree().change_scene_to_file(tutorial_scene_path)
	else:
		print("Tutorial previously completed. Loading Main Game.")
		current_state = GameState.PLAYING
		get_tree().change_scene_to_file(game_scene_path)
	
	# Wait for load, then setup
	await get_tree().process_frame
	await get_tree().process_frame
	_setup_gameplay_connections()

func finish_tutorial():
	print("Tutorial Completed.")
	has_completed_tutorial = true
	_save_data() # Save to disk
	
	emit_signal("tutorial_completed")
	
	# Transition directly to the main game
	start_game()

func restart_game():
	print("Restarting game...")
	
	# Restore state based on what we are restarting
	if get_tree().current_scene.scene_file_path == tutorial_scene_path:
		current_state = GameState.TUTORIAL
	else:
		current_state = GameState.PLAYING
		
	get_tree().paused = false
	
	# CLEAN UP ALL UI
	_cleanup_ui()
	
	# Reset Gameplay Data
	DestructionManager.reset_count()
	knuckles = 0 # Reset knuckles on restart
	
	emit_signal("game_restarted")
	
	# Reload
	get_tree().reload_current_scene()
	
	# Reconnect
	await get_tree().process_frame
	await get_tree().process_frame
	_setup_gameplay_connections()

func go_to_main_menu():
	print("Returning to main menu...")
	current_state = GameState.MENU
	get_tree().paused = false
	
	_cleanup_ui()
	
	get_tree().change_scene_to_file(main_menu_path)
	
func force_start_tutorial():
	print("Force starting tutorial...")
	current_state = GameState.TUTORIAL
	
	# Explicitly load the tutorial scene path
	get_tree().change_scene_to_file(tutorial_scene_path)
	
	# Wait for load, then setup connections
	await get_tree().process_frame
	await get_tree().process_frame
	_setup_gameplay_connections()

# SETUP HELPERS
func _setup_gameplay_connections():
	connect_to_enemies()
	setup_game_over_ui()
	
	# We only setup Victory UI and Destruction logic if we are in the MAIN GAME
	if current_state == GameState.PLAYING:
		setup_game_won_ui()
		# Connect signal
		if not DestructionManager.destruction_count_changed.is_connected(_on_destruction_count_changed):
			DestructionManager.destruction_count_changed.connect(_on_destruction_count_changed)
	else:
		# If in tutorial, disconnect destruction manager so breaking things doesn't win the game
		if DestructionManager.destruction_count_changed.is_connected(_on_destruction_count_changed):
			DestructionManager.destruction_count_changed.disconnect(_on_destruction_count_changed)

func connect_to_enemies():
	var enemies = get_tree().get_nodes_in_group("Enemy")
	for enemy in enemies:
		if enemy.has_signal("player_caught"):
			if not enemy.player_caught.is_connected(_on_player_caught):
				enemy.player_caught.connect(_on_player_caught)

func setup_game_over_ui():
	if game_over_ui != null: return
	var ui_scene = load("res://scenes/ui/game_over_ui.tscn")
	if ui_scene:
		game_over_ui = ui_scene.instantiate()
		get_tree().root.call_deferred("add_child", game_over_ui)

func setup_game_won_ui():
	if game_won_ui != null: return
	var ui_scene = load("res://scenes/ui/victory_screen.tscn")
	if ui_scene:
		game_won_ui = ui_scene.instantiate()
		get_tree().root.call_deferred("add_child", game_won_ui)
		game_won_ui.hide()

func _cleanup_ui():
	if game_over_ui:
		game_over_ui.queue_free()
		game_over_ui = null
	if game_won_ui:
		game_won_ui.queue_free()
		game_won_ui = null

# EVENT HANDLERS

func _on_destruction_count_changed(count: int):
	# Crucial Check: Only trigger victory if we are actually PLAYING (not in Tutorial)
	if count >= win_threshold and current_state == GameState.PLAYING:
		trigger_victory()

func _on_player_caught():
	if current_state == GameState.GAME_OVER or current_state == GameState.VICTORY:
		return
	trigger_game_over()

func trigger_game_over():
	print("GAME OVER!")
	current_state = GameState.GAME_OVER
	emit_signal("game_over")
	if game_over_ui: game_over_ui.show_game_over()
	get_tree().paused = true

func trigger_victory():
	print("VICTORY!")
	current_state = GameState.VICTORY
	emit_signal("game_won")
	
	# Small delay for dramatic effect
	await get_tree().create_timer(0.5).timeout
	
	if game_won_ui: game_won_ui.show_victory()
	get_tree().paused = true

# SAVE SYSTEM

func _save_data():
	var config = ConfigFile.new()
	config.set_value(SAVE_SECTION, SAVE_KEY_TUTORIAL, has_completed_tutorial)
	config.save(SAVE_PATH)

func _load_data():
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		has_completed_tutorial = config.get_value(SAVE_SECTION, SAVE_KEY_TUTORIAL, false)
	else:
		has_completed_tutorial = false

# PAUSE / RESUME / STATE CHECKS

func pause_game():
	if current_state == GameState.PLAYING or current_state == GameState.TUTORIAL:
		current_state = GameState.PAUSED
		get_tree().paused = true

func resume_game():
	if current_state == GameState.PAUSED:
		# Restore correct state based on scene path
		if get_tree().current_scene.scene_file_path == tutorial_scene_path:
			current_state = GameState.TUTORIAL
		else:
			current_state = GameState.PLAYING
		get_tree().paused = false

func is_game_over() -> bool:
	return current_state == GameState.GAME_OVER

func is_game_won() -> bool:
	return current_state == GameState.VICTORY

func is_playing() -> bool:
	return current_state == GameState.PLAYING or current_state == GameState.TUTORIAL

# DEBUG
func _input(event):
	# Press T to test victory manually
	if event.is_action_pressed("ui_text_completion_accept") or Input.is_key_pressed(KEY_T):
		if OS.is_debug_build(): # Only run in editor/debug builds
			print("Manual test: calling _on_destruction_count_changed(99)")
			_on_destruction_count_changed(99)
