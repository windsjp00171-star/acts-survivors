extends Node2D
## 主遊戲：移動、同伴招募與升級、自動攻擊、四種敵人與打散、同心合意與五旬節 FEVER、失敗。
## 數值全部來自 data/game.json。

const ZOOM := 2.5           # 鏡頭拉近、像素放大，畫面比較乾淨
const ZOOM_PORTRAIT := 1.9   # 直式畫面窄，鏡頭拉遠一點才看得到兩側的敵人
const CHUNK := 96
const SEP_CELL := 8.0
const DATA_PATH := "res://data/game.json"
## 隊形：同伴依加入順序站到這些位置（相對保羅）
const SLOTS := [Vector2(-24, 9), Vector2(24, 8), Vector2(-21, -10), Vector2(20, -11), Vector2(0, -21), Vector2(-7, 22)]

const C_GOLD := Color("ffd75e")
const C_CREAM := Color("fff4c2")
const C_SKY := Color("4fd8ff")
const C_HEAL := Color("7be08a")
const C_RED := Color("e8481c")
const C_FLAME := Color("ff8a2a")
const C_VL := Color("6b3a8c")

var D: Dictionary
var tex := {}
var t := 0.0
var kills := 0
var xp := 0
var level := 1
var xp_need := 6
var over := false
var choosing := false
var paused := false
var pending_cards: Array = []
var spawn_timer := 0.0
var scatter_by := {}
var shake := 0.0

var meter := 0.0
var fever := 0.0          # 剩餘秒數，>0 表示 FEVER 中
var fever_kills := 0
var fever_bursts: Array = []
var light := 0.0          # 光的身影剩下的秒數（五旬節時偶爾出現）
var light_max := 0.0
var run_lights := 0
var breads: Array = []    # 地上的餅
var run_bread := 0
var xp_acc := 0.0
var force_light := false

var fruits := {}          # 果子 key → 等級
var armor := {}           # 軍裝 key → 等級
var evolved := {}         # 同伴 key → 進化資料
var evo_timer := 0.0
var quake_key := ""       # 有「定時地震」型進化的同伴
var quakes: Array = []
var shield_cd := 0.0
var chests: Array = []
var chest_open := false
var elite_timer := 0.0
var trial_timer := 0.0
var boss = null
var boss_spawned := false
var won := false
var tele: Array = []      # Boss 的預警圖形
# 本局統計（給見證錄與結算）
var run_elites := 0
var run_fevers := 0
var run_evolutions := 0
var someone_down := false
var full_party := false
var tasks_done := 0
var task_witness := 0
var rerolls_left := 0
var t_start := 0.0
var hits: Array = []      # Boss 攻擊落下的閃光

var paul := {}
var pa := {}              # 保羅自己的攻擊（書信），用和同伴一樣的出招流程
var first_recruit := ""
var smoke_max_frames := 1800
var leader := "paul"      # 這一局的主角（同伴的 key；預設保羅）
var stage := {}           # 這一局的城市（data/stages.json）
var stage_i := 0
var epistles := {}        # 已選的書信卡效果
var founded_now := false  # 這局建立了新的教會
var trials: Array = []    # 這局打開的熬煉
var killed_types := {}    # 圖鑑用：這局打倒過的敵人種類   # 第一位同工：第一次升級一定出現他的招募卡
var comps: Array = []
var by_key := {}
var enemies: Array = []
var bolts: Array = []
var rings: Array = []
var beams: Array = []
var blasts: Array = []
var fires: Array = []     # 以利亞的火：先預兆再落下
var nets: Array = []      # 彼得的網（畫面效果）
var zaps: Array = []      # 約翰的閃電（畫面效果）
var thrusts: Array = []   # 多馬的刺擊（畫面效果）
var gathers: Array = []   # 安得烈的收聚（畫面效果）
var delayed: Array = []   # 延遲觸發的招式（參孫的第二下）
var links: Array = []     # 肢體連結：{src, dst, kind, cd}
var link_queue: Array = []
var link_fx: Array = []
var link_count := 0       # 本局觸發次數
var combo := 0            # 連擊：短時間內連續觸發的次數
var combo_t := 0.0
var combo_best := 0
var combo_tier := 0       # 這一串連擊已經共鳴到第幾層
var resonances: Array = []  # 共鳴衝擊波（畫面效果）
var sparks: Array = []    # 命中火花
var tag_fx: Array = []    # 流派專屬連結效果的小字
var dnums: Array = []     # 跳出來的傷害數字
var guard := 0            # 守護連結給的護盾層數
var haste_t := 0.0        # 詩歌連結：全隊加速剩下幾秒
var haste_amt := 0.0
var set_bonus := {}       # 已湊齊的套裝加成 {hp, regen, damage, speed}
var sets_on: Array = []
var grace_dmg := 0.0      # 恩上加恩（可疊加）
var grace_spd := 0.0      # 如鷹展翅（可疊加）
var mids_done := 0        # 中途 Boss 出現過幾次
var endless := false      # 無盡模式
var endless_boss_t := 0.0 # 無盡模式：下一隻 Boss 的時間
var endless_bosses := 0
var run_resonances := 0
var tip_queue: Array = []  # 新手教學：等著出現的提示
var run_chests := 0
var run_midboss := 0
var build_text := ""      # HUD 左側：同工與肢體連結
var run_tasks: Array = [] # 旅程任務：{def, done, failed}
var shots: Array = []
var gems: Array = []
var parts: Array = []
var heals: Array = []
var pops: Array = []
var chunks := {}
var solids: Array = []      # 擋路的物件（石柱、石牆）：Rect2
var wind_t := 8.0           # 馬爾他的暴風：倒數到下一陣風
var wind_on := 0.0          # 這一陣風還剩幾秒
var wind_dir := Vector2.RIGHT
var chunk_timer := 0.0
var joy := {"on": false, "index": -1, "origin": Vector2.ZERO, "pos": Vector2.ZERO}

var world: Node2D
var ground: Sprite2D
var ground_fx: Node2D
var air: Node2D
var cam: Camera2D
var ui: GameUI

# 自動測試用（godot -- --smoke）
var smoke := false
var smoke_shot := ""
var smoke_frames := 0
var smoke_preset := ""
var smoke_over := 0
var smoke_nofever := false


