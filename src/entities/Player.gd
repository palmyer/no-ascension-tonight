extends CharacterBody2D
class_name Player

# 组件引用
@onready var velocity_component: VelocityComponent = $VelocityComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapon_slot: Node2D = $WeaponSlot

var weapons: Array[WeaponBase] = []
var target_enemy: Node2D
var regen_timer: float = 0.0
var health_bar: ProgressBar

const MAX_WEAPONS: int = 6
const WEAPON_ORBIT_RADIUS: float = 52.0

func _ready():
	add_to_group("Player")
	
	# 初始化已装备的武器
	refresh_weapons()
	
	health_component.died.connect(_on_health_component_died)
	setup_health_bar()
	
	if animated_sprite:
		animated_sprite.play("idle")

func refresh_weapons():
	weapons.clear()
	for child in weapon_slot.get_children():
		if child is WeaponBase:
			if weapons.size() >= MAX_WEAPONS:
				break
			weapons.append(child)
			child.equip(self)
	layout_weapon_positions()

func layout_weapon_positions():
	for i in range(weapons.size()):
		var slot_angle = TAU * float(i) / float(MAX_WEAPONS)
		weapons[i].position = Vector2.RIGHT.rotated(slot_angle) * WEAPON_ORBIT_RADIUS

func setup_health_bar():
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(50, 6)
	health_bar.position = Vector2(-25, -50)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color.RED
	health_bar.add_theme_stylebox_override("fill", sb)
	add_child(health_bar)

func _physics_process(delta: float):
	handle_movement(delta)
	handle_regeneration(delta)
	
	target_enemy = get_nearest_enemy()
	
	# 处理所有已装备武器的逻辑
	for weapon in weapons:
		handle_weapon_logic(weapon, delta)
	
	queue_redraw()

func handle_movement(delta: float):
	var current_speed = velocity_component.max_speed * (1.0 + GameManager.current_stats["move_speed"] / 100.0)
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity_component.velocity = direction.normalized() * current_speed
	velocity_component.move(self)

func handle_regeneration(delta: float):
	regen_timer += delta
	if regen_timer >= 1.0:
		regen_timer -= 1.0
		var regen_per_sec = GameManager.current_stats["hp_regen_5s"] / 5.0
		if regen_per_sec > 0 and health_component.current_health < health_component.max_health:
			health_component.current_health = min(health_component.max_health, health_component.current_health + regen_per_sec)

func handle_weapon_logic(weapon: WeaponBase, _delta: float):
	var effective_range = weapon.get_effective_range()
	
	# 1. 旋转逻辑 (只有不攻击时或远程武器才自动转向)
	if not weapon.is_attacking or weapon is RangedWeapon:
		if target_enemy and global_position.distance_to(target_enemy.global_position) <= effective_range:
			weapon.look_at(target_enemy.global_position)
		else:
			weapon.look_at(get_global_mouse_position())
	
	# 2. 攻击触发逻辑
	if weapon.can_attack() and target_enemy:
		if global_position.distance_to(target_enemy.global_position) <= effective_range:
			weapon.attack(target_enemy.global_position)

func get_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("Enemy")
	var nearest = null
	var min_dist = 99999.0
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy
	return nearest

func _on_health_component_died():
	print("Player Died!")
	EventBus.game_over.emit()

func _on_hurtbox_component_hit(damage: float):
	EventBus.player_damaged.emit(damage)
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)

func _draw():
	# 绘制攻击距离（以第一把武器为准进行可视化，或者你可以绘制所有武器范围）
	if weapons.size() > 0:
		var attack_r = weapons[0].get_effective_range()
		draw_arc(Vector2.ZERO, attack_r, 0, TAU, 64, Color(1, 0, 0, 0.1), 1.0)
