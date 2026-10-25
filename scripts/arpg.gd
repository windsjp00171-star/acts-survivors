extends Node2D
## 宣教之路 2 試作：暗黑式的動作 RPG（彼得／保羅、耶路撒冷）
## 敵人是黑暗（懼怕、謊言、紛爭……），被牠們圍住、捆綁的是人；趕走黑暗，人就得自由，走回你的城。
## 城（被釋放的人、倉庫）整個帳號共用；開新角色時城還在（林前 3:6）。
## 倒下：裝備留在原地，空身從城裡出發去拿；城裡被釋放的人會陪你去（徒 14:20）。
## 操作：左鍵移動／攻擊、右鍵第一個技能（在游標處）、1～4 技能、Q 吃餅、E 喝水、I 背包、T 回城、空白鍵撿東西。
## 背包是暗黑式的格子：左鍵拿起／放下、右鍵直接穿上（符文直接鑲進去）。

const SAVE_PATH := "user://arpg.json"
const DARK_SHADER := """
shader_type canvas_item;
uniform vec4 L[16];
uniform int n = 1;
uniform float dark = 0.6;
uniform float aspect = 1.7777;
void fragment() {
	vec2 uv = SCREEN_UV;
	float lit = 0.0;
	for (int i = 0; i < 16; i++) {
		if (i >= n) { break; }
		vec2 d = (uv - L[i].xy) * vec2(aspect, 1.0);
		float r = L[i].z;
		lit = max(lit, (1.0 - smoothstep(r * 0.35, r, length(d))) * L[i].w);
	}
	float a = dark * (1.0 - lit);
	a = floor(a * 16.0 + 0.5) / 16.0;
	COLOR = vec4(0.03, 0.01, 0.07, a);
}
"""
const DARKNESS := {"town": 0.2, "gate": 0.55, "alley": 0.72, "council": 0.78}
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
	"gate": {"name": "城門外", "size": Vector2(1100, 640), "packs": 6, "lvl": 1, "mobs": ["fear", "fear", "lies", "sleep"], "champ": 0.25,
		"exits": [{"to": "town", "rect": Rect2(0, 280, 30, 80), "spawn": Vector2(580, 210), "label": "← 回城"},
			{"to": "alley", "rect": Rect2(1070, 280, 30, 80), "spawn": Vector2(40, 260), "label": "窄巷 →"}]},
	"alley": {"name": "窄巷", "size": Vector2(1200, 520), "packs": 7, "lvl": 4, "mobs": ["strife", "riot", "sorcery", "lies", "fear"], "champ": 0.35,
		"exits": [{"to": "gate", "rect": Rect2(0, 220, 30, 80), "spawn": Vector2(1040, 320), "label": "← 城門外"},
			{"to": "council", "rect": Rect2(1170, 220, 30, 80), "spawn": Vector2(60, 240), "label": "公會 →"}]},
	"council": {"name": "公會", "size": Vector2(700, 480), "packs": 3, "lvl": 7, "boss": true, "mobs": ["accuser", "pride", "fear"], "champ": 0.4,
		"exits": [{"to": "alley", "rect": Rect2(0, 200, 30, 80), "spawn": Vector2(1120, 260), "label": "← 窄巷"}]},
}

## 黑暗（敵人）
const SPIRITS := {
	"fear": {"name": "懼怕", "hp": 22, "dmg": 4, "spd": 46, "range": 16, "cd": 1.0, "xp": 6, "tex": "fear"},
	"lies": {"name": "謊言", "hp": 16, "dmg": 3, "spd": 30, "range": 120, "cd": 2.0, "xp": 7, "tex": "lies", "shoot": true},
	"strife": {"name": "紛爭", "hp": 34, "dmg": 7, "spd": 34, "range": 90, "cd": 3.2, "xp": 9, "tex": "strife", "charge": true},
	"sleep": {"name": "沉睡", "hp": 30, "dmg": 3, "spd": 22, "range": 16, "cd": 1.4, "xp": 8, "tex": "sleep", "slow_aura": true},
	"riot": {"name": "暴亂", "hp": 10, "dmg": 2, "spd": 72, "range": 14, "cd": 0.7, "xp": 3, "tex": "riot"},
	"sorcery": {"name": "邪術", "hp": 24, "dmg": 6, "spd": 30, "range": 140, "cd": 3.6, "xp": 12, "tex": "sorcery", "blink": true},
	"accuser": {"name": "控告者", "hp": 40, "dmg": 5, "spd": 26, "range": 150, "cd": 2.6, "xp": 14, "tex": "accuser", "homing": true},
	"pride": {"name": "驕傲", "hp": 60, "dmg": 9, "spd": 32, "range": 18, "cd": 1.6, "xp": 16, "tex": "pride", "proud": true},
	"terror": {"name": "恐嚇", "hp": 140, "dmg": 10, "spd": 28, "range": 60, "cd": 4.0, "xp": 40, "tex": "terror", "roar": true, "elite": true},
	"council": {"name": "公會的恐嚇", "hp": 480, "dmg": 9, "spd": 26, "range": 70, "cd": 2.4, "xp": 300, "tex": "boss_jerusalem", "boss": true},
}

## 精英群的詞綴（像暗黑的藍名怪：整群同一種、同一個詞綴，血比較多、掉比較多）
const CHAMPS := {"fast": {"name": "迅速的"}, "strong": {"name": "強壯的"}, "plague": {"name": "傳染的"}, "heavy": {"name": "沉重的"}}
## 第一次遇到某種黑暗時的提示
const TIPS := {
	"sleep": "沉睡：靠近牠，你會變慢。「睡著的人當醒過來」（弗 5:14）",
	"riot": "暴亂：一大群、跑很快，但一打就散",
	"sorcery": "邪術：會瞬間移動，在你腳下畫紫色的圈──看到圈就走開（徒 13:8）",
	"accuser": "控告者：射出會追著你跑的球（啟 12:10）",
	"pride": "驕傲：平常只受一半的傷害；定住牠、讓牠瞎眼時才打得動（雅 4:6）",
	"champ": "藍色名字的是精英群：比較強，也掉比較多",
}
## 職業：開新角色時選
const CLASSES := {
	"peter": {"name": "彼得", "tex": "peter", "life": 70, "life_lv": 10, "mana": 25, "mana_lv": 5, "ranged": false, "weapon": 0,
		"desc": "近身：船槳打、網子拉、跳進黑暗裡"},
	"paul": {"name": "保羅", "tex": "paul", "life": 55, "life_lv": 8, "mana": 40, "mana_lv": 6, "ranged": true, "weapon": 3,
		"desc": "遠程：寫書信射出去、責備、讓黑暗自相紛爭"},
}
## 技能（等級到了才會）
const SKILLS := {"peter": [
	{"id": "haul", "name": "撒網", "ref": "約 21:6", "lv": 1, "mp": 8, "cd": 3.0, "icon": "icon_haul",
		"desc": "在游標的地方撒網：網裡的黑暗被拉到中間、定住 1.5 秒"},
	{"id": "leap", "name": "跳在海裡", "ref": "約 21:7", "lv": 3, "mp": 12, "cd": 6.0, "icon": "icon_leap",
		"desc": "撲向游標（最遠 130）：落地的地方水花四濺，周圍的黑暗受重傷、被震開"},
	{"id": "rock", "name": "磐石", "ref": "太 16:18", "lv": 6, "mp": 15, "cd": 16.0, "icon": "icon_rock",
		"desc": "6 秒內受到的傷害減半，身邊的黑暗都衝著你來"},
	{"id": "fisher", "name": "得人如得魚", "ref": "路 5:10", "lv": 9, "mp": 10, "cd": 14.0, "icon": "icon_fisher",
		"desc": "8 秒內每趕走一個黑暗，回血、回靈力"},
], "paul": [
	{"id": "rebuke", "name": "責備", "ref": "提後 4:2", "lv": 1, "mp": 6, "cd": 1.0, "icon": "icon_rebuke",
		"desc": "責備游標上的黑暗：6 秒內慢慢受傷；牠散掉時，責備傳給旁邊兩個"},
	{"id": "blind", "name": "主的手加在你身上", "ref": "徒 13:11", "lv": 3, "mp": 12, "cd": 8.0, "icon": "icon_blind",
		"desc": "游標那一圈的黑暗瞎眼 4 秒，看不見你、彼此攻擊（太 12:26 自相紛爭）"},
	{"id": "grace", "name": "恩典夠用", "ref": "林後 12:9", "lv": 6, "mp": 18, "cd": 20.0, "icon": "icon_grace",
		"desc": "回 40% 生命，2 秒內不受傷"},
	{"id": "fight", "name": "美好的仗", "ref": "提後 4:7", "lv": 9, "mp": 16, "cd": 10.0, "icon": "icon_fight",
		"desc": "書信往四面八方射出三圈"},
]}

## 裝備的底子
const BASES := {
	"weapon": [{"name": "漁夫的木槳", "min": 3, "max": 6, "lv": 1}, {"name": "牧人的杖", "min": 4, "max": 8, "lv": 3}, {"name": "鐵頭漁叉", "min": 6, "max": 11, "lv": 6}, {"name": "蘆葦筆", "min": 2, "max": 6, "lv": 1}],
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
	{"id": "aspd", "name": "迅捷的", "pos": "pre", "desc": "出手 +%d%%", "min": 5, "max": 12, "per": 0.5, "slots": ["weapon", "belt"]},
	{"id": "armorp", "name": "厚實的", "pos": "pre", "desc": "防護 +%d%%", "min": 10, "max": 30, "per": 2.0, "slots": ["body", "feet", "belt"]},
	{"id": "mana", "name": "有靈的", "pos": "suf", "desc": "靈力 +%d", "min": 5, "max": 12, "per": 1.5, "slots": ["body", "belt", "weapon"]},
	{"id": "regen", "name": "得醫治的", "pos": "suf", "desc": "每秒回血 %d", "min": 1, "max": 3, "per": 0.15, "slots": ["body", "belt"]},
]
## 暗金（職業專屬）
const UNIQUES := [
	{"id": "peter_net", "slot": "weapon", "name": "彼得的網", "ref": "約 21:6", "min": 7, "max": 12, "lv": 1,
		"fx": {"dmg": 25, "net_big": 1}, "lines": ["傷害 +25%", "撒網範圍大一半、冷卻減半（彼得）", "「把網撒在船的右邊，就必得著。」"]},
	{"id": "pauls_parchments", "slot": "weapon", "name": "保羅的皮卷", "ref": "提後 4:13", "min": 5, "max": 9, "lv": 1,
		"fx": {"dmg": 20, "letter2": 1}, "lines": ["傷害 +20%", "書信一次寫兩封：多射一發（保羅）", "「更要緊的是那些皮卷。」"]},
	{"id": "david_sling", "slot": "weapon", "name": "大衛的甩石機弦", "ref": "撒上 17:49", "min": 6, "max": 12, "lv": 1,
		"fx": {"dmg": 30, "aspd": 20}, "lines": ["傷害 +30%", "出手 +20%", "「大衛用手從囊中掏出一塊石子來，用機弦甩去」"]},
	{"id": "troas_coat", "slot": "body", "name": "留在特羅亞的外衣", "ref": "提後 4:13", "armor": 10, "lv": 1,
		"fx": {"life": 30, "regen": 3, "mana": 15}, "lines": ["生命 +30", "每秒回血 3", "靈力 +15", "「我在特羅亞留於加布的那件外衣，你來的時候可以帶來」"]},
]
## 符文（希臘字母）與符文之語（新約的希臘文字）
const RUNES := {"Φ": {"name": "Φ（Phi）", "drop": 0.03}, "Ω": {"name": "Ω（Omega）", "drop": 0.02}, "Σ": {"name": "Σ（Sigma）", "drop": 0.025},
	"Ζ": {"name": "Ζ（Zeta）", "drop": 0.02}, "Η": {"name": "Η（Eta）", "drop": 0.018}, "Ν": {"name": "Ν（Nu）", "drop": 0.012},
	"Ι": {"name": "Ι（Iota）", "drop": 0.018}, "Κ": {"name": "Κ（Kappa）", "drop": 0.012}}
