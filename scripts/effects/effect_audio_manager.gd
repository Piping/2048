extends Node
class_name EffectAudioManager

var _mix_rate := 44100.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func play_generated(cue) -> void:
	if cue == null or not cue.enabled:
		return
	var player := AudioStreamPlayer.new()
	player.bus = str(cue.bus)
	player.volume_db = cue.volume_db
	player.pitch_scale = cue.pitch_scale + _rng.randf_range(-cue.pitch_random_range, cue.pitch_random_range)
	player.stream = _build_stream(cue)
	add_child(player)
	player.finished.connect(func() -> void:
		if is_instance_valid(player):
			player.queue_free()
	)
	player.play()


func _build_stream(cue) -> AudioStreamWAV:
	var total_time: float = max(0.02, cue.attack + cue.sustain + cue.release)
	var sample_count := int(ceil(total_time * _mix_rate))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var frequency_end: float = cue.frequency_end if cue.frequency_end > 0.0 else cue.frequency
	for i in sample_count:
		var t := float(i) / _mix_rate
		var progress: float = float(i) / max(1.0, float(sample_count - 1))
		var frequency: float = lerpf(cue.frequency, frequency_end, progress)
		var env: float = _envelope(t, cue.attack, cue.sustain, cue.release)
		var phase: float = TAU * frequency * t
		var sample: float = _waveform_sample(cue.waveform, phase) * env
		var pcm := int(clampi(int(round(sample * 30000.0)), -32768, 32767))
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


func _waveform_sample(waveform: StringName, phase: float) -> float:
	match str(waveform):
		"square":
			return 1.0 if sin(phase) >= 0.0 else -1.0
		"saw":
			return fmod(phase / PI, 2.0) - 1.0
		"triangle":
			return asin(sin(phase)) * (2.0 / PI)
		"noise":
			return _rng.randf_range(-1.0, 1.0)
		_:
			return sin(phase)
