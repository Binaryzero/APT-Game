extends SceneTree

const CURSOR := preload("res://scripts/cursor_director.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("[CURSOR_FAIL] " + message)


func _run() -> void:
	_expect(CURSOR.ASSET_PATHS.size() == 12, "the intent language exposes all twelve cursor modes")
	for mode in CURSOR.ASSET_PATHS:
		var texture := load(String(CURSOR.ASSET_PATHS[mode])) as Texture2D
		_expect(texture != null, "%s cursor asset loads" % mode)
		if texture != null:
			_expect(texture.get_width() == 96 and texture.get_height() == 96, "%s cursor has the normalized source size" % mode)

	var packed_scene := load("res://scenes/card_game.tscn") as PackedScene
	_expect(packed_scene != null, "the game scene loads with the cursor director")
	if packed_scene == null:
		quit(1)
		return
	var game := packed_scene.instantiate()
	root.add_child(game)
	await process_frame
	game.sound_muted = true
	game.juice.set_audio_muted(true)
	var cursor: EmberpanCursorDirector = game.cursor_director
	_expect(cursor != null and cursor.get_parent() == game, "the cursor director is attached to the complete game")
	_expect(cursor != null and cursor.layer > game.tutorial_canvas.layer, "the cursor renders above gameplay and tutorial overlays")
	cursor.set_pointer_inside_window(false)
	_expect(not cursor.pointer_root.visible, "leaving the game window hides the in-game cursor and releases pointer ownership")
	cursor.set_pointer_inside_window(true)
	_expect(cursor.pointer_root.visible, "re-entering the game window restores the custom cursor")

	var button := Button.new()
	button.set_meta("juice_kind", "button")
	_expect(cursor.resolve_mode_for(button) == "interact", "ordinary buttons use the interaction glove")
	button.disabled = true
	_expect(cursor.resolve_mode_for(button) == "blocked", "disabled buttons advertise a blocked action")

	var card := Button.new()
	card.set_meta("juice_kind", "card")
	card.set_meta("playable", true)
	_expect(cursor.resolve_mode_for(card) == "grab", "playable cards advertise drag affordance")
	card.set_meta("playable", false)
	_expect(cursor.resolve_mode_for(card) == "blocked", "unplayable cards advertise their constraint")
	card.set_meta("inspection_only", true)
	_expect(cursor.resolve_mode_for(card) == "inspect", "deck cards remain inspectable")

	var hostile := Button.new()
	hostile.set_meta("juice_kind", "unit")
	hostile.set_meta("friendly", false)
	hostile.set_meta("legal_target", true)
	_expect(cursor.resolve_mode_for(hostile) == "attack", "legal enemies use the hostile target cursor")
	var friendly := Button.new()
	friendly.set_meta("juice_kind", "unit")
	friendly.set_meta("friendly", true)
	friendly.set_meta("legal_target", true)
	_expect(cursor.resolve_mode_for(friendly) == "support", "legal allies use the support cursor")

	var recipe := Button.new()
	recipe.set_meta("juice_kind", "recipe")
	_expect(cursor.resolve_mode_for(recipe) == "cook", "available recipes use the cooking cursor")
	var route := Button.new()
	route.set_meta("juice_kind", "route")
	_expect(cursor.resolve_mode_for(route) == "route", "encounters use the route cursor")

	game.screen_name = "battle"
	game.input_locked = true
	game.is_player_turn = true
	_expect(cursor.resolve_mode_for() == "wait", "locked battle input uses the waiting cursor")
	game.input_locked = false
	game.is_player_turn = false
	_expect(cursor.resolve_mode_for() == "wait", "enemy turns use the waiting cursor")
	game.is_player_turn = true
	game.pending_action = {"kind": "spell", "effect": "target_enemy_damage"}
	_expect(cursor.resolve_mode_for() == "attack", "hostile targeting persists across the board")
	game.pending_action = {"kind": "spell", "effect": "target_friend_buff"}
	_expect(cursor.resolve_mode_for() == "support", "beneficial targeting persists across the board")
	game.pending_action.clear()
	game.player_hand.clear()
	game.player_hand.append({"id": "coal_squire", "uid": 77, "servings": 0})
	game.player_mana = 8
	game.drag_active = true
	game.dragged_card_uid = 77
	var play_region: Rect2 = game._play_region_screen_rect()
	var pointer_region: Rect2 = game._rect_between_canvas_items(game.screen_layer, game, play_region)
	_expect(cursor.resolve_mode_for(null, pointer_region.get_center()) == "serve", "card drags use authoritative valid-drop feedback")
	_expect(cursor.resolve_mode_for(null, pointer_region.position + Vector2(1, 1)) == "serve", "cursor accepts the transformed play-region top-left boundary")
	_expect(cursor.resolve_mode_for(null, pointer_region.end - Vector2(1, 1)) == "serve", "cursor accepts the transformed play-region bottom-right boundary")
	_expect(cursor.resolve_mode_for(null, pointer_region.end + Vector2(0, 1)) == "blocked", "card drags reject points immediately outside the serving zone")
	game.drag_active = false
	game.dragged_card_uid = -1

	cursor.configure_motion("minimal")
	_expect(cursor.motion_reduced, "reduced and minimal presentation disable cursor flavor motion")
	cursor.configure_motion("full")
	_expect(not cursor.motion_reduced, "full presentation restores cursor motion")
	cursor._apply_mode("wait", true)
	_expect(cursor.icon.pivot_offset == cursor.icon.size * 0.5, "the waiting timer rotates around its own center axis")

	button.free()
	card.free()
	hostile.free()
	friendly.free()
	recipe.free()
	route.free()
	game.juice.music_player.stop()
	game.juice.music_player.stream = null
	await create_timer(0.15).timeout
	game.free()
	await create_timer(0.15).timeout
	await process_frame
	await process_frame
	if failures.is_empty():
		print("[CURSOR_PASS]")
		quit(0)
	else:
		quit(1)
