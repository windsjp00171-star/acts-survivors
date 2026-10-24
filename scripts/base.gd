extends Control
## 營地裡的彈出面板：出發、同伴名冊（默契與生平）、解鎖、見證錄。由 camp.gd 開關。

signal closed

var G: Dictionary      # game.json
var bios: Dictionary
var stages: Array
var content: VBoxContainer
var scroll: ScrollContainer
var witness_label: Label
var nav_buttons := {}
var portrait := false
var kit_open := false   # 出發頁：主角技能說明展開
var tabs_enabled := {"home": true, "roster": true, "shop": true, "gifts": true, "ach": true, "codex": true}
var board_sel := ""      # 恩賜盤上選到的節點
var board_zoom := 1.0
const C_RED_UI := Color("ff7a6a")
var cur_tab := ""
var devlog: Dictionary
var codex: Dictionary
# 手機：手指在面板上拖曳就能捲動（按在按鈕上拖也可以），放開後會順勢滑一段
const DRAG_START := 10.0   # 手指移動超過這麼多才算拖曳，不算按按鈕
var drag_on := false
var drag_moved := 0.0
var drag_vel := 0.0
var fling := 0.0
var faking := false        # 自己送出的假事件，不要再攔


func _ready() -> void:
	G = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	bios = JSON.parse_string(FileAccess.get_file_as_string("res://data/bios.json"))
	stages = JSON.parse_string(FileAccess.get_file_as_string("res://data/stages.json")).stages
	codex = JSON.parse_string(FileAccess.get_file_as_string("res://data/codex.json"))
	devlog = JSON.parse_string(FileAccess.get_file_as_string("res://data/devlog.json"))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vs := get_viewport().get_visible_rect().size
	portrait = vs.y > vs.x
	_build()
	visible = false


## 打開面板到某一頁；key 是同伴時直接看他的生平
func open(tab: String, key := "") -> void:
	for k in nav_buttons:
		nav_buttons[k].visible = tabs_enabled.get(k, true)
	visible = true
	match tab:
		"roster":
			if key != "":
				_show_companion(key)
			else:
				_show_roster()
		"shop": _show_shop()
		"gifts": _show_gifts()
		"ach": _show_achievements()
		"codex": _show_codex()
		"log": _show_log()
		"altar": _show_altar()
		"library": _show_library()
		_: _show_home()


func close() -> void:
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if faking or not visible or scroll == null or not is_instance_valid(scroll):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_on = scroll.get_global_rect().has_point(event.position)
			drag_moved = 0.0
			drag_vel = 0.0
			fling = 0.0
		elif drag_on:
			drag_on = false
			if drag_moved > DRAG_START:
				# 拖曳結束：不要讓手指底下的按鈕被按到（送一個移到畫面外再放開的假事件）
				get_viewport().set_input_as_handled()
				_fake_release()
				fling = drag_vel
	elif event is InputEventMouseMotion and drag_on and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		drag_moved += absf(event.relative.y)
		if drag_moved > DRAG_START:
			scroll.scroll_vertical -= int(round(event.relative.y))
			drag_vel = lerpf(drag_vel, -event.relative.y / maxf(get_process_delta_time(), 0.008), 0.5)
			get_viewport().set_input_as_handled()


func _fake_release() -> void:
	faking = true
	var far := Vector2(-9999, -9999)
	var mm := InputEventMouseMotion.new()
	mm.position = far
	mm.global_position = far
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(mm)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = false
	mb.position = far
	mb.global_position = far
	Input.parse_input_event(mb)
	Input.flush_buffered_events()
	faking = false


func _process(dt: float) -> void:
	# 放開後順勢滑行，慢慢停下來
	if absf(fling) > 20.0 and scroll != null and is_instance_valid(scroll):
		scroll.scroll_vertical += int(round(fling * dt))
		fling *= pow(0.04, dt)
	else:
		fling = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.02, 0.06, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)

	var top := HBoxContainer.new()
	outer.add_child(top)
	var title := UIKit.label(Save.camp_name(), 20 if portrait else 24, UIKit.GOLD)
	top.add_child(title)
	if not portrait:
		var sub := UIKit.label("　宣教之路的出發地", 12, UIKit.MUTED)
		sub.size_flags_vertical = Control.SIZE_SHRINK_END
		top.add_child(sub)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	witness_label = UIKit.label("", 13 if portrait else 16, UIKit.SKY)
	top.add_child(witness_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(6 if portrait else 12, 0)
	top.add_child(gap)
	var x := UIKit.button("× 關閉", 13)
	x.custom_minimum_size = Vector2(64 if portrait else 80, 30)
	x.pressed.connect(close)
	top.add_child(x)

	# 橫式：左邊分頁、右邊內容；直式：分頁在上、內容在下
	var body: BoxContainer = VBoxContainer.new() if portrait else HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	outer.add_child(body)

	# 直式：分頁鈕自動換行（分頁變多也不會把面板撐出畫面）
	var nav: Container = HFlowContainer.new() if portrait else VBoxContainer.new()
	nav.custom_minimum_size = Vector2(0, 0) if portrait else Vector2(112, 0)
	nav.add_theme_constant_override("separation", 6)
	nav.add_theme_constant_override("h_separation", 6)
	nav.add_theme_constant_override("v_separation", 6)
	body.add_child(nav)
	for item in [["home", "出發", _show_home], ["roster", "同伴", _show_roster], ["shop", "解鎖", _show_shop], ["gifts", "恩賜", _show_gifts], ["ach", "見證錄", _show_achievements], ["codex", "圖鑑", _show_codex], ["log", "日誌", _show_log]]:
		var b := UIKit.button(item[1], 15 if portrait else 14)
		b.custom_minimum_size = Vector2(76, 34) if portrait else Vector2(112, 31)
		b.pressed.connect(item[2])
		nav.add_child(b)
		nav_buttons[item[0]] = b

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.1, 0.07, 0.12, 0.92), UIKit.BRONZE, 10))
	body.add_child(panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.get_v_scroll_bar().custom_minimum_size = Vector2(10, 0)
	panel.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)


func _clear(active: String, page := "") -> void:
	for c in content.get_children():
		c.queue_free()
	# 同一頁重畫（例如點了熬煉、學了恩賜）時保留捲動位置，換頁才回到最上面
	if page == "":
		page = active
	if page == cur_tab:
		_keep_scroll(scroll.scroll_vertical)
	else:
		scroll.scroll_vertical = 0
	cur_tab = page
	witness_label.text = "見證 %d　餅 %d" % [Save.data.witness, int(Save.data.get("bread", 0))]
	for k in nav_buttons:
		nav_buttons[k].add_theme_stylebox_override("normal", UIKit.box(Color("3a2a40") if k == active else UIKit.PANEL, UIKit.GOLD if k == active else UIKit.BRONZE, 6))


