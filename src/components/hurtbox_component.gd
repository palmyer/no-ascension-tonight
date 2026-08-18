extends Area2D
class_name HurtboxComponent

signal hit(damage: float)

@export var health_component: HealthComponent
@export var hit_cooldown: float = 1.0
@export var flat_damage_reduction: float = 0.0
@export var low_health_threshold: float = 0.35
@export var low_health_damage_reduction: float = 0.0

var _source_cooldowns: Dictionary = {}

func _ready():
	area_entered.connect(_on_area_entered)
	# Hurtbox 必须开启 monitoring 才能检测到 Hitbox
	monitoring = true

func _on_area_entered(area: Area2D):
	if area is HitboxComponent:
		var hitbox = area as HitboxComponent
		print("[DEBUG] Hurtbox (", name, ") hit by: ", area.name, " from ", area.owner.name if area.owner else area.get_parent().name, " Damage: ", hitbox.damage)
		_apply_hit_from_source(area.get_instance_id(), hitbox.damage)
	else:
		print("[DEBUG] Hurtbox (", name, ") entered by non-hitbox: ", area.name)

func _physics_process(delta: float) -> void:
	for source_id in _source_cooldowns.keys():
		_source_cooldowns[source_id] = _source_cooldowns[source_id] - delta
		if _source_cooldowns[source_id] <= 0.0:
			_source_cooldowns.erase(source_id)

	# 持续重叠时按内置 CD 结算伤害
	for area in get_overlapping_areas():
		if area is HitboxComponent:
			var hitbox := area as HitboxComponent
			_apply_hit_from_source(area.get_instance_id(), hitbox.damage)

func _apply_hit_from_source(source_id: int, damage: float) -> void:
	if _source_cooldowns.has(source_id):
		return
	var final_damage := get_final_damage(damage)
	if health_component:
		health_component.damage(final_damage)
	hit.emit(final_damage)
	_source_cooldowns[source_id] = hit_cooldown

func get_final_damage(damage: float) -> float:
	var final_damage := maxf(damage - flat_damage_reduction, 0.0)
	if health_component and health_component.max_health > 0.0:
		var health_ratio := health_component.current_health / health_component.max_health
		if health_ratio <= low_health_threshold:
			var reduction := clampf(low_health_damage_reduction / 100.0, 0.0, 1.0)
			final_damage *= 1.0 - reduction
	return final_damage
