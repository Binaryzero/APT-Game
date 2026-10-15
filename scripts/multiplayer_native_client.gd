extends Node
## Native counterpart of multiplayer/client.js. The dedicated server owns all gameplay.

var storage_namespace := ""
var state: Dictionary = _setup_state()
var config: Dictionary = {}
var defaults: Dictionary = {}
var ws: WebSocketPeer
var auth: Dictionary = {}
var active := false
var pending := false
var dirty := true
var disposed := false
var retry := 0
var _preparing := false
var _attempt := 0
var _storage_path := ""
var _preferences: Dictionary = {}
var _request: HTTPRequest
var _socket_hello_sent := false
var _socket_closed_handled := false
var _opened_at := 0
var _socket_opened_at := 0
var _last_packet := 0
var _last_ping := 0
var _disconnected_at := 0
var _retry_at := 0
var _timeouts: Dictionary = {}
var _tick_elapsed := 0.0

static func _setup_state() -> Dictionary:
	return {"screen": "setup", "status": "setup", "connectionMode": "", "connectionStage": "", "id": 0, "room": null, "snapshot": null, "error": ""}

func configure(json: String) -> void:
	var parsed: Variant = JSON.parse_string(json)
	if not parsed is Dictionary:
		_error("invalid_service_config")
		return
	defaults = parsed.duplicate(true)
	config = defaults.duplicate(true)
	_storage_path = "user://emberpan-pvp-%s.json" % (ProjectSettings.globalize_path("res://") + str(config.get("build", "")) + storage_namespace).sha256_text()
	if FileAccess.file_exists(_storage_path):
		var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(_storage_path))
		if stored is Dictionary:
			_preferences = stored
	_setup()
	_prepare()

func _setup() -> void:
	state["config"] = config
	state["playerName"] = str(_preferences.get("name", ""))
	state["invitation"] = ""
	state["canResume"] = not _saved().is_empty()

func drain() -> String:
	if not dirty:
		return ""
	dirty = false
	return JSON.stringify(state)

func _error(code: String) -> void:
	state["error"] = code
	dirty = true

func _write_preferences() -> void:
	if _storage_path.is_empty():
		return
	var file := FileAccess.open(_storage_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_preferences))

func _saved() -> Dictionary:
	var saved: Variant = _preferences.get("resume")
	if not saved is Dictionary or not _integer(saved.get("id")) or saved.id < 1 or not saved.get("room") is String or not saved.get("token") is String:
		return {}
	if not _validate_url(str(saved.get("endpoint", ""))).is_empty():
		return {}
	return saved

func _clear_saved() -> void:
	_preferences.erase("resume")
	_preferences.erase("invitation")
	_write_preferences()
	state["canResume"] = false

func _prepare(refresh := false, room := "") -> bool:
	if _preparing:
		while _preparing and not disposed:
			await get_tree().process_frame
		return not disposed and state.get("service") == "ready"
	if disposed:
		return false
	if not refresh and state.get("service") == "ready":
		return true
	_preparing = true
	state["service"] = "checking"
	dirty = true
	var discovered: Dictionary = await _discover(room)
	_preparing = false
	if disposed:
		return false
	if discovered.is_empty():
		state["service"] = "unavailable"
		dirty = true
		return false
	config = discovered
	state["config"] = config
	state["service"] = "ready"
	state["canResume"] = not _saved().is_empty()
	dirty = true
	return true

func _preview_url() -> String:
	var port := OS.get_environment("PORT")
	if not port.is_valid_int() or port.to_int() < 1 or port.to_int() > 65535:
		port = "3000"
	return str(defaults.get("previewUrl", "http://127.0.0.1:" + port)).trim_suffix("/")

