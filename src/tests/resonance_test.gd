extends SceneTree

func _init() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var game_manager: Node = get_root().get_node_or_null("GameManager")
	if not game_manager:
		push_error("GameManager autoload is unavailable")
		quit(1)
		return

	var errors: Array[String] = []
	for attribute_id in game_manager.ATTRIBUTE_ORDER:
		game_manager.reset_game()
		game_manager.attribute_mastery[attribute_id] = 10
		game_manager.update_current_stats()
		if game_manager.get_attribute_mastery_level(attribute_id) != 3:
			errors.append("mastery did not reach level 3: %s" % attribute_id)
		if not game_manager.get_attack_attribute_payload().has(attribute_id):
			errors.append("attribute payload missing: %s" % attribute_id)

	var known_reactions := [
		["fire", "water", "steam_burst"],
		["fire", "ice", "melt_shatter"],
		["fire", "blast", "flame_blast"],
		["poison", "ice", "frozen_toxin"],
		["vine", "ice", "frozen_vine"],
		["poison", "wind", "toxic_mist"],
		["water", "thunder", "conduct"],
		["ice", "thunder", "frost_thunder"],
		["vine", "thunder", "lightning_web"]
	]
	for reaction_case in known_reactions:
		var reaction: Dictionary = game_manager.get_attribute_reaction(reaction_case[0], reaction_case[1])
		if str(reaction.get("id", "")) != reaction_case[2]:
			errors.append("reaction mismatch: %s + %s" % [reaction_case[0], reaction_case[1]])

	if game_manager.get_attribute_reaction("fire", "fire").size() != 0:
		errors.append("same attribute should not trigger reaction")

	if errors.is_empty():
		print("Attribute reaction validation passed")
		quit(0)
		return

	for error in errors:
		push_error(error)
	quit(1)
