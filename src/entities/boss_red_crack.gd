extends CharacterBody2D
class_name BossRedCrack

@onready var health_component: HealthComponent = $HealthComponent
@onready var velocity_component: VelocityComponent = $VelocityComponent

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
	z_index = -1
	
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
	
	health_component.died.connect(_on_died)
	target = get_tree().get_first_node_in_group("Player")
	
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

func _physics_process(delta: float):
	if health_label:
		health_label.visible = GameManager.debug_mode
		health_label.text = boss_display_name + ": " + str(int(health_component.current_health)) + "/" + str(int(health_component.max_health))
	if attribute_component and attribute_component.is_disabled():
		velocity = Vector2.ZERO
		return

	if not target:
		target = get_tree().get_first_node_in_group("Player")
		return

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

func check_contact_damage():
	var areas = contact_hitbox.get_overlapping_areas()
	for area in areas:
		if area is HurtboxComponent and area.owner.is_in_group("Player"):
			area.emit_signal("hit", contact_hitbox.damage)

func check_dash_damage():
	if not dash_hitbox.monitorable: return
	var areas = dash_hitbox.get_overlapping_areas()
	for area in areas:
		if area is HurtboxComponent and area.owner.is_in_group("Player"):
			area.emit_signal("hit", dash_hitbox.damage)

func start_aiming():
	current_state = State.AIMING
	timer = charge_aim_time
	velocity = Vector2.ZERO
	slash_visual.visible = true
	slash_visual.color = Color(1, 1, 1, 0.2)
	print("[BOSS] Aiming...")

func start_lock():
	current_state = State.LOCKED
	timer = charge_lock_time
	print("[BOSS] Direction Locked!")

func start_charge():
	current_state = State.CHARGING
	timer = 0.5
	dash_hitbox.monitorable = true
	slash_visual.color = Color(1, 0, 0, 0.3)
	print("[BOSS] CHARGE!")

func stop_charge():
	dash_hitbox.monitorable = false
	slash_visual.visible = false
	modulate = Color.WHITE
	current_state = State.COOLDOWN
	timer = 1.0

func apply_variant_visual() -> void:
	match boss_id:
		"GreenPlague": $Placeholder.color = Color("4b9a65")
		"BlueArc": $Placeholder.color = Color("4c82c4")
		"YellowSand": $Placeholder.color = Color("c79a4d")
		"AscensionKing": $Placeholder.color = Color("b94fbd")
		_: $Placeholder.color = Color("c43f46")


func take_damage(amount: float) -> void:
	if health_component.current_health <= 0.0:
		return
	health_component.damage(amount)

func _on_died():
	print("[BOSS] %s Defeated!" % boss_display_name)
	EventBus.emit_signal("boss_defeated", boss_id)
	queue_free()

func _on_hurtbox_component_hit(damage: float):
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.ORANGE, 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.05)
