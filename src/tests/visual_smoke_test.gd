extends SceneTree

const OUTPUT_PATH := "user://no_ascension_visual_smoke.png"

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var game_manager: Node = root.get_node("GameManager")
	game_manager.start_new_run()
	var level: Node = load("res://scenes/levels/first_level.tscn").instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	await process_frame
	var image := get_root().get_texture().get_image()
	if image:
		image.save_png(OUTPUT_PATH)
	print("Visual smoke screenshot: ", OUTPUT_PATH)
	game_manager.reset_game()
	quit(0)
