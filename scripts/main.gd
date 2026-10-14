extends Node2D
## 主遊戲（里程碑 1）：移動、同伴群聚跟隨與自動攻擊、四種敵人與打散、各自血條、失敗。
## 數值全部來自 data/game.json。

const ZOOM := 2.0
const CHUNK := 96
const SEP_CELL := 8.0
const DATA_PATH := "res://data/game.json"

const C_INK := Color("f4ead2")
const C_GOLD := Color("ffd75e")
const C_CREAM := Color("fff4c2")
const C_SKY := Color("7ec8e3")
const C_HEAL := Color("7be08a")
const C_RED := Color("e8481c")
const C_BRONZE := Color("c9a46b")
const C_VL := Color("6b3a8c")

var D: Dictionary
var tex := {}
var t := 0.0
var kills := 0
var xp := 0
var over := false
var spawn_timer := 0.0
var scatter_by := {}
var shake := 0.0

var paul := {}
var comps: Array = []
var by_key := {}
var enemies: Array = []
var bolts: Array = []
var rings: Array = []
var beams: Array = []
var shots: Array = []
var gems: Array = []
var parts: Array = []
var heals: Array = []
var chunks := {}
var chunk_timer := 0.0
var joy := {"on": false, "index": -1, "origin": Vector2.ZERO, "pos": Vector2.ZERO}

var world: Node2D
var ground: Sprite2D
var ground_fx: Node2D
var air: Node2D
var cam: Camera2D
var ui: Control
var joy_pad: Control
var hp_fill: ColorRect
var xp_label: Label
var time_label: Label
var kill_label: Label
var hint_label: Label
var name_labels: Array = []
var font: SystemFont

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
	_build_world()
	_build_ui()
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

	paul = {"pos": Vector2.ZERO, "hp": float(D.paul.hp), "inv": 0.0, "moving": false,
		"node": _sprite("paul_0", Vector2(-7, -17))}
	var i := 0
	for d in D.companions:
		var home := Vector2(d.home[0], d.home[1])
		var c := {"key": d.key, "name": d.name, "skill": d.skill, "i": i, "home": home,
			"base": home, "pos": home, "off": Vector2.ZERO, "vel": Vector2.ZERO,
			"cd": 0.3 + i * 0.3, "sleep": 0.0, "alert": 0.0,
			"hp": float(D.companion_rules.hp), "down": 0.0, "hurt_cd": 0.0,
			"node": _sprite(d.key + "_0", Vector2(-7, -17))}
		comps.append(c)
		by_key[d.key] = c
		i += 1


func _label(text: String, size: int, color: Color, outline := 4) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = Color("140c10")
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(l)
	return l


func _build_ui() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK TC", "Noto Sans TC", "Microsoft JhengHei", "PingFang TC", "Heiti TC", "sans-serif"])
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)

	var hp_name := _label(D.paul.name, 13, C_GOLD)
	hp_name.position = Vector2(12, 4)
	var bg := ColorRect.new()
	bg.color = Color("0b080d")
	bg.position = Vector2(10, 26)
	bg.size = Vector2(124, 9)
	ui.add_child(bg)
	hp_fill = ColorRect.new()
	hp_fill.color = C_HEAL
	hp_fill.position = Vector2(12, 28)
	hp_fill.size = Vector2(120, 5)
	ui.add_child(hp_fill)
	xp_label = _label("經驗 0", 11, C_SKY)
	xp_label.position = Vector2(12, 38)
	time_label = _label("00:00", 16, C_CREAM)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kill_label = _label("驅散 0", 13, C_INK)
	kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	for c in [paul] + comps:
		var n := _label(D.paul.name if c == paul else c.name, 10, C_GOLD if c == paul else C_INK, 3)
		n.modulate.a = 0.85
		name_labels.append(n)

	var touch := DisplayServer.is_touchscreen_available()
	hint_label = _label("按住畫面下方拖曳來移動" if touch else "WASD／方向鍵移動（觸控：按住畫面下方拖曳）", 12, C_CREAM)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	joy_pad = Control.new()
	joy_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_pad.draw.connect(_draw_joy)
	ui.add_child(joy_pad)