func _ready() -> void:
	D = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	var stages: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/stages.json")).stages
	stage_i = clampi(int(Save.run_config.get("stage", 0)), 0, stages.size() - 1)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			stage_i = clampi(int(a.substr(8)), 0, stages.size() - 1)
	stage = stages[stage_i]
	for k in stage.weights:
		D.enemies[k].weight = stage.weights[k]
	D.boss.merge(stage.boss, true)
	# 熬煉（難度條件）
	trials = Save.run_config.get("trials", [])
	endless = bool(Save.run_config.get("endless", false)) or OS.get_cmdline_user_args().has("--endless")
	if endless:
		D.waves.max_enemies = int(D.endless.max_enemies)
		endless_boss_t = float(D.boss.at)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--trials="):
			trials = a.substr(9).split(",")
			Save.run_config.trials = trials
	if trials.has("swift"):
		for pt in D.waves.scaling.speed:
			pt[1] *= 1.2
	if trials.has("hard"):
		stage.hp_mult = float(stage.hp_mult) * 1.4
	if trials.has("sharp"):
		stage.dmg_mult = float(stage.dmg_mult) * 1.4
	if trials.has("many"):
		for pt in D.waves.curve:
			pt[1] *= 1.3
			pt[2] /= 1.3
		D.waves.max_enemies = int(D.waves.max_enemies * 1.3)
	if trials.has("lion"):
		D.boss.hp = float(D.boss.hp) * 1.5
		D.boss.warn = float(D.boss.warn) * 0.75
	# 主角：選了誰，就用他的名字、招式、流派與血量速度；他這一局不再當同伴
	leader = "paul" if OS.get_cmdline_user_args().has("--smoke") else str(Save.data.get("leader", "paul"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--leader="):
			leader = a.substr(9)
	if leader != "paul" and not Save.is_unlocked("leader_" + leader) and not OS.get_cmdline_user_args().has("--smoke"):
		leader = "paul"
	for L in D.leaders:
		if L.key == leader:
			D.paul.hp = L.hp
			D.paul.speed = L.speed
	if leader != "paul":
		for d in D.companions:
			if d.key == leader:
				D.paul.name = d.name
				D.paul.skill = d.skill
				D.paul.tag = d.tag
				D.paul.color = d.get("color", "#ffd75e")
		D.companions = D.companions.filter(func(d): return d.key != leader)
	# 永久恩典（用餅兌換的）
	D.paul.hp = float(D.paul.hp) + Save.up_value("vigor")
	D.paul.speed = float(D.paul.speed) * (1.0 + Save.up_value("run"))
	D.gems.magnet_radius = float(D.gems.magnet_radius) * (1.0 + Save.up_value("reap") + Save.building_bonus("magnet"))
	D.armor_slots = int(D.armor_slots) + int(Save.building_bonus("armor"))
	# 恩賜樹的全隊效果
	D.paul.speed = float(D.paul.speed) * (1.0 + Save.gift_global("move"))
	D.companion_rules.down_seconds = float(D.companion_rules.down_seconds) * maxf(0.3, 1.0 - Save.gift_global("revive"))
	D.companion_rules.down_seconds = float(D.companion_rules.down_seconds) * (1.0 - Save.up_value("rise"))
	for a in OS.get_cmdline_user_args():
		if a == "--smoke":
			smoke = true
		elif a.begins_with("--shot="):
			smoke_shot = a.substr(7)
		elif a.begins_with("--t0="):
			t = float(a.substr(5))
		elif a == "--light":
			force_light = true
		elif a.begins_with("--frames="):
			smoke_max_frames = int(a.substr(9))   # 測試用：跑更久（整局約 25000 格）
		elif a == "--nofever":
			smoke_nofever = true
		elif a.begins_with("--preset="):
			smoke_preset = a.substr(9)
	for k in D.enemies:
		scatter_by[k] = 0
	xp_need = int(D.leveling.first)
	t_start = t
	meter = Save.building_bonus("meter")   # 營地的祭壇：開局就有一些同心合意
	_build_world()
	_build_ui()
	var starter: String = Save.run_config.get("starter", Save.data.starter)
	if not by_key.has(starter) or not Save.is_unlocked(starter) or starter == leader:
		starter = Save.meta.default_starter
	if starter == leader:
		starter = "tim" if leader != "tim" else "luke"
	first_recruit = starter
	rerolls_left = Save.rerolls()
	var pool: Array = D.tasks.list.duplicate()
	pool.shuffle()
	for i in mini(int(D.tasks.count), pool.size()):
		run_tasks.append({"def": pool[i], "done": false, "failed": false})
	if smoke_preset == "ot":
		# 測試用：五位舊約人物滿級
		for k in ["david", "samson", "moses", "elijah", "joshua"]:
			_recruit(by_key[k])
			_set_level(by_key[k], 5)
	if smoke_preset == "links":
		# 測試用：提摩太出手→以利亞出手→大衛出手；西拉驅散→提摩太出手
		for k in ["tim", "elijah", "david"]:
			_recruit(by_key[k])
		for c in comps:
			if c.level > 0:
				_set_level(c, 4)
		links = [{"src": by_key.tim, "dst": by_key.elijah, "kind": "cast", "cd": 0.0},
			{"src": by_key.elijah, "dst": by_key.david, "kind": "cast", "cd": 0.0},
			{"src": by_key.silas, "dst": by_key.tim, "kind": "kill", "cd": 0.0}]
		_refresh_build_text()
	if smoke_preset == "five":
		# 測試用：接近實際的中後期隊伍（5 人 Lv4、兩種果子 Lv2）
		for k in ["tim", "luke", "apollos", "david"]:
			_recruit(by_key[k])
		for c in comps:
			if c.level > 0:
				_set_level(c, 4)
		fruits = {"joy": 2, "faith": 2}
	if smoke_preset.begins_with("team:") or smoke_preset.begins_with("teamevo:"):
		# 測試用：--preset=team:a,b,c（Lv4）或 teamevo:a,b,c（滿級並進化）
		var evo_on := smoke_preset.begins_with("teamevo:")
		for k in smoke_preset.get_slice(":", 1).split(","):
			_recruit(by_key[k])
			_set_level(by_key[k], 5 if evo_on else 4)
		if evo_on:
			fruits = {"joy": 1, "faith": 1, "good": 1, "peace": 1}
			for evo in _ready_evolutions():
				_evolve(evo)
	if smoke_preset == "sets":
		# 測試用：套裝＋新觸發條件＋流派專屬效果
		for k in ["silas", "tim", "luke", "barn"]:
			_recruit(by_key[k])
			_set_level(by_key[k], 3)
		armor = {"sword": 1, "shield": 1, "belt": 1, "breast": 1}
		_update_sets()
		links.append({"src": by_key.tim, "dst": by_key.silas, "kind": "reso", "cd": 0.0, "lv": 1})
		links.append({"src": by_key.tim, "dst": by_key.barn, "kind": "cast", "cd": 0.0, "lv": 1})
		links.append({"src": by_key.tim, "dst": by_key.luke, "kind": "kill", "cd": 0.0, "lv": 1})
		links.append({"src": by_key.silas, "dst": by_key.tim, "kind": "elite", "cd": 0.0, "lv": 1})
		print("sets=", sets_on, " bonus=", set_bonus, " hp=", D.paul.hp)
	if smoke_preset == "evo":
		# 測試用：五位滿級並全部進化
		for k in ["tim", "luke", "samson", "elijah"]:
			_recruit(by_key[k])
		for c in comps:
			if c.level > 0:
				_set_level(c, 5)
		_set_level(pa, 5)
		fruits = {"joy": 1, "faith": 1, "good": 1}
		for evo in _ready_evolutions():
			_evolve(evo)
	if smoke_preset == "disciples":
		# 測試用：五位門徒 Lv4
		for k in ["peter", "john", "thomas", "matthew", "andrew"]:
			_recruit(by_key[k])
			_set_level(by_key[k], 4)
	if smoke_preset == "branch":
		# 測試用：提摩太 Lv2→3 走分支「四散」
		_recruit(by_key.tim)
		_set_level(by_key.tim, 2)
		choosing = true
		pending_cards = [{"kind": "up", "key": "tim", "title": "", "tag": "", "desc": ""}]
		_on_card(0)
		print("branch cards: ", pending_cards.map(func(c): return c.title))
		ui.card_ready_at = 0.0
		_on_card(1)
		print("tim lv=%d branch=%d split=%s" % [by_key.tim.level, by_key.tim.branch, by_key.tim.st.split])
		_set_level(by_key.tim, 5)
		print("tim lv5 split=%s count=%s" % [by_key.tim.st.split, by_key.tim.st.count])
	if smoke_preset == "strong":
		# 測試用：滿編隊伍，西拉滿級帶喜樂，下一個寶箱會進化
		for c in comps:
			if c.level == 0 and c.follows == "":
				_recruit(c)
		for c in comps:
			if c.skill != "":
				_set_level(c, 5 if c.key == "silas" else 4)
		fruits = {"joy": 2, "faith": 2, "good": 1, "peace": 1}
		armor = {"shoes": 1, "shield": 2}
		chests.append({"pos": Vector2(0, 6)})
	for i in int(D.waves.initial):
		var a := randf() * TAU
		var d := 110.0 + randf() * 80.0
		_spawn_one(_pick_type(), Vector2(cos(a) * d, sin(a) * d * 0.7))
	_update_chunks()
	Sfx.music(stage.music)
	ground.modulate = Color(stage.tint[0], stage.tint[1], stage.tint[2])
	ui.show_banner("%s　%s%s" % [stage.name, stage.ref, ("\n熬煉 %d 點" % Save.trial_points(trials)) if not trials.is_empty() else ""], 2.5)


# ---------- 建立場景 ----------
func _tex(key: String) -> Texture2D:
	if not tex.has(key):
		tex[key] = load("res://assets/sprites/%s.png" % key)
	return tex[key]


func _sprite(key: String, offset: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(key)
	s.centered = false
	s.offset = offset
	world.add_child(s)
	return s


func _build_world() -> void:
	ground = Sprite2D.new()
	ground.texture = _tex(stage.get("ground", "ground"))
	ground.centered = false
	ground.region_enabled = true
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.z_index = -2
	add_child(ground)

	ground_fx = Node2D.new()
	ground_fx.z_index = -1
	ground_fx.draw.connect(_draw_ground_fx)
	add_child(ground_fx)

	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	air = Node2D.new()
	air.z_index = 10
	air.draw.connect(_draw_air)
	add_child(air)

	cam = Camera2D.new()
	var vs := get_viewport().get_visible_rect().size
	cam.zoom = Vector2.ONE * (ZOOM_PORTRAIT if vs.y > vs.x else ZOOM)
	add_child(cam)
	cam.make_current()

	paul = {"name": D.paul.name, "pos": Vector2.ZERO, "hp": float(D.paul.hp), "inv": 0.0, "moving": false,
		"node": _sprite(leader + "_0", Vector2(-7, -17))}
	pa = {"key": leader, "name": D.paul.name, "skill": D.paul.skill, "tag": D.paul.tag, "i": 99, "pos": Vector2.ZERO,
		"level": 1, "st": _stats(D.paul.skill, 1), "engine": D.skills[D.paul.skill].get("engine", D.paul.skill), "look": D.skills[D.paul.skill].get("look", ""),
		"cd": 0.5, "castfx": 0.0, "col": Color(D.paul.get("color", "#ffd75e")), "down": 0.0, "sleep": 0.0, "off": Vector2.ZERO, "follows": "", "with": "", "aff": 1.0, "syn": 1.0}
	by_key[leader] = pa
	var i := 0
	for d in D.companions:
		var home := Vector2.ZERO
		var c := {"key": d.key, "name": d.name, "skill": d.skill, "tag": d.tag, "i": i, "home": home,
			"base": home, "pos": home, "off": Vector2.ZERO, "vel": Vector2.ZERO, "level": 0, "st": {},
			"cd": 0.3 + i * 0.2, "sleep": 0.0, "alert": 0.0,
			"hp": float(D.companion_rules.hp), "down": 0.0, "hurt_cd": 0.0,
			"with": d.get("with", ""), "follows": d.get("follows", ""),
			"engine": D.skills[d.skill].get("engine", d.skill) if d.skill != "" else "",
			"look": D.skills[d.skill].get("look", "") if d.skill != "" else "",
			"syn": 1.0, "castfx": 0.0, "col": Color(d.get("color", "#ffd75e")),
			"aff": (1.0 + Save.affinity_level(d.key) * float(Save.meta.affinity.bonus_per_level)) * (1.0 + Save.up_value("haste")),
			"node": _sprite(d.key + "_0", Vector2(-7, -17))}
		c.node.visible = false
		comps.append(c)
		by_key[d.key] = c
		i += 1
	for c in comps + [pa]:
		_apply_gifts(c)


## 恩賜樹：依流派加上傷害、攻速、範圍、專屬連結強度與終極恩賜
func _apply_gifts(c: Dictionary) -> void:
	var per := {}
	var stats := []
	if Save.meta.gifts.trees.has(c.tag):
		for nd in Save.gift_nodes(c.tag):
			var r := Save.gift_rank(c.tag, nd.id)
			if r <= 0:
				continue
			if nd.kind == "stat":
				stats.append({"stat": nd.stat, "add": float(nd.get("add", 0.0)) * r, "mul": float(nd.get("mul", 0.0)) * r})
			elif nd.kind == "healmul":
				for k in ["amount", "heal", "heal_comp"]:
					stats.append({"stat": k, "add": 0.0, "mul": float(nd.per) * r})
			else:
				per[nd.kind] = float(per.get(nd.kind, 0.0)) + r * float(nd.per)
	c.tdmg = 1.0 + per.get("dmg", 0.0)
	c.aff = float(c.aff) * (1.0 + per.get("speed", 0.0))
	c.tarea = 1.0 + per.get("area", 0.0)
	c.tlink = 1.0 + per.get("link", 0.0)
	c.telite = 1.0 + per.get("elite", 0.0)
	c.tstart = per.get("start", 0.0) > 0.0
	c.tlinkcd = 1.0 - per.get("linkcd", 0.0)
	c.tult = per.get("ult", 0.0) > 0.0
	c.tcrit = per.get("crit", 0.0)
	c.texpose = per.get("expose", 0.0)
	c.tmeter = per.get("meter", 0.0)
	c.tdr = per.get("dr", 0.0)
	c.tthorns = per.get("thorns", 0.0)
	c.tleech = per.get("leech", 0.0)
	c.tloot = per.get("loot", 0.0)
	c.tcombo = per.get("combo", 0.0)
	c.tstats = stats


func _build_ui() -> void:
	ui = GameUI.new()
	add_child(ui)
	var names := [D.paul.name]
	for c in comps:
		names.append(c.name)
	ui.setup(names, DisplayServer.is_touchscreen_available())
	for c in comps:
		if c.with != "":
			ui.names[c.name].text = c.name + "・" + by_key[c.with].name
	ui.card_chosen.connect(_on_card)
	ui.chest_closed.connect(_on_chest_closed)
	ui.fever_pressed.connect(_start_fever)
	ui.restart_pressed.connect(func(): _leave("res://scenes/main.tscn"))
	ui.home_pressed.connect(func(): _leave("res://scenes/base.tscn"))
	ui.pause_pressed.connect(_set_paused.bind(true))
	ui.resume_pressed.connect(_set_paused.bind(false))
	get_tree().set_quit_on_go_back(false)
	ui.reroll_pressed.connect(_reroll)


# ---------- 同伴等級 ----------
func _stats(skill: String, lv: int) -> Dictionary:
	var s: Dictionary = D.skills[skill]
	var out: Dictionary = s.base.duplicate()
	for i in range(mini(lv - 1, s.levels.size())):
		out.merge(s.levels[i], true)
	return out


func _set_level(c: Dictionary, lv: int) -> void:
	c.level = lv
	if c.skill != "":
		c.st = _stats(c.skill, lv)
		# Lv3 二選一的分支：加在數值上，之後升級也保留
		var bi: int = c.get("branch", -1)
		if bi >= 0:
			for k in D.skills[c.skill].branches[bi].add:
				c.st[k] = float(c.st.get(k, 0)) + float(D.skills[c.skill].branches[bi].add[k])
			c.st.cooldown = maxf(0.2, float(c.st.get("cooldown", 1.0)))
		if evolved.has(c.key) and evolved[c.key].has("stats"):
			c.st.merge(evolved[c.key].stats, true)
		# 恩賜樹「範圍」：放大範圍與射程
		for k in ["radius", "max_radius", "length", "range", "jump_range"]:
			if c.st.has(k):
				c.st[k] = float(c.st[k]) * float(c.get("tarea", 1.0))
		# 恩賜樹的「改招式數值」節點（只改這個招式本來就有的數值）
		for sm in c.get("tstats", []):
			if c.st.has(sm.stat):
				c.st[sm.stat] = float(c.st[sm.stat]) * (1.0 + float(sm.mul)) + float(sm.add)
	if not comps.is_empty() and not pa.is_empty():
		_update_synergy()


func _recruit(c: Dictionary) -> void:
	if c.follows == "":
		c.home = SLOTS[_party_count() % SLOTS.size()]
	else:
		c.home = by_key[c.follows].home + Vector2(14, 0)
	_set_level(c, 2 if c.get("tstart", false) else 1)   # 恩賜樹「直接 Lv2」
	c.base = paul.pos + c.home + Vector2(randf_range(-30, 30), 40)
	c.pos = c.base
	c.node.visible = true
	if c.with != "":
		_recruit(by_key[c.with])
	if _party_count() >= Save.party_cap():
		full_party = true
	_update_synergy()


## 同工：同一流派的同伴有 2 位以上，他們攻擊加快
func _tag_counts() -> Dictionary:
	var cnt := {}
	for c in comps:
		if c.level > 0 and c.follows == "" and c.engine != "":
			cnt[c.tag] = cnt.get(c.tag, 0) + 1
	return cnt


func _update_synergy() -> void:
	var cnt := _tag_counts()
	var bonus: Dictionary = D.synergy.bonus
	# 技能協同：同流派的其他同伴每 1 級，傷害 +per_level_damage
	var lv_sum := {}
	for o in comps + [pa]:
		if o.level > 0 and o.follows == "":
			lv_sum[o.tag] = lv_sum.get(o.tag, 0) + int(o.level)
	for o in comps + [pa]:
		var others: int = lv_sum.get(o.tag, 0) - (int(o.level) if o.level > 0 else 0)
		o.synd = 1.0 + others * float(D.synergy.get("per_level_damage", 0.0))
	for c in comps:
		var n: int = mini(cnt.get(c.tag, 0), 3)
		var before: float = c.syn
		c.syn = 1.0 + float(bonus.get(str(n), 0.0))
		if c.level > 0 and c.syn > before and ui != null:
			ui.show_banner("同工：%s ×%d　攻擊加快" % [c.tag, n], 1.6)

## 隊伍人數（百基拉・亞居拉算一位）
func _party_count() -> int:
	var n := 0
	for c in comps:
		if c.level > 0 and c.follows == "":
			n += 1
	return n


## 果子與軍裝帶來的倍率
func _area() -> float:
	return 1.0 + fruits.get("joy", 0) * D.fruits.joy.per_level.area

func _dmg_mult() -> float:
	return (1.0 + fruits.get("faith", 0) * D.fruits.faith.per_level.damage) * (1.0 + Save.up_value("might")) * (1.0 + float(set_bonus.get("damage", 0.0)) + grace_dmg)

func _guard() -> float:
	return 1.0 + fruits.get("good", 0) * D.fruits.good.per_level.guard

func _accord() -> float:
	return (1.0 + fruits.get("peace", 0) * D.fruits.peace.per_level.accord) * (1.3 if epistles.has("accord_plus") else 1.0) * (1.0 + Save.up_value("accord"))


func _fever_dur() -> float:
	return float(D.fever.duration) + (3.0 if epistles.has("fever_plus") else 0.0)

func _scatter_mult() -> float:
	return maxf(0.3, 1.0 - fruits.get("peace", 0) * 0.1)

func _comp_max_hp() -> float:
	return D.companion_rules.hp * (1.0 + fruits.get("good", 0) * 0.1)

func _speed() -> float:
	return D.paul.speed * (1.0 + armor.get("shoes", 0) * 0.12)


func _make_cards() -> Array:
	var pool := []
	for k in D.fruits:
		var f: Dictionary = D.fruits[k]
		var lv: int = fruits.get(k, 0)
		if lv == 0 and not Save.is_unlocked("fruit_" + k):
			continue
		var fdesc: String = f.desc
		if lv == 0:
			for evo in D.evolutions:
				if evo.fruit == k and by_key.has(evo.companion) and by_key[evo.companion].level > 0:
					fdesc += "\n可讓%s進化（滿級時）" % by_key[evo.companion].name
					break
		if lv == 0 and fruits.size() < 6:
			pool.append({"kind": "fruit", "key": k, "title": f.name + "　新果子", "tag": f.tag, "desc": fdesc})
		elif lv > 0 and lv < 5:
			pool.append({"kind": "fruit", "key": k, "title": "%s　Lv%d → %d" % [f.name, lv, lv + 1], "tag": f.tag, "desc": f.desc})
	for k in D.armor:
		var a: Dictionary = D.armor[k]
		var lv: int = armor.get(k, 0)
		if lv == 0 and not Save.is_unlocked("armor_" + k):
			continue
		if lv == 0 and armor.size() < int(D.armor_slots) + (1 if epistles.has("armor_plus") else 0):
			var adesc: String = a.desc[0]
			for st in D.armor_sets:
				if st.pieces.has(k) and not sets_on.has(st.id):
					var need: Array = st.pieces.filter(func(pc): return pc != k and armor.get(pc, 0) == 0)
					if need.is_empty():
						adesc += "\n湊齊套裝「%s」：%s" % [st.name, st.desc]
					elif need.size() == 1:
						adesc += "\n再加%s湊成「%s」" % [D.armor[need[0]].name, st.name]
			pool.append({"kind": "armor", "key": k, "title": a.name + "　穿上", "tag": a.tag, "desc": adesc})
		elif lv > 0 and lv < 3:
			pool.append({"kind": "armor", "key": k, "title": "%s　Lv%d → %d" % [a.name, lv, lv + 1], "tag": a.tag, "desc": a.desc[lv]})
	if pa.level < 5:
		var pd: String = D.skills[pa.skill].desc[pa.level]
		if pa.level == 4:
			var pe := _evo_of(pa.key)
			pd += "\n滿級＋果子「%s」→ 進化「%s」" % [D.fruits[pe.fruit].name, pe.name]
		pool.append({"kind": "up", "key": pa.key, "title": "%s%s　Lv%d → %d" % [pa.name, "的書信" if pa.key == "paul" else "（主角）", pa.level, pa.level + 1], "tag": pa.tag, "desc": pd})
	for c in comps:
		if c.follows != "" or c.skill == "":
			continue
		var desc: Array = D.skills[c.skill].desc
		if c.level == 0 and (not Save.is_unlocked(c.key) or _party_count() >= Save.party_cap()):
			continue
		if c.level == 0:
			var nm: String = c.name + ("・" + by_key[c.with].name if c.with != "" else "")
			pool.append({"kind": "recruit", "key": c.key, "title": nm + "　加入", "tag": c.tag, "desc": desc[0]})
		elif c.level < 5:
			var d2: String = desc[c.level]
			var evo := _evo_of(c.key)
			if c.level == 4 and not evo.is_empty():
				var fname: String = D.fruits[evo.fruit].name
				d2 += "\n滿級＋果子「%s」→ 進化「%s」" % [fname, evo.name]
				if not Save.is_unlocked("fruit_" + evo.fruit):
					d2 += "（果子要先在補給帳棚解鎖）"
			pool.append({"kind": "up", "key": c.key, "title": "%s　Lv%d → %d" % [c.name, c.level, c.level + 1], "tag": c.tag, "desc": d2})
	for st in _stage_list():
		var ep: Dictionary = st.epistle
		if Save.data.churches.has(st.id) and not epistles.has(ep.effect):
			pool.append({"kind": "epistle", "key": ep.effect, "title": ep.name, "tag": "書信", "desc": ep.desc})
	var lc := _link_card()
	if not lc.is_empty():
		pool.append(lc)
	pool.shuffle()
	# 第一位同工：還沒加入前，招募卡一定排第一張
	if first_recruit != "" and by_key.has(first_recruit) and by_key[first_recruit].level == 0:
		var fc: Dictionary = by_key[first_recruit]
		pool = pool.filter(func(cd): return not (cd.kind == "recruit" and cd.key == first_recruit))
		var nm2: String = fc.name + ("・" + by_key[fc.with].name if fc.with != "" else "")
		pool.push_front({"kind": "recruit", "key": fc.key, "title": nm2 + "　加入", "tag": fc.tag, "desc": D.skills[fc.skill].desc[0]})
	# 符合進化條件時，進化卡一定排第一張
	for evo in _ready_evolutions():
		var c: Dictionary = by_key[evo.companion]
		pool.push_front({"kind": "evolve", "key": c.key, "title": "進化！" + evo.name, "tag": c.tag, "desc": c.name + "：" + evo.desc})
		break
	var cards := pool.slice(0, 3)
	var fill := _filler_cards()
	while cards.size() < 3 and not fill.is_empty():
		cards.append(fill.pop_front())
	return cards


## 沒有足夠的卡時的小獎勵（恩上加恩、如鷹展翅、嗎哪；血少時才有五餅二魚）
func _filler_cards() -> Array:
	var out := []
	for f in D.fillers:
		if f.kind == "heal" and paul.hp > float(D.paul.hp) * float(f.hp_below):
			continue
		out.append({"kind": f.kind, "key": "", "title": f.title, "tag": f.tag, "desc": f.desc, "amount": f.get("amount", 0)})
	out.shuffle()
	return out


func _level_up() -> void:
	level += 1
	xp -= xp_need
	var L: Dictionary = D.leveling
	xp_need = int(L.first + (level - 1) * L.step + pow(level - 1, 2) * L.growth)
	choosing = true
	joy.on = false
	ui.joy.on = false
	pending_cards = _make_cards()
	_tip("cards")
	if pending_cards.any(func(cd): return cd.kind == "link"):
		_tip("link")
	Sfx.play("levelup", 0.0)
	ui.do_flash(0.5)
	_ring_pop(paul.pos + Vector2(0, -6), C_GOLD, 60.0)
	ui.show_cards(pending_cards, Time.get_ticks_msec() / 1000.0, _card_delay(), rerolls_left)


func _card_delay() -> float:
	return float(D.leveling.touch_card_delay if DisplayServer.is_touchscreen_available() else D.leveling.card_delay)


func _reroll() -> void:
	if not choosing or rerolls_left <= 0:
		return
	rerolls_left -= 1
	pending_cards = _make_cards()
	ui.show_cards(pending_cards, Time.get_ticks_msec() / 1000.0, 0.15, rerolls_left)


func _apply_card(card: Dictionary) -> void:
	if card.kind == "recruit":
		_recruit(by_key[card.key])
	elif card.kind == "up":
		var c: Dictionary = by_key[card.key]
		_set_level(c, c.level + 1)
		_ring_pop(c.pos + Vector2(0, -6), C_GOLD, 30.0)
	elif card.kind == "fruit":
		fruits[card.key] = fruits.get(card.key, 0) + 1
	elif card.kind == "armor":
		armor[card.key] = armor.get(card.key, 0) + 1
		_update_sets()
	elif card.kind == "branch":
		var c: Dictionary = by_key[card.key]
		c.branch = int(card.idx)
		_set_level(c, 3)
		_ring_pop(c.pos + Vector2(0, -6), C_GOLD, 30.0)
	elif card.kind == "epistle":
		epistles[card.key] = true
		if card.key == "hp_plus":
			D.paul.hp = float(D.paul.hp) + 30.0
			paul.hp += 30.0
	elif card.kind == "evolve":
		_evolve(_evo_of(card.key))
	elif card.kind == "link_up":
		var L: Dictionary = links[int(card.key)]
		L.lv = int(L.get("lv", 1)) + 1
		_ring_pop(L.dst.pos + Vector2(0, -8), C_GOLD, 30.0)
	elif card.kind == "link":
		links.append({"src": by_key[card.src], "dst": by_key[card.dst], "kind": card.key, "cd": 0.0, "lv": 1})
		ui.show_banner("肢體連結！", 1.2)
	elif card.kind == "grace_dmg":
		grace_dmg += float(card.amount)
	elif card.kind == "grace_spd":
		grace_spd += float(card.amount)
	elif card.kind == "manna":
		run_bread += int(card.amount)
	else:
		paul.hp = minf(D.paul.hp, paul.hp + D.leveling.heal_card)


func _task_value(stat: String) -> int:
	match stat:
		"kills": return kills
		"elites": return run_elites
		"fevers": return run_fevers
		"links": return link_count
		"level": return level
		"combo": return combo_best
		"resonance": return run_resonances
		"chests": return run_chests
		"bread": return run_bread
		"midboss": return run_midboss
		"party": return _party_count()
	return 0


func _update_tasks() -> void:
	for rt in run_tasks:
		if rt.done or rt.failed:
			continue
		var d: Dictionary = rt.def
		if _task_value(d.stat) >= int(d.goal):
			rt.done = true
			tasks_done += 1
			task_witness += int(d.witness)
			chests.append({"pos": paul.pos + Vector2(randf_range(-24, 24), -26)})
			ui.show_banner("任務完成：%s　見證 +%d" % [d.name, int(d.witness)], 2.0)
		elif int(d.by) > 0 and t - t_start > float(d.by):
			rt.failed = true


func _task_text() -> String:
	var lines := []
	for rt in run_tasks:
		var d: Dictionary = rt.def
		var mark := "✓" if rt.done else ("×" if rt.failed else "・")
		var limit := ""
		if int(d.by) > 0 and not rt.done:
			limit = "（%d:%02d 前）" % [int(d.by) / 60, int(d.by) % 60]
		var prog := "" if rt.done else "　%d/%d" % [mini(_task_value(d.stat), int(d.goal)), int(d.goal)]
		lines.append("%s %s%s%s" % [mark, d.name, prog, limit])
	return "\n".join(lines)


func _refresh_build_text() -> void:
	var lines := []
	var cnt := _tag_counts()
	for tag in cnt:
		if cnt[tag] >= 2:
			lines.append("同工　%s ×%d" % [tag, cnt[tag]])
	var brs := []
	for c in [pa] + comps:
		if c.get("branch", -1) >= 0:
			brs.append("%s・%s" % [c.name, D.skills[c.skill].branches[c.branch].name])
	if not brs.is_empty():
		lines.append("分支　" + "、".join(brs))
	for L in links:
		var K: Dictionary = D.links.kinds[L.kind]
		var lvs := "" if int(L.get("lv", 1)) == 1 else " Lv%d" % int(L.lv)
		lines.append("連結　%s%s" % [(K.short + "→" + L.dst.name) if _glob(L.kind) else (L.src.name + "→" + L.dst.name + "（" + K.short + "）"), lvs])
	build_text = "\n".join(lines)


func _on_card(i: int) -> void:
	Sfx.play("pick", 0.0)
	var card: Dictionary = pending_cards[i]
	# 升到 Lv3：先選分支（第二張選單）
	if card.kind == "up" and by_key.has(card.key):
		var c: Dictionary = by_key[card.key]
		if c.level == 2 and c.get("branch", -1) < 0 and D.skills[c.skill].has("branches"):
			var who: String = c.name
			pending_cards = []
			for bi in D.skills[c.skill].branches.size():
				var br: Dictionary = D.skills[c.skill].branches[bi]
				pending_cards.append({"kind": "branch", "key": c.key, "idx": bi, "title": "%s：%s" % [who, br.name], "tag": "Lv3 分支", "desc": br.desc + "\n（之後的升級都會保留）"})
			ui.show_cards(pending_cards, Time.get_ticks_msec() / 1000.0, 0.3, 0)
			return
	_apply_card(card)
	_refresh_build_text()
	choosing = false
	if xp >= xp_need:
		_level_up()


# ---------- 輸入 ----------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if over and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			# 通關：回營地；失敗：再出發
			_leave("res://scenes/base.tscn" if won else "res://scenes/main.tscn")
			return
		if not over and (event.keycode == KEY_ESCAPE or event.keycode == KEY_P):
			_set_paused(not paused)
			return
		if paused:
			return
		if choosing and event.keycode == KEY_R:
			_reroll()
			return
		if choosing and event.keycode >= KEY_1 and event.keycode <= KEY_3:
			ui.pick(event.keycode - KEY_1)
			return
		if not over and not choosing and event.keycode == KEY_SPACE:
			_start_fever()
			return
	if over or choosing or paused:
		return
	var h := get_viewport().get_visible_rect().size.y
	if event is InputEventScreenTouch:
		if event.pressed and event.position.y > h * 0.3 and not joy.on:
			joy = {"on": true, "index": event.index, "origin": event.position, "pos": event.position}
		elif not event.pressed and event.index == joy.index:
			joy.on = false
	elif event is InputEventScreenDrag and joy.on and event.index == joy.index:
		joy.pos = event.position
	ui.joy = {"on": joy.on, "origin": joy.origin, "pos": joy.pos}


func _move_vector() -> Vector2:
	var v := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if v != Vector2.ZERO:
		return v.normalized()
	if joy.on:
		var d: Vector2 = joy.pos - joy.origin
		if d.length() > 4.0:
			return d.normalized() * minf(1.0, d.length() / 36.0)
	if smoke:
		return Vector2.from_angle(t * 0.6) * 0.8
	return Vector2.ZERO


# ---------- 敵人 ----------
func _pick_type() -> String:
	var total := 0.0
	for k in D.enemies:
		if not k.begins_with("_") and t >= D.enemies[k].from:
			total += D.enemies[k].weight
	var r := randf() * total
	for k in D.enemies:
		if not k.begins_with("_") and t >= D.enemies[k].from and D.enemies[k].weight > 0:
			r -= D.enemies[k].weight
			if r <= 0.0:
				return k
	return "fear"


func _view_rect() -> Rect2:
	var size := get_viewport().get_visible_rect().size / cam.zoom.x
	return Rect2(cam.position - size / 2.0, size)


func _edge_point(margin: float) -> Vector2:
	var v := _view_rect().grow(margin)
	match randi() % 4:
		0: return Vector2(v.position.x, v.position.y + randf() * v.size.y)
		1: return Vector2(v.end.x, v.position.y + randf() * v.size.y)
		2: return Vector2(v.position.x + randf() * v.size.x, v.position.y)
		_: return Vector2(v.position.x + randf() * v.size.x, v.end.y)


## [[x, y], ...] 折線內插
func _curve(points: Array, x: float) -> float:
	if x <= points[0][0]:
		return points[0][1]
	for i in range(points.size() - 1):
		var a: Array = points[i]
		var b: Array = points[i + 1]
		if x < b[0]:
			return lerpf(a[1], b[1], (x - a[0]) / (b[0] - a[0]))
	return points[-1][1]


## 回傳 (目標隻數, 每群間隔)
func _wave_now() -> Vector2:
	var c: Array = D.waves.curve
	if t >= c[-1][0]:
		return Vector2(c[-1][1], c[-1][2])
	for i in range(c.size() - 1):
		var a: Array = c[i]
		var b: Array = c[i + 1]
		if t >= a[0] and t < b[0]:
			var k: float = (t - a[0]) / (b[0] - a[0])
			return Vector2(lerpf(a[1], b[1], k), lerpf(a[2], b[2], k))
	return Vector2(c[0][1], c[0][2])


func _spawn_group() -> void:
	var type := _pick_type()
	var center := _edge_point(16.0)
	var n := randi_range(int(D.waves.group_min), int(D.waves.group_max))
	for i in n:
		if enemies.size() >= int(D.waves.max_enemies):
			return
		_spawn_one(type, center + Vector2(randf_range(-10, 10), randf_range(-10, 10)))


func _spawn_one(type: String, at: Vector2) -> void:
	var d: Dictionary = D.enemies[type]
	var SC: Dictionary = D.waves.scaling
	var V: Dictionary = D.waves.veteran
	var vet := randf() < _curve(V.chance, t)
	var hp: float = ceilf(d.hp * _curve(SC.hp, t) * stage.hp_mult * (float(V.hp_mult) if vet else 1.0) * _endless_mult("hp"))
	var spr: String = d.get("sprite", type)
	if d.has("looks"):
		spr = d.looks[randi() % d.looks.size()]
	var tint := Color(d.tint[0], d.tint[1], d.tint[2]) if d.has("tint") else Color.WHITE
	# 獵手：不追主角、改追同伴，顏色偏紅
	var hunter := type != "fear" and not d.has("shoot") and randf() < _curve(D.waves.hunter.chance, t)
	if hunter:
		tint *= Color(1.25, 0.75, 0.75)
	var e := {"type": type, "d": d, "pos": at, "hp": hp, "ph": randf() * TAU, "flash": 0.0, "stun": 0.0,
		"cd": 0.0, "bcd": 0.0, "shoot": (d.shoot.every * randf()) if d.has("shoot") else 0.0, "r": 6.0,
		"sprite": spr, "tint": tint * Color(0.7, 0.5, 0.6) if vet else tint, "roar": 2.0, "vet": vet, "hunter": hunter,
		"dmul": _curve(SC.damage, t) * stage.dmg_mult * _endless_mult("damage"), "smul": _curve(SC.speed, t) * _endless_mult("speed"),
		"dash_cd": randf() * 3.0, "dash_t": 0.0, "blink_cd": 2.0 + randf() * 2.0,
		"knock": Vector2.ZERO, "dead": false, "node": _sprite(spr + "_0", Vector2(-10, -13))}
	var sc: float = float(d.get("scale", 1.0)) * (float(V.scale) if vet else 1.0)
	if sc != 1.0:
		e.node.scale = Vector2.ONE * sc
		e.r *= sc
	enemies.append(e)


## 菁英與考驗型敵人：用現有敵人的圖，放大或換色
func _spawn_special(key: String, def: Dictionary, at: Vector2) -> void:
	var d := {"name": def.name, "hp": def.hp, "speed": def.speed, "damage": def.damage, "scatter": def.get("scatter", 0),
		"dies_on_touch": false}
	for k in ["roar_every", "roar_radius", "roar_force", "chest", "immune"]:
		if def.has(k):
			d[k] = def[k]
	var scale: float = def.get("scale", 1.0)
	var SC: Dictionary = D.waves.scaling
	var e := {"type": key, "d": d, "pos": at, "hp": float(def.hp) * _curve(SC.hp, t) * stage.hp_mult * _endless_mult("hp"), "ph": randf() * TAU,
		"dmul": _curve(SC.damage, t) * stage.dmg_mult, "smul": _curve(SC.speed, t),
		"flash": 0.0, "stun": 0.0, "cd": 0.0, "bcd": 0.0, "shoot": 0.0, "r": 6.0 * scale, "sprite": def.sprite,
		"tint": Color(def.tint[0], def.tint[1], def.tint[2]), "roar": 2.0, "elite": scale > 1.0,
		"knock": Vector2.ZERO, "dead": false, "node": _sprite(def.sprite + "_0", Vector2(-10, -13))}
	e.node.scale = Vector2(scale, scale)
	enemies.append(e)


func _trial_for_build() -> String:
	var best = null
	for c in comps:
		if c.level > 0 and c.skill != "" and (best == null or c.level > best.level):
			best = c
	if best == null:
		return ""
	for k in D.trials:
		if k.begins_with("_"):
			continue
		if D.trials[k].counters == best.key:
			return k
	return ""


func _hurt(e: Dictionary, dmg: float, from := Vector2.INF, src = null) -> void:
	if e.dead:
		return
	if fever > 0.0:
		dmg *= 1.5
	dmg *= _dmg_mult()
	if float(e.get("exposed_t", 0.0)) > 0.0:
		dmg *= 1.0 + float(e.expose)   # 被尼哥底母的燈照到：受到更多傷害
	if src is Dictionary:
		dmg *= float(src.get("tdmg", 1.0)) * float(src.get("synd", 1.0))
		if e.get("elite", false) or e.get("boss", false):
			dmg *= float(src.get("telite", 1.0))
		if float(src.get("tcrit", 0.0)) > 0.0 and randf() < float(src.tcrit):
			dmg *= 2.0   # 恩賜：會心一擊
		if float(src.get("texpose", 0.0)) > 0.0:
			e.exposed_t = 2.0
			e.expose = maxf(float(e.get("expose", 0.0)), float(src.texpose))
		if src == pa and armor.get("sword", 0) > 0:
			dmg *= 1.0 + float(D.armor.sword.per[armor.sword - 1])
	if e.type == "lies":
		dmg *= 1.0 + 0.5 * mini(armor.get("belt", 0), 2)
	if e.get("boss", false) and boss != null and boss.state == "break":
		dmg *= D.boss.break_mult
	e.hp -= dmg
	e.flash = 0.08
	Sfx.play("hit")
	if from != Vector2.INF:
		e.knock += (e.pos - from).normalized() * 40.0
	_dmg_number(e, dmg, src)
	if sparks.size() < 120:
		sparks.append({"pos": e.pos + Vector2(randf_range(-3, 3), randf_range(-8, -2)), "t": 0.0})
	if e.hp <= 0:
		_kill(e, true, src)


func _kill(e: Dictionary, by_player: bool, src = null) -> void:
	e.dead = true
	if by_player and src != null:
		_fire_links("kill", src, 0)
	e.node.queue_free()
	if by_player:
		killed_types["boss_" + stage.id if e.get("boss", false) else e.type] = true
		kills += 1
		Sfx.play("kill")
		gems.append({"pos": e.pos, "got": false})
		var BD: Dictionary = Save.meta.bread.drop
		var nb := 0
		if e.get("boss", false):
			nb = int(BD.boss) / (3 if e.get("mid", false) else 1)
		elif e.get("elite", false):
			nb = int(BD.elite)
		elif randf() < (float(BD.veteran) if e.get("vet", false) else float(BD.kill)):
			nb = 1
		for i in nb:
			breads.append({"pos": e.pos + Vector2(randf_range(-10, 10), randf_range(-8, 8))})
		if src is Dictionary:
			# 恩賜：驅散時累積同心合意、替主角回血、多掉經驗
			if float(src.get("tmeter", 0.0)) > 0.0 and fever <= 0.0:
				meter = minf(1.0, meter + float(src.tmeter))
			if float(src.get("tleech", 0.0)) > 0.0:
				paul.hp = minf(float(D.paul.hp), paul.hp + float(src.tleech))
			if randf() < float(src.get("tloot", 0.0)):
				gems.append({"pos": e.pos + Vector2(randf_range(-5, 5), randf_range(-4, 4)), "got": false})
			# 撒該：償還，多掉經驗；馬太：稅吏，有機會多掉餅
			for i in int(src.st.get("loot", 0)):
				gems.append({"pos": e.pos + Vector2(randf_range(-6, 6), randf_range(-5, 5)), "got": false})
			if randf() < float(src.st.get("bread_chance", 0.0)):
				breads.append({"pos": e.pos})
		if e.get("vet", false):
			for i in int(D.waves.veteran.gems) - 1:
				gems.append({"pos": e.pos + Vector2(randf_range(-6, 6), randf_range(-5, 5)), "got": false})
		if e.d.get("chest", false):
			chests.append({"pos": e.pos})
			_tip("chest")
		if e.get("elite", false):
			run_elites += 1
			_fire_links("elite", null, 0)
		if e.d.has("split_into"):
			for i in int(e.d.split_count):
				_spawn_one(e.d.split_into, e.pos + Vector2(randf_range(-8, 8), randf_range(-6, 6)))
		if e.get("boss", false) and e.get("mid", false):
			# 中途 Boss 打退了：掉寶箱，真正的 Boss 之後才來
			chests.append({"pos": e.pos})
			boss = null
			run_midboss += 1
			if endless:
				ui.show_banner("打退了！下一隻在 %d:%02d" % [int(endless_boss_t) / 60, int(endless_boss_t) % 60], 2.5)
			else:
				ui.show_banner("打退了！%s 會在 %d:%02d 捲土重來" % [D.boss.name, int(D.boss.at) / 60, int(D.boss.at) % 60], 2.5)
		elif e.get("boss", false):
			_win()
		_burst(e.pos, 6, C_GOLD if fever > 0.0 else C_VL, C_CREAM)
		_ring_pop(e.pos, C_CREAM, 9.0)
		# 被驅散的化成光點往上飄
		for i in (6 if e.get("vet", false) or e.get("elite", false) else 3):
			_mote(e.pos + Vector2(0, -4), C_GOLD)
		if fever > 0.0:
			fever_kills += 1
			if fever_kills % int(D.fever.extend_every_kills) == 0:
				fever += D.fever.extend_seconds
	else:
		_burst(e.pos, 6, C_VL, Color("3b1e52"))


func _burst(at: Vector2, n: int, c1: Color, c2: Color) -> void:
	for i in n:
		if parts.size() >= 600:
			return
		var a := randf() * TAU
		var s := 20.0 + randf() * 40.0
		parts.append({"pos": at, "vel": Vector2(cos(a) * s, sin(a) * s * 0.7 - 14.0), "life": 0.3 + randf() * 0.4, "max": 0.7, "c1": c1, "c2": c2})


func _ring_pop(at: Vector2, col: Color, size: float) -> void:
	if pops.size() < 80:
		pops.append({"pos": at, "t": 0.0, "size": size, "col": col})


func _nearest_enemies(from: Vector2, max_d: float, n: int, skip := {}) -> Array:
	var cand := []
	for e in enemies:
		if e.dead or skip.has(e.node):
			continue
		var d: float = from.distance_squared_to(e.pos)
		if d < max_d * max_d:
			cand.append([d, e])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var out := []
	for i in mini(n, cand.size()):
		out.append(cand[i][1])
	return out


func _active(c: Dictionary) -> bool:
	return c.level > 0 and c.off.length() < 10.0 and c.sleep <= 0.0 and c.down <= 0.0


func _barrier_pieces() -> Array:
	var out := []
	var pri = by_key.get("pri")
	if pri == null or not _active(pri):
		return out
	var s: Dictionary = pri.st
	var up := 1.0
	if not s.always_up:
		var cyc: float = fmod(t, s.cycle) / s.cycle
		up = 0.0
		if cyc < 0.07: up = cyc / 0.07
		elif cyc < 0.8: up = 1.0
		elif cyc < 0.87: up = 1.0 - (cyc - 0.8) / 0.07
	if up <= 0.0:
		return out
	for k in int(s.pieces):
		var a: float = t * 0.35 + k * TAU / s.pieces + 0.4
		out.append({"pos": paul.pos + Vector2(cos(a) * s.radius, 2.0 + sin(a) * s.radius * 0.8), "up": up})
	return out


# ---------- FEVER ----------
## 新手教學：第一次遇到才出現，看過就記在存檔
func _tip(id: String) -> void:
	var seen: Array = Save.data.get("tips_seen", [])
	if seen.has(id) or tip_queue.has(id) or not D.tips.has(id):
		return
	tip_queue.append(id)


func _update_tips() -> void:
	# 升級卡相關的提示要在選卡時就出現，其他的等選完再說
	if tip_queue.is_empty() or chest_open or paused:
		return
	var card_tip: bool = tip_queue[0] in ["cards", "link"]
	if (choosing and not card_tip) or (ui.tip_busy() and not (choosing and card_tip)):
		return
	var id: String = tip_queue.pop_front()
	var T: Dictionary = D.tips[id]
	var touch := DisplayServer.is_touchscreen_available()
	ui.show_tip(T.get("text_touch", T.text) if touch else T.text)
	if not Save.data.has("tips_seen"):
		Save.data.tips_seen = []
	Save.data.tips_seen.append(id)
	Save.save_profile()


func _start_fever() -> void:
	if meter < 1.0 or fever > 0.0 or over or choosing or paused:
		return
	fever = _fever_dur()
	fever_kills = 0
	run_fevers += 1
	_fire_links("fever", null, 0)
	Sfx.play("fever", 0.0)
	Sfx.music("fever")
	Sfx.buzz(90)
	var L: Dictionary = D.fever.light
	if force_light or randf() < float(L.chance):
		# 光的身影：不攻擊，只是扶起倒下的、醫好所有人，最後的爆發加倍
		light = 1.0
		light_max = 0.0
		run_lights += 1
		paul.hp = float(D.paul.hp)
		for c in comps:
			if c.level > 0:
				c.down = 0.0
				c.hp = _comp_max_hp()
				heals.append({"who": c, "t": 0.0})
		heals.append({"who": paul, "t": 0.0})
		ui.show_banner("%s\n%s" % [L.text, L.ref], 4.0)
	meter = 1.0
	ui.do_flash(0.7)
	shake = 0.2
	for c in comps:
		c.off = Vector2.ZERO
		c.vel = Vector2.ZERO
		c.sleep = 0.0


func _end_fever() -> void:
	fever = 0.0
	meter = 0.0
	Sfx.music("boss" if boss != null and not boss.dead else stage.music)
	fever_bursts.append({"pos": paul.pos, "r": 0.0, "hit": {}, "mult": float(D.fever.light.burst_mult) if light > 0.0 else 1.0})
	light = 0.0
	Sfx.play("burst", 0.0)
	ui.do_flash(0.5)
	shake = 0.25


# ---------- 主迴圈 ----------
## 離開這局：還沒結束的話（從暫停選單放棄）照失敗結算
func _leave(scene: String) -> void:
	if not over:
		over = true
		_record_run()
		_finish_run()
	get_tree().change_scene_to_file(scene)


func _set_paused(on: bool) -> void:
	if over:
		return
	paused = on
	joy.on = false
	ui.joy.on = false
	if on:
		ui.show_pause(build_text)
	else:
		ui.hide_pause()


func _notification(what: int) -> void:
	# 手機按返回鍵、切到別的 App、視窗失去焦點：自動暫停
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_set_paused(not paused)
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not smoke and not choosing and not chest_open:
			_set_paused(true)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if not over and not choosing and not chest_open and not paused:
		t += dt
		_step(dt)
	_render(dt)
	if smoke:
		_smoke_tick()


func _step(dt: float) -> void:
	var p := paul
	var mv := _move_vector()
	p.pos += mv * _speed() * dt
	p.moving = mv.length() > 0.05
	p.inv = maxf(0.0, p.inv - dt)
	shield_cd = maxf(0.0, shield_cd - dt)

	var luke = by_key.get("luke")
	var revive_mult: float = luke.st.revive_speed if luke != null and _active(luke) else 1.0
	if epistles.has("revive_plus"):
		revive_mult *= 2.0
	var barn = by_key.get("barn")
	var barn_on: bool = barn != null and _active(barn)
	var rules: Dictionary = D.companion_rules
	var party := 0
	var together := 0
	for c in comps:
		if c.level == 0:
			continue
		party += 1
		var k := minf(1.0, dt * 12.0)   # 同伴一開始就緊跟在主角身邊
		var target: Vector2 = p.pos + c.home + Vector2(sin(t * 0.7 + c.i * 1.7) * 2.0, cos(t * 0.9 + c.i * 1.3) * 1.5)
		if c.down <= 0.0:
			c.base += (target - c.base) * k
		var spring := 6.0
		if barn_on and barn.st.pull and c.pos.distance_to(barn.pos) < _aura_r(barn) * 1.4:
			spring = 30.0
		c.vel += (-spring * c.off - 4.0 * c.vel) * dt
		c.off += c.vel * dt
		if fever > 0.0:
			c.off *= 0.8
		c.pos = c.base + c.off
		c.sleep = maxf(0.0, c.sleep - dt)
		c.alert = maxf(0.0, c.alert - dt)
		c.castfx = maxf(0.0, c.castfx - dt)
		c.hurt_cd = maxf(0.0, c.hurt_cd - dt)
		if c.down > 0.0:
			c.down -= dt * revive_mult
			if c.down <= 0.0:
				c.hp = _comp_max_hp() * rules.revive_hp
		if _active(c):
			together += 1

	# 同心合意
	if fever > 0.0:
		fever -= dt
		if light > 0.0:
			light_max += dt   # 這裡拿來記已經出現多久
		meter = clampf(fever / _fever_dur(), 0.0, 1.0)
		if fever <= 0.0:
			_end_fever()
	elif party > 0:
		meter = minf(1.0, meter + dt / D.fever.fill_seconds * (float(together) / party) * _accord())

	for L in links:
		L.cd = maxf(0.0, L.cd - dt)
	_update_tasks()
	_update_tips()
	if t - t_start > 4.0:
		_tip("gem")
	if t - t_start > 25.0:
		_tip("tasks")
	if meter >= 1.0 and fever <= 0.0:
		_tip("fever")
	var bi := _boss_in()
	if bi >= 0.0 and bi < 12.0:
		_tip("boss")
	_companion_skills(dt)
	_update_projectiles(dt)
	_update_enemies(dt)
	_run_link_queue()
	for f in link_fx:
		f.t += dt
	link_fx = link_fx.filter(func(f): return f.t < 0.6)
	for f in tag_fx:
		f.t += dt
	tag_fx = tag_fx.filter(func(f): return f.t < 0.8)
	for dn in dnums:
		dn.t += dt
	dnums = dnums.filter(func(dn): return dn.t < 0.7)
	if combo > 0:
		combo_t -= dt
		if combo_t <= 0.0:
			combo = 0
			combo_tier = 0
	for rz in resonances:
		rz.r += 330.0 * dt
		for e in enemies:
			if not e.dead and not rz.hit.has(e.node) and e.pos.distance_to(rz.pos) < rz.r:
				rz.hit[e.node] = true
				_hurt(e, rz.dmg, rz.pos)
	resonances = resonances.filter(func(rz): return rz.r < 260.0)

	var ew: Dictionary = D.elite_wave
	var peak: bool = t >= ew.peak_from and t < ew.peak_to
	if t >= ew.from and boss == null:
		elite_timer -= dt
		if elite_timer <= 0.0:
			_spawn_special("terror", D.elites.terror, _edge_point(16.0))
			ui.show_banner("菁英出現：恐嚇", 2.0)
			_tip("elite")
			elite_timer = (ew.peak_every if peak else ew.elite_every) * float(stage.get("elite_mult", 1.0))
	if peak and boss == null:
		trial_timer -= dt
		if trial_timer <= 0.0:
			var tr := _trial_for_build()
			if tr != "":
				var center := _edge_point(16.0)
				for i in int(ew.trial_group):
					_spawn_special(tr, D.trials[tr], center + Vector2(randf_range(-12, 12), randf_range(-12, 12)))
			trial_timer = ew.trial_every
	var mids: Array = D.boss.get("mid", [])
	if mids_done < mids.size() and t >= float(mids[mids_done].at) and boss == null and t < float(D.boss.at) - 30.0:
		_spawn_boss(float(mids[mids_done].hp_mult))
		mids_done += 1
	if endless:
		# 無盡模式：Boss 一次比一次硬，打倒了也不會結束
		if t >= endless_boss_t and boss == null:
			_spawn_boss(1.0 + endless_bosses * float(D.endless.boss_growth), true)
			endless_bosses += 1
			endless_boss_t = t + float(D.endless.boss_every)
	elif t >= D.boss.at and not boss_spawned and (boss == null or boss.get("mid", false)):
		_spawn_boss()

	for ch in chests:
		if p.pos.distance_to(ch.pos) < 10.0 and not chest_open:
			ch.got = true
			_open_chest()
	chests = chests.filter(func(ch): return not ch.get("got", false))

	if quake_key != "":
		evo_timer -= dt
		if evo_timer <= 0.0:
			_quake()

	var wave := _wave_now()
	spawn_timer -= dt
	if spawn_timer <= 0.0 and enemies.size() < mini(int(wave.x), int(D.waves.max_enemies)):
		_spawn_group()
		spawn_timer = wave.y / _endless_mult("spawn")

	var G: Dictionary = D.gems
	for g in gems:
		var to: Vector2 = p.pos + Vector2(0, -6) - g.pos
		var d: float = to.length()
		if d < G.magnet_radius or fever > 0.0:
			g.pos += to.normalized() * (G.magnet_speed * (2.5 if fever > 0.0 else 1.0)) * dt
		if d < 4.0:
			g.got = true
			xp += 1
			xp_acc += Save.up_value("growth") + Save.building_bonus("xp") + Save.gift_global("xp") + (0.2 if epistles.has("xp_plus") else 0.0) + (float(D.armor.helmet.per[armor.helmet - 1]) if armor.get("helmet", 0) > 0 else 0.0)
			if xp_acc >= 1.0:
				xp_acc -= 1.0
				xp += 1
			Sfx.play("gem", 0.15)
	gems = gems.filter(func(g): return not g.got)
	for b in breads:
		var tb: Vector2 = p.pos + Vector2(0, -6) - b.pos
		if tb.length() < G.magnet_radius:
			b.pos += tb.normalized() * G.magnet_speed * dt
		if tb.length() < 5.0:
			b.got = true
			run_bread += 1
			Sfx.play("gem", 0.0)
	breads = breads.filter(func(b): return not b.get("got", false))
	var regen: float = Save.up_value("renew") + float(set_bonus.get("regen", 0.0)) + Save.building_bonus("regen")
	if regen > 0.0 and p.hp > 0.0:
		p.hp = minf(float(D.paul.hp), p.hp + regen * dt)
	if gems.size() > 300:
		gems = gems.slice(gems.size() - 300)

	for q in parts:
		q.pos += q.vel * dt
		if q.get("float", false):
			q.vel *= 0.97
		else:
			q.vel *= 0.92
			q.vel.y += 30.0 * dt
		q.life -= dt
	parts = parts.filter(func(q): return q.life > 0.0)
	for o in pops:
		o.t += dt
	pops = pops.filter(func(o): return o.t < 0.25)
	for sp in sparks:
		sp.t += dt
	sparks = sparks.filter(func(sp): return sp.t < 0.12)

	chunk_timer -= dt
	if chunk_timer <= 0.0:
		_update_chunks()
		chunk_timer = 0.4
	_update_wind(dt)
	_collide_solids()

	if xp >= xp_need and not over and not chest_open:
		_level_up()


func _companion_skills(dt: float) -> void:
	var barn = by_key.get("barn")
	var barn_on: bool = barn != null and _active(barn)
	var speed_mult: float = D.fever.attack_speed if fever > 0.0 else 1.0
	speed_mult *= (1.0 + float(set_bonus.get("speed", 0.0)) + grace_spd) * (1.0 + (haste_amt if haste_t > 0.0 else 0.0))
	haste_t = maxf(0.0, haste_t - dt)
	pa.ult_cd = maxf(0.0, float(pa.get("ult_cd", 0.0)) - dt)
	pa.pos = paul.pos + Vector2(0, 2)
	pa.castfx = maxf(0.0, pa.castfx - dt)
	pa.cd -= dt * speed_mult * (1.0 + Save.up_value("haste")) * float(pa.aff)
	if pa.cd <= 0.0:
		_cast(pa)
	for c in comps:
		if c.skill == "" or not _active(c):
			continue
		var s: Dictionary = c.st
		c.ult_cd = maxf(0.0, float(c.get("ult_cd", 0.0)) - dt)
		var mult: float = speed_mult * c.aff * c.syn
		if barn_on and c != barn and c.pos.distance_to(barn.pos) < _aura_r(barn):
			mult *= barn.st.attack_speed
		c.cd -= dt * mult
		if c.cd > 0.0:
			continue
		_cast(c)


## 讓同伴出一次招。triggered = 被別的招式觸發（不重設冷卻）。回傳是否真的出手。
func _cast(c: Dictionary, triggered := false, depth := 0) -> bool:
	var s: Dictionary = c.st
	var ult_now: bool = not triggered and c.get("tult", false) and float(c.get("ult_cd", 0.0)) <= 0.0
	if triggered and s.has("linked_mult"):
		# 司提反：被連結觸發時威力加倍
		s = s.duplicate()
		s.damage = float(s.damage) * float(s.linked_mult)
	if c.tag == "講道" and (triggered or ult_now) and s.has("damage"):
		# 講道的專屬連結：這一擊加重
		s = s.duplicate()
		s.damage = float(s.damage) * (1.0 + float(D.tag_links["講道"].mult) * float(c.get("tlink", 1.0)))
	var fired := true
	match c.engine:
		"bolt":
			var targets := _nearest_enemies(c.pos, s.range, int(s.count))
			fired = targets.size() > 0
			for i in (int(s.count) if fired else 0):
				var tg: Dictionary = targets[i % targets.size()]
				bolts.append({"pos": c.pos + Vector2(0, -8), "target": tg, "life": 1.5, "pierce": int(s.pierce),
					"split": int(s.split), "child": false, "dmg": float(s.damage), "size": int(s.size), "hit": {},
					"spd": float(s.speed), "emult": float(s.get("elite_mult", 1.0)), "look": c.look, "owner": c, "evo": evolved.has(c.key)})
		"ring":
			# 同一人同時最多 4 圈：連結一直觸發時不會無限疊加，拖慢遊戲
			var active := 0
			for r0 in rings:
				if r0.owner == c:
					active += 1
			var n_new := mini(int(s.rings), 4 - active)
			fired = n_new > 0
			if fired and float(s.get("heal_comp", 0.0)) > 0.0:
				# 馬利亞：晨光擴散時，扶持身邊的同伴（同伴回血）
				for o in comps:
					if o.level > 0 and o.down <= 0.0:
						o.hp = minf(_comp_max_hp(), o.hp + float(s.heal_comp))
				_ring_pop(c.pos + Vector2(0, -8), c.col, 18.0)
			for i in maxi(n_new, 0):
				rings.append({"owner": c, "r": 4.0 - i * 16.0, "dir": 1.0, "returns": int(s.returns), "hit": {},
					"max": float(s.max_radius) * _area(), "dmg": float(s.damage), "speed": float(s.speed), "stun": float(s.stun),
					"thick": int(s.thick), "knock": float(s.get("knock", 0.0)), "look": c.look, "evo": evolved.has(c.key)})
		"heal":
			paul.hp = minf(D.paul.hp, paul.hp + s.amount)
			heals.append({"who": paul, "t": 0.0})
			_ring_pop(c.pos + Vector2(0, -8), C_HEAL, 40.0)
			if evolved.has(c.key):
				_ring_pop(c.pos + Vector2(0, -8), C_GOLD, 64.0)
			Sfx.play("heal", 0.0)
			_ring_pop(paul.pos + Vector2(0, -8), C_HEAL, 14.0)
			_fire_links("heal", null, depth)
			for o in comps:
				if o.level == 0:
					continue
				if o.down > 0.0 and s.instant_revive:
					o.down = 0.0
					o.hp = _comp_max_hp() * D.companion_rules.revive_hp
				if o.down <= 0.0:
					o.hp = minf(_comp_max_hp(), o.hp + s.amount)
					heals.append({"who": o, "t": 0.0})
					_ring_pop(o.pos + Vector2(0, -8), C_HEAL, 12.0)
		"beam":
			var tg_list := _nearest_enemies(c.pos, s.range, 1)
			fired = tg_list.size() > 0
			if fired:
				var from: Vector2 = c.pos + Vector2(0, -7)
				var base_dir: Vector2 = (tg_list[0].pos - from).normalized()
				var n := int(s.beams)
				for b in n:
					var ang := (b - (n - 1) / 2.0) * deg_to_rad(28.0)
					_fire_beam(from, base_dir.rotated(ang), s, c.look, c)
		"shot":
			var tg_list := _nearest_enemies(c.pos, s.range, 1)
			fired = tg_list.size() > 0
			if fired:
				var from: Vector2 = c.pos + Vector2(0, -8)
				var base_dir: Vector2 = (tg_list[0].pos - from).normalized()
				var n := int(s.count)
				for i in n:
					var dir := base_dir.rotated(deg_to_rad((i - (n - 1) / 2.0) * float(s.spread)))
					bolts.append({"pos": from, "straight": true, "vel": dir * float(s.speed), "dir": dir, "life": float(s.range) * 1.4 / float(s.speed),
						"pierce": int(s.pierce), "dmg": float(s.damage), "size": 1, "hit": {}, "look": c.look, "owner": c,
						"split": 0, "child": true, "spd": float(s.speed), "emult": 1.0, "target": {}, "evo": evolved.has(c.key)})
		"net":
			var tl := _nearest_enemies(c.pos, s.range, 1)
			fired = tl.size() > 0
			if fired:
				var center: Vector2 = tl[0].pos
				var r: float = s.radius * _area()
				nets.append({"pos": center, "r": r, "t": 0.0, "evo": evolved.has(c.key), "look": c.look, "stun": float(s.stun), "col": c.col})
				for e in enemies:
					if not e.dead and e.pos.distance_to(center) < r:
						if not e.get("boss", false):
							e.knock += (center - e.pos) * float(s.pull) / maxf(r, 1.0) * 2.0
							e.stun = maxf(e.stun, float(s.stun))
						_hurt(e, s.damage, Vector2.INF, c)
		"chain":
			var tl := _nearest_enemies(c.pos, s.range, 1)
			fired = tl.size() > 0
			if fired:
				var hit := {}
				var from: Vector2 = c.pos + Vector2(0, -8)
				var cur: Dictionary = tl[0]
				var dmg: float = s.damage
				var pts := [from]
				for j in int(s.jumps) + 1:
					hit[cur.node] = true
					pts.append(cur.pos + Vector2(0, -4))
					_hurt(cur, dmg, Vector2.INF, c)
					dmg *= float(s.decay)
					var nx := _nearest_enemies(cur.pos, s.jump_range, 1, hit)
					if nx.is_empty():
						break
					cur = nx[0]
				zaps.append({"pts": pts, "t": 0.0, "evo": evolved.has(c.key), "col": c.col})
		"thrust":
			var tl := _nearest_enemies(c.pos, s.range + 20.0, 1)
			fired = tl.size() > 0
			if fired:
				var from: Vector2 = c.pos + Vector2(0, -6)
				var dir: Vector2 = (tl[0].pos - from).normalized()
				var crit := false
				for e in enemies:
					var rel: Vector2 = e.pos - from
					var along: float = rel.dot(dir)
					if not e.dead and along > 0.0 and along < s.range * _area() and absf(rel.cross(dir)) < s.width:
						var is_crit: bool = randf() < float(s.crit)
						crit = crit or is_crit
						_hurt(e, s.damage * (float(s.crit_mult) if is_crit else 1.0), from, c)
				thrusts.append({"from": from, "dir": dir, "len": s.range * _area(), "t": 0.0, "crit": crit, "evo": evolved.has(c.key), "look": c.look, "col": c.col})
				if c.look == "dash" and c != pa:
					# 腓利真的衝出去，再被拉回隊伍
					# 衝到前面，馬上往回跑（不會越跑越遠、回不來）
					c.off = dir * minf(s.range * _area() * 0.5, 55.0)
					c.vel = -c.off * 6.0
				if crit:
					_ring_pop(from + dir * 20.0, C_GOLD, 14.0)
		"gather":
			var r: float = s.radius * _area()
			for g in gems:
				if g.pos.distance_to(paul.pos) < r:
					g.pos = g.pos.lerp(paul.pos, 0.85)
			for b in breads:
				if b.pos.distance_to(paul.pos) < r:
					b.pos = b.pos.lerp(paul.pos, 0.85)
			for e in enemies:
				if not e.dead and e.pos.distance_to(paul.pos) < 55.0:
					_hurt(e, s.damage, paul.pos, c)
					if not e.get("boss", false):
						e.knock += (e.pos - paul.pos).normalized() * float(s.knock)
			if float(s.heal) > 0.0:
				paul.hp = minf(float(D.paul.hp), paul.hp + float(s.heal))
				heals.append({"who": paul, "t": 0.0})
				if evolved.has(c.key):
					for o in comps:
						if o.level > 0 and o.down <= 0.0:
							o.hp = minf(_comp_max_hp(), o.hp + float(s.heal))
			for i in int(s.get("bread", 0)):
				breads.append({"pos": paul.pos + Vector2(randf_range(-12, 12), randf_range(-8, 8))})
			gathers.append({"pos": paul.pos, "r": r, "t": 0.0})
		"garment":
			# 多加縫衣服：血最少的幾位同伴披上衣服，可以擋下一次傷害
			var cands := comps.filter(func(o): return o.level > 0 and o.down <= 0.0 and int(o.get("garment", 0)) < int(s.max))
			cands.sort_custom(func(a, b): return float(a.hp) < float(b.hp))
			fired = not cands.is_empty() or int(s.paul) > 0
			for i in mini(int(s.count), cands.size()):
				cands[i].garment = int(cands[i].get("garment", 0)) + 1
				_ring_pop(cands[i].pos + Vector2(0, -12), c.col, 10.0)
			if int(s.paul) > 0:
				guard = mini(guard + 1, 3)
		"nova":
			var slams := int(s.slams)
			for i in slams:
				delayed.append({"t": i * 0.25, "fn": _nova.bind(c, s)})
		"strike":
			var cand := _nearest_enemies(c.pos, s.range, 12)
			fired = cand.size() > 0
			cand.shuffle()
			for i in mini(int(s.count), cand.size()):
				fires.append({"pos": cand[i].pos, "t": float(s.delay), "max": float(s.delay), "r": float(s.radius) * _area(), "dmg": float(s.damage), "owner": c, "evo": evolved.has(c.key), "look": c.look})
		_:
			fired = false
			if not triggered:
				c.cd = 1.0
	if fired and not triggered:
		c.cd = s.cooldown
	if fired:
		c.castfx = 0.18
		if ult_now:
			c.ult_cd = float(D.tag_links.ult_cooldown)
			_tag_effect(c)
		if combo > 0 and (s.has("combo_keep") or float(c.get("tcombo", 0.0)) > 0.0):
			# 馬可、差派恩賜：出手讓連鎖多撐一下
			combo_t = minf(float(D.links.combo.window), combo_t + float(s.get("combo_keep", 0.0)) + float(c.get("tcombo", 0.0)))
		_fire_links("cast", c, depth)
	return fired


# ---------- 肢體連結（林前 12:26） ----------
## 某個條件發生時，把連到的同伴排進觸發佇列；佇列在每格結尾處理，避免在走訪陣列時改動它
func _fire_links(kind: String, src, depth: int) -> void:
	if depth >= int(D.links.max_depth):
		return
	for L in links:
		if L.kind != kind or L.cd > 0.0:
			continue
		if not _glob(kind) and L.src != src:
			continue
		L.cd = float(D.links.kinds[kind].cooldown) * float(D.links.levels.cooldown_mult[int(L.get("lv", 1)) - 1]) * float(L.dst.get("tlinkcd", 1.0))
		link_queue.append({"L": L, "depth": depth + 1})


func _run_link_queue() -> void:
	var guard := 0
	while not link_queue.is_empty() and guard < 30:
		guard += 1
		var q: Dictionary = link_queue.pop_front()
		var L: Dictionary = q.L
		if not _active(L.dst):
			continue
		var from: Vector2 = paul.pos if _glob(L.kind) else L.src.pos
		if _cast(L.dst, true, q.depth):
			_tag_effect(L.dst)
			link_count += 1
			Sfx.play("link%d" % mini(q.depth, 3), 0.02)
			link_fx.append({"a": from + Vector2(0, -8), "b": L.dst, "t": 0.0, "depth": q.depth})
			_ring_pop(L.dst.pos + Vector2(0, -8), C_GOLD, 12.0 + q.depth * 5.0)
			# 沿著連線灑一串光點
			for i in 5:
				var pt: Vector2 = from.lerp(L.dst.pos, i / 4.0) + Vector2(0, -8)
				_mote(pt, C_GOLD if q.depth < 2 else C_FLAME)
			if int(L.get("lv", 1)) >= int(D.links.levels.double_at):
				delayed.append({"t": 0.15, "fn": _cast.bind(L.dst, true, int(D.links.max_depth))})
			_combo_add()


## 連擊與共鳴
func _combo_add() -> void:
	var C: Dictionary = D.links.combo
	combo += 1
	combo_t = float(C.window) + (1.0 if epistles.has("combo_plus") else 0.0)
	combo_best = maxi(combo_best, combo)
	var ths: Array = C.thresholds
	if combo_tier < ths.size() and combo >= int(ths[combo_tier]):
		_resonance(combo_tier)
		combo_tier += 1
	elif combo_tier >= ths.size() and (combo - int(ths[-1])) % int(C.get("repeat_every", 25)) == 0:
		_resonance(ths.size() - 1)   # 最高一層之後，每再連一段就再共鳴一次


func _resonance(tier: int) -> void:
	run_resonances += 1
	var C: Dictionary = D.links.combo
	var dmg: float = float(C.damage[tier])
	resonances.append({"pos": paul.pos + Vector2(0, -6), "r": 0.0, "tier": tier, "hit": {}, "dmg": dmg})
	if fever <= 0.0:
		meter = minf(1.0, meter + float(C.meter))
	_fire_links("reso", null, 0)
	ui.show_banner(["共鳴！", "再次共鳴！", "大共鳴！", "滿溢的共鳴！"][mini(tier, 3)], 1.4)
	ui.do_flash(0.35 + tier * 0.1)
	shake = maxf(shake, 0.25 + tier * 0.08)
	Sfx.play("burst", 0.0)
	Sfx.buzz(60 + tier * 30)


## 往上飄的光點（驅散、連鎖都會用到）
func _mote(at: Vector2, col: Color) -> void:
	if parts.size() < 700:
		parts.append({"pos": at + Vector2(randf_range(-3, 3), randf_range(-3, 3)), "vel": Vector2(randf_range(-8, 8), randf_range(-30, -12)),
			"life": 0.7 + randf() * 0.5, "max": 1.2, "c1": Color.WHITE, "c2": col, "float": true})


func _link_card() -> Dictionary:
	# 已經有連結時，有機會出現「強化連結」
	var upgradable := links.filter(func(L): return int(L.get("lv", 1)) < int(D.links.levels.max))
	if not upgradable.is_empty() and (links.size() >= int(D.links.max_links) + (1 if epistles.has("link_plus") else 0) or randf() < 0.4):
		var L: Dictionary = upgradable[randi() % upgradable.size()]
		var lv: int = int(L.get("lv", 1))
		var K0: Dictionary = D.links.kinds[L.kind]
		var what := "觸發間隔縮短" if lv + 1 < int(D.links.levels.double_at) else "觸發時連出兩次"
		var who: String = (K0.short if _glob(L.kind) else L.src.name) + "→" + L.dst.name
		return {"kind": "link_up", "key": str(links.find(L)), "tag": "肢體", "title": "強化連結：%s　Lv%d → %d" % [K0.name, lv, lv + 1],
			"desc": "%s\n%s" % [who, what]}
	var cands := []
	for c in comps:
		# 光環、帳棚不會「出手」，連了也不會動，不放進候選
		if c.level > 0 and c.engine != "" and c.follows == "" and not c.engine in ["aura", "tent"]:
			cands.append(c)
	if cands.size() < 2 or links.size() >= int(D.links.max_links) + (1 if epistles.has("link_plus") else 0):
		return {}
	cands.shuffle()
	# 依權重抽觸發條件；隊伍裡沒有會治療的人就不出「一同得安慰」
	var has_heal := cands.any(func(c): return c.engine == "heal" or float(c.st.get("heal", 0.0)) > 0.0)
	var bag := []
	for k in D.links.kinds:
		if D.links.kinds[k].get("needs_heal", false) and not has_heal:
			continue
		for w in int(D.links.kinds[k].get("weight", 1)):
			bag.append(k)
	var kind: String = bag[randi() % bag.size()]
	var a: Dictionary = cands[0]
	var b: Dictionary = cands[1]
	var K: Dictionary = D.links.kinds[kind]
	var desc: String = K.desc % ([b.name] if _glob(kind) else [a.name, b.name])
	desc += "\n專屬：" + _tag_text(b)
	return {"kind": "link", "key": kind, "src": a.key, "dst": b.key, "tag": "肢體",
		"title": "肢體連結：" + K.name, "desc": desc}


## 傷害數字：同一隻敵人 0.25 秒內的傷害合成一個數字，最多 40 個同時在畫面上
func _dmg_number(e: Dictionary, dmg: float, src) -> void:
	if not Save.data.get("dnum_on", true):
		return
	var col: Color = src.get("col", C_CREAM) if src is Dictionary else C_CREAM
	for dn in dnums:
		if dn.e == e.node and dn.t < 0.25:
			dn.v += dmg
			dn.col = col
			return
	if dnums.size() >= 40:
		return
	dnums.append({"e": e.node, "pos": e.pos + Vector2(randf_range(-4, 4), -14), "v": dmg, "t": 0.0, "col": col})


## 觸發條件是否不看來源（受傷、治療、菁英、共鳴、五旬節）
func _glob(kind: String) -> bool:
	return bool(D.links.kinds[kind].get("global", false))


const TAG_COL := {"講道": Color("3fbfb0"), "詩歌": Color("ffd75e"), "守護": Color("9fd8ff"), "醫治": Color("7be08a"), "差派": Color("ff8a2a"), "門徒": Color("e8dcc0")}


## 流派專屬連結的說明（含恩賜樹強化後的數值）
func _tag_text(c: Dictionary) -> String:
	if not D.tag_links.has(c.tag):
		return "（%s 流派沒有專屬效果）" % c.tag
	var T: Dictionary = D.tag_links[c.tag]
	var k: float = float(c.get("tlink", 1.0))
	var v := ""
	match c.tag:
		"講道": v = "%.1f" % (1.0 + float(T.mult) * k)
		"詩歌": v = str(roundi(float(T.haste) * k * 100.0))
		"守護": v = str(_guard_max(c))
		"醫治": v = str(roundi(float(T.heal) * k))
		"差派": v = str(roundi(float(T.combo) * k))
		"門徒": v = str(roundi(float(T.radius) * k))
	return "%s・%s（%s）" % [c.tag, T.name, T.desc % v]


func _guard_max(c: Dictionary) -> int:
	return int(D.tag_links["守護"].max) + roundi((float(c.get("tlink", 1.0)) - 1.0) * 2.0) + int(Save.gift_global("guardcap"))


## 流派專屬連結的效果（講道的「加重」在出手前就算進傷害）
func _tag_effect(c: Dictionary) -> void:
	if not D.tag_links.has(c.tag):
		return
	var T: Dictionary = D.tag_links[c.tag]
	var k: float = float(c.get("tlink", 1.0))
	var col: Color = TAG_COL.get(c.tag, C_GOLD)
	match c.tag:
		"詩歌":
			haste_t = float(T.secs)
			haste_amt = maxf(haste_amt if haste_t > 0.0 else 0.0, float(T.haste) * k)
		"守護":
			guard = mini(_guard_max(c), guard + 1)
		"醫治":
			paul.hp = minf(float(D.paul.hp), paul.hp + float(T.heal) * k)
			heals.append({"who": paul, "t": 0.0})
		"差派":
			if combo > 0:
				for i in roundi(float(T.combo) * k):
					_combo_add()
		"門徒":
			var r: float = float(T.radius) * k
			for g in gems:
				if g.pos.distance_to(paul.pos) < r:
					g.pos = g.pos.lerp(paul.pos, 0.8)
	if tag_fx.size() < 12:
		tag_fx.append({"pos": c.pos, "text": T.name, "col": col, "t": 0.0})


## 套裝：湊齊就生效（血量加成在湊齊那一刻加上去）
func _update_sets() -> void:
	for st in D.armor_sets:
		if sets_on.has(st.id) or not st.pieces.all(func(pc): return armor.get(pc, 0) > 0):
			continue
		sets_on.append(st.id)
		for k in st.bonus:
			set_bonus[k] = float(set_bonus.get(k, 0.0)) + float(st.bonus[k])
		if st.bonus.has("hp"):
			D.paul.hp = float(D.paul.hp) + float(st.bonus.hp)
			paul.hp += float(st.bonus.hp)
		ui.show_banner("套裝：%s　%s" % [st.name, st.desc], 2.0)
		_ring_pop(paul.pos + Vector2(0, -8), C_GOLD, 40.0)


func _nova(c: Dictionary, s: Dictionary) -> void:
	if c.level == 0:
		return
	var center: Vector2 = c.pos + Vector2(0, -4)
	var r: float = s.radius * _area()
	blasts.append({"pos": center, "t": 0.0, "r": r, "col": c.col, "evo": evolved.has(c.key)})
	shake = maxf(shake, 0.12)
	for e in enemies:
		if not e.dead and e.pos.distance_to(center) < r + (8.0 if e.get("boss", false) else 0.0):
			_hurt(e, s.damage, center, c)
			if not e.get("boss", false):
				e.knock += (e.pos - center).normalized() * float(s.knock)
				if float(s.get("stun", 0.0)) > 0.0:
					e.stun = maxf(e.stun, float(s.stun))
	if float(s.get("heal", 0.0)) > 0.0:
		# 雅各：禱告順便幫保羅回血
		paul.hp = minf(float(D.paul.hp), paul.hp + float(s.heal))
		heals.append({"who": paul, "t": 0.0})


func _aura_r(barn: Dictionary) -> float:
	return barn.st.radius * _area()


func _fire_beam(from: Vector2, dir: Vector2, s: Dictionary, look := "", src = null) -> void:
	var length: float = s.length * _area()
	var width: float = s.width * _area()
	for o in enemies:
		var rel: Vector2 = o.pos - from
		var along: float = rel.dot(dir)
		var across: float = absf(rel.cross(dir))
		if along > 0.0 and along < length and across < width + (8.0 if o.get("boss", false) else 0.0):
			if s.get("stun", 0.0) > 0.0 and not o.get("boss", false):
				o.stun = s.stun
			if s.has("expose"):
				o.exposed_t = 3.0
				o.expose = float(s.expose)
			_hurt(o, s.damage * (s.lies_mult if o.type == "lies" else 1.0), from, src)
	beams.append({"pos": from, "dir": dir, "life": 0.3 if look == "" else 0.5, "len": length, "width": width, "look": look,
		"evo": src != null and evolved.has(src.key), "col": src.col if src != null else C_GOLD})
	if s.burst:
		var end: Vector2 = from + dir * length
		var br := 20.0 * _area()
		blasts.append({"pos": end, "t": 0.0, "r": br, "col": src.col if src != null else C_GOLD})
		for o in enemies:
			if o.pos.distance_to(end) < br:
				_hurt(o, s.damage, end, src)


func _update_projectiles(dt: float) -> void:
	for b in bolts:
		if b.get("straight", false):
			b.pos += b.vel * dt
			b.life -= dt
			for e in enemies:
				if e.dead or b.hit.has(e.node) or e.pos.distance_to(b.pos + Vector2(0, 4)) > e.r + 3.0:
					continue
				b.hit[e.node] = true
				_hurt(e, b.dmg, b.pos - b.vel.normalized() * 4.0, b.owner)
				if b.owner is Dictionary and float(b.owner.st.get("pin", 0.0)) > 0.0 and not e.get("boss", false):
					e.stun = maxf(e.stun, float(b.owner.st.pin))   # 哥尼流的標槍把敵人釘住
				b.pierce -= 1
				if b.pierce < 0:
					b.life = 0.0
					break
			continue
		var tg: Dictionary = b.target
		if tg.dead:
			var nxt := _nearest_enemies(b.pos, 60.0, 1, b.hit)
			if nxt.is_empty():
				b.life = 0.0
				continue
			b.target = nxt[0]
			tg = b.target
		var to: Vector2 = tg.pos - b.pos
		b.dir = to.normalized()
		b.pos += b.dir * b.spd * dt
		b.life -= dt
		if to.length() < 4.0:
			b.hit[tg.node] = true
			var big: bool = tg.get("elite", false) or tg.get("boss", false)
			_hurt(tg, b.dmg * (b.emult if big else 1.0), b.pos - to, b.owner)
			if b.split > 0 and not b.child:
				for o in _nearest_enemies(b.pos, 70.0, b.split, b.hit):
					bolts.append({"pos": b.pos, "target": o, "life": 0.8, "pierce": 0, "split": 0, "child": true,
						"dmg": maxf(1.0, b.dmg / 2.0), "size": 1, "hit": b.hit.duplicate(), "spd": b.spd, "emult": 1.0, "look": b.look, "owner": b.owner})
			if b.pierce > 0:
				b.pierce -= 1
				var nxt := _nearest_enemies(b.pos, 70.0, 1, b.hit)
				if nxt.is_empty():
					b.life = 0.0
				else:
					b.target = nxt[0]
			else:
				b.life = 0.0
	bolts = bolts.filter(func(b): return b.life > 0.0)

	for r in rings:
		var c: Dictionary = r.owner
		r.r += r.speed * dt * r.dir
		if r.dir > 0.0 and r.r >= r.max:
			if r.returns > 0:
				r.dir = -1.0
				r.returns -= 1
				r.hit = {}
			else:
				r.dead = true
		if r.dir < 0.0 and r.r <= 3.0:
			r.dead = true
		if r.r <= 0.0:
			continue
		var center: Vector2 = c.pos + Vector2(0, -6)
		for e in enemies:
			if not e.dead and not r.hit.has(e.node) and absf(center.distance_to(e.pos) - r.r) < 3.0 + r.thick * 2.0 + (10.0 if e.get("boss", false) else 0.0):
				r.hit[e.node] = true
				if e.d.get("immune", "") == "ring":
					_ring_pop(e.pos, Color("8a8a96"), 8.0)
					continue
				if r.stun > 0.0:
					e.stun = r.stun
				_hurt(e, r.dmg, Vector2.INF, c)   # 擊退只看招式自己的 knock，不套用一般命中的擊退
				if r.knock > 0.0 and not e.get("boss", false):
					e.knock += (e.pos - center).normalized() * r.knock
	rings = rings.filter(func(r): return not r.get("dead", false))

	for b in beams:
		b.life -= dt
	beams = beams.filter(func(b): return b.life > 0.0)
	for b in blasts:
		b.t += dt
	blasts = blasts.filter(func(b): return b.t < 0.3)
	for f in fires:
		f.t -= dt
		if f.t <= 0.0 and not f.get("hit", false):
			f.hit = true
			blasts.append({"pos": f.pos, "t": 0.0, "r": f.r, "col": C_GOLD if f.evo else C_FLAME, "evo": f.evo})
			_burst(f.pos, 8, C_FLAME, C_GOLD)
			for e in enemies:
				if not e.dead and e.pos.distance_to(f.pos) < f.r + (8.0 if e.get("boss", false) else 0.0):
					_hurt(e, f.dmg, f.pos, f.owner)
	fires = fires.filter(func(f): return f.t > -0.35)
	for arr in [nets, zaps, thrusts, gathers]:
		for f in arr:
			f.t += dt
	nets = nets.filter(func(f): return f.t < (maxf(0.4, f.stun) if f.get("look", "") == "purple" else 0.4))
	zaps = zaps.filter(func(f): return f.t < 0.25)
	thrusts = thrusts.filter(func(f): return f.t < 0.2)
	gathers = gathers.filter(func(f): return f.t < 0.5)
	for dl in delayed:
		dl.t -= dt
		if dl.t <= 0.0:
			dl.fn.call()
	delayed = delayed.filter(func(dl): return dl.t > 0.0)
	for h in heals:
		h.t += dt
	heals = heals.filter(func(h): return h.t < 0.9)

	for h in hits:
		h.t += dt
	hits = hits.filter(func(h): return h.t < 0.3)
	for q in quakes:
		q.r += 420.0 * dt
	quakes = quakes.filter(func(q): return q.r < 360.0)

	for fb in fever_bursts:
		fb.r += 260.0 * dt
		for e in enemies:
			if not e.dead and not fb.hit.has(e.node) and e.pos.distance_to(fb.pos) < fb.r:
				fb.hit[e.node] = true
				_hurt(e, D.fever.final_damage * fb.get("mult", 1.0), fb.pos)
	fever_bursts = fever_bursts.filter(func(fb): return fb.r < D.fever.final_radius)

	for s in shots:
		s.pos += s.vel * dt
		s.life -= dt
		if s.pos.distance_to(paul.pos + Vector2(0, -6)) < 5.0 and paul.inv <= 0.0:
			var belt: int = armor.get("belt", 0)
			if belt < 3:
				_damage_paul(s.dmg * (1.0 - 0.3 * belt))
			else:
				_ring_pop(s.pos, C_CREAM, 8.0)
			s.life = 0.0
	shots = shots.filter(func(s): return s.life > 0.0)


func _update_enemies(dt: float) -> void:
	var p := paul
	var bars := _barrier_pieces()
	var pri = by_key.get("pri")
	var barn = by_key.get("barn")
	var barn_on: bool = barn != null and _active(barn)
	var view := _view_rect()
	for e in enemies:
		if e.dead:
			continue
		if e.get("boss", false):
			_update_boss(e, dt)
			continue
		var d: Dictionary = e.d
		if d.has("roar_every"):
			e.roar -= dt
			if e.roar <= 0.0:
				e.roar = d.roar_every
				Sfx.play("roar")
				_ring_pop(e.pos, C_VL, d.roar_radius)
				shake = 0.15
				for c in comps:
					if c.level > 0 and c.down <= 0.0 and fever <= 0.0 and c.pos.distance_to(e.pos) < d.roar_radius:
						c.vel += (c.pos - e.pos).normalized() * d.roar_force * _scatter_mult()
						c.alert = 1.0
						scatter_by.fear += 1
		e.flash = maxf(0.0, e.flash - dt)
		e.cd = maxf(0.0, e.cd - dt)
		e.bcd = maxf(0.0, e.bcd - dt)
		if e.has("exposed_t"):
			e.exposed_t = maxf(0.0, e.exposed_t - dt)
		e.pos += e.knock * dt
		e.knock *= 0.85
		if e.stun > 0.0:
			e.stun -= dt
			continue
		var target: Vector2 = p.pos + Vector2(0, -4)
		if e.type == "fear" or e.get("hunter", false):
			var bd := 1e9
			for c in comps:
				if c.level == 0 or c.down > 0.0:
					continue
				var dd: float = c.pos.distance_to(e.pos)
				if dd < bd:
					bd = dd
					target = c.pos + Vector2(0, -4)
		var to: Vector2 = target - e.pos
		var dist: float = to.length()
		var dir: Vector2 = to / maxf(dist, 0.001)
		var go := 1.0
		if d.has("shoot"):
			var sh: Dictionary = d.shoot
			if dist < sh.keep_away:
				go = -0.6
			elif dist < sh.keep_away + 15.0:
				go = 0.0
			e.shoot -= dt
			if e.shoot <= 0.0 and dist < sh.range:
				shots.append({"pos": e.pos, "vel": dir * sh.speed, "life": 3.0, "dmg": float(sh.damage) * e.dmul})
				e.shoot = sh.every
		if d.has("dash"):
			# 暴動：每隔一陣子朝保羅衝刺
			e.dash_cd -= dt
			if e.dash_t > 0.0:
				e.dash_t -= dt
				go *= float(d.dash.mult)
			elif e.dash_cd <= 0.0 and dist < 130.0:
				e.dash_t = float(d.dash.time)
				e.dash_cd = float(d.dash.every)
				_ring_pop(e.pos, Color("e8481c"), 8.0)
		if d.has("blink"):
			# 邪術：瞬間移動到保羅附近
			e.blink_cd -= dt
			if e.blink_cd <= 0.0 and dist > 60.0:
				e.blink_cd = float(d.blink.every)
				_ring_pop(e.pos, Color("a060ff"), 10.0)
				var a := randf() * TAU
				e.pos = p.pos + Vector2(cos(a), sin(a) * 0.8) * randf_range(d.blink.min, d.blink.max)
				_ring_pop(e.pos, Color("a060ff"), 14.0)
		var wob: float = sin(t * 2.2 + e.ph) * 0.5
		e.pos += (dir * go + dir.orthogonal() * wob) * d.speed * e.smul * dt

		for b in bars:
			if b.up > 0.6 and e.bcd <= 0.0 and e.pos.distance_to(b.pos + Vector2(0, -3)) < 8.0:
				e.knock += (e.pos - p.pos).normalized() * pri.st.knockback * _guard() * 6.0
				e.bcd = 0.5
				_hurt(e, pri.st.damage * _guard(), Vector2.INF, pri)
		if e.dead:
			continue

		# 碰到同伴：打散、受傷、睡著
		if e.cd <= 0.0:
			for c in comps:
				if c.level == 0 or c.down > 0.0 or c.pos.distance_to(e.pos + Vector2(0, 5)) > e.r:
					continue
				var shielded: bool = fever > 0.0 or (e.type == "fear" and barn_on and barn.st.fear_immune and c.pos.distance_to(barn.pos) < _aura_r(barn))
				var out: Vector2 = (c.pos - p.pos).normalized()
				if d.scatter > 0 and not shielded:
					c.vel += out * d.scatter * _scatter_mult()
					scatter_by[e.type] += 1
					if d.scatter > 50:
						c.alert = 0.9
				if d.has("sleep_for") and not shielded:
					c.sleep = d.sleep_for
					scatter_by[e.type] += 1
				if fever <= 0.0:
					_damage_companion(c, d.damage * e.dmul * float(D.waves.hunter.comp_damage))
				if d.dies_on_touch:
					_kill(e, fever > 0.0)
				else:
					e.cd = 0.7
					e.knock -= dir * 60.0
				break
		if e.dead:
			continue

		# 碰到保羅
		if p.pos.distance_to(e.pos + Vector2(0, 5)) < e.r and p.inv <= 0.0:
			_damage_paul(d.damage * e.dmul)
			e.knock -= dir * 80.0
			if d.dies_on_touch:
				_kill(e, false)
				continue

		# 跑太遠就繞回畫面邊緣，維持密度
		if not view.grow(140.0).has_point(e.pos):
			e.pos = _edge_point(16.0)

	_separate()
	enemies = enemies.filter(func(e): return not e.dead)


func _separate() -> void:
	var grid := {}
	for i in enemies.size():
		var e: Dictionary = enemies[i]
		if e.dead or e.get("boss", false):
			continue
		var k: Vector2i = Vector2i(floori(e.pos.x / SEP_CELL), floori(e.pos.y / SEP_CELL))
		if not grid.has(k):
			grid[k] = []
		grid[k].append(i)
	for k in grid:
		for i in grid[k]:
			var a: Dictionary = enemies[i]
			for ox in range(-1, 2):
				for oy in range(-1, 2):
					var nk: Vector2i = k + Vector2i(ox, oy)
					if not grid.has(nk):
						continue
					for j in grid[nk]:
						if j <= i:
							continue
						var b: Dictionary = enemies[j]
						var dv: Vector2 = b.pos - a.pos
						var d2: float = dv.length_squared()
						if d2 > 0.0 and d2 < 64.0:
							var dd := sqrt(d2)
							var push := dv * ((8.0 - dd) * 0.5 / dd)
							a.pos -= push
							b.pos += push


func _damage_paul(n: float) -> void:
	if fever > 0.0 or won:
		return
	var sh: int = armor.get("shield", 0)
	if sh > 0 and shield_cd <= 0.0:
		shield_cd = [12.0, 9.0, 6.0][sh - 1]
		paul.inv = 0.4
		_ring_pop(paul.pos + Vector2(0, -8), C_GOLD, 16.0)
		return
	if guard > 0:
		# 守護連結的護盾
		guard -= 1
		paul.inv = 0.4
		_ring_pop(paul.pos + Vector2(0, -8), Color("9fd8ff"), 16.0)
		return
	if armor.get("breast", 0) > 0:
		n *= 1.0 - float(D.armor.breast.per[armor.breast - 1])
	n *= 1.0 - Save.up_value("aegis")
	paul.hp -= n
	Sfx.play("hurt")
	Sfx.buzz(40)
	paul.inv = 0.6
	shake = 0.12
	_fire_links("hurt", null, 0)
	if paul.hp <= 0.0:
		paul.hp = 0.0
		_game_over()


func _damage_companion(c: Dictionary, n: float) -> void:
	if c.hurt_cd > 0.0:
		return
	if int(c.get("garment", 0)) > 0:
		# 多加縫的衣服擋下這一次
		c.garment -= 1
		c.hurt_cd = 0.4
		_ring_pop(c.pos + Vector2(0, -8), Color("e8d8b0"), 12.0)
		return
	if c.st.has("tough"):
		n *= float(c.st.tough)   # 參孫：受到的傷害減半
	n *= 1.0 - float(c.get("tdr", 0.0))   # 恩賜：減傷
	if float(c.get("tthorns", 0.0)) > 0.0:
		# 恩賜：被打時反擊身邊的敵人
		for e in enemies:
			if not e.dead and e.pos.distance_to(c.pos) < 26.0:
				_hurt(e, float(c.tthorns), c.pos, c)
		_ring_pop(c.pos + Vector2(0, -6), c.col, 20.0)
	c.hp -= n
	c.hurt_cd = 0.4
	_fire_links("hurt", null, 0)
	if c.hp <= 0.0:
		c.hp = 0.0
		c.down = D.companion_rules.down_seconds
		c.vel = Vector2.ZERO
		if t - t_start < 210.0:
			someone_down = true


# ---------- 場景物件（依區塊生成） ----------
func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h) / 4294967296.0


## 把圓形的東西推出擋路的方塊（石柱、石牆）
func _push_out(pos: Vector2, r: float) -> Vector2:
	for rc: Rect2 in solids:
		if pos.x < rc.position.x - r or pos.x > rc.end.x + r or pos.y < rc.position.y - r or pos.y > rc.end.y + r:
			continue
		var q := Vector2(clampf(pos.x, rc.position.x, rc.end.x), clampf(pos.y, rc.position.y, rc.end.y))
		var d := pos - q
		var l := d.length()
		if l < r:
			if l < 0.01:
				# 中心在方塊裡：往最近的邊推出去
				var c := rc.get_center()
				d = Vector2(signf(pos.x - c.x), 0.0) if absf(pos.x - c.x) / rc.size.x > absf(pos.y - c.y) / rc.size.y else Vector2(0.0, signf(pos.y - c.y))
				pos = Vector2(rc.end.x + r if d.x > 0 else (rc.position.x - r if d.x < 0 else pos.x), rc.end.y + r if d.y > 0 else (rc.position.y - r if d.y < 0 else pos.y))
			else:
				pos = q + d / l * r
	return pos


func _collide_solids() -> void:
	if solids.is_empty():
		return
	paul.pos = _push_out(paul.pos, 4.0)
	for c in comps:
		if c.level > 0:
			c.base = _push_out(c.base, 3.0)
	for e in enemies:
		if not e.dead and not e.get("boss", false):
			e.pos = _push_out(e.pos, 3.0)


## 關卡機制：馬爾他的暴風每隔一陣子吹過來，把所有人往同一個方向推
func _update_wind(dt: float) -> void:
	var hz: Dictionary = stage.get("hazard", {})
	if hz.get("kind", "") != "wind":
		return
	if wind_on > 0.0:
		wind_on -= dt
		var f: float = float(hz.force) * dt
		paul.pos += wind_dir * f * 0.5
		for c in comps:
			if c.level > 0:
				c.base += wind_dir * f * 0.5
		for e in enemies:
			if not e.dead and not e.get("boss", false):
				e.pos += wind_dir * f
		return
	wind_t -= dt
	if wind_t <= 0.0:
		wind_t = float(hz.every)
		wind_on = float(hz.dur)
		wind_dir = Vector2.RIGHT.rotated(randf() * TAU)
		ui.show_banner(hz.get("text", "暴風！"), 1.5)
		Sfx.play("warn", 0.0)


func _update_chunks() -> void:
	var v := _view_rect().grow(40.0)
	var x0 := floori(v.position.x / CHUNK)
	var x1 := floori(v.end.x / CHUNK)
	var y0 := floori(v.position.y / CHUNK)
	var y1 := floori((v.end.y + 20.0) / CHUNK)
	var keep := {}
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			var key := Vector2i(cx, cy)
			keep[key] = true
			if chunks.has(key):
				continue
			var items := []
			var rects := []
			for k in 3:
				var h := _hash(cx * 7 + k * 131, cy * 13 + k * 71)
				var wx := cx * CHUNK + floori(_hash(cx + k * 17, cy * 3 + 1) * CHUNK)
				var wy := cy * CHUNK + floori(_hash(cx * 5 + 2, cy + k * 29) * CHUNK)
				if Vector2(wx, wy).length() < 50.0:
					continue
				# 依關卡的 props 比例挑一種物件
				var acc := 0.0
				var pick = null
				for pr in stage.get("props", []):
					acc += float(pr.weight)
					if h < acc:
						pick = pr
						break
				if pick == null:
					continue
				var texs: Array = pick.tex
				var key2: String = texs[floori(_hash(cx, cy + k) * texs.size()) % texs.size()]
				var t2 := _tex(key2)
				var s := _sprite(key2, Vector2(-t2.get_width() / 2, -t2.get_height()))
				s.position = Vector2(wx, wy)
				items.append(s)
				if pick.has("solid"):
					var bw: float = pick.solid[0]
					var bh: float = pick.solid[1]
					rects.append(Rect2(wx - bw / 2.0, wy - bh, bw, bh))
			chunks[key] = {"items": items, "rects": rects}
	for key in chunks.keys():
		if not keep.has(key):
			for s in chunks[key].items:
				s.queue_free()
			chunks.erase(key)
	solids.clear()
	for key in chunks:
		solids.append_array(chunks[key].rects)


# ---------- 畫面 ----------
func _render(dt: float) -> void:
	var p := paul
	var shake_off := Vector2.ZERO
	if shake > 0.0:
		shake -= dt
		shake_off = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
	cam.position = p.pos.round() + shake_off
	var v := _view_rect()
	ground.position = (v.position - Vector2(16, 16)).floor()
	ground.region_rect = Rect2(ground.position, v.size + Vector2(32, 32))

	var walk := int(t * 5.0) % 2
	p.node.texture = _tex("%s%s_%d" % [pa.key, "_evo" if evolved.has(pa.key) else "", walk if p.moving else 0])
	p.node.position = p.pos.round()
	var pk: float = pa.castfx / 0.18
	p.node.scale = Vector2(1.0 + 0.15 * pk, 1.0 - 0.1 * pk)
	p.node.modulate.a = 0.4 if p.inv > 0.0 and int(t * 20.0) % 2 == 1 else 1.0
	for c in comps:
		if c.level == 0:
			continue
		var f: int = (walk + c.i) % 2 if (p.moving or c.vel.length() > 5.0) and c.down <= 0.0 else 0
		c.node.texture = _tex("%s%s_%d" % [c.key, "_evo" if evolved.has(c.key) else "", f])
		c.node.position = c.pos.round()
		c.node.rotation = deg_to_rad(80.0) if c.down > 0.0 else 0.0
		var k: float = c.castfx / 0.18
		c.node.scale = Vector2(1.0 + 0.2 * k, 1.0 - 0.12 * k)
		if c.down > 0.0:
			c.node.modulate = Color(0.55, 0.55, 0.6)
		elif c.sleep > 0.0:
			c.node.modulate = Color(0.6, 0.65, 0.85)
		else:
			c.node.modulate = Color.WHITE.lerp(Color(1.8, 1.7, 1.2), k)
	var ef := int(t * 4.0) % 2
	for e in enemies:
		if not e.get("boss", false):
			e.node.texture = _tex("%s_%d" % [e.sprite, (ef + int(e.ph)) % 2])
		e.node.position = e.pos.round()
		if e.flash > 0.0:
			e.node.modulate = Color(4, 4, 3.5)
		elif e.stun > 0.0 or (e.get("boss", false) and e.state == "break"):
			e.node.modulate = Color(1.5, 1.5, 0.8)
		elif float(e.get("exposed_t", 0.0)) > 0.0:
			e.node.modulate = Color(1.6, 1.15, 0.6)   # 被燈照亮
		else:
			e.node.modulate = e.tint

	ground_fx.queue_redraw()
	air.queue_redraw()

	var ct := get_viewport().get_canvas_transform()
	ui.place_name(D.paul.name, ct * p.pos, not over and not choosing)
	for c in comps:
		if c.follows != "":
			ui.place_name(c.name, Vector2.ZERO, false)
		elif c.with != "":
			ui.place_name(c.name, ct * ((c.pos + by_key[c.with].pos) / 2.0), c.level > 0 and not over and not choosing)
		else:
			ui.place_name(c.name, ct * c.pos, c.level > 0 and not over and not choosing)
	ui.set_boss(boss.hp / boss.max_hp if boss != null and not boss.dead else -1.0, D.boss.name)
	ui.update_hud({"hp_frac": clampf(p.hp / D.paul.hp, 0.0, 1.0), "level": level, "xp_frac": clampf(float(xp) / xp_need, 0.0, 1.0),
		"time": int(t), "kills": kills, "bread": run_bread, "meter": meter, "fever": fever, "fever_kills": fever_kills, "over": over, "choosing": choosing or chest_open, "build": build_text, "tasks": _task_text(), "combo": combo, "combo_t": combo_t, "boss_in": _boss_in()})


## 光的身影：沒有臉，只有光的輪廓，站在保羅身邊
func _draw_light(n: Node2D) -> void:
	var k: float = clampf(minf(light_max, fever) / 0.8, 0.0, 1.0)
	var at: Vector2 = (paul.pos + Vector2(-16, 0)).round()
	var pulse := 0.85 + 0.15 * sin(t * 2.0)
	for i in 6:
		var a := -PI / 2.0 + (i - 2.5) * 0.35
		n.draw_line(at + Vector2(0, -14), at + Vector2(0, -14) + Vector2(cos(a), sin(a)) * 30.0, Color(C_CREAM, 0.12 * k), 3.0)
	n.draw_circle(at + Vector2(0, -12), 18.0, Color(1, 1, 0.9, 0.18 * k * pulse))
	n.draw_colored_polygon(PackedVector2Array([at + Vector2(-6, 0), at + Vector2(-3, -14), at + Vector2(3, -14), at + Vector2(6, 0)]), Color(1, 1, 0.95, 0.75 * k))
	n.draw_circle(at + Vector2(0, -17), 3.0, Color(1, 1, 0.95, 0.85 * k))
	n.draw_arc(at + Vector2(0, -17), 5.0, 0.0, TAU, 16, Color(C_GOLD, 0.6 * k), 1.0)


func _dot_ring(n: Node2D, center: Vector2, r: float, squash: float, col: Color, every: float, ph: float, thick := 1) -> void:
	var count := maxi(12, int(r * TAU / every))
	for k in count:
		var a := k / float(count) * TAU + ph
		n.draw_rect(Rect2(round(center.x + cos(a) * r), round(center.y + sin(a) * r * squash), thick, thick), col)


func _draw_ground_fx() -> void:
	var n := ground_fx
	for o in [paul] + comps:
		if o != paul and o.level == 0:
			continue
		n.draw_rect(Rect2(round(o.pos.x) - 4, round(o.pos.y) - 1, 9, 2), Color(0.24, 0.13, 0.05, 0.35))
	for k in evolved:
		var ec: Dictionary = by_key[k]
		if ec.level > 0 and ec.down <= 0.0:
			var gp: Vector2 = ec.pos.round()
			var a := 0.5 + 0.3 * sin(t * 4.0)
			n.draw_arc(gp, 8.0, 0.0, TAU, 20, Color(C_GOLD, a), 1.0)
			if int(t * 6.0 + ec.i) % 3 == 0:
				n.draw_rect(Rect2(gp.x + randf_range(-6, 6), gp.y - randf_range(4, 18), 1, 1), C_CREAM)
	var barn = by_key.get("barn")
	if barn != null and _active(barn):
		var pulse := fmod(t, 1.6) / 1.6
		var bc: Vector2 = barn.pos.round() + Vector2(0, -2)
		var col := C_GOLD if fever > 0.0 or evolved.has("barn") else Color("bfe3ff")
		_dot_ring(n, bc, _aura_r(barn), 0.62, Color(col, 0.9), 3.0, t * 0.8)
		_dot_ring(n, bc, _aura_r(barn) * pulse, 0.62, Color(col.lightened(0.4), 0.8), 4.0, -t)
	for ch in chests:
		var cx: float = roundf(ch.pos.x)
		var cy: float = roundf(ch.pos.y) - roundf(absf(sin(t * 3.0)) * 2.0)
		n.draw_rect(Rect2(cx - 6, cy - 6, 13, 10), Color("2a1a14"))
		n.draw_rect(Rect2(cx - 5, cy - 5, 11, 8), Color("b8862e"))
		n.draw_rect(Rect2(cx - 5, cy - 5, 11, 3), C_GOLD)
		n.draw_rect(Rect2(cx - 1, cy - 3, 3, 3), Color("2a1a14"))
		if int(t * 4.0) % 2 == 0:
			n.draw_rect(Rect2(cx + 6, cy - 9, 1, 1), Color.WHITE)
			n.draw_rect(Rect2(cx - 8, cy - 2, 1, 1), Color.WHITE)
	for b in breads:
		var bx: float = roundf(b.pos.x)
		var by: float = roundf(b.pos.y) - roundf(absf(sin(t * 3.0 + b.pos.x)) * 1.5)
		n.draw_rect(Rect2(bx - 4, by - 3, 9, 6), Color("2a1a10"))
		n.draw_rect(Rect2(bx - 3, by - 2, 7, 4), Color("c8873a"))
		n.draw_rect(Rect2(bx - 2, by - 2, 5, 1), Color("f0c070"))
		n.draw_rect(Rect2(bx - 1, by, 1, 1), Color("8a5a24"))
		n.draw_rect(Rect2(bx + 1, by, 1, 1), Color("8a5a24"))
	var tw := int(t * 6.0)
	for g in gems:
		var x: float = roundf(g.pos.x)
		var y: float = roundf(g.pos.y)
		# 經驗：小顆、不閃爍，滿地都是時也不會太花
		n.draw_rect(Rect2(x - 1, y - 2, 3, 5), Color("10202c"))
		n.draw_rect(Rect2(x - 2, y - 1, 5, 3), Color("10202c"))
		n.draw_rect(Rect2(x, y - 1, 1, 3), C_SKY)
		n.draw_rect(Rect2(x - 1, y, 3, 1), C_SKY)
		if (tw + int(g.pos.x)) % 11 == 0:
			n.draw_rect(Rect2(x, y, 1, 1), Color.WHITE)


func _draw_air() -> void:
	if wind_on > 0.0:
		# 暴風：一條條白色的風線往同一個方向掃過
		var v := _view_rect()
		for i in 24:
			var ph := fmod(t * 1.7 + i * 0.37, 1.0)
			var base := v.position + Vector2(_hash(i, 3) * v.size.x, _hash(i, 7) * v.size.y)
			var p0 := base + wind_dir * (ph - 0.5) * 120.0
			air.draw_line(p0, p0 + wind_dir * 14.0, Color(1, 1, 1, 0.45 * minf(1.0, wind_on)), 1.0)
	var n := air
	var on_fire := fever > 0.0
	for b in _barrier_pieces():
		var x: float = roundf(b.pos.x)
		var y: float = roundf(b.pos.y)
		var h: int = roundi(b.up * 7.0)
		n.draw_rect(Rect2(x - 5, y - h - 2, 1, h + 2), Color("5a3f28"))
		n.draw_rect(Rect2(x + 5, y - h - 2, 1, h + 2), Color("5a3f28"))
		for r in h:
			var col := Color("b5533c") if r % 3 == 2 else (Color("d9c7a0") if r % 3 == 1 else Color("efe2c0"))
			if on_fire:
				col = C_RED if r % 3 == 2 else (C_FLAME if r % 3 == 1 else C_GOLD)
			elif evolved.has("pri"):
				col = C_GOLD if r % 3 == 2 else (C_CREAM if r % 3 == 1 else Color.WHITE)
			n.draw_rect(Rect2(x - 4, y - h - 1 + r, 9, 1), col)
	for r in rings:
		if r.r <= 0.0:
			continue
		# 簡化：每圈只畫一條實線，顏色就是這位同伴的顏色，越擴散越淡
		var k: float = clampf(r.r / r.max, 0.0, 1.0)
		var center: Vector2 = (r.owner.pos + Vector2(0, -6)).round()
		var col: Color = r.owner.get("col", C_GOLD)
		var a := 0.95 - k * 0.55
		n.draw_arc(center, r.r, 0.0, TAU, maxi(16, int(r.r * 0.6)), Color(col, a), 1.0 + r.thick)
		if r.get("evo", false):
			n.draw_arc(center, r.r + 2.0, 0.0, TAU, maxi(16, int(r.r * 0.6)), Color(C_CREAM, a * 0.6), 1.0)
	for b in beams:
		var end: Vector2 = b.pos + b.dir * b.len
		var a := minf(1.0, b.life * 3.3)
		if b.get("evo", false):
			n.draw_line(b.pos, end, Color(C_GOLD, a * 0.35), b.width * 2.6)
		if b.look == "lamp":
			n.draw_line(b.pos, end, Color(C_FLAME if on_fire else Color("ff9a3a"), a * 0.45), b.width * 1.6)
			n.draw_line(b.pos, end, Color(C_GOLD, a * 0.8), b.width * 0.6)
			n.draw_circle(b.pos, 3.0, Color(C_CREAM, a))
		elif b.look == "sea":
			n.draw_line(b.pos, end, Color(C_FLAME if on_fire else Color("2f78c8"), a * 0.5), b.width * 1.6)
			n.draw_line(b.pos, end, Color(Color("8fd0ff"), a * 0.8), b.width * 0.8)
			n.draw_line(b.pos, end, Color(Color("eaf8ff"), a), 1.0)
		else:
			n.draw_line(b.pos, end, Color(C_FLAME if on_fire else b.get("col", Color("3fbfb0")), a * 0.6), b.width * 1.4)
			n.draw_line(b.pos, end, Color(C_CREAM, a), maxf(1.0, b.width * 0.4))
	for b in blasts:
		var k: float = b.t / 0.3
		n.draw_circle(b.pos, b.r * (0.4 + k * 0.6), Color(b.get("col", C_GOLD), (1.0 - k) * 0.6))
		n.draw_arc(b.pos, b.r * (0.4 + k * 0.6), 0.0, TAU, 32, Color(Color(b.get("col", C_GOLD)).lightened(0.4), 1.0 - k), 2.0)
		if b.get("evo", false):
			n.draw_arc(b.pos, b.r * (0.6 + k * 0.7), 0.0, TAU, 32, Color(C_CREAM, (1.0 - k) * 0.8), 1.0)
	for f in fires:
		if f.t > 0.0:
			var k: float = 1.0 - f.t / f.max
			n.draw_arc(f.pos, f.r, 0.0, TAU, 24, Color(C_FLAME, 0.4 + 0.5 * k), 1.0)
			n.draw_circle(f.pos, f.r * k, Color(C_FLAME, 0.18))
		else:
			var a: float = 1.0 + f.t / 0.35
			if f.get("evo", false):
				n.draw_rect(Rect2(f.pos.x - 7, f.pos.y - 70, 15, 70), Color(C_CREAM, a * 0.35))
			if f.get("look", "") == "glory":
				# 司提反：天開了，白金色寬光柱，落點一圈光
				n.draw_rect(Rect2(f.pos.x - 5, f.pos.y - 90, 11, 90), Color(Color.WHITE, a * 0.4))
				n.draw_rect(Rect2(f.pos.x - 2, f.pos.y - 90, 5, 90), Color(C_CREAM, a))
				n.draw_arc(f.pos, f.r * (1.4 - a * 0.4), 0.0, TAU, 24, Color(C_GOLD, a), 2.0)
			else:
				n.draw_rect(Rect2(f.pos.x - 3, f.pos.y - 60, 7, 60), Color(C_GOLD, a * 0.7))
				n.draw_rect(Rect2(f.pos.x - 1, f.pos.y - 60, 3, 60), Color(C_CREAM, a))
	var blink := int(t * 8.0) % 2 == 0
	for sh in tele:
		if sh.kind == "line":
			n.draw_line(sh.a, sh.b, Color(C_RED, 0.35), sh.w)
			var side: Vector2 = (sh.b - sh.a).normalized().orthogonal() * (sh.w / 2.0)
			var ea := 1.0 if blink else 0.5
			n.draw_line(sh.a + side, sh.b + side, Color(Color("ff3a2a"), ea), 1.0)
			n.draw_line(sh.a - side, sh.b - side, Color(Color("ff3a2a"), ea), 1.0)
		else:
			n.draw_circle(sh.c, sh.r, Color(C_RED, 0.35))
			n.draw_arc(sh.c, sh.r, 0.0, TAU, 40, Color(Color("ff3a2a"), 1.0 if blink else 0.5), 1.0)
	for h in hits:
		var a: float = 1.0 - h.t / 0.3
		if h.sh.kind == "line":
			n.draw_line(h.sh.a, h.sh.b, Color(Color("d8d8e8"), a), h.sh.w)
		else:
			n.draw_circle(h.sh.c, h.sh.r, Color(Color("d8d8e8"), a * 0.8))
	for q in quakes:
		_dot_ring(n, q.pos.round(), q.r, 0.7, Color(C_GOLD, 1.0 - q.r / 360.0), 3.0, 0.0, 2)
		_dot_ring(n, q.pos.round(), q.r * 0.7, 0.7, Color(C_CREAM, 1.0 - q.r / 360.0), 4.0, 0.5, 1)
	if armor.get("shield", 0) > 0 and shield_cd <= 0.0:
		_dot_ring(n, paul.pos.round() + Vector2(0, -8), 9.0, 1.1, Color(C_GOLD, 0.55), 3.0, t)
	if light > 0.0:
		_draw_light(n)
	for fb in fever_bursts:
		_dot_ring(n, fb.pos.round() + Vector2(0, -4), fb.r, 0.8, C_GOLD, 2.0, 0.0, 2)
		_dot_ring(n, fb.pos.round() + Vector2(0, -4), fb.r - 4.0, 0.8, C_FLAME, 3.0, 0.3, 2)
	for f in nets:
		if f.get("look", "") == "purple":
			# 呂底亞：紫布鋪在地上，定住的時間內慢慢淡掉
			var life: float = maxf(0.4, f.stun)
			var pk: float = clampf(f.t / life, 0.0, 1.0)
			var rr2: float = f.r * minf(1.0, f.t / 0.12)
			n.draw_circle(f.pos, rr2, Color(Color("8a3aa8"), 0.3 * (1.0 - pk)))
			n.draw_arc(f.pos, rr2, 0.0, TAU, 28, Color(C_GOLD if f.evo else Color("d8a0f0"), 1.0 - pk), 2.0)
			for i in 3:
				n.draw_line(f.pos + Vector2(-rr2 * 0.7, -rr2 * 0.4 + i * rr2 * 0.4), f.pos + Vector2(rr2 * 0.7, -rr2 * 0.4 + i * rr2 * 0.4), Color(Color("b86ad0"), 0.5 * (1.0 - pk)), 1.0)
			continue
		var k: float = f.t / 0.4
		var col: Color = C_GOLD if f.evo else f.get("col", Color("e8dcc0"))
		var rr: float = f.r * (1.0 - 0.3 * k)
		n.draw_arc(f.pos, rr, 0.0, TAU, 28, Color(col, 1.0 - k), 2.0)
		for i in 6:
			var a := i * PI / 6.0
			n.draw_line(f.pos - Vector2(cos(a), sin(a)) * rr, f.pos + Vector2(cos(a), sin(a)) * rr, Color(col, (1.0 - k) * 0.6), 1.0)
		n.draw_arc(f.pos, rr * 0.5, 0.0, TAU, 20, Color(col, (1.0 - k) * 0.6), 1.0)
	for z in zaps:
		var a: float = 1.0 - z.t / 0.25
		var col: Color = C_GOLD if z.evo else z.get("col", Color("ffe14d"))
		for i in z.pts.size() - 1:
			var p0: Vector2 = z.pts[i]
			var p1: Vector2 = z.pts[i + 1]
			var mid: Vector2 = (p0 + p1) / 2.0 + (p1 - p0).orthogonal().normalized() * randf_range(-5, 5)
			n.draw_polyline(PackedVector2Array([p0, mid, p1]), Color(col, a * 0.6), 3.0)
			n.draw_polyline(PackedVector2Array([p0, mid, p1]), Color(Color.WHITE, a), 1.0)
	for th in thrusts:
		var a: float = 1.0 - th.t / 0.2
		var tip: Vector2 = th.from + th.dir * th.len * minf(1.0, th.t / 0.06)
		var col: Color = C_GOLD if th.crit or th.evo else th.get("col", Color("d8d0c0"))
		if th.get("look", "") == "dash":
			# 腓利：一道青色的奔跑殘影
			col = C_GOLD if th.crit or th.evo else Color("6ae0d0")
			n.draw_line(th.from, tip, Color(col, a * 0.35), 7.0)
			for i in 3:
				n.draw_circle(th.from.lerp(tip, 0.3 + i * 0.25), 2.0 + i, Color(col, a * 0.5))
		n.draw_line(th.from, tip, Color(col, a), 3.0 if th.crit else 2.0)
		n.draw_circle(tip, 2.0, Color(Color.WHITE, a))
	for g in gathers:
		var k: float = g.t / 0.5
		_dot_ring(n, g.pos.round() + Vector2(0, -4), g.r * (1.0 - k), 0.8, Color(C_HEAL, 1.0 - k), 4.0, k * 3.0)
	for dn in dnums:
		var k2: float = dn.t / 0.7
		var big: bool = dn.v >= 20.0
		var txt := str(roundi(dn.v))
		var fs := 10 if big else 8
		var pos2: Vector2 = (dn.pos + Vector2(-fs * txt.length() * 0.3, -k2 * 10.0)).round()
		var a2 := 1.0 if k2 < 0.6 else (1.0 - k2) / 0.4
		n.draw_string_outline(UIKit.font(), pos2, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, Color(Color("140c10"), a2))
		n.draw_string(UIKit.font(), pos2, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Color.WHITE.lerp(dn.col, 0.6) if not big else C_GOLD, a2))
	for f in tag_fx:
		var k: float = f.t / 0.8
		var pos: Vector2 = (f.pos + Vector2(-8, -32 - k * 10.0)).round()
		n.draw_string_outline(UIKit.font(), pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(Color("140c10"), 1.0 - k))
		n.draw_string(UIKit.font(), pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(f.col, 1.0 - k))
	if guard > 0:
		for i in guard:
			_dot_ring(n, paul.pos.round() + Vector2(0, -8), 11.0 + i * 3.0, 1.0, Color(Color("9fd8ff"), 0.7), 3.0, t * (1.0 + i * 0.3))
	for f in link_fx:
		var to: Vector2 = f.b.pos + Vector2(0, -8)
		if f.t < 0.3:
			var a: float = 1.0 - f.t / 0.3
			# 從來源射向被觸發的人：前 0.08 秒線往前長出去
			var tip: Vector2 = f.a.lerp(to, minf(1.0, f.t / 0.08))
			n.draw_line(f.a, tip, Color(C_FLAME if f.depth >= 2 else C_GOLD, a * 0.8), 2.0 + f.depth)
			n.draw_line(f.a, tip, Color(C_CREAM, a), 1.0)
			n.draw_circle(tip, 3.0 + f.depth * 1.5, Color(C_GOLD, a * 0.5))
			n.draw_circle(tip, 2.0 + f.depth, Color(C_CREAM, a))
		if f.depth >= 2:
			var k: float = f.t / 0.6
			var txt := "連鎖×%d" % f.depth
			var pos: Vector2 = (to + Vector2(-12, -10 - k * 10.0)).round()
			n.draw_string_outline(UIKit.font(), pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(Color("140c10"), 1.0 - k))
			n.draw_string(UIKit.font(), pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(C_GOLD if f.depth == 2 else C_FLAME, 1.0 - k))
	for b in bolts:
		var x: float = roundf(b.pos.x)
		var y: float = roundf(b.pos.y)
		if b.get("evo", false):
			n.draw_circle(b.pos, 4.0, Color(C_GOLD, 0.35))
		var col: Color = C_FLAME if on_fire else (b.owner.get("col", C_GOLD) if b.get("owner") is Dictionary else C_GOLD)
		if b.look == "coin":
			n.draw_rect(Rect2(x - 2, y - 2, 5, 5), Color("2a1a10"))
			n.draw_rect(Rect2(x - 1, y - 1, 3, 3), C_FLAME if on_fire else C_GOLD)
			n.draw_rect(Rect2(x - 1, y - 1, 1, 1), Color.WHITE)
		elif b.look == "letter":
			# 捲起來的書信：米白色、中間一點紅色封印，跟著方向轉
			var d: Vector2 = b.dir
			var side := d.orthogonal()
			var c0: Vector2 = b.pos
			n.draw_line(c0 - d * 8.0, c0, Color(C_CREAM, 0.35), 2.0)
			n.draw_colored_polygon(PackedVector2Array([c0 - d * 3 - side * 2, c0 + d * 3 - side * 2, c0 + d * 3 + side * 2, c0 - d * 3 + side * 2]), C_FLAME if on_fire else Color("f4ead2"))
			n.draw_rect(Rect2(c0.round() - Vector2(0, 0), Vector2(1, 1)), Color("c0392b"))
		elif b.look == "pilum":
			# 羅馬標槍：木桿＋鐵尖
			var d: Vector2 = b.dir
			n.draw_line(b.pos - d * 9.0, b.pos, Color("8a6438"), 2.0)
			n.draw_line(b.pos - d * 1.0, b.pos + d * 3.0, C_FLAME if on_fire else Color("e0e0e8"), 2.0)
		elif b.look == "fig":
			n.draw_rect(Rect2(x - 2, y - 2, 4, 4), Color("2a1420"))
			n.draw_rect(Rect2(x - 1, y - 1, 3, 3), C_FLAME if on_fire else Color("8a4a8a"))
			n.draw_rect(Rect2(x, y - 2, 1, 1), Color("7a8a3a"))
		elif b.look == "stone":
			var sz: int = 3 if b.size >= 2 else 2
			n.draw_rect(Rect2(x - 1, y - 1, sz + 1, sz + 1), Color("2a2030"))
			n.draw_rect(Rect2(x, y - 1, sz, sz), Color("d8d0c0") if not on_fire else C_FLAME)
			n.draw_rect(Rect2(x, y - 1, 1, 1), Color.WHITE)
		else:
			# 光箭：後面拖一道光，比較看得出是誰射的、往哪飛
			var dir: Vector2 = b.get("dir", Vector2.RIGHT)
			n.draw_line(b.pos - dir * (10.0 + b.size * 3.0), b.pos, Color(col, 0.45), 2.0 + b.size)
			n.draw_line(b.pos - dir * 6.0, b.pos, Color(C_CREAM, 0.8), 1.0)
			var r: int = 2 if b.size < 2 else 3
			n.draw_rect(Rect2(x - r, y - 1, r * 2 + 1, 3), col)
			n.draw_rect(Rect2(x - 1, y - r, 3, r * 2 + 1), col)
			n.draw_rect(Rect2(x - 1, y - 1, 3, 3), Color.WHITE)
	for s in shots:
		n.draw_rect(Rect2(roundf(s.pos.x) - 1, roundf(s.pos.y) - 1, 3, 3), Color("c8e070"))
		n.draw_rect(Rect2(roundf(s.pos.x), roundf(s.pos.y), 1, 1), Color("2a2638"))
	for h in heals:
		if h.t > 0.75:
			continue
		var x: float = roundf(h.who.pos.x)
		var y: float = roundf(h.who.pos.y) - 19.0 - roundf(h.t * 10.0)
		n.draw_rect(Rect2(x - 3, y - 1, 7, 3), Color("10301a"))
		n.draw_rect(Rect2(x - 1, y - 3, 3, 7), Color("10301a"))
		n.draw_rect(Rect2(x - 2, y, 5, 1), C_HEAL)
		n.draw_rect(Rect2(x, y - 2, 1, 5), C_HEAL)
	for q in parts:
		var qc: Color = q.c1 if q.life > q.max * 0.5 else q.c2
		if q.get("float", false):
			var a: float = clampf(q.life / 0.4, 0.0, 1.0)
			n.draw_rect(Rect2(roundf(q.pos.x) - 1, roundf(q.pos.y), 3, 1), Color(qc, a * 0.6))
			n.draw_rect(Rect2(roundf(q.pos.x), roundf(q.pos.y) - 1, 1, 3), Color(qc, a))
		else:
			n.draw_rect(Rect2(roundf(q.pos.x), roundf(q.pos.y), 1, 1), qc)
	for sp in sparks:
		var sa: float = 1.0 - sp.t / 0.12
		var sx: float = roundf(sp.pos.x)
		var sy: float = roundf(sp.pos.y)
		n.draw_rect(Rect2(sx - 2, sy, 5, 1), Color(Color.WHITE, sa))
		n.draw_rect(Rect2(sx, sy - 2, 1, 5), Color(Color.WHITE, sa))
		n.draw_rect(Rect2(sx - 1, sy - 1, 3, 3), Color(C_GOLD, sa * 0.8))
	for rz in resonances:
		var ra: float = 1.0 - rz.r / 260.0
		var rcol: Color = [C_GOLD, C_FLAME, Color("ff6ad5"), Color.WHITE][mini(rz.tier, 3)]
		n.draw_arc(rz.pos, rz.r, 0.0, TAU, 64, Color(rcol, ra), 3.0 + rz.tier)
		n.draw_arc(rz.pos, rz.r * 0.85, 0.0, TAU, 64, Color(C_CREAM, ra * 0.7), 1.0)
		if rz.r < 60.0:
			n.draw_rect(Rect2(rz.pos.x - 4 - rz.tier, rz.pos.y - 120, 9 + rz.tier * 2, 120), Color(C_CREAM, ra * 0.5))
	for o in pops:
		var k: float = o.t / 0.25
		_dot_ring(n, o.pos.round(), o.size * (0.3 + k), 1.0, Color(o.col, 1.0 - k), 3.0, 0.0)
	var max_hp: float = _comp_max_hp()
	for c in [paul] + comps:
		if c != paul and c.level == 0:
			continue
		var x: float = roundf(c.pos.x)
		var y: float = roundf(c.pos.y)
		if on_fire:
			var fl := int(t * 12.0) % 2
			n.draw_rect(Rect2(x - 1 + fl, y - 23, 2, 1), C_CREAM)
			n.draw_rect(Rect2(x - 1, y - 22, 3, 2), C_GOLD)
			n.draw_rect(Rect2(x - 1, y - 20, 3, 1), C_FLAME)
			continue
		if c == paul:
			continue
		for gi in int(c.get("garment", 0)):
			# 頭上的小衣服：一件一個
			n.draw_rect(Rect2(x - 5 + gi * 4, y - 26, 3, 3), Color("e8d8b0"))
			n.draw_rect(Rect2(x - 4 + gi * 4, y - 25, 1, 1), Color("c87a5a"))
		if c.hp < max_hp and c.down <= 0.0:
			n.draw_rect(Rect2(x - 5, y - 21, 10, 2), Color("0b080d"))
			n.draw_rect(Rect2(x - 5, y - 21, roundf(10.0 * c.hp / max_hp), 2), C_HEAL if c.hp > max_hp * 0.35 else C_RED)
		if c.down > 0.0:
			var frac: float = 1.0 - c.down / D.companion_rules.down_seconds
			n.draw_rect(Rect2(x - 5, y - 12, 10, 2), Color("0b080d"))
			n.draw_rect(Rect2(x - 5, y - 12, roundf(10.0 * frac), 2), C_CREAM)
		if c.alert > 0.0:
			n.draw_rect(Rect2(x - 2, y - 26, 5, 7), C_CREAM)
			n.draw_rect(Rect2(x, y - 25, 1, 3), Color("c0392b"))
			n.draw_rect(Rect2(x, y - 21, 1, 1), Color("c0392b"))
		if c.sleep > 0.0:
			var zy: float = y - 24.0 - roundf((2.0 - c.sleep) * 3.0)
			n.draw_rect(Rect2(x + 4, zy, 3, 1), Color("9fb4e0"))
			n.draw_rect(Rect2(x + 5, zy + 1, 1, 1), Color("9fb4e0"))
			n.draw_rect(Rect2(x + 4, zy + 2, 3, 1), Color("9fb4e0"))


# ---------- 寶箱與進化 ----------
func _open_chest() -> void:
	chest_open = true
	run_chests += 1
	joy.on = false
	ui.joy.on = false
	var results := []
	for evo in _ready_evolutions():
		_evolve(evo)
		results.append({"title": "進化！" + evo.name, "desc": evo.desc, "big": true})
		break
	if results.is_empty():
		var n := randi_range(int(D.chest.rolls_min), int(D.chest.rolls_max)) + (1 if randf() < Save.up_value("lucky") else 0)
		for i in n:
			var pool := _make_cards().filter(func(card): return not card.kind in ["heal", "grace_dmg", "grace_spd", "manna"])
			if pool.is_empty():
				pool = _filler_cards()
			var card: Dictionary = pool[randi() % pool.size()]
			_apply_card(card)
			results.append({"title": card.title, "desc": card.desc, "big": false})
	_refresh_build_text()
	Sfx.play("chest", 0.0)
	Sfx.buzz(50)
	for i in int(Save.meta.bread.drop.chest):
		breads.append({"pos": paul.pos + Vector2(randf_range(-14, 14), randf_range(-10, 10))})
	ui.do_flash(0.4)
	ui.show_chest(results)


func _stage_list() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/stages.json")).stages


## 已經符合條件、還沒進化的
func _ready_evolutions() -> Array:
	var out := []
	for evo in D.evolutions:
		if not by_key.has(evo.companion):
			continue
		var c: Dictionary = by_key[evo.companion]
		if c.level >= 5 and fruits.has(evo.fruit) and not evolved.has(c.key):
			out.append(evo)
	return out


func _evo_of(key: String) -> Dictionary:
	for evo in D.evolutions:
		if evo.companion == key:
			return evo
	return {}


func _evolve(evo: Dictionary) -> void:
	var c: Dictionary = by_key[evo.companion]
	evolved[c.key] = evo
	run_evolutions += 1
	if evo.has("stats"):
		c.st.merge(evo.stats, true)
	if evo.has("every") and quake_key == "":
		quake_key = c.key
		evo_timer = 2.0
	_ring_pop(c.pos + Vector2(0, -8), C_GOLD, 50.0)
	_burst(c.pos + Vector2(0, -8), 20, C_GOLD, C_CREAM)
	Sfx.play("evolve", 0.0)
	Sfx.buzz(150)
	shake = 0.3
	ui.do_flash(0.5)
	ui.show_banner("進化！%s：%s" % [c.name, evo.name], 2.2)
	var l: Label = ui.names[c.name]
	l.text = "★" + l.text
	l.label_settings.font_color = C_GOLD
	l.modulate.a = 1.0


func _on_chest_closed() -> void:
	chest_open = false
	if xp >= xp_need:
		_level_up()


func _quake() -> void:
	var evo: Dictionary = evolved[quake_key]
	var src: Dictionary = by_key[quake_key]
	evo_timer = evo.every
	var view := _view_rect().grow(20.0)
	for e in enemies:
		if not e.dead and view.has_point(e.pos):
			e.stun = evo.stun
			_hurt(e, evo.damage, Vector2.INF, src)
	quakes.append({"pos": src.pos, "r": 0.0})
	Sfx.play("quake", 0.0)
	shake = 0.45
	ui.do_flash(0.35)
	ui.show_banner(evo.name, 1.2)


# ---------- Boss ----------
func _boss_tex() -> Texture2D:
	# 各城市有自己的 Boss 圖（tools/make_enemies.py 產生）；沒有的話用程式畫的鎖鏈
	var path := "res://assets/sprites/boss_%s.png" % stage.id
	if ResourceLoader.exists(path):
		return load(path)
	var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	var c := Vector2(20, 20)
	for y in 40:
		for x in 40:
			var p := Vector2(x + 0.5, y + 0.5) - c
			var r := p.length()
			var col := Color(0, 0, 0, 0)
			if r < 10.0:
				col = Color("3a2430") if r > 8.0 else Color("1a0c16")
			else:
				# 十二個鎖鏈環繞著核心
				for i in 12:
					var a := i * TAU / 12.0
					var lc := c + Vector2(cos(a), sin(a)) * 15.0 - c
					var tdir := Vector2(-sin(a), cos(a))
					var rel := p - lc
					var u := rel.dot(tdir) / 3.6
					var v := rel.dot(Vector2(cos(a), sin(a))) / 2.2
					var dd := u * u + v * v
					if dd < 1.0 and dd > 0.35:
						col = Color("b8b8c4") if (i % 2 == 0) else Color("7a7a88")
			img.set_pixel(x, y, col)
	for q in [Vector2(16, 18), Vector2(23, 18)]:
		img.set_pixel(int(q.x), int(q.y), Color("ff5a3a"))
		img.set_pixel(int(q.x) + 1, int(q.y), Color("ff5a3a"))
	return ImageTexture.create_from_image(img)


## 無盡模式：from 秒之後，每分鐘依 growth 複利變強
func _endless_mult(kind: String) -> float:
	if not endless or t <= float(D.endless.from):
		return 1.0
	return pow(1.0 + float(D.endless.growth[kind]), (t - float(D.endless.from)) / 60.0)


## 下一隻 Boss 還有幾秒（-1：Boss 正在場上或都打完了）
func _boss_in() -> float:
	if boss != null or won:
		return -1.0
	if endless and t >= float(D.boss.at) - 30.0:
		return maxf(0.0, endless_boss_t - t)
	var mids: Array = D.boss.get("mid", [])
	if mids_done < mids.size() and float(mids[mids_done].at) < float(D.boss.at) - 30.0:
		return maxf(0.0, float(mids[mids_done].at) - t)
	return maxf(0.0, float(D.boss.at) - t) if not boss_spawned else -1.0


## hp_mult < 1：中途 Boss（打退了不算通關）
func _spawn_boss(hp_mult := 1.0, keep_going := false) -> void:
	var mid := hp_mult < 1.0 or keep_going
	if not mid:
		boss_spawned = true
	var B: Dictionary = D.boss
	var s := Sprite2D.new()
	s.texture = _boss_tex()
	var own_art := ResourceLoader.exists("res://assets/sprites/boss_%s.png" % stage.id)
	s.centered = false
	s.offset = Vector2(-20, -30)
	world.add_child(s)
	boss = {"type": "boss", "boss": true, "d": {"name": B.name, "damage": B.touch_damage}, "pos": _edge_point(-30.0),
		"hp": float(B.hp) * hp_mult, "max_hp": float(B.hp) * hp_mult, "mid": mid, "ph": 0.0, "flash": 0.0, "stun": 0.0, "cd": 0.0, "bcd": 0.0, "r": 14.0,
		"sprite": "boss", "tint": Color(B.tint[0], B.tint[1], B.tint[2]) if B.has("tint") and not own_art else Color.WHITE, "dmul": 1.0, "smul": 1.0, "knock": Vector2.ZERO, "dead": false, "node": s,
		"state": "move", "timer": 2.5, "pattern_i": 0, "pattern": ""}
	enemies.append(boss)
	ui.show_banner(("Boss 來襲：" if mid else "Boss：") + B.name, 2.5)
	if fever <= 0.0:
		Sfx.music("boss")


func _update_boss(b: Dictionary, dt: float) -> void:
	var B: Dictionary = D.boss
	var phase2: bool = b.hp < b.max_hp * B.phase2_at
	b.flash = maxf(0.0, b.flash - dt)
	b.knock = Vector2.ZERO
	match b.state:
		"move":
			b.pos += (paul.pos - b.pos).normalized() * B.speed * (1.6 if phase2 else 1.0) * dt
			b.timer -= dt
			if b.timer <= 0.0:
				var order: Array = B.get("order", ["sweep", "slam", "grid", "hunt"])
				b.pattern = order[b.pattern_i % order.size()]
				b.pattern_i += 1
				tele = _make_tele(b)
				Sfx.play("warn", 0.0)
				b.state = "warn"
				b.timer = B.warn * (0.7 if phase2 else 1.0)
		"warn":
			b.timer -= dt
			if b.timer <= 0.0:
				_resolve_tele()
				tele = []
				if b.pattern == "summon":
					_boss_summon(b)
				if b.pattern == "slam" or b.pattern == "grid":
					b.state = "break"
					b.timer = B.break_seconds
					ui.show_banner("破口！", 1.0)
				else:
					b.state = "move"
					b.timer = 1.0 if phase2 else 1.6
		"break":
			b.timer -= dt
			if b.timer <= 0.0:
				b.state = "move"
				b.timer = 1.0 if phase2 else 1.4
	if paul.pos.distance_to(b.pos) < b.r and paul.inv <= 0.0:
		_damage_paul(B.touch_damage)


func _make_tele(b: Dictionary) -> Array:
	var B: Dictionary = D.boss
	var out := []
	match b.pattern:
		"sweep":
			var dir: Vector2 = (paul.pos - b.pos).normalized()
			out.append({"kind": "line", "a": b.pos - dir * 20.0, "b": b.pos + dir * B.sweep.length, "w": float(B.sweep.width), "dmg": float(B.sweep.damage)})
		"grid":
			var v := _view_rect().grow(40.0)
			var n := int(B.grid.lines)
			for i in n:
				var off := (i - (n - 1) / 2.0) * 70.0
				var x: float = paul.pos.x + off + randf_range(-10, 10)
				var y: float = paul.pos.y + off + randf_range(-10, 10)
				out.append({"kind": "line", "a": Vector2(x, v.position.y), "b": Vector2(x, v.end.y), "w": float(B.grid.width), "dmg": float(B.grid.damage)})
				out.append({"kind": "line", "a": Vector2(v.position.x, y), "b": Vector2(v.end.x, y), "w": float(B.grid.width), "dmg": float(B.grid.damage)})
		"slam":
			# 懲罰聚集：砸隊伍中心
			var sum: Vector2 = paul.pos
			var n := 1
			for c in comps:
				if _active(c):
					sum += c.pos
					n += 1
			out.append({"kind": "circle", "c": sum / n, "r": float(B.slam.radius), "dmg": float(B.slam.damage)})
		"hunt":
			# 懲罰分散：鎖定離保羅最遠的兩個同伴
			var list := []
			for c in comps:
				if c.level > 0 and c.down <= 0.0:
					list.append(c)
			list.sort_custom(func(a, c2): return a.pos.distance_to(paul.pos) > c2.pos.distance_to(paul.pos))
			for i in mini(2, list.size()):
				out.append({"kind": "circle", "c": list[i].pos, "r": float(B.hunt.radius), "dmg": float(B.hunt.damage)})
			if out.is_empty():
				out.append({"kind": "circle", "c": paul.pos, "r": float(B.hunt.radius), "dmg": float(B.hunt.damage)})
	return out


## 城市 Boss 的招式：召喚一圈那座城的敵人
func _boss_summon(b: Dictionary) -> void:
	var sm: Dictionary = D.boss.summon
	ui.show_banner("%s召來了%s" % [D.boss.name, D.enemies[sm.type].name], 1.2)
	_ring_pop(b.pos, C_VL, 40.0)
	for i in int(sm.count):
		var a := i * TAU / float(sm.count)
		_spawn_one(sm.type, b.pos + Vector2(cos(a), sin(a) * 0.8) * 30.0)


func _in_shape(sh: Dictionary, pt: Vector2) -> bool:
	if sh.kind == "line":
		var q := Geometry2D.get_closest_point_to_segment(pt, sh.a, sh.b)
		return pt.distance_to(q) < sh.w / 2.0 + 3.0
	return pt.distance_to(sh.c) < sh.r


func _resolve_tele() -> void:
	shake = 0.3
	for sh in tele:
		hits.append({"sh": sh, "t": 0.0})
		if _in_shape(sh, paul.pos + Vector2(0, -6)) and paul.inv <= 0.0:
			_damage_paul(sh.dmg)
		for c in comps:
			if c.level > 0 and c.down <= 0.0 and _in_shape(sh, c.pos + Vector2(0, -6)):
				if fever <= 0.0:
					c.hurt_cd = 0.0
					_damage_companion(c, sh.dmg)
				var center: Vector2 = sh.c if sh.kind == "circle" else Geometry2D.get_closest_point_to_segment(c.pos, sh.a, sh.b)
				c.vel += (c.pos - center).normalized() * 80.0


## 每局結束寫一筆紀錄到本機，之後拿來看哪個流派太強或太弱
func _record_run() -> void:
	var path := "user://runs.json"
	var runs: Array = []
	if FileAccess.file_exists(path):
		var old = JSON.parse_string(FileAccess.get_file_as_string(path))
		if old is Array:
			runs = old
	var party := {}
	for c in comps:
		if c.level > 0 and c.follows == "":
			party[c.key] = c.level
	runs.append({"date": Time.get_datetime_string_from_system(), "won": won, "seconds": int(t), "level": level,
		"kills": kills, "party": party, "fruits": fruits, "armor": armor, "evolved": evolved.keys(),
		"scattered_by": scatter_by, "boss_hp_left": (boss.hp / boss.max_hp) if boss != null and not boss.dead else 0.0})
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(runs, "  "))


