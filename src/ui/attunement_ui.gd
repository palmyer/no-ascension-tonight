extends Control

@onready var wheel_center = $Center

var hovered_sector: int = -1 # 0:R, 1:B, 2:G, 3:Y (顺时针，从上方开始)
var sector_scales = [1.0, 1.0, 1.0, 1.0]

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	EventBus.show_attunement_wheel.connect(_on_show)

func _on_show():
	visible = true
	hovered_sector = -1

func _process(_delta: float):
	if not visible: return
	
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
	visible = false
	WaveManager.start_next_wave()

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

func draw_sector(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color):
	var points = PackedVector2Array()
	points.append(center)
	var steps = 32
	for i in range(steps + 1):
		var phi = start_angle + (end_angle - start_angle) * i / steps
		points.append(center + Vector2.from_angle(phi) * radius)
	draw_polygon(points, [color])
