extends SceneTree

const DB := preload("res://scripts/card_database.gd")

const EXPECTED := {
    "hud_hero_station_frame": {"path": "res://assets/template/cardgame/layout/hero_station_frame.png", "size": Vector2i(512, 252)},
    "hud_unit_plate_frame": {"path": "res://assets/template/cardgame/layout/unit_plate_frame.png", "size": Vector2i(264, 264)},
    "hud_passive_medallion_frame": {"path": "res://assets/template/cardgame/layout/passive_medallion_frame.png", "size": Vector2i(128, 128)},
    "hud_turn_marker": {"path": "res://assets/template/cardgame/layout/turn_marker.png", "size": Vector2i(440, 76)},
    "hud_end_turn_frame": {"path": "res://assets/template/cardgame/layout/end_turn_frame.png", "size": Vector2i(256, 176)},
    "hud_history_ticket_frame": {"path": "res://assets/template/cardgame/layout/history_ticket_frame.png", "size": Vector2i(144, 116)},
    "hud_pantry_tray_frame": {"path": "res://assets/template/cardgame/layout/pantry_tray_frame.png", "size": Vector2i(384, 280)},
    "hud_mana_rack_frame": {"path": "res://assets/template/cardgame/layout/mana_rack_frame.png", "size": Vector2i(300, 144)},
    "hud_deck_cradle": {"path": "res://assets/template/cardgame/layout/deck_cradle.png", "size": Vector2i(256, 288)},
}

const TRANSPARENT_APERTURES := {
    "hud_hero_station_frame": [Vector2i(256, 119)],
    "hud_unit_plate_frame": [Vector2i(132, 123)],
    "hud_history_ticket_frame": [Vector2i(72, 64)],
    "hud_pantry_tray_frame": [Vector2i(82, 154), Vector2i(156, 154), Vector2i(229, 154), Vector2i(303, 154)],
    "hud_mana_rack_frame": [Vector2i(77, 82), Vector2i(169, 82)],
    "hud_deck_cradle": [Vector2i(129, 150)],
}

const CLEARED_NEUTRAL_WHITE_PROBES := {
    "hud_hero_station_frame": [Vector2i(256, 41)],
    "hud_unit_plate_frame": [Vector2i(133, 197), Vector2i(180, 179)],
    "hud_passive_medallion_frame": [Vector2i(34, 64), Vector2i(64, 64), Vector2i(93, 64)],
    "hud_history_ticket_frame": [Vector2i(60, 93), Vector2i(80, 93)],
    "hud_pantry_tray_frame": [Vector2i(82, 127), Vector2i(82, 193), Vector2i(156, 193), Vector2i(229, 193), Vector2i(303, 193)],
    "hud_mana_rack_frame": [Vector2i(150, 54), Vector2i(105, 112), Vector2i(230, 116)],
    "hud_deck_cradle": [Vector2i(100, 55), Vector2i(180, 58)],
}

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error("[LAYOUT_ASSET_FAIL] " + message)


func _run() -> void:
    for asset_id: String in EXPECTED:
        var expected: Dictionary = EXPECTED[asset_id]
        var texture := DB.art(asset_id)
        _expect(texture != null, "%s is registered" % asset_id)
        if texture != null:
            _expect(Vector2i(texture.get_size()) == expected.size, "%s has the intended runtime dimensions" % asset_id)
        var image := Image.load_from_file(ProjectSettings.globalize_path(String(expected.path)))
        _expect(not image.is_empty(), "%s has readable source pixels" % asset_id)
        _expect(image.detect_alpha() != Image.ALPHA_NONE, "%s preserves transparent alpha" % asset_id)
        var transparent_rgb_is_clear := true
        for y in range(image.get_height()):
            for x in range(image.get_width()):
                var pixel := image.get_pixel(x, y)
                if pixel.a < 0.03 and maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.01:
                    transparent_rgb_is_clear = false
                    break
            if not transparent_rgb_is_clear:
                break
        _expect(transparent_rgb_is_clear, "%s zeros hidden RGB in transparent pixels to prevent filtered fringes" % asset_id)
        for sample: Vector2i in TRANSPARENT_APERTURES.get(asset_id, []):
            _expect(image.get_pixelv(sample).a < 0.05, "%s aperture at %s is truly transparent" % [asset_id, sample])
        for sample: Vector2i in CLEARED_NEUTRAL_WHITE_PROBES.get(asset_id, []):
            var cleared_pixel := image.get_pixelv(sample)
            _expect(cleared_pixel.a < 0.03 and maxf(cleared_pixel.r, maxf(cleared_pixel.g, cleared_pixel.b)) <= 0.01, "%s removes neutral-white artifact at %s" % [asset_id, sample])

    if failures.is_empty():
        print("[LAYOUT_ASSET_PASS] nine GPT Image 2 HUD assets are registered, dimensioned, and transparent")
        quit(0)
    else:
        push_error("[LAYOUT_ASSET_FAIL] %d assertions failed" % failures.size())
        quit(1)
