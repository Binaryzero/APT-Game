extends SceneTree

const NativeClient = preload("res://scripts/multiplayer_native_client.gd")
const BUILD := "game-trading-card-server-v4"

class ManagedDescriptorClient:
	extends "res://scripts/multiplayer_native_client.gd"
	signal release_descriptor
	var descriptor_response: Array = []
	var descriptor_requests: Array[String] = []
	var wait_for_first := false
	var opened_endpoints: Array[String] = []

	func _request_descriptor(url: String) -> Array:
		descriptor_requests.append(url)
		var response := descriptor_response
		if wait_for_first and descriptor_requests.size() == 1:
			await release_descriptor
		return response

	func _connect_socket() -> void:
		opened_endpoints.append(str(config.signalingUrl))

var failures: Array[String] = []
var clients: Array[Node] = []
var storage_paths: Array[String] = []
var endpoint := ""
var preview_url := ""
var session_namespace := ""


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> bool:
	if not value:
		failures.append(message)
		push_error("[MULTIPLAYER_NATIVE_FAIL] " + message)
	return value


func _state(client: Node) -> Dictionary:
	var update: String = client.drain()
	if not update.is_empty():
		client.set_meta("test_state", JSON.parse_string(update))
	return client.get_meta("test_state", {})


func _command(client: Node, value: Dictionary) -> void:
	client.command(JSON.stringify(value))


