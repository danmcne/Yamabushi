extends Node
const Kit := preload("res://scripts/kit.gd")
const Roster := preload("res://game/fighters/roster.gd")
const Stations := preload("res://scripts/stations.gd")
## Rule checks, enabled only with:  godot --headless --path . --fixed-fps 60 -- --checks
## Each check drives the real station view and reports PASS or FAIL.

var main: Node
var frame := 0
var step := 0
var v
var fails := 0
var picked := 0

func _key(action: String) -> int:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return e.physical_keycode
	return -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# the checks count frames; hold them to real time so a fast machine walks as far as a slow one
	Engine.max_fps = 60

func _ok(name: String, cond: bool, detail: String = "") -> void:
	print("%s  %s %s" % ["PASS" if cond else "FAIL", name, detail])
	if not cond:
		fails += 1

func _process(_d: float) -> void:
	frame += 1
	match frame:
		5:
			main.choose(main.options_shown[1])
			GameState.station_states["village"] = {"bridge": 0.0}
			main.enter_station("village", {"area": "riverbank", "x": 230.0, "y": 226.0})
			v = main.view
			Input.action_press("move_right")
		185:
			Input.action_release("move_right")
			_ok("monk cannot cross a destroyed bridge", v.monk.x < v.area.river.a, "(x=%d)" % int(v.monk.x))
			v._start_night(40.0)
			v.oni.x = 230.0
			v.oni.y = 226.0
			v.watch = []
			Input.action_press("move_right")
		485:
			Input.action_release("move_right")
			_ok("oni wades across", v.oni.x > v.area.river.b, "(x=%d)" % int(v.oni.x))
			var w := {"x": 230.0, "y": 226.0, "type": "watch", "hp": 30.0, "cd": 5.0, "face": 1, "down": false, "down_t": 0.0, "atk": 0.0, "lost": 0.0}
			v.watch = [w]
			v.oni.hp = 999.0
			v.oni.maxhp = 999.0
		680:
			var w = v.watch[0] if v.watch.size() > 0 else null
			_ok("hunter cannot follow across a destroyed bridge", w != null and w.x < v.area.river.a, "(x=%d)" % (int(w.x) if w else -1))
			v.oni.hp = 1.0
			v.oni.maxhp = 100.0
			v.oni.hunger = 50.0
		690:
			_ok("a starving oni does not end the night: it lasts, weak and slow", v.mode == "night" and v.oni.hp >= 1.0 and Kit.oni_pace(v.oni.hp) < 0.5 * Kit.oni_pace(100.0))
			v.oni.t = 0.0
		700:
			_ok("the night ends at its hour", v.mode == "day")
			_ok("monk wakes near collapse after a starved night", GameState.stamina <= 5.0, "(stamina=%d)" % int(GameState.stamina))
			_ok("dawn dialog is up", main.modal_open())
			main.choose(main.options_shown[0])
		710:
			_ok("a weak monk is warned he will crawl", main.view.prompt().begins_with("Weak and hungry"), "(%s)" % main.view.prompt())
			Input.action_press("move_right")
		780:
			Input.action_release("move_right")
			_ok("but he may still set out: hunger slows, it does not stop", main.view.prog > 0.0)
			main.view.prog = 0.0
			main.view._stay()
		790:
			v = main.view
			v.monk.x = 500.0
			GameState.gourd = "sake"
			var ev := InputEventAction.new()
			ev.action = "act"
			ev.pressed = true
			Input.parse_input_event(ev)
		800:
			_ok("act does not drink from the gourd", GameState.gourd == "sake" and not (main.modal_open() and main.modal_title.text == "The gourd"))
			if main.modal_open():
				main.choose(main.options_shown[-1])
			GameState.block_input(0.5)
			var ev2 := InputEventAction.new()
			ev2.action = "gourd"
			ev2.pressed = true
			Input.parse_input_event(ev2)
		810:
			_ok("input is ignored during the grace period", not main.modal_open())
		880:
			GameState._input_block_until = 0
			var ev3 := InputEventAction.new()
			ev3.action = "gourd"
			ev3.pressed = true
			Input.parse_input_event(ev3)
		890:
			_ok("gourd button offers the sake", main.modal_open() and main.modal_title.text == "The gourd")
			main.choose(main.options_shown[1])
			GameState.station_states = {}
			main.enter_station("village", {"area": "street", "x": 500.0, "y": 240.0})
			v = main.view
			v._start_night(40.0)
			v.oni.x = 200.0
			v.oni.y = 240.0
			v.oni.hp = 999.0
			v.oni.maxhp = 999.0
			v.oni.t = 999.0
			v.watch = [{"x": 120.0, "y": 240.0, "type": "patrol", "hp": 30.0, "cd": 1.0, "face": 1, "down": false, "down_t": 0.0, "atk": 0.0, "lost": 0.0}]
			GameState.heat = 0.0
		940:
			_ok("a patrol spots an oni standing in the open", GameState.heat >= 10.0, "(heat=%d)" % int(GameState.heat))
			v.oni.x = 200.0
			v.oni.y = v.Y_MIN + 2.0
			v.oni.scale = 1.0
			v.watch = [{"x": 120.0, "y": 240.0, "type": "patrol", "hp": 30.0, "cd": 1.0, "face": 1, "down": false, "down_t": 0.0, "atk": 0.0, "lost": 0.0}]
			GameState.heat = 0.0
		1040:
			_ok("a hidden oni is not spotted", GameState.heat < 10.0 and v.oni_hidden, "(heat=%d)" % int(GameState.heat))
			v.oni.scale = 2.5
		1080:
			_ok("an oni too large for the alley is not hidden", not v.oni_hidden)
			v.oni.scale = 1.0
			v.oni.x = 400.0
			v.oni.y = 240.0
			v.watch = [{"x": 120.0, "y": 240.0, "type": "patrol", "hp": 30.0, "cd": 1.0, "face": 1, "down": false, "down_t": 0.0, "atk": 0.0, "lost": 0.0}]
			_ok("a patrol does not see beyond its lantern", not v._sees(v.watch[0]))
			v.oni.x = 160.0
			_ok("a patrol sees inside its lantern", v._sees(v.watch[0]))
			GameState.nights_left = 0
			var N := GameState.nights_total
			_ok("no moon on the night of the rite", GameState.moon_lit_on(N + 1) == 0.0)
			_ok("the moon wanes night by night before it", GameState.moon_lit_on(1) > GameState.moon_lit_on(N) and GameState.moon_lit_on(N) > 0.0)
			main.open_modal("Yamabushi  v" + GameState.VERSION, "A long body of text that should wrap rather than run off the right edge of the screen, however long it gets.",
				[{"label": "Begin", "sub": "Arrows or WASD walk, in depth too. Space acts. V gourd. C pipe (fire at night). X staff (kanabo at night)."}])
		1090:
			var panel: Control = main.modal_title.get_parent().get_parent()
			var r := panel.get_global_rect()
			_ok("dialog fits on screen", r.position.x >= 0.0 and r.end.x <= 480.0 and r.end.y <= 270.0, "(%s)" % str(r))
			main.choose(main.options_shown[0])
			GameState.stamina = 80.0
			main.enter_trail("cedar_trail", "post_town")
			v = main.view
			v.monk.x = 500.0
			v.monk.y = 230.0
		1100:
			_ok("the camp wakes as the monk nears: hungry ghosts and umbrella ghosts", v.woke and v.foes.size() == 5)
			for f in v.foes:
				f.x = v.monk.x + 12.0
				f.y = v.monk.y
				f.cd = 0.0
		1110:
			_ok("hungry ghosts cost the monk stamina", GameState.stamina < 80.0, "(stamina=%d)" % int(GameState.stamina))
			GameState.stamina = 80.0
			var before := GameState.curse
			for i in 2:
				v.monk.cd = 0.0
				v.monk.face = 1
				v._strike()
			_ok("a defeated ghost leaves its spirit", v.wisps.size() >= 1)
			v.monk.cd = 0.0
			v.wisps[0].x = v.monk.x + 5.0
			v.wisps[0].y = v.monk.y
			v._strike()
			_ok("the staff frees the spirit, a small merit", v.exorcised >= 1 and GameState.curse < before, "(freed=%d)" % v.exorcised)
			v.wisps = [{"kind": "onibi", "x": v.monk.x + 5.0, "y": v.monk.y, "life": 5.0}]
			v._act()
			_ok("Act binds a spirit as a shikigami", GameState.spirits.size() == 1 and GameState.spirits[0].kind == "onibi")
			v.foes = [{"kind": "gaki", "x": v.monk.x + 22.0, "y": v.monk.y, "hp": 30.0, "face": -1, "cd": 9.0, "atk": 0.0, "stun": 0.0, "flash": 0.0, "dead": false, "fade": 1.0, "seed": 0.0, "uid": 99}]
			v._summon()
			_ok("the bound demon fire answers with its special", v.fx.any(func(f): return f.k == "streak") and GameState.spirits[0].cd > 0.0)
		1116:
			_ok("demon fire burns the demon in its path", v.foes.size() == 0 or v.foes[0].hp < 30.0)
			v.foes = [{"kind": "kappa", "x": v.monk.x + 20.0, "y": v.monk.y, "hp": 35.0, "face": -1, "cd": 9.0, "atk": 0.0, "stun": 0.0, "flash": 0.0, "dead": false, "fade": 1.0, "seed": 0.0, "uid": 98}]
			v.wisps = []
			v._act()
			_ok("bowing to a kappa makes it spill its dish", v.foes[0].get("spilled", false) and v.foes[0].stun > 0.0)
			v.monk.cd = 0.0
			v.monk.face = 1
			v._strike()
			_ok("a spilled kappa takes double damage", v.foes[0].hp <= 5.0, "(hp=%d)" % int(v.foes[0].hp))
			_ok("the trail rises: the path is higher further on", v.elev(1000.0) > v.elev(100.0))
			v.foes = []
			v.monk.x = v.world_w
		1120:
			_ok("the trail ends in the next station", main.view.get_script().resource_path.ends_with("station_view.gd") and GameState.station_id == "post_town")
			main.arrive("peak")
			v = main.view
			v.monk.x = 700.0
			v.monk.y = v.Y_MIN + 4.0
			GameState.curse = 30.0
			var ev := InputEventAction.new()
			ev.action = "act"
			ev.pressed = true
			Input.parse_input_event(ev)
		1130:
			_ok("the rite can begin at the temple", main.modal_open() and main.modal_title.text == "The rite", "(%s)" % main.modal_title.text)
			main.choose(main.options_shown[0])
			var duel = main.view
			_ok("the rite is fought on the Shikigami engine: the yamabushi against Shuten-doji", duel.get_script().resource_path.ends_with("duel_view.gd") and duel.bout.fighters[0].definition.id == &"monk" and duel.bout.fighters[1].definition.id == &"shuten")
			GameState.curse = 20.0
			var mild: int = duel._oni(false).max_health
			GameState.curse = 60.0
			GameState.record.smash = 5
			var harsh = duel._oni(false)
			_ok("the run tilts the oni: a deeper curse and more smashing make it tougher and harder-hitting", harsh.max_health > mild and harsh.moves[&"stand_heavy"].damage > Roster.by_id(&"shuten").moves[&"stand_heavy"].damage)
			GameState.record.smash = 0
			GameState.spirits = [{"kind": "kappa", "cd": 0.0}]
			_ok("a bound kappa comes to the duel as Kawataro's spirit", duel._bound_spirits(GameState.spirits).size() == 1 and duel._bound_spirits(GameState.spirits)[0].source.id == &"kappa")
			GameState.spirits = []
			if main.modal_open():
				main.choose(main.options_shown[0])
			GameState.station_states = {}
			main.enter_station("village", {"area": "street", "x": 200.0, "y": 202.0})
			v = main.view
			Input.action_press("move_up")
		1150:
			Input.action_release("move_up")
			_ok("an alley leads up into the back lane", v.area_id == "lane", "(area=%s)" % v.area_id)
			v.monk.x = 350.0
			v.monk.y = v.Y_MAX - 2.0
			Input.action_press("move_down")
		1170:
			Input.action_release("move_down")
			_ok("the lane leads back down to the street", v.area_id == "street", "(area=%s)" % v.area_id)
			v.monk.x = 260.0
			v.monk.y = 210.0
			var icons: Array = v._icons_of(v._day_options())
			_ok("buying and stealing share the food icon", icons == ["food"], "(%s)" % str(icons))
			v.monk.x = 200.0
			v.monk.y = v.Y_MIN + 2.0
			GameState.heat = 0.0
			v._start_night(40.0)
			_ok("changing in an alley goes unseen", GameState.heat == 0.0, "(heat=%d)" % int(GameState.heat))
			v.watch = []
			v.night_log.eat = 2
			v.night_log.drink = 1
			v.oni.hp = v.oni.maxhp
			var h0 := GameState.heat
			v._dawn(false)
			_ok("raided stores raise heat at dawn", GameState.heat >= h0 - 5.0 + 9.0 - 0.01, "(heat %d -> %d)" % [int(h0), int(GameState.heat)])
			# the river crossing: no bridge, and the station can only be left from the far side
			while main.modal_open():
				main.choose({"label": "close"})
			GameState.paused = false
			GameState.ended = false
			GameState.nights_left = 3
			GameState.station_id = "river_crossing"
			GameState.station_states = {}
			GameState.flags = {}
			GameState.stamina = 80.0
			GameState.coins = 5
			main.enter_station("river_crossing", {"area": "landing", "x": 600.0, "y": 226.0})
			v = main.view
			Input.action_press("move_right")
		1240:
			Input.action_release("move_right")
			_ok("the monk cannot walk into the river", v.monk.x < v.area.river.a)
			main.go_map({"area": "landing", "x": v.monk.x, "y": v.monk.y})
		1245:
			_ok("the map will not let him leave from the near bank", main.view.stranded() and main.view.prompt().begins_with("You are still on the near bank"))
			main.enter_station("river_crossing", {"area": "landing", "x": 620.0, "y": 226.0})
			v = main.view
			v._ferry(3)
			_ok("the crossing is played out: he rides the boat, mid-river", v._by_boat() and v.monk.x < v.area.river.b)
			v._update_crossing(v.crossing.len)
			_ok("the ferry carries him across for a fare", v.monk.x > v.area.river.b and GameState.coins == 2 and GameState.flags.get("crossed:river_crossing", false))
			# the castle town's drunk samurai
			GameState.station_id = "castle_town"
			GameState.heat = 0.0
			GameState.curse = 30.0
			main.enter_station("castle_town", {"area": "main", "x": 600.0, "y": 226.0})
			v = main.view
			Input.action_press("move_right")
		1300:
			Input.action_release("move_right")
			_ok("the drunk samurai blocks the street", v.monk.x < 640.0, "(x=%d)" % int(v.monk.x))
			v._speak(v.area.blockers[0])
			_ok("a calm word from a monk without heat gets him to move", not v._blocker_up(v.area.blockers[0]))
			var c0 := GameState.curse
			GameState.flags.erase("passed:castle_town:samurai")
			v._strike_blocker(v.area.blockers[0])
			_ok("knocking him down breaks a vow and draws heat", GameState.curse > c0 and GameState.heat >= 12.0)
			# the oni's roar
			v._start_night(30.0)
			v.oni.x = 300.0
			v.oni.y = 230.0
			v.watch = [{"x": 340.0, "y": 230.0, "type": "watch", "hp": 30.0, "cd": 1.0, "face": -1, "down": false, "down_t": 0.0, "atk": 0.0, "lost": 0.0}]
			v._roar()
			_ok("the roar throws back and stuns a watchman", v.watch[0].get("stun", 0.0) > 0.0 and v.watch[0].x > 380.0)
			# one body: what the oni eats, the monk wakes fed by
			GameState.stamina = 30.0
			v._start_night(30.0)
			v.watch = []
			var food = v.buildings[3]
			v._oni_eat(food)
			v._oni_eat(food)
			v.oni.hp -= 5.0
			v._dawn(false)
			_ok("two meals as the oni wake the monk stronger than he went to sleep", GameState.stamina > 30.0, "(stamina=%d)" % int(GameState.stamina))
			GameState.set_difficulty(0)
			var easy_n: int = GameState.nights_total
			GameState.set_difficulty(2)
			_ok("difficulty sets the nights to spare: Easy has more than Hard", easy_n > GameState.nights_total)
			GameState.set_difficulty(1)
			# the fork in the road
			GameState.station_id = "post_town"
			GameState.nights_left = 3
			GameState.stamina = 80.0
			while main.modal_open():
				main.choose({"label": "close"})
			GameState.paused = false
			GameState.ended = false
			main.go_map({"area": "street", "x": 100.0, "y": 230.0})
		1310:
			Input.action_press("move_right")
		1314:
			Input.action_release("move_right")
			_ok("setting out at the fork asks which road", main.modal_open() and main.modal_title.text == "Which road?")
			_ok("the post town has three roads: the river, the old road, the high pass", main.options_shown.size() == 4)
			main.choose(main.options_shown[2])
			var m2 = main.view
			_ok("choosing the high pass sets the road", m2.target == "castle_town" and m2.trail_id() == "high_pass" and m2.road_chosen, "(%s)" % m2.target)
			Input.action_press("move_left")
		1318:
			Input.action_release("move_left")
			_ok("turning back at the crossroads lets you choose again", not main.view.road_chosen)
			# arriving at the temple early
			GameState.nights_left = 2
			GameState.curse = 20.0
			main.arrive("peak")
			_ok("arriving early, he waits in the temple and the seal still weakens", GameState.nights_left == 0 and GameState.curse == 20.0 + 2.0 * GameState.NIGHTLY_CURSE, "(curse=%d)" % int(GameState.curse))
			# keys: Shikigami's diamond, and number keys in dialogs
			_ok("J strikes, I acts, L is the special, K the spirit, U the gourd, O the pipe",
				_key("strike") == KEY_J and _key("act") == KEY_I and _key("special") == KEY_L and _key("spirit") == KEY_K and _key("gourd") == KEY_U and _key("pipe") == KEY_O)
			while main.modal_open():
				main.choose({"label": "close"})
			main.open_modal("Test", "", [{"label": "first"}, {"label": "second", "run": func(): picked = 2}])
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_2
			ev.pressed = true
			Input.parse_input_event(ev)
		1330:
			_ok("a dialog choice answers to its number key", picked == 2 and not main.modal_open())
			# the gourd: drinking water shows and gives stamina; when full it is kept
			GameState.gourd = "water"
			GameState.sips = 2
			GameState.stamina = 50.0
			var msg := GameState.drink_water()
			_ok("drinking water raises stamina and says so", GameState.stamina > 50.0 and GameState.sips == 1 and msg.contains("50 ->"), "(%s)" % msg)
			GameState.stamina = 100.0
			GameState.drink_water()
			_ok("a full monk keeps his water", GameState.sips == 1)
			# fire: the oni beside a house can set it alight with the pipe's ember
			GameState.station_states = {}
			main.enter_station("village", {"area": "street", "x": 100.0, "y": 210.0})
			v = main.view
			v._start_night(30.0)
			v.watch = []
			v.oni.x = 110.0
			v.oni.y = v.Y_MIN + 4.0
			_ok("beside a house the legend offers fire", v.legend().O == "Fire")
			v._ignite()
			_ok("O sets the house alight", v.bld("house").burning and GameState.record.burn >= 1)
			v.oni.x = 200.0
			v.oni.y = v.Y_MAX
			_ok("away from buildings the legend says where to go", v.legend().O.begins_with("Fire: near"))
			# the new shikigami
			main.enter_trail("high_pass", "castle_town")
			v = main.view
			v.monk.x = 300.0
			v.monk.y = 230.0
			v.monk.face = 1
			v.foes = [{"kind": "tengu", "x": 340.0, "y": 230.0, "hp": 25.0, "face": -1, "cd": 9.0, "atk": 0.0, "stun": 0.0, "flash": 0.0, "dead": false, "fade": 1.0, "seed": 0.0, "uid": 1}]
			v._spirit_special("tengu")
			_ok("a bound tengu's gale blows demons back", v.foes[0].x > 400.0 and v.foes[0].stun > 0.0)
			v.foes[0].x = 360.0
			v._spirit_special("kitsune")
			_ok("a bound fox steps the monk behind the demon", v.monk.x > 360.0)
			v._spirit_special("kasa")
			GameState.stamina = 80.0
			v.foes[0].x = v.monk.x - 10.0
			v.foes[0].y = v.monk.y
			v.foes[0].stun = 0.0
			v.foes[0].cd = 0.0
			v.foes[0].dead = false
			v.foes[0].hp = 25.0
			v._update_foe(v.foes[0], 0.016)
			_ok("the umbrella ghost's ward halves a blow", is_equal_approx(GameState.stamina, 80.0 - 2.5), "(stamina=%.2f)" % GameState.stamina)
			_kit_checks()
			_trail_night_checks()
			_town_night_checks()
			_record_checks()
			_duel_checks()
			_hunt_checks()
			_capture_checks()
			_rite_checks()
			_larder_checks()
			_sound_checks()
			_bout_end_checks()
			print("checks done, %d failed" % fails)
			get_tree().quit()


