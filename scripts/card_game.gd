class_name EmberpanCardGame
extends Control
const OpenSourceLicenses = preload("res://scripts/manus/open_source_licenses.gd")

signal screen_changed(screen_name: String)
signal battle_finished(victory: bool)

const DB := preload("res://scripts/card_database.gd")
const JUICE_DIRECTOR := preload("res://scripts/juice_director.gd")
const TARGET_LINE := preload("res://scripts/juice_target_line.gd")
const JUICE_PROFILES := preload("res://scripts/card_battle_juice_profiles.gd")
const LEADERBOARD_CLIENT := preload("res://scripts/leaderboard_client.gd")
const PAUSE_INPUT_ROUTER := preload("res://scripts/pause_input_router.gd")
const TUTORIAL_CALLOUT := preload("res://scripts/tutorial_callout.gd")
const L10N := preload("res://scripts/localization.gd")
const SLEEP_PARTICLE_EMITTER := preload("res://scripts/sleep_particle_emitter.gd")
const ATOMIC_JSON := preload("res://scripts/atomic_json_file.gd")
const CURSOR_DIRECTOR := preload("res://scripts/cursor_director.gd")
const BATTLE_LAYOUT := preload("res://scripts/battle_layout.gd")
const TAVERN := preload("res://scripts/tavern_ui.gd")
const SAVE_PATH := "user://emberpan_card_stats.json"
const SAVE_SCHEMA_VERSION := 1
const MAX_BOARD := 4
const MAX_HAND := 8
const MAX_MANA := 8
const BOARD_SERVE_MOVE_SECONDS := 0.48
const BOARD_SERVE_SETTLE_SECONDS := 0.52
const BOARD_SERVE_FADE_SECONDS := 0.40
const BOARD_REFLOW_SECONDS := 0.20
const BOARD_ATTACK_IMPACT_SECONDS := JUICE_DIRECTOR.ATTACK_IMPACT_SECONDS
const PLAYER_DECK_LAYER_OFFSET := Vector2(3.0, 4.0)
const DECK_CRADLE_APERTURE_RECT := Rect2(37.5, 28.0, 54.5, 97.5)
const DECK_CARD_OVERSCAN_RECT := Rect2(23.8, 9.5, 73.4, 124.0)
const DECK_FACE_CLIP_RECT := Rect2(34.0, 25.0, 63.0, 104.0)
const OPPONENT_HAND_CARD_SIZE := Vector2(44.0, 66.0)
const OPPONENT_HAND_ARC_RISE := 5.0
const DRAW_FLIGHT_SECONDS := 0.42
const DRAW_FLIP_SECONDS := 0.13

const INK := Color("#100A18")
const PLUM := Color("#24122E")
const PLUM_SOFT := Color("#3A2045")
const COPPER := Color("#C36D32")
const EMBER := Color("#F3A33C")
const GOLD := Color("#FFD36A")
const CREAM := Color("#F7E9C8")
const TEAL := Color("#55C6A9")
const MANA_BLUE := Color("#4AD9FF")
const CARD_MANA_CRYSTAL_TINT := Color("#858A96")
const CARD_MANA_CRYSTAL_UNAFFORDABLE_TINT := Color("#59616DB8")
const CRIMSON := Color("#D95757")
const HISTORY_PLAYER_DAMAGE_TEXT := Color("#FF3B30")
const MINION_HEALTH_RED := Color("#FF3B30")
const MUTED := Color("#BBAF9A")
const CONTENT_BG := Color(0.0, 0.0, 0.0, 0.75)
const HAND_CARD_BG := Color(0.0, 0.0, 0.0, 0.95)
const MODAL_MASK := Color("#000000")
const PAUSE_MODAL_Z_INDEX := 4096
const CARD_PREVIEW_Z_INDEX := 2048
const HUD_TEXT_OUTLINE_COLOR := Color(0.02, 0.01, 0.03, 0.94)
const HUD_SUPPORT_TEXT := Color("#DEC9A7")
const HUD_DETAIL_BG := Color(0.02, 0.01, 0.03, 0.86)
const HERO_PORTRAIT_BACKDROP_RECT := Rect2(89, 18, 78, 84)
const HERO_PORTRAIT_RECT := Rect2(86, 24, 84, 68)
const HERO_NEUTRAL_COVER_LEFT_RECT := Rect2(56, 67, 45, 50)
const HERO_NEUTRAL_COVER_RIGHT_RECT := Rect2(156, 67, 45, 50)
const PASSIVE_PORTRAIT_BACKDROP_RECT := Rect2(16, 15, 38, 40)
const UNIT_NAME_RECT := Rect2(16, 132, 100, 25)
const UNIT_PORTRAIT_BACKDROP_RECT := Rect2(25, 17, 82, 82)
const UNIT_ATTACK_SLOT_CENTER := Vector2(27, 105)
const UNIT_HEALTH_SLOT_CENTER := Vector2(105, 105)
const UNIT_STAT_ICON_SIZE := 26.0
const UNIT_STAT_LABEL_SIZE := Vector2(34, 32)
const PANTRY_INGREDIENT_ICON_SIZE := 34.0
const PANTRY_EMBER_ICON_SIZE := 38.0
const PANTRY_EMBER_ICON_OFFSET := Vector2(-2, -2)
const HISTORY_TICKET_WIDTH_SCALE := 1.75
const HISTORY_TICKET_TEXT_NUMBER_GAP := 0.0

const TUTORIAL_STEPS := [
	{
		"id": "play_precise_chop", "target": "precise_chop", "placement": "top", "progress_key": "tutorial.progress.1",
		"title_key": "tutorial.play_precise_chop.title", "body_key": "tutorial.play_precise_chop.body",
		"advance": "play_precise_chop", "action_gated": true, "hint_key": "tutorial.play_precise_chop.hint",
	},
	{
		"id": "target_enemy", "target": "first_enemy", "placement": "side", "progress_key": "tutorial.progress.2",
		"title_key": "tutorial.target_enemy.title", "body_key": "tutorial.target_enemy.body",
		"advance": "target_enemy", "action_gated": true, "hint_key": "tutorial.target_enemy.hint",
	},
	{
		"id": "end_turn", "target": "end_turn", "placement": "top", "progress_key": "tutorial.progress.3",
		"title_key": "tutorial.end_turn.title", "body_key": "tutorial.end_turn.body",
		"advance": "end_turn", "action_gated": true, "hint_key": "tutorial.end_turn.hint",
	},
	{
		"id": "wait_for_player_turn", "target": "none", "advance": "wait",
	},
	{
		"id": "complete", "target": "player_status", "placement": "bottom", "progress_key": "tutorial.progress.4",
		"title_key": "tutorial.complete.title", "body_key": "tutorial.complete.body",
		"advance": "finish", "button_key": "tutorial.finish",
	},
]

var screen_name := "title"
var rules_open := false
var settings_open := false
var pause_open := false
var leaderboard_open := false
var deck_overlay_open := false
var service_history_open := false
var debug_fast := false
var rng := RandomNumberGenerator.new()
var submission_rng := RandomNumberGenerator.new()
var reduce_motion := false
var sound_muted := false
var motion_mode := JUICE_PROFILES.MOTION_FULL
var shake_intensity := 1.0
var flash_intensity := 1.0
var particle_density := 1.0
var animation_speed := 1.0
var auto_accelerate := true
var captions_enabled := true

var screen_layer: Control
var juice: EmberpanJuiceDirector
var target_line: EmberpanTargetLine
var tweaks: EmberpanRuntimeTweakControls
var leaderboard: EmberpanLeaderboardClient
var pause_input_router: Node
var tutorial_canvas: CanvasLayer
var tutorial_callout: EmberpanTutorialCallout
var cursor_director: EmberpanCursorDirector
var battle_layout: EmberpanBattleLayout = BATTLE_LAYOUT.new()
var layout_safe_insets := Vector4.ZERO
var active_layout_profile: StringName = BATTLE_LAYOUT.PROFILE_STANDARD
var layout_rerender_queued := false
## Modal that was on screen at the previous render; modals only play their entrance when this changes.
var _presented_modal := ""
var _title_cursor: Control
## Title entrance clock (msec); -1 while the entrance waits for its first drawn frame.
var _title_entrance_msec := -100000
var _result_reveal_msec := -100000
var card_preview: Control
var enemy_hero_button: Button
var player_hero_control: Control
var chef_name_input: LineEdit
var last_rendered_screen := ""
var next_unit_uid := 1
var suppress_juice := true
var juice_events: Array[Dictionary] = []
var juice_processing := false
var juice_repeat_speed := 1.0
var card_nodes_by_uid := {}
var unit_nodes_by_uid := {}
var visual_hand_positions := {}
var visual_unit_rects := {}
var prior_hand_positions := {}
var prior_unit_rects := {}
var pending_draw_reveals := {}
var enemy_hero_anchor := Vector2(220, 75)
var player_hero_anchor := Vector2(1068, 75)
var pantry_anchor := Vector2(1180, 620)
var pantry_ingredient_anchors := {}
var recipe_anchors := {}
var reward_anchors := {}
var history_events: Array[Dictionary] = []
var reward_revealed := {}
var dragged_card_uid := -1
var drag_candidate_uid := -1
var drag_start_pointer := Vector2.ZERO
var drag_start_position := Vector2.ZERO
var drag_pointer_offset := Vector2.ZERO
var drag_last_pointer := Vector2.ZERO
var drag_velocity := Vector2.ZERO
var drag_active := false
var suppress_card_click_uid := -1
var tutorial_active := false
var tutorial_step_index := 0
var tutorial_pending := false
var opening_hand_in_progress := false
var opening_deal_generation := 0
var battle_generation := 0
var run_active := false

var run_deck: Array[Dictionary] = []
var next_card_uid := 1
var battle_number := 0
var completed_battles := 0
var current_encounter_id := ""
var selected_route := ""
var pantry := {"fungus": 0, "herb": 0, "meat": 0, "ember": 0}
var precise_kills := 0
var overkills := 0
var dishes_cooked := 0
var reward_options: Array[String] = []
var reward_done := false
var claimed_legendary_ids: Array[String] = []
var run_result := ""
var player_name := ""
var local_scores: Array[Dictionary] = []
var pending_global_submissions: Array[Dictionary] = []
var last_run_score := 0
var last_run_submission_id := ""
var _battle_tweak_values: Dictionary = {}
var run_ranked_eligible := true
var last_run_ranked_eligible := true

var player_health := 28
var player_max_health := 28
var player_armor := 0
var player_max_mana := 0
var player_mana := 0
var player_deck: Array[Dictionary] = []
var player_hand: Array[Dictionary] = []
var player_discard: Array[Dictionary] = []
var player_board: Array[Dictionary] = []
var fatigue := 0
var hero_power_used := false
var next_summon_attack_bonus := 0

var enemy_name := ""
var enemy_subtitle := ""
var enemy_passive := ""
var enemy_health := 0
var enemy_max_health := 0
var enemy_armor := 0
var enemy_max_mana := 0
var enemy_mana := 0
var enemy_deck: Array[Dictionary] = []
var enemy_hand: Array[Dictionary] = []
var enemy_discard: Array[Dictionary] = []
var enemy_board: Array[Dictionary] = []
var enemy_first_summon := true
var boss_enraged := false

var is_player_turn := false
var input_locked := false
var turn_number := 0
var pending_action := {}
var combat_log: Array[String] = []
var banner_text := ""
var banner_color := CREAM
var lifetime := {"runs": 0, "wins": 0, "best_streak": 0, "streak": 0}


func t(key: String, placeholder_value: Variant = {}) -> String:
	return L10N.t(key, placeholder_value)


func _ready() -> void:
	set_process_unhandled_input(true)
	_configure_battle_layout()
	rng.randomize()
	submission_rng.randomize()
	DisplayServer.window_set_title(t("app.title"))
	_setup_presentation_layers()
	_load_stats()
	if player_name.is_empty():
		player_name = t("leaderboard.chef_fallback")
	_apply_tweak_live_state()
	show_title()
	suppress_juice = false
	if OS.has_feature("web") and bool(JavaScriptBridge.eval("(() => { const p = new URLSearchParams(location.hash.slice(1)); return p.has('room') && p.has('invite'); })()")):
		get_tree().call_deferred("change_scene_to_file", "res://scenes/multiplayer.tscn")


func _setup_presentation_layers() -> void:
	screen_layer = Control.new()
	screen_layer.name = "ScreenLayer"
	screen_layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen_layer.position = Vector2.ZERO
	screen_layer.size = BATTLE_LAYOUT.DESIGN_SIZE
	screen_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	screen_layer.pivot_offset = Vector2.ZERO
	add_child(screen_layer)
	_apply_battle_canvas_transform()

	juice = JUICE_DIRECTOR.new()
	juice.name = "JuiceLayer"
	_configure_juice()
	add_child(juice)

	target_line = TARGET_LINE.new()
	target_line.name = "TargetingLine"
	juice.add_child(target_line)

	tweaks = get_node("/root/RuntimeTuning")
	tweaks.value_changed.connect(_on_tweak_value_changed)

	leaderboard = LEADERBOARD_CLIENT.new()
	leaderboard.name = "LeaderboardClient"
	leaderboard.state_changed.connect(_on_leaderboard_state_changed)
	add_child(leaderboard)

	pause_input_router = PAUSE_INPUT_ROUTER.new()
	pause_input_router.name = "PauseInputRouter"
	pause_input_router.escape_pressed.connect(_on_paused_escape_pressed)
	add_child(pause_input_router)

	tutorial_canvas = CanvasLayer.new()
	tutorial_canvas.name = "TutorialCanvas"
	tutorial_canvas.layer = 300
	add_child(tutorial_canvas)

	tutorial_callout = TUTORIAL_CALLOUT.new()
	tutorial_callout.name = "TutorialCalloutLayer"
	tutorial_callout.setup(DB.art("tutorial_mise"), DB.art("tutorial_pointer"))
	tutorial_callout.configure_safe_bounds(battle_layout.safe_canvas())
	tutorial_callout.next_requested.connect(_on_tutorial_next_requested)
	tutorial_callout.skip_requested.connect(_skip_tutorial)
	tutorial_canvas.add_child(tutorial_callout)

	cursor_director = CURSOR_DIRECTOR.new()
	cursor_director.name = "CursorDirector"
	cursor_director.setup(self)
	add_child(cursor_director)


func _tweak(identifier: StringName, fallback: Variant) -> Variant:
	if _battle_tweak_values.has(identifier):
		return _battle_tweak_values[identifier]
	return tweaks.get_value(identifier, fallback) if tweaks != null else fallback


func _tweak_int(identifier: StringName, fallback: int) -> int:
	return int(_tweak(identifier, fallback))


func _tweak_float(identifier: StringName, fallback: float) -> float:
	return float(_tweak(identifier, fallback))


func _tweak_bool(identifier: StringName, fallback: bool) -> bool:
	return bool(_tweak(identifier, fallback))


func _effective_sound_muted() -> bool:
	return sound_muted or _tweak_bool(&"audio.muted", false)


func _apply_tweak_live_state() -> void:
	if screen_layer == null or juice == null:
		return
	var hud_scale := _tweak_float(&"ui.hud_scale", 1.0)
	screen_layer.scale = Vector2.ONE * hud_scale
	screen_layer.modulate = Color.from_string(String(_tweak(&"ui.hud_tint", "#ffffff")), Color.WHITE)
	_configure_juice()
	juice.pitch_scale = _tweak_float(&"audio.pitch_scale", 1.0)
	juice.ambient_enabled = _tweak_bool(&"environment.ambient_particles", true)
	juice.ambient_density_scale = _tweak_float(&"environment.ambient_density", 1.0)
	juice.ambient_speed_scale = _tweak_float(&"environment.ambient_speed", 1.0)
	juice.particle_count_scale = _tweak_float(&"environment.particle_count", 1.0)
	juice.particle_radius_scale = _tweak_float(&"environment.particle_radius", 1.0)
	juice.flash_strength_scale = _tweak_float(&"environment.screen_flash", 1.0)
	juice.shake_strength_scale = _tweak_float(&"environment.screen_shake", 1.0)


func _configure_juice() -> void:
	if juice == null:
		return
	motion_mode = JUICE_PROFILES.MOTION_REDUCED if reduce_motion and motion_mode == JUICE_PROFILES.MOTION_FULL else motion_mode
	juice.set_audio_muted(_effective_sound_muted())
	juice.configure_presentation(motion_mode, shake_intensity, flash_intensity, particle_density, animation_speed, auto_accelerate, captions_enabled)
	if cursor_director != null:
		cursor_director.configure_motion(motion_mode)


func _on_tweak_value_changed(identifier: StringName, _value: Variant) -> void:
	_apply_tweak_live_state()
	if screen_name in ["battle", "kitchen", "route"] and tweaks != null and tweaks.is_rank_affecting(identifier):
		run_ranked_eligible = false
	if String(identifier).begins_with("ui.") or identifier in [
		&"environment.background_brightness", &"environment.background_tint",
		&"environment.overlay_opacity_scale", &"gameplay.max_board_slots",
		&"gameplay.max_hand_size", &"gameplay.guard_enabled",
	]:
		_render_current_screen()





func _render_current_screen() -> void:
	match screen_name:
		"title": _render_title()
		"battle": _render_battle()
		"kitchen": _render_kitchen()
		"route": _render_route()
		"end": _render_end()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_configure_battle_layout()
		if screen_name == "battle" and not layout_rerender_queued:
			layout_rerender_queued = true
			call_deferred("_rerender_after_layout_change")
		queue_redraw()


func _configure_battle_layout(viewport_override := Vector2.ZERO, safe_insets_override := Vector4(-1, -1, -1, -1)) -> void:
	var design_size: Vector2 = viewport_override if viewport_override.x > 0.0 and viewport_override.y > 0.0 else size if size.x > 0.0 and size.y > 0.0 else BATTLE_LAYOUT.DESIGN_SIZE
	var insets: Vector4 = layout_safe_insets if safe_insets_override.x < 0.0 else safe_insets_override
	battle_layout.configure(design_size, insets, BATTLE_LAYOUT.PROFILE_STANDARD)
	active_layout_profile = battle_layout.choose_profile_for_safe_width()
	battle_layout.configure(design_size, insets, active_layout_profile)
	_apply_battle_canvas_transform()


func _apply_battle_canvas_transform() -> void:
	if screen_layer == null:
		return
	var safe := battle_layout.safe_canvas()
	screen_layer.position = safe.position
	screen_layer.scale = Vector2(safe.size.x / BATTLE_LAYOUT.DESIGN_SIZE.x, safe.size.y / BATTLE_LAYOUT.DESIGN_SIZE.y)
	if tutorial_callout != null:
		tutorial_callout.configure_safe_bounds(safe)


func _rerender_after_layout_change() -> void:
	layout_rerender_queued = false
	if screen_name == "battle" and is_inside_tree():
		_render_battle()


func _battle_zone(identifier: StringName) -> Rect2:
	return battle_layout.reference_zone_for_profile(identifier, active_layout_profile)


func _target_battle_zone(identifier: StringName) -> Rect2:
	return battle_layout.reference_zone_for_profile(identifier, active_layout_profile)


func _input(event: InputEvent) -> void:
	if drag_candidate_uid < 0:
		return
	if event is InputEventMouseMotion:
		_update_card_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_card_drag(event.position)
	elif event is InputEventScreenDrag:
		_update_card_drag(event.position)
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_card_drag(event.position)


func _on_card_gui_input(event: InputEvent, card_uid: int, control: Control) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed or not _can_take_player_action():
		return
	drag_candidate_uid = card_uid
	dragged_card_uid = -1
	drag_active = false
	drag_start_pointer = get_viewport().get_mouse_position() if event is InputEventMouseButton else event.position
	drag_last_pointer = drag_start_pointer
	drag_start_position = control.position
	drag_pointer_offset = drag_start_pointer - control.global_position


func _update_card_drag(pointer: Vector2) -> void:
	var control: Control = card_nodes_by_uid.get(drag_candidate_uid)
	if control == null or not is_instance_valid(control):
		_reset_card_drag()
		return
	if not drag_active and pointer.distance_to(drag_start_pointer) < 7.0:
		return
	if not drag_active:
		drag_active = true
		dragged_card_uid = drag_candidate_uid
		suppress_card_click_uid = dragged_card_uid
		_hide_card_preview()
		control.z_index = 95
		control.scale = Vector2(1.075, 1.075)
		if juice != null:
			juice.play_sfx("draw", -13.0)
	drag_velocity = drag_velocity.lerp(pointer - drag_last_pointer, 0.45)
	drag_last_pointer = pointer
	control.global_position = pointer - drag_pointer_offset
	control.rotation = clampf(drag_velocity.x * 0.004, -0.12, 0.12) if motion_mode == JUICE_PROFILES.MOTION_FULL else 0.0
	if juice != null:
		var valid := _is_valid_card_drop(dragged_card_uid, pointer)
		var drop_zone := _play_region_in_layer(juice)
		var insertion_rect := _card_insertion_preview_rect(dragged_card_uid)
		if insertion_rect.size != Vector2.ZERO:
			insertion_rect = _rect_between_canvas_items(screen_layer, juice, insertion_rect)
		juice.show_drop_zone(drop_zone, valid, t("battle.release_to_serve") if valid else _card_playability_reason(dragged_card_uid), insertion_rect if valid else Rect2())


func _finish_card_drag(pointer: Vector2) -> void:
	var uid := drag_candidate_uid
	var control: Control = card_nodes_by_uid.get(uid)
	if drag_active and control != null and is_instance_valid(control):
		var valid := _is_valid_card_drop(uid, pointer)
		if juice != null:
			juice.dismiss_drop_zone()
		if valid:
			if juice != null:
				juice.contact_ring(_point_between_canvas_items(self, juice, pointer), TEAL, 48.0)
			_reset_card_drag()
			var hand_index := _find_hand_index_by_uid(uid)
			if hand_index >= 0:
				_on_hand_card_pressed(hand_index)
			return
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(control, "position", drag_start_position, 0.22)
		tween.tween_property(control, "rotation", float(control.get_meta("juice_rest_rotation", 0.0)), 0.22)
		tween.tween_property(control, "scale", Vector2.ONE, 0.18)
		_queue_juice_event({"kind": "invalid", "position": pointer, "message": _card_playability_reason(uid)})
		suppress_card_click_uid = -1
	_reset_card_drag()


func _reset_card_drag() -> void:
	drag_candidate_uid = -1
	dragged_card_uid = -1
	drag_active = false
	drag_velocity = Vector2.ZERO
	if juice != null:
		juice.dismiss_drop_zone()


func _find_hand_index_by_uid(uid: int) -> int:
	for index in range(player_hand.size()):
		if int(player_hand[index].get("uid", -1)) == uid:
			return index
	return -1


func _pending_spell_hand_index() -> int:
	if pending_action.get("kind") != "spell":
		return -1
	var card_uid := int(pending_action.get("card_uid", -1))
	if card_uid >= 0:
		return _find_hand_index_by_uid(card_uid)
	return int(pending_action.get("hand_index", -1))


func _has_pending_spell() -> bool:
	return pending_action.get("kind") == "spell"


func _is_valid_card_drop(uid: int, pointer: Vector2) -> bool:
	var screen_pointer := _point_between_canvas_items(self, screen_layer, pointer)
	return _play_region_screen_rect().grow(0.001).has_point(screen_pointer) and _card_playability_reason(uid) == t("battle.release_to_serve")


func _play_region_screen_rect() -> Rect2:
	return _target_battle_zone(&"play_region")


func _play_region_in_layer(destination: CanvasItem) -> Rect2:
	return _rect_between_canvas_items(screen_layer, destination, _play_region_screen_rect())


func _card_insertion_preview_rect(uid: int) -> Rect2:
	var hand_index := _find_hand_index_by_uid(uid)
	if hand_index < 0 or String(DB.card(player_hand[hand_index].id).get("type", "")) != "unit":
		return Rect2()
	var slot_count := maxi(_tweak_int(&"gameplay.max_board_slots", MAX_BOARD), player_board.size() + 1)
	if player_board.size() >= slot_count:
		return Rect2()
	var slots := _board_slot_rects(true, slot_count)
	return slots[player_board.size()] if player_board.size() < slots.size() else Rect2()


func _card_playability_reason(uid: int) -> String:
	var hand_index := _find_hand_index_by_uid(uid)
	if hand_index < 0:
		return t("battle.card_moved")
	if _has_pending_spell():
		return t("battle.wait_for_turn")
	var definition := DB.card(player_hand[hand_index].id)
	if definition.cost > player_mana:
		return t("battle.need_mana", {"cost": int(definition.cost)})
	if definition.type == "unit" and player_board.size() >= _tweak_int(&"gameplay.max_board_slots", MAX_BOARD):
		return t("battle.board_full")
	if not _can_take_player_action():
		return t("battle.wait_for_turn")
	return t("battle.release_to_serve")


func _on_hand_card_uid_pressed(uid: int) -> void:
	if suppress_card_click_uid == uid:
		suppress_card_click_uid = -1
		return
	var hand_index := _find_hand_index_by_uid(uid)
	if hand_index >= 0:
		_on_hand_card_pressed(hand_index)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if service_history_open:
			if event.keycode == KEY_ESCAPE:
				_close_service_history()
			get_viewport().set_input_as_handled()
			return
		if tutorial_active and _handle_tutorial_key(event):
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			if pause_open:
				_on_paused_escape_pressed()
			elif leaderboard_open:
				_close_leaderboard()
			elif settings_open:
				_close_settings()
			elif rules_open:
				rules_open = false
				_render_title()
			elif deck_overlay_open:
				deck_overlay_open = false
				_render_kitchen()
			elif screen_name == "battle" and not pending_action.is_empty():
				_cancel_pending_action()
			elif _is_active_run_screen():
				_open_pause_menu()
			get_viewport().set_input_as_handled()
			return
		if screen_name == "title" and not leaderboard_open and not settings_open and not rules_open and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			if get_viewport().gui_get_focus_owner() is LineEdit:
				return
			start_new_run()
			return
		if screen_name != "battle" or not is_player_turn or input_locked:
			return
		if event.keycode == KEY_ENTER:
			end_player_turn()
		elif event.keycode == KEY_Q:
			use_hero_power()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
			var hand_index := int(event.keycode - KEY_1)
			if hand_index < player_hand.size():
				_on_hand_card_pressed(hand_index)


func _handle_tutorial_key(event: InputEventKey) -> bool:
	if event.keycode == KEY_ESCAPE:
		_skip_tutorial()
		return true
	var step := _tutorial_current_step()
	if step.is_empty():
		return false
	var advance := String(step.get("advance", ""))
	if advance in ["next", "finish"] and event.keycode in [KEY_ENTER, KEY_SPACE]:
		_on_tutorial_next_requested()
		return true
	if advance == "play_precise_chop" and event.keycode >= KEY_1 and event.keycode <= KEY_8:
		var hand_index := int(event.keycode - KEY_1)
		if hand_index < player_hand.size() and String(player_hand[hand_index].id) == "precise_chop":
			_on_hand_card_pressed(hand_index)
		return true
	if advance == "end_turn" and event.keycode == KEY_ENTER:
		end_player_turn()
		return true
	return true


func show_title() -> void:
	_leave_pause_state()
	battle_generation += 1
	run_active = false
	opening_deal_generation += 1
	opening_hand_in_progress = false
	tutorial_pending = false
	tutorial_active = false
	service_history_open = false
	if tutorial_callout != null:
		tutorial_callout.dismiss()
	screen_name = "title"
	rules_open = false
	settings_open = false
	leaderboard_open = false
	pending_action.clear()
	input_locked = false
	_render_title()
	screen_changed.emit(screen_name)
	call_deferred("_sync_global_leaderboard")


func _tutorial_current_step() -> Dictionary:
	if not tutorial_active or tutorial_step_index < 0 or tutorial_step_index >= TUTORIAL_STEPS.size():
		return {}
	return TUTORIAL_STEPS[tutorial_step_index]


func _on_tutorial_next_requested() -> void:
	var step := _tutorial_current_step()
	if step.is_empty() or String(step.get("advance", "")) not in ["next", "finish"]:
		return
	if String(step.get("advance", "")) == "finish":
		_skip_tutorial()
		return
	_advance_tutorial_step()
	if screen_name == "battle":
		_render_battle()


func _tutorial_complete_action(action: String) -> void:
	var step := _tutorial_current_step()
	if step.is_empty() or String(step.get("advance", "")) != action:
		return
	_advance_tutorial_step()


func _advance_tutorial_step() -> void:
	tutorial_step_index += 1
	if tutorial_step_index >= TUTORIAL_STEPS.size():
		_skip_tutorial()
		return
	if String(_tutorial_current_step().get("advance", "")) == "wait" and tutorial_callout != null:
		tutorial_callout.dismiss()


func _skip_tutorial() -> void:
	tutorial_pending = false
	tutorial_active = false
	if tutorial_callout != null:
		tutorial_callout.dismiss()


func _render_tutorial() -> void:
	if tutorial_callout == null:
		return
	var step := _tutorial_current_step()
	if screen_name != "battle" or pause_open or service_history_open or step.is_empty() or String(step.get("advance", "")) == "wait":
		tutorial_callout.dismiss()
		return
	var target := String(step.get("target", "none"))
	var focus_rect := _tutorial_focus_rect(target)
	tutorial_callout.present(step, focus_rect, _tweak_float(&"ui.font_scale", 1.0), _tutorial_spotlight_rect(target, focus_rect))


func _tutorial_spotlight_rect(target: String, focus_rect: Rect2) -> Rect2:
	if target != "first_enemy" or pending_action.get("kind") != "spell":
		return focus_rect
	var hand_index := _pending_spell_hand_index()
	if hand_index < 0 or hand_index >= player_hand.size():
		return focus_rect
	var source := card_nodes_by_uid.get(int(player_hand[hand_index].uid)) as Control
	if source == null or not is_instance_valid(source):
		return focus_rect
	return focus_rect.merge(_tutorial_control_rect(source))


func _tutorial_focus_rect(target: String) -> Rect2:
	var rect := Rect2(530, 280, 220, 120)
	var live_target := _tutorial_target_control(target)
	if live_target != null:
		return _tutorial_control_rect(live_target)
	match target:
		"precise_chop":
			for runtime_card in player_hand:
				if String(runtime_card.id) == "precise_chop":
					rect = visual_hand_positions.get(int(runtime_card.uid), rect)
					break
		"first_enemy":
			if not enemy_board.is_empty():
				rect = visual_unit_rects.get(int(enemy_board[0].uid), rect)
		"end_turn":
			rect = Rect2(32, 642, 144, 45)
		"player_status":
			rect = Rect2(956, 14, 306, 126)
	return _tutorial_transform_rect(rect)


func _tutorial_target_control(target: String) -> Control:
	match target:
		"precise_chop":
			for runtime_card in player_hand:
				if String(runtime_card.id) == "precise_chop":
					return card_nodes_by_uid.get(int(runtime_card.uid)) as Control
		"first_enemy":
			if not enemy_board.is_empty():
				return unit_nodes_by_uid.get(int(enemy_board[0].uid)) as Control
		"end_turn":
			return screen_layer.find_child("EndTurnButton", true, false) as Control
		"player_status":
			return screen_layer.find_child("PlayerStatusPanel", true, false) as Control
	return null


func _tutorial_control_rect(control: Control) -> Rect2:
	if not is_instance_valid(control) or tutorial_callout == null:
		return Rect2()
	return _control_rect_in_layer(control, tutorial_callout)


func _tutorial_transform_rect(rect: Rect2) -> Rect2:
	if screen_layer == null or tutorial_callout == null:
		return rect
	return _rect_between_canvas_items(screen_layer, tutorial_callout, rect)


func _point_between_canvas_items(source: CanvasItem, destination: CanvasItem, point: Vector2) -> Vector2:
	if source == null or destination == null:
		return point
	var canvas_point := source.get_global_transform_with_canvas() * point
	return destination.get_global_transform_with_canvas().affine_inverse() * canvas_point


func _rect_between_canvas_items(source: CanvasItem, destination: CanvasItem, rect: Rect2) -> Rect2:
	if source == null or destination == null:
		return rect
	var transform := destination.get_global_transform_with_canvas().affine_inverse() * source.get_global_transform_with_canvas()
	var corners := [
		transform * rect.position,
		transform * Vector2(rect.end.x, rect.position.y),
		transform * rect.end,
		transform * Vector2(rect.position.x, rect.end.y),
	]
	var top_left: Vector2 = corners[0]
	var bottom_right: Vector2 = corners[0]
	for corner: Vector2 in corners:
		top_left.x = minf(top_left.x, corner.x)
		top_left.y = minf(top_left.y, corner.y)
		bottom_right.x = maxf(bottom_right.x, corner.x)
		bottom_right.y = maxf(bottom_right.y, corner.y)
	return Rect2(top_left, bottom_right - top_left)


func _control_rect_in_layer(control: Control, destination: CanvasItem) -> Rect2:
	if not is_instance_valid(control):
		return Rect2()
	return _rect_between_canvas_items(control, destination, Rect2(Vector2.ZERO, control.size))


func _screen_point_in_juice(point: Vector2) -> Vector2:
	return _point_between_canvas_items(screen_layer, juice, point) if screen_layer != null and juice != null else point


func _screen_rect_in_juice(rect: Rect2) -> Rect2:
	return _rect_between_canvas_items(screen_layer, juice, rect) if screen_layer != null and juice != null else rect


func _is_active_run_screen() -> bool:
	return screen_name in ["battle", "kitchen", "route"]


func _is_current_battle(generation: int) -> bool:
	return run_active and screen_name == "battle" and generation == battle_generation


func _cancel_pending_action() -> void:
	if screen_name != "battle" or pending_action.is_empty():
		return
	pending_action.clear()
	banner_text = t("battle.your_turn_mana", {"mana": player_mana})
	banner_color = TEAL
	_render_battle()