# ---------- 輸入 ----------
func _unhandled_input(event: InputEvent) -> void:
	if over:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			get_tree().reload_current_scene()
		return
	var h := get_viewport().get_visible_rect().size.y
	if event is InputEventScreenTouch:
		if event.pressed and event.position.y > h * 0.3 and not joy.on:
			joy = {"on": true, "index": event.index, "origin": event.position, "pos": event.position}
		elif not event.pressed and event.index == joy.index:
			joy.on = false
	elif event is InputEventScreenDrag and joy.on and event.index == joy.index:
		joy.pos = event.position


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
	var w: Dictionary = D.waves
	var type := _pick_type()
	var center := _edge_point(16.0)
	var n := randi_range(int(w.group_min), int(w.group_max))
	for i in n:
		if enemies.size() >= int(w.max_enemies):
			return
		_spawn_one(type, center + Vector2(randf_range(-10, 10), randf_range(-10, 10)))


func _spawn_one(type: String, at: Vector2) -> void:
	var d: Dictionary = D.enemies[type]
	var hp: float = ceilf(d.hp * (1.0 + D.waves.hp_per_minute * t / 60.0))
	var e := {"type": type, "d": d, "pos": at, "hp": hp, "ph": randf() * TAU, "flash": 0.0,
		"cd": 0.0, "bcd": 0.0, "shoot": (d.shoot.every * randf()) if d.has("shoot") else 0.0,
		"dead": false, "node": _sprite(type + "_0", Vector2(-10, -13))}
	enemies.append(e)


func _hurt(e: Dictionary, dmg: float) -> void:
	if e.dead:
		return
	e.hp -= dmg
	e.flash = 0.1
	_burst(e.pos, 3, C_CREAM, C_GOLD)
	if e.hp <= 0:
		_kill(e, true)


func _kill(e: Dictionary, by_player: bool) -> void:
	e.dead = true
	e.node.queue_free()
	_burst(e.pos, 8, C_VL, C_GOLD)
	if by_player:
		kills += 1
		gems.append({"pos": e.pos, "got": false})


func _burst(at: Vector2, n: int, c1: Color, c2: Color) -> void:
	for i in n:
		if parts.size() >= 500:
			return
		var a := randf() * TAU
		var s := 10.0 + randf() * 30.0
		parts.append({"pos": at, "vel": Vector2(cos(a) * s, sin(a) * s * 0.7 - 12.0), "life": 0.4 + randf() * 0.5, "max": 0.9, "c1": c1, "c2": c2})


func _nearest_enemy(from: Vector2, max_d: float):
	var best = null
	var bd := max_d
	for e in enemies:
		if e.dead:
			continue
		var d: float = from.distance_to(e.pos)
		if d < bd:
			bd = d
			best = e
	return best


func _active(c: Dictionary) -> bool:
	return c.off.length() < 10.0 and c.sleep <= 0.0 and c.down <= 0.0


func _barrier_pieces() -> Array:
	var out := []
	if not by_key.has("pri") or not _active(by_key.pri):
		return out
	var s: Dictionary = D.skills.tent
	var cyc: float = fmod(t, s.cycle) / s.cycle
	var up := 0.0
	if cyc < 0.07: up = cyc / 0.07
	elif cyc < 0.8: up = 1.0
	elif cyc < 0.87: up = 1.0 - (cyc - 0.8) / 0.07
	if up <= 0.0:
		return out
	for k in int(s.pieces):
		var a: float = t * 0.35 + k * TAU / s.pieces + 0.4
		out.append({"pos": paul.pos + Vector2(cos(a) * s.radius, 2.0 + sin(a) * s.radius * 0.8), "up": up})
	return out


