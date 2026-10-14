extends Node2D
## 主遊戲：移動、同伴招募與升級、自動攻擊、四種敵人與打散、同心合意與五旬節 FEVER、失敗。
## 數值全部來自 data/game.json。

const ZOOM := 2.0
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
var pending_cards: Array = []
var spawn_timer := 0.0
var scatter_by := {}
var shake := 0.0

var meter := 0.0
var fever := 0.0          # 剩餘秒數，>0 表示 FEVER 中
var fever_kills := 0
var fever_bursts: Array = []

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
var comps: Array = []
var by_key := {}
var enemies: Array = []
var bolts: Array = []
var rings: Array = []
var beams: Array = []
var blasts: Array = []
var fires: Array = []     # 以利亞的火：先預兆再落下
var delayed: Array = []   # 延遲觸發的招式（參孫的第二下）
var links: Array = []     # 肢體連結：{src, dst, kind, cd}
var link_queue: Array = []
var link_fx: Array = []
var link_count := 0       # 本局觸發次數
var build_text := ""      # HUD 左側：同工與肢體連結
var shots: Array = []
var gems: Array = []
var parts: Array = []
var heals: Array = []
var pops: Array = []
var chunks := {}
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
	for a in OS.get_cmdline_user_args():
		if a == "--smoke":
			smoke = true
		elif a.begins_with("--shot="):
			smoke_shot = a.substr(7)
		elif a.begins_with("--t0="):
			t = float(a.substr(5))
		elif a == "--nofever":
			smoke_nofever = true
		elif a.begins_with("--preset="):
			smoke_preset = a.substr(9)
	for k in D.enemies:
		scatter_by[k] = 0
	xp_need = int(D.leveling.first)
	t_start = t
	_build_world()
	_build_ui()
	var starter: String = Save.run_config.get("starter", Save.data.starter)
	if not by_key.has(starter) or not Save.is_unlocked(starter):
		starter = Save.meta.default_starter
	_recruit(by_key[starter])
	rerolls_left = Save.rerolls()
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
	ground.texture = _tex("ground")
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
	cam.zoom = Vector2(ZOOM, ZOOM)
	add_child(cam)
	cam.make_current()

	paul = {"name": D.paul.name, "pos": Vector2.ZERO, "hp": float(D.paul.hp), "inv": 0.0, "moving": false,
		"node": _sprite("paul_0", Vector2(-7, -17))}
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
			"syn": 1.0,
			"aff": 1.0 + Save.affinity_level(d.key) * float(Save.meta.affinity.bonus_per_level),
			"node": _sprite(d.key + "_0", Vector2(-7, -17))}
		c.node.visible = false
		comps.append(c)
		by_key[d.key] = c
		i += 1


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
	ui.restart_pressed.connect(func(): get_tree().reload_current_scene())
	ui.home_pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/base.tscn"))
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


func _recruit(c: Dictionary) -> void:
	if c.follows == "":
		c.home = SLOTS[_party_count() % SLOTS.size()]
	else:
		c.home = by_key[c.follows].home + Vector2(14, 0)
	_set_level(c, 1)
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
	return 1.0 + fruits.get("faith", 0) * D.fruits.faith.per_level.damage

func _guard() -> float:
	return 1.0 + fruits.get("good", 0) * D.fruits.good.per_level.guard

func _accord() -> float:
	return 1.0 + fruits.get("peace", 0) * D.fruits.peace.per_level.accord

func _scatter_mult() -> float:
	return maxf(0.3, 1.0 - fruits.get("peace", 0) * 0.1)

func _comp_max_hp() -> float:
	return D.companion_rules.hp * (1.0 + fruits.get("good", 0) * 0.1)

func _speed() -> float:
	return D.paul.speed * (1.0 + armor.get("shoes", 0) * 0.1)


