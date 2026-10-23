extends Node
## 存檔（自動載入，名稱 Save）：見證、解鎖、默契、統計、見證錄。存在 user://profile.json。

const PATH := "user://profile.json"
const TMP := "user://profile.json.tmp"     # 寫存檔時先寫這裡，確認完整才換上去
const PREV := "user://profile_prev.json"   # 上一次的存檔（主檔壞了就用它救回來）

var meta: Dictionary
var data: Dictionary
var run_config := {}
var story: Dictionary      # 劇情模式的章節（data/story.json）


## 中途存檔：還沒走完的這一局（離開時自動存，下次可以繼續）
const RUN_PATH := "user://run_save.txt"
var resume := {}   # 營地按了「繼續」：main.gd 開局時照這份還原


## 每日挑戰：用日期當種子，同一天每個人拿到一樣的城市、條件、呼召、聖物與第一位同伴
func daily_today() -> Dictionary:
	var date := Time.get_date_string_from_system()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("daily-" + date)
	var G: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	var stages: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/stages.json")).stages
	var levels: Array = meta.faith.levels.filter(func(L): return L.id != "simple")
	var trials := []
	while trials.size() < 2:
		var L: Dictionary = levels[rng.randi_range(0, levels.size() - 1)]
		if not trials.has(L.id):
			trials.append(L.id)
	var starters: Array = meta.start_unlocked.filter(func(k): return not str(k).begins_with("fruit_") and not str(k).begins_with("armor_"))
	return {"date": date, "stage": rng.randi_range(0, stages.size() - 1), "trials": trials,
		"calling": G.callings[rng.randi_range(0, G.callings.size() - 1)].id,
		"relic": G.relics[rng.randi_range(0, G.relics.size() - 1)].id,
		"starter": starters[rng.randi_range(0, starters.size() - 1)]}


func has_run_save() -> bool:
	return FileAccess.file_exists(RUN_PATH) and not read_run_save().is_empty()


func read_run_save() -> Dictionary:
	if not FileAccess.file_exists(RUN_PATH):
		return {}
	var v = str_to_var(FileAccess.get_file_as_string(RUN_PATH))
	return v if v is Dictionary and int(v.get("ver", 0)) == 1 else {}


func write_run_save(d: Dictionary) -> void:
	var f := FileAccess.open(RUN_PATH + ".tmp", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(var_to_str(d))
	f.close()
	DirAccess.rename_absolute(RUN_PATH + ".tmp", RUN_PATH)   # 先寫暫存檔再換名，寫到一半關掉也不會壞


func clear_run_save() -> void:
	if FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(RUN_PATH)


func _ready() -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string("res://data/meta.json"))
	story = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	load_profile()
	# 直式螢幕（手機）改用 360×640 當基準，介面與鏡頭會自動換成直式排版
	var ws := DisplayServer.window_get_size()
	if ws.y > ws.x:
		get_tree().root.content_scale_size = Vector2i(360, 640)


func _defaults() -> Dictionary:
	return {
		"witness": 0, "witness_total": 0,
		"unlocked": meta.start_unlocked.duplicate(), "bought": [],
		"affinity": {}, "achievements": [], "starter": meta.default_starter,
		"baskets": 0, "egg_seen": false, "camp_seen": [], "churches": [], "stage": 0, "talks_seen": {}, "talk_pending": [], "talk_run": -1, "bread": 0, "bread_total": 0, "ups": {}, "trials_on": [], "trial_best": {}, "faith_best": {}, "faith_sel": 0, "codex": {"enemies": [], "evos": [], "fruits": [], "armor": []},
		"stats": {"runs": 0, "wins": 0, "elites": 0, "best_kills": 0, "best_fevers": 0,
			"evolutions": 0, "no_down": 0, "full_party": 0, "tasks": 0, "lights": 0},
	}


func _read_json(p: String) -> Variant:
	if not FileAccess.file_exists(p):
		return null
	var v = JSON.parse_string(FileAccess.get_file_as_string(p))
	return v if v is Dictionary and v.has("stats") else null