func _shuffle_gameplay(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		if swap_index != index:
			var value: Variant = values[index]
			values[index] = values[swap_index]
			values[swap_index] = value


func _open_pause_menu() -> void:
	if pause_open or not _is_active_run_screen():
		return
	_reset_card_drag()
	pause_open = true
	settings_open = false
	if pause_input_router != null:
		pause_input_router.active = true
	_render_current_screen()
	get_tree().paused = true


func _resume_game() -> void:
	if not pause_open:
		return
	_leave_pause_state()
	_render_current_screen()


func _leave_pause_state() -> void:
	pause_open = false
	settings_open = false
	if pause_input_router != null:
		pause_input_router.active = false
	if is_inside_tree():
		get_tree().paused = false


func _on_paused_escape_pressed() -> void:
	if not pause_open:
		return
	if settings_open:
		_close_settings()
	else:
		_resume_game()


func _open_pause_settings() -> void:
	if not pause_open:
		return
	settings_open = true
	_render_current_screen()


func _close_settings() -> void:
	settings_open = false
	_render_current_screen()


func _resign_run() -> void:
	if not pause_open or not _is_active_run_screen():
		return
	_leave_pause_state()
	_finish_run(false)


func start_new_run(seed_value: int = -1) -> void:
	if chef_name_input != null and is_instance_valid(chef_name_input):
		_commit_player_name(chef_name_input.text)
	suppress_juice = true
	tutorial_pending = not debug_fast
	tutorial_active = false
	tutorial_step_index = 0
	if tutorial_callout != null:
		tutorial_callout.dismiss()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	battle_generation += 1
	run_active = true
	run_deck.clear()
	claimed_legendary_ids.clear()
	next_card_uid = 1
	for card_id in DB.STARTER_DECK:
		_add_card_to_run(card_id)
	battle_number = 1
	completed_battles = 0
	current_encounter_id = "picklemancer"
	selected_route = ""
	pantry = {"fungus": 0, "herb": 0, "meat": 0, "ember": 0}
	precise_kills = 0
	overkills = 0
	dishes_cooked = 0
	run_ranked_eligible = tweaks == null or not tweaks.has_rank_affecting_changes()
	player_max_health = _consume_tweak_int(&"player.starting_health", 28)
	player_health = player_max_health
	player_armor = 0
	run_result = ""
	next_unit_uid = 1
	visual_hand_positions.clear()
	visual_unit_rects.clear()
	_start_battle(current_encounter_id)


func _start_battle(encounter_id: String) -> void:
	_battle_tweak_values = tweaks.values_for_mode("NEXT BATTLE") if tweaks != null else {}
	battle_generation += 1
	opening_deal_generation += 1
	var deal_generation := opening_deal_generation
	opening_hand_in_progress = false
	suppress_juice = true
	juice_events.clear()
	screen_name = "battle"
	service_history_open = false
	current_encounter_id = encounter_id
	var encounter := DB.encounter(encounter_id)
	enemy_name = t(encounter.name_key)
	enemy_subtitle = t(encounter.subtitle_key)
	enemy_passive = t(encounter.passive_key)
	enemy_max_health = maxi(1, roundi(float(encounter.health) * _consume_tweak_float(&"enemy.hero_health_multiplier", 1.0)))
	enemy_health = enemy_max_health
	enemy_armor = 0
	enemy_max_mana = 0
	enemy_mana = 0
	enemy_first_summon = true
	boss_enraged = false

	player_max_mana = 0
	player_mana = 0
	player_deck = run_deck.duplicate(true)
	_shuffle_gameplay(player_deck)
	player_hand.clear()
	player_discard.clear()
	pending_draw_reveals.clear()
	player_board.clear()
	fatigue = 0
	hero_power_used = false
	next_summon_attack_bonus = 0
	history_events.clear()

	enemy_deck.clear()
	for card_id in encounter.deck:
		enemy_deck.append(_make_runtime_card(card_id, false))
	_shuffle_gameplay(enemy_deck)
	enemy_hand.clear()
	enemy_discard.clear()
	enemy_board.clear()
	var opening_unit: String = {
		"picklemancer": "pickle_imp",
		"mold_monarch": "moldling",
		"ember_butcher": "cellar_rat",
		"banquet_tyrant": "dough_golem",
	}.get(encounter_id, "pickle_imp")
	# Pre-plated enemies are part of encounter setup, not a turn summon. Preserve
	# the passive for the first enemy actually served during the enemy turn.
	enemy_first_summon = false
	for opening_index in range(mini(
		_consume_tweak_int(&"enemy.starting_units", 1),
		_consume_tweak_int(&"gameplay.max_board_slots", MAX_BOARD)
	)):
		_summon_unit(opening_unit, false, false)
	enemy_first_summon = true

	combat_log.clear()
	combat_log.append(t("log.encounter_challenge", {"enemy": enemy_name}))
	banner_text = t("battle.encounter_banner", {"number": battle_number, "enemy": enemy_name.to_upper()})
	banner_color = EMBER
	turn_number = 0
	pending_action.clear()
	input_locked = false
	is_player_turn = true

	var opening_hand_size := mini(
		_consume_tweak_int(&"gameplay.opening_hand_size", 5),
		_consume_tweak_int(&"gameplay.max_hand_size", MAX_HAND)
	)
	if battle_number == 1:
		var guaranteed := ["precise_chop", "coal_squire", "pan_paladin", "mise_en_place", "kitchen_guard"]
		_stack_opening_cards(guaranteed, opening_hand_size)

	var animate_opening_hand := battle_number == 1 and not debug_fast
	if not animate_opening_hand:
		for draw_index in range(opening_hand_size):
			_draw_player_card()
	_begin_player_turn(false, not animate_opening_hand)
	opening_hand_in_progress = animate_opening_hand
	suppress_juice = false
	_queue_juice_event({"kind": "battle_start", "name": enemy_name})
	if animate_opening_hand:
		call_deferred("_deal_opening_hand", opening_hand_size, deal_generation)
	call_deferred("_flush_juice_events")
	screen_changed.emit(screen_name)


func _stack_opening_cards(card_ids: Array, opening_hand_size: int) -> void:
	var stacked_cards: Array[Dictionary] = []
	for opening_index in range(mini(opening_hand_size, card_ids.size())):
		var card_id := String(card_ids[opening_index])
		for deck_index in range(player_deck.size()):
			if String(player_deck[deck_index].id) == card_id:
				stacked_cards.append(player_deck.pop_at(deck_index))
				break
	for stacked_index in range(stacked_cards.size() - 1, -1, -1):
		player_deck.append(stacked_cards[stacked_index])


func _deal_opening_hand(card_count: int, deal_generation: int) -> void:
	# Let the battle intro play against the freshly rendered empty hand before
	# the first card leaves the deck.
	await get_tree().process_frame
	while juice_processing or not juice_events.is_empty():
		if deal_generation != opening_deal_generation or screen_name != "battle":
			return
		await get_tree().process_frame
	if deal_generation != opening_deal_generation or screen_name != "battle":
		return
	for draw_index in range(card_count):
		if deal_generation != opening_deal_generation or screen_name != "battle":
			return
		var prior_hand_size := player_hand.size()
		_draw_player_card()
		if player_hand.size() <= prior_hand_size:
			continue
		var drawn_uid := int(player_hand.back().get("uid", -1))
		_render_battle()
		while pending_draw_reveals.has(drawn_uid):
			if deal_generation != opening_deal_generation or screen_name != "battle":
				return
			await get_tree().process_frame
		if debug_fast:
			await get_tree().process_frame
	if deal_generation != opening_deal_generation or screen_name != "battle":
		return
	opening_hand_in_progress = false
	input_locked = false
	tutorial_active = tutorial_pending
	tutorial_pending = false
	_render_battle()


func _begin_player_turn(draw_card: bool = true, unlock_input: bool = true) -> void:
	if _check_end_state():
		return
	is_player_turn = true
	input_locked = not unlock_input
	pending_action.clear()
	turn_number += 1
	player_max_mana = mini(_consume_tweak_int(&"gameplay.max_mana", MAX_MANA), player_max_mana + 1)
	player_mana = player_max_mana
	hero_power_used = false
	next_summon_attack_bonus = 0
	for unit in player_board:
		var was_ready := bool(unit.ready)
		unit.ready = true
		if not was_ready:
			_queue_juice_event({"kind": "ready", "uid": int(unit.uid)})
	if draw_card:
		for draw_index in range(_consume_tweak_int(&"gameplay.draw_per_turn", 1)):
			if not _draw_player_card():
				_check_end_state()
				return
	banner_text = t("battle.your_turn_mana", {"mana": player_mana})
	banner_color = TEAL
	_queue_juice_event({"kind": "turn", "friendly": true, "value": player_mana})
	if String(_tutorial_current_step().get("advance", "")) == "wait":
		_advance_tutorial_step()
	_render_battle()


func end_player_turn() -> void:
	if screen_name != "battle" or not is_player_turn or input_locked or not pending_draw_reveals.is_empty():
		return
	_tutorial_complete_action("end_turn")
	pending_action.clear()
	input_locked = true
	is_player_turn = false
	banner_text = t("battle.enemy_turn")
	banner_color = CRIMSON
	_queue_juice_event({"kind": "turn", "friendly": false})
	_render_battle()
	var turn_generation := battle_generation
	await _delay(0.46)
	if not _is_current_battle(turn_generation):
		return
	await _run_enemy_turn(turn_generation)


func _run_enemy_turn(turn_generation: int) -> void:
	if not _is_current_battle(turn_generation):
		return
	if _check_end_state():
		return
	enemy_max_mana = mini(
		_consume_tweak_int(&"gameplay.max_mana", MAX_MANA),
		enemy_max_mana + _consume_tweak_int(&"enemy.mana_per_turn", 1)
	)
	enemy_mana = enemy_max_mana
	enemy_first_summon = true
	for unit in enemy_board:
		unit.ready = true

	if current_encounter_id == "mold_monarch" and _enemy_has_ingredient("fungus"):
		var fungal_before := enemy_health
		enemy_health = mini(enemy_max_health, enemy_health + roundi(_consume_tweak_float(&"enemy.passive_strength_multiplier", 1.0)))
		if enemy_health > fungal_before:
			_queue_juice_event({"kind": "heal", "side": "enemy", "amount": enemy_health - fungal_before})
		_log(t("log.fungal_restore", {"health": roundi(_consume_tweak_float(&"enemy.passive_strength_multiplier", 1.0))}))
	_draw_enemy_card()

	var plays := 0
	while plays < _consume_tweak_int(&"enemy.cards_per_turn", 3) and enemy_board.size() < _consume_tweak_int(&"gameplay.max_board_slots", MAX_BOARD):
		if not _is_current_battle(turn_generation):
			return
		var hand_index := _enemy_best_affordable_card()
		if hand_index < 0:
			break
		var runtime_card: Dictionary = enemy_hand.pop_at(hand_index)
		var definition: Dictionary = DB.card(runtime_card.id)
		enemy_mana -= definition.cost
		_summon_unit(runtime_card.id, false, true)
		enemy_discard.append(runtime_card)
		_log(t("log.serves", {"source": enemy_name, "card": t(definition.name_key)}))
		plays += 1
		_render_battle()
		await _delay(0.48)
		if not _is_current_battle(turn_generation):
			return
		if _check_end_state():
			return

	var attack_queue: Array[Dictionary] = enemy_board.duplicate()
	for unit in attack_queue:
		if not _is_current_battle(turn_generation):
			return
		if not unit.ready or unit.health <= 0 or not enemy_board.has(unit):
			continue
		var target_index := _choose_enemy_attack_target(unit)
		unit.ready = false
		if target_index >= 0 and target_index < player_board.size():
			var target := player_board[target_index]
			_log(t("log.attacks", {"source": t(unit.name_key), "target": t(target.name_key)}))
			_resolve_unit_combat(unit, target, false)
		else:
			_log(t("log.hits_chef", {"source": t(unit.name_key), "damage": int(unit.attack)}))
			_queue_juice_event({"kind": "attack", "uid": int(unit.uid), "from_rect": _unit_visual_rect(unit), "destination": player_hero_anchor, "art": String(unit.art), "enemy": true})
			_damage_player(unit.attack, true)
		_remove_dead_units()
		_render_battle()
		await _delay(0.44)
		if not _is_current_battle(turn_generation):
			return
		if _check_end_state():
			return

	if not _is_current_battle(turn_generation):
		return
	input_locked = false
	_begin_player_turn(true)


func _enemy_best_affordable_card() -> int:
	var best_index := -1
	var best_cost := -1
	for index in range(enemy_hand.size()):
		var definition := DB.card(enemy_hand[index].id)
		if definition.cost <= enemy_mana and definition.cost > best_cost:
			best_cost = definition.cost
			best_index = index
	return best_index


func _choose_enemy_attack_target(attacker: Dictionary) -> int:
	var guard_index := _first_guard_index(player_board)
	if guard_index >= 0:
		return guard_index
	var best_index := -1
	var best_health := 999
	for index in range(player_board.size()):
		var target := player_board[index]
		if target.health <= attacker.attack and target.health < best_health:
			best_health = target.health
			best_index = index
	return best_index


func _on_hand_card_pressed(hand_index: int) -> void:
	if not _can_take_player_action() or hand_index < 0 or hand_index >= player_hand.size():
		return
	if _has_pending_spell():
		return
	pending_action.clear()
	var runtime_card := player_hand[hand_index]
	var definition := DB.card(runtime_card.id)
	if definition.cost > player_mana:
		banner_text = t("battle.not_enough_mana")
		banner_color = CRIMSON
		var mana_rect := _card_visual_rect(runtime_card)
		_queue_juice_event({"kind": "invalid", "position": mana_rect.position + mana_rect.size * 0.5, "message": t("battle.not_enough_mana")})
		_render_battle()
		return
	if definition.type == "unit":
		if player_board.size() >= _tweak_int(&"gameplay.max_board_slots", MAX_BOARD):
			banner_text = t("battle.player_board_full")
			banner_color = CRIMSON
			var full_rect := _card_visual_rect(runtime_card)
			_queue_juice_event({"kind": "invalid", "position": full_rect.position + full_rect.size * 0.5, "message": t("battle.board_full")})
			_render_battle()
			return
		var source_rect := _card_visual_rect(runtime_card)
		var board_slots := _tweak_int(&"gameplay.max_board_slots", MAX_BOARD)
		var summon_x := (1280.0 - (board_slots * 158 + maxi(0, board_slots - 1) * 12)) / 2.0 + player_board.size() * 170 + 79
		if not _pay_and_remove_hand_card(hand_index):
			return
		_queue_juice_event({"kind": "card_played", "card_id": runtime_card.id, "from_rect": source_rect, "destination": Vector2(summon_x, 443), "cost": int(definition.cost)})
		_summon_unit(runtime_card.id, true, true)
		player_discard.append(runtime_card)
		_log(t("log.chef_serves", {"card": t(definition.name_key)}))
		_trigger_mise_engine(definition)
		_render_battle()
		_check_end_state()
		return
	if definition.effect in ["target_enemy_damage", "target_friend_buff"]:
		pending_action = {
			"kind": "spell",
			"hand_index": hand_index,
			"card_uid": int(runtime_card.get("uid", -1)),
			"effect": definition.effect,
		}
		banner_text = t("battle.choose_target", {"target": t("battle.target_enemy" if definition.effect == "target_enemy_damage" else "battle.target_friendly")})
		banner_color = EMBER
		if String(runtime_card.id) == "precise_chop":
			_tutorial_complete_action("play_precise_chop")
		_render_battle()
		return
	_resolve_nontarget_card(hand_index)


func _resolve_nontarget_card(hand_index: int) -> void:
	if hand_index < 0 or hand_index >= player_hand.size():
		return
	var runtime_card := player_hand[hand_index]
	var definition := DB.card(runtime_card.id)
	var source_rect := _card_visual_rect(runtime_card)
	if not _pay_and_remove_hand_card(hand_index):
		return
	_queue_juice_event({"kind": "card_played", "card_id": runtime_card.id, "from_rect": source_rect, "destination": Vector2(640, 330), "cost": int(definition.cost)})
	_log(t("log.chef_plays", {"card": t(definition.name_key)}))
	match definition.effect:
		"enemy_area_damage":
			for unit in enemy_board.duplicate():
				_damage_unit(unit, definition.value, true)
			_remove_dead_units()
		"draw":
			for draw_index in range(definition.value):
				if not _draw_player_card():
					break
		"armor":
			_gain_player_armor(int(definition.value))
		"mooncap_broth":
			_heal_player(2)
			if _draw_player_card():
				_draw_player_card()
		"braised_bulwark":
			_gain_player_armor(5)
			if player_board.size() < _consume_tweak_int(&"gameplay.max_board_slots", MAX_BOARD):
				var guardian_attack := maxi(0, roundi(2.0 * _consume_tweak_float(&"player.unit_attack_multiplier", 1.0)))
				var guardian_health := maxi(1, roundi(3.0 * _consume_tweak_float(&"player.unit_health_multiplier", 1.0)))
				var guardian := {"id": "pan_token", "uid": next_unit_uid, "name_key": "unit.braised_guardian.name", "attack": guardian_attack, "health": guardian_health, "max_health": guardian_health, "guard": true, "ready": false, "art": "braised_bulwark"}
				player_board.append(guardian)
				next_unit_uid += 1
				_queue_juice_event({"kind": "summon", "uid": int(guardian.uid), "friendly": true})
		"dragonpepper_roast":
			_damage_enemy_hero(6)
		"leftover_stew":
			_heal_player(4)
			_draw_player_card()
		"sovereign_cleaver":
			_queue_juice_event({"kind": "legendary_cleave", "position": Vector2(640, 330), "amount": int(definition.value)})
			for unit in enemy_board.duplicate():
				_damage_unit(unit, int(definition.value), true, true)
			_remove_dead_units()
			_damage_enemy_hero(int(definition.value))
			_log(t("log.legendary_cleave"))
		"bell_last_service":
			var bell_bonus := int(definition.value)
			_heal_player(int(definition.heal))
			_queue_juice_event({"kind": "legendary_bell", "position": Vector2(640, 430), "amount": bell_bonus})
			for unit in player_board:
				unit.attack += bell_bonus
				unit.health += bell_bonus
				unit.max_health += bell_bonus
				unit.ready = true
				_queue_juice_event({"kind": "buff", "uid": int(unit.uid), "amount": bell_bonus})
			_log(t("log.legendary_bell"))
	_finish_played_card(runtime_card, definition)
	_trigger_mise_engine(definition)
	_render_battle()
	_check_end_state()


func _finish_played_card(runtime_card: Dictionary, definition: Dictionary) -> void:
	if definition.type == "dish":
		var remaining := int(runtime_card.get("servings", definition.get("servings", 1))) - 1
		_queue_juice_event({"kind": "serving_spent", "position": Vector2(640, 520), "remaining": remaining, "card_id": String(runtime_card.id)})
		_update_run_dish_servings(runtime_card.uid, remaining)
		if remaining > 0:
			runtime_card.servings = remaining
			player_discard.append(runtime_card)
			_log(t("log.servings_left", {"card": t(definition.name_key), "count": remaining}))
		else:
			_log(t("log.final_serving", {"card": t(definition.name_key)}))
	else:
		player_discard.append(runtime_card)


func _on_player_unit_pressed(board_index: int) -> void:
	if not _can_take_player_action() or board_index < 0 or board_index >= player_board.size():
		return
	if _has_pending_spell():
		if pending_action.get("effect") == "target_friend_buff":
			_resolve_targeted_spell(board_index, true, false)
		return
	var unit := player_board[board_index]
	if not unit.ready:
		banner_text = t("battle.unit_preheating", {"unit": t(unit.name_key).to_upper()})
		banner_color = MUTED
		var sleep_rect := _unit_visual_rect(unit)
		_queue_juice_event({"kind": "invalid", "position": sleep_rect.position + sleep_rect.size * 0.5, "message": t("battle.preheating")})
		_render_battle()
		return
	pending_action = {"kind": "attack", "board_index": board_index}
	banner_text = t("battle.choose_enemy_target")
	banner_color = EMBER
	_render_battle()


func _on_enemy_unit_pressed(board_index: int) -> void:
	if not _can_take_player_action() or board_index < 0 or board_index >= enemy_board.size():
		return
	if _has_pending_spell():
		if pending_action.get("effect") == "target_enemy_damage":
			_resolve_targeted_spell(board_index, false, false)
		return
	if pending_action.get("kind") != "attack":
		banner_text = t("battle.enemy_inspect", {"unit": t(enemy_board[board_index].name_key).to_upper(), "ingredient": _ingredient_label(enemy_board[board_index].get("ingredient", ""))})
		banner_color = MUTED
		_render_battle()
		return
	var guard_index := _first_guard_index(enemy_board)
	if guard_index >= 0 and board_index != guard_index:
		banner_text = t("battle.guard_blocks_target")
		banner_color = CRIMSON
		var guard_rect := _unit_visual_rect(enemy_board[guard_index])
		_queue_juice_event({"kind": "invalid", "position": guard_rect.position + guard_rect.size * 0.5, "message": t("battle.guard_blocks")})
		_render_battle()
		return
	var attacker_index := int(pending_action.board_index)
	if attacker_index < 0 or attacker_index >= player_board.size():
		pending_action.clear()
		return
	var attacker := player_board[attacker_index]
	var defender := enemy_board[board_index]
	attacker.ready = false
	_log(t("log.attacks", {"source": t(attacker.name_key), "target": t(defender.name_key)}))
	_resolve_unit_combat(attacker, defender, true)
	pending_action.clear()
	_remove_dead_units()
	_render_battle()
	_check_end_state()


func _on_enemy_hero_pressed() -> void:
	if not _can_take_player_action():
		return
	if _has_pending_spell():
		if pending_action.get("effect") == "target_enemy_damage":
			_resolve_targeted_spell(-1, false, true)
		return
	if pending_action.get("kind") != "attack":
		return
	if _first_guard_index(enemy_board) >= 0:
		banner_text = t("battle.guard_protects_chef")
		banner_color = CRIMSON
		var protecting := enemy_board[_first_guard_index(enemy_board)]
		var protecting_rect := _unit_visual_rect(protecting)
		_queue_juice_event({"kind": "invalid", "position": protecting_rect.position + protecting_rect.size * 0.5, "message": t("battle.guard_protects")})
		_render_battle()
		return
	var attacker_index := int(pending_action.board_index)
	if attacker_index < 0 or attacker_index >= player_board.size():
		pending_action.clear()
		return
	var attacker := player_board[attacker_index]
	attacker.ready = false
	_queue_juice_event({"kind": "attack", "uid": int(attacker.uid), "from_rect": _unit_visual_rect(attacker), "destination": enemy_hero_anchor, "art": String(attacker.art), "enemy": false})
	_damage_enemy_hero(attacker.attack)
	_log(t("log.strikes", {"source": t(attacker.name_key), "target": enemy_name, "damage": int(attacker.attack)}))
	pending_action.clear()
	_render_battle()
	_check_end_state()


func _resolve_targeted_spell(target_index: int, friendly: bool, enemy_hero: bool) -> void:
	var hand_index := _pending_spell_hand_index()
	if hand_index < 0 or hand_index >= player_hand.size():
		pending_action.clear()
		return
	var runtime_card := player_hand[hand_index]
	var definition := DB.card(runtime_card.id)
	var effect := String(definition.get("effect", ""))
	var valid_target := (
		(effect == "target_enemy_damage" and not friendly and (enemy_hero or (target_index >= 0 and target_index < enemy_board.size())))
		or (effect == "target_friend_buff" and friendly and not enemy_hero and target_index >= 0 and target_index < player_board.size())
	)
	if not valid_target:
		return
	if int(definition.cost) > player_mana:
		pending_action.clear()
		banner_text = t("battle.not_enough_mana")
		banner_color = CRIMSON
		var card_rect := _card_visual_rect(runtime_card)
		_queue_juice_event({"kind": "invalid", "position": card_rect.get_center(), "message": t("battle.not_enough_mana")})
		_render_battle()
		return
	var banner_before := banner_text
	var target_position := enemy_hero_anchor if enemy_hero else Vector2(640, 330)
	if friendly and target_index >= 0 and target_index < player_board.size():
		var friendly_rect := _unit_visual_rect(player_board[target_index])
		target_position = friendly_rect.position + friendly_rect.size * 0.5
	elif not enemy_hero and target_index >= 0 and target_index < enemy_board.size():
		var enemy_rect := _unit_visual_rect(enemy_board[target_index])
		target_position = enemy_rect.position + enemy_rect.size * 0.5
	var source_rect := _card_visual_rect(runtime_card)
	if not _pay_and_remove_hand_card(hand_index):
		pending_action.clear()
		return
	_queue_juice_event({"kind": "card_played", "card_id": runtime_card.id, "from_rect": source_rect, "destination": target_position, "cost": int(definition.cost)})
	if definition.effect == "target_enemy_damage":
		if enemy_hero:
			_damage_enemy_hero(definition.value)
			_log(t("log.deals_damage", {"source": t(definition.name_key), "damage": int(definition.value), "target": enemy_name}))
		elif target_index >= 0 and target_index < enemy_board.size():
			var target := enemy_board[target_index]
			_log(t("log.deals_damage", {"source": t(definition.name_key), "damage": int(definition.value), "target": t(target.name_key)}))
			_damage_unit(target, definition.value, true)
	elif definition.effect == "target_friend_buff" and friendly and target_index >= 0 and target_index < player_board.size():
		var target := player_board[target_index]
		target.attack += definition.value
		target.health += definition.value
		target.max_health += definition.value
		_queue_juice_event({"kind": "buff", "uid": int(target.uid), "position": target_position, "amount": int(definition.value)})
		_log(t("log.seasons", {"source": t(definition.name_key), "target": t(target.name_key), "value": int(definition.value)}))
	player_discard.append(runtime_card)
	_trigger_mise_engine(definition)
	pending_action.clear()
	if definition.effect == "target_enemy_damage" and not friendly and not enemy_hero:
		_tutorial_complete_action("target_enemy")
	if banner_text == banner_before:
		banner_text = t("battle.your_turn_mana", {"mana": player_mana})
		banner_color = TEAL
	_remove_dead_units()
	_render_battle()
	_check_end_state()


func use_hero_power() -> void:
	if not _can_take_player_action():
		return
	if _has_pending_spell():
		return
	var power_cost := _tweak_int(&"player.hero_power_cost", 2)
	if hero_power_used:
		banner_text = t("battle.chef_power_used")
		banner_color = MUTED
	elif player_mana < power_cost:
		banner_text = t("battle.hero_power_requires_mana", {"cost": power_cost})
		banner_color = CRIMSON
	else:
		_consume_tweak_int(&"player.hero_power_cost", 2)
		var power_armor := _consume_tweak_int(&"player.hero_power_armor", 2)
		var power_attack := _consume_tweak_int(&"player.hero_power_attack_bonus", 1)
		player_mana -= power_cost
		var armor_gained := _gain_player_armor(power_armor)
		next_summon_attack_bonus += power_attack
		hero_power_used = true
		_log(t("log.hero_power", {"armor": armor_gained}))
		banner_text = t("battle.next_ally_attack", {"attack": power_attack})
		banner_color = TEAL
		_queue_juice_event({"kind": "hero_power"})
	_render_battle()


func _pay_and_remove_hand_card(hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= player_hand.size():
		return false
	var definition := DB.card(player_hand[hand_index].id)
	if int(definition.cost) > player_mana:
		return false
	player_mana -= definition.cost
	player_hand.pop_at(hand_index)
	return true


func _summon_unit(card_id: String, friendly: bool, trigger_on_play: bool) -> Dictionary:
	var definition := DB.card(card_id)
	var unit := {
		"id": card_id,
		"name_key": definition.name_key,
		"attack": definition.attack,
		"health": definition.health,
		"max_health": definition.health,
		"guard": definition.get("guard", false),
		"ready": false,
		"art": definition.art,
		"ingredient": definition.get("ingredient", ""),
		"uid": next_unit_uid,
	}
	next_unit_uid += 1
	if friendly:
		unit.attack = maxi(0, roundi(float(unit.attack) * _consume_tweak_float(&"player.unit_attack_multiplier", 1.0)))
		unit.health = maxi(1, roundi(float(unit.health) * _consume_tweak_float(&"player.unit_health_multiplier", 1.0)))
		unit.max_health = unit.health
	else:
		unit.attack = maxi(0, roundi(float(unit.attack) * _consume_tweak_float(&"enemy.unit_attack_multiplier", 1.0)))
		unit.health = maxi(1, roundi(float(unit.health) * _consume_tweak_float(&"enemy.unit_health_multiplier", 1.0)))
		unit.max_health = unit.health
	if friendly and next_summon_attack_bonus > 0:
		unit.attack += next_summon_attack_bonus
		next_summon_attack_bonus = 0
	if not friendly:
		var passive_strength := roundi(_consume_tweak_float(&"enemy.passive_strength_multiplier", 1.0))
		if current_encounter_id == "picklemancer" and enemy_first_summon:
			unit.health += passive_strength
			unit.max_health += passive_strength
		elif current_encounter_id == "ember_butcher" and enemy_first_summon:
			unit.attack += passive_strength
		enemy_first_summon = false
	if friendly:
		player_board.append(unit)
	else:
		enemy_board.append(unit)
	_queue_juice_event({
		"kind": "summon",
		"uid": int(unit.uid),
		"friendly": friendly,
		"card_id": card_id,
		"rarity": String(definition.get("rarity", "common")),
	})
	if trigger_on_play:
		_resolve_on_play(definition, friendly, unit)
	return unit


func _resolve_on_play(definition: Dictionary, friendly: bool, source_unit: Dictionary = {}) -> void:
	if not String(definition.get("effect", "")).is_empty():
		_queue_juice_event({"kind": "trigger", "uid": int(source_unit.get("uid", -1)), "friendly": friendly, "name": t(String(definition.get("name_key", "juice.trigger")))})
	match definition.get("effect", ""):
		"armor_on_play":
			_gain_player_armor(int(definition.value))
		"hero_damage_on_play":
			_damage_enemy_hero(definition.value)
		"broth_on_play":
			if _draw_player_card():
				_heal_player(1)
		"enemy_on_play_damage":
			var enemy_before := enemy_health
			enemy_health = maxi(0, enemy_health - definition.value)
			if enemy_health < enemy_before:
				_queue_juice_event({"kind": "hero_damage", "side": "enemy", "amount": enemy_before - enemy_health})
		"enemy_heal_on_play":
			var enemy_heal_before := enemy_health
			enemy_health = mini(enemy_max_health, enemy_health + definition.value)
			if enemy_health > enemy_heal_before:
				_queue_juice_event({"kind": "heal", "side": "enemy", "amount": enemy_health - enemy_heal_before})


func _resolve_unit_combat(attacker: Dictionary, defender: Dictionary, player_attacks: bool) -> void:
	var attacker_damage := int(attacker.attack)
	var defender_damage := int(defender.attack)
	var attacker_rect := _unit_visual_rect(attacker)
	var defender_rect := _unit_visual_rect(defender)
	_queue_juice_event({
		"kind": "attack",
		"uid": int(attacker.uid),
		"from_rect": attacker_rect,
		"destination": defender_rect.position + defender_rect.size * 0.5,
		"art": String(attacker.art),
		"enemy": not player_attacks,
	})
	_damage_unit(defender, attacker_damage, player_attacks)
	_damage_unit(attacker, defender_damage, false)


func _damage_unit(unit: Dictionary, amount: int, enemy_target: bool, force_precise_harvest := false) -> void:
	amount = _consume_player_damage_amount(amount) if enemy_target else _enemy_damage_amount(amount)
	var before := int(unit.health)
	var rect := _unit_visual_rect(unit)
	var friendly := player_board.has(unit)
	unit.health -= amount
	var dead: bool = unit.health <= 0
	_queue_juice_event({
		"kind": "unit_damage",
		"uid": int(unit.get("uid", -1)),
		"position": rect.position + rect.size * 0.5,
		"rect": rect,
		"amount": amount,
		"excess_damage": maxi(0, amount - before),
		"health_before": before,
		"max_health": int(unit.get("max_health", before)),
		"art": String(unit.get("art", "")),
		"friendly": friendly,
		"dead": dead,
	})
	if enemy_target and unit.health <= 0:
		_record_harvest(unit, amount, before, force_precise_harvest)
	if dead:
		_queue_juice_event({
			"kind": "death",
			"uid": int(unit.get("uid", -1)),
			"position": rect.position + rect.size * 0.5,
			"friendly": friendly,
			"side": "player" if friendly else "enemy",
		})


func _record_harvest(unit: Dictionary, amount: int, health_before: int, force_precise := false) -> void:
	var ingredient := String(unit.get("ingredient", ""))
	if ingredient.is_empty():
		return
	var tolerance := _consume_tweak_int(&"gameplay.precise_cut_tolerance", 0)
	if force_precise or (amount >= health_before and amount <= health_before + tolerance):
		pantry[ingredient] = int(pantry.get(ingredient, 0)) + 1
		precise_kills += 1
		banner_text = t("battle.precise_harvest", {"ingredient": _ingredient_name(ingredient).to_upper()})
		banner_color = TEAL
		var precise_rect := _unit_visual_rect(unit)
		_queue_juice_event({"kind": "precise_cut", "position": precise_rect.position + precise_rect.size * 0.5, "ingredient": ingredient})
		_log(t("log.precise_harvest", {"ingredient": _ingredient_name(ingredient)}))
	elif amount > health_before:
		overkills += 1
		banner_text = t("battle.overkill_ruined")
		banner_color = CRIMSON
		var overkill_rect := _unit_visual_rect(unit)
		_queue_juice_event({"kind": "overkill", "position": overkill_rect.position + overkill_rect.size * 0.5, "ingredient": ingredient})
		_log(t("log.overkill_ruined", {"unit": t(unit.name_key)}))


func _trigger_mise_engine(played_definition: Dictionary) -> void:
	if int(played_definition.get("cost", MAX_MANA + 1)) > 2:
		return
	var mise_unit: Dictionary = {}
	for unit in player_board:
		if String(unit.get("id", "")) == "mise_the_thousand_handed" and int(unit.get("health", 0)) > 0:
			mise_unit = unit
			break
	if mise_unit.is_empty():
		return
	var mana_before := player_mana
	player_mana = mini(player_max_mana, player_mana + 1)
	var mana_restored := player_mana - mana_before
	_queue_juice_event({
		"kind": "legendary_engine",
		"uid": int(mise_unit.uid),
		"position": _unit_visual_rect(mise_unit).get_center(),
		"amount": mana_restored,
	})
	_draw_player_card()
	_log(t("log.legendary_engine"))


func _remove_dead_units() -> void:
	var living_player: Array[Dictionary] = []
	for unit in player_board:
		if unit.health > 0:
			living_player.append(unit)
	player_board = living_player
	var living_enemy: Array[Dictionary] = []
	for unit in enemy_board:
		if unit.health > 0:
			living_enemy.append(unit)
	enemy_board = living_enemy


func _damage_player(amount: int, enemy_source := false) -> void:
	if enemy_source:
		amount = _enemy_damage_amount(amount)
	var remaining := amount
	if player_armor > 0:
		var armor_before := player_armor
		var absorbed: int = mini(player_armor, remaining)
		player_armor -= absorbed
		remaining -= absorbed
		if absorbed > 0:
			_queue_juice_event({"kind": "armor_absorb", "side": "player", "amount": absorbed})
		if armor_before > 0 and player_armor == 0:
			_queue_juice_event({"kind": "armor_break", "side": "player", "amount": armor_before})
	var before := player_health
	player_health = maxi(0, player_health - remaining)
	if player_health < before:
		_queue_juice_event({"kind": "hero_damage", "side": "player", "amount": before - player_health})


func _damage_enemy_hero(amount: int) -> void:
	amount = _consume_player_damage_amount(amount)
	var remaining := amount
	if enemy_armor > 0:
		var absorbed: int = mini(enemy_armor, remaining)
		enemy_armor -= absorbed
		remaining -= absorbed
		if absorbed > 0:
			_queue_juice_event({"kind": "armor_absorb", "side": "enemy", "amount": absorbed})
	var before := enemy_health
	enemy_health = maxi(0, enemy_health - remaining)
	if enemy_health < before:
		_queue_juice_event({"kind": "hero_damage", "side": "enemy", "amount": before - enemy_health})
	var enrage_threshold := _consume_tweak_float(&"enemy.enrage_threshold", 0.5)
	if current_encounter_id == "banquet_tyrant" and not boss_enraged and enemy_health <= roundi(enemy_max_health * enrage_threshold):
		boss_enraged = true
		var enrage_bonus := _consume_tweak_int(&"enemy.enrage_stat_bonus", 1)
		for unit in enemy_board:
			unit.attack += enrage_bonus
			unit.health += enrage_bonus
			unit.max_health += enrage_bonus
		_queue_juice_event({"kind": "boss_enrage"})
		_log(t("log.tyrant_enrage", {"value": enrage_bonus}))


func _consume_player_damage_amount(amount: int) -> int:
	_consume_tweak_float(&"player.outgoing_damage_multiplier", 1.0)
	_consume_tweak_float(&"enemy.incoming_damage_multiplier", 1.0)
	return _player_damage_amount(amount)


func _player_damage_amount(amount: int) -> int:
	var multiplier := _tweak_float(&"player.outgoing_damage_multiplier", 1.0) * _tweak_float(&"enemy.incoming_damage_multiplier", 1.0)
	return 0 if amount <= 0 or multiplier <= 0.0 else maxi(1, roundi(float(amount) * multiplier))


func _enemy_damage_amount(amount: int) -> int:
	var multiplier := _consume_tweak_float(&"enemy.outgoing_damage_multiplier", 1.0)
	return 0 if amount <= 0 or multiplier <= 0.0 else maxi(1, roundi(float(amount) * multiplier))


func _gain_player_armor(base_amount: int) -> int:
	var gained := maxi(0, roundi(float(base_amount) * _consume_tweak_float(&"player.armor_gain_multiplier", 1.0)))
	player_armor += gained
	if gained > 0:
		_queue_juice_event({"kind": "armor", "side": "player", "amount": gained})
	return gained


func _heal_player(base_amount: int) -> int:
	var requested := maxi(0, roundi(float(base_amount) * _consume_tweak_float(&"player.healing_multiplier", 1.0)))
	var before := player_health
	player_health = mini(player_max_health, player_health + requested)
	var healed := player_health - before
	if healed > 0:
		_queue_juice_event({"kind": "heal", "side": "player", "amount": healed})
	return healed


func _draw_specific(card_id: String) -> bool:
	for index in range(player_deck.size()):
		if player_deck[index].id == card_id:
			player_hand.append(player_deck.pop_at(index))
			return true
	return _draw_player_card()


func _draw_player_card() -> bool:
	if player_hand.size() >= _consume_tweak_int(&"gameplay.max_hand_size", MAX_HAND):
		if not player_deck.is_empty():
			var burned: Dictionary = player_deck.pop_back()
			_log(t("log.card_burned", {"card": t(DB.card(burned.id).name_key)}))
			_queue_juice_event({"kind": "burn", "card_id": String(burned.id), "position": _target_battle_zone(&"player_deck").get_center()})
		return true
	if player_deck.is_empty():
		if not player_discard.is_empty():
			player_deck = player_discard.duplicate(true)
			player_discard.clear()
			_shuffle_gameplay(player_deck)
			_log(t("log.reshuffle"))
			_queue_juice_event({"kind": "shuffle", "position": _target_battle_zone(&"player_deck").get_center()})
		else:
			fatigue += 1
			var fatigue_damage := _consume_tweak_int(&"gameplay.fatigue_base_damage", 1) + fatigue - 1
			_damage_player(fatigue_damage)
			_log(t("log.fatigue", {"damage": fatigue_damage}))
			_queue_juice_event({"kind": "fatigue", "side": "player", "amount": fatigue_damage})
			return player_health > 0
	var drawn: Dictionary = player_deck.pop_back()
	player_hand.append(drawn)
	var uid := int(drawn.get("uid", -1))
	if uid >= 0 and screen_name == "battle" and not debug_fast and not suppress_juice and juice != null:
		pending_draw_reveals[uid] = true
	_queue_juice_event({"kind": "draw", "card_id": String(drawn.id), "uid": uid})
	return true


func _draw_enemy_card() -> void:
	if enemy_hand.size() >= _tweak_int(&"gameplay.max_hand_size", MAX_HAND):
		return
	if enemy_deck.is_empty():
		enemy_deck = enemy_discard.duplicate(true)
		enemy_discard.clear()
		_shuffle_gameplay(enemy_deck)
	if not enemy_deck.is_empty():
		enemy_hand.append(enemy_deck.pop_back())


func _check_end_state() -> bool:
	if not run_active:
		return true
	if enemy_health <= 0:
		_on_battle_victory()
		return true
	if player_health <= 0:
		_finish_run(false)
		return true
	return false


func _on_battle_victory() -> void:
	input_locked = true
	is_player_turn = false
	completed_battles = maxi(completed_battles, battle_number)
	if battle_number >= 3:
		_finish_run(true)
	else:
		battle_generation += 1
		battle_finished.emit(true)
		_enter_kitchen()


func _enter_kitchen() -> void:
	_skip_tutorial()
	screen_name = "kitchen"
	service_history_open = false
	var kitchen_heal := _consume_tweak_int(&"gameplay.kitchen_heal", 2)
	var restored := _heal_player(kitchen_heal)
	player_armor = 0
	reward_done = false
	deck_overlay_open = false
	reward_options.clear()
	reward_revealed.clear()
	var reward_count := _consume_tweak_int(&"gameplay.reward_choices", 3)
	for reward_id in _available_legendary_rewards(reward_count):
		reward_options.append(reward_id)
		reward_revealed[reward_id] = false
	banner_text = t("kitchen.break_restored", {"health": restored})
	banner_color = TEAL
	_render_kitchen()
	screen_changed.emit(screen_name)


func _available_legendary_rewards(reward_count: int) -> Array[String]:
	var candidates: Array[String] = []
	for card_id in DB.LEGENDARY_REWARDS:
		if not claimed_legendary_ids.has(card_id):
			candidates.append(card_id)
	candidates.resize(mini(maxi(0, reward_count), candidates.size()))
	return candidates


func _select_reward(card_id: String) -> void:
	if reward_done or not reward_options.has(card_id) or claimed_legendary_ids.has(card_id):
		return
	_add_card_to_run(card_id)
	claimed_legendary_ids.append(card_id)
	reward_done = true
	banner_text = t("kitchen.added_to_deck", {"card": t(DB.card(card_id).name_key).to_upper()})
	banner_color = TEAL
	_queue_juice_event({"kind": "reward", "position": reward_anchors.get(card_id, Vector2(1074, 330)), "card_id": card_id})
	_render_kitchen()


func _reveal_reward(card_id: String) -> void:
	if reward_done or bool(reward_revealed.get(card_id, false)):
		return
	reward_revealed[card_id] = true
	_queue_juice_event({"kind": "reward_reveal", "position": reward_anchors.get(card_id, Vector2(1074, 330)), "card_id": card_id})
	_render_kitchen()


func _reveal_all_rewards() -> void:
	if reward_done:
		return
	for card_id in reward_options:
		reward_revealed[card_id] = true
	_queue_juice_event({"kind": "reward_reveal", "position": Vector2(1074, 330), "amount": reward_options.size()})
	_render_kitchen()


func _skip_reward() -> void:
	if reward_done:
		return
	reward_done = true
	banner_text = t("kitchen.reward_skipped")
	banner_color = MUTED
	_render_kitchen()


func _cook_recipe(recipe_id: String) -> void:
	if not _can_cook(recipe_id):
		banner_text = t("kitchen.missing_ingredients")
		banner_color = CRIMSON
		_queue_juice_event({"kind": "invalid", "position": recipe_anchors.get(recipe_id, Vector2(774, 360)), "message": t("kitchen.missing_ingredients")})
		_render_kitchen()
		return
	var recipe: Dictionary = DB.RECIPES[recipe_id]
	var spent_ingredients: Array[String] = []
	if recipe.has("cost"):
		for ingredient in recipe.cost:
			var ingredient_cost := _scaled_recipe_cost(int(recipe.cost[ingredient]))
			pantry[ingredient] -= ingredient_cost
			for count_index in range(ingredient_cost):
				spent_ingredients.append(String(ingredient))
	else:
		var remaining := _scaled_recipe_cost(int(recipe.cost_any))
		for ingredient in ["fungus", "herb", "meat", "ember"]:
			while remaining > 0 and pantry[ingredient] > 0:
				pantry[ingredient] -= 1
				remaining -= 1
				spent_ingredients.append(String(ingredient))
	_add_card_to_run(recipe.card)
	dishes_cooked += 1
	banner_text = t("kitchen.cooked", {"dish": t(recipe.name_key).to_upper()})
	banner_color = EMBER
	_queue_juice_event({"kind": "cook", "recipe_id": recipe_id, "position": recipe_anchors.get(recipe_id, Vector2(774, 360)), "ingredients": spent_ingredients})
	_render_kitchen()


func _can_cook(recipe_id: String) -> bool:
	var recipe: Dictionary = DB.RECIPES[recipe_id]
	if recipe.has("cost"):
		for ingredient in recipe.cost:
			if pantry.get(ingredient, 0) < _scaled_recipe_cost(int(recipe.cost[ingredient])):
				return false
		return true
	var total := 0
	for value in pantry.values():
		total += int(value)
	return total >= _scaled_recipe_cost(int(recipe.cost_any))


func _scaled_recipe_cost(base_cost: int) -> int:
	return maxi(1, ceili(float(base_cost) * _tweak_float(&"gameplay.recipe_cost_multiplier", 1.0)))


func _continue_from_kitchen() -> void:
	if not reward_done:
		banner_text = t("kitchen.choose_or_skip_first")
		banner_color = CRIMSON
		_queue_juice_event({"kind": "invalid", "position": Vector2(1074, 555), "message": t("kitchen.choose_or_skip")})
		_render_kitchen()
		return
	if battle_number == 1:
		_show_route_selection()
	else:
		battle_number = 3
		_start_battle("banquet_tyrant")


func _show_route_selection() -> void:
	screen_name = "route"
	banner_text = t("route.choose_second_course")
	banner_color = EMBER
	_render_route()
	screen_changed.emit(screen_name)


func _choose_route(encounter_id: String) -> void:
	selected_route = encounter_id
	battle_number = 2
	_start_battle(encounter_id)
	_queue_juice_event({"kind": "route", "name": t(DB.encounter(encounter_id).name_key)})


func _finish_run(victory: bool) -> void:
	if not run_active:
		return
	run_active = false
	battle_generation += 1
	opening_deal_generation += 1
	opening_hand_in_progress = false
	_leave_pause_state()
	screen_name = "end"
	input_locked = false
	is_player_turn = false
	run_result = "victory" if victory else "defeat"
	lifetime.runs += 1
	if victory:
		lifetime.wins += 1
		lifetime.streak += 1
		lifetime.best_streak = maxi(lifetime.best_streak, lifetime.streak)
	else:
		lifetime.streak = 0
	var submission := _make_run_submission(victory)
	last_run_score = LEADERBOARD_CLIENT.calculate_score(submission)
	last_run_submission_id = String(submission.submission_id)
	last_run_ranked_eligible = run_ranked_eligible
	if run_ranked_eligible:
		pending_global_submissions.append(submission.duplicate(true))
	_record_local_score(submission)
	_save_stats()
	battle_finished.emit(victory)
	_queue_juice_event({"kind": "victory" if victory else "defeat"})
	_render_end()
	screen_changed.emit(screen_name)
	call_deferred("_submit_pending_global")


func _make_run_submission(victory: bool) -> Dictionary:
	return {
		"submission_id": "%d-%d-%d" % [Time.get_unix_time_from_system(), submission_rng.randi(), submission_rng.randi()],
		"name": LEADERBOARD_CLIENT.normalize_chef_name(player_name),
		"victory": victory,
		"battles_cleared": _battles_cleared(victory),
		"precise_cuts": precise_kills,
		"ingredients_ruined": overkills,
		"dishes_cooked": dishes_cooked,
		"health_remaining": player_health,
		"score_version": LEADERBOARD_CLIENT.SCORE_VERSION,
	}


func _battles_cleared(_victory: bool) -> int:
	return clampi(completed_battles, 0, 3)


func _record_local_score(submission: Dictionary) -> void:
	var record: Dictionary = submission.duplicate(true)
	record.score = LEADERBOARD_CLIENT.calculate_score(submission)
	record.created_at = Time.get_datetime_string_from_system(true)
	record.ranked_eligible = run_ranked_eligible
	local_scores.append(record)
	LEADERBOARD_CLIENT.sort_entries(local_scores)
	if local_scores.size() > LEADERBOARD_CLIENT.LOCAL_LIMIT:
		local_scores.resize(LEADERBOARD_CLIENT.LOCAL_LIMIT)


func _sync_global_leaderboard() -> void:
	if leaderboard == null:
		return
	if not pending_global_submissions.is_empty():
		_submit_pending_global()
	else:
		leaderboard.fetch_scores()


func _submit_pending_global() -> void:
	if leaderboard != null and not pending_global_submissions.is_empty():
		leaderboard.submit_score(pending_global_submissions.front())


func _on_leaderboard_state_changed() -> void:
	if leaderboard.status == "ready" and leaderboard.last_operation == "submit" and not pending_global_submissions.is_empty():
		pending_global_submissions.pop_front()
		_save_stats()
		if not pending_global_submissions.is_empty():
			call_deferred("_submit_pending_global")
	if screen_name not in ["title", "end"]:
		return
	if chef_name_input != null and is_instance_valid(chef_name_input) and chef_name_input.has_focus():
		return
	if screen_name == "title":
		_render_title()
	else:
		_render_end()


func _commit_player_name(value: String) -> void:
	var normalized := LEADERBOARD_CLIENT.normalize_chef_name(value)
	if player_name == normalized:
		return
	player_name = normalized
	_save_stats()


func _add_card_to_run(card_id: String) -> Dictionary:
	var definition := DB.card(card_id)
	var runtime := {
		"id": card_id,
		"uid": next_card_uid,
		"servings": int(definition.get("servings", 0)),
	}
	next_card_uid += 1
	run_deck.append(runtime)
	return runtime


func _make_runtime_card(card_id: String, with_uid: bool = true) -> Dictionary:
	var definition := DB.card(card_id)
	var runtime := {"id": card_id, "servings": int(definition.get("servings", 0))}
	if with_uid:
		runtime.uid = next_card_uid
		next_card_uid += 1
	return runtime


func _update_run_dish_servings(uid: int, remaining: int) -> void:
	for index in range(run_deck.size()):
		if int(run_deck[index].uid) == uid:
			if remaining <= 0:
				run_deck.remove_at(index)
			else:
				run_deck[index].servings = remaining
			return


func _can_take_player_action() -> bool:
	return screen_name == "battle" and is_player_turn and not input_locked and pending_draw_reveals.is_empty() and not service_history_open


func _has_remaining_player_action() -> bool:
	if not _can_take_player_action():
		return false
	if not pending_action.is_empty():
		return true
	var power_cost := _tweak_int(&"player.hero_power_cost", 2)
	if not hero_power_used and player_mana >= power_cost:
		return true
	for unit in player_board:
		if bool(unit.get("ready", false)):
			return true
	for runtime_card in player_hand:
		var definition := DB.card(String(runtime_card.id))
		if int(definition.cost) > player_mana:
			continue
		if String(definition.type) == "unit" and player_board.size() >= _tweak_int(&"gameplay.max_board_slots", MAX_BOARD):
			continue
		if String(definition.get("effect", "")) == "target_friend_buff" and player_board.is_empty():
			continue
		return true
	return false


func _enemy_has_ingredient(ingredient: String) -> bool:
	for unit in enemy_board:
		if unit.get("ingredient", "") == ingredient:
			return true
	return false


func _first_guard_index(board: Array[Dictionary]) -> int:
	if not _tweak_bool(&"gameplay.guard_enabled", true):
		return -1
	for index in range(board.size()):
		if board[index].get("guard", false):
			return index
	return -1


func _ingredient_label(ingredient: String) -> String:
	return t("ingredient.none") if ingredient.is_empty() else t("ingredient.label", {"ingredient": _ingredient_name(ingredient).to_upper()})


func _ingredient_name(ingredient: String) -> String:
	return t("ingredient.%s" % ingredient)


func _log(message: String) -> void:
	combat_log.push_front(message)
	var retained := _tweak_int(&"ui.combat_log_entries", 5)
	if combat_log.size() > retained:
		combat_log.resize(retained)
	print("[EMBERPAN] ", message)


func _delay(seconds: float) -> void:
	if debug_fast:
		await get_tree().create_timer(0.0, false).timeout
	else:
		var scaled := seconds * _consume_tweak_float(&"gameplay.turn_delay_scale", 1.0)
		if scaled <= 0.0:
			await get_tree().create_timer(0.0, false).timeout
		else:
			await get_tree().create_timer(scaled, false).timeout


func _toggle_motion() -> void:
	var modes := [JUICE_PROFILES.MOTION_FULL, JUICE_PROFILES.MOTION_REDUCED, JUICE_PROFILES.MOTION_MINIMAL]
	motion_mode = modes[(modes.find(motion_mode) + 1) % modes.size()]
	reduce_motion = motion_mode != JUICE_PROFILES.MOTION_FULL
	_apply_tweak_live_state()
	banner_text = t("settings.motion_enabled", {"mode": t("settings.motion.%s" % motion_mode).to_upper()})
	_save_stats()
	_render_current_screen()


func _cycle_shake() -> void:
	shake_intensity = 0.5 if shake_intensity > 0.75 else 0.0 if shake_intensity > 0.1 else 1.0
	_apply_tweak_live_state()
	_save_stats()
	_render_current_screen()


func _cycle_flash() -> void:
	flash_intensity = 0.5 if flash_intensity > 0.75 else 0.0 if flash_intensity > 0.1 else 1.0
	_apply_tweak_live_state()
	_save_stats()
	_render_current_screen()


func _cycle_particles() -> void:
	particle_density = 0.5 if particle_density > 0.75 else 0.0 if particle_density > 0.1 else 1.0
	_apply_tweak_live_state()
	_save_stats()
	_render_current_screen()


func _cycle_animation_speed() -> void:
	animation_speed = 1.5 if animation_speed < 1.25 else 2.0 if animation_speed < 1.75 else 1.0
	_apply_tweak_live_state()
	_save_stats()
	_render_current_screen()


func _toggle_acceleration() -> void:
	auto_accelerate = not auto_accelerate
	_apply_tweak_live_state()
	_save_stats()
	_render_current_screen()


func _toggle_captions() -> void:
	captions_enabled = not captions_enabled
	_apply_tweak_live_state()
	_save_stats()
	_render_current_screen()


func _intensity_name(value: float) -> String:
	return t("common.off") if value <= 0.1 else t("common.low") if value < 0.75 else t("common.full")


func _toggle_sound() -> void:
	sound_muted = not sound_muted
	_apply_tweak_live_state()
	if juice != null:
		if not _effective_sound_muted():
			juice.play_sfx("click", -8.0)
	_save_stats()
	_render_current_screen()


func _animate_reflow(control: Control, previous_rect: Rect2, target_rect: Rect2, entry_anchor: Vector2) -> void:
	if debug_fast or suppress_juice or not is_instance_valid(control):
		return
	var is_new := previous_rect.size == Vector2.ZERO
	var start_position := previous_rect.position if not is_new else entry_anchor - target_rect.size * 0.5
	if start_position.distance_to(target_rect.position) < 1.0 and not is_new:
		return
	control.position = target_rect.position if reduce_motion else start_position
	if is_new:
		control.scale = Vector2(0.72, 0.72) if not reduce_motion else Vector2(0.96, 0.96)
		control.modulate.a = 0.35
	var duration_scale := JUICE_PROFILES.duration_scale(motion_mode, animation_speed)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK if is_new else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "position", target_rect.position, (BOARD_SERVE_MOVE_SECONDS if is_new else BOARD_REFLOW_SECONDS) * duration_scale)
	tween.tween_property(control, "scale", Vector2.ONE, (BOARD_SERVE_SETTLE_SECONDS if is_new else BOARD_REFLOW_SECONDS) * duration_scale)
	tween.tween_property(control, "modulate:a", 1.0, (BOARD_SERVE_FADE_SECONDS if is_new else BOARD_REFLOW_SECONDS) * duration_scale)
	if is_new and juice != null:
		juice.play_sfx("draw" if control.get_meta("juice_kind", "") == "card" else "summon", -12.0)


func _post_render() -> void:
	_presented_modal = _modal_key()
	if juice == null:
		return
	if last_rendered_screen != screen_name:
		var old_screen := last_rendered_screen
		last_rendered_screen = screen_name
		juice.set_ambient("battle" if screen_name == "battle" else "kitchen" if screen_name in ["kitchen", "route"] else "title" if screen_name == "title" else "")
		if not debug_fast:
			screen_layer.modulate.a = 0.0
			var tween := create_tween().set_parallel(true)
			tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(screen_layer, "modulate:a", 1.0, 0.22 if reduce_motion else 0.38)
			if not old_screen.is_empty():
				juice.flash(TEAL if screen_name == "kitchen" else EMBER, 0.1, 0.24)
	call_deferred("_refresh_target_line")
	call_deferred("_pulse_legal_targets")
	call_deferred("_flush_juice_events")


func _refresh_target_line() -> void:
	if target_line == null or screen_name != "battle" or pending_action.is_empty():
		if target_line != null:
			target_line.dismiss()
		return
	var source: Control
	var color := EMBER
	if pending_action.get("kind") == "spell":
		var hand_index := _pending_spell_hand_index()
		if hand_index >= 0 and hand_index < player_hand.size():
			source = card_nodes_by_uid.get(int(player_hand[hand_index].uid))
		if pending_action.get("effect") == "target_friend_buff":
			color = TEAL
	elif pending_action.get("kind") == "attack":
		var board_index := int(pending_action.get("board_index", -1))
		if board_index >= 0 and board_index < player_board.size():
			source = unit_nodes_by_uid.get(int(player_board[board_index].uid))
	if source == null or not is_instance_valid(source):
		target_line.dismiss()
		return
	var source_rect := _control_rect_in_layer(source, target_line)
	target_line.configure(source_rect.get_center(), color)


func _pulse_legal_targets() -> void:
	if tutorial_active or debug_fast or reduce_motion:
		return
	for node in unit_nodes_by_uid.values():
		if not is_instance_valid(node) or not node.get_meta("legal_target", false):
			continue
		var tween: Tween = node.create_tween().set_loops()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(node, "modulate", Color(1.12, 1.08, 0.92, 1.0), 0.42)
		tween.tween_property(node, "modulate", Color.WHITE, 0.42)
	if enemy_hero_button != null and is_instance_valid(enemy_hero_button) and enemy_hero_button.get_meta("legal_target", false):
		var hero_tween: Tween = enemy_hero_button.create_tween().set_loops()
		hero_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		hero_tween.tween_property(enemy_hero_button, "modulate", Color(1.12, 1.08, 0.92, 1.0), 0.42)
		hero_tween.tween_property(enemy_hero_button, "modulate", Color.WHITE, 0.42)


func _queue_juice_event(event: Dictionary) -> void:
	_record_juice_history(event)
	if cursor_director != null and String(event.get("kind", "")) == "invalid":
		cursor_director.flash("blocked")
	if debug_fast or suppress_juice or juice == null:
		return
	juice_events.append(event.duplicate(true))
	call_deferred("_flush_juice_events")


func _record_juice_history(payload: Dictionary) -> void:
	var kind := String(payload.get("kind", ""))
	if kind in ["", "ready", "turn", "battle_start"]:
		return
	var source := t("history.source.chef")
	var target := t("history.target.board")
	var event_name := t("history.event.%s" % kind)
	var value := int(payload.get("amount", payload.get("cost", payload.get("value", 0))))
	var color := MUTED
	if kind in ["unit_damage", "hero_damage", "death", "overkill", "defeat"]:
		color = CRIMSON
		target = t("history.target.%s" % String(payload.get("side", "unit")))
	elif kind in ["heal", "buff", "precise_cut", "reward", "victory"]:
		color = TEAL
	elif kind in ["legendary_engine", "legendary_cleave", "legendary_bell"]:
		color = GOLD
	elif kind in ["armor", "armor_absorb", "hero_power", "cook", "card_played", "route"]:
		color = EMBER
	if kind == "card_played":
		var card := DB.card(String(payload.get("card_id", "")))
		source = t(String(card.get("name_key", "history.source.card"))).to_upper()
		target = t("history.target.table")
		value = -value
	elif kind == "summon":
		source = t("history.source.ally" if bool(payload.get("friendly", false)) else "history.source.enemy")
		target = t("history.target.plate")
	elif kind == "draw":
		source = t("history.source.deck")
		target = t("history.target.hand")
	elif kind == "precise_cut":
		source = t("history.source.exact")
		var ingredient := String(payload.get("ingredient", ""))
		target = _ingredient_name(ingredient).to_upper() if not ingredient.is_empty() else t("history.target.pantry")
	elif kind == "cook":
		source = t("history.source.pantry")
		target = t("history.target.dish")
	elif kind == "legendary_engine":
		source = t("card.mise_the_thousand_handed.name").to_upper()
		target = t("history.target.hand")
	elif kind == "legendary_cleave":
		source = t("card.the_sovereign_cleaver.name").to_upper()
		target = t("history.target.enemy")
	elif kind == "legendary_bell":
		source = t("card.bell_of_the_last_service.name").to_upper()
		target = t("history.target.player")
	var highlight_red := (kind == "hero_damage" and String(payload.get("side", "")) == "player") or (kind == "death" and bool(payload.get("friendly", false)))
	_record_history(source, event_name, target, value, color, highlight_red)


func _record_history(source: String, event_name: String, target: String, value: int, color: Color, highlight_red := false) -> void:
	var detail := t("history.detail", {"source": source, "event": event_name, "target": target})
	if auto_accelerate and not history_events.is_empty():
		var prior: Dictionary = history_events.back()
		if prior.source == source and prior.event == event_name and prior.target == target:
			prior.value = int(prior.value) + value
			prior.detail = t("history.repeated", {"detail": detail})
			history_events[history_events.size() - 1] = prior
			return
	history_events.append({"source": source, "event": event_name, "target": target, "value": value, "color": color, "detail": detail, "highlight_red": highlight_red})


func _flush_juice_events() -> void:
	if juice_processing or juice_events.is_empty() or juice == null:
		return
	juice_processing = true
	var prior_kind := ""
	var repeat_index := 0
	while not juice_events.is_empty():
		var event: Dictionary = juice_events.pop_front()
		var current_kind := String(event.get("kind", ""))
		repeat_index = repeat_index + 1 if current_kind == prior_kind else 0
		prior_kind = current_kind
		juice_repeat_speed = 1.0 / (1.0 + repeat_index * 0.22) if auto_accelerate else 1.0
		await _play_juice_event(event)
	juice_repeat_speed = 1.0
	juice_processing = false


func _play_juice_event(event: Dictionary) -> void:
	if juice == null:
		return
	var kind := String(event.get("kind", ""))
	var position := _juice_event_position(event)
	match kind:
		"battle_start":
			juice.begin_signature()
			juice.flash(EMBER, 0.16, 0.34)
			var battle_center := _screen_point_in_juice(Vector2(640, 350))
			juice.float_text(battle_center, t("juice.service_begins"), EMBER, 27, true)
			juice.contact_ring(battle_center, EMBER, 105.0, true)
			juice.play_sfx("turn", -8.0)
			await _juice_wait(0.34)
			juice.end_signature()
		"turn":
			var friendly := bool(event.get("friendly", true))
			juice.float_text(_screen_point_in_juice(Vector2(640, 338)), t("juice.your_turn" if friendly else "juice.enemy_turn"), TEAL if friendly else CRIMSON, 22, true)
			juice.contact_ring(_screen_point_in_juice(Vector2(640, 348)), TEAL if friendly else CRIMSON, 82.0)
			juice.play_sfx("turn", -10.0)
			await _juice_wait(0.16)
		"draw":
			juice.play_sfx("draw", -10.0)
			await _animate_draw_to_hand(int(event.get("uid", -1)))
		"card_played":
			var from_rect := _screen_rect_in_juice(event.get("from_rect", Rect2(Vector2(640, 650), Vector2(138, 164))))
			var destination := _screen_point_in_juice(event.get("destination", Vector2(640, 330)))
			var definition := DB.card(String(event.get("card_id", "")))
			if not definition.is_empty():
				var play_travel_seconds := 0.46 if String(definition.get("type", "")) == "unit" else 0.3
				juice.card_ghost(DB.art(definition.art), from_rect, destination, _rarity_color(definition.get("rarity", "common")), play_travel_seconds)
			var mana_cost := int(event.get("cost", 0))
			if mana_cost > 0:
				juice.float_text(_screen_point_in_juice(Vector2(640, 528)), t("juice.mana_spent", {"mana": mana_cost}), EMBER, 15, false)
			juice.contact_ring(destination, _rarity_color(definition.get("rarity", "common")), 52.0)
			var technique_sfx := _technique_sfx_kind(definition)
			if technique_sfx.is_empty():
				juice.play_sfx("play", -9.0)
			else:
				juice.play_sfx(technique_sfx, -4.0, false)
			await _juice_wait(0.28 if String(definition.get("type", "")) == "unit" else 0.11)
		"invalid":
			juice.float_text(position, String(event.get("message", t("juice.not_available"))), CRIMSON, 17, false)
			juice.burst(position, CRIMSON, 9, "ash", 38.0)
			juice.shake(screen_layer, 3.5, 0.16)
			juice.play_sfx("invalid", -7.0)
			await _juice_wait(0.07)
		"burn":
			juice.float_text(position, t("juice.card_burned"), CRIMSON, 20, true)
			juice.burst(position, EMBER, 24, "ash", 92.0)
			juice.play_sfx("overkill", -9.0)
			await _juice_wait(0.12)
		"shuffle":
			juice.float_text(position, t("juice.reshuffle"), TEAL, 16, false)
			juice.burst(position, TEAL, 12, "spark", 48.0)
			juice.play_sfx("draw", -11.0)
			await _juice_wait(0.07)
		"fatigue":
			juice.vignette(CRIMSON, 0.55)
			juice.float_text(_screen_point_in_juice(player_hero_anchor), t("juice.fatigue", {"damage": int(event.get("amount", 0))}), CRIMSON, 22, true)
			juice.play_sfx("heavy", -7.0)
			await _juice_wait(0.1)
		"summon":
			juice.burst(position, TEAL if bool(event.get("friendly", true)) else CRIMSON, 18, "spark", 72.0)
			juice.float_text(position, t("juice.served"), TEAL if bool(event.get("friendly", true)) else CRIMSON, 16, false)
			juice.play_sfx("summon", -8.0)
			if bool(event.get("friendly", false)) and String(event.get("rarity", "")) == "legendary":
				juice.play_voiceover("legendary_summon", -1.0)
			await _juice_wait(0.24)
		"ready":
			juice.burst(position, TEAL, 11, "spark", 45.0)
			juice.float_text(position, t("juice.ready"), TEAL, 15, false)
			juice.play_sfx("armor", -15.0)
			await _juice_wait(0.05)
		"trigger":
			var trigger_node: Control = unit_nodes_by_uid.get(int(event.get("uid", -1)))
			var trigger_position := position
			if is_instance_valid(trigger_node):
				trigger_position = _control_rect_in_layer(trigger_node, juice).get_center()
				juice.actor_reaction(trigger_node, "trigger", EMBER)
			juice.float_text(trigger_position, t("juice.trigger"), EMBER, 15, false)
			juice.contact_ring(trigger_position, EMBER, 38.0)
			juice.play_sfx("buff", -12.0)
			await _juice_wait(0.05)
		"legendary_engine":
			var engine_node: Control = unit_nodes_by_uid.get(int(event.get("uid", -1)))
			var engine_position := position
			if is_instance_valid(engine_node):
				engine_position = _control_rect_in_layer(engine_node, juice).get_center()
				juice.actor_reaction(engine_node, "trigger", GOLD)
			juice.contact_ring(engine_position, GOLD, 52.0, true)
			juice.burst(engine_position, TEAL, 18, "spark", 70.0)
			juice.float_text(engine_position - Vector2(0, 22), t("juice.legendary_engine", {"mana": int(event.get("amount", 0))}), GOLD, 19, true)
			juice.play_sfx("buff", -7.0)
			await _juice_wait(0.12)
		"legendary_cleave":
			juice.begin_signature()
			juice.slash(position, GOLD, 920.0, true)
			juice.flash(TEAL, 0.24, 0.3)
			juice.vignette(PLUM_SOFT, 0.72)
			juice.burst(position, EMBER, 34, "shard", 150.0)
			juice.float_text(_screen_point_in_juice(Vector2(640, 245)), t("juice.legendary_cleave"), GOLD, 28, true)
			juice.shake(screen_layer, 8.0, 0.34)
			juice.play_sfx("blade", -3.0)
			await _juice_wait(0.2)
			juice.end_signature()
		"legendary_bell":
			juice.begin_signature()
			juice.contact_ring(position, GOLD, 180.0, true)
			juice.contact_ring(position, TEAL, 118.0, true)
			juice.burst(position, GOLD, 36, "spark", 145.0)
			juice.flash(GOLD, 0.22, 0.4)
			juice.float_text(_screen_point_in_juice(Vector2(640, 280)), t("juice.legendary_bell"), GOLD, 28, true)
			juice.play_sfx("boss", -7.0)
			await _juice_wait(0.22)
			juice.end_signature()
		"attack":
			var attack_rect := _screen_rect_in_juice(event.get("from_rect", Rect2(Vector2(570, 270), Vector2(140, 120))))
			var attack_target := _screen_point_in_juice(event.get("destination", Vector2(640, 330)))
			var art_id := String(event.get("art", ""))
			var attacker_node: Control = unit_nodes_by_uid.get(int(event.get("uid", -1)))
			if is_instance_valid(attacker_node):
				juice.actor_lunge(attacker_node, attack_target, CRIMSON if bool(event.get("enemy", false)) else TEAL)
			if not art_id.is_empty():
				juice.card_ghost(DB.art(art_id), attack_rect, attack_target, CRIMSON if bool(event.get("enemy", false)) else TEAL, BOARD_ATTACK_IMPACT_SECONDS)
			juice.play_sfx("character_attack", -10.0)
			await _juice_wait(BOARD_ATTACK_IMPACT_SECONDS)
			if attacker_node == null:
				juice.contact_ring(attack_target, CRIMSON if bool(event.get("enemy", false)) else TEAL, 48.0, true)
		"unit_damage":
			var amount := int(event.get("amount", 0))
			var excess_damage := int(event.get("excess_damage", 0))
			if excess_damage > 0:
				var crack_rect := _screen_rect_in_juice(event.get("rect", Rect2(Vector2(561, 259), Vector2(158, 142))))
				var crack_art := DB.art(String(event.get("art", "")))
				var crack_accent := TEAL if bool(event.get("friendly", false)) else CRIMSON
				juice.card_cracks(
					crack_rect,
					excess_damage,
					int(event.get("max_health", 1)),
					crack_art,
					crack_accent,
					int(event.get("uid", 0)) * 7919 + amount * 101
				)
			juice.float_text(position, t("juice.damage", {"damage": amount}), CRIMSON, 28, amount >= 5)
			juice.mechanic_impact(position, "meat" if amount >= 5 else "blade", amount, amount >= 5)
			if bool(event.get("dead", false)):
				juice.vignette(CRIMSON, 0.42)
			await _juice_wait(0.09)
		"death":
			juice.burst(position, Color("#C98A5A"), 24, "ash", 92.0)
			juice.float_text(position, t("juice.cleared"), MUTED, 15, false)
			await _juice_wait(0.08)
		"hero_damage":
			var damage := int(event.get("amount", 0))
			juice.float_text(position, t("juice.damage", {"damage": damage}), CRIMSON, 31, damage >= 5)
			juice.flash(CRIMSON, 0.12 + minf(0.16, damage * 0.012), 0.2)
			juice.burst(position, CRIMSON, 16 + mini(damage, 8), "spark", 72.0)
			juice.shake(screen_layer, clampf(2.5 + damage * 0.65, 3.0, 9.0), 0.2)
			juice.play_sfx("heavy" if damage >= 5 else "hit", -6.0)
			var actor: Control = player_hero_control if String(event.get("side", "")) == "player" else enemy_hero_button
			if is_instance_valid(actor):
				juice.actor_reaction(actor, "hit", CRIMSON)
			await _juice_wait(0.1)
		"armor":
			var armor_value := int(event.get("amount", 0))
			juice.float_text(position, t("juice.armor_gained", {"armor": armor_value}), COPPER, 20, false)
			juice.burst(position, COPPER, 16, "spark", 62.0)
			juice.mechanic_impact(position, "armor", armor_value, false)
			juice.play_sfx("armor", -8.0)
			await _juice_wait(0.08)
		"armor_absorb":
			var absorbed := int(event.get("amount", 0))
			juice.float_text(position, t("juice.block", {"damage": absorbed}), COPPER, 18, false)
			juice.burst(position, COPPER, 13, "spark", 55.0)
			juice.contact_ring(position, COPPER, 42.0, true)
			juice.play_sfx("armor", -8.0)
			await _juice_wait(0.07)
		"armor_break":
			juice.float_text(position, t("juice.pan_broken"), CRIMSON, 19, false)
			juice.mechanic_impact(position, "armor", int(event.get("amount", 0)), true)
			juice.shake(screen_layer, 3.0, 0.14)
			await _juice_wait(0.09)
		"heal":
			var healed := int(event.get("amount", 0))
			juice.float_text(position, t("juice.healed", {"health": healed}), TEAL, 25, false)
			juice.mechanic_impact(position, "broth", healed, false)
			juice.play_sfx("heal", -9.0)
			await _juice_wait(0.08)
		"buff":
			var buff := int(event.get("amount", 0))
			juice.float_text(position, t("juice.buff", {"value": buff}), EMBER, 22, false)
			juice.burst(position, EMBER, 19, "spark", 68.0)
			juice.play_sfx("buff", -8.0)
			await _juice_wait(0.1)
		"precise_cut":
			juice.begin_signature()
			var ingredient := String(event.get("ingredient", ""))
			juice.slash(position, TEAL, 235.0, false)
			juice.flash(TEAL, 0.2, 0.24)
			juice.float_text(position - Vector2(0, 18), t("juice.precise_cut"), TEAL, 26, true)
			juice.caption(position + Vector2(118, -8), t("juice.clean_cut"), TEAL)
			juice.play_sfx("precise", -5.0)
			await _juice_wait(0.16)
			var ingredient_texture := DB.art("ingredient_" + ingredient)
			if ingredient_texture == null:
				ingredient_texture = DB.art("icon_sword")
				var ingredient_anchor: Vector2 = pantry_ingredient_anchors.get(ingredient, pantry_anchor)
				juice.ingredient_fly(ingredient_texture, position, _screen_point_in_juice(ingredient_anchor), TEAL, t("juice.ingredient_gained", {"ingredient": _ingredient_name(ingredient).to_upper()}))
			await _juice_wait(0.18)
			juice.end_signature()
		"overkill":
			juice.begin_signature()
			var ruined := String(event.get("ingredient", ""))
			juice.slash(position, CRIMSON, 260.0, true)
			juice.flash(CRIMSON, 0.24, 0.3)
			juice.vignette(CRIMSON, 0.6)
			juice.float_text(position - Vector2(0, 18), t("juice.ingredient_ruined"), CRIMSON, 24, true)
			juice.burst(position, Color("#5B4B4B"), 26, "ash", 102.0)
			juice.play_sfx("overkill", -4.0)
			if not ruined.is_empty():
				var ruined_texture := DB.art("ingredient_" + ruined)
				if ruined_texture != null:
					juice.ingredient_fly(ruined_texture, position, position + Vector2(0, -35), CRIMSON)
			await _juice_wait(0.2)
			juice.end_signature()
		"hero_power":
			var hero_power_position := _screen_point_in_juice(player_hero_anchor)
			juice.burst(hero_power_position, EMBER, 27, "spark", 112.0)
			juice.float_text(hero_power_position, t("juice.seasoned"), EMBER, 24, true)
			juice.play_sfx("buff", -5.0)
			await _juice_wait(0.15)
		"cook":
			juice.begin_signature()
			var recipe_id := String(event.get("recipe_id", ""))
			var recipe_position := _screen_point_in_juice(event.get("position", recipe_anchors.get(recipe_id, Vector2(774, 360))))
			var ingredients: Array = event.get("ingredients", [])
			for ingredient_value in ingredients:
				var ingredient_name := String(ingredient_value)
				var pantry_position := _screen_point_in_juice(pantry_ingredient_anchors.get(ingredient_name, pantry_anchor))
				var ingredient_art := DB.art("ingredient_" + ingredient_name)
				if ingredient_art == null:
					ingredient_art = DB.art("icon_sword")
				juice.ingredient_fly(ingredient_art, pantry_position, recipe_position, EMBER)
			juice.burst(recipe_position, Color("#D9F7E9"), 24, "steam", 95.0)
			juice.burst(recipe_position, EMBER, 22, "spark", 82.0)
			juice.mechanic_impact(_screen_point_in_juice(Vector2(820, 136)), "broth", ingredients.size(), true)
			juice.float_text(recipe_position, t("juice.dish_ready"), EMBER, 24, true)
			juice.play_sfx("cook", -4.0)
			await _juice_wait(0.24)
			juice.end_signature()
		"serving_spent":
			var remaining_servings := int(event.get("remaining", 0))
			juice.contact_ring(position, EMBER, 38.0)
			juice.burst(position, EMBER, 9, "rivet", 42.0)
			juice.float_text(position, t("juice.final_serving") if remaining_servings <= 0 else t("juice.servings_left", {"count": remaining_servings}), EMBER, 16, false)
			juice.play_sfx("click", -9.0)
			await _juice_wait(0.07)
		"reward_reveal":
			juice.card_ghost(DB.art("juice_card_back"), Rect2(position - Vector2(46, 66), Vector2(92, 132)), position, EMBER, 0.22)
			juice.contact_ring(position, EMBER, 54.0)
			juice.float_text(position, t("juice.revealed"), EMBER, 17, false)
			juice.play_sfx("draw", -7.0)
			await _juice_wait(0.10)
		"reward":
			juice.burst(position, TEAL, 22, "spark", 82.0)
			juice.float_text(position, t("juice.added_to_deck"), TEAL, 21, true)
			juice.play_sfx("precise", -8.0)
			await _juice_wait(0.14)
		"route":
			juice.slash(_screen_point_in_juice(Vector2(640, 360)), EMBER, 980.0, true)
			juice.flash(EMBER, 0.18, 0.28)
			juice.float_text(_screen_point_in_juice(Vector2(640, 145)), String(event.get("name", t("juice.next_course"))).to_upper(), EMBER, 25, true)
			juice.play_sfx("play", -5.0)
			await _juice_wait(0.18)
		"boss_enrage":
			juice.begin_signature()
			juice.vignette(CRIMSON, 1.0)
			juice.flash(CRIMSON, 0.28, 0.34)
			juice.burst(_screen_point_in_juice(enemy_hero_anchor), CRIMSON, 34, "spark", 145.0)
			juice.float_text(_screen_point_in_juice(Vector2(640, 150)), t("juice.second_serving"), CRIMSON, 30, true)
			juice.caption(_screen_point_in_juice(Vector2(640, 218)), t("juice.feast_not_over"), CRIMSON)
			juice.shake(screen_layer, 10.0, 0.52)
			juice.play_sfx("boss", -3.0)
			await _juice_wait(0.3)
			juice.end_signature()
		"victory":
			juice.begin_signature()
			juice.flash(TEAL, 0.28, 0.5)
			for index in range(5):
				juice.burst(_screen_point_in_juice(Vector2(230 + index * 205, 180 + (index % 2) * 210)), TEAL if index % 2 == 0 else EMBER, 22, "spark", 120.0)
			juice.float_text(_screen_point_in_juice(Vector2(640, 135)), t("juice.banquet_served"), TEAL, 31, true)
			juice.play_sfx("victory", -3.0)
			await _juice_wait(0.32)
			juice.end_signature()
		"defeat":
			juice.begin_signature()
			juice.vignette(CRIMSON, 1.1)
			juice.burst(_screen_point_in_juice(Vector2(640, 280)), Color("#665A4C"), 36, "ash", 180.0)
			juice.float_text(_screen_point_in_juice(Vector2(640, 145)), t("juice.kitchen_closed"), CRIMSON, 29, true)
			juice.play_sfx("defeat", -3.0)
			await _juice_wait(0.28)
			juice.end_signature()
		_:
			return


func _juice_wait(seconds: float) -> void:
	if debug_fast:
		await get_tree().create_timer(0.0, false).timeout
	else:
		await get_tree().create_timer(seconds * (0.5 if reduce_motion else 1.0) * juice_repeat_speed / maxf(0.5, animation_speed), false).timeout


func _juice_event_position(event: Dictionary) -> Vector2:
	if event.has("position"):
		return _screen_point_in_juice(event.position)
	var uid := int(event.get("uid", -1))
	if uid >= 0 and visual_unit_rects.has(uid):
		var live_unit: Control = unit_nodes_by_uid.get(uid)
		if is_instance_valid(live_unit):
			return _control_rect_in_layer(live_unit, juice).get_center()
		var rect: Rect2 = visual_unit_rects[uid]
		return _screen_rect_in_juice(rect).get_center()
	var side := String(event.get("side", ""))
	if side == "player":
		return _screen_point_in_juice(player_hero_anchor)
	if side == "enemy":
		return _screen_point_in_juice(enemy_hero_anchor)
	return _screen_point_in_juice(Vector2(640, 330))


func _unit_visual_rect(unit: Dictionary) -> Rect2:
	return visual_unit_rects.get(int(unit.get("uid", -1)), Rect2(Vector2(640, 330), Vector2(158, 142)))


func _card_visual_rect(runtime_card: Dictionary) -> Rect2:
	return visual_hand_positions.get(int(runtime_card.get("uid", -1)), Rect2(Vector2(570, 548), Vector2(138, 164)))


func _clear_ui() -> void:
	_hide_card_preview()
	chef_name_input = null
	if target_line != null:
		target_line.dismiss()
	card_nodes_by_uid.clear()
	unit_nodes_by_uid.clear()
	enemy_hero_button = null
	player_hero_control = null
	for child in screen_layer.get_children():
		screen_layer.remove_child(child)
		child.queue_free()





func _add_background(texture: Texture2D, tint := Color(1, 1, 1, 1)) -> void:
	var background := TextureRect.new()
	background.texture = texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var environment_tint := Color.from_string(String(_tweak(&"environment.background_tint", "#ffffff")), Color.WHITE)
	var brightness := _tweak_float(&"environment.background_brightness", 1.0)
	background.modulate = Color(
		tint.r * environment_tint.r * brightness,
		tint.g * environment_tint.g * brightness,
		tint.b * environment_tint.b * brightness,
		tint.a
	)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_layer.add_child(background)


func _place(control: Control, rect: Rect2) -> Control:
	return _place_on(screen_layer, control, rect)


func _place_on(parent: Control, control: Control, rect: Rect2) -> Control:
	control.position = rect.position
	control.size = rect.size
	parent.add_child(control)
	control.pivot_offset = control.size * 0.5
	return control


func _panel(rect: Rect2, color := CONTENT_BG, border := COPPER, width := 2, radius := 14) -> Panel:
	return _panel_on(screen_layer, rect, color, border, width, radius)


func _panel_on(parent: Control, rect: Rect2, color := CONTENT_BG, border := COPPER, width := 2, radius := 14) -> Panel:
	var panel := Panel.new()
	var panel_color: Color = color
	if panel_color == CONTENT_BG:
		panel_color.a = _tweak_float(&"ui.panel_opacity", CONTENT_BG.a)
	panel.add_theme_stylebox_override("panel", _style(panel_color, border, width, radius))
	_place_on(parent, panel, rect)
	return panel


func _hud_readability_plate_on(parent: Control, rect: Rect2, accent: Color, node_name: String, radius := 8) -> Panel:
	var plate := Panel.new()
	plate.name = node_name
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", _style(HUD_DETAIL_BG, Color(accent, 0.58), 1, radius))
	_place_on(parent, plate, rect)
	return plate


func _label(text: String, font_size := 20, color := CREAM, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	L10N.apply_font(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", maxi(8, roundi(font_size * _tweak_float(&"ui.font_scale", 1.0))))
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _hud_label(text: String, preferred_font_size: int, minimum_font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_CENTER, outline_size := 2) -> Label:
	var label := _label(text, preferred_font_size, color, alignment)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.max_lines_visible = 1
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_outline_color", HUD_TEXT_OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", outline_size)
	label.set_meta("hud_preferred_font_size", label.get_theme_font_size("font_size"))
	label.set_meta("hud_minimum_font_size", maxi(8, minimum_font_size))
	label.set_meta("hud_outline_size", outline_size)
	return label


func _place_hud_label_on(parent: Control, text: String, preferred_font_size: int, minimum_font_size: int, color: Color, rect: Rect2, node_name: String, alignment := HORIZONTAL_ALIGNMENT_CENTER, outline_size := 2) -> Label:
	var label := _hud_label(text, preferred_font_size, minimum_font_size, color, alignment, outline_size)
	label.name = node_name
	label.set_meta("hud_assigned_size", rect.size)
	_place_on(parent, label, rect)
	_fit_hud_label(label)
	return label


func _embolden_hud_label(label: Label, strength := 1.0) -> Label:
	var bold_font := FontVariation.new()
	bold_font.base_font = label.get_theme_font("font")
	bold_font.variation_embolden = strength
	label.add_theme_font_override("font", bold_font)
	_fit_hud_label(label)
	return label


## Display-face label: one line, shrinks to its rect instead of wrapping (headings, names, big numbers).
func _display_label(text: String, font: Font, font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_CENTER, outline_size := 3) -> Label:
	var label := _label(text, font_size, color, alignment)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_override("font", font)
	if outline_size > 0:
		label.add_theme_color_override("font_outline_color", HUD_TEXT_OUTLINE_COLOR)
		label.add_theme_constant_override("outline_size", outline_size)
	return label


func _place_display_on(parent: Control, label: Label, rect: Rect2, minimum_font_size := 10) -> Label:
	_place_on(parent, label, rect)
	_fit_label_width(label, rect.size.x + 24.0, minimum_font_size)
	return label


func _heading(parent: Control, text: String, font_size: int, color: Color, rect: Rect2, alignment := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	return _place_display_on(parent, _display_label(text, L10N.HEADING_FONT_RESOURCE, font_size, color, alignment), rect, maxi(10, font_size - 10))


## Swap a label/button onto a display face and re-measure fitted HUD text with the new metrics.
func _set_font(control: Control, font: Font) -> Control:
	control.add_theme_font_override("font", font)
	if control is Label and control.has_meta("hud_assigned_size"):
		_fit_hud_label(control as Label)
	return control


func _fit_hud_label(label: Label) -> void:
	var preferred_size := int(label.get_meta("hud_preferred_font_size", label.get_theme_font_size("font_size")))
	var minimum_size := mini(preferred_size, int(label.get_meta("hud_minimum_font_size", 8)))
	var outline_size := int(label.get_meta("hud_outline_size", 0))
	var assigned_size: Vector2 = label.get_meta("hud_assigned_size", label.size)
	var available_width := maxf(1.0, assigned_size.x - float(outline_size * 2 + 2))
	var available_height := maxf(1.0, assigned_size.y - float(outline_size * 2 + 2))
	var font := label.get_theme_font("font")
	var resolved_size := preferred_size
	while resolved_size > minimum_size:
		var text_size := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, resolved_size)
		if text_size.x <= available_width and font.get_height(resolved_size) <= available_height:
			break
		resolved_size -= 1
	label.add_theme_font_size_override("font_size", resolved_size)
	label.size = assigned_size
	var resolved_text_size := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, resolved_size)
	label.set_meta("hud_resolved_font_size", resolved_size)
	label.set_meta(
		"hud_text_fits",
		resolved_text_size.x <= available_width and font.get_height(resolved_size) <= available_height
	)


func _set_hud_intrinsic_minimum(label: Label, minimum_height := 0.0) -> void:
	var font_size := label.get_theme_font_size("font_size")
	var outline_size := int(label.get_meta("hud_outline_size", 0))
	var text_size := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	label.custom_minimum_size = Vector2(
		ceilf(text_size.x) + float(outline_size * 2 + 2),
		maxf(minimum_height, ceilf(label.get_theme_font("font").get_height(font_size)) + float(outline_size * 2))
	)


func _fit_button_text(button: Button, preferred_font_size: int, minimum_font_size: int, horizontal_padding := 16.0, vertical_padding := 8.0) -> void:
	var preferred_size := maxi(8, roundi(preferred_font_size * _tweak_float(&"ui.font_scale", 1.0)))
	var minimum_size := mini(preferred_size, maxi(8, minimum_font_size))
	var font := button.get_theme_font("font")
	var available_width := maxf(1.0, button.size.x - horizontal_padding * 2.0)
	var available_height := maxf(1.0, button.size.y - vertical_padding * 2.0)
	var resolved_size := preferred_size
	while resolved_size > minimum_size:
		var text_size := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, resolved_size)
		if text_size.x <= available_width and font.get_height(resolved_size) <= available_height:
			break
		resolved_size -= 1
	button.clip_text = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", resolved_size)
	button.add_theme_color_override("font_outline_color", HUD_TEXT_OUTLINE_COLOR)
	button.add_theme_constant_override("outline_size", 2)
	button.set_meta("hud_preferred_font_size", preferred_size)
	button.set_meta("hud_minimum_font_size", minimum_size)
	button.set_meta("hud_resolved_font_size", resolved_size)


