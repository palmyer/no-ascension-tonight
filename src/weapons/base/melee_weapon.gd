extends WeaponBase
class_name MeleeWeapon

@onready var hitbox: HitboxComponent = $HitboxComponent

var is_swinging: bool = false
var hit_targets: Array[Node2D] = []

func _ready():
	super._ready()
	if hitbox:
		hitbox.monitoring = true
		hitbox.monitorable = true

func _physics_process(delta: float):
	super._physics_process(delta)
	
	if is_attacking and is_swinging:
		process_aoe_damage()

func process_aoe_damage():
	if not hitbox: return
	
	var overlapping_areas = hitbox.get_overlapping_areas()
	var final_damage = base_damage * get_damage_multiplier()
	
	for area in overlapping_areas:
		if area is HurtboxComponent:
			var enemy = area.owner
			if enemy and not hit_targets.has(enemy):
				hit_targets.append(enemy)
				area.emit_signal("hit", final_damage)

func get_effective_range() -> float:
	# 近战逻辑：继承 50% 的远程范围加成
	var ranged_bonus = GameManager.current_stats.get("attack_range", 600.0) - 600.0
	return base_range + (ranged_bonus * 0.5)
