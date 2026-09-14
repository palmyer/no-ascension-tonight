extends Node

var completed_count: int = 0

func _on_run_completed(_final_wave: int) -> void:
	completed_count += 1

func _init() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	var wave_manager: Node = get_node_or_null("/root/WaveManager")
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if not game_manager or not wave_manager or not event_bus:
		push_error("game flow autoloads are unavailable")
		get_tree().quit(1)
		return

	var errors: Array[String] = []
	event_bus.run_completed.connect(_on_run_completed)

	game_manager.select_starting_weapon("sword")
	game_manager.start_new_run()
	for wave in range(1, wave_manager.MAX_WAVES + 1):
		if int(game_manager.current_wave) != wave:
			errors.append("flow entered unexpected wave %d" % int(game_manager.current_wave))
		if game_manager.current_state != game_manager.GameState.DAY:
			errors.append("wave %d did not start in day state" % wave)

		wave_manager.start_night()
		if game_manager.current_state != game_manager.GameState.NIGHT:
			errors.append("wave %d did not enter night state" % wave)
		if wave_manager.get_spawn_budget(true) <= 0:
			errors.append("wave %d night budget is empty" % wave)

		if wave < wave_manager.MAX_WAVES:
			wave_manager.start_next_wave()
			if int(game_manager.current_wave) != wave + 1:
				errors.append("flow did not advance after wave %d" % wave)
			if game_manager.current_state != game_manager.GameState.DAY:
				errors.append("wave %d did not return to day state" % (wave + 1))

	wave_manager.complete_run()
	wave_manager.complete_run()
	if not wave_manager.run_completed_flag:
		errors.append("complete_run did not set terminal flag")
	if game_manager.game_started:
		errors.append("completed run remained active")
	if not game_manager.run_won:
		errors.append("completed run did not set win state")
	if completed_count != 1:
		errors.append("completed run emitted %d completion events" % completed_count)
	if str(game_manager.run_end_reason) != "ascension_complete":
		errors.append("completed run end reason mismatch")

	event_bus.run_completed.disconnect(_on_run_completed)
	game_manager.reset_game()
	if errors.is_empty():
		print("Wave flow validation passed: 20 day/night transitions and idempotent completion")
		get_tree().quit(0)
		return

	for error in errors:
		push_error(error)
	get_tree().quit(1)
