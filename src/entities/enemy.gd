extends CharacterBody2D
class_name Enemy

enum EnemyType { MELEE, ARROW, MAGIC, HEAL, HEAVY, ASSASSIN }
@export var enemy_type: EnemyType = EnemyType.MELEE

@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: Sprite2D = $Sprite2D

@export var speed: float = 100.0
@export var shoot_range: float = 400.0
@export var shoot_interval: float = 1.5
@export var bullet_scene_path: String = "res://scenes/entities/projectiles/bullet.tscn"

@export var heal_range: float = 300.0
@export var heal_amount: float = 3.0
@export var heal_interval: float = 1.0

@export var aggro_range: float = 350.0

var target: Node2D
var shoot_timer: float = 0.0
var heal_timer: float = 0.0
var melee_attack_timer: float = 0.0
var core_attack_timer: float = 0.0
var health_label: Label
var enemy_level: int = 1
var wave_damage_multiplier: float = 1.0
var attribute_component: AttributeStatusComponent
var fracture_stacks: int = 0
var fracture_time: float = 0.0
var fracture_triggering: bool = false
var is_elite: bool = false
var flank_side: float = 1.0
# 土豆兄弟式行走动画：弹跳步频 + 左右摇摆。
var walk_time: float = 0.0
var dying: bool = false

const DEMON_CORE_SCRIPT = preload("res://src/entities/demon_core.gd")
const DAMAGE_NUMBER_SCRIPT = preload("res://src/effects/damage_number.gd")
const HIT_SPARKS_SCRIPT = preload("res://src/effects/hit_sparks.gd")

@export var orb_scene: PackedScene = preload("res://scenes/entities/pickups/spirit_orb.tscn")
@onready var bullet_pkg: PackedScene = load(bullet_scene_path)

var player: Node2D
var core: Node2D

const MELEE_TEXTURE = preload("res://assets/textures/enemies/enemy_red_melee_full.png")
const ARROW_TEXTURE = preload("res://assets/textures/enemies/enemy_yellow_arrow_full.png")
const MAGIC_TEXTURE = preload("res://assets/textures/enemies/enemy_blue_magic_full.png")
const HEAL_TEXTURE  = preload("res://assets/textures/enemies/enemy_green_heal_full.png")
const HEAVY_TEXTURE = preload("res://assets/textures/enemies/enemy_heavy_full.png")
const ASSASSIN_TEXTURE = preload("res://assets/textures/enemies/enemy_assassin_full.png")
const STATUS_VIEW_SCRIPT = preload("res://src/entities/enemy_status_view.gd")

func _ready():
	add_to_group("Enemy")
	add_to_group("DamageableEnemy")
	z_index = 2
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Keep minions visibly smaller than the protagonist while preserving the
	# full-body silhouette and faction-specific weapon read at gameplay scale.
	sprite.scale = Vector2.ONE * 0.17

	match enemy_type:
		EnemyType.MELEE:
			sprite.texture = MELEE_TEXTURE
			speed = 110.0
			$HitboxComponent.damage = 8.0
		EnemyType.ARROW:
			sprite.texture = ARROW_TEXTURE
			speed = 75.0
			shoot_range = 420.0
			shoot_interval = 1.2
		EnemyType.MAGIC:
			sprite.texture = MAGIC_TEXTURE
			speed = 65.0
			shoot_range = 380.0
			shoot_interval = 1.8
		EnemyType.HEAL:
			sprite.texture = HEAL_TEXTURE
			speed = 85.0
			aggro_range = 250.0
		EnemyType.HEAVY:
			sprite.texture = HEAVY_TEXTURE
			sprite.scale = Vector2.ONE * 0.07
			speed = 58.0
			$HitboxComponent.damage = 12.0
		EnemyType.ASSASSIN:
			sprite.texture = ASSASSIN_TEXTURE
			sprite.scale = Vector2.ONE * 0.07
			speed = 155.0
			aggro_range = 520.0
			$HitboxComponent.damage = 6.0
			# 固定一侧包抄方向，避免每帧抖动导致突袭妖原地画圈。
			flank_side = 1.0 if randf() < 0.5 else -1.0


	var scaling := WaveManager.get_enemy_scaling(GameManager.current_state == GameManager.GameState.NIGHT)
	enemy_level = int(scaling.get("level", 1))
	wave_damage_multiplier = float(scaling.get("damage", 1.0))
	speed *= float(scaling.get("speed", 1.0))
	$HitboxComponent.damage *= wave_damage_multiplier
	if enemy_type == EnemyType.HEAL:
		heal_amount *= float(scaling.get("heal", 1.0))

	var base_health := 10.0
	match enemy_type:
		EnemyType.MELEE: base_health = 8.0
		EnemyType.HEAL:  base_health = 5.0
		EnemyType.HEAVY: base_health = 24.0
		EnemyType.ASSASSIN: base_health = 6.0

	var scaled_health := base_health * float(scaling.get("health", 1.0))
	if is_elite:
		# 精英妖：体型、生命和压制力提升，死亡时必掉妖丹。
		scaled_health *= 2.6
		$HitboxComponent.damage *= 1.25
		sprite.scale *= 1.45
		speed *= 0.95
		modulate = Color(1.0, 0.9, 0.66)
	health_component.max_health = scaled_health
	health_component.current_health = scaled_health
	attribute_component = AttributeStatusComponent.new()
	attribute_component.health_component = health_component
	add_child(attribute_component)
	var status_view := STATUS_VIEW_SCRIPT.new()
	status_view.configure(attribute_component)
	add_child(status_view)

	health_component.died.connect(_on_died)
	player = get_tree().get_first_node_in_group("Player")
	core = get_tree().get_first_node_in_group("LifeCore")

	# 出生弹出：从压缩状态弹到正常体型，与土豆兄弟的刷怪反馈一致。
	scale = Vector2(0.3, 0.3)
	var spawn_pop := create_tween()
	spawn_pop.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	setup_debug_ui()