func _wait(predicate: Callable, message: String, timeout_seconds: float = 8.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	if predicate.call():
		return true
	for client: Node in clients:
		var state := _state(client)
		print("[MULTIPLAYER_NATIVE_STATE] ", JSON.stringify({"screen": state.get("screen"), "status": state.get("status"), "service": state.get("service"), "error": state.get("error")}))
	return _expect(false, message)


func _client(seat: String, discover: bool = false, implementation: Node = null) -> Node:
	var client: Node = NativeClient.new() if implementation == null else implementation
	client.storage_namespace = session_namespace + "-" + seat
	root.add_child(client)
	clients.append(client)
	client.configure(JSON.stringify({
		"build": BUILD,
		"signalingUrl": "ws://127.0.0.1:1/ws" if discover else endpoint,
		"bootstrapUrl": "multiplayer/bootstrap.json" if discover else "",
		"previewUrl": preview_url,
		"iceTransportPolicy": "all",
	}))
	var storage_path := ProjectSettings.globalize_path(client._storage_path)
	if not storage_paths.has(storage_path):
		storage_paths.append(storage_path)
	return client


func _managed_client(label: String, descriptor: Dictionary, status: int = 200, result: int = HTTPRequest.RESULT_SUCCESS) -> Node:
	var client := ManagedDescriptorClient.new()
	client.descriptor_response = [result, status, PackedStringArray(), JSON.stringify(descriptor).to_utf8_buffer()]
	return _client("managed-" + label, true, client)


func _managed_discovery() -> void:
	var discovery_url := "https://discovery.example/bootstrap?build=old&build=older&region=test&room=old&r%6fom=older&mode=join"
	var descriptor := {"version": 1, "build": BUILD, "signalingUrl": "wss://game.example/ws", "iceTransportPolicy": "all"}
	OS.set_environment("GAME_MULTIPLAYER_DISCOVERY_URL", discovery_url)
	OS.set_environment("GAME_MULTIPLAYER_SIGNALING_URL", endpoint)
	var managed := _managed_client("valid", descriptor)
	if await _wait(func(): return _state(managed).get("service") == "ready", "Managed HTTPS descriptor configures native multiplayer"):
		_expect(_state(managed).get("config", {}).get("signalingUrl") == descriptor.signalingUrl, "Managed discovery overrides direct environment and stale configured endpoints")
		_expect(managed.descriptor_requests.size() == 1, "Managed discovery issues one descriptor request")
		if managed.descriptor_requests.size() == 1:
			var requested: String = managed.descriptor_requests[0]
			var query := requested.get_slice("?", 1)
			var build_parameters: Array[String] = []
			for parameter: String in query.split("&"):
				if parameter.get_slice("=", 0).uri_decode() == "build":
					build_parameters.append(parameter.get_slice("=", 1).uri_decode())
			_expect(requested.begins_with("https://discovery.example/bootstrap?"), "Operator discovery keeps the configured HTTPS endpoint")
			_expect(build_parameters == [BUILD] and query.contains("region=test"), "Managed discovery replaces the build parameter and preserves other query values")
			_expect(not query.contains("room=") and not query.contains("r%6fom=") and not query.contains("mode="), "Initial managed discovery removes stale room selection")
	var routed: String = managed._managed_discovery_url(discovery_url, "AB_room")
	_expect(routed.count("room=") == 1 and routed.contains("room=AB_room") and not routed.contains("mode="), "Native room discovery replaces duplicate selection parameters")
	for invalid_room: String in ["bad room", "bad&invite=value", "x".repeat(65)]:
		_expect(managed._managed_discovery_url(discovery_url, invalid_room).is_empty(), "Native room discovery rejects invalid room values")
	var racing := ManagedDescriptorClient.new()
	racing.wait_for_first = true
	racing.descriptor_response = [HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(descriptor).to_utf8_buffer()]
	_client("managed-race", true, racing)
	_command(racing, {"op": "join", "invitation": "AB_room.private-invite"})
	await process_frame
	_expect(racing.descriptor_requests.size() == 1 and racing.opened_endpoints.is_empty(), "Native Join waits for initial managed discovery")
	var room_descriptor := descriptor.duplicate(true)
	room_descriptor.signalingUrl = "wss://original.example/ws"
	racing.descriptor_response = [HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(room_descriptor).to_utf8_buffer()]
	racing.release_descriptor.emit()
	if await _wait(func(): return racing.opened_endpoints.size() == 1, "Native Join starts a fresh room lookup after initial discovery"):
		_expect(racing.descriptor_requests.size() == 2 and racing.descriptor_requests[-1].contains("room=AB_room"), "Native Join includes the invitation room in managed discovery")
		_expect(not racing.descriptor_requests[-1].contains("invite=") and not racing.descriptor_requests[-1].contains("token="), "Native managed lookup includes no invitation or resume data")
		_expect(racing.opened_endpoints[-1] == room_descriptor.signalingUrl, "Native Join selects the room's original generation")
	_command(racing, {"op": "leave"})
	racing.descriptor_response = [HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(descriptor).to_utf8_buffer()]
	_command(racing, {"op": "host"})
	if await _wait(func(): return racing.opened_endpoints.size() == 2, "Native Host resolves a new generation"):
		_expect(not racing.descriptor_requests[-1].contains("room=") and not racing.descriptor_requests[-1].contains("mode="), "Native Host clears prior room selection")
		_expect(racing.opened_endpoints[-1] == descriptor.signalingUrl, "Native Host uses the latest descriptor")
	_command(racing, {"op": "leave"})
	racing._preferences["resume"] = {"id": 1, "room": "AB_room", "token": "test-resume", "endpoint": room_descriptor.signalingUrl}
	var requests_before_resume := racing.descriptor_requests.size()
	_command(racing, {"op": "resume"})
	if await _wait(func(): return racing.opened_endpoints.size() == 3, "Native managed resume restores its saved endpoint"):
		_expect(racing.descriptor_requests.size() == requests_before_resume and racing.opened_endpoints[-1] == room_descriptor.signalingUrl, "Native managed resume bypasses discovery")
	var bad_version: Dictionary = descriptor.duplicate(true)
	bad_version.version = 2
	var bad_build: Dictionary = descriptor.duplicate(true)
	bad_build.build = "old-build"
	var cases: Array[Dictionary] = [
		{"label": "wrong-version", "descriptor": bad_version},
		{"label": "wrong-build", "descriptor": bad_build},
		{"label": "http-failure", "descriptor": descriptor, "status": 503},
		{"label": "transport-failure", "descriptor": descriptor, "result": HTTPRequest.RESULT_CANT_CONNECT},
	]
	for service_url: String in ["ws://game.example/ws", "/ws", "wss://127.0.0.1/ws", "wss://localhost/ws", "wss://[::1]/ws"]:
		var invalid_endpoint: Dictionary = descriptor.duplicate(true)
		invalid_endpoint.signalingUrl = service_url
		cases.append({"label": "invalid-service-%d" % cases.size(), "descriptor": invalid_endpoint})
	for invalid: Dictionary in cases:
		var client := _managed_client(invalid.label, invalid.descriptor, invalid.get("status", 200), invalid.get("result", HTTPRequest.RESULT_SUCCESS))
		if not await _wait(func(): return _state(client).get("service") == "unavailable", "Managed %s rejects the descriptor without fallback" % invalid.label):
			continue
		_expect(not client.active and client.ws == null, "Rejected managed descriptor never connects to the direct fallback")
		_command(client, {"op": "host", "name": "Managed test"})
		await _wait(func(): return _state(client).get("screen") == "setup" and _state(client).get("error") == "service_unavailable", "Managed failure remains a recoverable Host error")
	OS.set_environment("GAME_MULTIPLAYER_DISCOVERY_URL", "http://discovery.example/bootstrap")
	var insecure_operator := _managed_client("insecure-operator", descriptor)
	await _wait(func(): return _state(insecure_operator).get("service") == "unavailable", "Operator discovery URL requires HTTPS")
	_expect(insecure_operator.descriptor_requests.is_empty(), "Insecure operator URL is rejected before requesting credentials or service data")
	OS.set_environment("GAME_MULTIPLAYER_DISCOVERY_URL", "")
	OS.set_environment("GAME_MULTIPLAYER_SIGNALING_URL", "")


func _bootstrap_mode(mode: String) -> bool:
	var request := HTTPRequest.new()
	root.add_child(request)
	var error := request.request(preview_url + "test/bootstrap-mode", ["Content-Type: text/plain"], HTTPClient.METHOD_POST, mode)
	if not _expect(error == OK, "Bootstrap fixture control request starts"):
		request.queue_free()
		return false
	var response: Array = await request.request_completed
	request.queue_free()
	return _expect(response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200, "Bootstrap fixture accepts " + mode)


func _snapshot(client: Node) -> Dictionary:
	var value: Variant = _state(client).get("snapshot")
	return value if value is Dictionary else {}


func _revision(client: Node) -> int:
	return int(_snapshot(client).get("revision", -1))


func _member(client: Node, id: int) -> Dictionary:
	var room: Variant = _state(client).get("room")
	if room is Dictionary:
		for member: Dictionary in room.get("members", []):
			if int(member.get("id", 0)) == id:
				return member
	return {}


func _private_snapshot(client: Node) -> bool:
	var state := _state(client)
	var snapshot := _snapshot(client)
	var players: Array = snapshot.get("players", [])
	if not _expect(players.size() == 2, "Each native player receives both public seats"):
		return false
	for player: Dictionary in players:
		_expect(not player.has("deck"), "No native client receives a private deck")
		if int(player.id) == int(state.id):
			_expect(player.get("hand") is Array, "Native client receives its own private hand")
		else:
			_expect(not player.has("hand"), "Opponent hand remains private in native snapshots")
	return failures.is_empty()


func _malformed_packets() -> void:
	var room := {"id": "packet-test", "topology": "dedicated", "build": BUILD, "leader": 1, "phase": "lobby", "members": [
		{"id": 1, "name": "Packet test", "loadout": {}, "connected": true, "ready": false, "rematch": false},
	]}
	var welcome := {"type": "welcome", "id": 1, "token": "packet-test-token", "room": room}
	var invalid_timeouts: Dictionary = welcome.duplicate(true)
	invalid_timeouts["timeouts"] = "invalid"
	var invalid_grace: Dictionary = welcome.duplicate(true)
	invalid_grace["timeouts"] = {"guestGraceMs": "invalid"}
	var missing_room_id: Dictionary = welcome.duplicate(true)
	missing_room_id.room.erase("id")
	var packets: Array[Dictionary] = [
		{"type": "welcome", "id": 1, "token": "packet-test-token", "room": null},
		invalid_timeouts,
		invalid_grace,
		missing_room_id,
		{"type": "room", "room": missing_room_id.room},
		{"type": "pong", "t": "invalid"},
	]
	for index in range(packets.size()):
		var client := _client("packet-%d" % index)
		client.message(packets[index])
		var state := _state(client)
		_expect(state.get("error") == "invalid_server_message", "Malformed native packet %d reports a protocol error" % index)
		_expect(int(state.get("id", -1)) == 0 and state.get("room") == null and client.auth.is_empty(), "Malformed native packet %d cannot partially authenticate or replace room state" % index)


func _exercise() -> void:
	var host := _client("host")
	var guest := _client("guest")
	_command(guest, {"op": "join", "invitation": "invalid"})
	if not await _wait(func(): return _state(guest).get("error") == "invalid_invite", "Malformed invitations produce a recoverable error"):
		return
	_command(host, {"op": "host", "name": "Native host"})
	if not await _wait(func(): return _state(host).get("screen") == "lobby", "Native host creates a room"):
		return
	_expect(int(_state(host).get("id", 0)) == 1, "Host authenticates as the first seat")
	_expect(not _state(host).get("canStart", true), "A single player cannot start a duel")
	var invitation := str(_state(host).get("invitation", ""))
	if not _expect(not invitation.is_empty(), "Host receives a usable invitation"):
		return
	_command(guest, {"op": "join", "name": "Native guest", "invitation": invitation})
	if not await _wait(func(): return _state(guest).get("screen") == "lobby" and not _member(host, 2).is_empty(), "Second native client joins by invitation"):
		return
	_expect(int(_state(guest).get("id", 0)) == 2, "Guest authenticates as the second seat")
	_command(host, {"op": "start"})
	_expect(_state(host).get("error") == "players_not_ready", "Readiness protects the start action")
	_command(host, {"op": "ready"})
	if not await _wait(func(): return _member(guest, 1).get("ready", false), "Host readiness reaches the guest"):
		return
	_command(guest, {"op": "loadout", "loadout": {"starter": "aggro", "hero": "ember_butcher", "legendary": "the_sovereign_cleaver"}})
	if not await _wait(func(): return _member(host, 2).get("loadout", {}).get("starter") == "aggro", "Native loadout selection reaches authority"):
		return
	_expect(not _member(host, 1).get("ready", true), "Changing a loadout resets readiness")
	_command(host, {"op": "ready"})
	_command(guest, {"op": "ready"})
	if not await _wait(func(): return _state(host).get("canStart", false), "Both native seats become ready"):
		return
	_command(host, {"op": "start"})
	if not await _wait(func(): return not _snapshot(host).is_empty() and not _snapshot(guest).is_empty(), "Native clients receive the authoritative match"):
		return
	if not _private_snapshot(host) or not _private_snapshot(guest):
		return
	_expect(_snapshot(guest).players[1].hero == "ember_butcher", "Selected hero is present in the match")
	_command(guest, {"op": "action", "action": {"kind": "end"}})
	if not await _wait(func(): return _state(guest).get("error") == "not_your_turn", "Authority rejects a native out-of-turn action"):
		return
	var revision := _revision(host)
	_command(host, {"op": "action", "action": {"kind": "end"}})
	if not await _wait(func(): return _revision(host) > revision and _revision(guest) == _revision(host), "Native action advances both private snapshots"):
		return
	_expect(int(_snapshot(host).active) == 2, "Ending a turn hands control to the guest")

	# The real socket closes; polling must reconnect with the authenticated seat.
	var generation := int(_member(guest, 1).get("generation", 0))
	host.ws.close(1000, "native_acceptance_disconnect")
	if not await _wait(func(): return _state(guest).get("status") == "opponent_reconnecting", "Opponent sees native transport loss"):
		return
	if not await _wait(func(): return int(_member(guest, 1).get("generation", 0)) > generation and _state(host).get("status") == "connected", "Native transport automatically resumes its seat"):
		return
	_expect(int(_state(host).id) == 1, "Automatic reconnect preserves the host seat")
	if not _private_snapshot(host):
		return

	# Simulate closing and reopening the native game, preserving only its local save.
	generation = int(_member(guest, 1).get("generation", 0))
	clients.erase(host)
	root.remove_child(host)
	host.free()
	if not await _wait(func(): return _state(guest).get("status") == "opponent_reconnecting", "Native reload disconnects the old socket"):
		return
	host = _client("host")
	if not await _wait(func(): return _state(host).get("canResume", false), "Native reload discovers its saved seat"):
		return
	_command(host, {"op": "resume"})
	if not await _wait(func(): return int(_member(guest, 1).get("generation", 0)) > generation and not _snapshot(host).is_empty() and _state(host).get("status") == "connected", "Reopened native game restores its room and private match"):
		return
	_expect(int(_state(host).id) == 1, "Saved credentials restore the correct seat")
	if not _private_snapshot(host):
		return

	# Finish through legal end-turn actions, exercising real fatigue and result packets.
	for turn_index in range(80):
		if _snapshot(host).get("status") == "ended":
			break
		revision = _revision(host)
		var actor := host if int(_snapshot(host).active) == 1 else guest
		_command(actor, {"op": "action", "action": {"kind": "end"}})
		if not await _wait(func(): return _revision(host) > revision and _revision(guest) == _revision(host), "Fatigue turn %d reaches both native clients" % turn_index):
			return
	if not _expect(_snapshot(host).get("status") == "ended", "Legal native turns complete a duel"):
		return
	_expect(_snapshot(host).winner == _snapshot(guest).winner, "Both native clients agree on the winner")
	if not await _wait(func(): return _state(host).get("canRematch", false) and _state(guest).get("canRematch", false), "Native result state permits a rematch"):
		return
	_command(host, {"op": "rematch"})
	_command(guest, {"op": "rematch"})
	if not await _wait(func(): return int(_state(host).get("round", 0)) == 2 and int(_state(guest).get("round", 0)) == 2, "Both native votes create round two"):
		return
	_expect(_snapshot(host).get("status") == "playing" and _revision(host) == 0, "Rematch begins with fresh authoritative state")
	_expect(_snapshot(guest).players[1].hero == "ember_butcher", "Rematch preserves the selected loadout")
	_command(guest, {"op": "leave"})
	_expect(_state(guest).get("screen") == "setup" and not _state(guest).get("canResume", true), "Leave returns to setup and clears saved credentials")
	# Returning to the title screen frees the multiplayer scene immediately.
	clients.erase(guest)
	root.remove_child(guest)
	guest.free()
	if not await _wait(func(): return _snapshot(host).get("status") == "ended", "Leaving and immediately freeing the native scene awards a forfeit to the survivor"):
		return
	_expect(int(_snapshot(host).winner) == 1, "Remaining player wins after the guest leaves")
	_command(host, {"op": "leave"})
	_expect(_state(host).get("screen") == "setup" and not _state(host).get("canResume", true), "Host can leave and clear the final seat")


func _exercise_discovery() -> void:
	if not await _bootstrap_mode("unavailable"):
		return
	var client := _client("discovery", true)
	if not await _wait(func(): return _state(client).get("service") == "unavailable", "Native preview discovery reports an unavailable descriptor"):
		return
	_expect(_state(client).get("screen") == "setup", "Unavailable discovery keeps native setup available")
	if not await _bootstrap_mode("ready"):
		return
	_command(client, {"op": "host", "name": "Discovered host"})
	if not await _wait(func(): return _state(client).get("screen") == "lobby", "Host retries failed discovery and creates a room after recovery"):
		return
	_expect(_state(client).get("config", {}).get("signalingUrl") == endpoint, "Relative /ws descriptor resolves against the configured preview port")
	var room_id: String = _state(client).room.id
	clients.erase(client)
	root.remove_child(client)
	client.free()
	if not await _bootstrap_mode("moved"):
		return
	client = _client("discovery", true)
	if not await _wait(func(): return _state(client).get("service") == "ready", "Reopened native client discovers the replacement descriptor"):
		return
	_expect(_state(client).get("config", {}).get("signalingUrl") != endpoint, "Fixture actually changes the discovered endpoint")
	_expect(_state(client).get("canResume", false), "Saved native room remains resumable after discovery changes")
	_command(client, {"op": "resume"})
	if not await _wait(func(): return _state(client).get("screen") == "lobby", "Native resume reconnects to the original authority after discovery changes"):
		return
	_expect(_state(client).room.id == room_id, "Native resume preserves its original room")
	_expect(_state(client).get("config", {}).get("signalingUrl") == endpoint, "Native resume stays pinned to the authenticated endpoint")
	_command(client, {"op": "leave"})
	_expect(_state(client).get("screen") == "setup", "Discovered native room can be left normally")


func _run() -> void:
	endpoint = OS.get_environment("GAME_MULTIPLAYER_TEST_SIGNALING_URL")
	preview_url = OS.get_environment("GAME_MULTIPLAYER_TEST_PREVIEW_URL")
	session_namespace = OS.get_environment("GAME_MULTIPLAYER_TEST_SESSION")
	if not _expect(not endpoint.is_empty() and not preview_url.is_empty() and not session_namespace.is_empty(), "Use the native test runner to provide an isolated local server and save namespace"):
		quit(1)
		return
	_malformed_packets()
	if failures.is_empty():
		await _managed_discovery()
	if failures.is_empty():
		await _exercise()
	if failures.is_empty():
		await _exercise_discovery()
	for client: Node in clients:
		client.dispose()
		client.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	for storage_path: String in storage_paths:
		if FileAccess.file_exists(storage_path):
			DirAccess.remove_absolute(storage_path)
	if failures.is_empty():
		print("[MULTIPLAYER_NATIVE_PASS] Native clients validated managed HTTPS discovery, packet validation, private authoritative play, reconnect, saved resume, results, rematch, leave, preview discovery recovery and endpoint pinning")
	quit(0 if failures.is_empty() else 1)
