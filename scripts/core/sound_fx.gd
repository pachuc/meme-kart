extends Node
## Autoload "SoundFx". All audio in the shell is synthesized at startup
## (square/saw/noise chiptune blips) so no sound files are needed.
## Replace any of these by dropping AudioStream assets in and swapping
## the entries in _build_streams(), or point TrackDef.music at a file.
##
## API:
##   SoundFx.play("pickup")                  - UI / non-positional
##   SoundFx.play_3d("boost", global_pos)    - positional one-shot
##   SoundFx.engine_loop                     - looped stream for kart engines
##   SoundFx.play_music(stream_or_null)      - null = built-in loop

const SAMPLE_RATE := 22050
const POOL_SIZE := 8

var engine_loop: AudioStreamWAV
var _streams: Dictionary = {}
var _players: Array = []
var _players_3d: Array = []
var _music_player: AudioStreamPlayer
var _default_music: AudioStreamWAV


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_streams()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 8.0
		p3.max_db = 0.0
		add_child(p3)
		_players_3d.append(p3)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -16.0
	add_child(_music_player)
	play_music(null)


func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(sound):
		push_warning("SoundFx: unknown sound '%s'" % sound)
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[sound]
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


func play_3d(sound: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(sound):
		push_warning("SoundFx: unknown sound '%s'" % sound)
		return
	for p in _players_3d:
		if not p.playing:
			p.stream = _streams[sound]
			p.global_position = pos
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


## null = built-in chiptune loop. Pass an AudioStream to override
## (e.g. TrackDef.music).
func play_music(stream: AudioStream) -> void:
	_music_player.stream = stream if stream != null else _default_music
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


# --- synthesis --------------------------------------------------------------

func _build_streams() -> void:
	_streams = {
		"ui_move": _wav(_tone(660, 660, 0.045, 0.25)),
		"ui_select": _wav(_seq([_tone(880, 880, 0.07, 0.3), _tone(1320, 1320, 0.1, 0.3)])),
		"count": _wav(_tone(440, 440, 0.14, 0.4)),
		"go": _wav(_tone(880, 880, 0.32, 0.45)),
		"hop": _wav(_tone(260, 480, 0.09, 0.4)),
		"boost": _wav(_tone(300, 950, 0.28, 0.45, "saw")),
		"pickup": _wav(_seq([_tone(523, 523, 0.06, 0.3), _tone(659, 659, 0.06, 0.3), _tone(784, 784, 0.09, 0.3)])),
		"tick": _wav(_tone(1050, 1050, 0.03, 0.25)),
		"shell": _wav(_mix([_tone(620, 180, 0.16, 0.35, "saw"), _noise(0.12, 0.2)])),
		"spin": _wav(_tone(720, 130, 0.42, 0.4, "saw")),
		"bump": _wav(_noise(0.08, 0.35)),
		"finish": _wav(_seq([
			_tone(523, 523, 0.12, 0.35), _tone(659, 659, 0.12, 0.35),
			_tone(784, 784, 0.12, 0.35), _tone(1046, 1046, 0.4, 0.4),
		])),
	}
	# 75 Hz saw, exactly 30 cycles -> seamless loop.
	engine_loop = _wav(_tone_flat(75.0, 0.4, 0.5, "saw"), true)
	_default_music = _wav(_make_music(), true)


func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav


## Tone with fast attack + linear decay envelope, optional pitch sweep.
func _tone(f0: float, f1: float, dur: float, vol: float, shape: String = "square") -> PackedFloat32Array:
	var n := int(dur * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += lerpf(f0, f1, t) / SAMPLE_RATE
		var env := minf(t * 25.0, 1.0) * (1.0 - t)
		out[i] = _osc(phase, shape) * env * vol
	return out


## Constant-envelope tone (for seamless loops).
func _tone_flat(freq: float, dur: float, vol: float, shape: String) -> PackedFloat32Array:
	var n := int(dur * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		phase += freq / SAMPLE_RATE
		out[i] = _osc(phase, shape) * vol
	return out


func _osc(phase: float, shape: String) -> float:
	var p := fmod(phase, 1.0)
	match shape:
		"saw":
			return p * 2.0 - 1.0
		"sine":
			return sin(p * TAU)
		_:
			return 1.0 if p < 0.5 else -1.0


func _noise(dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in n:
		var t := float(i) / n
		out[i] = (rng.randf() * 2.0 - 1.0) * (1.0 - t) * vol
	return out


func _seq(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p in parts:
		for i in p.size():
			out[i] += p[i]
	return out


## 8-second I-vi-IV-V arpeggio loop, 120 bpm. Placeholder race music.
func _make_music() -> PackedFloat32Array:
	const C4 := 261.63
	const NOTE := 0.25  # eighth note at 120 bpm
	var chords := [
		[0.0, 4.0, 7.0],    # C
		[9.0, 12.0, 16.0],  # Am
		[5.0, 9.0, 12.0],   # F
		[7.0, 11.0, 14.0],  # G
	]
	var melody := PackedFloat32Array()
	var bass := PackedFloat32Array()
	for chord in chords:
		for step in 8:
			var semi: float = chord[step % 3] + (12.0 if step % 4 == 3 else 0.0)
			melody.append_array(_tone_env_tail(C4 * pow(2.0, semi / 12.0), NOTE, 0.14))
		var root: float = C4 * pow(2.0, (chord[0] - 24.0) / 12.0)
		bass.append_array(_tone_env_tail(root, NOTE * 4.0, 0.16))
		bass.append_array(_tone_env_tail(root, NOTE * 4.0, 0.16))
	return _mix([melody, bass])


## Tone with a short release tail (keeps note transitions click-free).
func _tone_env_tail(freq: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += freq / SAMPLE_RATE
		var env := minf(t * 30.0, 1.0) * minf((1.0 - t) * 6.0, 1.0)
		out[i] = _osc(phase, "square") * env * vol
	return out
