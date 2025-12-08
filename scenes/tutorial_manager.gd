extends Node3D

@onready var dialogue_label: RichTextLabel = $CanvasLayer/Control/MarginContainer/Panel/RichTextLabel
@onready var dialogue_panel: Control = $CanvasLayer/Control
@onready var character_animator: AnimationPlayer = $Background/Lisa/AnimationPlayer 

@export_multiline var dialogue_lines: Array[String] = [
	"Welcome, Apprentice. You haven't been at work for a long time.",
	"Your superiors are searching you. Make sure they don't catch you.",
	"Your goal is simple: Collect Knuckles and create Havoc without detection.",
	"Press WASD to move. Press Shift to sprint. Press Space to jump. Good luck!"
]

@export var talk_animation: String = "Talking"
@export var text_speed: float = 0.05 

# State
var current_line_index: int = 0
var is_typing: bool = false
var active_tween: Tween = null # Store the specific tween to kill it safely

func _ready() -> void:
	if dialogue_lines.is_empty():
		push_error("Tutorial: No dialogue lines defined!")
		end_tutorial()
		return
		
	start_dialogue()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		if is_typing:
			_complete_current_line()
		else:
			_advance_dialogue()

func start_dialogue() -> void:
	current_line_index = 0
	dialogue_panel.show()
	_show_line()

func _show_line() -> void:
	var line = dialogue_lines[current_line_index]
	dialogue_label.text = line
	dialogue_label.visible_ratio = 0.0
	is_typing = true
	
	# Start Talking Animation
	_set_talking_state(true)
	
	# Kill previous tween if it exists, just in case
	if active_tween: active_tween.kill()
	
	active_tween = create_tween()
	var duration = line.length() * text_speed
	active_tween.tween_property(dialogue_label, "visible_ratio", 1.0, duration)
	
	active_tween.finished.connect(_on_typing_finished)

func _on_typing_finished() -> void:
	is_typing = false
	# Stop Talking Animation
	_set_talking_state(false)

func _complete_current_line() -> void:
	# Safely kill ONLY the text tween, not other game tweens
	if active_tween:
		active_tween.kill()
	
	dialogue_label.visible_ratio = 1.0
	_on_typing_finished()

func _advance_dialogue() -> void:
	current_line_index += 1
	
	if current_line_index < dialogue_lines.size():
		_show_line()
	else:
		end_tutorial()

# ANIMATION LOGIC
func _set_talking_state(is_talking: bool) -> void:
	if not character_animator: return
	
	if is_talking:
		# If we are supposed to talk, play the animation
		character_animator.play(talk_animation)
	else:
		character_animator.pause()

func end_tutorial() -> void:
	dialogue_panel.hide()
	print("Tutorial Finished. Handing over to GameManager.")
	GameManager.finish_tutorial()