## The monk's kit by day: the pipe, the conch, the falls, the goma, the samurai's sake.
func _kit_checks() -> void:
	main.enter_trail("cedar_trail", "post_town")
	var v = main.view
	v.monk.x = 120.0
	v.monk.y = 230.0
	v.foes = []
	GameState.curse = 30.0
	GameState.stamina = 60.0
	v.acts.smoke()
	_ok("a pipe is a small lapse", is_equal_approx(GameState.curse, 32.0), "(curse=%.1f)" % GameState.curse)
	Input.action_press("move_right")
	v._update(0.1)
	Input.action_release("move_right")
	_ok("he stands still while he smokes", is_equal_approx(v.monk.x, 120.0) and v.monk.anim == "smoke")
	v.acts.interrupt()
	var near := {"kind": "gaki", "x": 220.0, "y": 230.0, "hp": 30.0, "face": -1, "cd": 9.0, "atk": 0.0, "stun": 0.0, "flash": 0.0, "dead": false, "fade": 1.0, "seed": 0.0, "uid": 1}
	var far := near.duplicate()
	far.x = 420.0
	far.uid = 2
	v.foes = [near, far]
	GameState._input_block_until = 0
	Input.action_press("move_left")
	var ev := InputEventAction.new()
	ev.action = "special"
	ev.pressed = true
	v._unhandled_input(ev)
	Input.action_release("move_left")
	_ok("A and special sound the conch: demons in earshot on every side stand stunned", near.stun >= 2.0 and far.stun == 0.0 and near.hp == 30.0)
	_ok("the conch needs its breath back", v.acts.conch_cd > 0.0 and v.monk.ofuda_cd == 0.0)
	v.acts.interrupt()
	v.foes = []
	v.monk.x = 250.0
	v.monk.y = v.Y_MIN + 4.0
	_ok("at the falls, I is takigyo", v.legend().I == "Takigyo")
	GameState.stamina = 80.0
	GameState.curse = 40.0
	v.acts.taki_option("cedar_trail").run.call()
	# 25 for the cold, and the hour's hunger
	_ok("takigyo costs stamina and eases the curse", is_equal_approx(GameState.stamina, 80.0 - 25.0 - 2.5) and is_equal_approx(GameState.curse, 30.0))
	_ok("each falls only once", v.acts.taki_option("cedar_trail").disabled)
	# goma at the village shrine
	GameState.station_states = {}
	main.enter_station("village", {"area": "street", "x": 820.0, "y": 210.0})
	v = main.view
	GameState.hours = 9.0
	GameState.firewood = false
	var goma = v._day_options().filter(func(o): return o.short == "Goma")
	_ok("no firewood, no goma", goma.size() == 1 and goma[0].disabled)
	GameState.firewood = true
	GameState.heat = 20.0
	GameState.curse = 40.0
	var coins := GameState.coins
	goma = v._day_options().filter(func(o): return o.short == "Goma")
	goma[0].run.call()
	_ok("a goma with the town watching eases curse and rumour", is_equal_approx(GameState.curse, 28.0) and is_equal_approx(GameState.heat, 5.0) and GameState.coins == coins + 2 and not GameState.firewood)
	_ok("he kneels at the fire", v.monk.anim == "goma")
	GameState.firewood = true
	goma = v._day_options().filter(func(o): return o.short == "Goma")
	_ok("one goma here a day", goma[0].disabled)
	# the samurai takes the sake
	GameState.station_id = "castle_town"
	main.enter_station("castle_town", {"area": "main", "x": 630.0, "y": 230.0})
	v = main.view
	GameState.flags.erase("passed:castle_town:samurai")
	GameState.gourd = "sake"
	GameState.curse = 40.0
	var offer = v._day_options().filter(func(o): return o.short == "Offer")
	_ok("with sake in the gourd, it can be offered to the samurai", offer.size() == 1 and offer[0].vice)
	offer[0].run.call()
	_ok("he takes it and lets you by: a small lapse", GameState.flags.get("passed:castle_town:samurai", false) and GameState.gourd == "empty" and is_equal_approx(GameState.curse, 43.0))
	GameState.gourd = "water"
	_ok("no sake, no offer", v._day_options().filter(func(o): return o.short == "Offer").is_empty())


