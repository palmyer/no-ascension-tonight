extends Node

const DAMAGE_ZONE_SCRIPT = preload("res://src/effects/damage_zone.gd")
const SKILL_BURST_VISUAL = preload("res://src/effects/skill_burst_visual.gd")

enum GameState { DAY, SHOP, NIGHT }
var current_state: GameState = GameState.DAY
var current_wave: int = 1
var game_started: bool = false
var run_won: bool = false

const STARTING_WEAPON_ORDER = ["sword", "blade", "spear", "musket"]
const STARTING_WEAPONS = {
	"sword": {
		"name": "引霜灵剑",
		"subtitle": "平衡近战",
		"description": "攻守均衡，挥斩稳定，适合第一次踏入秘境。"
	},
	"blade": {
		"name": "破鳞钢刃",
		"subtitle": "快速连斩",
		"description": "出手更快，贴身压制妖兽，但攻击距离较短。"
	},
	"spear": {
		"name": "龙脊长枪",
		"subtitle": "长距爆发",
		"description": "攻击距离与伤害更高，回身较慢，需要预判走位。"
	},
	"musket": {
		"name": "火符连铳",
		"subtitle": "远程守线",
		"description": "远距离发射符弹，适合守住灵核外围。"
	}
}
var selected_weapon_id: String = "sword"

const ATTRIBUTE_ORDER = ["fire", "blast", "poison", "vine", "water", "ice", "wind", "thunder"]
const ATTRIBUTE_DEFINITIONS = {
	"fire": {"color": 0, "name": "火", "display_name": "焚锋", "description": "灼烧目标并持续造成伤害。", "duration": 4.0, "max_stacks": 3, "tick_damage": 2.0},
	"blast": {"color": 0, "name": "爆", "display_name": "爆燃", "description": "积累爆印，在其他属性触发时引爆。", "duration": 3.0, "max_stacks": 3, "tick_damage": 0.0},
	"poison": {"color": 1, "name": "毒", "display_name": "毒蚀", "description": "叠加毒层，降低敌人恢复并持续腐蚀。", "duration": 5.0, "max_stacks": 5, "tick_damage": 1.5},
	"vine": {"color": 1, "name": "藤", "display_name": "荆棘", "description": "减速目标，叠满后短暂束缚。", "duration": 3.5, "max_stacks": 3, "tick_damage": 1.0},
	"water": {"color": 2, "name": "水", "display_name": "浸润", "description": "浸润目标，强化后续属性反应。", "duration": 4.0, "max_stacks": 3, "tick_damage": 0.0},
	"ice": {"color": 2, "name": "冰", "display_name": "凝霜", "description": "积累寒霜，减速并冻结目标。", "duration": 4.0, "max_stacks": 3, "tick_damage": 0.5},
	"wind": {"color": 3, "name": "风", "display_name": "风刃", "description": "留下风痕，扩散附近属性状态。", "duration": 3.0, "max_stacks": 3, "tick_damage": 1.0},
	"thunder": {"color": 3, "name": "雷", "display_name": "引雷", "description": "积累雷印，触发链式闪电与麻痹。", "duration": 3.0, "max_stacks": 3, "tick_damage": 1.0}
}

