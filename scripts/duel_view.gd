extends Node2D
## The final standoffs, fought on the Shikigami engine (game/, vendored).
##
##   "rite"  At the temple on the new moon the yamabushi faces his own oni
##           (Shuten-doji's kit). Win, and the oni is cast out. The yamabushi
##           is built here on En no Gyoja's kit with the road's own specials:
##           the thrown ofuda (special) and the horagai (away + special). He
##           has no heal.
##   "hunt"  If the rite fails, or the curse consumes him on the road, the oni
##           has the body for good and roams the road (see the hunt in
##           game_state.gd). The master exorcist (Abe no Seimei's kit) catches up
##           with it wherever it is, and you play the oni. Throw him off and the
##           hunt goes on, but he comes back: tougher and sharper each time.
##
## Both fighters keep their full base movesets. The run only tilts them: the
## oni's curse and appetites make it tougher and harder-hitting, the monk's
## condition on arrival and the spirits he freed shade his strength, and the
## shikigami he bound on the trails come with him as spirits to summon. The
## yokai the oni bound on night trails come with the oni (Yamabushi's one
## change to the engine lets it bind them: see game/VENDORED.md).
##
## The keys match the road's: J is the staff (or kanabo), the heavy blow, and
## I the light one; the player's fighter has its light and heavy moves
## exchanged, so that guard stays where Shikigami puts it, J+L.

const Roster := preload("res://game/fighters/roster.gd")
const Kit := preload("res://scripts/kit.gd")
const Stations := preload("res://scripts/stations.gd")
const DuelFigures := preload("res://scripts/duel_figures.gd")
const BACK := 192.0
const W := 480.0
const H := 270.0
const PAPER := Color("#ece3cf")
## The Shikigami view is laid out at 1280 x 720; Yamabushi's is 480 x 270.
const STAGE_SCALE := 480.0 / 1280.0
## Difficulty -> the Shikigami computer level (Practice, Easy, Normal, Hard).
const CPU_LEVEL := [0, 1, 2]
## The conch's call: a wave of sound that stuns long and hurts little. A
## normal guard takes the edge off it rather than stopping it: the engine
## blocks it outright (with half the stun, as blockstun), and the duel view
## adds back half its damage. It cannot finish a fighter on its own.
const CONCH := {id = &"conch", startup = 16, active = 1, recovery = 22, cooldown = 240,
	spawn_offset = Vector2(50, -125),
	spawn = {id = &"conch_call", startup = 0, active = 26, recovery = 0, motion = Vector2(9, 0),
		damage = 30, hitstun = 50, blockstun = 25, knockback = 2.0, hitstop = 4,
		hitboxes = [Rect2(-16, -150, 32, 150)]}}
const CONCH_GUARDED := 0.5
## The ofuda, as thrown on the road: a paper talisman that flies straight.
const OFUDA := {id = &"ofuda", startup = 10, active = 1, recovery = 20, cooldown = 60,
	spawn_offset = Vector2(45, -115),
	spawn = {id = &"ofuda_paper", startup = 0, active = 90, recovery = 0, motion = Vector2(8, 0),
		damage = 50, hitstun = 16, blockstun = 12, knockback = 5.0, hitstop = 5,
		hitboxes = [Rect2(-12, -18, 24, 36)]}}
## Which roster yokai a trail shikigami fights as, and the special it brings.
const SPIRIT_SOURCE := {"kappa": [&"kappa", &"water_jet"], "onibi": [&"kitsune", &"bewitching_dust"], "gaki": [&"rokurokubi", &""],
	"tengu": [&"tengu", &"gale_fan"], "kitsune": [&"kitsune", &"fox_step"], "kasa": [&"tanuki", &""]}


