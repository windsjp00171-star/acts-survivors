extends Node2D
## 主遊戲：移動、同伴招募與升級、自動攻擊、四種敵人與打散、同心合意與五旬節 FEVER、失敗。
## 數值全部來自 data/game.json。

const ZOOM := 2.0
const CHUNK := 96
const SEP_CELL := 8.0
const DATA_PATH := "res://data/game.json"

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

var paul := {}
var comps: Array = []
var by_key := {}
var enemies: Array = []
var bolts: Array = []
var rings: Array = []
var beams: Array = []
var blasts: Array = []
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


func _ready() -> void:
	D = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	for a in OS.get_cmdline_user_args():
		if a == "--smoke":
			smoke = true
		elif a.begins_with("--shot="):
			smoke_shot = a.substr(7)
		elif a.begins_with("--t0="):
			t = float(a.substr(5))
	for k in D.enemies:
		scatter_by[k] = 0
	xp_need = int(D.leveling.first)
	_build_world()
	_build_ui()
	for key in D.start_party:
		_recruit(by_key[key])
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
		var home := Vector2(d.home[0], d.home[1])
		var c := {"key": d.key, "name": d.name, "skill": d.skill, "tag": d.tag, "i": i, "home": home,
			"base": home, "pos": home, "off": Vector2.ZERO, "vel": Vector2.ZERO, "level": 0, "st": {},
			"cd": 0.3 + i * 0.2, "sleep": 0.0, "alert": 0.0,
			"hp": float(D.companion_rules.hp), "down": 0.0, "hurt_cd": 0.0,
			"with": d.get("with", ""), "follows": d.get("follows", ""),
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
	ui.fever_pressed.connect(_start_fever)
	ui.restart_pressed.connect(func(): get_tree().reload_current_scene())


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
	_set_level(c, 1)
	c.base = paul.pos + c.home + Vector2(randf_range(-30, 30), 40)
	c.pos = c.base
	c.node.visible = true
	if c.with != "":
		_recruit(by_key[c.with])


func _active_in_party(c: Dictionary) -> bool:
	return c.level > 0


func _make_cards() -> Array:
	var pool := []
	for c in comps:
		if c.follows != "" or c.skill == "":
			continue
		var desc: Array = D.skills[c.skill].desc
		if c.level == 0:
			var nm: String = c.name + ("・" + by_key[c.with].name if c.with != "" else "")
			pool.append({"kind": "recruit", "key": c.key, "title": nm + "　加入", "tag": c.tag, "desc": desc[0]})
		elif c.level < 5:
			pool.append({"kind": "up", "key": c.key, "title": "%s　Lv%d → %d" % [c.name, c.level, c.level + 1], "tag": c.tag, "desc": desc[c.level]})
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
	ui.show_cards(pending_cards, Time.get_ticks_msec() / 1000.0, D.leveling.card_delay)


func _on_card(i: int) -> void:
	var card: Dictionary = pending_cards[i]
	if card.kind == "recruit":
		_recruit(by_key[card.key])
	elif card.kind == "up":
		var c: Dictionary = by_key[card.key]
		_set_level(c, c.level + 1)
		_ring_pop(c.pos + Vector2(0, -6), C_GOLD, 30.0)
	else:
		paul.hp = minf(D.paul.hp, paul.hp + D.leveling.heal_card)
	choosing = false
	if xp >= xp_need:
		_level_up()


# ---------- 輸入 ----------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if over and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			get_tree().reload_current_scene()
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
		"cd": 0.0, "bcd": 0.0, "shoot": (d.shoot.every * randf()) if d.has("shoot") else 0.0,
		"knock": Vector2.ZERO, "dead": false, "node": _sprite(type + "_0", Vector2(-10, -13))}
	enemies.append(e)


func _hurt(e: Dictionary, dmg: float, from := Vector2.INF) -> void:
	if e.dead:
		return
	if fever > 0.0:
		dmg *= 1.5
	e.hp -= dmg
	e.flash = 0.08
	if from != Vector2.INF:
		e.knock += (e.pos - from).normalized() * 40.0
	_burst(e.pos, 2, C_CREAM, C_GOLD)
	if e.hp <= 0:
		_kill(e, true)


