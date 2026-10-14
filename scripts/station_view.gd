extends Node2D
## One station as a belt-scroller: side-view sprites that also move in depth.
## Buildings stand along the back of each street; people walk in the band in
## front. A station is several connected areas. By day you play the monk; by
## night, unless the seal holds, the oni. Monk and oni share one body: the
## oni's condition at dawn is the monk's.
##
## In the hunt, after the fall, there is only the oni ("night" mode, whatever
## the hour). By day the town is awake: its guards see without lanterns and its
## people run screaming. Every street edge that leads nowhere in town is a road
## out, back down the route or on along it.

const Stations := preload("res://scripts/stations.gd")
const Kit := preload("res://scripts/kit.gd")
const MonkActs := preload("res://scripts/monk_acts.gd")
const Figure := preload("res://scripts/figure.gd")
const Spirits := preload("res://scripts/spirits.gd")
const W := 480.0
const H := 270.0
const BACK := 192.0        # base line of the buildings
const Y_MIN := 200.0       # walkable depth band
const Y_MAX := 258.0
const NEAR_BACK := 224.0   # feet above this line are close enough to use a facade
const BRIDGE_Y0 := 214.0   # the bridge deck, for anyone who cannot wade
const BRIDGE_Y1 := 240.0
const BOAT_Y := 222.0      # the ferry's waterline
const FERRY_W := 60.0
const WATER := Color("#35566e")
const BANK := 24.0         # a river shelves to full depth over this far from its bank
const WAIST := 17.0 / 44.0 # how deep a wader stands, as a share of his height: to the hip
const KNEE := 9.0 / 44.0   # at the ford
const INK := Color("#0b0d1c")
const PAPER := Color("#ece3cf")
const NIGHT_HUNGER := 15.0  # body the oni burns over a night without eating
const MEAL := 18.0          # body a meal gives back (a cask gives 70% of it)
const POOL_AHEAD := 40.0   # a patrol's lantern light: centre ahead of him, and radii
const POOL_RX := 50.0
const POOL_RY := 18.0
const HEAR := 260.0         # how far the watch hears a crash or a blow: much farther than a lantern lights
const INSPECTED_HEAT := 60.0  # rumour after passing the exorcists' inspection at dawn
const DAY_SIGHT := 220.0    # how far a guard sees ahead by day, without a lantern
const DAY_FOLK := 5         # townspeople in each street by day, in the hunt
const CROWD_PER_FIRE := 5   # townspeople who come running with buckets to each fire
const CROWD_LOOKS := [{"robe": "#5b4a38", "item": "bucket"}, {"robe": "#6d5a78", "skin": "#d9b595", "item": "bucket"},
	{"robe": "#8c4b2f", "sash": "#d9cfb4", "item": "bucket"}, {"robe": "#3f4f47", "item": "bucket"}, {"robe": "#4a5a6a", "hat": "#7b6a48", "item": "bucket"}]

var main: Node
var id := ""
var station := {}
var area_id := ""
var area := {}
var areas_b := {}          # area id -> live building dictionaries
var buildings: Array = []  # the current area's buildings
var world_w := 1000.0
var mode := "day"
var monk := {"x": 140.0, "y": 228.0, "face": 1, "moving": false}
var acts: MonkActs
var crossing := {}         # the monk on his way across a river: {kind, t, len, d, x0, x1}
var ferry_side := -1.0     # the bank the ferry waits at: -1 the left, 1 the right
var oni := {}
var oni_hidden := false
var watch: Array = []
var shots: Array = []
var fx: Array = []
var summons: Array = []      # the oni's shikigami, showing themselves
var spirit_fx: Array = []
var next_oni_spirit := 0
var wisps: Array = []        # spirits of fallen yokai, in an unpeopled town
var night_log := {}
var plunder := 0
var spawn_t := 0.0
var wash := 0.0
var glyph_t := 0.0
var shake := 0.0
var cam_x := 0.0            # where the street is scrolled to, as last drawn
var t := 0.0
var font: Font
var glyph_font: Font


func setup(station_id: String, main_node: Node, wake: Dictionary = {}) -> void:
	id = station_id
	main = main_node
	acts = MonkActs.new(main, monk)
	station = Stations.def(id)
	var saved := GameState.load_station_hp(id)
	areas_b = {}
	for aid in station.areas:
		var list: Array = []
		for src in station.areas[aid].buildings:
			var b: Dictionary = src.duplicate()
			b.max_pantry = src.get("pantry", 0)
			b.max_barrels = src.get("barrels", 0)
			b.hp = float(saved.get(b.id, src.get("hp", 100.0)))
			b.pantry = b.max_pantry if b.hp > 0 else 0
			b.barrels = b.max_barrels if b.hp > 0 else 0
			# in the hunt, what the oni took is still gone until a day has passed
			var larder: Dictionary = GameState.larders.get("%s:%s" % [id, b.id], {})
			if GameState.hunt and not larder.is_empty() and b.hp > 0 and not GameState.restocked(int(larder.at)):
				b.pantry = int(larder.pantry)
				b.barrels = int(larder.barrels)
				b.taken_at = int(larder.at)
			b.burning = false
			b.fallen = b.hp <= 0
			b.area = aid
			list.append(b)
		areas_b[aid] = list
	var start: Dictionary = wake if not wake.is_empty() else station.start
	_enter_area(start.area)
	monk.x = float(start.x)
	monk.y = float(start.get("y", 228.0))
	_settle(monk, false)


func _ready() -> void:
	font = ThemeDB.fallback_font
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Noto Serif CJK JP", "Noto Sans CJK JP", "Shippori Mincho", "IPAexMincho", "IPAMincho", "Droid Sans Fallback"])
	glyph_font = sf


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	t += dt
	if not GameState.paused and not GameState.ended:
		if mode == "day":
			_update_day(dt)
		else:
			_update_night(dt)
	_update_fx(dt)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.paused or GameState.ended or event.is_echo() or GameState.input_blocked():
		return
	if mode == "day" and (acts.busy() or not crossing.is_empty()):
		return
	if event.is_action_pressed("act"):
		_act()
	elif event.is_action_pressed("pipe"):
		_pipe()
	elif event.is_action_pressed("gourd") and mode == "day":
		acts.gourd()
	elif event.is_action_pressed("strike") and mode == "night":
		_strike()
	elif event.is_action_pressed("special") and mode == "night":
		_roar()
	elif event.is_action_pressed("spirit"):
		if mode == "night":
			_oni_summon()
		elif not GameState.spirits.is_empty():
			main.toast("Your shikigami answer only against demons on the road.")


# ---------- helpers ----------
func bld(bid: String):
	for b in buildings:
		if b.id == bid:
			return b
	return null

func all_buildings() -> Array:
	var out: Array = []
	for aid in areas_b:
		out.append_array(areas_b[aid])
	return out

const ICONS := {"Buy": "food", "Steal": "food", "Alms": "food", "Pray": "prayer", "Gamble": "dice", "Gate": "gate",
	"Repair": "repair", "Fish": "water", "Refill": "water", "Ford": "ford", "Forage": "forage", "Drink": "sake", "Eat": "food",
	"Speak": "bow", "Strike": "staff", "Ferry": "boat", "Work": "boat", "Wade": "ford", "Offer": "sake", "Goma": "goma", "Wood": "wood"}

func _opt(short: String, label: String, sub: String, vice: bool, disabled: bool, run: Callable) -> Dictionary:
	return {"short": short, "label": label, "sub": sub, "vice": vice, "disabled": disabled, "run": run, "icon": ICONS.get(short, "")}

## The distinct icons among a set of options, in order.
func _icons_of(opts: Array) -> Array:
	var out: Array = []
	for o in opts:
		var ic: String = o.get("icon", "")
		if ic != "" and not out.has(ic):
			out.append(ic)
	return out

func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)

func _near_facade(ent: Dictionary, b: Dictionary, margin: float, depth: float) -> bool:
	return ent.x > b.x - margin and ent.x < b.x + b.w + margin and ent.y < depth

func act_label() -> String:
	if mode == "day":
		var o := _day_options()
		if o.is_empty():
			return "Act"
		return o[0].short if o.size() == 1 else "Choose"
	var n = _night_option()
	return n.short if n != null else "Eat"

func pipe_label() -> String:
	return "Smoke" if mode == "day" else "Ignite"

## What each of the IJKL keys (and U, O) does right now, for the on-screen legend.
func legend() -> Dictionary:
	if mode == "day":
		var o := _day_options()
		var act: String = "" if o.is_empty() or not crossing.is_empty() else (o[0].short if o.size() == 1 else "Choose")
		return {"I": act, "J": "", "L": "", "K": "", "U": "Gourd", "O": "Pipe"}
	var n = _night_option()
	var rc: float = oni.get("roar_cd", 0.0)
	return {"I": n.short if n != null else "", "J": "Kanabo", "L": "Roar" if rc <= 0.0 else "Roar %ds" % int(ceil(rc)),
		"K": "" if GameState.oni_spirits.is_empty() else "Shikigami", "U": "", "O": "Fire" if _burnable() != null else "Fire: near a house"}

func _enter_area(aid: String) -> void:
	area_id = aid
	area = station.areas[aid]
	buildings = areas_b[aid]
	world_w = float(area.width)


# ---------- movement ----------
func _walkable(x: float, y: float, is_oni: bool) -> bool:
	var r = area.get("river")
	if r != null and x > r.a and x < r.b:
		if is_oni:
			return true
		var br = bld("bridge")
		return br != null and br.hp > 0 and y >= BRIDGE_Y0 and y <= BRIDGE_Y1
	return true

func _in_river(x: float) -> bool:
	var r = area.get("river")
	return r != null and x > r.a and x < r.b

## How far below the surface someone standing at x would have his feet, for a
## full depth of `depth`: the river shelves from its banks.
func _sink(x: float, depth: float) -> float:
	var r = area.get("river")
	if r == null:
		return 0.0
	return depth * clampf(minf(x - r.a, r.b - x) / BANK, 0.0, 1.0)

## How deep the oni stands where he is: nothing on the bridge.
func _oni_sink() -> float:
	var br = bld("bridge")
	if br != null and br.hp > 0 and oni.y >= BRIDGE_Y0 and oni.y <= BRIDGE_Y1:
		return 0.0
	return _sink(oni.x, 64.0 * oni.scale * WAIST)

## Move an entity, sliding along obstacles. Returns true if it left the area.
func _move(ent: Dictionary, dx: float, dy: float, is_oni: bool, may_exit: bool) -> bool:
	var nx: float = ent.x + dx
	var ny: float = clampf(ent.y + dy, Y_MIN, Y_MAX)
	if _walkable(nx, ny, is_oni):
		ent.x = nx
		ent.y = ny
	elif _walkable(ent.x, ny, is_oni):
		ent.y = ny
	elif _walkable(nx, ent.y, is_oni):
		ent.x = nx
	var ex: Dictionary = area.get("exits", {})
	if may_exit and dx < 0 and ent.x < 10.0 and ex.has("left"):
		_change_area(ex.left, ent, -1.0, ent.y)
		return true
	if may_exit and dx > 0 and ent.x > world_w - 10.0 and ex.has("right"):
		_change_area(ex.right, ent, 16.0, ent.y)
		return true
	if may_exit and is_oni and GameState.hunt and ((dx < 0 and ent.x < 10.0 and not ex.has("left")) or (dx > 0 and ent.x > world_w - 10.0 and not ex.has("right"))):
		_road_out()
		return true
	if may_exit:
		for d in area.get("doors", []):
			if ent.x < d.x or ent.x > d.x + d.w:
				continue
			if d.dir == "up" and dy < 0 and ent.y <= Y_MIN + 0.5:
				_change_area(d.to, ent, float(d.at), Y_MAX - 4.0)
				return true
			if d.dir == "down" and dy > 0 and ent.y >= Y_MAX - 0.5:
				_change_area(d.to, ent, float(d.at), Y_MIN + 4.0)
				return true
	ent.x = clampf(ent.x, 10.0, world_w - 10.0)
	return false

