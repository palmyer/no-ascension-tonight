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
@export var max_integrity: float = 100.0
var integrity: float = 100.0
var hit_flash_time: float = 0.0
var destroyed: bool = false

func _ready():
	add_to_group("LifeCore")
	integrity = max_integrity
	# 初始更新一次
	update_aura_shape()
	queue_redraw()

func _process(delta: float):
	# 实时更新形状以响应拾取
	update_aura_shape()
	hit_flash_time = maxf(hit_flash_time - delta, 0.0)
	var integrity_ratio := get_integrity_ratio()
	$CoreVisual.color = Color("d34c4c").lerp(Color("46c982"), integrity_ratio)
	$CoreVisual.modulate = Color(1.0, 1.0, 1.0, 1.0) if hit_flash_time <= 0.0 else Color(1.8, 0.65, 0.65, 1.0)
	queue_redraw()

func receive_damage(amount: float) -> void:
	if destroyed or not GameManager.game_started or GameManager.is_core_warded():
		return
	var final_damage := maxf(amount, 0.0)
	var damage_reduction := clampf(GameManager.get_upgrade_modifier("core_damage_reduction_pct"), 0.0, 0.75)
	var damage_taken_bonus := GameManager.get_upgrade_modifier("core_damage_taken_pct")
	final_damage *= maxf(1.0 - damage_reduction + damage_taken_bonus, 0.1)
	if final_damage <= 0.0:
		return
	integrity = clampf(integrity - final_damage, 0.0, max_integrity)
	hit_flash_time = 0.18
	EventBus.core_damaged.emit(final_damage, integrity, max_integrity)
	if GameManager.has_upgrade("core_revenge"):
		GameManager.arm_core_revenge()
	if integrity <= 0.0:
		destroyed = true
		EventBus.core_destroyed.emit()
		GameManager.game_started = false
		EventBus.game_over.emit()

func repair(amount: float) -> void:
	if destroyed:
		return
	var final_amount := maxf(amount, 0.0)
	if final_amount <= 0.0:
		return
	var old_integrity := integrity
	integrity = minf(integrity + final_amount, max_integrity)
	var repaired_amount := integrity - old_integrity
	if repaired_amount > 0.0:
		EventBus.core_repaired.emit(repaired_amount, integrity, max_integrity)

func get_integrity_ratio() -> float:
	return clampf(integrity / maxf(max_integrity, 1.0), 0.0, 1.0)

func is_destroyed() -> bool:
	return destroyed

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
	draw_arc(Vector2.ZERO, 52.0, -PI / 2.0, TAU * get_integrity_ratio() - PI / 2.0, 40, Color("e8c36a"), 5.0)
	if GameManager.is_core_warded():
		draw_arc(Vector2.ZERO, 62.0, 0.0, TAU, 48, Color(0.38, 0.78, 1.0, 0.85), 3.0)
	if GameManager.core_revenge_ready:
		draw_arc(Vector2.ZERO, 70.0, -PI / 2.0, TAU * 0.8 - PI / 2.0, 48, Color("f0b95f"), 4.0)

func _on_aura_area_body_entered(body: Node2D):
	if body.is_in_group("Player"):
		GameManager.player_in_aura = true
		GameManager.update_current_stats()
		if GameManager.debug_mode:
			print("[DEBUG] Player entered Aura - Buff Applied")

func _on_aura_area_body_exited(body: Node2D):
	if body.is_in_group("Player"):
		GameManager.player_in_aura = false
		GameManager.update_current_stats()
		if GameManager.debug_mode:
			print("[DEBUG] Player left Aura - Buff Removed")
