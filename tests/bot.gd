extends Node
## Automated player, enabled only with:  godot --headless --path . --fixed-fps 60 -- --bot
## Options: --bot-policy=virtue|feed|random   --bot-runs=N   --bot-shots=DIR
##          --bot-noprayer (never pray, so the oni comes out)   --bot-trace
##          --bot-level=0|1|2 (Easy, Normal, Hard; default Normal)
##          --bot-hunt (after a fall, play the hunt to its end instead of starting
##          again; on the road its oni is untouchable, so that only hunger and
##          the master exorcist, fought in earnest, can end it)
##   virtue  keeps every vow by day; at night the oni hides and starves
##   feed    keeps every vow by day; at night the oni eats, then hides
##   random  presses things
## It plays through the real scenes. It proves the code runs and which paths
## are reachable; it says nothing about how the game feels.

var main: Node
var policy := "virtue"
var max_runs := 10
var runs := 0
var results := {}
var frame := 0
var shot_dir := ""
var shots_taken := 0
var stays := 0
var conchs := 0
var dawn_stamina: Array = []
var trace := false
var no_prayer := false
var begin_label := "Begin: Normal"
var last_mode := ""
var last_hour := -1
var hunt := false
var trail_dir := {}    # trail view -> the way the hunting oni is walking it


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot-policy="):
			policy = a.split("=")[1]
		elif a.begins_with("--bot-runs="):
			max_runs = int(a.split("=")[1])
		elif a.begins_with("--bot-level="):
			begin_label = "Begin: " + ["Easy", "Normal", "Hard"][int(a.split("=")[1])]
		elif a == "--bot-noprayer":
			no_prayer = true
		elif a == "--bot-hunt":
			hunt = true
		elif a == "--bot-trace":
			trace = true
		elif a.begins_with("--bot-shots="):
			shot_dir = a.split("=")[1]
	print("bot: policy=%s runs=%d" % [policy, max_runs])


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)

func _hold(l: bool, r: bool, u: bool = false, d: bool = false) -> void:
	for pair in [["move_left", l], ["move_right", r], ["move_up", u], ["move_down", d]]:
		if pair[1]:
			Input.action_press(pair[0])
		else:
			Input.action_release(pair[0])

func _steer(ent: Dictionary, tx: float, ty: float) -> bool:
	var dx: float = tx - ent.x
	var dy: float = ty - ent.y
	_hold(dx < -3.0, dx > 3.0, dy < -3.0, dy > 3.0)
	return absf(dx) <= 6.0 and absf(dy) <= 6.0


func _process(_delta: float) -> void:
	frame += 1
	if shot_dir != "" and frame % 500 == 0 and shots_taken < 24:
		get_viewport().get_texture().get_image().save_png("%s/shot_%02d.png" % [shot_dir, shots_taken])
		shots_taken += 1
	if main.modal_open():
		_hold(false, false)
		if frame % 3 == 0:
			_handle_modal()
		return
	if main.suppression != null:
		if frame % (6 if policy != "random" else 9) == 0:
			_press("act")
		return
	if GameState.input_blocked():
		return
	var v = main.view
	if v == null:
		return
	var path: String = v.get_script().resource_path
	if hunt and GameState.hunt:
		GameState.invincible = not path.ends_with("duel_view.gd")
	if path.ends_with("duel_view.gd"):
		# the computer fights the master exorcist for the oni
		if v.player is PlayerController:
			v.player = CpuController.new(CpuController.LEVELS[2][1], randi())
			v.bout.fighters[0].invincible = false
		return
	if path.ends_with("map_view.gd"):
		_drive_map(v)
	elif path.ends_with("trail_view.gd"):
		_drive_trail(v)
	elif path.ends_with("peak_view.gd"):
		var hall: Dictionary = v.buildings[0]
		if _steer(v.monk, hall.x + hall.w / 2.0, v.Y_MIN + 4.0) and frame % 20 == 0:
			_press("act")
	else:
		_drive_station(v)


