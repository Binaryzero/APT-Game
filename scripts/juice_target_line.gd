class_name EmberpanTargetLine
extends Control

const TARGETING_Z_INDEX := 1024

var start_point := Vector2.ZERO
var end_point := Vector2.ZERO
var line_color := Color("#F3A33C")
var follows_mouse := true
var active := false


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_as_relative = false
    z_index = TARGETING_Z_INDEX
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    set_process(true)


func configure(from: Vector2, color: Color) -> void:
    start_point = from
    line_color = color
    active = true
    visible = true
    queue_redraw()


func dismiss() -> void:
    active = false
    visible = false
    queue_redraw()


func _process(_delta: float) -> void:
    if not active:
        return
    if follows_mouse:
        end_point = get_local_mouse_position()
    queue_redraw()


func _draw() -> void:
    if not active:
        return
    var distance := start_point.distance_to(end_point)
    if distance < 12.0:
        return
    var bend := clampf(distance * 0.22, 34.0, 110.0)
    var control := (start_point + end_point) * 0.5 + Vector2(0, -bend)
    var points := PackedVector2Array()
    for index in range(25):
        var t := float(index) / 24.0
        var inverse := 1.0 - t
        points.append(inverse * inverse * start_point + 2.0 * inverse * t * control + t * t * end_point)
    var pulse := 0.76 + sin(Time.get_ticks_msec() * 0.009) * 0.16
    var shadow := Color(0.04, 0.02, 0.06, 0.65)
    draw_polyline(points, shadow, 8.0, true)
    draw_polyline(points, Color(line_color, pulse), 3.5, true)
    var tangent := (end_point - control).normalized()
    var perpendicular := Vector2(-tangent.y, tangent.x)
    var arrow := PackedVector2Array([
        end_point,
        end_point - tangent * 22.0 + perpendicular * 9.0,
        end_point - tangent * 22.0 - perpendicular * 9.0,
    ])
    draw_colored_polygon(arrow, Color(line_color, 1.0))