# ---------- 主迴圈 ----------
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if not over:
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

	# 同伴：有延遲地跟隨＋被打散後彈回
	var rules: Dictionary = D.companion_rules
	for c in comps:
		var k := minf(1.0, dt * 5.0)
		var target: Vector2 = p.pos + c.home + Vector2(sin(t * 0.7 + c.i * 1.7) * 2.0, cos(t * 0.9 + c.i * 1.3) * 1.5)
		if c.down <= 0.0:
			c.base += (target - c.base) * k
		c.vel += (-6.0 * c.off - 4.0 * c.vel) * dt
		c.off += c.vel * dt
		c.pos = c.base + c.off
		c.sleep = maxf(0.0, c.sleep - dt)
		c.alert = maxf(0.0, c.alert - dt)
		c.hurt_cd = maxf(0.0, c.hurt_cd - dt)
		if c.down > 0.0:
			c.down -= dt
			if c.down <= 0.0:
				c.hp = rules.hp * rules.revive_hp

	_companion_skills(dt)
	_update_projectiles(dt)
	_update_enemies(dt)

	# 生成：一群一群，照曲線補到目標數量
	var w: Dictionary = D.waves
	var wave := _wave_now()
	spawn_timer -= dt
	if spawn_timer <= 0.0 and enemies.size() < mini(int(wave.x), int(w.max_enemies)):
		_spawn_group()
		spawn_timer = wave.y

	var G: Dictionary = D.gems
	for g in gems:
		var to: Vector2 = p.pos + Vector2(0, -6) - g.pos
		var d: float = to.length()
		if d < G.magnet_radius:
			g.pos += to.normalized() * G.magnet_speed * dt
		if d < 4.0:
			g.got = true
			xp += 1
	gems = gems.filter(func(g): return not g.got)
	if gems.size() > 300:
		gems = gems.slice(gems.size() - 300)

	for q in parts:
		q.pos += q.vel * dt
		q.vel.y += 20.0 * dt
		q.life -= dt
	parts = parts.filter(func(q): return q.life > 0.0)

	chunk_timer -= dt
	if chunk_timer <= 0.0:
		_update_chunks()
		chunk_timer = 0.4


func _companion_skills(dt: float) -> void:
	var S: Dictionary = D.skills
	var barn = by_key.get("barn")
	var barn_on: bool = barn != null and _active(barn)
	for c in comps:
		if c.skill == "" or not _active(c):
			continue
		var in_aura: bool = barn_on and c != barn and c.pos.distance_to(barn.pos) < S.aura.radius
		c.cd -= dt * (S.aura.attack_speed if in_aura else 1.0)
		if c.cd > 0.0:
			continue
		match c.skill:
			"bolt":
				var e = _nearest_enemy(c.pos, S.bolt.range)
				if e != null:
					bolts.append({"pos": c.pos + Vector2(0, -8), "target": e, "life": 1.5})
					c.cd = S.bolt.cooldown
			"ring":
				rings.append({"pos": c.pos + Vector2(0, -6), "r": 4.0, "hit": {}})
				c.cd = S.ring.cooldown
			"heal":
				paul.hp = minf(D.paul.hp, paul.hp + S.heal.amount)
				heals.append({"who": paul, "t": 0.0})
				for o in comps:
					if o.down <= 0.0:
						o.hp = minf(D.companion_rules.hp, o.hp + S.heal.amount)
						heals.append({"who": o, "t": 0.0})
				c.cd = S.heal.cooldown
			"beam":
				var e = _nearest_enemy(c.pos, S.beam.range)
				if e != null:
					var from: Vector2 = c.pos + Vector2(0, -7)
					var dir: Vector2 = (e.pos - from).normalized()
					for o in enemies:
						var rel: Vector2 = o.pos - from
						var along: float = rel.dot(dir)
						var across: float = absf(rel.cross(dir))
						if along > 0.0 and along < S.beam.length and across < S.beam.width:
							_hurt(o, S.beam.damage)
					beams.append({"pos": from, "dir": dir, "life": 0.25})
					c.cd = S.beam.cooldown
			_:
				c.cd = 1.0


