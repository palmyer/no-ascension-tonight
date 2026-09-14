extends Node

const WEAPON_EXPECTATIONS := [
	{"id": "sword", "damage": 10.0, "ranged": false, "attribute": "fire", "exclusive_cards": ["sword_sweep", "sword_burn_trail"]},
	{"id": "blade", "damage": 15.0, "ranged": false, "attribute": "poison", "exclusive_cards": ["blade_combo", "blade_poison_cloud"]},
	{"id": "spear", "damage": 22.0, "ranged": false, "attribute": "ice", "exclusive_cards": ["spear_pierce", "spear_shatter"]},
	{"id": "musket", "damage": 16.0, "ranged": true, "attribute": "thunder", "exclusive_cards": ["musket_charge", "musket_aura"]}
]

func _init() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var root := get_tree().root
	var game_manager: GameManager = root.get_node_or_null("GameManager") as GameManager
	var upgrade_manager: Node = root.get_node_or_null("UpgradeManager")
	var errors: Array[String] = []
	if not game_manager or not upgrade_manager:
		push_error("weapon runtime autoloads are unavailable")
		get_tree().quit(1)
		return

	for expectation in WEAPON_EXPECTATIONS:
		var weapon_id := str(expectation["id"])
		game_manager.select_starting_weapon(weapon_id)
		game_manager.start_new_run()
		var level: Node = load("res://scenes/levels/first_level.tscn").instantiate()
		root.add_child(level)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame

		var spawner: Node = level.get_node_or_null("Gameplay/EnemySpawner")
		if spawner:
			spawner.process_mode = Node.PROCESS_MODE_DISABLED
		var player := get_tree().get_first_node_in_group("Player") as Player
		if not player:
			errors.append("%s player was not instantiated" % weapon_id)
		else:
			if not player.weapon_runtime or player.weapon_runtime.weapon_id != weapon_id:
				errors.append("%s did not use the single WeaponRuntime contract" % weapon_id)
			elif not is_equal_approx(player.weapon_runtime.get_base_damage(), float(expectation["damage"])):
				errors.append("%s WeaponRuntime definition disagrees with the player" % weapon_id)
			if not is_equal_approx(player.weapon_damage, float(expectation["damage"])):
				errors.append("%s base damage mismatch" % weapon_id)
			if player.uses_ranged_weapon != bool(expectation["ranged"]):
				errors.append("%s ranged contract mismatch" % weapon_id)
			var payload := game_manager.get_attack_attribute_payload()
			if not payload.has(str(expectation["attribute"])):
				errors.append("%s starting attribute is missing from attack payload" % weapon_id)
			var profile := player.get_special_profile()
			if float(profile.get("damage", 0.0)) <= 0.0 or float(profile.get("cooldown", 0.0)) <= 0.0:
				errors.append("%s special profile is not executable" % weapon_id)
			if not Dictionary(profile.get("payload", {})).has(str(expectation["attribute"])):
				errors.append("%s special payload does not carry its starting attribute" % weapon_id)

			var enemy := load("res://scenes/entities/enemies/enemy.tscn").instantiate() as Enemy
			enemy.enemy_type = Enemy.EnemyType.MELEE
			level.get_node("Gameplay").add_child(enemy)
			await get_tree().process_frame
			enemy.set_physics_process(false)
			enemy.health_component.max_health = 10000.0
			enemy.health_component.current_health = 10000.0
			enemy.global_position = player.global_position + Vector2(52.0, 0.0)
			await get_tree().process_frame
			# The player may have fired at an earlier spawner target while the
			# test scene was settling. Start this assertion at a known attack
			# boundary so it tests the runtime contract, not elapsed setup time.
			player.ranged_attack_timer = 0.0
			var health_before := enemy.health_component.current_health
			await get_tree().create_timer(0.65).timeout
			if enemy.health_component.current_health >= health_before:
				errors.append("%s automatic basic attack did not damage a target" % weapon_id)
			var special_health_before := enemy.health_component.current_health
			player.try_special()
			if player.get_special_cooldown_remaining() <= 0.0:
				errors.append("%s active special did not enter cooldown" % weapon_id)
			if enemy.health_component.current_health >= special_health_before:
				errors.append("%s active special did not damage a target" % weapon_id)
			if not enemy.attribute_component.statuses.has(str(expectation["attribute"])):
				errors.append("%s attack path did not apply its starting status" % weapon_id)
			for card_id in expectation["exclusive_cards"]:
				if not upgrade_manager.acquire_card(str(card_id)):
					errors.append("%s exclusive card route could not be acquired: %s" % [weapon_id, card_id])
			if player.get_weapon_status_lines().is_empty():
				errors.append("%s exclusive card route did not reach runtime status" % weapon_id)

		level.queue_free()
		await get_tree().process_frame
		for child in root.get_children():
			if child is Bullet:
				child.queue_free()
		game_manager.reset_game()

	if errors.is_empty():
		print("Weapon runtime validation passed: four basic attacks, specials, attributes, and cooldowns")
		get_tree().quit(0)
		return

	for error in errors:
		push_error(error)
	get_tree().quit(1)
