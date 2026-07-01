extends Control

const BOARD_MODEL_SCRIPT := preload("res://scripts/board_model.gd")
const SELF_PLAY_AGENT_SCRIPT := preload("res://scripts/self_play_agent.gd")
const DEFAULT_THEME_ID := "classic"
const GRID_SIZE := 4
const CELL_COUNT := GRID_SIZE * GRID_SIZE
const TARGET_VALUE := 2048
const SAVE_PATH := "user://save.cfg"
const SWIPE_THRESHOLD := 72.0
const MAX_UNDO_STEPS := 3
const HIGH_LEVEL_GLOW_THRESHOLD := 128
const FIRE_LEVEL_THRESHOLD := 512
const EXPLOSION_LEVEL_THRESHOLD := 64

const DEBUG_PRESETS := {
	"spawn_pulse": {
		"board": [
			0, 0, 0, 0,
			0, 2, 4, 0,
			0, 8, 16, 0,
			0, 0, 0, 0
		],
		"play_board": [
			0, 0, 0, 0,
			0, 2, 4, 0,
			0, 8, 16, 0,
			0, 0, 0, 2
		],
		"score": 48,
		"description": "Spawn pulse board loaded."
	},
	"merge_128": {
		"board": [
			64, 64, 8, 0,
			16, 32, 8, 0,
			0, 4, 2, 0,
			0, 0, 0, 0
		],
		"play_board": [
			128, 8, 0, 0,
			16, 32, 8, 0,
			4, 2, 0, 0,
			0, 0, 0, 2
		],
		"score": 840,
		"description": "128 merge board loaded."
	},
	"merge_512": {
		"board": [
			256, 256, 32, 0,
			128, 64, 16, 0,
			0, 8, 4, 0,
			0, 0, 0, 0
		],
		"play_board": [
			512, 32, 0, 0,
			128, 64, 16, 0,
			8, 4, 0, 0,
			0, 0, 0, 2
		],
		"score": 6240,
		"description": "512 merge board loaded."
	},
	"merge_1024": {
		"board": [
			512, 512, 64, 0,
			256, 128, 32, 0,
			64, 16, 8, 0,
			4, 2, 0, 0
		],
		"play_board": [
			1024, 64, 0, 0,
			256, 128, 32, 0,
			64, 16, 8, 0,
			4, 2, 0, 2
		],
		"score": 10320,
		"description": "1024 merge strike board loaded."
	},
	"merge_4096": {
		"board": [
			2048, 2048, 256, 0,
			1024, 512, 128, 0,
			64, 32, 16, 0,
			8, 4, 2, 0
		],
		"play_board": [
			4096, 256, 0, 0,
			1024, 512, 128, 0,
			64, 32, 16, 0,
			8, 4, 2, 4
		],
		"score": 34880,
		"description": "4096 merge scene-cue board loaded."
	},
	"combo_chain": {
		"board": [
			64, 64, 32, 32,
			16, 16, 8, 8,
			4, 4, 2, 2,
			0, 0, 0, 0
		],
		"play_board": [
			128, 64, 0, 0,
			32, 16, 0, 0,
			8, 4, 0, 0,
			0, 0, 0, 2
		],
		"score": 4120,
		"description": "Combo-chain board loaded."
	},
	"celebration_2048": {
		"board": [
			1024, 1024, 64, 0,
			512, 256, 128, 0,
			64, 32, 16, 0,
			8, 4, 2, 0
		],
		"play_board": [
			2048, 64, 0, 0,
			512, 256, 128, 0,
			64, 32, 16, 0,
			8, 4, 2, 4
		],
		"score": 18240,
		"description": "2048 celebration board loaded."
	}
}

@export var classic_theme: Resource
@export var promare_theme: Resource

