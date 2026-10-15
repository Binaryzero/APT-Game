class_name EmberpanJuiceDirector
extends Control

const BrowserBgmPlayer = preload("res://scripts/manus/browser_bgm_player.gd")

signal sfx_played(kind: String)

const PROFILES := preload("res://scripts/card_battle_juice_profiles.gd")
const BGM_STREAM := preload("res://assets/template/cardgame/music/emberpan_midnight_service.wav")
const L10N := preload("res://scripts/localization.gd")
const CARD_CRACK_OVERLAY := preload("res://scripts/card_crack_overlay.gd")
const VOICEOVER_STREAMS := {
    "legendary_summon": preload("res://assets/template/cardgame/voiceovers/legendary_summon.wav"),
}
const SFX_KINDS := [
    "hover", "click", "invalid",
    "draw", "play",
    "summon", "hit", "heavy", "armor", "heal", "buff", "precise", "overkill",
    "turn", "cook", "boss", "victory", "defeat", "material",
    "blade", "fire", "broth", "meat", "fungus", "voice",
    "technique_attack", "technique_buff",
    "character_attack",
]
const SFX_STREAMS := {
    "hover": preload("res://assets/template/cardgame/sfx/hover.wav"),
    "click": preload("res://assets/template/cardgame/sfx/click.wav"),
    "invalid": preload("res://assets/template/cardgame/sfx/invalid.wav"),
    "draw": preload("res://assets/template/cardgame/sfx/draw.wav"),
    "play": preload("res://assets/template/cardgame/sfx/play.wav"),
    "summon": preload("res://assets/template/cardgame/sfx/summon.wav"),
    "hit": preload("res://assets/template/cardgame/sfx/hit.wav"),
    "heavy": preload("res://assets/template/cardgame/sfx/heavy.wav"),
    "armor": preload("res://assets/template/cardgame/sfx/armor.wav"),
    "heal": preload("res://assets/template/cardgame/sfx/heal.wav"),
    "buff": preload("res://assets/template/cardgame/sfx/buff.wav"),
    "precise": preload("res://assets/template/cardgame/sfx/precise.wav"),
    "overkill": preload("res://assets/template/cardgame/sfx/overkill.wav"),
    "turn": preload("res://assets/template/cardgame/sfx/turn.wav"),
    "cook": preload("res://assets/template/cardgame/sfx/cook.wav"),
    "boss": preload("res://assets/template/cardgame/sfx/boss.wav"),
    "victory": preload("res://assets/template/cardgame/sfx/victory.wav"),
    "defeat": preload("res://assets/template/cardgame/sfx/defeat.wav"),
    "material": preload("res://assets/template/cardgame/sfx/material.wav"),
    "blade": preload("res://assets/template/cardgame/sfx/blade.wav"),
    "fire": preload("res://assets/template/cardgame/sfx/fire.wav"),
    "broth": preload("res://assets/template/cardgame/sfx/broth.wav"),
    "meat": preload("res://assets/template/cardgame/sfx/meat.wav"),
    "fungus": preload("res://assets/template/cardgame/sfx/fungus.wav"),
    "voice": preload("res://assets/template/cardgame/sfx/voice.wav"),
    "technique_attack": preload("res://assets/template/cardgame/sfx/technique_attack.wav"),
    "technique_buff": preload("res://assets/template/cardgame/sfx/technique_buff.wav"),
    "character_attack": preload("res://assets/template/cardgame/sfx/character_attack.wav"),
}

const CREAM := Color("#F7E9C8")
const TEAL := Color("#55C6A9")
const EMBER := Color("#F3A33C")
const CRIMSON := Color("#D95757")
const COPPER := Color("#C36D32")

# Board combat needs enough time for anticipation, contact, and recovery to read.
const ATTACK_ANTICIPATION_SECONDS := 0.10
const ATTACK_LUNGE_SECONDS := 0.24
const ATTACK_RECOVERY_SECONDS := 0.28
const ATTACK_IMPACT_SECONDS := ATTACK_ANTICIPATION_SECONDS + ATTACK_LUNGE_SECONDS

