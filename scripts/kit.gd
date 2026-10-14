extends RefCounted
## The drawing kit. Every building, person, creature and prop is composed
## from a small set of reusable parts, parameterised by data (a building's
## style, a person's look). Stations never draw anything by hand; they hand
## data to these parts. When real sprites arrive they can replace the parts
## one at a time, and the data that composes them stays the same.

const Figure := preload("res://scripts/figure.gd")
const INK := Color("#0b0d1c")
const PAPER := Color("#ece3cf")

## Default styles per building kind. A building's own "style" entry overrides any field.
const KIND_STYLE := {
	"house": {"wall": "#8a5f3f", "roof": "thatch", "roof_col": "#7b6a48", "storeys": 1},
	"stall": {"wall": "#8a5f3f", "roof": "bark", "roof_col": "#5a4a36", "awning": "#2d3d6b", "counter": true},
	"inn": {"wall": "#9a7050", "roof": "tile", "roof_col": "#3d3f4a", "storeys": 2, "noren": "#2d3d6b", "lanterns": 2},
	"den": {"wall": "#7a5440", "roof": "tile", "roof_col": "#4a2a2a", "noren": "#1f1f28", "lanterns": 1, "lantern_col": "#d9573a"},
}


static func shade(c: Color, amt: float) -> Color:
	return c.lerp(INK, amt)

static func poly(ci: CanvasItem, pts: Array, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), col)

static func style_of(b: Dictionary) -> Dictionary:
	var st: Dictionary = KIND_STYLE.get(b.kind, {}).duplicate()
	st.merge(b.get("style", {}), true)
	return st


# ---------- sky and ground ----------
## Draws sky, moon (lit fraction 0 = new moon) and backdrop. Returns the darkening to apply to the scene.
static func sky(ci: CanvasItem, cam: float, night: bool, hours: float, moon_lit: float, backdrop: String, base: float, t: float) -> float:
	var w := 480.0
	var top: Color
	var bot: Color
	var dk: float
	if night:
		top = Color("#0b1028")
		bot = Color("#2b2447")
		dk = 0.55
	else:
		var d := clampf((hours - 15.0) / 3.0, 0.0, 1.0)
		top = Color("#8fa9bd").lerp(Color("#3d3a5c"), d)
		bot = Color("#cfd6d3").lerp(Color("#d98b5f"), d)
		dk = d * 0.25
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, base), Vector2(0, base)]), PackedColorArray([top, top, bot, bot]))
	if night:
		for i in 40:
			var sx := fmod(i * 131.7 - cam * 0.02, w)
			var sy := fmod(i * 47.3, base * 0.6)
			ci.draw_rect(Rect2(sx, sy, 1, 1), Color(1, 1, 1, 0.35 + 0.25 * sin(t * 2.0 + i)))
		moon(ci, Vector2(380 - cam * 0.05, 48), 12.0, moon_lit, top.lerp(bot, 48.0 / base))
	var far := shade(Color("#6d7f8c"), dk + 0.1)
	var near := shade(Color("#4d5d57"), dk + 0.15)
	match backdrop:
		"peaks":
			_ridge(ci, cam, 0.12, base - 70, 80, far, 1.0, base, true)
			_ridge(ci, cam, 0.35, base - 25, 45, near, 4.0, base, false)
		"forest":
			_ridge(ci, cam, 0.15, base - 55, 50, far, 1.0, base, false)
			for i in 26:
				var x := fmod(i * 61.0 - cam * 0.45, w + 60.0) - 30.0
				cedar(ci, x, base + 2, 70.0 + fmod(i * 23.0, 40.0), dk + 0.25, true)
		_:
			_ridge(ci, cam, 0.15, base - 64, 55, far, 1.0, base, false)
			_ridge(ci, cam, 0.4, base - 22, 45, near, 4.0, base, false)
	return dk

static func _ridge(ci: CanvasItem, cam: float, par: float, y0: float, amp: float, col: Color, seed: float, base: float, snow: bool) -> void:
	var pts: Array = [Vector2(0, base)]
	var x := 0.0
	var tops: Array = []
	while x <= 480.0:
		var wx := x + cam * par
		var y := y0 - amp * (0.3 * sin(wx * 0.011 + seed) + 0.15 * sin(wx * 0.037 + seed * 2.0))
		pts.append(Vector2(x, y))
		tops.append(Vector2(x, y))
		x += 8.0
	pts.append(Vector2(480, base))
	poly(ci, pts, col)
	if snow:
		for p in tops:
			if p.y < y0 - amp * 0.2:
				ci.draw_rect(Rect2(p.x - 4, p.y, 8, 3), Color(0.92, 0.92, 0.9, 0.8))

static func moon(ci: CanvasItem, c: Vector2, r: float, lit: float, sky_col: Color) -> void:
	if lit <= 0.01:
		return   # the new moon: nothing in the sky
	ci.draw_circle(c, r, Color("#e9e1c8"))
	if lit >= 0.99:
		return
	# a waning moon is lit on the left; the shadow eats it from the right
	ci.draw_circle(c + Vector2(2.0 * r * lit, -1.0), r * 1.02, sky_col)

static func ground(ci: CanvasItem, base: float, dk: float, kind: String) -> void:
	var col := Color("#6e5c47")
	var road := Color("#7d6a52")
	if kind == "stone":
		col = Color("#6b6a66")
		road = Color("#86847c")
	elif kind == "forest":
		col = Color("#4f5a3c")
		road = Color("#6a5d45")
	ci.draw_rect(Rect2(0, base, 480, 270 - base), shade(col, dk))
	ci.draw_rect(Rect2(0, base + 22, 480, 30), shade(road, dk))
	if kind == "stone":
		var y := base + 24
		while y < base + 52:
			ci.draw_line(Vector2(0, y), Vector2(480, y), shade(Color("#5f5d58"), dk), 1.0)
			y += 7


## Ground that rises. `lift` maps a world x to how far the ground there stands
## above the ground under the camera's centre, in screen pixels; the road band
## and everything standing on it are drawn raised by the same amount.
static func terrain(ci: CanvasItem, cam: float, base: float, dk: float, kind: String, lift: Callable) -> void:
	var col := Color("#6b6a66") if kind == "stone" else (Color("#4f5a3c") if kind == "forest" else Color("#6e5c47"))
	var road := Color("#86847c") if kind == "stone" else (Color("#6a5d45") if kind == "forest" else Color("#7d6a52"))
	var x := -8.0
	while x < 488.0:
		var y0: float = base - lift.call(cam + x)
		var y1: float = base - lift.call(cam + x + 8.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x, y0), Vector2(x + 8, y1), Vector2(x + 8, 400), Vector2(x, 400)]), shade(col, dk))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x, y0 + 22), Vector2(x + 8, y1 + 22), Vector2(x + 8, y1 + 52), Vector2(x, y0 + 52)]), shade(road, dk))
		if kind == "stone" and absf(y1 - y0) > 0.5:
			# stone steps where the path climbs
			ci.draw_line(Vector2(x, y0 + 22), Vector2(x, y0 + 52), shade(Color("#5f5d58"), dk), 1.0)
			ci.draw_line(Vector2(x, y0 + 22), Vector2(x + 8, y0 + 22), shade(Color("#9c998f"), dk), 1.0)
		x += 8.0


