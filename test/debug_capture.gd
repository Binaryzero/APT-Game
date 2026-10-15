extends Node

var output_dir := ""


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    output_dir = OS.get_environment("GAME_CAPTURE_DIR")
    if output_dir.is_empty():
        output_dir = ProjectSettings.globalize_path("user://cardgame-captures")
    DirAccess.make_dir_recursive_absolute(output_dir)
    call_deferred("_capture_states")


func _capture(name: String) -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    RenderingServer.force_draw()
    await get_tree().process_frame
    var image := get_viewport().get_texture().get_image()
    var path := output_dir.path_join(name + ".png")
    var error := image.save_png(path)
    if error != OK:
        push_error("[DEBUG_CAPTURE_FAIL] could not save " + path)
        get_tree().quit(1)
    print("[DEBUG_CAPTURE] " + path)


func _settle(seconds: float) -> void:
    await get_tree().create_timer(seconds).timeout


func _wait_for_opening_hand(game: Node, timeout_seconds := 6.0) -> void:
    var elapsed := 0.0
    while game.opening_hand_in_progress and elapsed < timeout_seconds:
        await get_tree().create_timer(0.05).timeout
        elapsed += 0.05


func _hud_readability_history(game: Node) -> Array[Dictionary]:
    return [
        {"event": game.t("history.event.draw"), "value": 1, "color": Color("#F7E9C8")},
        {"event": game.t("history.event.death"), "value": -1, "color": Color("#D95757")},
        {"event": game.t("history.event.precise_cut"), "value": -2, "color": Color("#55C6A9")},
        {"event": game.t("history.event.hero_damage"), "value": 12, "color": Color("#D95757"), "user_took_damage": true},
    ]


