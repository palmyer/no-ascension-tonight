extends Node
class_name HealthComponent

signal health_changed(new_health, max_health)
signal died

@export var max_health: float = 10000.0
@onready var current_health: float = max_health

func damage(amount: float):
	current_health = clamp(current_health - amount, 0, max_health)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		died.emit()

func heal(amount: float):
	current_health = clamp(current_health + amount, 0, max_health)
	health_changed.emit(current_health, max_health)
