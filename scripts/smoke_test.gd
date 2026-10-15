extends SceneTree

const DB := preload("res://scripts/card_database.gd")
const L10N := preload("res://scripts/localization.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error("[SMOKE_FAIL] " + message)


func _find_hand_card(game: Node, card_id: String) -> int:
    for index in range(game.player_hand.size()):
        if game.player_hand[index].id == card_id:
            return index
    return -1


func _find_button_with_prefix(root_node: Node, prefix: String) -> Button:
    if root_node is Button and (root_node as Button).text.begins_with(prefix):
        return root_node as Button
    for child in root_node.get_children():
        var match := _find_button_with_prefix(child, prefix)
        if match != null:
            return match
    return null


func _count_buttons(root_node: Node) -> int:
    var count := 1 if root_node is Button else 0
    for child in root_node.get_children():
        count += _count_buttons(child)
    return count


func _has_label(root_node: Node, text: String) -> bool:
    if root_node is Label and (root_node as Label).text == text:
        return true
    for child in root_node.get_children():
        if _has_label(child, text):
            return true
    return false


func _contains_submission(records: Array[Dictionary], submission_id: String) -> bool:
    for record in records:
        if String(record.get("submission_id", "")) == submission_id:
            return true
    return false


func _has_legendary_rewards(game: Node, expected_count: int, excluded_id := "") -> bool:
    var seen := {}
    for card_id in game.reward_options:
        if seen.has(card_id) or not DB.LEGENDARY_REWARDS.has(card_id) or card_id == excluded_id:
            return false
        if String(DB.card(card_id).get("rarity", "")) != "legendary":
            return false
        seen[card_id] = true
    return game.reward_options.size() == expected_count


func _run() -> void:
    L10N.set_locale("en")
    var packed_scene := load("res://scenes/card_game.tscn") as PackedScene
    _expect(packed_scene != null, "card game scene loads")
    if packed_scene == null:
        quit(1)
        return

    var game := packed_scene.instantiate()
    root.add_child(game)
    await process_frame
    game.debug_fast = true

    _expect(game.screen_name == "title", "game boots to title")
    var start_button := _find_button_with_prefix(game.screen_layer, "START GAME")
    var leaderboard_button := _find_button_with_prefix(game.screen_layer, "LEADERBOARD")
    var settings_button := _find_button_with_prefix(game.screen_layer, "SETTINGS")
    var language_button := game.screen_layer.get_node_or_null("LanguageToggle") as Button
    _expect(start_button != null, "title exposes a centered Start Game button")
    _expect(leaderboard_button != null, "title exposes a Leaderboard footer button")
    _expect(settings_button != null, "title exposes a Settings footer button")
    _expect(language_button != null, "title exposes the language selector")
    var multiplayer_button := game.screen_layer.find_child("TitleMultiplayerButton", true, false) as Button
    if start_button != null and language_button != null:
        for menu_button: Button in [start_button, leaderboard_button, settings_button, multiplayer_button]:
            if menu_button != null:
                _expect(not language_button.get_global_rect().intersects(menu_button.get_global_rect()), "language selector stays clear of %s" % menu_button.name)
    if start_button != null and leaderboard_button != null and settings_button != null and multiplayer_button != null:
        _expect(is_equal_approx(leaderboard_button.position.y, settings_button.position.y) and is_equal_approx(multiplayer_button.position.y, settings_button.position.y), "secondary title actions share one counter-front row")
        _expect(is_equal_approx(leaderboard_button.size.x, settings_button.size.x) and is_equal_approx(leaderboard_button.size.y, settings_button.size.y), "secondary title actions share one button size")
        _expect(start_button.position.y + start_button.size.y < leaderboard_button.position.y and multiplayer_button.position.x + multiplayer_button.size.x < leaderboard_button.position.x and leaderboard_button.position.x + leaderboard_button.size.x < settings_button.position.x, "secondary actions sit below Start Game in reading order")
        _expect(is_equal_approx(start_button.position.x + start_button.size.x * 0.5, 640.0) and is_equal_approx((multiplayer_button.position.x + settings_button.position.x + settings_button.size.x) * 0.5, 640.0), "title menu is centered across the full title screen")
    _expect(not _has_label(game.screen_layer, "SERVICE LEADERS"), "leaderboard content is hidden on the base title screen")
    _expect(_find_button_with_prefix(game.screen_layer, "HOW TO PLAY") == null, "title removes the How To Play action")
    var leaderboard_logic = load("res://scripts/leaderboard_client.gd")
    _expect(leaderboard_logic.normalize_chef_name("  chef!! pan---pal  ") == "CHEF PAN-PAL", "chef names normalize consistently")
    _expect(leaderboard_logic.calculate_score({"victory": true, "battles_cleared": 3, "precise_cuts": 2, "ingredients_ruined": 0, "dishes_cooked": 1, "health_remaining": 20}) == 6900, "leaderboard score formula is deterministic")
    _expect(_find_button_with_prefix(game.screen_layer, "MOTION") == null, "motion preference is hidden on the title screen")
    _expect(_find_button_with_prefix(game.screen_layer, "SOUND") == null, "sound preference is hidden on the title screen")
    game.leaderboard_open = true
    game._render_title()
    _expect(_has_label(game.screen_layer, "SERVICE LEADERS"), "Leaderboard opens in a dialog")
    _expect(_has_label(game.screen_layer, "LOCAL") and _has_label(game.screen_layer, "GLOBAL"), "Leaderboard dialog shows local and global standings")
    _expect(game.chef_name_input != null, "Leaderboard dialog contains chef-name editing")
    var leaderboard_enter_event := InputEventKey.new()
    leaderboard_enter_event.keycode = KEY_ENTER
    leaderboard_enter_event.pressed = true
    game._unhandled_input(leaderboard_enter_event)
    _expect(game.screen_name == "title" and game.leaderboard_open, "Leaderboard dialog blocks the title shortcut from starting a run")
    var leaderboard_escape_event := InputEventKey.new()
    leaderboard_escape_event.keycode = KEY_ESCAPE
    leaderboard_escape_event.pressed = true
    game._unhandled_input(leaderboard_escape_event)
    _expect(not game.leaderboard_open, "Escape closes the Leaderboard dialog")
    game.settings_open = true
    game._render_title()
    _expect(_find_button_with_prefix(game.screen_layer, "MOTION") != null, "Settings contains the motion preference")
    _expect(_find_button_with_prefix(game.screen_layer, "SOUND") != null, "Settings contains the sound preference")
    var enter_event := InputEventKey.new()
    enter_event.keycode = KEY_ENTER
    enter_event.pressed = true
    game._unhandled_input(enter_event)
    _expect(game.screen_name == "title" and game.settings_open, "Settings blocks the title shortcut from starting a run")
    var escape_event := InputEventKey.new()
    escape_event.keycode = KEY_ESCAPE
    escape_event.pressed = true
    game._unhandled_input(escape_event)
    _expect(not game.settings_open, "Escape closes Settings")
    game.start_new_run(1337)
    await process_frame
    _expect(game.screen_name == "battle", "new run enters first battle")
    _expect(game.current_encounter_id == "picklemancer", "first encounter is the Picklemancer")
    _expect(game.player_hand.size() == 5, "opening hand contains five cards")
    _expect(game.player_health == 28 and game.player_max_health == 28, "rebalanced run starts at 28 Health")
    _expect(game.player_mana == 1 and game.player_max_mana == 1, "opening turn starts with one Mana")
    var player_mana_pool := game.screen_layer.get_node_or_null("PlayerManaPool") as Control
    var player_mana_title := game.screen_layer.find_child("PlayerManaPoolTitle", true, false) as Label
    var player_mana_value_plate := game.screen_layer.find_child("PlayerManaValuePlate", true, false) as Panel
    var player_mana_value_style := player_mana_value_plate.get_theme_stylebox("panel") as StyleBoxFlat if player_mana_value_plate != null else null
    var player_mana_value := game.screen_layer.find_child("PlayerManaValue", true, false) as Label
    var player_mana_crystal := game.screen_layer.find_child("PlayerManaCrystal", true, false) as TextureRect
    var player_mana_rack := game.screen_layer.find_child("PlayerManaRackFrame", true, false) as TextureRect
    var enemy_mana_pool := game.screen_layer.get_node_or_null("EnemyManaPool") as Control
    var enemy_mana_rack := game.screen_layer.find_child("EnemyManaRackFrame", true, false) as TextureRect
    var enemy_mana_readout := game.screen_layer.find_child("EnemyManaReadoutPlate", true, false) as Panel
    var enemy_mana_value := game.screen_layer.find_child("EnemyManaValue", true, false) as Label
    var enemy_mana_readout_style := enemy_mana_readout.get_theme_stylebox("panel") as StyleBoxFlat if enemy_mana_readout != null else null
    _expect(
        player_mana_pool != null
        and Rect2(player_mana_pool.position, player_mana_pool.size) == game._target_battle_zone(&"player_mana"),
        "Mana Pool occupies the lower-right owner rail"
    )
    _expect(player_mana_pool != null and not (player_mana_pool is Panel) and enemy_mana_pool != null and not (enemy_mana_pool is Panel), "player and enemy Mana Pools use unstyled layout containers")
    _expect(player_mana_rack != null and enemy_mana_rack != null, "player and enemy Mana Pools preserve their inner rack artwork")
    _expect(player_mana_rack.material == null and enemy_mana_rack.material == null, "clean Mana rack artwork needs no runtime fringe-removal shader")
    _expect(player_mana_title != null and player_mana_title.text == "MANA POOL" and player_mana_title.get_theme_font_size("font_size") >= 14, "Mana Pool has a larger clear heading")
    _expect(player_mana_title != null and player_mana_pool != null and is_equal_approx(player_mana_title.get_global_rect().get_center().x, player_mana_pool.get_global_rect().get_center().x), "Mana Pool heading remains centered over the full rack")
    _expect(player_mana_rack != null and player_mana_rack.position.y == -5.0 and player_mana_crystal != null and player_mana_crystal.position.y == 25.0, "player Mana rack and crystal move upward together")
    _expect(player_mana_value_plate != null and player_mana_value_plate.position == Vector2(54, 26) and Rect2(player_mana_value_plate.position, player_mana_value_plate.size).encloses(Rect2(68, 31, 56, 3)) and player_mana_value_style != null and is_equal_approx(player_mana_value_style.bg_color.a, 1.0), "left-and-up-shifted opaque Mana number plate completely covers the rack artwork's exposed white strip")
    _expect(player_mana_value != null and player_mana_value.get_parent() == player_mana_value_plate and is_equal_approx(player_mana_value.get_global_rect().get_center().x, player_mana_value_plate.get_global_rect().get_center().x), "Mana value moves with its shifted number plate")
    _expect(player_mana_value != null and player_mana_value.text == "1/1" and player_mana_value.get_theme_font_size("font_size") >= 24 and bool(player_mana_value.get_meta("hud_text_fits", false)), "Mana Pool keeps its current and maximum values prominent inside the rack")
    _expect(player_mana_crystal != null and player_mana_crystal.size == Vector2(44, 44), "Mana Pool fits the mana instrument into its generated rack")
    _expect(not bool(player_mana_pool.get_meta("mana_glowing", true)), "Mana Pool rests without a rack glow at one current Mana")
    var enemy_mana_crystal := game.screen_layer.find_child("EnemyManaCrystal", true, false) as TextureRect
    _expect(enemy_mana_crystal != null and enemy_mana_crystal.size == Vector2(34, 34), "enemy mana crystal uses the compact upper-right rack size")
    _expect(enemy_mana_readout != null and enemy_mana_value != null and Rect2(enemy_mana_readout.position, enemy_mana_readout.size) == Rect2(28, 25, 106, 30) and is_equal_approx(enemy_mana_value.get_global_rect().get_center().x, enemy_mana_readout.get_global_rect().get_center().x), "enemy Mana readout wraps its centered text at the refined horizontal position")
    _expect(enemy_mana_readout_style != null and is_equal_approx(enemy_mana_readout_style.bg_color.a, 1.0), "enemy Mana readout fully blocks the rack artwork beneath it")
    _expect(not _has_label(game.screen_layer, "YOUR HAND") and not _has_label(game.screen_layer, "YOUR HAND · 1 MANA"), "hand summary text is removed")
    var mana_cost_badges: Array[Node] = game.screen_layer.find_children("ManaCostBadge", "Control", true, false)
    var every_card_crystal_is_darkened: bool = not mana_cost_badges.is_empty()
    for mana_cost_badge in mana_cost_badges:
        var card_crystal := mana_cost_badge.get_node_or_null("ManaCrystalIcon") as TextureRect
        if card_crystal == null or (
            card_crystal.modulate != game.CARD_MANA_CRYSTAL_TINT
            and card_crystal.modulate != game.CARD_MANA_CRYSTAL_UNAFFORDABLE_TINT
        ):
            every_card_crystal_is_darkened = false
            break
    _expect(every_card_crystal_is_darkened, "every card darkens its mana crystal behind the cost value")
    var saw_affordable_card := false
    var saw_unaffordable_card := false
    var every_affordable_card_frame_glows := true
    var every_unaffordable_card_frame_stays_unlit := true
    var every_hand_card_background_is_95_percent_opaque := true
    for runtime_card in game.player_hand:
        var hand_card: Button = game.card_nodes_by_uid.get(int(runtime_card.uid)) as Button
        var frame_style := hand_card.get_theme_stylebox("normal") as StyleBoxFlat if hand_card != null else null
        if hand_card == null:
            every_hand_card_background_is_95_percent_opaque = false
        else:
            for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
                var state_style := hand_card.get_theme_stylebox(state) as StyleBoxFlat
                every_hand_card_background_is_95_percent_opaque = every_hand_card_background_is_95_percent_opaque and (
                    state_style != null and is_equal_approx(state_style.bg_color.a, 0.95)
                )
        if int(DB.card(runtime_card.id).cost) <= game.player_mana:
            saw_affordable_card = true
            every_affordable_card_frame_glows = every_affordable_card_frame_glows and (
                frame_style != null
                and frame_style.border_color == game.GOLD
                and frame_style.shadow_size > 0
            )
        else:
            saw_unaffordable_card = true
            every_unaffordable_card_frame_stays_unlit = every_unaffordable_card_frame_stays_unlit and (
                frame_style != null and frame_style.shadow_size == 0
            )
    _expect(saw_affordable_card and every_affordable_card_frame_glows, "every card affordable with current Mana has a golden border glow")
    _expect(saw_unaffordable_card and every_unaffordable_card_frame_stays_unlit, "cards above current Mana do not receive the affordability glow")
    _expect(every_hand_card_background_is_95_percent_opaque, "every hand-fan card background remains 95% opaque in every interaction state")
    game.player_mana = 2
    game.player_max_mana = 2
    game._render_battle()
    player_mana_pool = game.screen_layer.get_node_or_null("PlayerManaPool") as Control
    player_mana_value = game.screen_layer.find_child("PlayerManaValue", true, false) as Label
    player_mana_rack = game.screen_layer.find_child("PlayerManaRackFrame", true, false) as TextureRect
    _expect(player_mana_pool != null and bool(player_mana_pool.get_meta("mana_glowing", false)), "Mana Pool enters its rack glow state above one current Mana")
    _expect(player_mana_rack != null and player_mana_rack.modulate == Color("#D9FAFF"), "Mana Pool glow is limited to its inner rack artwork")
    _expect(player_mana_value != null and not player_mana_value.has_theme_constant_override("shadow_outline_size"), "Mana numbers remain unglowed")
    game.player_mana = 1
    game.player_max_mana = 1
    game._render_battle()
    var enemy_passive_button := game.screen_layer.find_child("EnemyPassiveButton", true, false) as Button
    _expect(enemy_passive_button != null and enemy_passive_button.tooltip_text.begins_with("Enemy skill:"), "enemy passive is available from the adjacent inspectable medallion")
    game._unhandled_input(escape_event)
    var pause_overlay: Node = game.screen_layer.get_node_or_null("PauseOverlay")
    var pause_settings_button: Button = null
    _expect(game.pause_open and game.get_tree().paused, "Escape pauses an active run")
    _expect(pause_overlay != null, "pausing renders a dedicated pause overlay")
    if pause_overlay != null:
        _expect((pause_overlay as CanvasItem).z_index == game.PAUSE_MODAL_Z_INDEX, "pause overlay renders above targeting and gameplay effects")
        _expect(_count_buttons(pause_overlay) == 2, "pause menu contains exactly two actions")
        _expect(_find_button_with_prefix(pause_overlay, "RESIGN") != null, "pause menu exposes Resign")
        pause_settings_button = _find_button_with_prefix(pause_overlay, "SETTINGS")
        _expect(pause_settings_button != null, "pause menu exposes Settings")
    if pause_settings_button != null:
        pause_settings_button.pressed.emit()
    _expect(game.pause_open and game.settings_open and game.get_tree().paused, "pause Settings opens without resuming gameplay")
    game.pause_input_router._input(escape_event)
    _expect(game.pause_open and not game.settings_open and game.get_tree().paused, "Escape returns from Settings to the pause menu")
    game.pause_input_router._input(escape_event)
    _expect(not game.pause_open and not game.get_tree().paused, "Escape resumes an active run from the pause menu")
    var hero_power_button := game.screen_layer.find_child("HeroPowerButton", true, false) as Button
    var end_turn_button := _find_button_with_prefix(game.screen_layer, "END TURN")
    var action_panel := game.screen_layer.find_child("BattleActionPanel", true, false) as Panel
    _expect(hero_power_button != null and end_turn_button != null, "battle action buttons are rendered")
    _expect(action_panel == null, "obsolete lower-left action panel is removed")
    if hero_power_button != null and end_turn_button != null:
        _expect(Rect2(hero_power_button.position, hero_power_button.size) == game._target_battle_zone(&"hero_power") and Rect2(end_turn_button.position, end_turn_button.size) == game._target_battle_zone(&"turn_control"), "Chef Power stays beside the player station and one End Turn control owns the right rail")
        _expect(not Rect2(hero_power_button.position, hero_power_button.size).intersects(Rect2(end_turn_button.position, end_turn_button.size)), "Chef Power and End Turn controls do not overlap")
        var power_title := hero_power_button.get_node_or_null("HeroPowerTitle") as Label
        var power_cost := hero_power_button.get_node_or_null("HeroPowerCostRow/HeroPowerCost") as Label
        var power_icon := hero_power_button.get_node_or_null("HeroPowerCostRow/HeroPowerManaIcon") as TextureRect
        var power_effect := hero_power_button.get_node_or_null("HeroPowerEffect") as Label
        _expect(power_title != null and power_title.text == "SEASON PAN" and power_title.get_theme_font_size("font_size") == 13, "Chef Power title remains prominent")
        _expect(power_cost != null and power_cost.text == "COST 2" and power_cost.get_theme_font_size("font_size") == 9, "Chef Power cost uses smaller supporting text")
        _expect(power_icon != null and power_icon.texture == DB.art("juice_mana_burner"), "Chef Power replaces the Mana word with the mana icon")
        _expect(power_effect != null and power_effect.text == "GAIN +2 ARMOR" and power_effect.get_theme_font_size("font_size") == 9, "Chef Power effect uses smaller supporting text")
        _expect(end_turn_button.text == "END TURN", "End Turn button omits its keyboard shortcut")

    var precise_index := _find_hand_card(game, "precise_chop")
    _expect(precise_index >= 0, "opening hand guarantees Precise Chop")
    game.enemy_board[0].health = 2
    game._on_hand_card_pressed(precise_index)
    _expect(game.pending_action.get("effect") == "target_enemy_damage", "targeted Technique enters targeting mode")
    await process_frame
    _expect(game.target_line.active and game.target_line.visible, "targeted Technique displays its targeting arrow")
    var hand_size_before_target_cancel: int = game.player_hand.size()
    var mana_before_target_cancel: int = game.player_mana
    game._unhandled_input(escape_event)
    _expect(game.pending_action.is_empty(), "Escape clears the targeted card selection")
    _expect(not game.target_line.active and not game.target_line.visible, "Escape dismisses the targeting arrow")
    _expect(not game.pause_open and not game.get_tree().paused, "Escape does not pause while targeting is active")
    _expect(
        game.player_hand.size() == hand_size_before_target_cancel and game.player_mana == mana_before_target_cancel,
        "cancelling targeting keeps the selected card and its Mana unspent"
    )
    game._on_hand_card_pressed(precise_index)
    _expect(game.pending_action.get("effect") == "target_enemy_damage", "cancelled targeted Technique can be selected again")
    game._on_enemy_unit_pressed(0)
    _expect(game.precise_kills == 1, "exact damage records a Precise Cut")
    _expect(game.pantry.herb == 1, "Precise Cut harvests the enemy ingredient")
    _expect(game.enemy_board.is_empty(), "defeated enemy leaves the board")

    game.player_mana = 5
    game.use_hero_power()
    _expect(game.hero_power_used and game.player_armor >= 2, "Chef Power applies Armor and marks itself used")
    var squire_index := _find_hand_card(game, "coal_squire")
    game._on_hand_card_pressed(squire_index)
    _expect(game.player_board.size() == 1, "unit card summons a Kitchen Ally")
    _expect(not game.player_board[0].ready, "new ally begins asleep")
    _expect(game.player_board[0].has("uid") and game.player_board[0].uid > 0, "summoned units receive stable presentation UIDs")
    _expect(game.player_board[0].attack == 2, "Chef Power seasons the next summoned ally")
    var sleeping_unit_button: Button = game.unit_nodes_by_uid.get(int(game.player_board[0].uid))
    _expect(sleeping_unit_button != null and sleeping_unit_button.get_node_or_null("SleepParticles") != null, "sleeping units render a rising Z particle emitter")

    await game.end_player_turn()
    _expect(game.is_player_turn, "enemy artificial intelligence completes and returns control")
    _expect(game.turn_number == 2, "turn counter advances after enemy artificial intelligence")
    _expect(game.player_board[0].ready, "surviving ally wakes on the next turn")
    var ready_unit_button: Button = game.unit_nodes_by_uid.get(int(game.player_board[0].uid))
    _expect(ready_unit_button != null and ready_unit_button.get_node_or_null("SleepParticles") == null, "ready units remove the sleep particle emitter")

    var overkill_unit: Dictionary = game._summon_unit("pickle_imp", false, false)
    overkill_unit.health = 1
    game._damage_unit(overkill_unit, 2, true)
    game._remove_dead_units()
    _expect(game.overkills == 1, "excess lethal damage records Overkill")

    game.player_board.clear()
    game.player_hand.clear()
    game.player_discard.clear()
    game.player_deck.clear()
    game.player_max_mana = 8
    game.player_mana = 8
    game.player_hand.append(game._make_runtime_card("mise_the_thousand_handed"))
    game._on_hand_card_pressed(0)
    _expect(game.player_board.size() == 1 and game.player_board[0].id == "mise_the_thousand_handed", "Mise enters play as a 4/7 legendary ally")
    _expect(game.player_mana == 2, "Mise spends 6 Mana")
    game.player_deck.append(game._make_runtime_card("pepper_mage"))
    game.player_hand.append(game._make_runtime_card("coal_squire"))
    game._on_hand_card_pressed(0)
    _expect(game.player_mana == 2, "Mise refunds 1 Mana after a low-cost card")
    _expect(game.player_hand.size() == 1 and game.player_hand[0].id == "pepper_mage", "Mise draws one replacement card after a low-cost card")

    game.player_hand.clear()
    game.enemy_board.clear()
    game.enemy_health = 20
    var cleaver_herb_before := int(game.pantry.herb)
    var cleaver_meat_before := int(game.pantry.meat)
    var cleaver_precise_before: int = game.precise_kills
    var cleaver_overkills_before: int = game.overkills
    var cleaver_pickle: Dictionary = game._summon_unit("pickle_imp", false, false)
    var cleaver_mimic: Dictionary = game._summon_unit("meat_mimic", false, false)
    cleaver_pickle.health = 1
    cleaver_mimic.health = 4
    game.player_mana = 8
    game.player_hand.append(game._make_runtime_card("the_sovereign_cleaver"))
    game._on_hand_card_pressed(0)
    _expect(game.enemy_health == 15 and game.enemy_board.is_empty(), "Sovereign Cleaver deals 5 to the enemy chef and every enemy unit")
    _expect(int(game.pantry.herb) == cleaver_herb_before + 1 and int(game.pantry.meat) == cleaver_meat_before + 1, "Sovereign Cleaver harvests every lethal ingredient")
    _expect(game.precise_kills == cleaver_precise_before + 2 and game.overkills == cleaver_overkills_before, "Sovereign Cleaver converts its overkill damage into Precise Cuts")

    game.player_hand.clear()
    game.player_health = 10
    for unit in game.player_board:
        unit.ready = false
    var bell_attack_before := int(game.player_board[0].attack)
    var bell_health_before := int(game.player_board[0].health)
    game.player_mana = 8
    game.player_hand.append(game._make_runtime_card("bell_of_the_last_service"))
    game._on_hand_card_pressed(0)
    _expect(game.player_health == 18, "Bell restores 8 Health")
    _expect(game.player_board[0].ready and int(game.player_board[0].attack) == bell_attack_before + 3 and int(game.player_board[0].health) == bell_health_before + 3, "Bell gives every ally +3/+3 and Ready")

    game.debug_force_battle_victory()
    await process_frame
    _expect(game.screen_name == "kitchen", "battle victory enters a Kitchen Break")
    _expect(game.player_health == 20, "rebalanced Kitchen Break restores 2 Health")
    _expect(_has_legendary_rewards(game, 3), "first victory offers all three unique legendary cards")

    game.pantry.fungus = 1
    game.pantry.herb = maxi(1, game.pantry.herb)
    var deck_before_cooking: int = game.run_deck.size()
    game._cook_recipe("mooncap_broth")
    _expect(game.run_deck.size() == deck_before_cooking + 1, "cooking adds a Dish Card to the run deck")
    _expect(game.dishes_cooked == 1, "cooking statistic increments")
    var dish: Dictionary = game.run_deck.back()
    _expect(dish.id == "mooncap_broth" and dish.servings == 2, "Dish Card stores finite servings")

    var reward_card: String = game.reward_options[0]
    var deck_before_reward: int = game.run_deck.size()
    game._select_reward(reward_card)
    _expect(game.reward_done, "card reward can be selected")
    _expect(game.run_deck.size() == deck_before_reward + 1 and game.run_deck.back().id == reward_card, "selected legendary is added to the run deck")
    _expect(game.claimed_legendary_ids == [reward_card], "selected legendary is recorded as claimed for the run")
    game._continue_from_kitchen()
    _expect(game.screen_name == "route", "first Kitchen Break leads to route selection")

    game._choose_route("mold_monarch")
    _expect(game.screen_name == "battle" and game.battle_number == 2, "Cold Cellar route starts battle two")
    game.debug_force_battle_victory()
    await process_frame
    _expect(game.screen_name == "kitchen", "second victory enters the final Kitchen Break")
    _expect(_has_legendary_rewards(game, 2, reward_card), "second victory offers only the two unclaimed legendaries")
    _expect(not game.reward_options.has(reward_card), "a claimed legendary never reappears in later rewards")
    game._select_reward(game.reward_options[0])
    _expect(game.claimed_legendary_ids.size() == 2, "two different legendary rewards can be claimed in one run")
    game._continue_from_kitchen()
    _expect(game.screen_name == "battle" and game.current_encounter_id == "banquet_tyrant", "Kitchen Break starts the final boss")

    game.enemy_health = int(game.enemy_max_health / 2) + 1
    game._damage_enemy_hero(2)
    _expect(game.boss_enraged, "Banquet Tyrant enters Second Serving below half Health")

    game.debug_force_run_victory()
    await process_frame
    _expect(game.screen_name == "end" and game.run_result == "victory", "boss defeat reaches victory summary")
    _expect(game.last_run_score > 0, "victory calculates a leaderboard score")
    _expect(_contains_submission(game.local_scores, game.last_run_submission_id), "completed victory is recorded locally")
    _expect(_contains_submission(game.pending_global_submissions, game.last_run_submission_id), "offline victory is queued for global submission")
    _expect(_has_label(game.screen_layer, "LOCAL") and _has_label(game.screen_layer, "GLOBAL"), "game over shows local and global standings together")
    _expect(game.screen_layer.get_node_or_null("VictoryLegendaryShowcase") != null, "victory summary showcases the claimed legendary cards")

    game.start_new_run(2026)
    _expect(game.claimed_legendary_ids.is_empty(), "a new run resets claimed legendary rewards")
    game.debug_force_defeat()
    await process_frame
    _expect(game.screen_name == "end" and game.run_result == "defeat", "zero player Health reaches defeat summary")
    _expect(_contains_submission(game.local_scores, game.last_run_submission_id), "completed defeat is recorded locally")
    _expect(_contains_submission(game.pending_global_submissions, game.last_run_submission_id), "multiple offline runs remain queued for global submission")

    var ranked_queue_size: int = game.pending_global_submissions.size()
    game.tweaks.set_value(&"player.starting_health", 60, false)
    game.start_new_run(3030)
    _expect(not game.run_ranked_eligible, "gameplay-affecting tweaks mark a run as local-only")
    game.debug_force_defeat()
    await process_frame
    _expect(not game.last_run_ranked_eligible, "custom-rules result remains ineligible for the global board")
    _expect(_contains_submission(game.local_scores, game.last_run_submission_id), "custom-rules result is still recorded locally")
    _expect(game.pending_global_submissions.size() == ranked_queue_size, "custom-rules result is not queued globally")
    game.tweaks.reset_parameter(&"player.starting_health")

    game.show_title()
    _expect(game.screen_name == "title", "run summary can return to title")

    game.start_new_run(4040)
    game._unhandled_input(escape_event)
    pause_overlay = game.screen_layer.get_node_or_null("PauseOverlay")
    var resign_button: Button = _find_button_with_prefix(pause_overlay, "RESIGN") if pause_overlay != null else null
    if resign_button != null:
        resign_button.pressed.emit()
    _expect(resign_button != null and game.screen_name == "end" and game.run_result == "defeat", "Resign ends the current run as a defeat")
    _expect(not game.pause_open and not game.get_tree().paused, "Resign leaves the scene tree running for the result screen")

    var store: Node = game.tweaks
    _expect(store == root.get_node("RuntimeTuning"), "game uses the persistent authoritative tuning store")
    _expect(store.apply_preview_patch({"ui.hud_tint": "#55aa7700", "environment.background_tint": Color(0.2, 0.4, 0.6, 0.1)}), "color tuning accepts preview values")
    _expect(store.get_color(&"ui.hud_tint").a == 1.0 and store.get_color(&"environment.background_tint").a == 1.0, "RGB-only presentation controls stay opaque")
    _expect(store.apply_preview_patch({"player.starting_health": 44}), "next-run value is accepted")
    var values: Dictionary = store._values.duplicate(true)
    var active: Dictionary = store._active_values.duplicate(true)
    game.free()
    await process_frame
    var multiplayer_scene: Node = load("res://scenes/multiplayer.tscn").instantiate()
    root.add_child(multiplayer_scene)
    await process_frame
    _expect(store == root.get_node("RuntimeTuning"), "tuning remains available while visiting multiplayer")
    _expect(store._values == values and store._active_values == active, "multiplayer does not replace local preview settings")
    multiplayer_scene.free()
    await process_frame
    game = packed_scene.instantiate()
    root.add_child(game)
    await process_frame
    _expect(game.tweaks == store and store._values == values and store._active_values == active, "returning to solo retains pending and active values")
    _expect(store.value_changed.get_connections().size() == 1, "freed game does not leave duplicate tuning listeners")
    store.reset_all()
    var passed := failures.is_empty()
    game.free()
    await create_timer(0.15).timeout
    await process_frame
    await process_frame
    if passed:
        print("[SMOKE_PASS] title dialogs, pause flow, combat, AI, exact harvest, cooking, rewards, route, boss, victory, defeat, and replay validated")
        quit(0)
    else:
        push_error("[SMOKE_FAIL] %d assertions failed" % failures.size())
        quit(1)
