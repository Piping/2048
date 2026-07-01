extends "res://scripts/effects/effect_cue.gd"
class_name AudioEffectCue

@export var bus: StringName = &"Master"
@export var volume_db := -6.0
@export var pitch_scale := 1.0
@export var pitch_random_range := 0.0
@export var waveform: StringName = &"sine"
@export var attack := 0.005
@export var sustain := 0.05
@export var release := 0.12
@export var frequency := 440.0
@export var frequency_end := 0.0
