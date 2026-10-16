extends Node2D
## 安提阿營地：遊戲開啟後的第一個畫面。保羅在營地走動，跟同伴、帳棚、見證牆、路標互動。
## 設施依進度出現（meta.json 的 camp）。鍵盤 WASD 移動、空白鍵互動；觸控／滑鼠點目標就走過去。

const C_GOLD := Color("ffd75e")
const C_CREAM := Color("fff4c2")
const C_INK := Color("f4ead2")

var G: Dictionary
var cam: Camera2D
var props: Node2D        # 帳棚、營火等（畫在角色後面）
var actors: Node2D       # 角色（y 排序）
var tags: Node2D         # 名字與提示（最上層）
var panel                # base.gd 彈出面板
var hud: CanvasLayer
var witness_label: Label
var hint_label: Label
var news_label: Label
var news_until := 0.0

var paul := {}            # 營地裡操作的人物（就是選的主角）
var lead := "paul"
var people: Array = []   # {key, name, pos, node}
var spots: Array = []    # 可互動的東西 {kind, key, name, pos, r}
var built: Array = []    # 已出現的設施
var target = null        # 點擊後走過去的目標 spot
var walk_to = null       # 點擊空地走過去的位置
var t := 0.0
var portrait := false
var squash := Vector2.ONE
# 營地對話（data/talks.json）
var T: Dictionary
var bubbles := {}        # 同伴 key → 這次要聊的那一段
var talk: Array = []     # 正在進行的對話
var talk_i := 0
var talk_key := ""
var talk_box: PanelContainer
var talk_icon: TextureRect
var talk_name: Label
var talk_text: Label
var typing := false
var type_t := 0.0
var type_speed := 26.0
var type_pitch := 1.0
var type_shown := 0


func _ready() -> void:
	G = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var vs := get_viewport().get_visible_rect().size
	portrait = vs.y > vs.x
	# 直式：把營地往上下拉長，讓東西都放得進窄畫面
	squash = Vector2(0.6, 2.0) if portrait else Vector2.ONE

	var ground := Sprite2D.new()
	ground.texture = load("res://assets/sprites/ground.png")
	ground.region_enabled = true
	ground.region_rect = Rect2(0, 0, 1024, 1024)
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.z_index = -2
	ground.modulate = Color(0.82, 0.8, 0.78)
	add_child(ground)
	props = Node2D.new()
	props.z_index = -1
	props.draw.connect(_draw_props)
	add_child(props)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	tags = Node2D.new()
	tags.z_index = 10
	tags.draw.connect(_draw_tags)
	add_child(tags)
	cam = Camera2D.new()
	cam.zoom = Vector2.ONE * (vs.x / 205.0 if portrait else 2.0)
	add_child(cam)
	cam.make_current()

	_build_camp()
	_build_hud()
	_pick_bubbles()
	Sfx.music("camp")

	var shot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.substr(7)
	if shot != "":
		_auto_shots(shot)


func _p(x: float, y: float) -> Vector2:
	return (Vector2(x, y) * squash).round()


