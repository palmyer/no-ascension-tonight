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
	if DisplayServer.get_name() == "headless":
		print("Visual smoke: scene startup passed; render capture unavailable in headless mode")
	else:
		var texture: Texture2D = get_root().get_texture()
		if texture:
			var image := texture.get_image()
			if image:
				image.save_png(OUTPUT_PATH)
				print("Visual smoke: scene startup passed; rendered image saved: ", OUTPUT_PATH)
			else:
				print("Visual smoke: scene startup passed; rendered image was unavailable")
		else:
			print("Visual smoke: scene startup passed; rendered image was unavailable")
	game_manager.reset_game()
	quit(0)
