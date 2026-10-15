extends Control
## PvP presentation shared by browser and native clients; the server owns authority.

const DB := preload("res://scripts/card_database.gd")
const L10N := preload("res://scripts/localization.gd")
const TARGET_LINE := preload("res://scripts/juice_target_line.gd")
const NATIVE_CLIENT := preload("res://scripts/multiplayer_native_client.gd")
const GOLD := Color("#FFD36A")
const CREAM := Color("#F7E9C8")
const TEAL := Color("#55C6A9")
const MUTED := Color("#BBAF9A")
const PLUM := Color("#24122E")
const RED := Color("#D95757")
const CONNECTION_SUCCESS_SFX := preload("res://assets/template/cardgame/sfx/summon.wav")


class ConnectionSpinner:
	extends Control

	var angle := 0.0
	var pulse := 0.0
	var accent := Color("#55C6A9")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _process(delta: float) -> void:
		angle = fmod(angle + delta * 4.6, TAU)
		pulse = fmod(pulse + delta * 2.4, 1.0)
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := maxf(5.0, minf(size.x, size.y) * 0.34)
		draw_arc(center, radius, 0.0, TAU, 40, Color(accent, 0.18), 4.0, true)
		draw_arc(center, radius, angle, angle + PI * 0.82, 18, accent, 5.0, true)
		for index in range(3):
			var alpha := 0.25 + 0.65 * maxf(0.0, 1.0 - absf(pulse * 3.0 - float(index)))
			draw_circle(Vector2(center.x - 12.0 + index * 12.0, size.y - 4.0), 2.5, Color(accent, alpha))


var bridge: Object
var state: Dictionary = {"screen": "setup", "status": "setup"}
var layer: Control
var name_value := "Chef"
var invite_value := ""
var name_initialized := false
var selected_opponent := 0
var selected_card: Dictionary = {}
var selected_unit := 0
var rules: Dictionary = {}
var countdown: Label
var elapsed := 0.0
var feedback_audio: AudioStreamPlayer
var connection_feedback_count := 0
var celebrated_peer_connections := {}


func _ready() -> void:
	L10N.apply_font(self)
	feedback_audio = AudioStreamPlayer.new()
	feedback_audio.name = "MultiplayerConnectionSFX"
	feedback_audio.stream = CONNECTION_SUCCESS_SFX
	feedback_audio.bus = "UI"
	feedback_audio.volume_db = -5.0
	feedback_audio.pitch_scale = 0.95
	add_child(feedback_audio)
	resized.connect(_fit_canvas)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(FileAccess.get_file_as_string("res://multiplayer/rules.js"), true)
		JavaScriptBridge.eval(FileAccess.get_file_as_string("res://multiplayer/client.js"), true)
		bridge = JavaScriptBridge.get_interface("EmberpanMP")
		rules = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(EmberpanRules.CARDS)")))
	else:
		bridge = NATIVE_CLIENT.new()
		add_child(bridge)
		rules = JSON.parse_string(FileAccess.get_file_as_string("res://multiplayer/cards.json"))
	bridge.configure(FileAccess.get_file_as_string("res://multiplayer/config.json"))
	_poll()
	_render()


func _exit_tree() -> void:
	# Native shutdown preserves the reserved seat; explicit navigation sends leave.
	if bridge != null and OS.has_feature("web"):
		bridge.dispose()
	if is_instance_valid(feedback_audio):
		feedback_audio.stop()
		feedback_audio.stream = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (not selected_card.is_empty() or selected_unit != 0):
		selected_card = {}
		selected_unit = 0
		_render()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_poll()
	elapsed += delta
	if elapsed >= 0.5 and is_instance_valid(countdown):
		elapsed = 0.0
		var snapshot: Dictionary = state.get("snapshot", {}) if state.get("snapshot") != null else {}
		var seconds := maxi(0, int((float(snapshot.get("deadline", 0)) / 1000.0) - Time.get_unix_time_from_system() - float(state.get("serverOffsetMs", 0)) / 1000.0))
		countdown.text = t("timer", {"seconds": seconds}) if state.get("status") == "connected" else t("timer_paused")


