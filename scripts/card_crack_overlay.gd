class_name EmberpanCardCrackOverlay
extends Control

const CRACK_SHADOW := Color("#E80B0710")
const CRACK_EDGE := Color("#F4F2D8B5")


static func primary_branch_count(excess_damage: int) -> int:
	return 3 + clampi(excess_damage, 1, 9)


static func crack_reach(card_size: Vector2, excess_damage: int) -> float:
	var short_side := minf(card_size.x, card_size.y)
	return short_side * (0.28 + 0.055 * float(clampi(excess_damage, 1, 8)))


func configure(card_size: Vector2, excess_damage: int, max_health: int, crack_seed: int) -> void:
	size = card_size
	pivot_offset = card_size * 0.5
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var normalized_severity := clampf(float(excess_damage) / maxf(1.0, float(max_health)), 0.0, 1.0)
	var branch_count := primary_branch_count(excess_damage)
	var reach := crack_reach(card_size, excess_damage)
	set_meta("excess_damage", excess_damage)
	set_meta("severity", normalized_severity)
	set_meta("primary_branch_count", branch_count)
	set_meta("crack_reach", reach)

	var crack_rng := RandomNumberGenerator.new()
	crack_rng.seed = crack_seed
	var impact := card_size * 0.5 + Vector2(
		crack_rng.randf_range(-card_size.x * 0.08, card_size.x * 0.08),
		crack_rng.randf_range(-card_size.y * 0.10, card_size.y * 0.04)
	)
	var primary_paths: Array[PackedVector2Array] = []
	for branch_index in range(branch_count):
		var base_angle := TAU * float(branch_index) / float(branch_count)
		var angle := base_angle + crack_rng.randf_range(-0.24, 0.24)
		var length_scale := crack_rng.randf_range(0.72, 1.08)
		var segment_count := 3 + mini(3, excess_damage / 2)
		var path := _make_path(impact, angle, reach * length_scale, segment_count, crack_rng)
		primary_paths.append(path)
		_add_crack_path(path, 3.3 + normalized_severity * 1.5)

	var secondary_count := mini(6, excess_damage / 2)
	for fork_index in range(secondary_count):
		var source_path := primary_paths[fork_index % primary_paths.size()]
		var source_index := mini(source_path.size() - 1, 2 + fork_index % 2)
		var source := source_path[source_index]
		var parent_direction := source_path[source_index - 1].direction_to(source)
		var fork_angle := parent_direction.angle() + (-1.0 if fork_index % 2 == 0 else 1.0) * crack_rng.randf_range(0.62, 1.02)
		var fork_path := _make_path(source, fork_angle, reach * crack_rng.randf_range(0.30, 0.48), 2 + mini(2, excess_damage / 4), crack_rng)
		_add_crack_path(fork_path, 2.4 + normalized_severity)

	if excess_damage >= 7:
		for splinter_index in range(2):
			var source_path := primary_paths[(branch_count - 1 - splinter_index) % primary_paths.size()]
			var source := source_path[mini(source_path.size() - 1, 1 + splinter_index)]
			var splinter_angle := source_path[0].direction_to(source).angle() + (-0.9 if splinter_index == 0 else 0.9)
			_add_crack_path(_make_path(source, splinter_angle, reach * 0.25, 2, crack_rng), 2.1)

	set_meta("crack_path_count", branch_count + secondary_count + (2 if excess_damage >= 7 else 0))
	_add_impact_chip(impact, 4.0 + normalized_severity * 3.5)


func _make_path(origin: Vector2, angle: float, length: float, segment_count: int, crack_rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array([origin])
	var cursor := origin
	var direction_angle := angle
	for segment_index in range(segment_count):
		direction_angle += crack_rng.randf_range(-0.23, 0.23)
		var step_scale := crack_rng.randf_range(0.82, 1.18)
		var next := cursor + Vector2.from_angle(direction_angle) * (length / float(segment_count)) * step_scale
		next.x = clampf(next.x, 3.0, size.x - 3.0)
		next.y = clampf(next.y, 3.0, size.y - 3.0)
		if next.distance_to(cursor) < 1.0:
			break
		points.append(next)
		cursor = next
	return points


func _add_crack_path(points: PackedVector2Array, shadow_width: float) -> void:
	if points.size() < 2:
		return
	var shadow := Line2D.new()
	shadow.points = points
	shadow.width = shadow_width
	shadow.default_color = CRACK_SHADOW
	shadow.antialiased = true
	shadow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	shadow.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(shadow)

	var edge := Line2D.new()
	edge.points = points
	edge.position = Vector2(-0.8, -0.7)
	edge.width = maxf(0.8, shadow_width * 0.28)
	edge.default_color = CRACK_EDGE
	edge.antialiased = true
	edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
	edge.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(edge)


func _add_impact_chip(impact: Vector2, radius: float) -> void:
	var chip := Polygon2D.new()
	var points := PackedVector2Array()
	for point_index in range(9):
		var point_radius := radius * (0.68 if point_index % 2 == 0 else 1.0)
		points.append(Vector2.from_angle(TAU * float(point_index) / 9.0) * point_radius)
	chip.polygon = points
	chip.color = CRACK_SHADOW
	chip.position = impact
	add_child(chip)
