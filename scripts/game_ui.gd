class_name GameUI
extends CanvasLayer
## 畫面上的介面：血量、經驗、時間、同心合意、名牌、搖桿、升級卡、FEVER 按鈕、失敗畫面。

signal card_chosen(index: int)
signal fever_pressed
signal restart_pressed
signal home_pressed
signal reroll_pressed
signal pause_pressed
signal resume_pressed
signal chest_closed

const C_INK := Color("f4ead2")
const C_GOLD := Color("ffd75e")
const C_CREAM := Color("fff4c2")
const C_SKY := Color("4fd8ff")
const C_HEAL := Color("7be08a")
const C_RED := Color("e8481c")
const C_BRONZE := Color("c9a46b")
const C_FLAME := Color("ff8a2a")
const C_DARK := Color("0b080d")

var font: SystemFont
var root: Control
var hp_fill: ColorRect
var xp_fill: ColorRect
var lv_label: Label
var time_label: Label
var kill_label: Label
var hint_label: Label
var meter_bg: ColorRect
var meter_fill: ColorRect
var meter_label: Label
var fever_label: Label
var fever_btn: Button
var tint: ColorRect
var flash: ColorRect
var joy_pad: Control
var names := {}
var cards_box: BoxContainer
var card_buttons: Array = []
var card_ready_at := 0.0
var joy := {"on": false, "origin": Vector2.ZERO, "pos": Vector2.ZERO}
var banner: Label
var banner_until := 0.0
var boss_bg: ColorRect
var boss_fill: ColorRect
var boss_label: Label
var chest_panel: Control


func setup(name_list: Array, touch: bool) -> void:
	font = SystemFont.new()
	font.font_weight = 500
	font.font_names = PackedStringArray(["Noto Sans CJK TC", "Noto Sans TC", "Microsoft JhengHei", "PingFang TC", "Heiti TC", "sans-serif"])
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	tint = _rect(Color(1.0, 0.6, 0.15, 0.0), Vector2.ZERO, Vector2.ONE)
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)

	label("保羅", 13, C_GOLD).position = Vector2(12, 4)
	_rect(C_DARK, Vector2(10, 26), Vector2(124, 9))
	hp_fill = _rect(C_HEAL, Vector2(12, 28), Vector2(120, 5))
	lv_label = label("Lv.1", 11, C_SKY)
	lv_label.position = Vector2(12, 37)
	_rect(C_DARK, Vector2(48, 41), Vector2(86, 6))
	xp_fill = _rect(C_SKY, Vector2(49, 42), Vector2(0, 4))
	time_label = label("00:00", 16, C_CREAM)
	kill_label = label("驅散 0", 13, C_INK)
	pause_btn = UIKit.button("Ⅱ", 14)
	pause_btn.custom_minimum_size = Vector2(34, 30)
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	root.add_child(pause_btn)

	for n in name_list:
		var l := label(n, 11, C_GOLD if n == "保羅" else C_INK, 2)
		l.modulate.a = 0.85
		names[n] = l

	meter_bg = _rect(C_DARK, Vector2.ZERO, Vector2(204, 10))
	meter_fill = _rect(C_FLAME, Vector2.ZERO, Vector2(0, 6))
	meter_label = label("同心合意", 12, C_INK)
	fever_label = label("", 12, C_GOLD)

	fever_btn = Button.new()
	fever_btn.text = "五旬節"
	fever_btn.custom_minimum_size = Vector2(96, 44)
	fever_btn.add_theme_font_override("font", font)
	fever_btn.add_theme_font_size_override("font_size", 16)
	fever_btn.add_theme_stylebox_override("normal", _box(Color("c4421a"), C_GOLD))
	fever_btn.add_theme_stylebox_override("hover", _box(Color("e0582a"), C_CREAM))
	fever_btn.add_theme_stylebox_override("pressed", _box(C_GOLD, C_CREAM))
	fever_btn.add_theme_color_override("font_color", C_CREAM)
	fever_btn.visible = false
	fever_btn.pressed.connect(func(): fever_pressed.emit())
	root.add_child(fever_btn)

	hint_label = label("按住畫面下方拖曳來移動" if touch else "WASD／方向鍵移動　同心合意滿了按空白鍵", 12, C_CREAM)

	joy_pad = Control.new()
	joy_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_pad.draw.connect(_draw_joy)
	root.add_child(joy_pad)

	banner = label("", 18, C_GOLD)
	banner.visible = false
	boss_bg = _rect(C_DARK, Vector2.ZERO, Vector2(244, 8))
	boss_fill = _rect(Color("b8b8c4"), Vector2.ZERO, Vector2(240, 4))
	boss_label = label("", 12, Color("d8d8e8"))
	set_boss(-1.0, "")

	flash = _rect(Color(1, 0.96, 0.8, 0.0), Vector2.ZERO, Vector2.ONE)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)


