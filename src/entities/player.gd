extends CharacterBody2D
class_name Player

const MOVE_SPEED := 250.0
const SWORD_TEXTURE = preload("res://assets/textures/weapons/weapon_sword.png")
const BLADE_TEXTURE = preload("res://assets/textures/weapons/weapon_blade.png")
const SPEAR_TEXTURE = preload("res://assets/textures/weapons/weapon_spear.png")
const MUSKET_TEXTURE = preload("res://assets/textures/weapons/weapon_flute.png")
const PROJECTILE_SCENE = preload("res://scenes/entities/projectiles/bullet.tscn")

var can_slash := true

@export var slash_time: float = 0.2
@export var sword_return_time: float = 0.5
@export var weapon_damage: float = 10.0
@export var debug_attack_visual: bool = true
var uses_ranged_weapon := false
var ranged_attack_timer := 0.0
var ranged_attack_range := 760.0
var ranged_cooldown := 0.8
var melee_range_multiplier := 1.0
var regeneration_timer := 0.0

@onready var health_component: HealthComponent = get_node_or_null("HealthComponent")
@onready var hurtbox_component: HurtboxComponent = get_node_or_null("HurtboxComponent")
@onready var sword_pivot: Node2D = $Sprite2D/SwordPivot
@onready var sword_anim: AnimationPlayer = $Sprite2D/SwordPivot/sword/AnimationPlayer
@onready var sword_sprite: Sprite2D = $Sprite2D/SwordPivot/sword
@onready var sword_hitbox: Area2D = $Sprite2D/SwordPivot/sword/SwordHitbox
@onready var sword_hitbox_shape: CollisionShape2D = $Sprite2D/SwordPivot/sword/SwordHitbox/CollisionShape2D

var slash_hit_targets: Dictionary = {}
var health_bar: ProgressBar
var target_enemy: Node2D
var locked_target: Node2D
var sword_base_position: Vector2
var swing_extension_dir_local: Vector2 = Vector2.ZERO
var swing_extension_amount: float = 0.0

func _ready() -> void:
	add_to_group("Player")
	_apply_starting_weapon()
	_setup_health_bar()
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(_on_died)
		apply_runtime_stats(GameManager.current_stats)
		_on_health_changed(health_component.current_health, health_component.max_health)
	if sword_anim and not sword_anim.animation_finished.is_connected(_on_animation_player_animation_finished):
		sword_anim.animation_finished.connect(_on_animation_player_animation_finished)
	if sword_hitbox:
		sword_hitbox.monitoring = false
		sword_hitbox.body_entered.connect(_on_sword_hitbox_body_entered)
	if sword_sprite:
		sword_base_position = sword_sprite.position
	$Sprite2D/SwordPivot/sword.show_behind_parent = false

func _setup_health_bar() -> void:
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(56, 6)
	health_bar.position = Vector2(-28, -48)
	health_bar.z_index = 10
	add_child(health_bar)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	health_bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.2, 0.2, 1.0)
	health_bar.add_theme_stylebox_override("fill", fill)

func _on_health_changed(new_health: float, max_health: float) -> void:
	if not health_bar:
		return
	health_bar.max_value = max_health
	health_bar.value = new_health

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_speed_multiplier: float = maxf(1.0 + float(GameManager.current_stats.get("move_speed", 0.0)) / 100.0, 0.0)
	velocity = input_dir * MOVE_SPEED * move_speed_multiplier
	move_and_slide()
	_process_regeneration(delta)

	if uses_ranged_weapon:
		_process_ranged_attack(delta)
		queue_redraw()
		return

	if can_slash or not (locked_target and is_instance_valid(locked_target)):
		locked_target = _get_nearest_enemy()
	target_enemy = locked_target
	if target_enemy and is_instance_valid(target_enemy):
		var dist: float = global_position.distance_to(target_enemy.global_position)
		var attack_range: float = _get_attack_trigger_range() + _get_melee_range_bonus()
		var target_radius: float = _get_target_trigger_radius(target_enemy)

		if dist <= attack_range + target_radius:
			if sword_pivot:
				sword_pivot.look_at(target_enemy.global_position)
			if can_slash:
				slash_hit_targets.clear()
				_prepare_sword_range_extension()
				if sword_hitbox:
					sword_hitbox.monitoring = true
				sword_anim.speed_scale = sword_anim.get_animation("slash").length / _get_attack_duration(slash_time)
				sword_anim.play("slash")
				can_slash = false

	_update_sword_extension_visual()
	if sword_hitbox and sword_hitbox.monitoring:
		for body in sword_hitbox.get_overlapping_bodies():
			_apply_slash_hit(body)
	queue_redraw()

