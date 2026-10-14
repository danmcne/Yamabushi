extends RefCounted
## The standoffs' fighters in the journey's low-resolution style.
##
## Shikigami's skeleton still poses every fighter, because the engine traces
## each blow's reach from the posed weapon: what is drawn is what hits. This
## reads the joints of that pose (shoulder, elbow, wrist; hip, knee, ankle;
## neck and head) and the weapon's line, and draws over them from the same
## character sheets as the journey (figure.gd): the yamabushi and his oni in
## detail, everyone else from their rig's colours and a few features.
##
## Two of the monk's moves have no blow to trace, and are drawn as the journey
## draws them: the ofuda thrown, the conch at his lips.
##
## The upper body turns as Shikigami turns it: when a full stroke swings the
## chest past profile, the back is toward the viewer, and the far arm is drawn
## behind the body.

const Figure := preload("res://scripts/figure.gd")
const PuppetsRegistry := preload("res://game/art/puppets/registry.gd")
const Basic := preload("res://game/art/puppets/basic.gd")
## The way the yamabushi and the oni face in the standoffs: three-quarters
## toward the viewer, as Shikigami's diagonal view sets their shoulders.
const YAW := 35.0


## `falling`: the round or the bout is over, and a beaten fighter falls.
static func draw_fighter(ci: CanvasItem, f: Fighter, base: Transform2D, curse: float, gourd: String, alpha := 1.0, falling := false) -> void:
	var p := PuppetsRegistry.for_id(f.definition.id)
	if p == null:
		return
	var scale := f.definition.stand_hurtbox.size.y / p.height * Puppet.FIT
	var id := f.definition.id
	var moving := f.state == Fighter.State.MOVE and f.move != null
	if id == &"monk" and moving and f.move.id in [&"ofuda", &"conch"]:
		var kind := "toss" if f.move.id == &"ofuda" else "conch"
		var phase := clampf(float(f.state_frame) / maxf(1.0, f.move.startup), 0.0, 1.0)
		var t := float(Time.get_ticks_msec()) / 1000.0
		Figure.monk(ci, base * f.position, YAW if f.facing > 0 else 180.0 - YAW, p.height * scale, kind, t, phase, curse, gourd, alpha)
		ci.draw_set_transform_matrix(base)
		return
	var pose := Puppet._pose(f, p, scale)
	_seiza(f, p, pose, falling, Engine.get_physics_frames())
	var tf := p.pose_transforms(pose.angles, pose.root, pose.root_rot)
	# draw in figure units: the journey's sheets are laid out on a rig BASE tall
	var u := p.height / Figure.BASE
	ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(f.facing * scale * u, scale * u), 0.0, f.position))
	var j := _joints(p, tf, u, pose.angles.get("yaw", p.yaw_at_rest()))
	var hurt := f.state == Fighter.State.HITSTUN and f.state_frame < 6
	match id:
		&"monk":
			_monk(ci, j, curse, gourd, alpha)
		&"shuten":
			_oni(ci, j, f, hurt, alpha)
		_:
			_generic(ci, p, j, id, alpha)
	ci.draw_set_transform_matrix(base)


