extends CanvasLayer
class_name VfxController

const TILE_FIRE_SHADER := preload("res://assets/shaders/tile_fire.gdshader")
const EXPLOSION_WAVE_SHADER := preload("res://assets/shaders/explosion_wave.gdshader")
const SCREEN_FRACTURE_SHADER := preload("res://assets/shaders/screen_fracture.gdshader")
const VFX_128_BURST_PATH := "res://assets/vfx_750/part1/16.png"
const VFX_IMPACT_DIR := "res://assets/vfx_pack/Effect_Impact_1"
const VFX_EXPLOSION_DIR := "res://assets/vfx_pack/Effect_Explosion2_1"
const HIGH_TIER_OVERLAY_PATHS := {
	1024: "res://assets/vfx_750/part1/23.png",
	2048: "res://assets/vfx_750/part1/24.png",
	4096: "res://assets/vfx_750/part1/25.png",
	8192: "res://assets/vfx_750/part1/26.png"
}

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
var high_tier_overlay_frames: Dictionary = {}
var tile_128_burst_frames: Array[Texture2D] = []
var impact_frames: Array[Texture2D] = []
var explosion_frames: Array[Texture2D] = []
var milestone_banner_active := false


func _ready() -> void:
	visible = true
	# Runtime VFX are spawned under AnimationOverlay; keep it visible even if the
	# scene file gets an accidental hidden flag.
	animation_overlay.visible = true
	# 750-Free tile VFX files are sprite atlases, not one-frame-per-file sequences.
	tile_128_burst_frames = _load_atlas_frames_from_file(VFX_128_BURST_PATH, Vector2i(14, 9), 0)
	for value in HIGH_TIER_OVERLAY_PATHS.keys():
		high_tier_overlay_frames[value] = _load_atlas_frames_from_file(HIGH_TIER_OVERLAY_PATHS[value], Vector2i(14, 9), 0)
	impact_frames = _load_sequence_frames(VFX_IMPACT_DIR)
	explosion_frames = _load_sequence_frames(VFX_EXPLOSION_DIR)
	print(
		"[vfx_controller] burst=%d overlay1024=%d overlay2048=%d overlay4096=%d overlay8192=%d impact=%d explosion=%d" % [
			tile_128_burst_frames.size(),
			_overlay_frames_for_value(1024).size(),
			_overlay_frames_for_value(2048).size(),
			_overlay_frames_for_value(4096).size(),
			_overlay_frames_for_value(8192).size(),
			impact_frames.size(),
			explosion_frames.size()
		]
	)


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


func reset_debug_state() -> void:
	tile_vfx_time = 0.0
	milestone_banner_active = false
	screen_fx.visible = false
	screen_fx.material = null
	screen_fx_secondary.visible = false
	screen_fx_secondary.material = null
	impact_flash.visible = false
	impact_flash.material = null
	impact_flash.color = Color(1, 1, 1, 0)
	celebration_particles.visible = false
	celebration_particles.emitting = false
	for child in animation_overlay.get_children():
		child.queue_free()


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
	_sync_tile_fire_material(panel, fire_material)
	# Keep the shader as the long-lived state and reserve sprite overlays for the
	# very top tier only; the sprite reads poorly on 512-sized milestones.
	if value < 1024:
		return

	fx_sprite.visible = true
	fx_sprite.material = _additive_material()
	fx_sprite.self_modulate = Color(1, 1, 1, 0.42)
	_layout_tile_sprite(fx_sprite, panel)


func advance(delta: float, board: Array[int]) -> void:
	tile_vfx_time += delta
	for index in board.size():
		var panel: PanelContainer = board_view.panel_at(index)
		var fx_layer: ColorRect = board_view.fx_layer_at(index)
		if is_instance_valid(fx_layer) and fx_layer.visible:
			_sync_tile_fire_material(panel, fx_layer.material as ShaderMaterial)
		var sprite: TextureRect = board_view.fx_sprite_at(index)
		if not is_instance_valid(sprite) or not sprite.visible:
			continue
		_layout_tile_sprite(sprite, panel)
		var frames := _overlay_frames_for_value(board[index])
		if frames.is_empty():
			continue
		var frame_index := int(floor(tile_vfx_time * 14.0)) % frames.size()
		sprite.texture = frames[frame_index]


