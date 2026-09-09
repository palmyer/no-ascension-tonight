extends Node2D
class_name SkillBurstVisual

var radius: float = 180.0
var tint: Color = Color("e8b85b")
var duration: float = 0.38
var target_positions: Array = []
var elapsed: float = 0.0

func configure(effect_radius: float, effect_color: Color, targets: Array = []) -> void:
	radius = effect_radius
	tint = effect_color
	target_positions = targets.duplicate()

func _ready() -> void:
	z_index = 20
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= duration:
		queue_free()

func _draw() -> void:
	var progress := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
	var pulse := 0.72 + progress * 0.38
	var fill := tint
	fill.a = 0.16 * (1.0 - progress)
	draw_circle(Vector2.ZERO, radius * pulse, fill)

	var ring := tint
	ring.a = 0.9 * (1.0 - progress)
	draw_arc(Vector2.ZERO, radius * pulse, 0.0, TAU, 72, ring, 5.0)
	draw_arc(Vector2.ZERO, radius * 0.45 * pulse, 0.0, TAU, 48, ring, 2.0)

	for index in range(8):
		var angle := TAU * float(index) / 8.0 + progress * 0.8
		var start := Vector2.from_angle(angle) * radius * 0.38 * pulse
		var finish := Vector2.from_angle(angle) * radius * 0.96 * pulse
		draw_line(start, finish, ring, 2.0)

	for target_position in target_positions:
		var target := target_position as Vector2
		var chain_color := tint
		chain_color.a = 0.85 * (1.0 - progress)
		draw_line(Vector2.ZERO, target, chain_color, 3.0)
