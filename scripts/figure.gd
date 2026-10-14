extends RefCounted
## The character sheets. Every figure in the game is drawn from here.
##
## The yamabushi and the oni stand on a low-resolution rig that can be seen
## from any side: a head; a torso; arms with a shoulder and an elbow; legs
## jointed only at the hip (a knee where the hakama ends, but no bend).
## Points on the rig are given in the figure's own frame and projected for the
## way it faces (see `px`), and its parts are drawn far to near, so one rig
## gives the profile, the three-quarter views front and back, and the front
## and back views.
##
## The same parts are drawn over Shikigami's skeleton in the final standoffs
## (duel_figures.gd), from the joints that skeleton is posed in.
##
## Townspeople, the watch and the exorcists keep a simpler rig: facing you at
## rest, in profile when they walk.
##
## Drawing is in units of a rig `BASE` tall, feet at the origin, scaled to the
## height asked for.

const BASE := 44.0
const INK := Color("#1b1b22")
const SKIN := Color("#dcb08b")
const JACKET := Color("#e9e3d3")
const HAKAMA := Color("#cfc6ae")
const KYAHAN := Color("#3a3a46")
const STRAW := Color("#b89a5a")
const TEKKO := Color("#2f2f38")
const BONTEN := Color("#d97a2b")
const WOOD := Color("#6b4a2b")
const BRASS := Color("#c9a13a")
const GOURD := Color("#c98f3a")
const GOURD_SAKE := Color("#a4552a")
const SHELL := Color("#efe2cc")
const SHELL_LIP := Color("#d9884a")
const ONI := Color("#b3342a")
const ONI_GOURD := Vector3(-1.2, 2.6, -7.6)   # where the oni's sake gourd hangs, from its hip
const TIGER := Color("#d9a441")
const IRON := Color("#26222a")
const HORN := Color("#e8dfc9")
const GOLD := Color("#d9a441")

## The shakujo's length, butt to crown.
const STAFF := 46.0
## The monk's limbs: upper arm, forearm, leg (hip to ankle), knee (where the hakama ends).
const M_UPPER := 6.8
const M_FORE := 6.4
const M_LEG := 16.0
const M_KNEE := 11.5
## The oni's.
const O_UPPER := 7.2
const O_FORE := 6.8
const O_LEG := 14.2


# ---------- primitives ----------
static func dir(angle: float) -> Vector2:
	var r := deg_to_rad(angle)
	return Vector2(sin(r), cos(r))

## A tapered rod from `p0` to `p1`, rounded at both ends unless `caps` is false
## (then flat at `p1`, where a foot will cover it).
static func limb(ci: CanvasItem, p0: Vector2, p1: Vector2, w0: float, w1: float, col: Color, caps := true) -> void:
	var d := (p1 - p0)
	if d.length() < 0.01:
		ci.draw_circle(p0, w0 / 2.0, col)
		return
	d = d.normalized()
	var n := Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PackedVector2Array([p0 + n * w0 / 2.0, p1 + n * w1 / 2.0, p1 - n * w1 / 2.0, p0 - n * w0 / 2.0]), col)
	ci.draw_circle(p0, w0 / 2.0, col)
	if caps:
		ci.draw_circle(p1, w1 / 2.0, col)

static func poly(ci: CanvasItem, pts: Array, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), col)

static func hull(ci: CanvasItem, pts: Array, col: Color) -> void:
	var h := Geometry2D.convex_hull(PackedVector2Array(pts))
	if h.size() >= 3:
		ci.draw_colored_polygon(h, col)

## Every colour a figure is painted in passes through here: at `alpha`, and
## darkened by `gloom` (an oni pressed into a hiding place is drawn in its
## shadow; set it around the draw and back to 0).
static var gloom := 0.0
static func a(c: Color, alpha: float) -> Color:
	var d := c.darkened(gloom) if gloom > 0.0 else c
	return Color(d.r, d.g, d.b, c.a * alpha)

static func shadow(ci: CanvasItem, w: float) -> void:
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-w, 0), Vector2(0, -2), Vector2(w, 0), Vector2(0, 2)]), Color(0, 0, 0, 0.22))


# ---------- turning ----------
## Points on the yamabushi and the oni are Vector3(a, h, b) in the figure's
## frame: a forward, h downward (negative is up, as on the screen), b to the
## figure's left. `yaw` is the way it faces in degrees: 0 to the right, 90
## toward the viewer, 180 to the left, -90 away. Seen at that yaw, a point
## lands at (a cos yaw + b sin yaw, h), and the larger a sin yaw - b cos yaw,
## the nearer the viewer it is.
static func px(p: Vector3, yaw: float) -> Vector2:
	var r := deg_to_rad(yaw)
	return Vector2(p.x * cos(r) + p.z * sin(r), p.y)

static func near(p: Vector3, yaw: float) -> float:
	var r := deg_to_rad(yaw)
	return p.x * sin(r) - p.z * cos(r)

## A point of the figure's frame placed about `origin` on the screen, with the
## figure's up along `up` (for a figure leaning or lying, as Shikigami poses them).
static func at(origin: Vector2, up: Vector2, p: Vector3, yaw: float) -> Vector2:
	var f := Vector2(-up.y, up.x)
	var q := px(p, yaw)
	return origin + f * q.x - up * q.y

## Draw [depth, Callable] pairs far to near.
static func paint(layers: Array) -> void:
	layers.sort_custom(func(x, y): return x[0] < y[0])
	for e in layers:
		e[1].call()

## The yaw a figure turns toward as it moves by (dx, dy), dy toward the
## viewer. Standing after walking along the street, it settles three-quarters
## toward the viewer on the side it last faced; after walking toward or away
## from the viewer it stays so. `hold` turns it to a given yaw (a pose that
## faces somewhere). Turns are eased, so it passes through the views between,
## and turning about goes by way of the front.
static func turn(ent: Dictionary, dx: float, dy: float, dt: float, hold := NAN) -> void:
	var yaw: float = ent.get("yaw", 0.0 if ent.get("face", 1) > 0 else 180.0)
	var goal := yaw
	if not is_nan(hold):
		goal = hold
	elif dx != 0.0 or dy != 0.0:
		goal = rad_to_deg(atan2(dy, dx))
		ent.along = absf(dy) < absf(dx)
	elif ent.get("along", true):
		goal = 30.0 if cos(deg_to_rad(yaw)) >= 0.0 else 150.0
	var diff := wrapf(goal - yaw, -180.0, 180.0)
	if absf(diff) > 170.0:
		diff = absf(diff) * (1.0 if cos(deg_to_rad(yaw)) >= 0.0 else -1.0)
	ent.yaw = wrapf(yaw + diff * minf(1.0, dt * 12.0), -180.0, 180.0)

## The elbow and hand of an arm from shoulder `s` reaching for `to`, the elbow
## bending toward `pole`.
static func reach(s: Vector3, to: Vector3, l1: float, l2: float, pole: Vector3) -> Array:
	var d := to - s
	var dist := clampf(d.length(), absf(l1 - l2) + 0.05, l1 + l2 - 0.05)
	var u := d.normalized()
	var along := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var off := sqrt(maxf(0.0, l1 * l1 - along * along))
	var p := (pole - u * pole.dot(u)).normalized()
	return [s + u * along + p * off, s + u * dist]

