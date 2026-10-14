extends Node2D
## The last climb: stone steps under a row of torii up to the temple at the
## peak. Dusk turns to night as you climb; it is the new moon, and there is no
## moon. Arriving before the new moon, you wait inside the temple's wards: the
## oni stays sealed, but the seal still weakens night by night.

const Stations := preload("res://scripts/stations.gd")
const Kit := preload("res://scripts/kit.gd")
const MonkActs := preload("res://scripts/monk_acts.gd")
const W := 480.0
const H := 270.0
const BACK := 192.0
const Y_MIN := 200.0
const Y_MAX := 258.0
const PAPER := Color("#ece3cf")

var main: Node
var area := {}
var buildings: Array = []
var slope: Array = []
var world_w := 900.0
var monk := {"x": 20.0, "y": 230.0, "face": 1, "moving": false}
var t := 0.0
var font: Font
var waited := 0
var _cam := 0.0
var acts: MonkActs


func setup(main_node: Node) -> void:
	main = main_node
	acts = MonkActs.new(main, monk)
	area = Stations.PEAK
	world_w = float(area.width)
	slope = area.get("slope", [[0, 0]])
	for src in area.buildings:
		var b: Dictionary = src.duplicate()
		b.hp = 100.0
		b.pantry = 0
		b.barrels = 0
		buildings.append(b)
	# nights still to pass before the new moon are spent waiting in the temple
	waited = maxi(0, GameState.nights_left)
	for i in waited:
		GameState.add_curse(GameState.NIGHTLY_CURSE)
	GameState.nights_left = 0


func _ready() -> void:
	font = ThemeDB.fallback_font
	if waited > 0:
		main.toast("You arrive early and wait %d %s within the temple's wards. The seal still weakens." % [waited, "night" if waited == 1 else "nights"])
	else:
		main.toast("The mountain temple. Tonight is the new moon.")


func elev(x: float) -> float:
	for i in range(1, slope.size()):
		var a: Array = slope[i - 1]
		var b: Array = slope[i]
		if x <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), clampf((x - float(a[0])) / maxf(1.0, float(b[0]) - float(a[0])), 0.0, 1.0))
	return float(slope[-1][1])

func lift(x: float) -> float:
	return elev(x) - elev(_cam + W / 2.0)

func _near_hall() -> bool:
	var b: Dictionary = buildings[0]
	return monk.x > b.x + 20 and monk.y < Y_MIN + 24.0

func _near_falls() -> bool:
	for p in area.props:
		if p.kind == "waterfall" and absf(p.x - monk.x) < 22.0 and monk.y < Y_MIN + 22.0:
			return true
	return false

func act_label() -> String:
	return "Rite" if _near_hall() else ("Takigyo" if _near_falls() else "Act")

func legend() -> Dictionary:
	return {"I": "Begin the rite" if _near_hall() else ("Takigyo" if _near_falls() else ""), "U": "Gourd", "O": "Pipe"}

func pipe_label() -> String:
	return "Smoke"


func _process(delta: float) -> void:
	t += delta
	if not GameState.paused and not GameState.ended:
		acts.tick(delta)
		var dx := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
		var dy := int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
		if acts.busy():
			dx = 0
			dy = 0
		acts.turn(dx, dy, delta)
		monk.moving = dx != 0 or dy != 0
		if dx != 0:
			monk.face = dx
		var g := (elev(monk.x + 4.0) - elev(monk.x - 4.0)) / 8.0
		var up := maxf(0.0, g * dx)
		monk.x = clampf(monk.x + dx * 50.0 * Kit.monk_pace(GameState.stamina) / (1.0 + up * 3.0) * delta, 10.0, world_w - 10.0)
		monk.y = clampf(monk.y + dy * 35.0 * delta, Y_MIN, Y_MAX)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.paused or GameState.ended or event.is_echo() or GameState.input_blocked() or acts.busy():
		return
	if event.is_action_pressed("act") and _near_hall():
		main.reach_peak()
	elif event.is_action_pressed("act") and _near_falls():
		main.open_modal("The falls", "The last falls below the temple. Pilgrims stand under them before the rite.", [acts.taki_option("peak"), {"label": "Walk on"}])
	elif event.is_action_pressed("pipe"):
		acts.smoke()
	elif event.is_action_pressed("gourd"):
		acts.gourd()


# ---------- sound ----------
func screen_x(x: float) -> float:
	return x - _cam

func music() -> Dictionary:
	return {"tune": "trail", "tension": 0.0}

## Wind on the mountain, the falls as near as they are.
func ambience() -> Dictionary:
	var mid := _cam + W / 2.0
	var water := 0.0
	for p in area.props:
		if p.kind == "waterfall":
			water = maxf(water, 1.0 - absf(p.x - mid) / 350.0)
	return {"wind": 0.8, "water": clampf(water, 0.0, 1.0)}

func _draw() -> void:
	_cam = clampf(monk.x - W / 2.0, 0.0, maxf(0.0, world_w - W))
	var cam := _cam
	var here := elev(cam + W / 2.0)
	var climb := clampf(monk.x / (world_w * 0.8), 0.0, 1.0)
	var night := climb > 0.55
	var dk := Kit.sky(self, cam, night, 15.0 + climb * 3.0, 0.0, area.backdrop, BACK + clampf(here * 0.35, 0.0, 50.0), t)
	Kit.terrain(self, cam, BACK, dk, area.ground, lift)
	for p in area.props:
		var sx: float = p.x - cam
		if sx < -60 or sx > W + 60:
			continue
		var by: float = BACK - lift(p.x)
		match p.kind:
			"cedar":
				Kit.cedar(self, sx, by + 2, p.get("h", 60.0), dk)
			"torii":
				Kit.torii(self, sx, by, p.get("h", 50.0), dk, 10.0)
			"stone_lantern":
				Kit.stone_lantern(self, sx, by + 2, dk, night)
			"waterfall":
				Kit.waterfall(self, sx, by + 4, p.get("h", 64.0), dk, t)
	for b in buildings:
		Kit.building(self, b, b.x - cam, BACK - lift(b.x + b.w / 2.0), night, true)
	var my: float = monk.y - lift(monk.x)
	acts.draw(self, monk.x - cam, my, t)
	if night:
		draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.04, 0.12, 0.25))
	if _near_hall():
		Kit.icon(self, "prayer", Vector2(monk.x - cam, my - 54), true)
	elif _near_falls():
		Kit.icon(self, "water", Vector2(monk.x - cam, my - 54), true)
	draw_string(font, Vector2(8, 16), "The mountain temple, new moon", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PAPER)
	draw_string(font, Vector2(0, 16), "Curse %d: the deeper, the stronger the oni" % int(GameState.curse), HORIZONTAL_ALIGNMENT_RIGHT, W - 8, 12, PAPER)
	draw_string(font, Vector2(0, H - 3), "v" + GameState.VERSION, HORIZONTAL_ALIGNMENT_RIGHT, W - 3, 8, Color(PAPER, 0.4))
