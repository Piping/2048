extends Control

const BOARD_MODEL_SCRIPT := preload("res://scripts/board_model.gd")
const SELF_PLAY_AGENT_SCRIPT := preload("res://scripts/self_play_agent.gd")
const GRID_SIZE := 4
const CELL_COUNT := GRID_SIZE * GRID_SIZE
const TARGET_VALUE := 2048
const SAVE_PATH := "user://save.cfg"
const SWIPE_THRESHOLD := 72.0
const MAX_UNDO_STEPS := 3
const HIGH_LEVEL_GLOW_THRESHOLD := 128
const FIRE_LEVEL_THRESHOLD := 512
const EXPLOSION_LEVEL_THRESHOLD := 64

const TILE_COLORS := {
	0: Color("cdc1b4"),
	2: Color("eee4da"),
	4: Color("ede0c8"),
	8: Color("f2b179"),
	16: Color("f59563"),
	32: Color("f67c5f"),
	64: Color("f65e3b"),
	128: Color("edcf72"),
	256: Color("edcc61"),
	512: Color("edc850"),
	1024: Color("edc53f"),
	2048: Color("edc22e")
}

const DARK_TEXT_VALUES := {
	0: true,
	2: true,
	4: true
}

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

@onready var score_label: Label = $SafeArea/VBox/Header/ScoreCard/ScoreBox/Value
@onready var best_label: Label = $SafeArea/VBox/Header/BestCard/BestBox/Value
@onready var status_label: Label = $SafeArea/VBox/Controls/Status
@onready var board_grid = $SafeArea/VBox/BoardFrame/BoardPadding/BoardCenter/BoardGrid
@onready var undo_button: Button = $SafeArea/VBox/Controls/UndoButton
@onready var new_game_button: Button = $SafeArea/VBox/Controls/NewGameButton
@onready var self_play_button: Button = $SafeArea/VBox/Controls/SelfPlayButton
@onready var safe_area: MarginContainer = $SafeArea
@onready var flash_overlay: ColorRect = $FlashOverlay
@onready var vfx_controller = $Effects
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