func _card_description_label(text: String, font_size: int) -> Label:
	var label := _label(text, font_size, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	label.name = "CardDescription"
	label.max_lines_visible = 2
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _card_stats_footer(attack: int, health: int, color: Color, icon_size: float, font_size: int) -> HBoxContainer:
	var stats := HBoxContainer.new()
	stats.name = "CardStats"
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 2)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sword_icon := _texture(DB.art("icon_sword"))
	sword_icon.name = "AttackIcon"
	sword_icon.custom_minimum_size = Vector2.ONE * icon_size
	stats.add_child(sword_icon)
	var attack_label := _label(str(attack), font_size + 2, color, HORIZONTAL_ALIGNMENT_CENTER)
	attack_label.add_theme_font_override("font", L10N.NUMBER_FONT_RESOURCE)
	attack_label.name = "AttackValue"
	attack_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	attack_label.custom_minimum_size = Vector2(icon_size * 0.65, icon_size)
	stats.add_child(attack_label)

	var separator := _label("·", font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	separator.autowrap_mode = TextServer.AUTOWRAP_OFF
	separator.custom_minimum_size = Vector2(icon_size * 0.45, icon_size)
	stats.add_child(separator)

	var shield_icon := _texture(DB.art("icon_shield"))
	shield_icon.name = "HealthIcon"
	shield_icon.custom_minimum_size = Vector2.ONE * icon_size
	stats.add_child(shield_icon)
	var health_label := _label(str(health), font_size + 2, color, HORIZONTAL_ALIGNMENT_CENTER)
	health_label.add_theme_font_override("font", L10N.NUMBER_FONT_RESOURCE)
	health_label.name = "HealthValue"
	health_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	health_label.custom_minimum_size = Vector2(icon_size * 0.65, icon_size)
	stats.add_child(health_label)
	return stats


func _mana_cost_badge(cost: int, size: Vector2, font_size: int, affordable := true) -> Control:
	var badge := Control.new()
	badge.name = "ManaCostBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size = size
	badge.custom_minimum_size = size

	var crystal := _texture(DB.art("juice_mana_burner"))
	crystal.name = "ManaCrystalIcon"
	crystal.position = Vector2.ZERO
	crystal.size = size
	crystal.modulate = CARD_MANA_CRYSTAL_TINT if affordable else CARD_MANA_CRYSTAL_UNAFFORDABLE_TINT
	badge.add_child(crystal)

	var value := _label(str(cost), font_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	value.add_theme_font_override("font", L10N.NUMBER_FONT_RESOURCE)
	value.name = "ManaCostValue"
	value.position = Vector2.ZERO
	value.size = size
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.add_theme_color_override("font_outline_color", Color("#E20A1230"))
	value.add_theme_constant_override("outline_size", maxi(2, roundi(font_size * 0.18)))
	badge.add_child(value)
	return badge


func _mana_readout(value_text: String, font_size: int, color: Color, icon_size: float, prefix_text := "", suffix_text := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ManaReadout"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.clip_contents = true
	if not prefix_text.is_empty():
		var prefix := _hud_label(prefix_text, font_size, maxi(9, font_size - 6), color, HORIZONTAL_ALIGNMENT_LEFT, 2)
		prefix.name = "ManaPrefix"
		prefix.add_theme_font_override("font", L10N.HEADING_FONT_RESOURCE)
		_set_hud_intrinsic_minimum(prefix, icon_size)
		row.add_child(prefix)
	var crystal := _texture(DB.art("juice_mana_burner"))
	crystal.name = "ManaCrystalIcon"
	crystal.custom_minimum_size = Vector2.ONE * icon_size
	row.add_child(crystal)
	if not value_text.is_empty():
		var value := _hud_label(value_text, font_size + 2, maxi(9, font_size - 6), color, HORIZONTAL_ALIGNMENT_LEFT, 2)
		value.name = "ManaValue"
		value.add_theme_font_override("font", L10N.NUMBER_FONT_RESOURCE)
		_set_hud_intrinsic_minimum(value, icon_size)
		row.add_child(value)
	if not suffix_text.is_empty():
		var suffix := _hud_label(suffix_text, font_size, maxi(9, font_size - 6), color, HORIZONTAL_ALIGNMENT_LEFT, 2)
		suffix.name = "ManaSuffix"
		_set_hud_intrinsic_minimum(suffix, icon_size)
		row.add_child(suffix)
	return row


func _place_mana_readout_on(parent: Control, value_text: String, font_size: int, color: Color, icon_size: float, prefix_text: String, rect: Rect2, node_name: String) -> HBoxContainer:
	var row := _mana_readout(value_text, font_size, color, icon_size, prefix_text)
	row.name = node_name
	row.set_meta("hud_assigned_size", rect.size)
	_place_on(parent, row, rect)
	_fit_mana_readout(row)
	return row


func _fit_mana_readout(row: HBoxContainer) -> void:
	var assigned_size: Vector2 = row.get_meta("hud_assigned_size", row.size)
	var labels: Array[Label] = []
	var fixed_width := 0.0
	var fixed_height := 0.0
	for child in row.get_children():
		if child is Label:
			labels.append(child)
		elif child is Control:
			var child_control := child as Control
			fixed_width += child_control.custom_minimum_size.x
			fixed_height = maxf(fixed_height, child_control.custom_minimum_size.y)
	var separation := float(row.get_theme_constant("separation"))
	var gap_width := separation * maxf(0.0, float(row.get_child_count() - 1))
	var resolved_size := 8
	var preferred_size := 8
	var minimum_size := 8
	for label in labels:
		preferred_size = maxi(preferred_size, int(label.get_meta("hud_preferred_font_size", label.get_theme_font_size("font_size"))))
		minimum_size = maxi(minimum_size, int(label.get_meta("hud_minimum_font_size", 8)))
	resolved_size = preferred_size
	var fits := false
	while resolved_size >= minimum_size:
		var required_width := fixed_width + gap_width
		var required_height := fixed_height
		for label in labels:
			var outline_size := int(label.get_meta("hud_outline_size", 0))
			var font := label.get_theme_font("font")
			required_width += ceilf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, resolved_size).x) + float(outline_size * 2 + 2)
			required_height = maxf(required_height, ceilf(font.get_height(resolved_size)) + float(outline_size * 2 + 2))
		fits = required_width <= assigned_size.x and required_height <= assigned_size.y
		if fits or resolved_size == minimum_size:
			break
		resolved_size -= 1
	for label in labels:
		var outline_size := int(label.get_meta("hud_outline_size", 0))
		var font := label.get_theme_font("font")
		var text_width := ceilf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, resolved_size).x)
		label.add_theme_font_size_override("font_size", resolved_size)
		label.custom_minimum_size = Vector2(text_width + float(outline_size * 2 + 2), minf(assigned_size.y, ceilf(font.get_height(resolved_size)) + float(outline_size * 2 + 2)))
		label.set_meta("hud_resolved_font_size", resolved_size)
		label.set_meta("hud_text_fits", fits)
	row.size = assigned_size
	row.set_meta("hud_resolved_font_size", resolved_size)
	row.set_meta("hud_text_fits", fits)


