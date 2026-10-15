extends Control
## Packet Tactics main scene: builds the table UI, runs the engine, and answers human decisions.

const T := preload("res://scripts/pt/pt_theme.gd")
const Defs := preload("res://scripts/pt/pt_defs.gd")
const Card := preload("res://scripts/pt/pt_card.gd")
const CardView := preload("res://scripts/pt/pt_card_view.gd")
const NetPanel := preload("res://scripts/pt/pt_net_panel.gd")
const GameEngine := preload("res://scripts/pt/pt_engine.gd")
const AIBrain := preload("res://scripts/pt/pt_ai.gd")
const HumanBrain := preload("res://scripts/pt/pt_human.gd")
const MenuScript := preload("res://scripts/pt/pt_menu.gd")
const RulesView := preload("res://scripts/pt/pt_rules_view.gd")
const Sfx := preload("res://scripts/pt/pt_sfx.gd")

signal decided(value: Variant)

const MAIN_X := 8.0
const MAIN_W := 884.0
const PANELS_Y := 40.0
const PANELS_H := 426.0
const PROMPT_Y := 470.0
const HAND_Y := 514.0
const SIDE_X := 904.0
const SPEEDS := [1.0, 0.5, 0.12]
const SPEED_NAMES := ["NORMAL", "FAST", "TURBO"]

var engine: RefCounted = null
var cfg: Dictionary = {}
var panels: Array = []
var viewer := 0
var layout_base := 0
var mode := "idle"
var actor := 0
var selected_card: RefCounted = null
var respond_opts: Array = []
var discard_sel: Array = []
var discard_need := 0
var pick_cands: Array = []
var speed_idx := 0
var _gen := 0
var _dirty := true
var _hand_dirty := true
var _game_started := false
var _game_over_shown := false
var _toast_tween: Tween = null

# UI nodes
var game_root: Control
var hand_root: Control
var prompt_label: Label
var prompt_buttons: HBoxContainer
var inspect_view: Control
var inspect_caption: Label
var log_view: RichTextLabel
var stack_root: Control
var toast_label: Label
var phase_label: RichTextLabel
var deck_label: Label
var discard_btn: Button
var speed_btn: Button
var menu: Control
var rules_view: Control
var overlay_root: Control
var curtain: Control
var sfx: Node

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sfx = Sfx.new()
	add_child(sfx)
	_build_game_ui()
	menu = MenuScript.new()
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	menu.start_requested.connect(_on_start_requested)
	menu.rules_requested.connect(func() -> void: _open_rules("rules"))
	menu.resume_requested.connect(_close_menu)
	add_child(menu)
	rules_view = RulesView.new()
	rules_view.process_mode = Node.PROCESS_MODE_ALWAYS
	rules_view.visible = false
	rules_view.closed.connect(_close_rules)
	add_child(rules_view)
	overlay_root = Control.new()
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay_root)
	game_root.visible = false
	var args := OS.get_cmdline_user_args()
	if args.has("--autostart"):
		_on_start_requested({"mode": "ai", "players": 2, "win": 6, "name": "OPERATOR", "seed": 7})

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if rules_view.visible:
			_close_rules()
		elif menu.visible:
			if _game_started and not _game_over_shown:
				_close_menu()
		elif _game_started:
			_open_menu()

# ------------------------------------------------------------------ build

