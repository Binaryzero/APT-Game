extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("[RELIABILITY_FAIL] " + message)


func _card_ids(cards: Array[Dictionary]) -> Array[String]:
	var identifiers: Array[String] = []
	for card in cards:
		identifiers.append(String(card.id))
	return identifiers


func _find_hand_card(game: Node, card_id: String) -> int:
	for index in range(game.player_hand.size()):
		if String(game.player_hand[index].id) == card_id:
			return index
	return -1


func _local_submission(game: Node, submission_id: String) -> Dictionary:
	for submission: Dictionary in game.local_scores:
		if String(submission.get("submission_id", "")) == submission_id:
			return submission
	return {}


func _settle_frames(count: int = 12) -> void:
	for frame in range(count):
		await process_frame


func _run() -> void:
	var packed_scene := load("res://scenes/card_game.tscn") as PackedScene
	_expect(packed_scene != null, "card game scene loads")
	if packed_scene == null:
		quit(1)
		return
	var game := packed_scene.instantiate()
	root.add_child(game)
	await process_frame
	game.debug_fast = true

	game.start_new_run(91234)
	var first_player_order := _card_ids(game.player_deck)
	var first_enemy_order := _card_ids(game.enemy_deck)
	game.start_new_run(91234)
	_expect(_card_ids(game.player_deck) == first_player_order, "same seed reproduces player deck order")
	_expect(_card_ids(game.enemy_deck) == first_enemy_order, "same seed reproduces enemy deck order")
	game.start_new_run(91235)
	_expect(_card_ids(game.player_deck) != first_player_order or _card_ids(game.enemy_deck) != first_enemy_order, "different seed changes gameplay ordering")
	game.rng.seed = 77
	var expected_next_random: int = game.rng.randi()
	game.rng.seed = 77
	game._make_run_submission(false)
	_expect(game.rng.randi() == expected_next_random, "submission identifiers do not consume gameplay RNG")

	game.start_new_run(91)
	game._skip_tutorial()
	game.player_mana = 2
	game.player_max_mana = 2
	var precise_index := _find_hand_card(game, "precise_chop")
	_expect(precise_index >= 0, "transaction regression starts with Precise Chop in hand")
	var precise_uid := int(game.player_hand[precise_index].uid)
	var hand_size_before_target: int = game.player_hand.size()
	var armor_before_target := int(game.player_armor)
	var target_health_before := int(game.enemy_board[0].health)
	game._on_hand_card_pressed(precise_index)
	var hero_power_button := game.screen_layer.find_child("HeroPowerButton", true, false) as Button
	_expect(int(game.pending_action.get("card_uid", -1)) == precise_uid, "target transaction is bound to a stable card UID")
	_expect(hero_power_button != null and hero_power_button.disabled, "Chef Power is disabled while a card payment is pending")
	game.use_hero_power()
	_expect(game.player_mana == 2 and not game.hero_power_used and game.player_armor == armor_before_target, "Chef Power cannot spend Mana during a target transaction")
	_expect(int(game.pending_action.get("card_uid", -1)) == precise_uid and game.player_hand.size() == hand_size_before_target, "blocked competing action preserves the target transaction and selected card")
	game.player_mana = 0
	game._on_enemy_unit_pressed(0)
	_expect(game.player_mana == 0, "target resolution can never make Mana negative")
	_expect(game.pending_action.is_empty(), "failed target payment closes the stale transaction")
	_expect(game.player_hand.size() == hand_size_before_target and _find_hand_card(game, "precise_chop") >= 0, "failed target payment preserves the selected card")
	_expect(int(game.enemy_board[0].health) == target_health_before, "failed target payment cannot mutate the target")
	game.player_mana = 1
	precise_index = _find_hand_card(game, "precise_chop")
	game._on_hand_card_pressed(precise_index)
	game._on_enemy_unit_pressed(0)
	_expect(game.player_mana == 0 and game.player_hand.size() == hand_size_before_target - 1, "an affordable target transaction pays and removes its card exactly once")
	_expect(game.enemy_board.is_empty(), "an affordable target transaction still resolves its effect")

	game.start_new_run(92)
	game._skip_tutorial()
	_expect(game.completed_battles == 0, "a new run resets authoritative completed-battle accounting")
	game.debug_force_battle_victory()
	_expect(game.screen_name == "kitchen" and game.completed_battles == 1, "first encounter victory records one completed battle before Kitchen Break")
	game._open_pause_menu()
	game._resign_run()
	var first_kitchen_submission := _local_submission(game, game.last_run_submission_id)
	_expect(int(first_kitchen_submission.get("battles_cleared", -1)) == 1, "resigning from the first Kitchen Break records one cleared battle")

	game.start_new_run(93)
	game._skip_tutorial()
	game.debug_force_battle_victory()
	game._skip_reward()
	game._continue_from_kitchen()
	_expect(game.screen_name == "route" and game.completed_battles == 1, "route selection retains one completed battle")
	game._open_pause_menu()
	game._resign_run()
	var route_submission := _local_submission(game, game.last_run_submission_id)
	_expect(int(route_submission.get("battles_cleared", -1)) == 1, "resigning from route selection records one cleared battle")

	game.start_new_run(94)
	game._skip_tutorial()
	game.debug_force_battle_victory()
	game._skip_reward()
	game._continue_from_kitchen()
	game._choose_route("mold_monarch")
	game.debug_force_battle_victory()
	_expect(game.screen_name == "kitchen" and game.completed_battles == 2, "second encounter victory records two completed battles before Kitchen Break")
	game._open_pause_menu()
	game._resign_run()
	var second_kitchen_submission := _local_submission(game, game.last_run_submission_id)
	_expect(int(second_kitchen_submission.get("battles_cleared", -1)) == 2, "resigning from the second Kitchen Break records two cleared battles")

	game.start_new_run(101)
	game._skip_tutorial()
	var battle_results: Array[bool] = []
	game.battle_finished.connect(func(victory: bool): battle_results.append(victory))
	game.player_health = 1
	game.player_deck.clear()
	game.player_discard.clear()
	game.player_hand.clear()
	var runs_before_fatigue := int(game.lifetime.runs)
	game._begin_player_turn(true)
	_expect(game.screen_name == "end" and game.run_result == "defeat", "lethal start-of-turn fatigue ends the run immediately")
	_expect(not game.run_active and not game.is_player_turn, "lethal fatigue cannot leave an active player turn")
	_expect(int(game.lifetime.runs) == runs_before_fatigue + 1, "lethal fatigue records one run")
	_expect(battle_results == [false], "lethal fatigue emits one defeat result")
	game._check_end_state()
	game._check_end_state()
	_expect(int(game.lifetime.runs) == runs_before_fatigue + 1 and battle_results == [false], "repeated end-state checks are idempotent")

	game.start_new_run(202)
	game.battle_number = 3
	game.enemy_health = 0
	var results_before_victory := battle_results.size()
	game._check_end_state()
	game._check_end_state()
	_expect(game.run_result == "victory" and battle_results.size() == results_before_victory + 1 and battle_results.back(), "final victory emits exactly once")

	game.start_new_run(303)
	game._skip_tutorial()
	game.end_player_turn()
	game.pause_open = true
	game.get_tree().paused = true
	game._resign_run()
	var runs_after_resign := int(game.lifetime.runs)
	await _settle_frames()
	_expect(game.screen_name == "end" and game.run_result == "defeat", "waiting enemy turn cannot leave the result screen after resignation")
	_expect(int(game.lifetime.runs) == runs_after_resign, "waiting enemy turn cannot finish a resigned run twice")

	game.start_new_run(404)
	game._skip_tutorial()
	game.end_player_turn()
	game.pause_open = true
	game.get_tree().paused = true
	game._resign_run()
	game.start_new_run(505)
	var replacement_health := int(game.player_health)
	var replacement_hand := _card_ids(game.player_hand)
	var replacement_enemy_board: Array[Dictionary] = game.enemy_board.duplicate(true)
	await _settle_frames()
	_expect(game.screen_name == "battle" and game.is_player_turn and game.turn_number == 1, "old enemy turn cannot take control from a replacement run")
	_expect(game.player_health == replacement_health and _card_ids(game.player_hand) == replacement_hand and game.enemy_board == replacement_enemy_board, "old enemy turn cannot mutate replacement run state")

	game.start_new_run(606)
	game._skip_tutorial()
	game.end_player_turn()
	game.pause_open = true
	game.get_tree().paused = true
	game._resume_game()
	await _settle_frames(30)
	_expect(game.screen_name == "battle" and game.is_player_turn and game.turn_number == 2, "ordinary pause and resume preserves the current enemy turn")

	var passed := failures.is_empty()
	game.free()
	await create_timer(0.15).timeout
	await process_frame
	await process_frame
	if passed:
		print("[RELIABILITY_PASS] deterministic shuffles, atomic target payment, intermission scoring, lethal fatigue, idempotent completion, and stale-turn cancellation validated")
		quit(0)
	else:
		quit(1)