func _hero_power_button(cost: int, armor: int, disabled: bool, available_width := 144.0) -> Button:
	var button := _button("", use_hero_power, TEAL, disabled)
	button.name = "HeroPowerButton"
	_plaque(button, "plate", TEAL, 13)
	button.clip_contents = true
	button.tooltip_text = "%s · %s · %s" % [
		t("battle.hero_power"),
		t("battle.hero_power_cost", {"cost": cost}),
		t("battle.hero_power_effect", {"armor": armor}),
	]

	var title_color := Color("#9C9588") if disabled else CREAM
	var detail_color := Color("#858074") if disabled else MUTED
	var cost_color := Color("#5596A3") if disabled else MANA_BLUE
	var content_width := maxf(1.0, available_width - 16.0)
	_place_hud_label_on(
		button,
		t("battle.hero_power"),
		13,
		10,
		title_color,
		Rect2(8, 3, content_width, 24),
		"HeroPowerTitle",
		HORIZONTAL_ALIGNMENT_CENTER,
		1
	)
	var power_title := button.get_node("HeroPowerTitle") as Label
	var power_heading := FontVariation.new()
	power_heading.base_font = L10N.NAME_FONT_RESOURCE
	power_heading.spacing_glyph = 0
	_set_font(power_title, power_heading)

	var cost_row := HBoxContainer.new()
	cost_row.name = "HeroPowerCostRow"
	cost_row.position = Vector2(8, 25)
	cost_row.size = Vector2(content_width, 18)
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 3)
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cost_row)
	var cost_label := _hud_label(t("battle.hero_power_cost", {"cost": cost}), 9, 8, cost_color, HORIZONTAL_ALIGNMENT_LEFT, 1)
	cost_label.name = "HeroPowerCost"
	_set_hud_intrinsic_minimum(cost_label, 16.0)
	cost_row.add_child(cost_label)
	var mana_icon := _texture(DB.art("juice_mana_burner"))
	mana_icon.name = "HeroPowerManaIcon"
	mana_icon.custom_minimum_size = Vector2(16, 16)
	mana_icon.modulate = Color("#879396") if disabled else Color.WHITE
	cost_row.add_child(mana_icon)

	_place_hud_label_on(
		button,
		t("battle.hero_power_effect", {"armor": armor}),
		9,
		8,
		detail_color,
		Rect2(8, 46, content_width, 18),
		"HeroPowerEffect",
		HORIZONTAL_ALIGNMENT_CENTER,
		1
	)
	return button


func _line_edit(value: String, placeholder: String) -> LineEdit:
	var input := LineEdit.new()
	input.text = value
	input.placeholder_text = placeholder
	L10N.apply_font(input)
	input.max_length = 16
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.add_theme_font_size_override("font_size", maxi(8, roundi(18 * _tweak_float(&"ui.font_scale", 1.0))))
	input.add_theme_color_override("font_color", CREAM)
	input.add_theme_color_override("font_placeholder_color", MUTED)
	input.add_theme_color_override("caret_color", EMBER)
	var inset := _style(Color("#0E080C"), Color(TAVERN.BRASS, 0.75), 1, 6)
	inset.border_width_top = 3
	inset.border_color = Color(TAVERN.BRASS, 0.75)
	inset.shadow_color = Color(0, 0, 0, 0.45)
	inset.shadow_size = 3
	input.add_theme_stylebox_override("normal", inset)
	var inset_focus := inset.duplicate() as StyleBoxFlat
	inset_focus.border_color = GOLD
	inset_focus.shadow_color = Color(GOLD, 0.35)
	inset_focus.shadow_size = 7
	input.add_theme_stylebox_override("focus", inset_focus)
	input.set_meta("cursor_mode", "interact")
	return input


func _button(text: String, callback: Callable, accent := COPPER, disabled := false) -> Button:
	var button := Button.new()
	button.text = text
	L10N.apply_font(button)
	button.disabled = disabled
	button.add_theme_font_size_override("font_size", maxi(8, roundi(17 * _tweak_float(&"ui.font_scale", 1.0))))
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(CONTENT_BG, accent, 2, 10))
	button.add_theme_stylebox_override("hover", _style(CONTENT_BG, EMBER, 3, 10))
	button.add_theme_stylebox_override("pressed", _style(CONTENT_BG, TEAL, 3, 10))
	button.add_theme_stylebox_override("disabled", _style(CONTENT_BG, Color("#665A4C"), 1, 10))
	button.add_theme_stylebox_override("focus", _golden_focus_style(10))
	button.set_meta("juice_kind", "button")
	button.set_meta("juice_accent", accent)
	button.mouse_entered.connect(func(): _on_juice_hover(button, true))
	button.mouse_exited.connect(func(): _on_juice_hover(button, false))
	button.focus_entered.connect(func(): _on_juice_hover(button, true))
	button.focus_exited.connect(func(): _on_juice_hover(button, false))
	button.button_down.connect(func(): _on_juice_press(button, true))
	button.button_up.connect(func(): _on_juice_press(button, false))
	button.pressed.connect(func():
		if juice != null:
			juice.play_sfx("click", -11.0)
		callback.call()
	)
	return button


func _on_juice_hover(control: Control, entered: bool) -> void:
	if not is_instance_valid(control):
		return
	var kind := String(control.get_meta("juice_kind", "button"))
	var preserve_position := bool(control.get_meta("juice_preserve_position", false))
	if kind in ["card", "unit"]:
		if entered:
			_show_card_preview(String(control.get_meta("card_id", "")), int(control.get_meta("servings", 0)), control)
		else:
			_hide_card_preview()
	if control.get_meta("juice_hovered", false) == entered:
		return
	control.set_meta("juice_hovered", entered)
	if kind == "card" and control.has_meta("card_uid"):
		_spread_hand_neighbors(int(control.get_meta("card_uid")), entered)
		_apply_card_name_layout(control, not entered)
	if entered:
		control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if not preserve_position:
			control.set_meta("juice_origin", control.position)
		if juice != null and _tweak_bool(&"audio.hover_sounds", true):
			juice.play_sfx("hover", -17.0)
	var origin: Vector2 = control.get_meta("juice_origin", control.position)
	var hover_scale := _tweak_float(&"ui.hover_lift_scale", 1.0)
	var lift := 4.0
	var target_scale := Vector2(1.025, 1.025)
	if kind == "card":
		lift = 12.0
		target_scale = Vector2(1.055, 1.055)
	elif kind in ["route", "reward", "recipe"]:
		lift = 7.0
		target_scale = Vector2(1.035, 1.035)
	elif kind == "unit":
		lift = 5.0
		target_scale = Vector2(1.035, 1.035)
	lift *= hover_scale
	target_scale = Vector2.ONE + (target_scale - Vector2.ONE) * hover_scale
	if control is Button and control.disabled:
		lift *= 0.35
		target_scale = Vector2(1.012, 1.012)
	if reduce_motion:
		lift *= 0.3
		target_scale = Vector2(1.015, 1.015)
	var prior = control.get_meta("juice_tween") if control.has_meta("juice_tween") else null
	if prior is Tween and prior.is_valid():
		prior.kill()
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	control.set_meta("juice_tween", tween)
	var base_z := int(control.get_meta("juice_base_z", 0))
	if entered:
		control.z_index = base_z + 40
		if not preserve_position:
			tween.tween_property(control, "position", origin - Vector2(0, lift), 0.12)
		tween.tween_property(control, "scale", target_scale, 0.12)
		if kind == "card" and not reduce_motion:
			var tilt := float(control.get_meta("juice_rest_rotation", 0.0))
			tween.tween_property(control, "rotation", tilt, 0.12)
	else:
		control.z_index = base_z
		if not preserve_position:
			tween.tween_property(control, "position", origin, 0.12)
		tween.tween_property(control, "scale", Vector2.ONE, 0.12)
		tween.tween_property(control, "rotation", float(control.get_meta("juice_rest_rotation", 0.0)), 0.12)


func _on_juice_press(control: Control, pressed: bool) -> void:
	if not is_instance_valid(control):
		return
	var prior = control.get_meta("juice_press_tween") if control.has_meta("juice_press_tween") else null
	if prior is Tween and prior.is_valid():
		prior.kill()
	var tween := create_tween()
	control.set_meta("juice_press_tween", tween)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var target := Vector2(0.965, 0.965) if pressed else Vector2(1.035, 1.035) if control.get_meta("juice_hovered", false) else Vector2.ONE
	tween.tween_property(control, "scale", target, 0.065 if pressed else 0.1)


