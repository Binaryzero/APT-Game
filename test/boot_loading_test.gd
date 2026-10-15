extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var boot_scene := load("res://scenes/boot.tscn") as PackedScene
	var boot := boot_scene.instantiate()
	boot.target_scene = "res://scenes/missing-for-loading-test.tscn"
	root.add_child(boot)
	current_scene = boot
	await process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()
		var capture_dir := OS.get_environment("GAME_CAPTURE_DIR")
		if capture_dir.is_empty():
			capture_dir = ProjectSettings.globalize_path("res://captures")
		DirAccess.make_dir_recursive_absolute(capture_dir)
		var capture_path := capture_dir.path_join("game-loading-" + EmberpanL10n.current_locale() + ".png")
		if root.get_texture().get_image().save_png(capture_path) != OK:
			push_error("[BOOT_LOADING_FAIL] unable to save loading screenshot")
			quit(1)
			return
	for i in range(5):
		await process_frame
	if not boot.retry_button.visible or boot.loading or boot.status_label.text != EmberpanL10n.t("loading.failed"):
		push_error("[BOOT_LOADING_FAIL] failed loads must stop and expose retry")
		quit(1)
		return
	boot.target_scene = "res://scenes/card_game.tscn"
	boot.retry_button.pressed.emit()
	var deadline := Time.get_ticks_msec() + 15000
	while is_instance_valid(boot) and Time.get_ticks_msec() < deadline:
		await process_frame
	if current_scene == null or not current_scene is EmberpanCardGame or current_scene.screen_name != "title":
		push_error("[BOOT_LOADING_FAIL] retry did not transition to the game title")
		quit(1)
		return
	await create_timer(0.15).timeout
	current_scene.free()
	current_scene = null
	await create_timer(0.15).timeout
	await process_frame
	print("[BOOT_LOADING_PASS] loading UI, failure, retry and title handoff verified")
	quit()