func _handle_modal() -> void:
	var opts: Array = main.options_shown
	if opts.is_empty():
		return
	if main.modal_title.text.begins_with("Dawn"):
		dawn_stamina.append(int(GameState.stamina))
	# the journey's endings: the bot does not fight the standoffs, it records
	# how the road ended and starts again
	var journey_end: bool = main.modal_title.text in ["The rite", "The fall", "Too far gone", "The new moon passes"]
	if hunt and journey_end and main.modal_title.text != "The rite":
		print("  the hunt begins: %s" % main.modal_title.text)
		main.choose(opts[0])
		return
	if hunt and main.modal_title.text == "The road out":
		main.choose(opts[randi() % (opts.size() - 1)])
		return
	if GameState.ended or journey_end:
		var key := "%s (curse %d)" % [main.modal_title.text, int(GameState.curse)]
		if GameState.hunt:
			key = "hunt: %s (master thrown %d)" % [main.modal_title.text, GameState.master_beaten]
		results[key] = results.get(key, 0) + 1
		runs += 1
		print("run %d: %s" % [runs, key])
		if GameState.hunt:
			print("  %s" % GameState.hunt_line())
		if runs >= max_runs:
			print("bot results: ", results)
			print("bot stamina at dawn after oni nights: ", dawn_stamina)
			print("bot days spent staying for lack of stamina: ", stays)
			print("bot conch calls on the trails: ", conchs)
			get_tree().quit()
			return
		if journey_end or GameState.hunt:
			if GameState.hunt:
				GameState.invincible = false
			main.choose({"label": "record"})
			main.start_run()
			return
	var enabled := opts.filter(func(o): return not o.get("disabled", false))
	var pick = null
	if policy != "random":
		for want in [begin_label, "Begin", "The paddy", "The high", "Submit", "Return them", "Pour", "Wake", "Get up", "Go on", "Take the ferry", "Pole the ferry", "Wade", "Bow", "Pray", "Ask", "Forage", "Repair", "Buy", "Cross"]:
			for o in enabled:
				if o.label.begins_with(want):
					pick = o
					break
			if pick != null:
				break
		if pick == null:
			for o in enabled:
				if not o.get("vice", false):
					pick = o
	if pick == null:
		pick = enabled[randi() % enabled.size()]
	main.choose(pick)


func _drive_map(v) -> void:
	if v.prog <= 0.02 and GameState.stamina < GameState.TRAVEL_STAMINA and GameState.nights_left > 0:
		stays += 1
		_hold(false, false)
		_press("act")
		return
	_hold(false, true)
	if v.prog >= 0.98:
		_hold(false, false)
		_press("act")


# ---------- trail ----------
func _drive_trail(v) -> void:
	if trace and frame % 240 == 0:
		print("  trail %s %s x=%d h=%.1f st=%d curse=%d nights_left=%d" % [v.trail_id, v.mode, int(v._body().x), GameState.hours, int(GameState.stamina), int(GameState.curse), GameState.nights_left])
	if v.mode == "night":
		_drive_trail_oni(v)
		return
	if policy == "random":
		_hold(false, true)
		var r := randf()
		if r < 0.05: _press("strike")
		elif r < 0.06: _press("act")
		elif r < 0.07: _press("spirit")
		elif r < 0.08: _press("special")
		return
	# starving on the road: dig roots where the path allows
	var fg = v.trail.get("forage")
	if GameState.stamina < 30.0 and fg != null and GameState.forage_today < 2 and GameState.hours < 15.0:
		if _steer(v.monk, (fg.a + fg.b) / 2.0, 230.0) and frame % 20 == 0:
			_press("act")
		return
	# a lingering spirit: bind it while there is room, otherwise free it
	var w = v._near_wisp()
	if w == null:
		for x in v.wisps:
			if absf(x.x - v.monk.x) < 120.0:
				_steer(v.monk, x.x, x.y)
				return
	elif frame % 10 == 0:
		_press("act" if GameState.spirits.size() < GameState.SPIRIT_SLOTS else "strike")
		return
	var near = null
	var crowd := 0
	for f in v.foes:
		if not f.dead and absf(f.x - v.monk.x) < 60.0:
			near = f
		if not f.dead and f.stun <= 0.0 and absf(f.x - v.monk.x) < 120.0:
			crowd += 1
	# a crowd closing in: the conch (its keying is covered by the checks)
	if crowd >= 3 and v.acts.conch_cd <= 0.0 and GameState.stamina > 20.0:
		v._conch()
		conchs += 1
	if near != null:
		if frame % 30 == 0:
			_press("spirit")
		_steer(v.monk, near.x - 18.0 * signf(near.x - v.monk.x + 0.01), near.y)
		v.monk.face = 1 if near.x > v.monk.x else -1
		if near.kind == "kappa" and not near.get("spilled", false) and frame % 15 == 0:
			_press("act")
		elif frame % 12 == 0:
			_press("strike")
		return
	_hold(false, true)


