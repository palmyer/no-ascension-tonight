extends Node

# 波次管理器：控制昼夜循环

signal state_changed(new_state: GameManager.GameState)
signal wave_finished(wave_num: int)

@export var day_duration: float = 60.0
@export var night_duration: float = 60.0

var time_left: float = 0.0

func _ready():
	start_day()

func _process(delta: float):
	time_left -= delta
	if time_left <= 0:
		_on_timer_finished()

func _on_timer_finished():
	match GameManager.current_state:
		GameManager.GameState.DAY:
			start_night()
		GameManager.GameState.NIGHT:
			show_attunement_selection()

func start_day():
	GameManager.current_state = GameManager.GameState.DAY
	time_left = day_duration
	GameManager.update_current_stats()
	state_changed.emit(GameManager.current_state)
	print("[DEBUG] Day Started")

func start_night():
	GameManager.current_state = GameManager.GameState.NIGHT
	time_left = night_duration
	GameManager.update_current_stats()
	state_changed.emit(GameManager.current_state)
	print("[DEBUG] Night Started")

func show_attunement_selection():
	get_tree().paused = true
	EventBus.emit_signal("show_attunement_wheel")
	print("[DEBUG] Night ended, showing Attunement Wheel...")

func start_next_wave():
	wave_finished.emit(GameManager.current_wave)
	GameManager.current_wave += 1
	get_tree().paused = false
	start_day()

func reset_manager():
	time_left = day_duration
	print("[DEBUG] Wave Manager Reset")