func _row(parent: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	return h


func _text(parent: Control, s: String, size: int, color: Color, wrap := false) -> Label:
	var l := UIKit.label(s, size, color)
	if wrap:
		# 中文沒有空白可以斷行：用任意斷行，手機直式才不會被長句子撐寬
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


func _comp_def(key: String) -> Dictionary:
	for c in G.companions:
		if c.key == key:
			return c
	return {}


func _display_name(c: Dictionary) -> String:
	if c.get("with", "") != "":
		return c.name + "・" + _comp_def(c.with).name
	return c.name


# ---------- 出發 ----------
func _show_home() -> void:
	_clear("home")
	if str(Save.data.get("refund_note", "")) != "":
		_text(content, "改版通知：" + str(Save.data.refund_note), 12, UIKit.HEAL, true)
		Save.data.erase("refund_note")
		Save.save_profile()
	# 上一局還沒走完（中途離開）：可以繼續
	var rs := Save.read_run_save()
	if not rs.is_empty():
		_text(content, "上一局還沒走完：%s　%d:%02d　Lv%d" % [str(rs.get("where", "")), int(rs.vars.t) / 60, int(rs.vars.t) % 60, int(rs.vars.level)], 14, UIKit.GOLD, true)
		var rrow := _row(content)
		var go := UIKit.button("繼續這一局", 15, true)
		go.custom_minimum_size = Vector2(0 if portrait else 160, 40)
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.pressed.connect(func():
			Save.resume = rs
			get_tree().change_scene_to_file("res://scenes/main.tscn"))
		rrow.add_child(go)
		var drop := UIKit.button("放棄這一局", 13)
		drop.custom_minimum_size = Vector2(0 if portrait else 140, 40)
		drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		drop.pressed.connect(func():
			if drop.text == "放棄這一局":
				drop.text = "再按一次確定放棄"   # 怕按錯：要按兩次
				return
			Save.clear_run_save()
			_show_home())
		rrow.add_child(drop)
		_text(content, "中途離開會自動存檔；開始新的一局會蓋掉這份", 11, UIKit.MUTED, true)
	# 劇情模式（照聖經走一趟）／自由模式（通過的章節自由組隊重玩）
	var free_ok: bool = not Save.data.churches.is_empty()
	var mode: String = str(Save.data.get("mode", "story")) if free_ok else "story"
	var mrow := _row(content)
	for m in [["story", "劇情：福音傳到地極"], ["free", "自由模式"]]:
		var mb := UIKit.button(m[1], 14, mode == m[0])
		mb.custom_minimum_size = Vector2(0 if portrait else 150, 36)
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mb.disabled = m[0] == "free" and not free_ok
		var mk: String = m[0]
		mb.pressed.connect(func():
			Save.data.mode = mk
			Save.save_profile()
			_show_home())
		mrow.add_child(mb)
	if not free_ok:
		_text(content, "自由模式：通過第一章以後開放，可以自由組隊、挑戰信心等級", 11, UIKit.MUTED, true)
	if mode == "story":
		_show_story()
		return
	_daily_box()
	# 主角：保羅以外的人要先在解鎖商店買
	var lead: String = Save.data.get("leader", "paul")
	var leaders: Array = G.leaders.filter(func(L): return L.key == "paul" or Save.is_unlocked("leader_" + L.key))
	if not leaders.any(func(L): return L.key == lead):
		lead = "paul"
	if leaders.size() > 1:
		_text(content, "主角", 16, UIKit.GOLD)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		content.add_child(flow)
		for L in leaders:
			var key: String = L.key
			var nm: String = G.paul.name if key == "paul" else _comp_def(key).name
			var b := UIKit.button(nm, 13, key == lead)
			b.icon = UIKit.sprite_icon(key, 2).texture
			b.expand_icon = true
			b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			b.custom_minimum_size = Vector2(84, 40)
			b.pressed.connect(func():
				Save.data.leader = key
				Save.save_profile()
				_show_home())
			flow.add_child(b)
		for L in leaders:
			if L.key == lead:
				_text(content, "%s　血 %d　速度 %d" % [L.desc, int(L.hp), int(L.speed)], 11, UIKit.MUTED, true)
	_kit_box(content, lead)
	_calling_ui()
	var starter: String = Save.data.starter
	if not Save.is_unlocked(starter) or starter == lead:
		starter = Save.meta.default_starter
	var c := _comp_def(starter)
	var h := _row(content)
	h.add_child(UIKit.sprite_icon(starter, 4))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_text(v, "第一位同工：" + _display_name(c), 16, UIKit.GOLD)
	_text(v, "第一次升級一定會出現他的招募卡；到「同伴」頁可以換人", 12, UIKit.MUTED, true)
	_text(v, "隊伍上限 %d 人　每局重抽 %d 次" % [Save.party_cap(), Save.rerolls()], 13, UIKit.INK)
	# 自由模式：在劇情裡通過的城都可以再去
	_text(content, "自由模式：通過過的地方", 16, UIKit.GOLD)
	var sel := clampi(int(Save.data.stage), 0, stages.size() - 1)
	if not _stage_open(sel):
		sel = _first_open()
	for i in stages.size():
		var stg: Dictionary = stages[i]
		var founded: bool = Save.data.churches.has(stg.id)
		var open := _stage_open(i)
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UIKit.box(Color(0.2, 0.15, 0.1) if i == sel else Color(0.14, 0.1, 0.17), UIKit.GOLD if i == sel else Color("4a3a50"), 6))
		content.add_child(box)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var mark := UIKit.label("✓" if founded else ("▶" if open else "・"), 18, UIKit.HEAL if founded else (UIKit.GOLD if open else UIKit.MUTED))
		mark.custom_minimum_size = Vector2(20, 0)
		row.add_child(mark)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var title := "%s　%s" % [stg.name, stg.ref] if open else "？？？"
		_text(col, title + ("　教會已建立" if founded else ""), 14, UIKit.CREAM if open else UIKit.MUTED, true)
		_text(col, stg.intro if open else "在劇情模式通過這一章後開放", 11, UIKit.MUTED, true)
		if founded:
			_text(col, "書信卡：" + stg.epistle.name, 11, UIKit.SKY, true)
			# 教會成長：人數越多，近況越多（不影響戰力）
			var sid2: String = stg.id
			var cst := Save.church_stage(sid2)
			var notes: Array = stg.get("church_notes", [])
			var line := "%s教會　%d 人" % [stg.get("church", stg.name), Save.church_members(sid2)]
			if cst > 0 and notes.size() >= cst:
				line += "　%s（%s）" % [notes[cst - 1][0], notes[cst - 1][1]]
			elif cst < Save.meta.church.members.size():
				line += "　再 %d 人，教會會有新的近況" % (int(Save.meta.church.members[cst]) - Save.church_members(sid2))
			_text(col, line, 11, UIKit.HEAL, true)
			var C: Dictionary = Save.meta.church
			var lb := UIKit.button("寫信堅固他們　見證 %d → +%d 人" % [int(C.letter_cost), int(C.letter_add)], 11)
			lb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			lb.disabled = int(Save.data.witness) < int(C.letter_cost)
			lb.pressed.connect(func():
				if Save.church_letter(sid2):
					Sfx.play("heal", 0.0)
					_show_home())
			col.add_child(lb)
		if open and i == sel and stg.has("story"):
			_text(col, "這段故事：" + stg.story, 11, UIKit.INK, true)
		if open and i != sel:
			var pick := UIKit.button("選這裡", 12)
			pick.custom_minimum_size = Vector2(72, 30)
			pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var idx := i
			pick.pressed.connect(func():
				Save.data.stage = idx
				Save.save_profile()
				_show_home())
			row.add_child(pick)
	# 無盡模式：建立幾間教會後才能開
	if _endless_open():
		var eon: bool = Save.data.get("endless_on", false)
		var eb := UIKit.button("%s 無盡模式　Boss 打倒後繼續，敵人每分鐘都更強" % ["●" if eon else "○"], 13, eon)
		eb.custom_minimum_size = Vector2(0, 40)
		eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		eb.pressed.connect(func():
			Save.data.endless_on = not Save.data.get("endless_on", false)
			Save.save_profile()
			_show_home())
		content.add_child(eb)
		var best := int(Save.data.stats.get("endless_best", 0))
		if best > 0:
			_text(content, "無盡模式最久撐了 %d:%02d" % [best / 60, best % 60], 11, UIKit.SKY)
	else:
		_text(content, "無盡模式：建立 %d 間教會後開放（目前 %d 間）" % [int(G.endless.unlock_churches), Save.data.churches.size()], 11, UIKit.MUTED, true)
	# 信心等級：建立這座城的教會後開放，通過第 N 級才能挑戰第 N+1 級
	var sid: String = stages[sel].id
	var fopen := Save.faith_open(sid)
	if fopen > 0:
		var fcur := clampi(int(Save.data.get("faith_sel", 0)), 0, fopen)
		var FD: Dictionary = Save.meta.faith
		_text(content, "信心等級（彼前 1:7）", 15, UIKit.GOLD)
		var fr := _row(content)
		var minus := UIKit.button("−", 16)
		minus.custom_minimum_size = Vector2(40, 34)
		minus.disabled = fcur <= 0
		minus.pressed.connect(func():
			Save.data.faith_sel = fcur - 1
			Save.save_profile()
			_show_home())
		fr.add_child(minus)
		var lv := UIKit.label("  第 %d 級  " % fcur, 18, UIKit.GOLD if fcur > 0 else UIKit.CREAM)
		fr.add_child(lv)
		var plus := UIKit.button("＋", 16)
		plus.custom_minimum_size = Vector2(40, 34)
		plus.disabled = fcur >= fopen
		plus.pressed.connect(func():
			Save.data.faith_sel = fcur + 1
			Save.save_profile()
			_show_home())
		fr.add_child(plus)
		var best := int(Save.data.get("faith_best", {}).get(sid, 0))
		var ftxt := "見證與餅 +%d%%　%s最高通過第 %d 級" % [roundi(fcur * float(FD.reward_per_level) * 100), stages[sel].name, best]
		if portrait:
			_text(content, ftxt, 11, UIKit.SKY, true)   # 直式：放到下一行，不把畫面撐寬
		else:
			fr.add_child(UIKit.label("  " + ftxt, 11, UIKit.SKY))
		if fcur > 0:
			var names := []
			for i2 in fcur:
				names.append("%d %s" % [i2 + 1, FD.levels[i2].name])
			_text(content, "・".join(names), 11, UIKit.MUTED, true)
			_text(content, "第 %d 級新增：%s（%s）" % [fcur, FD.levels[fcur - 1].desc, FD.levels[fcur - 1].ref], 12, UIKit.INK, true)
		if fopen < int(FD.max) and fcur == fopen:
			_text(content, "通過第 %d 級，就能挑戰第 %d 級：%s" % [fopen, fopen + 1, FD.levels[fopen].desc], 11, UIKit.MUTED, true)
	elif not Save.data.churches.is_empty():
		_text(content, "信心等級：在%s建立教會後開放" % stages[sel].name, 11, UIKit.MUTED, true)
	# 營地接下來還會出現什麼（小提示）
	var soon := []
	var STAT_NAME := {"runs": "出發", "wins": "通關", "witness_total": "累計見證", "achievements": "完成見證錄"}
	for item in Save.meta.camp:
		if not Save.camp_built(item) and soon.size() < 2:
			var left := int(item.min) - Save.camp_stat(item.stat)
			var nm: String = item.name if item.get("name", "") != "" else "營地新景象"
			var unit := "次" if item.stat in ["runs", "wins"] else ("個" if item.stat == "achievements" else "")
			soon.append("・%s：%s再 %d %s" % [nm, STAT_NAME.get(item.stat, item.stat), left, unit])
	if not soon.is_empty():
		_text(content, "營地接下來\n" + "\n".join(soon), 11, UIKit.MUTED, true)
	var st: Dictionary = Save.data.stats
	_text(content, "已出發 %d 次　通關 %d 次　最多驅散 %d　見證錄 %d／%d" % [st.runs, st.wins, st.best_kills, Save.data.achievements.size(), Save.meta.achievements.size()], 12, UIKit.MUTED, true)
	var go := UIKit.button("出發：" + stages[sel].name, 18, true)
	go.custom_minimum_size = Vector2(220, 52)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(_start)
	content.add_child(go)
	content.move_child(go, 0)   # 出發鈕放最上面，不用捲到底才找得到
	go.grab_focus()
	_text(content, "提示：每局結束都會帶回「見證」，用來解鎖新同伴、果子、軍裝和隊伍位置。完成見證錄的目標可以解鎖舊約人物。", 12, UIKit.MUTED, true)