func _make_cards() -> Array:
	var pool := []
	for k in D.fruits:
		var f: Dictionary = D.fruits[k]
		var lv: int = fruits.get(k, 0)
		if lv == 0 and not Save.is_unlocked("fruit_" + k):
			continue
		if lv == 0 and fruits.size() < 6:
			pool.append({"kind": "fruit", "key": k, "title": f.name + "　新果子", "tag": f.tag, "desc": f.desc})
		elif lv > 0 and lv < 5:
			pool.append({"kind": "fruit", "key": k, "title": "%s　Lv%d → %d" % [f.name, lv, lv + 1], "tag": f.tag, "desc": f.desc})
	for k in D.armor:
		var a: Dictionary = D.armor[k]
		var lv: int = armor.get(k, 0)
		if lv == 0 and not Save.is_unlocked("armor_" + k):
			continue
		if lv == 0 and armor.size() < int(D.armor_slots):
			pool.append({"kind": "armor", "key": k, "title": a.name + "　穿上", "tag": a.tag, "desc": a.desc[0]})
		elif lv > 0 and lv < 3:
			pool.append({"kind": "armor", "key": k, "title": "%s　Lv%d → %d" % [a.name, lv, lv + 1], "tag": a.tag, "desc": a.desc[lv]})
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
			pool.append({"kind": "up", "key": c.key, "title": "%s　Lv%d → %d" % [c.name, c.level, c.level + 1], "tag": c.tag, "desc": desc[c.level]})
	var lc := _link_card()
	if not lc.is_empty():
		pool.append(lc)
	pool.shuffle()
	var cards := pool.slice(0, 3)
	while cards.size() < 3:
		cards.append({"kind": "heal", "key": "", "title": "五餅二魚", "tag": "恩典", "desc": "保羅回復 %d 血" % int(D.leveling.heal_card)})
	return cards


func _level_up() -> void:
	level += 1
	xp -= xp_need
	xp_need = int(D.leveling.first) + (level - 1) * int(D.leveling.step)
	choosing = true
	joy.on = false
	ui.joy.on = false
	pending_cards = _make_cards()
	ui.do_flash(0.5)
	_ring_pop(paul.pos + Vector2(0, -6), C_GOLD, 60.0)
	ui.show_cards(pending_cards, Time.get_ticks_msec() / 1000.0, D.leveling.card_delay, rerolls_left)


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
	elif card.kind == "link":
		links.append({"src": by_key[card.src], "dst": by_key[card.dst], "kind": card.key, "cd": 0.0})
		ui.show_banner("肢體連結！", 1.2)
	else:
		paul.hp = minf(D.paul.hp, paul.hp + D.leveling.heal_card)


func _refresh_build_text() -> void:
	var lines := []
	var cnt := _tag_counts()
	for tag in cnt:
		if cnt[tag] >= 2:
			lines.append("同工　%s ×%d" % [tag, cnt[tag]])
	for L in links:
		var K: Dictionary = D.links.kinds[L.kind]
		lines.append("連結　%s" % (("受傷→" + L.dst.name) if L.kind == "hurt" else (L.src.name + "→" + L.dst.name + "（" + K.short + "）")))
	build_text = "\n".join(lines)


func _on_card(i: int) -> void:
	_apply_card(pending_cards[i])
	_refresh_build_text()
	choosing = false
	if xp >= xp_need:
		_level_up()


# ---------- 輸入 ----------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if over and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			get_tree().reload_current_scene()
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
	if over or choosing:
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
		if t >= D.enemies[k].from:
			total += D.enemies[k].weight
	var r := randf() * total
	for k in D.enemies:
		if t >= D.enemies[k].from:
			r -= D.enemies[k].weight
			if r <= 0.0:
				return k
	return "fear"


func _view_rect() -> Rect2:
	var size := get_viewport().get_visible_rect().size / ZOOM
	return Rect2(cam.position - size / 2.0, size)


func _edge_point(margin: float) -> Vector2:
	var v := _view_rect().grow(margin)
	match randi() % 4:
		0: return Vector2(v.position.x, v.position.y + randf() * v.size.y)
		1: return Vector2(v.end.x, v.position.y + randf() * v.size.y)
		2: return Vector2(v.position.x + randf() * v.size.x, v.position.y)
		_: return Vector2(v.position.x + randf() * v.size.x, v.end.y)


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
	var hp: float = ceilf(d.hp * (1.0 + D.waves.hp_per_minute * t / 60.0))
	var e := {"type": type, "d": d, "pos": at, "hp": hp, "ph": randf() * TAU, "flash": 0.0, "stun": 0.0,
		"cd": 0.0, "bcd": 0.0, "shoot": (d.shoot.every * randf()) if d.has("shoot") else 0.0, "r": 6.0,
		"sprite": type, "tint": Color.WHITE, "roar": 2.0,
		"knock": Vector2.ZERO, "dead": false, "node": _sprite(type + "_0", Vector2(-10, -13))}
	enemies.append(e)


