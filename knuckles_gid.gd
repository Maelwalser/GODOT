extends Node3D

var player_in_area = false
var player_node = null

@onready var canvas_layer = $CanvasLayer
@onready var prompt_label = $CanvasLayer/Label

# Called when the node enters the scene tree for the first time.
func _ready():
	# Setup prompt label
	if prompt_label:
		prompt_label.text = "Find 9 Knuckles and get a cookie! Good luck <3"
		prompt_label.add_theme_font_size_override("font_size", 34)
		prompt_label.add_theme_color_override("font_color", Color.RED)
		prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
		prompt_label.add_theme_constant_override("outline_size", 3)
		prompt_label.visible = false  # Hide by default
		prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Make label follow Knuckles position on screen
	if prompt_label and prompt_label.visible:
		update_label_position()
	
	# Rotate Knuckles to face player
	if player_in_area and player_node:
		look_at_player()

func update_label_position():
	# Get camera
	var camera = get_viewport().get_camera_3d()
	if camera:
		# Convert 3D position to 2D screen position
		var screen_pos = camera.unproject_position(global_position)
		# Position label above Knuckles
		prompt_label.position = screen_pos - Vector2(50, 60)

func look_at_player():
	# Make Knuckles rotate towards player
	var direction = player_node.global_position - global_position
	direction.y = 0  # Keep rotation only on Y axis (horizontal)
	
	if direction.length() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 0.1)

# When player enters Knuckles area
func _on_area_3d_body_entered(body):
	print("Body entered: ", body.name)
	print("Body groups: ", body.get_groups())
	
	if body.is_in_group("Player"):
		player_in_area = true
		player_node = body
		if prompt_label:
			prompt_label.visible = true
		print("Player nearby!")

# When player exits Knuckles area
func _on_area_3d_body_exited(body):
	print("Body exited: ", body.name)
	
	if body.is_in_group("Player"):
		player_in_area = false
		player_node = null
		if prompt_label:
			prompt_label.visible = false
