extends CanvasLayer
class_name VfxController

const TILE_FIRE_SHADER := preload("res://assets/shaders/tile_fire.gdshader")
const EXPLOSION_WAVE_SHADER := preload("res://assets/shaders/explosion_wave.gdshader")
const SCREEN_FRACTURE_SHADER := preload("res://assets/shaders/screen_fracture.gdshader")
const VFX_TILE_FIRE_DIR := "res://assets/vfx_pack/Effect_DitheredFire_1"
const VFX_TILE_INFERNO_DIR := "res://assets/vfx_pack/Effect_FastPixelFire_1"
const VFX_IMPACT_DIR := "res://assets/vfx_pack/Effect_Impact_1"
const VFX_EXPLOSION_DIR := "res://assets/vfx_pack/Effect_Explosion2_1"

@onready var screen_fx: ColorRect = $ScreenFX
@onready var screen_fx_secondary: ColorRect = $ScreenFXSecondary
@onready var impact_flash: ColorRect = $ImpactFlash
@onready var animation_overlay: Control = $AnimationOverlay
@onready var celebration_particles: CPUParticles2D = $Celebration

var board_view
var flash_overlay: ColorRect
var font_size_callback: Callable
var tile_colors: Dictionary = {}
var dark_text_values: Dictionary = {}
var high_level_glow_threshold := 128
var fire_level_threshold := 512
var explosion_level_threshold := 64
var tile_vfx_time := 0.0
var tile_fire_frames: Array[Texture2D] = []
var tile_inferno_frames: Array[Texture2D] = []
var impact_frames: Array[Texture2D] = []
var explosion_frames: Array[Texture2D] = []


func _ready() -> void:
	tile_fire_frames = _load_sequence_frames(VFX_TILE_FIRE_DIR)
	tile_inferno_frames = _load_sequence_frames(VFX_TILE_INFERNO_DIR)
	impact_frames = _load_sequence_frames(VFX_IMPACT_DIR)
	explosion_frames = _load_sequence_frames(VFX_EXPLOSION_DIR)


func configure(
	board_view_node,
	flash_overlay_node: ColorRect,
	font_size_func: Callable,
	colors: Dictionary,
	dark_values: Dictionary,
	high_level_glow: int,
	fire_level: int,
	explosion_level: int
) -> void:
	board_view = board_view_node
	flash_overlay = flash_overlay_node
	font_size_callback = font_size_func
	tile_colors = colors
	dark_text_values = dark_values
	high_level_glow_threshold = high_level_glow
	fire_level_threshold = fire_level
	explosion_level_threshold = explosion_level


func apply_tile_overlay(index: int, value: int, panel: PanelContainer) -> void:
	var fx_layer: ColorRect = board_view.fx_layer_at(index)
	var fx_sprite: TextureRect = board_view.fx_sprite_at(index)
	fx_layer.visible = false
	fx_layer.material = null
	fx_sprite.visible = false
	fx_sprite.texture = null
	fx_sprite.self_modulate = Color.WHITE
	fx_sprite.scale = Vector2.ONE
	fx_sprite.position = Vector2.ZERO
	fx_sprite.pivot_offset = Vector2.ZERO

	if value < high_level_glow_threshold:
		return

	var fire_material := ShaderMaterial.new()
	fire_material.shader = TILE_FIRE_SHADER
	var fire_intensity := 0.10 if value < 256 else (0.18 if value < fire_level_threshold else 0.32)
	var fire_tier := 1.0 if value < 256 else (2.0 if value < fire_level_threshold else 3.0)
	fire_material.set_shader_parameter("intensity", fire_intensity)
	fire_material.set_shader_parameter("tier", fire_tier)
	fire_material.set_shader_parameter(
		"glow_color",
		Color(1.0, 0.90, 0.44, 1.0) if value < 256 else (Color(1.0, 0.56, 0.08, 1.0) if value < fire_level_threshold else Color(1.0, 0.14, 0.02, 1.0))
	)
	fire_material.set_shader_parameter(
		"core_color",
		Color(1.0, 0.96, 0.78, 1.0) if value < 256 else (Color(1.0, 0.94, 0.44, 1.0) if value < fire_level_threshold else Color(1.0, 0.86, 0.22, 1.0))
	)
	fx_layer.visible = true
	fx_layer.color = Color.WHITE
	fx_layer.material = fire_material
	if value < 256:
		return

	fx_sprite.visible = true
	fx_sprite.material = _additive_material()
	if value < fire_level_threshold:
		fx_sprite.self_modulate = Color(1, 1, 1, 0.38)
		fx_sprite.size = Vector2(panel.size.x * 1.04, panel.size.y * 0.42)
		fx_sprite.position = Vector2(panel.size.x * -0.02, panel.size.y * 0.60)
	else:
		fx_sprite.self_modulate = Color(1, 1, 1, 0.56)
		fx_sprite.size = Vector2(panel.size.x * 1.16, panel.size.y * 0.62)
		fx_sprite.position = Vector2(panel.size.x * -0.08, panel.size.y * 0.42)


