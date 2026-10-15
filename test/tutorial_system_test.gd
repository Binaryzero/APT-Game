extends SceneTree

const DB := preload("res://scripts/card_database.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error("[TUTORIAL_FAIL] " + message)


func _step_id(game: Node) -> String:
    return String(game._tutorial_current_step().get("id", ""))


func _find_hand_card(game: Node, card_id: String) -> int:
    for index in range(game.player_hand.size()):
        if String(game.player_hand[index].id) == card_id:
            return index
    return -1


func _wait_for_opening_hand(game: Node, timeout_seconds := 6.0) -> void:
    var elapsed := 0.0
    while game.opening_hand_in_progress and elapsed < timeout_seconds:
        await create_timer(0.05).timeout
        elapsed += 0.05


func _run() -> void:
    _expect(DB.art("tutorial_mise") != null, "GPT Image 2 Mise guide art is imported and registered")
    _expect(DB.art("tutorial_pointer") != null, "GPT Image 2 spoon pointer art is imported and registered")

    var packed_scene := load("res://scenes/card_game.tscn") as PackedScene
    _expect(packed_scene != null, "card game scene loads with the tutorial system")
    if packed_scene == null:
        quit(1)
        return

    var game := packed_scene.instantiate()
    root.add_child(game)
    await process_frame
    game.sound_muted = true
    game.start_new_run(260902)

    _expect(game.opening_hand_in_progress, "new-run opening begins with a staged deal")
    _expect(game.player_hand.is_empty(), "the staged deal renders an empty opening hand first")
    _expect(not game.tutorial_active and not game.tutorial_callout.visible, "tutorial stays hidden before the opening draw")
    _expect(game.input_locked, "battle actions stay locked during the opening draw")
    var expected_opening_uids: Array[int] = []
    for draw_offset in range(5):
        expected_opening_uids.append(int(game.player_deck[game.player_deck.size() - 1 - draw_offset].uid))

    await create_timer(0.1).timeout
    _expect(game.player_hand.is_empty(), "the empty hand remains visible during the battle intro")
    _expect(not game.tutorial_active, "tutorial remains inactive throughout the empty-hand intro")

    await _wait_for_opening_hand(game)

    _expect(not game.opening_hand_in_progress, "all five opening draws finish within the presentation window")
    _expect(game.player_hand.size() == 5, "the opening sequence draws five cards")
    for opening_index in range(mini(expected_opening_uids.size(), game.player_hand.size())):
        _expect(int(game.player_hand[opening_index].uid) == expected_opening_uids[opening_index], "opening card %d comes from the top of the deck" % (opening_index + 1))
    _expect(game.tutorial_active, "every normal new run starts the tutorial")
    var visible_lessons := 0
    var click_through_lessons := 0
    for step: Dictionary in game.TUTORIAL_STEPS:
        var advance := String(step.get("advance", ""))
        if advance != "wait":
            visible_lessons += 1
        if advance == "next":
            click_through_lessons += 1
    _expect(visible_lessons == 4, "streamlined tutorial has four visible lessons")
    _expect(click_through_lessons == 0, "no lesson pauses gameplay behind a Next button")
    _expect(_step_id(game) == "play_precise_chop", "new-run tutorial starts on the first live card action")
    _expect(game.tutorial_callout.visible and game.tutorial_callout.get_child_count() > 0, "opening action callout is visibly rendered")
    _expect(game.is_player_turn and not game.input_locked, "the opening player turn begins immediately")
    var focus_ring := game.tutorial_callout.find_child("TutorialFocusRing", true, false) as Control
    var callout_panel := game.tutorial_callout.find_child("TutorialPanel", true, false) as Control
    _expect(callout_panel != null and callout_panel.position.y + callout_panel.size.y <= 206.0, "top callout clears the opening-card row")
    var focus_style := focus_ring.get_theme_stylebox("panel") as StyleBoxFlat if focus_ring != null else null
    _expect(
        focus_style != null
        and is_zero_approx(focus_style.bg_color.a)
        and is_zero_approx(focus_style.shadow_color.a)
        and focus_style.shadow_size == 0,
        "static focus outline leaves the highlighted control fully clear and bright"
    )
    var tutorial_pointer := game.tutorial_callout.find_child("TutorialPointer", true, false) as Control
    var initial_ring_modulate := focus_ring.modulate if focus_ring != null else Color.TRANSPARENT
    var initial_pointer_position := tutorial_pointer.position if tutorial_pointer != null else Vector2.ZERO
    await create_timer(0.3).timeout
    _expect(
        focus_ring != null and focus_ring.modulate == initial_ring_modulate
        and tutorial_pointer != null and tutorial_pointer.position == initial_pointer_position,
        "tutorial focus outline and pointer remain static"
    )

    var precise_index := _find_hand_card(game, "precise_chop")
    _expect(precise_index >= 0, "Precise Chop remains in the guaranteed tutorial hand")
    if precise_index >= 0:
        var precise_uid := int(game.player_hand[precise_index].uid)
        var precise_card := game.card_nodes_by_uid.get(precise_uid) as Control
        var precise_target: Rect2 = game.visual_hand_positions.get(precise_uid, Rect2())
        _expect(precise_card != null and precise_card.position.distance_to(precise_target.position) < 0.1, "tutorial spotlight stays aligned with the settled Precise Chop card")
        _expect(precise_card != null and focus_ring != null, "opening tutorial resolves the live Precise Chop card and focus ring")
        if precise_card != null and focus_ring != null:
            var live_rect: Rect2 = game._tutorial_control_rect(precise_card).grow(9.0)
            _expect(
                focus_ring.position.distance_to(live_rect.position) < 0.1 and focus_ring.size.distance_to(live_rect.size) < 1.1,
                "opening focus ring follows the live Precise Chop bounds (%s / %s)" % [Rect2(focus_ring.position, focus_ring.size), live_rect]
            )
        game._on_hand_card_pressed(precise_index)
    _expect(_step_id(game) == "target_enemy", "selecting Precise Chop advances to enemy targeting")
    _expect(String(game.pending_action.get("effect", "")) == "target_enemy_damage", "tutorial uses the authoritative targeting state")
    await process_frame
    var targeting_source := game.card_nodes_by_uid.get(int(game.player_hand[int(game.pending_action.hand_index)].uid)) as Control
    var targeting_source_rect: Rect2 = game._tutorial_control_rect(targeting_source) if targeting_source != null else Rect2()
    var targeting_focus_rect: Rect2 = game._tutorial_focus_rect("first_enemy")
    callout_panel = game.tutorial_callout.find_child("TutorialPanel", true, false) as Control
    var target_callout_rect := Rect2(callout_panel.position, callout_panel.size) if callout_panel != null else Rect2()
    var tutorial_bounds := Rect2(Vector2.ZERO, game.tutorial_callout.size)
    var visible_source_spotlight := targeting_source_rect.grow(9.0).intersection(tutorial_bounds)
    var visible_focus_spotlight := targeting_focus_rect.grow(9.0).intersection(tutorial_bounds)
    _expect(
        game.tutorial_callout.clear_spotlight_rect.encloses(visible_source_spotlight)
        and game.tutorial_callout.clear_spotlight_rect.encloses(visible_focus_spotlight),
        "enemy-target lesson keeps both Precise Chop and Pickle Imp inside the clear spotlight corridor (%s / %s / %s)" % [
            game.tutorial_callout.clear_spotlight_rect,
            visible_source_spotlight,
            visible_focus_spotlight,
        ]
    )
    _expect(
        callout_panel != null and not target_callout_rect.intersects(game.tutorial_callout.clear_spotlight_rect),
        "enemy-target callout stays beside the card-to-target corridor"
    )
    _expect(game.target_line.active and game.target_line.visible, "Precise Chop targeting arrow remains visible during the enemy-target lesson")
    _expect(
        not game.target_line.z_as_relative
        and game.target_line.z_index == game.target_line.TARGETING_Z_INDEX
        and game.target_line.z_index > 120,
        "targeting line and arrowhead use a fixed z-index above every card elevation"
    )
    for card_node: Control in game.card_nodes_by_uid.values():
        _expect(game.target_line.z_index > card_node.z_index, "targeting line renders above hand card %s" % card_node.name)
    var tutorial_enemy := game.unit_nodes_by_uid.get(int(game.enemy_board[0].uid)) as Control
    var initial_enemy_modulate := tutorial_enemy.modulate if tutorial_enemy != null else Color.TRANSPARENT
    await create_timer(0.25).timeout
    _expect(
        tutorial_enemy != null and tutorial_enemy.modulate == initial_enemy_modulate,
        "tutorial target content does not inherit the normal legal-target pulse"
    )

    game._on_enemy_unit_pressed(0)
    _expect(_step_id(game) == "end_turn", "selecting the opening enemy advances directly to End Turn")
    _expect(game.precise_kills == 1 and int(game.pantry.herb) == 1, "the tutorial action performs a real Precise Cut and harvest")
    var tutorial_end_turn := game.screen_layer.find_child("EndTurnButton", true, false) as Control
    var initial_end_turn_modulate := tutorial_end_turn.self_modulate if tutorial_end_turn != null else Color.TRANSPARENT
    await create_timer(0.3).timeout
    _expect(
        tutorial_end_turn != null and tutorial_end_turn.self_modulate == initial_end_turn_modulate,
        "tutorial End Turn callout remains static"
    )

    game.debug_fast = true
    await game.end_player_turn()
    _expect(game.turn_number == 2 and game.is_player_turn, "the enemy turn completes before the final lesson")
    _expect(_step_id(game) == "complete", "the next player turn reveals the completion callout")
    _expect(game.tutorial_callout.visible, "completion callout is visible after the hidden wait state")
    game._on_tutorial_next_requested()
    _expect(not game.tutorial_active and not game.tutorial_callout.visible, "finishing the tutorial restores the unobstructed battle")

    game.debug_fast = false
    game.start_new_run(260903)
    await _wait_for_opening_hand(game)
    _expect(game.tutorial_active and _step_id(game) == "play_precise_chop", "a subsequent brand-new run restarts the tutorial")
    game.motion_mode = "minimal"
    game._render_battle()
    focus_ring = game.tutorial_callout.find_child("TutorialFocusRing", true, false) as Control
    _expect(focus_ring != null and focus_ring.modulate == Color.WHITE, "tutorial focus treatment stays fully visible in Minimal motion")
    var escape := InputEventKey.new()
    escape.keycode = KEY_ESCAPE
    escape.pressed = true
    game._unhandled_input(escape)
    _expect(not game.tutorial_active and not game.tutorial_callout.visible, "Escape skips the tutorial immediately")
    _expect(not game.pause_open, "tutorial Escape is consumed before the run pause menu")
    _expect(game.screen_name == "battle" and game.is_player_turn and not game.input_locked, "skipping preserves the active opening turn")

    var passed := failures.is_empty()
    game.free()
    await create_timer(0.15).timeout
    await process_frame
    await process_frame
    if passed:
        print("[TUTORIAL_PASS] streamlined live-action tutorial, exact harvest, wait state, completion, and skip validated")
        quit(0)
    else:
        push_error("[TUTORIAL_FAIL] %d assertions failed" % failures.size())
        quit(1)
