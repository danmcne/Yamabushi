extends RefCounted
## What the monk does with his own kit by day, the same in every view: the
## gourd, the pipe, the conch, the falls. Each act holds him in a pose for a
## few real seconds (`anim`), during which he stands still; the hours an act
## costs pass on the clock at once.
##
## Each view keeps one of these beside its `monk` dictionary and draws him
## through `draw`.

const Kit := preload("res://scripts/kit.gd")
const Figure := preload("res://scripts/figure.gd")

const CONCH_CD := 12.0        # seconds before the conch can sound again
const CONCH_STAMINA := 3.0
const CONCH_REACH := 150.0    # minor yokai within this are stunned
const CONCH_STUN := 2.0
const TAKI_STAMINA := 25.0    # standing under the falls: cost, minimum, and merit
const TAKI_MIN := 30.0
const TAKI_CURSE := 10.0

var main: Node
var monk: Dictionary
var conch_cd := 0.0


func _init(main_node: Node, monk_dict: Dictionary) -> void:
	main = main_node
	monk = monk_dict


## Hold him in a pose for `secs`; `facing` turns him to a yaw for it (back
## to the viewer to pray at a shrine, toward the viewer under the falls).
func play(kind: String, secs: float, facing := NAN) -> void:
	# what goes to the mouth is done side-on, so it is never hidden behind the head
	if is_nan(facing) and kind in ["drink", "smoke", "conch"]:
		facing = 0.0 if monk.face > 0 else 180.0
	monk.anim = kind
	monk.anim_t = secs
	monk.anim_len = secs
	monk.anim_yaw = facing

## Turn him as he moves by (dx, dy), to the pose's yaw while one plays, and
## side-on while he strikes.
func turn(dx: float, dy: float, dt: float, striking := false) -> void:
	var hold: float = NAN
	if busy():
		hold = monk.get("anim_yaw", NAN)
	elif striking:
		hold = 0.0 if monk.face > 0 else 180.0
	Figure.turn(monk, dx, dy, dt, hold)

func busy() -> bool:
	return monk.get("anim_t", 0.0) > 0.0

## Break off whatever pose he holds (a blow lands, say). Effects already spent stay spent.
func interrupt() -> void:
	monk.anim_t = 0.0
	monk.anim = ""

func tick(dt: float) -> void:
	conch_cd = maxf(0.0, conch_cd - dt)
	if busy():
		monk.anim_t -= dt
		monk.moving = false
		if monk.anim_t <= 0.0:
			interrupt()

func draw(ci: CanvasItem, x: float, y: float, t: float, swing: float = 0.0, sink: float = 0.0) -> void:
	var kind: String = monk.get("anim", "")
	var phase := 0.0
	if kind != "":
		phase = 1.0 - monk.anim_t / maxf(0.01, monk.anim_len)
	Kit.monk(ci, x, y, monk.get("yaw", 0.0 if monk.face > 0 else 180.0), monk.moving, t, GameState.curse, GameState.gourd, swing, kind, phase, sink)


# ---------- the gourd ----------
func gourd() -> void:
	if GameState.gourd == "sake":
		main.open_modal("The gourd", "It was water when you filled it. It is sake now.", [
			{"label": "Drink the sake", "sub": "+60 stamina. Breaks the vow against intoxicants", "vice": true, "icon": "sake", "run": _drink_sake},
			{"label": "Pour it out", "sub": "Refill it with water at a river or well", "run": _pour},
			{"label": "Leave it for now"},
		])
	elif GameState.gourd == "water" and GameState.sips > 0:
		var before := GameState.sips
		main.toast(GameState.drink_water())
		if GameState.sips < before:
			play("drink", 1.2)
			GameState.event("water")
	else:
		main.toast("The gourd is empty. Refill it at a river or well.")

func _drink_sake() -> void:
	play("drink", 1.6)
	GameState.event("sake")
	main.toast(GameState.drink_sake())

func _pour() -> void:
	GameState.gourd = "empty"
	main.toast("The ground drinks it instead.")


# ---------- the pipe ----------
func smoke() -> void:
	play("smoke", 2.5)
	GameState.event("smoke")
	GameState.advance(0.5)
	GameState.gain_stamina(5)
	main.toast("You smoke a pipe. A small lapse for an ascetic.")
	GameState.add_curse(2)


# ---------- the conch ----------
## Sound the horagai. Returns true if it sounded; the view decides who hears it.
func conch() -> bool:
	if conch_cd > 0.0:
		main.toast("You are still short of breath (%ds)." % int(ceil(conch_cd)))
		return false
	if GameState.stamina < CONCH_STAMINA + 1.0:
		main.toast("Too weak to sound the conch.")
		return false
	conch_cd = CONCH_CD
	GameState.stamina -= CONCH_STAMINA
	play("conch", 1.4)
	return true

func conch_label() -> String:
	return "Conch" if conch_cd <= 0.0 else "Conch %ds" % int(ceil(conch_cd))


# ---------- the falls ----------
## Takigyo, the waterfall austerity: once at each fall.
func taki_option(key: String) -> Dictionary:
	var done: bool = GameState.flags.get("taki:" + key, false)
	var sub := "An hour under the falls: -%d stamina, the curse eases by %d" % [int(TAKI_STAMINA), int(TAKI_CURSE)]
	if done:
		sub = "You have already stood under these falls"
	elif GameState.stamina < TAKI_MIN:
		sub = "Too weak: the cold would stop your heart"
	return {"label": "Stand under the falls (takigyo)", "sub": sub, "icon": "water",
		"disabled": done or GameState.stamina < TAKI_MIN, "run": _taki.bind(key)}

func _taki(key: String) -> void:
	GameState.flags["taki:" + key] = true
	GameState.advance(1.0)
	GameState.stamina = maxf(0.0, GameState.stamina - TAKI_STAMINA)
	play("taki", 4.0, 90.0)
	GameState.event("takigyo")
	main.toast("The water hammers the thoughts out of you, then the cold, then the oni's voice.")
	GameState.add_curse(-TAKI_CURSE)
