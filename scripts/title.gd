extends Control
## 標題畫面：遊戲開啟後的第一個畫面。夜空、遠山、往地平線延伸的路，一群人跟著保羅往光裡走。
## 「開始」進營地；「設定」切音樂、音效、特效精簡、字大一點。手機返回鍵在這裡是離開遊戲。

const WALKERS := ["silas", "tim", "paul", "luke", "barn"]   # 保羅在中間最前面
const PX := 3.0             # 像素放大倍數（背景用的「一格」）

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
	for k in WALKERS:
		for f in 2:
			tex["%s_%d" % [k, f]] = load("res://assets/sprites/%s_%d.png" % [k, f])
	_build()
	Sfx.music("camp")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_auto_shot(a.substr(7))


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

	var ver := UIKit.label(_version(), 10, UIKit.MUTED)
	add_child(ver)
	ver.position = Vector2(8, vs.y - 20)


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
	queue_redraw()


# ---------- 背景（全部用實心色塊畫，像素風） ----------
func _draw() -> void:
	var vs := get_viewport().get_visible_rect().size
	var horizon := vs.y * (0.55 if portrait else 0.58)
	# 夜空：由深到淺的色帶（不用漸層，一條條實心色）
	var bands := [Color("0b0716"), Color("120a22"), Color("1a0f2e"), Color("24143a"), Color("2f1a44"), Color("3c214c"), Color("4a2a50")]
	var bh := horizon / bands.size()
	for i in bands.size():
		draw_rect(Rect2(0, i * bh, vs.x, bh + 1), bands[i])
	# 星星
	for s in stars:
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
	_hills(vs, horizon, 0.0, Color("2a1a34"), 34.0, 0.013)
	_hills(vs, horizon, 1.7, Color("1c1226"), 22.0, 0.021)
	# 地面
	draw_rect(Rect2(0, horizon, vs.x, vs.y - horizon), Color("2a1c18"))
	draw_rect(Rect2(0, horizon, vs.x, PX * 2), Color("3a2820"))
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
	for i in [0, 4, 1, 3, 2]:   # 後面的先畫
		var k: String = WALKERS[i]
		var f: int = (int(t * 4.0) + i) % 2
		var off: Vector2 = Vector2((i - 2) * 15.0 * scale * 0.55, -abs(i - 2) * 6.0 * scale * 0.4)
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
	get_tree().quit()