## The oni's night on a trail: fight what comes; the feed policy binds what it fells.
func _drive_trail_oni(v) -> void:
	if policy == "random":
		_hold(randf() < 0.5, randf() < 0.5)
		if randf() < 0.05: _press("strike")
		elif randf() < 0.02: _press("special")
		return
	var w = v._near_wisp()
	if w != null and policy == "feed" and frame % 10 == 0:
		_press("act")
		return
	var near = null
	for f in v.foes:
		if not f.dead and absf(f.x - v.oni.x) < 150.0:
			near = f
	if near == null:
		if GameState.hunt:
			if not trail_dir.has(v):
				trail_dir[v] = v.oni.face
			_hold(trail_dir[v] < 0, trail_dir[v] > 0)
		else:
			_hold(false, false)
		return
	_steer(v.oni, near.x - 24.0 * signf(near.x - v.oni.x + 0.01), near.y)
	v.oni.face = 1 if near.x > v.oni.x else -1
	if frame % 15 == 0:
		_press("strike")
	elif frame % 200 == 0:
		_press("special")


# ---------- station ----------
func _find(v, pred: Callable):
	for aid in v.areas_b:
		for b in v.areas_b[aid]:
			if pred.call(b):
				return b
	return null

## Walk toward a point that may be in another area. Returns true when there.
func _go(v, aid: String, x: float, y: float) -> bool:
	if aid != v.area_id:
		for d in v.area.get("doors", []):
			if d.to == aid:
				var dy_target: float = v.Y_MIN - 5.0 if d.dir == "up" else v.Y_MAX + 5.0
				_steer(v.monk, d.x + d.w / 2.0, dy_target)
				return false
		var ex: Dictionary = v.area.get("exits", {})
		var right: bool = ex.get("right", "") == aid
		_steer(v.monk, (v.world_w + 20.0) if right else -20.0, v.monk.y)
		return false
	# never try to walk through an unbridged river
	var rv = v.area.get("river")
	if rv != null and v.bld("bridge") == null and (v.monk.x < rv.a) != (x < rv.a):
		_hold(false, false)
		return true
	# a blocker between here and there must be dealt with first
	for bl in v.area.get("blockers", []):
		if v._blocker_up(bl):
			var bm: float = bl.x + bl.w / 2.0
			if (v.monk.x < bm) != (x < bm):
				if _steer(v.monk, bl.x - 6.0 if v.monk.x < bm else bl.x + bl.w + 6.0, v.Y_MIN + 10.0) and frame % 20 == 0:
					_press("act")
				return false
	# a closed checkpoint between here and there must be passed first
	var g = v.bld("gate")
	if g != null and g.hp > 0 and not GameState.gate_passed:
		var mid: float = g.x + g.w / 2.0
		if (v.monk.x < mid) != (x < mid):
			var gx: float = g.x - 4.0 if v.monk.x < mid else g.x + g.w + 4.0
			if _steer(v.monk, gx, v.Y_MIN + 6.0) and frame % 20 == 0:
				_press("act")
			return false
	return _steer(v.monk, x, y)

