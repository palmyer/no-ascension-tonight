extends Area2D
class_name DemonCore

## 精英妖必掉的局内中间层资源。拾取后累积到本局妖丹计数，
## 在波间调谐可兑换第四事件「炼丹·淬体」。

var attract_speed: float = 320.0
var is_attracted: bool = false
var player: Node2D
var elapsed: float = 0.0

func _ready() -> void:
	z_index = 2
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if not player:
		player = get_tree().get_first_node_in_group("Player")
		return
	var dist := global_position.distance_to(player.global_position)
	var pickup_range: float = GameManager.current_stats.get("pickup_range", 150.0)
	if is_attracted or dist < pickup_range:
		is_attracted = true
		var direction := global_position.direction_to(player.global_position)
		global_position += direction * attract_speed * delta
		attract_speed += 420.0 * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		GameManager.add_demon_core()
		queue_free()

func _draw() -> void:
	var pulse := 1.0 + sin(elapsed * 5.0) * 0.08
	draw_circle(Vector2.ZERO, 13.0 * pulse, Color(0.55, 0.38, 0.10))
	draw_circle(Vector2.ZERO, 10.0 * pulse, Color("e8b64c"))
	draw_circle(Vector2(-3.0, -3.0), 3.5 * pulse, Color("fff0c2"))
	draw_arc(Vector2.ZERO, 16.0 * pulse, elapsed * 1.5, elapsed * 1.5 + PI * 1.2, 14, Color("f5d789", 0.7), 2.0)
