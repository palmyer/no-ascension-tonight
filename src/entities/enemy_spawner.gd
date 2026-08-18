extends Node2D
class_name EnemySpawner

@export var enemy_scene: PackedScene
@export var spawn_radius: float = 500.0

@export var spawn_interval: float = 1.0
@export var enemies_per_spawn: int = 1

var spawn_timer: float = 0.0
var tracked_wave: int = -1
var tracked_state: int = -1
var phase_spawned: int = 0

func _process(delta: float):
	if not GameManager.game_started:
		return
	var state := GameManager.current_state
	if state != GameManager.GameState.DAY and state != GameManager.GameState.NIGHT:
		return

	if tracked_wave != GameManager.current_wave or tracked_state != state:
		tracked_wave = GameManager.current_wave
		tracked_state = state
		phase_spawned = 0
		spawn_timer = 0.0

	var is_night := state == GameManager.GameState.NIGHT
	var phase_budget := WaveManager.get_spawn_budget(is_night)
	if phase_spawned >= phase_budget:
		return

	spawn_timer -= delta
	if spawn_timer <= 0:
		var batch_size: int = maxi(WaveManager.get_spawn_batch_size(), enemies_per_spawn)
		var remaining: int = phase_budget - phase_spawned
		var spawn_count: int = mini(batch_size, remaining)
		for i in range(spawn_count):
			if spawn_enemy():
				phase_spawned += 1
		spawn_timer = WaveManager.get_spawn_interval()

func spawn_enemy() -> bool:
	if not enemy_scene:
		return false

	var available_directions: Array = WaveManager.get_active_spawn_directions()

	var spawn_dir = available_directions.pick_random()
	var angle = 0.0
	match spawn_dir:
		0: angle = -PI/2 # North
		1: angle = PI/2  # South
		2: angle = 0.0   # East
		3: angle = PI    # West

	angle += randf_range(-0.8, 0.8)

	var radius := spawn_radius
	var pos = Vector2.ZERO

	var dir = Vector2.from_angle(angle)
	var t = 0.0
	if abs(dir.x) > abs(dir.y):
		t = radius / abs(dir.x)
	else:
		t = radius / abs(dir.y)

	pos = dir * t

	var jitter = Vector2(randf_range(-50, 50), randf_range(-50, 50))
	pos += jitter

	pos.x = clamp(pos.x, -radius * 0.98, radius * 0.98)
	pos.y = clamp(pos.y, -radius * 0.98, radius * 0.98)

	var enemy = enemy_scene.instantiate()
	enemy.enemy_type = pick_enemy_type()

	enemy.global_position = global_position + pos
	get_parent().add_child(enemy)
	return true

func pick_enemy_type() -> Enemy.EnemyType:
	var weights: Array = WaveManager.get_enemy_type_weights()
	var roll := randf()
	var cumulative := 0.0
	for index in range(min(weights.size(), 4)):
		cumulative += float(weights[index])
		if roll < cumulative:
			return index
	return Enemy.EnemyType.MELEE
