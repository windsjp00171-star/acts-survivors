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
var tabs_enabled := {"home": true, "roster": true, "shop": true, "gifts": true, "ach": true, "codex": true}
var gift_tag := "講道"
var gift_sel := 0
var cur_tab := ""
var devlog: Dictionary
var codex: Dictionary


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
		"market": _show_market()
		_: _show_home()


func close() -> void:
	visible = false
	closed.emit()


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
	var title := UIKit.label("安提阿", 20 if portrait else 24, UIKit.GOLD)
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
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	# 呼召：五重職事（弗 4:11），條件達成才開放
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
	# 旅程地圖：照保羅旅程的順序，建立前一間教會才能去下一座城
	_text(content, "旅程地圖", 16, UIKit.GOLD)
	var sel := clampi(int(Save.data.stage), 0, stages.size() - 1)
	if not _stage_open(sel):
		sel = 0
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
		_text(col, stg.intro if open else "建立前一間教會後解鎖", 11, UIKit.MUTED, true)
		if founded:
			_text(col, "書信卡：" + stg.epistle.name, 11, UIKit.SKY, true)
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
	if Save.trials_unlocked():
		var on: Array = Save.data.trials_on
		var tp := Save.trial_points(on)
		_text(content, "熬煉（彼前 1:7）　%d 點：見證 +%d%%、餅 +%d%%" % [tp, roundi(tp * Save.meta.trials.witness_per_point * 100), roundi(tp * Save.meta.trials.bread_per_point * 100)], 15, UIKit.GOLD, true)
		var best := int(Save.data.trial_best.get(stages[sel].id, 0))
		if best > 0:
			_text(content, "%s 最高通過 %d 點" % [stages[sel].name, best], 11, UIKit.SKY)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		content.add_child(grid)
		for tr in Save.meta.trials.list:
			var is_on: bool = on.has(tr.id)
			var tb := UIKit.button("%s %s（%d）\n%s" % ["●" if is_on else "○", tr.name, int(tr.points), tr.desc], 11, is_on)
			tb.custom_minimum_size = Vector2(0, 44)
			tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var tid: String = tr.id
			tb.pressed.connect(func():
				if Save.data.trials_on.has(tid):
					Save.data.trials_on.erase(tid)
				else:
					Save.data.trials_on.append(tid)
				Save.save_profile()
				_show_home())
			grid.add_child(tb)
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


func _calling_ok(cid: String) -> String:
	for CL in G.get("callings", []):
		if CL.id == cid and Save.stat_value(CL.unlock.stat) >= int(CL.unlock.min):
			return cid
	return "apostle"


func _endless_open() -> bool:
	return Save.data.churches.size() >= int(G.endless.unlock_churches)


func _stage_open(i: int) -> bool:
	# 已經建立過的城一定開著（中間插入新城市時，舊存檔不會被鎖住）
	return i == 0 or Save.data.churches.has(stages[i - 1].id) or Save.data.churches.has(stages[i].id)


