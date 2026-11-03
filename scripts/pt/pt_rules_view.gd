extends Control
## Overlay with two tabs: RULES (text) and CODEX (every card in the deck with copy counts).
## Sizes itself from the live viewport and re-runs layout on window resize.

const T := preload("res://scripts/pt/pt_theme.gd")
const Defs := preload("res://scripts/pt/pt_defs.gd")
const Card := preload("res://scripts/pt/pt_card.gd")
const CardView := preload("res://scripts/pt/pt_card_view.gd")
const RulesText := preload("res://scripts/pt/pt_rules_text.gd")
const PtLayout := preload("res://scripts/pt/pt_layout.gd")

signal closed

var _panel: Panel
var _title: Label
var _close: Button
var _rules_scroll: ScrollContainer
var _rules_text: RichTextLabel
var _codex_root: Control
var _codex_scroll: ScrollContainer
var _codex_grid: GridContainer
var _codex_tip: Label
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
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", T.box(Color(T.PANEL, 0.97), T.CYAN, 2, 12))
	add_child(_panel)
	_title = T.make_label("FIELD MANUAL", 20, T.CYAN, "title")
	_panel.add_child(_title)
	_tab_rules = Button.new()
	_tab_rules.text = "RULES"
	_tab_rules.toggle_mode = true
	_tab_rules.size = Vector2(110, 30)
	T.style_button(_tab_rules, T.CYAN, 13)
	_tab_rules.pressed.connect(func() -> void: _show_tab("rules"))
	_panel.add_child(_tab_rules)
	_tab_codex = Button.new()
	_tab_codex.text = "CARD CODEX"
	_tab_codex.toggle_mode = true
	_tab_codex.size = Vector2(140, 30)
	T.style_button(_tab_codex, T.GREEN, 13)
	_tab_codex.pressed.connect(func() -> void: _show_tab("codex"))
	_panel.add_child(_tab_codex)
	_close = Button.new()
	_close.text = "CLOSE"
	_close.size = Vector2(100, 30)
	T.style_button(_close, T.WARN, 13)
	_close.pressed.connect(func() -> void: closed.emit())
	_panel.add_child(_close)
	# rules tab
	_rules_scroll = ScrollContainer.new()
	_rules_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_rules_scroll)
	_rules_text = RichTextLabel.new()
	_rules_text.bbcode_enabled = true
	_rules_text.fit_content = true
	_rules_text.scroll_active = false
	_rules_text.add_theme_font_override("normal_font", T.font("regular"))
	_rules_text.add_theme_font_override("bold_font", T.font("bold"))
	_rules_text.add_theme_font_override("italics_font", T.font("regular"))
	_rules_text.add_theme_font_size_override("normal_font_size", 14)
	_rules_text.add_theme_font_size_override("bold_font_size", 14)
	_rules_text.add_theme_font_size_override("italics_font_size", 14)
	_rules_text.add_theme_color_override("default_color", T.TEXT)
	_rules_text.text = RulesText.RULES
	_rules_scroll.add_child(_rules_text)
	# codex tab
	_codex_root = Control.new()
	_codex_root.visible = false
	_panel.add_child(_codex_root)
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	_show_tab("rules")

func open(tab := "rules") -> void:
	visible = true
	_show_tab(tab)

## Size and place everything from the live viewport; safe to re-run on resize.
func _relayout() -> void:
	var vp := get_viewport_rect().size
	var pw := minf(1160.0, vp.x - 80.0)
	var ph := minf(664.0, vp.y - 56.0)
	_panel.position = PtLayout.centered(vp, pw, ph)
	_panel.size = Vector2(pw, ph)
	_title.position = Vector2(24, 10)
	_tab_rules.position = Vector2(340, 10)
	_tab_codex.position = Vector2(460, 10)
	_close.position = Vector2(pw - 100.0 - 24.0, 10)
	_rules_scroll.position = Vector2(24, 52)
	_rules_scroll.size = Vector2(pw - 48.0, ph - 52.0 - 16.0)
	_rules_text.custom_minimum_size = Vector2(pw - 48.0 - 24.0, 0)
	_codex_root.position = Vector2(24, 52)
	_codex_root.size = Vector2(pw - 48.0, ph - 52.0 - 16.0)
	_relayout_codex()

func _relayout_codex() -> void:
	if not _codex_built:
		return
	var w: float = _codex_root.size.x
	var h: float = _codex_root.size.y
	_preview.position = Vector2(w - 252.0, 6.0)
	_codex_tip.position = Vector2(w - 250.0, 372.0)
	_codex_scroll.position = Vector2.ZERO
	_codex_scroll.size = Vector2(w - 252.0 - 16.0, h)
	_codex_grid.columns = clampi(int((_codex_scroll.size.x + 10.0) / 166.0), 1, 8)

func _show_tab(tab: String) -> void:
	_tab_rules.button_pressed = tab == "rules"
	_tab_codex.button_pressed = tab == "codex"
	_rules_scroll.visible = tab == "rules"
	_codex_root.visible = tab == "codex"
	if tab == "codex" and not _codex_built:
		_build_codex()
		_relayout_codex()

func _build_codex() -> void:
	_codex_built = true
	_preview = CardView.new()
	var sample := Card.new(0, "staging_start", Defs.DEFS["staging_start"])
	_preview.setup(sample, 252)
	_preview.show_flavor = true
	_preview.interactive = false
	_codex_root.add_child(_preview)
	_codex_tip = T.make_label("Hover a card to enlarge it.", 12, T.TEXT_DIM)
	_codex_root.add_child(_codex_tip)
	_codex_scroll = ScrollContainer.new()
	_codex_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_codex_root.add_child(_codex_scroll)
	_codex_grid = GridContainer.new()
	_codex_grid.add_theme_constant_override("h_separation", 10)
	_codex_grid.add_theme_constant_override("v_separation", 10)
	_codex_scroll.add_child(_codex_grid)
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
			_codex_grid.add_child(v)