## 結算：交給存檔算見證、默契、見證錄，回傳要顯示的幾行
func _finish_run() -> Array:
	var party := {}
	for c in comps:
		if c.level > 0 and c.follows == "":
			party[c.key] = c.level
	var res: Dictionary = Save.finish_run({"kills": kills, "seconds": int(t - t_start), "level": level, "won": won,
		"elites": run_elites, "fevers": run_fevers, "evolutions": run_evolutions, "tasks_done": tasks_done,
		"task_witness": task_witness, "lights": run_lights, "bread": run_bread,
		"resonances": run_resonances, "midbosses": run_midboss, "chests": run_chests, "links": link_count,
		"combo": combo_best, "party_size": _party_count(), "endless": endless, "sets": sets_on.size(), "leader": leader,
		"trial_points": Save.trial_points(trials), "stage": stage.id,
		"seen": {"enemies": killed_types.keys().map(func(k): return k.replace("pride_small", "pride")), "evos": evolved.keys(), "fruits": fruits.keys(), "armor": armor.keys()}, "no_down": t - t_start >= 210.0 and not someone_down, "full_party": full_party, "party": party})
	var lines := [["帶回見證 +%d　（共 %d）　餅 +%d" % [res.witness, Save.data.witness, res.bread], 15, C_SKY]]
	if not trials.is_empty():
		lines.append(["熬煉 %d 點：見證與餅已加成" % Save.trial_points(trials), 11, C_GOLD])
	for a in res.achievements:
		var txt: String = "見證錄：" + a.name
		if a.has("unlock"):
			txt += "　→　%s 加入名單！" % _comp_name(a.unlock)
		lines.append([txt, 13, C_GOLD])
	if not res.affinity_ups.is_empty():
		var names := []
		for k in res.affinity_ups:
			names.append(_comp_name(k))
		var rows := []
		for i in range(0, names.size(), 3):
			rows.append("、".join(names.slice(i, i + 3)))
		lines.append(["默契提升：" + "\n".join(rows) + "（解鎖新的生平）", 12, C_HEAL])
	return lines