## 呼召要等劇情走過大馬色（第 4 章）才出現；之前一律是「使徒」
func _callings_open() -> bool:
	return Save.data.churches.has("damascus")


func _calling_ui() -> void:
	# 呼召：五重職事（弗 4:11），條件達成才開放
	if not _callings_open():
		return
	var cur: String = Save.data.get("calling", "apostle")
	_text(content, "呼召（弗 4:11）", 16, UIKit.GOLD)
	var cflow := HFlowContainer.new()
	cflow.add_theme_constant_override("h_separation", 6)
	cflow.add_theme_constant_override("v_separation", 6)
	content.add_child(cflow)
	for CL in G.get("callings", []):
		var cid: String = CL.id
		var open: bool = Save.stat_value(CL.unlock.stat) >= int(CL.unlock.min)
		var cb := UIKit.button(("%s %s" % [CL.icon, CL.name]) if open else "？ " + CL.name, 13, cid == cur and open)
		cb.custom_minimum_size = Vector2(84, 36)
		cb.disabled = not open
		cb.tooltip_text = CL.unlock.text
		cb.pressed.connect(func():
			Save.data.calling = cid
			Save.save_profile()
			_show_home())
		cflow.add_child(cb)
	for CL in G.get("callings", []):
		if CL.id == cur:
			_text(content, "%s・%s（%s）：%s" % [CL.name, CL.word, CL.ref, CL.desc], 12, UIKit.SKY, true)
			_text(content, CL.rule, 12, UIKit.INK, true)
	var locked := []
	for CL in G.get("callings", []):
		if Save.stat_value(CL.unlock.stat) < int(CL.unlock.min):
			locked.append("%s：%s" % [CL.name, CL.unlock.text])
	if not locked.is_empty():
		_text(content, "還沒開放的呼召　" + "、".join(locked), 11, UIKit.MUTED, true)


## 劇情模式：章節列表
func _show_story() -> void:
	var CH: Array = Save.story.chapters
	var sel := clampi(int(Save.data.get("story_sel", Save.story_next())), 0, CH.size() - 1)
	if not Save.story_open(sel):
		sel = mini(Save.story_next(), CH.size() - 1)
	var ch_sel: Dictionary = CH[sel]
	var go := UIKit.button("出發：第 %d 章　%s" % [sel + 1, ch_sel.title], 18, true)
	go.custom_minimum_size = Vector2(220, 52)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(func(): _start_story(sel))
	content.add_child(go)
	_text(content, "福音傳到地極", 16, UIKit.GOLD)
	_text(content, "「聖靈降臨在你們身上，你們就必得著能力，並要在耶路撒冷、猶太全地，和撒馬利亞，直到地極，作我的見證。」（徒 1:8）", 11, UIKit.MUTED, true)
	_text(content, "每一章的主角和會遇到的同伴都照聖經；在故事裡加入的人，自由模式也能帶。", 11, UIKit.MUTED, true)
	for i in CH.size():
		var ch: Dictionary = CH[i]
		var stg: Dictionary = _stage_by_id(ch.stage)
		var open := Save.story_open(i)
		var done: bool = Save.data.churches.has(ch.stage)
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UIKit.box(Color(0.2, 0.15, 0.1) if i == sel else Color(0.14, 0.1, 0.17), UIKit.GOLD if i == sel else Color("4a3a50"), 6))
		content.add_child(box)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var mark := UIKit.label("✓" if done else ("▶" if open else "・"), 18, UIKit.HEAL if done else (UIKit.GOLD if open else UIKit.MUTED))
		mark.custom_minimum_size = Vector2(20, 0)
		row.add_child(mark)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		_text(col, ("第 %d 章　%s　%s" % [i + 1, ch.title, stg.get("ref", "")]) if open else "第 %d 章　？？？" % (i + 1), 14, UIKit.CREAM if open else UIKit.MUTED, true)
		if open:
			_text(col, stg.get("intro", ""), 11, UIKit.MUTED, true)
			# 這一章的人：主角＋會遇到的同伴
			var people := HFlowContainer.new()
			people.add_theme_constant_override("h_separation", 4)
			col.add_child(people)
			for k in [ch.leader] + Array(ch.cast):
				var ic := UIKit.sprite_icon(k, 2)
				ic.tooltip_text = G.paul.name if k == "paul" else _comp_def(k).get("name", k)
				people.add_child(ic)
			if ch.get("solo", false):
				_text(col, "這一章只有主角一個人", 11, UIKit.SKY, true)
		if open and i == sel and stg.has("story"):
			_text(col, "這段故事：" + stg.story, 11, UIKit.INK, true)
		if open and i == sel:
			_kit_box(col, str(ch.leader))
		if open and i != sel:
			var pick := UIKit.button("選這章", 12)
			pick.custom_minimum_size = Vector2(72, 30)
			pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var idx := i
			pick.pressed.connect(func():
				Save.data.story_sel = idx
				Save.save_profile()
				_show_home())
			row.add_child(pick)
	_calling_ui()
	content.move_child(go, 0)
	go.grab_focus()