## Move an entity into another area of the station at (x, y); x < 0 means the far right edge.
func _change_area(to: String, ent: Dictionary, x: float, y: float) -> void:
	_enter_area(to)
	ent.x = world_w - 16.0 if x < 0 else x
	ent.y = y
	_settle(ent, ent == oni)
	watch = []
	shots = []
	wash = 0.35
	if mode == "night":
		_spawn_patrols()
	main.toast(_cap(area.name))

## Put an entity somewhere legal: out of the water if it cannot wade, and on
## the monk's side of a closed checkpoint.
func _settle(ent: Dictionary, is_oni: bool) -> void:
	ent.y = clampf(ent.y, Y_MIN, Y_MAX)
	ent.x = clampf(ent.x, 10.0, world_w - 10.0)
	if not is_oni and not _walkable(ent.x, ent.y, false):
		var r = area.river
		ent.x = r.a - 6.0 if ent.x < (r.a + r.b) / 2.0 else r.b + 6.0

func _gate_side_clamp(prev_x: float) -> void:
	var walls: Array = []
	var g = bld("gate")
	if g != null and g.hp > 0 and not GameState.gate_passed:
		walls.append(g)
	for bl in area.get("blockers", []):
		if _blocker_up(bl):
			walls.append(bl)
	for wl in walls:
		var mid: float = wl.x + wl.w / 2.0
		if prev_x < mid:
			monk.x = minf(monk.x, wl.x - 4.0)
		else:
			monk.x = maxf(monk.x, wl.x + wl.w + 4.0)

## A blocker stands in the street by day until dealt with.
func _blocker_up(bl: Dictionary) -> bool:
	return mode == "day" and not GameState.flags.get("passed:%s:%s" % [id, bl.id], false)

func _near_blocker():
	for bl in area.get("blockers", []):
		if _blocker_up(bl) and absf(monk.x - (bl.x + bl.w / 2.0)) < bl.w / 2.0 + 20.0:
			return bl
	return null

## Whether the monk has reached the far side of a river he must cross.
func _check_crossed() -> void:
	if not Stations.ROUTE[id].get("must_cross", false):
		return
	var r = area.get("river")
	if area.get("far_side", false) or (area.has("ferry") and r != null and monk.x > r.b):
		GameState.flags["crossed:" + id] = true


# ---------- day ----------
func _day_options() -> Array:
	var o: Array = []
	for b in buildings:
		if b.kind == "bridge" or not _near_facade(monk, b, 12.0, NEAR_BACK):
			continue
		if b.hp > 0:
			match b.kind:
				"stall":
					o.append(_opt("Buy", "Buy food (3 coins)", "+25 stamina", false, GameState.coins < 3, _buy))
					o.append(_opt("Steal", "Steal food", "+25 stamina. Breaks the vow against stealing", true, false, _steal))
				"shrine":
					o.append(_pray_opt(b))
					o.append(_goma_opt(b))
				"den":
					o.append(_opt("Gamble", "Gamble 2 coins", "Double or nothing. A lapse of discipline", true, GameState.coins < 2, _gamble))
				"gate":
					if not GameState.gate_passed:
						o.append(_opt("Gate", "Approach the checkpoint", "Guards and an exorcist inspect every traveller", false, false, _checkpoint))
			if station.has("alms") and station.alms.building == b.id:
				o.append(_opt("Alms", "Ask %s for alms" % station.alms.giver, "Only if the village still trusts strangers", false, false, _alms))
		if b.hp < 100:
			o.append(_opt("Repair", "Repair %s" % b.name, "Costs 3 hours. Earns coins and trust", false, false, _repair.bind(b)))
		if b.hp <= 0:
			o.append(_goma_opt(b))
	var bl = _near_blocker()
	if bl != null:
		o.append(_opt("Speak", "Bow and speak calmly to %s" % bl.name, "He may let a humble monk pass. Not if your name or your horns give you away", false, false, _speak.bind(bl)))
		o.append(_opt("Strike", "Knock him down with your staff", "Quick. Breaks the vow against violence, and people will talk", true, false, _strike_blocker.bind(bl)))
		if GameState.gourd == "sake":
			o.append(_opt("Offer", "Offer him the sake in your gourd", "A small lapse: a monk does not deal in drink", true, false, _offer_sake.bind(bl)))
	var r = area.get("river")
	if r != null and monk.x > r.a - 24 and monk.x < r.b + 24:
		o.append(_opt("Fish", "Catch and eat a fish", "+45 stamina. Breaks the vow against killing", true, false, _fish))
		o.append(_opt("Refill", "Refill the gourd with water", "Two sips. Pours out anything else in it", false, false, _refill))
		if area.has("ferry") and bld("bridge") == null:
			var fare: int = area.ferry.fare
			o.append(_opt("Ferry", "Take the ferry (%d coins)" % fare, "Half an hour across", false, GameState.coins < fare, _ferry.bind(fare)))
			o.append(_opt("Work", "Pole the ferry for your passage", "Three hours of work, and a coin besides", false, false, _work_ferry))
			o.append(_opt("Wade", "Wade across", "An hour and 20 stamina; the current is strong", false, GameState.stamina < 30, _wade))
		var br = bld("bridge")
		if br != null and br.hp < 100:
			o.append(_opt("Repair", "Repair the bridge", "Costs 3 hours. Earns coins and trust", false, false, _repair.bind(br)))
		if br != null and br.hp <= 0:
			o.append(_opt("Ford", "Cross by the ford upstream", "Costs 1½ hours and 5 stamina", false, false, _ford))
	var wl = area.get("well")
	if wl != null and absf(monk.x - wl.x) < 22.0 and monk.y < NEAR_BACK:
		o.append(_opt("Refill", "Draw water from the well", "Fills the gourd: two sips. Pours out anything else in it", false, false, _refill))
	var f = area.get("forage")
	if f != null and monk.x > f.a and monk.x < f.b:
		o.append(_opt("Forage", "Forage for roots", "+15 stamina. Costs 1½ hours", false, false, _forage))
		if not GameState.firewood:
			o.append(_opt("Wood", "Gather firewood for a goma", "A bundle of cut wood. Costs an hour", false, false, _gather_wood))
	return o


func _act() -> void:
	if mode == "night":
		var n = _night_option()
		if n != null:
			n.run.call()
		return
	var o := _day_options()
	if o.is_empty():
		return
	if o.size() == 1 and not o[0].vice and not o[0].disabled:
		o[0].run.call()
	else:
		o.append({"label": "Leave"})
		main.open_modal("What will you do?", "", o)


func _pipe() -> void:
	if mode == "night":
		_ignite()
		return
	acts.smoke()


func _buy() -> void:
	GameState.coins -= 3
	GameState.gain_stamina(25)
	GameState.advance(0.25)
	main.toast("Warm food, honestly paid for.")

func _steal() -> void:
	GameState.gain_stamina(25)
	if randf() < 0.5:
		_heat(6)
		main.toast("The vendor saw your face.")
	else:
		main.toast("Nobody saw. You did.")
	GameState.add_curse(10)

func _alms() -> void:
	if GameState.alms_today:
		main.toast("%s has already given what she can spare." % _cap(station.alms.giver))
	elif GameState.heat >= 40:
		main.toast("%s shuts her door: \"Something walks these nights. Nothing for strangers.\"" % _cap(station.alms.giver))
	else:
		GameState.alms_today = true
		GameState.gain_stamina(30)
		GameState.advance(0.5)
		main.toast("%s gives you millet and asks for a blessing." % _cap(station.alms.giver))

## Prayer at a shrine, once a day at each (a goma there is another matter).
func _pray_opt(b: Dictionary) -> Dictionary:
	var key := "pray:%s:%s:%d" % [id, b.id, GameState.night_no]
	var done: bool = GameState.flags.get(key, false)
	return _opt("Pray", "Pray", "You have already prayed here today" if done else "Weakens tonight's oni. Costs 2 hours", false, done, _pray.bind(key))

func _pray(key: String) -> void:
	if GameState.stamina < 10:
		main.toast("Too weak to kneel.")
		return
	GameState.flags[key] = true
	GameState.stamina -= 10
	GameState.advance(2.0)
	GameState.prayer += 20
	acts.play("pray", 3.0, -90.0)
	GameState.event("pray", {"x": monk.x})
	main.toast("You pray. Tonight the oni is weaker by %d." % int(GameState.prayer))
	GameState.add_curse(-2)

func _repair(b: Dictionary) -> void:
	if GameState.stamina < 25:
		main.toast("Too weak for a day of carpentry.")
		return
	GameState.stamina -= 25
	GameState.advance(3.0)
	b.hp = 50.0 if b.hp <= 0 else 100.0
	b.fallen = false
	GameState.coins += b.pay
	_heat(-10)
	main.toast("You repair %s%s." % [b.name, (" and are paid %d coins" % b.pay) if b.pay > 0 else ""])
	GameState.add_curse(-6)

func _forage() -> void:
	if GameState.forage_today >= 2:
		main.toast("Nothing left here worth digging.")
		return
	GameState.forage_today += 1
	GameState.advance(1.5)
	GameState.gain_stamina(15)
	main.toast("Bitter roots, but roots.")

func _fish() -> void:
	GameState.gain_stamina(45)
	main.toast("The fish is good. The vow against killing is broken.")
	GameState.add_curse(12)

func _refill() -> void:
	GameState.gourd = "water"
	GameState.sips = 2
	main.toast("The gourd holds clean water.")

func _ford() -> void:
	GameState.advance(1.5)
	GameState.stamina = maxf(0.0, GameState.stamina - 5.0)
	_cross("ford", 4.5)
	main.toast("You wade the ford, the water at your knees.")

func _ferry(fare: int) -> void:
	GameState.coins -= fare
	GameState.advance(0.5)
	_cross("ferry", 4.0)
	main.toast("The ferryman poles you across without a word.")

func _work_ferry() -> void:
	if GameState.stamina < 25:
		main.toast("Too weak to pole a boat.")
		return
	GameState.stamina -= 20
	GameState.advance(3.0)
	GameState.coins += 1
	_cross("pole", 5.0)
	main.toast("You pole travellers back and forth all afternoon, and cross with the last of them.")

func _wade() -> void:
	GameState.stamina -= 20
	GameState.advance(1.0)
	_cross("wade", 6.0)
	main.toast("You wade across waist-deep, the current dragging at your robe.")

