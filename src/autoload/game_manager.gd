extends Node

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
var debug_mode: bool = true

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

func _on_boss_defeated(boss_id: String):
	if boss_states.has(boss_id):
		boss_states[boss_id] = true
		print("[DEBUG] GameManager: Boss %s defeated!" % boss_id)

func _on_orb_collected(type: int):
	orb_counts[type] += 1
	total_orbs += 1
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

	_apply_attribute_stats()

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
	for attribute_id in get_active_attribute_ids():
		payload[attribute_id] = get_attribute_mastery_level(attribute_id)
	return payload

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
	print("[DEBUG] Attunement changed to: ", type)

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
	
	update_current_stats()
	print("[DEBUG] Game State Reset")
