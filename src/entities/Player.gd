extends CharacterBody2D
class_name Player

const MOVE_SPEED := 250.0

var can_slash := true

@export var slash_time: float = 0.2
@export var sword_return_time: float = 0.5
@export var weapon_damage: float = 10.0
@export var debug_attack_visual: bool = true

@onready var health_component: HealthComponent = get_node_or_null("HealthComponent")
@onready var sword_pivot: Node2D = $Sprite2D/SwordPivot
@onready var sword_anim: AnimationPlayer = $Sprite2D/SwordPivot/sword/AnimationPlayer
@onready var sword_hitbox: Area2D = $Sprite2D/SwordPivot/sword/SwordHitbox
@onready var sword_hitbox_shape: CollisionShape2D = $Sprite2D/SwordPivot/sword/SwordHitbox/CollisionShape2D

var slash_hit_targets: Dictionary = {}
var health_bar: ProgressBar
var target_enemy: Node2D
var locked_target: Node2D

func _ready() -> void:
	add_to_group("Player")
	_setup_health_bar()
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(_on_died)
		_on_health_changed(health_component.current_health, health_component.max_health)
	if sword_anim:
		sword_anim.animation_finished.connect(_on_animation_player_animation_finished)
	if sword_hitbox:
		sword_hitbox.monitoring = false
		sword_hitbox.body_entered.connect(_on_sword_hitbox_body_entered)
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
	velocity = input_dir * MOVE_SPEED
	move_and_slide()

	if can_slash or not (locked_target and is_instance_valid(locked_target)):
		locked_target = _get_nearest_enemy()
	target_enemy = locked_target
	if target_enemy and is_instance_valid(target_enemy):
		var dist: float = global_position.distance_to(target_enemy.global_position)
		var attack_range: float = _get_attack_trigger_range()
		var target_radius: float = _get_target_trigger_radius(target_enemy)

		if dist <= attack_range + target_radius:
			if sword_pivot:
				sword_pivot.look_at(target_enemy.global_position)
			if can_slash:
				slash_hit_targets.clear()
				if sword_hitbox:
					sword_hitbox.monitoring = true
				sword_anim.speed_scale = sword_anim.get_animation("slash").length / slash_time
				sword_anim.play("slash")
				can_slash = false

	if sword_hitbox and sword_hitbox.monitoring:
		for body in sword_hitbox.get_overlapping_bodies():
			_apply_slash_hit(body)
	queue_redraw()

func _draw() -> void:
	if not debug_attack_visual:
		return
	var attack_range: float = _get_attack_trigger_range()
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
	var range_bonus: float = 0.0
	if get_node_or_null("/root/GameManager"):
		var ranged_bonus: float = GameManager.current_stats.get("attack_range", 600.0) - 600.0
		range_bonus = ranged_bonus * 0.5
	return center_dist + hitbox_radius + range_bonus

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
		body.take_damage(weapon_damage)

func take_damage(amount: float) -> void:
	if health_component:
		health_component.damage(amount)
	if get_node_or_null("/root/EventBus"):
		EventBus.player_damaged.emit(amount)

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
		sword_anim.speed_scale = sword_anim.get_animation("sword_return").length / sword_return_time
		sword_anim.play("sword_return")
	else:
		can_slash = true
		locked_target = null
