extends MeleeWeapon
class_name Sword

@onready var visual: Sprite2D = $Visual

func _ready():
	super._ready()
	weapon_name = "Spirit Sword"
	base_damage = 18.0
	base_range = 140.0
	base_cooldown = 0.4

func attack(_target_pos: Vector2):
	if randf() < 0.5:
		await attack_slash()
	else:
		await attack_stab()
	
	cooldown_timer = base_cooldown / get_speed_multiplier()

func attack_slash():
	is_attacking = true
	is_swinging = false
	hit_targets.clear()
	var speed_mult = get_speed_multiplier()
	var original_rot = rotation
	
	var prep_time = 0.08 / speed_mult
	var swing_time = 0.12 / speed_mult
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "rotation", original_rot - PI/2, prep_time)
	await tween.finished
	
	is_swinging = true
	tween = create_tween()
	tween.tween_property(self, "rotation", original_rot + PI/2, swing_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	is_swinging = false
	rotation = original_rot
	is_attacking = false

func attack_stab():
	is_attacking = true
	is_swinging = true
	hit_targets.clear()
	var speed_mult = get_speed_multiplier()
	var original_pos = position
	
	var thrust_dist = 85.0
	var thrust_time = 0.08 / speed_mult
	
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + Vector2.RIGHT.rotated(rotation) * thrust_dist, thrust_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	is_swinging = false
	tween = create_tween()
	tween.tween_property(self, "position", original_pos, 0.2 / speed_mult)
	await tween.finished
	is_attacking = false
