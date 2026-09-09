extends Node2D
class_name FirstLevel

const CORE_SCENE = preload("res://scenes/entities/life_core.tscn")
const PLAYER_SCENE = preload("res://scenes/entities/player/player.tscn")
const ENEMY_SCENE = preload("res://scenes/entities/enemies/enemy.tscn")
const GATE_SCENE = preload("res://scenes/world/gate_zone.tscn")
const BOSS_SCENE = preload("res://scenes/entities/bosses/boss_red_crack.tscn")
const HUD_SCRIPT = preload("res://src/ui/game_hud.gd")
const HEALTH_SCRIPT = preload("res://src/components/health_component.gd")
const HURTBOX_SCRIPT = preload("res://src/components/hurtbox_component.gd")
const MAP_BACKGROUND_TEXTURE = preload("res://assets/textures/environment/first_level_map_diamond.png")
var arena_boundary_points := PackedVector2Array([
	Vector2(0, -820),
	Vector2(820, 0),
	Vector2(0, 820),
	Vector2(-820, 0),
])

func _ready() -> void:
	if not GameManager.game_started:
		GameManager.game_started = true
		WaveManager.start_day()
	_build_world()
	_build_core()
	_build_player()
	_build_spawner()
	_build_gates()
	add_child(HUD_SCRIPT.new())
	queue_redraw()

func _build_world() -> void:
	# The arena is a single continuous painted map. Region-specific details are
	# authored into that canvas so no independent decals can leave hard seams.
	z_index = 0
	_build_arena_boundary()

func _build_arena_boundary() -> void:
	# Invisible collision follows the four sides of the diamond. This keeps the
	# play space honest: enemies and the player cannot walk into the mist beyond
	# the painted edge or get trapped by a rectangular camera limit.
	var boundary := StaticBody2D.new()
	boundary.name = "DiamondArenaBoundary"
	boundary.collision_layer = 1
	boundary.collision_mask = 0
	for index in range(arena_boundary_points.size()):
		var edge := CollisionShape2D.new()
		var segment := SegmentShape2D.new()
		segment.a = arena_boundary_points[index]
		segment.b = arena_boundary_points[(index + 1) % arena_boundary_points.size()]
		edge.shape = segment
		boundary.add_child(edge)
	add_child(boundary)

func _build_core() -> void:
	var core := CORE_SCENE.instantiate()
	core.name = "LifeCore"
	core.position = Vector2.ZERO
	add_child(core)

func _build_player() -> void:
	var player := PLAYER_SCENE.instantiate()
	player.name = "Player"
	player.position = Vector2(0, 90)
	player.collision_layer = 2
	player.collision_mask = 9
	add_child(player)

	var health: HealthComponent = HealthComponent.new()
	health.name = "HealthComponent"
	player.add_child(health)

	var hurtbox: HurtboxComponent = HurtboxComponent.new()
	hurtbox.name = "HurtboxComponent"
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 16
	hurtbox.health_component = health
	var hurt_shape := CollisionShape2D.new()
	var hurt_circle := CircleShape2D.new()
	hurt_circle.radius = 16.0
	hurt_shape.shape = hurt_circle
	hurtbox.add_child(hurt_shape)
	player.add_child(hurtbox)
	hurtbox.hit.connect(player._on_hurtbox_component_hit)

	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = -1230
	camera.limit_top = -900
	camera.limit_right = 1230
	camera.limit_bottom = 900
	player.add_child(camera)

func _build_spawner() -> void:
	var spawner: EnemySpawner = EnemySpawner.new()
	spawner.name = "EnemySpawner"
	spawner.enemy_scene = ENEMY_SCENE
	spawner.spawn_radius = 720.0
	add_child(spawner)

func _build_gates() -> void:
	var gates := [
		{"name": "赤裂 Boss 房  ·  火爆", "id": "RedCrack", "position": Vector2(0, -760), "color": Color("d85a55")},
		{"name": "翠疫 Boss 房  ·  毒藤", "id": "GreenPlague", "position": Vector2(0, 760), "color": Color("65c579")},
		{"name": "蓝弧 Boss 房  ·  水冰", "id": "BlueArc", "position": Vector2(760, 0), "color": Color("69bde1")},
		{"name": "黄砂 Boss 房  ·  风雷", "id": "YellowSand", "position": Vector2(-760, 0), "color": Color("ddb95b")}
	]
	for data in gates:
		var gate := GATE_SCENE.instantiate()
		gate.name = str(data.id) + "Gate"
		gate.gate_name = str(data.name)
		gate.boss_id = str(data.id)
		gate.boss_scene = BOSS_SCENE
		gate.position = data.position
		gate.set_meta("accent_color", data.color)
		add_child(gate)

func _draw() -> void:
	# One continuous 16:9 canvas covers the complete playable gate-to-gate
	# space. The base fill only protects the camera margins outside that canvas.
	draw_rect(Rect2(-1800, -1200, 3600, 2400), Color("5f715d"), true)
	# The source art is 16:9, so it is drawn into a corrected world rectangle.
	# This makes its four tips share the same world radius instead of producing
	# a horizontally stretched diamond on a widescreen viewport.
	draw_texture_rect(MAP_BACKGROUND_TEXTURE, Rect2(-1230, -900, 2460, 1800), false)

