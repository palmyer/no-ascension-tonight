extends Area2D
class_name GateZone

const GATE_TEXTURE = preload("res://assets/textures/environment/shanmen_portal.png")

@export var gate_name: String = "North Gate"
@export var boss_id: String = ""
@export var activation_time: float = 5.0
@export var boss_scene: PackedScene

var charge_timer: float = 0.0
var player_inside: bool = false
var is_activated: bool = false
var accent_color: Color = Color("d7ad58")
var gate_sprite: Sprite2D

@onready var progress_bar: TextureProgressBar
@onready var label: Label

func _ready():
	collision_layer = 0
	collision_mask = 2 # Player layer
	if has_meta("accent_color"):
		accent_color = get_meta("accent_color")
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	setup_visual()
	setup_ui()
	queue_redraw()

func setup_visual() -> void:
	gate_sprite = Sprite2D.new()
	gate_sprite.name = "ShanmenTexture"
	gate_sprite.texture = GATE_TEXTURE
	gate_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	gate_sprite.position = Vector2(0, -22)
	gate_sprite.scale = Vector2(0.18, 0.18)
	gate_sprite.z_index = 1
	add_child(gate_sprite)

func setup_ui():
	# Keep the room caption and charge bar on the playable side of the room.
	# This matters now that the four rooms sit on the tips of the diamond.
	var inward := -global_position.normalized() * 132.0
	label = Label.new()
	label.text = gate_name
	label.position = inward + Vector2(-110, -18)
	label.size = Vector2(220, 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", accent_color)
	add_child(label)
	
	# Using a simple ColorRect as a progress bar for now
	var bg = ColorRect.new()
	bg.size = Vector2(140, 8)
	bg.position = inward + Vector2(-70, 26)
	bg.color = Color(0.02, 0.07, 0.08, 0.84)
	add_child(bg)
	
	var fg = ColorRect.new()
	fg.size = Vector2(0, 8)
	fg.position = inward + Vector2(-70, 26)
	fg.color = accent_color
	fg.name = "ProgressForeground"
	add_child(fg)

func _process(delta: float):
	if is_activated:
		return
	if GameManager.current_state != GameManager.GameState.DAY:
		label.modulate.a = 0.45
	else:
		label.modulate.a = 1.0
	
	if player_inside and GameManager.current_state == GameManager.GameState.DAY:
		charge_timer += delta
		update_ui()
		
		if charge_timer >= activation_time:
			activate_gate()
	elif charge_timer > 0:
		charge_timer = max(0, charge_timer - delta * 0.5) # Slowly decay
		update_ui()

func update_ui():
	var fg = get_node("ProgressForeground")
	if fg:
		fg.size.x = (charge_timer / activation_time) * 140.0

func activate_gate():
	if boss_id.is_empty() or not WaveManager.try_spawn_boss(boss_id, boss_scene, global_position):
		charge_timer = 0.0
		update_ui()
		if GameManager.debug_mode:
			print("[GATE] %s is not available at wave %d" % [gate_name, GameManager.current_wave])
		return

	is_activated = true
	if GameManager.debug_mode:
		print("[GATE] %s Activated! %s summoned" % [gate_name, boss_id])
	
	# Hide UI
	label.visible = false
	get_node("ProgressForeground").visible = false
	
	# Visual effect
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(2, 2), 0.5)
	tween.tween_property(self, "modulate:a", 0, 0.5)
	await tween.finished
	queue_free()

func _on_body_entered(body: Node2D):
	if body.is_in_group("Player"):
		player_inside = true
		if GameManager.debug_mode:
			print("[GATE] Player entered %s zone" % gate_name)

func _on_body_exited(body: Node2D):
	if body.is_in_group("Player"):
		player_inside = false
		if GameManager.debug_mode:
			print("[GATE] Player left %s zone" % gate_name)

func _draw() -> void:
	var aura := Color(accent_color.r, accent_color.g, accent_color.b, 0.12)
	draw_circle(Vector2(0, -22), 70.0, aura)
	draw_arc(Vector2(0, -22), 62.0, -PI * 0.78, PI * 0.78, 40, Color(accent_color.r, accent_color.g, accent_color.b, 0.55), 3.0)
	draw_circle(Vector2(0, -22), 18.0, Color(accent_color.r, accent_color.g, accent_color.b, 0.18))
	draw_arc(Vector2(0, -22), 18.0, 0.0, TAU, 24, Color(accent_color.r, accent_color.g, accent_color.b, 0.72), 2.0)
