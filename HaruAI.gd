class_name AIControllerHaru
extends CharacterBody3D

signal player_caught

@export_group("Movement")
@export var walk_speed : float = 3.0
@export var run_speed : float = 6.0
@export var rotation_speed : float = 5.0

@export_group("Vision")
@export var vision_range : float = 12.0
@export var vision_angle : float = 45.0
@export var show_vision_area : bool = true

@export var vision_color_chase : Color = Color(1.0, 0.5, 0.0, 0.4) 
@export var vision_color_patrol : Color = Color(0.0, 0.0, 1.0, 0.4)

@export_group("AI Parameters")
@export var patrol_path : Path3D
@export var lose_player_delay : float = 5.0
@export var chase_update_interval : float = 0.2
@export var attack_distance : float = 2.0
@export var patrol_point_reached_range : float = 1.0


enum State {PATROL, SEARCH, CHASE}
var current_state : State = State.PATROL


var patrol_points : PackedVector3Array
var current_patrol_index : int = 0

var time_since_lost_sight : float = 0.0
var time_since_path_update : float = 0.0
var player_distance : float
var last_known_player_position : Vector3
var last_known_player_velocity : Vector3 = Vector3.ZERO
var search_path_extended : bool = false

# NODES
@onready var anim_player : AnimationPlayer = $Haru/AnimationPlayer
@onready var agent : NavigationAgent3D = get_node("NavigationAgent3D")
@onready var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var player = get_tree().get_nodes_in_group("Player")[0] if get_tree().get_nodes_in_group("Player").size() > 0 else null

@onready var vision_area : Area3D = $Area3D
@onready var vision_collision : CollisionShape3D = $Area3D/CollisionShape3D
@onready var vision_visual : MeshInstance3D

func _ready():
	# Vision Setup
	if vision_area:
		vision_area.body_entered.connect(_on_body_entered)
		vision_area.body_exited.connect(_on_body_exited)
	
	if show_vision_area and vision_collision:
		create_vision_visual_from_collision()
		
	# Navigation Setup
	if agent:
		agent.path_desired_distance = 1.0
		agent.target_desired_distance = attack_distance
		agent.path_max_distance = 1.0
		agent.radius = 2.0 
		agent.avoidance_enabled = true
		agent.max_speed = run_speed
		agent.velocity_computed.connect(_on_velocity_computed)
		agent.debug_enabled = true
		

		print("Haru Agent Ready.")

	# Patrol Setup
	if patrol_path:
		var curve = patrol_path.curve
		for i in range(curve.point_count):
			patrol_points.append(patrol_path.to_global(curve.get_point_position(i)))
	else:
		print("Warning: No Patrol Path assigned to Haru!")

func _process(delta):
	if player:
		player_distance = global_position.distance_to(player.global_position)
	
	# State Machine
	match current_state:
		State.CHASE:
			process_chase_state(delta)
		State.SEARCH:
			process_search_state(delta)
		State.PATROL:
			process_patrol_state(delta)

	update_vision_visual()

# STATE LOGIC

func process_chase_state(delta):
	# Vision Check
	if not is_player_in_vision_cone():
		print("Haru lost sight! Switching to Search.")
		last_known_player_position = player.global_position
		last_known_player_velocity = player.velocity # Capture velocity for prediction
		agent.target_position = last_known_player_position
		
		current_state = State.SEARCH
		time_since_lost_sight = 0.0
		search_path_extended = false
		return

	# Update tracking data
	last_known_player_position = player.global_position
	
	# Attack Logic
	if player_distance <= attack_distance:
		emit_signal("player_caught")
		agent.target_position = global_position # Stop
		return

	# Path Update
	time_since_path_update += delta
	if time_since_path_update >= chase_update_interval:
		agent.target_position = player.global_position
		time_since_path_update = 0.0

func process_search_state(delta):
	# If we see them, go back to chase immediately
	if is_player_in_vision_cone():
		print("Haru found player again! Resuming Chase.")
		current_state = State.CHASE
		return
		
	time_since_lost_sight += delta
	
	if agent.is_navigation_finished():
		
		# If we reached the "last known spot" AND we have grace time left -> Predict
		if not search_path_extended and time_since_lost_sight < lose_player_delay:
			predict_and_extend_path()
		
		# If time is up or we finished the prediction path -> Return to Patrol
		elif time_since_lost_sight >= lose_player_delay:
			print("Haru giving up. Returning to Patrol.")
			current_state = State.PATROL
			find_closest_patrol_point()

func predict_and_extend_path():
	print("Haru predicting player movement...")
	search_path_extended = true
	
	var time_left = lose_player_delay - time_since_lost_sight
	
	# Get Direction
	var search_dir = last_known_player_velocity.normalized()
	# Fallback if player was standing still
	if search_dir.length_squared() < 0.1:
		search_dir = (last_known_player_position - global_position).normalized()
	
	# Calculate new point based on speed and remaining grace time
	var extra_distance = run_speed * time_left
	var predicted_pos = last_known_player_position + (search_dir * extra_distance)
	
	# Snap to NavMesh
	var map = get_world_3d().navigation_map
	var safe_pos = NavigationServer3D.map_get_closest_point(map, predicted_pos)
	
	agent.target_position = safe_pos