func _build_game_ui() -> void:
	game_root = Control.new()
	game_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game_root)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/pt/bg_circuit.webp")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_root.add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.03, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_root.add_child(shade)
	# top bar
	var top := Panel.new()
	top.position = Vector2(0, 0)
	top.size = Vector2(1280, 36)
	top.add_theme_stylebox_override("panel", T.box(Color(0.01, 0.04, 0.06, 0.92), T.LINE, 1, 0))
	game_root.add_child(top)
	var title := T.make_label("PACKET TACTICS", 18, T.CYAN, "title")
	title.position = Vector2(12, 5)
	game_root.add_child(title)
	deck_label = T.make_label("DECK 0", 13, T.TEXT, "bold")
	deck_label.position = Vector2(210, 9)
	game_root.add_child(deck_label)
	discard_btn = Button.new()
	discard_btn.text = "DISCARD 0"
	discard_btn.position = Vector2(290, 5)
	discard_btn.size = Vector2(104, 26)
	T.style_button(discard_btn, T.TEXT_DIM, 12)
	discard_btn.pressed.connect(_show_discard_pile)
	game_root.add_child(discard_btn)
	phase_label = RichTextLabel.new()
	phase_label.bbcode_enabled = true
	phase_label.scroll_active = false
	phase_label.fit_content = false
	phase_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	phase_label.position = Vector2(410, 8)
	phase_label.size = Vector2(560, 24)
	phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_label.add_theme_font_override("normal_font", T.font("bold"))
	phase_label.add_theme_font_override("bold_font", T.font("bold"))
	phase_label.add_theme_font_size_override("normal_font_size", 13)
	phase_label.add_theme_font_size_override("bold_font_size", 13)
	game_root.add_child(phase_label)
	speed_btn = Button.new()
	speed_btn.position = Vector2(992, 5)
	speed_btn.size = Vector2(110, 26)
	T.style_button(speed_btn, T.CYAN, 12)
	speed_btn.pressed.connect(_cycle_speed)
	game_root.add_child(speed_btn)
	var rules_btn := Button.new()
	rules_btn.text = "RULES"
	rules_btn.position = Vector2(1108, 5)
	rules_btn.size = Vector2(76, 26)
	T.style_button(rules_btn, T.GREEN, 12)
	rules_btn.pressed.connect(func() -> void: _open_rules("rules"))
	game_root.add_child(rules_btn)
	var menu_btn := Button.new()
	menu_btn.text = "MENU"
	menu_btn.position = Vector2(1190, 5)
	menu_btn.size = Vector2(76, 26)
	T.style_button(menu_btn, T.WARN, 12)
	menu_btn.pressed.connect(_open_menu)
	game_root.add_child(menu_btn)
	_update_speed_label()
	# prompt bar
	var bar := Panel.new()
	bar.position = Vector2(MAIN_X, PROMPT_Y)
	bar.size = Vector2(MAIN_W, 40)
	bar.add_theme_stylebox_override("panel", T.box(Color(0.02, 0.07, 0.1, 0.95), T.CYAN_DIM, 1, 8))
	game_root.add_child(bar)
	prompt_label = T.make_label("", 14, T.TEXT, "bold")
	prompt_label.position = Vector2(MAIN_X + 12, PROMPT_Y + 3)
	prompt_label.size = Vector2(480, 34)
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_root.add_child(prompt_label)
	prompt_buttons = HBoxContainer.new()
	prompt_buttons.position = Vector2(MAIN_X + 496, PROMPT_Y + 4)
	prompt_buttons.size = Vector2(MAIN_W - 504, 32)
	prompt_buttons.alignment = BoxContainer.ALIGNMENT_END
	prompt_buttons.add_theme_constant_override("separation", 6)
	game_root.add_child(prompt_buttons)
	# hand
	hand_root = Control.new()
	hand_root.position = Vector2(MAIN_X, HAND_Y)
	hand_root.size = Vector2(MAIN_W, 206)
	hand_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_root.add_child(hand_root)
	# sidebar
	inspect_view = CardView.new()
	inspect_view.setup(Card.new(0, "staging_start", Defs.DEFS["staging_start"]), 244)
	inspect_view.show_flavor = true
	inspect_view.interactive = false
	inspect_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspect_view.position = Vector2(SIDE_X + 62, 44)
	game_root.add_child(inspect_view)
	inspect_caption = T.make_label("", 12, T.TEXT_DIM, "bold")
	inspect_caption.position = Vector2(SIDE_X, 44 + 342)
	inspect_caption.size = Vector2(368, 18)
	inspect_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_root.add_child(inspect_caption)
	var log_panel := Panel.new()
	log_panel.position = Vector2(SIDE_X, 412)
	log_panel.size = Vector2(368, 300)
	log_panel.add_theme_stylebox_override("panel", T.box(Color(0.01, 0.04, 0.06, 0.92), T.LINE, 1, 8))
	game_root.add_child(log_panel)
	var log_title := T.make_label("EVENT LOG", 11, T.CYAN, "bold")
	log_title.position = Vector2(SIDE_X + 10, 416)
	game_root.add_child(log_title)
	log_view = RichTextLabel.new()
	log_view.bbcode_enabled = true
	log_view.scroll_following = true
	log_view.position = Vector2(SIDE_X + 6, 434)
	log_view.size = Vector2(356, 274)
	log_view.add_theme_font_override("normal_font", T.font("regular"))
	log_view.add_theme_font_override("bold_font", T.font("bold"))
	log_view.add_theme_font_size_override("normal_font_size", 12)
	log_view.add_theme_font_size_override("bold_font_size", 12)
	game_root.add_child(log_view)
	# stack + toast
	stack_root = Control.new()
	stack_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack_root.visible = false
	game_root.add_child(stack_root)
	toast_label = T.make_label("", 16, Color.WHITE, "bold")
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.position = Vector2(MAIN_X + 142, PANELS_Y + PANELS_H - 34)
	toast_label.size = Vector2(600, 30)
	toast_label.add_theme_stylebox_override("normal", T.box(Color(0, 0, 0, 0.82), T.CYAN, 1, 8))
	toast_label.modulate.a = 0.0
	game_root.add_child(toast_label)

# ------------------------------------------------------------- game setup

func _on_start_requested(c: Dictionary) -> void:
	_start_game(c)

func _teardown() -> void:
	if engine != null:
		for sig_name in ["changed", "logged", "announced", "stack_changed", "rps_round", "finished"]:
			for conn in engine.get_signal_connection_list(sig_name):
				engine.disconnect(sig_name, conn.callable)
		engine.over = true
	_gen += 1
	decided.emit(null)
	for ov in overlay_root.get_children():
		ov.queue_free()
	for pnl in panels:
		pnl.queue_free()
	panels.clear()
	mode = "idle"
	selected_card = null
	respond_opts = []
	discard_sel = []
	log_view.clear()
	_game_over_shown = false

