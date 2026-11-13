extends Node
## Studio-grade 44.1kHz procedural synthwave engine: 64-step chord progressions, filtered supersaw bass, stereo delay lead, and sidechain kick.

var muted: bool = false:
	set(value):
		muted = value
		if _bgm_player:
			_bgm_player.volume_db = -80.0 if muted else -8.0

var _sfx_players: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer
var _bgm_pb: AudioStreamGeneratorPlayback

const POOL_SIZE := 8
const SAMPLE_RATE := 44100.0
const DELAY_SAMPLES := 13230 # ~300ms stereo-style echo

var _stage_id: int = 1
var _progress: float = 0.0
var _bgm_time: float = 0.0
var _step_idx: int = 0

# Oscillator phases
var _bass_p1: float = 0.0
var _bass_p2: float = 0.0
var _bass_lpf: float = 0.0
var _pad_p1: float = 0.0
var _pad_p2: float = 0.0
var _pad_p3: float = 0.0
var _lead_p1: float = 0.0
var _lead_p2: float = 0.0
var _lead_lpf: float = 0.0

# Drums
var _kick_env: float = 0.0
var _kick_phase: float = 0.0
var _snare_env: float = 0.0
var _snare_body_phase: float = 0.0
var _snare_lpf: float = 0.0
var _hat_env: float = 0.0
var _hat_prev: float = 0.0

# Circular echo delay buffer for lead melody
var _delay_buf: PackedFloat32Array = PackedFloat32Array()
var _delay_idx: int = 0

