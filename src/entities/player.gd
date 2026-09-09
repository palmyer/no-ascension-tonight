extends CharacterBody2D
class_name Player

const MOVE_SPEED := 250.0
const SWORD_TEXTURE = preload("res://assets/textures/weapons/sword_48.png")
const BLADE_TEXTURE = preload("res://assets/textures/weapons/sword_48.png")
const SPEAR_TEXTURE = preload("res://assets/textures/weapons/sword_48.png")
const MUSKET_TEXTURE = preload("res://assets/textures/weapons/sword_48.png")
const PROJECTILE_SCENE = preload("res://scenes/entities/projectiles/bullet.tscn")
const SKILL_BURST_VISUAL = preload("res://src/effects/skill_burst_visual.gd")
const BASE_ATTACK_RANGE := 1600.0

var can_slash := true
var touch_move_vector := Vector2.ZERO

@export var slash_time: float = 0.2
@export var sword_return_time: float = 0.5
@export var weapon_damage: float = 10.0
@export var debug_attack_visual: bool = false
var uses_ranged_weapon := false
var ranged_attack_timer := 0.0
var ranged_attack_range := 760.0
var ranged_cooldown := 0.8
var melee_range_multiplier := 1.0
var regeneration_timer := 0.0
var special_cooldown_remaining: float = 0.0
var slash_count: int = 0
var current_slash_is_sweep: bool = false
var current_attack_charged: bool = false
var current_attack_momentum: bool = false
var movement_since_attack: float = 0.0
var current_attack_afterimage: bool = false
var current_afterimage_position: Vector2 = Vector2.ZERO
var afterimage_anchor_position: Vector2 = Vector2.ZERO
var afterimage_anchor_ready: bool = false
var afterimage_triggered: bool = false
var temporary_shield: float = 0.0
var shield_retaliation: float = 0.0
var shield_breaking: bool = false
var kill_streak: int = 0
var kill_streak_timer: float = 0.0
var blade_combo_target_id: int = -1
var blade_combo_count: int = 0
var blade_combo_timer: float = 0.0
var ranged_shot_count: int = 0

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
	special_cooldown_remaining = maxf(special_cooldown_remaining - delta, 0.0)
	movement_since_attack += velocity.length() * delta
	kill_streak_timer = maxf(kill_streak_timer - delta, 0.0)
	if kill_streak_timer <= 0.0:
		kill_streak = 0
	if GameManager.has_upgrade("afterimage") and not afterimage_anchor_ready and movement_since_attack >= GameManager.get_upgrade_modifier_or_default("afterimage_distance", 260.0):
		afterimage_anchor_position = global_position
		afterimage_anchor_ready = true
	blade_combo_timer = maxf(blade_combo_timer - delta, 0.0)
	if blade_combo_timer <= 0.0:
		blade_combo_target_id = -1
		blade_combo_count = 0
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir == Vector2.ZERO and touch_move_vector.length_squared() > 0.01:
		input_dir = touch_move_vector
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
				slash_count += 1
				current_slash_is_sweep = GameManager.has_upgrade("sword_sweep") and slash_count % maxi(int(GameManager.get_upgrade_modifier("sword_sweep_interval", 3.0)), 1) == 0
				current_attack_charged = GameManager.selected_weapon_id == "spear" and GameManager.has_upgrade("spear_pierce") and movement_since_attack >= 180.0
				current_attack_momentum = GameManager.has_upgrade("momentum_edge") and movement_since_attack >= GameManager.get_upgrade_modifier_or_default("momentum_distance", 220.0)
				current_attack_afterimage = GameManager.has_upgrade("afterimage") and afterimage_anchor_ready
				current_afterimage_position = afterimage_anchor_position
				afterimage_triggered = false
				afterimage_anchor_ready = false
				movement_since_attack = 0.0
				_prepare_sword_range_extension()
				if sword_hitbox:
					sword_hitbox.monitoring = true
				sword_anim.speed_scale = sword_anim.get_animation("slash").length / _get_attack_duration(slash_time)
				sword_anim.play("slash")
				can_slash = false

	_update_sword_extension_visual()
	if sword_hitbox and sword_hitbox.monitoring:
		if current_slash_is_sweep:
			for body in get_tree().get_nodes_in_group("DamageableEnemy"):
				if is_instance_valid(body) and body is Node2D and global_position.distance_to(body.global_position) <= _get_attack_trigger_range() + _get_target_trigger_radius(body):
					_apply_slash_hit(body)
		else:
			for body in sword_hitbox.get_overlapping_bodies():
				_apply_slash_hit(body)
	queue_redraw()