func _comp_name(key: String) -> String:
	for d in D.companions:
		if d.key == key:
			return d.name
	return key


func _win() -> void:
	if won:
		return
	if not Save.data.churches.has(stage.id):
		Save.data.churches.append(stage.id)
		founded_now = true
	Sfx.music("")
	Sfx.play("win", 0.0)
	Sfx.buzz(250)
	won = true
	over = true
	_record_run()
	tele = []
	joy.on = false
	ui.joy.on = false
	shake = 0.5
	ui.do_flash(0.8)
	var s := int(t)
	var lines := [
		["%s　教會建立！" % stage.name if founded_now else "%s　通關" % stage.name, 26, C_GOLD],
		[D.boss.win_text, 13, C_CREAM],
		[D.boss.win_ref, 11, Color("c9a46b")],
		["用時 %02d:%02d　Lv.%d　驅散 %d" % [s / 60, s % 60, level, kills], 13, Color("f4ead2")],
	]
	if founded_now:
		var nxt := ""
		var all := _stage_list()
		if stage_i + 1 < all.size():
			nxt = "　下一站：" + all[stage_i + 1].name
		lines.append(["解鎖書信卡「%s」%s" % [stage.epistle.name, nxt], 12, C_HEAL])
	ui.show_game_over(lines + _finish_run(), "再走一次", true)


