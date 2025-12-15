class_name AIControllerMoritz
extends CharacterBody3D
signal player_caught

@export_group("Hearing")
@export var hearing_range : float = 30.0
@export var investigate_duration : float = 4.0

@export_group("Movement")
@export var walk_speed : float = 3.5
@export var run_speed : float = 6.0
@export var rotation_speed : float = 5.0
@export var jump_height : float = 2.5 

@export_group("Vision")
@export var vision_range : float = 13.0
@export var vision_angle : float = 70.0

@export_group("AI Parameters")
@export var patrol_path : Path3D
@export var lose_player_delay : float = 5.0
@export var chase_update_interval : float = 0.2
@export var attack_distance : float = 2.5
@export var attack_vertical_range : float = 3.0
@export var patrol_point_reached_range : float = 1.0

@export var min_laugh_interval : float = 3.0  
@export var laugh_chance : float = 0.5


enum State {PATROL, SEARCH, CHASE, INVESTIGATE}
var current_state : State = State.PATROL

var patrol_points : PackedVector3Array
var current_patrol_index : int = 0

var laugh_cooldown : float = 0.0

var time_since_lost_sight : float = 0.0
var time_since_path_update : float = 0.0
var player_distance : float
var last_known_player_position : Vector3

var last_known_player_velocity : Vector3 = Vector3.ZERO
var search_path_extended : bool = false

var investigation_target : Vector3
var investigation_time : float = 0.0

# Nodes
@onready var anim_player : AnimationPlayer = $Moritz/AnimationPlayer
@onready var agent : NavigationAgent3D = get_node("NavigationAgent3D")
@onready var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var player = get_tree().get_nodes_in_group("Player")[0] if get_tree().get_nodes_in_group("Player").size() > 0 else null
@onready var vision_area : Area3D = $Area3D
@onready var footstep_player: AudioStreamPlayer3D = $FootStepPlayer
@onready var laugh_sound: AudioStreamPlayer3D = $LaughSound


func _ready():
	if vision_area:
		vision_area.body_entered.connect(_on_body_entered)
		vision_area.body_exited.connect(_on_body_exited)
		
	if agent:
		agent.path_desired_distance = 1.0
		agent.target_desired_distance = 0.5
		agent.path_max_distance = 1.0
		agent.radius = 3.0
		agent.avoidance_enabled = true
		agent.max_speed = run_speed
		agent.velocity_computed.connect(_on_velocity_computed)
		agent.debug_enabled = false
		
		print("Navigation agent ready. Debug enabled: ", agent.debug_enabled)
		
	if patrol_path:
		var curve = patrol_path.curve
		for i in range(curve.point_count):
			patrol_points.append(patrol_path.to_global(curve.get_point_position(i)))
	else:
		print("Warning: No Patrol Path assigned to Moritz!")
		
func hear_noise(noise_position: Vector3):
	var distance = global_position.distance_to(noise_position)
	
	if distance > hearing_range:
		return
	
	if current_state == State.CHASE:
		return
	
	print("Haru heard something at: ", noise_position)
	investigation_target = noise_position
	investigation_time = 0.0
	current_state = State.INVESTIGATE
	agent.target_position = noise_position
	
func play_laugh_occasionally():
	if laugh_cooldown <= 0 and randf() < laugh_chance:
		if laugh_sound and not laugh_sound.playing:
			laugh_sound.play()
			laugh_cooldown = min_laugh_interval

func _process(delta):
	if player:
		player_distance = global_position.distance_to(player.global_position)
	
	if laugh_cooldown > 0:
		laugh_cooldown -= delta
		
	match current_state:
		State.CHASE:
			process_chase_state(delta)
		State.SEARCH:
			process_search_state(delta)
		State.PATROL:
			process_patrol_state(delta)
		State.INVESTIGATE:
			process_investigate_state(delta)
			
	

# STATE LOGIC

func process_investigate_state(delta):
	if is_player_in_vision_cone():
		print("Haru spotted player while investigating!")
		current_state = State.CHASE
		return
	
	investigation_time += delta
	
	if agent.is_navigation_finished() or investigation_time >= investigate_duration:
		print("Haru finished investigating. Returning to patrol.")
		current_state = State.PATROL
		find_closest_patrol_point()

func process_chase_state(delta):
	# If we lose visibility, switch to SEARCH (Grace period)
	if not is_player_in_vision_cone():
		print("Lost sight! Switching to Search Mode.")
		last_known_player_position = player.global_position
		last_known_player_velocity = player.velocity
		agent.target_position = last_known_player_position
		current_state = State.SEARCH
		time_since_lost_sight = 0.0
		search_path_extended = false
		return

	last_known_player_position = player.global_position
	
	# Attack Logic
	var horizontal_dist = Vector2(global_position.x, global_position.z).distance_to(Vector2(player.global_position.x, player.global_position.z))
	var vertical_dist = abs(global_position.y - player.global_position.y)
	
	# If close enough horizontally AND within vertical tolerance
	if horizontal_dist <= attack_distance and vertical_dist <= attack_vertical_range:
		emit_signal("player_caught")
		agent.target_position = global_position 
		return

	# Path Update Throttling
	time_since_path_update += delta
	if time_since_path_update >= chase_update_interval:
		agent.target_position = player.global_position
		time_since_path_update = 0.0

