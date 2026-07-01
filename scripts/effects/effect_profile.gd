extends Resource
class_name EffectProfile

@export var id: StringName
@export var event_name: StringName
@export var min_tile_value := 0
@export var max_tile_value := 0
@export var priority := 0
@export var intensity_rank := 0
@export var debug_label := ""
@export var cues: Array[Resource] = []


func matches(query_event: StringName, tile_value: int) -> bool:
	if event_name != query_event:
		return false
	if min_tile_value > 0 and tile_value < min_tile_value:
		return false
	if max_tile_value > 0 and tile_value > max_tile_value:
		return false
	return true
