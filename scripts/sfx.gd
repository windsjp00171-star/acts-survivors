extends Node
## 音效與音樂（自動載入，名稱 Sfx）。聲音由 tools/make_sounds.py 產生。
## 常出現的聲音有最短間隔，避免同時一大堆疊在一起（「聲音不要太雜」）。

const GAP := {"hit": 0.06, "kill": 0.045, "gem": 0.07, "heal": 0.5, "link1": 0.08, "link2": 0.08, "link3": 0.08, "hurt": 0.15, "ui": 0.05}
const VOL := {"hit": -14.0, "kill": -9.0, "gem": -15.0, "heal": -10.0, "ui": -8.0, "roar": -4.0, "pick": -6.0}

var streams := {}
var last := {}
var players: Array = []
var music_player: AudioStreamPlayer
var music_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_player = AudioStreamPlayer.new()
	add_child(music_player)


func _on(kind: String) -> bool:
	return bool(Save.data.get(kind + "_on", true))


func play(name: String, pitch_jitter := 0.06) -> void:
	if not _on("sfx"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last.get(name, -1.0)) < float(GAP.get(name, 0.0)):
		return
	last[name] = now
	if not streams.has(name):
		var path := "res://assets/audio/%s.wav" % name
		streams[name] = load(path) if ResourceLoader.exists(path) else null
	if streams[name] == null:
		return
	for p in players:
		if not p.playing:
			p.stream = streams[name]
			p.volume_db = VOL.get(name, -5.0)
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return


func music(name: String) -> void:
	if name == music_name and music_player.playing:
		return
	music_name = name
	if name == "" or not _on("music"):
		var tw := create_tween()
		tw.tween_property(music_player, "volume_db", -40.0, 0.8)
		tw.tween_callback(music_player.stop)
		return
	var st = load("res://assets/audio/music_%s.ogg" % name)
	st.loop = true
	music_player.stream = st
	music_player.volume_db = -30.0
	music_player.play()
	create_tween().tween_property(music_player, "volume_db", -12.0, 1.2)


func toggle(kind: String) -> void:
	Save.data[kind + "_on"] = not _on(kind)
	Save.save_profile()
	if kind == "music":
		var n := music_name
		music_name = ""
		music(n if _on("music") else "")
		music_name = n
