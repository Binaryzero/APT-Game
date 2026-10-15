class_name EmberpanTutorialCallout
extends Control

signal next_requested
signal skip_requested

const INK := Color("#100A18")
const PLUM := Color("#24122E")
const COPPER := Color("#C36D32")
const EMBER := Color("#F3A33C")
const GOLD := Color("#FFD36A")
const CREAM := Color("#F7E9C8")
const TEAL := Color("#55C6A9")
const MUTED := Color("#BBAF9A")
const MODAL_MASK := Color("#000000")
const L10N := preload("res://scripts/localization.gd")

var guide_texture: Texture2D
var pointer_texture: Texture2D
var clear_spotlight_rect := Rect2()
var safe_bounds := Rect2()


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    process_mode = Node.PROCESS_MODE_ALWAYS
    z_index = 4090
    visible = false


func setup(guide: Texture2D, pointer: Texture2D) -> void:
    guide_texture = guide
    pointer_texture = pointer


func configure_safe_bounds(bounds: Rect2) -> void:
    safe_bounds = bounds


func dismiss() -> void:
    _clear()
    clear_spotlight_rect = Rect2()
    visible = false


func present(step: Dictionary, focus_rect: Rect2, font_scale := 1.0, spotlight_rect := Rect2()) -> void:
    dismiss()
    visible = true
    var viewport_size := size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        viewport_size = get_viewport_rect().size
    var viewport_bounds := Rect2(Vector2.ZERO, viewport_size)
    var bounds := safe_bounds.intersection(viewport_bounds) if safe_bounds.has_area() else viewport_bounds
    var focus := focus_rect.grow(9.0).intersection(bounds)
    if focus.size.x < 4.0 or focus.size.y < 4.0:
        focus = Rect2(bounds.get_center() - Vector2(110, 55), Vector2(220, 110))
    var spotlight_source := spotlight_rect.merge(focus_rect) if spotlight_rect.has_area() else focus_rect
    clear_spotlight_rect = spotlight_source.grow(9.0).intersection(bounds)
    if clear_spotlight_rect.size.x < 4.0 or clear_spotlight_rect.size.y < 4.0:
        clear_spotlight_rect = focus

    _add_dimmer(Rect2(0, 0, viewport_size.x, clear_spotlight_rect.position.y))
    _add_dimmer(Rect2(0, clear_spotlight_rect.end.y, viewport_size.x, viewport_size.y - clear_spotlight_rect.end.y))
    _add_dimmer(Rect2(0, clear_spotlight_rect.position.y, clear_spotlight_rect.position.x, clear_spotlight_rect.size.y))
    _add_dimmer(Rect2(clear_spotlight_rect.end.x, clear_spotlight_rect.position.y, viewport_size.x - clear_spotlight_rect.end.x, clear_spotlight_rect.size.y))

    if not bool(step.get("action_gated", false)):
        var focus_blocker := Control.new()
        focus_blocker.position = focus.position
        focus_blocker.size = focus.size
        focus_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
        add_child(focus_blocker)

    var focus_ring := Panel.new()
    focus_ring.name = "TutorialFocusRing"
    focus_ring.position = focus.position
    focus_ring.size = focus.size
    focus_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    focus_ring.add_theme_stylebox_override("panel", _focus_ring_style())
    add_child(focus_ring)

    var placement := String(step.get("placement", "auto"))
    var callout_size := Vector2(500, 184) if placement == "side" else Vector2(620, 184)
    var callout_y := 18.0
    var callout_x := clampf(focus.get_center().x - callout_size.x * 0.5, bounds.position.x + 18.0, bounds.end.x - callout_size.x - 18.0)
    if placement == "side":
        var left_space := clear_spotlight_rect.position.x - bounds.position.x - 30.0
        var right_space := bounds.end.x - clear_spotlight_rect.end.x - 30.0
        callout_x = bounds.position.x + 18.0 if left_space >= right_space else bounds.end.x - callout_size.x - 18.0
        callout_y = clampf(clear_spotlight_rect.get_center().y - callout_size.y * 0.5, bounds.position.y + 18.0, bounds.end.y - callout_size.y - 18.0)
    elif placement == "bottom" or (placement == "auto" and focus.get_center().y < viewport_size.y * 0.5):
        callout_y = bounds.end.y - callout_size.y - 18.0
    else:
        callout_y = bounds.position.y + 18.0

    var pointer := _texture(pointer_texture)
    pointer.name = "TutorialPointer"
    pointer.size = Vector2(112, 57)
    var pointer_on_left := focus.position.x >= 142.0
    if placement == "side":
        pointer_on_left = callout_x > focus.get_center().x
    if pointer_on_left:
        pointer.position = Vector2(focus.position.x - pointer.size.x - 10.0, focus.get_center().y - pointer.size.y * 0.5)
    else:
        pointer.position = Vector2(focus.end.x + 10.0, focus.get_center().y - pointer.size.y * 0.5)
        pointer.flip_h = true
    pointer.position.x = clampf(pointer.position.x, bounds.position.x + 8.0, bounds.end.x - pointer.size.x - 8.0)
    pointer.position.y = clampf(pointer.position.y, bounds.position.y + 8.0, bounds.end.y - pointer.size.y - 8.0)
    add_child(pointer)

    var callout := Panel.new()
    callout.name = "TutorialPanel"
    callout.position = Vector2(callout_x, callout_y)
    callout.size = callout_size
    callout.mouse_filter = Control.MOUSE_FILTER_STOP
    callout.add_theme_stylebox_override("panel", _style(Color(0.141, 0.071, 0.180, 0.97), COPPER, 3, 18))
    add_child(callout)

    var guide := _texture(guide_texture)
    guide.position = Vector2(12, 18)
    guide.size = Vector2(112, 112)
    callout.add_child(guide)

    var nameplate := _label(L10N.t("tutorial.guide_name"), 11, EMBER, HORIZONTAL_ALIGNMENT_LEFT, font_scale)
    nameplate.add_theme_font_override("font", L10N.BUTTON_FONT_RESOURCE)
    nameplate.position = Vector2(135, 10)
    nameplate.size = Vector2(callout_size.x - 154, 18)
    callout.add_child(nameplate)

    var title := _label(L10N.t(String(step.get("title_key", "tutorial.lesson"))), 21, CREAM, HORIZONTAL_ALIGNMENT_LEFT, font_scale)
    title.add_theme_font_override("font", L10N.HEADING_FONT_RESOURCE)
    title.position = Vector2(135, 27)
    title.size = Vector2(callout_size.x - 154, 32)
    callout.add_child(title)

    var body := _label(L10N.t(String(step.get("body_key", "tutorial.empty"))), 14, CREAM, HORIZONTAL_ALIGNMENT_LEFT, font_scale)
    body.position = Vector2(135, 57)
    body.size = Vector2(callout_size.x - 154, 55)
    callout.add_child(body)

    var progress := _label(L10N.t(String(step.get("progress_key", "tutorial.empty"))), 10, MUTED, HORIZONTAL_ALIGNMENT_LEFT, font_scale)
    progress.position = Vector2(135, 112)
    progress.size = Vector2(170, 18)
    callout.add_child(progress)

    var skip := _button(L10N.t("tutorial.skip"), func(): skip_requested.emit(), COPPER, font_scale)
    skip.position = Vector2(12, 140)
    skip.size = Vector2(210, 32)
    callout.add_child(skip)

    if bool(step.get("action_gated", false)):
        var action_hint := _label(L10N.t(String(step.get("hint_key", "tutorial.action_hint"))), 11, TEAL, HORIZONTAL_ALIGNMENT_RIGHT, font_scale)
        action_hint.position = Vector2(236, 137)
        action_hint.size = Vector2(callout_size.x - 255, 34)
        callout.add_child(action_hint)
    else:
        var next_label := L10N.t(String(step.get("button_key", "tutorial.next")))
        var next := _button(next_label, func(): next_requested.emit(), TEAL, font_scale)
        next.position = Vector2(410, 135)
        next.size = Vector2(191, 40)
        callout.add_child(next)
        next.grab_focus()