## 主角的職業特質、職業技能、覺醒（出發前先知道這位主角怎麼玩）
func _kit_box(parent: Control, lead: String) -> void:
	var K: Dictionary = G.get("kits", {}).get(lead, {})
	if K.is_empty():
		return
	var nm: String = G.paul.name if lead == "paul" else _comp_def(lead).get("name", lead)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIKit.box(Color(0.12, 0.09, 0.14), Color("ff6a8a"), 6))
	parent.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	box.add_child(v)
	_text(v, "%s怎麼玩" % nm, 14, Color("ff6a8a"))
	_text(v, str(K.get("trait", "")), 12, UIKit.INK, true)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 4)
	v.add_child(flow)
	for d in K.pool:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 3)
		var path := "res://assets/sprites/icon_%s.png" % d.id
		if ResourceLoader.exists(path):
			var ic := TextureRect.new()
			ic.texture = load(path)
			ic.custom_minimum_size = Vector2(24, 24)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			chip.add_child(ic)
		var lb := UIKit.label("%s（%s）" % [d.name, d.role], 11, UIKit.CREAM)
		lb.tooltip_text = "%s（%s）" % [d.desc[0], d.ref]
		chip.add_child(lb)
		flow.add_child(chip)
	_text(v, "升級時學會（最多 %d 招），全部自動施放" % (int(K.slots) - 1), 10, UIKit.MUTED, true)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 4)
	detail.visible = kit_open
	var more := UIKit.button("收起說明" if kit_open else "每一招、覺醒的說明", 12)
	more.pressed.connect(func():
		kit_open = not kit_open
		detail.visible = kit_open   # 只展開這一塊，不重畫整頁（捲動位置不會跳回最上面）
		more.text = "收起說明" if kit_open else "每一招、覺醒的說明")
	v.add_child(more)
	v.add_child(detail)
	for d in K.pool:
		_text(detail, "・%s（%s）：%s" % [d.name, d.ref, d.desc[0]], 11, UIKit.INK, true)
	var at: Array = K.get("awaken_at", [])
	var rows: Array = K.get("awaken", [])
	for ri in rows.size():
		_text(detail, ("覺醒（Lv%d，三選一）" % int(at[ri])) if ri < at.size() else "覺醒", 12, UIKit.GOLD)
		for o in rows[ri]:
			_text(detail, "・%s（%s）：%s" % [o.name, o.ref, o.desc], 11, UIKit.INK, true)


func _stage_by_id(sid: String) -> Dictionary:
	for st in stages:
		if st.id == sid:
			return st
	return {}


