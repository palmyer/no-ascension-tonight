extends StaticBody2D
class_name TrainingDummy

@export var max_health: float = 1000000.0
var current_health: float = max_health

func _ready() -> void:
	add_to_group("DamageableEnemy")
	current_health = max_health

func take_damage(amount: float) -> void:
	current_health = max(current_health - amount, 0.0)
