extends Control

const FIRST_LEVEL_SCENE := "res://scenes/levels/first_level.tscn"

var main_view: Control
var settings_view: Control
var weapon_view: Control
var resolution_option: OptionButton
var mode_option: OptionButton
var selected_weapon_label: Label
var preview_title: Label
var preview_subtitle: Label
var preview_description: Label
var preview_weapon_icon: Label
var weapon_buttons: Dictionary = {}

const COLOR_BACKGROUND := Color("07151d")
const COLOR_PANEL := Color("0e2730")
const COLOR_PANEL_DARK := Color("0a1e27")
const COLOR_TEXT := Color("f2e5bf")
const COLOR_MUTED := Color("9cb4a7")
const COLOR_GOLD := Color("c7a45b")
const COLOR_RED := Color("b84949")
const COLOR_GREEN := Color("5ca875")
const COLOR_BLUE := Color("5b91ca")
const COLOR_YELLOW := Color("c7a553")
const CHARACTER_PORTRAIT = preload("res://assets/textures/player/player_256.png")
const WEAPON_MARKS := {"sword": "剑", "blade": "刃", "spear": "枪", "musket": "铳"}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.game_started = false
	_build_views()
	_show_view(main_view)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BACKGROUND)
	var center := size * 0.5
	draw_circle(center, 420.0, Color(0.08, 0.2, 0.23, 0.35))
	draw_circle(center, 250.0, Color(0.14, 0.31, 0.3, 0.2))
	var directions = [
		[Vector2.UP, COLOR_RED],
		[Vector2.RIGHT, COLOR_BLUE],
		[Vector2.DOWN, COLOR_GREEN],
		[Vector2.LEFT, COLOR_YELLOW]
	]
	for item in directions:
		var direction: Vector2 = item[0]
		var color: Color = item[1]
		color.a = 0.18
		draw_line(center + direction * 160.0, center + direction * 900.0, color, 2.0)