## Set the monk across the river over `secs`: by boat ("ferry" as a
## passenger, "pole" working it) or on foot ("wade", "ford"). The hours and
## stamina are already spent; this is the crossing itself, which nothing interrupts.
func _cross(kind: String, secs: float) -> void:
	var r = area.river
	var d := 1.0 if monk.x < (r.a + r.b) / 2.0 else -1.0
	crossing = {"kind": kind, "t": 0.0, "len": secs, "d": d, "x0": monk.x, "x1": r.b + 8.0 if d > 0 else r.a - 8.0}
	monk.face = int(d)
	acts.interrupt()
	if _by_boat():
		monk.y = BOAT_Y
	_update_crossing(0.0)

func _by_boat() -> bool:
	return crossing.get("kind", "") in ["ferry", "pole"]

func _update_crossing(dt: float) -> void:
	crossing.t += dt
	var k := clampf(crossing.t / crossing.len, 0.0, 1.0)
	if _by_boat():
		monk.moving = false
		monk.x = _boat_x() + FERRY_W * _aboard(true)
	else:
		monk.moving = true
		monk.x = lerpf(crossing.x0, crossing.x1, k)
	acts.turn(crossing.d, 0.0, maxf(dt, 0.001))
	if k >= 1.0:
		_land()

## Where on the boat (as a share of its length) the monk stands: the bow as a
## passenger, the stern when he poles. `crossing.d` is the way it is going.
func _aboard(monk_side: bool) -> float:
	var poling: bool = crossing.kind == "pole"
	var at_bow := monk_side != poling
	return 0.5 + crossing.d * (0.2 if at_bow else -0.2)

func _land() -> void:
	if _by_boat():
		ferry_side = crossing.d
	monk.x = crossing.x1
	monk.moving = false
	crossing = {}
	_check_crossed()

## The ferry's left end: tied at one bank, or on its way across.
func _boat_x() -> float:
	var r = area.river
	var near: float = r.a + 6.0
	var far: float = r.b - 6.0 - FERRY_W
	if _by_boat():
		var k := smoothstep(0.0, 1.0, crossing.t / crossing.len)
		return lerpf(near, far, k) if crossing.d > 0 else lerpf(far, near, k)
	return near if ferry_side < 0 else far

func _speak(bl: Dictionary) -> void:
	GameState.advance(0.5)
	if GameState.heat < 30 and GameState.curse < 60:
		GameState.flags["passed:%s:%s" % [id, bl.id]] = true
		main.toast("He squints at you, mutters about monks, and staggers off to find more sake.")
	else:
		GameState.hurt_monk(15)
		monk.x -= 30.0 if monk.x < bl.x else -30.0
		main.toast("\"I know what walks at night, monk.\" He draws on you; you barely get clear.")

func _strike_blocker(bl: Dictionary) -> void:
	GameState.flags["passed:%s:%s" % [id, bl.id]] = true
	GameState.advance(0.25)
	_heat(12)
	main.toast("One blow and he is in the gutter. The street goes quiet, and watches you.")
	GameState.add_curse(8)

func _gamble() -> void:
	GameState.advance(0.5)
	if randf() < 0.5:
		GameState.coins += 2
		main.toast("The dice favour you. Two coins richer.")
	else:
		GameState.coins -= 2
		main.toast("The dice take two coins.")
	GameState.add_curse(4)

func _checkpoint() -> void:
	main.open_modal("The checkpoint", "Guards stop every traveller. Behind them an exorcist holds a talisman up to each face.", [
		_opt("", "Submit to inspection", "Hold the oni down while the talisman burns. Harder the deeper your curse", false, false, _inspect),
		_opt("", "Lie about who you are", "You pass freely. Breaks the vow against false speech", true, false, _lie),
		{"label": "Turn back"},
	])

func _inspect() -> void:
	main.start_suppression(GameState.curse, _inspected)

func _inspected(ok: bool) -> void:
	GameState.advance(0.5)
	if ok:
		GameState.gate_passed = true
		GameState.event("gate")
		_heat(-3)
		main.toast("The talisman cools. The guards wave you through.")
	else:
		_heat(25)
		main.toast("The oni surges against the talisman. The guards drive you back.")

func _lie() -> void:
	GameState.gate_passed = true
	GameState.event("gate")
	main.toast("\"A pilgrim from Kumano.\" They wave you through.")
	GameState.add_curse(6)

## The goma: a fire rite before a shrine, or on the ashes of a house the oni burned.
## The town comes to watch unless rumour has turned it against you.
func _goma_opt(b: Dictionary) -> Dictionary:
	var key := "goma:%s:%d" % [id, GameState.night_no]
	var sub := "Three hours. Needs a bundle of firewood"
	var ok: bool = GameState.firewood and GameState.hours <= 15.0 and not GameState.flags.get(key, false)
	if GameState.flags.get(key, false):
		sub = "You have already lit a goma here today"
	elif GameState.hours > 15.0:
		sub = "Too late in the day to begin"
	elif GameState.firewood:
		sub = "Three hours. Eases the curse; if the town comes, rumour too" + (". These ashes most of all" if b.hp <= 0 else "")
	var where := "on the ashes of %s" % b.name if b.hp <= 0 else "before %s" % b.name
	return _opt("Goma", "Light a goma fire %s" % where, sub, false, not ok, _goma.bind(b, key))

func _goma(b: Dictionary, key: String) -> void:
	GameState.flags[key] = true
	GameState.firewood = false
	GameState.advance(3.0)
	acts.play("goma", 4.0, 20.0 if monk.face > 0 else 160.0)
	GameState.event("goma", {"x": monk.x})
	var ruin: bool = b.hp <= 0
	if _peopled() and GameState.heat < 50:
		_heat(-15.0 - (10.0 if ruin else 0.0))
		GameState.coins += 2
		GameState.add_curse(-12.0 - (6.0 if ruin else 0.0))
		main.toast("Townsfolk gather at the fire and leave offerings. " + ("They say the ruin is clean now." if ruin else "The smoke carries their prayers and yours."))
	else:
		GameState.add_curse(-6)
		main.toast("You chant alone before the fire. Doors stay shut; nobody comes.")

func _gather_wood() -> void:
	GameState.firewood = true
	GameState.advance(1.0)
	main.toast("You cut and bundle wood for a goma fire.")

func _offer_sake(bl: Dictionary) -> void:
	GameState.flags["passed:%s:%s" % [id, bl.id]] = true
	GameState.gourd = "empty"
	GameState.advance(0.25)
	main.toast("He snatches the gourd, drinks it dry and waves you past. Whatever he suspects, it can wait.")
	GameState.add_curse(3)


func _update_day(dt: float) -> void:
	var dx := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var dy := int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	acts.tick(dt)
	if acts.busy():
		dx = 0
		dy = 0
	if not crossing.is_empty():
		_update_crossing(dt)
		dx = 0
		dy = 0
	else:
		acts.turn(dx, dy, dt)
		monk.moving = dx != 0 or dy != 0
	if dx != 0 or dy != 0:
		if dx != 0:
			monk.face = dx
		# a weak body walks slowly
		var sp := 58.0 * Kit.monk_pace(GameState.stamina)
		var prev: float = monk.x
		if not _move(monk, dx * sp * dt, dy * sp * 0.7 * dt, false, true):
			_gate_side_clamp(prev)
		GameState.stamina = maxf(0.0, GameState.stamina - 0.5 * dt)
		_check_crossed()
	GameState.advance(dt / GameState.HOUR_SECONDS)
	if GameState.hours >= GameState.DUSK:
		_dusk()


# ---------- transitions ----------
func _dusk() -> void:
	if not crossing.is_empty():
		_land()
	var n := GameState.begin_night()
	if GameState.ended:
		return
	if n.sleep:
		GameState.event("sleep")
		_heat(-20)
		GameState.gain_stamina(40)
		main.open_modal("Night %d" % GameState.night_no, "The seal holds. For once you sleep, and %s sleeps with you." % Stations.ROUTE[id].name, [{"label": "Wake", "run": _leave_at_dawn}])
	else:
		_start_night(n.eff)

func _start_night(eff: float) -> void:
	mode = "night"
	GameState.event("transform", {"x": monk.x})
	wash = 1.4
	glyph_t = 1.4
	var length := 18.0 + eff * 0.45
	# one body: the oni's strength tonight is the monk's stamina at dusk, on the
	# same 0-100 scale, and whatever is left of it at dawn is the monk's again.
	# Hunger takes a fixed share over a night; meals give it back.
	oni = {"x": monk.x, "y": monk.y, "face": monk.face, "yaw": monk.get("yaw", 30.0), "scale": 1.0 + eff / 120.0, "hp": maxf(1.0, GameState.stamina), "maxhp": 100.0, "t": length,
		"hunger": NIGHT_HUNGER / length, "dmg": 1.0, "drunk": 0.0, "slow": 0.0, "swing": 0.0, "cd": 0.0, "flash": 0.0}
	watch = []
	shots = []
	night_log = {"eat": 0, "drink": 0, "smash": 0, "burn": 0, "heat0": GameState.heat, "spotted": 0}
	plunder = 0
	spawn_t = 4.0
	_spawn_patrols()
	# changing in the open, among people, may be seen; a hiding place is safer
	if not area.get("npcs", []).is_empty() and not _in_hide(monk, 1.0) and randf() < 0.5:
		_heat(12)
		night_log.witnessed = true
		main.toast("The seal gives way, and someone sees the monk become the oni.")
	else:
		main.toast("The seal gives way. The oni wakes, and it is hungry.")

func _dawn(fell: bool) -> void:
	GameState.event("dawn")
	if not night_log.has("witnessed"):
		night_log.witnessed = false
	for b in all_buildings():
		b.burning = false
		b.pantry = b.max_pantry if b.hp > 0 else 0
		b.barrels = b.max_barrels if b.hp > 0 else 0
	# one body: the monk wakes in whatever state the oni left it
	GameState.stamina = 5.0 if fell else clampf(round(oni.hp), 5.0, 100.0)
	monk.x = oni.x
	monk.y = oni.y
	monk.face = oni.face
	monk.yaw = oni.get("yaw", 30.0)
	mode = "day"
	wash = 0.8
	watch = []
	shots = []
	wisps = []
	oni = {}
	_settle(monk, false)
	_check_crossed()
	GameState.gourd = "sake"
	GameState.sips = 0
	_heat(-5)
	var raided: int = night_log.eat + night_log.drink
	_heat(3.0 * raided)
	var L := night_log
	var habits: Array = []
	if L.eat > 0: habits.append("ate %d" % L.eat)
	if L.drink > 0: habits.append("drank %d" % L.drink)
	if L.smash > 0: habits.append("smashed %d" % L.smash)
	if L.burn > 0: habits.append("set %d fires" % L.burn)
	var body := "Beaten, the oni fled into the dark before dawn. " if fell else ""
	if raided > 0:
		body += "The town finds its stores raided. "
	var cond := "You wake with stamina at %d." % int(GameState.stamina)
	var txt := "%sLast night the oni %s. Heat rose by %d. %s Your gourd smells of sake." % [
		body,
		", ".join(habits) if habits.size() > 0 else "fed on nothing and broke nothing",
		maxi(0, int(round(GameState.heat - L.heat0 + 5))), cond]
	var report := _dawn_report.bind("Dawn after night %d" % GameState.night_no, txt)
	# at full rumour the exorcists are waiting, and test him as at a checkpoint
	if GameState.heat >= 100:
		main.open_modal("Exorcists at dawn", "The exorcists are waiting when you wake. One holds a talisman up to your face.", [
			_opt("", "Submit to inspection", "Hold the oni down while the talisman burns. Harder the deeper your curse", false, false,
				main.start_suppression.bind(GameState.curse, _dawn_inspected.bind(report))),
		])
		return
	report.call()

