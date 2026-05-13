extends Area2D
class_name HitboxComponent

@export var damage: float = 20.0

func _ready():
	# 确保 Hitbox 默认是开启的 monitorable，这样 Hurtbox 才能检测到它
	# 具体开关由使用者（如 Player.gd）在攻击时控制
	monitorable = true
	monitoring = false
