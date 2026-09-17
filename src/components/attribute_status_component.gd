extends Node
class_name AttributeStatusComponent

const REACTION_COOLDOWN := 0.35
const DAMAGE_NUMBER_SCRIPT = preload("res://src/effects/damage_number.gd")

var health_component: HealthComponent
var statuses: Dictionary = {}
var reaction_cooldowns: Dictionary = {}
var frozen_time: float = 0.0
var stunned_time: float = 0.0
# 0.0-1.0；大妖等强目标用它把冰冻/束缚/硬直时长按比例衰减为软控制。
var cc_resistance: float = 0.0

func _apply_hard_cc(duration: float) -> void:
	stunned_time = maxf(stunned_time, duration * (1.0 - clampf(cc_resistance, 0.0, 0.95)))

func _apply_freeze(duration: float) -> void:
	frozen_time = maxf(frozen_time, duration * (1.0 - clampf(cc_resistance, 0.0, 0.95)))

func _ready() -> void:
	if not health_component:
		health_component = get_parent().get_node_or_null("HealthComponent")

func _process(delta: float) -> void:
	frozen_time = maxf(frozen_time - delta, 0.0)
	stunned_time = maxf(stunned_time - delta, 0.0)
	for reaction_id in reaction_cooldowns.keys():
		reaction_cooldowns[reaction_id] = float(reaction_cooldowns[reaction_id]) - delta
		if reaction_cooldowns[reaction_id] <= 0.0:
			reaction_cooldowns.erase(reaction_id)
	_tick_statuses(delta)

func apply_payload(payload: Dictionary, attack_damage: float = 0.0, origin: Vector2 = Vector2.ZERO) -> void:
	for attribute_id in payload:
		_apply_attribute(str(attribute_id), int(payload[attribute_id]), attack_damage, origin)

func _apply_attribute(attribute_id: String, mastery_level: int, attack_damage: float, origin: Vector2) -> void:
	if health_component and health_component.current_health <= 0.0:
		return
	if not GameManager.ATTRIBUTE_DEFINITIONS.has(attribute_id):
		return
	var target := get_parent()

	var existing_ids: Array = statuses.keys()
	for existing_id in existing_ids:
		if existing_id == attribute_id:
			continue
		var reaction := GameManager.get_attribute_reaction(str(existing_id), attribute_id)
		if not reaction.is_empty():
			_trigger_reaction(reaction, str(existing_id), attribute_id, mastery_level, attack_damage, origin)

	var definition: Dictionary = GameManager.ATTRIBUTE_DEFINITIONS[attribute_id]
	var status: Dictionary = statuses.get(attribute_id, {"stacks": 0, "time": 0.0, "tick_time": 0.0, "mastery": 0, "bound": false})
	var mastery_bonus := maxi(mastery_level - 1, 0)
	var next_stacks := mini(int(status.get("stacks", 0)) + 1, int(definition.get("max_stacks", 1)) + mastery_bonus)
	status["stacks"] = next_stacks
	var duration_multiplier := 1.0 + mastery_bonus * 0.15
	status["time"] = maxf(float(status.get("time", 0.0)), float(definition.get("duration", 2.0)) * duration_multiplier)
	status["mastery"] = maxi(int(status.get("mastery", 0)), mastery_level)
	if attribute_id == "vine" and next_stacks >= int(definition.get("max_stacks", 1)) and not bool(status.get("bound", false)):
		_apply_hard_cc(0.55 + mastery_level * 0.15)
		status["bound"] = true
	var detonator_threshold := int(GameManager.get_upgrade_modifier("status_detonator_stacks"))
	if detonator_threshold > 0 and next_stacks >= detonator_threshold and attack_damage > 0.0:
		var detonation_damage := attack_damage * GameManager.get_upgrade_modifier("status_detonator_damage_pct", 0.32)
		target.take_damage(detonation_damage)
		GameManager.spawn_burst_damage(target.global_position, GameManager.get_upgrade_modifier("status_detonator_radius", 75.0), detonation_damage * 0.45, {}, Color("d78b63"))
		status["stacks"] = 0
	statuses[attribute_id] = status

