extends CanvasLayer

@onready var panel : Control = $Panel
@onready var restart_button : Button = $Panel/VBoxContainer/RestartButton
@onready var menu_button : Button = $Panel/VBoxContainer/MenuButton
@onready var quit_button : Button = $Panel/VBoxContainer/QuitButton

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func show_game_over():
	panel.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func hide_game_over():
	panel.visible = false

func _on_restart_pressed():
	hide_game_over()
	GameManager.restart_game()

func _on_menu_pressed():
	hide_game_over()
	GameManager.go_to_main_menu()

func _on_quit_pressed():
	get_tree().quit()
