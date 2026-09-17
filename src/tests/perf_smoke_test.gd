extends Node2D
## 性能冒烟测试：满密度敌潮下统计平均/最差帧耗时（headless 仅反映 CPU 侧成本）。
## 不注入 game_started/夜间状态——WaveManager 会立刻进入波间并暂停场景，
## 本测试只采样敌人 AI 与行走动画的持续 CPU 成本。

const ENEMY_COUNT := 150
const SAMPLE_SECONDS := 3.0

var _frames: int = 0
var _worst_ms: float = 0.0
var _elapsed: float = 0.0
var _last_ticks: int = 0

func _ready() -> void:
	GameManager.current_wave = 16
	var enemy_scene: PackedScene = load("res://scenes/entities/enemies/enemy.tscn")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260916
	for index in range(ENEMY_COUNT):
		var enemy := enemy_scene.instantiate()
		enemy.enemy_type = index % 6
		enemy.is_elite = index % 20 == 0
		var angle := TAU * float(index) / float(ENEMY_COUNT)
		var radius := 200.0 + rng.randf() * 500.0
		enemy.position = Vector2.from_angle(angle) * radius
		add_child(enemy)
	_last_ticks = Time.get_ticks_usec()

func _physics_process(delta: float) -> void:
	var now := int(Time.get_ticks_usec())
	var frame_ms := (now - _last_ticks) / 1000.0
	_last_ticks = now
	_frames += 1
	_worst_ms = maxf(_worst_ms, frame_ms)
	_elapsed += delta
	if _elapsed >= SAMPLE_SECONDS:
		_report()

func _report() -> void:
	var avg_ms := _elapsed * 1000.0 / maxf(float(_frames), 1.0)
	print("perf smoke: enemies=%d frames=%d avg=%.2fms worst=%.2fms" % [ENEMY_COUNT, _frames, avg_ms, _worst_ms])
	# CPU 侧软阈值：平均帧耗时超过 25ms 视为需要优化。
	if avg_ms > 25.0:
		print("perf smoke FAILED: avg frame time above 25ms budget")
		get_tree().quit(1)
		return
	print("perf smoke passed: avg frame time within budget")
	get_tree().quit(0)
