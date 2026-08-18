extends SceneTree

func _init() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var wave_manager: Node = get_root().get_node_or_null("WaveManager")
	if not wave_manager:
		push_error("WaveManager autoload is unavailable")
		quit(1)
		return

	var errors: Array[String] = wave_manager.validate_wave_plan()
	var expected_boss_waves := {
		7: "RedCrack",
		10: "GreenPlague",
		13: "BlueArc",
		16: "YellowSand",
		20: "AscensionKing"
	}
	var expected_route_counts := {1: 1, 4: 2, 7: 3, 10: 4}

	for wave in range(1, wave_manager.MAX_WAVES + 1):
		var data: Dictionary = wave_manager.get_wave_data(wave)
		if int(data.get("day_budget", 0)) <= 0 or int(data.get("night_budget", 0)) <= 0:
			errors.append("wave %d has invalid budget" % wave)
		if expected_boss_waves.has(wave) and data.get("boss_id", "") != expected_boss_waves[wave]:
			errors.append("wave %d boss trigger mismatch" % wave)
		if expected_route_counts.has(wave) and int(data.get("directions", 0)) != expected_route_counts[wave]:
			errors.append("wave %d route count mismatch" % wave)

	if errors.is_empty():
		print("Wave plan validation passed: %d waves" % wave_manager.MAX_WAVES)
		quit(0)
		return

	for error in errors:
		push_error(error)
	quit(1)
