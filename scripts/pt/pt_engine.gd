extends RefCounted
## Authoritative rules engine for Packet Tactics. No UI code: decisions are requested from
## per-seat "brains" (AI or human) and may be awaited, so the same engine runs headless in tests.

const Defs := preload("res://scripts/pt/pt_defs.gd")
const Card := preload("res://scripts/pt/pt_card.gd")

const MAX_SERVERS := 9
const ROOT_KEYS := ["lateral_pivot", "server_hijack", "data_wipe", "double_tap", "supply_chain"]
const REFLECT_KEYS := ["server_hijack", "data_wipe", "double_tap"]
const ENTER_KEYS := ["server_hijack", "lateral_pivot", "supply_chain"]

signal changed
signal logged(text: String, kind: String)
signal announced(seat: int, card: RefCounted, note: String)
signal stack_changed
signal rps_round(a: int, b: int, ca: int, cb: int, result: String)
signal finished(result: Dictionary)

var tree: SceneTree = null
var pace: float = 0.0
var rng := RandomNumberGenerator.new()
var seed_value: int = 0
var players: Array = []
var deck: Array = []
var discard: Array = []
var current: int = 0
var turn_number: int = 0
var phase: String = ""
var win_target: int = Defs.WIN_DEFAULT
var base_hand: int = Defs.HAND_LIMIT
var over: bool = false
var result: Dictionary = {}
var stack: Array = []
var deck_empty: bool = false
var log_lines: Array = []
var _uid: int = 0

# ----------------------------------------------------------------- setup

func setup(cfg: Dictionary, brains: Array) -> void:
	seed_value = int(cfg.get("seed", 1))
	rng.seed = seed_value
	win_target = int(cfg.get("win", Defs.WIN_DEFAULT))
	base_hand = int(cfg.get("hand_limit", Defs.HAND_LIMIT))
	players.clear()
	deck.clear()
	discard.clear()
	log_lines.clear()
	over = false
	result = {}
	stack = []
	deck_empty = false
	current = 0
	turn_number = 0
	var plist: Array = cfg.players
	for i in plist.size():
		var pc: Dictionary = plist[i]
		players.append({
			"seat": i, "name": String(pc.name), "ai": bool(pc.ai), "adv": int(pc.adv),
			"hand": [], "net": [], "brain": brains[i], "actions_left": 0,
		})
	for key: String in Defs.deck_keys():
		deck.append(_new_card(key))
	_shuffle(deck)
	var opening: int = int(cfg.get("opening", Defs.OPENING_HAND))
	for p: Dictionary in players:
		p.net.append(_new_slot(_new_card("staging_start")))
		for i in deck.size():
			if (deck[i] as Card).key == "small_ddos":
				p.hand.append(deck.pop_at(i))
				break
	for p: Dictionary in players:
		for i in opening:
			if not deck.is_empty():
				p.hand.append(deck.pop_back())
	_log("Network online. First to %d servers wins." % win_target, "sys")

func _new_card(key: String) -> Card:
	_uid += 1
	return Card.new(_uid, key, Defs.DEFS[key])

func _new_slot(server: Card) -> Dictionary:
	return {"server": server, "soft": null, "mal": null}

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _pace(seconds: float) -> void:
	if tree != null and pace > 0.0 and not over:
		await tree.create_timer(seconds * pace).timeout

func _log(text: String, kind := "info") -> void:
	log_lines.append({"text": text, "kind": kind})
	if log_lines.size() > 400:
		log_lines.pop_front()
	logged.emit(text, kind)

# ------------------------------------------------------------- queries

func seat_count() -> int:
	return players.size()

func pname(seat: int) -> String:
	return String(players[seat].name)

func active_attach(slot: Dictionary):
	if slot.mal != null:
		return slot.mal
	return slot.soft

## Static modifiers that apply to a player's network right now. Malware suppresses Software
## installed on the same server.
func mods(p: Dictionary) -> Dictionary:
	var m := {"hand": 0, "draw_bonus": 0, "extra_play": 0}
	for slot: Dictionary in p.net:
		var a = active_attach(slot)
		if a == null or not (a as Card).def.has("mods"):
			continue
		var cm: Dictionary = (a as Card).def.mods
		for k: String in cm:
			if cm[k] is bool:
				m[k] = true
			else:
				m[k] = int(m.get(k, 0)) + int(cm[k])
	return m

func hand_limit(p: Dictionary) -> int:
	return maxi(0, base_hand + int(mods(p).hand))

func hand_revealed(p: Dictionary) -> bool:
	return bool(mods(p).get("reveal", false))

