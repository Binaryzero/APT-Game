extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func has_label(root_node: Node, expected_text: String) -> bool:
	for label: Label in root_node.find_children("*", "Label", true, false):
		if label.text == expected_text:
			return true
	return false


func _run() -> void:
	var game = load("res://scenes/card_game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var entry := game.screen_layer.find_child("TitleMultiplayerButton", true, false) as Button
	expect(entry != null and not entry.disabled, "Title exposes multiplayer entry")
	var start_button := game.screen_layer.find_child("TitleStartButton", true, false) as Button
	expect(start_button != null, "Solo entry remains available")
	if start_button != null and entry != null:
		start_button.grab_focus()
		await create_timer(1.3).timeout
		entry.grab_focus()
		await create_timer(0.2).timeout
		expect(start_button.position.distance_to(Vector2(470, 262)) < 2.0, "START sign stays at its resting position after focus leaves during the entrance")
	game.queue_free()
	await process_frame
	var online = load("res://scenes/multiplayer.tscn").instantiate()
	root.add_child(online)
	await process_frame
	expect(online.bridge != null, "Native builds initialize a multiplayer client")
	expect(str(online.state.get("error", "")).is_empty(), "Native multiplayer has no platform restriction")
	expect(online.rules.get("precise_chop", {}).get("target") == "enemy", "Native UI loads PvP targeting metadata")
	online.set_process(false) # Keep synthetic UI states separate from native bridge polling.
	for locale in ["en", "zh-CN"]:
		online.state = {"screen": "setup", "status": "setup", "error": ""}
		online.L10N.set_locale(locale)
		online._render()
		await process_frame
		var labels: Array[Node] = online.layer.find_children("*", "Label", true, false)
		for label: Label in labels:
			expect(label.position.y >= 0 and label.position.y + label.size.y <= 721, "Setup labels fit viewport: " + label.text)
		expect(not online.layer.get_node("HostRoomButton").disabled, "Native Host is enabled without a settings screen")
		expect(not online.layer.get_node("JoinRoomButton").disabled, "Native Join is enabled")
		expect(online.layer.get_node("ResumeRoomButton").disabled, "Reconnect requires a saved seat")
		online.state["canResume"] = true
		online._render()
		expect(not online.layer.get_node("ResumeRoomButton").disabled, "Native Reconnect is enabled for a saved seat")
		for edit: LineEdit in online.layer.find_children("*", "LineEdit", true, false):
			expect(not edit.placeholder_text.contains("wss://"), "Players never configure a server URL")
		for button: Button in online.layer.find_children("*", "Button", true, false):
			expect(button.text != online.t("connection_settings"), "No infrastructure settings button in player flow")
		for connection_case in [
			{"mode": "host", "stage": "creating_room", "title": "connecting_host"},
			{"mode": "join", "stage": "joining_room", "title": "connecting_join"},
			{"mode": "resume", "stage": "restoring_seat", "title": "connecting_resume"},
		]:
			online.state = {
				"screen": "connecting",
				"status": "connecting",
				"connectionMode": connection_case.mode,
				"connectionStage": connection_case.stage,
				"error": "",
			}
			online._render()
			await process_frame
			expect(online.layer.find_child("PrimaryConnectionSpinner", true, false) != null, "Connection screen animates for " + connection_case.mode)
			expect(has_label(online.layer, online.t(connection_case.title)), "Connection screen names the " + connection_case.mode + " operation")
			expect(has_label(online.layer, online.t("status." + connection_case.stage)), "Connection screen explains the " + connection_case.stage + " phase")
	online.L10N.set_locale("en")
	online.state = {
		"screen": "lobby",
		"status": "connecting",
		"connectionMode": "join",
		"connectionStage": "negotiating_peer",
		"id": 2,
		"error": "",
		"room": {
			"catalog": {"starters": {"balanced": [], "aggro": [], "guard": []}, "heroes": ["chef_sama", "picklemancer", "mold_monarch", "ember_butcher", "banquet_tyrant"], "legendaries": ["mise_the_thousand_handed", "the_sovereign_cleaver", "bell_of_the_last_service"]},
			"id": "TEST",
			"members": [
				{"id": 1, "name": "Host", "connected": true, "ready": true},
				{"id": 2, "name": "Guest", "connected": true, "ready": false},
			],
		},
	}
	online._render()
	await process_frame
	expect(online.layer.find_child("SeatConnectionSpinner1", true, false) != null, "Lobby animates each peer still negotiating")
	expect(has_label(online.layer, online.t("status.negotiating_peer")), "Lobby keeps the current peer-negotiation status visible")
	for picker_name in ["LoadoutStarter", "LoadoutHero", "LoadoutLegendary"]:
		var picker = online.layer.get_node_or_null(picker_name)
		expect(picker is OptionButton, "Lobby exposes " + picker_name)
		if picker is OptionButton:
			expect(picker.item_count == (5 if picker_name == "LoadoutHero" else 3), "All choices available")
	expect(not has_label(online.layer, online.t("empty_seat")), "Two players fill the entire duel lobby; no extra seats")
	var has_ready := false
	for button: Button in online.layer.find_children("*", "Button", true, false):
		has_ready = has_ready or button.text == online.t("ready_button")
	expect(has_ready, "Either player can explicitly ready for the duel")
	online.state.status = "connected"
	online.state.connectionStage = "connected"
	online.state.room.members[1].ready = true
	online._render()
	online._maybe_play_connection_feedback(false)
	await process_frame
	expect(online.connection_feedback_count == 1, "Connected transition emits one celebration")
	expect(online.layer.find_child("ConnectionSuccessBanner", true, false) != null, "Connected transition shows a success banner")
	var connection_particles: Array[Node] = online.layer.find_children("*", "Polygon2D", true, false)
	expect(connection_particles.size() >= 20, "Connected transition emits a visible particle burst; got %d particles" % connection_particles.size())
	expect(online.feedback_audio.stream == online.CONNECTION_SUCCESS_SFX and online.feedback_audio.bus == "UI", "Connected transition uses the authored UI sound cue")
	online._maybe_play_connection_feedback(false)
	expect(online.connection_feedback_count == 1, "Stable connected polling does not replay the celebration")
	var reconnected_room: Dictionary = online.state["room"]
	var reconnected_members: Array = reconnected_room["members"]
	var reconnected_member: Dictionary = reconnected_members[0]
	reconnected_member["generation"] = 2
	reconnected_members[0] = reconnected_member
	reconnected_room["members"] = reconnected_members
	online.state["room"] = reconnected_room
	online._maybe_play_connection_feedback(false)
	expect(online.connection_feedback_count == 2, "A genuinely re-established peer generation celebrates once")
	await create_timer(1.8).timeout
	online.feedback_audio.stop()
	online.feedback_audio.stream = null
	online.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	await process_frame
	if failures.is_empty():
		print("[MULTIPLAYER_UI_PASS] One-click setup, bilingual connection phases and once-only success feedback validated")
	quit(0 if failures.is_empty() else 1)
