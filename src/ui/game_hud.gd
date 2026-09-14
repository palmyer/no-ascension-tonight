extends CanvasLayer
class_name GameHud

const LEVEL_UP_SCRIPT = preload("res://src/ui/level_up_ui.gd")
const ATTUNEMENT_SCRIPT = preload("res://src/ui/attunement_ui.gd")
const BUILD_STATUS_SCRIPT = preload("res://src/ui/build_status_hud.gd")
const TOUCH_CONTROLS_SCRIPT = preload("res://src/ui/touch_controls.gd")

const BG := Color("08171e")
const PANEL := Color("0b232b")
const PANEL_ALT := Color("102f37")
const TEXT := Color("f2e5bf")
const MUTED := Color("9cb4a7")
const GOLD := Color("e2bb6c")
const RED := Color("df6c69")
const GREEN := Color("70d29a")
const BLUE := Color("78c9e7")
const YELLOW := Color("e6c568")

var root: Control
var phase_label: Label
var wave_label: Label
var timer_label: Label
var core_bar: ProgressBar
var core_label: Label
var hp_bar: ProgressBar
var hp_label: Label
var xp_bar: ProgressBar
var xp_label: Label
var orb_labels: Array[Label] = []
var attune_label: Label
var weapon_label: Label
var attribute_label: Label
var aura_label: Label
var special_key_label: Label
var special_label: Label
var special_bar: ProgressBar
var special_hint: Label
var toast_label: Label
var toast_time := 0.0
var boss_panel: PanelContainer
var boss_title: Label
var boss_bar: ProgressBar
var boss_hint: Label
var pause_overlay: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_build_level_up_overlay()
	_build_attunement_overlay()
	_build_game_over_overlay()
	_connect_events()

func _connect_events() -> void:
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.core_damaged.connect(_on_core_damaged)
	EventBus.core_repaired.connect(_on_core_repaired)
	EventBus.special_used.connect(_on_special_used)
	EventBus.attribute_reaction.connect(_on_attribute_reaction)
	EventBus.intermission_event_chosen.connect(_on_intermission_event_chosen)
	EventBus.card_acquired.connect(_on_card_acquired)

func _process(delta: float) -> void:
	toast_time = maxf(toast_time - delta, 0.0)
	if toast_label:
		toast_label.visible = toast_time > 0.0
	_refresh_hud()