## Shikigami's bout view, less its seashore backdrop: the standoff is staged
## on the mountain, drawn by the duel view behind this layer in the journey's
## own style. Otherwise this follows BoutView.draw step for step.
class Stage extends Node2D:
	var bout: Bout
	var names: Array[String] = []
	var colourways := [0, 0]   # Shikigami's trails and effects in their first (tori) colours
	func _draw() -> void:
		if bout == null:
			return
		var base := Transform2D(0.0, BoutView.ORIGIN)
		draw_set_transform(BoutView.ORIGIN)
		for i in 2:
			var f := bout.fighters[i]
			if Puppet.has_puppet(f):
				BoutView._trail(self, f, colourways[i], true)
				DuelFigures.draw_fighter(self, f, base, GameState.curse, GameState.gourd, 1.0, bout.phase in [Bout.Phase.ROUND_OVER, Bout.Phase.BOUT_OVER])
				BoutView._trail(self, f, colourways[i], false)
				Pieces.draw_effect(self, f, base)
				BoutView._labels(self, f, false)
			else:
				BoutView._fighter(self, f, BoutView.COLORS[i], false)
		for sp in bout.spirits:
			if Puppet.has_puppet(sp):
				DuelFigures.draw_fighter(self, sp, base, GameState.curse, GameState.gourd, 0.45)
			else:
				BoutView._fighter(self, sp, Color(BoutView.COLORS[sp.summoner].lightened(0.5), 0.4), false)
		for e in bout.entities:
			# a spirit's piece is its own, ghostly as the spirit is; Shikigami
			# draws a tethered piece from the summoner, which made the oni's
			# long-necked shikigami stretch out the oni's own neck and head
			var ghost := _spirit_of(e)
			if e.move.tethered and e.from_spirit and ghost == null:
				continue   # its spirit is already gone
			if e.move.tethered:
				var owner: Fighter = ghost if ghost != null else bout.fighters[e.owner_index]
				var skin := BoutView.COLORS[e.owner_index].lightened(0.2)
				var rig := BoutView.PuppetsRegistry.for_id(owner.definition.id)
				var neck := owner.hurtbox().get_center()
				if rig:
					skin = rig.colourways[0 if ghost != null else colourways[e.owner_index]].get("skin", skin)
					neck = Puppet.world_point(owner, "head", Vector2.ZERO)
				if ghost != null:
					skin.a = GHOST
				var line := PackedVector2Array([neck])
				line.append_array(e._path)
				line.append(e.position + Vector2(0, 12))
				draw_polyline(line, skin, 7.0)
				if ghost != null and e.move.id == &"flying_head":
					_ghost_head(e, ghost)
					continue
			if e.frame < e.move.startup:
				for local in e.move.hitboxes:
					var box := MoveDefinition.place(local, e.position, e.facing)
					var urgency := float(e.frame) / maxf(e.move.startup, 1.0)
					draw_rect(box, Color(1.0, 0.2, 0.2, 0.08 + 0.2 * urgency))
					draw_rect(Rect2(box.position.x, -4, box.size.x, 4), Color(1.0, 0.3, 0.2, 0.8))
			if e.move.motion.y > 0.0 and e.position.y < -20.0:
				for box in e.active_hitboxes():
					draw_rect(Rect2(box.position.x, -6, box.size.x, 6), Color(0, 0, 0, 0.45))
			if e.move.id == &"conch_call":
				_waves(e)
				continue
			if e.move.id == &"ofuda_paper":
				_paper(e)
				continue
			if Pieces.draw(self, bout, e, base, colourways):
				continue
			var drawn := e.boxes() if e.returning else e.active_hitboxes()
			for box in drawn:
				draw_rect(box, BoutView.COLORS[e.owner_index].lightened(0.4))
				draw_rect(box, Color.WHITE, false, 2.0)
		draw_set_transform(Vector2.ZERO)
		BoutView._hud(self, bout, names)

	const GHOST := 0.45   # how much of a summoned spirit shows

	## The summoned spirit that sent piece `e`, if a spirit sent it.
	func _spirit_of(e: Entity) -> Fighter:
		if not e.from_spirit:
			return null
		for sp in bout.spirits:
			if sp.summoner == e.owner_index:
				return sp
		return null

	## A spirit's flying head: its own face and hair, as faint as the rest of it.
	func _ghost_head(e: Entity, sp: Fighter) -> void:
		var rig := BoutView.PuppetsRegistry.for_id(sp.definition.id)
		var col: Dictionary = rig.colourways[0] if rig else {}
		var skin: Color = col.get("skin", Color("#e9dcc8"))
		var hair: Color = col.get("hair", Color("#1b1b22"))
		skin.a = GHOST
		hair.a = GHOST
		var c := e.position
		draw_circle(c, 17.0, skin)
		draw_arc(c, 17.0, PI * 1.05, PI * 1.95, 16, hair, 9.0)
		draw_rect(Rect2(c.x - e.facing * 17.0 - 5.0, c.y - 8.0, 10.0, 34.0), hair)
		for k in [-1.0, 1.0]:
			draw_circle(c + Vector2(e.facing * 6.0 + k * 5.0, -2.0), 1.8, Color(0.1, 0.1, 0.12, GHOST))

	## The conch's call: arcs of sound spreading ahead, no box.
	func _waves(e: Entity) -> void:
		var c := e.position + Vector2(-e.facing * 30.0, -80.0)
		var age := float(e.frame) / maxf(1.0, e.move.active)
		for k in 4:
			var r := 30.0 + k * 22.0 + age * 40.0
			var mid := 0.0 if e.facing > 0 else PI
			draw_arc(c, r, mid - 0.7, mid + 0.7, 18, Color(1.0, 0.95, 0.8, (1.0 - age) * (0.9 - k * 0.18)), 5.0)

	## The ofuda as on the road: a strip of paper with a red seal, turning in flight.
	func _paper(e: Entity) -> void:
		var tilt := sin(e.frame * 0.4) * 0.3
		draw_set_transform(BoutView.ORIGIN + e.position, tilt, Vector2.ONE)
		draw_rect(Rect2(-9, -22, 18, 44), Color("#f4efe2"))
		draw_rect(Rect2(-6, -18, 12, 4), Color("#b0372c"))
		draw_line(Vector2(0, -12), Vector2(0, 16), Color("#b0372c"), 2.5)
		draw_line(Vector2(-4, -2), Vector2(4, -2), Color("#b0372c"), 2.0)
		draw_set_transform(BoutView.ORIGIN)