const ATTRIBUTE_REACTIONS = {
	"fire|water": {"id": "steam_burst", "name": "蒸爆", "damage_multiplier": 0.65, "effect": "burst"},
	"fire|ice": {"id": "melt_shatter", "name": "熔裂", "damage_multiplier": 0.95, "effect": "shatter"},
	"fire|poison": {"id": "toxic_flame", "name": "焚毒", "damage_multiplier": 0.75, "effect": "burst"},
	"fire|vine": {"id": "burning_vine", "name": "燃藤", "damage_multiplier": 0.70, "effect": "burn"},
	"fire|thunder": {"id": "thunder_fire", "name": "雷火", "damage_multiplier": 0.85, "effect": "chain", "chain_count": 2},
	"fire|blast": {"id": "flame_blast", "name": "爆燃", "damage_multiplier": 0.90, "effect": "burst"},
	"blast|ice": {"id": "ice_blast", "name": "冰爆", "damage_multiplier": 0.90, "effect": "freeze"},
	"blast|poison": {"id": "toxic_blast", "name": "毒爆", "damage_multiplier": 0.85, "effect": "burst"},
	"blast|water": {"id": "pressure_burst", "name": "水爆", "damage_multiplier": 0.80, "effect": "burst"},
	"blast|wind": {"id": "wind_blast", "name": "风爆", "damage_multiplier": 0.80, "effect": "stagger"},
	"blast|thunder": {"id": "thunder_blast", "name": "雷爆", "damage_multiplier": 1.00, "effect": "chain", "chain_count": 2},
	"poison|ice": {"id": "frozen_toxin", "name": "冻毒", "damage_multiplier": 0.70, "effect": "freeze"},
	"ice|thunder": {"id": "frost_thunder", "name": "霜雷", "damage_multiplier": 1.05, "effect": "chain", "chain_count": 3},
	"vine|ice": {"id": "frozen_vine", "name": "冰藤", "damage_multiplier": 0.70, "effect": "freeze"},
	"ice|wind": {"id": "snowstorm", "name": "雪暴", "damage_multiplier": 0.70, "effect": "freeze"},
	"poison|thunder": {"id": "corrosive_lightning", "name": "腐雷", "damage_multiplier": 0.80, "effect": "chain", "chain_count": 2},
	"poison|wind": {"id": "toxic_mist", "name": "毒雾", "damage_multiplier": 0.60, "effect": "spread"},
	"vine|thunder": {"id": "lightning_web", "name": "雷网", "damage_multiplier": 0.85, "effect": "stun", "chain_count": 2},
	"vine|wind": {"id": "thorn_storm", "name": "藤风", "damage_multiplier": 0.70, "effect": "spread"},
	"water|ice": {"id": "ice_lock", "name": "冰封", "damage_multiplier": 0.75, "effect": "freeze"},
	"water|thunder": {"id": "conduct", "name": "导电", "damage_multiplier": 0.90, "effect": "chain", "chain_count": 3},
	"water|wind": {"id": "water_blade", "name": "水刃", "damage_multiplier": 0.75, "effect": "stagger"},
	"wind|thunder": {"id": "storm_charge", "name": "风雷", "damage_multiplier": 0.85, "effect": "chain", "chain_count": 2}
}

const WEAPON_ATTRIBUTES = {
	"sword": ["fire"],
	"blade": ["poison"],
	"spear": ["ice"],
	"musket": ["thunder"]
}

# Debug 开关
var debug_mode: bool = false

# 掉落计数
var orb_counts = {
	0: 0, # RED
	1: 0, # GREEN
	2: 0, # BLUE
	3: 0  # YELLOW
}

# 经验与等级
const XP_BASE_REQUIREMENT: int = 10
const XP_LINEAR_GROWTH: int = 4
const XP_STEP_GROWTH: int = 2
var total_orbs: int = 0
var player_level: int = 1
var xp_required: int = XP_BASE_REQUIREMENT

# 基础属性模板 (唯一来源)
const DEFAULT_BASE_STATS = {
	"max_health": 100,
	"damage_pct": 0,
	"attack_speed": 0,
	"move_speed": 0,
	"armor": 0,
	"bullet_count": 1,
	"hp_regen_5s": 0.0,           # 5秒回复量
	"attack_range": 1600.0,        # 基础攻击范围
	"pickup_range": 150.0,        # 基础拾取范围
	"outside_aura_damage_pct": 0,
	"low_health_damage_reduction": 0,
	"orb_attract_speed_pct": 0
}
# 基础属性 (由升级卡片提升)
var base_stats = DEFAULT_BASE_STATS.duplicate(true)

# 当前实时属性 (基础 + 灵性加成 + 光环加成)
var current_stats = {}
var attribute_mastery: Dictionary = {}

# 光环状态
var player_in_aura: bool = false

# 波间事件效果。效果只影响下一波，避免把一次选择永久滚雪球。
var next_day_orb_bonus: float = 0.0
var next_night_core_ward: float = 0.0
var active_core_ward_time: float = 0.0
var last_intermission_event_id: String = ""
var core_revenge_ready: bool = false
var special_core_repair_timer: float = 0.0
var attribute_shift_timer: float = 0.0
var attribute_shift_index: int = 0
var attribute_shift_initialized: bool = false
var attribute_overload_stacks: int = 0
var overkill_chain_depth: int = 0
var transmute_charge: float = 0.0