# ---------- buildings ----------
static func building(ci: CanvasItem, b: Dictionary, sx: float, base: float, night: bool, gate_open: bool) -> void:
	var dk := 0.5 if night else 0.0
	if b.hp <= 0:
		rubble(ci, sx, b.w, base, dk)
		return
	match b.kind:
		"shrine":
			shrine(ci, sx, b.w, b.h, base, dk)
		"gate":
			gate(ci, sx, b.w, b.h, base, dk, gate_open and not night)
		"temple":
			temple(ci, sx, b.w, b.h, base, dk)
		_:
			facade(ci, b, sx, base, dk, night)
	if b.hp < 100:
		var y: float = base - b.h
		var n := int(ceil((100.0 - b.hp) / 20.0))
		for i in n:
			var cx: float = sx + 12 + float((i * 29) % int(maxf(1.0, b.w - 24)))
			ci.draw_polyline(PackedVector2Array([Vector2(cx, y + b.h * 0.45), Vector2(cx + 5, y + b.h * 0.6), Vector2(cx - 2, y + b.h * 0.75)]), shade(Color("#1a1310"), dk * 0.5), 1.0)
	if b.get("burning", false):
		ci.draw_rect(Rect2(sx, base - b.h, b.w, b.h), Color(1.0, 0.45, 0.15, 0.12))

static func facade(ci: CanvasItem, b: Dictionary, sx: float, base: float, dk: float, night: bool) -> void:
	var st := style_of(b)
	var y: float = base - b.h
	var w: float = b.w
	var wall := shade(Color(st.get("wall", "#8a5f3f")), dk)
	var beam := shade(Color("#3b2a1f"), dk)
	var roof_h: float = b.h * 0.34
	var two: bool = st.get("storeys", 1) == 2
	var mid: float = y + b.h * 0.52
	if two:
		ci.draw_rect(Rect2(sx + 6, mid, w - 12, base - mid), wall)
		ci.draw_rect(Rect2(sx + 10, y + roof_h * 0.9, w - 20, mid - y - roof_h * 0.9), wall)
		poly(ci, [Vector2(sx, mid + 4), Vector2(sx + w, mid + 4), Vector2(sx + w - 8, mid - 4), Vector2(sx + 8, mid - 4)], shade(Color(st.roof_col), dk))
		ci.draw_rect(Rect2(sx + 12, mid - 12, w - 24, 2), beam)
		var bx := sx + 12
		while bx < sx + w - 12:
			ci.draw_rect(Rect2(bx, mid - 12, 1, 8), beam)
			bx += 6
	else:
		ci.draw_rect(Rect2(sx + 6, y + roof_h, w - 12, b.h - roof_h), wall)
	var px := sx + 6
	while px < sx + w - 6:
		ci.draw_rect(Rect2(px, y + roof_h, 2, b.h - roof_h), beam)
		px += w / 4.0
	roof(ci, st.get("roof", "thatch"), shade(Color(st.get("roof_col", "#7b6a48")), dk), sx, y, w, roof_h)
	# lattice windows, lit from inside at night
	var win := Color(1.0, 0.77, 0.43, 0.6) if night else shade(Color("#c9b994"), dk)
	var wy: float = (y + roof_h + 6) if not two else (y + roof_h + 2)
	for i in int(maxf(1.0, floor(w / 60.0))):
		var wx: float = sx + 14 + i * 44
		ci.draw_rect(Rect2(wx, wy, 14, 9), win)
		ci.draw_line(Vector2(wx + 7, wy), Vector2(wx + 7, wy + 9), beam, 1.0)
	# doorway, with a noren curtain if the style has one
	var dw := 20.0
	var dx: float = sx + w / 2.0 - dw / 2.0
	ci.draw_rect(Rect2(dx, base - 22, dw, 22), shade(Color("#2a2018"), dk))
	if st.has("noren"):
		var nc := shade(Color(st.noren), dk)
		for k in 3:
			ci.draw_rect(Rect2(dx + 1 + k * 6.5, base - 22, 5.5, 10), nc)
	if st.get("awning", "") != "":
		ci.draw_rect(Rect2(sx + 8, y + roof_h, w - 16, 8), shade(Color(st.awning), dk))
	if st.get("counter", false):
		ci.draw_rect(Rect2(sx + 4, base - 16, w - 8, 4), shade(Color("#6b4a2b"), dk))
	var lc := Color(st.get("lantern_col", "#c8402e"))
	for k in int(st.get("lanterns", 0)):
		lantern(ci, Vector2(sx + 10 + k * (w - 20), y + roof_h + 4), lc, night)
	if st.get("sign", "") != "":
		ci.draw_rect(Rect2(sx + w - 18, y + roof_h + 4, 8, 22), shade(Color("#d9cfb4"), dk))
	for i in int(b.get("barrels", 0)):
		ci.draw_circle(Vector2(sx + w - 18 - i * 9, base - 5), 4.5, shade(Color("#6b4a2b"), dk))

static func roof(ci: CanvasItem, kind: String, col: Color, sx: float, y: float, w: float, h: float) -> void:
	match kind:
		"tile":
			poly(ci, [Vector2(sx - 8, y + h + 2), Vector2(sx + w + 8, y + h + 2), Vector2(sx + w - w * 0.2, y + 2), Vector2(sx + w * 0.2, y + 2)], col)
			ci.draw_rect(Rect2(sx + w * 0.18, y - 1, w * 0.64, 4), col.darkened(0.2))
			poly(ci, [Vector2(sx - 8, y + h + 2), Vector2(sx - 2, y + h - 4), Vector2(sx + 2, y + h + 2)], col.darkened(0.2))
			poly(ci, [Vector2(sx + w + 8, y + h + 2), Vector2(sx + w + 2, y + h - 4), Vector2(sx + w - 2, y + h + 2)], col.darkened(0.2))
			var ly := y + 8.0
			while ly < y + h:
				ci.draw_line(Vector2(sx + w * 0.15, ly), Vector2(sx + w * 0.85, ly), col.darkened(0.25), 1.0)
				ly += 5.0
		"bark":
			poly(ci, [Vector2(sx - 4, y + h), Vector2(sx + w + 4, y + h), Vector2(sx + w * 0.72, y + h * 0.2), Vector2(sx + w * 0.28, y + h * 0.2)], col)
		_:
			# thatch: thick and steep, with a dark ridge
			poly(ci, [Vector2(sx - 6, y + h + 2), Vector2(sx + w + 6, y + h + 2), Vector2(sx + w * 0.72, y - 4), Vector2(sx + w * 0.28, y - 4)], col)
			ci.draw_rect(Rect2(sx + w * 0.26, y - 6, w * 0.48, 5), col.darkened(0.35))
			ci.draw_line(Vector2(sx - 6, y + h + 2), Vector2(sx + w + 6, y + h + 2), col.darkened(0.3), 2.0)

