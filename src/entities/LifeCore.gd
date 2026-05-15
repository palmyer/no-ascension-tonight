extends StaticBody2D
class_name LifeCore

@onready var aura_area: Area2D = $AuraArea
@onready var aura_collision: CollisionPolygon2D = $AuraArea/CollisionPolygon2D

var base_aura_radius: float = 150.0
var radius_growth_per_orb: float = 5.0 # 每颗球增加的半径

func _ready():
	add_to_group("LifeCore")
	# 初始更新一次
	update_aura_shape()

func _process(_delta: float):
	# 实时更新形状以响应拾取
	update_aura_shape()

func update_aura_shape():
	var points = PackedVector2Array()
	var segments = 64
	
	for i in range(segments):
		var angle = (float(i) / segments) * TAU
		var radius = get_aura_radius_at_angle(angle)
		points.append(Vector2.from_angle(angle) * radius)
	
	if aura_collision:
		aura_collision.polygon = points
	
	queue_redraw()

func get_aura_radius_at_angle(angle: float) -> float:
	# 归一化角度到 [0, TAU]
	angle = fposmod(angle, TAU)
	
	# 定义四个顶点的方向
	# 0(Right:Blue), PI/2(Down:Green), PI(Left:Yellow), 3PI/2(Up:Red)
	var cardinal_radii = [
		base_aura_radius + GameManager.orb_counts[2] * radius_growth_per_orb, # Right (Blue)
		base_aura_radius + GameManager.orb_counts[1] * radius_growth_per_orb, # Down (Green)
		base_aura_radius + GameManager.orb_counts[3] * radius_growth_per_orb, # Left (Yellow)
		base_aura_radius + GameManager.orb_counts[0] * radius_growth_per_orb  # Up (Red)
	]
	
	# 检查斩首状态并提供超远半径（灵路）
	# Up (RedCrack) 是索引 3
	if GameManager.boss_states.get("RedCrack", false):
		cardinal_radii[3] = 2000.0 # 延伸到边界
	
	var segment_idx = int(angle / (PI/2))
	var t = (angle - segment_idx * (PI/2)) / (PI/2)
	
	var r1 = cardinal_radii[segment_idx]
	var r2 = cardinal_radii[(segment_idx + 1) % 4]
	
	# 使用平滑插值 (Smoothstep) 使曲线圆滑
	var smooth_t = t * t * (3.0 - 2.0 * t)
	return lerp(r1, r2, smooth_t)

func _draw():
	# 绘制平滑光环
	var points = PackedVector2Array()
	var segments = 64
	for i in range(segments):
		var angle = (float(i) / segments) * TAU
		var radius = get_aura_radius_at_angle(angle)
		points.append(Vector2.from_angle(angle) * radius)
	
	draw_polygon(points, [Color(0, 1, 1, 0.2)])
	# 绘制边缘线
	draw_polyline(points + PackedVector2Array([points[0]]), Color(0, 1, 1, 0.5), 2.0)

func _on_aura_area_body_entered(body: Node2D):
	if body is Player:
		GameManager.player_in_aura = true
		GameManager.update_current_stats()
		print("[DEBUG] Player entered Aura - Buff Applied")

func _on_aura_area_body_exited(body: Node2D):
	if body is Player:
		GameManager.player_in_aura = false
		GameManager.update_current_stats()
		print("[DEBUG] Player left Aura - Buff Removed")