func _sprite(key: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/%s_0.png" % key)
	s.centered = false
	s.offset = Vector2(-7, -17)
	actors.add_child(s)
	return s


func _build_camp() -> void:
	var news := []
	for item in Save.meta.camp:
		if not Save.camp_built(item):
			continue
		built.append(item)
		if not Save.data.camp_seen.has(item.id):
			Save.data.camp_seen.append(item.id)
			if item.has("news") and Save.data.stats.runs > 0:
				news.append(item.news)
		var pos := _p(item.pos[0], item.pos[1])
		if item.kind in ["depart", "shop", "ach", "log", "market"]:
			spots.append({"kind": item.kind, "key": "", "name": item.name, "pos": pos, "r": 20.0})
	Save.save_profile()

	# 營火旁只隨機出現幾位（有話要說的一定在），人再多也不會塞滿（百基拉・亞居拉站一起）
	# 主角：選了誰，營地裡走動的就是他；保羅改坐在營火旁
	lead = str(Save.data.get("leader", "paul"))
	if lead != "paul" and not Save.is_unlocked("leader_" + lead):
		lead = "paul"
	var all := []
	for c in G.companions:
		if Save.is_unlocked(c.key) and c.get("follows", "") == "" and c.key != lead:
			all.append(c)
	var pending := _choose_talks(all)
	all.shuffle()
	var list := all.filter(func(c): return pending.has(c.key))
	for c in all:
		if list.size() >= int(Save.meta.get("camp_visible", 8)):
			break
		if not list.has(c):
			list.append(c)
	for i in list.size():
		var c: Dictionary = list[i]
		var a := PI * 0.75 + i * TAU / maxf(list.size(), 5.0)
		var pos := _p(cos(a) * 46.0, sin(a) * 26.0 + 6.0)
		var node := _sprite(c.key)
		node.position = pos
		node.flip_h = pos.x > 0.0
		people.append({"key": c.key, "pos": pos, "node": node, "ph": randf() * TAU})
		if c.get("with", "") != "":
			var n2 := _sprite(c.with)
			n2.position = pos + Vector2(12, 2)
			n2.flip_h = node.flip_h
		var nm: String = c.name + ("・" + _name_of(c.with) if c.get("with", "") != "" else "")
		spots.append({"kind": "comp", "key": c.key, "name": nm, "pos": pos + (Vector2(6, 0) if c.get("with", "") != "" else Vector2.ZERO), "r": 12.0})

	# 營地四周固定的樹和石頭
	for d in [["tree_1", -150, -70], ["tree_2", 150, -78], ["tree_3", -160, 70], ["tree_2", 165, 80], ["tree_1", 40, -88],
			["rock_1", -60, -70], ["rock_2", 70, 70], ["rock_3", -150, -5], ["bush", 30, 82], ["bush", -100, 84]]:
		var tr := Sprite2D.new()
		tr.texture = load("res://assets/sprites/%s.png" % d[0])
		tr.centered = false
		tr.offset = Vector2(-tr.texture.get_width() / 2.0, -tr.texture.get_height())
		tr.position = _p(d[1], d[2])
		actors.add_child(tr)

	var start := _p(-10, 22)
	if Save.data.stats.runs > 0:
		start = _p(110, 40)   # 剛從路上回來
	paul = {"pos": start, "node": _sprite(lead), "moving": false}
	if lead != "paul":
		var pn := _sprite("paul")
		pn.position = _p(-14, -6)
		people.append({"key": "paul", "pos": pn.position, "node": pn, "ph": randf() * TAU})
	if not news.is_empty():
		news_label_text = "\n".join(news)


var news_label_text := ""


func _name_of(key: String) -> String:
	for c in G.companions:
		if c.key == key:
			return c.name
	return key


func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var title := UIKit.label(Save.camp_name(), 20, UIKit.GOLD)
	title.position = Vector2(12, 6)
	hud.add_child(title)
	witness_label = UIKit.label("", 14, UIKit.SKY)
	hud.add_child(witness_label)
	hint_label = UIKit.label("", 12, C_CREAM)
	hud.add_child(hint_label)
	news_label = UIKit.label("", 13, C_GOLD)
	news_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(news_label)
	if news_label_text != "":
		news_label.text = "營地新設施！\n" + news_label_text
		news_until = 5.0
	var go := UIKit.button("出發", 15, true)
	go.custom_minimum_size = Vector2(88, 36)
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(func(): _interact({"kind": "depart"}))
	go.name = "GoButton"
	hud.add_child(go)
	talk_box = PanelContainer.new()
	talk_box.add_theme_stylebox_override("panel", UIKit.box(Color(0.1, 0.07, 0.12, 0.95), UIKit.GOLD, 10))
	talk_box.visible = false
	hud.add_child(talk_box)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	talk_box.add_child(th)
	talk_icon = TextureRect.new()
	talk_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	talk_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	talk_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	talk_icon.custom_minimum_size = Vector2(42, 51)
	th.add_child(talk_icon)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(tv)
	talk_name = UIKit.label("", 13, UIKit.GOLD)
	tv.add_child(talk_name)
	talk_text = UIKit.label("", 14, C_INK)
	talk_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	talk_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(talk_text)
	var more := UIKit.label("▼", 10, UIKit.MUTED)
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(more)
	var p2 = load("res://scripts/base.gd").new()
	panel = p2
	hud.add_child(panel)
	panel.tabs_enabled = {"home": true, "roster": true, "shop": _has("shop"), "gifts": _has("shop"), "ach": _has("ach"), "log": true}
	panel.closed.connect(func(): target = null)


## 每次從旅程回來，挑幾位同伴有話要說
## 這次回營地有誰要聊天（每次回來挑一次；同一次回來保留還沒聊完的）
func _choose_talks(unlocked: Array) -> Array:
	T = JSON.parse_string(FileAccess.get_file_as_string("res://data/talks.json"))
	var runs: int = Save.data.stats.runs
	if runs == 0 or int(Save.data.get("talk_run", -1)) == runs:
		return Save.data.get("talk_pending", [])
	Save.data.talk_run = runs
	var cands := []
	for c in unlocked:
		var seen: int = int(Save.data.get("talks_seen", {}).get(c.key, 0))
		if T.talks.has(c.key) and seen < T.talks[c.key].size():
			cands.append(c.key)
	cands.shuffle()
	Save.data.talk_pending = cands.slice(0, int(T.per_visit))
	Save.save_profile()
	return Save.data.talk_pending


func _pick_bubbles() -> void:
	for k in Save.data.get("talk_pending", []):
		_add_bubble(k)


func _add_bubble(key: String) -> void:
	var seen: int = int(Save.data.get("talks_seen", {}).get(key, 0))
	if T.talks.has(key) and seen < T.talks[key].size():
		bubbles[key] = T.talks[key][seen]


func _start_talk(key: String) -> void:
	talk = bubbles[key]
	talk_key = key
	talk_i = 0
	_show_line()


func _show_line() -> void:
	var line: Array = talk[talk_i]
	var who: String = line[0]
	talk_icon.texture = load("res://assets/sprites/%s_0.png" % who)
	talk_name.text = G.paul.name if who == "paul" else _name_of(who)
	talk_text.text = line[1]
	talk_box.visible = true
	# 打字機效果＋咕噥聲
	var vo: Dictionary = T.get("voices", {}).get(who, {})
	type_pitch = float(vo.get("pitch", 1.0))
	type_speed = float(vo.get("speed", 26.0))
	type_t = 0.0
	type_shown = 0
	typing = true
	talk_text.visible_characters = 0


func _advance_talk() -> void:
	if typing:
		typing = false
		talk_text.visible_characters = -1
		return
	talk_i += 1
	if talk_i < talk.size():
		_show_line()
		return
	# 聊完：默契增加、記錄看過
	talk_box.visible = false
	var seen: Dictionary = Save.data.get("talks_seen", {})
	seen[talk_key] = int(seen.get(talk_key, 0)) + 1
	Save.data.talks_seen = seen
	Save.data.affinity[talk_key] = Save.affinity_xp(talk_key) + int(T.talk_bonus)
	Save.data.talk_pending.erase(talk_key)
	Save.save_profile()
	bubbles.erase(talk_key)
	news_label.text = "與%s的默契 +%d" % [_name_of(talk_key), int(T.talk_bonus)]
	news_until = 1.6
	Sfx.play("heal", 0.0)
	talk = []


func _has(kind: String) -> bool:
	for b in built:
		if b.kind == kind:
			return true
	return false


# ---------- 移動與互動 ----------
func _process(dt: float) -> void:
	t += dt
	news_until -= dt
	var busy: bool = panel.visible or not talk.is_empty()
	var mv := Vector2.ZERO
	if not busy:
		mv = Vector2(
			float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		if mv != Vector2.ZERO:
			target = null
			walk_to = null
		elif target != null:
			var to: Vector2 = target.pos + Vector2(0, 10) - paul.pos
			if to.length() < 4.0:
				var tg = target
				target = null
				_interact(tg)
			else:
				mv = to.normalized()
		elif walk_to != null:
			var to2: Vector2 = walk_to - paul.pos
			if to2.length() < 3.0:
				walk_to = null
			else:
				mv = to2.normalized()
	paul.moving = mv != Vector2.ZERO
	paul.pos += mv.normalized() * 55.0 * dt
	var lim := _p(150, 85)
	paul.pos = paul.pos.clamp(-lim, lim)
	paul.node.position = paul.pos.round()
	if mv.x != 0.0:
		paul.node.flip_h = mv.x < 0.0
	var f := int(t * 6.0) % 2 if paul.moving else 0
	paul.node.texture = load("res://assets/sprites/%s_%d.png" % [lead, f])
	for p in people:
		p.node.position = p.pos + Vector2(0, roundf(sin(t * 1.6 + p.ph) * 0.6))

	if typing:
		type_t += dt * type_speed
		var n := mini(int(type_t), talk_text.text.length())
		while type_shown < n:
			var ch := talk_text.text[type_shown]
			type_shown += 1
			if type_shown % 2 == 1 and not ch in "，。、；：！？「」（）… 0123456789:–":
				Sfx.voice(type_pitch)
		talk_text.visible_characters = n
		if n >= talk_text.text.length():
			typing = false
	_update_hud()
	props.queue_redraw()
	tags.queue_redraw()


func _near() -> Variant:
	var best = null
	var bd := 9999.0
	for s in spots:
		var d: float = paul.pos.distance_to(s.pos + Vector2(0, 10))
		if d < s.r + 8.0 and d < bd:
			best = s
			bd = d
	return best


func _unhandled_input(event: InputEvent) -> void:
	if panel.visible:
		return
	if not talk.is_empty():
		var adv: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_E, KEY_ENTER]) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		if adv:
			_advance_talk()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_E, KEY_ENTER]:
			var n = _near()
			if n != null:
				_interact(n)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var wp := get_global_mouse_position()
		var hit = null
		for s in spots:
			if wp.distance_to(s.pos + Vector2(0, -6)) < s.r + 6.0:
				hit = s
		if hit != null:
			target = hit
			walk_to = null
		else:
			walk_to = wp
			target = null


