# destructible_object.gd
extends RigidBody3D
class_name DestructibleObject

# Export variables for easy customization per object type
@export var object_type: String = "generic" 
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
	
	if particles:
		
		particles.amount = particle_count
		
		if particles.process_material:
			
			particles.process_material = particles.process_material.duplicate(true)  
			
			particles.process_material.color = particle_color
			
func take_damage(_amount: int = 1):
	if is_destroyed:
		return
	
	destroy()

func destroy():
	
	var ais = get_tree().get_nodes_in_group("AI")  
	for ai in ais:
		if ai.has_method("hear_noise"):
			ai.hear_noise(global_position)
	
	if is_destroyed:
		return
	
	is_destroyed = true
	collision_shape.disabled = true
	
	DestructionManager.add_destruction()
	
	if particles:
		particles.emitting = true

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
