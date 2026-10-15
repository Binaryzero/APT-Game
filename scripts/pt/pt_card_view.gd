extends Control
## Draws one card (face or back). Design grid is 140 x 196 units; everything scales with size.x.

const T := preload("res://scripts/pt/pt_theme.gd")
const Defs := preload("res://scripts/pt/pt_defs.gd")

signal pressed(view: Control)
signal hovered(view: Control, on: bool)

const DESIGN := Vector2(140, 196)

var card: RefCounted = null
var face_down := false
var selected := false
var glow := Color(0, 0, 0, 0)
var dim := false
var show_flavor := false
var badge := ""
var interactive := true
var _hover := false
var _pulse := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func setup(p_card: RefCounted, width: float, p_face_down := false) -> void:
	card = p_card
	face_down = p_face_down
	var k := width / DESIGN.x
	custom_minimum_size = Vector2(width, DESIGN.y * k)
	size = custom_minimum_size
	queue_redraw()

func _process(delta: float) -> void:
	if glow.a > 0.0 or selected:
		_pulse += delta * 4.0
		queue_redraw()

func _mouse_entered_internal() -> void:
	_hover = true
	hovered.emit(self, true)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_mouse_entered_internal()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		hovered.emit(self, false)
		queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()

func _draw() -> void:
	var k := size.x / DESIGN.x
	var r := Rect2(Vector2.ZERO, size)
	if card == null:
		return
	if face_down:
		_draw_back(r, k)
		return
	var d: Dictionary = card.def
	var tcol: Color = T.type_color(String(d.type))
	var alpha := 0.45 if dim else 1.0
	# body
	draw_style_box(T.box(Color("#07111a", alpha), Color(tcol, 0.9 * alpha), maxi(1, int(2 * k)), int(9 * k)), r)
	# header bar
	var hdr := Rect2(3 * k, 3 * k, size.x - 6 * k, 24 * k)
	draw_style_box(T.box(Color(tcol, 0.22 * alpha), Color(0, 0, 0, 0), 0, int(6 * k)), hdr)
	var nm: String = card.title().to_upper()
	var f_title := T.font("title")
	var fs := T.fit_size(f_title, nm, hdr.size.x - 8 * k, int(14 * k), int(8 * k))
	draw_string(f_title, Vector2(hdr.position.x + 5 * k, hdr.position.y + hdr.size.y * 0.5 + fs * 0.34), nm, HORIZONTAL_ALIGNMENT_LEFT, hdr.size.x - 8 * k, fs, Color(1, 1, 1, alpha))
	# type
	var f_b := T.font("bold")
	draw_string(f_b, Vector2(7 * k, 38 * k), String(Defs.TYPE_LABEL.get(d.type, "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 14 * k, int(9 * k), Color(tcol, alpha))
	# art
	var art_rect := Rect2(5 * k, 42 * k, size.x - 10 * k, 60 * k)
	var tex := T.art(String(d.type))
	var ts := tex.get_size()
	var aspect := art_rect.size.x / art_rect.size.y
	var src_h := ts.x / aspect
	var src := Rect2(0, (ts.y - src_h) * 0.5, ts.x, src_h)
	draw_texture_rect_region(tex, art_rect, src, Color(1, 1, 1, alpha))
	draw_rect(art_rect, Color(tcol, 0.7 * alpha), false, maxf(1.0, k))
	# tag chip
	var chip := Rect2(5 * k, 105 * k, size.x - 10 * k, 16 * k)
	draw_style_box(T.box(Color(0, 0, 0, 0.55 * alpha), Color(tcol, 0.6 * alpha), 1, int(4 * k)), chip)
	var tag: String = String(d.get("tag", ""))
	var tfs := T.fit_size(f_b, tag, chip.size.x - 6 * k, int(9 * k), int(6 * k))
	draw_string(f_b, Vector2(chip.position.x, chip.position.y + chip.size.y * 0.5 + tfs * 0.36), tag, HORIZONTAL_ALIGNMENT_CENTER, chip.size.x, tfs, Color(tcol, alpha).lightened(0.25))
	# body text
	var body: String = String(d.text)
	var body_h := (60.0 if not show_flavor else 52.0) * k
	var body_w := size.x - 14 * k
	var f_r := T.font("regular")
	var bfs := T.fit_block(f_r, body, body_w, body_h, int(11 * k), int(7 * k))
	draw_multiline_string(f_r, Vector2(7 * k, 133 * k + bfs * 0.8 - 2 * k), body, HORIZONTAL_ALIGNMENT_LEFT, body_w, bfs, -1, Color(0.86, 0.94, 0.97, alpha))
	if show_flavor:
		var fl: String = String(d.get("flavor", ""))
		var ffs := T.fit_size(f_r, fl, body_w, int(9 * k), int(6 * k))
		draw_string(f_r, Vector2(7 * k, 190 * k), fl, HORIZONTAL_ALIGNMENT_LEFT, body_w, ffs, Color(tcol, 0.8 * alpha))
	if badge != "":
		var bw := f_b.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * k)).x + 12 * k
		var br := Rect2(size.x - bw - 4 * k, size.y - 22 * k, bw, 18 * k)
		draw_style_box(T.box(Color(0, 0, 0, 0.85), T.WARN, 1, int(4 * k)), br)
		draw_string(f_b, Vector2(br.position.x, br.position.y + 13 * k), badge, HORIZONTAL_ALIGNMENT_CENTER, bw, int(11 * k), T.WARN)
	if dim:
		draw_rect(r, Color(0, 0, 0, 0.35))
	# state outlines
	if selected:
		var pulse := 0.6 + 0.4 * sin(_pulse)
		draw_style_box(T.box(Color(0, 0, 0, 0), Color(T.GREEN, pulse), maxi(2, int(3 * k)), int(9 * k)), r.grow(1.0 * k))
	elif glow.a > 0.0:
		var pulse2 := 0.45 + 0.4 * (0.5 + 0.5 * sin(_pulse))
		draw_style_box(T.box(Color(0, 0, 0, 0), Color(glow, pulse2), maxi(2, int(2 * k)), int(9 * k)), r.grow(1.0 * k))
	if _hover and interactive:
		draw_style_box(T.box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.5), 1, int(9 * k)), r)

func _draw_back(r: Rect2, k: float) -> void:
	draw_style_box(T.box(Color("#050c12"), T.CYAN_DIM, maxi(1, int(2 * k)), int(9 * k)), r)
	var c := r.get_center()
	for i in 5:
		var inset := (8 + i * 9) * k
		draw_rect(r.grow(-inset), Color(T.CYAN, 0.10 + 0.04 * i), false, maxf(1.0, k))
	var h := 26.0 * k
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)]), Color(T.CYAN, 0.18))
	draw_polyline(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0), c + Vector2(0, -h)]), T.CYAN, maxf(1.0, 1.5 * k))
	draw_string(T.font("title"), Vector2(0, c.y + 6 * k), "PT", HORIZONTAL_ALIGNMENT_CENTER, size.x, int(18 * k), T.CYAN)
