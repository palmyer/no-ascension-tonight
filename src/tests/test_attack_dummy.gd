extends Node2D

@export var test_attack_range: float = 1200.0

func _ready() -> void:
	if get_node_or_null("/root/GameManager"):
		GameManager.current_stats["attack_range"] = test_attack_range