func _tick_statuses(delta: float) -> void:
	if health_component and health_component.current_health <= 0.0:
		return
	var target := get_parent()
	for attribute_id in statuses.keys():
		var status: Dictionary = statuses[attribute_id]
		status["time"] = float(status.get("time", 0.0)) - delta
		status["tick_time"] = float(status.get("tick_time", 0.0)) - delta
		var definition: Dictionary = GameManager.ATTRIBUTE_DEFINITIONS.get(attribute_id, {})
		var tick_damage := float(definition.get("tick_damage", 0.0))
		if tick_damage > 0.0 and float(status["tick_time"]) <= 0.0 and target.has_method("take_damage"):
			if health_component and health_component.current_health <= 0.0:
				return
			var mastery_multiplier := 1.0 + maxi(int(status.get("mastery", 1)) - 1, 0) * 0.15
			target.take_damage(tick_damage * int(status.get("stacks", 1)) * mastery_multiplier)
			status["tick_time"] = 1.0
		if float(status["time"]) <= 0.0:
			statuses.erase(attribute_id)
		else:
			statuses[attribute_id] = status

func _trigger_reaction(reaction: Dictionary, first_attribute: String, second_attribute: String, mastery_level: int, attack_damage: float, origin: Vector2) -> void:
	if health_component and health_component.current_health <= 0.0:
		return
	var reaction_id := str(reaction.get("id", ""))
	if reaction_id.is_empty() or reaction_cooldowns.has(reaction_id):
		return

	var target := get_parent()
	if not target.has_method("take_damage"):
		return
	var first_mastery := int(statuses.get(first_attribute, {}).get("mastery", 1))
	var mastery_multiplier := 1.0 + float(first_mastery + mastery_level - 2) * 0.12
	var reaction_cooldown := GameManager.get_reaction_cooldown() if get_node_or_null("/root/GameManager") else REACTION_COOLDOWN
	reaction_cooldowns[reaction_id] = reaction_cooldown / mastery_multiplier
	var reaction_damage := maxf(1.0, attack_damage * float(reaction.get("damage_multiplier", 0.5)) * mastery_multiplier)
	reaction_damage *= 1.0 + GameManager.get_upgrade_modifier("reaction_damage_pct")
	GameManager.add_transmute_charge(reaction_damage)
	target.take_damage(reaction_damage)
	# 反应打击反馈：反应主色飘字 + 轻微震屏与击中停顿。
	if target is Node2D:
		var reaction_color := Color.WHITE
		var first_definition: Dictionary = GameManager.ATTRIBUTE_DEFINITIONS.get(first_attribute, {})
		match int(first_definition.get("color", -1)):
			0: reaction_color = Color("ef8556")
			1: reaction_color = Color("8fd48a")
			2: reaction_color = Color("75d7ef")
			3: reaction_color = Color("f1d36c")
		var host := target.get_parent() if target.get_parent() else get_tree().current_scene
		DAMAGE_NUMBER_SCRIPT.spawn(host, (target as Node2D).global_position, reaction_damage, "reaction", reaction_color)
		EventBus.camera_shake_requested.emit(3.0)
		GameManager.request_hitstop(0.04, 0.12)
	if get_node_or_null("/root/EventBus") and target is Node2D:
		EventBus.attribute_reaction.emit(str(reaction.get("name", reaction_id)), target.global_position)

	var effect := str(reaction.get("effect", ""))
	match effect:
		"burst":
			_damage_nearby_targets(reaction_damage * 0.35)
			_apply_knockback(origin, 28.0 + mastery_multiplier * 8.0)
			_apply_hard_cc(0.25)
		"chain":
			_chain_damage(reaction_damage * 0.45, int(reaction.get("chain_count", 2)))
		"burn":
			_apply_attribute("fire", mastery_level, reaction_damage * 0.25, origin)
		"freeze", "shatter":
			_apply_freeze(0.8 + mastery_multiplier * 0.4)
		"stun", "stagger":
			_apply_hard_cc(0.55 + mastery_multiplier * 0.25)
		"spread":
			_spread_attribute(second_attribute, reaction_damage * 0.25)

	var spread_chance := GameManager.get_upgrade_modifier("reaction_spread_chance") if get_node_or_null("/root/GameManager") else 0.0
	if effect != "spread" and spread_chance > 0.0 and randf() < spread_chance:
		var spread_count := maxi(int(GameManager.get_upgrade_modifier("reaction_spread_count", 1.0)), 1)
		_spread_attribute(second_attribute, reaction_damage * 0.25, spread_count)