func _interact(s: Dictionary) -> void:
	walk_to = null
	match s.kind:
		"comp":
			if bubbles.has(s.key):
				_start_talk(s.key)
			else:
				panel.open("roster", s.key)
		"shop": panel.open("shop")
		"ach": panel.open("ach")
		"log": panel.open("log")
		"market": panel.open("market")
		_: panel.open("home")


func _update_hud() -> void:
	var vs := get_viewport().get_visible_rect().size
	witness_label.text = "見證 %d　餅 %d" % [Save.data.witness, int(Save.data.get("bread", 0))]
	witness_label.position = Vector2(vs.x - witness_label.size.x - 12.0, 10)
	var go := hud.get_node("GoButton") as Button
	go.position = Vector2(vs.x - 100.0, vs.y - 48.0)
	go.visible = not panel.visible and talk.is_empty()
	var n = _near()
	var touch := DisplayServer.is_touchscreen_available()
	if n != null:
		hint_label.text = ("點一下：" if touch else "空白鍵：") + _verb(n)
	else:
		hint_label.text = "點同伴或設施就會走過去" if touch else "WASD 移動，靠近按空白鍵"
	hint_label.position = Vector2(14, vs.y - 30.0)
	talk_box.size = Vector2(minf(vs.x - 24.0, 460.0), 0)
	talk_box.position = Vector2(roundf((vs.x - talk_box.size.x) / 2.0), vs.y - talk_box.size.y - 60.0)
	hint_label.visible = not panel.visible and talk.is_empty()
	news_label.visible = news_until > 0.0 and not panel.visible
	if news_label.visible:
		news_label.modulate.a = clampf(news_until, 0.0, 1.0)
		news_label.position = Vector2(roundf((vs.x - news_label.size.x) / 2.0), 44)