func _apply_starting_weapon() -> void:
	uses_ranged_weapon = false
	sword_sprite.visible = true
	sword_sprite.scale = Vector2.ONE
	sword_sprite.texture = SWORD_TEXTURE
	weapon_damage = 10.0
	slash_time = 0.2
	sword_return_time = 0.5
	melee_range_multiplier = 1.0

	match GameManager.selected_weapon_id:
		"blade":
			sword_sprite.texture = BLADE_TEXTURE
			weapon_damage = 15.0
			slash_time = 0.17
			sword_return_time = 0.42
			melee_range_multiplier = 0.9
		"spear":
			sword_sprite.texture = SPEAR_TEXTURE
			weapon_damage = 22.0
			slash_time = 0.24
			sword_return_time = 0.55
			melee_range_multiplier = 1.25
		"musket":
			sword_sprite.texture = MUSKET_TEXTURE
			sword_sprite.scale = Vector2(0.85, 0.85)
			weapon_damage = 16.0
			uses_ranged_weapon = true
			ranged_attack_range = 760.0
			ranged_cooldown = 0.8

func _process_ranged_attack(delta: float) -> void:
	ranged_attack_timer = max(ranged_attack_timer - delta, 0.0)
	target_enemy = _get_nearest_enemy()
	if not target_enemy or not is_instance_valid(target_enemy):
		return

	var distance_to_target := global_position.distance_to(target_enemy.global_position)
	if distance_to_target > ranged_attack_range:
		return

	if sword_pivot:
		sword_pivot.look_at(target_enemy.global_position)
	if ranged_attack_timer <= 0.0:
		_fire_ranged_projectile(target_enemy)
		var attack_speed_multiplier := _get_attack_speed_multiplier()
		ranged_attack_timer = ranged_cooldown / attack_speed_multiplier

func _fire_ranged_projectile(target: Node2D) -> void:
	var damage_multiplier: float = 1.0 + GameManager.current_stats.get("damage_pct", 0.0) / 100.0
	var projectile_count: int = maxi(int(GameManager.current_stats.get("bullet_count", 1)), 1)
	var target_angle := global_position.direction_to(target.global_position).angle()
	var spread_step := deg_to_rad(8.0)

	for index in range(projectile_count):
		var projectile = PROJECTILE_SCENE.instantiate()
		var spread_offset := (float(index) - float(projectile_count - 1) / 2.0) * spread_step
		projectile.damage = weapon_damage * damage_multiplier
		projectile.speed = 680.0
		projectile.color = Color("f3b85d")
		projectile.global_position = global_position
		projectile.rotation = target_angle + spread_offset
		get_tree().root.add_child(projectile)

func apply_runtime_stats(stats: Dictionary) -> void:
	if health_component:
		var target_max_health := maxf(float(stats.get("max_health", health_component.max_health)), 1.0)
		var previous_max_health := maxf(health_component.max_health, 1.0)
		var health_ratio := clampf(health_component.current_health / previous_max_health, 0.0, 1.0)
		var max_health_changed := not is_equal_approx(previous_max_health, target_max_health)
		health_component.max_health = target_max_health
		if max_health_changed:
			health_component.current_health = target_max_health * health_ratio
		if max_health_changed:
			health_component.health_changed.emit(health_component.current_health, target_max_health)

	if hurtbox_component:
		hurtbox_component.flat_damage_reduction = maxf(float(stats.get("armor", 0.0)), 0.0)