## 菁英與考驗型敵人：用現有敵人的圖，放大或換色
func _spawn_special(key: String, def: Dictionary, at: Vector2) -> void:
	var d := {"name": def.name, "hp": def.hp, "speed": def.speed, "damage": def.damage, "scatter": def.get("scatter", 0),
		"dies_on_touch": false}
	for k in ["roar_every", "roar_radius", "roar_force", "chest", "immune"]:
		if def.has(k):
			d[k] = def[k]
	var scale: float = def.get("scale", 1.0)
	var e := {"type": key, "d": d, "pos": at, "hp": float(def.hp) * (1.0 + D.waves.hp_per_minute * t / 60.0), "ph": randf() * TAU,
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
	if e.type == "lies":
		dmg *= 1.0 + 0.5 * mini(armor.get("belt", 0), 2)
	if e.get("boss", false) and boss != null and boss.state == "break":
		dmg *= D.boss.break_mult
	e.hp -= dmg
	e.flash = 0.08
	if from != Vector2.INF:
		e.knock += (e.pos - from).normalized() * 40.0
	_burst(e.pos, 2, C_CREAM, C_GOLD)
	if e.hp <= 0:
		_kill(e, true, src)


func _kill(e: Dictionary, by_player: bool, src = null) -> void:
	e.dead = true
	if by_player and src != null:
		_fire_links("kill", src, 0)
	e.node.queue_free()
	if by_player:
		kills += 1
		gems.append({"pos": e.pos, "got": false})
		if e.d.get("chest", false):
			chests.append({"pos": e.pos})
		if e.get("elite", false):
			run_elites += 1
		if e.get("boss", false):
			_win()
		_burst(e.pos, 9, C_GOLD if fever > 0.0 else C_VL, C_CREAM)
		_ring_pop(e.pos, C_CREAM, 9.0)
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
func _start_fever() -> void:
	if meter < 1.0 or fever > 0.0 or over or choosing:
		return
	fever = D.fever.duration
	fever_kills = 0
	run_fevers += 1
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
	fever_bursts.append({"pos": paul.pos, "r": 0.0, "hit": {}})
	ui.do_flash(0.5)
	shake = 0.25


# ---------- 主迴圈 ----------
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if not over and not choosing and not chest_open:
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
	var barn = by_key.get("barn")
	var barn_on: bool = barn != null and _active(barn)
	var rules: Dictionary = D.companion_rules
	var party := 0
	var together := 0
	for c in comps:
		if c.level == 0:
			continue
		party += 1
		var k := minf(1.0, dt * 5.0 * (1.0 + armor.get("shoes", 0) * 0.5))
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
		meter = clampf(fever / D.fever.duration, 0.0, 1.0)
		if fever <= 0.0:
			_end_fever()
	elif party > 0:
		meter = minf(1.0, meter + dt / D.fever.fill_seconds * (float(together) / party) * _accord())

	for L in links:
		L.cd = maxf(0.0, L.cd - dt)
	_companion_skills(dt)
	_update_projectiles(dt)
	_update_enemies(dt)
	_run_link_queue()
	for f in link_fx:
		f.t += dt
	link_fx = link_fx.filter(func(f): return f.t < 0.6)

	var ew: Dictionary = D.elite_wave
	if t >= ew.from and t < ew.to and boss == null:
		elite_timer -= dt
		if elite_timer <= 0.0:
			_spawn_special("terror", D.elites.terror, _edge_point(16.0))
			ui.show_banner("菁英出現：恐嚇", 2.0)
			elite_timer = ew.elite_every
		trial_timer -= dt
		if trial_timer <= 0.0:
			var tr := _trial_for_build()
			if tr != "":
				var center := _edge_point(16.0)
				for i in int(ew.trial_group):
					_spawn_special(tr, D.trials[tr], center + Vector2(randf_range(-12, 12), randf_range(-12, 12)))
			trial_timer = ew.trial_every
	if t >= D.boss.at and not boss_spawned:
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
		spawn_timer = wave.y

	var G: Dictionary = D.gems
	for g in gems:
		var to: Vector2 = p.pos + Vector2(0, -6) - g.pos
		var d: float = to.length()
		if d < G.magnet_radius or fever > 0.0:
			g.pos += to.normalized() * (G.magnet_speed * (2.5 if fever > 0.0 else 1.0)) * dt
		if d < 4.0:
			g.got = true
			xp += 1
	gems = gems.filter(func(g): return not g.got)
	if gems.size() > 300:
		gems = gems.slice(gems.size() - 300)

	for q in parts:
		q.pos += q.vel * dt
		q.vel *= 0.92
		q.vel.y += 30.0 * dt
		q.life -= dt
	parts = parts.filter(func(q): return q.life > 0.0)
	for o in pops:
		o.t += dt
	pops = pops.filter(func(o): return o.t < 0.25)

	chunk_timer -= dt
	if chunk_timer <= 0.0:
		_update_chunks()
		chunk_timer = 0.4

	if xp >= xp_need and not over and not chest_open:
		_level_up()


func _companion_skills(dt: float) -> void:
	var barn = by_key.get("barn")
	var barn_on: bool = barn != null and _active(barn)
	var speed_mult: float = D.fever.attack_speed if fever > 0.0 else 1.0
	for c in comps:
		if c.skill == "" or not _active(c):
			continue
		var s: Dictionary = c.st
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
	var fired := true
	match c.engine:
		"bolt":
			var targets := _nearest_enemies(c.pos, s.range, int(s.count))
			fired = targets.size() > 0
			for i in (int(s.count) if fired else 0):
				var tg: Dictionary = targets[i % targets.size()]
				bolts.append({"pos": c.pos + Vector2(0, -8), "target": tg, "life": 1.5, "pierce": int(s.pierce),
					"split": int(s.split), "child": false, "dmg": float(s.damage), "size": int(s.size), "hit": {},
					"spd": float(s.speed), "emult": float(s.get("elite_mult", 1.0)), "look": c.look, "owner": c})
		"ring":
			for i in int(s.rings):
				rings.append({"owner": c, "r": 4.0 - i * 16.0, "dir": 1.0, "returns": int(s.returns), "hit": {},
					"max": float(s.max_radius) * _area(), "dmg": float(s.damage), "speed": float(s.speed), "stun": float(s.stun),
					"thick": int(s.thick), "knock": float(s.get("knock", 0.0)), "look": c.look})
		"heal":
			paul.hp = minf(D.paul.hp, paul.hp + s.amount)
			heals.append({"who": paul, "t": 0.0})
			for o in comps:
				if o.level == 0:
					continue
				if o.down > 0.0 and s.instant_revive:
					o.down = 0.0
					o.hp = _comp_max_hp() * D.companion_rules.revive_hp
				if o.down <= 0.0:
					o.hp = minf(_comp_max_hp(), o.hp + s.amount)
					heals.append({"who": o, "t": 0.0})
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
		"nova":
			var slams := int(s.slams)
			for i in slams:
				delayed.append({"t": i * 0.25, "fn": _nova.bind(c, s)})
		"strike":
			var cand := _nearest_enemies(c.pos, s.range, 12)
			fired = cand.size() > 0
			cand.shuffle()
			for i in mini(int(s.count), cand.size()):
				fires.append({"pos": cand[i].pos, "t": float(s.delay), "max": float(s.delay), "r": float(s.radius) * _area(), "dmg": float(s.damage), "owner": c})
		_:
			fired = false
			if not triggered:
				c.cd = 1.0
	if fired and not triggered:
		c.cd = s.cooldown
	if fired:
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
		if kind != "hurt" and L.src != src:
			continue
		L.cd = float(D.links.kinds[kind].cooldown)
		link_queue.append({"L": L, "depth": depth + 1})


func _run_link_queue() -> void:
	var guard := 0
	while not link_queue.is_empty() and guard < 30:
		guard += 1
		var q: Dictionary = link_queue.pop_front()
		var L: Dictionary = q.L
		if not _active(L.dst):
			continue
		var from: Vector2 = paul.pos if L.kind == "hurt" else L.src.pos
		if _cast(L.dst, true, q.depth):
			link_count += 1
			link_fx.append({"a": from + Vector2(0, -8), "b": L.dst, "t": 0.0, "depth": q.depth})
			_ring_pop(L.dst.pos + Vector2(0, -8), C_GOLD, 12.0 + q.depth * 5.0)


func _link_card() -> Dictionary:
	var cands := []
	for c in comps:
		if c.level > 0 and c.engine != "" and c.follows == "":
			cands.append(c)
	if cands.size() < 2 or links.size() >= int(D.links.max_links):
		return {}
	cands.shuffle()
	var kinds: Array = D.links.kinds.keys()
	var kind: String = kinds[randi() % kinds.size()]
	var a: Dictionary = cands[0]
	var b: Dictionary = cands[1]
	var K: Dictionary = D.links.kinds[kind]
	var desc: String = K.desc % ([b.name] if kind == "hurt" else [a.name, b.name])
	return {"kind": "link", "key": kind, "src": a.key, "dst": b.key, "tag": "肢體",
		"title": "肢體連結：" + K.name, "desc": desc}


func _nova(c: Dictionary, s: Dictionary) -> void:
	if c.level == 0:
		return
	var center: Vector2 = c.pos + Vector2(0, -4)
	var r: float = s.radius * _area()
	blasts.append({"pos": center, "t": 0.0, "r": r, "col": Color("e8c8a0")})
	shake = maxf(shake, 0.12)
	for e in enemies:
		if not e.dead and e.pos.distance_to(center) < r + (8.0 if e.get("boss", false) else 0.0):
			_hurt(e, s.damage, center, c)
			if not e.get("boss", false):
				e.knock += (e.pos - center).normalized() * float(s.knock)


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
			_hurt(o, s.damage * (s.lies_mult if o.type == "lies" else 1.0), from, src)
	beams.append({"pos": from, "dir": dir, "life": 0.3 if look == "" else 0.5, "len": length, "width": width, "look": look})
	if s.burst:
		var end: Vector2 = from + dir * length
		var br := 20.0 * _area()
		blasts.append({"pos": end, "t": 0.0, "r": br})
		for o in enemies:
			if o.pos.distance_to(end) < br:
				_hurt(o, s.damage, end, src)


func _update_projectiles(dt: float) -> void:
	for b in bolts:
		var tg: Dictionary = b.target
		if tg.dead:
			var nxt := _nearest_enemies(b.pos, 60.0, 1, b.hit)
			if nxt.is_empty():
				b.life = 0.0
				continue
			b.target = nxt[0]
			tg = b.target
		var to: Vector2 = tg.pos - b.pos
		b.pos += to.normalized() * b.spd * dt
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
				_hurt(e, r.dmg, center, c)
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
			blasts.append({"pos": f.pos, "t": 0.0, "r": f.r, "col": C_FLAME})
			_burst(f.pos, 8, C_FLAME, C_GOLD)
			for e in enemies:
				if not e.dead and e.pos.distance_to(f.pos) < f.r + (8.0 if e.get("boss", false) else 0.0):
					_hurt(e, f.dmg, f.pos, f.owner)
	fires = fires.filter(func(f): return f.t > -0.35)
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
				_hurt(e, D.fever.final_damage, fb.pos)
	fever_bursts = fever_bursts.filter(func(fb): return fb.r < D.fever.final_radius)

	for s in shots:
		s.pos += s.vel * dt
		s.life -= dt
		if s.pos.distance_to(paul.pos + Vector2(0, -6)) < 5.0 and paul.inv <= 0.0:
			var belt: int = armor.get("belt", 0)
			if belt < 3:
				_damage_paul(D.enemies.lies.shoot.damage * (1.0 - 0.3 * belt))
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
		e.pos += e.knock * dt
		e.knock *= 0.85
		if e.stun > 0.0:
			e.stun -= dt
			continue
		var target: Vector2 = p.pos + Vector2(0, -4)
		if e.type == "fear":
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
				shots.append({"pos": e.pos, "vel": dir * sh.speed, "life": 3.0})
				e.shoot = sh.every
		var wob: float = sin(t * 2.2 + e.ph) * 0.5
		e.pos += (dir * go + dir.orthogonal() * wob) * d.speed * dt

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
					_damage_companion(c, d.damage)
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
			_damage_paul(d.damage)
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
	paul.hp -= n
	paul.inv = 0.6
	shake = 0.12
	_fire_links("hurt", null, 0)
	if paul.hp <= 0.0:
		paul.hp = 0.0
		_game_over()


func _damage_companion(c: Dictionary, n: float) -> void:
	if c.hurt_cd > 0.0:
		return
	c.hp -= n
	c.hurt_cd = 0.4
	_fire_links("hurt", null, 0)
	if c.hp <= 0.0:
		c.hp = 0.0
		c.down = D.companion_rules.down_seconds
		c.vel = Vector2.ZERO
		if t < 300.0:
			someone_down = true


# ---------- 場景物件（依區塊生成） ----------
func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h) / 4294967296.0


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
			for k in 3:
				var h := _hash(cx * 7 + k * 131, cy * 13 + k * 71)
				if h > 0.5:
					continue
				var wx := cx * CHUNK + floori(_hash(cx + k * 17, cy * 3 + 1) * CHUNK)
				var wy := cy * CHUNK + floori(_hash(cx * 5 + 2, cy + k * 29) * CHUNK)
				if Vector2(wx, wy).length() < 50.0:
					continue
				var v3 := 1 + floori(_hash(cx, cy + k) * 3)
				var key2 := ("tree_%d" % v3) if h < 0.17 else (("rock_%d" % v3) if h < 0.32 else "bush")
				var t2 := _tex(key2)
				var s := _sprite(key2, Vector2(-t2.get_width() / 2, -t2.get_height()))
				s.position = Vector2(wx, wy)
				items.append(s)
			chunks[key] = items
	for key in chunks.keys():
		if not keep.has(key):
			for s in chunks[key]:
				s.queue_free()
			chunks.erase(key)


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
	p.node.texture = _tex("paul_%d" % (walk if p.moving else 0))
	p.node.position = p.pos.round()
	p.node.modulate.a = 0.4 if p.inv > 0.0 and int(t * 20.0) % 2 == 1 else 1.0
	for c in comps:
		if c.level == 0:
			continue
		var f: int = (walk + c.i) % 2 if (p.moving or c.vel.length() > 5.0) and c.down <= 0.0 else 0
		c.node.texture = _tex("%s_%d" % [c.key, f])
		c.node.position = c.pos.round()
		c.node.rotation = deg_to_rad(80.0) if c.down > 0.0 else 0.0
		if c.down > 0.0:
			c.node.modulate = Color(0.55, 0.55, 0.6)
		elif c.sleep > 0.0:
			c.node.modulate = Color(0.6, 0.65, 0.85)
		else:
			c.node.modulate = Color.WHITE
	var ef := int(t * 4.0) % 2
	for e in enemies:
		if not e.get("boss", false):
			e.node.texture = _tex("%s_%d" % [e.sprite, (ef + int(e.ph)) % 2])
		e.node.position = e.pos.round()
		if e.flash > 0.0:
			e.node.modulate = Color(4, 4, 3.5)
		elif e.stun > 0.0 or (e.get("boss", false) and e.state == "break"):
			e.node.modulate = Color(1.5, 1.5, 0.8)
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
		"time": int(t), "kills": kills, "meter": meter, "fever": fever, "fever_kills": fever_kills, "over": over, "choosing": choosing or chest_open, "build": build_text})


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
	var barn = by_key.get("barn")
	if barn != null and _active(barn):
		var pulse := fmod(t, 1.6) / 1.6
		var bc: Vector2 = barn.pos.round() + Vector2(0, -2)
		var col := C_GOLD if fever > 0.0 else Color("bfe3ff")
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
	var tw := int(t * 6.0)
	for g in gems:
		var x: float = roundf(g.pos.x)
		var y: float = roundf(g.pos.y) - roundf(sin(t * 4.0 + g.pos.x) * 1.0)
		n.draw_rect(Rect2(x - 1, y - 3, 3, 7), Color("10202c"))
		n.draw_rect(Rect2(x - 2, y - 2, 5, 5), Color("10202c"))
		n.draw_rect(Rect2(x - 3, y - 1, 7, 3), Color("10202c"))
		n.draw_rect(Rect2(x, y - 2, 1, 5), C_SKY)
		n.draw_rect(Rect2(x - 2, y, 5, 1), C_SKY)
		n.draw_rect(Rect2(x - 1, y - 1, 3, 3), C_SKY)
		n.draw_rect(Rect2(x - 1, y - 1, 1, 1), Color.WHITE)
		if (tw + int(g.pos.x)) % 7 == 0:
			n.draw_rect(Rect2(x + 2, y - 4, 1, 1), Color.WHITE)
			n.draw_rect(Rect2(x - 3, y + 2, 1, 1), Color.WHITE)


