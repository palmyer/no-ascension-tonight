extends Control

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const LOGO_TEXTURE := preload("res://assets/textures/ui/game_logo_cultivation_mountain_orb_sun_white_rounded.png")
var has_transitioned := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_logo()
	var timer := get_tree().create_timer(1.8)
	timer.timeout.connect(_open_main_menu)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("07141b"))
	var center := size * 0.5
	draw_circle(center, 250.0, Color(0.12, 0.28, 0.3, 0.18))
	draw_circle(center, 160.0, Color(0.16, 0.42, 0.38, 0.16))
	for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_line(center + direction * 80.0, center + direction * 420.0, Color(0.67, 0.55, 0.3, 0.22), 2.0)

func _build_logo() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	center.add_child(content)

	var logo := TextureRect.new()
	logo.custom_minimum_size = Vector2(240, 240)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture = LOGO_TEXTURE
	content.add_child(logo)

	var title := Label.new()
	title.text = "今晚不飞升"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("f3e4bf"))
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "NO ASCENSION TONIGHT"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("b69d6b"))
	content.add_child(subtitle)

	var line := HSeparator.new()
	line.custom_minimum_size = Vector2(260, 1)
	content.add_child(line)

	var hint := Label.new()
	hint.text = "山海秘境 · 灵核将醒"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color("8fb8a7"))
	content.add_child(hint)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_open_main_menu()
	elif event is InputEventMouseButton and event.pressed:
		_open_main_menu()

func _open_main_menu() -> void:
	if has_transitioned:
		return
	has_transitioned = true
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