func _damage_nearby_targets(damage: float) -> void:
	var target := get_parent() as Node2D
	if not target:
		return
	for other in get_tree().get_nodes_in_group("DamageableEnemy"):
		if other == target or not is_instance_valid(other) or not (other is Node2D):
			continue
		var other_health: HealthComponent = other.get_node_or_null("HealthComponent")
		if other_health and other_health.current_health <= 0.0:
			continue
		if target.global_position.distance_to(other.global_position) <= 120.0 and other.has_method("take_damage"):
			other.take_damage(damage)

func _spread_attribute(attribute_id: String, attack_damage: float, max_targets: int = -1) -> void:
	var target := get_parent() as Node2D
	if not target:
		return
	var spread_targets := 0
	for other in get_tree().get_nodes_in_group("DamageableEnemy"):
		if other == target or not is_instance_valid(other) or not (other is Node2D):
			continue
		if target.global_position.distance_to(other.global_position) > 150.0:
			continue
		if other.has_method("apply_attribute_payload"):
			other.apply_attribute_payload({attribute_id: 1}, attack_damage)
			spread_targets += 1
			if max_targets > 0 and spread_targets >= max_targets:
				break

func _chain_damage(damage: float, jump_count: int) -> void:
	var target := get_parent() as Node2D
	if not target:
		return
	var candidates: Array = []
	for other in get_tree().get_nodes_in_group("DamageableEnemy"):
		if other == target or not is_instance_valid(other) or not (other is Node2D):
			continue
		var other_health: HealthComponent = other.get_node_or_null("HealthComponent")
		if other_health and other_health.current_health <= 0.0:
			continue
		if target.global_position.distance_to(other.global_position) <= 180.0 and other.has_method("take_damage"):
			candidates.append(other)

	for _jump in range(mini(candidates.size(), jump_count)):
		var nearest: Node = null
		var nearest_distance := INF
		for candidate in candidates:
			var candidate_distance := target.global_position.distance_to(candidate.global_position)
			if candidate_distance < nearest_distance:
				nearest_distance = candidate_distance
				nearest = candidate
		if not nearest:
			break
		nearest.take_damage(damage)
		candidates.erase(nearest)

func _apply_knockback(origin: Vector2, distance: float) -> void:
	var target := get_parent() as Node2D
	if not target:
		return
	var direction := origin.direction_to(target.global_position) if origin != Vector2.ZERO else Vector2.RIGHT
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	target.global_position += direction * distance

func get_speed_multiplier() -> float:
	if frozen_time > 0.0 or stunned_time > 0.0:
		return 0.0
	var multiplier := 1.0
	if statuses.has("vine"):
		var vine_mastery := int(statuses["vine"].get("mastery", 1))
		multiplier *= maxf(0.5, 0.65 - maxi(vine_mastery - 1, 0) * 0.05)
	if statuses.has("ice"):
		var ice_mastery := int(statuses["ice"].get("mastery", 1))
		multiplier *= maxf(0.4, 0.55 - maxi(ice_mastery - 1, 0) * 0.05)
	return multiplier

func is_disabled() -> bool:
	return frozen_time > 0.0 or stunned_time > 0.0

func get_healing_received_multiplier() -> float:
	var poison_status: Dictionary = statuses.get("poison", {})
	if poison_status.is_empty():
		return 1.0
	return maxf(1.0 - int(poison_status.get("stacks", 0)) * 0.15, 0.25)
