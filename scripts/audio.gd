extends Node
## The game's sound, as an autoload: it listens and the rules never call it.
##
##   Effects   GameState's named events (strike, crash, roar, ...) each play a
##             sound (EFFECTS), placed left or right where it happened on screen.
##   Ambience  wind, running water, night insects and fire, each as loud as the
##             view says its place is (a view's `ambience()`: name -> 0..1).
##   Music     the tune the view asks for (a view's `music()`: {tune, tension});
##             a tune's stems come in one by one as tension rises, and a new
##             tune crossfades in.
##   Standoffs Shikigami's own sound in a fight: the bell as a round begins,
##             blows and blocks as they land, the gong at a knockout.
##
## Sound and music can each be turned off in the pause dialog (Shikigami's
## settings, which its synthesizer reads). Tools that drive the game run silent.

const Sounds := preload("res://scripts/sounds.gd")

## Event -> [sound, volume dB]; "who" picks between the monk's and the oni's.
const EFFECTS := {
	"strike": {"monk": ["staff", -8.0], "oni": ["kanabo", -6.0]},
	"hurt": {"monk": ["hurt", -8.0], "oni": ["hurt_oni", -7.0]},
	"crash": ["crash", -6.0],
	"fall": ["collapse", -4.0],
	"fire": ["ignite", -6.0],
	"alarm": ["alarm", -5.0],
	"heard": ["clack", -10.0],
	"scream": ["fire_bell", -8.0],
	"roar": ["roar", -3.0],
	"transform": ["transform", -4.0],
	"dawn": ["dawn", -6.0],
	"sleep": ["rin", -10.0],
	"eat": ["chomp", -8.0],
	"drink": {"monk": ["gulp", -8.0], "oni": ["gulp_oni", -7.0]},
	"sake": ["gulp", -8.0],
	"water": ["gulp", -9.0],
	"smoke": ["puff", -10.0],
	"conch": ["horagai", -4.0],
	"ofuda": ["ofuda", -8.0],
	"shikigami": ["summon", -7.0],
	"bind": ["rin", -6.0],
	"free": ["chime", -7.0],
	"pray": ["rin", -8.0],
	"takigyo": ["splash", -6.0],
	"goma": ["goma", -6.0],
	"gate": ["clappers", -8.0],
}
const MUSIC_DB := -11.0
const AMBIENCE_DB := -16.0
const LOOP_TRIM := {"water": -7.0}   # each loop's own level against the others
const FADE := 1.5        # seconds for a tune to cross over, or a stem to come in
const VOICES := 10       # effects that can sound at once

var enabled := true
var sound: Sounds
var _voices: Array[AudioStreamPlayer2D] = []
var _loops := {}             # ambience name -> player
var _tune := ""
var _stems: Array = []       # the playing tune's players
var _leaving: Array = []     # the last tune's players, fading out
var _heard := {}             # for the standoffs: what has been heard of each fighter


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a in ["--checks", "--bot", "--duel"] or a.begins_with("--snap=") or a.begins_with("--figures=") or a.begins_with("--sounds="):
			enabled = false
	# a bot may play with sound, to show the sound keeps up with real play
	if "--with-sound" in args:
		enabled = true
	if enabled:
		start()

## Set up the voices, the ambience and the synthesizer (which begins making
## the tunes in the background), and listen to the game.
func start() -> void:
	enabled = true
	sound = Sounds.new()
	add_child(sound)
	for i in VOICES:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 900.0
		p.attenuation = 0.6
		add_child(p)
		_voices.append(p)
	for name in Sounds.LOOPS:
		var lp := AudioStreamPlayer.new()
		lp.volume_db = -80.0
		add_child(lp)
		_loops[name] = lp
	GameState.happened.connect(_on_event)


## Play an effect by name, at x on screen (or the middle).
func play(name: String, volume_db := 0.0, screen_x := 240.0) -> void:
	if not enabled or not Settings.sound_on():
		return
	var chosen: AudioStreamPlayer2D = null
	var furthest := -1.0
	for p in _voices:
		if not p.playing:
			chosen = p
			break
		var through := p.get_playback_position() / maxf(p.stream.get_length(), 0.001)
		if through > furthest:
			furthest = through
			chosen = p
	chosen.stream = sound.stream(name)
	chosen.volume_db = volume_db
	chosen.position = Vector2(clampf(screen_x, -400.0, 880.0), 135.0)
	chosen.play()

