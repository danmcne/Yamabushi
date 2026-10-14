extends Sound
## Yamabushi's sounds: Shikigami's synthesizer (game/audio/sound.gd, vendored
## unchanged) with the road's own sounds added. Nothing recorded is shipped,
## and there are no voices: a town's alarm is its fire bell and the watch's
## clappers, not a scream.
##
## Three kinds of sound, all made the first time they are wanted:
##   effects  one-off sounds, named in EFFECTS (Shikigami's own as well);
##   loops    ambience that runs while its place is near: LOOPS;
##   tunes    music, each a few stems of one length that play together, so a
##            tune can thicken as tension rises: TUNES (stem k is "tune/k").
##
## The day is in the bright yo scale, the night in Shikigami's dark hirajōshi.

## D yo: D, E, G, A, B.
const YO := [146.83, 164.81, 196.0, 220.0, 246.94]
const IN := Sound.SCALE

## Every effect, Shikigami's and the road's.
const EFFECTS := ["bell", "gong", "hit", "hit_heavy", "block", "tick",
	"staff", "kanabo", "hurt", "hurt_oni", "crash", "collapse", "ignite", "clappers", "alarm", "clack", "fire_bell",
	"roar", "transform", "dawn", "rin", "chime", "chomp", "gulp", "gulp_oni", "puff", "horagai", "ofuda", "summon",
	"splash", "goma"]
const LOOPS := ["wind", "water", "insects", "fire"]
## Each tune's stems, in the order they are layered in as tension rises.
const TUNES := {
	"menu": 1,     # Shikigami's: the title and the map
	"fight": 1,    # Shikigami's: the rite
	"town": 2,     # a town by day: koto and a soft knock; the shakuhachi over them
	"trail": 2,    # a trail by day: a drone and a few koto notes; the shakuhachi
	"night": 3,    # the oni's night: drone and slow taiko; the shamisen; driving taiko and the noh flute
	"master": 2,   # the master exorcist: taiko and shamisen; the noh flute and kotsuzumi
}

var _pieces: Dictionary = {}   # tune -> its stems, once made


## Loops and stems loop; effects do not.
func stream(name: String) -> AudioStreamWAV:
	_mutex.lock()
	var have := _made.has(name)
	_mutex.unlock()
	if not have:
		var looped := name in LOOPS or name.contains("/") or name in ["menu", "fight"]
		var samples := _synth(name)
		if not looped:
			_fade_end(samples, 0.03)
		var w := _wav(samples, looped)
		_mutex.lock()
		_made[name] = w
		_mutex.unlock()
	return _made[name]

## Make every tune's stems in the background, ahead of need: one task a tune.
func prepare() -> void:
	for tune in TUNES:
		if not _making.has(tune) and not has_stream("%s/0" % tune):
			_making[tune] = WorkerThreadPool.add_task(_make_tune.bind(tune))

func _make_tune(tune: String) -> void:
	for k in TUNES[tune]:
		stream("%s/%d" % [tune, k])

## Whether a sound is made yet (the music waits for its tune's stems).
func has_stream(name: String) -> bool:
	_mutex.lock()
	var have := _made.has(name)
	_mutex.unlock()
	return have

func _process(_delta: float) -> void:
	for name in _making.keys():
		if WorkerThreadPool.is_task_completed(_making[name]):
			WorkerThreadPool.wait_for_task_completion(_making[name])
			_making.erase(name)