func advance(delta: float, board: Array[int]) -> void:
	tile_vfx_time += delta
	for index in board.size():
		var sprite: TextureRect = board_view.fx_sprite_at(index)
		if not is_instance_valid(sprite) or not sprite.visible:
			continue
		var value := board[index]
		var frames := tile_fire_frames if value < fire_level_threshold else tile_inferno_frames
		if frames.is_empty():
			continue
		var frame_index := int(floor(tile_vfx_time * 14.0)) % frames.size()
		sprite.texture = frames[frame_index]


func play_refresh_feedback(board: Array[int], move_animations: Array[Dictionary], spawned_index: int, merged_indices: Array[int]) -> void:
	for child in animation_overlay.get_children():
		child.queue_free()
	_play_move_animations(move_animations)
	if spawned_index >= 0 and spawned_index < board.size():
		_pulse_tile(board_view.panel_at(spawned_index), Vector2(1.14, 1.14), 0.14)
	for tile_index in merged_indices:
		if tile_index >= 0 and tile_index < board.size():
			_pulse_tile(board_view.panel_at(tile_index), Vector2(1.22, 1.22), 0.18)
			if board[tile_index] >= explosion_level_threshold:
				_spawn_merge_burst(tile_index, board[tile_index])


func play_celebration() -> void:
	flash_overlay.visible = true
	flash_overlay.color = Color(1, 0.68, 0.2, 0.0)
	var flash_tween: Tween = create_tween()
	flash_tween.set_trans(Tween.TRANS_SINE)
	flash_tween.tween_property(flash_overlay, "color", Color(1, 0.68, 0.2, 0.7), 0.12)
	flash_tween.tween_property(flash_overlay, "color", Color(1, 0.2, 0.05, 0.0), 0.4)
	flash_tween.finished.connect(func() -> void:
		flash_overlay.visible = false
	)

	var viewport_size := get_viewport().get_visible_rect().size
	celebration_particles.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.32)
	celebration_particles.color = Color(1.0, 0.78, 0.24, 1.0)
	celebration_particles.visible = true
	celebration_particles.restart()
	celebration_particles.emitting = true


func highest_merge_tile(board: Array[int], merged_indices: Array[int]) -> int:
	var best_index := -1
	var best_value := -1
	for tile_index in merged_indices:
		if tile_index >= 0 and tile_index < board.size() and board[tile_index] > best_value:
			best_value = board[tile_index]
			best_index = tile_index
	return max(best_index, 0)


func play_screen_merge_feedback(top_merge_value: int, focus_tile_index: int) -> void:
	if top_merge_value < high_level_glow_threshold:
		return
	var center_uv := _screen_uv_for_tile(focus_tile_index)
	_play_screen_blast(top_merge_value, center_uv)
	if top_merge_value >= 256:
		_play_screen_fracture(top_merge_value, center_uv)


func _pulse_tile(tile: PanelContainer, peak_scale: Vector2, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "scale", peak_scale, duration * 0.45)
	tween.tween_property(tile, "scale", Vector2.ONE, duration * 0.55)


