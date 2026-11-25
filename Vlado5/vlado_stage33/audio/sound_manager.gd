class_name SoundManager
extends Node

const SAMPLE_RATE := 22050

var _streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0
var _wind_player: AudioStreamPlayer
var _river_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()

func _exit_tree() -> void:
	for p in _sfx_players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
			p.free()
	if _wind_player:
		_wind_player.stop()
		_wind_player.stream = null
		_wind_player.free()
	if _river_player:
		_river_player.stop()
		_river_player.stream = null
		_river_player.free()
	_wind_player = null
	_river_player = null
	_sfx_players.clear()
	_streams.clear()

func _ready() -> void:
	_rng.seed = 195308
	_build_streams()

	for _i in 10:
		var p := AudioStreamPlayer.new()
		p.max_polyphony = 2
		add_child(p)
		_sfx_players.append(p)

	_wind_player = AudioStreamPlayer.new()
	_wind_player.stream = _streams["wind"]
	_wind_player.volume_db = -18.0
	add_child(_wind_player)
	_wind_player.play()

	_river_player = AudioStreamPlayer.new()
	_river_player.stream = _streams["river"]
	_river_player.volume_db = -26.0
	add_child(_river_player)
	_river_player.play()

func update_ambience(river_dist_m: float, wind_strength: float = 1.0) -> void:
	if _wind_player:
		_wind_player.volume_db = clampf(-20.0 + 4.0 * wind_strength, -28.0, -10.0)
	if _river_player:
		var near_f := 1.0 - clampf((river_dist_m - 5.0) / 45.0, 0.0, 1.0)
		_river_player.volume_db = lerpf(-38.0, -13.0, near_f)

func play_rifle_shot() -> void:
	_play_stream("shot", -1.5, _rng.randf_range(0.96, 1.04))

func play_smg_shot() -> void:
	_play_stream("shot_smg", -3.0, _rng.randf_range(0.97, 1.05))

func play_mg_shot() -> void:
	_play_stream("shot_mg", -2.0, _rng.randf_range(0.95, 1.02))

func play_revolver_shot() -> void:
	_play_stream("shot_revolver", -1.2, _rng.randf_range(0.96, 1.04))

func play_pistol_shot() -> void:
	_play_stream("shot_pistol", -2.6, _rng.randf_range(0.97, 1.05))

func play_shotgun_shot() -> void:
	_play_stream("shot_shotgun", -0.5, _rng.randf_range(0.94, 1.03))

func play_explosion() -> void:
	_play_stream("explosion", 0.0, _rng.randf_range(0.92, 1.04))

func play_melee_swing() -> void:
	_play_stream("melee", -5.0, _rng.randf_range(0.95, 1.06))

func play_revolver_reload() -> void:
	_play_stream("reload_revolver", -5.0, 1.0)

func play_bolt_cycle() -> void:
	_play_stream("bolt", -7.0, _rng.randf_range(0.97, 1.03))

func play_reload() -> void:
	_play_stream("reload", -6.0, 1.0)

func play_dry_fire() -> void:
	_play_stream("dry", -8.0, 1.0)

func play_equip(is_equip: bool) -> void:
	_play_stream("equip", -9.0, 1.06 if is_equip else 0.90)

func play_hit(surface: String) -> void:
	match surface:
		"metal":
			_play_stream("hit_metal", -4.0, _rng.randf_range(0.95, 1.06))
		"wood":
			_play_stream("hit_wood", -5.5, _rng.randf_range(0.92, 1.08))
		"stone":
			_play_stream("hit_stone", -7.0, _rng.randf_range(0.90, 1.12))
		_:
			_play_stream("hit_dirt", -10.0, _rng.randf_range(0.90, 1.10))

func play_footstep(surface: String, intensity: float = 1.0) -> void:
	var key := "step_dirt"
	var db := -14.0
	match surface:
		"water":
			key = "step_water"
			db = -11.0
		"wood":
			key = "step_wood"
			db = -12.5
		"stone":
			key = "step_stone"
			db = -13.0
		"grass":
			key = "step_grass"
			db = -15.5
	db += clampf((intensity - 1.0) * 4.5, -5.0, 4.0)
	_play_stream(key, db, _rng.randf_range(0.88, 1.14))

