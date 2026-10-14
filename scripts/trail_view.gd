extends Node2D
## The trail between two stations. The path rises and falls; climbing is
## slower and more tiring. Somewhere along it is a camp where minor demons
## gather.
##
## By day the monk fights with his staff and his signature special, a thrown
## ofuda that stuns (it recharges); the conch stuns everything in earshot. A
## defeated demon leaves its spirit behind for a few moments: strike it to
## free it (a small merit), or press Act beside it to bind it as a shikigami,
## as En no Gyoja bound his two oni. A bound shikigami answers the Spirit key
## with its own special, then needs time to recover.
##
## Dusk on the trail, or collapsing on it, means a night on it. If the seal
## holds the monk sleeps by the path; if not, the oni wakes among the yokai,
## who come out for it. It fights them with the kanabo and its roar, and may
## bind a fallen yokai for itself: an oni's shikigami, which answers only the
## oni, on the trails and in the streets. Each tightens its hold on the monk.
##
## In the hunt, after the fall, the oni walks the trails both ways, by day and
## by night: each end leads down into the town there (the temple's end stays
## warded), and there is nothing to eat out here.

const Stations := preload("res://scripts/stations.gd")
const Kit := preload("res://scripts/kit.gd")
const MonkActs := preload("res://scripts/monk_acts.gd")
const Spirits := preload("res://scripts/spirits.gd")
const Figure := preload("res://scripts/figure.gd")
const NIGHT_HUNGER := 15.0
const W := 480.0
const H := 270.0
const BACK := 192.0
const Y_MIN := 200.0
const Y_MAX := 258.0
const PAPER := Color("#ece3cf")
const OFUDA_CD := 3.0
const SPIRIT_CD := 8.0
const WISP_LIFE := 7.0
const FOE := Spirits.FOE
const NAMES := Spirits.NAMES

var main: Node
var trail_id := ""
var target := ""      # the station at the trail's right end
var left_end := ""    # and at its left: where the monk set out from
var trail := {}
var world_w := 1100.0
var slope: Array = []
var monk := {"x": 20.0, "y": 230.0, "face": 1, "moving": false, "cd": 0.0, "swing": 0.0, "hurt": 0.0, "ofuda_cd": 0.0}
var foes: Array = []
var wisps: Array = []
var talismans: Array = []
var summons: Array = []
var next_spirit := 0
var woke := false
var exorcised := 0
var fx: Array = []
var t := 0.0
var font: Font
var done := false
var acts: MonkActs
var mode := "day"
var oni := {}
var night_log := {}


func setup(tid: String, to: String, main_node: Node) -> void:
	trail_id = tid
	target = to
	main = main_node
	trail = Stations.TRAILS[tid]
	world_w = float(trail.width)
	slope = trail.get("slope", [[0, 0]])
	acts = MonkActs.new(main, monk)


func _ready() -> void:
	font = ThemeDB.fallback_font
	main.toast(_cap(trail.name))


func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


# ---------- terrain ----------
## Height of the path at world x, from the trail's slope points.
func elev(x: float) -> float:
	if slope.size() == 1:
		return float(slope[0][1])
	for i in range(1, slope.size()):
		var a: Array = slope[i - 1]
		var b: Array = slope[i]
		if x <= float(b[0]):
			var f := clampf((x - float(a[0])) / maxf(1.0, float(b[0]) - float(a[0])), 0.0, 1.0)
			return lerpf(float(a[1]), float(b[1]), f)
	return float(slope[-1][1])

func grade(x: float) -> float:
	return (elev(x + 4.0) - elev(x - 4.0)) / 8.0

var _cam := 0.0
func lift(x: float) -> float:
	return elev(x) - elev(_cam + W / 2.0)


# ---------- prompts ----------
## Who walks the trail now: the monk by day, the oni by night.
func _body() -> Dictionary:
	return oni if mode == "night" else monk

func _near_wisp():
	var b := _body()
	var reach: float = 24.0 * b.get("scale", 1.0)
	for w in wisps:
		if absf(w.x - b.x) < reach and absf(w.y - b.y) < 14.0:
			return w
	return null

func _near_kappa():
	if mode == "night":
		return null
	for f in foes:
		if f.kind == "kappa" and not f.dead and not f.get("spilled", false) and absf(f.x - monk.x) < 34.0 and absf(f.y - monk.y) < 12.0:
			return f
	return null

## The waterfall the monk stands before, if any.
func _near_falls():
	if mode == "night":
		return null
	for p in trail.props:
		if p.kind == "waterfall" and absf(p.x - monk.x) < 22.0 and monk.y < Y_MIN + 22.0:
			return p
	return null

## Whether the monk stands where roots can be dug.
func _at_forage() -> bool:
	var f = trail.get("forage")
	return mode == "day" and f != null and monk.x > f.a and monk.x < f.b

