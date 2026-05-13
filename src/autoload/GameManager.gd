extends Node

enum GameState { DAY, SHOP, NIGHT }
var current_state: GameState = GameState.DAY
var current_wave: int = 1

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
var total_orbs: int = 0
var player_level: int = 1
var xp_required: int = 10 # 初始升级所需
var xp_growth: int = 5

# 基础属性 (由升级卡片提升)
var base_stats = {
	"max_health": 100,
	"damage_pct": 0,
	"attack_speed": 0,
	"move_speed": 0,
	"armor": 0,
	"bullet_count": 1,
	"attack_range": 600.0,        # 基础攻击范围
	"pickup_range": 150.0        # 基础拾取范围
}

# 当前实时属性 (基础 + 灵性加成 + 光环加成)
var current_stats = {}

# 光环状态
var player_in_aura: bool = false

func _ready():
	EventBus.orb_collected.connect(_on_orb_collected)
	update_current_stats()

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

func level_up():
	player_level += 1
	total_orbs = 0 
	xp_required += xp_growth
	EventBus.level_up.emit(player_level)
	get_tree().paused = true

func apply_card_upgrade(stat_name: String, value: float):
	base_stats[stat_name] += value
	update_current_stats()

# 调谐系统 (Attunement)
# -1 表示均分，0-3 表示对应颜色的权重提升至 40%
var attuned_type: int = -1 

func get_weighted_drop_type() -> int:
	if attuned_type == -1:
		return randi() % 4
	
	var roll = randf()
	if roll < 0.4:
		return attuned_type
	
	# 剩下的 60% 由其他 3 种颜色均分 (每种 20%)
	var others = []
	for i in range(4):
		if i != attuned_type:
			others.append(i)
	
	var remaining_roll = (roll - 0.4) / 0.6
	if remaining_roll < 0.33:
		return others[0]
	elif remaining_roll < 0.66:
		return others[1]
	else:
		return others[2]

func set_attunement(type: int):
	attuned_type = type
	print("[DEBUG] Attunement changed to: ", type)

func get_min_energy_level() -> int:
	var min_count = orb_counts[0]
	for i in range(1, 4):
		if orb_counts[i] < min_count:
			min_count = orb_counts[i]
	# 每 5 个球升一级
	return min_count / 5

func reset_game():
	current_state = GameState.DAY
	current_wave = 1
	total_orbs = 0
	player_level = 1
	xp_required = 10
	player_in_aura = false
	attuned_type = -1
	
	for key in orb_counts:
		orb_counts[key] = 0
	
	# 重置基础属性
	base_stats = {
		"max_health": 100,
		"damage_pct": 0,
		"attack_speed": 0,
		"move_speed": 0,
		"armor": 0,
		"bullet_count": 1,
		"attack_range": 600.0,
		"pickup_range": 150.0
	}
	
	update_current_stats()
	print("[DEBUG] Game State Reset")


