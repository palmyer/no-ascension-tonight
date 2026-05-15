extends Node2D

@onready var state_label: Label = $UI/Control/StateLabel
@onready var timer_label: Label = $UI/Control/TimerLabel
@onready var orb_count_label: Label = $UI/Control/OrbCountLabel
@onready var xp_bar: ProgressBar = $UI/Control/XPBar
@onready var stats_label: Label = $UI/Control/StatsLabel
@onready var last_damage_label: Label = $UI/Control/LastDamageLabel

func _ready():
	EventBus.player_damaged.connect(_on_player_damaged)

func _on_player_damaged(damage: float):
	last_damage_label.text = "Last Damage: %.1f" % damage

func _process(_delta: float):
	update_ui()

func update_ui():
	var state_name = "DAY"
	match GameManager.current_state:
		GameManager.GameState.DAY: state_name = "DAY"
		GameManager.GameState.NIGHT: state_name = "NIGHT"

	state_label.text = "State: %s (Wave %d)" % [state_name, GameManager.current_wave]
	timer_label.text = "Time: %d" % int(WaveManager.time_left)

	# 调谐状态
	var attune_name = "None"
	match GameManager.attuned_type:
		0: attune_name = "Red (DMG)"
		1: attune_name = "Green (HP)"
		2: attune_name = "Blue (AtkSpd)"
		3: attune_name = "Yellow (Spd)"
	$UI/Control/AttuneLabel.text = "Current Attune: " + attune_name

	# 经验与掉落
	xp_bar.max_value = GameManager.xp_required
	xp_bar.value = GameManager.total_orbs
	$UI/Control/XPLabel.text = "LV: %d" % GameManager.player_level
	
	orb_count_label.text = "R:%d G:%d B:%d Y:%d" % [
		GameManager.orb_counts[0],
		GameManager.orb_counts[1],
		GameManager.orb_counts[2],
		GameManager.orb_counts[3]
	]
	
	# 属性展示 (3行格式)
	var cur = GameManager.current_stats
	var base = GameManager.base_stats
	
	var line_top = "[CURRENT] HP:%d DMG:%d%% SPD:%d%% REG:%d" % [
		cur.max_health, cur.damage_pct, cur.move_speed, int(cur.hp_regen_5s)
	]
	
	var line_mid = "[AURA] " + ("ACTIVE (DMG/ATK+20%%, SPD+15%%)" if GameManager.player_in_aura else "INACTIVE")
	
	var line_bot = "[BASE] HP:%d DMG:%d%% SPD:%d%% ARM:%d BUL:%d" % [
		base.max_health, base.damage_pct, base.move_speed, base.armor, base.bullet_count
	]
	
	stats_label.text = "%s\n%s\n%s" % [line_top, line_mid, line_bot]
