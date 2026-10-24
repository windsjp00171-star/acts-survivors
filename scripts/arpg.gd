extends Node2D
## 宣教之路 2 試作：暗黑式的動作 RPG（彼得、耶路撒冷）
## 敵人是黑暗（懼怕、謊言、紛爭……），被牠們圍住、捆綁的是人；趕走黑暗，人就得自由，走回你的城。
## 城（被釋放的人、倉庫）整個帳號共用；開新角色時城還在（林前 3:6）。
## 倒下：裝備留在原地，空身從城裡出發去拿；城裡被釋放的人會陪你去（徒 14:20）。
## 操作：左鍵移動／攻擊、右鍵撒網（在游標處）、1～4 技能、Q 吃餅、E 喝水、I 背包、T 回城、空白鍵撿東西。

const SAVE_PATH := "user://arpg.json"
const C_GOLD := Color("ffd75e")
const C_CREAM := Color("fff4c2")
const C_INK := Color("f4ead2")
const C_RED := Color("e0503a")
const C_DARK := Color("2a1a30")
const C_MAGIC := Color("7aa8ff")
const C_UNIQUE := Color("c8a050")
const C_RUNE := Color("ffb040")
const C_RUNEWORD := Color("c8a050")

## 地圖：每一區的大小、出口、黑暗的群數、怪的等級
const ZONES := {
	"town": {"name": "耶路撒冷・所羅門的廊下", "size": Vector2(640, 420), "packs": 0, "lvl": 1,
		"exits": [{"to": "gate", "rect": Rect2(610, 170, 30, 80), "spawn": Vector2(40, 210), "label": "城門外 →"}]},
	"gate": {"name": "城門外", "size": Vector2(1100, 640), "packs": 6, "lvl": 1,
		"exits": [{"to": "town", "rect": Rect2(0, 280, 30, 80), "spawn": Vector2(580, 210), "label": "← 回城"},
			{"to": "alley", "rect": Rect2(1070, 280, 30, 80), "spawn": Vector2(40, 260), "label": "窄巷 →"}]},
	"alley": {"name": "窄巷", "size": Vector2(1200, 520), "packs": 7, "lvl": 4,
		"exits": [{"to": "gate", "rect": Rect2(0, 220, 30, 80), "spawn": Vector2(1040, 320), "label": "← 城門外"},
			{"to": "council", "rect": Rect2(1170, 220, 30, 80), "spawn": Vector2(60, 240), "label": "公會 →"}]},
	"council": {"name": "公會", "size": Vector2(700, 480), "packs": 0, "lvl": 7, "boss": true,
		"exits": [{"to": "alley", "rect": Rect2(0, 200, 30, 80), "spawn": Vector2(1120, 260), "label": "← 窄巷"}]},
}

## 黑暗（敵人）
const SPIRITS := {
	"fear": {"name": "懼怕", "hp": 22, "dmg": 4, "spd": 46, "range": 16, "cd": 1.0, "xp": 6, "tex": "fear"},
	"lies": {"name": "謊言", "hp": 16, "dmg": 3, "spd": 30, "range": 120, "cd": 2.0, "xp": 7, "tex": "lies", "shoot": true},
	"strife": {"name": "紛爭", "hp": 34, "dmg": 7, "spd": 34, "range": 90, "cd": 3.2, "xp": 9, "tex": "strife", "charge": true},
	"terror": {"name": "恐嚇", "hp": 140, "dmg": 10, "spd": 28, "range": 60, "cd": 4.0, "xp": 40, "tex": "terror", "roar": true, "elite": true},
	"council": {"name": "公會的恐嚇", "hp": 480, "dmg": 9, "spd": 26, "range": 70, "cd": 2.4, "xp": 300, "tex": "boss_jerusalem", "boss": true},
}

## 彼得的技能（等級到了才會）
const SKILLS := [
	{"id": "haul", "name": "撒網", "ref": "約 21:6", "lv": 1, "mp": 8, "cd": 3.0, "icon": "icon_haul",
		"desc": "在游標的地方撒網：網裡的黑暗被拉到中間、定住 1.5 秒"},
	{"id": "leap", "name": "跳在海裡", "ref": "約 21:7", "lv": 3, "mp": 12, "cd": 6.0, "icon": "icon_leap",
		"desc": "撲向游標（最遠 130）：落地的地方水花四濺，周圍的黑暗受重傷、被震開"},
	{"id": "rock", "name": "磐石", "ref": "太 16:18", "lv": 6, "mp": 15, "cd": 16.0, "icon": "icon_rock",
		"desc": "6 秒內受到的傷害減半，身邊的黑暗都衝著你來"},
	{"id": "fisher", "name": "得人如得魚", "ref": "路 5:10", "lv": 9, "mp": 10, "cd": 14.0, "icon": "icon_fisher",
		"desc": "8 秒內每趕走一個黑暗，回血、回靈力"},
]

## 裝備的底子
const BASES := {
	"weapon": [{"name": "漁夫的木槳", "min": 3, "max": 6, "lv": 1}, {"name": "牧人的杖", "min": 4, "max": 8, "lv": 3}, {"name": "鐵頭漁叉", "min": 6, "max": 11, "lv": 6}],
	"body": [{"name": "粗麻外衣", "armor": 4, "lv": 1}, {"name": "羊毛外衣", "armor": 8, "lv": 3}, {"name": "皮革外衣", "armor": 13, "lv": 6}],
	"feet": [{"name": "草鞋", "armor": 1, "lv": 1}, {"name": "皮鞋", "armor": 3, "lv": 4}],
	"belt": [{"name": "布腰帶", "armor": 1, "lv": 1}, {"name": "皮腰帶", "armor": 2, "lv": 4}],
}
const SLOT_NAME := {"weapon": "手上", "body": "外衣", "feet": "鞋", "belt": "腰帶"}
## 詞綴：前綴＋後綴，數值隨物品等級長
const AFFIXES := [
	{"id": "dmg", "name": "堅實的", "pos": "pre", "desc": "傷害 +%d%%", "min": 8, "max": 20, "per": 2.0, "slots": ["weapon", "belt"]},
	{"id": "life", "name": "活潑的", "pos": "pre", "desc": "生命 +%d", "min": 6, "max": 14, "per": 2.0, "slots": ["body", "belt", "feet", "weapon"]},
	{"id": "move", "name": "腳步快的", "pos": "suf", "desc": "移動 +%d%%", "min": 6, "max": 14, "per": 0.6, "slots": ["feet", "belt"]},
]
## 暗金（職業專屬）
const UNIQUES := [
	{"id": "peter_net", "slot": "weapon", "name": "彼得的網", "ref": "約 21:6", "min": 7, "max": 12, "lv": 1,
		"fx": {"dmg": 25, "net_big": 1}, "lines": ["傷害 +25%", "撒網範圍大一半、冷卻減半", "「把網撒在船的右邊，就必得著。」"]},
]
## 符文（希臘字母）與符文之語（新約的希臘文字）
const RUNES := {"Φ": {"name": "Φ（Phi）", "drop": 0.05}, "Ω": {"name": "Ω（Omega）", "drop": 0.03}, "Σ": {"name": "Σ（Sigma）", "drop": 0.04}}
const RUNEWORDS := [
	{"word": "ΦΩΣ", "slot": "weapon", "name": "光", "ref": "約 8:12",
		"lines": ["ΦΩΣ 是新約希臘文的「光」", "傷害 +40%", "每第 3 下攻擊，往前射出一道光（穿透）", "「我是世界的光。跟從我的，就不在黑暗裡走。」"],
		"fx": {"dmg": 40, "light": 1}},
]
## 被釋放的人說的話（第一次見面時）
const FREED_LINES := ["我被懼怕綁了好多年……今天第一次覺得可以呼吸。", "原來我不是一個人。", "他們說我沒救了。你們卻來找我。",
	"謊言在我耳邊說了一輩子，現在安靜了。", "我想跟你們回去，看看你們的教會。", "我家門口那條巷子，以後我來守。",
	"我會打鐵。城裡需要人手嗎？", "我想學怎麼禱告。", "我以前是跟著拿石頭的那群人……可以重新開始嗎？", "謝謝你沒有放棄我。"]

var zone := "town"
var P := {}                 # 玩家
var mobs: Array = []        # 黑暗 {key, pos, hp, hpmax, dmg, spd, cd, wind, pack, stun, hit_t, vel, shots}
var packs: Array = []       # 被捆綁的人 {pos, alive(黑暗數), freed, tint, line, t}
var walkers: Array = []     # 被釋放、正在走回城的人
var drops: Array = []       # 地上的東西 {pos, item}
var shots: Array = []       # 謊言吐出來的 {pos, vel, dmg, life}
var fxs: Array = []         # 特效 {kind, pos, r, t, max, ...}
var floats: Array = []      # 傷害數字 {pos, text, col, t}
var escorts: Array = []     # 陪你去撿屍體的人
var obstacles: Array = []   # {rect, tex, at}
var town: Dictionary = {}   # 帳號共用：freed[], stash[], chars
var corpse: Dictionary = {} # {zone, pos, equip}
var tex_cache := {}
var t := 0.0
var msg := ""
var msg_t := 0.0
var move_target := Vector2.INF
var attack_target = null
var attack_cd := 0.0
var swing_n := 0
var cam: Camera2D
var ui: CanvasLayer
var hud: Control
var inv_panel: PanelContainer
var inv_open := false
var inv_sel := -1           # 背包選到的第幾件（-1 = 沒有）
var inv_sel_equip := ""     # 選到的裝備欄
var talk_t := 0.0
var talk_text := ""
var smoke := false
var bot := false
var smoke_frames := 0
var smoke_max := 3000
var smoke_shot := ""
var stats := {"kills": 0, "freed": 0, "deaths": 0, "drops": 0, "zones": {}}
var bot_goal := ""
var full_warn_t := 0.0


