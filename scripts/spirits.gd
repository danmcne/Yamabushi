extends RefCounted
## The shikigami's specials, the same whoever calls them and wherever: the
## monk's on the trails by day, the oni's on the trails and in the streets by
## night. Each binder commands only its own: the monk's shikigami will not
## answer the oni, nor the oni's the monk.
##
## A view hands over its caller ({x, y, face}), the targets in reach (each with
## x, y and stun), and how to hurt one; it gets back what to show.

const Kit := preload("res://scripts/kit.gd")
const NAMES := {"gaki": "hungry ghost", "onibi": "demon fire", "kappa": "kappa", "tengu": "tengu", "kitsune": "fox spirit", "kasa": "umbrella ghost"}
const COOLDOWN := 8.0
## The minor yokai as foes, wherever they are met: their strength, pace, reach,
## how often they strike and how hard, and what a blow from one feels like.
const FOE := {
	"gaki": {"hp": 30.0, "speed": 28.0, "reach": 14.0, "cd": 1.2, "dmg": 5.0, "hurt": "The hungry ghost claws at you."},
	"onibi": {"hp": 15.0, "speed": 34.0, "reach": 10.0, "cd": 1.0, "dmg": 4.0, "hurt": "Demon fire scorches your robe."},
	"kappa": {"hp": 35.0, "speed": 30.0, "reach": 14.0, "cd": 1.3, "dmg": 5.0, "hurt": "The kappa drags at your legs."},
	"tengu": {"hp": 25.0, "speed": 44.0, "reach": 16.0, "cd": 1.1, "dmg": 5.0, "hurt": "The tengu swoops and rakes you."},
	"kitsune": {"hp": 25.0, "speed": 36.0, "reach": 12.0, "cd": 1.0, "dmg": 6.0, "hurt": "The fox bites from behind."},
	"kasa": {"hp": 15.0, "speed": 36.0, "reach": 12.0, "cd": 1.2, "dmg": 3.0, "hurt": "The umbrella lashes you with its tongue."},
}


## Call `kind`'s special. Returns {toast, summon, fx, move (Vector2, or null)
## and the face to turn to after it, ward (seconds)}.
static func call_special(kind: String, caller: Dictionary, targets: Array, hurt: Callable, world_w: float) -> Dictionary:
	var out := {"toast": "", "summon": {}, "fx": {}, "move": null, "face": caller.face, "ward": 0.0}
	var face: float = caller.face
	match kind:
		"gaki":
			var best = _nearest(caller, targets, 170.0)
			out.summon = {"kind": "gaki", "x": best.x if best else caller.x + face * 30.0, "y": best.y if best else caller.y, "life": 1.2, "face": face}
			if best != null:
				best.stun = 3.0
				hurt.call(best, 20.0, 0.0)
			out.toast = "The hungry ghost seizes one and will not let go."
		"onibi":
			for f in targets:
				var ahead: float = (f.x - caller.x) * face
				if ahead > -6.0 and ahead < 170.0 and absf(f.y - caller.y) < 18.0:
					hurt.call(f, 25.0, face * 10.0)
			out.fx = {"k": "streak", "x": caller.x, "y": caller.y, "life": 0.6, "face": face}
			out.toast = "Demon fire streaks down the way, burning all it passes."
		"tengu":
			out.summon = {"kind": "tengu", "x": caller.x - face * 10.0, "y": caller.y, "life": 1.0, "face": face}
			for f in targets:
				var ahead: float = (f.x - caller.x) * face
				if ahead > -10.0 and ahead < 160.0 and absf(f.y - caller.y) < 36.0:
					f.stun = 1.5
					hurt.call(f, 10.0, face * 90.0)
			out.fx = {"k": "gust", "x": caller.x + face * 40.0, "y": caller.y, "life": 0.6, "face": face}
			out.toast = "The tengu beats its wings, and a gale sweeps everything ahead back."
		"kitsune":
			var near = _nearest(caller, targets, 170.0)
			if near != null:
				var side := 1.0 if near.x >= caller.x else -1.0
				out.move = Vector2(clampf(near.x + side * 18.0, 10.0, world_w - 10.0), near.y)
				out.face = -int(side)
				near.stun = 2.0
				hurt.call(near, 25.0, -side * 10.0)
				out.fx = {"k": "free", "x": out.move.x, "y": out.move.y - 20.0, "life": 0.6}
			out.toast = "Fox step: gone, and striking from behind."
		"kasa":
			out.ward = 5.0
			out.summon = {"kind": "kasa", "x": caller.x, "y": caller.y - 0.5, "life": 5.0, "face": face}
			out.toast = "The umbrella ghost opens overhead: blows land at half strength."
		"kappa":
			out.summon = {"kind": "kappa", "x": caller.x + face * 16.0, "y": caller.y, "life": 1.0, "face": face}
			for f in targets:
				if absf(f.x - caller.x) < 80.0 and absf(f.y - caller.y) < 30.0:
					f.stun = 1.0
					hurt.call(f, 15.0, signf(f.x - caller.x + 0.01) * 50.0)
			out.fx = {"k": "splash", "x": caller.x, "y": caller.y, "life": 0.6}
			out.toast = "The kappa empties a river over everything near."
	return out

