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
	enemy.health_component.max_health = 100.0
	enemy.health_component.current_health = 100.0

	if not enemy.attribute_component:
		errors.append("enemy did not create AttributeStatusComponent")
	if not enemy.get_node_or_null("EnemyStatusView"):
		errors.append("enemy did not create EnemyStatusView")

	var status_component := enemy.attribute_component
	var health_before := enemy.health_component.current_health
	enemy.apply_attribute_payload({"fire": 1}, 10.0)
	if not status_component.statuses.has("fire"):
		errors.append("fire status was not attached")
	await get_tree().create_timer(1.1).timeout
	if enemy.health_component.current_health >= health_before:
		errors.append("fire status did not tick damage")

	enemy.apply_attribute_payload({"ice": 1}, 10.0)
	if status_component.frozen_time <= 0.0:
		errors.append("fire + ice reaction did not freeze target")
	if not is_zero_approx(status_component.get_speed_multiplier()):
		errors.append("frozen target did not stop movement")

	status_component.frozen_time = 0.0
	status_component.statuses.clear()
	enemy.apply_attribute_payload({"vine": 1}, 1.0)
	enemy.apply_attribute_payload({"vine": 1}, 1.0)
	enemy.apply_attribute_payload({"vine": 1}, 1.0)
	if status_component.stunned_time <= 0.0:
		errors.append("max vine stacks did not bind target")

	enemy.queue_free()
	await get_tree().process_frame
	var boss_scene: PackedScene = load("res://scenes/entities/bosses/boss_red_crack.tscn")
	var boss: BossRedCrack = boss_scene.instantiate() as BossRedCrack
	add_child(boss)
	await get_tree().process_frame
	await get_tree().process_frame
	if not boss.attribute_component:
		errors.append("boss did not create AttributeStatusComponent")
	if not boss.get_node_or_null("BossStatusView"):
		errors.append("boss did not create BossStatusView")
	boss.queue_free()
	await get_tree().process_frame
	game_manager.reset_game()
	if errors.is_empty():
		print("Negative status validation passed: burn, reaction freeze, vine bind, and target status view")
		get_tree().quit(0)
		return

	for error in errors:
		push_error(error)
	get_tree().quit(1)