func _draw_air() -> void:
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
			n.draw_rect(Rect2(x - 4, y - h - 1 + r, 9, 1), col)
	for r in rings:
		if r.r <= 0.0:
			continue
		var k: float = 1.0 - r.r / r.max
		var center: Vector2 = (r.owner.pos + Vector2(0, -6)).round()
		var col := (C_FLAME if on_fire else C_GOLD) if k > 0.4 or r.dir < 0.0 else Color("e0b860")
		var inner := C_RED if on_fire else C_CREAM
		if r.look == "horn":
			col = C_FLAME if on_fire else Color("e8e0d0")
			inner = Color("a89878")
		_dot_ring(n, center, r.r, 0.8, col, 2.0 if r.thick > 1 else 2.5, r.r * 0.05, r.thick)
		_dot_ring(n, center, r.r - 3.0, 0.8, inner, 5.0, 0.0)
	for b in beams:
		var end: Vector2 = b.pos + b.dir * b.len
		var a := minf(1.0, b.life * 3.3)
		if b.look == "sea":
			n.draw_line(b.pos, end, Color(C_FLAME if on_fire else Color("2f78c8"), a * 0.5), b.width * 1.6)
			n.draw_line(b.pos, end, Color(Color("8fd0ff"), a * 0.8), b.width * 0.8)
			n.draw_line(b.pos, end, Color(Color("eaf8ff"), a), 1.0)
		else:
			n.draw_line(b.pos, end, Color(C_FLAME if on_fire else Color("3fbfb0"), a * 0.6), b.width * 1.4)
			n.draw_line(b.pos, end, Color(C_CREAM, a), maxf(1.0, b.width * 0.4))
	for b in blasts:
		var k: float = b.t / 0.3
		n.draw_circle(b.pos, b.r * (0.4 + k * 0.6), Color(b.get("col", C_GOLD), (1.0 - k) * 0.6))
	for f in fires:
		if f.t > 0.0:
			var k: float = 1.0 - f.t / f.max
			n.draw_arc(f.pos, f.r, 0.0, TAU, 24, Color(C_FLAME, 0.4 + 0.5 * k), 1.0)
			n.draw_circle(f.pos, f.r * k, Color(C_FLAME, 0.18))
		else:
			var a: float = 1.0 + f.t / 0.35
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
	for fb in fever_bursts:
		_dot_ring(n, fb.pos.round() + Vector2(0, -4), fb.r, 0.8, C_GOLD, 2.0, 0.0, 2)
		_dot_ring(n, fb.pos.round() + Vector2(0, -4), fb.r - 4.0, 0.8, C_FLAME, 3.0, 0.3, 2)
	for f in link_fx:
		var to: Vector2 = f.b.pos + Vector2(0, -8)
		if f.t < 0.3:
			var a: float = 1.0 - f.t / 0.3
			# 從來源射向被觸發的人：前 0.08 秒線往前長出去
			var tip: Vector2 = f.a.lerp(to, minf(1.0, f.t / 0.08))
			n.draw_line(f.a, tip, Color(C_FLAME if f.depth >= 2 else C_GOLD, a * 0.8), 2.0 + f.depth)
			n.draw_line(f.a, tip, Color(C_CREAM, a), 1.0)
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
		var col := C_FLAME if on_fire else C_GOLD
		if b.look == "stone":
			var sz: int = 3 if b.size >= 2 else 2
			n.draw_rect(Rect2(x - 1, y - 1, sz + 1, sz + 1), Color("2a2030"))
			n.draw_rect(Rect2(x, y - 1, sz, sz), Color("d8d0c0") if not on_fire else C_FLAME)
			n.draw_rect(Rect2(x, y - 1, 1, 1), Color.WHITE)
		elif b.size >= 2:
			n.draw_rect(Rect2(x - 2, y - 1, 5, 3), col)
			n.draw_rect(Rect2(x - 1, y - 2, 3, 5), col)
			n.draw_rect(Rect2(x - 1, y - 1, 3, 3), Color.WHITE)
		else:
			n.draw_rect(Rect2(x - 1, y, 3, 1), col)
			n.draw_rect(Rect2(x, y - 1, 1, 3), col)
			n.draw_rect(Rect2(x, y, 1, 1), Color.WHITE)
	for s in shots:
		n.draw_rect(Rect2(roundf(s.pos.x) - 1, roundf(s.pos.y) - 1, 3, 3), Color("c8e070"))
		n.draw_rect(Rect2(roundf(s.pos.x), roundf(s.pos.y), 1, 1), Color("2a2638"))
	for h in heals:
		if h.t > 0.75:
			continue
		var x: float = roundf(h.who.pos.x)
		var y: float = roundf(h.who.pos.y) - 17.0 - roundf(h.t * 8.0)
		n.draw_rect(Rect2(x - 1, y, 3, 1), C_HEAL)
		n.draw_rect(Rect2(x, y - 1, 1, 3), C_HEAL)
	for q in parts:
		n.draw_rect(Rect2(roundf(q.pos.x), roundf(q.pos.y), 1, 1), q.c1 if q.life > q.max * 0.5 else q.c2)
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
	joy.on = false
	ui.joy.on = false
	var results := []
	for evo in D.evolutions:
		var c: Dictionary = by_key[evo.companion]
		if c.level >= 5 and fruits.has(evo.fruit) and not evolved.has(c.key):
			evolved[c.key] = evo
			run_evolutions += 1
			if evo.has("stats"):
				c.st.merge(evo.stats, true)
			if evo.has("every") and quake_key == "":
				quake_key = c.key
				evo_timer = 2.0
			_ring_pop(c.pos + Vector2(0, -8), C_GOLD, 40.0)
			results.append({"title": "進化！" + evo.name, "desc": evo.desc, "big": true})
			break
	if results.is_empty():
		var n := randi_range(int(D.chest.rolls_min), int(D.chest.rolls_max))
		for i in n:
			var pool := _make_cards().filter(func(card): return card.kind != "heal")
			if pool.is_empty():
				pool = [{"kind": "heal", "key": "", "title": "五餅二魚", "desc": "保羅回復 %d 血" % int(D.leveling.heal_card)}]
			var card: Dictionary = pool[randi() % pool.size()]
			_apply_card(card)
			results.append({"title": card.title, "desc": card.desc, "big": false})
	_refresh_build_text()
	ui.do_flash(0.4)
	ui.show_chest(results)


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
	shake = 0.45
	ui.do_flash(0.35)
	ui.show_banner(evo.name, 1.2)