func label(text: String, size: int, color: Color, outline := 2) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size + 2
	ls.font_color = color
	# 中文筆畫多，外框太粗會糊在一起：用細外框＋往右下的陰影
	ls.outline_size = mini(outline, 2)
	ls.outline_color = Color("140c10", 0.85)
	ls.shadow_size = 0
	ls.shadow_offset = Vector2(1, 1)
	ls.shadow_color = Color(0, 0, 0, 0.6)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func _rect(c: Color, pos: Vector2, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	return r


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func vp() -> Vector2:
	return get_viewport().get_visible_rect().size


# ---------- 每幀更新 ----------
var build_label: Label
var pause_btn: Button
var pause_box: Control
var task_label: Label


func update_hud(st: Dictionary) -> void:
	var size := vp()
	hp_fill.size.x = roundf(120.0 * st.hp_frac)
	hp_fill.color = C_HEAL if st.hp_frac > 0.35 else C_RED
	lv_label.text = "Lv.%d" % st.level
	xp_fill.size.x = roundf(84.0 * st.xp_frac)
	var s: int = st.time
	time_label.text = "%02d:%02d" % [s / 60, s % 60]
	time_label.position = Vector2(roundf((size.x - time_label.size.x) / 2.0), 4)
	kill_label.text = "驅散 %d" % st.kills
	pause_btn.position = Vector2(size.x - 42.0, 4)
	pause_btn.visible = not st.over
	kill_label.position = Vector2(size.x - kill_label.size.x - 52.0, 4)
	hint_label.modulate.a = clampf((10.0 - st.time) / 2.0, 0.0, 1.0)
	hint_label.position = Vector2(roundf((size.x - hint_label.size.x) / 2.0), size.y - 70.0)

	# 同心合意
	var mx := roundf((size.x - 204.0) / 2.0)
	var my := size.y - 22.0
	meter_bg.position = Vector2(mx, my)
	meter_fill.position = Vector2(mx + 2, my + 2)
	meter_fill.size.x = roundf(200.0 * st.meter)
	var fever_on: bool = st.fever > 0.0
	meter_fill.color = C_GOLD if fever_on or st.meter >= 1.0 else C_FLAME
	meter_label.text = "五旬節！" if fever_on else "同心合意"
	meter_label.label_settings.font_color = C_GOLD if fever_on or st.meter >= 1.0 else C_INK
	meter_label.position = Vector2(mx - meter_label.size.x - 8.0, my - 6.0)
	fever_label.visible = fever_on
	if fever_on:
		fever_label.text = "FEVER ×%d" % st.fever_kills
		fever_label.position = Vector2(roundf((size.x - fever_label.size.x) / 2.0), 26)
	fever_btn.visible = st.meter >= 1.0 and not fever_on and not st.over and not st.choosing
	fever_btn.position = Vector2(roundf((size.x - fever_btn.size.x) / 2.0), my - 54.0)
	tint.color.a = 0.14 if fever_on else 0.0
	if build_label == null:
		build_label = label("", 10, C_CREAM)
	build_label.text = st.get("build", "")
	build_label.position = Vector2(12, 52)
	if task_label == null:
		task_label = label("", 10, C_INK)
	task_label.text = st.get("tasks", "")
	if size.y > size.x:
		# 直式：任務排在左邊、同工與連結的下面
		task_label.position = Vector2(12, build_label.position.y + (build_label.size.y + 4.0 if build_label.text != "" else 0.0))
	else:
		task_label.position = Vector2(size.x - task_label.size.x - 12.0, 30)
	var now := Time.get_ticks_msec() / 1000.0
	banner.visible = now < banner_until
	if banner.visible:
		banner.position = Vector2(roundf((size.x - banner.size.x) / 2.0), 64)
		banner.modulate.a = clampf((banner_until - now) * 2.0, 0.0, 1.0)
	if boss_bg.visible:
		boss_bg.position = Vector2(roundf((size.x - 244.0) / 2.0), 48)
		boss_fill.position = boss_bg.position + Vector2(2, 2)
		boss_label.position = Vector2(boss_bg.position.x - boss_label.size.x - 8.0, 41)
	flash.color.a = maxf(0.0, flash.color.a - 0.04)
	joy_pad.queue_redraw()


func show_banner(text: String, secs: float) -> void:
	banner.text = text
	banner_until = Time.get_ticks_msec() / 1000.0 + secs


func set_boss(frac: float, boss_name: String) -> void:
	var on := frac >= 0.0
	boss_bg.visible = on
	boss_fill.visible = on
	boss_label.visible = on
	if on:
		boss_fill.size.x = roundf(240.0 * frac)
		boss_label.text = boss_name


func show_chest(results: Array) -> void:
	chest_panel = PanelContainer.new()
	chest_panel.add_theme_stylebox_override("panel", _box(Color("241a2e"), C_GOLD))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	chest_panel.add_child(box)
	root.add_child(chest_panel)
	var head := label("寶箱", 18, C_GOLD)
	root.remove_child(head)
	box.add_child(head)
	for r in results:
		var l := label("%s\n%s" % [r.title, r.desc], 15 if r.big else 13, C_GOLD if r.big else C_INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(260, 0)
		root.remove_child(l)
		box.add_child(l)
	var btn := Button.new()
	btn.text = "繼續"
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_stylebox_override("normal", _box(C_BRONZE, C_DARK))
	btn.add_theme_stylebox_override("focus", _box(C_GOLD, C_DARK))
	btn.add_theme_color_override("font_color", Color("2a1a14"))
	btn.add_theme_color_override("font_focus_color", Color("2a1a14"))
	btn.add_theme_color_override("font_hover_color", Color("2a1a14"))
	btn.pressed.connect(_close_chest)
	box.add_child(btn)
	await get_tree().process_frame
	if chest_panel == null:
		return
	chest_panel.position = ((vp() - chest_panel.size) / 2.0).round()
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(btn):
		btn.grab_focus()


func _close_chest() -> void:
	if chest_panel:
		chest_panel.queue_free()
		chest_panel = null
		chest_closed.emit()


## 失敗彩蛋：光的身影蹲到保羅身邊，留下一個籃子
func play_egg(baskets: int, paul_screen: Vector2) -> void:
	for n in names:
		names[n].visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var light := Control.new()
	light.set_anchors_preset(Control.PRESET_FULL_RECT)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(light)
	var st := {"x": vp().x + 40.0, "a": 0.0, "crouch": false, "basket": 0.0}
	light.draw.connect(func():
		var gy := paul_screen.y
		var fx: float = st.x
		var a: float = st.a
		for i in 6:
			light.draw_circle(Vector2(fx, gy - 18), 40.0 - i * 6.0, Color(1.0, 0.85, 0.5, a * 0.06))
		if st.crouch:
			light.draw_circle(Vector2(fx, gy - 22), 5.0, Color(1, 0.97, 0.85, a))
			light.draw_rect(Rect2(fx - 7, gy - 16, 14, 14), Color(1, 0.95, 0.8, a))
		else:
			light.draw_circle(Vector2(fx, gy - 34), 5.0, Color(1, 0.97, 0.85, a))
			light.draw_rect(Rect2(fx - 6, gy - 28, 12, 26), Color(1, 0.95, 0.8, a))
		if st.basket > 0.0:
			var bx := paul_screen.x + 22.0
			var ba: float = st.basket
			light.draw_rect(Rect2(bx - 8, gy - 8, 16, 8), Color(0.65, 0.48, 0.27, ba))
			light.draw_rect(Rect2(bx - 6, gy - 11, 12, 3), Color(0.94, 0.78, 0.47, ba))
			light.draw_arc(Vector2(bx, gy - 9), 7.0, PI, TAU, 12, Color(0.35, 0.25, 0.15, ba), 1.5)
	)
	var tw := create_tween()
	tw.tween_property(dim, "color:a", 0.82, 1.0)
	tw.parallel().tween_method(func(v): st.a = v; light.queue_redraw(), 0.0, 1.0, 1.0)
	tw.tween_method(func(v): st.x = v; light.queue_redraw(), vp().x + 40.0, paul_screen.x + 22.0, 2.0)
	tw.tween_callback(func(): st.crouch = true; light.queue_redraw())
	await tw.finished
	var verse := label("我的恩典夠你用的，\n因為我的能力是在人的軟弱上顯得完全。", 15, C_CREAM)
	verse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ref := label("林後 12:9", 12, C_GOLD)
	await get_tree().process_frame
	verse.position = Vector2(roundf((vp().x - verse.size.x) / 2.0), roundf(vp().y * 0.18))
	ref.position = Vector2(roundf((vp().x - ref.size.x) / 2.0), verse.position.y + verse.size.y + 6.0)
	await get_tree().create_timer(3.5).timeout
	var tw2 := create_tween()
	tw2.tween_callback(func(): st.crouch = false)
	tw2.tween_method(func(v): st.basket = v; light.queue_redraw(), 0.0, 1.0, 0.6)
	tw2.tween_method(func(v): st.x = v; light.queue_redraw(), paul_screen.x + 22.0, vp().x + 60.0, 1.8)
	tw2.parallel().tween_method(func(v): st.a = v; light.queue_redraw(), 1.0, 0.0, 1.8)
	await tw2.finished
	var b := label("籃子 %d／12" % baskets, 13, C_GOLD)
	b.position = paul_screen + Vector2(4, 6)
	await get_tree().create_timer(1.6).timeout
	for n in [verse, ref, b, light, dim]:
		n.queue_free()


func place_name(n: String, screen_pos: Vector2, show: bool) -> void:
	var l: Label = names[n]
	l.visible = show
	l.position = (screen_pos + Vector2(-l.size.x / 2.0, 2.0)).round()


func do_flash(a: float) -> void:
	flash.color.a = a


func _draw_joy() -> void:
	if not joy.on:
		return
	joy_pad.draw_arc(joy.origin, 36.0, 0.0, TAU, 48, Color(C_CREAM, 0.5), 2.0)
	var d: Vector2 = joy.pos - joy.origin
	if d.length() > 36.0:
		d = d.normalized() * 36.0
	joy_pad.draw_circle(joy.origin + d, 14.0, Color(C_CREAM, 0.45))


# ---------- 升級卡 ----------
func show_cards(cards: Array, now: float, delay: float, rerolls := 0) -> void:
	hide_cards()
	var size := vp()
	var portrait := size.y > size.x
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.08, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.name = "CardDim"
	root.add_child(dim)
	var title := label("升級！選一個", 20, C_GOLD)
	title.name = "CardTitle"
	title.position = Vector2(roundf((size.x - 140) / 2.0), 34 if not portrait else 90)
	cards_box = VBoxContainer.new() if portrait else HBoxContainer.new()
	cards_box.add_theme_constant_override("separation", 10)
	root.add_child(cards_box)
	card_buttons.clear()
	for i in cards.size():
		var c: Dictionary = cards[i]
		var b := Button.new()
		b.text = "%d　%s\n【%s】\n%s" % [i + 1, c.title, c.tag, c.desc]
		b.custom_minimum_size = Vector2(300, 74) if portrait else Vector2(184, 150)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT if portrait else HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", C_INK)
		b.add_theme_color_override("font_hover_color", C_CREAM)
		b.add_theme_stylebox_override("normal", _box(Color("241a2e"), C_BRONZE))
		b.add_theme_stylebox_override("hover", _box(Color("3a2a40"), C_GOLD))
		b.add_theme_stylebox_override("focus", _box(Color("3a2a40"), C_GOLD))
		b.add_theme_stylebox_override("pressed", _box(Color("5a4420"), C_CREAM))
		b.add_theme_stylebox_override("disabled", _box(Color("241a2e"), C_BRONZE))
		b.add_theme_color_override("font_disabled_color", C_INK)
		var idx := i
		b.pressed.connect(func(): pick(idx))
		cards_box.add_child(b)
		card_buttons.append(b)
	# 剛跳出時先鎖住（變暗），避免滑動移動時手指誤觸
	for b in card_buttons:
		b.disabled = true
		b.modulate.a = 0.55
	await get_tree().process_frame
	if cards_box == null:
		return
	cards_box.position = ((size - cards_box.size) / 2.0).round() + Vector2(0, 14)
	card_ready_at = now + delay
	var my_id := cards_box.get_instance_id()
	get_tree().create_timer(delay, true).timeout.connect(func():
		if cards_box == null or cards_box.get_instance_id() != my_id:
			return
		for b in card_buttons:
			if is_instance_valid(b):
				b.disabled = false
				b.modulate.a = 1.0
		if not card_buttons.is_empty() and is_instance_valid(card_buttons[0]):
			card_buttons[0].grab_focus())
	if rerolls > 0:
		var rb := UIKit.button("重抽（R）　剩 %d 次" % rerolls, 13)
		rb.name = "CardReroll"
		rb.focus_mode = Control.FOCUS_NONE
		rb.custom_minimum_size = Vector2(160, 32)
		rb.pressed.connect(func():
			if Time.get_ticks_msec() / 1000.0 >= card_ready_at:
				reroll_pressed.emit())
		root.add_child(rb)
		rb.position = Vector2(roundf((size.x - 160) / 2.0), cards_box.position.y + cards_box.size.y + 10)


## 暫停選單
func show_pause(build_text: String) -> void:
	hide_pause()
	var size := vp()
	pause_box = Control.new()
	pause_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(pause_box)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.06, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_box.add_child(dim)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pause_box.add_child(v)
	var title := UIKit.label("暫停", 22, C_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	if build_text != "":
		var b := UIKit.label(build_text, 11, C_CREAM)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(b)
	var go := UIKit.button("繼續（Esc）", 16, true)
	go.custom_minimum_size = Vector2(200, 40)
	go.pressed.connect(func(): resume_pressed.emit())
	v.add_child(go)
	var re := UIKit.button("放棄，重新開始", 14)
	re.custom_minimum_size = Vector2(200, 34)
	re.pressed.connect(func(): restart_pressed.emit())
	v.add_child(re)
	var home := UIKit.button("放棄，回安提阿", 14)
	home.custom_minimum_size = Vector2(200, 34)
	home.pressed.connect(func(): home_pressed.emit())
	v.add_child(home)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for kind in [["sfx", "音效"], ["music", "音樂"]]:
		var tb := UIKit.button("", 13)
		tb.custom_minimum_size = Vector2(96, 30)
		var k: String = kind[0]
		var nm: String = kind[1]
		var refresh := func(): tb.text = "%s：%s" % [nm, "開" if Save.data.get(k + "_on", true) else "關"]
		refresh.call()
		tb.pressed.connect(func():
			Sfx.toggle(k)
			refresh.call())
		row.add_child(tb)
	var note := UIKit.label("放棄會照失敗結算（見證減半）", 10, UIKit.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	await get_tree().process_frame
	if is_instance_valid(v):
		v.position = ((size - v.size) / 2.0).round()
		go.grab_focus()


func hide_pause() -> void:
	if pause_box != null and is_instance_valid(pause_box):
		root.remove_child(pause_box)
		pause_box.queue_free()
	pause_box = null


func pick(i: int) -> void:
	if card_buttons.is_empty() or Time.get_ticks_msec() / 1000.0 < card_ready_at:
		return
	hide_cards()
	card_chosen.emit(i)


func hide_cards() -> void:
	for n in ["CardDim", "CardTitle", "CardReroll"]:
		var node := root.get_node_or_null(n)
		if node:
			root.remove_child(node)
			node.queue_free()
	if cards_box:
		cards_box.queue_free()
		cards_box = null
	card_buttons.clear()


# ---------- 失敗 ----------
func show_game_over(lines: Array, button_text := "再出發") -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.06, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)
	for row in lines:
		var l := label(row[0], row[1], row[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.remove_child(l)
		box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var home := UIKit.button("回安提阿", 16)
	home.custom_minimum_size = Vector2(140, 40)
	home.pressed.connect(func(): home_pressed.emit())
	row.add_child(home)
	var btn := UIKit.button(button_text, 16, true)
	btn.custom_minimum_size = Vector2(140, 40)
	btn.pressed.connect(func(): restart_pressed.emit())
	row.add_child(btn)
	for n in names:
		names[n].visible = false
	await get_tree().process_frame
	box.position = ((vp() - box.size) / 2.0).round()
	btn.grab_focus()
