extends Control
class_name EffectScenePlayer

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var flash: ColorRect = $Flash
@onready var ring: ColorRect = $Ring
@onready var label: Label = $Label
@onready var sfx: AudioStreamPlayer = $Sfx

var _tile_rect := Rect2(Vector2.ZERO, Vector2.ZERO)
var _mix_rate := 44100.0


func _ready() -> void:
	sfx.stream = _build_hit_stream()


func configure(effect_context: Dictionary) -> void:
	_tile_rect = effect_context.get("tile_rect", Rect2(Vector2.ZERO, Vector2.ZERO))
	var tile_value := int(effect_context.get("tile_value", 0))
	position = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.position = _tile_rect.position - _tile_rect.size * 0.18
	flash.size = _tile_rect.size * 1.36
	flash.pivot_offset = flash.size * 0.5
	ring.position = _tile_rect.position - _tile_rect.size * 0.26
	ring.size = _tile_rect.size * 1.52
	ring.pivot_offset = ring.size * 0.5
	label.text = str(tile_value)
	label.position = Vector2(_tile_rect.position.x - 18.0, _tile_rect.position.y - 54.0)
	label.pivot_offset = label.size * 0.5


func play() -> void:
	if animation_player.has_animation("play"):
		animation_player.play("play")
		return
	finish()


func _play_hit_sfx() -> void:
	if sfx.stream == null:
		sfx.stream = _build_hit_stream()
	sfx.play()


func finish() -> void:
	queue_free()


func _build_hit_stream() -> AudioStreamWAV:
	var attack := 0.003
	var sustain := 0.08
	var release := 0.24
	var total_time: float = attack + sustain + release
	var sample_count := int(ceil(total_time * _mix_rate))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / _mix_rate
		var progress: float = float(i) / max(1.0, float(sample_count - 1))
		var base_frequency := lerpf(240.0, 110.0, progress)
		var overtone_frequency := base_frequency * 2.35
		var env: float = _envelope(t, attack, sustain, release)
		var sample := (
			sin(TAU * base_frequency * t) * 0.72 +
			sin(TAU * overtone_frequency * t) * 0.28
		) * env
		var pcm := int(clampi(int(round(sample * 28000.0)), -32768, 32767))
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(_mix_rate)
	stream.stereo = false
	stream.data = data
	return stream


func _envelope(time: float, attack: float, sustain: float, release: float) -> float:
	if time <= attack:
		return clampf(time / max(attack, 0.001), 0.0, 1.0)
	var sustain_end: float = attack + sustain
	if time <= sustain_end:
		return 1.0
	var release_progress: float = (time - sustain_end) / max(release, 0.001)
	return clampf(1.0 - release_progress, 0.0, 1.0)
