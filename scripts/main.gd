extends Node
## Owns the current view (map or station) and the shared UI: dialogs, toasts,
## the suppression struggle, endings and touch controls.

const StationView := preload("res://scripts/station_view.gd")
const MapView := preload("res://scripts/map_view.gd")
const TrailView := preload("res://scripts/trail_view.gd")
const PeakView := preload("res://scripts/peak_view.gd")
const DuelView := preload("res://scripts/duel_view.gd")
const Suppression := preload("res://scripts/suppression.gd")
const TouchPad := preload("res://scripts/touch_pad.gd")
const KeyLegend := preload("res://scripts/key_legend.gd")
const Stations := preload("res://scripts/stations.gd")

const INK := Color("#14172b")
const PAPER := Color("#ece3cf")
const VICE := Color("#b0372c")

var view: Node2D
var ui: CanvasLayer
var modal_root: Control
var modal_title: Label
var modal_body: Label
var modal_opts: VBoxContainer
var toast_panel: PanelContainer
var toast_label: Label
var toast_t := 0.0
var options_shown: Array = []
var suppression: Control
var pad: Control
var legend: Control
var wake := {}
var on_title := false   # the title dialog is up (its music is the menu's)


func _ready() -> void:
	_build_ui()
	GameState.fallen.connect(_on_fallen)
	GameState.new_moon.connect(new_moon_passed)
	var args := OS.get_cmdline_user_args()
	var tool_script := ""
	if "--bot" in args:
		tool_script = "res://tests/bot.gd"
	elif "--checks" in args:
		tool_script = "res://tests/checks.gd"
	elif "--duel" in args:
		tool_script = "res://tests/duel_smoke.gd"
	for a in args:
		if a.begins_with("--snap="):
			tool_script = "res://tests/snap.gd"
		elif a.begins_with("--figures="):
			tool_script = "res://tests/figures.gd"
		elif a.begins_with("--sounds="):
			tool_script = "res://tests/export_sounds.gd"
	if tool_script != "":
		# the tools drive runs of their own: they neither read nor leave a saved run
		GameState.saving = false
		var helper: Node = load(tool_script).new()
		helper.main = self
		add_child(helper)
	start_run()


func start_run() -> void:
	on_title = true
	GameState.new_run()
	enter_station("village")
	var opts: Array = [
		{"label": "Begin: Easy", "sub": "Two nights to spare, gentle watch, an easy duel", "run": _begin.bind(0)},
		{"label": "Begin: Normal", "sub": "One night to spare", "run": _begin.bind(1)},
		{"label": "Begin: Hard", "sub": "No night to spare, a hard watch and duel", "run": _begin.bind(2)},
	]
	var saved := GameState.saved_run()
	if not saved.is_empty():
		var at: String = Stations.ROUTE.get(saved.get("station_id", ""), {}).get("name", "the road")
		var when := "Dawn after night %d" % int(saved.get("night_no", 0))
		if saved.get("hunt", false):
			var place: Dictionary = saved.get("hunt_at", {})
			at = Stations.ROUTE[place.station].name if place.has("station") else Stations.TRAILS[place.trail].name
			var n := int(saved.get("hunt_phase", 0)) / 2 + 1
			when = "The hunt, %s %d" % ["day" if saved.get("daylight", false) else "night", n]
		opts.append({"label": "Continue", "sub": "%s, at %s (%s)" % [when, at,
			GameState.DIFFICULTY[int(saved.get("difficulty", 1))].name], "run": _continue.bind(saved)})
	open_modal("Yamabushi  v" + GameState.VERSION,
		"You sealed an oni inside your own body; the seal holds only by your vows. Reach the temple at the peak by the new moon and face it in the rite. Break your vows and it wakes at night. You share one body.",
		opts)
	toast("WASD walk. I or Space act, J staff, L special, K shikigami, U gourd, O pipe, P pause. Choices: their numbers, or W/S and I.")

func _begin(level: int) -> void:
	on_title = false
	GameState.clear_save()
	GameState.set_difficulty(level)

## Pick up the saved run where it was left: at dawn, on the map, or in the hunt.
func _continue(saved: Dictionary) -> void:
	on_title = false
	var wake := GameState.load_run(saved)
	if GameState.hunt:
		go_hunt(GameState.hunt_at, GameState.hunt_oni)
	else:
		go_map(wake)


func _input(event: InputEvent) -> void:
	# a dialog's choices answer to their number keys
	if not modal_root.visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	var idx := -1
	if k >= KEY_1 and k <= KEY_9:
		idx = k - KEY_1
	elif k >= KEY_KP_1 and k <= KEY_KP_9:
		idx = k - KEY_KP_1
	if idx >= 0 and idx < options_shown.size() and not options_shown[idx].get("disabled", false):
		get_viewport().set_input_as_handled()
		choose(options_shown[idx])

