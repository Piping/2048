extends RefCounted
class_name EffectProfileLibrary


static func build_default_profile_set() -> EffectProfileSet:
	var set := EffectProfileSet.new()
	set.profiles = [
		_spawn_profile(),
		_merge_profile(&"merge_128", 128, 255, 10, 1, 1.00, 1.00, 980.0, 1320.0, -16.0),
		_merge_profile(&"merge_256", 256, 511, 20, 2, 1.04, 1.08, 820.0, 1180.0, -14.0),
		_merge_profile(&"merge_512", 512, 1023, 30, 3, 1.10, 1.18, 640.0, 980.0, -11.0),
		_merge_profile(&"merge_1024", 1024, 2047, 40, 4, 1.18, 1.34, 460.0, 780.0, -8.0),
		_merge_profile(&"merge_2048_plus", 2048, 0, 50, 5, 1.28, 1.55, 280.0, 560.0, -5.0),
		_screen_merge_profile(),
		_milestone_profile(),
		_celebration_profile()
	]
	return set


static func _spawn_profile() -> EffectProfile:
	var vfx := VfxEffectCue.new()
	vfx.action = "spawn_pulse"
	vfx.scale_boost = 1.0
	vfx.intensity_boost = 1.0

	var audio := AudioEffectCue.new()
	audio.volume_db = -20.0
	audio.frequency = 1180.0
	audio.frequency_end = 1540.0
	audio.attack = 0.004
	audio.sustain = 0.015
	audio.release = 0.05
	audio.pitch_random_range = 0.02

	var profile := EffectProfile.new()
	profile.id = &"spawn_basic"
	profile.event_name = &"spawn"
	profile.min_tile_value = 0
	profile.max_tile_value = 4
	profile.priority = 5
	profile.intensity_rank = 0
	profile.debug_label = "Spawn"
	profile.cues = [vfx, audio]
	return profile


static func _merge_profile(
	id: StringName,
	min_value: int,
	max_value: int,
	priority: int,
	intensity_rank: int,
	scale_boost: float,
	intensity_boost: float,
	frequency: float,
	frequency_end: float,
	volume_db: float
) -> EffectProfile:
	var vfx := VfxEffectCue.new()
	vfx.action = "merge_feedback"
	vfx.scale_boost = scale_boost
	vfx.intensity_boost = intensity_boost

	var audio := AudioEffectCue.new()
	audio.volume_db = volume_db
	audio.frequency = frequency
	audio.frequency_end = frequency_end
	audio.attack = 0.005
	audio.sustain = 0.05 + float(intensity_rank) * 0.01
	audio.release = 0.09 + float(intensity_rank) * 0.02
	audio.waveform = &"triangle" if intensity_rank <= 2 else &"saw"
	audio.pitch_random_range = 0.015

	var profile := EffectProfile.new()
	profile.id = id
	profile.event_name = &"merge_move"
	profile.min_tile_value = min_value
	profile.max_tile_value = max_value
	profile.priority = priority
	profile.intensity_rank = intensity_rank
	profile.debug_label = str(id)
	profile.cues = [vfx, audio]
	return profile


static func _screen_merge_profile() -> EffectProfile:
	var vfx := VfxEffectCue.new()
	vfx.action = "screen_merge_feedback"
	vfx.intensity_boost = 1.25

	var audio := AudioEffectCue.new()
	audio.delay = 0.03
	audio.volume_db = -7.0
	audio.frequency = 180.0
	audio.frequency_end = 90.0
	audio.attack = 0.002
	audio.sustain = 0.08
	audio.release = 0.22
	audio.waveform = &"saw"

	var profile := EffectProfile.new()
	profile.id = &"screen_merge_2048_plus"
	profile.event_name = &"screen_merge"
	profile.min_tile_value = 2048
	profile.max_tile_value = 0
	profile.priority = 80
	profile.intensity_rank = 6
	profile.debug_label = "Screen Merge"
	profile.cues = [vfx, audio]
	return profile


static func _milestone_profile() -> EffectProfile:
	var vfx := VfxEffectCue.new()
	vfx.action = "milestone_feedback"
	vfx.intensity_boost = 1.3

	var audio := AudioEffectCue.new()
	audio.volume_db = -6.0
	audio.frequency = 520.0
	audio.frequency_end = 860.0
	audio.attack = 0.01
	audio.sustain = 0.12
	audio.release = 0.30
	audio.waveform = &"triangle"

	var profile := EffectProfile.new()
	profile.id = &"milestone_2048_plus"
	profile.event_name = &"milestone"
	profile.min_tile_value = 2048
	profile.max_tile_value = 0
	profile.priority = 90
	profile.intensity_rank = 6
	profile.debug_label = "Milestone"
	profile.cues = [vfx, audio]
	return profile


static func _celebration_profile() -> EffectProfile:
	var vfx := VfxEffectCue.new()
	vfx.action = "celebration"
	vfx.intensity_boost = 1.4

	var audio := AudioEffectCue.new()
	audio.delay = 0.04
	audio.volume_db = -4.0
	audio.frequency = 660.0
	audio.frequency_end = 990.0
	audio.attack = 0.015
	audio.sustain = 0.18
	audio.release = 0.35
	audio.waveform = &"triangle"

	var profile := EffectProfile.new()
	profile.id = &"celebration_2048"
	profile.event_name = &"celebration"
	profile.min_tile_value = 2048
	profile.max_tile_value = 0
	profile.priority = 100
	profile.intensity_rank = 7
	profile.debug_label = "Celebration"
	profile.cues = [vfx, audio]
	return profile
