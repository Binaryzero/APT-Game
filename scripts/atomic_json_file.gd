class_name EmberpanAtomicJsonFile
extends RefCounted

const BACKUP_SUFFIX := ".bak"
const TEMPORARY_SUFFIX := ".tmp"


static func load_dictionary(path: String, validator: Callable = Callable()) -> Dictionary:
	var primary := _read_dictionary(path, validator)
	if bool(primary.ok):
		return (primary.value as Dictionary).duplicate(true)
	var backup_path := path + BACKUP_SUFFIX
	var backup := _read_dictionary(backup_path, validator)
	if not bool(backup.ok):
		return {}
	var recovered: Dictionary = (backup.value as Dictionary).duplicate(true)
	# Restore a valid primary while retaining the backup as another recovery point.
	save_dictionary(path, recovered, validator)
	return recovered


static func save_dictionary(path: String, payload: Dictionary, validator: Callable = Callable()) -> Error:
	if validator.is_valid() and not bool(validator.call(payload)):
		return ERR_INVALID_DATA
	var directory := path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if directory_error != OK:
		return directory_error

	var temporary_path := path + TEMPORARY_SUFFIX
	var temporary := FileAccess.open(temporary_path, FileAccess.WRITE)
	if temporary == null:
		return FileAccess.get_open_error()
	temporary.store_string(JSON.stringify(payload) + "\n")
	temporary.flush()
	temporary.close()
	if not bool(_read_dictionary(temporary_path, validator).ok):
		_remove_if_present(temporary_path)
		return ERR_FILE_CORRUPT

	var target_global := ProjectSettings.globalize_path(path)
	var backup_path := path + BACKUP_SUFFIX
	var backup_global := ProjectSettings.globalize_path(backup_path)
	var temporary_global := ProjectSettings.globalize_path(temporary_path)
	var target_exists := FileAccess.file_exists(path)
	var target_is_valid := target_exists and bool(_read_dictionary(path, validator).ok)
	if target_is_valid:
		_remove_if_present(backup_path)
		var backup_error := DirAccess.rename_absolute(target_global, backup_global)
		if backup_error != OK:
			_remove_if_present(temporary_path)
			return backup_error
	elif target_exists:
		# A corrupt primary is not allowed to replace a known-good backup.
		var remove_error := DirAccess.remove_absolute(target_global)
		if remove_error != OK:
			_remove_if_present(temporary_path)
			return remove_error

	var promote_error := DirAccess.rename_absolute(temporary_global, target_global)
	if promote_error != OK:
		if target_is_valid and FileAccess.file_exists(backup_path) and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(backup_global, target_global)
		return promote_error
	return OK


static func _read_dictionary(path: String, validator: Callable = Callable()) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "value": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "value": {}}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"ok": false, "value": {}}
	var parsed: Variant = parser.data
	var valid: bool = parsed is Dictionary and (not validator.is_valid() or bool(validator.call(parsed)))
	return {"ok": valid, "value": parsed if valid else {}}


static func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