func _dawn_inspected(ok: bool, report: Callable) -> void:
	if not ok:
		main.end_run("Bound", "The oni surges against the talisman, and the exorcists see the mark under your cap. You are taken.")
		return
	GameState.heat = INSPECTED_HEAT
	main.toast("The talisman cools. The exorcists let you go, but they will be watching.")
	report.call()

func _dawn_report(title: String, txt: String) -> void:
	if plunder > 0:
		main.open_modal(title, txt + " Beside you lie %d coins that are not yours." % plunder, [
			_opt("", "Keep the coins", "Breaks the vow against stealing", true, false, _keep_plunder),
			_opt("", "Return them", "Costs an hour. Someone may wonder how you found them", false, false, _return_plunder),
		])
	else:
		main.open_modal(title, txt, [{"label": "Get up", "run": _leave_at_dawn}])

# ---------- the hunt ----------
## A day gives way to a night, or a night to a day. The town mends a little,
## raises a ruin only when its days are up, and restocks a raided building a
## day after the raid; a new watch comes on; the master exorcist may have
## caught up.
func _turn_phase() -> void:
	var due := GameState.next_phase()
	oni.t = GameState.HUNT_PHASE
	for b in all_buildings():
		b.hp = GameState.rebuilt(id, b.id, b.hp)
		b.fallen = b.hp <= 0
		if b.hp > 0 and (not b.has("taken_at") or GameState.restocked(b.taken_at)):
			b.pantry = b.max_pantry
			b.barrels = b.max_barrels
			b.erase("taken_at")
	watch = watch.filter(func(w): return w.type in ["watch", "exorcist"] and not w.down)
	_spawn_patrols()
	wash = 0.5
	GameState.save_station(id, all_buildings())
	GameState.save_hunt(main._here(), oni)
	if GameState.daylight:
		main.toast("Day breaks over %s. The town wakes, and sees." % Stations.ROUTE[id].name)
	else:
		main.toast("Night falls over %s. The watch lights its lanterns." % Stations.ROUTE[id].name)
	if due and _peopled():
		_master()

func _master() -> void:
	if GameState.ended or mode != "night":
		return
	GameState.save_station(id, all_buildings())
	main.master_comes({"station": id, "area": area_id, "x": oni.x, "y": oni.y}, oni)

## The oni walks off the edge of town onto a road: which one?
func _road_out() -> void:
	var opts: Array = []
	for r in Stations.roads(id):
		var trail: Dictionary = Stations.TRAILS[r.trail]
		opts.append({"label": "Take %s to %s" % [trail.name, Stations.ROUTE[r.to].name], "run": _take_road.bind(r)})
	opts.append({"label": "Stay in %s" % Stations.ROUTE[id].name, "run": _stay})
	main.open_modal("The road out", "", opts)

func _take_road(r: Dictionary) -> void:
	GameState.save_station(id, all_buildings())
	main.oni_takes_road(r.trail, id, r.to, oni)

func _stay() -> void:
	oni.x = clampf(oni.x, 30.0, world_w - 30.0)


func _keep_plunder() -> void:
	GameState.coins += plunder
	GameState.add_curse(10)
	if not GameState.ended:
		_leave_at_dawn()

func _return_plunder() -> void:
	GameState.return_penalty = 1.0
	GameState.add_curse(-4)
	if GameState.heat >= 50:
		_heat(8)
		main.toast("The owner looks at you a moment too long.")
	else:
		_heat(-5)
	_leave_at_dawn()

func _leave_at_dawn() -> void:
	GameState.save_station(id, all_buildings())
	main.go_map({"area": area_id, "x": monk.x, "y": monk.y})


# ---------- night ----------
func _night_option():
	for w in wisps:
		if absf(w.x - oni.x) < 24.0 * oni.scale and absf(w.y - oni.y) < 16.0:
			return {"short": "Bind", "icon": "spirit", "run": _oni_bind_wisp.bind(w)}
	for b in buildings:
		if b.kind == "bridge" or b.hp <= 0 or not _near_facade(oni, b, 10.0 * oni.scale, NEAR_BACK + 8.0 * oni.scale):
			continue
		if b.barrels > 0:
			return {"short": "Drink", "icon": "sake", "run": _oni_drink.bind(b)}
		if b.pantry > 0:
			return {"short": "Eat", "icon": "food", "run": _oni_eat.bind(b)}
	return null

## The oni takes from a building's stores. In the hunt the town refills them
## a day after it first did.
func _take(b: Dictionary) -> void:
	if GameState.hunt and not b.has("taken_at"):
		b.taken_at = GameState.hunt_phase

func _oni_drink(b: Dictionary) -> void:
	_take(b)
	b.barrels -= 1
	_heal(MEAL * 0.7)
	oni.dmg = minf(2.0, oni.dmg + 0.2)
	oni.drunk = minf(12.0, oni.drunk + 5.0)
	_heat(1)
	GameState.record.drink += 1
	night_log.drink += 1
	_oni_pose("drink")
	GameState.event("drink", {"x": oni.x, "who": "oni"})
	main.toast("The oni drains a cask. Stronger, and less steady.")

func _oni_eat(b: Dictionary) -> void:
	_take(b)
	b.pantry -= 1
	GameState.grow(oni)
	_heal(MEAL)
	_heat(2)
	GameState.record.eat += 1
	night_log.eat += 1
	_oni_pose("eat")
	GameState.event("eat", {"x": oni.x})
	main.toast("The oni eats and grows.")

## Hold the oni in a pose for a moment (drawn by Kit.oni from `anim`).
func _oni_pose(kind: String) -> void:
	oni.anim = kind
	oni.anim_t = 0.8
	# side-on, so what goes to its mouth is seen
	oni.anim_yaw = 0.0 if oni.face > 0 else 180.0

func _heal(n: float) -> void:
	oni.hp = minf(oni.maxhp, oni.hp + n)

## The building the oni could set alight from where it stands, if any.
func _burnable():
	for b in buildings:
		if b.kind != "bridge" and b.hp > 0 and not b.burning and _near_facade(oni, b, 14.0 * oni.scale, NEAR_BACK + 14.0 * oni.scale):
			return b
	return null

func _ignite() -> void:
	var b = _burnable()
	if b != null:
		b.burning = true
		GameState.event("fire", {"x": b.x + b.w / 2.0})
		_fire_alarm(b)
		_heat(10)
		GameState.record.burn += 1
		night_log.burn += 1
		_oni_pose("ignite")
		main.toast("The pipe's ember catches %s." % b.name)
		return
	main.toast("Nothing here will burn: go up to a building and press O.")

func _strike() -> void:
	if oni.cd > 0:
		return
	oni.cd = 0.55
	oni.swing = 0.25
	GameState.event("strike", {"x": oni.x, "who": "oni"})
	var reach: float = 36.0 * oni.scale
	var x0: float = oni.x if oni.face > 0 else oni.x - reach
	var x1: float = oni.x + reach if oni.face > 0 else oni.x
	var hit := false
	if oni.y < NEAR_BACK + 10.0 * oni.scale:
		for b in buildings:
			if b.kind != "bridge" and b.hp > 0 and b.x < x1 and b.x + b.w > x0:
				_hit_building(b, 22.0 * oni.dmg)
				hit = true
	var r = area.get("river")
	var br = bld("bridge")
	if r != null and br != null and br.hp > 0 and r.a < x1 and r.b > x0 and not hit:
		_hit_building(br, 22.0 * oni.dmg)
		hit = true
	for w in watch:
		if not w.down and w.x > x0 - 6 and w.x < x1 + 6 and absf(w.y - oni.y) < 16.0 * oni.scale:
			w.hp -= 40.0 * oni.dmg
			w.x += oni.face * 16.0
			_ashore(w)
			w.flash = 0.15
			hit = true
			_noise(w.x)
			if w.hp <= 0:
				_knock(w, true)
	if hit:
		shake = 0.18

## The oni's own special: a roar that throws back and stuns everyone near it,
## and is heard far down the street. Recharges. The monk's shikigami stay
## silent at night: yokai do not command yokai.
func _roar() -> void:
	if oni.get("roar_cd", 0.0) > 0.0:
		return
	oni.roar_cd = 10.0
	oni.roaring = 0.6
	GameState.event("roar", {"x": oni.x})
	_heat(6)
	GameState.record.roar += 1
	var reach: float = 90.0 * oni.scale
	for w in watch:
		if w.down:
			continue
		var d: float = absf(w.x - oni.x)
		if d < reach and absf(w.y - oni.y) < 40.0 * oni.scale:
			w.stun = 2.0
			w.x += signf(w.x - oni.x + 0.01) * 60.0
			w.x = clampf(w.x, 10.0, world_w - 10.0)
			_ashore(w)
	_noise(oni.x, 1.3)
	shake = 0.4
	main.toast("The oni roars. Shutters slam all down the street.")

## Whether people live here. An abandoned town has no watch and no rumour;
## yokai walk its streets at night instead.
func _peopled() -> bool:
	return station.get("people", true)

func _heat(n: float) -> void:
	if _peopled():
		GameState.add_heat(n)

## A crash or a blow is heard: every watchman within earshot leaves his round
## and comes running (a drunk oni is louder). Fire is not heard but seen: see
## _fire_alarm.
func _noise(x: float, loud: float = 1.0) -> void:
	var reach := HEAR * loud * (1.5 if oni.get("drunk", 0.0) > 0.0 else 1.0)
	var heard := 0
	for w in watch:
		if w.down or w.type in ["crowd", "yokai"] or absf(w.x - x) > reach:
			continue
		if w.type == "patrol":
			# heard, not seen: he goes to look, lantern up, and raises the
			# alarm only if the light finds the oni
			w.goal_x = x
			w.goal_t = 8.0
			w.heard = true
			heard += 1
		w.face = 1 if x > w.x else -1
	if heard > 0:
		GameState.event("heard", {"x": x})
		main.toast("The watch heard that, and comes to look.")

## A fire is seen from every street. The patrols make for it, and townspeople
## come running with buckets: enough of them, left alone, put it out; any who
## see the oni at it scream and run, and the alarm goes up.
func _fire_alarm(b: Dictionary) -> void:
	if not _peopled() or b.area != area_id:
		return
	for w in watch:
		if not w.down and w.type == "patrol":
			w.goal_x = b.x + b.w / 2.0
			w.goal_t = 40.0
	var crowd := watch.filter(func(w): return w.type == "crowd").size()
	for i in mini(CROWD_PER_FIRE, 12 - crowd):
		var left := randf() < 0.5
		watch.append({"x": randf_range(10.0, 40.0) if left else world_w - randf_range(10.0, 40.0), "y": randf_range(Y_MIN + 8.0, Y_MAX - 4.0),
			"type": "crowd", "hp": 15.0, "cd": 0.0, "face": 1 if left else -1, "down": false, "down_t": 0.0, "atk": 0.0, "lost": 0.0,
			"goal": b.id, "fleeing": false, "delay": randf_range(0.5, 4.0), "look": CROWD_LOOKS[i % CROWD_LOOKS.size()]})
		_settle(watch[-1], false)
	main.toast("Fire! People come running with buckets.")