func _start_game(c: Dictionary) -> void:
	_teardown()
	get_tree().paused = false
	cfg = c
	var n: int = int(c.players)
	var seed_value: int = int(c.seed)
	var humans: int = 1 if c.mode == "ai" else n
	var plist: Array = []
	var brains: Array = []
	var adv_base: int = seed_value % Defs.ADVERSARIES.size()
	for i in n:
		var is_human := i < humans
		var nm := ""
		if is_human:
			nm = String(c.name) if i == 0 else "PLAYER %d" % (i + 1)
		else:
			nm = String(Defs.AI_NAMES[(seed_value / 7 + i) % Defs.AI_NAMES.size()])
		plist.append({"name": nm, "ai": not is_human, "adv": (adv_base + i * 2) % Defs.ADVERSARIES.size()})
		if is_human:
			brains.append(HumanBrain.new(self, i))
		else:
			brains.append(AIBrain.new(i, seed_value))
	engine = GameEngine.new()
	engine.tree = get_tree()
	engine.pace = SPEEDS[speed_idx]
	engine.changed.connect(func() -> void:
		_dirty = true
		_hand_dirty = true)
	engine.logged.connect(_on_logged)
	engine.announced.connect(_on_announced)
	engine.stack_changed.connect(_rebuild_stack)
	engine.rps_round.connect(_on_rps_round)
	engine.finished.connect(_on_finished)
	engine.setup({"players": plist, "win": int(c.win), "seed": seed_value}, brains)
	viewer = -1 if c.mode == "hot" else 0
	layout_base = 0
	_build_panels()
	menu.visible = false
	menu.set_resume_visible(true)
	rules_view.visible = false
	game_root.visible = true
	_game_started = true
	_dirty = true
	_hand_dirty = true
	_set_prompt("", [])
	_toast("Race to %d servers. Good luck, %s." % [int(c.win), plist[0].name])
	_run_engine()

func _run_engine() -> void:
	var e := engine
	await e.run()

func _build_panels() -> void:
	for i in engine.players.size():
		var pnl := NetPanel.new()
		pnl.bind(engine, i, i == viewer)
		pnl.card_picked.connect(_on_net_card)
		pnl.card_hovered.connect(_inspect)
		pnl.header_picked.connect(_on_header_picked)
		game_root.add_child(pnl)
		panels.append(pnl)
	game_root.move_child(stack_root, -1)
	game_root.move_child(toast_label, -1)
	_layout_panels()

func _layout_panels() -> void:
	var n := panels.size()
	if n == 0:
		return
	if viewer >= 0:
		layout_base = viewer
	var order: Array = []
	for k in range(1, n):
		order.append((layout_base + k) % n)
	order.append(layout_base)
	var gap := 6.0
	var h := (PANELS_H - gap * (n - 1)) / n
	for i in n:
		var pnl: Control = panels[order[i]]
		pnl.position = Vector2(MAIN_X, PANELS_Y + i * (h + gap))
		pnl.size = Vector2(MAIN_W, h)
		pnl.is_self = (order[i] == viewer)
		pnl.mark_dirty()

# ------------------------------------------------------------ frame update

func _process(_delta: float) -> void:
	if engine == null or not _game_started:
		return
	if _dirty:
		_dirty = false
		_update_top()
		for pnl in panels:
			pnl.mark_dirty()
		if mode == "idle":
			_idle_prompt()
	if _hand_dirty:
		_hand_dirty = false
		_refresh_hand()

func _update_top() -> void:
	deck_label.text = "DECK %d" % engine.deck.size()
	discard_btn.text = "DISCARD %d" % engine.discard.size()
	var cur: Dictionary = engine.players[engine.current]
	var phases := {"begin": "BEGIN", "draw": "DRAW", "main": "ACT", "discard": "DISCARD"}
	var parts: Array = []
	for ph: String in ["begin", "draw", "main", "discard"]:
		if engine.phase == ph and not engine.over:
			parts.append("[color=#3dff8e][b]%s[/b][/color]" % phases[ph])
		else:
			parts.append("[color=#4b6674]%s[/color]" % phases[ph])
	phase_label.text = "[color=#27d3f5][b]TURN %d[/b][/color]  %s   %s" % [engine.turn_number + 1, String(cur.name), "  >  ".join(parts)]

func _idle_prompt() -> void:
	if engine.over:
		_set_prompt("Game over.", [])
		return
	var cur: Dictionary = engine.players[engine.current]
	var who := "Your" if (cfg.mode == "ai" and engine.current == 0) else "%s's" % cur.name
	var dots := ".".repeat(1 + int(Time.get_ticks_msec() / 400) % 3)
	if cur.ai:
		_set_prompt("%s is running their turn%s" % [cur.name, dots], [])
	else:
		_set_prompt("%s turn - %s" % [who, String(engine.phase).to_upper()], [])

func _update_speed_label() -> void:
	speed_btn.text = "SPEED: " + SPEED_NAMES[speed_idx]

func _cycle_speed() -> void:
	speed_idx = (speed_idx + 1) % SPEEDS.size()
	_update_speed_label()
	if engine != null:
		engine.pace = SPEEDS[speed_idx]

# ----------------------------------------------------------- prompt / hand