func setup_debug_ui():
	health_label = Label.new()
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.position = Vector2(-20, -10)
	health_label.add_theme_font_size_override("font_size", 14)
	add_child(health_label)

func apply_attribute_payload(payload: Dictionary, attack_damage: float = 0.0, origin: Vector2 = Vector2.ZERO) -> void:
	if attribute_component:
		attribute_component.apply_payload(payload, attack_damage, origin)

func play_attack_anim():
	var st = create_tween()
	st.tween_property(self, "scale", Vector2(1.25, 0.75), 0.1)
	st.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

func _physics_process(delta: float):
	if dying:
		return
	fracture_time = maxf(fracture_time - delta, 0.0)
	if fracture_time <= 0.0:
		fracture_stacks = 0
	if health_label:
		health_label.visible = GameManager.debug_mode
		health_label.text = "L%d %d" % [enemy_level, int(health_component.current_health)]
	# 行走动画：移动中弹跳 + 摇摆，静止时缓慢呼吸。
	var is_moving := velocity.length_squared() > 10.0
	walk_time += delta * (10.0 if is_moving else 2.2)
	var bounce_phase := absf(sin(walk_time))
	sprite.position.y = -bounce_phase * (4.0 if is_moving else 1.2)
	sprite.rotation = sin(walk_time) * (0.09 if is_moving else 0.03)
	if attribute_component and attribute_component.is_disabled():
		velocity = Vector2.ZERO
		return

	if not player: player = get_tree().get_first_node_in_group("Player")
	if not core: core = get_tree().get_first_node_in_group("LifeCore")

	if not player: return

	# Keep every enemy type facing the player, including healers that return early.
	sprite.flip_h = player.global_position.x < global_position.x

	var dist_to_player = global_position.distance_to(player.global_position)
	var current_aggro = aggro_range
	var is_night = GameManager.current_state == GameManager.GameState.NIGHT
	var status_speed_multiplier := attribute_component.get_speed_multiplier() if attribute_component else 1.0
	if GameManager.has_upgrade("aura_slow") and core and is_instance_valid(core):
		if global_position.distance_to(core.global_position) <= 190.0:
			status_speed_multiplier *= maxf(0.25, 1.0 - GameManager.get_upgrade_modifier("core_aura_slow_pct"))

	if is_night:
		current_aggro = aggro_range * 2.0
		if _process_core_attack(delta):
			return

	# HEAL enemy: periodically heal nearby allies
	if enemy_type == EnemyType.HEAL:
		heal_timer -= delta * maxf(status_speed_multiplier, 0.1)
		if heal_timer <= 0:
			if heal_nearby_enemies():
				play_attack_anim()
			heal_timer = heal_interval

	var move_target: Vector2 = Vector2.ZERO
	var active_chase = false
	var chasing_player = false

	if enemy_type == EnemyType.HEAL:
		if dist_to_player < current_aggro:
			var flee_dir = global_position.direction_to(player.global_position)
			velocity = -flee_dir * speed * status_speed_multiplier
			move_and_slide()
			return
		elif is_night and core:
			move_target = core.global_position
			active_chase = true
	else:
		if dist_to_player < current_aggro:
			move_target = player.global_position
			active_chase = true
			chasing_player = true

			var is_ranged = (enemy_type == EnemyType.ARROW or enemy_type == EnemyType.MAGIC)
			if is_ranged and dist_to_player < shoot_range:
				shoot_timer -= delta
				if shoot_timer <= 0:
					shoot_at_player()
					shoot_timer = shoot_interval

			# MELEE: periodic attack animation when close to player
			if enemy_type == EnemyType.MELEE or enemy_type == EnemyType.HEAVY or enemy_type == EnemyType.ASSASSIN:
				var contact_range := 50.0
				var contact_interval := 0.8
				if enemy_type == EnemyType.HEAVY:
					contact_range = 60.0
					contact_interval = 1.1
				elif enemy_type == EnemyType.ASSASSIN:
					contact_range = 46.0
					contact_interval = 0.55
				if dist_to_player < contact_range:
					melee_attack_timer -= delta
					if melee_attack_timer <= 0:
						play_attack_anim()
						_damage_player(float($HitboxComponent.damage))
						melee_attack_timer = contact_interval
		elif is_night and core:
			move_target = core.global_position
			active_chase = true

	if active_chase:
		var direction = global_position.direction_to(move_target)
		var final_speed = speed * status_speed_multiplier
		var is_ranged = (enemy_type == EnemyType.ARROW or enemy_type == EnemyType.MAGIC)
		if is_ranged and dist_to_player < shoot_range * 0.5:
			final_speed *= 0.5
		# 突袭妖：远距离沿侧翼弧线包抄，进入扑击距离后直线加速扑上。
		if enemy_type == EnemyType.ASSASSIN and chasing_player:
			if dist_to_player > 170.0:
				var to_player = global_position.direction_to(player.global_position)
				var side = Vector2(-to_player.y, to_player.x) * flank_side
				direction = (to_player * 0.35 + side).normalized()
			else:
				final_speed *= 1.3

		velocity = direction * final_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO

func _process_core_attack(delta: float) -> bool:
	if not core or not is_instance_valid(core) or not core.has_method("receive_damage"):
		return false
	if core.has_method("is_destroyed") and core.is_destroyed():
		return false
	if global_position.distance_to(core.global_position) > 62.0:
		return false

	velocity = Vector2.ZERO
	core_attack_timer -= delta
	if core_attack_timer <= 0.0:
		var damage_ratio := 0.45
		var attack_interval := 1.1
		match enemy_type:
			EnemyType.ARROW:
				damage_ratio = 0.30
				attack_interval = 1.35
			EnemyType.MAGIC:
				damage_ratio = 0.40
				attack_interval = 1.25
			EnemyType.HEAL:
				damage_ratio = 0.25
				attack_interval = 1.5
			EnemyType.HEAVY:
				damage_ratio = 0.60
				attack_interval = 1.0
			EnemyType.ASSASSIN:
				damage_ratio = 0.35
				attack_interval = 0.75
		var core_damage := maxf(float($HitboxComponent.damage) * damage_ratio, 2.0)
		core.receive_damage(core_damage)
		core_attack_timer = attack_interval
		play_attack_anim()
	return true

func _damage_player(amount: float) -> void:
	if not player or not is_instance_valid(player) or not player.has_method("take_damage"):
		return
	player.take_damage(maxf(amount, 0.0))

func heal_nearby_enemies() -> bool:
	var enemies = get_tree().get_nodes_in_group("Enemy")
	var best_target = null
	var best_hp_pct = 1.0
	for enemy in enemies:
		if enemy == self: continue
		if not is_instance_valid(enemy): continue
		if not enemy.has_method("receive_heal"): continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < heal_range:
			var hp_pct = enemy.health_component.current_health / enemy.health_component.max_health
			if hp_pct < best_hp_pct:
				best_hp_pct = hp_pct
				best_target = enemy
	if best_target:
		best_target.receive_heal(heal_amount)
		return true
	return false

