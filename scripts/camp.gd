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
	get_tree().set_quit_on_go_back(false)   # 返回鍵自己處理（見 _notification）
	var vs := get_viewport().get_visible_rect().size
	portrait = vs.y > vs.x
	# 直式：把營地往上下拉長，讓東西都放得進窄畫面
	squash = Vector2(0.6, 2.0) if portrait else Vector2.ONE

	var ground := Sprite2D.new()
	ground.texture = load("res://assets/sprites/ground_camp.png")
	ground.region_enabled = true
	ground.region_rect = Rect2(0, 0, 1024, 1024)
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.z_index = -2
	add_child(ground)
	floor_node = Sprite2D.new()   # 營地中間踩出來的泥土地與小路（_build_floor）
	floor_node.z_index = -2
	add_child(floor_node)
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
	if not portrait:
		cam.position.y = -8.0   # 上排的建設比較高，畫面往上一點

	_build_camp()
	_build_hud()
	_pick_bubbles()
	Sfx.music("camp")
	if Save.has_run_save():
		panel.open.call_deferred("home")   # 上一局還沒走完：直接打開出發面板，最上面就是「繼續這一局」

	var shot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.substr(7)
	if shot != "":
		_auto_shots(shot)


## 手機的返回鍵：先關面板／對話，再回標題畫面


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if panel != null and panel.visible:
		panel.close()
	elif not talk.is_empty():
		talk.clear()
		if talk_box != null:
			talk_box.visible = false
	else:
		get_tree().change_scene_to_file("res://scenes/title.tscn")   # 回標題畫面（在標題按返回才離開）


func _p(x: float, y: float) -> Vector2:
	return (Vector2(x, y) * squash).round()


## 設施的位置：直式畫面有自己排的 pos_v（建設有高有寬，直接壓窄會擠在一起）
func _at(item: Dictionary) -> Vector2:
	if portrait and item.has("pos_v"):
		return Vector2(item.pos_v[0], item.pos_v[1])
	return _p(item.pos[0], item.pos[1])


const LAMPS := [[-46, -36], [56, -34], [112, -8], [30, 46], [-40, 42], [-84, -2]]
const LAMPS_V := [[-30, -36], [36, -40], [50, 40], [-40, 86], [20, 92], [-40, -30]]


func _lamp_pos(i: int) -> Vector2:
	var l: Array = LAMPS_V[i] if portrait else LAMPS[i]
	return Vector2(l[0], l[1])


