extends Control
## 標題畫面：遊戲開啟後的第一個畫面。夜空、遠山、往地平線延伸的路，一群人往遠方的光走去。
## 走在路上的人跟著劇情進度換（下一章的主角在中間）；拔摩海島通過後，夜空變成新天新地的清晨。
## 第一次開遊戲先播一段開場（升天、五旬節），可以跳過，設定裡可以重看。
## 劇情模式第一次通過司提反、大馬士革、羅馬這幾章，回營地前會先來這裡播章節過場（CUTS），播完直接進營地。
## 「開始」進營地；「設定」切音樂、音效、特效精簡、字大一點。手機返回鍵在這裡是離開遊戲。

const PX := 3.0             # 像素放大倍數（背景用的「一格」）
# 開場：每一幕的旁白與畫面（scene 決定 _draw_intro 畫什麼）
const INTRO := [
	{"scene": "rise", "text": "耶穌從死裡復活以後，四十天之久，向門徒顯現。"},
	{"scene": "rise", "text": "祂被接上升之前說：「聖靈降臨在你們身上，你們就必得著能力，直到地極，作我的見證。」"},
	{"scene": "room", "text": "五旬節到了，門徒都聚集在一處，同心合意地禱告。"},
	{"scene": "wind", "text": "忽然，從天上有響聲下來，好像一陣大風吹過，充滿了他們所坐的屋子。"},
	{"scene": "fire", "text": "又有舌頭如火焰顯現出來，分開落在他們各人頭上，他們就都被聖靈充滿。"},
	{"scene": "road", "text": "從那天起，福音從耶路撒冷出發，一路往地極去。"},
]
const ROOM := ["john", "peter", "mary", "james", "andrew"]
# 章節結束的過場（劇情模式第一次通過那一章後播一次）：用同一套畫法
const CUTS := {
	"stephen": [
		{"scene": "sky", "text": "司提反被聖靈充滿，定睛望天，看見神的榮耀，又看見耶穌站在神的右邊。"},
		{"scene": "stones", "text": "眾人摀著耳朵，一齊衝向他，把他推到城外，拿石頭打他。"},
		{"scene": "coats", "text": "作見證的人把衣裳放在一個少年人腳前。那個少年人，名叫掃羅。"},
		{"scene": "kneel", "text": "司提反跪下，大聲喊著：「主啊，不要將這罪歸於他們！」說完，就睡了。"},
		{"scene": "scatter", "who": ["disciple", "philip", "disciple"], "text": "從那天起，耶路撒冷的信徒四散。可是他們走到哪裡，就把福音傳到哪裡。"},
	],
	"damascus": [
		{"scene": "wall", "text": "掃羅在大馬士革傳講耶穌。猶太人商量要殺他，日夜在城門守著。"},
		{"scene": "wall", "lower": true, "text": "門徒趁著夜裡，用筐子把他從城牆上縋下去。"},
		{"scene": "meet", "text": "到了耶路撒冷，門徒都怕他。只有巴拿巴接待他，帶他去見使徒。"},
		{"scene": "alone", "text": "後來弟兄們送他回家鄉大數。有好幾年，他就在那裡。"},
		{"scene": "scatter", "who": ["john", "peter", "disciple"], "text": "那時，各處的教會都得著平安。彼得走遍四方，來到了約帕。"},
	],
	"rome": [
		{"scene": "rome", "text": "保羅在羅馬自己租的房子裡，住了整整兩年。凡來見他的，他都接待。"},
		{"scene": "letters", "text": "他帶著鎖鏈，寫信給各地的教會。路加一直在他身邊。"},
		{"scene": "years", "text": "很多年過去了。使徒們一個一個，跑完了他們的路。"},
		{"scene": "sea", "text": "年老的約翰被流放到拔摩海島。在主日，他被聖靈感動，聽見身後有大聲音。"},
	],
}

var walkers: Array = ["silas", "tim", "paul", "luke", "barn"]   # 中間（第 3 位）最前面
var dawn := false           # 通過拔摩海島：新天新地的清晨
var intro_i := -1           # 開場播到第幾幕（-1 是沒有在播）
var cut_id := "intro"       # 正在播哪一段：intro 或 CUTS 的鍵
var cut: Array = INTRO
var intro_t := 0.0
var intro_box: Control
var intro_label: Label
var ver_label: Label