var reduce_motion := false
var reduce_shake := false
var muted := false
var motion_mode := PROFILES.MOTION_FULL
var shake_intensity := 1.0
var flash_intensity := 1.0
var particle_density := 1.0
var animation_speed := 1.0
var auto_accelerate := true
var captions_enabled := true
var pitch_scale := 1.0
var ambient_enabled := true
var ambient_density_scale := 1.0
var ambient_speed_scale := 1.0
var particle_count_scale := 1.0
var particle_radius_scale := 1.0
var flash_strength_scale := 1.0
var shake_strength_scale := 1.0
var ambient_mode := ""
var ambient_elapsed := 0.0
var rng := RandomNumberGenerator.new()
var active_particles := 0
var active_overlays := 0
var active_audio := 0
var signature_depth := 0
var drop_zone_overlay: Control
var _cue_serial := 0
var music_player: BrowserBgmPlayer
var voiceover_player: AudioStreamPlayer
var _active_audio_players: Array[AudioStreamPlayer] = []


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    rng.randomize()
    _start_music()
    _setup_voiceover_player()


func _exit_tree() -> void:
    if is_instance_valid(music_player):
        music_player.stop()
        music_player.stream = null
    if is_instance_valid(voiceover_player):
        voiceover_player.stop()
        voiceover_player.stream = null
    for player in _active_audio_players.duplicate():
        if is_instance_valid(player):
            player.stop()
            player.stream = null
    _active_audio_players.clear()
    active_audio = 0


func _start_music() -> void:
    music_player = BrowserBgmPlayer.new()
    music_player.name = "EmberpanBGM"
    music_player.stream = BGM_STREAM
    music_player.bus = "Music"
    add_child(music_player)
    music_player.play()
    music_player.stream_paused = muted


func _setup_voiceover_player() -> void:
    voiceover_player = AudioStreamPlayer.new()
    voiceover_player.name = "LegendaryVoiceover"
    voiceover_player.bus = "Voice"
    voiceover_player.finished.connect(_on_voiceover_finished)
    add_child(voiceover_player)


func play_voiceover(kind: String, volume_db := 0.0) -> bool:
    if muted or not is_instance_valid(voiceover_player):
        return false
    var stream := VOICEOVER_STREAMS.get(kind) as AudioStream
    if stream == null:
        push_warning("Unknown authored voiceover cue: %s" % kind)
        return false
    stop_voiceover()
    voiceover_player.stream = stream
    voiceover_player.volume_db = volume_db
    if is_instance_valid(music_player):
        music_player.volume_db = -9.0
    voiceover_player.play()
    return true


func stop_voiceover() -> void:
    if is_instance_valid(voiceover_player):
        voiceover_player.stop()
    if is_instance_valid(music_player):
        music_player.volume_db = 0.0


func _on_voiceover_finished() -> void:
    if is_instance_valid(music_player):
        music_player.volume_db = 0.0


func set_audio_muted(value: bool) -> void:
    muted = value
    if muted:
        stop_voiceover()
    if is_instance_valid(music_player):
        music_player.stream_paused = muted


func set_accessibility(motion_reduced: bool, sound_muted: bool) -> void:
    reduce_motion = motion_reduced
    reduce_shake = motion_reduced
    motion_mode = PROFILES.MOTION_REDUCED if motion_reduced else PROFILES.MOTION_FULL
    set_audio_muted(sound_muted)


func configure_presentation(mode: String, shake_value: float, flash_value: float, density: float, speed: float, accelerate: bool, captions: bool) -> void:
    motion_mode = mode if mode in [PROFILES.MOTION_FULL, PROFILES.MOTION_REDUCED, PROFILES.MOTION_MINIMAL] else PROFILES.MOTION_FULL
    reduce_motion = motion_mode != PROFILES.MOTION_FULL
    reduce_shake = motion_mode == PROFILES.MOTION_MINIMAL or shake_value <= 0.0
    shake_intensity = clampf(shake_value, 0.0, 1.5)
    flash_intensity = clampf(flash_value, 0.0, 1.5)
    particle_density = clampf(density, 0.0, 2.0)
    animation_speed = clampf(speed, 0.5, 2.5)
    auto_accelerate = accelerate
    captions_enabled = captions


func begin_signature() -> void:
    signature_depth += 1


func end_signature() -> void:
    signature_depth = maxi(0, signature_depth - 1)