## A night on the trail: collapsing brings it; the oni fights the yokai and
## binds them; its shikigami answer it in the streets and stand with it in the
## rite; a night begun with none left is the new moon.
func _trail_night_checks() -> void:
	GameState.curse = 45.0
	GameState.prayer = 0.0
	GameState.nights_left = 3
	GameState.oni_spirits = []
	GameState.invincible = false
	main.enter_trail("cedar_trail", "post_town")
	var v = main.view
	v.monk.x = 400.0
	v.monk.y = 230.0
	v.foes = []
	v.woke = true
	GameState.stamina = 0.0
	GameState.hours = 12.0
	Input.action_press("move_right")
	v._update(0.1)
	Input.action_release("move_right")
	_ok("at no stamina the monk does not collapse: he crawls on, and the day goes on", v.mode == "day" and v.monk.x > 400.0 and Kit.monk_pace(0.0) < 0.3)
	GameState.hours = GameState.DUSK
	v._update(0.016)
	_ok("dusk on a trail brings the night there, not the next town", main.view == v and v.mode == "night")
	_ok("a starved oni wakes weak and slow, but wakes", v.oni.hp >= 1.0 and Kit.oni_pace(v.oni.hp) < 0.5)
	v.foes = [{"kind": "gaki", "x": v.oni.x + 20.0, "y": v.oni.y, "hp": 30.0, "face": -1, "cd": 9.0, "atk": 0.0, "stun": 0.0, "flash": 0.0, "dead": false, "fade": 1.0, "seed": 0.0, "uid": 7}]
	v.oni.face = 1
	v._oni_strike()
	_ok("the kanabo fells a yokai, and its spirit lingers", v.foes[0].dead and v.wisps.size() == 1)
	v.wisps[0].x = v.oni.x + 4.0
	v.wisps[0].y = v.oni.y
	var curse := GameState.curse
	_ok("beside the spirit, I binds it for the oni", v.legend().I == "Bind for the oni")
	v._oni_bind()
	_ok("the oni binds it for itself, and its hold tightens", GameState.oni_spirits.size() == 1 and is_equal_approx(GameState.curse, curse + GameState.ONI_BIND_CURSE) and GameState.spirits.size() <= 1)
	v.oni.hp = 40.0
	v.oni.t = 0.0
	v._update_night(0.016)
	_ok("at dawn the monk wakes on the trail, as strong as the oni left him", v.mode == "day" and is_equal_approx(GameState.stamina, 40.0) and main.modal_open())
	main.choose(main.options_shown[0])
	GameState.forage_today = 0
	v.monk.x = 130.0
	v.monk.y = 230.0
	var st := GameState.stamina
	_ok("on a trail, roots by the path: I forages", v.legend().I == "Forage")
	v._act()
	_ok("foraging on the trail feeds a starving monk without a broken vow", GameState.stamina > st + 10.0 and GameState.forage_today == 1)
	# in the streets, the oni's shikigami answer it
	GameState.station_states = {}
	main.enter_station("village", {"area": "street", "x": 300.0, "y": 230.0})
	v = main.view
	v._start_night(40.0)
	v.oni.face = 1
	var w := {"x": v.oni.x + 30.0, "y": v.oni.y, "type": "watch", "hp": 30.0, "cd": 9.0, "face": -1, "down": false, "down_t": 0.0, "atk": 0.0, "lost": 0.0}
	v.watch = [w]
	GameState.oni_spirits = [{"kind": "tengu", "cd": 0.0}]
	var x0: float = w.x
	v._oni_summon()
	_ok("in the streets the oni's shikigami answer it", w.x > x0 + 50.0 and w.stun > 0.0)
	# the new moon
	GameState.nights_left = 0
	v._dusk()
	_ok("a night begun with none left is the new moon, away from the temple", main.modal_open() and main.modal_title.text == "The new moon passes")
	main.choose(main.options_shown[0])
	_ok("and the oni keeps the body: the hunt begins where it fell, by night", GameState.hunt and main.view.get("id") == "village" and main.view.mode == "night" and not GameState.daylight)
	GameState.hunt = false
	GameState.nights_left = 3
	GameState.spirits = [{"kind": "kappa", "cd": 0.0}]
	main.start_duel("rite")
	_ok("in the rite the monk's shikigami stand with him, and the yokai the oni bound with it", main.view.bout.fighters[1].spirits.size() == 1 and main.view.bout.fighters[0].spirits.size() == 1)
	GameState.spirits = []
	GameState.oni_spirits = []