func _kill(e: Dictionary, by_player: bool) -> void:
	e.dead = true
	e.node.queue_free()
	if by_player:
		kills += 1
		gems.append({"pos": e.pos, "got": false})
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
	if not over and not choosing:
		t += dt
		_step(dt)
	_render(dt)
	if smoke:
		_smoke_tick()


func _step(dt: float) -> void:
	var p := paul
	var mv := _move_vector()
	p.pos += mv * D.paul.speed * dt
	p.moving = mv.length() > 0.05
	p.inv = maxf(0.0, p.inv - dt)

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
		var k := minf(1.0, dt * 5.0)
		var target: Vector2 = p.pos + c.home + Vector2(sin(t * 0.7 + c.i * 1.7) * 2.0, cos(t * 0.9 + c.i * 1.3) * 1.5)
		if c.down <= 0.0:
			c.base += (target - c.base) * k
		var spring := 6.0
		if barn_on and barn.st.pull and c.pos.distance_to(barn.pos) < barn.st.radius * 1.4:
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
				c.hp = rules.hp * rules.revive_hp
		if _active(c):
			together += 1

	# 同心合意
	if fever > 0.0:
		fever -= dt
		meter = clampf(fever / D.fever.duration, 0.0, 1.0)
		if fever <= 0.0:
			_end_fever()
	elif party > 0:
		meter = minf(1.0, meter + dt / D.fever.fill_seconds * (float(together) / party))

	_companion_skills(dt)
	_update_projectiles(dt)
	_update_enemies(dt)

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

	if xp >= xp_need and not over:
		_level_up()


func _companion_skills(dt: float) -> void:
	var barn = by_key.get("barn")
	var barn_on: bool = barn != null and _active(barn)
	var speed_mult: float = D.fever.attack_speed if fever > 0.0 else 1.0
	for c in comps:
		if c.skill == "" or not _active(c):
			continue
		var s: Dictionary = c.st
		var mult := speed_mult
		if barn_on and c != barn and c.pos.distance_to(barn.pos) < barn.st.radius:
			mult *= barn.st.attack_speed
		c.cd -= dt * mult
		if c.cd > 0.0:
			continue
		match c.skill:
			"bolt":
				var targets := _nearest_enemies(c.pos, s.range, int(s.count))
				if targets.size() > 0:
					for i in int(s.count):
						var tg: Dictionary = targets[i % targets.size()]
						bolts.append({"pos": c.pos + Vector2(0, -8), "target": tg, "life": 1.5, "pierce": int(s.pierce),
							"split": int(s.split), "child": false, "dmg": float(s.damage), "size": int(s.size), "hit": {}})
					c.cd = s.cooldown
			"ring":
				for i in int(s.rings):
					rings.append({"owner": c, "r": 4.0 - i * 16.0, "dir": 1.0, "returns": int(s.returns), "hit": {},
						"max": float(s.max_radius), "dmg": float(s.damage), "speed": float(s.speed), "stun": float(s.stun), "thick": int(s.thick)})
				c.cd = s.cooldown
			"heal":
				paul.hp = minf(D.paul.hp, paul.hp + s.amount)
				heals.append({"who": paul, "t": 0.0})
				for o in comps:
					if o.level == 0:
						continue
					if o.down > 0.0 and s.instant_revive:
						o.down = 0.0
						o.hp = D.companion_rules.hp * D.companion_rules.revive_hp
					if o.down <= 0.0:
						o.hp = minf(D.companion_rules.hp, o.hp + s.amount)
						heals.append({"who": o, "t": 0.0})
				c.cd = s.cooldown
			"beam":
				var tg_list := _nearest_enemies(c.pos, s.range, 1)
				if tg_list.size() > 0:
					var from: Vector2 = c.pos + Vector2(0, -7)
					var base_dir: Vector2 = (tg_list[0].pos - from).normalized()
					var n := int(s.beams)
					for b in n:
						var ang := (b - (n - 1) / 2.0) * deg_to_rad(28.0)
						var dir := base_dir.rotated(ang)
						_fire_beam(from, dir, s)
					c.cd = s.cooldown
			_:
				c.cd = 1.0