func _sprite(key: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/%s_0.png" % key)
	s.centered = false
	s.offset = Vector2(-12, -25)
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
		var pos := _at(item)
		if item.kind in ["depart", "shop", "ach", "log", "supper"]:
			spots.append({"kind": item.kind, "key": "", "name": item.name, "pos": pos, "r": 20.0})
	for bd in Save.meta.buildings:
		if Save.built(bd.id):
			spots.append({"kind": "bld", "key": bd.id, "name": bd.name, "pos": _at(bd), "r": 18.0})
	Save.save_profile()
	for b in built:
		var bp := _at(b)
		if PROP_TEX.has(b.kind):
			_place(PROP_TEX[b.kind], bp, {"ach": "notes", "log": "log", "banner": "flag", "depart": "road"}.get(b.kind, ""))
		elif b.kind == "lamps":
			for i in LAMPS.size():
				_place("lamp", _lamp_pos(i), "lamp")
	for bd in Save.meta.buildings:
		if Save.built(bd.id):
			var bp := _at(bd)
			if bd.id == "garden":
				garden_node = _place("garden_%d" % _garden_stage(), bp)
			else:
				_place(bd.id, bp, bd.id if bd.id in ["altar", "forge"] else "")
	_place("fire", Vector2(0, 7), "fire")
	_build_floor()

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
	for d in [["tree_1", -150, -70], ["tree_2", 176, -62], ["tree_3", -160, 70], ["tree_2", 165, 80], ["tree_1", 58, -100],
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
var floor_node: Sprite2D
var fx_nodes: Array = []   # 建設上會動的東西（火、旗子、見證牆的紙）
var garden_node: Sprite2D

const PROP_TEX := {"shop": "tent_big", "tent_small": "tent_small", "ach": "board", "log": "log", "depart": "sign",
	"banner": "banner", "supper": "supper"}


## 一個貼地的物件（圖的底邊中間對準 pos），放進 actors 跟人一起依 y 排序；fx 是畫在它上面會動的東西
func _place(tex: String, pos: Vector2, fx := "") -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/camp_%s.png" % tex)
	s.centered = false
	s.offset = Vector2(-floorf(s.texture.get_width() / 2.0), -s.texture.get_height())
	s.position = pos
	actors.add_child(s)
	if fx != "":
		var n := Node2D.new()
		n.draw.connect(_draw_fx.bind(n, fx))
		s.add_child(n)
		fx_nodes.append(n)
	return s


func _garden_stage() -> int:
	var g: Dictionary = Save.data.get("garden", {})
	if g.is_empty():
		return 0
	return 2 if int(Save.data.stats.runs) - int(g.at) >= 3 else 1


## 泥土地：營火四周一大片，加上通往每一座建設的小路（依實際位置算，直式畫面也對得上）
func _build_floor() -> void:
	var lim := _p(190, 110)
	var w := int(lim.x * 2.0)
	var hh := int(lim.y * 2.0)
	var dirt := PackedFloat32Array()
	dirt.resize(w * hh)
	var org := -lim
	var stamp := func(c: Vector2, rx: float, ry: float) -> void:
		for y in range(maxi(0, int(c.y - ry - org.y)), mini(hh, int(c.y + ry - org.y) + 1)):
			for x in range(maxi(0, int(c.x - rx - org.x)), mini(w, int(c.x + rx - org.x) + 1)):
				var d := Vector2((x + org.x - c.x) / rx, (y + org.y - c.y) / ry).length_squared()
				var i := y * w + x
				dirt[i] = maxf(dirt[i], 1.0 - d)
	stamp.call(_p(0, 6), 74.0 * squash.x, 40.0 * squash.y)
	var ends := []
	for sp in spots:
		if sp.kind != "comp":
			ends.append(sp.pos)
	ends.append(_p(190, 40))   # 往外的路
	for e in ends:
		stamp.call(e + Vector2(0, 4), 16.0, 7.0)
		var a := Vector2(0, 6)
		var steps := int(a.distance_to(e) / 3.0)
		for k in steps + 1:
			var q := a.lerp(e, float(k) / maxf(steps, 1))
			q += Vector2(0, sin(k * 0.35) * 2.0)
			stamp.call(q, 5.0, 4.0)
	var img := Image.create(w, hh, false, Image.FORMAT_RGBA8)
	var cols := [Color("a48662"), Color("b49470"), Color("c4a47a")]
	for y in hh:
		for x in w:
			var v := dirt[y * w + x]
			var r := float(hash(Vector2i(x, y)) % 1000) / 1000.0
			if v + (r - 0.5) * 0.12 <= 0.05:
				continue
			var lo := float(hash(Vector2i(x / 6, y / 4)) % 1000) / 1000.0   # 一塊一塊的深淺，不要每一點都跳
			var c: Color = cols[2] if v > 0.5 and lo > 0.6 else cols[1]
			if v < 0.16:
				c = cols[0]
			if r > 0.985:
				c = Color("e0d0b0")
			img.set_pixel(x, y, c)
	floor_node.texture = ImageTexture.create_from_image(img)
	floor_node.centered = false
	floor_node.position = org


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
		if not _talk_lines(c.key).is_empty():
			cands.append(c.key)
	cands.shuffle()
	Save.data.talk_pending = cands.slice(0, int(T.per_visit))
	Save.save_profile()
	return Save.data.talk_pending


func _pick_bubbles() -> void:
	for k in Save.data.get("talk_pending", []):
		_add_bubble(k)


func _add_bubble(key: String) -> void:
	var lines := _talk_lines(key)
	if not lines.is_empty():
		bubbles[key] = lines


## 這位同伴下一段要聊的內容；還沒到劇情時間（after 那座城還沒建立教會）就回傳空的
func _talk_lines(key: String) -> Array:
	var seen: int = int(Save.data.get("talks_seen", {}).get(key, 0))
	if not T.talks.has(key) or seen >= T.talks[key].size():
		return []
	var sg = T.talks[key][seen]
	if sg is Dictionary:
		if not Save.data.churches.has(str(sg.get("after", ""))):
			return []
		return sg.lines
	return sg


## 擘餅的桌子：同伴圍著一起記念主（不加默契、不記錄，隨時可以來）
func _start_supper() -> void:
	var sp: Dictionary = T.get("supper", {})
	talk = sp.get("after_corinth" if Save.data.churches.has("corinth") else "before_corinth", [])
	if talk.is_empty():
		return
	talk_key = ""
	talk_i = 0
	_show_line()


## 營地建設的互動：水井每天的活水、祭壇的祝福、書房的書卷、園子收成……
const WELL_VERSES := [["約 4:14", "人若喝我所賜的水，就永遠不渴。"], ["詩 23:2", "祂使我躺臥在青草地上，領我在可安歇的水邊。"],
	["賽 40:31", "但那等候耶和華的，必從新得力。他們必如鷹展翅上騰。"], ["太 11:28", "凡勞苦擔重擔的人可以到我這裡來，我就使你們得安息。"],
	["腓 4:13", "我靠著那加給我力量的，凡事都能做。"], ["詩 46:1", "神是我們的避難所，是我們的力量，是我們在患難中隨時的幫助。"],
	["羅 8:28", "我們曉得萬事都互相效力，叫愛神的人得益處。"], ["哀 3:22-23", "我們不至消滅，是出於耶和華諸般的慈愛……每早晨，這都是新的。"]]


func _say(lines: Array) -> void:
	# 用對話框說幾句話（who 用 paul 就是主角在想）
	talk = lines
	talk_key = ""
	talk_i = 0
	_show_line()


func _use_building(id: String) -> void:
	var today := Time.get_date_string_from_system()
	match id:
		"well":
			var v: Array = WELL_VERSES[hash(today) % WELL_VERSES.size()]
			if str(Save.data.get("well_day", "")) != today:
				Save.data.well_day = today
				Save.data.bread = int(Save.data.get("bread", 0)) + 5
				Save.save_profile()
				_say([["paul", "（打了一桶水。）今天的話：「%s」（%s）\n餅 +5" % [v[1], v[0]]]])
			else:
				_say([["paul", "「%s」（%s）\n今天已經打過水了，明天再來。" % [v[1], v[0]]]])
		"altar":
			panel.open("altar")
		"library":
			panel.open("library")
		"tower":
			panel.open("home")
		"forge":
			panel.open("shop")
		"granary":
			panel.open("gifts")
		"garden":
			var g: Dictionary = Save.data.get("garden", {})
			var runs := int(Save.data.stats.runs)
			if g.is_empty():
				Save.data.garden = {"at": runs}
				Save.save_profile()
				_say([["paul", "在園子裡撒下種子。（再出發 3 趟就能收成）「我栽種了，亞波羅澆灌了，惟有神叫他生長。」（林前 3:6）"]])
			elif runs - int(g.at) >= 3:
				Save.data.garden = {"at": runs}
				Save.data.bread = int(Save.data.get("bread", 0)) + 40
				Save.data.witness = int(Save.data.witness) + 20
				Save.save_profile()
				_say([["paul", "園子收成了！餅 +40、見證 +20。又撒下了新的種子。"]])
			if garden_node != null:
				garden_node.texture = load("res://assets/sprites/camp_garden_%d.png" % _garden_stage())
			else:
				_say([["paul", "種子正在長。（再出發 %d 趟就能收成）" % (3 - (runs - int(g.at)))]])
		"table":
			var last := int(Save.data.get("feast_run", -1))
			if last == int(Save.data.stats.runs):
				_say([["paul", "剛剛才一起吃過飯。下次出發回來再聚吧。"]])
			else:
				Save.data.feast_run = int(Save.data.stats.runs)
				var names := []
				for p in people:
					if p.key != "paul":
						Save.data.affinity[p.key] = Save.affinity_xp(p.key) + 2
						names.append(_name_of(p.key))
				Save.save_profile()
				_say([["paul", "大家坐下來一起吃飯。（%s的默契 +2）「他們天天同心合意……存著歡喜誠實的心用飯。」（徒 2:46）" % "、".join(names.slice(0, 4))]])


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
	talk_box.visible = false
	if talk_key == "":
		talk = []      # 擘餅：安靜地結束，不加默契
		return
	# 聊完：默契增加、記錄看過
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
	for n in fx_nodes:
		n.queue_redraw()
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
		"supper": _start_supper()
		"bld": _use_building(str(s.key))
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
		"supper": return "一起擘餅，記念主"
		"bld": return {"well": "打水（每天一次）", "altar": "禱告：為下一趟求祝福", "library": "讀找到的書卷", "tower": "眺望：今日挑戰",
			"garden": "看看園子", "forge": "工坊：軍裝與解鎖", "granary": "倉房：恩賜", "table": "在愛筵長桌一起吃飯"}.get(s.key, s.name)
	return "看旅程地圖、出發"


# ---------- 畫營地 ----------
func _draw_props() -> void:
	# 地上的光（畫在人和建設後面）；營地的東西本身是 _place 放的圖
	var n := props
	var fl := 0.5 + 0.5 * sin(t * 9.0) * sin(t * 5.3)
	n.draw_circle(Vector2(0, 4), 34.0 + fl * 3.0, Color(1.0, 0.6, 0.2, 0.07))
	n.draw_circle(Vector2(0, 4), 18.0 + fl * 2.0, Color(1.0, 0.7, 0.3, 0.1))
	if _has("lamps"):
		for i in LAMPS.size():
			n.draw_circle(_lamp_pos(i) + Vector2(0, -2), 9.0, Color(1.0, 0.8, 0.4, 0.08))


## 建設上會動的部分（座標以建設的底邊中間為原點）
func _draw_fx(n: Node2D, kind: String) -> void:
	var fl := 0.5 + 0.5 * sin(t * 9.0 + n.get_instance_id() % 7) * sin(t * 5.3)
	match kind:
		"fire":
			var h := 4.0 + fl * 4.0
			n.draw_rect(Rect2(-3, -2 - h, 6, h), Color("e8481c"))
			n.draw_rect(Rect2(-2, -2 - h * 0.8, 4, h * 0.8), Color("ff8a2a"))
			n.draw_rect(Rect2(-1, -2 - h * 0.5, 2, h * 0.5), Color("ffd75e"))
			if int(t * 5.0) % 3 == 0:
				n.draw_rect(Rect2(roundf(sin(t * 7.0) * 2.0), -6 - h - fmod(t * 20.0, 6.0), 1, 1), Color("ffd75e"))
		"altar":
			var h2 := 3.0 + fl * 3.0
			n.draw_rect(Rect2(-3, -16 - h2, 6, h2), Color("e8481c"))
			n.draw_rect(Rect2(-2, -16 - h2 * 0.75, 4, h2 * 0.75), Color("ffb040"))
			n.draw_rect(Rect2(-1, -16 - h2 - 3.0 - fmod(t * 6.0, 6.0), 1, 2), Color(0.8, 0.8, 0.8, 0.4))
		"forge":
			var c := Color("ff8a2a") if int(t * 4.0) % 2 == 0 else Color("e8481c")
			n.draw_rect(Rect2(-7, -14, 8, 5), c)
			n.draw_rect(Rect2(-5, -13, 4, 3), Color("ffd75e"))
			n.draw_circle(Vector2(-3, -12), 9.0, Color(1.0, 0.5, 0.2, 0.1))
			var sm := fmod(t * 5.0, 10.0)
			n.draw_rect(Rect2(1 + sm * 0.3, -36 - sm, 2, 2), Color(0.7, 0.7, 0.7, 0.4 - sm * 0.04))
		"lamp":
			n.draw_rect(Rect2(-1, -15 - roundf(fl), 2, 2 + roundf(fl)), Color("ffd75e"))
		"flag":
			var wave := roundf(sin(t * 3.0))
			n.draw_colored_polygon(PackedVector2Array([Vector2(1, -30), Vector2(15, -27 + wave), Vector2(1, -22)]), Color("ffd75e"))
			n.draw_line(Vector2(2, -26), Vector2(12, -26 + wave), Color("e0a820"), 1.0)
		"notes":
			var done: int = Save.data.achievements.size()
			for i in mini(done, 12):
				n.draw_texture(preload("res://assets/sprites/camp_note.png"), Vector2(-13 + (i % 6) * 4 + (i / 6) * 2, -23 + (i / 6) * 6))
		"log":
			if panel != null and panel.has_new_log() and int(t * 3.0) % 2 == 0:
				n.draw_rect(Rect2(-1, -36, 3, 7), Color("ffd75e"))
				n.draw_rect(Rect2(-1, -28, 3, 2), Color("ffd75e"))


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
		var y: float = s.pos.y - 22.0 if s.kind == "comp" else s.pos.y + 10.0   # 建設的名字寫在底下（建設有高有矮）
		var pos := Vector2(roundf(s.pos.x - w / 2.0), y)
		var col := C_GOLD if s == near else C_INK
		n.draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color("140c10"))
		n.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		if s == near:
			var by: float = (y - 9.0 if s.kind == "comp" else s.pos.y - 48.0) + roundf(sin(t * 5.0))
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