func _discover(room := "") -> Dictionary:
	var discovered := defaults.duplicate(true)
	var managed_url := OS.get_environment("GAME_MULTIPLAYER_DISCOVERY_URL")
	if not managed_url.is_empty():
		managed_url = _managed_discovery_url(managed_url, room)
		if managed_url.is_empty():
			return {}
		var response := await _request_descriptor(managed_url)
		# Operator-managed discovery owns the deployment choice. Never fall through
		# to a stale configured service when that route is unavailable or invalid.
		if disposed or response.is_empty() or response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
			return {}
		var managed: Variant = JSON.parse_string(response[3].get_string_from_utf8())
		if not _valid_descriptor(managed) or not _public_endpoint(str(managed.signalingUrl)):
			return {}
		discovered.merge(managed, true)
		return _validated_config(discovered, str(managed.signalingUrl))
	var endpoint := OS.get_environment("GAME_MULTIPLAYER_SIGNALING_URL")
	if not endpoint.is_empty():
		return _validated_config(discovered, endpoint)
	var bootstrap := str(defaults.get("bootstrapUrl", "multiplayer/bootstrap.json"))
	if not bootstrap.is_empty():
		# The native preview and the web export use the same managed descriptor.
		# Configuration is trusted project data; invitations never set this base or endpoint.
		if bootstrap.contains(":") or bootstrap.begins_with("//") or bootstrap.contains("..") or not _valid_preview_url(_preview_url()):
			return {}
		var response := await _request_descriptor(_preview_url() + "/" + bootstrap.trim_prefix("/"))
		if disposed:
			return {}
		if not response.is_empty() and response[0] == HTTPRequest.RESULT_SUCCESS:
			if response[1] == 200:
				var managed: Variant = JSON.parse_string(response[3].get_string_from_utf8())
				if not _valid_descriptor(managed):
					return {}
				discovered.merge(managed, true)
				return _validated_config(discovered, str(managed.signalingUrl))
			if response[1] != 404:
				return {}
		elif not response.is_empty() and response[0] in [HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED, HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED]:
			return {}
		# A standalone native game may have no preview server running. Its packaged
		# descriptor or configured endpoint remains a usable fallback in that case.
		var local_path := "res://" + bootstrap.trim_prefix("/")
		if FileAccess.file_exists(local_path):
			var file := FileAccess.open(local_path, FileAccess.READ)
			if not file or file.get_length() > 4096:
				return {}
			var local: Variant = JSON.parse_string(file.get_as_text())
			if not _valid_descriptor(local):
				return {}
			discovered.merge(local, true)
	return _validated_config(discovered, str(discovered.get("signalingUrl", "")))

func _request_descriptor(url: String) -> Array:
	_request = HTTPRequest.new()
	_request.timeout = 8.0
	_request.max_redirects = 0
	_request.body_size_limit = 4096
	add_child(_request)
	var request := _request
	# This public route uses no cookies, bearer tokens, or client credentials.
	var result := request.request(url, ["Cache-Control: no-cache"])
	var response: Array = []
	if result == OK:
		response = await request.request_completed
	request.queue_free()
	_request = null
	return response

func _managed_discovery_url(url: String, room := "") -> String:
	if not room.is_empty() and not RegEx.create_from_string("^[a-zA-Z0-9_-]{1,64}$").search(room):
		return ""
	for character: int in url.to_utf8_buffer():
		if character <= 32 or character == 127:
			return ""
	var pattern := RegEx.create_from_string("^https://(\\[[0-9a-fA-F:]+\\]|[a-zA-Z0-9.-]+)(?::([0-9]{1,5}))?(/[^?#]*)?(?:\\?([^#]*))?$")
	var found := pattern.search(url)
	if not found or (not found.get_string(2).is_empty() and (found.get_string(2).to_int() < 1 or found.get_string(2).to_int() > 65535)):
		return ""
	var query := PackedStringArray()
	var escapes := RegEx.create_from_string("%[0-9a-fA-F]{2}")
	for field: String in found.get_string(4).split("&", false):
		var name := field.get_slice("=", 0).replace("+", " ")
		for escaped: RegExMatch in escapes.search_all(name):
			name = name.replace(escaped.get_string(), escaped.get_string().to_upper())
		if name.uri_decode() not in ["build", "room", "mode"]:
			query.append(field)
	query.append("build=" + str(defaults.get("build", "")).uri_encode())
	if not room.is_empty():
		query.append("room=" + room.uri_encode())
	return url.get_slice("?", 0) + "?" + "&".join(query)