func process_search_state(delta):
	# If we see player again, go back to CHASE
	if is_player_in_vision_cone():
		print("Found player again! Resuming Chase.")
		current_state = State.CHASE
		return
		
	time_since_lost_sight += delta
	
	if agent.is_navigation_finished():
		
		# If we haven't extended the path yet, and we still have time left
		if not search_path_extended and time_since_lost_sight < lose_player_delay:
			predict_and_extend_path()
		
		# If we HAVE extended (or time is up), and we finished that path too -> Patrol
		elif time_since_lost_sight >= lose_player_delay:
			print("Given up search. Returning to Patrol.")
			current_state = State.PATROL
			find_closest_patrol_point()
	
func predict_and_extend_path():
	print("Reached last known spot. Predicting player movement...")
	search_path_extended = true
	
	# Calculate how much time is left in the search
	var time_left = lose_player_delay - time_since_lost_sight
	
	# Get Direction
	var search_dir = last_known_player_velocity.normalized()
	if search_dir.length_squared() < 0.1:
		search_dir = (last_known_player_position - global_position).normalized()
	
	# Calculate new point
	var extra_distance = run_speed * time_left
	var predicted_pos = last_known_player_position + (search_dir * extra_distance)
	
	# Snap to Navigation Mesh
	var map = get_world_3d().navigation_map
	var safe_pos = NavigationServer3D.map_get_closest_point(map, predicted_pos)
	
	# Set new target
	agent.target_position = safe_pos

func process_patrol_state(delta):
	# Vision Check
	if is_player_in_vision_cone():
		print("Spotted player! Starting Chase.")
		play_laugh_occasionally()
		current_state = State.CHASE
		return
		
	if patrol_points.is_empty():
		return 
		
	# Set Target
	var target = patrol_points[current_patrol_index]
	agent.target_position = target
	
	# Check for Arrival
	if agent.is_navigation_finished():
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()


# MOVEMENT LOGIC
func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	# Jump Logic
	if is_on_floor() and is_on_wall() and current_state == State.CHASE:
		if player and player.global_position.y > global_position.y + 0.5:
			# Simple calculation for velocity needed to reach jump_height: v = sqrt(2 * g * h)
			velocity.y = sqrt(2 * gravity * jump_height)
	# If we are close enough to the final target (and not patrolling), stop
	if agent.is_navigation_finished() and current_state != State.PATROL:
		velocity.x = move_toward(velocity.x, 0, run_speed * delta)
		velocity.z = move_toward(velocity.z, 0, run_speed * delta)
	else:
		# Standard Navigation Movement
		var next_path_position = agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		
		# Determine speed based on state
		var speed = walk_speed if current_state == State.PATROL else run_speed
		var intended_velocity = direction * speed
		
		if agent.avoidance_enabled:
			agent.set_velocity(intended_velocity)
		else:
			_on_velocity_computed(intended_velocity)
		
	var is_moving = velocity.length() > 0.1		
	if is_moving and is_on_floor():
		if not footstep_player.playing:
			footstep_player.play()
			
	else:
		if footstep_player.playing:
			footstep_player.stop()	

	# Animation Handling
	handle_animation()
	handle_rotation(delta)

func handle_rotation(delta):
	# If Chasing or Searching, look at interesting things
	if current_state == State.CHASE and player:
		look_at_smoothly(player.global_position, delta)
	
	if velocity.length_squared() > 0.1:
		var target_rot = atan2(-velocity.x, -velocity.z)
		rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)
	
	elif current_state == State.SEARCH:
		look_at_smoothly(agent.target_position, delta)

func look_at_smoothly(target_pos: Vector3, delta: float):
	var direction = (target_pos - global_position).normalized()
	direction.y = 0
	if direction.length() > 0:
		var target_rot = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)

func _on_velocity_computed(safe_velocity: Vector3):
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	move_and_slide()

func handle_animation():
	if not anim_player: return
	
	var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
	var walk_anim_name = "walk" 
	
	if horizontal_speed > 0.1:
		if anim_player.current_animation != walk_anim_name:
			# Speed up animation if running
			var anim_speed = 1.0 if current_state == State.PATROL else 1.5
			anim_player.play(walk_anim_name, 0.2, anim_speed)
	else:
		if anim_player.is_playing() and anim_player.current_animation == walk_anim_name:
			anim_player.stop()

# UTILITY

func is_player_in_vision_cone() -> bool:
	if not player: return false
	
	# Check Distance
	if player_distance > vision_range:
		return false
		
	# Check Angle
	var direction_to_player = (player.global_position - global_position).normalized()
	direction_to_player.y = 0 # Flatten to horizontal plane
	var forward = -transform.basis.z 
	forward.y = 0
	
	var angle = rad_to_deg(forward.angle_to(direction_to_player))
	
	if angle > vision_angle:
		return false
		
	# Check Raycast (Obstacles)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1, 0), player.global_position + Vector3(0, 1, 0))
	query.exclude = [self] # Don't detect self
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == player:
		return true
		
	return false

# Finds the closest point on the path so we don't walk all the way back to the start
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

# Empty signals required for Area3D connection
func _on_body_entered(body): pass 
func _on_body_exited(body): pass