# Boss 状态跟踪
var boss_states = {
	"RedCrack": false,
	"GreenPlague": false,
	"BlueArc": false,
	"YellowSand": false,
	"AscensionKing": false
}

func _ready():
	EventBus.orb_collected.connect(_on_orb_collected)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	update_current_stats()

func _process(delta: float) -> void:
	active_core_ward_time = maxf(active_core_ward_time - delta, 0.0)
	special_core_repair_timer = maxf(special_core_repair_timer - delta, 0.0)
	_process_attribute_shift(delta)

func _on_boss_defeated(boss_id: String):
	if boss_states.has(boss_id):
		boss_states[boss_id] = true
		if debug_mode:
			print("[DEBUG] GameManager: Boss %s defeated!" % boss_id)

func _on_orb_collected(type: int):
	orb_counts[type] += 1
	total_orbs += 1
	if has_upgrade("orb_alchemy"):
		var player := get_tree().get_first_node_in_group("Player")
		var health := player.get_node_or_null("HealthComponent") if player else null
		if health:
			health.heal(get_upgrade_modifier("orb_alchemy_heal", 0.0))
	var shield_player := get_tree().get_first_node_in_group("Player")
	if shield_player and shield_player.has_method("add_temporary_shield") and has_upgrade("aegis_resonance"):
		shield_player.add_temporary_shield(get_upgrade_modifier_or_default("shield_on_orb", 0.0))
	update_current_stats() # 灵性球改变即更新属性
	
	if total_orbs >= xp_required:
		level_up()

func update_current_stats():
	# 1. 初始化为基础属性
	for key in base_stats:
		current_stats[key] = base_stats[key]
	
	# 2. 灵性等级加成 (每级 5 个球)
	# 红(0): 伤害, 绿(1): 生命, 蓝(2): 攻速, 黄(3): 移速
	current_stats["damage_pct"] += (orb_counts[0] / 5) * 5
	current_stats["max_health"] += (orb_counts[1] / 5) * 10
	current_stats["attack_speed"] += (orb_counts[2] / 5) * 5
	current_stats["move_speed"] += (orb_counts[3] / 5) * 2
	
	# 3. 光环加成 (如果在范围内)
	if player_in_aura:
		current_stats["damage_pct"] += 20
		current_stats["attack_speed"] += 20
		current_stats["move_speed"] += 15
		current_stats["hp_regen_5s"] += 5.0 # 光环内5秒回5点
		current_stats["armor"] += get_upgrade_modifier("aura_armor")
		current_stats["damage_pct"] += get_upgrade_modifier("aura_damage_pct")

	var rainbow_threshold := maxi(int(get_upgrade_modifier("rainbow_threshold", 0.0)), 0)
	if rainbow_threshold > 0 and _has_all_four_colors(rainbow_threshold):
		current_stats["damage_pct"] += get_upgrade_modifier("rainbow_damage_pct")

	_apply_attribute_stats()
	current_stats["outside_aura_damage_pct"] += get_upgrade_modifier("outside_aura_damage_pct")

	var player := get_tree().get_first_node_in_group("Player")
	if player and player.has_method("apply_runtime_stats"):
		player.apply_runtime_stats(current_stats)

func level_up():
	player_level += 1
	total_orbs = 0 
	xp_required = get_xp_required_for_level(player_level)
	EventBus.level_up.emit(player_level)
	get_tree().paused = true

func get_xp_required_for_level(level: int) -> int:
	var level_index := maxi(level - 1, 0)
	var step_bonus := floori(float(level_index) / 4.0) * XP_STEP_GROWTH
	return XP_BASE_REQUIREMENT + level_index * XP_LINEAR_GROWTH + step_bonus

func apply_card_upgrade(stat_name: String, value: float):
	base_stats[stat_name] += value
	update_current_stats()