func act_icons() -> Array:
	if mode == "night":
		return ["spirit"] if _near_wisp() != null else []
	if _near_falls() != null:
		return ["water"]
	if _at_forage() and _near_wisp() == null:
		return ["forage"]
	if _near_wisp() != null:
		return ["spirit", "staff"]
	if _near_kappa() != null:
		return ["bow"]
	return []

func act_label() -> String:
	if _near_wisp() != null:
		return "Bind"
	if _near_kappa() != null:
		return "Bow"
	return "Act"

func pipe_label() -> String:
	return "Smoke"

func legend() -> Dictionary:
	if mode == "night":
		var rc: float = oni.get("roar_cd", 0.0)
		return {"I": "Bind for the oni" if _near_wisp() != null else "", "J": "Kanabo",
			"L": "Roar" if rc <= 0.0 else "Roar %ds" % int(ceil(rc)),
			"K": "" if GameState.oni_spirits.is_empty() else "Shikigami", "U": "", "O": ""}
	var w = _near_wisp()
	var act: String = "Bind" if w != null else ("Bow" if _near_kappa() != null else ("Takigyo" if _near_falls() != null else ("Forage" if _at_forage() else "")))
	var ready := 0
	for sp in GameState.spirits:
		if sp.cd <= 0.0:
			ready += 1
	return {"I": act, "J": "Free spirit" if w != null else "Staff",
		"L": ("Ofuda" if monk.ofuda_cd <= 0.0 else "Ofuda %ds" % int(ceil(monk.ofuda_cd))) + " · A+L " + acts.conch_label(),
		"K": "" if GameState.spirits.is_empty() else ("Shikigami" if ready > 0 else "Shikigami (resting)"),
		"U": "Gourd", "O": "Pipe"}


# ---------- input ----------
func _unhandled_input(event: InputEvent) -> void:
	if GameState.paused or GameState.ended or done or event.is_echo() or GameState.input_blocked() or acts.busy():
		return
	if mode == "night":
		if event.is_action_pressed("strike"):
			_oni_strike()
		elif event.is_action_pressed("act"):
			_oni_bind()
		elif event.is_action_pressed("special"):
			_roar()
		elif event.is_action_pressed("spirit"):
			_summon()
		return
	if event.is_action_pressed("strike"):
		_strike()
	elif event.is_action_pressed("act"):
		_act()
	elif event.is_action_pressed("special"):
		# A (left) and special: the conch, as away and special is in the final
		# duel; its call carries to every side
		if Input.is_action_pressed("move_left"):
			_conch()
		else:
			_ofuda()
	elif event.is_action_pressed("spirit"):
		_summon()
	elif event.is_action_pressed("pipe"):
		acts.smoke()
	elif event.is_action_pressed("gourd"):
		acts.gourd()


func _act() -> void:
	var falls = _near_falls()
	if falls != null:
		main.open_modal("The falls", "Cold water drops from the cliff into a pool.", [acts.taki_option(trail_id), {"label": "Walk on"}])
		return
	var w = _near_wisp()
	if w != null:
		if GameState.bind_spirit(w.kind):
			wisps.erase(w)
			GameState.event("bind", {"x": w.x, "who": "monk"})
			main.toast("You bind the %s with a spell of En no Gyoja. It will answer your call." % _foe_name(w.kind))
		else:
			main.toast("You can hold only %d shikigami. Strike the spirit to free it." % GameState.SPIRIT_SLOTS)
		return
	var k = _near_kappa()
	if k != null:
		# a kappa returns a bow, and spills the water in the dish on its head
		k.spilled = true
		k.stun = 3.0
		monk.cd = 0.4
		main.toast("You bow. The kappa bows back, and the water spills from its dish.")
		return
	if _at_forage():
		_forage()

## Roots and bitter greens by the path: slow, but no vow broken. Twice a day.
func _forage() -> void:
	if GameState.forage_today >= 2:
		main.toast("Nothing left here worth digging.")
		return
	GameState.forage_today += 1
	GameState.advance(1.5)
	GameState.gain_stamina(15)
	main.toast("You dig roots by the path. Bitter, but roots.")

## The monk's own special: a thrown talisman that stuns. It recharges.
func _ofuda() -> void:
	if monk.ofuda_cd > 0.0:
		return
	monk.ofuda_cd = OFUDA_CD
	GameState.event("ofuda", {"x": monk.x})
	GameState.hurt_monk(1.0)
	talismans.append({"x": monk.x + monk.face * 8.0, "y": monk.y, "vx": monk.face * 170.0, "life": 1.6})

## The horagai: its call stuns every minor yokai within earshot. It does not drive them off.
func _conch() -> void:
	if not acts.conch():
		return
	GameState.event("conch", {"x": monk.x})
	var heard := 0
	for f in foes:
		if not f.dead and absf(f.x - monk.x) < MonkActs.CONCH_REACH:
			f.stun = maxf(f.stun, MonkActs.CONCH_STUN)
			f.atk = 0.0
			heard += 1
	fx.append({"k": "conch", "x": monk.x, "y": monk.y, "life": 0.8})
	if heard > 0:
		main.toast("The conch's call rolls down the slope. The yokai stand frozen.")
	else:
		main.toast("The conch's call rolls down the slope and echoes back.")

