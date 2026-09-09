extends Node2D
class_name DamageZone

var radius: float = 80.0
var duration: float = 2.0
var damage_per_tick: float = 4.0
var tick_interval: float = 0.5
var attribute_payload: Dictionary = {}
var tint: Color = Color("e37b4d")
var elapsed: float = 0.0
var tick_timer: float = 0.0

func configure(zone_radius: float, zone_duration: float, zone_damage: float, payload: Dictionary, zone_color: Color) -> void:
	radius = zone_radius
	duration = zone_duration
	damage_per_tick = zone_damage
	attribute_payload = payload.duplicate(true)
	tint = zone_color

func _ready() -> void:
	z_index = -1
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	tick_timer -= delta
	if tick_timer <= 0.0:
		_apply_tick()
		tick_timer = tick_interval
	queue_redraw()
	if elapsed >= duration:
		queue_free()

func _apply_tick() -> void:
	for enemy in get_tree().get_nodes_in_group("DamageableEnemy"):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if global_position.distance_to(enemy.global_position) > radius:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage_per_tick)
		if enemy.has_method("apply_attribute_payload") and not attribute_payload.is_empty():
			enemy.apply_attribute_payload(attribute_payload, damage_per_tick, global_position)

func _draw() -> void:
	var progress := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
	var fill := tint
	fill.a = 0.16 * (1.0 - progress)
	draw_circle(Vector2.ZERO, radius, fill)
	var outline := tint
	outline.a = 0.75 * (1.0 - progress)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, outline, 3.0)