func _build_hud() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Combat HUD hierarchy: threat/readiness at the top, player resources at
	# the bottom-left, and the run build at the bottom-right.  Every panel is
	# anchored to a screen edge so the layout stays readable at 16:9 sizes.
	var top_panel := _make_corner_panel(Vector2(470, 170), Control.PRESET_TOP_LEFT, Vector2(24, 22), GOLD)
	root.add_child(top_panel)
	var top_box := _panel_box(top_panel, 14)
	var phase_row := HBoxContainer.new()
	phase_row.add_theme_constant_override("separation", 12)
	top_box.add_child(phase_row)
	phase_label = _label("昼间 · 向山门进发", 23, TEXT)
	phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_row.add_child(phase_label)
	attune_label = _label("调谐 · 未定", 13, MUTED)
	attune_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	phase_row.add_child(attune_label)
	var wave_row := HBoxContainer.new()
	wave_row.add_theme_constant_override("separation", 12)
	top_box.add_child(wave_row)
	wave_label = _label("第 1 / 20 波", 15, GOLD)
	wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_row.add_child(wave_label)
	timer_label = _label("60 秒", 26, TEXT)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wave_row.add_child(timer_label)
	core_bar = _make_bar(GOLD, Vector2(0, 14))
	core_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_box.add_child(core_bar)
	core_label = _label("灵核 100 / 100", 13, MUTED)
	top_box.add_child(core_label)

	var orb_panel := _make_corner_panel(Vector2(450, 166), Control.PRESET_TOP_RIGHT, Vector2(-24, 22), BLUE)
	root.add_child(orb_panel)
	var orb_box := _panel_box(orb_panel, 14)
	var growth_row := HBoxContainer.new()
	orb_box.add_child(growth_row)
	xp_label = _label("修为  LV.1", 17, TEXT)
	xp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var level_hint := _label("灵性收集", 12, MUTED)
	level_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	growth_row.add_child(xp_label)
	growth_row.add_child(level_hint)
	xp_bar = _make_bar(BLUE, Vector2(0, 12))
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	orb_box.add_child(xp_bar)
	var orb_row := HBoxContainer.new()
	orb_row.add_theme_constant_override("separation", 8)
	orb_box.add_child(orb_row)
	for item in [["赤", RED], ["翠", GREEN], ["蓝", BLUE], ["黄", YELLOW]]:
		var orb_label := _label("%s 0" % item[0], 16, item[1])
		orb_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		orb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		orb_row.add_child(orb_label)
		orb_labels.append(orb_label)

	var build_panel := _make_corner_panel(Vector2(520, 224), Control.PRESET_BOTTOM_LEFT, Vector2(24, -268), BLUE)
	root.add_child(build_panel)
	var build_box := _panel_box(build_panel, 16)
	var player_row := HBoxContainer.new()
	player_row.add_theme_constant_override("separation", 12)
	build_box.add_child(player_row)
	weapon_label = _label("本命法宝 · 引霜灵剑", 16, GOLD)
	weapon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_row.add_child(weapon_label)
	aura_label = _label("灵核光环 · 未进入", 13, MUTED)
	aura_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_row.add_child(aura_label)
	hp_label = _label("道基 100 / 100", 16, TEXT)
	build_box.add_child(hp_label)
	hp_bar = _make_bar(GREEN, Vector2(0, 12))
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_box.add_child(hp_bar)
	attribute_label = _label("属性  无", 15, TEXT)
	attribute_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_box.add_child(attribute_label)
	var special_row := HBoxContainer.new()
	special_row.add_theme_constant_override("separation", 10)
	build_box.add_child(special_row)
	special_key_label = _label("SPACE", 13, GOLD)
	special_key_label.add_theme_stylebox_override("normal", _make_style(Color("172f35"), GOLD, 1, 5))
	special_row.add_child(special_key_label)
	special_label = _label("诀技 · 就绪", 19, GOLD)
	special_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	special_row.add_child(special_label)
	special_bar = _make_bar(GOLD, Vector2(0, 10))
	special_bar.custom_minimum_size = Vector2(112, 10)
	special_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	special_row.add_child(special_bar)
	special_hint = _label("主动诀技", 12, MUTED)
	special_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_box.add_child(special_hint)

	var help_label := _label("WASD / 触控移动   ·   自动攻击   ·   SPACE 诀技   ·   ESC 暂停", 13, MUTED)
	help_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	help_label.position = Vector2(-390, -30)
	help_label.size = Vector2(780, 24)
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(help_label)

	toast_label = _label("", 21, GOLD)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-400, 192)
	toast_label.size = Vector2(800, 40)
	toast_label.visible = false
	root.add_child(toast_label)

	boss_panel = _make_corner_panel(Vector2(560, 126), Control.PRESET_CENTER_TOP, Vector2(-280, 246), RED)
	boss_panel.visible = false
	root.add_child(boss_panel)
	var boss_box := _panel_box(boss_panel, 14)
	boss_title = _label("大妖", 19, TEXT)
	boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_title)
	boss_bar = _make_bar(RED, Vector2(0, 14))
	boss_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_box.add_child(boss_bar)
	boss_hint = _label("", 13, MUTED)
	boss_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_hint)

	var build_status := BUILD_STATUS_SCRIPT.new()
	build_status.name = "RunBuildHud"
	root.add_child(build_status)

	var touch_controls := TOUCH_CONTROLS_SCRIPT.new()
	touch_controls.name = "TouchControls"
	touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(touch_controls)