var main: Node
var mode := "rite"
var bout: Bout
var player: RefCounted   # anything with read(me, them) -> Intent: the player, or a computer in tests
var cpu: RefCounted       # the opponent: a computer, or a scripted controller in tests
var stage: Stage
var font: Font
var done := false
var tilt_notes: Array[String] = []


func setup(kind: String, main_node: Node) -> void:
	mode = kind
	main = main_node
	InputSetup.register()
	var a: FighterDefinition
	var b: FighterDefinition
	var spirits_a: Array[SpiritBinding] = []
	var spirits_b: Array[SpiritBinding] = []
	# each binder's shikigami stand with it: the monk's with the monk, and the
	# yokai the oni bound on night trails with the oni
	if mode == "rite":
		a = _monk()
		b = _oni(false)
		spirits_a = _bound_spirits(GameState.spirits)
		spirits_b = _bound_spirits(GameState.oni_spirits)
	else:
		a = _oni(true)
		b = _master()
		spirits_a = _bound_spirits(GameState.oni_spirits)
		spirits_b = _master_spirits()
	_staff_on_j(a)
	bout = Bout.new(a, b, spirits_a, spirits_b)
	# either can jump clean over the other (the engine's second change)
	bout.air_passes = true
	# and no round is a draw: one of them always stands (the engine's fourth change)
	bout.no_double_ko = true
	for i in 2:
		bout.fighters[i].set_chord_window(InputHistory.DEFAULT_CHORD)
	bout.fighters[0].invincible = GameState.invincible
	player = PlayerController.new("p1_")
	# the computer plays sharper the more oni there is in the rite, and each
	# time the oni has thrown the master exorcist off
	var level: float = CPU_LEVEL[GameState.difficulty] + (3.0 * _menace() if mode == "rite" else float(GameState.master_beaten))
	cpu = CpuController.new(_cpu_table(level), randi())
	tilt_notes.append("Computer: level %.1f" % level)


func _ready() -> void:
	font = ThemeDB.fallback_font
	stage = Stage.new()
	stage.scale = Vector2(STAGE_SCALE, STAGE_SCALE)
	stage.bout = bout
	# there are no players 1 and 2 here: the end of a bout names who won
	if mode == "rite":
		stage.names.assign(["The yamabushi", "His oni"])
		BoutView.winner_titles.assign(["YAMABUSHI WINS", "ONI WINS"])
	else:
		stage.names.assign(["The oni", "The master exorcist"])
		BoutView.winner_titles.assign(["ONI WINS", "EXORCIST WINS"])
	add_child(stage)