func _ready() -> void:
	rng.randomize()
	board_model = BOARD_MODEL_SCRIPT.new()
	board_view = board_grid
	self_play_agent = SELF_PLAY_AGENT_SCRIPT.new()
	_apply_display_safe_area()
	vfx_controller.configure(
		board_view,
		flash_overlay,
		Callable(self, "_font_size_for"),
		TILE_COLORS,
		DARK_TEXT_VALUES,
		HIGH_LEVEL_GLOW_THRESHOLD,
		FIRE_LEVEL_THRESHOLD,
		EXPLOSION_LEVEL_THRESHOLD
	)
	_apply_theme()
	_load_best_score()
	undo_button.pressed.connect(_on_undo_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	self_play_button.pressed.connect(_on_self_play_pressed)
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
	vfx_controller.play_move_feedback(board, [], last_spawned_index, [], combo_count)


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
	vfx_controller.play_move_feedback(board, move_animations_for_feedback, last_spawned_index, merged_indices_for_feedback, combo_count)

	if _should_play_screen_merge_feedback(last_top_merge_value):
		vfx_controller.play_screen_merge_feedback(last_top_merge_value, vfx_controller.highest_merge_tile(board, merged_indices_for_feedback))

	var current_max: int = board_model.max_value(board)
	if current_max > highest_announced_tile and _should_play_milestone_feedback(current_max):
		highest_announced_tile = current_max
		vfx_controller.play_milestone_feedback(current_max)
	elif current_max > highest_announced_tile:
		highest_announced_tile = current_max

	last_merged_indices.clear()
	last_move_animations.clear()

	if result["max_tile"] >= TARGET_VALUE and not has_won:
		has_won = true
		vfx_controller.play_celebration()
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
		style.bg_color = TILE_COLORS.get(value, Color("3c3a32"))
		style.corner_radius_top_left = 18
		style.corner_radius_top_right = 18
		style.corner_radius_bottom_right = 18
		style.corner_radius_bottom_left = 18
		if value >= FIRE_LEVEL_THRESHOLD:
			style.border_width_left = 4
			style.border_width_top = 4
			style.border_width_right = 4
			style.border_width_bottom = 4
			style.border_color = Color(1.0, 0.84, 0.25, 0.98)
		elif value >= 256:
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			style.border_color = Color(1.0, 0.90, 0.48, 0.90)
		elif value >= HIGH_LEVEL_GLOW_THRESHOLD:
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = Color(1.0, 0.96, 0.72, 0.72)

		panel.add_theme_stylebox_override("panel", style)
		label.text = "" if value == 0 else str(value)
		label.add_theme_color_override("font_color", Color("776e65") if DARK_TEXT_VALUES.has(value) else Color("f9f6f2"))
		label.add_theme_font_size_override("font_size", _font_size_for(value))
		panel.modulate = Color.WHITE
		panel.scale = Vector2.ONE
		panel.pivot_offset = panel.size * 0.5
		vfx_controller.apply_tile_overlay(i, value, panel)


func _apply_theme() -> void:
	var title := $SafeArea/VBox/Header/TitleColumn/Title as Label
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color("776e65"))

	var subtitle := $SafeArea/VBox/Header/TitleColumn/Subtitle as Label
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color("776e65"))

	var score_card := $SafeArea/VBox/Header/ScoreCard as PanelContainer
	var best_card := $SafeArea/VBox/Header/BestCard as PanelContainer
	score_card.add_theme_stylebox_override("panel", _card_style())
	best_card.add_theme_stylebox_override("panel", _card_style())

	var board_frame := $SafeArea/VBox/BoardFrame as PanelContainer
	board_frame.add_theme_stylebox_override("panel", _board_style())

	var help := $SafeArea/VBox/Help as Label
	help.add_theme_font_size_override("font_size", 18)
	help.add_theme_color_override("font_color", Color("776e65"))

	var controls_status := $SafeArea/VBox/Controls/Status as Label
	controls_status.add_theme_font_size_override("font_size", 20)
	controls_status.add_theme_color_override("font_color", Color("776e65"))

	var score_title := $SafeArea/VBox/Header/ScoreCard/ScoreBox/Label as Label
	var best_title := $SafeArea/VBox/Header/BestCard/BestBox/Label as Label
	for label in [score_title, best_title]:
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color("eee4da"))

	score_label.add_theme_font_size_override("font_size", 30)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	best_label.add_theme_font_size_override("font_size", 30)
	best_label.add_theme_color_override("font_color", Color.WHITE)

	new_game_button.add_theme_font_size_override("font_size", 22)
	undo_button.add_theme_font_size_override("font_size", 20)


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("bbada0")
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _board_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("bbada0")
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_right = 24
	style.corner_radius_bottom_left = 24
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
			vfx_controller.play_move_feedback(board, [], last_spawned_index, [], 0)
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
	vfx_controller.play_move_feedback(board, move_animations, spawned_index, merged_indices, debug_combo_count)
	if _should_play_screen_merge_feedback(top_merge_value):
		vfx_controller.play_screen_merge_feedback(top_merge_value, vfx_controller.highest_merge_tile(board, merged_indices))
	if play_milestone and _should_play_milestone_feedback(top_merge_value):
		vfx_controller.play_milestone_feedback(top_merge_value)
	if play_celebration_fx:
		vfx_controller.play_celebration()


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


func _sync_debug_feedback(message: String) -> void:
	if is_instance_valid(debug_panel):
		debug_panel.set_feedback(message)


func _update_status(message: String) -> void:
	status_label.text = message


func _load_best_score() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		best_score = int(config.get_value("stats", "best_score", 0))


func _save_best_score() -> void:
	var config := ConfigFile.new()
	config.set_value("stats", "best_score", best_score)
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