static func lantern(ci: CanvasItem, p: Vector2, col: Color, night: bool) -> void:
	if night:
		ci.draw_circle(p + Vector2(0, 5), 9, Color(col, 0.18))
	ci.draw_line(p, p + Vector2(0, 2), Color("#1b1b22"), 1.0)
	ci.draw_rect(Rect2(p.x - 3, p.y + 2, 6, 8), col if night else col.darkened(0.2))

static func rubble(ci: CanvasItem, sx: float, w: float, base: float, dk: float) -> void:
	var rc := shade(Color("#4a3b30"), dk)
	for i in 8:
		var rx: float = sx + w * i / 8.0
		var rh := 5.0 + float((i * 37) % 9)
		poly(ci, [Vector2(rx, base), Vector2(rx + w / 16.0, base - rh), Vector2(rx + w / 8.0 + 4, base)], rc)
	ci.draw_rect(Rect2(sx + 10, base - 18, 3, 18), shade(Color("#211a17"), dk))
	ci.draw_rect(Rect2(sx + w - 16, base - 12, 3, 12), shade(Color("#211a17"), dk))

static func torii(ci: CanvasItem, x: float, base: float, h: float, dk: float, foot: float = 0.0) -> void:
	var red := shade(Color("#c23b2c"), dk * 0.8)
	var wd := h * 0.8
	ci.draw_rect(Rect2(x - wd / 2 + 3, base - h, 3, h + foot), red)
	ci.draw_rect(Rect2(x + wd / 2 - 6, base - h, 3, h + foot), red)
	ci.draw_rect(Rect2(x - wd / 2 - 3, base - h - 3, wd + 6, 3), shade(Color("#1b1b22"), dk))
	ci.draw_rect(Rect2(x - wd / 2, base - h + 5, wd, 2), red)

static func shrine(ci: CanvasItem, sx: float, w: float, h: float, base: float, dk: float) -> void:
	var y := base - h
	ci.draw_rect(Rect2(sx + 30, y + 26, w - 34, h - 26), shade(Color("#6f4b33"), dk))
	poly(ci, [Vector2(sx + 22, y + 28), Vector2(sx + w + 6, y + 28), Vector2(sx + w - 10, y + 12), Vector2(sx + 38, y + 12)], shade(Color("#2f3038"), dk))
	ci.draw_rect(Rect2(sx + 52, y + 34, 16, 4), shade(Color("#d9cfb4"), dk))
	torii(ci, sx + 14, base, h - 20, dk, 14.0)

static func gate(ci: CanvasItem, sx: float, w: float, h: float, base: float, dk: float, open: bool) -> void:
	var y := base - h
	var wood := shade(Color("#3b2a1f"), dk)
	ci.draw_rect(Rect2(sx + 2, y + 10, 5, h - 10 + 60), wood)
	ci.draw_rect(Rect2(sx + w - 7, y + 10, 5, h - 10 + 60), wood)
	poly(ci, [Vector2(sx - 6, y + 12), Vector2(sx + w + 6, y + 12), Vector2(sx + w - 2, y), Vector2(sx + 2, y)], shade(Color("#2f3038"), dk))
	if not open:
		ci.draw_rect(Rect2(sx - 2, base + 30, w + 4, 4), shade(Color("#d8cdb4"), dk))

static func temple(ci: CanvasItem, sx: float, w: float, h: float, base: float, dk: float) -> void:
	var y := base - h
	# stone platform and steps
	ci.draw_rect(Rect2(sx, base - 14, w, 14), shade(Color("#8a877e"), dk))
	for i in 4:
		ci.draw_rect(Rect2(sx + w / 2 - 22 + i * 3, base - 4 - i * 3.5 + 4, 44 - i * 6, 3.5), shade(Color("#9c998f"), dk))
	ci.draw_rect(Rect2(sx + 14, y + h * 0.42, w - 28, h * 0.58 - 14), shade(Color("#6f4b33"), dk))
	var px := sx + 14
	while px <= sx + w - 14:
		ci.draw_rect(Rect2(px - 2, y + h * 0.42, 4, h * 0.58 - 14), shade(Color("#a33a2c"), dk * 0.8))
		px += (w - 28) / 5.0
	# great roof with upturned eaves, and a smaller roof above
	var rc := shade(Color("#33363f"), dk)
	poly(ci, [Vector2(sx - 14, y + h * 0.46), Vector2(sx + w + 14, y + h * 0.46), Vector2(sx + w - 24, y + h * 0.2), Vector2(sx + 24, y + h * 0.2)], rc)
	poly(ci, [Vector2(sx - 14, y + h * 0.46), Vector2(sx - 22, y + h * 0.38), Vector2(sx - 2, y + h * 0.44)], rc)
	poly(ci, [Vector2(sx + w + 14, y + h * 0.46), Vector2(sx + w + 22, y + h * 0.38), Vector2(sx + w + 2, y + h * 0.44)], rc)
	ci.draw_rect(Rect2(sx + 34, y + h * 0.12, w - 68, h * 0.1), shade(Color("#6f4b33"), dk))
	poly(ci, [Vector2(sx + 20, y + h * 0.14), Vector2(sx + w - 20, y + h * 0.14), Vector2(sx + w - 44, y), Vector2(sx + 44, y)], rc)
	ci.draw_rect(Rect2(sx + w / 2 - 10, y + h * 0.5, 20, 6), shade(Color("#d9cfb4"), dk))


# ---------- props ----------
static func cedar(ci: CanvasItem, x: float, base: float, h: float, dk: float, far: bool = false) -> void:
	var trunk := shade(Color("#3b2a1f"), dk)
	var leaf := shade(Color("#2f4a3b") if not far else Color("#3a5446"), dk)
	ci.draw_rect(Rect2(x - 2, base - h, 4, h), trunk)
	for k in 4:
		var yy := base - h + k * h * 0.18
		var ww := 8.0 + k * 5.0
		poly(ci, [Vector2(x - ww, yy + h * 0.22), Vector2(x + ww, yy + h * 0.22), Vector2(x, yy)], leaf)

static func rock(ci: CanvasItem, x: float, base: float, s: float, dk: float) -> void:
	poly(ci, [Vector2(x - s, base), Vector2(x - s * 0.7, base - s * 0.8), Vector2(x + s * 0.2, base - s), Vector2(x + s, base - s * 0.4), Vector2(x + s * 1.1, base)], shade(Color("#6d6b66"), dk))

