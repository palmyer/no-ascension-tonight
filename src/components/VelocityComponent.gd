extends Node
class_name VelocityComponent

@export var max_speed: float = 300.0
@export var acceleration: float = 1500.0
@export var friction: float = 1000.0

var velocity: Vector2 = Vector2.ZERO

func accelerate_to_input(input_vector: Vector2, delta: float):
	if input_vector.length() > 0:
		velocity = velocity.move_toward(input_vector.normalized() * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

func move(body: CharacterBody2D):
	body.velocity = velocity
	body.move_and_slide()
	# 同步回真实速度（处理碰撞）
	velocity = body.velocity
