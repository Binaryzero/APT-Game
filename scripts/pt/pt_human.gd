extends RefCounted
## Brain for a human seat: every decision is delegated to the game UI, which awaits player input.

var ui: Node = null
var seat: int = 0

func _init(p_ui: Node, p_seat: int) -> void:
	ui = p_ui
	seat = p_seat

func choose_main(e: RefCounted, p: Dictionary, first: bool) -> Dictionary:
	return await ui.h_main(e, p, first)

func choose_response(e: RefCounted, p: Dictionary, opts: Array):
	return await ui.h_response(e, p, opts)

func choose_discard(e: RefCounted, p: Dictionary, n: int, why: String) -> Array:
	return await ui.h_discard(e, p, n, why)

func choose_card(e: RefCounted, p: Dictionary, cands: Array, purpose: String, prompt: String):
	return await ui.h_pick_card(e, p, cands, purpose, prompt)

func choose_yes_no(e: RefCounted, p: Dictionary, prompt: String, src) -> bool:
	return await ui.h_yes_no(e, p, prompt, src)

func choose_option(e: RefCounted, p: Dictionary, prompt: String, options: Array) -> int:
	return await ui.h_option(e, p, prompt, options)

func choose_rps(e: RefCounted, p: Dictionary, vs_name: String) -> int:
	return await ui.h_rps(e, p, vs_name)