func _duration(seconds: float) -> float:
    return maxf(0.025, seconds * PROFILES.duration_scale(motion_mode, animation_speed))


func _release_particle(node: Node) -> void:
    active_particles = maxi(0, active_particles - 1)
    if is_instance_valid(node):
        node.queue_free()


func _release_overlay(node: Node) -> void:
    active_overlays = maxi(0, active_overlays - 1)
    if is_instance_valid(node):
        node.queue_free()


func set_ambient(mode: String) -> void:
    ambient_mode = mode
    ambient_elapsed = 0.0
    set_process(not mode.is_empty())


func _process(delta: float) -> void:
    if ambient_mode.is_empty() or reduce_motion or not ambient_enabled or signature_depth > 0:
        return
    ambient_elapsed += delta
    var interval := (0.45 if ambient_mode == "battle" else 0.31) / maxf(0.05, ambient_density_scale)
    if ambient_elapsed < interval:
        return
    ambient_elapsed = 0.0
    var spawn := Vector2(rng.randf_range(30.0, size.x - 30.0), size.y + 8.0)
    var color := EMBER if ambient_mode != "kitchen" else Color("#D9F7E9")
    _ambient_mote(spawn, color, ambient_mode == "kitchen")


func _ambient_mote(spawn: Vector2, color: Color, steam: bool) -> void:
    if active_particles >= int(PROFILES.LIMITS.particles):
        return
    var particle := Polygon2D.new()
    particle.polygon = _circle_points(7.0 if steam else 3.0, 8 if steam else 4)
    particle.color = Color(color, 0.14 if steam else 0.32)
    particle.position = spawn
    add_child(particle)
    active_particles += 1
    var travel := Vector2(rng.randf_range(-65.0, 65.0), rng.randf_range(-210.0, -120.0))
    var duration := rng.randf_range(2.2, 4.0) / maxf(0.05, ambient_speed_scale)
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(particle, "position", spawn + travel, duration)
    tween.tween_property(particle, "modulate:a", 0.0, duration)
    tween.tween_property(particle, "scale", Vector2(1.8, 1.8) if steam else Vector2(0.3, 0.3), duration)
    tween.chain().tween_callback(func(): _release_particle(particle))


func burst(position: Vector2, color: Color, count := 16, style := "spark", radius := 78.0) -> void:
    var profile_density := PROFILES.particle_scale(motion_mode, particle_density)
    var scaled_count := maxi(0, roundi(float(count) * particle_count_scale * profile_density))
    var actual_count := mini(scaled_count, 28 if reduce_motion else scaled_count)
    actual_count = mini(actual_count, maxi(0, int(PROFILES.LIMITS.particles) - active_particles))
    radius *= particle_radius_scale
    for index in range(actual_count):
        var particle := Polygon2D.new()
        var particle_size := rng.randf_range(2.5, 6.5)
        if style in ["steam", "spore"]:
            particle.polygon = _circle_points(particle_size * 1.7, 8)
        elif style == "ash":
            particle.polygon = PackedVector2Array([Vector2(-particle_size, -particle_size * 0.4), Vector2(particle_size, 0), Vector2(-particle_size * 0.5, particle_size * 0.6)])
        elif style == "flame":
            particle.polygon = PackedVector2Array([Vector2(0, -particle_size * 2.3), Vector2(particle_size, particle_size), Vector2(0, particle_size * 0.55), Vector2(-particle_size, particle_size)])
        elif style == "rivet":
            particle.polygon = _circle_points(particle_size, 7)
        elif style == "wedge":
            particle.polygon = PackedVector2Array([Vector2(-particle_size, -particle_size), Vector2(particle_size * 1.8, 0), Vector2(-particle_size, particle_size)])
        else:
            particle.polygon = PackedVector2Array([Vector2(0, -particle_size * 1.8), Vector2(particle_size * 0.55, 0), Vector2(0, particle_size * 1.8), Vector2(-particle_size * 0.55, 0)])
        particle.color = Color(color, rng.randf_range(0.65, 1.0))
        particle.position = position + Vector2(rng.randf_range(-7.0, 7.0), rng.randf_range(-7.0, 7.0))
        particle.rotation = rng.randf_range(-PI, PI)
        add_child(particle)
        active_particles += 1
        var angle := rng.randf_range(-PI, PI)
        if style in ["steam", "flame"]:
            angle = rng.randf_range(-2.25, -0.9)
        elif style == "ash":
            angle = rng.randf_range(0.65, 2.5)
        var travel_radius := rng.randf_range(radius * 0.45, radius)
        var destination := particle.position + Vector2.from_angle(angle) * travel_radius
        var duration := _duration(rng.randf_range(0.32, 0.68))
        var tween := create_tween().set_parallel(true)
        tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(particle, "position", destination, duration)
        tween.tween_property(particle, "rotation", particle.rotation + rng.randf_range(-3.5, 3.5), duration)
        tween.tween_property(particle, "scale", Vector2(0.12, 0.12), duration)
        tween.tween_property(particle, "modulate:a", 0.0, duration)
        tween.chain().tween_callback(func(): _release_particle(particle))


