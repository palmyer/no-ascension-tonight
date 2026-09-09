extends CharacterBody2D
class_name Bullet

@export var speed: float = 600.0
@export var damage: float = 20.0
@export var lifetime: float = 2.0
@export var color: Color = Color.GOLD
@export var piercing: bool = false
@export var max_hits: int = 1
var attribute_payload: Dictionary = {}
var hit_targets: Dictionary = {}
var remaining_hits: int = 1
var return_enabled: bool = false
var return_damage_multiplier: float = 0.65
var return_pierce_count: int = 1
var return_speed: float = 820.0
var returning: bool = false

@onready var hitbox: HitboxComponent = $HitboxComponent

func _ready():
	$Visual.color = color
	hitbox.damage = damage
	remaining_hits = maxi(max_hits, 1) if piercing else 1
	# 弹药通常持续开启判定
	hitbox.monitoring = true
	hitbox.monitorable = true
	
	# 自动销毁计时
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float):
	if returning:
		var player := get_tree().get_first_node_in_group("Player")
		if not player or not is_instance_valid(player):
			queue_free()
			return
		if global_position.distance_to(player.global_position) <= 24.0:
			queue_free()
			return
		global_position = global_position.move_toward(player.global_position, return_speed * delta)
		rotation = global_position.direction_to(player.global_position).angle()
		return
	var velocity_vec = Vector2.RIGHT.rotated(rotation) * speed
	var collision = move_and_collide(velocity_vec * delta)
	if collision:
		if return_enabled:
			_start_return()
		else:
			queue_free()

func _start_return() -> void:
	if returning:
		return
	returning = true
	hit_targets.clear()
	remaining_hits = maxi(return_pierce_count, 1)
	hitbox.damage = damage * return_damage_multiplier
	hitbox.last_applied_damage = 0.0

func _on_hitbox_component_area_entered(_area: Area2D):
	if not (_area is HurtboxComponent):
		return
	var target := _area.get_parent()
	if not target or not target.has_method("apply_attribute_payload"):
		return
	var target_id := target.get_instance_id()
	if hit_targets.has(target_id):
		return
	hit_targets[target_id] = true
	var applied_damage := hitbox.last_applied_damage if hitbox.last_applied_damage > 0.0 else damage
	target.apply_attribute_payload(attribute_payload, applied_damage, global_position)
	if target.has_method("add_fracture"):
		target.add_fracture(applied_damage)
	GameManager.register_attribute_overload(attribute_payload, target.global_position, applied_damage)
	if return_enabled and not returning:
		_start_return()
		return
	remaining_hits -= 1
	if remaining_hits <= 0:
		queue_free()