# ---------- Boss ----------
func _boss_tex() -> Texture2D:
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


func _spawn_boss() -> void:
	boss_spawned = true
	var B: Dictionary = D.boss
	var s := Sprite2D.new()
	s.texture = _boss_tex()
	s.centered = false
	s.offset = Vector2(-20, -30)
	world.add_child(s)
	boss = {"type": "boss", "boss": true, "d": {"name": B.name, "damage": B.touch_damage}, "pos": _edge_point(-30.0),
		"hp": float(B.hp), "max_hp": float(B.hp), "ph": 0.0, "flash": 0.0, "stun": 0.0, "cd": 0.0, "bcd": 0.0, "r": 14.0,
		"sprite": "boss", "tint": Color.WHITE, "knock": Vector2.ZERO, "dead": false, "node": s,
		"state": "move", "timer": 2.5, "pattern_i": 0, "pattern": ""}
	enemies.append(boss)
	ui.show_banner("Boss：" + B.name, 2.5)


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
				var order := ["sweep", "slam", "grid", "hunt"]
				b.pattern = order[b.pattern_i % order.size()]
				b.pattern_i += 1
				tele = _make_tele(b)
				b.state = "warn"
				b.timer = B.warn * (0.7 if phase2 else 1.0)
		"warn":
			b.timer -= dt
			if b.timer <= 0.0:
				_resolve_tele()
				tele = []
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
		"task_witness": task_witness, "no_down": t - t_start >= 300.0 and not someone_down, "full_party": full_party, "party": party})
	var lines := [["帶回見證 +%d　（共 %d）" % [res.witness, Save.data.witness], 15, C_SKY]]
	for a in res.achievements:
		var txt: String = "見證錄：" + a.name
		if a.has("unlock"):
			txt += "　→　%s 加入名單！" % _comp_name(a.unlock)
		lines.append([txt, 13, C_GOLD])
	if not res.affinity_ups.is_empty():
		var names := []
		for k in res.affinity_ups:
			names.append(_comp_name(k))
		lines.append(["默契提升：" + "、".join(names) + "（解鎖新的生平）", 12, C_HEAL])
	return lines


