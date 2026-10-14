extends Control
## The suppression struggle. The talisman makes the oni stir; each press of
## Act pushes it back down. It rises faster the deeper the curse, so a
## disciplined monk passes easily and a compromised one has to fight for it.

const DURATION := 3.5
const PUSH := 0.15

var curse := 0.0
var value := 0.2
var time_left := DURATION
var done_cb: Callable
var font: Font
var finished := false


func setup(c: float, cb: Callable) -> void:
	curse = c
	done_cb = cb


func rise_rate() -> float:
	return 0.1 + curse * 0.008


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	if finished:
		return
	time_left -= delta
	value += rise_rate() * delta
	if value >= 1.0:
		_finish(false)
	elif time_left <= 0.0:
		_finish(true)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if finished:
		return
	if event.is_action_pressed("act") and not event.is_echo():
		value = maxf(0.0, value - PUSH)
		get_viewport().set_input_as_handled()


func _finish(ok: bool) -> void:
	finished = true
	var cb := done_cb
	queue_free()
	cb.call(ok)


func _draw() -> void:
	var sz := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.04, 0.04, 0.09, 0.6))
	var box := Rect2(sz.x / 2 - 150, sz.y / 2 - 50, 300, 100)
	draw_rect(box, Color("#ece3cf"))
	var ink := Color("#14172b")
	draw_string(font, box.position + Vector2(0, 22), "The talisman burns. Hold the oni down: press Act.", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 12, ink)
	var bar := Rect2(box.position + Vector2(20, 40), Vector2(260, 16))
	draw_rect(bar, Color("#cdbf9f"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(value, 0.0, 1.0), bar.size.y)), Color("#b0372c"))
	draw_rect(bar, ink, false, 1.0)
	var secs := maxf(0.0, time_left)
	draw_string(font, box.position + Vector2(0, 82), "Hold for %.1f more seconds" % secs, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 11, ink)