## A waterfall at the back of the path: a dark cliff, the white fall, a pool.
static func waterfall(ci: CanvasItem, x: float, base: float, h: float, dk: float, t: float) -> void:
	var rock := shade(Color("#5b5a57"), dk)
	poly(ci, [Vector2(x - 34, base), Vector2(x - 30, base - h * 0.7), Vector2(x - 14, base - h), Vector2(x + 16, base - h * 1.05),
		Vector2(x + 30, base - h * 0.6), Vector2(x + 36, base)], rock)
	var water := shade(Color("#dfeaf2"), dk * 0.7)
	ci.draw_rect(Rect2(x - 7, base - h, 14, h), water)
	for i in 4:
		var y := base - h + fmod(t * 60.0 + i * h / 4.0, h)
		ci.draw_line(Vector2(x - 5 + i * 3, y), Vector2(x - 5 + i * 3, y + 8), shade(Color("#b8cad8"), dk), 1.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 22, base + 2), Vector2(x, base - 3), Vector2(x + 22, base + 2), Vector2(x, base + 6)]), shade(Color("#9fb8c8"), dk))
	for i in 3:
		var age := fmod(t * 1.3 + i / 3.0, 1.0)
		ci.draw_arc(Vector2(x, base), 6.0 + age * 12.0, PI, TAU, 10, Color(1, 1, 1, (1.0 - age) * 0.5), 1.0)

static func stone_lantern(ci: CanvasItem, x: float, base: float, dk: float, lit: bool) -> void:
	var c := shade(Color("#8a877e"), dk)
	ci.draw_rect(Rect2(x - 5, base - 4, 10, 4), c)
	ci.draw_rect(Rect2(x - 2, base - 18, 4, 14), c)
	ci.draw_rect(Rect2(x - 6, base - 26, 12, 8), c)
	if lit:
		ci.draw_rect(Rect2(x - 3, base - 24, 6, 4), Color(1.0, 0.8, 0.45, 0.9))
	poly(ci, [Vector2(x - 9, base - 26), Vector2(x + 9, base - 26), Vector2(x, base - 33)], c)

static func bush(ci: CanvasItem, x: float, base: float, dk: float) -> void:
	ci.draw_circle(Vector2(x, base + 2), 9, shade(Color("#3e5a4a"), dk))
	ci.draw_circle(Vector2(x + 9, base + 4), 7, shade(Color("#3e5a4a"), dk))

static func campfire(ci: CanvasItem, x: float, y: float, t: float) -> void:
	ci.draw_rect(Rect2(x - 8, y - 2, 16, 3), Color("#3b2a1f"))
	ci.draw_circle(Vector2(x, y - 6), 9, Color(1.0, 0.55, 0.2, 0.18))
	poly(ci, [Vector2(x - 5, y - 2), Vector2(x + 5, y - 2), Vector2(x + sin(t * 9.0) * 2.0, y - 12 - sin(t * 7.0) * 2.0)], Color("#f08a3c"))
	poly(ci, [Vector2(x - 2, y - 2), Vector2(x + 3, y - 2), Vector2(x, y - 7)], Color("#ffd65a"))

static func hide_spot(ci: CanvasItem, h: Dictionary, sx: float, base: float, dk: float) -> void:
	if sx + h.w < -10 or sx > 490:
		return
	match h.look:
		"alley":
			ci.draw_rect(Rect2(sx + 4, base - 44, h.w - 8, 44), shade(Color("#211a17"), dk * 0.6))
		"grove":
			for i in 3:
				cedar(ci, sx + h.w * (0.2 + 0.3 * i), base + 4, 46.0, dk)
		"reeds":
			for i in 14:
				var x: float = sx + i * h.w / 14.0
				ci.draw_line(Vector2(x, base + 12), Vector2(x + 3, base - 26 - (i % 3) * 5), shade(Color("#6f7a45"), dk), 1.5)
		"cargo":
			for i in int(maxf(1.0, floor(h.w / 34.0))):
				ci.draw_rect(Rect2(sx + 6 + i * 34, base - 26, 30, 28), shade(Color("#7b6242"), dk))
				ci.draw_rect(Rect2(sx + 16 + i * 34, base - 44, 30, 20), shade(Color("#6b5335"), dk))
		"hay":
			poly(ci, [Vector2(sx, base + 4), Vector2(sx + h.w, base + 4), Vector2(sx + h.w * 0.5, base - 34)], shade(Color("#b39a56"), dk))

## Markers for what the oni can eat (bowls) and drink (casks) in a building tonight.
static func food_marks(ci: CanvasItem, b: Dictionary, sx: float, base: float, t: float) -> void:
	var n: int = b.pantry + b.barrels
	if n <= 0 or b.hp <= 0:
		return
	var y: float = base - b.h - 12 + sin(t * 3.0) * 1.5
	var x0: float = sx + b.w / 2.0 - (n - 1) * 5.0
	for i in n:
		var p := Vector2(x0 + i * 10.0, y)
		ci.draw_circle(p, 5.5, Color(1.0, 0.85, 0.5, 0.22))
		if i < b.barrels:
			ci.draw_rect(Rect2(p.x - 3, p.y - 3, 6, 6), Color("#c58a4a"))
			ci.draw_line(Vector2(p.x - 3, p.y), Vector2(p.x + 3, p.y), Color("#5a3a1c"), 1.0)
		else:
			poly(ci, [Vector2(p.x - 4, p.y - 1), Vector2(p.x + 4, p.y - 1), Vector2(p.x + 2, p.y + 3), Vector2(p.x - 2, p.y + 3)], Color("#f2ead8"))
			ci.draw_circle(Vector2(p.x, p.y - 2), 2.5, Color("#ffffff"))