## The rite to Shikigami's fight tune; the master exorcist to his own, its
## noh flute coming in as the oni weakens.
func music() -> Dictionary:
	if mode == "rite":
		return {"tune": "fight", "tension": 0.0}
	var f := bout.fighters[0]
	return {"tune": "master", "tension": 1.0 - 0.8 * float(f.health) / maxf(1.0, f.definition.max_health)}

func legend() -> Dictionary:
	var d := bout.fighters[0].definition
	var names: Array = []
	for sid in d.specials:
		names.append(String(sid).replace("_", " ").capitalize())
	var special: String = names[0] if names.size() > 0 else "Special"
	if names.size() > 1:
		special += " · away+L " + names[1]
	return {"I": "Light", "J": ("Staff" if mode == "rite" else "Kanabo") + " (heavy)", "L": special, "K": "Spirit"}

## The player's fighter strikes its heavy blow with J, as on the road, and its
## light one with I. Shikigami reads J as light and I as heavy, and its guard is
## light + special (J+L); exchanging the fighter's light and heavy moves keeps
## that guard, and the throw (light + heavy), where they are.
func _staff_on_j(d: FighterDefinition) -> void:
	for stance in ["stand", "crouch", "jump"]:
		var lk := StringName(stance + "_light")
		var hk := StringName(stance + "_heavy")
		if d.moves.has(lk) and d.moves.has(hk):
			var m: MoveDefinition = d.moves[lk]
			d.moves[lk] = d.moves[hk]
			d.moves[hk] = m


# ---------- the fighters, tilted by the run ----------
func _monk() -> FighterDefinition:
	var d: FighterDefinition = Roster.by_id(&"monk")
	d.display_name = "The yamabushi"
	# the road's specials: the ofuda in place of meditation (so he has no heal),
	# the horagai in place of the sutra palm
	_replace(d, &"meditation", Roster._special(OFUDA))
	_replace(d, &"sutra_palm", Roster._special(CONCH))
	d.preferred_gap = Roster.preferred_gap(d)
	# a weak body is a weak fighter; the spirits he freed steady him
	var body := 0.75 + 0.25 * clampf(GameState.stamina / 100.0, 0.0, 1.0)
	var merit := 1.0 + 0.03 * mini(GameState.freed_total, 5)
	d.max_health = roundi(d.max_health * body * merit)
	tilt_notes.append("Monk: health x%.2f (body %d, freed %d)" % [body * merit, int(GameState.stamina), GameState.freed_total])
	return d

## Put `move` in the place of special `old`: the same input calls it.
func _replace(d: FighterDefinition, old: StringName, move: MoveDefinition) -> void:
	var slot := d.specials.find(old)
	d.moves.erase(old)
	d.moves[move.id] = move
	d.specials[slot] = move.id
	for pattern in d.commands:
		if d.commands[pattern] == old:
			d.commands[pattern] = move.id