func _build_views() -> void:
	var main_data = _make_view(Vector2(560, 620))
	main_view = main_data.view
	var main_content: VBoxContainer = main_data.content
	_add_heading(main_content, "今晚不飞升", "NO ASCENSION TONIGHT", 52)
	_add_spacer(main_content, 24)
	var tagline := Label.new()
	tagline.text = "白日入山斩妖，夜晚守住灵核道基。"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 18)
	tagline.add_theme_color_override("font_color", COLOR_MUTED)
	main_content.add_child(tagline)
	_add_spacer(main_content, 28)

	var start_button := _make_button("开始游戏", Vector2(360, 58), COLOR_GOLD)
	start_button.pressed.connect(_show_weapon_view)
	main_content.add_child(start_button)

	var settings_button := _make_button("设置", Vector2(360, 52), COLOR_BLUE)
	settings_button.pressed.connect(_show_settings_view)
	main_content.add_child(settings_button)

	var quit_button := _make_button("退出", Vector2(360, 48), COLOR_MUTED)
	quit_button.pressed.connect(get_tree().quit)
	main_content.add_child(quit_button)

	_add_spacer(main_content, 20)
	var version := Label.new()
	version.text = "第一关 · 灵核初醒"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_color_override("font_color", Color("687f78"))
	main_content.add_child(version)

	var settings_data = _make_view(Vector2(620, 520))
	settings_view = settings_data.view
	var settings_content: VBoxContainer = settings_data.content
	_add_heading(settings_content, "设置", "DISPLAY SETTINGS", 36)
	_add_spacer(settings_content, 20)
	resolution_option = OptionButton.new()
	resolution_option.custom_minimum_size = Vector2(420, 48)
	resolution_option.add_theme_font_size_override("font_size", 18)
	for resolution in SettingsManager.RESOLUTION_OPTIONS:
		var index := resolution_option.item_count
		resolution_option.add_item("%d × %d" % [resolution.x, resolution.y])
		resolution_option.set_item_metadata(index, resolution)
		if resolution == SettingsManager.resolution:
			resolution_option.select(index)
	resolution_option.item_selected.connect(_on_resolution_selected)
	settings_content.add_child(_make_labeled_control("分辨率", resolution_option))

	mode_option = OptionButton.new()
	mode_option.custom_minimum_size = Vector2(420, 48)
	mode_option.add_theme_font_size_override("font_size", 18)
	mode_option.add_item("窗口")
	mode_option.add_item("全屏")
	mode_option.select(1 if SettingsManager.fullscreen else 0)
	mode_option.item_selected.connect(_on_mode_selected)
	settings_content.add_child(_make_labeled_control("显示模式", mode_option))

	_add_spacer(settings_content, 24)
	var settings_hint := Label.new()
	settings_hint.text = "设置会自动保存到本机。全屏模式下分辨率作为下次窗口模式尺寸保存。"
	settings_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_hint.add_theme_color_override("font_color", COLOR_MUTED)
	settings_content.add_child(settings_hint)
	_add_spacer(settings_content, 20)
	var settings_back := _make_button("返回", Vector2(420, 50), COLOR_MUTED)
	settings_back.pressed.connect(_show_main_view)
	settings_content.add_child(settings_back)

	var weapon_data = _make_view(Vector2(900, 720))
	weapon_view = weapon_data.view
	var weapon_content: VBoxContainer = weapon_data.content
	_add_heading(weapon_content, "选择本命法宝", "CHOOSE YOUR ARTIFACT", 36)
	var weapon_hint := Label.new()
	weapon_hint.text = "每局选择一把本命武器。法宝会随着四色灵性继续蜕变。"
	weapon_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_hint.add_theme_color_override("font_color", COLOR_MUTED)
	weapon_content.add_child(weapon_hint)
	_add_spacer(weapon_content, 12)

	var preview_row := HBoxContainer.new()
	preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_row.add_theme_constant_override("separation", 18)
	weapon_content.add_child(preview_row)
	var portrait := TextureRect.new()
	portrait.texture = CHARACTER_PORTRAIT
	portrait.custom_minimum_size = Vector2(150, 150)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_row.add_child(portrait)
	var preview_copy := VBoxContainer.new()
	preview_copy.custom_minimum_size = Vector2(360, 150)
	preview_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_row.add_child(preview_copy)
	preview_title = Label.new()
	preview_title.add_theme_font_size_override("font_size", 26)
	preview_title.add_theme_color_override("font_color", COLOR_TEXT)
	preview_copy.add_child(preview_title)
	preview_subtitle = Label.new()
	preview_subtitle.add_theme_font_size_override("font_size", 15)
	preview_subtitle.add_theme_color_override("font_color", COLOR_GOLD)
	preview_copy.add_child(preview_subtitle)
	preview_description = Label.new()
	preview_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_description.add_theme_font_size_override("font_size", 14)
	preview_description.add_theme_color_override("font_color", COLOR_MUTED)
	preview_copy.add_child(preview_description)
	preview_weapon_icon = Label.new()
	preview_weapon_icon.custom_minimum_size = Vector2(78, 78)
	preview_weapon_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_weapon_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_weapon_icon.add_theme_font_size_override("font_size", 48)
	preview_weapon_icon.add_theme_color_override("font_color", COLOR_GOLD)
	preview_row.add_child(preview_weapon_icon)
	_add_spacer(weapon_content, 10)

	var weapon_grid := GridContainer.new()
	weapon_grid.columns = 2
	weapon_grid.add_theme_constant_override("h_separation", 14)
	weapon_grid.add_theme_constant_override("v_separation", 14)
	weapon_content.add_child(weapon_grid)
	for weapon_id in GameManager.STARTING_WEAPON_ORDER:
		var data: Dictionary = GameManager.STARTING_WEAPONS[weapon_id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(390, 118)
		button.toggle_mode = true
		button.text = "%s\n%s\n%s" % [data.name, data.subtitle, data.description]
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", COLOR_TEXT)
		button.add_theme_stylebox_override("normal", _make_panel_style(COLOR_PANEL_DARK, Color("41646a"), 1))
		button.add_theme_stylebox_override("hover", _make_panel_style(Color("193844"), COLOR_GOLD, 2))
		button.add_theme_stylebox_override("pressed", _make_panel_style(Color("254c50"), COLOR_GOLD, 2))
		button.pressed.connect(_select_weapon.bind(weapon_id))
		weapon_grid.add_child(button)
		weapon_buttons[weapon_id] = button

	selected_weapon_label = Label.new()
	selected_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_weapon_label.add_theme_color_override("font_color", COLOR_GOLD)
	weapon_content.add_child(selected_weapon_label)
	_add_spacer(weapon_content, 8)
	var weapon_actions := HBoxContainer.new()
	weapon_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	weapon_actions.add_theme_constant_override("separation", 14)
	weapon_content.add_child(weapon_actions)
	var weapon_back := _make_button("返回", Vector2(220, 52), COLOR_MUTED)
	weapon_back.pressed.connect(_show_main_view)
	weapon_actions.add_child(weapon_back)
	var begin_button := _make_button("开始", Vector2(300, 56), COLOR_GOLD)
	begin_button.pressed.connect(_start_game)
	weapon_actions.add_child(begin_button)
	_select_weapon(GameManager.selected_weapon_id)

func _make_view(panel_size: Vector2) -> Dictionary:
	var view := Control.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(view)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = panel_size
	panel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_PANEL, COLOR_GOLD, 1))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	return {"view": view, "content": content}