func _drive_station(v) -> void:
	if trace and (v.mode != last_mode or int(GameState.hours) != last_hour):
		print("  %s %s/%s %s h=%.1f st=%d curse=%d prayer=%d heat=%d x=%d" % [v.mode, v.id, v.area_id, "gate-ok" if GameState.gate_passed else "", GameState.hours, int(GameState.stamina), int(GameState.curse), int(GameState.prayer), int(GameState.heat), int(v.monk.x)])
		last_mode = v.mode
		last_hour = int(GameState.hours)
	if v.mode == "night":
		_drive_oni(v)
		return
	if policy == "random":
		if frame % 40 == 0:
			_hold(randf() < 0.35, randf() < 0.5, randf() < 0.2, randf() < 0.2)
		var r := randf()
		if r < 0.01: _press("act")
		elif r < 0.012: _press("pipe")
		elif r < 0.014: _press("gourd")
		return
	var need := maxf(0.0, GameState.curse + GameState.NIGHTLY_CURSE - (GameState.SLEEP_BELOW - 1.0))
	var yb: float = v.Y_MIN + 6.0
	var alms_b = null
	if v.station.has("alms"):
		alms_b = _find(v, func(b): return b.id == v.station.alms.building and b.hp > 0)
	var shrine = _find(v, func(b): return b.kind == "shrine" and b.hp > 0 and not GameState.flags.get("pray:%s:%s:%d" % [v.id, b.id, GameState.night_no], false))
	var forage_area := ""
	for aid in v.station.areas:
		if v.station.areas[aid].has("forage"):
			forage_area = aid
	var damaged = _find(v, func(b): return b.hp < 100 and b.kind != "bridge")
	if alms_b != null and not GameState.alms_today and GameState.heat < 40 and (alms_b.area == v.area_id or v.bld("gate") == null or GameState.gate_passed):
		if _go(v, alms_b.area, alms_b.x + alms_b.w / 2.0, yb) and frame % 20 == 0:
			_press("act")
	elif v.Stations.ROUTE[v.id].get("must_cross", false) and not GameState.flags.get("crossed:" + v.id, false):
		for aid in v.station.areas:
			var ar: Dictionary = v.station.areas[aid]
			if ar.has("ferry"):
				if _go(v, aid, ar.river.a - 14.0, 228.0) and frame % 20 == 0:
					_press("act")
	elif GameState.stamina < 25 and forage_area != "" and GameState.forage_today < 2 and GameState.hours < 15:
		var f: Dictionary = v.station.areas[forage_area].forage
		if _go(v, forage_area, (f.a + f.b) / 2.0, 230.0) and frame % 20 == 0:
			_press("act")
	elif shrine != null and not no_prayer and GameState.prayer < need and GameState.stamina >= 12 and GameState.hours < 16:
		if _go(v, shrine.area, shrine.x + shrine.w / 2.0, yb) and frame % 20 == 0:
			_press("act")
	elif GameState.stamina < 60 and forage_area != "" and GameState.forage_today < 2 and GameState.hours < 15:
		var f2: Dictionary = v.station.areas[forage_area].forage
		if _go(v, forage_area, (f2.a + f2.b) / 2.0, 230.0) and frame % 20 == 0:
			_press("act")
	elif damaged != null and GameState.stamina > 45 and GameState.hours < 14:
		if _go(v, damaged.area, damaged.x + damaged.w / 2.0, yb) and frame % 20 == 0:
			_press("act")
	else:
		_hold(false, false)

func _drive_oni(v) -> void:
	if trace and frame % 120 == 0:
		print("    oni %s x=%d y=%d hp=%d/%d t=%.1f hidden=%s paused=%s modal=%s" % [v.area_id, int(v.oni.x), int(v.oni.y), int(v.oni.hp), int(v.oni.maxhp), v.oni.t, v.oni_hidden, GameState.paused, main.modal_open()])
	if policy == "random":
		if frame % 40 == 0:
			_hold(randf() < 0.4, randf() < 0.5, randf() < 0.3, randf() < 0.3)
		var r := randf()
		if r < 0.02: _press("act")
		elif r < 0.025: _press("pipe")
		elif r < 0.07: _press("strike")
		elif r < 0.072: _press("special")
		return
	var o: Dictionary = v.oni
	if policy == "feed" and o.hp / o.maxhp < 0.9:
		for b in v.buildings:
			if b.hp > 0 and b.kind != "bridge" and (b.pantry > 0 or b.barrels > 0):
				if _steer(o, b.x + b.w / 2.0, v.Y_MIN + 4.0) and frame % 10 == 0:
					_press("act")
				return
	if GameState.hunt:
		for b in v.buildings:
			if b.hp > 0 and b.kind != "bridge" and (b.pantry > 0 or b.barrels > 0) and o.hp / o.maxhp < 0.9:
				if _steer(o, b.x + b.w / 2.0, v.Y_MIN + 4.0) and frame % 10 == 0:
					_press("act")
				return
		for w in v.watch:
			if not w.down and w.type in ["watch", "exorcist"] and absf(w.x - o.x) < 60.0:
				o.face = 1 if w.x > o.x else -1
				if frame % 15 == 0:
					_press("strike")
		_hold(false, true)
		return
	var best = null
	for h in v.area.get("hides", []):
		if o.scale <= h.max_scale and (best == null or absf(h.x + h.w / 2.0 - o.x) < absf(best.x + best.w / 2.0 - o.x)):
			best = h
	if best != null:
		_steer(o, best.x + best.w / 2.0, v.Y_MIN + 2.0)
	else:
		_hold(false, false)
