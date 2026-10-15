class_name EmberpanCursorDirector
extends CanvasLayer

signal mode_changed(mode: String)

const ASSET_PATHS := {
	"default": "res://assets/template/cardgame/cursors/default.png",
	"interact": "res://assets/template/cardgame/cursors/interact.png",
	"inspect": "res://assets/template/cardgame/cursors/inspect.png",
	"grab": "res://assets/template/cardgame/cursors/grab.png",
	"grabbing": "res://assets/template/cardgame/cursors/grabbing.png",
	"serve": "res://assets/template/cardgame/cursors/serve.png",
	"attack": "res://assets/template/cardgame/cursors/attack.png",
	"support": "res://assets/template/cardgame/cursors/support.png",
	"cook": "res://assets/template/cardgame/cursors/cook.png",
	"route": "res://assets/template/cardgame/cursors/route.png",
	"blocked": "res://assets/template/cardgame/cursors/blocked.png",
	"wait": "res://assets/template/cardgame/cursors/wait.png",
}

const MODE_COLORS := {
	"default": Color("#F3A33C"),
	"interact": Color("#F3A33C"),
	"inspect": Color("#FFD36A"),
	"grab": Color("#F3A33C"),
	"grabbing": Color("#F3A33C"),
	"serve": Color("#55C6A9"),
	"attack": Color("#D95757"),
	"support": Color("#55C6A9"),
	"cook": Color("#F3A33C"),
	"route": Color("#FFD36A"),
	"blocked": Color("#8B8175"),
	"wait": Color("#BBAF9A"),
}

const MODE_SIZES := {
	"default": 54.0,
	"interact": 58.0,
	"inspect": 62.0,
	"grab": 60.0,
	"grabbing": 60.0,
	"serve": 64.0,
	"attack": 66.0,
	"support": 64.0,
	"cook": 64.0,
	"route": 62.0,
	"blocked": 60.0,
	"wait": 60.0,
}

const CENTERED_MODES := ["inspect", "grab", "grabbing", "serve", "attack", "support", "cook", "route", "blocked", "wait"]
const HALO_MODES := ["serve", "attack", "support", "cook", "route", "blocked", "wait"]
const TRAIL_MODES := ["grabbing", "serve", "attack", "support", "cook", "route"]
const MAX_TRAILS := 5

var game: Node
var current_mode := "default"
var motion_reduced := false
var pointer_root: Control
var trail_layer: Control
var halo: Panel
var icon: TextureRect
var textures := {}
var last_pointer := Vector2.ZERO
var last_trail_pointer := Vector2.ZERO
var trail_cooldown := 0.0
var override_mode := ""
var override_until_ms := 0
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var owns_system_cursor := false
var pointer_inside_window := true
var window_focused := true


func setup(game_node: Node) -> void:
	game = game_node


func _ready() -> void:
	layer = 8192
	process_mode = Node.PROCESS_MODE_ALWAYS
	for mode in ASSET_PATHS:
		textures[mode] = load(String(ASSET_PATHS[mode]))

	trail_layer = Control.new()
	trail_layer.name = "CursorTrails"
	trail_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trail_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(trail_layer)

	pointer_root = Control.new()
	pointer_root.name = "Pointer"
	pointer_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer_root.z_index = 10
	add_child(pointer_root)

	halo = Panel.new()
	halo.name = "IntentHalo"
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.size = Vector2(38, 38)
	halo.pivot_offset = halo.size * 0.5
	pointer_root.add_child(halo)

	icon = TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer_root.add_child(icon)

	_apply_mode(current_mode, true)
	previous_mouse_mode = Input.get_mouse_mode()
	_acquire_system_cursor()


func _exit_tree() -> void:
	if owns_system_cursor and DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(previous_mouse_mode)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_MOUSE_EXIT:
			set_pointer_inside_window(false)
		NOTIFICATION_WM_MOUSE_ENTER:
			set_pointer_inside_window(true)
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			window_focused = false
			_release_system_cursor()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			window_focused = true
			if pointer_inside_window:
				_acquire_system_cursor()


func set_pointer_inside_window(inside: bool) -> void:
	pointer_inside_window = inside
	if inside and window_focused:
		_acquire_system_cursor()
	else:
		_release_system_cursor()


func _acquire_system_cursor() -> void:
	if pointer_root != null:
		pointer_root.visible = not DisplayServer.is_touchscreen_available()
	if DisplayServer.get_name() != "headless" and not DisplayServer.is_touchscreen_available():
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		owns_system_cursor = true