func _update_crowd(w: Dictionary, dt: float) -> void:
	if w.delay > 0.0:
		w.delay -= dt
		return
	var close: float = 90.0 * maxf(1.0, oni.scale * 0.8)
	if not w.fleeing and not oni_hidden and absf(oni.x - w.x) < close and absf(oni.y - w.y) < 30.0:
		w.fleeing = true
		GameState.event("scream", {"x": w.x})
		_heat(4)
		night_log.spotted += 1
		spawn_t = minf(spawn_t, 1.0)
		_noise(w.x, 0.8)
		main.toast("Someone sees the oni and screams." if w.goal == "" else "Someone at the fire sees the oni and screams.")
	var b = bld(w.goal)
	if w.goal == "" and not w.fleeing:
		# about their business: strolling, now and then turning back
		if randf() < 0.3 * dt:
			w.face = -w.face
		_walk(w, 16.0 * dt)
		if w.x < 30.0 or w.x > world_w - 30.0:
			w.face = 1 if w.x < 30.0 else -1
		return
	if w.fleeing or b == null or not b.burning:
		# run home, out of the street
		var away := (-1.0 if w.x < oni.x else 1.0) if w.fleeing else (-1.0 if w.x < world_w / 2.0 else 1.0)
		w.face = away
		_move(w, away * (70.0 if w.fleeing else 40.0) * dt, 0.0, false, false)
		if w.x <= 12.0 or w.x >= world_w - 12.0:
			w.down = true
			w.down_t = 99.0
		return
	var cx: float = b.x + b.w / 2.0
	if absf(cx - w.x) > b.w / 2.0 - 4.0 or w.y > NEAR_BACK:
		w.face = 1 if cx > w.x else -1
		_move(w, w.face * 52.0 * dt, clampf(NEAR_BACK - 4.0 - w.y, -1.0, 1.0) * 30.0 * dt, false, false)
	else:
		b.doused = b.get("doused", 0.0) + dt
		if b.doused > 7.0:
			b.burning = false
			b.doused = 0.0
			main.toast("The townspeople put out the fire at %s." % b.name)

## In an unpeopled town the yokai of the place walk the streets at night, and
## come for the oni as they come for anyone.
func _update_yokai(w: Dictionary, dt: float) -> bool:
	var spec: Dictionary = Spirits.FOE[w.kind]
	w.flash = maxf(0.0, w.get("flash", 0.0) - dt)
	var ddx: float = oni.x - w.x
	var ddy: float = oni.y - w.y
	w.face = 1 if ddx > 0 else -1
	if absf(ddx) > spec.reach + 8.0 * (oni.scale - 1.0) or absf(ddy) > 8.0 * oni.scale:
		var d := Vector2(ddx, ddy).normalized()
		_move(w, d.x * spec.speed * dt, d.y * spec.speed * 0.7 * dt, true, false)
	elif w.cd <= 0.0:
		w.cd = spec.cd
		w.atk = 0.25
		_hurt_oni(spec.dmg * (0.5 if oni.get("ward", 0.0) > 0.0 else 1.0))
		return GameState.ended or mode != "night"
	return false

func _spawn_yokai() -> void:
	var nest: Dictionary = area.get("yokai", {})
	for kind in nest:
		for i in int(nest[kind]):
			var x := randf_range(40.0, world_w - 40.0)
			if absf(x - oni.x) < 140.0:
				x = clampf(x + 200.0, 40.0, world_w - 40.0)
			watch.append({"x": x, "y": randf_range(Y_MIN + 6.0, Y_MAX - 6.0), "type": "yokai", "kind": kind, "hp": Spirits.FOE[kind].hp,
				"cd": randf_range(0.5, 1.5), "face": -1, "down": false, "down_t": 0.0, "atk": 0.0, "lost": 0.0, "stun": 0.0,
				"flash": 0.0, "fade": 1.0, "seed": randf() * TAU})

func _oni_bind_wisp(w: Dictionary) -> void:
	if GameState.oni_bind(w.kind):
		GameState.event("bind", {"x": w.x, "who": "oni"})
		wisps.erase(w)
		main.toast("The oni takes the %s for its own. Its hold on you tightens." % Spirits.NAMES.get(w.kind, w.kind))
	else:
		main.toast("The oni already holds %d yokai." % GameState.SPIRIT_SLOTS)

## The oni comes down out of the dark from the trail, and the night goes on here.
func continue_night(o: Dictionary) -> void:
	mode = "night"
	wash = 0.8
	oni = o.duplicate()
	for k in ["dmg", "slow", "drunk", "swing", "cd", "flash", "roar_cd", "roaring", "ward"]:
		if not oni.has(k):
			oni[k] = 1.0 if k == "dmg" else 0.0
	oni.x = monk.x
	oni.y = monk.y
	oni.face = 1
	watch = []
	shots = []
	night_log = {"eat": 0, "drink": 0, "smash": 0, "burn": 0, "heat0": GameState.heat, "spotted": 0}
	plunder = 0
	spawn_t = 4.0
	_spawn_patrols()
	main.toast("The oni comes down out of the dark into %s." % Stations.ROUTE[id].name)
	if GameState.hunt and GameState.hunt_phase >= GameState.master_due and _peopled():
		# he was waiting for it here
		_master.call_deferred()

## The oni calls a shikigami of its own against the watch. The street sees it.
func _oni_summon() -> void:
	if GameState.oni_spirits.is_empty():
		main.toast("The monk's shikigami will not answer the oni." if not GameState.spirits.is_empty() else "The oni has bound no yokai of its own.")
		return
	var i := Spirits.next_ready(GameState.oni_spirits, next_oni_spirit)
	if i < 0:
		main.toast("The oni's shikigami are still gathering themselves.")
		return
	var sp: Dictionary = GameState.oni_spirits[i]
	sp.cd = Spirits.COOLDOWN
	next_oni_spirit = (i + 1) % GameState.oni_spirits.size()
	var live := watch.filter(func(w): return not w.down)
	var r := Spirits.call_special(sp.kind, oni, live, _spirit_hurt, world_w)
	GameState.event("shikigami", {"x": oni.x, "kind": sp.kind})
	if r.move != null:
		oni.x = r.move.x
		oni.y = clampf(r.move.y, Y_MIN, Y_MAX)
		oni.face = r.face
	oni.ward = maxf(oni.get("ward", 0.0), r.ward)
	if not r.summon.is_empty():
		summons.append(r.summon)
	if not r.fx.is_empty():
		spirit_fx.append(r.fx)
	_heat(2)
	main.toast(r.toast)

func _spirit_hurt(w: Dictionary, n: float, push: float) -> void:
	w.hp -= n
	w.x = clampf(w.x + push, 10.0, world_w - 10.0)
	_ashore(w)
	if w.hp <= 0 and not w.down:
		_knock(w, true)

func _hit_building(b: Dictionary, d: float) -> void:
	b.hp -= d
	GameState.event("crash", {"x": b.x + b.w / 2.0})
	_noise(b.x + b.w / 2.0)
	_heat(2)
	for i in 6:
		fx.append({"k": "chip", "x": b.x + randf() * b.w, "y": BACK - b.h * randf(), "vx": (randf() - 0.5) * 90.0, "vy": -60.0 - randf() * 60.0, "life": 0.9})
	if b.hp <= 0:
		_collapse(b, false)

func _collapse(b: Dictionary, by_fire: bool) -> void:
	if b.fallen:
		return
	b.hp = 0.0
	b.fallen = true
	GameState.fell(id, b.id)
	GameState.event("fall", {"x": b.x + b.w / 2.0, "fire": by_fire})
	b.burning = false
	b.pantry = 0
	b.barrels = 0
	b.erase("taken_at")   # a ruin is restocked when it is raised again
	var here: bool = b.area == area_id
	if by_fire:
		_heat(8)
		if here:
			main.toast("%s burns to the ground." % _cap(b.name))
	else:
		_heat(12)
		plunder += b.loot
		GameState.record.smash += 1
		night_log.smash += 1
		main.toast("%s collapses." % _cap(b.name))
	if here:
		shake = 0.3

func _knock(w: Dictionary, by_oni: bool) -> void:
	w.down = true
	w.down_t = 0.0
	if w.type == "yokai":
		wisps.append({"kind": w.kind, "x": w.x, "y": w.y, "life": 7.0})
		main.toast("The %s falls; its spirit lingers. I binds it to the oni." % Spirits.NAMES.get(w.kind, w.kind))
		return
	if by_oni:
		_heat(4)

## Blows from the watch, or hunger. Hunger never ends the night: a starving
## oni grows slow and weak (see the speed in _update_night), and the monk wakes
## starved.
func _hurt_oni(n: float, starving: bool = false) -> void:
	if starving:
		# the monk wakes starved; in the hunt there is no monk, and it can kill
		oni.hp = maxf(0.0 if GameState.hunt else 1.0, oni.hp - n)
		if oni.hp <= 0.0:
			main.hunt_over("Starved", "The towns have learned to hide their food. The oni's hunger eats it from within, and the exorcists bind it where it falls in %s." % Stations.ROUTE[id].name)
		return
	if GameState.invincible:
		return
	n *= GameState.diff().hurt * (0.5 if oni.get("ward", 0.0) > 0.0 else 1.0)
	oni.hp -= n
	GameState.event("hurt", {"x": oni.x, "who": "oni"})
	oni.flash = 0.15
	if oni.hp > 0:
		return
	if GameState.hunt:
		main.hunt_over("Bound", "The watch and the exorcists of %s bring the oni down at last. They pin it with talismans until the sutras are read, and bind it." % Stations.ROUTE[id].name)
	elif GameState.heat >= GameState.diff().capture:
		main.end_run("Bound", "The exorcists pin the oni with their talismans until dawn, and at dawn there is only a monk to bind. You are taken.")
	else:
		main.toast("The oni flees into the dark, beaten.")
		_dawn(true)

func _in_hide(ent: Dictionary, scale: float) -> bool:
	for h in area.get("hides", []):
		if ent.x > h.x and ent.x < h.x + h.w and ent.y < Y_MIN + 16.0 and scale <= h.max_scale:
			return true
	return false

func _is_hidden() -> bool:
	return _in_hide(oni, oni.scale)

func _spawn_patrols() -> void:
	_spawn_yokai()
	var day := GameState.hunt and GameState.daylight
	if day and _peopled():
		_spawn_folk()
	for i in int(station.get("patrols", 1)):
		var x := randf_range(40.0, world_w - 40.0)
		for tries in 6:
			if absf(x - oni.x) > 170.0:
				break
			x = randf_range(40.0, world_w - 40.0)
		watch.append({"x": x, "y": randf_range(Y_MIN + 10.0, Y_MAX - 6.0), "type": "patrol", "hp": 30.0, "cd": 1.0,
			"face": -1 if randf() < 0.5 else 1, "down": false, "down_t": 0.0, "atk": 0.0, "lost": 0.0, "lantern": not day})
		_settle(watch[-1], false)