func _draw_soft_territory(direction: Vector2, color: Color) -> void:
	var normal := Vector2(-direction.y, direction.x)
	# The plume centers move outward and widen near the gate, creating a
	# readable regional pull while leaving a large neutral combat core.
	for index in range(8):
		var progress: float = float(index) / 7.0
		var offset: float = sin(float(index) * 1.7) * 34.0
		var center: Vector2 = direction * lerp(330.0, 760.0, progress) + normal * offset
		var radius: float = lerp(230.0, 380.0, progress)
		var alpha: float = lerp(0.006, 0.018, progress)
		draw_circle(center, radius, Color(color.r, color.g, color.b, alpha))
	# Short, separated veins keep the direction legible without recreating the
	# previous harsh four-axis lines or a rectangular corridor.
	for segment in range(6):
		var start: Vector2 = direction * (280.0 + float(segment) * 92.0) + normal * sin(float(segment) * 2.2) * 10.0
		var finish: Vector2 = start + direction * 54.0
		draw_line(start, finish, Color(color.r, color.g, color.b, 0.10), 2.0)

func _draw_region_props() -> void:
	# North / red: ember stones and short heat fissures.
	for point in [Vector2(-300, -575), Vector2(270, -705), Vector2(460, -485)]:
		_draw_ember_cluster(point)
	# South / green: moss islands and curling vines.
	for point in [Vector2(-430, 560), Vector2(360, 620), Vector2(-150, 790)]:
		_draw_vine_cluster(point)
	# East / blue: sparse crystals and water ripples.
	for point in [Vector2(520, -300), Vector2(650, 330), Vector2(770, 90)]:
		_draw_crystal_cluster(point)
	# West / yellow: wind-carved sand ribbons, talismans and dry grass.
	for point in [Vector2(-560, -260), Vector2(-680, 280), Vector2(-790, -20)]:
		_draw_sand_marker(point)

func _draw_ember_cluster(point: Vector2) -> void:
	draw_circle(point, 18.0, Color(0.35, 0.10, 0.08, 0.32))
	draw_circle(point + Vector2(5, -3), 6.0, Color(1.0, 0.24, 0.08, 0.66))
	draw_circle(point + Vector2(-7, 5), 3.0, Color(1.0, 0.64, 0.18, 0.78))
	draw_line(point + Vector2(-26, 8), point + Vector2(-4, 1), Color(0.92, 0.20, 0.10, 0.32), 3.0)
	draw_line(point + Vector2(8, 4), point + Vector2(29, -10), Color(0.92, 0.20, 0.10, 0.28), 2.0)

func _draw_vine_cluster(point: Vector2) -> void:
	var vine := PackedVector2Array([point + Vector2(-30, 12), point + Vector2(-12, 2), point + Vector2(2, -13), point + Vector2(27, -17)])
	draw_polyline(vine, Color(0.24, 0.72, 0.44, 0.38), 3.0)
	draw_circle(point + Vector2(-8, 0), 8.0, Color(0.30, 0.82, 0.50, 0.24))
	draw_circle(point + Vector2(12, -13), 6.0, Color(0.43, 0.92, 0.58, 0.30))
	draw_circle(point + Vector2(28, -18), 4.0, Color(0.54, 1.0, 0.68, 0.38))

func _draw_crystal_cluster(point: Vector2) -> void:
	var crystal := PackedVector2Array([point + Vector2(0, -22), point + Vector2(12, -4), point + Vector2(4, 20), point + Vector2(-12, 7)])
	draw_colored_polygon(crystal, Color(0.25, 0.78, 0.96, 0.26))
	draw_polyline(PackedVector2Array([crystal[0], crystal[1], crystal[2], crystal[3], crystal[0]]), Color(0.45, 0.92, 1.0, 0.60), 2.0)
	draw_arc(point + Vector2(0, 15), 30.0, PI * 0.12, PI * 0.88, 22, Color(0.28, 0.82, 1.0, 0.28), 2.0)
	draw_arc(point + Vector2(0, 15), 48.0, PI * 0.18, PI * 0.82, 22, Color(0.28, 0.82, 1.0, 0.16), 2.0)

func _draw_sand_marker(point: Vector2) -> void:
	draw_arc(point, 30.0, PI * 0.12, PI * 0.82, 24, Color(0.92, 0.65, 0.24, 0.30), 3.0)
	draw_arc(point + Vector2(4, 8), 48.0, PI * 0.16, PI * 0.84, 24, Color(0.92, 0.65, 0.24, 0.18), 2.0)
	var talisman := PackedVector2Array([point + Vector2(-5, -22), point + Vector2(7, -18), point + Vector2(5, 2), point + Vector2(-7, -2)])
	draw_colored_polygon(talisman, Color(0.90, 0.58, 0.18, 0.42))
	draw_line(point + Vector2(-1, -18), point + Vector2(1, -6), Color(0.98, 0.85, 0.42, 0.55), 1.0)

func _draw_gate_marker(position: Vector2, color: Color, angle: float) -> void:
	var marker := Color(color.r, color.g, color.b, 0.34)
	draw_circle(position, 70.0, Color(color.r, color.g, color.b, 0.05))
	draw_arc(position, 66.0, angle - 0.72, angle + 0.72, 28, marker, 3.0)
	draw_line(position - Vector2.from_angle(angle) * 38.0, position + Vector2.from_angle(angle) * 38.0, marker, 2.0)