const RUNEWORDS := [
	{"word": "ΦΩΣ", "slot": "weapon", "name": "光", "ref": "約 8:12",
		"lines": ["ΦΩΣ 是新約希臘文的「光」", "傷害 +40%", "每第 3 下攻擊，往前射出一道光（穿透）", "「我是世界的光。跟從我的，就不在黑暗裡走。」"],
		"fx": {"dmg": 40, "light": 1}},
	{"word": "ΖΩΗ", "slot": "body", "name": "生命", "ref": "約 14:6",
		"lines": ["ΖΩΗ 是新約希臘文的「生命」", "生命 +40%", "每秒回血 4", "「我就是道路、真理、生命」"],
		"fx": {"lifep": 40, "regen": 4}},
	{"word": "ΝΙΚΗ", "slot": "weapon", "name": "得勝", "ref": "約壹 5:4",
		"lines": ["ΝΙΚΗ 是新約希臘文的「得勝」", "傷害 +60%", "每一下有 10% 機會把黑暗定住 1 秒", "「使我們勝了世界的，就是我們的信心」"],
		"fx": {"dmg": 60, "stun": 10}},
]
## 被釋放的人說的話（第一次見面時）
const FREED_LINES := ["我被懼怕綁了好多年……今天第一次覺得可以呼吸。", "原來我不是一個人。", "他們說我沒救了。你們卻來找我。",
	"謊言在我耳邊說了一輩子，現在安靜了。", "我想跟你們回去，看看你們的教會。", "我家門口那條巷子，以後我來守。",
	"我會打鐵。城裡需要人手嗎？", "我想學怎麼禱告。", "我以前是跟著拿石頭的那群人……可以重新開始嗎？", "謝謝你沒有放棄我。",
	"我在門口討了三十年的錢，沒有人停下來看我。", "我的女兒還在家裡等，我可以先回去告訴她嗎？", "那些聲音說我不配。原來它們在說謊。",
	"我好累……可是心裡好輕。", "你們的神，連我這種人也要嗎？", "我記得你的臉，在我最黑的時候。",
	"我要把我的餅分給城裡的人。", "原來天這麼亮。", "我以前很會吵架。以後，我想學會勸和。", "我可以跟著你們嗎？我走得慢，但我會跟上。"]

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
var dark_rect: ColorRect
var dark_mat: ShaderMaterial
var shake_t := 0.0
var decals: Array = []      # 地上的細節 {tex, pos}
var line_bag: Array = []    # 被釋放的人說的話（抽完才重洗，不會一直重複）
var hud: Control
var inv_ctl: Control        # 背包（暗黑式的格子，自己畫）
var inv_open := false
var held: Dictionary = {}   # 游標上拿著的東西
var newchar_confirm := ""   # 開新角色：再按一次才算
var inv_msg := ""
var inv_msg_until := 0.0
var inv_test_mp := Vector2.INF   # 測試截圖：假裝滑鼠在這裡
var pbolts: Array = []      # 保羅的書信 {pos, vel, dmg, crit, life}
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
var bot_stuck_t := 0.0
var bot_last_pos := Vector2.ZERO
var shots_every := 0   # 測試：每幾格截一張圖（--every=）


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
		elif a.begins_with("--every="):
			shots_every = int(a.substr(8))
		elif a == "--real":
			Engine.time_scale = 1.0   # 測試：機器人照正常速度玩（看手感）
	cam = Camera2D.new()
	add_child(cam)
	cam.zoom = Vector2(2, 2)   # 靠近一點看：人物大、黑暗看得清楚（像暗黑的視角）
	cam.make_current()
	_build_ui()
	_load()
	if smoke and OS.get_cmdline_user_args().has("--fresh"):
		town = {"freed": [], "stash": [], "chars": 1, "seen": []}
		corpse = {}
		_new_char()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--class="):
			_new_char(a.substr(8))   # 測試：用這個職業
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lv="):
			P.lv = int(a.substr(5))   # 測試：直接從這個等級開始
			_recalc()
			P.hp = P.hpmax
		elif a.begins_with("--start="):
			zone = a.substr(8)   # 測試：直接從這一區開始
			P.pos = Vector2(60, 240)
	_enter(zone, P.pos if P.has("pos") else Vector2(320, 260))
	_say("宣教之路 2 試作：左鍵走路、攻擊；右鍵%s；Q 吃餅、E 喝水；I 背包；T 回城" % _skills()[0].name, 5.0)
	if Sfx.has_method("music"):
		Sfx.music("jerusalem")


func _new_char(cls := "peter") -> void:
	var C: Dictionary = CLASSES[cls]
	P = {"cls": cls, "name": C.name, "lv": 1, "xp": 0, "hp": 60.0, "mp": 30.0, "pos": Vector2(320, 260), "face": 1, "bread": 3, "water": 2,
		"equip": {"weapon": {}, "body": {}, "feet": {}, "belt": {}}, "bag": [], "cds": {}, "buffs": {}, "slow_t": 0.0}
	P.equip.weapon = _make_base("weapon", int(C.weapon), 1)
	P.equip.body = _make_base("body", 0, 1)
	zone = "town"
	_recalc()
	P.hp = P.hpmax
	P.mp = P.mpmax


func _skills() -> Array:
	return SKILLS[P.get("cls", "peter")]


# ---------------------------------------------------------------- 存檔
func _save() -> void:
	if smoke:
		return
	var d := {"ver": 2, "zone": "town" if zone != "town" else zone, "P": _ser_p(), "town": town, "corpse": _ser_corpse()}
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
	town = {"freed": [], "stash": [], "chars": 1, "seen": []}
	if smoke or not FileAccess.file_exists(SAVE_PATH):
		_new_char()
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not d is Dictionary or not d.has("P"):
		_new_char()
		return
	town = d.town
	if not town.has("seen"):
		town.seen = []
	P = d.P
	P.pos = Vector2(P.pos[0], P.pos[1])
	P.cds = {}
	P.buffs = {}
	P.slow_t = 0.0
	P.lv = int(P.lv)
	if not P.has("cls"):
		P.cls = "peter"
	P.name = CLASSES[P.cls].name
	# 舊存檔（清單式的背包）：照格子重新排；排不下的放倉庫
	_repack(town.stash)
	for it in _repack(P.bag):
		_fit(town.stash, it)
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


func _roll_item(ilvl: int, boss := false, champ := false) -> Dictionary:
	# 暗金：Boss 掉的機會高；精英群也比較高
	if randf() < (0.22 if boss else (0.04 if champ else 0.012)):
		var U: Dictionary = UNIQUES.pick_random()
		var u := {"slot": U.slot, "base": U.name, "name": U.name, "rarity": "unique", "uid": U.id, "ilvl": ilvl, "mods": U.fx.duplicate(),
			"sockets": 0, "runes": [], "lines": U.lines, "ref": U.ref}
		if U.has("armor"):
			u.armor = int(U.armor) + ilvl / 2
		else:
			u.min = int(U.min) + ilvl / 2
			u.max = int(U.max) + ilvl
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
	if randf() < (0.6 if boss else (0.55 if champ else 0.34)):
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
		# 普通（白色）：可能有孔，可以鑲符文（等級高一點的武器才會有 4 個孔）
		if randf() < 0.45:
			it.sockets = randi_range(1, 4 if slot == "weapon" and ilvl >= 3 else 3)
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
		L.append("右鍵：直接鑲進身上的武器或外衣")
		L.append("武器 3 孔：Φ Ω Σ「光」　武器 4 孔：Ν Ι Κ Η「得勝」　外衣 3 孔：Ζ Ω Η「生命」")
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
	var C: Dictionary = CLASSES[P.get("cls", "peter")]
	var lv := int(P.lv)
	var life := float(C.life) + lv * float(C.life_lv)
	var mana := float(C.mana) + lv * float(C.mana_lv)
	var dmgp := 0.0
	var move := 0.0
	var armor := 0.0
	var armorp := 0.0
	var lifep := 0.0
	var aspd := 0.0
	var regen := 0.0
	var stun := 0.0
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
		var M: Dictionary = it.mods
		life += float(M.get("life", 0))
		mana += float(M.get("mana", 0))
		dmgp += float(M.get("dmg", 0))
		move += float(M.get("move", 0))
		armorp += float(M.get("armorp", 0))
		lifep += float(M.get("lifep", 0))
		aspd += float(M.get("aspd", 0))
		regen += float(M.get("regen", 0))
		stun += float(M.get("stun", 0))
		for k in M:
			if k in ["net_big", "light", "letter2"]:
				P.fx[k] = true
	P.hpmax = life * (1.0 + lifep / 100.0)
	P.mpmax = mana
	P.dmin = (wmin + lv * 0.8) * (1.0 + dmgp / 100.0)
	P.dmax = (wmax + lv * 1.2) * (1.0 + dmgp / 100.0)
	P.armor = armor * (1.0 + armorp / 100.0)
	P.speed = 70.0 * (1.0 + move / 100.0)
	P.aspd = aspd
	P.regen = regen
	P.stunp = stun
	P.hp = minf(float(P.get("hp", P.hpmax)), float(P.hpmax))
	P.mp = minf(float(P.get("mp", P.mpmax)), float(P.mpmax))


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
		for S in _skills():
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
	pbolts.clear()
	fxs.clear()
	walkers.clear()
	move_target = Vector2.INF
	attack_target = null
	_build_obstacles()
	var Z: Dictionary = ZONES[z]
	stats.zones[z] = int(stats.zones.get(z, 0)) + 1
	# 每次進來，黑暗又把人圍住了（可以一直回來刷）
	for i in int(Z.packs):
		# 公會：Boss 在右邊，其他的群擺在左半邊
		var hi: Vector2 = Z.size - Vector2(80, 60) if not Z.get("boss", false) else Vector2(330, Z.size.y - 60)
		var pp := _free_spot(Vector2(140, 60), hi)
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
	cam.limit_left = 0
	cam.limit_top = -16
	cam.limit_right = int(Z.size.x)
	cam.limit_bottom = int(Z.size.y) + 16
	cam.position = P.pos
	cam.reset_smoothing()


