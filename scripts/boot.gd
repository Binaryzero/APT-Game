extends Control
## Lightweight entry scene: render first, then load the game without preloading its resources.

const L10N := preload("res://scripts/localization.gd")
const BACKGROUND := preload("res://assets/template/cardgame/loading/emberpan-loading.png")
@export_file("*.tscn") var target_scene := "res://scenes/card_game.tscn"
var progress_bar: ProgressBar
var status_label: Label
var retry_button: Button
var loading := false
var transitioning := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art := TextureRect.new()
	art.texture = BACKGROUND
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.01, 0.04, 0.3)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var title := Label.new()
	title.text = L10N.t("loading.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color("#FFD36A"))
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 45
	title.offset_bottom = 110
	add_child(title)
	var panel := VBoxContainer.new()
	panel.name = "LoadingPanel"
	panel.anchor_left = 0.2
	panel.anchor_right = 0.8
	panel.anchor_top = 0.72
	panel.anchor_bottom = 0.96
	panel.add_theme_constant_override("separation", 14)
	add_child(panel)
	status_label = Label.new()
	status_label.name = "LoadingStatus"
	status_label.text = L10N.t("loading.preparing")
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 23)
	panel.add_child(status_label)
	progress_bar = ProgressBar.new()
	progress_bar.name = "SceneProgress"
	progress_bar.custom_minimum_size.y = 10
	progress_bar.show_percentage = false
	progress_bar.indeterminate = true
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#35223E")
	track.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#F3A33C")
	fill.set_corner_radius_all(5)
	progress_bar.add_theme_stylebox_override("background", track)
	progress_bar.add_theme_stylebox_override("fill", fill)
	panel.add_child(progress_bar)
	var hint := Label.new()
	hint.text = L10N.t("loading.hint")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("#DEC9A7"))
	panel.add_child(hint)
	retry_button = Button.new()
	retry_button.name = "RetryLoading"
	retry_button.text = L10N.t("loading.retry")
	retry_button.custom_minimum_size.y = 44
	retry_button.hide()
	retry_button.pressed.connect(_begin_loading)
	panel.add_child(retry_button)
	L10N.apply_tree_fonts(self)
	_begin_loading()

func _begin_loading() -> void:
	if loading or transitioning:
		return
	loading = true
	retry_button.hide()
	progress_bar.show()
	status_label.text = L10N.t("loading.preparing")
	# Present the loading artwork before synchronous resource initialization.
	# Godot 4.7.2 leaks script placeholders when this PCK loads on a worker.
	# Keep main-thread loading and an honest indeterminate preparation state.
	await get_tree().process_frame
	await get_tree().process_frame
	_enter_game.call_deferred()

func _enter_game() -> void:
	if not ResourceLoader.exists(target_scene):
		_fail()
		return
	transitioning = true
	var scene := ResourceLoader.load(target_scene, "PackedScene") as PackedScene
	if scene == null or get_tree().change_scene_to_packed(scene) != OK:
		_fail()

func _fail() -> void:
	loading = false
	transitioning = false
	progress_bar.hide()
	status_label.text = L10N.t("loading.failed")
	retry_button.show()
	retry_button.grab_focus()