# ---------- icons ----------
## Action icons on a dark badge. One icon per kind of resource or act: buying,
## stealing and alms are all "food"; fishing and refilling are both "water".
static func icon(ci: CanvasItem, kind: String, p: Vector2, active: bool = false, a: float = 1.0) -> void:
	var r := 7.5 if active else 6.0
	ci.draw_circle(p, r + 1.0, Color(0.08, 0.09, 0.17, 0.8 * a))
	if active:
		ci.draw_arc(p, r + 1.0, 0, TAU, 20, Color(1.0, 0.84, 0.35, a), 1.2)
	var k := r / 6.0
	match kind:
		"food":
			poly(ci, [p + Vector2(-4, 0) * k, p + Vector2(4, 0) * k, p + Vector2(2.5, 3) * k, p + Vector2(-2.5, 3) * k], Color(0.84, 0.32, 0.22, a))
			ci.draw_circle(p + Vector2(0, -0.5) * k, 3.2 * k, Color(0.97, 0.95, 0.9, a))
		"water":
			poly(ci, [p + Vector2(0, -4.5) * k, p + Vector2(3, 0.5) * k, p + Vector2(-3, 0.5) * k], Color(0.45, 0.72, 0.95, a))
			ci.draw_circle(p + Vector2(0, 1) * k, 3.0 * k, Color(0.45, 0.72, 0.95, a))
		"prayer":
			var red := Color(0.82, 0.24, 0.18, a)
			ci.draw_rect(Rect2(p + Vector2(-4.5, -3.5) * k, Vector2(9, 1.6) * k), red)
			ci.draw_rect(Rect2(p + Vector2(-3, -3) * k, Vector2(1.4, 7) * k), red)
			ci.draw_rect(Rect2(p + Vector2(1.6, -3) * k, Vector2(1.4, 7) * k), red)
			ci.draw_rect(Rect2(p + Vector2(-3.5, -1) * k, Vector2(7, 1) * k), red)
		"repair":
			ci.draw_line(p + Vector2(-3, 3.5) * k, p + Vector2(2, -1.5) * k, Color(0.6, 0.42, 0.25, a), 1.6 * k)
			ci.draw_rect(Rect2(p + Vector2(0, -4) * k, Vector2(4, 2.6) * k), Color(0.75, 0.75, 0.8, a))
		"forage":
			ci.draw_line(p + Vector2(0, 4) * k, p + Vector2(0, -2) * k, Color(0.55, 0.42, 0.28, a), 1.4 * k)
			ci.draw_circle(p + Vector2(-2, -2.5) * k, 2.0 * k, Color(0.45, 0.7, 0.35, a))
			ci.draw_circle(p + Vector2(2, -3) * k, 2.0 * k, Color(0.45, 0.7, 0.35, a))
		"gate":
			ci.draw_rect(Rect2(p + Vector2(-2.5, -4.5) * k, Vector2(5, 9) * k), Color(0.96, 0.94, 0.88, a))
			ci.draw_rect(Rect2(p + Vector2(-0.6, -3.5) * k, Vector2(1.2, 7) * k), Color(0.75, 0.2, 0.15, a))
		"dice":
			ci.draw_rect(Rect2(p + Vector2(-3.5, -3.5) * k, Vector2(7, 7) * k), Color(0.97, 0.95, 0.9, a))
			for d in [Vector2(-1.6, -1.6), Vector2(1.6, 1.6), Vector2(0, 0)]:
				ci.draw_circle(p + d * k, 0.8 * k, Color(0.1, 0.1, 0.12, a))
		"ford":
			for i in 2:
				var yy := (-1.5 + i * 3.0) * k
				ci.draw_polyline(PackedVector2Array([p + Vector2(-4 * k, yy), p + Vector2(-2 * k, yy - 1.5 * k), p + Vector2(0, yy), p + Vector2(2 * k, yy - 1.5 * k), p + Vector2(4 * k, yy)]), Color(0.45, 0.72, 0.95, a), 1.2)
		"boat":
			poly(ci, [p + Vector2(-5, 0) * k, p + Vector2(5, 0) * k, p + Vector2(3, 3) * k, p + Vector2(-3, 3) * k], Color(0.6, 0.42, 0.25, a))
			ci.draw_line(p + Vector2(2, 0) * k, p + Vector2(-1, -5) * k, Color(0.93, 0.89, 0.81, a), 1.0)
		"bow":
			ci.draw_circle(p + Vector2(0, -2.5) * k, 1.8 * k, Color(0.93, 0.89, 0.81, a))
			ci.draw_line(p + Vector2(0, -1) * k, p + Vector2(3, 3) * k, Color(0.93, 0.89, 0.81, a), 1.6 * k)
		"staff":
			ci.draw_line(p + Vector2(-3.5, 4) * k, p + Vector2(3.5, -4) * k, Color(0.6, 0.42, 0.25, a), 1.6 * k)
			ci.draw_arc(p + Vector2(3.5, -4) * k, 1.5 * k, 0, TAU, 8, Color(0.85, 0.75, 0.45, a), 1.0)
		"fire":
			poly(ci, [p + Vector2(-3.5, 3) * k, p + Vector2(3.5, 3) * k, p + Vector2(0.5, -5) * k], Color(0.95, 0.5, 0.2, a))
			poly(ci, [p + Vector2(-1.5, 3) * k, p + Vector2(2, 3) * k, p + Vector2(0, -1) * k], Color(1.0, 0.85, 0.35, a))
		"roar":
			ci.draw_circle(p + Vector2(-2.5, 0) * k, 1.6 * k, Color(0.85, 0.3, 0.22, a))
			for i in 3:
				ci.draw_arc(p + Vector2(-2.5, 0) * k, (2.5 + i * 1.5) * k, -0.9, 0.9, 8, Color(1.0, 0.85, 0.6, a), 1.0)
		"spirit":
			ci.draw_circle(p + Vector2(0, -1) * k, 3.0 * k, Color(0.9, 0.95, 1.0, a))
			ci.draw_line(p + Vector2(0, 2) * k, p + Vector2(-2, 4.5) * k, Color(0.9, 0.95, 1.0, a), 1.2)
		"conch":
			poly(ci, [p + Vector2(-4.5, -1) * k, p + Vector2(2.5, -3.5) * k, p + Vector2(4.5, 1.5) * k, p + Vector2(-2, 3) * k], Color(0.94, 0.89, 0.8, a))
			ci.draw_circle(p + Vector2(3, -0.5) * k, 1.8 * k, Color(0.85, 0.53, 0.29, a))
		"goma":
			ci.draw_rect(Rect2(p + Vector2(-4, 2) * k, Vector2(8, 1.6) * k), Color(0.48, 0.33, 0.2, a))
			poly(ci, [p + Vector2(-3, 2) * k, p + Vector2(3, 2) * k, p + Vector2(0.5, -4.5) * k], Color(0.94, 0.54, 0.24, a))
			poly(ci, [p + Vector2(-1.4, 2) * k, p + Vector2(1.6, 2) * k, p + Vector2(0, -1.5) * k], Color(1.0, 0.84, 0.35, a))
		"wood":
			for i in 3:
				ci.draw_rect(Rect2(p + Vector2(-4, -3 + i * 2.2) * k, Vector2(8, 1.5) * k), Color(0.55, 0.4, 0.25, a) if i % 2 == 0 else Color(0.66, 0.5, 0.32, a))
		"sake":
			ci.draw_rect(Rect2(p + Vector2(-3, -3.5) * k, Vector2(6, 7) * k), Color(0.77, 0.54, 0.29, a))
			ci.draw_line(p + Vector2(-3, 0) * k, p + Vector2(3, 0) * k, Color(0.35, 0.23, 0.11, a), 1.0)
		"up":
			var c := Color(0.93, 0.89, 0.81, a)
			poly(ci, [p + Vector2(0, -4) * k, p + Vector2(3.5, 0) * k, p + Vector2(-3.5, 0) * k], c)
			ci.draw_rect(Rect2(p + Vector2(-1, 0) * k, Vector2(2, 3.5) * k), c)
		"down":
			var c2 := Color(0.93, 0.89, 0.81, a)
			poly(ci, [p + Vector2(0, 4) * k, p + Vector2(3.5, 0) * k, p + Vector2(-3.5, 0) * k], c2)
			ci.draw_rect(Rect2(p + Vector2(-1, -3.5) * k, Vector2(2, 3.5) * k), c2)


