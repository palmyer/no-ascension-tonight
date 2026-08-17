extends MeleeWeapon
class_name Spear

@onready var visual: Sprite2D = $Visual
var base_visual_scale: Vector2 = Vector2.ONE

func _ready():
	super._ready()
	base_visual_scale = visual.scale
	weapon_name = "Dragon Spear"
	base_damage = 22.0
	base_range = 180.0
	base_cooldown = 0.6

func attack(_target_pos: Vector2):
	is_attacking = true
	is_swinging = true # 刺击过程中都有伤害
	hit_targets.clear()
	
	var speed_mult = get_speed_multiplier()
	var original_pos = position
	
	# 戳刺距离加成 (1.2x)
	var thrust_dist = 80.0 * (get_effective_range() / base_range) * 1.2
	var thrust_time = 0.08 / speed_mult
	var recover_time = 0.2 / speed_mult
	
	var tween = create_tween()
	# 伸展视觉
	visual.scale = Vector2(base_visual_scale.x * 1.2, base_visual_scale.y * 0.8)
	
	# 向前突刺
	tween.tween_property(self, "position", original_pos + Vector2.RIGHT.rotated(rotation) * thrust_dist, thrust_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	is_swinging = false
	tween = create_tween()
	# 收回
	tween.tween_property(self, "position", original_pos, recover_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(visual, "scale", base_visual_scale, recover_time)
	await tween.finished
	
	cooldown_timer = base_cooldown / speed_mult
	is_attacking = false