func _unhandled_input(event: InputEvent) -> void:
	# testing aid: fights cost neither the monk nor the oni anything
	if event.is_action_pressed("cheat") and not event.is_echo():
		GameState.invincible = not GameState.invincible
		toast("Testing aid %s: fights cost nothing." % ("on" if GameState.invincible else "off"))
	elif event.is_action_pressed("pause") and not event.is_echo():
		pause()

## Stop the game where it stands: a dialog over everything, which nothing
## moves under (every view waits while GameState.paused).
func pause() -> void:
	if modal_open() or suppression != null or GameState.ended:
		return
	open_modal("Paused", "Nothing moves until you return.", [
		{"label": "Resume"},
		{"label": "Sound: %s" % ("on" if Settings.sound_on() else "off"), "sub": "Effects and ambience", "run": _toggle.bind("sound")},
		{"label": "Music: %s" % ("on" if Settings.music_on() else "off"), "run": _toggle.bind("music")},
		{"label": "Begin again", "sub": "Abandon this run", "run": start_run},
	])

## Turn sound or music on or off, and show the pause dialog again.
func _toggle(what: String) -> void:
	Settings.set_option(what, not (Settings.sound_on() if what == "sound" else Settings.music_on()))
	pause()

func _process(delta: float) -> void:
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0:
			toast_panel.visible = false
	if pad != null:
		pad.refresh(view, view != null and view.get("mode") == "night")
	if legend != null:
		legend.view = view


# ---------- views ----------
func _set_view(v: Node2D) -> void:
	if view != null:
		# stop it at once: it is freed only at the end of the frame, and must
		# not act again in the meantime (see the dusk that ends a journey)
		view.set_process(false)
		view.set_physics_process(false)
		view.set_process_unhandled_input(false)
		view.queue_free()
	view = v
	add_child(v)

func enter_station(id: String, at: Dictionary = {}) -> void:
	var v := StationView.new()
	v.setup(id, self, at)
	_set_view(v)

func enter_trail(trail_id: String, target: String) -> void:
	var v := TrailView.new()
	v.setup(trail_id, target, self)
	v.left_end = GameState.station_id
	_set_view(v)

## Arrival at the end of a trail: a station, or the temple at the peak.
func arrive(target: String) -> void:
	if target == "peak":
		var v := PeakView.new()
		v.setup(self)
		_set_view(v)
		return
	GameState.arrive(target)
	enter_station(target)

## The oni walks off the end of a trail at night into the town it led to (at
## `at`, or where the trail comes in).
func oni_enters(target: String, o: Dictionary, at: Dictionary = {}) -> void:
	GameState.arrive(target)
	var v := StationView.new()
	v.setup(target, self, at)
	_set_view(v)
	v.continue_night(o)

## The oni sets out on a trail from station `from` toward `to`, entering it at
## the end nearest `from`.
func oni_takes_road(trail: String, from: String, to: String, o: Dictionary) -> void:
	var lr := Stations.ends(trail, from, to)
	var v := TrailView.new()
	v.setup(trail, lr[1], self)
	v.left_end = lr[0]
	_set_view(v)
	v.continue_night(o, 20.0 if lr[0] == from else v.world_w - 20.0, o.get("y", 230.0))

func go_map(at: Dictionary) -> void:
	wake = at
	# each dawn on the map is where a run is saved
	GameState.save_run(at)
	var v := MapView.new()
	v.setup(self)
	_set_view(v)


# ---------- endings ----------
func end_run(title: String, body: String) -> void:
	# a bell for the oni cast out; a gong for every other ending
	Audio.play("bell" if title == "The oni is cast out" else "gong", -4.0)
	GameState.ended = true
	GameState.clear_save()
	open_modal(title, body, [{"label": "Begin again", "run": start_run}])

## The standoffs, on the Shikigami engine: "rite" (monk against oni) or
## "hunt" (the oni against the master exorcist, wherever he catches it).
func start_duel(kind: String) -> void:
	GameState.ended = false
	GameState.paused = false
	var v := DuelView.new()
	v.setup(kind, self)
	_set_view(v)
	toast(" / ".join(v.tilt_notes))

## The journey is over and the oni has the body. Nothing is saved from here.
func _fall(title: String, body: String) -> void:
	var at := _here()
	# what the oni did here stays done when it takes the road
	if view is StationView:
		GameState.save_station(view.id, view.all_buildings())
	GameState.ended = true
	GameState.clear_save()
	open_modal(title, body, [{"label": "Take the road as the oni", "run": start_hunt.bind(at)}])

