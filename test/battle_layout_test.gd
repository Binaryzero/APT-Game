extends SceneTree

const LAYOUT := preload("res://scripts/battle_layout.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error("[BATTLE_LAYOUT_FAIL] " + message)


func _expect_near(actual: Vector2, expected: Vector2, tolerance: float, message: String) -> void:
    _expect(actual.distance_to(expected) <= tolerance, "%s (%s / %s)" % [message, actual, expected])


func _expect_fitted_hud_labels(root: Control, context: String) -> void:
    var fitted_count := 0
    for node in root.find_children("*", "Label", true, false):
        var label := node as Label
        if label == null or not label.has_meta("hud_resolved_font_size"):
            continue
        fitted_count += 1
        var parent := label.get_parent() as Control
        var fits_parent := parent != null and Rect2(Vector2.ZERO, parent.size).encloses(Rect2(label.position, label.size))
        _expect(parent != null and fits_parent, "%s: %s remains inside its HUD parent" % [context, label.name])
        _expect(label.autowrap_mode == TextServer.AUTOWRAP_OFF and label.max_lines_visible == 1, "%s: %s is a single-line HUD label" % [context, label.name])
        _expect(label.clip_text and label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "%s: %s clips with ellipsis fallback" % [context, label.name])
        var outline_size := label.get_theme_constant("outline_size")
        var assigned_size: Vector2 = label.get_meta("hud_assigned_size", label.size)
        var font_size := label.get_theme_font_size("font_size")
        var font := label.get_theme_font("font")
        var text_size := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
        var glyphs_fit := text_size.x + float(outline_size * 2 + 2) <= assigned_size.x + 0.5 and font.get_height(font_size) + float(outline_size * 2 + 2) <= assigned_size.y + 0.5
        _expect(outline_size > 0, "%s: %s has a dark readability outline" % [context, label.name])
        _expect(bool(label.get_meta("hud_text_fits", false)), "%s: %s reports a successful fitted-text result" % [context, label.name])
        _expect(glyphs_fit, "%s: %s rendered glyph bounds fit its authored rectangle (%s in %s)" % [context, label.name, text_size, assigned_size])
    _expect(fitted_count >= 14, "%s: all critical relocated HUD labels use the fitted-label contract" % context)


func _representative_history(game: Node) -> Array[Dictionary]:
    return [
        {"event": game.t("history.event.draw"), "value": 1, "color": Color("#F7E9C8")},
        {"event": game.t("history.event.death"), "value": -1, "color": Color("#D95757"), "highlight_red": true},
        {"event": game.t("history.event.precise_cut"), "value": -2, "color": Color("#55C6A9")},
        {"event": game.t("history.event.hero_damage"), "value": 12, "color": Color("#D95757"), "highlight_red": true},
    ]


func _run() -> void:
    var layout := LAYOUT.new()
    layout.configure(Vector2(1280, 720), Vector4.ZERO, LAYOUT.PROFILE_STANDARD)
    _expect(layout.safe_canvas() == Rect2(0, 0, 1280, 720), "shipped safe canvas preserves the authored design space")
    _expect(layout.zone(&"opponent_hand") == Rect2(435, 0, 410, 40), "shipped opponent hand occupies only the top-edge peek strip")
    _expect(layout.zone(&"opponent_station") == Rect2(512, 42, 256, 124), "shipped opponent station owns the top-center spine")
    _expect(layout.zone(&"opponent_row") == Rect2(242, 170, 807, 132), "opponent row keeps its established clearance from the hero station")
    _expect(layout.zone(&"player_row") == Rect2(242, 354, 807, 108), "player row reserves space for below-card minion names")
    _expect(layout.zone(&"player_station") == Rect2(512, 490, 256, 124), "shipped player station owns the bottom-center spine")
    _expect(layout.zone(&"hero_power") == Rect2(740, 514, 108, 72), "shipped Chef Power hugs the visible edge of the player station")
    _expect(layout.zone(&"opponent_deck") == Rect2(1139, 100, 128, 115), "shipped opponent deck sits eight pixels higher on the upper-right rail")
    _expect(layout.zone(&"turn_control") == Rect2(1123, 299, 144, 97), "shipped End Turn owns the mid-right commitment rail")
    _expect(layout.zone(&"player_deck") == Rect2(1139, 439, 128, 144), "shipped player deck owns the lower-right cradle")
    _expect(layout.zone_for_profile(&"opponent_deck", LAYOUT.PROFILE_COMPACT) == Rect2(1146, 102, 120, 112), "compact opponent deck also sits eight pixels higher")
    _expect(layout.zone(&"play_region") == Rect2(205, 150, 870, 390), "one shipped play region owns display and legality")
    _expect(layout.zone(&"preview") == Rect2(170, 176, 246, 350), "shipped card preview owns a fixed left-side inspection zone")

    var target_cases := [
        {"size": Vector2(1280, 720), "insets": Vector4.ZERO},
        {"size": Vector2(1920, 1080), "insets": Vector4(24, 16, 24, 16)},
        {"size": Vector2(1024, 768), "insets": Vector4(32, 24, 32, 24)},
        {"size": Vector2(2560, 1080), "insets": Vector4(48, 0, 48, 0)},
    ]
    for test_case: Dictionary in target_cases:
        layout.configure(test_case.size, test_case.insets, LAYOUT.PROFILE_STANDARD)
        var safe := layout.safe_canvas()
        _expect(is_equal_approx(safe.size.x / safe.size.y, LAYOUT.DESIGN_ASPECT), "safe canvas remains 16:9 at %s" % test_case.size)
        for zone_name: StringName in layout.target_zone_names():
            _expect(layout.contains_zone(zone_name), "%s stays within safe canvas at %s" % [zone_name, test_case.size])
        var reference_probe := Rect2(230, 158, 819, 133)
        var runtime_probe := layout.from_reference(reference_probe)
        var round_trip := layout.to_reference(runtime_probe)
        _expect_near(round_trip.position, reference_probe.position, 0.01, "reference position round-trips")
        _expect_near(round_trip.size, reference_probe.size, 0.01, "reference size round-trips")

    layout.configure(Vector2(960, 540), Vector4(48, 12, 48, 12), LAYOUT.PROFILE_STANDARD)
    _expect(layout.choose_profile_for_safe_width() == LAYOUT.PROFILE_COMPACT, "narrow safe width selects compact profile")
    layout.configure(Vector2(1920, 1080), Vector4.ZERO, LAYOUT.PROFILE_STANDARD)
    _expect(layout.choose_profile_for_safe_width() == LAYOUT.PROFILE_STANDARD, "wide safe width selects standard profile")

    var packed_scene := load("res://scenes/card_game.tscn") as PackedScene
    _expect(packed_scene != null, "game scene loads with BattleLayout")
    if packed_scene != null:
        var game := packed_scene.instantiate()
        root.add_child(game)
        await process_frame
        game.sound_muted = true
        var probe := Control.new()
        probe.position = Vector2(184, 236)
        probe.size = Vector2(158, 142)
        game.screen_layer.add_child(probe)
        for hud_scale in [0.8, 1.0, 1.2]:
            game.screen_layer.scale = Vector2.ONE * hud_scale
            game.screen_layer.position = Vector2(11, -7)
            await process_frame
            var expected_canvas_center: Vector2 = probe.get_global_transform_with_canvas() * (probe.size * 0.5)
            var juice_expected: Vector2 = game.juice.get_global_transform_with_canvas().affine_inverse() * expected_canvas_center
            var tutorial_expected: Vector2 = game.tutorial_callout.get_global_transform_with_canvas().affine_inverse() * expected_canvas_center
            var juice_rect: Rect2 = game._control_rect_in_layer(probe, game.juice)
            var tutorial_rect: Rect2 = game._control_rect_in_layer(probe, game.tutorial_callout)
            _expect_near(juice_rect.get_center(), juice_expected, 0.01, "JuiceLayer center follows live control at HUD scale %.1f" % hud_scale)
            _expect_near(tutorial_rect.get_center(), tutorial_expected, 0.01, "TutorialCanvas center follows live control at HUD scale %.1f" % hud_scale)
            game.target_line.configure(juice_rect.get_center(), Color.WHITE)
            _expect_near(game.target_line.start_point, juice_expected, 0.01, "target line uses transformed live source at HUD scale %.1f" % hud_scale)

        probe.queue_free()
        game.screen_layer.scale = Vector2.ONE
        game.screen_layer.position = Vector2.ZERO
        game.debug_fast = true
        game.start_new_run(2402)
        await process_frame
        await process_frame
        for friendly in [true, false]:
            var unit: Dictionary = game._summon_unit("coal_squire" if friendly else "moldling", friendly, false)
            game._render_battle()
            var token: Button = game.unit_nodes_by_uid[int(unit.uid)]
            var mana_before: int = game.player_mana
            var selection_before: Dictionary = game.pending_action.duplicate(true)
            for signal_pair in [["mouse_entered", "mouse_exited"], ["focus_entered", "focus_exited"]]:
                token.emit_signal(signal_pair[0])
                _expect(game.card_preview != null, "played cards support hover and focus inspection on both sides, including sleeping units")
                if game.card_preview != null:
                    _expect(game.card_preview.get_meta("screen_rect") == game._target_battle_zone(&"preview"), "played cards reuse the left-side preview zone")
                    _expect(game.card_preview.mouse_filter == Control.MOUSE_FILTER_IGNORE, "played-card previews do not intercept targeting input")
                    _expect(game.card_preview.get_child(2).text == game.t(game.DB.card(unit.id).name_key), "played-card preview displays the inspected card definition")
                _expect(game.player_mana == mana_before and game.pending_action == selection_before and not unit.ready, "inspection does not spend mana, select, or ready a unit")
                token.emit_signal(signal_pair[1])
                _expect(game.card_preview == null, "played-card preview dismisses when hover or focus ends")
        game.start_new_run(2402)
        await process_frame
        await process_frame
        var enemy_station := game.screen_layer.find_child("EnemyHeroStation", true, false) as Control
        var player_station := game.screen_layer.find_child("PlayerStatusPanel", true, false) as Control
        var passive_button := game.screen_layer.find_child("EnemyPassiveButton", true, false) as Control
        var opponent_hand := game.screen_layer.find_child("OpponentHandDisplay", true, false) as Control
        var hero_power := game.screen_layer.find_child("HeroPowerButton", true, false) as Control
        _expect(enemy_station != null and Rect2(enemy_station.position, enemy_station.size) == game._target_battle_zone(&"opponent_station"), "opponent hero uses the compact top-center station")
        _expect(player_station != null and Rect2(player_station.position, player_station.size) == game._target_battle_zone(&"player_station"), "player hero uses the compact bottom-center station")
        _expect(passive_button != null and Rect2(passive_button.position, passive_button.size) == game._target_battle_zone(&"passive"), "enemy passive medallion is adjacent to the opponent station")
        _expect(game.enemy_hand.is_empty() and opponent_hand == null, "an empty opponent hand renders neither cards nor a zero count")
        _expect(hero_power != null and Rect2(hero_power.position, hero_power.size) == game._target_battle_zone(&"hero_power"), "Chef Power is adjacent to the bottom-center player station")
        if enemy_station != null and player_station != null:
            var enemy_portrait_backdrop := enemy_station.get_node_or_null("HeroPortraitBackdrop") as Panel
            var player_portrait_backdrop := player_station.get_node_or_null("HeroPortraitBackdrop") as Panel
            var enemy_portrait := enemy_station.get_node_or_null("HeroPortrait") as TextureRect
            var player_portrait := player_station.get_node_or_null("HeroPortrait") as TextureRect
            var enemy_hero_frame := enemy_station.get_node_or_null("HeroStationFrame") as TextureRect
            var player_hero_frame := player_station.get_node_or_null("HeroStationFrame") as TextureRect
            var enemy_neutral_cover_left := enemy_station.get_node_or_null("HeroNeutralCoverLeft") as Panel
            var enemy_neutral_cover_right := enemy_station.get_node_or_null("HeroNeutralCoverRight") as Panel
            var player_neutral_cover_left := player_station.get_node_or_null("HeroNeutralCoverLeft") as Panel
            var player_neutral_cover_right := player_station.get_node_or_null("HeroNeutralCoverRight") as Panel
            var enemy_portrait_backdrop_style := enemy_portrait_backdrop.get_theme_stylebox("panel") as StyleBoxFlat if enemy_portrait_backdrop != null else null
            var player_portrait_backdrop_style := player_portrait_backdrop.get_theme_stylebox("panel") as StyleBoxFlat if player_portrait_backdrop != null else null
            _expect(enemy_portrait_backdrop_style != null and is_equal_approx(enemy_portrait_backdrop_style.bg_color.a, 0.8) and enemy_portrait_backdrop_style.corner_radius_top_left >= 39, "opponent portrait has an 80% opaque rounded black background")
            _expect(player_portrait_backdrop_style != null and is_equal_approx(player_portrait_backdrop_style.bg_color.a, 0.8) and player_portrait_backdrop_style.corner_radius_top_left >= 39, "player portrait has an 80% opaque rounded black background")
            for neutral_cover: Panel in [enemy_neutral_cover_left, enemy_neutral_cover_right, player_neutral_cover_left, player_neutral_cover_right]:
                var neutral_cover_style := neutral_cover.get_theme_stylebox("panel") as StyleBoxFlat if neutral_cover != null else null
                _expect(neutral_cover_style != null and neutral_cover_style.bg_color == Color.BLACK, "hero stat parchment is completely replaced by opaque black")
            _expect(enemy_portrait_backdrop != null and enemy_portrait != null and enemy_portrait_backdrop.get_index() < enemy_portrait.get_index(), "opponent backdrop renders beneath its portrait")
            _expect(player_portrait_backdrop != null and player_portrait != null and player_portrait_backdrop.get_index() < player_portrait.get_index(), "player backdrop renders beneath its portrait")
            _expect(enemy_portrait != null and Rect2(enemy_portrait.position, enemy_portrait.size) == game.HERO_PORTRAIT_RECT and enemy_portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "opponent portrait uses the enlarged covered crop")
            _expect(player_portrait != null and Rect2(player_portrait.position, player_portrait.size) == game.HERO_PORTRAIT_RECT and player_portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "player portrait uses the enlarged covered crop")
            _expect(enemy_portrait_backdrop != null and Rect2(enemy_portrait_backdrop.position, enemy_portrait_backdrop.size) == game.HERO_PORTRAIT_BACKDROP_RECT, "opponent backdrop overscans the full portrait opening")
            _expect(player_portrait_backdrop != null and Rect2(player_portrait_backdrop.position, player_portrait_backdrop.size) == game.HERO_PORTRAIT_BACKDROP_RECT, "player backdrop overscans the full portrait opening")
            _expect(enemy_hero_frame != null and enemy_portrait_backdrop != null and enemy_hero_frame.get_index() < enemy_portrait_backdrop.get_index(), "opponent portrait cover blocks the pale frame interior")
            _expect(player_hero_frame != null and player_portrait_backdrop != null and player_hero_frame.get_index() < player_portrait_backdrop.get_index(), "player portrait cover blocks the pale frame interior")
            _expect(is_equal_approx(enemy_station.position.x, player_station.position.x), "hero stations share the ownership spine")
            _expect(enemy_station.position.y < player_station.position.y, "opponent remains above the local player")
            var enemy_name_plate := enemy_station.get_node_or_null("HeroNamePlate") as Panel
            var player_name_plate := player_station.get_node_or_null("HeroNamePlate") as Panel
            var enemy_name_label := enemy_station.find_child("HeroNameLabel", true, false) as Label
            var player_name_label := player_station.find_child("HeroNameLabel", true, false) as Label
            _expect(enemy_name_plate != null and Rect2(Vector2.ZERO, enemy_station.size).encloses(Rect2(enemy_name_plate.position, enemy_name_plate.size)), "opponent nameplate remains inside its station")
            _expect(player_name_plate != null and Rect2(Vector2.ZERO, player_station.size).encloses(Rect2(player_name_plate.position, player_name_plate.size)), "player nameplate remains inside its station")
            _expect(enemy_name_label != null and player_name_label != null and bool(enemy_name_label.get_meta("hud_text_fits", false)) and bool(player_name_label.get_meta("hud_text_fits", false)), "both hero names use measured fitted text")
            _expect(enemy_station.clip_contents and player_station.clip_contents, "hero stations enforce hard visual containment")
            for station: Control in [enemy_station, player_station]:
                var station_portrait := station.get_node_or_null("HeroPortrait") as TextureRect
                var station_name_plate := station.get_node_or_null("HeroNamePlate") as Panel
                var station_health_plate := station.get_node_or_null("HeroHealthPlate") as Panel
                var station_armor_plate := station.get_node_or_null("HeroArmorPlate") as Panel
                _expect(station_portrait != null and station_name_plate != null and not Rect2(station_portrait.position, station_portrait.size).intersects(Rect2(station_name_plate.position, station_name_plate.size)), "%s nameplate clears its portrait" % station.name)
                _expect(station_portrait != null and station_health_plate != null and not Rect2(station_portrait.position, station_portrait.size).intersects(Rect2(station_health_plate.position, station_health_plate.size)), "%s Health plate clears its portrait" % station.name)
                _expect(station_portrait != null and station_armor_plate != null and not Rect2(station_portrait.position, station_portrait.size).intersects(Rect2(station_armor_plate.position, station_armor_plate.size)), "%s Armor plate clears its portrait" % station.name)
                _expect(station_health_plate != null and station_armor_plate != null and not Rect2(station_health_plate.position, station_health_plate.size).intersects(Rect2(station_armor_plate.position, station_armor_plate.size)), "%s vital plates remain independently readable" % station.name)
        if passive_button != null:
            var passive_portrait_backdrop := passive_button.get_node_or_null("PassivePortraitBackdrop") as ColorRect
            _expect(passive_portrait_backdrop != null and passive_portrait_backdrop.color == Color.BLACK, "enemy passive portrait has an opaque black backdrop")

        var protected_zone_names: Array[StringName] = [&"history_rail", &"pantry", &"opponent_deck", &"turn_control", &"player_deck", &"player_mana", &"opponent_mana", &"opponent_station", &"player_station", &"player_hand"]
        for friendly in [false, true]:
            var row_zone: StringName = &"player_row" if friendly else &"opponent_row"
            for slot_count in [1, 4, 6]:
                var slot_rects: Array[Rect2] = game._board_slot_rects(friendly, slot_count)
                _expect(slot_rects.size() == slot_count, "%s row returns %d stable slots" % ["player" if friendly else "opponent", slot_count])
                for slot_index in range(slot_rects.size()):
                    var slot_rect := slot_rects[slot_index]
                    _expect(game._target_battle_zone(row_zone).grow(0.01).encloses(slot_rect), "slot %d stays inside the %s row" % [slot_index, row_zone])
                    for other_index in range(slot_index):
                        _expect(not slot_rect.intersects(slot_rects[other_index]), "permanent slots remain distinct at density %d" % slot_count)
                    for zone_name in protected_zone_names:
                        if zone_name == row_zone or (friendly and zone_name == &"player_hand"):
                            continue
                        _expect(not slot_rect.intersects(game._target_battle_zone(zone_name)), "%s slot clears %s at density %d" % [row_zone, zone_name, slot_count])

        for hand_count in [1, 5, 8, 10]:
            var hand_rects: Array[Rect2] = game._hand_layout_rects(hand_count)
            _expect(hand_rects.size() == hand_count, "hand geometry returns %d stable cards" % hand_count)
            var prior_cost_corner := Rect2()
            for hand_index in range(hand_rects.size()):
                var hand_card_rect := hand_rects[hand_index]
                _expect(Rect2(0, 0, 1280, 720).encloses(hand_card_rect), "hand card %d stays inside the authored canvas" % hand_index)
                for zone_name in [&"pantry", &"player_station", &"hero_power", &"player_deck", &"player_mana"]:
                    _expect(not hand_card_rect.intersects(game._target_battle_zone(zone_name)), "hand card %d clears %s at count %d" % [hand_index, zone_name, hand_count])
                var cost_corner := Rect2(hand_card_rect.position, Vector2(24, 40))
                if hand_index > 0:
                    _expect(not cost_corner.intersects(prior_cost_corner), "cost corners stay individually exposed at count %d" % hand_count)
                prior_cost_corner = cost_corner

        _expect(game.screen_layer.get_node_or_null("CenterEndTurnButton") == null, "combat corridor contains no duplicate End Turn control")
        var plate_tokens: Array = game.screen_layer.find_children("*", "Button", true, false).filter(func(node): return bool(node.get_meta("plate_token", false)))
        _expect(plate_tokens.size() == game.enemy_board.size() + game.player_board.size(), "every occupied permanent renders as one culinary plate token")
        for plate_token: Button in plate_tokens:
            var unit_name_plate := plate_token.get_node_or_null("UnitNamePlate") as Panel
            var unit_state_plate := plate_token.get_node_or_null("UnitStatePlate") as Panel
            var unit_portrait_backdrop := plate_token.get_node_or_null("UnitPortraitBackdrop") as Panel
            var unit_portrait_backdrop_style := unit_portrait_backdrop.get_theme_stylebox("panel") as StyleBoxFlat if unit_portrait_backdrop != null else null
            _expect(unit_portrait_backdrop_style != null and is_equal_approx(unit_portrait_backdrop_style.bg_color.a, 0.8), "every minion portrait has an 80% opaque black aperture backing")
            _expect(not plate_token.clip_contents and unit_name_plate != null and unit_state_plate != null, "every permanent exposes its below-card nameplate while retaining a bounded state plate")
            _expect(unit_name_plate != null and unit_name_plate.position.y >= plate_token.size.y - 0.01, "every minion name sits below its circular card frame")
            var unit_name_label := unit_name_plate.get_node_or_null("UnitNameLabel") as Label if unit_name_plate != null else null
            _expect(unit_name_label != null and Rect2(Vector2.ZERO, unit_name_plate.size).encloses(Rect2(unit_name_label.position, unit_name_label.size)), "UnitNameLabel remains contained by its below-card plate")
            for label_name in ["UnitStateLabel", "UnitAttackLabel", "UnitHealthLabel"]:
                var unit_label := plate_token.get_node_or_null(label_name) as Label
                _expect(unit_label != null and Rect2(Vector2.ZERO, plate_token.size).encloses(Rect2(unit_label.position, unit_label.size)), "%s remains inside its permanent plate" % label_name)
            for stat_name in ["Attack", "Health"]:
                var stat_icon := plate_token.get_node_or_null("Unit%sIcon" % stat_name) as TextureRect
                var stat_label := plate_token.get_node_or_null("Unit%sLabel" % stat_name) as Label
                var stat_font := stat_label.get_theme_font("font") as FontVariation if stat_label != null else null
                var icon_center := stat_icon.position + stat_icon.size * 0.5 if stat_icon != null else Vector2.ZERO
                var label_center := stat_label.position + stat_label.size * 0.5 if stat_label != null else Vector2.ONE
                _expect(stat_icon != null and stat_label != null and icon_center.distance_to(label_center) <= 0.01, "%s number is centered over its icon" % stat_name)
                _expect(stat_label != null and stat_label.get_theme_font_size("font_size") >= 16, "%s number uses the larger stat type size" % stat_name)
                _expect(stat_font != null and stat_font.variation_embolden > 0.0, "%s number uses a bold font variation" % stat_name)
            var unit_health_label := plate_token.get_node_or_null("UnitHealthLabel") as Label
            var expected_health_color: Color = game.TEAL if bool(plate_token.get_meta("friendly", false)) else game.MINION_HEALTH_RED
            _expect(unit_health_label != null and unit_health_label.get_theme_color("font_color") == expected_health_color, "player minion Health uses player cyan while enemy minion Health remains bright red")
        var history_button := game.screen_layer.get_node_or_null("ServiceHistoryButton") as Control
        var pantry_panel := game.screen_layer.get_node_or_null("BattlePantryPanel") as Control
        var enemy_deck_display := game.screen_layer.get_node_or_null("EnemyDeckDisplay") as Control
        var player_deck_display := game.screen_layer.get_node_or_null("PlayerDeckDisplay") as Control
        var enemy_mana_pool := game.screen_layer.get_node_or_null("EnemyManaPool") as Control
        var player_mana_pool := game.screen_layer.get_node_or_null("PlayerManaPool") as Control
        var end_turn_button := game.screen_layer.get_node_or_null("EndTurnButton") as Control
        var turn_marker := game.screen_layer.get_node_or_null("TurnMarker") as Control
        _expect(history_button != null and Rect2(history_button.position, history_button.size) == game._target_battle_zone(&"history_rail"), "newest-first history owns the slim left audit rail (%s / %s)" % [Rect2(history_button.position, history_button.size) if history_button != null else Rect2(), game._target_battle_zone(&"history_rail")])
        _expect(pantry_panel != null and Rect2(pantry_panel.position, pantry_panel.size) == game._target_battle_zone(&"pantry"), "Pantry occupies the separated lower-left owner band")
        _expect(game.pantry_ingredient_anchors.size() == 4, "each Pantry ingredient exposes a live flight anchor")
        var pantry_icons: Array[Node] = pantry_panel.find_children("PantryIngredient_*", "TextureRect", false, false) if pantry_panel != null else []
        _expect(pantry_icons.size() == 4, "Pantry renders all four ingredient icons")
        for pantry_icon: TextureRect in pantry_icons:
            var expected_size := Vector2(38, 38) if pantry_icon.name == "PantryIngredient_ember" else Vector2(34, 34)
            _expect(pantry_icon.size == expected_size, "%s overscans its tray aperture without exposing the white backing" % pantry_icon.name)
        var ember_icon := pantry_panel.get_node_or_null("PantryIngredient_ember") as TextureRect if pantry_panel != null else null
        _expect(ember_icon != null and ember_icon.position + ember_icon.size * 0.5 == Vector2(150, 75), "the rightmost Pantry sprite is shifted two pixels northwest")
        _expect(enemy_deck_display != null and Rect2(enemy_deck_display.position, enemy_deck_display.size) == game._target_battle_zone(&"opponent_deck"), "opponent deck occupies the upper-right cradle")
        _expect(player_deck_display != null and int(player_deck_display.get_meta("deck_count", -1)) == game.player_deck.size(), "player deck cradle reflects authoritative deck count")
        var enemy_deck_card_back := enemy_deck_display.find_child("EnemyDeckCardBack", true, false) as TextureRect if enemy_deck_display != null else null
        var player_deck_card_back := player_deck_display.find_child("DeckCardBack", true, false) as TextureRect if player_deck_display != null else null
        var enemy_deck_face_clip := enemy_deck_display.get_node_or_null("EnemyDeckFaceClip") as Control if enemy_deck_display != null else null
        var player_deck_face_clip := player_deck_display.get_node_or_null("DeckFaceClip") as Control if player_deck_display != null else null
        var enemy_deck_cradle := enemy_deck_display.get_node_or_null("EnemyDeckCradle") as TextureRect if enemy_deck_display != null else null
        var player_deck_cradle := player_deck_display.get_node_or_null("PlayerDeckCradle") as TextureRect if player_deck_display != null else null
        var enemy_deck_backdrop := enemy_deck_display.find_child("EnemyDeckApertureBackdrop", true, false) as ColorRect if enemy_deck_display != null else null
        var player_deck_backdrop := player_deck_display.find_child("DeckApertureBackdrop", true, false) as ColorRect if player_deck_display != null else null
        var player_deck_rect: Rect2 = game._target_battle_zone(&"player_deck")
        var player_deck_aperture := Rect2(player_deck_rect.position + game.DECK_CRADLE_APERTURE_RECT.position, game.DECK_CRADLE_APERTURE_RECT.size)
        _expect(game.DECK_CARD_OVERSCAN_RECT == Rect2(23.8, 9.5, 73.4, 124.0), "both card-back stacks use extra left-and-top-biased overscan around their cradle apertures")
        _expect(enemy_deck_card_back != null and enemy_deck_card_back.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "opponent card back scales up to cover its complete cradle aperture")
        _expect(enemy_deck_face_clip != null and Rect2(enemy_deck_face_clip.position, enemy_deck_face_clip.size).encloses(game.DECK_CRADLE_APERTURE_RECT), "opponent top card clips beyond every pale aperture edge")
        _expect(enemy_deck_card_back != null and enemy_deck_face_clip != null and Rect2(enemy_deck_card_back.position, enemy_deck_card_back.size).encloses(Rect2(Vector2.ZERO, enemy_deck_face_clip.size)), "opponent card art overscans its complete face clip")
        _expect(enemy_deck_backdrop != null and enemy_deck_card_back != null and enemy_deck_backdrop.color == Color.BLACK and enemy_deck_backdrop.get_index() < enemy_deck_card_back.get_index(), "opponent deck reveals opaque black beneath any transparent card pixels")
        _expect(player_deck_card_back != null and player_deck_card_back.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "player card back scales up to cover its complete cradle aperture")
        _expect(player_deck_face_clip != null and Rect2(player_deck_face_clip.position, player_deck_face_clip.size).encloses(player_deck_aperture), "player top card clips beyond every pale aperture edge")
        _expect(player_deck_card_back != null and player_deck_face_clip != null and Rect2(player_deck_card_back.position, player_deck_card_back.size).encloses(Rect2(Vector2.ZERO, player_deck_face_clip.size)), "player card art overscans its complete face clip")
        _expect(player_deck_backdrop != null and player_deck_card_back != null and player_deck_backdrop.color == Color.BLACK and player_deck_backdrop.get_index() < player_deck_card_back.get_index(), "player deck reveals opaque black beneath any transparent card pixels")
        _expect(enemy_deck_cradle != null and enemy_deck_face_clip != null and enemy_deck_cradle.get_index() < enemy_deck_face_clip.get_index(), "opponent top card covers the cradle's pale inner edge")
        _expect(player_deck_cradle != null and player_deck_face_clip != null and player_deck_cradle.get_index() < player_deck_face_clip.get_index(), "player top card covers the cradle's pale inner edge")
        _expect(enemy_mana_pool != null and Rect2(enemy_mana_pool.position, enemy_mana_pool.size) == game._target_battle_zone(&"opponent_mana"), "opponent Mana remains associated with the upper owner")
        if enemy_mana_pool != null:
            var enemy_mana_readout := enemy_mana_pool.get_node_or_null("EnemyManaReadoutPlate") as Panel
            var enemy_mana_pips: Array[Node] = enemy_mana_pool.find_children("ResourcePip*", "Panel", false, false)
            _expect(enemy_mana_pips.size() == maxi(1, game.enemy_max_mana), "opponent Mana renders one centered pip per available Mana")
            for enemy_mana_pip: Panel in enemy_mana_pips:
                _expect(enemy_mana_readout != null and enemy_mana_pip.position.y >= enemy_mana_readout.position.y + enemy_mana_readout.size.y, "%s sits below the ENEMY Mana readout" % enemy_mana_pip.name)
                _expect(Rect2(Vector2.ZERO, enemy_mana_pool.size).encloses(Rect2(enemy_mana_pip.position, enemy_mana_pip.size)), "%s remains inside the opponent Mana rack" % enemy_mana_pip.name)
        _expect(player_mana_pool != null and Rect2(player_mana_pool.position, player_mana_pool.size) == game._target_battle_zone(&"player_mana"), "player Mana remains associated with the lower owner")
        _expect(end_turn_button != null and Rect2(end_turn_button.position, end_turn_button.size) == game._target_battle_zone(&"turn_control"), "exactly one End Turn control owns the mid-right commitment rail")
        if turn_marker != null:
            var turn_plate := turn_marker.get_node_or_null("TurnBannerPlate") as Panel
            _expect(turn_plate != null and Rect2(Vector2.ZERO, turn_marker.size).encloses(Rect2(turn_plate.position, turn_plate.size)), "turn text stays on a padded plate inside the ornamental marker")
            var turn_readout := turn_marker.find_child("TurnBannerManaReadout", true, false) as HBoxContainer
            if turn_readout != null:
                _expect(Rect2(Vector2.ZERO, turn_readout.get_parent().size).encloses(Rect2(turn_readout.position, turn_readout.size)) and bool(turn_readout.get_meta("hud_text_fits", false)), "turn Mana composition fits inside its readability plate")
                for child: Control in turn_readout.get_children():
                    _expect(Rect2(Vector2.ZERO, turn_readout.size).encloses(Rect2(child.position, child.size)), "%s remains inside the turn Mana composition" % child.name)
        var history_tickets: Array[Node] = game.screen_layer.find_children("ServiceHistoryTicket_*", "TextureRect", true, false)
        _expect(not history_tickets.is_empty(), "battle HUD renders its available compact history tickets")
        for ticket_index in range(history_tickets.size()):
            var history_ticket := history_tickets[ticket_index] as TextureRect
            _expect(history_ticket.size == Vector2(252, 58.5), "%s is 75%% wider than its prior width" % history_ticket.name)
            _expect((history_ticket as TextureRect).stretch_mode == TextureRect.STRETCH_SCALE, "%s stretches its frame to the requested aspect ratio" % history_ticket.name)
            var event_label := history_ticket.get_node_or_null("ServiceHistoryEvent_%d" % ticket_index) as Label
            var amount_label := history_ticket.get_node_or_null("ServiceHistoryAmount_%d" % ticket_index) as Label
            var rendered_item: Dictionary = game.history_events[game.history_events.size() - 1 - ticket_index]
            var expected_text_color: Color = game.HISTORY_PLAYER_DAMAGE_TEXT if bool(rendered_item.get("highlight_red", false)) else Color.WHITE
            _expect(event_label != null and amount_label != null and event_label.get_theme_color("font_color") == expected_text_color and amount_label.get_theme_color("font_color") == Color.WHITE, "%s highlights player harm in red while keeping its number white" % history_ticket.name)
            var rendered_gap := 0.0
            if event_label != null and amount_label != null:
                var event_line_height := event_label.get_theme_font("font").get_height(event_label.get_theme_font_size("font_size"))
                var amount_line_height := amount_label.get_theme_font("font").get_height(amount_label.get_theme_font_size("font_size"))
                var event_line_bottom := event_label.position.y + event_label.size.y * 0.5 + event_line_height * 0.5
                var amount_line_top := amount_label.position.y + amount_label.size.y * 0.5 - amount_line_height * 0.5
                rendered_gap = amount_line_top - event_line_bottom
            _expect(event_label != null and amount_label != null and is_zero_approx(rendered_gap), "%s removes the gap between its event text and number" % history_ticket.name)
        _expect_fitted_hud_labels(game.screen_layer, "default font")
        _expect(game._target_battle_zone(&"opponent_deck").end.y < game._target_battle_zone(&"turn_control").position.y, "opponent deck scans above End Turn")
        _expect(game._target_battle_zone(&"turn_control").end.y < game._target_battle_zone(&"player_deck").position.y, "End Turn scans above the player deck")
        _expect(game._play_region_screen_rect() == game._target_battle_zone(&"play_region"), "runtime legality consumes the authoritative target play region")
        var playable_unit_uid := -1
        for runtime_card in game.player_hand:
            if String(game.DB.card(runtime_card.id).get("type", "")) == "unit":
                playable_unit_uid = int(runtime_card.uid)
                break
        if playable_unit_uid >= 0:
            game.player_mana = 10
            _expect(game._is_valid_card_drop(playable_unit_uid, game._play_region_screen_rect().get_center()), "authoritative region accepts its center")
            _expect(not game._is_valid_card_drop(playable_unit_uid, Vector2(16, 700)), "authoritative region rejects outside release")
            var insertion_rect: Rect2 = game._card_insertion_preview_rect(playable_unit_uid)
            _expect(insertion_rect.size != Vector2.ZERO and game._target_battle_zone(&"player_row").encloses(insertion_rect), "unit insertion preview comes from the density-aware player row")
            var play_region_in_juice: Rect2 = game._play_region_in_layer(game.juice)
            var insertion_in_juice: Rect2 = game._rect_between_canvas_items(game.screen_layer, game.juice, insertion_rect)
            game.juice.show_drop_zone(play_region_in_juice, true, "RELEASE TO SERVE", insertion_in_juice)
            var overlay := game.juice.get_node_or_null("AuthoritativePlayRegion") as Control
            _expect(overlay != null and Rect2(overlay.position, overlay.size) == play_region_in_juice, "displayed drop zone exactly matches the legality region in Juice space")
            _expect(overlay != null and overlay.get_node_or_null("InsertionPreview") != null, "valid unit drag displays one insertion preview inside that region")
            game.juice.dismiss_drop_zone()
        var first_hand_card: Control = game.card_nodes_by_uid.get(int(game.player_hand[0].uid)) if not game.player_hand.is_empty() else null
        if first_hand_card != null:
            var preview_rect: Rect2 = game._card_preview_screen_rect(first_hand_card)
            _expect(preview_rect == game._target_battle_zone(&"preview"), "card inspection always uses the fixed left-side preview zone")
            _expect(game._target_battle_zone(&"safe_canvas").grow(0.01).encloses(preview_rect), "fixed card inspection stays inside the safe canvas")
            game._show_card_preview(String(first_hand_card.get_meta("card_id", "")), int(first_hand_card.get_meta("servings", 0)), first_hand_card)
            _expect(game.card_preview != null and is_equal_approx(game.card_preview.modulate.a, 1.0), "card inspection is fully opaque")
            _expect(game.card_preview != null and game.card_preview.z_index == game.CARD_PREVIEW_Z_INDEX and not game.card_preview.z_as_relative, "card inspection renders on an absolute foreground layer")
            var preview_style := game.card_preview.get_theme_stylebox("panel") as StyleBoxFlat if game.card_preview != null else null
            _expect(preview_style != null and is_equal_approx(preview_style.bg_color.a, 1.0), "card inspection panel background is fully opaque")
            game._hide_card_preview()
            var focus_style := first_hand_card.get_theme_stylebox("focus") as StyleBoxFlat
            _expect(focus_style != null and focus_style.get_border_width(SIDE_LEFT) == 0 and focus_style.shadow_size > 0 and focus_style.bg_color.r > focus_style.bg_color.b, "keyboard focus uses a subtle golden tint and halo without a conventional outline")

        game.tweaks.set_value(&"ui.font_scale", 0.8, false)
        game.history_events = _representative_history(game)
        game.banner_text = game.t("battle.your_turn_mana", {"mana": game.player_mana})
        game._render_battle()
        await process_frame
        await process_frame
        var damage_event_label := game.screen_layer.find_child("ServiceHistoryEvent_0", true, false) as Label
        var damage_amount_label := game.screen_layer.find_child("ServiceHistoryAmount_0", true, false) as Label
        var ordinary_event_label := game.screen_layer.find_child("ServiceHistoryEvent_1", true, false) as Label
        var ordinary_amount_label := game.screen_layer.find_child("ServiceHistoryAmount_1", true, false) as Label
        var defeated_event_label := game.screen_layer.find_child("ServiceHistoryEvent_2", true, false) as Label
        var defeated_amount_label := game.screen_layer.find_child("ServiceHistoryAmount_2", true, false) as Label
        _expect(damage_event_label != null and damage_amount_label != null and damage_event_label.get_theme_color("font_color") == game.HISTORY_PLAYER_DAMAGE_TEXT and damage_amount_label.get_theme_color("font_color") == Color.WHITE, "player-damage history event renders in bright red while its number remains white")
        _expect(ordinary_event_label != null and ordinary_amount_label != null and ordinary_event_label.get_theme_color("font_color") == Color.WHITE and ordinary_amount_label.get_theme_color("font_color") == Color.WHITE, "non-player-damage history text and number remain white")
        _expect(defeated_event_label != null and defeated_amount_label != null and defeated_event_label.get_theme_color("font_color") == game.HISTORY_PLAYER_DAMAGE_TEXT and defeated_amount_label.get_theme_color("font_color") == Color.WHITE, "defeated player-minion history event renders in bright red while its number remains white")
        _expect_fitted_hud_labels(game.screen_layer, "minimum font")

        game.tweaks.set_value(&"ui.font_scale", 1.25, false)
        game.history_events = _representative_history(game)
        game.banner_text = game.t("battle.your_turn_mana", {"mana": game.player_mana})
        game._render_battle()
        await process_frame
        await process_frame
        var max_font_end_label := game.screen_layer.find_child("EndTurnVisibleLabel", true, false) as Label
        _expect(max_font_end_label != null and max_font_end_label.autowrap_mode == TextServer.AUTOWRAP_OFF and Rect2(Vector2.ZERO, max_font_end_label.get_parent().size).encloses(Rect2(max_font_end_label.position, max_font_end_label.size)), "maximum-font End Turn remains one line inside its generated frame")
        for max_font_vital in game.screen_layer.find_children("Hero*Label", "Label", true, false):
            var fits_station := Rect2(Vector2.ZERO, max_font_vital.get_parent().size).encloses(Rect2(max_font_vital.position, max_font_vital.size))
            _expect(max_font_vital.autowrap_mode == TextServer.AUTOWRAP_OFF and fits_station, "maximum-font hero vital remains inside its status plate")
        _expect_fitted_hud_labels(game.screen_layer, "maximum font")
        _expect(game.screen_layer.find_children("ServiceHistoryEvent_*", "Label", true, false).size() == 4, "maximum-font battle exercises every annotated history ticket")

        game.L10N.set_locale("zh-CN", false)
        game.history_events = _representative_history(game)
        game.banner_text = game.t("battle.your_turn_mana", {"mana": game.player_mana})
        game._render_battle()
        await process_frame
        await process_frame
        _expect_fitted_hud_labels(game.screen_layer, "Simplified Chinese maximum font")

        game.tweaks.set_value(&"ui.font_scale", 0.8, false)
        game._render_battle()
        await process_frame
        await process_frame
        _expect_fitted_hud_labels(game.screen_layer, "Simplified Chinese minimum font")

        game.L10N.set_locale("en", false)
        game.tweaks.set_value(&"ui.font_scale", 1.25, false)
        game.history_events = _representative_history(game)
        game.banner_text = game.t("battle.your_turn_mana", {"mana": game.player_mana})
        var runtime_cases := [
            {"size": Vector2(1280, 720), "insets": Vector4.ZERO, "profile": LAYOUT.PROFILE_STANDARD},
            {"size": Vector2(1920, 1080), "insets": Vector4(24, 16, 24, 16), "profile": LAYOUT.PROFILE_STANDARD},
            {"size": Vector2(2044, 1168), "insets": Vector4.ZERO, "profile": LAYOUT.PROFILE_STANDARD},
            {"size": Vector2(1024, 768), "insets": Vector4(32, 24, 32, 24), "profile": LAYOUT.PROFILE_COMPACT},
            {"size": Vector2(2560, 1080), "insets": Vector4(48, 0, 48, 0), "profile": LAYOUT.PROFILE_STANDARD},
            {"size": Vector2(960, 540), "insets": Vector4(48, 12, 48, 12), "profile": LAYOUT.PROFILE_COMPACT},
            {"size": Vector2(896, 504), "insets": Vector4(44, 8, 44, 8), "profile": LAYOUT.PROFILE_COMPACT},
        ]
        for runtime_case: Dictionary in runtime_cases:
            game._configure_battle_layout(runtime_case.size, runtime_case.insets)
            game._render_battle()
            await process_frame
            await process_frame
            var runtime_safe: Rect2 = game.battle_layout.safe_canvas()
            _expect(game.active_layout_profile == runtime_case.profile, "available safe width selects %s at %s" % [runtime_case.profile, runtime_case.size])
            _expect_near(game.screen_layer.position, runtime_safe.position, 0.01, "authored canvas centers inside safe bounds")
            _expect_near(game.screen_layer.scale * LAYOUT.DESIGN_SIZE, runtime_safe.size, 0.01, "authored canvas scales exactly to the safe rectangle")
            _expect(game.tutorial_callout.safe_bounds == runtime_safe, "tutorial bounds follow the responsive safe rectangle")
            for control_name in ["EnemyHeroStation", "PlayerStatusPanel", "EnemyPassiveButton", "EndTurnButton", "HeroPowerButton", "EnemyDeckDisplay", "PlayerManaPool"]:
                var critical := game.screen_layer.find_child(control_name, true, false) as Control
                var critical_rect: Rect2 = game._control_rect_in_layer(critical, game)
                _expect(critical != null and runtime_safe.grow(0.5).encloses(critical_rect), "%s stays inside safe insets at %s" % [control_name, runtime_case.size])
            for card_control in game.card_nodes_by_uid.values():
                if is_instance_valid(card_control):
                    _expect(runtime_safe.grow(0.5).encloses(game._control_rect_in_layer(card_control, game)), "hand hit target stays inside safe insets at %s" % runtime_case.size)
            for unit_control in game.unit_nodes_by_uid.values():
                if is_instance_valid(unit_control):
                    _expect(runtime_safe.grow(0.5).encloses(game._control_rect_in_layer(unit_control, game)), "permanent hit target stays inside safe insets at %s" % runtime_case.size)
            _expect_fitted_hud_labels(game.screen_layer, "maximum font %s profile at %s" % [runtime_case.profile, runtime_case.size])
        game.tweaks.set_value(&"ui.font_scale", 1.0, false)
        game._configure_battle_layout(Vector2(1280, 720), Vector4.ZERO)
        game._render_battle()
        _expect(game.screen_layer.find_child("OpponentHandDisplay", true, false) == null, "zero-card opponent hand remains completely hidden after rerender")
        game.history_events.clear()
        game._record_juice_history({"kind": "death", "friendly": true, "side": "player"})
        game._record_juice_history({"kind": "death", "friendly": false, "side": "enemy"})
        _expect(game.history_events.size() == 2 and bool(game.history_events[0].get("highlight_red", false)), "player-minion defeat is recorded as a red-highlight history event")
        _expect(game.history_events.size() == 2 and not bool(game.history_events[1].get("highlight_red", false)), "enemy-minion defeat is not recorded as player harm")
        game.enemy_hand.append(game._make_runtime_card("coal_squire"))
        game._render_battle()
        await process_frame
        await process_frame
        var populated_opponent_hand := game.screen_layer.find_child("OpponentHandDisplay", true, false) as Control
        var populated_enemy_station := game.screen_layer.find_child("EnemyHeroStation", true, false) as Control
        var populated_enemy_name_plate := populated_enemy_station.get_node_or_null("HeroNamePlate") as Panel if populated_enemy_station != null else null
        _expect(populated_opponent_hand != null and bool(populated_opponent_hand.get_meta("concealed", false)) and int(populated_opponent_hand.get_meta("hand_count", -1)) == 1, "non-empty opponent hand renders its concealed card and count")
        _expect(populated_opponent_hand != null and Rect2(populated_opponent_hand.position, populated_opponent_hand.size) == game._target_battle_zone(&"opponent_hand"), "non-empty opponent hand is anchored to the top-edge peek strip")
        if populated_opponent_hand != null and populated_enemy_station != null and populated_enemy_name_plate != null:
            var populated_hand_rect := Rect2(populated_opponent_hand.position, populated_opponent_hand.size)
            var populated_name_rect := Rect2(populated_enemy_station.position + populated_enemy_name_plate.position, populated_enemy_name_plate.size)
            _expect(not populated_hand_rect.intersects(populated_name_rect), "opponent hand peek strip clears the enemy nameplate")
            _expect(populated_enemy_station.z_index > populated_opponent_hand.z_index, "opponent nameplate renders above the concealed hand")
            for card_back: TextureRect in populated_opponent_hand.find_children("ConcealedCardBack*", "TextureRect", false, false):
                var visible_card_height := card_back.position.y + card_back.size.y
                _expect(visible_card_height <= card_back.size.y * 0.5 + 0.01, "%s exposes no more than half its height" % card_back.name)
        game.queue_free()

    await create_timer(0.15).timeout
    await process_frame
    if failures.is_empty():
        print("[BATTLE_LAYOUT_PASS] semantic safe-canvas zones and cross-layer transforms validated")
        quit(0)
    else:
        push_error("[BATTLE_LAYOUT_FAIL] %d assertions failed" % failures.size())
        quit(1)
