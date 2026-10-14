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
var tabs_enabled := {"home": true, "roster": true, "shop": true, "ach": true, "codex": true}
var codex: Dictionary


func _ready() -> void:
	G = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	bios = JSON.parse_string(FileAccess.get_file_as_string("res://data/bios.json"))
	stages = JSON.parse_string(FileAccess.get_file_as_string("res://data/stages.json")).stages
	codex = JSON.parse_string(FileAccess.get_file_as_string("res://data/codex.json"))
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
		"ach": _show_achievements()
		"codex": _show_codex()
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
	var title := UIKit.label("安提阿", 24, UIKit.GOLD)
	top.add_child(title)
	if not portrait:
		var sub := UIKit.label("　宣教之路的出發地", 12, UIKit.MUTED)
		sub.size_flags_vertical = Control.SIZE_SHRINK_END
		top.add_child(sub)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	witness_label = UIKit.label("", 16, UIKit.SKY)
	top.add_child(witness_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(12, 0)
	top.add_child(gap)
	var x := UIKit.button("✕ 關閉", 13)
	x.custom_minimum_size = Vector2(80, 30)
	x.pressed.connect(close)
	top.add_child(x)

	# 橫式：左邊分頁、右邊內容；直式：分頁在上、內容在下
	var body: BoxContainer = VBoxContainer.new() if portrait else HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	outer.add_child(body)

	var nav: BoxContainer = HBoxContainer.new() if portrait else VBoxContainer.new()
	nav.custom_minimum_size = Vector2(0, 0) if portrait else Vector2(112, 0)
	nav.add_theme_constant_override("separation", 6)
	body.add_child(nav)
	for item in [["home", "出發", _show_home], ["roster", "同伴", _show_roster], ["shop", "解鎖", _show_shop], ["ach", "見證錄", _show_achievements], ["codex", "圖鑑", _show_codex]]:
		var b := UIKit.button(item[1], 15)
		b.custom_minimum_size = Vector2(0, 36) if portrait else Vector2(112, 38)
		if portrait:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


func _clear(active: String) -> void:
	for c in content.get_children():
		c.queue_free()
	scroll.scroll_vertical = 0
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
	var starter: String = Save.data.starter
	if not Save.is_unlocked(starter):
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
		_text(col, title + ("　教會已建立" if founded else ""), 14, UIKit.CREAM if open else UIKit.MUTED)
		_text(col, stg.intro if open else "建立前一間教會後解鎖", 11, UIKit.MUTED, true)
		if founded:
			_text(col, "書信卡：" + stg.epistle.name, 11, UIKit.SKY, true)
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
	if Save.trials_unlocked():
		var on: Array = Save.data.trials_on
		var tp := Save.trial_points(on)
		_text(content, "熬煉（彼前 1:7）　%d 點：見證 +%d%%、餅 +%d%%" % [tp, roundi(tp * Save.meta.trials.witness_per_point * 100), roundi(tp * Save.meta.trials.bread_per_point * 100)], 15, UIKit.GOLD)
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
	var st: Dictionary = Save.data.stats
	_text(content, "已出發 %d 次　通關 %d 次　最多驅散 %d　見證錄 %d／%d" % [st.runs, st.wins, st.best_kills, Save.data.achievements.size(), Save.meta.achievements.size()], 12, UIKit.MUTED, true)
	var go := UIKit.button("出發：" + stages[sel].name, 18, true)
	go.custom_minimum_size = Vector2(220, 48)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	go.pressed.connect(_start)
	content.add_child(go)
	go.grab_focus()
	_text(content, "提示：每局結束都會帶回「見證」，用來解鎖新同伴、果子、軍裝和隊伍位置。完成見證錄的目標可以解鎖舊約人物。", 12, UIKit.MUTED, true)


func _stage_open(i: int) -> bool:
	return i == 0 or Save.data.churches.has(stages[i - 1].id)


func _start() -> void:
	var starter: String = Save.data.starter
	if not Save.is_unlocked(starter):
		starter = Save.meta.default_starter
	var sel := clampi(int(Save.data.stage), 0, stages.size() - 1)
	Save.run_config = {"starter": starter, "stage": sel if _stage_open(sel) else 0,
		"trials": Save.data.trials_on.duplicate() if Save.trials_unlocked() else []}
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ---------- 同伴 ----------
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
		var sub := UIKit.label(("默契 Lv%d" % lv) if unlocked else c.get("era", ""), 10, UIKit.SKY if unlocked else UIKit.MUTED)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(sub)
		var key: String = c.key
		b.pressed.connect(func(): _show_companion(key))
		grid.add_child(b)


func _show_companion(key: String) -> void:
	_clear("roster")
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
	_text(content, "永久恩典（花餅）", 16, UIKit.GOLD)
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
	_text(content, "解鎖（花見證）", 16, UIKit.GOLD)
	_text(content, "用見證解鎖。舊約人物要靠「見證錄」的目標解鎖。", 12, UIKit.MUTED, true)
	for item in Save.meta.shop:
		var bought: bool = Save.data.bought.has(item.id)
		var locked_req: bool = item.has("requires") and not Save.data.bought.has(item.requires)
		var h := _row(content)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		_text(v, item.name, 14, UIKit.MUTED if bought else UIKit.INK)
		_text(v, item.desc, 11, UIKit.MUTED, true)
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
	var st: Dictionary = Save.data.stats
	for a in Save.meta.achievements:
		var done: bool = Save.data.achievements.has(a.id)
		var h := _row(content)
		var mark := UIKit.label("✓" if done else "・", 16, UIKit.HEAL if done else UIKit.MUTED)
		mark.custom_minimum_size = Vector2(18, 0)
		h.add_child(mark)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		_text(v, a.name, 14, UIKit.GOLD if done else UIKit.INK)
		var prog := "" if done else "　（%d／%d）" % [mini(int(st.get(a.stat, 0)), int(a.min)), int(a.min)]
		_text(v, a.desc + prog, 12, UIKit.MUTED, true)
		var reward := []
		if a.has("unlock"):
			reward.append("解鎖 " + _comp_def(a.unlock).get("name", a.unlock))
		if a.has("witness"):
			reward.append("見證 +%d" % int(a.witness))
		_text(h, "、".join(reward), 12, UIKit.SKY)


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


func _show_codex() -> void:
	_clear("codex")
	var cx: Dictionary = Save.data.get("codex", {})
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
	for step in [["home", _show_home], ["roster", _show_roster], ["detail", func(): _show_companion("silas")], ["shop", _show_shop], ["ach", _show_achievements], ["codex", _show_codex]]:
		visible = true
		step[1].call()
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png(shot_path.replace(".png", "_%s.png" % step[0]))