func _set_prompt(text: String, buttons: Array) -> void:
	prompt_label.text = text
	for old in prompt_buttons.get_children():
		prompt_buttons.remove_child(old)
		old.queue_free()
	for def_btn in buttons:
		var b := Button.new()
		b.text = String(def_btn.text)
		b.custom_minimum_size = Vector2(0, 30)
		T.style_button(b, def_btn.get("accent", T.CYAN), 13)
		b.disabled = bool(def_btn.get("disabled", false))
		var val: Variant = def_btn.value
		b.pressed.connect(func() -> void: decided.emit(val))
		prompt_buttons.add_child(b)

func _refresh_hand() -> void:
	for c in hand_root.get_children():
		c.queue_free()
	if engine == null or viewer < 0 or viewer >= engine.players.size():
		return
	var p: Dictionary = engine.players[viewer]
	var n: int = p.hand.size()
	if n == 0:
		return
	var cw := 128.0 if n <= 8 else (116.0 if n <= 11 else 104.0)
	var ch := cw * CardView.DESIGN.y / CardView.DESIGN.x
	var step := cw + 8.0
	if n > 1:
		step = minf(step, (MAIN_W - 16.0 - cw) / (n - 1))
	var total := step * (n - 1) + cw
	var x0 := (MAIN_W - total) * 0.5
	for i in n:
		var card: RefCounted = p.hand[i]
		var v := CardView.new()
		v.setup(card, cw)
		var raised := false
		match mode:
			"main":
				if viewer == actor:
					if engine.can_play(p, card):
						v.glow = T.GREEN
					elif card.type() != "zd":
						v.dim = true
			"selected":
				v.selected = (card == selected_card)
				raised = v.selected
				v.dim = (card != selected_card)
			"discard":
				v.selected = discard_sel.has(card)
				raised = v.selected
			"respond":
				if respond_opts.has(card):
					v.glow = T.VIOLET
				else:
					v.dim = true
		v.position = Vector2(x0 + i * step, 22.0 - (16.0 if raised else 0.0))
		v.pressed.connect(_on_hand_card)
		v.hovered.connect(func(view: Control, on: bool) -> void:
			if on:
				_inspect(view.card))
		hand_root.add_child(v)

func _on_hand_card(view: Control) -> void:
	var card: RefCounted = view.card
	_inspect(card)
	sfx.play("click")
	var p: Dictionary = engine.players[viewer]
	match mode:
		"main", "selected":
			if viewer != actor:
				return
			if engine.can_play(p, card):
				decided.emit({"t": "card", "card": card})
			else:
				_toast(_why_not(p, card), T.WARN)
		"discard":
			if discard_sel.has(card):
				discard_sel.erase(card)
			else:
				if discard_sel.size() >= discard_need:
					discard_sel.pop_front()
				discard_sel.append(card)
			_refresh_discard_bar()
			_hand_dirty = true
		"respond":
			if respond_opts.has(card):
				decided.emit({"t": "zd", "card": card})
			else:
				_toast("That card can't answer right now.", T.WARN)

func _why_not(p: Dictionary, card: RefCounted) -> String:
	var m: Dictionary = engine.mods(p)
	match card.type():
		"zd":
			return "0DAY: hold it, then play it when another card is played."
		"prod", "stage":
			return "Your network is full."
		"soft":
			if m.get("no_soft", false):
				return "Poisoned Package: you can't play Software."
			return "No Server in your network can take Software (each needs to be free of Malware)."
		"mal":
			return "No Server can accept Malware right now (Antivirus Suite protects its owner)."
		"exploit":
			if m.get("no_exploit", false):
				return "Rootkit: you can't play Exploits."
			if card.key == "clean_sweep":
				return "There is no Malware in your network to purge."
			return "No valid target for this Exploit right now."
	return "You can't play that now."

func _inspect(card: RefCounted) -> void:
	if card == null:
		return
	inspect_view.card = card
	inspect_view.queue_redraw()
	var cap := ""
	if engine != null:
		var ref: Dictionary = engine.locate(card)
		if not ref.is_empty():
			cap = "In %s's NETWORK" % engine.pname(int(ref.p))
		elif engine.discard.has(card):
			cap = "In the DISCARD pile"
		else:
			for p: Dictionary in engine.players:
				if p.hand.has(card):
					cap = "In %s's HAND" % p.name
	inspect_caption.text = cap

func _on_header_picked(seat: int) -> void:
	if mode == "pick_player" and pick_cands.has(seat):
		decided.emit({"seat": seat})

func _on_net_card(card: RefCounted) -> void:
	_inspect(card)
	if mode == "pick":
		if pick_cands.has(card):
			decided.emit({"card": card})
		else:
			_toast("Not a valid target for this effect.", T.WARN)

func _apply_highlights(cards: Array, players_hl: Array = []) -> void:
	var hl := {}
	for c in cards:
		hl[c] = T.GREEN
	for pnl in panels:
		pnl.set_highlights(hl, T.VIOLET if players_hl.has(pnl.seat) else Color(0, 0, 0, 0))

func _clear_highlights() -> void:
	_apply_highlights([], [])

# ------------------------------------------------------------ toasts / log