# ---------------------------------------------------------------- 開始
func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for a in OS.get_cmdline_user_args():
		if a == "--smoke":
			smoke = true
		elif a == "--bot":
			bot = true
			Engine.time_scale = 3.0
		elif a.begins_with("--frames="):
			smoke_max = int(a.substr(9))
		elif a.begins_with("--shot="):
			smoke_shot = a.substr(7)
	cam = Camera2D.new()
	add_child(cam)
	cam.zoom = Vector2(2, 2)   # 靠近一點看：人物大、黑暗看得清楚（像暗黑的視角）
	cam.make_current()
	_build_ui()
	_load()
	if smoke and OS.get_cmdline_user_args().has("--fresh"):
		town = {"freed": [], "stash": [], "chars": 1}
		corpse = {}
		_new_char()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lv="):
			P.lv = int(a.substr(5))   # 測試：直接從這個等級開始
			_recalc()
			P.hp = P.hpmax
		elif a.begins_with("--start="):
			zone = a.substr(8)   # 測試：直接從這一區開始
			P.pos = Vector2(60, 240)
	_enter(zone, P.pos if P.has("pos") else Vector2(320, 260))
	_say("宣教之路 2 試作：左鍵走路、攻擊；右鍵撒網；Q 吃餅、E 喝水；I 背包；T 回城", 5.0)
	if Sfx.has_method("music"):
		Sfx.music("jerusalem")


func _new_char() -> void:
	P = {"name": "彼得", "lv": 1, "xp": 0, "hp": 60.0, "mp": 30.0, "pos": Vector2(320, 260), "face": 1, "bread": 3, "water": 2,
		"equip": {"weapon": {}, "body": {}, "feet": {}, "belt": {}}, "bag": [], "cds": {}, "buffs": {}}
	P.equip.weapon = _make_base("weapon", 0, 1)
	P.equip.body = _make_base("body", 0, 1)
	zone = "town"
	_recalc()
	P.hp = P.hpmax
	P.mp = P.mpmax


# ---------------------------------------------------------------- 存檔
func _save() -> void:
	if smoke:
		return
	var d := {"ver": 1, "zone": "town" if zone != "town" else zone, "P": _ser_p(), "town": town, "corpse": _ser_corpse()}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func _ser_p() -> Dictionary:
	var p: Dictionary = P.duplicate(true)
	p.pos = [P.pos.x, P.pos.y]
	p.erase("cds")
	p.erase("buffs")
	return p


func _ser_corpse() -> Dictionary:
	if corpse.is_empty():
		return {}
	var c: Dictionary = corpse.duplicate(true)
	c.pos = [corpse.pos.x, corpse.pos.y]
	return c


func _load() -> void:
	town = {"freed": [], "stash": [], "chars": 1}
	if smoke or not FileAccess.file_exists(SAVE_PATH):
		_new_char()
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not d is Dictionary or not d.has("P"):
		_new_char()
		return
	town = d.town
	P = d.P
	P.pos = Vector2(P.pos[0], P.pos[1])
	P.cds = {}
	P.buffs = {}
	P.lv = int(P.lv)
	corpse = d.get("corpse", {})
	if not corpse.is_empty():
		corpse.pos = Vector2(corpse.pos[0], corpse.pos[1])
	zone = "town"
	P.pos = Vector2(320, 260)
	_recalc()


# ---------------------------------------------------------------- 物品
func _make_base(slot: String, idx: int, ilvl: int) -> Dictionary:
	var B: Dictionary = BASES[slot][idx]
	var it := {"slot": slot, "base": B.name, "name": B.name, "rarity": "normal", "ilvl": ilvl, "mods": {}, "sockets": 0, "runes": []}
	if B.has("min"):
		it.min = int(B.min)
		it.max = int(B.max)
	if B.has("armor"):
		it.armor = int(B.armor)
	return it


func _roll_item(ilvl: int, boss := false) -> Dictionary:
	# 暗金：職業專屬，Boss 掉的機會高
	if randf() < (0.22 if boss else 0.012):
		var U: Dictionary = UNIQUES.pick_random()
		var u := {"slot": U.slot, "base": U.name, "name": U.name, "rarity": "unique", "uid": U.id, "ilvl": ilvl, "mods": U.fx.duplicate(),
			"sockets": 0, "runes": [], "min": int(U.min) + ilvl / 2, "max": int(U.max) + ilvl, "lines": U.lines, "ref": U.ref}
		return u
	var slot: String = ["weapon", "body", "feet", "belt"].pick_random()
	var cands := []
	for i in BASES[slot].size():
		if int(BASES[slot][i].lv) <= ilvl + 1:
			cands.append(i)
	var it := _make_base(slot, cands.pick_random(), ilvl)
	if it.has("min"):
		it.min = int(it.min) + ilvl / 3
		it.max = int(it.max) + ilvl / 2
	if randf() < (0.6 if boss else 0.34):
		# 魔法（藍色）：一到兩個詞綴
		it.rarity = "magic"
		var pool := AFFIXES.filter(func(A): return A.slots.has(slot))
		pool.shuffle()
		var pre := ""
		var suf := ""
		for k in mini(pool.size(), randi_range(1, 2)):
			var A: Dictionary = pool[k]
			var v := randi_range(int(A.min), int(A.max)) + int(ilvl * float(A.per) * 0.5)
			it.mods[A.id] = v
			if A.pos == "pre":
				pre = A.name
			else:
				suf = A.name
		it.name = pre + suf + it.base if pre != "" or suf != "" else it.base
	elif slot == "weapon" or slot == "body":
		# 普通（白色）：可能有孔，可以鑲符文
		if randf() < 0.45:
			it.sockets = randi_range(1, 3)
			it.name = "有 %d 個孔的%s" % [it.sockets, it.base]
	return it


func _rune_item(letter: String) -> Dictionary:
	return {"slot": "rune", "rarity": "rune", "letter": letter, "name": "符文 " + RUNES[letter].name, "base": "符文"}


func _item_color(it: Dictionary) -> Color:
	match str(it.get("rarity", "normal")):
		"magic": return C_MAGIC
		"unique": return C_UNIQUE
		"rune": return C_RUNE
		"runeword": return C_RUNEWORD
	return C_INK


func _item_lines(it: Dictionary) -> Array:
	var L := [it.name]
	if it.rarity == "rune":
		L.append("鑲進有孔的裝備（照順序拼字）")
		L.append("例：Φ Ω Σ 鑲進有 3 個孔的武器 → 「光」")
		return L
	L.append(SLOT_NAME.get(it.slot, ""))
	if it.has("min"):
		L.append("傷害 %d～%d" % [int(it.min), int(it.max)])
	if it.has("armor"):
		L.append("防護 %d" % int(it.armor))
	if it.rarity == "unique" or it.rarity == "runeword":
		for l in it.get("lines", []):
			L.append(l)
	else:
		for A in AFFIXES:
			if it.mods.has(A.id):
				L.append(A.desc % int(it.mods[A.id]))
	if int(it.get("sockets", 0)) > 0:
		var s := ""
		for i in int(it.sockets):
			s += (str(it.runes[i]) if i < it.runes.size() else "○") + " "
		L.append("孔：" + s)
	return L


## 鑲符文：照順序鑲滿、拼成符文之語時，整件變成那個字
func _socket(it: Dictionary, letter: String) -> bool:
	if int(it.get("sockets", 0)) <= it.runes.size() or it.rarity == "runeword":
		return false
	it.runes.append(letter)
	if it.runes.size() == int(it.sockets):
		var w := "".join(it.runes)
		for RW in RUNEWORDS:
			if RW.word == w and RW.slot == it.slot:
				it.rarity = "runeword"
				it.name = "%s（%s）" % [RW.name, RW.word]
				it.lines = RW.lines
				it.mods = RW.fx.duplicate()
				_say("符文之語！%s ── %s（%s）" % [RW.word, RW.name, RW.ref], 4.0)
				Sfx.play("evolve", 0.0)
				_ring(P.pos, C_GOLD, 60.0)
	return true


# ---------------------------------------------------------------- 角色數值
func _recalc() -> void:
	var lv := int(P.lv)
	var life := 70.0 + lv * 10.0
	var dmgp := 0.0
	var move := 0.0
	var armor := 0.0
	var wmin := 2.0
	var wmax := 4.0
	P.fx = {}
	for s in P.equip:
		var it: Dictionary = P.equip[s]
		if it.is_empty():
			continue
		if it.has("min"):
			wmin = float(it.min)
			wmax = float(it.max)
		armor += float(it.get("armor", 0))
		life += float(it.mods.get("life", 0))
		dmgp += float(it.mods.get("dmg", 0))
		move += float(it.mods.get("move", 0))
		for k in it.mods:
			if k in ["net_big", "light"]:
				P.fx[k] = true
	P.hpmax = life
	P.mpmax = 25.0 + lv * 5.0
	P.dmin = (wmin + lv * 0.8) * (1.0 + dmgp / 100.0)
	P.dmax = (wmax + lv * 1.2) * (1.0 + dmgp / 100.0)
	P.armor = armor
	P.speed = 70.0 * (1.0 + move / 100.0)
	P.hp = minf(float(P.get("hp", life)), life)
	P.mp = minf(float(P.get("mp", P.mpmax)), P.mpmax)


func _xp_need(lv: int) -> int:
	return int(40.0 * pow(lv, 1.55))


func _gain_xp(n: int) -> void:
	P.xp = int(P.xp) + n
	while int(P.xp) >= _xp_need(int(P.lv)):
		P.xp = int(P.xp) - _xp_need(int(P.lv))
		P.lv = int(P.lv) + 1
		_recalc()
		P.hp = P.hpmax
		P.mp = P.mpmax
		_ring(P.pos, C_GOLD, 40.0)
		Sfx.play("levelup", 0.0)
		var learned := ""
		for S in SKILLS:
			if int(S.lv) == int(P.lv):
				learned = "　學會「%s」（%s）" % [S.name, S.ref]
		_say("升到 Lv%d%s" % [int(P.lv), learned], 3.0)


# ---------------------------------------------------------------- 地圖
func _enter(z: String, at: Vector2) -> void:
	zone = z
	P.pos = at
	mobs.clear()
	packs.clear()
	drops.clear()
	shots.clear()
	fxs.clear()
	walkers.clear()
	move_target = Vector2.INF
	attack_target = null
	_build_obstacles()
	var Z: Dictionary = ZONES[z]
	stats.zones[z] = int(stats.zones.get(z, 0)) + 1
	# 每次進來，黑暗又把人圍住了（可以一直回來刷）
	for i in int(Z.packs):
		var pp := _free_spot(Vector2(140, 60), Z.size - Vector2(80, 60))
		_spawn_pack(pp, int(Z.lvl), z == "alley" and i == int(Z.packs) - 1)
	if Z.get("boss", false):
		var bp := Vector2(Z.size.x * 0.65, Z.size.y * 0.5)
		packs.append({"pos": bp + Vector2(60, 0), "alive": 1, "freed": false, "tint": _tint(), "line": "公會裡的一位年輕人：「我一直以為……他們說的就是對的。」", "boss": true})
		_spawn_mob("council", bp, packs.size() - 1, int(Z.lvl))
	if z == "town":
		_say("耶路撒冷・所羅門的廊下：被釋放的人 %d 位" % town.freed.size(), 3.0)
		P.hp = P.hpmax
		P.mp = P.mpmax
	else:
		_say(Z.name, 2.0)
	cam.limit_left = -40
	cam.limit_top = -40
	cam.limit_right = int(Z.size.x) + 40
	cam.limit_bottom = int(Z.size.y) + 40
	cam.position = P.pos
	cam.reset_smoothing()