## 每日挑戰：今天大家都一樣的城市、條件、呼召、聖物；當天第一次通關見證與餅 ×1.5
func _daily_box() -> void:
	var dly := Save.daily_today()
	var st: Dictionary = stages[int(dly.stage)]
	var tn := []
	for id in dly.trials:
		for L in Save.meta.faith.levels:
			if L.id == id:
				tn.append("%s（%s）" % [L.name, L.desc])
	var cn := ""
	for CL in G.callings:
		if CL.id == dly.calling:
			cn = CL.name
	var rn := ""
	for r in G.relics:
		if r.id == dly.relic:
			rn = r.name
	_text(content, "今日挑戰　%s" % dly.date, 16, UIKit.GOLD)
	_text(content, "城市：%s　主角：保羅　第一位同伴：%s\n呼召：%s　一開始帶著聖物：%s\n條件：%s" % [st.name, _display_name(_comp_def(str(dly.starter))) if not _comp_def(str(dly.starter)).is_empty() else str(dly.starter), cn, rn, "、".join(tn)], 12, UIKit.INK, true)
	var best: Dictionary = Save.data.get("daily_best", {})
	if str(best.get("date", "")) == dly.date:
		_text(content, "今天最好：%s　撐了 %d:%02d　驅散 %d" % ["通關 ✓" if best.won else "還沒通關", int(best.seconds) / 60, int(best.seconds) % 60, int(best.kills)], 12, UIKit.HEAL, true)
	else:
		_text(content, "當天第一次通關：見證與餅 ×1.5", 11, UIKit.MUTED, true)
	var db := UIKit.button("出發：今日挑戰", 15)
	db.custom_minimum_size = Vector2(0, 40)
	db.pressed.connect(func():
		Save.run_config = {"starter": str(dly.starter), "stage": int(dly.stage), "faith": 0, "endless": false,
			"calling": str(dly.calling), "daily": str(dly.date), "daily_trials": dly.trials, "daily_relic": str(dly.relic)}
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	content.add_child(db)


func _start_story(i: int) -> void:
	var idx := 0
	for j in stages.size():
		if stages[j].id == Save.story.chapters[i].stage:
			idx = j
	Save.run_config = {"story": i, "stage": idx, "starter": Save.data.starter, "faith": 0, "endless": false,
		"calling": _calling_ok(str(Save.data.get("calling", "apostle")))}
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _calling_ok(cid: String) -> String:
	if not _callings_open():
		return "apostle"
	for CL in G.get("callings", []):
		if CL.id == cid and Save.stat_value(CL.unlock.stat) >= int(CL.unlock.min):
			return cid
	return "apostle"


func _endless_open() -> bool:
	return Save.data.churches.size() >= int(G.endless.unlock_churches)


func _stage_open(i: int) -> bool:
	# 自由模式：在劇情裡通過（建立教會）的城才能重玩
	return Save.data.churches.has(stages[i].id)


func _first_open() -> int:
	for i in stages.size():
		if _stage_open(i):
			return i
	return 0


func _start() -> void:
	var starter: String = Save.data.starter
	if not Save.is_unlocked(starter):
		starter = Save.meta.default_starter
	var sel := clampi(int(Save.data.stage), 0, stages.size() - 1)
	if not _stage_open(sel):
		sel = _first_open()
	Save.run_config = {"starter": starter, "stage": sel,
		"faith": clampi(int(Save.data.get("faith_sel", 0)), 0, Save.faith_open(stages[sel].id)),
		"endless": _endless_open() and bool(Save.data.get("endless_on", false)),
		"calling": _calling_ok(str(Save.data.get("calling", "apostle")))}
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ---------- 同伴 ----------
func _shop_name(id: String) -> String:
	for it in Save.meta.shop:
		if it.id == id:
			return it.name
	var c := _comp_def(id)
	return c.get("name", id)


## 名冊上的簡短提示：怎麼解鎖
func _lock_short(key: String) -> String:
	for item in Save.meta.shop:
		if item.id == key:
			return "解鎖：見證 %d" % int(item.cost)
	for a in Save.meta.achievements:
		if a.get("unlock", "") == key:
			return "見證錄：" + ("？？？" if a.get("secret", false) else a.name)
	return ""


func _lock_hint(key: String) -> String:
	for item in Save.meta.shop:
		if item.id == key:
			return "在「解鎖」頁用見證 %d 解鎖" % int(item.cost)
	for a in Save.meta.achievements:
		if a.get("unlock", "") == key:
			return "見證錄：%s（%s）" % [a.name, a.desc]
	return ""


## 祭壇：為下一趟求一個祝福（三選一，用掉就要再回來禱告）
const BLESSINGS := [
	{"id": "lv", "name": "得力", "ref": "賽 40:31", "desc": "下一趟一開始，主角的招式直接是 Lv2"},
	{"id": "meter", "name": "同心", "ref": "徒 2:1", "desc": "下一趟一開始，同心合意就有一半"},
	{"id": "grapes", "name": "葡萄", "ref": "民 13:23", "desc": "下一趟身上帶著一串葡萄：血少於三成時自動吃下，全隊回四成血"},
	{"id": "xp", "name": "智慧", "ref": "雅 1:5", "desc": "下一趟經驗 +15%"},
	{"id": "relic", "name": "看顧", "ref": "詩 121:8", "desc": "下一趟第一個寶箱，一定可以選聖物（劇情模式改成多一張升級卡）"},
	{"id": "guard", "name": "盾牌", "ref": "詩 3:3", "desc": "下一趟一開始有 2 層護盾"}]


func _show_altar() -> void:
	_clear("home")
	_text(content, "祭壇（創 12:7）", 18, UIKit.GOLD)
	var cur: String = str(Save.data.get("blessing", ""))
	if cur != "":
		for b in BLESSINGS:
			if b.id == cur:
				_text(content, "下一趟已經有的祝福：「%s」（%s）%s" % [b.name, b.ref, b.desc], 13, UIKit.HEAL, true)
		_text(content, "出發用掉以後，再回來禱告。", 11, UIKit.MUTED, true)
		return
	_text(content, "安靜下來禱告。為下一趟求一個祝福：", 13, UIKit.INK, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("altar-%d" % int(Save.data.stats.runs))   # 同一趟回來，選項固定（不能一直重開）
	var pool := BLESSINGS.duplicate()
	for i in 3:
		var b: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var btn := UIKit.button("「%s」（%s）\n%s" % [b.name, b.ref, b.desc], 13)
		btn.custom_minimum_size = Vector2(0, 54)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var bid: String = b.id
		btn.pressed.connect(func():
			Save.data.blessing = bid
			Save.save_profile()
			_show_altar())
		content.add_child(btn)


## 書房：每座城找到的失落書卷
func _show_library() -> void:
	_clear("home")
	var got: Array = Save.data.get("scrolls", [])
	_text(content, "書房：失落的書卷（%d／%d）" % [got.size(), stages.size()], 18, UIKit.GOLD)
	_text(content, "每座城的地圖上都藏著一卷。離它不遠時，主角身邊會有一個小金點指著方向。", 11, UIKit.MUTED, true)
	for st in stages:
		if got.has(st.id):
			_text(content, "✦ %s（%s）" % [st.name, st.get("ref", "")], 14, UIKit.GOLD)
			_text(content, str(st.get("intro", "")), 12, UIKit.INK, true)
		else:
			_text(content, "？ %s：還沒找到" % st.name, 13, UIKit.MUTED)


func _show_roster() -> void:
	_clear("roster")
	_text(content, "常帶出門的同伴默契會升高：攻擊變快，並解鎖他的生平。", 12, UIKit.MUTED, true)
	var grid := GridContainer.new()
	grid.columns = 2 if portrait else 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for c in G.companions:
		if c.get("follows", "") != "":
			continue
		var unlocked := Save.is_unlocked(c.key)
		var b := UIKit.button("", 12)
		b.custom_minimum_size = Vector2(136 if portrait else 108, 92)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(v)
		var icon := UIKit.sprite_icon(c.key, 3)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not unlocked:
			icon.modulate = Color(0, 0, 0, 0.85)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)
		var n := UIKit.label(_display_name(c) if unlocked else "？？？", 12, UIKit.INK if unlocked else UIKit.MUTED)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(n)
		var lv := Save.affinity_level(c.key)
		var sub := UIKit.label(("默契 Lv%d" % lv) if unlocked else _lock_short(c.key), 10, UIKit.SKY if unlocked else UIKit.CREAM)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(sub)
		var key: String = c.key
		b.pressed.connect(func(): _show_companion(key))
		grid.add_child(b)


func _show_companion(key: String) -> void:
	_clear("roster", "detail:" + key)
	var top_back := UIKit.button("← 返回名冊", 13)
	top_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top_back.pressed.connect(_show_roster)
	content.add_child(top_back)
	var c := _comp_def(key)
	var unlocked := Save.is_unlocked(key)
	var h := _row(content)
	var icon := UIKit.sprite_icon(key, 5)
	if not unlocked:
		icon.modulate = Color(0, 0, 0, 0.85)
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_text(v, _display_name(c) if unlocked else "？？？", 20, UIKit.GOLD)
	_text(v, "【%s】%s" % [c.tag, c.get("era", "")], 12, UIKit.SKY)
	var sk: Dictionary = G.skills[c.skill]
	_text(v, sk.desc[0], 13, UIKit.INK, true)
	for evo in G.evolutions:
		if evo.companion == key:
			_text(v, "進化「%s」：滿級＋果子「%s」" % [evo.name, G.fruits[evo.fruit].name], 12, UIKit.GOLD, true)
			_text(v, evo.desc, 11, UIKit.MUTED, true)
	# 同行合擊：跟誰是聖經裡的搭檔
	for B in G.get("bonds", []):
		if B.a == key or B.b == key:
			var mate: String = B.b if B.a == key else B.a
			var mname: String = "保羅" if mate == "paul" else _display_name(_comp_def(mate))
			_text(v, "同行・與%s「%s」（%s）：%s" % [mname, B.name, B.ref, B.desc], 11, UIKit.SKY, true)
	if not unlocked:
		_text(content, "尚未加入：" + _lock_hint(key), 13, UIKit.CREAM, true)
	else:
		var lv := Save.affinity_level(key)
		var nxt := Save.next_threshold(key)
		var prog := "默契 Lv%d　%s" % [lv, ("下一級還差 %d" % (nxt - Save.affinity_xp(key))) if nxt > 0 else "已滿"]
		_text(content, prog + "　攻擊速度 +%d%%" % int(lv * Save.meta.affinity.bonus_per_level * 100), 13, UIKit.SKY)
		var starter := UIKit.button("設為第一位同工" if Save.data.starter != key else "目前的第一位同工", 13, Save.data.starter != key)
		starter.disabled = Save.data.starter == key
		starter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		starter.pressed.connect(func():
			Save.data.starter = key
			Save.save_profile()
			_show_companion(key))
		content.add_child(starter)
	_text(content, "生平", 16, UIKit.GOLD)
	var entries: Array = bios.get(key, [])
	var lv2 := Save.affinity_level(key) if unlocked else -1
	for i in entries.size():
		var e: Dictionary = entries[i]
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UIKit.box(Color(0.14, 0.1, 0.17), Color("4a3a50"), 6))
		var bv := VBoxContainer.new()
		box.add_child(bv)
		content.add_child(box)
		if i <= lv2:
			_text(bv, e.title + "　" + e.ref, 13, UIKit.CREAM)
			_text(bv, e.text, 12, UIKit.INK, true)
		else:
			_text(bv, "默契 Lv%d 解鎖" % i, 12, UIKit.MUTED)
	var back := UIKit.button("返回名冊", 13)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_show_roster)
	content.add_child(back)