func set_touch_move_vector(value: Vector2) -> void:
	touch_move_vector = value.limit_length(1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("special") and not get_tree().paused:
		try_special()

func get_special_profile() -> Dictionary:
	match GameManager.selected_weapon_id:
		"blade":
			return {
				"name": "腐心散",
				"description": "近身毒爆，命中后回复少量生命。",
				"damage": 24.0,
				"radius": 230.0,
				"cooldown": 8.5,
				"color": Color("65c579"),
				"payload": {"poison": 3, "vine": 1},
				"knockback": 55.0,
				"heal_per_hit": 4.0
			}
		"spear":
			return {
				"name": "霜锋震",
				"description": "大范围冰震，冻结并击退周围妖物。",
				"damage": 46.0,
				"radius": 250.0,
				"cooldown": 10.0,
				"color": Color("76c8e8"),
				"payload": {"water": 2, "ice": 3},
				"knockback": 120.0
			}
		"musket":
			return {
				"name": "天雷引",
				"description": "锁定远处五名目标，雷链在敌群间跳跃。",
				"damage": 34.0,
				"radius": 900.0,
				"cooldown": 9.0,
				"color": Color("e4d15e"),
				"payload": {"water": 2, "thunder": 3},
				"max_targets": 5,
				"chain": true
			}
		_:
			return {
				"name": "赤焰回环",
				"description": "引爆身边火印，灼烧并击退一圈妖物。",
				"damage": 38.0,
				"radius": 200.0,
				"cooldown": 8.0,
				"color": Color("ee8556"),
				"payload": {"fire": 3, "blast": 2},
				"knockback": 95.0
			}

func get_special_cooldown() -> float:
	var profile := get_special_profile()
	return maxf(float(profile.get("cooldown", 8.0)) / (1.0 + float(GameManager.current_stats.get("attack_speed", 0.0)) / 250.0), 2.5)

func get_special_cooldown_remaining() -> float:
	return special_cooldown_remaining

func get_weapon_status_lines() -> Array[String]:
	var lines: Array[String] = []
	match GameManager.selected_weapon_id:
		"sword":
			if GameManager.has_upgrade("sword_sweep"):
				var interval := maxi(int(GameManager.get_upgrade_modifier("sword_sweep_interval", 3.0)), 1)
				if current_slash_is_sweep:
					lines.append("回风斩：横扫!")
				else:
					lines.append("回风斩：%d/%d" % [slash_count % interval, interval])
			if GameManager.has_upgrade("sword_burn_trail"):
				lines.append("焚痕：命中留火")
		"blade":
			if GameManager.has_upgrade("blade_combo"):
				var max_stacks := maxi(int(GameManager.get_upgrade_modifier("blade_combo_max_stacks", 5.0)), 1)
				if blade_combo_count > 0 and blade_combo_timer > 0.0:
					lines.append("连刃：%d/%d" % [blade_combo_count, max_stacks])
				else:
					lines.append("连刃：待命")
			if GameManager.has_upgrade("blade_poison_cloud"):
				lines.append("毒爆：死亡留雾")
		"spear":
			if GameManager.has_upgrade("spear_pierce"):
				if current_attack_charged:
					lines.append("贯阵：READY")
				else:
					var charge_ratio := clampf(movement_since_attack / 180.0, 0.0, 1.0)
					lines.append("贯阵：%d%%" % int(charge_ratio * 100.0))
			if GameManager.has_upgrade("spear_shatter"):
				lines.append("碎冰：冻结追加")
		"musket":
			if GameManager.has_upgrade("musket_charge"):
				var interval := maxi(int(GameManager.get_upgrade_modifier("musket_charge_interval", 5.0)), 1)
				lines.append("雷符：%d/%d" % [ranged_shot_count % interval, interval])
			if GameManager.has_upgrade("musket_aura"):
				lines.append("守线：生效" if GameManager.player_in_aura else "守线：待入阵")
	return lines

func try_special() -> void:
	if special_cooldown_remaining > 0.0 or not GameManager.game_started:
		return
	var profile := get_special_profile()
	var radius := float(profile.get("radius", 180.0)) + GameManager.get_upgrade_modifier("special_radius_bonus")
	var max_targets := int(profile.get("max_targets", -1))
	var candidates: Array = []
	for enemy in get_tree().get_nodes_in_group("DamageableEnemy"):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if global_position.distance_to(enemy.global_position) <= radius:
			candidates.append(enemy)

	var targets: Array = []
	if max_targets < 0:
		targets = candidates
	else:
		var remaining := candidates.duplicate()
		for _index in range(mini(max_targets, remaining.size())):
			var nearest: Node2D = null
			var nearest_distance := INF
			for candidate in remaining:
				if not is_instance_valid(candidate):
					continue
				var candidate_distance := global_position.distance_to(candidate.global_position)
				if candidate_distance < nearest_distance:
					nearest_distance = candidate_distance
					nearest = candidate
			if nearest:
				targets.append(nearest)
				remaining.erase(nearest)

	var revenge_bonus := GameManager.consume_core_revenge_bonus()
	var attack_damage := float(profile.get("damage", 20.0)) * _get_damage_multiplier() * (1.0 + revenge_bonus)
	attack_damage += GameManager.consume_transmute_charge(global_position)
	var target_positions: Array = []
	var hit_count := 0
	for enemy in targets:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(attack_damage)
		if enemy.has_method("apply_attribute_payload"):
			var payload: Dictionary = profile.get("payload", {})
			enemy.apply_attribute_payload(payload, attack_damage, global_position)
			if enemy.has_method("add_fracture"):
				enemy.add_fracture(attack_damage)
			GameManager.register_attribute_overload(payload, enemy.global_position, attack_damage)
		var knockback := float(profile.get("knockback", 0.0))
		if knockback > 0.0 and enemy is Node2D:
			var direction := global_position.direction_to(enemy.global_position)
			if direction == Vector2.ZERO:
				direction = Vector2.RIGHT
			enemy.global_position += direction * knockback
		if float(profile.get("heal_per_hit", 0.0)) > 0.0 and health_component:
			health_component.heal(float(profile.get("heal_per_hit", 0.0)))
		target_positions.append(to_local(enemy.global_position))
		hit_count += 1

	if hit_count >= 3 and GameManager.has_upgrade("special_aftershock"):
		GameManager.spawn_damage_zone(global_position, GameManager.get_upgrade_modifier("special_aftershock_radius", 140.0), 2.5, attack_damage * GameManager.get_upgrade_modifier("special_aftershock_damage_pct", 0.25), {}, profile.get("color", Color.WHITE))
	if GameManager.player_in_aura:
		var repair_amount := GameManager.try_special_core_repair()
		if repair_amount > 0.0:
			var core := get_tree().get_first_node_in_group("LifeCore")
			if core and core.has_method("repair"):
				core.repair(repair_amount)

	special_cooldown_remaining = get_special_cooldown()
	_spawn_special_visual(radius, profile.get("color", Color.WHITE), target_positions)
	EventBus.special_used.emit(str(profile.get("name", "秘术")), hit_count)

func _spawn_special_visual(radius: float, color: Color, target_positions: Array) -> void:
	var visual := SKILL_BURST_VISUAL.new()
	visual.global_position = global_position
	visual.configure(radius, color, target_positions)
	var host := get_tree().current_scene
	if not host:
		host = get_tree().root
	host.add_child(visual)

func _apply_starting_weapon() -> void:
	uses_ranged_weapon = false
	sword_sprite.visible = true
	# The menu art is high resolution; normalize every weapon to a readable
	# combat silhouette instead of letting source image dimensions determine
	# the in-game scale.
	sword_sprite.scale = Vector2(1.05, 1.05)
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
			sword_sprite.scale = Vector2(1.05, 1.05)
			weapon_damage = 22.0
			slash_time = 0.24
			sword_return_time = 0.55
			melee_range_multiplier = 1.25
		"musket":
			sword_sprite.texture = MUSKET_TEXTURE
			sword_sprite.scale = Vector2(0.9, 0.9)
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
	if distance_to_target > _get_ranged_attack_range():
		return

	if sword_pivot:
		sword_pivot.look_at(target_enemy.global_position)
	if ranged_attack_timer <= 0.0:
		_fire_ranged_projectile(target_enemy)
		var attack_speed_multiplier := _get_attack_speed_multiplier()
		ranged_attack_timer = ranged_cooldown / attack_speed_multiplier

func _fire_ranged_projectile(target: Node2D) -> void:
	var damage_multiplier := _get_damage_multiplier()
	var projectile_count: int = maxi(int(GameManager.current_stats.get("bullet_count", 1)), 1)
	var target_angle := global_position.direction_to(target.global_position).angle()
	var spread_step := deg_to_rad(8.0)
	ranged_shot_count += 1
	if GameManager.has_upgrade("afterimage") and not afterimage_anchor_ready and movement_since_attack >= GameManager.get_upgrade_modifier_or_default("afterimage_distance", 260.0):
		afterimage_anchor_position = global_position
		afterimage_anchor_ready = true
	var ranged_afterimage_ready := GameManager.has_upgrade("afterimage") and afterimage_anchor_ready
	var ranged_afterimage_position := afterimage_anchor_position
	afterimage_anchor_ready = false
	var momentum_multiplier := 1.0
	if GameManager.has_upgrade("momentum_edge") and movement_since_attack >= GameManager.get_upgrade_modifier_or_default("momentum_distance", 220.0):
		momentum_multiplier += GameManager.get_upgrade_modifier("momentum_damage_pct")
		movement_since_attack = 0.0
	if ranged_afterimage_ready:
		movement_since_attack = 0.0
	var boss_multiplier := 1.0
	if target.is_in_group("Boss"):
		boss_multiplier += GameManager.get_upgrade_modifier("boss_damage_pct") / 100.0
	var charge_interval := maxi(int(GameManager.get_upgrade_modifier("musket_charge_interval", 5.0)), 1)
	var charged_shot := GameManager.has_upgrade("musket_charge") and ranged_shot_count % charge_interval == 0
	var transmute_bonus := GameManager.consume_transmute_charge(target.global_position)

	for index in range(projectile_count):
		var projectile = PROJECTILE_SCENE.instantiate()
		var spread_offset := (float(index) - float(projectile_count - 1) / 2.0) * spread_step
		var charged_damage_multiplier := 1.0 + GameManager.get_upgrade_modifier("musket_charge_damage_pct") if charged_shot else 1.0
		projectile.damage = (weapon_damage * damage_multiplier + transmute_bonus if index == 0 else weapon_damage * damage_multiplier) * charged_damage_multiplier * momentum_multiplier * boss_multiplier
		projectile.speed = 680.0
		projectile.color = Color("e8e067") if charged_shot else Color("f3b85d")
		projectile.piercing = charged_shot
		projectile.max_hits = maxi(int(GameManager.get_upgrade_modifier("musket_charge_pierce_count", 3.0)), 1) if charged_shot else 1
		projectile.attribute_payload = GameManager.get_attack_attribute_payload().duplicate(true)
		var projectile_hitbox: HitboxComponent = projectile.get_node("HitboxComponent")
		projectile_hitbox.critical_chance = clampf(GameManager.get_upgrade_modifier("critical_chance"), 0.0, 1.0)
		projectile_hitbox.critical_multiplier = GameManager.get_upgrade_modifier("critical_multiplier", 1.5)
		projectile_hitbox.critical_explosion_radius = GameManager.get_upgrade_modifier("critical_explosion_radius")
		projectile_hitbox.critical_explosion_damage_pct = GameManager.get_upgrade_modifier("critical_explosion_damage_pct")
		projectile_hitbox.critical_color = Color("f6c857")
		projectile.return_enabled = GameManager.has_upgrade("returning_edge")
		projectile.return_damage_multiplier = GameManager.get_upgrade_modifier_or_default("return_projectile_damage_pct", 0.65) + GameManager.get_upgrade_modifier("return_projectile_damage_bonus_pct")
		projectile.return_pierce_count = maxi(int(GameManager.get_upgrade_modifier_or_default("return_projectile_pierce_count", 1.0)), 1)
		projectile.return_speed = GameManager.get_upgrade_modifier_or_default("return_projectile_speed", 820.0)
		projectile.global_position = global_position
		projectile.rotation = target_angle + spread_offset
		get_tree().root.add_child(projectile)
	if ranged_afterimage_ready:
		GameManager.spawn_afterimage_attack(ranged_afterimage_position, weapon_damage * damage_multiplier, GameManager.get_attack_attribute_payload(), Color("b797e8"))

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
		hurtbox_component.low_health_damage_reduction = maxf(float(stats.get("low_health_damage_reduction", 0.0)), 0.0)

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

func _get_damage_multiplier() -> float:
	var damage_pct: float = float(GameManager.current_stats.get("damage_pct", 0.0))
	if not GameManager.player_in_aura:
		damage_pct += float(GameManager.current_stats.get("outside_aura_damage_pct", 0.0))
	if GameManager.selected_weapon_id == "musket" and GameManager.player_in_aura:
		damage_pct += GameManager.get_upgrade_modifier("musket_aura_damage_pct") * 100.0
	if GameManager.has_upgrade("attribute_shift") and GameManager.get_active_attribute_ids().size() >= 2:
		damage_pct += GameManager.get_upgrade_modifier("attribute_shift_damage_pct") * 100.0
	if health_component and GameManager.has_upgrade("low_health_frenzy"):
		var health_ratio := health_component.current_health / maxf(health_component.max_health, 1.0)
		if health_ratio <= GameManager.get_upgrade_modifier("low_health_threshold", 0.35):
			damage_pct += GameManager.get_upgrade_modifier("low_health_damage_pct")
	return maxf(1.0 + damage_pct / 100.0, 0.0)

func _get_ranged_attack_range() -> float:
	var range_bonus := maxf(float(GameManager.current_stats.get("attack_range", BASE_ATTACK_RANGE)) - BASE_ATTACK_RANGE, 0.0)
	return ranged_attack_range + range_bonus

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
		return _get_ranged_attack_range()
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
	var ranged_bonus: float = GameManager.current_stats.get("attack_range", BASE_ATTACK_RANGE) - BASE_ATTACK_RANGE
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

func _apply_slash_hit(body: Node2D, allow_weapon_chain: bool = true, damage_scale: float = 1.0) -> void:
	if not sword_hitbox.monitoring:
		return
	if not body.is_in_group("DamageableEnemy"):
		return
	var body_id := body.get_instance_id()
	if slash_hit_targets.has(body_id):
		return
	slash_hit_targets[body_id] = true
	if body.has_method("take_damage"):
		var attack_damage := weapon_damage * _get_damage_multiplier()
		attack_damage += GameManager.consume_transmute_charge(body.global_position)
		if current_slash_is_sweep:
			attack_damage *= clampf(GameManager.get_upgrade_modifier("sword_sweep_damage_pct", 0.75), 0.1, 1.5)
		if GameManager.selected_weapon_id == "blade" and GameManager.has_upgrade("blade_combo"):
			var target_id := body.get_instance_id()
			var combo_window := GameManager.get_upgrade_modifier("blade_combo_window", 1.2)
			if blade_combo_target_id == target_id and blade_combo_timer > 0.0:
				blade_combo_count = mini(blade_combo_count + 1, maxi(int(GameManager.get_upgrade_modifier("blade_combo_max_stacks", 5.0)), 1))
			else:
				blade_combo_target_id = target_id
				blade_combo_count = 1
			blade_combo_timer = combo_window
			attack_damage *= 1.0 + float(blade_combo_count) * GameManager.get_upgrade_modifier("blade_combo_damage_pct", 0.06)
		if current_attack_charged and GameManager.selected_weapon_id == "spear":
			attack_damage *= 1.15
		if current_attack_momentum:
			attack_damage *= 1.0 + GameManager.get_upgrade_modifier("momentum_damage_pct")
		if body.is_in_group("Boss"):
			attack_damage *= 1.0 + GameManager.get_upgrade_modifier("boss_damage_pct") / 100.0
		attack_damage *= damage_scale
		var resolved_damage := GameManager.resolve_player_attack_damage(attack_damage, body.global_position, Color("f6c857"))
		attack_damage = float(resolved_damage.get("damage", attack_damage))
		body.take_damage(attack_damage)
		var payload := GameManager.get_attack_attribute_payload()
		if body.has_method("apply_attribute_payload"):
			body.apply_attribute_payload(payload, attack_damage, global_position)
			if body.has_method("add_fracture"):
				body.add_fracture(attack_damage)
			GameManager.register_attribute_overload(payload, body.global_position, attack_damage)
		if current_attack_afterimage and not afterimage_triggered:
			GameManager.spawn_afterimage_attack(current_afterimage_position, attack_damage, payload, Color("b797e8"))
			afterimage_triggered = true
		if GameManager.selected_weapon_id == "sword" and GameManager.has_upgrade("sword_burn_trail"):
			GameManager.spawn_damage_zone(
				body.global_position,
				GameManager.get_upgrade_modifier("sword_burn_trail_radius", 70.0),
				GameManager.get_upgrade_modifier("sword_burn_trail_duration", 2.0),
				GameManager.get_upgrade_modifier("sword_burn_trail_damage", 12.0),
				{"fire": 1},
				Color("ee8556")
			)
		if GameManager.selected_weapon_id == "spear" and GameManager.has_upgrade("spear_shatter"):
			var attribute_status := body.get_node_or_null("AttributeStatusComponent")
			if attribute_status and attribute_status.frozen_time > 0.0:
				body.take_damage(attack_damage * GameManager.get_upgrade_modifier("spear_shatter_damage_pct", 0.8))
		if allow_weapon_chain and current_attack_charged and GameManager.selected_weapon_id == "spear":
			_apply_spear_pierce(body)

func _apply_spear_pierce(primary_target: Node2D) -> void:
	var direction := global_position.direction_to(primary_target.global_position)
	if direction == Vector2.ZERO:
		return
	var candidates: Array[Node2D] = []
	var max_distance := _get_attack_trigger_range() + 130.0
	for candidate in get_tree().get_nodes_in_group("DamageableEnemy"):
		if not is_instance_valid(candidate) or not (candidate is Node2D) or candidate == primary_target:
			continue
		var candidate_node := candidate as Node2D
		var offset := global_position.direction_to(candidate_node.global_position)
		var distance := global_position.distance_to(candidate_node.global_position)
		if distance <= 0.0 or distance > max_distance:
			continue
		if absf(direction.angle_to(offset)) > 0.7:
			continue
		candidates.append(candidate_node)

	var pierce_count := maxi(int(GameManager.get_upgrade_modifier("spear_pierce_count", 2.0)), 1)
	for _index in range(pierce_count):
		var nearest: Node2D = null
		var nearest_distance := INF
		for candidate in candidates:
			if not is_instance_valid(candidate):
				continue
			var candidate_distance := global_position.distance_to(candidate.global_position)
			if candidate_distance < nearest_distance:
				nearest_distance = candidate_distance
				nearest = candidate
		if not nearest:
			break
		_apply_slash_hit(nearest, false, GameManager.get_upgrade_modifier("spear_pierce_damage_pct", 0.65))
		candidates.erase(nearest)

func add_temporary_shield(amount: float) -> void:
	if amount <= 0.0 or not GameManager.has_upgrade("aegis_resonance"):
		return
	temporary_shield = minf(temporary_shield + amount, GameManager.get_upgrade_modifier_or_default("shield_max", 36.0))
	queue_redraw()

func refund_special_cooldown(amount: float) -> void:
	special_cooldown_remaining = maxf(special_cooldown_remaining - amount, 0.0)

func resolve_incoming_damage(amount: float) -> float:
	var remaining_damage := maxf(amount, 0.0)
	var absorbed := minf(temporary_shield, remaining_damage)
	if absorbed > 0.0:
		temporary_shield -= absorbed
		shield_retaliation += absorbed
		remaining_damage -= absorbed
	var shield_broken := absorbed > 0.0 and temporary_shield <= 0.0
	if shield_broken:
		_release_shield_burst()
	if remaining_damage > 0.0 and health_component:
		health_component.damage(remaining_damage)
	queue_redraw()
	return remaining_damage

func _release_shield_burst() -> void:
	if shield_breaking:
		return
	var stored_damage := shield_retaliation
	shield_retaliation = 0.0
	if stored_damage <= 0.0 or not GameManager.has_upgrade("shield_breaker"):
		return
	shield_breaking = true
	var burst_damage := stored_damage * GameManager.get_upgrade_modifier_or_default("shield_break_damage_pct", 0.80)
	var defeat_count := GameManager.spawn_burst_damage(
		global_position,
		GameManager.get_upgrade_modifier_or_default("shield_break_radius", 105.0),
		burst_damage,
		{},
		Color("7ed6c1")
	)
	if defeat_count > 0 and GameManager.has_upgrade("shield_revenge"):
		add_temporary_shield(defeat_count * GameManager.get_upgrade_modifier_or_default("shield_refund_per_kill", 5.0))
	shield_breaking = false

func take_damage(amount: float) -> void:
	var final_damage := maxf(amount - float(GameManager.current_stats.get("armor", 0.0)), 0.0)
	if hurtbox_component:
		final_damage = hurtbox_component.get_final_damage(amount)
	resolve_incoming_damage(final_damage)
	if get_node_or_null("/root/EventBus"):
		EventBus.player_damaged.emit(final_damage)

func _on_hurtbox_component_hit(damage: float) -> void:
	if get_node_or_null("/root/EventBus"):
		EventBus.player_damaged.emit(damage)

func register_enemy_kill(_enemy: Node2D) -> void:
	if not GameManager.has_upgrade("kill_rhythm"):
		return
	if kill_streak_timer > 0.0:
		kill_streak += 1
	else:
		kill_streak = 1
	kill_streak_timer = GameManager.get_upgrade_modifier_or_default("kill_streak_window", 2.0)
	special_cooldown_remaining = maxf(special_cooldown_remaining - GameManager.get_upgrade_modifier_or_default("kill_cooldown_refund", 0.45), 0.0)
	ranged_attack_timer = maxf(ranged_attack_timer - GameManager.get_upgrade_modifier_or_default("kill_attack_refund", 0.18), 0.0)
	var threshold := maxi(int(GameManager.get_upgrade_modifier_or_default("kill_streak_threshold", 3.0)), 1)
	if GameManager.has_upgrade("kill_chain") and kill_streak >= threshold:
		special_cooldown_remaining = maxf(special_cooldown_remaining - GameManager.get_upgrade_modifier_or_default("kill_streak_special_refund", 1.5), 0.0)
		kill_streak = 0

func _on_died() -> void:
	if GameManager.debug_mode:
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
		current_slash_is_sweep = false
		current_attack_charged = false
		current_attack_momentum = false
		current_attack_afterimage = false
		afterimage_triggered = false
		locked_target = null
		if sword_sprite:
			sword_sprite.position = sword_base_position
		swing_extension_amount = 0.0
		swing_extension_dir_local = Vector2.ZERO
