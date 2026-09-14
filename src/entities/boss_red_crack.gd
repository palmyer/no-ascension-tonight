extends CharacterBody2D
class_name BossRedCrack

const BOSS_BULLET_SCENE = preload("res://scenes/entities/projectiles/bullet.tscn")
const HAZARD_ZONE_SCRIPT = preload("res://src/effects/hazard_zone.gd")
const STATUS_VIEW_SCRIPT = preload("res://src/entities/enemy_status_view.gd")

@onready var health_component: HealthComponent = $HealthComponent
@onready var velocity_component: VelocityComponent = $VelocityComponent
@onready var boss_visual: Node2D = $BossVisual

@export var speed: float = 60.0
@export var charge_aim_time: float = 2.0
@export var charge_lock_time: float = 0.5
@export var charge_dash_speed: float = 600.0
@export var charge_cooldown: float = 5.0

enum State { CHASE, AIMING, LOCKED, CHARGING, COOLDOWN }
var current_state: State = State.CHASE

var target: Node2D
var timer: float = 0.0
var charge_direction: Vector2 = Vector2.ZERO
var boss_id: String = "RedCrack"
var boss_display_name: String = "赤裂大妖"
var boss_stats: Dictionary = {}
var attribute_component: AttributeStatusComponent
var core: Node2D
var core_attack_timer: float = 0.0
var contact_damage_timer: float = 0.0
var dash_damage_timer: float = 0.0
var ability_timer: float = 2.5
var enraged: bool = false
var ability_casting: bool = false

var health_label: Label
@onready var slash_visual: ColorRect = $WeaponPivot/SlashVisual
@onready var contact_hitbox: Area2D = $ContactHitbox
@onready var dash_hitbox: Area2D = $WeaponPivot/HitboxComponent

func configure_boss(configured_id: String, configured_stats: Dictionary) -> void:
	boss_id = configured_id
	boss_stats = configured_stats.duplicate(true)
	boss_display_name = str(boss_stats.get("display_name", boss_id))

func _ready():
	add_to_group("Enemy")
	add_to_group("DamageableEnemy")
	add_to_group("Boss")
	z_index = 3
	
	if boss_stats.is_empty():
		boss_stats = WaveManager.get_boss_stats(boss_id)
	boss_display_name = str(boss_stats.get("display_name", boss_id))
	speed = float(boss_stats.get("speed", speed))
	charge_aim_time = float(boss_stats.get("charge_aim_time", charge_aim_time))
	charge_cooldown = float(boss_stats.get("charge_cooldown", charge_cooldown))
	contact_hitbox.damage = float(boss_stats.get("contact_damage", contact_hitbox.damage))
	dash_hitbox.damage = float(boss_stats.get("dash_damage", dash_hitbox.damage))
	apply_variant_visual()

	var scaled_health := float(boss_stats.get("health", 500.0))
	health_component.max_health = scaled_health
	health_component.current_health = scaled_health
	attribute_component = AttributeStatusComponent.new()
	attribute_component.health_component = health_component
	add_child(attribute_component)
	var status_view := STATUS_VIEW_SCRIPT.new()
	status_view.configure(attribute_component, true)
	add_child(status_view)
	
	health_component.died.connect(_on_died)
	target = get_tree().get_first_node_in_group("Player")
	core = get_tree().get_first_node_in_group("LifeCore")
	
	slash_visual.visible = false
	
	# 确保所有 Hitbox 物理层级正确
	contact_hitbox.monitoring = true
	contact_hitbox.monitorable = true
	dash_hitbox.monitoring = true
	dash_hitbox.monitorable = false
	setup_debug_ui()

func setup_debug_ui():
	if not health_label:
		health_label = Label.new()
		health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		health_label.position = Vector2(-50, -60)
		health_label.add_theme_font_size_override("font_size", 20)
		add_child(health_label)

func apply_attribute_payload(payload: Dictionary, attack_damage: float = 0.0, origin: Vector2 = Vector2.ZERO) -> void:
	if attribute_component:
		attribute_component.apply_payload(payload, attack_damage, origin)

func get_boss_status_text() -> String:
	if current_state == State.AIMING or current_state == State.LOCKED:
		return "冲锋蓄力中  ·  注意红色预警"
	if current_state == State.CHARGING:
		return "冲锋进行中  ·  立即闪避"
	if ability_timer <= 1.0:
		return "秘术即将释放  ·  保持移动"
	return "秘术冷却  %.1fs" % ability_timer

