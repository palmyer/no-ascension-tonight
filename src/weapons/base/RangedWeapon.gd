extends WeaponBase
class_name RangedWeapon

@export var projectile_scene: PackedScene
@export var bullet_count: int = 1
@export var spread_angle: float = 15.0

func attack(_target_pos: Vector2):
	is_attacking = true
	var speed_mult = get_speed_multiplier()
	var final_damage = base_damage * get_damage_multiplier()
	
	var count = bullet_count
	# 这里可以加入全局子弹数加成逻辑
	
	for i in range(count):
		var bullet = projectile_scene.instantiate()
		bullet.damage = final_damage
		var offset = (i - (count - 1) / 2.0) * deg_to_rad(spread_angle)
		bullet.global_position = global_position
		bullet.rotation = global_rotation + offset
		get_tree().root.add_child(bullet)
	
	# 后坐力动画
	var original_pos = position
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + Vector2.LEFT.rotated(rotation) * 5.0, 0.05 / speed_mult)
	tween.tween_property(self, "position", original_pos, 0.1 / speed_mult)
	
	cooldown_timer = base_cooldown / speed_mult
	await tween.finished
	is_attacking = false

func get_effective_range() -> float:
	return GameManager.current_stats.get("attack_range", base_range)
