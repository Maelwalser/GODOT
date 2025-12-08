# ProtoController v1.0 by Brackeys
# CC0 License
# Intended for rapid prototyping of first-person games.
# Happy prototyping!

extends CharacterBody3D

## Was player in air previously?
@export var was_on_floor : bool = false
##Was player on the ground previously?
@export var was_in_air : bool = false
##evaluating players endurance
@export var max_endurance : float = 6
@export var endurance_drain_rate : float = 2.0  
@export var endurance_recovery_rate : float = 1.0  
@export var min_endurance_to_sprint : float = 1.0
@export var sprint_cooldown_duration : float = 2.5  # NEW: Duration of cooldown in seconds

## Can we move around?
@export var can_move : bool = true
## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we press to jump?
@export var can_jump : bool = true
## Can we hold to run?
@export var can_sprint : bool = true
## Can we press to enter freefly mode (noclip)?
@export var can_freefly : bool = false

@export_group("Speeds")
## Look around rotation speed.
@export var look_speed : float = 0.002
## Normal speed.
@export var base_speed : float = 5.0
## Speed of jump.
@export var jump_velocity : float = 5.5
## How fast do we run?
@export var sprint_speed : float = 14.0
## How fast do we freefly?
@export var freefly_speed : float = 25.0

@export_group("Input Actions")
## Name of Input Action to move Left.
@export var input_left : String = "ui_left"
## Name of Input Action to move Right.
@export var input_right : String = "ui_right"
## Name of Input Action to move Forward.
@export var input_forward : String = "ui_up"
## Name of Input Action to move Backward.
@export var input_back : String = "ui_down"
## Name of Input Action to Jump.
@export var input_jump : String = "ui_accept"
## Name of Input Action to Sprint.
@export var input_sprint : String = "sprint"
## Name of Input Action to toggle freefly mode.
@export var input_freefly : String = "freefly"
## Name of the input for attacking
@export var input_attack : String = "attack"


@onready var knuckles_label = $CanvasGroup/Label

var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false
var current_endurance : float = 10.0
var is_out_of_breath : bool = false
var sprint_cooldown_timer : float = 0.0  # NEW: Tracks cooldown time remaining
var is_in_sprint_cooldown : bool = false  # NEW: Whether we're in cooldown

## IMPORTANT REFERENCES
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider
@onready var footstep_player: AudioStreamPlayer3D = $FootstepPlayer
@onready var jump_landing_player: AudioStreamPlayer3D = $JumpLandingPlayer
@onready var attack_area = $TempAttack
@onready var breathing_player: AudioStreamPlayer3D = $BreathingPlayer

func _input(event):
	if event.is_action_pressed("attack"):
		attack()
		
func attack():
	for body in attack_area.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(1)

func _ready() -> void:
	check_input_mappings()
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
	
	current_endurance = max_endurance
	
	# Setup label position and style
	if knuckles_label:
		knuckles_label.position = Vector2(10, 10)  # Top left corner
		knuckles_label.add_theme_font_size_override("font_size", 32)

func _unhandled_input(event: InputEvent) -> void:
	# Mouse capturing
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
	
	# Look around
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)
	
	# Toggle freefly mode
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()

func _physics_process(delta: float) -> void:
	# If freeflying, handle freefly and nothing else
	if can_freefly and freeflying:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var motion := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return
	
	# NEW: Handle sprint cooldown timer
	if is_in_sprint_cooldown:
		sprint_cooldown_timer -= delta
		if sprint_cooldown_timer <= 0:
			is_in_sprint_cooldown = false
			sprint_cooldown_timer = 0
			print("Sprint cooldown ended!")  # DEBUG
	
	# Apply gravity to velocity
	if has_gravity:
		if not is_on_floor():
			velocity += get_gravity() * delta
		if is_on_floor():
			was_in_air = false 
		else:
			was_in_air = true  

	# Apply jumping
	if can_jump:
		if Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = jump_velocity
			
	var is_trying_to_sprint = can_sprint and Input.is_action_pressed(input_sprint)
	var is_moving = Input.get_vector(input_left, input_right, input_forward, input_back).length() > 0		
	# MODIFIED: Check if we're not in cooldown as well
	var can_actually_sprint = is_trying_to_sprint and current_endurance > 0 and is_moving and not is_in_sprint_cooldown
	
	if can_actually_sprint:
		move_speed = sprint_speed
		current_endurance -= endurance_drain_rate * delta
		
		# NEW: When endurance hits 0, trigger cooldown IMMEDIATELY
		if current_endurance <= 0:
			current_endurance = 0
			if not is_in_sprint_cooldown:  # Only trigger once
				is_out_of_breath = true
				is_in_sprint_cooldown = true
				sprint_cooldown_timer = sprint_cooldown_duration
				print("OUT OF BREATH! Sprint locked for ", sprint_cooldown_duration, " seconds!")  # DEBUG
				if breathing_player:
					print("Breathing player exists, attempting to play...")  # DEBUG
					breathing_player.play()
				else:
					print("ERROR: breathing_player is NULL!")  # DEBUG
	else:
		move_speed = base_speed
		# MODIFIED: Only recover endurance if NOT in cooldown
		if not is_in_sprint_cooldown:
			current_endurance += endurance_recovery_rate * delta
			current_endurance = min(max_endurance, current_endurance)
			
			# Only stop breathing sound when fully recovered
			if is_out_of_breath and current_endurance >= max_endurance * 0.5:
				is_out_of_breath = false
				if breathing_player and breathing_player.playing:
					breathing_player.stop()
	
	# Apply desired movement to velocity
	if can_move:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if move_dir:
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
	else:
		velocity.x = 0
		velocity.y = 0
	
	# Use velocity to actually move
	move_and_slide()
	
	if was_in_air and is_on_floor():
		jump_landing_player.play()
	
	if is_moving and is_on_floor():
		if not footstep_player.playing:
			footstep_player.play()
			
	else:
		if footstep_player.playing:
			footstep_player.stop()
		
## Rotate us to look around.
## Base of controller rotates around y (left/right). Head rotates around x (up/down).
## Modifies look_rotation based on rot_input, then resets basis and rotates by look_rotation.
func rotate_look(rot_input : Vector2):
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)


func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func disable_freefly():
	collider.disabled = false
	freeflying = false


func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false


func _process(delta):
	# Update label text every frame with global counter
	if knuckles_label:
		var base_text = "Knuckles: " + str(GameManager.knuckles) + "/9"
		# NEW: Show cooldown status in UI
		if is_in_sprint_cooldown:
			base_text += "\n[EXHAUSTED: " + str(ceil(sprint_cooldown_timer)) + "s]"
		knuckles_label.text = base_text

## Checks if some Input Actions haven't been created.
## Disables functionality accordingly.
func check_input_mappings():
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if can_move and not InputMap.has_action(input_forward):
		push_error("Movement disabled. No InputAction found for input_forward: " + input_forward)
		can_move = false
	if can_move and not InputMap.has_action(input_back):
		push_error("Movement disabled. No InputAction found for input_back: " + input_back)
		can_move = false
	if can_jump and not InputMap.has_action(input_jump):
		push_error("Jumping disabled. No InputAction found for input_jump: " + input_jump)
		can_jump = false
	if can_sprint and not InputMap.has_action(input_sprint):
		push_error("Sprinting disabled. No InputAction found for input_sprint: " + input_sprint)
		can_sprint = false
	if can_freefly and not InputMap.has_action(input_freefly):
		push_error("Freefly disabled. No InputAction found for input_freefly: " + input_freefly)
		can_freefly = false
