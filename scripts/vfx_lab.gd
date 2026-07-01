extends Control

const PARTS_ROOT := "res://assets/vfx_750"
const ATLAS_CELL_SIZE := 64

const PART_NOTES := {
	"Part 1": "Ring-like magic pulse atlas",
	"Part 2": "Compact low flame atlas",
	"Part 3": "Dense impact/burst atlas",
	"Part 4": "Round radial burst atlas",
	"Part 5": "Soft plume/smoke burst atlas",
	"Part 6": "Split flame tongues atlas",
	"Part 7": "Low floor-fire atlas",
	"Part 8": "Fast slash burst atlas",
	"Part 9": "Arc/flash burst atlas",
	"Part 10": "Ignition ring atlas",
	"Part 11": "Tall vertical flame atlas",
	"Part 12": "Heavy ember burst atlas",
	"Part 13": "Compact hot pulse atlas",
	"Part 14": "Wide energy bloom atlas",
	"Part 15": "Long sweep/ribbon atlas"
}

@onready var effect_picker: OptionButton = $SafeArea/Layout/Sidebar/EffectPicker
@onready var part_picker: OptionButton = $SafeArea/Layout/Sidebar/PartPicker
@onready var row_picker: OptionButton = $SafeArea/Layout/Sidebar/RowPicker
@onready var play_button: Button = $SafeArea/Layout/Sidebar/Playback/PlayButton
@onready var loop_toggle: CheckButton = $SafeArea/Layout/Sidebar/Playback/LoopToggle
@onready var fps_slider: HSlider = $SafeArea/Layout/Sidebar/FpsSlider
@onready var fps_value: Label = $SafeArea/Layout/Sidebar/FpsValue
@onready var scale_slider: HSlider = $SafeArea/Layout/Sidebar/ScaleSlider
@onready var scale_value: Label = $SafeArea/Layout/Sidebar/ScaleValue
@onready var desc_label: Label = $SafeArea/Layout/Sidebar/Description
@onready var atlas_info: Label = $SafeArea/Layout/Sidebar/AtlasInfo
@onready var preview_tile: PanelContainer = $SafeArea/Layout/Stage/StagePad/StageInner/TileWrap/Tile
@onready var preview_sprite: TextureRect = $SafeArea/Layout/Stage/StagePad/StageInner/TileWrap/Tile/EffectSprite
@onready var stage_label: Label = $SafeArea/Layout/Stage/StageHeader/Selection
@onready var mode_picker: OptionButton = $SafeArea/Layout/Stage/StageHeader/ModePicker
@onready var tile_wrap: Control = $SafeArea/Layout/Stage/StagePad/StageInner/TileWrap
@onready var gallery_scroll: ScrollContainer = $SafeArea/Layout/Stage/StagePad/StageInner/GalleryScroll
@onready var gallery_grid: GridContainer = $SafeArea/Layout/Stage/StagePad/StageInner/GalleryScroll/GalleryGrid

var effects: Array[Dictionary] = []
var selected_effect := 0
var selected_row := 0
var playing := true
var time_accumulator := 0.0
var atlas_frames: Array[Texture2D] = []
var gallery_mode := true
var gallery_previews: Array[Dictionary] = []


func _ready() -> void:
	_collect_effects()
	_populate_parts()
	_populate_effects()
	_populate_rows(_current_effect()["rows"])
	_populate_modes()
	part_picker.item_selected.connect(_on_part_selected)
	effect_picker.item_selected.connect(_on_effect_selected)
	row_picker.item_selected.connect(_on_row_selected)
	mode_picker.item_selected.connect(_on_mode_selected)
	play_button.pressed.connect(_on_play_pressed)
	loop_toggle.button_pressed = true
	fps_slider.value_changed.connect(_on_fps_changed)
	scale_slider.value_changed.connect(_on_scale_changed)
	preview_tile.clip_contents = true
	preview_tile.pivot_offset = preview_tile.size * 0.5
	preview_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_sprite.material = _additive_material()
	mode_picker.select(1)
	_on_fps_changed(fps_slider.value)
	_on_scale_changed(scale_slider.value)
	_load_selected_effect()
	_refresh_mode()


func _process(delta: float) -> void:
	var fps: float = maxf(1.0, float(fps_slider.value))
	time_accumulator += delta
	if not atlas_frames.is_empty():
		var frame_count: int = atlas_frames.size()
		var frame := int(floor(time_accumulator * fps))
		if loop_toggle.button_pressed:
			frame %= frame_count
		else:
			frame = min(frame, frame_count - 1)
		if playing:
			preview_sprite.texture = atlas_frames[frame]
	if gallery_mode:
		_update_gallery_animation()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_UP:
			_step_effect(-1)
			accept_event()
		KEY_DOWN:
			_step_effect(1)
			accept_event()
		KEY_LEFT:
			_step_row(-1)
			accept_event()
		KEY_RIGHT:
			_step_row(1)
			accept_event()