func _synth(name: String) -> PackedFloat32Array:
	if name.contains("/"):
		var parts := name.split("/")
		return _piece(parts[0])[int(parts[1])]
	match name:
		# ---- blows ----
		"staff":
			# the staff's knock, and its rings jingling
			var s := _silence(0.5)
			_add(s, _tone(0.12, 520.0, 0.02, 0.5), 0)
			_add(s, _crunch(0.06, 0.01, 0.5), 0)
			_add(s, _jingle(0.4, [2100.0, 2900.0, 3700.0], 6, 0.12), int(0.01 * RATE))
			return _normalised(s, 0.8)
		"kanabo":
			# iron on bone: a heavy thump and the club's clank
			var s2 := _strike(0.4, 70.0, 0.16, 0.05)
			_add(s2, _bell(620.0, 0.4, [1.0, 2.7], [0.3, 0.2], [0.12, 0.06]), 0)
			return _normalised(s2, 0.9)
		"hurt":
			return _normalised(_strike(0.2, 120.0, 0.06, 0.02), 0.6)
		"hurt_oni":
			return _normalised(_strike(0.3, 70.0, 0.1, 0.03), 0.7)
		# ---- the town ----
		"crash":
			# wood splitting
			var c := _crunch(0.4, 0.08, 0.9)
			_add(c, _body(0.4, [180.0, 260.0, 410.0], 0.1, 0.4), 0)
			return _normalised(c, 0.85)
		"collapse":
			# a building coming down: a long rumble, beams cracking, debris after
			var d := _silence(1.6)
			_add(d, _rumble(1.4, 0.55, 0.8), 0)
			_add(d, _crunch(0.5, 0.12, 0.8), 0)
			for k in 5:
				_add(d, _crunch(0.12, 0.03, 0.5 - k * 0.07), int((0.25 + k * 0.17) * RATE))
			return _normalised(d, 0.9)
		"ignite":
			var i := _silence(0.9)
			_add(i, _whoosh(0.5, 200.0, 900.0), 0)
			_add(i, _crackle(0.8, 14.0, 0.5), int(0.1 * RATE))
			return _normalised(i, 0.75)
		"clack":
			# one strike of the watch's clappers (hyōshigi): what was that?
			return _normalised(_clap(0.6), 0.6)
		"clappers":
			# two strokes of the clappers
			var k2 := _silence(0.5)
			_add(k2, _clap(0.9), 0)
			_add(k2, _clap(0.8), int(0.2 * RATE))
			return _normalised(k2, 0.8)
		"alarm":
			# the watch beating the alarm: clappers, faster and faster
			var a := _silence(1.4)
			var at := 0.0
			var gap := 0.22
			for k in 8:
				_add(a, _clap(0.9 - k * 0.05), int(at * RATE))
				at += gap
				gap *= 0.82
			return _normalised(a, 0.85)
		"fire_bell":
			# the town's alarm bell (hanshō), struck three times: someone has seen the oni
			var fb := _silence(1.6)
			for k in 3:
				_add(fb, _bell(880.0, 1.0, [1.0, 2.4, 4.1], [1.0, 0.5, 0.25], [0.5, 0.25, 0.12]), int(k * 0.24 * RATE))
			return _normalised(fb, 0.8)
		# ---- the oni ----
		"roar":
			return _normalised(_roar(1.2), 0.9)
		"transform":
			# the seal giving way: a temple bell whose note sags, over a rumble
			var tr := _silence(3.2)
			_add(tr, _sagging_bell(110.0, 3.0), 0)
			_add(tr, _rumble(2.8, 0.6, 0.18), int(0.2 * RATE))
			return _normalised(tr, 0.9)
		# ---- the day ----
		"dawn":
			# a far temple bell
			return _normalised(_bell(196.0, 3.0, [1.0, 2.76, 5.40], [1.0, 0.4, 0.2], [2.4, 1.1, 0.5]), 0.5)
		"rin":
			# the bowl gong of prayer and of binding
			return _normalised(_bell(1046.5, 2.6, [1.0, 2.71, 5.1], [1.0, 0.4, 0.2], [2.0, 0.9, 0.4]), 0.55)
		"chime":
			# a spirit freed, rising away: three bowl notes up the scale
			var ch := _silence(2.4)
			for k in 3:
				_add(ch, _bell(YO[k + 2] * 4.0, 1.6, [1.0, 2.71], [1.0, 0.3], [1.0, 0.4]), int(k * 0.16 * RATE))
			return _normalised(ch, 0.5)
		"chomp":
			var e := _silence(0.4)
			for k in 2:
				_add(e, _crunch(0.1, 0.03, 0.6), int(k * 0.15 * RATE))
				_add(e, _body(0.1, [150.0], 0.03, 0.3), int(k * 0.15 * RATE))
			return _normalised(e, 0.6)
		"gulp":
			return _normalised(_gulps(240.0, 2), 0.55)
		"gulp_oni":
			return _normalised(_gulps(150.0, 3), 0.65)
		"puff":
			return _normalised(_whoosh(0.35, 150.0, 400.0), 0.35)
		# ---- the monk's kit and the spirits ----
		"horagai":
			return _normalised(_horagai(1.7), 0.85)
		"ofuda":
			# a slip of paper flicked, and its seal's small ring
			var o := _silence(0.8)
			_add(o, _whoosh(0.18, 1500.0, 3500.0), 0)
			_add(o, _bell(1760.0, 0.6, [1.0, 2.7], [0.6, 0.2], [0.3, 0.12]), int(0.12 * RATE))
			return _normalised(o, 0.55)
		"summon":
			# paper rustling and the small bells (suzu) of a shikigami
			var su := _silence(1.0)
			_add(su, _rustle(0.5), 0)
			_add(su, _jingle(0.9, [3100.0, 3600.0, 4200.0, 5000.0], 10, 0.18), int(0.05 * RATE))
			return _normalised(su, 0.6)
		"splash":
			var sp := _crunch(0.7, 0.2, 0.7)
			_add(sp, _rumble(0.6, 0.15, 0.4), 0)
			return _normalised(sp, 0.6)
		"goma":
			var g := _silence(2.6)
			_add(g, _whoosh(0.5, 200.0, 900.0), 0)
			_add(g, _crackle(1.6, 10.0, 0.4), int(0.1 * RATE))
			_add(g, _bell(1046.5, 2.2, [1.0, 2.71], [0.7, 0.3], [1.8, 0.8]), int(0.4 * RATE))
			return _normalised(g, 0.7)
		# ---- ambience ----
		"wind":
			return _seamless(_wind(8.0), 0.4)
		"water":
			return _seamless(_water(5.0), 0.3)
		"insects":
			return _seamless(_insects(6.0), 0.2)
		"fire":
			return _seamless(_fire_loop(5.0), 0.3)
	return super(name)


