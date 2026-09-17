extends Area2D
class_name HurtboxComponent

signal hit(damage: float)

@export var health_component: HealthComponent
@export var hit_cooldown: float = 1.0
@export var flat_damage_reduction: float = 0.0
@export var low_health_threshold: float = 0.35
@export var low_health_damage_reduction: float = 0.0

var _source_cooldowns: Dictionary = {}
# 最近一次命中的来源世界坐标，供宿主（如重装妖的正面格挡）判定受击方向。
var last_hit_origin: Vector2 = Vector2.INF
# 最近一次命中是否暴击，供伤害飘字与 hitstop 反馈读取。
var last_hit_critical: bool = false

func _ready():
	area_entered.connect(_on_area_entered)
	# Hurtbox 必须开启 monitoring 才能检测到 Hitbox
	monitoring = true

func _on_area_entered(area: Area2D):
	if area is HitboxComponent:
		var hitbox = area as HitboxComponent
		if get_node_or_null("/root/GameManager") and GameManager.debug_mode:
			print("[DEBUG] Hurtbox (", name, ") hit by: ", area.name, " from ", area.owner.name if area.owner else area.get_parent().name, " Damage: ", hitbox.damage)
		_apply_hit_from_source(hitbox)
	else:
		if get_node_or_null("/root/GameManager") and GameManager.debug_mode:
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
			_apply_hit_from_source(hitbox)


func _apply_hit_from_source(hitbox: HitboxComponent) -> void:
	var source_id := hitbox.get_instance_id()
	if _source_cooldowns.has(source_id):
		return
	# Keep critical logic here so melee/ranged hitboxes share one damage pipeline.
	var final_damage := get_final_damage(hitbox.damage)
	hitbox.last_was_critical = false
	if hitbox.critical_chance > 0.0 and randf() < hitbox.critical_chance:
		final_damage *= maxf(hitbox.critical_multiplier, 1.0)
		hitbox.last_was_critical = true
		if hitbox.critical_explosion_radius > 0.0 and hitbox.critical_explosion_damage_pct > 0.0:
			GameManager.spawn_burst_damage(global_position, hitbox.critical_explosion_radius, final_damage * hitbox.critical_explosion_damage_pct, {}, hitbox.critical_color)
	hitbox.last_applied_damage = final_damage
	var owner_node := get_parent()
	if owner_node and owner_node.has_method("resolve_incoming_damage"):
		last_hit_origin = hitbox.global_position
		last_hit_critical = bool(hitbox.last_was_critical)
		owner_node.resolve_incoming_damage(final_damage)
	elif health_component:
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