func float_text(position: Vector2, text: String, color: Color, font_size := 26, dramatic := false) -> void:
    var label := Label.new()
    label.text = text
    L10N.apply_font(label)
    label.position = position - Vector2(90, 25)
    label.size = Vector2(180, 50)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_outline_color", Color("#E6100A18"))
    label.add_theme_constant_override("outline_size", 6)
    label.pivot_offset = label.size * 0.5
    label.scale = Vector2(0.35, 0.35) if dramatic else Vector2(0.7, 0.7)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(label)
    var rise := 64.0 if dramatic else 42.0
    var duration := _duration(0.7 if dramatic else 0.52)
    if reduce_motion:
        rise *= 0.35
        duration *= 0.65
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "scale", Vector2.ONE * (1.18 if dramatic else 1.0), 0.16)
    tween.set_parallel(true)
    tween.tween_property(label, "position:y", label.position.y - rise, duration)
    tween.chain().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_property(label, "modulate:a", 0.0, 0.24)
    tween.tween_callback(label.queue_free)


func slash(position: Vector2, color: Color, length := 210.0, heavy := false) -> void:
    var line := Line2D.new()
    var angle := rng.randf_range(-0.42, 0.42) + (-0.25 if heavy else 0.0)
    var vector := Vector2(length, 0).rotated(angle)
    line.points = PackedVector2Array([position - vector * 0.5, position + vector * 0.5])
    line.width = 12.0 if heavy else 7.0
    line.default_color = Color(color, 0.95)
    line.antialiased = true
    add_child(line)
    burst(position, color, 22 if heavy else 14, "spark", 105.0 if heavy else 78.0)
    var tween := create_tween().set_parallel(true)
    tween.tween_property(line, "width", 1.0, _duration(0.22))
    tween.tween_property(line, "modulate:a", 0.0, _duration(0.28))
    tween.chain().tween_callback(line.queue_free)


func flash(color: Color, strength := 0.28, duration := 0.2) -> void:
    strength *= flash_strength_scale * flash_intensity
    if strength <= 0.0 or active_overlays >= int(PROFILES.LIMITS.overlays):
        return
    var overlay := ColorRect.new()
    overlay.color = Color(color, strength)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(overlay)
    active_overlays += 1
    var tween := create_tween()
    tween.tween_property(overlay, "modulate:a", 0.0, _duration(duration))
    tween.tween_callback(func(): _release_overlay(overlay))


func vignette(color: Color, duration := 0.7) -> void:
    if active_overlays >= int(PROFILES.LIMITS.overlays):
        return
    var overlay := ColorRect.new()
    overlay.color = Color(color, 0.0)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(overlay)
    active_overlays += 1
    var tween := create_tween()
    tween.tween_property(overlay, "color:a", 0.35, duration * 0.35)
    tween.tween_property(overlay, "color:a", 0.0, duration * 0.65)
    tween.tween_callback(func(): _release_overlay(overlay))


func shake(target: Control, intensity := 5.0, duration := 0.22) -> void:
    intensity *= shake_strength_scale * shake_intensity
    if reduce_shake or intensity <= 0.0 or not is_instance_valid(target):
        return
    var origin := target.position
    var tween := create_tween()
    var steps := maxi(2, int(duration / 0.035))
    for index in range(steps):
        var remaining := 1.0 - float(index) / float(steps)
        var offset := Vector2(rng.randf_range(-intensity, intensity), rng.randf_range(-intensity, intensity)) * remaining
        tween.tween_property(target, "position", origin + offset, duration / steps)
    tween.tween_property(target, "position", origin, 0.04)


