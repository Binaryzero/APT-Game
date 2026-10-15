extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func finish() -> void:
	for failure: String in failures:
		push_error(failure)
	print("PLAYER_NAME_UNICODE ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func clean(path: String) -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))

const Client := preload("res://scripts/leaderboard_client.gd")
const NativeClient := preload("res://scripts/multiplayer_native_client.gd")

func run() -> void:
	var client := Client.new()
	root.add_child(client)
	for value: String in ["张伟", "李娜", "王昊", "王𠮷", "昊"]:
		check(Client.normalize_chef_name(value) == value, "accept " + value)
		var wire: Dictionary = JSON.parse_string(JSON.stringify({"name": Client.normalize_chef_name(value), "score": 100, "submission_id": "unicode-entry"}))
		client._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"score_version": Client.SCORE_VERSION, "entries": [wire], "entry": wire}).to_utf8_buffer())
		check(client.entries.size() == 1 and client.entries[0].name == value, "retrieved row " + value)
		check(client.submitted_entry.name == value, "submitted response " + value)
	check(Client.normalize_chef_name("  chef!! pan---pal  ") == "CHEF PAN-PAL", "legacy ASCII normalization")
	check(Client.normalize_chef_name("王".repeat(15) + "𠮷伟") == "王".repeat(15) + "𠮷", "codepoint truncation")
	check(Client.normalize_chef_name("Juń") == "JUŃ", "attached combining mark")
	check(Client.normalize_chef_name("\u0301张\u200b伟<>") == "张伟", "drop orphan marks controls and markup")
	for value: String in ["张".repeat(24), "王".repeat(22) + "𠮷", "𠮷".repeat(12), "A".repeat(23) + "𠮷尾"]:
		var truncated := NativeClient._transport_player_name(value)
		check(truncated.to_utf16_buffer().size() <= 48, "legacy service transport cap")
		check(not truncated.contains(String.chr(0xfffd)), "complete Unicode codepoints")
	check(NativeClient._transport_player_name("A".repeat(23) + "𠮷尾") == "A".repeat(23), "do not split supplementary Han at legacy cap")
	client.free()
	finish()
