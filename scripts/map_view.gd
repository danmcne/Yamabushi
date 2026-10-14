extends Node2D
## The pilgrimage seen from above. Each dawn the monk stands at the station
## he slept in and chooses: stay another day, or walk on toward the next.
## Where the road forks, setting out asks which road; turning back undoes it.

const Stations := preload("res://scripts/stations.gd")
const Kit := preload("res://scripts/kit.gd")
const W := 480.0
const H := 270.0
const PAPER := Color("#ece3cf")

var main: Node
var at := ""
var target := ""
var prog := 0.0
var choice := 0
var road_chosen := false   # at a fork, set once the monk has picked a road this dawn
var t := 0.0
var font: Font


func setup(main_node: Node) -> void:
	main = main_node
	at = GameState.station_id
	_pick(0)

func _pick(i: int) -> void:
	var nxt: Array = Stations.ROUTE[at].next
	if nxt.is_empty():
		target = ""
		return
	choice = clampi(i, 0, nxt.size() - 1)
	target = nxt[choice]

func _ready() -> void:
	font = ThemeDB.fallback_font
	if GameState.nights_left <= 0 and not Stations.ROUTE[at].next.has("peak"):
		main.new_moon_passed()

## A station on the far side of a river can only be left once across it.
func stranded() -> bool:
	return Stations.ROUTE[at].get("must_cross", false) and not GameState.flags.get("crossed:" + at, false)

func road_name() -> String:
	var tid := trail_id()
	return Stations.TRAILS[tid].name if tid != "" else ""


func trail_id() -> String:
	if target == "":
		return ""
	return Stations.ROUTE[at].get("trails", {}).get(target, "")

func prompt() -> String:
	if target == "":
		return ""
	var there: String = Stations.ROUTE[target].name
	var here: String = Stations.ROUTE[at].name
	if prog >= 0.98:
		return "Act: climb to the rite" if target == "peak" else "Act: enter %s" % there
	if trail_id() != "" and prog > 0.02:
		return "Walking toward %s. A camp lies on the trail." % there
	if prog <= 0.02:
		if GameState.nights_left <= 0:
			return "The new moon is tonight. Walk on to the peak."
		if stranded():
			return "You are still on the near bank. Act: another day in %s, and cross it" % here
		if GameState.stamina < 30.0:
			return "Weak and hungry: you will crawl. Right: set out anyway.  Act: stay in %s" % here
		if Stations.ROUTE[at].next.size() > 1:
			if road_chosen:
				return "By %s. Right: set out.  Left: reconsider.  Act: stay" % road_name()
			return "The road forks. Right: choose a road and set out.  Act: stay"
		return "Act: another day in %s.  Right: set out (%d stamina)" % [here, int(GameState.TRAVEL_STAMINA)]
	return "Walking toward %s" % there

func act_label() -> String:
	if prog >= 0.98:
		return "Enter"
	return "Stay" if prog <= 0.02 else "Act"

func legend() -> Dictionary:
	return {"I": act_label()}

func pipe_label() -> String:
	return "Smoke"


func _process(delta: float) -> void:
	t += delta
	if not GameState.paused and not GameState.ended and target != "":
		var dir := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
		if dir > 0 and prog <= 0.0 and stranded():
			dir = 0
		# at a fork, setting out asks which road; walking back to the station undoes it
		if dir > 0 and prog <= 0.0 and Stations.ROUTE[at].next.size() > 1 and not road_chosen:
			_ask_road()
			return
		if prog <= 0.0 and dir < 0:
			road_chosen = false
		var before := prog
		prog = clampf(prog + dir * delta * 0.35, 0.0, 1.0)
		if trail_id() != "" and before < 0.5 and prog >= 0.5:
			GameState.depart()
			main.enter_trail(trail_id(), target)
			return
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.paused or GameState.ended or event.is_echo() or GameState.input_blocked():
		return
	if not event.is_action_pressed("act"):
		return
	if prog >= 0.98:
		_arrive()
	elif prog <= 0.02:
		_stay()


