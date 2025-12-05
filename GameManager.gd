extends Node

signal game_over
signal game_restarted
signal tutorial_completed 

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER, TUTORIAL }

var current_state : GameState = GameState.MENU
var game_over_ui : CanvasLayer = null
var game_won_ui : Control = null

#change this to the goal needed to win
@export var win_threshold: int = 15

# CONFIGURATION & PATHS
const SAVE_PATH = "user://game_settings.cfg"
const SAVE_SECTION = "Progress"
const SAVE_KEY_TUTORIAL = "tutorial_complete"

@export var main_menu_path : String = "res://scenes/ui/main_menu.tscn"
@export var game_scene_path : String = "res://main.tscn"
@export var tutorial_scene_path : String = "res://scenes/tutorial.tscn" 

# State Variable
var has_completed_tutorial : bool = false



func _ready():
	# Load saved data immediately upon game launch
	_load_data()
	
	await get_tree().process_frame
	
	# Only connect setup if we are NOT in the menu
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.name != "MainMenu":
		# Detect if we are in tutorial or main game based on filename
		if current_scene.scene_file_path == tutorial_scene_path:
			current_state = GameState.TUTORIAL
		else:
			current_state = GameState.PLAYING
			
		connect_to_enemies()
		setup_game_over_ui()
		setup_game_won_ui()
		DestructionManager.destruction_count_changed.connect(_on_destruction_count_changed)


func start_game():
	print("Initiating game sequence...")

	if not has_completed_tutorial:
		print("First time detected. Loading Tutorial.")
		current_state = GameState.TUTORIAL
		get_tree().change_scene_to_file(tutorial_scene_path)
	else:
		print("Tutorial previously completed. Loading Main Game.")
		current_state = GameState.PLAYING
		get_tree().change_scene_to_file(game_scene_path)
	
	# Post-load setup
	await get_tree().process_frame
	await get_tree().process_frame
	connect_to_enemies()
	setup_game_over_ui()

# Call this function at the end of your Tutorial Scene!
func finish_tutorial():
	print("Tutorial Completed.")
	has_completed_tutorial = true
	_save_data() # Commit to disk
	
	emit_signal("tutorial_completed")
	
	# Transition directly to the main game
	start_game()



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
		# If no file exists (first ever run), default to false
		has_completed_tutorial = false



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
	if game_won_ui != null:
		return
		
	var ui_scene = load("res://scenes/ui/victory_screen.tscn")
	
	if ui_scene:
		game_won_ui = ui_scene.instantiate()
		get_tree().root.call_deferred("add_child", game_won_ui)
		game_won_ui.hide()
		
		

func _on_destruction_count_changed(count: int):
	if count >= win_threshold and current_state == GameState.PLAYING:
		trigger_victory()
	

func _on_player_caught():
	if current_state == GameState.GAME_OVER: return
	trigger_game_over()

func trigger_game_over():
	current_state = GameState.GAME_OVER
	emit_signal("game_over")
	if game_over_ui: game_over_ui.show_game_over()
	get_tree().paused = true
	
func trigger_victory():
	current_state = GameState.VICTORY
	emit_signal("game_won")
	await get_tree().create_timer(0.5).timeout

	if game_won_ui:
		game_won_ui.show_victory()
	
	get_tree().paused = true

func restart_game():
	current_state = GameState.PLAYING
	get_tree().paused = false
	if game_over_ui:
		game_over_ui.queue_free()
		game_over_ui = null
	if game_won_ui:
		game_won_ui.queue_free()
		game_won_ui = null
	
	DestructionManager.reset_count()
	emit_signal("game_restarted")
	
	# Reload the current scene
	
	get_tree().reload_current_scene()
	await get_tree().process_frame
	await get_tree().process_frame
	connect_to_enemies()
	setup_game_over_ui()
	setup_game_won_ui()

func go_to_main_menu():
	current_state = GameState.MENU
	get_tree().paused = false
	if game_over_ui:
		game_over_ui.queue_free()
		game_over_ui = null
	if game_won_ui:
		game_won_ui.queue_free()
		game_won_ui = null
	
	get_tree().change_scene_to_file(main_menu_path)
	
func start_game():
	print("Starting game from menu...")
	current_state = GameState.PLAYING
	get_tree().change_scene_to_file(game_scene_path)
	
	await get_tree().process_frame
	await get_tree().process_frame
	connect_to_enemies()
	setup_game_over_ui()
	setup_game_won_ui()
	
	DestructionManager.destruction_count_changed.connect(_on_destruction_count_changed)

func pause_game():
	if current_state == GameState.PLAYING or current_state == GameState.TUTORIAL:
		current_state = GameState.PAUSED
		get_tree().paused = true
	
	
	
	
	
#Delete this!!!!!		
func _input(event):
	# Press T to test victory manually
	if event.is_action_pressed("ui_text_completion_accept") or Input.is_key_pressed(KEY_T):
		print("Manual test: calling _on_destruction_count_changed(99)")
		_on_destruction_count_changed(99)

func resume_game():
	if current_state == GameState.PAUSED:
		# Determine previous state based on current scene
		if get_tree().current_scene.scene_file_path == tutorial_scene_path:
			current_state = GameState.TUTORIAL
		else:
			current_state = GameState.PLAYING
		get_tree().paused = false

func is_game_over() -> bool:
	return current_state == GameState.GAME_OVER

func is_playing() -> bool:
	return current_state == GameState.PLAYING or current_state == GameState.TUTORIAL