func _physics_process(delta: float):
	contact_damage_timer = maxf(contact_damage_timer - delta, 0.0)
	dash_damage_timer = maxf(dash_damage_timer - delta, 0.0)
	if health_label:
		health_label.visible = GameManager.debug_mode
		health_label.text = boss_display_name + ": " + str(int(health_component.current_health)) + "/" + str(int(health_component.max_health))
	if attribute_component and attribute_component.is_disabled():
		velocity = Vector2.ZERO
		return

	if not target:
		target = get_tree().get_first_node_in_group("Player")
		return

	if _process_core_attack(delta):
		return

	_process_variant_ability(delta)

	# 持续检测接触伤害
	check_contact_damage()
	# 水平翻转面向玩家
	$Placeholder.scale.x = -1.0 if target.global_position.x < global_position.x else 1.0
	var status_speed_multiplier := attribute_component.get_speed_multiplier() if attribute_component else 1.0

	match current_state:
		State.CHASE:
			var direction = global_position.direction_to(target.global_position)
			velocity = direction * speed * status_speed_multiplier
			move_and_slide()
			$WeaponPivot.rotation = direction.angle()
			
			timer += delta
			if timer >= charge_cooldown:
				start_aiming()
				
		State.AIMING:
			timer -= delta
			var direction = global_position.direction_to(target.global_position)
			$WeaponPivot.rotation = direction.angle()
			charge_direction = direction
			
			modulate = Color.RED.lerp(Color.WHITE, timer / charge_aim_time)
			
			if timer <= 0:
				start_lock()
				
		State.LOCKED:
			timer -= delta
			modulate = Color.RED
			if timer <= 0:
				start_charge()

		State.CHARGING:
			velocity = charge_direction * charge_dash_speed * status_speed_multiplier
			move_and_slide()
			
			# 冲锋实时伤害检测
			check_dash_damage()
			
			timer -= delta
			if timer <= 0:
				stop_charge()
				
		State.COOLDOWN:
			timer -= delta
			if timer <= 0:
				current_state = State.CHASE
				timer = 0.0

