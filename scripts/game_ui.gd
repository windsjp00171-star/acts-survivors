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
signal dialogue_done

const C_INK := Color("f4ead2")
const C_GOLD := Color("ffd75e")
const C_CREAM := Color("fff4c2")
const C_SKY := Color("4fd8ff")
const C_HEAL := Color("7be08a")
const C_RED := Color("e8481c")
const C_BRONZE := Color("c9a46b")
const C_FLAME := Color("ff8a2a")
const C_DARK := Color("0b080d")

var font: Font
var root: Control
var dlg_box: PanelContainer   # 城市的劇情對話
var dlg_lines: Array = []
var dlg_i := 0
var hp_fill: ColorRect
var xp_fill: ColorRect
var lv_label: Label
var time_label: Label
var boss_in_label: Label
var tip_box: PanelContainer
var tip_label: Label
var tip_until := 0.0
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
var hero_label: Label      # 左上角主角名字
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
	font = UIKit.font()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	tint = _rect(Color(1.0, 0.6, 0.15, 0.0), Vector2.ZERO, Vector2.ONE)
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)

	hero_label = label(name_list[0], 13, C_GOLD)
	hero_label.position = Vector2(12, 4)
	_rect(C_DARK, Vector2(10, 26), Vector2(124, 9))
	hp_fill = _rect(C_HEAL, Vector2(12, 28), Vector2(120, 5))
	lv_label = label("Lv.1", 11, C_SKY)
	lv_label.position = Vector2(12, 37)
	_rect(C_DARK, Vector2(48, 41), Vector2(86, 6))
	xp_fill = _rect(C_SKY, Vector2(49, 42), Vector2(0, 4))
	time_label = label("00:00", 16, C_CREAM)
	boss_in_label = label("", 11, C_FLAME)
	kill_label = label("驅散 0", 13, C_INK)
	pause_btn = UIKit.button("Ⅱ", 14)
	pause_btn.custom_minimum_size = Vector2(34, 30)
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	root.add_child(pause_btn)

	for n in name_list:
		var l := label(n, 11, C_GOLD if n == name_list[0] else C_INK, 2)
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
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	ls.font_size = UIKit.big(size) + 2
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


const LOCKED := Color(0.55, 0.55, 0.6, 1.0)   # 卡片剛跳出、還不能按的樣子


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


## 劇情對話：下方一個對話框，左邊是說話的人，點一下（或空白鍵）下一句
## lines 每句是 {name, text, icon, col}
func show_dialogue(lines: Array) -> void:
	hide_dialogue()
	dlg_lines = lines
	dlg_i = 0
	dlg_box = PanelContainer.new()
	dlg_box.add_theme_stylebox_override("panel", _box(Color(0.08, 0.05, 0.1, 0.95), C_GOLD))
	root.add_child(dlg_box)
	_dlg_render()


func _dlg_render() -> void:
	if dlg_box == null:
		return
	for ch in dlg_box.get_children():
		ch.queue_free()
	var L: Dictionary = dlg_lines[dlg_i]
	var size := vp()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	dlg_box.add_child(h)
	if L.get("icon", "") != "":
		var ic := UIKit.sprite_icon(L.icon, 4)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var nm := label(L.name, 14, L.get("col", C_GOLD))
	nm.get_parent().remove_child(nm)
	v.add_child(nm)
	var tx := label(L.text, 13, C_INK)
	tx.get_parent().remove_child(tx)
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tx.custom_minimum_size = Vector2(minf(460.0, size.x - 140.0), 0)
	v.add_child(tx)
	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(col)
	var nx := UIKit.button("下一句 ▶" if dlg_i < dlg_lines.size() - 1 else "出發 ▶", 13, true)
	nx.custom_minimum_size = Vector2(88, 30)
	nx.pressed.connect(dialogue_next)
	col.add_child(nx)
	if dlg_i < dlg_lines.size() - 1:
		var sk := UIKit.button("跳過", 11)
		sk.custom_minimum_size = Vector2(88, 24)
		sk.pressed.connect(func():
			dlg_i = dlg_lines.size() - 1
			dialogue_next())
		col.add_child(sk)
	await get_tree().process_frame
	if dlg_box != null and is_instance_valid(dlg_box) and is_instance_valid(nx):
		dlg_box.size = Vector2.ZERO
		dlg_box.position = Vector2(((size.x - dlg_box.size.x) / 2.0), size.y - dlg_box.size.y - 16.0).round()
		nx.grab_focus()