func _toast(text: String, color: Color = T.CYAN) -> void:
	if color == T.WARN:
		sfx.play("warn")
	toast_label.text = text
	toast_label.add_theme_stylebox_override("normal", T.box(Color(0, 0, 0, 0.85), color, 1, 8))
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)

const LOG_COLORS := {
	"turn": "#27d3f5", "play": "#e6f7fb", "zd": "#c77dff", "draw": "#7fa3b1", "discard": "#ffb21f",
	"delete": "#ff5a3c", "steal": "#ff8a3c", "install": "#3dff8e", "warn": "#ffb21f", "sys": "#27d3f5", "info": "#a9c4cf",
}

func _on_logged(text: String, kind: String) -> void:
	var col: String = LOG_COLORS.get(kind, "#a9c4cf")
	var line := "[color=%s]%s[/color]" % [col, text.replace("[", "(").replace("]", ")")]
	if kind == "turn":
		line = "\n[b]" + line + "[/b]"
	log_view.append_text(line + "\n")

func _on_announced(seat: int, card: RefCounted, note: String) -> void:
	_inspect(card)
	var verb := "installs" if note == "installed" else ("moves" if note == "moved" else ("answers with" if note == "0DAY" else "plays"))
	var col: Color = T.type_color(String(card.def.type))
	sfx.play("zd" if note == "0DAY" or card.type() == "zd" else ("install" if note == "installed" else "play"))
	_toast("%s %s %s" % [engine.pname(seat), verb, card.title()], col)

func _on_rps_round(a: int, b: int, ca: int, cb: int, result: String) -> void:
	var names := ["ROCK", "PAPER", "SCISSORS"]
	var tail := "DRAW - again!" if result == "draw" else ("%s takes the round" % engine.pname(a if result == "a" else b))
	_toast("%s: %s   vs   %s: %s  -  %s" % [engine.pname(a), names[ca], engine.pname(b), names[cb], tail], T.WARN)

# ---------------------------------------------------------------- stack

func _rebuild_stack() -> void:
	for c in stack_root.get_children():
		c.queue_free()
	if engine == null or engine.stack.is_empty():
		stack_root.visible = false
		return
	stack_root.visible = true
	var n: int = engine.stack.size()
	var cw := 96.0
	var ch := cw * CardView.DESIGN.y / CardView.DESIGN.x
	var w := minf(MAIN_W - 40.0, n * (cw + 12.0) + 28.0)
	var h := ch + 54.0
	var origin := Vector2(MAIN_X + (MAIN_W - w) * 0.5, PANELS_Y + (PANELS_H - h) * 0.5 - 20.0)
	var bgp := Panel.new()
	bgp.position = origin
	bgp.size = Vector2(w, h)
	bgp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bgp.add_theme_stylebox_override("panel", T.box(Color(0.02, 0.05, 0.08, 0.93), T.VIOLET, 2, 12))
	stack_root.add_child(bgp)
	var t := T.make_label("CARD STACK - newest resolves first", 11, T.VIOLET, "bold")
	t.position = origin + Vector2(12, 4)
	stack_root.add_child(t)
	var step: float = minf(cw + 12.0, (w - 28.0 - cw) / maxf(1.0, n - 1))
	for i in n:
		var item: Dictionary = engine.stack[i]
		var v := CardView.new()
		v.setup(item.card, cw)
		v.interactive = false
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.position = origin + Vector2(14 + i * step, 24)
		if item.state == "cancelled":
			v.dim = true
			v.badge = "CANCELLED"
		elif item.state == "rooted":
			v.dim = true
			v.badge = "BLOCKED"
		stack_root.add_child(v)
		var who := T.make_label(engine.pname(int(item.owner)), 10, T.TEXT, "bold")
		who.position = origin + Vector2(14 + i * step + 2, 24 + ch + 2)
		stack_root.add_child(who)

# ------------------------------------------------------ overlays / menu

func _open_menu() -> void:
	if not _game_started:
		return
	menu.visible = true
	menu.set_resume_visible(not _game_over_shown)
	get_tree().paused = true

func _close_menu() -> void:
	menu.visible = false
	get_tree().paused = false

func _open_rules(tab: String) -> void:
	rules_view.open(tab)
	if _game_started:
		get_tree().paused = true

func _close_rules() -> void:
	rules_view.visible = false
	if _game_started and not menu.visible:
		get_tree().paused = false

func _show_discard_pile() -> void:
	if engine == null or engine.discard.is_empty():
		_toast("The discard pile is empty.", T.TEXT_DIM)
		return
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.02, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(110, 50)
	panel.size = Vector2(1060, 620)
	panel.add_theme_stylebox_override("panel", T.box(Color(T.PANEL, 0.98), T.CYAN, 2, 12))
	ov.add_child(panel)
	var t := T.make_label("DISCARD PILE (%d cards, newest first)" % engine.discard.size(), 20, T.CYAN, "title")
	t.position = Vector2(136, 62)
	ov.add_child(t)
	var close := Button.new()
	close.text = "CLOSE"
	close.position = Vector2(1040, 60)
	close.size = Vector2(110, 32)
	T.style_button(close, T.WARN)
	close.pressed.connect(func() -> void: ov.queue_free())
	ov.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(130, 104)
	scroll.size = Vector2(1020, 550)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ov.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var count := 0
	for i in range(engine.discard.size() - 1, -1, -1):
		var v := CardView.new()
		v.setup(engine.discard[i], 118)
		v.interactive = false
		grid.add_child(v)
		count += 1
		if count >= 96:
			break
	overlay_root.add_child(ov)