func play_move_feedback(board: Array[int], move_animations: Array, spawned_index: int, merged_indices: Array, combo_count: int) -> void:
	for child in animation_overlay.get_children():
		child.queue_free()
	_play_move_animations(move_animations)
	if spawned_index >= 0 and spawned_index < board.size():
		_pulse_tile(board_view.panel_at(spawned_index), Vector2(1.14, 1.14), 0.14)
	for tile_index in merged_indices:
		if tile_index >= 0 and tile_index < board.size():
			_pulse_tile(board_view.panel_at(tile_index), Vector2(1.22, 1.22), 0.18)
			if board[tile_index] == 128:
				_play_tile_atlas_once(tile_128_burst_frames, tile_index, 22.0, Vector2(1.28, 1.28), Vector2(0.0, 0.0), 0.92)
			if board[tile_index] >= explosion_level_threshold:
				_spawn_merge_burst(tile_index, board[tile_index])
	if not merged_indices.is_empty():
		_play_board_impact(board, merged_indices)
	if combo_count >= 2:
		_play_combo_feedback(combo_count, board, merged_indices)


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
	_play_banner_flyby("2048", Color(1.0, 0.84, 0.18, 1.0))


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


func play_milestone_feedback(value: int) -> void:
	_play_board_heat_sweep(value)
	if value >= 1024:
		_play_banner_flyby(str(value), Color(1.0, 0.72, 0.16, 1.0))
	elif value >= 512:
		_play_corner_badge(str(value), Color(1.0, 0.55, 0.10, 1.0))


func _pulse_tile(tile: PanelContainer, peak_scale: Vector2, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "scale", peak_scale, duration * 0.45)
	tween.tween_property(tile, "scale", Vector2.ONE, duration * 0.55)


func _play_move_animations(move_animations: Array) -> void:
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
		ghost_style.bg_color.a = 0.28
		ghost_style.corner_radius_top_left = 18
		ghost_style.corner_radius_top_right = 18
		ghost_style.corner_radius_bottom_right = 18
		ghost_style.corner_radius_bottom_left = 18
		ghost_style.border_width_left = 2
		ghost_style.border_width_top = 2
		ghost_style.border_width_right = 2
		ghost_style.border_width_bottom = 2
		ghost_style.border_color = tile_colors.get(value, Color("3c3a32")).lightened(0.18)
		if value >= fire_level_threshold:
			ghost_style.shadow_color = Color(1.0, 0.36, 0.08, 0.85)
			ghost_style.shadow_size = 22
		elif value >= high_level_glow_threshold:
			ghost_style.shadow_color = Color(1.0, 0.82, 0.22, 0.55)
			ghost_style.shadow_size = 14
		ghost.add_theme_stylebox_override("panel", ghost_style)
		ghost.modulate = Color(1, 1, 1, 0.82)

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
		tween.tween_property(ghost, "modulate:a", 0.0, 0.12)
		tween.finished.connect(_queue_free_if_valid.bind(ghost))


func _spawn_merge_burst(tile_index: int, value: int) -> void:
	var tile: PanelContainer = board_view.panel_at(tile_index)
	var center := tile.global_position - animation_overlay.global_position + tile.size * 0.5
	_play_sequence(effect_frames_for_value(value), center, tile.size * (2.0 if value < fire_level_threshold else 2.6), 30.0, true, 0.95 if value < fire_level_threshold else 1.0)
	if value >= 128:
		_play_sequence(impact_frames, center, tile.size * 1.9, 30.0, false, 1.0)

	if value >= 256:
		_play_impact_flash(value)


func _play_board_impact(board: Array[int], merged_indices: Array[int]) -> void:
	var strongest_index := highest_merge_tile(board, merged_indices)
	if strongest_index < 0:
		return
	var strongest_value := board[strongest_index]
	if strongest_value < 128:
		return
	var peak_scale := Vector2(0.985, 0.985) if strongest_value < 512 else Vector2(0.972, 0.972)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	for index in board.size():
		var tile: PanelContainer = board_view.panel_at(index)
		tween.tween_property(tile, "scale", peak_scale, 0.045)
	tween.chain()
	for index in board.size():
		var tile: PanelContainer = board_view.panel_at(index)
		tween.tween_property(tile, "scale", Vector2.ONE, 0.11)


