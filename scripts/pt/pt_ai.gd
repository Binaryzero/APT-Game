extends RefCounted
## Deterministic AI opponent. Decisions are pure functions of the visible game state and a
## per-seat seeded generator (used only for Rock-Paper-Scissors), so replays are reproducible.

const Defs := preload("res://scripts/pt/pt_defs.gd")
const Card := preload("res://scripts/pt/pt_card.gd")

const SOFT_VALUE := {
	"cloud_storage": 55.0, "cache_layer": 40.0, "firewall": 45.0, "password_manager": 38.0,
	"antivirus": 40.0, "auto_patcher": 42.0, "threat_feed": 58.0, "macro_engine": 55.0,
	"backup_agent": 44.0, "vpn_tunnel": 38.0,
}
const MAL_VALUE := {
	"sniffer": 20.0, "ransomware": 55.0, "memory_leak": 40.0, "cryptominer": 50.0,
	"rootkit": 38.0, "poisoned_package": 30.0, "exfil_trojan": 52.0, "throttle": 50.0,
}
const EXPLOIT_VALUE := {
	"server_hijack": 80.0, "data_wipe": 60.0, "double_tap": 38.0, "lateral_pivot": 40.0,
	"supply_chain": 38.0, "clean_sweep": 30.0, "rollback": 20.0, "phishing": 30.0,
	"social_engineering": 30.0, "bug_bounty": 45.0, "hot_swap": 20.0, "fresh_install": 25.0,
	"forced_failover": 55.0,
}

var seat: int = 0
var rng := RandomNumberGenerator.new()

func _init(p_seat: int, p_seed: int) -> void:
	seat = p_seat
	rng.seed = p_seed * 7919 + p_seat * 104729 + 13

# ------------------------------------------------------------ valuation

func soft_value(c: Card) -> float:
	return float(SOFT_VALUE.get(c.key, 35.0))

func harm(c: Card) -> float:
	return float(MAL_VALUE.get(c.key, 35.0))

## How good it is for `p` that attachment `c` sits in `owner_seat`'s network.
func attach_utility(c: Card, owner_seat: int, p: Dictionary) -> float:
	if c.type() == "soft":
		return soft_value(c) if owner_seat == p.seat else -soft_value(c) * 0.6
	return -harm(c) if owner_seat == p.seat else harm(c) * 0.8

func card_worth(e: RefCounted, c: Card) -> float:
	if c.is_server():
		var w := 100.0 + (10.0 if c.type() == "prod" else 0.0)
		var slot: Dictionary = e.slot_of(c)
		if not slot.is_empty():
			if slot.soft != null and slot.mal == null:
				w += soft_value(slot.soft) * 0.5
			if slot.mal != null:
				w -= harm(slot.mal) * 0.5
		return w
	if c.type() == "soft":
		return soft_value(c)
	return harm(c)

func hand_value(c: Card) -> float:
	match c.type():
		"zd":
			match String(c.def.zd):
				"cancel":
					return 72.0
				"root":
					return 62.0
				"kill":
					return 56.0
				_:
					return 42.0
		"prod":
			return 88.0
		"stage":
			return 82.0
		"soft":
			return soft_value(c)
		"mal":
			return harm(c) * 0.8 + 8.0
		"exploit":
			return float(EXPLOIT_VALUE.get(c.key, 30.0))
	return 10.0

func leader(e: RefCounted, p: Dictionary) -> int:
	var best := -1
	var best_score := -1.0
	for q: Dictionary in e.players:
		if q.seat == p.seat:
			continue
		var s := float(q.net.size()) * 10.0 + float(e.count_type(q, "soft")) - float(e.count_type(q, "mal")) * 0.5
		if s > best_score:
			best_score = s
			best = q.seat
	return best

# ---------------------------------------------------------------- main