func _tint() -> Color:
	return Color.from_hsv(randf(), randf_range(0.04, 0.14), randf_range(0.88, 1.0))


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
	if line_bag.is_empty():
		line_bag = FREED_LINES.duplicate()
		line_bag.shuffle()
	packs.append({"pos": at, "alive": 0, "freed": false, "tint": _tint(), "line": line_bag.pop_back()})
	var pi := packs.size() - 1
	var table: Array = ZONES[zone].get("mobs", ["fear"])
	var kinds: Array = []
	var champ := ""
	if elite:
		_spawn_mob("terror", at + Vector2(0, -24), pi, lvl + 1)
		for i in 4:
			kinds.append(table.pick_random())
	elif randf() < float(ZONES[zone].get("champ", 0.0)):
		# 精英群：整群同一種、同一個詞綴
		champ = CHAMPS.keys().pick_random()
		var k0: String = table.filter(func(k): return k != "riot").pick_random()
		for i in randi_range(3, 4):
			kinds.append(k0)
	else:
		for i in randi_range(3, 6):
			kinds.append(table.pick_random())
	# 暴亂：一來就是一大群（一群最多一次）
	if kinds.has("riot"):
		kinds = kinds.filter(func(k): return k != "riot")
		for i in randi_range(5, 7):
			kinds.append("riot")
	for i in kinds.size():
		_spawn_mob(kinds[i], at + Vector2.from_angle(i * TAU / kinds.size()) * randf_range(26, 40 if kinds.size() < 7 else 52), pi, lvl, champ)


func _spawn_mob(key: String, at: Vector2, pack: int, lvl: int, champ := "") -> void:
	var S: Dictionary = SPIRITS[key]
	var k := (1.0 + (lvl - 1) * 0.28) * 1.3
	var hp := float(S.hp) * k
	var spd := float(S.spd)
	var cdk := 1.0
	if champ != "":
		hp *= 2.5 if champ == "strong" else 1.6
	if champ == "fast":
		spd *= 1.6
		cdk = 0.7
	mobs.append({"key": key, "pos": at, "home": at, "hp": hp, "hpmax": hp, "dmg": float(S.dmg) * (1.0 + (lvl - 1) * 0.2) * 1.3, "spd": spd,
		"cd": randf_range(0.5, 1.5), "wind": 0.0, "pack": pack, "stun": 0.0, "hit_t": 0.0, "lvl": lvl, "aggro": false, "vel": Vector2.ZERO,
		"phase": 0, "dead": false, "champ": champ, "cdk": cdk, "confuse": 0.0, "dot_t": 0.0, "dot_dps": 0.0})
	packs[pack].alive = int(packs[pack].alive) + 1


func _build_obstacles() -> void:
	obstacles.clear()
	decals.clear()
	var Z: Dictionary = ZONES[zone]
	var sz: Vector2 = Z.size
	var dk: Array = ["decal_pebbles", "decal_crack_1", "decal_crack_2", "decal_potsherd", "decal_tuft_dry", "decal_footprints", "decal_straw", "decal_pebbles_dark"]
	if zone == "town":
		dk = ["decal_flowers_w", "decal_flowers_y", "decal_straw", "decal_footprints", "decal_tuft"]
	for i in int(sz.x * sz.y / 9000.0):
		decals.append({"tex": dk.pick_random(), "pos": Vector2(randf_range(10, sz.x - 10), randf_range(20, sz.y - 10)).round()})
	# 邊界：上下一排矮牆（只是畫面，走不出去是地圖邊）
	if zone != "town":
		for x in range(0, int(sz.x), 34):
			decals.append({"tex": "wall_1", "pos": Vector2(x, -6), "solid": true})
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
			# 城外：橄欖樹林、小屋、石堆，一群一群的
			for c in 7:
				var cc := Vector2(randf_range(180, sz.x - 140), randf_range(80, sz.y - 60))
				var kind: Array = [["olive_1", "olive_2", "olive_1"], ["house", "stall", "amphora"], ["stones", "rock_1", "rock_2"], ["tree_1", "bush", "dry_bush"]].pick_random()
				for j in kind.size():
					_obs(kind[j], cc + Vector2(j * 26 - 26, randf_range(-14, 14)))
			_obs("lantern", Vector2(150, 330))
			_obs("lantern", Vector2(150, 130))
		"alley":
			# 窄巷：兩排房子夾出一條彎彎的路
			for i in 9:
				var x := 120.0 + i * 120.0
				_obs(["house", "redhouse", "wall_1"].pick_random(), Vector2(x, 70 + (i % 2) * 40))
				_obs(["house", "redhouse", "wall_2"].pick_random(), Vector2(x + 50, sz.y - 40 - (i % 3) * 30))
				if i % 3 == 1:
					_obs("lantern", Vector2(x + 20, 120))
		"council":
			for i in 6:
				_obs("column_1", Vector2(150 + i * 90, 70))
				_obs("column_1", Vector2(150 + i * 90, sz.y - 30))
			_obs("lantern", Vector2(120, 240))
			_obs("lantern", Vector2(sz.x - 60, 240))


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
	shake_t = maxf(0.0, shake_t - dt)
	cam.offset = Vector2(randf_range(-2, 2), randf_range(-2, 2)) if shake_t > 0.0 else Vector2.ZERO
	_update_light()
	queue_redraw()
	hud.queue_redraw()
	if inv_open:
		inv_ctl.queue_redraw()


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
	P.hp = minf(float(P.hpmax), float(P.hp) + dt * (0.4 + float(P.get("regen", 0.0))))
	P.slow_t = maxf(0.0, float(P.get("slow_t", 0.0)) - dt)
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
			var reach := 140.0 if CLASSES[P.cls].ranged else 22.0 + (14.0 if SPIRITS[m.key].get("boss", false) else 0.0)
			if d > reach:
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
	var sp := float(P.speed) * (0.55 if float(P.get("slow_t", 0.0)) > 0.0 else 1.0)
	P.pos = _collide(P.pos + dir * sp * dt, 5.0)
	if absf(dir.x) > 0.1:
		P.face = 1 if dir.x > 0 else -1


func _click(wp: Vector2, right: bool) -> void:
	if right:
		_cast(_skills()[0].id, wp)
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
	var ranged: bool = CLASSES[P.cls].ranged
	attack_cd = (0.6 if ranged else 0.55) / (1.0 + float(P.get("aspd", 0.0)) / 100.0)
	swing_n += 1
	P.face = 1 if m.pos.x > P.pos.x else -1
	var dmg := randf_range(float(P.dmin), float(P.dmax))
	var crit := randf() < 0.08
	if crit:
		dmg *= 2.0
	var dir: Vector2 = (m.pos - P.pos).normalized()
	if ranged:
		# 保羅：寫一封書信射出去
		_bolt(dir * 220.0, dmg, crit, 0.7)
		if P.fx.get("letter2", false):
			_bolt(dir.rotated(0.2) * 220.0, dmg * 0.7, false, 0.7)
		Sfx.play("link1", 0.08)
	else:
		fxs.append({"kind": "swing", "pos": P.pos + Vector2(P.face * 10, -10), "t": 0.0, "max": 0.18, "face": P.face})
		_strike(m, dmg, crit)
		Sfx.play("hit", 0.06)
	if P.fx.get("light", false) and swing_n % 3 == 0:
		fxs.append({"kind": "beam", "pos": P.pos + Vector2(0, -10), "dir": dir, "len": 150.0, "t": 0.0, "max": 0.3})
		for o in mobs:
			var rel: Vector2 = o.pos - P.pos
			if not o.dead and rel.dot(dir) > 0 and rel.dot(dir) < 150.0 and absf(rel.dot(dir.orthogonal())) < 12.0:
				_hurt(o, dmg * 1.5, false)


func _bolt(vel: Vector2, dmg: float, crit: bool, life: float) -> void:
	pbolts.append({"pos": P.pos + Vector2(0, -10), "vel": vel, "dmg": dmg, "crit": crit, "life": life})


## 玩家的普通攻擊打中：「得勝」有機會把黑暗定住
func _strike(m: Dictionary, dmg: float, crit: bool) -> void:
	if randf() * 100.0 < float(P.get("stunp", 0.0)):
		m.stun = maxf(float(m.stun), 1.0)
	_hurt(m, dmg, crit)


# ---------------------------------------------------------------- 技能
func _skill_ok(id: String) -> bool:
	for S in _skills():
		if S.id == id:
			return int(P.lv) >= int(S.lv)
	return false


