extends Node2D
## 主遊戲：移動、同伴招募與升級、自動攻擊、四種敵人與打散、同心合意與五旬節 FEVER、失敗。
## 數值全部來自 data/game.json。

const ZOOM := 2.5           # 鏡頭拉近、像素放大，畫面比較乾淨
const ZOOM_PORTRAIT := 1.9   # 直式畫面窄，鏡頭拉遠一點才看得到兩側的敵人
const CHUNK := 96
const SEP_CELL := 8.0
const DATA_PATH := "res://data/game.json"
## 隊形：同伴依加入順序站到這些位置（相對保羅）
const SLOTS := [Vector2(-32, 12), Vector2(32, 11), Vector2(-28, -14), Vector2(27, -15), Vector2(0, -28), Vector2(-9, 29)]   # 人物圖 0.45 起變大，隊形也拉開一點

const C_GOLD := Color("ffd75e")
const C_CREAM := Color("fff4c2")
const C_SKY := Color("4fd8ff")
const C_HEAL := Color("7be08a")
const C_RED := Color("e8481c")
const C_FLAME := Color("ff8a2a")
const C_VL := Color("6b3a8c")
const SHARE_URL := "https://windsjp00171-star.github.io/acts-survivors/"

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
var fever_ext := 0.0        # 這次五旬節已經延長了幾秒
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
var banishes_left := 0   # 放逐：這一局不再出現某張卡
var banished: Array = []  # "kind:key"
var t_start := 0.0
var hits: Array = []      # Boss 攻擊落下的閃光

var paul := {}
var pa := {}              # 保羅自己的攻擊（書信），用和同伴一樣的出招流程
var first_recruit := ""
var solo := false         # 這一關只有主角一個人（劇情模式的大馬色、雅典）
var story := false        # 劇情模式
var chapter := {}         # 劇情模式的這一章（data/story.json）
var story_idx := -1       # 劇情模式第幾章（0 起算）
# 劇情模式裡，各個系統從第幾章（0 起算）開始出現：第一章只要懂走路、選卡、帶同伴
const STORY_GATE := {"bond": 1, "fruit": 2, "armor": 2, "school": 4, "link": 9}
var vision_on := false    # 對話時畫出光中的耶穌（關卡的 vision 列出哪段對話要畫）
var tongues: Array = []   # 五旬節：落在頭上的火焰 {who, t}
var sheets: Array = []    # 約帕：天上降下的大布 {pos, t, max}
var chariot_done := false # 撒馬利亞：曠野的車出現過了
var dmg_log := {}        # 測試用：主角被各種來源打掉的血
var journey_step := 0     # 安提阿：0 還叫掃羅、1 改稱保羅、2 馬可離隊
var smoke_max_frames := 1800
var bot := false            # 測試用：比較會玩的機器人（--bot）
var leader := "paul"      # 這一局的主角（同伴的 key；預設保羅）
var stage := {}           # 這一局的城市（data/stages.json）
var stage_i := 0
var epistles := {}        # 已選的書信卡效果
var founded_now := false  # 這局建立了新的教會
var trials: Array = []    # 這局套用的信心等級限制（id）
var faith := 0            # 信心等級
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
var impacts: Array = []   # 投射物打中的地方：一圈光、往前噴的光芒（只是畫面，不影響傷害）
var blasting := false     # 輔助「爆裂」的連帶傷害進行中（避免連鎖爆炸無限觸發）
var smite_cd := 0.0       # 醫治「鞭傷」的冷卻
var atone_cd := 0.0       # 醫治「以善勝惡」的冷卻
var guard_slow_t := 0.0   # 守護「四圍的火城」的間隔
const IMPACT_COL := {"letter": Color("fff4c2"), "vial": Color("8ae0d0"), "stone": Color("d8d0c0"), "coin": Color("ffd75e"),
	"pilum": Color("e0e0e8"), "fig": Color("c87ac8"), "errand": Color("d8a860")}
var tag_fx: Array = []    # 流派專屬連結效果的小字
var dnums: Array = []     # 跳出來的傷害數字
var gem_chain := 0         # 連續撿經驗：音一階一階往上
var gem_last := -9.0
const GEM_STEPS := [1.0, 1.122, 1.26, 1.498, 1.682, 2.0, 2.245, 2.52]   # 五聲音階（do re mi sol la do' re' mi'）
var guard := 0            # 守護連結給的護盾層數
var still_t := 0.0        # 隊伍停下來多久了（吳文水、雅各的「引導」）
var harp_t := 0.0         # 耶杜頓的琴聲還剩幾秒
var harp_chance := 0.0
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
var EV: Dictionary          # data/events.json
var event_t := 0.0          # 下一次局內事件的時間（距離開局的秒數）
var events_done: Array = []
var enemy_hp_bonus := 0.0   # 事件：之後的敵人血量增加
var move_bonus := 0.0       # 事件：主角移速
var prov_bread := 0.0       # 這局帶回的餅加成（舊的市集行囊用過；現在固定 0）
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
var film := false          # 測試用：錄影模式
var auto_lite := false    # 畫面一直卡（每秒不到 40 格超過 3 秒）：這一局自動改用特效精簡
var low_fps_t := 0.0
var perf := false          # 測試用：--perf 每 300 格印出各部分平均花多少時間
var perf_us := {}
var perf_n := 0
var hitstop := 0.0        # 打擊停頓：大的命中讓整個畫面停一下下（秒）
var hitstop_cd := 0.0
var poofs: Array = []    # 被驅散的敵人：壓扁、往上淡出（0.3 秒）
var chunks := {}
var solids: Array = []      # 擋路的物件（石柱、石牆）：Rect2
var wind_t := 8.0           # 米利大的暴風：倒數到下一陣風
var wind_on := 0.0          # 這一陣風還剩幾秒
var wind_dir := Vector2.RIGHT
var chunk_timer := 0.0
var joy := {"on": false, "index": -1, "origin": Vector2.ZERO, "pos": Vector2.ZERO}

var world: Node2D
var ground: Sprite2D
var ground_fx: Node2D
var decals: Node2D
var air: Node2D
var cam: Camera2D
var ui: GameUI

# 自動測試用（godot -- --smoke）
# 流派規則（data/game.json 的 schools）：同流派 2/3/4 人啟動、升級
var school_tier := {}      # 流派 → 0..3
var pa_free: Array = []    # 主角不佔格就帶著的流派（主角本身的流派、恩賜「規則改寫」）
var fusions_on := {}       # 已經融合的流派組合 "講道+詩歌" → true
var fz_count := {}         # 融合名稱 → 這局發動幾次（結算顯示）
var fz_tag_t := {}         # 融合名稱 → 下次可以再冒小字的時間
var fz_beat := 0           # 讚美為盾：數重拍
var fz_heal_t := 0.0       # 悔改得醫治：回血間隔
var fz_guard_t := 0.0      # 弟兄守望：護盾間隔
var fz_pair_t := 5.0       # 兩個兩個：招小門徒間隔
var school_mods := {}      # 流派卡與恩賜第 5 層改寫的數值（加上去）
var school_cards := {}     # 已拿過的流派卡 "流派:id"
var praise := 0.0          # 詩歌：讚美
var anoint := 0.0          # 醫治：恩膏
var guard_regen := 0.0     # 守護：下一層護盾長回來的倒數
var trail: Array = []      # 差派：腳蹤 {pos, life, max}
var trail_t := 0.0
var trail_tick := 0.0
var minions: Array = []    # 門徒：小門徒 {pos, life, cd, hop}
var minion_strike_t := 0.0
var beat_clock := 0.0      # 詩歌：拍子時鐘（有音樂時跟著音樂）
var beat_last_mpos := -1.0
var beat_i := -1
var beat_now := false      # 這一格剛好落在拍子上
var beat_down := false     # 而且是重拍
var songs: Array = []      # 全場詩歌的畫面
var holies: Array = []     # 聖光的畫面
var run_converts := 0
var run_minions := 0
var run_songs := 0
var run_holies := 0
var run_shocks := 0
# 同行合擊（data/game.json 的 bonds）
var bond_cd := {}          # 第幾組 → 下次可以發動的時間
var bond_buff := {}        # 同伴 key → 加倍剩下的秒數
var bonds_seen := {}
var crit_t := 0.0          # 全隊會心一擊剩下的秒數
var feast_t := 0.0         # 掉兩倍經驗剩下的秒數
var run_bonds := 0
var rains: Array = []      # 義人的禱告：天降大雨的畫面
var star_t := 10.0         # 拔摩海島：下一次星辰墜落的倒數
var star_falls: Array = [] # 正在墜落的星 {pos, t, max, r, dmg}
var lamp_tick := 0.0
# 新的攻擊方式
var boomers: Array = []    # 馬可的皮袋
var trees: Array = []      # 撒該的桑樹
var zones: Array = []      # 馬利亞的香氣
var jars: Array = []       # 基甸的瓶子
var fishes: Array = []     # 約拿的大魚
var floods: Array = []     # 挪亞的洪水
var cones: Array = []      # 米利暗的鼓聲（畫面）
# 各城的關卡機制（stages.json 的 hazard）
var hz_t := -1.0           # 下一次發生的時間（距離開局的秒數）
var spots: Array = []      # 地上的壇、帳棚、火堆 {kind, pos, life, ...}
var altar_buff := 0.0      # 雅典：認識未識之神的加成剩下的秒數
# 聖物（像流亡黯道的傳奇裝備）、膏抹（輔助寶石）、屬性（燃燒、浸濕、感電）
var relics := {}           # 聖物 id → true
var relic_pending := false # 撿到的寶箱要讓你選聖物
var loaves_n := 0          # 五餅二魚：撿到的經驗
var shadow_t := 0.0
var dove_t := 0.0
var chaining := false      # 連鎖膏抹：避免一跳再跳
var elem_of := {}          # 同伴 key → fire / water / shock
var run_relics := 0
# 帶人信主與劇情對話
var talking := false       # 劇情對話中（遊戲暫停）
var seekers: Array = []    # 在尋找的人 {pos, hp, prog, def, life}
var followers: Array = []  # 信主跟著走的人 {pos, name, col}
var seek_t := -1.0
var seek_used := {}
var run_saved := 0
var run_seek_spawned := 0
var names_all := {}        # 說話的人 key → 名字（主角換人時也找得到）
# 難度導演：隊伍太強、敵人還沒走到就被打倒時，敵人慢慢變硬（站樁就過不了）
var pressure := 0.0        # 0 起跳，敵人血量 ×(1 + pressure)
var life_avg := 5.0        # 最近被打倒的敵人平均活了幾秒
var persec_t := -1.0       # 逼迫：下一次落在主角腳下的時間
# 大馬色：瞎眼（blind_state："" 沒有、"vision" 路上的大光、"blind" 看不見、"heal" 鱗片掉下、"done"）
var blind_state := ""
var blind_r := 0.0
var blind_flash := 0.0     # 大光：整個畫面亮白
var ananias := {}          # 亞拿尼亞：{pos, node}
var dark: Node2D
# 五重職事（弗 4:11）：出發前選的呼召
var calling := "apostle"
var prophecy := {}         # 先知：預言之地 {pos, r, t}
var prophecy_t := 12.0

var smoke := false
var smoke_shot := ""
var smoke_frames := 0
var smoke_preset := ""
var smoke_over := 0
var smoke_nofever := false
var fxtest := false
var keystones := {}
var waited := false   # 同心合意滿了：已經提醒過「等候父所應許的」
## 五旬節：門徒說的「鄉談」（徒 2:9–11 的地方）
const TONGUES := ["帕提亞的話", "米所波大米的話", "加帕多家的話", "埃及的話", "羅馬的話", "克里特的話", "阿拉伯的話", "本都的話"]
var overcome_cd := 0.0   # 恩賜盤上裝了哪些有代價的基石（preach、midnight、overcome、stand、pairs、cast）   # 測試：把各種技能特效擺在畫面上截圖（--fxtest，搭配 --shot）


func _ready() -> void:
	resuming = Save.resume
	Save.resume = {}
	if OS.get_cmdline_user_args().has("--resume"):
		resuming = Save.read_run_save()   # 測試用：照存檔繼續
	save_test = OS.get_cmdline_user_args().has("--save_test")
	if OS.get_cmdline_user_args().has("--daily"):
		var dly := Save.daily_today()   # 測試用：今天的每日挑戰
		Save.run_config = {"starter": str(dly.starter), "stage": int(dly.stage), "faith": 0, "endless": false,
			"calling": str(dly.calling), "daily": str(dly.date), "daily_trials": dly.trials, "daily_relic": str(dly.relic)}
		print("DAILY ", dly)
	if not resuming.is_empty():
		Save.run_config = resuming.run_config.duplicate(true)
	D = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	EV = JSON.parse_string(FileAccess.get_file_as_string("res://data/events.json"))
	event_t = float(EV.first)
	var stages: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/stages.json")).stages
	stage_i = clampi(int(Save.run_config.get("stage", 0)), 0, stages.size() - 1)
	var story_i := int(Save.run_config.get("story", -1))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			stage_i = clampi(int(a.substr(8)), 0, stages.size() - 1)
		if a.begins_with("--story="):
			story_i = int(a.substr(8))
	if story_i >= 0 and story_i < Save.story.chapters.size():
		# 劇情模式：章節決定關卡、主角與會遇到的同伴
		story = true
		story_idx = story_i
		chapter = Save.story.chapters[story_i]
		for i in stages.size():
			if stages[i].id == chapter.stage:
				stage_i = i
		Save.run_config.faith = 0
		Save.run_config.endless = false
	stage = stages[stage_i]
	solo = story and bool(chapter.get("solo", false))
	if story:
		stage.hp_mult = float(stage.hp_mult) * float(Save.story.get("hp_mult", 1.0)) * float(chapter.get("hp_mult", 1.0))
		stage.dmg_mult = float(stage.dmg_mult) * float(Save.story.get("dmg_mult", 1.0)) * float(chapter.get("dmg_mult", 1.0))
	for k in stage.weights:
		D.enemies[k].weight = stage.weights[k]
	D.boss.merge(stage.boss, true)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--boss_order="):
			# 測試用：--boss_order=barrage,wave（Boss 只出這幾招，兩個階段都一樣）
			D.boss.order = Array(a.substr(13).split(","))
			D.boss.order2 = D.boss.order
		if a == "--god":
			god_mode = true   # 測試用：主角不會倒下
	D.director.merge(stage.get("director", {}), true)
	if story:
		D.boss.hp = float(D.boss.hp) * float(Save.story.get("boss_mult", 1.0)) * float(chapter.get("boss_mult", 1.0))
	# 熬煉（難度條件）
	faith = int(Save.run_config.get("faith", 0))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--faith="):
			faith = int(a.substr(8))
			Save.run_config.faith = faith
	trials = Save.faith_ids(faith)
	if Save.run_config.has("daily"):
		trials = Array(Save.run_config.daily_trials)   # 每日挑戰：今天的兩個條件
	Save.run_config.trials = trials
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
	if trials.has("persecute"):
		D.director.persecute_every = 5
	if trials.has("elites"):
		stage.elite_mult = float(stage.get("elite_mult", 1.0)) * 0.5
	if trials.has("oath"):
		D.boss.mid.append({"at": 300, "hp_mult": 0.35})
	for dd in D.companions:
		names_all[dd.key] = dd.name
	names_all["paul"] = "保羅"
	names_all["jesus"] = "耶穌"
	names_all["ananias"] = "亞拿尼亞"
	names_all["disciple"] = "門徒"
	# 主角：選了誰，就用他的名字、招式、流派與血量速度；他這一局不再當同伴
	leader = "paul" if OS.get_cmdline_user_args().has("--smoke") else str(Save.data.get("leader", "paul"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--leader="):
			leader = a.substr(9)
	if leader != "paul" and not Save.is_unlocked("leader_" + leader) and not OS.get_cmdline_user_args().has("--smoke"):
		leader = "paul"
	if Save.run_config.has("daily"):
		leader = "paul"   # 每日挑戰大家都用保羅
	if not resuming.is_empty():
		leader = str(resuming.leader)
	if story:
		leader = str(chapter.leader)
	if stage.has("leader"):
		leader = str(stage.leader)   # 這一關的主角是固定的（拔摩海島是約翰）
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
	calling = str(Save.run_config.get("calling", Save.data.get("calling", "apostle")))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--calling="):
			calling = a.substr(10)
	Save.run_config.calling = calling
	# 永久恩典（營地建設）
	D.paul.hp = float(D.paul.hp) + Save.up_value("vigor") + Save.gift_global("hp")
	keystones = Save.board_keystones()
	if OS.get_cmdline_user_args().has("--smoke") and not keystones.is_empty():
		print("KEYSTONES ", keystones.keys(), " hp+", Save.gift_global("hp"))
	if keystones.has("midnight"):
		D.paul.hp = float(D.paul.hp) - 15.0   # 基石「半夜唱詩」的代價
	if trials.has("faithful"):
		D.paul.hp = float(D.paul.hp) * 0.7   # 信心等級：至死忠心
	D.paul.speed = float(D.paul.speed) * (1.0 + Save.up_value("run"))
	D.gems.magnet_radius = float(D.gems.magnet_radius) * (1.0 + Save.up_value("reap") + Save.building_bonus("magnet"))
	D.armor_slots = int(D.armor_slots) + int(Save.building_bonus("armor"))
	# 恩賜樹的全隊效果
	D.paul.speed = float(D.paul.speed) * (1.0 + Save.gift_global("move")) * (0.9 if keystones.has("stand") else 1.0)
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
		elif a == "--fxtest":
			fxtest = true
		elif a == "--perf":
			perf = true
		elif a == "--film":
			film = true   # 錄宣傳影片：機器人照常速玩，打擊停頓等效果照常
		elif a == "--bot":
			bot = true
			if not OS.get_cmdline_user_args().has("--film"):
				Engine.time_scale = 4.0   # 機器人模擬：時間跑快 4 倍（--film 錄影時用正常速度）
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
	first_recruit = "" if solo else starter
	if story:
		first_recruit = "" if solo or chapter.cast.is_empty() or chapter.get("late", false) else str(chapter.cast[0])
	if not resuming.is_empty():
		first_recruit = ""
	if stage.has("leader_level"):
		_set_level(pa, int(stage.leader_level))   # 年老的約翰：一開始招式就比較熟練
	# 流派長在主角的招式上：主角本身的流派、恩賜「規則改寫」的流派，一開始就成形（不佔輔助格）
	if D.schools.has(str(pa.get("tag", ""))):
		pa_free.append(str(pa.tag))
	for tag in D.schools:
		if float(school_mods.get("solo_" + tag, 0.0)) > 0.0 and not pa_free.has(tag):
			pa_free.append(tag)
	_update_schools()
	rerolls_left = Save.rerolls()
	banishes_left = 0 if Save.run_config.get("trials", []).has("simple") else int(D.leveling.get("banishes", 2))
	# 營地的倉房：開局先多選幾張升級卡（給足剛好升那幾級的經驗）
	var L0: Dictionary = D.leveling
	for k in (0 if not resuming.is_empty() else int(Save.building_bonus("picks"))):
		xp += int(L0.first + k * L0.step + pow(k, 2) * L0.growth)
	ui.dialogue_done.connect(func():
		talking = false
		vision_on = false)
	if stage.get("hazard", {}).get("kind", "") in ["blind", "journey"]:
		if stage.hazard.kind == "blind":
			blind_state = "vision"
		if leader == "paul" and ui.names.has(D.paul.name):
			ui.names[D.paul.name].text = "掃羅"   # 到徒 13:9 才開始叫保羅
			ui.hero_label.text = "掃羅"
	if resuming.is_empty():
		_start_talk("in")
	var pool: Array = D.tasks.list.duplicate()
	if story:
		# 劇情模式不出旅程任務，只有一個目標：從黑暗中贏回人（帶尋找的人信主）
		pool = []
		if not solo:
			var goal := 2 if story_idx < 3 else (3 if story_idx < 8 else 4)
			run_tasks.append({"def": {"id": "souls", "name": "從黑暗中贏回人", "stat": "saved", "goal": goal, "by": 0, "witness": 15 * goal}, "done": false, "failed": false})
	if solo:
		pool = pool.filter(func(tk): return not tk.id in ["links", "reso", "party"])   # 一個人的關卡沒有同伴
	if D.boss.get("mid", []).is_empty():
		pool = pool.filter(func(tk): return tk.id != "mid")   # 沒有中途 Boss 的關卡
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
	for a in OS.get_cmdline_user_args():
		# 測試用：--relics=hair,mantle　--anoint=tim:multi,chain
		if a.begins_with("--branch="):
			# 測試用：--branch=tim:1（強制選 Lv3 的第幾條分支）
			var bk := a.substr(9).get_slice(":", 0)
			by_key[bk].branch = int(a.substr(9).get_slice(":", 1))
			_set_level(by_key[bk], maxi(3, int(by_key[bk].level)))
		if a.begins_with("--only="):
			# 測試用：--only=tim（只留這幾位同伴，其他人不上場）
			var keep: Array = Array(a.substr(7).split(","))
			only_keys = keep
			for c in comps:
				if not keep.has(c.key) and c.level > 0:
					c.level = 0
		if a.begins_with("--mods="):
			# 測試用：--mods=march:1,heal_smite:3（直接改寫流派規則的數值）
			for kv in a.substr(7).split(","):
				school_mods[kv.get_slice(":", 0)] = float(kv.get_slice(":", 1))
		if a.begins_with("--armor="):
			# 測試用：--armor=helmet:3,breast:3
			for kv in a.substr(8).split(","):
				armor[kv.get_slice(":", 0)] = int(kv.get_slice(":", 1))
			_update_sets()
		if a.begins_with("--fruits="):
			# 測試用：--fruits=joy:5,good:3
			for kv in a.substr(9).split(","):
				fruits[kv.get_slice(":", 0)] = int(kv.get_slice(":", 1))
			_refresh_all_stats()
		if a.begins_with("--relics="):
			for id in a.substr(9).split(","):
				_take_relic(id)
		if a.begins_with("--anoint="):
			var who: String = a.substr(9).get_slice(":", 0)
			var ao := _who(who)
			if not ao.is_empty():
				ao.anoints = Array(a.substr(9).get_slice(":", 1).split(","))
				_set_level(ao, maxi(1, ao.level))
				_update_schools()
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
	if Save.run_config.has("daily") and resuming.is_empty() and D.relics.any(func(r): return r.id == str(Save.run_config.daily_relic)):
		_take_relic(str(Save.run_config.daily_relic))   # 每日挑戰：今天的聖物一開始就帶著
	if not resuming.is_empty():
		_apply_resume(resuming)
	else:
		_apply_blessing()
	for i in int(D.waves.initial):
		var a := randf() * TAU
		var d := 110.0 + randf() * 80.0
		_spawn_one(_pick_type(), Vector2(cos(a) * d, sin(a) * d * 0.7))
	_update_chunks()
	Sfx.music(stage.music)
	ground.modulate = Color(stage.tint[0], stage.tint[1], stage.tint[2])
	if not (stage.get("vision", []).has("in") and (not Save.data.get("story_seen", []).has("in_" + stage.id) or OS.get_cmdline_user_args().has("--talk"))):   # 開場是光中的耶穌時，不蓋上城名
		ui.show_banner("%s　%s%s" % [stage.name, stage.ref, ("\n信心等級 %d" % faith) if faith > 0 else ""], 2.5)


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

	decals = Node2D.new()   # 地上的小細節（裂縫、草叢、水窪……），貼在地面上、在所有東西底下
	decals.z_index = -2
	add_child(decals)

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

	dark = Node2D.new()
	dark.z_index = 30
	dark.draw.connect(_draw_dark)
	add_child(dark)

	cam = Camera2D.new()
	var vs := get_viewport().get_visible_rect().size
	cam.zoom = Vector2.ONE * (ZOOM_PORTRAIT if vs.y > vs.x else ZOOM)
	add_child(cam)
	cam.make_current()

	paul = {"name": D.paul.name, "pos": Vector2.ZERO, "hp": float(D.paul.hp), "inv": 0.0, "moving": false,
		"node": _sprite(leader + "_0", Vector2(-12, -25))}
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
			"node": _sprite(d.key + "_0", Vector2(-12, -25))}
		c.node.visible = false
		comps.append(c)
		by_key[d.key] = c
		i += 1
	for c in comps + [pa]:
		_apply_gifts(c)
	for el in ["fire", "water", "shock"]:
		for k in D.elements.get(el, []):
			elem_of[k] = el
	# 恩賜樹第 5 層：改寫流派規則
	for tag in Save.meta.gifts.board.order:
		for nd in Save.gift_nodes(tag):
			if nd.kind == "mod" and Save.gift_eff(tag, nd.id) > 0:
				for k in nd.mod:
					school_mods[k] = float(school_mods.get(k, 0.0)) + float(nd.mod[k]) * Save.gift_eff(tag, nd.id)


## 恩賜樹：依流派加上傷害、攻速、範圍、專屬連結強度與終極恩賜
func _apply_gifts(c: Dictionary) -> void:
	var per := {}
	var stats := []
	if Save.meta.gifts.board.order.has(c.tag):
		for nd in Save.gift_nodes(c.tag) + Save.gift_nodes("橋").filter(func(b): return b.tags.has(c.tag)):
			var r := Save.gift_eff(c.tag, nd.id)   # 只有裝上的節點生效
			if r <= 0 or nd.kind in ["cards", "keystone"]:
				continue
			if nd.kind == "bridge":
				per["dmg"] = float(per.get("dmg", 0.0)) + float(nd.per)
				continue
			if nd.kind == "stat":
				stats.append({"stat": nd.stat, "add": float(nd.get("add", 0.0)) * r, "mul": float(nd.get("mul", 0.0)) * r})
			elif nd.kind == "mod":
				continue
			elif nd.kind == "healmul":
				for k in ["amount", "heal", "heal_comp"]:
					stats.append({"stat": k, "add": 0.0, "mul": float(nd.per) * r})
			else:
				per[nd.kind] = float(per.get(nd.kind, 0.0)) + r * float(nd.per)
	c.tdmg = 1.0 + per.get("dmg", 0.0) + (0.4 if keystones.has("preach") and c.tag == "講道" else 0.0)
	c.aff = float(c.aff) * (1.0 + per.get("speed", 0.0)) * (0.85 if keystones.has("preach") else 1.0) * (0.75 if keystones.has("cast") and c.tag == "門徒" else 1.0)
	c.tarea = (1.0 + per.get("area", 0.0)) * (2.0 if keystones.has("cast") and c.tag == "門徒" else 1.0)
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
	ui.card_banished.connect(_banish)


# ---------- 同伴等級 ----------
func _stats(skill: String, lv: int) -> Dictionary:
	var s: Dictionary = D.skills[skill]
	var out: Dictionary = s.base.duplicate()
	for i in range(mini(lv - 1, s.levels.size())):
		out.merge(s.levels[i], true)
	return out


func _set_level(c: Dictionary, lv: int) -> void:
	if int(c.get("level", 0)) == 0 and lv > 0:
		c.name_until = t + 5.0   # 剛加入：名字顯示幾秒
	c.level = lv
	if c.skill != "":
		c.st = _stats(c.skill, lv)
		# Lv3 二選一的分支：加在數值上，之後升級也保留
		var bi: int = c.get("branch", -1)
		if bi >= 0:
			for k in D.skills[c.skill].branches[bi].add:
				c.st[k] = float(c.st.get(k, 0)) + float(D.skills[c.skill].branches[bi].add[k])
			c.branch_fx = D.skills[c.skill].branches[bi].get("onhit", [])   # 分支帶的命中效果
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
		_mod_stats(c)
	if not comps.is_empty() and not pa.is_empty():
		_update_synergy()


func _recruit(c: Dictionary) -> void:
	if solo:
		return   # 一個人的關卡：沒有同伴加入
	if not only_keys.is_empty() and not only_keys.has(c.key):
		return   # 測試用：--only
	if story and not Save.is_unlocked(c.key):
		# 劇情模式：在故事裡加入的那一刻就永久解鎖
		Save.data.unlocked.append(c.key)
		Save.save_profile()
		ui.show_banner("%s 加入了！（同伴名冊多了一位）" % c.name, 2.2)
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
	_update_schools()

## 隊伍人數（百基拉・亞居拉算一位）
func _party_count() -> int:
	var n := 0
	for c in comps:
		if c.level > 0 and c.follows == "":
			n += 1
	return n


## 果子 Lv3、Lv5 解鎖的效果（讓被動加成看得見）
func _fruit_lv(k: String) -> int:
	return int(fruits.get(k, 0))


func _update_fruits(dt: float) -> void:
	if _fruit_lv("joy") >= 3 and not choosing:
		joy_t -= dt
		if joy_t <= 0.0:
			var lv5 := _fruit_lv("joy") >= 5
			joy_t = 3.0 if lv5 else 5.0
			joy_waves.append({"pos": paul.pos, "r": 6.0, "max": 60.0 * _area(), "hit": {}, "dmg": 6.0 + level * 0.4, "stun": 0.5 if lv5 else 0.0})
			_fxc("歡呼")
	for w in joy_waves:
		w.r += 220.0 * dt
		for e in enemies.duplicate():
			if not e.dead and not w.hit.has(e.node) and e.pos.distance_to(w.pos) < w.r:
				w.hit[e.node] = true
				_hurt(e, w.dmg, w.pos)
				if w.stun > 0.0 and not e.get("boss", false):
					e.stun = maxf(e.stun, w.stun)
	joy_waves = joy_waves.filter(func(w): return w.r < w.max)
	if _fruit_lv("good") >= 5 and not choosing:
		good_heal_t -= dt
		if good_heal_t <= 0.0:
			good_heal_t = 10.0
			_heal_paul(float(D.paul.hp) * 0.06)
			for c in comps:
				if c.level > 0 and c.down <= 0.0:
					_heal_comp(c, _comp_max_hp() * 0.08)
			_ring_pop(paul.pos + Vector2(0, -6), Color("8fe08a"), 40.0)
			_fxc("良善回血")


## 果子與軍裝帶來的倍率
func _area() -> float:
	return 1.0 + fruits.get("joy", 0) * D.fruits.joy.per_level.area

func _dmg_mult() -> float:
	return (1.0 + fruits.get("faith", 0) * D.fruits.faith.per_level.damage) * (1.0 + Save.up_value("might")) * (1.0 + float(set_bonus.get("damage", 0.0)) + grace_dmg)

func _guard() -> float:
	return 1.0 + fruits.get("good", 0) * D.fruits.good.per_level.guard

func _accord() -> float:
	return (1.0 + fruits.get("peace", 0) * D.fruits.peace.per_level.accord) * (1.3 if epistles.has("accord_plus") else 1.0) * (1.0 + Save.up_value("accord")) * (1.0 + Save.gift_global("accord"))


func _fever_dur() -> float:
	return float(D.fever.duration) + (3.0 if epistles.has("fever_plus") else 0.0) + (3.0 if _fruit_lv("peace") >= 5 else 0.0) - (3.0 if trials.has("night") else 0.0)

func _scatter_mult() -> float:
	return maxf(0.3, 1.0 - fruits.get("peace", 0) * 0.1) * (0.3 if calling == "shepherd" else 1.0)

func _comp_max_hp() -> float:
	return D.companion_rules.hp * (1.0 + fruits.get("good", 0) * 0.1) * (1.3 if calling == "shepherd" else 1.0) * (1.25 if epistles.has("comp_hp") else 1.0)

func _speed() -> float:
	return D.paul.speed * (1.0 + armor.get("shoes", 0) * 0.12 + move_bonus + _sv("差派", "run") + (0.1 if epistles.has("run_plus") else 0.0)) * (0.9 if relics.has("ark") else 1.0)


## 劇情模式：這個系統在這一章開放了沒（自由模式全部開放）
func _sys_open(sys: String) -> bool:
	return not story or story_idx >= int(STORY_GATE.get(sys, 0))


## 果子卡的說明：累積多少、下一個解鎖的效果
func _fruit_desc(k: String, lv: int) -> String:
	var f: Dictionary = D.fruits[k]
	var d: String = f.desc
	var per: float = float(f.per_level.values()[0])
	if f.has("total") and lv > 0:
		d += "\n累積：" + (f.total % roundi(per * lv * 100.0)) + " → " + (f.total % roundi(per * (lv + 1) * 100.0))
	for need in [3, 5]:
		if lv < need:
			var ms: Dictionary = f.get("milestones", {}).get(str(need), {})
			if not ms.is_empty():
				d += "\n%sLv%d 解鎖「%s」：%s" % ["★ " if lv + 1 == need else "", need, ms.name, ms.desc]
			break
	return d


func _make_cards() -> Array:
	var pool := []
	for k in D.fruits:
		var f: Dictionary = D.fruits[k]
		var lv: int = fruits.get(k, 0)
		if (lv == 0 and not Save.is_unlocked("fruit_" + k)) or not _sys_open("fruit"):
			continue
		var fdesc: String = f.desc
		if lv == 0:
			for evo in D.evolutions:
				if evo.fruit == k and by_key.has(evo.companion) and by_key[evo.companion].level > 0:
					fdesc += "\n可讓%s進化（滿級時）" % by_key[evo.companion].name
					break
		if lv == 0 and fruits.size() < 6:
			pool.append({"kind": "fruit", "key": k, "title": f.name + "　新果子", "tag": f.tag, "desc": fdesc + _fruit_desc(k, 0).substr(f.desc.length())})
		elif lv > 0 and lv < 5:
			pool.append({"kind": "fruit", "key": k, "title": "%s　Lv%d → %d" % [f.name, lv, lv + 1], "tag": f.tag, "desc": _fruit_desc(k, lv)})
	for k in D.armor:
		var a: Dictionary = D.armor[k]
		var lv: int = armor.get(k, 0)
		if (lv == 0 and not Save.is_unlocked("armor_" + k)) or not _sys_open("armor"):
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
		var pe := _evo_of(pa.key)
		if pa.level == 4 and not pe.is_empty():
			pd +="\n滿級＋果子「%s」→ 進化「%s」" % [D.fruits[pe.fruit].name, pe.name]
		pool.append({"kind": "up", "key": pa.key, "title": "%s%s　Lv%d → %d" % [pa.name, "的書信" if pa.key == "paul" else "（主角）", pa.level, pa.level + 1], "tag": pa.tag, "desc": pd})
	for c in comps:
		if c.follows != "" or c.skill == "" or solo:
			continue
		if story and c.level == 0 and (not chapter.cast.has(c.key) or c.get("gone", false)):
			continue   # 劇情模式：只遇得到這一章的人
		var desc: Array = D.skills[c.skill].desc
		if c.level == 0 and ((not Save.is_unlocked(c.key) and not story) or _party_count() >= Save.party_cap()):
			continue
		if c.level == 0:
			var nm: String = c.name + ("・" + by_key[c.with].name if c.with != "" else "")
			var rd: String = desc[0] + _bond_hint(c.key)
			if D.schools.has(c.tag) and not _school_on(c.tag) and not comps.any(func(o): return o.level > 0 and o.tag == c.tag):
				rd += "\n新流派：%s「%s」（練到 Lv%d 可借給主角）" % [c.tag, D.schools[c.tag].name, int(D.support_rules.lend_level)]
			pool.append({"kind": "recruit", "key": c.key, "title": nm + "　加入", "tag": c.tag, "desc": rd})
		elif c.level < 5:
			var d2: String = desc[c.level]
			var evo := _evo_of(c.key)
			if c.level == 4 and not evo.is_empty():
				var fname: String = D.fruits[evo.fruit].name
				d2 += "\n滿級＋果子「%s」→ 進化「%s」" % [fname, evo.name]
				if not Save.is_unlocked("fruit_" + evo.fruit):
					d2 += "（果子要先在補給帳棚解鎖）"
			if c.level + 1 == int(D.support_rules.lend_level) and D.schools.has(c.tag) and not _school_on(c.tag):
				d2 += "\n★ 練到 Lv%d 可以把流派「%s」借給主角" % [c.level + 1, D.schools[c.tag].name]
			pool.append({"kind": "up", "key": c.key, "title": "%s　Lv%d → %d" % [c.name, c.level, c.level + 1], "tag": c.tag, "desc": d2})
	for st in _stage_list():
		var ep: Dictionary = st.epistle
		if Save.data.churches.has(st.id) and not epistles.has(ep.effect):
			pool.append({"kind": "epistle", "key": ep.effect, "title": ep.name, "tag": "書信", "desc": ep.desc})
	var lc := _link_card() if _sys_open("link") else {}
	if not lc.is_empty():
		pool.append(lc)
	if _sys_open("school"):
		for sc in _school_cards():
			pool.append(sc)
		for spc in _support_cards():
			pool.append(spc)
	if relics.has("rod"):
		for f in pool.filter(func(cd): return cd.kind == "fruit"):
			pool.append(f)   # 亞倫發芽的杖：果子卡更常出現
	# 恩賜盤的流派傾向：點在哪個流派區越多，那個流派的卡越常出現（多放一份進牌堆，後面會去掉重複）
	for cd in pool.duplicate():
		var tl := Save.board_tilt(str(cd.get("tag", "")))
		if tl > 0.0 and randf() < tl:
			pool.append(cd)
	pool.shuffle()
	var seen_cards := {}
	pool = pool.filter(func(cd):
		var k := "%s:%s:%s" % [cd.kind, cd.key, cd.get("aid", cd.get("title", ""))]
		if seen_cards.has(k):
			return false
		seen_cards[k] = true
		return true)
	# 主角起點的流派：第一次升級一定有一張這個流派的招募卡
	if level <= 2:
		var st_tag: String = str(Save.board_node(Save.board_start(leader)).get("tag", ""))
		var ri := pool.find_custom(func(cd): return cd.kind == "recruit" and cd.tag == st_tag)
		if ri > 0:
			pool.push_front(pool.pop_at(ri))
	# 主角的輔助卡比較常排到前面（流派要靠它成形）
	var spc_i := pool.find_custom(func(cd): return cd.kind == "anoint")
	if spc_i > 0 and randf() < 0.6:
		pool.push_front(pool.pop_at(spc_i))
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
	var n_cards := mini(4, (4 if calling == "teacher" else 3) + (1 if epistles.has("vernacular") else 0)) - (1 if trials.has("tempt") else 0)
	if calling == "teacher":
		# 教師：有流派卡時一定排進來
		for sc in pool.filter(func(cd): return cd.kind == "school"):
			pool.erase(sc)
			pool.insert(mini(1, pool.size()), sc)
	pool = pool.filter(func(cd): return not banished.has("%s:%s" % [cd.kind, cd.key]))
	var cards := pool.slice(0, n_cards)
	var fill := _filler_cards()
	while cards.size() < n_cards and not fill.is_empty():
		cards.append(fill.pop_front())
	return cards


## 沒有足夠的卡時的小獎勵（恩上加恩、如鷹展翅、嗎哪；血少時才有五餅二魚）
func _filler_cards() -> Array:
	var out := []
	for f in D.fillers:
		if f.kind == "heal" and paul.hp > float(D.paul.hp) * float(f.hp_below):
			continue
		var fd: String = f.desc
		if f.kind == "grace_dmg" or f.kind == "grace_spd":
			var now: float = grace_dmg if f.kind == "grace_dmg" else grace_spd
			fd += "\n目前 +%d%% → +%d%%" % [roundi(now * 100.0), roundi((now + float(f.amount)) * 100.0)]
		out.append({"kind": f.kind, "key": "", "title": f.title, "tag": f.tag, "desc": fd, "amount": f.get("amount", 0)})
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
	if pending_cards.any(func(cd): return cd.kind == "anoint"):
		_tip("anoint")
	if pending_cards.any(func(cd): return cd.kind == "school"):
		_tip("deepen")
	Sfx.play("levelup", 0.0)
	ui.do_flash(0.5)
	_ring_pop(paul.pos + Vector2(0, -6), C_GOLD, 60.0)
	# 升級的光把身邊的敵人推開一點（選完卡回到戰場時有喘息的空間）
	blasts.append({"pos": paul.pos, "t": 0.0, "r": 70.0, "col": C_GOLD, "evo": false})
	for e in enemies:
		if not e.dead and not e.get("boss", false) and e.pos.distance_to(paul.pos) < 70.0:
			e.knock += (e.pos - paul.pos).normalized() * 220.0
	ui.show_cards(pending_cards, Time.get_ticks_msec() / 1000.0, _card_delay(), rerolls_left, "升級！選一個", "", banishes_left)


func _card_delay() -> float:
	return float(D.leveling.touch_card_delay if DisplayServer.is_touchscreen_available() else D.leveling.card_delay)


func _reroll() -> void:
	if not choosing or rerolls_left <= 0:
		return
	rerolls_left -= 1
	pending_cards = _make_cards()
	ui.show_cards(pending_cards, Time.get_ticks_msec() / 1000.0, 0.15, rerolls_left, "升級！選一個", "", banishes_left)


## 放逐：這張卡這一局不會再出現，換一手新的（不扣重抽）
func _banish(i: int) -> void:
	if not choosing or banishes_left <= 0 or i >= pending_cards.size():
		return
	var card: Dictionary = pending_cards[i]
	if str(card.get("key", "")) == "" or card.kind in ["evolve", "branch"]:
		return
	banishes_left -= 1
	banished.append("%s:%s" % [card.kind, card.key])
	Sfx.play("hit", 0.0)
	pending_cards = _make_cards()
	ui.show_cards(pending_cards, Time.get_ticks_msec() / 1000.0, 0.15, rerolls_left, "升級！選一個", "已放逐「%s」" % card.title, banishes_left)


func _apply_card(card: Dictionary) -> void:
	if card.kind == "recruit":
		_recruit(by_key[card.key])
	elif card.kind == "up":
		var c: Dictionary = by_key[card.key]
		_set_level(c, c.level + 1)
		_ring_pop(c.pos + Vector2(0, -6), C_GOLD, 30.0)
	elif card.kind == "fruit":
		fruits[card.key] = fruits.get(card.key, 0) + 1
		var ms: Dictionary = D.fruits[card.key].get("milestones", {}).get(str(fruits[card.key]), {})
		if not ms.is_empty():
			ui.show_banner("%s Lv%d：「%s」　%s" % [D.fruits[card.key].name, fruits[card.key], ms.name, ms.desc], 3.0)
			_ring_pop(paul.pos + Vector2(0, -6), C_GOLD, 44.0)
	elif card.kind == "armor":
		armor[card.key] = armor.get(card.key, 0) + 1
		var a3: Dictionary = D.armor[card.key]
		if armor[card.key] == 3 and a3.has("lv3"):
			ui.show_banner("%s Lv3：「%s」" % [a3.name, a3.lv3], 3.0)
			_ring_pop(paul.pos + Vector2(0, -6), C_GOLD, 44.0)
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
	elif card.kind == "event":
		_event_effects(card.effects)
	elif card.kind.begins_with("shop_"):
		_buy(card)
	elif card.kind == "relic":
		_take_relic(card.key)
	elif card.kind == "anoint":
		var ao := _who(card.key)
		if not ao.is_empty():
			if not ao.has("anoints"):
				ao.anoints = []
			ao.anoints.append(card.aid)
			_set_level(ao, ao.level)
			_ring_pop(ao.pos + Vector2(0, -8), Color("c8a0ff"), 24.0)
			if str(card.aid).begins_with("s_"):
				_update_schools()
	elif card.kind == "school":
		school_cards[card.key] = true
		for k in card.mod:
			school_mods[k] = float(school_mods.get(k, 0.0)) + float(card.mod[k])
		ui.show_banner("深化卡：" + card.title, 1.6)
		_update_schools()
		_ring_pop(paul.pos + Vector2(0, -8), TAG_COL.get(card.tag, C_GOLD), 36.0)
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
		"saved": return run_saved
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
	for CL in D.get("callings", []):
		if CL.id == calling:
			lines.append("呼召　%s・%s" % [CL.name, CL.word])
	for tag in school_tier:
		if int(school_tier[tag]) > 0:
			var nc := 0
			for k in school_cards:
				if k.begins_with(tag + ":"):
					nc += 1
			lines.append("流派　%s「%s」%d 階" % [tag, D.schools[tag].name, school_tier[tag]])
	if not relics.is_empty():
		var rn := []
		for r in D.relics:
			if relics.has(r.id):
				rn.append(r.name)
		lines.append("聖物　" + "、".join(rn))
	if not pa.is_empty():
		var an := []
		for id in pa.get("anoints", []):
			if str(id).begins_with("s_"):
				an.append("「%s」" % D.schools[str(id).substr(2)].name)
			else:
				for a in D.anoints:
					if a.id == id:
						an.append(a.name)
		lines.append("輔助　%s %d／%d 格%s" % [pa.name, an.size(), _support_slots(), ("：" + "、".join(an)) if not an.is_empty() else ""])
	for f in D.fusions:
		if _fused(f.a, f.b):
			lines.append("融合　「%s」" % f.name)
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


## 暫停畫面的「怎麼構築」：每個流派差什麼、進化差什麼、融合與套裝還缺什麼
func _build_guide() -> String:
	var L := []
	var lend := int(D.support_rules.lend_level)
	var used: Array = pa.get("anoints", []) if not pa.is_empty() else []
	var free_slots: int = _support_slots() - used.size()
	var tags := []
	for o in [pa] + comps:
		if not o.is_empty() and int(o.get("level", 0)) > 0 and o.get("follows", "") == "" and D.schools.has(str(o.get("tag", ""))) and not tags.has(o.tag):
			tags.append(o.tag)
	# 這一局每個人打出多少傷害（看誰是主力、誰該再練）
	var dl := ([pa] + comps).filter(func(o): return not o.is_empty() and float(o.get("dealt", 0.0)) > 0.0)
	if not dl.is_empty():
		dl.sort_custom(func(x, y): return float(x.dealt) > float(y.dealt))
		var tot := 0.0
		for o in dl:
			tot += float(o.dealt)
		L.append("【這一局的傷害】")
		for o in dl:
			L.append("%s　%d（%d%%）" % [o.name, roundi(float(o.dealt)), roundi(float(o.dealt) * 100.0 / tot)])
	L.append("【流派】")
	for tag in tags:
		var S: Dictionary = D.schools[tag]
		var tier: int = int(school_tier.get(tag, 0))
		if tier >= 3:
			L.append("✓ %s「%s」3 階（滿）" % [tag, S.name])
		elif tier > 0:
			L.append("✓ %s「%s」%d 階：再選 %d 張「%s」深化卡就到 3 階" % [tag, S.name, tier, 3 - tier, tag])
		else:
			var best = null
			for c in comps:
				if c.level > 0 and c.tag == tag and c.follows == "" and (best == null or c.level > best.level):
					best = c
			var how := ""
			if best != null and best.level < lend:
				how = "把%s練到 Lv%d（現在 Lv%d），升級時會出現借出卡" % [best.name, lend, best.level]
			elif free_slots <= 0:
				how = "主角輔助格滿了（主角招式 Lv3、進化各多 1 格）"
			else:
				how = "升級時選「%s借出「%s」」的卡" % [best.name if best != null else "同伴", S.name]
			L.append("・%s「%s」還沒成形：%s" % [tag, S.name, how])
	if tags.is_empty():
		L.append("・隊伍裡還沒有流派：招募同伴，練到 Lv%d 就能把他的流派借給主角" % lend)
	L.append("主角輔助：%d／%d 格" % [used.size(), _support_slots()])
	var fl := []
	for f in D.fusions:
		var on_a := _school_on(f.a)
		var on_b := _school_on(f.b)
		if on_a and on_b:
			fl.append("✓「%s」（%s＋%s）" % [f.name, f.a, f.b])
		elif on_a != on_b and (tags.has(f.a) and tags.has(f.b)):
			fl.append("・「%s」：再讓%s成形" % [f.name, f.b if on_a else f.a])
	if not fl.is_empty():
		L.append("【融合】")
		L.append_array(fl)
	var el := []
	for c in [pa] + comps:
		if c.is_empty() or int(c.get("level", 0)) <= 0 or evolved.has(c.key):
			continue
		var evo := _evo_of(c.key)
		if evo.is_empty():
			continue
		var has_f: bool = fruits.has(evo.fruit)
		el.append("%s「%s」：Lv%d／5 %s、果子「%s」%s" % [c.name, evo.name, int(c.level), "✓" if int(c.level) >= 5 else "", D.fruits[evo.fruit].name, "✓" if has_f else "（還沒有）"])
	for k in evolved:
		el.append("✓ %s 已進化「%s」" % [by_key[k].name if by_key.has(k) else pa.name, evolved[k].name])
	if not el.is_empty():
		L.append("【進化】滿級＋對應的果子")
		L.append_array(el)
	var sl := []
	for st in D.armor_sets:
		var miss: Array = st.pieces.filter(func(pc): return armor.get(pc, 0) == 0)
		if miss.is_empty():
			sl.append("✓「%s」：%s" % [st.name, st.desc])
		elif miss.size() < st.pieces.size():
			sl.append("・「%s」：再穿%s → %s" % [st.name, D.armor[miss[0]].name, st.desc])
	if not sl.is_empty():
		L.append("【套裝】")
		L.append_array(sl)
	return "\n".join(L)


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
	_autosave()
	if xp >= xp_need:
		_level_up()


# ---------- 輸入 ----------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if talking and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			ui.dialogue_next()
			get_viewport().set_input_as_handled()
			return
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
		if choosing and event.keycode == KEY_B:
			ui.toggle_banish()
			return
		if choosing and event.keycode >= KEY_1 and event.keycode <= KEY_4 and event.keycode - KEY_1 < pending_cards.size():
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
	if smoke and bot and OS.get_cmdline_user_args().has("--idle"):
		return Vector2.ZERO   # 測試用：完全站著不動的機器人（檢查「站樁能不能過關」）
	if smoke and bot:
		return _bot_move()
	if smoke:
		return Vector2.from_angle(t * 0.6) * 0.8
	return Vector2.ZERO


## 測試機器人：躲開附近的敵人與 Boss 預警、空檔時去撿經驗和寶箱
func _bot_move() -> Vector2:
	var p: Vector2 = paul.pos
	var push := Vector2.ZERO
	for e in enemies:
		if e.dead:
			continue
		var d: Vector2 = p - e.pos
		var l := d.length()
		var reach := 60.0 if e.get("boss", false) else 38.0
		if l < reach and l > 0.01:
			push += d / l * (reach - l) / reach * (3.0 if e.get("boss", false) else 1.0)
	for sh in tele:
		if sh.kind == "circle":
			var d2: Vector2 = p - sh.c
			if d2.length() < sh.r + 12.0:
				push += d2.normalized() * 6.0
		else:
			var ab: Vector2 = sh.b - sh.a
			var q: Vector2 = sh.a + ab * clampf((p - sh.a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
			var d3: Vector2 = p - q
			if d3.length() < sh.w + 12.0:
				push += (d3.normalized() if d3.length() > 0.01 else ab.orthogonal().normalized()) * 6.0
	for sf in star_falls:
		# 星辰、逼迫：落點附近趕快走開
		if sf.t > 0.0:
			var d4: Vector2 = p - sf.pos
			if d4.length() < sf.r + 10.0:
				push += (d4.normalized() if d4.length() > 0.5 else Vector2.RIGHT.rotated(randf() * TAU)) * 8.0
	var pull := Vector2.ZERO
	var best := 1e9
	for sk in seekers:
		pull = (sk.pos - p).normalized() * 1.4 if p.distance_to(sk.pos) > 10.0 else Vector2.ZERO
		best = 0.0
	var targets: Array = chests.duplicate() + items
	if not merchant.is_empty():
		targets.append(merchant)
	for ch in targets:
		var dc: float = p.distance_to(ch.pos)
		if dc < best and seekers.is_empty():
			best = dc
			pull = (ch.pos - p).normalized() * 1.2
	if pull == Vector2.ZERO:
		for g in gems:
			var dg: float = p.distance_to(g.pos)
			if dg < best and dg < 140.0:
				best = dg
				pull = (g.pos - p).normalized() * 0.6
	# 不要離起點太遠（太遠會撿不到東西、被包圍）
	pull += -p / 400.0
	var v := push * 2.0 + pull
	return v.normalized() if v.length() > 0.05 else Vector2.ZERO


## 測試機器人選卡：進化 > 招募 > 升級最高等的人 > 果子 > 軍裝 > 連結 > 其他
func _bot_pick(cards: Array) -> int:
	var best := 0
	var best_score := -1e9
	for i in cards.size():
		var cd: Dictionary = cards[i]
		var sc := 0.0
		match cd.kind:
			"evolve": sc = 100.0
			"recruit": sc = 60.0
			"branch": sc = 55.0
			"up": sc = 40.0 + (float(by_key[cd.key].level) * 3.0 if by_key.has(cd.key) else 0.0)
			"fruit": sc = 35.0
			"armor": sc = 30.0
			"link", "link_up": sc = 28.0
			"epistle": sc = 26.0
			"heal": sc = 50.0 if paul.hp < float(D.paul.hp) * 0.5 else 5.0
			"event": sc = 20.0
			"school": sc = 45.0
			"relic": sc = 50.0
			"anoint": sc = 52.0 if str(cd.get("aid", "")).begins_with("s_") else 38.0
			_: sc = 10.0
		sc += randf() * 6.0
		if sc > best_score:
			best_score = sc
			best = i
	return best


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
	var hp: float = ceilf(d.hp * _curve(SC.hp, t) * stage.hp_mult * (float(V.hp_mult) if vet else 1.0) * _endless_mult("hp") * (1.0 + enemy_hp_bonus))
	var spr: String = d.get("sprite", type)
	if d.has("looks"):
		spr = d.looks[randi() % d.looks.size()]
	var tint := Color(d.tint[0], d.tint[1], d.tint[2]) if d.has("tint") else Color.WHITE
	# 獵手：不追主角、改追同伴，顏色偏紅
	var hunter := type != "fear" and not d.has("shoot") and randf() < _curve(D.waves.hunter.chance, t)
	if hunter:
		tint *= Color(1.25, 0.75, 0.75)
	hp = ceilf(hp * (1.0 + pressure))
	var e := {"type": type, "d": d, "pos": at, "hp": hp, "ph": randf() * TAU, "flash": 0.0, "stun": 0.0, "born": t,
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
	for k in ["roar_every", "roar_radius", "roar_force", "chest", "immune", "shoot", "dash", "drain", "summon"]:
		if def.has(k):
			d[k] = def[k]
	var scale: float = def.get("scale", 1.0)
	var SC: Dictionary = D.waves.scaling
	var e := {"type": key, "d": d, "pos": at, "hp": float(def.hp) * _curve(SC.hp, t) * stage.hp_mult * _endless_mult("hp") * (1.0 + pressure * 0.5), "ph": randf() * TAU,
		"dmul": _curve(SC.damage, t) * stage.dmg_mult, "smul": _curve(SC.speed, t),
		"flash": 0.0, "stun": 0.0, "cd": 0.0, "bcd": 0.0, "shoot": 0.0, "r": 6.0 * scale, "sprite": def.sprite,
		"tint": Color(def.tint[0], def.tint[1], def.tint[2]), "roar": 2.0, "elite": scale > 1.0,
		"dash_cd": 2.0, "dash_t": 0.0, "blink_cd": 2.0, "sum_cd": 2.0,
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
	if e.dead or float(e.get("ally", 0.0)) > 0.0:
		return
	if src is Dictionary and ((calling == "evangelist" and randf() < 0.05) or (epistles.has("convert_plus") and randf() < 0.02)) and not e.get("elite", false) and not e.get("boss", false):
		_convert(e, 5.0)   # 傳福音的：不管哪個流派，這一擊都可能把敵人說服過來
		return
	if fever > 0.0:
		dmg *= 1.5
		if src is Dictionary and not e.get("elite", false) and not e.get("boss", false) and randf() < 0.02:
			# 五旬節：各人聽見用自己的鄉談說神的大作為（徒 2:6、11），有人就被說服過來
			_convert(e, 5.0)
			_fxc("鄉談")
			if tag_fx.size() < 8:
				tag_fx.append({"pos": e.pos + Vector2(4, 8), "text": TONGUES.pick_random(), "col": C_CREAM, "t": 0.0})
			return
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
		var atone: float = (_sv("醫治", "atone") if _tagged(src, "醫治") else 0.0) + (0.1 if src.has("st") and float(src.st.get("atone", 0.0)) > 0.0 else 0.0)
		if atone > 0.0 and t >= atone_cd:
			# 以善勝惡：醫治的人打出去的傷害，一部分化成血最少的人的醫治
			atone_cd = t + 0.3
			_fxc("以善勝惡")
			_atone(dmg * atone)
		if src.has("st") and float(src.st.get("melee", 0.0)) > 0.0:
			# 近戰：貼身打中的敵人露出破綻（2 秒內全隊打他更痛），自己也吸回一點力氣
			e.exposed_t = maxf(float(e.get("exposed_t", 0.0)), 2.0)
			e.expose = maxf(float(e.get("expose", 0.0)), float(src.st.melee))
			if t < float(src.get("leech_cd", 0.0)):
				pass   # 吸血每 0.25 秒最多一次（範圍打到一大群時不會一下補滿）
			elif src == pa:
				src.leech_cd = t + 0.25
				_heal_paul(float(src.st.get("leech", 1.0)))
			elif src.level > 0 and float(src.get("down", 0.0)) <= 0.0:
				src.leech_cd = t + 0.25
				src.hp = minf(_comp_max_hp(), float(src.hp) + float(src.st.get("leech", 1.0)))
		if src == pa and armor.get("sword", 0) > 0:
			dmg *= 1.0 + float(D.armor.sword.per[armor.sword - 1])
		# 流派規則
		var stag: String = src.get("tag", "")
		if float(src.get("beat_mult", 1.0)) > 1.0:
			dmg *= float(src.beat_mult)   # 詩歌：重拍
			if not e.get("boss", false):
				e.stun = maxf(e.stun, 0.3)
		if (src == pa or stag == "守護") and guard > 0:
			dmg *= 1.0 + _sv("守護", "shield_sword") * guard   # 以盾為劍
		if _tagged(src, "詩歌"):
			praise += 1.0
		if float(bond_buff.get(src.get("key", ""), 0.0)) > 0.0:
			dmg *= 2.0   # 同行合擊：加倍
		if t < float(src.get("cross_until", -1.0)):
			dmg *= 1.4   # 使徒：跨流派的連結
	if keystones.has("midnight") and src is Dictionary and src.get("tag", "") == "詩歌" and paul.hp < float(D.paul.hp) * 0.5:
		dmg *= 2.0   # 基石「半夜唱詩」
	if int(e.get("sunder", 0)) > 0 and float(e.get("sunder_t", 0.0)) > 0.0:
		dmg *= 1.0 + 0.1 * int(e.sunder)   # 哥尼流的破甲
	if crit_t > 0.0:
		dmg *= 2.0   # 同行合擊：我的主，我的神
	if altar_buff > 0.0:
		dmg *= 1.0 + float(stage.get("hazard", {}).get("buff", 0.0))   # 雅典：認識未識之神
	if relics.has("hair"):
		dmg *= 1.0 + 0.5 * clampf(1.0 - paul.hp / float(D.paul.hp), 0.0, 1.0)   # 參孫的頭髮
	if not e.get("burning_hit", false):
		dmg *= _apply_element(e, dmg, src)
	if not prophecy.is_empty() and e.pos.distance_to(prophecy.pos) < prophecy.r:
		dmg *= 2.0   # 先知：預言之地
		e.slow_t = 1.0   # 也走得慢
	if e.type == "lies":
		dmg *= 1.0 + 0.5 * mini(armor.get("belt", 0), 2)
	if e.get("boss", false) and boss != null and boss.state == "break":
		dmg *= D.boss.break_mult
	if src is Dictionary and (e.get("elite", false) or e.get("boss", false)) and _fx_of(src).has("heavy"):
		dmg *= 1.6   # 輔助「磐石」
	if int(e.get("msg", 0)) > 0 and _sv("講道", "msg_expose") > 0.0:
		dmg *= 1.0 + _sv("講道", "msg_expose")   # 兩刃的劍：已經累積信息的敵人更痛
	if src is Dictionary and _fruit_lv("faith") >= 3 and randf() < (0.2 if _fruit_lv("faith") >= 5 else 0.12):
		dmg *= 2.5 if _fruit_lv("faith") >= 5 else 2.0   # 信實：阿們
		_fxc("阿們")
		if tag_fx.size() < 12:
			tag_fx.append({"pos": e.pos + Vector2(4, 8), "text": "阿們", "col": C_GOLD, "t": 0.0})
	if not e.has("hp0"):
		e.hp0 = e.hp   # 第一次被打時的血量（「收割」用）
	e.hp -= dmg
	if src is Dictionary:
		src.dealt = float(src.get("dealt", 0.0)) + minf(dmg, maxf(0.0, dmg + e.hp))   # 這一局打出的傷害（結算排行用）
	e.flash = 0.08
	Sfx.play("hit")
	if from != Vector2.INF:
		# 擊退：打得越重退得越遠（菁英、Boss 退得少）
		var kb := 34.0 + minf(dmg, 40.0) * 0.8
		if e.get("elite", false) or e.get("boss", false):
			kb *= 0.35
		e.knock += (e.pos - from).normalized() * kb
	if e.get("boss", false) and dmg >= 30.0:
		_hit_stop(0.035, 0.08)
	_dmg_number(e, dmg, src)
	var hcol: Color = src.get("col", C_GOLD) if src is Dictionary else C_GOLD
	if sparks.size() < (30 if _fx_lite() else 120):
		sparks.append({"pos": e.pos + Vector2(randf_range(-3, 3), randf_range(-8, -2)), "t": 0.0, "col": hcol})
	if parts.size() < 400 and not _fx_lite():
		_burst(e.pos + Vector2(0, -5), 2, hcol, hcol.darkened(0.4))
	if src is Dictionary and not e.get("burning_hit", false):
		_anoint_on_hit(e, dmg, src)
	if e.hp <= 0:
		_kill(e, true, src)
	elif _tagged(src, "講道"):
		_persuade(e, 1)


func _kill(e: Dictionary, by_player: bool, src = null) -> void:
	e.dead = true
	if by_player and src != null:
		_fire_links("kill", src, 0)
	if by_player and e.get("elite", false):
		_hit_stop(0.07, 0.18)
		_ring_pop(e.pos + Vector2(0, -6), C_GOLD, 26.0)
		_burst(e.pos + Vector2(0, -6), 16, C_GOLD, C_CREAM)
		Sfx.play("shatter", 0.04, 0.85)
		# 菁英（黑暗的營壘）被拆毀：被它困住的人在那裡出現
		if not solo:
			_spawn_seeker(e.pos, {"name": "從黑暗中出來的人", "ref": "徒 26:18", "line": "我好像……醒過來了。"})
	if poofs.size() < 60 and not e.get("boss", false) and not _fx_lite():
		poofs.append({"tex": e.node.texture, "pos": e.pos.round(), "off": e.node.offset, "t": 0.0, "flip": e.node.flip_h})
	e.node.queue_free()
	if by_player:
		if e.has("born") and not e.get("elite", false):
			life_avg = lerpf(life_avg, t - float(e.born), 0.02)
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
		var item_chance := 0.2 if e.get("elite", false) else (0.0 if e.get("boss", false) else 0.001)
		if randf() < item_chance and items.size() < 4:
			var r := randf()
			items.append({"kind": "horn" if r < 0.3 else ("calm" if r < 0.6 else "grapes"), "pos": e.pos})
		if src is Dictionary and _fx_of(src).has("release") and not blasting:
			# 得釋放：驅散的地方爆開光
			blasting = true
			_fxc("爆光")
			blasts.append({"pos": e.pos + Vector2(0, -4), "t": 0.0, "r": 26.0, "col": C_GOLD, "evo": false})
			for o in _enemies_near(e.pos, 36.0):
				if o != e and not o.dead and float(o.get("ally", 0.0)) <= 0.0 and o.pos.distance_to(e.pos) < 26.0 + float(o.r):
					_hurt(o, 8.0 + level, e.pos, src)
			blasting = false
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
			if _tagged(src, "門徒"):
				if randf() < _sv("門徒", "minion_chance") * (1.0 + _sv("門徒", "minion_chance_mult")):
					for i in (2 if _sv("門徒", "minion_pair") > 0.0 else 1):
						_spawn_minion(e.pos)
		if float(e.get("burn_t", 0.0)) > 0.0 and not e.get("boss", false):
			# 燒死的敵人爆開，把火傳給旁邊的
			blasts.append({"pos": e.pos, "t": 0.0, "r": 20.0, "col": C_FLAME, "evo": false})
			for o in enemies:
				if not o.dead and o != e and o.pos.distance_to(e.pos) < 20.0:
					o.burn_t = 3.0
					o.burn_dps = maxf(float(o.get("burn_dps", 0.0)), float(e.get("burn_dps", 2.0)))
		if src is Dictionary and src.get("anoints", []).has("trigger") and t >= float(src.get("trig_cd", 0.0)) and src.level > 0:
			src.trig_cd = t + 0.8
			delayed.append({"t": 0.05, "fn": _cast.bind(src, true, 1)})
		if feast_t > 0.0:
			gems.append({"pos": e.pos + Vector2(randf_range(-5, 5), randf_range(-4, 4)), "got": false})
		if e.get("vet", false):
			for i in int(D.waves.veteran.gems) - 1:
				gems.append({"pos": e.pos + Vector2(randf_range(-6, 6), randf_range(-5, 5)), "got": false})
		if e.d.get("chest", false):
			chests.append({"pos": e.pos, "relic": randf() < float(D.relic_rules.elite_chance)})
			_tip("chest")
		if e.get("elite", false):
			run_elites += 1
			_fire_links("elite", null, 0)
		if e.d.has("split_into"):
			for i in int(e.d.split_count):
				_spawn_one(e.d.split_into, e.pos + Vector2(randf_range(-8, 8), randf_range(-6, 6)))
		if e.get("boss", false):
			# Boss 倒下：還沒打下來的預警、衝擊波、線、牆、捆鎖全部收掉（不然會一直留在畫面上）
			tele = []
			boss_waves.clear()
			boss_lines.clear()
			boss_walls.clear()
			tether = {}
			star_falls = star_falls.filter(func(sf): return sf.get("src", "") != "boss")
		if e.get("boss", false) and e.get("mid", false):
			# 中途 Boss 打退了：掉寶箱（一定能選聖物），真正的 Boss 之後才來
			chests.append({"pos": e.pos, "relic": true})
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
			fever_kills += 1   # 五旬節的長短是固定的（聖靈的澆灌是恩典，不是驅散多少換來的）
	else:
		_burst(e.pos, 6, C_VL, Color("3b1e52"))


func _burst(at: Vector2, n: int, c1: Color, c2: Color) -> void:
	if _fx_lite():
		n = n / 3   # 特效精簡
	for i in n:
		if parts.size() >= 600:
			return
		var a := randf() * TAU
		var s := 20.0 + randf() * 40.0
		parts.append({"pos": at, "vel": Vector2(cos(a) * s, sin(a) * s * 0.7 - 14.0), "life": 0.3 + randf() * 0.4, "max": 0.7, "c1": c1, "c2": c2})


func _perf(k: String, us: int) -> void:
	perf_us[k] = int(perf_us.get(k, 0)) + us


func _perf_report() -> void:
	perf_n += 1
	if perf_n % 300 != 0:
		return
	var out := []
	for k in perf_us:
		out.append("%s %.2f" % [k, perf_us[k] / 300.0 / 1000.0])
	var alive := enemies.filter(func(e): return not e.dead).size()
	print("PERF t=%d 敵人=%d 粒子=%d 飛行=%d ｜ %s（毫秒／格）" % [int(t), alive, parts.size(), bolts.size() + shots.size(), "、".join(out)])
	perf_us.clear()


## 打擊停頓：大的命中、打倒菁英時整個畫面停一下（很短，不會擋到操作）；冷卻中就不停，避免連續卡頓
func _hit_stop(sec: float, shake_amt := 0.0) -> void:
	if (smoke and not film) or _fx_lite() or hitstop_cd > 0.0:
		return
	hitstop = maxf(hitstop, sec)
	hitstop_cd = 0.25
	shake = maxf(shake, shake_amt)


## 投射物打中的那一點：一圈光＋往前噴的光芒，打得越重越大（穿透時每一個打中的點都有）
func _impact(at: Vector2, src, dmg: float, look, dir: Vector2) -> void:
	if impacts.size() >= (25 if _fx_lite() else 90):
		return
	var col: Color = IMPACT_COL.get(str(look), src.get("col", C_GOLD) if src is Dictionary else C_GOLD)
	impacts.append({"pos": at, "t": 0.0, "col": col, "size": clampf(5.0 + sqrt(maxf(dmg, 0.0)) * 1.8, 5.0, 16.0),
		"dir": dir if dir.length() > 0.1 else Vector2.RIGHT, "rot": randf_range(-0.4, 0.4)})


func _ring_pop(at: Vector2, col: Color, size: float) -> void:
	if pops.size() < 80:
		pops.append({"pos": at, "t": 0.0, "size": size, "col": col})


## 敵人分格：每一格畫面先把敵人依位置分到 32×32 的格子裡，找「附近的敵人」時只看附近幾格，
## 不用每次都把全部敵人掃一遍（敵人上百隻時，手機才不會卡）。Boss 很大，每次都一併列入。
const GRID := 32.0
var egrid := {}
var egrid_big: Array = []


func _build_grid() -> void:
	egrid.clear()
	egrid_big.clear()
	for e in enemies:
		if e.dead:
			continue
		if e.get("boss", false):
			egrid_big.append(e)
			continue
		var k := Vector2i(floori(e.pos.x / GRID), floori(e.pos.y / GRID))
		if egrid.has(k):
			egrid[k].append(e)
		else:
			egrid[k] = [e]


## 某個點 rad 範圍附近可能碰得到的敵人（只是候選，距離還是要自己再算；這一格畫面剛出生的不在裡面）
func _enemies_near(at: Vector2, rad: float) -> Array:
	var out: Array = egrid_big.duplicate()
	var x0 := floori((at.x - rad) / GRID)
	var x1 := floori((at.x + rad) / GRID)
	var y0 := floori((at.y - rad) / GRID)
	var y1 := floori((at.y + rad) / GRID)
	for gx in range(x0, x1 + 1):
		for gy in range(y0, y1 + 1):
			var k := Vector2i(gx, gy)
			if egrid.has(k):
				out.append_array(egrid[k])
	return out


func _nearest_enemies(from: Vector2, max_d: float, n: int, skip := {}) -> Array:
	var cand := []
	for e in (_enemies_near(from, max_d + 8.0) if max_d <= 240.0 else enemies):
		if e.dead or skip.has(e.node) or float(e.get("ally", 0.0)) > 0.0:
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
# ---------- 局內事件（使徒行傳的場景，二選一） ----------
func _start_event() -> void:
	var pool: Array = EV.events.filter(func(ev): return not events_done.has(ev.id))
	event_t = t - t_start + randf_range(float(EV.every[0]), float(EV.every[1]))
	if pool.is_empty():
		return
	var ev: Dictionary = pool[randi() % pool.size()]
	events_done.append(ev.id)
	choosing = true
	joy.on = false
	ui.joy.on = false
	pending_cards = []
	for i in ev.choices.size():
		var ch: Dictionary = ev.choices[i]
		pending_cards.append({"kind": "event", "key": str(i), "title": ch.label, "tag": ev.ref, "desc": ch.desc, "effects": ch.effects})
	Sfx.play("chest", 0.0)
	_tip("event")
	ui.show_cards(pending_cards, Time.get_ticks_msec() / 1000.0, _card_delay(), 0, "%s（%s）" % [ev.title, ev.ref], ev.text)
	if smoke:
		print("EVENT ", ev.id)
		if smoke_shot != "" and not FileAccess.file_exists(smoke_shot.replace(".png", "_event.png")):
			await get_tree().create_timer(0.3).timeout
			get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_event.png"))


func _event_effects(fx: Dictionary) -> void:
	for k in fx:
		var v = fx[k]
		match k:
			"heal_paul":
				paul.hp = float(D.paul.hp) if str(v) == "full" else minf(float(D.paul.hp), paul.hp + float(v))
				heals.append({"who": paul, "t": 0.0})
			"heal_team":
				for c in comps:
					if c.level > 0:
						c.down = 0.0
						c.hp = _comp_max_hp()
			"stun_all":
				for e in enemies:
					if not e.dead and not e.get("boss", false):
						e.stun = maxf(e.stun, float(v))
			"meter":
				meter = minf(1.0, meter + float(v))
			"chests":
				for i in int(v):
					chests.append({"pos": paul.pos + Vector2.from_angle(i * 2.1) * 30.0})
			"lose_armor":
				if not armor.is_empty():
					armor.erase(armor.keys()[randi() % armor.size()])
			"hurt_paul":
				paul.hp = maxf(1.0, paul.hp - float(D.paul.hp) * float(v))
			"dmg":
				grace_dmg += float(v)
			"spd":
				grace_spd += float(v)
			"move":
				move_bonus += float(v)
			"level":
				xp = maxi(xp, xp_need)
			"enemy_hp":
				enemy_hp_bonus += float(v)
			"bread":
				run_bread += int(v)
			"witness":
				task_witness += int(v)
			"guard":
				guard = mini(guard + int(v), 5)
			"down_one":
				var up := comps.filter(func(c): return c.level > 0 and c.down <= 0.0 and c.follows == "")
				if not up.is_empty():
					var c: Dictionary = up[randi() % up.size()]
					c.hp = 0.0
					c.down = float(D.companion_rules.down_seconds)
					c.down_total = float(c.get("down_total", 0.0)) + 1.0
			"recruit":
				var cand := comps.filter(func(c): return not solo and c.level == 0 and c.follows == "" and c.skill != "" and (chapter.cast.has(c.key) if story else Save.is_unlocked(c.key)))
				if not cand.is_empty() and _party_count() < Save.party_cap():
					var c: Dictionary = cand[randi() % cand.size()]
					_recruit(c)
					ui.show_banner("%s 加入了！" % c.name, 1.6)
				else:
					xp = maxi(xp, xp_need)
			"elites":
				for i in int(v):
					_spawn_special("terror", D.elites.terror, _edge_point(16.0))
	_refresh_build_text()


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
	var card_tip: bool = tip_queue[0] in ["cards", "link", "anoint", "deepen"]
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
	fever_ext = 0.0
	if meter < 1.0 or fever > 0.0 or over or choosing or paused:
		return
	fever = _fever_dur()
	fever_kills = 0
	waited = false
	if _fruit_lv("peace") >= 3:
		# 和平：平安歸你們（全隊回血）；Lv5 再把身邊的敵人推開
		_heal_paul(float(D.paul.hp) * 0.3)
		for c in comps:
			if c.level > 0 and c.down <= 0.0:
				_heal_comp(c, _comp_max_hp() * 0.3)
		_fxc("平安")
		if _fruit_lv("peace") >= 5:
			_ring_pop(paul.pos + Vector2(0, -6), Color("ffe9a0"), 90.0)
			for e in enemies:
				if not e.dead and e.pos.distance_to(paul.pos) < 90.0:
					e.knock += (e.pos - paul.pos).normalized() * (40.0 if e.get("boss", false) else 120.0)
	run_fevers += 1
	_fire_links("fever", null, 0)
	Sfx.play("fever", 0.0)   # 五旬節：不換歌（換掉會出戲），關卡曲的鼓和旋律整個推上來
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
	meter = 0.3 if epistles.has("refill") else 0.0   # 彼得前書：都要同心
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
	if scene.ends_with("base.tscn") and str(Save.data.get("pending_cut", "")) != "":
		scene = "res://scenes/title.tscn"   # 章節過場在標題場景播，播完自己回營地
	get_tree().change_scene_to_file(scene)


func _set_paused(on: bool) -> void:
	if over:
		return
	paused = on
	joy.on = false
	ui.joy.on = false
	if on:
		_refresh_build_text()
		ui.show_pause(build_text, _build_guide())
	else:
		ui.hide_pause()


func _notification(what: int) -> void:
	# 手機按返回鍵、切到別的 App、視窗失去焦點：自動暫停
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_set_paused(not paused)
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not smoke and not choosing and not chest_open:
			_set_paused(true)
		_autosave()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_autosave()


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	hitstop_cd = maxf(0.0, hitstop_cd - delta)
	if not auto_lite and not smoke and not over and not choosing and not paused:
		low_fps_t = low_fps_t + delta if Engine.get_frames_per_second() < 40 else maxf(0.0, low_fps_t - delta)
		if low_fps_t > 3.0:
			auto_lite = true   # 舊手機：少畫一點粒子與特效，讓遊戲保持順暢
	var pr0 := Time.get_ticks_usec()
	if hitstop > 0.0:
		hitstop -= delta   # 停頓中：世界不動，只重畫
	elif not over and not choosing and not chest_open and not paused and not talking:
		t += dt
		_step(dt)
	var pr1 := Time.get_ticks_usec()
	_render(dt)
	if perf:
		_perf("更新合計", pr1 - pr0)
		_perf("畫面", Time.get_ticks_usec() - pr1)
		_perf_report()
	if smoke:
		_smoke_tick()
	autosave_t -= delta
	if autosave_t <= 0.0:
		autosave_t = 20.0
		_autosave()


func _step(dt: float) -> void:
	var p := paul
	var mv := _move_vector()
	p.pos += mv * _speed() * dt
	p.moving = mv.length() > 0.05
	still_t = 0.0 if p.moving else still_t + dt
	if absf(mv.x) > 0.1:
		p.face = signf(mv.x)
	p.inv = maxf(0.0, p.inv - dt)
	shield_cd = maxf(0.0, shield_cd - dt)

	var luke = by_key.get("luke")
	var revive_mult: float = luke.st.revive_speed if luke != null and _active(luke) else 1.0
	if epistles.has("revive_plus"):
		revive_mult *= 2.0
	if calling == "shepherd":
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
	if not choosing and not chest_open and not over and boss == null and fever <= 0.0 \
			and t - t_start >= event_t and events_done.size() < int(EV.max_per_run):
		_start_event()
	if t - t_start > 4.0:
		_tip("gem")
	if t - t_start > 25.0:
		_tip("tasks")
	if meter >= 1.0 and fever <= 0.0:
		_tip("fever")
		if not waited:
			waited = true
			ui.show_banner("同心合意，等候父所應許的（徒 1:4）", 1.8)
	var bi := _boss_in()
	if bi >= 0.0 and bi < 12.0:
		_tip("boss")
	_update_beat(dt)
	var p0 := Time.get_ticks_usec()
	_build_grid()
	_companion_skills(dt)
	var p1 := Time.get_ticks_usec()
	_update_projectiles(dt)
	var p2 := Time.get_ticks_usec()
	_update_enemies(dt)
	var p3 := Time.get_ticks_usec()
	_update_schools_step(dt)
	_update_engines(dt)
	_update_ailments(dt)
	_update_seek(dt)
	_run_link_queue()
	if perf:
		_perf("招式", p1 - p0)
		_perf("飛行物", p2 - p1)
		_perf("敵人", p3 - p2)
		_perf("流派等", Time.get_ticks_usec() - p3)
	enemies = enemies.filter(func(e): return not e.dead)
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
	# 音樂的層次跟著戰況：血很少 → 只剩伴奏、聲音變悶；菁英潮或 Boss → 鼓和旋律往前；開局 → 只有伴奏和輕輕的鼓
	var mood := "normal"
	if fever > 0.0:
		mood = "fever"
	elif paul.hp < float(D.paul.hp) * 0.3:
		mood = "danger"
	elif peak or (boss != null and not boss.dead):
		mood = "peak"
	elif t - t_start < 25.0:
		mood = "calm"
	Sfx.set_intensity(mood)
	if t >= ew.from and boss == null:
		elite_timer -= dt
		if elite_timer <= 0.0:
			var ek: String = Array(stage.get("elites", ["terror"])).pick_random()
			_spawn_special(ek, D.elites[ek], _edge_point(16.0))
			ui.show_banner("菁英出現：" + D.elites[ek].name, 2.0)
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

	_update_finds(dt)
	for ch in chests:
		if p.pos.distance_to(ch.pos) < 10.0 and not chest_open:
			ch.got = true
			if bless == "relic" and not story:
				ch.relic = true
				bless = ""
			if ch.get("relic", false):
				relic_pending = true
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
	var helm: int = armor.get("helmet", 0)
	var mr: float = float(G.magnet_radius) * (1.0 + 0.2 * helm + (0.2 if epistles.has("xp_plus") else 0.0))   # 救恩的頭盔：撿經驗的範圍變大
	if helm >= 3 and not choosing:
		helmet_t -= dt
		if helmet_t <= 0.0:
			helmet_t = 20.0
			vac_t = 1.2   # 把畫面上的經驗全部吸過來
			_fxc("救恩臨到")
			_ring_pop(p.pos + Vector2(0, -6), C_GOLD, 30.0)
	vac_t = maxf(0.0, vac_t - dt)
	for g in gems:
		var to: Vector2 = p.pos + Vector2(0, -6) - g.pos
		var d: float = to.length()
		if d < mr or fever > 0.0 or vac_t > 0.0:
			g.pos += to.normalized() * (G.magnet_speed * (2.5 if fever > 0.0 or vac_t > 0.0 else 1.0)) * dt
		if d < 4.0:
			g.got = true
			xp += 1
			xp_acc += followers.size() * float(D.seek.xp_each) + Save.up_value("growth") + Save.building_bonus("xp") + Save.gift_global("xp") + (0.2 if epistles.has("xp_plus") else 0.0) + (float(D.armor.helmet.per[armor.helmet - 1]) if armor.get("helmet", 0) > 0 else 0.0) + (0.15 if bless == "xp" else 0.0)
			if xp_acc >= 1.0:
				xp_acc -= 1.0
				xp += 1
			gem_chain = gem_chain + 1 if t - gem_last < 0.45 else 0
			gem_last = t
			Sfx.play("gem", 0.0, GEM_STEPS[mini(gem_chain / 2, GEM_STEPS.size() - 1)])
	gems = gems.filter(func(g): return not g.got)
	for b in breads:
		var tb: Vector2 = p.pos + Vector2(0, -6) - b.pos
		if tb.length() < G.magnet_radius:
			b.pos += tb.normalized() * G.magnet_speed * dt
		if tb.length() < 5.0:
			b.got = true
			run_bread += 2 if relics.has("loaves") else 1   # 五餅二魚：餅變兩倍
			if relics.has("loaves"):
				loaves_n += 1
				if loaves_n % 10 == 0:
					paul.hp = minf(_hp_cap(), paul.hp + 8.0)
					heals.append({"who": paul, "t": 0.0})
			Sfx.play("gem", 0.0)
	breads = breads.filter(func(b): return not b.get("got", false))
	var regen: float = Save.up_value("renew") + float(set_bonus.get("regen", 0.0)) + Save.building_bonus("regen")
	if regen > 0.0 and p.hp > 0.0:
		var before: float = p.hp
		p.hp = minf(float(D.paul.hp), p.hp + regen * dt)
		regen_acc += p.hp - before
		if regen_acc >= 2.0:
			# 慢慢回血：每回滿 2 點跳一個綠色的字，看得到套裝與局外加成在作用
			regen_acc = 0.0
			if tag_fx.size() < 12:
				tag_fx.append({"pos": p.pos + Vector2(-2, 2), "text": "+2", "col": C_HEAL, "t": 0.0})
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
	for im in impacts:
		im.t += dt
	impacts = impacts.filter(func(im): return im.t < 0.2)

	var p4 := Time.get_ticks_usec()
	chunk_timer -= dt
	if chunk_timer <= 0.0:
		_update_chunks()
		chunk_timer = 0.4
	_update_wind(dt)
	_update_stars(dt)
	_update_fruits(dt)
	_update_hazard(dt)
	_update_lamps(dt)
	_collide_solids()
	if perf:
		_perf("場景", Time.get_ticks_usec() - p4)

	if xp >= xp_need and not over and not chest_open and not choosing:
		_level_up()


func _companion_skills(dt: float) -> void:
	var barn = by_key.get("barn")
	var barn_on: bool = barn != null and _active(barn)
	var speed_mult: float = D.fever.attack_speed if fever > 0.0 else 1.0
	speed_mult *= (1.0 + float(set_bonus.get("speed", 0.0)) + grace_spd) * (1.0 + (haste_amt if haste_t > 0.0 else 0.0))
	if keystones.has("pairs"):
		speed_mult *= 1.2 if (_party_count() + 1) % 2 == 0 else 0.9   # 基石「兩個兩個」
	haste_t = maxf(0.0, haste_t - dt)
	harp_t = maxf(0.0, harp_t - dt)
	pa.ult_cd = maxf(0.0, float(pa.get("ult_cd", 0.0)) - dt)
	pa.pos = paul.pos + Vector2(0, 2)
	pa.castfx = maxf(0.0, pa.castfx - dt)
	pa.cd -= dt * speed_mult * (1.0 + Save.up_value("haste")) * float(pa.aff) * _school_speed(pa)
	if pa.cd <= 0.0 and _beat_ready(pa):
		_cast(pa)
		_on_beat_cast(pa)
	for c in comps:
		if c.skill == "" or not _active(c):
			continue
		var s: Dictionary = c.st
		c.ult_cd = maxf(0.0, float(c.get("ult_cd", 0.0)) - dt)
		var mult: float = speed_mult * c.aff * c.syn * _school_speed(c) * (2.0 if float(bond_buff.get(c.key, 0.0)) > 0.0 else 1.0) * (0.8 if relics.has("ladder") else 1.0)
		if float(c.get("renew_t", 0.0)) > 0.0:
			c.renew_t = float(c.renew_t) - dt
			mult *= 1.0 + float(c.get("renew_amt", 0.0))   # 重新得力：剛被醫治的人出手更快
		if float(c.get("fed_t", 0.0)) > 0.0:
			c.fed_t = float(c.fed_t) - dt
			mult *= 1.2   # 高長煮的飯：吃飽了出手更快
		if barn_on and c != barn and c.pos.distance_to(barn.pos) < _aura_r(barn):
			mult *= barn.st.attack_speed
		c.cd -= dt * mult
		if c.cd > 0.0 or not _beat_ready(c):
			continue
		_cast(c)
		_on_beat_cast(c)


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
	s = _signature_pre(c, s)
	if s.is_empty():
		return false   # 這一招現在不出（例如雅各：隊伍還在走，跪不下來）
	match c.engine:
		"bolt":
			var targets := _nearest_enemies(c.pos, s.range, int(s.count))
			if float(s.get("prio", 0.0)) > 0.0:
				# 追根究柢：在射程內挑血最多的
				var pool := _nearest_enemies(c.pos, s.range, 12)
				pool.sort_custom(func(a, b): return float(a.hp) > float(b.hp))
				targets = pool.slice(0, int(s.count))
				_fxc("追血多")
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
			_heal_paul(float(s.amount))
			if float(s.get("smite", 0.0)) > 0.0:
				var nx := _nearest_enemies(c.pos, 140.0, int(s.smite))
				for o in nx:
					zaps.append({"pts": [c.pos + Vector2(0, -10), o.pos + Vector2(0, -4)], "t": 0.0, "evo": false, "col": C_HEAL})
					_fxc("醫生的手")
					_hurt(o, float(s.amount) * 1.5, Vector2.INF, c)
			_anoint_add(_sv("醫治", "anoint_bonus"))
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
					_anoint_add((o.hp + float(s.amount) - _comp_max_hp()) * 0.3)
					_heal_comp(o, float(s.amount), float(s.get("renew", 0.0)), float(s.get("cleanse", 0.0)) > 0.0)
					heals.append({"who": o, "t": 0.0})
					_ring_pop(o.pos + Vector2(0, -8), C_HEAL, 12.0)
		"beam":
			var tg_list := _nearest_enemies(c.pos, s.range, 1)
			fired = tg_list.size() > 0
			if fired:
				var from: Vector2 = c.pos + Vector2(0, -7)
				var base_dir: Vector2 = (tg_list[0].pos - from).normalized()
				var n := int(s.beams)
				if c.get("skill", "") == "lamp":
					# 尼哥底母「掃過」：提燈從一邊慢慢掃到另一邊
					var ss := s.duplicate()
					ss.damage = float(s.damage) * 0.45
					for k in 5:
						delayed.append({"t": k * 0.1, "fn": _fire_beam.bind(from, base_dir.rotated(deg_to_rad(-32.0 + k * 16.0)), ss, c.look, c)})
					n = 0
				for b in n:
					var ang := (b - (n - 1) / 2.0) * deg_to_rad(28.0)
					var bdir := base_dir.rotated(ang)
					_fire_beam(from, bdir, s, c.look, c)
					if c.get("skill", "") == "beam":
						# 亞波羅「折射」：光束打到底，再折向附近另一隻敵人
						var end: Vector2 = from + bdir * float(s.length) * _area()
						var nx := _nearest_enemies(end, 90.0, 1)
						if not nx.is_empty() and nx[0].pos.distance_to(end) > 6.0:
							var ss2 := s.duplicate()
							ss2.damage = float(s.damage) * 0.6
							ss2.length = minf(float(s.length), end.distance_to(nx[0].pos) + 30.0) / _area()
							ss2.burst = 0
							_fire_beam(end, (nx[0].pos - end).normalized(), ss2, c.look, c)
							_fxc("折射")
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
				if c.look != "dash":
					_lunge(c, s)
				var from: Vector2 = c.pos + Vector2(0, -6)
				var dir: Vector2 = (tl[0].pos - from).normalized()
				var crit := false
				for e in enemies:
					var rel: Vector2 = e.pos - from
					var along: float = rel.dot(dir)
					if not e.dead and along > 0.0 and along < s.range * _area() and absf(rel.cross(dir)) < s.width:
						var low: bool = float(s.get("execute", 0.0)) > 0.0 and float(e.hp) < float(e.get("hp0", e.hp)) * 0.3
						var is_crit: bool = randf() < float(s.crit) * (2.0 if low else 1.0)
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
				_heal_paul(float(s.heal))
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
			_lunge(c, s)
			var slams := int(s.slams)
			for i in slams:
				delayed.append({"t": i * 0.25, "fn": _nova.bind(c, s)})
		"strike":
			var cand := _nearest_enemies(c.pos, s.range, 12)
			fired = cand.size() > 0
			cand.shuffle()
			for i in mini(int(s.count), cand.size()):
				fires.append({"pos": cand[i].pos, "t": float(s.delay), "max": float(s.delay), "r": float(s.radius) * _area(), "dmg": float(s.damage), "owner": c, "evo": evolved.has(c.key), "look": c.look})
		"boomerang":
			# 馬可：皮袋飛出去再飛回來，去程回程都打得到
			var tl := _nearest_enemies(c.pos, float(s.range) * _area() + 30.0, 1)
			fired = not tl.is_empty()
			if fired:
				var bdir: Vector2 = (tl[0].pos - c.pos).normalized()
				var nb := int(s.count)
				for i in nb:
					boomers.append({"pos": c.pos + Vector2(0, -8), "dir": bdir.rotated(deg_to_rad((i - (nb - 1) / 2.0) * 25.0)), "dist": 0.0,
						"range": float(s.range) * _area(), "spd": float(s.speed), "back": false, "hit": {}, "owner": c,
						"dmg": float(s.damage), "life": 4.0, "evo": evolved.has(c.key)})
		"turret":
			# 撒該：種一棵桑樹，樹會自己丟果子
			var mine := trees.filter(func(tr): return tr.owner == c)
			if mine.size() >= int(s.max):
				trees.erase(mine[0])
			var ang := randf() * TAU
			trees.append({"pos": paul.pos + Vector2(cos(ang), sin(ang) * 0.7) * randf_range(24.0, 44.0), "life": float(s.life), "max": float(s.life), "cd": 0.3, "owner": c})
			_ring_pop(trees[-1].pos, c.col, 14.0)
		"orbit":
			# 約書亞：繞城的祭司一直在轉（在 _update_engines），出手時是一聲大呼
			var rr: float = float(s.max_radius) * _area()
			Sfx.play("shout", 0.05)
			blasts.append({"pos": paul.pos + Vector2(0, -6), "t": 0.0, "r": rr, "col": c.col, "evo": evolved.has(c.key)})
			for e in enemies.duplicate():
				if not e.dead and e.pos.distance_to(paul.pos) < rr:
					_hurt(e, float(s.shout), paul.pos, c)
					if not e.get("boss", false):
						e.knock += (e.pos - paul.pos).normalized() * float(s.knock)
		"zone":
			# 馬利亞：地上留下一片香氣
			var mz := zones.filter(func(z): return z.owner == c)
			if mz.size() >= int(s.max):
				zones.erase(mz[0])
			var tl2 := _nearest_enemies(paul.pos, 60.0, 1)
			var zp: Vector2 = paul.pos.lerp(tl2[0].pos, 0.5) if not tl2.is_empty() else paul.pos + Vector2(randf_range(-10, 10), 6)
			zones.append({"pos": zp, "life": float(s.life), "max": float(s.life), "r": float(s.radius) * _area(), "tick": 0.0, "owner": c})
		"trap":
			# 基甸：擺下瓶子，敵人碰到就打破、火把亮起
			for i in int(s.count):
				var mj := jars.filter(func(j): return j.owner == c)
				if mj.size() >= int(s.max):
					jars.erase(mj[0])
				var ja := randf() * TAU
				jars.append({"pos": paul.pos + Vector2(cos(ja), sin(ja) * 0.75) * randf_range(18.0, 52.0), "life": float(s.life), "owner": c})
		"pet":
			# 但以理：獅子撲向附近的敵人
			_ensure_lions(c, int(s.lions))
			fired = false
			for ln in c.lions:
				var tl3 := _nearest_enemies(ln.pos, float(s.reach) * _area(), 1)
				if tl3.is_empty() or ln.jump > 0.0:
					continue
				fired = true
				ln.from = ln.pos
				ln.to = tl3[0].pos
				ln.jump = 0.25
		"swallow":
			# 約拿：大魚吞下一排敵人，過一會兒吐出來砸出去
			var tl4 := _nearest_enemies(c.pos, float(s.length) * _area() + 20.0, 1)
			fired = not tl4.is_empty()
			if fired:
				var from: Vector2 = c.pos + Vector2(0, -4)
				var fdir: Vector2 = (tl4[0].pos - from).normalized()
				var flen: float = float(s.length) * _area()
				var cand := []
				for e in enemies:
					var rel: Vector2 = e.pos - from
					var along: float = rel.dot(fdir)
					if not e.dead and along > 0.0 and along < flen and absf(rel.cross(fdir)) < float(s.width) and float(e.get("ally", 0.0)) <= 0.0:
						cand.append(e)
				cand.sort_custom(func(a, b): return a.pos.distance_squared_to(from) < b.pos.distance_squared_to(from))
				var eaten := 0
				for e in cand.slice(0, int(s.count)):
					if not e.get("boss", false) and not e.get("elite", false) and float(e.hp) <= float(s.damage) * 4.0 * _dmg_mult():
						eaten += 1
						_kill(e, true, c)   # 吞下去了
					else:
						_hurt(e, float(s.damage), from, c)
				Sfx.play("splash")
				fishes.append({"pos": from + fdir * flen * 0.5, "dir": fdir, "len": flen, "t": 0.0, "hold": maxf(0.6, float(s.hold)),
					"eaten": eaten, "owner": c, "dmg": float(s.damage), "r": float(s.spit_r) * _area(), "done": false, "repent": float(s.get("repent", 0.0)) > 0.0})
		"wave":
			# 挪亞：洪水從畫面一側整片推過去
			var v := _view_rect()
			var tl5 := _nearest_enemies(paul.pos, 200.0, 1)
			var side: float = 1.0 if tl5.is_empty() or tl5[0].pos.x >= paul.pos.x else -1.0
			Sfx.play("splash", 0.0)
			for i in int(s.waves):
				var sd: float = side if i % 2 == 0 else -side
				floods.append({"x": v.position.x - 10.0 if sd > 0.0 else v.end.x + 10.0, "dir": sd, "y": paul.pos.y + (i - (int(s.waves) - 1) / 2.0) * 30.0,
					"h": float(s.height) * _area(), "spd": float(s.speed), "hit": {}, "dmg": float(s.damage), "push": float(s.push), "owner": c,
					"end": v.end.x + 20.0 if sd > 0.0 else v.position.x - 20.0, "delay": i * 0.35, "evo": evolved.has(c.key)})
		"rescue":
			# 以斯帖：標記最強的敵人（受到更多傷害）；保護在 _esther_save
			var best = null
			for e in _nearest_enemies(c.pos, float(s.range), 30):
				if best == null or float(e.hp) > float(best.hp):
					best = e
			fired = best != null
			if fired:
				best.exposed_t = float(s.mark_t)
				best.expose = maxf(float(best.get("expose", 0.0)), float(s.expose))
				best.crowned_t = float(s.mark_t)
				_hurt(best, float(s.damage), Vector2.INF, c)
				_ring_pop(best.pos + Vector2(0, -10), c.col, 12.0)
		"cone":
			# 米利暗：朝前方打出扇形的鼓聲
			var tl6 := _nearest_enemies(c.pos, float(s.range) * _area() + 20.0, 1)
			fired = not tl6.is_empty()
			if fired:
				_lunge(c, s)
				var cdir: Vector2 = (tl6[0].pos - c.pos).normalized()
				for i in int(s.pulses):
					delayed.append({"t": i * 0.18, "fn": _cone_hit.bind(c, s, cdir)})
		_:
			fired = false
			if not triggered:
				c.cd = 1.0
	if fired:
		c.casts = int(c.get("casts", 0)) + 1
		_signature_post(c, s, triggered)
	if fired and not triggered:
		c.cd = s.cooldown
		if c.get("skill", "") == "run":
			# 腓利：兩次衝刺（充能）——第一次衝完很快可以再衝一次
			if int(c.get("charges", 1)) > 0:
				c.charges = 0
				c.cd = 0.35
			else:
				c.charges = 1
	if fired:
		c.castfx = 0.18
		# 出手的動作：轉向最近的敵人、往那邊跨一小步
		var aim := _nearest_enemies(c.pos, 220.0, 1)
		c.cast_dir = (aim[0].pos - c.pos).normalized() if not aim.is_empty() else Vector2.ZERO
		if ult_now:
			c.ult_cd = float(D.tag_links.ult_cooldown)
			_tag_effect(c)
		if combo > 0 and (s.has("combo_keep") or float(c.get("tcombo", 0.0)) > 0.0):
			# 馬可、差派恩賜：出手讓連鎖多撐一下
			combo_t = minf(float(D.links.combo.window), combo_t + float(s.get("combo_keep", 0.0)) + float(c.get("tcombo", 0.0)))
		_fire_links("cast", c, depth)
		_bond_check(c)
		if not triggered:
			if c.get("anoints", []).has("echo"):
				c.echo_n = int(c.get("echo_n", 0)) + 1
				if c.echo_n % 3 == 0:
					delayed.append({"t": 0.2, "fn": _cast.bind(c, true, 1)})
			if relics.has("mantle") and randf() < 0.12:
				delayed.append({"t": 0.15, "fn": _cast.bind(c, true, 1)})
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
		L.cd = float(D.links.kinds[kind].cooldown) * float(D.links.levels.cooldown_mult[int(L.get("lv", 1)) - 1]) * float(L.dst.get("tlinkcd", 1.0)) * (0.7 if relics.has("ladder") else 1.0)
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
		if calling == "apostle" and L.src is Dictionary and L.src.get("tag", "") != L.dst.tag:
			L.dst.cross_until = t + 0.6   # 使徒：不同流派之間的連結威力加重
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
			_minions_strike()
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
## 設定「特效精簡」：碎片、光點、畫面震動減少
func _fx_lite() -> bool:
	return auto_lite or bool(Save.data.get("fxlite_on", false))


func _mote(at: Vector2, col: Color) -> void:
	if _fx_lite():
		return
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
	dnums.append({"e": e.node, "pos": e.pos + Vector2(randf_range(-4, 4), -14), "v": dmg, "t": 0.0, "col": col, "dx": randf_range(-10.0, 10.0)})


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
	return int(D.tag_links["守護"].max) + roundi((float(c.get("tlink", 1.0)) - 1.0) * 2.0) + int(Save.gift_global("guardcap")) + (2 if keystones.has("stand") else 0)


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
			guard = mini(maxi(_guard_max(c), _school_guard_cap()), guard + 1)
		"醫治":
			_heal_paul(float(T.heal) * k)
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


# ---------- 流派規則（同流派 2 人啟動、3、4 人升級） ----------
func _school_count(tag: String) -> int:
	var n := 0
	for c in comps:
		if c.level > 0 and c.follows == "" and c.engine != "" and c.tag == tag:
			n += 1
	if not pa.is_empty() and pa.get("tag", "") == tag:
		n += 1
	return n + int(school_mods.get("solo_" + tag, 0.0))


func _update_schools() -> void:
	if not D.has("schools") or pa.is_empty():
		return
	for tag in D.schools:
		var before: int = school_tier.get(tag, 0)
		var on: bool = pa_free.has(tag) or pa.get("anoints", []).has("s_" + tag)
		var nc := 0
		for k in school_cards:
			if k.begins_with(tag + ":"):
				nc += 1
		var tier: int = clampi(1 + nc, 1, 3) if on else 0
		school_tier[tag] = tier
		if tier > before and ui != null:
			var S: Dictionary = D.schools[tag]
			ui.show_banner("流派成形・%s「%s」" % [tag, S.name] if before == 0 else "流派深化・%s「%s」%d 階" % [tag, S.name, tier], 2.4)
			_ring_pop(paul.pos + Vector2(0, -8), TAG_COL.get(tag, C_GOLD), 50.0)
			_tip("school")
	_check_fusions()


## 主角或同流派的同伴：流派規則套用在誰身上（主角裝上的流派，主角也算）
func _tagged(c, tag: String) -> bool:
	if not (c is Dictionary):
		return false
	if c.get("tag", "") == tag:
		return true
	return not pa.is_empty() and is_same(c, pa) and _school_on(tag)


## 主角的輔助格：基本 1 格，招式 Lv3、進化各多 1 格，使徒再 +1
func _support_slots() -> int:
	var n := int(D.support_rules.base_slots)
	if int(pa.get("level", 1)) >= 3:
		n += 1
	if evolved.has(pa.get("key", "")):
		n += 1
	if calling == "apostle":
		n += 1
	return n


## 升級時出現的輔助卡：同伴練到 Lv3 借出他的流派；偶爾出現一般輔助
func _support_cards() -> Array:
	var out := []
	if pa.is_empty() or pa.get("skill", "") == "":
		return out
	var used: Array = pa.get("anoints", [])
	if used.size() >= _support_slots():
		return out
	var lent := {}
	for c in comps:
		if c.level < int(D.support_rules.lend_level) or c.follows != "" or not D.schools.has(c.tag):
			continue
		if used.has("s_" + c.tag) or pa_free.has(c.tag) or lent.has(c.tag):
			continue
		lent[c.tag] = true
		var S: Dictionary = D.schools[c.tag]
		out.append({"kind": "anoint", "key": pa.key, "aid": "s_" + c.tag, "tag": c.tag,
			"title": "%s借出「%s」→ %s" % [c.name, S.name, pa.name],
			"desc": "%s%s
（主角輔助 %d／%d 格）" % [D.school_supports[c.tag], _fusion_hint(c.tag), used.size(), _support_slots()]})
	if randf() < float(D.support_rules.card_chance):
		var eng: String = pa.get("engine", "")
		var opts: Array = D.anoints.filter(func(a): return not used.has(a.id) and (a.engines.has("all") or a.engines.has(eng)))
		if not opts.is_empty():
			var a: Dictionary = opts.pick_random()
			out.append({"kind": "anoint", "key": pa.key, "aid": a.id, "tag": "輔助",
				"title": "輔助「%s」→ %s" % [a.name, pa.name], "desc": "%s
（主角輔助 %d／%d 格）" % [a.desc, used.size(), _support_slots()]})
	out.shuffle()
	return out.slice(0, 2)


func _fusion_hint(tag: String) -> String:
	for f in D.fusions:
		var other := ""
		if f.a == tag:
			other = f.b
		elif f.b == tag:
			other = f.a
		if other != "" and _school_on(other):
			return "
＋%s 融合：「%s」%s" % [other, f.name, f.desc]
	return ""


## 兩個流派同時成形：融合出新玩法
func _check_fusions() -> void:
	for f in D.fusions:
		var k: String = f.a + "+" + f.b
		if fusions_on.has(k) or not (_school_on(f.a) and _school_on(f.b)):
			continue
		fusions_on[k] = true
		if smoke:
			print("FUSION ", f.name)
		if ui != null:
			ui.show_banner("融合！%s＋%s「%s」\n%s" % [f.a, f.b, f.name, f.desc], 3.2)
			_ring_pop(paul.pos + Vector2(0, -8), C_GOLD, 70.0)
			_ring_pop(paul.pos + Vector2(0, -8), TAG_COL.get(f.b, C_GOLD), 46.0)
			Sfx.play("holy", 0.0)


func _fused(a: String, b: String) -> bool:
	return fusions_on.has(a + "+" + b) or fusions_on.has(b + "+" + a)


## 融合發動了：記次數，偶爾在發動的地方冒出融合的名字（讓玩家看得出是哪個融合在作用）
func _fz(a: String, b: String, at: Vector2) -> void:
	for f in D.fusions:
		if (f.a == a and f.b == b) or (f.a == b and f.b == a):
			fz_count[f.name] = int(fz_count.get(f.name, 0)) + 1
			if t >= float(fz_tag_t.get(f.name, 0.0)) and tag_fx.size() < 12:
				fz_tag_t[f.name] = t + 6.0
				if at.distance_to(paul.pos) > 90.0:
					at = paul.pos   # 發動點太遠（可能在畫面外），就冒在主角身上
				tag_fx.append({"pos": at + Vector2(-10, -6), "text": "「%s」" % f.name, "col": TAG_COL.get(f.b, C_GOLD).lerp(TAG_COL.get(f.a, C_GOLD), 0.35), "t": 0.0})
			return


## 以善勝惡：把一點醫治給隊伍裡（含主角）血量比例最低的人
func _atone(n: float) -> void:
	n = clampf(n, 0.5, 6.0)
	var low = null
	var low_k: float = float(paul.hp) / float(D.paul.hp)
	for c in comps:
		if c.level > 0 and c.down <= 0.0 and float(c.hp) / _comp_max_hp() < low_k:
			low = c
			low_k = float(c.hp) / _comp_max_hp()
	if low == null:
		_heal_paul(n)
		_mote(paul.pos + Vector2(0, -10), C_HEAL)
	else:
		_heal_comp(low, n)
		_mote(low.pos + Vector2(0, -10), C_HEAL)


func _heal_party(n: float) -> void:
	_heal_paul(n)
	for c in comps:
		if c.level > 0 and c.down <= 0.0:
			_heal_comp(c, n)


## 醫治一位同伴：補血；醫治流派「重新得力」讓他 3 秒內攻擊加快；cleanse 時把睡著、被嚇散的叫回來
func _heal_comp(o: Dictionary, n: float, renew := 0.0, cleanse := false) -> void:
	o.hp = minf(_comp_max_hp(), float(o.hp) + n)
	var rn: float = renew + _sv("醫治", "renew")
	if rn > 0.0:
		o.renew_t = 3.0
		_fxc("得力")
		o.renew_amt = maxf(float(o.get("renew_amt", 0.0)) if float(o.get("renew_t", 0.0)) > 0.0 else 0.0, rn)
	if cleanse:
		if float(o.get("sleep", 0.0)) > 0.0:
			o.sleep = 0.0
			_ring_pop(o.pos + Vector2(0, -8), C_CREAM, 12.0)
		if o.off.length() > 10.0:
			o.off = Vector2.ZERO   # 被嚇散的立刻回到隊伍
			o.vel = Vector2.ZERO


## 融合：重拍的時候
func _fusion_downbeat() -> void:
	if _fused("講道", "詩歌"):
		for e in enemies:
			if e.dead or float(e.get("ally", 0.0)) <= 0.0:
				continue
			_fz("講道", "詩歌", e.pos)
			blasts.append({"pos": e.pos, "t": 0.0, "r": 18.0, "col": C_GOLD, "evo": false})
			for o in enemies.duplicate():
				if not o.dead and float(o.get("ally", 0.0)) <= 0.0 and o.pos.distance_to(e.pos) < 18.0:
					_hurt(o, 5.0 + level * 0.4, e.pos)
	if _fused("詩歌", "守護"):
		fz_beat += 1
		if fz_beat % 2 == 0 and guard < _school_guard_cap():
			guard += 1
			_ring_pop(paul.pos + Vector2(0, -8), Color("9fd8ff"), 14.0)
			_fz("詩歌", "守護", paul.pos)
	if _fused("詩歌", "醫治"):
		_heal_party(1.5)
		_anoint_add(4.0)
		_ring_pop(paul.pos + Vector2(0, -8), C_HEAL, 22.0)
		_fz("詩歌", "醫治", paul.pos)
	if _fused("詩歌", "差派") and not trail.is_empty():
		_fz("詩歌", "差派", trail[-1].pos)
		for f in trail.slice(maxi(0, trail.size() - 16)):
			_mote(f.pos, C_FLAME)
			for o in enemies.duplicate():
				if not o.dead and float(o.get("ally", 0.0)) <= 0.0 and o.pos.distance_squared_to(f.pos) < 120.0:
					_hurt(o, 4.0 + level * 0.3, Vector2.INF)
	if _fused("詩歌", "門徒"):
		if not minions.is_empty():
			_fz("詩歌", "門徒", minions[0].pos)
		for m in minions:
			blasts.append({"pos": m.pos, "t": 0.0, "r": 14.0, "col": Color("e8dcc0"), "evo": false})
			for o in enemies.duplicate():
				if not o.dead and float(o.get("ally", 0.0)) <= 0.0 and o.pos.distance_to(m.pos) < 14.0:
					_hurt(o, 5.0 + level * 0.4, m.pos)


func _school_on(tag: String) -> bool:
	return int(school_tier.get(tag, 0)) > 0


## 流派規則的數值：這一階的基本值＋流派卡、恩賜的改寫（流派沒啟動時是 0）
func _sv(tag: String, key: String) -> float:
	var tier: int = school_tier.get(tag, 0)
	if tier <= 0:
		return 0.0
	return float(D.schools[tag].tiers[tier - 1].get(key, 0.0)) + float(school_mods.get(key, 0.0))


## 升級時出現的流派卡：每個已啟動的流派最多一張
func _school_cards() -> Array:
	var out := []
	var flags := ["offbeat", "yoke", "holy_garment", "minion_pair", "convert_boom", "convert_elite", "newsong", "revive_all"]
	for tag in school_tier:
		if int(school_tier[tag]) <= 0:
			continue
		var opts: Array = D.schools[tag].cards.filter(func(sc):
			if school_cards.has(tag + ":" + sc.id):
				return false
			for k in sc.mod:
				if flags.has(k) and float(school_mods.get(k, 0.0)) > 0.0:
					return false   # 恩賜已經給了同樣的開關
			return true)
		if opts.is_empty():
			continue
		var sc: Dictionary = opts.pick_random()
		out.append({"kind": "school", "key": tag + ":" + sc.id, "title": sc.name, "tag": tag, "mod": sc.mod,
			"desc": "「%s」規則改寫：%s\n（%s）" % [D.schools[tag].name, sc.desc, sc.ref]})
	return out


## 差派：主角在走時攻擊更快、站著變慢；站在腳蹤上再快一點
func _school_speed(c: Dictionary) -> float:
	if not _tagged(c, "差派"):
		return 1.0
	var m: float = (1.0 + _sv("差派", "move_haste")) if paul.moving else 0.75
	var relay := _sv("差派", "relay")
	if relay > 0.0:
		for f in trail:
			if f.pos.distance_squared_to(c.pos) < 144.0:
				m *= 1.0 + relay
				break
	return m


# 詩歌：拍子
func _update_beat(dt: float) -> void:
	beat_now = false
	if not _school_on("詩歌"):
		return
	beat_clock += dt
	var mp: AudioStreamPlayer = Sfx.music_player
	if mp.playing and is_equal_approx(Engine.time_scale, 1.0):
		var mpos := mp.get_playback_position()
		if mpos != beat_last_mpos:
			beat_clock = mpos + AudioServer.get_time_since_last_mix()
		beat_last_mpos = mpos
	var bpm := float(D.get("music_bpm", {}).get(Sfx.music_name, 128))
	var bi := int(floor(beat_clock * bpm / 60.0))
	if bi == beat_i:
		return
	beat_i = bi
	beat_now = true
	beat_down = bi % 4 == 0 or (_sv("詩歌", "offbeat") > 0.0 and bi % 4 == 2)
	var m: float = _sv("詩歌", "downbeat_mult") if beat_down else 1.0
	for c in comps + [pa]:
		if _tagged(c, "詩歌"):
			c.beat_mult = m
	if beat_down:
		_fusion_downbeat()
		if _sv("詩歌", "march") > 0.0:
			# 列隊前進：重拍時身邊的敵人變慢，全隊攻擊加快一下
			for e in _enemies_near(paul.pos, 120.0):
				if not e.dead and e.pos.distance_to(paul.pos) < 120.0:
					e.slow_t = maxf(float(e.get("slow_t", 0.0)), 1.0)
			haste_t = maxf(haste_t, 1.0)
			haste_amt = maxf(haste_amt, 0.15)


## 詩歌同伴只在拍子上出手（「節拍」流派成形以後才有拍子；還沒成形時照一般方式出手）
func _beat_ready(c: Dictionary) -> bool:
	return not _school_on("詩歌") or not _tagged(c, "詩歌") or beat_now


func _on_beat_cast(c: Dictionary) -> void:
	if not _tagged(c, "詩歌") or not beat_down:
		return
	_ring_pop(c.pos + Vector2(0, -8), C_GOLD, 22.0)
	_mote(c.pos + Vector2(0, -14), C_GOLD)
	Sfx.play("downbeat", 0.0)
	if fever <= 0.0:
		meter = minf(1.0, meter + _sv("詩歌", "downbeat_meter"))


func _praise_song() -> void:
	praise = 0.0
	run_songs += 1
	var mult := 1.0 + _sv("詩歌", "praise_boom_mult")
	var dmg := (12.0 + level * 1.2) * mult
	var v := _view_rect()
	songs.append({"pos": paul.pos + Vector2(0, -8), "t": 0.0})
	shake = maxf(shake, 0.2)
	Sfx.play("song", 0.0)
	ui.show_banner("讚美！全場的詩歌", 1.4)
	for e in enemies.duplicate():
		if not e.dead and v.has_point(e.pos):
			_hurt(e, dmg * (0.4 if e.get("boss", false) else 1.0), paul.pos)
			if not e.get("boss", false):
				e.stun = maxf(e.stun, 1.0)
	if _sv("詩歌", "newsong") > 0.0:
		haste_t = 5.0
		haste_amt = maxf(haste_amt, 0.3)
	if _sv("詩歌", "ambush") > 0.0:
		# 自相擊殺：畫面上的黑暗勢力亂了陣腳，互相攻擊
		for e in enemies:
			if not e.dead and v.has_point(e.pos) and not e.get("boss", false) and not e.get("elite", false) and float(e.get("ally", 0.0)) <= 0.0:
				e.confused = maxf(float(e.get("confused", 0.0)), 3.0)


# 講道：說服
func _persuade(e: Dictionary, n: int) -> void:
	if e.dead or e.get("boss", false) or float(e.get("ally", 0.0)) > 0.0:
		return
	var need := maxi(1, int(_sv("講道", "msg_need")))
	if e.get("elite", false):
		if _sv("講道", "convert_elite") <= 0.0:
			return
		need *= 3
	e.msg = int(e.get("msg", 0)) + n
	if e.msg < need:
		return
	e.msg = 0
	_convert(e, _sv("講道", "convert_dur"))


## 被黑暗捆綁的人被說服、得了釋放，暫時一起對抗黑暗（同時最多 14 位）
func _convert(e: Dictionary, dur: float) -> void:
	if e.dead or float(e.get("ally", 0.0)) > 0.0:
		return
	var allies := 0
	for o in enemies:
		if float(o.get("ally", 0.0)) > 0.0:
			allies += 1
	if allies >= 14:
		return
	e.ally = dur
	Sfx.play("persuade")
	_tip("convert")
	e.stun = 0.0
	e.knock = Vector2.ZERO
	run_converts += 1
	_ring_pop(e.pos + Vector2(0, -4), C_GOLD, 16.0)
	if _fused("講道", "醫治") and t >= fz_heal_t:
		fz_heal_t = t + 0.25
		_heal_party(1.0)
		_mote(paul.pos + Vector2(0, -10), C_HEAL)
		_fz("講道", "醫治", paul.pos)
	if _fused("講道", "門徒") and randf() < 0.25:
		_spawn_minion(e.pos)
		_fz("講道", "門徒", e.pos)
	for i in 3:
		_mote(e.pos + Vector2(0, -6), C_GOLD)


## 被說服的人：每個黑暗的勢力背後都捆綁著一個人；說服了，他就得釋放（金色），
## 跟你一起去撞黑暗，時間到就回家去（算你驅散的）
func _update_ally(e: Dictionary, dt: float) -> void:
	e.ally -= dt
	if e.ally <= 0.0:
		e.ally = 0.0
		if _sv("講道", "convert_heal") > 0.0:
			# 使人和好：被說服的人回家時，主角與附近的同伴回血
			_heal_paul(_sv("講道", "convert_heal"))
			for c in comps:
				if c.level > 0 and c.down <= 0.0 and c.pos.distance_to(e.pos) < 80.0:
					c.hp = minf(_comp_max_hp(), float(c.hp) + _sv("講道", "convert_heal"))
			_mote(paul.pos + Vector2(0, -10), C_HEAL)
		if _sv("講道", "convert_boom") > 0.0:
			var r := 36.0
			blasts.append({"pos": e.pos, "t": 0.0, "r": r, "col": C_GOLD, "evo": false})
			for o in enemies.duplicate():
				if o != e and not o.dead and o.pos.distance_to(e.pos) < r:
					_hurt(o, 16.0 + level, e.pos)
		if calling == "evangelist":
			for i in 2:
				gems.append({"pos": e.pos + Vector2(randf_range(-6, 6), randf_range(-5, 5)), "got": false})
		# 得釋放的人回家去了；有的想知道更多，留下來成了尋找的人
		if randf() < 0.15 and not solo:
			_spawn_seeker(e.pos, {"name": "得釋放的人", "ref": "徒 26:18", "line": "我想知道更多……"})
		_kill(e, true)
		return
	var best = null
	var bd := 150.0 * 150.0
	for o in enemies:
		if o.dead or o == e or float(o.get("ally", 0.0)) > 0.0:
			continue
		var d2: float = o.pos.distance_squared_to(e.pos)
		if d2 < bd:
			bd = d2
			best = o
	var target: Vector2 = paul.pos + Vector2(0, 16) if best == null else best.pos
	var to: Vector2 = target - e.pos
	if to.length() > 4.0:
		e.pos += to.normalized() * float(e.d.speed) * 1.4 * dt
	if best != null and e.cd <= 0.0 and sqrt(bd) < float(e.r) + 6.0:
		e.cd = 0.5
		_hurt(best, maxf(6.0, float(e.d.damage) * 1.5), e.pos)
		var sp := int(_sv("講道", "convert_spread"))
		if sp > 0:
			_persuade(best, sp)


# 守護：盾即是劍
func _school_guard_cap() -> int:
	return 2 + int(_sv("守護", "guard_bonus")) if _school_on("守護") else 0


func _shield_shock(at: Vector2) -> void:
	if _fused("講道", "守護"):
		var nx := _nearest_enemies(at, 60.0, 1, {})
		if not nx.is_empty() and not nx[0].get("boss", false) and not nx[0].get("elite", false):
			_convert(nx[0], 6.0)
			link_fx.append({"a": at + Vector2(0, -6), "b": nx[0], "t": 0.0, "depth": 1})
			_fz("講道", "守護", nx[0].pos)
	if _fused("守護", "醫治"):
		_heal_paul(3.0)
		_mote(paul.pos + Vector2(0, -10), C_HEAL)
		_fz("守護", "醫治", paul.pos)
	run_shocks += 1
	Sfx.play("shield")
	var r := 40.0 * (1.0 + _sv("守護", "shock_area"))
	var dmg := _sv("守護", "shock_dmg") * (1.0 + level * 0.05)
	blasts.append({"pos": at + Vector2(0, -6), "t": 0.0, "r": r, "col": Color("9fd8ff"), "evo": false, "shock": true})
	shake = maxf(shake, 0.1)
	for e in enemies.duplicate():
		if not e.dead and e.pos.distance_to(at) < r:
			_hurt(e, dmg, at)
			if not e.get("boss", false):
				e.knock += (e.pos - at).normalized() * 140.0
				if _sv("守護", "shield_stun") > 0.0:
					e.stun = maxf(e.stun, 1.5)   # 大小的盾牌：被震開的敵人暈眩


# 醫治：滿溢
func _heal_paul(n: float) -> void:
	if trials.has("drought"):
		n *= 0.6   # 信心等級：乾旱
	if keystones.has("overcome"):
		n *= 0.8   # 基石「以善勝惡」：治療量 -20%，滿出來的變成光
		var over: float = paul.hp + n - _hp_cap()
		if over > 1.0 and t >= float(overcome_cd):
			var tg := _nearest_enemies(paul.pos, 140.0, 1)
			if not tg.is_empty():
				overcome_cd = t + 0.3
				zaps.append({"pts": [paul.pos + Vector2(0, -14), tg[0].pos + Vector2(0, -4)], "t": 0.0, "evo": true, "col": C_HEAL})
				_hurt(tg[0], over * 2.0 + level * 0.5, Vector2.INF)
				_fxc("以善勝惡")
	_anoint_add(paul.hp + n - float(D.paul.hp))
	paul.hp = minf(_hp_cap(), maxf(paul.hp, minf(float(D.paul.hp), paul.hp + n)))
	if n > 0.0 and _sv("醫治", "heal_smite") > 0.0 and t >= smite_cd:
		# 鞭傷：主角被治療時，一道光打向最近的敵人
		var nx := _nearest_enemies(paul.pos, 130.0, 1)
		if not nx.is_empty():
			smite_cd = t + 0.25
			zaps.append({"pts": [paul.pos + Vector2(0, -10), nx[0].pos + Vector2(0, -4)], "t": 0.0, "evo": true, "col": C_HEAL})
			_hurt(nx[0], maxf(4.0, n * _sv("醫治", "heal_smite")) + level * 0.5, Vector2.INF)


func _anoint_add(v: float) -> void:
	if v <= 0.0 or not _school_on("醫治"):
		return
	anoint += v
	if anoint >= _sv("醫治", "anoint_need"):
		_holy_light()


func _holy_light() -> void:
	anoint = 0.0
	run_holies += 1
	var k := 1.0 + _sv("醫治", "holy_mult")
	var r := 64.0 * k
	var dmg := _sv("醫治", "holy_dmg") * k * (1.0 + level * 0.04)
	holies.append({"pos": paul.pos, "t": 0.0, "r": r})
	if _sv("醫治", "holy_pool") > 0.0 and spots.size() < 40:
		spots.append({"kind": "water", "pos": paul.pos, "life": 5.0, "tick": 0.0, "r": r * 0.6})   # 活水：留下一片水
	ui.show_banner("滿溢！聖光", 1.2)
	if _fused("守護", "醫治") and guard < _school_guard_cap():
		guard += 1
	Sfx.play("holy", 0.0)
	for e in enemies.duplicate():
		if not e.dead and e.pos.distance_to(paul.pos) < r:
			_hurt(e, dmg, paul.pos)
	paul.hp = minf(float(D.paul.hp), paul.hp + 10.0)
	var revived := false
	for o in comps:
		if o.level == 0:
			continue
		if o.down > 0.0 and (not revived or _sv("醫治", "revive_all") > 0.0):
			o.down = 0.0
			o.hp = _comp_max_hp() * 0.6
			revived = true
			_ring_pop(o.pos + Vector2(0, -8), C_HEAL, 20.0)
		elif o.down <= 0.0:
			o.hp = minf(_comp_max_hp(), o.hp + 20.0)
		if _sv("醫治", "holy_garment") > 0.0 and o.down <= 0.0:
			o.garment = mini(int(o.get("garment", 0)) + 1, 3)
		heals.append({"who": o, "t": 0.0})


# 門徒：得人
func _spawn_minion(at: Vector2) -> void:
	if minions.size() >= int(_sv("門徒", "minion_cap")):
		return
	run_minions += 1
	minions.append({"pos": at, "life": 12.0 + _sv("門徒", "minion_life"), "cd": 0.3, "hop": 0.0, "ph": randf() * TAU})
	if _sv("門徒", "minion_net") > 0.0:
		# 撒在深水：小門徒一出現就撒網，把身邊的敵人拉過來定住
		nets.append({"pos": at, "r": 50.0, "t": 0.0, "evo": false, "look": "", "stun": 0.8, "col": Color("e8dcc0")})
		for e in _enemies_near(at, 56.0):
			if not e.dead and not e.get("boss", false) and e.pos.distance_to(at) < 50.0:
				e.knock += (at - e.pos) * 3.0
				e.stun = maxf(e.stun, 0.8)
	if _fused("守護", "門徒") and t >= fz_guard_t and guard < _school_guard_cap():
		fz_guard_t = t + 3.0
		guard += 1
		_ring_pop(paul.pos + Vector2(0, -8), Color("9fd8ff"), 14.0)
		_fz("守護", "門徒", paul.pos)
	if _fused("醫治", "門徒"):
		_heal_paul(2.0)
		_mote(paul.pos + Vector2(0, -10), C_HEAL)
		_fz("醫治", "門徒", at)
		var low = null
		for c in comps:
			if c.level > 0 and c.down <= 0.0 and (low == null or float(c.hp) < float(low.hp)):
				low = c
		if low != null:
			low.hp = minf(_comp_max_hp(), float(low.hp) + 2.0)
	_ring_pop(at + Vector2(0, -6), Color("e8dcc0"), 12.0)


func _minion_dmg() -> float:
	return (5.0 + level * 0.5) * (1.0 + _sv("門徒", "minion_dmg_mult"))


## 肢體連結觸發時，小門徒一起衝出去打一下
func _minions_strike() -> void:
	if minions.is_empty() or minion_strike_t > 0.0:
		return
	minion_strike_t = 0.3
	for m in minions:
		var tl := _nearest_enemies(m.pos, 70.0, 1)
		if tl.is_empty():
			continue
		m.pos = m.pos.lerp(tl[0].pos, 0.7)
		m.hop = 0.2
		_hurt(tl[0], _minion_dmg(), m.pos)


## 每一格：腳蹤、護盾長回來、讚美、小門徒
func _update_schools_step(dt: float) -> void:
	if guard > 0 and _sv("守護", "guard_slow") > 0.0:
		guard_slow_t -= dt
		if guard_slow_t <= 0.0:
			guard_slow_t = 0.3
			for e in _enemies_near(paul.pos, 50.0):
				if not e.dead and e.pos.distance_to(paul.pos) < 50.0:
					e.slow_t = maxf(float(e.get("slow_t", 0.0)), 0.5)
	# 差派：腳蹤（平安的鞋 Lv3 沒有差派流派也會留下）
	var shoes_only: bool = not _school_on("差派") and armor.get("shoes", 0) >= 3
	if _school_on("差派") or shoes_only:
		if paul.moving:
			trail_t -= dt
			if trail_t <= 0.0:
				trail_t = 0.28 if shoes_only else _sv("差派", "trail_every")
				if shoes_only:
					_fxc("鞋的腳蹤")
				var life := 3.0 + _sv("差派", "trail_life")
				trail.append({"pos": paul.pos + Vector2(0, 1), "life": life, "max": life, "side": trail.size() % 2})
				if _sv("差派", "trail_heal") > 0.0:
					_heal_paul(_sv("差派", "trail_heal"))   # 如鹿的腳：走得越多，回得越多
		trail_tick -= dt
		if trail_tick <= 0.0 and not trail.is_empty():
			trail_tick = 0.35
			var dmg := (3.0 if shoes_only else _sv("差派", "trail_dmg")) * (1.0 + _sv("差派", "trail_mult")) * (1.0 + level * 0.03) * (1.5 if _fused("守護", "差派") and guard > 0 else 1.0)
			var box := Rect2(trail[0].pos, Vector2.ZERO)
			for f in trail:
				box = box.expand(f.pos)
			box = box.grow(10.0)
			for e in enemies.duplicate():
				if e.dead or not box.has_point(e.pos) or float(e.get("ally", 0.0)) > 0.0:
					continue
				for f in trail:
					if f.pos.distance_squared_to(e.pos) < 110.0:
						e.slow_t = 0.8
						if _sv("差派", "trail_expose") > 0.0:
							e.exposed_t = maxf(float(e.get("exposed_t", 0.0)), 2.0)   # 腳前的燈：踩到的露出破綻
							e.expose = maxf(float(e.get("expose", 0.0)), _sv("差派", "trail_expose"))
						_hurt(e, dmg, Vector2.INF)
						if _fused("講道", "差派") and not e.dead:
							_persuade(e, 1)
							_fz("講道", "差派", e.pos)
						break
		if _fused("醫治", "差派"):
			for c in comps:
				if c.level > 0 and c.down <= 0.0 and trail.any(func(f): return f.pos.distance_squared_to(c.pos) < 144.0):
					c.hp = minf(_comp_max_hp(), float(c.hp) + 2.0 * 0.35)
					if randf() < 0.3:
						_mote(c.pos + Vector2(0, -8), C_HEAL)
					_fz("醫治", "差派", c.pos)
		if _fused("差派", "門徒") and paul.moving and not trail.is_empty():
			fz_pair_t -= 0.35
			if fz_pair_t <= 0.0:
				fz_pair_t = 5.0
				_spawn_minion(trail[-1].pos)
				_fz("差派", "門徒", trail[-1].pos)
	for f in trail:
		f.life -= dt
	trail = trail.filter(func(f): return f.life > 0.0)
	# 守護：護盾自己長回來
	if _school_on("守護"):
		guard_regen -= dt * (2.0 if _fused("守護", "差派") and paul.moving else 1.0)
		if guard_regen <= 0.0:
			guard_regen = maxf(1.5, _sv("守護", "regen_cd"))
			if guard < _school_guard_cap():
				guard += 1
				_ring_pop(paul.pos + Vector2(0, -8), Color("9fd8ff"), 14.0)
	# 詩歌：讚美滿了
	if _school_on("詩歌") and praise >= _sv("詩歌", "praise_need"):
		_praise_song()
	for sg in songs:
		sg.t += dt
	songs = songs.filter(func(sg): return sg.t < 0.9)
	for hl in holies:
		hl.t += dt
	holies = holies.filter(func(hl): return hl.t < 0.7)
	crit_t = maxf(0.0, crit_t - dt)
	if calling == "prophet":
		_update_prophecy(dt)
	for rn in rains:
		rn.t += dt
	rains = rains.filter(func(rn): return rn.t < 1.6)
	feast_t = maxf(0.0, feast_t - dt)
	for k in bond_buff.keys():
		bond_buff[k] = float(bond_buff[k]) - dt
		if bond_buff[k] <= 0.0:
			bond_buff.erase(k)
	# 門徒：小門徒
	minion_strike_t = maxf(0.0, minion_strike_t - dt)
	for m in minions:
		m.life -= dt
		m.cd -= dt
		m.hop = maxf(0.0, m.hop - dt)
		if m.pos.distance_to(paul.pos) > 170.0:
			m.pos = paul.pos + Vector2(randf_range(-20, 20), randf_range(10, 20))
		var tl := _nearest_enemies(m.pos, 90.0, 1)
		var target: Vector2 = paul.pos + Vector2(cos(m.ph) * 26.0, sin(m.ph) * 16.0 + 10.0) if tl.is_empty() else tl[0].pos
		var to: Vector2 = target - m.pos
		if to.length() > 5.0:
			m.pos += to.normalized() * 75.0 * dt
		if not tl.is_empty() and to.length() < 10.0 and m.cd <= 0.0:
			m.cd = 0.6
			m.hop = 0.15
			_hurt(tl[0], _minion_dmg(), m.pos)
			if tl[0].dead and _sv("門徒", "minion_heal") > 0.0:
				_heal_paul(_sv("門徒", "minion_heal"))   # 彼此相顧
	minions = minions.filter(func(m): return m.life > 0.0)


# ---------- 同行合擊（兩位同伴先後出手就發動） ----------
## 隊伍裡這位同伴（或主角）：不在、倒下、睡著時回傳空的
func _member(k: String) -> Dictionary:
	if not pa.is_empty() and pa.key == k:
		return pa
	if by_key.has(k) and by_key[k] != pa and _active(by_key[k]):
		return by_key[k]
	return {}


## 先知：每隔一陣子，在敵人最多的地方標出「預言之地」，裡面的敵人受到兩倍傷害
func _update_prophecy(dt: float) -> void:
	if not prophecy.is_empty():
		prophecy.t -= dt
		if prophecy.t <= 0.0:
			prophecy = {}
		return
	prophecy_t -= dt
	if prophecy_t > 0.0:
		return
	prophecy_t = 11.0
	var v := _view_rect()
	var foes := enemies.filter(func(e): return not e.dead and v.has_point(e.pos))
	if foes.is_empty():
		return
	var best: Vector2 = foes[0].pos
	var best_n := -1
	for i in mini(12, foes.size()):
		var c0: Vector2 = foes[randi() % foes.size()].pos
		var n := 0
		for e in foes:
			if e.pos.distance_squared_to(c0) < 2500.0:
				n += 1
		if n > best_n:
			best_n = n
			best = c0
	prophecy = {"pos": best, "r": 52.0, "t": 8.0}
	if tag_fx.size() < 12:
		tag_fx.append({"pos": best + Vector2(-12, 20), "text": "預言之地", "col": Color("c8a0ff"), "t": 0.0})


## 招募卡上的提示：跟隊伍裡的誰是搭檔
func _bond_hint(k: String) -> String:
	if not _sys_open("bond"):
		return ""
	for B in D.get("bonds", []):
		var mate: String = B.b if B.a == k else (B.a if B.b == k else "")
		if mate != "" and not _member(mate).is_empty():
			return "\n同行：與%s合擊「%s」" % [_member(mate).name, B.name]
	return ""


func _bond_check(c: Dictionary) -> void:
	if not D.has("bonds") or not _sys_open("bond"):
		return
	c.last_cast = t
	for i in D.bonds.size():
		var B: Dictionary = D.bonds[i]
		if B.a != c.key and B.b != c.key:
			continue
		if t < float(bond_cd.get(i, 0.0)):
			continue
		var other := _member(B.b if B.a == c.key else B.a)
		var shep: bool = calling == "shepherd"
		if other.is_empty() or t - float(other.get("last_cast", -99.0)) > float(D.bond_rules.window) * (1.7 if shep else 1.0):
			continue
		bond_cd[i] = t + float(D.bond_rules.cooldown) * (0.6 if shep else 1.0)
		_bond_fx(B, c, other)


func _bond_fx(B: Dictionary, c: Dictionary, other: Dictionary) -> void:
	run_bonds += 1
	link_fx.append({"a": c.pos + Vector2(0, -8), "b": other, "t": 0.0, "depth": 3})
	_ring_pop(c.pos + Vector2(0, -8), C_GOLD, 26.0)
	_ring_pop(other.pos + Vector2(0, -8), C_GOLD, 26.0)
	if tag_fx.size() < 12:
		tag_fx.append({"pos": (c.pos + other.pos) / 2.0 + Vector2(-10, 0), "text": "合擊・" + B.name, "col": C_GOLD, "t": 0.0})
	if not bonds_seen.has(B.name):
		bonds_seen[B.name] = true
		ui.show_banner("同行合擊：%s（%s）" % [B.name, B.ref], 2.2)
		_tip("bond")
	Sfx.play("bond", 0.0)
	var v := _view_rect()
	var foes := enemies.filter(func(e): return not e.dead and v.has_point(e.pos) and float(e.get("ally", 0.0)) <= 0.0)
	match B.fx:
		"quake":
			for e in foes:
				_hurt(e, 10.0 + level, paul.pos)
				if not e.get("boss", false):
					e.stun = maxf(e.stun, 1.5)
			quakes.append({"pos": paul.pos, "r": 0.0})
			shake = 0.35
		"haste":
			haste_t = 5.0
			haste_amt = maxf(haste_amt, 0.4)
			for i in 3:
				_combo_add()
		"empower":
			bond_buff[B.b] = 6.0
			var em := _member(B.b)
			if not em.is_empty():
				_ring_pop(em.pos + Vector2(0, -8), C_FLAME, 30.0)
		"care":
			paul.hp = float(D.paul.hp)
			guard = mini(guard + 2, 5)
			heals.append({"who": paul, "t": 0.0})
		"bread":
			for i in 6:
				breads.append({"pos": paul.pos + Vector2(randf_range(-30, 30), randf_range(-24, 24))})
			for o in comps:
				if o.level > 0 and o.down <= 0.0:
					o.hp = minf(_comp_max_hp(), o.hp + 20.0)
		"pull":
			var near := _nearest_enemies(paul.pos, 120.0, 1)
			var center: Vector2 = paul.pos + Vector2(0, -30) if near.is_empty() else near[0].pos
			nets.append({"pos": center, "r": 110.0, "t": 0.0, "evo": true, "look": "", "stun": 0.8, "col": C_GOLD})
			for e in foes:
				if e.pos.distance_to(center) < 110.0:
					if not e.get("boss", false):
						e.knock += (center - e.pos) * 3.0
						e.stun = maxf(e.stun, 0.8)
					_hurt(e, 12.0 + level, Vector2.INF)
		"raise":
			for o in comps:
				if o.level == 0:
					continue
				if o.down > 0.0:
					o.down = 0.0
					o.hp = _comp_max_hp() * 0.6
				o.hp = minf(_comp_max_hp(), o.hp + 30.0)
				heals.append({"who": o, "t": 0.0})
			paul.hp = minf(float(D.paul.hp), paul.hp + 30.0)
		"gentile":
			var n := 0
			for e in foes:
				if n < 12 and not e.get("boss", false) and not e.get("elite", false) and e.pos.distance_to(paul.pos) < 90.0:
					e.msg = 0
					_convert(e, 6.0)
					n += 1
			_ring_pop(paul.pos + Vector2(0, -8), C_GOLD, 90.0)
		"garments":
			for o in comps:
				if o.level > 0 and o.down <= 0.0:
					o.garment = mini(int(o.get("garment", 0)) + 2, 3)
		"pillars":
			foes.shuffle()
			for i in mini(7, foes.size()):
				fires.append({"pos": foes[i].pos, "t": 0.45, "max": 0.45, "r": 22.0, "dmg": 30.0 + level * 2.0, "owner": c, "evo": true, "look": "glory"})
		"walls":
			blasts.append({"pos": paul.pos + Vector2(0, -6), "t": 0.0, "r": 150.0, "col": C_GOLD, "evo": true})
			shake = 0.4
			for e in foes:
				if e.pos.distance_to(paul.pos) < 150.0:
					_hurt(e, 15.0 + level, paul.pos)
					if not e.get("boss", false):
						e.knock += (e.pos - paul.pos).normalized() * 320.0
		"feast":
			feast_t = 5.0
			for e in foes:
				_hurt(e, 8.0 + level, Vector2.INF)
		"deacons":
			var bs := {"damage": 14.0 + level * 1.5, "length": 150.0, "width": 5.0, "burst": false, "lies_mult": 1.0}
			for i in 7:
				_fire_beam(paul.pos + Vector2(0, -8), Vector2.RIGHT.rotated(i * TAU / 7.0 + t), bs, "", c)
		"rain":
			for o in comps:
				if o.level > 0 and o.down <= 0.0:
					o.hp = minf(_comp_max_hp(), o.hp + 25.0)
			paul.hp = minf(float(D.paul.hp), paul.hp + 25.0)
			for e in foes:
				e.slow_t = 4.0
			rains.append({"t": 0.0})
		"giant":
			var big = null
			for e in foes:
				if big == null or float(e.hp) > float(big.hp):
					big = e
			if big != null:
				blasts.append({"pos": big.pos, "t": 0.0, "r": 30.0, "col": C_FLAME, "evo": true})
				_hurt(big, 60.0 + level * 6.0, paul.pos)
				shake = 0.25
		"crit":
			crit_t = 6.0
		"rebirth":
			if fever <= 0.0:
				meter = minf(1.0, meter + 0.4)


# ---------- 新的攻擊方式：迴力、桑樹、繞城、香氣、瓶子、獅子、大魚、洪水、鼓聲 ----------
func _ensure_lions(c: Dictionary, n: int) -> void:
	if not c.has("lions"):
		c.lions = []
	while c.lions.size() < n:
		c.lions.append({"pos": c.pos + Vector2(10, 4), "jump": 0.0, "from": c.pos, "to": c.pos, "ph": randf() * TAU})


func _cone_hit(c: Dictionary, s: Dictionary, dir: Vector2) -> void:
	if c.level == 0:
		return
	var r: float = float(s.range) * _area()
	var half := deg_to_rad(float(s.angle))
	var from: Vector2 = c.pos + Vector2(0, -6)
	cones.append({"pos": from, "dir": dir, "r": r, "half": half, "t": 0.0, "col": c.col, "evo": evolved.has(c.key)})
	for e in enemies.duplicate():
		var rel: Vector2 = e.pos - from
		if e.dead or rel.length() > r + (8.0 if e.get("boss", false) else 0.0) or absf(dir.angle_to(rel)) > half:
			continue
		_hurt(e, float(s.damage), Vector2.INF, c)
		if not e.get("boss", false):
			e.knock += rel.normalized() * float(s.knock)


## 以斯帖：主角血量很低時，「此時此刻」爆發一次保護
func _esther_save() -> void:
	var es := _member("esther")
	if es.is_empty() or es.get("skill", "") == "":
		return
	var s: Dictionary = es.st
	if paul.hp > float(D.paul.hp) * 0.3 or t < float(es.get("save_ready", 0.0)):
		return
	es.save_ready = t + float(s.save_cd)
	paul.hp = minf(float(D.paul.hp), paul.hp + float(D.paul.hp) * float(s.save_heal))
	paul.inv = 2.0
	var r: float = float(s.save_r)
	blasts.append({"pos": paul.pos + Vector2(0, -6), "t": 0.0, "r": r, "col": es.col, "evo": true})
	holies.append({"pos": paul.pos, "t": 0.0, "r": r})
	ui.show_banner("此時此刻！（斯 4:14）", 1.6)
	Sfx.play("holy", 0.0)
	shake = 0.3
	for e in enemies.duplicate():
		if not e.dead and e.pos.distance_to(paul.pos) < r and not e.get("boss", false):
			e.knock += (e.pos - paul.pos).normalized() * 260.0
			e.stun = maxf(e.stun, 2.0)


## 被基甸的火把嚇到：亂了陣腳，去撞別的敵人
func _update_confused(e: Dictionary, dt: float) -> void:
	e.confused -= dt
	var best = null
	var bd := 120.0 * 120.0
	for o in enemies:
		if o.dead or o == e or float(o.get("ally", 0.0)) > 0.0 or float(o.get("confused", 0.0)) > 0.0:
			continue
		var d2: float = o.pos.distance_squared_to(e.pos)
		if d2 < bd:
			bd = d2
			best = o
	if best == null:
		e.pos += Vector2(cos(t * 3.0 + e.ph), sin(t * 2.0 + e.ph)) * float(e.d.speed) * dt
		return
	var to: Vector2 = best.pos - e.pos
	if to.length() > 4.0:
		e.pos += to.normalized() * float(e.d.speed) * 1.2 * dt
	if e.cd <= 0.0 and sqrt(bd) < float(e.r) + 6.0:
		e.cd = 0.6
		_hurt(best, maxf(4.0, float(e.d.damage) * 1.5), e.pos)


func _update_engines(dt: float) -> void:
	# 迴力皮袋
	for b in boomers:
		b.life -= dt
		if not b.back:
			b.pos += b.dir * b.spd * dt
			b.dist += b.spd * dt
			if b.dist >= b.range:
				b.back = true
				b.hit = {}
		else:
			var to: Vector2 = b.owner.pos + Vector2(0, -8) - b.pos
			if to.length() < 6.0:
				b.life = 0.0
			b.pos += to.normalized() * b.spd * 1.25 * dt
		for e in enemies:
			if not e.dead and not b.hit.has(e.node) and e.pos.distance_to(b.pos + Vector2(0, 4)) < float(e.r) + 4.0:
				b.hit[e.node] = true
				_impact(b.pos, b.owner, b.dmg, b.get("look", ""), (e.pos - b.pos).normalized())
				_hurt(e, b.dmg, b.pos, b.owner)
	boomers = boomers.filter(func(b): return b.life > 0.0)
	# 桑樹
	for tr in trees:
		tr.life -= dt
		tr.cd -= dt
		var c: Dictionary = tr.owner
		if tr.cd <= 0.0 and c.level > 0:
			var s: Dictionary = c.st
			tr.cd = float(s.fire_every)
			var tl := _nearest_enemies(tr.pos, float(s.range), int(s.count))
			for i in tl.size():
				bolts.append({"pos": tr.pos + Vector2(0, -14), "target": tl[i], "life": 1.5, "pierce": 0, "split": 0, "child": false,
					"dmg": float(s.damage), "size": 1, "hit": {}, "spd": float(s.speed), "emult": 1.0, "look": "fig", "owner": c, "evo": evolved.has(c.key)})
	trees = trees.filter(func(tr): return tr.life > 0.0)
	# 繞城的祭司
	for c in comps:
		if c.get("engine", "") != "orbit" or not _active(c):
			continue
		var s: Dictionary = c.st
		c.orbit_ang = float(c.get("orbit_ang", 0.0)) + float(s.spin) * dt
		if not c.has("orbit_hit"):
			c.orbit_hit = {}
		var pts := _orbit_points(c)
		for e in enemies:
			if e.dead or t < float(c.orbit_hit.get(e.node, 0.0)):
				continue
			for pt in pts:
				if pt.distance_squared_to(e.pos) < 70.0:
					c.orbit_hit[e.node] = t + float(s.hit_every)
					_hurt(e, float(s.damage), pt, c)
					break
		if c.orbit_hit.size() > 300:
			c.orbit_hit = {}
	# 香氣
	for z in zones:
		z.life -= dt
		z.tick -= dt
		if z.tick <= 0.0 and z.owner.level > 0:
			var s: Dictionary = z.owner.st
			z.tick = float(s.tick)
			for e in enemies.duplicate():
				if not e.dead and e.pos.distance_to(z.pos) < z.r:
					_hurt(e, float(s.damage), Vector2.INF, z.owner)
					if float(s.get("stun", 0.0)) > 0.0 and not e.get("boss", false):
						e.stun = maxf(e.stun, float(s.stun))
			for o in comps:
				if o.level > 0 and o.down <= 0.0 and o.pos.distance_to(z.pos) < z.r:
					o.hp = minf(_comp_max_hp(), o.hp + float(s.heal_comp))
			if paul.pos.distance_to(z.pos) < z.r:
				_heal_paul(float(s.heal_comp) * 0.5)
	zones = zones.filter(func(z): return z.life > 0.0)
	# 瓶子：敵人碰到就打破
	for j in jars:
		j.life -= dt
		if j.life <= 0.0:
			continue
		for e in enemies:
			if not e.dead and float(e.get("ally", 0.0)) <= 0.0 and e.pos.distance_to(j.pos) < 8.0:
				j.life = 0.0
				var c: Dictionary = j.owner
				var s: Dictionary = c.st
				var rr: float = float(s.radius) * _area()
				blasts.append({"pos": j.pos, "t": 0.0, "r": rr, "col": C_FLAME, "evo": evolved.has(c.key)})
				_burst(j.pos, 8, C_FLAME, C_GOLD)
				Sfx.play("shatter")
				for o in enemies.duplicate():
					if not o.dead and o.pos.distance_to(j.pos) < rr:
						_hurt(o, float(s.damage), j.pos, c)
						if not o.get("boss", false):
							o.confused = float(s.confuse)
				break
	jars = jars.filter(func(j): return j.life > 0.0)
	# 獅子
	for c in comps:
		if c.get("engine", "") != "pet" or c.level == 0:
			continue
		_ensure_lions(c, int(c.st.lions))
		for i in c.lions.size():
			var ln: Dictionary = c.lions[i]
			if ln.jump > 0.0:
				ln.jump -= dt
				var k: float = 1.0 - clampf(ln.jump / 0.25, 0.0, 1.0)
				ln.pos = ln.from.lerp(ln.to, k)
				if ln.jump <= 0.0:
					var s: Dictionary = c.st
					var rr: float = float(s.radius) * _area()
					blasts.append({"pos": ln.pos, "t": 0.0, "r": rr, "col": c.col, "evo": evolved.has(c.key)})
					for e in enemies.duplicate():
						if not e.dead and e.pos.distance_to(ln.pos) < rr + (8.0 if e.get("boss", false) else 0.0):
							_hurt(e, float(s.damage), ln.pos, c)
							if not e.get("boss", false):
								e.stun = maxf(e.stun, float(s.stun))
			else:
				var home: Vector2 = c.pos + Vector2(12 + i * 8, 6)
				var to: Vector2 = home - ln.pos
				if to.length() > 3.0:
					ln.pos += to.normalized() * minf(to.length() * 4.0, 140.0) * dt
				if to.length() > 160.0:
					ln.pos = home
	# 大魚：時間到吐出來
	for f in fishes:
		f.t += dt
		if f.t >= f.hold and not f.done:
			f.done = true
			var tl := _nearest_enemies(f.pos, 140.0, 1)
			var at: Vector2 = tl[0].pos if not tl.is_empty() else f.pos + f.dir * 60.0
			fires.append({"pos": at, "t": 0.35, "max": 0.35, "r": f.r, "dmg": f.dmg * (1.0 + 0.6 * f.eaten), "owner": f.owner, "evo": evolved.has(f.owner.key), "look": "spit"})
			if f.get("repent", false):
				# 尼尼微悔改：落點附近的敵人被說服（菁英、Boss 除外）
				var n_conv: int = int(f.eaten) + 2
				for e in _nearest_enemies(at, f.r * 1.6, 12):
					if n_conv <= 0:
						break
					if not e.get("boss", false) and not e.get("elite", false):
						_convert(e, 6.0)
						n_conv -= 1
						_fxc("悔改")
	fishes = fishes.filter(func(f): return f.t < f.hold + 0.4)
	# 洪水
	for w in floods:
		if w.delay > 0.0:
			w.delay -= dt
			continue
		w.x += w.dir * w.spd * dt
		for e in enemies:
			if e.dead or w.hit.has(e.node):
				continue
			if absf(e.pos.y - w.y) < w.h / 2.0 and absf(e.pos.x - w.x) < 8.0:
				w.hit[e.node] = true
				_hurt(e, w.dmg, Vector2.INF, w.owner)
				if not e.get("boss", false):
					e.knock += Vector2(w.dir * w.push, 0)
					if w.evo:
						e.stun = maxf(e.stun, 0.6)
	floods = floods.filter(func(w): return (w.x < w.end) if w.dir > 0.0 else (w.x > w.end))
	for cn in cones:
		cn.t += dt
	cones = cones.filter(func(cn): return cn.t < 0.22)
	for e in enemies:
		if e.has("crowned_t"):
			e.crowned_t = maxf(0.0, float(e.crowned_t) - dt)


func _orbit_points(c: Dictionary) -> Array:
	var s: Dictionary = c.st
	var out := []
	var n := int(s.count)
	var r: float = float(s.radius) * _area()
	for i in n:
		var a: float = float(c.get("orbit_ang", 0.0)) + i * TAU / n
		out.append(paul.pos + Vector2(cos(a), sin(a) * 0.8) * r + Vector2(0, -4))
	return out


func _draw_engines(n: Node2D) -> void:
	# 香氣（地上一片粉金色的點，實心）
	for z in zones:
		var k: float = clampf(z.life / z.max, 0.0, 1.0)
		var zc: Vector2 = z.pos.round()
		_dot_ring(n, zc, z.r, 0.75, z.owner.col, 4.0, t * 0.5, 2)
		_dot_ring(n, zc, z.r * 0.6, 0.75, C_CREAM, 5.0, -t * 0.7, 1)
		for i in 4:
			var py: float = fmod(t * 14.0 + i * 7.0, 18.0)
			var px: float = zc.x + sin(i * 2.1 + t) * z.r * 0.5
			n.draw_rect(Rect2(roundf(px), zc.y - py, 2, 2), z.owner.col if k > 0.3 else C_CREAM)
	# 瓶子
	for j in jars:
		var jx: float = roundf(j.pos.x)
		var jy: float = roundf(j.pos.y)
		n.draw_rect(Rect2(jx - 3, jy - 6, 7, 7), Color("2a1408"))
		n.draw_rect(Rect2(jx - 2, jy - 5, 5, 5), Color("b8703a"))
		n.draw_rect(Rect2(jx - 1, jy - 7, 3, 2), Color("2a1408"))
		var fl := int(t * 8.0 + jx) % 2
		n.draw_rect(Rect2(jx, jy - 9 - fl, 1, 2), C_FLAME)
	# 桑樹
	for tr in trees:
		var tx: float = roundf(tr.pos.x)
		var ty: float = roundf(tr.pos.y)
		n.draw_rect(Rect2(tx - 2, ty - 12, 4, 12), Color("2a1a10"))
		n.draw_rect(Rect2(tx - 1, ty - 12, 2, 12), Color("8a5a30"))
		n.draw_circle(Vector2(tx, ty - 18), 10.0, Color("1a3010"))
		n.draw_circle(Vector2(tx, ty - 18), 9.0, Color("4a7a2a"))
		n.draw_circle(Vector2(tx - 3, ty - 21), 4.0, Color("6a9a3a"))
		for i in 4:
			n.draw_rect(Rect2(tx - 6 + i * 4, ty - 17 + (i % 2) * 4, 2, 2), Color("8a4a8a"))
		if tr.life < 1.5 and int(t * 8.0) % 2 == 0:
			n.draw_rect(Rect2(tx - 1, ty - 30, 2, 2), C_CREAM)
	# 繞城的祭司（拿著號角的小人）
	for c in comps:
		if c.get("engine", "") != "orbit" or not _active(c):
			continue
		for pt in _orbit_points(c):
			var ox: float = roundf(pt.x)
			var oy: float = roundf(pt.y)
			# 祭司：白袍、頭巾，手上的羊角往外吹
			n.draw_rect(Rect2(ox - 3, oy - 9, 7, 11), Color("1a1408"))
			n.draw_rect(Rect2(ox - 2, oy - 8, 5, 2), Color("f4f0e8"))
			n.draw_rect(Rect2(ox - 1, oy - 6, 3, 2), Color("e0a878"))
			n.draw_rect(Rect2(ox - 2, oy - 4, 5, 5), Color("f4f0e8"))
			n.draw_rect(Rect2(ox, oy - 4, 1, 5), Color("3a7ad0"))
			n.draw_rect(Rect2(ox + 3, oy - 5, 2, 1), C_GOLD)
			n.draw_rect(Rect2(ox + 5, oy - 7, 2, 4), C_GOLD)
			n.draw_rect(Rect2(ox + 6, oy - 6, 1, 2), C_CREAM)
	# 迴力皮袋（轉動的十字）
	for b in boomers:
		var bp: Vector2 = b.pos.round()
		var a: float = t * 18.0
		var u := Vector2(cos(a), sin(a)) * 4.0
		var col: Color = C_GOLD if b.evo else b.owner.col
		# 皮袋：圓鼓鼓的袋子，袋口綁繩，轉著飛
		var spin := int(t * 12.0) % 4
		n.draw_rect(Rect2(bp.x - 4, bp.y - 3, 9, 7), Color("1a1420"))
		n.draw_rect(Rect2(bp.x - 3, bp.y - 2, 7, 5), col)
		n.draw_rect(Rect2(bp.x - 3, bp.y - 2, 3, 2), col.lightened(0.35))
		var tie: Vector2 = [Vector2(0, -4), Vector2(4, 0), Vector2(0, 3), Vector2(-5, 0)][spin]
		n.draw_rect(Rect2(bp + tie, Vector2(2, 2)), Color("8a6438"))
	# 獅子
	for c in comps:
		if c.get("engine", "") != "pet" or c.level == 0 or not c.has("lions"):
			continue
		for ln in c.lions:
			var lx: float = roundf(ln.pos.x)
			var ly: float = roundf(ln.pos.y) - (4.0 if ln.jump > 0.0 else 0.0)
			var face: float = 1.0 if ln.to.x >= ln.from.x else -1.0
			n.draw_rect(Rect2(lx - 7, ly - 7, 15, 8), Color("2a1a08"))
			n.draw_rect(Rect2(lx - 6, ly - 6, 12, 5), Color("d8a040"))
			# 頭：一圈深色鬃毛包著淺色的臉，嘴巴是閉著的（封住獅子的口）
			var hx: float = lx + face * 5
			n.draw_rect(Rect2(hx - 4, ly - 11, 9, 9), Color("2a1a08"))
			n.draw_rect(Rect2(hx - 3, ly - 10, 7, 7), Color("8a4a14"))
			n.draw_rect(Rect2(hx - 2 + face, ly - 9, 4, 5), Color("e8c060"))
			n.draw_rect(Rect2(hx + face * 2, ly - 8, 1, 1), Color("1a1408"))
			n.draw_rect(Rect2(hx - 1 + face * 2, ly - 6, 2, 1), Color("8a4a14"))
			var lg := int(t * 8.0) % 2 if ln.jump <= 0.0 else 0
			n.draw_rect(Rect2(lx - 5, ly - 1, 2, 2 + lg), Color("a86a20"))
			n.draw_rect(Rect2(lx + 3, ly - 1, 2, 3 - lg), Color("a86a20"))
			n.draw_rect(Rect2(lx - face * 7, ly - 6, 2, 1), Color("a86a20"))
	# 大魚（從地面冒出來，張口再闔上）
	for f in fishes:
		if f.t > f.hold:
			continue
		var k: float = clampf(f.t / 0.3, 0.0, 1.0) * clampf((f.hold - f.t) / 0.3, 0.0, 1.0)
		var c0: Vector2 = f.pos.round()
		var side: Vector2 = f.dir.orthogonal()
		var hl: float = f.len * 0.5 * k
		var body := PackedVector2Array([c0 - f.dir * hl, c0 - side * 7.0 * k, c0 + f.dir * hl, c0 + side * 7.0 * k])
		n.draw_colored_polygon(body, Color("1a2a3a"))
		var inner := PackedVector2Array([c0 - f.dir * (hl - 2.0), c0 - side * 5.0 * k, c0 + f.dir * (hl - 2.0), c0 + side * 5.0 * k])
		n.draw_colored_polygon(inner, Color("5a8ab0"))
		n.draw_line(c0 - f.dir * hl * 0.6, c0 + f.dir * hl * 0.6, Color("a8c8e0"), 1.0)
		var tail: Vector2 = c0 - f.dir * hl
		n.draw_colored_polygon(PackedVector2Array([tail, tail - f.dir * 6.0 + side * 6.0 * k, tail - f.dir * 6.0 - side * 6.0 * k]), Color("3a6a90"))
		n.draw_rect(Rect2((c0 + f.dir * hl * 0.6 + side * 2.0).round(), Vector2(2, 2)), Color.WHITE)
	# 洪水（一道直立的水牆，白色浪頭）
	for w in floods:
		if w.delay > 0.0:
			continue
		var x: float = roundf(w.x)
		var y0: float = roundf(w.y - w.h / 2.0)
		n.draw_rect(Rect2(x - w.dir * 10.0 - 6.0, y0, 12, w.h), Color("1a3a6a"))
		n.draw_rect(Rect2(x - w.dir * 10.0 - 5.0, y0 + 1, 10, w.h - 2), Color("3a7ad0"))
		n.draw_rect(Rect2(x - 2, y0, 4, w.h), Color("8fd0ff"))
		for i in range(0, int(w.h), 6):
			var fx: float = x + (2.0 if (i / 6 + int(t * 10.0)) % 2 == 0 else -1.0) * w.dir
			n.draw_rect(Rect2(fx, y0 + i, 2, 3), Color.WHITE)
	# 鼓聲（實心的扇形）
	for cn in cones:
		var k: float = cn.t / 0.22
		var rr: float = cn.r * (0.5 + 0.5 * k)
		var pts := PackedVector2Array([cn.pos])
		for i in 9:
			var a: float = cn.dir.angle() - cn.half + cn.half * 2.0 * i / 8.0
			pts.append(cn.pos + Vector2(cos(a), sin(a)) * rr)
		var outline := pts.duplicate()
		outline.append(cn.pos)
		var col: Color = C_GOLD if cn.evo else cn.col
		for i in outline.size() - 1:
			_pline(n, outline[i], outline[i + 1], col.darkened(0.6), 3)
		for i in outline.size() - 1:
			_pline(n, outline[i], outline[i + 1], col, 1)
		for i in range(1, 9, 2):
			_fx(n, "note", 1, 0, pts[i])
	# 以斯帖的標記：被標記的敵人頭上一頂金冠
	for e in enemies:
		if float(e.get("crowned_t", 0.0)) > 0.0 and not e.dead:
			var cx: float = roundf(e.pos.x)
			var cy: float = roundf(e.pos.y) - 24.0
			n.draw_rect(Rect2(cx - 4, cy, 9, 4), Color("3a1a30"))
			n.draw_rect(Rect2(cx - 3, cy + 1, 7, 2), C_GOLD)
			for i in 3:
				n.draw_rect(Rect2(cx - 3 + i * 3, cy - 2, 1, 2), C_GOLD)
	# 被嘲諷（紅色驚嘆號）、驚慌（藍色波浪）、破甲（灰色裂痕）
	for e in enemies:
		if e.dead:
			continue
		var ex: float = roundf(e.pos.x)
		var ey: float = roundf(e.pos.y) - 22.0
		if float(e.get("taunt_t", 0.0)) > 0.0:
			n.draw_rect(Rect2(ex - 1, ey - 1, 3, 7), Color("2a0808"))
			n.draw_rect(Rect2(ex, ey, 1, 3), C_RED)
			n.draw_rect(Rect2(ex, ey + 4, 1, 1), C_RED)
		elif float(e.get("fear_t", 0.0)) > 0.0:
			for j in 4:
				n.draw_rect(Rect2(ex - 3 + j * 2, ey + (j % 2), 2, 1), Color("9fd8ff"))
		if int(e.get("sunder", 0)) > 0 and float(e.get("sunder_t", 0.0)) > 0.0:
			for j in int(e.sunder):
				n.draw_rect(Rect2(ex - 4 + j * 3, ey + 6, 2, 2), Color("c8c8d8"))
	# 亂了陣腳的敵人：頭上的問號
	for e in enemies:
		if float(e.get("confused", 0.0)) > 0.0 and not e.dead:
			var qx: float = roundf(e.pos.x)
			var qy: float = roundf(e.pos.y) - 22.0
			n.draw_rect(Rect2(qx - 2, qy - 1, 5, 8), Color("2a1408"))
			n.draw_rect(Rect2(qx - 1, qy, 3, 1), C_FLAME)
			n.draw_rect(Rect2(qx + 1, qy + 1, 1, 2), C_FLAME)
			n.draw_rect(Rect2(qx, qy + 3, 1, 1), C_FLAME)
			n.draw_rect(Rect2(qx, qy + 5, 1, 1), C_FLAME)


# ---------- 聖物、膏抹、屬性 ----------
## 聖物與膏抹改的招式數值（每次重算等級時套用）
func _mod_stats(c: Dictionary) -> void:
	var st: Dictionary = c.st
	var eng: String = c.get("engine", "")
	var an: Array = c.get("anoints", [])
	if an.has("multi") and st.has("count"):
		st.count = float(st.count) + 2.0
		st.damage = float(st.get("damage", 1.0)) * 0.7
	if an.has("pierce") and st.has("pierce"):
		st.pierce = float(st.pierce) + 2.0
	if an.has("expand"):
		for k in ["radius", "max_radius", "length", "width", "range", "height", "reach", "spit_r"]:
			if st.has(k):
				st[k] = float(st[k]) * 1.4
		st.cooldown = float(st.get("cooldown", 1.0)) * 1.25
	if an.has("swift"):
		st.cooldown = float(st.get("cooldown", 1.0)) * 0.75
		if st.has("damage"):
			st.damage = float(st.damage) * 0.85
	if relics.has("staff"):
		if eng == "beam" and st.has("beams"):
			st.beams = float(st.beams) + 1.0
			st.damage = float(st.damage) * 0.8
		elif eng == "shot" and st.has("count"):
			st.count = float(st.count) + 1.0
			st.damage = float(st.damage) * 0.8
	if relics.has("sling") and eng == "bolt":
		st.damage = float(st.damage) * float(st.get("count", 1.0))
		st.count = 1.0
		st.pierce = float(st.get("pierce", 0.0)) + 2.0


func _refresh_all_stats() -> void:
	for o in comps + [pa]:
		if o.level > 0 and o.get("skill", "") != "":
			_set_level(o, o.level)


## 寶箱打開後：從三件聖物裡選一件
func _offer_relic() -> void:
	var pool: Array = D.relics.filter(func(r): return not relics.has(r.id))
	if pool.is_empty() or relics.size() >= int(D.relic_rules.max):
		return
	pool.shuffle()
	choosing = true
	joy.on = false
	ui.joy.on = false
	pending_cards = []
	for r in pool.slice(0, 3):
		pending_cards.append({"kind": "relic", "key": r.id, "title": r.name, "tag": r.ref, "desc": r.desc + "\n" + r.story})
	Sfx.play("chest", 0.0)
	_tip("relic")
	ui.show_cards(pending_cards, Time.get_ticks_msec() / 1000.0, _card_delay(), 0, "聖物：選一件（一局最多 %d 件）" % int(D.relic_rules.max), "每一件都會改變這一局的玩法")


func _take_relic(id: String) -> void:
	relics[id] = true
	run_relics += 1
	if smoke:
		print("RELIC ", id)
	if id == "rod":
		for k in fruits:
			fruits[k] = mini(int(fruits[k]) + 1, 5)
	_refresh_all_stats()
	for r in D.relics:
		if r.id == id:
			ui.show_banner("聖物：%s（%s）" % [r.name, r.ref], 2.0)
	_ring_pop(paul.pos + Vector2(0, -8), C_GOLD, 50.0)


## 升級時偶爾出現的膏抹卡：選一位有空格、招式合用的同伴
func _anoint_card() -> Dictionary:
	if randf() > float(D.anoint_rules.chance):
		return {}
	var who := []
	for o in comps + [pa]:
		if o.level > 0 and o.get("skill", "") != "" and o.get("anoints", []).size() < int(D.anoint_rules.slots) and o.follows == "":
			who.append(o)
	who.shuffle()
	for o in who:
		var eng: String = o.get("engine", "")
		var opts: Array = D.anoints.filter(func(a): return not o.get("anoints", []).has(a.id) and (a.engines.has("all") or a.engines.has(eng)))
		if opts.is_empty():
			continue
		var a: Dictionary = opts.pick_random()
		return {"kind": "anoint", "key": o.key, "aid": a.id, "title": "膏抹「%s」→ %s" % [a.name, o.name], "tag": o.tag, "desc": a.desc + "\n（每位同伴最多 %d 種）" % int(D.anoint_rules.slots)}
	return {}


func _who(k: String) -> Dictionary:
	if not pa.is_empty() and pa.key == k:
		return pa
	return by_key.get(k, {})


## 屬性：打中時附上燃燒、浸濕、感電（回傳傷害倍率）
func _apply_element(e: Dictionary, dmg: float, src) -> float:
	var mult := 1.0
	if float(e.get("shock_t", 0.0)) > 0.0:
		mult *= 1.25
	if not (src is Dictionary):
		return mult
	var el: String = elem_of.get(src.get("key", ""), "")
	match el:
		"fire":
			e.burn_t = 3.0
			e.burn_dps = maxf(float(e.get("burn_dps", 0.0)) * 0.5, dmg * 0.35)
		"water":
			e.wet_t = 3.0
		"shock":
			if float(e.get("wet_t", 0.0)) > 0.0:
				mult *= 2.0   # 浸濕的敵人被雷打到：加倍
				e.wet_t = 0.0
				if sparks.size() < 120:
					sparks.append({"pos": e.pos + Vector2(0, -8), "t": 0.0, "col": Color("ffe14d")})
			e.shock_t = 3.0
	return mult


## 膏抹：連鎖、餘燼、觸發
## 這位成員打中時會觸發的效果：主角輔助＋進化＋Lv3 分支
func _fx_of(src) -> Array:
	if not src is Dictionary:
		return []
	return src.get("anoints", []) + src.get("onhit", []) + src.get("branch_fx", [])


func _anoint_on_hit(e: Dictionary, dmg: float, src: Dictionary) -> void:
	var an: Array = _fx_of(src)
	if an.is_empty():
		return
	var base: float = dmg / maxf(0.01, _dmg_mult())   # 之後的 _hurt 會再乘一次倍率，這裡先除掉
	if an.has("pillar") and not chaining and t >= float(src.get("pillar_cd", 0.0)) and randf() < 0.25:
		# 光柱：打中的地方，天上降下一道光柱
		src.pillar_cd = t + 0.2
		_fxc("光柱")
		fires.append({"pos": e.pos, "t": 0.3, "max": 0.3, "r": 18.0 * _area(), "dmg": base * 1.2, "owner": src, "evo": true, "look": "glory"})
	if an.has("zap") and not chaining and t >= float(src.get("zap_cd", 0.0)) and randf() < 0.3:
		# 雷擊：打中後，閃電跳向附近 3 隻
		src.zap_cd = t + 0.2
		_fxc("雷擊")
		chaining = true
		var prev: Vector2 = e.pos + Vector2(0, -4)
		var seen := {e.node: true}
		for o in _nearest_enemies(e.pos, 70.0, 3, seen):
			zaps.append({"pts": [prev, o.pos + Vector2(0, -4)], "t": 0.0, "evo": true, "col": C_GOLD})
			_hurt(o, base * 0.6, Vector2.INF, src)
			prev = o.pos + Vector2(0, -4)
		chaining = false
	if an.has("chain") and not chaining and t >= float(src.get("chain_cd", 0.0)):
		src.chain_cd = t + 0.12
		var nx := _nearest_enemies(e.pos, 55.0, 1, {e.node: true})
		if not nx.is_empty():
			chaining = true
			zaps.append({"pts": [e.pos + Vector2(0, -4), nx[0].pos + Vector2(0, -4)], "t": 0.0, "evo": false, "col": src.get("col", C_GOLD)})
			_hurt(nx[0], dmg * 0.5 / maxf(0.01, _dmg_mult()), Vector2.INF, src)
			chaining = false
	if an.has("still") and not e.get("boss", false) and randf() < 0.2:
		e.stun = maxf(e.stun, 1.0)   # 平靜：定住
		_fxc("定住")
	if an.has("slow"):
		e.slow_t = maxf(float(e.get("slow_t", 0.0)), 1.5)   # 沉重：變慢
		_fxc("變慢")
	if an.has("mark"):
		e.exposed_t = maxf(float(e.get("exposed_t", 0.0)), 3.0)   # 印記：之後受到的傷害更多
		_fxc("印記")
		e.expose = maxf(float(e.get("expose", 0.0)), 0.2)
	if an.has("leech") and t >= float(src.get("leech_a_cd", 0.0)):
		src.leech_a_cd = t + 0.3
		_fxc("吸血")
		_heal_paul(1.0)   # 恩典夠用
	if an.has("harvest") and not e.get("elite", false) and not e.get("boss", false) and e.hp > 0.0 and e.hp <= float(e.get("hp0", 1.0)) * 0.15:
		e.hp = 0.0   # 收割：剩一點點血的直接散去
		_fxc("收割")
		_ring_pop(e.pos + Vector2(0, -6), C_CREAM, 12.0)
	if an.has("split") and not chaining and t >= float(src.get("split_cd", 0.0)):
		# 分光：打中後分出 2 支小光箭
		src.split_cd = t + 0.15
		_fxc("分光")
		for o in _nearest_enemies(e.pos, 80.0, 2, {e.node: true}):
			bolts.append({"pos": e.pos + Vector2(0, -6), "target": o, "life": 0.8, "pierce": 0, "split": 0, "child": true,
				"dmg": maxf(1.0, base * 0.4), "size": 1, "hit": {e.node: true}, "spd": 220.0, "emult": 1.0, "look": "", "owner": src})
	if an.has("blast") and not blasting:
		# 爆裂：打中的地方炸開，波及旁邊的敵人（四成傷害）
		blasting = true
		var br := 20.0 * _area()
		_fxc("爆裂")
		blasts.append({"pos": e.pos + Vector2(0, -4), "t": 0.0, "r": br, "col": src.get("col", C_FLAME), "evo": false})
		for o in _enemies_near(e.pos, br + 12.0):
			if o != e and not o.dead and float(o.get("ally", 0.0)) <= 0.0 and o.pos.distance_to(e.pos) < br + float(o.r):
				_hurt(o, dmg * 0.4 / maxf(0.01, _dmg_mult()), e.pos, src)
		blasting = false
	if an.has("ember") and t >= float(src.get("ember_cd", 0.0)) and spots.size() < 40:
		src.ember_cd = t + 0.6
		spots.append({"kind": "ember", "pos": e.pos, "life": 3.0, "tick": 0.0, "dmg": maxf(2.0, float(src.st.get("damage", 2.0)) * 0.5), "owner": src})


func _update_ailments(dt: float) -> void:
	for e in enemies:
		if e.dead:
			continue
		if e.has("wet_t"):
			e.wet_t = maxf(0.0, float(e.wet_t) - dt)
		if e.has("shock_t"):
			e.shock_t = maxf(0.0, float(e.shock_t) - dt)
		if float(e.get("burn_t", 0.0)) > 0.0:
			e.burn_t -= dt
			e.burn_tick = float(e.get("burn_tick", 0.0)) - dt
			if e.burn_tick <= 0.0:
				e.burn_tick = 0.5
				e.burning_hit = true
				_hurt(e, float(e.burn_dps) * 0.5 / maxf(0.01, _dmg_mult()), Vector2.INF)
				e.burning_hit = false
	# 聖物：彼得的影子、挪亞的鴿子
	if relics.has("shadow"):
		shadow_t -= dt
		if shadow_t <= 0.0:
			shadow_t = 0.5
			for e in enemies.duplicate():
				if not e.dead and e.pos.distance_to(paul.pos) < 18.0:
					_hurt(e, 3.0 + level * 0.3, paul.pos)
	if relics.has("dove") and paul.hp < float(D.paul.hp) * 0.5:
		dove_t -= dt
		if dove_t <= 0.0:
			dove_t = 8.0
			guard = mini(guard + 1, 5)
			paul.hp = minf(_hp_cap(), paul.hp + 5.0)
			_ring_pop(paul.pos + Vector2(0, -10), C_CREAM, 18.0)


## 參孫的頭髮：治療最多回到 80%
func _hp_cap() -> float:
	return float(D.paul.hp) * (0.7 if relics.has("hair") else 1.0)


func _draw_ailments(n: Node2D) -> void:
	var blink := int(t * 8.0) % 2
	for e in enemies:
		if e.dead:
			continue
		var x: float = roundf(e.pos.x)
		var y: float = roundf(e.pos.y)
		if float(e.get("burn_t", 0.0)) > 0.0:
			n.draw_rect(Rect2(x - 4 + blink, y - 14 - blink, 2, 3), C_FLAME)
			n.draw_rect(Rect2(x + 2 - blink, y - 12, 2, 3), C_RED)
			n.draw_rect(Rect2(x - 1, y - 16 + blink, 1, 2), C_GOLD)
		if float(e.get("wet_t", 0.0)) > 0.0:
			n.draw_rect(Rect2(x - 5, y - 4 + blink, 1, 2), Color("8fd0ff"))
			n.draw_rect(Rect2(x + 4, y - 6 + blink * 2, 1, 2), Color("8fd0ff"))
		if float(e.get("shock_t", 0.0)) > 0.0 and blink == 0:
			n.draw_rect(Rect2(x - 6, y - 10, 2, 1), Color("ffe14d"))
			n.draw_rect(Rect2(x - 5, y - 9, 1, 2), Color("ffe14d"))
			n.draw_rect(Rect2(x + 4, y - 12, 2, 1), Color("ffe14d"))
			n.draw_rect(Rect2(x + 5, y - 11, 1, 2), Color("ffe14d"))


# ---------- 劇情對話與帶人信主 ----------
## 第一次進城（in）／第一次建立教會（out）時的對話
func _start_talk(which: String) -> void:
	var key: String = which + "_" + stage.id
	var raw: Array = stage.get("talk_" + which, [])
	var seen: Array = Save.data.get("story_seen", [])
	if raw.is_empty() or (seen.has(key) and not OS.get_cmdline_user_args().has("--talk")):
		return
	if not seen.has(key):
		seen.append(key)
		Save.data.story_seen = seen
		Save.save_profile()
	vision_on = stage.get("vision", []).has(which)
	_show_talk(raw)


func _show_talk(raw: Array) -> void:
	var lines := []
	for L in raw:
		var who: String = L[0]
		var col: Color = C_GOLD
		for dd in D.companions:
			if dd.key == who and dd.has("color"):
				col = Color(dd.color)
		if who == "jesus":
			col = Color("fff4c2")
		lines.append({"name": L[2] if L.size() > 2 else names_all.get(who, who), "text": L[1], "icon": who, "col": col})
	talking = true
	joy.on = false
	ui.joy.on = false
	ui.show_dialogue(lines)


## 出現一位尋找的人：先用這座城自己的人物，用完了才用 fallback
## （黑暗的勢力被驅散、被捆綁的人得了釋放，也會在那裡出現想知道更多的人——徒 26:18）
func _spawn_seeker(at: Vector2, fallback: Dictionary) -> bool:
	var SK: Dictionary = D.seek
	if run_seek_spawned >= int(SK.max_per_run) or seekers.size() >= 2 or boss != null:
		return false
	var pool: Array = stage.get("seekers", []).filter(func(x): return not seek_used.has(x.name))
	var def: Dictionary = pool.pick_random() if not pool.is_empty() else fallback
	seek_used[def.name] = true
	run_seek_spawned += 1
	seekers.append({"pos": at, "hp": float(SK.hp), "prog": 0.0, "def": def, "life": 40.0, "ph": randf() * TAU})
	ui.show_banner("有人在尋找：%s" % def.name, 2.0)
	_tip("seek")
	return true


func _update_seek(dt: float) -> void:
	var SK: Dictionary = D.seek
	if seek_t < 0.0:
		seek_t = float(SK.first)
	if t - t_start >= seek_t and seekers.is_empty() and run_seek_spawned < int(SK.max_per_run) and boss == null:
		seek_t = t - t_start + randf_range(float(SK.every[0]), float(SK.every[1]))
		var a := randf() * TAU
		_spawn_seeker(paul.pos + Vector2(cos(a), sin(a) * 0.7) * randf_range(70.0, 95.0), {"name": "迷路的人", "ref": "路 19:10", "line": "我好像一直在找什麼……"})
	for sk in seekers:
		sk.life -= dt
		sk.pos += Vector2(cos(t * 0.7 + sk.ph), sin(t * 0.5 + sk.ph)) * 3.0 * dt + sk.get("vel", Vector2.ZERO) * dt
		if paul.pos.distance_to(sk.pos) < float(SK.radius):
			sk.prog += dt
		for e in enemies:
			if not e.dead and float(e.get("ally", 0.0)) <= 0.0 and e.pos.distance_to(sk.pos) < float(e.r) + 4.0:
				sk.hp -= float(e.d.damage) * float(e.dmul) * dt * 2.0
		if sk.prog >= float(SK.need) * (0.7 if epistles.has("seek_fast") else 1.0):
			sk.done = true
			run_saved += 1
			if smoke:
				print("SAVED ", sk.def.name)
			followers.append({"pos": sk.pos, "name": sk.def.name, "col": Color.from_hsv(randf(), 0.45, 0.9)})
			if followers.size() > int(SK.follow_max):
				followers.pop_front()
			ui.show_banner("%s 信主了！（%s）" % [sk.def.name, sk.def.ref], 2.2)
			if sk.get("chariot", false):
				_caught_away()
			if tag_fx.size() < 12:
				tag_fx.append({"pos": sk.pos + Vector2(-20, -6), "text": "「%s」" % sk.def.line, "col": C_CREAM, "t": 0.0})
			holies.append({"pos": sk.pos, "t": 0.0, "r": 30.0})
			Sfx.play("holy", 0.0)
		elif sk.hp <= 0.0 or sk.life <= 0.0:
			sk.done = true
			ui.show_banner("%s 走散了……" % sk.def.name, 1.6)
			_ring_pop(sk.pos, Color("8a8a96"), 14.0)
	seekers = seekers.filter(func(sk): return not sk.get("done", false))
	# 跟著走的人：排成一列跟在主角後面
	var lead: Vector2 = paul.pos
	for f in followers:
		var to: Vector2 = lead - f.pos
		if to.length() > 9.0:
			f.pos += to.normalized() * (to.length() - 9.0) * minf(1.0, dt * 6.0)
		lead = f.pos


func _draw_seek(n: Node2D) -> void:
	var SK: Dictionary = D.seek
	for sk in seekers:
		var x: float = roundf(sk.pos.x)
		var y: float = roundf(sk.pos.y)
		# 範圍圈與進度
		_dot_ring(n, Vector2(x, y), float(SK.radius), 0.75, C_CREAM, 4.0, t * 0.6, 1)
		var k: float = clampf(sk.prog / float(SK.need), 0.0, 1.0)
		if k > 0.0:
			n.draw_arc(Vector2(x, y - 6), 12.0, -PI / 2.0, -PI / 2.0 + TAU * k, 24, C_GOLD, 3.0)
		if sk.get("chariot", false):
			# 曠野的車：木頭車身、兩個輪子、前面一匹馬
			var fx: float = signf(sk.vel.x)
			n.draw_rect(Rect2(x - 10, y - 4, 20, 6), Color("5a3a20"))
			n.draw_rect(Rect2(x - 9, y - 3, 18, 3), Color("8a6438"))
			for wx in [-6, 6]:
				n.draw_circle(Vector2(x + wx, y + 3), 3.0, Color("2a1a10"))
				n.draw_rect(Rect2(x + wx - 1, y + 2, 2, 2), Color("c9a46b"))
			n.draw_rect(Rect2(x + fx * 14 - 5, y - 8, 10, 6), Color("6a4a30"))
			n.draw_rect(Rect2(x + fx * 19 - 2, y - 11, 4, 5), Color("6a4a30"))
			n.draw_rect(Rect2(x + fx * 11 - 1, y - 2, 2, 5), Color("4a3020"))
			n.draw_rect(Rect2(x + fx * 16 - 1, y - 2, 2, 5), Color("4a3020"))
		_draw_person(n, x, y - (6 if sk.get("chariot", false) else 0), Color("e8c060") if sk.get("chariot", false) else Color("8a8a96"), Color("a06030") if sk.get("chariot", false) else Color("5a5a66"))
		# 頭上的問號，血少時變紅
		var qc: Color = C_RED if sk.hp < float(SK.hp) * 0.4 else C_CREAM
		var qy: float = y - 22.0 - (int(t * 3.0) % 2)
		n.draw_rect(Rect2(x - 3, qy - 1, 7, 9), Color("1a1420"))
		n.draw_rect(Rect2(x - 1, qy, 3, 1), qc)
		n.draw_rect(Rect2(x + 1, qy + 1, 1, 2), qc)
		n.draw_rect(Rect2(x, qy + 3, 1, 2), qc)
		n.draw_rect(Rect2(x, qy + 6, 1, 1), qc)
		# 血條
		n.draw_rect(Rect2(x - 6, y + 2, 12, 2), Color("0b080d"))
		n.draw_rect(Rect2(x - 6, y + 2, roundf(12.0 * clampf(sk.hp / float(SK.hp), 0.0, 1.0)), 2), C_HEAL)
	for f in followers:
		var fx: float = roundf(f.pos.x)
		var fy: float = roundf(f.pos.y)
		_draw_person(n, fx, fy, Color("e8dcc0"), f.col)
		n.draw_rect(Rect2(fx, fy - 12, 1, 1), C_GOLD)


## 小人：深色外框、袍子、腰帶、臉
func _draw_person(n: Node2D, x: float, y: float, robe: Color, sash: Color) -> void:
	n.draw_rect(Rect2(x - 3, y - 11, 7, 12), Color("1a1420"))
	n.draw_rect(Rect2(x - 2, y - 6, 5, 6), robe)
	n.draw_rect(Rect2(x, y - 6, 1, 6), sash)
	n.draw_rect(Rect2(x - 1, y - 10, 3, 4), Color("e0a878"))
	n.draw_rect(Rect2(x - 2, y - 11, 5, 2), Color("4a3020"))


## 近戰同伴出手前往最近的敵人跨一步（最多 40），打完被隊形拉回來；主角不會被拉走
func _lunge(c: Dictionary, s: Dictionary) -> void:
	if c == pa or float(s.get("melee", 0.0)) <= 0.0:
		return
	var tl := _nearest_enemies(c.pos, 80.0, 1)
	if tl.is_empty():
		return
	var to: Vector2 = tl[0].pos - c.pos
	if to.length() < 14.0:
		return
	c.off = to.normalized() * minf(to.length() - 8.0, 40.0)
	_fxc("跨步")
	c.vel = -c.off * 5.0
	c.pos = c.base + c.off


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
	if float(s.get("heal_team", 0.0)) > 0.0:
		# 雅各：義人祈禱的力量，身邊的同伴也得醫治、醒過來
		for o in comps:
			if o != c and o.level > 0 and o.down <= 0.0 and o.pos.distance_to(center) < r + 20.0:
				_heal_comp(o, float(s.heal_team), 0.0, true)
				_fxc("禱告醫治")
				heals.append({"who": o, "t": 0.0})
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
			for e in _enemies_near(b.pos, 40.0):
				if e.dead or b.hit.has(e.node) or e.pos.distance_to(b.pos + Vector2(0, 4)) > e.r + 3.0:
					continue
				b.hit[e.node] = true
				_impact(b.pos, b.owner, b.dmg, b.get("look", ""), b.vel.normalized())
				_hurt(e, b.dmg, b.pos - b.vel.normalized() * 4.0, b.owner)
				if b.owner is Dictionary and float(b.owner.st.get("pin", 0.0)) > 0.0 and not e.get("boss", false):
					e.stun = maxf(e.stun, float(b.owner.st.pin))   # 哥尼流的標槍把敵人釘住
				if b.get("look", "") == "pilum":
					e.sunder = mini(int(e.get("sunder", 0)) + 1, 3)   # 哥尼流「破甲」：每中一槍，之後受到的傷害 +10%
					e.sunder_t = 5.0
				if b.get("look", "") == "vial" and not b.get("puddled", false) and spots.size() < 40:
					# 馬雅各：藥瓶摔破，留下一灘藥水（敵人變慢、一直受傷）
					b.puddled = true
					spots.append({"kind": "potion", "pos": e.pos, "life": 3.0, "tick": 0.0, "r": 18.0 * _area(), "dmg": maxf(1.0, b.dmg * 0.3), "owner": b.owner})
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
			_impact(b.pos, b.owner, b.dmg * (b.emult if big else 1.0), b.get("look", ""), b.dir)
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
		for e in _enemies_near(center, r.r + 3.0 + r.thick * 2.0 + 8.0):
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
			blasts.append({"pos": f.pos, "t": 0.0, "r": f.r, "col": Color("5a8ab0") if f.get("look", "") == "spit" else (C_GOLD if f.evo else C_FLAME), "evo": f.evo})
			if f.owner is Dictionary and f.owner.has("st") and float(f.owner.st.get("consecrate", 0.0)) > 0.0:
				var hv: float = float(f.owner.st.consecrate)
				_fxc("火中醫治")
				if paul.pos.distance_to(f.pos) < f.r + 24.0:
					_heal_paul(hv)
				for o in comps:
					if o.level > 0 and o.down <= 0.0 and o.pos.distance_to(f.pos) < f.r + 24.0:
						_heal_comp(o, hv)
			_burst(f.pos, 8, C_FLAME, C_GOLD)
			if f.owner is Dictionary and f.owner.get("skill", "") == "fire" and spots.size() < 40:
				# 以利亞「燒盡」：火落下的地方地上燒 3 秒（像奉獻）
				spots.append({"kind": "blaze", "pos": f.pos, "life": 3.0, "tick": 0.0, "r": f.r, "dmg": maxf(1.0, f.dmg * 0.25), "owner": f.owner})
			for e in _enemies_near(f.pos, f.r + 8.0):
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
				_damage_paul(s.dmg * (1.0 - 0.3 * belt), false, "shot")
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
	var taunt_on: bool = _school_on("守護") and comps.any(func(o): return o.tag == "守護" and _active(o))
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
		if e.has("sunder_t"):
			e.sunder_t = maxf(0.0, float(e.sunder_t) - dt)
		e.pos += e.knock * dt
		e.knock *= 0.85
		if float(e.get("ally", 0.0)) > 0.0:
			_update_ally(e, dt)
			continue
		if float(e.get("confused", 0.0)) > 0.0:
			_update_confused(e, dt)
			continue
		if e.has("slow_t"):
			e.slow_t = maxf(0.0, e.slow_t - dt)
		if e.stun > 0.0:
			e.stun -= dt
			continue
		var target: Vector2 = p.pos + Vector2(0, -4)
		if e.type == "fear" or e.get("hunter", false):
			var bd := 1e9
			# 守護：獵手改去追守護同伴
			var taunt: bool = e.get("hunter", false) and taunt_on
			for c in comps:
				if c.level == 0 or c.down > 0.0 or (taunt and c.tag != "守護"):
					continue
				var dd: float = c.pos.distance_to(e.pos)
				if dd < bd:
					bd = dd
					target = c.pos + Vector2(0, -4)
		if float(e.get("taunt_t", 0.0)) > 0.0:
			# 參孫的嘲諷：這幾秒只追他
			e.taunt_t = float(e.taunt_t) - dt
			var tb = e.get("taunt_by")
			if tb is Dictionary and tb.level > 0 and tb.down <= 0.0:
				target = tb.pos + Vector2(0, -4)
		var to: Vector2 = target - e.pos
		var dist: float = to.length()
		var dir: Vector2 = to / maxf(dist, 0.001)
		var go := 1.0
		if float(e.get("fear_t", 0.0)) > 0.0:
			# 希幔的號聲：驚慌，往反方向逃
			e.fear_t = float(e.fear_t) - dt
			go = -1.1
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
			# 先在落點出現紫色預兆，0.7 秒後才真的過去；落地後愣一下、不能馬上撞人
			e.blink_cd -= dt
			if e.has("blink_to"):
				e.blink_wait -= dt
				if e.blink_wait <= 0.0:
					_ring_pop(e.pos, Color("a060ff"), 10.0)
					e.pos = e.blink_to
					e.erase("blink_to")
					_ring_pop(e.pos, Color("a060ff"), 14.0)
					e.stun = 0.5
					e.blink_safe = 0.8
			elif e.blink_cd <= 0.0 and dist > 90.0:
				e.blink_cd = float(d.blink.every)
				var a := randf() * TAU
				e.blink_to = p.pos + Vector2(cos(a), sin(a) * 0.8) * randf_range(d.blink.min, d.blink.max)
				e.blink_wait = 0.7
		if d.has("summon"):
			# 灰馬騎士：一直召來蝗蟲
			e.sum_cd -= dt
			if e.sum_cd <= 0.0 and enemies.size() < int(D.waves.max_enemies):
				e.sum_cd = float(d.summon.every)
				_ring_pop(e.pos, Color("8aaa96"), 16.0)
				for i in int(d.summon.count):
					_spawn_one(d.summon.type, e.pos + Vector2(randf_range(-10, 10), randf_range(-8, 8)))
		if d.has("hop"):
			# 污靈：一跳一跳地靠近，落地時停一下
			e.hop_cd = float(e.get("hop_cd", randf())) - dt
			if float(e.get("hop_t", 0.0)) > 0.0:
				e.hop_t -= dt
				go *= float(d.hop.mult)
			else:
				go = 0.0
				if e.hop_cd <= 0.0:
					e.hop_t = float(d.hop.time)
					e.hop_cd = float(d.hop.every)
		var slow: float = 0.5 if float(e.get("slow_t", 0.0)) > 0.0 else 1.0
		if d.get("swarm", false) or e.get("march", false):
			# 蝗蟲：整群朝出現時主角的方向直直飛過去，不會轉彎
			if not e.has("swarm_dir"):
				e.swarm_dir = dir.rotated(randf_range(-0.15, 0.15))
			if e.get("march", false) and not view.grow(160.0).has_point(e.pos):
				e.erase("march")   # 衝出畫面後恢復正常
			e.pos += e.swarm_dir * d.speed * e.smul * slow * dt
		else:
			var wob: float = sin(t * 2.2 + e.ph) * 0.5
			e.pos += (dir * go + dir.orthogonal() * wob) * d.speed * e.smul * slow * dt

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
		e.blink_safe = maxf(0.0, float(e.get("blink_safe", 0.0)) - dt)
		if p.pos.distance_to(e.pos + Vector2(0, 5)) < e.r and p.inv <= 0.0 and e.blink_safe <= 0.0:
			_damage_paul(d.damage * e.dmul, false, "touch")
			e.knock -= dir * 80.0
			if d.has("drain") and fever <= 0.0:
				# 黑馬騎士：手裡拿著天平，吸走同心合意（啟 6:5）
				meter = maxf(0.0, meter - float(d.drain))
				_ring_pop(paul.pos + Vector2(0, -8), Color("3a3a48"), 20.0)
			if d.dies_on_touch:
				_kill(e, false)
				continue

		# 跑太遠就繞回畫面邊緣，維持密度
		if not view.grow(140.0).has_point(e.pos):
			e.pos = _edge_point(16.0)
			e.erase("swarm_dir")
			e.erase("march")

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


func _damage_paul(n: float, pierce := false, src := "") -> void:
	if god_mode:
		if smoke:
			fx_stat["主角被打:" + src] = float(fx_stat.get("主角被打:" + src, 0.0)) + n
		return
	if fever > 0.0 or won:
		return
	var raw := n
	if epistles.has("burden"):
		n *= 0.85   # 加拉太書：彼此擔當
	var sh: int = armor.get("shield", 0)
	if pierce:
		pass   # 逼迫：護盾擋不住，只能躲開
	elif sh > 0 and shield_cd <= 0.0:
		shield_cd = [12.0, 9.0, 6.0][sh - 1]
		paul.inv = 0.4
		_ring_pop(paul.pos + Vector2(0, -8), C_GOLD, 16.0)
		return
	if guard > 0 and not pierce:
		# 守護連結的護盾
		guard -= 1
		paul.inv = 0.4
		_ring_pop(paul.pos + Vector2(0, -8), Color("9fd8ff"), 16.0)
		if _school_on("守護"):
			_shield_shock(paul.pos)
		return
	if armor.get("breast", 0) > 0:
		n *= 1.0 - float(D.armor.breast.per[armor.breast - 1])
	n *= 1.0 - Save.up_value("aegis")
	if raw - n >= 1.0 and t >= block_txt_t and tag_fx.size() < 12:
		# 護心鏡、書信、局外加成擋掉的傷害：頭上跳出「擋 X」
		block_txt_t = t + 0.6
		tag_fx.append({"pos": paul.pos + Vector2(-4, 6), "text": "擋 %d" % roundi(raw - n), "col": Color("9fd8ff"), "t": 0.0})
	if smoke:
		dmg_log[src] = float(dmg_log.get(src, 0.0)) + n   # 測試用：被什麼打傷
	paul.hp -= n
	paul.hurt_t = 0.18
	if bless_grapes and paul.hp > 0.0 and paul.hp < float(D.paul.hp) * 0.3:
		bless_grapes = false
		_use_item("grapes")
	if _fruit_lv("good") >= 3 and t >= good_cd:
		# 良善：被打的時候放出一圈光，推開並定住身邊的敵人
		good_cd = t + 6.0
		_fxc("照在人前")
		_ring_pop(paul.pos + Vector2(0, -6), Color("9fd8ff"), 56.0)
		for e in enemies:
			if not e.dead and e.pos.distance_to(paul.pos) < 56.0:
				e.knock += (e.pos - paul.pos).normalized() * (30.0 if e.get("boss", false) else 90.0)
				if not e.get("boss", false):
					e.stun = maxf(e.stun, 1.0)
	_esther_save()
	Sfx.play("hurt")
	Sfx.buzz(40)
	paul.inv = 0.6
	shake = 0.12
	if armor.get("breast", 0) >= 3 and paul.hp < float(D.paul.hp) * 0.3 and t >= breast_cd and paul.hp > 0.0:
		# 護心鏡：危急時發光，2 秒內不受傷
		breast_cd = t + 30.0
		paul.inv = 2.0
		_fxc("護心")
		_ring_pop(paul.pos + Vector2(0, -8), C_CREAM, 40.0)
		if tag_fx.size() < 12:
			tag_fx.append({"pos": paul.pos + Vector2(-8, -6), "text": "護心", "col": C_CREAM, "t": 0.0})
	_fire_links("hurt", null, 0)
	if paul.hp <= 0.0:
		paul.hp = 0.0
		_game_over()


func _damage_companion(c: Dictionary, n: float) -> void:
	if c.hurt_cd > 0.0:
		return
	if relics.has("ark") and not paul.moving:
		n *= 0.4   # 約櫃：主角站定時同伴受到的傷害 −60%
	if int(c.get("garment", 0)) > 0:
		# 多加縫的衣服擋下這一次
		c.garment -= 1
		c.hurt_cd = 0.4
		_ring_pop(c.pos + Vector2(0, -8), Color("e8d8b0"), 12.0)
		if by_key.has("dorcas") and by_key.dorcas.level > 0 and float(by_key.dorcas.st.get("reflect", 0.0)) > 0.0:
			# 衣服擋下時，光往外推，傷害身邊的敵人
			_fxc("衣服反擊")
			blasts.append({"pos": c.pos + Vector2(0, -6), "t": 0.0, "r": 24.0, "col": Color("e8d8b0"), "evo": false})
			for e in _enemies_near(c.pos, 30.0):
				if not e.dead and e.pos.distance_to(c.pos) < 24.0:
					_hurt(e, float(by_key.dorcas.st.reflect) + level * 0.3, c.pos, by_key.dorcas)
		return
	if guard > 0 and _sv("守護", "yoke") > 0.0:
		# 同負一軛：主角的護盾替同伴擋下
		guard -= 1
		c.hurt_cd = 0.4
		_ring_pop(c.pos + Vector2(0, -8), Color("9fd8ff"), 14.0)
		_shield_shock(c.pos)
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
	c.hurt_t = 0.18
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


## 關卡機制：米利大的暴風每隔一陣子吹過來，把所有人往同一個方向推
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


## 啟示錄的書信卡：五旬節時七個金燈台繞著主角轉（啟 1:12–13）
func _lamp_points() -> Array:
	var out := []
	for i in 7:
		var a := t * 1.6 + i * TAU / 7.0
		out.append(paul.pos + Vector2(cos(a), sin(a) * 0.75) * 46.0 + Vector2(0, -6))
	return out


func _update_lamps(dt: float) -> void:
	if not epistles.has("lamps") or fever <= 0.0:
		return
	lamp_tick -= dt
	if lamp_tick > 0.0:
		return
	lamp_tick = 0.25
	var pts := _lamp_points()
	for e in enemies.duplicate():
		if e.dead:
			continue
		for lp in pts:
			if e.pos.distance_squared_to(lp) < 150.0:
				_hurt(e, 10.0 + level, lp)
				break


## 難度導演：敵人平均活不到 DR.target 秒（還沒走到隊伍就倒了），壓力就慢慢升高；
## 主角血少時壓力往下降，讓人喘口氣。另外從 DR.persecute_from 秒起，定時有「逼迫」砸在主角腳下，站著不動一定會被打到。
func _update_director(dt: float) -> void:
	var DR: Dictionary = D.director
	var el := t - t_start
	if el > float(DR.from):
		var hp_frac: float = paul.hp / float(D.paul.hp)
		if hp_frac < 0.4:
			pressure = maxf(0.0, pressure - float(DR.relax) * dt)
		elif life_avg < float(DR.target):
			pressure = minf(float(DR.max), pressure + float(DR.rise) * dt * (float(DR.target) - life_avg))
	if el < float(DR.persecute_from) or boss != null or choosing:
		return
	if persec_t < 0.0:
		persec_t = float(DR.persecute_from)
	if el < persec_t:
		return
	persec_t = el + float(DR.persecute_every)
	# 逼迫：一圈正落在主角腳下，旁邊再兩圈（傷害照主角血量的比例算，局外血量再多也躲不掉）
	var dmg: float = float(D.paul.hp) * float(DR.persecute_dmg) * (1.0 + el / float(DR.get("persecute_grow", 300)))
	var warn: float = float(DR.persecute_warn) * (1.5 if calling == "prophet" else 1.0)
	_tip("persecute")
	star_falls.append({"pos": paul.pos, "t": warn, "max": warn, "r": 20.0, "dmg": dmg, "pierce": true})
	for i in 2:
		var a := randf() * TAU
		star_falls.append({"pos": paul.pos + Vector2(cos(a), sin(a) * 0.8) * randf_range(25.0, 45.0), "t": warn, "max": warn, "r": 18.0, "dmg": dmg, "pierce": true})


## 五旬節的火焰、約帕的大布：倒數與落地
func _update_tongues_sheets(dt: float, hz: Dictionary) -> void:
	for tg in tongues:
		tg.t -= dt
	tongues = tongues.filter(func(tg): return tg.t > 0.0)
	for sh in sheets:
		sh.t -= dt
		if sh.t <= 0.0 and not sh.get("done", false):
			sh.done = true
			var n := 0
			for e in enemies:
				if not e.dead and not e.get("boss", false) and not e.get("elite", false) and e.pos.distance_to(sh.pos) < float(hz.radius):
					_convert(e, float(hz.dur))
					n += 1
			holies.append({"pos": sh.pos, "t": 0.0, "r": float(hz.radius)})
			Sfx.play("holy", 0.0)
			if n > 0:
				ui.show_banner("神所潔淨的，你不可當作俗物（徒 10:15）　%d 個被說服了" % n, 1.6)
	sheets = sheets.filter(func(sh): return sh.t > -0.4)


## 撒馬利亞：曠野路上的車（坐在車上的人慢慢經過，陪他夠久就信主）
func _spawn_chariot(hz: Dictionary) -> void:
	chariot_done = true
	var dir := Vector2.RIGHT if randf() < 0.5 else Vector2.LEFT
	var v := _view_rect()
	var at := Vector2(v.position.x - 10.0 if dir.x > 0.0 else v.end.x + 10.0, paul.pos.y + randf_range(-30.0, 30.0))
	seekers.append({"pos": at, "hp": float(D.seek.hp) * 2.0, "prog": 0.0, "def": hz.seeker, "life": float(hz.life), "ph": 0.0,
		"vel": dir * float(hz.speed), "chariot": true})
	ui.show_banner(hz.text, 3.0)
	_tip("seek")


func _caught_away() -> void:
	# 主的靈把腓利提了去（徒 8:39）：主角和隊伍一起到了別的地方
	var hz: Dictionary = stage.hazard
	var a := randf() * TAU
	var off := Vector2(cos(a), sin(a) * 0.8) * 220.0
	holies.append({"pos": paul.pos, "t": 0.0, "r": 40.0})
	paul.pos += off
	for c in comps:
		if c.level > 0:
			c.pos += off
			c.base += off
	for f in followers:
		f.pos += off
	ui.do_flash(0.5)
	ui.show_banner(hz.caught_text, 3.0)


## 安提阿：掃羅改稱保羅；劇情模式裡馬可半路離隊
func _update_journey(hz: Dictionary) -> void:
	var el := t - t_start
	if journey_step == 0 and el >= float(hz.rename_at):
		journey_step = 1
		if leader == "paul":
			if ui.names.has(D.paul.name):
				ui.names[D.paul.name].text = D.paul.name
			ui.hero_label.text = D.paul.name
			ui.show_banner(hz.rename_text, 2.5)
	if journey_step == 1 and el >= float(hz.depart_at):
		journey_step = 2
		var c = by_key.get(hz.depart)
		if story and c != null and c.level > 0:
			c.level = 0
			c.gone = true
			c.node.visible = false
			links = links.filter(func(L): return L.src != c and L.dst != c)
			ui.place_name(c.name, Vector2.ZERO, false)
			_ring_pop(c.pos, Color("8a8a96"), 14.0)
			ui.show_banner(hz.depart_text, 3.0)
			if smoke:
				print("DEPART ", c.key, " party=", _party_count())


## 大馬色：路上的大光 → 瞎眼（只看得見身邊）→ 亞拿尼亞走過來按手 → 鱗片掉下、被聖靈充滿
func _update_blind(dt: float, hz: Dictionary) -> void:
	var el := t - t_start
	match blind_state:
		"vision":
			# 對話結束（或第二次以後直接）：一道大光，然後什麼都看不見
			blind_flash = 0.7
			blind_state = "blind"
			blind_r = float(hz.radius)
			shake = 0.4
			Sfx.play("holy", 0.0)
			ui.show_banner(hz.text, 3.0)
		"blind":
			blind_flash = maxf(0.0, blind_flash - dt)
			if el >= float(hz.ananias_at) and ananias.is_empty():
				var a := randf() * TAU
				ananias = {"pos": paul.pos + Vector2(cos(a), sin(a) * 0.7) * 130.0, "node": _sprite("ananias_0", Vector2(-12, -25))}
				ui.show_banner("有人走過來了：「掃羅弟兄……」（徒 9:17）", 2.5)
			if not ananias.is_empty():
				var to: Vector2 = paul.pos - ananias.pos
				ananias.pos += to.normalized() * minf(to.length(), float(hz.ananias_speed) * dt)
				ananias.node.position = ananias.pos.round()
				ananias.node.texture = _tex("ananias_%d" % (int(t * 4.0) % 2))
				if to.length() < float(hz.touch):
					_ananias_arrive(hz)
		"heal":
			if blind_r <= float(hz.radius):
				ui.show_banner(hz.heal_text, 3.0)   # 對話結束後才出現
			blind_r += dt * 420.0
			if blind_r > 700.0:
				blind_state = "done"
		"done":
			if not ananias.is_empty():
				var to2: Vector2 = paul.pos + Vector2(-16, 6) - ananias.pos
				if to2.length() > 10.0:
					ananias.pos += to2.normalized() * minf(to2.length(), 50.0 * dt)
				ananias.node.position = ananias.pos.round()
				ananias.node.texture = _tex("ananias_%d" % ((int(t * 4.0) % 2) if to2.length() > 10.0 else 0))


func _ananias_arrive(hz: Dictionary) -> void:
	blind_state = "heal"
	meter = 1.0   # 被聖靈充滿：五旬節可以開了
	holies.append({"pos": paul.pos, "t": 0.0, "r": 60.0})
	Sfx.play("holy", 0.0)
	if smoke:
		print("ANANIAS t=%.0f" % (t - t_start))
	var seen: Array = Save.data.get("story_seen", [])
	if not seen.has("ananias_" + stage.id) or OS.get_cmdline_user_args().has("--talk"):
		if not seen.has("ananias_" + stage.id):
			seen.append("ananias_" + stage.id)
			Save.data.story_seen = seen
			Save.save_profile()
		_show_talk(stage.get("talk_ananias", []))


## 黑暗：一格一格的實心黑色，只留主角身邊一個圓；路上的大光是整片亮白
## 大馬色城門的探照光（地面層與瞎眼的黑暗層都畫）
func _draw_searchlight(n: Node2D) -> void:
	if boss == null or float(boss.get("search_t", 0.0)) <= 0.0:
		return
	var tip: Vector2 = boss.pos + Vector2.from_angle(boss.search_ang) * 280.0
	n.draw_line(boss.pos, tip, Color(Color("fff4c2"), 0.25), 22.0)
	n.draw_line(boss.pos, tip, Color(Color("fff4c2"), 0.6), 8.0)
	n.draw_line(boss.pos, tip, Color.WHITE, 2.0)


func _draw_dark() -> void:
	var n := dark
	var v := _view_rect().grow(4.0)
	var c: Vector2 = paul.pos.round()
	if vision_on:
		# 路上：光裡站著耶穌（光柱畫在地面那層，掃羅站在光裡）
		var at := c + Vector2(0, -36)
		for i in 12:
			var a := i / 12.0 * TAU + t * 0.3
			n.draw_line(at + Vector2(cos(a), sin(a)) * 14.0, at + Vector2(cos(a), sin(a)) * (24.0 + 4.0 * (i % 2)), Color("ffe9a0"), 2.0)
		n.draw_circle(at, 13.0, Color("fff8d8"))
		n.draw_texture_rect(_tex("jesus_0"), Rect2(at + Vector2(-17, -19), Vector2(36, 33)), false)
		return
	if blind_state == "" or blind_state == "done" or blind_state == "vision":
		return
	if blind_flash > 0.0:
		n.draw_rect(v, Color("fffbe8") if blind_flash > 0.35 else Color("ffe9a0"))
		return
	var r := blind_r
	var edge := 5.0
	var y := v.position.y
	var dk := Color("05030a")
	var band := Color("1c1228")
	while y < v.end.y:
		var dy := y + 1.0 - c.y
		if absf(dy) >= r:
			n.draw_rect(Rect2(v.position.x, y, v.size.x, 2), dk)
		else:
			var hw := floorf(sqrt(r * r - dy * dy) / 2.0) * 2.0
			var hw2 := floorf(sqrt(maxf(0.0, (r - edge) * (r - edge) - dy * dy)) / 2.0) * 2.0 if absf(dy) < r - edge else 0.0
			n.draw_rect(Rect2(v.position.x, y, c.x - hw - v.position.x, 2), dk)
			n.draw_rect(Rect2(c.x + hw, y, v.end.x - c.x - hw, 2), dk)
			n.draw_rect(Rect2(c.x - hw, y, hw - hw2, 2), band)
			n.draw_rect(Rect2(c.x + hw2, y, hw - hw2, 2), band)
		y += 2.0
	_draw_searchlight(n)   # 瞎眼的時候也看得到探照的光
	# 亞拿尼亞在黑暗裡：圓邊上一個金色箭頭指著他的方向
	if not ananias.is_empty() and blind_state == "blind":
		var to: Vector2 = ananias.pos - c
		if to.length() > r - 4.0:
			var d := to.normalized()
			var tip := c + d * (r - 2.0)
			var side := Vector2(-d.y, d.x)
			n.draw_colored_polygon(PackedVector2Array([tip, tip - d * 7.0 + side * 4.0, tip - d * 7.0 - side * 4.0]), C_GOLD)


## 各城的關卡機制（米利大的暴風、拔摩的星辰各有自己的函式）
func _update_hazard(dt: float) -> void:
	_update_director(dt)
	altar_buff = maxf(0.0, altar_buff - dt)
	_update_spots(dt)
	var hz: Dictionary = stage.get("hazard", {})
	var kind: String = hz.get("kind", "")
	if kind == "blind":
		_update_blind(dt, hz)
		return
	_update_tongues_sheets(dt, hz)
	if kind == "chariot":
		if not chariot_done and t - t_start >= float(hz.at) and boss == null:
			_spawn_chariot(hz)
		return
	if kind == "journey":
		_update_journey(hz)
		return
	if kind in ["", "wind", "stars"] or boss != null or choosing:
		return
	if hz_t < 0.0:
		hz_t = float(hz.get("first", 40))
	if t - t_start < hz_t:
		return
	hz_t = t - t_start + float(hz.every)
	ui.show_banner(hz.get("text", ""), 2.0)
	Sfx.play("warn", 0.0)
	var v := _view_rect()
	match kind:
		"quake":
			# 腓立比：半夜的地震，全場敵人暈眩
			for e in enemies:
				if not e.dead and not e.get("boss", false):
					e.stun = maxf(e.stun, float(hz.stun))
			quakes.append({"pos": paul.pos, "r": 0.0})
			shake = 0.5
			ui.do_flash(0.3)
		"mob", "phalanx":
			# 帖撒羅尼迦的暴民、羅馬的軍團：從畫面一側排成一排衝過來
			var dirs := [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]
			var dir: Vector2 = dirs.pick_random()
			var n := int(hz.count)
			for i in n:
				var off := (i - (n - 1) / 2.0) * (14.0 if kind == "phalanx" else 10.0)
				var at: Vector2
				if dir.x != 0.0:
					at = Vector2(v.position.x - 12.0 if dir.x > 0.0 else v.end.x + 12.0, paul.pos.y + off + randf_range(-3, 3))
				else:
					at = Vector2(paul.pos.x + off + randf_range(-3, 3), v.position.y - 12.0 if dir.y > 0.0 else v.end.y + 12.0)
				if kind == "mob":
					at += -dir * randf_range(0.0, 30.0)
				_spawn_one(hz.type, at)
				enemies[-1].swarm_dir = dir
				enemies[-1].march = true
		"assassins":
			# 耶路撒冷：刺客從四面直奔主角
			for i in int(hz.count):
				var a := i * TAU / float(hz.count)
				_spawn_one(hz.type, paul.pos + Vector2(cos(a), sin(a) * 0.8) * 110.0)
				var e: Dictionary = enemies[-1]
				e.smul = float(e.smul) * 1.4
				e.hp = float(e.hp) * 2.0
				e.tint = Color(1.6, 0.6, 0.6)
				e.assassin = true
				e.hunter = false
				_ring_pop(e.pos, C_RED, 12.0)
		"altar", "tent":
			var a := randf() * TAU
			spots.append({"kind": kind, "pos": paul.pos + Vector2(cos(a), sin(a) * 0.8) * randf_range(60.0, 90.0), "life": float(hz.life), "on": 0.0})
		"tongues":
			# 五旬節：舌頭如火焰落在每個人頭上，燒傷身邊的敵人，同心合意增加
			for o in [paul] + comps.filter(func(c): return c.level > 0 and c.down <= 0.0):
				tongues.append({"who": o, "t": 1.4})
				blasts.append({"pos": o.pos, "t": 0.0, "r": float(hz.radius), "col": C_FLAME, "evo": false})
				for e in enemies.duplicate():
					if not e.dead and not e.get("boss", false) and e.pos.distance_to(o.pos) < float(hz.radius):
						_hurt(e, float(hz.damage) * (1.0 + level * 0.05), o.pos)
			meter = minf(1.0, meter + float(hz.meter))
			Sfx.play("holy", 0.0)
		"sheet":
			# 約帕：天上降下一塊大布，落地時範圍裡的敵人被說服過來
			var a2 := randf() * TAU
			sheets.append({"pos": paul.pos + Vector2(cos(a2), sin(a2) * 0.8) * randf_range(10.0, 40.0), "t": float(hz.warn), "max": float(hz.warn)})
		"bonfire":
			for i in int(hz.count):
				var a := randf() * TAU
				spots.append({"kind": "bonfire", "pos": paul.pos + Vector2(cos(a), sin(a) * 0.8) * randf_range(30.0, 80.0), "life": float(hz.life), "tick": 0.0})


func _update_spots(dt: float) -> void:
	var hz: Dictionary = stage.get("hazard", {})
	for sp in spots:
		sp.life -= dt
		match sp.kind:
			"altar":
				# 站在壇上累積時間，滿了就得到加成
				if paul.pos.distance_to(sp.pos) < 14.0:
					sp.on += dt
					if sp.on >= float(hz.need):
						sp.life = 0.0
						altar_buff = float(hz.buff_t)
						ui.show_banner("你們所敬拜的，我現在告訴你們（徒 17:23）　傷害 +%d%%" % roundi(float(hz.buff) * 100.0), 2.0)
						_ring_pop(sp.pos, C_GOLD, 40.0)
						Sfx.play("levelup", 0.0)
			"tent":
				if paul.pos.distance_to(sp.pos) < 14.0:
					sp.life = 0.0
					guard = mini(guard + int(hz.guard), 5)
					for i in int(hz.bread):
						breads.append({"pos": sp.pos + Vector2(randf_range(-10, 10), randf_range(-8, 8))})
					ui.show_banner("在帳棚裡歇一下腳：護盾 +%d" % int(hz.guard), 1.5)
					_ring_pop(sp.pos, Color("9fd8ff"), 30.0)
			"bait":
				if paul.pos.distance_to(sp.pos) < sp.r + 4.0:
					sp.life = 0.0
					blasts.append({"pos": sp.pos, "t": 0.0, "r": 26.0, "col": C_GOLD, "evo": false})
					if paul.inv <= 0.0:
						_damage_paul(sp.dmg, false, "boss")
			"dark":
				sp.tick -= dt
				if sp.tick <= 0.0:
					sp.tick = 0.5
					if paul.pos.distance_to(sp.pos) < sp.r and paul.inv <= 0.0:
						_damage_paul(sp.dmg, false, "boss")
			"water":
				sp.tick -= dt
				if sp.tick <= 0.0:
					sp.tick = 0.5
					if paul.pos.distance_to(sp.pos) < sp.r:
						paul.hp = minf(float(D.paul.hp), paul.hp + 1.5)
					for c in comps:
						if c.level > 0 and c.down <= 0.0 and c.pos.distance_to(sp.pos) < sp.r:
							c.hp = minf(_comp_max_hp(), float(c.hp) + 1.5)
					for e in _enemies_near(sp.pos, sp.r + 8.0):
						if not e.dead and e.pos.distance_to(sp.pos) < sp.r:
							e.slow_t = maxf(float(e.get("slow_t", 0.0)), 0.8)
			"blaze", "potion":
				sp.tick -= dt
				if sp.tick <= 0.0:
					sp.tick = 0.5
					for e in _enemies_near(sp.pos, sp.r + 8.0):
						if not e.dead and e.pos.distance_to(sp.pos) < sp.r and float(e.get("ally", 0.0)) <= 0.0:
							_hurt(e, float(sp.dmg), Vector2.INF, sp.owner)
							if sp.kind == "potion":
								e.slow_t = maxf(float(e.get("slow_t", 0.0)), 0.8)
			"ember":
				sp.tick -= dt
				if sp.tick <= 0.0:
					sp.tick = 0.5
					for e in enemies.duplicate():
						if not e.dead and e.pos.distance_to(sp.pos) < 14.0:
							e.burn_t = maxf(float(e.get("burn_t", 0.0)), 1.5)
							e.burn_dps = maxf(float(e.get("burn_dps", 0.0)), float(sp.dmg))
			"bonfire":
				sp.tick -= dt
				if sp.tick <= 0.0:
					sp.tick = 0.5
					for e in enemies.duplicate():
						if not e.dead and e.pos.distance_to(sp.pos) < float(hz.radius):
							_hurt(e, float(hz.damage) * _curve(D.waves.scaling.hp, t) * 0.5, Vector2.INF)
	spots = spots.filter(func(sp): return sp.life > 0.0)


func _draw_spots(n: Node2D) -> void:
	var hz: Dictionary = stage.get("hazard", {})
	for sp in spots:
		var x: float = roundf(sp.pos.x)
		var y: float = roundf(sp.pos.y)
		var blinking: bool = sp.life < 2.0 and int(t * 8.0) % 2 == 0
		match sp.kind:
			"bait":
				# 亮晶晶的錢幣（其實是陷阱）：金色、會閃，底下一點黑影
				var glint := int(t * 6.0 + x) % 3 == 0
				n.draw_circle(Vector2(x, y + 2), 5.0, Color(0.1, 0.0, 0.1, 0.4))
				n.draw_rect(Rect2(x - 3, y - 3, 7, 6), Color("8a5a10"))
				n.draw_rect(Rect2(x - 2, y - 2, 5, 4), Color("ffd75e"))
				if glint:
					n.draw_rect(Rect2(x - 1, y - 2, 1, 1), Color.WHITE)
			"dark":
				# 黑暗的水窪：深紫色的一片，邊緣冒泡
				var da: float = clampf(sp.life / 1.0, 0.0, 1.0)
				n.draw_set_transform(Vector2(x, y), 0.0, Vector2(1.0, 0.7))
				n.draw_circle(Vector2.ZERO, sp.r, Color(0.16, 0.06, 0.22, 0.55 * da))
				n.draw_circle(Vector2.ZERO, sp.r * 0.7, Color(0.28, 0.08, 0.36, 0.45 * da))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				_dot_ring(n, Vector2(x, y), sp.r, 0.7, Color(Color("a060ff"), da), 4.0, -t * 1.2, 1)
			"water":
				# 活水：淡藍的一片，邊緣有慢慢轉的點
				var wa: float = clampf(sp.life / 1.0, 0.0, 1.0)
				n.draw_circle(Vector2(x, y), sp.r, Color(0.45, 0.75, 0.95, 0.12 * wa))
				_dot_ring(n, Vector2(x, y), sp.r, 0.8, Color(Color("9fd8ff"), wa), 5.0, t * 0.8, 1)
			"blaze":
				# 燒著的地：一圈火苗在地上跳
				var bk: float = clampf(sp.life / 0.6, 0.0, 1.0)
				_pring(n, Vector2(x, y), sp.r, Color(C_RED, bk), 1, 0.6, 2)
				for j in 9:
					var ja := j * 2.4 + 0.7
					var jr: float = sp.r * (0.25 + 0.7 * fmod(j * 0.37, 1.0))
					var jx: float = roundf(x + cos(ja) * jr)
					var jy: float = roundf(y + sin(ja) * jr * 0.6)
					var jh := 2 + (int(t * 10.0 + j) % 3)
					n.draw_rect(Rect2(jx - 1, jy - jh, 3, jh), Color(C_FLAME, bk))
					n.draw_rect(Rect2(jx, jy - jh - 1, 1, 2), Color(C_GOLD, bk))
			"potion":
				# 藥水：一灘淡綠色的水，冒小泡泡
				var pk2: float = clampf(sp.life / 0.6, 0.0, 1.0)
				var ry2: float = sp.r * 0.6
				for yy in range(-int(ry2), int(ry2) + 1):
					var hw := floorf(sp.r * sqrt(maxf(0.0, 1.0 - pow(yy / ry2, 2.0))))
					n.draw_rect(Rect2(x - hw, y + yy, hw * 2.0 + 1.0, 1), Color(Color("5ac8a0") if yy % 3 else Color("8ae0c0"), 0.55 * pk2))
				_pring(n, Vector2(x, y), sp.r, Color(Color("2a6a5a"), pk2), 1, 0.6)
				var bb := int(t * 3.0 + x) % 4
				n.draw_rect(Rect2(x - 4 + bb * 2, y - 2 - bb, 2, 2), Color(Color.WHITE, pk2))
			"ember":
				var fl2 := int(t * 10.0 + x) % 2
				_dot_ring(n, Vector2(x, y), 12.0, 0.75, C_FLAME, 4.0, t * 2.0, 1)
				n.draw_rect(Rect2(x - 2, y - 4 - fl2, 5, 4), C_RED)
				n.draw_rect(Rect2(x - 1, y - 5 + fl2, 3, 4), C_FLAME)
			"altar":
				# 石壇：灰白色的方台，上面刻著字；站上去時下面的圈慢慢填滿
				_dot_ring(n, Vector2(x, y), 14.0, 0.75, C_GOLD, 3.0, t, 2)
				var k: float = clampf(sp.on / float(hz.need), 0.0, 1.0)
				if k > 0.0:
					n.draw_arc(Vector2(x, y), 10.0, -PI / 2.0, -PI / 2.0 + TAU * k, 24, C_GOLD, 3.0)
				if not blinking:
					n.draw_rect(Rect2(x - 6, y - 12, 13, 11), Color("3a362e"))
					n.draw_rect(Rect2(x - 5, y - 11, 11, 9), Color("c8c2b2"))
					n.draw_rect(Rect2(x - 3, y - 9, 7, 1), Color("6a665e"))
					n.draw_rect(Rect2(x - 3, y - 6, 5, 1), Color("6a665e"))
			"tent":
				if not blinking:
					n.draw_colored_polygon(PackedVector2Array([Vector2(x - 10, y), Vector2(x, y - 14), Vector2(x + 10, y)]), Color("2a1a10"))
					n.draw_colored_polygon(PackedVector2Array([Vector2(x - 8, y - 1), Vector2(x, y - 12), Vector2(x + 8, y - 1)]), Color("c8a46b"))
					n.draw_line(Vector2(x, y - 12), Vector2(x, y - 1), Color("8a6438"), 1.0)
					n.draw_rect(Rect2(x - 2, y - 5, 4, 4), Color("5a3a20"))
				_dot_ring(n, Vector2(x, y), 14.0, 0.75, Color("9fd8ff"), 4.0, t, 1)
			"bonfire":
				var fl := int(t * 10.0 + x) % 2
				_dot_ring(n, Vector2(x, y), float(hz.radius), 0.75, C_FLAME, 4.0, t * 2.0, 2)
				n.draw_rect(Rect2(x - 6, y - 2, 13, 4), Color("3a1a08"))
				n.draw_rect(Rect2(x - 5, y - 1, 11, 2), Color("8a5a30"))
				n.draw_rect(Rect2(x - 4, y - 8 - fl, 9, 7), C_RED)
				n.draw_rect(Rect2(x - 3, y - 10 + fl, 7, 7), C_FLAME)
				n.draw_rect(Rect2(x - 1, y - 9, 3, 5), C_GOLD)


## 拔摩海島：星辰從天墜落（啟 8:10）。先在地上出現預警圈，時間到砸下來，主角、同伴、敵人都會受傷
func _update_stars(dt: float) -> void:
	for sf in star_falls:
		sf.t -= dt
		if sf.t <= 0.0 and not sf.get("done", false):
			sf.done = true
			blasts.append({"pos": sf.pos, "t": 0.0, "r": sf.r * 1.4, "col": C_GOLD, "evo": false})
			shake = maxf(shake, 0.15)
			if paul.pos.distance_to(sf.pos) < sf.r and paul.inv <= 0.0:
				_damage_paul(sf.dmg, sf.get("pierce", false), sf.get("src", "persecute" if sf.get("pierce", false) else "star"))
			for c in comps:
				if c.level > 0 and c.down <= 0.0 and c.pos.distance_to(sf.pos) < sf.r and fever <= 0.0:
					c.hurt_cd = 0.0
					_damage_companion(c, sf.dmg)
			for e in enemies.duplicate():
				if not e.dead and e.pos.distance_to(sf.pos) < sf.r:
					_hurt(e, sf.dmg * 2.0, sf.pos)
	star_falls = star_falls.filter(func(sf): return sf.t > -0.3)
	var hz: Dictionary = stage.get("hazard", {})
	if hz.get("kind", "") != "stars" or boss != null or choosing:
		return
	star_t -= dt
	if star_t <= 0.0:
		star_t = float(hz.every)
		ui.show_banner(hz.get("text", "星辰墜落！"), 1.3)
		Sfx.play("warn", 0.0)
		for i in int(hz.count):
			var a := randf() * TAU
			var at: Vector2 = paul.pos + Vector2(cos(a), sin(a) * 0.8) * randf_range(0.0, 70.0)
			var wn: float = float(hz.warn) * (1.5 if calling == "prophet" else 1.0)
			star_falls.append({"pos": at, "t": wn, "max": wn, "r": float(hz.radius), "dmg": float(hz.damage) * _curve(D.waves.scaling.damage, t)})


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
			# 地上的小細節（不擋路）
			var dl: Array = stage.get("decals", [])
			if not dl.is_empty():
				for k in 6:
					var dk: String = dl[floori(_hash(cx * 3 + k * 41, cy * 11 + k * 7) * dl.size()) % dl.size()]
					var ds := Sprite2D.new()
					ds.texture = _tex(dk)
					ds.centered = true
					ds.flip_h = _hash(cx + k, cy - k) > 0.5
					ds.position = Vector2(cx * CHUNK + floori(_hash(cx * 13 + k, cy * 5 + k * 3) * CHUNK), cy * CHUNK + floori(_hash(cx * 7 - k, cy * 17 + k) * CHUNK))
					decals.add_child(ds)
					items.append(ds)
			# 這座城的地標：偶爾才有一座，有地標的那一格就不放別的物件
			var lms: Array = stage.get("landmarks", [])
			var lmh := _hash(cx * 31 + 5, cy * 37 + 9)
			if not lms.is_empty() and lmh < 0.045 and Vector2(cx, cy).length() > 1.5:
				var lm: Dictionary = lms[floori(_hash(cx + 3, cy + 5) * lms.size()) % lms.size()]
				var lt := _tex(lm.tex)
				var lx := cx * CHUNK + CHUNK / 2
				var ly := cy * CHUNK + CHUNK / 2 + lt.get_height() / 2
				var ls := _sprite(lm.tex, Vector2(-lt.get_width() / 2, -lt.get_height()))
				ls.position = Vector2(lx, ly)
				items.append(ls)
				var sw: float = lm.get("solid", [lt.get_width() - 8, 14])[0]
				var sh: float = lm.get("solid", [lt.get_width() - 8, 14])[1]
				if sw > 0.0:
					rects.append(Rect2(lx - sw / 2.0, ly - sh, sw, sh))
				else:
					ls.reparent(decals)   # 平的（打穀場）：人可以走上去，畫在地上
				chunks[key] = {"items": items, "rects": rects}
				continue
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
		if not _fx_lite():
			shake_off = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
	cam.position = p.pos.round() + shake_off
	var v := _view_rect()
	ground.position = (v.position - Vector2(16, 16)).floor()
	ground.region_rect = Rect2(ground.position, v.size + Vector2(32, 32))

	var walk := int(t * 5.0) % 2
	p.node.texture = _tex("%s%s_%d" % [pa.key, "_evo" if evolved.has(pa.key) else "", walk if p.moving else 0])
	p.hurt_t = maxf(0.0, float(p.get("hurt_t", 0.0)) - dt)
	_animate(p.node, p.pos, p.moving, float(p.get("face", 1.0)), pa.castfx / 0.18, p.hurt_t / 0.18, 0.0, 0.15, pa.get("cast_dir", Vector2.ZERO))
	p.node.modulate = Color(1, 1, 1, 0.4 if p.inv > 0.0 and int(t * 20.0) % 2 == 1 else 1.0)
	if p.hp <= 0.0:
		# 倒下了：躺平、變灰
		p.node.modulate = Color(0.5, 0.5, 0.5)
		p.node.rotation = deg_to_rad(80.0) * float(p.get("face", 1.0))
		p.node.scale = Vector2.ONE
	for c in comps:
		if c.level == 0:
			continue
		var c_moving: bool = (p.moving or c.vel.length() > 5.0) and c.down <= 0.0
		var f: int = (walk + c.i) % 2 if c_moving else 0
		c.node.texture = _tex("%s%s_%d" % [c.key, "_evo" if evolved.has(c.key) else "", f])
		if absf(c.vel.x) > 4.0:
			c.face = signf(c.vel.x)
		c.hurt_t = maxf(0.0, float(c.get("hurt_t", 0.0)) - dt)
		var k: float = c.castfx / 0.18
		if c.down > 0.0:
			# 倒下：躺平（往臉朝的方向倒）
			c.node.position = c.pos.round()
			c.node.rotation = deg_to_rad(80.0) * float(c.get("face", 1.0))
			c.node.scale = Vector2.ONE
			c.node.modulate = Color(0.55, 0.55, 0.6)
			continue
		_animate(c.node, c.pos, c_moving, float(c.get("face", 1.0)), k, c.hurt_t / 0.18, c.i * 1.7, 0.2, c.get("cast_dir", Vector2.ZERO))
		if c.sleep > 0.0:
			c.node.modulate = Color(0.6, 0.65, 0.85)
		elif c.hurt_t > 0.0:
			c.node.modulate = Color(3, 3, 3) if c.hurt_t > 0.14 else Color(1.9, 0.75, 0.7)
		else:
			c.node.modulate = Color.WHITE.lerp(Color(1.8, 1.7, 1.2), k)
	if p.hurt_t > 0.0 and p.hp > 0.0:
		p.node.modulate = Color(3, 3, 3, 1.0) if p.hurt_t > 0.14 else Color(1.9, 0.75, 0.7, p.node.modulate.a)
	var ef := int(t * 4.0) % 2
	for e in enemies:
		if e.dead:
			continue
		if not e.get("boss", false):
			e.node.texture = _tex("%s_%d" % [e.sprite, (ef + int(e.ph)) % 2])
			# 剛出現：從地上長出來；被打中：壓扁一下
			var age: float = t - float(e.get("born", -9.0))
			if e.flash > 0.0:
				e.node.scale = Vector2(1.18, 0.86)
			elif age < 0.22 and age >= 0.0:
				var g := age / 0.22
				e.node.scale = Vector2(1.0 + 0.3 * (1.0 - g), g)
			else:
				e.node.scale = Vector2.ONE
		e.node.position = e.pos.round()
		if e.flash > 0.0:
			e.node.modulate = Color(4, 4, 3.5)
		elif float(e.get("ally", 0.0)) > 0.0:
			e.node.modulate = Color(2.4, 2.0, 0.5)   # 被說服：變成金色
		elif e.stun > 0.0 or (e.get("boss", false) and e.state == "break"):
			e.node.modulate = Color(1.5, 1.5, 0.8)
		elif float(e.get("exposed_t", 0.0)) > 0.0:
			e.node.modulate = Color(1.6, 1.15, 0.6)   # 被燈照亮
		else:
			e.node.modulate = e.tint

	for pf in poofs:
		pf.t += dt
	poofs = poofs.filter(func(pf): return pf.t < 0.3)

	ground_fx.queue_redraw()
	air.queue_redraw()
	dark.queue_redraw()

	var ct := get_viewport().get_canvas_transform()
	var all_names := bool(Save.data.get("names_on", false))
	var calm_ui := not over and not choosing
	ui.place_name(D.paul.name, ct * p.pos, calm_ui and (all_names or t - t_start < 6.0))
	for c in comps:
		var nm_on: bool = calm_ui and c.level > 0 and (all_names or t < float(c.get("name_until", 0.0)) or float(c.get("down", 0.0)) > 0.0)
		if c.follows != "":
			ui.place_name(c.name, Vector2.ZERO, false)
		elif c.with != "":
			ui.place_name(c.name, ct * ((c.pos + by_key[c.with].pos) / 2.0), nm_on)
		else:
			ui.place_name(c.name, ct * c.pos, nm_on)
	ui.set_boss(boss.hp / boss.max_hp if boss != null and not boss.dead else -1.0, D.boss.name)
	ui.update_hud({"hp_frac": clampf(p.hp / D.paul.hp, 0.0, 1.0), "level": level, "xp_frac": clampf(float(xp) / xp_need, 0.0, 1.0),
		"time": int(t), "kills": kills, "bread": run_bread, "meter": meter, "fever": fever, "fever_kills": fever_kills, "over": over, "choosing": choosing or chest_open, "build": build_text, "tasks": _task_text(), "combo": combo, "combo_t": combo_t, "boss_in": _boss_in()})


## 人物的動作（不用另外畫圖，全部用位置、傾斜、伸縮做出來）：
## 走路時一跳一跳、左右輕晃；站著時慢慢呼吸；出招時往前一壓；被打時往後縮一下；往左走就轉身。
## 腳底是原點，所以伸縮、傾斜都以腳為中心。
func _animate(node: Sprite2D, pos: Vector2, moving: bool, face: float, cast_k: float, hurt_k: float, ph: float, cast_amt: float, cast_dir := Vector2.ZERO) -> void:
	var bob := 0.0
	var off := Vector2.ZERO
	if cast_k > 0.0 and cast_dir != Vector2.ZERO:
		# 出手：面向目標，往前跨一步再收回來
		off += cast_dir * 3.0 * sin(cast_k * PI)
		if absf(cast_dir.x) > 0.2:
			face = signf(cast_dir.x)
	if hurt_k > 0.0 and not _fx_lite():
		off.x += roundf(sin(t * 70.0) * 1.2 * hurt_k)   # 被打：抖一下
	var tilt := 0.0
	var sc := Vector2.ONE
	if moving:
		var w := t * 10.0 + ph
		bob = -absf(sin(w)) * 1.5
		tilt = sin(w) * 0.07
	else:
		sc.y = 1.0 + 0.025 * sin(t * 2.4 + ph)
	sc *= Vector2(1.0 + cast_amt * cast_k, 1.0 - cast_amt * 0.6 * cast_k)
	if hurt_k > 0.0:
		sc *= Vector2(1.0 - 0.12 * hurt_k, 1.0 + 0.08 * hurt_k)
		tilt -= 0.18 * hurt_k * face
	node.position = pos.round() + Vector2(0, roundf(bob)) + off.round()
	node.rotation = tilt
	node.scale = sc
	node.flip_h = face < 0.0


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


## ---------- 招式的招牌機制（參考魔獸世界各職業的玩法）----------
## 出手前：依這位同伴的招牌機制改這一次的數值；回傳空的 = 這次不出手
func _signature_pre(c: Dictionary, s: Dictionary) -> Dictionary:
	match c.get("skill", ""):
		"street":
			# 吳文水「引導」：隊伍停下來越久，講得越大聲（傷害、寬度最多 3 倍）
			var k := 1.0 + minf(2.0, still_t * 0.6)
			if k > 1.05:
				s = s.duplicate()
				s.damage = float(s.damage) * k
				s.width = float(s.width) * (1.0 + (k - 1.0) * 0.5)
				if k >= 2.5:
					_fxc("越講越大聲")
					_tag_fx(c, "越講越大聲", C_GOLD)
		"prayer":
			# 雅各「引導禱告」：照常禱告；隊伍停下來越久，補得越多（最多 2 倍）
			var k2 := 1.0 + minf(1.0, still_t * 0.5)
			s = s.duplicate()
			for key in ["heal", "heal_team"]:
				if s.has(key):
					s[key] = float(s[key]) * k2
		"sling":
			# 大衛「蓄力」：越久沒甩，石子越重（最多 3 倍）
			var idle := t - float(c.get("last_cast_t", t)) - float(s.cooldown)
			if idle > 0.2:
				s = s.duplicate()
				s.damage = float(s.damage) * (1.0 + minf(2.0, idle * 0.8))
				_fxc("蓄力")
		"cymbal":
			# 亞薩「重拍」：每第 4 下鈸聲，傷害三倍、圈更粗
			c.beat_n = (int(c.get("beat_n", 0)) + 1) % 4
			if c.beat_n == 0:
				s = s.duplicate()
				s.damage = float(s.damage) * 3.0
				s.thick = int(s.get("thick", 1)) + 2
				_fxc("重拍")
				_tag_fx(c, "鏘！", C_GOLD)
				shake = maxf(shake, 0.08)
		"touch":
			s = s.duplicate()
			s.execute = 1.0   # 多馬「斬殺」：打血少的敵人會心加倍（在 _cast 的 thrust 判斷）
	return s


## 出手後：招牌機制的後續（連擊點數、嗜血、嘲諷、戰場復活……）
func _signature_post(c: Dictionary, s: Dictionary, triggered: bool) -> void:
	c.last_cast_t = t
	match c.get("skill", ""):
		"bolt":
			# 提摩太「熱心」：射滿 6 支，放一次齊射（像連擊點數）
			c.combo = int(c.get("combo", 0)) + int(s.count)
			if c.combo >= 6:
				c.combo = 0
				_fxc("熱心齊射")
				for tg in _nearest_enemies(c.pos, float(s.range) * 1.3, 6):
					bolts.append({"pos": c.pos + Vector2(0, -12), "target": tg, "life": 1.5, "pierce": int(s.pierce), "split": 0, "child": true,
						"dmg": float(s.damage), "size": int(s.size) + 1, "hit": {}, "spd": float(s.speed) * 1.2, "emult": 1.0, "look": c.look, "owner": c, "evo": true})
				_tag_fx(c, "熱心齊射", C_GOLD)
		"cook":
			# 高長「大餐」：吃過飯的同伴 8 秒內出手加快
			for o in comps:
				if o.level > 0 and o.down <= 0.0:
					o.fed_t = 8.0
			pa.fed_t = 8.0
			_fxc("吃飽了")
			_tag_fx(c, "開飯了", Color("f0c070"))
		"timbrel":
			# 米利暗「嗜血」：每 25 秒擊鼓，全隊出手加快 30%、6 秒
			if t >= float(c.get("lust_at", 0.0)):
				c.lust_at = t + 25.0
				haste_t = maxf(haste_t, 6.0)
				haste_amt = maxf(haste_amt, 0.3)
				_fxc("擊鼓跳舞")
				ui.show_banner("米利暗擊鼓跳舞！全隊加快", 1.2)
				_ring_pop(c.pos + Vector2(0, -10), C_GOLD, 60.0)
		"heal":
			# 路加「戰場復活」：每 30 秒，倒下的同伴立刻扶起來
			if t >= float(c.get("res_at", 0.0)):
				for o in comps:
					if o.level > 0 and o.down > 0.0:
						o.down = 0.0
						o.hp = _comp_max_hp() * 0.6
						c.res_at = t + 30.0
						_fxc("扶起來")
						_tag_fx(o, "路加扶起來了", C_HEAL)
						_ring_pop(o.pos + Vector2(0, -10), C_HEAL, 24.0)
						break
		"jawbone":
			# 參孫「嘲諷」：身邊的敵人 2 秒內只追他
			for e in _enemies_near(c.pos, 70.0):
				if not e.dead and not e.get("boss", false):
					e.taunt_t = 2.0
					e.taunt_by = c
			_fxc("嘲諷")
		"horn":
			# 希幔「吹號」：身邊的敵人驚慌、四散逃開
			for e in _enemies_near(c.pos, float(s.radius) * _area()):
				if not e.dead and not e.get("boss", false) and not e.get("elite", false):
					e.fear_t = float(s.fear)
			_fxc("驚慌")
		"harp":
			# 耶杜頓「稱謝」：接下來幾秒，同伴出手有機會立刻再出手一次
			harp_t = float(s.duration)
			harp_chance = float(s.chance)
			_fxc("稱謝")
	if harp_t > 0.0 and not triggered and c.get("skill", "") != "harp" and randf() < harp_chance:
		delayed.append({"t": 0.12, "fn": func(): _cast(c, true)})
		_fxc("琴聲再一次")


func _tag_fx(o: Dictionary, text: String, col: Color) -> void:
	if tag_fx.size() < 12:
		tag_fx.append({"pos": o.pos + Vector2(4, 8), "text": text, "col": col, "t": 0.0})


## 測試用：每一種特效擺一個在主角周圍，時間停住（--fxtest）
func _fx_gallery() -> void:
	var c0: Vector2 = paul.pos
	for e in enemies:
		e.dead = true
	enemies.clear()
	zaps.append({"pts": [c0 + Vector2(-97, -36), c0 + Vector2(-71, -24), c0 + Vector2(-52, -42)], "t": 0.05, "evo": false, "col": Color("8fd0ff")})
	beams.append({"pos": c0 + Vector2(-97, 6), "dir": Vector2(1, 0.25).normalized(), "len": 90.0, "width": 3.0, "life": 0.3, "look": "", "col": Color("3fbfb0")})
	beams.append({"pos": c0 + Vector2(-97, 24), "dir": Vector2(1, -0.1).normalized(), "len": 90.0, "width": 5.0, "life": 0.3, "look": "sea", "col": Color("2f78c8")})
	blasts.append({"pos": c0 + Vector2(45, -36), "t": 0.08, "r": 18.0, "col": C_FLAME, "evo": false})
	blasts.append({"pos": c0 + Vector2(84, -33), "t": 0.12, "r": 45.0, "col": C_GOLD, "evo": false})
	fires.append({"pos": c0 + Vector2(-26, -18), "t": -0.1, "max": 0.6, "r": 16.0, "dmg": 0.0, "owner": pa, "evo": false, "look": ""})
	fires.append({"pos": c0 + Vector2(0, -24), "t": -0.1, "max": 0.6, "r": 16.0, "dmg": 0.0, "owner": pa, "evo": false, "look": "glory"})
	fires.append({"pos": c0 + Vector2(26, -18), "t": -0.1, "max": 0.6, "r": 16.0, "dmg": 0.0, "owner": pa, "evo": false, "look": "spit"})
	fires.append({"pos": c0 + Vector2(58, 12), "t": 0.3, "max": 0.6, "r": 18.0, "dmg": 0.0, "owner": pa, "evo": false, "look": ""})
	nets.append({"pos": c0 + Vector2(-65, 48), "r": 30.0, "t": 0.1, "evo": false, "look": "", "stun": 1.0, "col": Color("e8dcc0")})
	nets.append({"pos": c0 + Vector2(6, 54), "r": 34.0, "t": 0.3, "evo": false, "look": "purple", "stun": 2.0, "col": Color("8e4488")})
	rings.append({"owner": pa, "r": 40.0, "max": 80.0, "thick": 2, "dir": 1.0, "returns": 0, "hit": {}})
	thrusts.append({"from": c0 + Vector2(52, 36), "dir": Vector2(1, 0), "len": 40.0, "t": 0.1, "crit": true, "evo": false, "look": "", "col": Color("d8d0c0")})
	thrusts.append({"from": c0 + Vector2(52, 48), "dir": Vector2(1, 0), "len": 50.0, "t": 0.1, "crit": false, "evo": false, "look": "dash", "col": Color("6ae0d0")})
	impacts.append({"pos": c0 + Vector2(97, 0), "t": 0.03, "col": C_GOLD, "size": 14.0, "dir": Vector2.RIGHT, "rot": 0.0})
	heals.append({"who": paul, "t": 0.2})
	guard = 3
	Engine.time_scale = 0.0


## ---------- 像素特效的小工具（實心像素、不反鋸齒，跟人物同一套畫法）----------
## 動畫圖（橫排一條、每格一樣寬）的第 f 格，畫在 at（center：中心對齊；否則底邊中間對齊）
func _fx(n: Node2D, key: String, frames: int, f: int, at: Vector2, sc := 1.0, col := Color.WHITE, center := true) -> void:
	var tx := _tex("fx_" + key)
	var fw := tx.get_width() / frames
	var fh := tx.get_height()
	var w := fw * sc
	var hh := fh * sc
	var o := at.round() - (Vector2(w / 2.0, hh / 2.0) if center else Vector2(w / 2.0, hh))
	n.draw_texture_rect_region(tx, Rect2(o.round(), Vector2(w, hh).round()), Rect2(clampi(f, 0, frames - 1) * fw, 0, fw, fh), col)


## 呂底亞的紫布：一片橢圓的布（一橫條一橫條畫，邊上金色流蘇），在原解析度畫才不會變成大方塊
func _pcloth(n: Node2D, c: Vector2, r: float, a: float, evo: bool) -> void:
	var ry := r * 0.62
	for yy in range(-int(ry), int(ry) + 1):
		var half := floorf(r * sqrt(maxf(0.0, 1.0 - pow(yy / ry, 2.0))))
		if half < 1.0:
			continue
		var col := Color("6e3068") if posmod(yy, 4) < 2 else Color("8e4488")
		n.draw_rect(Rect2(c.x - half, c.y + yy, half * 2.0 + 1.0, 1), Color(col, a))
		n.draw_rect(Rect2(c.x - half, c.y + yy, 1, 1), Color(C_GOLD if evo else Color("c8a040"), a))
		n.draw_rect(Rect2(c.x + half, c.y + yy, 1, 1), Color(C_GOLD if evo else Color("c8a040"), a))
	_pring(n, c, r, Color(C_GOLD, a), 1, 0.62, 1)


## 彼得的網：斜格子的漁網＋一圈網邊和鉛墜
func _pnet(n: Node2D, c: Vector2, r: float, a: float, col: Color) -> void:
	var ry := r * 0.75
	var step := 6.0
	for k in range(-int(r * 2.0 / step), int(r * 2.0 / step) + 1):
		for sgn in [1.0, -1.0]:
			var last := Vector2(INF, INF)
			for yy in range(-int(ry), int(ry) + 1):
				var xx: float = k * step + sgn * yy
				if pow(xx / r, 2.0) + pow(yy / ry, 2.0) > 1.0:
					continue
				var p := Vector2(c.x + xx, c.y + yy)
				if p != last:
					n.draw_rect(Rect2(p, Vector2.ONE), Color(col, a * 0.85))
					last = p
	_pring(n, c, r, Color(Color("6b4a2a"), a), 2, 0.75)
	for i in 10:
		var ang := i * TAU / 10.0
		n.draw_rect(Rect2((c + Vector2(cos(ang) * r, sin(ang) * ry)).round() - Vector2(1, 1), Vector2(3, 3)), Color(Color("8a8a9a"), a))


## 一條像素線（每一步畫一個 w×w 的方塊）
func _pline(n: Node2D, a: Vector2, b: Vector2, col: Color, w := 1) -> void:
	var d := b - a
	var steps := maxi(1, int(maxf(absf(d.x), absf(d.y))))
	var off := Vector2(w / 2, w / 2)
	for i in steps + 1:
		var p := (a + d * (float(i) / steps)).round() - off
		n.draw_rect(Rect2(p, Vector2(w, w)), col)


## 像素圓環（橢圓：ky 是上下壓扁的比例）
func _pring(n: Node2D, c: Vector2, r: float, col: Color, w := 1, ky := 0.75, gap := 0) -> void:
	if r < 1.0:
		return
	var count := maxi(12, int(r * TAU / maxf(1.0, w * 0.9)))
	var last := Vector2(INF, INF)
	for k in count:
		if gap > 0 and k % (gap * 2) >= gap:
			continue
		var a := k / float(count) * TAU
		var p := Vector2(roundf(c.x + cos(a) * r), roundf(c.y + sin(a) * r * ky))
		if p == last:
			continue
		last = p
		n.draw_rect(Rect2(p - Vector2(w / 2, w / 2), Vector2(w, w)), col)


## 閃電：從 a 到 b 的鋸齒折線（每 0.05 秒換一次形狀，看起來在跳動）
func _bolt_pts(a: Vector2, b: Vector2, seed: int) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var d := b - a
	var segs := clampi(int(d.length() / 9.0), 2, 10)
	var side := d.orthogonal().normalized()
	var step := int(t * 20.0)
	for i in range(1, segs):
		var k := float(i) / segs
		var j := (_hash(seed + i * 7, step) - 0.5) * 10.0 * sin(k * PI)
		pts.append(a + d * k + side * j)
	pts.append(b)
	return pts


func _draw_ground_fx() -> void:
	var n := ground_fx
	# 馬利亞的香膏：地上一片淡粉金色的香膏（畫在人物腳下），中間一個打開的玉瓶
	for z in zones:
		var k: float = clampf(z.life / z.max, 0.0, 1.0)
		var fade: float = clampf(k * 3.0, 0.0, 1.0) * clampf((z.max - z.life) / 0.25, 0.0, 1.0)   # 出現與消失都淡入淡出
		var zc: Vector2 = z.pos.round()
		var zcol: Color = z.owner.col
		for i in 3:
			var rr: float = z.r * (1.0 - i * 0.28)
			n.draw_set_transform(zc, 0.0, Vector2(1.0, 0.62))
			n.draw_circle(Vector2.ZERO, rr, Color(zcol.lerp(C_CREAM, i * 0.35), (0.16 + i * 0.07) * fade))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		n.draw_set_transform(zc, 0.0, Vector2(1.0, 0.62))
		n.draw_arc(Vector2.ZERO, z.r, 0.0, TAU, 40, Color(zcol, 0.55 * fade), 1.5)
		n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 玉瓶：白色瓶身、金色瓶口，倒出來的香膏
		n.draw_rect(Rect2(zc.x - 2, zc.y - 6, 5, 6), Color(Color("f4ead2"), fade))
		n.draw_rect(Rect2(zc.x - 1, zc.y - 8, 3, 2), Color(C_GOLD, fade))
		n.draw_rect(Rect2(zc.x + 3, zc.y - 1, 3, 1), Color(zcol.lerp(C_CREAM, 0.4), fade))
	if vision_on:
		# 天上一道光柱照在主角身上（大馬色路上、升天、司提反看見天開了）
		var v0 := _view_rect()
		var c0: Vector2 = paul.pos.round()
		for i in 5:
			var w := 34.0 - i * 6.0
			n.draw_rect(Rect2(c0.x - w / 2.0, v0.position.y - 4.0, w, c0.y - v0.position.y + 8.0), [Color("6a5a3a"), Color("a08a50"), Color("d8c070"), Color("fff0b0"), Color("ffffff")][i])
	# 瞬移的預兆：落點的紫色圈慢慢收縮
	for e in enemies:
		if e.has("blink_to") and not e.dead:
			var k: float = clampf(float(e.blink_wait) / 0.7, 0.0, 1.0)
			n.draw_arc(e.blink_to, 4.0 + k * 10.0, 0.0, TAU, 16, Color(Color("a060ff"), 0.9), 1.5)
			n.draw_circle(e.blink_to, 3.0, Color(Color("a060ff"), 0.35))
	for o in [paul] + comps:
		if o != paul and o.level == 0:
			continue
		n.draw_rect(Rect2(round(o.pos.x) - 5, round(o.pos.y) - 1, 11, 2), Color(0.24, 0.13, 0.05, 0.35))
		n.draw_rect(Rect2(round(o.pos.x) - 4, round(o.pos.y) - 2, 9, 4), Color(0.24, 0.13, 0.05, 0.18))
	# 敵人腳下的影子（讓人站在地上，不像貼紙）
	var vr := _view_rect().grow(16.0)
	for e in enemies:
		if e.dead or e.get("boss", false) or not vr.has_point(e.pos):
			continue
		n.draw_rect(Rect2(round(e.pos.x) - 6, round(e.pos.y) - 1, 13, 2), Color(0.1, 0.05, 0.08, 0.28))
	_draw_spots(n)
	# 先知：預言之地（紫色的圈，中間一隻眼睛）
	if not prophecy.is_empty():
		var pc: Vector2 = prophecy.pos.round()
		_dot_ring(n, pc, prophecy.r, 0.8, Color("c8a0ff"), 3.0, t * 0.6, 2)
		_dot_ring(n, pc, prophecy.r - 6.0, 0.8, C_GOLD, 5.0, -t * 0.6, 1)
		n.draw_rect(Rect2(pc.x - 6, pc.y - 2, 13, 5), Color("2a1640"))
		n.draw_rect(Rect2(pc.x - 5, pc.y - 1, 11, 3), Color("c8a0ff"))
		n.draw_rect(Rect2(pc.x - 1, pc.y - 2, 3, 5), C_GOLD)
	# 星辰墜落的落點：紅色虛線圈慢慢收縮
	for sf in star_falls:
		if sf.t > 0.0:
			var k: float = clampf(sf.t / sf.max, 0.0, 1.0)
			_dot_ring(n, sf.pos.round(), sf.r, 0.8, C_RED, 3.0, t * 3.0, 2)
			_dot_ring(n, sf.pos.round(), sf.r * k, 0.8, C_GOLD, 4.0, -t * 3.0, 1)
	# 差派：發光的腳蹤（實心，快消失時變小）
	for f in trail:
		var fx: float = roundf(f.pos.x) + (2.0 if f.side == 1 else -3.0)
		var fy: float = roundf(f.pos.y)
		var big: bool = f.life > 0.6
		var fc: Color = C_GOLD if f.life > f.max * 0.6 else C_FLAME
		if big:
			n.draw_rect(Rect2(fx - 1, fy - 3, 4, 6), Color("3a1606"))
			n.draw_rect(Rect2(fx, fy - 2, 2, 4), fc)
			n.draw_rect(Rect2(fx, fy - 2, 1, 1), C_CREAM)
		else:
			n.draw_rect(Rect2(fx, fy - 1, 2, 2), C_FLAME)
	# 詩歌：主角腳下的四個拍子
	if _school_on("詩歌"):
		var bx: float = roundf(paul.pos.x) - 8.0
		var by: float = roundf(paul.pos.y) + 4.0
		for k in 4:
			var lit: bool = posmod(beat_i, 4) == k
			var dn: bool = k == 0 or (k == 2 and _sv("詩歌", "offbeat") > 0.0)
			var sz := 3 if dn else 2
			n.draw_rect(Rect2(bx + k * 5 - 1, by - 1, sz + 2, sz + 2), Color("1a1008"))
			n.draw_rect(Rect2(bx + k * 5, by, sz, sz), (C_GOLD if dn else C_CREAM) if lit else Color("5a4a30"))
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
	_draw_finds(n)
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
	# 被驅散的敵人：變白、壓扁、往上飄走
	for pf in poofs:
		var k: float = pf.t / 0.3
		var sx: float = (1.0 + 0.5 * k) * (-1.0 if pf.flip else 1.0)
		n.draw_set_transform(pf.pos + Vector2(0, -6.0 * k), 0.0, Vector2(sx, 1.0 - 0.7 * k))
		n.draw_texture(pf.tex, pf.off, Color(3.0, 3.0, 2.6, 1.0 - k))
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
		# 實心顏色：深色描邊＋本色＋亮色內線，外圈有幾個音符般的小方塊
		var k: float = clampf(r.r / r.max, 0.0, 1.0)
		var center: Vector2 = (r.owner.pos + Vector2(0, -6)).round()
		var col: Color = C_FLAME if on_fire else r.owner.get("col", C_GOLD)
		# 聲波：一圈像素環，越外面越細；環上四個音符跟著轉
		var w: int = 3 if k < 0.4 and r.thick >= 2 else 2
		_pring(n, center, r.r, col.darkened(0.5), w + 1, 0.8)
		_pring(n, center, r.r, col, w - 1 if w > 1 else 1, 0.8)
		for j in 4:
			var ang: float = j * TAU / 4.0 + r.r * 0.03
			_fx(n, "note", 1, 0, center + Vector2(cos(ang), sin(ang) * 0.8) * r.r)
		if r.get("evo", false):
			_pring(n, center, r.r + 3.0, C_GOLD, 1, 0.8, 2)
	for b in beams:
		var end: Vector2 = b.pos + b.dir * b.len
		# 實心光束：越接近消失越細，而不是變透明
		var a := minf(1.0, b.life * 3.3)
		var bw: float = b.width * (0.4 + 0.6 * a)
		if b.get("evo", false):
			n.draw_line(b.pos, end, C_GOLD, bw * 2.4)
		var bc: Color = C_FLAME if on_fire else b.get("col", Color("3fbfb0"))
		if b.look == "lamp":
			bc = C_FLAME if on_fire else Color("ff9a3a")
		elif b.look == "sea":
			bc = C_FLAME if on_fire else Color("2f78c8")
		# 光束：一節一節的像素光（灰階圖上色），粗細取整數像素
		var bh := maxf(3.0, roundf(bw * 1.6 + 2.0))
		n.draw_set_transform(b.pos.round(), b.dir.angle(), Vector2.ONE)
		n.draw_texture_rect(_tex("fx_beam"), Rect2(Vector2(0, -bh / 2.0), Vector2(b.len, bh)), true, bc.lightened(0.15))
		n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_fx(n, "spark", 4, int(t * 12.0) % 2, b.pos)
		# 光束上流動的小方塊
		for j in 4:
			var fp: Vector2 = (b.pos + b.dir * b.len * fmod(t * 2.5 + j * 0.25, 1.0)).round()
			n.draw_rect(Rect2(fp.x - 1, fp.y - 1, 3, 3), C_CREAM)
		_fx(n, "spark", 4, 1 + int(t * 12.0) % 2, end)
	for b in blasts:
		# 實心衝擊波：一圈粗的本色環往外推，裡面跟著一圈亮色與放射的碎塊
		# 爆開：小的用像素火球動畫，大的（升級、震波）用一圈往外推的像素環
		var k: float = b.t / 0.3
		var bcol: Color = b.get("col", C_GOLD)
		var rr: float = b.r * (0.4 + k * 0.6)
		if b.r <= 34.0:
			var sc := maxf(1.0, roundf(b.r / 14.0 * 2.0) / 2.0)
			_fx(n, "boom", 6, int(k * 6.0), b.pos, sc, Color.WHITE.lerp(bcol, 0.35))
		else:
			_pring(n, b.pos.round(), rr, bcol.darkened(0.5), 3, 0.8)
			_pring(n, b.pos.round(), rr, bcol, 2, 0.8)
			_pring(n, b.pos.round(), rr - 2.0, C_CREAM, 1, 0.8, 2)
		if b.get("evo", false):
			_pring(n, b.pos.round(), b.r * (0.6 + k * 0.7), C_GOLD, 1, 0.8, 2)
	for f in fires:
		var flook: String = f.get("look", "")
		if f.t > 0.0:
			# 預兆：地上一圈虛線，裡面一圈往內收
			var k: float = 1.0 - f.t / f.max
			var wc: Color = Color("8fd0ff") if flook == "spit" else (C_GOLD if flook == "glory" else C_FLAME)
			_pring(n, f.pos.round(), f.r, wc, 2, 0.6, 2)
			_pring(n, f.pos.round(), f.r * (1.0 - k), C_CREAM, 1, 0.6)
		else:
			var a: float = 1.0 + f.t / 0.35      # 1 → 0：落下後慢慢收掉
			var fr := int((1.0 - a) * 12.0) % 4
			var shrink := clampf(a * 1.4, 0.0, 1.0)
			if flook == "spit":
				# 約拿的大魚吐出來：一道水柱砸下來，落點水花
				_fx(n, "watercol", 4, fr, f.pos + Vector2(0, 2), 1.0, Color(1, 1, 1, shrink), false)
				_fx(n, "splash", 4, int((1.0 - a) * 4.0), f.pos + Vector2(0, -4), 1.5)
			elif flook == "glory":
				# 司提反：天開了，白金色的光柱，落點一圈光
				_fx(n, "glorycol", 4, fr, f.pos + Vector2(0, 2), 1.0, Color(1, 1, 1, shrink), false)
				_pring(n, f.pos.round(), f.r * (1.4 - a * 0.4), C_GOLD, 2, 0.6)
			else:
				_fx(n, "firecol", 4, fr, f.pos + Vector2(0, 2), 1.0, Color(1, 1, 1, shrink), false)
				_fx(n, "boom", 6, int((1.0 - a) * 5.0) + 1, f.pos + Vector2(0, -4), 1.0)
			if f.get("evo", false):
				_pring(n, f.pos.round(), f.r * 1.2, C_CREAM, 1, 0.6, 2)
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
		_pring(n, paul.pos.round() + Vector2(0, -12), 13.0, Color(C_GOLD, 0.7), 1, 1.1, 3)
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
			_pcloth(n, f.pos.round(), rr2, 1.0 - pk * pk, f.evo)
			continue
		# 彼得的網：一張圓網撒開再收攏
		var k: float = f.t / 0.4
		var rr: float = f.r * (1.0 - 0.3 * k)
		_pnet(n, f.pos.round(), rr, 1.0 - k * k, C_GOLD if f.evo else Color("c8b48a"))
	for z in zaps:
		# 閃電：鋸齒狀的像素線，外面一層本色、裡面白芯；打中的地方一團電光
		var col: Color = C_GOLD if z.evo else z.get("col", Color("ffe14d"))
		var thick: int = 3 if z.t < 0.12 else 2
		for i in z.pts.size() - 1:
			var p0: Vector2 = z.pts[i]
			var p1: Vector2 = z.pts[i + 1]
			var bp := _bolt_pts(p0, p1, i * 31 + int(p0.x))
			for j in bp.size() - 1:
				_pline(n, bp[j], bp[j + 1], col.darkened(0.45), thick + 1)
			for j in bp.size() - 1:
				_pline(n, bp[j], bp[j + 1], col if thick > 2 else col.lightened(0.3), thick - 1)
			for j in bp.size() - 1:
				_pline(n, bp[j], bp[j + 1], Color.WHITE, 1)
			_fx(n, "zapend", 3, int(z.t / 0.25 * 3.0), p1)
	for th in thrusts:
		var a: float = 1.0 - th.t / 0.2
		var tip: Vector2 = th.from + th.dir * th.len * minf(1.0, th.t / 0.06)
		var col: Color = C_GOLD if th.crit or th.evo else th.get("col", Color("d8d0c0"))
		if th.get("look", "") == "dash":
			# 腓利：一道青色的奔跑殘影（三道平行的速度線）
			col = C_GOLD if th.crit or th.evo else Color("6ae0d0")
			var sd: Vector2 = th.dir.orthogonal()
			for i in 3:
				_pline(n, th.from + sd * (i - 1) * 4.0, th.from.lerp(tip, 0.6 + i * 0.15) + sd * (i - 1) * 4.0, col.darkened(0.2 * i), 2 if i == 1 else 1)
		_pline(n, th.from, tip, col.darkened(0.6), 4 if th.crit else 3)
		_pline(n, th.from, tip, col, 2 if th.crit else 1)
		_fx(n, "spark", 4, int((1.0 - a) * 4.0), tip, 2.0 if th.crit else 1.0)
	for g in gathers:
		var k: float = g.t / 0.5
		_dot_ring(n, g.pos.round() + Vector2(0, -4), g.r * (1.0 - k), 0.8, C_HEAL, 4.0, k * 3.0, 2)
		_dot_ring(n, g.pos.round() + Vector2(0, -4), g.r * (1.0 - k) - 5.0, 0.8, C_CREAM, 6.0, -k * 3.0, 1)
	# 五旬節：頭上的火焰（實心的紅、橘、金三層）
	for tg in tongues:
		var hp: Vector2 = (tg.who.pos + Vector2(0, -32 - (int(t * 8.0) % 2))).round()
		n.draw_rect(Rect2(hp.x - 3, hp.y - 2, 7, 6), Color("c8301a"))
		n.draw_rect(Rect2(hp.x - 2, hp.y - 5, 5, 6), C_FLAME)
		n.draw_rect(Rect2(hp.x - 1, hp.y - 7, 3, 5), C_GOLD)
		n.draw_rect(Rect2(hp.x, hp.y - 9, 1, 3), Color.WHITE)
	# 約帕：四角吊著的大布從天上降下來
	for sh in sheets:
		if sh.t > 0.0:
			var k: float = clampf(sh.t / sh.max, 0.0, 1.0)
			var r: float = float(stage.hazard.radius)
			var c0: Vector2 = (sh.pos + Vector2(0, -160.0 * k)).round()
			_dot_ring(n, sh.pos.round(), r, 0.8, C_CREAM, 5.0, t, 1)
			var w := r * (0.6 + 0.4 * (1.0 - k))
			for cx in [-1, 1]:
				n.draw_line(c0 + Vector2(cx * w, -w * 0.5), c0 + Vector2(cx * w * 0.3, -w * 0.5 - 60.0), Color("c9a46b"), 1.0)
			n.draw_rect(Rect2(c0.x - w, c0.y - w * 0.5, w * 2.0, w), Color("6a5a48"))
			n.draw_rect(Rect2(c0.x - w + 2, c0.y - w * 0.5 + 2, w * 2.0 - 4, w - 4), Color("f4ead2"))
			for i in 5:
				n.draw_rect(Rect2(c0.x - w + 6 + i * (w * 2.0 - 12) / 4.0, c0.y - 2 + (i % 2) * 4, 3, 2), [Color("8a6438"), Color("5a8a2a"), Color("6a5a90"), Color("b05a30"), Color("3a3a3a")][i])
	# 星辰：從天上斜斜落下，拖著金色的尾巴（司提反那一關是石頭）
	for sf in star_falls:
		if sf.t > 0.0 and stage.get("hazard", {}).get("look", "") == "stone" and not sf.get("pierce", false):
			var ks: float = clampf(sf.t / sf.max, 0.0, 1.0)
			var spp: Vector2 = (sf.pos + Vector2(-90.0, -60.0) * ks + Vector2(0, -40.0 * sin(ks * PI))).round()
			_dot_ring(n, sf.pos.round(), sf.r, 0.8, Color("c8b8a0"), 4.0, 0.0, 1)
			n.draw_rect(Rect2(spp.x - 3, spp.y - 3, 7, 6), Color("3a3430"))
			n.draw_rect(Rect2(spp.x - 2, spp.y - 3, 5, 5), Color("8a8078"))
			n.draw_rect(Rect2(spp.x - 2, spp.y - 3, 2, 2), Color("b0a89c"))
			continue
		if sf.t > 0.0:
			var k: float = clampf(sf.t / sf.max, 0.0, 1.0)
			var sp: Vector2 = (sf.pos + Vector2(40.0, -150.0) * k).round()
			n.draw_line(sp, sp + Vector2(16, -60) * 0.5, Color("8a5a10"), 4.0)
			n.draw_line(sp, sp + Vector2(16, -60) * 0.5, C_GOLD, 2.0)
			n.draw_rect(Rect2(sp.x - 3, sp.y - 3, 7, 7), Color("8a5a10"))
			n.draw_rect(Rect2(sp.x - 2, sp.y - 2, 5, 5), C_GOLD)
			n.draw_rect(Rect2(sp.x - 1, sp.y - 1, 3, 3), Color.WHITE)
	for sh in tele:
		if sh.get("star", false) and boss != null:
			var kk: float = clampf(float(boss.timer) / float(D.boss.warn), 0.0, 1.0)
			var sp2: Vector2 = (sh.c + Vector2(30.0, -140.0) * kk).round()
			n.draw_line(sp2, sp2 + Vector2(10, -40), C_GOLD, 2.0)
			n.draw_rect(Rect2(sp2.x - 2, sp2.y - 2, 5, 5), C_GOLD)
			n.draw_rect(Rect2(sp2.x - 1, sp2.y - 1, 3, 3), Color.WHITE)
	# 七個金燈台
	if epistles.has("lamps") and fever > 0.0:
		for lp in _lamp_points():
			var lx: float = roundf(lp.x)
			var ly: float = roundf(lp.y)
			n.draw_rect(Rect2(lx - 3, ly + 3, 7, 2), Color("8a6420"))
			n.draw_rect(Rect2(lx - 1, ly - 3, 3, 7), Color("8a6420"))
			n.draw_rect(Rect2(lx, ly - 3, 1, 7), C_GOLD)
			n.draw_rect(Rect2(lx - 2, ly + 3, 5, 1), C_GOLD)
			var fl := int(t * 10.0 + lx) % 2
			n.draw_rect(Rect2(lx - 1, ly - 7 - fl, 3, 3), C_FLAME)
			n.draw_rect(Rect2(lx, ly - 7 - fl, 1, 2), C_CREAM)
	_draw_engines(n)
	_draw_ailments(n)
	_draw_seek(n)
	_draw_schools(n)
	for dn in dnums:
		var k2: float = dn.t / 0.7
		var big: bool = dn.v >= 20.0 + level * 1.5   # 大傷害：比這個等級平常的一擊大很多
		var txt := str(roundi(dn.v))
		# 跳出來時先大一點再縮回去（0.1 秒），之後往上飄、往旁邊偏一點
		var pop := 1.0 + 0.6 * clampf(1.0 - dn.t / 0.1, 0.0, 1.0)
		var fs := roundi((11 if big else 8) * pop)
		var rise := 14.0 * (1.0 - pow(1.0 - minf(k2 * 1.6, 1.0), 2.0))
		var pos2: Vector2 = (dn.pos + Vector2(-fs * txt.length() * 0.3 + float(dn.get("dx", 0.0)) * k2, -rise)).round()
		var a2 := 1.0 if k2 < 0.6 else (1.0 - k2) / 0.4
		n.draw_string_outline(UIKit.font(), pos2, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, Color(Color("140c10"), a2))
		n.draw_string(UIKit.font(), pos2, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Color.WHITE.lerp(dn.col, 0.6) if not big else C_GOLD, a2))
	for f in tag_fx:
		var k: float = f.t / 0.8
		var pos: Vector2 = (f.pos + Vector2(-8, -32 - k * 10.0)).round()
		n.draw_string_outline(UIKit.font(), pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(Color("140c10"), 1.0 - k))
		n.draw_string(UIKit.font(), pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(f.col, 1.0 - k))
	if guard > 0:
		# 護盾：一面一面小盾牌繞著主角轉（幾面就是擋得下幾次）
		for i in guard:
			var ga := t * 1.6 + i * TAU / guard
			var gp: Vector2 = paul.pos + Vector2(0, -12) + Vector2(cos(ga) * 15.0, sin(ga) * 9.0)
			_fx(n, "shield", 2, int(t * 4.0 + i) % 2, gp)
	for f in link_fx:
		var to: Vector2 = f.b.pos + Vector2(0, -8)
		if f.t < 0.3:
			var a: float = 1.0 - f.t / 0.3
			# 從來源射向被觸發的人：前 0.08 秒線往前長出去
			var tip: Vector2 = f.a.lerp(to, minf(1.0, f.t / 0.08))
			var lc: Color = C_FLAME if f.depth >= 2 else C_GOLD
			var lw := 2 + mini(f.depth, 2) if a > 0.4 else 2
			_pline(n, f.a, tip, lc.darkened(0.6), lw + 1)
			_pline(n, f.a, tip, lc, maxi(1, lw - 1))
			_pline(n, f.a, tip, C_CREAM, 1)
			_fx(n, "spark", 4, int((1.0 - a) * 3.0), tip, 2.0 if f.depth >= 2 else 1.0)
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
			_dot_ring(n, b.pos.round(), 5.0, 1.0, C_GOLD, 4.0, t * 6.0)
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
		elif b.look == "vial":
			# 藥瓶：淡青色的玻璃瓶、褐色軟木塞，跟著方向轉
			var d: Vector2 = b.dir
			var side := d.orthogonal()
			var c0: Vector2 = b.pos
			n.draw_line(c0 - d * 7.0, c0, Color(Color("8ae0d0"), 0.35), 2.0)
			n.draw_colored_polygon(PackedVector2Array([c0 - d * 3 - side * 2, c0 + d * 2 - side * 2, c0 + d * 2 + side * 2, c0 - d * 3 + side * 2]), C_FLAME if on_fire else Color("bff0e6"))
			n.draw_line(c0 + d * 2, c0 + d * 4, Color("8a5a30"), 2.0)
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
			n.draw_line(b.pos - dir * (10.0 + b.size * 3.0), b.pos, col.darkened(0.5), 2.0 + b.size)
			n.draw_line(b.pos - dir * (7.0 + b.size * 2.0), b.pos, col, 1.0 + b.size)
			n.draw_line(b.pos - dir * 5.0, b.pos, C_CREAM, 1.0)
			var r: int = 2 if b.size < 2 else 3
			n.draw_rect(Rect2(x - r, y - 1, r * 2 + 1, 3), col)
			n.draw_rect(Rect2(x - 1, y - r, 3, r * 2 + 1), col)
			n.draw_rect(Rect2(x - 1, y - 1, 3, 3), Color.WHITE)
	if boss != null and float(boss.get("vortex_t", 0.0)) > 0.0:
		# 漩渦：繞著 Boss 轉的弧線，越來越快
		for i in 4:
			var va: float = t * 5.0 + i * TAU / 4.0
			n.draw_arc(boss.pos, 30.0 + i * 14.0, va, va + 1.4, 16, Color(Color("a060ff"), 0.7), 2.0)
	for w in joy_waves:
		# 歡呼：金色的圈往外擴散，越外面越淡
		var ka: float = 1.0 - w.r / w.max
		_dot_ring(n, w.pos, w.r, 0.8, Color(C_GOLD, 0.3 + 0.6 * ka), 4.0, t * 2.0, 2)
	for ln in boss_lines:
		# 長老的指控：一道細線慢慢變亮，快落下時閃爍
		var k: float = clampf(1.0 - ln.t / ln.max, 0.0, 1.0)
		var on: bool = ln.t > 0.3 or int(t * 10.0) % 2 == 0
		n.draw_line(ln.a, ln.b, Color(C_RED, 0.15 + 0.25 * k), ln.w * (0.3 + 0.7 * k))
		if on:
			n.draw_line(ln.a, ln.b, Color(Color("ff3a2a"), 0.4 + 0.6 * k), 1.0)
		n.draw_circle(ln.a, 4.0, Color("c8a040"))
	for w in boss_walls:
		# 隔斷的牆：灰色的磚牆往中間推，門的地方空著
		var gy0: float = w.gap_y - w.gap_h / 2.0
		var gy1: float = w.gap_y + w.gap_h / 2.0
		n.draw_rect(Rect2(w.x - 5, w.top, 10, gy0 - w.top), Color("4a4448"))
		n.draw_rect(Rect2(w.x - 5, gy1, 10, w.bot - gy1), Color("4a4448"))
		n.draw_rect(Rect2(w.x - 3, w.top, 2, gy0 - w.top), Color("8a8088"))
		n.draw_rect(Rect2(w.x - 3, gy1, 2, w.bot - gy1), Color("8a8088"))
		n.draw_rect(Rect2(w.x - 6, gy0 - 3, 12, 3), Color("ffd75e"))
		n.draw_rect(Rect2(w.x - 6, gy1, 12, 3), Color("ffd75e"))
	if not tether.is_empty():
		# 捆鎖：從釘住的點拉到主角的一條鎖鏈，和一圈範圍
		_dot_ring(n, tether.pos, tether.r, 0.8, Color(Color("a8a8b8"), 0.8), 5.0, t, 1)
		var cl: Vector2 = paul.pos - tether.pos
		for i in int(cl.length() / 5.0):
			var cp: Vector2 = tether.pos + cl.normalized() * (i * 5.0)
			n.draw_rect(Rect2(cp.x - 1, cp.y - 1, 3, 3), Color("c8c8d8") if i % 2 == 0 else Color("6a6a7a"))
	_draw_searchlight(n)
	for w in boss_waves:
		# 衝擊波：一圈紫紅色的牆，缺口的地方空著
		var a0: float = w.gap + w.gap_w
		var span: float = TAU - w.gap_w * 2.0
		n.draw_arc(w.pos, w.r, a0, a0 + span, 72, Color("14060c"), 11.0)
		n.draw_arc(w.pos, w.r, a0, a0 + span, 72, Color("8a1020"), 7.0)
		n.draw_arc(w.pos, w.r + 2.0, a0, a0 + span, 72, Color("ff5a40"), 2.0)
		# 缺口兩端畫亮一點，看得出從哪裡穿過去
		for ea in [w.gap - w.gap_w, w.gap + w.gap_w]:
			n.draw_circle(w.pos + Vector2.from_angle(ea) * w.r, 4.0, Color("ffd75e"))
	for s in shots:
		if s.get("boss", false):
			var sp2: Vector2 = s.pos.round()
			n.draw_circle(sp2, 4.0, Color("2a0a30"))
			n.draw_circle(sp2, 3.0, Color("c040e0"))
			n.draw_circle(sp2 + Vector2(-1, -1), 1.2, Color("ffd0ff"))
			continue
		n.draw_rect(Rect2(roundf(s.pos.x) - 1, roundf(s.pos.y) - 1, 3, 3), Color("c8e070"))
		n.draw_rect(Rect2(roundf(s.pos.x), roundf(s.pos.y), 1, 1), Color("2a2638"))
	for h in heals:
		if h.t > 0.75:
			continue
		# 醫治：身上冒出三顆綠色光點往上飄
		var hk: float = h.t / 0.75
		for j in 3:
			var hp2: Vector2 = h.who.pos + Vector2(-6 + j * 6, -10.0 - j * 4.0 - hk * 16.0 + (j % 2) * 3.0)
			_fx(n, "heal", 3, int(hk * 3.0 + j * 0.5), hp2)
	for q in parts:
		var qc: Color = q.c1 if q.life > q.max * 0.5 else q.c2
		if q.get("float", false):
			var a: float = clampf(q.life / 0.4, 0.0, 1.0)
			n.draw_rect(Rect2(roundf(q.pos.x) - 1, roundf(q.pos.y), 3, 1), Color(qc, a * 0.6))
			n.draw_rect(Rect2(roundf(q.pos.x), roundf(q.pos.y) - 1, 1, 3), Color(qc, a))
		else:
			n.draw_rect(Rect2(roundf(q.pos.x), roundf(q.pos.y), 1, 1), qc)
	for im in impacts:
		# 打中：像素火花（大一擊用兩倍大），往前噴幾顆碎塊
		var k: float = im.t / 0.2
		var sz: float = im.size
		var ic: Color = im.col
		_fx(n, "spark", 4, int(k * 4.0), im.pos, 2.0 if sz >= 12.0 else 1.0, Color.WHITE.lerp(ic, 0.3))
		if not _fx_lite():
			var base_a: float = im.dir.angle() + im.rot
			for j in 3:
				var v := Vector2.from_angle(base_a + (j - 1) * 0.5)
				var dp: Vector2 = (im.pos + v * sz * (0.6 + 1.2 * k)).round()
				n.draw_rect(Rect2(dp, Vector2(2, 2)), ic.lightened(0.3))
	for sp in sparks:
		var sx: float = roundf(sp.pos.x)
		var sy: float = roundf(sp.pos.y)
		var ssz := 3 if sp.t < 0.06 else 2
		var scol: Color = sp.get("col", C_GOLD)
		n.draw_rect(Rect2(sx - ssz, sy, ssz * 2 + 1, 1), Color.WHITE)
		n.draw_rect(Rect2(sx, sy - ssz, 1, ssz * 2 + 1), Color.WHITE)
		n.draw_rect(Rect2(sx - 1, sy - 1, 3, 3), scol)
	for rz in resonances:
		var ra: float = 1.0 - rz.r / 260.0
		var rcol: Color = [C_GOLD, C_FLAME, Color("ff6ad5"), Color.WHITE][mini(rz.tier, 3)]
		var rw := int((2.0 + rz.tier) * ra) + 2
		_pring(n, rz.pos.round(), rz.r, rcol.darkened(0.6), rw + 1, 0.8)
		_pring(n, rz.pos.round(), rz.r, rcol, rw - 1, 0.8)
		_pring(n, rz.pos.round(), rz.r * 0.85, C_CREAM, 1, 0.8, 2)
		if rz.r < 60.0:
			var pw: float = (9.0 + rz.tier * 2) * ra
			n.draw_rect(Rect2(rz.pos.x - pw / 2.0, rz.pos.y - 120, pw, 120), rcol)
			n.draw_rect(Rect2(rz.pos.x - 1, rz.pos.y - 120, 3, 120), C_CREAM)
	for o in pops:
		var k: float = o.t / 0.25
		_dot_ring(n, o.pos.round(), o.size * (0.3 + k), 1.0, o.col, 3.0, 0.0, 2 if k < 0.5 else 1)
	var max_hp: float = _comp_max_hp()
	for c in [paul] + comps:
		if c != paul and c.level == 0:
			continue
		var x: float = roundf(c.pos.x)
		var y: float = roundf(c.pos.y)
		if on_fire:
			var fl := int(t * 12.0) % 2
			n.draw_rect(Rect2(x - 1 + fl, y - 31, 2, 1), C_CREAM)
			n.draw_rect(Rect2(x - 1, y - 30, 3, 2), C_GOLD)
			n.draw_rect(Rect2(x - 1, y - 28, 3, 1), C_FLAME)
			continue
		if c == paul:
			continue
		for gi in int(c.get("garment", 0)):
			# 頭上的小衣服：一件一個
			n.draw_rect(Rect2(x - 5 + gi * 4, y - 34, 3, 3), Color("e8d8b0"))
			n.draw_rect(Rect2(x - 4 + gi * 4, y - 33, 1, 1), Color("c87a5a"))
		if c.hp < max_hp and c.down <= 0.0:
			n.draw_rect(Rect2(x - 5, y - 29, 10, 2), Color("0b080d"))
			n.draw_rect(Rect2(x - 5, y - 29, roundf(10.0 * c.hp / max_hp), 2), C_HEAL if c.hp > max_hp * 0.35 else C_RED)
		if c.down > 0.0:
			var frac: float = 1.0 - c.down / D.companion_rules.down_seconds
			n.draw_rect(Rect2(x - 5, y - 12, 10, 2), Color("0b080d"))
			n.draw_rect(Rect2(x - 5, y - 12, roundf(10.0 * frac), 2), C_CREAM)
		if c.alert > 0.0:
			n.draw_rect(Rect2(x - 2, y - 34, 5, 7), C_CREAM)
			n.draw_rect(Rect2(x, y - 33, 1, 3), Color("c0392b"))
			n.draw_rect(Rect2(x, y - 29, 1, 1), Color("c0392b"))
		if c.sleep > 0.0:
			var zy: float = y - 32.0 - roundf((2.0 - c.sleep) * 3.0)
			n.draw_rect(Rect2(x + 4, zy, 3, 1), Color("9fb4e0"))
			n.draw_rect(Rect2(x + 5, zy + 1, 1, 1), Color("9fb4e0"))
			n.draw_rect(Rect2(x + 4, zy + 2, 3, 1), Color("9fb4e0"))


## 流派規則的畫面：實心顏色、不用半透明
func _draw_schools(n: Node2D) -> void:
	# 講道：敵人頭上的信息（青色小方塊）
	if _school_on("講道"):
		for e in enemies:
			var mc: int = int(e.get("msg", 0))
			if mc <= 0 or e.dead:
				continue
			var ex: float = roundf(e.pos.x) - mc * 2.0
			var ey: float = roundf(e.pos.y) - 20.0
			for i in mc:
				n.draw_rect(Rect2(ex + i * 4 - 1, ey - 1, 4, 4), Color("0c1e1c"))
				n.draw_rect(Rect2(ex + i * 4, ey, 2, 2), TAG_COL["講道"])
	# 被說服的敵人：頭上一個金色的光環
	for e in enemies:
		if float(e.get("ally", 0.0)) > 0.0 and not e.dead:
			var hx: float = roundf(e.pos.x)
			var hy: float = roundf(e.pos.y) - 21.0
			n.draw_rect(Rect2(hx - 4, hy, 9, 1), C_GOLD)
			n.draw_rect(Rect2(hx - 5, hy + 1, 1, 1), C_GOLD)
			n.draw_rect(Rect2(hx + 5, hy + 1, 1, 1), C_GOLD)
	# 門徒：小門徒（米白色的小人，快離開時閃爍）
	for m in minions:
		if m.life < 2.0 and int(t * 8.0) % 2 == 0:
			continue
		var mx: float = roundf(m.pos.x)
		var my: float = roundf(m.pos.y) - (3.0 if m.hop > 0.0 else 0.0)
		n.draw_rect(Rect2(mx - 3, my - 10, 7, 11), Color("2a1a10"))
		n.draw_rect(Rect2(mx - 2, my - 6, 5, 6), Color("e8dcc0"))
		n.draw_rect(Rect2(mx - 2, my - 6, 5, 1), Color("b89a6a"))
		n.draw_rect(Rect2(mx - 1, my - 9, 3, 3), Color("e0a878"))
		n.draw_rect(Rect2(mx - 1, my - 10, 3, 1), Color("5a3a20"))
		if m.hop > 0.0:
			n.draw_rect(Rect2(mx + 3, my - 7, 3, 1), C_CREAM)
	# 詩歌：全場的詩歌（金色的同心圈＋飛出去的音符）
	for sg in songs:
		var k: float = sg.t / 0.9
		var c0: Vector2 = sg.pos.round()
		for j in 3:
			var rr: float = 20.0 + (k * 260.0) - j * 26.0
			if rr > 0.0:
				n.draw_arc(c0, rr, 0.0, TAU, 64, [C_GOLD, C_CREAM, C_FLAME][j], 3.0 - j)
		for j in 10:
			var a := j * TAU / 10.0 + k * 1.5
			var np: Vector2 = (c0 + Vector2(cos(a), sin(a) * 0.8) * (16.0 + k * 140.0)).round()
			n.draw_rect(Rect2(np.x - 1, np.y - 1, 4, 3), Color("1a1008"))
			n.draw_rect(Rect2(np.x, np.y, 2, 2), C_GOLD)
			n.draw_rect(Rect2(np.x + 2, np.y - 5, 1, 6), C_GOLD)
			n.draw_rect(Rect2(np.x + 2, np.y - 5, 2, 1), C_GOLD)
	# 醫治：聖光（白綠色的十字光柱＋擴散的圈）
	for hl in holies:
		var k: float = hl.t / 0.7
		var c1: Vector2 = hl.pos.round()
		var w: float = 9.0 * (1.0 - k) + 2.0
		n.draw_rect(Rect2(c1.x - w / 2.0 - 1, c1.y - 110, w + 2, 110), Color("1a3a1e"))
		n.draw_rect(Rect2(c1.x - w / 2.0, c1.y - 110, w, 110), C_HEAL)
		n.draw_rect(Rect2(c1.x - 1, c1.y - 110, 2, 110), Color.WHITE)
		n.draw_rect(Rect2(c1.x - 14, c1.y - 30, 28, 4), C_HEAL)
		n.draw_rect(Rect2(c1.x - 14, c1.y - 29, 28, 2), Color.WHITE)
		n.draw_arc(c1, hl.r * minf(1.0, k * 2.0), 0.0, TAU, 48, C_HEAL, 3.0)
		n.draw_arc(c1, hl.r * minf(1.0, k * 2.0) - 4.0, 0.0, TAU, 48, Color.WHITE, 1.0)
	# 天降大雨：藍白色的雨線
	if not rains.is_empty():
		var v := _view_rect()
		for i in 70:
			var rx: float = v.position.x + _hash(i, 11) * v.size.x
			var ry: float = v.position.y + fmod(_hash(i, 5) * v.size.y + t * 260.0, v.size.y)
			n.draw_rect(Rect2(roundf(rx), roundf(ry), 1, 6), Color("8fd0ff"))
			n.draw_rect(Rect2(roundf(rx), roundf(ry) + 4, 1, 2), Color.WHITE)
	# 同行合擊的加倍：頭上一個橘色的小火焰
	for k in bond_buff:
		var bm := _member(k)
		if not bm.is_empty():
			var bx2: float = roundf(bm.pos.x)
			var by2: float = roundf(bm.pos.y) - 27.0 - (int(t * 8.0) % 2)
			n.draw_rect(Rect2(bx2 - 2, by2, 5, 4), Color("5a1a08"))
			n.draw_rect(Rect2(bx2 - 1, by2, 3, 3), C_FLAME)
			n.draw_rect(Rect2(bx2, by2 - 1, 1, 2), C_GOLD)
	# 已融合的流派：主角腳下兩色的光點互相繞（一組融合一對）
	var fi := 0
	for f in D.fusions:
		if not _fused(f.a, f.b):
			continue
		var fa: float = t * 2.2 + fi * 1.3
		for j in 2:
			var ang := fa + j * PI
			var op: Vector2 = (paul.pos + Vector2(cos(ang) * (12.0 + fi * 2.0), 2.0 + sin(ang) * 4.0)).round()
			n.draw_rect(Rect2(op.x - 1, op.y - 1, 4, 4), Color("140c10"))
			n.draw_rect(Rect2(op.x, op.y, 2, 2), TAG_COL.get([f.a, f.b][j], C_GOLD))
		fi += 1
	# 主角腳下：讚美（金）與恩膏（綠）的小量條
	var bars := []
	if _school_on("詩歌"):
		bars.append([praise / maxf(1.0, _sv("詩歌", "praise_need")), C_GOLD])
	if _school_on("醫治"):
		bars.append([anoint / maxf(1.0, _sv("醫治", "anoint_need")), C_HEAL])
	var px: float = roundf(paul.pos.x) - 8.0
	var py: float = roundf(paul.pos.y) + 9.0
	for i in bars.size():
		n.draw_rect(Rect2(px - 1, py + i * 4 - 1, 18, 4), Color("0b080d"))
		n.draw_rect(Rect2(px, py + i * 4, roundf(16.0 * clampf(bars[i][0], 0.0, 1.0)), 2), bars[i][1])


# ---------- 寶箱與進化 ----------
func _draw_finds(n: Node2D) -> void:
	for it in items:
		var col: Color = ITEM_INFO[it.kind][2]
		var ix: float = roundf(it.pos.x)
		var iy: float = roundf(it.pos.y) - roundf(absf(sin(t * 3.0 + ix)) * 2.0)
		n.draw_circle(Vector2(ix, iy - 3), 8.0 + sin(t * 4.0) * 1.0, Color(col, 0.18))
		match it.kind:
			"horn":   # 羊角號：彎彎的金色號角
				n.draw_rect(Rect2(ix - 5, iy - 3, 8, 3), Color("2a1a10"))
				n.draw_rect(Rect2(ix - 4, iy - 2, 6, 1), C_GOLD)
				n.draw_rect(Rect2(ix + 2, iy - 6, 3, 4), Color("2a1a10"))
				n.draw_rect(Rect2(ix + 3, iy - 5, 1, 3), C_GOLD)
			"calm":   # 平靜的水面：藍色的波紋
				n.draw_rect(Rect2(ix - 5, iy - 4, 11, 7), Color("1a2a4a"))
				n.draw_rect(Rect2(ix - 4, iy - 3, 9, 5), Color("6ab0e8"))
				n.draw_rect(Rect2(ix - 3, iy - 1, 7, 1), Color("e8f4ff"))
			"grapes": # 一串葡萄
				for k in 6:
					var gp := Vector2(ix - 3 + (k % 3) * 2 + (k / 3), iy - 4 + (k / 3) * 2 + (k / 5) * 2)
					n.draw_rect(Rect2(gp, Vector2(2, 2)), Color("8a3ac8") if k % 2 else Color("b06ad8"))
				n.draw_rect(Rect2(ix, iy - 6, 1, 2), Color("5a8a3a"))
	for hr in horn_rings:
		_dot_ring(n, hr.pos, hr.r, 0.8, Color(C_GOLD, 1.0 - hr.r / 420.0), 3.0, t, 2)
	if not merchant.is_empty():
		var mx: float = roundf(merchant.pos.x)
		var my: float = roundf(merchant.pos.y)
		n.draw_rect(Rect2(mx - 12, my - 16, 24, 4), Color("6a2a8a"))     # 紫色的布棚
		n.draw_rect(Rect2(mx - 12, my - 12, 2, 12), Color("4a3020"))
		n.draw_rect(Rect2(mx + 10, my - 12, 2, 12), Color("4a3020"))
		n.draw_rect(Rect2(mx - 10, my - 4, 20, 4), Color("8a6a3a"))       # 攤子的桌面
		n.draw_rect(Rect2(mx - 8, my - 6, 6, 2), Color("9a4ac8"))
		n.draw_rect(Rect2(mx + 1, my - 6, 6, 2), Color("c8a0e8"))
		if int(t * 3.0) % 2 == 0:
			n.draw_rect(Rect2(mx - 1, my - 24, 3, 5), C_GOLD)              # 頭上的記號
	if scroll.has("pos") and not scroll.has("got"):
		var sx: float = roundf(scroll.pos.x)
		var sy: float = roundf(scroll.pos.y) - roundf(absf(sin(t * 2.0)) * 2.0)
		n.draw_circle(Vector2(sx, sy - 3), 10.0, Color(1, 0.95, 0.7, 0.15 + 0.08 * sin(t * 3.0)))
		n.draw_rect(Rect2(sx - 5, sy - 5, 11, 6), Color("4a3020"))
		n.draw_rect(Rect2(sx - 4, sy - 4, 9, 4), Color("e8dcc0"))
		n.draw_rect(Rect2(sx - 6, sy - 5, 2, 6), Color("8a6a3a"))
		n.draw_rect(Rect2(sx + 5, sy - 5, 2, 6), Color("8a6a3a"))
		# 離得不遠時，畫面邊上有一個小金點指著它的方向
		var d: Vector2 = scroll.pos - paul.pos
		if d.length() < 260.0 and d.length() > 90.0:
			var tip: Vector2 = paul.pos + d.normalized() * 34.0 + Vector2(0, -8)
			n.draw_rect(Rect2(tip.round() - Vector2(1, 1), Vector2(3, 3)), Color(C_GOLD, 0.7 + 0.3 * sin(t * 5.0)))


## ---------- 局內撿到的東西：稀有道具、路過的商人、失落的書卷 ----------
const ITEM_INFO := {"horn": ["耶利哥的號角", "書 6:20", Color("ffd75e")], "calm": ["平靜風浪", "可 4:39", Color("9fd8ff")], "grapes": ["以實各的葡萄", "民 13:23", Color("b06ad8")]}


func _update_finds(dt: float) -> void:
	for it in items:
		if paul.pos.distance_to(it.pos) < 11.0:
			it.got = true
			_use_item(str(it.kind))
	items = items.filter(func(it): return not it.get("got", false))
	for hr in horn_rings:
		hr.r += 420.0 * dt
	horn_rings = horn_rings.filter(func(hr): return hr.r < 420.0)
	if calm_t > 0.0:
		calm_t -= dt
		for e in enemies:
			if not e.dead:
				e.stun = maxf(e.stun, 0.1 if e.get("boss", false) else 0.2)
	# 路過的商人：每局一次，開局 2 分半左右出現在附近
	if not merchant_done and merchant.is_empty() and t - t_start > 150.0 and (boss == null or boss.get("mid", false)):
		var a := randf() * TAU
		merchant = {"pos": paul.pos + Vector2(cos(a), sin(a) * 0.7) * 110.0, "t": 40.0}
		ui.show_banner("路邊有人擺了賣紫色布的攤子（徒 16:14）：帶著這局撿到的餅去看看", 2.5)
	if not merchant.is_empty():
		merchant.t -= dt
		if paul.pos.distance_to(merchant.pos) < 16.0 and not choosing and not chest_open:
			merchant_done = true
			_open_merchant()
			merchant = {}
		elif merchant.t <= 0.0:
			merchant_done = true
			merchant = {}
	# 失落的書卷：每座城藏一卷（撿過的城就不再出現）
	if scroll.is_empty() and not Save.data.get("scrolls", []).has(stage.id) and t - t_start > 20.0 and not scroll.has("got"):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("scroll-" + stage.id)
		var a2 := rng.randf() * TAU
		scroll = {"pos": Vector2(cos(a2), sin(a2) * 0.8) * rng.randf_range(420.0, 560.0)}
	if scroll.has("pos") and not scroll.has("got") and paul.pos.distance_to(scroll.pos) < 12.0:
		scroll.got = true
		var got: Array = Save.data.get("scrolls", [])
		got.append(stage.id)
		Save.data.scrolls = got
		Save.data.witness = int(Save.data.witness) + 30
		Save.save_profile()
		_ring_pop(scroll.pos + Vector2(0, -6), C_GOLD, 40.0)
		Sfx.play("holy", 0.0)
		ui.show_banner("找到失落的書卷！（%d／%d）見證 +30\n營地的書房可以讀" % [got.size(), _stage_list().size()], 3.0)


## 營地祭壇求來的祝福：出發時套用，然後用掉
func _apply_blessing() -> void:
	bless = "" if smoke else str(Save.data.get("blessing", ""))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bless="):
			bless = a.substr(8)   # 測試用：--bless=xp
	if bless == "":
		return
	if not smoke:
		Save.data.blessing = ""
		Save.save_profile()
	match bless:
		"lv":
			_set_level(pa, maxi(2, int(pa.level)))
		"meter":
			meter = maxf(meter, 0.5)
		"grapes":
			bless_grapes = true
		"guard":
			guard = maxi(guard, 2)
	ui.show_banner("祭壇的祝福：" + {"lv": "得力", "meter": "同心", "grapes": "葡萄", "xp": "智慧", "relic": "看顧", "guard": "盾牌"}.get(bless, bless), 2.0)


func _use_item(kind: String) -> void:
	var info: Array = ITEM_INFO[kind]
	ui.show_banner("%s（%s）" % [info[0], info[1]], 1.8)
	if smoke:
		print("ITEM ", kind)
	_fxc("道具:" + kind)
	match kind:
		"horn":
			# 耶利哥的號角：一圈金色的衝擊波，畫面上的小怪全部倒下，菁英和 Boss 掉一大截血
			horn_rings.append({"pos": paul.pos, "r": 0.0})
			shake = 0.5
			Sfx.play("burst", 0.0)
			for e in enemies.duplicate():
				if e.dead or float(e.get("ally", 0.0)) > 0.0:
					continue
				if e.get("boss", false) or e.get("elite", false):
					_hurt(e, float(e.get("max_hp", e.hp)) * (0.08 if e.get("boss", false) else 0.4), paul.pos)
				elif e.pos.distance_to(paul.pos) < 420.0:
					_hurt(e, 99999.0, paul.pos)
		"calm":
			# 平靜風浪：所有敵人停住 4 秒
			calm_t = 4.0
			ui.do_flash(0.3)
			Sfx.play("holy", 0.0)
		"grapes":
			# 以實各的葡萄：全隊回 40% 血
			_heal_paul(float(D.paul.hp) * 0.4)
			for c in comps:
				if c.level > 0 and c.down <= 0.0:
					_heal_comp(c, _comp_max_hp() * 0.4)
			_ring_pop(paul.pos + Vector2(0, -6), C_HEAL, 40.0)


## 商人：用這局撿到的餅買東西（買了就從帶回營地的餅裡扣）
func _open_merchant() -> void:
	if smoke:
		print("MERCHANT bread=%d" % run_bread)
	choosing = true
	joy.on = false
	ui.joy.on = false
	pending_cards = []
	for o in [["shop_heal", "醫治", "全隊回滿血", 15], ["shop_pick", "多選一張升級卡", "馬上再選一次升級", 25],
			["shop_reroll", "重抽 +2", "這一局多兩次重抽", 10], ["shop_leave", "看看就好", "不買，繼續趕路", 0]]:
		var ok: bool = run_bread >= int(o[3])
		pending_cards.append({"kind": o[0], "key": "", "title": o[1] + ("　餅 %d" % o[3] if o[3] > 0 else ""), "tag": "商人",
			"desc": o[2] + ("" if ok else "\n（這局的餅不夠：現在 %d）" % run_bread), "cost": int(o[3])})
	Sfx.play("chest", 0.0)
	ui.show_cards(pending_cards, Time.get_ticks_msec() / 1000.0, _card_delay(), 0, "賣紫色布的攤子（徒 16:14）", "這局撿到的餅：%d 個" % run_bread)


func _buy(card: Dictionary) -> void:
	var cost := int(card.get("cost", 0))
	if run_bread < cost:
		ui.show_banner("餅不夠，下次再來", 1.4)
		return
	run_bread -= cost
	match card.kind:
		"shop_heal":
			paul.hp = _hp_cap()
			for c in comps:
				if c.level > 0:
					c.down = 0.0
					c.hp = _comp_max_hp()
			_ring_pop(paul.pos + Vector2(0, -6), C_HEAL, 40.0)
		"shop_pick":
			xp += xp_need   # 下一格就升級：多選一張
		"shop_reroll":
			rerolls_left += 2


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
		if trials.has("poor"):
			n = maxi(1, n - 1)   # 信心等級：貧窮
		if bless == "relic" and story:
			n += 1   # 祭壇的「看顧」：劇情模式沒有聖物，改成多一項
			bless = ""
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
## ---------- 中途存檔 ----------
## 存的是「構築」：時間、等級、隊伍、果子、軍裝、聖物、流派、連結、任務。不存敵人與子彈，繼續時重新生怪（像 Brotato 在波次之間存）
const SAVE_VARS := ["t", "kills", "xp", "level", "xp_need", "meter", "run_lights", "run_bread", "xp_acc", "fruits", "armor",
	"run_elites", "run_fevers", "run_evolutions", "tasks_done", "task_witness", "rerolls_left", "t_start", "journey_step",
	"chariot_done", "epistles", "killed_types", "link_count", "combo_best", "guard", "grace_dmg", "grace_spd", "mids_done",
	"boss_spawned", "endless_boss_t", "endless_bosses", "run_resonances", "event_t", "events_done", "enemy_hp_bonus", "move_bonus",
	"run_chests", "run_midboss", "school_mods", "school_cards", "praise", "anoint", "run_converts", "run_minions", "run_songs",
	"run_holies", "run_shocks", "bonds_seen", "run_bonds", "loaves_n", "run_relics", "seek_t", "seek_used", "run_saved",
	"run_seek_spawned", "pressure", "life_avg", "persec_t", "fz_count", "scatter_by", "blind_state", "blind_r", "hz_t",
	"founded_now", "someone_down", "full_party", "merchant_done", "banishes_left", "banished"]
var resuming := {}
var autosave_t := 20.0
var save_test := false   # 測試用：--save_test 讓機器人模擬也寫存檔


func _autosave() -> void:
	if over or won or choosing or chest_open or relic_pending or (smoke and not save_test) or pa.is_empty() or t - t_start < 5.0:
		return
	Save.write_run_save(_snapshot())


func _snapshot() -> Dictionary:
	var d := {"ver": 1, "run_config": Save.run_config.duplicate(true), "leader": leader, "hp": paul.hp,
		"where": (chapter.get("title", stage.name) if story else stage.name), "date": Time.get_datetime_string_from_system(), "vars": {}}
	for k in SAVE_VARS:
		d.vars[k] = get(k)
	if boss != null and not boss.dead:
		# Boss 還活著：繼續時重新出現（中途 Boss 也是）
		if boss.get("mid", false):
			d.vars.mids_done = maxi(0, mids_done - 1)
		else:
			d.vars.boss_spawned = false
	d.comps = []
	for c in comps:
		if c.level > 0:
			d.comps.append({"key": c.key, "level": int(c.level), "branch": int(c.get("branch", -1)), "anoints": c.get("anoints", []).duplicate(), "hp": float(c.hp)})
	d.pa = {"level": int(pa.level), "branch": int(pa.get("branch", -1)), "anoints": pa.get("anoints", []).duplicate()}
	d.evolved = evolved.keys()
	d.relics = relics.keys()
	d.links = []
	for L in links:
		d.links.append({"src": L.src.key if L.src is Dictionary and not L.src.is_empty() else "", "dst": L.dst.key, "kind": L.kind, "lv": int(L.get("lv", 1))})
	d.run_tasks = run_tasks.duplicate(true)
	d.followers = followers.duplicate(true)
	return d


func _apply_resume(r: Dictionary) -> void:
	for id in r.get("relics", []):
		_take_relic(id)   # 先拿聖物（亞倫的杖會動到果子，下面再照存檔蓋回去）
	for k in r.vars:
		set(k, r.vars[k])
	for cd in r.comps:
		var c: Dictionary = by_key.get(cd.key, {})
		if c.is_empty():
			continue
		if int(c.level) == 0:
			_recruit(c)
		c.branch = int(cd.branch)
		c.anoints = Array(cd.anoints)
		_set_level(c, int(cd.level))
		c.hp = float(cd.hp)
	pa.branch = int(r.pa.branch)
	pa.anoints = Array(r.pa.anoints)
	_set_level(pa, int(r.pa.level))
	for k in r.evolved:
		var ev := _evo_of(str(k))
		if not ev.is_empty() and not evolved.has(k) and not _who(str(k)).is_empty():
			_evolve(ev)
	for L in r.links:
		var src := _who(str(L.src)) if str(L.src) != "" else {}
		var dst := _who(str(L.dst))
		if not dst.is_empty():
			links.append({"src": src if not src.is_empty() else pa, "dst": dst, "kind": L.kind, "cd": 0.0, "lv": int(L.lv)})
	run_tasks = r.run_tasks
	followers = r.followers
	paul.hp = minf(float(r.hp), _hp_cap())
	paul.inv = 2.0   # 剛回來：先給 2 秒喘口氣
	_update_sets()
	_refresh_all_stats()
	_update_synergy()
	_update_schools()
	_refresh_build_text()
	ui.show_banner("繼續上一局：%s　%d:%02d" % [str(r.get("where", "")), int(t) / 60, int(t) % 60], 2.5)
	if smoke:
		print("RESUME t=%.0f Lv=%d hp=%.0f party=%s fruits=%s armor=%s links=%d schools=%s" % [t, level, paul.hp, comps.filter(func(c): return c.level > 0).map(func(c): return "%s%d" % [c.key, c.level]), fruits, armor, links.size(), school_tier])


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
	if evo.has("onhit"):
		c.onhit = evo.onhit   # 進化帶的命中效果（光柱、雷擊、爆裂）
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
	if relic_pending:
		relic_pending = false
		if relics.size() < int(D.relic_rules.max) and not story:
			_offer_relic()
			if choosing:
				return
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
	_update_boss_waves(dt)
	_update_boss_extras(b, dt)
	var B: Dictionary = D.boss
	var phase2: bool = b.hp < b.max_hp * B.phase2_at
	b.flash = maxf(0.0, b.flash - dt)
	b.knock = Vector2.ZERO
	match b.state:
		"move":
			b.pos += (paul.pos - b.pos).normalized() * B.speed * (1.6 if phase2 else 1.0) * dt
			b.timer -= dt
			if phase2 and not b.get("p2", false):
				b.p2 = true
				b.pattern_i = 0
				ui.show_banner("%s更猛烈了！" % B.name, 1.6)
				_ring_pop(b.pos, C_RED, 60.0)
				shake = 0.4
				Sfx.play("roar", 0.0)
			if float(b.get("vortex_t", 0.0)) > 0.0:
				# 漩渦：把主角往 Boss 拉過去，結束時在 Boss 身邊重重砸下
				b.vortex_t -= dt
				var pullv: Vector2 = (b.pos - paul.pos)
				if pullv.length() > 20.0:
					paul.pos += pullv.normalized() * 34.0 * dt
				if b.vortex_t <= 0.0:
					tele = [{"kind": "circle", "c": b.pos, "r": 46.0, "dmg": float(B.slam.damage)}]
					_resolve_tele()
					tele = []
					_ring_pop(b.pos, C_VL, 46.0)
				return
			if b.timer <= 0.0:
				var order: Array = B.get("order2", B.get("order", ["sweep", "slam", "grid", "hunt"])) if phase2 else B.get("order", ["sweep", "slam", "grid", "hunt"])
				b.pattern = order[b.pattern_i % order.size()]
				b.pattern_i += 1
				tele = _make_tele(b)
				Sfx.play("warn", 0.0)
				if BOSS_SPECIAL.has(b.pattern):
					_ring_pop(b.pos, C_RED, 34.0)   # 特殊招式：Boss 身上先亮一圈，提醒要出招了
				b.state = "warn"
				b.timer = B.warn * (0.7 if phase2 else 1.0) * (1.4 if calling == "prophet" else 1.0)
		"warn":
			b.timer -= dt
			if b.timer <= 0.0:
				for sh in tele:
					if sh.get("rush", false):
						b.pos = sh.b   # 騷亂衝過去
						_ring_pop(b.pos, C_RED, 30.0)
				_resolve_tele()
				tele = []
				if b.pattern == "charge" and int(b.get("charges", 0)) < 2:
					# 連續衝撞：衝完馬上再瞄準一次（共三次）
					b.charges = int(b.get("charges", 0)) + 1
					var dr2: Vector2 = (paul.pos - b.pos).normalized()
					tele = [{"kind": "line", "a": b.pos, "b": b.pos + dr2 * 220.0, "w": 22.0, "dmg": float(B.sweep.damage), "rush": true}]
					b.timer = 0.5 if phase2 else 0.6
					return
				b.charges = 0
				if BOSS_SPECIAL.has(b.pattern):
					_boss_special(b, phase2)
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
		_damage_paul(B.touch_damage, false, "boss")


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
		"chains":
			# 腓立比：捆鎖從 Boss 往六個方向甩出去
			for i in 6:
				var dd := Vector2.RIGHT.rotated(i * TAU / 6.0 + randf() * 0.5)
				out.append({"kind": "line", "a": b.pos, "b": b.pos + dd * 260.0, "w": 10.0, "dmg": float(B.sweep.damage)})
		"charge":
			# 連續衝撞：朝主角衝三次，每次重新瞄準
			var dc: Vector2 = (paul.pos - b.pos).normalized()
			out.append({"kind": "line", "a": b.pos, "b": b.pos + dc * 220.0, "w": 22.0, "dmg": float(B.sweep.damage), "rush": true})
		"rush":
			# 帖撒羅尼迦：騷亂朝主角直衝過去
			var dr: Vector2 = (paul.pos - b.pos).normalized()
			out.append({"kind": "line", "a": b.pos, "b": b.pos + dr * 300.0, "w": 22.0, "dmg": float(B.sweep.damage), "rush": true})
		"ring":
			# 雅典：一圈偶像圍住主角，站在中間或跑出去
			for i in 10:
				var a := i * TAU / 10.0
				out.append({"kind": "circle", "c": paul.pos + Vector2(cos(a), sin(a) * 0.8) * 55.0, "r": 14.0, "dmg": float(B.hunt.damage)})
		"cross":
			# 哥林多：十字分裂，從主角所在的位置切成四塊
			var vv := _view_rect().grow(40.0)
			out.append({"kind": "line", "a": Vector2(vv.position.x, paul.pos.y), "b": Vector2(vv.end.x, paul.pos.y), "w": 12.0, "dmg": float(B.grid.damage)})
			out.append({"kind": "line", "a": Vector2(paul.pos.x, vv.position.y), "b": Vector2(paul.pos.x, vv.end.y), "w": 12.0, "dmg": float(B.grid.damage)})
		"spiral":
			# 以弗所：火從主角身邊捲成螺旋往外燒
			for i in 9:
				var a := i * 0.9 + randf()
				out.append({"kind": "circle", "c": paul.pos + Vector2(cos(a), sin(a) * 0.8) * (8.0 + i * 11.0), "r": 13.0, "dmg": float(B.hunt.damage)})
		"oath":
			# 耶路撒冷：四十人的誓約，主角四周一圈加正中間
			out.append({"kind": "circle", "c": paul.pos, "r": 18.0, "dmg": float(B.slam.damage)})
			for i in 4:
				var a := PI / 4.0 + i * PI / 2.0
				out.append({"kind": "circle", "c": paul.pos + Vector2(cos(a), sin(a) * 0.8) * 40.0, "r": 18.0, "dmg": float(B.slam.damage)})
		"tide":
			# 米利大：一道道海浪直直打過來，只有浪與浪之間是安全的
			var vt := _view_rect().grow(40.0)
			for i in 5:
				var x: float = paul.pos.x + (i - 2) * 46.0 + randf_range(-6, 6)
				out.append({"kind": "line", "a": Vector2(x, vt.position.y), "b": Vector2(x, vt.end.y), "w": 18.0, "dmg": float(B.grid.damage)})
		"legions":
			# 羅馬：三排軍團橫著推過來
			var vl := _view_rect().grow(40.0)
			for i in 3:
				var y: float = paul.pos.y + (i - 1) * 40.0 + randf_range(-6, 6)
				out.append({"kind": "line", "a": Vector2(vl.position.x, y), "b": Vector2(vl.end.x, y), "w": 14.0, "dmg": float(B.grid.damage)})
		"stars":
			# 大紅龍：尾巴拖下天上的星辰（啟 12:4），落在主角附近一大片
			var ST: Dictionary = B.get("stars", {"damage": 16, "count": 8, "radius": 18})
			for i in int(ST.count):
				var a := randf() * TAU
				out.append({"kind": "circle", "c": paul.pos + Vector2(cos(a), sin(a) * 0.8) * (0.0 if i == 0 else randf_range(25.0, 95.0)),
					"r": float(ST.radius), "dmg": float(ST.damage), "star": true})
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


## 不是地上警示的招式：彈幕、扇形連射、追著主角落下、黑暗的水窪、留缺口的衝擊波、漩渦
func _boss_special(b: Dictionary, phase2: bool) -> void:
	var B: Dictionary = D.boss
	var bd: float = float(B.sweep.damage)
	match b.pattern:
		"barrage":
			# 彈幕：從 Boss 往四面八方射出一圈一圈的黑暗，每一圈錯開一點角度
			for w in (4 if phase2 else 3):
				delayed.append({"t": w * 0.45, "fn": func():
					if b.get("dead", false):
						return
					var n := 14
					for i in n:
						var a := i * TAU / n + w * 0.22
						shots.append({"pos": b.pos + Vector2(0, -8), "vel": Vector2.from_angle(a) * 62.0, "life": 5.0, "dmg": bd * 0.45, "boss": true})
					Sfx.play("warn", 0.1)})
		"volley":
			# 扇形連射：朝主角射三輪，每輪五發
			for w in (4 if phase2 else 3):
				delayed.append({"t": w * 0.35, "fn": func():
					if b.get("dead", false):
						return
					var base_a: float = (paul.pos - b.pos).angle()
					for i in 5:
						shots.append({"pos": b.pos + Vector2(0, -8), "vel": Vector2.from_angle(base_a + (i - 2) * 0.22) * 105.0, "life": 4.0, "dmg": bd * 0.4, "boss": true})})
		"follow":
			# 追著主角落下：一個接一個落在主角剛剛站的地方，要一直走
			for i in (8 if phase2 else 6):
				delayed.append({"t": i * 0.28, "fn": func():
					if not b.get("dead", false):
						star_falls.append({"pos": paul.pos, "t": 0.6, "max": 0.6, "r": 16.0, "dmg": float(B.hunt.damage), "pierce": true, "src": "boss"})})
		"pools":
			# 黑暗的水窪：主角附近留下幾片黑暗，踩在裡面會一直受傷，過一陣子才散
			for i in (5 if phase2 else 4):
				var a := randf() * TAU
				spots.append({"kind": "dark", "pos": paul.pos + (Vector2.ZERO if i == 0 else Vector2(cos(a), sin(a) * 0.8) * randf_range(35.0, 80.0)), "life": 6.0, "tick": 0.0, "r": 22.0, "dmg": bd * 0.25})
		"wave":
			# 衝擊波：從 Boss 擴散出去的一圈，只有一個缺口可以穿過
			var gap: float = (paul.pos - b.pos).angle() + randf_range(-1.6, 1.6)
			boss_waves.append({"pos": b.pos, "r": 12.0, "gap": gap, "gap_w": 0.55, "dmg": bd, "hit": false})
			if phase2:
				var gap2 := gap + PI + randf_range(-0.8, 0.8)
				delayed.append({"t": 0.8, "fn": func(): boss_waves.append({"pos": b.pos, "r": 12.0, "gap": gap2, "gap_w": 0.55, "dmg": bd, "hit": false})})
		"vortex":
			b.vortex_t = 2.4
			ui.show_banner("被拉過去了！往外走", 1.2)
		"accuse":
			# 五旬節・公會的恐嚇：長老從四周一個接一個指著你（一道一道的線依序落下）
			for i in (5 if phase2 else 4):
				var a := randf() * TAU
				var from: Vector2 = paul.pos + Vector2.from_angle(a) * 150.0
				boss_lines.append({"a": from, "b": from + (paul.pos - from).normalized() * 300.0, "w": 14.0, "t": 0.9 + i * 0.45, "max": 0.9 + i * 0.45, "dmg": bd * 0.8})
		"stones":
			# 司提反・硬著頸項的人：一圈一圈的石頭往你身上收過來，要趁早跑出去
			var center: Vector2 = paul.pos
			delayed.append({"t": 1.0, "fn": func(): star_falls.append({"pos": center, "t": 0.7, "max": 0.7, "r": 22.0, "dmg": float(B.hunt.damage), "pierce": true, "src": "boss"})})
			for k in 3:
				for i in 16:
					var a := i * TAU / 16.0 + k * 0.2
					var at: Vector2 = center + Vector2(cos(a), sin(a) * 0.8) * (90.0 - k * 30.0)
					delayed.append({"t": k * 0.45, "fn": func(): star_falls.append({"pos": at, "t": 0.7, "max": 0.7, "r": 13.0, "dmg": float(B.hunt.damage), "pierce": true, "src": "boss", "look": "stone"})})
		"bait":
			# 撒馬利亞・貪財的心：地上冒出亮晶晶的錢幣，撿了會爆開（不要貪）
			for i in (7 if phase2 else 5):
				var a := randf() * TAU
				spots.append({"kind": "bait", "pos": paul.pos + Vector2(cos(a), sin(a) * 0.8) * randf_range(20.0, 75.0), "life": 9.0, "tick": 0.0, "r": 9.0, "dmg": bd * 0.9})
			ui.show_banner("地上的錢不要撿！", 1.2)
		"searchlight":
			# 大馬色・晝夜看守的城門：一道探照的光繞著城門轉，碰到就被抓
			b.search_t = 3.6 if phase2 else 3.0
			b.search_ang = (paul.pos - b.pos).angle() - 1.2
			b.search_dir = 1.0 if randf() < 0.5 else -1.0
		"squeeze":
			# 約帕・中間隔斷的牆：兩道牆從左右夾過來，各有一個門可以穿過
			var v := _view_rect()
			for sd in [-1.0, 1.0]:
				boss_walls.append({"x": v.position.x - 10.0 if sd > 0.0 else v.end.x + 10.0, "dir": sd, "gap_y": paul.pos.y + randf_range(-50, 50), "gap_h": 26.0,
					"stop": paul.pos.x + (40.0 if sd < 0.0 else -40.0), "dmg": bd, "hit": false, "top": v.position.y - 20.0, "bot": v.end.y + 20.0})
		"stampede":
			# 安提阿・路司得的群眾：群眾從四面八方一起湧上來
			for i in 16:
				var a := i * TAU / 16.0
				_spawn_one("riot", paul.pos + Vector2(cos(a), sin(a) * 0.8) * 130.0)
			ui.show_banner("群眾湧上來了！", 1.0)
		"tether":
			# 腓立比・捆鎖：主角被鎖在一個點上，走太遠會被拉回來、受傷
			tether = {"pos": paul.pos, "t": 3.5 if phase2 else 3.0, "r": 46.0, "dmg": bd * 0.35, "tick": 0.0}
			ui.show_banner("被捆鎖綁住了！", 1.0)
		"idols":
			# 雅典・滿城偶像：四周立起會射擊的偶像
			for i in (5 if phase2 else 4):
				var a := i * TAU / (5.0 if phase2 else 4.0) + randf()
				_spawn_one("idol", paul.pos + Vector2(cos(a), sin(a) * 0.8) * 85.0)
		"rumor":
			# 府城・謠言：一傳二、二傳四，越傳越多，還會傳到你要去的地方（照你走的方向往前落）
			var mem := {"p": paul.pos}
			for k in (4 if phase2 else 3):
				delayed.append({"t": k * 0.55, "fn": func():
					var ahead: Vector2 = paul.pos + (paul.pos - mem.p) * 1.2
					mem.p = paul.pos
					for i in int(pow(2, k)):
						var jit := Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(10.0, 14.0 + k * 16.0)
						star_falls.append({"pos": ahead + jit, "t": 0.65, "max": 0.65, "r": 15.0, "dmg": float(B.hunt.damage), "pierce": true, "src": "boss"})})


func _update_boss_extras(b: Dictionary, dt: float) -> void:
	for ln in boss_lines:
		ln.t -= dt
		if ln.t <= 0.0 and not ln.get("done", false):
			ln.done = true
			_hit_shape({"kind": "line", "a": ln.a, "b": ln.b, "w": ln.w, "dmg": ln.dmg})
			shake = maxf(shake, 0.15)
	boss_lines = boss_lines.filter(func(ln): return not ln.get("done", false))
	for w in boss_walls:
		var prev: float = w.x
		w.x += w.dir * 75.0 * dt
		var crossed: bool = (prev - paul.pos.x) * (w.x - paul.pos.x) <= 0.0
		if crossed and not w.hit and absf(paul.pos.y - w.gap_y) > w.gap_h / 2.0 and paul.inv <= 0.0:
			w.hit = true
			_damage_paul(w.dmg, false, "boss")
			paul.pos.x += w.dir * 14.0   # 被牆推開
	boss_walls = boss_walls.filter(func(w): return (w.x < w.stop) if w.dir > 0.0 else (w.x > w.stop))
	if not tether.is_empty():
		tether.t -= dt
		var off: Vector2 = paul.pos - tether.pos
		if off.length() > tether.r:
			paul.pos = tether.pos + off.normalized() * tether.r   # 鎖鏈拉住
			tether.tick -= dt
			if tether.tick <= 0.0 and paul.inv <= 0.0:
				tether.tick = 0.6
				_damage_paul(tether.dmg, false, "boss")
		if tether.t <= 0.0:
			tether = {}
	if float(b.get("search_t", 0.0)) > 0.0:
		b.search_t -= dt
		b.search_ang += b.search_dir * 1.5 * dt
		var tip: Vector2 = b.pos + Vector2.from_angle(b.search_ang) * 280.0
		var q := Geometry2D.get_closest_point_to_segment(paul.pos, b.pos, tip)
		if paul.pos.distance_to(q) < 12.0 and paul.inv <= 0.0 and t >= float(b.get("search_cd", 0.0)):
			b.search_cd = t + 0.5
			_damage_paul(float(D.boss.sweep.damage) * 0.5, false, "boss")


func _update_boss_waves(dt: float) -> void:
	for w in boss_waves:
		var prev: float = w.r
		w.r += 95.0 * dt
		var d: float = paul.pos.distance_to(w.pos)
		if not w.hit and d >= prev - 4.0 and d <= w.r + 4.0 and paul.inv <= 0.0:
			var ang: float = absf(angle_difference((paul.pos - w.pos).angle(), w.gap))
			if ang > w.gap_w:
				w.hit = true
				_damage_paul(w.dmg, false, "boss")
	boss_waves = boss_waves.filter(func(w): return w.r < 320.0)


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


func _hit_shape(sh: Dictionary) -> void:
	hits.append({"sh": sh, "t": 0.0})
	if _in_shape(sh, paul.pos + Vector2(0, -6)) and paul.inv <= 0.0:
		_damage_paul(sh.dmg, false, "boss")
	for c in comps:
		if c.level > 0 and c.down <= 0.0 and _in_shape(sh, c.pos + Vector2(0, -6)) and fever <= 0.0:
			c.hurt_cd = 0.0
			_damage_companion(c, sh.dmg)


func _resolve_tele() -> void:
	shake = 0.3
	for sh in tele:
		hits.append({"sh": sh, "t": 0.0})
		if _in_shape(sh, paul.pos + Vector2(0, -6)) and paul.inv <= 0.0:
			_damage_paul(sh.dmg, false, "boss")
		for c in comps:
			if c.level > 0 and c.down <= 0.0 and _in_shape(sh, c.pos + Vector2(0, -6)):
				if fever <= 0.0:
					c.hurt_cd = 0.0
					_damage_companion(c, sh.dmg)
				var center: Vector2 = sh.c if sh.kind == "circle" else Geometry2D.get_closest_point_to_segment(c.pos, sh.a, sh.b)
				c.vel += (c.pos - center).normalized() * 80.0


## 每局結束寫一筆紀錄到本機，之後拿來看哪個流派太強或太弱
func _record_run() -> void:
	if not smoke or save_test:
		Save.clear_run_save()   # 這一局結束了：不能再「繼續」
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
		"task_witness": task_witness, "lights": run_lights, "bread": int(run_bread * (1.0 + prov_bread)),
		"resonances": run_resonances, "midbosses": run_midboss, "chests": run_chests, "links": link_count,
		"combo": combo_best, "party_size": _party_count(), "converts": run_converts, "minions": run_minions, "songs": run_songs, "holies": run_holies, "shocks": run_shocks, "bonds": run_bonds, "relics": run_relics, "saved": run_saved, "school": school_tier.values().max() if not school_tier.is_empty() else 0, "endless": endless, "sets": sets_on.size(), "leader": leader,
		"faith": faith, "stage": stage.id, "daily": str(Save.run_config.get("daily", "")),
		"seen": {"enemies": killed_types.keys().map(func(k): return k.replace("pride_small", "pride")), "evos": evolved.keys(), "fruits": fruits.keys(), "armor": armor.keys(), "relics": relics.keys()}, "no_down": t - t_start >= 210.0 and not someone_down, "full_party": full_party, "party": party})
	if smoke:
		print("WITNESS +%d bread +%d saved=%d kills=%d" % [res.witness, res.bread, run_saved, kills])
	var lines := [["帶回見證 +%d　（共 %d）　餅 +%d" % [res.witness, Save.data.witness, res.bread], 15, C_SKY]]
	if res.get("daily_bonus", false):
		lines.append(["今日挑戰通關！見證與餅 ×1.5", 13, C_GOLD])
	if faith > 0:
		lines.append(["信心等級 %d：見證與餅 +%d%%%s" % [faith, roundi(faith * float(Save.meta.faith.reward_per_level) * 100), ("　下一級已開放" if won and faith < int(Save.meta.faith.max) else "")], 11, C_GOLD])
	for a in res.achievements:
		var txt: String = "見證錄：" + a.name
		if a.has("unlock"):
			txt += "　→　%s 加入名單！" % _comp_name(a.unlock)
		lines.append([txt, 13, C_GOLD])
	if not fz_count.is_empty():
		var fl := []
		for k in fz_count:
			fl.append("%s ×%d" % [k, int(fz_count[k])])
		lines.append(["融合發動：" + "、".join(fl), 12, C_GOLD])
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
	if story and founded_now and stage.id in ["stephen", "damascus", "rome", "patmos", "fucheng"] and not Save.data.get("cuts_seen", []).has(stage.id):
		Save.data.pending_cut = stage.id   # 回營地前先播這一章結束的過場（title.gd 的 CUTS）
	if story and leader != "paul" and not Save.is_unlocked("leader_" + leader) and D.leaders.any(func(L): return L.key == leader):
		Save.data.unlocked.append("leader_" + leader)   # 劇情的主角，自由模式也能選
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
		[stage.get("win_title", "%s　教會建立！" % stage.get("church", stage.name)) if founded_now else "%s　通關" % stage.name, 26, C_GOLD],
		["這一趟有 %d 個人信主" % run_saved, 13, C_HEAL] if run_saved > 0 else ["", 4, C_CREAM],
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
	if founded_now and not Save.data.get("story_seen", []).has("out_" + stage.id) and not stage.get("talk_out", []).is_empty():
		_start_talk("out")
		await ui.dialogue_done
	var share := "我在《宣教之路》%s%s！\n「%s」（%s）\n一起來玩：%s" % [stage.name, "建立了教會" if founded_now else "通關了", D.boss.win_text, D.boss.win_ref, SHARE_URL]
	ui.show_game_over(lines + _finish_run(), "再走一次", true, stage.get("story", ""), share)


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
	] + summary, "再出發", false, stage.get("story", ""),
		"我在《宣教之路》的%s撐了 %d:%02d，驅散了 %d 個懼怕與謊言。\n「打倒了，也不至死亡。」（林後 4:9）\n一起來玩：%s" % [stage.name, s / 60, s % 60, kills, SHARE_URL])


# ---------- 自動測試 ----------
## 測試用：每 5 格看一次場上的狀態，結束時印出「效果有沒有真的發生」
var fx_stat := {}
var only_keys: Array = []
var god_mode := false     # 測試用
var boss_waves: Array = []  # Boss 的衝擊波圈（留一個缺口可以躲）
const BOSS_SPECIAL := ["barrage", "volley", "follow", "pools", "wave", "vortex",
	"accuse", "stones", "bait", "searchlight", "squeeze", "stampede", "tether", "idols", "rumor"]   # 不是「地上警示→瞬間打下」的招式
var boss_lines: Array = []  # 依序落下的線（公會的長老一個一個指著你）
var boss_walls: Array = []  # 從兩側夾過來的牆（中間隔斷的牆）
var tether := {}            # 捆鎖：把主角綁在一個點上
var joy_t := 5.0            # 喜樂 Lv3：下一次歡呼
var joy_waves: Array = []   # 擴散中的歡呼圈 {pos, r, max, hit, dmg, stun}
var good_heal_t := 10.0     # 良善 Lv5：下一次全隊回血
var good_cd := 0.0          # 良善 Lv3：被打時放光的冷卻
var breast_cd := 0.0        # 護心鏡 Lv3：危急時發光的冷卻
var helmet_t := 20.0        # 救恩的頭盔 Lv3：下一次把經驗全部吸過來
var vac_t := 0.0            # 正在把畫面上的經驗吸過來
var block_txt_t := 0.0      # 「擋」字的間隔
var regen_acc := 0.0        # 慢慢回血累積到 2 點就跳字
var items: Array = []       # 地上的稀有道具 {kind, pos}：horn 耶利哥的號角、calm 平靜風浪、grapes 葡萄
var horn_rings: Array = []  # 號角的金色衝擊波（畫面）
var calm_t := 0.0           # 平靜風浪：敵人停住剩下的秒數
var merchant := {}          # 路過的商人 {pos, used}
var merchant_done := false
var scroll := {}            # 這座城藏著的書卷 {pos}
var bless := ""             # 營地祭壇求的祝福（這一趟用）
var bless_grapes := false   # 祝福「葡萄」：血少於三成時自動吃下   # 測試用：只讓這幾位上場
var fx_hp := {}


func _fxc(k: String) -> void:
	if smoke:
		fx_stat["觸發:" + k] = float(fx_stat.get("觸發:" + k, 0.0)) + 1.0


func _fx_sample() -> void:
	var add := func(k: String, v: float): fx_stat[k] = float(fx_stat.get(k, 0.0)) + v
	for e in enemies:
		if e.dead:
			continue
		if float(e.get("stun", 0.0)) > 0.0: add.call("暈眩", 1)
		if float(e.get("slow_t", 0.0)) > 0.0: add.call("變慢", 1)
		if float(e.get("exposed_t", 0.0)) > 0.0: add.call("破綻", 1)
		if float(e.get("confused", 0.0)) > 0.0: add.call("混亂", 1)
		if float(e.get("burn_t", 0.0)) > 0.0: add.call("燃燒", 1)
		if float(e.get("ally", 0.0)) > 0.0: add.call("被說服", 1)
	for c in [pa] + comps:
		if c.level > 0:
			add.call("衣服", int(c.get("garment", 0)))
			var hp: float = paul.hp if c == pa else float(c.hp)
			var was: float = float(fx_hp.get(c.key, hp))
			if hp > was: add.call("回血", hp - was)
			fx_hp[c.key] = hp
	add.call("香氣", zones.size())
	add.call("瓶子", jars.size())
	add.call("樹", trees.size())
	add.call("獅子", 1 if comps.any(func(c): return c.has("lions") and c.level > 0) else 0)
	add.call("小門徒", minions.size())
	add.call("護盾", guard)
	add.call("加速", 1 if haste_t > 0.0 else 0)


func _smoke_tick() -> void:
	smoke_frames += 1
	if smoke_shot != "" and smoke_frames == smoke_max_frames - 20 and not choosing and not paused:
		_set_paused(true)   # 測試用：最後拍一張暫停畫面
	if fxtest and smoke_frames == 20:
		_fx_gallery()
	if fxtest and smoke_frames == 26:
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_fx.png"))
	if smoke_shot != "" and smoke_frames == 30:   # 開局的畫面（看地面、物件）
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_start.png"))
	if smoke_shot != "" and smoke_frames == smoke_max_frames - 5 and paused:
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_pause.png"))
	if smoke_frames % 5 == 0:
		_fx_sample()
	if smoke_shot != "" and seekers.any(func(sk): return sk.prog > 1.5) and not FileAccess.file_exists(smoke_shot.replace(".png", "_seek.png")):
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_seek.png"))
	if smoke_shot != "" and not FileAccess.file_exists(smoke_shot.replace(".png", "_hz.png")):
		# 測試用：各章的關卡機制（火焰、大布、曠野的車、石頭）
		if tongues.any(func(tg): return tg.t < 1.1) or sheets.any(func(sh): return sh.t < 0.8 and sh.t > 0.0) or seekers.any(func(sk): return sk.get("chariot", false) and paul.pos.distance_to(sk.pos) < 70.0) or (star_falls.size() > 2 and stage.get("hazard", {}).get("look", "") == "stone"):
			get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_hz.png"))
			return
	if smoke_shot != "" and not fz_count.is_empty() and tag_fx.any(func(f): return str(f.text).begins_with("「") and f.t > 0.1) and not FileAccess.file_exists(smoke_shot.replace(".png", "_fz.png")):
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_fz.png"))
		return
	if smoke_shot != "" and blind_state != "":
		# 測試用：大馬色的瞎眼、亞拿尼亞、按手時的對話
		for pair in [["_blind", blind_state == "blind" and t - t_start > 20.0], ["_ananias", blind_state == "blind" and not ananias.is_empty() and paul.pos.distance_to(ananias.pos) < 60.0], ["_atalk", talking and blind_state == "heal"]]:
			if pair[1] and not FileAccess.file_exists(smoke_shot.replace(".png", pair[0] + ".png")):
				get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", pair[0] + ".png"))
				return
	if talking and smoke_frames % 15 == 0:
		if smoke_shot != "" and not FileAccess.file_exists(smoke_shot.replace(".png", "_talk.png")):
			get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_talk.png"))
		ui.dialogue_next()
	if chest_open and smoke_frames % 40 == 0:
		if smoke_shot != "" and not FileAccess.file_exists(smoke_shot.replace(".png", "_chest.png")):
			get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_chest.png"))
		ui._close_chest()
	if over and smoke_shot == "":
		# 不截圖時：一結束就印結果離開（大量模擬用）
		print("BOTRESULT stage=%s t=%.0f won=%s level=%d kills=%d party=%d pressure=%.2f" % [stage.id, t - t_start, won, level, kills, _party_count(), pressure])
		print("DMG ", dmg_log)
		var dealt := {}
		for c in [pa] + comps:
			if c.level > 0:
				dealt[c.key] = roundi(float(c.get("dealt", 0.0)))
		print("DEALT ", dealt)
		print("SUPPORTS ", pa.get("anoints", []), " slots=", _support_slots(), " fusions=", fusions_on.keys(), " tiers=", school_tier)
		get_tree().quit()
		return
	if over and smoke_shot != "":
		smoke_over += 1
		if smoke_over == 170:
			get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_egg.png"))
		if smoke_over == 900:
			get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_over.png"))
			print("SMOKE DONE (over) t=%.1f won=%s" % [t, won])
			print("BOTRESULT stage=%s t=%.0f won=%s level=%d kills=%d party=%d" % [stage.id, t - t_start, won, level, kills, _party_count()])
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
		if smoke_shot != "" and level >= 3 and banishes_left == int(D.leveling.get("banishes", 2)) and ui.banish_mode == false:
			ui.toggle_banish()   # 測試放逐：截一張放逐模式的圖，再放逐第一張
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_banish.png"))
			var bk: String = "%s:%s" % [pending_cards[0].kind, pending_cards[0].key]
			ui.pick(0)
			print("BANISH ", bk, " left=", banishes_left, " back=", pending_cards.any(func(cd): return "%s:%s" % [cd.kind, cd.key] == bk))
			return
		ui.pick(_bot_pick(pending_cards) if bot else randi() % pending_cards.size())
	if meter >= 1.0 and fever <= 0.0 and not smoke_nofever:
		_start_fever()
	if smoke_frames % 300 == 0:
		var party := []
		for c in comps:
			if c.level > 0:
				party.append("%s%d" % [c.key, c.level])
		print("links fired=%d combo=%d best=%d" % [link_count, combo, combo_best])
		print("director pressure=%.2f life_avg=%.1f" % [pressure, life_avg])
		print("bonds=%d " % run_bonds, "schools tier=%s converts=%d minions=%d(%d) songs=%d praise=%.0f holies=%d anoint=%.0f shocks=%d guard=%d trail=%d" % [school_tier, run_converts, run_minions, minions.size(), run_songs, praise, run_holies, anoint, run_shocks, guard, trail.size()])
		print("t=%.1f hp=%.0f Lv=%d enemies=%d kills=%d fever=%.1f boss=%s party=%s fruits=%s armor=%s evo=%s" % [t, paul.hp, level, enemies.size(), kills, fever,
			("%.0f/%s" % [boss.hp, boss.state]) if boss != null else "-(tele %d)" % tele.size(), party, fruits, armor, evolved.keys()])
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
		var dealt2 := {}
		for c in [pa] + comps:
			if c.level > 0:
				dealt2[c.key] = "%d/%d次/倒%.0f" % [roundi(float(c.get("dealt", 0.0))), int(c.get("casts", 0)), float(c.get("down_total", 0.0))]
		print("DEALT ", dealt2, " tiers=", school_tier, " anoints=", pa.get("anoints", []))
		var fxr := {}
		for k in fx_stat:
			if float(fx_stat[k]) > 0.0:
				fxr[k] = roundi(float(fx_stat[k]))
		print("FX ", fxr)
		get_tree().quit()