## The sound and its volume for an event, or [] for none.
static func effect_for(what: String, info: Dictionary) -> Array:
	var e = EFFECTS.get(what, [])
	if e is Dictionary:
		return e.get(info.get("who", "monk"), e.values()[0])
	return e

func _on_event(what: String, info: Dictionary) -> void:
	var e := effect_for(what, info)
	if e.is_empty():
		return
	var x := 240.0
	var v = _view()
	if info.has("x") and v != null and v.has_method("screen_x"):
		x = v.screen_x(info.x)
	play(e[0], e[1], x)


func _view():
	var scene := get_tree().current_scene
	return scene.get("view") if scene != null else null


func _process(delta: float) -> void:
	if not enabled:
		return
	var v = _view()
	# music: the view's tune, its stems in as tension rises
	var want := {"tune": "menu", "tension": 0.0}
	if v != null and v.has_method("music") and not get_tree().current_scene.get("on_title"):
		want = v.music()
	if not Settings.music_on():
		want = {"tune": "", "tension": 0.0}
	_follow(want.tune, want.get("tension", 0.0), delta)
	# ambience
	var amb: Dictionary = v.ambience() if v != null and v.has_method("ambience") else {}
	for name in _loops:
		var lp: AudioStreamPlayer = _loops[name]
		var level: float = amb.get(name, 0.0) if Settings.sound_on() else 0.0
		var target: float = AMBIENCE_DB + LOOP_TRIM.get(name, 0.0) + linear_to_db(maxf(level, 0.0001))
		if level > 0.01 and not lp.playing:
			lp.stream = sound.stream(name)
			lp.volume_db = -60.0
			lp.play()
		lp.volume_db = move_toward(lp.volume_db, target, 30.0 * delta)
		if level <= 0.01 and lp.playing and lp.volume_db < -55.0:
			lp.stop()
	# a standoff
	if v != null and v.get("bout") != null:
		_listen(v.bout)


## Keep the music on `tune`, its stems layered for `tension` (0 to 1): the
## first stem always, each further one as tension passes its share.
func _follow(tune: String, tension: float, delta: float) -> void:
	# a new tune comes in once its stems are made (they are made in the
	# background from the start); until then the last one plays on
	if tune != _tune:
		var made := tune == "" or sound.has_stream("%s/%d" % [tune, Sounds.TUNES[tune] - 1])
		if made:
			_leaving.append_array(_stems)
			_stems = []
			_tune = tune
			if tune != "":
				for k in Sounds.TUNES[tune]:
					var p := AudioStreamPlayer.new()
					p.stream = sound.stream("%s/%d" % [tune, k])
					p.volume_db = -60.0
					add_child(p)
					_stems.append(p)
				# started together, the stems stay together: they are one length
				for p in _stems:
					p.play()
	var n := _stems.size()
	for k in n:
		var on := k == 0 or tension >= float(k) / n
		var target := MUSIC_DB if on else -60.0
		_stems[k].volume_db = move_toward(_stems[k].volume_db, target, 60.0 / FADE * delta)
	for p in _leaving.duplicate():
		p.volume_db = move_toward(p.volume_db, -60.0, 60.0 / FADE * delta)
		if p.volume_db <= -59.0:
			p.queue_free()
			_leaving.erase(p)


## Shikigami's sound for a standoff, from what changed this frame.
func _listen(bout) -> void:
	if _heard.get("bout") != bout:
		_heard = {"bout": bout, "bell": false, "blows": [], "blocks": [], "ko": [false, false]}
		for f in bout.fighters:
			_heard.blows.append(f.blows_taken)
			_heard.blocks.append(f.blocks_taken)
	var in_banner: bool = bout.phase != Bout.Phase.FIGHT or bout.phase_frame < Bout.BANNER_FRAMES
	if in_banner:
		_heard.bell = false
	elif not _heard.bell:
		_heard.bell = true
		play("bell", -6.0)
	for i in 2:
		var f = bout.fighters[i]
		if f.blows_taken > _heard.blows[i]:
			play("hit_heavy" if f.last_blow >= 60 else "hit", -6.0)
		if f.blocks_taken > _heard.blocks[i]:
			play("block", -8.0)
		_heard.blows[i] = f.blows_taken
		_heard.blocks[i] = f.blocks_taken
		var ko: bool = f.state == Fighter.State.KO
		if ko and not _heard.ko[i]:
			play("gong", -4.0)
		_heard.ko[i] = ko