# ---------- 解鎖 ----------
func _show_shop() -> void:
	_clear("shop")
	_text(content, "營地建設　用「見證」蓋", 16, UIKit.GOLD)
	_text(content, "蓋好就一直有效，每一項都有上限。（餅留著學「恩賜」那一頁的恩賜盤）", 11, UIKit.MUTED, true)
	for u in Save.meta.bread.upgrades:
		var rank := Save.up_rank(u.id)
		var full: bool = rank >= int(u.max)
		var h2 := _row(content)
		var v2 := VBoxContainer.new()
		v2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(v2)
		var pips := "●".repeat(rank) + "○".repeat(int(u.max) - rank)
		_text(v2, "%s　%s" % [u.name, pips], 14, UIKit.INK)
		_text(v2, "%s（%s）" % [u.desc, u.ref], 11, UIKit.MUTED, true)
		var cost := Save.up_cost(u)
		var b2 := UIKit.button("已滿" if full else ("見證 %d" % cost), 13, not full)
		b2.custom_minimum_size = Vector2(110, 32)
		b2.disabled = full or int(Save.data.witness) < cost
		var uu: Dictionary = u
		b2.pressed.connect(func():
			if Save.buy_up(uu):
				Sfx.play("pick", 0.0)
				_show_shop())
		h2.add_child(b2)
	for bd in Save.meta.buildings:
		var blv := Save.building_level(bd.id)
		var bmax := int(bd.get("max", 1))
		var done := blv >= bmax
		var hb := _row(content)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(vb)
		var pips := ("　" + "●".repeat(blv) + "○".repeat(bmax - blv)) if bmax > 1 else ("　已蓋好" if blv > 0 else "")
		_text(vb, bd.name + pips, 14, UIKit.MUTED if done else UIKit.INK)
		_text(vb, "%s（%s）" % [bd.desc, bd.ref], 11, UIKit.MUTED, true)
		var bcost := Save.building_cost(bd)
		var bb := UIKit.button("已滿" if done else (("升級　見證 %d" if blv > 0 else "蓋　見證 %d") % bcost), 13, not done)
		bb.custom_minimum_size = Vector2(110, 32)
		bb.disabled = done or int(Save.data.witness) < bcost
		var bdd: Dictionary = bd
		bb.pressed.connect(func():
			if Save.buy_building(bdd):
				Sfx.play("pick", 0.0)
				_show_shop())
		hb.add_child(bb)
	_text(content, "解鎖　用「見證」兌換", 16, UIKit.GOLD)
	_text(content, "用見證解鎖。舊約人物要靠「見證錄」的目標解鎖。", 12, UIKit.MUTED, true)
	for item in Save.meta.shop:
		var bought: bool = Save.data.bought.has(item.id)
		var locked_req: bool = item.has("requires") and not (Save.data.bought.has(item.requires) or Save.data.unlocked.has(item.requires))
		var h := _row(content)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		_text(v, item.name, 14, UIKit.MUTED if bought else UIKit.INK)
		_text(v, item.desc, 11, UIKit.MUTED, true)
		if locked_req and not bought:
			var how := _lock_hint(item.requires)
			_text(v, "需要先解鎖「%s」%s" % [_shop_name(item.requires), ("：" + how) if how != "" else ""], 11, UIKit.CREAM, true)
		var b := UIKit.button("已解鎖" if bought else ("見證 %d" % int(item.cost)), 13, not bought)
		b.custom_minimum_size = Vector2(96, 32)
		b.disabled = bought or locked_req or Save.data.witness < item.cost
		var it: Dictionary = item
		b.pressed.connect(func():
			if Save.buy(it):
				_show_shop())
		h.add_child(b)


# ---------- 見證錄 ----------
func _show_achievements() -> void:
	_clear("ach")
	var all: Array = Save.meta.achievements
	var got: int = all.filter(func(a): return Save.data.achievements.has(a.id)).size()
	_text(content, "見證錄　%d／%d" % [got, all.size()], 16, UIKit.GOLD)
	_text(content, "完成目標會得到見證、餅，有的還會解鎖新同伴。", 11, UIKit.MUTED, true)
	var group := ""
	for a in all:
		var g: String = a.get("group", "")
		if g != group:
			group = g
			var in_g := all.filter(func(x): return x.get("group", "") == g)
			var got_g := in_g.filter(func(x): return Save.data.achievements.has(x.id)).size()
			_text(content, "%s　%d／%d" % [g, got_g, in_g.size()], 14, UIKit.SKY)
		var done: bool = Save.data.achievements.has(a.id)
		var hidden: bool = a.get("secret", false) and not done
		var h := _row(content)
		var mark := UIKit.label("✓" if done else "・", 16, UIKit.HEAL if done else UIKit.MUTED)
		mark.custom_minimum_size = Vector2(18, 0)
		h.add_child(mark)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		_text(v, "？？？" if hidden else a.name, 14, UIKit.GOLD if done else UIKit.INK)
		var cur := Save.stat_value(a.stat)
		var prog := "" if done or hidden else "　（%d／%d）" % [mini(cur, int(a.min)), int(a.min)]
		_text(v, a.desc + prog, 12, UIKit.MUTED, true)
		var reward := []
		if a.has("unlock"):
			reward.append("解鎖 " + _comp_def(a.unlock).get("name", a.unlock))
		if a.has("witness"):
			reward.append("見證 +%d" % int(a.witness))
		if a.has("bread"):
			reward.append("餅 +%d" % int(a.bread))
		_text(h, "\n".join(reward), 12, UIKit.SKY)


# ---------- 圖鑑 ----------
func _codex_section(title: String, total: int, seen: int) -> void:
	_text(content, "%s　%d／%d" % [title, seen, total], 15, UIKit.GOLD)


func _codex_entry(known: bool, name: String, lines: Array) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIKit.box(Color(0.14, 0.1, 0.17), Color("4a3a50"), 6))
	content.add_child(box)
	var v := VBoxContainer.new()
	box.add_child(v)
	_text(v, name if known else "？？？", 13, UIKit.CREAM if known else UIKit.MUTED)
	if known:
		for ln in lines:
			_text(v, ln[0], 11, ln[1], true)


