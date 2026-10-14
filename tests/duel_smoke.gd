extends Node
## Duel smoke test, enabled only with:  godot --headless --path . --fixed-fps 60 -- --duel [--duel-hunt]
## Fights the rite, or the master exorcist catching up with the oni in the
## hunt, with the computer playing both sides. It shows the standoffs run to an
## ending; it says nothing of balance.

var main: Node
var frame := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_d: float) -> void:
	frame += 1
	if frame == 5:
		main.choose(main.options_shown[1])
		GameState.curse = 45.0
		GameState.record = {"eat": 4, "drink": 2, "smash": 3, "burn": 1, "roar": 1, "bind": 0}
		GameState.spirits = [{"kind": "onibi", "cd": 0.0}, {"kind": "kappa", "cd": 0.0}]
		var kind := "rite"
		if "--duel-hunt" in OS.get_cmdline_user_args():
			kind = "hunt"
			GameState.curse = 100.0
			GameState.begin_hunt()
			GameState.hunt_at = {"station": "post_town", "area": Stations.def("post_town").start.area, "x": 300.0, "y": 230.0}
		main.start_duel(kind)
		main.view.player = CpuController.new(CpuController.LEVELS[2][1], 7)
		print("duel: ", main.view.tilt_notes)
		return
	if frame > 5 and main.modal_open():
		print("duel ended: %s" % main.modal_title.text)
		get_tree().quit()
	if frame > 60 * 60 * 12:
		print("duel: no ending after twelve minutes")
		get_tree().quit()

const Stations := preload("res://scripts/stations.gd")