func _ask_road() -> void:
	var opts: Array = []
	var nxt: Array = Stations.ROUTE[at].next
	for i in nxt.size():
		var to: String = nxt[i]
		var tid: String = Stations.ROUTE[at].trails.get(to, "")
		var road: String = Stations.TRAILS[tid].name if tid != "" else "the road"
		var sub := "Toward %s." % Stations.ROUTE[to].name
		if to == "castle_town" and at == "post_town":
			sub += " Skips the river crossing and saves a night, but it is the hardest trail."
		elif to == "ruined_town":
			sub += " Through a post town abandoned years ago: no watch, no rumour, and nothing to eat. Yokai walk it at night."
		opts.append({"label": _label_of(road), "sub": sub, "run": _take_road.bind(i)})
	opts.append({"label": "Not yet", "sub": "Stay at the crossroads to decide"})
	main.open_modal("Which road?", "The road forks outside %s." % Stations.ROUTE[at].name, opts)

func _take_road(i: int) -> void:
	_pick(i)
	road_chosen = true

func _label_of(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)

func _stay() -> void:
	if GameState.nights_left <= 0:
		main.toast("No nights remain. Only the peak.")
		return
	GameState.new_day()
	main.enter_station(at, main.wake)

func _arrive() -> void:
	GameState.depart()
	main.arrive(target)


# ---------- drawing ----------
func _ctrl(a: Vector2, b: Vector2) -> Vector2:
	var mid := (a + b) / 2.0
	var n := (b - a).orthogonal().normalized()
	return mid + n * 28.0

func _bez(a: Vector2, c: Vector2, b: Vector2, p: float) -> Vector2:
	return a * (1 - p) * (1 - p) + c * 2.0 * (1 - p) * p + b * p * p