## Pausing; the watch's ears; drink; fire and its crowd; the abandoned town and
## its yokai; the oni walking off a trail into a town at night.
func _town_night_checks() -> void:
	GameState.nights_left = 3
	GameState.curse = 45.0
	GameState.heat = 0.0
	GameState.invincible = false
	main.pause()
	_ok("P pauses: a dialog over everything, and nothing moves", main.modal_open() and main.modal_title.text == "Paused" and GameState.paused)
	main.choose(main.options_shown[0])
	_ok("and Resume goes on", not GameState.paused)
	GameState.station_states = {}
	main.enter_station("castle_town", {"area": "main", "x": 400.0, "y": 210.0})
	var v = main.view
	v._start_night(40.0)
	v.oni.x = 410.0
	v.oni.y = v.Y_MIN + 4.0
	var near := _patrol(v.oni.x + 220.0, 1)
	var far := _patrol(v.oni.x - 520.0, -1)
	v.watch = [near, far]
	_ok("a patrol's lantern does not reach the oni from there", not v._sees(near))
	v.oni.face = 1
	v.oni.cd = 0.0
	v._strike()
	_ok("a crash is heard far beyond the lanterns: the near patrol goes to look ('?'), the far one does not", near.get("heard", false) and near.has("goal_x") and not far.get("heard", false))
	_ok("hearing is not seeing: he raises no alarm until his lantern finds the oni", near.type == "patrol")
	far.x = v.oni.x - 330.0
	v.oni.drunk = 6.0
	v._noise(v.oni.x)
	_ok("a drunk oni is louder: heard from farther", far.get("heard", false))
	v.oni.drunk = 0.0
	# fire brings the town
	v.watch = []
	var b = v.bld("merchant")
	v.oni.x = b.x + b.w / 2.0
	v._ignite()
	var crowd: Array = v.watch.filter(func(w): return w.type == "crowd")
	_ok("a fire brings people running with buckets", b.burning and crowd.size() >= v.CROWD_PER_FIRE)
	v.oni.x = 1200.0
	for w in crowd:
		w.delay = 0.0
		w.x = b.x + b.w / 2.0
		w.y = v.NEAR_BACK - 4.0
	for i in 4:
		for w in crowd:
			v._update_crowd(w, 0.5)
	_ok("enough of them, left alone, put it out", not b.burning)
	var heat := GameState.heat
	b.burning = true
	var w0: Dictionary = crowd[0]
	w0.fleeing = false
	v.oni.x = w0.x + 20.0
	v.oni.y = w0.y
	v.oni_hidden = false
	v._update_crowd(w0, 0.1)
	_ok("one who sees the oni at the fire screams, and the rumour grows", w0.fleeing and GameState.heat > heat)
	# the abandoned town
	GameState.station_id = "ruined_town"
	main.enter_station("ruined_town", {"area": "street", "x": 300.0, "y": 230.0})
	v = main.view
	_ok("the abandoned town stands half in ruins", v.bld("teahouse").hp <= 0 and v.bld("shrine").hp < 100.0)
	heat = GameState.heat
	v._start_night(40.0)
	var yokai: Array = v.watch.filter(func(w): return w.type == "yokai")
	_ok("at night yokai walk its streets, and no watch", yokai.size() >= 3 and v.watch.size() == yokai.size())
	var y0: Dictionary = yokai[0]
	y0.x = v.oni.x + 20.0
	y0.y = v.oni.y
	y0.hp = 10.0
	v.oni.face = 1
	v.oni.cd = 0.0
	v._strike()
	_ok("the kanabo fells a yokai there, and its spirit lingers; nobody talks", y0.down and v.wisps.size() == 1 and is_equal_approx(GameState.heat, heat))
	v.wisps[0].x = v.oni.x
	v.wisps[0].y = v.oni.y
	GameState.oni_spirits = []
	_ok("I binds it for the oni", v._night_option() != null and v._night_option().short == "Bind")
	v._night_option().run.call()
	_ok("the oni holds it", GameState.oni_spirits.size() == 1)
	GameState.oni_spirits = []
	# off the end of a trail at night, into the town
	main.enter_trail("cedar_trail", "post_town")
	v = main.view
	v.woke = true
	v._start_night(40.0)
	v.oni.x = v.world_w - 13.0
	Input.action_press("move_right")
	v._update_night(0.05)
	Input.action_release("move_right")
	var town = main.view
	_ok("the oni walks off the trail's end into the town, and its night goes on there", town.get("id") == "post_town" and town.mode == "night" and GameState.station_id == "post_town")