func _on_fallen() -> void:
	_fall("The fall", "The last of the vows gives way. The yamabushi does not wake; the oni does, and this time it keeps the body. Word reaches the master exorcist, who sets out after it.")


# ---------- the hunt ----------
## Where the body is now, as a place the hunt can be resumed: in a town, on a
## trail, or (from the temple) at the top of the mountain trail.
func _here() -> Dictionary:
	if view is StationView:
		var b: Dictionary = view.oni if view.mode == "night" else view.monk
		return {"station": view.id, "area": view.area_id, "x": b.x, "y": b.y}
	if view is TrailView:
		var b2: Dictionary = view.oni if view.mode == "night" else view.monk
		return {"trail": view.trail_id, "left": view.left_end, "right": view.target, "x": b2.x, "y": b2.y}
	var top: Dictionary = Stations.TRAILS["mountain_trail"]
	return {"trail": "mountain_trail", "left": "castle_town", "right": "peak", "x": float(top.width) - 40.0, "y": 230.0}

func start_hunt(at: Dictionary) -> void:
	GameState.begin_hunt()
	GameState.save_hunt(at, GameState.hunt_oni)
	toast("The oni has the body for good. Eat, or starve; the hunters gather, and the master exorcist is on the road.")
	go_hunt(at, GameState.hunt_oni)

## Put the oni at a place in the hunt.
func go_hunt(at: Dictionary, o: Dictionary) -> void:
	GameState.ended = false
	GameState.paused = false
	if at.has("station"):
		oni_enters(at.station, o, {"area": at.area, "x": at.x, "y": at.y})
		return
	var v := TrailView.new()
	v.setup(at.trail, at.right, self)
	v.left_end = at.left
	_set_view(v)
	v.continue_night(o, at.x, at.y)

## The master exorcist catches up with the oni where it stands.
func master_comes(at: Dictionary, o: Dictionary) -> void:
	GameState.hunt_at = at
	GameState.hunt_oni = o.duplicate()
	var again := GameState.master_beaten > 0
	open_modal("The master exorcist", ("He is back, and he has not come alone this time: the talismans on his sleeves are fresh, and his shikigami are many." if again
		else "A man in white steps out ahead of the oni and unrolls a sutra scroll. He has walked a long way to be here."),
		[{"label": "Face him", "run": start_duel.bind("hunt")}])

## The oni threw the master exorcist off: back to where it was.
func resume_hunt() -> void:
	GameState.save_hunt(GameState.hunt_at, GameState.hunt_oni)
	go_hunt(GameState.hunt_at, GameState.hunt_oni)

## The end of the hunt, however it comes.
func hunt_over(title: String, body: String) -> void:
	end_run(title, body + " " + GameState.hunt_line())

## At the temple the rite can always be tried; how much oni there is to face
## depends on how deep the curse has gone (see DuelView._oni).
func reach_peak() -> void:
	var c := int(GameState.curse)
	var warn := ""
	if c > 75:
		warn = " It is nearly all oni now: huge, quick, and cunning."
	elif c > 50:
		warn = " The curse has fed it: it will be bigger and quicker than it was."
	open_modal("The rite", "The curse stands at %d. In the temple hall you loosen the seal and meet your oni face to face. Defeat it, and finish it with the sealing rite.%s" % [c, warn],
		[{"label": "Begin the rite", "run": start_duel.bind("rite")}])

func new_moon_passed() -> void:
	_fall("The new moon passes", "The night of the rite comes while you are still on the road, and the seal has nothing left to hold it. The oni takes the body for good, and the master exorcist sets out after it.")


# ---------- suppression ----------
func start_suppression(curse: float, cb: Callable) -> void:
	GameState.paused = true
	suppression = Suppression.new()
	# the oni pushes as hard as the curse is deep, and the difficulty says how hard that is
	suppression.setup(curse * GameState.diff().struggle, _suppression_done.bind(cb))
	ui.add_child(suppression)

func _suppression_done(ok: bool, cb: Callable) -> void:
	suppression = null
	GameState.paused = false
	# the presses of the struggle must not run on into what follows it
	GameState.block_input(1.0)
	cb.call(ok)


# ---------- dialogs and toasts ----------
func toast(text: String) -> void:
	toast_label.text = text
	toast_panel.visible = true
	toast_t = 3.0