func _build_level_up_overlay() -> void:
	var layer := LEVEL_UP_SCRIPT.new()
	layer.name = "LevelUpUI"
	var control := Control.new()
	control.name = "Control"
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.05, 0.07, 0.78)
	control.add_child(dim)
	var shell := PanelContainer.new()
	shell.name = "CardShell"
	shell.set_anchors_preset(Control.PRESET_CENTER)
	shell.position = Vector2(-620, -360)
	shell.size = Vector2(1240, 720)
	var shell_style := _make_style(Color("0b232b"), Color("b08b4f"), 2, 18)
	shell_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	shell_style.shadow_size = 24
	shell.add_theme_stylebox_override("panel", shell_style)
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(shell)

	var title := _label("灵性突破  ·  三选一", 36, GOLD)
	title.name = "Label"
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-420, -320)
	title.size = Vector2(840, 54)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control.add_child(title)
	var subtitle := _label("", 16, MUTED)
	subtitle.name = "Subtitle"
	subtitle.set_anchors_preset(Control.PRESET_CENTER)
	subtitle.position = Vector2(-600, -268)
	subtitle.size = Vector2(1200, 32)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control.add_child(subtitle)
	var cards := HBoxContainer.new()
	cards.name = "HBoxContainer"
	cards.set_anchors_preset(Control.PRESET_CENTER)
	cards.position = Vector2(-590, -206)
	cards.size = Vector2(1180, 500)
	cards.add_theme_constant_override("separation", 22)
	control.add_child(cards)
	var footer := _label("", 15, MUTED)
	footer.name = "Footer"
	footer.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	footer.position = Vector2(-600, -42)
	footer.size = Vector2(1200, 30)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control.add_child(footer)
	layer.add_child(control)
	# Keep the overlay as a direct gameplay child so tooling and tests can
	# address it without knowing the HUD implementation detail.
	var host := get_parent() if get_parent() else self
	host.add_child(layer)

func _build_attunement_overlay() -> void:
	var control := Control.new()
	control.name = "AttunementUI"
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.set_script(ATTUNEMENT_SCRIPT)
	var label := _label("调谐灵性：选择下一波偏向", 26, TEXT)
	label.name = "Label"
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position = Vector2(-280, 74)
	label.size = Vector2(560, 42)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control.add_child(label)
	add_child(control)

func _build_game_over_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GameOverUI"
	layer.set_script(load("res://src/ui/game_over_ui.gd"))
	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-300, -230)
	panel.size = Vector2(600, 460)
	panel.add_theme_stylebox_override("panel", _make_style(PANEL, GOLD, 2, 12))
	var box := VBoxContainer.new()
	box.name = "VBoxContainer"
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var message := _label("灵核破碎", 32, TEXT)
	message.name = "MessageLabel"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(message)
	var summary := _label("", 15, MUTED)
	summary.name = "SummaryLabel"
	summary.custom_minimum_size = Vector2(520, 230)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary)
	var restart := Button.new()
	restart.name = "RestartButton"
	restart.text = "重新入山"
	restart.custom_minimum_size = Vector2(220, 54)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.add_theme_font_size_override("font_size", 19)
	restart.add_theme_stylebox_override("normal", _make_style(PANEL_ALT, GOLD, 1, 7))
	restart.add_theme_stylebox_override("hover", _make_style(Color("25484b"), GOLD, 2, 7))
	box.add_child(restart)
	layer.add_child(panel)
	add_child(layer)

