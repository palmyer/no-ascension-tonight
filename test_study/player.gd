extends CharacterBody2D

const move_speed = 2500

var current_look_dir = "right"

var can_slash: bool = true
@export var slash_time: float = 0.2
@export var sword_return_time: float = 0.5
@export var weapon_damage: float = 1.0

func _physics_process(delta: float) -> void:
	var input = Vector2(Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")).normalized()
	velocity = input * move_speed * delta
	move_and_slide()
	
	if current_look_dir == "right" and get_global_mouse_position().x < global_position.x:
		$Sprite2D/flip_anim.play("look_left")
		current_look_dir = "left"
	elif current_look_dir == "left" and get_global_mouse_position().x > global_position.x:
		$Sprite2D/flip_anim.play("look_right")
		current_look_dir = "right"
		
	if get_global_mouse_position().y > global_position.y:
		$Sprite2D/sword.show_behind_parent = false
		$Sprite2D.frame = 0
	else:
		$Sprite2D/sword.show_behind_parent = true
		$Sprite2D.frame = 1
		
	if Input.is_action_pressed("attack") and can_slash:
		$Sprite2D/sword/AnimationPlayer.speed_scale = $Sprite2D/sword/AnimationPlayer.get_animation("slash").length / slash_time
		$Sprite2D/sword/AnimationPlayer.play("slash")
		can_slash = false

func spawn_slash():
	pass