func _process_regeneration(delta: float) -> void:
	if not health_component:
		return
	var regeneration_per_five_seconds: float = maxf(float(GameManager.current_stats.get("hp_regen_5s", 0.0)), 0.0)
	if regeneration_per_five_seconds <= 0.0:
		regeneration_timer = 0.0
		return

	regeneration_timer += delta
	if regeneration_timer < 5.0:
		return
	var regeneration_ticks := floori(regeneration_timer / 5.0)
	regeneration_timer -= float(regeneration_ticks) * 5.0
	health_component.heal(regeneration_per_five_seconds * regeneration_ticks)

func _get_attack_speed_multiplier() -> float:
	return maxf(1.0 + float(GameManager.current_stats.get("attack_speed", 0.0)) / 100.0, 0.1)

func _get_attack_duration(base_duration: float) -> float:
	return base_duration / _get_attack_speed_multiplier()

func _draw() -> void:
	if not debug_attack_visual:
		return
	var attack_range: float = _get_attack_trigger_range()
	if not uses_ranged_weapon:
		attack_range += _get_melee_range_bonus()
	draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 64, Color(0.3, 0.8, 1.0, 0.8), 2.0)
	if target_enemy and is_instance_valid(target_enemy):
		var enemy_local: Vector2 = to_local(target_enemy.global_position)
		var dist: float = global_position.distance_to(target_enemy.global_position)
		var target_radius: float = _get_target_trigger_radius(target_enemy)
		var can_trigger: bool = dist <= attack_range + target_radius
		var line_color: Color = Color(0.2, 1.0, 0.4, 0.9) if can_trigger else Color(1.0, 0.35, 0.35, 0.9)
		draw_line(Vector2.ZERO, enemy_local, line_color, 2.0)
		draw_arc(enemy_local, target_radius, 0.0, TAU, 64, Color(1.0, 0.75, 0.2, 0.8), 2.0)

func _get_nearest_enemy() -> Node2D:
	var enemies: Array = get_tree().get_nodes_in_group("DamageableEnemy")
	var nearest: Node2D = null
	var min_dist := INF
	for enemy in enemies:
		if not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy as Node2D
		var d: float = global_position.distance_to(enemy_node.global_position)
		if d < min_dist:
			min_dist = d
			nearest = enemy_node
	return nearest

func _get_attack_trigger_range() -> float:
	if uses_ranged_weapon:
		return ranged_attack_range
	if not sword_hitbox:
		return 80.0
	var center_dist: float = global_position.distance_to(sword_hitbox.global_position)
	var hitbox_radius: float = 0.0
	if sword_hitbox_shape and sword_hitbox_shape.shape:
		var shape: Shape2D = sword_hitbox_shape.shape
		if shape is RectangleShape2D:
			var rect: RectangleShape2D = shape as RectangleShape2D
			var local_radius: float = rect.size.length() * 0.5
			var scale_factor: float = max(abs(sword_hitbox_shape.global_scale.x), abs(sword_hitbox_shape.global_scale.y))
			hitbox_radius = local_radius * scale_factor
		elif shape is CircleShape2D:
			var circle: CircleShape2D = shape as CircleShape2D
			var c_scale: float = max(abs(sword_hitbox_shape.global_scale.x), abs(sword_hitbox_shape.global_scale.y))
			hitbox_radius = circle.radius * c_scale
		else:
			hitbox_radius = 24.0
	return (center_dist + hitbox_radius) * melee_range_multiplier

func _get_melee_range_bonus() -> float:
	if not get_node_or_null("/root/GameManager"):
		return 0.0
	var ranged_bonus: float = GameManager.current_stats.get("attack_range", 600.0) - 600.0
	return max(ranged_bonus * 0.5, 0.0)

