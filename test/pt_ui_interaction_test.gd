extends SceneTree
## Confirms targeted hand cards immediately enter board targeting without a Play-button step.
## Run with: godot --headless --path . --script res://test/pt_ui_interaction_test.gd

const GameUI := preload("res://scripts/pt/pt_game.gd")
const EngineScript := preload("res://scripts/pt/pt_engine.gd")
const AI := preload("res://scripts/pt/pt_ai.gd")
const Card := preload("res://scripts/pt/pt_card.gd")
const Defs := preload("res://scripts/pt/pt_defs.gd")

var failures: Array[String] = []
var flow_done := false
var flow_result: Variant = null

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PT_UI_FAIL: " + message)

func _run_flow(ui: Control, engine: RefCounted, player: Dictionary, card: RefCounted, gen: int) -> void:
	flow_result = await ui._play_flow(engine, player, card, gen)
	flow_done = true

func _run() -> void:
	var ui: Control = GameUI.new()
	root.add_child(ui)
	await process_frame

	var engine: RefCounted = EngineScript.new()
	var players: Array = [
		{"name": "HUMAN", "ai": false, "adv": 0},
		{"name": "OPPONENT", "ai": true, "adv": 1},
	]
	engine.setup({"players": players, "win": 6, "seed": 23}, [AI.new(0, 23), AI.new(1, 23)])
	ui.engine = engine
	ui.viewer = 0
	ui.actor = 0
	ui._gen = 1
	ui._build_panels()

	var player: Dictionary = engine.players[0]
	var software: RefCounted = Card.new(1000, "antivirus", Defs.DEFS["antivirus"])
	player.hand.append(software)
	_check(engine.can_play(player, software), "fixture Software card should be playable")
	var spec: Dictionary = engine.next_spec(software, {})
	var choices: Array = engine.choices_for(player, software, spec, {})
	_check(not choices.is_empty(), "fixture Software card should have a Server target")
	if choices.is_empty():
		ui.queue_free()
		quit(1)
		return

	call_deferred("_run_flow", ui, engine, player, software, ui._gen)
	await process_frame
	_check(ui.mode == "pick", "selecting a targeted hand card should immediately open board targeting")
	_check(ui.prompt_buttons.get_child_count() == 1, "targeting should not require a second Play button")
	if ui.prompt_buttons.get_child_count() == 1:
		_check(ui.prompt_buttons.get_child(0).text == "CANCEL", "Cancel should remain available while selecting a target")
	_check(ui.pick_cands.has(choices[0]), "the valid Server should be highlighted as a target")

	ui._on_net_card(choices[0])
	while not flow_done:
		await process_frame
	var result: Variant = flow_result
	_check(result is Dictionary, "clicking the highlighted board card should finish the play selection")
	if result is Dictionary:
		_check(result.get("kind") == "play", "selected Software should return a play action")
		_check(result.get("card") == software, "the original selected hand card should be played")
		_check(result.get("targets", {}).get("srv") == choices[0], "the clicked board card should become the target")

	var server: RefCounted = Card.new(1001, "auth_server", Defs.DEFS["auth_server"])
	player.hand.append(server)
	_check(engine.can_play(player, server), "fixture Server card should be playable")
	flow_done = false
	flow_result = null
	call_deferred("_run_flow", ui, engine, player, server, ui._gen)
	await process_frame
	_check(ui.mode == "place_server", "selecting a Server should enter board placement mode")
	var add_server: Button = null
	for child in ui.panels[0]._slots_root.get_children():
		if child is Button and child.text == "+ ADD\nSERVER":
			add_server = child
	_check(add_server != null, "the player's network should show a clickable empty Server slot")
	if add_server != null:
		add_server.emit_signal("pressed")
	while not flow_done:
		await process_frame
	var server_result: Variant = flow_result
	_check(server_result is Dictionary, "clicking the empty network slot should finish Server placement")
	if server_result is Dictionary:
		_check(server_result.get("card") == server, "the selected Server should be the card placed")
		_check(server_result.get("kind") == "play", "Server placement should return a play action")

	ui.queue_free()
	await process_frame
	if failures.is_empty():
		print("PT_UI_INTERACTION_TEST_OK direct_target=true play_button=false cancel=true")
		quit(0)
	else:
		print("PT_UI_INTERACTION_TEST_FAILED count=%d" % failures.size())
		quit(1)
