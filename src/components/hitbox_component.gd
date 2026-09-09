extends Area2D
class_name HitboxComponent

@export var damage: float = 20.0

var critical_chance: float = 0.0
var critical_multiplier: float = 1.5
var critical_explosion_radius: float = 0.0
var critical_explosion_damage_pct: float = 0.0
var critical_color: Color = Color("f6c857")
var last_was_critical: bool = false
var last_applied_damage: float = 0.0

func _ready():
	# 确保 Hitbox 默认是开启的 monitorable，这样 Hurtbox 才能检测到它
	# 具体开关由使用者（如 player.gd）在攻击时控制
	monitorable = true
	monitoring = false