func count_type(p: Dictionary, t: String) -> int:
	var n := 0
	for slot: Dictionary in p.net:
		if (slot.server as Card).type() == t:
			n += 1
		if slot.soft != null and t == "soft":
			n += 1
		if slot.mal != null and t == "mal":
			n += 1
	return n

func locate(card: Card) -> Dictionary:
	for p: Dictionary in players:
		for i in p.net.size():
			var slot: Dictionary = p.net[i]
			if slot.server == card:
				return {"p": p.seat, "s": i, "l": "server"}
			if slot.soft == card:
				return {"p": p.seat, "s": i, "l": "soft"}
			if slot.mal == card:
				return {"p": p.seat, "s": i, "l": "mal"}
	return {}

func owner_of(card: Card) -> int:
	var ref := locate(card)
	return -1 if ref.is_empty() else int(ref.p)

func slot_of(card: Card) -> Dictionary:
	var ref := locate(card)
	if ref.is_empty():
		return {}
	return players[ref.p].net[ref.s]

func is_covered(card: Card) -> bool:
	var slot := slot_of(card)
	return not slot.is_empty() and slot.soft == card and slot.mal != null

func slot_accepts(slot: Dictionary, t: String) -> bool:
	if t == "soft":
		return slot.soft == null and slot.mal == null
	if t == "mal":
		return slot.mal == null
	return false

# ------------------------------------------------------- target specs

func spec_for(card: Card) -> Array:
	match card.type():
		"soft":
			return [{"id": "srv", "kind": "dest_self", "prompt": "Choose a Server in your NETWORK to install on"}]
		"mal":
			return [{"id": "srv", "kind": "mal_dest", "prompt": "Choose a Server to infect"}]
		"exploit":
			return card.def.get("spec", [])
	return []

func next_spec(card: Card, targets: Dictionary) -> Dictionary:
	for s: Dictionary in spec_for(card):
		if not targets.has(s.id):
			return s
	return {}

func _moving(card: Card, targets: Dictionary) -> Card:
	if targets.has("src") and targets.src != null:
		return targets.src
	return card

## Valid choices for the next target slot. Cards for card kinds, seat ints for player kinds.
func choices_for(p: Dictionary, card: Card, s: Dictionary, targets: Dictionary) -> Array:
	var out: Array = []
	var key := card.key
	match String(s.kind):
		"attach", "attach_soft_other":
			for q: Dictionary in players:
				for slot: Dictionary in q.net:
					var a = active_attach(slot)
					if a == null:
						continue
					if s.kind == "attach_soft_other" and (q.seat == p.seat or (a as Card).type() != "soft"):
						continue
					if q.seat != p.seat and (key == "lateral_pivot" or key == "supply_chain") and mods(q).get("anti_steal", false):
						continue
					if key == "lateral_pivot" and _dest_options(p, a, q.seat).is_empty():
						continue
					out.append(a)
		"attach_same":
			var a_card = targets.get("a")
			if a_card != null:
				var q_seat := owner_of(a_card)
				if q_seat >= 0:
					for slot: Dictionary in players[q_seat].net:
						var a = active_attach(slot)
						if a != null and a != a_card:
							out.append(a)
		"server":
			for q: Dictionary in players:
				if s.who == "other" and q.seat == p.seat:
					continue
				var m := mods(q)
				if q.seat != p.seat:
					if key == "server_hijack" and m.get("anti_steal", false):
						continue
					if key == "data_wipe" and m.get("anti_delete", false):
						continue
				for slot: Dictionary in q.net:
					out.append(slot.server)
		"dest":
			var src = targets.get("src")
			if src != null:
				out = _dest_options(p, src, owner_of(src))
		"dest_self":
			var mv := _moving(card, targets)
			for slot: Dictionary in p.net:
				if slot_accepts(slot, mv.type()):
					out.append(slot.server)
		"mal_dest":
			for q: Dictionary in players:
				if mods(q).get("no_mal_in", false):
					continue
				for slot: Dictionary in q.net:
					if slot.mal == null:
						out.append(slot.server)
		"card_self":
			for slot: Dictionary in p.net:
				out.append(slot.server)
				var a = active_attach(slot)
				if a != null:
					out.append(a)
		"player":
			for q: Dictionary in players:
				if q.seat == p.seat:
					continue
				if mods(q).get("anti_target", false):
					continue
				out.append(q.seat)
	return out

