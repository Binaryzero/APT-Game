extends "res://scripts/manus/preview/tuning_transport.gd"

func store() -> Variant:
	return get_node_or_null("/root/RuntimeTuning")

func settings() -> Array:
	var result: Array = store()._catalog.duplicate(true)
	for entry: Dictionary in result:
		entry["label_key"] = "tuning.parameter.%s.label" % str(entry.id)
		entry["description_key"] = "tuning.parameter.%s.description" % str(entry.id)
		entry["integrity"] = "GAMEPLAY" if store().is_rank_affecting(entry.id) else "COSMETIC"
	return result

func requested(setting: Dictionary) -> Variant:
	return store().get_value(StringName(setting.id))

func active(setting: Dictionary) -> Variant:
	return store().active_value(StringName(setting.id),setting.default)

func commit(patch: Dictionary) -> bool:
	return store().apply_preview_patch(patch)

func translate(value: String) -> String:
	return str(preload("res://scripts/localization.gd").t(value)) if not value.is_empty() else ""

func control_for(setting: Dictionary) -> Dictionary:
	var localized := setting.duplicate(true)
	localized["category_key"] = "tuning.category." + str(setting.category).to_lower()
	var unit := str(setting.get("unit", "")).to_lower()
	if unit in ["armor", "attack", "cards", "damage", "health", "lines", "mana", "ratio", "slots", "units"]: localized["unit_key"] = "tuning.unit." + unit
	return super.control_for(localized)