## By day in the hunt the street is full of people about their business, until
## they see the oni (a crowd with nowhere to be; see _update_crowd).
func _spawn_folk() -> void:
	for i in DAY_FOLK:
		var x := randf_range(30.0, world_w - 30.0)
		if absf(x - oni.x) < 120.0:
			x = fmod(x + world_w / 2.0, world_w - 60.0) + 30.0
		watch.append({"x": x, "y": randf_range(Y_MIN + 8.0, Y_MAX - 4.0), "type": "crowd", "hp": 15.0, "cd": 0.0,
			"face": 1 if randf() < 0.5 else -1, "down": false, "down_t": 0.0, "atk": 0.0, "lost": 0.0,
			"goal": "", "fleeing": false, "delay": 0.0, "look": CROWD_LOOKS[i % CROWD_LOOKS.size()].duplicate()})
		watch[-1].look.erase("item")
		_settle(watch[-1], false)

func _spawn_hunter() -> void:
	var left := randf() < 0.5
	var x := 12.0 if left else world_w - 12.0
	# exorcists among them once rumour runs high, and more of them as the hunt wears on
	var ex := GameState.heat >= 50 and randf() < minf(0.8, 0.4 * GameState.hunt_hunters())
	watch.append({"x": x, "y": randf_range(Y_MIN + 6.0, Y_MAX - 6.0), "type": "exorcist" if ex else "watch", "hp": 40.0 if ex else 30.0,
		"cd": 1.0, "face": 1 if left else -1, "down": false, "down_t": 0.0, "atk": 0.0, "lost": 0.0})
	_settle(watch[-1], false)

## A patrol sees exactly what its lantern lights: the oni is seen if any part
## of its body is inside the pool. Hunters already on the alarm track the oni
## unless it hides (exorcists sense a hidden oni at close range).
func _sees(w: Dictionary) -> bool:
	var dx: float = oni.x - w.x
	if oni_hidden and not (w.type == "exorcist" and absf(dx) < 60.0):
		return false
	if w.type != "patrol":
		return true
	if not w.get("lantern", true):
		# by day: anything ahead of him within sight
		return dx * w.face > -20.0 and absf(dx) < DAY_SIGHT and absf(oni.y - w.y) < 50.0
	var cx: float = w.x + w.face * POOL_AHEAD
	var ex: float = (oni.x - cx) / (POOL_RX + 10.0 * oni.scale)
	var ey: float = (oni.y - w.y) / (POOL_RY + 6.0 * oni.scale)
	return ex * ex + ey * ey <= 1.0

func _update_night(dt: float) -> void:
	oni.t -= dt
	oni.cd -= dt
	oni.swing = maxf(0.0, oni.swing - dt)
	oni.flash = maxf(0.0, oni.flash - dt)
	oni.slow = maxf(0.0, oni.slow - dt)
	oni.drunk = maxf(0.0, oni.drunk - dt)
	oni.roar_cd = maxf(0.0, oni.get("roar_cd", 0.0) - dt)
	oni.roaring = maxf(0.0, oni.get("roaring", 0.0) - dt)
	oni.anim_t = maxf(0.0, oni.get("anim_t", 0.0) - dt)
	if oni.anim_t <= 0.0:
		oni.anim = ""
	_hurt_oni(oni.hunger * dt, true)
	GameState.shrink(oni, dt)
	oni.ward = maxf(0.0, oni.get("ward", 0.0) - dt)
	for sp in GameState.oni_spirits:
		sp.cd = maxf(0.0, sp.cd - dt)
	for s2 in summons:
		s2.life -= dt
	summons = summons.filter(func(s2): return s2.life > 0.0)
	for f2 in spirit_fx:
		f2.life -= dt
	spirit_fx = spirit_fx.filter(func(f2): return f2.life > 0.0)
	if mode != "night" or GameState.ended:
		return
	var dx := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var dy := int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	var sp: float = 70.0 * (1.0 + (oni.scale - 1.0) * 0.25) * Kit.oni_pace(oni.hp)
	if oni.slow > 0:
		sp *= 0.5
	# the deeper he wades, the slower
	sp *= 1.0 - 0.55 * _oni_sink() / (64.0 * oni.scale * WAIST)
	# drunk: it staggers, slows and is heard coming
	var drunk := minf(1.0, oni.drunk / 6.0)
	sp *= 1.0 - 0.3 * drunk
	var sway: float = sin(t * 2.3) * drunk * 0.6
	if drunk > 0.0 and (dx != 0 or dy != 0):
		for w in watch:
			if not w.down and w.type == "patrol" and absf(w.x - oni.x) < 80.0 * (1.0 + drunk):
				w.goal_x = oni.x
				w.goal_t = 6.0
				w.heard = true
	oni.moving = dx != 0 or dy != 0
	if dx != 0:
		oni.face = dx
	var hold: float = NAN
	if oni.swing > 0.0:
		hold = 0.0 if oni.face > 0 else 180.0
	elif oni.get("roaring", 0.0) > 0.0:
		hold = 90.0
	elif oni.get("anim", "") != "":
		hold = oni.anim_yaw
	Figure.turn(oni, dx, dy, dt, hold)
	_move(oni, (dx + sway) * sp * dt, dy * sp * 0.7 * dt, true, true)
	oni_hidden = _is_hidden()

	for wp in wisps:
		wp.life -= dt
	wisps = wisps.filter(func(wp): return wp.life > 0.0)
	var max_h := 0
	if GameState.heat >= 15 and _peopled():
		# more with rumour, and in the hunt more every day it goes on
		max_h = int(ceil((1 + floor(GameState.heat / 25.0)) * station.hunter_scale * GameState.diff().hunters * GameState.hunt_hunters()))
	spawn_t -= dt
	var hunting := 0
	for w in watch:
		if not w.down and w.type in ["watch", "exorcist"]:
			hunting += 1
	if hunting < max_h and spawn_t <= 0:
		spawn_t = 3.5
		_spawn_hunter()

	for w in watch:
		if w.down:
			w.down_t += dt
			continue
		if w.get("stun", 0.0) > 0.0:
			w.stun -= dt
			continue
		w.atk = maxf(0.0, w.atk - dt)
		w.cd -= dt
		if w.type == "crowd":
			_update_crowd(w, dt)
			continue
		if w.type == "yokai":
			if _update_yokai(w, dt):
				return
			continue
		if w.type == "patrol":
			_update_patrol(w, dt)
		else:
			if _update_hunter(w, dt):
				return
		for b in buildings:
			if b.burning and w.x > b.x - 6 and w.x < b.x + b.w + 6 and w.y < NEAR_BACK:
				w.hp -= 12.0 * dt
				if w.hp <= 0:
					_knock(w, false)
	watch = watch.filter(func(w): return not (w.down and w.down_t > 3.0))

	for sh in shots:
		sh.x += sh.vx * dt
		sh.life -= dt
		if absf(sh.x - oni.x) < 12.0 * oni.scale and absf(sh.y - oni.y) < 14.0 * oni.scale:
			sh.life = 0.0
			oni.slow = 1.5
			_hurt_oni(8.0)
			if GameState.ended or mode != "night":
				return
	shots = shots.filter(func(sh): return sh.life > 0)

	_update_fire(dt)
	if oni.t <= 0:
		if GameState.hunt:
			_turn_phase()
		else:
			_dawn(false)

func _update_patrol(w: Dictionary, dt: float) -> void:
	if w.has("goal_x"):
		# making for a fire or a noise, lantern ahead; given up after a while
		w.goal_t = w.get("goal_t", 8.0) - dt
		if absf(w.goal_x - w.x) > 30.0:
			w.face = 1 if w.goal_x > w.x else -1
			_walk(w, 40.0 * dt)
		elif w.goal_t <= 0.0 or (not w.get("heard", false) and buildings.filter(func(b): return b.burning).is_empty()):
			w.erase("goal_x")
			w.erase("heard")
	else:
		_walk(w, 24.0 * dt)
	if w.x < 30.0:
		w.face = 1
	elif w.x > world_w - 30.0:
		w.face = -1
	elif randf() < 0.08 * dt:
		w.face = -w.face
	if _sees(w):
		w.type = "watch"
		w.cd = 0.8
		# a watchman who lost the oni and finds it again does not raise the town twice
		if w.get("alarmed", false):
			return
		w.alarmed = true
		GameState.event("alarm", {"x": w.x})
		night_log.spotted += 1
		_heat(10)
		spawn_t = minf(spawn_t, 2.0)
		main.toast("A night watchman sees the oni and beats the alarm." if w.get("lantern", true) else "A guard sees the oni and raises the alarm.")

## Knocked toward the water, people fetch up on the bank; yokai may stand in it.
func _ashore(w: Dictionary) -> void:
	if w.type != "yokai":
		_settle(w, false)

## A townsperson walks `d` the way he faces, and turns back where he cannot
## go on (people do not wade: they keep to the banks and the bridge).
func _walk(w: Dictionary, d: float) -> void:
	var x0: float = w.x
	_move(w, w.face * d, 0.0, false, false)
	if absf(w.x - x0) < d * 0.5:
		w.face = -w.face

## Returns true if the night ended during this update.
func _update_hunter(w: Dictionary, dt: float) -> bool:
	if not _sees(w) and oni_hidden:
		w.lost += dt
		if w.lost > 3.0:
			w.type = "patrol"
			w.lost = 0.0
		return false
	w.lost = 0.0
	var dx: float = oni.x - w.x
	var s := 1.0 if dx >= 0 else -1.0
	w.face = s
	# walkers cannot wade; near the river they head for the bridge deck
	var ty: float = oni.y
	var r = area.get("river")
	if r != null and ((w.x < r.a) != (oni.x < r.a) or (w.x > r.b) != (oni.x > r.b)):
		ty = (BRIDGE_Y0 + BRIDGE_Y1) / 2.0
	var vy := clampf(ty - w.y, -1.0, 1.0)
	if w.type == "watch":
		if absf(dx) > 20.0 + 14.0 * oni.scale or absf(oni.y - w.y) > 10.0 + 6.0 * oni.scale:
			_move(w, s * 48.0 * dt, vy * 34.0 * dt, false, false)
		elif w.cd <= 0:
			w.cd = 1.1
			w.atk = 0.2
			_hurt_oni(6.0)
			if GameState.ended or mode != "night":
				return true
	else:
		if absf(dx) > 150:
			_move(w, s * 40.0 * dt, vy * 30.0 * dt, false, false)
		elif absf(dx) < 110:
			_move(w, -s * 40.0 * dt, vy * 30.0 * dt, false, false)
		else:
			_move(w, 0.0, vy * 30.0 * dt, false, false)
		if w.cd <= 0 and absf(dx) < 230:
			w.cd = 2.2
			w.atk = 0.3
			shots.append({"x": w.x, "y": w.y, "vx": s * 150.0, "life": 2.2})
	return false