func _skill(id: String) -> Dictionary:
	for S in _skills():
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
		"rebuke":
			# 點到的那一個；沒點到就找離游標最近的
			var best = null
			var bd := 40.0
			for m in mobs:
				if not m.dead and m.pos.distance_to(at + Vector2(0, 6)) < bd:
					bd = m.pos.distance_to(at + Vector2(0, 6))
					best = m
			if best == null or best.pos.distance_to(P.pos) > 200.0:
				P.mp = float(P.mp) + float(S.mp)
				return
			best.dot_t = 6.0
			best.dot_dps = maxf(float(best.dot_dps), base * 2.4 / 6.0)
			best.aggro = true
			fxs.append({"kind": "link", "pos": P.pos + Vector2(0, -12), "to": best.pos + Vector2(0, -8), "t": 0.0, "max": 0.3})
			Sfx.play("persuade", 0.05)
		"blind":
			if at.distance_to(P.pos) > 160.0:
				at = P.pos + (at - P.pos).normalized() * 160.0
			fxs.append({"kind": "ring", "pos": at, "r": 50.0, "t": 0.0, "max": 0.6, "col": Color("c0a0ff")})
			for m in mobs:
				if not m.dead and m.pos.distance_to(at) < 56.0:
					m.aggro = true
					if SPIRITS[m.key].get("boss", false):
						m.stun = maxf(m.stun, 1.0)
					else:
						m.confuse = 4.0
						m.wind = 0.0
			Sfx.play("shatter", 0.0)
		"grace":
			P.hp = minf(float(P.hpmax), float(P.hp) + float(P.hpmax) * 0.4)
			P.buffs.grace = 2.0
			fxs.append({"kind": "ring", "pos": P.pos, "r": 36.0, "t": 0.0, "max": 0.6, "col": C_GOLD})
			Sfx.play("heal", 0.0)
		"fight":
			for w in 3:
				for i in 12:
					_bolt(Vector2.from_angle(i * TAU / 12.0 + w * 0.13) * (150.0 + w * 40.0), base * 0.9, false, 0.9)
			Sfx.play("shield", 0.0)
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
			KEY_1, KEY_2, KEY_3, KEY_4:
				var si: int = ev.physical_keycode - KEY_1
				_cast(_skills()[si].id, get_global_mouse_position())
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
	for i in _skills().size():
		if Rect2(x0 + i * 34.0, vs.y - 38.0, 30, 30).has_point(sp):
			var at: Vector2 = P.pos + Vector2(P.face * 30.0, 0)
			var best := 1e9
			for m in mobs:
				if not m.dead and m.pos.distance_to(P.pos) < best:
					best = m.pos.distance_to(P.pos)
					at = m.pos
			_cast(_skills()[i].id, at)
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
		# 被責備：慢慢受傷
		if float(m.dot_t) > 0.0:
			m.dot_t = float(m.dot_t) - dt
			m.hp -= float(m.dot_dps) * dt
			if m.hp <= 0.0:
				_kill(m)
				continue
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
			_tip(m.key)
			if str(m.champ) != "":
				_tip("champ")
		# 瞎眼：看不見你，黑暗彼此攻擊（自相紛爭）
		if float(m.confuse) > 0.0:
			m.confuse = float(m.confuse) - dt
			_confused(m, dt)
			continue
		if S.get("slow_aura", false) and d < 60.0 and float(P.hp) > 0.0:
			P.slow_t = maxf(float(P.get("slow_t", 0.0)), 0.3)
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
			m.cd = float(S.cd) * float(m.cdk)
			m.aim = target
			if S.get("charge", false) or S.get("roar", false) or S.get("boss", false) or S.get("blink", false):
				m.wind = 0.9 if S.get("boss", false) else (0.8 if S.get("blink", false) else 0.7)
				if S.get("boss", false):
					m.phase = (int(m.phase) + 1) % 3
			else:
				_mob_strike(m)
		# 黑暗之間不要疊在一起
		for o in mobs:
			if o != m and not o.dead and o.pos.distance_to(m.pos) < 10.0:
				m.pos += (m.pos - o.pos).normalized() * 0.6


func _confused(m: Dictionary, dt: float) -> void:
	var best = null
	var bd := 140.0
	for o in mobs:
		if not is_same(o, m) and not o.dead and o.pos.distance_to(m.pos) < bd:
			bd = o.pos.distance_to(m.pos)
			best = o
	if best == null:
		m.pos = _collide(m.pos + Vector2.from_angle(t * 2.0 + m.home.x) * float(m.spd) * 0.5 * dt, 5.0)
		return
	if bd > 16.0:
		m.pos = _collide(m.pos + (best.pos - m.pos).normalized() * float(m.spd) * dt, 5.0)
		return
	m.cd -= dt
	if m.cd <= 0.0:
		m.cd = float(SPIRITS[m.key].cd) * float(m.cdk)
		fxs.append({"kind": "swing", "pos": m.pos + Vector2(0, -8), "t": 0.0, "max": 0.18, "face": 1 if best.pos.x > m.pos.x else -1})
		_hurt(best, float(m.dmg) * 1.5 + float(P.dmax) * 0.5, false)


func _mob_strike(m: Dictionary) -> void:
	var S: Dictionary = SPIRITS[m.key]
	var aim: Vector2 = m.get("aim", P.pos)
	if S.get("shoot", false):
		shots.append({"pos": m.pos + Vector2(0, -8), "vel": (aim - m.pos).normalized() * 110.0, "dmg": m.dmg, "life": 2.0})
		return
	if S.get("homing", false):
		# 控告者：會追著你的球
		shots.append({"pos": m.pos + Vector2(0, -8), "vel": (aim - m.pos).normalized() * 70.0, "dmg": m.dmg, "life": 4.0, "home": true})
		return
	if S.get("blink", false):
		# 邪術：腳下的圈炸開，然後瞬間移到別的地方
		fxs.append({"kind": "ring", "pos": aim, "r": 30.0, "t": 0.0, "max": 0.5, "col": Color("b070ff")})
		if aim.distance_to(P.pos) < 30.0:
			_hit_player(m.dmg * 1.4, m)
		fxs.append({"kind": "poof", "pos": m.pos, "t": 0.0, "max": 0.4})
		m.pos = _collide(P.pos + Vector2.from_angle(randf() * TAU) * randf_range(70, 110), 5.0)
		fxs.append({"kind": "poof", "pos": m.pos, "t": 0.0, "max": 0.4})
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


func _hit_player(n: float, src) -> void:
	if float(P.hp) <= 0.0:
		return
	if float(P.buffs.get("grace", 0.0)) > 0.0:
		_float(P.pos + Vector2(0, -28), "恩典", C_GOLD)
		return
	n *= 100.0 / (100.0 + float(P.armor) * 4.0)
	if float(P.buffs.get("rock", 0.0)) > 0.0:
		n *= 0.5
	P.hp = float(P.hp) - n
	_float(P.pos + Vector2(0, -28), str(roundi(n)), C_RED)
	Sfx.play("hurt", 0.05)
	if src is Dictionary and str(src.get("champ", "")) == "heavy":
		P.slow_t = 1.5
	if float(P.hp) <= 0.0:
		_die()


func _hurt(m: Dictionary, n: float, crit: bool) -> void:
	if m.dead:
		return
	var proud: bool = SPIRITS[m.key].get("proud", false) and m.stun <= 0.0 and float(m.confuse) <= 0.0
	if proud:
		n *= 0.5   # 驕傲：要先定住、弄瞎才打得動（雅 4:6）
	m.hp -= n
	m.hit_t = 0.12
	m.aggro = true
	if not SPIRITS[m.key].get("boss", false) and not SPIRITS[m.key].get("elite", false):
		m.pos = _collide(m.pos + (m.pos - P.pos).normalized() * (6.0 if crit else 3.0), 5.0)   # 被打得往後退一點
	if crit:
		shake_t = 0.1
	if floats.size() < 50:
		floats.append({"pos": m.pos + Vector2(randf_range(-4, 4), -22), "text": str(roundi(n)) + ("!" if crit else ""), "col": C_GOLD if crit else (Color("9a9aa8") if proud else C_CREAM), "t": 0.0, "big": crit})
	if m.hp <= 0.0:
		_kill(m)


func _kill(m: Dictionary) -> void:
	m.dead = true
	var S: Dictionary = SPIRITS[m.key]
	var champ: String = str(m.get("champ", ""))
	stats.kills += 1
	_gain_xp(int(float(S.xp) * (1.0 + (int(m.lvl) - 1) * 0.3) * (2.0 if champ != "" else 1.0)))
	# 責備傳下去：旁邊兩個
	if float(m.get("dot_t", 0.0)) > 0.0:
		var near: Array = mobs.filter(func(o): return not o.dead and o.pos.distance_to(m.pos) < 80.0)
		near.sort_custom(func(a, b): return a.pos.distance_to(m.pos) < b.pos.distance_to(m.pos))
		for o in near.slice(0, 2):
			o.dot_t = 4.0
			o.dot_dps = m.dot_dps
			o.aggro = true
			fxs.append({"kind": "link", "pos": m.pos + Vector2(0, -8), "to": o.pos + Vector2(0, -8), "t": 0.0, "max": 0.3})
	# 傳染的：散掉時跑出兩個暴亂
	if champ == "plague":
		for i in 2:
			_spawn_mob("riot", m.pos + Vector2.from_angle(i * PI) * 12.0, int(m.pack), int(m.lvl))
			mobs[-1].aggro = true
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
	if randf() < (1.0 if boss else (0.6 if S.get("elite", false) else (0.45 if champ != "" else 0.16))):
		for i in (3 if boss else 1):
			_drop(m.pos + Vector2(randf_range(-14, 14), randf_range(-8, 8)), _roll_item(ilvl + (1 if champ != "" else 0), boss, champ != ""))
	if randf() < (0.5 if boss else 0.1):
		_drop(m.pos + Vector2(randf_range(-10, 10), 4), {"slot": "food", "rarity": "food", "food": "bread", "name": "餅"})
	elif randf() < 0.06:
		_drop(m.pos + Vector2(randf_range(-10, 10), 4), {"slot": "food", "rarity": "food", "food": "water", "name": "水"})
	for L in RUNES:
		if randf() < float(RUNES[L].drop) * (4.0 if boss else (2.0 if S.get("elite", false) or champ != "" else 1.0)):
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
	var p := _collide(at, 10.0)
	drops.append({"pos": p, "item": it})
	stats.drops += 1
	# 好東西掉下來：一道光柱、一聲響（像暗黑的暗金）
	if it.rarity in ["unique", "rune"]:
		fxs.append({"kind": "pillar", "pos": p, "t": 0.0, "max": 1.6, "col": _item_color(it)})
		Sfx.play("evolve" if it.rarity == "unique" else "chest", 0.0)
		if it.rarity == "unique":
			_say("暗金掉下來了：" + it.name, 3.0)


func _pickup(dr: Dictionary) -> void:
	if dr.item.rarity == "food":
		var k: String = dr.item.food
		if int(P.get(k, 0)) >= 5:
			return
		P[k] = int(P.get(k, 0)) + 1
		drops.erase(dr)
		Sfx.play("gem", 0.0)
		return
	if not _fit(P.bag, dr.item, false):
		if t >= full_warn_t:
			full_warn_t = t + 2.0
			_float(P.pos + Vector2(0, -30), "背包放不下了", C_RED)
		return
	drops.erase(dr)
	_fit(P.bag, dr.item)
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
	pbolts.clear()
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
		elif not _fit(P.bag, it):
			_drop(P.pos + Vector2(randf_range(-16, 16), randf_range(-8, 8)), it)
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
	for s in shots:
		if s.get("home", false):
			var want: Vector2 = (P.pos + Vector2(0, -8) - s.pos).normalized() * 75.0
			s.vel = (s.vel as Vector2).lerp(want, minf(1.0, dt * 1.2))
	shots = shots.filter(func(s): return s.life > 0.0)
	for b in pbolts:
		b.pos += b.vel * dt
		b.life -= dt
		for m in mobs:
			if not m.dead and (m.pos + Vector2(0, -8)).distance_to(b.pos) < 10.0 + (14.0 if SPIRITS[m.key].get("boss", false) else 0.0):
				_strike(m, float(b.dmg), b.crit)
				b.life = 0.0
				break
	pbolts = pbolts.filter(func(b): return b.life > 0.0)
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


