extends Node
class_name EffectDirector

@export var profile_set: Resource

@onready var audio_manager: Node = $AudioManager

var vfx_controller


func configure(vfx_controller_node) -> void:
	vfx_controller = vfx_controller_node


func play_event(event_name: StringName, context: Dictionary) -> void:
	if vfx_controller == null or profile_set == null:
		return
	var tile_value := int(context.get("tile_value", 0))
	var profile = profile_set.find_profile(event_name, tile_value)
	if profile == null:
		return
	for cue in profile.cues:
		_schedule_cue(cue, profile, context)


func _schedule_cue(cue, profile, context: Dictionary) -> void:
	if cue == null or not cue.enabled:
		return
	if cue.delay <= 0.0:
		_execute_cue(cue, profile, context)
		return
	var timer := get_tree().create_timer(cue.delay)
	timer.timeout.connect(_execute_cue.bind(cue, profile, context))


func _execute_cue(cue, profile, context: Dictionary) -> void:
	if cue != null and cue.get("action") != null:
		_play_vfx(cue, context)
	elif cue != null and cue.get("packed_scene") != null:
		_play_scene_cue(cue, context)
	else:
		audio_manager.play_generated(cue)


func _play_vfx(cue, context: Dictionary) -> void:
	match cue.action:
		"spawn_pulse":
			vfx_controller.play_spawn_feedback(
				int(context.get("spawned_index", -1)),
				cue.scale_boost,
				cue.intensity_boost
			)
		"merge_feedback":
			vfx_controller.play_merge_feedback(
				context.get("board", []),
				context.get("move_animations", []),
				int(context.get("spawned_index", -1)),
				context.get("merged_indices", []),
				int(context.get("combo_count", 0)),
				cue.scale_boost,
				cue.intensity_boost
			)
		"screen_merge_feedback":
			vfx_controller.play_screen_merge_feedback(
				int(context.get("tile_value", 0)),
				int(context.get("focus_tile_index", -1)),
				cue.intensity_boost
			)
		"milestone_feedback":
			vfx_controller.play_milestone_feedback(
				int(context.get("tile_value", 0)),
				cue.intensity_boost
			)
		"celebration":
			vfx_controller.play_celebration(cue.intensity_boost)


func _play_scene_cue(cue, context: Dictionary) -> void:
	if cue.packed_scene == null:
		return
	var scene_instance = cue.packed_scene.instantiate()
	if scene_instance == null:
		return
	var tile_index := int(context.get("focus_tile_index", -1))
	var enriched_context := context.duplicate(true)
	enriched_context["tile_rect"] = vfx_controller.tile_visual_rect(tile_index)
	var attach_parent: Node = get_tree().current_scene if cue.attach_to == "root" else vfx_controller.overlay_root()
	attach_parent.add_child(scene_instance)
	if scene_instance.has_method("configure"):
		scene_instance.call("configure", enriched_context)
	if scene_instance.has_method("play"):
		scene_instance.call("play")


func preview_profile(event_name: StringName, context: Dictionary) -> void:
	play_event(event_name, context)
