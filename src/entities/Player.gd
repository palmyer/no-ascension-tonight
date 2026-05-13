extends CharacterBody2D
class_name Player

@onready var velocity_component: VelocityComponent = $VelocityComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var hitbox: HitboxComponent = $WeaponPivot/HitboxComponent

enum WeaponMode { MELEE, RANGED }

@export var current_weapon_mode: WeaponMode = WeaponMode.RANGED
@export var attack_interval: float = 1.0 # 射速 1s/发
@export var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")

var target_enemy: Node2D
var is_attacking: bool = false
var attack_timer: float = 0.0

var health_bar: ProgressBar

func _ready():
	add_to_group("Player")
	# 初始化时关闭 hitbox
	hitbox.monitoring = false
	hitbox.monitorable = false
	attack_timer = attack_interval
	
	health_component.died.connect(_on_health_component_died)
	setup_health_bar()

func setup_health_bar():
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(50, 6)
	health_bar.position = Vector2(-25, -35)
	
	# 设置样式
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color.RED
	health_bar.add_theme_stylebox_override("fill", sb)
	
	add_child(health_bar)

func _physics_process(delta: float):
	# 更新血条
	if health_bar:
		health_bar.max_value = health_component.max_health
		health_bar.value = health_component.current_health
	
	# 动态应用实时属性
	var base_speed = velocity_component.max_speed
	var current_speed = base_speed * (1.0 + GameManager.current_stats["move_speed"] / 100.0)
	
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity_component.velocity = velocity_component.velocity.move_toward(direction.normalized() * current_speed, velocity_component.acceleration * delta)
	velocity_component.move(self)
	
	# 自动索敌
	target_enemy = get_nearest_enemy()
	
	# 旋转逻辑
	if not is_attacking or current_weapon_mode == WeaponMode.RANGED:
		if target_enemy:
			weapon_pivot.look_at(target_enemy.global_position)
		else:
			var mouse_pos = get_global_mouse_position()
			weapon_pivot.look_at(mouse_pos)
	
	# 自动攻击计时 (应用当前攻速加成)
	var base_interval = attack_interval
	var current_interval = base_interval / (1.0 + GameManager.current_stats["attack_speed"] / 100.0)
	
	attack_timer -= delta
	if attack_timer <= 0:
		if target_enemy:
			attack()
			attack_timer = current_interval
	
	queue_redraw()

func get_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("Enemy")
	var nearest = null
	var min_dist = GameManager.current_stats["attack_range"]
	
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy
	return nearest

func _draw():
	# 绘制攻击范围 (红圈)
	var attack_r = GameManager.current_stats["attack_range"]
	draw_arc(Vector2.ZERO, attack_r, 0, TAU, 64, Color(1, 0, 0, 0.1), 1.0)

func attack():
	match current_weapon_mode:
		WeaponMode.MELEE:
			attack_melee()
		WeaponMode.RANGED:
			attack_ranged()

func attack_ranged():
	print("[DEBUG] Auto-Shoot Triggered")
	if not bullet_scene: return
	
	var count = GameManager.current_stats["bullet_count"]
	var spread_angle = deg_to_rad(15.0) 
	
	# 应用实时伤害加成
	var final_damage = 20.0 * (1.0 + GameManager.current_stats["damage_pct"] / 100.0)
	
	for i in range(count):
		var bullet = bullet_scene.instantiate()
		bullet.damage = final_damage
		bullet.color = Color.GOLD # 玩家子弹金色
		var offset = (i - (count - 1) / 2.0) * spread_angle
		bullet.global_position = weapon_pivot.get_node("SwordPlaceholder").global_position
		bullet.rotation = weapon_pivot.rotation + offset
		
		# 修正层级逻辑：
		var hb = bullet.get_node("HitboxComponent")
		hb.collision_layer = 8 # 设置为“玩家攻击层”，对应敌人 Hurtbox 的 Mask
		hb.collision_mask = 4  # 检测“敌人身体层”，用于子弹碰撞消失
		
		get_tree().root.add_child(bullet)
	
	# 简单的枪口抖动反馈
	var tween = create_tween()
	var original_pos = weapon_pivot.position
	tween.tween_property(weapon_pivot, "position", original_pos + Vector2(-5, 0).rotated(weapon_pivot.rotation), 0.05)
	tween.tween_property(weapon_pivot, "position", original_pos, 0.1)


func attack_melee():
	if is_attacking:
		return
		
	print("[DEBUG] Auto-Melee Started")
	is_attacking = true
	
	# 提前开启判定，并确保 monitoring/monitorable 都为 true
	hitbox.monitoring = true
	hitbox.monitorable = true
	
	var sword = weapon_pivot.get_node("SwordPlaceholder")
	sword.color = Color.WHITE
	
	var original_rot = weapon_pivot.rotation
	var tween = create_tween()
	
	# 动作优化：大幅度蓄力 + 更广的挥砍弧度
	tween.tween_property(weapon_pivot, "rotation", original_rot - 0.8, 0.08)
	tween.tween_property(weapon_pivot, "rotation", original_rot + 3.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 延长判定时间，确保覆盖整个挥砍路径
	await get_tree().create_timer(0.25).timeout
	
	hitbox.monitoring = false
	hitbox.monitorable = false
	sword.color = Color.YELLOW
	is_attacking = false
	print("[DEBUG] Auto-Melee Finished")



func _on_health_component_died():
	print("Player Died!")
	EventBus.game_over.emit()

func _on_hurtbox_component_hit(damage: float):
	print("[DEBUG] Player hit! Damage: ", damage)
	# 受击反馈
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