func receive_heal(amount: float):
	if is_instance_valid(health_component):
		var healing_multiplier := attribute_component.get_healing_received_multiplier() if attribute_component else 1.0
		health_component.heal(amount * healing_multiplier)

func shoot_at_player():
	if not bullet_pkg or not player: return
	var bullet = bullet_pkg.instantiate()

	play_attack_anim()

	var base_damage = 5.0
	var bullet_color = Color.WHITE
	var bullet_speed = 600.0

	match enemy_type:
		EnemyType.ARROW:
			base_damage = 4.0
			bullet_color = Color.GREEN
			bullet_speed = 700.0
		EnemyType.MAGIC:
			base_damage = 5.0
			bullet_color = Color.BLUE
			bullet_speed = 400.0
		_:
			base_damage = 5.0
			bullet_color = Color.WHITE
			bullet_speed = 600.0

	base_damage *= wave_damage_multiplier

	bullet.damage = base_damage
	bullet.color = bullet_color
	bullet.speed = bullet_speed
	bullet.global_position = global_position
	bullet.rotation = global_position.direction_to(player.global_position).angle()

	var hb = bullet.get_node("HitboxComponent")
	hb.collision_layer = 16
	hb.collision_mask = 2

	get_tree().root.add_child(bullet)

func resolve_incoming_damage(amount: float) -> void:
	# HurtboxComponent 的钩子：带上最近一次命中来源，供正面格挡判定方向。
	var hurtbox := get_node_or_null("HurtboxComponent") as HurtboxComponent
	var origin := hurtbox.last_hit_origin if hurtbox else Vector2.INF
	var was_critical := hurtbox.last_hit_critical if hurtbox else false
	take_damage(maxf(amount, 0.0), origin, was_critical)

func take_damage(amount: float, origin: Vector2 = Vector2.INF, was_critical: bool = false) -> void:
	if dying or health_component.current_health <= 0.0:
		return
	var final_amount := amount
	var attacker_position := origin if origin.is_finite() else (player.global_position if player and is_instance_valid(player) else global_position + Vector2.UP)
	if enemy_type == EnemyType.HEAVY and _is_hit_from_front(origin):
		# 正面厚重护甲：约 120° 扇区内伤害减免 70%，绕后与侧面全额生效。
		final_amount = amount * 0.3
		was_critical = false
		_flash_frontal_block()
	var health_before := health_component.current_health
	health_component.damage(final_amount)
	_apply_hit_feedback(final_amount, attacker_position, was_critical)
	if health_component.current_health <= 0.0 and health_before > 0.0 and final_amount > health_before:
		GameManager.spawn_overkill_chain(global_position, final_amount - health_before)

func _apply_hit_feedback(amount: float, attacker_position: Vector2, was_critical: bool) -> void:
	if amount <= 0.0:
		return
	# 伤害飘字 + 命中火花。
	DAMAGE_NUMBER_SCRIPT.spawn(get_parent() if get_parent() else get_tree().current_scene, global_position, amount, "crit" if was_critical else "normal")
	var knock_dir := (global_position - attacker_position).normalized()
	HIT_SPARKS_SCRIPT.spawn(get_parent() if get_parent() else get_tree().current_scene, global_position - knock_dir * 8.0, knock_dir)
	# 方向击退：普攻附带小位移，暴击更明显。
	var knockback := clampf(amount * 0.25, 3.0, 14.0)
	if was_critical:
		knockback *= 1.6
		EventBus.camera_shake_requested.emit(5.0)
		GameManager.request_hitstop(0.05)
	global_position += knock_dir * knockback

func _is_hit_from_front(origin: Vector2) -> bool:
	if not player or not is_instance_valid(player):
		return true
	var attacker_position := origin if origin.is_finite() else player.global_position
	var to_attacker := global_position.direction_to(attacker_position)
	var facing := global_position.direction_to(player.global_position)
	return to_attacker.dot(facing) > 0.35

func _flash_frontal_block() -> void:
	modulate = Color("9fd8e8")
	var tween = create_tween()
	tween.tween_interval(0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)