func _fire_beam(from: Vector2, dir: Vector2, s: Dictionary) -> void:
	for o in enemies:
		var rel: Vector2 = o.pos - from
		var along: float = rel.dot(dir)
		var across: float = absf(rel.cross(dir))
		if along > 0.0 and along < s.length and across < s.width:
			_hurt(o, s.damage * (s.lies_mult if o.type == "lies" else 1.0), from)
	beams.append({"pos": from, "dir": dir, "life": 0.3, "len": float(s.length), "width": float(s.width)})
	if s.burst:
		var end: Vector2 = from + dir * s.length
		blasts.append({"pos": end, "t": 0.0, "r": 20.0})
		for o in enemies:
			if o.pos.distance_to(end) < 20.0:
				_hurt(o, s.damage, end)


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
		var spd: float = by_key.tim.st.speed if by_key.has("tim") else 200.0
		b.pos += to.normalized() * spd * dt
		b.life -= dt
		if to.length() < 4.0:
			b.hit[tg.node] = true
			_hurt(tg, b.dmg, b.pos - to)
			if b.split > 0 and not b.child:
				for o in _nearest_enemies(b.pos, 70.0, b.split, b.hit):
					bolts.append({"pos": b.pos, "target": o, "life": 0.8, "pierce": 0, "split": 0, "child": true,
						"dmg": maxf(1.0, b.dmg / 2.0), "size": 1, "hit": b.hit.duplicate()})
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
			if not e.dead and not r.hit.has(e.node) and absf(center.distance_to(e.pos) - r.r) < 3.0 + r.thick * 2.0:
				r.hit[e.node] = true
				if r.stun > 0.0:
					e.stun = r.stun
				_hurt(e, r.dmg, center)
	rings = rings.filter(func(r): return not r.get("dead", false))

	for b in beams:
		b.life -= dt
	beams = beams.filter(func(b): return b.life > 0.0)
	for b in blasts:
		b.t += dt
	blasts = blasts.filter(func(b): return b.t < 0.3)
	for h in heals:
		h.t += dt
	heals = heals.filter(func(h): return h.t < 0.9)

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
			_damage_paul(D.enemies.lies.shoot.damage)
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
		var d: Dictionary = e.d
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
				e.knock += (e.pos - p.pos).normalized() * pri.st.knockback * 6.0
				e.bcd = 0.5
				_hurt(e, pri.st.damage)
		if e.dead:
			continue

		# 碰到同伴：打散、受傷、睡著
		if e.cd <= 0.0:
			for c in comps:
				if c.level == 0 or c.down > 0.0 or c.pos.distance_to(e.pos + Vector2(0, 5)) > 6.0:
					continue
				var shielded: bool = fever > 0.0 or (e.type == "fear" and barn_on and barn.st.fear_immune and c.pos.distance_to(barn.pos) < barn.st.radius)
				var out: Vector2 = (c.pos - p.pos).normalized()
				if d.scatter > 0 and not shielded:
					c.vel += out * d.scatter
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
		if p.pos.distance_to(e.pos + Vector2(0, 5)) < 6.0 and p.inv <= 0.0:
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
		if e.dead:
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
	if fever > 0.0:
		return
	paul.hp -= n
	paul.inv = 0.6
	shake = 0.12
	if paul.hp <= 0.0:
		paul.hp = 0.0
		_game_over()