# ---------- props: boats, castles ----------
## A flat river boat, its left end at x and its waterline at y. A ferryman
## poles it from the stern, facing `face`. People aboard stand on its deck,
## at `boat_deck`.
static func boat(ci: CanvasItem, x: float, y: float, w: float, dk: float, t: float, ferryman: bool, face: float = -1.0) -> void:
	var yy := boat_deck(y, t) + 6.0
	poly(ci, [Vector2(x, yy - 6), Vector2(x + w, yy - 6), Vector2(x + w - 10, yy + 2), Vector2(x + 8, yy + 2)], shade(Color("#6b4a2b"), dk))
	ci.draw_rect(Rect2(x + 4, yy - 8, w - 8, 2), shade(Color("#8a6040"), dk))
	if ferryman:
		var fx := x + w * (0.5 - face * 0.2)
		person(ci, fx, yy - 6, face, {"robe": "#4a5a6a", "hat": "#b39a56"})
		ci.draw_line(Vector2(fx - face * 4, yy - 30), Vector2(fx + face * 6, yy + 6), shade(Color("#6b4a2b"), dk), 1.2)

static func boat_deck(y: float, t: float) -> float:
	return y + sin(t * 1.5) * 1.0 - 6.0

## A castle keep on the skyline, behind the town that serves it.
static func castle(ci: CanvasItem, x: float, base: float, dk: float) -> void:
	var wall := shade(Color("#e6e0d0"), dk + 0.15)
	var roof := shade(Color("#3a3c44"), dk + 0.15)
	var stone := shade(Color("#7b786f"), dk + 0.15)
	poly(ci, [Vector2(x - 70, base), Vector2(x + 70, base), Vector2(x + 52, base - 34), Vector2(x - 52, base - 34)], stone)
	var y := base - 34.0
	var ww := 84.0
	for tier in 4:
		ci.draw_rect(Rect2(x - ww / 2, y - 18, ww, 18), wall)
		poly(ci, [Vector2(x - ww / 2 - 10, y - 16), Vector2(x + ww / 2 + 10, y - 16), Vector2(x + ww / 2 - 6, y - 26), Vector2(x - ww / 2 + 6, y - 26)], roof)
		for k in int(ww / 16):
			ci.draw_rect(Rect2(x - ww / 2 + 6 + k * 16, y - 12, 5, 5), roof)
		y -= 26.0
		ww -= 16.0
	ci.draw_rect(Rect2(x - 4, y - 6, 8, 6), Color("#d9a441"))

## Rice paddies in front of a rural road: flooded squares catching the sky.
static func paddies(ci: CanvasItem, sx: float, w: float, base: float, dk: float) -> void:
	var x := sx
	while x < sx + w:
		ci.draw_rect(Rect2(x + 2, base + 2, 36, 18), shade(Color("#6f8a8e"), dk))
		for k in 5:
			ci.draw_line(Vector2(x + 6 + k * 7, base + 18), Vector2(x + 6 + k * 7, base + 8), shade(Color("#6f9a4a"), dk), 1.0)
		x += 40.0


# ---------- props: the well ----------
static func well(ci: CanvasItem, x: float, base: float, dk: float) -> void:
	var stone := shade(Color("#8a877e"), dk)
	var wood := shade(Color("#3b2a1f"), dk)
	ci.draw_rect(Rect2(x - 12, base - 12, 24, 14), stone)
	ci.draw_rect(Rect2(x - 12, base - 12, 24, 3), shade(Color("#9c998f"), dk))
	ci.draw_rect(Rect2(x - 11, base - 40, 2, 28), wood)
	ci.draw_rect(Rect2(x + 9, base - 40, 2, 28), wood)
	poly(ci, [Vector2(x - 16, base - 38), Vector2(x + 16, base - 38), Vector2(x + 10, base - 46), Vector2(x - 10, base - 46)], shade(Color("#5a4a36"), dk))
	ci.draw_line(Vector2(x, base - 38), Vector2(x, base - 22), Color(0.6, 0.55, 0.45), 1.0)
	ci.draw_rect(Rect2(x - 3, base - 22, 6, 5), wood)


# ---------- people and creatures ----------
static func shadow(ci: CanvasItem, x: float, y: float, w: float) -> void:
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x - w, y), Vector2(x, y - 2), Vector2(x + w, y), Vector2(x, y + 2)]), Color(0, 0, 0, 0.22))

static func reset(ci: CanvasItem) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A townsperson from a look, drawn by figure.gd: front view at rest, side view walking.
static func person(ci: CanvasItem, x: float, y: float, face: float, look: Dictionary, a: float = 1.0, walk: float = -1.0) -> void:
	var kind := "walk" if walk >= 0.0 else "stand"
	var view: String = "side" if walk >= 0.0 else look.get("view", "front")
	Figure.person(ci, Vector2(x, y), 1 if face >= 0 else -1, 40.0, look, view, kind, walk / 9.0 if walk >= 0.0 else 0.0, a)

## The monk facing `yaw` (see Figure.px): an act if one is playing, else a
## strike, a walk or standing.
## `sink` lowers him into water, as for the oni.
static func monk(ci: CanvasItem, x: float, y: float, yaw: float, moving: bool, t: float, curse: float, gourd: String, swing: float = 0.0, act: String = "", phase: float = 0.0, sink: float = 0.0) -> void:
	var kind := act
	if kind == "":
		kind = "strike" if swing > 0.0 else ("walk" if moving else "stand")
	if kind == "strike" and act == "":
		phase = swing
	Figure.monk(ci, Vector2(x, y + sink), yaw, 44.0, kind, t, phase, curse, gourd, 1.0, sink <= 0.5)

## The oni at (x, y), drawn `sink` pixels lower when he stands in water; the
## view paints the water back over what is under it.
static func oni(ci: CanvasItem, x: float, y: float, o: Dictionary, t: float, hidden: bool, sink: float = 0.0) -> void:
	var s: float = o.scale
	var kind: String = o.get("anim", "")
	var phase := 0.0
	if kind == "":
		if o.swing > 0:
			kind = "strike"
			phase = 1.0 - o.swing / 0.25
		elif o.get("roaring", 0.0) > 0.0:
			kind = "roar"
		else:
			kind = "walk" if o.get("moving", false) else "stand"
	var tilt: float = sin(t * 2.3) * 0.07 if o.drunk > 0 else 0.0
	var yaw: float = o.get("yaw", 0.0 if o.face >= 0 else 180.0)
	# hidden: in the shadow of its hiding place, not see-through
	Figure.gloom = 0.6 if hidden else 0.0
	Figure.oni(ci, Vector2(x, y + sink), yaw, 64.0 * s, kind, t, phase, 1.0, o.flash > 0, tilt, sink <= 0.5)
	Figure.gloom = 0.0