## 光源：彼得（穿著「光」更亮）、城裡的燈、被釋放的人、地上的寶、出口
func _update_light() -> void:
	var vs := get_viewport_rect().size
	var ct := get_viewport().get_canvas_transform()
	var arr: Array = []
	var zoom: float = cam.zoom.y
	var add := func(wp: Vector2, wr: float, k: float):
		if arr.size() >= 16:
			return
		var sp: Vector2 = ct * wp
		if sp.x < -200 or sp.y < -200 or sp.x > vs.x + 200 or sp.y > vs.y + 200:
			return
		arr.append(Vector4(sp.x / vs.x, sp.y / vs.y, wr * zoom / vs.y, k))
	add.call(P.pos + Vector2(0, -10), 120.0 * (1.5 if P.fx.get("light", false) else 1.0), 1.0)
	for o in obstacles:
		if o.tex == "lantern":
			add.call((o.at as Vector2) + Vector2(6, 4), 70.0, 0.9)
	for ex in ZONES[zone].exits:
		add.call((ex.rect as Rect2).get_center(), 60.0, 0.7)
	for w in walkers:
		add.call(w.pos + Vector2(0, -10), 30.0, 0.8)
	for e in escorts:
		add.call(e.pos + Vector2(0, -10), 30.0, 0.8)
	for f in fxs:
		if f.kind == "chains":
			add.call(f.pos + Vector2(0, -10), 70.0 * (1.0 - f.t / f.max), 1.0)
	for dr in drops:
		if dr.item.rarity in ["unique", "rune", "runeword"]:
			add.call(dr.pos, 26.0, 0.8)
	if not corpse.is_empty() and corpse.zone == zone:
		add.call(corpse.pos, 30.0, 0.6)
	while arr.size() < 16:
		arr.append(Vector4(-9, -9, 0, 0))
	dark_mat.set_shader_parameter("L", PackedVector4Array(arr))
	dark_mat.set_shader_parameter("n", 16)
	dark_mat.set_shader_parameter("aspect", vs.x / vs.y)
	dark_mat.set_shader_parameter("dark", float(DARKNESS.get(zone, 0.5)))


func _float(at: Vector2, text: String, col: Color) -> void:
	if floats.size() < 40:
		floats.append({"pos": at, "text": text, "col": col, "t": 0.0})


func _ring(at: Vector2, col: Color, r: float) -> void:
	fxs.append({"kind": "ring", "pos": at, "r": r, "t": 0.0, "max": 0.5, "col": col})


func _say(s: String, sec: float) -> void:
	msg = s
	msg_t = sec


## 第一次遇到：說一句（整個帳號只說一次）
func _tip(k: String) -> void:
	if not TIPS.has(k) or town.seen.has(k):
		return
	town.seen.append(k)
	_say(TIPS[k], 4.0)


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
	for dc in decals:
		var dt2 := _tex(dc.tex)
		if dt2:
			draw_texture(dt2, dc.pos)
	for dr in drops:
		_draw_drop(dr)
	for it in items:
		match it.k:
			"obs":
				# 彼得走到房子、城門後面時，那一塊變半透明（才看得到自己）
				var otx := _tex(it.o.tex)
				var orr := Rect2(it.o.at, otx.get_size())
				var behind: bool = orr.grow(-2).has_point(P.pos + Vector2(0, -8)) and P.pos.y < (it.o.rect as Rect2).end.y
				draw_texture(otx, (it.o.at as Vector2).round(), Color(1, 1, 1, 0.45 if behind else 1.0))
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
		if s.get("home", false):
			draw_circle(s.pos, 4.0, Color("8a2a20"))
			draw_circle(s.pos, 2.0, Color("ff8a60"))
		else:
			draw_circle(s.pos, 3.0, Color("6e8a48"))
			draw_circle(s.pos, 1.5, Color("c8e070"))
	for b in pbolts:
		# 書信：一小卷羊皮紙
		var bp: Vector2 = (b.pos as Vector2).round()
		draw_rect(Rect2(bp - Vector2(3, 2), Vector2(6, 4)), Color("f4ead2"))
		draw_rect(Rect2(bp - Vector2(2, 1), Vector2(4, 1)), Color("6a4a30"))
		draw_rect(Rect2(bp - (b.vel as Vector2).normalized() * 6.0 - Vector2(1, 1), Vector2(2, 2)), Color(C_GOLD, 0.5))
	for f in fxs:
		_draw_fx(f)
	for f in floats:
		var k: float = f.t / 0.9
		var p: Vector2 = (f.pos + Vector2(0, -k * 14.0)).round()
		var fsz := 11 if f.get("big", false) else 8
		draw_string_outline(UIKit.font(), p, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 2, Color(0, 0, 0, 1.0 - k))
		draw_string(UIKit.font(), p, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(f.col, 1.0 - k))


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
		draw_string(UIKit.font(), Vector2(120, 348), "工匠（背包裡：白色裝備放到工匠格打孔）", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, C_GOLD)
	draw_string(UIKit.font(), Vector2(282, 150), "被釋放的人：%d 位" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_GOLD)