func _tint() -> Color:
	return Color.from_hsv(randf(), randf_range(0.1, 0.35), randf_range(0.8, 1.0))


func _free_spot(lo: Vector2, hi: Vector2) -> Vector2:
	for k in 30:
		var p := Vector2(randf_range(lo.x, hi.x), randf_range(lo.y, hi.y))
		var ok := true
		for o in obstacles:
			if (o.rect as Rect2).grow(30).has_point(p):
				ok = false
		for pk in packs:
			if p.distance_to(pk.pos) < 120:
				ok = false
		if ok:
			return p
	return Vector2(randf_range(lo.x, hi.x), randf_range(lo.y, hi.y))


func _spawn_pack(at: Vector2, lvl: int, elite: bool) -> void:
	packs.append({"pos": at, "alive": 0, "freed": false, "tint": _tint(), "line": FREED_LINES.pick_random()})
	var pi := packs.size() - 1
	var n := randi_range(3, 6)
	if elite:
		_spawn_mob("terror", at + Vector2(0, -24), pi, lvl + 1)
		n = 4
	for i in n:
		var k: String = ["fear", "fear", "lies", "strife"].pick_random()
		_spawn_mob(k, at + Vector2.from_angle(i * TAU / n) * randf_range(26, 40), pi, lvl)


func _spawn_mob(key: String, at: Vector2, pack: int, lvl: int) -> void:
	var S: Dictionary = SPIRITS[key]
	var k := (1.0 + (lvl - 1) * 0.28) * 1.3
	var hp := float(S.hp) * k
	mobs.append({"key": key, "pos": at, "home": at, "hp": hp, "hpmax": hp, "dmg": float(S.dmg) * (1.0 + (lvl - 1) * 0.2) * 1.3, "spd": float(S.spd),
		"cd": randf_range(0.5, 1.5), "wind": 0.0, "pack": pack, "stun": 0.0, "hit_t": 0.0, "lvl": lvl, "aggro": false, "vel": Vector2.ZERO,
		"phase": 0, "dead": false})
	packs[pack].alive = int(packs[pack].alive) + 1


func _build_obstacles() -> void:
	obstacles.clear()
	var Z: Dictionary = ZONES[zone]
	var sz: Vector2 = Z.size
	match zone:
		"town":
			_obs("lm_colonnade", Vector2(320, 70))
			_obs("well", Vector2(320, 300))
			_obs("house", Vector2(90, 110))
			_obs("redhouse", Vector2(540, 110))
			_obs("camp_forge", Vector2(170, 380))   # 工匠
			_obs("camp_tent_small", Vector2(470, 390))
			_obs("stall", Vector2(230, 200))
			_obs("stall", Vector2(420, 200))
			_obs("amphora", Vector2(250, 206))
			_obs("lantern", Vector2(270, 290))
			_obs("lantern", Vector2(370, 290))
			_obs("column_1", Vector2(200, 130))
			_obs("column_1", Vector2(440, 130))
		"gate":
			_obs("lm_gate_jerusalem", Vector2(60, 220))
			for i in 9:
				_obs(["olive_1", "tree_1", "house", "stones", "wall_1"].pick_random(), Vector2(randf_range(160, sz.x - 120), randf_range(60, sz.y - 40)))
		"alley":
			# 窄巷：兩排房子夾出一條彎彎的路
			for i in 9:
				var x := 120.0 + i * 120.0
				_obs(["house", "redhouse", "wall_1"].pick_random(), Vector2(x, 70 + (i % 2) * 40))
				_obs(["house", "redhouse", "wall_2"].pick_random(), Vector2(x + 50, sz.y - 40 - (i % 3) * 30))
		"council":
			for i in 6:
				_obs("column_1", Vector2(150 + i * 90, 70))
				_obs("column_1", Vector2(150 + i * 90, sz.y - 30))


func _obs(texk: String, foot: Vector2) -> void:
	var tx := _tex(texk)
	if tx == null:
		return
	var w := float(tx.get_width())
	var h := float(tx.get_height())
	# 碰撞只算底下那一條（人可以走到房子前面）
	obstacles.append({"tex": texk, "at": foot - Vector2(w / 2.0, h), "rect": Rect2(foot.x - w * 0.42, foot.y - minf(h * 0.45, 14.0), w * 0.84, minf(h * 0.45, 14.0))})


func _tex(k: String) -> Texture2D:
	if not tex_cache.has(k):
		var p := "res://assets/sprites/%s.png" % k
		tex_cache[k] = load(p) if ResourceLoader.exists(p) else null
	return tex_cache[k]


func _collide(p: Vector2, r: float) -> Vector2:
	var sz: Vector2 = ZONES[zone].size
	p.x = clampf(p.x, 8.0, sz.x - 8.0)
	p.y = clampf(p.y, 16.0, sz.y - 6.0)
	for o in obstacles:
		var R: Rect2 = o.rect
		var q := Vector2(clampf(p.x, R.position.x, R.end.x), clampf(p.y, R.position.y, R.end.y))
		var d := p - q
		if d.length() < r:
			if d.length() < 0.01:
				d = Vector2(0, 1) if p.y > R.get_center().y else Vector2(0, -1)
				p = q + d * r
			else:
				p = q + d.normalized() * r
	return p


# ---------------------------------------------------------------- 每一格
func _process(dt: float) -> void:
	t += dt
	msg_t -= dt
	talk_t -= dt
	if smoke:
		_smoke_tick()
	if bot:
		_bot(dt)
	_update_player(dt)
	_update_mobs(dt)
	_update_misc(dt)
	cam.position = cam.position.lerp(P.pos, minf(1.0, dt * 8.0))
	queue_redraw()
	hud.queue_redraw()


func _update_player(dt: float) -> void:
	if float(P.hp) <= 0.0:
		return
	attack_cd -= dt
	for k in P.cds.keys():
		P.cds[k] = float(P.cds[k]) - dt
	for k in P.buffs.keys():
		P.buffs[k] = float(P.buffs[k]) - dt
		if P.buffs[k] <= 0.0:
			P.buffs.erase(k)
	P.mp = minf(float(P.mpmax), float(P.mp) + dt * (1.5 + int(P.lv) * 0.15))
	if float(P.buffs.get("bread", 0.0)) > 0.0:
		P.hp = minf(float(P.hpmax), float(P.hp) + float(P.hpmax) * 0.5 / 3.0 * dt)
	if float(P.buffs.get("water", 0.0)) > 0.0:
		P.mp = minf(float(P.mpmax), float(P.mp) + float(P.mpmax) * 0.6 / 3.0 * dt)
	P.hp = minf(float(P.hpmax), float(P.hp) + dt * 0.4)
	if inv_open:
		return
	# 鍵盤走路
	var kv := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if Input.is_physical_key_pressed(KEY_A): kv.x -= 1
	if Input.is_physical_key_pressed(KEY_D): kv.x += 1
	if Input.is_physical_key_pressed(KEY_W): kv.y -= 1
	if Input.is_physical_key_pressed(KEY_S): kv.y += 1
	if kv.length() > 0.1:
		move_target = Vector2.INF
		attack_target = null
		_step(kv.normalized(), dt)
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not bot and get_viewport().get_mouse_position().y < get_viewport_rect().size.y - 48.0:
		_click(get_global_mouse_position(), false)
	# 攻擊目標
	if attack_target != null:
		var m: Dictionary = attack_target
		if m.dead:
			attack_target = null
		else:
			var d: float = P.pos.distance_to(m.pos)
			if d > 22.0 + (14.0 if SPIRITS[m.key].get("boss", false) else 0.0):
				_step((m.pos - P.pos).normalized(), dt)
			elif attack_cd <= 0.0:
				_swing(m)
	elif move_target != Vector2.INF:
		var to: Vector2 = move_target - P.pos
		if to.length() < 3.0:
			move_target = Vector2.INF
		else:
			_step(to.normalized(), dt)
	# 出口
	for ex in ZONES[zone].exits:
		if (ex.rect as Rect2).has_point(P.pos):
			_enter(ex.to, ex.spawn)
			_save()
			return
	# 撿屍體
	if not corpse.is_empty() and corpse.zone == zone and P.pos.distance_to(corpse.pos) < 16.0:
		_take_corpse()
	# 自動撿符文、靠近的裝備按空白鍵（機器人自動撿）
	for dr in drops.duplicate():
		if P.pos.distance_to(dr.pos) < 14.0 and (dr.item.rarity == "rune" or dr.item.rarity == "food" or bot or Input.is_physical_key_pressed(KEY_SPACE)):
			_pickup(dr)
	# 城裡：禱告的人、工匠
	if zone == "town" and P.pos.distance_to(Vector2(470, 380)) < 40.0 and town.freed.size() >= 1 and float(P.hp) < float(P.hpmax):
		P.hp = P.hpmax
		P.mp = P.mpmax
		P.bread = maxi(int(P.get("bread", 0)), 3)
		_float(P.pos + Vector2(0, -30), "禱告：全都好了，還帶了餅", Color("7af0a0"))


func _step(dir: Vector2, dt: float) -> void:
	P.pos = _collide(P.pos + dir * float(P.speed) * dt, 5.0)
	if absf(dir.x) > 0.1:
		P.face = 1 if dir.x > 0 else -1


func _click(wp: Vector2, right: bool) -> void:
	if right:
		_cast("haul", wp)
		return
	var best = null
	var bd := 14.0
	for m in mobs:
		if not m.dead and m.pos.distance_to(wp + Vector2(0, 6)) < bd + (16.0 if SPIRITS[m.key].get("boss", false) else 0.0):
			bd = m.pos.distance_to(wp)
			best = m
	if best != null:
		attack_target = best
		move_target = Vector2.INF
		return
	for dr in drops:
		if dr.pos.distance_to(wp) < 12.0:
			move_target = dr.pos
			attack_target = null
			return
	attack_target = null
	move_target = wp


