class_name EmberpanBattleLayout
extends RefCounted

const DESIGN_SIZE := Vector2(1280.0, 720.0)
const DESIGN_ASPECT := 16.0 / 9.0
const PROFILE_STANDARD := &"standard"
const PROFILE_COMPACT := &"compact"

const TARGET_REFERENCE_RECTS := {
    &"safe_canvas": Rect2(0, 0, 1280, 720),
    &"opponent_hand": Rect2(435, 0, 410, 40),
    &"opponent_station": Rect2(512, 42, 256, 124),
    &"opponent_row": Rect2(242, 170, 807, 132),
    &"combat_corridor": Rect2(220, 310, 855, 58),
    &"player_row": Rect2(242, 354, 807, 108),
    &"player_station": Rect2(512, 490, 256, 124),
    &"player_hand": Rect2(220, 583, 840, 133),
    &"history_rail": Rect2(6, 137, 153, 382),
    &"pantry": Rect2(13, 536, 192, 140),
    &"opponent_deck": Rect2(1139, 100, 128, 115),
    &"turn_control": Rect2(1123, 299, 144, 97),
    &"player_deck": Rect2(1139, 439, 128, 144),
    &"player_mana": Rect2(1088, 606, 173, 94),
    &"opponent_mana": Rect2(973, 76, 166, 72),
    &"hero_power": Rect2(740, 514, 108, 72),
    &"passive": Rect2(784, 67, 70, 70),
    &"banner": Rect2(1080, 263, 187, 32),
    &"play_region": Rect2(205, 150, 870, 390),
    &"preview": Rect2(170, 176, 246, 350),
    &"modal": Rect2(154, 54, 972, 612),
}

const COMPACT_REFERENCE_RECTS := {
    &"safe_canvas": Rect2(0, 0, 1280, 720),
    &"opponent_hand": Rect2(445, 0, 390, 40),
    &"opponent_station": Rect2(512, 42, 256, 124),
    &"opponent_row": Rect2(218, 170, 844, 132),
    &"combat_corridor": Rect2(204, 310, 872, 58),
    &"player_row": Rect2(218, 354, 844, 108),
    &"player_station": Rect2(512, 490, 256, 124),
    &"player_hand": Rect2(204, 583, 872, 133),
    &"history_rail": Rect2(4, 145, 114, 366),
    &"pantry": Rect2(8, 538, 190, 138),
    &"opponent_deck": Rect2(1146, 102, 120, 112),
    &"turn_control": Rect2(1122, 299, 144, 97),
    &"player_deck": Rect2(1146, 439, 120, 144),
    &"player_mana": Rect2(1092, 606, 169, 94),
    &"opponent_mana": Rect2(980, 78, 158, 70),
    &"hero_power": Rect2(740, 514, 104, 72),
    &"passive": Rect2(784, 67, 70, 70),
    &"banner": Rect2(1086, 263, 180, 32),
    &"play_region": Rect2(198, 150, 884, 390),
    &"preview": Rect2(126, 190, 220, 322),
    &"modal": Rect2(32, 36, 1216, 648),
}

var viewport_size := DESIGN_SIZE
var safe_insets := Vector4.ZERO
var profile: StringName = PROFILE_STANDARD
var _safe_canvas := Rect2(Vector2.ZERO, DESIGN_SIZE)


func configure(new_viewport_size := DESIGN_SIZE, new_safe_insets := Vector4.ZERO, new_profile: StringName = PROFILE_STANDARD) -> void:
    viewport_size = Vector2(maxf(1.0, new_viewport_size.x), maxf(1.0, new_viewport_size.y))
    safe_insets = Vector4(
        maxf(0.0, new_safe_insets.x),
        maxf(0.0, new_safe_insets.y),
        maxf(0.0, new_safe_insets.z),
        maxf(0.0, new_safe_insets.w)
    )
    profile = new_profile if new_profile in [PROFILE_STANDARD, PROFILE_COMPACT] else PROFILE_STANDARD
    _safe_canvas = _calculate_safe_canvas()


func safe_canvas() -> Rect2:
    return _safe_canvas


func zone(identifier: StringName) -> Rect2:
    return zone_for_profile(identifier, profile)


func zone_for_profile(identifier: StringName, selected_profile: StringName) -> Rect2:
    return from_reference(reference_zone_for_profile(identifier, selected_profile))


func reference_zone_for_profile(identifier: StringName, selected_profile: StringName) -> Rect2:
    var reference: Dictionary = COMPACT_REFERENCE_RECTS if selected_profile == PROFILE_COMPACT else TARGET_REFERENCE_RECTS
    return reference.get(identifier, Rect2())


func from_reference(reference_rect: Rect2) -> Rect2:
    var scale := Vector2(_safe_canvas.size.x / DESIGN_SIZE.x, _safe_canvas.size.y / DESIGN_SIZE.y)
    return Rect2(_safe_canvas.position + reference_rect.position * scale, reference_rect.size * scale)


func to_reference(runtime_rect: Rect2) -> Rect2:
    var scale := Vector2(DESIGN_SIZE.x / _safe_canvas.size.x, DESIGN_SIZE.y / _safe_canvas.size.y)
    return Rect2((runtime_rect.position - _safe_canvas.position) * scale, runtime_rect.size * scale)


func point_from_reference(reference_point: Vector2) -> Vector2:
    var scale := Vector2(_safe_canvas.size.x / DESIGN_SIZE.x, _safe_canvas.size.y / DESIGN_SIZE.y)
    return _safe_canvas.position + reference_point * scale


func contains_zone(identifier: StringName, grow_tolerance := 0.5) -> bool:
    return _safe_canvas.grow(grow_tolerance).encloses(zone(identifier))


func target_zone_names() -> Array[StringName]:
    return [
        &"opponent_hand", &"opponent_station", &"opponent_row", &"combat_corridor",
        &"player_row", &"player_station", &"player_hand", &"history_rail", &"pantry",
        &"opponent_deck", &"turn_control", &"player_deck", &"player_mana", &"opponent_mana",
        &"hero_power", &"passive", &"banner",
        &"play_region", &"preview", &"modal",
    ]


func choose_profile_for_safe_width() -> StringName:
    return PROFILE_COMPACT if _safe_canvas.size.x < 1120.0 else PROFILE_STANDARD


func _calculate_safe_canvas() -> Rect2:
    var available_position := Vector2(safe_insets.x, safe_insets.y)
    var available_size := Vector2(
        maxf(1.0, viewport_size.x - safe_insets.x - safe_insets.z),
        maxf(1.0, viewport_size.y - safe_insets.y - safe_insets.w)
    )
    var canvas_size := available_size
    if available_size.x / available_size.y > DESIGN_ASPECT:
        canvas_size.x = available_size.y * DESIGN_ASPECT
    else:
        canvas_size.y = available_size.x / DESIGN_ASPECT
    return Rect2(available_position + (available_size - canvas_size) * 0.5, canvas_size)
