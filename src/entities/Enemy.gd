extends CharacterBody2D
class_name Enemy

enum EnemyType { MELEE, ARROW, MAGIC, HEAL }
@export var enemy_type: EnemyType = EnemyType.MELEE

@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: Sprite2D = $Sprite2D

@export var speed: float = 100.0
@export var shoot_range: float = 400.0
@export var shoot_interval: float = 1.5
@export var bullet_scene_path: String = "res://scenes/Bullet.tscn"

@export var heal_range: float = 300.0
@export var heal_amount: float = 3.0
@export var heal_interval: float = 1.0

@export var aggro_range: float = 350.0

var target: Node2D
var shoot_timer: float = 0.0
var heal_timer: float = 0.0
var melee_attack_timer: float = 0.0
var health_label: Label

@export var orb_scene: PackedScene = preload("res://scenes/SpiritOrb.tscn")
@onready var bullet_pkg: PackedScene = load(bullet_scene_path)

var player: Node2D
var core: Node2D

const MELEE_TEXTURE = preload("res://enemy_meele_64.png")
const ARROW_TEXTURE = preload("res://enemy_arrow_64.png")
const MAGIC_TEXTURE = preload("res://enemy_magic_64.png")
const HEAL_TEXTURE  = preload("res://enemy_heal_64.png")

func _ready():
	add_to_group("Enemy")
	add_to_group("DamageableEnemy")
	z_index = -2

	match enemy_type:
		EnemyType.MELEE:
			sprite.texture = MELEE_TEXTURE
			speed = 110.0
			$HitboxComponent.damage = 25.0
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


	var base_health = 10.0
	match enemy_type:
		EnemyType.MELEE: base_health = 15.0
		EnemyType.HEAL:  base_health = 8.0

	var scaled_health = base_health + (GameManager.current_wave - 1) * 5.0
	health_component.max_health = scaled_health
	health_component.current_health = scaled_health

	health_component.died.connect(_on_died)
	player = get_tree().get_first_node_in_group("Player")
	core = get_tree().get_first_node_in_group("LifeCore")

	if not GameManager.boss_states["RedCrack"] and GameManager.current_state == GameManager.GameState.NIGHT:
		var multiplier = 1.0
		if GameManager.current_wave <= 6:
			multiplier = 1.2
		elif GameManager.current_wave <= 13:
			multiplier = 1.5
		else:
			multiplier = 2.0

		$HitboxComponent.damage *= multiplier

	setup_debug_ui()

func setup_debug_ui():
	health_label = Label.new()
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.position = Vector2(-20, -10)
	health_label.add_theme_font_size_override("font_size", 14)
	add_child(health_label)

func play_attack_anim():
	var st = create_tween()
	st.tween_property(self, "scale", Vector2(1.25, 0.75), 0.1)
	st.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

func _physics_process(delta: float):
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

	# HEAL enemy: periodically heal nearby allies
	if enemy_type == EnemyType.HEAL:
		heal_timer -= delta
		if heal_timer <= 0:
			if heal_nearby_enemies():
				play_attack_anim()
			heal_timer = heal_interval

	var move_target: Vector2 = Vector2.ZERO
	var active_chase = false

	if enemy_type == EnemyType.HEAL:
		if dist_to_player < current_aggro:
			var flee_dir = global_position.direction_to(player.global_position)
			velocity = -flee_dir * speed
			move_and_slide()
			return
		elif is_night and core:
			move_target = core.global_position
			active_chase = true
	else:
		if dist_to_player < current_aggro:
			move_target = player.global_position
			active_chase = true

			var is_ranged = (enemy_type == EnemyType.ARROW or enemy_type == EnemyType.MAGIC)
			if is_ranged and dist_to_player < shoot_range:
				shoot_timer -= delta
				if shoot_timer <= 0:
					shoot_at_player()
					shoot_timer = shoot_interval

			# MELEE: periodic attack animation when close to player
			if enemy_type == EnemyType.MELEE:
				var contact_range = 50.0
				if dist_to_player < contact_range:
					melee_attack_timer -= delta
					if melee_attack_timer <= 0:
						play_attack_anim()
						melee_attack_timer = 0.8
		elif is_night and core:
			move_target = core.global_position
			active_chase = true

	if active_chase:
		var direction = global_position.direction_to(move_target)
		var final_speed = speed
		var is_ranged = (enemy_type == EnemyType.ARROW or enemy_type == EnemyType.MAGIC)
		if is_ranged and dist_to_player < shoot_range * 0.5:
			final_speed *= 0.5

		velocity = direction * final_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO

	sprite.flip_h = player.global_position.x < global_position.x

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
		health_component.heal(amount)

func shoot_at_player():
	if not bullet_pkg or not player: return
	var bullet = bullet_pkg.instantiate()

	play_attack_anim()

	var base_damage = 5.0
	var bullet_color = Color.WHITE
	var bullet_speed = 600.0

	match enemy_type:
		EnemyType.ARROW:
			base_damage = 5.0
			bullet_color = Color.GREEN
			bullet_speed = 700.0
		EnemyType.MAGIC:
			base_damage = 8.0
			bullet_color = Color.BLUE
			bullet_speed = 400.0
		_:
			base_damage = 5.0
			bullet_color = Color.WHITE
			bullet_speed = 600.0

	if not GameManager.boss_states["RedCrack"] and GameManager.current_state == GameManager.GameState.NIGHT:
		var multiplier = 1.0
		if GameManager.current_wave <= 6:
			multiplier = 1.2
		elif GameManager.current_wave <= 13:
			multiplier = 1.5
		else:
			multiplier = 2.0
		base_damage *= multiplier

	bullet.damage = base_damage
	bullet.color = bullet_color
	bullet.speed = bullet_speed
	bullet.global_position = global_position
	bullet.rotation = global_position.direction_to(player.global_position).angle()

	var hb = bullet.get_node("HitboxComponent")
	hb.collision_layer = 16
	hb.collision_mask = 2

	get_tree().root.add_child(bullet)

func take_damage(amount: float) -> void:
	health_component.damage(amount)

func _on_died():
	spawn_orb()
	queue_free()

func spawn_orb():
	if not orb_scene: return
	var orb = orb_scene.instantiate()
	orb.global_position = global_position
	orb.type = GameManager.get_weighted_drop_type()
	get_parent().add_child(orb)

func _on_hurtbox_component_hit(damage: float):
	modulate = Color.RED
	var knockback_dir = (global_position - get_tree().get_first_node_in_group("Player").global_position).normalized()
	global_position += knockback_dir * 10.0

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.05)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)

	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
