extends CanvasLayer

signal preset_load_requested(preset_id: String)
signal preset_play_requested(preset_id: String)
signal reset_requested()

const PRESETS := [
	{
		"id": "spawn_pulse",
		"label": "Spawn Pulse",
		"description": "Quiet board with a fresh tile pulse. Use this to judge spawn readability without merge noise."
	},
	{
		"id": "merge_128",
		"label": "Merge 128",
		"description": "Single high-value merge with burst, board impact, and screen blast."
	},
	{
		"id": "merge_512",
		"label": "Merge 512",
		"description": "Inferno-tier merge that also triggers milestone feedback."
	},
	{
		"id": "combo_chain",
		"label": "Combo Chain",
		"description": "Multiple merges in one beat to evaluate overlap, readability, and combo callouts."
	},
	{
		"id": "celebration_2048",
		"label": "2048 Celebration",
		"description": "Full-stack win moment: merge burst, milestone sweep, banner, and celebration particles."
	}
]

@onready var toggle_button: Button = $ToggleButton
@onready var panel: PanelContainer = $Panel
@onready var preset_picker: OptionButton = $Panel/Margin/Layout/PresetPicker
@onready var description_label: Label = $Panel/Margin/Layout/Description
@onready var feedback_label: Label = $Panel/Margin/Layout/Feedback


func _ready() -> void:
	_populate_presets()
	toggle_button.pressed.connect(_on_toggle_pressed)
	preset_picker.item_selected.connect(_on_preset_selected)
	$Panel/Margin/Layout/Actions/LoadButton.pressed.connect(_on_load_pressed)
	$Panel/Margin/Layout/Actions/PlayButton.pressed.connect(_on_play_pressed)
	$Panel/Margin/Layout/Footer/ResetButton.pressed.connect(func() -> void:
		reset_requested.emit()
	)
	$Panel/Margin/Layout/Footer/CloseButton.pressed.connect(func() -> void:
		_set_panel_open(false)
	)
	_set_panel_open(false)
	_on_preset_selected(0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F8:
		_set_panel_open(not panel.visible)
		get_viewport().set_input_as_handled()


func set_feedback(message: String) -> void:
	feedback_label.text = message


func _populate_presets() -> void:
	preset_picker.clear()
	for preset in PRESETS:
		preset_picker.add_item(preset["label"])
		preset_picker.set_item_metadata(preset_picker.item_count - 1, preset["id"])


func _on_toggle_pressed() -> void:
	_set_panel_open(not panel.visible)


func _on_preset_selected(index: int) -> void:
	var preset: Dictionary = PRESETS[index]
	description_label.text = preset["description"]


func _on_load_pressed() -> void:
	preset_load_requested.emit(_selected_preset_id())


func _on_play_pressed() -> void:
	preset_play_requested.emit(_selected_preset_id())


func _selected_preset_id() -> String:
	return str(preset_picker.get_item_metadata(preset_picker.selected))


func _set_panel_open(is_open: bool) -> void:
	panel.visible = is_open
	toggle_button.text = "Hide VFX Debug" if is_open else "VFX Debug"
