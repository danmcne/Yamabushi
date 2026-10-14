extends Node
## Writes every sound to WAV files, so they can be listened to outside the
## game, and reports each one's length, peak and loudness (RMS), and how long
## it took to make. Enabled only with:  godot --headless --path . -- --sounds=DIR
## Each tune is written stem by stem and as a mix of all its stems.
## --only=roar,town/0 writes just those.

const Sounds := preload("res://scripts/sounds.gd")

var main: Node
var dir := ""

func _ready() -> void:
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sounds="):
			dir = a.split("=")[1]
		elif a.begins_with("--only="):
			only = Array(a.split("=")[1].split(","))
	DirAccess.make_dir_recursive_absolute(dir)
	var s := Sounds.new()
	var names: Array = Sounds.EFFECTS + Sounds.LOOPS
	for tune in Sounds.TUNES:
		for k in Sounds.TUNES[tune]:
			names.append("%s/%d" % [tune, k])
	if not only.is_empty():
		names = names.filter(func(n): return n in only)
	for name in names:
		var started := Time.get_ticks_msec()
		var w: AudioStreamWAV = s.stream(name)
		var took := Time.get_ticks_msec() - started
		w.save_to_wav(dir.path_join(name.replace("/", "_") + ".wav"))
		print("%-12s %s" % [name, _describe(w, took)])
	for tune in Sounds.TUNES:
		if Sounds.TUNES[tune] < 2 or not only.is_empty():
			continue
		var mix: PackedFloat32Array = s._blank(s.stream("%s/0" % tune).data.size() / 2)
		for k in Sounds.TUNES[tune]:
			var stem: AudioStreamWAV = s.stream("%s/%d" % [tune, k])
			for i in mix.size():
				mix[i] += stem.data.decode_s16(i * 2) / 32000.0 * 1.6 / Sounds.TUNES[tune]
		var m: AudioStreamWAV = s._wav(mix, true)
		m.save_to_wav(dir.path_join(tune + "_mix.wav"))
		print("%-12s %s" % [tune + " mix", _describe(m, 0)])
	s.free()
	get_tree().quit()

func _describe(w: AudioStreamWAV, took: int) -> String:
	var n := w.data.size() / 2
	var peak := 0.0
	var sq := 0.0
	var clipped := 0
	for i in n:
		var v := absf(w.data.decode_s16(i * 2) / 32000.0)
		peak = maxf(peak, v)
		sq += v * v
		if v >= 1.0:
			clipped += 1
	return "%5.2f s  peak %.2f  rms %.3f  clipped %d  made in %d ms" % [n / float(Sound.RATE), peak, sqrt(sq / maxf(1.0, n)), clipped, took]