## Servers that can receive `moving` from a network owned by `from_seat` (must be another network).
func _dest_options(p: Dictionary, moving: Card, from_seat: int) -> Array:
	var out: Array = []
	for q: Dictionary in players:
		if q.seat == from_seat:
			continue
		if moving.type() == "mal" and mods(q).get("no_mal_in", false):
			continue
		for slot: Dictionary in q.net:
			if slot_accepts(slot, moving.type()):
				out.append(slot.server)
	return out

func _fillable(p: Dictionary, card: Card, targets: Dictionary) -> bool:
	var s := next_spec(card, targets)
	if s.is_empty():
		return true
	var ch := choices_for(p, card, s, targets)
	if ch.is_empty():
		if s.get("optional", false):
			var t2 := targets.duplicate()
			t2[s.id] = null
			return _fillable(p, card, t2)
		return false
	for c in ch:
		var t3 := targets.duplicate()
		t3[s.id] = c
		if _fillable(p, card, t3):
			return true
	return false

func validate_targets(p: Dictionary, card: Card, targets: Dictionary) -> bool:
	var probe := {}
	for s: Dictionary in spec_for(card):
		if not targets.has(s.id):
			return false
		var pick = targets[s.id]
		var ch := choices_for(p, card, s, probe)
		if pick == null:
			if not s.get("optional", false):
				return false
		elif not ch.has(pick):
			return false
		probe[s.id] = pick
	return true

func can_play(p: Dictionary, card: Card) -> bool:
	if not p.hand.has(card):
		return false
	var m := mods(p)
	match card.type():
		"prod", "stage":
			return p.net.size() < MAX_SERVERS
		"soft":
			return not m.get("no_soft", false) and _fillable(p, card, {})
		"mal":
			return _fillable(p, card, {})
		"exploit":
			if m.get("no_exploit", false):
				return false
			if card.key == "clean_sweep" and count_type(p, "mal") == 0:
				return false
			return _fillable(p, card, {})
		"zd":
			return String(card.def.zd) == "cache"
	return false

# ---------------------------------------------------------- 0DAY logic

func exploit_victims(item: Dictionary) -> Array:
	var c: Card = item.card
	var t: Dictionary = item.targets
	var out: Array = []
	match c.key:
		"lateral_pivot", "supply_chain":
			if t.get("src") != null:
				out.append(owner_of(t.src))
		"server_hijack", "data_wipe":
			if t.get("srv") != null:
				out.append(owner_of(t.srv))
		"double_tap":
			if t.get("a") != null:
				out.append(owner_of(t.a))
	return out

func reflect_possible(item: Dictionary) -> bool:
	return item.card.key in REFLECT_KEYS

func response_options(p: Dictionary) -> Array:
	var out: Array = []
	if stack.is_empty():
		return out
	var top: Dictionary = stack.back()
	for c in p.hand:
		var card: Card = c
		if card.type() != "zd":
			continue
		match String(card.def.zd):
			"cancel", "cache":
				out.append(card)
			"kill":
				var tc: Card = top.card
				if tc.is_server() or tc.is_attach() or (tc.type() == "exploit" and tc.key in ENTER_KEYS):
					out.append(card)
			"root":
				var tc2: Card = top.card
				if tc2.type() == "exploit" and tc2.key in ROOT_KEYS and exploit_victims(top).has(p.seat):
					out.append(card)
	return out

# ------------------------------------------------------------ game flow

func run() -> void:
	while not over:
		await _take_turn(current)
		if over:
			break
		current = (current + 1) % seat_count()
		turn_number += 1

func _take_turn(seat: int) -> void:
	var p: Dictionary = players[seat]
	phase = "begin"
	changed.emit()
	_log("%s begins turn %d." % [p.name, turn_number + 1], "turn")
	await _pace(0.5)
	await _begin_effects(p)
	if over:
		return
	await _check_deck_out()
	if over:
		return
	phase = "draw"
	changed.emit()
	var n: int = 1 + int(mods(p).draw_bonus)
	n = maxi(0, n)
	if n > 0:
		_draw(p, n)
		_log("%s draws %d card%s." % [p.name, n, "" if n == 1 else "s"], "draw")
	else:
		_log("%s cannot draw this turn." % p.name, "warn")
	await _pace(0.4)
	await _check_deck_out()
	if over:
		return
	phase = "main"
	p.actions_left = 1 + int(mods(p).extra_play)
	var first := true
	var safety := 0
	while p.actions_left > 0 and not over and safety < 12:
		safety += 1
		changed.emit()
		var act: Dictionary = await p.brain.choose_main(self, p, first)
		if over:
			return
		var kind := String(act.get("kind", "draw"))
		if kind == "end" and not first:
			break
		if kind == "zd":
			var zc: Card = act.card
			if p.hand.has(zc) and can_play(p, zc):
				await play_card(p, zc, act.get("targets", {}))
			continue
		if kind == "play":
			var card: Card = act.card
			var targets: Dictionary = act.get("targets", {})
			if can_play(p, card) and validate_targets(p, card, targets):
				await play_card(p, card, targets)
				p.actions_left -= 1
				first = false
				await _check_deck_out()
				continue
			_log("Illegal play ignored; drawing instead.", "warn")
		# draw action (also the fallback)
		_draw(p, 1)
		_log("%s draws a card instead of playing." % p.name, "draw")
		p.actions_left -= 1
		first = false
		await _pace(0.4)
		await _check_deck_out()
	if over:
		return
	phase = "discard"
	changed.emit()
	await _discard_to_limit(p)
	if over:
		return
	await _check_deck_out()

