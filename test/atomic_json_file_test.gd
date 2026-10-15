extends SceneTree

const ATOMIC_JSON := preload("res://scripts/atomic_json_file.gd")
const TEST_PATH := "user://emberpan_atomic_json_test.json"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("[ATOMIC_JSON_FAIL] " + message)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _run() -> void:
	_remove(TEST_PATH)
	_remove(TEST_PATH + ATOMIC_JSON.BACKUP_SUFFIX)
	_remove(TEST_PATH + ATOMIC_JSON.TEMPORARY_SUFFIX)
	_expect(ATOMIC_JSON.save_dictionary(TEST_PATH, {"version": 1, "value": "first"}) == OK, "initial save succeeds")
	_expect(ATOMIC_JSON.save_dictionary(TEST_PATH, {"version": 1, "value": "second"}) == OK, "replacement save succeeds")
	_expect(String(ATOMIC_JSON.load_dictionary(TEST_PATH).get("value", "")) == "second", "primary save contains the latest value")

	var corrupt := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	corrupt.store_string("{truncated")
	corrupt.close()
	var recovered := ATOMIC_JSON.load_dictionary(TEST_PATH)
	_expect(String(recovered.get("value", "")) == "first", "corrupt primary recovers from the valid backup")
	_expect(String(ATOMIC_JSON.load_dictionary(TEST_PATH).get("value", "")) == "first", "backup recovery restores a valid primary")

	_remove(TEST_PATH)
	var backup_only := ATOMIC_JSON.load_dictionary(TEST_PATH)
	_expect(String(backup_only.get("value", "")) == "first", "missing primary recovers from backup")

	_remove(TEST_PATH)
	_remove(TEST_PATH + ATOMIC_JSON.BACKUP_SUFFIX)
	_remove(TEST_PATH + ATOMIC_JSON.TEMPORARY_SUFFIX)
	if failures.is_empty():
		print("[ATOMIC_JSON_PASS] transactional save replacement and backup recovery validated")
		quit(0)
	else:
		quit(1)
