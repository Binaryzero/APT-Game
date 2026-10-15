extends SceneTree
## Headless rules check: plays many complete AI-vs-AI games and asserts engine invariants.
## Run: godot --headless --path . --script res://test/pt_engine_test.gd

const Engine_ := preload("res://scripts/pt/pt_engine.gd")
const AI := preload("res://scripts/pt/pt_ai.gd")
const Defs := preload("res://scripts/pt/pt_defs.gd")
const Card := preload("res://scripts/pt/pt_card.gd")

var failures: Array = []
var played := {}
var summary := {"games": 0, "servers": 0, "count": 0, "malware": 0, "software": 0, "rps": 0, "turns": 0}

func _initialize() -> void:
	_run.call_deferred()

func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		push_error("FAIL: " + msg)

func _run() -> void:
	for n_players in [2, 3, 4]:
		for seed_value in range(1, 41):
			await _play(n_players, seed_value, 6)
	await _play(2, 99, 5)
	await _play(2, 100, 7)
	await _determinism()
	await _deck_out_games()
	await _rps_check()
	_deck_checks()
	_coverage()
	print("PT_SUMMARY ", JSON.stringify(summary))
	if failures.is_empty():
		print("PT_ENGINE_TEST_OK")
		quit(0)
	else:
		print("PT_ENGINE_TEST_FAILED ", failures.size())
		quit(1)

func _make(n_players: int, seed_value: int, win: int) -> RefCounted:
	var e: RefCounted = Engine_.new()
	var plist: Array = []
	var brains: Array = []
	for i in n_players:
		plist.append({"name": "P%d" % i, "ai": true, "adv": i})
		brains.append(AI.new(i, seed_value))
	e.setup({"players": plist, "win": win, "seed": seed_value}, brains)
	return e

func _total_cards(e: RefCounted) -> int:
	var n: int = e.deck.size() + e.discard.size()
	for p: Dictionary in e.players:
		n += p.hand.size()
		for slot: Dictionary in p.net:
			n += 1
			if slot.soft != null:
				n += 1
			if slot.mal != null:
				n += 1
	return n

func _play(n_players: int, seed_value: int, win: int) -> void:
	var e := _make(n_players, seed_value, win)
	var expected: int = _total_cards(e)
	var watchdog := 0
	e.changed.connect(func() -> void:
		watchdog += 1)
	var tag := "%dp seed %d win %d" % [n_players, seed_value, win]
	await e.run()
	for line: Dictionary in e.log_lines:
		var t: String = line.text
		var idx := t.find(" plays ")
		if idx >= 0:
			var nm := t.substr(idx + 7).trim_suffix(".")
			played[nm] = int(played.get(nm, 0)) + 1
		else:
			idx = t.find(" answers with ")
			if idx >= 0:
				var nm2 := t.substr(idx + 14).trim_suffix("!")
				played[nm2] = int(played.get(nm2, 0)) + 1
	_check(e.over, tag + ": game did not finish")
	_check(_total_cards(e) == expected, tag + ": card count drifted %d -> %d" % [expected, _total_cards(e)])
	var uids := {}
	for c in e.deck + e.discard:
		_check(not uids.has(c.uid), tag + ": duplicate uid in deck/discard")
		uids[c.uid] = true
	for p: Dictionary in e.players:
		for c in p.hand:
			_check(not uids.has(c.uid), tag + ": duplicate uid in hand")
			uids[c.uid] = true
		for slot: Dictionary in p.net:
			_check(not uids.has(slot.server.uid), tag + ": duplicate server uid")
			uids[slot.server.uid] = true
			_check(slot.server.is_server(), tag + ": non-server in server slot")
			if slot.soft != null:
				_check(slot.soft.type() == "soft", tag + ": bad software slot")
				uids[slot.soft.uid] = true
			if slot.mal != null:
				_check(slot.mal.type() == "mal", tag + ": bad malware slot")
				uids[slot.mal.uid] = true
	_check(e.result.has("winner"), tag + ": no winner")
	summary.games += 1
	summary.turns += e.turn_number
	var kind := String(e.result.get("kind", ""))
	if summary.has(kind):
		summary[kind] += 1
	if kind == "servers":
		var w: Dictionary = e.players[int(e.result.winner)]
		_check(w.net.size() >= win, tag + ": server win without enough servers")

func _determinism() -> void:
	var a := _make(3, 7, 6)
	await a.run()
	var b := _make(3, 7, 6)
	await b.run()
	_check(a.result.winner == b.result.winner and a.turn_number == b.turn_number and a.log_lines.size() == b.log_lines.size(), "same seed must replay identically")

func _deck_checks() -> void:
	var keys: Array = Defs.deck_keys()
	_check(keys.size() >= 120, "deck too small: %d" % keys.size())
	var counts := {}
	for k in keys:
		counts[Defs.DEFS[k].type] = int(counts.get(Defs.DEFS[k].type, 0)) + 1
	print("PT_DECK ", JSON.stringify(counts), " total ", keys.size())
	for k: String in Defs.DEFS:
		var d: Dictionary = Defs.DEFS[k]
		_check(d.has("name") and d.has("type") and d.has("text"), k + ": missing fields")
		_check(Defs.TYPE_ART.has(d.type), k + ": unknown type")

func _deck_out_games() -> void:
	for n_players in [2, 3]:
		for seed_value in range(1, 25):
			var e := _make(n_players, seed_value, 99)
			e.deck = e.deck.slice(0, 22)
			await e.run()
			_check(e.over and e.result.has("winner"), "deck-out game must end")
			var kind := String(e.result.get("kind", ""))
			_check(kind in ["count", "malware", "software", "rps"], "deck-out kind: " + kind)
			summary[kind] = int(summary.get(kind, 0)) + 1
	print("PT_DECKOUT ", JSON.stringify(summary))

func _rps_check() -> void:
	var e := _make(3, 5, 6)
	var w: int = await e._rps_duel(0, 2)
	_check(w == 0 or w == 2, "rps duel returns one of the duelists")

func _coverage() -> void:
	var missing: Array = []
	for k: String in Defs.DEFS:
		var d: Dictionary = Defs.DEFS[k]
		if int(d.copies) > 0 and not played.has(d.name):
			missing.append(d.name)
	print("PT_NEVER_PLAYED ", missing)