# 4-bar (64-step) chord roots & melodies per stage
# Chords change every 16 steps (bar 0..3)
const TRACKS := {
	1: { # Neon Alley: 148 BPM, D Minor (Dm - Bb - C - Am)
		"bpm": 148.0,
		"roots": [73.42, 58.27, 65.41, 55.00], # D2, Bb1, C2, A1
		"lead": [
			587.33, 0.0, 659.25, 0.0, 698.46, 0.0, 880.00, 0.0, 698.46, 0.0, 659.25, 0.0, 587.33, 0.0, 523.25, 0.0,
			587.33, 0.0, 698.46, 0.0, 932.33, 0.0, 880.00, 0.0, 698.46, 0.0, 587.33, 0.0, 466.16, 0.0, 523.25, 0.0,
			523.25, 0.0, 659.25, 0.0, 783.99, 0.0, 1046.5, 0.0, 880.00, 0.0, 783.99, 0.0, 659.25, 0.0, 587.33, 0.0,
			440.00, 0.0, 523.25, 0.0, 659.25, 0.0, 880.00, 0.0, 783.99, 0.0, 659.25, 0.0, 587.33, 523.25, 440.00, 0.0,
		],
	},
	2: { # Midnight Tunnels: 154 BPM, E Phrygian (Em - F - G - Dm)
		"bpm": 154.0,
		"roots": [82.41, 87.31, 98.00, 73.42], # E2, F2, G2, D2
		"lead": [
			659.25, 0.0, 698.46, 0.0, 783.99, 0.0, 987.77, 0.0, 783.99, 0.0, 698.46, 0.0, 659.25, 0.0, 587.33, 0.0,
			698.46, 0.0, 880.00, 0.0, 1046.5, 0.0, 880.00, 0.0, 698.46, 0.0, 659.25, 0.0, 587.33, 0.0, 523.25, 0.0,
			783.99, 0.0, 987.77, 0.0, 1174.7, 0.0, 987.77, 0.0, 783.99, 0.0, 698.46, 0.0, 659.25, 0.0, 587.33, 0.0,
			587.33, 0.0, 659.25, 0.0, 698.46, 0.0, 880.00, 0.0, 783.99, 0.0, 698.46, 0.0, 659.25, 587.33, 493.88, 0.0,
		],
	},
	3: { # Shogun Skyline: 160 BPM, F# Minor (F#m - D - E - C#m)
		"bpm": 160.0,
		"roots": [92.50, 73.42, 82.41, 69.30], # F#2, D2, E2, C#2
		"lead": [
			739.99, 0.0, 880.00, 0.0, 1108.7, 0.0, 987.77, 0.0, 880.00, 0.0, 739.99, 0.0, 659.25, 0.0, 587.33, 0.0,
			587.33, 0.0, 739.99, 0.0, 880.00, 0.0, 1174.7, 0.0, 1108.7, 0.0, 880.00, 0.0, 739.99, 0.0, 659.25, 0.0,
			659.25, 0.0, 824.07, 0.0, 987.77, 0.0, 1318.5, 0.0, 1108.7, 0.0, 987.77, 0.0, 824.07, 0.0, 739.99, 0.0,
			554.37, 0.0, 659.25, 0.0, 824.07, 0.0, 1108.7, 0.0, 987.77, 0.0, 824.07, 0.0, 739.99, 659.25, 554.37, 0.0,
		],
	},
	4: { # Cyber Shogunate: 168 BPM, A Minor (Am - F - G - Em)
		"bpm": 168.0,
		"roots": [110.00, 87.31, 98.00, 82.41], # A2, F2, G2, E2
		"lead": [
			880.00, 1046.5, 1318.5, 0.0, 1174.7, 1046.5, 880.00, 0.0, 880.00, 1046.5, 1318.5, 0.0, 1568.0, 1318.5, 1046.5, 0.0,
			698.46, 880.00, 1046.5, 0.0, 1396.9, 1318.5, 1046.5, 0.0, 880.00, 1046.5, 1174.7, 0.0, 1046.5, 880.00, 698.46, 0.0,
			783.99, 987.77, 1174.7, 0.0, 1568.0, 1318.5, 1174.7, 0.0, 987.77, 1174.7, 1318.5, 0.0, 1174.7, 987.77, 783.99, 0.0,
			659.25, 783.99, 987.77, 0.0, 1318.5, 1174.7, 987.77, 0.0, 880.00, 987.77, 1046.5, 0.0, 1318.5, 1174.7, 987.77, 0.0,
		],
	},
	5: { # Sakura Express: 172 BPM, G Minor (Gm - Eb - F - Dm)
		"bpm": 172.0,
		"roots": [98.00, 77.78, 87.31, 73.42],
		"lead": [
			783.99, 0.0, 932.33, 0.0, 1174.7, 0.0, 1046.5, 0.0, 932.33, 0.0, 783.99, 0.0, 698.46, 0.0, 587.33, 0.0,
			622.25, 0.0, 783.99, 0.0, 932.33, 0.0, 1244.5, 0.0, 1174.7, 0.0, 932.33, 0.0, 783.99, 0.0, 622.25, 0.0,
			698.46, 0.0, 880.00, 0.0, 1046.5, 0.0, 1396.9, 0.0, 1174.7, 0.0, 1046.5, 0.0, 880.00, 0.0, 698.46, 0.0,
			587.33, 0.0, 698.46, 0.0, 880.00, 0.0, 1174.7, 0.0, 1046.5, 0.0, 880.00, 0.0, 783.99, 698.46, 587.33, 0.0,
		],
	},
	6: { # Reactor Core: 176 BPM, C Minor (Cm - Ab - Bb - G)
		"bpm": 176.0,
		"roots": [65.41, 103.83, 116.54, 98.00],
		"lead": [
			523.25, 622.25, 783.99, 0.0, 1046.5, 783.99, 622.25, 0.0, 523.25, 622.25, 783.99, 0.0, 932.33, 783.99, 622.25, 0.0,
			830.61, 1046.5, 1244.5, 0.0, 1046.5, 830.61, 622.25, 0.0, 830.61, 1046.5, 1244.5, 0.0, 1396.9, 1244.5, 1046.5, 0.0,
			932.33, 1174.7, 1396.9, 0.0, 1174.7, 932.33, 698.46, 0.0, 932.33, 1174.7, 1396.9, 0.0, 1568.0, 1396.9, 1174.7, 0.0,
			783.99, 987.77, 1174.7, 0.0, 1568.0, 1396.9, 1174.7, 0.0, 987.77, 1174.7, 1396.9, 0.0, 1568.0, 1396.9, 1174.7, 0.0,
		],
	},
	7: { # Crimson Shrine: 180 BPM, B Phrygian (Bm - C - D - Am)
		"bpm": 180.0,
		"roots": [61.74, 65.41, 73.42, 55.00],
		"lead": [
			493.88, 0.0, 523.25, 0.0, 659.25, 0.0, 783.99, 0.0, 987.77, 0.0, 783.99, 0.0, 659.25, 0.0, 523.25, 0.0,
			523.25, 0.0, 659.25, 0.0, 783.99, 0.0, 1046.5, 0.0, 987.77, 0.0, 783.99, 0.0, 659.25, 0.0, 523.25, 0.0,
			587.33, 0.0, 739.99, 0.0, 880.00, 0.0, 1174.7, 0.0, 1046.5, 0.0, 880.00, 0.0, 739.99, 0.0, 587.33, 0.0,
			440.00, 0.0, 523.25, 0.0, 659.25, 0.0, 880.00, 0.0, 987.77, 0.0, 880.00, 0.0, 783.99, 659.25, 523.25, 0.0,
		],
	},
	8: { # Void Overpass: 184 BPM, C# Minor (C#m - A - B - G#m)
		"bpm": 184.0,
		"roots": [69.30, 55.00, 61.74, 103.83],
		"lead": [
			554.37, 659.25, 830.61, 0.0, 1108.7, 830.61, 659.25, 0.0, 554.37, 659.25, 830.61, 0.0, 987.77, 830.61, 659.25, 0.0,
			440.00, 554.37, 659.25, 0.0, 880.00, 659.25, 554.37, 0.0, 440.00, 554.37, 659.25, 0.0, 830.61, 659.25, 554.37, 0.0,
			493.88, 622.25, 739.99, 0.0, 987.77, 739.99, 622.25, 0.0, 493.88, 622.25, 739.99, 0.0, 932.33, 739.99, 622.25, 0.0,
			830.61, 987.77, 1244.5, 0.0, 1661.2, 1480.0, 1244.5, 0.0, 987.77, 1244.5, 1480.0, 0.0, 1661.2, 1480.0, 1244.5, 0.0,
		],
	},
	9: { # Eclipse Finale: 190 BPM, D Minor / Harmonic Finale (Dm - Bb - Gm - A)
		"bpm": 190.0,
		"roots": [73.42, 58.27, 98.00, 110.00],
		"lead": [
			587.33, 698.46, 880.00, 0.0, 1174.7, 880.00, 698.46, 0.0, 587.33, 698.46, 880.00, 0.0, 1046.5, 880.00, 698.46, 0.0,
			466.16, 587.33, 698.46, 0.0, 932.33, 698.46, 587.33, 0.0, 466.16, 587.33, 698.46, 0.0, 880.00, 698.46, 587.33, 0.0,
			783.99, 932.33, 1174.7, 0.0, 1568.0, 1396.9, 1174.7, 0.0, 932.33, 1174.7, 1396.9, 0.0, 1568.0, 1396.9, 1174.7, 0.0,
			880.00, 1108.7, 1318.5, 0.0, 1760.0, 1568.0, 1318.5, 0.0, 1108.7, 1318.5, 1568.0, 0.0, 1760.0, 1568.0, 1318.5, 0.0,
		],
	},
}

