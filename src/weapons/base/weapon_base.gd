extends Node2D
class_name WeaponBase

@export var weapon_name: String = "Generic Weapon"
@export var base_damage: float = 10.0
@export var base_range: float = 100.0
@export var base_cooldown: float = 1.0

var wielder: Node2D
var is_attacking: bool = false
var cooldown_timer: float = 0.0

func equip(p_wielder: Node2D):
	wielder = p_wielder

func _ready():
	pass

func can_attack() -> bool:
	return not is_attacking and cooldown_timer <= 0.0

func attack(_target_pos: Vector2):
	# To be overridden
	pass

func get_effective_range() -> float:
	return base_range

func get_speed_multiplier() -> float:
	return 1.0 + GameManager.current_stats.get("attack_speed", 0.0) / 100.0

func get_damage_multiplier() -> float:
	return 1.0 + GameManager.current_stats.get("damage_pct", 0.0) / 100.0

func _physics_process(delta: float):
	if cooldown_timer > 0:
		cooldown_timer -= delta
