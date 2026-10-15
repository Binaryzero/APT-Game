extends SceneTree
## Captures rules, codex and hot-seat curtain screens.

var game: Node
var out_dir := "/tmp/pt_caps2"

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	root.get_texture().get_image().save_png(out_dir + "/" + name + ".png")
	print("[SHOT] ", name)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://scenes/packet_tactics.tscn")
	game = scene.instantiate()
	root.add_child(game)
	await create_timer(0.8).timeout
	game._open_rules("rules")
	await create_timer(0.3).timeout
	await _shot("10_rules")
	game.rules_view.open("codex")
	await create_timer(0.5).timeout
	await _shot("11_codex")
	game._close_rules()
	game._on_start_requested({"mode": "hot", "players": 3, "win": 6, "name": "ALICE", "seed": 5})
	game.engine.pace = 0.02
	await create_timer(1.5).timeout
	await _shot("12_hot_start")
	game.decided.emit({"t": "ready"})
	await create_timer(0.5).timeout
	await _shot("13_hot_hand")
	game.decided.emit({"t": "draw"})
	await create_timer(1.5).timeout
	await _shot("14_hot_curtain2")
	print("[DONE2]")
	quit()
