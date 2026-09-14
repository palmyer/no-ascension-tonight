extends Node2D

func _ready() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if not game_manager:
		push_error("GameManager autoload is unavailable")
		get_tree().quit(1)
		return

	var errors: Array[String] = []
	game_manager.start_new_run()
	var enemy_scene: PackedScene = load("res://scenes/entities/enemies/enemy.tscn")
	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	add_child(enemy)
	await get_tree().process_frame
	await get_tree().process_frame
	enemy.health_component.max_health = 10000.0
	enemy.health_component.current_health = 10000.0

	var status_component := enemy.attribute_component
	var reaction_count := 0
	for reaction_key in game_manager.ATTRIBUTE_REACTIONS:
		var parts := str(reaction_key).split("|")
		if parts.size() != 2:
			errors.append("malformed reaction key: %s" % reaction_key)
			continue
		var reaction: Dictionary = game_manager.get_attribute_reaction(parts[0], parts[1])
		var reaction_id := str(reaction.get("id", ""))
		if reaction_id.is_empty():
			errors.append("reaction lookup failed: %s" % reaction_key)
			continue

		status_component.statuses.clear()
		status_component.reaction_cooldowns.clear()
		status_component.frozen_time = 0.0
		status_component.stunned_time = 0.0
		enemy.health_component.current_health = enemy.health_component.max_health
		var health_before := enemy.health_component.current_health
		enemy.apply_attribute_payload({parts[0]: 1}, 10.0)
		enemy.apply_attribute_payload({parts[1]: 1}, 10.0)
		if not status_component.reaction_cooldowns.has(reaction_id):
			errors.append("reaction did not trigger: %s" % reaction_key)
		if enemy.health_component.current_health >= health_before:
			errors.append("reaction did not deal damage: %s" % reaction_key)
		reaction_count += 1

	if not enemy.get_node_or_null("EnemyStatusView"):
		errors.append("enemy status view missing during reaction coverage")
	enemy.queue_free()
	await get_tree().process_frame
	game_manager.reset_game()
	if errors.is_empty():
		print("Attribute status validation passed: %d reactions and target control effects" % reaction_count)
		get_tree().quit(0)
		return

	for error in errors:
		push_error(error)
	get_tree().quit(1)