## Named events for sound to follow; the run saved at dawn and continued; the gamepad.
func _record_checks() -> void:
	var heard: Array = []
	var listen := func(what: String, _info: Dictionary): heard.append(what)
	GameState.happened.connect(listen)
	main.enter_trail("cedar_trail", "post_town")
	var v = main.view
	v.monk.x = 120.0
	v.foes = []
	v.acts.smoke()
	v.acts.interrupt()
	v.monk.cd = 0.0
	v._strike()
	GameState.happened.disconnect(listen)
	_ok("acts are announced as named events, for sound to follow", "smoke" in heard and "strike" in heard, str(heard))
	# a saved run, in a file of the check's own
	GameState.saving = true
	GameState.save_path = "user://yamabushi_check_save.json"
	GameState.station_id = "river_crossing"
	GameState.curse = 37.0
	GameState.night_no = 2
	GameState.oni_spirits = [{"kind": "kappa", "cd": 0.0}]
	GameState.station_states = {"village": {"bridge": 0.0}}
	main.go_map({"area": "landing", "x": 200.0, "y": 230.0})
	GameState.new_run()
	var saved := GameState.saved_run()
	var wake := GameState.load_run(saved)
	_ok("the run is saved at dawn on the map, and continues where it was", GameState.station_id == "river_crossing" and is_equal_approx(GameState.curse, 37.0)
		and GameState.night_no == 2 and GameState.oni_spirits.size() == 1 and float(GameState.station_states.village.bridge) == 0.0 and wake.area == "landing")
	main.end_run("checked", "")
	_ok("and the save is gone when the run ends", GameState.saved_run().is_empty())
	main.choose(main.options_shown[0]) if main.modal_open() else null
	GameState.saving = false
	GameState.ended = false
	var pad := false
	for e in InputMap.action_get_events("strike"):
		pad = pad or (e is InputEventJoypadButton and e.button_index == JOY_BUTTON_X)
	_ok("a gamepad mirrors the keys: X is the staff, as J", pad)


func _patrol(x: float, face: int) -> Dictionary:
	return {"x": x, "y": 230.0, "type": "patrol", "hp": 30.0, "cd": 9.0, "face": face, "down": false, "down_t": 0.0, "atk": 0.0, "lost": 0.0}


## A controller that holds one numpad direction and buttons.
class Held:
	var numpad := 5
	var buttons := ""
	func read(me: Fighter, _them: Fighter) -> Intent:
		return Intent.from_numpad(numpad, me.facing, buttons)


