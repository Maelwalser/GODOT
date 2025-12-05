extends RigidBody3D

@export var held_position_offset : Vector3 = Vector3.ZERO
@export var held_rotation_offset : Vector3 = Vector3.ZERO
@export var damage : int = 10

var original_parent = null
var is_held = false
var is_swinging = false # Prevents spamming click and physics conflicts

# Reference to the Hitbox. Make sure the path matches your scene tree!
@onready var hitbox = $Hitbox 

func pick_up(new_parent: Node3D):
	if is_held: return
	is_held = true
	original_parent = get_parent()
	
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	collision_layer = 0
	collision_mask = 0
	
	reparent(new_parent, false)
	
	# Connect the hitbox signal via code so we don't forget in the editor
	if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func drop_object():
	if !is_held: return
	is_held = false
	is_swinging = false # Reset swing state
	
	if is_instance_valid(original_parent):
		reparent(original_parent, true)
	else:
		reparent(get_tree().root, true)
	
	collision_layer = 1
	collision_mask = 1
	freeze = false
	apply_central_impulse(-global_transform.basis.z * 5.0)

# LOGIC FOR SWINGING
func action():
	if is_swinging: return
	swing_hammer()

func swing_hammer():
	is_swinging = true
	
	var tween = create_tween()
	
	# 1. THE HEAVY WIND UP (0.8 seconds)
	# We use EASE_OUT to simulate the initial effort of lifting a heavy object against gravity.
	# We also pull it back further (-45 degrees) to sell the weight.
	var wind_up_rot = held_rotation_offset + Vector3(45, 0, 0)
	tween.tween_property(self, "rotation_degrees", wind_up_rot, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 2. THE STRIKE (0.2 seconds)
	# Even heavy hammers fall fast. We use TRANS_EXPO + EASE_IN to simulate
	# acceleration (gravity) pulling it down hard at the end.
	var strike_rot = held_rotation_offset + Vector3(-80, 0, 0)
	tween.tween_property(self, "rotation_degrees", strike_rot, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	tween.parallel().tween_callback(apply_impact_shake).set_delay(0.2)

	# 3. IMPACT PAUSE (0.1 seconds)
	# This adds "weight" by making the hammer feel like it stuck into the ground/target 
	# for a split second before you can lift it again.
	tween.tween_interval(0.1)
	
	# 4. THE LONG RECOVERY (1.2 seconds)
	# It takes a long time to pull the hammer back to the idle position.
	# TRANS_BOUNCE gives it a little heavy wobble as it settles.
	tween.tween_property(self, "rotation_degrees", held_rotation_offset, 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# Unlock the hammer only after the long recovery is done
	tween.finished.connect(func(): is_swinging = false)

func apply_impact_shake():
	# Access the camera (The grandparent of the hammer: Hammer -> Hand -> Camera)
	var camera = get_parent().get_parent() 
	if camera is Camera3D:
		var shake_tween = create_tween()
		# Quickly jerk the camera down and back up
		shake_tween.tween_property(camera, "v_offset", -0.1, 0.05)
		shake_tween.tween_property(camera, "v_offset", 0.0, 0.1)

# LOGIC FOR HITTING
func _on_hitbox_body_entered(body):
	# Only deal damage if we are currently swinging and holding the object
	if is_held and is_swinging:
		if body.has_method("take_damage"):
			body.take_damage(damage)
			print("Hit " + body.name)
			
			# Optional: Add a small impact shake or sound here

func _physics_process(_delta):
	# CRITICAL CHANGE: Only lock position/rotation if NOT swinging
	if is_held and not is_swinging:
		position = held_position_offset
		rotation_degrees = held_rotation_offset
