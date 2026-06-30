extends GridContainer
class_name BoardView

const GRID_SIZE := 4
const CELL_COUNT := GRID_SIZE * GRID_SIZE

var tile_panels: Array[PanelContainer] = []
var tile_labels: Array[Label] = []
var tile_fx_layers: Array[ColorRect] = []
var tile_fx_sprites: Array[TextureRect] = []


func _ready() -> void:
	columns = GRID_SIZE
	_rebuild_tiles()


func _rebuild_tiles() -> void:
	for child in get_children():
		child.queue_free()

	tile_panels.clear()
	tile_labels.clear()
	tile_fx_layers.clear()
	tile_fx_sprites.clear()

	for index in CELL_COUNT:
		var tile = PanelContainer.new()
		tile.name = "Tile%d" % index
		tile.custom_minimum_size = Vector2(120, 120)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var fx_layer = ColorRect.new()
		fx_layer.visible = false
		fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx_layer.color = Color.WHITE
		fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		fx_layer.grow_horizontal = Control.GROW_DIRECTION_BOTH
		fx_layer.grow_vertical = Control.GROW_DIRECTION_BOTH
		fx_layer.z_index = 1
		tile.add_child(fx_layer)

		var label = Label.new()
		label.name = "Label"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(label)

		var fx_sprite = TextureRect.new()
		fx_sprite.visible = false
		fx_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fx_sprite.stretch_mode = TextureRect.STRETCH_SCALE
		fx_sprite.z_index = 2
		tile.add_child(fx_sprite)

		add_child(tile)
		tile_panels.append(tile)
		tile_labels.append(label)
		tile_fx_layers.append(fx_layer)
		tile_fx_sprites.append(fx_sprite)


func panel_at(index: int) -> PanelContainer:
	return tile_panels[index]


func label_at(index: int) -> Label:
	return tile_labels[index]


func fx_layer_at(index: int) -> ColorRect:
	return tile_fx_layers[index]


func fx_sprite_at(index: int) -> TextureRect:
	return tile_fx_sprites[index]
