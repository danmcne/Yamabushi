extends Control
## A small legend in the corner: the I/J/K/L diamond and the U and O keys, each
## with what it does right now. Keys that do nothing at the moment are dimmed.
## The current view supplies the words through legend().

const PAPER := Color("#ece3cf")
const CAP := Vector2(11, 10)
## Key positions: the diamond as it sits under the right hand.
const POS := {"U": Vector2(0, 0), "I": Vector2(13, 0), "O": Vector2(26, 0), "J": Vector2(3, 12), "K": Vector2(16, 12), "L": Vector2(29, 12)}

var view: Node
var font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if view == null or not view.has_method("legend") or not is_instance_valid(view):
		return
	var words: Dictionary = view.legend()
	var origin := Vector2(4, 270 - 56)
	# as wide as its longest line
	var widest := 0.0
	for k in words:
		if words[k] != "":
			widest = maxf(widest, font.get_string_size("%s  %s" % [k, words[k]], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	draw_rect(Rect2(origin - Vector2(2, 2), Vector2(maxf(122.0, 48.0 + widest), 54)), Color(0.06, 0.07, 0.14, 0.55))
	# the keys
	for k in POS:
		var on: bool = words.get(k, "") != ""
		var p: Vector2 = origin + POS[k]
		draw_rect(Rect2(p, CAP), Color(PAPER, 0.85 if on else 0.25))
		draw_string(font, p + Vector2(2.5, 8.5), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.08, 0.09, 0.17, 1.0 if on else 0.6))
	draw_string(font, origin + Vector2(0, 33), "P pause", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(PAPER, 0.55))
	# what they do, in a column beside them
	var y := origin.y + 7.0
	for k in ["I", "J", "L", "K", "U", "O"]:
		var w: String = words.get(k, "")
		if w == "":
			continue
		draw_string(font, Vector2(origin.x + 44, y), "%s  %s" % [k, w], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(PAPER, 0.95))
		y += 8.0