var t := 0.0
var tex := {}
var stars: Array = []
var title_box: VBoxContainer
var settings_box: PanelContainer
var portrait := false
var started := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().set_quit_on_go_back(true)
	var vs := get_viewport().get_visible_rect().size
	portrait = vs.y > vs.x
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		stars.append({"p": Vector2(rng.randf(), rng.randf() * 0.55), "ph": rng.randf() * TAU, "big": rng.randf() < 0.15})
	_pick_walkers()
	for k in walkers + ROOM + ["jesus"]:
		for f in 2:
			var path := "res://assets/sprites/%s_%d.png" % [k, f]
			if ResourceLoader.exists(path):
				tex["%s_%d" % [k, f]] = load(path)
	_build()
	Sfx.music("camp")
	var shot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.substr(7)
	var pc := str(Save.data.get("pending_cut", ""))
	if shot != "":
		_auto_shot(shot)
	elif CUTS.has(pc):
		_start_intro(pc)
	elif not Save.data.get("intro_seen", false) or OS.get_cmdline_user_args().has("--intro"):
		_start_intro()


## 路上的人：下一章的主角在中間，旁邊是這一章會遇到的同伴；全部通過後是約翰和舊約的見證人
func _pick_walkers() -> void:
	var CH: Array = Save.story.chapters
	var i := Save.story_next()
	dawn = i >= CH.size()
	var ch: Dictionary = CH[mini(i, CH.size() - 1)]
	var side: Array = Array(ch.cast).slice(0, 4)
	if dawn:
		side = ["peter", "paul", "moses", "elijah"]
	var row: Array = []
	if side.size() >= 2:
		row = [side[1], side[0], ch.leader] + side.slice(2, 4)
	else:
		row = side + [ch.leader]
	walkers = row


func _build() -> void:
	title_box = VBoxContainer.new()
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 6)
	add_child(title_box)
	var vs := get_viewport().get_visible_rect().size
	title_box.position = Vector2(0, vs.y * (0.12 if portrait else 0.08))
	title_box.size = Vector2(vs.x, 0)

	var main := UIKit.label("宣教之路", 44 if portrait else 52, UIKit.GOLD)
	main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_theme_constant_override("outline_size", 8)
	main.add_theme_color_override("font_outline_color", Color("2a1408"))
	_reparent(main)
	var en := UIKit.label("ACTS SURVIVORS", 15, UIKit.CREAM)
	en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	en.add_theme_constant_override("outline_size", 4)
	en.add_theme_color_override("font_outline_color", Color("1a1020"))
	_reparent(en)
	var verse := UIKit.label("「直到地極，作我的見證。」（徒 1:8）", 12, UIKit.INK)
	verse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	verse.add_theme_constant_override("outline_size", 4)
	verse.add_theme_color_override("font_outline_color", Color("1a1020"))
	_reparent(verse)

	# 直式：按鈕上下排在人群下面；橫式：左右排在最下面
	var btns: BoxContainer = VBoxContainer.new() if portrait else HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	add_child(btns)
	var go := UIKit.button("開始", 20, true)
	go.custom_minimum_size = Vector2(200, 52)
	go.pressed.connect(_start)
	btns.add_child(go)
	var st := UIKit.button("設定", 15)
	st.custom_minimum_size = Vector2(200, 40) if portrait else Vector2(140, 52)
	st.pressed.connect(_toggle_settings)
	btns.add_child(st)
	await get_tree().process_frame
	btns.position = Vector2(round((vs.x - btns.size.x) / 2.0), round(vs.y * 0.79) if portrait else vs.y - btns.size.y - 14.0)
	go.grab_focus()

	ver_label = UIKit.label(_version(), 10, UIKit.MUTED)
	add_child(ver_label)
	ver_label.position = Vector2(8, vs.y - 20)
	ver_label.visible = intro_i < 0


func _reparent(l: Label) -> void:
	if l.get_parent() != null:
		l.get_parent().remove_child(l)
	title_box.add_child(l)


func _version() -> String:
	var dl = JSON.parse_string(FileAccess.get_file_as_string("res://data/devlog.json"))
	if dl is Dictionary and not dl.get("entries", []).is_empty():
		return "v" + str(dl.entries[0].version)
	return ""


func _start() -> void:
	if started:
		return
	started = true
	Sfx.play("ui", 0.0)
	get_tree().change_scene_to_file("res://scenes/base.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if intro_i >= 0:
		# 開場：點一下或按鍵就到下一幕
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo):
			_next_intro()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER] and settings_box == null:
			_start()
		elif event.keycode == KEY_ESCAPE and settings_box != null:
			_toggle_settings()