## The oni, tilted by the run. In the rite, the deeper the curse the more of
## it there is. In the hunt the curse is always full, so what counts is the
## body: how big its meals have made it, and how much of it the road has left.
func _oni(hunting: bool) -> FighterDefinition:
	var d: FighterDefinition = Roster.by_id(&"shuten")
	d.display_name = "The oni"
	# the yokai it bound on the road stand with it (one of the engine's four small changes)
	d.binds_any = true
	var r: Dictionary = GameState.record
	var health := 0.7 + GameState.curse / 100.0 + 0.03 * mini(int(r.eat), 10)
	var power := 1.0 + 0.04 * mini(int(r.smash), 8)
	var why := "curse %d, ate %d" % [int(GameState.curse), r.eat]
	if hunting:
		var o: Dictionary = GameState.hunt_oni
		var size: float = o.get("scale", 1.0)
		var body := clampf(o.get("hp", 100.0) / 100.0, 0.25, 1.0)
		health = (1.0 + 0.25 * (size - 1.0)) * body
		power += 0.1 * (size - 1.0)
		why = "size %.1f, body %d" % [size, int(o.get("hp", 100.0))]
	# the more oni there is, the quicker it moves
	var speed := 0.9 + 0.4 * _menace()
	_hasten(d, speed)
	d.max_health = roundi(d.max_health * health)
	for id in d.moves:
		var m: MoveDefinition = d.moves[id]
		if m != null and m.damage > 0:
			m.damage = roundi(m.damage * power)
	# a drinker's sake heals more and comes round sooner
	if d.moves.has(&"sake") and int(r.drink) > 0:
		var sake: MoveDefinition = d.moves[&"sake"]
		sake.heal = roundi(sake.heal * (1.0 + 0.05 * mini(int(r.drink), 8)))
		sake.cooldown = roundi(sake.cooldown * (1.0 - 0.04 * mini(int(r.drink), 8)))
	# an arsonist's quake comes round sooner and hits harder
	if d.moves.has(&"kanabo_quake") and int(r.burn) > 0:
		var q: MoveDefinition = d.moves[&"kanabo_quake"]
		q.cooldown = roundi(q.cooldown * (1.0 - 0.08 * mini(int(r.burn), 5)))
		q.damage = roundi(q.damage * (1.0 + 0.1 * mini(int(r.burn), 5)))
	tilt_notes.append("Oni: health x%.2f, blows x%.2f, speed x%.2f (%s, smashed %d, drank %d, burned %d)" % [
		health, power, speed, why, r.smash, r.drink, r.burn])
	return d

## The master exorcist: Seimei's kit, with more of him each time he returns:
## more health, quicker feet (and sharper play: see setup).
func _master() -> FighterDefinition:
	var d: FighterDefinition = Roster.by_id(&"onmyoji")
	var n := GameState.master_beaten
	var k := 1.0 + 0.2 * n
	var speed := 1.0 + 0.08 * n
	d.max_health = roundi(d.max_health * k)
	_hasten(d, speed)
	tilt_notes.append("Master exorcist: health x%.1f, speed x%.2f (thrown off %d times)" % [k, speed, n])
	return d

## How much oni there is, 0 to 1. In the rite, as deep as the curse has gone
## (none below 40); in the hunt, where the curse is always full, as big as its
## meals have made it (size 1 to 3).
func _menace() -> float:
	if mode == "rite":
		return clampf((GameState.curse - 40.0) / 60.0, 0.0, 1.0)
	return clampf((GameState.hunt_oni.get("scale", 1.0) - 1.0) / 2.0, 0.0, 1.0)

## Quicker on its feet: walking and jumping.
static func _hasten(d: FighterDefinition, k: float) -> void:
	d.walk_forward *= k
	d.walk_back *= k
	d.jump_forward *= k

## The computer's play at a level on a continuous scale. Between two of
## Shikigami's levels it is a blend of them. Above Hard each further level
## brings it half of the remaining way to a ceiling: deciding and guarding
## sooner, reading, guarding and punishing more often.
const SHARPER := ["aggression", "guard_chance", "low_read", "spirit_read", "escape_chance", "punish", "anti_air", "utility", "heal_chance"]
const QUICKER := {"think": 3.0, "guard_delay": 1.0}   # frame counts, and their floor
static func _cpu_table(level: float) -> Dictionary:
	var levels := CpuController.LEVELS
	var top := levels.size() - 1
	var lo := clampi(int(floor(level)), 0, top)
	var hi := mini(lo + 1, top)
	var f := clampf(level - lo, 0.0, 1.0)
	var g := 1.0 - pow(0.5, maxf(0.0, level - top))
	var out := {}
	for k in levels[lo][1]:
		var v := lerpf(float(levels[lo][1][k]), float(levels[hi][1][k]), f)
		var name := String(k)
		if name in SHARPER:
			v = lerpf(v, 0.95, g)
		elif QUICKER.has(name):
			v = roundi(lerpf(v, QUICKER[name], g))
		out[k] = v
	return out