func _verb(s: Dictionary) -> String:
	match s.kind:
		"comp": return ("跟%s聊聊（默契 +）" if bubbles.has(s.key) else "看%s的生平") % s.name
		"shop": return "補給帳棚（解鎖）"
		"ach": return "見證牆"
		"log": return "製作日誌（看看改了什麼）"
		"market": return "市集（買下一趟的行囊）"
	return "看旅程地圖、出發"


# ---------- 畫營地 ----------
func _draw_props() -> void:
	var n := props
	var lit := _has("lamps")
	for b in built:
		var p := _p(b.pos[0], b.pos[1])
		match b.kind:
			"shop": _tent(n, p, 1.0, Color("c9a46b"), Color("a65a8e"))
			"tent_small": _tent(n, p, 0.7, Color("b89870"), Color("6f6a5a"))
			"ach": _board(n, p)
			"log": _log_post(n, p)
			"market": _market(n, p)
			"depart": _sign(n, p)
			"banner": _banner(n, p)
	# 用見證蓋的營地建設
	for bd in Save.meta.buildings:
		if Save.built(bd.id):
			_building(n, _p(bd.pos[0], bd.pos[1]), bd.id)
	# 營火
	var fl := 0.5 + 0.5 * sin(t * 9.0) * sin(t * 5.3)
	n.draw_circle(Vector2(0, 2), 30.0 + fl * 3.0, Color(1.0, 0.6, 0.2, 0.08))
	n.draw_circle(Vector2(0, 2), 16.0 + fl * 2.0, Color(1.0, 0.7, 0.3, 0.12))
	for i in 5:
		var a := i * TAU / 5.0
		n.draw_rect(Rect2(Vector2(cos(a) * 7.0, 3.0 + sin(a) * 3.0).round() - Vector2(2, 1), Vector2(4, 2)), Color("8a8478"))
	n.draw_rect(Rect2(-5, 1, 10, 2), Color("5a3f28"))
	n.draw_rect(Rect2(-3, -1, 6, 2), Color("6b4a2a"))
	var h := 4.0 + fl * 3.0
	n.draw_rect(Rect2(-3, 1 - h, 6, h), Color("e8481c"))
	n.draw_rect(Rect2(-2, 1 - h * 0.8, 4, h * 0.8), Color("ff8a2a"))
	n.draw_rect(Rect2(-1, 1 - h * 0.5, 2, h * 0.5), Color("ffd75e"))
	if lit:
		for i in 6:
			var a := i * TAU / 6.0 + 0.3
			var lp := _p(cos(a) * 92.0, sin(a) * 52.0)
			n.draw_circle(lp + Vector2(0, -9), 6.0, Color(1.0, 0.8, 0.4, 0.15))
			n.draw_rect(Rect2(lp.x, lp.y - 8, 1, 8), Color("5a3f28"))
			n.draw_rect(Rect2(lp.x - 1, lp.y - 10, 3, 2), Color("ffd75e"))


