extends RangedWeapon
class_name Musket

func _ready():
	super._ready()
	weapon_name = "Fire Musket"
	base_damage = 25.0
	base_range = 600.0
	base_cooldown = 1.0
	bullet_count = 1
	spread_angle = 5.0
	if not projectile_scene:
		projectile_scene = preload("res://scenes/Bullet.tscn")

func attack(target_pos: Vector2):
	# 远程武器在发射前瞬间再次对准目标，确保精准
	look_at(target_pos)
	await super.attack(target_pos)