## Call the next ready shikigami: the monk's by day, the oni's by night.
func _summon() -> void:
	var night := mode == "night"
	var slots: Array = GameState.oni_spirits if night else GameState.spirits
	if slots.is_empty():
		if night:
			main.toast("The monk's shikigami will not answer the oni." if not GameState.spirits.is_empty() else "The oni has bound no yokai of its own.")
		else:
			main.toast("You have bound no shikigami.")
		return
	var i := Spirits.next_ready(slots, next_spirit)
	if i < 0:
		main.toast("The shikigami are still gathering themselves.")
		return
	slots[i].cd = SPIRIT_CD
	next_spirit = (i + 1) % slots.size()
	_spirit_special(slots[i].kind)

## A shikigami's special, for whoever walks the trail now.
func _spirit_special(kind: String) -> void:
	var b := _body()
	var live := foes.filter(func(f): return not f.dead)
	var r := Spirits.call_special(kind, b, live, _damage, world_w)
	GameState.event("shikigami", {"x": b.x, "kind": kind})
	if r.move != null:
		b.x = r.move.x
		b.y = clampf(r.move.y, Y_MIN, Y_MAX)
		b.face = r.face
	b.ward = maxf(b.get("ward", 0.0), r.ward)
	if not r.summon.is_empty():
		summons.append(r.summon)
	if not r.fx.is_empty():
		fx.append(r.fx)
	main.toast(r.toast)


# ---------- update ----------
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	t += dt
	if not GameState.paused and not GameState.ended and not done:
		if mode == "night":
			_update_night(dt)
		else:
			_update(dt)
	for f in fx:
		f.life -= dt
		f.y -= 20.0 * dt
	fx = fx.filter(func(f): return f.life > 0)
	queue_redraw()


func _update(dt: float) -> void:
	monk.cd -= dt
	acts.tick(dt)
	monk.ofuda_cd = maxf(0.0, monk.ofuda_cd - dt)
	monk.swing = maxf(0.0, monk.swing - dt)
	monk.hurt = maxf(0.0, monk.hurt - dt)
	monk.ward = maxf(0.0, monk.get("ward", 0.0) - dt)
	for sp in GameState.spirits:
		sp.cd = maxf(0.0, sp.cd - dt)
	var dx := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var dy := int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	if acts.busy():
		dx = 0
		dy = 0
	acts.turn(dx, dy, dt, monk.swing > 0.0)
	monk.moving = dx != 0 or dy != 0
	if dx != 0:
		monk.face = dx
	# climbing: slower, and harder on the body
	var up := maxf(0.0, grade(monk.x) * dx)
	var sp := 58.0 * Kit.monk_pace(GameState.stamina) / (1.0 + up * 3.0)
	monk.x = clampf(monk.x + dx * sp * dt, 10.0, world_w)
	monk.y = clampf(monk.y + dy * sp * 0.7 * dt, Y_MIN, Y_MAX)
	if monk.moving:
		GameState.stamina = maxf(0.0, GameState.stamina - (0.5 + up * 4.0) * dt)
	GameState.advance(dt / GameState.HOUR_SECONDS)

	var camp: Dictionary = trail.camp
	if not woke and monk.x > camp.x - 120.0:
		woke = true
		_spawn_foes()
		main.toast("Something stirs in the %s." % camp.look)
	for f in foes:
		_update_foe(f, dt)
	foes = foes.filter(func(f): return not (f.dead and f.fade <= 0.0))
	for w in wisps:
		w.life -= dt
	wisps = wisps.filter(func(w): return w.life > 0.0)
	_update_talismans(dt)
	for s in summons:
		s.life -= dt
	summons = summons.filter(func(s): return s.life > 0.0)

	if monk.x >= world_w - 2.0:
		_arrive()
	elif GameState.hours >= GameState.DUSK:
		_dusk()


func _spawn_foes() -> void:
	var camp: Dictionary = trail.camp
	for kind in trail.foes:
		for i in int(trail.foes[kind]):
			foes.append({"kind": kind, "x": camp.x + randf() * camp.w, "y": randf_range(Y_MIN + 6.0, Y_MAX - 6.0),
				"hp": FOE[kind].hp, "face": -1, "cd": randf_range(0.5, 1.5), "atk": 0.0, "stun": 0.0,
				"flash": 0.0, "dead": false, "fade": 1.0, "seed": randf() * TAU, "uid": foes.size() + 1})