func set_stage(stage_id: int) -> void:
	_stage_id = clampi(stage_id, 1, 9)
	_step_idx = 0

func set_progress(pct: float) -> void:
	_progress = clampf(pct, 0.0, 1.0)

func _ready() -> void:
	_delay_buf.resize(DELAY_SAMPLES)
	_delay_buf.fill(0.0)

	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		var stream := AudioStreamGenerator.new()
		stream.mix_rate = SAMPLE_RATE
		stream.buffer_length = 0.35
		p.stream = stream
		p.volume_db = -5.0
		add_child(p)
		_sfx_players.append(p)

	_bgm_player = AudioStreamPlayer.new()
	var bgm_stream := AudioStreamGenerator.new()
	bgm_stream.mix_rate = SAMPLE_RATE
	bgm_stream.buffer_length = 0.09
	_bgm_player.stream = bgm_stream
	_bgm_player.volume_db = -8.0
	add_child(_bgm_player)
	_bgm_player.play()
	_bgm_pb = _bgm_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _process(_delta: float) -> void:
	if _bgm_pb == null or muted:
		return
	var frames := _bgm_pb.get_frames_available()
	if frames <= 0:
		return

	var track: Dictionary = TRACKS.get(_stage_id, TRACKS[1])
	var base_bpm: float = track["bpm"]

	var tier := 0
	var key_mult := 1.0
	var bpm := base_bpm
	if _progress >= 0.75:
		tier = 3
		key_mult = 1.12246 # +2 semitones climax lift (clean & musical!)
		bpm = base_bpm + 8.0
	elif _progress >= 0.50:
		tier = 2
		bpm = base_bpm + 4.0
	elif _progress >= 0.25:
		tier = 1

	var step_dur := (60.0 / bpm) / 4.0
	var dt := 1.0 / SAMPLE_RATE
	var roots: Array = track["roots"]
	var lead_arr: Array = track["lead"]

	for i in frames:
		_bgm_time += dt
		if _bgm_time >= step_dur:
			_bgm_time -= step_dur
			_step_idx = (_step_idx + 1) % 64
			var s16 := _step_idx % 16

			# Four-on-the-floor punchy kick + syncopated double kick in higher tiers
			var kick_hit := s16 in [0, 4, 8, 12]
			if tier >= 2 and s16 == 14:
				kick_hit = true
			if kick_hit:
				_kick_env = 1.0
				_kick_phase = 0.0

			# Snare on beats 2 & 4 (steps 4 and 12)
			if tier >= 1 and (s16 in [4, 12] or (tier == 3 and _step_idx == 63)):
				_snare_env = 1.0
				_snare_body_phase = 0.0

			# Crisp off-beat / 16th-note hi-hats
			if s16 % 4 == 2:
				_hat_env = 0.65
			elif tier >= 1 and s16 % 2 == 1:
				_hat_env = 0.28

		var s16 := _step_idx % 16
		var bar := _step_idx / 16
		var root_freq: float = float(roots[bar]) * key_mult

		# 1. Punchy Analog Sub-Kick
		var kick_s := 0.0
		if _kick_env > 0.001:
			var k_freq := 46.0 + 135.0 * pow(_kick_env, 3.0)
			_kick_phase += (k_freq / SAMPLE_RATE) * TAU
			kick_s = sin(_kick_phase) * _kick_env * 0.62
			_kick_env *= 0.9978

		# Sidechain pump: bass & pads duck smoothly when kick hits!
		var sidechain := 1.0 - clampf(_kick_env * 0.72, 0.0, 0.72)

		# 2. Snare (200Hz body + low-passed noise snap)
		var snare_s := 0.0
		if _snare_env > 0.001:
			_snare_body_phase += (185.0 / SAMPLE_RATE) * TAU
			var body := sin(_snare_body_phase) * 0.45
			var raw_n := randf_range(-1.0, 1.0)
			_snare_lpf = lerpf(_snare_lpf, raw_n, 0.28)
			snare_s = (body + _snare_lpf * 0.75) * _snare_env * 0.34
			_snare_env *= 0.9968

		# 3. Crisp High-Passed Hi-Hat
		var hat_s := 0.0
		if _hat_env > 0.001:
			var n := randf_range(-1.0, 1.0)
			var hp := n - _hat_prev
			_hat_prev = n
			hat_s = hp * _hat_env * 0.14
			_hat_env *= 0.992

		# 4. Warm Filtered Supersaw Bass (rolling 16th-note octave groove)
		var b_freq := root_freq * (2.0 if (s16 % 4 == 2 or (tier >= 2 and s16 % 4 == 3)) else 1.0)
		_bass_p1 += (b_freq / SAMPLE_RATE) * TAU
		_bass_p2 += ((b_freq * 1.006) / SAMPLE_RATE) * TAU
		var saw1 := 2.0 * fmod(_bass_p1 / TAU, 1.0) - 1.0
		var saw2 := 2.0 * fmod(_bass_p2 / TAU, 1.0) - 1.0
		var b_env := 1.0 - (_bgm_time / step_dur) * 0.42
		var raw_bass := (saw1 + saw2) * 0.5 * b_env
		var bass_cutoff := 0.09 + 0.06 * float(tier)
		_bass_lpf = lerpf(_bass_lpf, raw_bass, bass_cutoff)
		var bass_s := _bass_lpf * sidechain * 0.42

		# 5. Warm Lush Pad Chords (root + minor 3rd + 5th)
		var pad_s := 0.0
		if tier >= 1:
			var p_root := root_freq * 2.0
			_pad_p1 += (p_root / SAMPLE_RATE) * TAU
			_pad_p2 += ((p_root * 1.1892) / SAMPLE_RATE) * TAU # Minor 3rd
			_pad_p3 += ((p_root * 1.4983) / SAMPLE_RATE) * TAU # Perfect 5th
			pad_s = (sin(_pad_p1) + sin(_pad_p2) + sin(_pad_p3)) * 0.055 * sidechain

		# 6. Expressive Detuned Lead Synth + Stereo-style Circular Delay
		var lead_dry := 0.0
		if tier >= 1:
			var lf: float = float(lead_arr[_step_idx]) * key_mult
			if lf > 0.0:
				_lead_p1 += (lf / SAMPLE_RATE) * TAU
				_lead_p2 += ((lf * 1.005) / SAMPLE_RATE) * TAU
				var l_saw := (2.0 * fmod(_lead_p1 / TAU, 1.0) - 1.0) + (2.0 * fmod(_lead_p2 / TAU, 1.0) - 1.0)
				var l_env := 1.0 - (_bgm_time / step_dur) * 0.55
				_lead_lpf = lerpf(_lead_lpf, l_saw * 0.5, 0.18 + 0.06 * float(tier))
				lead_dry = _lead_lpf * l_env * (0.16 if tier == 1 else 0.22)

		var delayed: float = _delay_buf[_delay_idx]
		_delay_buf[_delay_idx] = lead_dry + delayed * 0.36
		_delay_idx = (_delay_idx + 1) % DELAY_SAMPLES

		var mix_l := clampf(kick_s + snare_s + hat_s + bass_s + pad_s + lead_dry + delayed * 0.45, -0.95, 0.95)
		var mix_r := clampf(kick_s + snare_s + hat_s + bass_s + pad_s + lead_dry * 0.85 + delayed * 0.65, -0.95, 0.95)
		_bgm_pb.push_frame(Vector2(mix_l, mix_r))

