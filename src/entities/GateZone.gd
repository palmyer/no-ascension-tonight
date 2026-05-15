extends Area2D
class_name GateZone

@export var gate_name: String = "North Gate"
@export var activation_time: float = 5.0
@export var boss_scene: PackedScene

var charge_timer: float = 0.0
var player_inside: bool = false
var is_activated: bool = false

@onready var progress_bar: TextureProgressBar
@onready var label: Label

func _ready():
	collision_layer = 0
	collision_mask = 2 # Player layer
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	setup_ui()

func setup_ui():
	# Simple label and progress indicator
	label = Label.new()
	label.text = gate_name
	label.position = Vector2(-50, -80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	
	# Using a simple ColorRect as a progress bar for now
	var bg = ColorRect.new()
	bg.size = Vector2(100, 10)
	bg.position = Vector2(-50, -50)
	bg.color = Color(0, 0, 0, 0.5)
	add_child(bg)
	
	var fg = ColorRect.new()
	fg.size = Vector2(0, 10)
	fg.position = Vector2(-50, -50)
	fg.color = Color.GOLD
	fg.name = "ProgressForeground"
	add_child(fg)

func _process(delta: float):
	if is_activated: return
	
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
		fg.size.x = (charge_timer / activation_time) * 100.0

func activate_gate():
	is_activated = true
	print("[GATE] %s Activated! Boss Summing..." % gate_name)
	
	if boss_scene:
		var boss = boss_scene.instantiate()
		boss.global_position = global_position
		get_parent().add_child(boss)
	
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
		print("[GATE] Player entered %s zone" % gate_name)

func _on_body_exited(body: Node2D):
	if body.is_in_group("Player"):
		player_inside = false
		print("[GATE] Player left %s zone" % gate_name)