func card_ghost(texture: Texture2D, from_rect: Rect2, destination: Vector2, color := COPPER, duration := 0.32) -> void:
    var card := Panel.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#E6100A18")
    style.border_color = color
    style.set_border_width_all(3)
    style.set_corner_radius_all(10)
    card.add_theme_stylebox_override("panel", style)
    card.position = from_rect.position
    card.size = from_rect.size
    card.pivot_offset = card.size * 0.5
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var art := TextureRect.new()
    art.texture = texture
    art.position = Vector2(8, 8)
    art.size = card.size - Vector2(16, 16)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.add_child(art)
    add_child(card)
    var target_position := destination - card.size * 0.5
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    var actual_duration := _duration(duration)
    tween.tween_property(card, "position", target_position, actual_duration)
    tween.tween_property(card, "rotation", rng.randf_range(-0.08, 0.08), actual_duration)
    tween.tween_property(card, "scale", Vector2(0.7, 0.7), actual_duration)
    tween.chain().tween_property(card, "modulate:a", 0.0, 0.12)
    tween.chain().tween_callback(card.queue_free)


func card_cracks(rect: Rect2, excess_damage: int, max_health: int, texture: Texture2D, accent: Color, crack_seed: int) -> Control:
    if excess_damage <= 0 or active_overlays >= int(PROFILES.LIMITS.overlays):
        return null
    var snapshot := Panel.new()
    snapshot.name = "ProceduralCardCracks"
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#F218101A")
    style.border_color = Color(accent, 0.95)
    style.set_border_width_all(3)
    style.set_corner_radius_all(11)
    snapshot.add_theme_stylebox_override("panel", style)
    snapshot.position = rect.position
    snapshot.size = rect.size
    snapshot.pivot_offset = rect.size * 0.5
    snapshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
    snapshot.clip_contents = true
    snapshot.set_meta("excess_damage", excess_damage)

    if texture != null:
        var art := TextureRect.new()
        art.texture = texture
        art.position = Vector2(10, 7)
        art.size = Vector2(rect.size.x - 20.0, rect.size.y * 0.62)
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        snapshot.add_child(art)
    var damage_glaze := ColorRect.new()
    damage_glaze.color = Color("#4DD95757")
    damage_glaze.position = Vector2(3, 3)
    damage_glaze.size = rect.size - Vector2(6, 6)
    damage_glaze.mouse_filter = Control.MOUSE_FILTER_IGNORE
    snapshot.add_child(damage_glaze)

    var cracks: Control = CARD_CRACK_OVERLAY.new()
    cracks.name = "CrackGeometry"
    cracks.configure(rect.size, excess_damage, max_health, crack_seed)
    snapshot.add_child(cracks)
    snapshot.set_meta("severity", cracks.get_meta("severity"))
    snapshot.set_meta("primary_branch_count", cracks.get_meta("primary_branch_count"))
    snapshot.set_meta("crack_path_count", cracks.get_meta("crack_path_count"))
    snapshot.set_meta("crack_reach", cracks.get_meta("crack_reach"))
    add_child(snapshot)
    active_overlays += 1

    if motion_mode != PROFILES.MOTION_MINIMAL:
        cracks.scale = Vector2(0.08, 0.08)
        cracks.modulate.a = 0.25
        var formation := create_tween().set_parallel(true)
        formation.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        formation.tween_property(cracks, "scale", Vector2.ONE, _duration(0.13))
        formation.tween_property(cracks, "modulate:a", 1.0, _duration(0.07))

    var hold_seconds := 0.38 + minf(0.22, float(excess_damage) * 0.025)
    var lifecycle := create_tween()
    lifecycle.tween_interval(_duration(hold_seconds))
    lifecycle.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    lifecycle.tween_property(snapshot, "modulate:a", 0.0, _duration(0.22))
    lifecycle.tween_callback(func(): _release_overlay(snapshot))
    return snapshot