func _tent(n: Node2D, p: Vector2, s: float, cloth: Color, stripe: Color) -> void:
	var w := 26.0 * s
	var h := 20.0 * s
	n.draw_colored_polygon(PackedVector2Array([p + Vector2(-w, 0), p + Vector2(0, -h), p + Vector2(w, 0)]), cloth)
	n.draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.35, 0), p + Vector2(0, -h * 0.75), p + Vector2(w * 0.35, 0)]), Color("2a1e22"))
	n.draw_line(p + Vector2(-w, 0), p + Vector2(0, -h), stripe, 2.0)
	n.draw_line(p + Vector2(w, 0), p + Vector2(0, -h), stripe, 2.0)
	n.draw_rect(Rect2(p.x - 1, p.y - h - 4, 1, 5), Color("5a3f28"))


func _board(n: Node2D, p: Vector2) -> void:
	n.draw_rect(Rect2(p.x - 14, p.y - 18, 2, 18), Color("5a3f28"))
	n.draw_rect(Rect2(p.x + 12, p.y - 18, 2, 18), Color("5a3f28"))
	n.draw_rect(Rect2(p.x - 15, p.y - 22, 30, 14), Color("8a6438"))
	n.draw_rect(Rect2(p.x - 13, p.y - 20, 26, 10), Color("c9a46b"))
	var done: int = Save.data.achievements.size()
	for i in mini(done, 9):
		n.draw_rect(Rect2(p.x - 11 + (i % 5) * 5, p.y - 19 + (i / 5) * 5, 3, 3), Color("fff4c2"))


