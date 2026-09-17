extends Area2D
class_name RelicChest

## 昼间随机刷新的遗物宝箱。玩家触碰开启，随机获得一件一次性遗物：
## 净世符（全场伤害+硬直）/ 淬锋露（全属性熟练度+1）/ 回春露（玩家与灵核恢复）。

const RELIC_DEFINITIONS = [
	{
		"id": "purge",
		"name": "净世符",
		"color": Color("ef8a5f")
	},
	{
		"id": "sharpen",
		"name": "淬锋露",
		"color": Color("c9a4f0")
	},
	{
		"id": "spring",
		"name": "回春露",
		"color": Color("7ed69b")
	}
]

var elapsed: float = 0.0
var opened: bool = false

func _ready() -> void:
	z_index = 2
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if opened or not body.is_in_group("Player"):
		return
	opened = true
	var relic: Dictionary = RELIC_DEFINITIONS.pick_random()
	_apply_relic(str(relic.id))
	_show_relic_label(str(relic.name), Color(relic.color))
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.18)
	tween.tween_callback(queue_free)

func _apply_relic(relic_id: String) -> void:
	match relic_id:
		"purge":
			for enemy in get_tree().get_nodes_in_group("DamageableEnemy"):
				if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
					continue
				var health: HealthComponent = enemy.get_node_or_null("HealthComponent")
				if health and health.current_health <= 0.0:
					continue
				enemy.take_damage(50.0, global_position)
				GameManager.spawn_burst_damage(enemy.global_position, 40.0, 0.0, {}, Color("ef8a5f"))
		"sharpen":
			for attribute_id in GameManager.ATTRIBUTE_DEFINITIONS:
				GameManager.apply_attribute_upgrade(attribute_id, 1)
		"spring":
			var player_node := get_tree().get_first_node_in_group("Player")
			if player_node:
				var health: HealthComponent = player_node.get_node_or_null("HealthComponent")
				if health:
					health.heal(40.0)
			var core := get_tree().get_first_node_in_group("LifeCore")
			if core and core.has_method("repair"):
				core.repair(15.0)

func _show_relic_label(relic_name: String, color: Color) -> void:
	var label := Label.new()
	label.text = "获得遗物  ·  %s" % relic_name
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.position = Vector2(-80, -70)
	label.z_index = 10
	add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 46.0, 1.6)
	tween.tween_property(label, "modulate:a", 0.0, 1.6).set_delay(0.6)
	tween.chain().tween_callback(label.queue_free)

func _draw() -> void:
	var bob := sin(elapsed * 2.4) * 3.0
	var base := Vector2(0, bob)
	draw_circle(base + Vector2(0, 16), 20.0, Color(0.06, 0.10, 0.09, 0.5))
	draw_rect(Rect2(base + Vector2(-18, -6), Vector2(36, 22)), Color("8a6a3c"))
	draw_rect(Rect2(base + Vector2(-18, -6), Vector2(36, 8)), Color("a5824a"))
	draw_rect(Rect2(base + Vector2(-3, -10), Vector2(6, 10)), Color("e8c877"))
	draw_rect(Rect2(base + Vector2(-18, 4), Vector2(36, 3)), Color("5f4726"))
	var glow := 1.0 + sin(elapsed * 3.2) * 0.18
	draw_arc(base + Vector2(0, 4), 30.0 * glow, 0.0, TAU, 26, Color("f5d789", 0.35), 2.0)
