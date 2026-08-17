extends CanvasLayer

@onready var panel = $Panel
@onready var restart_button = $Panel/VBoxContainer/RestartButton
@onready var message_label = $Panel/VBoxContainer/MessageLabel

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS # 确保在暂停时也能工作
	EventBus.game_over.connect(_on_game_over)
	restart_button.pressed.connect(_on_restart_pressed)

func _on_game_over():
	visible = true
	get_tree().paused = true

func _on_restart_pressed():
	get_tree().paused = false
	GameManager.reset_game()
	WaveManager.reset_manager()
	get_tree().reload_current_scene()