func choose_main(e: RefCounted, p: Dictionary, first: bool) -> Dictionary:
	var best_score := -1.0e9
	var best_act: Dictionary = {"kind": "draw"}
	var draw_score := 22.0
	if p.hand.size() <= 3:
		draw_score += 8.0
	if p.hand.size() >= e.hand_limit(p):
		draw_score -= 10.0
	if first:
		best_score = draw_score
	else:
		best_score = 45.0
		best_act = {"kind": "end"}
	# free 0DAY draws
	for c in p.hand:
		var cc: Card = c
		if cc.type() == "zd" and String(cc.def.zd) == "cache" and p.hand.size() <= 4 and e.can_play(p, cc):
			return {"kind": "zd", "card": cc, "targets": {}}
	for c in p.hand:
		var card: Card = c
		if card.type() == "zd" or not e.can_play(p, card):
			continue
		for t in _enum_targets(e, p, card):
			var s := score_play(e, p, card, t)
			if s > best_score + 0.0001:
				best_score = s
				best_act = {"kind": "play", "card": card, "targets": t}
	return best_act

func _enum_targets(e: RefCounted, p: Dictionary, card: Card) -> Array:
	var out: Array = []
	_dfs(e, p, card, {}, out)
	return out

func _dfs(e: RefCounted, p: Dictionary, card: Card, targets: Dictionary, out: Array) -> void:
	if out.size() >= 80:
		return
	var s: Dictionary = e.next_spec(card, targets)
	if s.is_empty():
		out.append(targets.duplicate())
		return
	var ch: Array = e.choices_for(p, card, s, targets)
	if s.get("optional", false):
		var skip := targets.duplicate()
		skip[s.id] = null
		_dfs(e, p, card, skip, out)
	var n := 0
	for c in ch:
		var t2 := targets.duplicate()
		t2[s.id] = c
		_dfs(e, p, card, t2, out)
		n += 1
		if n >= 10:
			break

func score_play(e: RefCounted, p: Dictionary, card: Card, t: Dictionary) -> float:
	var key := card.key
	var win: int = e.win_target
	match card.type():
		"prod", "stage":
			if p.net.size() + 1 >= win:
				return 10000.0
			var s := 100.0 if card.type() == "prod" else 94.0
			if card.def.has("enter"):
				s += 6.0
			if p.net.size() + 1 >= win - 1:
				s += 30.0
			return s
		"soft":
			var srv: Card = t.srv
			var s2 := soft_value(card) + 18.0
			if key == "cloud_storage" or key == "cache_layer":
				if p.hand.size() >= e.hand_limit(p) - 1:
					s2 += 22.0
			if e.slot_of(srv).get("mal") != null:
				s2 -= 100.0
			return s2
		"mal":
			var srv2: Card = t.srv
			var qs: int = e.owner_of(srv2)
			if qs == p.seat:
				return -300.0
			var s3 := harm(card) + 22.0
			var slot: Dictionary = e.slot_of(srv2)
			if slot.soft != null:
				s3 += soft_value(slot.soft) * 0.9
			var q: Dictionary = e.players[qs]
			if qs == leader(e, p):
				s3 += 18.0
			s3 += float(q.net.size()) * 3.0
			return s3
		"exploit":
			return _score_exploit(e, p, card, t)
	return 0.0

