extends RefCounted
## Procedural tavern-kitchen materials for the card battler presentation: carved wood plaques with
## brass nails, framed slate menu boards hung on ropes, rarity card trim, faceted mana gems, candle
## glows and hearth embers. Everything is drawn in code or tiny shaders so no texture assets ship.

const WOOD_EDGE := Color("#140904")
const WOOD_DEEP := Color("#2E180C")
const WOOD_BASE := Color("#5B341A")
const WOOD_WARM := Color("#7A4622")
const BRASS := Color("#C99440")
const BRASS_LIGHT := Color("#FFE3A6")
const BRASS_DARK := Color("#5A3712")
const SLATE := Color("#1A1318")
const SLATE_LIGHT := Color("#33242E")
const ROPE := Color("#8C6A43")
const EMBER := Color("#F3A33C")
const GOLD := Color("#FFD36A")
const CREAM := Color("#F7E9C8")
const INK := Color("#100A18")

const SHINE_SHADER_CODE := """
shader_type canvas_item;
uniform vec2 size = vec2(1000.0, 100.0);
uniform float period = 5.0;
uniform float band_width = 0.07;
uniform vec4 shine_color : source_color = vec4(1.0, 0.98, 0.88, 0.9);
varying vec2 local_pos;
void vertex() {
	local_pos = VERTEX;
}
void fragment() {
	vec4 base = COLOR;
	float sweep = fract(TIME / period) * 1.8 - 0.4;
	float band = local_pos.x / size.x + (local_pos.y / size.y) * 0.25 - sweep;
	float strength = smoothstep(band_width, 0.0, abs(band));
	float fill = smoothstep(0.35, 0.65, max(base.r, base.g));
	COLOR = vec4(mix(base.rgb, shine_color.rgb, strength * shine_color.a * fill), base.a);
}
"""

