extends Node2D

const OUTPUT_PATH := "user://no_ascension_boss_smoke.png"
const BOSS_SCENE = preload("res://scenes/entities/bosses/boss_red_crack.tscn")

func _ready() -> void:
	GameManager.start_new_run()
	var level: Node = load("res://scenes/levels/first_level.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var gameplay: Node = level.get_node("Gameplay")
	var ids := ["RedCrack", "GreenPlague", "BlueArc", "YellowSand", "AscensionKing"]
	var positions := [Vector2(-260, -160), Vector2(260, -160), Vector2(260, 170), Vector2(-260, 170), Vector2(0, 350)]
	for index in range(ids.size()):
		var boss: BossRedCrack = BOSS_SCENE.instantiate()
		boss.configure_boss(ids[index], {"display_name": ids[index], "health": 900.0, "speed": 50.0, "contact_damage": 12.0, "dash_damage": 20.0, "charge_cooldown": 9.0, "charge_aim_time": 1.8, "ability_cooldown": 4.0})
		boss.position = positions[index]
		gameplay.add_child(boss)
	GameManager.current_state = GameManager.GameState.NIGHT
	for _frame in range(90):
		await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		print("Boss visual smoke: scene startup passed; render capture unavailable in headless mode")
	else:
		var texture: Texture2D = get_viewport().get_texture()
		if texture:
			var image := texture.get_image()
			if image:
				image.save_png(OUTPUT_PATH)
				print("Boss visual smoke: scene startup passed; rendered image saved: ", OUTPUT_PATH)
			else:
				print("Boss visual smoke: scene startup passed; rendered image was unavailable")
		else:
			print("Boss visual smoke: scene startup passed; rendered image was unavailable")
	GameManager.reset_game()
	get_tree().quit()