func process_patrol_state(delta):
	# Vision Check
	if is_player_in_vision_cone():
		print("Haru spotted player! Starting Chase.")
		current_state = State.CHASE
		return
		
	if patrol_points.is_empty():
		return 
		
	var target = patrol_points[current_patrol_index]
	agent.target_position = target
	
	if agent.is_navigation_finished():
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()

# MOVEMENT & PHYSICS

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Stop if we reached destination and aren't patrolling
	if agent.is_navigation_finished() and current_state != State.PATROL:
		velocity.x = move_toward(velocity.x, 0, run_speed * delta)
		velocity.z = move_toward(velocity.z, 0, run_speed * delta)
	else:
		var next_path_position = agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		
		var speed = walk_speed if current_state == State.PATROL else run_speed
		var intended_velocity = direction * speed
		
		if agent.avoidance_enabled:
			agent.set_velocity(intended_velocity)
		else:
			_on_velocity_computed(intended_velocity)

	handle_animation()
	handle_rotation(delta)

func handle_rotation(delta):

	
	if current_state == State.CHASE and player:
		look_at_smoothly(player.global_position, delta)
	
	elif velocity.length_squared() > 0.1:
		# atan2(x, z) gives angle for +Z forward characters
		var target_rot = atan2(velocity.x, velocity.z) 
		rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)
	
	elif current_state == State.SEARCH:
		look_at_smoothly(agent.target_position, delta)

func look_at_smoothly(target_pos: Vector3, delta: float):
	var direction = (target_pos - global_position).normalized()
	direction.y = 0
	if direction.length() > 0:
		var target_rot = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)

func _on_velocity_computed(safe_velocity: Vector3):
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	move_and_slide()

# ANIMATION

func handle_animation():
	if not anim_player: return
	
	var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
	var walk_anim_name = "walk" 
	
	if horizontal_speed > 0.1:
		if anim_player.current_animation != walk_anim_name:
			var anim_speed = 1.0 if current_state == State.PATROL else 1.5
			anim_player.play(walk_anim_name, 0.2, anim_speed)
	else:
		if anim_player.is_playing() and anim_player.current_animation == walk_anim_name:
			anim_player.stop()

# UTILITY 

func is_player_in_vision_cone() -> bool:
	if not player: return false
	
	if player_distance > vision_range:
		return false
		
	var direction_to_player = (player.global_position - global_position).normalized()
	direction_to_player.y = 0 
	
	var forward = transform.basis.z 
	forward.y = 0
	
	var angle = rad_to_deg(forward.angle_to(direction_to_player))
	
	if angle > vision_angle:
		return false
		
	# Raycast for walls
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1, 0), player.global_position + Vector3(0, 1, 0))
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == player:
		return true
		
	return false

func find_closest_patrol_point():
	if patrol_points.is_empty(): return
	
	var closest_dist = INF
	var closest_index = 0
	
	for i in range(patrol_points.size()):
		var d = global_position.distance_to(patrol_points[i])
		if d < closest_dist:
			closest_dist = d
			closest_index = i
			
	current_patrol_index = closest_index

# VISUAL DEBUG

func update_vision_visual():
	if not vision_visual or not vision_visual.material_override: return
	
	if current_state == State.CHASE:
		vision_visual.material_override.albedo_color = vision_color_chase
	elif current_state == State.SEARCH:
		vision_visual.material_override.albedo_color = Color(1.0, 1.0, 0.0, 0.2) # Yellowish
	else:
		vision_visual.material_override.albedo_color = vision_color_patrol

func create_vision_visual_from_collision():
	vision_visual = MeshInstance3D.new()
	vision_collision.add_child(vision_visual)
	var shape = vision_collision.shape
	
	# Recreate mesh based on shape
	if shape is SphereShape3D:
		var m = SphereMesh.new(); m.radius = shape.radius; m.height = shape.radius * 2; vision_visual.mesh = m
	elif shape is BoxShape3D:
		var m = BoxMesh.new(); m.size = shape.size; vision_visual.mesh = m
	elif shape is CylinderShape3D:
		var m = CylinderMesh.new(); m.height = shape.height; m.top_radius = shape.radius; m.bottom_radius = shape.radius; vision_visual.mesh = m
	elif shape is CapsuleShape3D:
		var m = CapsuleMesh.new(); m.radius = shape.radius; m.height = shape.height; vision_visual.mesh = m
	
	var material = StandardMaterial3D.new()
	material.albedo_color = vision_color_patrol
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vision_visual.material_override = material

# Signals for Area3D 
func _on_body_entered(body): pass
func _on_body_exited(body): pass