## The joints of a posed rig, in figure units.
static func _joints(p: PuppetDefinition, tf: Dictionary, u: float, rig_yaw: float) -> Dictionary:
	var j := {}
	for side in ["lead", "trail"]:
		j[side + "_sh"] = tf[side + "_upper"].origin / u
		j[side + "_el"] = tf[side + "_fore"].origin / u
		# the wrist: where the hand joins, or the weapon for a fist that is all club
		var wrist: String = side + "_hand" if tf.has(side + "_hand") else side + "_weapon"
		j[side + "_wr"] = tf[wrist].origin / u
		j[side + "_hip"] = tf[side + "_thigh"].origin / u
		j[side + "_kn"] = tf[side + "_shin"].origin / u
		j[side + "_an"] = tf[side + "_foot"].origin / u
		# the hand's centre, a little past the wrist along the forearm
		j[side + "_hand"] = j[side + "_wr"] + (j[side + "_wr"] - j[side + "_el"]).normalized() * 1.0
		# the foot as the rig shapes it, so it stands on the floor where the rig does
		var foot: Array = []
		var fp: PuppetDefinition.Part = p.find(side + "_foot")
		for q in p.shape_of(fp, p.view):
			foot.append((tf[side + "_foot"] * q) / u)
		j[side + "_foot"] = foot
	j.hip = (j.lead_hip + j.trail_hip) / 2.0
	j.sh = (j.lead_sh + j.trail_sh) / 2.0
	var head: PuppetDefinition.Part = p.find("head")
	var shape := p.shape_of(head, p.view)
	var c := Vector2.ZERO
	for q in shape:
		c += q
	c /= maxf(1.0, shape.size())
	j.neck = tf.head.origin / u
	j.head = (tf.head * c) / u
	j.weapons = []
	for w in p.weapons:
		if String(w.bone).ends_with("_weapon"):
			var t: Transform2D = tf[w.bone]
			j.weapons.append({"name": w.name, "a": (t * w.from) / u, "b": (t * w.to) / u})
	# which leg is nearer: in the diagonal view the lead leg is far. The arms
	# turn with the upper body (Shikigami's "yaw"): the nearer is the one whose
	# shoulder the turn brings toward the viewer.
	j.near = "trail" if p.view == PuppetDefinition.View.DIAGONAL or not p.side_lead_near else "lead"
	j.far = "lead" if j.near == "trail" else "trail"
	j.near_arm = "lead" if p.arm_depth("lead", rig_yaw) > 0.0 else "trail"
	j.far_arm = "trail" if j.near_arm == "lead" else "lead"
	# the sheets' own yaw for the chest: Shikigami's turn of 180 is profile with
	# the trailing (staff) side near, 90 the chest to the viewer, and past 180
	# the back turns toward the viewer. The head keeps looking at the opponent.
	j.yaw = wrapf(180.0 - rig_yaw, -180.0, 180.0)
	j.head_yaw = clampf(j.yaw, 15.0, 75.0)
	j.far_behind = p.arm_depth(j.far_arm, rig_yaw) < PuppetDefinition.BEHIND
	return j


# ---------- the yamabushi ----------
static func _monk(ci: CanvasItem, j: Dictionary, curse: float, gourd: String, alpha: float) -> void:
	var near: String = j.near
	var far: String = j.far
	var yaw: float = j.yaw
	var up: Vector2 = (j.sh - j.hip).normalized()
	var hip: Vector2 = j.hip
	var sh: Vector2 = j.sh
	var L: Array = []
	for s in [far, near]:
		L.append([-20.0 if s == far else -19.0, _monk_leg.bind(ci, j[s + "_kn"], j[s + "_an"], j[s + "_foot"], s == far, alpha)])
	L.append([-10.0, Figure.hakama.bind(ci, hip, up, [j[far + "_kn"], j[near + "_kn"]], alpha)])
	# the jacket over the shoulders
	var jk: Array = [j.lead_sh, j.trail_sh, j.neck]
	for q in Figure.ring(3.6, -1.0, 5.0):
		jk.append(Figure.at(hip, up, q, yaw))
	for q in Figure.ring(3.4, 0.4, 5.9):
		jk.append(Figure.at(sh, up, q, yaw))
	L.append([0.0, _jacket.bind(ci, jk, [j.lead_sh, j.trail_sh], alpha)])
	var g := Vector3(-4.8, 3.0, -3.2)
	L.append([Figure.near(g, yaw), Figure._gourd.bind(ci, Figure.at(hip, up, g, yaw), gourd, alpha)])
	for sb in [-1.0, 1.0]:
		var top := Vector3(2.4, -0.4, 3.6 * sb)
		var bot := Vector3(4.4, 0, 2.3 * sb)
		if Figure.near(bot, yaw) > 0.0:
			L.append([Figure.near(bot, yaw), Figure._band.bind(ci, Figure.at(sh, up, top, yaw), Figure.at(sh.lerp(hip, 0.75), up, bot, yaw), alpha)])
		for i in 3:
			var b := Vector3(4.6, 0, 2.3 * sb)
			if Figure.near(b, yaw) > -1.0:
				L.append([Figure.near(b, yaw) + 0.1, Figure._bonten.bind(ci, Figure.at(sh.lerp(hip, 0.2 + 0.25 * i), up, b, yaw), alpha)])
	var cv := Vector3(4.6, 2.2, 3.0)
	L.append([Figure.near(cv, yaw), Figure._conch.bind(ci, Figure.at(hip, up, cv, yaw), 0.75, alpha)])
	var k0 := Vector3(4.4, -2.4, -1.6)
	L.append([Figure.near(k0, yaw), Figure._kiseru.bind(ci, Figure.at(hip, up, k0, yaw), Figure.at(hip, up, Vector3(4.8, -6.0, -2.2), yaw), alpha)])
	L.append([0.5, Figure.monk_head.bind(ci, _head_on(j, 4.6), j.head_yaw, curse, alpha, _head_up(j))])
	var fa: String = j.far_arm
	var na: String = j.near_arm
	L.append([-6.0 if j.far_behind else 5.0, Figure.sleeve.bind(ci, j[fa + "_sh"], j[fa + "_el"], j[fa + "_hand"], alpha, 0.82)])
	for w in j.weapons:
		L.append([5.5, Figure.staff.bind(ci, w.a, w.b, alpha)])
	L.append([6.0, Figure.sleeve.bind(ci, j[na + "_sh"], j[na + "_el"], j[na + "_hand"], alpha, 1.0)])
	Figure.paint(L)

