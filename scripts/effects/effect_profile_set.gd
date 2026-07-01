extends Resource
class_name EffectProfileSet

@export var profiles: Array[Resource] = []


func find_profile(event_name: StringName, tile_value: int):
	var best = null
	for profile in profiles:
		if profile == null or not profile.matches(event_name, tile_value):
			continue
		if best == null:
			best = profile
			continue
		if profile.priority > best.priority:
			best = profile
			continue
		if profile.priority == best.priority and profile.min_tile_value > best.min_tile_value:
			best = profile
	return best