func apply_attribute_upgrade(attribute_id: String, points: int = 3) -> void:
	if not ATTRIBUTE_DEFINITIONS.has(attribute_id):
		return
	attribute_mastery[attribute_id] = int(attribute_mastery.get(attribute_id, 0)) + maxi(points, 1)
	update_current_stats()

func has_upgrade(card_id: String) -> bool:
	var upgrade_manager := get_node_or_null("/root/UpgradeManager")
	return upgrade_manager != null and upgrade_manager.has_card(card_id)

func get_upgrade_modifier(modifier_id: String, default_value: float = 0.0) -> float:
	var upgrade_manager := get_node_or_null("/root/UpgradeManager")
	if not upgrade_manager:
		return default_value
	return float(upgrade_manager.get_modifier(modifier_id, default_value))

func get_upgrade_modifier_or_default(modifier_id: String, fallback: float) -> float:
	var value := get_upgrade_modifier(modifier_id)
	return fallback if is_zero_approx(value) else value

func get_reaction_cooldown() -> float:
	return maxf(0.12, 0.35 * (1.0 - get_upgrade_modifier("reaction_cooldown_reduction")))

func arm_core_revenge() -> void:
	if has_upgrade("core_revenge"):
		core_revenge_ready = true

func consume_core_revenge_bonus() -> float:
	if not core_revenge_ready:
		return 0.0
	core_revenge_ready = false
	return get_upgrade_modifier("core_revenge_damage_pct")

func try_special_core_repair() -> float:
	var amount := get_upgrade_modifier("special_core_repair_amount")
	if amount <= 0.0 or special_core_repair_timer > 0.0:
		return 0.0
	special_core_repair_timer = get_upgrade_modifier("special_core_repair_interval", 12.0)
	return amount

func spawn_damage_zone(position: Vector2, radius: float, duration: float, damage: float, payload: Dictionary, color: Color) -> void:
	var zone := DAMAGE_ZONE_SCRIPT.new()
	zone.global_position = position
	zone.configure(radius, duration, damage, payload, color)
	var host := get_tree().current_scene
	if not host:
		host = get_tree().root
	host.add_child(zone)

func get_attribute_mastery_level(attribute_id: String) -> int:
	var points := int(attribute_mastery.get(attribute_id, 0))
	if points >= 10:
		return 3
	if points >= 6:
		return 2
	if points >= 3:
		return 1
	return 0

func get_active_attribute_ids() -> Array:
	var active: Array = []
	for attribute_id in ATTRIBUTE_ORDER:
		if int(attribute_mastery.get(attribute_id, 0)) > 0:
			active.append(attribute_id)
	return active

func get_attack_attribute_payload() -> Dictionary:
	var payload: Dictionary = {}
	var active := get_active_attribute_ids()
	if has_upgrade("attribute_shift") and active.size() >= 2:
		var current_index := posmod(attribute_shift_index, active.size())
		var current_attribute := str(active[current_index])
		payload[current_attribute] = get_attribute_mastery_level(current_attribute)
		if has_upgrade("attribute_prism"):
			var echo_attribute := str(active[(current_index + 1) % active.size()])
			payload[echo_attribute] = maxi(get_attribute_mastery_level(echo_attribute) - 1, 1)
		return payload
	for attribute_id in active:
		payload[attribute_id] = get_attribute_mastery_level(attribute_id)
	return payload

func get_current_shift_attribute() -> String:
	var active := get_active_attribute_ids()
	if active.is_empty():
		return ""
	return str(active[posmod(attribute_shift_index, active.size())])

func spawn_burst_damage(position: Vector2, radius: float, damage: float, payload: Dictionary = {}, color: Color = Color("f6c857")) -> int:
	if radius <= 0.0 or damage <= 0.0:
		return 0
	var defeated_count := 0
	for enemy in get_tree().get_nodes_in_group("DamageableEnemy"):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if position.distance_to(enemy.global_position) > radius:
			continue
		var was_alive := true
		var enemy_health := enemy.get_node_or_null("HealthComponent")
		if enemy_health:
			was_alive = enemy_health.current_health > 0.0
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
		if was_alive and enemy_health and enemy_health.current_health <= 0.0:
			defeated_count += 1
		if not payload.is_empty() and enemy.has_method("apply_attribute_payload"):
			enemy.apply_attribute_payload(payload, damage, position)
	var visual := SKILL_BURST_VISUAL.new()
	visual.global_position = position
	visual.configure(radius, color)
	var host := get_tree().current_scene if get_tree().current_scene else get_tree().root
	host.add_child(visual)
	return defeated_count