func _release_system_cursor() -> void:
	if pointer_root != null:
		pointer_root.visible = false
	if owns_system_cursor and DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func configure_motion(mode: String) -> void:
	motion_reduced = mode != "full"
	if motion_reduced:
		_clear_trails()


func flash(mode: String, duration := 0.28) -> void:
	if not ASSET_PATHS.has(mode):
		return
	override_mode = mode
	override_until_ms = Time.get_ticks_msec() + roundi(duration * 1000.0)
	_apply_mode(mode)
	_click_ripple(MODE_COLORS.get(mode, Color.WHITE), 1.25)


func resolve_mode_for(control: Control = null, pointer := Vector2(-100000.0, -100000.0)) -> String:
	if game == null:
		return "default"
	if Time.get_ticks_msec() < override_until_ms and not override_mode.is_empty():
		return override_mode
	if pointer.x < -99999.0:
		pointer = get_viewport().get_mouse_position()

	if bool(game.get("drag_active")):
		var dragged_uid := int(game.get("dragged_card_uid"))
		if dragged_uid >= 0 and game.has_method("_is_valid_card_drop"):
			return "serve" if bool(game.call("_is_valid_card_drop", dragged_uid, pointer)) else "blocked"
		return "grabbing"
	if int(game.get("drag_candidate_uid")) >= 0:
		return "grabbing"

	var target := _cursor_target(control)
	if target != null:
		var explicit := String(target.get_meta("cursor_mode", ""))
		if not explicit.is_empty() and ASSET_PATHS.has(explicit):
			return explicit
		if target is BaseButton and (target as BaseButton).disabled:
			return "blocked"
		if target is LineEdit:
			return "interact"
		if target is ScrollBar:
			return "grab" if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else "grabbing"

		var kind := String(target.get_meta("juice_kind", ""))
		match kind:
			"card":
				if bool(target.get_meta("inspection_only", false)):
					return "inspect"
				return "grab" if bool(target.get_meta("playable", false)) else "blocked"
			"unit":
				if bool(target.get_meta("legal_target", false)):
					return "support" if bool(target.get_meta("friendly", false)) else "attack"
				if bool(target.get_meta("friendly", false)) and bool(target.get_meta("unit_ready", false)) and _can_act():
					return "attack"
				return "blocked" if not _pending_action().is_empty() else "inspect"
			"hero":
				if bool(target.get_meta("legal_target", false)):
					return "attack"
				return "blocked" if not _pending_action().is_empty() else "inspect"
			"recipe":
				return "cook"
			"reward":
				return "inspect" if bool(target.get_meta("reward_revealed", false)) else "interact"
			"route":
				return "route"
			"button":
				return "interact"

	if _should_wait():
		return "wait"
	var action := _pending_action()
	if not action.is_empty():
		return "support" if String(action.get("effect", "")) == "target_friend_buff" else "attack"
	return "default"


func _process(delta: float) -> void:
	if pointer_root == null:
		return
	if Time.get_ticks_msec() >= override_until_ms:
		override_mode = ""
	var pointer := get_viewport().get_mouse_position()
	var hovered := get_viewport().gui_get_hovered_control()
	var next_mode := resolve_mode_for(hovered, pointer)
	_apply_mode(next_mode)
	position_pointer(pointer)

	trail_cooldown = maxf(0.0, trail_cooldown - delta)
	if not motion_reduced and current_mode in TRAIL_MODES and pointer.distance_to(last_trail_pointer) >= 18.0 and trail_cooldown <= 0.0:
		_spawn_trail(pointer)
		last_trail_pointer = pointer
		trail_cooldown = 0.045

	if not motion_reduced and current_mode == "wait":
		icon.rotation += delta * 2.4
	else:
		icon.rotation = lerp_angle(icon.rotation, 0.0, minf(1.0, delta * 18.0))
	if not motion_reduced and current_mode in HALO_MODES:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.08
		halo.scale = Vector2.ONE * pulse
	else:
		halo.scale = Vector2.ONE
	last_pointer = pointer


func position_pointer(pointer: Vector2) -> void:
	if pointer_root == null:
		return
	var hotspot := _hotspot_for(current_mode)
	pointer_root.position = pointer - hotspot


func _input(event: InputEvent) -> void:
	if pointer_root == null:
		return
	if event is InputEventScreenTouch:
		pointer_root.visible = false
		return
	if event is InputEventMouseMotion:
		pointer_inside_window = true
		window_focused = true
		_acquire_system_cursor()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(pointer_root, "scale", Vector2(0.86, 0.86), 0.055)
	else:
		var release_tween := create_tween()
		release_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		release_tween.tween_property(pointer_root, "scale", Vector2.ONE, 0.13)
		_click_ripple(MODE_COLORS.get(current_mode, Color.WHITE))


