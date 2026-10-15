extends RefCounted
## Shared palette, fonts and small drawing helpers for the Packet Tactics UI.

const Defs := preload("res://scripts/pt/pt_defs.gd")

const BG := Color("#04080c")
const PANEL := Color("#09131a")
const PANEL_2 := Color("#0e1d27")
const LINE := Color("#17303d")
const CYAN := Color("#27d3f5")
const CYAN_DIM := Color("#16788c")
const GREEN := Color("#3dff8e")
const WARN := Color("#ffb21f")
const RED := Color("#ff5a3c")
const VIOLET := Color("#c77dff")
const TEXT := Color("#d9eef5")
const TEXT_DIM := Color("#7fa3b1")

static var _font_cache := {}
static var _art_cache := {}

static func font(kind: String) -> Font:
	if not _font_cache.has(kind):
		var path := "res://assets/template/fonts/ui_regular.tres"
		match kind:
			"bold":
				path = "res://assets/template/fonts/ui_bold.tres"
			"medium":
				path = "res://assets/template/fonts/ui_medium.tres"
			"title":
				path = "res://assets/template/fonts/display/card_title.tres"
			"name":
				path = "res://assets/template/fonts/display/card_name.tres"
			"number":
				path = "res://assets/template/fonts/display/card_number.tres"
		_font_cache[kind] = load(path)
	return _font_cache[kind]

static func art(type_key: String) -> Texture2D:
	var name_: String = Defs.TYPE_ART.get(type_key, "production")
	if not _art_cache.has(name_):
		_art_cache[name_] = load("res://assets/pt/art_%s.webp" % name_)
	return _art_cache[name_]

static func type_color(t: String) -> Color:
	return Defs.TYPE_COLOR.get(t, CYAN)

static func box(fill: Color, border: Color = Color(0, 0, 0, 0), bw := 1, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	return sb

static func style_button(b: Button, accent: Color = CYAN, font_size := 15) -> void:
	b.add_theme_font_override("font", font("bold"))
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.BLACK)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.5, 0.55))
	b.add_theme_stylebox_override("normal", box(Color(accent, 0.12), Color(accent, 0.8), 1, 6))
	b.add_theme_stylebox_override("hover", box(Color(accent, 0.28), accent, 2, 6))
	b.add_theme_stylebox_override("pressed", box(accent, accent, 2, 6))
	b.add_theme_stylebox_override("disabled", box(Color(0.1, 0.14, 0.17), Color(0.2, 0.28, 0.32), 1, 6))
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), GREEN, 2, 6))
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func make_label(text: String, size := 14, color: Color = TEXT, kind := "regular") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Shrinks a font size until `text` fits `width` on a single line.
static func fit_size(f: Font, text: String, width: float, start: int, minimum: int) -> int:
	var size := start
	while size > minimum and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size

## Largest font size (<= start) at which wrapped `text` fits in a box.
static func fit_block(f: Font, text: String, width: float, height: float, start: int, minimum: int) -> int:
	var size := start
	while size > minimum:
		var sz := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size)
		if sz.y <= height:
			break
		size -= 1
	return size