func _update_foe(f: Dictionary, dt: float) -> void:
	f.flash = maxf(0.0, f.flash - dt)
	f.atk = maxf(0.0, f.atk - dt)
	if f.dead:
		f.fade -= dt * 1.2
		return
	if f.stun > 0.0:
		f.stun -= dt
		return
	f.cd -= dt
	var spec: Dictionary = FOE[f.kind]
	var b := _body()
	var size: float = b.get("scale", 1.0)
	# a fox spirit blinks out and reappears behind its quarry
	if f.kind == "kitsune":
		f.blink = maxf(0.0, f.get("blink", 0.0) - dt)
		f.next_blink = f.get("next_blink", randf_range(2.5, 4.5)) - dt
		if f.next_blink <= 0.0:
			f.next_blink = randf_range(3.5, 5.5)
			f.blink = 0.4
			f.x = clampf(b.x - b.face * 16.0 * size, 10.0, world_w)
			f.y = b.y
	var ddx: float = b.x - f.x
	var ddy: float = b.y - f.y
	f.face = 1 if ddx > 0 else -1
	if absf(ddx) > spec.reach + 8.0 * (size - 1.0) or absf(ddy) > 8.0 * size:
		var d := Vector2(ddx, ddy).normalized()
		f.x += d.x * spec.speed * dt
		f.y = clampf(f.y + d.y * spec.speed * 0.7 * dt, Y_MIN, Y_MAX)
	elif f.cd <= 0.0:
		f.cd = spec.cd
		f.atk = 0.25
		var dmg: float = spec.dmg * (0.5 if b.get("ward", 0.0) > 0.0 else 1.0)
		if mode == "night":
			_hurt_oni(dmg)
			return
		GameState.hurt_monk(dmg)
		GameState.event("hurt", {"x": monk.x, "who": "monk"})
		monk.hurt = 0.2
		acts.interrupt()
		monk.x = clampf(monk.x + f.face * 8.0, 10.0, world_w)
		main.toast(spec.hurt)


func _update_talismans(dt: float) -> void:
	for tl in talismans:
		tl.x += tl.vx * dt
		tl.life -= dt
		for f in foes:
			if f.dead or absf(f.x - tl.x) > 10.0 or absf(f.y - tl.y) > 12.0:
				continue
			f.stun = 1.5
			_damage(f, 12.0, signf(tl.vx) * 6.0)
			tl.life = 0.0
			break
	talismans = talismans.filter(func(tl): return tl.life > 0.0)


func _strike() -> void:
	if monk.cd > 0:
		return
	monk.cd = 0.4
	monk.swing = 0.25
	GameState.event("strike", {"x": monk.x, "who": "monk"})
	GameState.hurt_monk(1.0)
	# a spirit within reach is freed by the staff
	var w = _near_wisp()
	if w != null:
		wisps.erase(w)
		exorcised += 1
		GameState.freed_total += 1
		GameState.event("free", {"x": w.x})
		fx.append({"k": "free", "x": w.x, "y": w.y - 20, "life": 1.0})
		GameState.add_curse(-2)
		main.toast("You free the spirit. It rises and is gone.")
		return
	for f in foes:
		if f.dead:
			continue
		var ddx: float = f.x - monk.x
		if (signf(ddx) == float(monk.face) or absf(ddx) < 6.0) and absf(ddx) < 28.0 and absf(f.y - monk.y) < 12.0:
			_damage(f, 15.0, monk.face * 10.0)


func _damage(f: Dictionary, n: float, push: float) -> void:
	# a kappa that has spilled its dish is weak: everything hurts it twice as much
	if f.get("spilled", false):
		n *= 2.0
	f.hp -= n
	f.flash = 0.15
	f.x += push
	if f.hp <= 0 and not f.dead:
		f.dead = true
		wisps.append({"kind": f.kind, "x": f.x, "y": f.y, "life": WISP_LIFE})
		if mode == "night":
			night_log.felled = night_log.get("felled", 0) + 1
			main.toast("The %s falls. Its spirit lingers: the oni may bind it (I)." % _foe_name(f.kind))
		else:
			main.toast("The %s falls. Its spirit lingers: strike to free it, Act to bind it." % _foe_name(f.kind))

func _foe_name(kind: String) -> String:
	return NAMES.get(kind, kind)


# ---------- night on the trail ----------
func _dusk() -> void:
	acts.interrupt()
	var n := GameState.begin_night()
	if GameState.ended:
		return
	if n.sleep:
		GameState.gain_stamina(30)
		main.open_modal("Night %d, on the trail" % GameState.night_no, "The seal holds. You sleep rolled in your robe beside the path, and nothing comes near.", [{"label": "Wake", "run": _wake}])
	else:
		_start_night(n.eff)

func _wake() -> void:
	GameState.new_day()
	main.toast("Dawn on %s." % trail.name)