# --------------------------------------------------------- game over

func _on_finished(res: Dictionary) -> void:
	_game_over_shown = true
	mode = "idle"
	_clear_highlights()
	_set_prompt("Game over.", [])
	await get_tree().create_timer(1.2).timeout
	if engine == null or not engine.over:
		return
	_show_game_over(res)

func _show_game_over(res: Dictionary) -> void:
	var winner: int = int(res.winner)
	var human_win: bool = cfg.mode == "ai" and winner == 0
	sfx.play("win" if (human_win or cfg.mode != "ai") else "lose")
	var headline := "NETWORK SECURED" if human_win else ("BREACHED" if cfg.mode == "ai" else "%s WINS" % engine.pname(winner))
	var col: Color = T.GREEN if (human_win or cfg.mode != "ai") else T.RED
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.02, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(320, 120)
	panel.size = Vector2(640, 440)
	panel.add_theme_stylebox_override("panel", T.box(Color(T.PANEL, 0.97), col, 3, 14))
	ov.add_child(panel)
	var h := T.make_label(headline, 44, col, "title")
	h.position = Vector2(320, 140)
	h.size = Vector2(640, 60)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(h)
	var sub := T.make_label("%s wins. %s" % [engine.pname(winner), res.reason], 16, T.TEXT, "bold")
	sub.position = Vector2(350, 210)
	sub.size = Vector2(580, 50)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(sub)
	var yy := 276.0
	var cols := [370.0, 590.0, 690.0, 790.0]
	var heads := ["PLAYER", "SERVERS", "MALWARE", "SOFTWARE"]
	for i in 4:
		var hl := T.make_label(heads[i], 13, T.TEXT_DIM, "bold")
		hl.position = Vector2(cols[i], yy)
		ov.add_child(hl)
	yy += 28.0
	for row: Dictionary in res.standings:
		var win_row: bool = int(row.seat) == winner
		var vals := [engine.pname(int(row.seat)), str(int(row.servers)), str(int(row.malware)), str(int(row.software))]
		for i in 4:
			var cl := T.make_label(String(vals[i]), 16, T.GREEN if win_row else T.TEXT, "bold")
			cl.position = Vector2(cols[i], yy)
			ov.add_child(cl)
		yy += 26.0
	var again := Button.new()
	again.text = "PLAY AGAIN"
	again.position = Vector2(350, 470)
	again.size = Vector2(180, 44)
	T.style_button(again, T.GREEN, 17)
	again.pressed.connect(func() -> void:
		var c := cfg.duplicate()
		c.seed = int(Time.get_ticks_usec() % 2000000000)
		_start_game(c))
	ov.add_child(again)
	var board := Button.new()
	board.text = "VIEW BOARD"
	board.position = Vector2(550, 470)
	board.size = Vector2(170, 44)
	T.style_button(board, T.CYAN, 17)
	board.pressed.connect(func() -> void: ov.queue_free())
	ov.add_child(board)
	var back := Button.new()
	back.text = "MAIN MENU"
	back.position = Vector2(740, 470)
	back.size = Vector2(170, 44)
	T.style_button(back, T.WARN, 17)
	back.pressed.connect(func() -> void:
		ov.queue_free()
		_open_menu())
	ov.add_child(back)
	overlay_root.add_child(ov)

# ================================================================ HUMAN INPUT

func _ensure_viewer(seat: int) -> void:
	actor = seat
	if cfg.mode != "hot":
		viewer = 0
		return
	if viewer == seat:
		return
	var gen := _gen
	viewer = -1
	_hand_dirty = true
	_layout_panels()
	var cv := Control.new()
	cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cv.mouse_filter = Control.MOUSE_FILTER_STOP
	var bgc := ColorRect.new()
	bgc.color = Color(0.01, 0.03, 0.05, 1.0)
	bgc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cv.add_child(bgc)
	var t1 := T.make_label("PASS THE DEVICE TO", 22, T.TEXT_DIM, "bold")
	t1.position = Vector2(0, 230)
	t1.size = Vector2(1280, 30)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(t1)
	var t2 := T.make_label(engine.pname(seat), 72, T.CYAN, "title")
	t2.position = Vector2(0, 264)
	t2.size = Vector2(1280, 90)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(t2)
	var t3 := T.make_label("Everyone else look away - this player's hand is private.", 16, T.TEXT_DIM)
	t3.position = Vector2(0, 360)
	t3.size = Vector2(1280, 24)
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(t3)
	var go := Button.new()
	go.text = "I AM %s - SHOW MY HAND" % engine.pname(seat)
	go.position = Vector2(440, 410)
	go.size = Vector2(400, 54)
	T.style_button(go, T.GREEN, 18)
	go.pressed.connect(func() -> void: decided.emit({"t": "ready"}))
	cv.add_child(go)
	overlay_root.add_child(cv)
	await decided
	cv.queue_free()
	if gen != _gen:
		return
	viewer = seat
	_layout_panels()
	_hand_dirty = true
	_dirty = true

