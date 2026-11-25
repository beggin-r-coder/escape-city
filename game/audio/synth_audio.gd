class_name SynthAudio
extends Node
## Placeholder procedural audio (no licensed assets needed for the prototype):
## a layered engine tone pitched by speed, a siren that swells with police proximity,
## tyre skid noise while drifting, plus generated one-shots (crash, coin, smash, warning).
## Replace with recorded assets later; keep the same entry points.

const MIX_RATE := 22050.0

var engine_speed: float = 0.0  # m/s
var siren_level: float = 0.0  # 0..1
var skid_level: float = 0.0  # 0..1
var muted: bool = false

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _phase_engine: float = 0.0
var _phase_engine2: float = 0.0
var _phase_siren: float = 0.0
var _siren_t: float = 0.0
var _lp: float = 0.0
var _one_shots: Dictionary = {}
var _shot_players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.15
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.bus = AudioBuses.SFX
	_player.volume_db = -8.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	build_one_shots()
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = AudioBuses.SFX
		add_child(p)
		_shot_players.append(p)


func build_one_shots() -> void:
	_one_shots["crash"] = _make_noise_burst(0.45, 9.0, 0.9)
	_one_shots["smash"] = _make_noise_burst(0.18, 18.0, 0.5)
	_one_shots["coin"] = _make_tone([1320.0, 1760.0], 0.12, 0.35)
	_one_shots["warning"] = _make_tone([880.0, 660.0], 0.18, 0.4)
	_one_shots["escape"] = _make_tone([660.0, 880.0, 1100.0], 0.12, 0.35)


func play(name_id: String) -> void:
	if muted or not _one_shots.has(name_id):
		return
	for p in _shot_players:
		if not p.playing:
			p.stream = _one_shots[name_id]
			p.play()
			return


func _process(delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		_siren_t += delta
		return
	_playback.push_buffer(synth(frames, delta))


## Renders `frames` samples of the continuous layers (engine, siren, skid). Pure enough to
## call offline in tests: no playback or tree needed.
func synth(frames: int, delta: float) -> PackedVector2Array:
	_siren_t += delta
	var buf := PackedVector2Array()
	buf.resize(frames)
	var eng_f := 38.0 + engine_speed * 5.5
	var eng_amp := 0.0 if muted else 0.16 + clampf(engine_speed / 22.0, 0.0, 1.0) * 0.1
	var wail := 0.5 + 0.5 * sin(_siren_t * TAU * 0.45)
	var siren_f := 620.0 + 520.0 * wail
	var siren_amp := 0.0 if muted else siren_level * 0.12
	var skid_amp := 0.0 if muted else skid_level * 0.12
	var inc_e := eng_f / MIX_RATE
	var inc_e2 := eng_f * 0.5 / MIX_RATE
	var inc_s := siren_f / MIX_RATE
	for i in frames:
		_phase_engine = fmod(_phase_engine + inc_e, 1.0)
		_phase_engine2 = fmod(_phase_engine2 + inc_e2, 1.0)
		_phase_siren = fmod(_phase_siren + inc_s, 1.0)
		var saw := (_phase_engine * 2.0 - 1.0) * 0.6 + (_phase_engine2 * 2.0 - 1.0) * 0.4
		_lp += (saw - _lp) * 0.18
		var v := _lp * eng_amp
		v += sin(_phase_siren * TAU) * siren_amp
		if skid_amp > 0.0:
			v += randf_range(-1.0, 1.0) * skid_amp
		buf[i] = Vector2(v, v)
	return buf


## One-shot sample bank (crash, smash, coin, warning, escape), exposed for tests.
func one_shot(name_id: String) -> AudioStreamWAV:
	return _one_shots.get(name_id, null)


static func _make_noise_burst(seconds: float, decay: float, amp: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.35
		var s := lp * amp * exp(-t * decay)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data)


static func _make_tone(freqs: Array, step_seconds: float, amp: float) -> AudioStreamWAV:
	var per := int(MIX_RATE * step_seconds)
	var n := per * freqs.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var f := float(freqs[mini(i / per, freqs.size() - 1)])
		phase += f / MIX_RATE
		var local_t := float(i % per) / float(per)
		var env := minf(1.0, local_t * 20.0) * (1.0 - local_t * 0.6)
		var s := sin(phase * TAU) * amp * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data)


static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(MIX_RATE)
	w.stereo = false
	w.data = data
	return w
