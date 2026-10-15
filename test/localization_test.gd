extends SceneTree

const DB := preload("res://scripts/card_database.gd")
const L10N := preload("res://scripts/localization.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error("[LOCALIZATION_FAIL] " + message)


func _find_named_button(node: Node, button_name: StringName) -> Button:
    if node is Button and node.name == button_name:
        return node as Button
    for child: Node in node.get_children():
        var match := _find_named_button(child, button_name)
        if match != null:
            return match
    return null


func _has_control_text(node: Node, expected: String) -> bool:
    if node is Label and (node as Label).text == expected:
        return true
    if node is Button and (node as Button).text == expected:
        return true
    for child: Node in node.get_children():
        if _has_control_text(child, expected):
            return true
    return false


func _assert_tuning_keys(game: Node) -> void:
    for descriptor: Dictionary in game.tweaks._catalog:
        var identifier := String(descriptor.id)
        for suffix: String in ["label", "description"]:
            var key := "tuning.parameter.%s.%s" % [identifier, suffix]
            _expect(L10N.t(key) != key, "tuning %s resolves" % key)
        var category_key := "tuning.category.%s" % String(descriptor.category).to_lower()
        _expect(L10N.t(category_key) != category_key, "tuning category %s resolves" % category_key)
        var mode_key := "tuning.mode.%s" % String(descriptor.mode).to_lower().replace(" ", "_")
        _expect(L10N.t(mode_key) != mode_key, "tuning mode %s resolves" % mode_key)
        var unit := String(descriptor.get("unit", ""))
        if not unit.is_empty() and unit not in ["×", "dB", "+/ +"]:
            var unit_key := "tuning.unit.%s" % unit.to_lower()
            _expect(L10N.t(unit_key) != unit_key, "tuning unit %s resolves" % unit_key)


func _assert_database_keys() -> void:
    for definition: Dictionary in DB.CARDS.values():
        for field: String in ["name_key", "text_key"]:
            var key := String(definition[field])
            _expect(L10N.t(key) != key, "card %s resolves" % key)
    for definition: Dictionary in DB.RECIPES.values():
        for field: String in ["name_key", "summary_key"]:
            var key := String(definition[field])
            _expect(L10N.t(key) != key, "recipe %s resolves" % key)
    for definition: Dictionary in DB.ENCOUNTERS.values():
        for field: String in ["name_key", "subtitle_key", "passive_key"]:
            var key := String(definition[field])
            _expect(L10N.t(key) != key, "encounter %s resolves" % key)


func _assert_chinese_glyph_coverage() -> void:
    var file := FileAccess.open("res://localization/zh-CN.json", FileAccess.READ)
    _expect(file != null, "Chinese catalog can be read for glyph validation")
    if file == null:
        return
    var catalog: Variant = JSON.parse_string(file.get_as_text())
    _expect(catalog is Dictionary, "Chinese catalog is a JSON object")
    if not catalog is Dictionary:
        return
    var font := load(L10N.UI_FONT_PATH) as Font
    _expect(font != null, "Figtree UI font and its Noto Sans SC fallback load")
    if font == null:
        return
    var missing := PackedInt32Array()
    for value: Variant in (catalog as Dictionary).values():
        var localized_text := String(value)
        for index in range(localized_text.length()):
            var codepoint := localized_text.unicode_at(index)
            if codepoint > 31 and not font.has_char(codepoint) and not missing.has(codepoint):
                missing.append(codepoint)
    _expect(missing.is_empty(), "UI font chain contains every Chinese catalog glyph; missing codepoints: %s" % str(missing))


func _assert_card_descriptions_fit(game: Node) -> void:
    var uid := 9100
    for locale: String in L10N.SUPPORTED_LOCALES:
        L10N.set_locale(locale)
        for card_id: String in DB.CARDS:
            var card := game._card_button({"id": card_id, "uid": uid, "servings": 2}, 0, 126.0, 190.0, true, true) as Button
            uid += 1
            game.add_child(card)
            await process_frame
            var description := card.get_node_or_null("CardDescription") as Label
            _expect(
                description != null and description.get_line_count() <= description.max_lines_visible,
                "%s card description fits without truncation in %s" % [card_id, locale]
            )
            card.free()
    L10N.set_locale("en")


func _run() -> void:
    _expect(L10N.validate_catalogs().is_empty(), "English and Chinese catalogs have matching keys and placeholders")
    _expect(L10N.catalog_keys("en").size() >= 500, "catalog covers all game and tuning copy")
    _assert_chinese_glyph_coverage()
    _expect(ThemeDB.fallback_font.get_font_name().begins_with("Figtree"), "project-wide primary font is Figtree")
    var primary := load("res://assets/template/fonts/ui_regular.tres") as FontVariation
    _expect(primary.base_font.resource_path.ends_with("Figtree-VF.subset.woff2"), "approved Figtree body face")
    _expect(primary.fallbacks.size() == 1 and primary.fallbacks[0].has_char("厨".unicode_at(0)), "Figtree falls back to Noto Sans SC for Chinese")
    for system_locale: String in ["zh", "zh_CN", "zh-CN", "zh-Hans-CN", "zh_TW", "ZH-hk"]:
        _expect(L10N.locale_for_system(system_locale) == "zh-CN", "system locale %s selects Simplified Chinese" % system_locale)
    for system_locale: String in ["en", "en_US", "fr-FR", "ja_JP", ""]:
        _expect(L10N.locale_for_system(system_locale) == "en", "system locale '%s' selects English" % system_locale)
    _expect(ThemeDB.fallback_font.has_char("厨".unicode_at(0)), "project-wide default font contains Chinese glyphs")
    L10N.set_locale("en")
    _expect(L10N.t("battle.health", {"current": 7, "maximum": 12}) == "7 / 12 HEALTH", "English dictionary placeholders render")
    _expect(L10N.t("settings.acceleration", "2×").contains("2×"), "scalar t(key, placeholder_value) renders {value}")
    _assert_database_keys()

    L10N.set_locale("zh-CN")
    _expect(L10N.t("title.start") == "开始游戏", "Chinese title translation loads")
    _expect(L10N.t("battle.health", {"current": 7, "maximum": 12}) == "7 / 12 生命", "Chinese placeholders render")
    _expect(L10N.t("battle.mana_pool") == "法力池", "Mana Pool heading has a Simplified Chinese translation")
    _expect(load(L10N.UI_FONT_PATH) is Font, "localized UI font chain loads")
    _assert_database_keys()

    L10N.set_locale("en")
    var packed_scene := load("res://scenes/card_game.tscn") as PackedScene
    _expect(packed_scene != null, "card game scene loads")
    if packed_scene != null:
        var game := packed_scene.instantiate()
        root.add_child(game)
        await process_frame
        _assert_tuning_keys(game)


        var card := game._card_button({"id": "coal_squire", "uid": 9001, "servings": 0}, 0, 138.0, 164.0, true) as Button
        var description := card.get_node_or_null("CardDescription") as Label
        _expect(description != null, "cards expose a dedicated description label")
        if description != null:
            _expect(description.max_lines_visible == 2 and description.clip_text, "card descriptions are clipped to two visible lines")
        var stats := card.get_node_or_null("CardStats") as HBoxContainer
        _expect(stats != null, "unit cards expose a symbolic stat footer")
        if stats != null:
            _expect(stats.get_node_or_null("AttackIcon") is TextureRect, "unit-card Attack uses the sword icon")
            _expect(stats.get_node_or_null("HealthIcon") is TextureRect, "unit-card Health uses the shield icon")
        _expect(not _has_control_text(card, L10N.t("card.stats", {"attack": 1, "health": 2})), "unit-card footer does not spell out Attack or Health")
        card.free()

        game._show_card_preview("coal_squire", 0)
        var preview_description := game.card_preview.get_node_or_null("CardDescription") as Label
        _expect(preview_description != null and preview_description.max_lines_visible == 2, "card previews keep descriptions within two lines")
        _expect(game.card_preview.get_node_or_null("CardStats/AttackIcon") is TextureRect, "card previews reuse the sword icon")
        _expect(game.card_preview.get_node_or_null("CardStats/HealthIcon") is TextureRect, "card previews reuse the shield icon")
        game._hide_card_preview()

        await _assert_card_descriptions_fit(game)

        var toggle := _find_named_button(game, &"LanguageToggle")
        _expect(toggle != null, "title exposes the EN/CN toggle")
        if toggle != null:
            var toggle_font := toggle.get_theme_font(&"font")
            _expect(toggle_font.get_font_name().begins_with("Figtree"), "mixed-language toggle uses Figtree in English mode")
            _expect(toggle_font.has_char("中".unicode_at(0)), "mixed-language toggle retains Chinese fallback in English mode")
            toggle.pressed.emit()
            await process_frame
            _expect(L10N.current_locale() == "zh-CN", "title toggle changes the locale")
            _expect(_has_control_text(game.screen_layer, "开始游戏"), "title rerenders with Chinese copy")
        game.queue_free()
        await create_timer(0.15).timeout
        await process_frame

    L10N.set_locale("en")
    if failures.is_empty():
        print("[LOCALIZATION_PASS] %d catalog keys validated in English and Simplified Chinese." % L10N.catalog_keys("en").size())
        quit(0)
    else:
        print("[LOCALIZATION_FAIL] %d checks failed." % failures.size())
        quit(1)