func _clear() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()


func _add_dimmer(rect: Rect2) -> void:
    if rect.size.x <= 0.0 or rect.size.y <= 0.0:
        return
    var dimmer := ColorRect.new()
    dimmer.position = rect.position
    dimmer.size = rect.size
    dimmer.color = Color(MODAL_MASK, 0.76)
    dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dimmer)


func _texture(texture: Texture2D) -> TextureRect:
    var image := TextureRect.new()
    image.texture = texture
    image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    image.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return image


func _label(text: String, font_size: int, color: Color, alignment: HorizontalAlignment, font_scale: float) -> Label:
    var label := Label.new()
    label.text = text
    L10N.apply_font(label)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", maxi(8, roundi(font_size * font_scale)))
    label.add_theme_color_override("font_color", color)
    label.horizontal_alignment = alignment
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label


func _button(text: String, callback: Callable, accent: Color, font_scale: float) -> Button:
    var button := Button.new()
    button.text = text
    L10N.apply_font(button)
    button.add_theme_font_size_override("font_size", maxi(8, roundi(12 * font_scale)))
    button.add_theme_color_override("font_color", CREAM)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_stylebox_override("normal", _style(Color(0.063, 0.039, 0.094, 0.92), accent, 2, 9))
    button.add_theme_stylebox_override("hover", _style(Color(0.141, 0.071, 0.180, 0.98), GOLD, 3, 9))
    button.add_theme_stylebox_override("pressed", _style(Color(0.141, 0.071, 0.180, 0.98), TEAL, 3, 9))
    button.pressed.connect(callback)
    return button


func _focus_ring_style() -> StyleBoxFlat:
    var style := _style(Color.TRANSPARENT, TEAL, 4, 14)
    # A StyleBoxFlat shadow is a filled shape behind the panel. Even with a
    # transparent background it darkens the live control inside the spotlight.
    style.shadow_color = Color.TRANSPARENT
    style.shadow_size = 0
    style.shadow_offset = Vector2.ZERO
    return style


func _style(color: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = border
    style.set_border_width_all(width)
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    style.shadow_color = Color(0, 0, 0, 0.63)
    style.shadow_size = 8 if width >= 3 else 3
    style.content_margin_left = 8
    style.content_margin_right = 8
    style.content_margin_top = 5
    style.content_margin_bottom = 5
    return style