func load_profile() -> void:
	data = _defaults()
	# 主檔讀不出來（寫到一半斷電、被關掉）：依序改用寫好但還沒換上的暫存檔、上一次的存檔
	var saved = _read_json(PATH)
	if saved == null:
		saved = _read_json(TMP)
	if saved == null:
		saved = _read_json(PREV)
	if saved != null:
		for k in saved:
			if k == "stats":
				data.stats.merge(saved.stats, true)
			else:
				data[k] = saved[k]
	# 舊的熬煉紀錄 → 信心等級（大約每 2 點算一級）
	if data.faith_best.is_empty() and not data.trial_best.is_empty():
		for sid in data.trial_best:
			data.faith_best[sid] = mini(6, int(data.trial_best[sid]) / 2)
	# 關卡順序改過兩次（0.16 前面多了大馬色、0.18 多了劇情的新章節）：舊存檔選的城照名字找回來
	if saved != null and int(data.get("map_ver", 1)) < 3:
		var old_ids: Array = ["philippi", "thessalonica", "athens", "corinth", "ephesus", "jerusalem", "malta", "rome", "patmos"]
		if int(data.get("map_ver", 1)) == 2:
			old_ids.push_front("damascus")
		var sid: String = old_ids[clampi(int(data.get("stage", 0)), 0, old_ids.size() - 1)]
		var ids: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/stages.json")).stages.map(func(st): return st.id)
		data.stage = maxi(0, ids.find(sid))
	data.map_ver = 3
	# 0.25 拿掉市集：還沒用掉的行囊折回見證
	var bag: Array = data.get("provisions", [])
	if not bag.is_empty():
		data.witness = int(data.witness) + 60 * bag.size()
		data.provisions = []
	_refund_capped_ups()
	_migrate_board()


## 永久恩典有了上限：超過上限的等級把花掉的餅退回來
func _refund_capped_ups() -> void:
	var refund := 0
	for u in meta.bread.upgrades:
		var r := up_rank(u.id)
		if r > int(u.max):
			for i in range(int(u.max), r):
				refund += (int(u.cost) + i * int(u.cost_step)) / 3   # 當年是用餅買的（現在標價是見證）
			data.ups[u.id] = int(u.max)
	if refund > 0:
		data.bread = int(data.get("bread", 0)) + refund
		data.refund_note = "永久恩典改成有上限，多出來的等級退回 %d 個餅" % refund
		save_profile()


## 從頭開始旅程：舊進度先存一份備份，然後全部歸零（設定保留）
func reset_profile() -> void:
	if FileAccess.file_exists(PATH):
		var b := FileAccess.open("user://profile_backup.json", FileAccess.WRITE)
		b.store_string(JSON.stringify(data, "  "))
	var keep := {}
	for k in ["music_on", "sfx_on", "fxlite_on", "bigtext_on"]:
		if data.has(k):
			keep[k] = data[k]
	data = _defaults()
	data.map_ver = 3
	data.merge(keep, true)
	data.board_ver = 1
	save_profile()


## 存檔碼：把整個存檔壓縮成一段文字（換手機、換瀏覽器時帶走）
const CODE_HEAD := "ACTS1:"


func export_code() -> String:
	var raw := JSON.stringify(data).to_utf8_buffer()
	return CODE_HEAD + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))


## 匯入存檔碼：成功就取代目前的存檔（目前的先備份到 profile_backup.json），失敗回傳原因
func import_code(code: String) -> String:
	var c := code.strip_edges().replace("\n", "").replace(" ", "")
	if not c.begins_with(CODE_HEAD):
		return "這不是宣教之路的存檔碼（開頭應該是 %s）" % CODE_HEAD
	var packed := Marshalls.base64_to_raw(c.substr(CODE_HEAD.length()))
	if packed.is_empty():
		return "存檔碼不完整，請確認整段都複製到了"
	var raw := packed.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var saved = JSON.parse_string(raw.get_string_from_utf8()) if not raw.is_empty() else null
	if not (saved is Dictionary) or not saved.has("stats") or not saved.has("witness"):
		return "存檔碼讀不出來，請確認整段都複製到了"
	var b := FileAccess.open("user://profile_backup.json", FileAccess.WRITE)
	b.store_string(JSON.stringify(data, "  "))
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(saved, "  "))
	f = null
	load_profile()   # 重新讀進來，舊版本的存檔也會照常轉換
	save_profile()
	return ""