func ingredient_fly(texture: Texture2D, start: Vector2, destination: Vector2, color: Color, label_text := "") -> void:
    var token := TextureRect.new()
    token.texture = texture
    token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    token.position = start - Vector2(24, 24)
    token.size = Vector2(48, 48)
    token.pivot_offset = Vector2(24, 24)
    token.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(token)
    var midpoint := (start + destination) * 0.5 + Vector2(0, -95)
    var duration := _duration(0.48)
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(token, "position", midpoint - Vector2(24, 24), duration * 0.48)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_property(token, "position", destination - Vector2(24, 24), duration * 0.52)
    tween.set_parallel(true)
    tween.tween_property(token, "rotation", TAU * 0.8, duration)
    tween.chain().tween_callback(func(): burst(destination, color, 15, "spark", 55.0))
    if not label_text.is_empty():
        tween.chain().tween_callback(func(): float_text(destination, label_text, color, 18, false))
    tween.chain().tween_callback(token.queue_free)


func play_sfx(kind: String, volume_db := -7.0, variation := true) -> void:
    if muted or active_audio >= int(PROFILES.LIMITS.audio):
        return
    var stream := SFX_STREAMS.get(kind) as AudioStream
    if stream == null:
        push_warning("Unknown authored SFX cue: %s" % kind)
        return
    var player := AudioStreamPlayer.new()
    player.stream = stream
    player.volume_db = volume_db
    _cue_serial += 1
    var variation_offset := (float((_cue_serial * 37 + hash(kind)) % 11) - 5.0) * 0.008 if variation else 0.0
    player.pitch_scale = pitch_scale + variation_offset
    player.bus = "UI" if kind in ["hover", "click", "invalid"] else "Cards" if kind in ["draw", "play"] else "Voice" if kind == "voice" else "Combat"
    add_child(player)
    _active_audio_players.append(player)
    active_audio += 1
    player.finished.connect(func():
        active_audio = maxi(0, active_audio - 1)
        _active_audio_players.erase(player)
        player.queue_free()
    )
    sfx_played.emit(kind)
    player.play()


func play_layered_sfx(kind: String, volume_db := -8.0) -> void:
    var kit: Dictionary = PROFILES.kit(kind)
    play_sfx(String(kit.sound), volume_db)
    if kind in ["blade", "fire", "armor", "meat", "fungus"]:
        play_sfx("material", volume_db - 6.0)


func contact_ring(position: Vector2, color: Color, radius := 42.0, heavy := false) -> void:
    var ring := Line2D.new()
    var points := _circle_points(radius, 28)
    points.append(points[0])
    ring.points = points
    ring.position = position
    ring.width = 8.0 if heavy else 4.0
    ring.default_color = color
    ring.antialiased = true
    ring.scale = Vector2(0.18, 0.18)
    add_child(ring)
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(ring, "scale", Vector2(1.35, 1.35), _duration(0.28))
    tween.tween_property(ring, "modulate:a", 0.0, _duration(0.32))
    tween.tween_property(ring, "width", 1.0, _duration(0.28))
    tween.chain().tween_callback(ring.queue_free)


func mechanic_impact(position: Vector2, kit_name: String, amount := 1, heavy := false) -> void:
    var kit: Dictionary = PROFILES.kit(kit_name)
    var primary := Color(String(kit.primary))
    var secondary := Color(String(kit.secondary))
    contact_ring(position, primary, 45.0 + minf(amount * 2.0, 18.0), heavy)
    match String(kit.particle):
        "flame":
            burst(position, primary, 18 + mini(amount, 6), "flame", 75.0)
            burst(position, Color("#4A3030"), 8, "ash", 58.0)
        "steam":
            burst(position, primary, 18, "steam", 75.0)
        "rivet":
            burst(position, secondary, 14, "rivet", 65.0)
        "spore":
            burst(position, primary, 13, "spore", 70.0)
            burst(position, secondary, 9, "steam", 52.0)
        "wedge":
            burst(position, primary, 20, "wedge", 82.0)
        _:
            burst(position, primary, 16 + mini(amount, 7), "shard", 72.0)
    play_layered_sfx(kit_name, -8.0 if not heavy else -5.0)


