extends Node

signal state_changed(new_state: GameManager.GameState)
signal wave_finished(wave_num: int)
signal boss_spawned(boss_id: String, wave_num: int)
signal run_completed(final_wave: int)

const MAX_WAVES: int = 20
const RESONANCE_START_WAVE: int = 10
const DEFAULT_BOSS_SCENE: PackedScene = preload("res://scenes/entities/bosses/boss_red_crack.tscn")
const SPAWN_DIRECTION_ORDER = [0, 1, 2, 3]
const STANDARD_BOSS_IDS = ["RedCrack", "GreenPlague", "BlueArc", "YellowSand"]

# Enemy mix indexes: MELEE, ARROW, MAGIC, HEAL, HEAVY, ASSASSIN.
const ENEMY_MIXES: Dictionary = {
	"tutorial_melee": [1.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	"tutorial_arrow": [0.80, 0.15, 0.0, 0.0, 0.05, 0.0],
	"mixed_light": [0.58, 0.24, 0.10, 0.0, 0.04, 0.04],
	"mixed": [0.48, 0.23, 0.12, 0.07, 0.06, 0.04],
	"pressure": [0.34, 0.22, 0.16, 0.15, 0.08, 0.05],
	"late_pressure": [0.28, 0.21, 0.22, 0.16, 0.08, 0.05],
	"final": [0.26, 0.22, 0.23, 0.15, 0.09, 0.05]
}

# Explicit wave data keeps balance values inspectable and testable.
# Budgets count individual enemies, not spawn ticks.
const WAVE_PLAN: Array[Dictionary] = [
	{"level": 1, "day_budget": 4, "night_budget": 12, "spawn_interval": 2.40, "spawn_batch": 1, "directions": 1, "health_multiplier": 0.85, "damage_multiplier": 0.75, "speed_multiplier": 0.90, "enemy_mix": "tutorial_melee", "boss_id": ""},
	{"level": 1, "day_budget": 6, "night_budget": 16, "spawn_interval": 2.20, "spawn_batch": 1, "directions": 1, "health_multiplier": 0.90, "damage_multiplier": 0.82, "speed_multiplier": 0.94, "enemy_mix": "tutorial_arrow", "boss_id": ""},
	{"level": 2, "day_budget": 8, "night_budget": 20, "spawn_interval": 2.00, "spawn_batch": 1, "directions": 1, "health_multiplier": 0.95, "damage_multiplier": 0.90, "speed_multiplier": 0.98, "enemy_mix": "tutorial_arrow", "boss_id": ""},
	{"level": 2, "day_budget": 10, "night_budget": 26, "spawn_interval": 1.85, "spawn_batch": 1, "directions": 2, "health_multiplier": 1.00, "damage_multiplier": 0.96, "speed_multiplier": 1.00, "enemy_mix": "mixed_light", "boss_id": ""},
	{"level": 3, "day_budget": 12, "night_budget": 32, "spawn_interval": 1.70, "spawn_batch": 1, "directions": 2, "health_multiplier": 1.08, "damage_multiplier": 1.02, "speed_multiplier": 1.02, "enemy_mix": "mixed", "boss_id": ""},
	{"level": 3, "day_budget": 14, "night_budget": 38, "spawn_interval": 1.60, "spawn_batch": 1, "directions": 2, "health_multiplier": 1.12, "damage_multiplier": 1.06, "speed_multiplier": 1.04, "enemy_mix": "mixed", "boss_id": ""},
	{"level": 4, "day_budget": 16, "night_budget": 44, "spawn_interval": 1.50, "spawn_batch": 1, "directions": 3, "health_multiplier": 1.16, "damage_multiplier": 1.10, "speed_multiplier": 1.06, "enemy_mix": "mixed", "boss_id": "RedCrack"},
	{"level": 4, "day_budget": 18, "night_budget": 50, "spawn_interval": 1.40, "spawn_batch": 1, "directions": 3, "health_multiplier": 1.24, "damage_multiplier": 1.18, "speed_multiplier": 1.08, "enemy_mix": "pressure", "boss_id": ""},
	{"level": 5, "day_budget": 20, "night_budget": 56, "spawn_interval": 1.30, "spawn_batch": 1, "directions": 3, "health_multiplier": 1.32, "damage_multiplier": 1.26, "speed_multiplier": 1.10, "enemy_mix": "pressure", "boss_id": ""},
	{"level": 5, "day_budget": 22, "night_budget": 62, "spawn_interval": 1.22, "spawn_batch": 2, "directions": 4, "health_multiplier": 1.40, "damage_multiplier": 1.35, "speed_multiplier": 1.12, "enemy_mix": "pressure", "boss_id": "GreenPlague"},
	{"level": 6, "day_budget": 24, "night_budget": 68, "spawn_interval": 1.15, "spawn_batch": 2, "directions": 4, "health_multiplier": 1.48, "damage_multiplier": 1.44, "speed_multiplier": 1.14, "enemy_mix": "pressure", "boss_id": ""},
	{"level": 6, "day_budget": 26, "night_budget": 74, "spawn_interval": 1.08, "spawn_batch": 2, "directions": 4, "health_multiplier": 1.56, "damage_multiplier": 1.54, "speed_multiplier": 1.16, "enemy_mix": "pressure", "boss_id": ""},
	{"level": 7, "day_budget": 28, "night_budget": 80, "spawn_interval": 1.02, "spawn_batch": 2, "directions": 4, "health_multiplier": 1.64, "damage_multiplier": 1.64, "speed_multiplier": 1.18, "enemy_mix": "late_pressure", "boss_id": "BlueArc"},
	{"level": 7, "day_budget": 30, "night_budget": 86, "spawn_interval": 0.96, "spawn_batch": 2, "directions": 4, "health_multiplier": 1.72, "damage_multiplier": 1.74, "speed_multiplier": 1.20, "enemy_mix": "late_pressure", "boss_id": ""},
	{"level": 8, "day_budget": 32, "night_budget": 92, "spawn_interval": 0.90, "spawn_batch": 2, "directions": 4, "health_multiplier": 1.80, "damage_multiplier": 1.84, "speed_multiplier": 1.22, "enemy_mix": "late_pressure", "boss_id": ""},
	{"level": 8, "day_budget": 34, "night_budget": 98, "spawn_interval": 0.86, "spawn_batch": 2, "directions": 4, "health_multiplier": 1.90, "damage_multiplier": 1.95, "speed_multiplier": 1.24, "enemy_mix": "late_pressure", "boss_id": "YellowSand"},
	{"level": 9, "day_budget": 36, "night_budget": 104, "spawn_interval": 0.82, "spawn_batch": 2, "directions": 4, "health_multiplier": 2.00, "damage_multiplier": 2.06, "speed_multiplier": 1.26, "enemy_mix": "late_pressure", "boss_id": ""},
	{"level": 9, "day_budget": 38, "night_budget": 110, "spawn_interval": 0.78, "spawn_batch": 2, "directions": 4, "health_multiplier": 2.10, "damage_multiplier": 2.18, "speed_multiplier": 1.28, "enemy_mix": "late_pressure", "boss_id": ""},
	{"level": 10, "day_budget": 40, "night_budget": 116, "spawn_interval": 0.74, "spawn_batch": 2, "directions": 4, "health_multiplier": 2.20, "damage_multiplier": 2.30, "speed_multiplier": 1.30, "enemy_mix": "late_pressure", "boss_id": ""},
	{"level": 12, "day_budget": 42, "night_budget": 132, "spawn_interval": 0.65, "spawn_batch": 3, "directions": 4, "health_multiplier": 2.35, "damage_multiplier": 2.48, "speed_multiplier": 1.34, "enemy_mix": "final", "boss_id": "AscensionKing", "night_duration": 90.0}
]

const BOSS_SCHEDULE: Dictionary = {
	"RedCrack": {"wave": 7, "unlock_wave": 5, "display_name": "赤裂大妖", "health": 700.0, "speed": 68.0, "contact_damage": 14.0, "dash_damage": 28.0, "charge_cooldown": 4.6, "charge_aim_time": 1.8, "ability_cooldown": 7.0},
	"GreenPlague": {"wave": 10, "unlock_wave": 8, "display_name": "翠疫大妖", "health": 900.0, "speed": 58.0, "contact_damage": 16.0, "dash_damage": 32.0, "charge_cooldown": 4.4, "charge_aim_time": 1.9, "ability_cooldown": 6.0},
	"BlueArc": {"wave": 13, "unlock_wave": 11, "display_name": "蓝弧大妖", "health": 1150.0, "speed": 74.0, "contact_damage": 15.0, "dash_damage": 30.0, "charge_cooldown": 4.0, "charge_aim_time": 1.7, "ability_cooldown": 5.2},
	"YellowSand": {"wave": 16, "unlock_wave": 14, "display_name": "黄砂大妖", "health": 1450.0, "speed": 92.0, "contact_damage": 17.0, "dash_damage": 34.0, "charge_cooldown": 3.6, "charge_aim_time": 1.6, "ability_cooldown": 5.0},
	"AscensionKing": {"wave": 20, "unlock_wave": 20, "display_name": "飞升妖王", "health": 2400.0, "speed": 105.0, "contact_damage": 24.0, "dash_damage": 48.0, "charge_cooldown": 3.0, "charge_aim_time": 1.5, "ability_cooldown": 4.5}
}

@export var day_duration: float = 60.0
@export var night_duration: float = 60.0

var time_left: float = 0.0
var boss_spawned_ids: Dictionary = {}
var run_completed_flag: bool = false

func _ready():
	EventBus.boss_defeated.connect(_on_boss_defeated)
	var plan_errors := validate_wave_plan()
	for error in plan_errors:
		push_error("Wave plan: " + error)
	if GameManager.game_started:
		start_day()

func _process(delta: float):
	if not GameManager.game_started:
		return
	time_left -= delta
	if time_left <= 0:
		_on_timer_finished()

func _on_timer_finished():
	match GameManager.current_state:
		GameManager.GameState.DAY:
			start_night()
		GameManager.GameState.NIGHT:
			if GameManager.current_wave >= MAX_WAVES:
				complete_run()
			else:
				show_attunement_selection()

func _on_boss_defeated(boss_id: String) -> void:
	if boss_id == "AscensionKing" and GameManager.current_wave >= MAX_WAVES:
		complete_run()

func start_day():
	if run_completed_flag:
		return
	GameManager.current_state = GameManager.GameState.DAY
	time_left = float(get_wave_data().get("day_duration", day_duration))
	GameManager.update_current_stats()
	state_changed.emit(GameManager.current_state)
	if GameManager.debug_mode:
		print("[WAVE %d] Day Started | level %d" % [GameManager.current_wave, get_wave_level()])

func start_night():
	if run_completed_flag:
		return
	GameManager.current_state = GameManager.GameState.NIGHT
	time_left = float(get_wave_data().get("night_duration", night_duration))
	GameManager.activate_night_ward()
	GameManager.clear_day_event_bonus()
	GameManager.update_current_stats()
	state_changed.emit(GameManager.current_state)
	_spawn_scheduled_boss()
	if GameManager.debug_mode:
		print("[WAVE %d] Night Started | enemies %d | resonance %d" % [GameManager.current_wave, get_spawn_budget(true), get_resonance_layers()])

func show_attunement_selection():
	get_tree().paused = true
	EventBus.emit_signal("show_attunement_wheel")
	if GameManager.debug_mode:
		print("[WAVE %d] Night ended, showing Attunement Wheel" % GameManager.current_wave)

func start_next_wave():
	if run_completed_flag:
		return
	wave_finished.emit(GameManager.current_wave)
	GameManager.current_wave = mini(GameManager.current_wave + 1, MAX_WAVES)
	get_tree().paused = false
	start_day()

func reset_manager():
	time_left = 0.0
	boss_spawned_ids.clear()
	run_completed_flag = false
	if GameManager.debug_mode:
		print("[DEBUG] Wave Manager Reset | %d waves" % MAX_WAVES)

func get_wave_data(wave_num: int = -1) -> Dictionary:
	var requested_wave := GameManager.current_wave if wave_num < 1 else wave_num
	var safe_wave := clampi(requested_wave, 1, MAX_WAVES)
	return WAVE_PLAN[safe_wave - 1].duplicate(true)

func get_wave_level(wave_num: int = -1) -> int:
	return int(get_wave_data(wave_num).get("level", 1))

func get_spawn_budget(is_night: bool) -> int:
	var budget_key := "night_budget" if is_night else "day_budget"
	return int(get_wave_data().get(budget_key, 0))

func get_spawn_interval() -> float:
	return max(float(get_wave_data().get("spawn_interval", 1.0)), 0.2)

func get_spawn_batch_size() -> int:
	return max(int(get_wave_data().get("spawn_batch", 1)), 1)

func get_enemy_type_weights() -> Array:
	var mix_id: String = str(get_wave_data().get("enemy_mix", "mixed"))
	var weights: Array = ENEMY_MIXES.get(mix_id, ENEMY_MIXES["mixed"])
	return weights.duplicate()

func get_enemy_scaling(is_night: bool = true) -> Dictionary:
	var data := get_wave_data()
	var resonance := get_resonance_scaling()
	var phase_health := 1.0 if is_night else 0.90
	var phase_damage := 1.0 if is_night else 0.80
	var phase_speed := 1.0 if is_night else 0.96
	return {
		"level": int(data.get("level", 1)),
		"health": float(data.get("health_multiplier", 1.0)) * phase_health * resonance["health"],
		"damage": float(data.get("damage_multiplier", 1.0)) * phase_damage * resonance["damage"],
		"speed": float(data.get("speed_multiplier", 1.0)) * phase_speed * resonance["speed"],
		"heal": float(data.get("health_multiplier", 1.0)) * resonance["health"]
	}

func get_resonance_layers() -> int:
	if GameManager.current_wave < RESONANCE_START_WAVE:
		return 0
	var layers := 0
	for boss_id in STANDARD_BOSS_IDS:
		if boss_spawned_ids.has(boss_id) and not GameManager.boss_states.get(boss_id, false):
			layers += 1
	return layers

func get_resonance_scaling() -> Dictionary:
	var layers := get_resonance_layers()
	return {
		"health": 1.0 + layers * 0.05,
		"damage": 1.0 + layers * 0.05,
		"speed": 1.0 + layers * 0.03
	}

func get_active_spawn_directions() -> Array:
	var requested := int(get_wave_data().get("directions", 1))
	var active: Array = []
	for direction in SPAWN_DIRECTION_ORDER:
		var boss_id := get_boss_id_for_direction(direction)
		if boss_id != "" and GameManager.boss_states.get(boss_id, false):
			continue
		active.append(direction)
		if active.size() >= requested:
			break
	if active.is_empty():
		return SPAWN_DIRECTION_ORDER.duplicate()
	return active

func get_boss_id_for_direction(direction: int) -> String:
	match direction:
		0: return "RedCrack"
		1: return "GreenPlague"
		2: return "BlueArc"
		3: return "YellowSand"
	return ""

func get_boss_data(boss_id: String) -> Dictionary:
	return BOSS_SCHEDULE.get(boss_id, {}).duplicate(true)

func get_boss_stats(boss_id: String) -> Dictionary:
	var data := get_boss_data(boss_id)
	if data.is_empty():
		return {}
	var scheduled_wave := int(data.get("wave", GameManager.current_wave))
	var wave_delta := GameManager.current_wave - scheduled_wave
	var progression: float = 1.0 + float(maxi(wave_delta, 0)) * 0.06
	var early_factor: float = maxf(0.85, 1.0 - float(maxi(-wave_delta, 0)) * 0.05)
	var health_factor: float = progression * early_factor
	var damage_factor: float = (1.0 + float(maxi(wave_delta, 0)) * 0.04) * early_factor
	var resonance := get_resonance_scaling()
	return {
		"display_name": data.get("display_name", boss_id),
		"health": float(data.get("health", 500.0)) * health_factor * resonance["health"],
		"speed": float(data.get("speed", 60.0)) * (1.0 + float(maxi(wave_delta, 0)) * 0.02) * early_factor * resonance["speed"],
		"contact_damage": float(data.get("contact_damage", 10.0)) * damage_factor * resonance["damage"],
		"dash_damage": float(data.get("dash_damage", 20.0)) * damage_factor * resonance["damage"],
		"charge_cooldown": float(data.get("charge_cooldown", 5.0)),
		"charge_aim_time": float(data.get("charge_aim_time", 2.0))
	}

func try_spawn_boss(boss_id: String, boss_scene: PackedScene, spawn_position: Vector2) -> bool:
	var data := get_boss_data(boss_id)
	if data.is_empty() or boss_spawned_ids.has(boss_id) or GameManager.boss_states.get(boss_id, false):
		return false
	if GameManager.current_wave < int(data.get("unlock_wave", data.get("wave", MAX_WAVES))):
		return false
	return _spawn_boss(boss_id, boss_scene, spawn_position)

func _spawn_scheduled_boss():
	var boss_id: String = str(get_wave_data().get("boss_id", ""))
	if boss_id.is_empty():
		return
	if boss_spawned_ids.has(boss_id) or GameManager.boss_states.get(boss_id, false):
		return
	_spawn_boss(boss_id, DEFAULT_BOSS_SCENE, get_boss_spawn_position(boss_id))

func _spawn_boss(boss_id: String, boss_scene: PackedScene, spawn_position: Vector2) -> bool:
	var player = get_tree().get_first_node_in_group("Player")
	var core = get_tree().get_first_node_in_group("LifeCore")
	var host: Node = player.get_parent() if player and player.get_parent() else core.get_parent() if core and core.get_parent() else null
	if not host:
		return false
	var scene: PackedScene = boss_scene if boss_scene else DEFAULT_BOSS_SCENE
	var boss = scene.instantiate()
	var stats := get_boss_stats(boss_id)
	if boss.has_method("configure_boss"):
		boss.configure_boss(boss_id, stats)
	host.add_child(boss)
	boss.global_position = spawn_position
	boss_spawned_ids[boss_id] = true
	boss_spawned.emit(boss_id, GameManager.current_wave)
	if GameManager.debug_mode:
		print("[BOSS] %s spawned at wave %d | HP %.0f" % [stats.get("display_name", boss_id), GameManager.current_wave, stats.get("health", 0.0)])
	return true

func get_boss_spawn_position(boss_id: String) -> Vector2:
	var center = get_tree().get_first_node_in_group("LifeCore")
	if not center:
		center = get_tree().get_first_node_in_group("Player")
	if not center:
		return Vector2.ZERO
	var angle := 0.0
	match boss_id:
		"RedCrack": angle = -PI / 2.0
		"GreenPlague": angle = PI / 2.0
		"BlueArc": angle = 0.0
		"YellowSand": angle = PI
		_: angle = 0.0
	return center.global_position + Vector2.from_angle(angle) * 620.0

func complete_run():
	if run_completed_flag:
		return
	run_completed_flag = true
	GameManager.game_started = false
	GameManager.run_won = true
	get_tree().paused = false
	EventBus.run_completed.emit(GameManager.current_wave)
	run_completed.emit(GameManager.current_wave)
	if GameManager.debug_mode:
		print("[RUN] Ascension complete at wave %d" % GameManager.current_wave)

func validate_wave_plan() -> Array[String]:
	var errors: Array[String] = []
	if WAVE_PLAN.size() != MAX_WAVES:
		errors.append("expected %d waves, got %d" % [MAX_WAVES, WAVE_PLAN.size()])
	var previous_level := 0
	var previous_interval := INF
	var previous_directions := 0
	for index in range(WAVE_PLAN.size()):
		var wave_num := index + 1
		var data: Dictionary = WAVE_PLAN[index]
		if int(data.get("level", 0)) < previous_level:
			errors.append("wave %d level regresses" % wave_num)
		if float(data.get("spawn_interval", 0.0)) >= previous_interval:
			if wave_num > 1:
				errors.append("wave %d spawn interval does not tighten" % wave_num)
		if int(data.get("directions", 0)) < previous_directions:
			errors.append("wave %d direction count regresses" % wave_num)
		if int(data.get("day_budget", 0)) <= 0 or int(data.get("night_budget", 0)) <= 0:
			errors.append("wave %d has empty spawn budget" % wave_num)
		var boss_id: String = str(data.get("boss_id", ""))
		if not boss_id.is_empty() and not BOSS_SCHEDULE.has(boss_id):
			errors.append("wave %d references unknown boss %s" % [wave_num, boss_id])
		previous_level = int(data.get("level", 0))
		previous_interval = float(data.get("spawn_interval", 0.0))
		previous_directions = int(data.get("directions", 0))
	var expected_boss_waves := {"RedCrack": 7, "GreenPlague": 10, "BlueArc": 13, "YellowSand": 16, "AscensionKing": 20}
	for boss_id in expected_boss_waves:
		if int(BOSS_SCHEDULE[boss_id]["wave"]) != expected_boss_waves[boss_id]:
			errors.append("boss %s schedule mismatch" % boss_id)
	if str(WAVE_PLAN[MAX_WAVES - 1].get("boss_id", "")) != "AscensionKing":
		errors.append("final wave has no AscensionKing")
	return errors
