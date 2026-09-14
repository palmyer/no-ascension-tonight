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
	var level: Node = load("res://scenes/levels/first_level.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var gameplay: Node = level.get_node("Gameplay")
	var player: Player = get_tree().get_first_node_in_group("Player") as Player
	if not player:
		errors.append("player was not instantiated")
	else:
		var enemy_scene: PackedScene = load("res://scenes/entities/enemies/enemy.tscn")
		var enemy: Enemy = enemy_scene.instantiate() as Enemy
		enemy.enemy_type = Enemy.EnemyType.HEAVY
		gameplay.add_child(enemy)
		await get_tree().process_frame
		enemy.health_component.max_health = 10000.0
		enemy.health_component.current_health = 10000.0
		enemy.global_position = player.global_position
		await get_tree().process_frame
		var health_before := player.health_component.current_health
		await get_tree().create_timer(0.1).timeout
		if player.health_component.current_health >= health_before:
			errors.append("melee enemy did not damage player")
		enemy.queue_free()

		var boss_scene: PackedScene = load("res://scenes/entities/bosses/boss_red_crack.tscn")
		var boss: BossRedCrack = boss_scene.instantiate() as BossRedCrack
		boss.configure_boss("RedCrack", {"display_name": "Test Boss", "health": 10000.0, "speed": 0.0, "contact_damage": 12.0, "dash_damage": 20.0, "charge_cooldown": 99.0, "charge_aim_time": 1.8, "ability_cooldown": 99.0})
		gameplay.add_child(boss)
		await get_tree().process_frame
		boss.global_position = player.global_position
		await get_tree().process_frame
		health_before = player.health_component.current_health
		await get_tree().create_timer(0.1).timeout
		if player.health_component.current_health >= health_before:
			errors.append("boss contact damage did not reach player")
		boss.queue_free()

	await get_tree().process_frame
	game_manager.reset_game()
	if errors.is_empty():
		print("Enemy damage validation passed: melee and boss contact damage reach player health")
		get_tree().quit(0)
		return

	for error in errors:
		push_error(error)
	get_tree().quit(1)
