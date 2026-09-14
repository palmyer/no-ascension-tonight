extends SceneTree

const OUTPUT_PATH := "user://no_ascension_menu_smoke.png"
const WEAPON_OUTPUT_PATH := "user://no_ascension_weapon_smoke.png"

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("Menu visual smoke: scene startup passed; render capture unavailable in headless mode")
	else:
		var texture: Texture2D = get_root().get_texture()
		if texture:
			var image := texture.get_image()
			if image:
				image.save_png(OUTPUT_PATH)
				print("Menu visual smoke: scene startup passed; rendered image saved: ", OUTPUT_PATH)
			else:
				print("Menu visual smoke: scene startup passed; rendered image was unavailable")
		else:
			print("Menu visual smoke: scene startup passed; rendered image was unavailable")
	menu._show_weapon_view()
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("Weapon visual smoke: weapon view startup passed; render capture unavailable in headless mode")
	else:
		var weapon_texture: Texture2D = get_root().get_texture()
		if weapon_texture:
			var weapon_image := weapon_texture.get_image()
			if weapon_image:
				weapon_image.save_png(WEAPON_OUTPUT_PATH)
				print("Weapon visual smoke: weapon view startup passed; rendered image saved: ", WEAPON_OUTPUT_PATH)
			else:
				print("Weapon visual smoke: weapon view startup passed; rendered image was unavailable")
		else:
			print("Weapon visual smoke: weapon view startup passed; rendered image was unavailable")
	quit(0)