func _start_night(eff: float) -> void:
	mode = "night"
	GameState.event("transform", {"x": monk.x})
	var length := 18.0 + eff * 0.45
	# one body: tonight's oni is as strong as the monk was at dusk, and a starved
	# one is slow (see Kit.oni_pace); whatever is left at dawn is the monk's
	oni = {"x": monk.x, "y": monk.y, "face": monk.face, "yaw": monk.get("yaw", 30.0), "scale": 1.0 + eff / 120.0,
		"hp": maxf(1.0, GameState.stamina), "maxhp": 100.0, "t": length, "hunger": NIGHT_HUNGER / length,
		"swing": 0.0, "cd": 0.0, "flash": 0.0, "roar_cd": 0.0, "roaring": 0.0, "ward": 0.0, "moving": false, "drunk": 0.0}
	night_log = {"felled": 0, "bound": 0}
	wisps = []
	talismans = []
	if not woke:
		woke = true
		_spawn_foes()
	main.toast("Night falls on the trail. The seal gives way, and the yokai of the %s come out for the oni." % trail.camp.look)

## The oni comes onto the trail in the hunt at x, its body carried from wherever it was.
func continue_night(o: Dictionary, x: float, y: float) -> void:
	mode = "night"
	oni = o.duplicate()
	for k in ["swing", "cd", "flash", "roar_cd", "roaring", "ward", "drunk"]:
		if not oni.has(k):
			oni[k] = 0.0
	oni.moving = false
	oni.x = clampf(x, 20.0, world_w - 20.0)
	oni.y = clampf(y, Y_MIN, Y_MAX)
	oni.face = 1 if oni.x < world_w / 2.0 else -1
	monk.x = oni.x
	night_log = {"felled": 0, "bound": 0}
	if not woke:
		woke = true
		_spawn_foes()

func _update_night(dt: float) -> void:
	oni.t -= dt
	oni.cd -= dt
	oni.swing = maxf(0.0, oni.swing - dt)
	oni.flash = maxf(0.0, oni.flash - dt)
	oni.roar_cd = maxf(0.0, oni.roar_cd - dt)
	oni.roaring = maxf(0.0, oni.roaring - dt)
	oni.ward = maxf(0.0, oni.ward - dt)
	# hunger: the monk wakes starved; in the hunt there is no monk, and it can kill
	oni.hp = maxf(0.0 if GameState.hunt else 1.0, oni.hp - oni.hunger * dt)
	GameState.shrink(oni, dt)
	if oni.hp <= 0.0:
		_brought_down(true)
		return
	for sp in GameState.oni_spirits:
		sp.cd = maxf(0.0, sp.cd - dt)
	var dx := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var dy := int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	oni.moving = dx != 0 or dy != 0
	if dx != 0:
		oni.face = dx
	var hold: float = NAN
	if oni.swing > 0.0:
		hold = 0.0 if oni.face > 0 else 180.0
	elif oni.roaring > 0.0:
		hold = 90.0
	Figure.turn(oni, dx, dy, dt, hold)
	var sp: float = 70.0 * (1.0 + (oni.scale - 1.0) * 0.25) * Kit.oni_pace(oni.hp)
	oni.x = clampf(oni.x + dx * sp * dt, 10.0, world_w - 10.0)
	oni.y = clampf(oni.y + dy * sp * 0.7 * dt, Y_MIN, Y_MAX)
	# the trail's end: the oni goes on down into the town, and its night goes on
	# there; in the hunt the near end leads back down too
	if dx > 0 and oni.x >= world_w - 12.0:
		if target == "peak":
			if not oni.get("warded", false):
				oni.warded = true
				main.toast("The temple's wards turn the oni back down the mountain.")
		else:
			_leave(target)
			return
	if dx < 0 and oni.x <= 12.0 and GameState.hunt:
		_leave(left_end)
		return
	for f in foes:
		_update_foe(f, dt)
		if mode != "night" or GameState.ended:
			return
	foes = foes.filter(func(f): return not (f.dead and f.fade <= 0.0))
	for w in wisps:
		w.life -= dt
	wisps = wisps.filter(func(w): return w.life > 0.0)
	for s2 in summons:
		s2.life -= dt
	summons = summons.filter(func(s2): return s2.life > 0.0)
	if oni.t <= 0.0:
		if GameState.hunt:
			_turn_phase()
		else:
			_dawn(false)

## Down off the trail into the town at one end: off the left end, the oni
## comes into that town by the road from ahead.
func _leave(to: String) -> void:
	done = true
	main.oni_enters(to, oni, Stations.entry(to, to == left_end and to != target))

## In the hunt a day gives way to a night, or a night to a day; the yokai of
## the camp gather again if the oni scattered them.
func _turn_phase() -> void:
	GameState.next_phase()
	oni.t = GameState.HUNT_PHASE
	if foes.filter(func(f): return not f.dead).is_empty():
		foes = []
		_spawn_foes()
	GameState.save_hunt(main._here(), oni)
	main.toast("Day breaks over %s." % trail.name if GameState.daylight else "Night falls over %s." % trail.name)

