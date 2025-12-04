# game_manager.gd
extends Node

signal game_over
signal game_restarted
signal game_won

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER, VICTORY }

var current_state : GameState = GameState.MENU
var game_over_ui : CanvasLayer = null
var game_won_ui : Control = null


@export var win_threshold: int = 20

@export var main_menu_path : String = "res://scenes/ui/main_menu.tscn"
@export var game_scene_path : String = "res://main.tscn"



func _ready():
	# Wait for scene to be ready
	await get_tree().process_frame
	
	# Only connect to enemies and setup UI if we're in the game scene (not menu)
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.name != "MainMenu":
		current_state = GameState.PLAYING
		connect_to_enemies()
		setup_game_over_ui()
		setup_game_won_ui()
		DestructionManager.destruction_count_changed.connect(_on_destruction_count_changed)

func connect_to_enemies():
	var enemies = get_tree().get_nodes_in_group("Enemy")
	print("Found enemies: ", enemies.size())
	for enemy in enemies:
		print("Enemy found: ", enemy.name)
		if enemy.has_signal("player_caught"):
			if not enemy.player_caught.is_connected(_on_player_caught):
				enemy.player_caught.connect(_on_player_caught)
				print("Connected to enemy signal: ", enemy.name)

func setup_game_over_ui():
	# Don't create duplicate UI
	if game_over_ui != null:
		return
		
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
	print(">>> SIGNAL RECEIVED: player_caught <<<")
	if current_state == GameState.GAME_OVER:
		return
	
	trigger_game_over()

func trigger_game_over():
	print("GAME OVER!")
	current_state = GameState.GAME_OVER
	emit_signal("game_over")
	
	if game_over_ui:
		game_over_ui.show_game_over()
	
	get_tree().paused = true
	
func trigger_victory():
	current_state = GameState.VICTORY
	emit_signal("game_won")
	
	if game_won_ui:
		game_won_ui.show_victory()
		
	get_tree().paused = true

func restart_game():
	print("Restarting game...")
	current_state = GameState.PLAYING
	get_tree().paused = false
	
	# Clean up old UI
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
	
	# Reconnect after reload
	await get_tree().process_frame
	await get_tree().process_frame
	connect_to_enemies()
	setup_game_over_ui()
	setup_game_won_ui()

func go_to_main_menu():
	print("Returning to main menu...")
	current_state = GameState.MENU
	get_tree().paused = false
	
	# Clean up game over UI
	if game_over_ui:
		game_over_ui.queue_free()
		game_over_ui = null
	if game_won_ui:
		game_won_ui.queue_free()
		game_won_ui = null
	
	get_tree().change_scene_to_file(main_menu_path)
	
	#remove this, only for testing purposes
func test_trigger_victory():
	if current_state == GameState.PLAYING:
		trigger_victory()

func start_game():
	print("Starting game from menu...")
	current_state = GameState.PLAYING
	get_tree().change_scene_to_file(game_scene_path)
	
	await get_tree().process_frame
	await get_tree().process_frame
	connect_to_enemies()
	setup_game_over_ui()
	setup_game_won_ui()

func pause_game():
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true

func resume_game():
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false

func is_game_over() -> bool:
	return current_state == GameState.GAME_OVER

func is_playing() -> bool:
	return current_state == GameState.PLAYING
	
func is_game_won() -> bool:
	return current_state == GameState.VICTORY
