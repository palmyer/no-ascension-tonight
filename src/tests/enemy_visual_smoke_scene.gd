extends Node2D

const OUTPUT_PATH := "user://no_ascension_enemy_smoke.png"
const ENEMY_SCENE = preload("res://scenes/entities/enemies/enemy.tscn")


func _ready() -> void:
	GameManager.start_new_run()

	var level: Node = load("res://scenes/levels/first_level.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var gameplay: Node = level.get_node("Gameplay")
	var positions := [
		Vector2(-420.0, -120.0),
		Vector2(-250.0, -120.0),
		Vector2(-80.0, -120.0),
		Vector2(90.0, -120.0),
		Vector2(260.0, -120.0),
		Vector2(430.0, -120.0),
	]

	for index in range(6):
		var enemy: Enemy = ENEMY_SCENE.instantiate()
		enemy.enemy_type = index
		enemy.position = positions[index]
		gameplay.add_child(enemy)

	for _frame in range(2):
		await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	if image:
		image.save_png(OUTPUT_PATH)
	print("Enemy visual smoke screenshot: ", OUTPUT_PATH)

	GameManager.reset_game()
	get_tree().quit()
