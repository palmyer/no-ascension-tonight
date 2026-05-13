extends Area2D
class_name HurtboxComponent

signal hit(damage: float)

@export var health_component: HealthComponent

func _ready():
	area_entered.connect(_on_area_entered)
	# Hurtbox 必须开启 monitoring 才能检测到 Hitbox
	monitoring = true

func _on_area_entered(area: Area2D):
	if area is HitboxComponent:
		var hitbox = area as HitboxComponent
		print("[DEBUG] Hurtbox (", name, ") hit by: ", area.name, " from ", area.owner.name if area.owner else area.get_parent().name, " Damage: ", hitbox.damage)
		if health_component:
			health_component.damage(hitbox.damage)
		hit.emit(hitbox.damage)