func _play_board_heat_sweep(value: int) -> void:
	var sweep := ColorRect.new()
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sweep.color = Color(1.0, 0.55, 0.10, 0.0)
	sweep.size = get_viewport().get_visible_rect().size
	sweep.position = Vector2.ZERO
	animation_overlay.add_child(sweep)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(sweep, "color", Color(1.0, 0.62, 0.16, 0.16 if value < 1024 else 0.24), 0.08)
	tween.tween_property(sweep, "color", Color(1.0, 0.18, 0.04, 0.0), 0.42)
	tween.finished.connect(_queue_free_if_valid.bind(sweep))


func _play_combo_feedback(combo_count: int, board: Array[int], merged_indices: Array[int]) -> void:
	var strongest_index := highest_merge_tile(board, merged_indices)
	var anchor := Vector2(get_viewport().get_visible_rect().size.x * 0.5, 82.0)
	if strongest_index >= 0:
		var tile: PanelContainer = board_view.panel_at(strongest_index)
		anchor = tile.global_position + Vector2(tile.size.x * 0.5, -24.0)
	var label := Label.new()
	label.text = "COMBO x%d" % combo_count
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.60, 1.0))
	label.size = Vector2(190, 42)
	label.position = anchor - label.size * 0.5
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	animation_overlay.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 22.0, 0.32)
	tween.tween_property(label, "modulate:a", 0.0, 0.34).set_delay(0.14)
	tween.finished.connect(_queue_free_if_valid.bind(label))


func _play_corner_badge(text: String, color: Color) -> void:
	var badge := Label.new()
	badge.text = text
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 44)
	badge.add_theme_color_override("font_color", color)
	badge.size = Vector2(180, 70)
	badge.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5 - 90.0, 92.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	animation_overlay.add_child(badge)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(badge, "scale", Vector2(1.18, 1.18), 0.12)
	tween.tween_property(badge, "modulate:a", 0.0, 0.40).set_delay(0.34)
	tween.finished.connect(_queue_free_if_valid.bind(badge))


func _play_banner_flyby(text: String, banner_color: Color) -> void:
	if milestone_banner_active:
		return
	milestone_banner_active = true
	var viewport_size := get_viewport().get_visible_rect().size
	var plane := Control.new()
	plane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plane.size = Vector2(360, 86)
	plane.position = Vector2(-plane.size.x - 60.0, viewport_size.y * 0.18)
	animation_overlay.add_child(plane)

	var banner := PanelContainer.new()
	banner.size = Vector2(246, 46)
	banner.position = Vector2(92, 20)
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = banner_color
	banner_style.corner_radius_top_left = 8
	banner_style.corner_radius_top_right = 8
	banner_style.corner_radius_bottom_left = 8
	banner_style.corner_radius_bottom_right = 8
	banner.add_theme_stylebox_override("panel", banner_style)
	plane.add_child(banner)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.28, 0.13, 0.02, 1.0))
	banner.add_child(label)

	var fuselage := ColorRect.new()
	fuselage.color = Color(1.0, 0.94, 0.76, 1.0)
	fuselage.size = Vector2(70, 20)
	fuselage.position = Vector2(12, 32)
	plane.add_child(fuselage)
	var wing := ColorRect.new()
	wing.color = Color(1.0, 0.54, 0.14, 1.0)
	wing.size = Vector2(52, 12)
	wing.position = Vector2(22, 20)
	plane.add_child(wing)
	var tail := ColorRect.new()
	tail.color = Color(0.90, 0.18, 0.08, 1.0)
	tail.size = Vector2(18, 28)
	tail.position = Vector2(2, 24)
	plane.add_child(tail)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(plane, "position:x", viewport_size.x + 80.0, 1.85)
	tween.tween_property(plane, "position:y", plane.position.y + 24.0, 0.92)
	tween.tween_property(plane, "rotation", deg_to_rad(-3.0), 0.25)
	tween.tween_property(plane, "rotation", deg_to_rad(2.0), 0.35).set_delay(0.25)
	tween.finished.connect(func() -> void:
		milestone_banner_active = false
		_queue_free_if_valid(plane)
	)


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