func _populate_effects() -> void:
	effect_picker.clear()
	for effect in effects:
		effect_picker.add_item(effect["label"])


func _populate_parts() -> void:
	part_picker.clear()
	var seen_parts: Array[String] = []
	for effect in effects:
		var part_name: String = effect["part"]
		if seen_parts.has(part_name):
			continue
		seen_parts.append(part_name)
		part_picker.add_item(part_name)


func _populate_rows(row_count: int) -> void:
	row_picker.clear()
	for row in row_count:
		row_picker.add_item("Color %d" % (row + 1))
	row_picker.select(min(selected_row, max(row_count - 1, 0)))


func _populate_modes() -> void:
	mode_picker.clear()
	mode_picker.add_item("Single")
	mode_picker.add_item("Gallery")
	mode_picker.select(1)


func _load_selected_effect() -> void:
	var effect := _current_effect()
	atlas_frames = _load_atlas_frames_from_resource(effect, selected_row)
	time_accumulator = 0.0
	preview_sprite.texture = atlas_frames[0] if not atlas_frames.is_empty() else null
	desc_label.text = effect["desc"]
	stage_label.text = "%s  %s" % [effect["part"], effect["label"]]
	atlas_info.text = "%dx%d  rows %d  cols %d  row %d  frames %d" % [
		effect["width"],
		effect["height"],
		effect["rows"],
		effect["cols"],
		selected_row + 1,
		atlas_frames.size()
	]
	if gallery_mode:
		_refresh_gallery()


func _current_effect() -> Dictionary:
	return effects[selected_effect]


func _on_part_selected(index: int) -> void:
	var target_part: String = part_picker.get_item_text(index)
	for effect_index in effects.size():
		if effects[effect_index]["part"] == target_part:
			selected_effect = effect_index
			effect_picker.select(effect_index)
			selected_row = 0
			_populate_rows(_current_effect()["rows"])
			_load_selected_effect()
			return


func _on_effect_selected(index: int) -> void:
	selected_effect = index
	selected_row = 0
	_sync_part_picker(_current_effect()["part"])
	_populate_rows(_current_effect()["rows"])
	_load_selected_effect()


func _on_row_selected(index: int) -> void:
	selected_row = index
	_load_selected_effect()


func _on_mode_selected(index: int) -> void:
	gallery_mode = index == 1
	_refresh_mode()


func _step_effect(delta: int) -> void:
	if effects.is_empty():
		return
	selected_effect = posmod(selected_effect + delta, effects.size())
	effect_picker.select(selected_effect)
	_sync_part_picker(_current_effect()["part"])
	selected_row = min(selected_row, max(int(_current_effect()["rows"]) - 1, 0))
	_populate_rows(_current_effect()["rows"])
	_load_selected_effect()


func _step_row(delta: int) -> void:
	var row_count := int(_current_effect()["rows"])
	if row_count <= 0:
		return
	selected_row = posmod(selected_row + delta, row_count)
	row_picker.select(selected_row)
	_load_selected_effect()


func _on_play_pressed() -> void:
	playing = not playing
	play_button.text = "Pause" if playing else "Play"


func _on_fps_changed(value: float) -> void:
	fps_value.text = "%d fps" % int(round(value))
	if gallery_mode:
		_refresh_gallery()


func _on_scale_changed(value: float) -> void:
	scale_value.text = "%.2fx" % value
	var size := Vector2(180, 180) * value
	preview_sprite.size = size
	preview_sprite.position = preview_tile.size * 0.5 - size * 0.5
	if gallery_mode:
		_refresh_gallery()


func _load_atlas_frames_from_resource(effect: Dictionary, row: int) -> Array[Texture2D]:
	var source_texture := load(str(effect["path"])) as Texture2D
	if source_texture == null:
		return []
	var image := source_texture.get_image()
	if image == null:
		return []

	var cell_width := int(effect["cell_width"])
	var cell_height := int(effect["cell_height"])
	var textures: Array[Texture2D] = []
	for column in int(effect["cols"]):
		var frame := Image.create(cell_width, cell_height, false, image.get_format())
		frame.blit_rect(
			image,
			Rect2i(column * cell_width, row * cell_height, cell_width, cell_height),
			Vector2i.ZERO
		)
		textures.append(ImageTexture.create_from_image(frame))
	return textures


func _additive_material() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