func add_fracture(attack_damage: float, stacks_to_add: int = 1) -> void:
	if not GameManager.has_upgrade("fracture_mark") or health_component.current_health <= 0.0:
		return
	fracture_time = GameManager.get_upgrade_modifier_or_default("fracture_duration", 2.2)
	fracture_stacks += maxi(stacks_to_add, 1)
	var threshold := maxi(int(GameManager.get_upgrade_modifier_or_default("fracture_threshold", 5.0)), 1)
	if fracture_stacks < threshold or not GameManager.has_upgrade("fracture_harvest") or fracture_triggering:
		return
	fracture_triggering = true
	var harvest_damage := attack_damage * GameManager.get_upgrade_modifier_or_default("fracture_damage_pct", 0.70)
	fracture_stacks = 0
	fracture_time = 0.0
	take_damage(harvest_damage)
	GameManager.spawn_burst_damage(
		global_position,
		GameManager.get_upgrade_modifier_or_default("fracture_radius", 90.0),
		harvest_damage * 0.45,
		{},
		Color("c6a4ff")
	)
	var spread_count := maxi(int(GameManager.get_upgrade_modifier_or_default("fracture_spread", 1.0)), 0)
	if spread_count > 0:
		var spread_targets: Array = []
		for candidate in get_tree().get_nodes_in_group("DamageableEnemy"):
			if candidate == self or not is_instance_valid(candidate) or not candidate.has_method("add_fracture"):
				continue
			if candidate.global_position.distance_to(global_position) <= GameManager.get_upgrade_modifier_or_default("fracture_radius", 90.0):
				spread_targets.append(candidate)
		for index in range(mini(spread_count, spread_targets.size())):
			var spread_target = spread_targets[index]
			spread_target.add_fracture(harvest_damage * 0.35, 1)
	fracture_triggering = false

func _on_died():
	GameManager.record_enemy_kill()
	var player_node := get_tree().get_first_node_in_group("Player")
	if player_node and player_node.has_method("register_enemy_kill"):
		player_node.register_enemy_kill(self)
	if is_elite and get_parent():
		var demon_core := DEMON_CORE_SCRIPT.new()
		demon_core.global_position = global_position
		get_parent().call_deferred("add_child", demon_core)
	spawn_orb()
	if GameManager.has_upgrade("execution_burst"):
		GameManager.spawn_burst_damage(
			global_position,
			GameManager.get_upgrade_modifier("execution_burst_radius", 85.0),
			GameManager.get_upgrade_modifier("execution_burst_damage", 20.0),
			{},
			Color("d78b63")
		)
	if GameManager.has_upgrade("blade_poison_cloud"):
		GameManager.spawn_damage_zone(
			global_position,
			GameManager.get_upgrade_modifier("blade_poison_cloud_radius", 90.0),
			GameManager.get_upgrade_modifier("blade_poison_cloud_duration", 3.0),
			GameManager.get_upgrade_modifier("blade_poison_cloud_damage", 4.0),
			{"poison": 1},
			Color("65c579")
		)
	# 死亡表现：停用逻辑与碰撞，压缩弹开式缩小后消失。
	dying = true
	velocity = Vector2.ZERO
	$HitboxComponent.set_deferred("monitoring", false)
	$HurtboxComponent.set_deferred("monitoring", false)
	$HurtboxComponent.set_deferred("monitorable", false)
	var death_pop := create_tween()
	death_pop.tween_property(self, "scale", Vector2(1.3, 1.3), 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	death_pop.tween_property(self, "scale", Vector2.ZERO, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	death_pop.tween_callback(queue_free)

func spawn_orb():
	if not orb_scene: return
	_spawn_orb_once()
	if GameManager.should_drop_bonus_orb():
		_spawn_orb_once()

func _spawn_orb_once() -> void:
	var orb = orb_scene.instantiate()
	orb.global_position = global_position
	orb.type = GameManager.get_weighted_drop_type()
	# 死亡信号可能来自物理回调，延迟入树避免 area 状态在 flushing queries 中切换。
	get_parent().call_deferred("add_child", orb)

func _on_hurtbox_component_hit(damage: float):
	modulate = Color.RED
	var knockback_dir = (global_position - get_tree().get_first_node_in_group("Player").global_position).normalized()
	global_position += knockback_dir * 10.0

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.05)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)

	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
