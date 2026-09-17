extends Node

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_RESOLUTION := Vector2i(1920, 1080)
const RESOLUTION_OPTIONS = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
]

var resolution: Vector2i = DEFAULT_RESOLUTION
var fullscreen: bool = false
# 特效质量：high 完整反馈；low 面向低端真机，跳过火花并收紧飘字并发。
var visual_quality: String = "high"

func is_fx_low_quality() -> bool:
	return visual_quality == "low"

## 静态访问入口：打击反馈等静态工厂在无法引用实例时使用。
static func fx_low_quality() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		return false
	var node := tree.root.get_node_or_null("SettingsManager")
	return node != null and str(node.get("visual_quality")) == "low"

func set_visual_quality(value: String) -> void:
	visual_quality = "low" if value == "low" else "high"
	_save_settings()

func _ready() -> void:
	_load_settings()
	_apply_window_settings()

func set_resolution(value: Vector2i) -> void:
	if not RESOLUTION_OPTIONS.has(value):
		resolution = DEFAULT_RESOLUTION
	else:
		resolution = value
	if not fullscreen:
		_apply_window_settings()
	_save_settings()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_window_settings()
	_save_settings()

func _apply_window_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return

	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return

	var width := int(config.get_value("display", "width", DEFAULT_RESOLUTION.x))
	var height := int(config.get_value("display", "height", DEFAULT_RESOLUTION.y))
	var loaded_resolution := Vector2i(width, height)
	resolution = loaded_resolution if RESOLUTION_OPTIONS.has(loaded_resolution) else DEFAULT_RESOLUTION
	fullscreen = bool(config.get_value("display", "fullscreen", false))
	visual_quality = "low" if str(config.get_value("performance", "visual_quality", "high")) == "low" else "high"

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "width", resolution.x)
	config.set_value("display", "height", resolution.y)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("performance", "visual_quality", visual_quality)
	if config.save(SETTINGS_PATH) != OK:
		# Settings are optional; a failed save should never prevent the run from
		# starting or leave an invalid in-memory configuration behind.
		resolution = DEFAULT_RESOLUTION if not RESOLUTION_OPTIONS.has(resolution) else resolution