static func _monk_leg(ci: CanvasItem, knee: Vector2, ankle: Vector2, foot: Array, far: bool, alpha: float) -> void:
	Figure.shin(ci, knee, ankle, far, alpha)
	Figure.hull(ci, foot, Figure.a(Figure.STRAW.darkened(0.15) if far else Figure.STRAW, alpha))

static func _jacket(ci: CanvasItem, pts: Array, shoulders: Array, alpha: float) -> void:
	for s in shoulders:
		ci.draw_circle(s, 2.8, Figure.a(Figure.JACKET, alpha))
	Figure.hull(ci, pts, Figure.a(Figure.JACKET, alpha))


# ---------- the oni ----------
static func _oni(ci: CanvasItem, j: Dictionary, f: Fighter, hurt: bool, alpha: float) -> void:
	var skin := Color("#ffd9cc") if hurt else Figure.ONI
	var near: String = j.near
	var far: String = j.far
	var yaw: float = j.yaw
	var up: Vector2 = (j.sh - j.hip).normalized()
	var hip: Vector2 = j.hip
	var sh: Vector2 = j.sh
	var L: Array = []
	for leg in [[far, skin.darkened(0.2), -20.0], [near, skin, -19.0]]:
		var s: String = leg[0]
		L.append([leg[2], _oni_leg.bind(ci, j[s + "_hip"], j[s + "_kn"], j[s + "_an"], j[s + "_foot"], leg[1], alpha)])
	var tk: Array = [j.lead_sh, j.trail_sh, j.neck]
	for q in Figure.ring(4.2, -1.0, 6.0):
		tk.append(Figure.at(hip, up, q, yaw))
	for q in Figure.ring(4.8, 0.6, 8.0):
		tk.append(Figure.at(sh, up, q, yaw))
	L.append([0.0, Figure.hull.bind(ci, tk, Figure.a(skin.darkened(0.14), alpha))])
	L.append([0.2, Figure.pelt.bind(ci, hip, up, yaw, alpha)])
	var drinking: bool = f.state == Fighter.State.MOVE and f.move != null and f.move.id == &"sake"
	if not drinking and Figure.near(Figure.ONI_GOURD, yaw) > -2.0:
		L.append([Figure.near(Figure.ONI_GOURD, yaw) + 0.3, Figure._gourd.bind(ci, Figure.at(hip, up, Figure.ONI_GOURD, yaw), "sake", alpha, 1.15)])
	for sb in [-1.0, 1.0]:
		var c0 := Vector3(4.9, 4.4, 0.6 * sb)
		if Figure.near(c0, yaw) > 0.5:
			L.append([0.3, Figure._crease.bind(ci, Figure.at(sh, up, c0, yaw), Figure.at(sh, up, Vector3(4.3, 5.2, 5.6 * sb), yaw), Figure.a(skin.darkened(0.4), alpha))])
	L.append([0.5, Figure.oni_head.bind(ci, _head_on(j, 4.8), j.head_yaw, skin, alpha, _head_up(j))])
	var fa: String = j.far_arm
	var na: String = j.near_arm
	L.append([-6.0 if j.far_behind else 5.0, Figure.oni_arm.bind(ci, j[fa + "_sh"], j[fa + "_el"], j[fa + "_hand"], skin.darkened(0.3), alpha)])
	if drinking:
		# on its side, the neck at the lips, as from a bottle
		var mouth := _head_on(j, 4.8)
		L.append([5.2, Figure._gourd.bind(ci, j.lead_hand, "sake", alpha, 1.3, mouth - j.lead_hand)])
	for w in j.weapons:
		L.append([5.5, Figure.kanabo.bind(ci, w.a, w.b, alpha)])
	L.append([6.0, Figure.oni_arm.bind(ci, j[na + "_sh"], j[na + "_el"], j[na + "_hand"], skin.lightened(0.05), alpha)])
	Figure.paint(L)

