extends Node2D

var weapon_damage: float = 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	look_at(get_global_mouse_position())
	$Sprite2D/AnimationPlayer.play("slash")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "slash":
		queue_free()


func _on_area_2d_body_entered(body: Node2D) -> void:
	body.take_damage(weapon_damage)