func _show_card_preview(card_id: String, servings: int, source: Control = null) -> void:
	if card_id.is_empty() or juice == null:
		return
	_hide_card_preview()
	var definition := DB.card(card_id)
	if definition.is_empty():
		return
	var preview := Panel.new()
	var preview_screen_rect := _card_preview_screen_rect(source)
	var preview_rect := _rect_between_canvas_items(screen_layer, juice, preview_screen_rect)
	preview.position = preview_rect.position
	preview.size = preview_rect.size
	preview.set_meta("screen_rect", preview_screen_rect)
	preview.pivot_offset = preview.size * 0.5
	var preview_scale := _tweak_float(&"ui.card_preview_scale", 1.0)
	preview.scale = Vector2.ONE * 0.92 * preview_scale
	preview.modulate = Color.WHITE
	preview.z_as_relative = false
	preview.z_index = CARD_PREVIEW_Z_INDEX
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_theme_stylebox_override("panel", _style(Color(CONTENT_BG, 1.0), _rarity_color(definition.get("rarity", "common")), 3, 16))
	var preview_trim := TAVERN.CardTrim.new()
	preview_trim.accent = _rarity_color(definition.get("rarity", "common"))
	preview_trim.rarity = String(definition.get("rarity", "common"))
	preview_trim.art_rect = Rect2(17, 14, 212, 178)
	preview_trim.name_rect = Rect2(12, 219, 222, 32)
	preview_trim.show_jewel = false
	preview_trim.size = preview.size
	var art := _texture(DB.art(definition.art))
	art.position = Vector2(17, 14)
	art.size = Vector2(212, 178)
	# The trim rides on the art node behind it (show_behind_parent), so it draws over the panel but under
	# the art, cost, name and rules while the preview keeps its art/cost/name child order.
	preview.add_child(art)
	preview_trim.position = -art.position
	preview_trim.show_behind_parent = true
	art.add_child(preview_trim)
	var cost := _mana_readout(str(int(definition.cost)), 20, MANA_BLUE, 26.0)
	cost.position = Vector2(18, 194)
	cost.size = Vector2(210, 24)
	preview.add_child(cost)
	var title := _display_label(t(definition.name_key), L10N.NAME_FONT_RESOURCE, 21, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 2)
	title.position = Vector2(15, 218)
	title.size = Vector2(216, 34)
	preview.add_child(title)
	_fit_label_width(title, 240.0, 13)
	var rules := _card_description_label(t(definition.text_key), 14)
	rules.position = Vector2(22, 252)
	rules.size = Vector2(202, 63)
	preview.add_child(rules)
	if definition.type == "unit":
		var stats := _card_stats_footer(int(definition.attack), int(definition.health), _rarity_color(definition.get("rarity", "common")), 20.0, 13)
		stats.position = Vector2(15, 316)
		stats.size = Vector2(216, 24)
		preview.add_child(stats)
	else:
		var footer_text: String = t("card.servings", {"count": servings}) if definition.type == "dish" else t("card.type.%s" % String(definition.type))
		var footer := _label(footer_text, 13, _rarity_color(definition.get("rarity", "common")), HORIZONTAL_ALIGNMENT_CENTER)
		footer.add_theme_font_override("font", L10N.BUTTON_FONT_RESOURCE)
		footer.position = Vector2(15, 316)
		footer.size = Vector2(216, 24)
		preview.add_child(footer)
	juice.add_child(preview)
	card_preview = preview
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(preview, "scale", Vector2.ONE * preview_scale, 0.14)


func _card_preview_screen_rect(_source: Control = null) -> Rect2:
	return _target_battle_zone(&"preview")


func _hide_card_preview() -> void:
	if card_preview == null or not is_instance_valid(card_preview):
		card_preview = null
		return
	card_preview.queue_free()
	card_preview = null


func _style(color: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	var scaled_radius := maxi(0, roundi(radius * _tweak_float(&"ui.corner_radius_scale", 1.0)))
	style.corner_radius_top_left = scaled_radius
	style.corner_radius_top_right = scaled_radius
	style.corner_radius_bottom_left = scaled_radius
	style.corner_radius_bottom_right = scaled_radius
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _card_cost_style(affordable: bool) -> StyleBoxFlat:
	var border := GOLD if affordable else Color("#8C684C")
	var style := _style(Color("#E8100A18"), border, 2, 14)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	if affordable:
		style.shadow_color = Color(1.0, 0.72, 0.22, 0.78)
		style.shadow_size = 7
		style.shadow_offset = Vector2.ZERO
	return style


func _affordable_card_frame_style(border_width: int, shadow_size: int) -> StyleBoxFlat:
	var style := _style(HAND_CARD_BG, GOLD, border_width, 10)
	style.shadow_color = Color(GOLD, 0.78)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2.ZERO
	return style


func _golden_focus_style(radius: int, background_opacity := 0.90) -> StyleBoxFlat:
	var style := _style(Color(0.16, 0.105, 0.045, background_opacity), Color.TRANSPARENT, 0, radius)
	style.shadow_color = Color(GOLD, 0.44)
	style.shadow_size = 7
	style.shadow_offset = Vector2.ZERO
	return style


func _end_turn_glow_style(border_width: int) -> StyleBoxFlat:
	# A soft golden pill hugging the brass frame (not a boxed panel): no drawn border, a faint warm
	# fill and a wide golden shadow halo.
	var style := _style(Color(GOLD, 0.16), GOLD, 0, 26)
	style.expand_margin_left = -6.0
	style.expand_margin_right = -6.0
	style.expand_margin_top = -22.0
	style.expand_margin_bottom = -20.0
	style.shadow_color = Color(GOLD, 0.62 + 0.04 * float(border_width))
	style.shadow_size = 12 + border_width
	style.shadow_offset = Vector2.ZERO
	return style


func _apply_end_turn_glow(button: Button) -> void:
	button.set_meta("end_turn_recommended", true)
	button.set_meta("end_turn_pulsing", false)
	button.add_theme_color_override("font_color", Color("#FFF1B8"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _end_turn_glow_style(3))
	button.add_theme_stylebox_override("hover", _end_turn_glow_style(4))
	button.add_theme_stylebox_override("pressed", _end_turn_glow_style(4))
	var halo := TAVERN.CandleGlow.new()
	halo.name = "EndTurnHalo"
	halo.color = GOLD
	halo.intensity = 0.55
	halo.animate = _motion_full()
	halo.show_behind_parent = true
	halo.position = Vector2(-26, -18)
	halo.size = button.size + Vector2(52, 36)
	button.add_child(halo)
	var visible_label := button.get_node_or_null("EndTurnVisibleLabel") as Label
	if visible_label != null and _motion_full():
		visible_label.material = TAVERN.shine_material(visible_label.size, 2.6)
	if tutorial_active or debug_fast or motion_mode != JUICE_PROFILES.MOTION_FULL:
		return
	button.set_meta("end_turn_pulsing", true)
	var tween := button.create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(button, "self_modulate", Color("#FFF0B8"), 0.72)
	tween.tween_property(button, "self_modulate", Color.WHITE, 0.72)


func _shade_color(base: Color) -> Color:
	var adjusted := base
	adjusted.a = clampf(base.a * _tweak_float(&"environment.overlay_opacity_scale", 1.0), 0.0, 1.0)
	return adjusted


func _texture(texture: Texture2D, mode := TextureRect.STRETCH_KEEP_ASPECT_CENTERED) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = mode
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


# ---------------------------------------------------------------- tavern presentation helpers

## Focus a freshly built control once the frame settles, unless a re-render replaced it meanwhile.
func _defer_focus(control: Control) -> void:
	(func():
		if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
			control.grab_focus()
	).call_deferred()


func _motion_full() -> bool:
	return not reduce_motion and not debug_fast and motion_mode == JUICE_PROFILES.MOTION_FULL


func _modal_key() -> String:
	if pause_open:
		return "pause_settings" if settings_open else "pause"
	if service_history_open:
		return "history"
	if deck_overlay_open:
		return "deck"
	if leaderboard_open:
		return "leaderboard"
	if settings_open:
		return "settings"
	if rules_open:
		return "rules"
	return ""


## Dress a Button as a carved wooden plaque (sign | plate | chip | row). The plaque is a
## show_behind_parent child, so the Button keeps its text, focus, signals and node name.
func _plaque(button: Button, variant := "plate", accent := TAVERN.BRASS, font_size := 17, chain_height := 0.0) -> Button:
	_make_button_chromeless(button)
	var plaque := TAVERN.Plaque.new()
	plaque.variant = variant
	plaque.accent = accent
	plaque.chain_height = chain_height
	plaque.notch = 12.0 if variant == "sign" else 6.0 if variant in ["chip", "row"] else 8.0
	plaque.seed_value = TAVERN.seed_from(button.name + button.text + variant)
	button.add_child(plaque)
	button.add_theme_font_override("font", L10N.HEADING_FONT_RESOURCE)
	button.add_theme_font_size_override("font_size", maxi(8, roundi(font_size * _tweak_float(&"ui.font_scale", 1.0))))
	button.add_theme_color_override("font_color", CREAM)
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, Color("#FFF0C4"))
	button.add_theme_color_override("font_disabled_color", Color(MUTED, 0.5))
	button.add_theme_color_override("font_outline_color", Color("#120704"))
	button.add_theme_constant_override("outline_size", 5 if variant == "sign" else 4)
	button.set_meta("tavern_plaque", variant)
	return button


func _fit_plaque_text(button: Button, preferred_font_size: int, minimum_font_size: int, horizontal_padding := 22.0) -> void:
	var font := button.get_theme_font("font")
	var resolved := maxi(8, roundi(preferred_font_size * _tweak_float(&"ui.font_scale", 1.0)))
	var available := maxf(1.0, button.size.x - horizontal_padding * 2.0)
	while resolved > minimum_font_size and font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, resolved).x > available:
		resolved -= 1
	button.clip_text = true
	button.add_theme_font_size_override("font_size", resolved)


func _place_plaque_on(parent: Control, button: Button, rect: Rect2, variant := "plate", accent := TAVERN.BRASS, font_size := 17) -> Button:
	_plaque(button, variant, accent, font_size)
	_place_on(parent, button, rect)
	_fit_plaque_text(button, font_size, maxi(9, font_size - 6))
	return button


## Static wooden plank/banner (not a button) used for headers such as the kitchen banner.
func _plank_on(parent: Control, rect: Rect2, variant := "sign", accent := TAVERN.BRASS, node_name := "TavernPlank") -> Control:
	var plank := TAVERN.Plaque.new()
	plank.name = node_name
	plank.variant = variant
	plank.accent = accent
	plank.notch = 12.0 if variant == "sign" else 8.0
	plank.seed_value = TAVERN.seed_from(node_name)
	plank.show_behind_parent = false
	_place_on(parent, plank, rect)
	plank.set_anchors_preset(Control.PRESET_TOP_LEFT)
	plank.position = rect.position
	plank.size = rect.size
	return plank


func _board_on(parent: Control, rect: Rect2, accent := TAVERN.BRASS, hanging := false, node_name := "TavernBoard") -> Control:
	var board := TAVERN.Board.new()
	board.name = node_name
	board.accent = accent
	board.hanging = hanging
	board.seed_value = TAVERN.seed_from(node_name + str(rect.size))
	_place_on(parent, board, rect)
	return board


## Blurred, vignetted dim behind a modal; fades in only when the modal first appears.
func _modal_backdrop(parent: Control, color: Color, key: String) -> ColorRect:
	var backdrop := ColorRect.new()
	backdrop.name = "ModalBackdrop"
	backdrop.color = _shade_color(color)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var blur := TAVERN.backdrop_material()
	backdrop.material = blur
	parent.add_child(backdrop)
	if key != _presented_modal and not debug_fast:
		blur.set_shader_parameter("fade", 0.0)
		backdrop.create_tween().tween_property(blur, "shader_parameter/fade", 1.0, 0.22 if not reduce_motion else 0.12)
	return backdrop


## Move everything a modal added after `start_index` into one group and play the hang-in entrance once.
func _present_modal(parent: Control, start_index: int, key: String) -> Control:
	var moving := parent.get_children().slice(start_index)
	var group := Control.new()
	group.name = "ModalGroup"
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.position = Vector2.ZERO
	group.size = BATTLE_LAYOUT.DESIGN_SIZE
	parent.add_child(group)
	for child in moving:
		child.reparent(group, false)
	if key != _presented_modal and not debug_fast:
		group.modulate.a = 0.0
		var tween := group.create_tween().set_parallel(true)
		if reduce_motion or motion_mode != JUICE_PROFILES.MOTION_FULL:
			tween.tween_property(group, "modulate:a", 1.0, 0.16)
		else:
			group.position = Vector2(0, -46)
			tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(group, "position", Vector2.ZERO, 0.38)
			tween.tween_property(group, "modulate:a", 1.0, 0.2)
		if juice != null:
			juice.play_sfx("hover", -14.0)
	return group


func _render_title() -> void:
	_clear_ui()
	_add_background(DB.art("title_kitchen"), Color("#DFFFFFFF"))
	var background := screen_layer.get_child(screen_layer.get_child_count() - 1) as Control
	var entering := last_rendered_screen != "title"
	if entering and _motion_full():
		_title_entrance_msec = -1
	# Re-renders during the entrance (e.g. a leaderboard sync) continue the choreography instead of skipping it.
	var animate := _motion_full() and (_title_entrance_msec == -1 or Time.get_ticks_msec() - _title_entrance_msec < 1500)
	if _motion_full() and background != null:
		# Slow breathing push-in keeps the kitchen alive behind the menu.
		background.pivot_offset = BATTLE_LAYOUT.DESIGN_SIZE * 0.5
		var drift := background.create_tween().set_loops()
		drift.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(background, "scale", Vector2(1.035, 1.035), 9.0)
		drift.tween_property(background, "scale", Vector2.ONE, 9.0)
	var shade := ColorRect.new()
	shade.color = _shade_color(Color("#85100A18"))
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_layer.add_child(shade)
	# Candle and hearth light pools painted back over the shade.
	for light: Array in [
		[Rect2(470, 60, 310, 190), Color("#FFB45A"), 0.34],
		[Rect2(1030, 170, 150, 170), Color("#FFB04A"), 0.42],
		[Rect2(90, 300, 260, 230), Color("#FF8A2E"), 0.5],
		[Rect2(220, 360, 190, 130), Color("#FF9A3C"), 0.38],
	]:
		var glow := TAVERN.CandleGlow.new()
		glow.color = light[1]
		glow.intensity = light[2]
		glow.animate = _motion_full()
		_place(glow, light[0])
	# Soft top and bottom scrims keep the lockup and the footer legible over busy kitchen art.
	_place(_vertical_scrim(Color(INK, 0.72), Color(INK, 0.0)), Rect2(0, 0, 1280, 300))
	_place(_vertical_scrim(Color(INK, 0.0), Color(INK, 0.78)), Rect2(0, 560, 1280, 160))
	if not reduce_motion and motion_mode != JUICE_PROFILES.MOTION_MINIMAL and particle_density > 0.0:
		var embers := TAVERN.make_embers(Rect2(150, 400, 250, 50), maxi(4, roundi(22 * particle_density)))
		screen_layer.add_child(embers)
		var motes := TAVERN.make_embers(Rect2(440, 180, 420, 300), maxi(3, roundi(14 * particle_density)), Color("#E9D7FF"), 7.0, Vector2(4, 12), Vector2(0.25, 0.6), -1.0)
		motes.spread = 180.0
		screen_layer.add_child(motes)

	# Hanging START sign; its chains are a separate node placed before the lockup so they disappear
	# behind the logo while the sign itself stays in front.
	var start_button := _button(t("title.start"), start_new_run, EMBER)
	start_button.name = "TitleStartButton"
	start_button.set_meta("juice_preserve_position", true)
	_plaque(start_button, "sign", TAVERN.BRASS, 26)
	start_button.add_theme_color_override("font_color", Color("#FFE3A0"))
	start_button.position = Vector2(470, 262)
	start_button.size = Vector2(340, 86)
	var chains := TAVERN.SignChains.new()
	chains.target = start_button
	chains.chain_height = 150.0
	_place(chains, Rect2(start_button.position, start_button.size))
	var sway := TAVERN.SwayDriver.new()
	sway.amplitude = 0.012 if _motion_full() else 0.0
	sway.initial_swing = 0.05 if animate else 0.0
	start_button.add_child(sway)

	var title := _label(t("title.heading"), 74, Color("#FFE8B4"), HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "TitleHeading"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_set_font(title, L10N.TITLE_FONT_RESOURCE)
	title.add_theme_color_override("font_outline_color", Color("#1A0A12"))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.62))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("shadow_outline_size", 14)
	_fit_label_width(title, 1040.0, 52)
	_place(title, Rect2(120, 58, 1040, 104))
	if _motion_full():
		title.material = TAVERN.shine_material(title.size, 5.5)
	var ribbon_start_index := screen_layer.get_child_count()
	_place_title_subtitle(t("title.subtitle"), 172.0)
	var ribbon_parts := screen_layer.get_children().slice(ribbon_start_index)
	_place(start_button, Rect2(470, 262, 340, 86))
	_fit_plaque_text(start_button, 26, 16, 34.0)
	start_button.pivot_offset = Vector2(170, -150)

	# Secondary actions: wooden plates nailed to the front of the counter.
	var plates: Array[Button] = []
	var multiplayer_button := _button(t("mp.title_button"), func(): get_tree().change_scene_to_file("res://scenes/multiplayer.tscn"), TEAL)
	multiplayer_button.name = "TitleMultiplayerButton"
	plates.append(multiplayer_button)
	var leaderboard_button := _button(t("title.leaderboard"), _open_leaderboard, TEAL)
	leaderboard_button.name = "TitleLeaderboardButton"
	plates.append(leaderboard_button)
	var settings_button := _button(t("title.settings"), func(): settings_open = true; _render_current_screen(), COPPER)
	settings_button.name = "TitleSettingsButton"
	plates.append(settings_button)
	for plate_index in range(plates.size()):
		var plate := plates[plate_index]
		_plaque(plate, "plate", TAVERN.BRASS, 16)
		_place(plate, Rect2(316 + plate_index * 222, 612, 204, 48))
		_fit_plaque_text(plate, 16, 11, 26.0)

	var language_toggle := _button(t("title.language_toggle"), _toggle_language, TEAL if L10N.current_locale() == "zh-CN" else EMBER)
	language_toggle.name = "LanguageToggle"
	language_toggle.tooltip_text = t("title.language_tooltip.%s" % ("english" if L10N.current_locale() == "zh-CN" else "chinese"))
	_plaque(language_toggle, "chip", TAVERN.BRASS, 14)
	L10N.apply_font(language_toggle)
	_place(language_toggle, Rect2(1148, 18, 116, 34))

	var licenses := _button(t("ui.open_source_licenses"), OpenSourceLicenses.open.bind(self), COPPER)
	licenses.name = "OpenSourceLicensesButton"
	licenses.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_style_title_quiet(licenses, 12, 6, false)
	_place(licenses, Rect2(16, 684, 200, 28))
	var hints := _place_input_hints(Rect2(440, 678, 400, 30))

	var menu_items: Array[Button] = [start_button]
	menu_items.append_array(plates)
	var cursor := TAVERN.SelectionBrackets.new()
	cursor.reduce_motion = not _motion_full()
	screen_layer.add_child(cursor)
	cursor.snap_to(start_button)
	_title_cursor = cursor
	for item: Button in menu_items:
		item.focus_entered.connect(func():
			if is_instance_valid(cursor):
				cursor.target = item
		)
		item.mouse_entered.connect(func():
			if not item.has_focus() and not (leaderboard_open or settings_open or rules_open):
				item.grab_focus()
		)
	language_toggle.focus_entered.connect(func():
		if is_instance_valid(cursor):
			cursor.target = language_toggle
	)
	cursor.visible = not (leaderboard_open or settings_open or rules_open)

	if animate:
		_title_entrance(title, ribbon_parts, start_button, plates, [language_toggle, licenses, hints])

	if leaderboard_open:
		_render_leaderboard_overlay()
	elif rules_open:
		_render_rules_overlay()
	elif settings_open:
		_render_settings_overlay()
	else:
		_defer_focus(start_button)
	_post_render()


## Staggered title entrance: logo drops and settles, the sign swings down on its chains, plates rise.
func _title_entrance(title: Control, ribbon_parts: Array, sign: Control, plates: Array[Button], extras: Array) -> void:
	var title_rest := title.position
	title.position = title_rest + Vector2(0, -56)
	title.scale = Vector2(1.14, 1.14)
	title.modulate.a = 0.0
	var sign_rest := sign.position
	sign.position = sign_rest + Vector2(0, -300)
	var plate_rests: Array[Vector2] = []
	for plate in plates:
		plate_rests.append(plate.position)
		plate.position += Vector2(0, 40)
		plate.modulate.a = 0.0
	for part in ribbon_parts:
		(part as CanvasItem).modulate.a = 0.0
	for extra in extras:
		(extra as CanvasItem).modulate.a = 0.0
	# The first title frame pays for texture uploads and shader compiles; start the choreography after
	# it so a long first frame cannot fast-forward the entrance.
	var elapsed := 0.0
	if _title_entrance_msec == -1:
		await get_tree().process_frame
		await get_tree().process_frame
		if not is_instance_valid(title) or not is_instance_valid(sign):
			return
		if _title_entrance_msec == -1:
			_title_entrance_msec = Time.get_ticks_msec()
	elapsed = maxf(0.0, float(Time.get_ticks_msec() - _title_entrance_msec) / 1000.0)
	var tweens: Array[Tween] = []
	var logo := title.create_tween().set_parallel(true)
	tweens.append(logo)
	logo.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	logo.tween_property(title, "position", title_rest, 0.6)
	logo.tween_property(title, "scale", Vector2.ONE, 0.6)
	logo.tween_property(title, "modulate:a", 1.0, 0.3)
	for part in ribbon_parts:
		if is_instance_valid(part):
			var part_item := part as CanvasItem
			var fade := part_item.create_tween()
			fade.tween_property(part_item, "modulate:a", 1.0, 0.35).set_delay(0.3)
			tweens.append(fade)
	var drop := sign.create_tween()
	tweens.append(drop)
	drop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drop.tween_property(sign, "position", sign_rest, 0.62).set_delay(0.3)
	var sway := sign.get_node_or_null("SwayDriver")
	if sway != null:
		# The landing jolt starts the decaying swing.
		drop.tween_callback(func(): if is_instance_valid(sway): sway.set("_time", 0.0))
	for plate_index in range(plates.size()):
		var plate := plates[plate_index]
		if not is_instance_valid(plate):
			continue
		var plate_rest := plate_rests[plate_index]
		var rise := plate.create_tween().set_parallel(true)
		tweens.append(rise)
		rise.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rise.tween_property(plate, "position", plate_rest, 0.42).set_delay(0.6 + plate_index * 0.1)
		rise.tween_property(plate, "modulate:a", 1.0, 0.25).set_delay(0.6 + plate_index * 0.1)
	for extra in extras:
		if not is_instance_valid(extra):
			continue
		var extra_item := extra as CanvasItem
		var reveal := extra_item.create_tween()
		tweens.append(reveal)
		reveal.tween_property(extra_item, "modulate:a", 1.0, 0.4).set_delay(0.95)
	if elapsed > 0.0:
		for tween in tweens:
			if tween.is_valid():
				tween.custom_step(elapsed)


## Corner prompt chips: [↑↓] select · [Enter] confirm.
func _place_input_hints(rect: Rect2) -> Control:
	var row := HBoxContainer.new()
	row.name = "InputHints"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for hint: Array in [["", true, "title.hint.select"], ["ENTER", false, "title.hint.confirm"]]:
		var cap := TAVERN.KeyCap.new()
		cap.legend = hint[0]
		cap.arrows = hint[1]
		cap.font = L10N.BUTTON_FONT_RESOURCE
		cap.font_size = 10
		cap.custom_minimum_size = Vector2(26 if hint[1] else 50, 22)
		row.add_child(cap)
		var label := _label(t(hint[2]), 12, Color(CREAM, 0.72), HORIZONTAL_ALIGNMENT_LEFT)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.add_theme_font_override("font", L10N.BUTTON_FONT_RESOURCE)
		label.add_theme_color_override("font_outline_color", HUD_TEXT_OUTLINE_COLOR)
		label.add_theme_constant_override("outline_size", 3)
		row.add_child(label)
		if hint[1]:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(10, 1)
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(spacer)
	_place(row, rect)
	return row


func _vertical_scrim(top: Color, bottom: Color) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, top)
	gradient.set_color(1, bottom)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 64
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _chalk_rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(CREAM, 0.1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


## Subtitle ribbon: tracked display caps flanked by hairlines and diamond studs (no manual spaces).
func _place_title_subtitle(text: String, y: float) -> void:
	var font := L10N.HEADING_FONT_RESOURCE
	var font_size := 22
	var subtitle := _label(text, font_size, EMBER, HORIZONTAL_ALIGNMENT_CENTER)
	subtitle.name = "TitleSubtitle"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	_set_font(subtitle, font)
	subtitle.add_theme_color_override("font_outline_color", Color("#1A0A12"))
	subtitle.add_theme_constant_override("outline_size", 4)
	var is_latin := text.to_upper() == text and text.unicode_at(0) < 0x2E80
	if is_latin:
		var tracked := FontVariation.new()
		tracked.base_font = font
		tracked.spacing_glyph = 7
		subtitle.add_theme_font_override("font", tracked)
		font = tracked
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	_place(subtitle, Rect2(340, y, 600, 34))
	var half_gap := text_width * 0.5 + 22.0
	for side: float in [-1.0, 1.0]:
		var line_from := Color(EMBER, 0.0) if side < 0.0 else Color(EMBER, 0.85)
		var line_to := Color(EMBER, 0.85) if side < 0.0 else Color(EMBER, 0.0)
		var gradient := Gradient.new()
		gradient.set_color(0, line_from)
		gradient.set_color(1, line_to)
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 64
		texture.height = 2
		var line := TextureRect.new()
		line.texture = texture
		line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		line.stretch_mode = TextureRect.STRETCH_SCALE
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var line_width := 120.0
		var line_x := 640.0 - half_gap - line_width if side < 0.0 else 640.0 + half_gap
		_place(line, Rect2(line_x, y + 17, line_width, 1.5))
		var stud := Panel.new()
		stud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stud_style := StyleBoxFlat.new()
		stud_style.bg_color = GOLD
		stud.add_theme_stylebox_override("panel", stud_style)
		stud.rotation = PI * 0.25
		var stud_x := 640.0 + side * (half_gap - 8.0)
		_place(stud, Rect2(stud_x - 3.5, y + 14, 7, 7))
		stud.pivot_offset = Vector2(3.5, 3.5)


func _fit_label_width(label: Label, available_width: float, minimum_font_size: int) -> void:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	while font_size > minimum_font_size and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > available_width - 24.0:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)


func _title_button_style(background: Color, border: Color, width: int, radius: int, shadow := Color.TRANSPARENT, shadow_size := 0) -> StyleBoxFlat:
	var style := _style(background, border, width, radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	if shadow_size > 0:
		style.shadow_color = shadow
		style.shadow_size = shadow_size
		style.shadow_offset = Vector2(0, 3)
	return style


func _focus_ring_style(radius: int, color := GOLD) -> StyleBoxFlat:
	var style := _style(Color.TRANSPARENT, color, 2, radius)
	style.draw_center = false
	style.expand_margin_left = 3
	style.expand_margin_right = 3
	style.expand_margin_top = 3
	style.expand_margin_bottom = 3
	style.shadow_color = Color(color, 0.35)
	style.shadow_size = 6
	return style


## Primary CTA: filled copper-to-ember plate with dark ink label; clearly outranks the secondary stack.
func _style_title_primary(button: Button) -> void:
	button.add_theme_font_size_override("font_size", maxi(8, roundi(21 * _tweak_float(&"ui.font_scale", 1.0))))
	button.add_theme_font_override("font", L10N.HEADING_FONT_RESOURCE)
	for color_name in ["font_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color_name, Color("#24100A"))
	button.add_theme_color_override("font_hover_color", Color("#1A0A06"))
	button.add_theme_stylebox_override("normal", _title_button_style(Color("#E39A45"), Color("#FFE0A0"), 2, 12, Color(0, 0, 0, 0.55), 8))
	button.add_theme_stylebox_override("hover", _title_button_style(Color("#F5B35C"), Color("#FFF1C8"), 2, 12, Color(GOLD, 0.45), 12))
	button.add_theme_stylebox_override("pressed", _title_button_style(Color("#C27A33"), Color("#FFE0A0"), 2, 12, Color(0, 0, 0, 0.55), 4))
	button.add_theme_stylebox_override("hover_pressed", button.get_theme_stylebox("pressed"))
	button.add_theme_stylebox_override("focus", _focus_ring_style(14, Color("#FFF1C8")))


## Secondary actions share one size/style so the stack reads as a single system.
func _style_title_secondary(button: Button, accent := COPPER, hover_accent := EMBER, font_size := 16) -> void:
	button.add_theme_font_size_override("font_size", maxi(8, roundi(font_size * _tweak_float(&"ui.font_scale", 1.0))))
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _title_button_style(Color(0.07, 0.035, 0.07, 0.82), Color(accent, 0.78), 1, 10, Color(0, 0, 0, 0.4), 6))
	button.add_theme_stylebox_override("hover", _title_button_style(Color(0.16, 0.08, 0.12, 0.92), hover_accent, 2, 10, Color(hover_accent, 0.28), 8))
	button.add_theme_stylebox_override("pressed", _title_button_style(Color(0.05, 0.025, 0.05, 0.92), GOLD, 2, 10))
	button.add_theme_stylebox_override("hover_pressed", button.get_theme_stylebox("pressed"))
	button.add_theme_stylebox_override("focus", _focus_ring_style(12))


## Quiet utility item (language chip, licenses link): low contrast at rest, clear on hover/focus.
func _style_title_quiet(button: Button, font_size: int, radius: int, bordered: bool) -> void:
	button.add_theme_font_size_override("font_size", maxi(8, roundi(font_size * _tweak_float(&"ui.font_scale", 1.0))))
	button.add_theme_color_override("font_color", Color(CREAM, 0.82) if bordered else Color(MUTED, 0.78))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	var rest := _title_button_style(Color(0.05, 0.025, 0.05, 0.72) if bordered else Color.TRANSPARENT, Color(CREAM, 0.28) if bordered else Color.TRANSPARENT, 1 if bordered else 0, radius)
	rest.content_margin_left = 12
	rest.content_margin_right = 12
	rest.content_margin_top = 2
	rest.content_margin_bottom = 2
	button.add_theme_stylebox_override("normal", rest)
	var hover := rest.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.06, 0.1, 0.8)
	hover.border_color = Color(EMBER, 0.9)
	hover.set_border_width_all(1)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	button.add_theme_stylebox_override("focus", _focus_ring_style(radius))
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER if bordered else HORIZONTAL_ALIGNMENT_LEFT


func _toggle_language() -> void:
	L10N.toggle_locale(true)
	DisplayServer.window_set_title(t("app.title"))
	_render_title()


func _open_leaderboard() -> void:
	leaderboard_open = true
	_render_title()
	call_deferred("_sync_global_leaderboard")


func _close_leaderboard() -> void:
	if chef_name_input != null and is_instance_valid(chef_name_input):
		_commit_player_name(chef_name_input.text)
	leaderboard_open = false
	_render_title()


func _render_leaderboard_overlay() -> void:
	_modal_backdrop(screen_layer, Color(MODAL_MASK, 0.62), "leaderboard")
	var start_index := screen_layer.get_child_count()
	_render_leaderboards(Rect2(150, 50, 980, 610), true, true)
	var done := _place_plaque_on(screen_layer, _button(t("common.done_escape"), _close_leaderboard, COPPER), Rect2(440, 592, 400, 48), "plate", TAVERN.BRASS, 17)
	done.name = "CloseLeaderboardButton"
	_present_modal(screen_layer, start_index, "leaderboard")


func _render_leaderboards(rect: Rect2, show_refresh: bool, show_name_edit := false) -> void:
	_board_on(screen_layer, rect, EMBER, screen_name == "title", "LeaderboardBoard")
	_place(_texture(DB.art("leaderboard_crest")), Rect2(rect.position + Vector2(16, 10), Vector2(78, 78)))
	var heading_width := rect.size.x - (500.0 if show_name_edit else 120.0)
	_heading(screen_layer, t("leaderboard.heading"), 24, CREAM, Rect2(rect.position + Vector2(102, 18), Vector2(heading_width, 34)), HORIZONTAL_ALIGNMENT_LEFT)
	_place(_label(t("leaderboard.subheading"), 12, EMBER), Rect2(rect.position + Vector2(104, 50), Vector2(heading_width - 2.0, 22)))
	if show_name_edit:
		_place(_label(t("leaderboard.chef_name"), 12, TEAL, HORIZONTAL_ALIGNMENT_CENTER), Rect2(rect.position + Vector2(rect.size.x - 320, 12), Vector2(280, 22)))
		var name_input := _line_edit(player_name, t("leaderboard.chef_placeholder"))
		name_input.text_submitted.connect(func(value: String):
			_commit_player_name(value)
			name_input.text = player_name
			name_input.release_focus()
		)
		name_input.focus_exited.connect(func():
			_commit_player_name(name_input.text)
			if is_instance_valid(name_input):
				name_input.text = player_name
		)
		_place(name_input, Rect2(rect.position + Vector2(rect.size.x - 320, 38), Vector2(280, 44)))
		chef_name_input = name_input

	var padding := 16.0
	var gap := 10.0
	var column_width := (rect.size.x - padding * 2.0 - gap) / 2.0
	var local_rect := Rect2(rect.position + Vector2(padding, 94), Vector2(column_width, 270))
	var global_rect := Rect2(rect.position + Vector2(padding + column_width + gap, 94), Vector2(column_width, 270))
	var global_records: Array[Dictionary] = []
	if leaderboard != null:
		global_records = leaderboard.entries
	_render_leaderboard_column(t("leaderboard.local"), local_scores, local_rect, true)
	_render_leaderboard_column(t("leaderboard.global"), global_records, global_rect, false)

	var status_text := t("leaderboard.status.offline")
	var status_color := MUTED
	if leaderboard != null:
		match leaderboard.status:
			"loading":
				status_text = t("leaderboard.status.connecting")
				status_color = EMBER
			"ready":
				status_text = t("leaderboard.status.live")
				status_color = TEAL
			"error":
				status_text = t("leaderboard.status.retry")
				if not leaderboard.diagnostic_code.is_empty():
					status_text = t("leaderboard.status.retry_detail", {"code": leaderboard.diagnostic_code})
				status_color = CRIMSON
	if screen_name == "end" and not last_run_ranked_eligible:
		status_text = t("leaderboard.status.custom_rules")
		status_color = EMBER
	if not pending_global_submissions.is_empty() and (leaderboard == null or leaderboard.status != "loading"):
		status_text = t("leaderboard.status.pending", {"status": status_text, "count": pending_global_submissions.size()})
	_place(_label(status_text, 12, status_color, HORIZONTAL_ALIGNMENT_CENTER), Rect2(rect.position + Vector2(18, 378), Vector2(rect.size.x - 36, 24)))
	var rules_note := t("leaderboard.rules_note")
	if screen_name == "end":
		var submission_note_break := rules_note.find("\n")
		rules_note = rules_note.substr(submission_note_break + 1) if submission_note_break >= 0 else ""
	if not rules_note.is_empty():
		_place(_label(rules_note, 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER), Rect2(rect.position + Vector2(28, 403), Vector2(rect.size.x - 56, 40)))
	if show_refresh:
		var retrying := leaderboard != null and leaderboard.status == "loading"
		var refresh := _place_plaque_on(screen_layer, _button(t("leaderboard.refresh"), _sync_global_leaderboard, TEAL, retrying), Rect2(rect.position + Vector2(86, 454), Vector2(rect.size.x - 172, 40)), "plate", TEAL, 15)
		refresh.name = "RefreshLeaderboardButton"


