extends RefCounted
## One physical card in play. Definitions live in pt_defs.gd; this is the runtime instance.

var uid: int = 0
var key: String = ""
var def: Dictionary = {}
## Seat of the player who installed this card (for Malware that benefits its installer).
var installed_by: int = -1

func _init(p_uid: int, p_key: String, p_def: Dictionary) -> void:
	uid = p_uid
	key = p_key
	def = p_def

func title() -> String:
	return String(def.get("name", key))

func type() -> String:
	return String(def.get("type", ""))

func is_server() -> bool:
	var t := type()
	return t == "prod" or t == "stage"

func is_attach() -> bool:
	var t := type()
	return t == "soft" or t == "mal"
