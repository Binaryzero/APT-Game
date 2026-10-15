class_name EmberpanRuntimeTweakControls
extends Node
signal value_changed(identifier: StringName, value: Variant)
const CATEGORY_ORDER := [&"UI", &"GAMEPLAY", &"AUDIO", &"PLAYER", &"ENEMIES", &"ENVIRONMENT"]
var _catalog: Array[Dictionary] = []
var _descriptors := {}
var _values := {}
var _active_values := {}
func _ready() -> void:
    _build_catalog()
    _apply_audio_bus_values()

func get_value(identifier: StringName, fallback: Variant = null) -> Variant:
    return _values.get(identifier, fallback)


func get_float(identifier: StringName, fallback := 0.0) -> float:
    return float(get_value(identifier, fallback))


func get_int(identifier: StringName, fallback := 0) -> int:
    return int(get_value(identifier, fallback))


func get_bool(identifier: StringName, fallback := false) -> bool:
    return bool(get_value(identifier, fallback))


func get_color(identifier: StringName, fallback := Color.WHITE) -> Color:
    return Color.from_string(String(get_value(identifier, fallback.to_html(false))), fallback)


func descriptor_count() -> int:
    return _catalog.size()


func category_names() -> Array[StringName]:
    return CATEGORY_ORDER.duplicate()


func values_for_mode(mode: String) -> Dictionary:
    var result := {}
    for descriptor: Dictionary in _catalog:
        if descriptor.mode == mode:
            result[descriptor.id] = _values[descriptor.id]
    return result


func is_rank_affecting(identifier: StringName) -> bool:
    var descriptor: Dictionary = _descriptors.get(identifier, {})
    return not descriptor.is_empty() and descriptor.category in [&"GAMEPLAY", &"PLAYER", &"ENEMIES"]


func has_rank_affecting_changes() -> bool:
    for descriptor: Dictionary in _catalog:
        if descriptor.category in [&"GAMEPLAY", &"PLAYER", &"ENEMIES"] and not _values_equal(descriptor, _values[descriptor.id], descriptor.default):
            return true
    return false