func _swing(m: Dictionary) -> void:
	attack_cd = 0.55
	swing_n += 1
	P.face = 1 if m.pos.x > P.pos.x else -1
	var dmg := randf_range(float(P.dmin), float(P.dmax))
	var crit := randf() < 0.08
	if crit:
		dmg *= 2.0
	fxs.append({"kind": "swing", "pos": P.pos + Vector2(P.face * 10, -10), "t": 0.0, "max": 0.18, "face": P.face})
	_hurt(m, dmg, crit)
	if P.fx.get("light", false) and swing_n % 3 == 0:
		var dir: Vector2 = (m.pos - P.pos).normalized()
		fxs.append({"kind": "beam", "pos": P.pos + Vector2(0, -10), "dir": dir, "len": 150.0, "t": 0.0, "max": 0.3})
		for o in mobs:
			var rel: Vector2 = o.pos - P.pos
			if not o.dead and rel.dot(dir) > 0 and rel.dot(dir) < 150.0 and absf(rel.dot(dir.orthogonal())) < 12.0:
				_hurt(o, dmg * 1.5, false)
	Sfx.play("hit", 0.06)


# ---------------------------------------------------------------- 技能
func _skill_ok(id: String) -> bool:
	for S in SKILLS:
		if S.id == id:
			return int(P.lv) >= int(S.lv)
	return false


func _skill(id: String) -> Dictionary:
	for S in SKILLS:
		if S.id == id:
			return S
	return {}


func _cast(id: String, at: Vector2) -> void:
	var S := _skill(id)
	if S.is_empty() or not _skill_ok(id) or float(P.hp) <= 0.0:
		return
	if float(P.cds.get(id, 0.0)) > 0.0:
		return
	if float(P.mp) < float(S.mp):
		_float(P.pos + Vector2(0, -30), "靈力不夠", C_MAGIC)
		return
	P.mp = float(P.mp) - float(S.mp)
	var cd := float(S.cd)
	var base := (float(P.dmin) + float(P.dmax)) * 0.5
	match id:
		"haul":
			var r := 46.0 * (1.5 if P.fx.get("net_big", false) else 1.0)
			if P.fx.get("net_big", false):
				cd *= 0.5
			if at.distance_to(P.pos) > 160.0:
				at = P.pos + (at - P.pos).normalized() * 160.0
			fxs.append({"kind": "net", "pos": at, "r": r, "t": 0.0, "max": 0.6})
			for m in mobs:
				if not m.dead and m.pos.distance_to(at) < r + 6.0:
					if not SPIRITS[m.key].get("boss", false):
						m.pos = m.pos.lerp(at, 0.75)
					m.stun = maxf(m.stun, 1.5)
					m.aggro = true
					_hurt(m, base * 0.6, false)
			Sfx.play("splash", 0.0)
		"leap":
			if at.distance_to(P.pos) > 130.0:
				at = P.pos + (at - P.pos).normalized() * 130.0
			P.pos = _collide(at, 5.0)
			attack_target = null
			move_target = Vector2.INF
			fxs.append({"kind": "splash", "pos": P.pos, "r": 56.0, "t": 0.0, "max": 0.5})
			for m in mobs:
				if not m.dead and m.pos.distance_to(P.pos) < 56.0:
					_hurt(m, base * 2.2, false)
					if not SPIRITS[m.key].get("boss", false):
						m.pos = _collide(m.pos + (m.pos - P.pos).normalized() * 40.0, 5.0)
					m.stun = maxf(m.stun, 0.6)
			Sfx.play("splash", 0.0)
		"rock":
			P.buffs.rock = 6.0
			for m in mobs:
				if not m.dead and m.pos.distance_to(P.pos) < 140.0:
					m.aggro = true
			fxs.append({"kind": "ring", "pos": P.pos, "r": 40.0, "t": 0.0, "max": 0.5, "col": Color("d8c8a8")})
			Sfx.play("shield", 0.0)
		"fisher":
			P.buffs.fisher = 8.0
			fxs.append({"kind": "ring", "pos": P.pos, "r": 30.0, "t": 0.0, "max": 0.5, "col": Color("7af0a0")})
			Sfx.play("heal", 0.0)
	P.cds[id] = cd


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if inv_open:
			return
		if ev.button_index == MOUSE_BUTTON_LEFT and _hud_click(ev.position):
			return
		if ev.button_index == MOUSE_BUTTON_LEFT:
			_click(get_global_mouse_position(), false)
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			_click(get_global_mouse_position(), true)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.physical_keycode:
			KEY_1: _cast("haul", get_global_mouse_position())
			KEY_2: _cast("leap", get_global_mouse_position())
			KEY_3: _cast("rock", P.pos)
			KEY_4: _cast("fisher", P.pos)
			KEY_I: _toggle_inv()
			KEY_Q: _eat("bread")
			KEY_E: _eat("water")
			KEY_T:
				if zone != "town":
					_say("回城（禱告後回到所羅門的廊下）", 2.0)
					_enter("town", Vector2(320, 260))
					_save()
			KEY_N:
				if zone == "town" and inv_open:
					pass
			KEY_ESCAPE:
				if inv_open:
					_toggle_inv()


## 點畫面下面的技能格、餅、水（手機也能玩）：技能放在最近的黑暗身上
func _hud_click(sp: Vector2) -> bool:
	var vs := get_viewport_rect().size
	var x0 := vs.x / 2.0 - 2.0 * 34.0
	for i in SKILLS.size():
		if Rect2(x0 + i * 34.0, vs.y - 38.0, 30, 30).has_point(sp):
			var at: Vector2 = P.pos + Vector2(P.face * 30.0, 0)
			var best := 1e9
			for m in mobs:
				if not m.dead and m.pos.distance_to(P.pos) < best:
					best = m.pos.distance_to(P.pos)
					at = m.pos
			_cast(SKILLS[i].id, at)
			return true
	if sp.distance_to(Vector2(34, vs.y - 34)) < 30.0 or Rect2(60, vs.y - 24, 70, 20).has_point(sp):
		_eat("bread")
		return true
	if sp.distance_to(Vector2(vs.x - 34, vs.y - 34)) < 30.0 or Rect2(vs.x - 120, vs.y - 24, 60, 20).has_point(sp):
		_eat("water")
		return true
	if Rect2(vs.x - 70, 4, 66, 22).has_point(sp):
		_toggle_inv()
		return true
	return false


# ---------------------------------------------------------------- 黑暗
func _update_mobs(dt: float) -> void:
	for m in mobs:
		if m.dead:
			continue
		m.hit_t = maxf(0.0, m.hit_t - dt)
		var S: Dictionary = SPIRITS[m.key]
		if m.stun > 0.0:
			m.stun -= dt
			continue
		var d: float = m.pos.distance_to(P.pos)
		if not m.aggro and d < 150.0 and float(P.hp) > 0.0:
			m.aggro = true
			# 一群一起醒
			for o in mobs:
				if o.pack == m.pack:
					o.aggro = true
		var target: Vector2 = P.pos
		# 陪你的人也會被打
		if not escorts.is_empty() and float(P.buffs.get("rock", 0.0)) <= 0.0:
			for e in escorts:
				if e.pos.distance_to(m.pos) < d - 20.0:
					target = e.pos
		if not m.aggro or float(P.hp) <= 0.0:
			# 在被捆綁的人旁邊打轉
			var hp: Vector2 = m.home + Vector2.from_angle(t * 0.7 + m.pack) * 10.0
			m.pos = m.pos.move_toward(hp, dt * 12.0)
			continue
		m.cd -= dt
		if m.wind > 0.0:
			# 蓄力中（有預警圈），時間到出手
			m.wind -= dt
			if m.wind <= 0.0:
				_mob_strike(m)
			continue
		var dd: float = m.pos.distance_to(target)
		if dd > float(S.range):
			m.pos = _collide(m.pos + (target - m.pos).normalized() * float(m.spd) * dt, 5.0)
		elif m.cd <= 0.0:
			m.cd = float(S.cd)
			m.aim = target
			if S.get("charge", false) or S.get("roar", false) or S.get("boss", false):
				m.wind = 0.7 if not S.get("boss", false) else 0.9
				if S.get("boss", false):
					m.phase = (int(m.phase) + 1) % 3
			else:
				_mob_strike(m)
		# 黑暗之間不要疊在一起
		for o in mobs:
			if o != m and not o.dead and o.pos.distance_to(m.pos) < 10.0:
				m.pos += (m.pos - o.pos).normalized() * 0.6


func _mob_strike(m: Dictionary) -> void:
	var S: Dictionary = SPIRITS[m.key]
	var aim: Vector2 = m.get("aim", P.pos)
	if S.get("shoot", false):
		shots.append({"pos": m.pos + Vector2(0, -8), "vel": (aim - m.pos).normalized() * 110.0, "dmg": m.dmg, "life": 2.0})
		return
	if S.get("charge", false):
		# 紛爭：直直衝過去
		var to: Vector2 = (aim - m.pos).normalized()
		var end := _collide(m.pos + to * 90.0, 5.0)
		fxs.append({"kind": "dash", "pos": m.pos, "to": end, "t": 0.0, "max": 0.25})
		if _seg_hit(m.pos, end, P.pos, 12.0):
			_hit_player(m.dmg * 1.3, m)
		m.pos = end
		return
	if S.get("roar", false):
		fxs.append({"kind": "ring", "pos": m.pos, "r": 70.0, "t": 0.0, "max": 0.5, "col": C_RED})
		if m.pos.distance_to(P.pos) < 70.0:
			_hit_player(m.dmg, m)
			P.pos = _collide(P.pos + (P.pos - m.pos).normalized() * 40.0, 5.0)
		return
	if S.get("boss", false):
		match int(m.phase):
			1:
				# 一圈謊言
				for i in 12:
					shots.append({"pos": m.pos + Vector2(0, -16), "vel": Vector2.from_angle(i * TAU / 12.0 + t) * 90.0, "dmg": m.dmg * 0.6, "life": 3.0})
			2:
				# 砸地（有預警圈）
				fxs.append({"kind": "ring", "pos": aim, "r": 56.0, "t": 0.0, "max": 0.5, "col": C_RED})
				if aim.distance_to(P.pos) < 56.0:
					_hit_player(m.dmg * 1.6, m)
			_:
				# 叫來更多懼怕
				for i in 2:
					_spawn_mob("fear", m.pos + Vector2.from_angle(i * 2.1) * 30.0, int(m.pack), int(m.lvl))
				_say("公會的恐嚇：「不許再奉這名講論！」（徒 4:18）", 2.0)
		return
	if m.pos.distance_to(aim) < float(S.range) + 4.0:
		if aim.distance_to(P.pos) < 4.0:
			_hit_player(m.dmg, m)
		else:
			for e in escorts:
				if e.pos.distance_to(aim) < 6.0:
					e.hp = float(e.hp) - m.dmg


