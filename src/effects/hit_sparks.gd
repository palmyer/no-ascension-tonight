extends CPUParticles2D
class_name HitSparks

## 打击反馈命中火花：沿攻击来源方向短促飞溅后自动销毁。

const SETTINGS_SCRIPT = preload("res://src/autoload/settings_manager.gd")

static var _spark_texture: ImageTexture

static func _get_spark_texture() -> ImageTexture:
	if not _spark_texture:
		var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_spark_texture = ImageTexture.create_from_image(image)
	return _spark_texture

static func spawn(parent: Node, world_position: Vector2, direction: Vector2, color: Color = Color("ffd9a0")) -> void:
	if not parent or not is_instance_valid(parent):
		return
	# 低特效质量跳过火花，只保留飘字与震屏等低成本反馈。
	if SETTINGS_SCRIPT.fx_low_quality():
		return
	var node := HitSparks.new()
	node.global_position = world_position
	node.direction = direction if direction.length_squared() > 0.01 else Vector2.UP
	node.color = color
	parent.add_child(node)
	node._fire()

func _fire() -> void:
	texture = _get_spark_texture()
	one_shot = true
	emitting = true
	amount = 5
	lifetime = 0.28
	explosiveness = 1.0
	spread = 42.0
	initial_velocity_min = 90.0
	initial_velocity_max = 210.0
	gravity = Vector2(0, 320)
	scale_amount_min = 0.7
	scale_amount_max = 1.4
	z_index = 9
	get_tree().create_timer(0.5).timeout.connect(queue_free)