func _public_endpoint(endpoint: String) -> bool:
	if not endpoint.begins_with("wss://") or not _validate_url(endpoint).is_empty():
		return false
	var authority := endpoint.trim_prefix("wss://").get_slice("/", 0).to_lower()
	if authority.begins_with("["):
		var address := authority.get_slice("]", 0).trim_prefix("[")
		# Reject both compressed and expanded IPv6 loopback/unspecified literals.
		return address.replace(":", "").lstrip("0") not in ["", "1"]
	var host := authority.get_slice(":", 0).trim_suffix(".")
	return host not in ["localhost", "0.0.0.0"] and not host.ends_with(".localhost") and not host.begins_with("127.") and not host.is_valid_int()

func _validated_config(discovered: Dictionary, endpoint: String) -> Dictionary:
	if endpoint.begins_with("/") and not endpoint.begins_with("//") and _valid_preview_url(_preview_url()):
		endpoint = _preview_url().replace("https://", "wss://").replace("http://", "ws://") + endpoint
	if not _validate_url(endpoint).is_empty() or discovered.get("iceTransportPolicy", "all") not in ["all", "relay"]:
		return {}
	discovered["signalingUrl"] = endpoint
	return discovered

func _valid_descriptor(value: Variant) -> bool:
	return value is Dictionary and value.get("version") == 1 and value.get("build") == defaults.get("build") and value.get("signalingUrl") is String

func _valid_preview_url(url: String) -> bool:
	var pattern := RegEx.create_from_string("^https?://(\\[[0-9a-fA-F:]+\\]|[a-zA-Z0-9.-]+)(?::([0-9]{1,5}))?$")
	var found := pattern.search(url)
	if not found:
		return false
	if url.begins_with("http://") and found.get_string(1) not in ["localhost", "127.0.0.1", "[::1]"]:
		return false
	return found.get_string(2).is_empty() or (found.get_string(2).to_int() > 0 and found.get_string(2).to_int() <= 65535)

func _validate_url(url: String) -> String:
	if url.is_empty():
		return "service_not_configured"
	var pattern := RegEx.create_from_string("^(wss?)://(\\[[0-9a-fA-F:]+\\]|[a-zA-Z0-9.-]+)(?::([0-9]{1,5}))?/ws$")
	var found := pattern.search(url)
	if not found:
		return "invalid_service_url"
	if not found.get_string(3).is_empty() and (found.get_string(3).to_int() < 1 or found.get_string(3).to_int() > 65535):
		return "invalid_service_url"
	if found.get_string(1) == "ws" and found.get_string(2) not in ["localhost", "127.0.0.1", "[::1]"]:
		return "secure_service_required"
	return ""

func parse_invitation(value: Variant) -> Dictionary:
	if not value is String or value.length() > 2048:
		return {}
	var room := ""
	var invite := ""
	if value.contains("#"):
		var base: String = value.get_slice("#", 0)
		var authority: String = base.trim_prefix("https://").trim_prefix("http://").get_slice("/", 0)
		if not (base.begins_with("https://") or base.begins_with("http://")) or authority.is_empty() or authority.contains("@"):
			return {}
		for field: String in value.get_slice("#", 1).split("&"):
			if not field.contains("="):
				continue
			var key := field.get_slice("=", 0).uri_decode()
			var entry := field.get_slice("=", 1).uri_decode()
			if key == "room" and room.is_empty():
				room = entry
			elif key == "invite" and invite.is_empty():
				invite = entry
	else:
		var parts: PackedStringArray = value.strip_edges().split(".")
		if parts.size() < 2:
			return {}
		room = parts[0]
		invite = parts[1]
	if not RegEx.create_from_string("^[a-zA-Z0-9_-]{1,64}$").search(room) or not RegEx.create_from_string("^[a-zA-Z0-9_-]{1,256}$").search(invite):
		return {}
	return {"room": room, "invite": invite}