func _comp_name(key: String) -> String:
	for d in D.companions:
		if d.key == key:
			return d.name
	return key


func _win() -> void:
	if won:
		return
	won = true
	over = true
	_record_run()
	tele = []
	joy.on = false
	ui.joy.on = false
	shake = 0.5
	ui.do_flash(0.8)
	var s := int(t)
	ui.show_game_over([
		["腓立比　通關", 26, C_GOLD],
		[D.boss.win_text, 13, C_CREAM],
		[D.boss.win_ref, 11, Color("c9a46b")],
		["用時 %02d:%02d　Lv.%d　驅散 %d" % [s / 60, s % 60, level, kills], 13, Color("f4ead2")],
	] + _finish_run(), "再走一次")


# ---------- 失敗 ----------
func _game_over() -> void:
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
	if smoke_shot != "" and link_fx.any(func(f): return f.depth >= 2 and f.t > 0.05 and f.t < 0.15) and not FileAccess.file_exists(smoke_shot.replace(".png", "_link.png")):
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_link.png"))
	if choosing and smoke_frames % 20 == 0:
		ui.card_ready_at = 0.0
		if smoke_shot != "" and not FileAccess.file_exists(smoke_shot.replace(".png", "_cards.png")):
			get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_cards.png"))
		ui.pick(randi() % 3)
	if meter >= 1.0 and fever <= 0.0 and not smoke_nofever:
		_start_fever()
	if smoke_frames % 300 == 0:
		var party := []
		for c in comps:
			if c.level > 0:
				party.append("%s%d" % [c.key, c.level])
		print("links fired=%d" % link_count)
		print("t=%.1f hp=%.0f Lv=%d enemies=%d kills=%d fever=%.1f boss=%s party=%s fruits=%s armor=%s evo=%s" % [t, paul.hp, level, enemies.size(), kills, fever,
			("%.0f/%s" % [boss.hp, boss.state]) if boss != null else "-", party, fruits, armor, evolved.keys()])
	if smoke_shot != "" and fever > 0.0 and fever < D.fever.duration - 1.5 and not FileAccess.file_exists(smoke_shot.replace(".png", "_fever.png")):
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_fever.png"))
	if smoke_shot != "" and smoke_frames == 1700:
		get_viewport().get_texture().get_image().save_png(smoke_shot)
	if smoke_frames >= 1800:
		print("SMOKE DONE t=%.1f fps=%d" % [t, Engine.get_frames_per_second()])
		get_tree().quit()
