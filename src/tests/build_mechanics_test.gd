extends SceneTree


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var game_manager: Node = get_root().get_node_or_null("GameManager")
	var upgrade_manager: Node = get_root().get_node_or_null("UpgradeManager")
	var errors: Array[String] = []
	if not game_manager or not upgrade_manager:
		push_error("build mechanic autoloads are unavailable")
		quit(1)
		return

	game_manager.select_starting_weapon("sword")
	game_manager.reset_game()

	if not upgrade_manager.acquire_card("attribute_shift"):
		errors.append("attribute shift card could not be acquired")
	game_manager.apply_attribute_upgrade("water", 3)
	var switched_payload: Dictionary = game_manager.get_attack_attribute_payload()
	if switched_payload.size() != 1:
		errors.append("attribute shift should select one active attribute")
	if not upgrade_manager.acquire_card("attribute_prism"):
		errors.append("attribute prism prerequisite chain failed")
	if game_manager.get_attack_attribute_payload().size() != 2:
		errors.append("attribute prism should add one echo attribute")

	if upgrade_manager.acquire_card("critical_explosion"):
		errors.append("critical explosion should require critical edge")
	if not upgrade_manager.acquire_card("critical_edge"):
		errors.append("critical edge could not be acquired")
	if not upgrade_manager.acquire_card("critical_explosion"):
		errors.append("critical explosion prerequisite chain failed")
	if not is_equal_approx(upgrade_manager.get_modifier("critical_chance"), 0.12):
		errors.append("critical chance modifier mismatch")

	for color_index in range(4):
		game_manager.orb_counts[color_index] = 1
	if not upgrade_manager.acquire_card("rainbow_confluence"):
		errors.append("rainbow confluence could not be acquired")
	game_manager.update_current_stats()
	if not is_equal_approx(game_manager.get_upgrade_modifier("rainbow_damage_pct"), 18.0):
		errors.append("rainbow confluence modifier mismatch")

	for card_id in ["orb_alchemy", "momentum_edge", "reaction_overflow", "status_detonator", "boss_hunter", "execution_burst", "aura_forge", "low_health_frenzy"]:
		if not upgrade_manager.acquire_card(card_id):
			errors.append("mechanic card could not be acquired: %s" % card_id)

	var new_build_cards := [
		"overkill_conversion", "overkill_split",
		"aegis_resonance", "shield_breaker", "shield_revenge",
		"afterimage", "afterimage_echo", "afterimage_return",
		"fracture_mark", "fracture_harvest",
		"attribute_overload", "attribute_overload_echo",
		"returning_edge", "return_double",
		"kill_rhythm", "kill_chain",
		"damage_alchemy", "damage_transmute"
	]
	for card_id in new_build_cards:
		if not upgrade_manager.acquire_card(card_id):
			errors.append("new build card could not be acquired: %s" % card_id)

	if not is_equal_approx(game_manager.get_upgrade_modifier("overkill_damage_pct"), 0.65):
		errors.append("overkill conversion modifier mismatch")
	if not is_equal_approx(game_manager.get_upgrade_modifier("shield_on_orb"), 6.0):
		errors.append("shield resonance modifier mismatch")
	if not is_equal_approx(game_manager.get_upgrade_modifier("afterimage_damage_pct"), 0.90):
		errors.append("afterimage chain modifier mismatch")
	if not is_equal_approx(game_manager.get_upgrade_modifier("return_projectile_pierce_count"), 2.0):
		errors.append("return projectile pierce modifier mismatch")

	game_manager.attribute_mastery.clear()
	game_manager.apply_attribute_upgrade("fire", 3)
	game_manager.attribute_overload_stacks = 0
	var overload_payload := {"fire": 1}
	for _index in range(5):
		game_manager.register_attribute_overload(overload_payload, Vector2.ZERO, 10.0)
	if game_manager.attribute_overload_stacks != 5:
		errors.append("attribute overload should accumulate one stack per hit")
	game_manager.add_transmute_charge(100.0)
	if not is_equal_approx(game_manager.transmute_charge, 20.0):
		errors.append("damage alchemy should convert reaction damage to charge")
	if not is_equal_approx(game_manager.consume_transmute_charge(Vector2.ZERO), 20.0):
		errors.append("damage transmute should consume stored charge")

	game_manager.reset_game()
	if errors.is_empty():
		print("Build mechanic validation passed: switching, crit, chain builds, overload, shield, and transmute hooks")
		quit(0)
		return

	for error in errors:
		push_error(error)
	quit(1)