func _discard_to_limit(p: Dictionary) -> void:
	var limit := hand_limit(p)
	if p.hand.size() > limit:
		var n: int = p.hand.size() - limit
		var chosen: Array = await p.brain.choose_discard(self, p, n, "Hand limit is %d" % limit)
		chosen = _sanitize_discard(p, chosen, n)
		for c in chosen:
			p.hand.erase(c)
			discard.append(c)
		_log("%s discards %s (hand limit %d)." % [p.name, _names(chosen), limit], "discard")
		changed.emit()
		await _pace(0.4)

func _sanitize_discard(p: Dictionary, chosen: Array, n: int) -> Array:
	var out: Array = []
	for c in chosen:
		if p.hand.has(c) and not out.has(c) and out.size() < n:
			out.append(c)
	var i := 0
	while out.size() < n and i < p.hand.size():
		if not out.has(p.hand[i]):
			out.append(p.hand[i])
		i += 1
	return out

func _names(cards: Array) -> String:
	var parts: Array = []
	for c in cards:
		parts.append((c as Card).title())
	return ", ".join(parts)

func _begin_effects(p: Dictionary) -> void:
	var queue: Array = []
	for slot: Dictionary in p.net:
		if (slot.server as Card).def.has("begin"):
			queue.append({"ops": slot.server.def.begin, "src": slot.server})
		var a = active_attach(slot)
		if a != null and (a as Card).def.has("begin"):
			queue.append({"ops": a.def.begin, "src": a})
	for entry: Dictionary in queue:
		if over:
			return
		var src: Card = entry.src
		if locate(src).is_empty():
			continue
		if src.is_attach() and is_covered(src):
			continue
		await _run_ops(p, entry.ops, src, "begin")

func _check_deck_out() -> void:
	if deck_empty and not over:
		await _finish_by_count()

func _draw(p: Dictionary, n: int) -> int:
	var got := 0
	for i in n:
		if deck.is_empty():
			break
		p.hand.append(deck.pop_back())
		got += 1
	if deck.is_empty():
		deck_empty = true
	changed.emit()
	return got

func _forced_discard(q: Dictionary, n: int, why: String) -> void:
	n = mini(n, q.hand.size())
	if n <= 0:
		_log("%s has no cards to discard." % q.name, "info")
		return
	var chosen: Array = await q.brain.choose_discard(self, q, n, why)
	chosen = _sanitize_discard(q, chosen, n)
	for c in chosen:
		q.hand.erase(c)
		discard.append(c)
	_log("%s discards %s." % [q.name, _names(chosen)], "discard")
	changed.emit()
	await _pace(0.35)

# ---------------------------------------------------------- playing cards

func play_card(p: Dictionary, card: Card, targets: Dictionary) -> void:
	p.hand.erase(card)
	card.installed_by = p.seat
	var item := {"card": card, "owner": p.seat, "targets": targets, "state": "active", "mode": ""}
	stack = [item]
	_log("%s plays %s." % [p.name, card.title()], "play")
	announced.emit(p.seat, card, "")
	changed.emit()
	stack_changed.emit()
	await _pace(0.8)
	await _response_loop()
	if over:
		return
	await _resolve_stack()
	stack = []
	stack_changed.emit()
	changed.emit()

func _response_loop() -> void:
	var guard := 0
	while not over and guard < 40:
		guard += 1
		var top: Dictionary = stack.back()
		var responded := false
		for k in range(1, seat_count()):
			var seat: int = (int(top.owner) + k) % seat_count()
			if await _offer_response(seat):
				responded = true
				break
		if not responded:
			return

