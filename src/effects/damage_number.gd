extends Label
class_name DamageNumber

## 打击反馈伤害飘字。普通白色、暴击黄色放大、属性反应按反应色、持续伤害灰色小字。
## 带并发护栏：同屏数量超限时优先丢弃普通飘字，避免怪海下节点堆积。

const HIGH_QUALITY_CAP := 60
const LOW_QUALITY_CAP := 20
const SETTINGS_SCRIPT = preload("res://src/autoload/settings_manager.gd")

static var _alive_count: int = 0

static func spawn(parent: Node, world_position: Vector2, amount: float, kind: String = "normal", color: Color = Color.WHITE) -> void:
	if not parent or not is_instance_valid(parent):
		return
	var quality_cap := LOW_QUALITY_CAP if SETTINGS_SCRIPT.fx_low_quality() else HIGH_QUALITY_CAP
	if _alive_count >= quality_cap and (kind == "normal" or kind == "dot"):
		# 关键反馈（暴击/反应）不受上限影响，保证高光时刻必达。
		return
	var node := DamageNumber.new()
	node.text = str(int(round(amount))) if amount >= 1.0 else "1"
	node.global_position = world_position + Vector2(randf_range(-10.0, 10.0), randf_range(-18.0, -6.0))
	match kind:
		"crit":
			node.add_theme_font_size_override("font_size", 22)
			node.modulate = Color("ffd452")
		"reaction":
			node.add_theme_font_size_override("font_size", 19)
			node.modulate = color
		"dot":
			node.add_theme_font_size_override("font_size", 13)
			node.modulate = Color("c8c8c8")
		_:
			node.add_theme_font_size_override("font_size", 16)
			node.modulate = Color.WHITE
	parent.add_child(node)
	node._animate()

func _animate() -> void:
	_alive_count += 1
	z_index = 20
	var drift := Vector2(randf_range(-14.0, 14.0), -34.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + drift, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.55).set_delay(0.2)
	tween.chain().tween_callback(_release)

func _release() -> void:
	_alive_count = maxi(_alive_count - 1, 0)
	queue_free()