## 寫存檔：先寫暫存檔、讀回來確認完整，再把舊的存成「上一次」、暫存檔換成正式的。
## 任何一步中斷，下次讀檔都還找得到一份完整的（見 load_profile）。
func save_profile() -> void:
	var txt := JSON.stringify(data, "  ")
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		_write_direct(txt)
		return
	f.store_string(txt)
	f.close()
	if FileAccess.get_file_as_string(TMP) != txt:
		_write_direct(txt)   # 暫存檔寫不完整（空間不夠之類）：退回直接寫
		return
	if FileAccess.file_exists(PATH):
		if FileAccess.file_exists(PREV):
			DirAccess.remove_absolute(PREV)
		DirAccess.rename_absolute(PATH, PREV)
	if DirAccess.rename_absolute(TMP, PATH) != OK:
		_write_direct(txt)


func _write_direct(txt: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(txt)


func is_unlocked(key: String) -> bool:
	return data.unlocked.has(key)


## 劇情模式：第 i 章開了沒（第一章一定開；之後要先通過前一章）
func story_open(i: int) -> bool:
	return i == 0 or data.churches.has(story.chapters[i - 1].stage)


## 劇情進行到第幾章（第一個還沒通過的章節；全部通過就是章節數）
func story_next() -> int:
	for i in story.chapters.size():
		if not data.churches.has(story.chapters[i].stage):
			return i
	return story.chapters.size()


## 營地在哪座城：最後通過的那一章的城（還沒通過任何一章時在耶路撒冷）
func camp_name() -> String:
	var name := "耶路撒冷"
	for ch in story.chapters:
		if data.churches.has(ch.stage):
			name = ch.camp
	return name


func trials_unlocked() -> bool:
	return not data.churches.is_empty()


## 教會成長：人數與階段（0 是剛建立）
func church_members(sid: String) -> int:
	return int(data.get("church_members", {}).get(sid, 0))


func church_stage(sid: String) -> int:
	var n := 0
	for m in meta.church.members:
		if church_members(sid) >= int(m):
			n += 1
	return n


## 花見證寫信堅固教會
func church_letter(sid: String) -> bool:
	var C: Dictionary = meta.church
	if not data.churches.has(sid) or int(data.witness) < int(C.letter_cost):
		return false
	data.witness = int(data.witness) - int(C.letter_cost)
	if not data.has("church_members"):
		data.church_members = {}
	data.church_members[sid] = church_members(sid) + int(C.letter_add)
	save_profile()
	return true


## 信心等級：第 n 級要套用的限制（第 1～n 項）
func faith_ids(n: int) -> Array:
	var out := []
	for i in mini(n, meta.faith.levels.size()):
		out.append(meta.faith.levels[i].id)
	return out


## 這座城最高可以選到第幾級：建立教會後開放第 1 級，之後每通過一級開下一級
func faith_open(sid: String) -> int:
	if not data.churches.has(sid):
		return 0
	return mini(int(meta.faith.max), int(data.get("faith_best", {}).get(sid, 0)) + 1)


func faith_max() -> int:
	var m := 0
	for k in data.get("faith_best", {}):
		m = maxi(m, int(data.faith_best[k]))
	return m


## 舊的計分方式（熬煉點數）只剩相容用：等級越高點數越多
func trial_points(ids: Array) -> int:
	return ids.size()


func party_cap() -> int:
	var n: int = meta.party_cap_base
	if run_config.get("trials", []).has("alone"):
		n -= 1
	for id in data.bought:
		if id.begins_with("slot_"):
			n += 1
	if run_config.get("calling", "") == "apostle":
		n += 1   # 使徒：隊伍上限 +1
	return n


func rerolls() -> int:
	if run_config.get("trials", []).has("simple"):
		return 0
	var n := 0
	for item in meta.shop:
		if item.kind == "reroll" and data.bought.has(item.id):
			n += int(item.get("amount", 1))
	return n


func affinity_xp(key: String) -> int:
	return int(data.affinity.get(key, 0))


func affinity_level(key: String) -> int:
	var xp := affinity_xp(key)
	var lv := 0
	for th in meta.affinity.thresholds:
		if xp >= th:
			lv += 1
	return lv


func next_threshold(key: String) -> int:
	var lv := affinity_level(key)
	var ths: Array = meta.affinity.thresholds
	return ths[lv] if lv < ths.size() else -1


## 營地設施的條件值
func camp_stat(stat: String) -> int:
	match stat:
		"witness_total": return int(data.witness_total)
		"achievements": return data.achievements.size()
		"churches": return data.churches.size()
	return int(data.stats.get(stat, 0))


func camp_built(item: Dictionary) -> bool:
	return camp_stat(item.stat) >= int(item.min)


## 永久恩典（營地建設裡用見證蓋）
func up_rank(id: String) -> int:
	return int(data.ups.get(id, 0))


func up_value(id: String) -> float:
	for u in meta.bread.upgrades:
		if u.id == id:
			return up_rank(id) * float(u.per)
	return 0.0


# ---------- 營地建設 ----------
func building_level(id: String) -> int:
	var bd = data.get("buildings", {})
	if bd is Array:   # 舊存檔：只記蓋了哪些
		return 1 if bd.has(id) else 0
	return int(bd.get(id, 0))


func built(id: String) -> bool:
	return building_level(id) > 0


func building_cost(b: Dictionary) -> int:
	return int(b.cost) * (building_level(b.id) + 1)


## 所有已蓋好的建築加起來的效果（效果 × 等級）
func building_bonus(key: String) -> float:
	var v := 0.0
	for b in meta.buildings:
		v += float(b.bonus.get(key, 0.0)) * building_level(b.id)
	return v


func buy_building(b: Dictionary) -> bool:
	var lv := building_level(b.id)
	if lv >= int(b.get("max", 1)) or int(data.witness) < building_cost(b):
		return false
	data.witness -= building_cost(b)
	var bd = data.get("buildings", {})
	if bd is Array:
		var conv := {}
		for id in bd:
			conv[id] = 1
		bd = conv
	bd[b.id] = lv + 1
	data.buildings = bd
	save_profile()
	return true


# ---------- 恩賜盤（meta.json 的 gifts.board）----------
# 學會（用餅，永久）：data.board_learned；裝上（每位主角一套）：data.board_on[主角]
# 學會要跟已學會的節點或任何一位主角的起點相連；裝上要從這位主角的起點一路連過去，總數不超過 gift_cap()
var _bn := {}    # id → 節點
var _adj := {}   # id → 相連的 id


func _board() -> Dictionary:
	if _bn.is_empty():
		for nd in meta.gifts.board.nodes:
			_bn[nd.id] = nd
			_adj[nd.id] = []
		for l in meta.gifts.board.links:
			_adj[l[0]].append(l[1])
			_adj[l[1]].append(l[0])
	return _bn


func board_nodes() -> Array:
	return meta.gifts.board.nodes


func board_node(id: String) -> Dictionary:
	return _board().get(id, {})


func board_adj(id: String) -> Array:
	_board()
	return _adj.get(id, [])


func cur_leader() -> String:
	return str(data.get("leader", "paul"))


func board_start(leader: String) -> String:
	return str(meta.gifts.board.starts.get(leader, "中央:hub"))


func board_is_start(id: String) -> bool:
	return meta.gifts.board.starts.values().has(id)


func board_learned(id: String) -> bool:
	return board_is_start(id) or data.get("board_learned", []).has(id)


func board_on_list(leader: String) -> Array:
	return data.get("board_on", {}).get(leader, [])


func board_is_on(id: String, leader: String) -> bool:
	return id == board_start(leader) or board_on_list(leader).has(id)


## 可以學：還沒學、而且旁邊有學會的節點
func board_can_learn(id: String) -> bool:
	if board_learned(id):
		return false
	for o in board_adj(id):
		if board_learned(o):
			return true
	return false


func board_learn(id: String) -> bool:
	var nd := board_node(id)
	if nd.is_empty() or not board_can_learn(id) or int(data.get("bread", 0)) < int(nd.cost):
		return false
	data.bread = int(data.bread) - int(nd.cost)
	var L: Array = data.get("board_learned", [])
	L.append(id)
	data.board_learned = L
	# 學會了而且接得上、點數也夠：直接幫現在的主角裝上
	if board_toggle(id, cur_leader()) != "":
		pass
	save_profile()
	return true


func gift_used(leader := "") -> int:
	return board_on_list(leader if leader != "" else cur_leader()).size()


## 裝上／卸下（卸下時，接不回起點的節點也一起卸下）。回傳空字串＝成功，不然是原因
func board_toggle(id: String, leader: String) -> String:
	if id == board_start(leader):
		return "起點一定點上"
	if not board_learned(id):
		return "還沒學會"
	var on: Array = board_on_list(leader).duplicate()
	if on.has(id):
		on.erase(id)
		on = _connected(on, leader)
	else:
		if on.size() >= gift_cap():
			return "點數用完了（%d／%d）" % [on.size(), gift_cap()]
		var touch := false
		for o in board_adj(id):
			if o == board_start(leader) or on.has(o):
				touch = true
		if not touch:
			return "要跟已經點上的節點相連"
		on.append(id)
	var B: Dictionary = data.get("board_on", {})
	B[leader] = on
	data.board_on = B
	return ""


## 只留下從起點接得到的節點
func _connected(on: Array, leader: String) -> Array:
	var seen := {board_start(leader): true}
	var q := [board_start(leader)]
	while not q.is_empty():
		var cur: String = q.pop_back()
		for o in board_adj(cur):
			if on.has(o) and not seen.has(o):
				seen[o] = true
				q.append(o)
	return on.filter(func(x): return seen.has(x))


func board_clear(leader: String) -> void:
	var B: Dictionary = data.get("board_on", {})
	B[leader] = []
	data.board_on = B


## 一鍵推薦：從起點往外，先點自己流派的經文節點與基石，再補小節點（只用學會的）
func board_recommend(leader: String, tag: String) -> void:
	board_clear(leader)
	var on := []
	var cap := gift_cap()
	while on.size() < cap:
		var best := ""
		var best_score := -1.0
		for id in _board():
			if on.has(id) or id == board_start(leader) or not board_learned(id):
				continue
			var touch := false
			for o in board_adj(id):
				if o == board_start(leader) or on.has(o):
					touch = true
			if not touch:
				continue
			var nd: Dictionary = _bn[id]
			var sc := 1.0 + int(nd.size)
			if nd.tag == tag or (nd.tag == "橋" and nd.get("tags", []).has(tag)):
				sc += 4.0
			elif nd.tag == "中央":
				sc += 1.5
			if nd.kind == "keystone":
				sc -= 3.0   # 有代價的基石不幫忙點，讓玩家自己決定
			if sc > best_score:
				best_score = sc
				best = id
		if best == "":
			break
		on.append(best)
	var B: Dictionary = data.get("board_on", {})
	B[leader] = on
	data.board_on = B


## 遊戲裡用：這個節點對現在的主角有沒有生效（1／0）
func gift_eff(_tag: String, id: String) -> int:
	return 1 if board_is_on(id, cur_leader()) else 0


func gift_nodes(tag: String) -> Array:
	return board_nodes().filter(func(n): return n.tag == tag)


## 全隊效果（move、xp、guardcap、revive、hp）：裝上的節點加起來
func gift_global(kind: String) -> float:
	var v := 0.0
	for nd in board_nodes():
		if nd.kind == kind and board_is_on(nd.id, cur_leader()):
			v += float(nd.get("per", 0.0))
	return v


## 裝上的基石（有代價的那種）
func board_keystones() -> Dictionary:
	var out := {}
	for nd in board_nodes():
		if nd.kind == "keystone" and board_is_on(nd.id, cur_leader()):
			out[nd.ks] = true
	return out


## 流派傾向：這個流派區每裝 1 點，升級卡出現這個流派的機會 +3%；卡片節點再加
func board_tilt(tag: String) -> float:
	var v := 0.0
	for nd in board_nodes():
		if board_is_on(nd.id, cur_leader()):
			if nd.tag == tag:
				v += 0.03
			if nd.kind == "cards" and nd.tag == tag:
				v += float(nd.per)
	return minf(v, 0.6)


func gift_cap() -> int:
	var G: Dictionary = meta.gifts.get("loadout", {"base": 10, "per_church": 2, "per_faith": 1})
	return int(G.base) + data.churches.size() * int(G.per_church) + faith_max() * int(G.per_faith)


## 舊的六棵恩賜樹 → 恩賜盤：花在樹上的餅全部退回，讓玩家在新盤上重新點（先備份）
func _migrate_board() -> void:
	if int(data.get("board_ver", 0)) >= 1:
		return
	var refund := 0
	for tag in data.get("gifts", {}):
		if not meta.gifts.trees.has(tag):
			continue
		for nd in meta.gifts.trees[tag].nodes:
			for i in int(data.gifts[tag].get(nd.id, 0)):
				refund += int(nd.cost) + i * int(nd.cost_step)
	if refund > 0:
		var b := FileAccess.open("user://profile_backup.json", FileAccess.WRITE)
		if b != null:
			b.store_string(JSON.stringify(data, "  "))
		data.bread = int(data.get("bread", 0)) + refund
		data.refund_note = str(data.get("refund_note", "")) + ("\n" if data.has("refund_note") else "") + "恩賜樹改成「恩賜盤」：花在舊恩賜樹上的 %d 個餅全部退回了，到倉房（恩賜）重新點；也可以按「一鍵推薦」" % refund
	data.gifts = {}
	data.erase("gift_on")
	data.board_ver = 1
	save_profile()


func up_cost(u: Dictionary) -> int:
	return int(u.cost) + up_rank(u.id) * int(u.cost_step)


## 永久恩典（0.25 起和營地建設放在一起，用見證蓋）
func buy_up(u: Dictionary) -> bool:
	var c := up_cost(u)
	if up_rank(u.id) >= int(u.max) or int(data.witness) < c:
		return false
	data.witness = int(data.witness) - c
	data.ups[u.id] = up_rank(u.id) + 1
	save_profile()
	return true


func buy(item: Dictionary) -> bool:
	if data.bought.has(item.id) or data.witness < item.cost:
		return false
	if item.has("requires") and not (data.bought.has(item.requires) or data.unlocked.has(item.requires)):
		return false
	data.witness -= int(item.cost)
	data.bought.append(item.id)
	if item.kind in ["companion", "fruit", "armor", "leader"] and not data.unlocked.has(item.id):
		data.unlocked.append(item.id)
	save_profile()
	return true


## 一局結束：算見證、默契、統計、見證錄；回傳要顯示在結算畫面的內容
## 見證錄的數值：大多直接是統計，有幾項是從存檔算出來的
func stat_value(id: String) -> int:
	match id:
		"churches": return data.churches.size()
		"companions": return data.unlocked.filter(func(k): return not (k.begins_with("fruit_") or k.begins_with("armor_") or k.begins_with("leader_"))).size()
		"gift_points": return data.get("board_learned", []).size()
		"bread_total": return int(data.get("bread_total", 0))
		"codex_enemies": return data.get("codex", {}).get("enemies", []).size()
		"faith_max": return faith_max()
		"affinity_max":
			var m := 0
			for k in data.affinity:
				m = maxi(m, affinity_level(k))
			return m
	return int(data.stats.get(id, 0))


func finish_run(r: Dictionary) -> Dictionary:
	var W: Dictionary = meta.witness
	# 驅散的敵人有上限：build 越強殺得越多，不能讓見證跟著暴增
	var gain := int(minf(float(r.kills) / float(W.per_kills), float(W.get("kill_cap", 9999))) + r.seconds / W.per_seconds + r.level * W.per_level)
	gain += int(r.get("saved", 0)) * int(W.get("saved_each", 4))   # 帶人信主
	if r.won:
		gain += int(W.boss_bonus)
	elif not r.get("endless", false):
		gain = int(gain * W.lose_ratio)   # 無盡模式本來就是撐到倒下，不打折
	gain += int(r.get("task_witness", 0))
	var tp := int(r.get("faith", 0))
	var fm := 1.0 + tp * float(meta.faith.reward_per_level)
	gain = int(gain * fm)
	r.bread = int(int(r.get("bread", 0)) * (fm + building_bonus("bread")))
	var day: String = str(r.get("daily", ""))
	if day != "":
		# 每日挑戰：當天第一次通關，見證與餅 ×1.5；記下當天最好的成績
		if r.won and str(data.get("daily_won", "")) != day:
			data.daily_won = day
			gain = int(gain * 1.5)
			r.bread = int(r.bread * 1.5)
			r.daily_bonus = true
		var best: Dictionary = data.get("daily_best", {})
		if str(best.get("date", "")) != day:
			best = {"date": day, "kills": 0, "seconds": 0, "won": false}
		best.kills = maxi(int(best.kills), int(r.kills))
		best.seconds = maxi(int(best.seconds), int(r.seconds))
		best.won = bool(best.won) or bool(r.won)
		data.daily_best = best
	if r.won:
		var sid: String = r.get("stage", "")
		if not data.has("faith_best"):
			data.faith_best = {}
		data.faith_best[sid] = maxi(int(data.faith_best.get(sid, 0)), tp)
	# 教會成長：在已建立教會的城帶人信主，人數加進那間教會
	var csid: String = r.get("stage", "")
	if data.churches.has(csid) and int(r.get("saved", 0)) > 0:
		if not data.has("church_members"):
			data.church_members = {}
		data.church_members[csid] = int(data.church_members.get(csid, 0)) + int(r.saved)
	var st: Dictionary = data.stats
	st.runs += 1
	if r.won:
		st.wins += 1
	st.elites += int(r.elites)
	st.best_kills = maxi(st.best_kills, int(r.kills))
	st.best_fevers = maxi(st.best_fevers, int(r.fevers))
	st.evolutions += int(r.evolutions)
	st.tasks += int(r.get("tasks_done", 0))
	st.lights = int(st.get("lights", 0)) + int(r.get("lights", 0))
	if r.no_down:
		st.no_down = 1
	if r.full_party:
		st.full_party = 1
	# 見證錄用的統計（累計 add、最高 best）
	for k in ["resonances", "midbosses", "chests", "links", "kills_total", "fevers_total", "converts", "minions", "songs", "holies", "shocks", "bonds", "relics", "saved"]:
		st[k] = int(st.get(k, 0)) + int(r.get(k.replace("_total", ""), 0))
	for k in ["combo", "level", "party_size", "sets", "school"]:
		st["best_" + k] = maxi(int(st.get("best_" + k, 0)), int(r.get(k, 0)))
	if r.get("endless", false):
		st.endless_best = maxi(int(st.get("endless_best", 0)), int(r.seconds))
	if r.won and r.get("leader", "paul") != "paul":
		st.leader_wins = int(st.get("leader_wins", 0)) + 1
	if r.won:
		st.best_trial_win = maxi(int(st.get("best_trial_win", 0)), tp)

	# 圖鑑：把這局遇到的記下來
	var cx: Dictionary = data.codex
	for k in ["enemies", "evos", "fruits", "armor", "relics"]:
		if not cx.has(k):
			cx[k] = []
		for id in r.get("seen", {}).get(k, []):
			if not cx[k].has(id):
				cx[k].append(id)
	var aff_ups := []
	var A: Dictionary = meta.affinity
	for key in r.party:
		var before := affinity_level(key)
		data.affinity[key] = affinity_xp(key) + int((int(r.party[key]) * int(A.per_level_reached) + (int(A.win_bonus) if r.won else 0)) * (1.0 + building_bonus("affinity")))
		if affinity_level(key) > before:
			aff_ups.append(key)

	var new_ach := []
	for a in meta.achievements:
		if data.achievements.has(a.id):
			continue
		if stat_value(a.stat) >= int(a.min):
			data.achievements.append(a.id)
			gain += int(a.get("witness", 0))
			r.bread = int(r.bread) + int(a.get("bread", 0))
			if a.has("unlock") and not data.unlocked.has(a.unlock):
				data.unlocked.append(a.unlock)
			new_ach.append(a)
	data.bread = int(data.get("bread", 0)) + int(r.get("bread", 0))
	data.bread_total = int(data.get("bread_total", 0)) + int(r.get("bread", 0))
	data.witness += gain
	data.witness_total += gain
	save_profile()
	return {"witness": gain, "achievements": new_ach, "affinity_ups": aff_ups, "bread": int(r.bread), "daily_bonus": r.get("daily_bonus", false)}