## The master exorcist's shikigami: a different draw of yokai each time he
## comes, one the first time and two after (Shikigami's two summon slots).
func _master_spirits() -> Array[SpiritBinding]:
	var pool: Array = []
	for src in SPIRIT_SOURCE.values():
		if not pool.any(func(p): return p[0] == src[0]):
			pool.append(src)
	pool.shuffle()
	var kinds: Array = []
	for i in mini(1 + mini(GameState.master_beaten, 1), pool.size()):
		kinds.append({"kind": SPIRIT_SOURCE.find_key(pool[i])})
	var out := _bound_spirits(kinds)
	var names: Array = out.map(func(b: SpiritBinding) -> String: return b.source.display_name)
	tilt_notes.append("Master's shikigami: " + ", ".join(names))
	return out

## Shikigami bound on the trails fight as roster yokai.
func _bound_spirits(list: Array) -> Array[SpiritBinding]:
	var out: Array[SpiritBinding] = []
	for sp in list:
		var src: Array = SPIRIT_SOURCE.get(sp.kind, [])
		if src.is_empty():
			continue
		var d: FighterDefinition = Roster.by_id(src[0])
		if d == null or d.specials.is_empty():
			continue
		var move: StringName = src[1] if src[1] != &"" and d.specials.has(src[1]) else d.specials[0]
		out.append(SpiritBinding.new(d, move))
	return out


# ---------- the fight ----------
func _physics_process(_delta: float) -> void:
	if done or GameState.paused or GameState.ended:
		return
	var a := bout.fighters[0]
	var b := bout.fighters[1]
	var intents: Array[Intent] = [player.read(a, b), cpu.read(b, a)]
	var calls := _conch_calls()
	var blocked := b.blocks_taken
	bout.step(intents)
	if mode == "rite":
		_conch_through_guard(calls, b, blocked)
	if bout.is_over():
		done = true
		_result(bout.winner())


## The conch's calls in the air this frame.
func _conch_calls() -> Array:
	var out: Array = []
	for e in bout.entities:
		if e.owner_index == 0 and e.move.id == &"conch_call":
			out.append(e)
	return out

## A guarded call is blocked by the engine; the guard only blunts it here.
func _conch_through_guard(calls: Array, target: Fighter, blocked_before: int) -> void:
	if calls.is_empty() or target.blocks_taken == blocked_before:
		return
	for e in calls:
		# spent before its time: it struck
		if e.spent and e.frame < e.move.total_frames() and not target.invincible:
			var dmg := roundi(e.move.damage * CONCH_GUARDED)
			target.health = maxi(target.health - dmg, 1)
			target.show_notice("-%d" % dmg)
			return


func _process(_delta: float) -> void:
	stage.queue_redraw()
	queue_redraw()


func _result(winner: int) -> void:
	if mode == "rite":
		if winner == 0:
			var sealed := " and seal it with the finishing rite" if bout.bound else ""
			main.end_run("The oni is cast out", "On the moonless night you meet your oni in the temple and defeat it%s. At dawn you walk down the mountain alone in your own body. %s" % [sealed, GameState.habits_line()])
		else:
			main.open_modal("The rite fails", "The oni throws you down in the temple hall and takes the body for its own. Before dawn, the master exorcist begins the climb.",
				[{"label": "Take the road as the oni", "run": main.start_hunt.bind(main._here())}])
	else:
		if winner == 0:
			# the oni walks on with what the fight left it, a little more for having won
			var f := bout.fighters[0]
			var o: Dictionary = GameState.hunt_oni
			o.hp = clampf(100.0 * f.health / maxf(1.0, f.definition.max_health) + 10.0, 10.0, 100.0)
			GameState.master_thrown()
			main.open_modal("The master exorcist falls back", "He goes down in the road and his shikigami carry him off. He will be back, and not alone.",
				[{"label": "Go on", "run": main.resume_hunt}])
		else:
			main.hunt_over("Sealed", "The master exorcist binds the oni in a jar of sutras and carries it to the temple on the mountain. Of the monk, nothing remains.")