func _play_move_animations(move_animations: Array[Dictionary]) -> void:
	if move_animations.is_empty():
		return

	for animation in move_animations:
		var from_index := int(animation["from"])
		var to_index := int(animation["to"])
		var value := int(animation["value"])
		if from_index == to_index:
			continue

		var from_panel: PanelContainer = board_view.panel_at(from_index)
		var to_panel: PanelContainer = board_view.panel_at(to_index)
		var ghost := PanelContainer.new()
		ghost.custom_minimum_size = from_panel.size
		ghost.size = from_panel.size
		ghost.position = from_panel.global_position - animation_overlay.global_position
		ghost.pivot_offset = ghost.size * 0.5
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ghost_style := StyleBoxFlat.new()
		ghost_style.bg_color = tile_colors.get(value, Color("3c3a32"))
		ghost_style.corner_radius_top_left = 18
		ghost_style.corner_radius_top_right = 18
		ghost_style.corner_radius_bottom_right = 18
		ghost_style.corner_radius_bottom_left = 18
		if value >= fire_level_threshold:
			ghost_style.shadow_color = Color(1.0, 0.36, 0.08, 0.85)
			ghost_style.shadow_size = 22
		elif value >= high_level_glow_threshold:
			ghost_style.shadow_color = Color(1.0, 0.82, 0.22, 0.55)
			ghost_style.shadow_size = 14
		ghost.add_theme_stylebox_override("panel", ghost_style)

		var ghost_label := Label.new()
		ghost_label.text = str(value)
		ghost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ghost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ghost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ghost_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ghost_label.add_theme_font_size_override("font_size", int(font_size_callback.call(value)))
		ghost_label.add_theme_color_override("font_color", Color("776e65") if dark_text_values.has(value) else Color("f9f6f2"))
		ghost.add_child(ghost_label)
		animation_overlay.add_child(ghost)

		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(
			ghost,
			"position",
			to_panel.global_position - animation_overlay.global_position,
			0.12
		)
		tween.tween_property(ghost, "modulate:a", 0.15, 0.12)
		tween.finished.connect(_queue_free_if_valid.bind(ghost))


func _spawn_merge_burst(tile_index: int, value: int) -> void:
	var tile: PanelContainer = board_view.panel_at(tile_index)
	var center := tile.global_position - animation_overlay.global_position + tile.size * 0.5
	_play_sequence(effect_frames_for_value(value), center, tile.size * (2.0 if value < fire_level_threshold else 2.6), 30.0, true, 0.95 if value < fire_level_threshold else 1.0)
	if value >= 128:
		_play_sequence(impact_frames, center, tile.size * 1.9, 30.0, false, 1.0)

	var shockwave := ColorRect.new()
	shockwave.color = Color.WHITE
	shockwave.size = tile.size * 3.2
	shockwave.position = center - shockwave.size * 0.5
	shockwave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shockwave_material := ShaderMaterial.new()
	shockwave_material.shader = EXPLOSION_WAVE_SHADER
	shockwave_material.set_shader_parameter("center_uv", Vector2(0.5, 0.5))
	shockwave_material.set_shader_parameter(
		"core_color",
		Color(1.0, 0.98, 0.72, 1.0) if value < fire_level_threshold else Color(1.0, 0.82, 0.22, 1.0)
	)
	shockwave_material.set_shader_parameter(
		"outer_color",
		Color(1.0, 0.52, 0.10, 1.0) if value < fire_level_threshold else Color(1.0, 0.18, 0.03, 1.0)
	)
	shockwave.material = shockwave_material
	animation_overlay.add_child(shockwave)
	var shockwave_tween: Tween = create_tween()
	shockwave_tween.tween_method(_set_shader_progress.bind(shockwave_material), 0.0, 1.0, 0.50)
	shockwave_tween.finished.connect(_queue_free_if_valid.bind(shockwave))

	if value >= 256:
		_play_impact_flash(value)


func effect_frames_for_value(value: int) -> Array[Texture2D]:
	return impact_frames if value < fire_level_threshold else explosion_frames


func _play_sequence(frames: Array[Texture2D], center: Vector2, size: Vector2, fps: float, additive: bool, alpha: float = 1.0) -> void:
	if frames.is_empty():
		return
	var sprite := TextureRect.new()
	sprite.texture = frames[0]
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.size = size
	sprite.position = center - size * 0.5
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.self_modulate = Color(1, 1, 1, alpha)
	if additive:
		sprite.material = _additive_material()
	animation_overlay.add_child(sprite)
	_animate_sequence(sprite, frames, fps)


func _animate_sequence(target: TextureRect, frames: Array[Texture2D], fps: float) -> void:
	if frames.is_empty():
		_queue_free_if_valid(target)
		return
	var index := 0
	while is_instance_valid(target) and index < frames.size():
		target.texture = frames[index]
		index += 1
		if index >= frames.size():
			break
		await get_tree().create_timer(1.0 / fps).timeout
	_queue_free_if_valid(target)


func _queue_free_if_valid(node: Variant) -> void:
	if is_instance_valid(node):
		node.queue_free()


