extends Node2D
class_name TerrainPool

## 腐水潭：持续存在的地形危险区。潭内敌人周期性获得毒与藤蔓状态，
## 玩家不受影响，是引怪削弱的防守支点。

@export var pool_radius: float = 110.0

var elapsed: float = 0.0
var tick_timer: float = 0.0

const TICK_INTERVAL := 1.0

func _ready() -> void:
	z_index = 1

func _process(delta: float) -> void:
	elapsed += delta
	tick_timer -= delta
	if tick_timer <= 0.0:
		_apply_pool_tick()
		tick_timer = TICK_INTERVAL
	queue_redraw()

func _apply_pool_tick() -> void:
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if not enemy.has_method("apply_attribute_payload"):
			continue
		var health: HealthComponent = enemy.get_node_or_null("HealthComponent")
		if health and health.current_health <= 0.0:
			continue
		if enemy.is_in_group("Boss"):
			continue
		if global_position.distance_to(enemy.global_position) <= pool_radius:
			enemy.apply_attribute_payload({"poison": 1, "vine": 1}, 0.0, global_position)

func _draw() -> void:
	var pulse := 1.0 + sin(elapsed * 1.8) * 0.03
	var fill := Color("4e7a4a")
	fill.a = 0.30
	draw_circle(Vector2.ZERO, pool_radius * pulse, fill)
	var edge := Color("7fae6d")
	edge.a = 0.55
	draw_arc(Vector2.ZERO, pool_radius * pulse, 0.0, TAU, 48, edge, 3.0)
	for index in range(5):
		var angle := TAU * float(index) / 5.0 + elapsed * 0.25
		var center := Vector2.from_angle(angle) * pool_radius * 0.55
		draw_circle(center, 10.0 + sin(elapsed * 2.0 + index) * 3.0, Color("6f9a5f", 0.22))
