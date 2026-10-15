extends Control
## Overlay with two tabs: RULES (text) and CODEX (every card in the deck with copy counts).

const T := preload("res://scripts/pt/pt_theme.gd")
const Defs := preload("res://scripts/pt/pt_defs.gd")
const Card := preload("res://scripts/pt/pt_card.gd")
const CardView := preload("res://scripts/pt/pt_card_view.gd")
const RulesText := preload("res://scripts/pt/pt_rules_text.gd")

signal closed

var _rules_scroll: ScrollContainer
var _codex_root: Control
var _preview: Control
var _tab_rules: Button
var _tab_codex: Button
var _codex_built := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.02, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(60, 28)
	panel.size = Vector2(1160, 664)
	panel.add_theme_stylebox_override("panel", T.box(Color(T.PANEL, 0.97), T.CYAN, 2, 12))
	add_child(panel)
	var title := T.make_label("FIELD MANUAL", 26, T.CYAN, "title")
	title.position = Vector2(88, 40)
	add_child(title)
	_tab_rules = Button.new()
	_tab_rules.text = "RULES"
	_tab_rules.toggle_mode = true
	_tab_rules.position = Vector2(400, 42)
	_tab_rules.size = Vector2(120, 34)
	T.style_button(_tab_rules, T.CYAN)
	_tab_rules.pressed.connect(func() -> void: _show_tab("rules"))
	add_child(_tab_rules)
	_tab_codex = Button.new()
	_tab_codex.text = "CARD CODEX"
	_tab_codex.toggle_mode = true
	_tab_codex.position = Vector2(530, 42)
	_tab_codex.size = Vector2(150, 34)
	T.style_button(_tab_codex, T.GREEN)
	_tab_codex.pressed.connect(func() -> void: _show_tab("codex"))
	add_child(_tab_codex)
	var close := Button.new()
	close.text = "CLOSE"
	close.position = Vector2(1080, 42)
	close.size = Vector2(110, 34)
	T.style_button(close, T.WARN)
	close.pressed.connect(func() -> void: closed.emit())
	add_child(close)
	# rules
	_rules_scroll = ScrollContainer.new()
	_rules_scroll.position = Vector2(90, 92)
	_rules_scroll.size = Vector2(1100, 580)
	_rules_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_rules_scroll)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(1070, 0)
	rt.add_theme_font_override("normal_font", T.font("regular"))
	rt.add_theme_font_override("bold_font", T.font("bold"))
	rt.add_theme_font_override("italics_font", T.font("regular"))
	rt.add_theme_font_size_override("normal_font_size", 16)
	rt.add_theme_font_size_override("bold_font_size", 16)
	rt.add_theme_font_size_override("italics_font_size", 16)
	rt.add_theme_color_override("default_color", T.TEXT)
	rt.text = RulesText.RULES
	_rules_scroll.add_child(rt)
	# codex
	_codex_root = Control.new()
	_codex_root.position = Vector2(80, 88)
	_codex_root.size = Vector2(1120, 586)
	_codex_root.visible = false
	add_child(_codex_root)
	_show_tab("rules")

func open(tab := "rules") -> void:
	visible = true
	_show_tab(tab)

func _show_tab(tab: String) -> void:
	_tab_rules.button_pressed = tab == "rules"
	_tab_codex.button_pressed = tab == "codex"
	_rules_scroll.visible = tab == "rules"
	_codex_root.visible = tab == "codex"
	if tab == "codex" and not _codex_built:
		_build_codex()

func _build_codex() -> void:
	_codex_built = true
	_preview = CardView.new()
	var sample := Card.new(0, "staging_start", Defs.DEFS["staging_start"])
	_preview.setup(sample, 252)
	_preview.show_flavor = true
	_preview.interactive = false
	_preview.position = Vector2(850, 6)
	_codex_root.add_child(_preview)
	var tip := T.make_label("Hover a card to enlarge it.", 13, T.TEXT_DIM)
	tip.position = Vector2(852, 372)
	_codex_root.add_child(tip)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(840, 586)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_codex_root.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	var order := ["prod", "stage", "soft", "mal", "exploit", "zd"]
	for t in order:
		for key: String in Defs.DEFS:
			var d: Dictionary = Defs.DEFS[key]
			if d.type != t:
				continue
			var c := Card.new(0, key, d)
			var v := CardView.new()
			v.setup(c, 156)
			v.interactive = false
			v.mouse_filter = Control.MOUSE_FILTER_STOP
			var copies: int = int(d.get("copies", 0))
			v.badge = "x%d" % copies if copies > 0 else "START"
			v.hovered.connect(func(view: Control, on: bool) -> void:
				if on:
					_preview.card = view.card
					_preview.queue_redraw())
			grid.add_child(v)