## The elbow and hand of an arm swung `th` degrees from hanging (90 forward,
## 180 straight up), the forearm bent a further `bend` forward, held `out` to
## the side (+ to the figure's left).
static func swing(s: Vector3, th: float, bend: float, out: float, l1: float, l2: float) -> Array:
	var r1 := deg_to_rad(th)
	var r2 := deg_to_rad(th + bend)
	var e := s + Vector3(sin(r1), cos(r1), out).normalized() * l1
	return [e, e + Vector3(sin(r2), cos(r2), out * 0.5).normalized() * l2]

## An arm from a pose: ["swing", th, bend, out] or ["reach", spot, offset, pole].
static func arm(s: Vector3, spec: Array, spots: Dictionary, l1: float, l2: float) -> Array:
	if spec[0] == "reach":
		return reach(s, spots[spec[1]] + spec[2], l1, l2, spec[3])
	return swing(s, spec[1], spec[2], spec[3], l1, l2)

## The part of a head's surface (radius `r` about `c` on the screen) within
## `spread` degrees of the direction `toward` (in the figure's frame) that
## faces the viewer: hair on the upper back of the head, seen from any side.
## Ball and half-space are both convex, so the cap is the hull of its points.
static func cap(c: Vector2, up: Vector2, r: float, toward: Vector3, spread: float, yaw: float) -> PackedVector2Array:
	var pts: Array = []
	var k := cos(deg_to_rad(spread))
	var tw := toward.normalized()
	var ry := deg_to_rad(yaw)
	var across := Vector3(cos(ry), 0, sin(ry))
	for i in 120:
		var y := 1.0 - 2.0 * (i + 0.5) / 120.0
		var rr := sqrt(1.0 - y * y)
		var th := i * 2.399963
		var q := Vector3(cos(th) * rr, y, sin(th) * rr)
		if q.dot(tw) >= k and near(q, yaw) >= 0.0:
			pts.append(at(c, up, q * r, yaw))
	for i in 48:
		# the head's outline, and the cap's own edge, where they bound it
		var ang := TAU * i / 48.0
		var o := across * cos(ang) + Vector3(0, sin(ang), 0)
		if o.dot(tw) >= k:
			pts.append(at(c, up, o * r, yaw))
		var e1 := tw.cross(Vector3(0, 0, 1)).normalized()
		var e2 := tw.cross(e1).normalized()
		var rim := tw * k + (e1 * cos(ang) + e2 * sin(ang)) * sqrt(1.0 - k * k)
		if near(rim, yaw) >= 0.0:
			pts.append(at(c, up, rim * r, yaw))
	if pts.size() < 3:
		return PackedVector2Array()
	return Geometry2D.convex_hull(PackedVector2Array(pts))

