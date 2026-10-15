extends SceneTree

const PROFILES := preload("res://scripts/card_battle_juice_profiles.gd")
const CARD_CRACK_OVERLAY := preload("res://scripts/card_crack_overlay.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error("[CARD_BATTLE_JUICE_FAIL] " + message)


func _find_button_with_prefix(root_node: Node, prefix: String) -> Button:
    if root_node is Button and (root_node as Button).text.begins_with(prefix):
        return root_node as Button
    for child in root_node.get_children():
        var match := _find_button_with_prefix(child, prefix)
        if match != null:
            return match
    return null


func _wait_for_opening_hand(game: Node, timeout_seconds := 6.0) -> void:
    var elapsed := 0.0
    while game.opening_hand_in_progress and elapsed < timeout_seconds:
        await create_timer(0.05).timeout
        elapsed += 0.05


func _run() -> void:
    _expect(PROFILES.tier("signature").blocking <= 0.25, "signature blocking budget is bounded")
    _expect(PROFILES.particle_scale("minimal", 1.0) == 0.0, "minimal motion removes flavor particles")
    _expect(PROFILES.KITS.size() >= 7, "mechanic families have distinct presentation kits")

    var light_cracks: Control = CARD_CRACK_OVERLAY.new()
    light_cracks.configure(Vector2(158, 142), 1, 6, 101)
    var severe_cracks: Control = CARD_CRACK_OVERLAY.new()
    severe_cracks.configure(Vector2(158, 142), 8, 6, 101)
    _expect(int(severe_cracks.get_meta("primary_branch_count")) > int(light_cracks.get_meta("primary_branch_count")), "excess damage adds primary crack branches")
    _expect(int(severe_cracks.get_meta("crack_path_count")) > int(light_cracks.get_meta("crack_path_count")), "excess damage adds forked crack paths")
    _expect(float(severe_cracks.get_meta("crack_reach")) > float(light_cracks.get_meta("crack_reach")), "excess damage extends cracks farther across the card")
    light_cracks.free()
    severe_cracks.free()

    var database = load("res://scripts/card_database.gd")
    for art_id in [
        "juice_card_back", "juice_mana_burner", "juice_armor_pan",
        "juice_pantry_jar", "juice_encounter_seal", "juice_selection_knife",
        "juice_cooking_cauldron",
        "mise_the_thousand_handed", "the_sovereign_cleaver", "bell_of_the_last_service",
    ]:
        _expect(database.art(art_id) != null, "%s is imported and registered" % art_id)

    var packed_scene := load("res://scenes/card_game.tscn") as PackedScene
    _expect(packed_scene != null, "game scene loads with the complete presentation stack")
    if packed_scene == null:
        quit(1)
        return
    var game := packed_scene.instantiate()
    root.add_child(game)
    await process_frame
    game.sound_muted = true
    game.start_new_run(4242)
    _expect(game.player_hand.is_empty(), "first battle initially renders an empty hand")
    _expect(game.opening_hand_in_progress and game.input_locked, "opening deal locks actions until all cards settle")
    _expect(not game.tutorial_active, "tutorial presentation waits for the opening deal")
    await _wait_for_opening_hand(game)

    var preview_cracks: Control = game.juice.card_cracks(Rect2(560, 270, 158, 142), 5, 6, null, game.CRIMSON, 501)
    _expect(preview_cracks != null and preview_cracks.get_node_or_null("CrackGeometry") != null, "juice director renders procedural cracks over a damaged card snapshot")

    var overkill_probe := {
        "uid": 9001, "health": 2, "max_health": 6, "art": "pickle_imp",
        "ingredient": "", "name_key": "card.pickle_imp.name",
    }
    game.enemy_board.append(overkill_probe)
    game.visual_unit_rects[9001] = Rect2(420, 162, 158, 142)
    game.juice_events.clear()
    game._damage_unit(overkill_probe, 7, true)
    var damage_event: Dictionary = {}
    for queued_event in game.juice_events:
        if String(queued_event.get("kind", "")) == "unit_damage":
            damage_event = queued_event
            break
    _expect(int(damage_event.get("excess_damage", -1)) == 5, "unit damage forwards the exact overkill amount to crack generation")
    _expect(damage_event.get("rect", Rect2()) == Rect2(420, 162, 158, 142), "cracks retain the defeated card's last board rectangle")
    game.juice_events.clear()
    game.enemy_board.erase(overkill_probe)
    game.visual_unit_rects.erase(9001)

    _expect(not game.opening_hand_in_progress, "opening deal finishes before normal battle interaction")
    _expect(game.is_player_turn and not game.input_locked, "first battle begins with an active player turn after the deal")
    _expect(game.player_mana == 1 and game.player_max_mana == 1, "first battle grants opening-turn Mana immediately")
    _expect(game.player_hand.size() == 5, "first battle deals the full opening hand")
    _expect(game.screen_layer.get_node_or_null("EndTurnButton") != null, "first battle renders the normal combat controls immediately")
    _expect(game.screen_layer.get_node_or_null("CenterEndTurnButton") == null, "board-center End Turn stays hidden while a player action remains")

    for history_index in range(8):
        game._record_history("TEST %d" % history_index, "ACTION", "BOARD", history_index + 1, game.TEAL)
    game._render_battle()
    _expect(game.history_events.size() > int(PROFILES.LIMITS.history), "Service History retains the full encounter instead of the former five-row preview")
    var history_button: Button = game.screen_layer.get_node_or_null("ServiceHistoryButton") as Button
    _expect(history_button != null, "battle HUD collapses Service History into a button")
    if history_button != null:
        history_button.pressed.emit()
    await process_frame
    var history_dialog: Node = game.screen_layer.get_node_or_null("ServiceHistoryDialog")
    var history_scroll: Node = history_dialog.get_node_or_null("ServiceHistoryScroll") if history_dialog != null else null
    var history_rows: Node = history_scroll.get_node_or_null("ServiceHistoryRows") if history_scroll != null else null
    _expect(game.service_history_open and history_dialog != null, "Service History button opens a modal dialog")
    _expect(history_scroll is ScrollContainer, "Service History dialog provides a scrollable list")
    _expect(history_rows != null and history_rows.get_child_count() == game.history_events.size(), "Service History dialog renders every retained action")
    _expect(not game._can_take_player_action(), "Service History dialog blocks battle actions while open")
    var history_escape := InputEventKey.new()
    history_escape.keycode = KEY_ESCAPE
    history_escape.pressed = true
    game._unhandled_input(history_escape)
    _expect(not game.service_history_open and game.screen_layer.get_node_or_null("ServiceHistoryDialog") == null, "Escape closes Service History without pausing the battle")

    var deck_display: Node = game.screen_layer.get_node_or_null("PlayerDeckDisplay")
    _expect(deck_display != null, "battle renders a dedicated face-down player deck")
    _expect(deck_display != null and int(deck_display.get_meta("deck_count", -1)) == game.player_deck.size(), "visible deck count matches the authoritative remaining deck")
    var deck_size_before_draw: int = game.player_deck.size()
    game._draw_player_card()
    var drawn_uid := int(game.player_hand.back().uid)
    game._render_battle()
    var pending_card: Button = game.card_nodes_by_uid.get(drawn_uid)
    var pending_card_back: Node = pending_card.get_node_or_null("DrawCardBack") if pending_card != null else null
    _expect(game.pending_draw_reveals.has(drawn_uid), "newly drawn card waits face-down for its reveal")
    _expect(pending_card != null and not pending_card.visible and pending_card_back != null, "hand card remains concealed while the deck flight begins")
    _expect(not (pending_card_back is Panel), "pending card back does not create the former dark, bordered container")
    deck_display = game.screen_layer.get_node_or_null("PlayerDeckDisplay")
    _expect(deck_display != null and int(deck_display.get_meta("deck_count", -1)) == deck_size_before_draw - 1, "drawing removes the visible top card from the deck count")
    var draw_visual: Control = null
    for draw_wait in range(10):
        await create_timer(0.04).timeout
        draw_visual = game.juice.get_node_or_null("DrawnCardReveal") as Control
        if draw_visual != null:
            break
    var flying_card_back: Node = draw_visual.get_node_or_null("DrawCardBack") if draw_visual != null else null
    var flying_card_face: Control = draw_visual.get_node_or_null("DrawCardFace") as Control if draw_visual != null else null
    _expect(draw_visual != null and not (draw_visual is Button), "concealed draw uses a neutral wrapper without a card container")
    _expect(flying_card_back is TextureRect and not (flying_card_back is Panel), "concealed draw displays only the card-back texture")
    _expect(flying_card_face != null and not flying_card_face.visible, "dark card frame and face details stay hidden until the flip")
    await create_timer(1.0).timeout
    var revealed_card: Button = game.card_nodes_by_uid.get(drawn_uid)
    _expect(not game.pending_draw_reveals.has(drawn_uid), "draw animation completes the card reveal")
    _expect(revealed_card != null and revealed_card.visible and revealed_card.get_node_or_null("DrawCardBack") == null, "revealed card settles face-up and interactive in hand")

    game.player_mana = 0
    var card_uid := int(game.player_hand[0].uid)
    _expect(game._card_playability_reason(card_uid) != "RELEASE TO SERVE", "unaffordable cards remain inspectable with a reason")
    game.player_mana = 8
    _expect(game._card_playability_reason(card_uid) == "RELEASE TO SERVE", "valid drag and click paths share playability rules")
    game.hero_power_used = true
    _expect(game._has_remaining_player_action(), "a playable card keeps End Turn from being recommended")

    game.player_mana = 0
    game.pending_action = {"kind": "spell"}
    _expect(game._has_remaining_player_action(), "active targeting keeps End Turn from being recommended")
    game.pending_action.clear()
    var ready_ally: Dictionary = game._summon_unit("coal_squire", true, false)
    ready_ally.ready = true
    _expect(game._has_remaining_player_action(), "a ready ally keeps End Turn from being recommended")
    ready_ally.ready = false

    for unit in game.player_board:
        unit.ready = false
    game.pending_action.clear()
    game.tutorial_active = false
    game.motion_mode = PROFILES.MOTION_FULL
    game._render_battle()
    var end_turn_button := _find_button_with_prefix(game.screen_layer, "END TURN")
    var end_turn_style := end_turn_button.get_theme_stylebox("normal") as StyleBoxFlat if end_turn_button != null else null
    _expect(end_turn_button != null and bool(end_turn_button.get_meta("end_turn_recommended", false)), "End Turn becomes recommended when no player action remains")
    _expect(end_turn_style != null and end_turn_style.shadow_size > 0 and end_turn_style.border_color == game.GOLD, "recommended End Turn has a golden glow")
    _expect(game.screen_layer.get_node_or_null("CenterEndTurnButton") == null, "combat corridor remains open when End Turn is recommended")
    _expect(end_turn_button != null and bool(end_turn_button.get_meta("end_turn_pulsing", false)), "single End Turn control receives the golden pulse animation")
    var end_turn_initial_tint := end_turn_button.self_modulate if end_turn_button != null else Color.TRANSPARENT
    await create_timer(0.2).timeout
    _expect(end_turn_button != null and end_turn_button.self_modulate != end_turn_initial_tint, "single End Turn visibly animates its golden pulse")
    game.hero_power_used = false
    game.player_mana = game._tweak_int(&"player.hero_power_cost", 2)
    game._render_battle()
    end_turn_button = _find_button_with_prefix(game.screen_layer, "END TURN")
    _expect(end_turn_button != null and not bool(end_turn_button.get_meta("end_turn_recommended", false)), "End Turn stops glowing when the Chef Power is available")
    _expect(game.screen_layer.get_node_or_null("CenterEndTurnButton") == null, "board End Turn disappears when a player action becomes available")

    game.debug_fast = true
    game.debug_force_battle_victory()
    await process_frame
    _expect(game.screen_name == "kitchen", "victory enters the enhanced Kitchen Break")
    _expect(game.reward_options == database.LEGENDARY_REWARDS, "first victory offers the complete legendary trio")
    var reward_id: String = game.reward_options[0]
    _expect(not bool(game.reward_revealed.get(reward_id, true)), "rewards begin sealed")
    game._reveal_reward(reward_id)
    _expect(bool(game.reward_revealed.get(reward_id, false)), "reward reveal flips the sealed card")
    game._select_reward(reward_id)
    _expect(game.reward_done, "revealed rewards use the existing authoritative selection path")
    _expect(game.claimed_legendary_ids == [reward_id], "selected legendary is excluded from later reward pools")

    game.deck_overlay_open = true
    game._render_kitchen()
    await process_frame
    var deck_overlay: Node = game.screen_layer.get_node_or_null("DeckOverlay")
    var deck_dialog: Panel = deck_overlay.get_node_or_null("DeckDialogPanel") as Panel if deck_overlay != null else null
    var deck_dialog_style := deck_dialog.get_theme_stylebox("panel") as StyleBoxFlat if deck_dialog != null else null
    var deck_card_scroll: Node = deck_overlay.get_node_or_null("DeckCardScroll") if deck_overlay != null else null
    var deck_card_inset: Node = deck_card_scroll.get_node_or_null("DeckCardInset") if deck_card_scroll != null else null
    var deck_card_row: Node = deck_card_inset.get_node_or_null("DeckCardRow") if deck_card_inset != null else null
    var deck_summary_scroll: Node = deck_overlay.get_node_or_null("DeckSummaryScroll") if deck_overlay != null else null
    _expect(deck_overlay != null, "View Deck opens a dedicated modal overlay")
    _expect(deck_dialog_style != null and is_equal_approx(deck_dialog_style.bg_color.a, 1.0), "deck dialog background is completely opaque")
    _expect(deck_card_scroll is ScrollContainer and (deck_card_scroll as ScrollContainer).horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "deck dialog provides a horizontally scrollable card strip")
    _expect(deck_card_row != null and deck_card_row.get_child_count() == game.run_deck.size(), "deck card strip renders every current runtime card")
    _expect(deck_card_row != null and deck_card_row.get_child_count() > 0 and deck_card_row.get_child(0).get_meta("card_id", "") != "", "deck strip cards support the standard interactive preview metadata")
    var deck_scroll_bar := (deck_card_scroll as ScrollContainer).get_h_scroll_bar() if deck_card_scroll is ScrollContainer else null
    _expect(deck_scroll_bar != null and deck_scroll_bar.max_value > deck_scroll_bar.page, "current deck cards overflow into a genuinely scrollable horizontal range")
    var first_deck_card := deck_card_row.get_child(0) as Button if deck_card_row != null and deck_card_row.get_child_count() > 0 else null
    _expect(first_deck_card != null and first_deck_card.tooltip_text.is_empty(), "card inspection does not spawn a competing native tooltip")
    if first_deck_card != null:
        first_deck_card.mouse_entered.emit()
    _expect(first_deck_card != null and game.card_preview != null, "hovering a deck card opens the standard enlarged card preview")
    if first_deck_card != null:
        first_deck_card.mouse_exited.emit()
    _expect(deck_summary_scroll is ScrollContainer, "deck dialog retains the text-based deck summary below the cards")
    var deck_escape := InputEventKey.new()
    deck_escape.keycode = KEY_ESCAPE
    deck_escape.pressed = true
    game._unhandled_input(deck_escape)
    _expect(not game.deck_overlay_open and game.screen_layer.get_node_or_null("DeckOverlay") == null, "Escape closes the deck dialog")

    game.juice.configure_presentation("minimal", 0.0, 0.0, 1.0, 2.0, true, true)
    var particles_before: int = int(game.juice.active_particles)
    game.juice.burst(Vector2(100, 100), Color.WHITE, 30, "spark", 50.0)
    _expect(game.juice.active_particles == particles_before, "minimal mode enforces zero-particle flavor budget")
    game.juice.caption(Vector2(100, 100), "RESULT", Color.WHITE)
    await create_timer(0.5).timeout

    var passed := failures.is_empty()
    game.free()
    await create_timer(0.15).timeout
    await process_frame
    await process_frame
    if passed:
        print("[CARD_BATTLE_JUICE_PASS] profiles, GPT Image 2 assets, immediate battle start, drag parity, history, reward reveals, and minimal mode validated")
        quit(0)
    else:
        push_error("[CARD_BATTLE_JUICE_FAIL] %d assertions failed" % failures.size())
        quit(1)
