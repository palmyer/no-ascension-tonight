extends Node2D

const ENEMY_SCENE = preload("res://scenes/entities/enemies/enemy.tscn")
const BOSS_SCENE = preload("res://scenes/entities/bosses/boss_red_crack.tscn")
const ENEMY_TYPES := [
	Enemy.EnemyType.MELEE,
	Enemy.EnemyType.ARROW,
	Enemy.EnemyType.MAGIC,
	Enemy.EnemyType.HEAL,
	Enemy.EnemyType.HEAVY,
	Enemy.EnemyType.ASSASSIN
]
const BOSS_EXPECTATIONS := [
	{"id": "RedCrack", "wave": 7},
	{"id": "GreenPlague", "wave": 10},
	{"id": "BlueArc", "wave": 13},
	{"id": "YellowSand", "wave": 16},
	{"id": "AscensionKing", "wave": 20}
]

func _ready() -> void:
	call_deferred("_run_checks")

func _count_runtime_hazards() -> int:
	var count := 0
	for child in get_children():
		if child is HazardZone:
			count += 1
	return count

func _count_runtime_bullets() -> int:
	var count := 0
	for child in get_tree().root.get_children():
		if child is Bullet:
			count += 1
	return count

func _run_checks() -> void:
	var game_manager: GameManager = get_node_or_null("/root/GameManager") as GameManager
	var wave_manager: Node = get_node_or_null("/root/WaveManager")
	var errors: Array[String] = []
	if not game_manager or not wave_manager:
		push_error("content coverage autoloads are unavailable")
		get_tree().quit(1)
		return

	game_manager.select_starting_weapon("sword")
	game_manager.start_new_run()
	var level: Node = load("res://scenes/levels/first_level.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var gameplay: Node = level.get_node("Gameplay")
	var spawner: Node = gameplay.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.process_mode = Node.PROCESS_MODE_DISABLED
	var player := get_tree().get_first_node_in_group("Player") as Player
	if not player:
		errors.append("content coverage player was not instantiated")

	for index in range(ENEMY_TYPES.size()):
		var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
		enemy.enemy_type = ENEMY_TYPES[index]
		enemy.position = Vector2(-420.0 + index * 170.0, -260.0)
		gameplay.add_child(enemy)
		await get_tree().process_frame
		enemy.set_physics_process(false)
		enemy.health_component.max_health = 10000.0
		enemy.health_component.current_health = 10000.0
		if enemy.attribute_component == null:
			errors.append("enemy type %d has no attribute status path" % index)
		if not enemy.get_node_or_null("EnemyStatusView"):
			errors.append("enemy type %d has no target status view" % index)
		match ENEMY_TYPES[index]:
			Enemy.EnemyType.MELEE:
				if enemy.get_node("HitboxComponent").damage <= 0.0:
					errors.append("melee enemy has no contact damage")
			Enemy.EnemyType.ARROW, Enemy.EnemyType.MAGIC:
				if enemy.shoot_range <= 0.0 or enemy.shoot_interval <= 0.0:
					errors.append("ranged enemy type %d has no shooting contract" % index)
			Enemy.EnemyType.HEAL:
				if enemy.heal_range <= 0.0 or enemy.heal_amount <= 0.0:
					errors.append("healer has no healing contract")
			Enemy.EnemyType.HEAVY, Enemy.EnemyType.ASSASSIN:
				if enemy.get_node("HitboxComponent").damage <= 0.0 or enemy.speed <= 0.0:
					errors.append("elite enemy type %d has no combat contract" % index)

	var healer: Enemy = null
	var heal_target: Enemy = null
	for candidate in get_tree().get_nodes_in_group("Enemy"):
		if not candidate is Enemy:
			continue
		if candidate.enemy_type == Enemy.EnemyType.HEAL:
			healer = candidate
		elif candidate.enemy_type == Enemy.EnemyType.MELEE:
			heal_target = candidate
	if healer and heal_target:
		healer.global_position = heal_target.global_position + Vector2(40.0, 0.0)
		heal_target.health_component.current_health = 1.0
	var heal_before := heal_target.health_component.current_health if heal_target else 0.0
	if not healer or not heal_target or not healer.heal_nearby_enemies() or heal_target.health_component.current_health <= heal_before:
		errors.append("healer did not execute a real ally-heal path")

	for expectation in BOSS_EXPECTATIONS:
		wave_manager.reset_manager()
		game_manager.boss_states[str(expectation["id"])] = false
		game_manager.current_wave = int(expectation["wave"])
		game_manager.game_started = true
		wave_manager.start_night()
		await get_tree().process_frame
		var boss := get_tree().get_first_node_in_group("Boss") as BossRedCrack
		if not boss:
			errors.append("scheduled boss %s did not spawn" % str(expectation["id"]))
			continue
		if boss.boss_id != str(expectation["id"]):
			errors.append("scheduled boss expected %s, got %s" % [str(expectation["id"]), boss.boss_id])
		var configured_stats: Dictionary = wave_manager.get_boss_stats(boss.boss_id)
		if not is_equal_approx(float(boss.boss_stats.get("ability_cooldown", -1.0)), float(configured_stats.get("ability_cooldown", -2.0))):
			errors.append("boss %s ability cooldown did not reach runtime" % boss.boss_id)
		if not boss.get_node_or_null("BossStatusView"):
			errors.append("boss %s has no target status view" % boss.boss_id)
		if str(boss.get_boss_status_text()).is_empty():
			errors.append("boss %s has no readable status text" % boss.boss_id)
		var hazards_before := _count_runtime_hazards()
		var bullets_before := _count_runtime_bullets()
		boss.ability_timer = 0.0
		boss._process_variant_ability(0.01)
		if boss.ability_timer <= 0.0:
			errors.append("boss %s variant ability did not enter cooldown" % boss.boss_id)
		var spawned_hazards := _count_runtime_hazards() - hazards_before
		var spawned_bullets := _count_runtime_bullets() - bullets_before
		if boss.boss_id in ["GreenPlague", "YellowSand", "AscensionKing"] and spawned_hazards <= 0:
			errors.append("boss %s did not create its hazard ability" % boss.boss_id)
		if boss.boss_id in ["BlueArc", "AscensionKing"] and spawned_bullets <= 0:
			errors.append("boss %s did not create its projectile ability" % boss.boss_id)
		boss.timer = boss.charge_cooldown
		boss.current_state = BossRedCrack.State.CHASE
		boss._physics_process(0.01)
		if boss.current_state != BossRedCrack.State.AIMING:
			errors.append("boss %s charge telegraph path did not start" % boss.boss_id)
		boss.queue_free()
		await get_tree().process_frame

	level.queue_free()
	await get_tree().process_frame
	game_manager.reset_game()
	wave_manager.reset_manager()
	if errors.is_empty():
		print("Content coverage validation passed: six enemy behaviors and five scheduled bosses")
		get_tree().quit(0)
		return

	for error in errors:
		push_error(error)
	get_tree().quit(1)