static func _cap_fill(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3:
		ci.draw_colored_polygon(pts, col)

## Points round a body at one height: an ellipse `da` deep and `db` wide, `h`
## below (or, negative, above) the centre it is added to. A torso drawn on rings
## stays inside the garment ringed round it, from any side.
static func ring(da: float, h: float, db: float, n: int = 12) -> Array:
	var out: Array = []
	for i in n:
		var ang := TAU * i / n
		out.append(Vector3(cos(ang) * da, h, sin(ang) * db))
	return out

static func _avg_near(points: Array, yaw: float) -> float:
	var s := 0.0
	for q in points:
		s += near(q, yaw)
	return s / maxf(1.0, points.size())


# ---------- the yamabushi ----------
## His pose for `kind` at time `t`, `phase` 0..1 through an action. Arms are
## ["swing", angle, elbow bend, out] or ["reach", spot, offset, elbow pole];
## the left hand takes what he holds, the right the staff ("staff": its angle,
## 180 upright, or -1 laid on the ground before him).
static func pose(kind: String, t: float, phase: float) -> Dictionary:
	var p := {"lean": 0.0, "bow": 0.0, "kneel": false, "ll": 0.0, "rl": 0.0, "held": "", "staff": 180.0,
		"left": ["swing", 4.0, 22.0, 0.15], "right": ["swing", 8.0, 52.0, -0.1]}
	match kind:
		"walk":
			var s := sin(t * 9.0)
			p.ll = 24.0 * s
			p.rl = -24.0 * s
			# the leg swinging forward lifts its foot (seen most from the front and behind)
			p.llift = 2.6 * maxf(0.0, cos(t * 9.0))
			p.rlift = 2.6 * maxf(0.0, -cos(t * 9.0))
			p.left = ["swing", 6.0 - 18.0 * s, 24.0, 0.15]
			p.right = ["swing", 10.0 + 5.0 * s, 50.0, -0.1]
			p.staff = 180.0 - 4.0 * s
			p.lean = 3.0
		"strike":
			# both hands on the staff: up overhead, then forward and down
			var k := clampf(phase, 0.0, 1.0)
			var th := lerpf(170.0, 72.0, k)
			p.right = ["swing", th, 10.0, -0.05]
			p.left = ["swing", th - 6.0, 18.0, 0.05]
			p.staff = th + 16.0
			p.ll = 14.0
			p.rl = -10.0
			p.lean = lerpf(-4.0, 10.0, k)
		"drink":
			p.left = ["reach", "mouth", Vector3(4.0, -1.2, 0.0), Vector3(-0.3, 0.4, 1.0)]
			p.held = "gourd"
			p.bow = -10.0
		"smoke":
			p.left = ["reach", "mouth", Vector3(1.2, 1.2, 0.3), Vector3(0.0, 1.0, 0.7)]
			p.held = "pipe"
		"conch":
			p.left = ["reach", "mouth", Vector3(1.6, 0.6, 0.0), Vector3(-0.3, 0.3, 1.0)]
			p.held = "conch"
			p.bow = -6.0
		"toss":
			# an ofuda flung from beside the ear, the arm following through
			var k := clampf(phase, 0.0, 1.0)
			p.left = ["swing", lerpf(165.0, 92.0, k), lerpf(40.0, 4.0, k), 0.1]
			p.held = "ofuda" if k < 0.95 else ""
			p.lean = lerpf(-4.0, 8.0, k)
			p.ll = 12.0
			p.rl = -8.0
		"pray", "taki":
			# gassho: palms together before the chest
			p.kneel = kind == "pray"
			p.left = ["reach", "chest", Vector3(0, 0, 0.3), Vector3(-0.4, 1.0, 1.0)]
			p.right = ["reach", "chest", Vector3(0, 0, -0.3), Vector3(-0.4, 1.0, -1.0)]
			p.bow = 10.0 if kind == "pray" else 14.0
			p.staff = -1.0
		"goma":
			p.kneel = true
			p.left = ["swing", 80.0 + 10.0 * sin(t * 4.0), 12.0, 0.1]
			p.right = ["swing", 40.0, 50.0, -0.1]
			p.held = "stick"
			p.staff = -1.0
		"down":
			p.kneel = true
			p.lean = 70.0
			p.staff = -1.0
	return p


## The monk at `pos` (his feet), `height` pixels tall, facing `yaw`.
static func monk(ci: CanvasItem, pos: Vector2, yaw: float, height: float, kind: String, t: float, phase: float,
		curse: float, gourd: String, alpha: float = 1.0, grounded: bool = true) -> void:
	var k := height / BASE
	ci.draw_set_transform(pos, 0.0, Vector2(k, k))
	if grounded:
		shadow(ci, 8.0)
	var p := pose(kind, t, phase)
	var kneel: bool = p.kneel
	var hip := Vector3(0, -8.5 if kneel else -17.0, 0)
	var lr := deg_to_rad(p.lean)
	var up := Vector3(sin(lr), -cos(lr), 0)
	var fw := Vector3(cos(lr), sin(lr), 0)
	var sh := hip + up * 15.0
	var head := sh + Vector3(0.6 + sin(deg_to_rad(p.bow)) * 2.0, -5.5, 0)
	var spots := {"mouth": head + Vector3(3.8, 1.9, 0), "chest": sh + fw * 5.4 - up * 4.5}
	var L: Array = []
	# legs: kyahan shins and sandals, under the hakama
	var knees: Array = []
	var ankles: Array = []
	for side in [1.0, -1.0]:
		var hj := hip + Vector3(0, 0, 2.6 * side)
		var knee: Vector3
		var ankle: Vector3
		if kneel:
			knee = hj + Vector3(7.0, 6.6, 0)
			ankle = hj + Vector3(-3.4, 7.5, 0)
		else:
			var sw := deg_to_rad(p.ll if side > 0.0 else p.rl)
			var d := Vector3(sin(sw), cos(sw), 0)
			var lift := Vector3(0, -(p.get("llift", 0.0) if side > 0.0 else p.get("rlift", 0.0)), 0)
			knee = hj + d * M_KNEE + lift * 0.6
			ankle = hj + d * (M_LEG - 1.0) + lift
		knees.append(knee)
		ankles.append(ankle)
		var toe := -1.0 if kneel else 1.0
		var foot: Array = []
		for c in [Vector3(-1.4 * toe, 1.0, 1.1), Vector3(-1.4 * toe, 1.0, -1.1), Vector3(2.8 * toe, 1.0, 1.1),
				Vector3(2.8 * toe, 1.0, -1.1), Vector3(0, -0.2, 1.0), Vector3(0, -0.2, -1.0)]:
			foot.append(px(ankle + c, yaw))
		var far := near(hj, yaw) < -0.5
		L.append([near(ankle, yaw) - 20.0, _shin.bind(ci, px(knee, yaw), px(ankle, yaw), foot, far, alpha)])
	# the hakama: one baggy mass from the waist to the knees (in seiza, to the ankles)
	var hk: Array = []
	for i in 8:
		var ang := TAU * i / 8.0
		hk.append(px(hip + Vector3(cos(ang) * 4.6, -1.0, sin(ang) * 6.0), yaw))
		for kn in knees:
			hk.append(px(kn + Vector3(cos(ang) * 3.4, 0.0, sin(ang) * 3.6), yaw))
		if kneel:
			for an in ankles:
				hk.append(px(an + Vector3(cos(ang) * 2.0, -0.6, sin(ang) * 3.0), yaw))
	L.append([0.0, _fill.bind(ci, hk, a(HAKAMA, alpha))])
	# the suzukake jacket, covering the shoulders
	var jk: Array = []
	# tucked into the hakama: narrower at the waist than the hakama's own
	for q in ring(3.6, -1.0, 5.0):
		jk.append(px(hip + q, yaw))
	for q in ring(3.4, 0.4, 5.9):
		jk.append(px(sh + q, yaw))
	for sa in [-1.0, 1.0]:
		jk.append(px(sh + up * 1.4 + Vector3(0, 0, 4.0 * sa), yaw))
	L.append([-0.5, _fill.bind(ci, jk, a(JACKET, alpha))])
	# the yuigesa down the chest, its six bonten in two columns
	for sb in [-1.0, 1.0]:
		var top := sh + fw * 2.4 + up * 0.4 + Vector3(0, 0, 3.6 * sb)
		var bot := sh.lerp(hip, 0.75) + fw * 4.4 + Vector3(0, 0, 2.3 * sb)
		L.append([_avg_near([top, bot], yaw) + 0.1, _band.bind(ci, px(top, yaw), px(bot, yaw), alpha)])
		for i in 3:
			var bp := sh.lerp(hip, 0.2 + 0.25 * i) + fw * 4.6 + Vector3(0, 0, 2.3 * sb)
			L.append([near(bp, yaw) + 0.2, _bonten.bind(ci, px(bp, yaw), alpha)])
	# at the belt: the gourd behind, the conch and the kiseru in front
	if p.held != "gourd":
		var g := hip + Vector3(-4.8, 3.0, -3.2)
		L.append([near(g, yaw) + 0.3, _gourd.bind(ci, px(g, yaw), gourd, alpha)])
	if p.held != "conch":
		var c := hip + Vector3(4.6, 2.2, 3.0)
		L.append([near(c, yaw) + 0.3, _conch.bind(ci, px(c, yaw), 0.75, alpha, cos(deg_to_rad(yaw)) < 0.0)])
	if p.held != "pipe":
		var p0 := hip + Vector3(4.4, -2.4, -1.6)
		var p1 := hip + Vector3(4.8, -6.0, -2.2)
		L.append([near(p1, yaw) + 0.3, _kiseru.bind(ci, px(p0, yaw), px(p1, yaw), alpha)])
	# head
	L.append([near(head, yaw) + 0.5, monk_head.bind(ci, px(head, yaw), yaw, curse, alpha)])
	# arms, and what they hold
	var left := arm(sh + Vector3(0, 0.6, 4.4), p.left, spots, M_UPPER, M_FORE)
	var right := arm(sh + Vector3(0, 0.6, -4.4), p.right, spots, M_UPPER, M_FORE)
	var ld := _avg_near([sh + Vector3(0, 0.6, 4.4), left[0], left[1]], yaw) + 0.3
	var rd := _avg_near([sh + Vector3(0, 0.6, -4.4), right[0], right[1]], yaw) + 0.3
	L.append([ld, sleeve.bind(ci, px(sh + Vector3(0, 0.6, 4.4), yaw), px(left[0], yaw), px(left[1], yaw), alpha, 1.0 if ld > 0.0 else 0.82)])
	L.append([rd, sleeve.bind(ci, px(sh + Vector3(0, 0.6, -4.4), yaw), px(right[0], yaw), px(right[1], yaw), alpha, 1.0 if rd > 0.0 else 0.82)])
	var lh: Vector3 = left[1]
	var mouth: Vector3 = spots.mouth
	var at_mouth := maxf(ld, near(head, yaw) + 1.0) + 0.1
	match p.held:
		"gourd":
			var tg := tipped(mouth, yaw, 1.0)
			L.append([at_mouth, _gourd.bind(ci, tg[0], gourd, alpha, 1.0, tg[1])])
		"pipe":
			var bowl := mouth + Vector3(8.4, 1.2, 0)
			L.append([at_mouth, _pipe.bind(ci, px(mouth, yaw), px(bowl, yaw), t, alpha)])
		"conch":
			var fwd := cos(deg_to_rad(yaw))
			L.append([at_mouth, _conch_call.bind(ci, px(mouth + Vector3(2.0, -0.6, 0), yaw), 1.0 if fwd >= 0.0 else -1.0, t, phase, alpha)])
		"stick":
			L.append([ld + 0.05, _stick.bind(ci, px(lh, yaw), px(lh + Vector3(5.0, 1.0, 0), yaw), alpha)])
		"ofuda":
			L.append([ld + 0.05, _ofuda_in_hand.bind(ci, px(lh, yaw), alpha)])
	# the ringed staff in his right hand, or laid before him
	if p.staff >= 0.0:
		var sd := Vector3(sin(deg_to_rad(p.staff)), cos(deg_to_rad(p.staff)), 0)
		var grip: Vector3 = right[1]
		# held upright, its butt rests on the ground; swung, it is held near the butt
		var below := 13.0
		if sd.y < -0.85:
			below = -grip.y / -sd.y
		L.append([rd - 0.05, staff.bind(ci, px(grip - sd * below, yaw), px(grip + sd * (STAFF - below), yaw), alpha)])
	else:
		var s0 := Vector3(-2.0, -0.8, -5.0)
		var s1 := Vector3(26.0, -0.8, -5.0)
		L.append([_avg_near([s0, s1], yaw) - 21.0, staff.bind(ci, px(s0, yaw), px(s1, yaw), alpha)])
	match kind:
		"goma":
			var fire := Vector3(19, 0, 0)
			L.append([near(fire, yaw), _goma_fire.bind(ci, px(fire, yaw), t, alpha)])
		"taki":
			L.append([100.0, _falls_on.bind(ci, px(head, yaw), t, alpha)])
	paint(L)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# the monk's parts, each drawn at points already on the screen
static func _fill(ci: CanvasItem, pts: Array, col: Color) -> void:
	hull(ci, pts, col)

static func _shin(ci: CanvasItem, knee: Vector2, ankle: Vector2, foot: Array, far: bool, alpha: float) -> void:
	limb(ci, knee, ankle, 3.0, 2.5, a(KYAHAN.lightened(0.12) if far else KYAHAN, alpha))
	hull(ci, foot, a(STRAW.darkened(0.15) if far else STRAW, alpha))

static func _band(ci: CanvasItem, p0: Vector2, p1: Vector2, alpha: float) -> void:
	limb(ci, p0, p1, 1.5, 1.5, a(INK, alpha * 0.85))

static func _bonten(ci: CanvasItem, c: Vector2, alpha: float) -> void:
	ci.draw_circle(c, 1.75, a(BONTEN, alpha))
	ci.draw_circle(c + Vector2(-0.4, -0.4), 0.7, a(BONTEN.lightened(0.35), alpha))

## A gourd: its body at c, its neck toward `neck` (upright at the belt; on its
## side, neck at the lips, when someone drinks from it), `k` times the monk's.
static func _gourd(ci: CanvasItem, c: Vector2, gourd: String, alpha: float, k: float = 1.0, neck := Vector2(0, -1)) -> void:
	var gc := GOURD_SAKE if gourd == "sake" else GOURD
	var n := neck.normalized()
	ci.draw_circle(c, 2.4 * k, a(gc, alpha))
	ci.draw_circle(c + n * 3.2 * k, 1.6 * k, a(gc, alpha))
	limb(ci, c + n * 1.6 * k, c + n * 1.9 * k, 0.5 * k, 0.5 * k, a(gc.darkened(0.45), alpha))
	ci.draw_circle(c + n * 4.6 * k, 0.6 * k, a(gc.darkened(0.3), alpha))

## Drinking from the gourd as from a bottle: on its side, the bottom tipped up,
## the neck at the lips. Returns [body, neck direction] for _gourd.
static func tipped(mouth: Vector3, yaw: float, k: float) -> Array:
	var body := mouth + Vector3(4.4, -1.6, 0.0) * k
	return [px(body, yaw), px(mouth, yaw) - px(body, yaw)]

static func _kiseru(ci: CanvasItem, p0: Vector2, p1: Vector2, alpha: float) -> void:
	limb(ci, p0, p1, 0.8, 0.8, a(INK, alpha))
	ci.draw_circle(p1, 0.9, a(BRASS, alpha))

static func _pipe(ci: CanvasItem, mouth: Vector2, bowl: Vector2, t: float, alpha: float) -> void:
	limb(ci, mouth, bowl, 0.8, 0.8, a(INK, alpha))
	ci.draw_circle(bowl, 1.1, a(BRASS, alpha))
	for i in 3:
		var age := fmod(t * 0.9 + i * 0.33, 1.0)
		ci.draw_circle(bowl + Vector2(age * 3.0 + sin(t * 3.0 + i) * 1.2, -1.0 - age * 12.0), 0.8 + age * 2.4, Color(0.92, 0.92, 0.9, (1.0 - age) * 0.55 * alpha))

static func _conch_call(ci: CanvasItem, c: Vector2, fwd: float, t: float, phase: float, alpha: float) -> void:
	_conch(ci, c, 1.2, alpha, fwd < 0.0)
	if phase > 0.0:
		for i in 3:
			var r := 6.0 + fmod(t * 30.0 + i * 7.0, 20.0)
			var mid := 0.0 if fwd > 0.0 else PI
			ci.draw_arc(c + Vector2(3.0 * fwd, 0), r, mid - 0.6, mid + 0.6, 10, Color(1.0, 0.95, 0.8, (1.0 - r / 26.0) * alpha), 1.0)

static func _ofuda_in_hand(ci: CanvasItem, hand: Vector2, alpha: float) -> void:
	ci.draw_rect(Rect2(hand + Vector2(-1.0, -4.6), Vector2(2.2, 4.4)), a(Color("#f4efe2"), alpha))
	ci.draw_line(hand + Vector2(0.1, -4.0), hand + Vector2(0.1, -1.0), a(Color("#b0372c"), alpha), 0.6)

static func _stick(ci: CanvasItem, p0: Vector2, p1: Vector2, alpha: float) -> void:
	limb(ci, p0, p1, 1.0, 1.0, a(Color("#c9b48a"), alpha))

static func _falls_on(ci: CanvasItem, head: Vector2, t: float, alpha: float) -> void:
	for i in 5:
		var x0 := head.x - 5.0 + i * 2.5
		ci.draw_line(Vector2(x0, -90.0), Vector2(x0 + sin(t * 7.0 + i) * 0.6, head.y - 3.0), Color(0.85, 0.92, 1.0, 0.55 * alpha), 1.6)
	for i in 6:
		var age := fmod(t * 1.6 + i / 6.0, 1.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		ci.draw_circle(head + Vector2(side * (3.0 + age * 7.0), -2.0 + age * 10.0), 0.9, Color(0.9, 0.95, 1.0, (1.0 - age) * 0.8 * alpha))

## His head seen at `yaw`: short hair at the back, the black tokin on the
## brow, eyes on the side that faces you, horns through the hair once the
## curse is past half. `up` tilts it (Shikigami's poses lean and fall).
static func monk_head(ci: CanvasItem, c: Vector2, yaw: float, curse: float, alpha: float, up := Vector2.UP) -> void:
	var L: Array = []
	L.append([0.0, _disc.bind(ci, c, 4.6, a(SKIN, alpha))])
	L.append([0.01, _cap_fill.bind(ci, cap(c, up, 4.75, Vector3(-0.6, -0.8, 0), 72.0, yaw), a(INK, alpha))])
	for sb in [-1.0, 1.0]:
		var eye := Vector3(3.9, -0.4, 1.5 * sb)
		if near(eye, yaw) > 0.6:
			L.append([near(eye, yaw), _dot.bind(ci, at(c, up, eye, yaw), 1.1, a(INK, alpha))])
	if curse > 50:
		var hh := 1.5 + (curse - 50.0) / 50.0 * 3.5
		for sb in [-1.0, 1.0]:
			var base := Vector3(0.4 + 0.5 * sb, -4.2, 1.6 * sb)
			L.append([near(base, yaw) + 0.02, _horn.bind(ci, at(c, up, base, yaw), at(c, up, base + Vector3(0.3, -hh, 0), yaw), 1.0, a(Color("#d8d0bf"), alpha))])
	# the tokin: a small black cap bound on the brow
	var cap := Vector3(1.8, -4.4, 0)
	var pts: Array = []
	for q in [Vector3(-1.6, 0.8, 1.5), Vector3(-1.6, 0.8, -1.5), Vector3(1.8, 0.8, 1.5), Vector3(1.8, 0.8, -1.5),
			Vector3(0.6, -1.8, 0.7), Vector3(0.6, -1.8, -0.7), Vector3(-0.6, -1.2, 0)]:
		pts.append(at(c, up, cap + q, yaw))
	L.append([near(cap, yaw) + 0.03, _fill.bind(ci, pts, a(INK, alpha))])
	paint(L)

static func _disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, col)

static func _dot(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_rect(Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), col)

static func _horn(ci: CanvasItem, base: Vector2, tip: Vector2, w: float, col: Color) -> void:
	var d := (tip - base).normalized()
	var n := Vector2(-d.y, d.x)
	poly(ci, [base + n * w, tip, base - n * w], col)

## The shakujo from its butt to its crown: the brass loop at the top lies
## along the shaft, with a ring hanging either side of it, however the staff
## is held.
static func staff(ci: CanvasItem, butt: Vector2, top: Vector2, alpha: float) -> void:
	var d := top - butt
	if d.length() < 0.01:
		d = Vector2.UP
	d = d.normalized()
	var n := Vector2(-d.y, d.x)
	limb(ci, butt, top, 1.4, 1.4, a(WOOD, alpha))
	var loop := PackedVector2Array()
	var centre := top + d * 2.4
	for i in 17:
		var ang := TAU * i / 16.0
		loop.append(centre + d * cos(ang) * 3.0 + n * sin(ang) * 2.2)
	ci.draw_polyline(loop, a(BRASS, alpha), 1.0)
	for s in [-1.0, 1.0]:
		ci.draw_arc(centre + n * 2.4 * s - d * 0.6, 1.0, 0, TAU, 8, a(BRASS, alpha), 0.8)

## An arm through its joints: a wide suzukake sleeve to the elbow, the dark
## tekko over the forearm, a hand. `shade` darkens the far arm.
static func sleeve(ci: CanvasItem, shoulder: Vector2, elbow: Vector2, hand: Vector2, alpha: float, shade: float) -> void:
	limb(ci, shoulder, elbow, 5.0, 4.4, a(JACKET.darkened(1.0 - shade), alpha))
	limb(ci, elbow, hand, 2.6, 2.4, a(TEKKO.darkened((1.0 - shade) * 0.5), alpha))
	ci.draw_circle(hand, 1.6, a(SKIN.darkened(1.0 - shade), alpha))

## The horagai: a conch with a flared orange lip, at `c`, scaled by `s`;
## `flip` turns it to face left.
static func _conch(ci: CanvasItem, c: Vector2, s: float, alpha: float, flip := false) -> void:
	var dx := -1.0 if flip else 1.0
	poly(ci, [c + Vector2(-3.2 * dx, -1.2) * s, c + Vector2(2.6 * dx, -2.4) * s, c + Vector2(3.4 * dx, 0.8) * s, c + Vector2(-1.6 * dx, 2.2) * s], a(SHELL, alpha))
	ci.draw_circle(c + Vector2(2.6 * dx, -0.6) * s, 1.4 * s, a(SHELL_LIP, alpha))
	ci.draw_line(c + Vector2(-2.0 * dx, -0.6) * s, c + Vector2(1.6 * dx, 0.2) * s, a(SHELL_LIP.darkened(0.3), alpha), 0.6)

## The goma fire: a stacked square of cut wood with flames and rising sparks.
static func _goma_fire(ci: CanvasItem, c: Vector2, t: float, alpha: float) -> void:
	ci.draw_circle(c + Vector2(0, -5), 9.0, Color(1.0, 0.55, 0.2, 0.18 * alpha))
	for i in 3:
		ci.draw_rect(Rect2(c + Vector2(-6.0, -1.4 - i * 1.6), Vector2(12.0, 1.4)), a(Color("#7a5532") if i % 2 == 0 else Color("#8d6a40"), alpha))
	var f := sin(t * 9.0)
	poly(ci, [c + Vector2(-5, -5), c + Vector2(5, -5), c + Vector2(1.5 + f * 1.5, -17 - sin(t * 7.0) * 2.0)], Color(0.94, 0.54, 0.24, alpha))
	poly(ci, [c + Vector2(-2.5, -5), c + Vector2(3, -5), c + Vector2(f, -11)], Color(1.0, 0.84, 0.35, alpha))
	for i in 4:
		var age := fmod(t * 0.8 + i * 0.25, 1.0)
		ci.draw_circle(c + Vector2(sin(t * 2.0 + i * 1.7) * 4.0, -12.0 - age * 22.0), 0.6, Color(1.0, 0.75, 0.3, (1.0 - age) * alpha))

## The hakama over the hips and both knees, for a figure posed elsewhere (the duel).
static func hakama(ci: CanvasItem, hip: Vector2, up: Vector2, knees: Array, alpha: float) -> void:
	var fw := Vector2(-up.y, up.x)
	var pts: Array = [hip - fw * 5.8 + up, hip + fw * 5.8 + up]
	for kn in knees:
		var dd: Vector2 = (kn - hip).normalized()
		var n := Vector2(-dd.y, dd.x)
		pts.append(kn + n * 5.0)
		pts.append(kn - n * 5.0)
	hull(ci, pts, a(HAKAMA, alpha))

## A kyahan-wrapped shin, for a figure posed elsewhere; its foot is drawn apart.
static func shin(ci: CanvasItem, knee: Vector2, ankle: Vector2, far: bool, alpha: float) -> void:
	limb(ci, knee, ankle, 3.0, 2.5, a(KYAHAN.lightened(0.12) if far else KYAHAN, alpha), false)


# ---------- the oni ----------
## The oni's pose: as the monk's, with the kanabo in the right hand, either
## resting on the right shoulder ("club": "shoulder") or carried along the
## forearm ("arm").
static func oni_pose(kind: String, t: float, phase: float) -> Dictionary:
	var p := {"lean": 4.0, "bow": 0.0, "ll": 0.0, "rl": 0.0, "held": "", "club": "shoulder",
		"left": ["swing", 12.0, 30.0, 0.3], "right": ["reach", "shoulder", Vector3(3.8, 5.4, 0.8), Vector3(0.2, 1.0, -1.0)]}
	match kind:
		"walk":
			var s := sin(t * 9.0)
			p.ll = 20.0 * s
			p.rl = -20.0 * s
			p.llift = 2.8 * maxf(0.0, cos(t * 9.0))
			p.rlift = 2.8 * maxf(0.0, -cos(t * 9.0))
			p.left = ["swing", 12.0 - 16.0 * s, 30.0, 0.3]
			p.lean = 6.0
		"strike":
			var k := clampf(phase, 0.0, 1.0)
			var th := lerpf(175.0, 72.0, k)
			p.right = ["swing", th, 8.0, -0.15]
			p.left = ["swing", th - 12.0, 24.0, 0.2]
			p.club = "arm"
			p.ll = 16.0
			p.rl = -12.0
			p.lean = lerpf(-6.0, 14.0, k)
		"eat":
			p.left = ["reach", "mouth", Vector3(1.6, 0.4, 0.0), Vector3(-0.3, 0.5, 1.0)]
			p.held = "food"
		"drink":
			# from the sake gourd at its waist, filled from the cask
			p.left = ["reach", "mouth", Vector3(5.2, -1.6, 0.0), Vector3(-0.3, 0.5, 1.0)]
			p.held = "gourd"
		"ignite":
			p.left = ["swing", 95.0, 6.0, 0.1]
			p.held = "ember"
		"roar":
			p.left = ["swing", 130.0, 20.0, 0.7]
			p.right = ["swing", 150.0, 10.0, -0.6]
			p.club = "arm"
			p.bow = -14.0
			p.lean = -8.0
		"down":
			p.lean = 70.0
	return p


## The oni at `pos` (its feet), `height` pixels tall, facing `yaw`. `tilt`
## sways it (drunk); `flash` whitens it as a blow lands.
static func oni(ci: CanvasItem, pos: Vector2, yaw: float, height: float, kind: String, t: float, phase: float,
		alpha: float = 1.0, flash: bool = false, tilt: float = 0.0, grounded: bool = true) -> void:
	var k := height / BASE
	ci.draw_set_transform(pos, 0.0, Vector2(k, k))
	if grounded:
		shadow(ci, 12.0)
	ci.draw_set_transform(pos, tilt, Vector2(k, k))
	var skin := Color("#ffd9cc") if flash else ONI
	var p := oni_pose(kind, t, phase)
	var hip := Vector3(0, -16.0, 0)
	var lr := deg_to_rad(p.lean)
	var up := Vector3(sin(lr), -cos(lr), 0)
	var fw := Vector3(cos(lr), sin(lr), 0)
	var sh := hip + up * 14.0
	var head := sh + Vector3(1.6 + sin(deg_to_rad(p.bow)) * 2.0, -4.8, 0)
	var rs := sh + Vector3(0, 0.6, -6.6)
	var ls := sh + Vector3(0, 0.6, 6.6)
	var spots := {"mouth": head + Vector3(4.0, 2.0, 0), "shoulder": rs}
	var L: Array = []
	# legs: thick, kneeless, bare feet flat on the ground
	for side in [1.0, -1.0]:
		var hj := hip + Vector3(0, 1.0, 3.0 * side)
		var sw := deg_to_rad(p.ll if side > 0.0 else p.rl)
		var ankle := hj + Vector3(sin(sw), cos(sw), 0) * O_LEG - Vector3(0, p.get("llift", 0.0) if side > 0.0 else p.get("rlift", 0.0), 0)
		var foot: Array = []
		for c in [Vector3(-2.4, 1.8, 2.0), Vector3(-2.4, 1.8, -2.0), Vector3(4.6, 1.8, 2.2), Vector3(4.6, 1.8, -2.2),
				Vector3(-1.6, -0.4, 1.8), Vector3(-1.6, -0.4, -1.8), Vector3(2.0, -0.2, 1.8), Vector3(2.0, -0.2, -1.8)]:
			foot.append(px(ankle + c, yaw))
		var col := skin.darkened(0.2) if near(hj, yaw) < -0.5 else skin
		L.append([near(ankle, yaw) - 20.0, _oni_leg.bind(ci, px(hj, yaw), px(ankle, yaw), foot, col, alpha)])
	# the tiger-skin wrap, and the sake gourd hung at its side
	L.append([0.2, pelt.bind(ci, px(hip, yaw), Vector2.UP, yaw, alpha)])
	# (not when it hangs on the far side, where only a fleck of it would show)
	var g := hip + ONI_GOURD
	if p.held != "gourd" and near(g, yaw) > -2.0:
		L.append([near(g, yaw) + 0.3, _gourd.bind(ci, px(g, yaw), "sake", alpha, 1.15)])
	# the bare torso, darker than the arms in front of it
	var tk: Array = []
	# the waist inside the tiger skin's own waist
	for q in ring(4.2, -1.0, 6.0):
		tk.append(px(hip + q, yaw))
	for q in ring(4.8, 0.6, 8.0):
		tk.append(px(sh + q, yaw))
	for sa in [-1.0, 1.0]:
		tk.append(px(sh + up * 1.8 + Vector3(0, 0, 5.4 * sa), yaw))
	L.append([-0.5, _fill.bind(ci, tk, a(skin.darkened(0.14), alpha))])
	for sb in [-1.0, 1.0]:
		var c0 := sh + fw * 4.9 - up * 4.4 + Vector3(0, 0, 0.6 * sb)
		var c1 := sh + fw * 4.3 - up * 5.2 + Vector3(0, 0, 5.6 * sb)
		if _avg_near([c0, c1], yaw) > 0.5:
			L.append([_avg_near([c0, c1], yaw), _crease.bind(ci, px(c0, yaw), px(c1, yaw), a(skin.darkened(0.4), alpha))])
	# the navel on the belly, above the tiger skin's waist (`up` points up)
	var navel := hip + fw * 4.6 + up * 4.2
	if near(navel, yaw) > 1.0:
		L.append([near(navel, yaw), _disc.bind(ci, px(navel, yaw), 0.6, a(skin.darkened(0.45), alpha))])
	L.append([near(head, yaw) + 0.5, oni_head.bind(ci, px(head, yaw), yaw, skin, alpha)])
	# arms: the near one lit, the far one in shadow, gold rings above the elbow and at the wrist
	var left := arm(ls, p.left, spots, O_UPPER, O_FORE)
	var right := arm(rs, p.right, spots, O_UPPER, O_FORE)
	var ld := _avg_near([ls, left[0], left[1]], yaw) + 0.3
	var rd := _avg_near([rs, right[0], right[1]], yaw) + 0.3
	L.append([ld, oni_arm.bind(ci, px(ls, yaw), px(left[0], yaw), px(left[1], yaw), skin.lightened(0.05) if ld > 0.0 else skin.darkened(0.3), alpha)])
	L.append([rd, oni_arm.bind(ci, px(rs, yaw), px(right[0], yaw), px(right[1], yaw), skin.lightened(0.05) if rd > 0.0 else skin.darkened(0.3), alpha)])
	# the kanabo in the right hand
	var grip: Vector3 = right[1]
	var cd: Vector3
	if p.club == "shoulder":
		# laid over the top of the shoulder, clear of it by the club's thickness
		cd = (rs + Vector3(-0.4, -3.6, -0.6) - grip).normalized()
	else:
		cd = (grip - right[0]).normalized()
	var club_d := rd + 0.05 if p.club == "shoulder" else rd - 0.05
	L.append([club_d, kanabo.bind(ci, px(grip - cd * 2.5, yaw), px(grip + cd * 24.0, yaw), alpha)])
	if p.club == "shoulder":
		# the fist closed over the grip
		L.append([club_d + 0.01, _disc.bind(ci, px(grip, yaw), 2.4, a(skin.lightened(0.05) if rd > 0.0 else skin.darkened(0.3), alpha))])
	var lh: Vector3 = left[1]
	var held_d := maxf(ld, near(head, yaw) + 1.0) + 0.1 if p.held in ["food", "gourd"] else ld + 0.05
	if p.held == "gourd":
		var tg := tipped(spots.mouth, yaw, 1.3)
		L.append([held_d, _gourd.bind(ci, tg[0], "sake", alpha, 1.3, tg[1])])
	elif p.held != "":
		L.append([held_d, _oni_held.bind(ci, px(lh, yaw), p.held, alpha)])
	paint(L)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _oni_leg(ci: CanvasItem, top: Vector2, ankle: Vector2, foot: Array, col: Color, alpha: float) -> void:
	limb(ci, top, ankle, 7.2, 6.0, a(col, alpha), false)
	var d := (ankle - top).normalized()
	limb(ci, ankle - d * 2.4 + Vector2(-d.y, d.x) * 3.0, ankle - d * 2.4 - Vector2(-d.y, d.x) * 3.0, 1.2, 1.2, a(GOLD, alpha))
	hull(ci, foot, a(col.darkened(0.22), alpha))

static func _crease(ci: CanvasItem, p0: Vector2, p1: Vector2, col: Color) -> void:
	limb(ci, p0, p1, 0.6, 0.6, col)

static func _oni_held(ci: CanvasItem, hand: Vector2, what: String, alpha: float) -> void:
	match what:
		"food":
			ci.draw_circle(hand + Vector2(1.0, -1.2), 2.4, a(Color("#f2ead8"), alpha))
		"ember":
			ci.draw_circle(hand + Vector2(2.6, -0.4), 1.4, Color(1.0, 0.6, 0.2, alpha))
			ci.draw_circle(hand + Vector2(2.6, -0.4), 3.2, Color(1.0, 0.6, 0.2, 0.25 * alpha))

## The kanabo from grip to head: an iron club thickening toward the head, studded.
static func kanabo(ci: CanvasItem, grip: Vector2, tip: Vector2, alpha: float) -> void:
	limb(ci, grip, tip, 2.2, 4.2, a(IRON, alpha))
	var cd := (tip - grip).normalized()
	var n := Vector2(-cd.y, cd.x)
	for i in 4:
		var q := grip.lerp(tip, 0.45 + 0.15 * i)
		ci.draw_circle(q + n * 1.9, 0.55, a(Color("#8a8a94"), alpha))
		ci.draw_circle(q - n * 1.9, 0.55, a(Color("#8a8a94"), alpha))

## A heavy arm through its joints: gold armlet above the elbow, gold cuff at
## the wrist, a fist.
static func oni_arm(ci: CanvasItem, shoulder: Vector2, elbow: Vector2, hand: Vector2, col: Color, alpha: float) -> void:
	limb(ci, shoulder, elbow, 5.4, 4.6, a(col, alpha))
	limb(ci, elbow, hand, 4.6, 4.0, a(col, alpha))
	var d := (elbow - shoulder).normalized()
	var n := Vector2(-d.y, d.x)
	var ring := shoulder.lerp(elbow, 0.62)
	limb(ci, ring + n * 2.4, ring - n * 2.4, 1.3, 1.3, a(GOLD, alpha))
	var f := (hand - elbow).normalized()
	var nf := Vector2(-f.y, f.x)
	var cuff := hand - f * 2.6
	limb(ci, cuff + nf * 2.1, cuff - nf * 2.1, 1.6, 1.6, a(GOLD, alpha))
	ci.draw_circle(hand, 2.4, a(col, alpha))

## The tiger-skin wrap about the hips, seen at `yaw`: short and flared, its
## hem cut in points, striped on the side toward the viewer. `hip` is on the
## screen; `up` tilts it for a figure posed elsewhere.
static func pelt(ci: CanvasItem, hip: Vector2, up: Vector2, yaw: float, alpha: float) -> void:
	var waist: Array = []
	var hem: Array = []
	var n := 14
	for i in n:
		var ang := TAU * i / n
		waist.append(Vector3(cos(ang) * 5.0, -2.6, sin(ang) * 7.0))
		hem.append(Vector3(cos(ang) * 6.0, 3.0, sin(ang) * 8.0))
	var body: Array = []
	for q in waist + hem:
		body.append(at(hip, up, q, yaw))
	hull(ci, body, a(TIGER, alpha))
	for i in n:
		var h0: Vector3 = hem[i]
		var h1: Vector3 = hem[(i + 1) % n]
		var tip: Vector3 = (h0 + h1) / 2.0 * 1.04 + Vector3(0, 2.6, 0)
		poly(ci, [at(hip, up, h0, yaw), at(hip, up, h1, yaw), at(hip, up, tip, yaw)], a(TIGER.darkened(0.08), alpha))
	for i in n:
		var w: Vector3 = waist[i]
		if near(w, yaw) < 1.0 or i % 2 == 1:
			continue
		var h: Vector3 = hem[i]
		var mid := w.lerp(h, 0.55) + Vector3(0.6, 0, 0)
		limb(ci, at(hip, up, w.lerp(h, 0.15), yaw), at(hip, up, mid, yaw), 1.0, 0.7, a(INK, alpha))

## The oni's head seen at `yaw`: a shaggy black mane behind and above it
## (around the face from the front, over the head from behind), horns, heavy
## brows, yellow eyes, tusks.
static func oni_head(ci: CanvasItem, c: Vector2, yaw: float, skin: Color, alpha: float, up := Vector2.UP) -> void:
	var L: Array = []
	var back := Vector3(-2.6, -0.8, 0)
	var mc := at(c, up, back, yaw)
	var mane := PackedVector2Array()
	var side := cos(deg_to_rad(yaw))
	for i in 22:
		var ang := TAU * i / 22.0
		var r := 5.6 + (1.3 if i % 2 == 0 else 0.0)
		var dv := Vector2(cos(ang), sin(ang))
		# it falls to the shoulders behind the head, and on both sides from the front
		var behind := maxf(0.0, -dv.x * signf(side)) if absf(side) > 0.3 else absf(dv.x)
		r += 3.0 * maxf(0.0, dv.y) * behind
		mane.append(mc + (dv.x * Vector2(-up.y, up.x) - dv.y * up) * r)
	L.append([near(back, yaw) - 0.01, _shape.bind(ci, mane, a(INK, alpha))])
	L.append([0.0, _disc.bind(ci, c, 4.8, a(skin, alpha))])
	L.append([0.01, _cap_fill.bind(ci, cap(c, up, 5.0, Vector3(-0.55, -0.83, 0), 80.0, yaw), a(INK, alpha))])
	for sb in [-1.0, 1.0]:
		var base := Vector3(1.0 + 0.5 * sb, -4.0, 2.0 * sb)
		var tip := base + Vector3(0.8, -5.6, 0.6 * sb)
		L.append([near(base, yaw) - 0.005, _horn.bind(ci, at(c, up, base, yaw), at(c, up, tip, yaw), 1.3, a(HORN, alpha))])
		var brow := Vector3(3.9, -2.0, 1.7 * sb)
		var eye := Vector3(4.2, -0.9, 1.7 * sb)
		if near(eye, yaw) > 0.6:
			L.append([near(brow, yaw) + 0.01, _bar.bind(ci, at(c, up, brow, yaw), 2.2, 0.9, a(INK, alpha))])
			L.append([near(eye, yaw), _bar.bind(ci, at(c, up, eye, yaw), 1.6, 1.1, a(Color("#ffd65a"), alpha))])
		var tusk := Vector3(4.3, 2.4, 1.3 * sb)
		if near(tusk, yaw) > 0.4:
			var tb := at(c, up, tusk, yaw)
			L.append([near(tusk, yaw) + 0.02, _horn.bind(ci, tb, tb - up * 1.7, 0.6, a(Color.WHITE, alpha))])
	var mouth := Vector3(4.4, 1.8, 0)
	if near(mouth, yaw) > 1.0:
		L.append([near(mouth, yaw), _bar.bind(ci, at(c, up, mouth, yaw), 3.0 * absf(sin(deg_to_rad(yaw))) + 0.8, 0.7, a(INK, alpha))])
	paint(L)

static func _shape(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if Geometry2D.triangulate_polygon(pts).is_empty():
		pts = Geometry2D.convex_hull(pts)
	ci.draw_colored_polygon(pts, col)

static func _bar(ci: CanvasItem, c: Vector2, w: float, h: float, col: Color) -> void:
	ci.draw_rect(Rect2(c - Vector2(w, h) / 2.0, Vector2(w, h)), col)


# ---------- townspeople, the watch, exorcists ----------
## A person from a look (robe, sash, skin, hat colour or "", item), in "front"
## view at rest or "side" view when walking.
static func person(ci: CanvasItem, pos: Vector2, face: int, height: float, look: Dictionary, view: String,
		kind: String, t: float, alpha: float = 1.0) -> void:
	var k := height / 40.0
	var robe := Color(look.get("robe", "#5b4a38"))
	var skin := Color(look.get("skin", "#d6ab86"))
	var hat: String = look.get("hat", "")
	var item: String = look.get("item", "")
	ci.draw_set_transform(pos, 0.0, Vector2(k, k))
	shadow(ci, 7.0)
	if kind == "down":
		ci.draw_set_transform(pos, -PI / 2.0 * face, Vector2(face * k, k))
	elif view == "front":
		ci.draw_set_transform(pos, 0.0, Vector2(k, k))
	else:
		ci.draw_set_transform(pos, 0.0, Vector2(face * k, k))
	var head := Vector2(0, -33)
	if view == "front" and kind != "down":
		# feet, robe, sash, arms at the sides
		ci.draw_rect(Rect2(-4.2, -2.4, 3.0, 2.4), a(INK, alpha))
		ci.draw_rect(Rect2(1.2, -2.4, 3.0, 2.4), a(INK, alpha))
		poly(ci, [Vector2(-5.2, -29), Vector2(5.2, -29), Vector2(6.6, -2.2), Vector2(-6.6, -2.2)], a(robe, alpha))
		poly(ci, [Vector2(-1.8, -29), Vector2(1.8, -29), Vector2(0, -22)], a(skin, alpha))
		if look.has("sash"):
			ci.draw_rect(Rect2(-5.6, -17.5, 11.2, 2.6), a(Color(look.sash), alpha))
		for side in [-1.0, 1.0]:
			limb(ci, Vector2(5.0 * side, -28), Vector2(6.6 * side, -17), 3.6, 3.0, a(robe.darkened(0.12), alpha))
			ci.draw_circle(Vector2(6.8 * side, -16.2), 1.4, a(skin, alpha))
		_item(ci, item, Vector2(7.0, -16.5), true, t, alpha)
	else:
		# side: legs swing below the robe's hem, arms swing
		var s := sin(t * 9.0) if kind == "walk" else 0.0
		for lg in [-1.0, 1.0]:
			var foot := Vector2(2.6 * s * lg, -0.8)
			limb(ci, Vector2(0, -6), foot, 2.4, 2.0, a(INK.lightened(0.15), alpha))
		poly(ci, [Vector2(-4.4, -29), Vector2(4.6, -29), Vector2(5.6, -5), Vector2(-5.2, -5)], a(robe, alpha))
		if look.has("sash"):
			ci.draw_rect(Rect2(-4.8, -17.5, 10.2, 2.6), a(Color(look.sash), alpha))
		var ang := 12.0 - 18.0 * s
		if kind == "strike":
			ang = 95.0
		var hand := Vector2(1.0, -28) + dir(ang) * 12.0
		limb(ci, Vector2(1.0, -28), hand, 3.4, 2.8, a(robe.darkened(0.12), alpha))
		ci.draw_circle(hand, 1.4, a(skin, alpha))
		_item(ci, item, hand, false, t, alpha, kind == "strike")
		head = Vector2(0.6, -33)
	ci.draw_circle(head, 4.0, a(skin, alpha))
	if view != "front":
		ci.draw_rect(Rect2(head + Vector2(2.0, -0.8), Vector2(1.0, 1.0)), a(INK, alpha))
		poly(ci, [head + Vector2(-4.0, 0.4), head + Vector2(-3.6, -2.6), head + Vector2(-0.6, -4.0), head + Vector2(-1.4, 0.4)], a(INK, alpha))
	else:
		ci.draw_rect(Rect2(head + Vector2(-2.2, -0.6), Vector2(1.0, 1.0)), a(INK, alpha))
		ci.draw_rect(Rect2(head + Vector2(1.2, -0.6), Vector2(1.0, 1.0)), a(INK, alpha))
		poly(ci, [head + Vector2(-4.0, -1.0), head + Vector2(-3.4, -3.2), head + Vector2(0, -4.2), head + Vector2(3.4, -3.2), head + Vector2(4.0, -1.0), head + Vector2(0, -3.0)], a(INK, alpha))
	if hat == "#1b1b22":
		# eboshi: a tall black cap
		poly(ci, [head + Vector2(-2.6, -3.0), head + Vector2(2.6, -3.0), head + Vector2(1.4, -10.0), head + Vector2(-1.8, -8.6)], a(INK, alpha))
	elif hat != "":
		# kasa: a wide straw hat
		poly(ci, [head + Vector2(-8.0, -2.2), head + Vector2(8.0, -2.2), head + Vector2(0, -7.6)], a(Color(hat), alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _item(ci: CanvasItem, item: String, hand: Vector2, front: bool, t: float, alpha: float, thrust := false) -> void:
	match item:
		"lantern":
			ci.draw_line(hand, hand + Vector2(0, 3), a(INK, alpha), 0.8)
			ci.draw_rect(Rect2(hand + Vector2(-2.0, 3.0), Vector2(4.0, 5.0)), Color(1.0, 0.82, 0.5, 0.95 * alpha))
		"spear":
			var d := Vector2(0.35, -1.0).normalized() if not thrust else Vector2(1.0, -0.12).normalized()
			limb(ci, hand - d * 10.0, hand + d * 26.0, 1.0, 1.0, a(WOOD, alpha))
			poly(ci, [hand + d * 26.0 + Vector2(-d.y, d.x) * 1.2, hand + d * 31.0, hand + d * 26.0 - Vector2(-d.y, d.x) * 1.2], a(Color("#c8ccd2"), alpha))
		"bucket":
			ci.draw_line(hand, hand + Vector2(0, 2.0), a(INK, alpha), 0.6)
			poly(ci, [hand + Vector2(-2.2, 2.0), hand + Vector2(2.2, 2.0), hand + Vector2(1.8, 6.0), hand + Vector2(-1.8, 6.0)], a(Color("#8d6a40"), alpha))
			ci.draw_line(hand + Vector2(-2.2, 3.4), hand + Vector2(2.2, 3.4), a(Color("#5a4630"), alpha), 0.5)
		"talisman":
			ci.draw_rect(Rect2(hand + Vector2(-1.2, -5.0), Vector2(2.6, 5.0)), a(Color("#f4efe2"), alpha))
			ci.draw_line(hand + Vector2(0.1, -4.4), hand + Vector2(0.1, -0.8), a(Color("#b0372c"), alpha), 0.6)
		"swords":
			limb(ci, Vector2(-3.0, -17.0), Vector2(-11.0, -21.0), 1.2, 1.2, a(INK, alpha))
			limb(ci, Vector2(-3.0, -16.0), Vector2(-8.0, -18.0), 1.0, 1.0, a(INK, alpha))
