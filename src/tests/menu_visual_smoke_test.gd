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
	var image := get_root().get_texture().get_image()
	if image:
		image.save_png(OUTPUT_PATH)
	print("Menu visual smoke screenshot: ", OUTPUT_PATH)
	menu._show_weapon_view()
	await process_frame
	await process_frame
	var weapon_image := get_root().get_texture().get_image()
	if weapon_image:
		weapon_image.save_png(WEAPON_OUTPUT_PATH)
	print("Weapon visual smoke screenshot: ", WEAPON_OUTPUT_PATH)
	quit(0)