## The yamabushi's own duel kit: channelled meditation, the conch through a guard.
func _duel_checks() -> void:
	GameState.invincible = false
	main.start_duel("rite")
	var v = main.view
	var a: Fighter = v.bout.fighters[0]
	var b: Fighter = v.bout.fighters[1]
	var held := Held.new()
	v.player = Held.new()
	v.cpu = held
	_ok("special is the ofuda, away + special the conch: no meditation, no heal", a.definition.commands.get("C") == &"ofuda" and a.definition.commands.get("4C") == &"conch" and not a.definition.moves.has(&"meditation") and not a.definition.moves.has(&"sutra_palm"))
	a.position = Vector2(-300, 0)
	b.position = Vector2(300, 0)
	var me: Held = v.player
	me.buttons = "A"
	var swung := ""
	for i in 12:
		v._physics_process(0.016)
		if a.state == Fighter.State.MOVE and swung == "":
			swung = String(a.move.id)
	me.buttons = ""
	_ok("J (Shikigami's light button) swings the staff, the heavy blow", swung == "stand_heavy", "(%s)" % swung)
	for i in 80:
		v._physics_process(0.016)
	a.perform(&"ofuda")
	var flew := false
	for i in 30:
		v._physics_process(0.016)
		flew = flew or v.bout.entities.any(func(e): return e.move.id == &"ofuda_paper")
	_ok("the ofuda flies as a paper talisman", flew)
	for i in 120:
		v._physics_process(0.016)
	a.position = Vector2(-80, 0)
	b.position = Vector2(80, 0)
	held.buttons = "G"
	held.numpad = 4
	for i in 4:
		v._physics_process(0.016)
	var hp := b.health
	var blocks := b.blocks_taken
	a.perform(&"conch")
	for i in 50:
		v._physics_process(0.016)
	_ok("a guard blunts the conch but does not stop it", b.blocks_taken > blocks and hp - b.health == roundi(v.CONCH.spawn.damage * v.CONCH_GUARDED), "(%d lost)" % (hp - b.health))
	held.buttons = ""
	held.numpad = 5
	for i in 60:
		v._physics_process(0.016)
	a.position = Vector2(-80, 0)
	b.position = Vector2(80, 0)
	hp = b.health
	a.perform(&"conch")
	var stunned := false
	for i in 50:
		v._physics_process(0.016)
		stunned = stunned or b.state == Fighter.State.HITSTUN
	_ok("unguarded, the conch stuns and hurts in full", stunned and hp - b.health == v.CONCH.spawn.damage, "(%d lost)" % (hp - b.health))
	# a jump toward the other at close range carries clean over him
	for i in 90:
		v._physics_process(0.016)
	held.numpad = 5
	held.buttons = ""
	a.position = Vector2(-60, 0)
	b.position = Vector2(30, 0)
	me.numpad = 9
	var over := false
	for i in 80:
		v._physics_process(0.016)
		if a.position.y >= 0.0 and i > 10:
			me.numpad = 5
		over = over or (a.position.x > b.position.x)
	me.numpad = 5
	_ok("either can jump over the other and land on its far side", over and a.position.x > b.position.x, "(%d vs %d)" % [int(a.position.x), int(b.position.x)])


## The hunt: after the fall the oni roams the whole road, by day and by night,
## until the exorcists bring it down.
func _hunt_checks() -> void:
	GameState.new_run()
	GameState.invincible = false
	GameState.curse = 100.0
	GameState.begin_hunt()
	main.go_hunt({"station": "post_town", "area": "street", "x": 300.0, "y": 230.0}, GameState.hunt_oni)
	var v = main.view
	var stores: Array = v.buildings.filter(func(x): return x.kind != "bridge" and x.max_pantry > 0)
	var b = stores[0]
	var b2 = stores[1]
	v._collapse(b, false)
	b2.hp = 50.0
	b2.pantry = 0
	v.watch = []
	v.oni.t = 0.0
	v._update_night(0.016)
	_ok("in the hunt a night gives way to a day, and the oni walks on", GameState.daylight and v.mode == "night" and v.oni.t > 40.0)
	_ok("every phase a damaged building is mended a little and restocked", is_equal_approx(b2.hp, 50.0 + GameState.REBUILD) and b2.pantry == b2.max_pantry)
	_ok("but a fallen one stays a ruin, with nothing to eat in it", b.hp <= 0.0 and b.pantry == 0)
	var phases := 1
	while b.hp <= 0.0 and phases < 20:
		GameState.next_phase()
		b.hp = GameState.rebuilt(v.id, b.id, b.hp)
		phases += 1
	_ok("until the town raises it again, days later (%d on Normal)" % int(GameState.diff().rebuild), phases == 2 * int(GameState.diff().rebuild), "(%d phases)" % phases)
	GameState.hunt_phase = 1
	GameState.daylight = true
	GameState.master_due = GameState.MASTER_FIRST
	var first_day := GameState.hunt_hunters()
	GameState.hunt_phase = 9
	var fifth_day := GameState.hunt_hunters()
	GameState.hunt_phase = 1
	_ok("each day of the hunt brings a fifth more hunters", is_equal_approx(first_day, 1.0) and is_equal_approx(fifth_day, 1.8))
	var folk: Array = v.watch.filter(func(w): return w.type == "crowd")
	_ok("by day the town's people are out in the street", folk.size() == v.DAY_FOLK)
	var guard := _patrol(v.oni.x - 180.0, 1)
	guard.lantern = false
	guard.y = v.oni.y
	v.oni_hidden = false
	_ok("by day a guard sees the oni far ahead of him without a lantern", v._sees(guard))
	guard.face = -1
	_ok("but not behind him", not v._sees(guard))
	var heat := GameState.heat
	var f0: Dictionary = folk[0]
	f0.x = v.oni.x + 30.0
	f0.y = v.oni.y
	v._update_crowd(f0, 0.1)
	_ok("anyone who sees it screams and runs, and the rumour grows", f0.fleeing and GameState.heat > heat)
	# the road out, either way along the route
	v.watch = []
	v.oni.x = 12.0
	Input.action_press("move_left")
	v._update_night(0.05)
	Input.action_release("move_left")
	_ok("walking off the edge of town opens the road out, back down the route and on along it", main.modal_open() and main.options_shown.size() == 5)
	var back: Array = main.options_shown.filter(func(o): return o.label.ends_with("the mountain village"))
	main.choose(back[0])
	var tv = main.view
	_ok("back down the route, the oni comes onto the trail at its far end", tv.get("trail_id") == "cedar_trail" and tv.oni.x > tv.world_w - 40.0 and tv.left_end == "village")
	tv.oni.x = 11.0
	Input.action_press("move_left")
	tv._update_night(0.05)
	Input.action_release("move_left")
	v = main.view
	_ok("and the trail's near end leads down into the town there", v.get("id") == "village" and v.mode == "night" and GameState.hunt)
	_ok("coming back down the route, it enters the town by the road from ahead", v.area_id == Stations.def("village").end.area)
	# hunger can kill
	v.oni.hp = 0.5
	v._hurt_oni(1.0, true)
	_ok("in the hunt there is no monk to wake: starving is the end", GameState.ended and main.modal_title.text == "Starved")
	main.choose({"label": "close"})
	# the master exorcist, back each time stronger
	GameState.ended = false
	GameState.hunt_oni.hp = 70.0
	main.go_hunt({"station": "castle_town", "area": "main", "x": 400.0, "y": 230.0}, GameState.hunt_oni)
	v = main.view
	GameState.hunt_phase = GameState.master_due - 1
	v.oni.t = 0.0
	v._update_night(0.016)
	_ok("the master exorcist catches up with it in the end", main.modal_open() and main.modal_title.text == "The master exorcist")
	main.choose(main.options_shown[0])
	var d = main.view
	var h1: int = d.bout.fighters[1].definition.max_health
	var base_oni: int = Roster.by_id(&"shuten").max_health
	var o_now: Dictionary = GameState.hunt_oni
	var expect := roundi(base_oni * (1.0 + 0.25 * (o_now.scale - 1.0)) * clampf(o_now.hp / 100.0, 0.25, 1.0))
	_ok("the oni fights him as big as its meals made it and as strong as the road left it, not as deep as its curse",
		d.bout.fighters[0].definition.max_health == expect, "(%d, expected %d)" % [d.bout.fighters[0].definition.max_health, expect])
	_ok("he fights it where he caught it", d.mode == "hunt" and GameState.hunt_at.get("station", "") == "castle_town")
	var master_walk: float = Roster.by_id(&"onmyoji").walk_forward
	_ok("the first time he brings one shikigami", d.bout.fighters[1].spirits.size() == 1)
	d._result(0)
	main.choose(main.options_shown[0])
	_ok("thrown off, he falls back, and the hunt goes on where it was", main.view.get("id") == "castle_town" and GameState.master_beaten == 1
		and GameState.master_due == GameState.hunt_phase + GameState.MASTER_GAP)
	main.start_duel("hunt")
	d = main.view
	_ok("when he comes back he is stronger, quicker, sharper, with two shikigami", d.bout.fighters[1].definition.max_health > h1
		and d.bout.fighters[1].definition.walk_forward > master_walk and d.bout.fighters[1].spirits.size() == 2 and d.cpu.p.think <= CpuController.LEVELS[2][1].think)
	d._result(1)
	_ok("and if he wins, the oni is sealed", GameState.ended and main.modal_title.text == "Sealed")
	main.choose({"label": "close"})
	GameState.new_run()