func music() -> Dictionary:
	return {"tune": "menu", "tension": 0.0}

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("#6f7a5a"))
	# terrain: deterministic mountain clusters
	for i in 34:
		var x := fmod(i * 97.3, W)
		var y := 20.0 + fmod(i * 53.7, H - 40.0)
		var s := 10.0 + fmod(i * 7.1, 14.0)
		if y < 150 - x * 0.25:
			s *= 1.3
		draw_colored_polygon(PackedVector2Array([Vector2(x - s, y + s * 0.6), Vector2(x + s, y + s * 0.6), Vector2(x, y - s * 0.8)]), Color("#4d5b52"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - s * 0.3, y - s * 0.3), Vector2(x + s * 0.3, y - s * 0.3), Vector2(x, y - s * 0.8)]), Color("#d9d6c8"))
	# a river crossing the lowlands
	var river := PackedVector2Array()
	for i in 25:
		var p := i / 24.0
		river.append(Vector2(p * W, 250 - p * 60 + sin(p * 9.0) * 10))
	draw_polyline(river, Color("#3f6b86"), 4.0)
	# roads
	for from in Stations.ROUTE:
		for to in Stations.ROUTE[from].next:
			var a: Vector2 = Stations.ROUTE[from].pos
			var b: Vector2 = Stations.ROUTE[to].pos
			var c := _ctrl(a, b)
			var road := PackedVector2Array()
			for i in 31:
				road.append(_bez(a, c, b, i / 30.0))
			var chosen: bool = from == at and to == target
			draw_polyline(road, Color("#e3c76a") if chosen else Color("#8a7453"), 3.0 if not chosen else 4.0)
			for i in range(0, 31, 2):
				draw_circle(road[i], 0.9, Color("#c8b58f"))
	# camps on the trails
	for from in Stations.ROUTE:
		for to in Stations.ROUTE[from].get("trails", {}):
			var a2: Vector2 = Stations.ROUTE[from].pos
			var b2: Vector2 = Stations.ROUTE[to].pos
			var cp := _bez(a2, _ctrl(a2, b2), b2, 0.5)
			draw_circle(cp, 5, Color(0.2, 0.15, 0.12, 0.8))
			draw_colored_polygon(PackedVector2Array([cp + Vector2(-3, 2), cp + Vector2(3, 2), cp + Vector2(0, -5)]), Color("#f08a3c"))
	# stations
	for sid in Stations.ROUTE:
		var p: Vector2 = Stations.ROUTE[sid].pos
		if sid == "peak":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-26, 16), p + Vector2(26, 16), p + Vector2(0, -22)]), Color("#3f4a47"))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-9, -8), p + Vector2(9, -8), p + Vector2(0, -22)]), Color("#ece8dc"))
			draw_rect(Rect2(p.x - 5, p.y - 30, 10, 2), Color("#c23b2c"))
			draw_rect(Rect2(p.x - 4, p.y - 30, 2, 8), Color("#c23b2c"))
			draw_rect(Rect2(p.x + 2, p.y - 30, 2, 8), Color("#c23b2c"))
		else:
			if sid == "castle_town":
				draw_set_transform(p + Vector2(0, -6), 0.0, Vector2(0.2, 0.2))
				Kit.castle(self, 0.0, 0.0, 0.0)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var n := 4 if sid == "village" else 7
			for i in n:
				var q := p + Vector2((i % 4) * 9 - 13, (i / 4) * 8 - 6)
				draw_rect(Rect2(q.x, q.y, 7, 6), Color("#8a5f3f"))
				draw_colored_polygon(PackedVector2Array([q + Vector2(-1, 0), q + Vector2(8, 0), q + Vector2(3.5, -4)]), Color("#5a4a36"))
			var ruined := 0
			for hp in GameState.load_station_hp(sid).values():
				if hp <= 0:
					ruined += 1
			if ruined > 0:
				for k in 3:
					draw_circle(p + Vector2(8 + k * 3, -14 - k * 5 - fmod(t * 6.0, 5.0)), 2.5 + k, Color(0.25, 0.25, 0.28, 0.5))
		draw_string(font, p + Vector2(-60, 28), _label(sid), HORIZONTAL_ALIGNMENT_CENTER, 120, 11, PAPER)
	# the monk
	var pos: Vector2 = Stations.ROUTE[at].pos
	if target != "":
		var a: Vector2 = Stations.ROUTE[at].pos
		var b: Vector2 = Stations.ROUTE[target].pos
		pos = _bez(a, _ctrl(a, b), b, prog)
	draw_circle(pos, 5.0, Color("#e9e3d3"))
	draw_circle(pos, 1.8, Color("#1b1b22"))
	# header and prompt
	draw_rect(Rect2(0, 0, W, 24), Color(0.08, 0.09, 0.17, 0.75))
	Kit.moon(self, Vector2(14, 12), 6.0, GameState.moon_lit(), Color(0.08, 0.09, 0.17))
	if GameState.nights_left <= 0:
		draw_arc(Vector2(14, 12), 6.0, 0, TAU, 16, Color(PAPER, 0.4), 1.0)
	draw_string(font, Vector2(26, 16), "Nights to the new moon: %d" % GameState.nights_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PAPER)
	draw_string(font, Vector2(0, H - 26), "v" + GameState.VERSION, HORIZONTAL_ALIGNMENT_RIGHT, W - 3, 8, Color(PAPER, 0.4))
	draw_string(font, Vector2(0, 16), "Curse %d   Heat %d   Stamina %d" % [int(GameState.curse), int(GameState.heat), int(GameState.stamina)], HORIZONTAL_ALIGNMENT_RIGHT, W - 8, 12, PAPER)
	draw_rect(Rect2(0, H - 22, W, 22), Color(0.08, 0.09, 0.17, 0.75))
	draw_string(font, Vector2(0, H - 7), prompt(), HORIZONTAL_ALIGNMENT_CENTER, W, 12, PAPER)

func _label(sid: String) -> String:
	var s: String = Stations.ROUTE[sid].name
	return s.substr(0, 1).to_upper() + s.substr(1)
