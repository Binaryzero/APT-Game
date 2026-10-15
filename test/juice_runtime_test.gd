extends SceneTree

const BrowserBgmPlayer = preload("res://scripts/manus/browser_bgm_player.gd")


func _initialize() -> void:
    call_deferred("_run")


func _find_hand_card(game: Node, card_id: String) -> int:
    for index in range(game.player_hand.size()):
        if game.player_hand[index].id == card_id:
            return index
    return -1


func _settle(seconds := 0.8) -> void:
    await create_timer(seconds).timeout


func _wait_for_opening_hand(game: Node, timeout_seconds := 6.0) -> void:
    var elapsed := 0.0
    while game.opening_hand_in_progress and elapsed < timeout_seconds:
        await create_timer(0.05).timeout
        elapsed += 0.05


func _run() -> void:
    var packed_scene := load("res://scenes/card_game.tscn") as PackedScene
    if packed_scene == null:
        push_error("[JUICE_RUNTIME_FAIL] card game scene did not load")
        quit(1)
        return
    var game := packed_scene.instantiate()
    root.add_child(game)
    await process_frame
    game.sound_muted = false
    game.reduce_motion = false
    game.juice.set_accessibility(false, false)
    var played_sfx: Array[String] = []
    game.juice.sfx_played.connect(func(kind: String): played_sfx.append(kind))

    var sfx_kinds: Array = game.juice.SFX_KINDS
    var sfx_streams: Dictionary = game.juice.SFX_STREAMS
    if sfx_streams.size() != sfx_kinds.size():
        push_error("[JUICE_RUNTIME_FAIL] authored SFX registry is incomplete: %s streams for %s cues" % [sfx_streams.size(), sfx_kinds.size()])
        quit(1)
        return
    for kind in sfx_kinds:
        var stream := sfx_streams.get(kind) as AudioStreamWAV
        if stream == null:
            push_error("[JUICE_RUNTIME_FAIL] authored SFX did not load: %s" % kind)
            quit(1)
            return
        if stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.mix_rate != 48000 or stream.stereo:
            push_error("[JUICE_RUNTIME_FAIL] authored SFX has unexpected format: %s" % kind)
            quit(1)
            return

    var legendary_voice := game.juice.VOICEOVER_STREAMS.get("legendary_summon") as AudioStreamWAV
    if legendary_voice == null or legendary_voice.format != AudioStreamWAV.FORMAT_16_BITS or legendary_voice.mix_rate != 48000 or legendary_voice.stereo or legendary_voice.loop_mode != AudioStreamWAV.LOOP_DISABLED or absf(legendary_voice.get_length() - 3.7163125) > 0.01:
        push_error("[JUICE_RUNTIME_FAIL] legendary summon voiceover has unexpected format, loop mode, or duration")
        quit(1)
        return

    var music_player := game.juice.music_player as BrowserBgmPlayer
    var bgm := music_player.stream as AudioStreamWAV if music_player != null else null
    if music_player == null or bgm == null or not music_player.playing or music_player.bus != "Music":
        push_error("[JUICE_RUNTIME_FAIL] persistent BGM player did not start on the Music bus")
        quit(1)
        return
    if bgm.format != AudioStreamWAV.FORMAT_16_BITS or bgm.mix_rate != 48000 or not bgm.stereo or bgm.loop_mode != AudioStreamWAV.LOOP_FORWARD or absf(bgm.get_length() - 82.5) > 0.01:
        push_error("[JUICE_RUNTIME_FAIL] persistent BGM has unexpected format, loop mode, or duration")
        quit(1)
        return
    game.juice.set_audio_muted(true)
    if not music_player.stream_paused:
        push_error("[JUICE_RUNTIME_FAIL] sound mute did not pause BGM")
        quit(1)
        return
    game.juice.set_audio_muted(false)
    if music_player.stream_paused:
        push_error("[JUICE_RUNTIME_FAIL] sound unmute did not resume BGM")
        quit(1)
        return

    game.start_new_run(1337)
    await _wait_for_opening_hand(game)
    var precise_index := _find_hand_card(game, "precise_chop")
    game.enemy_board[0].health = 2
    game._on_hand_card_pressed(precise_index)
    await _settle(0.25)
    game._on_enemy_unit_pressed(0)
    await _settle(1.5)
    if played_sfx.count("technique_attack") != 1 or played_sfx.has("technique_buff"):
        push_error("[JUICE_RUNTIME_FAIL] offensive TECHNIQUE did not use its exclusive attack cue")
        quit(1)
        return

    game.player_mana = 5
    game.use_hero_power()
    await _settle(0.5)
    var squire_index := _find_hand_card(game, "coal_squire")
    game._on_hand_card_pressed(squire_index)
    await _settle(1.0)
    game.player_mana = 10
    game.player_hand.append(game._make_runtime_card("seasoned_strike"))
    game._render_battle()
    var buff_index := _find_hand_card(game, "seasoned_strike")
    game._on_hand_card_pressed(buff_index)
    await _settle(0.15)
    game._on_player_unit_pressed(0)
    await _settle(0.8)
    if played_sfx.count("technique_buff") != 1 or played_sfx.count("technique_attack") != 1:
        push_error("[JUICE_RUNTIME_FAIL] buff TECHNIQUE did not use its exclusive empowerment cue")
        quit(1)
        return
    await game.end_player_turn()
    await _settle(0.9)
    var voiceover_player := game.juice.voiceover_player as AudioStreamPlayer
    if voiceover_player == null or voiceover_player.playing:
        push_error("[JUICE_RUNTIME_FAIL] non-legendary summons triggered the legendary voiceover")
        quit(1)
        return

    var overkill_unit: Dictionary = game._summon_unit("pickle_imp", false, false)
    overkill_unit.health = 1
    game._damage_unit(overkill_unit, 2, true)
    game._remove_dead_units()
    game._render_battle()
    await _settle(1.5)

    game._summon_unit("mise_the_thousand_handed", true, false)
    game._render_battle()
    await _settle(0.4)
    if not voiceover_player.playing or absf(music_player.volume_db + 9.0) > 0.01:
        push_error("[JUICE_RUNTIME_FAIL] legendary unit summon did not trigger voiceover and BGM ducking")
        quit(1)
        return
    game.juice.stop_voiceover()
    if absf(music_player.volume_db) > 0.01:
        push_error("[JUICE_RUNTIME_FAIL] stopping legendary voiceover did not restore BGM gain")
        quit(1)
        return

    var character_attack_before := played_sfx.count("character_attack")
    var generic_play_before := played_sfx.count("play")
    game._queue_juice_event({"kind": "attack", "position": Vector2(420, 360), "destination": Vector2(760, 260), "enemy": false})
    game._queue_juice_event({"kind": "attack", "position": Vector2(760, 260), "destination": Vector2(420, 560), "enemy": true})
    await _settle(1.0)
    if played_sfx.count("character_attack") != character_attack_before + 2 or played_sfx.count("play") != generic_play_before:
        push_error("[JUICE_RUNTIME_FAIL] character attacks did not exclusively use the dedicated startup cue")
        quit(1)
        return

    game._queue_juice_event({"kind": "legendary_engine", "position": Vector2(520, 430), "amount": 1})
    game._queue_juice_event({"kind": "legendary_cleave", "position": Vector2(640, 330), "amount": 5})
    game._queue_juice_event({"kind": "legendary_bell", "position": Vector2(640, 430), "amount": 3})
    await _settle(1.8)
    if game.juice_processing or not game.juice_events.is_empty():
        push_error("[JUICE_RUNTIME_FAIL] legendary presentation events did not drain")
        quit(1)
        return

    game.debug_force_battle_victory()
    await _settle(0.7)
    game.pantry.fungus = 1
    game.pantry.herb = 1
    game._render_kitchen()
    game._cook_recipe("mooncap_broth")
    await _settle(1.4)
    game._select_reward(game.reward_options[0])
    await _settle(0.8)
    game._continue_from_kitchen()
    await _settle(0.6)
    game._choose_route("mold_monarch")
    await _settle(1.0)

    game.battle_number = 3
    game.current_encounter_id = "banquet_tyrant"
    game.enemy_max_health = 34
    game.enemy_health = 18
    game._damage_enemy_hero(2)
    await _settle(1.5)
    game.debug_force_run_victory()
    await _settle(1.6)
    game.start_new_run(2026)
    await _wait_for_opening_hand(game)
    game._skip_tutorial()
    var defeated_portrait := game.player_hero_control as Control
    game.player_health = 1
    game._damage_player(1, true)
    game._check_end_state()
    await _settle(1.3)
    if game.screen_name != "end" or game.run_result != "defeat" or is_instance_valid(defeated_portrait) or game.player_hero_control != null:
        push_error("[JUICE_RUNTIME_FAIL] lethal hero damage retained a freed battle portrait")
        quit(1)
        return
    if game.juice_processing or not game.juice_events.is_empty():
        push_error("[JUICE_RUNTIME_FAIL] lethal hero damage presentation did not drain after the defeat rebuild")
        quit(1)
        return

    game.free()
    await create_timer(0.15).timeout
    await process_frame
    await process_frame
    print("[JUICE_RUNTIME_PASS] dedicated character attacks, split offensive/buff TECHNIQUE cues, legendary summon voiceover, looping Lyria BGM, authored SFX, legendary rewards, combat, harvest, cooking, route, boss, victory, and lethal-damage defeat sequences completed")
    quit(0)