func h_main(e: RefCounted, p: Dictionary, first: bool) -> Dictionary:
	var gen := _gen
	await _ensure_viewer(p.seat)
	if gen != _gen:
		return {"kind": "draw"}
	while true:
		mode = "main"
		selected_card = null
		_clear_highlights()
		var btns: Array = [{"text": "DRAW A CARD", "value": {"t": "draw"}, "accent": T.CYAN}]
		if not first:
			btns.append({"text": "END TURN", "value": {"t": "end"}, "accent": T.WARN})
		var left: int = p.actions_left
		_set_prompt("%s: play one card (%d play%s left) or draw." % [p.name, left, "" if left == 1 else "s"], btns)
		_hand_dirty = true
		var v: Variant = await decided
		if gen != _gen:
			return {"kind": "draw"}
		if v == null or not (v is Dictionary):
			continue
		match String(v.t):
			"draw":
				mode = "idle"
				_hand_dirty = true
				return {"kind": "draw"}
			"end":
				mode = "idle"
				_hand_dirty = true
				return {"kind": "end"}
			"card":
				var r: Variant = await _play_flow(e, p, v.card, gen)
				if gen != _gen:
					return {"kind": "draw"}
				if r != null:
					mode = "idle"
					_clear_highlights()
					_hand_dirty = true
					return r
	return {"kind": "draw"}

func _play_flow(e: RefCounted, p: Dictionary, card: RefCounted, gen: int) -> Variant:
	var current: RefCounted = card
	while true:
		selected_card = current
		mode = "selected"
		_hand_dirty = true
		_inspect(current)
		var needs: bool = not e.spec_for(current).is_empty()
		var verb := "PLAY" if current.type() != "zd" else "PLAY 0DAY"
		_set_prompt("%s: %s" % [current.title(), "you will choose targets next." if needs else "ready to play."], [
			{"text": "%s  %s" % [verb, current.title().to_upper()], "value": {"t": "go"}, "accent": T.GREEN},
			{"text": "CANCEL", "value": {"t": "cancel"}, "accent": T.WARN},
		])
		var v: Variant = await decided
		if gen != _gen:
			return null
		if v == null or not (v is Dictionary):
			continue
		match String(v.t):
			"cancel":
				return null
			"card":
				current = v.card
				continue
			"go":
				var targets := {}
				var ok := true
				while true:
					var s: Dictionary = e.next_spec(current, targets)
					if s.is_empty():
						break
					var ch: Array = e.choices_for(p, current, s, targets)
					if ch.is_empty():
						if s.get("optional", false):
							targets[s.id] = null
							continue
						_toast("No valid target.", T.WARN)
						ok = false
						break
					var pick: Variant = await _target_pick(e, s, ch)
					if gen != _gen:
						return null
					if pick == null or pick.has("cancel"):
						ok = false
						break
					targets[s.id] = null if pick.has("skip") else (pick.seat if pick.has("seat") else pick.card)
				_clear_highlights()
				if not ok:
					continue
				return {"kind": "zd" if current.type() == "zd" else "play", "card": current, "targets": targets}
	return null

func _target_pick(e: RefCounted, s: Dictionary, ch: Array) -> Variant:
	var btns: Array = [{"text": "CANCEL", "value": {"cancel": true}, "accent": T.WARN}]
	if s.get("optional", false):
		btns.push_front({"text": "SKIP", "value": {"skip": true}, "accent": T.CYAN})
	if String(s.kind) == "player":
		mode = "pick_player"
		pick_cands = ch
		_apply_highlights([], ch)
		for seat in ch:
			btns.push_front({"text": String(e.pname(int(seat))), "value": {"seat": int(seat)}, "accent": T.VIOLET})
		_set_prompt(String(s.prompt), btns)
	else:
		mode = "pick"
		pick_cands = ch
		_apply_highlights(ch)
		_set_prompt("%s - click a highlighted card." % String(s.prompt), btns)
	var v: Variant = await decided
	_clear_highlights()
	return v if v is Dictionary else null

func h_response(e: RefCounted, p: Dictionary, opts: Array) -> Variant:
	var gen := _gen
	await _ensure_viewer(p.seat)
	if gen != _gen:
		return null
	mode = "respond"
	respond_opts = opts
	var top: Dictionary = e.stack.back()
	var btns: Array = []
	var seen := {}
	for c in opts:
		var cc: RefCounted = c
		if seen.has(cc.key):
			continue
		seen[cc.key] = true
		btns.append({"text": "PLAY " + cc.title().to_upper(), "value": {"t": "zd", "card": cc}, "accent": T.VIOLET})
	btns.append({"text": "PASS", "value": {"t": "pass"}, "accent": T.CYAN})
	var desc: String = "%s played %s." % [e.pname(int(top.owner)), top.card.title()]
	_set_prompt("%s %s, answer with a 0DAY?" % [desc, p.name], btns)
	_hand_dirty = true
	var v: Variant = await decided
	mode = "idle"
	respond_opts = []
	_hand_dirty = true
	if gen != _gen or v == null or not (v is Dictionary):
		return null
	if String(v.t) == "zd":
		return v.card
	return null