## 市集的攤子：條紋布棚、桌上擺著東西
func _market(n: Node2D, p: Vector2) -> void:
	n.draw_rect(Rect2(p.x - 14, p.y - 8, 28, 8), Color("8a6438"))
	n.draw_rect(Rect2(p.x - 13, p.y - 20, 2, 12), Color("5a3f28"))
	n.draw_rect(Rect2(p.x + 11, p.y - 20, 2, 12), Color("5a3f28"))
	for i in 7:
		n.draw_rect(Rect2(p.x - 15 + i * 4, p.y - 24, 4, 5), Color("9a4ab8") if i % 2 == 0 else Color("efe2c0"))
	for i in 4:
		n.draw_rect(Rect2(p.x - 10 + i * 6, p.y - 11, 3, 3), [Color("e0b060"), Color("7a8a3a"), Color("b05a3a"), Color("ffd75e")][i])


## 製作日誌告示：木樁上釘一張紙；有新版本還沒看時，上面有閃爍的驚嘆號
func _log_post(n: Node2D, p: Vector2) -> void:
	n.draw_rect(Rect2(p.x - 1, p.y - 18, 2, 18), Color("5a3f28"))
	n.draw_rect(Rect2(p.x - 8, p.y - 22, 16, 12), Color("efe2c0"))
	n.draw_rect(Rect2(p.x - 8, p.y - 22, 16, 1), Color("c9a46b"))
	for i in 3:
		n.draw_rect(Rect2(p.x - 6, p.y - 19 + i * 3, 12 - (i % 2) * 4, 1), Color("8a7a5a"))
	if panel != null and panel.has_new_log() and int(t * 3.0) % 2 == 0:
		n.draw_rect(Rect2(p.x - 1, p.y - 33, 3, 7), Color("ffd75e"))
		n.draw_rect(Rect2(p.x - 1, p.y - 25, 3, 2), Color("ffd75e"))


func _building(n: Node2D, p: Vector2, id: String) -> void:
	var W := Color("5a3f28")
	match id:
		"well":
			n.draw_circle(p + Vector2(0, -3), 7.0, Color("8a8478"))
			n.draw_circle(p + Vector2(0, -3), 4.5, Color("2a4a6a"))
			n.draw_rect(Rect2(p.x - 8, p.y - 16, 2, 13), W)
			n.draw_rect(Rect2(p.x + 6, p.y - 16, 2, 13), W)
			n.draw_rect(Rect2(p.x - 9, p.y - 18, 18, 2), Color("8a6438"))
		"tower":
			n.draw_rect(Rect2(p.x - 6, p.y - 30, 2, 30), W)
			n.draw_rect(Rect2(p.x + 4, p.y - 30, 2, 30), W)
			n.draw_rect(Rect2(p.x - 8, p.y - 34, 16, 5), Color("8a6438"))
			n.draw_colored_polygon(PackedVector2Array([p + Vector2(-9, -34), p + Vector2(9, -34), p + Vector2(0, -42)]), Color("a65a3a"))
		"altar":
			n.draw_rect(Rect2(p.x - 9, p.y - 8, 18, 8), Color("9a958a"))
			n.draw_rect(Rect2(p.x - 9, p.y - 8, 18, 2), Color("c8c2b2"))
			var fl := 3.0 + sin(t * 8.0) * 1.0
			n.draw_rect(Rect2(p.x - 2, p.y - 8 - fl, 4, fl), Color("ff8a2a"))
		"library":
			n.draw_rect(Rect2(p.x - 12, p.y - 16, 24, 16), Color("c8b898"))
			n.draw_colored_polygon(PackedVector2Array([p + Vector2(-14, -16), p + Vector2(14, -16), p + Vector2(0, -24)]), Color("8a5a3a"))
			n.draw_rect(Rect2(p.x - 3, p.y - 8, 6, 8), W)
		"table":
			n.draw_rect(Rect2(p.x - 16, p.y - 6, 32, 4), Color("8a6438"))
			n.draw_rect(Rect2(p.x - 14, p.y - 2, 2, 4), W)
			n.draw_rect(Rect2(p.x + 12, p.y - 2, 2, 4), W)
			for i in 4:
				n.draw_rect(Rect2(p.x - 12 + i * 7, p.y - 8, 3, 2), Color("e0b060"))
		"garden":
			for i in 5:
				var q := p + Vector2(-12 + i * 6, -2 + (i % 2) * 3)
				n.draw_circle(q, 3.0, Color("5b6b2f"))
				n.draw_rect(Rect2(q.x, q.y - 2, 1, 1), [Color("ff7aa8"), Color("ffd75e"), Color("c8a0ff")][i % 3])
		"forge":
			n.draw_rect(Rect2(p.x - 10, p.y - 12, 20, 12), Color("6a665e"))
			n.draw_rect(Rect2(p.x - 4, p.y - 8, 8, 6), Color("ff8a2a") if int(t * 4.0) % 2 == 0 else Color("e8481c"))
			n.draw_rect(Rect2(p.x + 4, p.y - 20, 4, 8), Color("4a4640"))