func _score_exploit(e: RefCounted, p: Dictionary, card: Card, t: Dictionary) -> float:
	var win: int = e.win_target
	match card.key:
		"server_hijack":
			var srv: Card = t.srv
			var q: Dictionary = e.players[e.owner_of(srv)]
			if p.net.size() + 1 >= win:
				return 9000.0
			var s := 112.0 + (8.0 if srv.type() == "prod" else 0.0)
			if q.net.size() >= win - 1:
				s += 60.0
			return s
		"data_wipe":
			var srv2: Card = t.srv
			var qs: int = e.owner_of(srv2)
			if qs == p.seat:
				return -500.0
			var q2: Dictionary = e.players[qs]
			var s2 := 64.0
			if q2.net.size() >= win - 1:
				s2 += 70.0
			if qs == leader(e, p):
				s2 += 10.0
			if srv2.def.get("on_delete", "") == "return" or e.mods(q2).get("backup", false):
				s2 -= 55.0
			return s2
		"double_tap":
			var total := 28.0
			for id in ["a", "b"]:
				var c = t.get(id)
				if c != null:
					total -= attach_utility(c, e.owner_of(c), p)
			return total
		"lateral_pivot", "supply_chain":
			var src: Card = t.src
			var dst: Card = t.dst
			var from_owner: int = e.owner_of(src)
			var to_owner: int = e.owner_of(dst)
			var gain := attach_utility(src, to_owner, p) - attach_utility(src, from_owner, p)
			return 22.0 + gain
		"clean_sweep":
			var total2 := 0.0
			for slot: Dictionary in p.net:
				if slot.mal != null:
					total2 += harm(slot.mal)
			return 14.0 + total2 if total2 >= 30.0 else -100.0
		"rollback":
			var c2: Card = t.c
			if c2.is_attach() and c2.type() == "mal":
				return 22.0 + harm(c2) + 18.0
			return -400.0
		"phishing":
			var s3 := 34.0
			for q3: Dictionary in e.players:
				if q3.seat != p.seat:
					s3 += 4.0 + float(q3.hand.size())
			return s3
		"social_engineering":
			var q4: Dictionary = e.players[int(t.pl)]
			if q4.hand.size() < 2:
				return 10.0
			return 38.0 + float(q4.hand.size()) * 3.0 + (12.0 if int(t.pl) == leader(e, p) else 0.0)
		"bug_bounty":
			var over: int = maxi(0, p.hand.size() - 1 + 3 - e.hand_limit(p))
			return 48.0 - float(over) * 6.0
		"hot_swap":
			var c3: Card = t.c
			if c3.type() == "mal":
				return 24.0 + harm(c3) * 0.8
			if c3.is_server():
				var slot2: Dictionary = e.slot_of(c3)
				if slot2.mal != null:
					return harm(slot2.mal) - 12.0
			return -400.0
		"fresh_install":
			return 30.0 if p.hand.size() >= 5 else -60.0
		"forced_failover":
			var q5: Dictionary = e.players[int(t.pl)]
			var s4 := 58.0
			if q5.net.size() >= win - 1:
				s4 += 60.0
			if int(t.pl) == leader(e, p):
				s4 += 8.0
			if q5.net.size() <= 1:
				s4 -= 30.0
			return s4
	return 0.0

# ------------------------------------------------------------ responses

func choose_response(e: RefCounted, p: Dictionary, opts: Array):
	var top: Dictionary = e.stack.back()
	var threat := _threat(e, p, top)
	var by := {}
	for c in opts:
		var cc: Card = c
		var z := String(cc.def.zd)
		if not by.has(z):
			by[z] = cc
	if threat >= 40.0:
		if by.has("root"):
			return by.root
		if by.has("kill") and threat >= 45.0:
			return by.kill
		if by.has("cancel"):
			return by.cancel
	return null

func _threat(e: RefCounted, p: Dictionary, top: Dictionary) -> float:
	var c: Card = top.card
	var o: int = top.owner
	var win: int = e.win_target
	if c.type() == "zd":
		if e.stack.size() < 2:
			return 0.0
		var below: Dictionary = e.stack[e.stack.size() - 2]
		var z := String(c.def.zd)
		if z == "cancel" or z == "kill":
			if below.owner == p.seat:
				return _item_value(e, p, below)
			return 0.0
		if z == "root":
			if below.owner == p.seat:
				return _item_value(e, p, below)
		return 0.0
	var oplayer: Dictionary = e.players[o]
	if c.is_server():
		if oplayer.net.size() + 1 >= win:
			return 500.0
		if oplayer.net.size() + 1 >= win - 1:
			return 55.0
		return 10.0
	if c.type() == "soft":
		return 0.0
	if c.type() == "mal":
		var srv = top.targets.get("srv")
		if srv != null and e.owner_of(srv) == p.seat:
			var s := harm(c)
			var slot: Dictionary = e.slot_of(srv)
			if slot.soft != null:
				s += soft_value(slot.soft) * 0.9
			return s
		return 0.0
	if c.type() == "exploit":
		if e.exploit_victims(top).has(p.seat):
			match c.key:
				"server_hijack":
					return 110.0
				"data_wipe":
					return 90.0 if p.net.size() >= 2 else 40.0
				_:
					var t: Dictionary = top.targets
					var cc = t.get("src", t.get("a"))
					if cc != null:
						return absf(attach_utility(cc, p.seat, p)) + 10.0
					return 40.0
		if c.key == "social_engineering" or c.key == "forced_failover":
			if int(top.targets.get("pl", -1)) == p.seat:
				return 60.0 if c.key == "forced_failover" else 45.0
		if c.key == "lateral_pivot":
			var dst = top.targets.get("dst")
			var src = top.targets.get("src")
			if dst != null and src != null and e.owner_of(dst) == p.seat and src.type() == "mal":
				return harm(src) + 10.0
		if c.key == "phishing":
			return 36.0 if p.hand.size() >= 4 else 20.0
	return 0.0

