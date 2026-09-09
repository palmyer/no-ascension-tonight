extends Node2D
class_name HazardZone

## Boss-only telegraph that can threaten the player and the life core.
## It is intentionally separate from DamageZone: regular skill zones damage
## enemies, while boss hazards damage the things the player protects.

var radius: float = 90.0
var duration: float = 2.5
var damage_per_tick: float = 8.0
var tick_interval: float = 0.55
var tint: Color = Color("e17a5b")
var affects_core: bool = true
var elapsed: float = 0.0
var tick_timer: float = 0.0

func configure(zone_radius: float, zone_duration: float, zone_damage: float, zone_color: Color, can_damage_core: bool = true) -> void:
	radius = zone_radius
	duration = zone_duration
	damage_per_tick = zone_damage
	tint = zone_color
	affects_core = can_damage_core

func _ready() -> void:
	z_index = 8
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
	var player := get_tree().get_first_node_in_group("Player")
	if player and is_instance_valid(player) and global_position.distance_to(player.global_position) <= radius:
		if player.has_method("take_damage"):
			player.take_damage(damage_per_tick)

	if not affects_core:
		return
	var core := get_tree().get_first_node_in_group("LifeCore")
	if core and is_instance_valid(core) and global_position.distance_to(core.global_position) <= radius:
		if core.has_method("receive_damage"):
			core.receive_damage(damage_per_tick * 0.75)

func _draw() -> void:
	var progress := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
	var pulse := 1.0 + sin(elapsed * 7.0) * 0.04
	var fill := tint
	fill.a = 0.18 * (1.0 - progress)
	draw_circle(Vector2.ZERO, radius * pulse, fill)
	var outline := tint
	outline.a = 0.88 * (1.0 - progress)
	draw_arc(Vector2.ZERO, radius * pulse, 0.0, TAU, 56, outline, 3.0)
	for index in range(8):
		var angle := TAU * float(index) / 8.0 + elapsed * 0.45
		var start := Vector2.from_angle(angle) * radius * 0.62
		var finish := Vector2.from_angle(angle) * radius * 0.9
		draw_line(start, finish, outline, 2.0)