const BACKDROP_SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float blur_radius = 2.2;
uniform float vignette = 0.85;
uniform float fade = 1.0;
void fragment() {
	vec4 tint = COLOR;
	vec2 px = SCREEN_PIXEL_SIZE * blur_radius;
	vec3 sum = texture(screen_texture, SCREEN_UV).rgb * 0.2;
	sum += texture(screen_texture, SCREEN_UV + vec2(px.x, 0.0)).rgb * 0.1;
	sum += texture(screen_texture, SCREEN_UV - vec2(px.x, 0.0)).rgb * 0.1;
	sum += texture(screen_texture, SCREEN_UV + vec2(0.0, px.y)).rgb * 0.1;
	sum += texture(screen_texture, SCREEN_UV - vec2(0.0, px.y)).rgb * 0.1;
	sum += texture(screen_texture, SCREEN_UV + px * 1.6).rgb * 0.1;
	sum += texture(screen_texture, SCREEN_UV - px * 1.6).rgb * 0.1;
	sum += texture(screen_texture, SCREEN_UV + vec2(px.x, -px.y) * 1.6).rgb * 0.1;
	sum += texture(screen_texture, SCREEN_UV + vec2(-px.x, px.y) * 1.6).rgb * 0.1;
	float edge = distance(UV, vec2(0.5));
	float shade = 1.0 - smoothstep(0.25, 0.78, edge) * vignette;
	vec3 dimmed = mix(sum, tint.rgb, clamp(tint.a, 0.0, 1.0));
	COLOR = vec4(dimmed * shade, fade);
}
"""

static var _glow_texture: GradientTexture2D
static var _spark_texture: GradientTexture2D
static var _grain_texture: NoiseTexture2D
static var _shine_shader: Shader
static var _backdrop_shader: Shader


# ---------------------------------------------------------------- shared resources

static func glow_texture() -> GradientTexture2D:
	if _glow_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.35, Color(1, 1, 1, 0.55))
		_glow_texture = GradientTexture2D.new()
		_glow_texture.gradient = gradient
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(0.5, 0.5)
		_glow_texture.fill_to = Vector2(0.5, 0.0)
		_glow_texture.width = 128
		_glow_texture.height = 128
	return _glow_texture


static func spark_texture() -> GradientTexture2D:
	if _spark_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.25, Color(1, 1, 1, 0.85))
		_spark_texture = GradientTexture2D.new()
		_spark_texture.gradient = gradient
		_spark_texture.fill = GradientTexture2D.FILL_RADIAL
		_spark_texture.fill_from = Vector2(0.5, 0.5)
		_spark_texture.fill_to = Vector2(0.5, 0.0)
		_spark_texture.width = 16
		_spark_texture.height = 16
	return _spark_texture


static func grain_texture() -> NoiseTexture2D:
	if _grain_texture == null:
		var noise := FastNoiseLite.new()
		noise.seed = 41
		noise.frequency = 0.09
		noise.fractal_octaves = 3
		_grain_texture = NoiseTexture2D.new()
		_grain_texture.noise = noise
		_grain_texture.width = 128
		_grain_texture.height = 128
		_grain_texture.seamless = true
	return _grain_texture


static func shine_material(label_size: Vector2, period := 5.0) -> ShaderMaterial:
	if _shine_shader == null:
		_shine_shader = Shader.new()
		_shine_shader.code = SHINE_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = _shine_shader
	material.set_shader_parameter("size", label_size)
	material.set_shader_parameter("period", period)
	return material


static func backdrop_material() -> ShaderMaterial:
	if _backdrop_shader == null:
		_backdrop_shader = Shader.new()
		_backdrop_shader.code = BACKDROP_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = _backdrop_shader
	return material


# ---------------------------------------------------------------- drawing primitives

static func notched_rect(rect: Rect2, notch: float) -> PackedVector2Array:
	var n := clampf(notch, 0.0, minf(rect.size.x, rect.size.y) * 0.45)
	var p := rect.position
	var e := rect.end
	return PackedVector2Array([
		Vector2(p.x + n, p.y), Vector2(e.x - n, p.y), Vector2(e.x, p.y + n), Vector2(e.x, e.y - n),
		Vector2(e.x - n, e.y), Vector2(p.x + n, e.y), Vector2(p.x, e.y - n), Vector2(p.x, p.y + n),
	])


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not points.is_empty():
		result.append(points[0])
	return result


static func draw_soft_shadow(item: CanvasItem, rect: Rect2, radius: float, strength := 0.6, spread := 14, offset := Vector2(0, 8)) -> void:
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, strength * 0.7)
	shadow.set_corner_radius_all(roundi(radius))
	shadow.shadow_color = Color(0, 0, 0, strength)
	shadow.shadow_size = spread
	shadow.anti_aliasing = true
	shadow.draw(item.get_canvas_item(), Rect2(rect.position + offset, rect.size))


static func draw_glow_rim(item: CanvasItem, rect: Rect2, radius: float, color: Color, spread := 14) -> void:
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(color, color.a * 0.35)
	glow.set_corner_radius_all(roundi(radius))
	glow.shadow_color = color
	glow.shadow_size = spread
	glow.draw(item.get_canvas_item(), rect)


static func draw_wood(item: CanvasItem, rect: Rect2, notch: float, seed_value: int, tone := WOOD_BASE, vertical_grain := false) -> void:
	var polygon := notched_rect(rect, notch)
	var colors := PackedColorArray()
	for point in polygon:
		var t := (point.y - rect.position.y) / maxf(1.0, rect.size.y)
		colors.append(tone.lightened(0.14).lerp(tone.darkened(0.34), t))
	item.draw_polygon(polygon, colors)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var along := rect.size.y if vertical_grain else rect.size.x
	var across := rect.size.x if vertical_grain else rect.size.y
	var line_count := maxi(3, int(across / 4.0))
	var n := clampf(notch, 0.0, minf(rect.size.x, rect.size.y) * 0.45)
	for index in range(line_count):
		var offset := (float(index) + rng.randf_range(0.15, 0.85)) * across / float(line_count)
		# Keep grain inside the notched silhouette.
		var edge_distance := minf(offset, across - offset)
		var shrink := maxf(0.0, n - edge_distance) + 2.0
		var start := shrink
		var finish := along - shrink
		if finish - start < 6.0:
			continue
		var amplitude := rng.randf_range(0.3, 1.5)
		var frequency := rng.randf_range(0.012, 0.034)
		var phase := rng.randf() * TAU
		var steps := maxi(4, int((finish - start) / 12.0))
		var points := PackedVector2Array()
		for step in range(steps + 1):
			var a := lerpf(start, finish, float(step) / float(steps))
			var b := offset + sin(a * frequency + phase) * amplitude
			points.append(rect.position + (Vector2(b, a) if vertical_grain else Vector2(a, b)))
		var dark := rng.randf() < 0.72
		var color := Color(0.07, 0.03, 0.012, rng.randf_range(0.16, 0.38)) if dark else Color(1.0, 0.78, 0.5, rng.randf_range(0.04, 0.11))
		item.draw_polyline(points, color, rng.randf_range(0.7, 1.5), true)
	if along > 110.0 and across > 26.0:
		var knot := rect.position + (Vector2(rng.randf_range(0.3, 0.7) * across, rng.randf_range(0.2, 0.8) * along) if vertical_grain else Vector2(rng.randf_range(0.2, 0.8) * along, rng.randf_range(0.3, 0.7) * across))
		_draw_ellipse(item, knot, Vector2(7, 2.6) if not vertical_grain else Vector2(2.6, 7), Color(0.08, 0.03, 0.01, 0.35))
		_draw_ellipse(item, knot, Vector2(3, 1.1) if not vertical_grain else Vector2(1.1, 3), Color(0.04, 0.015, 0.005, 0.5))
	# Bevel: warm top lip, dark bottom lip and a burnt outline.
	item.draw_polyline(PackedVector2Array([polygon[7] + Vector2(1.5, 0), polygon[0] + Vector2(0, 1.5), polygon[1] + Vector2(0, 1.5), polygon[2] + Vector2(-1.5, 0)]), Color(1.0, 0.82, 0.55, 0.3), 1.5, true)
	item.draw_polyline(PackedVector2Array([polygon[3] + Vector2(-1.5, 0), polygon[4] + Vector2(0, -1.5), polygon[5] + Vector2(0, -1.5), polygon[6] + Vector2(1.5, 0)]), Color(0, 0, 0, 0.45), 2.0, true)
	item.draw_polyline(_closed(polygon), WOOD_EDGE, 2.0, true)


static func draw_groove(item: CanvasItem, rect: Rect2, inset: float, notch: float, color := Color(0, 0, 0, 0.5)) -> void:
	var inner := rect.grow(-inset)
	if inner.size.x <= 4.0 or inner.size.y <= 4.0:
		return
	var polygon := _closed(notched_rect(inner, maxf(0.0, notch - inset * 0.4)))
	item.draw_polyline(polygon, color, 1.5, true)
	var lip := PackedVector2Array()
	for point in polygon:
		lip.append(point + Vector2(0, 1.2))
	item.draw_polyline(lip, Color(1.0, 0.85, 0.6, 0.1), 1.0, true)


static func draw_inlay(item: CanvasItem, rect: Rect2, inset: float, notch: float, color: Color, width := 1.5) -> void:
	var inner := rect.grow(-inset)
	if inner.size.x <= 4.0 or inner.size.y <= 4.0:
		return
	var polygon := _closed(notched_rect(inner, maxf(0.0, notch - inset * 0.4)))
	var shadow := PackedVector2Array()
	for point in polygon:
		shadow.append(point + Vector2(0, 1))
	item.draw_polyline(shadow, Color(0, 0, 0, 0.55), width + 0.5, true)
	item.draw_polyline(polygon, color, width, true)


static func draw_nail(item: CanvasItem, center: Vector2, radius := 3.4) -> void:
	item.draw_circle(center + Vector2(0.7, 1.1), radius + 0.9, Color(0, 0, 0, 0.5))
	item.draw_circle(center, radius, BRASS_DARK)
	item.draw_circle(center - Vector2.ONE * radius * 0.16, radius * 0.78, BRASS)
	item.draw_circle(center - Vector2.ONE * radius * 0.34, radius * 0.32, BRASS_LIGHT)


static func draw_brass_corner(item: CanvasItem, corner: Vector2, direction: Vector2, length := 30.0, thickness := 7.0) -> void:
	# `direction` points from the corner into the panel (e.g. (1, 1) for the top-left corner).
	var dx := Vector2(direction.x, 0)
	var dy := Vector2(0, direction.y)
	var polygon := PackedVector2Array([
		corner, corner + dx * length, corner + dx * (length - 5.0) + dy * thickness,
		corner + dx * thickness + dy * thickness, corner + dx * thickness + dy * (length - 5.0), corner + dy * length,
	])
	var colors := PackedColorArray()
	for index in range(polygon.size()):
		colors.append(BRASS.lightened(0.18) if index in [0, 1, 5] else BRASS.darkened(0.25))
	item.draw_polyline(_closed(_offset_points(polygon, Vector2(1, 2))), Color(0, 0, 0, 0.5), 2.0, true)
	item.draw_polygon(polygon, colors)
	item.draw_polyline(_closed(polygon), BRASS_DARK, 1.0, true)
	draw_nail(item, corner + (dx + dy) * thickness * 0.55, 2.6)


static func draw_chain(item: CanvasItem, from_point: Vector2, to_point: Vector2, link := 7.0) -> void:
	var length := from_point.distance_to(to_point)
	if length < 2.0:
		return
	var direction := (to_point - from_point) / length
	var normal := Vector2(-direction.y, direction.x)
	var count := int(length / link)
	for index in range(count + 1):
		var center := from_point + direction * (float(index) + 0.5) * link
		if index % 2 == 0:
			var points := PackedVector2Array()
			for step in range(13):
				var angle := TAU * float(step) / 12.0
				points.append(center + direction * cos(angle) * link * 0.62 + normal * sin(angle) * link * 0.32)
			item.draw_polyline(points, Color(0, 0, 0, 0.55), 3.0, true)
			item.draw_polyline(points, BRASS.darkened(0.1), 1.6, true)
		else:
			item.draw_line(center - direction * link * 0.55, center + direction * link * 0.55, Color(0, 0, 0, 0.55), 3.0, true)
			item.draw_line(center - direction * link * 0.55, center + direction * link * 0.55, BRASS.lightened(0.15), 1.4, true)


static func draw_rope(item: CanvasItem, from_point: Vector2, to_point: Vector2) -> void:
	item.draw_line(from_point + Vector2(1.5, 0), to_point + Vector2(1.5, 0), Color(0, 0, 0, 0.45), 4.0, true)
	item.draw_line(from_point, to_point, ROPE.darkened(0.2), 3.2, true)
	var length := from_point.distance_to(to_point)
	var direction := (to_point - from_point) / maxf(1.0, length)
	var normal := Vector2(-direction.y, direction.x)
	var twist := 5.0
	var offset := 0.0
	while offset < length:
		var center := from_point + direction * offset
		item.draw_line(center - normal * 1.4, center + normal * 1.4 + direction * 2.5, ROPE.lightened(0.25), 1.0, true)
		offset += twist


static func draw_diamond(item: CanvasItem, center: Vector2, half_size: Vector2, color: Color, outline := Color(0, 0, 0, 0.6)) -> void:
	var points := PackedVector2Array([center + Vector2(0, -half_size.y), center + Vector2(half_size.x, 0), center + Vector2(0, half_size.y), center + Vector2(-half_size.x, 0)])
	item.draw_colored_polygon(points, color)
	item.draw_polyline(_closed(points), outline, 1.0, true)


## Faceted mana crystal: four shaded facets, a table highlight and an optional glow halo.
static func draw_gem(item: CanvasItem, center: Vector2, half_size: Vector2, color: Color, lit: bool) -> void:
	var top := center + Vector2(0, -half_size.y)
	var right := center + Vector2(half_size.x, 0)
	var bottom := center + Vector2(0, half_size.y)
	var left := center + Vector2(-half_size.x, 0)
	var core := center + Vector2(0, -half_size.y * 0.12)
	if lit:
		item.draw_texture_rect(glow_texture(), Rect2(center - half_size * 2.3, half_size * 4.6), false, Color(color, 0.42))
	var base := color if lit else Color(0.16, 0.2, 0.26, 0.92)
	item.draw_colored_polygon(PackedVector2Array([top, core, left]), base.lightened(0.45 if lit else 0.12))
	item.draw_colored_polygon(PackedVector2Array([top, right, core]), base.lightened(0.12 if lit else 0.04))
	item.draw_colored_polygon(PackedVector2Array([left, core, bottom]), base.darkened(0.12))
	item.draw_colored_polygon(PackedVector2Array([core, right, bottom]), base.darkened(0.42))
	item.draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color(0.02, 0.05, 0.1, 0.9), 1.2, true)
	if lit:
		item.draw_line(top + Vector2(-half_size.x * 0.2, half_size.y * 0.35), left + Vector2(half_size.x * 0.35, -half_size.y * 0.05), Color(1, 1, 1, 0.75), 1.0, true)
		item.draw_circle(top + Vector2(-half_size.x * 0.12, half_size.y * 0.42), maxf(0.8, half_size.x * 0.14), Color(1, 1, 1, 0.9))


static func star_points(center: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(10):
		var angle := -PI * 0.5 + PI * float(index) / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * (outer if index % 2 == 0 else inner))
	return points


static func _draw_ellipse(item: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for step in range(16):
		var angle := TAU * float(step) / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	item.draw_colored_polygon(points, color)


static func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point + offset)
	return result


static func seed_from(text: String) -> int:
	return absi(hash(text)) % 100000 + 1


## Carved wood frame with mitred vertical side planks, brass corner brackets and a dark slate face.
static func draw_board(item: CanvasItem, outer: Rect2, frame: float, accent: Color, seed_value: int, lit := false) -> void:
	var inner := outer.grow(-frame)
	draw_wood(item, outer, 10.0, seed_value, WOOD_BASE.lightened(0.08) if lit else WOOD_BASE, false)
	for side: float in [0.0, 1.0]:
		var x := outer.position.x if side == 0.0 else outer.end.x - frame
		var side_rect := Rect2(x, outer.position.y + frame, frame, outer.size.y - frame * 2.0)
		draw_wood(item, side_rect, 0.0, seed_value + 11 + int(side), WOOD_BASE.darkened(0.06), true)
	for corner: Array in [[outer.position, inner.position], [Vector2(outer.end.x, outer.position.y), Vector2(inner.end.x, inner.position.y)], [Vector2(outer.position.x, outer.end.y), Vector2(inner.position.x, inner.end.y)], [outer.end, inner.end]]:
		item.draw_line(corner[0], corner[1], Color(0, 0, 0, 0.5), 1.5, true)
	item.draw_rect(inner.grow(2), WOOD_EDGE)
	item.draw_rect(inner, SLATE)
	item.draw_texture_rect(glow_texture(), Rect2(inner.position + inner.size * Vector2(-0.1, -0.25), inner.size * Vector2(1.2, 1.25)), false, Color(SLATE_LIGHT, 0.85))
	item.draw_texture_rect(grain_texture(), inner, true, Color(1, 0.9, 0.8, 0.045))
	for step in range(6):
		var alpha := 0.42 - float(step) * 0.07
		item.draw_rect(Rect2(inner.position + Vector2(step, step), inner.size - Vector2(step, step) * 2.0), Color(0, 0, 0, alpha), false, 1.0)
	var rule := inner.grow(-9)
	if rule.size.x > 20.0 and rule.size.y > 20.0:
		item.draw_rect(rule, Color(accent, 0.32 if not lit else 0.6), false, 1.0)
		for point: Vector2 in [rule.position, Vector2(rule.end.x, rule.position.y), Vector2(rule.position.x, rule.end.y), rule.end]:
			draw_diamond(item, point, Vector2(3.5, 3.5), Color(accent, 0.8), Color(0, 0, 0, 0.4))
	var bracket := minf(38.0, minf(outer.size.x, outer.size.y) * 0.22)
	draw_brass_corner(item, outer.position + Vector2(2, 2), Vector2(1, 1), bracket)
	draw_brass_corner(item, Vector2(outer.end.x - 2, outer.position.y + 2), Vector2(-1, 1), bracket)
	draw_brass_corner(item, Vector2(outer.position.x + 2, outer.end.y - 2), Vector2(1, -1), bracket)
	draw_brass_corner(item, outer.end - Vector2(2, 2), Vector2(-1, -1), bracket)
	if outer.size.x > 260.0:
		draw_nail(item, Vector2(outer.get_center().x, outer.position.y + frame * 0.5), 3.0)
		draw_nail(item, Vector2(outer.get_center().x, outer.end.y - frame * 0.5), 3.0)
	if outer.size.y > 260.0:
		draw_nail(item, Vector2(outer.position.x + frame * 0.5, outer.get_center().y), 3.0)
		draw_nail(item, Vector2(outer.end.x - frame * 0.5, outer.get_center().y), 3.0)


# ---------------------------------------------------------------- particles

## Warm hearth embers / drifting motes; counts stay small for Web + the compatibility renderer.
static func make_embers(emission_rect: Rect2, amount: int, color := EMBER, lifetime := 4.0, speed := Vector2(18, 46), sprite_scale := Vector2(0.5, 1.2), rise := -8.0) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "HearthEmbers"
	particles.amount = maxi(1, amount)
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.position = emission_rect.get_center()
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = emission_rect.size * 0.5
	particles.direction = Vector2(0, -1)
	particles.spread = 24.0
	particles.gravity = Vector2(0, rise)
	particles.initial_velocity_min = speed.x
	particles.initial_velocity_max = speed.y
	particles.scale_amount_min = sprite_scale.x
	particles.scale_amount_max = sprite_scale.y
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.lightened(0.35), 0.0))
	ramp.set_color(1, Color(color.darkened(0.2), 0.0))
	ramp.add_point(0.15, Color(color.lightened(0.25), 0.95))
	ramp.add_point(0.7, Color(color, 0.5))
	particles.color_ramp = ramp
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 1.0))
	scale_curve.add_point(Vector2(1, 0.3))
	particles.scale_amount_curve = scale_curve
	particles.texture = spark_texture()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = additive
	return particles


# ---------------------------------------------------------------- controls

## Wooden plaque drawn behind its parent Button (show_behind_parent). Reads the button's draw mode and
## focus each frame so hover, focus, press and disabled states restyle the material, not just a fill.
class Plaque:
	extends Control
	const TAVERN := preload("res://scripts/tavern_ui.gd")
	@export var variant := "plate" # sign | plate | chip | row
	@export var accent := TAVERN.BRASS
	@export var seed_value := 1
	@export var chain_height := 0.0
	@export var notch := 8.0
	var _state := -1

	func _init() -> void:
		name = "TavernPlaque"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		set_process(true)

	func _process(_delta: float) -> void:
		var button := get_parent() as BaseButton
		if button == null:
			return
		var state := button.get_draw_mode()
		if button.has_focus():
			state += 16
		if bool(button.get_meta("juice_hovered", false)):
			state += 32
		if state != _state:
			_state = state
			queue_redraw()

	func _draw() -> void:
		var button := get_parent() as BaseButton
		var mode := button.get_draw_mode() if button != null else BaseButton.DRAW_NORMAL
		var disabled := mode == BaseButton.DRAW_DISABLED
		var pressed := mode in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]
		var hot := not disabled and (mode == BaseButton.DRAW_HOVER or pressed or (button != null and (button.has_focus() or bool(button.get_meta("juice_hovered", false)))))
		var rect := Rect2(Vector2.ZERO, size)
		if variant == "panel":
			TAVERN.draw_soft_shadow(self, rect, 10, 0.6, 16, Vector2(0, 8))
			if hot:
				TAVERN.draw_glow_rim(self, rect.grow(2), 10, Color(accent, 0.55), 18)
			TAVERN.draw_board(self, rect, 12.0, accent if not disabled else Color(0.4, 0.36, 0.32), seed_value, hot)
			return
		if variant == "sign" and chain_height > 0.0:
			for x_ratio: float in [0.16, 0.84]:
				var anchor := Vector2(size.x * x_ratio, 0)
				TAVERN.draw_chain(self, anchor + Vector2(0, -chain_height), anchor + Vector2(0, 6))
		var radius := notch
		TAVERN.draw_soft_shadow(self, rect, radius, 0.55 if variant != "row" else 0.35, 10 if variant == "sign" else 6, Vector2(0, 5 if variant == "sign" else 3))
		if hot:
			TAVERN.draw_glow_rim(self, rect.grow(1), radius, Color(TAVERN.EMBER if variant != "row" else accent, 0.5), 16 if variant == "sign" else 11)
		var tone := TAVERN.WOOD_BASE
		match variant:
			"sign":
				tone = TAVERN.WOOD_WARM
			"chip":
				tone = TAVERN.WOOD_DEEP.lightened(0.08)
			"row":
				tone = TAVERN.WOOD_DEEP.lightened(0.14)
		if hot:
			tone = tone.lightened(0.1)
		if pressed:
			tone = tone.darkened(0.12)
		if disabled:
			tone = tone.darkened(0.35).lerp(Color(0.2, 0.18, 0.17), 0.45)
		TAVERN.draw_wood(self, rect, notch, seed_value, tone, false)
		var trim := accent if not disabled else Color(0.42, 0.37, 0.33)
		match variant:
			"sign":
				TAVERN.draw_groove(self, rect, 5.0, notch)
				TAVERN.draw_inlay(self, rect, 9.0, notch, Color(TAVERN.BRASS.lightened(0.1) if not hot else TAVERN.GOLD, 0.95), 2.0)
				for corner: Vector2 in [Vector2(14, 13), Vector2(size.x - 14, 13), Vector2(14, size.y - 13), Vector2(size.x - 14, size.y - 13)]:
					TAVERN.draw_nail(self, corner, 3.6)
				for x_ratio: float in [0.16, 0.84]:
					TAVERN.draw_nail(self, Vector2(size.x * x_ratio, 5), 3.0)
			"plate":
				TAVERN.draw_groove(self, rect, 4.0, notch)
				TAVERN.draw_inlay(self, rect, 7.0, notch, Color(trim, 0.85 if hot else 0.62), 1.4)
				if size.x > 90.0:
					TAVERN.draw_nail(self, Vector2(11, size.y * 0.5), 3.0)
					TAVERN.draw_nail(self, Vector2(size.x - 11, size.y * 0.5), 3.0)
			"chip":
				TAVERN.draw_inlay(self, rect, 3.5, notch, Color(TAVERN.BRASS, 0.75 if hot else 0.45), 1.0)
			"row":
				TAVERN.draw_inlay(self, rect, 3.0, notch, Color(trim, 0.9 if hot else 0.45), 1.2)
				TAVERN.draw_nail(self, Vector2(9, size.y * 0.5), 2.4)


## A framed menu board: carved wood frame with brass corner brackets around a dark slate face,
## optionally hung from two ropes that run off the top edge of the screen.
class Board:
	extends Control
	const TAVERN := preload("res://scripts/tavern_ui.gd")
	@export var accent := TAVERN.BRASS
	@export var frame := 14.0
	@export var outset := 5.0
	@export var hanging := false
	@export var seed_value := 7

	func _init() -> void:
		name = "TavernBoard"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var outer := Rect2(Vector2.ZERO, size).grow(outset)
		if hanging:
			var top := -global_position.y / maxf(0.01, get_global_transform().get_scale().y) - 20.0
			for x_ratio: float in [0.2, 0.8]:
				var anchor := Vector2(size.x * x_ratio, outer.position.y + 4.0)
				TAVERN.draw_rope(self, Vector2(anchor.x + (x_ratio - 0.5) * 40.0, top), anchor)
		TAVERN.draw_soft_shadow(self, outer, 10, 0.7, 22, Vector2(0, 12))
		TAVERN.draw_board(self, outer, frame, accent, seed_value)
		if hanging:
			for x_ratio: float in [0.2, 0.8]:
				TAVERN.draw_nail(self, Vector2(size.x * x_ratio, outer.position.y + 5.0), 3.6)


## Rarity trim drawn over a card's dark body and beneath its art/text children: double frame line,
## art window with corner studs, a ribbon behind the name and a rarity jewel.
class CardTrim:
	extends Control
	const TAVERN := preload("res://scripts/tavern_ui.gd")
	@export var accent := TAVERN.BRASS
	@export var rarity := "common"
	@export var art_rect := Rect2()
	@export var name_rect := Rect2()
	@export var show_jewel := true

	func _init() -> void:
		name = "CardTrim"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var rich := rarity in ["legendary", "epic"]
		# Text box: warm dark parchment gradient.
		var text_box := Rect2(5, name_rect.end.y - 2, size.x - 10, size.y - name_rect.end.y - 3)
		if text_box.size.y > 4:
			draw_texture_rect(TAVERN.glow_texture(), Rect2(text_box.position - Vector2(10, 6), text_box.size + Vector2(20, 26)), false, Color(0.32, 0.2, 0.11, 0.55))
		# Art window.
		draw_rect(art_rect.grow(2), Color(0, 0, 0, 0.9))
		draw_texture_rect(TAVERN.glow_texture(), art_rect.grow(6), false, Color(accent.darkened(0.45), 0.7))
		draw_rect(art_rect.grow(2), Color(accent.darkened(0.15), 0.9), false, 1.5)
		for point: Vector2 in [art_rect.position - Vector2(2, 2), Vector2(art_rect.end.x + 2, art_rect.position.y - 2), Vector2(art_rect.position.x - 2, art_rect.end.y + 2), art_rect.end + Vector2(2, 2)]:
			TAVERN.draw_diamond(self, point, Vector2(3, 3), accent.lightened(0.2))
		# Double frame line.
		var frame_a := rect.grow(-3.5)
		var frame_b := rect.grow(-6.0)
		_rounded_outline(frame_a, 7.0, Color(accent.darkened(0.3), 0.95), 1.5)
		_rounded_outline(frame_b, 5.0, Color(accent, 0.45), 1.0)
		if rich:
			for corner: Vector2 in [Vector2(9, size.y - 9), Vector2(size.x - 9, size.y - 9)]:
				draw_arc(corner, 6.0, 0, TAU, 14, Color(accent, 0.85), 1.2, true)
				draw_circle(corner, 2.0, accent.lightened(0.3))
		# Name ribbon with swallow-tail ends.
		if name_rect.size.x > 10:
			var r := name_rect
			var tail := 7.0
			var ribbon := PackedVector2Array([
				Vector2(r.position.x, r.position.y + 2), Vector2(r.end.x, r.position.y + 2),
				Vector2(r.end.x - tail, r.get_center().y), Vector2(r.end.x, r.end.y - 2),
				Vector2(r.position.x, r.end.y - 2), Vector2(r.position.x + tail, r.get_center().y),
			])
			var colors := PackedColorArray()
			for point in ribbon:
				var t := (point.y - r.position.y) / maxf(1.0, r.size.y)
				colors.append(Color("#3A2214").lerp(Color("#1A0D08"), t))
			draw_polygon(ribbon, colors)
			draw_polyline(PackedVector2Array([ribbon[0], ribbon[1]]), Color(accent, 0.8), 1.0, true)
			draw_polyline(PackedVector2Array([ribbon[4], ribbon[3]]), Color(accent, 0.55), 1.0, true)
		# Rarity jewel under the art.
		if show_jewel:
			var jewel := Vector2(art_rect.get_center().x, art_rect.end.y + 1)
			TAVERN.draw_gem(self, jewel, Vector2(5, 6), accent, true)

	func _rounded_outline(rect: Rect2, radius: float, color: Color, width: float) -> void:
		var style := StyleBoxFlat.new()
		style.draw_center = false
		style.border_color = color
		style.set_border_width_all(maxi(1, roundi(width)))
		style.set_corner_radius_all(roundi(radius))
		style.anti_aliasing = true
		style.draw(get_canvas_item(), rect)


## Faceted mana gem used for the Mana pip rails.
class Gem:
	extends Control
	const TAVERN := preload("res://scripts/tavern_ui.gd")
	@export var color := Color("#4AD9FF")
	@export var lit := true

	func _init() -> void:
		name = "ManaGem"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		TAVERN.draw_gem(self, size * 0.5, Vector2(size.x * 0.52, size.y * 0.7), color, lit)


## Brass chevrons that flank the selected menu item and glide between items (the title menu's focus cursor).
class SelectionBrackets:
	extends Control
	const TAVERN := preload("res://scripts/tavern_ui.gd")
	var target: Control
	var reduce_motion := false
	var _time := 0.0

	func _init() -> void:
		name = "SelectionBrackets"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 20

	func snap_to(control: Control) -> void:
		target = control
		if control != null:
			var rect := _target_rect(control)
			position = rect.position
			size = rect.size

	func _target_rect(control: Control) -> Rect2:
		var local: Transform2D = (get_parent() as CanvasItem).get_global_transform().affine_inverse() * control.get_global_transform()
		return Rect2(local.origin, control.size * local.get_scale()).grow_individual(26, 4, 26, 4)

	func _process(delta: float) -> void:
		_time += delta
		if target == null or not is_instance_valid(target):
			return
		var rect := _target_rect(target)
		var weight := 1.0 if reduce_motion else clampf(delta * 14.0, 0.0, 1.0)
		position = position.lerp(rect.position, weight)
		size = size.lerp(rect.size, weight)
		modulate.a = target.modulate.a
		queue_redraw()

	func _draw() -> void:
		var bob := 0.0 if reduce_motion else sin(_time * 4.2) * 3.0
		var mid := size.y * 0.5
		for side: float in [-1.0, 1.0]:
			# Left chevron points right at the item, right chevron points left.
			var tip_x := (12.0 - bob) if side < 0.0 else (size.x - 12.0 + bob)
			var back_x := tip_x - 14.0 if side < 0.0 else tip_x + 14.0
			var notch_x := tip_x - 9.0 if side < 0.0 else tip_x + 9.0
			var chevron := PackedVector2Array([Vector2(back_x, mid - 11), Vector2(tip_x, mid), Vector2(back_x, mid + 11), Vector2(notch_x, mid)])
			draw_texture_rect(TAVERN.glow_texture(), Rect2(Vector2(tip_x - 20, mid - 20), Vector2(40, 40)), false, Color(TAVERN.EMBER, 0.45))
			draw_colored_polygon(_offset(chevron, Vector2(1, 2)), Color(0, 0, 0, 0.55))
			draw_colored_polygon(chevron, TAVERN.GOLD)
			draw_polyline(PackedVector2Array([chevron[0], chevron[1], chevron[2]]), TAVERN.BRASS_LIGHT, 1.2, true)
			draw_polyline(PackedVector2Array([chevron[0], chevron[1], chevron[2], chevron[3], chevron[0]]), TAVERN.BRASS_DARK, 1.0, true)

	func _offset(points: PackedVector2Array, delta: Vector2) -> PackedVector2Array:
		var result := PackedVector2Array()
		for point in points:
			result.append(point + delta)
		return result


## A soft candle/hearth light that flickers with layered sine noise (static when motion is reduced).
class CandleGlow:
	extends Control
	const TAVERN := preload("res://scripts/tavern_ui.gd")
	@export var color := Color("#FFB04A")
	@export var intensity := 0.5
	@export var animate := true
	var _time := 0.0
	var _phase := 0.0

	func _init() -> void:
		name = "CandleGlow"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_phase = float(absi(hash(name + str(position))) % 1000) * 0.01
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive
		set_process(animate)

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var flicker := 1.0
		if animate:
			flicker = 0.84 + 0.1 * sin(_time * 7.3 + _phase) + 0.06 * sin(_time * 17.1 + _phase * 2.0)
		var grow := size * (flicker - 1.0) * 0.25
		draw_texture_rect(TAVERN.glow_texture(), Rect2(-grow, size + grow * 2.0), false, Color(color, intensity * flicker))


## Rotates its parent like a sign hanging from a rod: a decaying drop swing followed by a gentle idle sway.
class SwayDriver:
	extends Node
	var amplitude := 0.02
	var initial_swing := 0.0
	var speed := 1.3
	var _time := 0.0

	func _ready() -> void:
		name = "SwayDriver"

	func _process(delta: float) -> void:
		_time += delta
		var parent := get_parent() as Control
		if parent == null:
			return
		var decay := initial_swing * exp(-_time * 2.2)
		parent.rotation = sin(_time * speed * TAU * 0.5) * amplitude + sin(_time * 5.4) * decay


## Five-point stars for the run ledger (earned stars pop in, missing stars stay as dark engravings).
class StarRow:
	extends Control
	const TAVERN := preload("res://scripts/tavern_ui.gd")
	@export var earned := 0
	@export var total := 3
	@export var reveal := 1.0

	func _init() -> void:
		name = "RunStars"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_reveal(value: float) -> void:
		reveal = value
		queue_redraw()

	func _draw() -> void:
		var spacing := size.x / float(maxi(1, total))
		for index in range(total):
			var center := Vector2(spacing * (float(index) + 0.5), size.y * 0.5 + (0.0 if index != 1 else -3.0))
			var outer := minf(size.y * 0.46, spacing * 0.42) * (1.12 if index == 1 else 1.0)
			var slot := TAVERN.star_points(center, outer, outer * 0.46)
			draw_colored_polygon(TAVERN._offset_points(slot, Vector2(1, 3)), Color(0, 0, 0, 0.5))
			draw_colored_polygon(slot, Color(0.12, 0.08, 0.07, 0.95))
			draw_polyline(TAVERN._closed(slot), Color(TAVERN.BRASS_DARK, 0.9), 1.2, true)
			if index >= earned:
				continue
			var local := clampf(reveal * float(total) - float(index), 0.0, 1.0)
			if local <= 0.0:
				continue
			var pop := 1.0 + sin(local * PI) * 0.35
			var star := TAVERN.star_points(center, outer * local * pop * 0.92, outer * 0.44 * local * pop * 0.92)
			draw_texture_rect(TAVERN.glow_texture(), Rect2(center - Vector2.ONE * outer * 1.6, Vector2.ONE * outer * 3.2), false, Color(TAVERN.GOLD, 0.35 * local))
			var colors := PackedColorArray()
			for point_index in range(star.size()):
				colors.append(TAVERN.GOLD.lightened(0.35) if star[point_index].y < center.y else TAVERN.EMBER.darkened(0.05))
			draw_polygon(star, colors)
			draw_polyline(TAVERN._closed(star), TAVERN.BRASS_DARK, 1.2, true)


## Keyboard prompt key cap ("Enter", arrow pair) drawn as a small brass-rimmed key.
class KeyCap:
	extends Control
	const TAVERN := preload("res://scripts/tavern_ui.gd")
	@export var legend := ""
	@export var arrows := false
	@export var font: Font
	@export var font_size := 11

	func _init() -> void:
		name = "KeyCap"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var face := StyleBoxFlat.new()
		face.bg_color = Color("#2A1A12")
		face.border_color = Color(TAVERN.BRASS, 0.8)
		face.set_border_width_all(1)
		face.border_width_bottom = 3
		face.set_corner_radius_all(4)
		face.anti_aliasing = true
		face.draw(get_canvas_item(), rect)
		var color := Color(TAVERN.CREAM, 0.92)
		if arrows:
			var c := Vector2(size.x * 0.5, size.y * 0.5 - 1)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 3), c + Vector2(-5, -4), c + Vector2(-1, 3)]), color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(1, -3), c + Vector2(9, -3), c + Vector2(5, 4)]), color)
		elif font != null:
			var text_size := font.get_string_size(legend, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var baseline := (size.y - 2.0 - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
			draw_string(font, Vector2((size.x - text_size.x) * 0.5, baseline), legend, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Brass toggle switch for ON/OFF settings: dark track, sliding knob, lit gem when enabled.
class ToggleSwitch:
	extends Control
	const TAVERN := preload("res://scripts/tavern_ui.gd")
	@export var on := false
	@export var lit_color := Color("#55C6A9")

	func _init() -> void:
		name = "ToggleSwitch"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var radius := size.y * 0.5
		var track := StyleBoxFlat.new()
		track.bg_color = Color(lit_color.darkened(0.55), 0.95) if on else Color("#140C10")
		track.border_color = Color(TAVERN.BRASS, 0.85)
		track.set_border_width_all(1)
		track.set_corner_radius_all(roundi(radius))
		track.anti_aliasing = true
		track.draw(get_canvas_item(), rect)
		draw_rect(Rect2(radius * 0.6, 2, size.x - radius * 1.2, 2), Color(0, 0, 0, 0.35))
		var knob := Vector2(size.x - radius, radius) if on else Vector2(radius, radius)
		if on:
			TAVERN.draw_gem(self, Vector2(radius + 3, radius), Vector2(4, 5), lit_color, true)
		draw_circle(knob + Vector2(0.5, 1.5), radius - 1.5, Color(0, 0, 0, 0.5))
		draw_circle(knob, radius - 2.0, TAVERN.BRASS_DARK)
		draw_circle(knob - Vector2(0.6, 0.6), radius - 3.2, TAVERN.BRASS)
		draw_circle(knob - Vector2(radius * 0.25, radius * 0.25), radius * 0.28, TAVERN.BRASS_LIGHT)


## Chains for a hanging sign, kept as a separate node so they can sit behind the logo while the sign
## itself stays in front; copies the sign's transform every frame (drop, sway and hover lift).
class SignChains:
	extends Control
	const TAVERN := preload("res://scripts/tavern_ui.gd")
	var target: Control
	var chain_height := 150.0

	func _init() -> void:
		name = "SignChains"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if target == null or not is_instance_valid(target):
			return
		position = target.position
		size = target.size
		pivot_offset = target.pivot_offset
		rotation = target.rotation
		scale = target.scale
		modulate = target.modulate

	func _draw() -> void:
		for x_ratio: float in [0.16, 0.84]:
			var anchor := Vector2(size.x * x_ratio, 0)
			TAVERN.draw_chain(self, anchor + Vector2(0, -chain_height), anchor + Vector2(0, 6))
