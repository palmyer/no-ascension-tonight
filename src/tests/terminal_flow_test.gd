extends Node2D

const BOSS_SCENE = preload("res://scenes/entities/bosses/boss_red_crack.tscn")

var game_over_count: int = 0
var run_completed_count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run_checks")

func _on_game_over() -> void:
	game_over_count += 1

func _on_run_completed(_final_wave: int) -> void:
	run_completed_count += 1

func _run_checks() -> void:
	var game_manager: GameManager = get_node_or_null("/root/GameManager") as GameManager
	var wave_manager: Node = get_node_or_null("/root/WaveManager")
	var event_bus: Node = get_node_or_null("/root/EventBus")
	var errors: Array[String] = []
	if not game_manager or not wave_manager or not event_bus:
		push_error("terminal flow autoloads are unavailable")
		get_tree().quit(1)
		return
	event_bus.game_over.connect(_on_game_over)
	event_bus.run_completed.connect(_on_run_completed)

	var level: Node = null

	# Player death must stop the run before the player is removed from the tree.
	game_manager.start_new_run()
	level = load("res://scenes/levels/first_level.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("Player") as Player
	if not player or not player.health_component:
		errors.append("player death fixture did not create a valid health component")
	else:
		game_over_count = 0
		player.take_damage(99999.0)
		await get_tree().process_frame
		if game_manager.game_started or game_manager.run_end_reason != "player_died":
			errors.append("player death did not close the run")
		if game_over_count != 1:
			errors.append("player death emitted %d game-over events" % game_over_count)
	level.queue_free()
	await get_tree().process_frame
	get_tree().paused = false

	# Core destruction is a separate loss route and must not be confused with
	# player death even though both show the same terminal UI.
	game_manager.start_new_run()
	level = load("res://scenes/levels/first_level.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var core := get_tree().get_first_node_in_group("LifeCore") as LifeCore
	if not core:
		errors.append("core destruction fixture did not create the life core")
	else:
		game_over_count = 0
		core.receive_damage(99999.0)
		await get_tree().process_frame
		if game_manager.game_started or game_manager.run_end_reason != "core_destroyed":
			errors.append("core destruction did not close the run")
		if game_over_count != 1:
			errors.append("core destruction emitted %d game-over events" % game_over_count)
	level.queue_free()
	await get_tree().process_frame
	get_tree().paused = false

	# The final boss route must resolve through boss_defeated and complete_run.
	game_manager.start_new_run()
	game_manager.current_wave = wave_manager.MAX_WAVES
	game_manager.current_state = game_manager.GameState.NIGHT
	level = load("res://scenes/levels/first_level.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var final_boss: BossRedCrack = BOSS_SCENE.instantiate() as BossRedCrack
	final_boss.configure_boss("AscensionKing", {"display_name": "Test King", "health": 50.0, "speed": 0.0, "contact_damage": 1.0, "dash_damage": 1.0, "charge_cooldown": 99.0, "charge_aim_time": 1.0, "ability_cooldown": 99.0})
	level.get_node("Gameplay").add_child(final_boss)
	await get_tree().process_frame
	run_completed_count = 0
	final_boss.take_damage(999.0)
	await get_tree().process_frame
	if not game_manager.run_won or game_manager.game_started or game_manager.run_end_reason != "ascension_complete":
		errors.append("final boss defeat did not complete the run")
	if run_completed_count != 1:
		errors.append("final boss defeat emitted %d completion events" % run_completed_count)
	wave_manager.complete_run()
	if run_completed_count != 1:
		errors.append("completion was not idempotent after final boss defeat")
	level.queue_free()
	await get_tree().process_frame
	get_tree().paused = false

	# The time-out route must also be a valid win and share the same idempotent
	# terminal state without requiring a boss node to be present.
	game_manager.start_new_run()
	game_manager.current_wave = wave_manager.MAX_WAVES
	game_manager.current_state = game_manager.GameState.NIGHT
	wave_manager.time_left = 0.0
	run_completed_count = 0
	wave_manager._on_timer_finished()
	wave_manager._on_timer_finished()
	if not game_manager.run_won or game_manager.game_started or game_manager.run_end_reason != "ascension_complete":
		errors.append("final-wave timeout did not complete the run")
	if run_completed_count != 1:
		errors.append("final-wave timeout emitted %d completion events" % run_completed_count)

	event_bus.game_over.disconnect(_on_game_over)
	event_bus.run_completed.disconnect(_on_run_completed)
	get_tree().paused = false
	game_manager.reset_game()
	wave_manager.reset_manager()
	if errors.is_empty():
		print("Terminal flow validation passed: player death, core loss, boss win, timeout win")
		get_tree().quit(0)
		return

	for error in errors:
		push_error(error)
	get_tree().quit(1)
