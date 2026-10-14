extends Node
## Pose sheet, enabled only with:  -- --figures=/some/dir   (needs a display)
## Draws every figure in every pose, enlarged, and saves one image.

const Figure := preload("res://scripts/figure.gd")
var main: Node
var dir := ""
var frame := 0
var sheet: Node2D

class Sheet extends Node2D:
	func _label(x: float, y: float, text: String) -> void:
		draw_string(ThemeDB.fallback_font, Vector2(x - 24, y), text, HORIZONTAL_ALIGNMENT_CENTER, 48, 7, Color.BLACK)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 480, 270), Color("#8fa0a8"))
		# the turn: profile, three-quarters, front, three-quarters from behind, back
		var yaws := [0.0, 40.0, 90.0, 140.0, 180.0, -40.0, -90.0]
		var names := ["side", "3/4", "front", "3/4 L", "side L", "back 3/4", "back"]
		for i in yaws.size():
			var x := 18.0 + i * 33.0
			Figure.monk(self, Vector2(x, 62), yaws[i], 46.0, "stand", 0.4, 0.0, 60.0, "water")
			_label(x, 70, names[i])
			Figure.oni(self, Vector2(x + 236, 62), yaws[i], 50.0, "stand", 0.4, 0.0)
			_label(x + 236, 70, names[i])
		var kinds := ["walk", "strike", "drink", "smoke", "conch", "pray", "taki", "goma"]
		for i in kinds.size():
			var x := 24.0 + i * 46.0
			var yaw := 90.0 if kinds[i] == "taki" else 0.0
			Figure.monk(self, Vector2(x, 140), yaw, 54.0, kinds[i], 0.4 + i * 0.1, 0.6, 60.0, "sake" if i == 2 else "water")
			_label(x, 148, kinds[i])
		var okinds := ["walk", "strike", "eat", "drink", "ignite", "roar"]
		for i in okinds.size():
			var x := 30.0 + i * 52.0
			Figure.oni(self, Vector2(x, 212), 30.0 if i == 2 else 0.0, 62.0, okinds[i], 0.5 + i * 0.2, 0.6)
			_label(x, 220, okinds[i])
		var looks := [
			{"robe": "#6d5a78", "skin": "#d9b595"}, {"robe": "#8c4b2f", "sash": "#d9cfb4"},
			{"robe": "#5b4a38", "hat": "#7b6a48"}, {"robe": "#2e3f63", "hat": "#3a3226", "item": "lantern"},
			{"robe": "#e9e3d3", "hat": "#1b1b22", "sash": "#a8322a", "item": "talisman"}]
		for i in looks.size():
			var x := 290.0 + i * 20.0
			Figure.person(self, Vector2(x, 262), 1, 36.0, looks[i], "front", "stand", 0.0)
			Figure.person(self, Vector2(x + 100, 262), 1, 36.0, looks[i], "side", "walk", 0.3 + i * 0.2)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--figures="):
			dir = a.split("=")[1]
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	sheet = Sheet.new()
	layer.add_child(sheet)

func _process(_d: float) -> void:
	frame += 1
	if frame == 10:
		get_viewport().get_texture().get_image().save_png(dir + "/figures.png")
		get_tree().quit()