@onready var score_label: Label = $SafeArea/VBox/Header/ScoreCard/ScoreBox/Value
@onready var best_label: Label = $SafeArea/VBox/Header/BestCard/BestBox/Value
@onready var status_label: Label = $SafeArea/VBox/Controls/Status
@onready var board_grid = $SafeArea/VBox/BoardFrame/BoardPadding/BoardCenter/BoardGrid
@onready var background_rect: ColorRect = $Background
@onready var undo_button: Button = $SafeArea/VBox/Controls/ButtonsRow/UndoButton
@onready var new_game_button: Button = $SafeArea/VBox/Controls/ButtonsRow/NewGameButton
@onready var self_play_button: Button = $SafeArea/VBox/Controls/ButtonsRow/SelfPlayButton
@onready var theme_picker: OptionButton = $SafeArea/VBox/Controls/ButtonsRow/ThemePicker
@onready var safe_area: MarginContainer = $SafeArea
@onready var flash_overlay: ColorRect = $FlashOverlay
@onready var vfx_controller = $Effects
@onready var effect_director = $EffectDirector
@onready var debug_panel = $DebugPanel

var board_model
var board_view
var self_play_agent
var rng := RandomNumberGenerator.new()
var board: Array[int] = []
var score := 0
var best_score := 0
var has_won := false
var touch_start := Vector2.ZERO
var swipe_consumed := false
var undo_history: Array[Dictionary] = []
var last_spawned_index := -1
var last_merged_indices: Array[int] = []
var last_move_animations: Array[Dictionary] = []
var last_top_merge_value := 0
var combo_count := 0
var highest_announced_tile := 0
var self_play_enabled := true
var self_play_running := false
var self_play_timer: SceneTreeTimer = null
var theme_configs: Dictionary = {}
var current_theme_id := DEFAULT_THEME_ID
var current_theme