func _process_variant_ability(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.NIGHT:
		return
	if health_component and not enraged and health_component.current_health <= health_component.max_health * 0.5:
		enraged = true
		if boss_visual and boss_visual.has_method("set_enraged"):
			boss_visual.set_enraged(true)
		ability_timer = minf(ability_timer, 1.0)

	ability_timer -= delta
	if ability_timer > 0.0 or ability_casting:
		return

	var cooldown := float(boss_stats.get("ability_cooldown", 6.0))
	if enraged:
		cooldown *= 0.72
	ability_timer = maxf(cooldown, 2.2)
	match boss_id:
		"GreenPlague":
			_cast_green_plague()
		"BlueArc":
			_cast_blue_arc()
		"YellowSand":
			_cast_yellow_sand()
		"AscensionKing":
			_cast_ascension_king()
		_:
			# Red Crack's charge is already its signature skill. The extra
			# telegraph keeps the late-game version readable without stacking
			# another unavoidable hit.
			if enraged:
				_spawn_hazard(global_position, 92.0, 1.6, 11.0, Color("ef6a4f"), false)

func _cast_green_plague() -> void:
	var target_position := target.global_position if target and is_instance_valid(target) else global_position
	_spawn_hazard(target_position, 105.0, 3.8, 7.0, Color("65c579"), true)
	_spawn_hazard(target_position + Vector2.from_angle(randf() * TAU) * 130.0, 68.0, 2.8, 5.0, Color("b4e36c"), false)

func _cast_blue_arc() -> void:
	var aim := global_position.direction_to(target.global_position) if target and is_instance_valid(target) else Vector2.RIGHT
	for offset in [-0.24, 0.0, 0.24]:
		_spawn_boss_bullet(aim.rotated(offset), 13.0 if not enraged else 17.0, Color("75d7ef"), 520.0)

func _cast_yellow_sand() -> void:
	var center := target.global_position if target and is_instance_valid(target) else global_position
	for index in range(3 if enraged else 2):
		var angle := TAU * float(index) / float(3 if enraged else 2) + timer
		_spawn_hazard(center + Vector2.from_angle(angle) * 145.0, 76.0, 2.4, 10.0, Color("d9b34d"), true)

func _cast_ascension_king() -> void:
	var center := target.global_position if target and is_instance_valid(target) else global_position
	for index in range(6 if enraged else 4):
		var angle := TAU * float(index) / float(6 if enraged else 4) + timer * 0.35
		_spawn_hazard(center + Vector2.from_angle(angle) * 175.0, 62.0, 2.8, 12.0, Color("c966c9"), true)
	var aim := global_position.direction_to(center)
	_spawn_boss_bullet(aim, 20.0 if enraged else 16.0, Color("f1cf68"), 560.0)

func _spawn_boss_bullet(direction: Vector2, damage: float, color: Color, bullet_speed: float) -> void:
	var bullet = BOSS_BULLET_SCENE.instantiate()
	bullet.damage = damage
	bullet.speed = bullet_speed
	bullet.lifetime = 2.5
	bullet.color = color
	bullet.global_position = global_position
	bullet.rotation = direction.angle()
	bullet.piercing = false
	bullet.max_hits = 1
	var hitbox: HitboxComponent = bullet.get_node_or_null("HitboxComponent")
	if hitbox:
		hitbox.collision_layer = 16
		hitbox.collision_mask = 2
	get_tree().root.add_child(bullet)

func _spawn_hazard(position: Vector2, radius: float, duration: float, damage: float, color: Color, can_damage_core: bool) -> void:
	var hazard := HAZARD_ZONE_SCRIPT.new()
	hazard.global_position = position
	hazard.configure(radius, duration, damage, color, can_damage_core)
	var host := get_tree().current_scene
	if not host:
		host = get_tree().root
	host.add_child(hazard)

func _process_core_attack(delta: float) -> bool:
	if GameManager.current_state != GameManager.GameState.NIGHT:
		return false
	if not core or not is_instance_valid(core) or not core.has_method("receive_damage"):
		return false
	if core.has_method("is_destroyed") and core.is_destroyed():
		return false
	if global_position.distance_to(core.global_position) > 78.0:
		return false

	velocity = Vector2.ZERO
	core_attack_timer -= delta
	if core_attack_timer <= 0.0:
		core.receive_damage(float(contact_hitbox.damage) * 0.65)
		core_attack_timer = 1.0
	return true

func check_contact_damage():
	if contact_damage_timer > 0.0:
		return
	var areas = contact_hitbox.get_overlapping_areas()
	for area in areas:
		if not area is HurtboxComponent:
			continue
		var player := area.get_parent()
		if player and player.is_in_group("Player") and player.has_method("take_damage"):
			player.take_damage(contact_hitbox.damage)
			contact_damage_timer = 0.8
			return

func check_dash_damage():
	if not dash_hitbox.monitorable: return
	if dash_damage_timer > 0.0: return
	var areas = dash_hitbox.get_overlapping_areas()
	for area in areas:
		if not area is HurtboxComponent:
			continue
		var player := area.get_parent()
		if player and player.is_in_group("Player") and player.has_method("take_damage"):
			player.take_damage(dash_hitbox.damage)
			dash_damage_timer = 0.6
			return

func start_aiming():
	current_state = State.AIMING
	timer = charge_aim_time
	velocity = Vector2.ZERO
	slash_visual.visible = true
	slash_visual.color = Color(1, 1, 1, 0.2)
	if GameManager.debug_mode:
		print("[BOSS] Aiming...")

func start_lock():
	current_state = State.LOCKED
	timer = charge_lock_time
	if GameManager.debug_mode:
		print("[BOSS] Direction Locked!")

func start_charge():
	current_state = State.CHARGING
	timer = 0.5
	dash_hitbox.monitorable = true
	slash_visual.color = Color(1, 0, 0, 0.3)
	if GameManager.debug_mode:
		print("[BOSS] CHARGE!")

func stop_charge():
	dash_hitbox.monitorable = false
	slash_visual.visible = false
	modulate = Color.WHITE
	current_state = State.COOLDOWN
	timer = 1.0

func apply_variant_visual() -> void:
	var primary := Color("c43f46")
	var secondary := Color("f0b95f")
	match boss_id:
		"GreenPlague":
			primary = Color("4b9a65")
			secondary = Color("b4e36c")
		"BlueArc":
			primary = Color("4c82c4")
			secondary = Color("75d7ef")
		"YellowSand":
			primary = Color("c79a4d")
			secondary = Color("f1d36c")
		"AscensionKing":
			primary = Color("b94fbd")
			secondary = Color("f1cf68")
		_:
			pass
	$Placeholder.visible = false
	if boss_visual and boss_visual.has_method("configure"):
		boss_visual.configure(boss_id, primary, secondary)


func take_damage(amount: float) -> void:
	if health_component.current_health <= 0.0:
		return
	health_component.damage(amount)

func _on_died():
	if GameManager.debug_mode:
		print("[BOSS] %s Defeated!" % boss_display_name)
	EventBus.emit_signal("boss_defeated", boss_id)
	queue_free()

func _on_hurtbox_component_hit(damage: float):
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.ORANGE, 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.05)