func _refresh_mode() -> void:
	tile_wrap.visible = not gallery_mode
	gallery_scroll.visible = gallery_mode
	play_button.disabled = false
	if gallery_mode:
		stage_label.text = "All Parts Gallery"
		_refresh_gallery()
	else:
		stage_label.text = "%s  %s" % [_current_effect()["part"], _current_effect()["label"]]


func _refresh_gallery() -> void:
	for child in gallery_grid.get_children():
		child.queue_free()
	gallery_previews.clear()
	var scale := float(scale_slider.value)
	for effect in effects:
		gallery_grid.add_child(_build_gallery_card(effect, scale))
	_update_gallery_animation()


func _build_gallery_card(effect: Dictionary, scale: float) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(148, 176)
	card.add_theme_constant_override("separation", 8)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(148, 136)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.15, 0.16, 0.20, 1.0)
	frame_style.corner_radius_top_left = 8
	frame_style.corner_radius_top_right = 8
	frame_style.corner_radius_bottom_left = 8
	frame_style.corner_radius_bottom_right = 8
	frame.add_theme_stylebox_override("panel", frame_style)
	card.add_child(frame)

	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(104, 104)
	tile.size = Vector2(104, 104)
	tile.position = Vector2(22, 16)
	tile.clip_contents = true
	var tile_style := StyleBoxFlat.new()
	tile_style.bg_color = Color("edcc61")
	tile_style.corner_radius_top_left = 16
	tile_style.corner_radius_top_right = 16
	tile_style.corner_radius_bottom_left = 16
	tile_style.corner_radius_bottom_right = 16
	frame.add_child(tile)
	tile.add_theme_stylebox_override("panel", tile_style)

	var sprite := TextureRect.new()
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.material = _additive_material()
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var size := Vector2(96, 96) * scale
		sprite.size = size
		sprite.position = tile.size * 0.5 - size * 0.5
		var frames := _load_atlas_frames_from_resource(effect, selected_row)
		if not frames.is_empty():
			sprite.texture = frames[0]
		tile.add_child(sprite)
	gallery_previews.append({"sprite": sprite, "frames": frames})

	var id_label := Label.new()
	id_label.text = "%s / %s / row %d" % [effect["part"], effect["label"], selected_row + 1]
	id_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	id_label.add_theme_font_size_override("font_size", 14)
	card.add_child(id_label)
	return card


func _collect_effects() -> void:
	effects.clear()
	var part_dirs := DirAccess.get_directories_at(PARTS_ROOT)
	part_dirs.sort()
	for part_dir in part_dirs:
		var part_number := _parse_part_number(part_dir)
		if part_number < 0:
			continue
		var part_name := "Part %d" % part_number
		var part_path := "%s/%s" % [PARTS_ROOT, part_dir]
		var files := DirAccess.get_files_at(part_path)
		files.sort()
		for file_name in files:
			if not file_name.ends_with(".png"):
				continue
			var full_path := "%s/%s" % [part_path, file_name]
			var source_texture := load(full_path) as Texture2D
			if source_texture == null:
				continue
			var image := source_texture.get_image()
			if image == null:
				continue
			if image.get_width() % ATLAS_CELL_SIZE != 0 or image.get_height() % ATLAS_CELL_SIZE != 0:
				continue
			var rows := image.get_height() / ATLAS_CELL_SIZE
			var cols := image.get_width() / ATLAS_CELL_SIZE
			effects.append({
				"part": part_name,
				"label": file_name.get_basename(),
				"desc": PART_NOTES.get(part_name, "Sprite atlas effect"),
				"path": full_path,
				"width": image.get_width(),
				"height": image.get_height(),
				"rows": rows,
				"cols": cols,
				"cell_width": ATLAS_CELL_SIZE,
				"cell_height": ATLAS_CELL_SIZE
			})
	if effects.is_empty():
		push_error("No VFX atlas PNGs found under repo path %s" % PARTS_ROOT)


func _parse_part_number(part_dir: String) -> int:
	if not part_dir.begins_with("part"):
		return -1
	return int(part_dir.trim_prefix("part"))


func _sync_part_picker(target_part: String) -> void:
	for index in part_picker.item_count:
		if part_picker.get_item_text(index) == target_part:
			part_picker.select(index)
			return


func _update_gallery_animation() -> void:
	if gallery_previews.is_empty():
		return
	var fps: float = maxf(1.0, float(fps_slider.value))
	for preview in gallery_previews:
		var frames: Array = preview["frames"]
		if frames.is_empty():
			continue
		var frame_count: int = frames.size()
		var frame := int(floor(time_accumulator * fps))
		if loop_toggle.button_pressed:
			frame %= frame_count
		else:
			frame = min(frame, frame_count - 1)
		var sprite: TextureRect = preview["sprite"]
		sprite.texture = frames[frame]
