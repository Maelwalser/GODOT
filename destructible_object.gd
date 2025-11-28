# destructible_object.gd
extends RigidBody3D
class_name DestructibleObject

# Export variables for easy customization per object type
@export var object_type: String = "generic"  # "mug", "glass", "tv", etc.
@export var destruction_sound: AudioStream
@export var particle_color: Color = Color.WHITE
@export var particle_count: int = 30

@onready var audio_player = $AudioStreamPlayer3D
@onready var model = $Model
@onready var collision_shape = $CollisionShape3D
@onready var particles = $GPUParticles3D

var is_destroyed: bool = false

func _ready():
	collision_layer = 2
	collision_mask = 1
	
	print("====== READY DEBUG ======")
	print("Object type: ", object_type)
	print("particle_color value: ", particle_color)
	print("particle_count value: ", particle_count)
	
	if particles:
		print("Particles exists!")
		print("Process material before: ", particles.process_material)
		
		# Set amount first
		particles.amount = particle_count
		
		# Now handle the material
		if particles.process_material:
			print("Original material color: ", particles.process_material.color)
			
			# Duplicate it
			particles.process_material = particles.process_material.duplicate(true)  # true = deep copy
			
			print("After duplicate, material is: ", particles.process_material)
			print("After duplicate, color is: ", particles.process_material.color)
			
			# Set the color
			particles.process_material.color = particle_color
			
			print("After setting color: ", particles.process_material.color)
			print("particle_color we tried to set: ", particle_color)

func take_damage(_amount: int = 1):
	if is_destroyed:
		return
	
	destroy()

func destroy():
	if is_destroyed:
		return
	
	is_destroyed = true
	collision_shape.disabled = true
	
	# DEBUG: Check particle setup
	print("=== PARTICLE DEBUG ===")
	print("Particles node exists? ", particles != null)
	if particles:
		print("Particles emitting before: ", particles.emitting)
		print("Particles amount: ", particles.amount)
		print("Particles lifetime: ", particles.lifetime)
		print("Particles one_shot: ", particles.one_shot)
		print("Particles explosiveness: ", particles.explosiveness)
		print("Particles visibility: ", particles.visible)
		print("Particles process_material: ", particles.process_material)
		if particles.process_material:
			print("Material color: ", particles.process_material.color)
		print("Particles global_position: ", particles.global_position)
	
	# Trigger particle effect
	if particles:
		particles.emitting = true
		print("Particles emitting after: ", particles.emitting)
	
	# Play destruction sound
	if destruction_sound and audio_player:
		audio_player.stream = destruction_sound
		audio_player.play()
	
	# Visual destruction effect
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(model, "scale", Vector3.ZERO, 0.3)
	tween.tween_property(model, "rotation", Vector3(randf() * 2, randf() * 2, randf() * 2), 0.3)
	
	await get_tree().create_timer(1.0).timeout
	queue_free()