func _start() -> void:
	var starter: String = Save.data.starter
	if not Save.is_unlocked(starter):
		starter = Save.meta.default_starter
	var sel := clampi(int(Save.data.stage), 0, stages.size() - 1)
	Save.run_config = {"starter": starter, "stage": sel if _stage_open(sel) else 0,
		"trials": Save.data.trials_on.duplicate() if Save.trials_unlocked() else [],
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
		var PR: Dictionary = Save.meta.pray
		var pray := UIKit.button("為他代禱　見證 %d → 默契 +%d" % [int(PR.witness), int(PR.affinity)], 13)
		pray.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		pray.disabled = int(Save.data.witness) < int(PR.witness)
		pray.pressed.connect(func():
			if Save.pray_for(key):
				Sfx.play("heal", 0.0)
				_show_companion(key))
		content.add_child(pray)
		var GB: Dictionary = Save.meta.gift_bread
		var gift := UIKit.button("送餅給他　餅 %d → 默契 +%d" % [int(GB.cost), int(GB.affinity)], 13)
		gift.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		gift.disabled = int(Save.data.get("bread", 0)) < int(GB.cost)
		gift.pressed.connect(func():
			if Save.gift_bread(key):
				Sfx.play("heal", 0.0)
				_show_companion(key))
		content.add_child(gift)
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
	_text(content, "永久恩典　用「餅」兌換", 16, UIKit.GOLD)
	_text(content, "餅在旅程中撿到，失敗也會全部帶回來。每一項都有上限。", 11, UIKit.MUTED, true)
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
		var b2 := UIKit.button("已滿" if full else ("餅 %d" % cost), 13, not full)
		b2.custom_minimum_size = Vector2(96, 32)
		b2.disabled = full or int(Save.data.bread) < cost
		var uu: Dictionary = u
		b2.pressed.connect(func():
			if Save.buy_up(uu):
				_show_shop())
		h2.add_child(b2)
	_text(content, "營地建設　用「見證」蓋", 16, UIKit.GOLD)
	_text(content, "蓋好就一直有效，也會出現在營地裡。", 11, UIKit.MUTED, true)
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
	# 傳揚見證：見證換餅（見證多了也有地方用）
	var X: Dictionary = Save.meta.exchange
	_text(content, "傳揚見證　用見證換餅（%d 見證 → %d 餅）" % [int(X.witness), int(X.bread)], 14, UIKit.SKY)
	var xr := HFlowContainer.new()
	xr.add_theme_constant_override("h_separation", 6)
	content.add_child(xr)
	for times in [1, 5, 20]:
		var tb := UIKit.button("見證 %d → 餅 %d" % [int(X.witness) * times, int(X.bread) * times], 12)
		tb.custom_minimum_size = Vector2(120, 30)
		tb.disabled = int(Save.data.witness) < int(X.witness) * times
		var tm: int = times
		tb.pressed.connect(func():
			if Save.exchange(tm):
				Sfx.play("pick", 0.0)
				_show_achievements())
		xr.add_child(tb)
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


# ---------- 恩賜樹 ----------
## 內容重建、版面算好之後，把捲動放回原來的位置
func _keep_scroll(v: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = v


func _show_gifts() -> void:
	_clear("gifts")
	var GF: Dictionary = Save.meta.gifts
	_text(content, "恩賜樹　用「餅」學習", 16, UIKit.GOLD)
	_text(content, "上面的節點學了才能學連著的下一個；越下面的層要先累積越多點。", 11, UIKit.MUTED, true)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	content.add_child(flow)
	for tag in GF.trees:
		var tg: String = tag
		var b := UIKit.button("%s %d" % [tg, Save.gift_points(tg)], 13 if portrait else 12, tg == gift_tag)
		b.custom_minimum_size = Vector2(72, 32) if portrait else Vector2(62, 28)
		b.pressed.connect(func():
			gift_tag = tg
			gift_sel = 0
			_show_gifts())
		flow.add_child(b)
	var tree: Dictionary = GF.trees[gift_tag]
	var members: Array = G.companions.filter(func(c): return c.tag == gift_tag and c.skill != "").map(func(c): return c.name)

	# 樹：3 欄 × 4 層的格子，節點之間畫連線（像暗黑破壞神 2 的技能樹）
	# 說明與學習鈕放在樹旁邊：橫式在右邊、直式在上面（都不用往下拉）
	var area: BoxContainer = VBoxContainer.new() if portrait else HBoxContainer.new()
	area.add_theme_constant_override("separation", 10)
	content.add_child(area)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	var cw := 104.0 if portrait else 100.0
	var ch := 84.0
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(cw * 3, ch * GF.tiers.size())
	canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if portrait:
		area.add_child(side)
		area.add_child(canvas)
	else:
		area.add_child(canvas)
		area.add_child(side)
	var nodes: Array = tree.nodes
	var center := func(nd: Dictionary) -> Vector2: return Vector2((int(nd.col) + 0.5) * cw, (int(nd.row) + 0.5) * ch + 7.0)
	canvas.draw.connect(func():
		for r in GF.tiers.size():
			# 每一層上方寫這一層要先累積幾點（點夠了變金色）
			var need := int(GF.tiers[r])
			if need > 0:
				canvas.draw_string(UIKit.font(), Vector2(4, r * ch + 11), "第 %d 層：需 %d 點" % [r + 1, need], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIKit.GOLD if Save.gift_points(gift_tag) >= need else UIKit.MUTED)
		for nd in nodes:
			for rq in nd.req:
				var from: Dictionary = nodes.filter(func(x): return x.id == rq)[0]
				var lit: bool = Save.gift_rank(gift_tag, rq) > 0
				canvas.draw_line(center.call(from), center.call(nd), UIKit.GOLD if lit else Color("4a3a50"), 3.0 if lit else 2.0))
	for i in nodes.size():
		var nd: Dictionary = nodes[i]
		var rank := Save.gift_rank(gift_tag, nd.id)
		var open := Save.gift_open(i, gift_tag)
		var full: bool = rank >= int(nd.max)
		var nb := Button.new()
		nb.text = "%s\n%s" % [tree.names[i], "●".repeat(rank) + "○".repeat(int(nd.max) - rank)]
		nb.add_theme_font_override("font", UIKit.font())
		nb.add_theme_font_size_override("font_size", 11 if portrait else 12)
		nb.add_theme_color_override("font_color", UIKit.GOLD if rank > 0 else (UIKit.CREAM if open else UIKit.MUTED))
		var border: Color = UIKit.GOLD if full or i == gift_sel else (UIKit.BRONZE if open else Color("3a2e44"))
		nb.add_theme_stylebox_override("normal", UIKit.box(Color(0.22, 0.16, 0.1) if rank > 0 else (Color(0.16, 0.12, 0.18) if open else Color(0.08, 0.06, 0.1)), border, 6))
		nb.add_theme_stylebox_override("hover", UIKit.box(Color(0.28, 0.2, 0.14), UIKit.GOLD, 6))
		nb.size = Vector2(cw - 12, ch - 26)
		nb.position = center.call(nd) - nb.size / 2.0
		var idx: int = i
		nb.pressed.connect(func():
			gift_sel = idx
			_show_gifts())
		canvas.add_child(nb)
	canvas.queue_redraw()

	# 選到的節點：說明與學習鈕
	if gift_sel >= 0:
		var nd: Dictionary = nodes[gift_sel]
		var rank := Save.gift_rank(gift_tag, nd.id)
		var full: bool = rank >= int(nd.max)
		var open := Save.gift_open(gift_sel, gift_tag)
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UIKit.box(Color(0.14, 0.1, 0.16), UIKit.GOLD, 6))
		side.add_child(box)
		var h: BoxContainer = HBoxContainer.new() if portrait else VBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		box.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		_text(v, "%s　Lv%d／%d" % [tree.names[gift_sel], rank, int(nd.max)], 15, UIKit.CREAM)
		if tree.has("refs"):
			_text(v, "（%s）" % tree.refs[gift_sel], 11, UIKit.SKY)
		_text(v, nd.desc % gift_tag, 12, UIKit.INK, true)
		if nd.id == "link" or nd.id == "ult":
			var TL: Dictionary = G.tag_links.get(gift_tag, {})
			if not TL.is_empty():
				_text(v, "%s的專屬連結：%s" % [gift_tag, TL.name], 11, UIKit.SKY, true)
		if not open:
			var why := []
			if Save.gift_points(gift_tag) < int(GF.tiers[int(nd.row)]):
				why.append("這棵樹先累積 %d 點" % int(GF.tiers[int(nd.row)]))
			for rq in nd.req:
				if Save.gift_rank(gift_tag, rq) <= 0:
					why.append("先學「%s」" % tree.names[nodes.find(nodes.filter(func(x): return x.id == rq)[0])])
			_text(v, "還不能學：" + "、".join(why), 11, UIKit.CREAM, true)
		var cost := Save.gift_cost(gift_sel, gift_tag)
		var bb := UIKit.button("已學滿" if full else ("學習　餅 %d" % cost), 13, open and not full)
		bb.custom_minimum_size = Vector2(110, 34)
		bb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bb.disabled = full or not open or int(Save.data.get("bread", 0)) < cost
		bb.pressed.connect(func():
			if Save.buy_gift(gift_sel, gift_tag):
				Sfx.play("pick", 0.0)
				_show_gifts())
		h.add_child(bb)
	var SR: Dictionary = G.get("schools", {}).get(gift_tag, {})
	if not SR.is_empty():
		# 流派規則：隊伍裡同流派 2 人啟動，3、4 人升級；第 5 層的節點會改寫規則
		_text(side, "流派規則「%s」（%s）" % [SR.name, SR.ref], 13, UIKit.GOLD)
		_text(side, SR.desc + "。隊伍裡同流派 2 人啟動，3 人、4 人再升級（主角也算）。第 5 層的節點會改寫這條規則。", 11, UIKit.INK, true)
	_text(side, "這個流派：" + "、".join(members), 11, UIKit.MUTED, true)
	_text(side, "（%s）" % tree.ref, 11, UIKit.MUTED)


# ---------- 市集 ----------
func _show_market() -> void:
	_clear("", "market")
	_text(content, "市集　用「見證」買行囊", 16, UIKit.GOLD)
	_text(content, "行囊在下一趟出門時生效，用完就沒了。每趟回營地，貨架會換一批。", 11, UIKit.MUTED, true)
	for it in Save.market_offers():
		var got := Save.market_bought(it.id)
		var h := _row(content)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		_text(v, it.name + ("　已買" if got else ""), 14, UIKit.MUTED if got else UIKit.INK)
		_text(v, "%s（%s）" % [it.desc, it.ref], 11, UIKit.MUTED, true)
		var b := UIKit.button("已買" if got else ("見證 %d" % int(it.cost)), 13, not got)
		b.custom_minimum_size = Vector2(96, 32)
		b.disabled = got or int(Save.data.witness) < int(it.cost)
		var item: Dictionary = it
		b.pressed.connect(func():
			if Save.buy_provision(item):
				Sfx.play("pick", 0.0)
				_show_market())
		h.add_child(b)
	var bag: Array = Save.data.get("provisions", [])
	if not bag.is_empty():
		var names := []
		for id in bag:
			for it in Save.meta.market.items:
				if it.id == id:
					names.append(it.name)
		_text(content, "已備好的行囊：" + "、".join(names), 13, UIKit.SKY, true)


# ---------- 製作日誌 ----------
func has_new_log() -> bool:
	return devlog != null and not devlog.entries.is_empty() and Save.data.get("log_seen", "") != devlog.entries[0].version


func _show_log() -> void:
	_clear("log")
	Save.data.log_seen = devlog.entries[0].version
	Save.save_profile()
	_text(content, "製作日誌", 16, UIKit.GOLD)
	_text(content, "每次改版改了什麼，都寫在這裡。有想法歡迎告訴我們！", 11, UIKit.MUTED, true)
	for i in devlog.entries.size():
		var e: Dictionary = devlog.entries[i]
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UIKit.box(Color(0.16, 0.12, 0.1) if i == 0 else Color(0.12, 0.09, 0.14), UIKit.GOLD if i == 0 else Color("4a3a50"), 6))
		content.add_child(box)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		box.add_child(v)
		_text(v, "%s　%s" % [e.version, e.title], 15, UIKit.CREAM if i == 0 else UIKit.INK)
		_text(v, e.date, 11, UIKit.MUTED)
		for it in e.items:
			_text(v, "・" + it, 12, UIKit.INK, true)


func _show_codex() -> void:
	_clear("codex")
	var cx: Dictionary = Save.data.get("codex", {})
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
	for step in [["home", _show_home], ["roster", _show_roster], ["detail", func(): _show_companion("silas")], ["shop", _show_shop], ["gifts", _show_gifts], ["ach", _show_achievements], ["codex", _show_codex], ["log", _show_log], ["market", _show_market]]:
		visible = true
		step[1].call()
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png(shot_path.replace(".png", "_%s.png" % step[0]))