static func _oni_leg(ci: CanvasItem, top: Vector2, knee: Vector2, ankle: Vector2, foot: Array, col: Color, alpha: float) -> void:
	Figure.limb(ci, top, knee, 7.2, 6.6, Figure.a(col, alpha))
	Figure._oni_leg(ci, knee, ankle, foot, col, alpha)


## Where to centre a head of radius `r` so it sits on the neck, leaning as the rig's head leans.
static func _head_on(j: Dictionary, r: float) -> Vector2:
	return j.neck + _head_up(j) * (r - 0.6)

static func _head_up(j: Dictionary) -> Vector2:
	var d: Vector2 = j.head - j.neck
	return d.normalized() if d.length() > 0.01 else Vector2.UP


# ---------- everyone else ----------
## From the rig's own colours and a few features of its description: a robe
## or legs, a hat, ears, a long nose or a beak, a shell, wings, tails.
## A beaten fighter (health gone) kneels into seiza at once, wherever it is,
## and stays kneeling, head bowing, while the winner may seal it; when the
## round or the bout is over it falls, into Shikigami's lying pose. Shikigami
## itself stands a fighter up, dazed, for the sealing and lays it flat at a
## knockout; this one rule replaces both, so it never starts over. Counted in
## physics frames (`now`) from when its health ran out, whatever its state.
const SEIZA_IN := 16.0     # frames to sink into seiza
const SEIZA_BOW := 40.0    # frames for the head to bow
const SEIZA_FALL := 22.0   # frames to fall
const LYING_ROOT := Vector2(-30.0, -18.0)   # Shikigami's knocked-out pose
const LYING_ROT := -88.0
static func _seiza(f: Fighter, p: PuppetDefinition, pose: Dictionary, falling: bool, now: int) -> void:
	if f.health > 0:
		for k in ["down_at", "fall_at"]:
			if f.has_meta(k):
				f.remove_meta(k)
		return
	if not f.has_meta("down_at"):
		f.set_meta("down_at", now)
	var down_at: int = f.get_meta("down_at")
	var t := float(now - down_at)
	var fall := 0.0
	if falling:
		# a fighter beaten outright still kneels a moment before it falls
		if not f.has_meta("fall_at"):
			f.set_meta("fall_at", maxi(now, down_at + int(SEIZA_IN + SEIZA_BOW * 0.5)))
		fall = smoothstep(0.0, SEIZA_FALL, float(now - int(f.get_meta("fall_at"))))
	var stand: Dictionary = p.base_angles("stand")
	var thigh := p.find("lead_shin").pivot.length()
	var shin := p.find("lead_foot").pivot.length()
	# kneeling: thighs level ahead, shins folded under, sitting back on the heels,
	# hands on the thighs, the head bowing
	var bow := smoothstep(SEIZA_IN, SEIZA_IN + SEIZA_BOW, t)
	var kneel := stand.duplicate()
	kneel.merge({lead_thigh = -86.0, trail_thigh = -82.0, lead_shin = 172.0, trail_shin = 170.0,
		torso = lerpf(4.0, 14.0, bow), head = lerpf(10.0, 34.0, bow),
		lead_upper = 12.0, lead_fore = -70.0, trail_upper = 6.0, trail_fore = -64.0}, true)
	var into := smoothstep(0.0, SEIZA_IN, t)
	var a: Dictionary = pose.angles
	for k in kneel:
		var from: float = stand.get(k, 0.0)
		a[k] = lerpf(lerpf(from, kneel[k], into), from, fall)
	pose.root = Vector2(0.0, (thigh + shin * 0.82) * into).lerp(LYING_ROOT, fall)
	pose.root_rot = lerpf(0.0, LYING_ROT, fall)

