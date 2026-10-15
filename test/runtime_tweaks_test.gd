extends SceneTree

const TWEAKS := preload("res://scripts/runtime_tweak_controls.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error("[TWEAK_FAIL] " + message)


func _run() -> void:
    # Do not depend on the machine locale (first-launch detection follows the OS/browser language).
    load("res://scripts/localization.gd").set_locale("en", false)
    var controls := TWEAKS.new()
    root.add_child(controls)
    await process_frame

    _expect(controls.descriptor_count() == 61, "catalog exposes all 61 active controls")
    _expect(controls.get_int(&"player.starting_health") == 28, "rebalanced starting Health is the default")
    _expect(controls.get_int(&"gameplay.kitchen_heal") == 2, "rebalanced Kitchen Break healing is the default")
    _expect(controls.category_names() == [&"UI", &"GAMEPLAY", &"AUDIO", &"PLAYER", &"ENEMIES", &"ENVIRONMENT"], "catalog uses the six requested categories")
    var packed_scene := load("res://scenes/card_game.tscn") as PackedScene
    _expect(packed_scene != null, "card game scene loads with tweak controls")
    if packed_scene != null:
        var game := packed_scene.instantiate()
        root.add_child(game)
        await process_frame
        game.tweaks.set_value(&"audio.muted", true, false)
        game.tweaks.set_value(&"player.starting_health", 44, false)
        game.tweaks.set_value(&"enemy.hero_health_multiplier", 2.0, false)
        game.tweaks.set_value(&"enemy.starting_units", 2, false)
        game.tweaks.set_value(&"player.hero_power_cost", 1, false)
        game.tweaks.set_value(&"player.hero_power_armor", 5, false)
        game.tweaks.set_value(&"environment.particle_count", 0.5, false)
        game.debug_fast = true
        game.start_new_run(1337)
        await process_frame
        _expect(game.player_max_health == 44 and game.player_health == 44, "next-run player Health control reaches gameplay")
        game.tweaks.apply_preview_patch({"player.starting_health": 50})
        _expect(game.tweaks.active_value(&"player.starting_health") == 44 and game.player_max_health == 44, "Next-run Apply does not report unused health as active")
        _expect(game.tweaks.get_value(&"player.starting_health") == 50, "Next-run request is retained")
        _expect(game.enemy_max_health == 40, "next-battle enemy Health multiplier reaches gameplay")
        var active_slots: int = game._tweak_int(&"gameplay.max_board_slots", 4)
        var active_threshold: float = game._tweak_float(&"enemy.enrage_threshold", 0.5)
        game.tweaks.set_value(&"gameplay.max_board_slots", 6, false)
        game.tweaks.set_value(&"enemy.enrage_threshold", 0.8, false)
        _expect(game._tweak_int(&"gameplay.max_board_slots", 4) == active_slots, "next-battle board size remains pending during this battle")
        _expect(is_equal_approx(game._tweak_float(&"enemy.enrage_threshold", 0.5), active_threshold), "next-battle enrage threshold remains pending")
        _expect(not game.run_ranked_eligible, "gameplay edits taint the active run")
        game.tweaks.reset_parameter(&"gameplay.max_board_slots")
        _expect(not game.run_ranked_eligible, "reset cannot erase run taint")
        _expect(game.enemy_board.size() == 2, "starting-enemy count reaches encounter setup")
        _expect(is_equal_approx(game.juice.particle_count_scale, 0.5), "environment controls reach the presentation director")
        await process_frame
        var pantry_panel := game.screen_layer.get_node_or_null("BattlePantryPanel") as Control
        _expect(pantry_panel != null, "battle pantry panel is identifiable for layout checks")
        if pantry_panel != null:
            var pantry_rect := Rect2(pantry_panel.position, pantry_panel.size)
            var action_panel := game.screen_layer.get_node_or_null("BattleActionPanel") as Control
            _expect(pantry_rect.position.x <= 18.0, "battle pantry sits on the far-left HUD rail")
            _expect(
                action_panel == null and pantry_rect.position.y >= game._target_battle_zone(&"history_rail").end.y + 8.0,
                "battle pantry is separated below history after the legacy action panel is removed"
            )
        var deck_display := game.screen_layer.get_node_or_null("PlayerDeckDisplay") as Control
        _expect(deck_display != null, "player deck display is identifiable for layout checks")
        if deck_display != null:
            var deck_rect: Rect2 = deck_display.get_meta("deck_stack_rect", Rect2())
            _expect(game._target_battle_zone(&"safe_canvas").encloses(deck_rect), "player deck stays on-canvas")
        game.player_mana = 2
        game.use_hero_power()
        _expect(game.player_mana == 1 and game.player_armor == 5, "Chef Power controls reach live gameplay")
        game.tweaks.apply_preview_patch({"player.hero_power_armor": 7})
        game.use_hero_power()
        _expect(game.tweaks.active_value(&"player.hero_power_armor") == 5, "Already-used hero power does not consume the next action setting")
        game.hero_power_used = false
        game.player_mana = 0
        game.use_hero_power()
        _expect(game.tweaks.active_value(&"player.hero_power_armor") == 5, "Insufficient mana does not consume the next action setting")
        game.tweaks.apply_preview_patch({"player.outgoing_damage_multiplier": 2.0})
        game._player_damage_amount(3)
        _expect(game.tweaks.active_value(&"player.outgoing_damage_multiplier") == 1.0, "Damage prediction does not consume next-attack tuning")
        game._damage_enemy_hero(3)
        _expect(game.tweaks.active_value(&"player.outgoing_damage_multiplier") == 2.0, "Actual damage consumes next-attack tuning")
        game.tweaks.reset_all()
        game.queue_free()

    controls.queue_free()
    await create_timer(0.15).timeout
    await process_frame
    if failures.is_empty():
        print("[TWEAK_PASS] 61 controls and representative end-to-end consumers validated")
        quit(0)
    else:
        push_error("[TWEAK_FAIL] %d assertions failed" % failures.size())
        quit(1)
