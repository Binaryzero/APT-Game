class_name EmberpanL10n
extends RefCounted

const DEFAULT_LOCALE := "en"
const SUPPORTED_LOCALES := ["en", "zh-CN"]
const CATALOG_PATHS := {
	"en": "res://localization/en.json",
	"zh-CN": "res://localization/zh-CN.json",
}
const LOCALE_OVERRIDE_ENV := "PROTO_CARD_LOCALE"
const PREFERENCE_PATH := "user://localization.cfg"
const PREFERENCE_SECTION := "localization"
const PREFERENCE_KEY := "locale"
const UI_FONT_PATH := "res://assets/template/fonts/ui_regular.tres"
const UI_FONT_RESOURCE: Font = preload("res://assets/template/fonts/ui_regular.tres")
## Buttons use Figtree SemiBold (light Latin tracking) with Noto Sans SC Medium for Chinese.
const BUTTON_FONT_RESOURCE: Font = preload("res://assets/template/fonts/display/card_button.tres")
## Display faces: ManusCC0 titles/numbers, Cinzel headings/names, and Noto Serif SC Chinese titles/headings/names.
const TITLE_FONT_RESOURCE: Font = preload("res://assets/template/fonts/display/card_title.tres")
const HEADING_FONT_RESOURCE: Font = preload("res://assets/template/fonts/display/card_heading.tres")
const NAME_FONT_RESOURCE: Font = preload("res://assets/template/fonts/display/card_name.tres")
const NUMBER_FONT_RESOURCE: Font = preload("res://assets/template/fonts/display/card_number.tres")

static var _catalogs := {}
static var _locale := ""
static var _loaded := false


static func t(key: String, placeholder_value: Variant = {}) -> String:
	_ensure_loaded()
	var catalog: Dictionary = _catalogs.get(_locale, {})
	var english: Dictionary = _catalogs.get(DEFAULT_LOCALE, {})
	var value := String(catalog.get(key, english.get(key, key)))
	if not english.has(key):
		push_warning("Missing English localization key: %s" % key)
	if placeholder_value is Dictionary:
		var placeholders := placeholder_value as Dictionary
		return value if placeholders.is_empty() else value.format(placeholders)
	return value.format({"value": placeholder_value})


static func set_locale(locale: String, persist := false, preference_path := PREFERENCE_PATH) -> bool:
	_ensure_loaded()
	var normalized := _normalize_locale(locale)
	if not SUPPORTED_LOCALES.has(normalized) or not _catalogs.has(normalized):
		return false
	_locale = normalized
	TranslationServer.set_locale(normalized)
	if persist and not _save_preference(normalized, preference_path):
		push_warning("Unable to persist localization preference: %s" % preference_path)
	return true


static func toggle_locale(persist := true) -> String:
	set_locale("zh-CN" if current_locale() == "en" else "en", persist)
	return _locale


static func current_locale() -> String:
	_ensure_loaded()
	return _locale


static func available_locales() -> PackedStringArray:
	return SUPPORTED_LOCALES.duplicate()


static func catalog_keys(locale: String) -> PackedStringArray:
	_ensure_loaded()
	var keys := PackedStringArray()
	for key: Variant in (_catalogs.get(_normalize_locale(locale), {}) as Dictionary):
		keys.append(String(key))
	keys.sort()
	return keys


static func validate_catalogs() -> PackedStringArray:
	_ensure_loaded()
	var failures := PackedStringArray()
	var english_keys := catalog_keys(DEFAULT_LOCALE)
	for locale: String in SUPPORTED_LOCALES:
		var locale_keys := catalog_keys(locale)
		if locale_keys != english_keys:
			failures.append("Localization key mismatch for %s" % locale)
			continue
		var catalog: Dictionary = _catalogs[locale]
		var english: Dictionary = _catalogs[DEFAULT_LOCALE]
		for key: String in english_keys:
			if _placeholder_names(String(catalog[key])) != _placeholder_names(String(english[key])):
				failures.append("Placeholder mismatch for %s in %s" % [key, locale])
	return failures


static func apply_font(control: Control) -> void:
	if control == null:
		return
	_ensure_loaded()
	# Use Figtree with its Noto Sans SC fallback for both locales, including
	# mixed-script controls such as "EN / 中文" before the locale changes.
	control.add_theme_font_override(&"font", BUTTON_FONT_RESOURCE if control is Button else UI_FONT_RESOURCE)


static func apply_tree_fonts(root: Node) -> void:
	if root is Control:
		apply_font(root as Control)
	for node: Node in root.find_children("*", "Control", true, false):
		apply_font(node as Control)


static func _ensure_loaded() -> void:
	if _loaded:
		return
	for locale: String in SUPPORTED_LOCALES:
		var path := String(CATALOG_PATHS[locale])
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("Unable to open localization catalog: %s" % path)
			_catalogs[locale] = {}
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			push_error("Localization catalog must be a JSON object: %s" % path)
			_catalogs[locale] = {}
			continue
		_catalogs[locale] = parsed
	_locale = _detect_locale()
	TranslationServer.set_locale(_locale)
	_loaded = true


static func _detect_locale() -> String:
	var override := OS.get_environment(LOCALE_OVERRIDE_ENV)
	if not override.is_empty():
		var normalized_override := _normalize_locale(override)
		if SUPPORTED_LOCALES.has(normalized_override):
			return normalized_override
	if DisplayServer.get_name() != "headless" and OS.get_environment("GAME_CAPTURE_DIR").is_empty():
		var config := ConfigFile.new()
		if config.load(PREFERENCE_PATH) == OK:
			var saved := _normalize_locale(String(config.get_value(PREFERENCE_SECTION, PREFERENCE_KEY, "")))
			if SUPPORTED_LOCALES.has(saved):
				return saved
	# First launch (no saved choice): follow the system/browser language. On Web,
	# OS.get_locale() reflects navigator.language.
	return locale_for_system(OS.get_locale())


## Map a system/browser locale to a supported catalog: any Chinese variant
## (zh, zh_CN, zh-Hans, zh-TW, ...) uses Simplified Chinese; everything else English.
static func locale_for_system(system_locale: String) -> String:
	var language := system_locale.strip_edges().replace("_", "-").to_lower().get_slice("-", 0)
	return "zh-CN" if language == "zh" else DEFAULT_LOCALE


static func _save_preference(locale: String, preference_path: String) -> bool:
	if DisplayServer.get_name() == "headless" or not OS.get_environment("GAME_CAPTURE_DIR").is_empty():
		return true
	var config := ConfigFile.new()
	config.set_value(PREFERENCE_SECTION, PREFERENCE_KEY, locale)
	return config.save(preference_path) == OK


static func _placeholder_names(value: String) -> PackedStringArray:
	var regex := RegEx.new()
	regex.compile("\\{([A-Za-z][A-Za-z0-9_]*)\\}")
	var names := PackedStringArray()
	for result: RegExMatch in regex.search_all(value):
		names.append(result.get_string(1))
	names.sort()
	return names


static func _normalize_locale(locale: String) -> String:
	var normalized := locale.strip_edges().replace("_", "-").to_lower()
	if normalized == "zh" or normalized.begins_with("zh-cn") or normalized.begins_with("zh-sg") or normalized.begins_with("zh-hans"):
		return "zh-CN"
	if normalized.begins_with("en"):
		return "en"
	return locale
