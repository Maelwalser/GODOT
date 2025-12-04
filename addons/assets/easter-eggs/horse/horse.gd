extends Node3D

@onready var animation_player = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready():
	if animation_player:
		# Получаем список всех анимаций
		var animation_names = animation_player.get_animation_list()
		
		if animation_names.size() > 0:
			# Проигрываем первую анимацию
			animation_player.play(animation_names[0])
			
			# Выводим имя анимации в консоль для справки
			print("Playing anim: ", animation_names[0])
		else:
			print("Anim horse not found")
	else:
		print("AnimationPlayer not found")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