func _prepare_sword_range_extension() -> void:
	if not sword_sprite or not sword_pivot:
		return
	var bonus: float = _get_melee_range_bonus()
	if bonus <= 0.0:
		swing_extension_amount = 0.0
		swing_extension_dir_local = Vector2.ZERO
		sword_sprite.position = sword_base_position
		return
	var target_dir_global: Vector2 = Vector2.RIGHT
	if locked_target and is_instance_valid(locked_target):
		target_dir_global = (locked_target.global_position - global_position).normalized()
	swing_extension_dir_local = sword_pivot.global_transform.basis_xform_inv(target_dir_global).normalized()
	swing_extension_amount = bonus

func _update_sword_extension_visual() -> void:
	if not sword_sprite or not sword_anim:
		return
	var t: float = 0.0
	if sword_anim.current_animation == &"slash":
		var slash_anim: Animation = sword_anim.get_animation("slash")
		var slash_anim_len: float = slash_anim.length if slash_anim else 0.0
		if slash_anim_len > 0.0:
			var p: float = clamp(sword_anim.current_animation_position / slash_anim_len, 0.0, 1.0)
			if p <= 0.5:
				t = p * 2.0
			else:
				t = (1.0 - p) * 2.0
	sword_sprite.position = sword_base_position + swing_extension_dir_local * swing_extension_amount * t

func _get_target_trigger_radius(target: Node2D) -> float:
	var max_radius: float = 0.0
	var shapes: Array[Node] = target.find_children("*", "CollisionShape2D", true, false)
	for node in shapes:
		var cs: CollisionShape2D = node as CollisionShape2D
		if not cs or not cs.shape or cs.disabled:
			continue
		var local_radius: float = 0.0
		var shape: Shape2D = cs.shape
		if shape is CircleShape2D:
			local_radius = (shape as CircleShape2D).radius
		elif shape is RectangleShape2D:
			local_radius = (shape as RectangleShape2D).size.length() * 0.5
		else:
			continue
		var scale_factor: float = max(abs(cs.global_scale.x), abs(cs.global_scale.y))
		var world_radius: float = cs.global_position.distance_to(target.global_position) + local_radius * scale_factor
		if world_radius > max_radius:
			max_radius = world_radius
	return max_radius

func spawn_slash() -> void:
	pass

func _on_sword_hitbox_body_entered(body: Node2D) -> void:
	_apply_slash_hit(body)

func _apply_slash_hit(body: Node2D) -> void:
	if not sword_hitbox.monitoring:
		return
	if not body.is_in_group("DamageableEnemy"):
		return
	var body_id := body.get_instance_id()
	if slash_hit_targets.has(body_id):
		return
	slash_hit_targets[body_id] = true
	if body.has_method("take_damage"):
		var damage_multiplier: float = 1.0 + GameManager.current_stats.get("damage_pct", 0.0) / 100.0
		body.take_damage(weapon_damage * damage_multiplier)

func take_damage(amount: float) -> void:
	var final_damage := maxf(amount - float(GameManager.current_stats.get("armor", 0.0)), 0.0)
	if health_component:
		health_component.damage(final_damage)
	if get_node_or_null("/root/EventBus"):
		EventBus.player_damaged.emit(final_damage)

func _on_hurtbox_component_hit(damage: float) -> void:
	if get_node_or_null("/root/EventBus"):
		EventBus.player_damaged.emit(damage)

func _on_died() -> void:
	print("Player Died!")
	if get_node_or_null("/root/EventBus"):
		EventBus.game_over.emit()
	queue_free()

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "slash":
		if sword_hitbox:
			sword_hitbox.monitoring = false
		sword_anim.speed_scale = sword_anim.get_animation("sword_return").length / _get_attack_duration(sword_return_time)
		sword_anim.play("sword_return")
	else:
		can_slash = true
		locked_target = null
		if sword_sprite:
			sword_sprite.position = sword_base_position
		swing_extension_amount = 0.0
		swing_extension_dir_local = Vector2.ZERO
