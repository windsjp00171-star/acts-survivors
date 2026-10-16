extends Node
## 存檔（自動載入，名稱 Save）：見證、解鎖、默契、統計、見證錄。存在 user://profile.json。

const PATH := "user://profile.json"

var meta: Dictionary
var data: Dictionary
var run_config := {}


func _ready() -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string("res://data/meta.json"))
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


func load_profile() -> void:
	data = _defaults()
	if FileAccess.file_exists(PATH):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if saved is Dictionary:
			for k in saved:
				if k == "stats":
					data.stats.merge(saved.stats, true)
				else:
					data[k] = saved[k]
	# 舊的熬煉紀錄 → 信心等級（大約每 2 點算一級）
	if data.faith_best.is_empty() and not data.trial_best.is_empty():
		for sid in data.trial_best:
			data.faith_best[sid] = mini(6, int(data.trial_best[sid]) / 2)
	_refund_old_gifts()
	_refund_capped_ups()
	_init_gift_on()


## 永久恩典有了上限：超過上限的等級把花掉的餅退回來
func _refund_capped_ups() -> void:
	var refund := 0
	for u in meta.bread.upgrades:
		var r := up_rank(u.id)
		if r > int(u.max):
			for i in range(int(u.max), r):
				refund += int(u.cost) + i * int(u.cost_step)
			data.ups[u.id] = int(u.max)
	if refund > 0:
		data.bread = int(data.get("bread", 0)) + refund
		data.refund_note = "永久恩典改成有上限，多出來的等級退回 %d 個餅" % refund
		save_profile()


## 恩賜樹改版後，舊存檔裡已經不存在的節點：把花掉的餅退回來
func _refund_old_gifts() -> void:
	var refund := 0
	for tag in data.get("gifts", {}).keys():
		if not meta.gifts.trees.has(tag):
			continue
		var ids := gift_nodes(tag).map(func(n): return n.id)
		for id in data.gifts[tag].keys():
			if not ids.has(id):
				var r := int(data.gifts[tag][id])
				for i in r:
					refund += 30 + i * 15
				data.gifts[tag].erase(id)
	if refund > 0:
		data.bread = int(data.get("bread", 0)) + refund
		save_profile()


func save_profile() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))


func is_unlocked(key: String) -> bool:
	return data.unlocked.has(key)


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
	return int(data.stats.get(stat, 0))


func camp_built(item: Dictionary) -> bool:
	return camp_stat(item.stat) >= int(item.min)


## 永久恩典（用餅兌換）
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


# ---------- 市集：每趟回營地換一批行囊 ----------
func market_offers() -> Array:
	var items: Array = meta.market.items.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.stats.runs) * 7919 + 13
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
	return items.slice(0, int(meta.market.offers))


func market_bought(id: String) -> bool:
	return data.get("market_run", -1) == int(data.stats.runs) and data.get("market_bought", []).has(id)


func buy_provision(item: Dictionary) -> bool:
	if market_bought(item.id) or int(data.witness) < int(item.cost):
		return false
	if data.get("market_run", -1) != int(data.stats.runs):
		data.market_run = int(data.stats.runs)
		data.market_bought = []
	data.witness -= int(item.cost)
	data.market_bought.append(item.id)
	if not data.has("provisions"):
		data.provisions = []
	data.provisions.append(item.id)
	save_profile()
	return true


## 出門時拿走行囊（用完就沒了）
func take_provisions() -> Array:
	var out: Array = data.get("provisions", [])
	data.provisions = []
	save_profile()
	return out


## 傳揚見證：見證換餅
func exchange(times: int) -> bool:
	var X: Dictionary = meta.exchange
	if int(data.witness) < int(X.witness) * times:
		return false
	data.witness -= int(X.witness) * times
	data.bread = int(data.get("bread", 0)) + int(X.bread) * times
	save_profile()
	return true


## 為同伴代禱：見證換默契
func pray_for(key: String) -> bool:
	var P: Dictionary = meta.pray
	if int(data.witness) < int(P.witness):
		return false
	data.witness -= int(P.witness)
	data.affinity[key] = affinity_xp(key) + int(P.affinity)
	save_profile()
	return true


## 送餅給同伴：默契增加
func gift_bread(key: String) -> bool:
	var G2: Dictionary = meta.gift_bread
	if int(data.get("bread", 0)) < int(G2.cost):
		return false
	data.bread = int(data.bread) - int(G2.cost)
	data.affinity[key] = affinity_xp(key) + int(G2.affinity)
	save_profile()
	return true


# ---------- 恩賜樹 ----------
func gift_rank(tag: String, kind: String) -> int:
	return int(data.get("gifts", {}).get(tag, {}).get(kind, 0))


func gift_points(tag: String) -> int:
	var n := 0
	for k in data.get("gifts", {}).get(tag, {}):
		n += int(data.gifts[tag][k])
	return n