func spawn_overkill_chain(position: Vector2, overkill_damage: float) -> void:
	if not has_upgrade("overkill_conversion") or overkill_damage <= 0.0:
		return
	var max_depth := maxi(int(get_upgrade_modifier_or_default("overkill_chain_depth", 2.0)), 1)
	if overkill_chain_depth >= max_depth:
		return
	var radius := get_upgrade_modifier_or_default("overkill_radius", 185.0)
	var target_count := maxi(int(get_upgrade_modifier_or_default("overkill_chain_count", 1.0)), 1)
	var candidates: Array = []
	for enemy in get_tree().get_nodes_in_group("DamageableEnemy"):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_health := enemy.get_node_or_null("HealthComponent")
		if enemy_health and enemy_health.current_health <= 0.0:
			continue
		if position.distance_to(enemy.global_position) <= radius:
			candidates.append(enemy)
	overkill_chain_depth += 1
	for index in range(mini(target_count, candidates.size())):
		var nearest: Node2D = null
		var nearest_distance := INF
		for candidate in candidates:
			if not is_instance_valid(candidate) or not (candidate is Node2D):
				continue
			var distance := position.distance_to(candidate.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = candidate
		if not nearest:
			break
		var damage_ratio := get_upgrade_modifier_or_default("overkill_damage_pct", 0.65)
		if index > 0:
			damage_ratio = get_upgrade_modifier_or_default("overkill_split_damage_pct", damage_ratio)
		nearest.take_damage(overkill_damage * damage_ratio)
		candidates.erase(nearest)
	overkill_chain_depth -= 1
	var visual := SKILL_BURST_VISUAL.new()
	visual.global_position = position
	visual.configure(radius, Color("f6c857"))
	var host := get_tree().current_scene if get_tree().current_scene else get_tree().root
	host.add_child(visual)

func register_attribute_overload(payload: Dictionary, position: Vector2, attack_damage: float) -> bool:
	if not has_upgrade("attribute_overload"):
		return false
	if get_active_attribute_ids().size() != 1 or payload.size() != 1:
		attribute_overload_stacks = 0
		return false
	attribute_overload_stacks += 1
	var threshold := maxi(int(get_upgrade_modifier_or_default("attribute_overload_threshold", 6.0)), 1)
	if attribute_overload_stacks < threshold:
		return false
	attribute_overload_stacks = 0
	var burst_damage := attack_damage * get_upgrade_modifier_or_default("attribute_overload_damage_pct", 1.2)
	var radius := get_upgrade_modifier_or_default("attribute_overload_radius", 90.0)
	spawn_burst_damage(position, radius, burst_damage, payload, Color("e67e52"))
	return true

func add_transmute_charge(reaction_damage: float) -> void:
	if not has_upgrade("damage_alchemy") or reaction_damage <= 0.0:
		return
	var charge_pct := get_upgrade_modifier_or_default("transmute_charge_pct", 0.20)
	var max_charge := get_upgrade_modifier_or_default("transmute_max_charge", 90.0)
	transmute_charge = minf(transmute_charge + reaction_damage * charge_pct, max_charge)

func consume_transmute_charge(position: Vector2) -> float:
	if transmute_charge <= 0.0:
		return 0.0
	var charge := transmute_charge
	transmute_charge = 0.0
	if has_upgrade("damage_transmute"):
		spawn_burst_damage(
			position,
			get_upgrade_modifier_or_default("transmute_radius", 82.0),
			charge * get_upgrade_modifier_or_default("transmute_burst_pct", 0.75),
			{},
			Color("d9a5ff")
		)
	return charge

func spawn_afterimage_attack(position: Vector2, attack_damage: float, payload: Dictionary, color: Color) -> int:
	if not has_upgrade("afterimage") or attack_damage <= 0.0:
		return 0
	var echo_damage := attack_damage * get_upgrade_modifier_or_default("afterimage_damage_pct", 0.25)
	var defeated_count := spawn_burst_damage(
		position,
		get_upgrade_modifier_or_default("afterimage_radius", 72.0),
		echo_damage,
		payload,
		color
	)
	if has_upgrade("afterimage_return"):
		var player := get_tree().get_first_node_in_group("Player")
		if player and player.has_method("refund_special_cooldown"):
			player.refund_special_cooldown(get_upgrade_modifier_or_default("afterimage_cooldown_refund", 0.45))
	return defeated_count

func resolve_player_attack_damage(base_damage: float, position: Vector2, color: Color = Color("f6c857")) -> Dictionary:
	var critical_chance := clampf(get_upgrade_modifier("critical_chance"), 0.0, 1.0)
	if critical_chance <= 0.0 or randf() >= critical_chance:
		return {"damage": base_damage, "critical": false}
	var critical_damage := base_damage * get_upgrade_modifier("critical_multiplier", 1.5)
	var explosion_radius := get_upgrade_modifier("critical_explosion_radius")
	if explosion_radius > 0.0:
		spawn_burst_damage(position, explosion_radius, critical_damage * get_upgrade_modifier("critical_explosion_damage_pct"), {}, color)
	return {"damage": critical_damage, "critical": true}

func _process_attribute_shift(delta: float) -> void:
	if not has_upgrade("attribute_shift"):
		return
	var active := get_active_attribute_ids()
	if active.size() < 2:
		attribute_shift_index = 0
		attribute_shift_initialized = false
		return
	if not attribute_shift_initialized:
		attribute_shift_timer = get_upgrade_modifier("attribute_shift_interval", 4.5)
		attribute_shift_initialized = true
		return
	attribute_shift_timer -= delta
	if attribute_shift_timer <= 0.0:
		attribute_shift_index = (attribute_shift_index + 1) % active.size()
		attribute_shift_timer = get_upgrade_modifier("attribute_shift_interval", 4.5)

func _has_all_four_colors(threshold: int) -> bool:
	for color_index in range(4):
		if int(orb_counts.get(color_index, 0)) < threshold:
			return false
	return true

func get_attribute_summary() -> String:
	var parts: Array[String] = []
	for attribute_id in get_active_attribute_ids():
		var definition: Dictionary = ATTRIBUTE_DEFINITIONS[attribute_id]
		parts.append("%s%d" % [definition.get("display_name", attribute_id), get_attribute_mastery_level(attribute_id)])
	return "、".join(parts) if not parts.is_empty() else "无"

func get_attribute_reaction(first_attribute: String, second_attribute: String) -> Dictionary:
	if first_attribute == second_attribute:
		return {}
	var first_index := ATTRIBUTE_ORDER.find(first_attribute)
	var second_index := ATTRIBUTE_ORDER.find(second_attribute)
	if first_index < 0 or second_index < 0:
		return {}
	var key := "%s|%s" % [first_attribute, second_attribute] if first_index < second_index else "%s|%s" % [second_attribute, first_attribute]
	return ATTRIBUTE_REACTIONS.get(key, {}).duplicate(true)

func _apply_attribute_stats() -> void:
	for attribute_id in get_active_attribute_ids():
		var level := get_attribute_mastery_level(attribute_id)
		match attribute_id:
			"fire": current_stats["damage_pct"] += level * 2
			"blast": current_stats["attack_range"] += level * 35
			"poison": current_stats["damage_pct"] += level
			"vine": current_stats["attack_range"] += level * 20
			"water": current_stats["attack_speed"] += level * 2
			"ice": current_stats["attack_range"] += level * 25
			"wind": current_stats["move_speed"] += level * 3
			"thunder": current_stats["attack_speed"] += level * 3

# 调谐系统 (Attunement)
# -1 表示均分，0-3 表示对应颜色的权重提升至 40%
var attuned_type: int = -1 

func get_weighted_drop_type() -> int:
	# 排除已封死（斩首）的方向
	var boss_by_type := {
		0: "RedCrack",
		1: "GreenPlague",
		2: "BlueArc",
		3: "YellowSand"
	}
	var active_types = []
	for i in range(4):
		var boss_id: String = boss_by_type[i]
		if boss_id == "" or not boss_states.get(boss_id, false):
			active_types.append(i)
	
	if active_types.size() == 0: return randi() % 4 # Fallback
	
	if attuned_type != -1 and active_types.has(attuned_type):
		var roll = randf()
		if roll < 0.4:
			return attuned_type
		
		# 剩下的从其他可用颜色中选
		var other_actives = []
		for t in active_types:
			if t != attuned_type:
				other_actives.append(t)
		
		if other_actives.size() > 0:
			return other_actives.pick_random()
		else:
			return attuned_type
	
	return active_types.pick_random()

func set_attunement(type: int):
	attuned_type = type
	update_current_stats()
	if debug_mode:
		print("[DEBUG] Attunement changed to: ", type)

func apply_intermission_event(event_id: String) -> void:
	last_intermission_event_id = event_id
	match event_id:
		"repair":
			var core := get_tree().get_first_node_in_group("LifeCore")
			if core and core.has_method("repair"):
				core.repair(30.0)
			var player := get_tree().get_first_node_in_group("Player")
			var health := player.get_node_or_null("HealthComponent") if player else null
			if health:
				health.heal(20.0)
		"harvest":
			next_day_orb_bonus = 0.35
		"ward":
			next_night_core_ward = 18.0
		_:
			return
	EventBus.intermission_event_chosen.emit(event_id)

func activate_night_ward() -> void:
	active_core_ward_time = next_night_core_ward
	next_night_core_ward = 0.0

func is_core_warded() -> bool:
	return active_core_ward_time > 0.0

func get_core_ward_time_left() -> float:
	return active_core_ward_time

func should_drop_bonus_orb() -> bool:
	var total_bonus := next_day_orb_bonus + get_upgrade_modifier("day_bonus_orb_chance")
	if current_state != GameState.DAY or total_bonus <= 0.0:
		return false
	return randf() < total_bonus

func clear_day_event_bonus() -> void:
	next_day_orb_bonus = 0.0

func select_starting_weapon(weapon_id: String) -> void:
	if STARTING_WEAPONS.has(weapon_id):
		selected_weapon_id = weapon_id

func get_selected_weapon() -> Dictionary:
	return STARTING_WEAPONS.get(selected_weapon_id, STARTING_WEAPONS["sword"])

func start_new_run() -> void:
	reset_game()
	WaveManager.reset_manager()
	game_started = true
	WaveManager.start_day()

func get_min_energy_level() -> int:
	var min_count = orb_counts[0]
	for i in range(1, 4):
		if orb_counts[i] < min_count:
			min_count = orb_counts[i]
	# 每 5 个球升一级
	return min_count / 5

func reset_game():
	game_started = false
	run_won = false
	current_state = GameState.DAY
	current_wave = 1
	total_orbs = 0
	player_level = 1
	xp_required = get_xp_required_for_level(player_level)
	player_in_aura = false
	attuned_type = -1
	next_day_orb_bonus = 0.0
	next_night_core_ward = 0.0
	active_core_ward_time = 0.0
	last_intermission_event_id = ""
	core_revenge_ready = false
	special_core_repair_timer = 0.0
	attribute_shift_timer = 0.0
	attribute_shift_index = 0
	attribute_shift_initialized = false
	attribute_overload_stacks = 0
	overkill_chain_depth = 0
	transmute_charge = 0.0
	
	for key in boss_states:
		boss_states[key] = false
	
	for key in orb_counts:
		orb_counts[key] = 0
	
	# 重置基础属性
	base_stats = DEFAULT_BASE_STATS.duplicate(true)
	attribute_mastery.clear()
	var starting_attributes: Array = WEAPON_ATTRIBUTES.get(selected_weapon_id, ["fire"])
	for attribute_id in starting_attributes:
		attribute_mastery[attribute_id] = 3
	var upgrade_manager := get_node_or_null("/root/UpgradeManager")
	if upgrade_manager:
		upgrade_manager.reset_run()
	
	update_current_stats()
	if debug_mode:
		print("[DEBUG] Game State Reset")