## 設定：音樂、音效、特效精簡、字大一點（和遊戲中的暫停選單同一組開關）
func _toggle_settings() -> void:
	if settings_box != null:
		settings_box.queue_free()
		settings_box = null
		return
	Sfx.play("ui", 0.0)
	settings_box = PanelContainer.new()
	settings_box.add_theme_stylebox_override("panel", UIKit.box(Color(0.08, 0.05, 0.1, 0.96), UIKit.GOLD, 12))
	add_child(settings_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	settings_box.add_child(v)
	var head := UIKit.label("設定", 18, UIKit.GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	for kind in [["music", "音樂", true], ["sfx", "音效", true], ["fxlite", "特效精簡", false], ["bigtext", "字大一點", false]]:
		var k: String = kind[0]
		var nm: String = kind[1]
		var def: bool = kind[2]
		var b := UIKit.button("", 14)
		b.custom_minimum_size = Vector2(200, 38)
		var refresh := func(): b.text = "%s：%s" % [nm, "開" if Save.data.get(k + "_on", def) else "關"]
		refresh.call()
		b.pressed.connect(func():
			if k in ["music", "sfx"]:
				Sfx.toggle(k)
				if k == "music" and Save.data.get("music_on", true):
					Sfx.music("camp")
			else:
				Save.data[k + "_on"] = not bool(Save.data.get(k + "_on", false))
				Save.save_profile()
			refresh.call())
		v.add_child(b)
	var rw := UIKit.button("重看開場", 14)
	rw.custom_minimum_size = Vector2(200, 38)
	rw.pressed.connect(func():
		_toggle_settings()
		_start_intro())
	v.add_child(rw)
	var note := UIKit.label("字大一點在下一個畫面生效", 10, UIKit.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	var close := UIKit.button("關閉", 14, true)
	close.custom_minimum_size = Vector2(200, 38)
	close.pressed.connect(_toggle_settings)
	v.add_child(close)
	await get_tree().process_frame
	if settings_box != null:
		var vs := get_viewport().get_visible_rect().size
		settings_box.position = ((vs - settings_box.size) / 2.0).round()
		close.grab_focus()


func _process(dt: float) -> void:
	t += dt
	if intro_i >= 0:
		intro_t += dt
		if intro_t > 5.5:
			_next_intro()
	queue_redraw()


# ---------- 開場 ----------
func _start_intro(id := "intro") -> void:
	cut_id = id
	cut = INTRO if id == "intro" else CUTS[id]
	if intro_box != null:
		intro_box.queue_free()   # 上一段還沒收掉（只有測試拍照會連播）
	intro_i = 0
	intro_t = 0.0
	title_box.visible = false
	if ver_label != null:
		ver_label.visible = false
	for c in get_children():
		if c is BoxContainer and c != title_box:
			c.visible = false
	intro_box = Control.new()
	intro_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(intro_box)
	var vs := get_viewport().get_visible_rect().size
	intro_label = UIKit.label("", 15, UIKit.CREAM)
	intro_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.add_theme_constant_override("outline_size", 6)
	intro_label.add_theme_color_override("font_outline_color", Color("0b0716"))
	intro_label.custom_minimum_size = Vector2(vs.x - 40.0, 0)
	intro_label.position = Vector2(20, vs.y * (0.74 if portrait else 0.76))
	intro_box.add_child(intro_label)
	var skip := UIKit.button("跳過 ▶", 12)
	skip.custom_minimum_size = Vector2(80, 30)
	skip.position = Vector2(vs.x - 92, 12)
	skip.pressed.connect(_end_intro)
	intro_box.add_child(skip)
	var hint := UIKit.label("點一下畫面到下一幕", 10, UIKit.MUTED)
	hint.position = Vector2(12, vs.y - 22)
	intro_box.add_child(hint)
	intro_label.text = cut[0].text


func _next_intro() -> void:
	intro_i += 1
	intro_t = 0.0
	if intro_i >= cut.size():
		_end_intro()
		return
	intro_label.text = cut[intro_i].text
	if cut[intro_i].scene in ["wind", "fire", "sky", "sea"]:
		Sfx.play("holy", 0.0)


func _end_intro() -> void:
	intro_i = -1
	if cut_id != "intro":
		# 章節過場看完：記下來，直接回營地
		var seen: Array = Save.data.get("cuts_seen", [])
		if not seen.has(cut_id):
			seen.append(cut_id)
		Save.data.cuts_seen = seen
		Save.data.pending_cut = ""
		Save.save_profile()
		_start()
		return
	Save.data.intro_seen = true
	Save.save_profile()
	if intro_box != null:
		intro_box.queue_free()
		intro_box = null
	title_box.visible = true
	ver_label.visible = true
	for c in get_children():
		if c is BoxContainer:
			c.visible = true


func _draw_intro(vs: Vector2) -> void:
	var it: Dictionary = cut[intro_i]
	var sc: String = it.scene
	var fade := clampf(intro_t / 0.6, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, vs), Color("0b0716"))
	var cx := vs.x * 0.5
	var floor_y := vs.y * (0.6 if portrait else 0.62)
	var s := 4.0 if portrait else 3.5
	match sc:
		"rise":
			# 橄欖山：一道光柱，耶穌在光中慢慢往上
			for i in 5:
				var w := 60.0 - i * 11.0
				draw_rect(Rect2(cx - w / 2.0, 0, w, floor_y), [Color("3a2a44"), Color("6a5a50"), Color("a89060"), Color("e8d090"), Color("fff8d8")][i] * Color(1, 1, 1, fade))
			_hills(vs, floor_y, 0.4, Color("1c1226"), 26.0, 0.018)
			draw_rect(Rect2(0, floor_y, vs.x, vs.y - floor_y), Color("1a1220"))
			var up := intro_t * 10.0 if intro_i == 1 else 0.0
			var jp := Vector2(cx, floor_y - 30.0 - up) - Vector2(7, 17) * s
			draw_texture_rect(_tx("jesus"), Rect2(jp, Vector2(14, 17) * s), false, Color(1, 1, 1, fade))
			for i in 4:
				var k: String = ROOM[i]
				var px := cx + (i - 1.5) * 26.0 * s * 0.5
				draw_texture_rect(_tx(k), Rect2(Vector2(px, floor_y + 18.0) - Vector2(7, 17) * s * 0.8, Vector2(14, 17) * s * 0.8), false, Color(0.6, 0.6, 0.7, fade))
		"room", "wind", "fire":
			# 樓房：牆、窗、門徒圍坐
			draw_rect(Rect2(0, 0, vs.x, floor_y), Color("2a1c24"))
			for x in range(0, int(vs.x), 24):
				draw_rect(Rect2(x, 0, 1, floor_y), Color("221620"))
			var wx := cx - 30.0
			draw_rect(Rect2(wx, floor_y * 0.22, 60, 50), Color("1a1430"))
			draw_rect(Rect2(wx + 4, floor_y * 0.22 + 4, 52, 42), Color("3a4a80") if sc == "room" else Color("fff4c2"))
			draw_rect(Rect2(wx + 29, floor_y * 0.22 + 4, 2, 42), Color("1a1430"))
			draw_rect(Rect2(0, floor_y, vs.x, vs.y - floor_y), Color("4a3428"))
			for x in range(0, int(vs.x), 18):
				draw_rect(Rect2(x, floor_y, 1, vs.y - floor_y), Color("3a281e"))
			var shake := Vector2(randf_range(-2, 2), 0) if sc == "wind" else Vector2.ZERO
			for i in ROOM.size():
				var k: String = ROOM[i]
				var px := cx + (i - 2) * 30.0 * s * 0.5
				var at := Vector2(px, floor_y + 30.0) + shake - Vector2(7, 17) * s
				draw_texture_rect(_tx(k), Rect2(at, Vector2(14, 17) * s), false, Color(1, 1, 1, fade))
				if sc == "fire" and intro_t > 0.8:
					var hp := at + Vector2(7, -4) * s
					var fl := int(t * 8.0) % 2
					draw_rect(Rect2(hp.x - 3 * s * 0.5, hp.y - fl * 2, 3 * s, 3 * s * 0.8), Color("c8301a"))
					draw_rect(Rect2(hp.x - 2 * s * 0.5, hp.y - 2 * s - fl * 2, 2 * s, 3 * s * 0.8), Color("ff8a2a"))
					draw_rect(Rect2(hp.x - 0.5 * s, hp.y - 3.5 * s - fl * 2, s, 2 * s), Color("ffd75e"))
			if sc == "wind":
				# 大風：一條條白色的風線掃過屋子
				for i in 18:
					var ph := fmod(t * 1.6 + i * 0.29, 1.0)
					var y := fmod(i * 37.0, floor_y + 60.0)
					draw_rect(Rect2(-80 + ph * (vs.x + 160), y, 50 + (i % 3) * 20, 2), Color(1, 1, 1, 0.55))
		"road":
			# 一條路從耶路撒冷往遠方去
			var horizon := vs.y * 0.5
			draw_rect(Rect2(0, 0, vs.x, horizon), Color("24143a"))
			for st in stars:
				var p: Vector2 = (st.p * Vector2(vs.x, horizon)).floor()
				draw_rect(Rect2(p, Vector2(2, 2)), Color("c8b8e8"))
			_hills(vs, horizon, 0.0, Color("1c1226"), 26.0, 0.016)
			draw_rect(Rect2(0, horizon, vs.x, vs.y - horizon), Color("2a1c18"))
			var rows := int((vs.y - horizon) / PX)
			var reveal := clampf(intro_t / 3.0, 0.0, 1.0)
			for r in rows:
				var k := float(r) / rows
				if 1.0 - k > reveal:
					continue
				var half := 4.0 + k * vs.x * 0.3
				draw_rect(Rect2(cx - half, horizon + r * PX, half * 2.0, PX), Color("5a4430") if (r / 3) % 2 == 0 else Color("624a34"))
		_:
			_draw_cut(it, vs, cx, floor_y, s, fade)


# ---------- 章節過場的畫面 ----------
func _draw_cut(it: Dictionary, vs: Vector2, cx: float, floor_y: float, s: float, fade: float) -> void:
	var sc: String = it.scene
	var W := Color(1, 1, 1, fade)
	var shade := Color(0.32, 0.26, 0.34, fade)   # 人群的剪影
	match sc:
		"sky", "stones", "coats", "kneel":
			# 耶路撒冷城外：暗紅的天、城牆的影子
			_bands(vs, floor_y, [Color("1a0c16"), Color("24101c"), Color("2e1420"), Color("3a1a24")])
			draw_rect(Rect2(0, floor_y - 70, vs.x, 70), Color("22141c"))
			for x in range(0, int(vs.x), 30):
				draw_rect(Rect2(x, floor_y - 82, 18, 12), Color("22141c"))
			draw_rect(Rect2(0, floor_y, vs.x, vs.y - floor_y), Color("3a281e"))
			if sc in ["sky", "kneel"]:
				# 天開了：光從上面照下來
				_pillar(cx if sc == "sky" else cx, floor_y + 20.0, fade * (0.9 if sc == "kneel" else 0.7))
				if sc == "sky":
					var jp := Vector2(cx, floor_y * 0.32) - Vector2(7, 17) * s * 0.8
					draw_texture_rect(_tx("jesus"), Rect2(jp, Vector2(14, 17) * s * 0.8), false, Color(1, 1, 1, fade * clampf(intro_t / 1.5, 0.0, 1.0)))
			if sc == "stones":
				for i in 4:
					var sx := cx + (-1 if i < 2 else 1) * (70.0 + (i % 2) * 34.0) * s * 0.4
					_who("disciple", Vector2(sx, floor_y + 34.0), s * 0.9, shade)
				for i in 9:
					var ph := fmod(t * 0.9 + i * 0.37, 1.0)
					var from := Vector2(cx + (-1 if i % 2 == 0 else 1) * 90.0 * s * 0.4, floor_y - 10.0)
					var sp: Vector2 = from.lerp(Vector2(cx + (i % 3 - 1) * 8.0, floor_y), ph) - Vector2(0, sin(ph * PI) * 40.0)
					draw_rect(Rect2(sp.round(), Vector2(2, 2) * s * 0.6), Color(0.6, 0.58, 0.55, fade))
			if sc == "coats":
				# 少年掃羅站著看，腳前一堆衣裳
				_who("paul", Vector2(cx, floor_y + 34.0), s, W)
				var py := floor_y + 34.0
				for i in 4:
					draw_rect(Rect2(cx - 14.0 * s * 0.5 + i * 3.0, py - i * 5.0, 28.0 * s * 0.5 - i * 6.0, 5), [Color("6a4a3a"), Color("8a6a4a"), Color("5a5a7a"), Color("a08060")][i] * Color(1, 1, 1, fade))
				for i in 2:
					_who("disciple", Vector2(cx + (i * 2 - 1) * 60.0 * s * 0.5, floor_y + 20.0), s * 0.8, shade)
			elif sc == "kneel":
				# 跪下：只畫上半身，位置低一點
				var top := Vector2(cx, floor_y + 34.0) - Vector2(7, 12) * s
				draw_texture_rect_region(_tx("stephen"), Rect2(top, Vector2(14, 12) * s), Rect2(0, 0, 14, 12), W)
			else:
				_who("stephen", Vector2(cx, floor_y + 34.0), s, W)
		"scatter", "alone":
			# 往遠方的路：散出去的人
			var horizon := vs.y * 0.5
			_bands(vs, horizon, [Color("1a1430"), Color("24183a"), Color("2f1e44"), Color("3c2650")])
			_hills(vs, horizon, 0.6, Color("1c1226"), 26.0, 0.016)
			draw_rect(Rect2(0, horizon, vs.x, vs.y - horizon), Color("2a1c18"))
			var rows := int((vs.y - horizon) / PX)
			for r in rows:
				var half := 4.0 + float(r) / rows * vs.x * 0.3
				draw_rect(Rect2(cx - half, horizon + r * PX, half * 2.0, PX), Color("5a4430") if (r / 3) % 2 == 0 else Color("624a34"))
			if sc == "alone":
				# 一個人，往遠處走（越走越小）
				var k := clampf(intro_t / 5.5, 0.0, 1.0)
				var y := lerpf(vs.y * 0.7, horizon + 26.0, k)
				_who("paul", Vector2(cx, y), s * lerpf(1.0, 0.45, k), W)
			else:
				var who: Array = it.get("who", ["disciple"])
				for i in who.size():
					_who(who[i], Vector2(cx + (i - (who.size() - 1) / 2.0) * 22.0 * s * 0.5, vs.y * 0.68 - absf(i - (who.size() - 1) / 2.0) * 10.0), s, W)
		"wall":
			# 大馬士革的城牆，夜裡；第二幕筐子慢慢縋下去
			_bands(vs, floor_y, [Color("0b0716"), Color("120a22"), Color("1a0f2e")])
			for st in stars:
				draw_rect(Rect2((st.p * Vector2(vs.x, floor_y * 0.6)).floor(), Vector2(2, 2)), Color("c8b8e8"))
			var wx := cx - 10.0
			var wall_top := floor_y * 0.35
			draw_rect(Rect2(0, wall_top, wx, vs.y - wall_top), Color("3a3040"))
			for y in range(int(wall_top), int(vs.y), 12):
				draw_rect(Rect2(0, y, wx, 1), Color("2a2230"))
			draw_rect(Rect2(0, floor_y + 40.0, vs.x, vs.y), Color("1a1220"))
			_who("disciple", Vector2(wx - 30.0, wall_top), s * 0.7, shade)
			_who("disciple", Vector2(wx - 70.0, wall_top), s * 0.7, shade)
			var drop := clampf(intro_t / 4.5, 0.0, 1.0) * (floor_y + 10.0 - wall_top) if it.get("lower", false) else 0.0
			var by := wall_top + 6.0 + drop
			draw_rect(Rect2(wx + 18.0, wall_top - 6.0, 2, by - wall_top + 6.0), Color("a08060"))
			# 筐子裡露出掃羅的頭
			var head := Vector2(wx + 19.0, by) - Vector2(7, 8) * s
			draw_texture_rect_region(_tx("paul"), Rect2(head, Vector2(14, 8) * s), Rect2(0, 0, 14, 8), W)
			draw_rect(Rect2(wx + 19.0 - 9.0 * s * 0.5, by - 2.0, 18.0 * s * 0.5, 7.0 * s * 0.6), Color("8a6a3a") * Color(1, 1, 1, fade))
			for i in 4:
				draw_rect(Rect2(wx + 19.0 - 9.0 * s * 0.5 + i * 4.5 * s * 0.5, by - 2.0, 1, 7.0 * s * 0.6), Color("5a4020"))
		"meet", "rome", "letters":
			# 屋子裡
			draw_rect(Rect2(0, 0, vs.x, floor_y), Color("2a1c24") if sc == "meet" else Color("2c2420"))
			for x in range(0, int(vs.x), 24):
				draw_rect(Rect2(x, 0, 1, floor_y), Color("221620"))
			draw_rect(Rect2(cx - 30.0, floor_y * 0.22, 60, 50), Color("1a1430"))
			draw_rect(Rect2(cx - 26.0, floor_y * 0.22 + 4, 52, 42), Color("7a9ac8") if sc != "meet" else Color("3a4a80"))
			draw_rect(Rect2(0, floor_y, vs.x, vs.y - floor_y), Color("4a3428"))
			var fy := floor_y + 34.0
			if sc == "meet":
				_who("peter", Vector2(cx + 34.0 * s * 0.5, fy), s, W)
				_who("barn", Vector2(cx - 4.0 * s * 0.5, fy), s, W)
				_who("paul", Vector2(cx - 40.0 * s * 0.5, fy), s, W)
				_who("disciple", Vector2(cx + 64.0 * s * 0.5, fy - 12.0), s * 0.85, shade)
			else:
				var px := cx - (10.0 if sc == "letters" else 0.0) * s * 0.5
				_who("paul", Vector2(px, fy), s, W)
				# 鎖鏈：從手腕連到牆邊
				var wr := Vector2(px - 5.0 * s, fy - 7.0 * s)
				var n := 6
				for i in n:
					var cp := wr.lerp(Vector2(4.0, wr.y + 10.0), float(i) / n)
					draw_rect(Rect2(cp.round(), Vector2(4, 3)), Color(0.62, 0.62, 0.66, fade))
				if sc == "rome":
					_who("luke", Vector2(cx - 34.0 * s * 0.5, fy - 8.0), s * 0.9, W)
					var come := clampf(intro_t / 3.0, 0.0, 1.0)
					_who("disciple", Vector2(lerpf(vs.x + 30.0, cx + 34.0 * s * 0.5, come), fy), s, W)
					_who("disciple", Vector2(lerpf(vs.x + 80.0, cx + 60.0 * s * 0.5, come), fy - 6.0), s * 0.9, W)
				else:
					_who("luke", Vector2(cx + 30.0 * s * 0.5, fy), s, W)
					# 桌上的信：一行一行寫出來
					var tx := cx + 4.0 * s
					draw_rect(Rect2(tx - 4.0 * s, fy - 4.0 * s, 16.0 * s, 4.0 * s), Color("5a3a24"))
					draw_rect(Rect2(tx - 3.0 * s, fy - 5.0 * s, 9.0 * s, 2.0 * s), Color("e8dcc0"))
					var lines := int(clampf(intro_t / 0.8, 0.0, 4.0))
					for i in lines:
						draw_rect(Rect2(tx - 2.5 * s, fy - 4.7 * s + i * 2.0, 7.0 * s - (i % 2) * 6.0, 1), Color("5a3a24"))
		"years":
			# 很多年：星星轉動，空的路
			var horizon := vs.y * 0.55
			_bands(vs, horizon, [Color("0b0716"), Color("120a22"), Color("1a0f2e"), Color("24143a")])
			for st in stars:
				var a: float = st.p.x * TAU + t * 0.08
				var r: float = (0.2 + st.p.y) * vs.x * 0.7
				var p := Vector2(cx + cos(a) * r, horizon * 0.2 + sin(a) * r * 0.5)
				if p.y < horizon:
					draw_rect(Rect2(p.floor(), Vector2(2, 2)), Color("c8b8e8") * Color(1, 1, 1, fade))
			_hills(vs, horizon, 0.0, Color("1c1226"), 26.0, 0.016)
			draw_rect(Rect2(0, horizon, vs.x, vs.y - horizon), Color("2a1c18"))
			var rows := int((vs.y - horizon) / PX)
			for r in rows:
				var half := 4.0 + float(r) / rows * vs.x * 0.3
				draw_rect(Rect2(cx - half, horizon + r * PX, half * 2.0, PX), Color("5a4430") if (r / 3) % 2 == 0 else Color("624a34"))
		"sea":
			# 拔摩海島：海、岩石、年老的約翰；後來天上有光
			var horizon := vs.y * 0.5
			_bands(vs, horizon, [Color("10183a"), Color("182448"), Color("223058"), Color("2c3c64")])
			if intro_t > 2.0:
				_pillar(cx, floor_y + 10.0, fade * clampf((intro_t - 2.0) / 1.5, 0.0, 1.0))
			draw_rect(Rect2(0, horizon, vs.x, vs.y - horizon), Color("1a2a4a"))
			for i in 24:
				var wy := horizon + 6.0 + (i % 8) * (vs.y - horizon) / 8.0
				var wx := fmod(i * 97.0 + t * (12.0 + (i % 3) * 6.0), vs.x + 60.0) - 30.0
				draw_rect(Rect2(wx, wy, 18 + (i % 4) * 6, 2), Color("3a5a8a"))
			var iy := floor_y + 20.0
			draw_rect(Rect2(cx - 90.0, iy, 180.0, 40.0), Color("3a3038"))
			draw_rect(Rect2(cx - 60.0, iy - 14.0, 110.0, 16.0), Color("4a3e44"))
			_who("john", Vector2(cx, iy), s, W)


## 一個人：腳底中心在 foot
func _who(k: String, foot: Vector2, s: float, col: Color) -> void:
	var at := foot - Vector2(7, 17) * s
	draw_texture_rect(_tx(k), Rect2(at, Vector2(14, 17) * s), false, col)


func _tx(k: String) -> Texture2D:
	var key := "%s_0" % k
	if not tex.has(key):
		tex[key] = load("res://assets/sprites/%s.png" % key)
	return tex[key]


## 一條條實心色帶的天空
func _bands(vs: Vector2, h: float, cols: Array) -> void:
	var bh := h / cols.size()
	for i in cols.size():
		draw_rect(Rect2(0, i * bh, vs.x, bh + 1), cols[i])


## 從天上照下來的光柱
func _pillar(cx: float, bottom: float, a: float) -> void:
	for i in 5:
		var w := 64.0 - i * 12.0
		var c: Color = [Color("6a5a50"), Color("a89060"), Color("e8d090"), Color("fff0c0"), Color("fffbe8")][i]
		draw_rect(Rect2(cx - w / 2.0, 0, w, bottom), Color(c, 0.25 + i * 0.12) * Color(1, 1, 1, a))


# ---------- 背景（全部用實心色塊畫，像素風） ----------
func _draw() -> void:
	var vs := get_viewport().get_visible_rect().size
	var horizon := vs.y * (0.55 if portrait else 0.58)
	# 夜空：由深到淺的色帶（不用漸層，一條條實心色）
	if intro_i >= 0:
		_draw_intro(vs)
		return
	var bands := [Color("0b0716"), Color("120a22"), Color("1a0f2e"), Color("24143a"), Color("2f1a44"), Color("3c214c"), Color("4a2a50")]
	if dawn:
		# 新天新地：不再有黑夜（啟 22:5）
		bands = [Color("3a6aa8"), Color("5a86b8"), Color("7aa0c4"), Color("a8bcc8"), Color("d8c8b0"), Color("f0d0a0"), Color("ffe0a8")]
	var bh := horizon / bands.size()
	for i in bands.size():
		draw_rect(Rect2(0, i * bh, vs.x, bh + 1), bands[i])
	# 星星（清晨就沒有了）
	for s in stars:
		if dawn:
			break
		var on := sin(t * 1.6 + s.ph) > -0.6
		if not on:
			continue
		var p: Vector2 = (s.p * Vector2(vs.x, horizon)).floor()
		var c := Color("fff4c2") if s.big else Color("c8b8e8")
		draw_rect(Rect2(p, Vector2(PX, PX) if s.big else Vector2(2, 2)), c)
	# 遠方的光（地極的盡頭）：一道從地平線升起的光柱
	var cx := vs.x * 0.5
	for i in 5:
		var w := (70.0 - i * 13.0) * (1.0 + 0.04 * sin(t * 1.2))
		draw_rect(Rect2(cx - w / 2.0, 0, w, horizon), [Color(0.55, 0.42, 0.32, 0.18), Color(0.75, 0.6, 0.38, 0.18), Color(0.95, 0.82, 0.5, 0.2), Color(1, 0.95, 0.7, 0.25), Color(1, 1, 0.9, 0.35)][i])
	# 遠山：兩層剪影
	_hills(vs, horizon, 0.0, Color("6a8a6a") if dawn else Color("2a1a34"), 34.0, 0.013)
	_hills(vs, horizon, 1.7, Color("4a6a4a") if dawn else Color("1c1226"), 22.0, 0.021)
	# 地面
	draw_rect(Rect2(0, horizon, vs.x, vs.y - horizon), Color("4a5a30") if dawn else Color("2a1c18"))
	draw_rect(Rect2(0, horizon, vs.x, PX * 2), Color("6a7a40") if dawn else Color("3a2820"))
	# 往地平線的路（梯形，一格一格往上收窄）
	var rows := int((vs.y - horizon) / PX)
	for r in rows:
		var y := horizon + r * PX
		var k := float(r) / rows
		var half := 6.0 + k * vs.x * 0.32
		draw_rect(Rect2(cx - half, y, half * 2.0, PX), Color("5a4430") if (r / 3) % 2 == 0 else Color("624a34"))
		if r % 9 == 0:
			draw_rect(Rect2(cx - 1.5, y, 3, PX), Color("7a6040"))
	# 一群人在路上往光裡走（原地走路的動畫）
	var scale := 4.0 if portrait else 3.5
	var base_y := horizon + (70.0 if portrait else 46.0)
	var mid := (walkers.size() - 1) / 2.0
	var order: Array = range(walkers.size())
	order.sort_custom(func(a, b): return absf(a - mid) > absf(b - mid))   # 後面的先畫
	for i in order:
		var k: String = walkers[i]
		var f: int = (int(t * 4.0) + i) % 2
		var off: Vector2 = Vector2((i - mid) * 15.0 * scale * 0.55, -absf(i - mid) * 6.0 * scale * 0.4)
		var at := Vector2(cx, base_y) + off - Vector2(7, 17) * scale
		draw_rect(Rect2(at + Vector2(2, 15.5) * scale, Vector2(10, 2) * scale), Color(0, 0, 0, 0.35))
		draw_texture_rect(tex["%s_%d" % [k, f]], Rect2(at, Vector2(14, 17) * scale), false)


func _hills(vs: Vector2, horizon: float, ph: float, col: Color, amp: float, freq: float) -> void:
	var x := 0.0
	while x < vs.x:
		var h := amp * (0.6 + 0.4 * sin(x * freq + ph) + 0.25 * sin(x * freq * 2.7 + ph * 2.0))
		h = floor(h / PX) * PX
		draw_rect(Rect2(x, horizon - h, PX * 2, h + 1), col)
		x += PX * 2


func _auto_shot(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(path.replace(".png", "_title.png"))
	_toggle_settings()
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(path.replace(".png", "_settings.png"))
	_toggle_settings()
	_start_intro()
	for i in [0, 2, 3, 4, 5]:
		intro_i = i - 1
		_next_intro()
		intro_t = 2.0
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png(path.replace(".png", "_intro%d.png" % i))
	# 章節過場：每一幕都拍一張（intro_t 停在 3.5 秒，讓會動的東西動到一半）
	for id in CUTS:
		_start_intro(id)
		for i in cut.size():
			intro_i = i
			intro_label.text = cut[i].text
			intro_t = 3.5
			await get_tree().create_timer(0.25).timeout
			intro_t = 3.5
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%s%d.png" % [id, i]))
	get_tree().quit()
