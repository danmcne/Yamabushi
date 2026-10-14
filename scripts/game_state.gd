extends Node
## Everything that must survive a change of scene lives here: the meters,
## the clock to the new moon, the oni's behaviour record, and the damage
## left in every station the monk has passed through.

const Stations := preload("res://scripts/stations.gd")

signal fallen
signal new_moon
## Named moments of play, for sound and music (and anything else) to attach
## to without touching the rules. `what` is one of EVENTS; `info` may carry a
## position ("x") or a kind.
signal happened(what: String, info: Dictionary)
const EVENTS := ["strike", "hurt", "crash", "fall", "fire", "alarm", "heard", "scream", "roar", "transform", "dawn",
	"sleep", "eat", "drink", "sake", "water", "smoke", "conch", "ofuda", "shikigami", "bind", "free", "pray",
	"takigyo", "goma", "gate"]

## One saved run, written at each dawn (the map) and in the hunt at each turn
## of day and night, read by Continue, cleared when the run ends. Tools that
## drive the game (checks, bots, shots) turn it off.
var save_path := "user://yamabushi_run.json"
const SAVED := ["difficulty", "nights_total", "nights_left", "night_no", "hours", "stamina", "coins", "curse", "heat",
	"prayer", "gourd", "sips", "firewood", "alms_today", "forage_today", "gate_passed", "flags", "spirits",
	"oni_spirits", "bound_total", "freed_total", "record", "station_id", "station_states",
	"hunt", "hunt_phase", "daylight", "master_beaten", "master_due", "hunt_oni", "hunt_at", "ruins", "larders"]
var saving := true

const VERSION := "0.15.1"

const SLEEP_BELOW := 20.0     # effective curse below this at dusk: the monk sleeps
const NIGHTLY_CURSE := 10.0   # the seal weakens a little every night
const HOUR_SECONDS := 8.0     # real seconds per in-game hour during the day
const DAY_START := 6.0
const DUSK := 18.0
const ARRIVAL_HOUR := 8.0     # travelling to a new station takes the early morning
const TRAVEL_HEAT_KEEP := 0.5 # rumour follows you, but only half of it
const TRAVEL_STAMINA := 15.0  # setting out; the trail itself costs the rest

const SPIRIT_SLOTS := 2      # shikigami the monk can hold bound at once

## Difficulty levels. nights: before the new moon (four stations need four);
## heat: how fast rumour grows; hurt: damage the watch and the trail demons do;
## capture: heat at which a beaten oni is bound; hunters: how many come;
## struggle: how hard the oni pushes against an inspection's talisman;
## rebuild: days, in the hunt, before a town raises a fallen building again.
const DIFFICULTY := [
	{"name": "Easy", "nights": 6, "heat": 0.6, "hurt": 0.5, "capture": 100.0, "hunters": 0.7, "struggle": 0.6, "rebuild": 2},
	{"name": "Normal", "nights": 5, "heat": 1.0, "hurt": 1.0, "capture": 80.0, "hunters": 1.0, "struggle": 1.0, "rebuild": 3},
	{"name": "Hard", "nights": 4, "heat": 1.3, "hurt": 1.3, "capture": 70.0, "hunters": 1.3, "struggle": 1.2, "rebuild": 4},
]
var difficulty := 1

## Nights before the new moon; the rite is on the night after the last of them.
## Set by the difficulty: the long road has four stations, one night in each,
## plus slack on Easy and Normal. The high pass skips the river crossing.
var nights_total := 5

var nights_left := 0
var night_no := 0
var hours := DAY_START
var stamina := 100.0
var coins := 4
var curse := 25.0
var heat := 0.0
var prayer := 0.0
var gourd := "water"          # "water", "sake" or "empty"
var sips := 2
var firewood := false         # a bundle of cut wood for a goma fire
var alms_today := false
var forage_today := 0
var gate_passed := false
var flags := {}               # per-run facts, such as "crossed:river_crossing"
var spirits: Array = []       # the monk's shikigami: {"kind": "gaki"|"onibi"|..., "cd": seconds}
var oni_spirits: Array = []   # the oni's own, bound on night trails
var bound_total := 0
var freed_total := 0
var invincible := false       # testing aid (F10): fights cost the monk and the oni nothing
var return_penalty := 0.0
var record := {}
var station_id := "village"
var station_states := {}      # station id -> {building id: hp}

