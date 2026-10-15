extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var online = load("res://scenes/multiplayer.tscn").instantiate()
	root.add_child(online)
	await process_frame
	online.state = {"screen": "lobby", "status": "connected", "id": 1, "error": "", "room": {"id": "DUEL", "leader": 1,
		"catalog": {"starters": {"balanced": [], "aggro": [], "guard": []}, "heroes": ["chef_sama", "picklemancer", "mold_monarch", "ember_butcher", "banquet_tyrant"], "legendaries": ["mise_the_thousand_handed", "the_sovereign_cleaver", "bell_of_the_last_service"]},
		"members": [{"id": 1, "name": "Player One", "connected": true, "ready": false, "loadout": {"starter": "aggro", "hero": "ember_butcher", "legendary": "mise_the_thousand_handed"}}, {"id": 2, "name": "Player Two", "connected": true, "ready": true}]}}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	for locale in ["en", "zh-CN"]:
		online.L10N.set_locale(locale)
		online._render()
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		await process_frame
		root.get_texture().get_image().save_png("res://captures/loadout-" + locale + ".png")
	quit()
