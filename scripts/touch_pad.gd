extends Control
## On-screen buttons for touch screens. They emit the same input actions as
## the keyboard, so the game code never needs to know which one was used.
## One button per kit item: the gourd, the pipe and the staff (the kanabō at night).

var buttons := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make("move_up", "▲", Vector2(46, 192))
	_make("move_left", "◀", Vector2(4, 228))
	_make("move_down", "▼", Vector2(46, 228))
	_make("move_right", "▶", Vector2(88, 228))
	_make("act", "Act", Vector2(300, 228))
	_make("gourd", "Gourd", Vector2(344, 228))
	_make("pipe", "Pipe", Vector2(388, 228))
	_make("strike", "Staff", Vector2(432, 228))
	_make("special", "Ofuda", Vector2(388, 188))
	_make("spirit", "Spirit", Vector2(432, 188))
	_make("pause", "II", Vector2(436, 40))


func _make(action: String, label: String, pos: Vector2) -> void:
	var b := Button.new()
	b.text = label
	b.position = pos
	b.size = Vector2(42, 36)
	b.focus_mode = Control.FOCUS_NONE
	b.modulate = Color(1, 1, 1, 0.8)
	b.add_theme_font_size_override("font_size", 10)
	b.button_down.connect(_send.bind(action, true))
	b.button_up.connect(_send.bind(action, false))
	add_child(b)
	buttons[action] = b


func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func refresh(view: Node, night: bool) -> void:
	if view != null and view.has_method("act_label"):
		buttons.act.text = view.act_label()
	if view != null and view.has_method("pipe_label"):
		buttons.pipe.text = view.pipe_label()
	var trail: bool = view != null and view.has_method("_summon")
	buttons.strike.visible = night or trail
	buttons.strike.text = "Kanabo" if night else "Staff"
	buttons.spirit.visible = trail
	buttons.special.visible = night or trail
	buttons.special.text = "Roar" if night else "Ofuda"
	buttons.gourd.visible = not night