func _seg_hit(a: Vector2, b: Vector2, p: Vector2, r: float) -> bool:
	var ab := b - a
	var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
	return (a + ab * k).distance_to(p) < r


func _hit_player(n: float, _src) -> void:
	if float(P.hp) <= 0.0:
		return
	n *= 100.0 / (100.0 + float(P.armor) * 4.0)
	if float(P.buffs.get("rock", 0.0)) > 0.0:
		n *= 0.5
	P.hp = float(P.hp) - n
	_float(P.pos + Vector2(0, -28), str(roundi(n)), C_RED)
	Sfx.play("hurt", 0.05)
	if float(P.hp) <= 0.0:
		_die()


func _hurt(m: Dictionary, n: float, crit: bool) -> void:
	if m.dead:
		return
	m.hp -= n
	m.hit_t = 0.12
	m.aggro = true
	_float(m.pos + Vector2(randf_range(-4, 4), -22), str(roundi(n)), C_GOLD if crit else C_CREAM)
	if m.hp <= 0.0:
		_kill(m)


func _kill(m: Dictionary) -> void:
	m.dead = true
	var S: Dictionary = SPIRITS[m.key]
	stats.kills += 1
	_gain_xp(int(float(S.xp) * (1.0 + (int(m.lvl) - 1) * 0.3)))
	fxs.append({"kind": "poof", "pos": m.pos, "t": 0.0, "max": 0.4})
	Sfx.play("kill", 0.05)
	if float(P.buffs.get("fisher", 0.0)) > 0.0:
		P.hp = minf(float(P.hpmax), float(P.hp) + 4.0)
		P.mp = minf(float(P.mpmax), float(P.mp) + 3.0)
	# 掉東西
	var ilvl := int(m.lvl)
	var boss: bool = S.get("boss", false)
	if boss:
		stats.boss = int(stats.get("boss", 0)) + 1
		_say("公會的恐嚇退去了。彼得和約翰說：「聽從你們，不聽從神，這在神面前合理不合理？」（徒 4:19）", 5.0)
	if randf() < (1.0 if boss else (0.6 if S.get("elite", false) else 0.16)):
		for i in (3 if boss else 1):
			_drop(m.pos + Vector2(randf_range(-14, 14), randf_range(-8, 8)), _roll_item(ilvl, boss))
	if randf() < (0.5 if boss else 0.1):
		_drop(m.pos + Vector2(randf_range(-10, 10), 4), {"slot": "food", "rarity": "food", "food": "bread", "name": "餅"})
	elif randf() < 0.06:
		_drop(m.pos + Vector2(randf_range(-10, 10), 4), {"slot": "food", "rarity": "food", "food": "water", "name": "水"})
	for L in RUNES:
		if randf() < float(RUNES[L].drop) * (4.0 if boss else (2.0 if S.get("elite", false) else 1.0)):
			_drop(m.pos + Vector2(randf_range(-10, 10), 6), _rune_item(L))
	var pk: Dictionary = packs[int(m.pack)]
	pk.alive = int(pk.alive) - 1
	if int(pk.alive) <= 0 and not pk.freed:
		_free_person(pk)


## 黑暗都趕走了：被捆綁的人得自由，說一句話，走回城裡
func _free_person(pk: Dictionary) -> void:
	pk.freed = true
	stats.freed += 1
	fxs.append({"kind": "chains", "pos": pk.pos, "t": 0.0, "max": 0.8})
	_ring(pk.pos, C_GOLD, 30.0)
	Sfx.play("holy", 0.0)
	var who: String = ["一位漁夫", "一位寡婦", "一個賣餅的", "一位老人", "一個少年", "一位織布的", "一個挑水的", "一位文士"].pick_random()
	if pk.get("boss", false):
		who = "公會裡的年輕人"
	var line: String = pk.line
	talk_text = "%s：「%s」" % [who, line.trim_prefix("公會裡的一位年輕人：「").trim_suffix("」")]
	talk_t = 4.0
	town.freed.append({"name": who, "line": line, "tint": [pk.tint.r, pk.tint.g, pk.tint.b], "from": ZONES[zone].name})
	walkers.append({"pos": pk.pos, "tint": pk.tint, "t": 0.0})
	_gain_xp(10 * int(ZONES[zone].lvl))
	_save()


func _drop(at: Vector2, it: Dictionary) -> void:
	drops.append({"pos": _collide(at, 4.0), "item": it})
	stats.drops += 1


func _pickup(dr: Dictionary) -> void:
	if dr.item.rarity == "food":
		var k: String = dr.item.food
		if int(P.get(k, 0)) >= 5:
			return
		P[k] = int(P.get(k, 0)) + 1
		drops.erase(dr)
		Sfx.play("gem", 0.0)
		return
	if P.bag.size() >= 24:
		if t >= full_warn_t:
			full_warn_t = t + 2.0
			_float(P.pos + Vector2(0, -30), "背包滿了", C_RED)
		return
	drops.erase(dr)
	P.bag.append(dr.item)
	_float(dr.pos + Vector2(0, -12), dr.item.name, _item_color(dr.item))
	Sfx.play("gem", 0.0)
	if bot:
		_bot_equip(dr.item)


## 餅（回血）、水（回靈力）：腰帶上各最多 5 個，Q／E 使用，慢慢回 3 秒
func _eat(kind: String) -> void:
	if int(P.get(kind, 0)) <= 0 or float(P.hp) <= 0.0 or float(P.buffs.get(kind, 0.0)) > 0.0:
		return
	P[kind] = int(P[kind]) - 1
	P.buffs[kind] = 3.0
	_float(P.pos + Vector2(0, -30), "吃餅" if kind == "bread" else "喝水", Color("7af0a0") if kind == "bread" else C_MAGIC)
	Sfx.play("heal", 0.0)


## 倒下：裝備留在原地，空身回城；城裡被釋放的人陪你去拿（徒 14:20）
func _die() -> void:
	stats.deaths += 1
	var bare := true
	for s in P.equip:
		if not P.equip[s].is_empty():
			bare = false
	if corpse.is_empty() or not bare:
		# 前一份還沒拿回來又倒下：身上穿的放進前一份裡（裝備不會因為連續倒下就不見）
		var old: Dictionary = corpse.get("equip", {})
		corpse = {"zone": zone, "pos": P.pos, "equip": P.equip.duplicate(true), "extra": corpse.get("extra", [])}
		for s in old:
			if not old[s].is_empty():
				corpse.extra.append(old[s])
	for s in P.equip:
		P.equip[s] = {}
	_recalc()
	P.hp = P.hpmax
	P.mp = P.mpmax
	_enter("town", Vector2(320, 260))
	escorts.clear()
	var n := mini(5, 1 + town.freed.size() / 3)
	for i in n:
		var f: Dictionary = town.freed[town.freed.size() - 1 - i] if i < town.freed.size() else {"tint": [1, 1, 1], "name": "弟兄"}
		escorts.append({"pos": P.pos + Vector2.from_angle(i * 1.3) * 18.0, "tint": Color(f.tint[0], f.tint[1], f.tint[2]), "hp": 40.0, "cd": 0.0})
	_say("倒下了。裝備留在%s。被你釋放的 %d 個人陪你回去拿（徒 14:20）" % [ZONES[corpse.zone].name, n], 5.0)
	Sfx.play("lose", 0.0)
	_save()


func _take_corpse() -> void:
	var all := []
	for s in corpse.equip:
		if not corpse.equip[s].is_empty():
			all.append(corpse.equip[s])
	all.append_array(corpse.get("extra", []))
	for it in all:
		if P.equip[it.slot].is_empty():
			P.equip[it.slot] = it
		else:
			P.bag.append(it)
	corpse = {}
	_recalc()
	_say("裝備拿回來了。陪你來的人說：「我們回城裡等你。」", 3.0)
	for e in escorts:
		walkers.append({"pos": e.pos, "tint": e.tint, "t": 0.0})
	escorts.clear()
	Sfx.play("chest", 0.0)
	_save()


func _update_misc(dt: float) -> void:
	for s in shots:
		s.pos += s.vel * dt
		s.life -= dt
		if s.pos.distance_to(P.pos + Vector2(0, -8)) < 8.0:
			_hit_player(float(s.dmg), null)
			s.life = 0.0
	shots = shots.filter(func(s): return s.life > 0.0)
	for f in fxs:
		f.t += dt
	fxs = fxs.filter(func(f): return f.t < f.max)
	for f in floats:
		f.t += dt
	floats = floats.filter(func(f): return f.t < 0.9)
	mobs = mobs.filter(func(m): return not m.dead)
	if attack_target != null and attack_target.dead:
		attack_target = null
	# 被釋放的人走回城（往最近的回城出口走，走出畫面就到城裡了）
	for w in walkers:
		w.t += dt
		var ex := Vector2(-40, P.pos.y)
		for e in ZONES[zone].exits:
			if e.to == "town" or (zone != "town" and e.to == "gate" and zone == "alley"):
				ex = (e.rect as Rect2).get_center()
		w.pos = w.pos.move_toward(ex, dt * 30.0)
	walkers = walkers.filter(func(w): return w.t < 12.0)
	# 陪你的人：跟著你，順手打旁邊的黑暗
	for e in escorts:
		e.cd = float(e.cd) - dt
		var slot: Vector2 = P.pos + Vector2.from_angle(escorts.find(e) * 1.3 + t * 0.3) * 22.0
		var tgt = null
		for m in mobs:
			if not m.dead and m.pos.distance_to(e.pos) < 50.0:
				tgt = m
				break
		if tgt != null:
			e.pos = e.pos.move_toward(tgt.pos, dt * 50.0)
			if e.pos.distance_to(tgt.pos) < 16.0 and e.cd <= 0.0:
				e.cd = 0.8
				_hurt(tgt, 3.0 + int(P.lv) * 0.8, false)
		else:
			e.pos = e.pos.move_toward(slot, dt * 70.0)
	escorts = escorts.filter(func(e): return float(e.hp) > 0.0)


func _float(at: Vector2, text: String, col: Color) -> void:
	if floats.size() < 40:
		floats.append({"pos": at, "text": text, "col": col, "t": 0.0})


