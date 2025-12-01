class_name AIControllerMoritz
extends CharacterBody3D
signal player_caught

@export var walk_speed : float = 2.0
@export var run_speed : float = 5.5
@export var rotation_speed : float = 5.0
@export var vision_range : float = 10.0
@export var vision_angle : float = 45.0
@export var lose_player_delay : float = 1.0
@export var chase_update_interval : float = 0.2
@export var attack_distance : float = 2.0



var is_running : bool = false
var is_stopped : bool = true
var look_at_player : bool = false
var player_in_range : bool = false
var time_since_lost_sight : float = 0.0
var player_was_in_cone : bool = false
var time_since_path_update : float = 0.0

@onready var anim_player : AnimationPlayer = $Moritz/AnimationPlayer
@onready var agent : NavigationAgent3D = get_node("NavigationAgent3D")
@onready var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var player = get_tree().get_nodes_in_group("Player")[0] if get_tree().get_nodes_in_group("Player").size() > 0 else null
@onready var vision_area : Area3D = $Area3D

@export var show_vision_area : bool = true
@export var vision_color : Color = Color(1.0, 0.0, 0.0, 0.4)
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
		agent.target_desired_distance = attack_distance
		agent.path_max_distance = 1.0
		agent.avoidance_enabled = true
		agent.max_speed = run_speed
		agent.debug_enabled = true
		agent.navigation_finished.connect(_on_navigation_finished)
		
		await get_tree().process_frame
		print("Navigation agent ready. Debug enabled: ", agent.debug_enabled)

func _process(delta):
	if player != null:
		player_distance = global_position.distance_to(player.global_position)
		
		if player_in_range:
			if not player_was_in_cone:
				if is_player_in_vision_cone():
					player_was_in_cone = true
					is_chasing = true
					time_since_lost_sight = 0.0
					update_vision_color(true)
					print("Enemy spotted player! Starting chase!")
			
			if player_was_in_cone:
				look_at_player = true
				is_running = true
				is_stopped = false
				is_chasing = true
				last_known_player_position = player.global_position
				
				time_since_path_update += delta
				if time_since_path_update >= chase_update_interval:
					update_chase_path()
					time_since_path_update = 0.0
					
				time_since_lost_sight = 0.0
		else:
			if player_was_in_cone:
				time_since_lost_sight += delta
				if time_since_lost_sight < lose_player_delay:
					look_at_player = true
					is_running = true
					is_stopped = false
					is_chasing = true
				else:
					stop_chasing()
			else:
				if is_chasing:
					stop_chasing()

func update_chase_path():
	if player == null:
		return
		
	# Check distance (using the global calculation)
	if player_distance <= attack_distance:
		print("In attack range!")
		emit_signal("player_caught")
		is_stopped = true
		is_chasing = false
		return
	is_stopped = false

	agent.target_position = player.global_position

func stop_chasing():
	look_at_player = false
	is_running = false
	is_stopped = true
	is_chasing = false
	player_was_in_cone = false
	time_since_lost_sight = 0.0
	update_vision_color(false)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	if is_chasing and not is_stopped and agent and player:
		if agent.is_navigation_finished():
			agent.target_position = player.global_position 
		
		var next_path_position = agent.get_next_path_position()
		var direction = (next_path_position - global_position).normalized()
		var horizontal_direction = Vector3(direction.x, 0, direction.z)
		
		if horizontal_direction.length() < 0.1 or not agent.is_target_reachable():
			# Fallback movement using global positions
			var direct_direction = (player.global_position - global_position)
			direct_direction.y = 0
			horizontal_direction = direct_direction.normalized()
		else:
			horizontal_direction = horizontal_direction.normalized()
		
		var current_speed = run_speed if is_running else walk_speed
		
		velocity.x = horizontal_direction.x * current_speed
		velocity.z = horizontal_direction.z * current_speed
		
	else:
		velocity.x = 0
		velocity.z = 0
	
	move_and_slide()
	if anim_player:
		var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
	
		var walk_anim_name = "walk" 

		if horizontal_speed > 0.1:
			if anim_player.current_animation != walk_anim_name:
				anim_player.play(walk_anim_name, 0.2)
		else:
			if anim_player.is_playing():
				anim_player.stop()
	
	# Rotation Logic (Maintained your preferred orientation)
	if look_at_player and player != null:
		var look_direction = (player.global_position - global_position).normalized()
		look_direction.y = 0
		if look_direction.length() > 0:
			var target_rot = atan2(-look_direction.x, -look_direction.z)
			rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)
	elif velocity.length_squared() > 0.1:
		var target_rot = atan2(-velocity.x, -velocity.z)
		rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)

func _on_navigation_finished():
	if is_chasing and player_was_in_cone and player:
		agent.target_position = player.global_position 

func is_player_in_vision_cone() -> bool:
	if player == null:
		return false

	var direction_to_player = (player.global_position - global_position).normalized()
	direction_to_player.y = 0
	direction_to_player = direction_to_player.normalized()
	
	var forward = -transform.basis.z 
	forward.y = 0
	forward = forward.normalized()
	
	var dot_product = forward.dot(direction_to_player)
	var angle = rad_to_deg(acos(clamp(dot_product, -1.0, 1.0)))
	
	return angle <= vision_angle and player_distance <= vision_range

func _on_body_entered(body):
	if body.is_in_group("Player"):
		player_in_range = true
		print("Player entered vision area")

func _on_body_exited(body):
	if body.is_in_group("Player"):
		player_in_range = false
		print("Player exited vision area")

func create_vision_visual_from_collision():
	vision_visual = MeshInstance3D.new()
	vision_collision.add_child(vision_visual)
	var shape = vision_collision.shape
	if shape is SphereShape3D:
		var sphere_mesh = SphereMesh.new(); sphere_mesh.radius = shape.radius; sphere_mesh.height = shape.radius * 2; vision_visual.mesh = sphere_mesh
	elif shape is BoxShape3D:
		var box_mesh = BoxMesh.new(); box_mesh.size = shape.size; vision_visual.mesh = box_mesh
	elif shape is CylinderShape3D:
		var cylinder_mesh = CylinderMesh.new(); cylinder_mesh.height = shape.height; cylinder_mesh.top_radius = shape.radius; cylinder_mesh.bottom_radius = shape.radius; vision_visual.mesh = cylinder_mesh
	elif shape is CapsuleShape3D:
		var capsule_mesh = CapsuleMesh.new(); capsule_mesh.radius = shape.radius; capsule_mesh.height = shape.height; vision_visual.mesh = capsule_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = vision_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = false
	vision_visual.material_override = material

func update_vision_color(tracking: bool):
	if vision_visual and vision_visual.material_override:
		if tracking:
			vision_visual.material_override.albedo_color = Color(1.0, 1.0, 0.0, 0.1)
		else:
			vision_visual.material_override.albedo_color = Color(1.0, 0.0, 0.0, 0.1)
