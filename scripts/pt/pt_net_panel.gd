extends Control
## A player's network: header (name, goal progress, hand) plus a row of server slots.

const T := preload("res://scripts/pt/pt_theme.gd")
const Defs := preload("res://scripts/pt/pt_defs.gd")
const SlotView := preload("res://scripts/pt/pt_slot_view.gd")

signal card_picked(card: RefCounted)
signal card_hovered(card: RefCounted)
signal header_picked(seat: int)
signal server_placement_picked(seat: int)

var engine: RefCounted = null
var seat := 0
var is_self := false
var highlights: Dictionary = {}
var player_highlight := Color(0, 0, 0, 0)
var placement_active := false
var _pulse := 0.0
var _slots_root: Control
var _dirty := true

func _ready() -> void:
	_slots_root = Control.new()
	_slots_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slots_root)
	set_process(true)
	resized.connect(func() -> void: _dirty = true)

func bind(e: RefCounted, p_seat: int, p_self: bool) -> void:
	engine = e
	seat = p_seat
	is_self = p_self
	_dirty = true

func mark_dirty() -> void:
	_dirty = true

func set_highlights(h: Dictionary, ph: Color) -> void:
	highlights = h
	player_highlight = ph
	_dirty = true

func set_placement_active(active: bool) -> void:
	if placement_active == active:
		return
	placement_active = active
	_dirty = true

func _process(delta: float) -> void:
	_pulse += delta * 4.0
	if player_highlight.a > 0.0:
		queue_redraw()
	if _dirty:
		_dirty = false
		_rebuild()
		queue_redraw()

func _rebuild() -> void:
	for c in _slots_root.get_children():
		c.queue_free()
	if engine == null or seat >= engine.players.size():
		return
	var p: Dictionary = engine.players[seat]
	var reveal_extra := 20.0 if engine.hand_revealed(p) and not is_self else 0.0
	var header_h := 28.0 + reveal_extra
	var avail_h := size.y - header_h - 8.0
	var n: int = maxi(engine.win_target, p.net.size())
	var s_h := avail_h / SlotView.TOTAL_H
	var s_w := (size.x - 16.0) / (n * (SlotView.W + 6.0))
	var sc := clampf(minf(s_h, s_w), 0.6, 1.5)
	var x := 8.0
	var slot_y := header_h + 2.0 + maxf(0.0, (avail_h - SlotView.TOTAL_H * sc) * 0.5)
	for slot: Dictionary in p.net:
		var v := SlotView.new()
		v.setup(slot, sc, highlights)
		v.position = Vector2(x, slot_y)
		v.picked.connect(func(c: RefCounted) -> void: card_picked.emit(c))
		v.hovered.connect(func(c: RefCounted) -> void: card_hovered.emit(c))
		_slots_root.add_child(v)
		x += (SlotView.W + 6.0) * sc
	if placement_active and is_self and p.net.size() < 9:
		var add_server := Button.new()
		add_server.text = "+ ADD\nSERVER"
		add_server.position = Vector2(x, slot_y)
		add_server.size = Vector2(SlotView.W * sc, SlotView.TOTAL_H * sc)
		add_server.custom_minimum_size = add_server.size
		add_server.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		T.style_button(add_server, T.GREEN, 11)
		add_server.pressed.connect(func() -> void: server_placement_picked.emit(seat))
		_slots_root.add_child(add_server)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.y < 30.0 or player_highlight.a > 0.0:
			header_picked.emit(seat)

func _draw() -> void:
	if engine == null or seat >= engine.players.size():
		return
	var p: Dictionary = engine.players[seat]
	var active: bool = engine.current == seat and not engine.over
	var adv: Dictionary = Defs.ADVERSARIES[int(p.adv) % Defs.ADVERSARIES.size()]
	var acol := Color(String(adv.color))
	var border := T.CYAN if active else T.LINE
	draw_style_box(T.box(Color(T.PANEL, 0.88), border, 2 if active else 1, 10), Rect2(Vector2.ZERO, size))
	if player_highlight.a > 0.0:
		var pl := 0.5 + 0.5 * sin(_pulse)
		draw_style_box(T.box(Color(player_highlight, 0.08 + 0.08 * pl), Color(player_highlight, 0.5 + 0.5 * pl), 3, 10), Rect2(Vector2.ZERO, size))
	var f_t := T.font("title")
	var f_b := T.font("bold")
	# marker + name
	draw_circle(Vector2(18, 15), 6, acol)
	var title := String(p.name).to_upper()
	draw_string(f_t, Vector2(30, 21), title, HORIZONTAL_ALIGNMENT_LEFT, 260, 16, Color.WHITE)
	var name_w := f_t.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var role := "YOU" if is_self else ("AI" if p.ai else "PLAYER")
	draw_string(f_b, Vector2(36 + name_w, 20), "· %s · %s" % [Defs.ADVERSARIES[int(p.adv) % Defs.ADVERSARIES.size()].name, role], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, T.TEXT_DIM)
	# server progress pips (right side)
	var goal: int = engine.win_target
	var x := size.x - 14.0
	var hand_n: int = p.hand.size()
	var limit: int = engine.hand_limit(p)
	var hand_text := "HAND %d/%d" % [hand_n, limit]
	var hw := f_b.get_string_size(hand_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var hand_col := T.WARN if hand_n > limit else T.TEXT
	draw_string(f_b, Vector2(x - hw, 19), hand_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, hand_col)
	x -= hw + 14.0
	var shown := mini(hand_n, 12)
	for i in shown:
		var rx := x - 9.0 * (i + 1)
		draw_rect(Rect2(rx, 8, 7, 11), Color(T.CYAN, 0.35))
		draw_rect(Rect2(rx, 8, 7, 11), T.CYAN, false, 1.0)
	x -= 9.0 * shown + 16.0
	var servers: int = p.net.size()
	for i in goal:
		var px := x - 14.0 * (goal - i)
		var filled := i < servers
		draw_rect(Rect2(px, 8, 11, 11), Color(T.GREEN, 0.9) if filled else Color(T.LINE, 0.9))
		draw_rect(Rect2(px, 8, 11, 11), Color(T.GREEN, 0.9), false, 1.0)
	var lbl := "SERVERS %d/%d" % [servers, goal]
	var lw := f_b.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(f_b, Vector2(x - 14.0 * goal - lw - 8.0, 19), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, T.GREEN)
	# revealed hand pills
	if engine.hand_revealed(p) and not is_self:
		var px2 := 10.0
		draw_string(f_b, Vector2(px2, 42), "HAND EXPOSED:", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, T.RED)
		px2 += 86.0
		for c in p.hand:
			var cc: RefCounted = c
			var t: String = cc.title()
			var tw := f_b.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12.0
			if px2 + tw > size.x - 8.0:
				draw_string(f_b, Vector2(px2, 42), "…", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, T.TEXT_DIM)
				break
			var col: Color = T.type_color(String(cc.def.type))
			draw_style_box(T.box(Color(col, 0.2), Color(col, 0.9), 1, 4), Rect2(px2, 31, tw, 15))
			draw_string(f_b, Vector2(px2 + 6, 42), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
			px2 += tw + 4.0