## A watchman raises the town once; at full rumour dawn brings an inspection,
## not the end; the hunt is saved and continued.
func _capture_checks() -> void:
	GameState.new_run()
	GameState.set_difficulty(0)
	_ok("on Easy a beaten oni is bound only at full rumour, and the oni pushes less against a talisman",
		GameState.diff().capture >= 100.0 and GameState.diff().struggle < 1.0)
	GameState.set_difficulty(1)
	GameState.station_states = {}
	main.enter_station("castle_town", {"area": "main", "x": 400.0, "y": 230.0})
	var v = main.view
	v._start_night(40.0)
	v.oni_hidden = false
	var w := _patrol(v.oni.x - 30.0, 1)
	w.y = v.oni.y
	v.watch = [w]
	var h0 := GameState.heat
	v._update_patrol(w, 0.01)
	var h1 := GameState.heat
	w.type = "patrol"
	v._update_patrol(w, 0.01)
	_ok("a watchman who loses the oni and finds it again does not raise the town twice", h1 > h0 and is_equal_approx(GameState.heat, h1) and w.type == "watch")
	GameState.heat = 100.0
	v.night_log.eat = 4    # the stores found raided at dawn keep it there
	v.oni.t = 0.0
	v._update_night(0.016)
	_ok("at full rumour the exorcists are waiting at dawn, with an inspection, not a verdict", main.modal_open() and main.modal_title.text == "Exorcists at dawn" and not GameState.ended)
	main.choose({"label": "close"})
	v._dawn_inspected(true, v._dawn_report.bind("Dawn", "checked"))
	_ok("pass it and the day goes on, rumour down to %d" % int(v.INSPECTED_HEAT), is_equal_approx(GameState.heat, v.INSPECTED_HEAT) and main.modal_title.text == "Dawn" and not GameState.ended)
	main.choose({"label": "close"})
	v._dawn_inspected(false, v._dawn_report.bind("Dawn", "checked"))
	_ok("fail it and you are taken", GameState.ended and main.modal_title.text == "Bound")
	main.choose({"label": "close"})
	# the hunt, saved and continued
	GameState.new_run()
	GameState.saving = true
	GameState.save_path = "user://yamabushi_check_save.json"
	GameState.curse = 100.0
	GameState.begin_hunt()
	main.go_hunt({"station": "castle_town", "area": "main", "x": 400.0, "y": 230.0}, GameState.hunt_oni)
	v = main.view
	v.oni.hp = 63.0
	v.oni.t = 0.0
	v._update_night(0.016)
	GameState.new_run()
	var saved := GameState.saved_run()
	main._continue(saved)
	v = main.view
	_ok("the hunt is saved at each turn of day and night, and continues there", GameState.hunt and GameState.daylight and GameState.hunt_phase == 1
		and v.get("id") == "castle_town" and v.mode == "night" and absf(v.oni.hp - 63.0) < 0.5)
	GameState.clear_save()
	GameState.saving = false
	GameState.new_run()


## The rite at any curse, the oni scaled to it; one prayer a day at a shrine.
func _rite_checks() -> void:
	GameState.new_run()
	GameState.curse = 85.0
	main.reach_peak()
	_ok("the rite is open however deep the curse", main.modal_open() and main.modal_title.text == "The rite")
	main.choose(main.options_shown[0])
	var d = main.view
	var oni: FighterDefinition = d.bout.fighters[1].definition
	_ok("deep in the curse the oni is quicker and plays sharper", oni.walk_forward > Roster.by_id(&"shuten").walk_forward
		and d.cpu.p.think < CpuController.LEVELS[d.CPU_LEVEL[GameState.difficulty]][1].think)
	GameState.new_run()
	main.enter_station("village", {"area": "temple_path", "x": 300.0, "y": 212.0})
	var v = main.view
	var shrine = v.buildings.filter(func(b): return b.kind == "shrine")[0]
	v.monk.x = shrine.x + shrine.w / 2.0
	v.monk.y = v.Y_MIN + 4.0
	var pray: Array = v._day_options().filter(func(o): return o.short == "Pray")
	pray[0].run.call()
	var again: Array = v._day_options().filter(func(o): return o.short == "Pray")
	_ok("one prayer a day at each shrine", again.size() == 1 and again[0].disabled and GameState.prayer > 0.0)
	GameState.new_run()


## In the hunt a raided larder fills a whole day later, even across a visit
## elsewhere; townspeople keep out of the river.
func _larder_checks() -> void:
	GameState.new_run()
	GameState.curse = 100.0
	GameState.begin_hunt()
	main.go_hunt({"station": "post_town", "area": "street", "x": 300.0, "y": 230.0}, GameState.hunt_oni)
	var v = main.view
	var b = v.buildings.filter(func(x): return x.max_pantry > 0)[0]
	v._oni_eat(b)
	var left: int = b.pantry
	v.watch = []
	v.oni.t = 0.0
	v._update_night(0.016)
	_ok("half a day after a raid the larder is still as the oni left it", b.pantry == left)
	GameState.save_station(v.id, v.all_buildings())
	main.go_hunt({"station": "post_town", "area": "street", "x": 300.0, "y": 230.0}, v.oni)
	v = main.view
	b = v.bld(b.id)
	_ok("leaving and coming back does not fill it", b.pantry == left)
	v.watch = []
	v.oni.t = 0.0
	v._update_night(0.016)
	_ok("a whole day after the raid it is full again", b.pantry == b.max_pantry)
	# nobody stands in a river
	GameState.new_run()
	main.enter_station("river_crossing", {"area": "landing", "x": 300.0, "y": 230.0})
	v = main.view
	v._start_night(40.0)
	var r: Dictionary = v.area.river
	var w := _patrol((r.a + r.b) / 2.0, 1)
	v.watch = [w]
	v._settle(w, false)
	_ok("someone placed in the river is put on the bank", w.x < r.a or w.x > r.b)
	w.x = r.a - 8.0
	w.face = 1
	for i in 20:
		v._update_patrol(w, 0.1)
	_ok("a patrol walking toward the water turns back at it", w.x <= r.a and w.face == -1)
	GameState.new_run()


