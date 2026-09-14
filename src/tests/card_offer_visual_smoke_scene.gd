extends Node2D

const OUTPUT_PATH := "user://no_ascension_card_offer_smoke.png"


func _ready() -> void:
	GameManager.start_new_run()
	var level: Node = load("res://scenes/levels/first_level.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	EventBus.level_up.emit(2)
	await get_tree().process_frame
	await get_tree().process_frame

	if DisplayServer.get_name() == "headless":
		print("Card offer visual smoke: level-up startup passed; render capture unavailable in headless mode")
	else:
		var texture: Texture2D = get_viewport().get_texture()
		if texture:
			var image := texture.get_image()
			if image:
				image.save_png(OUTPUT_PATH)
				print("Card offer visual smoke: level-up startup passed; rendered image saved: ", OUTPUT_PATH)
			else:
				print("Card offer visual smoke: level-up startup passed; rendered image was unavailable")
		else:
			print("Card offer visual smoke: level-up startup passed; rendered image was unavailable")

	get_tree().paused = false
	GameManager.reset_game()
	get_tree().quit()