func _ring(at: Vector2, col: Color, r: float) -> void:
	fxs.append({"kind": "ring", "pos": at, "r": r, "t": 0.0, "max": 0.5, "col": col})


func _say(s: String, sec: float) -> void:
	msg = s
	msg_t = sec


# ---------------------------------------------------------------- 畫面
func _draw() -> void:
	var Z: Dictionary = ZONES[zone]
	var sz: Vector2 = Z.size
	var gt := _tex("ground_jerusalem")
	draw_rect(Rect2(-200, -200, sz.x + 400, sz.y + 400), Color("120c10"))
	if gt:
		draw_texture_rect(gt, Rect2(Vector2.ZERO, sz), true, Color(0.7, 0.66, 0.72) if zone == "council" else (Color(1.0, 0.95, 0.85) if zone == "town" else Color(0.86, 0.82, 0.8)))
	# 越深的地方越暗：邊緣一圈陰影
	for i in 6:
		draw_rect(Rect2(Vector2.ZERO, sz).grow(-i * 4.0), Color(0, 0, 0, 0.08), false, 4.0)
	for ex in Z.exits:
		var R: Rect2 = ex.rect
		draw_rect(R, Color(1.0, 0.85, 0.4, 0.15 + 0.08 * sin(t * 3.0)))
		draw_string(UIKit.font(), R.get_center() + Vector2(-30 if R.position.x > 100 else 2, -46), ex.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_GOLD)
	# 城：被釋放的人站在廊下
	if zone == "town":
		_draw_town()
	# 屍體
	if not corpse.is_empty() and corpse.zone == zone:
		var cp: Vector2 = corpse.pos
		draw_rect(Rect2(cp + Vector2(-8, -3), Vector2(16, 5)), Color("6a5040"))
		draw_rect(Rect2(cp + Vector2(-6, -6), Vector2(12, 3)), Color("8a6a50"))
		draw_string(UIKit.font(), cp + Vector2(-14, -10), "你的裝備", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, C_GOLD)
	# 依 y 排序畫：障礙物、被捆綁的人、黑暗、玩家、陪你的人、走回城的人
	var items := []
	for o in obstacles:
		items.append({"y": (o.rect as Rect2).end.y, "k": "obs", "o": o})
	for pk in packs:
		items.append({"y": pk.pos.y, "k": "pack", "o": pk})
	for m in mobs:
		items.append({"y": m.pos.y, "k": "mob", "o": m})
	for e in escorts:
		items.append({"y": e.pos.y, "k": "esc", "o": e})
	for w in walkers:
		items.append({"y": w.pos.y, "k": "walk", "o": w})
	items.append({"y": P.pos.y, "k": "me", "o": P})
	items.sort_custom(func(a, b): return a.y < b.y)
	for dr in drops:
		_draw_drop(dr)
	for it in items:
		match it.k:
			"obs":
				draw_texture(_tex(it.o.tex), (it.o.at as Vector2).round())
			"pack":
				_draw_pack(it.o)
			"mob":
				_draw_mob(it.o)
			"esc", "walk":
				_draw_person(it.o.pos, it.o.tint, false, 1)
			"me":
				if float(P.hp) > 0.0:
					_draw_person(P.pos, Color.WHITE, true, int(P.face))
	for s in shots:
		draw_circle(s.pos, 3.0, Color("6e8a48"))
		draw_circle(s.pos, 1.5, Color("c8e070"))
	for f in fxs:
		_draw_fx(f)
	for f in floats:
		var k: float = f.t / 0.9
		var p: Vector2 = (f.pos + Vector2(0, -k * 14.0)).round()
		draw_string_outline(UIKit.font(), p, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, 2, Color(0, 0, 0, 1.0 - k))
		draw_string(UIKit.font(), p, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(f.col, 1.0 - k))


func _draw_town() -> void:
	# 每一位被釋放的人，在城裡有自己的位置（越多人，廊下越熱鬧）
	var n: int = town.freed.size()
	for i in mini(n, 60):
		var f: Dictionary = town.freed[i]
		var a := i * 2.399
		var r := 40.0 + sqrt(i) * 22.0
		var p := Vector2(320, 230) + Vector2(cos(a) * r * 1.4, sin(a) * r * 0.7)
		_draw_person(p + Vector2(0, sin(t * 1.5 + i) * 0.5), Color(f.tint[0], f.tint[1], f.tint[2]), false, 1 if i % 2 else -1)
	if n >= 1:
		draw_string(UIKit.font(), Vector2(430, 358), "禱告的人（走過去：全都好了）", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("7af0a0"))
	if n >= 3:
		draw_string(UIKit.font(), Vector2(120, 348), "工匠（背包裡替白色裝備打孔）", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, C_GOLD)
	draw_string(UIKit.font(), Vector2(282, 150), "被釋放的人：%d 位" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_GOLD)