func _item_value(e: RefCounted, p: Dictionary, item: Dictionary) -> float:
	var c: Card = item.card
	if c.type() == "zd":
		# my own 0DAY being answered: only worth protecting if it was itself defending something big
		return 50.0 if e.stack.size() >= 3 else 0.0
	return score_play_item(e, p, item)

func score_play_item(e: RefCounted, p: Dictionary, item: Dictionary) -> float:
	var c: Card = item.card
	var t: Dictionary = item.targets
	if c.is_server():
		if p.net.size() + 1 >= e.win_target:
			return 500.0
		return 60.0
	if c.type() == "exploit":
		return minf(100.0, _score_exploit_safe(e, p, c, t))
	if c.type() == "mal" or c.type() == "soft":
		return 30.0
	return 0.0

func _score_exploit_safe(e: RefCounted, p: Dictionary, c: Card, t: Dictionary) -> float:
	# The card is already off the table; evaluate using the same heuristics defensively.
	for k in t:
		if t[k] is Card and (e.locate(t[k]).is_empty()):
			return 0.0
	return _score_exploit(e, p, c, t)

# ------------------------------------------------------- other decisions

func choose_discard(e: RefCounted, p: Dictionary, n: int, _why: String) -> Array:
	var cards: Array = p.hand.duplicate()
	cards.sort_custom(func(a: Card, b: Card) -> bool:
		var va := hand_value(a)
		var vb := hand_value(b)
		if va == vb:
			return a.uid < b.uid
		return va < vb)
	return cards.slice(0, n)

func choose_card(e: RefCounted, p: Dictionary, cands: Array, purpose: String, _prompt: String):
	var best = cands[0]
	var best_score := -1.0e9
	for c in cands:
		var cc: Card = c
		var s := 0.0
		match purpose:
			"remove_bad":
				var o: int = e.owner_of(cc)
				s = harm(cc) if o == p.seat else -harm(cc)
			"uninstall_own":
				s = -card_worth(e, cc)
				if e.players[p.seat].net.size() <= 1:
					s = 0.0
			"steal_best", "wipe_best":
				s = card_worth(e, cc)
		s += -float(cc.uid) * 0.0001
		if s > best_score:
			best_score = s
			best = cc
	return best

func choose_yes_no(e: RefCounted, p: Dictionary, prompt: String, src) -> bool:
	if prompt.contains("DISCARD a card, then DRAW"):
		var worst := 999.0
		for c in p.hand:
			worst = minf(worst, hand_value(c))
		return not p.hand.is_empty() and worst < 48.0
	if prompt.contains("Malware"):
		for slot: Dictionary in p.net:
			if slot.mal != null:
				return true
		return false
	if prompt.contains("return it"):
		var slot2: Dictionary = e.slot_of(src)
		return not slot2.is_empty() and slot2.mal != null
	return true

func choose_option(_e: RefCounted, _p: Dictionary, _prompt: String, options: Array) -> int:
	return options.size() - 1

func choose_rps(_e: RefCounted, _p: Dictionary, _vs: String) -> int:
	return rng.randi_range(0, 2)