# ---------- 恩賜盤 ----------
## 內容重建、版面算好之後，把捲動放回原來的位置
func _keep_scroll(v: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = v


func _show_gifts() -> void:
	_clear("gifts")
	var leaders: Array = G.leaders.filter(func(L): return L.key == "paul" or Save.is_unlocked("leader_" + L.key))
	var lead := Save.cur_leader()
	if not leaders.any(func(L): return L.key == lead):
		lead = "paul"
	var lname: String = G.paul.name if lead == "paul" else _comp_def(lead).name
	var start := Save.board_start(lead)
	var start_tag: String = str(Save.board_node(start).get("tag", "中央"))
	_text(content, "恩賜盤　用餅「學會」，出發前替主角「點上」（點數 %d／%d）" % [Save.gift_used(lead), Save.gift_cap()], 15, UIKit.GOLD, true)
	var area: BoxContainer = VBoxContainer.new() if portrait else HBoxContainer.new()
	area.add_theme_constant_override("separation", 10)
	content.add_child(area)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	var vs := get_viewport().get_visible_rect().size
	var cw: float = minf(vs.x - 60.0, 520.0) if portrait else minf(vs.x * 0.42, vs.y - 150.0)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(cw, cw)
	canvas.clip_contents = true
	canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	area.add_child(canvas)
	area.add_child(side)
	var top := HFlowContainer.new()
	top.add_theme_constant_override("h_separation", 6)
	top.add_theme_constant_override("v_separation", 6)
	side.add_child(top)
	for L in leaders:
		var key: String = L.key
		var nm: String = G.paul.name if key == "paul" else _comp_def(key).name
		var b := UIKit.button("%s %d" % [nm, Save.gift_used(key)], 12, key == lead)
		b.pressed.connect(func():
			Save.data.leader = key   # 跟出發頁選的主角是同一個
			board_sel = ""
			Save.save_profile()
			_show_gifts())
		top.add_child(b)
	var tools := HFlowContainer.new()
	tools.add_theme_constant_override("h_separation", 6)
	side.add_child(tools)
	var rec := UIKit.button("一鍵推薦", 12)
	rec.pressed.connect(func():
		Save.board_recommend(lead, start_tag if start_tag != "中央" else _best_tag())
		Save.save_profile()
		Sfx.play("holy", 0.0)
		_show_gifts())
	tools.add_child(rec)
	var clr := UIKit.button("全部卸下", 12)
	clr.pressed.connect(func():
		if clr.text == "全部卸下":
			clr.text = "再按一次確定"
			return
		Save.board_clear(lead)
		Save.save_profile()
		_show_gifts())
	tools.add_child(clr)
	var zb := UIKit.button("縮小看全部" if board_zoom > 1.0 else "放大", 12)
	zb.pressed.connect(func():
		board_zoom = 1.0 if board_zoom > 1.0 else 2.0
		_show_gifts())
	tools.add_child(zb)

	# 盤面：整張縮到放得下；放大時以選到的節點為中心
	var span := 345.0
	var sc: float = cw / (span * 2.0) * board_zoom
	var focus := Vector2.ZERO
	if board_zoom > 1.0:
		var fn := Save.board_node(board_sel if board_sel != "" else start)
		focus = Vector2(float(fn.get("x", 0)), float(fn.get("y", 0)))
	var to_px := func(nd: Dictionary) -> Vector2: return Vector2(cw / 2.0, cw / 2.0) + (Vector2(float(nd.x), float(nd.y)) - focus) * sc
	var COL := {"講道": UIKit.SKY, "詩歌": UIKit.GOLD, "醫治": UIKit.HEAL, "守護": Color("6ab0f0"), "差派": Color("ff9a4a"), "門徒": Color("c08ae0"),
		"中央": UIKit.CREAM, "橋": Color("e0e0e0")}
	canvas.draw.connect(func():
		canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(cw, cw)), Color(0.07, 0.05, 0.09))
		for tg in Save.meta.gifts.board.order:
			# 流派的名字寫在那一區
			var i: int = Save.meta.gifts.board.order.find(tg)
			var a := deg_to_rad(-90.0 + i * 60.0)
			var lp: Vector2 = Vector2(cw / 2.0, cw / 2.0) + (Vector2(cos(a), sin(a)) * 46.0 * 3.4 - focus) * sc
			canvas.draw_string(UIKit.font(), lp + Vector2(-14, 4), tg, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(COL[tg], 0.45))
		for l in Save.meta.gifts.board.links:
			var na := Save.board_node(l[0])
			var nb := Save.board_node(l[1])
			var on: bool = Save.board_is_on(l[0], lead) and Save.board_is_on(l[1], lead)
			var lr: bool = Save.board_learned(l[0]) and Save.board_learned(l[1])
			canvas.draw_line(to_px.call(na), to_px.call(nb), UIKit.GOLD if on else (UIKit.BRONZE if lr else Color("3a2e44")), 3.0 if on else 1.5)
		for nd in Save.board_nodes():
			var p: Vector2 = to_px.call(nd)
			var r: float = [0.0, 2.5, 4.0, 5.5][int(nd.size)] * board_zoom * clampf(cw / 400.0, 0.8, 1.4)
			var col: Color = COL.get(nd.tag, UIKit.CREAM)
			var on: bool = Save.board_is_on(nd.id, lead)
			var lr: bool = Save.board_learned(nd.id)
			var can: bool = Save.board_can_learn(nd.id)
			if nd.id == board_sel:
				canvas.draw_circle(p, r + 4.0, Color(1, 1, 1, 0.35))
			if on:
				canvas.draw_circle(p, r + 1.5, UIKit.GOLD)
				canvas.draw_circle(p, r, col)
			elif lr:
				canvas.draw_circle(p, r, col.darkened(0.55))
				canvas.draw_arc(p, r, 0.0, TAU, 20, col, 1.5)
			elif can:
				canvas.draw_circle(p, r, Color(0.12, 0.1, 0.14))
				canvas.draw_arc(p, r, 0.0, TAU, 20, Color(col, 0.8), 1.5)
			else:
				canvas.draw_circle(p, r * 0.8, Color("2a2230"))
			if nd.kind == "keystone":
				canvas.draw_arc(p, r + 3.0, 0.0, TAU, 20, Color(C_RED_UI, 0.8), 1.0)
			if Save.board_is_start(nd.id):
				canvas.draw_string(UIKit.font(), p + Vector2(-5, 5), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIKit.CREAM if nd.id == start else UIKit.MUTED))
	canvas.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var best := ""
			var bd := 18.0
			for nd in Save.board_nodes():
				var d: float = (to_px.call(nd) as Vector2).distance_to(ev.position)
				if d < bd:
					bd = d
					best = nd.id
			if best != "":
				board_sel = best
				Sfx.play("ui", 0.0)
				_show_gifts())
	canvas.queue_redraw()

	# 選到的節點：說明、學會、點上／卸下
	var sel := board_sel if board_sel != "" else start
	var nd := Save.board_node(sel)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIKit.box(Color(0.14, 0.1, 0.16), UIKit.GOLD, 6))
	side.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	box.add_child(v)
	var kind_name: String = ["", "小節點", "經文節點", "基石"][int(nd.size)]
	_text(v, "%s　%s・%s" % [nd.name, nd.tag, kind_name], 15, UIKit.CREAM)
	if str(nd.get("ref", "")) != "":
		_text(v, "（%s）" % nd.ref, 11, UIKit.SKY)
	_text(v, str(nd.desc), 12, UIKit.INK, true)
	if nd.kind == "keystone":
		_text(v, "基石：很強，但有代價", 11, C_RED_UI, true)
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 8)
	v.add_child(h)
	if sel == start:
		_text(v, "★ %s的起點：一定點上、不佔點數" % lname, 11, UIKit.GOLD, true)
	elif not Save.board_learned(sel):
		var can := Save.board_can_learn(sel)
		var cost := int(nd.cost)
		var lb := UIKit.button("學會（%d 餅）" % cost, 13)
		lb.disabled = not can or int(Save.data.get("bread", 0)) < cost
		lb.pressed.connect(func():
			if Save.board_learn(sel):
				Sfx.play("holy", 0.0)
				_show_gifts())
		h.add_child(lb)
		if not can:
			_text(v, "要先學會旁邊相連的節點", 11, UIKit.MUTED, true)
		elif int(Save.data.get("bread", 0)) < cost:
			_text(v, "餅不夠（有 %d 個）" % int(Save.data.get("bread", 0)), 11, UIKit.MUTED, true)
	else:
		var on := Save.board_is_on(sel, lead)
		var tb := UIKit.button("卸下" if on else "替%s點上" % lname, 13, not on)
		var msg := Label.new()
		tb.pressed.connect(func():
			var err := Save.board_toggle(sel, lead)
			if err == "":
				Save.save_profile()
				Sfx.play("ui", 0.0)
				_show_gifts()
			else:
				_text(v, err, 11, UIKit.CREAM, true))
		h.add_child(tb)
	_text(side, "藍＝講道、金＝詩歌、綠＝醫治、淡藍＝守護、橘＝差派、紫＝門徒。金框是點上的，亮邊是學會的，暗的是還沒學。紅圈是基石。", 10, UIKit.MUTED, true)
	var SR: Dictionary = G.get("schools", {}).get(str(nd.tag), {})
	if not SR.is_empty():
		_text(side, "流派規則「%s」（%s）" % [SR.name, SR.ref], 12, UIKit.GOLD)
		_text(side, str(SR.desc), 11, UIKit.INK, true)


## 保羅一鍵推薦：點在隊伍裡最多人的那個流派
func _best_tag() -> String:
	var cnt := {}
	for c in G.companions:
		if Save.is_unlocked(c.key) and c.skill != "":
			cnt[c.tag] = int(cnt.get(c.tag, 0)) + Save.affinity_xp(c.key) + 1
	var best := "講道"
	for k in cnt:
		if int(cnt[k]) > int(cnt.get(best, 0)):
			best = k
	return best


# ---------- 製作日誌 ----------
func has_new_log() -> bool:
	return devlog != null and not devlog.entries.is_empty() and Save.data.get("log_seen", "") != devlog.entries[0].version


func _show_log() -> void:
	_clear("log")
	Save.data.log_seen = devlog.entries[0].version
	Save.save_profile()
	_text(content, "製作日誌", 16, UIKit.GOLD)
	_text(content, "每次改版改了什麼，都寫在這裡。有想法歡迎告訴我們！", 11, UIKit.MUTED, true)
	# 從頭開始旅程：故事改了很多，想從第一章重新走一次（舊進度會先備份）
	var rb := UIKit.button("從頭開始旅程", 12)
	rb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var rnote := UIKit.label("見證、餅、教會、同伴全部回到一開始；音樂與畫面設定保留", 10, UIKit.MUTED)
	rb.pressed.connect(func():
		if rb.text == "從頭開始旅程":
			rb.text = "真的要重來嗎？再按一次確定"
			rnote.text = "舊進度會先存一份備份（profile_backup.json）"
			return
		Save.reset_profile()
		Sfx.play("holy", 0.0)
		_show_home())
	content.add_child(rb)
	content.add_child(rnote)
	_save_code_ui()
	_text(content, "素材說明：人物、敵人、地圖、特效都是程式畫的像素圖；過場背景圖是用 AI（Pollinations 的 FLUX 模型）畫出空場景，再縮成像素風格；音樂是程式合成的原創曲，裡面引用的聖詩旋律都是 1929 年以前、早已公版的曲調。", 10, UIKit.MUTED, true)
	for i in devlog.entries.size():
		var e: Dictionary = devlog.entries[i]
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UIKit.box(Color(0.16, 0.12, 0.1) if i == 0 else Color(0.12, 0.09, 0.14), UIKit.GOLD if i == 0 else Color("4a3a50"), 6))
		content.add_child(box)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		box.add_child(v)
		_text(v, "%s　%s" % [e.version, e.title], 15, UIKit.CREAM if i == 0 else UIKit.INK, true)
		_text(v, e.date, 11, UIKit.MUTED)
		for it in e.items:
			_text(v, "・" + it, 12, UIKit.INK, true)


