extends SceneTree
## Real-renderer capture driver: plays a few human decisions and saves screenshots.
## Run: xvfb-run -a godot --path . --resolution 1280x720 --script res://test/pt_capture.gd

var game: Node
var out_dir := "/tmp/pt_caps"

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out_dir + "/" + name + ".png")
	print("[SHOT] ", name)

func _wait_mode(m: String, timeout := 20.0) -> bool:
	var t := 0.0
	while game.mode != m and t < timeout:
		await create_timer(0.1).timeout
		t += 0.1
	return game.mode == m

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://scenes/packet_tactics.tscn")
	game = scene.instantiate()
	root.add_child(game)
	await create_timer(1.0).timeout
	await _shot("01_menu")
	game._on_start_requested({"mode": "ai", "players": 3, "win": 6, "name": "OPERATOR", "seed": 11})
	game.speed_idx = 2
	game.engine.pace = 0.02
	await _wait_mode("main")
	await create_timer(0.6).timeout
	await _shot("02_first_turn")
	var turns := 0
	var shots := 0
	var played := 0
	var shots_modal := 0
	var t0 := Time.get_ticks_msec()
	while not game.engine.over and turns < 400 and Time.get_ticks_msec() - t0 < 200000:
		if game.mode == "main":
			var p: Dictionary = game.engine.players[0]
			var choice: Variant = null
			for c in p.hand:
				if game.engine.can_play(p, c) and c.type() != "zd":
					choice = c
					break
			if choice != null and played < 40:
				game.decided.emit({"t": "card", "card": choice})
				await create_timer(0.1).timeout
				if shots < 3:
					await _shot("03_selected_%d" % shots)
				game.decided.emit({"t": "go"})
				await create_timer(0.1).timeout
				var guard := 0
				while game.mode in ["pick", "pick_player"] and guard < 4:
					if shots < 5:
						await _shot("04_pick_%d_%d" % [shots, guard])
					if game.mode == "pick":
						game.decided.emit({"card": game.pick_cands[0]})
					else:
						game.decided.emit({"seat": game.pick_cands[0]})
					await create_timer(0.2).timeout
					guard += 1
				shots += 1
				played += 1
			else:
				game.decided.emit({"t": "draw"})
			turns += 1
			await create_timer(0.05).timeout
			if turns % 10 == 0:
				await _shot("05_mid_%d" % turns)
		elif game.mode == "discard":
			game.discard_sel = game.engine.players[0].hand.slice(0, game.discard_need)
			game.decided.emit({"t": "confirm"})
			await create_timer(0.1).timeout
		elif game.mode == "respond":
			await _shot("06_respond")
			game.decided.emit({"t": "pass"})
			await create_timer(0.1).timeout
		elif game.mode == "pick":
			game.decided.emit({"card": game.pick_cands[0]})
			await create_timer(0.1).timeout
		else:
			if game.overlay_root.get_child_count() > 0 and game.mode == "idle":
				if shots_modal < 2:
					shots_modal += 1
					await _shot("08_modal_%d" % shots_modal)
				game.decided.emit(true)
			await create_timer(0.05).timeout
	await create_timer(2.0).timeout
	await _shot("07_end")
	print("[DONE] over=", game.engine.over, " turns=", turns, " played=", played)
	quit()
