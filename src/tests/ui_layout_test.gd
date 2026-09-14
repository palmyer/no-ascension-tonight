extends Node

func _ready() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var errors: Array[String] = []
	var game_manager := get_tree().root.get_node_or_null("GameManager")
	if not game_manager:
		push_error("game manager is unavailable")
		get_tree().quit(1)
		return
	game_manager.start_new_run()
	var level: Node = load("res://scenes/levels/first_level.tscn").instantiate()
	get_tree().root.add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var hud: GameHud = null
	var gameplay := level.get_node_or_null("Gameplay")
	if not gameplay:
		errors.append("gameplay root was not created")
	for child in gameplay.get_children() if gameplay else []:
		if child is GameHud:
			hud = child as GameHud
			break
	if not hud:
		errors.append("gameplay HUD was not created")
	else:
		for property_name in ["phase_label", "attune_label", "weapon_label", "core_bar", "hp_bar", "xp_bar", "special_bar", "special_hint", "boss_panel"]:
			if hud.get(property_name) == null:
				errors.append("HUD missing %s" % property_name)
		var build_panel := level.find_child("RunBuildPanel", true, false)
		if not build_panel:
			errors.append("run build panel was not created")
		var status_panel := level.find_child("CombatStatusPanel", true, false)
		if not status_panel:
			errors.append("combat status panel was not created")
		var shell := level.find_child("CardShell", true, false) as PanelContainer
		if not shell:
			errors.append("level-up shell was not created")
		elif shell.size != Vector2(1240, 720):
			errors.append("level-up shell does not use the responsive safe size")

	if errors.is_empty():
		print("UI layout validation passed: combat hierarchy, readiness panels, build panel, and level-up safe size")
		game_manager.reset_game()
		level.queue_free()
		get_tree().quit(0)
		return

	for error in errors:
		push_error(error)
	game_manager.reset_game()
	get_tree().quit(1)