func _draw() -> void:
	if mode == "rite":
		_draw_mountain()
	else:
		_draw_road()
	var title := "The rite: the yamabushi against his oni" if mode == "rite" else "The master exorcist catches up with the oni"
	draw_rect(Rect2(0, H - 16, W, 16), Color(0.08, 0.09, 0.17, 0.7))
	draw_string(font, Vector2(0, H - 5), "J+L guard   J+K+L spirit guard   J+I throw   away+L second special   away, toward + K seal the beaten", HORIZONTAL_ALIGNMENT_CENTER, W, 8, PAPER)
	draw_string(font, Vector2(0, 62), title, HORIZONTAL_ALIGNMENT_CENTER, W, 10, Color(PAPER, 0.85))
	draw_string(font, Vector2(0, H - 20), "v" + GameState.VERSION, HORIZONTAL_ALIGNMENT_RIGHT, W - 3, 8, Color(PAPER, 0.4))


## The standoff's stage: the temple courtyard on the peak under a moonless
## sky, in the journey's own style, behind Shikigami's fighters.
func _draw_mountain() -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	var dk := Kit.sky(self, 0.0, true, 22.0, 0.0, "peaks", BACK + 30.0, t)
	Kit.ground(self, BACK, dk, "stone")
	var hall := {"kind": "temple", "x": 150.0, "w": 180.0, "h": 104.0, "hp": 100.0, "pantry": 0, "barrels": 0}
	Kit.building(self, hall, hall.x, BACK, true, true)
	Kit.torii(self, 70.0, BACK, 58.0, dk, 12.0)
	Kit.torii(self, 410.0, BACK, 58.0, dk, 12.0)
	for lx in [125.0, 355.0]:
		Kit.stone_lantern(self, lx, BACK + 2, dk, true)
	Kit.cedar(self, 22.0, BACK + 2, 96.0, dk)
	Kit.cedar(self, 458.0, BACK + 2, 90.0, dk)
	draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.04, 0.12, 0.2))

## Where the master exorcist catches the oni: that street, as damaged as the
## oni left it, or that stretch of trail, by day or by night. The stage is
## centred on the spot where he caught it.
func _draw_road() -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	var at: Dictionary = GameState.hunt_at
	var look := {"backdrop": "hills", "ground": "earth", "width": W}
	var builds: Array = []
	if at.has("station"):
		look = Stations.def(at.station).areas[at.area]
		var hp: Dictionary = GameState.load_station_hp(at.station)
		for src in look.get("buildings", []):
			if src.kind != "bridge":
				var b: Dictionary = src.duplicate()
				b.hp = float(hp.get(b.id, src.get("hp", 100.0)))
				b.burning = false
				b.pantry = 0
				b.barrels = 0
				builds.append(b)
	elif at.has("trail"):
		look = Stations.TRAILS[at.trail]
	var x0 := clampf(float(at.get("x", W / 2.0)) - W / 2.0, 0.0, maxf(0.0, float(look.get("width", W)) - W))
	var dark := not GameState.daylight
	var dk := Kit.sky(self, x0, dark, GameState.hours, GameState.moon_lit(dark), look.get("backdrop", "hills"), BACK + 20.0, t)
	Kit.ground(self, BACK, dk, look.get("ground", "earth"))
	for p in look.get("props", []):
		var sx: float = p.x - x0
		if p.kind != "castle" and (sx + p.get("w", 0.0) < -100 or sx > W + 100):
			continue
		match p.kind:
			"cedar": Kit.cedar(self, sx, BACK + 2, p.get("h", 60.0), dk)
			"rock": Kit.rock(self, sx, BACK + 4, p.get("s", 10.0), dk)
			"stone_lantern": Kit.stone_lantern(self, sx, BACK + 2, dk, dark)
			"torii": Kit.torii(self, sx, BACK, p.get("h", 50.0), dk, 10.0)
			"paddies": Kit.paddies(self, sx, p.get("w", 200.0), BACK, dk)
			"waterfall": Kit.waterfall(self, sx, BACK + 4, p.get("h", 70.0), dk, t)
			"castle":
				# far off on the skyline, as in the town
				draw_set_transform(Vector2(W / 2.0 + (p.x - x0 - W / 2.0) * 0.3, BACK - 26.0), 0.0, Vector2(0.6, 0.6))
				Kit.castle(self, 0.0, 0.0, dk + 0.1)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for b in builds:
		var bx: float = b.x - x0
		if bx + b.w > -30 and bx < W + 30:
			Kit.building(self, b, bx, BACK, dark, true)
	if dark:
		draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.04, 0.12, 0.2))