func dialogue_next() -> void:
	if dlg_box == null:
		return
	Sfx.play("ui", 0.0)
	dlg_i += 1
	if dlg_i >= dlg_lines.size():
		hide_dialogue()
		dialogue_done.emit()
	else:
		_dlg_render()


func hide_dialogue() -> void:
	if dlg_box != null and is_instance_valid(dlg_box):
		dlg_box.queue_free()
	dlg_box = null


func vp() -> Vector2:
	return get_viewport().get_visible_rect().size


# ---------- 每幀更新 ----------
var build_label: Label
var combo_label: Label
var combo_last := 0
var combo_pop := 0.0
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
	# 下一隻 Boss 倒數
	var bi: float = st.get("boss_in", -1.0)
	boss_in_label.visible = bi >= 0.0 and not st.over
	if boss_in_label.visible:
		boss_in_label.text = "Boss %d:%02d" % [int(bi) / 60, int(bi) % 60]
		boss_in_label.modulate = Color(1, 1, 1, 1.0 if bi > 20.0 or int(bi * 3.0) % 2 == 0 else 0.4)
		# 五旬節時「FEVER ×N」佔了這一行，倒數往下移
		boss_in_label.position = Vector2(roundf((size.x - boss_in_label.size.x) / 2.0), 44 if fever_label.visible else 26)
	kill_label.text = ("驅散 %d　餅 %d" % [st.kills, st.bread]) if st.get("bread", 0) > 0 else "驅散 %d" % st.kills
	pause_btn.position = Vector2(size.x - 42.0, 4)
	pause_btn.visible = not st.over
	kill_label.position = Vector2(size.x - kill_label.size.x - 52.0, 4)
	hint_label.modulate.a = clampf((10.0 - st.time) / 2.0, 0.0, 1.0)
	if tip_box != null and tip_box.visible:
		var left := tip_until - Time.get_ticks_msec() / 1000.0
		tip_box.modulate.a = clampf(left / 0.5, 0.0, 1.0)
		tip_box.visible = left > 0.0 and not st.over
		# 選卡時放上面、蓋在暗幕上；平常放在下方
		tip_box.size = tip_box.get_combined_minimum_size()
		tip_box.position = Vector2(roundf((size.x - tip_box.size.x) / 2.0), 40.0 if st.choosing else size.y - tip_box.size.y - 70.0)
		if st.choosing and tip_box.get_index() != root.get_child_count() - 1:
			root.move_child(tip_box, -1)
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
	# 連鎖連擊：3 以上才顯示，越高顏色越熱，每次增加會跳一下
	if combo_label == null:
		combo_label = label("", 20, C_GOLD)
		combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cb: int = st.get("combo", 0)
	if cb > combo_last:
		combo_pop = 1.0
	combo_last = cb
	combo_pop = maxf(0.0, combo_pop - 0.08)
	combo_label.visible = cb >= 3 and not st.over
	if combo_label.visible:
		combo_label.text = "連鎖 ×%d" % cb
		var heat: Color = [C_GOLD, C_FLAME, Color("ff6ad5"), Color.WHITE][mini(cb / 15, 3)]
		combo_label.label_settings.font_color = heat
		combo_label.label_settings.font_size = 20 + mini(cb / 10, 8) * 2
		combo_label.modulate.a = clampf(st.get("combo_t", 0.0) / 0.6, 0.3, 1.0)
		combo_label.scale = Vector2.ONE * (1.0 + combo_pop * 0.25)
		combo_label.pivot_offset = combo_label.size / 2.0
		combo_label.position = Vector2(roundf((size.x - combo_label.size.x) / 2.0), 130 if size.y > size.x else 98)
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
		var por := size.y > size.x
		if por and banner.autowrap_mode == TextServer.AUTOWRAP_OFF:
			# 直式手機：長的提示會超出畫面，改成自動換行，放在任務清單下面
			banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			banner.custom_minimum_size = Vector2(size.x - 24.0, 0)
			banner.size = Vector2(size.x - 24.0, 0)
		banner.position = Vector2(roundf((size.x - banner.size.x) / 2.0), roundf(size.y * 0.24) if por else 64.0)
		banner.modulate.a = clampf((banner_until - now) * 2.0, 0.0, 1.0)
	if boss_bg.visible:
		boss_bg.position = Vector2(roundf((size.x - 244.0) / 2.0), 48)
		boss_fill.position = boss_bg.position + Vector2(2, 2)
		boss_label.position = Vector2(boss_bg.position.x - boss_label.size.x - 8.0, 41)
	flash.color.a = maxf(0.0, flash.color.a - 0.04)
	joy_pad.queue_redraw()