# ---------- 失敗 ----------
func _game_over() -> void:
	Sfx.music("")
	Sfx.play("lose", 0.0)
	over = true
	joy.on = false
	ui.joy.on = false
	paul.node.modulate = Color(0.5, 0.5, 0.5)
	var who := "—"
	var best := 0
	for k in scatter_by:
		if scatter_by[k] > best:
			best = scatter_by[k]
			who = D.enemies[k].name
	var s := int(t)
	tele = []
	_record_run()
	# 失敗彩蛋：第一次失敗必定出現，之後偶爾出現；不給任何資源
	var summary := _finish_run()
	var first: bool = not Save.data.egg_seen
	if (first and D.easter_egg.first_time) or randf() < D.easter_egg.chance:
		if first:
			Save.data.egg_seen = true
			Save.data.baskets = maxi(1, int(Save.data.baskets))
			Save.save_profile()
		await ui.play_egg(int(Save.data.baskets), ui.get_viewport().get_canvas_transform() * paul.pos)
	ui.show_game_over([
		["旅程中斷", 26, C_GOLD],
		["四面受敵，卻不被困住；心裡作難，卻不至失望；\n遭逼迫，卻不被丟棄；打倒了，也不至死亡。", 13, C_CREAM],
		["林後 4:8–9", 11, Color("c9a46b")],
		["撐了 %02d:%02d　Lv.%d　驅散 %d\n最常被「%s」打散" % [s / 60, s % 60, level, kills, who], 13, Color("f4ead2")],
	] + summary)


