extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene_path := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene_path != "res://scenes/boot.tscn":
		push_error("[PCK_BOOT_FAIL] unexpected main scene: " + main_scene_path)
		quit(1)
		return
	var packed_scene := load(main_scene_path) as PackedScene
	if packed_scene == null:
		push_error("[PCK_BOOT_FAIL] loading scene missing from exported pack")
		quit(1)
		return
	var boot := packed_scene.instantiate()
	root.add_child(boot)
	current_scene = boot
	var deadline := Time.get_ticks_msec() + 15000
	while is_instance_valid(boot) and Time.get_ticks_msec() < deadline:
		await process_frame
	if current_scene == null or current_scene.name != "CardGame" or current_scene.screen_name != "title":
		push_error("[PCK_BOOT_FAIL] exported loader did not reach title")
		quit(1)
		return
	await create_timer(0.15).timeout
	current_scene.free()
	current_scene = null
	await create_timer(0.15).timeout
	await process_frame
	print("[PCK_BOOT_PASS] exported loading screen reaches title with runtime art and scripts")
	quit()
