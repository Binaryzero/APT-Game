extends SceneTree
## Headless layout check: the UI must adapt to every window size with no letterbox math.
## Run: godot --headless --path . --script res://test/pt_layout_test.gd

const PtLayout := preload("res://scripts/pt/pt_layout.gd")
const GameUI := preload("res://scripts/pt/pt_game.gd")

const SIZES := [
	Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440),
	Vector2i(3440, 1440), Vector2i(1920, 1200), Vector2i(1280, 800), Vector2i(1024, 640),
]

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(msg: String) -> void:
	failures.append(msg)
	push_error("PT_LAYOUT_FAIL: " + msg)

func _run() -> void:
	# 1. Pure metrics invariants at every size. Under stretch aspect "expand" the engine
	# keeps a uniform scale and grows the viewport along the excess axis, so derive the
	# design viewport the same way before checking.
	for s in SIZES:
		var scale := minf(float(s.x) / PtLayout.DESIGN.x, float(s.y) / PtLayout.DESIGN.y)
		var vp := Vector2(s) / scale
		var l: Dictionary = PtLayout.metrics(vp)
		if l.panels_h < 240.0:
			_fail("metrics panels_h < 240 at %s" % s)
		if l.hand_y + PtLayout.HAND_H > vp.y + 0.5:
			_fail("metrics hand exceeds viewport at %s" % s)
		if l.side_x + PtLayout.SIDE_W > vp.x + 0.5:
			_fail("metrics sidebar exceeds viewport at %s" % s)
		if l.main_x < PtLayout.MARGIN - 0.01 or l.main_x + l.main_w > l.side_x - 12.0 + 0.01:
			_fail("metrics main column outside its span at %s" % s)
		if l.prompt_y + PtLayout.PROMPT_H > l.hand_y + 0.01:
			_fail("metrics prompt overlaps hand at %s" % s)
	print("PT_LAYOUT metrics invariants ok for %d sizes" % SIZES.size())

	# 2. Live UI at every size: resize the window and let the layout pass react.
	var game: Control = GameUI.new()
	root.add_child(game)
	await process_frame
	var menu: Control = game.get("menu")
	var rules: Control = game.get("rules_view")
	var seen_vp: Array = []
	for s in SIZES:
		root.size = Vector2(s)
		await process_frame
		await process_frame
		var vp: Vector2 = game.get_viewport_rect().size
		seen_vp.append(vp)
		var top: Control = game.get("_top_panel")
		if absf(top.size.x - vp.x) > 0.5:
			_fail("top bar width %s != viewport %s at %s" % [top.size.x, vp.x, s])
		var hand: Control = game.get("hand_root")
		if hand.position.y + hand.size.y > vp.y + 0.5:
			_fail("hand row exceeds viewport at %s" % s)
		var log: Control = game.get("log_view")
		if log.position.y + log.size.y > vp.y + 0.5:
			_fail("log exceeds viewport at %s" % s)
		var speed: Control = game.get("speed_btn")
		if speed.position.x + speed.size.x > vp.x + 0.5:
			_fail("speed button exceeds viewport at %s" % s)
		var menu_btn: Control = game.get("menu_btn")
		if absf(menu_btn.position.x + menu_btn.size.x - (vp.x - 8.0)) > 0.5:
			_fail("menu button not flush to right margin at %s" % s)
		var rules_panel: Control = rules.get("_panel")
		var rcenter: Vector2 = rules_panel.position + rules_panel.size * 0.5
		if absf(rcenter.x - vp.x * 0.5) > 1.0 or absf(rcenter.y - vp.y * 0.5) > 1.0:
			_fail("rules panel not centered at %s" % s)
		var mtitle: Control = menu.get_child(2)
		if absf(mtitle.size.x - vp.x) > 0.5:
			_fail("menu title width %s != viewport %s at %s" % [mtitle.size.x, vp.x, s])
		print("PT_LAYOUT %dx%d -> vp %dx%d ok" % [s.x, s.y, int(vp.x), int(vp.y)])
	var distinct := {}
	for vp: Vector2 in seen_vp:
		distinct[vp] = true
	if distinct.size() < 3:
		_fail("window resize had no effect in this environment (vps seen: %s)" % [seen_vp])
	if failures.is_empty():
		print("PT_LAYOUT_TEST_OK sizes=%d" % SIZES.size())
		quit()
	else:
		print("PT_LAYOUT_TEST_FAILED count=%d" % failures.size())
		quit(1)