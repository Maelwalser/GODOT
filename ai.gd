class_name AIController
extends CharacterBody3D

@export var walk_speed : float = 1.0
@export var run_speed : float = 2.5
@export var rotation_speed : float = 5.0
@export var vision_range : float = 10.0
@export var vision_angle : float = 45.0
@export var lose_player_delay : float = 1.0  # Time before stopping tracking after losing sight

var is_running : bool = false
var is_stopped : bool = false
var look_at_player : bool = false
var move_direction : Vector3 
var target_y_rot : float
var player_in_range : bool = false
var time_since_lost_sight : float = 0.0  # Timer for tracking delay
var player_was_in_cone : bool = false  # Track if player was recently visible

@onready var agent : NavigationAgent3D = get_node("NavigationAgent3D")
@onready var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var player = get_tree().get_nodes_in_group("Player")[0]
@onready var vision_area : Area3D = $Area3D

var player_distance : float

func _ready():
	if vision_area:
		vision_area.body_entered.connect(_on_body_entered)
		vision_area.body_exited.connect(_on_body_exited)

func _process(delta):
	if player != null:
		player_distance = position.distance_to(player.position)
		
		# Check if player is currently in vision cone
		if player_in_range:
			var player_in_cone = is_player_in_vision_cone()
			
			if player_in_cone:
				# Player is in view - track and chase
				look_at_player = true
				is_running = true
				move_to_positioin(player.position)
				time_since_lost_sight = 0.0  # Reset timer
				player_was_in_cone = true
			else:
				# Player left vision cone - start counting delay
				if player_was_in_cone:
					time_since_lost_sight += delta
					
					# Continue tracking during grace period
					if time_since_lost_sight < lose_player_delay:
						look_at_player = true
						is_running = true
						move_to_positioin(player.position)
					else:
						# Grace period expired - stop tracking
						look_at_player = false
						is_running = false
						player_was_in_cone = false

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	var target_pos = agent.get_next_path_position()
	var move_dir = position.direction_to(target_pos)
	move_dir.y = 0
	move_dir = move_dir.normalized()
	
	if agent.is_navigation_finished() or is_stopped:
		move_dir = Vector3.ZERO
		
	var current_speed = walk_speed
	
	if is_running:
		current_speed = run_speed
		
	velocity.x = move_dir.x * current_speed
	velocity.z = move_dir.z * current_speed
	
	move_and_slide()
	
	if look_at_player and player != null:
		var player_dir = player.position - position
		target_y_rot = atan2(player_dir.x, player_dir.z)
	elif velocity.length() > 0:
		target_y_rot = atan2(velocity.x, velocity.z)
	
	rotation.y = lerp_angle(rotation.y, target_y_rot, rotation_speed * delta)

func is_player_in_vision_cone() -> bool:
	if player == null:
		return false
	
	var direction_to_player = (player.position - position).normalized()
	direction_to_player.y = 0
	direction_to_player = direction_to_player.normalized()
	
	var forward = -transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	
	var dot_product = forward.dot(direction_to_player)
	var angle = rad_to_deg(acos(dot_product))
	
	return angle <= vision_angle and player_distance <= vision_range

func _on_body_entered(body):
	if body.is_in_group("Player"):
		player_in_range = true

func _on_body_exited(body):
	if body.is_in_group("Player"):
		player_in_range = false
		# Start the grace period timer instead of immediately stopping
		# The _process function will handle the delay

func move_to_positioin(to_position: Vector3, adjust_pos : bool = true):
	if not agent:
		agent = get_node("NavigationAgent3D")
	
	is_stopped = false
	
	if adjust_pos:
		var map = get_world_3d().navigation_map
		var adjusted_pos = NavigationServer3D.map_get_closest_point(map, to_position)
		agent.target_position = adjusted_pos
	else:
		agent.target_position = to_position
