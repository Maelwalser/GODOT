extends Node

signal game_over
signal game_restarted

enum GameState { PLAYING, PAUSED, GAME_OVER }

var current_state : GameState = GameState.PLAYING
var game_over_ui : CanvasLayer = null

func _ready():
	# Wait for scene to be ready
	await get_tree().process_frame
	connect_to_enemies()
	setup_game_over_ui()

func connect_to_enemies():
	var enemies = get_tree().get_nodes_in_group("Enemy")
	for enemy in enemies:
		if enemy.has_signal("player_caught"):
			if not enemy.player_caught.is_connected(_on_player_caught):
				enemy.player_caught.connect(_on_player_caught)
	print("Connected to ", enemies.size(), " enemies")

func setup_game_over_ui():
	# Load and instantiate the game over UI
	var ui_scene = load("res://scenes/ui/game_over_ui.tscn")
	if ui_scene:
		game_over_ui = ui_scene.instantiate()
		get_tree().root.call_deferred("add_child", game_over_ui)

func _on_player_caught():
	if current_state == GameState.GAME_OVER:
		return
	
	trigger_game_over()

func trigger_game_over():
	print("GAME OVER!")
	current_state = GameState.GAME_OVER
	emit_signal("game_over")
	
	# Show game over UI
	if game_over_ui:
		game_over_ui.show_game_over()
	
	# Pause the game (but allow UI to work)
	get_tree().paused = true

func restart_game():
	print("Restarting game...")
	current_state = GameState.PLAYING
	get_tree().paused = false
	emit_signal("game_restarted")
	
	# Reload the current scene
	get_tree().reload_current_scene()
	
	# Reconnect to enemies after scene reload
	await get_tree().process_frame
	await get_tree().process_frame
	connect_to_enemies()

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
