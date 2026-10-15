class_name EmberpanLeaderboardClient
extends Node

signal state_changed

const SCORE_VERSION := 2
const DISPLAY_LIMIT := 5
const LOCAL_LIMIT := 20
const API_PATH := "/api/leaderboard"
const RETRYABLE_HTTP_CODES := [408, 425, 500, 502, 503, 504]
const DEFAULT_TIMEOUT_SECONDS := 20.0
const DEFAULT_REQUEST_ATTEMPTS := 3

var entries: Array[Dictionary] = []
var status := "idle"
var status_message := ""
var last_operation := ""
var submitted_entry := {}
var base_url := ""
var base_urls: Array[String] = []
var diagnostic_code := ""
var last_request_id := ""
var retry_count := 0
var last_http_code := 0
var last_result := HTTPRequest.RESULT_SUCCESS
var http: HTTPRequest

var active_operation := ""
var active_path := ""
var active_method := HTTPClient.METHOD_GET
var active_headers := PackedStringArray()
var active_body := ""
var active_attempt := 0
var max_attempts := DEFAULT_REQUEST_ATTEMPTS
var request_trace_id := ""


func _ready() -> void:
    http = HTTPRequest.new()
    http.name = "LeaderboardRequest"
    http.timeout = maxf(
        8.0,
        float(ProjectSettings.get_setting("leaderboard/request_timeout_seconds", DEFAULT_TIMEOUT_SECONDS))
    )
    add_child(http)
    http.request_completed.connect(_on_request_completed)
    base_urls = _resolve_base_urls()
    base_url = base_urls.front() if not base_urls.is_empty() else ""
    if not _can_request():
        status = "offline"
        status_message = "Global service unavailable"


func fetch_scores() -> void:
    if not _can_request():
        _set_state("offline", "Global service unavailable", "fetch", "OFFLINE")
        return
    _begin_request(
        "fetch",
        API_PATH + "?limit=%d" % DISPLAY_LIMIT,
        HTTPClient.METHOD_GET,
        PackedStringArray(["Accept: application/json"]),
        ""
    )


func submit_score(submission: Dictionary) -> void:
    if not _can_request():
        _set_state("offline", "Run saved locally · global service unavailable", "submit", "OFFLINE")
        return
    var payload := submission.duplicate(true)
    payload["score_version"] = SCORE_VERSION
    _begin_request(
        "submit",
        API_PATH,
        HTTPClient.METHOD_POST,
        PackedStringArray(["Accept: application/json", "Content-Type: application/json"]),
        JSON.stringify(payload)
    )


func _begin_request(
    operation: String,
    path: String,
    method: HTTPClient.Method,
    headers: PackedStringArray,
    body: String
) -> void:
    _cancel_active_request()
    base_urls = _resolve_base_urls()
    base_url = base_urls.front() if not base_urls.is_empty() else ""
    active_operation = operation
    active_path = path
    active_method = method
    active_headers = headers
    active_body = body
    active_attempt = 0
    retry_count = 0
    max_attempts = maxi(DEFAULT_REQUEST_ATTEMPTS, base_urls.size())
    request_trace_id = _new_request_id()
    last_operation = operation
    submitted_entry = {}
    diagnostic_code = ""
    last_request_id = ""
    last_http_code = 0
    last_result = HTTPRequest.RESULT_SUCCESS
    status = "loading"
    status_message = "Loading global standings" if operation == "fetch" else "Submitting score"
    state_changed.emit()
    _issue_active_request()


func _issue_active_request() -> void:
    if base_urls.is_empty():
        _set_state("error", "Global service unavailable", active_operation, "NO-ENDPOINT")
        return
    active_attempt += 1
    var endpoint_index := (active_attempt - 1) % base_urls.size()
    base_url = base_urls[endpoint_index]
    var request_headers := active_headers.duplicate()
    request_headers.append("X-Request-Id: %s" % request_trace_id)
    var error := http.request(
        base_url + active_path,
        request_headers,
        active_method,
        active_body
    )
    if error != OK:
        _handle_attempt_failure(HTTPRequest.RESULT_REQUEST_FAILED, 0, PackedStringArray())


