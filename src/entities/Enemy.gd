extends CharacterBody2D
class_name Enemy

enum EnemyType { MELEE, RANGED }
@export var enemy_type: EnemyType = EnemyType.MELEE

@onready var health_component: HealthComponent = $HealthComponent
@export var speed: float = 100.0
@export var shoot_range: float = 400.0
@export var shoot_interval: float = 1.5
@export var bullet_scene_path: String = "res://scenes/Bullet.tscn"

var target: Node2D
var shoot_timer: float = 0.0
var health_label: Label

@export var orb_scene: PackedScene = preload("res://scenes/SpiritOrb.tscn")
@onready var bullet_pkg: PackedScene = load(bullet_scene_path)

@export var aggro_range: float = 350.0

var player: Node2D
var core: Node2D

func _ready():
	add_to_group("Enemy")
	
	# 根据类型设置颜色
	if enemy_type == EnemyType.RANGED:
		$Placeholder.color = Color.PURPLE # 远程敌人紫色
		speed = 80.0 # 远程走慢点
	else:
		$Placeholder.color = Color.RED # 近战敌人红色
	
	# 随着波数增加血量
	var scaled_health = 10.0 + (GameManager.current_wave - 1) * 5.0
	health_component.max_health = scaled_health
	health_component.current_health = scaled_health
	
	health_component.died.connect(_on_died)
	player = get_tree().get_first_node_in_group("Player")
	core = get_tree().get_first_node_in_group("LifeCore")
	
	setup_debug_ui()

func setup_debug_ui():
	health_label = Label.new()
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.position = Vector2(-20, -10) # 居中显示在敌人身上
	health_label.add_theme_font_size_override("font_size", 14)
	add_child(health_label)

func _physics_process(delta: float):
	# 更新 Debug UI
	if health_label:
		health_label.visible = GameManager.debug_mode
		health_label.text = str(int(health_component.current_health))

	if not player: player = get_tree().get_first_node_in_group("Player")
	if not core: core = get_tree().get_first_node_in_group("LifeCore")
	
	if not player: return
	
	var dist_to_player = global_position.distance_to(player.global_position)
	var current_aggro = aggro_range
	var is_night = GameManager.current_state == GameManager.GameState.NIGHT
	
	if is_night:
		current_aggro = aggro_range * 2.0
	
	var move_target: Vector2 = Vector2.ZERO
	var active_chase = false
	
	if dist_to_player < current_aggro:
		# 玩家在范围内，优先追玩家
		move_target = player.global_position
		active_chase = true
		
		# 远程攻击逻辑 (仅限远程敌人)
		if enemy_type == EnemyType.RANGED and dist_to_player < shoot_range:
			shoot_timer -= delta
			if shoot_timer <= 0:
				shoot_at_player()
				shoot_timer = shoot_interval
	elif is_night and core:
		# 晚上且玩家不在范围，向灵核移动
		move_target = core.global_position
		active_chase = true
	
	if active_chase:
		var direction = global_position.direction_to(move_target)
		# 如果在射程内且是追玩家，可以稍微减速或者停止以便射击（可选）
		var final_speed = speed
		if dist_to_player < shoot_range * 0.5: final_speed *= 0.5
		
		velocity = direction * final_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO

func shoot_at_player():
	if not bullet_pkg or not player: return
	var bullet = bullet_pkg.instantiate()
	bullet.damage = 5.0 # 敌人子弹伤害
	bullet.color = Color.WHITE # 敌人子弹白色
	bullet.global_position = global_position
	bullet.rotation = global_position.direction_to(player.global_position).angle()
	
	# 修正层级逻辑：
	var hb = bullet.get_node("HitboxComponent")
	hb.collision_layer = 16 # 设置为“敌人攻击层”，对应玩家 Hurtbox 的 Mask
	hb.collision_mask = 2   # 检测“玩家身体层”，用于子弹碰撞消失
	
	get_tree().root.add_child(bullet)

func _on_died():
	print("Enemy Defeated!")
	spawn_orb()
	queue_free()

func spawn_orb():
	if not orb_scene: return
	var orb = orb_scene.instantiate()
	orb.global_position = global_position
	# 使用调谐后的加权概率
	orb.type = GameManager.get_weighted_drop_type()
	get_parent().add_child(orb)

func _on_hurtbox_component_hit(damage: float):
	# 受击反馈：变红
	modulate = Color.RED
	var knockback_dir = (global_position - get_tree().get_first_node_in_group("Player").global_position).normalized()
	global_position += knockback_dir * 10.0
	
	# 缩放效果
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.05)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)
	
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE

