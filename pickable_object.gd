extends RigidBody3D

var original_parent = null
var is_held = false

@export var held_position_offset : Vector3 = Vector3.ZERO
@export var held_rotation_offset : Vector3 = Vector3.ZERO

func pick_up(new_parent: Node3D):
	if is_held: return
	
	is_held = true
	original_parent = get_parent()
	
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	
	collision_layer = 0
	collision_mask = 0

	reparent(new_parent, false)
	
	# APPLY THE OFFSET HERE
	position = held_position_offset
	rotation_degrees = held_rotation_offset

func drop_object():
	if !is_held: return
	
	is_held = false
	
	if is_instance_valid(original_parent):
		reparent(original_parent, true)
	else:
		reparent(get_tree().root, true)
	
	collision_layer = 1
	collision_mask = 1
	freeze = false
	
	apply_central_impulse(-global_transform.basis.z * 5.0)

func _physics_process(_delta):
	if is_held:
		position = held_position_offset
		rotation_degrees = held_rotation_offset
