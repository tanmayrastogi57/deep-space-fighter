extends Node

var engine_player: AudioStreamPlayer
var engine_playback: AudioStreamGeneratorPlayback
var engine_phase := 0.0
var engine_throttle := 0.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	engine_player = AudioStreamPlayer.new()
	engine_player.name = "EngineLoop"
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.25
	engine_player.stream = stream
	add_child(engine_player)
	engine_player.play()
	engine_playback = engine_player.get_stream_playback()


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	if engine_player != null:
		engine_player.stop()
		engine_player.stream = null
		if engine_player.get_parent() == self:
			remove_child(engine_player)
		engine_player.free()
		engine_player = null
	engine_playback = null


func _process(_delta: float) -> void:
	if engine_playback == null:
		return
	var frames := engine_playback.get_frames_available()
	var frequency := lerpf(42.0, 118.0, engine_throttle)
	var volume := lerpf(0.015, 0.09, engine_throttle) * float(Settings.data.get("effects_volume", 0.85))
	for _frame in frames:
		engine_phase = fmod(engine_phase + frequency / 22050.0, 1.0)
		var low := sin(engine_phase * TAU)
		var harmonic := sin(engine_phase * TAU * 2.03) * 0.35
		var sample := (low + harmonic) * volume
		engine_playback.push_frame(Vector2(sample, sample))


func set_engine_throttle(value: float) -> void:
	engine_throttle = clampf(value, 0.0, 1.0)


func play_effect(effect: StringName, strength: float = 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = _build_effect(effect, strength)
	player.volume_db = linear_to_db(maxf(0.001, float(Settings.data.get("effects_volume", 0.85))))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _build_effect(effect: StringName, strength: float) -> AudioStreamWAV:
	var duration := 0.18
	var start_frequency := 260.0
	var end_frequency := 90.0
	match effect:
		"cannon":
			duration = 0.08
			start_frequency = 145.0
			end_frequency = 62.0
		"missile":
			duration = 0.34
			start_frequency = 85.0
			end_frequency = 420.0
		"impact":
			duration = 0.28
			start_frequency = 70.0
			end_frequency = 24.0
		"dock":
			duration = 0.45
			start_frequency = 320.0
			end_frequency = 520.0
	var mix_rate := 22050
	var sample_count := int(duration * mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var phase := 0.0
	for index in sample_count:
		var progress := float(index) / float(sample_count)
		var frequency := lerpf(start_frequency, end_frequency, progress)
		phase += frequency / float(mix_rate)
		var envelope := pow(1.0 - progress, 2.2)
		var noise := randf_range(-0.18, 0.18)
		var value := clampf((sin(phase * TAU) + noise) * envelope * 0.42 * strength, -1.0, 1.0)
		var integer := int(value * 32767.0)
		bytes[index * 2] = integer & 0xff
		bytes[index * 2 + 1] = (integer >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = bytes
	return stream
