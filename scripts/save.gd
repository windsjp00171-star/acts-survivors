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
		"baskets": 0, "egg_seen": false, "camp_seen": [], "churches": [], "stage": 0, "talks_seen": {}, "talk_pending": [], "talk_run": -1, "bread": 0, "bread_total": 0, "ups": {}, "trials_on": [], "trial_best": {}, "codex": {"enemies": [], "evos": [], "fruits": [], "armor": []},
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
	_refund_old_gifts()


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


func trial_points(ids: Array) -> int:
	var n := 0
	for t in meta.trials.list:
		if ids.has(t.id):
			n += int(t.points)
	return n


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
				v += gift_rank(tag, nd.id) * float(nd.per)
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
	save_profile()
	return true


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
		"affinity_max":
			var m := 0
			for k in data.affinity:
				m = maxi(m, affinity_level(k))
			return m
	return int(data.stats.get(id, 0))


func finish_run(r: Dictionary) -> Dictionary:
	var W: Dictionary = meta.witness
	var gain := int(r.kills / W.per_kills + r.seconds / W.per_seconds + r.level * W.per_level)
	if r.won:
		gain += int(W.boss_bonus)
	elif not r.get("endless", false):
		gain = int(gain * W.lose_ratio)   # 無盡模式本來就是撐到倒下，不打折
	gain += int(r.get("task_witness", 0))
	var tp := int(r.get("trial_points", 0))
	gain = int(gain * (1.0 + tp * float(meta.trials.witness_per_point)))
	r.bread = int(int(r.get("bread", 0)) * (1.0 + tp * float(meta.trials.bread_per_point) + building_bonus("bread")))
	if r.won and tp > 0:
		var sid: String = r.get("stage", "")
		data.trial_best[sid] = maxi(int(data.trial_best.get(sid, 0)), tp)
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
	for k in ["resonances", "midbosses", "chests", "links", "kills_total", "fevers_total", "converts", "minions", "songs", "holies", "shocks", "bonds"]:
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
	for k in ["enemies", "evos", "fruits", "armor"]:
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