func _update_projectiles(dt: float) -> void:
	var S: Dictionary = D.skills
	for b in bolts:
		var tg: Dictionary = b.target
		var to: Vector2 = tg.pos - b.pos
		b.pos += to.normalized() * S.bolt.speed * dt
		b.life -= dt
		if tg.dead:
			b.life = 0.0
		elif to.length() < 4.0:
			_hurt(tg, S.bolt.damage)
			b.life = 0.0
	bolts = bolts.filter(func(b): return b.life > 0.0)

	for r in rings:
		r.r += S.ring.speed * dt
		for e in enemies:
			if not e.dead and not r.hit.has(e.node) and absf(r.pos.distance_to(e.pos) - r.r) < 4.0:
				r.hit[e.node] = true
				_hurt(e, S.ring.damage)
	rings = rings.filter(func(r): return r.r < S.ring.max_radius)

	for b in beams:
		b.life -= dt
	beams = beams.filter(func(b): return b.life > 0.0)
	for h in heals:
		h.t += dt
	heals = heals.filter(func(h): return h.t < 0.9)

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
	var tent: Dictionary = D.skills.tent
	var view := _view_rect()
	for e in enemies:
		if e.dead:
			continue
		var d: Dictionary = e.d
		e.flash = maxf(0.0, e.flash - dt)
		e.cd = maxf(0.0, e.cd - dt)
		e.bcd = maxf(0.0, e.bcd - dt)
		var target: Vector2 = p.pos + Vector2(0, -4)
		if e.type == "fear":
			var bd := 1e9
			for c in comps:
				if c.down > 0.0:
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
				e.pos += (e.pos - p.pos).normalized() * tent.knockback
				e.bcd = 0.5
				_hurt(e, tent.damage)
		if e.dead:
			continue

		# 碰到同伴：打散、受傷、睡著
		if e.cd <= 0.0:
			for c in comps:
				if c.down > 0.0 or c.pos.distance_to(e.pos + Vector2(0, 5)) > 6.0:
					continue
				var out: Vector2 = (c.pos - p.pos).normalized()
				if d.scatter > 0:
					c.vel += out * d.scatter
					scatter_by[e.type] += 1
				if d.scatter > 50:
					c.alert = 0.9
				if d.has("sleep_for"):
					c.sleep = d.sleep_for
					scatter_by[e.type] += 1
				_damage_companion(c, d.damage)
				if d.dies_on_touch:
					_kill(e, false)
				else:
					e.cd = 0.7
					e.pos -= dir * 6.0
				break
		if e.dead:
			continue

		# 碰到保羅
		if p.pos.distance_to(e.pos + Vector2(0, 5)) < 6.0 and p.inv <= 0.0:
			_damage_paul(d.damage)
			e.pos -= dir * 10.0
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
		shake_off = Vector2(randf_range(-1, 1), randf_range(-1, 1))
	cam.position = p.pos.round() + shake_off
	var v := _view_rect()
	ground.position = (v.position - Vector2(16, 16)).floor()
	ground.region_rect = Rect2(ground.position, v.size + Vector2(32, 32))

	var walk := int(t * 5.0) % 2
	p.node.texture = _tex("paul_%d" % (walk if p.moving else 0))
	p.node.position = p.pos.round()
	p.node.modulate.a = 0.4 if p.inv > 0.0 and int(t * 20.0) % 2 == 1 else 1.0
	for c in comps:
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
		e.node.modulate = Color(3, 3, 2.6) if e.flash > 0.0 else Color.WHITE

	ground_fx.queue_redraw()
	air.queue_redraw()
	_update_hud()


func _dot_ring(n: Node2D, center: Vector2, r: float, squash: float, col: Color, every: float, ph: float) -> void:
	var count := maxi(12, int(r * TAU / every))
	for k in count:
		var a := k / float(count) * TAU + ph
		n.draw_rect(Rect2(round(center.x + cos(a) * r), round(center.y + sin(a) * r * squash), 1, 1), col)