func _add_heading(content: VBoxContainer, title_text: String, subtitle_text: String, font_size: int) -> void:
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", font_size)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", COLOR_GOLD)
	content.add_child(subtitle)

func _make_button(text: String, minimum_size: Vector2, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _make_panel_style(COLOR_PANEL_DARK, Color(accent, 0.45), 1))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color("193844"), accent, 2))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color("254c50"), accent, 2))
	return button

func _make_labeled_control(label_text: String, control: Control) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", COLOR_MUTED)
	group.add_child(label)
	group.add_child(control)
	return group

func _make_panel_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	return style

func _add_spacer(content: VBoxContainer, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, height)
	content.add_child(spacer)

func _show_view(view: Control) -> void:
	main_view.visible = view == main_view
	settings_view.visible = view == settings_view
	weapon_view.visible = view == weapon_view

func _show_main_view() -> void:
	_show_view(main_view)

func _show_settings_view() -> void:
	_show_view(settings_view)

func _show_weapon_view() -> void:
	_show_view(weapon_view)

func _on_resolution_selected(index: int) -> void:
	SettingsManager.set_resolution(resolution_option.get_item_metadata(index))

func _on_mode_selected(index: int) -> void:
	SettingsManager.set_fullscreen(index == 1)

func _select_weapon(weapon_id: String) -> void:
	if not weapon_buttons.has(weapon_id):
		return
	GameManager.select_starting_weapon(weapon_id)
	for id in weapon_buttons:
		var button: Button = weapon_buttons[id]
		button.button_pressed = id == weapon_id
		button.self_modulate = Color.WHITE if id == weapon_id else Color(0.72, 0.78, 0.75, 1.0)
	var selected: Dictionary = GameManager.get_selected_weapon()
	selected_weapon_label.text = "已选择：%s · %s" % [selected.name, selected.subtitle]
	if preview_title:
		preview_title.text = str(selected.get("name", "本命法宝"))
		preview_subtitle.text = str(selected.get("subtitle", ""))
		preview_description.text = str(selected.get("description", ""))
		preview_weapon_icon.text = str(WEAPON_MARKS.get(weapon_id, "法"))

func _start_game() -> void:
	GameManager.start_new_run()
	get_tree().change_scene_to_file(FIRST_LEVEL_SCENE)