func _on_request_completed(
    result: int,
    response_code: int,
    headers: PackedStringArray,
    body: PackedByteArray
) -> void:
    last_result = result
    last_http_code = response_code
    var returned_request_id := _response_header(headers, "x-request-id")
    if not returned_request_id.is_empty():
        last_request_id = returned_request_id
    if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
        _handle_attempt_failure(result, response_code, headers)
        return

    var parsed = JSON.parse_string(body.get_string_from_utf8())
    if not parsed is Dictionary or not parsed.get("entries", []) is Array:
        _set_state(
            "error",
            "Global service returned invalid data",
            active_operation,
            "DATA-%s" % _short_request_id()
        )
        return
    if int(parsed.get("score_version", -1)) != SCORE_VERSION:
        _set_state(
            "error",
            "Global service uses incompatible scoring rules",
            active_operation,
            "VERSION-%s" % _short_request_id()
        )
        return
    entries.clear()
    for raw_entry in parsed.get("entries", []):
        if raw_entry is Dictionary:
            entries.append(raw_entry.duplicate(true))
    sort_entries(entries)
    if parsed.get("entry", {}) is Dictionary:
        submitted_entry = parsed.get("entry", {}).duplicate(true)
    _set_state("ready", "Global standings live", active_operation)


func _handle_attempt_failure(result: int, response_code: int, headers: PackedStringArray) -> void:
    last_result = result
    last_http_code = response_code
    var returned_request_id := _response_header(headers, "x-request-id")
    if not returned_request_id.is_empty():
        last_request_id = returned_request_id
    if _is_retryable(result, response_code) and active_attempt < max_attempts:
        retry_count += 1
        status_message = "Retrying global service (%d/%d)" % [active_attempt + 1, max_attempts]
        state_changed.emit()
        call_deferred("_issue_active_request")
        return
    var code := "NET-%d" % result if result != HTTPRequest.RESULT_SUCCESS else "HTTP-%d" % response_code
    var request_suffix := _short_request_id()
    if not request_suffix.is_empty():
        code += "-%s" % request_suffix
    var message := "Global service did not respond"
    if response_code == 429:
        message = "Global service is busy · retry shortly"
    elif response_code >= 400:
        message = "Global service rejected the request"
    if active_operation == "submit":
        message = "Run saved locally · %s" % message.to_lower()
    _set_state("error", message, active_operation, code)


func _is_retryable(result: int, response_code: int) -> bool:
    if result != HTTPRequest.RESULT_SUCCESS:
        return true
    if response_code in [404, 405] and base_urls.size() > 1:
        return true
    return response_code in RETRYABLE_HTTP_CODES


func _response_header(headers: PackedStringArray, sought_name: String) -> String:
    var normalized_name := sought_name.to_lower()
    for header in headers:
        var separator := header.find(":")
        if separator <= 0:
            continue
        if header.substr(0, separator).strip_edges().to_lower() == normalized_name:
            return header.substr(separator + 1).strip_edges()
    return ""


func _short_request_id() -> String:
    if last_request_id.is_empty():
        return request_trace_id.substr(0, mini(8, request_trace_id.length())).to_upper()
    return last_request_id.substr(0, mini(8, last_request_id.length())).to_upper()


func _resolve_base_urls() -> Array[String]:
    var urls: Array[String] = []
    if OS.has_feature("web"):
        var origin = JavaScriptBridge.eval("window.location.origin", true)
        if origin is String and _is_hosted_origin(String(origin)):
            _append_base_url(urls, String(origin))

    var configured := String(ProjectSettings.get_setting("leaderboard/api_base_url", "")).strip_edges()
    if not configured.is_empty() and (not OS.has_feature("web") or not _is_loopback_url(configured)):
        _append_base_url(urls, configured)

    var fallbacks = ProjectSettings.get_setting("leaderboard/api_fallback_urls", PackedStringArray())
    if fallbacks is PackedStringArray or fallbacks is Array:
        for fallback in fallbacks:
            _append_base_url(urls, String(fallback))
    return urls