func _update_fire(dt: float) -> void:
	for aid in areas_b:
		var list: Array = areas_b[aid]
		for b in list:
			if not b.burning:
				continue
			b.hp -= 6.0 * dt
			if aid == area_id and randf() < dt * 14.0:
				fx.append({"k": "fire", "x": b.x + randf() * b.w, "y": BACK - randf() * b.h * 0.9, "vx": (randf() - 0.5) * 14.0, "vy": -30.0 - randf() * 40.0, "life": 0.8 + randf() * 0.5})
			for n in list:
				if n == b or n.burning or n.hp <= 0 or n.kind == "bridge":
					continue
				var gap: float = maxf(n.x - (b.x + b.w), b.x - (n.x + n.w))
				if gap < station.fire_gap and randf() < station.fire_spread * dt:
					n.burning = true
					_fire_alarm(n)
					if aid == area_id:
						main.toast("Fire spreads to %s." % n.name)
			if b.hp <= 0:
				_collapse(b, true)


func _update_fx(dt: float) -> void:
	for f in fx:
		f.x += f.vx * dt
		f.y += f.vy * dt
		f.life -= dt
		if f.k == "chip":
			f.vy += 260.0 * dt
	fx = fx.filter(func(f): return f.life > 0)
	wash = maxf(0.0, wash - dt)
	glyph_t = maxf(0.0, glyph_t - dt)
	shake = maxf(0.0, shake - dt)


# ---------- sound ----------
## Where on screen something at street x is (for the sound's left and right).
func screen_x(x: float) -> float:
	return x - cam_x

## The music: the town by day; the oni's night (also by day in the hunt), more
## of it as the town turns out after the oni.
func music() -> Dictionary:
	if mode == "day":
		return {"tune": "town" if _peopled() else "trail", "tension": 0.0}
	var hunting := watch.any(func(w): return not w.down and w.type in ["watch", "exorcist"])
	var searching := watch.any(func(w): return not w.down and w.get("heard", false))
	var t := GameState.heat / 100.0 * 0.5 + (0.7 if hunting else (0.35 if searching else 0.0))
	if GameState.hunt:
		t = maxf(t, 0.34)
		if GameState.master_due - GameState.hunt_phase <= 1:
			t += 0.3
	return {"tune": "night", "tension": clampf(t, 0.0, 1.0)}

## The street's ambience: a little wind, the river as near as it is, insects
## in the dark, any fire in this street as near as it is.
func ambience() -> Dictionary:
	var mid := cam_x + W / 2.0
	var dark := mode == "night" and not GameState.daylight
	var out := {"wind": 0.15, "insects": 0.5 if dark else 0.0}
	var r = area.get("river")
	if r != null:
		var d := maxf(0.0, maxf(r.a - mid, mid - r.b))
		out.water = clampf(1.0 - d / 400.0, 0.0, 1.0)
	var fire := 0.0
	for b in buildings:
		if b.burning:
			fire = maxf(fire, 1.0 - absf(b.x + b.w / 2.0 - mid) / 400.0)
	out.fire = clampf(fire, 0.0, 1.0)
	return out


# ---------- drawing ----------
func _draw() -> void:
	var night := mode == "night"
	# in the hunt the oni walks by day too
	var dark := night and not GameState.daylight
	var focus: float = oni.x if night else monk.x
	var cam := clampf(focus - W / 2.0, 0.0, maxf(0.0, world_w - W))
	cam_x = cam
	if shake > 0:
		cam += (randf() - 0.5) * 6.0
	var dk := Kit.sky(self, cam, dark, GameState.hours, GameState.moon_lit(dark), area.get("backdrop", "hills"), BACK, t)
	Kit.ground(self, BACK, dk, area.get("ground", "earth"))
	var r = area.get("river")
	if r != null:
		_draw_river(r, cam, dk)
	var f = area.get("forage")
	if f != null:
		var x: float = f.a + 10
		while x < f.b:
			if x - cam > -20 and x - cam < W + 20:
				Kit.bush(self, x - cam, BACK, dk)
			x += 38
	for p in area.get("props", []):
		_draw_prop(p, p.x - cam, dk, dark)

	for b in buildings:
		var s: float = b.x - cam
		if b.kind != "bridge" and s + b.w > -30 and s < W + 30:
			Kit.building(self, b, s, BACK, dark, GameState.gate_passed)
	for h in area.get("hides", []):
		Kit.hide_spot(self, h, h.x - cam, BACK, dk)
	var wl = area.get("well")
	if wl != null:
		Kit.well(self, wl.x - cam, BACK + 4, dk)
	var ex: Dictionary = area.get("exits", {})
	if ex.has("left") and cam < 4:
		draw_string(font, Vector2(4, BACK + 14), "◀ " + _cap(station.areas[ex.left].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(PAPER, 0.7))
	if ex.has("right") and cam > world_w - W - 4:
		draw_string(font, Vector2(0, BACK + 14), _cap(station.areas[ex.right].name) + " ▶", HORIZONTAL_ALIGNMENT_RIGHT, W - 4, 9, Color(PAPER, 0.7))
	# people, sorted by depth
	var ents: Array = []
	if not night:
		for n in area.get("npcs", []):
			var b = bld(n.building)
			if b != null and b.hp > 0:
				ents.append({"k": "npc", "y": Y_MIN + 3.0, "n": n, "x": b.x + n.dx})
		for bl in area.get("blockers", []):
			if _blocker_up(bl):
				ents.append({"k": "blocker", "y": Y_MIN + 20.0, "bl": bl})
		if not _by_boat():
			ents.append({"k": "monk", "y": monk.y})
	else:
		for w in watch:
			ents.append({"k": "watch", "y": w.y, "w": w})
		for s2 in summons:
			ents.append({"k": "summon", "y": s2.y + 0.5, "s": s2})
		ents.append({"k": "oni", "y": oni.y})
	# what stands in the river takes its place in depth, so water painted over a wader never covers it
	if r != null:
		if bld("bridge") != null:
			ents.append({"k": "bridge", "y": BRIDGE_Y0 - 0.5})
		elif area.has("ferry"):
			ents.append({"k": "boat", "y": BOAT_Y})
	ents.sort_custom(func(a, b): return a.y < b.y)
	for e in ents:
		match e.k:
			"npc":
				Kit.person(self, e.x - cam, e.y, e.n.face, e.n)
			"blocker":
				Kit.person(self, e.bl.x + e.bl.w / 2.0 - cam, e.y, 1 if monk.x > e.bl.x else -1, e.bl.look)
				var sway := sin(t * 1.7) * 2.0
				draw_string(font, Vector2(e.bl.x + e.bl.w / 2.0 - cam - 6 + sway, e.y - 40), "~", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(PAPER, 0.7))
			"monk":
				var ms := 0.0
				if not crossing.is_empty():
					ms = _sink(monk.x, 44.0 * (KNEE if crossing.kind == "ford" else WAIST))
				acts.draw(self, monk.x - cam, monk.y, t, 0.0, ms)
				_wade_water(monk.x, monk.y, ms, 12.0, cam, dk)
			"boat":
				var bx := _boat_x() - cam
				var deck := Kit.boat_deck(BOAT_Y, t)
				if _by_boat():
					Kit.boat(self, bx, BOAT_Y, FERRY_W, dk, t, crossing.kind == "ferry", crossing.d)
					if crossing.kind == "pole":
						Kit.person(self, bx + FERRY_W * _aboard(false), deck, crossing.d, {"robe": "#6d5a78", "skin": "#d9b595", "hat": "#b39a56"})
					acts.draw(self, bx + FERRY_W * _aboard(true), deck, t)
				else:
					# by night it is tied up, unmanned
					Kit.boat(self, bx, BOAT_Y, FERRY_W, dk, t, mode == "day")
			"bridge":
				_draw_bridge(r, cam, dk)
			"watch":
				var w: Dictionary = e.w
				match w.type:
					"crowd":
						if w.delay <= 0.0:
							Figure.person(self, Vector2(w.x - cam, w.y), w.face, 40.0, w.look, "side", "down" if w.down else "walk", t + w.x * 0.01)
					"yokai":
						var yf := {"y": w.y, "face": w.face, "flash": w.flash, "fade": clampf(1.0 - w.down_t / 1.2, 0.0, 1.0) if w.down else 1.0,
							"seed": w.seed, "atk": w.atk}
						Kit.creature(self, w.kind, yf, w.x - cam, t)
					_:
						Kit.watchman(self, w, w.x - cam, font)
			"summon":
				Spirits.draw_summon(self, e.s, e.s.x - cam, e.s.y, t)
			"oni":
				var os := _oni_sink()
				Kit.oni(self, oni.x - cam, oni.y, oni, t, oni_hidden, os)
				_wade_water(oni.x, oni.y, os, 18.0 * oni.scale, cam, dk)
				if oni.get("roaring", 0.0) > 0.0:
					var rr: float = (0.6 - oni.roaring) / 0.6 * 90.0 * oni.scale
					draw_arc(Vector2(oni.x - cam, oni.y - 30.0 * oni.scale), rr, 0, TAU, 32, Color(1.0, 0.85, 0.6, oni.roaring), 2.0)
	if night:
		for wp in wisps:
			Kit.wisp(self, wp.x - cam, wp.y, wp.kind, t)
		for f2 in spirit_fx:
			Spirits.draw_fx(self, f2, f2.x - cam, f2.y)
		for sh in shots:
			draw_rect(Rect2(sh.x - cam - 3, sh.y - 28, 6, 10), Color("#f4efe2"))
			draw_rect(Rect2(sh.x - cam - 1, sh.y - 26, 2, 6), Color("#b0372c"))
	for p in fx:
		if p.k == "chip":
			draw_rect(Rect2(p.x - cam, p.y, 2, 2), Color("#5a3f2a"))
	if night:
		if dark:
			draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.04, 0.12, 0.28))
		for w in watch:
			if not w.down and w.type == "patrol" and w.get("lantern", true):
				Kit.light_pool(self, w.x - cam + w.face * POOL_AHEAD, w.y, POOL_RX, POOL_RY)
		for b in buildings:
			if b.burning:
				draw_circle(Vector2(b.x + b.w / 2.0 - cam, BACK - b.h / 2.0), b.w * 0.7, Color(1.0, 0.55, 0.24, 0.12))
			elif b.kind != "bridge":
				Kit.food_marks(self, b, b.x - cam, BACK, t)
	for p in fx:
		if p.k == "fire":
			var a := clampf(p.life, 0.0, 1.0)
			draw_circle(Vector2(p.x - cam, p.y), 2.0 + a * 3.0, Color(1.0, (120.0 + a * 100.0) / 255.0, 0.24, a * 0.8))
	if not night:
		_draw_place_marks(cam)
	_draw_prompt(cam, night)
	_draw_hud(night)
	if wash > 0:
		draw_rect(Rect2(0, 0, W, H), Color(0.04, 0.04, 0.08, clampf(wash, 0.0, 1.0) * 0.9))
	if glyph_t > 0 and night:
		var col := Color(0.69, 0.22, 0.17, clampf(glyph_t, 0.0, 1.0))
		if glyph_font.has_char(0x9B3C):
			draw_string(glyph_font, Vector2(0, H / 2.0 + 42), "鬼", HORIZONTAL_ALIGNMENT_CENTER, W, 120, col)
		else:
			draw_string(font, Vector2(0, H / 2.0 + 8), "The oni wakes", HORIZONTAL_ALIGNMENT_CENTER, W, 28, col)

