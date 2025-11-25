extends Control

@onready var start_button : Button = $VBoxContainer/StartButton
@onready var quit_button : Button = $VBoxContainer/QuitButton

@export var game_scene_path : String = "res://main.tscn"

func _ready():

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Connect buttons
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Focus the start button for keyboard/controller support
	start_button.grab_focus()

func _on_start_pressed():
	print("Starting game...")
	GameManager.start_game() 

func _on_quit_pressed():
	get_tree().quit()
