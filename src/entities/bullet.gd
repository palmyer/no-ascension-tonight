extends CharacterBody2D
class_name Bullet

@export var speed: float = 600.0
@export var damage: float = 20.0
@export var lifetime: float = 2.0
@export var color: Color = Color.GOLD

@onready var hitbox: HitboxComponent = $HitboxComponent

func _ready():
	$Visual.color = color
	hitbox.damage = damage
	# 弹药通常持续开启判定
	hitbox.monitoring = true
	hitbox.monitorable = true
	
	# 自动销毁计时
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float):
	var velocity_vec = Vector2.RIGHT.rotated(rotation) * speed
	var collision = move_and_collide(velocity_vec * delta)
	if collision:
		# 撞击到任何东西（如墙壁）就消失
		queue_free()

func _on_hitbox_component_area_entered(_area: Area2D):
	# 击中目标后消失
	queue_free()
