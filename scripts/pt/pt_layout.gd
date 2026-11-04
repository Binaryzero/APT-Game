extends RefCounted
## Viewport-driven layout metrics for Packet Tactics.
## The project stretches with aspect "expand": Godot keeps a uniform element scale
## (min(window/DESIGN)) and grows the design viewport along the excess axis, so element
## sizes stay in design pixels while only regions and positions recompute from the viewport.

const DESIGN := Vector2(1600.0, 900.0)
const TOP_H := 30.0
const PROMPT_H := 34.0
const HAND_H := 200.0
const SIDE_W := 368.0
const MAIN_W := 1000.0
const MARGIN := 8.0

## Region geometry for the table screen from a design-viewport size (always >= 1280x720).
static func metrics(vp: Vector2) -> Dictionary:
	var hand_y: float = vp.y - MARGIN - HAND_H
	var prompt_y: float = hand_y - 6.0 - PROMPT_H
	var panels_y: float = TOP_H + 6.0
	var panels_h: float = maxf(240.0, prompt_y - 6.0 - panels_y)
	var side_x: float = vp.x - MARGIN - SIDE_W
	var span: float = side_x - 12.0 - MARGIN
	var main_x: float = MARGIN + maxf(0.0, (span - MAIN_W) * 0.5)
	return {
		"vp": vp, "top_h": TOP_H, "panels_y": panels_y, "panels_h": panels_h,
		"prompt_y": prompt_y, "hand_y": hand_y, "main_x": main_x, "main_w": MAIN_W,
		"side_x": side_x,
	}

## Top-left corner for a viewport-centered box (overlays and modals).
static func centered(vp: Vector2, w: float, h: float) -> Vector2:
	return Vector2((vp.x - w) * 0.5, (vp.y - h) * 0.5)