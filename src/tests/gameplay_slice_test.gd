extends SceneTree

func _init() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var errors: Array[String] = []
	var game_manager: Node = get_root().get_node_or_null("GameManager")
	var wave_manager: Node = get_root().get_node_or_null("WaveManager")
	if not game_manager or not wave_manager:
		push_error("game autoloads are unavailable")
		quit(1)
		return
	game_manager.start_new_run()

	var level: Node = load("res://scenes/levels/first_level.tscn").instantiate()
	get_root().add_child(level)
	await process_frame
	await process_frame

	var player: Node = get_first_node_in_group("Player")
	var core: Node = get_first_node_in_group("LifeCore")
	if not player:
		errors.append("player was not instantiated")
	if not core:
		errors.append("life core was not instantiated")

	if player and player.has_method("try_special"):
		player.try_special()
		if float(player.get_special_cooldown_remaining()) <= 0.0:
			errors.append("special did not enter cooldown")

	if core:
		var before := float(core.integrity)
		core.receive_damage(10.0)
		if not is_equal_approx(float(core.integrity), before - 10.0):
			errors.append("core damage was not applied")
		game_manager.apply_intermission_event("ward")
		wave_manager.start_night()
		var warded_integrity := float(core.integrity)
		core.receive_damage(1000.0)
		if not is_equal_approx(float(core.integrity), warded_integrity):
			errors.append("core ward did not block damage")

	game_manager.level_up()
	await process_frame
	var level_up_ui := level.get_node_or_null("Gameplay/LevelUpUI")
	if not level_up_ui or not level_up_ui.visible:
		errors.append("level-up card UI did not open")
	else:
		var card_container := level_up_ui.get_node_or_null("Control/HBoxContainer")
		if not card_container or card_container.get_child_count() != 3:
			errors.append("level-up card UI did not create three cards")
	paused = false

	if errors.is_empty():
		print("Gameplay slice validation passed")
		game_manager.reset_game()
		quit(0)
		return

	for error in errors:
		push_error(error)
	game_manager.reset_game()
	quit(1)
