extends Control

@onready var start_button: Button = $MarginContainer/VBoxContainer/StartButton
@onready var quit_button: Button = $MarginContainer/VBoxContainer/QuitButton
@onready var tutorial_button: Button = $MarginContainer/VBoxContainer/TutorialButton

@export var game_scene_path : String = "res://main.tscn"
@export var character_animator: AnimationPlayer
@export var animation_name: String = "Wave"

func _ready():

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Connect buttons
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	

	_play_intro_animation()
	
func _play_intro_animation() -> void:
	if character_animator:
		if character_animator.has_animation(animation_name):
			character_animator.play(animation_name)
		else:
			push_warning("Main Menu: Animation '" + animation_name + "' not found on the player.")
	else:
		push_warning("Main Menu: Character Animator not assigned in Inspector.")

func _on_start_pressed():
	print("Starting game...")
	GameManager.start_game() 

func _on_quit_pressed():
	get_tree().quit()
	
func _on_tutorial_pressed():
	print("Starting tutorial manually...")
	GameManager.force_start_tutorial()