func _refresh_hud() -> void:
	if not GameManager.game_started and not get_tree().paused:
		return
	var is_day := GameManager.current_state == GameManager.GameState.DAY
	phase_label.text = "昼间 · 向山门进发" if is_day else "夜间 · 守住灵核"
	phase_label.add_theme_color_override("font_color", GOLD if is_day else BLUE)
	var attune_names := ["赤 · 伤害", "翠 · 生命", "蓝 · 攻速", "黄 · 移速"]
	var attuned_type := int(GameManager.get("attuned_type"))
	attune_label.text = "调谐 · %s" % (attune_names[attuned_type] if attuned_type >= 0 and attuned_type < attune_names.size() else "未定")
	wave_label.text = "第 %d / %d 波" % [GameManager.current_wave, WaveManager.MAX_WAVES]
	timer_label.text = "%02d 秒" % maxi(int(ceil(WaveManager.time_left)), 0)
	var core := get_tree().get_first_node_in_group("LifeCore")
	if core:
		core_bar.max_value = core.max_integrity
		core_bar.value = core.integrity
		var ward := "  ·  护阵 %.0fs" % GameManager.get_core_ward_time_left() if GameManager.is_core_warded() else ""
		core_label.text = "灵核 %d / %d%s" % [int(core.integrity), int(core.max_integrity), ward]
	var player := get_tree().get_first_node_in_group("Player")
	if player:
		var health: HealthComponent = player.get_node_or_null("HealthComponent")
		if health:
			hp_bar.max_value = health.max_health
			hp_bar.value = health.current_health
			hp_label.text = "道基 %d / %d" % [int(health.current_health), int(health.max_health)]
		var selected_weapon := GameManager.get_selected_weapon()
		weapon_label.text = "本命法宝 · %s" % str(selected_weapon.get("name", "未命名法宝"))
		attribute_label.text = "属性  " + GameManager.get_attribute_summary()
		aura_label.text = "灵核光环 · 已激活" if GameManager.player_in_aura else "灵核光环 · 未进入"
		aura_label.add_theme_color_override("font_color", GREEN if GameManager.player_in_aura else MUTED)
		if player.has_method("get_special_profile"):
			var profile: Dictionary = player.get_special_profile()
			var remaining := float(player.get_special_cooldown_remaining())
			var cooldown := maxf(float(player.get_special_cooldown()), 0.1) if player.has_method("get_special_cooldown") else 1.0
			special_bar.max_value = cooldown
			special_bar.value = clampf(cooldown - remaining, 0.0, cooldown)
			special_label.text = "%s  ·  就绪" % profile.get("name", "诀技") if remaining <= 0.0 else "%s  ·  %.1fs" % [profile.get("name", "诀技"), remaining]
			special_label.add_theme_color_override("font_color", GOLD if remaining <= 0.0 else MUTED)
			special_hint.text = str(profile.get("description", "主动诀技"))
	for index in range(orb_labels.size()):
		orb_labels[index].text = "%s %d" % [["赤", "翠", "蓝", "黄"][index], GameManager.orb_counts[index]]
	xp_bar.max_value = maxi(GameManager.xp_required, 1)
	xp_bar.value = GameManager.total_orbs
	xp_label.text = "修为  LV.%d  ·  %d / %d" % [GameManager.player_level, GameManager.total_orbs, GameManager.xp_required]
	_refresh_boss()

func _refresh_boss() -> void:
	var boss := get_tree().get_first_node_in_group("Boss")
	if not boss or not is_instance_valid(boss):
		boss_panel.visible = false
		return
	boss_panel.visible = true
	var display_name := str(boss.get("boss_display_name"))
	var health: HealthComponent = boss.get_node_or_null("HealthComponent")
	if health:
		boss_bar.max_value = health.max_health
		boss_bar.value = health.current_health
		boss_title.text = display_name + ("  ·  狂暴" if bool(boss.get("enraged")) else "")
	if boss.has_method("get_boss_status_text"):
		boss_hint.text = boss.get_boss_status_text()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if pause_overlay and pause_overlay.visible:
		_resume_game()
		return
	if not GameManager.game_started or get_tree().paused:
		return
	_open_pause_menu()

