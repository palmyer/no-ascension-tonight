extends Node2D

const BUILD_STATUS_HUD = preload("res://src/ui/build_status_hud.gd")

@onready var state_label: Label = $UI/Control/StateLabel
@onready var timer_label: Label = $UI/Control/TimerLabel
@onready var orb_count_label: Label = $UI/Control/OrbCountLabel
@onready var xp_bar: ProgressBar = $UI/Control/XPBar
@onready var stats_label: Label = $UI/Control/StatsLabel
@onready var last_damage_label: Label = $UI/Control/LastDamageLabel

var core_bar: ProgressBar
var core_label: Label
var special_label: Label
var toast_label: Label
var toast_time: float = 0.0

func _ready():
	if not GameManager.game_started:
		GameManager.game_started = true
		WaveManager.start_day()
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.core_damaged.connect(_on_core_damaged)
	EventBus.core_repaired.connect(_on_core_repaired)
	EventBus.special_used.connect(_on_special_used)
	EventBus.attribute_reaction.connect(_on_attribute_reaction)
	EventBus.intermission_event_chosen.connect(_on_intermission_event_chosen)
	EventBus.card_acquired.connect(_on_card_acquired)
	_build_additional_hud()

func _on_player_damaged(damage: float):
	last_damage_label.text = "Last Damage: %.1f" % damage

func _on_core_damaged(damage: float, current_integrity: float, _max_integrity: float) -> void:
	_show_toast("灵核受击 -%.0f（剩余 %.0f）" % [damage, current_integrity], Color("e86d63"))

func _on_core_repaired(amount: float, current_integrity: float, _max_integrity: float) -> void:
	_show_toast("灵核修复 +%.0f（当前 %.0f）" % [amount, current_integrity], Color("72d19a"))

func _on_special_used(skill_name: String, hit_count: int) -> void:
	_show_toast("%s · 命中 %d" % [skill_name, hit_count], Color("f0c66a"))

func _on_attribute_reaction(reaction_name: String, _position: Vector2) -> void:
	_show_toast("属性反应：%s" % reaction_name, Color("c99bf2"))

func _on_intermission_event_chosen(event_id: String) -> void:
	var event_names := {"repair": "回灵·修核", "harvest": "贪取·丰收", "ward": "镇门·护阵"}
	_show_toast("已选择：%s" % event_names.get(event_id, event_id), Color("8bc7e8"))

func _on_card_acquired(card_id: String, rank: int) -> void:
	var card := UpgradeManager.get_card_definition(card_id)
	_show_toast("获得卡片：%s · 等级 %d" % [card.get("name", card_id), rank], Color("e9b45e"))

func _show_toast(message: String, color: Color) -> void:
	if not toast_label:
		return
	toast_label.text = message
	toast_label.add_theme_color_override("font_color", color)
	toast_time = 2.2

func _process(delta: float):
	toast_time = maxf(toast_time - delta, 0.0)
	if toast_label:
		toast_label.visible = toast_time > 0.0
	update_ui()

func _build_additional_hud() -> void:
	var hud: Control = $UI/Control

	core_bar = ProgressBar.new()
	core_bar.position = Vector2(20.0, 145.0)
	core_bar.size = Vector2(300.0, 18.0)
	core_bar.show_percentage = false
	core_bar.add_theme_stylebox_override("background", _make_bar_style(Color("172c31")))
	core_bar.add_theme_stylebox_override("fill", _make_bar_style(Color("d3a952")))
	hud.add_child(core_bar)

	core_label = Label.new()
	core_label.position = Vector2(20.0, 165.0)
	core_label.size = Vector2(360.0, 28.0)
	core_label.add_theme_font_size_override("font_size", 16)
	core_label.add_theme_color_override("font_color", Color("f1dfb0"))
	hud.add_child(core_label)

	special_label = Label.new()
	special_label.position = Vector2(20.0, 930.0)
	special_label.size = Vector2(620.0, 52.0)
	special_label.add_theme_font_size_override("font_size", 20)
	special_label.add_theme_color_override("font_color", Color("f0c66a"))
	hud.add_child(special_label)

	var build_status_hud := BUILD_STATUS_HUD.new()
	hud.add_child(build_status_hud)

	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-300.0, 112.0)
	toast_label.size = Vector2(600.0, 42.0)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 22)
	toast_label.visible = false
	hud.add_child(toast_label)

func _make_bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

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
	var attribute_line := "[ATTR] " + GameManager.get_attribute_summary()
	
	stats_label.text = "%s\n%s\n%s\n%s" % [line_top, line_mid, line_bot, attribute_line]

	var core := get_tree().get_first_node_in_group("LifeCore")
	if core and core_bar and core_label:
		core_bar.max_value = core.max_integrity
		core_bar.value = core.integrity
		var ward_text := " · 护阵 %.0fs" % GameManager.get_core_ward_time_left() if GameManager.is_core_warded() else ""
		core_label.text = "灵核 %d / %d%s" % [int(core.integrity), int(core.max_integrity), ward_text]

	var player := get_tree().get_first_node_in_group("Player")
	if player and special_label and player.has_method("get_special_profile"):
		var special_data: Dictionary = player.get_special_profile()
		var remaining := float(player.get_special_cooldown_remaining())
		var cooldown_text := "就绪" if remaining <= 0.0 else "冷却 %.1fs" % remaining
		special_label.text = "空格 · %s  [%s]    %s" % [
			special_data.get("name", "秘术"),
			cooldown_text,
			special_data.get("description", "")
		]