func _play_tile_atlas_once(
	frames: Array[Texture2D],
	tile_index: int,
	fps: float,
	scale_multiplier: Vector2,
	offset: Vector2,
	alpha: float
) -> void:
	if frames.is_empty():
		return
	var tile: PanelContainer = board_view.panel_at(tile_index)
	var size := tile.size * scale_multiplier
	var center := tile.global_position - animation_overlay.global_position + tile.size * 0.5 + offset
	_play_sequence(frames, center, size, fps, true, alpha)


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


func _layout_tile_sprite(sprite: TextureRect, panel: PanelContainer) -> void:
	var tile_size := panel.size
	if tile_size.x <= 0.0 or tile_size.y <= 0.0:
		return
	sprite.size = tile_size * 1.08
	sprite.position = tile_size * -0.04
	sprite.pivot_offset = sprite.size * 0.5


func _overlay_frames_for_value(value: int) -> Array[Texture2D]:
	if value >= 8192:
		return high_tier_overlay_frames.get(8192, [])
	if value >= 4096:
		return high_tier_overlay_frames.get(4096, [])
	if value >= 2048:
		return high_tier_overlay_frames.get(2048, [])
	if value >= 1024:
		return high_tier_overlay_frames.get(1024, [])
	return []


func _sync_tile_fire_material(panel: PanelContainer, material: ShaderMaterial) -> void:
	if material == null:
		return
	var tile_size := panel.size
	if tile_size.x <= 0.0 or tile_size.y <= 0.0:
		return
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	var corner_radius := 18.0
	var border_width := 0.0
	if style != null:
		corner_radius = max(
			float(style.corner_radius_top_left),
			max(
				float(style.corner_radius_top_right),
				max(float(style.corner_radius_bottom_right), float(style.corner_radius_bottom_left))
			)
		)
		border_width = max(
			float(style.border_width_left),
			max(
				float(style.border_width_top),
				max(float(style.border_width_right), float(style.border_width_bottom))
			)
		)
	material.set_shader_parameter("rect_size", tile_size)
	material.set_shader_parameter("corner_radius_px", corner_radius)
	material.set_shader_parameter("edge_inset_px", border_width)


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
	for path in _list_png_resource_paths(directory):
		var texture := load(path) as Texture2D
		if texture != null:
			textures.append(texture)
	return textures


func _load_atlas_frames_from_file(path: String, grid: Vector2i, row: int) -> Array[Texture2D]:
	var source_texture := load(path) as Texture2D
	if source_texture == null:
		return []
	var image := source_texture.get_image()
	if image == null:
		return []
	var cell_width := image.get_width() / grid.x
	var cell_height := image.get_height() / grid.y
	if cell_width <= 0 or cell_height <= 0:
		return []
	var textures: Array[Texture2D] = []
	for column in grid.x:
		var frame := Image.create(cell_width, cell_height, false, image.get_format())
		frame.blit_rect(
			image,
			Rect2i(column * cell_width, row * cell_height, cell_width, cell_height),
			Vector2i.ZERO
		)
		textures.append(ImageTexture.create_from_image(frame))
	return textures


func _load_atlas_frames(directory: String, grid: Vector2i, row: int) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for path in _list_png_resource_paths(directory):
		var source_texture := load(path) as Texture2D
		if source_texture == null:
			continue
		var image := source_texture.get_image()
		if image == null:
			continue
		var cell_width := image.get_width() / grid.x
		var cell_height := image.get_height() / grid.y
		if cell_width <= 0 or cell_height <= 0:
			continue
		for column in grid.x:
			var frame := Image.create(cell_width, cell_height, false, image.get_format())
			frame.blit_rect(
				image,
				Rect2i(column * cell_width, row * cell_height, cell_width, cell_height),
				Vector2i.ZERO
			)
			textures.append(ImageTexture.create_from_image(frame))
	return textures


func _list_png_resource_paths(directory: String) -> PackedStringArray:
	var files := DirAccess.get_files_at(directory)
	files.sort()
	var paths := PackedStringArray()
	var seen: Dictionary = {}
	for file_name in files:
		var png_name := ""
		if file_name.ends_with(".png"):
			png_name = file_name
		elif file_name.ends_with(".png.import"):
			png_name = file_name.trim_suffix(".import")
		else:
			continue
		if seen.has(png_name):
			continue
		seen[png_name] = true
		paths.append("%s/%s" % [directory, png_name])
	return paths
