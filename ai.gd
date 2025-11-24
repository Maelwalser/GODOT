class_name AIController
extends CharacterBody3D

@export var walk_speed : float = 1.0
@export var run_speed : float = 2.5
@export var rotation_speed : float = 5.0
@export var vision_range : float = 10.0
@export var vision_angle : float = 45.0
@export var lose_player_delay : float = 1.0  # Time before stopping tracking after losing sight
@export var chase_update_interval : float = 0.2

var is_running : bool = false
var is_stopped : bool = true
var look_at_player : bool = false
var move_direction : Vector3 
var target_y_rot : float
var player_in_range : bool = false
var time_since_lost_sight : float = 0.0  # Timer for tracking delay
var player_was_in_cone : bool = false  # Track if player was recently visible
var time_since_path_update : float = 0.0  # Timer for path updates

@onready var agent : NavigationAgent3D = get_node("NavigationAgent3D")
@onready var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var player = get_tree().get_nodes_in_group("Player")[0]
@onready var vision_area : Area3D = $Area3D

@export var show_vision_area : bool = true
@export var vision_color : Color = Color(1.0, 0.0, 0.0, 0.5)  # Red with 50% opacity
@onready var vision_collision : CollisionShape3D = $Area3D/CollisionShape3D
@onready var vision_visual : MeshInstance3D

var player_distance : float
var last_known_player_position : Vector3
var is_chasing : bool = false

func _ready():
	if vision_area:
		vision_area.body_entered.connect(_on_body_entered)
		vision_area.body_exited.connect(_on_body_exited)
		
	if show_vision_area and vision_collision:
		create_vision_visual_from_collision()
		
	if agent:
		agent.path_desired_distance = 0.5
		agent.target_desired_distance = 1.0
		agent.path_max_distance = 1.0
		agent.avoidance_enabled = false
		agent.max_speed = run_speed
		

func create_vision_visual_from_collision():
	# Create a MeshInstance3D that matches the collision shape
	vision_visual = MeshInstance3D.new()
	vision_collision.add_child(vision_visual)  # Add as child to follow the collision shape
	
	# Get the shape from the CollisionShape3D
	var shape = vision_collision.shape
	
	# Create a mesh that matches the collision shape
	if shape is SphereShape3D:
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = shape.radius
		sphere_mesh.height = shape.radius * 2
		vision_visual.mesh = sphere_mesh
		
	elif shape is BoxShape3D:
		var box_mesh = BoxMesh.new()
		box_mesh.size = shape.size
		vision_visual.mesh = box_mesh
		
	elif shape is CylinderShape3D:
		var cylinder_mesh = CylinderMesh.new()
		cylinder_mesh.height = shape.height
		cylinder_mesh.top_radius = shape.radius
		cylinder_mesh.bottom_radius = shape.radius
		vision_visual.mesh = cylinder_mesh
		
	elif shape is CapsuleShape3D:
		var capsule_mesh = CapsuleMesh.new()
		capsule_mesh.radius = shape.radius
		capsule_mesh.height = shape.height
		vision_visual.mesh = capsule_mesh
	
	# Create and apply semi-transparent material
	var material = StandardMaterial3D.new()
	material.albedo_color = vision_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show both sides
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # Unlit
	material.no_depth_test = false  # makes it not visible through walls
	
	vision_visual.material_override = material

# Change color when tracking
func update_vision_color(tracking: bool):
	if vision_visual and vision_visual.material_override:
		if tracking:
			vision_visual.material_override.albedo_color = Color(1.0, 1.0, 0.0, 0.2)  # Yellow when tracking
		else:
			vision_visual.material_override.albedo_color = Color(1.0, 0.0, 0.0, 0.2)  # Red when idle

func _process(delta):
	if player != null:
		player_distance = position.distance_to(player.position)
		
		if player_in_range:
			# Player is in the area
			if not player_was_in_cone:
				# Check if we can initially spot the player (vision cone check)
				if is_player_in_vision_cone():
					# Start tracking
					player_was_in_cone = true
					time_since_lost_sight = 0.0
					update_vision_color(true)
					print("Enemy spotted player! Starting chase!") # Debug
			
			# If we're tracking (either just started or already tracking)
			if player_was_in_cone:
				look_at_player = true
				is_running = true
				is_stopped = false
				last_known_player_position = player.position
				time_since_path_update += delta
				if time_since_path_update >= chase_update_interval:
					move_to_position(player.position)
					time_since_path_update = 0.0 # Continuously update target position
					
				time_since_lost_sight = 0.0
		else:
			# Player is NOT in range - handle grace period
			if player_was_in_cone:
				time_since_lost_sight += delta
				
				if time_since_lost_sight < lose_player_delay:
					# Still within grace period - continue tracking last known position
					look_at_player = true
					is_running = true
					is_stopped = false
					if last_known_player_position:
						move_to_position(last_known_player_position)
					
					print("Lost sight! Chasing for ", lose_player_delay - time_since_lost_sight, " more seconds")  # Debug
				else:
					# Grace period expired - stop tracking
					print("Lost player completely. Stopping chase.")  # Debug
					look_at_player = false
					is_running = false
					player_was_in_cone = false
					time_since_lost_sight = 0.0
					update_vision_color(false) 
			else:
				# Not tracking
				look_at_player = false
				is_running = false

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	# Only move if we have a valid path
	if not agent.is_navigation_finished() and not is_stopped:
		var target_pos = agent.get_next_path_position()
		var move_dir = position.direction_to(target_pos)
		move_dir.y = 0
		move_dir = move_dir.normalized()
		
		# Use appropriate speed
		var current_speed = walk_speed
		if is_running:
			current_speed = run_speed
		
		velocity.x = move_dir.x * current_speed
		velocity.z = move_dir.z * current_speed
	else:
		# Stop movement when navigation is finished or stopped
		velocity.x = 0
		velocity.z = 0
	
	move_and_slide()
	
	if look_at_player and player != null:
		var player_dir = player.position - position
		target_y_rot = atan2(player_dir.x, player_dir.z)
	elif velocity.length() > 0.1:
		target_y_rot = atan2(velocity.x, velocity.z)
	
	var visual_rotation = target_y_rot + deg_to_rad(180)
	rotation.y = lerp_angle(rotation.y, visual_rotation, rotation_speed * delta)

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

func move_to_position(to_position: Vector3, adjust_pos : bool = true):
	if not agent:
		agent = get_node("NavigationAgent3D")
	
	is_stopped = false
	
	if adjust_pos:
		var map = get_world_3d().navigation_map
		var adjusted_pos = NavigationServer3D.map_get_closest_point(map, to_position)
		agent.target_position = adjusted_pos
		print("Set navigation target to: ", adjusted_pos)
	else:
		agent.target_position = to_position
		print("Set navigation target to: ", to_position)