func _additive_material() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


func _set_shader_progress(progress: float, material: Variant) -> void:
	if is_instance_valid(material):
		material.set_shader_parameter("progress", progress)


func _play_screen_blast(value: int, center_uv: Vector2) -> void:
	screen_fx.visible = true
	screen_fx.color = Color.WHITE
	var material := ShaderMaterial.new()
	material.shader = EXPLOSION_WAVE_SHADER
	var clamped_center := center_uv.clamp(Vector2(0.08, 0.08), Vector2(0.92, 0.92))
	material.set_shader_parameter("center_uv", clamped_center)
	material.set_shader_parameter(
		"core_color",
		Color(1.0, 0.95, 0.65, 1.0) if value < fire_level_threshold else Color(1.0, 0.82, 0.28, 1.0)
	)
	material.set_shader_parameter(
		"outer_color",
		Color(1.0, 0.62, 0.14, 1.0) if value < fire_level_threshold else Color(1.0, 0.28, 0.05, 1.0)
	)
	screen_fx.material = material
	screen_fx_secondary.visible = true
	screen_fx_secondary.color = Color(1.0, 0.84, 0.42, 0.0) if value < fire_level_threshold else Color(1.0, 0.42, 0.10, 0.0)
	screen_fx_secondary.material = null
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_parallel(true)
	tween.tween_method(_set_shader_progress.bind(material), 0.0, 1.0, 1.5)
	tween.tween_property(
		screen_fx_secondary,
		"color",
		Color(1.0, 0.96, 0.75, 0.18) if value < fire_level_threshold else Color(1.0, 0.58, 0.16, 0.24),
		0.12
	)
	tween.tween_property(
		screen_fx_secondary,
		"color",
		Color(1.0, 0.12, 0.04, 0.0),
		1.38
	)
	tween.finished.connect(func() -> void:
		screen_fx.visible = false
		screen_fx.material = null
		screen_fx_secondary.visible = false
		screen_fx_secondary.material = null
	)


func _play_screen_fracture(value: int, center_uv: Vector2) -> void:
	screen_fx_secondary.visible = true
	screen_fx_secondary.color = Color.WHITE
	var material := ShaderMaterial.new()
	material.shader = SCREEN_FRACTURE_SHADER
	material.set_shader_parameter("intensity", 1.22 if value < fire_level_threshold else 1.75)
	var clamped_center := center_uv.clamp(Vector2(0.08, 0.08), Vector2(0.92, 0.92))
	material.set_shader_parameter("center_uv", clamped_center)
	material.set_shader_parameter(
		"tint_color",
		Color(1.0, 0.82, 0.36, 1.0) if value < fire_level_threshold else Color(1.0, 0.46, 0.12, 1.0)
	)
	screen_fx_secondary.material = material
	var tween: Tween = create_tween()
	tween.tween_method(_set_shader_progress.bind(material), 0.0, 1.0, 1.5)
	tween.finished.connect(func() -> void:
		screen_fx_secondary.visible = false
		screen_fx_secondary.material = null
	)


func _play_impact_flash(value: int) -> void:
	impact_flash.visible = true
	impact_flash.material = null
	impact_flash.color = Color(1.0, 0.98, 0.94, 0.0) if value < fire_level_threshold else Color(1.0, 0.82, 0.54, 0.0)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(
		impact_flash,
		"color",
		Color(1.0, 0.98, 0.94, 0.24) if value < fire_level_threshold else Color(1.0, 0.82, 0.54, 0.30),
		0.04
	)
	tween.tween_property(impact_flash, "color", Color(1.0, 0.2, 0.06, 0.0), 0.18)
	tween.finished.connect(func() -> void:
		impact_flash.visible = false
	)


func _screen_uv_for_tile(tile_index: int) -> Vector2:
	if tile_index < 0:
		return Vector2(0.5, 0.5)
	var tile: PanelContainer = board_view.panel_at(tile_index)
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(0.5, 0.5)
	var center := tile.global_position + tile.size * 0.5
	return Vector2(center.x / viewport_size.x, center.y / viewport_size.y)


func _load_sequence_frames(directory: String) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	var files := DirAccess.get_files_at(directory)
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".png"):
			continue
		var image := Image.new()
		var image_path := ProjectSettings.globalize_path("%s/%s" % [directory, file_name])
		if image.load(image_path) == OK:
			textures.append(ImageTexture.create_from_image(image))
	return textures