## Bring a one-off sound to silence over its last moments, so none ends in a click.
func _fade_end(s: PackedFloat32Array, seconds: float) -> void:
	var f := mini(int(seconds * RATE), s.size())
	for i in f:
		s[s.size() - f + i] *= 1.0 - float(i) / f


# ---------- voices of things ----------

## The hyōshigi: two blocks of hard wood struck together, high and dry.
func _clap(amp: float) -> PackedFloat32Array:
	var s := _tone(0.06, 2100.0, 0.007, 0.7 * amp)
	_add(s, _tone(0.06, 3300.0, 0.005, 0.4 * amp), 0)
	_add(s, _crunch(0.03, 0.004, 0.6 * amp), 0)
	return s

## Little bells: many short bright rings at the given pitches, scattered.
func _jingle(seconds: float, freqs: Array, count: int, decay: float) -> PackedFloat32Array:
	var s := _silence(seconds)
	for k in count:
		var f: float = freqs[randi() % freqs.size()] * randf_range(0.98, 1.02)
		var at := int(randf() * (seconds - decay * 2.0) * RATE)
		_add(s, _tone(decay * 2.0, f, decay * randf_range(0.5, 1.0), 0.25), at)
	return s

## Crackling: a fire's pops, `rate` a second, over its hiss.
func _crackle(seconds: float, rate: float, amp: float) -> PackedFloat32Array:
	var s := _silence(seconds)
	for k in int(seconds * rate):
		var at := int(randf() * seconds * RATE)
		_add(s, _crunch(0.03, randf_range(0.002, 0.008), amp * randf_range(0.3, 1.0)), at)
	return s

## Paper rustling: soft high noise in uneven little gusts.
func _rustle(seconds: float) -> PackedFloat32Array:
	var s := _crunch(seconds, seconds, 0.5)
	for i in s.size():
		var t := float(i) / RATE
		s[i] *= 0.5 + 0.5 * absf(sin(TAU * 11.0 * t + 3.0 * sin(TAU * 3.0 * t)))
	return s

## Swallowing: a few low bloops falling in pitch.
func _gulps(f: float, n: int) -> PackedFloat32Array:
	var s := _silence(0.25 * n + 0.2)
	for k in n:
		var g := PackedFloat32Array()
		g.resize(int(0.13 * RATE))
		var ph := 0.0
		for i in g.size():
			var t := float(i) / RATE
			ph += TAU * f * (1.0 - 1.8 * t) / RATE
			g[i] = 0.6 * sin(t / 0.13 * PI) * sin(ph)
		_add(s, g, int(k * 0.25 * RATE))
	return s

