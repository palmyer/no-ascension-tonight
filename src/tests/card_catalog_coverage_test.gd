extends Node

func _init() -> void:
	call_deferred("_run_checks")

func _acquire_card_with_prerequisites(card_id: String, game_manager: Node, upgrade_manager: Node, visiting: Dictionary) -> bool:
	if upgrade_manager.has_card(card_id):
		return true
	if visiting.has(card_id):
		return false
	var card: Dictionary = upgrade_manager.get_card_definition(card_id)
	if card.is_empty():
		return false
	var required_weapon := str(card.get("requires_weapon", ""))
	if not required_weapon.is_empty() and required_weapon != str(game_manager.selected_weapon_id):
		return false
	visiting[card_id] = true
	var required_card := str(card.get("requires_card", ""))
	if not required_card.is_empty() and not _acquire_card_with_prerequisites(required_card, game_manager, upgrade_manager, visiting):
		visiting.erase(card_id)
		return false
	var acquired: bool = upgrade_manager.acquire_card(card_id)
	visiting.erase(card_id)
	return acquired

func _run_checks() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	var upgrade_manager: Node = get_node_or_null("/root/UpgradeManager")
	if not game_manager or not upgrade_manager:
		push_error("card coverage autoloads are unavailable")
		get_tree().quit(1)
		return

	var errors: Array[String] = []
	var catalog: Array = upgrade_manager.CARD_CATALOG
	if catalog.size() != 66:
		errors.append("expected 66 cards, got %d" % catalog.size())

	var ids: Dictionary = {}
	for card in catalog:
		var card_id := str(card.get("id", ""))
		if card_id.is_empty() or ids.has(card_id):
			errors.append("card catalog contains an empty or duplicate id")
		ids[card_id] = true
		var effect_type := str(card.get("effect_type", ""))
		if effect_type == "modifier" and (card.get("modifiers", {}) as Dictionary).is_empty():
			errors.append("modifier card has no modifiers: %s" % card_id)
		if int(card.get("max_rank", 1)) > 1 and upgrade_manager.CARD_RANK_VALUES.get(card_id, []).size() < int(card.get("max_rank", 1)):
			errors.append("repeatable card has incomplete rank values: %s" % card_id)

	game_manager.select_starting_weapon("sword")
	game_manager.reset_game()
	for _offer_index in range(40):
		var offer: Array[Dictionary] = upgrade_manager.get_offer(3)
		if offer.size() != 3:
			errors.append("three-choice offer returned %d cards" % offer.size())
		var offered_ids: Dictionary = {}
		for card in offer:
			var card_id := str(card.get("id", ""))
			if offered_ids.has(card_id):
				errors.append("three-choice offer duplicated card: %s" % card_id)
			offered_ids[card_id] = true
			var required_weapon := str(card.get("requires_weapon", ""))
			if not required_weapon.is_empty() and required_weapon != game_manager.selected_weapon_id:
				errors.append("offer leaked wrong weapon card: %s" % card_id)
			var required_card := str(card.get("requires_card", ""))
			if not required_card.is_empty() and not upgrade_manager.has_card(required_card):
				errors.append("offer leaked locked prerequisite card: %s" % card_id)

	var weapon_ids := ["sword", "blade", "spear", "musket"]
	for weapon_id in weapon_ids:
		game_manager.select_starting_weapon(weapon_id)
		game_manager.reset_game()
		var visiting: Dictionary = {}
		for card in catalog:
			var required_weapon := str(card.get("requires_weapon", ""))
			if not required_weapon.is_empty() and required_weapon != weapon_id:
				continue
			var card_id := str(card.get("id", ""))
			if upgrade_manager.has_card(card_id):
				continue
			var required_card := str(card.get("requires_card", ""))
			if not required_card.is_empty() and not upgrade_manager.has_card(required_card):
				if not _acquire_card_with_prerequisites(required_card, game_manager, upgrade_manager, visiting):
					errors.append("%s prerequisite path failed: %s" % [card_id, required_card])
					continue
			var modifier_values_before: Dictionary = {}
			for modifier_id in card.get("modifiers", {}):
				modifier_values_before[str(modifier_id)] = upgrade_manager.get_modifier(str(modifier_id))
			if not upgrade_manager.acquire_card(card_id):
				errors.append("%s could not acquire card path: %s" % [weapon_id, card_id])
				continue
			var card_definition: Dictionary = upgrade_manager.get_card_definition(card_id)
			for modifier_id in card_definition.get("modifiers", {}):
				var expected_value := float(card_definition["modifiers"][modifier_id])
				var before_value := float(modifier_values_before.get(str(modifier_id), 0.0))
				var applied_value: float = upgrade_manager.get_modifier(str(modifier_id)) - before_value
				if not is_equal_approx(applied_value, expected_value):
					errors.append("%s modifier was not stored: %s" % [card_id, modifier_id])

		var acquired_cards: Array[Dictionary] = upgrade_manager.get_acquired_cards()
		if acquired_cards.size() != 60:
			errors.append("%s should expose 60 card definitions, got %d" % [weapon_id, acquired_cards.size()])
		for card in catalog:
			var required_weapon := str(card.get("requires_weapon", ""))
			if required_weapon.is_empty() or required_weapon == weapon_id:
				if not upgrade_manager.has_card(str(card.get("id", ""))):
					errors.append("%s card became unreachable: %s" % [weapon_id, card.get("id", "")])

	game_manager.reset_game()
	if errors.is_empty():
		print("Card catalog coverage passed: 66 definitions, 60 reachable per weapon, and prerequisite chains")
		get_tree().quit(0)
		return

	for error in errors:
		push_error(error)
	get_tree().quit(1)