func _play_stream(key: String, db: float, pitch: float) -> void:
	if not _streams.has(key) or _sfx_players.is_empty():
		return
	var p := _sfx_players[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_players.size()
	p.stream = _streams[key]
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()

func _make_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32760.0)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

func _build_streams() -> void:
	# 1. M48 / Full Rifle Shot + Valley Echo
	var shot_n := int(SAMPLE_RATE * 1.15)
	var shot_s := PackedFloat32Array()
	shot_s.resize(shot_n)
	var lp := 0.0
	for i in shot_n:
		var t := float(i) / float(SAMPLE_RATE)
		var n := _rng.randf_range(-1.0, 1.0)
		var crack := exp(-t * 58.0) * n * 0.95
		var thump := exp(-t * 22.0) * sin(TAU * lerpf(165.0, 48.0, minf(t * 9.0, 1.0)) * t) * 0.85
		lp = lerpf(lp, n, 0.14)
		var echo1 := exp(-maxf(t - 0.16, 0.0) * 6.5) * lp * 0.34 if t > 0.16 else 0.0
		var echo2 := exp(-maxf(t - 0.38, 0.0) * 4.5) * lp * 0.20 if t > 0.38 else 0.0
		shot_s[i] = clampf((crack + thump + echo1 + echo2) * 0.85, -1.0, 1.0)
	_streams["shot"] = _make_wav(shot_s)

	# 1b. Crnogorski Gaser 11.2mm Revolver Shot (heavy low-mid punch + metallic hammer click + canyon slap)
	var rev_n := int(SAMPLE_RATE * 0.78)
	var rev_s := PackedFloat32Array()
	rev_s.resize(rev_n)
	lp = 0.0
	for i in rev_n:
		var t := float(i) / float(SAMPLE_RATE)
		var n := _rng.randf_range(-1.0, 1.0)
		var hammer := exp(-t * 260.0) * sin(TAU * 2800.0 * t) * 0.35
		var blast := exp(-t * 42.0) * n * 0.98
		var boom := exp(-t * 19.0) * sin(TAU * lerpf(210.0, 56.0, minf(t * 14.0, 1.0)) * t) * 0.92
		lp = lerpf(lp, n, 0.16)
		var echo := exp(-maxf(t - 0.13, 0.0) * 9.0) * lp * 0.28 if t > 0.13 else 0.0
		rev_s[i] = clampf((hammer + blast + boom + echo) * 0.88, -1.0, 1.0)
	_streams["shot_revolver"] = _make_wav(rev_s)

	# 1c. Semi-auto Pistol (9mm / 7.62mm crisp snap)
	var pis_n := int(SAMPLE_RATE * 0.48)
	var pis_s := PackedFloat32Array()
	pis_s.resize(pis_n)
	lp = 0.0
	for i in pis_n:
		var t := float(i) / float(SAMPLE_RATE)
		var n := _rng.randf_range(-1.0, 1.0)
		var snap := exp(-t * 74.0) * n * 0.92
		var punch := exp(-t * 36.0) * sin(TAU * lerpf(280.0, 95.0, minf(t * 18.0, 1.0)) * t) * 0.65
		lp = lerpf(lp, n, 0.24)
		var tail := exp(-maxf(t - 0.08, 0.0) * 16.0) * lp * 0.20 if t > 0.08 else 0.0
		pis_s[i] = clampf((snap + punch + tail) * 0.82, -1.0, 1.0)
	_streams["shot_pistol"] = _make_wav(pis_s)

	# 1d. 12GA Shotgun Blast (wide roar + deep chest thump + valley echo)
	var sh_n := int(SAMPLE_RATE * 1.10)
	var sh_s := PackedFloat32Array()
	sh_s.resize(sh_n)
	lp = 0.0
	for i in sh_n:
		var t := float(i) / float(SAMPLE_RATE)
		var n := _rng.randf_range(-1.0, 1.0)
		var roar := exp(-t * 28.0) * n * 1.10
		var sub := exp(-t * 14.0) * sin(TAU * lerpf(150.0, 38.0, minf(t * 8.0, 1.0)) * t) * 1.05
		lp = lerpf(lp, n, 0.12)
		var echo := exp(-maxf(t - 0.18, 0.0) * 6.0) * lp * 0.36 if t > 0.18 else 0.0
		sh_s[i] = clampf((roar + sub + echo) * 0.90, -1.0, 1.0)
	_streams["shot_shotgun"] = _make_wav(sh_s)

	# 1e. Grenade Explosion
	var exp_n := int(SAMPLE_RATE * 1.65)
	var exp_s := PackedFloat32Array()
	exp_s.resize(exp_n)
	lp = 0.0
	for i in exp_n:
		var t := float(i) / float(SAMPLE_RATE)
		var n := _rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, n, 0.09)
		var shock := exp(-t * 12.0) * n * 1.15
		var rumble := exp(-t * 4.5) * sin(TAU * lerpf(95.0, 26.0, minf(t * 3.5, 1.0)) * t) * 1.10
		var debris := exp(-t * 5.2) * lp * 0.65
		exp_s[i] = clampf((shock + rumble + debris) * 0.92, -1.0, 1.0)
	_streams["explosion"] = _make_wav(exp_s)

	# 1f. Melee Slash
	var mel_n := int(SAMPLE_RATE * 0.24)
	var mel_s := PackedFloat32Array()
	mel_s.resize(mel_n)
	lp = 0.0
	for i in mel_n:
		var t := float(i) / float(SAMPLE_RATE)
		lp = lerpf(lp, _rng.randf_range(-1.0, 1.0), 0.32)
		var env := sin(PI * clampf(t / 0.24, 0.0, 1.0))
		var ring := exp(-absf(t - 0.11) * 70.0) * sin(TAU * 2400.0 * t) * 0.28
		mel_s[i] = clampf(env * lp * 0.65 + ring, -1.0, 1.0)
	_streams["melee"] = _make_wav(mel_s)

	# 2. Bolt Cycle
	var bolt_n := int(SAMPLE_RATE * 0.30)
	var bolt_s := PackedFloat32Array()
	bolt_s.resize(bolt_n)
	for i in bolt_n:
		var t := float(i) / float(SAMPLE_RATE)
		var cl1 := exp(-absf(t - 0.04) * 140.0) * sin(TAU * 1650.0 * t) * 0.45
		var slide := exp(-absf(t - 0.12) * 35.0) * _rng.randf_range(-0.3, 0.3)
		var cl2 := exp(-absf(t - 0.22) * 120.0) * sin(TAU * 1280.0 * t) * 0.50
		bolt_s[i] = clampf(cl1 + slide + cl2, -1.0, 1.0)
	_streams["bolt"] = _make_wav(bolt_s)

	# 3. Reload Stripper Clip + Lock
	var rel_n := int(SAMPLE_RATE * 0.55)
	var rel_s := PackedFloat32Array()
	rel_s.resize(rel_n)
	for i in rel_n:
		var t := float(i) / float(SAMPLE_RATE)
		var c1 := exp(-absf(t - 0.07) * 110.0) * sin(TAU * 1400.0 * t) * 0.45
		var c2 := exp(-absf(t - 0.22) * 80.0) * (_rng.randf_range(-0.3, 0.3) + 0.35 * sin(TAU * 920.0 * t))
		var c3 := exp(-absf(t - 0.40) * 120.0) * sin(TAU * 1800.0 * t) * 0.55
		rel_s[i] = clampf(c1 + c2 + c3, -1.0, 1.0)
	_streams["reload"] = _make_wav(rel_s)

	# 3b. Revolver Cylinder Spin + Gate Click
	var rrel_n := int(SAMPLE_RATE * 0.65)
	var rrel_s := PackedFloat32Array()
	rrel_s.resize(rrel_n)
	for i in rrel_n:
		var t := float(i) / float(SAMPLE_RATE)
		var gate := exp(-absf(t - 0.06) * 140.0) * sin(TAU * 1950.0 * t) * 0.50
		var ratchet := 0.0
		for k in 6:
			var tk := 0.14 + float(k) * 0.065
			ratchet += exp(-absf(t - tk) * 220.0) * sin(TAU * (2400.0 + float(k) * 90.0) * t) * 0.38
		var close_lock := exp(-absf(t - 0.56) * 140.0) * sin(TAU * 1550.0 * t) * 0.58
		rrel_s[i] = clampf(gate + ratchet + close_lock, -1.0, 1.0)
	_streams["reload_revolver"] = _make_wav(rrel_s)

	# 4. Dry Fire
	var dry_n := int(SAMPLE_RATE * 0.08)
	var dry_s := PackedFloat32Array()
	dry_s.resize(dry_n)
	for i in dry_n:
		var t := float(i) / float(SAMPLE_RATE)
		dry_s[i] = exp(-t * 90.0) * (sin(TAU * 2200.0 * t) * 0.4 + _rng.randf_range(-0.25, 0.25))
	_streams["dry"] = _make_wav(dry_s)

	# 5. Equip Rustle
	var eq_n := int(SAMPLE_RATE * 0.24)
	var eq_s := PackedFloat32Array()
	eq_s.resize(eq_n)
	lp = 0.0
	for i in eq_n:
		var t := float(i) / float(SAMPLE_RATE)
		lp = lerpf(lp, _rng.randf_range(-1.0, 1.0), 0.22)
		var clack := exp(-absf(t - 0.14) * 110.0) * sin(TAU * 720.0 * t) * 0.35
		eq_s[i] = clampf(sin(PI * t / 0.24) * lp * 0.45 + clack, -1.0, 1.0)
	_streams["equip"] = _make_wav(eq_s)

	# 6. Hits (Metal, Wood, Stone, Dirt)
	var hit_n := int(SAMPLE_RATE * 0.48)
	var hm := PackedFloat32Array()
	var hw := PackedFloat32Array()
	var hs := PackedFloat32Array()
	var hd := PackedFloat32Array()
	hm.resize(hit_n)
	hw.resize(hit_n)
	hs.resize(hit_n)
	hd.resize(hit_n)
	for i in hit_n:
		var t := float(i) / float(SAMPLE_RATE)
		hm[i] = exp(-t * 7.5) * (0.45 * sin(TAU * 890.0 * t) + 0.35 * sin(TAU * 1345.0 * t) + 0.20 * sin(TAU * 2110.0 * t))
		hw[i] = exp(-t * 28.0) * (0.65 * sin(TAU * 260.0 * t) + 0.35 * _rng.randf_range(-1.0, 1.0) * exp(-t * 45.0))
		hs[i] = exp(-t * 20.0) * (0.45 * sin(TAU * lerpf(2400.0, 950.0, minf(t * 8.0, 1.0)) * t) + 0.35 * _rng.randf_range(-1.0, 1.0))
		hd[i] = exp(-t * 36.0) * _rng.randf_range(-0.6, 0.6)
	_streams["hit_metal"] = _make_wav(hm)
	_streams["hit_wood"] = _make_wav(hw)
	_streams["hit_stone"] = _make_wav(hs)
	_streams["hit_dirt"] = _make_wav(hd)

	# 7. Footsteps (Dirt, Grass, Wood, Stone, Water)
	var st_n := int(SAMPLE_RATE * 0.16)
	for kind in ["step_dirt", "step_grass", "step_wood", "step_stone", "step_water"]:
		var arr := PackedFloat32Array()
		arr.resize(st_n)
		lp = 0.0
		for i in st_n:
			var t := float(i) / float(SAMPLE_RATE)
			var env := exp(-t * (28.0 if kind == "step_water" else 42.0))
			var n := _rng.randf_range(-1.0, 1.0)
			lp = lerpf(lp, n, 0.24 if kind == "step_grass" else 0.45)
			var tone := 0.0
			if kind == "step_wood":
				tone = sin(TAU * 175.0 * t) * 0.55
			elif kind == "step_stone":
				tone = sin(TAU * 420.0 * t) * 0.40
			elif kind == "step_dirt":
				tone = sin(TAU * 115.0 * t) * 0.35
			elif kind == "step_water":
				tone = lp * 0.8 + sin(TAU * 320.0 * t) * 0.15
			arr[i] = clampf(env * (lp * 0.55 + tone), -1.0, 1.0)
		_streams[kind] = _make_wav(arr)

	# 8. Continuous Ambience Loops (2.0s Wind & River)
	var amb_n := SAMPLE_RATE * 2
	var wind_s := PackedFloat32Array()
	var riv_s := PackedFloat32Array()
	wind_s.resize(amb_n)
	riv_s.resize(amb_n)
	var w_lp := 0.0
	var r_lp := 0.0
	for i in amb_n:
		var t := float(i) / float(SAMPLE_RATE)
		var gust := 0.65 + 0.35 * sin(TAU * t * 0.5)
		w_lp = lerpf(w_lp, _rng.randf_range(-1.0, 1.0), 0.025)
		r_lp = lerpf(r_lp, _rng.randf_range(-1.0, 1.0), 0.16)
		wind_s[i] = clampf(w_lp * gust * 1.4, -1.0, 1.0)
		riv_s[i] = clampf((r_lp * 0.85 + 0.15 * sin(TAU * t * 3.0) * r_lp), -1.0, 1.0)
	var fade_n := int(SAMPLE_RATE * 0.15)
	for i in fade_n:
		var k := float(i) / float(fade_n)
		wind_s[i] = lerpf(wind_s[amb_n - fade_n + i], wind_s[i], k)
		riv_s[i] = lerpf(riv_s[amb_n - fade_n + i], riv_s[i], k)

	# 4b. Stage 3.3 — MP40
	var smg_n := int(SAMPLE_RATE * 0.34)
	var smg_s := PackedFloat32Array()
	smg_s.resize(smg_n)
	var smg_lp := 0.0
	for i in smg_n:
		var t := float(i) / float(SAMPLE_RATE)
		var n := _rng.randf_range(-1.0, 1.0)
		var crack := exp(-t * 88.0) * n * 0.90
		var body := exp(-t * 46.0) * sin(TAU * lerpf(240.0, 105.0, minf(t * 22.0, 1.0)) * t) * 0.55
		smg_lp = lerpf(smg_lp, n, 0.30)
		var tail := exp(-maxf(t - 0.05, 0.0) * 24.0) * smg_lp * 0.22 if t > 0.05 else 0.0
		var mech := exp(-absf(t - 0.14) * 120.0) * sin(TAU * 1450.0 * t) * 0.16
		smg_s[i] = clampf((crack + body + tail + mech) * 0.80, -1.0, 1.0)
	_streams["shot_smg"] = _make_wav(smg_s)

	# 4c. Stage 3.3 — MG42
	var mg_n := int(SAMPLE_RATE * 0.52)
	var mg_s := PackedFloat32Array()
	mg_s.resize(mg_n)
	var mg_lp := 0.0
	for i in mg_n:
		var t := float(i) / float(SAMPLE_RATE)
		var n := _rng.randf_range(-1.0, 1.0)
		var crack := exp(-t * 46.0) * n * 1.05
		var thump := exp(-t * 17.0) * sin(TAU * lerpf(190.0, 42.0, minf(t * 11.0, 1.0)) * t) * 0.95
		mg_lp = lerpf(mg_lp, n, 0.10)
		var ehco := exp(-maxf(t - 0.10, 0.0) * 8.0) * mg_lp * 0.30 if t > 0.10 else 0.0
		var belt := exp(-absf(t - 0.26) * 60.0) * _rng.randf_range(-0.18, 0.18)
		mg_s[i] = clampf((crack + thump + ehco + belt) * 0.88, -1.0, 1.0)
	_streams["shot_mg"] = _make_wav(mg_s)

	_streams["wind"] = _make_wav(wind_s, true)
	_streams["river"] = _make_wav(riv_s, true)