func h_discard(e: RefCounted, p: Dictionary, n: int, why: String) -> Array:
	var gen := _gen
	await _ensure_viewer(p.seat)
	if gen != _gen:
		return []
	if n >= p.hand.size():
		_toast("You must discard your whole hand.", T.WARN)
		return p.hand.duplicate()
	mode = "discard"
	discard_sel = []
	discard_need = n
	_hand_dirty = true
	_refresh_discard_bar(why)
	while true:
		var v: Variant = await decided
		if gen != _gen:
			return []
		if v is Dictionary and String(v.get("t", "")) == "confirm" and discard_sel.size() == discard_need:
			break
	var out := discard_sel.duplicate()
	mode = "idle"
	discard_sel = []
	_hand_dirty = true
	return out

var _discard_why := ""

func _refresh_discard_bar(why := "") -> void:
	if why != "":
		_discard_why = why
	var left := discard_need - discard_sel.size()
	var txt := "%s: choose %d card%s to DISCARD (%d more)." % [_discard_why, discard_need, "" if discard_need == 1 else "s", left] if left > 0 else "%s: ready to discard." % _discard_why
	_set_prompt(txt, [{"text": "CONFIRM DISCARD", "value": {"t": "confirm"}, "accent": T.RED, "disabled": left != 0}])

func h_pick_card(e: RefCounted, p: Dictionary, cands: Array, _purpose: String, prompt: String) -> Variant:
	var gen := _gen
	await _ensure_viewer(p.seat)
	if gen != _gen:
		return cands[0]
	if cands.size() == 1:
		_toast("Only one choice: %s" % cands[0].title(), T.CYAN)
		_inspect(cands[0])
		return cands[0]
	mode = "pick"
	pick_cands = cands
	_apply_highlights(cands)
	_set_prompt("%s - click a highlighted card." % prompt, [])
	var v: Variant = await decided
	_clear_highlights()
	mode = "idle"
	if gen != _gen or v == null or not (v is Dictionary) or not v.has("card"):
		return cands[0]
	return v.card

func _modal(title: String, body: String, buttons: Array, accent: Color = T.CYAN) -> Variant:
	var ov := Control.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.02, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(340, 240)
	panel.size = Vector2(600, 220)
	panel.add_theme_stylebox_override("panel", T.box(Color(T.PANEL, 0.98), accent, 2, 12))
	ov.add_child(panel)
	var t := T.make_label(title, 22, accent, "title")
	t.position = Vector2(360, 254)
	t.size = Vector2(560, 30)
	ov.add_child(t)
	var b := T.make_label(body, 16, T.TEXT)
	b.position = Vector2(360, 292)
	b.size = Vector2(560, 80)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ov.add_child(b)
	var row := HBoxContainer.new()
	row.position = Vector2(360, 390)
	row.size = Vector2(560, 48)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	ov.add_child(row)
	for def_btn in buttons:
		var btn := Button.new()
		btn.text = String(def_btn.text)
		btn.custom_minimum_size = Vector2(150, 44)
		T.style_button(btn, def_btn.get("accent", T.CYAN), 16)
		var val: Variant = def_btn.value
		btn.pressed.connect(func() -> void: decided.emit(val))
		row.add_child(btn)
	overlay_root.add_child(ov)
	var v: Variant = await decided
	ov.queue_free()
	return v

func h_yes_no(e: RefCounted, p: Dictionary, prompt: String, src) -> bool:
	var gen := _gen
	await _ensure_viewer(p.seat)
	if gen != _gen:
		return false
	if src != null:
		_inspect(src)
	var v: Variant = await _modal("OPTIONAL EFFECT", prompt, [
		{"text": "YES", "value": true, "accent": T.GREEN}, {"text": "NO", "value": false, "accent": T.WARN}])
	if gen != _gen:
		return false
	return bool(v) if v != null else false

func h_option(e: RefCounted, p: Dictionary, prompt: String, options: Array) -> int:
	var gen := _gen
	await _ensure_viewer(p.seat)
	if gen != _gen:
		return 0
	var btns: Array = []
	for i in options.size():
		btns.append({"text": String(options[i]).to_upper(), "value": i, "accent": T.VIOLET})
	var v: Variant = await _modal("CHOOSE", prompt, btns, T.VIOLET)
	if gen != _gen or v == null:
		return 0
	return int(v)

func h_rps(e: RefCounted, p: Dictionary, vs_name: String) -> int:
	var gen := _gen
	await _ensure_viewer(p.seat)
	if gen != _gen:
		return 0
	var v: Variant = await _modal("TIEBREAKER: ROCK PAPER SCISSORS", "%s, throw against %s. First to win two rounds takes the game." % [p.name, vs_name], [
		{"text": "ROCK", "value": 0, "accent": T.CYAN}, {"text": "PAPER", "value": 1, "accent": T.GREEN}, {"text": "SCISSORS", "value": 2, "accent": T.WARN}], T.WARN)
	if gen != _gen or v == null:
		return 0
	return int(v)
