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
	
	# create_tween() lets us animate properties over time
	var tween = create_tween()
	
	# 1. Wind up (pull back slightly)
	# We rotate relative to the current rotation offset
	var wind_up_rot = held_rotation_offset + Vector3(80, 0, 0)
	tween.tween_property(self, "rotation_degrees", wind_up_rot, 0.15)
	
	# 2. The Strike (swing forward hard)
	var strike_rot = held_rotation_offset + Vector3(-90, 0, 0)
	tween.tween_property(self, "rotation_degrees", strike_rot, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	# 3. Recovery (return to held position)
	tween.tween_property(self, "rotation_degrees", held_rotation_offset, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# When the animation finishes, allow swinging again
	tween.finished.connect(func(): is_swinging = false)

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