func _get_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	return _sfx_players[0]

func _play_layer(freq_start: float, freq_end: float, duration: float, wave: String = "triangle", gain: float = 0.35, harm_ratio: float = 0.0) -> void:
	if muted:
		return
	var p := _get_player()
	p.play()
	var pb := p.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return

	var total_samples := int(SAMPLE_RATE * duration)
	var count := mini(total_samples, pb.get_frames_available())
	var phase := 0.0
	var phase2 := 0.0

	for i in count:
		var t := float(i) / float(maxi(1, total_samples))
		var freq := lerpf(freq_start, freq_end, t)
		phase += (freq / SAMPLE_RATE) * TAU
		var env := pow(1.0 - t, 1.4) * gain
		var sample := 0.0
		match wave:
			"sine":
				sample = sin(phase)
			"square":
				sample = 1.0 if sin(phase) >= 0.0 else -1.0
			"saw":
				sample = 2.0 * fmod(phase / TAU, 1.0) - 1.0
			"noise":
				sample = randf_range(-1.0, 1.0)
			_:
				sample = 2.0 * absf(2.0 * fmod(phase / TAU, 1.0) - 1.0) - 1.0

		if harm_ratio > 0.0:
			phase2 += ((freq * harm_ratio) / SAMPLE_RATE) * TAU
			sample = sample * 0.65 + sin(phase2) * 0.35

		pb.push_frame(Vector2(sample * env, sample * env))