func gift_nodes(tag: String) -> Array:
	return meta.gifts.trees[tag].nodes


## 全隊效果（move、xp、guardcap、revive）：所有樹加起來
func gift_global(kind: String) -> float:
	var v := 0.0
	for tag in meta.gifts.trees:
		for nd in gift_nodes(tag):
			if nd.kind == kind:
				v += gift_eff(tag, nd.id) * float(nd.per)
	return v


func gift_cost(i: int, tag: String) -> int:
	var nd: Dictionary = gift_nodes(tag)[i]
	return int(nd.cost) + gift_rank(tag, nd.id) * int(nd.cost_step)


## 第 i 個節點能不能學：這棵樹先點到 tiers[row] 點，而且前置節點都至少學過 1 級
func gift_open(i: int, tag: String) -> bool:
	var nd: Dictionary = gift_nodes(tag)[i]
	if gift_points(tag) < int(meta.gifts.tiers[int(nd.row)]):
		return false
	for r in nd.req:
		if gift_rank(tag, r) <= 0:
			return false
	return true


func buy_gift(i: int, tag: String) -> bool:
	var nd: Dictionary = gift_nodes(tag)[i]
	var c := gift_cost(i, tag)
	if not gift_open(i, tag) or gift_rank(tag, nd.id) >= int(nd.max) or int(data.bread) < c:
		return false
	data.bread = int(data.bread) - c
	if not data.has("gifts"):
		data.gifts = {}
	if not data.gifts.has(tag):
		data.gifts[tag] = {}
	data.gifts[tag][nd.id] = gift_rank(tag, nd.id) + 1
	# 學會的節點：配置點數夠就自動裝上；裝著的節點升級後超過上限就先卸下
	if gift_on(tag, nd.id):
		if gift_used() > gift_cap():
			toggle_gift(tag, nd.id)
	elif gift_used() + gift_rank(tag, nd.id) <= gift_cap():
		toggle_gift(tag, nd.id)
	save_profile()
	return true


# ---------- 恩賜配置：學會的節點永久保留，但每次出發只能裝上有限的點數 ----------
func gift_cap() -> int:
	var G: Dictionary = meta.gifts.get("loadout", {"base": 10, "per_church": 2, "per_faith": 1})
	return int(G.base) + data.churches.size() * int(G.per_church) + faith_max() * int(G.per_faith)


func gift_on(tag: String, id: String) -> bool:
	return data.get("gift_on", {}).get(tag, []).has(id)


func gift_used() -> int:
	var n := 0
	for tag in data.get("gift_on", {}):
		for id in data.gift_on[tag]:
			n += gift_rank(tag, id)
	return n


## 遊戲裡實際生效的等級：有裝上才算
func gift_eff(tag: String, id: String) -> int:
	return gift_rank(tag, id) if gift_on(tag, id) else 0


## 裝上／卸下；點數不夠時回傳 false
func toggle_gift(tag: String, id: String) -> bool:
	if not data.has("gift_on"):
		data.gift_on = {}
	if not data.gift_on.has(tag):
		data.gift_on[tag] = []
	if data.gift_on[tag].has(id):
		data.gift_on[tag].erase(id)
		return true
	if gift_used() + gift_rank(tag, id) > gift_cap():
		return false
	data.gift_on[tag].append(id)
	return true


## 舊存檔：還沒有配置時，照樹的順序把學過的節點裝上，裝到上限為止
func _init_gift_on() -> void:
	if data.has("gift_on"):
		return
	data.gift_on = {}
	var trees: Array = data.get("gifts", {}).keys()
	trees.sort_custom(func(a, b): return gift_points(a) > gift_points(b))
	for tag in trees:
		if not meta.gifts.trees.has(tag):
			continue
		for nd in gift_nodes(tag):
			if gift_rank(tag, nd.id) > 0:
				toggle_gift(tag, nd.id)
	if gift_used() < gift_points_all():
		data.refund_note = str(data.get("refund_note", "")) + ("\n" if data.has("refund_note") else "") + "恩賜樹改成「配置」：學過的都還在，但每次出發只能裝上 %d 點，到恩賜頁可以自由換" % gift_cap()


func gift_points_all() -> int:
	var n := 0
	for tag in data.get("gifts", {}):
		n += gift_points(tag)
	return n


func up_cost(u: Dictionary) -> int:
	return int(u.cost) + up_rank(u.id) * int(u.cost_step)


func buy_up(u: Dictionary) -> bool:
	var c := up_cost(u)
	if up_rank(u.id) >= int(u.max) or int(data.bread) < c:
		return false
	data.bread = int(data.bread) - c
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
		"gift_points":
			var n := 0
			for tag in data.get("gifts", {}):
				n += gift_points(tag)
			return n
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
	return {"witness": gain, "achievements": new_ach, "affinity_ups": aff_ups, "bread": int(r.bread)}