func open_modal(title: String, body: String, opts: Array) -> void:
	GameState.paused = true
	modal_title.text = title
	modal_body.text = body
	modal_body.visible = body != ""
	for c in modal_opts.get_children():
		c.queue_free()
	options_shown = opts
	var first: Button = null
	for i in opts.size():
		var o: Dictionary = opts[i]
		var b := Button.new()
		var sub: String = o.get("sub", "")
		# every choice has a number key; W/S (or the arrows) and I (or Space/Enter) work too
		b.text = ("%d   " % (i + 1) if i < 9 else "") + o.label + ("\n      " + sub if sub != "" else "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(340, 0)
		b.disabled = o.get("disabled", false)
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_focus_color", INK)
		b.add_theme_color_override("font_pressed_color", INK)
		b.add_theme_color_override("font_disabled_color", Color(INK, 0.4))
		var vice: bool = o.get("vice", false)
		b.add_theme_stylebox_override("normal", _button_style(Color("#fff8e8"), vice))
		b.add_theme_stylebox_override("hover", _button_style(Color("#f6ecd2"), vice))
		b.add_theme_stylebox_override("focus", _button_style(Color("#f6ecd2"), vice, true))
		b.add_theme_stylebox_override("pressed", _button_style(Color("#efe1bf"), vice))
		b.add_theme_stylebox_override("disabled", _button_style(Color("#f3ecdc"), vice))
		b.pressed.connect(choose.bind(o))
		modal_opts.add_child(b)
		if i == default_choice(opts):
			first = b
	modal_root.visible = true
	if first != null:
		# right after a struggle (or any press the dialog should not take),
		# I and Space do nothing until the grace is over; number keys work at once
		if GameState.input_blocked():
			get_tree().create_timer(GameState.input_grace_left(), true).timeout.connect(_focus_if_shown.bind(first))
		else:
			first.call_deferred("grab_focus")

## The choice I or Space would take in a dialog: the first open one that
## breaks no vow (-1 if none).
static func default_choice(opts: Array) -> int:
	for i in opts.size():
		if not opts[i].get("disabled", false) and not opts[i].get("vice", false):
			return i
	return -1

func _focus_if_shown(b: Button) -> void:
	if is_instance_valid(b) and modal_root.visible and b.is_inside_tree():
		b.grab_focus()

func choose(o: Dictionary) -> void:
	modal_root.visible = false
	options_shown = []
	GameState.paused = false
	GameState.block_input(0.4)
	if o.has("run"):
		o.run.call()

func modal_open() -> bool:
	return modal_root.visible


func _button_style(bg: Color, vice: bool, focused: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = VICE if vice else Color("#cdbf9f")
	s.set_border_width_all(1)
	if vice:
		s.border_width_left = 4
	if focused:
		s.border_color = Color("#d3a24a") if not vice else VICE
		s.set_border_width_all(2)
		if vice:
			s.border_width_left = 4
	s.set_corner_radius_all(3)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	if DisplayServer.is_touchscreen_available() or "--touch" in OS.get_cmdline_user_args():
		pad = TouchPad.new()
		ui.add_child(pad)
	else:
		legend = KeyLegend.new()
		ui.add_child(legend)

	toast_panel = PanelContainer.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.08, 0.09, 0.17, 0.9)
	ts.border_color = Color("#d3a24a")
	ts.border_width_left = 3
	ts.content_margin_left = 8
	ts.content_margin_right = 8
	ts.content_margin_top = 3
	ts.content_margin_bottom = 3
	toast_panel.add_theme_stylebox_override("panel", ts)
	toast_panel.position = Vector2(40, 60)
	toast_panel.custom_minimum_size = Vector2(400, 0)
	toast_panel.visible = false
	toast_label = Label.new()
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.custom_minimum_size = Vector2(384, 0)
	toast_label.add_theme_font_size_override("font_size", 11)
	toast_label.add_theme_color_override("font_color", PAPER)
	toast_panel.add_child(toast_label)
	ui.add_child(toast_panel)

	modal_root = Control.new()
	modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.visible = false
	ui.add_child(modal_root)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.1, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(center)
	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = PAPER
	ps.set_corner_radius_all(3)
	ps.content_margin_left = 14
	ps.content_margin_right = 14
	ps.content_margin_top = 10
	ps.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(340, 0)
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	modal_title = Label.new()
	modal_title.add_theme_font_size_override("font_size", 16)
	modal_title.add_theme_color_override("font_color", INK)
	box.add_child(modal_title)
	modal_body = Label.new()
	modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_body.custom_minimum_size = Vector2(340, 0)
	modal_body.add_theme_font_size_override("font_size", 11)
	modal_body.add_theme_color_override("font_color", INK)
	box.add_child(modal_body)
	modal_opts = VBoxContainer.new()
	modal_opts.add_theme_constant_override("separation", 4)
	box.add_child(modal_opts)
