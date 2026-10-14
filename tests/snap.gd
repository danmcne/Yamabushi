extends Node
## Screenshot helper, enabled only with:  -- --snap=/some/dir   (needs a display)
## One frame each of: the river crossing, the castle town and its drunk
## samurai, the high pass climbing, a trail fight with a spirit and a summoned
## shikigami, the oni's roar, the climb to the temple, and both standoffs
## (with the monk's ofuda and conch), the river crossings, and the hunt.

var main: Node
var dir := ""
var frame := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--snap="):
			dir = a.split("=")[1]

func _save(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])

func _process(_d: float) -> void:
	frame += 1
	var v = main.view
	match frame:
		8:
			_save("0_title")
		10:
			main.choose(main.options_shown[1])
			GameState.hours = 10.0
			GameState.station_id = "river_crossing"
			main.enter_station("river_crossing", {"area": "landing", "x": 560.0, "y": 226.0})
		30:
			_save("1_river_crossing")
			GameState.station_id = "castle_town"
			main.enter_station("castle_town", {"area": "main", "x": 580.0, "y": 230.0})
		50:
			_save("2_castle_town")
			main.enter_trail("high_pass", "castle_town")
		60:
			v.monk.x = 380.0
		75:
			_save("3_high_pass")
			main.enter_trail("paddy_road", "river_crossing")
		85:
			v.monk.x = 520.0
			v.monk.y = 232.0
			v.woke = true
			v._spawn_foes()
			v.foes[0].x = 560.0
			v.foes[0].y = 232.0
			v.foes[0].spilled = true
			v.foes[0].stun = 3.0
			v.wisps = [{"kind": "kappa", "x": 470.0, "y": 236.0, "life": 6.0}]
			GameState.spirits = [{"kind": "onibi", "cd": 0.0}, {"kind": "gaki", "cd": 4.0}]
			v.monk.face = 1
			v._spirit_special("onibi")
		100:
			_save("4_trail_spirits")
			main.enter_trail("high_pass", "castle_town")
		104:
			v.monk.x = 560.0
			v.monk.y = 230.0
			v.woke = true
			v.foes = []
			for k in ["tengu", "kitsune", "kasa", "tengu"]:
				v.foes.append({"kind": k, "x": 600.0 + v.foes.size() * 26.0, "y": 224.0 + v.foes.size() * 6.0, "hp": 25.0, "face": -1, "cd": 9.0, "atk": 0.0, "stun": 0.0, "flash": 0.0, "dead": false, "fade": 1.0, "seed": v.foes.size() * 1.3, "uid": v.foes.size()})
		108:
			_save("4b_new_yokai")
			GameState.station_id = "castle_town"
			main.enter_station("castle_town", {"area": "approach", "x": 300.0, "y": 230.0})
		112:
			v._start_night(50.0)
			v.oni.x = 300.0
			v.oni.y = 232.0
			v.glyph_t = 0.0
			v.wash = 0.0
			v.watch = [
				{"x": 360.0, "y": 236.0, "type": "watch", "hp": 30.0, "cd": 9.0, "face": -1, "down": false, "down_t": 0.0, "atk": 0.0, "lost": 0.0},
				{"x": 240.0, "y": 224.0, "type": "watch", "hp": 30.0, "cd": 9.0, "face": 1, "down": false, "down_t": 0.0, "atk": 0.0, "lost": 0.0},
			]
			v._roar()
			v.oni.x = 450.0
			v.oni.y = v.Y_MIN + 4.0
		124:
			_save("5_roar")
			GameState.nights_left = 0
			main.arrive("peak")
		130:
			v.monk.x = 450.0
			v.monk.y = 232.0
		150:
			_save("6_climb")
			GameState.curse = 45.0
			GameState.spirits = [{"kind": "kappa", "cd": 0.0}]
			main.start_duel("rite")
			main.view.player = CpuController.new(CpuController.LEVELS[2][1], 3)
		330:
			_save("7_rite_duel")
			# both stand still, so the monk's two drawn moves can be seen whole
			v.player = Still.new()
			v.cpu = Still.new()
		360:
			v.bout.fighters[0].position = Vector2(-160, 0)
			v.bout.fighters[1].position = Vector2(160, 0)
			v.bout.fighters[0].health -= 300
			v.bout.fighters[0].perform(&"ofuda")
		364:
			# physics runs several steps a frame under a slow display: save soon after
			_save("7b_ofuda")
		380:
			v.bout.fighters[0].perform(&"conch")
		385:
			_save("7c_conch")
		392:
			# J: the staff's full stroke, which turns his back toward us
			v.bout.fighters[0].perform(&"stand_light")
		395:
			_save("7d_staff")
			GameState.curse = 100.0
			GameState.begin_hunt()
			GameState.daylight = true
			GameState.hours = 12.0
			GameState.hunt_at = {"station": "post_town", "area": "street", "x": 300.0, "y": 230.0}
			GameState.oni_spirits = [{"kind": "gaki", "cd": 0.0}]
			main.start_duel("hunt")
			main.view.player = CpuController.new(CpuController.LEVELS[2][1], 5)
		520:
			# the oni calls its long-necked shikigami
			v.player = Still.new()
			v.cpu = Still.new()
			v.bout.fighters[0].position = Vector2(-200, 0)
			v.bout.fighters[1].position = Vector2(200, 0)
			v.bout.fighters[0].perform(&"summon_0")
		528:
			# the neck at full stretch (under a slow display, several physics steps a frame)
			_save("8b_ghost_neck")
		540:
			# the master exorcist knocked out: into seiza, then down
			v.bout.fighters[1].health = 0
			v.bout.fighters[1]._set_state(Fighter.State.KO, true)
		543, 548, 553, 558:
			_save("8c_ko_%d" % frame)
		560:
			_save("8_hunt_duel")
			GameState.new_run()
			GameState.curse = 40.0
			GameState.stamina = 80.0
			main.enter_trail("cedar_trail", "post_town")
		566:
			v.monk.x = 250.0
			v.monk.y = v.Y_MIN + 4.0
			v.acts.taki_option("cedar_trail").run.call()
		590:
			_save("9_takigyo")
			GameState.station_id = "village"
			GameState.station_states = {"village": {"house": 0.0}}
			main.enter_station("village", {"area": "street", "x": 820.0, "y": 212.0})
		596:
			GameState.hours = 9.0
			GameState.firewood = true
			v._day_options().filter(func(o): return o.short == "Goma")[0].run.call()
		620:
			_save("9b_goma")
			GameState.curse = 45.0
			GameState.stamina = 30.0
			GameState.nights_left = 3
			main.enter_trail("cedar_trail", "post_town")
		626:
			v.monk.x = 600.0
			v.monk.y = 232.0
			v.woke = true
			v._spawn_foes()
			GameState.oni_spirits = [{"kind": "kitsune", "cd": 0.0}]
			v._start_night(45.0)
			GameState.night_no = 2
			for i in v.foes.size():
				v.foes[i].x = v.oni.x + 40.0 + i * 22.0
				v.foes[i].y = 222.0 + (i % 3) * 12.0
			v.oni.face = 1
		640:
			v.oni.face = 1
			v._oni_strike()
		646:
			_save("10_trail_night")
			GameState.station_states = {}
			GameState.station_id = "castle_town"
			main.enter_station("castle_town", {"area": "main", "x": 520.0, "y": 230.0})
		650:
			v._start_night(40.0)
			v.watch = []
			var b = v.bld("merchant")
			v.oni.x = b.x + b.w + 30.0
			v.oni.y = v.Y_MIN + 6.0
			v.oni.face = -1
			b.burning = true
			v._fire_alarm(b)
			for w in v.watch:
				w.delay = 0.0
				w.x = b.x + b.w / 2.0 + randf_range(-110.0, 90.0)
		668:
			_save("11_fire_crowd")
			GameState.station_id = "ruined_town"
			main.enter_station("ruined_town", {"area": "street", "x": 470.0, "y": 230.0})
		704:
			v._start_night(40.0)
		730:
			_save("12_abandoned_town")
			GameState.stamina = 90.0
			GameState.coins = 10
			GameState.hours = 9.0
			GameState.station_id = "river_crossing"
			main.enter_station("river_crossing", {"area": "landing", "x": 630.0, "y": 236.0})
		734:
			v._wade()
		770:
			_save("13_wade")
			v._land()
			v.monk.x = 630.0
			v._ferry(3)
		810:
			_save("14_ferry")
			v._land()
			v._start_night(45.0)
			v.watch = []
			v.wash = 0.0
			v.glyph_t = 0.0
			v.oni.x = 846.0
			v.oni.y = 238.0
			v.oni.face = 1
		822:
			_save("15_oni_wading")
			GameState.station_id = "village"
			GameState.station_states = {"village": {"bridge": 0.0}}
			main.enter_station("village", {"area": "riverbank", "x": 250.0, "y": 236.0})
		826:
			v._ford()
		856:
			_save("16_ford")
			# the hunt: a town by day, its people about their business
			GameState.new_run()
			GameState.curse = 100.0
			GameState.record.eat = 3
			GameState.begin_hunt()
			GameState.next_phase()
			main.go_hunt({"station": "castle_town", "area": "main", "x": 380.0, "y": 232.0}, GameState.hunt_oni)
		866:
			v.wash = 0.0
			var folk: Array = v.watch.filter(func(w): return w.type == "crowd")
			for i in folk.size():
				folk[i].x = 470.0 + i * 50.0
		880:
			_save("17_hunt_day")
			v.oni.x = 440.0
		890:
			_save("18_hunt_seen")
			main.go_hunt({"trail": "high_pass", "left": "post_town", "right": "castle_town", "x": 900.0, "y": 230.0}, GameState.hunt_oni)
		904:
			_save("19_hunt_trail")
			main.go_hunt({"station": "post_town", "area": "street", "x": 30.0, "y": 230.0}, GameState.hunt_oni)
		908:
			v._road_out()
		914:
			_save("20_road_out")
			get_tree().quit()

## A fighter who does nothing.
class Still:
	func read(_me: Fighter, _them: Fighter) -> Intent:
		return Intent.new()