func _apply_mode(mode: String, immediate := false) -> void:
	if not ASSET_PATHS.has(mode):
		mode = "default"
	if mode == current_mode and icon != null and icon.texture != null:
		return
	current_mode = mode
	var size := float(MODE_SIZES.get(mode, 60.0))
	icon.texture = textures.get(mode)
	icon.position = Vector2.ZERO
	icon.size = Vector2.ONE * size
	icon.pivot_offset = icon.size * 0.5
	pointer_root.size = icon.size
	var hotspot := _hotspot_for(mode)
	pointer_root.pivot_offset = hotspot
	halo.position = hotspot - halo.size * 0.5
	halo.visible = mode in HALO_MODES
	halo.add_theme_stylebox_override("panel", _ring_style(MODE_COLORS.get(mode, Color.WHITE)))
	icon.modulate = Color.WHITE
	icon.rotation = 0.0
	if not immediate and not motion_reduced:
		pointer_root.scale = Vector2(0.72, 0.72)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(pointer_root, "scale", Vector2.ONE, 0.14)
	else:
		pointer_root.scale = Vector2.ONE
	mode_changed.emit(mode)


func _hotspot_for(mode: String) -> Vector2:
	var size := float(MODE_SIZES.get(mode, 60.0))
	if mode in CENTERED_MODES:
		return Vector2.ONE * size * 0.5
	return Vector2(4.0, 4.0)


func _cursor_target(control: Control) -> Control:
	var node := control
	var depth := 0
	while node != null and depth < 10:
		if node.has_meta("cursor_mode") or node.has_meta("juice_kind") or node is BaseButton or node is LineEdit or node is ScrollBar:
			return node
		node = node.get_parent_control()
		depth += 1
	return null


func _pending_action() -> Dictionary:
	var action: Variant = game.get("pending_action")
	return action if action is Dictionary else {}


func _can_act() -> bool:
	return bool(game.call("_can_take_player_action")) if game.has_method("_can_take_player_action") else true


func _should_wait() -> bool:
	if String(game.get("screen_name")) != "battle":
		return false
	if bool(game.get("pause_open")) or bool(game.get("settings_open")) or bool(game.get("service_history_open")):
		return false
	return bool(game.get("input_locked")) or not bool(game.get("is_player_turn"))


func _spawn_trail(pointer: Vector2) -> void:
	if trail_layer == null or icon.texture == null:
		return
	if trail_layer.get_child_count() >= MAX_TRAILS:
		trail_layer.get_child(0).queue_free()
	var ghost := TextureRect.new()
	ghost.texture = icon.texture
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.size = Vector2.ONE * minf(48.0, icon.size.x)
	ghost.position = pointer - ghost.size * 0.5
	ghost.pivot_offset = ghost.size * 0.5
	ghost.modulate = Color(MODE_COLORS.get(current_mode, Color.WHITE), 0.28)
	trail_layer.add_child(ghost)
	var tween := ghost.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.18)
	tween.tween_property(ghost, "scale", Vector2(0.55, 0.55), 0.18)
	tween.chain().tween_callback(ghost.queue_free)


func _click_ripple(color: Color, strength := 1.0) -> void:
	if motion_reduced or trail_layer == null:
		return
	var ripple := Panel.new()
	ripple.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ripple.position = last_pointer - Vector2(5, 5)
	ripple.size = Vector2(10, 10)
	ripple.pivot_offset = ripple.size * 0.5
	ripple.modulate = Color(color, 0.82)
	ripple.add_theme_stylebox_override("panel", _ring_style(color, 2))
	trail_layer.add_child(ripple)
	var target_size := Vector2.ONE * 44.0 * strength
	var tween := ripple.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ripple, "position", last_pointer - target_size * 0.5, 0.22)
	tween.tween_property(ripple, "size", target_size, 0.22)
	tween.tween_property(ripple, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(ripple.queue_free)


func _clear_trails() -> void:
	if trail_layer == null:
		return
	for child in trail_layer.get_children():
		child.queue_free()


func _ring_style(color: Color, width := 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.02, 0.06, 0.24)
	style.border_color = Color(color, 0.84)
	style.set_border_width_all(width)
	style.set_corner_radius_all(32)
	style.shadow_color = Color(color, 0.25)
	style.shadow_size = 4
	return style
