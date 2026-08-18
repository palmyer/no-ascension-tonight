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

func _ready() -> void:
	_load_settings()
	_apply_window_settings()

func set_resolution(value: Vector2i) -> void:
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
	resolution = Vector2i(width, height)
	fullscreen = bool(config.get_value("display", "fullscreen", false))

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "width", resolution.x)
	config.set_value("display", "height", resolution.y)
	config.set_value("display", "fullscreen", fullscreen)
	config.save(SETTINGS_PATH)