func _draw_ground_fx() -> void:
	var n := ground_fx
	for o in [paul] + comps:
		n.draw_rect(Rect2(round(o.pos.x) - 4, round(o.pos.y) - 1, 9, 2), Color(0.24, 0.13, 0.05, 0.35))
	var barn = by_key.get("barn")
	if barn != null and _active(barn):
		var pulse := fmod(t, 1.6) / 1.6
		var bc: Vector2 = barn.pos.round() + Vector2(0, -2)
		_dot_ring(n, bc, D.skills.aura.radius, 0.62, Color("bfe3ff", 0.9), 3.0, t * 0.8)
		_dot_ring(n, bc, D.skills.aura.radius * pulse, 0.62, Color("e8f4ff", 0.8), 4.0, -t)
	# 經驗寶石：深色外框的菱形＋會閃的亮點，在沙地上也看得清楚
	var tw := int(t * 6.0)
	for g in gems:
		var x: float = roundf(g.pos.x)
		var y: float = roundf(g.pos.y) - roundf(sin(t * 4.0 + g.pos.x) * 1.0)
		n.draw_rect(Rect2(x - 1, y - 3, 3, 7), Color("10202c"))
		n.draw_rect(Rect2(x - 2, y - 2, 5, 5), Color("10202c"))
		n.draw_rect(Rect2(x - 3, y - 1, 7, 3), Color("10202c"))
		n.draw_rect(Rect2(x, y - 2, 1, 5), Color("4fd8ff"))
		n.draw_rect(Rect2(x - 2, y, 5, 1), Color("4fd8ff"))
		n.draw_rect(Rect2(x - 1, y - 1, 3, 3), Color("4fd8ff"))
		n.draw_rect(Rect2(x - 1, y - 1, 1, 1), Color.WHITE)
		if (tw + int(g.pos.x)) % 7 == 0:
			n.draw_rect(Rect2(x + 2, y - 4, 1, 1), Color.WHITE)
			n.draw_rect(Rect2(x - 3, y + 2, 1, 1), Color.WHITE)


func _draw_air() -> void:
	var n := air
	for b in _barrier_pieces():
		var x: float = roundf(b.pos.x)
		var y: float = roundf(b.pos.y)
		var h: int = roundi(b.up * 7.0)
		n.draw_rect(Rect2(x - 5, y - h - 2, 1, h + 2), Color("5a3f28"))
		n.draw_rect(Rect2(x + 5, y - h - 2, 1, h + 2), Color("5a3f28"))
		for r in h:
			var col := Color("b5533c") if r % 3 == 2 else (Color("d9c7a0") if r % 3 == 1 else Color("efe2c0"))
			n.draw_rect(Rect2(x - 4, y - h - 1 + r, 9, 1), col)
	for r in rings:
		var k: float = 1.0 - r.r / D.skills.ring.max_radius
		_dot_ring(n, r.pos.round(), r.r, 0.8, C_GOLD if k > 0.5 else Color("e0b860"), 2.0 if k > 0.5 else 3.0, r.r * 0.05)
		if k > 0.3:
			_dot_ring(n, r.pos.round(), r.r - 3.0, 0.8, C_CREAM, 5.0, 0.0)
	for b in beams:
		var end: Vector2 = b.pos + b.dir * D.skills.beam.length
		n.draw_line(b.pos, end, Color("3fbfb0", minf(1.0, b.life * 2.4)), 3.0)
		n.draw_line(b.pos, end, Color(C_CREAM, minf(1.0, b.life * 4.0)), 1.0)
	for b in bolts:
		var x: float = roundf(b.pos.x)
		var y: float = roundf(b.pos.y)
		n.draw_rect(Rect2(x - 1, y, 3, 1), C_GOLD)
		n.draw_rect(Rect2(x, y - 1, 1, 3), C_GOLD)
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
		n.draw_rect(Rect2(roundf(q.pos.x), roundf(q.pos.y), 1, 1), q.c1 if q.life > q.max * 0.45 else q.c2)
	var max_hp: float = D.companion_rules.hp
	for c in comps:
		var x: float = roundf(c.pos.x)
		var y: float = roundf(c.pos.y)
		# 受傷才顯示的小血條
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


