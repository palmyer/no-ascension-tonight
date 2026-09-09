extends Control

var hovered_sector: int = -1 # 0:R, 1:B, 2:G, 3:Y (顺时针，从上方开始)
var sector_scales = [1.0, 1.0, 1.0, 1.0]
var selected_type: int = -1
var event_panel: PanelContainer

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	EventBus.show_attunement_wheel.connect(_on_show)

func _on_show():
	visible = true
	hovered_sector = -1
	selected_type = -1
	if event_panel:
		event_panel.queue_free()
		event_panel = null
	$Label.text = "调谐灵性：选择下一波偏向"

func _process(_delta: float):
	if not visible or event_panel: return
	
	var mouse_pos = get_local_mouse_position()
	var center_pos = size / 2.0
	var offset = mouse_pos - center_pos
	
	if offset.length() > 50: # 中心死区
		var angle = rad_to_deg(offset.angle()) # -180 to 180
		# 映射到 4 个扇区
		if angle >= -135 and angle < -45: hovered_sector = 0 # Top (Red)
		elif angle >= -45 and angle < 45: hovered_sector = 1 # Right (Blue)
		elif angle >= 45 and angle < 135: hovered_sector = 2 # Bottom (Green)
		else: hovered_sector = 3 # Left (Yellow)
	else:
		hovered_sector = -1
	
	# 更新缩放逻辑 (平滑缩放)
	for i in range(4):
		var target = 1.2 if i == hovered_sector else 1.0
		sector_scales[i] = lerp(sector_scales[i], target, 0.2)
	
	queue_redraw()

func _input(event: InputEvent):
	if visible and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if event.position.y > size.y * 0.64:
				return
			if hovered_sector != -1:
				confirm_selection(hovered_sector)

func confirm_selection(type: int):
	# 将 UI 类型映射到 GameManager 类型
	# UI: 0:Top(R), 1:Right(B), 2:Bottom(G), 3:Left(Y)
	# GM: 0:RED, 1:GREEN, 2:BLUE, 3:YELLOW
	var gm_type = 0
	match type:
		0: gm_type = 0 # Red
		1: gm_type = 2 # Blue
		2: gm_type = 1 # Green
		3: gm_type = 3 # Yellow
	
	GameManager.set_attunement(gm_type)
	selected_type = gm_type
	_show_event_options()

func _show_event_options() -> void:
	event_panel = PanelContainer.new()
	event_panel.set_anchors_preset(Control.PRESET_CENTER)
	event_panel.offset_left = -540.0
	event_panel.offset_top = 160.0
	event_panel.offset_right = 540.0
	event_panel.offset_bottom = 400.0
	event_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	event_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(event_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	event_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var title := Label.new()
	title.text = "波间事件：选择一个代价与收益"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("f2e5bf"))
	content.add_child(title)

	var options := HBoxContainer.new()
	options.alignment = BoxContainer.ALIGNMENT_CENTER
	options.add_theme_constant_override("separation", 14)
	content.add_child(options)

	var event_data := [
		{"id": "repair", "title": "回灵·修核", "description": "灵核 +30，自己回复 20", "color": Color("72d19a")},
		{"id": "harvest", "title": "贪取·丰收", "description": "下一次白天 35% 概率多掉一颗灵性", "color": Color("e6c067")},
		{"id": "ward", "title": "镇门·护阵", "description": "下一夜灵核获得 18 秒无敌护阵", "color": Color("7bbfe8")}
	]
	for data in event_data:
		var button := Button.new()
		button.text = "%s\n%s" % [data.title, data.description]
		button.custom_minimum_size = Vector2(310, 112)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", Color("f2e5bf"))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _make_button_style(Color("112a33"), data.color, 1))
		button.add_theme_stylebox_override("hover", _make_button_style(Color("1b4046"), data.color, 2))
		button.pressed.connect(_confirm_event.bind(str(data.id)))
		options.add_child(button)

func _confirm_event(event_id: String) -> void:
	GameManager.apply_intermission_event(event_id)
	if event_panel:
		event_panel.queue_free()
		event_panel = null
	visible = false
	WaveManager.start_next_wave()

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.12, 0.15, 0.97)
	style.border_color = Color("c7a45b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style

func _make_button_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	return style

func _draw():
	if not visible: return
	
	var center = size / 2.0
	var radius = 200.0
	
	# 绘制 4 个扇区
	var colors = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW]
	var start_angles = [-135, -45, 45, 135]
	
	for i in range(4):
		var s = sector_scales[i]
		var c = colors[i]
		if i == hovered_sector:
			c.a = 0.8
		else:
			c.a = 0.4

		draw_sector(center, radius * s, deg_to_rad(start_angles[i]), deg_to_rad(start_angles[i] + 90), c)
	draw_circle(center, 42.0, Color(0.04, 0.12, 0.15, 0.95))

func draw_sector(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color):
	var points = PackedVector2Array()
	points.append(center)
	var steps = 32
	for i in range(steps + 1):
		var phi = start_angle + (end_angle - start_angle) * i / steps
		points.append(center + Vector2.from_angle(phi) * radius)
	draw_polygon(points, [color])