# ---------- 自動測試 ----------
func _smoke_tick() -> void:
	smoke_frames += 1
	if chest_open and smoke_frames % 40 == 0:
		if smoke_shot != "" and not FileAccess.file_exists(smoke_shot.replace(".png", "_chest.png")):
			get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_chest.png"))
		ui._close_chest()
	if over and smoke_shot != "":
		smoke_over += 1
		if smoke_over == 170:
			get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_egg.png"))
		if smoke_over == 900:
			get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_over.png"))
			print("SMOKE DONE (over) t=%.1f won=%s" % [t, won])
			get_tree().quit()
		return
	if smoke_shot != "" and tele.size() > 0 and smoke_frames % 10 == 5 and not FileAccess.file_exists(smoke_shot.replace(".png", "_tele.png")):
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_tele.png"))
	if smoke_shot != "" and not quakes.is_empty() and not FileAccess.file_exists(smoke_shot.replace(".png", "_quake.png")):
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_quake.png"))
	if smoke_shot != "" and resonances.any(func(rz): return rz.r > 40.0 and rz.r < 90.0) and not FileAccess.file_exists(smoke_shot.replace(".png", "_reso.png")):
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_reso.png"))
	if smoke_shot != "" and link_fx.any(func(f): return f.depth >= 2 and f.t > 0.05 and f.t < 0.15) and not FileAccess.file_exists(smoke_shot.replace(".png", "_link.png")):
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_link.png"))
	if choosing and smoke_frames % 20 == 0:
		ui.card_ready_at = 0.0
		if smoke_shot != "" and not FileAccess.file_exists(smoke_shot.replace(".png", "_cards.png")):
			get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_cards.png"))
		ui.pick(randi() % pending_cards.size())
	if meter >= 1.0 and fever <= 0.0 and not smoke_nofever:
		_start_fever()
	if smoke_frames % 300 == 0:
		var party := []
		for c in comps:
			if c.level > 0:
				party.append("%s%d" % [c.key, c.level])
		print("links fired=%d combo=%d best=%d" % [link_count, combo, combo_best])
		print("t=%.1f hp=%.0f Lv=%d enemies=%d kills=%d fever=%.1f boss=%s party=%s fruits=%s armor=%s evo=%s" % [t, paul.hp, level, enemies.size(), kills, fever,
			("%.0f/%s" % [boss.hp, boss.state]) if boss != null else "-", party, fruits, armor, evolved.keys()])
	if smoke_shot != "" and fever > 0.0 and fever < D.fever.duration - 1.5 and not FileAccess.file_exists(smoke_shot.replace(".png", "_fever.png")):
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_fever.png"))
	if smoke_shot != "" and smoke_frames == 1500 and not FileAccess.file_exists(smoke_shot.replace(".png", "_pause.png")):
		_set_paused(true)
	if smoke_shot != "" and paused and smoke_frames == 1530:
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_pause.png"))
		_set_paused(false)
	if smoke_shot != "" and smoke_frames == 1700:
		get_viewport().get_texture().get_image().save_png(smoke_shot)
	if smoke_frames >= smoke_max_frames:
		print("SMOKE DONE t=%.1f fps=%d" % [t, Engine.get_frames_per_second()])
		get_tree().quit()
