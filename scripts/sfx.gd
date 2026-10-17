extends Node
## 音效與音樂（自動載入，名稱 Sfx）。聲音由 tools/make_sounds.py 產生。
## 常出現的聲音有最短間隔，避免同時一大堆疊在一起（「聲音不要太雜」）；有變體的（hit_2、hit_3）輪流播。
## 音樂由 tools/make_music.py 產生。關卡曲是三層（_perc、_harm、_top）同步播放，set_intensity 依戰況調每一層：
## calm 開局只有伴奏和輕輕的鼓、normal 全部、peak 菁英潮和 Boss 鼓與旋律更前面、danger 血很少時抽掉鼓、聲音變悶。
## 大的音效（爆發、進化、通關…）響的時候，音樂會短暫壓低。

const GAP := {"hit": 0.06, "kill": 0.045, "gem": 0.07, "heal": 0.5, "link1": 0.08, "link2": 0.08, "link3": 0.08, "hurt": 0.15, "ui": 0.05, "downbeat": 0.15, "splash": 0.2, "shatter": 0.1, "persuade": 0.15, "shield": 0.15, "shout": 0.3}
const VOL := {"hit": -14.0, "kill": -9.0, "gem": -15.0, "heal": -10.0, "ui": -8.0, "roar": -4.0, "pick": -6.0, "downbeat": -10.0, "persuade": -10.0, "shatter": -8.0}

var streams := {}
var last := {}
var players: Array = []
var music_player: AudioStreamPlayer
var music_name := ""
var variants := {}          # 音效名 → 這個音效的所有變體
var layered := false        # 現在的音樂是不是三層的
var intensity := "normal"
var layer_db := [0.0, 0.0, 0.0]
var duck := 0.0             # 音樂被壓低的量（dB，慢慢回來）
var music_bus := -1
var lowpass: AudioEffectLowPassFilter
const LAYERS := ["perc", "harm", "top"]
const MIX := {"calm": [-9.0, 0.0, -20.0], "normal": [0.0, 0.0, 0.0], "peak": [1.5, 0.0, 1.0], "danger": [-40.0, 0.0, -9.0]}
const DUCK := {"burst": 7.0, "evolve": 6.0, "levelup": 3.0, "fever": 6.0, "win": 9.0, "lose": 9.0, "roar": 4.0, "holy": 3.0, "chest": 3.0, "warn": 4.0}
const MAX_SAME := 3         # 同一個音效同時最多幾個


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	# 音樂自己一條匯流排：可以壓低（ducking），血很少時加低通濾波
	AudioServer.add_bus()
	music_bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(music_bus, "Music")
	AudioServer.set_bus_send(music_bus, "Master")
	lowpass = AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(music_bus, lowpass)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)


func _process(dt: float) -> void:
	if music_bus < 0:
		return
	duck = maxf(0.0, duck - dt * 10.0)
	AudioServer.set_bus_volume_db(music_bus, -duck)
	var want_lp := 900.0 if intensity == "danger" else 20000.0
	lowpass.cutoff_hz = lerpf(lowpass.cutoff_hz, want_lp, minf(1.0, dt * 3.0))
	if layered and music_player.stream is AudioStreamSynchronized:
		var target: Array = MIX[intensity]
		for i in 3:
			layer_db[i] = move_toward(layer_db[i], float(target[i]), dt * 12.0)   # 一層大約 1～2 秒淡入淡出
			music_player.stream.set_sync_stream_volume(i, layer_db[i])


## 依戰況換音樂的層次：calm／normal／peak／danger
func set_intensity(level: String) -> void:
	if MIX.has(level):
		intensity = level


func _on(kind: String) -> bool:
	return bool(Save.data.get(kind + "_on", true))


func play(name: String, pitch_jitter := 0.06, base_pitch := 1.0) -> void:
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
	if not variants.has(name):
		var vs := [streams[name]]
		for i in [2, 3]:
			var vp := "res://assets/audio/%s_%d.wav" % [name, i]
			if ResourceLoader.exists(vp):
				vs.append(load(vp))
		variants[name] = vs
	var same := 0
	for p in players:
		if p.playing and variants[name].has(p.stream):
			same += 1
	if same >= MAX_SAME:
		return
	if DUCK.has(name):
		duck = maxf(duck, float(DUCK[name]))
	for p in players:
		if not p.playing:
			p.stream = variants[name].pick_random()
			p.volume_db = VOL.get(name, -5.0)
			p.pitch_scale = base_pitch + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return


func music(name: String) -> void:
	if name == music_name and music_player.playing:
		return
	music_name = name
	intensity = "normal"      # 換歌就回到一般（關卡裡每一格畫面會再設一次）
	if name == "" or not _on("music"):
		var tw := create_tween()
		tw.tween_property(music_player, "volume_db", -40.0, 0.8)
		tw.tween_callback(music_player.stop)
		return
	var st: AudioStream = _music_stream(name)
	if st == null:
		return
	layered = st is AudioStreamSynchronized
	if layered:
		layer_db = (MIX[intensity] as Array).duplicate()
		for i in 3:
			st.set_sync_stream_volume(i, layer_db[i])
	# 換歌：舊的很快淡出，新的淡入
	var tw := create_tween()
	if music_player.playing:
		tw.tween_property(music_player, "volume_db", -40.0, 0.35)
	tw.tween_callback(func():
		music_player.stream = st
		music_player.volume_db = -30.0
		music_player.play())
	tw.tween_property(music_player, "volume_db", -12.0, 0.8)


## 三層的關卡曲（music_X_perc／_harm／_top）做成同步播放的一個串流；沒有分層的就是單一檔案
func _music_stream(name: String) -> AudioStream:
	var base := "res://assets/audio/music_%s" % name
	if ResourceLoader.exists(base + "_perc.ogg"):
		var sync := AudioStreamSynchronized.new()
		sync.stream_count = 3
		for i in 3:
			var part: AudioStreamOggVorbis = load("%s_%s.ogg" % [base, LAYERS[i]])
			part.loop = true
			sync.set_sync_stream(i, part)
		return sync
	if ResourceLoader.exists(base + ".ogg"):
		var one: AudioStreamOggVorbis = load(base + ".ogg")
		one.loop = true
		return one
	return null


func toggle(kind: String) -> void:
	Save.data[kind + "_on"] = not _on(kind)
	Save.save_profile()
	if kind == "music":
		var n := music_name
		music_name = ""
		music(n if _on("music") else "")
		music_name = n


## 對話咕噥聲：隨機一個母音，用角色的音高播
func voice(pitch: float) -> void:
	if not _on("sfx"):
		return
	var v: String = ["a", "e", "i", "o", "u"][randi() % 5]
	var name := "voice_" + v
	if not streams.has(name):
		streams[name] = load("res://assets/audio/%s.wav" % name)
	for p in players:
		if not p.playing:
			p.stream = streams[name]
			p.volume_db = -9.0
			p.pitch_scale = pitch * randf_range(0.94, 1.08)
			p.play()
			return


## 手機震動（只在手機上，可在暫停選單關掉）
func buzz(ms: int) -> void:
	if OS.has_feature("mobile") and _on("vibe"):
		Input.vibrate_handheld(ms)