static func _generic(ci: CanvasItem, p: PuppetDefinition, j: Dictionary, id: StringName, alpha: float) -> void:
	var col: Dictionary = p.colourways[0]
	var spec: Dictionary = Basic._spec(id)
	var skin: Color = col.get("skin", Figure.SKIN)
	var garment: Color = col.get("garment", Color("#5b4a38"))
	var second: Color = col.get("secondary", garment.lightened(0.2))
	var extra: Color = col.get("extra", garment.darkened(0.3))
	var hair: Color = col.get("hair", Figure.INK)
	var near: String = j.near
	var far: String = j.far
	var up: Vector2 = (j.sh - j.hip).normalized()
	var fw := Vector2(-up.y, up.x)
	var build: float = spec.get("build", 1.0)
	var w := 5.2 * build
	# behind everything: wings, shell, tails
	if spec.has("wings"):
		for k in [-1.0, 1.0]:
			Figure.poly(ci, [j.sh - fw * 2.0, j.sh - fw * (9.0 + 3.0 * k) - up * (4.0 + 5.0 * k), j.hip - fw * 4.0 + up * 6.0], Figure.a(extra, alpha * 0.9))
	if spec.get("shell", false):
		Figure.hull(ci, [j.sh - fw * 3.0, j.sh - fw * 9.5 - up * 2.0, j.hip - fw * 9.0 + up * 4.0, j.hip - fw * 3.0], Figure.a(Color("#3f6b3a"), alpha))
	var tails: int = spec.get("tails", 0)
	for i in tails:
		var tip: Vector2 = j.hip - fw * (12.0 + i * 1.5) + up * (6.0 + i * 5.0)
		Figure.limb(ci, j.hip - fw * 3.0, tip, 2.6, 3.6 if spec.get("tail", "") == "fox" else 3.0, Figure.a(extra if spec.get("tail", "") == "tanuki" else garment.lightened(0.3), alpha))
		if spec.get("tail", "") == "fox":
			ci.draw_circle(tip, 1.4, Figure.a(Color("#f4efe6"), alpha))
	# legs, or a robe to the ankles
	var leg_col := garment.darkened(0.2)
	Figure.limb(ci, j[far + "_hip"], j[far + "_kn"], 3.4 * build, 3.0 * build, Figure.a(leg_col.darkened(0.15), alpha))
	Figure.limb(ci, j[far + "_kn"], j[far + "_an"], 3.0 * build, 2.5 * build, Figure.a(leg_col.darkened(0.15), alpha))
	Figure.limb(ci, j[near + "_hip"], j[near + "_kn"], 3.4 * build, 3.0 * build, Figure.a(leg_col, alpha))
	Figure.limb(ci, j[near + "_kn"], j[near + "_an"], 3.0 * build, 2.5 * build, Figure.a(leg_col, alpha))
	for s in [far, near]:
		ci.draw_rect(Rect2(j[s + "_an"] + Vector2(-1.2, -0.6), Vector2(3.8, 1.4)), Figure.a(Figure.INK, alpha))
	if spec.get("hem", "") == "robe":
		var pts: Array = [j.hip - fw * w + up, j.hip + fw * w + up]
		for s in [far, near]:
			var a0: Vector2 = j[s + "_an"] - up * 1.0
			pts.append(a0 - fw * 3.5)
			pts.append(a0 + fw * 3.5)
		Figure.hull(ci, pts, Figure.a(garment, alpha))
	# torso, belly, sash
	Figure.poly(ci, [j.hip - fw * w - up, j.hip + fw * w - up, j.sh + fw * (w - 0.4), j.sh - fw * (w - 0.6)], Figure.a(garment, alpha))
	if spec.get("belly", false):
		ci.draw_circle(j.hip.lerp(j.sh, 0.35) + fw * 2.5, 4.4 * build, Figure.a(second, alpha))
	else:
		Figure.limb(ci, j.hip.lerp(j.sh, 0.12) - fw * w, j.hip.lerp(j.sh, 0.12) + fw * w, 1.8, 1.8, Figure.a(second, alpha))
	# head, hair, features, hat
	var head := _head_on(j, 4.2)
	ci.draw_circle(head, 4.2, Figure.a(skin, alpha))
	if spec.get("hair", "short") != "none":
		Figure.poly(ci, [head + Vector2(-4.4, 1.0), head + Vector2(-4.0, -2.4), head + Vector2(-1.4, -4.2), head + Vector2(1.2, -4.0), head + Vector2(-1.0, 0.6)], Figure.a(hair, alpha))
		if spec.get("hair", "") == "long":
			Figure.limb(ci, head + Vector2(-3.4, 0), head + Vector2(-4.2, 9.0), 2.6, 2.0, Figure.a(hair, alpha))
	ci.draw_rect(Rect2(head + Vector2(1.8, -0.9), Vector2(1.1, 1.0)), Figure.a(Figure.INK, alpha))
	match spec.get("nose", ""):
		"tengu":
			Figure.poly(ci, [head + Vector2(3.0, -1.2), head + Vector2(11.0, 0.2), head + Vector2(3.4, 1.4)], Figure.a(skin.darkened(0.1), alpha))
	var face: Variant = spec.get("face", [])
	if face is Array and "beak" in face:
		Figure.poly(ci, [head + Vector2(3.0, 0.2), head + Vector2(6.6, 1.4), head + Vector2(3.0, 2.6)], Figure.a(Color("#d9a441"), alpha))
	match spec.get("ears", ""):
		"fox":
			for ex in [-1.6, 1.6]:
				Figure.poly(ci, [head + Vector2(ex - 1.6, -3.0), head + Vector2(ex, -8.4), head + Vector2(ex + 1.6, -3.4)], Figure.a(garment.lightened(0.4), alpha))
		"tanuki":
			for ex in [-2.0, 2.0]:
				ci.draw_circle(head + Vector2(ex, -4.0), 1.5, Figure.a(extra, alpha))
	match spec.get("hat", ""):
		"eboshi":
			Figure.poly(ci, [head + Vector2(-2.6, -3.2), head + Vector2(2.6, -3.2), head + Vector2(1.4, -11.0), head + Vector2(-1.8, -9.4)], Figure.a(Figure.INK, alpha))
		"tokin":
			Figure.poly(ci, [head + Vector2(0.4, -3.6), head + Vector2(4.4, -3.0), head + Vector2(4.6, -5.6), head + Vector2(2.6, -7.2), head + Vector2(0.2, -6.2)], Figure.a(Figure.INK, alpha))
		"kasa":
			Figure.poly(ci, [head + Vector2(-8.0, -2.0), head + Vector2(8.0, -2.0), head + Vector2(0, -7.6)], Figure.a(col.get("straw", Figure.STRAW), alpha))
		"dish":
			ci.draw_circle(head + Vector2(-0.4, -4.0), 2.4, Figure.a(Color("#dfeaf2"), alpha))
	# arms, the far one first; held weapons between them
	far = j.far_arm
	near = j.near_arm
	Figure.limb(ci, j[far + "_sh"], j[far + "_el"], 3.6 * build, 3.2 * build, Figure.a(garment.darkened(0.18), alpha))
	Figure.limb(ci, j[far + "_el"], j[far + "_hand"], 3.0 * build, 2.6 * build, Figure.a(garment.darkened(0.18), alpha))
	ci.draw_circle(j[far + "_hand"], 1.5 * build, Figure.a(skin.darkened(0.18), alpha))
	for wpn in j.weapons:
		Figure.limb(ci, wpn.a, wpn.b, 1.2, 1.2, Figure.a(col.get("wood", Figure.WOOD), alpha))
	Figure.limb(ci, j[near + "_sh"], j[near + "_el"], 3.6 * build, 3.2 * build, Figure.a(garment.darkened(0.06), alpha))
	Figure.limb(ci, j[near + "_el"], j[near + "_hand"], 3.0 * build, 2.6 * build, Figure.a(garment.darkened(0.06), alpha))
	ci.draw_circle(j[near + "_hand"], 1.5 * build, Figure.a(skin, alpha))
