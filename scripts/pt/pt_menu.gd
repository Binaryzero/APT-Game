extends Control
## Start screen: mode, opponents, server goal, handle. Emits a config dictionary for the game.

const T := preload("res://scripts/pt/pt_theme.gd")
const Defs := preload("res://scripts/pt/pt_defs.gd")

signal start_requested(cfg: Dictionary)
signal rules_requested
signal resume_requested

var mode := "ai"
var count := 2
var goal := 6
var _count_row: HBoxContainer
var _count_label: Label
var _name_edit: LineEdit
var _resume_btn: Button
var _mode_btns: Array = []
var _count_btns: Array = []
var _goal_btns: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := TextureRect.new()
	bg.texture = load("res://assets/pt/bg_circuit.webp")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.03, 0.05, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var title := T.make_label("PACKET TACTICS", 48, T.CYAN, "title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 48.0
	title.offset_bottom = 122.0
	add_child(title)
	var sub := T.make_label("BUILD YOUR NETWORK.  INSTALL.  EXPLOIT.  ANSWER WITH A 0DAY.", 13, T.GREEN, "bold")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 132.0
	sub.offset_bottom = 156.0
	add_child(sub)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -300.0
	panel.offset_right = 300.0
	panel.offset_top = -212.0
	panel.offset_bottom = 212.0
	var sb := T.box(Color(T.PANEL, 0.94), T.CYAN, 2, 14)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 24.0
	sb.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_section_label("MODE"))
	_mode_btns = _segment(box, [["VS AI OPPONENTS", "ai"], ["HOT SEAT (SAME DEVICE)", "hot"]], mode, func(v: Variant) -> void:
		mode = String(v)
		_refresh_counts())
	_count_label = _section_label("OPPONENTS")
	box.add_child(_count_label)
	_count_row = HBoxContainer.new()
	_count_row.add_theme_constant_override("separation", 8)
	box.add_child(_count_row)
	box.add_child(_section_label("SERVERS TO WIN"))
	_goal_btns = _segment(box, [["5  SHORT", 5], ["6  STANDARD", 6], ["7  LONG", 7]], goal, func(v: Variant) -> void: goal = int(v))
	box.add_child(_section_label("YOUR HANDLE"))
	_name_edit = LineEdit.new()
	_name_edit.text = "OPERATOR"
	_name_edit.max_length = 14
	_name_edit.custom_minimum_size = Vector2(0, 34)
	_name_edit.add_theme_font_override("font", T.font("bold"))
	_name_edit.add_theme_font_size_override("font_size", 14)
	_name_edit.add_theme_stylebox_override("normal", T.box(Color(0, 0, 0, 0.5), T.CYAN_DIM, 1, 6))
	_name_edit.add_theme_stylebox_override("focus", T.box(Color(0, 0, 0, 0.5), T.GREEN, 2, 6))
	box.add_child(_name_edit)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	box.add_child(spacer)
	var start := Button.new()
	start.text = "START GAME"
	start.custom_minimum_size = Vector2(0, 44)
	T.style_button(start, T.GREEN, 18)
	start.pressed.connect(_on_start)
	box.add_child(start)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var how := Button.new()
	how.text = "HOW TO PLAY  /  CARD CODEX"
	how.custom_minimum_size = Vector2(0, 34)
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	T.style_button(how, T.CYAN, 13)
	how.pressed.connect(func() -> void: rules_requested.emit())
	row.add_child(how)
	_resume_btn = Button.new()
	_resume_btn.text = "RESUME GAME"
	_resume_btn.custom_minimum_size = Vector2(0, 34)
	_resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	T.style_button(_resume_btn, T.WARN, 13)
	_resume_btn.pressed.connect(func() -> void: resume_requested.emit())
	_resume_btn.visible = false
	row.add_child(_resume_btn)
	var foot := T.make_label("An original card game inspired by network security. Hands are private. First to the server goal wins.", 12, T.TEXT_DIM)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -38.0
	foot.offset_bottom = -18.0
	add_child(foot)
	_refresh_counts()

func set_resume_visible(v: bool) -> void:
	_resume_btn.visible = v

func _section_label(text: String) -> Label:
	return T.make_label(text, 12, T.TEXT_DIM, "bold")

func _segment(parent: Control, options: Array, current: Variant, on_change: Callable) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var btns: Array = []
	for opt in options:
		var b := Button.new()
		b.text = String(opt[0])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		T.style_button(b, T.CYAN, 13)
		b.add_theme_stylebox_override("pressed", T.box(Color(T.GREEN, 0.28), T.GREEN, 2, 6))
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.button_pressed = opt[1] == current
		var val: Variant = opt[1]
		b.pressed.connect(func() -> void:
			for other: Button in btns:
				other.button_pressed = (other == b)
			on_change.call(val))
		row.add_child(b)
		btns.append(b)
	return btns

func _refresh_counts() -> void:
	for c in _count_row.get_children():
		c.queue_free()
	_count_btns.clear()
	var opts: Array = []
	if mode == "ai":
		_count_label.text = "AI OPPONENTS"
		opts = [["1", 2], ["2", 3], ["3", 4]]
		if count < 2 or count > 4:
			count = 2
	else:
		_count_label.text = "HUMAN PLAYERS"
		opts = [["2 PLAYERS", 2], ["3 PLAYERS", 3], ["4 PLAYERS", 4]]
	for opt in opts:
		var b := Button.new()
		b.text = String(opt[0])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		T.style_button(b, T.CYAN, 13)
		b.add_theme_stylebox_override("pressed", T.box(Color(T.GREEN, 0.28), T.GREEN, 2, 6))
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.button_pressed = int(opt[1]) == count
		var val: int = int(opt[1])
		b.pressed.connect(func() -> void:
			count = val
			for other: Button in _count_btns:
				other.button_pressed = (other == b))
		_count_row.add_child(b)
		_count_btns.append(b)

func _on_start() -> void:
	var handle := _name_edit.text.strip_edges().to_upper()
	if handle == "":
		handle = "OPERATOR"
	start_requested.emit({"mode": mode, "players": count, "win": goal, "name": handle, "seed": int(Time.get_ticks_usec() % 2000000000)})
