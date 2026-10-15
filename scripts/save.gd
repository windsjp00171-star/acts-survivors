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


# ---------- 恩賜樹 ----------
func gift_rank(tag: String, kind: String) -> int:
	return int(data.get("gifts", {}).get(tag, {}).get(kind, 0))


func gift_points(tag: String) -> int:
	var n := 0
	for k in data.get("gifts", {}).get(tag, {}):
		n += int(data.gifts[tag][k])
	return n


func gift_cost(i: int, tag: String) -> int:
	var nd: Dictionary = meta.gifts.nodes[i]
	return int(nd.cost) + gift_rank(tag, nd.id) * int(nd.cost_step)


## 第 i 個節點能不能學：這棵樹先點到 tiers[row] 點，而且前置節點都至少學過 1 級
func gift_open(i: int, tag: String) -> bool:
	var nd: Dictionary = meta.gifts.nodes[i]
	if gift_points(tag) < int(meta.gifts.tiers[int(nd.row)]):
		return false
	for r in nd.req:
		if gift_rank(tag, r) <= 0:
			return false
	return true


func buy_gift(i: int, tag: String) -> bool:
	var nd: Dictionary = meta.gifts.nodes[i]
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
	r.bread = int(int(r.get("bread", 0)) * (1.0 + tp * float(meta.trials.bread_per_point)))
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
	for k in ["resonances", "midbosses", "chests", "links", "kills_total", "fevers_total"]:
		st[k] = int(st.get(k, 0)) + int(r.get(k.replace("_total", ""), 0))
	for k in ["combo", "level", "party_size", "sets"]:
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
		data.affinity[key] = affinity_xp(key) + int(r.party[key]) * int(A.per_level_reached) + (int(A.win_bonus) if r.won else 0)
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