## The hunt: after the fall the oni has the body for good. It walks the whole
## road, by day and by night, until the exorcists bring it down. A day and a
## night are each one phase. The towns mend a little every phase, but a fallen
## building stays a ruin for days (by difficulty), with nothing in it to eat;
## the hunters grow in number every day; the master exorcist catches up at
## MASTER_FIRST, and again MASTER_GAP phases after each time the oni throws him
## off, stronger.
const HUNT_PHASE := 45.0      # seconds in a phase
const HUNT_HUNGER := 20.0     # body the oni burns over a phase without eating
const REBUILD := 15.0         # hp a damaged building still standing regains in a phase
const MASTER_FIRST := 4
const MASTER_GAP := 3
var hunt := false
var hunt_phase := 0
var daylight := false
var master_beaten := 0
var master_due := MASTER_FIRST
var hunt_oni := {}            # the oni's body, carried from view to view
var hunt_at := {}             # where it is: {"station", "area", "x", "y"} or {"trail", "x", "y"}
var ruins := {}               # "station:building" -> phases until the town raises it again
var larders := {}             # "station:building" -> {pantry, barrels, at}: raided in the hunt at phase `at`

var paused := false
var ended := false
var _input_block_until := 0


func _ready() -> void:
	_register_inputs()
	new_run()


func new_run() -> void:
	nights_left = nights_total
	night_no = 0
	hours = DAY_START
	stamina = 100.0
	coins = 4
	curse = 25.0
	heat = 0.0
	prayer = 0.0
	gourd = "water"
	sips = 2
	firewood = false
	alms_today = false
	forage_today = 0
	gate_passed = false
	flags = {}
	spirits = []
	oni_spirits = []
	bound_total = 0
	freed_total = 0
	return_penalty = 0.0
	record = {"eat": 0, "drink": 0, "smash": 0, "burn": 0, "roar": 0, "bind": 0}
	station_id = "village"
	station_states = {}
	hunt = false
	hunt_phase = 0
	daylight = false
	master_beaten = 0
	master_due = MASTER_FIRST
	hunt_oni = {}
	hunt_at = {}
	ruins = {}
	larders = {}
	paused = false
	ended = false


# ---------- input grace ----------
## After a dialog or struggle closes, ignore game input briefly so that
## taps meant for the dialog never land in the world.
## Counted in frames rather than wall-clock time, so it means the same thing
## at any frame rate the game is run at.
func event(what: String, info: Dictionary = {}) -> void:
	assert(what in EVENTS, "unknown event %s" % what)
	happened.emit(what, info)


# ---------- the saved run ----------
func save_run(wake: Dictionary) -> void:
	if not saving:
		return
	var data := {"version": VERSION, "wake": wake}
	for k in SAVED:
		data[k] = get(k)
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))

