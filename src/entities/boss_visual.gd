extends Node2D
class_name BossVisual

var boss_id: String = "RedCrack"
var primary: Color = Color("c43f46")
var secondary: Color = Color("f0b95f")
var pulse_time: float = 0.0
var enraged: bool = false
var boss_sprite: Sprite2D

const RED_TEXTURE = preload("res://assets/textures/bosses/boss_red_crack_full.png")
const GREEN_TEXTURE = preload("res://assets/textures/bosses/boss_green_plague_full.png")
const BLUE_TEXTURE = preload("res://assets/textures/bosses/boss_blue_arc_full.png")
const YELLOW_TEXTURE = preload("res://assets/textures/bosses/boss_yellow_sand_full.png")
const ASCENSION_TEXTURE = preload("res://assets/textures/bosses/boss_ascension_king_full.png")

func _ready() -> void:
	_ensure_boss_sprite()

func _ensure_boss_sprite() -> void:
	if boss_sprite:
		return
	boss_sprite = Sprite2D.new()
	boss_sprite.name = "BossTexture"
	boss_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	boss_sprite.z_index = 1
	add_child(boss_sprite)
	_update_boss_sprite()

func _texture_for_boss() -> Texture2D:
	match boss_id:
		"GreenPlague":
			return GREEN_TEXTURE
		"BlueArc":
			return BLUE_TEXTURE
		"YellowSand":
			return YELLOW_TEXTURE
		"AscensionKing":
			return ASCENSION_TEXTURE
		_:
			return RED_TEXTURE

func _update_boss_sprite() -> void:
	if not boss_sprite:
		return
	boss_sprite.texture = _texture_for_boss()
	var sprite_scale := 0.2
	if boss_id == "AscensionKing":
		sprite_scale = 0.23
	boss_sprite.scale = Vector2.ONE * sprite_scale

func configure(configured_id: String, first_color: Color, second_color: Color) -> void:
	boss_id = configured_id
	primary = first_color
	secondary = second_color
	_ensure_boss_sprite()
	_update_boss_sprite()
	queue_redraw()

func set_enraged(value: bool) -> void:
	if enraged == value:
		return
	enraged = value
	queue_redraw()

func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(pulse_time * 3.0) * 0.035
	var aura := primary
	aura.a = 0.12 if not enraged else 0.22
	draw_circle(Vector2.ZERO, 62.0 * pulse, aura)
	var ring := secondary
	ring.a = 0.45 if not enraged else 0.82
	draw_arc(Vector2.ZERO, 56.0 * pulse, -PI / 2.0, TAU * 0.85, 42, ring, 2.5)

func _draw_red_crack() -> void:
	var body := primary
	draw_circle(Vector2.ZERO, 28.0, body)
	draw_colored_polygon(PackedVector2Array([Vector2(-31, -13), Vector2(-52, -32), Vector2(-24, -23)]), secondary)
	draw_colored_polygon(PackedVector2Array([Vector2(31, -13), Vector2(52, -32), Vector2(24, -23)]), secondary)
	draw_line(Vector2(-19, 1), Vector2(19, 1), Color("6b1f2c"), 5.0)
	draw_circle(Vector2(-10, -6), 4.0, Color("fff0c0"))
	draw_circle(Vector2(10, -6), 4.0, Color("fff0c0"))
	draw_line(Vector2(-10, 11), Vector2(6, 18), Color("5b1d28"), 3.0)

func _draw_green_plague() -> void:
	var body := primary
	draw_circle(Vector2.ZERO, 30.0, body)
	for index in range(6):
		var angle := TAU * float(index) / 6.0 - PI / 2.0
		var start := Vector2.from_angle(angle) * 20.0
		var finish := Vector2.from_angle(angle) * 45.0
		draw_line(start, finish, secondary, 6.0)
		draw_circle(finish, 5.0, secondary)
	draw_circle(Vector2(-10, -5), 4.0, Color("d8ffb0"))
	draw_circle(Vector2(10, -5), 4.0, Color("d8ffb0"))
	draw_arc(Vector2.ZERO, 22.0, 0.25, PI - 0.25, 18, Color("173b2c"), 4.0)

func _draw_blue_arc() -> void:
	var body := primary
	draw_circle(Vector2.ZERO, 27.0, body)
	for angle in [-0.9, 0.0, 0.9]:
		var points := PackedVector2Array()
		for index in range(5):
			var t := float(index) / 4.0
			var offset := Vector2.from_angle(angle) * (16.0 + t * 28.0)
			offset.y += sin(t * PI * 2.0 + angle) * 5.0
			points.append(offset)
		draw_polyline(points, secondary, 4.0)
	draw_circle(Vector2(-9, -5), 4.0, Color("e4fbff"))
	draw_circle(Vector2(9, -5), 4.0, Color("e4fbff"))
	draw_line(Vector2(-11, 12), Vector2(11, 12), Color("122f59"), 4.0)

func _draw_yellow_sand() -> void:
	var body := primary
	draw_colored_polygon(PackedVector2Array([Vector2(0, -36), Vector2(27, -14), Vector2(22, 22), Vector2(0, 36), Vector2(-22, 22), Vector2(-27, -14)]), body)
	for angle in range(0, 360, 60):
		var direction := Vector2.from_angle(deg_to_rad(float(angle)))
		draw_line(direction * 22.0, direction * 48.0, secondary, 4.0)
	draw_circle(Vector2(-9, -7), 4.0, Color("fff2a4"))
	draw_circle(Vector2(9, -7), 4.0, Color("fff2a4"))

func _draw_ascension_king() -> void:
	var body := primary
	draw_circle(Vector2.ZERO, 33.0, body)
	draw_colored_polygon(PackedVector2Array([Vector2(-32, -18), Vector2(-18, -50), Vector2(-5, -28)]), secondary)
	draw_colored_polygon(PackedVector2Array([Vector2(32, -18), Vector2(18, -50), Vector2(5, -28)]), secondary)
	draw_circle(Vector2.ZERO, 13.0, Color("221a3f"))
	draw_circle(Vector2.ZERO, 7.0, Color("f5d176"))
	for angle in [-PI / 2.0, 0.0, PI / 2.0, PI]:
		var start := Vector2.from_angle(angle) * 37.0
		var finish := Vector2.from_angle(angle) * 56.0
		draw_line(start, finish, secondary, 4.0)
