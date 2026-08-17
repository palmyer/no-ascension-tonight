extends StaticBody2D
class_name LifeCore

@onready var aura_area: Area2D = $AuraArea
@onready var aura_collision: CollisionPolygon2D = $AuraArea/CollisionPolygon2D
@onready var aura_red_visual: Sprite2D = $AuraVisuals/Red
@onready var aura_green_visual: Sprite2D = $AuraVisuals/Green
@onready var aura_blue_visual: Sprite2D = $AuraVisuals/Blue
@onready var aura_yellow_visual: Sprite2D = $AuraVisuals/Yellow

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
	update_aura_visuals()
	
	queue_redraw()

func update_aura_visuals():
	var cardinal_radii = get_cardinal_radii()
	var radius_scale = base_aura_radius
	if radius_scale <= 0.0:
		return

	# Each texture represents one directional spirit vein. Scale only along its
	# direction so visual growth follows collision aura shape.
	aura_red_visual.scale = Vector2(1.0, cardinal_radii[3] / radius_scale)
	aura_green_visual.scale = Vector2(1.0, cardinal_radii[1] / radius_scale)
	aura_blue_visual.scale = Vector2(cardinal_radii[0] / radius_scale, 1.0)
	aura_yellow_visual.scale = Vector2(cardinal_radii[2] / radius_scale, 1.0)

	aura_red_visual.modulate.a = get_aura_alpha(GameManager.orb_counts[0])
	aura_green_visual.modulate.a = get_aura_alpha(GameManager.orb_counts[1])
	aura_blue_visual.modulate.a = get_aura_alpha(GameManager.orb_counts[2])
	aura_yellow_visual.modulate.a = get_aura_alpha(GameManager.orb_counts[3])

func get_aura_alpha(orb_count: int) -> float:
	return clamp(0.32 + orb_count * 0.018, 0.32, 0.72)

func get_cardinal_radii():
	var cardinal_radii = [
		base_aura_radius + GameManager.orb_counts[2] * radius_growth_per_orb, # Right (Blue)
		base_aura_radius + GameManager.orb_counts[1] * radius_growth_per_orb, # Down (Green)
		base_aura_radius + GameManager.orb_counts[3] * radius_growth_per_orb, # Left (Yellow)
		base_aura_radius + GameManager.orb_counts[0] * radius_growth_per_orb  # Up (Red)
	]

	# Up (RedCrack) extends to the map boundary after beheading.
	if GameManager.boss_states.get("RedCrack", false):
		cardinal_radii[3] = 2000.0

	return cardinal_radii

func get_aura_radius_at_angle(angle: float) -> float:
	# 归一化角度到 [0, TAU]
	angle = fposmod(angle, TAU)
	
	# 0(Right:Blue), PI/2(Down:Green), PI(Left:Yellow), 3PI/2(Up:Red)
	var cardinal_radii = get_cardinal_radii()
	
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
	
	draw_polygon(points, [Color(0.08, 0.16, 0.2, 0.18)])
	# 绘制边缘线
	draw_polyline(points + PackedVector2Array([points[0]]), Color(0.65, 0.86, 0.78, 0.5), 2.0)

func _on_aura_area_body_entered(body: Node2D):
	if body.is_in_group("Player"):
		GameManager.player_in_aura = true
		GameManager.update_current_stats()
		print("[DEBUG] Player entered Aura - Buff Applied")

func _on_aura_area_body_exited(body: Node2D):
	if body.is_in_group("Player"):
		GameManager.player_in_aura = false
		GameManager.update_current_stats()
		print("[DEBUG] Player left Aura - Buff Removed")
