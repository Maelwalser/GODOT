extends CanvasLayer

@onready var panel : Control = $Panel
@onready var restart_button : Button = $Panel/VBoxContainer/RestartButton
@onready var quit_button : Button = $Panel/VBoxContainer/QuitButton

func _ready():
	# This UI should work even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Hide initially
	panel.visible = false
	
	# Connect buttons
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func show_game_over():
	panel.visible = true
	
	# Release mouse for UI interaction
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func hide_game_over():
	panel.visible = false

func _on_restart_pressed():
	hide_game_over()
	GameManager.restart_game()

func _on_quit_pressed():
	get_tree().quit()
