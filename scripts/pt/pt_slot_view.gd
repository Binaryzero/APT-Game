extends Control
## One server in a network with its Software/Malware stacked above it (like the rulebook layout).

const T := preload("res://scripts/pt/pt_theme.gd")
const Defs := preload("res://scripts/pt/pt_defs.gd")

signal picked(card: RefCounted)
signal hovered(card: RefCounted)

const W := 118.0
const AT := 44.0
const GAP := 3.0
const SV := 66.0
const TOTAL_H := AT + GAP + SV

var slot: Dictionary = {}
var s := 1.0
var highlights: Dictionary = {}
var _pulse := 0.0
var _hover_card: RefCounted = null

func setup(p_slot: Dictionary, p_scale: float, p_highlights: Dictionary) -> void:
	slot = p_slot
	s = p_scale
	highlights = p_highlights
	custom_minimum_size = Vector2(W * s, TOTAL_H * s)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_process(not highlights.is_empty())
	queue_redraw()

func _process(delta: float) -> void:
	_pulse += delta * 4.0
	queue_redraw()

func _card_at(pos: Vector2) -> RefCounted:
	if pos.y < AT * s:
		if slot.mal != null:
			if pos.y > 14.0 * s or slot.soft == null:
				return slot.mal
			return slot.soft
		return slot.soft
	return slot.server

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var c := _card_at(event.position)
		if c != _hover_card:
			_hover_card = c
			if c != null:
				hovered.emit(c)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var c2 := _card_at(event.position)
		if c2 != null:
			picked.emit(c2)
			accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_card = null
		queue_redraw()

func _hl(card: RefCounted) -> Color:
	if card != null and highlights.has(card):
		return highlights[card]
	return Color(0, 0, 0, 0)

func _draw() -> void:
	if slot.is_empty():
		return
	var f_b := T.font("bold")
	var f_r := T.font("regular")
	# --- server tile
	var sv: RefCounted = slot.server
	var sr := Rect2(0, (AT + GAP) * s, W * s, SV * s)
	var tcol: Color = T.type_color(String(sv.def.type))
	var tex := T.art(String(sv.def.type))
	var ts := tex.get_size()
	var aspect := sr.size.x / sr.size.y
	var src_h := ts.x / aspect
	draw_style_box(T.box(Color("#07111a"), Color(tcol, 0.9), maxi(1, int(2 * s)), int(7 * s)), sr)
	draw_texture_rect_region(tex, sr.grow(-2.0 * s), Rect2(0, (ts.y - src_h) * 0.5, ts.x, src_h), Color(1, 1, 1, 0.55))
	draw_rect(sr.grow(-2.0 * s), Color(0, 0, 0, 0.45))
	var nm: String = sv.title().to_upper()
	var f_t := T.font("title")
	var fs := T.fit_size(f_t, nm, sr.size.x - 10 * s, int(13 * s), int(7 * s))
	draw_string(f_t, Vector2(sr.position.x + 6 * s, sr.position.y + 18 * s), nm, HORIZONTAL_ALIGNMENT_LEFT, sr.size.x - 10 * s, fs, Color.WHITE)
	var kind_text := "PRODUCTION" if sv.type() == "prod" else "STAGING"
	draw_string(f_b, Vector2(sr.position.x + 6 * s, sr.position.y + 31 * s), kind_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(8 * s), Color(tcol, 1.0))
	var tag: String = String(sv.def.get("tag", ""))
	var tfs := T.fit_size(f_b, tag, sr.size.x - 10 * s, int(9 * s), int(6 * s))
	draw_string(f_b, Vector2(sr.position.x + 6 * s, sr.position.y + sr.size.y - 8 * s), tag, HORIZONTAL_ALIGNMENT_LEFT, sr.size.x - 10 * s, tfs, Color(0.9, 0.97, 1.0))
	var hs := _hl(sv)
	if hs.a > 0.0:
		var p := 0.5 + 0.5 * sin(_pulse)
		draw_style_box(T.box(Color(hs, 0.10 + 0.12 * p), Color(hs, 0.55 + 0.45 * p), maxi(2, int(3 * s)), int(7 * s)), sr.grow(1.0))
	if _hover_card == sv:
		draw_style_box(T.box(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.55), 1, int(7 * s)), sr)
	# --- attachments
	var soft: RefCounted = slot.soft
	var mal: RefCounted = slot.mal
	if soft == null and mal == null:
		var er := Rect2(6 * s, (AT - 24) * s, (W - 12) * s, 24 * s)
		draw_rect(er, Color(T.CYAN, 0.10), false, 1.0)
		return
	if soft != null:
		var covered := mal != null
		var soft_rect := Rect2(0, 0, W * s, 14 * s) if covered else Rect2(0, (AT - 32) * s, W * s, 32 * s)
		_draw_attach(soft, soft_rect, covered, f_b)
	if mal != null:
		_draw_attach(mal, Rect2(0, (AT - 32) * s, W * s, 32 * s), false, f_b)

func _draw_attach(card: RefCounted, r: Rect2, offline: bool, f_b: Font) -> void:
	var col: Color = T.type_color(String(card.def.type))
	var a := 0.45 if offline else 1.0
	draw_style_box(T.box(Color(col, 0.20 * a + 0.04), Color(col, 0.95 * a), maxi(1, int(2 * s)), int(6 * s)), r)
	var nm: String = card.title().to_upper()
	if offline:
		var fs := T.fit_size(f_b, nm, r.size.x - 10 * s, int(8 * s), int(5 * s))
		draw_string(f_b, Vector2(r.position.x + 5 * s, r.position.y + r.size.y * 0.5 + fs * 0.36), nm + "  (OFFLINE)", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10 * s, fs, Color(col, 0.8))
		draw_line(Vector2(r.position.x + 4 * s, r.position.y + r.size.y * 0.5), Vector2(r.end.x - 4 * s, r.position.y + r.size.y * 0.5), Color(col, 0.6), 1.0)
	else:
		var f_t := T.font("title")
		var fs2 := T.fit_size(f_t, nm, r.size.x - 10 * s, int(11 * s), int(6 * s))
		draw_string(f_t, Vector2(r.position.x + 5 * s, r.position.y + 13 * s), nm, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10 * s, fs2, Color.WHITE)
		var tag: String = String(card.def.get("tag", ""))
		var tfs := T.fit_size(f_b, tag, r.size.x - 10 * s, int(8 * s), int(5 * s))
		draw_string(f_b, Vector2(r.position.x + 5 * s, r.position.y + r.size.y - 5 * s), tag, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10 * s, tfs, Color(col, 1.0).lightened(0.3))
	var h := _hl(card)
	if h.a > 0.0:
		var p := 0.5 + 0.5 * sin(_pulse)
		draw_style_box(T.box(Color(h, 0.10 + 0.12 * p), Color(h, 0.55 + 0.45 * p), maxi(2, int(3 * s)), int(6 * s)), r.grow(1.0))
	if _hover_card == card:
		draw_style_box(T.box(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.55), 1, int(6 * s)), r)