## The saved run of this version, or an empty dictionary.
func saved_run() -> Dictionary:
	if not saving or not FileAccess.file_exists(save_path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary or parsed.get("version", "") != VERSION:
		return {}
	return parsed

## Restore the saved run; returns where on the map to wake.
func load_run(data: Dictionary) -> Dictionary:
	new_run()
	for k in SAVED:
		if not data.has(k):
			continue
		var v = data[k]
		# JSON keeps every number as a float
		if get(k) is int:
			v = int(v)
		set(k, v)
	return data.get("wake", {})

func clear_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func block_input(seconds: float) -> void:
	_input_block_until = Engine.get_process_frames() + int(seconds * 60.0)

func input_blocked() -> bool:
	return Engine.get_process_frames() < _input_block_until

## Seconds of input grace left (at 60 frames a second).
func input_grace_left() -> float:
	return maxf(0.0, (_input_block_until - Engine.get_process_frames()) / 60.0)


# ---------- meters ----------
func add_curse(n: float) -> void:
	curse = clampf(curse + n, 0.0, 100.0)
	if curse >= 100.0 and not ended and not hunt:
		fallen.emit()

func add_heat(n: float) -> void:
	if n > 0.0:
		n *= diff().heat
	heat = clampf(heat + n, 0.0, 100.0)

func diff() -> Dictionary:
	return DIFFICULTY[difficulty]

func set_difficulty(level: int) -> void:
	difficulty = clampi(level, 0, DIFFICULTY.size() - 1)
	nights_total = diff().nights
	nights_left = nights_total

func gain_stamina(n: float) -> void:
	stamina = clampf(stamina + n, 0.0, 100.0)

## Spend in-game time. Hunger drains stamina by the hour, whatever you do with it.
func advance(h: float) -> void:
	hours += h
	stamina = maxf(0.0, stamina - 2.5 * h)


# ---------- clock ----------
## Called at dusk. Returns the effective curse for tonight and whether the monk sleeps.
func begin_night() -> Dictionary:
	if nights_left <= 0:
		# the night of the new moon, and the monk is not at the temple
		ended = true
		new_moon.emit()
		return {"eff": curse, "sleep": false}
	hours = DUSK
	nights_left -= 1
	night_no += 1
	add_curse(NIGHTLY_CURSE)
	var eff := maxf(0.0, curse - prayer)
	prayer = 0.0
	return {"eff": eff, "sleep": eff < SLEEP_BELOW}

func new_day() -> void:
	hours = DAY_START + return_penalty
	return_penalty = 0.0
	alms_today = false
	forage_today = 0
	gate_passed = false

## Setting out at dawn on the road to the next station.
func depart() -> void:
	stamina = maxf(0.0, stamina - TRAVEL_STAMINA)
	new_day()
	hours = 7.0

## Arriving: rumour follows, but only half of it. The hour is whatever the road
## left. In the hunt the whole land knows, and none of it is left behind.
func arrive(id: String) -> void:
	station_id = id
	if hunt:
		return
	heat *= TRAVEL_HEAT_KEEP
	hours = maxf(hours, ARRIVAL_HOUR)


# ---------- the hunt ----------
## The oni takes the body for good. Its size is the curse's; its strength is
## what the monk had left, but never less than a beast's.
func begin_hunt() -> void:
	hunt = true
	ended = false
	paused = false
	hunt_phase = 0
	daylight = false
	hours = DUSK + 4.0
	master_beaten = 0
	master_due = MASTER_FIRST
	heat = maxf(heat, 40.0)
	hunt_oni = {"scale": 1.0 + curse / 120.0, "base": 1.0 + curse / 120.0, "hp": maxf(40.0, stamina), "maxhp": 100.0, "t": HUNT_PHASE,
		"hunger": HUNT_HUNGER / HUNT_PHASE, "dmg": 1.0, "drunk": 0.0, "slow": 0.0, "face": 1, "yaw": 30.0}

## Save the hunt: the oni's body (what of it outlasts a view) and where it is.
const HUNT_BODY := ["scale", "base", "hp", "maxhp", "t", "hunger", "dmg", "drunk", "face", "yaw"]
func save_hunt(at: Dictionary, o: Dictionary) -> void:
	hunt_at = at.duplicate()
	hunt_oni = {}
	for k in HUNT_BODY:
		if o.has(k):
			hunt_oni[k] = o[k]
	save_run(at)

## One phase gives way to the next: day to night or night to day. Every town
## rebuilds a little. Returns true if the master exorcist is due.
func next_phase() -> bool:
	hunt_phase += 1
	daylight = not daylight
	hours = 12.0 if daylight else DUSK + 4.0
	for key in ruins:
		ruins[key] -= 1
	for id in station_states:
		var hp: Dictionary = station_states[id]
		for b in hp:
			hp[b] = rebuilt(id, b, hp[b])
	return hunt_phase >= master_due

## A building's hp one phase later. A damaged one is mended a little; a fallen
## one stays a ruin until the days to raise it have passed (counted from the
## first phase the ruin is noticed), and then stands whole. The abandoned town
## stays as it is.
func rebuilt(id: String, bid: String, hp: float) -> float:
	if not Stations.def(id).get("people", true):
		return hp
	if hp > 0.0:
		return minf(100.0, hp + REBUILD)
	var key := "%s:%s" % [id, bid]
	if not ruins.has(key):
		ruins[key] = 2 * int(diff().rebuild) - 1
	return 100.0 if ruins[key] <= 0 else 0.0

## A building falls: whatever raising of it was under way starts over.
func fell(id: String, bid: String) -> void:
	ruins.erase("%s:%s" % [id, bid])

## The oni grows with each meal; in the hunt, between meals, it shrinks back
## toward the size it had when it took the body.
const MEAL_GROWTH := 0.08
const HUNT_SHRINK := 0.12     # size lost over a phase without eating
func grow(o: Dictionary) -> void:
	o.scale = minf(3.0, o.scale + MEAL_GROWTH)

func shrink(o: Dictionary, dt: float) -> void:
	if hunt:
		o.scale = maxf(o.get("base", 1.0), o.scale - HUNT_SHRINK * dt / HUNT_PHASE)

## Every day of the hunt brings more hunters: a fifth more each day.
func hunt_hunters() -> float:
	return 1.0 + 0.2 * (hunt_phase / 2) if hunt else 1.0

## The master exorcist is thrown off again: he comes back later, and stronger.
func master_thrown() -> void:
	master_beaten += 1
	master_due = hunt_phase + MASTER_GAP

func hunt_line() -> String:
	var days := (hunt_phase + 1) / 2
	var nights := hunt_phase / 2 + 1
	return "The oni roamed for %d %s and %d %s and threw off the master exorcist %s. %s" % [
		days, "day" if days == 1 else "days", nights, "night" if nights == 1 else "nights",
		"once" if master_beaten == 1 else "%d times" % master_beaten, habits_line()]

## Fraction of the moon lit on a given night. Night k of N shows (N+1-k)/(N+1),
## so the moon wanes through the journey and the rite night, N+1, has none.
func moon_lit_on(night: int) -> float:
	return clampf(float(nights_total + 1 - night) / float(nights_total + 1), 0.0, 1.0)

## Tonight's moon: during a night, that night's; by day, the coming one's.
func moon_lit(during_night: bool = false) -> float:
	return moon_lit_on(night_no if during_night else night_no + 1)


## Damage taken by the monk in a fight, unless the testing aid is on.
func hurt_monk(n: float) -> void:
	if not invincible:
		stamina = maxf(0.0, stamina - n * diff().hurt)

func bind_spirit(kind: String) -> bool:
	if spirits.size() >= SPIRIT_SLOTS:
		return false
	spirits.append({"kind": kind, "cd": 0.0})
	bound_total += 1
	return true

## The oni binds a yokai for itself. It serves the oni by night; each one
## tightens the oni's hold.
const ONI_BIND_CURSE := 3.0
func oni_bind(kind: String) -> bool:
	if oni_spirits.size() >= SPIRIT_SLOTS:
		return false
	oni_spirits.append({"kind": kind, "cd": 0.0})
	record.bind += 1
	add_curse(ONI_BIND_CURSE)
	return true

## The gourd, shared by every view. Each returns what to tell the player.
func drink_water() -> String:
	if stamina >= 98.0:
		return "You are not thirsty; the water keeps."
	var before := stamina
	sips -= 1
	gain_stamina(12)
	if sips <= 0:
		gourd = "empty"
	var left := "the gourd is empty" if gourd == "empty" else "%d %s left" % [sips, "sip" if sips == 1 else "sips"]
	return "You drink cold water: stamina %d -> %d (%s)." % [int(before), int(stamina), left]

func drink_sake() -> String:
	var before := stamina
	gourd = "empty"
	gain_stamina(60)
	add_curse(15)
	return "The sake warms you all the way down: stamina %d -> %d. A vow broken." % [int(before), int(stamina)]

func habits_line() -> String:
	return "Across the run the oni ate %d, drank %d, smashed %d buildings, set %d fires and bound %d yokai of its own. You bound %d spirits and freed %d." % [record.eat, record.drink, record.smash, record.burn, record.get("bind", 0), bound_total, freed_total]


# ---------- per-station damage ----------
func save_station(id: String, buildings: Array) -> void:
	var hp := {}
	for b in buildings:
		hp[b.id] = b.hp
		var key := "%s:%s" % [id, b.id]
		if b.has("taken_at"):
			larders[key] = {"pantry": b.pantry, "barrels": b.barrels, "at": b.taken_at}
		else:
			larders.erase(key)
	station_states[id] = hp

## In the hunt a town restocks a building a whole day (two phases) after the
## oni first raided it, and not before.
const RESTOCK := 2
func restocked(taken_at: int) -> bool:
	return hunt_phase >= taken_at + RESTOCK

func load_station_hp(id: String) -> Dictionary:
	return station_states.get(id, {})


# ---------- input ----------
func _register_inputs() -> void:
	var keys := {
		# the same diamond as Shikigami: J strike, I act, L special, K spirit;
		# the kit's other two items on U and O beside I
		"move_left": [KEY_LEFT, KEY_A],
		"move_right": [KEY_RIGHT, KEY_D],
		"move_up": [KEY_UP, KEY_W],
		"move_down": [KEY_DOWN, KEY_S],
		"act": [KEY_I, KEY_SPACE],
		"strike": [KEY_J],
		"special": [KEY_L],
		"spirit": [KEY_K],
		"gourd": [KEY_U],
		"pipe": [KEY_O],
		"cheat": [KEY_F10],
		"pause": [KEY_P, KEY_ESCAPE],
	}
	# a gamepad mirrors the diamond: X the staff, Y act, B the special, A the
	# spirit; the shoulders the gourd and the pipe; Start pauses
	var pad := {"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT, "move_up": JOY_BUTTON_DPAD_UP,
		"move_down": JOY_BUTTON_DPAD_DOWN, "act": JOY_BUTTON_Y, "strike": JOY_BUTTON_X, "special": JOY_BUTTON_B,
		"spirit": JOY_BUTTON_A, "gourd": JOY_BUTTON_LEFT_SHOULDER, "pipe": JOY_BUTTON_RIGHT_SHOULDER, "pause": JOY_BUTTON_START}
	var stick := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
		for k in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
		if pad.has(action):
			var b := InputEventJoypadButton.new()
			b.button_index = pad[action]
			InputMap.action_add_event(action, b)
		if stick.has(action):
			var m := InputEventJoypadMotion.new()
			m.axis = stick[action][0]
			m.axis_value = stick[action][1]
			InputMap.action_add_event(action, m)
	# dialogs: W/S move between choices, I confirms, as well as the arrows and Enter/Space
	for pair in [["ui_up", KEY_W], ["ui_down", KEY_S], ["ui_accept", KEY_I]]:
		var e2 := InputEventKey.new()
		e2.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], e2)