## What Act would do right now, shown as icons above whoever you are playing.
func _draw_prompt(cam: float, night: bool) -> void:
	if GameState.paused or not crossing.is_empty():
		return
	var icons: Array = []
	var pos := Vector2.ZERO
	if night:
		var n = _night_option()
		if n != null:
			icons.append(n.icon)
		if _burnable() != null:
			icons.append("fire")
		if icons.is_empty():
			return
		pos = Vector2(oni.x - cam, oni.y - 70.0 * oni.scale)
	else:
		icons = _icons_of(_day_options())
		pos = Vector2(monk.x - cam, monk.y - 52.0)
	for i in icons.size():
		Kit.icon(self, icons[i], pos + Vector2((i - (icons.size() - 1) / 2.0) * 18.0, 0), true)

## By day, small icons mark what each place offers the monk; the place he can
## use right now is highlighted.
func _draw_place_marks(cam: float) -> void:
	var here := _icons_of(_day_options())
	for b in buildings:
		if b.kind == "bridge":
			continue
		var icons: Array = []
		if b.hp > 0:
			match b.kind:
				"stall": icons.append("food")
				"shrine": icons.append("prayer")
				"den": icons.append("dice")
				"gate":
					if not GameState.gate_passed: icons.append("gate")
			if station.has("alms") and station.alms.building == b.id and not icons.has("food"):
				icons.append("food")
		if b.hp < 100:
			icons.append("repair")
		var near := _near_facade(monk, b, 12.0, NEAR_BACK)
		_marks(icons, Vector2(b.x + b.w / 2.0 - cam, BACK - b.h - 10.0), near, here)
	for bl in area.get("blockers", []):
		if _blocker_up(bl):
			_marks(["bow", "staff"], Vector2(bl.x + bl.w / 2.0 - cam, Y_MIN - 30.0), _near_blocker() == bl, here)
	var r = area.get("river")
	if r != null and crossing.is_empty():
		var ri: Array = ["water"]
		if area.has("ferry") and bld("bridge") == null:
			ri.append_array(["boat", "ford"])
		var br = bld("bridge")
		if br != null and br.hp <= 0:
			ri.append("ford")
		elif br != null and br.hp < 100:
			ri.append("repair")
		_marks(ri, Vector2((r.a + r.b) / 2.0 - cam, BACK - 14.0), monk.x > r.a - 24 and monk.x < r.b + 24, here)
	var wl = area.get("well")
	if wl != null:
		_marks(["water"], Vector2(wl.x - cam, BACK - 58.0), absf(monk.x - wl.x) < 22.0 and monk.y < NEAR_BACK, here)
	var f = area.get("forage")
	if f != null:
		_marks(["forage"], Vector2((f.a + f.b) / 2.0 - cam, BACK - 22.0), monk.x > f.a and monk.x < f.b, here)
	for d in area.get("doors", []):
		var dyp := BACK - 30.0 if d.dir == "up" else H - 10.0
		Kit.icon(self, d.dir, Vector2(d.x + d.w / 2.0 - cam, dyp), false, 0.8)

func _marks(icons: Array, p: Vector2, near: bool, here: Array) -> void:
	if p.x < -20 or p.x > W + 20:
		return
	for i in icons.size():
		var ic: String = icons[i]
		Kit.icon(self, ic, p + Vector2((i - (icons.size() - 1) / 2.0) * 15.0, 0), near and here.has(ic), 0.95 if near else 0.6)

func _draw_prop(p: Dictionary, sx: float, dk: float, night: bool) -> void:
	if p.kind != "castle" and (sx + p.get("w", 0.0) < -100 or sx > W + 100):
		return
	match p.kind:
		"cedar":
			Kit.cedar(self, sx, BACK + 2, p.get("h", 60.0), dk)
		"rock":
			Kit.rock(self, sx, BACK + 4, p.get("s", 10.0), dk)
		"stone_lantern":
			Kit.stone_lantern(self, sx, BACK + 2, dk, night)
		"torii":
			Kit.torii(self, sx, BACK, p.get("h", 50.0), dk, 10.0)
		"castle":
			# far off on the skyline: it moves slowly, so it shows from anywhere in town
			var cam_x: float = p.x - sx
			draw_set_transform(Vector2(W / 2.0 + (p.x - cam_x - W / 2.0) * 0.3, BACK - 26.0), 0.0, Vector2(0.6, 0.6))
			Kit.castle(self, 0.0, 0.0, dk + 0.1)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"paddies":
			Kit.paddies(self, sx, p.get("w", 200.0), BACK, dk)

func _draw_river(_r: Dictionary, cam: float, dk: float) -> void:
	_water(BACK, H, cam, dk)

## Paint the river's surface between depths y0 and y1, ripples and all. The
## river itself is one such band; a wader is drawn sunk below his waterline,
## and the band from there down painted back over him.
func _water(y0: float, y1: float, cam: float, dk: float) -> void:
	var r = area.get("river")
	var top := maxf(y0, BACK)
	var bot := minf(y1, H)
	if r == null or r.b - cam < 0 or r.a - cam > W or bot <= top:
		return
	draw_rect(Rect2(r.a - cam, top, r.b - r.a, bot - top), Kit.shade(WATER, dk))
	for i in 7:
		var yy := BACK + 8 + i * 9
		if yy < top or yy > bot:
			continue
		var x: float = r.a + fmod(t * 20.0 + i * 23.0, 60.0) - 60.0
		while x < r.b:
			var a := maxf(x, r.a)
			var b := minf(x + 14.0, r.b)
			if b > a:
				draw_line(Vector2(a - cam, yy), Vector2(b - cam, yy), Color(0.86, 0.9, 0.94, 0.25), 1.0)
			x += 60.0

## The water over someone sunk `sink` below the surface at (x, y), and the
## ripple where it meets him.
func _wade_water(x: float, y: float, sink: float, half_w: float, cam: float, dk: float) -> void:
	if sink <= 0.5:
		return
	_water(y, y + sink + 4.0, cam, dk)
	var r = area.river
	var a := maxf(x - half_w, r.a)
	var b := minf(x + half_w, r.b)
	if b > a:
		draw_line(Vector2(a - cam, y), Vector2(b - cam, y), Color(0.86, 0.9, 0.94, 0.55), 1.0)

func _draw_bridge(r: Dictionary, cam: float, dk: float) -> void:
	var ra: float = r.a - cam
	var rb: float = r.b - cam
	if rb < 0 or ra > W:
		return
	var br = bld("bridge")
	var c := Kit.shade(Color("#6b4a2b"), dk)
	if br.hp <= 0:
		draw_rect(Rect2(ra - 4, BRIDGE_Y0 - 4, 16, BRIDGE_Y1 - BRIDGE_Y0 + 8), c)
		draw_rect(Rect2(rb - 12, BRIDGE_Y0 - 4, 16, BRIDGE_Y1 - BRIDGE_Y0 + 8), c)
		return
	draw_rect(Rect2(ra - 4, BRIDGE_Y0 - 4, rb - ra + 8, BRIDGE_Y1 - BRIDGE_Y0 + 8), c)
	var x := ra
	while x < rb:
		draw_line(Vector2(x, BRIDGE_Y0 - 4), Vector2(x, BRIDGE_Y1 + 4), Kit.shade(Color("#7d5a38"), dk), 1.0)
		x += 6.0
	draw_rect(Rect2(ra - 4, BRIDGE_Y0 - 12, rb - ra + 8, 2), c)
	for i in 7:
		draw_rect(Rect2(ra + i * (rb - ra) / 6.0 - 1, BRIDGE_Y0 - 12, 2, 8), c)
	if br.hp < 100:
		draw_line(Vector2(ra + 30, BRIDGE_Y0), Vector2(ra + 40, BRIDGE_Y1), Kit.shade(Color("#1a1310"), dk * 0.5), 1.0)

func _bar(x: float, y: float, w: float, v: float, col: Color, label: String) -> void:
	draw_rect(Rect2(x, y, w, 6), Color(0.06, 0.07, 0.14, 0.7))
	draw_rect(Rect2(x, y, w * clampf(v, 0.0, 1.0), 6), col)
	draw_string(font, Vector2(x, y - 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, PAPER)

func _draw_hud(night: bool) -> void:
	if night:
		var when := "Night %d" % GameState.night_no
		if GameState.hunt:
			when = _cap(Kit.hunt_when())
		draw_string(font, Vector2(8, 16), "%s, %s%s" % [when, Kit.phase_left(oni.t).to_lower(), "  (hidden)" if oni_hidden else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PAPER)
		_bar(8, 30, 90, oni.hp / oni.maxhp, Color("#b0372c"), "Body, size %.1f" % oni.scale)
	else:
		var hh := int(GameState.hours)
		var mm := int((GameState.hours - hh) * 4) * 15
		draw_string(font, Vector2(8, 16), "%s, %d:%02d" % [_cap(area.name), hh, mm], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PAPER)
		_bar(8, 30, 90, GameState.stamina / 100.0, Color("#c9a13a"), "Stamina")
	_bar(106, 30, 70, GameState.curse / 100.0, Color("#8a4fb0"), "Curse")
	_bar(184, 30, 70, GameState.heat / 100.0, Color("#e07a3a"), "Heat")
	var right := "%d %s, %d %s left" % [GameState.coins, "coin" if GameState.coins == 1 else "coins", GameState.nights_left, "night" if GameState.nights_left == 1 else "nights"]
	if GameState.hunt:
		right = _cap(Stations.ROUTE[id].name)
		draw_string(font, Vector2(0, H - 14), Kit.master_line(), HORIZONTAL_ALIGNMENT_RIGHT, W - 6, 9, Color(PAPER, 0.85))
	draw_string(font, Vector2(0, 16), right, HORIZONTAL_ALIGNMENT_RIGHT, W - 8, 12, PAPER)
	if not night and GameState.prayer > 0:
		draw_string(font, Vector2(0, 32), "Prayer %d" % int(GameState.prayer), HORIZONTAL_ALIGNMENT_RIGHT, W - 8, 11, PAPER)
	if GameState.invincible:
		draw_string(font, Vector2(8, 52), "TEST: invincible (F10)", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#ffd65a"))
	if night:
		var rc: float = oni.get("roar_cd", 0.0)
		Kit.icon(self, "roar", Vector2(300, 26), rc <= 0.0, 1.0 if rc <= 0.0 else 0.45)
		draw_string(font, Vector2(284, 44), "L roar", HORIZONTAL_ALIGNMENT_CENTER, 32, 8, Color(PAPER, 0.8))
		if rc > 0.0:
			draw_arc(Vector2(300, 26), 8.5, -PI / 2, -PI / 2 + TAU * (1.0 - rc / 10.0), 20, Color("#ffd65a"), 1.5)
	draw_string(font, Vector2(0, H - 3), "v" + GameState.VERSION, HORIZONTAL_ALIGNMENT_RIGHT, W - 3, 8, Color(PAPER, 0.4))