func command(json: String) -> void:
	if disposed:
		return
	var c: Variant = JSON.parse_string(json)
	if not c is Dictionary:
		_error("invalid_action")
		return
	state["error"] = ""
	match c.get("op"):
		"host":
			await _begin({"op": "create", "name": c.get("name", "Chef")})
		"join":
			var invitation := parse_invitation(c.get("invitation"))
			if invitation.is_empty():
				_error("invalid_invite")
			else:
				invitation.merge({"op": "join", "name": c.get("name", "Chef")})
				await _begin(invitation)
		"resume":
			await _begin({"op": "resume"})
		"start":
			if not state.get("canStart", false):
				_error("players_not_ready")
			else:
				_send({"op": "start"})
		"action":
			_action(c.get("action"))
		"loadout":
			_send({"op": "loadout", "loadout": c.get("loadout")})
		"ready":
			_send({"op": "ready", "ready": not state.get("ready", false)})
		"rematch":
			_send({"op": "rematch", "ready": not state.get("rematch", false)})
		"copy":
			if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
				DisplayServer.clipboard_set(str(state.get("invitation", "")))
				state["inviteCopied"] = true
			else:
				_error("copy_unavailable")
		"leave":
			leave()
			var service: String = str(state.get("service", "unavailable"))
			state = _setup_state()
			state["service"] = service
			_setup()
		_:
			_error("invalid_action")
	dirty = true

func _begin(credentials: Dictionary) -> void:
	if active or pending:
		return
	pending = true
	_attempt += 1
	var attempt := _attempt
	state["connectionMode"] = "host" if credentials.op == "create" else "join" if credentials.op == "join" else "resume"
	state["connectionStage"] = "contacting_lobby"
	state["screen"] = "connecting"
	state["status"] = "connecting"
	dirty = true
	var code := ""
	if credentials.op == "resume":
		var saved := _saved().duplicate(true)
		if saved.is_empty():
			code = "resume_unavailable"
		else:
			while _preparing and not disposed:
				await get_tree().process_frame
			config["signalingUrl"] = saved.endpoint
			state["config"] = config
			state["service"] = "ready"
			credentials = {"op": "resume", "room": saved.room, "id": saved.id, "token": saved.token}
	else:
		while _preparing and not disposed:
			await get_tree().process_frame
		if disposed or attempt != _attempt:
			return
		if not await _prepare(true, str(credentials.get("room", "")) if credentials.op == "join" else ""):
			code = "service_unavailable"
		else:
			credentials["name"] = _transport_player_name(str(credentials.get("name", "Chef")).strip_edges())
			if credentials.name.is_empty():
				credentials["name"] = "Chef"
			_preferences["name"] = credentials.name
			state["playerName"] = credentials.name
			_write_preferences()
	if disposed or attempt != _attempt:
		return
	pending = false
	if code.is_empty():
		code = _validate_url(str(config.get("signalingUrl", "")))
	if not code.is_empty():
		state["screen"] = "setup"
		state["status"] = "setup"
		state["connectionMode"] = ""
		state["connectionStage"] = ""
		_error(code)
		return
	auth = credentials
	active = true
	retry = 0
	_disconnected_at = 0
	_retry_at = 0
	_opened_at = Time.get_ticks_msec()
	_connect_socket()
	dirty = true

func _connect_socket() -> void:
	if not active:
		return
	ws = WebSocketPeer.new()
	ws.inbound_buffer_size = 131072
	ws.outbound_buffer_size = 131072
	_socket_hello_sent = false
	_socket_closed_handled = false
	_socket_opened_at = Time.get_ticks_msec()
	_last_packet = _socket_opened_at
	if ws.connect_to_url(str(config.signalingUrl)) != OK:
		_socket_closed()

func _send(data: Dictionary) -> bool:
	if not ws or ws.get_ready_state() != WebSocketPeer.STATE_OPEN or ws.get_current_outbound_buffered_amount() > 128000:
		_error("reconnecting")
		return false
	if ws.send_text(JSON.stringify(data)) != OK:
		_error("reconnecting")
		return false
	return true

func _process(delta: float) -> void:
	if ws:
		ws.poll()
		if active:
			var socket_state := ws.get_ready_state()
			if socket_state == WebSocketPeer.STATE_OPEN:
				if not _socket_hello_sent:
					_socket_hello_sent = true
					state["connectionStage"] = "creating_room" if auth.op == "create" else "joining_room" if auth.op == "join" else "restoring_seat"
					var hello := auth.duplicate(true)
					hello["build"] = config.build
					_send(hello)
					dirty = true
				while active and ws.get_available_packet_count() > 0:
					var packet := ws.get_packet()
					_last_packet = Time.get_ticks_msec()
					var msg: Variant = JSON.parse_string(packet.get_string_from_utf8())
					if not msg is Dictionary:
						_error("invalid_server_message")
					else:
						message(msg)
			elif socket_state == WebSocketPeer.STATE_CLOSED and not _socket_closed_handled:
				_socket_closed()
	_tick_elapsed += delta
	if _tick_elapsed >= 0.5:
		_tick_elapsed = 0.0
		_tick()