static func _nearest(caller: Dictionary, targets: Array, reach: float):
	var best = null
	for f in targets:
		if absf(f.x - caller.x) < reach and (best == null or absf(f.x - caller.x) < absf(best.x - caller.x)):
			best = f
	return best


## The next ready shikigami in `slots` ({kind, cd}), starting after `after`;
## its index, or -1 if all are recovering.
static func next_ready(slots: Array, after: int) -> int:
	for k in slots.size():
		var i := (after + k) % slots.size()
		if slots[i].cd <= 0.0:
			return i
	return -1


## A summoned shikigami, showing itself for a moment.
static func draw_summon(ci: CanvasItem, s: Dictionary, x: float, y: float, t: float) -> void:
	var f := {"y": y, "face": s.face, "flash": 0.0, "fade": clampf(s.life * 2.0, 0.0, 0.8), "seed": 0.0, "atk": 0.3}
	Kit.creature(ci, s.kind, f, x, t)

## What a special leaves in the air: a gust, a splash, a streak of fire, a flash.
static func draw_fx(ci: CanvasItem, f: Dictionary, x: float, y: float) -> void:
	match f.k:
		"gust":
			for k in 4:
				var gx: float = x + f.face * (0.6 - f.life) * 160.0 - f.face * k * 10.0
				ci.draw_line(Vector2(gx, y - 30 + k * 8), Vector2(gx + f.face * 18, y - 30 + k * 8), Color(0.9, 0.95, 1.0, f.life), 1.5)
		"splash":
			ci.draw_arc(Vector2(x, y - 10), (0.6 - f.life) * 140.0, 0, TAU, 28, Color(0.6, 0.85, 1.0, f.life), 2.0)
		"streak":
			var reach: float = (0.6 - f.life) / 0.6 * 170.0
			for k in 3:
				var y0 := y - 14.0 - k * 4.0
				ci.draw_line(Vector2(x, y0), Vector2(x + f.face * reach, y0), Color(1.0, 0.55 + 0.15 * k, 0.2, f.life * 1.4), 2.0 - k * 0.5)
			ci.draw_circle(Vector2(x + f.face * reach, y - 18.0), 5.0, Color(0.6, 0.85, 1.0, f.life))
		"conch":
			for k in 3:
				ci.draw_arc(Vector2(x, y - 34), (0.8 - f.life) * 190.0 + k * 14.0, 0, TAU, 32, Color(1.0, 0.95, 0.8, f.life * 0.6), 1.2)
		_:
			ci.draw_circle(Vector2(x, y), 6.0 * f.life + 2.0, Color(0.9, 0.95, 1.0, f.life * 0.6))
