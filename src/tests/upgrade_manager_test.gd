extends SceneTree

func _init() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var game_manager: Node = get_root().get_node_or_null("GameManager")
	var upgrade_manager: Node = get_root().get_node_or_null("UpgradeManager")
	var errors: Array[String] = []
	if not game_manager or not upgrade_manager:
		push_error("upgrade system autoloads are unavailable")
		quit(1)
		return

	game_manager.select_starting_weapon("sword")
	game_manager.reset_game()
	var offer: Array[Dictionary] = upgrade_manager.get_offer(3)
	if offer.size() != 3:
		errors.append("upgrade offer should contain three cards")
	if not offer.is_empty() and str(offer[0].get("effect_type", "")) != "modifier":
		errors.append("first offer should prioritize a behavior card")
	var seen_ids: Dictionary = {}
	for card in offer:
		var card_id := str(card.get("id", ""))
		if seen_ids.has(card_id):
			errors.append("offer contains duplicate card: %s" % card_id)
		seen_ids[card_id] = true

	if not upgrade_manager.acquire_card("stat_damage"):
		errors.append("first rank stat card could not be acquired")
	if not is_equal_approx(float(game_manager.base_stats.get("damage_pct", 0.0)), 10.0):
		errors.append("first rank damage growth mismatch")
	if not upgrade_manager.acquire_card("stat_damage"):
		errors.append("second rank stat card could not be acquired")
	if not is_equal_approx(float(game_manager.base_stats.get("damage_pct", 0.0)), 22.0):
		errors.append("second rank damage growth mismatch")
	if not upgrade_manager.acquire_card("stat_damage"):
		errors.append("third rank stat card could not be acquired")
	if upgrade_manager.acquire_card("stat_damage"):
		errors.append("card exceeded its configured maximum rank")
	if upgrade_manager.get_card_rank("stat_damage") != 3:
		errors.append("card rank state did not stop at rank three")
	if not is_equal_approx(upgrade_manager.get_card_value_for_rank("stat_damage", 3), 15.0):
		errors.append("third rank card preview value mismatch")

	game_manager.reset_game()

	if not upgrade_manager.acquire_card("core_guardian"):
		errors.append("core behavior card could not be acquired")
	if not is_equal_approx(game_manager.get_upgrade_modifier("core_damage_reduction_pct"), 0.15):
		errors.append("core guardian modifier mismatch")
	if not upgrade_manager.acquire_card("spirit_harvest"):
		errors.append("day/night behavior card could not be acquired")
	if not is_equal_approx(game_manager.get_upgrade_modifier("day_bonus_orb_chance"), 0.20):
		errors.append("spirit harvest modifier mismatch")

	game_manager.select_starting_weapon("blade")
	game_manager.reset_game()
	if not upgrade_manager.acquire_card("blade_combo"):
		errors.append("matching weapon card could not be acquired")
	if upgrade_manager.acquire_card("musket_charge"):
		errors.append("non-matching weapon card should not be acquired")

	game_manager.select_starting_weapon("sword")
	game_manager.reset_game()
	if upgrade_manager.get_acquired_card_summary() != "暂无":
		errors.append("reset should clear acquired card summary")

	if errors.is_empty():
		print("Upgrade manager validation passed: card pool, ranks, and weapon gates")
		quit(0)
		return

	for error in errors:
		push_error(error)
	quit(1)