## The watch: a patrol carries a lantern; a raised alarm turns it into a hunter with a spear.
static func watchman(ci: CanvasItem, w: Dictionary, x: float, font: Font) -> void:
	var look := _watch_look(w)
	look["view"] = "side"
	var t: float = w.x / 9.0 * 0.35
	if w.down:
		Figure.person(ci, Vector2(x, w.y), w.face, 40.0, look, "side", "down", 0.0, maxf(0.0, 1.0 - w.down_t / 3.0))
		return
	var kind := "strike" if w.atk > 0 else ("stand" if w.get("stun", 0.0) > 0.0 else "walk")
	Figure.person(ci, Vector2(x, w.y), w.face, 40.0, look, "side", kind, t)
	if w.type == "watch":
		ci.draw_string(font, Vector2(x - 3, w.y - 46), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffd65a"))
	elif w.get("heard", false):
		ci.draw_string(font, Vector2(x - 3, w.y - 46), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ece3cf"))

static func _watch_look(w: Dictionary) -> Dictionary:
	if w.type == "exorcist":
		return {"robe": "#e9e3d3", "hat": "#1b1b22", "sash": "#a8322a", "item": "talisman"}
	# the alarm raised, or a guard by day: a spear instead of a lantern
	if w.type == "watch" or not w.get("lantern", true):
		return {"robe": "#2e3f63", "hat": "#3a3226", "item": "spear"}
	return {"robe": "#2e3f63", "hat": "#3a3226", "item": "lantern"}

## The lantern's pool of light. What a patrol can see is exactly this pool.
static func light_pool(ci: CanvasItem, cx: float, y: float, rx: float, ry: float) -> void:
	for k in 3:
		var f := 1.0 - k * 0.28
		var pts := PackedVector2Array()
		for i in 24:
			var ang := TAU * i / 24.0
			pts.append(Vector2(cx + cos(ang) * rx * f, y + sin(ang) * ry * f))
		ci.draw_colored_polygon(pts, Color(1.0, 0.8, 0.45, 0.07))

## How fast the monk walks for his stamina: full pace above 40, slowing
## smoothly to a crawl (a quarter of his pace) at nothing. Hunger never stops
## him; only the day's end does.
static func monk_pace(stamina: float) -> float:
	return 0.25 + 0.75 * smoothstep(0.0, 40.0, stamina)

## How fast a starving oni still moves: the body's strength (the monk's
## stamina, 0-100) slows it below half, down to a third of its pace.
static func oni_pace(hp: float) -> float:
	return 0.35 + 0.65 * clampf(hp / 50.0, 0.0, 1.0)

## The hunt's clock, for the views' headings: which day or night of it this is,
## what comes next and when, and how far behind the master exorcist is.
static func hunt_when() -> String:
	var n := GameState.hunt_phase / 2 + 1
	return ("day %d of the hunt" if GameState.daylight else "night %d of the hunt") % n

static func phase_left(t: float) -> String:
	var s := maxi(0, int(ceil(t)))
	if not GameState.hunt:
		return "Dawn in %ds" % s
	return ("Dusk in %ds" if GameState.daylight else "Day in %ds") % s

static func master_line() -> String:
	var due := GameState.master_due - GameState.hunt_phase
	if due <= 0:
		return "The master exorcist is close"
	return "The master exorcist: %d %s behind" % [due, "phase" if due == 1 else "phases"]

## Any of the minor yokai by kind.
static func creature(ci: CanvasItem, kind: String, f: Dictionary, x: float, t: float) -> void:
	match kind:
		"gaki":
			gaki(ci, f, x, t)
		"kappa":
			kappa(ci, f, x, t)
		"tengu":
			tengu(ci, f, x, t)
		"kitsune":
			kitsune(ci, f, x, t)
		"kasa":
			kasa(ci, f, x, t)
		_:
			onibi(ci, f, x, t)

## A hungry ghost: emaciated, pale, swollen belly. Minor demon of the trails.
static func gaki(ci: CanvasItem, f: Dictionary, x: float, t: float) -> void:
	var a: float = f.get("fade", 1.0)
	shadow(ci, x, f.y, 7)
	ci.draw_set_transform(Vector2(x, f.y), 0.0, Vector2(f.face, 1))
	var skin := Color(0.78, 0.8, 0.72, a) if f.flash <= 0 else Color(1, 1, 1, a)
	ci.draw_line(Vector2(-2, 0), Vector2(-3, -9), skin, 1.5)
	ci.draw_line(Vector2(2, 0), Vector2(3, -9), skin, 1.5)
	ci.draw_circle(Vector2(0, -12), 5.5, skin)
	poly(ci, [Vector2(-3, -15), Vector2(3, -15), Vector2(2, -24), Vector2(-2, -24)], skin)
	var reach := 4.0 + (6.0 if f.get("atk", 0.0) > 0 else 0.0)
	ci.draw_line(Vector2(1, -22), Vector2(reach + 4, -16 + sin(t * 6.0)), skin, 1.2)
	ci.draw_circle(Vector2(0, -28), 4, skin)
	ci.draw_rect(Rect2(1, -29, 2, 1.5), Color(0.1, 0.1, 0.1, a))
	ci.draw_line(Vector2(-4, -31), Vector2(-5, -24), Color(0.2, 0.2, 0.22, a), 1.0)
	reset(ci)

## A kappa: river imp with a shell and a water-filled dish on its head.
static func kappa(ci: CanvasItem, f: Dictionary, x: float, t: float) -> void:
	var a: float = f.get("fade", 1.0)
	shadow(ci, x, f.y, 8)
	ci.draw_set_transform(Vector2(x, f.y), 0.0, Vector2(f.face, 1))
	var skin := Color(0.38, 0.58, 0.36, a) if f.flash <= 0 else Color(1, 1, 1, a)
	var hop := absf(sin(t * 5.0 + f.seed)) * 3.0
	ci.draw_rect(Rect2(-4, -6 - hop, 3, 6), skin)
	ci.draw_rect(Rect2(1, -6 - hop, 3, 6), skin)
	ci.draw_circle(Vector2(-3, -13 - hop), 6.5, Color(0.36, 0.3, 0.2, a))
	ci.draw_circle(Vector2(1, -13 - hop), 5.5, skin)
	ci.draw_circle(Vector2(1, -22 - hop), 4.5, skin)
	poly(ci, [Vector2(4, -22 - hop), Vector2(8, -21 - hop), Vector2(4, -20 - hop)], Color(0.85, 0.7, 0.3, a))
	ci.draw_rect(Rect2(-3, -27 - hop, 8, 2), Color(0.75, 0.85, 0.9, a))
	ci.draw_rect(Rect2(2, -23 - hop, 1.5, 1.5), Color(0.1, 0.1, 0.1, a))
	reset(ci)

## A karasu-tengu: crow-headed mountain goblin, wings beating, hovering.
static func tengu(ci: CanvasItem, f: Dictionary, x: float, t: float) -> void:
	var a: float = f.get("fade", 1.0)
	var lift := 16.0 + sin(t * 4.0 + f.seed) * 4.0 - (10.0 if f.get("atk", 0.0) > 0 else 0.0)
	shadow(ci, x, f.y, 6)
	ci.draw_set_transform(Vector2(x, f.y - lift), 0.0, Vector2(f.face, 1))
	var robe := Color(0.18, 0.22, 0.36, a) if f.flash <= 0 else Color(1, 1, 1, a)
	var black := Color(0.1, 0.1, 0.12, a)
	var flap := sin(t * 14.0 + f.seed) * 6.0
	poly(ci, [Vector2(-2, -18), Vector2(-16, -24 + flap), Vector2(-12, -12)], black)
	poly(ci, [Vector2(2, -18), Vector2(-6, -30 + flap), Vector2(-4, -12)], Color(0.15, 0.15, 0.18, a))
	poly(ci, [Vector2(-5, -4), Vector2(5, -4), Vector2(4, -20), Vector2(-4, -20)], robe)
	ci.draw_line(Vector2(-2, -4), Vector2(-3, 2), black, 1.5)
	ci.draw_line(Vector2(2, -4), Vector2(3, 2), black, 1.5)
	ci.draw_circle(Vector2(0, -24), 4.2, black)
	poly(ci, [Vector2(3, -26), Vector2(10, -23), Vector2(3, -21)], Color(0.85, 0.7, 0.25, a))
	ci.draw_rect(Rect2(1, -26, 1.5, 1.5), Color(1.0, 0.8, 0.3, a))
	ci.draw_rect(Rect2(-3, -29, 5, 2), Color(0.1, 0.1, 0.12, a))
	reset(ci)

## A kitsune: a white fox on its hind legs, several tails fanned behind.
static func kitsune(ci: CanvasItem, f: Dictionary, x: float, t: float) -> void:
	var a: float = f.get("fade", 1.0) * (0.35 if f.get("blink", 0.0) > 0.0 else 1.0)
	shadow(ci, x, f.y, 7)
	ci.draw_set_transform(Vector2(x, f.y), 0.0, Vector2(f.face, 1))
	var fur := Color(0.95, 0.93, 0.88, a) if f.flash <= 0 else Color(1, 0.85, 0.7, a)
	for k in 3:
		var ang := -0.9 - k * 0.35 + sin(t * 3.0 + k) * 0.08
		var tip := Vector2(-4, -10) + Vector2(cos(ang + PI), sin(ang + PI) * -1.0) * 14.0
		poly(ci, [Vector2(-3, -12), Vector2(-5, -8), tip], fur)
		ci.draw_circle(tip, 2.0, Color(0.9, 0.55, 0.3, a))
	ci.draw_line(Vector2(-1, -6), Vector2(-2, 0), fur, 2.0)
	ci.draw_line(Vector2(2, -6), Vector2(3, 0), fur, 2.0)
	poly(ci, [Vector2(-4, -6), Vector2(4, -6), Vector2(3, -18), Vector2(-3, -18)], fur)
	ci.draw_circle(Vector2(1, -21), 3.8, fur)
	poly(ci, [Vector2(3, -22), Vector2(9, -20), Vector2(3, -19)], fur)
	poly(ci, [Vector2(-2, -24), Vector2(-1, -29), Vector2(1, -24)], fur)
	poly(ci, [Vector2(1, -24), Vector2(3, -29), Vector2(4, -23)], fur)
	ci.draw_line(Vector2(2, -22), Vector2(4, -21.5), Color(0.8, 0.2, 0.15, a), 1.0)
	reset(ci)

## A kasa-obake: an old paper umbrella come alive, one eye, one leg, a long tongue.
static func kasa(ci: CanvasItem, f: Dictionary, x: float, t: float) -> void:
	var a: float = f.get("fade", 1.0)
	var hop := absf(sin(t * 6.0 + f.seed)) * 6.0
	shadow(ci, x, f.y, 6)
	ci.draw_set_transform(Vector2(x, f.y - hop), 0.0, Vector2(f.face, 1))
	var paper := Color(0.82, 0.35, 0.28, a) if f.flash <= 0 else Color(1, 1, 1, a)
	ci.draw_line(Vector2(0, 0), Vector2(0, -8), Color(0.85, 0.72, 0.55, a), 1.6)
	poly(ci, [Vector2(-10, -8), Vector2(10, -8), Vector2(0, -26)], paper)
	for k in 3:
		ci.draw_line(Vector2(0, -26), Vector2(-8 + k * 8, -8), Color(0.55, 0.22, 0.18, a), 0.8)
	ci.draw_circle(Vector2(1, -15), 2.6, Color(1, 1, 1, a))
	ci.draw_circle(Vector2(1.5, -15), 1.2, Color(0.1, 0.1, 0.1, a))
	ci.draw_line(Vector2(2, -11), Vector2(5 + (4.0 if f.get("atk", 0.0) > 0 else 0.0), -8), Color(0.8, 0.2, 0.25, a), 1.4)
	reset(ci)

## A defeated demon's spirit, waiting to be freed or bound.
static func wisp(ci: CanvasItem, x: float, y: float, kind: String, t: float) -> void:
	var c := Color(0.9, 0.95, 1.0) if kind != "onibi" else Color(0.55, 0.85, 1.0)
	if kind == "kappa":
		c = Color(0.6, 0.9, 0.7)
	elif kind == "kitsune":
		c = Color(1.0, 0.8, 0.55)
	elif kind == "tengu":
		c = Color(0.7, 0.75, 1.0)
	elif kind == "kasa":
		c = Color(1.0, 0.7, 0.7)
	var yy := y - 18.0 + sin(t * 3.0) * 3.0
	ci.draw_circle(Vector2(x, yy), 9, Color(c, 0.18))
	ci.draw_circle(Vector2(x, yy), 4, Color(c, 0.8))
	ci.draw_polyline(PackedVector2Array([Vector2(x, yy + 4), Vector2(x - 3, yy + 9), Vector2(x + 2, yy + 13)]), Color(c, 0.6), 1.5)

## An ofuda: a paper talisman in flight.
static func ofuda(ci: CanvasItem, x: float, y: float, t: float) -> void:
	ci.draw_set_transform(Vector2(x, y), sin(t * 20.0) * 0.4, Vector2.ONE)
	ci.draw_rect(Rect2(-2.5, -5, 5, 10), Color("#f4efe2"))
	ci.draw_rect(Rect2(-0.6, -4, 1.2, 8), Color("#b0372c"))
	reset(ci)

## A will-o'-the-wisp of demon fire.
static func onibi(ci: CanvasItem, f: Dictionary, x: float, t: float) -> void:
	var a: float = f.get("fade", 1.0)
	var y: float = f.y - 22 + sin(t * 3.0 + f.seed) * 5.0
	shadow(ci, x, f.y, 5)
	ci.draw_circle(Vector2(x, y), 10, Color(0.45, 0.75, 1.0, 0.15 * a))
	var c := Color(0.55, 0.85, 1.0, a) if f.flash <= 0 else Color(1, 1, 1, a)
	poly(ci, [Vector2(x - 5, y + 3), Vector2(x + 5, y + 3), Vector2(x + sin(t * 8.0) * 2.0, y - 10)], c)
	ci.draw_circle(Vector2(x, y + 1), 4.5, c)
	ci.draw_circle(Vector2(x, y + 1), 2.0, Color(1, 1, 1, a))