func show_drop_zone(rect: Rect2, valid: bool, label_text := "", insertion_rect := Rect2()) -> void:
    dismiss_drop_zone()
    var panel := Panel.new()
    panel.name = "AuthoritativePlayRegion"
    panel.set_meta("authoritative_play_region", rect)
    panel.set_meta("valid", valid)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(TEAL if valid else CRIMSON, 0.11)
    style.border_color = Color(TEAL if valid else CRIMSON, 0.9)
    style.set_border_width_all(3)
    style.set_corner_radius_all(18)
    panel.add_theme_stylebox_override("panel", style)
    panel.position = rect.position
    panel.size = rect.size
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var label := Label.new()
    label.text = label_text if not label_text.is_empty() else L10N.t("battle.release_to_serve")
    L10N.apply_font(label)
    label.position = Vector2(0, 8)
    label.size = Vector2(rect.size.x, 34)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 17)
    label.add_theme_color_override("font_color", TEAL if valid else CRIMSON)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(label)
    if insertion_rect.size != Vector2.ZERO:
        var insertion := Panel.new()
        insertion.name = "InsertionPreview"
        var insertion_style := StyleBoxFlat.new()
        insertion_style.bg_color = Color(TEAL, 0.16)
        insertion_style.border_color = Color(TEAL, 0.92)
        insertion_style.set_border_width_all(3)
        insertion_style.set_corner_radius_all(roundi(minf(insertion_rect.size.x, insertion_rect.size.y) * 0.5))
        insertion.add_theme_stylebox_override("panel", insertion_style)
        insertion.position = insertion_rect.position - rect.position
        insertion.size = insertion_rect.size
        insertion.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(insertion)
    add_child(panel)
    drop_zone_overlay = panel


func dismiss_drop_zone() -> void:
    if is_instance_valid(drop_zone_overlay):
        drop_zone_overlay.queue_free()
    drop_zone_overlay = null


func actor_reaction(target: Control, reaction: String, color: Color) -> void:
    if not is_instance_valid(target):
        return
    var origin := target.position
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    if reaction == "hit":
        tween.tween_property(target, "position", origin + Vector2(10, 2), _duration(0.06))
        tween.tween_property(target, "position", origin, _duration(0.12))
    elif reaction == "celebrate":
        tween.tween_property(target, "scale", Vector2(1.08, 1.08), _duration(0.12))
        tween.tween_property(target, "scale", Vector2.ONE, _duration(0.2))
    else:
        tween.tween_property(target, "rotation", 0.035, _duration(0.08))
        tween.tween_property(target, "rotation", -0.025, _duration(0.08))
        tween.tween_property(target, "rotation", 0.0, _duration(0.1))
    contact_ring(_control_center_in_local_space(target), color, minf(target.size.x, target.size.y) * 0.34)


func actor_lunge(target: Control, destination: Vector2, color: Color) -> void:
    if not is_instance_valid(target):
        return
    var origin := target.position
    var center := origin + target.size * 0.5
    var destination_canvas := get_global_transform_with_canvas() * destination
    var parent_item := target.get_parent() as CanvasItem
    var destination_in_parent := parent_item.get_global_transform_with_canvas().affine_inverse() * destination_canvas if parent_item != null else destination
    var direction := center.direction_to(destination_in_parent)
    var anticipation := origin - direction * 9.0
    var impact := origin + direction * minf(62.0, center.distance_to(destination_in_parent) * 0.22)
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(target, "position", anticipation, _duration(ATTACK_ANTICIPATION_SECONDS))
    tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
    tween.tween_property(target, "position", impact, _duration(ATTACK_LUNGE_SECONDS))
    tween.tween_callback(func(): contact_ring(destination, color, 46.0, true))
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(target, "position", origin, _duration(ATTACK_RECOVERY_SECONDS))


func _control_center_in_local_space(target: Control) -> Vector2:
    var canvas_center := target.get_global_transform_with_canvas() * (target.size * 0.5)
    return get_global_transform_with_canvas().affine_inverse() * canvas_center


func caption(position: Vector2, text: String, color := CREAM) -> void:
    if captions_enabled and not text.is_empty():
        float_text(position, text, color, 14, false)
        play_sfx("voice", -16.0)


func _circle_points(radius: float, sides: int) -> PackedVector2Array:
    var points := PackedVector2Array()
    for index in range(sides):
        points.append(Vector2.from_angle(TAU * float(index) / float(sides)) * radius)
    return points