func _update_hud() -> void:
	var f: float = clampf(paul.hp / D.paul.hp, 0.0, 1.0)
	hp_fill.size.x = roundf(120.0 * f)
	hp_fill.color = C_HEAL if f > 0.35 else C_RED
	xp_label.text = "經驗 %d" % xp
	var s := int(t)
	time_label.text = "%02d:%02d" % [s / 60, s % 60]
	kill_label.text = "驅散 %d" % kills
	hint_label.modulate.a = clampf((8.0 - t) / 2.0, 0.0, 1.0)
	var vp := get_viewport().get_visible_rect().size
	time_label.position = Vector2(roundf((vp.x - time_label.size.x) / 2.0), 4)
	kill_label.position = Vector2(vp.x - kill_label.size.x - 12.0, 4)
	hint_label.position = Vector2(roundf((vp.x - hint_label.size.x) / 2.0), vp.y - hint_label.size.y - 18.0)
	var ct := get_viewport().get_canvas_transform()
	var all := [paul] + comps
	for i in all.size():
		var l: Label = name_labels[i]
		var sp: Vector2 = ct * all[i].pos
		l.position = (sp + Vector2(-l.size.x / 2.0, 2.0)).round()
		l.visible = not over
	joy_pad.queue_redraw()


func _draw_joy() -> void:
	if not joy.on:
		return
	joy_pad.draw_arc(joy.origin, 36.0, 0.0, TAU, 48, Color(C_CREAM, 0.5), 2.0)
	var d: Vector2 = joy.pos - joy.origin
	if d.length() > 36.0:
		d = d.normalized() * 36.0
	joy_pad.draw_circle(joy.origin + d, 14.0, Color(C_CREAM, 0.45))


# ---------- 失敗 ----------
func _game_over() -> void:
	over = true
	joy.on = false
	paul.node.modulate = Color(0.5, 0.5, 0.5)
	var who := "—"
	var best := 0
	for k in scatter_by:
		if scatter_by[k] > best:
			best = scatter_by[k]
			who = D.enemies[k].name
	var s := int(t)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.06, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	ui.add_child(box)
	for row in [
		["旅程中斷", 26, C_GOLD],
		["四面受敵，卻不被困住；心裡作難，卻不至失望；\n遭逼迫，卻不被丟棄；打倒了，也不至死亡。", 13, C_CREAM],
		["林後 4:8–9", 11, C_BRONZE],
		["撐了 %02d:%02d　驅散 %d　經驗 %d\n最常被「%s」打散" % [s / 60, s % 60, kills, xp, who], 13, C_INK],
	]:
		var l := _label(row[0], row[1], row[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ui.remove_child(l)
		box.add_child(l)
	var btn := Button.new()
	btn.text = "再出發"
	btn.custom_minimum_size = Vector2(160, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(func(): get_tree().reload_current_scene())
	box.add_child(btn)
	btn.grab_focus()


# ---------- 自動測試 ----------
func _smoke_tick() -> void:
	smoke_frames += 1
	if smoke_frames % 300 == 0:
		print("t=%.1f hp=%.0f enemies=%d kills=%d xp=%d down=%d scatter=%s" % [t, paul.hp, enemies.size(), kills, xp, comps.filter(func(c): return c.down > 0.0).size(), scatter_by])
	if smoke_shot != "" and smoke_frames == 900:
		get_viewport().get_texture().get_image().save_png(smoke_shot)
		print("shot saved ", smoke_shot)
	if smoke_frames >= 1200:
		print("SMOKE DONE t=%.1f fps=%d" % [t, Engine.get_frames_per_second()])
		get_tree().quit()