func _poll() -> void:
	if bridge == null:
		return
	var payload := str(bridge.drain())
	if payload.is_empty():
		return
	var next_state: Variant = JSON.parse_string(payload)
	if not next_state is Dictionary:
		return
	var previous_revision := int(state.get("snapshot", {}).get("revision", -1)) if state.get("snapshot") is Dictionary else -1
	state = next_state
	if not name_initialized and not str(state.get("playerName", "")).is_empty():
		name_value = str(state.playerName)
		name_initialized = true
	if invite_value.is_empty():
		invite_value = str(state.get("invitation", ""))
	if state.get("snapshot") is Dictionary and int(state.snapshot.revision) != previous_revision:
		selected_card = {}
		selected_unit = 0
	_render()
	_maybe_play_connection_feedback()


func t(key: String, values: Dictionary = {}) -> String:
	if not L10N.catalog_keys("en").has("mp." + key):
		return L10N.t("mp.error.generic", {"code": key.trim_prefix("error.").trim_prefix("status.")})
	var formatted := values.duplicate()
	for field: String in formatted:
		if formatted[field] is float and formatted[field] == floorf(formatted[field]):
			formatted[field] = int(formatted[field])
	return L10N.t("mp." + key, formatted)


func _command(data: Dictionary) -> void:
	if bridge != null:
		bridge.command(JSON.stringify(data))
		_poll()


func _place(node: Control, rect: Rect2) -> Control:
	layer.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node


func _label(value: String, rect: Rect2, font_size := 20, color := CREAM) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(label, rect)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = value
	return label


func _style(color: Color, border := TEAL) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style


func _button(value: String, rect: Rect2, callback: Callable, disabled := false, accent := TEAL) -> Button:
	var button := Button.new()
	button.clip_text = true
	button.text = value
	button.disabled = disabled
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_disabled_color", CREAM)
	button.add_theme_stylebox_override("normal", _style(PLUM, accent))
	button.add_theme_stylebox_override("hover", _style(Color("#44314F"), GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("#182E30"), GOLD))
	button.add_theme_stylebox_override("disabled", _style(Color("#211D27"), Color("#554759")))
	button.pressed.connect(callback)
	_place(button, rect)
	return button


func _line_edit(value: String, placeholder: String, rect: Rect2, changed: Callable) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = value
	edit.placeholder_text = placeholder
	edit.add_theme_font_size_override("font_size", 21)
	edit.add_theme_stylebox_override("normal", _style(PLUM))
	edit.text_changed.connect(changed)
	_place(edit, rect)
	return edit


func _connection_status_key() -> String:
	var stage := str(state.get("connectionStage", ""))
	if not stage.is_empty() and L10N.catalog_keys(L10N.current_locale()).has("mp.status." + stage):
		return "status." + stage
	return "status." + str(state.get("status", "setup"))


func _connection_status_text() -> String:
	return t(_connection_status_key())


func _spinner(rect: Rect2, name: String, accent := TEAL) -> ConnectionSpinner:
	var spinner := ConnectionSpinner.new()
	spinner.name = name
	spinner.accent = accent
	_place(spinner, rect)
	return spinner


func _begin_connection(mode: String) -> void:
	state["screen"] = "connecting"
	state["status"] = "connecting"
	state["connectionMode"] = mode
	state["connectionStage"] = "contacting_lobby"
	state["error"] = ""
	_render()
	match mode:
		"host": _command({"op": "host", "name": name_value})
		"join": _command({"op": "join", "name": name_value, "invitation": invite_value})
		"resume": _command({"op": "resume"})


func _connected_peer_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	var room: Dictionary = state.get("room", {}) if state.get("room") is Dictionary else {}
	var members: Array = room.get("members", [])
	for member: Dictionary in members:
		if int(member.get("id", 0)) == int(state.get("id", 0)):
			continue
		if member.get("connected", false):
			keys.append("%d:%d" % [int(member.get("id", 0)), int(member.get("generation", 0))])
	return keys