## 存檔碼：換手機、換瀏覽器時把進度帶走
func _save_code_ui() -> void:
	_text(content, "帶走存檔（換手機、換電腦時用）", 14, UIKit.GOLD)
	_text(content, "按「複製存檔碼」，把這段文字傳給自己（LINE、Email 都可以）；到新的裝置上，貼進下面的框框按「匯入」。", 11, UIKit.MUTED, true)
	var box := TextEdit.new()
	box.custom_minimum_size = Vector2(0, 64)
	box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.placeholder_text = "在這裡貼上存檔碼（ACTS1: 開頭）"
	box.add_theme_font_size_override("font_size", 11)
	content.add_child(box)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	content.add_child(row)
	var msg := UIKit.label("", 11, UIKit.SKY)
	msg.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var cp := UIKit.button("複製存檔碼", 12)
	cp.pressed.connect(func():
		var code := Save.export_code()
		DisplayServer.clipboard_set(code)
		box.text = code
		box.select_all()
		msg.text = "已經複製了（如果貼不出來，就長按上面的框框全選、複製）")
	row.add_child(cp)
	var im := UIKit.button("匯入", 12)
	im.pressed.connect(func():
		if box.text.strip_edges() == "":
			msg.text = "先把存檔碼貼進上面的框框"
			return
		if im.text == "匯入":
			im.text = "會取代現在的進度，再按一次確定"
			msg.text = "現在的進度會先備份（profile_backup.json）"
			return
		var err := Save.import_code(box.text)
		im.text = "匯入"
		if err != "":
			msg.text = err
			return
		Sfx.play("holy", 0.0)
		_show_home())
	row.add_child(im)
	content.add_child(msg)


func _show_codex() -> void:
	_clear("codex")
	var cx: Dictionary = Save.data.get("codex", {})
	# 同工的組合：主角放某一招時，某位同伴跟著出手（找到的才看得到全部）
	var CB: Array = G.get("kit_combos", [])
	if not CB.is_empty():
		var found: Array = Save.data.get("combos_found", [])
		_text(content, "同工的組合　%d／%d" % [found.size(), CB.size()], 16, UIKit.GOLD)
		_text(content, "主角放出某一招時，隊伍裡剛好有某位同伴，他會跟著一起出手。還沒找到的只看得到是哪位主角。", 11, UIKit.MUTED, true)
		for cb in CB:
			var lname: String = G.paul.name if cb.leader == "paul" else _comp_def(cb.leader).get("name", cb.leader)
			if found.has(cb.id):
				_text(content, "✓ %s（%s）：%s" % [cb.name, cb.ref, cb.why], 12, UIKit.INK, true)
			else:
				_text(content, "？ %s的某一招 ＋ 某位同伴" % lname, 12, UIKit.MUTED, true)
	# 詩歌本：去過的城市音樂可以在這裡點播
	_text(content, "詩歌本", 16, UIKit.GOLD)
	_text(content, "去過的城市，那裡的音樂就會收進來，點一下就能播放。", 11, UIKit.MUTED, true)
	var songs := [["title", "宣教之路（主題曲）"], ["camp", "營地"]]
	if Save.data.get("intro_seen", false):
		songs.append(["story", "很久以前的故事"])
	for st in stages:
		if Save.data.get("story_seen", []).has("in_" + st.id) or Save.data.churches.has(st.id):
			songs.append([st.music, st.name])
	if Save.data.stats.get("wins", 0) > 0:
		songs.append(["boss", "Boss 戰"])
	if int(Save.data.stats.get("fevers_total", 0)) > 0:
		songs.append(["fever", "五旬節"])
	var sflow := HFlowContainer.new()
	sflow.add_theme_constant_override("h_separation", 6)
	sflow.add_theme_constant_override("v_separation", 6)
	content.add_child(sflow)
	for sg in songs:
		var sname: String = sg[0]
		var sb := UIKit.button("♪ " + sg[1], 12, Sfx.music_name == sname)
		sb.custom_minimum_size = Vector2(96, 30)
		sb.pressed.connect(func():
			Sfx.music(sname)
			_show_codex())
		sflow.add_child(sb)
	# 信仰小辭典：一開始就全部看得到，給還不熟悉聖經的玩家
	var words: Array = codex.get("words", [])
	if not words.is_empty():
		_text(content, "信仰小辭典", 16, UIKit.GOLD)
		_text(content, "遊戲裡的名詞，在聖經裡是什麼意思？", 11, UIKit.MUTED, true)
		for w in words:
			_codex_entry(true, w.name, [[w.text, UIKit.INK], ["（%s）" % w.ref, UIKit.SKY]])
	var seen_e: Array = cx.get("enemies", [])
	var en: Array = codex.enemies
	_codex_section("敵人", en.size(), en.filter(func(e): return seen_e.has(e.id)).size())
	for e in en:
		_codex_entry(seen_e.has(e.id), e.name, [[e.what, UIKit.INK], ["「%s」（%s）" % [e.verse, e.ref], UIKit.SKY]])
	var seen_r: Array = cx.get("relics", [])
	_codex_section("聖物", G.get("relics", []).size(), G.get("relics", []).filter(func(r): return seen_r.has(r.id)).size())
	for r in G.get("relics", []):
		_codex_entry(seen_r.has(r.id), "%s（%s）" % [r.name, r.ref], [[r.desc, UIKit.INK], [r.story, UIKit.MUTED]])
	var seen_v: Array = cx.get("evos", [])
	_codex_section("進化", G.evolutions.size(), G.evolutions.filter(func(v): return seen_v.has(v.companion)).size())
	for v in G.evolutions:
		var who: String = G.paul.name if v.companion == "paul" else _comp_def(v.companion).get("name", v.companion)
		_codex_entry(seen_v.has(v.companion), "%s：%s" % [who, v.name], [[v.desc, UIKit.INK], ["條件：滿級＋果子「%s」" % G.fruits[v.fruit].name, UIKit.MUTED]])
	var seen_f: Array = cx.get("fruits", [])
	_codex_section("聖靈果子", G.fruits.size(), G.fruits.keys().filter(func(k): return seen_f.has(k)).size())
	for k in G.fruits:
		_codex_entry(seen_f.has(k), G.fruits[k].name, [[G.fruits[k].desc, UIKit.INK]])
	var seen_a: Array = cx.get("armor", [])
	_codex_section("全副軍裝（弗 6:13–17）", G.armor.size(), G.armor.keys().filter(func(k): return seen_a.has(k)).size())
	for k in G.armor:
		_codex_entry(seen_a.has(k), G.armor[k].name, [[G.armor[k].desc[0], UIKit.INK]])
	_codex_section("書信卡", stages.size(), stages.filter(func(st): return Save.data.churches.has(st.id)).size())
	for st in stages:
		_codex_entry(Save.data.churches.has(st.id), st.epistle.name, [[st.epistle.desc, UIKit.INK], ["建立%s教會後解鎖" % st.name, UIKit.MUTED]])


# ---------- 自動截圖測試 ----------
func auto_shots(shot_path: String) -> void:
	for step in [["home", _show_home], ["roster", _show_roster], ["detail", func(): _show_companion("silas")], ["shop", _show_shop], ["gifts", _show_gifts], ["ach", _show_achievements], ["codex", _show_codex], ["log", _show_log]]:
		visible = true
		step[1].call()
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png(shot_path.replace(".png", "_%s.png" % step[0]))