func _render_leaderboard_column(heading: String, records: Array[Dictionary], rect: Rect2, is_local: bool) -> void:
	_heading(screen_layer, heading, 15, TEAL if is_local else EMBER, Rect2(rect.position, Vector2(rect.size.x, 26)), HORIZONTAL_ALIGNMENT_CENTER)
	_place(_label(t("leaderboard.columns"), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER), Rect2(rect.position + Vector2(2, 27), Vector2(rect.size.x - 4, 18)))
	if records.is_empty():
		var empty_text := t("leaderboard.empty.local" if is_local else "leaderboard.empty.global")
		if not is_local and leaderboard != null and leaderboard.status in ["offline", "error"]:
			empty_text = t("leaderboard.empty.unavailable")
		_place(_label(empty_text, 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER), Rect2(rect.position + Vector2(8, 82), Vector2(rect.size.x - 16, 82)))
	for index in range(LEADERBOARD_CLIENT.DISPLAY_LIMIT):
		var row_rect := Rect2(rect.position + Vector2(0, 50 + index * 43), Vector2(rect.size.x, 38))
		if index >= records.size():
			_place(_label("%d     —" % (index + 1), 12, Color("#6E665A")), row_rect)
			_place(_chalk_rule(), Rect2(row_rect.position + Vector2(0, row_rect.size.y + 1), Vector2(row_rect.size.x, 1)))
			continue
		var record: Dictionary = records[index]
		var highlighted := is_local and String(record.get("submission_id", "")) == last_run_submission_id
		var local_only := is_local and not bool(record.get("ranked_eligible", true))
		var row_plate := _panel(row_rect, Color(0.07, 0.04, 0.05, 0.55) if not highlighted else Color(0.05, 0.16, 0.14, 0.7), TEAL if highlighted else Color(0, 0, 0, 0), 2 if highlighted else 0, 6)
		if highlighted:
			var glow_style := row_plate.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
			glow_style.shadow_color = Color(TEAL, 0.35)
			glow_style.shadow_size = 8
			row_plate.add_theme_stylebox_override("panel", glow_style)
		_place(_chalk_rule(), Rect2(row_rect.position + Vector2(0, row_rect.size.y + 1), Vector2(row_rect.size.x, 1)))
		var medal_colors := [GOLD, Color("#DCDCE6"), Color("#D98B4E")]
		var rank_color: Color = medal_colors[index] if index < 3 else EMBER
		_place(_set_font(_label(str(index + 1), 16, rank_color, HORIZONTAL_ALIGNMENT_CENTER), L10N.NUMBER_FONT_RESOURCE), Rect2(row_rect.position + Vector2(4, 1), Vector2(24, 36)))
		var chef_name := String(record.get("name", t("leaderboard.chef_fallback")))
		if chef_name.length() > 12:
			chef_name = chef_name.substr(0, 11) + "…"
		if local_only:
			chef_name += " *"
		_place(_label(chef_name, 12, EMBER if local_only else CREAM), Rect2(row_rect.position + Vector2(32, 1), Vector2(row_rect.size.x - 94, 36)))
		_place(_set_font(_label(str(int(record.get("score", 0))), 15, TEAL if highlighted else CREAM, HORIZONTAL_ALIGNMENT_RIGHT), L10N.NUMBER_FONT_RESOURCE), Rect2(row_rect.position + Vector2(row_rect.size.x - 68, 1), Vector2(62, 36)))


func _render_rules_overlay() -> void:
	_modal_backdrop(screen_layer, Color(MODAL_MASK, 0.4), "rules")
	var start_index := screen_layer.get_child_count()
	_board_on(screen_layer, Rect2(170, 86, 940, 548), TEAL, true, "RulesBoard")
	_heading(screen_layer, t("rules.heading"), 30, CREAM, Rect2(210, 108, 860, 46), HORIZONTAL_ALIGNMENT_CENTER)
	var rules := t("rules.body")
	_place(_label(rules, 17, MUTED), Rect2(224, 166, 832, 374))
	_place_plaque_on(screen_layer, _button(t("rules.understood"), func(): rules_open = false; _render_title(), TEAL), Rect2(430, 560, 420, 50), "plate", TEAL, 17)
	_present_modal(screen_layer, start_index, "rules")


func _centered_safe_modal_rect(preferred_size: Vector2) -> Rect2:
	var modal_bounds := _target_battle_zone(&"modal")
	var resolved_size := Vector2(minf(preferred_size.x, modal_bounds.size.x - 24.0), minf(preferred_size.y, modal_bounds.size.y - 24.0))
	return Rect2(modal_bounds.get_center() - resolved_size * 0.5, resolved_size)


func _render_settings_overlay(parent: Control = null) -> void:
	if parent == null:
		parent = screen_layer
	var key := "pause_settings" if pause_open else "settings"
	_modal_backdrop(parent, Color(MODAL_MASK, 0.3), key)
	var start_index := parent.get_child_count()

	var panel_rect := _centered_safe_modal_rect(Vector2(790, 570))
	_modal_panel_on(parent, panel_rect, COPPER)
	_heading(parent, t("settings.heading"), 29, CREAM, Rect2(panel_rect.position + Vector2(45, 20), Vector2(700, 44)), HORIZONTAL_ALIGNMENT_CENTER)
	_place_on(parent, _label(t("settings.description"), 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER), Rect2(panel_rect.position + Vector2(45, 62), Vector2(700, 28)))
	var left_x := panel_rect.position.x + 49.0
	var right_x := panel_rect.position.x + 411.0
	var width := 330.0
	var rows := [
		[left_x, 106, "settings.motion", t("settings.motion.%s" % motion_mode), _toggle_motion],
		[left_x, 166, "settings.shake", _intensity_name(shake_intensity), _cycle_shake],
		[left_x, 226, "settings.flash", _intensity_name(flash_intensity), _cycle_flash],
		[left_x, 286, "settings.particles", _intensity_name(particle_density), _cycle_particles],
		[right_x, 106, "settings.sound", t("common.off" if _effective_sound_muted() else "common.on"), _toggle_sound],
		[right_x, 166, "settings.animation_speed", "%.1f" % animation_speed, _cycle_animation_speed],
		[right_x, 226, "settings.acceleration", t("common.on" if auto_accelerate else "common.off"), _toggle_acceleration],
		[right_x, 286, "settings.captions", t("common.on" if captions_enabled else "common.off"), _toggle_captions],
	]
	for row: Array in rows:
		_settings_row(parent, Rect2(row[0], panel_rect.position.y + row[1], width, 49), row[2], row[3], row[4])
	_place_on(parent, _label(t("settings.minimal_motion_note"), 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER), Rect2(panel_rect.position + Vector2(65, 362), Vector2(660, 48)))
	var done := _place_plaque_on(parent, _button(t("common.done_escape"), _close_settings, TEAL), Rect2(panel_rect.position + Vector2(205, 446), Vector2(380, 54)), "plate", TEAL, 18)
	done.name = "CloseSettingsButton"
	_present_modal(parent, start_index, key)


func _modal_panel_on(parent: Control, rect: Rect2, accent: Color) -> Panel:
	var panel := Panel.new()
	panel.name = "ModalPanel"
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_place_on(parent, panel, rect)
	var board := TAVERN.Board.new()
	board.accent = accent
	board.hanging = true
	board.seed_value = TAVERN.seed_from(str(rect.size))
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(board)
	return panel


func _settings_option(button: Button) -> Button:
	_style_title_secondary(button, COPPER, EMBER, 16)
	return button


