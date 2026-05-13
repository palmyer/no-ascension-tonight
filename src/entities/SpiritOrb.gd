extends Area2D
class_name SpiritOrb

enum OrbType { RED, GREEN, BLUE, YELLOW }

@export var type: OrbType = OrbType.RED
@export var attract_speed: float = 400.0
@export var attract_dist: float = 150.0

var player: Node2D
var is_attracted: bool = false

func _ready():
	# 根据类型设置颜色
	match type:
		OrbType.RED: modulate = Color.RED
		OrbType.GREEN: modulate = Color.GREEN
		OrbType.BLUE: modulate = Color.BLUE
		OrbType.YELLOW: modulate = Color.YELLOW
	
	# 简单的出生动画
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK)

func _process(delta: float):
	if not player:
		player = get_tree().get_first_node_in_group("Player")
		return
		
	var dist = global_position.distance_to(player.global_position)
	var current_attract_dist = GameManager.current_stats.get("pickup_range", attract_dist)
	
	# 吸附逻辑
	if is_attracted or dist < current_attract_dist:
		is_attracted = true
		var direction = global_position.direction_to(player.global_position)
		global_position += direction * attract_speed * delta
		# 越靠近越快
		attract_speed += 500 * delta

func _on_body_entered(body: Node2D):
	if body is Player:
		# 触发拾取
		EventBus.emit_signal("orb_collected", type)
		queue_free()