func _draw_person(p: Vector2, tint: Color, me: bool, face: int) -> void:
	var tx := _tex("peter_%d" % (int(t * 4.0) % 2) if me else "disciple_%d" % (int(t * 3.0 + p.x) % 2))
	draw_set_transform(p.round(), 0.0, Vector2(-1 if face < 0 else 1, 1))
	draw_texture(tx, Vector2(-12, -25), tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if me and float(P.buffs.get("rock", 0.0)) > 0.0:
		draw_arc(p + Vector2(0, -10), 14.0, 0, TAU, 20, Color("d8c8a8"), 1.0)


func _draw_pack(pk: Dictionary) -> void:
	var p: Vector2 = pk.pos
	if pk.freed:
		return
	# 被捆綁的人：暗暗的、坐在地上，身上一圈鎖鏈
	_draw_person(p, Color(0.35, 0.28, 0.42), false, 1)
	for i in 8:
		var a := i * TAU / 8.0 + t * 0.5
		var q := p + Vector2(cos(a) * 9.0, -10.0 + sin(a) * 4.0)
		draw_rect(Rect2(q.round(), Vector2(2, 2)), Color("8a8a9a"))
	draw_circle(p + Vector2(0, -12), 13.0, Color(0.3, 0.1, 0.4, 0.18 + 0.06 * sin(t * 2.0)))


func _draw_mob(m: Dictionary) -> void:
	var S: Dictionary = SPIRITS[m.key]
	var boss: bool = S.get("boss", false)
	var tx := _tex(S.tex if boss else "%s_%d" % [S.tex, int(t * 4.0 + m.pos.x) % 2])
	var sc := 1.6 if S.get("elite", false) else 1.0
	var col := Color(1, 0.6, 0.6) if m.hit_t > 0.0 else (Color(0.6, 0.6, 1.0) if m.stun > 0.0 else Color.WHITE)
	# 黑暗：腳下一團暗紫色的影子，邊緣冒煙
	var ar := 9.0 * sc * (2.2 if boss else 1.0)
	draw_set_transform(m.pos.round(), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, ar, Color(0.15, 0.02, 0.2, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2((m.pos + Vector2(sin(t * 3.0 + m.pos.x) * ar, -2.0 - fmod(t * 8.0 + m.pos.y, 10.0))).round(), Vector2(1, 1)), Color(0.6, 0.3, 0.8, 0.7))
	if boss:
		draw_texture(tx, (m.pos - Vector2(20, 36)).round(), col)
	else:
		draw_set_transform(m.pos.round(), 0.0, Vector2(sc, sc))
		draw_texture(tx, Vector2(-10, -15), col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if m.wind > 0.0:
		# 預警：要出大招了
		var aim: Vector2 = m.get("aim", m.pos)
		var k: float = 1.0 - m.wind / 0.9
		if S.get("charge", false):
			draw_line(m.pos, m.pos + (aim - m.pos).normalized() * 90.0, Color(C_RED, 0.35 + 0.4 * k), 6.0)
		elif S.get("roar", false):
			draw_arc(m.pos, 70.0, 0, TAU, 32, Color(C_RED, 0.5 + 0.4 * k), 2.0)
		elif boss and int(m.phase) == 2:
			draw_circle(aim, 56.0, Color(C_RED, 0.12 + 0.2 * k))
			draw_arc(aim, 56.0, 0, TAU, 32, Color(C_RED, 0.8), 1.5)
	# 血條（受傷了才顯示；菁英、Boss 一直顯示）
	if m.hp < m.hpmax or S.get("elite", false) or boss:
		var w := 40.0 if boss else (24.0 if S.get("elite", false) else 14.0)
		var y := -40.0 if boss else (-30.0 if S.get("elite", false) else -20.0)
		draw_rect(Rect2(m.pos + Vector2(-w / 2.0, y), Vector2(w, 2)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(m.pos + Vector2(-w / 2.0, y), Vector2(w * m.hp / m.hpmax, 2)), C_RED)
	if attack_target != null and attack_target == m:
		draw_arc(m.pos, 9.0, 0, TAU, 16, Color(C_GOLD, 0.7), 1.0)


func _draw_drop(dr: Dictionary) -> void:
	var it: Dictionary = dr.item
	var col := _item_color(it)
	var p: Vector2 = dr.pos.round()
	if it.rarity == "food":
		if it.food == "bread":
			draw_rect(Rect2(p + Vector2(-4, -2), Vector2(8, 5)), Color("6a4020"))
			draw_rect(Rect2(p + Vector2(-3, -2), Vector2(6, 3)), Color("d8a060"))
		else:
			draw_rect(Rect2(p + Vector2(-2, -5), Vector2(5, 8)), Color("2a3a60"))
			draw_rect(Rect2(p + Vector2(-1, -3), Vector2(3, 5)), Color("8fd0ff"))
		return
	if it.rarity == "rune":
		draw_circle(p, 5.0, Color("2a1a14"))
		draw_circle(p, 4.0, Color("ffcf80"))
		draw_string(UIKit.font(), p + Vector2(-3, 3), it.letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("2a1a14"))
	else:
		draw_rect(Rect2(p + Vector2(-4, -3), Vector2(8, 6)), Color("2a1a14"))
		draw_rect(Rect2(p + Vector2(-3, -2), Vector2(6, 4)), col)
	if it.rarity == "unique" or it.rarity == "rune":
		draw_arc(p, 9.0 + sin(t * 4.0), 0, TAU, 16, Color(col, 0.6), 1.0)
	# 名字（像暗黑一樣地上寫著）
	draw_string_outline(UIKit.font(), p + Vector2(-16, -7), it.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, 2, Color(0, 0, 0, 0.9))
	draw_string(UIKit.font(), p + Vector2(-16, -7), it.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, col)


func _draw_fx(f: Dictionary) -> void:
	var k: float = f.t / f.max
	match f.kind:
		"swing":
			var c: Vector2 = f.pos
			draw_arc(c, 10.0, -1.2 if f.face > 0 else PI - 1.2, (1.2 if f.face > 0 else PI + 1.2), 8, Color(C_CREAM, 1.0 - k), 2.0)
		"net":
			var r: float = f.r * (0.3 + 0.7 * minf(1.0, k * 3.0))
			for i in range(-4, 5):
				draw_line(f.pos + Vector2(i * r / 4.0, -r * 0.7), f.pos + Vector2(i * r / 4.0 + r * 0.3, r * 0.7), Color(Color("e8dcc0"), 1.0 - k), 1.0)
			draw_arc(f.pos, r, 0, TAU, 32, Color(Color("6b4a2a"), 1.0 - k), 2.0)
		"splash":
			draw_arc(f.pos, f.r * k, 0, TAU, 32, Color(Color("8fd0ff"), 1.0 - k), 3.0)
			draw_circle(f.pos, f.r * k * 0.6, Color(0.5, 0.8, 1.0, 0.25 * (1.0 - k)))
		"ring":
			draw_arc(f.pos, f.r * (0.4 + 0.6 * k), 0, TAU, 32, Color(f.col, 1.0 - k), 2.0)
		"dash":
			draw_line(f.pos, f.to, Color(C_RED, 1.0 - k), 4.0)
		"beam":
			draw_line(f.pos, f.pos + f.dir * f.len, Color(C_CREAM, 1.0 - k), 5.0)
			draw_line(f.pos, f.pos + f.dir * f.len, Color(C_GOLD, 1.0 - k), 2.0)
		"poof":
			draw_circle(f.pos + Vector2(0, -8), 8.0 * (1.0 + k), Color(0.2, 0.05, 0.25, 0.5 * (1.0 - k)))
		"chains":
			# 鎖鏈斷開：碎片往外飛
			for i in 10:
				var a := i * TAU / 10.0
				draw_rect(Rect2((f.pos + Vector2(cos(a), sin(a) * 0.6 - 0.6) * (8.0 + k * 30.0)).round(), Vector2(2, 2)), Color(Color("aaaabb"), 1.0 - k))
			draw_circle(f.pos + Vector2(0, -12), 20.0 * k, Color(1.0, 0.9, 0.5, 0.3 * (1.0 - k)))


# ---------------------------------------------------------------- 介面
func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	hud.draw.connect(_draw_hud)
	inv_panel = PanelContainer.new()
	inv_panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.08, 0.06, 0.09, 0.96), C_GOLD, 6))
	inv_panel.visible = false
	ui.add_child(inv_panel)


func _draw_hud() -> void:
	var vs := get_viewport_rect().size
	var f := UIKit.font()
	# 左下：生命（紅）右下：靈力（藍）── 暗黑的兩顆球
	_orb(Vector2(34, vs.y - 34), 26.0, float(P.hp) / float(P.hpmax), Color("b02a20"), "%d" % roundi(maxf(0.0, float(P.hp))))
	_orb(Vector2(vs.x - 34, vs.y - 34), 26.0, float(P.mp) / float(P.mpmax), Color("2a50c0"), "%d" % roundi(float(P.mp)))
	hud.draw_string_outline(f, Vector2(66, vs.y - 10), "Q 餅 ×%d" % int(P.get("bread", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color.BLACK)
	hud.draw_string(f, Vector2(66, vs.y - 10), "Q 餅 ×%d" % int(P.get("bread", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d8a060"))
	hud.draw_string_outline(f, Vector2(vs.x - 116, vs.y - 10), "E 水 ×%d" % int(P.get("water", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color.BLACK)
	hud.draw_string(f, Vector2(vs.x - 116, vs.y - 10), "E 水 ×%d" % int(P.get("water", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8fd0ff"))
	# 技能列
	var x0 := vs.x / 2.0 - 2.0 * 34.0
	for i in SKILLS.size():
		var S: Dictionary = SKILLS[i]
		var r := Rect2(x0 + i * 34.0, vs.y - 38.0, 30, 30)
		hud.draw_rect(r, Color("140c10"))
		var tx := _tex(S.icon)
		var ok := _skill_ok(S.id)
		if tx:
			hud.draw_texture_rect(tx, r.grow(-3), false, Color.WHITE if ok else Color(0.3, 0.3, 0.3))
		var cd := float(P.cds.get(S.id, 0.0))
		if cd > 0.0:
			var fr := clampf(cd / float(S.cd), 0.0, 1.0)
			hud.draw_rect(Rect2(r.position.x, r.position.y + 30.0 * (1.0 - fr), 30, 30.0 * fr), Color(0, 0, 0, 0.6))
		hud.draw_rect(r, C_GOLD if ok else Color("4a3a40"), false, 1.0)
		hud.draw_string(f, r.position + Vector2(2, 10), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_CREAM)
		if not ok:
			hud.draw_string(f, r.position + Vector2(4, 26), "Lv%d" % int(S.lv), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("8a7a70"))
	# 經驗條
	var need := _xp_need(int(P.lv))
	hud.draw_rect(Rect2(x0, vs.y - 44.0, 4 * 34.0 - 4.0, 3), Color(0, 0, 0, 0.6))
	hud.draw_rect(Rect2(x0, vs.y - 44.0, (4 * 34.0 - 4.0) * float(P.xp) / float(need), 3), C_GOLD)
	# 左上：地點、等級、城
	hud.draw_string_outline(f, Vector2(8, 16), "%s　%s Lv%d" % [ZONES[zone].name, P.name, int(P.lv)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color.BLACK)
	hud.draw_string(f, Vector2(8, 16), "%s　%s Lv%d" % [ZONES[zone].name, P.name, int(P.lv)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_GOLD)
	hud.draw_string_outline(f, Vector2(8, 32), "被釋放的人 %d　（I 背包、T 回城、空白鍵撿東西）" % town.freed.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color.BLACK)
	hud.draw_string(f, Vector2(8, 32), "被釋放的人 %d　（I 背包、T 回城、空白鍵撿東西）" % town.freed.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_INK)
	hud.draw_rect(Rect2(vs.x - 70, 4, 66, 22), Color("140c10"))
	hud.draw_rect(Rect2(vs.x - 70, 4, 66, 22), C_GOLD, false, 1.0)
	hud.draw_string(f, Vector2(vs.x - 62, 20), "背包 I", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_CREAM)
	for m in mobs:
		if SPIRITS[m.key].get("boss", false) and m.aggro:
			# Boss 的名字和血條放在畫面上方
			var bw := 220.0
			hud.draw_rect(Rect2((vs.x - bw) / 2.0, 30, bw, 6), Color(0, 0, 0, 0.7))
			hud.draw_rect(Rect2((vs.x - bw) / 2.0, 30, bw * m.hp / m.hpmax, 6), C_RED)
			var bn: String = SPIRITS[m.key].name
			var bnw := f.get_string_size(bn, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			hud.draw_string_outline(f, Vector2((vs.x - bnw) / 2.0, 26), bn, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color.BLACK)
			hud.draw_string(f, Vector2((vs.x - bnw) / 2.0, 26), bn, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_RED)
	if not corpse.is_empty():
		hud.draw_string_outline(f, Vector2(8, 46), "你的裝備在：" + ZONES[corpse.zone].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color.BLACK)
		hud.draw_string(f, Vector2(8, 46), "你的裝備在：" + ZONES[corpse.zone].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_RED)
	# 中間上方：訊息；被釋放的人說的話
	if msg_t > 0.0:
		var w := f.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		hud.draw_string_outline(f, Vector2((vs.x - w) / 2.0, 64), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color.BLACK)
		hud.draw_string(f, Vector2((vs.x - w) / 2.0, 64), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_CREAM)
	if talk_t > 0.0:
		var w2 := f.get_string_size(talk_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		hud.draw_rect(Rect2((vs.x - w2) / 2.0 - 8, vs.y - 86, w2 + 16, 20), Color(0, 0, 0, 0.6))
		hud.draw_string(f, Vector2((vs.x - w2) / 2.0, vs.y - 71), talk_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_GOLD)


func _orb(c: Vector2, r: float, frac: float, col: Color, text: String) -> void:
	hud.draw_circle(c, r + 2.0, Color("2a1a14"))
	hud.draw_circle(c, r, Color("140c10"))
	frac = clampf(frac, 0.0, 1.0)
	# 由下往上填滿
	var top := c.y + r - 2.0 * r * frac
	for yy in range(int(top), int(c.y + r)):
		var dy := yy - c.y
		var hw := sqrt(maxf(0.0, r * r - dy * dy))
		hud.draw_rect(Rect2(c.x - hw, yy, hw * 2.0, 1), col)
	hud.draw_arc(c, r, 0, TAU, 32, C_GOLD, 1.0)
	var f := UIKit.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	hud.draw_string_outline(f, c + Vector2(-w / 2.0, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color.BLACK)
	hud.draw_string(f, c + Vector2(-w / 2.0, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_CREAM)


# ---------------------------------------------------------------- 背包
func _toggle_inv() -> void:
	inv_open = not inv_open
	inv_panel.visible = inv_open
	inv_sel = -1
	inv_sel_equip = ""
	if inv_open:
		_build_inv()


func _build_inv() -> void:
	for ch in inv_panel.get_children():
		ch.queue_free()
	var vs := get_viewport_rect().size
	inv_panel.position = Vector2(20, 20)
	inv_panel.size = Vector2(vs.x - 40, vs.y - 40)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	inv_panel.add_child(h)
	# 左：裝備
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(160, 0)
	h.add_child(left)
	left.add_child(UIKit.label("%s Lv%d　傷害 %d～%d　生命 %d　防護 %d" % [P.name, int(P.lv), roundi(float(P.dmin)), roundi(float(P.dmax)), roundi(float(P.hpmax)), roundi(float(P.armor))], 10, C_GOLD))
	for s in ["weapon", "body", "feet", "belt"]:
		var it: Dictionary = P.equip[s]
		var b := UIKit.button("%s：%s" % [SLOT_NAME[s], it.name if not it.is_empty() else "（空）"], 11, inv_sel_equip == s)
		if not it.is_empty():
			b.add_theme_color_override("font_color", _item_color(it))
		b.pressed.connect(func():
			inv_sel_equip = s
			inv_sel = -1
			_build_inv())
		left.add_child(b)
	if zone == "town":
		var nb := UIKit.button("開新角色（城和倉庫留著）", 10)
		nb.pressed.connect(func():
			if nb.text != "真的？再按一次":
				nb.text = "真的？再按一次"
				return
			for it in P.bag:
				if town.stash.size() < 30:
					town.stash.append(it)
			town.chars = int(town.chars) + 1
			_new_char()
			_enter("town", Vector2(320, 260))
			_say("新的宣教士出發了（第 %d 位）。前人的背包都放進倉庫了（林前 3:6）" % int(town.chars), 4.0)
			_save()
			_toggle_inv())
		left.add_child(nb)
	# 中：背包（倉庫）
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(170, 0)
	h.add_child(mid)
	mid.add_child(UIKit.label("背包 %d／24" % P.bag.size(), 10, C_GOLD))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(170, vs.y - 110)
	mid.add_child(sc)
	var list := VBoxContainer.new()
	sc.add_child(list)
	for i in P.bag.size():
		var it: Dictionary = P.bag[i]
		var b := UIKit.button(it.name, 10, inv_sel == i)
		b.add_theme_color_override("font_color", _item_color(it))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx: int = i
		b.pressed.connect(func():
			inv_sel = idx
			inv_sel_equip = ""
			_build_inv())
		list.add_child(b)
	if zone == "town" and not town.stash.is_empty():
		list.add_child(UIKit.label("倉庫（前一位留下的）%d" % town.stash.size(), 10, C_GOLD))
		for i in town.stash.size():
			var it: Dictionary = town.stash[i]
			var b := UIKit.button("取：" + str(it.name), 10)
			b.add_theme_color_override("font_color", _item_color(it))
			var idx: int = i
			b.pressed.connect(func():
				if P.bag.size() < 24:
					P.bag.append(town.stash[idx])
					town.stash.remove_at(idx)
					_save()
				_build_inv())
			list.add_child(b)
	# 右：說明與動作
	var right := VBoxContainer.new()
	var rw: float = vs.x - 40.0 - 160.0 - 170.0 - 40.0
	right.custom_minimum_size = Vector2(rw, 0)
	h.add_child(right)
	var sel: Dictionary = {}
	if inv_sel >= 0 and inv_sel < P.bag.size():
		sel = P.bag[inv_sel]
	elif inv_sel_equip != "":
		sel = P.equip[inv_sel_equip]
	if sel.is_empty():
		right.add_child(UIKit.label("點一件看說明", 11, C_INK))
		var hint := UIKit.label("符文：鑲進有孔的白色裝備，照順序拼出新約的希臘文字", 10, Color("b0a090"))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(rw, 0)
		right.add_child(hint)
		var close := UIKit.button("關閉（I）", 11)
		close.pressed.connect(_toggle_inv)
		right.add_child(close)
		return
	var lines := _item_lines(sel)
	for k in lines.size():
		var lb := UIKit.label(str(lines[k]), 12 if k == 0 else 10, _item_color(sel) if k == 0 else C_INK)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.custom_minimum_size = Vector2(rw, 0)
		right.add_child(lb)
	if inv_sel >= 0:
		if sel.rarity == "rune":
			for s in ["weapon", "body"]:
				var tgt: Dictionary = P.equip[s]
				if not tgt.is_empty() and int(tgt.get("sockets", 0)) > tgt.runes.size():
					var b := UIKit.button("鑲進%s（%s）" % [SLOT_NAME[s], tgt.name], 11, true)
					b.pressed.connect(func():
						if _socket(tgt, sel.letter):
							P.bag.remove_at(inv_sel)
							inv_sel = -1
							_recalc()
							_save()
						_build_inv())
					right.add_child(b)
		else:
			var eq := UIKit.button("穿上", 11, true)
			eq.pressed.connect(func():
				var old: Dictionary = P.equip[sel.slot]
				P.equip[sel.slot] = sel
				P.bag.remove_at(inv_sel)
				if not old.is_empty():
					P.bag.append(old)
				inv_sel = -1
				_recalc()
				_save()
				_build_inv())
			right.add_child(eq)
		var dropb := UIKit.button("丟掉", 10)
		dropb.pressed.connect(func():
			P.bag.remove_at(inv_sel)
			inv_sel = -1
			_build_inv())
		right.add_child(dropb)
	elif inv_sel_equip != "":
		var un := UIKit.button("脫下", 11)
		un.pressed.connect(func():
			if P.bag.size() < 24:
				P.bag.append(P.equip[inv_sel_equip])
				P.equip[inv_sel_equip] = {}
				_recalc()
			inv_sel_equip = ""
			_build_inv())
		right.add_child(un)
		# 城裡的工匠：替白色裝備打孔
		if zone == "town" and town.freed.size() >= 3 and sel.rarity == "normal" and inv_sel_equip in ["weapon", "body"] and int(sel.sockets) < 3 and sel.runes.is_empty():
			var sk := UIKit.button("請工匠打一個孔（%d → %d）" % [int(sel.sockets), int(sel.sockets) + 1], 11, true)
			sk.pressed.connect(func():
				sel.sockets = int(sel.sockets) + 1
				sel.name = "有 %d 個孔的%s" % [sel.sockets, sel.base]
				Sfx.play("chest", 0.0)
				_save()
				_build_inv())
			right.add_child(sk)
	var close2 := UIKit.button("關閉（I）", 11)
	close2.pressed.connect(_toggle_inv)
	right.add_child(close2)


# ---------------------------------------------------------------- 測試機器人
func _bot_equip(it: Dictionary) -> void:
	if it.rarity == "rune":
		for s in ["weapon", "body"]:
			var tgt: Dictionary = P.equip[s]
			if not tgt.is_empty() and int(tgt.get("sockets", 0)) > tgt.runes.size():
				var want := "ΦΩΣ"
				var nxt: String = want.substr(tgt.runes.size(), 1) if s == "weapon" else it.letter
				if it.letter == nxt and _socket(tgt, it.letter):
					P.bag.erase(it)
					_recalc()
					return
		return
	var cur: Dictionary = P.equip[it.slot]
	if _score(it) > _score(cur):
		P.equip[it.slot] = it
		P.bag.erase(it)
		if not cur.is_empty():
			P.bag.append(cur)
		_recalc()


func _score(it: Dictionary) -> float:
	if it.is_empty():
		return -1.0
	var s := float(it.get("min", 0)) + float(it.get("max", 0)) + float(it.get("armor", 0)) * 1.5
	for k in it.mods:
		s += float(it.mods[k]) * 0.5
	if it.rarity == "unique" or it.rarity == "runeword":
		s += 40.0
	if int(it.get("sockets", 0)) == 3 and it.slot == "weapon":
		s += 6.0
	return s


func _bot(_dt: float) -> void:
	if float(P.hp) <= 0.0 or inv_open:
		return
	# 撿屍體優先
	if not corpse.is_empty():
		_bot_go_zone(corpse.zone, corpse.pos)
		return
	if zone == "town":
		_bot_go_exit("gate")
		return
	# 打最近的黑暗
	var near = null
	var nd := 1e9
	for m in mobs:
		if not m.dead and m.pos.distance_to(P.pos) < nd:
			nd = m.pos.distance_to(P.pos)
			near = m
	if P.bag.size() >= 20:
		# 背包快滿：丟掉白色、沒孔的
		for it in P.bag.duplicate():
			if it.rarity == "normal" and int(it.get("sockets", 0)) == 0:
				P.bag.erase(it)
	for dr in drops:
		var full: bool = P.bag.size() >= 24 if dr.item.rarity != "food" else int(P.get(dr.item.food, 0)) >= 5
		if not full and dr.pos.distance_to(P.pos) < 120.0 and (near == null or nd > 60.0):
			move_target = dr.pos
			attack_target = null
			return
	if near != null:
		if float(P.hp) < float(P.hpmax) * 0.5:
			_eat("bread")
		if float(P.mp) < 12.0:
			_eat("water")
		if float(P.hp) < float(P.hpmax) * 0.25 and zone != "town":
			if smoke:
				print("BOT RETREAT zone=%s hp=%d/%d near=%s" % [zone, int(P.hp), int(P.hpmax), near.key])
			_enter("town", Vector2(320, 260))
			return
		var cnt := 0
		for m in mobs:
			if not m.dead and m.pos.distance_to(near.pos) < 50.0:
				cnt += 1
		if cnt >= 3:
			_cast("haul", near.pos)
			_cast("leap", near.pos)
		if float(P.hp) < float(P.hpmax) * 0.5:
			_cast("rock", P.pos)
		_cast("fisher", P.pos)
		attack_target = near
		return
	# 這一區清完：往下一區（公會清完就回城重來）
	var order := ["gate", "alley", "council"]
	var i := order.find(zone)
	if i >= 0 and i < order.size() - 1:
		_bot_go_exit(order[i + 1])
	else:
		_enter("town", Vector2(320, 260))


func _bot_go_exit(to: String) -> void:
	for ex in ZONES[zone].exits:
		if ex.to == to:
			move_target = (ex.rect as Rect2).get_center()
			attack_target = null
			return
	# 沒有直接的出口：往回走
	for ex in ZONES[zone].exits:
		move_target = (ex.rect as Rect2).get_center()


func _bot_go_zone(z: String, at: Vector2) -> void:
	if zone == z:
		# 路上有黑暗先打
		for m in mobs:
			if not m.dead and m.pos.distance_to(P.pos) < 50.0:
				attack_target = m
				return
		move_target = at
		attack_target = null
		return
	var order := ["town", "gate", "alley", "council"]
	var here := order.find(zone)
	var there := order.find(z)
	_bot_go_exit(order[here + (1 if there > here else -1)])


func _smoke_tick() -> void:
	smoke_frames += 1
	if OS.get_cmdline_user_args().has("--die") and smoke_frames % 1200 == 900 and zone != "town":
		_hit_player(99999.0, null)   # 測試：倒下、撿屍體
	if smoke_shot != "" and smoke_frames in [60, 600, 1500, smoke_max - 10]:
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_%d.png" % smoke_frames))
	if smoke_frames == smoke_max / 2 and smoke_shot != "":
		_toggle_inv()
	if smoke_frames == smoke_max / 2 + 30 and smoke_shot != "":
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_inv.png"))
		_toggle_inv()
	if smoke_frames >= smoke_max:
		var eq := []
		for s in P.equip:
			if not P.equip[s].is_empty():
				eq.append(P.equip[s].name)
		print("ARPG DONE t=%.0f lv=%d zone=%s stats=%s freed_town=%d equip=%s bag=%d" % [t, int(P.lv), zone, stats, town.freed.size(), eq, P.bag.size()])
		get_tree().quit()