## The oni is beaten by the yokai, or starves. Outside the hunt the monk wakes
## at dawn; in it, this is the end.
func _brought_down(starved: bool) -> void:
	if not GameState.hunt:
		_dawn(true)
		return
	done = true
	if starved:
		main.hunt_over("Starved", "Far from any town the oni's hunger eats it from within. The exorcists find it on %s, too weak to lift the kanabo, and bind it." % trail.name)
	else:
		main.hunt_over("Torn down", "The yokai of the %s drag the oni down at last. At dawn the exorcists come up the path and bind what is left." % trail.camp.look)

func _oni_strike() -> void:
	if oni.cd > 0.0:
		return
	oni.cd = 0.55
	oni.swing = 0.25
	GameState.event("strike", {"x": oni.x, "who": "oni"})
	var reach: float = 36.0 * oni.scale
	for f in foes:
		if f.dead:
			continue
		var ddx: float = f.x - oni.x
		if (signf(ddx) == float(oni.face) or absf(ddx) < 8.0) and absf(ddx) < reach and absf(f.y - oni.y) < 14.0 * oni.scale:
			_damage(f, 30.0, oni.face * 16.0)

## The oni's roar: everything near is thrown back and stunned.
func _roar() -> void:
	if oni.roar_cd > 0.0:
		return
	oni.roar_cd = 10.0
	oni.roaring = 0.6
	GameState.event("roar", {"x": oni.x})
	GameState.record.roar += 1
	for f in foes:
		if not f.dead and absf(f.x - oni.x) < 90.0 * oni.scale and absf(f.y - oni.y) < 40.0 * oni.scale:
			f.stun = 2.0
			f.x = clampf(f.x + signf(f.x - oni.x + 0.01) * 60.0, 10.0, world_w)

## The oni takes a fallen yokai's spirit for its own.
func _oni_bind() -> void:
	var w = _near_wisp()
	if w == null:
		return
	if GameState.oni_bind(w.kind):
		wisps.erase(w)
		GameState.event("bind", {"x": w.x, "who": "oni"})
		night_log.bound += 1
		main.toast("The oni takes the %s for its own. Its hold on you tightens." % _foe_name(w.kind))
	else:
		main.toast("The oni already holds %d yokai." % GameState.SPIRIT_SLOTS)

func _hurt_oni(n: float) -> void:
	if GameState.invincible:
		return
	oni.hp -= n * GameState.diff().hurt
	oni.flash = 0.15
	if oni.hp <= 0.0:
		_brought_down(false)

## Dawn: the monk wakes where the oni ended the night, in the state it left the body.
func _dawn(fell: bool) -> void:
	GameState.event("dawn")
	GameState.stamina = 5.0 if fell else clampf(round(oni.hp), 5.0, 100.0)
	monk.x = oni.x
	monk.y = oni.y
	monk.face = oni.face
	monk.yaw = oni.yaw
	mode = "day"
	oni = {}
	wisps = []
	summons = []
	GameState.gourd = "sake"
	GameState.sips = 0
	GameState.new_day()
	var txt := "The yokai drove the oni off into the dark before dawn. " if fell else ""
	txt += "In the night the oni felled %d yokai and bound %d for itself. You wake beside the path with stamina at %d. Your gourd smells of sake." % [
		night_log.felled, night_log.bound, int(GameState.stamina)]
	main.open_modal("Dawn on the trail", txt, [{"label": "Get up"}])


func _arrive() -> void:
	done = true
	main.arrive(target)


# ---------- sound ----------
func screen_x(x: float) -> float:
	return x - _cam

## The trail's music by day; the oni's night, rising when the yokai are on it.
func music() -> Dictionary:
	if mode != "night":
		return {"tune": "trail", "tension": 0.0}
	var b := _body()
	var close := foes.any(func(f): return not f.dead and absf(f.x - b.x) < 200.0)
	var t := 0.7 if close else 0.2
	if GameState.hunt:
		t = maxf(t, 0.34)
	return {"tune": "night", "tension": t}

## Wind along the trail, falling water near a waterfall, insects in the dark.
func ambience() -> Dictionary:
	var mid := _cam + W / 2.0
	var dark := mode == "night" and not GameState.daylight
	var water := 0.0
	for p in trail.props:
		if p.kind == "waterfall":
			water = maxf(water, 1.0 - absf(p.x - mid) / 350.0)
	return {"wind": 0.6, "insects": 0.6 if dark else 0.0, "water": clampf(water, 0.0, 1.0)}


