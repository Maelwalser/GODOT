extends Node3D

# Flag showing if player can pickup Knuckles
var player_in_area = false

@onready var canvas_layer = $CanvasLayer
@onready var prompt_label = $CanvasLayer/Label

# Called when the node enters the scene tree for the first time.
func _ready():
	# Setup prompt label
	if prompt_label:
		prompt_label.text = "Press E"
		prompt_label.add_theme_font_size_override("font_size", 34)
		prompt_label.add_theme_color_override("font_color", Color.YELLOW)
		prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
		prompt_label.add_theme_constant_override("outline_size", 3)
		prompt_label.visible = false  # Hide by default
		prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Check for E key press
	if Input.is_action_just_pressed("interact") and player_in_area:
		pickup_knuckles()
	
	# Make label follow Knuckles position on screen
	if prompt_label and prompt_label.visible:
		update_label_position()

func update_label_position():
	# Get camera
	var camera = get_viewport().get_camera_3d()
	if camera:
		# Convert 3D position to 2D screen position
		var screen_pos = camera.unproject_position(global_position)
		# Position label above Knuckles
		prompt_label.position = screen_pos - Vector2(50, 60)

func pickup_knuckles():
	# Increase global counter
	GameManager.knuckles += 1
	print("Knuckles collected: ", GameManager.knuckles)
	
	# Remove Knuckles from scene
	queue_free()

# When player enters Knuckles area
func _on_area_3d_body_entered(body):
	print("Body entered: ", body.name)
	print("Body groups: ", body.get_groups())
	
	if body.is_in_group("Player"):
		player_in_area = true
		if prompt_label:
			prompt_label.visible = true
		print("Press E to pickup Knuckles")

func _on_area_3d_body_exited(body):
	print("Body exited: ", body.name)
	
	if body.is_in_group("Player"):
		player_in_area = false
		if prompt_label:
			prompt_label.visible = false
