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
	{"name": "HP Regen+", "stat": "hp_regen_5s", "value": 1.0},
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
	for attribute_id in GameManager.ATTRIBUTE_ORDER:
		var definition: Dictionary = GameManager.ATTRIBUTE_DEFINITIONS[attribute_id]
		pool.append({
			"name": "%s·%s" % [definition.get("name", attribute_id), definition.get("display_name", attribute_id)],
			"type": "attribute",
			"attribute_id": attribute_id,
			"value": 3,
			"description": definition.get("description", "")
		})
	pool.shuffle()
	
	for i in range(3):
		var up = pool[i]
		var btn = Button.new()
		btn.text = str(up["name"])
		var description := str(up.get("description", ""))
		if not description.is_empty():
			btn.text += "\n" + description
		btn.text += "\n(+" + str(up["value"]) + ")"
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(200, 300)
		btn.pressed.connect(_on_card_selected.bind(up))
		card_container.add_child(btn)

func _on_card_selected(upgrade):
	# 应用属性
	if upgrade.get("type", "stat") == "attribute":
		GameManager.apply_attribute_upgrade(upgrade["attribute_id"], int(upgrade["value"]))
	else:
		GameManager.apply_card_upgrade(upgrade["stat"], upgrade["value"])
	# 恢复游戏
	visible = false
	get_tree().paused = false
