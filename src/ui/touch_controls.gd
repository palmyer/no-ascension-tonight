extends Control
class_name TouchControls

var player: Node
var move_pointer_id := -1
var move_origin := Vector2.ZERO
var move_position := Vector2.ZERO
var special_pointer_id := -1
var special_pressed := false
var joystick_radius := 78.0
var special_radius := 58.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = DisplayServer.is_touchscreen_available()
	set_process_input(visible)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if touch.position.x < size.x * 0.5 and move_pointer_id == -1:
				move_pointer_id = touch.index
				move_origin = touch.position
				move_position = touch.position
				_update_player_vector()
			elif touch.position.x >= size.x * 0.68 and touch.position.y >= size.y * 0.65 and special_pointer_id == -1:
				special_pointer_id = touch.index
				special_pressed = true
				var current_player := get_tree().get_first_node_in_group("Player")
				if current_player and current_player.has_method("try_special"):
					current_player.try_special()
			queue_redraw()
		else:
			if touch.index == move_pointer_id:
				move_pointer_id = -1
				move_origin = Vector2.ZERO
				move_position = Vector2.ZERO
				_update_player_vector()
			if touch.index == special_pointer_id:
				special_pointer_id = -1
				special_pressed = false
			queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == move_pointer_id:
			move_position = drag.position
			_update_player_vector()
			queue_redraw()

func _update_player_vector() -> void:
	var current_player := get_tree().get_first_node_in_group("Player")
	if current_player and current_player.has_method("set_touch_move_vector"):
		var vector := (move_position - move_origin).limit_length(joystick_radius) / joystick_radius
		current_player.set_touch_move_vector(vector)

func _draw() -> void:
	if not visible:
		return
	var joystick_center := move_origin if move_pointer_id != -1 else Vector2(142.0, size.y - 140.0)
	var joystick_knob := move_position if move_pointer_id != -1 else joystick_center
	var base := Color(0.2, 0.64, 0.66, 0.22)
	var outline := Color(0.55, 0.9, 0.82, 0.55)
	draw_circle(joystick_center, joystick_radius, base)
	draw_arc(joystick_center, joystick_radius, 0.0, TAU, 48, outline, 3.0)
	draw_circle(joystick_knob, 28.0, Color(0.7, 0.9, 0.82, 0.62))
	var special_center := Vector2(size.x - 130.0, size.y - 135.0)
	var special_color := Color("d8ad59")
	special_color.a = 0.55 if not special_pressed else 0.88
	draw_circle(special_center, special_radius, Color(0.38, 0.22, 0.08, 0.42))
	draw_arc(special_center, special_radius, 0.0, TAU, 48, special_color, 3.0)
	draw_string(ThemeDB.fallback_font, special_center + Vector2(-18, 7), "诀", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, special_color)