func _sign(n: Node2D, p: Vector2) -> void:
	n.draw_rect(Rect2(p.x, p.y - 16, 2, 16), Color("5a3f28"))
	n.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -16), p + Vector2(12, -16), p + Vector2(16, -12), p + Vector2(12, -8), p + Vector2(-8, -8)]), Color("c9a46b"))
	n.draw_line(p + Vector2(-6, -12), p + Vector2(10, -12), Color("5a3f28"), 1.0)
	# 往外的小路
	for i in 8:
		n.draw_rect(Rect2(p.x + 6 + i * 6, p.y + 3 + sin(i) * 2.0, 4, 2), Color(0.85, 0.75, 0.55, 0.5))


func _banner(n: Node2D, p: Vector2) -> void:
	n.draw_rect(Rect2(p.x, p.y - 26, 1, 26), Color("5a3f28"))
	var wave := sin(t * 3.0)
	n.draw_colored_polygon(PackedVector2Array([p + Vector2(1, -26), p + Vector2(15, -23 + wave), p + Vector2(1, -18)]), Color("ffd75e"))


func _draw_tags() -> void:
	var n := tags
	var font := UIKit.font()
	var near = _near()
	for s in spots:
		if s.kind == "comp" and bubbles.has(s.key):
			# 有話要說：頭上一個小對話框
			var bp: Vector2 = s.pos + Vector2(4, -28 + roundf(sin(t * 3.0 + s.pos.x)))
			n.draw_rect(Rect2(bp.x - 1, bp.y - 1, 12, 8), Color("140c10"))
			n.draw_rect(Rect2(bp.x, bp.y, 10, 6), Color.WHITE)
			n.draw_rect(Rect2(bp.x + 1, bp.y + 6, 2, 2), Color.WHITE)
			for d in 3:
				n.draw_rect(Rect2(bp.x + 2 + d * 3, bp.y + 2, 1, 1), Color("3a2a20"))
	for s in spots:
		if s.kind == "comp" and s != near:
			continue
		var txt: String = s.name
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var y: float = s.pos.y - (22.0 if s.kind == "comp" else 26.0)
		var pos := Vector2(roundf(s.pos.x - w / 2.0), y)
		var col := C_GOLD if s == near else C_INK
		n.draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color("140c10"))
		n.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		if s == near:
			var by := y - 9.0 + roundf(sin(t * 5.0))
			n.draw_rect(Rect2(s.pos.x - 1, by, 3, 3), C_GOLD)


# ---------- 自動截圖測試 ----------
func _auto_shots(shot: String) -> void:
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png(shot.replace(".png", "_camp.png"))
	paul.pos = spots[0].pos + Vector2(-4, 10)
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(shot.replace(".png", "_near.png"))
	if not bubbles.is_empty():
		get_viewport().get_texture().get_image().save_png(shot.replace(".png", "_bubble.png"))
		_start_talk(bubbles.keys()[0])
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png(shot.replace(".png", "_talk.png"))
		while not talk.is_empty():
			typing = false
			_advance_talk()
	await panel.auto_shots(shot)
	get_tree().quit()