func _build_catalog() -> void:
    _catalog = [
        _number("ui.hud_scale", "UI", 1.0, 0.8, 1.2, 0.05, "×", "LIVE"),
        _color("ui.hud_tint", "UI", "#ffffff", "LIVE"),
        _number("ui.font_scale", "UI", 1.0, 0.8, 1.25, 0.05, "×", "LIVE"),
        _number("ui.panel_opacity", "UI", 0.75, 0.5, 1.0, 0.05, "", "LIVE"),
        _number("ui.corner_radius_scale", "UI", 1.0, 0.4, 1.8, 0.1, "×", "LIVE"),
        _number("ui.hover_lift_scale", "UI", 1.0, 0.0, 2.0, 0.1, "×", "LIVE"),
        _number("ui.card_preview_scale", "UI", 1.0, 0.7, 1.3, 0.05, "×", "LIVE"),
        _boolean("ui.show_damage_predictions", "UI", true, "LIVE"),
        _number("ui.combat_log_entries", "UI", 5, 2, 9, 1, "lines", "LIVE", "int"),

        _number("gameplay.max_board_slots", "GAMEPLAY", 4, 2, 6, 1, "slots", "NEXT BATTLE", "int"),
        _number("gameplay.max_hand_size", "GAMEPLAY", 8, 4, 10, 1, "cards", "LIVE", "int"),
        _number("gameplay.max_mana", "GAMEPLAY", 8, 3, 12, 1, "Mana", "NEXT TURN", "int"),
        _number("gameplay.opening_hand_size", "GAMEPLAY", 5, 3, 8, 1, "cards", "NEXT BATTLE", "int"),
        _number("gameplay.draw_per_turn", "GAMEPLAY", 1, 0, 3, 1, "cards", "NEXT TURN", "int"),
        _number("gameplay.fatigue_base_damage", "GAMEPLAY", 1, 0, 6, 1, "damage", "NEXT DRAW", "int"),
        _number("gameplay.kitchen_heal", "GAMEPLAY", 2, 0, 12, 1, "Health", "NEXT BREAK", "int"),
        _number("gameplay.reward_choices", "GAMEPLAY", 3, 1, 3, 1, "cards", "NEXT BREAK", "int"),
        _number("gameplay.recipe_cost_multiplier", "GAMEPLAY", 1.0, 0.5, 2.0, 0.25, "×", "LIVE"),
        _number("gameplay.precise_cut_tolerance", "GAMEPLAY", 0, 0, 4, 1, "damage", "NEXT ATTACK", "int"),
        _number("gameplay.turn_delay_scale", "GAMEPLAY", 1.0, 0.0, 2.0, 0.1, "×", "NEXT WAIT"),
        _boolean("gameplay.guard_enabled", "GAMEPLAY", true, "LIVE"),

        _boolean("audio.muted", "AUDIO", false, "LIVE"),
        _number("audio.master_db", "AUDIO", -3.0, -30.0, 6.0, 1.0, "dB", "LIVE"),
        _number("audio.ui_db", "AUDIO", -2.0, -30.0, 6.0, 1.0, "dB", "LIVE"),
        _number("audio.cards_db", "AUDIO", -1.0, -30.0, 6.0, 1.0, "dB", "LIVE"),
        _number("audio.combat_db", "AUDIO", 0.0, -30.0, 6.0, 1.0, "dB", "LIVE"),
        _number("audio.ambience_db", "AUDIO", -8.0, -30.0, 6.0, 1.0, "dB", "LIVE"),
        _number("audio.music_db", "AUDIO", -5.0, -30.0, 6.0, 1.0, "dB", "LIVE"),
        _number("audio.voice_db", "AUDIO", -4.0, -30.0, 6.0, 1.0, "dB", "LIVE"),
        _number("audio.pitch_scale", "AUDIO", 1.0, 0.5, 1.5, 0.05, "×", "LIVE"),
        _boolean("audio.hover_sounds", "AUDIO", true, "LIVE"),

        _number("player.starting_health", "PLAYER", 28, 10, 60, 1, "Health", "NEXT RUN", "int"),
        _number("player.unit_attack_multiplier", "PLAYER", 1.0, 0.5, 2.5, 0.1, "×", "NEXT SUMMON"),
        _number("player.unit_health_multiplier", "PLAYER", 1.0, 0.5, 2.5, 0.1, "×", "NEXT SUMMON"),
        _number("player.outgoing_damage_multiplier", "PLAYER", 1.0, 0.25, 3.0, 0.05, "×", "NEXT ATTACK"),
        _number("player.healing_multiplier", "PLAYER", 1.0, 0.0, 3.0, 0.1, "×", "NEXT HEAL"),
        _number("player.armor_gain_multiplier", "PLAYER", 1.0, 0.0, 3.0, 0.1, "×", "NEXT GAIN"),
        _number("player.hero_power_cost", "PLAYER", 2, 0, 6, 1, "Mana", "NEXT USE", "int"),
        _number("player.hero_power_armor", "PLAYER", 2, 0, 12, 1, "Armor", "NEXT USE", "int"),
        _number("player.hero_power_attack_bonus", "PLAYER", 1, 0, 6, 1, "Attack", "NEXT USE", "int"),

        _number("enemy.hero_health_multiplier", "ENEMIES", 1.0, 0.25, 3.0, 0.05, "×", "NEXT BATTLE"),
        _number("enemy.unit_attack_multiplier", "ENEMIES", 1.0, 0.25, 3.0, 0.05, "×", "NEXT SUMMON"),
        _number("enemy.unit_health_multiplier", "ENEMIES", 1.0, 0.25, 3.0, 0.05, "×", "NEXT SUMMON"),
        _number("enemy.outgoing_damage_multiplier", "ENEMIES", 1.0, 0.0, 3.0, 0.05, "×", "NEXT ATTACK"),
        _number("enemy.incoming_damage_multiplier", "ENEMIES", 1.0, 0.25, 3.0, 0.05, "×", "NEXT ATTACK"),
        _number("enemy.mana_per_turn", "ENEMIES", 1, 0, 4, 1, "Mana", "NEXT TURN", "int"),
        _number("enemy.cards_per_turn", "ENEMIES", 3, 0, 6, 1, "cards", "NEXT TURN", "int"),
        _number("enemy.starting_units", "ENEMIES", 1, 0, 3, 1, "units", "NEXT BATTLE", "int"),
        _number("enemy.passive_strength_multiplier", "ENEMIES", 1.0, 0.0, 4.0, 0.25, "×", "NEXT TRIGGER"),
        _number("enemy.enrage_threshold", "ENEMIES", 0.5, 0.1, 0.9, 0.05, "ratio", "NEXT BATTLE"),
        _number("enemy.enrage_stat_bonus", "ENEMIES", 1, 0, 6, 1, "+/ +", "NEXT ENRAGE", "int"),

        _number("environment.background_brightness", "ENVIRONMENT", 1.0, 0.35, 1.5, 0.05, "×", "LIVE"),
        _color("environment.background_tint", "ENVIRONMENT", "#ffffff", "LIVE"),
        _number("environment.overlay_opacity_scale", "ENVIRONMENT", 1.0, 0.0, 1.8, 0.05, "×", "LIVE"),
        _boolean("environment.ambient_particles", "ENVIRONMENT", true, "LIVE"),
        _number("environment.ambient_density", "ENVIRONMENT", 1.0, 0.25, 3.0, 0.05, "×", "LIVE"),
        _number("environment.ambient_speed", "ENVIRONMENT", 1.0, 0.25, 3.0, 0.05, "×", "LIVE"),
        _number("environment.particle_count", "ENVIRONMENT", 1.0, 0.0, 2.5, 0.05, "×", "LIVE"),
        _number("environment.particle_radius", "ENVIRONMENT", 1.0, 0.25, 2.0, 0.05, "×", "LIVE"),
        _number("environment.screen_flash", "ENVIRONMENT", 1.0, 0.0, 2.0, 0.05, "×", "LIVE"),
        _number("environment.screen_shake", "ENVIRONMENT", 1.0, 0.0, 2.0, 0.05, "×", "LIVE"),
    ]
    _descriptors.clear()
    for descriptor: Dictionary in _catalog:
        _descriptors[descriptor.id] = descriptor
        _values[descriptor.id] = descriptor.default
        _active_values[descriptor.id] = descriptor.default


