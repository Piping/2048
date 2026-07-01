extends "res://scripts/effects/effect_cue.gd"
class_name VfxEffectCue

@export_enum("spawn_pulse", "merge_feedback", "screen_merge_feedback", "milestone_feedback", "celebration") var action := "merge_feedback"
@export var scale_boost := 1.0
@export var intensity_boost := 1.0