func _open_pause_menu() -> void:
	if not pause_overlay:
		pause_overlay = Control.new()
		pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.color = Color(0.01, 0.04, 0.05, 0.78)
		pause_overlay.add_child(dim)
		var panel := PanelContainer.new()
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.position = Vector2(-190, -170)
		panel.size = Vector2(380, 340)
		panel.add_theme_stylebox_override("panel", _make_style(PANEL, GOLD, 2, 12))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 14)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(box)
		var title := _label("暂离山海", 28, TEXT)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)
		var resume := _action_button("继续战斗")
		resume.pressed.connect(_resume_game)
		box.add_child(resume)
		var restart := _action_button("重新开始")
		restart.pressed.connect(_restart_run)
		box.add_child(restart)
		var menu := _action_button("返回主菜单")
		menu.pressed.connect(_return_to_menu)
		box.add_child(menu)
		pause_overlay.add_child(panel)
		root.add_child(pause_overlay)
	pause_overlay.visible = true
	get_tree().paused = true

func _resume_game() -> void:
	if pause_overlay:
		pause_overlay.visible = false
	get_tree().paused = false

func _restart_run() -> void:
	get_tree().paused = false
	GameManager.reset_game()
	WaveManager.reset_manager()
	get_tree().reload_current_scene()

func _return_to_menu() -> void:
	get_tree().paused = false
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_player_damaged(damage: float) -> void:
	_show_toast("道基受创  -%.0f" % damage, RED)

func _on_core_damaged(damage: float, current_integrity: float, _max_integrity: float) -> void:
	_show_toast("灵核受击  -%.0f  ·  剩余 %.0f" % [damage, current_integrity], RED)

func _on_core_repaired(amount: float, current_integrity: float, _max_integrity: float) -> void:
	_show_toast("灵核修复  +%.0f  ·  当前 %.0f" % [amount, current_integrity], GREEN)

func _on_special_used(skill_name: String, hit_count: int) -> void:
	_show_toast("%s  ·  命中 %d" % [skill_name, hit_count], GOLD)

func _on_attribute_reaction(reaction_name: String, _position: Vector2) -> void:
	_show_toast("属性反应  ·  %s" % reaction_name, Color("c99bf2"))

func _on_intermission_event_chosen(event_id: String) -> void:
	var names := {"repair": "回灵·修核", "harvest": "贪取·丰收", "ward": "镇门·护阵"}
	_show_toast("已选择  ·  %s" % names.get(event_id, event_id), BLUE)

func _on_card_acquired(card_id: String, rank: int) -> void:
	var card := UpgradeManager.get_card_definition(card_id)
	_show_toast("获得卡片  ·  %s  Lv.%d" % [card.get("name", card_id), rank], GOLD)

func _show_toast(message: String, color: Color) -> void:
	if not toast_label:
		return
	toast_label.text = message
	toast_label.add_theme_color_override("font_color", color)
	toast_time = 2.0

func _action_button(button_text: String) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(250, 46)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_stylebox_override("normal", _make_style(PANEL_ALT, Color("638c84"), 1, 7))
	button.add_theme_stylebox_override("hover", _make_style(Color("244a4c"), GOLD, 2, 7))
	return button

func _panel_box(panel: PanelContainer, margin: int) -> VBoxContainer:
	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", margin)
	margin_container.add_theme_constant_override("margin_top", margin)
	margin_container.add_theme_constant_override("margin_right", margin)
	margin_container.add_theme_constant_override("margin_bottom", margin)
	panel.add_child(margin_container)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin_container.add_child(box)
	return box

func _make_corner_panel(panel_size: Vector2, preset: Control.LayoutPreset, panel_position: Vector2, accent: Color) -> PanelContainer:
	var panel := _make_panel(Vector2.ZERO, panel_size, accent)
	panel.set_anchors_preset(preset)
	panel.position = panel_position
	panel.size = panel_size
	return panel

func _make_panel(position: Vector2, panel_size: Vector2, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = position
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", _make_style(PANEL, Color(accent.r, accent.g, accent.b, 0.65), 1, 8))
	return panel

func _make_bar(fill_color: Color, bar_size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = bar_size
	bar.size = bar_size
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _make_style(Color("071217"), Color(0, 0, 0, 0), 0, 4))
	bar.add_theme_stylebox_override("fill", _make_style(fill_color, Color(0, 0, 0, 0), 0, 4))
	return bar

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style