func _number(identifier: String, category: String, default_value: Variant, minimum: float, maximum: float, step: float, unit: String, mode: String, value_type := "float") -> Dictionary:
    return {
        "id": StringName(identifier), "category": StringName(category),
        "default": default_value, "min": minimum,
        "max": maximum, "step": step, "unit": unit, "mode": mode, "type": value_type,
    }


func _boolean(identifier: String, category: String, default_value: bool, mode: String) -> Dictionary:
    return {
        "id": StringName(identifier), "category": StringName(category),
        "default": default_value, "mode": mode, "type": "bool",
    }


func _color(identifier: String, category: String, default_value: String, mode: String) -> Dictionary:
    return {
        "id": StringName(identifier), "category": StringName(category),
        "default": default_value, "mode": mode, "type": "color",
    }


func _normalize(descriptor: Dictionary, candidate: Variant) -> Variant:
    match String(descriptor.type):
        "bool":
            if candidate is bool:
                return candidate
        "color":
            if candidate is Color:
                var color_candidate: Color = candidate
                return "#" + color_candidate.to_html(false).to_lower()
            if candidate is String and Color.html_is_valid(candidate):
                var parsed := Color.from_string(candidate, Color.WHITE)
                return "#" + parsed.to_html(false).to_lower()
        "int", "float":
            if (candidate is int or candidate is float) and is_finite(float(candidate)):
                var number := clampf(float(candidate), float(descriptor.min), float(descriptor.max))
                var step: float = float(descriptor.step)
                if step > 0.0:
                    number = float(descriptor.min) + round((number - float(descriptor.min)) / step) * step
                if descriptor.type == "int":
                    return roundi(number)
                return snappedf(number, step) if step > 0.0 else number
    return null


func _values_equal(descriptor: Dictionary, first: Variant, second: Variant) -> bool:
    if descriptor.type == "float":
        return is_equal_approx(float(first), float(second))
    return first == second


func _apply_audio_bus_values() -> void:
    if _catalog.is_empty():
        return
    for pair: Array in [
        [&"Master", &"audio.master_db"], [&"UI", &"audio.ui_db"],
        [&"Cards", &"audio.cards_db"], [&"Combat", &"audio.combat_db"],
        [&"Ambience", &"audio.ambience_db"], [&"Music", &"audio.music_db"],
        [&"Voice", &"audio.voice_db"],
    ]:
        var index := AudioServer.get_bus_index(pair[0])
        if index >= 0:
            AudioServer.set_bus_volume_db(index, get_float(pair[1]))



func apply_preview_patch(patch: Dictionary) -> bool:
    var checked := {}
    for id: String in patch:
        var entry: Dictionary = _descriptors.get(StringName(id),{})
        if entry.is_empty(): return false
        var next: Variant = _normalize(entry,patch[id])
        if next == null: return false
        checked[StringName(id)] = next
    var changed: Array[StringName] = []
    for id: StringName in checked:
        if _values_equal(_descriptors[id],_values[id],checked[id]): continue
        _values[id] = checked[id]
        if _descriptors[id].mode == "LIVE": _active_values[id] = checked[id]
        changed.append(id)
    if not changed.is_empty(): _apply_audio_bus_values()
    for id: StringName in changed: value_changed.emit(id,_values[id])
    return true

func set_value(identifier: StringName, candidate: Variant, _persist := true) -> bool:
    return apply_preview_patch({String(identifier):candidate})

func reset_parameter(identifier: StringName) -> void:
    if _descriptors.has(identifier): set_value(identifier, _descriptors[identifier].default)

func reset_all() -> void:
    var patch := {}
    for entry: Dictionary in _catalog: patch[String(entry.id)] = entry.default
    apply_preview_patch(patch)

# Requested values are editor intent. Only real consumers advance deferred values.
func active_value(identifier: StringName, fallback: Variant = null) -> Variant:
    return _active_values.get(identifier, fallback)

func record_consumed(identifier: StringName, value: Variant) -> void:
    if _descriptors.has(identifier): _active_values[identifier] = value