func _append_base_url(urls: Array[String], candidate: String) -> void:
    var normalized := candidate.strip_edges().trim_suffix("/")
    if normalized.is_empty() or normalized in urls:
        return
    urls.append(normalized)


func _is_hosted_origin(origin: String) -> bool:
    var normalized := origin.to_lower().trim_suffix("/")
    if _is_loopback_url(normalized):
        return true
    return normalized.begins_with("https://") and (
        normalized.ends_with(".manus.space")
        or normalized.ends_with(".manus.computer")
    )


func _is_loopback_url(url: String) -> bool:
    var normalized := url.to_lower()
    return (
        normalized.begins_with("http://127.0.0.1")
        or normalized.begins_with("http://localhost")
        or normalized.begins_with("https://127.0.0.1")
        or normalized.begins_with("https://localhost")
    )


func _can_request() -> bool:
    return (
        http != null
        and not base_urls.is_empty()
        and (not _is_headless() or bool(ProjectSettings.get_setting("leaderboard/enable_in_headless", false)))
    )


func _is_headless() -> bool:
    return DisplayServer.get_name() == "headless"


func _cancel_active_request() -> void:
    if http != null and http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
        http.cancel_request()


func _set_state(next_status: String, message: String, operation: String, code := "") -> void:
    status = next_status
    status_message = message
    last_operation = operation
    diagnostic_code = code
    state_changed.emit()


func _new_request_id() -> String:
    return "pc-%d-%08x" % [Time.get_unix_time_from_system(), randi()]


static func calculate_score(run: Dictionary) -> int:
    return maxi(
        0,
        (3000 if bool(run.get("victory", false)) else 0)
        + int(run.get("battles_cleared", 0)) * 1000
        + int(run.get("precise_cuts", 0)) * 150
        + int(run.get("dishes_cooked", 0)) * 100
        + int(run.get("health_remaining", 0)) * 25
        - int(run.get("ingredients_ruined", 0)) * 50
    )


static func normalize_chef_name(value: String) -> String:
    var result := ""
    var chinese := RegEx.create_from_string("^\\p{Han}$")
    var mark := RegEx.create_from_string("^\\p{M}$")
    var can_attach_mark := false
    var previous_space := false
    var previous_hyphen := false
    for index in range(value.length()):
        var character := value.substr(index, 1).to_upper()
        if character == " ":
            can_attach_mark = false
            if not result.is_empty() and not previous_space:
                result += character
            previous_space = true
            previous_hyphen = false
        elif character == "-":
            can_attach_mark = false
            if not result.is_empty() and not previous_hyphen:
                result += character
            previous_space = false
            previous_hyphen = true
        elif "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".contains(character) or chinese.search(character) != null:
            result += character
            can_attach_mark = character != "_"
            previous_space = false
            previous_hyphen = false
        elif can_attach_mark and mark.search(character) != null:
            result += character
        else:
            can_attach_mark = false
        if result.length() >= 16:
            break
    result = result.strip_edges().trim_suffix("-")
    return "CHEF" if result.is_empty() else result


static func sort_entries(records: Array[Dictionary]) -> void:
    records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        var left_score := int(left.get("score", 0))
        var right_score := int(right.get("score", 0))
        if left_score != right_score:
            return left_score > right_score
        var left_time := String(left.get("created_at", ""))
        var right_time := String(right.get("created_at", ""))
        if left_time != right_time:
            return left_time < right_time
        return String(left.get("submission_id", "")) < String(right.get("submission_id", ""))
    )