## The oni's roar: a low, rough, wavering tone over a growl of noise, falling.
func _roar(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var growl := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / 0.1, 1.0) * minf((seconds - t) / 0.5, 1.0)
		var f := 78.0 - 22.0 * t / seconds + 4.0 * sin(TAU * 6.0 * t)
		ph += TAU * f / RATE
		var tone := 0.0
		for k in range(1, 9):
			tone += sin(ph * k) / pow(k, 0.8)
		growl = lerpf(growl, randf() * 2.0 - 1.0, 0.04)
		var rasp := 0.6 + 0.4 * sin(TAU * 31.0 * t)
		out[i] = env * (0.45 * tone * rasp + 0.9 * growl * rasp)
	return out

## A temple bell whose note sags as it rings: the seal giving way.
func _sagging_bell(f0: float, seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ratios := [1.0, 2.76, 5.40]
	var amps := [1.0, 0.5, 0.25]
	var decays := [2.4, 1.2, 0.5]
	var phases := [0.0, 0.0, 0.0]
	for i in n:
		var t := float(i) / RATE
		var sag := 1.0 - 0.18 * t / seconds
		var v := 0.0
		for k in 3:
			phases[k] += TAU * f0 * ratios[k] * sag / RATE
			v += amps[k] * exp(-t / decays[k]) * sin(phases[k])
		out[i] = v * 0.35
	return out

## The horagai, the conch trumpet: a brassy, breathy horn note that swells up
## to its pitch and wavers as the breath runs out.
func _horagai(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var breath := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / 0.25, 1.0) * minf((seconds - t) / 0.35, 1.0)
		var f := 233.08 * (0.86 + 0.14 * minf(t / 0.25, 1.0)) * (1.0 + 0.006 * sin(TAU * 5.0 * t) * minf(t, 1.0))
		ph += TAU * f / RATE
		var v := 0.0
		for k in range(1, 7):
			v += sin(ph * k) / pow(k, 0.7)
		breath = lerpf(breath, randf() * 2.0 - 1.0, 0.3)
		out[i] = env * (0.3 * v + 0.25 * breath)
	return out


# ---------- ambience (loops) ----------

## Crossfade a loop's end over its start, so it repeats without a seam.
func _seamless(s: PackedFloat32Array, fade_seconds: float) -> PackedFloat32Array:
	var f := int(fade_seconds * RATE)
	var n := s.size() - f
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = s[i]
	for i in f:
		var w := float(i) / f
		out[i] = s[i] * w + s[n + i] * (1.0 - w)
	return out

## Wind: low noise through a band that wanders, in slow gusts.
func _wind(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 0.0
	var b := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := randf() * 2.0 - 1.0
		var band := 0.02 + 0.015 * sin(TAU * 0.13 * t)
		a = lerpf(a, x, band)
		b = lerpf(b, x, band * 0.25)
		var gust := 0.55 + 0.3 * sin(TAU * 0.19 * t) + 0.15 * sin(TAU * 0.47 * t + 1.0)
		out[i] = (a - b) * 6.0 * gust
	return _normalised(out, 0.6)

## Running water: a bright hiss with little burbles in it.
func _water(seconds: float) -> PackedFloat32Array:
	var out := _crunch(seconds, 1000.0, 0.25)
	for k in int(seconds * 9.0):
		var g := PackedFloat32Array()
		g.resize(int(0.05 * RATE))
		var f := randf_range(300.0, 900.0)
		var ph := 0.0
		for i in g.size():
			var t := float(i) / RATE
			ph += TAU * f * (1.0 + 4.0 * t) / RATE
			g[i] = 0.12 * sin(t / 0.05 * PI) * sin(ph)
		_add(out, g, int(randf() * seconds * RATE))
	return _normalised(out, 0.5)

## Night insects: bell crickets (suzumushi), high trills in short bursts.
func _insects(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for c in 2:
			var period := 0.9 if c == 0 else 1.3
			var on := fmod(t + c * 0.4, period) < 0.32
			if on:
				v += sin(TAU * (4200.0 - c * 600.0) * t) * (0.5 + 0.5 * sin(TAU * 40.0 * t))
		out[i] = 0.12 * v
	return out

## A fire: hiss, low roar and pops.
func _fire_loop(seconds: float) -> PackedFloat32Array:
	var out := _rumble(seconds, 1000.0, 0.25)
	_add(out, _crackle(seconds, 18.0, 0.45), 0)
	return _normalised(out, 0.6)


# ---------- music ----------

## A koto string: plucked, clear and ringing longer than the shamisen.
func _koto(f: float, seconds: float, amp := 0.4) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var period := maxi(int(RATE / f), 2)
	var line := PackedFloat32Array()
	line.resize(period)
	for i in period:
		line[i] = randf() * 2.0 - 1.0
	var k := 0
	for i in n:
		var cur := line[k]
		line[k] = 0.4993 * (cur + line[(k + 1) % period])
		k = (k + 1) % period
		out[i] = amp * cur * minf((seconds - float(i) / RATE) / 0.1, 1.0)
	return out

## The noh flute (nōkan): a shrill, breathy cry that leaps up to its note.
func _nokan(f: float, seconds: float, amp := 0.3) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var breath := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / 0.05, 1.0) * minf((seconds - t) / 0.2, 1.0)
		var leap := 1.0 + 0.5 * exp(-t / 0.08)   # the hishigi: a piercing start above the note
		ph += TAU * f * leap * (1.0 + 0.01 * sin(TAU * 6.5 * t)) / RATE
		breath = lerpf(breath, randf() * 2.0 - 1.0, 0.4)
		out[i] = amp * env * (sin(ph) + 0.25 * sin(3.0 * ph) + 0.6 * breath)
	return out

## A drone over a whole loop: each note rounded to a whole number of cycles in
## it, so the loop joins without a click, swelling slowly.
func _drone(freqs: Array, seconds: float, amp: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var fs: Array[float] = []
	for f in freqs:
		fs.append(round(f * seconds) / seconds)
	var swell: float = round(0.25 * seconds) / seconds
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in fs.size():
			v += sin(TAU * fs[k] * t) / (1.0 + k)
		out[i] = amp * (0.75 + 0.25 * sin(TAU * swell * t)) * v
	return out

## A tune's stems, made together from one seeded draw so they fit: see TUNES.
## Each is a loop of `bars` bars of eighth notes; a note running past the end
## wraps onto the start.
func _piece(tune: String) -> Array:
	_mutex.lock()
	var have: bool = _pieces.has(tune)
	_mutex.unlock()
	if have:
		return _pieces[tune]
	var stems: Array = []
	match tune:
		"menu", "fight":
			stems = [_ensemble(tune == "fight")]
		"town":
			stems = _town()
		"trail":
			stems = _trail()
		"night":
			stems = _night()
		"master":
			stems = _master()
	for k in stems.size():
		stems[k] = _normalised(stems[k], 0.8)
	_mutex.lock()
	_pieces[tune] = stems
	_mutex.unlock()
	return stems

func _notes(scale: Array, octaves: Array) -> Array[float]:
	var out: Array[float] = []
	for o in octaves:
		for f in scale:
			out.append(f * o)
	return out

## A wandering phrase: scale degrees (or -1, a rest) for `count` steps.
func _phrase(rng: RandomNumberGenerator, count: int, density: float, lo: int, hi: int, start: int) -> Array[int]:
	var out: Array[int] = []
	var d := start
	for k in count:
		if rng.randf() < density or k % 8 == 0:
			d = clampi(d + rng.randi_range(-2, 2), lo, hi)
			out.append(d)
		else:
			out.append(-1)
	return out

func _loop(bpm: float, bars: int) -> Dictionary:
	var step := 60.0 / bpm / 2.0
	return {"step": step, "eighths": bars * 8, "n": int(bars * 8 * step * RATE)}

func _blank(n: int) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	return s

## A soft, dry knock: a hand on a drum's rim, without the kotsuzumi's rising "pon".
func _knock(amp := 0.35) -> PackedFloat32Array:
	var s := _tone(0.08, 420.0, 0.025, amp)
	_add(s, _crunch(0.02, 0.004, amp * 0.5), 0)
	return s

## A town by day: koto over a soft knock; the shakuhachi above.
func _town() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var L := _loop(92.0, 8)
	var notes := _notes(YO, [1.0, 2.0, 4.0])
	var a := _blank(L.n)
	var b := _blank(L.n)
	var phrase := _phrase(rng, 32, 0.6, 4, 12, 7)
	for k in L.eighths:
		var at := int(k * L.step * RATE)
		var beat: int = k % 8
		var bar: int = k / 8
		var d: int = phrase[k % 32]
		if d >= 0:
			if bar >= 4 and beat == 6:
				d = mini(d + 1, notes.size() - 1)
			_add(a, _koto(notes[d], 1.6, 0.42 if beat % 2 == 0 else 0.3), at)
		if beat in [3, 7] or (beat == 5 and bar % 2 == 1):
			_add(a, _knock(0.3 if beat == 5 else 0.38), at)
		if beat == 0 and bar % 2 == 0:
			var held := clampi((phrase[(k + 2) % 32] if phrase[(k + 2) % 32] >= 0 else 8) + 2, 7, 13)
			_add(b, _shakuhachi(notes[mini(held, notes.size() - 1)], L.step * 12.0, 0.36), at)
	return [a, b]

## A trail by day: a low drone and a few koto notes; the shakuhachi wandering.
func _trail() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var L := _loop(66.0, 8)
	var seconds: float = L.n / float(RATE)
	var notes := _notes(YO, [1.0, 2.0, 4.0])
	var a := _drone([73.42, 110.0], seconds, 0.22)
	var b := _blank(L.n)
	var phrase := _phrase(rng, 64, 0.35, 5, 13, 8)
	for k in L.eighths:
		var at := int(k * L.step * RATE)
		if k % 8 in [0, 5] and rng.randf() < 0.7:
			_add(a, _koto(notes[rng.randi_range(3, 8)], 2.0, 0.3), at)
		var d: int = phrase[k]
		if d >= 0 and k % 2 == 0:
			_add(b, _shakuhachi(notes[d], L.step * rng.randi_range(3, 7), 0.34), at)
	return [a, b]

## The oni's night: drone and slow taiko; the shamisen's ostinato; driving
## taiko and the noh flute's cries, for when the town is up.
func _night() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	var L := _loop(72.0, 8)
	var seconds: float = L.n / float(RATE)
	var notes := _notes(IN, [0.5, 1.0, 2.0, 4.0])
	var a := _drone([73.42, 116.54], seconds, 0.24)
	var b := _blank(L.n)
	var c := _blank(L.n)
	var riff := [5, -1, 6, 5, -1, 8, 7, -1]
	for k in L.eighths:
		var at := int(k * L.step * RATE)
		var beat: int = k % 8
		var bar: int = k / 8
		if beat == 0:
			_add(a, _taiko(0.9), at)
		if beat == 4 and bar % 2 == 1:
			_add(a, _taiko(0.5), at)
		var d: int = riff[beat]
		if d >= 0:
			if bar % 4 == 3 and beat == 5:
				d += 1
			_add(b, _shamisen(notes[d], 0.9, 0.42), at)
		_add(c, _taiko(0.55 if beat % 2 == 0 else 0.3), at)
		if bar % 2 == 0 and beat == 0:
			_add(c, _nokan(notes[rng.randi_range(14, 17)], L.step * 6.0, 0.28), at + int(L.step * RATE))
	return [a, b, c]

## The master exorcist: driving taiko and shamisen, low and heavy; the noh
## flute and kotsuzumi over them.
func _master() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 59
	var L := _loop(124.0, 8)
	var notes := _notes(IN, [0.5, 1.0, 2.0, 4.0])
	var a := _blank(L.n)
	var b := _blank(L.n)
	var phrase := _phrase(rng, 32, 0.75, 3, 11, 6)
	for k in L.eighths:
		var at := int(k * L.step * RATE)
		var beat: int = k % 8
		var bar: int = k / 8
		_add(a, _taiko(1.0 if beat == 0 else (0.6 if beat % 2 == 0 else 0.3)), at)
		var d: int = phrase[k % 32]
		if d >= 0:
			_add(a, _shamisen(notes[d], 1.0, 0.45 if beat % 2 == 0 else 0.34), at)
		if beat in [3, 7]:
			_add(b, _kotsuzumi(), at)
		if beat == 0 and bar % 2 == 1:
			_add(b, _nokan(notes[rng.randi_range(13, 17)], L.step * 5.0, 0.3), at)
	return [a, b]
