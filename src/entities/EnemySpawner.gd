extends Node2D
class_name EnemySpawner

@export var enemy_scene: PackedScene
@export var spawn_radius: float = 500.0

@export var spawn_interval: float = 1.0 # 缩短生成间隔
@export var enemies_per_spawn: int = 2   # 每次生成的数量

var spawn_timer: float = 0.0

func _process(delta: float):
	if GameManager.current_state == GameManager.GameState.SHOP:
		return
		
	spawn_timer -= delta
	if spawn_timer <= 0:
		for i in range(enemies_per_spawn):
			spawn_enemy()
		# 随着波数略微提升生成强度
		var interval_reduction = (GameManager.current_wave - 1) * 0.05
		spawn_timer = max(0.2, spawn_interval - interval_reduction)

func spawn_enemy():
	if not enemy_scene:
		return
	
	# 计算可用方向 (排除已斩首的方向)
	var available_directions = []
	if not GameManager.boss_states.get("RedCrack", false): available_directions.append(0) # North
	# TODO: Add other directions when implemented
	# Temporarily allow all if none matched
	if available_directions.size() == 0:
		available_directions = [0, 1, 2, 3] 

	var spawn_dir = available_directions.pick_random()
	var angle = 0.0
	match spawn_dir:
		0: angle = -PI/2 # North
		1: angle = PI/2  # South
		2: angle = 0.0   # East
		3: angle = PI    # West
	
	# 增加角度随机范围，从 0.5 增加到 0.8，让散布更广
	angle += randf_range(-0.8, 0.8)
	
	# 确保生成的点在正方形边缘内
	var R = spawn_radius
	var pos = Vector2.ZERO
	
	var dir = Vector2.from_angle(angle)
	var t = 0.0
	if abs(dir.x) > abs(dir.y):
		t = R / abs(dir.x)
	else:
		t = R / abs(dir.y)
	
	pos = dir * t
	
	# 增加位置随机偏移 (Jitter)，防止完全堆在一条线上
	var jitter = Vector2(randf_range(-50, 50), randf_range(-50, 50))
	pos += jitter
	
	# 确保最终位置不会超出 1000 的物理边界太远 (保持在 0.98 以内)
	pos.x = clamp(pos.x, -R * 0.98, R * 0.98)
	pos.y = clamp(pos.y, -R * 0.98, R * 0.98)
		
	var enemy = enemy_scene.instantiate()
	
	# 设置敌人类型：远程/近战比例 1:10
	if randf() < 0.1: # 约 10% 概率生成远程
		enemy.enemy_type = Enemy.EnemyType.RANGED
	else:
		enemy.enemy_type = Enemy.EnemyType.MELEE
		
	enemy.global_position = global_position + pos
	get_parent().add_child(enemy)