## Sound: every named event is heard, every sound is made and sane, loops join
## without a click, each view asks for its music, and a tune thickens with tension.
func _sound_checks() -> void:
	var Sounds := preload("res://scripts/sounds.gd")
	var Audio_ := preload("res://scripts/audio.gd")
	var missing: Array = []
	for e in GameState.EVENTS:
		var fx: Array = Audio_.effect_for(e, {"who": "oni"})
		if fx.is_empty() or not fx[0] in Sounds.EFFECTS:
			missing.append(e)
	_ok("every named event of play is heard", missing.is_empty(), str(missing))
	var s: Node = Sounds.new()
	var bad: Array = []
	for name in Sounds.EFFECTS + Sounds.LOOPS:
		var w: AudioStreamWAV = s.stream(name)
		var peak := 0.0
		for i in range(0, w.data.size() / 2, 7):
			peak = maxf(peak, absf(w.data.decode_s16(i * 2) / 32000.0))
		if peak < 0.05 or peak > 1.0:
			bad.append("%s %.2f" % [name, peak])
	_ok("every sound is made, audible and unclipped", bad.is_empty(), str(bad))
	var seams: Array = []
	for name in Sounds.LOOPS:
		var w2: AudioStreamWAV = s.stream(name)
		var n := w2.data.size() / 2
		var jump := absf(w2.data.decode_s16(0) - w2.data.decode_s16((n - 1) * 2)) / 32000.0
		# no bigger than the steps from one sample to the next within the loop
		var step := 0.0
		for i in range(0, n - 1, 3):
			step = maxf(step, absf(w2.data.decode_s16(i * 2) - w2.data.decode_s16((i + 1) * 2)) / 32000.0)
		if jump > step:
			seams.append("%s %.2f > %.2f" % [name, jump, step])
	_ok("ambience loops join without a click", seams.is_empty(), str(seams))
	s.free()
	# the music each view asks for
	Audio.start()
	GameState.new_run()
	main.on_title = false
	main.enter_station("castle_town", {"area": "main", "x": 400.0, "y": 230.0})
	var v = main.view
	var day: String = v.music().tune
	v._start_night(40.0)
	var calm: float = v.music().tension
	v.watch = [{"x": v.oni.x + 300.0, "y": 230.0, "type": "watch", "hp": 30.0, "cd": 9.0, "face": -1, "down": false, "down_t": 0.0, "atk": 0.0, "lost": 0.0}]
	var hunted: float = v.music().tension
	_ok("a town by day has its tune; the oni's night thickens when the watch is out after it", day == "town" and calm < 1.0 / 3.0 and hunted >= 2.0 / 3.0,
		"(%s, %.2f -> %.2f)" % [day, calm, hunted])
	main.enter_trail("cedar_trail", "post_town")
	var trail_tune: String = main.view.music().tune
	main.start_duel("rite")
	var rite_tune: String = main.view.music().tune
	_ok("trails, the rite: each its own music", trail_tune == "trail" and rite_tune == "fight")
	# an event is heard where it happened, left or right
	main.enter_station("castle_town", {"area": "main", "x": 400.0, "y": 230.0})
	v = main.view
	v.cam_x = 200.0
	GameState.event("roar", {"x": 600.0})
	var heard := false
	for p in Audio._voices:
		if p.playing and p.stream == Audio.sound.stream("roar"):
			heard = is_equal_approx(p.position.x, 400.0)
	_ok("an event is heard, placed where it happened on screen", heard)
	# the tunes are made in the background; once made, a view's tune plays
	var waited := 0
	while not Audio.sound.has_stream("town/1") and waited < 30000:
		OS.delay_msec(100)
		Audio.sound._process(0.0)
		waited += 100
	Audio._process(0.1)
	_ok("the town's tune plays, its stems together", Audio._tune == "town" and Audio._stems.size() == 2 and Audio._stems.all(func(p): return p.playing), "(%s, %d ms to make)" % [Audio._tune, waited])
	for p in Audio._stems + Audio._leaving:
		p.stop()
	Audio.enabled = false
	GameState.new_run()


## The end of a bout names its winner; a knocked-out fighter kneels before it
## falls; the oni grows from meals, and in the hunt shrinks back between them.
func _bout_end_checks() -> void:
	GameState.new_run()
	main.start_duel("rite")
	var titles := BoutView.winner_titles.duplicate()
	main.start_duel("hunt")
	_ok("the end of a bout names who won, not a player", titles == ["YAMABUSHI WINS", "ONI WINS"] and BoutView.winner_titles == ["ONI WINS", "EXORCIST WINS"])
	var DuelFigures := preload("res://scripts/duel_figures.gd")
	var d = main.view
	var f: Fighter = d.bout.fighters[1]
	var p: PuppetDefinition = BoutView.PuppetsRegistry.for_id(f.definition.id)
	f.health = 0
	f._set_state(Fighter.State.KO, true)
	var kneel := {}
	var held := {}
	var lying := {}
	for i in 140:
		if i == 30:
			# the sealing window: Shikigami stands the beaten fighter up, dazed
			f._set_state(Fighter.State.DAZED, true)
		var pose := Puppet._pose(f, p, 1.0)
		DuelFigures._seiza(f, p, pose, i >= 90, 1000 + i)
		if i == 40:
			kneel = pose
		if i == 89:
			held = pose
		lying = pose
	_ok("a beaten fighter kneels in seiza at once and stays kneeling while it may be sealed, then falls when the bout is over",
		kneel.root.y > 20.0 and absf(kneel.root_rot) < 1.0 and held.root.y > 20.0 and absf(held.root_rot) < 1.0 and absf(lying.root_rot) > 80.0,
		"(kneeling %d, still %d, then turned %d)" % [int(kneel.root.y), int(held.root.y), int(lying.root_rot)])
	# no double knockouts
	main.start_duel("rite")
	var b: Bout = main.view.bout
	_ok("the standoffs are set against drawn rounds", b.no_double_ko)
	for k in 2:
		b.fighters[k].health = 0
		b.fighters[k]._set_state(Fighter.State.KO, true)
	b._health_before = [30, 80]
	b._check_ko()
	_ok("if both fall at once, the one who had more health stands, on 1", b.round_winner == 1 and b.fighters[1].health == 1 and b.fighters[0].state == Fighter.State.KO)
	# a dialog after a struggle does not take the presses of the struggle
	GameState.block_input(1.0)
	main.open_modal("Choose", "", [{"label": "Keep the coins", "vice": true}, {"label": "Return them"}])
	var owner := main.get_viewport().gui_get_focus_owner()
	_ok("right after a struggle a dialog has no choice ready for I or Space; only a number takes one", owner == null)
	main.choose({"label": "close"})
	GameState.block_input(0.0)
	_ok("and the choice I or Space would take is never one that breaks a vow",
		main.default_choice([{"label": "Keep the coins", "vice": true}, {"label": "Return them"}]) == 1)
	GameState.new_run()
	GameState.curse = 100.0
	GameState.begin_hunt()
	var o: Dictionary = GameState.hunt_oni
	var base: float = o.scale
	GameState.grow(o)
	var fed: float = o.scale
	GameState.shrink(o, GameState.HUNT_PHASE)
	_ok("in the hunt the oni grows with a meal and shrinks back between meals, never below its size at the fall",
		is_equal_approx(fed, base + GameState.MEAL_GROWTH) and is_equal_approx(o.scale, base))
	GameState.new_run()
