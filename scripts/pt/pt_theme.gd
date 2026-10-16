extends RefCounted
## Shared palette, fonts and small drawing helpers for the Packet Tactics UI.

const Defs := preload("res://scripts/pt/pt_defs.gd")

const BG := Color("#04080c")
const PANEL := Color("#09131a")
const PANEL_2 := Color("#0e1d27")
const LINE := Color("#17303d")
const CYAN := Color("#27d3f5")
const CYAN_DIM := Color("#16788c")
const GREEN := Color("#3dff8e")
const WARN := Color("#ffb21f")
const RED := Color("#ff5a3c")
const VIOLET := Color("#c77dff")
const TEXT := Color("#d9eef5")
const TEXT_DIM := Color("#7fa3b1")

static var _font_cache := {}
static var _art_cache := {}

## Explicit preloads keep each card illustration in Godot web exports.
const CARD_ART := {
	"antivirus": preload("res://assets/pt/cards/antivirus.webp"),
	"api_gateway": preload("res://assets/pt/cards/api_gateway.webp"),
	"auth_server": preload("res://assets/pt/cards/auth_server.webp"),
	"auto_patcher": preload("res://assets/pt/cards/auto_patcher.webp"),
	"backdoor_cache": preload("res://assets/pt/cards/backdoor_cache.webp"),
	"backup_agent": preload("res://assets/pt/cards/backup_agent.webp"),
	"billing_cluster": preload("res://assets/pt/cards/billing_cluster.webp"),
	"bug_bounty": preload("res://assets/pt/cards/bug_bounty.webp"),
	"build_runner": preload("res://assets/pt/cards/build_runner.webp"),
	"canary_node": preload("res://assets/pt/cards/canary_node.webp"),
	"clean_sweep": preload("res://assets/pt/cards/clean_sweep.webp"),
	"cloud_storage": preload("res://assets/pt/cards/cloud_storage.webp"),
	"cryptominer": preload("res://assets/pt/cards/cryptominer.webp"),
	"customer_db": preload("res://assets/pt/cards/customer_db.webp"),
	"data_warehouse": preload("res://assets/pt/cards/data_warehouse.webp"),
	"data_wipe": preload("res://assets/pt/cards/data_wipe.webp"),
	"dev_sandbox": preload("res://assets/pt/cards/dev_sandbox.webp"),
	"domain_controller": preload("res://assets/pt/cards/domain_controller.webp"),
	"double_tap": preload("res://assets/pt/cards/double_tap.webp"),
	"escrow_vault": preload("res://assets/pt/cards/escrow_vault.webp"),
	"exfil_trojan": preload("res://assets/pt/cards/exfil_trojan.webp"),
	"failover_node": preload("res://assets/pt/cards/failover_node.webp"),
	"forced_failover": preload("res://assets/pt/cards/forced_failover.webp"),
	"fresh_install": preload("res://assets/pt/cards/fresh_install.webp"),
	"hot_standby": preload("res://assets/pt/cards/hot_standby.webp"),
	"hot_swap": preload("res://assets/pt/cards/hot_swap.webp"),
	"lateral_pivot": preload("res://assets/pt/cards/lateral_pivot.webp"),
	"macro_engine": preload("res://assets/pt/cards/macro_engine.webp"),
	"mail_relay": preload("res://assets/pt/cards/mail_relay.webp"),
	"memory_leak": preload("res://assets/pt/cards/memory_leak.webp"),
	"phishing": preload("res://assets/pt/cards/phishing.webp"),
	"poisoned_package": preload("res://assets/pt/cards/poisoned_package.webp"),
	"preview_env": preload("res://assets/pt/cards/preview_env.webp"),
	"process_kill": preload("res://assets/pt/cards/process_kill.webp"),
	"qa_cluster": preload("res://assets/pt/cards/qa_cluster.webp"),
	"ransomware": preload("res://assets/pt/cards/ransomware.webp"),
	"rollback": preload("res://assets/pt/cards/rollback.webp"),
	"rootkit": preload("res://assets/pt/cards/rootkit.webp"),
	"server_hijack": preload("res://assets/pt/cards/server_hijack.webp"),
	"small_ddos": preload("res://assets/pt/cards/small_ddos.webp"),
	"sniffer": preload("res://assets/pt/cards/sniffer.webp"),
	"social_engineering": preload("res://assets/pt/cards/social_engineering.webp"),
	"supply_chain": preload("res://assets/pt/cards/supply_chain.webp"),
	"test_bench": preload("res://assets/pt/cards/test_bench.webp"),
	"threat_feed": preload("res://assets/pt/cards/threat_feed.webp"),
	"throttle": preload("res://assets/pt/cards/throttle.webp"),
	"vpn_tunnel": preload("res://assets/pt/cards/vpn_tunnel.webp"),
	"cache_layer": preload("res://assets/pt/cards/cache_layer.webp"),
	"firewall": preload("res://assets/pt/cards/firewall.webp"),
	"password_manager": preload("res://assets/pt/cards/password_manager.webp"),
	"remote_root": preload("res://assets/pt/cards/remote_root.webp"),
}

static func font(kind: String) -> Font:
	if not _font_cache.has(kind):
		var path := "res://assets/template/fonts/ui_regular.tres"
		match kind:
			"bold":
				path = "res://assets/template/fonts/ui_bold.tres"
			"medium":
				path = "res://assets/template/fonts/ui_medium.tres"
			"title":
				path = "res://assets/template/fonts/display/card_title.tres"
			"name":
				path = "res://assets/template/fonts/display/card_name.tres"
			"number":
				path = "res://assets/template/fonts/display/card_number.tres"
		_font_cache[kind] = load(path)
	return _font_cache[kind]

static func art(type_key: String) -> Texture2D:
	var name_: String = Defs.TYPE_ART.get(type_key, "production")
	if not _art_cache.has(name_):
		_art_cache[name_] = load("res://assets/pt/art_%s.webp" % name_)
	return _art_cache[name_]

static func art_for_card(card_key: String, type_key: String) -> Texture2D:
	if CARD_ART.has(card_key):
		return CARD_ART[card_key]
	return art(type_key)

static func type_color(t: String) -> Color:
	return Defs.TYPE_COLOR.get(t, CYAN)

static func box(fill: Color, border: Color = Color(0, 0, 0, 0), bw := 1, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	return sb

static func style_button(b: Button, accent: Color = CYAN, font_size := 15) -> void:
	b.add_theme_font_override("font", font("bold"))
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.BLACK)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.5, 0.55))
	b.add_theme_stylebox_override("normal", box(Color(accent, 0.12), Color(accent, 0.8), 1, 6))
	b.add_theme_stylebox_override("hover", box(Color(accent, 0.28), accent, 2, 6))
	b.add_theme_stylebox_override("pressed", box(accent, accent, 2, 6))
	b.add_theme_stylebox_override("disabled", box(Color(0.1, 0.14, 0.17), Color(0.2, 0.28, 0.32), 1, 6))
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), GREEN, 2, 6))
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func make_label(text: String, size := 14, color: Color = TEXT, kind := "regular") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Shrinks a font size until `text` fits `width` on a single line.
static func fit_size(f: Font, text: String, width: float, start: int, minimum: int) -> int:
	var size := start
	while size > minimum and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size

## Largest font size (<= start) at which wrapped `text` fits in a box.
static func fit_block(f: Font, text: String, width: float, height: float, start: int, minimum: int) -> int:
	var size := start
	while size > minimum:
		var sz := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size)
		if sz.y <= height:
			break
		size -= 1
	return size
