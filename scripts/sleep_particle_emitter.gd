class_name EmberpanSleepParticleEmitter
extends Control

const L10N := preload("res://scripts/localization.gd")

const CARD_SIZE := Vector2(158.0, 142.0)
const PARTICLE_LIFETIME := 1.62
const SPAWN_INTERVAL := 0.27
const SLEEP_COLOR := Color("#E3DDFF")
const OUTLINE_COLOR := Color("#171020")

var animated := true
var elapsed := 0.0
var particle_serial := 0


func configure(animate_particles: bool) -> void:
    animated = animate_particles
    name = "SleepParticles"
    size = CARD_SIZE
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_index = 20


func _ready() -> void:
    if animated:
        for index in range(6):
            _spawn_particle(float(index) / 6.0)
        set_process(true)
    else:
        _add_static_trail()
        set_process(false)


func _process(delta: float) -> void:
    elapsed += delta
    if elapsed < SPAWN_INTERVAL:
        return
    elapsed = fmod(elapsed, SPAWN_INTERVAL)
    _spawn_particle()


func _spawn_particle(progress := 0.0) -> void:
    var particle := _make_z(particle_serial)
    particle_serial += 1
    add_child(particle)

    var origin := CARD_SIZE * Vector2(0.50, 0.47)
    var travel := _travel_for(particle_serial)
    particle.position = origin.lerp(origin + travel, progress) - particle.size * 0.5
    particle.scale = Vector2.ONE * lerpf(0.72, 1.18, progress)
    particle.modulate.a = clampf(1.0 - progress * 0.72, 0.0, 1.0)

    var remaining := 1.0 - progress
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(particle, "position", origin + travel - particle.size * 0.5, PARTICLE_LIFETIME * remaining)
    tween.tween_property(particle, "scale", Vector2.ONE * 1.18, PARTICLE_LIFETIME * remaining)
    tween.tween_property(particle, "modulate:a", 0.0, PARTICLE_LIFETIME * remaining)
    tween.finished.connect(particle.queue_free)


func _add_static_trail() -> void:
    var origin := CARD_SIZE * Vector2(0.50, 0.47)
    for index in range(4):
        var particle := _make_z(index)
        var progress := 0.14 + float(index) * 0.20
        particle.position = origin.lerp(origin + _travel_for(index), progress) - particle.size * 0.5
        particle.scale = Vector2.ONE * lerpf(0.72, 1.12, progress)
        particle.modulate.a = lerpf(0.95, 0.45, progress)
        add_child(particle)


func _make_z(index: int) -> Label:
    var particle := Label.new()
    particle.name = "SleepZ%d" % index
    particle.text = L10N.t("battle.sleep_particle")
    L10N.apply_font(particle)
    particle.size = Vector2(24.0, 26.0)
    particle.pivot_offset = particle.size * 0.5
    particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    particle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    particle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    particle.add_theme_font_size_override("font_size", 14 + index % 3 * 2)
    particle.add_theme_color_override("font_color", SLEEP_COLOR)
    particle.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
    particle.add_theme_constant_override("outline_size", 3)
    return particle


func _travel_for(index: int) -> Vector2:
    return Vector2(25.0 + float(index % 3) * 7.0, -54.0 - float(index % 2) * 10.0)
