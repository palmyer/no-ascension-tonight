extends Node2D
class_name EnemyStatusView

## Lightweight, world-space status feedback for enemies and bosses.
## This is intentionally drawn with primitives so status readability does not
## depend on additional art assets.

const STATUS_ORDER := ["fire", "poison", "vine", "ice", "wind", "thunder", "blast", "water"]
const STATUS_SYMBOLS := {
	"fire": "火",
	"poison": "毒",
	"vine": "藤",
	"ice": "冰",
	"wind": "风",
	"thunder": "雷",
	"blast": "爆",
	"water": "水"
}
const STATUS_COLORS := {
	"fire": Color("ef704f"),
	"poison": Color("72c66d"),
	"vine": Color("4ba96b"),
	"ice": Color("78c9ef"),
	"wind": Color("b2e4d0"),
	"thunder": Color("e6cf62"),
	"blast": Color("e89a5b"),
	"water": Color("5d9ee6")
}

var status_component: AttributeStatusComponent
var is_boss: bool = false
var elapsed: float = 0.0

func configure(component: AttributeStatusComponent, boss: bool = false) -> void:
	status_component = component
	is_boss = boss
	name = "BossStatusView" if is_boss else "EnemyStatusView"
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	if not status_component or not is_instance_valid(status_component):
		return

	var active_ids: Array[String] = []
	for attribute_id in STATUS_ORDER:
		var status: Dictionary = status_component.statuses.get(attribute_id, {})
		if int(status.get("stacks", 0)) > 0:
			active_ids.append(attribute_id)

	var has_freeze := status_component.frozen_time > 0.0
	var has_stun := status_component.stunned_time > 0.0
	_draw_condition_effects(active_ids, has_freeze, has_stun)
	if active_ids.is_empty() and not has_freeze and not has_stun:
		return

	var chip_width := 31.0
	var gap := 3.0
	var total_width := active_ids.size() * chip_width + maxi(active_ids.size() - 1, 0) * gap
	var start_x := -total_width * 0.5
	var row_y := -62.0 if is_boss else -47.0
	for index in range(active_ids.size()):
		var attribute_id := active_ids[index]
		var status: Dictionary = status_component.statuses.get(attribute_id, {})
		var color: Color = STATUS_COLORS.get(attribute_id, Color.WHITE)
		var x := start_x + index * (chip_width + gap)
		var chip_rect := Rect2(x, row_y, chip_width, 25.0)
		var background := Color(0.02, 0.06, 0.08, 0.88)
		draw_rect(chip_rect, background, true)
		draw_rect(chip_rect, Color(color.r, color.g, color.b, 0.9), false, 1.5)

		var symbol := str(STATUS_SYMBOLS.get(attribute_id, "·"))
		draw_string(ThemeDB.fallback_font, Vector2(x + 3.0, row_y + 16.0), symbol, HORIZONTAL_ALIGNMENT_LEFT, 16.0, 13, Color.WHITE)
		var stacks := str(int(status.get("stacks", 0)))
		draw_string(ThemeDB.fallback_font, Vector2(x + 19.0, row_y + 16.0), stacks, HORIZONTAL_ALIGNMENT_LEFT, 10.0, 11, color)

		var definition: Dictionary = GameManager.ATTRIBUTE_DEFINITIONS.get(attribute_id, {})
		var mastery := maxi(int(status.get("mastery", 1)), 1)
		var max_duration := float(definition.get("duration", 2.0)) * (1.0 + (mastery - 1) * 0.15)
		var remaining := clampf(float(status.get("time", 0.0)), 0.0, max_duration)
		var progress := remaining / maxf(max_duration, 0.01)
		draw_rect(Rect2(x + 2.0, row_y + 20.0, chip_width - 4.0, 3.0), Color(0.12, 0.15, 0.16, 0.95), true)
		draw_rect(Rect2(x + 2.0, row_y + 20.0, (chip_width - 4.0) * progress, 3.0), color, true)

	_draw_control_badge(row_y, has_freeze, has_stun)

func _draw_condition_effects(active_ids: Array[String], has_freeze: bool, has_stun: bool) -> void:
	var pulse := 1.0 + sin(elapsed * 7.0) * 0.05
	if active_ids.has("fire"):
		var fire_color := Color(0.95, 0.32, 0.16, 0.28)
		draw_arc(Vector2.ZERO, 31.0 * pulse, 0.15, PI * 1.85, 28, fire_color, 3.0)
		for index in range(3):
			var flame_x := -16.0 + index * 16.0
			var flame := PackedVector2Array([
				Vector2(flame_x - 4.0, 26.0),
				Vector2(flame_x, 14.0 - (index % 2) * 4.0),
				Vector2(flame_x + 4.0, 26.0)
			])
			draw_colored_polygon(flame, Color(0.95, 0.40, 0.16, 0.6))
	if active_ids.has("poison"):
		for index in range(3):
			var bubble := Vector2(-18.0 + index * 18.0, 22.0 - fmod(elapsed * (4.0 + index), 8.0))
			draw_circle(bubble, 4.0 + index, Color(0.32, 0.82, 0.38, 0.42))
	if active_ids.has("vine"):
		var vine_color := Color(0.22, 0.68, 0.38, 0.68)
		draw_arc(Vector2.ZERO, 28.0, -0.35, PI + 0.35, 24, vine_color, 3.0)
		draw_arc(Vector2.ZERO, 25.0, PI - 0.35, TAU - 0.35, 24, vine_color, 3.0)
	if active_ids.has("ice") or has_freeze:
		var ice_color := Color(0.35, 0.78, 1.0, 0.62 if not has_freeze else 0.9)
		draw_arc(Vector2.ZERO, 33.0 * pulse, 0.0, TAU, 32, ice_color, 3.0)
		for index in range(4):
			var angle := TAU * float(index) / 4.0 + elapsed * 0.35
			var direction := Vector2.from_angle(angle)
			draw_line(direction * 27.0, direction * 36.0, ice_color, 2.0)
	if active_ids.has("thunder") or has_stun:
		var thunder_color := Color(1.0, 0.86, 0.28, 0.78)
		var points := PackedVector2Array([
			Vector2(-29.0, -5.0), Vector2(-20.0, -14.0), Vector2(-13.0, -4.0),
			Vector2(-4.0, -16.0), Vector2(4.0, -5.0), Vector2(14.0, -15.0),
			Vector2(27.0, -4.0)
		])
		draw_polyline(points, thunder_color, 2.5)

func _draw_control_badge(row_y: float, has_freeze: bool, has_stun: bool) -> void:
	if has_freeze:
		var remaining := "%.1f" % status_component.frozen_time
		draw_string(ThemeDB.fallback_font, Vector2(18.0, row_y - 7.0), "❄ " + remaining, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("a8e8ff"))
	elif has_stun:
		var remaining := "%.1f" % status_component.stunned_time
		draw_string(ThemeDB.fallback_font, Vector2(18.0, row_y - 7.0), "✦ " + remaining, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("ffe37b"))