# ---------- drawing ----------
func _draw() -> void:
	var night := mode == "night"
	# in the hunt the oni walks by day too
	var dark := night and not GameState.daylight
	var b := _body()
	_cam = clampf(b.x - W / 2.0, 0.0, maxf(0.0, world_w - W))
	var cam := _cam
	var here := elev(cam + W / 2.0)
	# the higher you climb, the lower the far ridges sit
	var dk := Kit.sky(self, cam, dark, GameState.hours, GameState.moon_lit(dark), trail.backdrop, BACK + clampf(here * 0.35, -10.0, 40.0), t)
	Kit.terrain(self, cam, BACK, dk, trail.ground, lift)
	for p in trail.props:
		var sx: float = p.x - cam
		if sx + p.get("w", 0.0) < -100 or sx > W + 100:
			continue
		var by: float = BACK - lift(p.x)
		match p.kind:
			"cedar":
				Kit.cedar(self, sx, by + 2, p.get("h", 60.0), dk)
			"rock":
				Kit.rock(self, sx, by + 4, p.get("s", 10.0), dk)
			"stone_lantern":
				Kit.stone_lantern(self, sx, by + 2, dk, false)
			"torii":
				Kit.torii(self, sx, by, p.get("h", 50.0), dk, 10.0)
			"castle":
				Kit.castle(self, sx, by - 30.0, dk)
			"paddies":
				Kit.paddies(self, sx, p.get("w", 200.0), by, dk)
			"waterfall":
				Kit.waterfall(self, sx, by + 4, p.get("h", 70.0), dk, t)
	var fg = trail.get("forage")
	if fg != null:
		var bx: float = fg.a + 10.0
		while bx < fg.b:
			if bx - cam > -20 and bx - cam < W + 20:
				Kit.bush(self, bx - cam, BACK - lift(bx), dk)
			bx += 38.0
	var camp: Dictionary = trail.camp
	var cxw: float = camp.x + camp.w / 2.0
	var cx: float = cxw - cam
	if cx > -60 and cx < W + 60:
		var cl: float = lift(cxw)
		Kit.campfire(self, cx, Y_MIN + 10.0 - cl, t)
		draw_rect(Rect2(cx - 50, BACK - 30 - cl, 4, 32), Kit.shade(Color("#3b2a1f"), dk))
		draw_rect(Rect2(cx - 46, BACK - 30 - cl, 16, 10), Kit.shade(Color("#9a8f78"), dk))
		draw_rect(Rect2(cx + 40, BACK - 8 - cl, 26, 8), Kit.shade(Color("#5a4630"), dk))
	var ents: Array = [{"k": "oni" if night else "monk", "y": b.y}]
	for f in foes:
		ents.append({"k": "foe", "y": f.y, "f": f})
	for s in summons:
		ents.append({"k": "summon", "y": s.y + 0.5, "s": s})
	ents.sort_custom(func(a, b): return a.y < b.y)
	for e in ents:
		match e.k:
			"monk":
				var sw: float = 1.0 - monk.swing / 0.25 if monk.swing > 0 else 0.0
				var my: float = monk.y - lift(monk.x)
				acts.draw(self, monk.x - cam, my, t, sw)
				if monk.hurt > 0:
					draw_circle(Vector2(monk.x - cam, my - 20), 10, Color(1, 0.3, 0.2, 0.25))
			"oni":
				var oy: float = oni.y - lift(oni.x)
				Kit.oni(self, oni.x - cam, oy, oni, t, false)
				if oni.roaring > 0.0:
					var rr: float = (0.6 - oni.roaring) / 0.6 * 90.0 * oni.scale
					draw_arc(Vector2(oni.x - cam, oy - 30.0 * oni.scale), rr, 0, TAU, 32, Color(1.0, 0.85, 0.6, oni.roaring), 2.0)
			"foe":
				_draw_creature(e.f, e.f.x - cam, e.f.y - lift(e.f.x))
			"summon":
				var s: Dictionary = e.s
				Spirits.draw_summon(self, s, s.x - cam, s.y - lift(s.x), t)
	for w in wisps:
		Kit.wisp(self, w.x - cam, w.y - lift(w.x), w.kind, t)
	for tl in talismans:
		Kit.ofuda(self, tl.x - cam, tl.y - lift(tl.x) - 22.0, t)
	for f in fx:
		Spirits.draw_fx(self, f, f.x - cam, f.y - lift(f.x))
	if dark:
		draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.04, 0.12, 0.3))
	# what Act would do, above whoever walks the trail
	var icons := act_icons()
	var above: float = 54.0 * b.get("scale", 1.0) * (1.4 if night else 1.0)
	for i in icons.size():
		Kit.icon(self, icons[i], Vector2(b.x - cam + (i - (icons.size() - 1) / 2.0) * 18.0, b.y - lift(b.x) - above), true)
	if b.x > world_w - W and (not night or target != "peak"):
		draw_string(font, Vector2(0, BACK + 14), _cap(Stations.ROUTE[target].name) + " ▶", HORIZONTAL_ALIGNMENT_RIGHT, W - 4, 9, Color(PAPER, 0.7))
	if GameState.hunt and b.x < W and left_end != "":
		draw_string(font, Vector2(4, BACK + 14), "◀ " + _cap(Stations.ROUTE[left_end].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(PAPER, 0.7))
	_draw_hud()

func _draw_creature(f: Dictionary, x: float, y: float) -> void:
	var g := f.duplicate()
	g.y = y
	_draw_creature_kind(f.kind, g, x)
	if f.get("stun", 0.0) > 0.0 and not f.dead:
		for k in 3:
			var a := t * 4.0 + k * TAU / 3.0
			draw_circle(Vector2(x + cos(a) * 7.0, y - 34.0 + sin(a) * 2.0), 1.2, Color("#ffd65a"))

func _draw_creature_kind(kind: String, f: Dictionary, x: float) -> void:
	Kit.creature(self, kind, f, x, t)

func _draw_hud() -> void:
	var hh := int(GameState.hours)
	var mm := int((GameState.hours - hh) * 4) * 15
	if mode == "night":
		var when := "night %d" % GameState.night_no
		if GameState.hunt:
			when = Kit.hunt_when()
		draw_string(font, Vector2(8, 16), "%s, %s" % [_cap(trail.name), when], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PAPER)
		_bar(8, 30, 90, oni.hp / 100.0, Color("#c0392b"), "Body")
		_bar(106, 30, 70, GameState.curse / 100.0, Color("#8a4fb0"), "Curse")
		var nx := 300.0
		_slot(Vector2(nx, 26), "roar", 1.0 - oni.roar_cd / 10.0, "L roar")
		for i in GameState.SPIRIT_SLOTS:
			nx += 34.0
			if i < GameState.oni_spirits.size():
				var osp: Dictionary = GameState.oni_spirits[i]
				_slot(Vector2(nx, 26), "spirit", 1.0 - osp.cd / SPIRIT_CD, "K " + _foe_name(osp.kind).split(" ")[-1])
			else:
				draw_arc(Vector2(nx, 26), 7.0, 0, TAU, 16, Color(PAPER, 0.3), 1.0)
		draw_string(font, Vector2(0, 16), Kit.phase_left(oni.t), HORIZONTAL_ALIGNMENT_RIGHT, W - 8, 12, PAPER)
		if GameState.hunt:
			draw_string(font, Vector2(0, H - 14), Kit.master_line(), HORIZONTAL_ALIGNMENT_RIGHT, W - 6, 9, Color(PAPER, 0.85))
		draw_string(font, Vector2(0, H - 3), "v" + GameState.VERSION, HORIZONTAL_ALIGNMENT_RIGHT, W - 3, 8, Color(PAPER, 0.4))
		return
	draw_string(font, Vector2(8, 16), "%s, %d:%02d" % [_cap(trail.name), hh, mm], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PAPER)
	_bar(8, 30, 90, GameState.stamina / 100.0, Color("#c9a13a"), "Stamina")
	_bar(106, 30, 70, GameState.curse / 100.0, Color("#8a4fb0"), "Curse")
	# the ofuda and the shikigami slots, with their recharge
	var x := 300.0
	_slot(Vector2(x - 40.0, 26), "conch", 1.0 - acts.conch_cd / MonkActs.CONCH_CD, "A+L conch", 44.0)
	_slot(Vector2(x, 26), "gate", 1.0 - monk.ofuda_cd / OFUDA_CD, "L ofuda")
	for i in GameState.SPIRIT_SLOTS:
		x += 34.0
		if i < GameState.spirits.size():
			var sp: Dictionary = GameState.spirits[i]
			_slot(Vector2(x, 26), "spirit", 1.0 - sp.cd / SPIRIT_CD, "K " + _foe_name(sp.kind).split(" ")[-1])
		else:
			draw_arc(Vector2(x, 26), 7.0, 0, TAU, 16, Color(PAPER, 0.3), 1.0)
	draw_string(font, Vector2(0, 16), "Freed %d" % exorcised, HORIZONTAL_ALIGNMENT_RIGHT, W - 8, 12, PAPER)
	if GameState.invincible:
		draw_string(font, Vector2(8, 52), "TEST: invincible (F10)", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#ffd65a"))
	draw_string(font, Vector2(0, H - 3), "v" + GameState.VERSION, HORIZONTAL_ALIGNMENT_RIGHT, W - 3, 8, Color(PAPER, 0.4))

func _slot(p: Vector2, ic: String, ready: float, label: String, width := 32.0) -> void:
	Kit.icon(self, ic, p, ready >= 1.0, 1.0 if ready >= 1.0 else 0.45)
	if ready < 1.0:
		draw_arc(p, 8.5, -PI / 2, -PI / 2 + TAU * clampf(ready, 0.0, 1.0), 20, Color("#ffd65a"), 1.5)
	draw_string(font, p + Vector2(-width / 2.0, 18), label, HORIZONTAL_ALIGNMENT_CENTER, width, 8, Color(PAPER, 0.8))

func _bar(x: float, y: float, w: float, v: float, col: Color, label: String) -> void:
	draw_rect(Rect2(x, y, w, 6), Color(0.06, 0.07, 0.14, 0.7))
	draw_rect(Rect2(x, y, w * clampf(v, 0.0, 1.0), 6), col)
	draw_string(font, Vector2(x, y - 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, PAPER)