func _draw_person(p: Vector2, tint: Color, me: bool, face: int) -> void:
	var tx := _tex("%s_%d" % [CLASSES[P.get("cls", "peter")].tex, int(t * 4.0) % 2] if me else "disciple_%d" % (int(t * 3.0 + p.x) % 2))
	if me and float(P.get("slow_t", 0.0)) > 0.0:
		tint = Color(0.7, 0.75, 1.0)
	draw_set_transform(p.round(), 0.0, Vector2(-1 if face < 0 else 1, 1))
	draw_texture(tx, Vector2(-12, -25), tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if me and float(P.buffs.get("rock", 0.0)) > 0.0:
		draw_arc(p + Vector2(0, -10), 14.0, 0, TAU, 20, Color("d8c8a8"), 1.0)
	if me and float(P.buffs.get("grace", 0.0)) > 0.0:
		draw_arc(p + Vector2(0, -10), 15.0, 0, TAU, 20, Color(C_GOLD, 0.8), 2.0)


func _draw_pack(pk: Dictionary) -> void:
	var p: Vector2 = pk.pos
	if pk.freed:
		return
	# 被捆綁的人：暗暗的，每一個黑暗都拉著一條鎖鏈綁在他身上；趕走一個，就斷一條
	for m in mobs:
		if not m.dead and int(m.pack) == packs.find(pk) and m.pos.distance_to(p) < 160.0:
			var a: Vector2 = p + Vector2(0, -10)
			var b: Vector2 = m.pos + Vector2(0, -6)
			var steps := int(a.distance_to(b) / 4.0)
			for i in steps:
				var q := a.lerp(b, float(i) / maxf(1.0, steps)) + Vector2(0, sin(i * 0.9 + t * 2.0) * 1.0)
				draw_rect(Rect2(q.round(), Vector2(2, 1) if i % 2 == 0 else Vector2(1, 2)), Color(0.55, 0.5, 0.62, 0.85))
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
	var champ: String = str(m.get("champ", ""))
	var sc := 1.6 if S.get("elite", false) else (1.3 if champ != "" else 1.0)
	var col := Color(1, 0.6, 0.6) if m.hit_t > 0.0 else (Color(0.6, 0.6, 1.0) if m.stun > 0.0 else (Color(0.85, 0.7, 1.0) if float(m.confuse) > 0.0 else Color.WHITE))
	if S.get("slow_aura", false):
		draw_circle(m.pos, 60.0, Color(0.4, 0.5, 0.9, 0.05))
	if champ != "":
		# 精英：腳下一圈藍光
		draw_set_transform(m.pos.round(), 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 13.0, 0, TAU, 20, Color(0.5, 0.65, 1.0, 0.7), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
		elif S.get("blink", false):
			draw_circle(aim, 30.0, Color(0.7, 0.4, 1.0, 0.12 + 0.2 * k))
			draw_arc(aim, 30.0, 0, TAU, 24, Color(0.7, 0.4, 1.0, 0.8), 1.5)
	if float(m.dot_t) > 0.0:
		# 被責備：身上冒金色的字
		for i in 2:
			var q: Vector2 = m.pos + Vector2(sin(t * 5.0 + i * 3.0) * 5.0, -14.0 - fmod(t * 20.0 + i * 7.0, 12.0))
			draw_rect(Rect2(q.round(), Vector2(1, 2)), Color(C_GOLD, 0.8))
	if float(m.confuse) > 0.0:
		draw_string(UIKit.font(), m.pos + Vector2(-3, -24 * sc), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("c0a0ff"))
	elif S.get("proud", false) and m.stun <= 0.0:
		draw_arc(m.pos + Vector2(0, -8), 12.0, PI, TAU, 12, Color(Color("d0c090"), 0.5), 1.0)
	# 血條（受傷了才顯示；菁英、Boss 一直顯示）
	if m.hp < m.hpmax or S.get("elite", false) or boss or champ != "":
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
			# 黑暗散掉：一團紫煙往外、往上飄散
			draw_circle(f.pos + Vector2(0, -8 - k * 6.0), 8.0 * (1.0 + k), Color(0.2, 0.05, 0.25, 0.5 * (1.0 - k)))
			for i in 6:
				var a: float = i * TAU / 6.0 + f.pos.x
				draw_rect(Rect2((f.pos + Vector2(cos(a) * k * 16.0, -8.0 + sin(a) * k * 10.0 - k * 10.0)).round(), Vector2(2, 2)), Color(0.6, 0.3, 0.8, 1.0 - k))
		"pillar":
			var pa := (1.0 - k) * 0.8
			draw_rect(Rect2(f.pos + Vector2(-2, -60), Vector2(4, 60)), Color(f.col, pa * 0.6))
			draw_rect(Rect2(f.pos + Vector2(-1, -60), Vector2(2, 60)), Color(Color.WHITE, pa))
		"chains":
			# 鎖鏈斷開：碎片往外飛
			for i in 10:
				var a := i * TAU / 10.0
				draw_rect(Rect2((f.pos + Vector2(cos(a), sin(a) * 0.6 - 0.6) * (8.0 + k * 30.0)).round(), Vector2(2, 2)), Color(Color("aaaabb"), 1.0 - k))
			draw_circle(f.pos + Vector2(0, -12), 20.0 * k, Color(1.0, 0.9, 0.5, 0.3 * (1.0 - k)))


# ---------------------------------------------------------------- 介面
func _build_ui() -> void:
	# 黑暗：整個畫面蓋一層，只有光源附近亮（彼得身邊、燈、被釋放的人、掉在地上的寶）
	var dl := CanvasLayer.new()
	dl.layer = 1
	add_child(dl)
	dark_rect = ColorRect.new()
	dark_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = DARK_SHADER
	dark_mat = ShaderMaterial.new()
	dark_mat.shader = sh
	dark_rect.material = dark_mat
	dl.add_child(dark_rect)
	ui = CanvasLayer.new()
	ui.layer = 2
	add_child(ui)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	hud.draw.connect(_draw_hud)
	inv_ctl = Control.new()
	inv_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	inv_ctl.mouse_filter = Control.MOUSE_FILTER_STOP
	inv_ctl.visible = false
	ui.add_child(inv_ctl)
	inv_ctl.draw.connect(_draw_inv)
	inv_ctl.gui_input.connect(_inv_input)


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
	var SK: Array = _skills()
	for i in SK.size():
		var S: Dictionary = SK[i]
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
	# 滑鼠指著的黑暗：上方顯示名字和血（像暗黑）
	var hov = attack_target
	var gm := get_global_mouse_position()
	for m in mobs:
		if not m.dead and m.pos.distance_to(gm + Vector2(0, 6)) < 14.0:
			hov = m
	if hov != null and not SPIRITS[hov.key].get("boss", false) and not inv_open:
		var hn: String = SPIRITS[hov.key].name
		var hc := C_INK
		if str(hov.champ) != "":
			hn = CHAMPS[hov.champ].name + hn
			hc = Color("8fb0ff")
		elif SPIRITS[hov.key].get("elite", false):
			hc = C_GOLD
		var hw := 120.0
		hud.draw_rect(Rect2((vs.x - hw) / 2.0, 30, hw, 4), Color(0, 0, 0, 0.7))
		hud.draw_rect(Rect2((vs.x - hw) / 2.0, 30, hw * maxf(0.0, hov.hp) / hov.hpmax, 4), C_RED)
		var hnw := f.get_string_size(hn, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		hud.draw_string_outline(f, Vector2((vs.x - hnw) / 2.0, 26), hn, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
		hud.draw_string(f, Vector2((vs.x - hnw) / 2.0, 26), hn, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, hc)
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


# ---------------------------------------------------------------- 背包（暗黑式的格子）
const CELL := 20
const BAG_W := 10
const BAG_H := 4


## 每一件佔幾格：武器 1×3、外衣 2×3、鞋 2×2、腰帶 2×1、符文 1×1
func _isize(it: Dictionary) -> Vector2i:
	match str(it.get("slot", "")):
		"weapon": return Vector2i(1, 3)
		"body": return Vector2i(2, 3)
		"feet": return Vector2i(2, 2)
		"belt": return Vector2i(2, 1)
	return Vector2i(1, 1)


func _overlaps(list: Array, it: Dictionary, gx: int, gy: int) -> Array:
	var s := _isize(it)
	var r := Rect2i(gx, gy, s.x, s.y)
	var out: Array = []
	for o in list:
		if is_same(o, it) or not o.has("gx"):
			continue
		var os := _isize(o)
		if r.intersects(Rect2i(int(o.gx), int(o.gy), os.x, os.y)):
			out.append(o)
	return out


func _inb(it: Dictionary, gx: int, gy: int) -> bool:
	var s := _isize(it)
	return gx >= 0 and gy >= 0 and gx + s.x <= BAG_W and gy + s.y <= BAG_H


## 找第一個放得下的位置（place=false 只是問放不放得下）
func _fit(list: Array, it: Dictionary, place := true) -> bool:
	for gx in BAG_W:
		for gy in BAG_H:
			if _inb(it, gx, gy) and _overlaps(list, it, gx, gy).is_empty():
				if place:
					it.gx = gx
					it.gy = gy
					list.append(it)
				return true
	return false


## 照格子重新排（舊存檔）；回傳排不下的
func _repack(list: Array) -> Array:
	var all := list.duplicate()
	list.clear()
	var later: Array = []
	for it in all:
		if it.has("gx"):
			it.gx = int(it.gx)
			it.gy = int(it.gy)
			if _inb(it, it.gx, it.gy) and _overlaps(list, it, it.gx, it.gy).is_empty():
				list.append(it)
				continue
		later.append(it)
	var over: Array = []
	for it in later:
		if not _fit(list, it):
			over.append(it)
	return over


func _bag_free() -> int:
	var n := BAG_W * BAG_H
	for it in P.bag:
		var s := _isize(it)
		n -= s.x * s.y
	return n


func _toggle_inv() -> void:
	if inv_open and not held.is_empty():
		if not _fit(P.bag, held):
			_drop(P.pos + Vector2(P.face * 12, 4), held)
		held = {}
	inv_open = not inv_open
	inv_ctl.visible = inv_open
	newchar_confirm = ""
	inv_ctl.queue_redraw()


func _inv_o() -> Vector2:
	return ((get_viewport_rect().size - Vector2(608, 328)) / 2.0).floor()


func _eq_rect(s: String) -> Rect2:
	var o := _inv_o()
	match s:
		"weapon": return Rect2(o + Vector2(14, 44), Vector2(40, 60))
		"body": return Rect2(o + Vector2(60, 44), Vector2(40, 60))
		"feet": return Rect2(o + Vector2(106, 44), Vector2(40, 40))
		"belt": return Rect2(o + Vector2(60, 112), Vector2(40, 20))
	return Rect2()


## 滑鼠在背包畫面的哪裡
func _inv_hit(mp: Vector2) -> Dictionary:
	var o := _inv_o()
	if Rect2(o + Vector2(548, 6), Vector2(52, 18)).has_point(mp):
		return {"w": "close"}
	if not Rect2(o, Vector2(608, 328)).has_point(mp):
		return {"w": "out"}
	for s in P.equip:
		if _eq_rect(s).has_point(mp):
			return {"w": "equip", "slot": s, "it": P.equip[s]}
	for g in [["bag", o + Vector2(160, 44), P.bag], ["stash", o + Vector2(160, 154), town.stash]]:
		if g[0] == "stash" and zone != "town":
			continue
		var org: Vector2 = g[1]
		if Rect2(org, Vector2(BAG_W, BAG_H) * CELL).has_point(mp):
			var c := Vector2i(((mp - org) / CELL).floor())
			for it in g[2]:
				var s2 := _isize(it)
				if Rect2i(int(it.gx), int(it.gy), s2.x, s2.y).has_point(c):
					return {"w": g[0], "it": it, "org": org, "list": g[2]}
			return {"w": g[0], "it": {}, "org": org, "list": g[2]}
	if zone == "town" and Rect2(o + Vector2(160, 250), Vector2(200, 24)).has_point(mp):
		return {"w": "craft"}
	if zone == "town" and Rect2(o + Vector2(14, 292), Vector2(64, 22)).has_point(mp):
		return {"w": "new", "cls": "peter"}
	if zone == "town" and Rect2(o + Vector2(84, 292), Vector2(64, 22)).has_point(mp):
		return {"w": "new", "cls": "paul"}
	return {"w": "panel"}


## 拿著東西時，放下去會落在哪一格（以游標為中心）
func _drop_cell(org: Vector2, mp: Vector2) -> Vector2i:
	var s := _isize(held)
	var tl: Vector2 = mp - Vector2(s) * CELL / 2.0
	return Vector2i(clampi(roundi((tl.x - org.x) / CELL), 0, BAG_W - s.x), clampi(roundi((tl.y - org.y) / CELL), 0, BAG_H - s.y))


func _inv_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		inv_test_mp = Vector2.INF
		inv_ctl.queue_redraw()
		return
	if not (ev is InputEventMouseButton and ev.pressed):
		return
	if ev.button_index != MOUSE_BUTTON_LEFT and ev.button_index != MOUSE_BUTTON_RIGHT:
		return
	_inv_click(_inv_hit(ev.position), ev.position, ev.button_index == MOUSE_BUTTON_RIGHT)
	inv_ctl.queue_redraw()


func _inv_say(s: String) -> void:
	inv_msg = s
	inv_msg_until = t + 2.5


func _inv_click(h: Dictionary, mp: Vector2, right: bool) -> void:
	var it: Dictionary = h.get("it", {})
	var w: String = h.w
	if w != "new":
		newchar_confirm = ""
	match w:
		"close":
			_toggle_inv()
			return
		"out":
			# 拿著東西點外面：丟在地上
			if not held.is_empty():
				_drop(P.pos + Vector2(P.face * 12, 4), held)
				held = {}
		"equip":
			var s: String = h.slot
			if held.is_empty():
				if not it.is_empty():
					if right:
						if _fit(P.bag, it):
							P.equip[s] = {}
						else:
							_inv_say("背包放不下")
					else:
						held = it
						P.equip[s] = {}
			elif held.rarity == "rune":
				if it.is_empty() or not _socket(it, held.letter):
					_inv_say("這件沒有空的孔")
				else:
					held = {}
			elif held.slot == s:
				P.equip[s] = held
				held = it
			else:
				_inv_say("這件要穿在「%s」" % SLOT_NAME.get(held.slot, ""))
			_recalc()
		"bag", "stash":
			var list: Array = h.list
			if held.is_empty():
				if it.is_empty():
					return
				if right:
					_inv_quick(it, list, w)
				else:
					list.erase(it)
					held = it
			else:
				var c := _drop_cell(h.org, mp)
				var ov := _overlaps(list, held, c.x, c.y)
				if ov.is_empty():
					held.gx = c.x
					held.gy = c.y
					list.append(held)
					held = {}
				elif ov.size() == 1:
					var o2: Dictionary = ov[0]
					if held.rarity == "rune" and _socket(o2, held.letter):
						held = {}
					else:
						list.erase(o2)
						held.gx = c.x
						held.gy = c.y
						list.append(held)
						held = o2
				else:
					_inv_say("放不下")
		"craft":
			if town.freed.size() < 3:
				_inv_say("城裡有 3 位以上被釋放的人，才會有工匠")
			elif held.is_empty():
				_inv_say("把白色的武器或外衣拿起來，放到這裡")
			elif held.rarity != "normal" or not (held.slot in ["weapon", "body"]) or not held.runes.is_empty():
				_inv_say("工匠只替還沒鑲東西的白色武器、外衣打孔")
			elif int(held.sockets) >= (4 if held.slot == "weapon" else 3):
				_inv_say("已經打滿了")
			else:
				held.sockets = int(held.sockets) + 1
				held.name = "有 %d 個孔的%s" % [held.sockets, held.base]
				_inv_say("工匠打好了一個孔")
				Sfx.play("chest", 0.0)
		"new":
			var cls: String = h.cls
			if newchar_confirm != cls:
				newchar_confirm = cls
				return
			_start_new_char(cls)
			return
	_save()


## 右鍵：直接穿上；符文直接鑲進去；倉庫的拿到背包
func _inv_quick(it: Dictionary, list: Array, where: String) -> void:
	if where == "stash":
		list.erase(it)
		if not _fit(P.bag, it):
			list.append(it)
			_inv_say("背包放不下")
		return
	if it.rarity == "rune":
		for s in ["weapon", "body"]:
			if not P.equip[s].is_empty() and _socket(P.equip[s], it.letter):
				list.erase(it)
				_recalc()
				return
		_inv_say("身上的武器、外衣沒有空的孔")
		return
	var s2: String = it.slot
	var old: Dictionary = P.equip[s2]
	list.erase(it)
	P.equip[s2] = it
	if not old.is_empty():
		old.gx = it.gx
		old.gy = it.gy
		if not (_inb(old, old.gx, old.gy) and _overlaps(list, old, old.gx, old.gy).is_empty()):
			if not _fit(list, old):
				_drop(P.pos + Vector2(P.face * 12, 4), old)
				old = {}
		else:
			list.append(old)
	_recalc()


func _start_new_char(cls: String) -> void:
	if not held.is_empty():
		_fit(P.bag, held)
		held = {}
	var lost := 0
	for it in P.bag:
		if not _fit(town.stash, it):
			lost += 1
	town.chars = int(town.chars) + 1
	_new_char(cls)
	_toggle_inv()
	_enter("town", Vector2(320, 260))
	_say("新的宣教士出發了：%s（第 %d 位）。前一位背包裡的東西都放進倉庫了（林前 3:6）%s" % [P.name, int(town.chars), "" if lost == 0 else "，有 %d 件放不下" % lost], 5.0)
	_save()


## 換上這件會怎樣（真的換一下再算回來）
func _swap_delta(slot: String, it: Dictionary) -> Array:
	var keep_hp: float = P.hp
	var keep_mp: float = P.mp
	var a := [float(P.dmin) + float(P.dmax), float(P.hpmax), float(P.armor), float(P.mpmax), float(P.speed), float(P.aspd), float(P.regen)]
	var old: Dictionary = P.equip[slot]
	P.equip[slot] = it
	_recalc()
	var b := [float(P.dmin) + float(P.dmax), float(P.hpmax), float(P.armor), float(P.mpmax), float(P.speed), float(P.aspd), float(P.regen)]
	P.equip[slot] = old
	_recalc()
	P.hp = keep_hp
	P.mp = keep_mp
	var names := ["平均傷害", "生命", "防護", "靈力", "移動", "出手 %", "每秒回血"]
	var out: Array = []
	for i in a.size():
		var dv: float = (b[i] - a[i]) * (0.5 if i == 0 else 1.0)
		if absf(dv) >= 0.5:
			out.append(["%s %s%d" % [names[i], "+" if dv > 0 else "", roundi(dv)], Color("7af0a0") if dv > 0 else C_RED])
	if out.is_empty():
		out.append(["數值差不多", C_INK])
	return out


func _txt(c: CanvasItem, p: Vector2, s: String, size: int, col: Color) -> void:
	c.draw_string_outline(UIKit.font(), p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color.BLACK)
	c.draw_string(UIKit.font(), p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _txtc(c: CanvasItem, p: Vector2, s: String, size: int, col: Color) -> void:
	var w := UIKit.font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_txt(c, p - Vector2(w / 2.0, 0), s, size, col)


func _button(c: CanvasItem, r: Rect2, s: String, size: int, lit: bool) -> void:
	c.draw_rect(r, Color("2a1a14") if lit else Color("140c10"))
	c.draw_rect(r, C_GOLD if lit else Color("6a5a50"), false, 1.0)
	_txtc(c, r.get_center() + Vector2(0, size * 0.4), s, size, C_CREAM)


## 一件東西的小圖（武器、外衣、鞋、腰帶、符文），加上孔
func _draw_item(c: CanvasItem, it: Dictionary, r: Rect2) -> void:
	var col := _item_color(it)
	c.draw_rect(r.grow(-1), Color(col, 0.14))
	c.draw_rect(r.grow(-1), Color(col, 0.55), false, 1.0)
	var m := r.get_center()
	var ink: Color = col.lerp(Color.WHITE, 0.15)
	match str(it.get("slot", "")):
		"weapon":
			c.draw_line(Vector2(m.x - 3, r.end.y - 5), Vector2(m.x + 3, r.position.y + 7), Color("9a7a4a"), 3.0)
			c.draw_rect(Rect2(Vector2(m.x + 1, r.position.y + 4), Vector2(5, 6)), ink)
		"body":
			c.draw_rect(Rect2(r.position + Vector2(5, 8), Vector2(r.size.x - 10, 7)), ink)
			c.draw_rect(Rect2(r.position + Vector2(10, 12), Vector2(r.size.x - 20, r.size.y - 18)), ink)
			c.draw_rect(Rect2(Vector2(m.x - 2, r.position.y + 8), Vector2(4, 4)), Color("140c10"))
		"feet":
			c.draw_rect(Rect2(r.position + Vector2(6, 12), Vector2(10, 18)), ink)
			c.draw_rect(Rect2(r.position + Vector2(22, 10), Vector2(10, 18)), ink)
		"belt":
			c.draw_rect(Rect2(r.position + Vector2(3, 7), Vector2(r.size.x - 6, 6)), ink)
			c.draw_rect(Rect2(Vector2(m.x - 3, r.position.y + 5), Vector2(6, 10)), C_GOLD, false, 1.0)
		"rune":
			c.draw_circle(m, 7.0, Color("2a1a14"))
			c.draw_circle(m, 6.0, Color("ffcf80"))
			_txtc(c, m + Vector2(0, 3.5), str(it.letter), 9, Color("2a1a14"))
	var n := int(it.get("sockets", 0))
	if n > 0:
		var cols := 1 if r.size.x < 30.0 else 2
		var rows := ceili(n / float(cols))
		for i in n:
			var p := m + Vector2((i % cols - (cols - 1) / 2.0) * 14.0, (i / cols - (rows - 1) / 2.0) * 14.0)
			c.draw_circle(p, 5.0, Color(0, 0, 0, 0.75))
			c.draw_arc(p, 5.0, 0, TAU, 12, Color("8a7a70"), 1.0)
			if i < it.runes.size():
				_txtc(c, p + Vector2(0, 3), str(it.runes[i]), 8, C_RUNE)


func _grid(c: CanvasItem, org: Vector2, list: Array, label: String, mp: Vector2) -> void:
	_txt(c, org + Vector2(0, -4), label, 8, C_GOLD)
	for x in BAG_W:
		for y in BAG_H:
			var r := Rect2(org + Vector2(x, y) * CELL, Vector2(CELL, CELL))
			c.draw_rect(r, Color("18121a"))
			c.draw_rect(r, Color("2e2428"), false, 1.0)
	# 拿著東西：先畫出會放在哪（綠：放得下；紅：放不下）
	if not held.is_empty() and Rect2(org, Vector2(BAG_W, BAG_H) * CELL).has_point(mp):
		var cc := _drop_cell(org, mp)
		var ok := _overlaps(list, held, cc.x, cc.y).size() <= 1
		c.draw_rect(Rect2(org + Vector2(cc) * CELL, Vector2(_isize(held)) * CELL), Color(0.3, 0.9, 0.4, 0.25) if ok else Color(0.9, 0.2, 0.2, 0.3))
	for it in list:
		_draw_item(c, it, Rect2(org + Vector2(int(it.gx), int(it.gy)) * CELL, Vector2(_isize(it)) * CELL))


func _tooltip(c: CanvasItem, it: Dictionary, at: Vector2, w: float) -> void:
	var f := UIKit.font()
	var y := at.y
	var lines := _item_lines(it)
	for k in lines.size():
		var fs := 11 if k == 0 else 9
		var s: String = str(lines[k])
		c.draw_multiline_string(f, Vector2(at.x, y + fs), s, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, _item_color(it) if k == 0 else C_INK)
		y += f.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y + 1.0
	var slot: String = str(it.get("slot", ""))
	if not P.equip.has(slot) or is_same(P.equip[slot], it):
		return
	y += 8.0
	_txt(c, Vector2(at.x, y + 9), "── 換上之後 ──", 9, C_GOLD)
	y += 13.0
	for d in _swap_delta(slot, it):
		_txt(c, Vector2(at.x, y + 9), d[0], 9, d[1])
		y += 12.0
	var cur: Dictionary = P.equip[slot]
	if not cur.is_empty():
		y += 4.0
		_txt(c, Vector2(at.x, y + 9), "現在穿的：", 9, Color("b0a090"))
		_txt(c, Vector2(at.x + 56, y + 9), cur.name, 9, _item_color(cur))


func _draw_inv() -> void:
	var c := inv_ctl
	var o := _inv_o()
	var mp := c.get_local_mouse_position() if inv_test_mp == Vector2.INF else inv_test_mp
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0, 0, 0, 0.35))
	c.draw_rect(Rect2(o, Vector2(608, 328)), Color(0.07, 0.05, 0.08, 0.97))
	c.draw_rect(Rect2(o, Vector2(608, 328)), C_GOLD, false, 1.0)
	var C: Dictionary = CLASSES[P.cls]
	_txt(c, o + Vector2(14, 22), "%s　Lv%d" % [P.name, int(P.lv)], 12, C_GOLD)
	_txt(c, o + Vector2(92, 22), C.desc, 8, Color("b0a090"))
	_button(c, Rect2(o + Vector2(548, 6), Vector2(52, 18)), "關閉 I", 9, false)
	# 人偶：身上穿的
	for s in P.equip:
		var r := _eq_rect(s)
		c.draw_rect(r, Color("18121a"))
		var lit: bool = not held.is_empty() and (held.get("slot", "") == s or (held.rarity == "rune" and s in ["weapon", "body"]))
		c.draw_rect(r, C_GOLD if lit else Color("5a4a40"), false, 1.0)
		_txt(c, r.position + Vector2(1, -2), SLOT_NAME[s], 7, Color("8a7a70"))
		if not P.equip[s].is_empty():
			_draw_item(c, P.equip[s], r)
	var y := o.y + 150.0
	for line in ["傷害 %d～%d" % [roundi(float(P.dmin)), roundi(float(P.dmax))], "生命 %d" % roundi(float(P.hpmax)), "靈力 %d" % roundi(float(P.mpmax)),
			"防護 %d" % roundi(float(P.armor)), "出手 +%d%%" % roundi(float(P.aspd)), "移動 %d" % roundi(float(P.speed)), "每秒回血 %.1f" % (0.4 + float(P.regen))]:
		_txt(c, Vector2(o.x + 14, y), line, 9, C_INK)
		y += 13.0
	# 背包、倉庫、工匠
	_grid(c, o + Vector2(160, 44), P.bag, "背包", mp)
	if zone == "town":
		_grid(c, o + Vector2(160, 154), town.stash, "倉庫（每一位宣教士共用）", mp)
		var has_smith: bool = town.freed.size() >= 3
		_button(c, Rect2(o + Vector2(160, 250), Vector2(200, 24)), "工匠：白色裝備放這裡打一個孔" if has_smith else "工匠（被釋放的人 3 位以上才有）", 8, has_smith and not held.is_empty())
		_txt(c, o + Vector2(14, 286), "開新角色（城和倉庫留著）", 8, C_GOLD)
		_button(c, Rect2(o + Vector2(14, 292), Vector2(64, 22)), "真的？再按" if newchar_confirm == "peter" else "新的彼得", 9, newchar_confirm == "peter")
		_button(c, Rect2(o + Vector2(84, 292), Vector2(64, 22)), "真的？再按" if newchar_confirm == "paul" else "新的保羅", 9, newchar_confirm == "paul")
	else:
		_txt(c, o + Vector2(160, 168), "倉庫、工匠、開新角色都在城裡（T 回城）", 8, Color("8a7a70"))
	c.draw_multiline_string(UIKit.font(), o + Vector2(160, 292), "左鍵拿起、放下；右鍵直接穿上（符文直接鑲進去、倉庫的拿進背包）；拿著東西點外面＝丟在地上", HORIZONTAL_ALIGNMENT_LEFT, 200, 8, -1, Color("8a7a70"))
	# 右邊：滑過去的東西（拿著的優先）
	var hv := _inv_hit(mp)
	var show: Dictionary = held if not held.is_empty() else hv.get("it", {})
	if not show.is_empty():
		_tooltip(c, show, o + Vector2(376, 34), 222)
	else:
		_txt(c, o + Vector2(376, 46), "滑鼠指著一件東西看說明", 9, Color("8a7a70"))
	if t < inv_msg_until:
		_txtc(c, Vector2(o.x + 304, o.y + 322), inv_msg, 10, C_RED)
	# 拿著的東西跟著游標
	if not held.is_empty():
		var hs := Vector2(_isize(held)) * CELL
		_draw_item(c, held, Rect2(mp - hs / 2.0, hs))


# ---------------------------------------------------------------- 測試機器人
func _bot_equip(it: Dictionary) -> void:
	if it.rarity == "rune":
		for s in ["weapon", "body"]:
			var tgt: Dictionary = P.equip[s]
			if not tgt.is_empty() and tgt.rarity != "runeword" and int(tgt.get("sockets", 0)) > tgt.runes.size():
				var want := ""
				for RW in RUNEWORDS:
					if RW.slot == s and RW.word.length() == int(tgt.sockets):
						want = RW.word
				var nxt: String = want.substr(tgt.runes.size(), 1) if want != "" else it.letter
				if it.letter == nxt and _socket(tgt, it.letter):
					P.bag.erase(it)
					_recalc()
					return
		return
	var cur: Dictionary = P.equip[it.slot]
	if _score(it) > _score(cur):
		P.bag.erase(it)
		P.equip[it.slot] = it
		if not cur.is_empty():
			_fit(P.bag, cur)
		_recalc()
		# 新的有孔：把背包裡的符文試著鑲上去
		for r in P.bag.filter(func(x): return x.rarity == "rune"):
			_bot_equip(r)


func _score(it: Dictionary) -> float:
	if it.is_empty():
		return -1.0
	var s := float(it.get("min", 0)) + float(it.get("max", 0)) + float(it.get("armor", 0)) * 1.5
	for k in it.mods:
		s += float(it.mods[k]) * 0.5
	if it.rarity == "unique" or it.rarity == "runeword":
		s += 40.0
	if int(it.get("sockets", 0)) >= 3 and it.rarity == "normal":
		s += 6.0 + it.runes.size() * 8.0
	return s


func _bot(dt: float) -> void:
	if float(P.hp) <= 0.0 or inv_open:
		return
	# 卡住了（兩秒沒動）：放棄要撿的東西、換個方向
	bot_stuck_t += dt
	if bot_stuck_t > 2.0:
		if P.pos.distance_to(bot_last_pos) < 4.0 and move_target != Vector2.INF:
			for dr in drops.duplicate():
				if dr.pos.distance_to(move_target) < 2.0:
					drops.erase(dr)
			move_target = P.pos + Vector2.from_angle(randf() * TAU) * 60.0
		bot_stuck_t = 0.0
		bot_last_pos = P.pos
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
	if _bag_free() < 12:
		# 背包快滿：丟掉白色沒孔的、太多的符文，還不夠就丟藍色的
		var cnt := {}
		for it in P.bag.duplicate():
			if it.rarity == "rune":
				cnt[it.letter] = int(cnt.get(it.letter, 0)) + 1
				if int(cnt[it.letter]) > 2:
					P.bag.erase(it)
			elif it.rarity == "normal" and int(it.get("sockets", 0)) == 0:
				P.bag.erase(it)
			elif it.rarity == "magic" and _bag_free() < 8:
				P.bag.erase(it)
	for dr in drops:
		var full: bool = not _fit(P.bag, dr.item, false) if dr.item.rarity != "food" else int(P.get(dr.item.food, 0)) >= 5
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
		if P.cls == "paul":
			if float(P.hp) < float(P.hpmax) * 0.4:
				_cast("grace", P.pos)
			if cnt >= 3:
				_cast("blind", near.pos)
				_cast("fight", P.pos)
			if float(near.dot_t) <= 0.0 and float(P.mp) > 14.0:
				_cast("rebuke", near.pos)
		else:
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
	if smoke_shot != "" and (smoke_frames in [60, 600, 1500, smoke_max - 10] or (shots_every > 0 and smoke_frames % shots_every == 0)):
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_%d.png" % smoke_frames))
	if OS.get_cmdline_user_args().has("--invtest") and smoke_frames == 30:
		_inv_test()
	if smoke_frames == smoke_max / 2 and smoke_shot != "":
		_toggle_inv()
		# 截圖時假裝滑鼠指著背包裡的第一件（看說明、比較）
		for it in P.bag:
			if it.rarity != "rune":
				inv_test_mp = _inv_o() + Vector2(160, 44) + (Vector2(int(it.gx), int(it.gy)) + Vector2(_isize(it)) / 2.0) * CELL
				break
	if smoke_frames == smoke_max / 2 + 30 and smoke_shot != "":
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_inv.png"))
		_toggle_inv()
	if smoke_frames >= smoke_max:
		var eq := []
		for s in P.equip:
			if not P.equip[s].is_empty():
				eq.append(P.equip[s].name)
		print("ARPG DONE cls=%s t=%.0f lv=%d zone=%s stats=%s freed_town=%d equip=%s bag=%d" % [P.cls, t, int(P.lv), zone, stats, town.freed.size(), eq, P.bag.size()])
		get_tree().quit()


## 測試：背包的每一種點法（--invtest）
func _inv_test() -> void:
	zone = "town"
	for i in 3:
		town.freed.append({"name": "測試", "line": "", "tint": [1, 1, 1], "from": ""})
	_toggle_inv()
	var o := _inv_o()
	var bag := o + Vector2(160, 44)
	var w := _make_base("weapon", 1, 3)
	w.sockets = 3
	w.name = "有 3 個孔的牧人的杖"
	_fit(P.bag, w)
	for L in ["Φ", "Ω", "Σ"]:
		_fit(P.bag, _rune_item(L))
	var body := _make_base("body", 2, 6)
	_fit(P.bag, body)
	print("INV bag=%d free=%d" % [P.bag.size(), _bag_free()])
	# 右鍵穿上杖：舊的木槳回到背包
	_inv_click(_inv_hit(bag + Vector2(int(w.gx), int(w.gy)) * CELL + Vector2(10, 10)), Vector2.ZERO, true)
	print("INV weapon=%s bag=%d" % [P.equip.weapon.name, P.bag.size()])
	# 左鍵拿起符文，放到身上的武器（照順序）
	for L in ["Φ", "Ω", "Σ"]:
		var r: Dictionary = P.bag.filter(func(x): return x.get("letter", "") == L)[0]
		var p := bag + Vector2(int(r.gx), int(r.gy)) * CELL + Vector2(10, 10)
		_inv_click(_inv_hit(p), p, false)
		var e := _eq_rect("weapon").get_center()
		_inv_click(_inv_hit(e), e, false)
	print("INV weapon=%s rarity=%s held=%s" % [P.equip.weapon.name, P.equip.weapon.rarity, held.is_empty()])
	# 拿起外衣，換到身上（舊的到手上），再放回背包空的地方
	var bp := bag + Vector2(int(body.gx), int(body.gy)) * CELL + Vector2(10, 10)
	_inv_click(_inv_hit(bp), bp, false)
	var be := _eq_rect("body").get_center()
	_inv_click(_inv_hit(be), be, false)
	print("INV body=%s held=%s" % [P.equip.body.name, held.get("name", "")])
	var empty := bag + Vector2(8, 2) * CELL + Vector2(10, 10)
	_inv_click(_inv_hit(empty), empty, false)
	print("INV held_after=%s bag=%d" % [held.get("name", ""), P.bag.size()])
	# 工匠：拿起白色外衣打孔，再丟到地上
	var old: Dictionary = P.bag.filter(func(x): return x.get("slot", "") == "body")[0]
	var op := bag + Vector2(int(old.gx), int(old.gy)) * CELL + Vector2(10, 10)
	_inv_click(_inv_hit(op), op, false)
	var cp := o + Vector2(260, 260)
	_inv_click(_inv_hit(cp), cp, false)
	print("INV crafted=%s sockets=%d" % [held.get("name", ""), int(held.get("sockets", 0))])
	_inv_click(_inv_hit(Vector2(2, 2)), Vector2(2, 2), false)
	print("INV dropped=%d held=%s" % [drops.size(), held.is_empty()])
	# 倉庫：右鍵拿進背包
	var st := _make_base("feet", 1, 4)
	_fit(town.stash, st)
	var sp := o + Vector2(160, 154) + Vector2(int(st.gx), int(st.gy)) * CELL + Vector2(10, 10)
	_inv_click(_inv_hit(sp), sp, true)
	print("INV stash=%d bag_has_feet=%s" % [town.stash.size(), P.bag.has(st)])
	# 開新角色：保羅
	var np := o + Vector2(100, 300)
	_inv_click(_inv_hit(np), np, false)
	_inv_click(_inv_hit(np), np, false)
	print("INV newchar=%s cls=%s stash=%d inv_open=%s" % [P.name, P.cls, town.stash.size(), inv_open])