func _capture_states() -> void:
    var packed_scene := load("res://scenes/card_game.tscn") as PackedScene
    var game := packed_scene.instantiate()
    add_child(game)
    game.debug_fast = true
    await _capture("cardgame-title")
    game.leaderboard_open = true
    game._render_title()
    await _capture("cardgame-leaderboard")
    game.leaderboard_open = false
    game._render_title()
    game.settings_open = true
    game._render_title()
    await _capture("cardgame-settings")
    game.settings_open = false
    game._render_title()

    game.debug_fast = false
    game.start_new_run(1337)
    await _wait_for_opening_hand(game)
    await _capture("cardgame-tutorial-card")
    var tutorial_precise_index := -1
    for index in range(game.player_hand.size()):
        if game.player_hand[index].id == "precise_chop":
            tutorial_precise_index = index
            break
    if tutorial_precise_index >= 0:
        game._on_hand_card_pressed(tutorial_precise_index)
        await _capture("cardgame-tutorial-target")
        game._on_enemy_unit_pressed(0)
    await _capture("cardgame-tutorial-end-turn")
    game.debug_fast = true
    await game.end_player_turn()
    await _capture("cardgame-tutorial-complete")
    game._on_tutorial_next_requested()

    game.debug_fast = false
    game.start_new_run(1337)
    game._skip_tutorial()
    game.debug_fast = true
    await _settle(0.9)
    await _capture("cardgame-battle")
    if not game.player_hand.is_empty():
        var focus_card: Control = game.card_nodes_by_uid.get(int(game.player_hand[0].uid))
        if focus_card != null:
            focus_card.grab_focus()
            await _settle(0.18)
            await _capture("cardgame-keyboard-focus")
            focus_card.release_focus()
            game._hide_card_preview()
    game.tweaks.set_value(&"ui.font_scale", 0.8, false)
    game._render_battle()
    await _capture("cardgame-font-min")
    var prior_history: Array[Dictionary] = game.history_events.duplicate(true)
    var prior_banner_text: String = game.banner_text
    game.tweaks.set_value(&"ui.font_scale", 1.25, false)
    game.history_events = _hud_readability_history(game)
    game.banner_text = game.t("battle.your_turn_mana", {"mana": game.player_mana})
    game._render_battle()
    await _capture("cardgame-font-max")
    game.L10N.set_locale("zh-CN", false)
    game.history_events = _hud_readability_history(game)
    game.banner_text = game.t("battle.your_turn_mana", {"mana": game.player_mana})
    game._render_battle()
    await _capture("cardgame-zh-cn")
    game.L10N.set_locale("en", false)
    game.tweaks.set_value(&"ui.font_scale", 1.0, false)
    game.history_events = prior_history
    game.banner_text = prior_banner_text
    game.motion_mode = game.JUICE_PROFILES.MOTION_REDUCED
    game.reduce_motion = true
    game._configure_juice()
    game._render_battle()
    await _capture("cardgame-motion-reduced")
    game.motion_mode = game.JUICE_PROFILES.MOTION_MINIMAL
    game._configure_juice()
    game._render_battle()
    await _capture("cardgame-motion-minimal")
    game.motion_mode = game.JUICE_PROFILES.MOTION_FULL
    game.reduce_motion = false
    game._configure_juice()
    game._render_battle()
    var drag_uid := -1
    for runtime_card in game.player_hand:
        if String(game.DB.card(runtime_card.id).get("type", "")) == "unit":
            drag_uid = int(runtime_card.uid)
            break
    if drag_uid >= 0:
        game.player_mana = 10
        game._render_battle()
        var drag_control: Control = game.card_nodes_by_uid.get(drag_uid)
        if drag_control != null:
            game.drag_candidate_uid = drag_uid
            game.dragged_card_uid = drag_uid
            game.drag_active = true
            game.drag_pointer_offset = drag_control.size * 0.5
            game.drag_last_pointer = game._play_region_screen_rect().get_center()
            game._update_card_drag(game._play_region_screen_rect().get_center())
            await _capture("cardgame-drag-region")
            game._reset_card_drag()
            game._render_battle()
    game._open_pause_menu()
    await _capture("cardgame-pause")
    game._open_pause_settings()
    await _capture("cardgame-pause-settings")
    game._on_paused_escape_pressed()
    game._resume_game()
    game._open_service_history()
    await _capture("cardgame-service-history")
    game._close_service_history()

    var precise_index := -1
    for index in range(game.player_hand.size()):
        if game.player_hand[index].id == "precise_chop":
            precise_index = index
            break
    if precise_index >= 0:
        game.enemy_board[0].health = 2
        game._on_hand_card_pressed(precise_index)
        await _capture("cardgame-targeting")
        game._on_enemy_unit_pressed(0)
        await _settle(0.9)
        await _capture("cardgame-precise-cut")

    var overkill_unit: Dictionary = game._summon_unit("pickle_imp", false, false)
    overkill_unit.health = 1
    game._damage_unit(overkill_unit, 2, true)
    game._remove_dead_units()
    game._render_battle()
    await _settle(0.9)
    await _capture("cardgame-overkill")

    game.suppress_juice = true
    game.juice_events.clear()
    game.enemy_board.clear()
    game.player_board.clear()
    for unit_index in range(6):
        var enemy_id := "pickle_imp" if unit_index % 2 == 0 else "pan_paladin"
        var player_id := "coal_squire" if unit_index % 2 == 0 else "pan_paladin"
        game._summon_unit(enemy_id, false, false)
        var friendly_unit: Dictionary = game._summon_unit(player_id, true, false)
        friendly_unit.ready = unit_index % 2 == 0
    game.player_hand.clear()
    var capture_cards := ["precise_chop", "coal_squire", "pan_paladin", "mise_en_place", "kitchen_guard"]
    for hand_index in range(10):
        game.player_hand.append(game._make_runtime_card(capture_cards[hand_index % capture_cards.size()]))
    game._render_battle()
    await _capture("cardgame-six-slots-ten-hand")
    var hover_card: Control = game.card_nodes_by_uid.get(int(game.player_hand[5].uid))
    if hover_card != null:
        game._on_juice_hover(hover_card, true)
        await _settle(0.18)
        await _capture("cardgame-ten-hand-hover")
        game._on_juice_hover(hover_card, false)

    game.debug_force_battle_victory()
    game.pantry.fungus = 1
    game.pantry.herb = 1
    game.pantry.meat = 1
    game.pantry.ember = 1
    game._render_kitchen()
    await _settle(0.4)
    print("[DEBUG_CAPTURE_STATE] %s · %d controls" % [game.screen_name, game.screen_layer.get_child_count()])
    await _capture("cardgame-kitchen-sealed")
    game._reveal_all_rewards()
    await _capture("cardgame-kitchen-revealed")

    game._select_reward(game.reward_options[0])
    game._continue_from_kitchen()
    await _capture("cardgame-route")

    game._choose_route("mold_monarch")
    game.debug_force_battle_victory()
    await _capture("cardgame-kitchen-second-sealed")
    game._reveal_all_rewards()
    await _capture("cardgame-kitchen-second-revealed")
    game._select_reward(game.reward_options[0])
    game._continue_from_kitchen()
    game.debug_force_run_victory()
    await _capture("cardgame-victory")

    game.start_new_run(2026)
    game.debug_force_defeat()
    await _capture("cardgame-defeat")
    print("[DEBUG_CAPTURE_PASS] tutorial journey, title, leaderboard, settings, battle, pause, targeting, combat, both Kitchen Break reward states, route, victory, and defeat captured")
    get_tree().quit(0)