func _maybe_play_connection_feedback(play_audio := true) -> void:
	if str(state.get("screen", "")) == "setup":
		celebrated_peer_connections.clear()
		return
	if str(state.get("status", "")) != "connected":
		return
	if str(state.get("screen", "")) not in ["lobby", "match"]:
		return
	var found_new_peer := false
	for key: String in _connected_peer_keys():
		if not celebrated_peer_connections.has(key):
			celebrated_peer_connections[key] = true
			found_new_peer = true
	if found_new_peer:
		_play_connection_success_feedback(play_audio)


func _play_connection_success_feedback(play_audio := true) -> void:
	if not is_instance_valid(layer):
		return
	connection_feedback_count += 1
	if play_audio and is_instance_valid(feedback_audio):
		feedback_audio.stop()
		feedback_audio.play()
	var origin := Vector2(640, 330)
	for index in range(26):
		var angle := (TAU * float(index) / 26.0) - PI * 0.5
		var particle := Polygon2D.new()
		particle.name = "ConnectionSuccessParticle"
		particle.polygon = PackedVector2Array([Vector2(0, -6), Vector2(3, -1), Vector2(7, 0), Vector2(3, 1), Vector2(0, 6), Vector2(-3, 1), Vector2(-7, 0), Vector2(-3, -1)])
		particle.color = GOLD if index % 3 == 0 else TEAL
		particle.position = origin + Vector2(cos(angle) * 268.0, sin(angle) * 72.0)
		particle.rotation = float(index) * 0.71
		particle.z_index = 12
		layer.add_child(particle)
		var distance := 310.0 + float(index % 5) * 16.0
		var destination := origin + Vector2(cos(angle) * distance, sin(angle) * distance * 0.5)
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "position", destination, 0.72)
		tween.tween_property(particle, "rotation", particle.rotation + PI * 1.5, 0.72)
		tween.tween_property(particle, "scale", Vector2(0.18, 0.18), 0.72)
		tween.tween_property(particle, "modulate:a", 0.0, 0.72).set_delay(0.18)
		tween.chain().tween_callback(particle.queue_free)
	var banner := Panel.new()
	banner.name = "ConnectionSuccessBanner"
	banner.z_index = 10
	banner.add_theme_stylebox_override("panel", _style(Color(0.06, 0.16, 0.16, 0.96), GOLD))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(banner, Rect2(380, 270, 520, 120))
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2(0.94, 0.94)
	var headline := Label.new()
	headline.text = t("connection_success")
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	headline.add_theme_font_size_override("font_size", 28)
	headline.add_theme_color_override("font_color", GOLD)
	banner.add_child(headline)
	headline.position = Vector2(20, 16)
	headline.size = Vector2(480, 46)
	var detail := Label.new()
	detail.text = t("connection_success_detail")
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 17)
	detail.add_theme_color_override("font_color", CREAM)
	banner.add_child(detail)
	detail.position = Vector2(20, 61)
	detail.size = Vector2(480, 35)
	var banner_tween := create_tween()
	banner_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.18)
	banner_tween.tween_interval(1.25)
	banner_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	banner_tween.set_parallel(true)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 0.24)
	banner_tween.tween_property(banner, "position:y", banner.position.y - 20.0, 0.24)
	banner_tween.chain().tween_callback(banner.queue_free)