func play_jump() -> void:
	_play_layer(280.0, 620.0, 0.10, "triangle", 0.32, 2.0)

func play_double_jump() -> void:
	_play_layer(440.0, 920.0, 0.12, "sine", 0.30, 1.5)

func play_boost() -> void:
	_play_layer(320.0, 1180.0, 0.18, "saw", 0.28, 1.5)

func play_slash() -> void:
	_play_layer(1450.0, 420.0, 0.09, "noise", 0.32)
	_play_layer(1980.0, 1120.0, 0.11, "sine", 0.22, 2.7)

func play_kill() -> void:
	_play_layer(140.0, 55.0, 0.12, "saw", 0.30)
	_play_layer(660.0, 1320.0, 0.14, "triangle", 0.26, 1.5)

func play_deflect() -> void:
	_play_layer(1280.0, 2150.0, 0.11, "sine", 0.32, 2.5)

func play_shoot() -> void:
	_play_layer(480.0, 110.0, 0.09, "saw", 0.22)
	_play_layer(900.0, 200.0, 0.05, "noise", 0.14)

func play_death() -> void:
	_play_layer(240.0, 42.0, 0.28, "saw", 0.40, 0.5)
	_play_layer(600.0, 80.0, 0.22, "noise", 0.24)

func play_win() -> void:
	var notes: Array[float] = [587.33, 659.25, 783.99, 880.0, 1174.66]
	for idx in notes.size():
		var freq: float = notes[idx]
		get_tree().create_timer(idx * 0.08).timeout.connect(func():
			_play_layer(freq, freq * 1.01, 0.22, "triangle", 0.32, 2.0)
		)