func _socket_closed() -> void:
	_socket_closed_handled = true
	if ws and ws.get_close_reason() == "replaced":
		_finish("session_replaced")
		return
	state["status"] = "reconnecting"
	state["connectionStage"] = "reconnecting"
	if _disconnected_at == 0:
		_disconnected_at = Time.get_ticks_msec()
	dirty = true
	if not auth.has("token"):
		_finish("connection_failed")
		return
	_retry_at = Time.get_ticks_msec() + mini(4000, 500 * int(pow(2, mini(retry, 4)))) + randi_range(0, 250)
	retry += 1

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and abs(float(value)) <= 9007199254740991.0

func message(msg: Dictionary) -> void:
	match msg.get("type"):
		"welcome":
			var room: Variant = msg.get("room")
			var timeouts: Variant = msg.get("timeouts", {})
			if not _valid_room(room) or not _integer(msg.get("id")) or msg.id < 1 or not msg.get("token") is String or msg.token.is_empty() or not timeouts is Dictionary:
				_error("invalid_server_message")
				return
			for key: String in ["guestGraceMs", "hostGraceMs"]:
				if timeouts.has(key) and (not _integer(timeouts[key]) or timeouts[key] < 1):
					_error("invalid_server_message")
					return
			if room.get("topology") != "dedicated" or room.get("build") != config.get("build"):
				_finish("incompatible_build")
				return
			state["id"] = msg.id
			retry = 0
			_disconnected_at = 0
			_retry_at = 0
			_timeouts = timeouts
			state["error"] = ""
			auth = {"op": "resume", "room": room.id, "id": msg.id, "token": msg.token}
			var saved := auth.duplicate(true)
			saved["endpoint"] = config.signalingUrl
			_preferences["resume"] = saved
			if msg.get("invite") is String and not msg.invite.is_empty():
				# Room codes join from either native previews or web exports.
				_preferences["invitation"] = str(room.id) + "." + str(msg.invite)
			state["invitation"] = str(_preferences.get("invitation", state.get("invitation", "")))
			state["canResume"] = true
			_write_preferences()
			_update_room(room)
		"room":
			if _valid_room(msg.get("room")):
				_update_room(msg.room)
			else:
				_error("invalid_server_message")
		"snapshot":
			var snapshot: Variant = msg.get("snapshot")
			if not _valid_snapshot(snapshot) or not _integer(msg.get("round")) or not _integer(msg.get("serverTime")):
				_error("invalid_server_message")
				return
			var current: Variant = state.get("snapshot")
			if msg.round < state.get("round", 0) or (msg.round == state.get("round", 0) and current is Dictionary and snapshot.revision < current.get("revision", 0)):
				return
			state["round"] = msg.round
			state["snapshot"] = snapshot
			state["screen"] = "match"
			state["serverOffsetMs"] = int(msg.serverTime) - _wall_time_ms()
		"pong":
			if not _integer(msg.get("t")):
				_error("invalid_server_message")
				return
			state["rttMs"] = maxi(0, _wall_time_ms() - int(msg.t))
		"ended":
			_finish(str(msg.get("reason", "connection_lost")))
		"error":
			var code := str(msg.get("code", "invalid_server_message"))
			if not auth.has("token"):
				active = false
				if ws:
					ws.close()
				state["screen"] = "setup"
				state["status"] = "setup"
				_error(code)
			elif code in ["room_unavailable", "resume_denied", "resume_expired", "session_expired", "incompatible_build"]:
				_finish(code)
			else:
				_error(code)
	dirty = true

func _valid_room(room: Variant) -> bool:
	if not room is Dictionary or not room.get("id") is String or room.id.is_empty() or not room.get("members") is Array or room.members.size() > 2:
		return false
	if not _integer(room.get("leader")) or room.get("phase") not in ["lobby", "playing", "ended"]:
		return false
	for member: Variant in room.members:
		if not member is Dictionary or not _integer(member.get("id")) or not member.get("name") is String or not member.get("loadout") is Dictionary:
			return false
		if not member.get("connected") is bool or not member.get("ready") is bool or not member.get("rematch") is bool:
			return false
	return true

