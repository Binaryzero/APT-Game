extends SceneTree
## Fast checks for starting state and every card's required art resource.
## Run with: godot --headless --path . --script res://test/pt_smoke_test.gd

const Defs := preload("res://scripts/pt/pt_defs.gd")
const PTTheme := preload("res://scripts/pt/pt_theme.gd")
const EngineScript := preload("res://scripts/pt/pt_engine.gd")
const AI := preload("res://scripts/pt/pt_ai.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("PT_SMOKE_FAIL: " + message)

func _run() -> void:
	_check(Defs.deck_keys().size() >= 120, "representative deck should contain at least 120 cards")
	for key: String in Defs.DEFS:
		var def: Dictionary = Defs.DEFS[key]
		_check(def.has("name") and def.has("type") and def.has("text"), "%s needs name, type, and rules text" % key)
		_check(Defs.TYPE_ART.has(def.get("type", "")), "%s uses an unknown card type" % key)
		var texture: Texture2D = PTTheme.art_for_card(key, String(def.get("type", "")))
		_check(texture != null and texture.get_width() > 0 and texture.get_height() > 0, "%s has no loadable illustration" % key)
		if int(def.get("copies", 0)) > 0:
			_check(PTTheme.CARD_ART.has(key), "%s lacks a card-specific art mapping" % key)

	for player_count: int in [2, 3, 4]:
		_check_starting_state(player_count)

	if failures.is_empty():
		print("PT_SMOKE_TEST_OK cards=%d mapped_art=%d player_counts=2,3,4" % [Defs.DEFS.size(), PTTheme.CARD_ART.size()])
		quit(0)
	else:
		print("PT_SMOKE_TEST_FAILED count=%d" % failures.size())
		quit(1)

func _check_starting_state(player_count: int) -> void:
	var engine: RefCounted = EngineScript.new()
	var players: Array = []
	var brains: Array = []
	for seat: int in player_count:
		players.append({"name": "P%d" % (seat + 1), "ai": true, "adv": seat})
		brains.append(AI.new(seat, 20261015))
	engine.setup({"players": players, "win": Defs.WIN_DEFAULT, "seed": 20261015}, brains)

	_check(engine.players.size() == player_count, "%d-player setup should preserve player count" % player_count)
	_check(engine.deck.size() == Defs.deck_keys().size() - player_count * (Defs.OPENING_HAND + 1), "%d-player setup has the wrong remaining deck size" % player_count)
	for p: Dictionary in engine.players:
		_check(p.net.size() == 1, "%s should begin with exactly one server" % p.name)
		if p.net.size() == 1:
			_check(p.net[0].server.key == "staging_start", "%s should begin with a Staging Server" % p.name)
		_check(p.hand.size() == Defs.OPENING_HAND + 1, "%s should begin with five cards plus a 0DAY" % p.name)
		var ddos_count := 0
		for card in p.hand:
			if card.key == "small_ddos":
				ddos_count += 1
		_check(ddos_count >= 1, "%s should begin with the guaranteed Small DDoS 0DAY" % p.name)

	var total: int = engine.deck.size() + engine.discard.size()
	for p: Dictionary in engine.players:
		total += p.hand.size()
		for slot: Dictionary in p.net:
			total += 1 + int(slot.soft != null) + int(slot.mal != null)
	_check(total == Defs.deck_keys().size() + player_count, "setup should conserve deck cards plus one starter server per player")
