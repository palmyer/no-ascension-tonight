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
		
	var enemy = enemy_scene.instantiate()
	
	# 设置敌人类型：远程/近战比例 1:10
	if randf() < 0.1: # 约 10% 概率生成远程
		enemy.enemy_type = Enemy.EnemyType.RANGED
	else:
		enemy.enemy_type = Enemy.EnemyType.MELEE
		
	var angle = randf() * TAU
	var pos = Vector2.from_angle(angle) * spawn_radius
	enemy.global_position = global_position + pos
	get_parent().add_child(enemy)
