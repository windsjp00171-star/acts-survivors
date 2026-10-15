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


## 永久恩典（花餅買）
func up_rank(id: String) -> int:
	return int(data.ups.get(id, 0))


func up_value(id: String) -> float:
	for u in meta.bread.upgrades:
		if u.id == id:
			return up_rank(id) * float(u.per)
	return 0.0


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
	if item.has("requires") and not data.bought.has(item.requires):
		return false
	data.witness -= int(item.cost)
	data.bought.append(item.id)
	if item.kind in ["companion", "fruit", "armor", "leader"] and not data.unlocked.has(item.id):
		data.unlocked.append(item.id)
	save_profile()
	return true


## 一局結束：算見證、默契、統計、見證錄；回傳要顯示在結算畫面的內容
func finish_run(r: Dictionary) -> Dictionary:
	var W: Dictionary = meta.witness
	var gain := int(r.kills / W.per_kills + r.seconds / W.per_seconds + r.level * W.per_level)
	if r.won:
		gain += int(W.boss_bonus)
	else:
		gain = int(gain * W.lose_ratio)
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
		if int(st.get(a.stat, 0)) >= int(a.min):
			data.achievements.append(a.id)
			gain += int(a.get("witness", 0))
			if a.has("unlock") and not data.unlocked.has(a.unlock):
				data.unlocked.append(a.unlock)
			new_ach.append(a)
	data.bread = int(data.get("bread", 0)) + int(r.get("bread", 0))
	data.bread_total = int(data.get("bread_total", 0)) + int(r.get("bread", 0))
	data.witness += gain
	data.witness_total += gain
	save_profile()
	return {"witness": gain, "achievements": new_ach, "affinity_ups": aff_ups, "bread": int(r.bread)}