## One settings line on the menu board: engraved name on the left, a brass toggle (ON/OFF) or a
## ‹ value › selector on the right. The Button keeps its full "NAME  VALUE" text for lookups and
## accessibility, but renders it through the themed parts.
func _settings_row(parent: Control, rect: Rect2, key: String, value_text: String, callback: Callable) -> Button:
	var marker := "\u0001"
	var composed := t(key, {"value": marker})
	var marker_index := composed.find(marker)
	var name_text := composed.substr(0, marker_index).strip_edges() if marker_index >= 0 else composed
	var suffix := composed.substr(marker_index + 1).strip_edges() if marker_index >= 0 else ""
	var button := _button(t(key, {"value": value_text}), callback, COPPER)
	_plaque(button, "row", EMBER, 15)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color", "font_outline_color"]:
		button.add_theme_color_override(state, Color.TRANSPARENT)
	button.add_theme_constant_override("outline_size", 0)
	_place_on(parent, button, rect)
	var name_label := _label(name_text, 15, CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.name = "SettingName"
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.add_theme_font_override("font", L10N.BUTTON_FONT_RESOURCE)
	name_label.add_theme_color_override("font_outline_color", Color("#120704"))
	name_label.add_theme_constant_override("outline_size", 3)
	_place_on(button, name_label, Rect2(22, 0, rect.size.x - 136, rect.size.y))
	_fit_label_width(name_label, rect.size.x - 136 + 24.0, 10)
	var is_toggle := value_text == t("common.on") or value_text == t("common.off")
	if is_toggle:
		var toggle := TAVERN.ToggleSwitch.new()
		toggle.on = value_text == t("common.on")
		toggle.lit_color = TEAL
		_place_on(button, toggle, Rect2(rect.size.x - 66, (rect.size.y - 22) * 0.5, 50, 22))
		var state_label := _label(value_text, 12, TEAL if toggle.on else MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		state_label.name = "SettingValue"
		state_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		state_label.add_theme_font_override("font", L10N.BUTTON_FONT_RESOURCE)
		_place_on(button, state_label, Rect2(rect.size.x - 120, 0, 48, rect.size.y))
	else:
		var value_label := _display_label(value_text + suffix, L10N.HEADING_FONT_RESOURCE, 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 3)
		value_label.name = "SettingValue"
		_place_on(button, value_label, Rect2(rect.size.x - 110, 0, 86, rect.size.y))
		_fit_label_width(value_label, 86 + 24.0, 10)
		for side: float in [-1.0, 1.0]:
			var chevron := _label("‹" if side < 0.0 else "›", 20, Color(EMBER, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
			chevron.autowrap_mode = TextServer.AUTOWRAP_OFF
			chevron.add_theme_font_override("font", L10N.HEADING_FONT_RESOURCE)
			_place_on(button, chevron, Rect2((rect.size.x - 124) if side < 0.0 else (rect.size.x - 26), 0, 14, rect.size.y - 3))
	return button


func _render_pause_overlay() -> void:
	if not pause_open:
		return
	var overlay := Control.new()
	overlay.name = "PauseOverlay"
	overlay.z_index = PAUSE_MODAL_Z_INDEX
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_layer.add_child(overlay)
	if settings_open:
		_render_settings_overlay(overlay)
		return

	_modal_backdrop(overlay, Color(MODAL_MASK, 0.45), "pause")
	var start_index := overlay.get_child_count()
	var pause_rect := _centered_safe_modal_rect(Vector2(500, 372))
	_modal_panel_on(overlay, pause_rect, COPPER)
	_heading(overlay, t("pause.heading"), 38, CREAM, Rect2(pause_rect.position + Vector2(40, 36), Vector2(420, 58)), HORIZONTAL_ALIGNMENT_CENTER)
	_place_on(overlay, _label(t("pause.resume_hint"), 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER), Rect2(pause_rect.position + Vector2(40, 96), Vector2(420, 28)))
	var resign_button := _button(t("pause.resign"), _resign_run, CRIMSON)
	resign_button.name = "PauseResignButton"
	_place_plaque_on(overlay, resign_button, Rect2(pause_rect.position + Vector2(70, 168), Vector2(360, 56)), "plate", CRIMSON, 18)
	var pause_settings_button := _button(t("title.settings"), _open_pause_settings, COPPER)
	pause_settings_button.name = "PauseSettingsButton"
	_place_plaque_on(overlay, pause_settings_button, Rect2(pause_rect.position + Vector2(70, 240), Vector2(360, 56)), "plate", TAVERN.BRASS, 18)
	_present_modal(overlay, start_index, "pause")
	_defer_focus(pause_settings_button)


func _render_battle() -> void:
	prior_hand_positions = visual_hand_positions.duplicate()
	prior_unit_rects = visual_unit_rects.duplicate()
	visual_hand_positions.clear()
	visual_unit_rects.clear()
	_clear_ui()
	_add_background(DB.art("battle_board"), Color("#C8FFFFFF"))
	var shade := ColorRect.new()
	shade.color = _shade_color(Color("#42100A18"))
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_layer.add_child(shade)
	_add_battle_lights()

	_render_top_status()
	_render_board_row(enemy_board, false)
	_render_board_row(player_board, true)
	_render_player_deck()
	_render_hand()
	_render_battle_controls()
	if service_history_open:
		_render_service_history_dialog()
	_render_pause_overlay()
	_post_render()
	_render_tutorial()


## Wall candles, the oven mouth and the brazier on the battle art get soft flickering light pools.
func _add_battle_lights() -> void:
	for light: Array in [
		[Rect2(52, 80, 120, 120), Color("#FFB04A"), 0.5],
		[Rect2(1100, 85, 120, 120), Color("#FFB04A"), 0.5],
		[Rect2(560, 40, 160, 110), Color("#FF7A2A"), 0.32],
		[Rect2(-20, 410, 130, 120), Color("#FF7A2A"), 0.42],
	]:
		var glow := TAVERN.CandleGlow.new()
		glow.color = light[1]
		glow.intensity = light[2]
		glow.animate = _motion_full()
		_place(glow, light[0])


func _render_top_status() -> void:
	_render_opponent_hand()

	var opponent_station_rect := _target_battle_zone(&"opponent_station")
	var hero_legal: bool = not pending_action.is_empty() and _first_guard_index(enemy_board) < 0 and (pending_action.get("kind") == "attack" or pending_action.get("effect") == "target_enemy_damage")
	var enemy_station := _button("", _on_enemy_hero_pressed, EMBER if hero_legal else CRIMSON)
	enemy_station.name = "EnemyHeroStation"
	enemy_station.clip_contents = true
	enemy_station.z_index = 6
	enemy_station.set_meta("juice_kind", "hero")
	enemy_station.set_meta("hero_side", "enemy")
	enemy_station.set_meta("legal_target", hero_legal)
	_make_button_chromeless(enemy_station)
	_place(enemy_station, opponent_station_rect)
	_add_hero_station_contents(enemy_station, DB.art(DB.encounter(current_encounter_id).portrait), enemy_name, enemy_health, enemy_max_health, enemy_armor, CRIMSON, true)
	enemy_hero_button = enemy_station
	enemy_hero_anchor = _control_rect_in_layer(enemy_station, screen_layer).get_center()

	var passive_rect := _target_battle_zone(&"passive")
	var passive_button := _button("", _noop, COPPER)
	passive_button.name = "EnemyPassiveButton"
	passive_button.tooltip_text = t("battle.enemy_skill", {"skill": enemy_passive})
	passive_button.set_meta("cursor_mode", "inspect")
	_make_button_chromeless(passive_button)
	_place(passive_button, passive_rect)
	_place_portrait_backdrop(passive_button, PASSIVE_PORTRAIT_BACKDROP_RECT, "PassivePortraitBackdrop")
	_place_on(passive_button, _texture(DB.art("hud_passive_medallion_frame")), Rect2(Vector2.ZERO, passive_rect.size))
	_place_on(passive_button, _texture(DB.art("juice_encounter_seal")), Rect2(18, 17, 34, 34))

	var turn_rect := _target_battle_zone(&"banner")
	var turn_marker := Control.new()
	turn_marker.name = "TurnMarker"
	turn_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_marker.z_index = 14
	_place(turn_marker, turn_rect)
	_place_on(turn_marker, _texture(DB.art("hud_turn_marker")), Rect2(Vector2.ZERO, turn_rect.size))
	var turn_plate := _hud_readability_plate_on(turn_marker, Rect2(29, 2, turn_rect.size.x - 58, 28), banner_color, "TurnBannerPlate", 9)
	var banner_mana := _banner_mana_context()
	if banner_mana.is_empty():
		_set_font(_place_hud_label_on(turn_plate, banner_text, 13, 10, banner_color, Rect2(4, 2, turn_plate.size.x - 8, turn_plate.size.y - 4), "TurnBannerLabel", HORIZONTAL_ALIGNMENT_CENTER, 2), L10N.HEADING_FONT_RESOURCE)
	else:
		_place_mana_readout_on(turn_plate, String(banner_mana.get("value", "")), 12, banner_color, 16.0, banner_text, Rect2(4, 2, turn_plate.size.x - 8, turn_plate.size.y - 4), "TurnBannerManaReadout")

	var player_station_rect := _target_battle_zone(&"player_station")
	var player_status_panel := Control.new()
	player_status_panel.name = "PlayerStatusPanel"
	player_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_status_panel.clip_contents = true
	player_status_panel.z_index = 12
	_place(player_status_panel, player_station_rect)
	_add_hero_station_contents(player_status_panel, DB.art("chef_sama"), t("player.chef_sama"), player_health, player_max_health, player_armor, TEAL, false)
	player_hero_control = player_status_panel
	player_hero_anchor = _control_rect_in_layer(player_status_panel, screen_layer).get_center()

	var opponent_mana_rect := _target_battle_zone(&"opponent_mana")
	var enemy_mana_pool := Control.new()
	enemy_mana_pool.name = "EnemyManaPool"
	enemy_mana_pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_mana_pool.clip_contents = true
	_place(enemy_mana_pool, opponent_mana_rect)
	var enemy_mana_rack := _texture(DB.art("hud_mana_rack_frame"))
	enemy_mana_rack.name = "EnemyManaRackFrame"
	_place_on(enemy_mana_pool, enemy_mana_rack, Rect2(Vector2.ZERO, opponent_mana_rect.size))
	var enemy_mana_crystal := _texture(DB.art("juice_mana_burner"))
	enemy_mana_crystal.name = "EnemyManaCrystal"
	_place_on(enemy_mana_pool, enemy_mana_crystal, Rect2(14, 19, 34, 34))
	var enemy_mana_readout := _hud_readability_plate_on(enemy_mana_pool, Rect2(28, 25, 106, 30), CRIMSON, "EnemyManaReadoutPlate", 9)
	enemy_mana_readout.add_theme_stylebox_override("panel", _style(Color(HUD_DETAIL_BG, 1.0), Color(CRIMSON, 0.58), 1, 9))
	_set_font(_place_hud_label_on(enemy_mana_readout, t("battle.enemy_mana", {"current": enemy_mana, "maximum": enemy_max_mana}), 15, 9, CREAM, Rect2(0, 3, enemy_mana_readout.size.x, 24), "EnemyManaValue", HORIZONTAL_ALIGNMENT_CENTER, 2), L10N.NUMBER_FONT_RESOURCE)
	var enemy_pip_count := maxi(1, enemy_max_mana)
	var enemy_pip_diameter := 8.0
	var enemy_pip_width := enemy_pip_count * enemy_pip_diameter + maxi(0, enemy_pip_count - 1) * 4.0
	var enemy_pip_y := enemy_mana_readout.position.y + enemy_mana_readout.size.y + 4.0
	_render_resource_pips_on(enemy_mana_pool, Vector2((opponent_mana_rect.size.x - enemy_pip_width) * 0.5, enemy_pip_y), enemy_mana, enemy_pip_count, CRIMSON, enemy_pip_diameter)
	_render_opponent_deck()


func _render_opponent_deck() -> void:
	var deck_rect := _target_battle_zone(&"opponent_deck")
	var display := Control.new()
	display.name = "EnemyDeckDisplay"
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.set_meta("deck_count", enemy_deck.size())
	display.set_meta("deck_stack_rect", Rect2(deck_rect.position + DECK_CARD_OVERSCAN_RECT.position, DECK_CARD_OVERSCAN_RECT.size))
	_place(display, deck_rect)
	var cradle := _texture(DB.art("hud_deck_cradle"))
	cradle.name = "EnemyDeckCradle"
	_place_on(display, cradle, Rect2(Vector2.ZERO, deck_rect.size))
	if not enemy_deck.is_empty():
		_place_deck_face_cover(display, Vector2.ZERO, "EnemyDeck")
	_place_on(display, _set_font(_display_label(str(enemy_deck.size()), L10N.NUMBER_FONT_RESOURCE, 13, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 2), L10N.NUMBER_FONT_RESOURCE), Rect2(49, 92, 32, 20))


func _place_deck_face_cover(parent: Control, deck_origin: Vector2, name_prefix: String) -> TextureRect:
	var clip := Control.new()
	clip.name = "%sFaceClip" % name_prefix
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip_contents = true
	_place_on(parent, clip, Rect2(deck_origin + DECK_FACE_CLIP_RECT.position, DECK_FACE_CLIP_RECT.size))
	var aperture_backdrop := ColorRect.new()
	aperture_backdrop.name = "%sApertureBackdrop" % name_prefix
	aperture_backdrop.color = Color.BLACK
	aperture_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_on(clip, aperture_backdrop, Rect2(Vector2.ZERO, DECK_FACE_CLIP_RECT.size))
	var card_back := _texture(DB.art("juice_card_back"), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	card_back.name = "%sCardBack" % name_prefix
	_place_on(clip, card_back, Rect2(DECK_CARD_OVERSCAN_RECT.position - DECK_FACE_CLIP_RECT.position, DECK_CARD_OVERSCAN_RECT.size))
	return card_back


func _add_hero_station_contents(parent: Control, portrait_texture: Texture2D, display_name: String, health: int, maximum_health: int, armor: int, accent: Color, portrait_button := false) -> void:
	var hero_frame := _texture(DB.art("hud_hero_station_frame"))
	hero_frame.name = "HeroStationFrame"
	_place_on(parent, hero_frame, Rect2(Vector2.ZERO, parent.size))
	_place_hero_portrait_backdrop(parent)
	_place_hero_neutral_covers(parent)
	var portrait := _texture(portrait_texture, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	portrait.name = "HeroPortrait"
	_place_on(parent, portrait, HERO_PORTRAIT_RECT)
	# The black shield inlays carry the stat glyph of the plate beneath them (Health left, Armor right).
	for inlay: Array in [[HERO_NEUTRAL_COVER_LEFT_RECT, "icon_shield", "HeroHealthGlyph"], [HERO_NEUTRAL_COVER_RIGHT_RECT, "juice_armor_pan", "HeroArmorGlyph"]]:
		var inlay_rect: Rect2 = inlay[0]
		var glyph := _texture(DB.art(inlay[1]))
		glyph.name = inlay[2]
		_place_on(parent, glyph, Rect2(inlay_rect.position.x + inlay_rect.size.x * 0.5 - 12.0, inlay_rect.position.y + 1.0, 24, 24))

	var name_plate := _hud_readability_plate_on(parent, Rect2(40, 0, 176, 24), accent, "HeroNamePlate", 9)
	_set_font(_place_hud_label_on(name_plate, display_name, 14, 10, CREAM, Rect2(7, 1, 162, 22), "HeroNameLabel", HORIZONTAL_ALIGNMENT_CENTER, 2), L10N.NAME_FONT_RESOURCE)

	var health_plate := _hud_readability_plate_on(parent, Rect2(8, 92, 112, 28), accent, "HeroHealthPlate", 10)
	_set_font(_place_hud_label_on(health_plate, t("battle.health", {"current": health, "maximum": maximum_health}), 15, 10, accent.lightened(0.14), Rect2(6, 2, 100, 24), "HeroHealthLabel", HORIZONTAL_ALIGNMENT_CENTER, 2), L10N.NUMBER_FONT_RESOURCE)

	var armor_plate := _hud_readability_plate_on(parent, Rect2(136, 92, 112, 28), MUTED, "HeroArmorPlate", 10)
	_set_font(_place_hud_label_on(armor_plate, t("battle.armor", {"armor": armor}), 14, 9, CREAM, Rect2(6, 2, 100, 24), "HeroArmorLabel", HORIZONTAL_ALIGNMENT_CENTER, 2), L10N.NUMBER_FONT_RESOURCE)
	if portrait_button:
		parent.tooltip_text = "%s · %s · %s" % [display_name, t("battle.health", {"current": health, "maximum": maximum_health}), t("battle.armor", {"armor": armor})]


func _place_hero_portrait_backdrop(parent: Control) -> Panel:
	return _place_rounded_black_backdrop(parent, HERO_PORTRAIT_BACKDROP_RECT, "HeroPortraitBackdrop", 0.8)


func _place_hero_neutral_covers(parent: Control) -> void:
	# Shield-shaped black enamel inlays that sit inside the copper shield frames (instead of round holes).
	for cover_def: Array in [[HERO_NEUTRAL_COVER_LEFT_RECT, "HeroNeutralCoverLeft"], [HERO_NEUTRAL_COVER_RIGHT_RECT, "HeroNeutralCoverRight"]]:
		var cover := _place_rounded_black_backdrop(parent, cover_def[0], cover_def[1])
		var shield := cover.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		shield.corner_radius_top_left = 7
		shield.corner_radius_top_right = 7
		shield.corner_radius_bottom_left = 22
		shield.corner_radius_bottom_right = 22
		shield.border_color = Color("#8A5530")
		shield.set_border_width_all(2)
		cover.add_theme_stylebox_override("panel", shield)


func _place_rounded_black_backdrop(parent: Control, rect: Rect2, node_name: String, opacity := 1.0) -> Panel:
	var backdrop := Panel.new()
	backdrop.name = node_name
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var circular_backdrop := StyleBoxFlat.new()
	circular_backdrop.bg_color = Color(Color.BLACK, opacity)
	var radius := roundi(minf(rect.size.x, rect.size.y) * 0.5)
	circular_backdrop.corner_radius_top_left = radius
	circular_backdrop.corner_radius_top_right = radius
	circular_backdrop.corner_radius_bottom_left = radius
	circular_backdrop.corner_radius_bottom_right = radius
	backdrop.add_theme_stylebox_override("panel", circular_backdrop)
	_place_on(parent, backdrop, rect)
	return backdrop


func _place_portrait_backdrop(parent: Control, rect: Rect2, node_name: String) -> ColorRect:
	var backdrop := ColorRect.new()
	backdrop.name = node_name
	backdrop.color = Color.BLACK
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_on(parent, backdrop, rect)
	return backdrop


func _render_opponent_hand() -> void:
	if enemy_hand.is_empty():
		return
	var hand_rect := _target_battle_zone(&"opponent_hand")
	var hand_display := Control.new()
	hand_display.name = "OpponentHandDisplay"
	hand_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_display.z_index = 5
	hand_display.set_meta("hand_count", enemy_hand.size())
	hand_display.set_meta("concealed", true)
	_place(hand_display, hand_rect)
	var visible_cards := mini(enemy_hand.size(), MAX_HAND)
	var card_width := OPPONENT_HAND_CARD_SIZE.x
	var card_height := OPPONENT_HAND_CARD_SIZE.y
	var overlap := 24.0
	var total_width := card_width + maxf(0.0, visible_cards - 1) * overlap if visible_cards > 0 else 0.0
	var start_x := (hand_rect.size.x - total_width) * 0.5
	for index in range(visible_cards):
		var normalized := 0.0 if visible_cards <= 1 else (float(index) / float(visible_cards - 1)) * 2.0 - 1.0
		var card_back := _texture(DB.art("juice_card_back"), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		card_back.name = "ConcealedCardBack%d" % index
		card_back.set_meta("concealed", true)
		card_back.rotation = normalized * 0.12
		card_back.pivot_offset = Vector2(card_width * 0.5, card_height)
		card_back.z_index = index
		var card_y := -card_height * 0.5 - absf(normalized) * OPPONENT_HAND_ARC_RISE
		_place_on(hand_display, card_back, Rect2(start_x + index * overlap, card_y, card_width, card_height))
	_place_on(hand_display, _label(str(enemy_hand.size()), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER), Rect2(hand_rect.size.x * 0.5 - 18, hand_rect.size.y - 18, 36, 16))


func _make_button_chromeless(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())


func _noop() -> void:
	pass


func _render_resource_pips(start: Vector2, value: int, maximum: int, color: Color, diameter := 12.0) -> void:
	_render_resource_pips_on(screen_layer, start, value, maximum, color, diameter)


func _render_resource_pips_on(parent: Control, start: Vector2, value: int, maximum: int, color: Color, diameter := 12.0) -> void:
	for index in range(maximum):
		var pip := Panel.new()
		pip.name = "ResourcePip%d" % index
		var lit := index < value
		pip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place_on(parent, pip, Rect2(start + Vector2(index * (diameter + 4.0), 0), Vector2(diameter, diameter)))
		var gem := TAVERN.Gem.new()
		gem.color = color
		gem.lit = lit
		gem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pip.add_child(gem)


func _banner_mana_context() -> Dictionary:
	if banner_text == t("battle.your_turn_mana", {"mana": player_mana}):
		return {"value": str(player_mana)}
	if banner_text == t("battle.not_enough_mana"):
		return {"value": ""}
	var power_cost := _tweak_int(&"player.hero_power_cost", 2)
	if banner_text == t("battle.hero_power_requires_mana", {"cost": power_cost}):
		return {"value": str(power_cost)}
	return {}


func _render_board_row(board: Array[Dictionary], friendly: bool) -> void:
	var slot_count := maxi(_tweak_int(&"gameplay.max_board_slots", MAX_BOARD), board.size())
	var slot_rects := _board_slot_rects(friendly, slot_count)
	for slot in range(slot_count):
		if slot < board.size():
			var unit: Dictionary = board[slot]
			var legal_target: bool = _is_legal_unit_target(slot, friendly)
			var selected: bool = friendly and pending_action.get("kind") == "attack" and pending_action.get("board_index") == slot
			var accent: Color = TEAL if friendly else CRIMSON
			if legal_target:
				var prediction := _prediction_kind(unit, friendly)
				accent = TEAL if prediction == "precise" else CRIMSON if prediction == "overkill" else EMBER
			if selected:
				accent = Color.WHITE
			var target_rect: Rect2 = slot_rects[slot]
			var button: Button = _unit_button(unit, friendly, slot, accent, target_rect.size.x)
			_place(button, target_rect)
			var uid := int(unit.get("uid", -1))
			if uid >= 0:
				unit_nodes_by_uid[uid] = button
				visual_unit_rects[uid] = target_rect
				_animate_reflow(button, prior_unit_rects.get(uid, Rect2()), target_rect, _target_battle_zone(&"opponent_station" if not friendly else "player_station").get_center())


func _board_slot_rects(friendly: bool, slot_count: int) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var row_rect := _target_battle_zone(&"player_row" if friendly else "opponent_row")
	var count := maxi(1, slot_count)
	var diameter := minf(132.0, minf(row_rect.size.y, (row_rect.size.x - maxf(0.0, count - 1.0) * 8.0) / count))
	var gap := 0.0 if count <= 1 else minf(18.0, (row_rect.size.x - count * diameter) / maxf(1.0, count - 1.0))
	var total_width := count * diameter + maxf(0.0, count - 1.0) * gap
	var start_x := row_rect.position.x + (row_rect.size.x - total_width) * 0.5
	var y := row_rect.position.y + (row_rect.size.y - diameter) * 0.5
	for slot in range(count):
		result.append(Rect2(start_x + slot * (diameter + gap), y, diameter, diameter))
	return result


func _unit_button(unit: Dictionary, friendly: bool, index: int, accent: Color, token_size: float) -> Button:
	var callback: Callable = func():
		if friendly:
			_on_player_unit_pressed(index)
		else:
			_on_enemy_unit_pressed(index)
	var button: Button = _button("", callback, accent)
	_make_button_chromeless(button)
	button.clip_contents = false
	button.set_meta("juice_kind", "unit")
	button.set_meta("card_id", String(unit.id))
	button.set_meta("plate_token", true)
	button.set_meta("unit_uid", int(unit.get("uid", -1)))
	button.set_meta("friendly", friendly)
	button.set_meta("legal_target", _is_legal_unit_target(index, friendly))
	button.set_meta("unit_ready", bool(unit.get("ready", false)))
	var scale_factor := token_size / 132.0
	var frame := _texture(DB.art("hud_unit_plate_frame"), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	frame.position = Vector2.ZERO
	frame.size = Vector2.ONE * token_size
	frame.modulate = accent.lightened(0.18) if button.get_meta("legal_target", false) else Color.WHITE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(frame)
	var unit_backdrop_rect := Rect2(UNIT_PORTRAIT_BACKDROP_RECT.position * scale_factor, UNIT_PORTRAIT_BACKDROP_RECT.size * scale_factor)
	_place_rounded_black_backdrop(button, unit_backdrop_rect, "UnitPortraitBackdrop", 0.8)
	var art := _texture(DB.art(unit.art), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	art.name = "UnitPortrait"
	art.position = Vector2(27, 19) * scale_factor
	art.size = Vector2(78, 70) * scale_factor
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(art)
	frame.move_to_front()
	var name_rect := Rect2(UNIT_NAME_RECT.position * scale_factor, UNIT_NAME_RECT.size * scale_factor)
	var name_plate := _hud_readability_plate_on(button, name_rect, accent, "UnitNamePlate", maxi(6, roundi(8 * scale_factor)))
	_set_font(_place_hud_label_on(name_plate, t(unit.name_key), maxi(10, roundi(12 * scale_factor)), 8, CREAM, Rect2(Vector2(4, 1) * scale_factor, Vector2(92, 23) * scale_factor), "UnitNameLabel", HORIZONTAL_ALIGNMENT_CENTER, 2), L10N.NAME_FONT_RESOURCE)
	var state := t("battle.ready" if unit.ready else "battle.sleep")
	if unit.get("guard", false):
		state = t("battle.state_guard", {"state": state})
	var predicted_damage := _predicted_damage_to_unit(unit, friendly)
	if _tweak_bool(&"ui.show_damage_predictions", true) and button.get_meta("legal_target", false) and predicted_damage > 0:
		var prediction := _prediction_kind(unit, friendly)
		if prediction == "precise":
			state = t("battle.exact_cut")
		elif prediction == "overkill":
			state = t("battle.overkill")
		else:
			state = t("battle.damage_prediction", {"damage": predicted_damage, "remaining": maxi(0, int(unit.health) - predicted_damage)})
	_hud_readability_plate_on(button, Rect2(Vector2(37, 2) * scale_factor, Vector2(58, 31) * scale_factor), accent, "UnitStatePlate", maxi(5, roundi(7 * scale_factor)))
	_set_font(_place_hud_label_on(button, state, maxi(8, roundi(9 * scale_factor)), 8, accent.lightened(0.18), Rect2(Vector2(41, 3) * scale_factor, Vector2(50, 24) * scale_factor), "UnitStateLabel", HORIZONTAL_ALIGNMENT_CENTER, 1), L10N.BUTTON_FONT_RESOURCE)
	var stat_icon_size := Vector2.ONE * UNIT_STAT_ICON_SIZE * scale_factor
	var stat_label_size := UNIT_STAT_LABEL_SIZE * scale_factor
	var sword_icon := _texture(DB.art("icon_sword"))
	sword_icon.name = "UnitAttackIcon"
	sword_icon.position = UNIT_ATTACK_SLOT_CENTER * scale_factor - stat_icon_size * 0.5
	sword_icon.size = stat_icon_size
	sword_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(sword_icon)
	var attack_label := _place_hud_label_on(button, str(unit.attack), maxi(16, roundi(20 * scale_factor)), maxi(11, roundi(13 * scale_factor)), CREAM, Rect2(UNIT_ATTACK_SLOT_CENTER * scale_factor - stat_label_size * 0.5, stat_label_size), "UnitAttackLabel", HORIZONTAL_ALIGNMENT_CENTER, 2)
	_set_font(attack_label, L10N.NUMBER_FONT_RESOURCE)
	_embolden_hud_label(attack_label, 0.25)
	var shield_icon := _texture(DB.art("icon_shield"))
	shield_icon.name = "UnitHealthIcon"
	shield_icon.position = UNIT_HEALTH_SLOT_CENTER * scale_factor - stat_icon_size * 0.5
	shield_icon.size = stat_icon_size
	shield_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(shield_icon)
	var health_color := TEAL if friendly else MINION_HEALTH_RED
	var health_label := _place_hud_label_on(button, str(unit.health), maxi(16, roundi(20 * scale_factor)), maxi(11, roundi(13 * scale_factor)), health_color, Rect2(UNIT_HEALTH_SLOT_CENTER * scale_factor - stat_label_size * 0.5, stat_label_size), "UnitHealthLabel", HORIZONTAL_ALIGNMENT_CENTER, 2)
	_set_font(health_label, L10N.NUMBER_FONT_RESOURCE)
	_embolden_hud_label(health_label, 0.25)
	_add_unit_state_badges(button, unit, accent, scale_factor)
	if not bool(unit.get("ready", false)):
		var sleep_particles := SLEEP_PARTICLE_EMITTER.new()
		sleep_particles.configure(motion_mode == JUICE_PROFILES.MOTION_FULL)
		button.add_child(sleep_particles)
	return button


func _add_unit_state_badges(button: Button, unit: Dictionary, accent: Color, scale_factor := 1.0) -> void:
	var x := 112.0 * scale_factor
	if bool(unit.get("guard", false)):
		var guard := Polygon2D.new()
		guard.polygon = PackedVector2Array([Vector2(0, -8), Vector2(8, 5), Vector2(0, 10), Vector2(-8, 5)])
		guard.color = COPPER
		guard.scale = Vector2.ONE * scale_factor
		guard.position = Vector2(x, 18 * scale_factor)
		button.add_child(guard)
		x -= 21.0 * scale_factor
	var readiness := Polygon2D.new()
	readiness.polygon = PackedVector2Array([
		Vector2(0, -7), Vector2(6, -3), Vector2(7, 4), Vector2(0, 8), Vector2(-7, 4), Vector2(-6, -3)
	])
	readiness.color = TEAL if bool(unit.get("ready", false)) else Color("#776B6270")
	readiness.scale = Vector2.ONE * scale_factor
	readiness.position = Vector2(x, 18 * scale_factor)
	button.add_child(readiness)
	if int(unit.get("attack", 0)) > int(DB.card(String(unit.get("id", ""))).get("attack", int(unit.get("attack", 0)))):
		var buff := Polygon2D.new()
		buff.polygon = PackedVector2Array([Vector2(0, -7), Vector2(7, 7), Vector2(-7, 7)])
		buff.color = EMBER
		buff.scale = Vector2.ONE * scale_factor
		buff.position = Vector2(16, 18) * scale_factor
		button.add_child(buff)


func _is_legal_unit_target(index: int, friendly: bool) -> bool:
	if pending_action.get("kind") == "spell":
		return friendly == (pending_action.get("effect") == "target_friend_buff")
	if pending_action.get("kind") == "attack" and not friendly:
		var guard_index := _first_guard_index(enemy_board)
		return guard_index < 0 or guard_index == index
	return false


func _predicted_damage_to_unit(unit: Dictionary, friendly: bool) -> int:
	if friendly:
		return 0
	if pending_action.get("kind") == "spell" and pending_action.get("effect") == "target_enemy_damage":
		var hand_index := _pending_spell_hand_index()
		if hand_index >= 0 and hand_index < player_hand.size():
			return _player_damage_amount(int(DB.card(player_hand[hand_index].id).get("value", 0)))
	if pending_action.get("kind") == "attack":
		var board_index := int(pending_action.get("board_index", -1))
		if board_index >= 0 and board_index < player_board.size():
			return _player_damage_amount(int(player_board[board_index].attack))
	return 0


func _prediction_kind(unit: Dictionary, friendly: bool) -> String:
	var damage := _predicted_damage_to_unit(unit, friendly)
	var ingredient := String(unit.get("ingredient", ""))
	if damage <= 0 or ingredient.is_empty():
		return "damage"
	if damage >= int(unit.health) and damage <= int(unit.health) + _tweak_int(&"gameplay.precise_cut_tolerance", 0):
		return "precise"
	if damage > int(unit.health):
		return "overkill"
	return "damage"


func _render_hand() -> void:
	var hand_rects := _hand_layout_rects(player_hand.size())
	var tutorial_stabilizes_hand := String(_tutorial_current_step().get("id", "")) == "play_precise_chop"
	for index in range(player_hand.size()):
		var runtime_card := player_hand[index]
		var target_rect: Rect2 = hand_rects[index]
		var card_width := target_rect.size.x
		var card_height := target_rect.size.y
		var card_button := _card_button(runtime_card, index, card_width, card_height, not _has_pending_spell())
		var normalized := 0.0 if player_hand.size() <= 1 else (float(index) / float(player_hand.size() - 1)) * 2.0 - 1.0
		var rest_rotation := normalized * (0.075 if player_hand.size() <= 7 else 0.045) if motion_mode == JUICE_PROFILES.MOTION_FULL else 0.0
		_place(card_button, target_rect)
		card_button.z_index = index
		card_button.rotation = rest_rotation
		card_button.set_meta("juice_rest_rotation", rest_rotation)
		var uid := int(runtime_card.uid)
		card_nodes_by_uid[uid] = card_button
		visual_hand_positions[uid] = target_rect
		# Overlapped cards keep their name inside the strip that stays visible beside the next card.
		var visible_width := card_width
		if index + 1 < player_hand.size():
			var next_gap: float = (hand_rects[index + 1] as Rect2).position.x - target_rect.position.x
			if next_gap > 0.0 and next_gap < card_width:
				visible_width = next_gap
		card_button.set_meta("visible_strip", visible_width)
		_apply_card_name_layout(card_button, true)
		if pending_draw_reveals.has(uid):
			_add_draw_card_cover(card_button, card_width, 164.0)
			card_button.visible = false
			card_button.disabled = true
		elif not tutorial_stabilizes_hand:
			_animate_reflow(card_button, prior_hand_positions.get(uid, Rect2()), target_rect, _target_battle_zone(&"player_deck").get_center())


func _hand_layout_rects(card_count: int) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if card_count <= 0:
		return result
	var hand_rect := _target_battle_zone(&"player_hand")
	var station_rect := _target_battle_zone(&"player_station")
	var power_rect := _target_battle_zone(&"hero_power")
	var card_width := 126.0 if card_count <= 5 else 114.0 if card_count <= 7 else 100.0
	var card_height := 164.0
	var left_area := Rect2(hand_rect.position.x, hand_rect.position.y, station_rect.position.x - hand_rect.position.x - 12.0, hand_rect.size.y)
	var right_start := power_rect.end.x + 12.0
	var right_area := Rect2(right_start, hand_rect.position.y, hand_rect.end.x - right_start, hand_rect.size.y)
	# Split the fan between the two wings so the narrowest exposed strip (where names live) is widest.
	var right_count := mini(3, floori(float(card_count) * 0.5))
	var best_strip := -1.0
	for candidate in range(0, mini(3, card_count - 1) + 1):
		var candidate_left := card_count - candidate
		var narrowest := minf(_hand_strip_width(left_area.size.x, candidate_left, card_width), _hand_strip_width(right_area.size.x, candidate, card_width))
		if narrowest > best_strip + 0.5:
			best_strip = narrowest
			right_count = candidate
	var left_count := card_count - right_count
	for index in range(card_count):
		var in_left := index < left_count
		var side_index := index if in_left else index - left_count
		var side_count := left_count if in_left else right_count
		var area := left_area if in_left else right_area
		var card_x := _packed_card_x(area, side_index, side_count, card_width)
		var normalized := 0.0 if side_count <= 1 else (float(side_index) / float(side_count - 1)) * 2.0 - 1.0
		var arc_drop := absf(normalized) * (7.0 if card_count <= 7 else 4.0)
		var card_y := minf(hand_rect.position.y, 720.0 - card_height - 22.0) + arc_drop
		result.append(Rect2(card_x, card_y, card_width, card_height))
	return result


func _hand_strip_width(area_width: float, count: int, card_width: float) -> float:
	if count <= 1:
		return card_width if count == 1 else INF
	return minf(card_width + 6.0, maxf(1.0, (area_width - card_width) / float(count - 1)))


func _packed_card_x(area: Rect2, index: int, count: int, card_width: float) -> float:
	if count <= 0:
		return area.get_center().x - card_width * 0.5
	var step := minf(card_width + 6.0, maxf(1.0, (area.size.x - card_width) / maxf(1.0, count - 1.0)))
	var total_width := card_width + maxf(0.0, count - 1.0) * step
	return area.position.x + (area.size.x - total_width) * 0.5 + index * step


func _render_player_deck() -> void:
	var deck_rect := _target_battle_zone(&"player_deck")
	var display := Control.new()
	display.name = "PlayerDeckDisplay"
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.set_meta("deck_count", player_deck.size())
	var card_rect := Rect2(deck_rect.position + DECK_CARD_OVERSCAN_RECT.position, DECK_CARD_OVERSCAN_RECT.size)
	display.set_meta("deck_stack_rect", card_rect)
	_place(display, Rect2(0, 0, 1280, 720))
	_heading(display, t("battle.your_deck"), 12, CREAM, Rect2(deck_rect.position + Vector2(0, -22), Vector2(deck_rect.size.x, 20)), HORIZONTAL_ALIGNMENT_CENTER)
	if player_deck.is_empty():
		var empty_label := _label(t("battle.empty_deck"), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		empty_label.name = "EmptyDeckSlot"
		_place_on(display, empty_label, Rect2(deck_rect.position + DECK_CRADLE_APERTURE_RECT.position, DECK_CRADLE_APERTURE_RECT.size))
	else:
		var visible_layers := mini(4, player_deck.size())
		for layer in range(visible_layers - 1, 0, -1):
			var card_back := _texture(DB.art("juice_card_back"), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
			card_back.name = "DeckCardBack%d" % layer
			card_back.modulate = Color(0.78, 0.72, 0.72, 1.0) if layer > 0 else Color.WHITE
			var layer_rect := Rect2(card_rect.position + PLAYER_DECK_LAYER_OFFSET * layer, card_rect.size)
			_place_on(display, card_back, layer_rect)
	var cradle := _texture(DB.art("hud_deck_cradle"))
	cradle.name = "PlayerDeckCradle"
	_place_on(display, cradle, deck_rect)
	if not player_deck.is_empty():
		_place_deck_face_cover(display, deck_rect.position, "Deck")

	var count_badge := Panel.new()
	count_badge.name = "DeckCountBadge"
	count_badge.add_theme_stylebox_override("panel", _style(Color("#F2100A18"), TEAL if not player_deck.is_empty() else MUTED, 2, 18))
	var count_rect := Rect2(deck_rect.position + Vector2(48, 116), Vector2(34, 26))
	_place_on(display, count_badge, count_rect)
	_place_on(display, _display_label(str(player_deck.size()), L10N.NUMBER_FONT_RESOURCE, 18, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 2), count_rect)


func _add_draw_card_cover(card_button: Button, width: float, height: float) -> void:
	var cover := Control.new()
	cover.name = "DrawCardBack"
	cover.z_index = 30
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.position = Vector2.ZERO
	cover.size = Vector2(width, height)
	card_button.add_child(cover)
	var back_art := _texture(DB.art("juice_card_back"), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	back_art.position = Vector2.ZERO
	back_art.size = Vector2(width, height)
	cover.add_child(back_art)


func _animate_draw_to_hand(uid: int) -> void:
	if not pending_draw_reveals.has(uid):
		await _juice_wait(0.04)
		return
	var target_screen_rect: Rect2 = visual_hand_positions.get(uid, Rect2())
	var target_rect := _rect_between_canvas_items(screen_layer, juice, target_screen_rect)
	var hand_card: Button = card_nodes_by_uid.get(uid)
	if target_rect.size == Vector2.ZERO or hand_card == null or not is_instance_valid(hand_card):
		pending_draw_reveals.erase(uid)
		if pending_draw_reveals.is_empty() and screen_name == "battle":
			_render_battle()
		return

	var draw_visual := Control.new()
	draw_visual.name = "DrawnCardReveal"
	draw_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_visual.z_index = 120
	draw_visual.size = target_rect.size
	draw_visual.pivot_offset = target_rect.size * 0.5
	juice.add_child(draw_visual)

	var face_visual := hand_card.duplicate() as Button
	face_visual.name = "DrawCardFace"
	face_visual.position = Vector2.ZERO
	face_visual.size = target_rect.size
	face_visual.pivot_offset = target_rect.size * 0.5
	face_visual.rotation = 0.0
	face_visual.scale = Vector2.ONE
	face_visual.visible = false
	face_visual.disabled = false
	face_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inherited_cover := face_visual.get_node_or_null("DrawCardBack")
	if inherited_cover != null:
		face_visual.remove_child(inherited_cover)
		inherited_cover.free()
	draw_visual.add_child(face_visual)

	var card_back := _texture(DB.art("juice_card_back"), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	card_back.name = "DrawCardBack"
	card_back.position = Vector2.ZERO
	card_back.size = target_rect.size
	draw_visual.add_child(card_back)

	var target_rotation := float(hand_card.get_meta("juice_rest_rotation", 0.0))
	var deck_rect := _target_battle_zone(&"player_deck")
	var deck_rect_in_juice := _rect_between_canvas_items(screen_layer, juice, deck_rect)
	draw_visual.position = deck_rect_in_juice.get_center() - target_rect.size * 0.5
	draw_visual.scale = Vector2(
		deck_rect_in_juice.size.x / target_rect.size.x,
		deck_rect_in_juice.size.y / target_rect.size.y
	)
	draw_visual.rotation = -0.045 if motion_mode == JUICE_PROFILES.MOTION_FULL else 0.0
	var duration_scale := JUICE_PROFILES.duration_scale(motion_mode, animation_speed) * juice_repeat_speed

	if motion_mode != JUICE_PROFILES.MOTION_MINIMAL:
		var flight := draw_visual.create_tween().set_parallel(true)
		flight.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		flight.tween_property(draw_visual, "position", target_rect.position, DRAW_FLIGHT_SECONDS * duration_scale)
		flight.tween_property(draw_visual, "scale", Vector2.ONE, DRAW_FLIGHT_SECONDS * duration_scale)
		flight.tween_property(draw_visual, "rotation", target_rotation, DRAW_FLIGHT_SECONDS * duration_scale)
		await flight.finished
		if not is_instance_valid(draw_visual):
			pending_draw_reveals.erase(uid)
			return
	else:
		draw_visual.position = target_rect.position
		draw_visual.scale = Vector2.ONE
		draw_visual.rotation = target_rotation

	var flip_out := draw_visual.create_tween()
	flip_out.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flip_out.tween_property(draw_visual, "scale", Vector2(0.0, 1.0), DRAW_FLIP_SECONDS * duration_scale)
	await flip_out.finished
	if not is_instance_valid(draw_visual):
		pending_draw_reveals.erase(uid)
		return
	card_back.visible = false
	face_visual.visible = true
	var flip_in := draw_visual.create_tween()
	flip_in.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flip_in.tween_property(draw_visual, "scale", Vector2.ONE, DRAW_FLIP_SECONDS * duration_scale)
	await flip_in.finished
	if is_instance_valid(draw_visual):
		juice.contact_ring(target_rect.get_center(), TEAL, 34.0)
		draw_visual.queue_free()

	pending_draw_reveals.erase(uid)
	if pending_draw_reveals.is_empty() and screen_name == "battle":
		_render_battle()


func _card_button(runtime_card: Dictionary, index: int, width: float, height: float, interactive: bool, inspection_only := false) -> Button:
	var definition: Dictionary = DB.card(runtime_card.id)
	var affordable: bool = definition.cost <= player_mana and not inspection_only
	var playable := affordable
	if not inspection_only and definition.type == "unit" and player_board.size() >= _tweak_int(&"gameplay.max_board_slots", MAX_BOARD):
		playable = false
	var accent: Color = _rarity_color(definition.get("rarity", "common"))
	var uid := int(runtime_card.uid)
	var callback: Callable
	if inspection_only:
		var inspection_card_id := String(runtime_card.id)
		var inspection_servings := int(runtime_card.get("servings", 0))
		callback = func(): _show_card_preview(inspection_card_id, inspection_servings)
	else:
		callback = func(card_uid := uid): _on_hand_card_uid_pressed(card_uid)
	var button: Button = _button("", callback, accent, not interactive)
	if not inspection_only:
		button.add_theme_stylebox_override("normal", _style(HAND_CARD_BG, accent, 2, 10))
		button.add_theme_stylebox_override("hover", _style(HAND_CARD_BG, EMBER, 3, 10))
		button.add_theme_stylebox_override("pressed", _style(HAND_CARD_BG, TEAL, 3, 10))
		button.add_theme_stylebox_override("hover_pressed", _style(HAND_CARD_BG, TEAL, 3, 10))
		button.add_theme_stylebox_override("disabled", _style(HAND_CARD_BG, Color("#665A4C"), 1, 10))
		button.add_theme_stylebox_override("focus", _golden_focus_style(10, HAND_CARD_BG.a))
	if affordable:
		button.add_theme_stylebox_override("normal", _affordable_card_frame_style(2, 8))
		button.add_theme_stylebox_override("hover", _affordable_card_frame_style(3, 11))
		button.add_theme_stylebox_override("pressed", _affordable_card_frame_style(3, 7))
		button.add_theme_stylebox_override("hover_pressed", _affordable_card_frame_style(3, 9))
		button.add_theme_stylebox_override("focus", _golden_focus_style(10, HAND_CARD_BG.a))
	button.set_meta("juice_kind", "card")
	button.set_meta("card_id", String(runtime_card.id))
	if not inspection_only:
		button.set_meta("card_uid", uid)
	button.set_meta("servings", int(runtime_card.get("servings", 0)))
	button.set_meta("playable", playable)
	button.set_meta("inspection_only", inspection_only)
	if not inspection_only:
		button.gui_input.connect(func(event: InputEvent):
			_on_card_gui_input(event, uid, button)
			_on_card_pointer_motion(event, button)
		)
	var trim := TAVERN.CardTrim.new()
	trim.accent = accent
	trim.rarity = String(definition.get("rarity", "common"))
	trim.art_rect = Rect2(17, 7, width - 34, height * 0.49)
	trim.name_rect = Rect2(4, height * 0.49, width - 8, 25)
	trim.position = Vector2.ZERO
	trim.size = Vector2(width, height)
	button.add_child(trim)
	var art := _texture(DB.art(definition.art))
	art.position = Vector2(17, 7)
	art.size = Vector2(width - 34, height * 0.49)
	button.add_child(art)
	var cost := _mana_cost_badge(int(definition.cost), Vector2(42, 46), 22, affordable)
	cost.position = Vector2(1, 0)
	button.add_child(cost)
	var name_font_size := 11 if String(definition.get("rarity", "")) == "legendary" else 13
	var name_label := _display_label(t(definition.name_key), L10N.NAME_FONT_RESOURCE, name_font_size, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 2)
	name_label.name = "CardName"
	name_label.position = Vector2(4, height * 0.49)
	name_label.size = Vector2(width - 8, 25)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(name_label)
	_fit_label_width(name_label, width, 9)
	name_label.set_meta("full_font_size", name_label.get_theme_font_size("font_size"))
	name_label.set_meta("preferred_font_size", name_font_size)
	var rules := _card_description_label(t(definition.text_key), 10)
	rules.position = Vector2(7, height * 0.49 + 26)
	rules.size = Vector2(width - 14, 45)
	rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(rules)
	if definition.type == "unit":
		var stats := _card_stats_footer(int(definition.attack), int(definition.health), accent, 16.0, 10)
		stats.position = Vector2(5, height - 22)
		stats.size = Vector2(width - 10, 18)
		button.add_child(stats)
	else:
		var footer_text := t("card.servings", {"count": int(runtime_card.servings)}) if definition.type == "dish" else t("card.type.%s" % String(definition.type))
		var footer := _label(footer_text, 10, accent, HORIZONTAL_ALIGNMENT_CENTER)
		footer.add_theme_font_override("font", L10N.BUTTON_FONT_RESOURCE)
		footer.position = Vector2(5, height - 22)
		footer.size = Vector2(width - 10, 18)
		footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(footer)
	if definition.type == "dish":
		for serving_index in range(int(runtime_card.get("servings", 0))):
			var pip := Panel.new()
			pip.add_theme_stylebox_override("panel", _style(Color("#DDF3A33C"), CREAM, 1, 7))
			pip.position = Vector2(width - 18 - serving_index * 15, height - 18)
			pip.size = Vector2(11, 11)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(pip)
	return button


## Lay the card name out for the whole face (hovered/unobstructed) or for the visible strip of an
## overlapped hand card: up to two centred lines, shrunk only as far as needed to keep words whole.
func _apply_card_name_layout(card: Control, use_strip: bool) -> void:
	var label := card.get_node_or_null("CardName") as Label
	if label == null:
		return
	var width := card.size.x
	var height := card.size.y
	var strip := float(card.get_meta("visible_strip", width))
	if not use_strip or strip >= width - 6.0:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.max_lines_visible = -1
		label.add_theme_font_size_override("font_size", int(label.get_meta("full_font_size", label.get_theme_font_size("font_size"))))
		label.remove_theme_constant_override("line_spacing")
		label.update_minimum_size()
		label.position = Vector2(4, height * 0.49)
		label.size = Vector2(width - 8, 25)
		return
	var font := label.get_theme_font("font")
	var box := Vector2(strip - 10.0, 31.0)
	var font_size := int(label.get_meta("preferred_font_size", 13))
	var words := label.text.split(" ", false)
	while font_size > 8:
		var fits := true
		for word in words:
			if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > box.x:
				fits = false
				break
		if fits:
			var block := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, box.x, font_size)
			fits = block.y <= font.get_height(font_size) * 2.0 + 1.0
		if fits:
			break
		font_size -= 1
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("line_spacing", -3)
	label.update_minimum_size()
	label.position = Vector2(5, height * 0.49 - 4.0)
	label.size = box


func _on_card_pointer_motion(event: InputEvent, control: Control) -> void:
	if not (event is InputEventMouseMotion) or drag_active or motion_mode != JUICE_PROFILES.MOTION_FULL:
		return
	if not control.get_meta("juice_hovered", false):
		return
	var local_ratio := clampf(event.position.x / maxf(1.0, control.size.x), 0.0, 1.0) * 2.0 - 1.0
	var rest_rotation := float(control.get_meta("juice_rest_rotation", 0.0))
	control.rotation = rest_rotation + local_ratio * 0.035


func _spread_hand_neighbors(uid: int, entered: bool) -> void:
	var hovered_index := _find_hand_index_by_uid(uid)
	if hovered_index < 0:
		return
	for index in range(player_hand.size()):
		if index == hovered_index:
			continue
		var other_uid := int(player_hand[index].uid)
		var node: Control = card_nodes_by_uid.get(other_uid)
		if node == null or not is_instance_valid(node):
			continue
		var rest_rect: Rect2 = visual_hand_positions.get(other_uid, Rect2(node.position, node.size))
		var separation := 9.0 if entered else 0.0
		var direction := -1.0 if index < hovered_index else 1.0
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "position:x", rest_rect.position.x + direction * separation, 0.12)


func _render_battle_controls() -> void:
	var power_cost := _tweak_int(&"player.hero_power_cost", 2)
	var power_armor := maxi(0, roundi(_tweak_int(&"player.hero_power_armor", 2) * _tweak_float(&"player.armor_gain_multiplier", 1.0)))
	_render_player_mana_pool()
	var hero_power_rect := _target_battle_zone(&"hero_power")
	var hero_power_button := _hero_power_button(power_cost, power_armor, hero_power_used or player_mana < power_cost or not _can_take_player_action() or _has_pending_spell(), hero_power_rect.size.x)
	hero_power_button.clip_text = true
	_place(hero_power_button, hero_power_rect)
	hero_power_button.z_index = 13
	var end_turn_button := _button(t("battle.end_turn"), end_player_turn, EMBER, not _can_take_player_action())
	_make_button_chromeless(end_turn_button)
	end_turn_button.clip_text = true
	end_turn_button.add_theme_font_size_override("font_size", 1)
	end_turn_button.add_theme_color_override("font_color", Color.TRANSPARENT)
	_place(end_turn_button, _target_battle_zone(&"turn_control"))
	end_turn_button.name = "EndTurnButton"
	var turn_frame := _texture(DB.art("hud_end_turn_frame"), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	turn_frame.name = "EndTurnFrame"
	turn_frame.modulate = Color.WHITE if not end_turn_button.disabled else Color(0.48, 0.44, 0.42, 0.82)
	_place_on(end_turn_button, turn_frame, Rect2(Vector2.ZERO, end_turn_button.size))
	var turn_color := GOLD if not end_turn_button.disabled and not _has_remaining_player_action() else CREAM if not end_turn_button.disabled else MUTED
	_set_font(_place_hud_label_on(end_turn_button, t("battle.end_turn"), 15, 10, turn_color, Rect2(19, 34, end_turn_button.size.x - 38, 30), "EndTurnVisibleLabel", HORIZONTAL_ALIGNMENT_CENTER, 2), L10N.HEADING_FONT_RESOURCE)
	end_turn_button.set_meta("end_turn_recommended", not end_turn_button.disabled and not _has_remaining_player_action())
	var recommend_end_turn := not end_turn_button.disabled and not _has_remaining_player_action()
	if recommend_end_turn:
		_apply_end_turn_glow(end_turn_button)

	var pantry_rect := _target_battle_zone(&"pantry")
	var pantry_panel := Control.new()
	pantry_panel.name = "BattlePantryPanel"
	pantry_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(pantry_panel, pantry_rect)
	_place_on(pantry_panel, _texture(DB.art("hud_pantry_tray_frame")), Rect2(Vector2.ZERO, pantry_rect.size))
	_set_font(_place_hud_label_on(pantry_panel, t("kitchen.pantry"), 13, 10, CREAM, Rect2(24, 23, pantry_rect.size.x - 48, 22), "PantryTitle", HORIZONTAL_ALIGNMENT_CENTER, 2), L10N.HEADING_FONT_RESOURCE)
	pantry_ingredient_anchors.clear()
	var battle_ingredients := ["fungus", "herb", "meat", "ember"]
	for ingredient_index in range(battle_ingredients.size()):
		var ingredient_id: String = battle_ingredients[ingredient_index]
		var well_center := Vector2(41.0 + ingredient_index * 37.0, 77.0)
		var ingredient_icon := _texture(DB.art("ingredient_" + ingredient_id))
		ingredient_icon.name = "PantryIngredient_%s" % ingredient_id
		ingredient_icon.set_meta("ingredient", ingredient_id)
		var ingredient_icon_extent := PANTRY_EMBER_ICON_SIZE if ingredient_id == "ember" else PANTRY_INGREDIENT_ICON_SIZE
		var ingredient_icon_size := Vector2.ONE * ingredient_icon_extent
		var ingredient_icon_offset := PANTRY_EMBER_ICON_OFFSET if ingredient_id == "ember" else Vector2.ZERO
		_place_on(pantry_panel, ingredient_icon, Rect2(well_center - ingredient_icon_size * 0.5 + ingredient_icon_offset, ingredient_icon_size))
		_set_font(_place_hud_label_on(pantry_panel, str(int(pantry[ingredient_id])), 12, 8, CREAM, Rect2(well_center + Vector2(6, 7), Vector2(23, 18)), "PantryIngredientCount_%s" % ingredient_id, HORIZONTAL_ALIGNMENT_CENTER, 1), L10N.NUMBER_FONT_RESOURCE)
		pantry_ingredient_anchors[ingredient_id] = pantry_rect.position + well_center
	_place_hud_label_on(pantry_panel, t("battle.deck_discard", {"deck": player_deck.size(), "discard": player_discard.size()}), 9, 8, TEAL, Rect2(20, 113, pantry_rect.size.x - 40, 18), "PantryDeckDiscardLabel", HORIZONTAL_ALIGNMENT_CENTER, 1)
	pantry_anchor = pantry_rect.position + Vector2(96, 77)

	var history_rect := _target_battle_zone(&"history_rail")
	var history_button := _button("%s  ·  %d" % [t("history.heading"), history_events.size()], _open_service_history, COPPER)
	history_button.name = "ServiceHistoryButton"
	history_button.tooltip_text = t("history.open_tooltip")
	_make_button_chromeless(history_button)
	history_button.text = ""
	history_button.add_theme_color_override("font_color", Color.TRANSPARENT)
	_place(history_button, history_rect)
	var ticket_width := (history_rect.size.x - 9) * HISTORY_TICKET_WIDTH_SCALE
	_set_font(_place_hud_label_on(history_button, str(history_events.size()), 13, 8, CREAM, Rect2(4.5 + (ticket_width - 34) * 0.5, 0, 34, 20), "ServiceHistoryCount", HORIZONTAL_ALIGNMENT_CENTER, 2), L10N.NUMBER_FONT_RESOURCE)
	var visible_history := mini(4, history_events.size())
	for ticket_index in range(visible_history):
		var item: Dictionary = history_events[history_events.size() - 1 - ticket_index]
		var ticket_rect := Rect2(4.5, 19 + ticket_index * 66, ticket_width, 58.5)
		var ticket_frame := _texture(DB.art("hud_history_ticket_frame"), TextureRect.STRETCH_SCALE)
		ticket_frame.name = "ServiceHistoryTicket_%d" % ticket_index
		_place_on(history_button, ticket_frame, ticket_rect)
		var item_text_color := HISTORY_PLAYER_DAMAGE_TEXT if bool(item.get("highlight_red", item.get("user_took_damage", false))) else Color.WHITE
		var event_label := _place_hud_label_on(ticket_frame, String(item.get("event", "")), 9, 8, item_text_color, Rect2(9, 15, ticket_rect.size.x - 18, 18), "ServiceHistoryEvent_%d" % ticket_index, HORIZONTAL_ALIGNMENT_CENTER, 1)
		_set_font(event_label, L10N.BUTTON_FONT_RESOURCE)
		var amount := int(item.get("value", 0))
		var amount_label := _place_hud_label_on(ticket_frame, "%+d" % amount if amount != 0 else "—", 11, 8, Color.WHITE, Rect2(12, 33, ticket_rect.size.x - 24, 18), "ServiceHistoryAmount_%d" % ticket_index, HORIZONTAL_ALIGNMENT_CENTER, 1)
		_set_font(amount_label, L10N.NUMBER_FONT_RESOURCE)
		var event_line_height := event_label.get_theme_font("font").get_height(event_label.get_theme_font_size("font_size"))
		var amount_line_height := amount_label.get_theme_font("font").get_height(amount_label.get_theme_font_size("font_size"))
		var line_center_distance := (event_line_height + amount_line_height) * 0.5 + HISTORY_TICKET_TEXT_NUMBER_GAP
		var text_group_center_y := 32.0
		event_label.position.y = text_group_center_y - line_center_distance * 0.5 - event_label.size.y * 0.5
		amount_label.position.y = text_group_center_y + line_center_distance * 0.5 - amount_label.size.y * 0.5


func _render_player_mana_pool() -> void:
	var mana_rect := _target_battle_zone(&"player_mana")
	var glowing := player_mana > 1
	var pool := Control.new()
	pool.name = "PlayerManaPool"
	pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pool.clip_contents = true
	pool.set_meta("mana_glowing", glowing)
	_place(pool, mana_rect)
	var rack := _texture(DB.art("hud_mana_rack_frame"), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	rack.name = "PlayerManaRackFrame"
	rack.modulate = Color("#D9FAFF") if glowing else Color.WHITE
	_place_on(pool, rack, Rect2(Vector2(0, -5), mana_rect.size))

	var mana_readout_center_x := mana_rect.size.x * 0.5
	var mana_value_center_x := mana_readout_center_x + 5.5
	var mana_value_plate_size := Vector2(76, 40)
	var mana_value_plate := _hud_readability_plate_on(pool, Rect2(mana_value_center_x - mana_value_plate_size.x * 0.5, 26, mana_value_plate_size.x, mana_value_plate_size.y), MANA_BLUE, "PlayerManaValuePlate", 13)
	mana_value_plate.add_theme_stylebox_override("panel", _style(Color(HUD_DETAIL_BG, 1.0), Color(MANA_BLUE, 0.58), 1, 13))
	var value := _place_hud_label_on(mana_value_plate, t("battle.mana", {"current": player_mana, "maximum": player_max_mana}), 30, 18, Color.WHITE, Rect2(3, 0, mana_value_plate_size.x - 6, mana_value_plate_size.y), "PlayerManaValue", HORIZONTAL_ALIGNMENT_CENTER, 1)
	_set_font(value, L10N.NUMBER_FONT_RESOURCE)
	value.add_theme_color_override("font_outline_color", Color("#D8100A18"))

	var title_plate_size := Vector2(128, 33)
	var title_plate := _hud_readability_plate_on(pool, Rect2(mana_readout_center_x - title_plate_size.x * 0.5, 2, title_plate_size.x, title_plate_size.y), MANA_BLUE, "PlayerManaTitlePlate", 8)
	_set_font(_place_hud_label_on(title_plate, t("battle.mana_pool"), 16, 14, CREAM, Rect2(6, 2, title_plate_size.x - 12, title_plate_size.y - 4), "PlayerManaPoolTitle", HORIZONTAL_ALIGNMENT_CENTER, 2), L10N.HEADING_FONT_RESOURCE)

	var player_mana_crystal := _texture(DB.art("juice_mana_burner"))
	player_mana_crystal.name = "PlayerManaCrystal"
	player_mana_crystal.modulate = Color("#D9FAFF") if glowing else Color.WHITE
	_place_on(pool, player_mana_crystal, Rect2(18, 25, 44, 44))

	var pip_count := maxi(1, player_max_mana)
	var pip_diameter := 10.0
	var pip_width := pip_count * pip_diameter + maxi(0, pip_count - 1) * 4.0
	_render_resource_pips_on(pool, Vector2((mana_rect.size.x - pip_width) * 0.5, 71), player_mana, pip_count, MANA_BLUE, pip_diameter)

func _open_service_history() -> void:
	if screen_name != "battle" or service_history_open:
		return
	_reset_card_drag()
	_hide_card_preview()
	service_history_open = true
	_render_battle()


func _close_service_history() -> void:
	if not service_history_open:
		return
	service_history_open = false
	_render_battle()


func _render_service_history_dialog() -> void:
	var overlay := Control.new()
	overlay.name = "ServiceHistoryDialog"
	overlay.z_index = 150
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_layer.add_child(overlay)

	_modal_backdrop(overlay, Color(MODAL_MASK, 0.35), "history")
	if _presented_modal != "history" and not debug_fast:
		overlay.modulate.a = 0.0
		overlay.create_tween().tween_property(overlay, "modulate:a", 1.0, 0.2)

	var dialog_rect := _centered_safe_modal_rect(Vector2(780, 580))
	_board_on(overlay, dialog_rect, COPPER, true, "ServiceHistoryBoard")
	_heading(overlay, t("history.heading"), 30, CREAM, Rect2(dialog_rect.position + Vector2(50, 21), Vector2(680, 44)), HORIZONTAL_ALIGNMENT_CENTER)
	_place_on(overlay, _label(t("history.dialog_summary", {"count": history_events.size()}), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER), Rect2(dialog_rect.position + Vector2(50, 62), Vector2(680, 24)))

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	_place_on(overlay, header, Rect2(dialog_rect.position + Vector2(42, 94), Vector2(696, 26)))
	var number_header := _label(t("history.column.number"), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	number_header.custom_minimum_size.x = 34.0
	header.add_child(number_header)
	var source_header := _label(t("history.column.source"), 10, MUTED)
	source_header.custom_minimum_size.x = 150.0
	header.add_child(source_header)
	var event_header := _label(t("history.column.result"), 10, MUTED)
	event_header.custom_minimum_size.x = 176.0
	header.add_child(event_header)
	var target_header := _label(t("history.column.target"), 10, MUTED)
	target_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(target_header)
	var value_header := _label(t("history.column.value"), 10, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	value_header.custom_minimum_size.x = 64.0
	header.add_child(value_header)

	var scroll := ScrollContainer.new()
	scroll.name = "ServiceHistoryScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	_place_on(overlay, scroll, Rect2(dialog_rect.position + Vector2(42, 122), Vector2(696, 370)))

	var rows := VBoxContainer.new()
	rows.name = "ServiceHistoryRows"
	rows.custom_minimum_size.x = 676.0
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)

	if history_events.is_empty():
		var empty := _label(t("history.empty"), 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		empty.custom_minimum_size = Vector2(676, 110)
		rows.add_child(empty)
	else:
		for index in range(history_events.size()):
			var item: Dictionary = history_events[index]
			var item_color: Color = item.get("color", MUTED)
			var row := PanelContainer.new()
			row.custom_minimum_size = Vector2(676, 54)
			row.tooltip_text = String(item.get("detail", ""))
			row.add_theme_stylebox_override("panel", _style(Color(0.10, 0.055, 0.13, 0.96), Color(item_color, 0.55), 1, 9))
			rows.add_child(row)

			var columns := HBoxContainer.new()
			columns.add_theme_constant_override("separation", 10)
			row.add_child(columns)
			var number := _label("%02d" % (index + 1), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
			number.custom_minimum_size.x = 34.0
			columns.add_child(number)
			var source := _label(String(item.get("source", "")), 12, item_color)
			source.custom_minimum_size.x = 150.0
			source.autowrap_mode = TextServer.AUTOWRAP_OFF
			source.clip_text = true
			source.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			columns.add_child(source)
			var result := _label(String(item.get("event", "")), 12, item_color)
			result.custom_minimum_size.x = 176.0
			result.autowrap_mode = TextServer.AUTOWRAP_OFF
			result.clip_text = true
			result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			columns.add_child(result)
			var target := _label(String(item.get("target", "")), 12, CREAM)
			target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			target.autowrap_mode = TextServer.AUTOWRAP_OFF
			target.clip_text = true
			target.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			columns.add_child(target)
			var amount := int(item.get("value", 0))
			var value := _label("%+d" % amount if amount != 0 else "—", 12, item_color, HORIZONTAL_ALIGNMENT_RIGHT)
			value.custom_minimum_size.x = 64.0
			columns.add_child(value)
		scroll.set_deferred("scroll_vertical", 1000000)

	var close_button := _button(t("common.done_escape"), _close_service_history, TEAL)
	close_button.name = "CloseServiceHistoryButton"
	_place_plaque_on(overlay, close_button, Rect2(dialog_rect.position + Vector2(180, 512), Vector2(420, 48)), "plate", TEAL, 17)
	close_button.call_deferred("grab_focus")


func _render_kitchen() -> void:
	recipe_anchors.clear()
	reward_anchors.clear()
	_clear_ui()
	_add_background(DB.art("kitchen_break"), Color("#BFFFFFFF"))
	var shade := ColorRect.new()
	shade.color = _shade_color(Color("#69100A18"))
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_layer.add_child(shade)

	_plank_on(screen_layer, Rect2(24, 18, 1232, 60), "sign", banner_color, "KitchenBannerPlank")
	_heading(screen_layer, banner_text, 20, banner_color.lightened(0.25), Rect2(42, 27, 1196, 42), HORIZONTAL_ALIGNMENT_CENTER)

	_board_on(screen_layer, Rect2(28, 96, 248, 544), COPPER, false, "KitchenChefBoard")
	_place(_texture(DB.art("chef_sama")), Rect2(47, 108, 210, 190))
	_heading(screen_layer, t("player.chef_sama"), 20, CREAM, Rect2(47, 292, 210, 34), HORIZONTAL_ALIGNMENT_CENTER)
	_place(_label(t("kitchen.health", {"current": player_health, "maximum": player_max_health}), 17, TEAL, HORIZONTAL_ALIGNMENT_CENTER), Rect2(47, 326, 210, 27))
	_place(_label(t("kitchen.pantry"), 16, EMBER, HORIZONTAL_ALIGNMENT_CENTER), Rect2(47, 350, 210, 28))
	_place(_texture(DB.art("juice_pantry_jar")), Rect2(49, 382, 48, 83))
	var kitchen_ingredients := ["fungus", "herb", "meat", "ember"]
	for ingredient_index in range(kitchen_ingredients.size()):
		var ingredient_id: String = kitchen_ingredients[ingredient_index]
		var ingredient_y := 385.0 + ingredient_index * 25.0
		_place(_texture(DB.art("ingredient_" + ingredient_id)), Rect2(68, ingredient_y, 24, 24))
		_place(_label(t("kitchen.ingredient_count", {"ingredient": _ingredient_name(ingredient_id), "count": int(pantry[ingredient_id])}), 15, CREAM), Rect2(100, ingredient_y, 125, 24))
	pantry_anchor = Vector2(80, 427)
	_place_plaque_on(screen_layer, _button(t("kitchen.view_deck", {"count": run_deck.size()}), func(): deck_overlay_open = true; _render_kitchen(), TEAL), Rect2(49, 525, 206, 49), "plate", TEAL, 15)
	var continue_button := _place_plaque_on(screen_layer, _button(t("common.continue"), _continue_from_kitchen, EMBER), Rect2(49, 583, 206, 44), "plate", GOLD, 16)
	continue_button.add_theme_color_override("font_color", Color("#FFE3A0"))

	_board_on(screen_layer, Rect2(294, 96, 580, 544), COPPER, false, "KitchenCookBoard")
	_heading(screen_layer, t("kitchen.cook_heading"), 23, CREAM, Rect2(316, 109, 536, 38), HORIZONTAL_ALIGNMENT_CENTER)
	_place(_texture(DB.art("juice_cooking_cauldron")), Rect2(785, 102, 70, 70))
	_place(_label(t("kitchen.cook_description"), 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER), Rect2(316, 145, 536, 26))
	var recipe_ids := ["mooncap_broth", "braised_bulwark", "dragonpepper_roast", "leftover_stew"]
	for index in range(recipe_ids.size()):
		var recipe_id: String = recipe_ids[index]
		var recipe: Dictionary = DB.RECIPES[recipe_id]
		var definition := DB.card(recipe.card)
		var recipe_y := 185.0 + index * 105.0
		var art := _texture(DB.art(definition.art))
		_place(art, Rect2(315, recipe_y + 4, 78, 86))
		var cost_text := _recipe_cost_text(recipe)
		_place_display_on(screen_layer, _display_label(t(recipe.name_key), L10N.NAME_FONT_RESOURCE, 17, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 2), Rect2(405, recipe_y + 4, 260, 25), 12)
		_place(_label(t("kitchen.recipe_details", {"cost": cost_text, "summary": t(recipe.summary_key)}), 13, MUTED), Rect2(405, recipe_y + 31, 260, 54))
		var cook_button := _button(t("kitchen.cook"), func(id := recipe_id): _cook_recipe(id), EMBER, not _can_cook(recipe_id))
		cook_button.set_meta("juice_kind", "recipe")
		_place_plaque_on(screen_layer, cook_button, Rect2(702, recipe_y + 18, 145, 56), "plate", EMBER, 17)
		if index < recipe_ids.size() - 1:
			_place(_chalk_rule(), Rect2(318, recipe_y + 97, 530, 1))
		recipe_anchors[recipe_id] = Vector2(774, recipe_y + 46)

	_board_on(screen_layer, Rect2(892, 96, 364, 544), GOLD, false, "KitchenRewardBoard")
	_heading(screen_layer, t("kitchen.reward_heading"), 22, CREAM, Rect2(912, 109, 324, 36), HORIZONTAL_ALIGNMENT_CENTER)
	_place(_label(t("kitchen.reward_description"), 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER), Rect2(912, 144, 324, 24))
	var compact_rewards := reward_options.size() > 3
	for index in range(reward_options.size()):
		var card_id := reward_options[index]
		var definition := DB.card(card_id)
		var revealed := bool(reward_revealed.get(card_id, false))
		var column := index % 2 if compact_rewards else 0
		var row := index / 2 if compact_rewards else index
		var y := 182.0 + row * 118.0
		var x := 916.0 + column * 158.0
		var reward_width := 150.0 if compact_rewards else 316.0
		var reward_button := _button("", func(id := card_id):
			if bool(reward_revealed.get(id, false)):
				_select_reward(id)
			else:
				_reveal_reward(id)
		, _rarity_color(definition.rarity) if revealed else GOLD.darkened(0.35), reward_done)
		reward_button.set_meta("juice_kind", "reward")
		reward_button.set_meta("reward_revealed", revealed)
		_plaque(reward_button, "row", _rarity_color(definition.rarity) if revealed else GOLD, 13)
		_place(reward_button, Rect2(x, y, reward_width, 102))
		reward_anchors[card_id] = Vector2(x + reward_width * 0.5, y + 51)
		if not revealed:
			var back := _texture(DB.art("juice_card_back"))
			back.position = Vector2(8, 6)
			back.size = Vector2(68, 90)
			reward_button.add_child(back)
			var hidden := _label(t("kitchen.sealed_card"), 11 if compact_rewards else 13, EMBER, HORIZONTAL_ALIGNMENT_CENTER)
			hidden.position = Vector2(76, 18)
			hidden.size = Vector2(reward_width - 82, 66)
			reward_button.add_child(hidden)
			continue
		var art := _texture(DB.art(definition.art))
		art.position = Vector2(8, 8)
		art.size = Vector2(54, 84) if compact_rewards else Vector2(78, 84)
		reward_button.add_child(art)
		var text_x := 68.0 if compact_rewards else 94.0
		var text_width := reward_width - text_x - 8.0
		var cost_readout := _mana_readout(
			str(int(definition.cost)),
			10 if compact_rewards else 12,
			CREAM,
			15.0 if compact_rewards else 18.0
		)
		cost_readout.name = "LegendaryRewardCost"
		cost_readout.position = Vector2(text_x, 9)
		cost_readout.size = Vector2(38 if compact_rewards else 48, 27)
		cost_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reward_button.add_child(cost_readout)
		var name_x := text_x + (40.0 if compact_rewards else 50.0)
		var reward_name := _label(t(definition.name_key), 9 if compact_rewards else 11, CREAM)
		reward_name.name = "LegendaryRewardName"
		reward_name.position = Vector2(name_x, 5)
		reward_name.size = Vector2(reward_width - name_x - 8.0, 34)
		reward_name.max_lines_visible = 2
		reward_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reward_button.add_child(reward_name)
		var details := _label(t(definition.text_key), 9 if compact_rewards else 12, MUTED)
		details.position = Vector2(text_x, 39)
		details.size = Vector2(text_width, 51)
		details.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reward_button.add_child(details)
	var all_revealed := true
	for reward_id in reward_options:
		if not bool(reward_revealed.get(reward_id, false)):
			all_revealed = false
			break
	_place_plaque_on(screen_layer, _button(t("kitchen.reveal_all"), _reveal_all_rewards, TEAL, reward_done or all_revealed), Rect2(916, 553, 148, 48), "plate", TEAL, 14)
	_place_plaque_on(screen_layer, _button(t("common.skip"), _skip_reward, MUTED, reward_done), Rect2(1074, 553, 118, 48), "plate", TAVERN.BRASS, 14)

	if deck_overlay_open:
		_render_deck_overlay()
	_render_pause_overlay()
	_post_render()


func _recipe_cost_text(recipe: Dictionary) -> String:
	if recipe.has("cost_any"):
		return t("kitchen.cost_any", {"count": _scaled_recipe_cost(int(recipe.cost_any))})
	var parts: Array[String] = []
	for ingredient in recipe.cost:
		parts.append(t("kitchen.cost_part", {"count": _scaled_recipe_cost(int(recipe.cost[ingredient])), "ingredient": _ingredient_name(String(ingredient))}))
	return t("kitchen.cost", {"ingredients": " + ".join(parts)})


func _render_deck_overlay() -> void:
	var overlay := Control.new()
	overlay.name = "DeckOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_layer.add_child(overlay)

	var backdrop := _modal_backdrop(overlay, Color(0.0, 0.0, 0.0, 0.62), "deck")
	backdrop.name = "DeckOverlayBackdrop"
	if _presented_modal != "deck" and not debug_fast:
		overlay.modulate.a = 0.0
		overlay.create_tween().tween_property(overlay, "modulate:a", 1.0, 0.2)

	var dialog := _panel_on(overlay, Rect2(140, 30, 1000, 660), Color(0.035, 0.02, 0.05, 1.0), TEAL, 3, 18)
	dialog.name = "DeckDialogPanel"
	var dialog_board := TAVERN.Board.new()
	dialog_board.accent = TEAL
	dialog_board.hanging = true
	dialog_board.outset = 0.0
	dialog_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(dialog_board)
	_heading(overlay, t("deck.heading", {"count": run_deck.size()}), 27, CREAM, Rect2(176, 45, 928, 42), HORIZONTAL_ALIGNMENT_CENTER)

	var card_scroll := ScrollContainer.new()
	card_scroll.name = "DeckCardScroll"
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.follow_focus = true
	card_scroll.clip_contents = true
	_place_on(overlay, card_scroll, Rect2(174, 92, 932, 218))

	var card_inset := MarginContainer.new()
	card_inset.name = "DeckCardInset"
	card_inset.add_theme_constant_override("margin_left", 7)
	card_inset.add_theme_constant_override("margin_top", 14)
	card_inset.add_theme_constant_override("margin_right", 7)
	card_scroll.add_child(card_inset)

	var card_row := HBoxContainer.new()
	card_row.name = "DeckCardRow"
	card_row.custom_minimum_size.y = 190.0
	card_row.add_theme_constant_override("separation", 14)
	card_inset.add_child(card_row)
	var card_width := 126.0
	var card_height := 190.0
	for card_index in range(run_deck.size()):
		var runtime_card: Dictionary = run_deck[card_index]
		var card := _card_button(runtime_card, card_index, card_width, card_height, true, true)
		card.name = "DeckCard%d" % card_index
		card.custom_minimum_size = Vector2(card_width, card_height)
		card.pivot_offset = Vector2(card_width, card_height) * 0.5
		card_row.add_child(card)

	var counts := {}
	var servings := {}
	for runtime_card in run_deck:
		counts[runtime_card.id] = int(counts.get(runtime_card.id, 0)) + 1
		if runtime_card.servings > 0:
			servings[runtime_card.id] = int(servings.get(runtime_card.id, 0)) + runtime_card.servings
	var entries: Array[Dictionary] = []
	for card_id in counts:
		var definition := DB.card(card_id)
		var extra := t("deck.total_servings", {"count": int(servings[card_id])}) if servings.has(card_id) else ""
		entries.append({
			"sort": t(definition.name_key),
			"count": int(counts[card_id]),
			"cost": int(definition.cost),
			"name": t(definition.name_key),
			"servings": extra,
			"rules": t(definition.text_key),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.sort) < String(b.sort))
	var summary_scroll := ScrollContainer.new()
	summary_scroll.name = "DeckSummaryScroll"
	summary_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	summary_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	summary_scroll.follow_focus = true
	_place_on(overlay, summary_scroll, Rect2(174, 326, 932, 246))
	var columns := HBoxContainer.new()
	columns.name = "DeckSummaryColumns"
	columns.custom_minimum_size.x = 912.0
	columns.add_theme_constant_override("separation", 24)
	summary_scroll.add_child(columns)
	for column_index in range(2):
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(444, 0)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 6)
		columns.add_child(column)
		for entry_index in range(column_index, entries.size(), 2):
			var entry_data: Dictionary = entries[entry_index]
			var entry := VBoxContainer.new()
			entry.custom_minimum_size = Vector2(444, 58)
			entry.add_theme_constant_override("separation", 0)
			column.add_child(entry)
			var heading := _mana_readout(
				str(int(entry_data.cost)), 13, CREAM, 19.0,
				"%d×" % int(entry_data.count),
				" · %s%s" % [String(entry_data.name), String(entry_data.servings)]
			)
			heading.alignment = BoxContainer.ALIGNMENT_BEGIN
			heading.custom_minimum_size = Vector2(444, 25)
			entry.add_child(heading)
			var rules := _label(String(entry_data.rules), 12, MUTED)
			rules.custom_minimum_size = Vector2(444, 30)
			entry.add_child(rules)
	var close_button := _button(t("deck.back"), func(): deck_overlay_open = false; _render_kitchen(), TEAL)
	close_button.name = "CloseDeckOverlayButton"
	_place_plaque_on(overlay, close_button, Rect2(430, 596, 420, 50), "plate", TEAL, 17)
	close_button.call_deferred("grab_focus")


func _render_route() -> void:
	_clear_ui()
	_add_background(DB.art("kitchen_break"), Color("#AFFFFFFF"))
	var shade := ColorRect.new()
	shade.color = _shade_color(Color("#8A100A18"))
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_layer.add_child(shade)
	var route_seal := _texture(DB.art("juice_encounter_seal"))
	route_seal.modulate = Color(1, 1, 1, 0.3)
	_place(route_seal, Rect2(594, 22, 92, 92))
	_heading(screen_layer, t("route.choose_second_course"), 37, CREAM, Rect2(220, 38, 840, 56), HORIZONTAL_ALIGNMENT_CENTER)
	_place(_label(t("route.description"), 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER), Rect2(280, 91, 720, 32))
	_render_route_card("mold_monarch", Rect2(110, 143, 500, 500), t("route.cold_cellar.name"), t("route.cold_cellar.description"))
	_render_route_card("ember_butcher", Rect2(670, 143, 500, 500), t("route.smokehouse.name"), t("route.smokehouse.description"))
	_render_pause_overlay()
	_post_render()


func _render_route_card(encounter_id: String, rect: Rect2, route_name: String, description: String) -> void:
	var encounter := DB.encounter(encounter_id)
	var button := _button("", func(): _choose_route(encounter_id), EMBER)
	button.set_meta("juice_kind", "route")
	_plaque(button, "panel", EMBER if encounter_id == "ember_butcher" else TEAL)
	_place(button, rect)
	var portrait := _texture(DB.art(encounter.portrait))
	portrait.position = Vector2(44, 20)
	portrait.size = Vector2(rect.size.x - 88, 310)
	button.add_child(portrait)
	var seal := _texture(DB.art("juice_encounter_seal"))
	seal.position = Vector2(rect.size.x - 88, 18)
	seal.size = Vector2(62, 62)
	button.add_child(seal)
	var knife := _texture(DB.art("juice_selection_knife"))
	knife.position = Vector2(18, 312)
	knife.size = Vector2(96, 46)
	knife.rotation = -0.16
	button.add_child(knife)
	var route := _display_label(route_name, L10N.HEADING_FONT_RESOURCE, 25, EMBER, HORIZONTAL_ALIGNMENT_CENTER, 3)
	route.position = Vector2(20, 333)
	route.size = Vector2(rect.size.x - 40, 38)
	route.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(route)
	var title := _display_label(t(encounter.name_key), L10N.NAME_FONT_RESOURCE, 20, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 2)
	title.position = Vector2(20, 372)
	title.size = Vector2(rect.size.x - 40, 32)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(title)
	var desc := _label(t("route.card_description", {"description": description, "passive": t(encounter.passive_key)}), 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	desc.position = Vector2(42, 404)
	desc.size = Vector2(rect.size.x - 84, 84)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(desc)


func _render_end() -> void:
	_clear_ui()
	_add_background(DB.art("title_kitchen"), Color("#ADFFFFFF"))
	var shade := ColorRect.new()
	shade.color = _shade_color(Color("#7F100A18"))
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_layer.add_child(shade)
	var victory := run_result == "victory"
	var headline := t("end.victory.headline" if victory else "end.defeat.headline")
	var color := TEAL if victory else CRIMSON
	var headline_label := _place_display_on(screen_layer, _display_label(headline, L10N.TITLE_FONT_RESOURCE, 44, Color("#FFE8B4"), HORIZONTAL_ALIGNMENT_CENTER, 8), Rect2(180, 26, 920, 64), 28)
	headline_label.add_theme_color_override("font_outline_color", Color("#1A0A12"))
	headline_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	headline_label.add_theme_constant_override("shadow_offset_y", 4)
	headline_label.add_theme_constant_override("shadow_outline_size", 10)
	if _motion_full():
		headline_label.material = TAVERN.shine_material(headline_label.size, 4.5)
	if victory:
		_render_victory_legendary_showcase()
	_board_on(screen_layer, Rect2(30, 136, 382, 550), color, false, "RunLedgerBoard")
	_heading(screen_layer, t("end.run_ledger"), 24, CREAM, Rect2(54, 148, 334, 32), HORIZONTAL_ALIGNMENT_CENTER)
	var stars := TAVERN.StarRow.new()
	stars.earned = _battles_cleared(victory)
	stars.total = 3
	_place(stars, Rect2(151, 184, 140, 24))
	_place(_label(player_name, 12, TEAL, HORIZONTAL_ALIGNMENT_CENTER), Rect2(54, 207, 334, 17))
	var score_label := _place_display_on(screen_layer, _display_label("%d" % last_run_score, L10N.NUMBER_FONT_RESOURCE, 48, color, HORIZONTAL_ALIGNMENT_CENTER, 4), Rect2(54, 222, 334, 50), 32)
	score_label.add_theme_color_override("font_shadow_color", Color(color, 0.45))
	score_label.add_theme_constant_override("shadow_outline_size", 12)
	score_label.add_theme_constant_override("shadow_offset_y", 0)
	_place(_label(t("end.final_score"), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER), Rect2(54, 274, 334, 20))
	_reveal_run_result(score_label, stars)
	var route_text := t("route.cold_cellar.name") if selected_route == "mold_monarch" else t("route.smokehouse.name") if selected_route == "ember_butcher" else t("end.route_not_reached")
	var summary := t("end.summary", {"battles": _battles_cleared(victory), "precise": precise_kills, "ruined": overkills, "dishes": dishes_cooked, "health": player_health, "maximum": player_max_health, "cards": run_deck.size(), "route": route_text, "streak": lifetime.best_streak})
	_render_end_summary_table(summary, Rect2(68, 300, 306, 214))
	_place(_label(t("end.local_score_saved"), 12, TEAL, HORIZONTAL_ALIGNMENT_CENTER), Rect2(60, 510, 322, 24))
	var again := _place_plaque_on(screen_layer, _button(t("end.run_again"), start_new_run, EMBER), Rect2(64, 548, 314, 52), "plate", GOLD, 18)
	again.add_theme_color_override("font_color", Color("#FFE3A0"))
	_place_plaque_on(screen_layer, _button(t("end.return_title"), show_title, TEAL), Rect2(64, 612, 314, 44), "plate", TEAL, 16)

	_render_leaderboards(Rect2(430, 136, 820, 550), true)
	_post_render()


## Result reveal: the score ticks up from zero and the earned stars pop in one after another.
func _reveal_run_result(score_label: Label, stars: Control) -> void:
	if last_rendered_screen != "end":
		_result_reveal_msec = Time.get_ticks_msec()
	# Re-renders (e.g. a leaderboard response) resume the reveal instead of restarting or skipping it.
	var elapsed := float(Time.get_ticks_msec() - _result_reveal_msec) / 1000.0
	if elapsed > 2.0 or not _motion_full():
		return
	var final_score := last_run_score
	score_label.text = "0"
	stars.call("set_reveal", 0.0)
	var reveal := score_label.create_tween()
	reveal.tween_interval(0.35)
	reveal.tween_method(func(value: float):
		if is_instance_valid(score_label):
			score_label.text = "%d" % roundi(value)
	, 0.0, float(final_score), 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_callback(func():
		if juice != null:
			juice.play_sfx("click", -8.0)
		if is_instance_valid(score_label):
			score_label.pivot_offset = score_label.size * 0.5
			var punch := score_label.create_tween()
			punch.tween_property(score_label, "scale", Vector2(1.14, 1.14), 0.08)
			punch.tween_property(score_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	var star_tween := stars.create_tween()
	star_tween.tween_interval(0.5)
	star_tween.tween_method(func(value: float):
		if is_instance_valid(stars):
			stars.call("set_reveal", value)
	, 0.0, 1.0, 1.0)
	if elapsed > 0.0:
		reveal.custom_step(elapsed)
		star_tween.custom_step(elapsed)


func _render_victory_legendary_showcase() -> void:
	var legendary_ids: Array[String] = []
	for card_id in DB.LEGENDARY_REWARDS:
		if claimed_legendary_ids.has(card_id):
			legendary_ids.append(card_id)
	if legendary_ids.is_empty():
		return
	var showcase := Control.new()
	showcase.name = "VictoryLegendaryShowcase"
	showcase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(showcase, Rect2(172, 92, 936, 36))
	_heading(showcase, t("end.legendary_service"), 14, GOLD, Rect2(0, 4, 180, 28), HORIZONTAL_ALIGNMENT_CENTER)
	var gap := 10.0
	var chip_width := (showcase.size.x - 190.0 - gap * float(legendary_ids.size() - 1)) / float(legendary_ids.size())
	for index in range(legendary_ids.size()):
		var card_id := legendary_ids[index]
		var definition := DB.card(card_id)
		var x := 190.0 + index * (chip_width + gap)
		_panel_on(showcase, Rect2(x, 0, chip_width, 36), Color(0.03, 0.015, 0.045, 0.92), GOLD, 1, 9)
		_place_on(showcase, _texture(DB.art(definition.art)), Rect2(x + 5, 3, 27, 30))
		_place_on(showcase, _label(t(definition.name_key), 12, CREAM, HORIZONTAL_ALIGNMENT_CENTER), Rect2(x + 36, 5, chip_width - 42, 26))


func _render_end_summary_table(summary: String, rect: Rect2) -> void:
	var table := Control.new()
	table.name = "RunSummaryTable"
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(table, rect)

	var rows := summary.split("\n", false)
	var row_height := rect.size.y / maxf(1.0, float(rows.size()))
	var label_width := 170.0
	var column_gap := 12.0
	var value_x := label_width + column_gap
	for index in range(rows.size()):
		var row := String(rows[index])
		var separator := row.find("  ")
		var label_text := row.strip_edges()
		var value_text := ""
		if separator >= 0:
			label_text = row.substr(0, separator).strip_edges()
			value_text = row.substr(separator).strip_edges()

		var row_y := index * row_height
		var label := _label(label_text, 15, MUTED)
		label.name = "Label%d" % index
		_place_on(table, label, Rect2(0, row_y, label_width, row_height))
		var value := _label(value_text, 15, MUTED)
		value.name = "Value%d" % index
		_place_on(table, value, Rect2(value_x, row_y, rect.size.x - value_x, row_height))


func _technique_sfx_kind(definition: Dictionary) -> String:
	if String(definition.get("type", "")) != "spell":
		return ""
	match String(definition.get("effect", "")):
		"target_enemy_damage", "enemy_area_damage", "sovereign_cleaver":
			return "technique_attack"
		"target_friend_buff", "armor", "bell_last_service":
			return "technique_buff"
		_:
			return ""


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary": return GOLD
		"rare": return TEAL
		"epic": return Color("#B990FF")
		"dish": return EMBER
		"enemy": return CRIMSON
		_: return COPPER


func _load_stats() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_environment("GAME_CAPTURE_DIR").is_empty():
		return
	var parsed: Dictionary = ATOMIC_JSON.load_dictionary(SAVE_PATH)
	if parsed.is_empty() or int(parsed.get("schema_version", 0)) > SAVE_SCHEMA_VERSION:
		return
	for key in lifetime:
		lifetime[key] = _saved_int(parsed, key, int(lifetime[key]), 0)
	reduce_motion = _saved_bool(parsed, "reduce_motion", reduce_motion)
	sound_muted = _saved_bool(parsed, "sound_muted", sound_muted)
	motion_mode = _saved_string(parsed, "motion_mode", JUICE_PROFILES.MOTION_REDUCED if reduce_motion else JUICE_PROFILES.MOTION_FULL)
	if motion_mode not in [JUICE_PROFILES.MOTION_FULL, JUICE_PROFILES.MOTION_REDUCED, JUICE_PROFILES.MOTION_MINIMAL]:
		motion_mode = JUICE_PROFILES.MOTION_REDUCED if reduce_motion else JUICE_PROFILES.MOTION_FULL
	reduce_motion = motion_mode != JUICE_PROFILES.MOTION_FULL
	shake_intensity = _saved_float(parsed, "shake_intensity", shake_intensity, 0.0, 1.0)
	flash_intensity = _saved_float(parsed, "flash_intensity", flash_intensity, 0.0, 1.0)
	particle_density = _saved_float(parsed, "particle_density", particle_density, 0.0, 1.0)
	animation_speed = _saved_float(parsed, "animation_speed", animation_speed, 0.5, 2.0)
	auto_accelerate = _saved_bool(parsed, "auto_accelerate", auto_accelerate)
	captions_enabled = _saved_bool(parsed, "captions_enabled", captions_enabled)
	player_name = LEADERBOARD_CLIENT.normalize_chef_name(_saved_string(parsed, "player_name", player_name))
	local_scores.clear()
	var saved_scores = parsed.get("local_scores", [])
	if saved_scores is Array:
		for saved_score in saved_scores:
			if saved_score is Dictionary and int(saved_score.get("score_version", 0)) == LEADERBOARD_CLIENT.SCORE_VERSION:
				local_scores.append(saved_score.duplicate(true))
	LEADERBOARD_CLIENT.sort_entries(local_scores)
	if local_scores.size() > LEADERBOARD_CLIENT.LOCAL_LIMIT:
		local_scores.resize(LEADERBOARD_CLIENT.LOCAL_LIMIT)
	pending_global_submissions.clear()
	var saved_pending = parsed.get("pending_global_submissions", [])
	if saved_pending is Array:
		for pending in saved_pending:
			if pending is Dictionary and int(pending.get("score_version", 0)) == LEADERBOARD_CLIENT.SCORE_VERSION:
				pending_global_submissions.append(pending.duplicate(true))
	elif parsed.get("pending_global_submission", {}) is Dictionary:
		var legacy_pending: Dictionary = parsed.get("pending_global_submission", {})
		if not legacy_pending.is_empty() and int(legacy_pending.get("score_version", 0)) == LEADERBOARD_CLIENT.SCORE_VERSION:
			pending_global_submissions.append(legacy_pending.duplicate(true))


func _saved_int(payload: Dictionary, key: String, fallback: int, minimum: int, maximum: int = 2147483647) -> int:
	var value: Variant = payload.get(key, fallback)
	return clampi(int(value), minimum, maximum) if value is int or value is float else fallback


func _saved_float(payload: Dictionary, key: String, fallback: float, minimum: float, maximum: float) -> float:
	var value: Variant = payload.get(key, fallback)
	return clampf(float(value), minimum, maximum) if value is int or value is float else fallback


func _saved_bool(payload: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = payload.get(key, fallback)
	return bool(value) if value is bool else fallback


func _saved_string(payload: Dictionary, key: String, fallback: String) -> String:
	var value: Variant = payload.get(key, fallback)
	return String(value) if value is String else fallback


func _save_stats() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_environment("GAME_CAPTURE_DIR").is_empty():
		return
	var payload := lifetime.duplicate(true)
	payload.schema_version = SAVE_SCHEMA_VERSION
	payload.reduce_motion = reduce_motion
	payload.sound_muted = sound_muted
	payload.motion_mode = motion_mode
	payload.shake_intensity = shake_intensity
	payload.flash_intensity = flash_intensity
	payload.particle_density = particle_density
	payload.animation_speed = animation_speed
	payload.auto_accelerate = auto_accelerate
	payload.captions_enabled = captions_enabled
	payload.player_name = player_name
	payload.local_scores = local_scores
	payload.pending_global_submissions = pending_global_submissions
	var save_error := ATOMIC_JSON.save_dictionary(SAVE_PATH, payload)
	if save_error != OK:
		push_warning("Could not save player statistics: %s" % error_string(save_error))


func debug_force_battle_victory() -> void:
	if screen_name == "battle":
		enemy_health = 0
		_check_end_state()


func debug_force_run_victory() -> void:
	battle_number = 3
	enemy_health = 0
	_check_end_state()


func debug_force_defeat() -> void:
	player_health = 0
	_check_end_state()

func _consume_tweak_int(identifier: StringName, fallback: int) -> int:
	var value := int(_tweak(identifier, fallback))
	if tweaks != null: tweaks.record_consumed(identifier, value)
	return value

func _consume_tweak_float(identifier: StringName, fallback: float) -> float:
	var value := float(_tweak(identifier, fallback))
	if tweaks != null: tweaks.record_consumed(identifier, value)
	return value