func _offer_response(seat: int) -> bool:
	var p: Dictionary = players[seat]
	var opts := response_options(p)
	if opts.is_empty():
		return false
	var choice = await p.brain.choose_response(self, p, opts)
	if choice == null or not opts.has(choice):
		return false
	var card: Card = choice
	var mode := ""
	if String(card.def.zd) == "root":
		mode = "block"
		if reflect_possible(stack.back()):
			var pick: int = await p.brain.choose_option(self, p, "Remote Root: block the Exploit, or reflect it back?", ["Block", "Reflect"])
			mode = "reflect" if pick == 1 else "block"
	p.hand.erase(card)
	card.installed_by = p.seat
	stack.append({"card": card, "owner": seat, "targets": {}, "state": "active", "mode": mode})
	_log("%s answers with %s!" % [p.name, card.title()], "zd")
	announced.emit(seat, card, "0DAY")
	changed.emit()
	stack_changed.emit()
	await _pace(0.8)
	return true

func _resolve_stack() -> void:
	var n := stack.size()
	(stack[n - 1] as Dictionary).state = "active"
	for i in range(n - 2, -1, -1):
		var above: Dictionary = stack[i + 1]
		var st := "active"
		if above.state == "active" and (above.card as Card).type() == "zd":
			match String(above.card.def.zd):
				"cancel", "kill":
					st = "cancelled"
				"root":
					if (stack[i].card as Card).type() == "exploit":
						st = "rooted"
		(stack[i] as Dictionary).state = st
	stack_changed.emit()
	for i in range(n - 1, -1, -1):
		if over:
			return
		await _execute_item(i)
		stack_changed.emit()
		await _pace(0.35)

func _execute_item(i: int) -> void:
	var item: Dictionary = stack[i]
	var card: Card = item.card
	var p: Dictionary = players[item.owner]
	if item.state == "cancelled":
		_log("%s is cancelled." % card.title(), "zd")
		discard.append(card)
		changed.emit()
		return
	match card.type():
		"zd":
			match String(card.def.zd):
				"cache":
					_draw(p, 2)
					_log("%s draws 2 cards from the cache." % p.name, "draw")
				"kill":
					_draw(p, 1)
					_log("%s draws a card." % p.name, "draw")
				"cancel":
					pass
				"root":
					pass
			discard.append(card)
		"prod", "stage":
			await _add_server(p, card)
		"soft", "mal":
			var srv: Card = item.targets.get("srv")
			var slot := slot_of(srv) if srv != null else {}
			if slot.is_empty() or not slot_accepts(slot, card.type()):
				_log("%s fizzles." % card.title(), "warn")
				discard.append(card)
			else:
				if card.type() == "soft":
					slot.soft = card
				else:
					slot.mal = card
				card.installed_by = p.seat
				_log("%s installs %s on %s (%s)." % [p.name, card.title(), srv.title(), pname(owner_of(srv))], "install")
				announced.emit(p.seat, card, "installed")
				changed.emit()
		"exploit":
			await _apply_exploit(i)
			discard.append(card)
	changed.emit()

# -------------------------------------------------------- network edits

func _add_server(p: Dictionary, srv: Card) -> void:
	p.net.append(_new_slot(srv))
	_log("%s adds %s to their NETWORK (%d servers)." % [p.name, srv.title(), p.net.size()], "install")
	changed.emit()
	if _check_win(p):
		return
	await _run_ops(p, srv.def.get("enter", []), srv, "enter")
	_check_win(p)

func _check_win(p: Dictionary) -> bool:
	if over:
		return true
	if p.net.size() >= win_target:
		_finish({"winner": p.seat, "reason": "%s built a network of %d servers." % [p.name, p.net.size()], "kind": "servers"})
		return true
	return false

## Removes a server (and discards its attachments). dest: discard | hand | steal.
func _remove_server(q: Dictionary, srv: Card, dest: String) -> void:
	var idx := -1
	for i in q.net.size():
		if q.net[i].server == srv:
			idx = i
			break
	if idx < 0:
		return
	var slot: Dictionary = q.net[idx]
	q.net.remove_at(idx)
	for a in [slot.soft, slot.mal]:
		if a != null:
			discard.append(a)
	match dest:
		"discard":
			discard.append(srv)
		"hand":
			q.hand.append(srv)
	changed.emit()
	await _run_ops(q, srv.def.get("leave", []), srv, "leave")