func _damage_companion(c: Dictionary, n: float) -> void:
	if c.hurt_cd > 0.0:
		return
	c.hp -= n
	c.hurt_cd = 0.4
	if c.hp <= 0.0:
		c.hp = 0.0
		c.down = D.companion_rules.down_seconds
		c.vel = Vector2.ZERO


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
		e.node.texture = _tex("%s_%d" % [e.type, (ef + int(e.ph)) % 2])
		e.node.position = e.pos.round()
		if e.flash > 0.0:
			e.node.modulate = Color(4, 4, 3.5)
		elif e.stun > 0.0:
			e.node.modulate = Color(1.4, 1.4, 0.8)
		else:
			e.node.modulate = Color.WHITE

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
	ui.update_hud({"hp_frac": clampf(p.hp / D.paul.hp, 0.0, 1.0), "level": level, "xp_frac": clampf(float(xp) / xp_need, 0.0, 1.0),
		"time": int(t), "kills": kills, "meter": meter, "fever": fever, "fever_kills": fever_kills, "over": over, "choosing": choosing})


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
		_dot_ring(n, bc, barn.st.radius, 0.62, Color(col, 0.9), 3.0, t * 0.8)
		_dot_ring(n, bc, barn.st.radius * pulse, 0.62, Color(col.lightened(0.4), 0.8), 4.0, -t)
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
		_dot_ring(n, center, r.r, 0.8, col, 2.0 if r.thick > 1 else 2.5, r.r * 0.05, r.thick)
		_dot_ring(n, center, r.r - 3.0, 0.8, C_RED if on_fire else C_CREAM, 5.0, 0.0)
	for b in beams:
		var end: Vector2 = b.pos + b.dir * b.len
		var a := minf(1.0, b.life * 3.3)
		n.draw_line(b.pos, end, Color(C_FLAME if on_fire else Color("3fbfb0"), a * 0.6), b.width * 1.4)
		n.draw_line(b.pos, end, Color(C_CREAM, a), maxf(1.0, b.width * 0.4))
	for b in blasts:
		var k: float = b.t / 0.3
		n.draw_circle(b.pos, b.r * (0.4 + k * 0.6), Color(C_GOLD, (1.0 - k) * 0.6))
	for fb in fever_bursts:
		_dot_ring(n, fb.pos.round() + Vector2(0, -4), fb.r, 0.8, C_GOLD, 2.0, 0.0, 2)
		_dot_ring(n, fb.pos.round() + Vector2(0, -4), fb.r - 4.0, 0.8, C_FLAME, 3.0, 0.3, 2)
	for b in bolts:
		var x: float = roundf(b.pos.x)
		var y: float = roundf(b.pos.y)
		var col := C_FLAME if on_fire else C_GOLD
		if b.size >= 2:
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
	var max_hp: float = D.companion_rules.hp
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
	ui.show_game_over([
		["旅程中斷", 26, C_GOLD],
		["四面受敵，卻不被困住；心裡作難，卻不至失望；\n遭逼迫，卻不被丟棄；打倒了，也不至死亡。", 13, C_CREAM],
		["林後 4:8–9", 11, Color("c9a46b")],
		["撐了 %02d:%02d　Lv.%d　驅散 %d\n最常被「%s」打散" % [s / 60, s % 60, level, kills, who], 13, Color("f4ead2")],
	])


# ---------- 自動測試 ----------
func _smoke_tick() -> void:
	smoke_frames += 1
	if choosing and smoke_frames % 20 == 0:
		ui.card_ready_at = 0.0
		if smoke_shot != "" and not FileAccess.file_exists(smoke_shot.replace(".png", "_cards.png")):
			get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_cards.png"))
		ui.pick(randi() % 3)
	if meter >= 1.0 and fever <= 0.0:
		_start_fever()
	if smoke_frames % 300 == 0:
		var party := []
		for c in comps:
			if c.level > 0:
				party.append("%s%d" % [c.key, c.level])
		print("t=%.1f hp=%.0f Lv=%d enemies=%d kills=%d fever=%.1f party=%s" % [t, paul.hp, level, enemies.size(), kills, fever, party])
	if smoke_shot != "" and fever > 0.0 and fever < D.fever.duration - 1.5 and not FileAccess.file_exists(smoke_shot.replace(".png", "_fever.png")):
		get_viewport().get_texture().get_image().save_png(smoke_shot.replace(".png", "_fever.png"))
	if smoke_shot != "" and smoke_frames == 1700:
		get_viewport().get_texture().get_image().save_png(smoke_shot)
	if smoke_frames >= 1800:
		print("SMOKE DONE t=%.1f fps=%d" % [t, Engine.get_frames_per_second()])
		get_tree().quit()