func _ready() -> void:
	rng.randomize()
	board_model = BOARD_MODEL_SCRIPT.new()
	board_view = board_grid
	self_play_agent = SELF_PLAY_AGENT_SCRIPT.new()
	_initialize_themes()
	_load_best_score()
	_resolve_current_theme()
	_apply_display_safe_area()
	vfx_controller.configure(
		board_view,
		flash_overlay,
		Callable(self, "_font_size_for"),
		current_theme.tile_colors,
		current_theme.tile_text_colors,
		HIGH_LEVEL_GLOW_THRESHOLD,
		FIRE_LEVEL_THRESHOLD,
		EXPLOSION_LEVEL_THRESHOLD
	)
	vfx_controller.apply_theme(current_theme)
	effect_director.configure(vfx_controller)
	_populate_theme_picker()
	_apply_theme()
	undo_button.pressed.connect(_on_undo_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	self_play_button.pressed.connect(_on_self_play_pressed)
	theme_picker.item_selected.connect(_on_theme_selected)
	debug_panel.preset_load_requested.connect(_on_debug_preset_load_requested)
	debug_panel.preset_play_requested.connect(_on_debug_preset_play_requested)
	debug_panel.reset_requested.connect(_on_debug_reset_requested)
	new_game()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		_try_move(Vector2i.LEFT)
	elif event.is_action_pressed("move_right"):
		_try_move(Vector2i.RIGHT)
	elif event.is_action_pressed("move_up"):
		_try_move(Vector2i.UP)
	elif event.is_action_pressed("move_down"):
		_try_move(Vector2i.DOWN)
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			touch_start = touch_event.position
			swipe_consumed = false
		else:
			swipe_consumed = false
	elif event is InputEventScreenDrag:
		if swipe_consumed:
			return
		var drag_event := event as InputEventScreenDrag
		var delta := drag_event.position - touch_start
		if delta.length() >= SWIPE_THRESHOLD:
			_handle_swipe(delta)
			swipe_consumed = true


func _process(delta: float) -> void:
	vfx_controller.advance(delta, board)


func new_game() -> void:
	var result = board_model.new_game(rng)
	board = result["board"]
	score = 0
	has_won = false
	undo_history.clear()
	last_spawned_index = result["spawned_indices"][-1] if not result["spawned_indices"].is_empty() else -1
	last_merged_indices.clear()
	last_top_merge_value = 0
	combo_count = 0
	highest_announced_tile = board_model.max_value(board)
	self_play_running = false
	self_play_timer = null
	vfx_controller.reset_debug_state()
	_update_undo_button()
	_update_self_play_button()
	_update_status("Ready. Use arrow keys, WASD, or swipe.")
	_sync_debug_feedback("Live game reset.")
	_refresh_ui()
	effect_director.play_event("spawn", _build_effect_context([], [], last_spawned_index, 0))


func _apply_display_safe_area() -> void:
	if OS.has_feature("macos") or OS.has_feature("windows") or OS.has_feature("linuxbsd") or OS.has_feature("web"):
		return

	var base_left := int(safe_area.get_theme_constant("margin_left"))
	var base_top := int(safe_area.get_theme_constant("margin_top"))
	var base_right := int(safe_area.get_theme_constant("margin_right"))
	var base_bottom := int(safe_area.get_theme_constant("margin_bottom"))

	var viewport_rect := get_viewport_rect()
	var safe_rect := DisplayServer.get_display_safe_area()
	if safe_rect.size == Vector2i.ZERO:
		return

	var left_margin: int = max(base_left, safe_rect.position.x)
	var top_margin: int = max(base_top, safe_rect.position.y)
	var right_margin: int = max(base_right, viewport_rect.size.x - (safe_rect.position.x + safe_rect.size.x))
	var bottom_margin: int = max(base_bottom, viewport_rect.size.y - (safe_rect.position.y + safe_rect.size.y))

	safe_area.add_theme_constant_override("margin_left", left_margin)
	safe_area.add_theme_constant_override("margin_top", top_margin)
	safe_area.add_theme_constant_override("margin_right", right_margin)
	safe_area.add_theme_constant_override("margin_bottom", bottom_margin)


func _try_move(direction: Vector2i) -> void:
	var snapshot := _capture_state()
	var result = board_model.apply_move(direction)
	if not result["moved"]:
		return
	board = result["board"]

	_push_undo_state(snapshot)
	score += result["score_gain"]
	if score > best_score:
		best_score = score
		_save_best_score()

	last_merged_indices = result["merged_indices"]
	last_move_animations = result["animations"]
	last_top_merge_value = 0
	for tile_index in last_merged_indices:
		last_top_merge_value = max(last_top_merge_value, board[tile_index])
	var merged_indices_for_feedback: Array[int] = last_merged_indices.duplicate()
	var move_animations_for_feedback: Array[Dictionary] = last_move_animations.duplicate()
	combo_count = combo_count + 1 if result["score_gain"] > 0 else 0
	last_spawned_index = board_model.spawn_random_tile(rng)
	board = board_model.get_board()
	_update_undo_button()
	_refresh_ui()
	effect_director.play_event(
		"merge_move",
		_build_effect_context(move_animations_for_feedback, merged_indices_for_feedback, last_spawned_index, last_top_merge_value)
	)

	if _should_play_screen_merge_feedback(last_top_merge_value):
		effect_director.play_event(
			"screen_merge",
			_build_effect_context(move_animations_for_feedback, merged_indices_for_feedback, last_spawned_index, last_top_merge_value)
		)

	var current_max: int = board_model.max_value(board)
	if current_max > highest_announced_tile and _should_play_milestone_feedback(current_max):
		highest_announced_tile = current_max
		effect_director.play_event(
			"milestone",
			_build_effect_context(move_animations_for_feedback, merged_indices_for_feedback, last_spawned_index, current_max)
		)
	elif current_max > highest_announced_tile:
		highest_announced_tile = current_max

	last_merged_indices.clear()
	last_move_animations.clear()

	if result["max_tile"] >= TARGET_VALUE and not has_won:
		has_won = true
		effect_director.play_event(
			"celebration",
			_build_effect_context(move_animations_for_feedback, merged_indices_for_feedback, last_spawned_index, result["max_tile"])
		)
		_update_status("2048 reached. Keep going if you want a higher score.")
	elif board_model.is_game_over(board):
		_update_status("No moves left. Start a new game.")
	else:
		_update_status("Merged %d points." % result["score_gain"] if result["score_gain"] > 0 else "Move registered.")


func _refresh_ui() -> void:
	score_label.text = str(score)
	best_label.text = str(best_score)

	for i in CELL_COUNT:
		var value := board[i]
		var panel: PanelContainer = board_view.panel_at(i)
		var label: Label = board_view.label_at(i)
		var style := StyleBoxFlat.new()
		style.bg_color = _tile_color_for(value)
		style.corner_radius_top_left = current_theme.tile_corner_radius
		style.corner_radius_top_right = current_theme.tile_corner_radius
		style.corner_radius_bottom_right = current_theme.tile_corner_radius
		style.corner_radius_bottom_left = current_theme.tile_corner_radius
		if _is_promare_theme():
			style.shadow_size = 10 if value < HIGH_LEVEL_GLOW_THRESHOLD else (18 if value < FIRE_LEVEL_THRESHOLD else 24)
			style.shadow_color = Color(
				style.bg_color.r,
				style.bg_color.g,
				style.bg_color.b,
				0.18 if value == 0 else (0.34 if value < HIGH_LEVEL_GLOW_THRESHOLD else 0.52)
			)
		if value >= FIRE_LEVEL_THRESHOLD:
			style.border_width_left = 4
			style.border_width_top = 4
			style.border_width_right = 4
			style.border_width_bottom = 4
			style.border_color = current_theme.tile_border_color_fire
		elif value >= 256:
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			style.border_color = current_theme.tile_border_color_256
		elif value >= HIGH_LEVEL_GLOW_THRESHOLD:
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = current_theme.tile_border_color_128

		panel.add_theme_stylebox_override("panel", style)
		label.text = "" if value == 0 else str(value)
		label.add_theme_color_override("font_color", _tile_text_color_for(value))
		label.add_theme_font_size_override("font_size", _font_size_for(value))
		panel.modulate = Color.WHITE
		panel.scale = Vector2.ONE
		panel.pivot_offset = panel.size * 0.5
		vfx_controller.apply_tile_overlay(i, value, panel)


func _apply_theme() -> void:
	var title := $SafeArea/VBox/Header/TitleColumn/Title as Label
	title.add_theme_font_size_override("font_size", 68 if _is_promare_theme() else 60)
	title.add_theme_color_override("font_color", current_theme.title_color)

	var subtitle := $SafeArea/VBox/Header/TitleColumn/Subtitle as Label
	subtitle.add_theme_font_size_override("font_size", 20 if _is_promare_theme() else 22)
	subtitle.add_theme_color_override("font_color", current_theme.subtitle_color)

	var score_card := $SafeArea/VBox/Header/ScoreCard as PanelContainer
	var best_card := $SafeArea/VBox/Header/BestCard as PanelContainer
	score_card.add_theme_stylebox_override("panel", _card_style())
	best_card.add_theme_stylebox_override("panel", _card_style())

	var board_frame := $SafeArea/VBox/BoardFrame as PanelContainer
	board_frame.add_theme_stylebox_override("panel", _board_style())

	var vbox := $SafeArea/VBox as VBoxContainer
	var header := $SafeArea/VBox/Header as HBoxContainer
	var controls := $SafeArea/VBox/Controls as VBoxContainer
	var buttons_row := $SafeArea/VBox/Controls/ButtonsRow as HBoxContainer
	vbox.add_theme_constant_override("separation", 16 if _is_promare_theme() else 18)
	header.add_theme_constant_override("separation", 14 if _is_promare_theme() else 16)
	controls.add_theme_constant_override("separation", 10 if _is_promare_theme() else 12)
	buttons_row.add_theme_constant_override("separation", 10 if _is_promare_theme() else 16)

	var help := $SafeArea/VBox/Help as Label
	help.add_theme_font_size_override("font_size", 18)
	help.add_theme_color_override("font_color", current_theme.help_color)

	var controls_status := $SafeArea/VBox/Controls/Status as Label
	controls_status.add_theme_font_size_override("font_size", 20)
	controls_status.add_theme_color_override("font_color", current_theme.status_color)

	var score_title := $SafeArea/VBox/Header/ScoreCard/ScoreBox/Label as Label
	var best_title := $SafeArea/VBox/Header/BestCard/BestBox/Label as Label
	for label in [score_title, best_title]:
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", current_theme.score_label_color)

	score_label.add_theme_font_size_override("font_size", 30)
	score_label.add_theme_color_override("font_color", current_theme.score_value_color)
	best_label.add_theme_font_size_override("font_size", 30)
	best_label.add_theme_color_override("font_color", current_theme.score_value_color)

	new_game_button.add_theme_font_size_override("font_size", 22)
	undo_button.add_theme_font_size_override("font_size", 20)
	self_play_button.add_theme_font_size_override("font_size", 20)
	theme_picker.add_theme_font_size_override("font_size", 18)
	for button in [theme_picker, undo_button, new_game_button, self_play_button]:
		_apply_button_theme(button)

	background_rect.color = current_theme.background_color
	flash_overlay.color = Color(
		current_theme.flash_overlay_color.r,
		current_theme.flash_overlay_color.g,
		current_theme.flash_overlay_color.b,
		0.0
	)


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = current_theme.score_card_color
	style.corner_radius_top_left = 10 if _is_promare_theme() else 16
	style.corner_radius_top_right = 10 if _is_promare_theme() else 16
	style.corner_radius_bottom_right = 10 if _is_promare_theme() else 16
	style.corner_radius_bottom_left = 10 if _is_promare_theme() else 16
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	if _is_promare_theme():
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = current_theme.tile_border_color_128
		style.shadow_size = 14
		style.shadow_color = Color(
			current_theme.tile_border_color_256.r,
			current_theme.tile_border_color_256.g,
			current_theme.tile_border_color_256.b,
			0.24
		)
	return style


func _board_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = current_theme.board_frame_color
	style.corner_radius_top_left = 14 if _is_promare_theme() else 24
	style.corner_radius_top_right = 14 if _is_promare_theme() else 24
	style.corner_radius_bottom_right = 14 if _is_promare_theme() else 24
	style.corner_radius_bottom_left = 14 if _is_promare_theme() else 24
	if _is_promare_theme():
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = current_theme.tile_border_color_128
		style.shadow_size = 22
		style.shadow_color = Color(
			current_theme.tile_border_color_256.r,
			current_theme.tile_border_color_256.g,
			current_theme.tile_border_color_256.b,
			0.20
		)
	return style


func _font_size_for(value: int) -> int:
	if value < 128:
		return 38
	if value < 1024:
		return 34
	if value < 10000:
		return 28
	return 24


func _handle_swipe(delta: Vector2) -> void:
	if absf(delta.x) > absf(delta.y):
		_try_move(Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT)
	else:
		_try_move(Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP)


func _on_debug_preset_load_requested(preset_id: String) -> void:
	_load_debug_preset(preset_id, false)


func _on_debug_preset_play_requested(preset_id: String) -> void:
	_load_debug_preset(preset_id, true)


func _on_debug_reset_requested() -> void:
	new_game()


func _load_debug_preset(preset_id: String, play_effect: bool) -> void:
	if not DEBUG_PRESETS.has(preset_id):
		_sync_debug_feedback("Unknown preset: %s" % preset_id)
		return

	var preset: Dictionary = DEBUG_PRESETS[preset_id]
	_apply_debug_board(preset, "board")
	_sync_debug_feedback(preset["description"])
	if play_effect:
		_play_debug_preset(preset_id)


func _apply_debug_board(preset: Dictionary, board_key: String = "board") -> void:
	_stop_self_play("Self-play paused for VFX debug.")
	vfx_controller.reset_debug_state()
	board = _typed_int_array(preset.get(board_key, preset["board"]))
	board_model.set_board(board)
	score = int(preset.get("score", 0))
	has_won = false
	undo_history.clear()
	last_spawned_index = -1
	last_merged_indices.clear()
	last_move_animations.clear()
	last_top_merge_value = 0
	combo_count = 0
	highest_announced_tile = board_model.max_value(board)
	_update_undo_button()
	_refresh_ui()
	_update_status(str(preset.get("description", "Debug preset loaded.")))


func _play_debug_preset(preset_id: String) -> void:
	vfx_controller.reset_debug_state()
	var preset: Dictionary = DEBUG_PRESETS[preset_id]
	match preset_id:
		"spawn_pulse":
			_apply_debug_board(preset, "play_board")
			last_spawned_index = 15
			effect_director.preview_profile("spawn", _build_effect_context([], [], last_spawned_index, 0, 0))
		"merge_128":
			_apply_debug_board(preset, "play_board")
			_play_debug_merge(
				[
					{"from": 0, "to": 0, "value": 64, "merge": true},
					{"from": 1, "to": 0, "value": 64, "merge": true},
					{"from": 2, "to": 1, "value": 8, "merge": false}
				],
				[0],
				15,
				1,
				128,
				false,
				false
			)
		"merge_512":
			_apply_debug_board(preset, "play_board")
			_play_debug_merge(
				[
					{"from": 0, "to": 0, "value": 256, "merge": true},
					{"from": 1, "to": 0, "value": 256, "merge": true},
					{"from": 2, "to": 1, "value": 32, "merge": false}
				],
				[0],
				15,
				1,
				512,
				true,
				false
			)
		"merge_1024":
			_apply_debug_board(preset, "play_board")
			_play_debug_merge(
				[
					{"from": 0, "to": 0, "value": 512, "merge": true},
					{"from": 1, "to": 0, "value": 512, "merge": true},
					{"from": 2, "to": 1, "value": 64, "merge": false}
				],
				[0],
				15,
				1,
				1024,
				false,
				false
			)
		"merge_4096":
			_apply_debug_board(preset, "play_board")
			_play_debug_merge(
				[
					{"from": 0, "to": 0, "value": 2048, "merge": true},
					{"from": 1, "to": 0, "value": 2048, "merge": true},
					{"from": 2, "to": 1, "value": 256, "merge": false}
				],
				[0],
				15,
				2,
				4096,
				true,
				false
			)
		"combo_chain":
			_apply_debug_board(preset, "play_board")
			_play_debug_merge(
				[
					{"from": 0, "to": 0, "value": 64, "merge": true},
					{"from": 1, "to": 0, "value": 64, "merge": true},
					{"from": 2, "to": 1, "value": 32, "merge": true},
					{"from": 3, "to": 1, "value": 32, "merge": true},
					{"from": 4, "to": 4, "value": 16, "merge": true},
					{"from": 5, "to": 4, "value": 16, "merge": true},
					{"from": 6, "to": 5, "value": 8, "merge": true},
					{"from": 7, "to": 5, "value": 8, "merge": true},
					{"from": 8, "to": 8, "value": 4, "merge": true},
					{"from": 9, "to": 8, "value": 4, "merge": true},
					{"from": 10, "to": 9, "value": 2, "merge": true},
					{"from": 11, "to": 9, "value": 2, "merge": true}
				],
				[0, 1, 4, 5, 8, 9],
				15,
				3,
				128,
				false,
				false
			)
		"celebration_2048":
			_apply_debug_board(preset, "play_board")
			_play_debug_merge(
				[
					{"from": 0, "to": 0, "value": 1024, "merge": true},
					{"from": 1, "to": 0, "value": 1024, "merge": true},
					{"from": 2, "to": 1, "value": 64, "merge": false}
				],
				[0],
				15,
				2,
				2048,
				true,
				true
			)
		_:
			_sync_debug_feedback("No playback recipe for preset: %s" % preset_id)
			return
	_sync_debug_feedback("Played preset: %s" % preset_id)


func _play_debug_merge(
	move_animations: Array[Dictionary],
	merged_indices: Array[int],
	spawned_index: int,
	debug_combo_count: int,
	top_merge_value: int,
	play_milestone: bool,
	play_celebration_fx: bool
) -> void:
	var context := _build_effect_context(move_animations, merged_indices, spawned_index, top_merge_value, debug_combo_count)
	effect_director.preview_profile("merge_move", context)
	if _should_play_screen_merge_feedback(top_merge_value):
		effect_director.preview_profile("screen_merge", context)
	if play_milestone and _should_play_milestone_feedback(top_merge_value):
		effect_director.preview_profile("milestone", context)
	if play_celebration_fx:
		effect_director.preview_profile("celebration", context)


func _should_play_screen_merge_feedback(value: int) -> bool:
	return value >= 2048


func _should_play_milestone_feedback(value: int) -> bool:
	return value >= 2048


func _typed_int_array(values: Variant) -> Array[int]:
	var typed: Array[int] = []
	if not (values is Array):
		return typed
	for value in values:
		typed.append(int(value))
	return typed


func _build_effect_context(
	move_animations: Array,
	merged_indices: Array[int],
	spawned_index: int,
	tile_value: int,
	context_combo_count: int = combo_count
) -> Dictionary:
	var focus_tile_index: int = vfx_controller.highest_merge_tile(board, merged_indices)
	return {
		"board": board.duplicate(),
		"move_animations": move_animations.duplicate(),
		"merged_indices": merged_indices.duplicate(),
		"spawned_index": spawned_index,
		"combo_count": context_combo_count,
		"tile_value": tile_value,
		"focus_tile_index": focus_tile_index
	}


func _sync_debug_feedback(message: String) -> void:
	if is_instance_valid(debug_panel):
		debug_panel.set_feedback(message)


func _update_status(message: String) -> void:
	status_label.text = message


func _load_best_score() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		best_score = int(config.get_value("stats", "best_score", 0))
		current_theme_id = str(config.get_value("ui", "theme_id", DEFAULT_THEME_ID))


func _save_best_score() -> void:
	var config := ConfigFile.new()
	config.set_value("stats", "best_score", best_score)
	config.set_value("ui", "theme_id", current_theme_id)
	config.save(SAVE_PATH)


func _on_new_game_pressed() -> void:
	new_game()


func _on_self_play_pressed() -> void:
	if self_play_running:
		_stop_self_play("Self-play stopped.")
	else:
		_start_self_play()


func _on_undo_pressed() -> void:
	if undo_history.is_empty():
		_update_status("No undo steps remaining.")
		return

	var snapshot: Dictionary = undo_history.pop_back()
	_restore_state(snapshot)
	last_spawned_index = -1
	last_merged_indices.clear()
	last_top_merge_value = 0
	_update_undo_button()
	_update_status("Undid the previous move.")
	_refresh_ui()
	_stop_self_play("Self-play paused after undo.")


func _on_theme_selected(index: int) -> void:
	var selected_id := str(theme_picker.get_item_metadata(index))
	if selected_id == current_theme_id:
		return
	current_theme_id = selected_id
	_resolve_current_theme()
	vfx_controller.configure(
		board_view,
		flash_overlay,
		Callable(self, "_font_size_for"),
		current_theme.tile_colors,
		current_theme.tile_text_colors,
		HIGH_LEVEL_GLOW_THRESHOLD,
		FIRE_LEVEL_THRESHOLD,
		EXPLOSION_LEVEL_THRESHOLD
	)
	vfx_controller.apply_theme(current_theme)
	_apply_theme()
	_refresh_ui()
	_save_best_score()


func _capture_state() -> Dictionary:
	return {
		"board": board.duplicate(),
		"score": score,
		"best_score": best_score,
		"has_won": has_won
	}


func _restore_state(snapshot: Dictionary) -> void:
	board = (snapshot["board"] as Array).duplicate()
	board_model.set_board(board)
	score = int(snapshot["score"])
	best_score = int(snapshot["best_score"])
	has_won = bool(snapshot["has_won"])
	_save_best_score()


func _push_undo_state(snapshot: Dictionary) -> void:
	undo_history.append(snapshot)
	while undo_history.size() > MAX_UNDO_STEPS:
		undo_history.pop_front()


func _update_undo_button() -> void:
	undo_button.disabled = undo_history.is_empty()
	undo_button.text = "Undo (%d)" % undo_history.size()


func _initialize_themes() -> void:
	theme_configs.clear()
	if classic_theme != null:
		var theme = classic_theme
		if theme != null:
			theme_configs[theme.theme_id] = theme
	if promare_theme != null:
		var theme = promare_theme
		if theme != null:
			theme_configs[theme.theme_id] = theme


func _resolve_current_theme() -> void:
	current_theme = theme_configs.get(current_theme_id, null)
	if current_theme == null:
		current_theme = theme_configs.get(DEFAULT_THEME_ID, null)
	if current_theme == null and classic_theme != null:
		current_theme = classic_theme
	if current_theme != null:
		current_theme_id = current_theme.theme_id


func _populate_theme_picker() -> void:
	theme_picker.clear()
	for theme_id in [DEFAULT_THEME_ID, "promare"]:
		var theme = theme_configs.get(theme_id, null)
		if theme == null:
			continue
		theme_picker.add_item(theme.display_name)
		theme_picker.set_item_metadata(theme_picker.item_count - 1, theme.theme_id)
	for index in theme_picker.item_count:
		if str(theme_picker.get_item_metadata(index)) == current_theme_id:
			theme_picker.select(index)
			break


func _tile_color_for(value: int) -> Color:
	if current_theme == null:
		return Color("3c3a32")
	if current_theme.tile_colors.has(value):
		return current_theme.tile_colors[value]
	if value > 2048 and current_theme.tile_colors.has(2048):
		return current_theme.tile_colors[2048]
	return current_theme.tile_colors.get(0, Color("3c3a32"))


func _tile_text_color_for(value: int) -> Color:
	if current_theme == null:
		return Color.WHITE
	if current_theme.tile_text_colors.has(value):
		return current_theme.tile_text_colors[value]
	if value > 2048 and current_theme.tile_text_colors.has(2048):
		return current_theme.tile_text_colors[2048]
	return current_theme.tile_text_colors.get(0, Color.WHITE)


func _apply_button_theme(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = current_theme.button_color
	var corner_radius := 8 if _is_promare_theme() else 14
	normal.corner_radius_top_left = corner_radius
	normal.corner_radius_top_right = corner_radius
	normal.corner_radius_bottom_left = corner_radius
	normal.corner_radius_bottom_right = corner_radius
	normal.content_margin_left = 16 if _is_promare_theme() else 14
	normal.content_margin_right = 16 if _is_promare_theme() else 14
	normal.content_margin_top = 11 if _is_promare_theme() else 10
	normal.content_margin_bottom = 11 if _is_promare_theme() else 10
	if _is_promare_theme():
		normal.border_width_left = 2
		normal.border_width_top = 2
		normal.border_width_right = 2
		normal.border_width_bottom = 2
		normal.border_color = current_theme.tile_border_color_128
		normal.shadow_size = 14
		normal.shadow_color = Color(
			current_theme.tile_border_color_256.r,
			current_theme.tile_border_color_256.g,
			current_theme.tile_border_color_256.b,
			0.22
		)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = current_theme.button_color.lightened(0.16 if _is_promare_theme() else 0.12)
	if _is_promare_theme():
		hover.border_color = current_theme.tile_border_color_fire
		hover.shadow_size = 18
		hover.shadow_color = Color(
			current_theme.tile_border_color_fire.r,
			current_theme.tile_border_color_fire.g,
			current_theme.tile_border_color_fire.b,
			0.28
		)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = current_theme.button_color.darkened(0.18 if _is_promare_theme() else 0.12)
	if _is_promare_theme():
		pressed.border_color = current_theme.tile_border_color_256
		pressed.shadow_size = 8

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = current_theme.button_color.darkened(0.28)
	disabled.shadow_size = 0
	if _is_promare_theme():
		disabled.border_color = Color(
			current_theme.tile_border_color_128.r,
			current_theme.tile_border_color_128.g,
			current_theme.tile_border_color_128.b,
			0.34
		)

	var focus := hover.duplicate() as StyleBoxFlat
	if _is_promare_theme():
		focus.border_width_left = 3
		focus.border_width_top = 3
		focus.border_width_right = 3
		focus.border_width_bottom = 3

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", current_theme.button_text_color)
	button.add_theme_color_override(
		"font_disabled_color",
		Color(
			current_theme.button_text_color.r,
			current_theme.button_text_color.g,
			current_theme.button_text_color.b,
			0.42 if _is_promare_theme() else 0.65
		)
	)


func _is_promare_theme() -> bool:
	return current_theme != null and str(current_theme.theme_id) == "promare"


func _update_self_play_button() -> void:
	self_play_button.text = "Stop Self-Play" if self_play_running else "Start Self-Play"


func _start_self_play() -> void:
	if not self_play_enabled or self_play_running:
		return
	self_play_running = true
	_update_self_play_button()
	_update_status("Self-play running. It will stop at 2048.")
	_schedule_self_play_step()


func _stop_self_play(message: String = "") -> void:
	self_play_running = false
	self_play_timer = null
	_update_self_play_button()
	if message != "":
		_update_status(message)


func _schedule_self_play_step() -> void:
	if not self_play_running:
		return
	self_play_timer = get_tree().create_timer(0.08)
	self_play_timer.timeout.connect(_run_self_play_step)


func _run_self_play_step() -> void:
	if not self_play_running:
		return
	if board_model.is_game_over(board):
		_stop_self_play("Self-play stopped: no moves left.")
		return

	var best_direction = self_play_agent.choose_best_direction(board_model, board)
	if best_direction == Vector2i.ZERO:
		_stop_self_play("Self-play stopped: no legal move.")
		return

	_try_move(best_direction)
	if self_play_running:
		_schedule_self_play_step()