func _delete_server(q: Dictionary, srv: Card) -> void:
	if srv.def.get("on_delete", "") == "return" or mods(q).get("backup", false):
		_log("%s returns to %s's hand instead of being deleted." % [srv.title(), q.name], "zd")
		await _remove_server(q, srv, "hand")
		return
	_log("%s is DELETED from %s's NETWORK." % [srv.title(), q.name], "delete")
	await _remove_server(q, srv, "discard")

func _delete_attach(card: Card, verb := "DELETED") -> void:
	var slot := slot_of(card)
	if slot.is_empty():
		return
	var q_seat := owner_of(card)
	if slot.soft == card:
		slot.soft = null
	elif slot.mal == card:
		slot.mal = null
	discard.append(card)
	_log("%s is %s from %s's NETWORK." % [card.title(), verb, pname(q_seat)], "delete")
	changed.emit()

func _detach(card: Card) -> void:
	var slot := slot_of(card)
	if slot.is_empty():
		return
	if slot.soft == card:
		slot.soft = null
	elif slot.mal == card:
		slot.mal = null

func _attach_to(srv: Card, card: Card, installer: int) -> bool:
	var slot := slot_of(srv)
	if slot.is_empty() or not slot_accepts(slot, card.type()):
		return false
	if card.type() == "soft":
		slot.soft = card
	else:
		slot.mal = card
	card.installed_by = installer
	return true

# -------------------------------------------------------------- exploits

func _apply_exploit(i: int) -> void:
	var item: Dictionary = stack[i]
	var card: Card = item.card
	var p: Dictionary = players[item.owner]
	var t: Dictionary = item.targets
	var reflect := false
	var responder: Dictionary = {}
	if item.state == "rooted":
		var rr: Dictionary = stack[i + 1]
		responder = players[rr.owner]
		if rr.mode == "reflect" and reflect_possible(item):
			reflect = true
			_log("%s REFLECTS %s back at %s!" % [responder.name, card.title(), p.name], "zd")
		else:
			_log("%s BLOCKS %s." % [responder.name, card.title()], "zd")
			return
	match card.key:
		"lateral_pivot", "supply_chain":
			var src: Card = t.get("src")
			var dst: Card = t.get("dst")
			if src == null or dst == null or locate(src).is_empty() or locate(dst).is_empty():
				_log("%s fizzles." % card.title(), "warn")
				return
			var from_name := pname(owner_of(src))
			_detach(src)
			if _attach_to(dst, src, p.seat):
				_log("%s moves %s from %s to %s's %s." % [p.name, src.title(), from_name, pname(owner_of(dst)), dst.title()], "install")
				announced.emit(p.seat, src, "moved")
			else:
				discard.append(src)
			changed.emit()
		"server_hijack":
			if reflect:
				var cands := _hijack_cands(p, responder)
				if cands.is_empty():
					_log("The reflection finds nothing to steal.", "warn")
					return
				var pick: Card = await responder.brain.choose_card(self, responder, cands, "steal_best", "Reflect: choose a Server to steal from %s" % p.name)
				_log("%s STEALS %s from %s." % [responder.name, pick.title(), p.name], "steal")
				await _remove_server(p, pick, "steal")
				await _add_server(responder, pick)
				return
			var srv: Card = t.get("srv")
			if srv == null or locate(srv).is_empty():
				_log("Server Hijack fizzles.", "warn")
				return
			var victim: Dictionary = players[owner_of(srv)]
			_log("%s STEALS %s from %s." % [p.name, srv.title(), victim.name], "steal")
			await _remove_server(victim, srv, "steal")
			await _add_server(p, srv)
		"data_wipe":
			var target_owner: Dictionary = p if reflect else {}
			var srv2: Card = t.get("srv")
			if reflect:
				var cands2: Array = []
				for slot: Dictionary in p.net:
					if not mods(p).get("anti_delete", false):
						cands2.append(slot.server)
				if cands2.is_empty():
					_log("The reflection finds nothing to delete.", "warn")
					return
				var pick2: Card = await responder.brain.choose_card(self, responder, cands2, "wipe_best", "Reflect: choose a Server of %s to delete" % p.name)
				await _delete_server(p, pick2)
				return
			if srv2 == null or locate(srv2).is_empty():
				_log("Data Wipe fizzles.", "warn")
				return
			target_owner = players[owner_of(srv2)]
			await _delete_server(target_owner, srv2)
		"double_tap":
			if reflect:
				var picks := 0
				if t.get("a") != null:
					picks += 1
				if t.get("b") != null:
					picks += 1
				var chosen_net := -1
				for k in picks:
					var cands3: Array = []
					for slot: Dictionary in p.net:
						var a = active_attach(slot)
						if a != null:
							cands3.append(a)
					if cands3.is_empty():
						break
					var pick3: Card = await responder.brain.choose_card(self, responder, cands3, "wipe_best", "Reflect: choose a card of %s to delete" % p.name)
					_delete_attach(pick3)
					chosen_net = p.seat
				return
			for key_id in ["a", "b"]:
				var c = t.get(key_id)
				if c != null and not locate(c).is_empty():
					_delete_attach(c)
		"clean_sweep":
			var doomed: Array = []
			for slot: Dictionary in p.net:
				if slot.mal != null:
					doomed.append(slot.mal)
			for c in doomed:
				_delete_attach(c)
		"rollback":
			var c2: Card = t.get("c")
			if c2 == null or locate(c2).is_empty():
				_log("Rollback fizzles.", "warn")
				return
			if c2.is_server():
				_log("%s UNINSTALLS %s." % [p.name, c2.title()], "delete")
				await _remove_server(p, c2, "discard")
			else:
				_delete_attach(c2, "UNINSTALLED")
			if over:
				return
			_draw(p, 2)
			_log("%s draws 2 cards." % p.name, "draw")
		"phishing":
			for k in range(1, seat_count()):
				var q: Dictionary = players[(p.seat + k) % seat_count()]
				await _forced_discard(q, 1, "Phishing Campaign")
				if over:
					return
		"social_engineering":
			var tp = t.get("pl")
			if tp != null:
				await _forced_discard(players[tp], 2, "Social Engineering")
		"bug_bounty":
			_draw(p, 3)
			_log("%s draws 3 cards." % p.name, "draw")
		"hot_swap":
			var c3: Card = t.get("c")
			if c3 == null or locate(c3).is_empty():
				_log("Hot Swap fizzles.", "warn")
				return
			if c3.is_server():
				_log("%s returns %s to their hand." % [p.name, c3.title()], "info")
				await _remove_server(p, c3, "hand")
			else:
				_detach(c3)
				p.hand.append(c3)
				_log("%s returns %s to their hand." % [p.name, c3.title()], "info")
				changed.emit()
		"fresh_install":
			if p.hand.size() >= 2:
				await _forced_discard(p, 2, "Fresh Install: discard 2")
				_draw(p, 3)
				_log("%s draws 3 cards." % p.name, "draw")
			else:
				_log("%s cannot discard 2 cards, so cannot draw." % p.name, "warn")
		"forced_failover":
			var tp2 = t.get("pl")
			if tp2 != null:
				var q2: Dictionary = players[tp2]
				var cands4: Array = []
				for slot: Dictionary in q2.net:
					cands4.append(slot.server)
				if cands4.is_empty():
					return
				var pick4: Card = await q2.brain.choose_card(self, q2, cands4, "uninstall_own", "Forced Failover: choose a Server to UNINSTALL")
				_log("%s UNINSTALLS %s." % [q2.name, pick4.title()], "delete")
				await _remove_server(q2, pick4, "discard")

