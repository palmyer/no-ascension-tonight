extends MeleeWeapon
class_name Blade

@onready var visual: Sprite2D = $Visual
var base_visual_scale: Vector2 = Vector2.ONE

func _ready():
	super._ready()
	base_visual_scale = visual.scale
	weapon_name = "Steel Blade"
	base_damage = 15.0
	base_range = 130.0
	base_cooldown = 0.5

func attack(_target_pos: Vector2):
	is_attacking = true
	is_swinging = false
	hit_targets.clear()
	
	var speed_mult = get_speed_multiplier()
	var original_rot = rotation
	
	var prep_time = 0.08 / speed_mult
	var swing_time = 0.12 / speed_mult
	var recover_time = 0.2 / speed_mult
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "rotation", original_rot - PI/2, prep_time)
	tween.tween_property(visual, "scale", base_visual_scale * 0.8, prep_time)
	await tween.finished
	
	is_swinging = true
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "rotation", original_rot + PI/2, swing_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "scale", base_visual_scale * 1.2, swing_time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	is_swinging = false
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "rotation", original_rot, recover_time)
	tween.tween_property(visual, "scale", base_visual_scale, recover_time)
	await tween.finished
	
	cooldown_timer = base_cooldown / speed_mult
	is_attacking = false