## 新手教學提示：畫面下方的小框，6 秒後自己消失（不擋操作）
func show_tip(text: String) -> void:
	if tip_box == null:
		tip_box = PanelContainer.new()
		tip_box.add_theme_stylebox_override("panel", _box(Color(0.08, 0.05, 0.1, 0.88), C_GOLD))
		tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tip_box)
		tip_label = label("", 12, C_CREAM)
		tip_label.get_parent().remove_child(tip_label)
		tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip_box.add_child(tip_label)
	var size := vp()
	tip_label.text = "提示：" + text
	tip_label.custom_minimum_size.x = minf(size.x - 40.0, 420.0)
	tip_box.reset_size()
	tip_box.visible = true
	tip_box.modulate.a = 1.0
	root.move_child(tip_box, -1)   # 蓋在升級卡的暗幕上面
	tip_until = Time.get_ticks_msec() / 1000.0 + 6.0


func tip_busy() -> bool:
	return tip_box != null and tip_box.visible


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
const KIND_NAME := {"recruit": "新同伴", "up": "升級", "branch": "分支", "evolve": "進化", "fruit": "聖靈果子", "armor": "軍裝",
	"epistle": "書信", "event": "事件", "school": "深化卡", "relic": "聖物", "anoint": "主角輔助", "link": "肢體連結", "link_up": "強化連結", "heal": "恩典", "grace_dmg": "恩典", "grace_spd": "恩典", "manna": "恩典"}
const KIND_COL := {"recruit": Color("7be08a"), "up": Color("4fd8ff"), "branch": Color("4fd8ff"), "evolve": Color("ffd75e"),
	"fruit": Color("ff9ae0"), "armor": Color("c9a46b"), "epistle": Color("fff4c2"), "event": Color("c8a0ff"), "school": Color("ffd75e"), "relic": Color("ff8a2a"), "anoint": Color("c8a0ff"), "link": Color("ff8a2a"), "link_up": Color("ff8a2a")}


