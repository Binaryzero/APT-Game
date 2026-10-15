extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error("[LEADERBOARD_CLIENT_FAIL] " + message)


func _wait_for_request(client: Node) -> void:
    while client.status == "loading":
        await client.state_changed


func _run() -> void:
    var service_url := OS.get_environment("LEADERBOARD_TEST_URL")
    _expect(not service_url.is_empty(), "LEADERBOARD_TEST_URL is configured")
    if service_url.is_empty():
        quit(1)
        return

    ProjectSettings.set_setting("leaderboard/api_base_url", service_url)
    ProjectSettings.set_setting("leaderboard/enable_in_headless", true)
    var client := preload("res://scripts/leaderboard_client.gd").new()
    root.add_child(client)
    await process_frame

    client.fetch_scores()
    await _wait_for_request(client)
    _expect(client.status == "ready", "Godot fetches the global leaderboard")

    var submission := {
        "submission_id": "godot-client-entry-0003",
        "name": "Godot Chef",
        "victory": true,
        "battles_cleared": 3,
        "precise_cuts": 2,
        "ingredients_ruined": 0,
        "dishes_cooked": 1,
        "health_remaining": 20,
        "score_version": 2,
    }
    client.submit_score(submission)
    await _wait_for_request(client)
    _expect(client.status == "ready" and client.last_operation == "submit", "Godot submits a completed run")
    _expect(int(client.submitted_entry.get("score", 0)) == 6900, "Godot receives the server-computed score")
    _expect(not client.entries.is_empty(), "Godot receives refreshed global standings")

    ProjectSettings.set_setting("leaderboard/api_base_url", "http://127.0.0.1:1")
    ProjectSettings.set_setting(
        "leaderboard/api_fallback_urls",
        PackedStringArray([service_url + "/missing-route", service_url])
    )
    var fallback_client := preload("res://scripts/leaderboard_client.gd").new()
    root.add_child(fallback_client)
    await process_frame
    fallback_client.fetch_scores()
    await _wait_for_request(fallback_client)
    _expect(fallback_client.status == "ready", "Godot fails over after a transient connection failure")
    _expect(fallback_client.retry_count == 2, "Godot retries both connection and missing-route failures")
    _expect(fallback_client.base_url == service_url, "Godot selects the healthy fallback endpoint")

    var passed := failures.is_empty()
    client.queue_free()
    fallback_client.queue_free()
    await process_frame
    await process_frame
    if passed:
        print("[LEADERBOARD_CLIENT_PASS] Godot fetch and submission validated against the live service")
        quit(0)
    else:
        quit(1)
