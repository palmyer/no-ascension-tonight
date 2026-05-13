extends CanvasLayer

@onready var card_container = $Control/HBoxContainer

# 定义可选的升级
var upgrades = [
	{"name": "Max HP+", "stat": "max_health", "value": 20},
	{"name": "Damage+", "stat": "damage_pct", "value": 10},
	{"name": "Speed+", "stat": "move_speed", "value": 5},
	{"name": "Armor+", "stat": "armor", "value": 2},
	{"name": "Attack Speed+", "stat": "attack_speed", "value": 10},
	{"name": "Bullet Count+", "stat": "bullet_count", "value": 1},
	{"name": "Attack Range+", "stat": "attack_range", "value": 100},
	{"name": "Pickup Range+", "stat": "pickup_range", "value": 100}
	]



func _ready():
	visible = false
	EventBus.level_up.connect(_on_level_up)

func _on_level_up(_new_level: int):
	# 弹出界面
	visible = true
	# 生成 3 张随机卡片
	for child in card_container.get_children():
		child.queue_free()
	
	var pool = upgrades.duplicate()
	pool.shuffle()
	
	for i in range(3):
		var up = pool[i]
		var btn = Button.new()
		btn.text = up["name"] + "\n(+" + str(up["value"]) + ")"
		btn.custom_minimum_size = Vector2(200, 300)
		btn.pressed.connect(_on_card_selected.bind(up))
		card_container.add_child(btn)

func _on_card_selected(upgrade):
	# 应用属性
	GameManager.apply_card_upgrade(upgrade["stat"], upgrade["value"])
	# 恢复游戏
	visible = false
	get_tree().paused = false
