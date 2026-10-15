extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("[EXPORTED_RUNTIME_FAIL] " + message)


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return bool(predicate.call())


func _run() -> void:
	var packed_scene := load("res://scenes/card_game.tscn") as PackedScene
	_expect(packed_scene != null, "exported card game scene loads")
	if packed_scene == null:
		quit(1)
		return

	var game := packed_scene.instantiate()
	root.add_child(game)
	await process_frame
	game.start_new_run(4242)
	_expect(game.screen_name == "battle", "exported run enters battle")
	_expect(game.player_hand.is_empty(), "opening battle renders an empty hand before dealing")
	_expect(game.opening_hand_in_progress and not game.tutorial_active, "tutorial waits for the opening deal")
	var opening_finished := await _wait_until(func(): return not game.opening_hand_in_progress, 8.0)
	_expect(opening_finished and game.player_hand.size() == 5, "opening deal draws five cards")
	_expect(game.tutorial_active, "tutorial starts after the opening deal")
	game._skip_tutorial()

	var defeated_portrait := game.player_hero_control as Control
	game.player_health = 1
	game._damage_player(1, true)
	game._check_end_state()
	var defeat_drained := await _wait_until(func(): return not game.juice_processing and game.juice_events.is_empty(), 5.0)
	_expect(game.screen_name == "end" and game.run_result == "defeat", "lethal damage reaches the defeat screen")
	_expect(not is_instance_valid(defeated_portrait) and game.player_hero_control == null, "defeat clears the freed portrait reference")
	_expect(defeat_drained, "lethal damage presentation drains")

	game.debug_fast = true
	game.start_new_run(5252)
	await process_frame
	game._skip_tutorial()
	game.end_player_turn()
	game.pause_open = true
	game.get_tree().paused = true
	game._resign_run()
	var runs_after_resign := int(game.lifetime.runs)
	await process_frame
	await process_frame
	_expect(game.screen_name == "end" and int(game.lifetime.runs) == runs_after_resign, "resignation cancels the waiting enemy turn")

	var passed := failures.is_empty()
	game.free()
	await create_timer(0.15).timeout
	await process_frame
	await process_frame
	if passed:
		print("[EXPORTED_RUNTIME_PASS] opening deal, lethal defeat, and stale-turn cancellation validated in the packaged game")
		quit(0)
	else:
		quit(1)