func _hijack_cands(victim: Dictionary, thief: Dictionary) -> Array:
	var out: Array = []
	if mods(victim).get("anti_steal", false):
		return out
	for slot: Dictionary in victim.net:
		out.append(slot.server)
	return out

# ------------------------------------------------------------ server ops

func _run_ops(p: Dictionary, ops: Array, src: Card, trigger: String) -> void:
	for op: Dictionary in ops:
		if over:
			return
		var may: bool = op.get("may", false)
		match String(op.op):
			"draw":
				var who := String(op.get("who", "self"))
				var n: int = int(op.get("n", 1))
				if who == "self":
					_draw(p, n)
					_log("%s: %s draws %d." % [src.title(), p.name, n], "draw")
				elif who == "each":
					for k in seat_count():
						var q: Dictionary = players[(p.seat + k) % seat_count()]
						_draw(q, n)
					_log("%s: each player draws %d." % [src.title(), n], "draw")
			"discard":
				var who2 := String(op.get("who", "self"))
				var n2: int = int(op.get("n", 1))
				_log("%s triggers: DISCARD %d." % [src.title(), n2], "warn")
				if who2 == "self":
					await _forced_discard(p, n2, src.title())
				elif who2 == "others":
					for k in range(1, seat_count()):
						await _forced_discard(players[(p.seat + k) % seat_count()], n2, src.title())
			"rummage":
				if p.hand.is_empty():
					continue
				if may and not await p.brain.choose_yes_no(self, p, "%s: DISCARD a card, then DRAW a card?" % src.title(), src):
					continue
				await _forced_discard(p, 1, src.title() + ": discard, then draw")
				_draw(p, 1)
				_log("%s draws a card." % p.name, "draw")
			"delete_malware", "delete_own_malware":
				var cands: Array = []
				for q2: Dictionary in players:
					if op.op == "delete_own_malware" and q2.seat != p.seat:
						continue
					for slot: Dictionary in q2.net:
						if slot.mal != null:
							cands.append(slot.mal)
				if cands.is_empty():
					continue
				if may and not await p.brain.choose_yes_no(self, p, "%s: DELETE a Malware card?" % src.title(), src):
					continue
				var pick: Card = await p.brain.choose_card(self, p, cands, "remove_bad", "%s: choose a Malware card to DELETE" % src.title())
				_delete_attach(pick)
			"bounce_self":
				if locate(src).is_empty() or owner_of(src) != p.seat:
					continue
				if may and not await p.brain.choose_yes_no(self, p, "%s: return it to your hand?" % src.title(), src):
					continue
				_log("%s returns %s to their hand." % [p.name, src.title()], "info")
				await _remove_server(p, src, "hand")
			"extra_play":
				if phase == "main" and current == p.seat:
					p.actions_left += 1
					_log("%s grants %s an extra play this turn." % [src.title(), p.name], "info")
			"installer_draw":
				var who_seat: int = src.installed_by
				if who_seat >= 0 and who_seat < seat_count():
					_draw(players[who_seat], int(op.get("n", 1)))
					_log("%s: %s draws a card." % [src.title(), pname(who_seat)], "draw")
	changed.emit()
	await _pace(0.3)