## 一張升級卡的內容：左邊人物圖（有的話）、上面是種類標籤，再來標題、說明
func _card_body(b: Button, c: Dictionary, i: int, portrait: bool, narrow := false) -> void:
	var kcol: Color = KIND_COL.get(c.kind, C_CREAM)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 8)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.get_parent().add_child(m)   # 內容放在按鈕上面一層；外層容器跟著內容長高
	var row: BoxContainer = HBoxContainer.new() if portrait else VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(row)
	var key: String = c.get("key", "")
	if c.kind in ["recruit", "up", "branch", "evolve"] and ResourceLoader.exists("res://assets/sprites/%s_0.png" % key):
		var ic := UIKit.sprite_icon(key + ("_evo" if c.kind == "evolve" and ResourceLoader.exists("res://assets/sprites/%s_evo_0.png" % key) else ""), 3)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var badge := label("%d　%s・%s" % [i + 1, KIND_NAME.get(c.kind, ""), c.get("tag", "")], 11, kcol)
	badge.get_parent().remove_child(badge)
	col.add_child(badge)
	var tl := label(c.title, 15, C_CREAM)
	tl.get_parent().remove_child(tl)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tl)
	var dl := label(c.desc, 12, C_INK)
	dl.get_parent().remove_child(dl)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(dl)
	for l in [badge, tl, dl]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.custom_minimum_size.x = 220 if portrait else (126 if narrow else 168)
		if not portrait:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func show_cards(cards: Array, now: float, delay: float, rerolls := 0, title_text := "升級！選一個", sub_text := "") -> void:
	hide_cards()
	var size := vp()
	var portrait := size.y > size.x
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.08, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.name = "CardDim"
	root.add_child(dim)
	var title := label(title_text, 20, C_GOLD)
	title.name = "CardTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size.x = size.x
	title.position = Vector2(0, 34 if not portrait else 90)
	if sub_text != "":
		# 事件的情境說明
		var sub := label(sub_text, 13, C_CREAM)
		sub.name = "CardSub"
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.size.x = size.x - 60.0
		sub.position = Vector2(30, (34 if not portrait else 90) + 30)
	cards_box = VBoxContainer.new() if portrait else HBoxContainer.new()
	var narrow: bool = not portrait and cards.size() >= 4   # 教師：四張卡時窄一點才排得下
	cards_box.add_theme_constant_override("separation", 6 if narrow else 10)
	root.add_child(cards_box)
	card_buttons.clear()
	for i in cards.size():
		var c: Dictionary = cards[i]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		card.custom_minimum_size = Vector2(320, 70) if portrait else (Vector2(144, 172) if narrow else Vector2(188, 172))
		cards_box.add_child(card)
		var b := Button.new()
		card.add_child(b)
		_card_body(b, c, i, portrait, narrow)
		var kcol: Color = KIND_COL.get(c.kind, C_BRONZE)
		b.add_theme_stylebox_override("normal", _box(Color("241a2e"), kcol.darkened(0.25)))
		b.add_theme_stylebox_override("hover", _box(Color("3a2a40"), C_GOLD))
		b.add_theme_stylebox_override("focus", _box(Color("3a2a40"), C_GOLD))
		b.add_theme_stylebox_override("pressed", _box(Color("5a4420"), C_CREAM))
		b.add_theme_stylebox_override("disabled", _box(Color("241a2e"), C_BRONZE))
		b.add_theme_color_override("font_disabled_color", C_INK)
		var idx := i
		b.pressed.connect(func(): pick(idx))
		card_buttons.append(b)
	# 剛跳出時先鎖住（變暗），避免滑動移動時手指誤觸
	for b in card_buttons:
		b.disabled = true
		b.get_parent().modulate = LOCKED   # 變暗但不透明（後面的數字不會透出來）
	await get_tree().process_frame
	if cards_box == null:
		return
	cards_box.position = ((size - cards_box.size) / 2.0).round() + Vector2(0, 14)
	card_ready_at = now + delay
	# 卡片一張接一張彈出來（每張 0.18 秒、間隔 0.06 秒；卡片在鎖住的時間內就出現完，不會擋到選擇）
	if not bool(Save.data.get("fxlite_on", false)):
		for i in card_buttons.size():
			var cd: Control = card_buttons[i].get_parent()
			var tw := cd.create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # 選卡時遊戲暫停，動畫照樣跑
			cd.modulate = Color(LOCKED, 0.0)
			cd.pivot_offset = cd.size / 2.0
			cd.scale = Vector2(0.92, 0.92)
			tw.tween_interval(0.06 * mini(i, 2))
			tw.set_parallel(true)
			tw.tween_property(cd, "modulate:a", 1.0, 0.18).set_ease(Tween.EASE_OUT)
			tw.tween_property(cd, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	var my_id := cards_box.get_instance_id()
	get_tree().create_timer(delay, true).timeout.connect(func():
		if cards_box == null or cards_box.get_instance_id() != my_id:
			return
		for b in card_buttons:
			if is_instance_valid(b):
				b.disabled = false
				b.get_parent().modulate = Color.WHITE
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
	var go := UIKit.button("繼續" if DisplayServer.is_touchscreen_available() else "繼續（Esc）", 16, true)
	go.custom_minimum_size = Vector2(200, 40)
	go.pressed.connect(func(): resume_pressed.emit())
	v.add_child(go)
	var re := UIKit.button("放棄，重新開始", 14)
	re.custom_minimum_size = Vector2(200, 34)
	re.pressed.connect(func(): restart_pressed.emit())
	v.add_child(re)
	var home := UIKit.button("放棄，回" + Save.camp_name(), 14)
	home.custom_minimum_size = Vector2(200, 34)
	home.pressed.connect(func(): home_pressed.emit())
	v.add_child(home)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var kinds := [["sfx", "音效"], ["music", "音樂"], ["dnum", "傷害數字"]]
	if OS.has_feature("mobile"):
		kinds.append(["vibe", "震動"])
	for kind in kinds:
		var tb := UIKit.button("", 13)
		tb.custom_minimum_size = Vector2(88, 30)
		var k: String = kind[0]
		var nm: String = kind[1]
		var refresh := func(): tb.text = "%s：%s" % [nm, "開" if Save.data.get(k + "_on", true) else "關"]
		refresh.call()
		tb.pressed.connect(func():
			Sfx.toggle(k)
			refresh.call())
		row.add_child(tb)
	# 預設關閉的設定：特效精簡、字大一點
	for kind in [["fxlite", "特效精簡"], ["bigtext", "字大一點"], ["names", "名字一直顯示"]]:
		var tb2 := UIKit.button("", 13)
		tb2.custom_minimum_size = Vector2(88, 30)
		var k2: String = kind[0]
		var nm2: String = kind[1]
		var refresh2 := func(): tb2.text = "%s：%s" % [nm2, "開" if Save.data.get(k2 + "_on", false) else "關"]
		refresh2.call()
		tb2.pressed.connect(func():
			Save.data[k2 + "_on"] = not bool(Save.data.get(k2 + "_on", false))
			Save.save_profile()
			refresh2.call())
		row.add_child(tb2)
	var note := UIKit.label("放棄會照失敗結算（見證減半）；字大一點在下一個畫面生效", 10, UIKit.MUTED)
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
	if i >= card_buttons.size() or Time.get_ticks_msec() / 1000.0 < card_ready_at:
		return
	hide_cards()
	card_chosen.emit(i)


func hide_cards() -> void:
	for n in ["CardDim", "CardTitle", "CardSub", "CardReroll"]:
		var node := root.get_node_or_null(n)
		if node:
			root.remove_child(node)
			node.queue_free()
	if cards_box:
		cards_box.queue_free()
		cards_box = null
	card_buttons.clear()


# ---------- 失敗 ----------
func show_game_over(lines: Array, button_text := "再出發", home_first := false, story := "", share := "") -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.06, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)
	var line_labels := []
	for row in lines:
		var l := label(row[0], row[1], row[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.remove_child(l)
		box.add_child(l)
		line_labels.append(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	# 通關時主按鈕是「回安提阿」（先回營地看新設施、聊天），失敗時主按鈕是「再出發」
	var home := UIKit.button("回" + Save.camp_name(), 16, home_first)
	home.custom_minimum_size = Vector2(140, 40)
	home.pressed.connect(func(): home_pressed.emit())
	row.add_child(home)
	var btn := UIKit.button(button_text, 16, not home_first)
	btn.custom_minimum_size = Vector2(140, 40)
	btn.pressed.connect(func(): restart_pressed.emit())
	row.add_child(btn)
	if story != "" or share != "":
		# 這段故事（給還不熟悉聖經的玩家）與分享文字
		var row2 := HBoxContainer.new()
		row2.alignment = BoxContainer.ALIGNMENT_CENTER
		row2.add_theme_constant_override("separation", 12)
		box.add_child(row2)
		var story_l := label(story, 12, C_CREAM)
		root.remove_child(story_l)
		story_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		story_l.custom_minimum_size = Vector2(minf(520.0, vp().x - 40.0), 0)
		story_l.visible = false
		box.add_child(story_l)
		box.move_child(story_l, row2.get_index())
		if story != "":
			var sb := UIKit.button("這段故事", 13)
			sb.custom_minimum_size = Vector2(120, 32)
			sb.pressed.connect(func():
				# 看故事時先收起結算的細節（只留標題），畫面才放得下
				story_l.visible = not story_l.visible
				sb.text = "收起故事" if story_l.visible else "這段故事"
				for j in range(1, line_labels.size()):
					line_labels[j].visible = not story_l.visible
				await get_tree().process_frame
				box.size = Vector2.ZERO
				box.position = ((vp() - box.size) / 2.0).round())
			row2.add_child(sb)
		if share != "":
			var shb := UIKit.button("複製分享文字", 13)
			shb.custom_minimum_size = Vector2(140, 32)
			shb.pressed.connect(func():
				DisplayServer.clipboard_set(share)
				shb.text = "已複製，貼給朋友吧！")
			row2.add_child(shb)
	for n in names:
		names[n].visible = false
	await get_tree().process_frame
	box.position = ((vp() - box.size) / 2.0).round()
	(home if home_first else btn).grab_focus()