func _render_connecting() -> void:
	var mode := str(state.get("connectionMode", "join"))
	var title_key := "connecting_join"
	if mode == "host":
		title_key = "connecting_host"
	elif mode == "resume":
		title_key = "connecting_resume"
	_label(t(title_key), Rect2(260, 180, 760, 54), 30, GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spinner(Rect2(580, 252, 120, 120), "PrimaryConnectionSpinner", GOLD)
	var progress := _label(_connection_status_text(), Rect2(240, 387, 800, 48), 22, TEAL)
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _label(t("connecting_hint"), Rect2(240, 438, 800, 62), 18, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(t("cancel"), Rect2(470, 540, 340, 56), func(): _command({"op": "leave"}))


func _render() -> void:
	if is_instance_valid(layer):
		remove_child(layer)
		layer.queue_free()
	countdown = null
	layer = Control.new()
	add_child(layer)
	_fit_canvas()
	var background := TextureRect.new()
	background.texture = DB.art("battle_board" if state.get("screen") == "match" else "title_kitchen")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(background, Rect2(0, 0, 1280, 720))
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.02, 0.08, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(shade, Rect2(0, 0, 1280, 720))
	_label(t("heading"), Rect2(40, 18, 840, 50), 34, GOLD)
	_label(_connection_status_text(), Rect2(42, 69, 880, 34), 18, TEAL)
	var error_code := str(state.get("error", ""))
	if not error_code.is_empty():
		_label(t("error." + error_code), Rect2(40, 661, 1060, 50), 18, RED)
	match str(state.get("screen", "setup")):
		"setup": _render_setup()
		"connecting": _render_connecting()
		"lobby": _render_lobby()
		"match": _render_match()
		"ended":
			_label(t("ended_hint"), Rect2(240, 230, 800, 140), 26)
			_button(t("back_rooms"), Rect2(440, 430, 400, 58), func(): _command({"op": "leave"}))


func _render_setup() -> void:
	_button(t("back_title"), Rect2(1020, 30, 220, 44), _back_title)
	_label(t("intro"), Rect2(70, 120, 1140, 64), 22)
	_label(t("name"), Rect2(90, 198, 410, 30), 18, MUTED)
	var name_input := _line_edit(name_value, t("name"), Rect2(90, 236, 410, 50), func(value: String): name_value = value)
	name_input.max_length = 24
	var host_button := _button(t("host"), Rect2(90, 310, 410, 65), func(): _begin_connection("host"), bridge == null)
	host_button.name = "HostRoomButton"
	var resume_button := _button(t("resume"), Rect2(90, 400, 410, 54), func(): _begin_connection("resume"), bridge == null or not state.get("canResume", false))
	resume_button.name = "ResumeRoomButton"
	_label(t("invite"), Rect2(600, 198, 590, 30), 18, MUTED)
	_line_edit(invite_value, t("invite_placeholder"), Rect2(600, 236, 590, 50), func(value: String): invite_value = value)
	var join_button := _button(t("join"), Rect2(600, 310, 590, 65), func(): _begin_connection("join"), bridge == null)
	join_button.name = "JoinRoomButton"
	_label(t("host_warning"), Rect2(600, 390, 590, 100), 20, MUTED)
	_label(t("one_click_hint"), Rect2(90, 525, 410, 96), 20, TEAL)
	var service_message := "service_ready"
	if state.get("service") == "checking":
		service_message = "service_checking"
	elif state.get("service") == "unavailable":
		service_message = "service_unavailable"
	_label(t(service_message), Rect2(600, 525, 590, 96), 20, MUTED)


func _loadout_name(kind: String, choice: String) -> String:
	if kind == "legendary":
		return L10N.t("card.%s.name" % choice)
	return t("%s.%s" % [kind, choice])


func _loadout_picker(kind: String, choices: Array, selected: String, loadout: Dictionary, rect: Rect2, catalog: Dictionary) -> void:
	_label(t("loadout_" + kind), Rect2(rect.position.x, rect.position.y - 27, rect.size.x, 25), 18, GOLD)
	var picker := OptionButton.new()
	picker.name = "Loadout" + kind.capitalize()
	picker.add_theme_font_size_override("font_size", 18)
	L10N.apply_font(picker)
	for index in range(choices.size()):
		var choice := str(choices[index])
		picker.add_item(_loadout_name(kind, choice))
		if choice == selected:
			picker.select(index)
	picker.disabled = str(state.get("status", "")) == "reconnecting"
	picker.item_selected.connect(func(index: int):
		var updated := loadout.duplicate()
		updated[kind] = str(choices[index])
		_command({"op": "loadout", "loadout": updated})
	)
	_place(picker, rect)
	var details := ""
	if kind == "starter":
		var counts := {}
		for card in catalog.get("starters", {}).get(selected, []):
			counts[card] = int(counts.get(card, 0)) + 1
		for card in counts:
			details += "%d × %s\n" % [counts[card], L10N.t("card.%s.name" % card)]
	elif kind == "legendary":
		details = L10N.t("mp.card." + selected)
	else:
		details = t("hero_cosmetic")
	picker.tooltip_text = details


func _render_lobby() -> void:
	var room: Dictionary = state.get("room", {})
	_button(t("leave"), Rect2(1030, 30, 210, 44), func(): _command({"op": "leave"}), false, RED)
	_label(t("room", {"room": room.get("id", "")}), Rect2(65, 120, 1100, 44), 25)
	_label(_connection_status_text(), Rect2(65, 157, 1100, 32), 17, TEAL)
	var members: Array = room.get("members", [])
	for index in range(2):
		var member: Dictionary = members[index] if index < members.size() else {}
		var text := t("empty_seat")
		var transport_ready := false
		if not member.is_empty():
			transport_ready = member.get("connected", false) and member.get("peerReady", str(state.get("status", "")) == "connected")
			text = str(member.name) + " · " + _loadout_name("hero", str(member.get("loadout", {}).get("hero", "chef_sama"))) + (" · " + t("host_badge") if int(member.id) == int(room.get("leader", 1)) else "")
			if not transport_ready:
				text += "  —  " + t("connecting")
			elif member.get("ready", false):
				text += "  —  " + t("ready")
			else:
				text += "  —  " + t("not_ready")
		_label(text, Rect2(90, 195 + index * 60, 1030, 54), 22, CREAM if not member.is_empty() else MUTED)
		if not member.is_empty() and not transport_ready:
			_spinner(Rect2(1140, 202 + index * 60, 36, 36), "SeatConnectionSpinner%d" % index)
	var loadout: Dictionary = {"starter": "balanced", "hero": "chef_sama", "legendary": "mise_the_thousand_handed"}
	for member: Dictionary in members:
		if int(member.id) == int(state.get("id", 0)):
			loadout = member.get("loadout", loadout)
	var catalog: Dictionary = room.get("catalog", {})
	if not catalog.is_empty():
		_loadout_picker("starter", catalog.get("starters", {}).keys(), str(loadout.starter), loadout, Rect2(90, 345, 300, 48), catalog)
		_loadout_picker("hero", catalog.get("heroes", []), str(loadout.hero), loadout, Rect2(410, 345, 330, 48), catalog)
		_loadout_picker("legendary", catalog.get("legendaries", []), str(loadout.legendary), loadout, Rect2(760, 345, 430, 48), catalog)
	_label(t("loadout_hint"), Rect2(620, 410, 570, 48), 16, MUTED)
	if int(state.get("id", 0)) == int(room.get("leader", 1)):
		var invite := _line_edit(str(state.get("invitation", "")), "", Rect2(90, 473, 800, 48), func(_value: String): pass)
		invite.editable = false
		_button(t("status.copied") if state.get("inviteCopied", false) else t("copy_invite"), Rect2(910, 473, 280, 48), func(): _command({"op": "copy"}))
		_button(t("start"), Rect2(680, 563, 510, 64), func(): _command({"op": "start"}), not state.get("canStart", false), GOLD)
	else:
		_label(t("waiting_host"), Rect2(90, 483, 1100, 70), 25, GOLD)
	_button(t("unready_button") if state.get("ready", false) else t("ready_button"), Rect2(90, 410, 510, 48), func(): _command({"op": "ready"}), state.get("status") == "reconnecting", TEAL)
	_label(t("lobby_hint"), Rect2(90, 558, 540, 78), 19, MUTED)


func _render_match() -> void:
	_button(t("leave"), Rect2(1060, 30, 180, 42), func(): _command({"op": "leave"}), false, RED)
	if not state.get("snapshot") is Dictionary:
		_label(t("syncing"), Rect2(250, 280, 780, 100), 28)
		return
	var snapshot: Dictionary = state.snapshot
	var players: Array = snapshot.players
	var own: Dictionary = {}
	var opponents: Array = []
	for player: Dictionary in players:
		if int(player.id) == int(state.id):
			own = player
		else:
			opponents.append(player)
	if own.is_empty():
		return
	if opponents.is_empty():
		return
	var opponent: Dictionary = opponents[0]
	selected_opponent = int(opponent.id)
	_label("%s · ♥ %d" % [opponent.name, opponent.health], Rect2(40, 113, 900, 44), 25, GOLD)
	var can_act: bool = int(snapshot.active) == int(state.id) and own.alive and snapshot.status == "playing" and state.get("status") == "connected"
	_card_art(str(opponent.get("hero", "chef_sama")), Rect2(905, 105, 68, 68))
	_label(t("hero_stats", {"name": opponent.name, "health": opponent.health, "armor": opponent.armor, "cards": opponent.handCount, "deck": opponent.deckCount}), Rect2(40, 165, 840, 34), 20)
	_button(t("target_hero"), Rect2(990, 113, 250, 44), func(): _target(int(opponent.id), 0), not can_act or not opponent.alive)
	for index in range(opponent.board.size()):
		_unit(opponent.board[index], Rect2(240 + index * 207, 207, 195, 108), int(opponent.id), false, can_act)
	var active_name := ""
	for player: Dictionary in players:
		if int(player.id) == int(snapshot.active):
			active_name = player.name
	_label(t("turn", {"name": active_name, "turn": snapshot.turn}), Rect2(40, 322, 860, 42), 24, GOLD)
	countdown = _label("", Rect2(1060, 322, 180, 42), 21, MUTED)
	_card_art(str(own.get("hero", "chef_sama")), Rect2(930, 345, 58, 58))
	_label(t("own_stats", {"health": own.health, "armor": own.armor, "mana": own.mana, "maximum": own.maxMana, "deck": own.deckCount}), Rect2(40, 365, 850, 36), 21, TEAL)
	for index in range(own.board.size()):
		_unit(own.board[index], Rect2(240 + index * 207, 409, 195, 106), int(own.id), true, can_act)
	_button(t("end_turn"), Rect2(1050, 420, 190, 80), func(): _action({"kind": "end"}), not can_act, GOLD)
	var hand: Array = own.get("hand", [])
	for index in range(hand.size()):
		var card: Dictionary = hand[index]
		var definition: Dictionary = rules.get(card.card, {})
		var rect := Rect2(40 + index * 150, 531, 142, 118)
		_card_art(str(card.card), rect)
		var label := "%d · %s" % [definition.get("cost", 0), L10N.t("card.%s.name" % card.card)]
		var button := _button(label, rect, func(): _select_card(card), not can_act or int(own.mana) < int(definition.get("cost", 0)), GOLD if selected_card.get("id") == card.id else TEAL)
		button.add_theme_font_size_override("font_size", 15)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_stylebox_override("normal", _style(Color(0.08, 0.03, 0.1, 0.60), GOLD if selected_card.get("id") == card.id else TEAL))
		button.add_theme_stylebox_override("disabled", _style(Color(0.08, 0.03, 0.1, 0.64), Color("#554759")))
		button.tooltip_text = L10N.t("mp.card." + str(card.card))
		if selected_card.get("id") == card.id:
			_arrow(button)
	if not selected_card.is_empty():
		_label(L10N.t("mp.card." + str(selected_card.card)) + "  ·  " + t("choose_target"), Rect2(40, 666, 1110, 38), 19, GOLD)
	elif selected_unit != 0:
		_label(t("choose_attack"), Rect2(40, 666, 1110, 38), 19, GOLD)
	elif str(state.get("error", "")).is_empty():
		var activity: Dictionary = state.get("activity", {})
		var hint := t("battle_hint")
		if snapshot.status == "playing" and not activity.is_empty() and int(activity.get("actor", 0)) != int(state.id) and int(activity.get("revision", -1)) >= int(snapshot.revision):
			hint = t("activity", {"name": str(activity.get("name", ""))})
		_label(hint, Rect2(40, 666, 1110, 38), 17, MUTED)
	if snapshot.status == "ended":
		var result := t("draw") if snapshot.winner == null else t("winner", {"name": _player_name(players, int(snapshot.winner))})
		var panel := Panel.new()
		panel.add_theme_stylebox_override("panel", _style(PLUM, GOLD))
		_place(panel, Rect2(240, 215, 800, 320))
		_label(result, Rect2(280, 260, 720, 75), 36, GOLD)
		_button(t("rematch_waiting") if state.get("rematch", false) else t("rematch"), Rect2(380, 350, 520, 64), func(): _command({"op": "rematch"}), not state.get("canRematch", false))
		_button(t("back_rooms"), Rect2(380, 438, 520, 64), func(): _command({"op": "leave"}))


func _player_name(players: Array, id: int) -> String:
	for player: Dictionary in players:
		if int(player.id) == id:
			return str(player.name)
	return ""


func _card_art(card: String, rect: Rect2) -> void:
	var art := TextureRect.new()
	art.texture = DB.art(card)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(art, rect)


func _unit(unit: Dictionary, rect: Rect2, player: int, own: bool, can_act: bool) -> void:
	_card_art(str(unit.card), rect)
	var text := L10N.t("card.%s.name" % unit.card) + "\n" + t("unit_stats", {"attack": unit.attack, "health": unit.health})
	text += "\n" + (t("guard") if unit.guard else "") + (" · " + t("unit_ready") if own and unit.ready else "")
	var button := _button(text, rect, func():
		if own and selected_card.is_empty():
			selected_unit = int(unit.id)
			_render()
		else:
			_target(player, int(unit.id))
	, not can_act, GOLD if selected_unit == int(unit.id) else TEAL)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", _style(Color(0.08, 0.03, 0.1, 0.64), GOLD if selected_unit == int(unit.id) else TEAL))
	button.add_theme_stylebox_override("disabled", _style(Color(0.08, 0.03, 0.1, 0.64), Color("#554759")))
	if selected_unit == int(unit.id):
		_arrow(button)


func _arrow(source: Control) -> void:
	var arrow := TARGET_LINE.new()
	layer.add_child(arrow)
	arrow.configure(source.position + source.size * 0.5, GOLD)


func _select_card(card: Dictionary) -> void:
	selected_unit = 0
	selected_card = card
	var definition: Dictionary = rules.get(card.card, {})
	if not definition.has("target"):
		_action({"kind": "play", "card": int(card.id)})
	else:
		_render()


func _target(player: int, unit: int) -> void:
	var action := {"targetPlayer": player}
	if unit != 0:
		action["targetUnit"] = unit
	if not selected_card.is_empty():
		action["kind"] = "play"
		action["card"] = int(selected_card.id)
	elif selected_unit != 0:
		action["kind"] = "attack"
		action["unit"] = selected_unit
	else:
		return
	_action(action)


func _action(action: Dictionary) -> void:
	selected_card = {}
	selected_unit = 0
	_command({"op": "action", "action": action})


func _back_title() -> void:
	_command({"op": "leave"})
	get_tree().change_scene_to_file("res://scenes/card_game.tscn")


func _fit_canvas() -> void:
	if not is_instance_valid(layer):
		return
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	layer.size = Vector2(1280, 720)
	layer.scale = Vector2.ONE * factor
	layer.position = (size - Vector2(1280, 720) * factor) * 0.5