func _valid_snapshot(snapshot: Variant) -> bool:
	if not snapshot is Dictionary or not _integer(snapshot.get("revision")) or not snapshot.get("players") is Array or snapshot.players.size() != 2:
		return false
	var has_self := false
	for player: Variant in snapshot.players:
		if not player is Dictionary:
			return false
		if player.get("id") == state.id:
			if not player.get("hand") is Array:
				return false
			has_self = true
		elif player.has("hand") or player.has("deck"):
			return false
	return has_self

func _update_room(room: Dictionary) -> void:
	if not room.get("members") is Array:
		_error("invalid_server_message")
		return
	var all_connected := true
	var all_ready := true
	state["ready"] = false
	state["rematch"] = false
	for member: Variant in room.members:
		if not member is Dictionary:
			_error("invalid_server_message")
			return
		all_connected = all_connected and member.get("connected", false)
		all_ready = all_ready and member.get("ready", false)
		if member.get("id") == state.id:
			state["ready"] = member.get("ready", false)
			state["rematch"] = member.get("rematch", false)
	state["room"] = room
	state["canRematch"] = room.get("phase") == "ended" and room.members.size() == 2 and all_connected
	state["canStart"] = room.get("leader") == state.id and room.get("phase") == "lobby" and room.members.size() == 2 and all_connected and all_ready
	state["status"] = "reconnecting" if not ws or ws.get_ready_state() != WebSocketPeer.STATE_OPEN else "connected" if all_connected else "opponent_reconnecting"
	state["connectionStage"] = "waiting_players" if room.get("phase") == "lobby" and room.members.size() == 1 else state.status
	state["screen"] = "lobby" if room.get("phase") == "lobby" else "match"
	dirty = true

func _action(value: Variant) -> void:
	if not state.get("snapshot") is Dictionary or state.get("status") != "connected":
		_error("reconnecting")
		return
	if not value is Dictionary:
		_error("invalid_action")
		return
	var action: Dictionary = value.duplicate(true)
	action["id"] = Crypto.new().generate_random_bytes(16).hex_encode()
	action["revision"] = state.snapshot.revision
	_send({"op": "action", "round": state.get("round"), "action": action})

static func _wall_time_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000)

func _tick() -> void:
	if not active:
		return
	var now := Time.get_ticks_msec()
	if not auth.has("token") and now - _opened_at > 15000:
		_finish("connection_failed")
		return
	if _disconnected_at > 0 and now - _disconnected_at > int(_timeouts.get("guestGraceMs", 90000)) + 20000:
		_finish("connection_lost")
		return
	if _retry_at > 0 and now >= _retry_at:
		_retry_at = 0
		_connect_socket()
	if ws and ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING and now - _socket_opened_at > 10000:
		ws.close()
	if ws and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if now - _last_packet > 20000:
			ws.close()
			return
		if now - _last_ping > 5000:
			_last_ping = now
			if not _send({"op": "ping", "t": _wall_time_ms()}):
				ws.close()

func _finish(reason: String) -> void:
	active = false
	if ws:
		ws.close()
	auth = {}
	_clear_saved()
	state["screen"] = "ended"
	state["status"] = reason
	state["error"] = ""
	dirty = true

func leave() -> void:
	_attempt += 1
	pending = false
	if active and ws and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send({"op": "leave"})
	active = false
	if ws:
		ws.close()
	auth = {}
	_clear_saved()

func dispose() -> void:
	disposed = true
	if _request:
		_request.cancel_request()
	leave()

func _exit_tree() -> void:
	# Closing the app reserves the seat for reconnection, like reloading a web tab.
	disposed = true
	if _request:
		_request.cancel_request()
	if ws:
		ws.close()


static func _transport_player_name(value: String) -> String:
	# The existing service caps names at 24 UTF-16 units; keep codepoints intact.
	var result := ""
	var units := 0
	for character in value:
		units += 2 if character.unicode_at(0) > 0xffff else 1
		if units > 24:
			break
		result += character
	return result
