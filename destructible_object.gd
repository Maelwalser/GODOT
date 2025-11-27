# destructible_object.gd
extends RigidBody3D
class_name DestructibleObject

# Export variables for easy customization per object type
@export var object_type: String = "generic"  # "mug", "glass", "tv", etc.
@export var destruction_sound: AudioStream

@onready var audio_player = $AudioStreamPlayer3D
@onready var model = $Model
@onready var collision_shape = $CollisionShape3D

var is_destroyed: bool = false

func _ready():
	# Set up collision layer/mask as needed
	collision_layer = 2  # Object layer
	collision_mask = 1   # Can collide with player/world

func take_damage(_amount: int = 1):
	if is_destroyed:
		return
	
	destroy()

func destroy():
	if is_destroyed:
		return
	
	is_destroyed = true
	
	# Disable collision
	collision_shape.disabled = true
	
	# Debug: Check sound and audio player
	print("DEBUG: destruction_sound is null? ", destruction_sound == null)
	print("DEBUG: audio_player is null? ", audio_player == null)
	if destruction_sound:
		print("DEBUG: destruction_sound path: ", destruction_sound.resource_path)
	if audio_player:
		print("DEBUG: audio_player exists, stream before assignment: ", audio_player.stream)
	
	# Play destruction sound
	if destruction_sound and audio_player:
		audio_player.stream = destruction_sound
		audio_player.play()
		print("DEBUG: Sound should be playing now!")
	else:
		print("DEBUG: Sound NOT played - condition failed!")
	
	# Simple destruction effect - shrink and spin
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(model, "scale", Vector3.ZERO, 0.3)
	tween.tween_property(model, "rotation", Vector3(randf() * 2, randf() * 2, randf() * 2), 0.3)
	
	# Wait for animation/sound to finish before removing
	await get_tree().create_timer(0.5).timeout
	
	queue_free()