# ------------------------------------------------------------ game end

func standings() -> Array:
	var rows: Array = []
	for p: Dictionary in players:
		rows.append({"seat": p.seat, "servers": p.net.size(), "malware": count_type(p, "mal"), "software": count_type(p, "soft")})
	return rows

func _finish_by_count() -> void:
	_log("The DECK is empty! Counting servers...", "sys")
	var rows := standings()
	var best_servers := 0
	for r: Dictionary in rows:
		best_servers = maxi(best_servers, int(r.servers))
	var tied: Array = rows.filter(func(r): return int(r.servers) == best_servers)
	var reason := "Most servers (%d) when the deck ran out." % best_servers
	var kind := "count"
	if tied.size() > 1:
		var least := 999
		for r: Dictionary in tied:
			least = mini(least, int(r.malware))
		tied = tied.filter(func(r): return int(r.malware) == least)
		reason = "Tied on servers; fewest Malware (%d) wins." % least
		kind = "malware"
		if tied.size() > 1:
			var most := -1
			for r: Dictionary in tied:
				most = maxi(most, int(r.software))
			tied = tied.filter(func(r): return int(r.software) == most)
			reason = "Tied on servers and Malware; most Software (%d) wins." % most
			kind = "software"
			if tied.size() > 1:
				var seats: Array = tied.map(func(r): return int(r.seat))
				_log("Still tied! Rock, Paper, Scissors decides it.", "sys")
				var champion: int = seats[0]
				for k in range(1, seats.size()):
					champion = await _rps_duel(champion, seats[k])
				reason = "Dead tie broken by Rock, Paper, Scissors."
				kind = "rps"
				_finish({"winner": champion, "reason": reason, "kind": kind})
				return
	_finish({"winner": int(tied[0].seat), "reason": reason, "kind": kind})

func _rps_duel(a: int, b: int) -> int:
	var wa := 0
	var wb := 0
	var guard := 0
	while wa < 2 and wb < 2 and guard < 30:
		guard += 1
		var ca: int = await players[a].brain.choose_rps(self, players[a], pname(b))
		var cb: int = await players[b].brain.choose_rps(self, players[b], pname(a))
		var diff := (ca - cb + 3) % 3
		var res := "draw"
		if diff == 1:
			wa += 1
			res = "a"
		elif diff == 2:
			wb += 1
			res = "b"
		var names := ["Rock", "Paper", "Scissors"]
		_log("%s: %s vs %s: %s" % [pname(a) + "/" + pname(b), names[ca], names[cb], "draw" if res == "draw" else (pname(a) if res == "a" else pname(b)) + " takes the round"], "sys")
		rps_round.emit(a, b, ca, cb, res)
		await _pace(1.0)
	return a if wa >= 2 else b

func _finish(res: Dictionary) -> void:
	if over:
		return
	over = true
	result = res
	result["standings"] = standings()
	_log("GAME OVER: %s wins! %s" % [pname(int(res.winner)), res.reason], "sys")
	changed.emit()
	finished.emit(result)
