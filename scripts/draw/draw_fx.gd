extends RefCounted
## 繪圖效果 helper（從 main.gd 抽出）：持有 g（指向 main），讀寫 main 的狀態。
## air 與 ground_fx 的 draw signal 連到這裡的方法。

const PX := preload("res://scripts/draw/px.gd")

var g: Node2D  # 指向 main.gd 的 Node2D，由 main 在 _ready 中設定

func _bolt_pts(a: Vector2, b: Vector2, seed: int) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var d := b - a
	var segs := clampi(int(d.length() / 9.0), 2, 10)
	var side := d.orthogonal().normalized()
	var step = int(g.t * 20.0)
	for i in range(1, segs):
		var k := float(i) / segs
		var j: float = (PX.hash2(seed + i * 7, step) - 0.5) * 10.0 * sin(k * PI)
		pts.append(a + d * k + side * j)
	pts.append(b)
	return pts




func _draw_ground_fx() -> void:
	var n: Node2D = g.ground_fx
	# 馬利亞的香膏：地上一片淡粉金色的香膏（畫在人物腳下），中間一個打開的玉瓶
	for z in g.zones:
		var k: float = clampf(z.life / z.max, 0.0, 1.0)
		var fade: float = clampf(k * 3.0, 0.0, 1.0) * clampf((z.max - z.life) / 0.25, 0.0, 1.0)   # 出現與消失都淡入淡出
		var zc: Vector2 = z.pos.round()
		var zcol: Color = z.owner.col
		for i in 3:
			var rr: float = z.r * (1.0 - i * 0.28)
			n.draw_set_transform(zc, 0.0, Vector2(1.0, 0.62))
			n.draw_circle(Vector2.ZERO, rr, Color(zcol.lerp(g.C_CREAM, i * 0.35), (0.16 + i * 0.07) * fade))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		n.draw_set_transform(zc, 0.0, Vector2(1.0, 0.62))
		n.draw_arc(Vector2.ZERO, z.r, 0.0, TAU, 40, Color(zcol, 0.55 * fade), 1.5)
		n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 玉瓶：白色瓶身、金色瓶口，倒出來的香膏
		n.draw_rect(Rect2(zc.x - 2, zc.y - 6, 5, 6), Color(Color("f4ead2"), fade))
		n.draw_rect(Rect2(zc.x - 1, zc.y - 8, 3, 2), Color(g.C_GOLD, fade))
		n.draw_rect(Rect2(zc.x + 3, zc.y - 1, 3, 1), Color(zcol.lerp(g.C_CREAM, 0.4), fade))
	if g.vision_on:
		# 天上一道光柱照在主角身上（大馬色路上、升天、司提反看見天開了）
		var v0: Rect2 = g._view_rect()
		var c0: Vector2 = g.paul.pos.round()
		for i in 5:
			var w := 34.0 - i * 6.0
			n.draw_rect(Rect2(c0.x - w / 2.0, v0.position.y - 4.0, w, c0.y - v0.position.y + 8.0), [Color("6a5a3a"), Color("a08a50"), Color("d8c070"), Color("fff0b0"), Color("ffffff")][i])
	# 瞬移的預兆：落點的紫色圈慢慢收縮
	for e in g.enemies:
		if e.has("blink_to") and not e.dead:
			var k: float = clampf(float(e.blink_wait) / 0.7, 0.0, 1.0)
			n.draw_arc(e.blink_to, 4.0 + k * 10.0, 0.0, TAU, 16, Color(Color("a060ff"), 0.9), 1.5)
			n.draw_circle(e.blink_to, 3.0, Color(Color("a060ff"), 0.35))
	for o in [g.paul] + g.comps:
		if o != g.paul and o.level == 0:
			continue
		n.draw_rect(Rect2(round(o.pos.x) - 5, round(o.pos.y) - 1, 11, 2), Color(0.24, 0.13, 0.05, 0.35))
		n.draw_rect(Rect2(round(o.pos.x) - 4, round(o.pos.y) - 2, 9, 4), Color(0.24, 0.13, 0.05, 0.18))
	# 敵人腳下的影子（讓人站在地上，不像貼紙）
	var vr = g._view_rect().grow(16.0)
	for e in g.enemies:
		if e.dead or e.get("boss", false) or not vr.has_point(e.pos):
			continue
		n.draw_rect(Rect2(round(e.pos.x) - 6, round(e.pos.y) - 1, 13, 2), Color(0.1, 0.05, 0.08, 0.28))
	g._draw_spots(n)
	# 先知：預言之地（紫色的圈，中間一隻眼睛）
	if not g.prophecy.is_empty():
		var pc: Vector2 = g.prophecy.pos.round()
		PX.dot_ring(n, pc, g.prophecy.r, 0.8, Color("c8a0ff"), 3.0, g.t * 0.6, 2)
		PX.dot_ring(n, pc, g.prophecy.r - 6.0, 0.8, g.C_GOLD, 5.0, -g.t * 0.6, 1)
		n.draw_rect(Rect2(pc.x - 6, pc.y - 2, 13, 5), Color("2a1640"))
		n.draw_rect(Rect2(pc.x - 5, pc.y - 1, 11, 3), Color("c8a0ff"))
		n.draw_rect(Rect2(pc.x - 1, pc.y - 2, 3, 5), g.C_GOLD)
	# 星辰墜落的落點：紅色虛線圈慢慢收縮
	for sf in g.star_falls:
		if sf.t > 0.0:
			var k: float = clampf(sf.t / sf.max, 0.0, 1.0)
			PX.dot_ring(n, sf.pos.round(), sf.r, 0.8, g.C_RED, 3.0, g.t * 3.0, 2)
			PX.dot_ring(n, sf.pos.round(), sf.r * k, 0.8, g.C_GOLD, 4.0, -g.t * 3.0, 1)
	# 差派：發光的腳蹤（實心，快消失時變小）
	for f in g.trail:
		var fx: float = roundf(f.pos.x) + (2.0 if f.side == 1 else -3.0)
		var fy: float = roundf(f.pos.y)
		var big: bool = f.life > 0.6
		var fc: Color = g.C_GOLD if f.life > f.max * 0.6 else g.C_FLAME
		if big:
			n.draw_rect(Rect2(fx - 1, fy - 3, 4, 6), Color("3a1606"))
			n.draw_rect(Rect2(fx, fy - 2, 2, 4), fc)
			n.draw_rect(Rect2(fx, fy - 2, 1, 1), g.C_CREAM)
		else:
			n.draw_rect(Rect2(fx, fy - 1, 2, 2), g.C_FLAME)
	# 詩歌：主角腳下的四個拍子
	if g._school_on("詩歌"):
		var bx: float = roundf(g.paul.pos.x) - 8.0
		var by: float = roundf(g.paul.pos.y) + 4.0
		for k in 4:
			var lit: bool = posmod(g.beat_i, 4) == k
			var dn: bool = k == 0 or (k == 2 and g._sv("詩歌", "offbeat") > 0.0)
			var sz := 3 if dn else 2
			n.draw_rect(Rect2(bx + k * 5 - 1, by - 1, sz + 2, sz + 2), Color("1a1008"))
			n.draw_rect(Rect2(bx + k * 5, by, sz, sz), (g.C_GOLD if dn else g.C_CREAM) if lit else Color("5a4a30"))
	for k in g.evolved:
		var ec: Dictionary = g.by_key[k]
		if ec.level > 0 and ec.down <= 0.0:
			var gp: Vector2 = ec.pos.round()
			var a = 0.5 + 0.3 * sin(g.t * 4.0)
			n.draw_arc(gp, 8.0, 0.0, TAU, 20, Color(g.C_GOLD, a), 1.0)
			if int(g.t * 6.0 + ec.i) % 3 == 0:
				n.draw_rect(Rect2(gp.x + randf_range(-6, 6), gp.y - randf_range(4, 18), 1, 1), g.C_CREAM)
	var barn = g.by_key.get("barn")
	if barn != null and g._active(barn):
		var pulse = fmod(g.t, 1.6) / 1.6
		var bc: Vector2 = barn.pos.round() + Vector2(0, -2)
		var col = g.C_GOLD if g.fever > 0.0 or g.evolved.has("barn") else Color("bfe3ff")
		PX.dot_ring(n, bc, g._aura_r(barn), 0.62, Color(col, 0.9), 3.0, g.t * 0.8)
		PX.dot_ring(n, bc, g._aura_r(barn) * pulse, 0.62, Color(col.lightened(0.4), 0.8), 4.0, -g.t)
	g._draw_finds(n)
	for ch in g.chests:
		var cx: float = roundf(ch.pos.x)
		var cy: float = roundf(ch.pos.y) - roundf(absf(sin(g.t * 3.0)) * 2.0)
		n.draw_rect(Rect2(cx - 6, cy - 6, 13, 10), Color("2a1a14"))
		n.draw_rect(Rect2(cx - 5, cy - 5, 11, 8), Color("b8862e"))
		n.draw_rect(Rect2(cx - 5, cy - 5, 11, 3), g.C_GOLD)
		n.draw_rect(Rect2(cx - 1, cy - 3, 3, 3), Color("2a1a14"))
		if int(g.t * 4.0) % 2 == 0:
			n.draw_rect(Rect2(cx + 6, cy - 9, 1, 1), Color.WHITE)
			n.draw_rect(Rect2(cx - 8, cy - 2, 1, 1), Color.WHITE)
		# 寶箱在螢幕外時，主角身邊有個金點指著方向
		var cd: Vector2 = ch.pos - g.paul.pos
		if cd.length() > 70.0 and cd.length() < 360.0:
			var ctip: Vector2 = g.paul.pos + cd.normalized() * 38.0 + Vector2(0, -8)
			n.draw_rect(Rect2(ctip.round() - Vector2(2, 2), Vector2(4, 4)), Color(g.C_GOLD, 0.6 + 0.4 * sin(g.t * 6.0)))
	# 分頭行動：同伴走出畫面時，畫面邊緣有一個他顏色的箭頭指著他在哪裡；倒下的閃紅、加驚嘆號
	if g.roam:
		var seen: Rect2 = g._view_rect()
		var inner: Rect2 = seen.grow(-9.0)
		var mid: Vector2 = seen.get_center()
		for c in g.comps:
			if c.level == 0 or c.follows != "" or seen.has_point(c.pos + Vector2(0, -8)):
				continue
			var dv: Vector2 = c.pos + Vector2(0, -8) - mid
			# 從畫面中心往同伴的方向，碰到內縮的邊框就停：箭頭貼著畫面邊緣
			var k: float = minf(absf(inner.size.x * 0.5 / maxf(absf(dv.x), 0.001)), absf(inner.size.y * 0.5 / maxf(absf(dv.y), 0.001)))
			var tip: Vector2 = (mid + dv * minf(k, 1.0)).round()
			var dir: Vector2 = dv.normalized()
			var side: Vector2 = dir.orthogonal()
			var down: bool = c.down > 0.0
			var ccol: Color = Color("ff5a4a") if down else c.col
			var a: float = (0.55 + 0.45 * sin(g.t * 10.0)) if down else 1.0
			var tri := PackedVector2Array([tip + dir * 5.0, tip - dir * 3.0 + side * 4.5, tip - dir * 3.0 - side * 4.5])
			var out := PackedVector2Array([tip + dir * 7.0, tip - dir * 4.5 + side * 6.5, tip - dir * 4.5 - side * 6.5])
			n.draw_colored_polygon(out, Color(0.08, 0.05, 0.07, 0.85 * a))
			n.draw_colored_polygon(tri, Color(ccol, a))
			if down:
				n.draw_rect(Rect2(tip - dir * 9.0 + Vector2(-0.5, -3), Vector2(1, 3)), Color(1, 1, 1, a))
				n.draw_rect(Rect2(tip - dir * 9.0 + Vector2(-0.5, 1), Vector2(1, 1)), Color(1, 1, 1, a))
	for b in g.breads:
		var bx: float = roundf(b.pos.x)
		var by: float = roundf(b.pos.y) - roundf(absf(sin(g.t * 3.0 + b.pos.x)) * 1.5)
		n.draw_rect(Rect2(bx - 4, by - 3, 9, 6), Color("2a1a10"))
		n.draw_rect(Rect2(bx - 3, by - 2, 7, 4), Color("c8873a"))
		n.draw_rect(Rect2(bx - 2, by - 2, 5, 1), Color("f0c070"))
		n.draw_rect(Rect2(bx - 1, by, 1, 1), Color("8a5a24"))
		n.draw_rect(Rect2(bx + 1, by, 1, 1), Color("8a5a24"))
	var tw = int(g.t * 6.0)
	for ge in g.gems:
		var x: float = roundf(ge.pos.x)
		var y: float = roundf(ge.pos.y)
		# 經驗：小顆、不閃爍，滿地都是時也不會太花
		n.draw_rect(Rect2(x - 1, y - 2, 3, 5), Color("10202c"))
		n.draw_rect(Rect2(x - 2, y - 1, 5, 3), Color("10202c"))
		n.draw_rect(Rect2(x, y - 1, 1, 3), g.C_SKY)
		n.draw_rect(Rect2(x - 1, y, 3, 1), g.C_SKY)
		if (tw + int(ge.pos.x)) % 11 == 0:
			n.draw_rect(Rect2(x, y, 1, 1), Color.WHITE)




func _draw_air() -> void:
	if g.wind_on > 0.0:
		# 暴風：一條條白色的風線往同一個方向掃過
		var v = g._view_rect()
		for i in 24:
			var ph = fmod(g.t * 1.7 + i * 0.37, 1.0)
			var base = v.position + Vector2(PX.hash2(i, 3) * v.size.x, PX.hash2(i, 7) * v.size.y)
			var p0 = base + g.wind_dir * (ph - 0.5) * 120.0
			g.air.draw_line(p0, p0 + g.wind_dir * 14.0, Color(1, 1, 1, 0.45 * minf(1.0, g.wind_on)), 1.0)
	var n: Node2D = g.air
	# 被驅散的敵人：變白、壓扁、往上飄走
	for pf in g.poofs:
		var k: float = pf.t / 0.3
		var sx: float = (1.0 + 0.5 * k) * (-1.0 if pf.flip else 1.0)
		n.draw_set_transform(pf.pos + Vector2(0, -6.0 * k), 0.0, Vector2(sx, 1.0 - 0.7 * k))
		n.draw_texture(pf.tex, pf.off, Color(3.0, 3.0, 2.6, 1.0 - k))
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var on_fire = g.fever > 0.0
	for b in g._barrier_pieces():
		var x: float = roundf(b.pos.x)
		var y: float = roundf(b.pos.y)
		var h: int = roundi(b.up * 7.0)
		n.draw_rect(Rect2(x - 5, y - h - 2, 1, h + 2), Color("5a3f28"))
		n.draw_rect(Rect2(x + 5, y - h - 2, 1, h + 2), Color("5a3f28"))
		for r in h:
			var col := Color("b5533c") if r % 3 == 2 else (Color("d9c7a0") if r % 3 == 1 else Color("efe2c0"))
			if on_fire:
				col = g.C_RED if r % 3 == 2 else (g.C_FLAME if r % 3 == 1 else g.C_GOLD)
			elif g.evolved.has("pri"):
				col = g.C_GOLD if r % 3 == 2 else (g.C_CREAM if r % 3 == 1 else Color.WHITE)
			n.draw_rect(Rect2(x - 4, y - h - 1 + r, 9, 1), col)
	for r in g.rings:
		if r.r <= 0.0:
			continue
		# 簡化：每圈只畫一條實線，顏色就是這位同伴的顏色，越擴散越淡
		# 實心顏色：深色描邊＋本色＋亮色內線，外圈有幾個音符般的小方塊
		var k: float = clampf(r.r / r.max, 0.0, 1.0)
		var center: Vector2 = (r.owner.pos + Vector2(0, -6)).round()
		var col: Color = g.C_FLAME if on_fire else r.owner.get("col", g.C_GOLD)
		# 聲波：一圈像素環，越外面越細；環上四個音符跟著轉
		# 畫面清爽：環變細、越往外越淡（原本整圈不透明，幾位同伴同時放時會蓋滿畫面）
		var fade: float = 1.0 - k
		var w: int = 2 if k < 0.4 and r.thick >= 2 else 1
		g.PX.ring(n, center, r.r, Color(col.darkened(0.5), 0.5 * fade), w + 1, 0.8)
		g.PX.ring(n, center, r.r, Color(col, 0.85 * fade), w, 0.8)
		if k < 0.5:
			for j in 4:
				var ang: float = j * TAU / 4.0 + r.r * 0.03
				g._fx(n, "note", 1, 0, center + Vector2(cos(ang), sin(ang) * 0.8) * r.r)
		if r.get("evo", false):
			g.PX.ring(n, center, r.r + 3.0, g.C_GOLD, 1, 0.8, 2)
	for b in g.beams:
		var end: Vector2 = b.pos + b.dir * b.len
		# 實心光束：越接近消失越細，而不是變透明
		var a := minf(1.0, b.life * 3.3)
		var bw: float = b.width * (0.4 + 0.6 * a)
		if b.get("evo", false):
			n.draw_line(b.pos, end, g.C_GOLD, bw * 2.4)
		var bc: Color = g.C_FLAME if on_fire else b.get("col", Color("3fbfb0"))
		if b.look == "lamp":
			bc = g.C_FLAME if on_fire else Color("ff9a3a")
		elif b.look == "sea":
			bc = g.C_FLAME if on_fire else Color("2f78c8")
		# 光束：一節一節的像素光（灰階圖上色），粗細取整數像素
		var bh := maxf(3.0, roundf(bw * 1.6 + 2.0))
		n.draw_set_transform(b.pos.round(), b.dir.angle(), Vector2.ONE)
		n.draw_texture_rect(g._tex("fx_beam"), Rect2(Vector2(0, -bh / 2.0), Vector2(b.len, bh)), true, bc.lightened(0.15))
		n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		g._fx(n, "spark", 4, int(g.t * 12.0) % 2, b.pos)
		# 光束上流動的小方塊
		for j in 4:
			var fp: Vector2 = (b.pos + b.dir * b.len * fmod(g.t * 2.5 + j * 0.25, 1.0)).round()
			n.draw_rect(Rect2(fp.x - 1, fp.y - 1, 3, 3), g.C_CREAM)
		g._fx(n, "spark", 4, 1 + int(g.t * 12.0) % 2, end)
	for b in g.blasts:
		# 實心衝擊波：一圈粗的本色環往外推，裡面跟著一圈亮色與放射的碎塊
		# 爆開：小的用像素火球動畫，大的（升級、震波）用一圈往外推的像素環
		var k: float = b.t / 0.3
		var bcol: Color = b.get("col", g.C_GOLD)
		var rr: float = b.r * (0.4 + k * 0.6)
		if b.r <= 34.0:
			var sc := maxf(1.0, roundf(b.r / 14.0 * 2.0) / 2.0)
			g._fx(n, "boom", 6, int(k * 6.0), b.pos, sc, Color.WHITE.lerp(bcol, 0.35))
		else:
			g.PX.ring(n, b.pos.round(), rr, bcol.darkened(0.5), 3, 0.8)
			g.PX.ring(n, b.pos.round(), rr, bcol, 2, 0.8)
			g.PX.ring(n, b.pos.round(), rr - 2.0, g.C_CREAM, 1, 0.8, 2)
		if b.get("evo", false):
			g.PX.ring(n, b.pos.round(), b.r * (0.6 + k * 0.7), g.C_GOLD, 1, 0.8, 2)
	for f in g.fires:
		var flook: String = f.get("look", "")
		if f.t > 0.0:
			# 預兆：地上一圈虛線，裡面一圈往內收
			var k: float = 1.0 - f.t / f.max
			var wc: Color = Color("8fd0ff") if flook == "spit" else (g.C_GOLD if flook == "glory" else g.C_FLAME)
			g.PX.ring(n, f.pos.round(), f.r, wc, 2, 0.6, 2)
			g.PX.ring(n, f.pos.round(), f.r * (1.0 - k), g.C_CREAM, 1, 0.6)
		else:
			var a: float = 1.0 + f.t / 0.35      # 1 → 0：落下後慢慢收掉
			var fr := int((1.0 - a) * 12.0) % 4
			var shrink := clampf(a * 1.4, 0.0, 1.0)
			if flook == "spit":
				# 約拿的大魚吐出來：一道水柱砸下來，落點水花
				g._fx(n, "watercol", 4, fr, f.pos + Vector2(0, 2), 1.0, Color(1, 1, 1, shrink), false)
				g._fx(n, "splash", 4, int((1.0 - a) * 4.0), f.pos + Vector2(0, -4), 1.5)
			elif flook == "glory":
				# 司提反：天開了，白金色的光柱，落點一圈光
				g._fx(n, "glorycol", 4, fr, f.pos + Vector2(0, 2), 1.0, Color(1, 1, 1, shrink), false)
				g.PX.ring(n, f.pos.round(), f.r * (1.4 - a * 0.4), g.C_GOLD, 2, 0.6)
			else:
				g._fx(n, "firecol", 4, fr, f.pos + Vector2(0, 2), 1.0, Color(1, 1, 1, shrink), false)
				g._fx(n, "boom", 6, int((1.0 - a) * 5.0) + 1, f.pos + Vector2(0, -4), 1.0)
			if f.get("evo", false):
				g.PX.ring(n, f.pos.round(), f.r * 1.2, g.C_CREAM, 1, 0.6, 2)
	var blink = int(g.t * 8.0) % 2 == 0
	for sh in g.tele:
		if sh.kind == "line":
			n.draw_line(sh.a, sh.b, Color(g.C_RED, 0.35), sh.w)
			var side: Vector2 = (sh.b - sh.a).normalized().orthogonal() * (sh.w / 2.0)
			var ea := 1.0 if blink else 0.5
			n.draw_line(sh.a + side, sh.b + side, Color(Color("ff3a2a"), ea), 1.0)
			n.draw_line(sh.a - side, sh.b - side, Color(Color("ff3a2a"), ea), 1.0)
		else:
			n.draw_circle(sh.c, sh.r, Color(g.C_RED, 0.35))
			n.draw_arc(sh.c, sh.r, 0.0, TAU, 40, Color(Color("ff3a2a"), 1.0 if blink else 0.5), 1.0)
	for h in g.hits:
		var a: float = 1.0 - h.t / 0.3
		if h.sh.kind == "line":
			n.draw_line(h.sh.a, h.sh.b, Color(Color("d8d8e8"), a), h.sh.w)
		else:
			n.draw_circle(h.sh.c, h.sh.r, Color(Color("d8d8e8"), a * 0.8))
	for q in g.quakes:
		var qm: float = float(q.get("max", 360.0))
		PX.dot_ring(n, q.pos.round(), q.r, 0.7, Color(g.C_GOLD, 1.0 - q.r / qm), 3.0, 0.0, 2)
		PX.dot_ring(n, q.pos.round(), q.r * 0.7, 0.7, Color(g.C_CREAM, 1.0 - q.r / qm), 4.0, 0.5, 1)
	if g.armor.get("shield", 0) > 0 and g.shield_cd <= 0.0:
		g.PX.ring(n, g.paul.pos.round() + Vector2(0, -12), 13.0, Color(g.C_GOLD, 0.7), 1, 1.1, 3)
	if g.light > 0.0:
		g._draw_light(n)
	for fb in g.fever_bursts:
		PX.dot_ring(n, fb.pos.round() + Vector2(0, -4), fb.r, 0.8, g.C_GOLD, 2.0, 0.0, 2)
		PX.dot_ring(n, fb.pos.round() + Vector2(0, -4), fb.r - 4.0, 0.8, g.C_FLAME, 3.0, 0.3, 2)
	for f in g.nets:
		if f.get("look", "") == "purple":
			# 呂底亞：紫布鋪在地上，定住的時間內慢慢淡掉
			var life: float = maxf(0.4, f.stun)
			var pk: float = clampf(f.t / life, 0.0, 1.0)
			var rr2: float = f.r * minf(1.0, f.t / 0.12)
			g.PX.cloth(n, f.pos.round(), rr2, 1.0 - pk * pk, f.evo)
			continue
		# 彼得的網：一張圓網撒開再收攏
		var k: float = f.t / 0.4
		var rr: float = f.r * (1.0 - 0.3 * k)
		g.PX.net(n, f.pos.round(), rr, 1.0 - k * k, g.C_GOLD if f.evo else Color("c8b48a"))
	for z in g.zaps:
		# 閃電：鋸齒狀的像素線，外面一層本色、裡面白芯；打中的地方一團電光
		var col: Color = g.C_GOLD if z.evo else z.get("col", Color("ffe14d"))
		var thick: int = 3 if z.t < 0.12 else 2
		for i in z.pts.size() - 1:
			var p0: Vector2 = z.pts[i]
			var p1: Vector2 = z.pts[i + 1]
			var bp := _bolt_pts(p0, p1, i * 31 + int(p0.x))
			for j in bp.size() - 1:
				g.PX.line(n, bp[j], bp[j + 1], col.darkened(0.45), thick + 1)
			for j in bp.size() - 1:
				g.PX.line(n, bp[j], bp[j + 1], col if thick > 2 else col.lightened(0.3), thick - 1)
			for j in bp.size() - 1:
				g.PX.line(n, bp[j], bp[j + 1], Color.WHITE, 1)
			g._fx(n, "zapend", 3, int(z.t / 0.25 * 3.0), p1)
	for th in g.thrusts:
		var a: float = 1.0 - th.t / 0.2
		var tip: Vector2 = th.from + th.dir * th.len * minf(1.0, th.t / 0.06)
		var col: Color = g.C_GOLD if th.crit or th.evo else th.get("col", Color("d8d0c0"))
		if th.get("look", "") == "dash":
			# 腓利：一道青色的奔跑殘影（三道平行的速度線）
			col = g.C_GOLD if th.crit or th.evo else Color("6ae0d0")
			var sd: Vector2 = th.dir.orthogonal()
			for i in 3:
				g.PX.line(n, th.from + sd * (i - 1) * 4.0, th.from.lerp(tip, 0.6 + i * 0.15) + sd * (i - 1) * 4.0, col.darkened(0.2 * i), 2 if i == 1 else 1)
		g.PX.line(n, th.from, tip, col.darkened(0.6), 4 if th.crit else 3)
		g.PX.line(n, th.from, tip, col, 2 if th.crit else 1)
		g._fx(n, "spark", 4, int((1.0 - a) * 4.0), tip, 2.0 if th.crit else 1.0)
	for ga in g.gathers:
		var k: float = ga.t / 0.5
		PX.dot_ring(n, ga.pos.round() + Vector2(0, -4), ga.r * (1.0 - k), 0.8, g.C_HEAL, 4.0, k * 3.0, 2)
		PX.dot_ring(n, ga.pos.round() + Vector2(0, -4), ga.r * (1.0 - k) - 5.0, 0.8, g.C_CREAM, 6.0, -k * 3.0, 1)
	# 五旬節：頭上的火焰（實心的紅、橘、金三層）
	for tg in g.tongues:
		var hp: Vector2 = (tg.who.pos + Vector2(0, -32 - (int(g.t * 8.0) % 2))).round()
		n.draw_rect(Rect2(hp.x - 3, hp.y - 2, 7, 6), Color("c8301a"))
		n.draw_rect(Rect2(hp.x - 2, hp.y - 5, 5, 6), g.C_FLAME)
		n.draw_rect(Rect2(hp.x - 1, hp.y - 7, 3, 5), g.C_GOLD)
		n.draw_rect(Rect2(hp.x, hp.y - 9, 1, 3), Color.WHITE)
	# 約帕：四角吊著的大布從天上降下來
	for sh in g.sheets:
		if sh.t > 0.0:
			var k: float = clampf(sh.t / sh.max, 0.0, 1.0)
			var r: float = float(g.stage.hazard.radius)
			var c0: Vector2 = (sh.pos + Vector2(0, -160.0 * k)).round()
			PX.dot_ring(n, sh.pos.round(), r, 0.8, g.C_CREAM, 5.0, g.t, 1)
			var w := r * (0.6 + 0.4 * (1.0 - k))
			for cx in [-1, 1]:
				n.draw_line(c0 + Vector2(cx * w, -w * 0.5), c0 + Vector2(cx * w * 0.3, -w * 0.5 - 60.0), Color("c9a46b"), 1.0)
			n.draw_rect(Rect2(c0.x - w, c0.y - w * 0.5, w * 2.0, w), Color("6a5a48"))
			n.draw_rect(Rect2(c0.x - w + 2, c0.y - w * 0.5 + 2, w * 2.0 - 4, w - 4), Color("f4ead2"))
			for i in 5:
				n.draw_rect(Rect2(c0.x - w + 6 + i * (w * 2.0 - 12) / 4.0, c0.y - 2 + (i % 2) * 4, 3, 2), [Color("8a6438"), Color("5a8a2a"), Color("6a5a90"), Color("b05a30"), Color("3a3a3a")][i])
	# 星辰：從天上斜斜落下，拖著金色的尾巴（司提反那一關是石頭）
	for sf in g.star_falls:
		if sf.t > 0.0 and g.stage.get("hazard", {}).get("look", "") == "stone" and not sf.get("pierce", false):
			var ks: float = clampf(sf.t / sf.max, 0.0, 1.0)
			var spp: Vector2 = (sf.pos + Vector2(-90.0, -60.0) * ks + Vector2(0, -40.0 * sin(ks * PI))).round()
			PX.dot_ring(n, sf.pos.round(), sf.r, 0.8, Color("c8b8a0"), 4.0, 0.0, 1)
			n.draw_rect(Rect2(spp.x - 3, spp.y - 3, 7, 6), Color("3a3430"))
			n.draw_rect(Rect2(spp.x - 2, spp.y - 3, 5, 5), Color("8a8078"))
			n.draw_rect(Rect2(spp.x - 2, spp.y - 3, 2, 2), Color("b0a89c"))
			continue
		if sf.t > 0.0:
			var k: float = clampf(sf.t / sf.max, 0.0, 1.0)
			var sp: Vector2 = (sf.pos + Vector2(40.0, -150.0) * k).round()
			n.draw_line(sp, sp + Vector2(16, -60) * 0.5, Color("8a5a10"), 4.0)
			n.draw_line(sp, sp + Vector2(16, -60) * 0.5, g.C_GOLD, 2.0)
			n.draw_rect(Rect2(sp.x - 3, sp.y - 3, 7, 7), Color("8a5a10"))
			n.draw_rect(Rect2(sp.x - 2, sp.y - 2, 5, 5), g.C_GOLD)
			n.draw_rect(Rect2(sp.x - 1, sp.y - 1, 3, 3), Color.WHITE)
	for sh in g.tele:
		if sh.get("star", false) and g.boss != null:
			var kk: float = clampf(float(g.boss.timer) / float(g.D.boss.warn), 0.0, 1.0)
			var sp2: Vector2 = (sh.c + Vector2(30.0, -140.0) * kk).round()
			n.draw_line(sp2, sp2 + Vector2(10, -40), g.C_GOLD, 2.0)
			n.draw_rect(Rect2(sp2.x - 2, sp2.y - 2, 5, 5), g.C_GOLD)
			n.draw_rect(Rect2(sp2.x - 1, sp2.y - 1, 3, 3), Color.WHITE)
	# 七個金燈台
	if g.epistles.has("lamps") and g.fever > 0.0:
		for lp in g._lamp_points():
			var lx: float = roundf(lp.x)
			var ly: float = roundf(lp.y)
			n.draw_rect(Rect2(lx - 3, ly + 3, 7, 2), Color("8a6420"))
			n.draw_rect(Rect2(lx - 1, ly - 3, 3, 7), Color("8a6420"))
			n.draw_rect(Rect2(lx, ly - 3, 1, 7), g.C_GOLD)
			n.draw_rect(Rect2(lx - 2, ly + 3, 5, 1), g.C_GOLD)
			var fl = int(g.t * 10.0 + lx) % 2
			n.draw_rect(Rect2(lx - 1, ly - 7 - fl, 3, 3), g.C_FLAME)
			n.draw_rect(Rect2(lx, ly - 7 - fl, 1, 2), g.C_CREAM)
	g._draw_engines(n)
	g._draw_ailments(n)
	g._draw_seek(n)
	_draw_schools(n)
	for dn in g.dnums:
		var k2: float = dn.t / 0.7
		var big: bool = dn.v >= 20.0 + g.level * 1.5   # 大傷害：比這個等級平常的一擊大很多
		var txt := str(roundi(dn.v))
		# 跳出來時先大一點再縮回去（0.1 秒），之後往上飄、往旁邊偏一點
		var pop := 1.0 + 0.6 * clampf(1.0 - dn.t / 0.1, 0.0, 1.0)
		var lead2: bool = dn.get("lead", false)   # 主角打的數字大一點、亮一點；同伴的小一點、淡一點，主角才看得出自己在做什麼
		var fs := roundi((11 if big else 8) * pop) + (2 if lead2 else -1)
		var rise := 14.0 * (1.0 - pow(1.0 - minf(k2 * 1.6, 1.0), 2.0))
		var pos2: Vector2 = (dn.pos + Vector2(-fs * txt.length() * 0.3 + float(dn.get("dx", 0.0)) * k2, -rise)).round()
		var a2 := (1.0 if k2 < 0.6 else (1.0 - k2) / 0.4) * (1.0 if lead2 else 0.7)
		n.draw_string_outline(UIKit.font(), pos2, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, Color(Color("140c10"), a2))
		n.draw_string(UIKit.font(), pos2, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(g.C_GOLD if big or lead2 else Color.WHITE.lerp(dn.col, 0.6), a2))
	for hs in g.hastes:
		var hk: float = hs.t / 0.5
		var hp: Vector2 = (hs.who.pos as Vector2).round()
		for j in 3:
			var hx: float = -8.0 + j * 8.0
			var hy: float = -4.0 - hk * 18.0 - j * 3.0
			n.draw_rect(Rect2(hp + Vector2(hx, hy), Vector2(1, 5)), Color(hs.col, 1.0 - hk))
	for sb in g.sbursts:
		# 護盾類技能：一圈小盾牌從主角身上往外展開、轉一下、淡掉
		var sk: float = sb.t / 0.6
		var sr: float = 6.0 + 28.0 * (1.0 - pow(1.0 - sk, 2.0))
		for j in int(sb.n):
			var sa: float = j * TAU / float(sb.n) + sk * 1.2
			g._fx(n, "shield", 2, j % 2, sb.pos + Vector2(0, -12) + Vector2(cos(sa) * sr, sin(sa) * sr * 0.65), 1.0, Color(sb.col, 1.0 - sk * sk))
	for i in g.kit_pops.size():
		# 主角放技能：頭上跳出這招的圖示（先放大再縮回、往上飄、最後淡掉），腳下一圈金光
		var kp: Dictionary = g.kit_pops[i]
		var kk: float = kp.t / 0.8
		var ka: float = 1.0 if kk < 0.6 else (1.0 - kk) / 0.4
		var ksz: float = 11.0 * (1.0 + 0.3 * clampf(1.0 - kp.t / 0.12, 0.0, 1.0))
		var kc: Vector2 = (g.paul.pos + Vector2((i - (g.kit_pops.size() - 1) / 2.0) * 22.0, -60.0 - kk * 6.0)).round()
		n.draw_rect(Rect2(kc - Vector2(ksz / 2.0 + 2.0, ksz / 2.0 + 2.0), Vector2(ksz + 4.0, ksz + 4.0)), Color(Color("140c10"), 0.85 * ka))
		n.draw_rect(Rect2(kc - Vector2(ksz / 2.0 + 2.0, ksz / 2.0 + 2.0), Vector2(ksz + 4.0, ksz + 4.0)), Color(g.C_GOLD, ka), false, 1.0)
		var itx = g._tex("icon_" + str(kp.id))
		if itx != null:
			n.draw_texture_rect(itx, Rect2(kc - Vector2(ksz / 2.0, ksz / 2.0), Vector2(ksz, ksz)), false, Color(1, 1, 1, ka))
		if kp.t < 0.3:
			g.PX.ring(n, g.paul.pos.round() + Vector2(0, 1), 10.0 + kp.t * 40.0, Color(g.C_GOLD, 1.0 - kp.t / 0.3), 1, 0.5)
	for f in g.tag_fx:
		var k: float = f.t / 0.8
		var pos: Vector2 = (f.pos + Vector2(-8, -32 - k * 10.0)).round()
		var tfs := 9 if f.get("big", false) else 8
		n.draw_string_outline(UIKit.font(), pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, 3 if tfs > 8 else 2, Color(Color("140c10"), 1.0 - k))
		n.draw_string(UIKit.font(), pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(f.col, 1.0 - k))
	if g.guard > 0:
		# 護盾：一面一面小盾牌繞著主角轉（幾面就是擋得下幾次）
		for i in g.guard:
			var ga = g.t * 1.6 + i * TAU / g.guard
			var gp: Vector2 = g.paul.pos + Vector2(0, -12) + Vector2(cos(ga) * 15.0, sin(ga) * 9.0)
			g._fx(n, "shield", 2, int(g.t * 4.0 + i) % 2, gp)
	for f in g.link_fx:
		var to: Vector2 = f.b.pos + Vector2(0, -8)
		if f.t < 0.3:
			var a: float = 1.0 - f.t / 0.3
			# 從來源射向被觸發的人：前 0.08 秒線往前長出去
			var tip: Vector2 = f.a.lerp(to, minf(1.0, f.t / 0.08))
			var lc: Color = g.C_FLAME if f.depth >= 2 else g.C_GOLD
			var lw := 2 + mini(f.depth, 2) if a > 0.4 else 2
			g.PX.line(n, f.a, tip, lc.darkened(0.6), lw + 1)
			g.PX.line(n, f.a, tip, lc, maxi(1, lw - 1))
			g.PX.line(n, f.a, tip, g.C_CREAM, 1)
			g._fx(n, "spark", 4, int((1.0 - a) * 3.0), tip, 2.0 if f.depth >= 2 else 1.0)
		if f.depth >= 2:
			var k: float = f.t / 0.6
			var txt := "連鎖×%d" % f.depth
			var pos: Vector2 = (to + Vector2(-12, -10 - k * 10.0)).round()
			n.draw_string_outline(UIKit.font(), pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(Color("140c10"), 1.0 - k))
			n.draw_string(UIKit.font(), pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(g.C_GOLD if f.depth == 2 else g.C_FLAME, 1.0 - k))
	for b in g.bolts:
		var x: float = roundf(b.pos.x)
		var y: float = roundf(b.pos.y)
		if b.get("evo", false):
			PX.dot_ring(n, b.pos.round(), 5.0, 1.0, g.C_GOLD, 4.0, g.t * 6.0)
		var col: Color = g.C_FLAME if on_fire else (b.owner.get("col", g.C_GOLD) if b.get("owner") is Dictionary else g.C_GOLD)
		if b.look == "coin":
			n.draw_rect(Rect2(x - 2, y - 2, 5, 5), Color("2a1a10"))
			n.draw_rect(Rect2(x - 1, y - 1, 3, 3), g.C_FLAME if on_fire else g.C_GOLD)
			n.draw_rect(Rect2(x - 1, y - 1, 1, 1), Color.WHITE)
		elif b.look == "letter":
			# 捲起來的書信：米白色、中間一點紅色封印，跟著方向轉
			var d: Vector2 = b.dir
			var side := d.orthogonal()
			var c0: Vector2 = b.pos
			n.draw_line(c0 - d * 8.0, c0, Color(g.C_CREAM, 0.35), 2.0)
			n.draw_colored_polygon(PackedVector2Array([c0 - d * 3 - side * 2, c0 + d * 3 - side * 2, c0 + d * 3 + side * 2, c0 - d * 3 + side * 2]), g.C_FLAME if on_fire else Color("f4ead2"))
			n.draw_rect(Rect2(c0.round() - Vector2(0, 0), Vector2(1, 1)), Color("c0392b"))
		elif b.look == "pilum":
			# 羅馬標槍：木桿＋鐵尖
			var d: Vector2 = b.dir
			n.draw_line(b.pos - d * 9.0, b.pos, Color("8a6438"), 2.0)
			n.draw_line(b.pos - d * 1.0, b.pos + d * 3.0, g.C_FLAME if on_fire else Color("e0e0e8"), 2.0)
		elif b.look == "vial":
			# 藥瓶：淡青色的玻璃瓶、褐色軟木塞，跟著方向轉
			var d: Vector2 = b.dir
			var side := d.orthogonal()
			var c0: Vector2 = b.pos
			n.draw_line(c0 - d * 7.0, c0, Color(Color("8ae0d0"), 0.35), 2.0)
			n.draw_colored_polygon(PackedVector2Array([c0 - d * 3 - side * 2, c0 + d * 2 - side * 2, c0 + d * 2 + side * 2, c0 - d * 3 + side * 2]), g.C_FLAME if on_fire else Color("bff0e6"))
			n.draw_line(c0 + d * 2, c0 + d * 4, Color("8a5a30"), 2.0)
		elif b.look == "leaf":
			# 生命樹的葉子：綠色一小片，跟著方向轉
			var d: Vector2 = b.dir
			var side := d.orthogonal()
			var c0: Vector2 = b.pos
			n.draw_colored_polygon(PackedVector2Array([c0 - d * 4, c0 - side * 2, c0 + d * 4, c0 + side * 2]), g.C_FLAME if on_fire else Color("6ac850"))
			n.draw_line(c0 - d * 4, c0 + d * 3, Color("2a5a1a"), 1.0)
		elif b.look == "fig":
			n.draw_rect(Rect2(x - 2, y - 2, 4, 4), Color("2a1420"))
			n.draw_rect(Rect2(x - 1, y - 1, 3, 3), g.C_FLAME if on_fire else Color("8a4a8a"))
			n.draw_rect(Rect2(x, y - 2, 1, 1), Color("7a8a3a"))
		elif b.look == "stone":
			var sz: int = 3 if b.size >= 2 else 2
			n.draw_rect(Rect2(x - 1, y - 1, sz + 1, sz + 1), Color("2a2030"))
			n.draw_rect(Rect2(x, y - 1, sz, sz), Color("d8d0c0") if not on_fire else g.C_FLAME)
			n.draw_rect(Rect2(x, y - 1, 1, 1), Color.WHITE)
		else:
			# 光箭：後面拖一道光，比較看得出是誰射的、往哪飛
			var dir: Vector2 = b.get("dir", Vector2.RIGHT)
			n.draw_line(b.pos - dir * (10.0 + b.size * 3.0), b.pos, col.darkened(0.5), 2.0 + b.size)
			n.draw_line(b.pos - dir * (7.0 + b.size * 2.0), b.pos, col, 1.0 + b.size)
			n.draw_line(b.pos - dir * 5.0, b.pos, g.C_CREAM, 1.0)
			var r: int = 2 if b.size < 2 else 3
			n.draw_rect(Rect2(x - r, y - 1, r * 2 + 1, 3), col)
			n.draw_rect(Rect2(x - 1, y - r, 3, r * 2 + 1), col)
			n.draw_rect(Rect2(x - 1, y - 1, 3, 3), Color.WHITE)
	if g.boss != null and float(g.boss.get("vortex_t", 0.0)) > 0.0:
		# 漩渦：繞著 Boss 轉的弧線，越來越快
		for i in 4:
			var va: float = g.t * 5.0 + i * TAU / 4.0
			n.draw_arc(g.boss.pos, 30.0 + i * 14.0, va, va + 1.4, 16, Color(Color("a060ff"), 0.7), 2.0)
	for w in g.joy_waves:
		# 歡呼：金色的圈往外擴散，越外面越淡
		var ka: float = 1.0 - w.r / w.max
		PX.dot_ring(n, w.pos, w.r, 0.8, Color(g.C_GOLD, 0.3 + 0.6 * ka), 4.0, g.t * 2.0, 2)
	for ln in g.boss_lines:
		# 長老的指控：一道細線慢慢變亮，快落下時閃爍
		var k: float = clampf(1.0 - ln.t / ln.max, 0.0, 1.0)
		var on: bool = ln.t > 0.3 or int(g.t * 10.0) % 2 == 0
		n.draw_line(ln.a, ln.b, Color(g.C_RED, 0.15 + 0.25 * k), ln.w * (0.3 + 0.7 * k))
		if on:
			n.draw_line(ln.a, ln.b, Color(Color("ff3a2a"), 0.4 + 0.6 * k), 1.0)
		n.draw_circle(ln.a, 4.0, Color("c8a040"))
	for w in g.boss_walls:
		# 隔斷的牆：灰色的磚牆往中間推，門的地方空著
		var gy0: float = w.gap_y - w.gap_h / 2.0
		var gy1: float = w.gap_y + w.gap_h / 2.0
		n.draw_rect(Rect2(w.x - 5, w.top, 10, gy0 - w.top), Color("4a4448"))
		n.draw_rect(Rect2(w.x - 5, gy1, 10, w.bot - gy1), Color("4a4448"))
		n.draw_rect(Rect2(w.x - 3, w.top, 2, gy0 - w.top), Color("8a8088"))
		n.draw_rect(Rect2(w.x - 3, gy1, 2, w.bot - gy1), Color("8a8088"))
		n.draw_rect(Rect2(w.x - 6, gy0 - 3, 12, 3), Color("ffd75e"))
		n.draw_rect(Rect2(w.x - 6, gy1, 12, 3), Color("ffd75e"))
	if not g.tether.is_empty():
		# 捆鎖：從釘住的點拉到主角的一條鎖鏈，和一圈範圍
		PX.dot_ring(n, g.tether.pos, g.tether.r, 0.8, Color(Color("a8a8b8"), 0.8), 5.0, g.t, 1)
		var cl: Vector2 = g.paul.pos - g.tether.pos
		for i in int(cl.length() / 5.0):
			var cp: Vector2 = g.tether.pos + cl.normalized() * (i * 5.0)
			n.draw_rect(Rect2(cp.x - 1, cp.y - 1, 3, 3), Color("c8c8d8") if i % 2 == 0 else Color("6a6a7a"))
	g._draw_searchlight(n)
	for w in g.boss_waves:
		# 衝擊波：一圈紫紅色的牆，缺口的地方空著
		var a0: float = w.gap + w.gap_w
		var span: float = TAU - w.gap_w * 2.0
		n.draw_arc(w.pos, w.r, a0, a0 + span, 72, Color("14060c"), 11.0)
		n.draw_arc(w.pos, w.r, a0, a0 + span, 72, Color("8a1020"), 7.0)
		n.draw_arc(w.pos, w.r + 2.0, a0, a0 + span, 72, Color("ff5a40"), 2.0)
		# 缺口兩端畫亮一點，看得出從哪裡穿過去
		for ea in [w.gap - w.gap_w, w.gap + w.gap_w]:
			n.draw_circle(w.pos + Vector2.from_angle(ea) * w.r, 4.0, Color("ffd75e"))
	for s in g.shots:
		if s.get("boss", false):
			var sp2: Vector2 = s.pos.round()
			n.draw_circle(sp2, 4.0, Color("2a0a30"))
			n.draw_circle(sp2, 3.0, Color("c040e0"))
			n.draw_circle(sp2 + Vector2(-1, -1), 1.2, Color("ffd0ff"))
			continue
		n.draw_rect(Rect2(roundf(s.pos.x) - 1, roundf(s.pos.y) - 1, 3, 3), Color("c8e070"))
		n.draw_rect(Rect2(roundf(s.pos.x), roundf(s.pos.y), 1, 1), Color("2a2638"))
	for h in g.heals:
		if h.t > 0.75:
			continue
		# 醫治：身上冒出三顆綠色光點往上飄
		var hk: float = h.t / 0.75
		for j in 3:
			var hp2: Vector2 = h.who.pos + Vector2(-6 + j * 6, -10.0 - j * 4.0 - hk * 16.0 + (j % 2) * 3.0)
			g._fx(n, "heal", 3, int(hk * 3.0 + j * 0.5), hp2)
	for q in g.parts:
		var qc: Color = q.c1 if q.life > q.max * 0.5 else q.c2
		if q.get("float", false):
			var a: float = clampf(q.life / 0.4, 0.0, 1.0)
			n.draw_rect(Rect2(roundf(q.pos.x) - 1, roundf(q.pos.y), 3, 1), Color(qc, a * 0.6))
			n.draw_rect(Rect2(roundf(q.pos.x), roundf(q.pos.y) - 1, 1, 3), Color(qc, a))
		else:
			n.draw_rect(Rect2(roundf(q.pos.x), roundf(q.pos.y), 1, 1), qc)
	for im in g.impacts:
		# 打中：像素火花（大一擊用兩倍大），往前噴幾顆碎塊
		var k: float = im.t / 0.2
		var sz: float = im.size
		var ic: Color = im.col
		g._fx(n, "spark", 4, int(k * 4.0), im.pos, 2.0 if sz >= 12.0 else 1.0, Color.WHITE.lerp(ic, 0.3))
		if not g._fx_lite():
			var base_a: float = im.dir.angle() + im.rot
			for j in 3:
				var v := Vector2.from_angle(base_a + (j - 1) * 0.5)
				var dp: Vector2 = (im.pos + v * sz * (0.6 + 1.2 * k)).round()
				n.draw_rect(Rect2(dp, Vector2(2, 2)), ic.lightened(0.3))
	for sp in g.sparks:
		var sx: float = roundf(sp.pos.x)
		var sy: float = roundf(sp.pos.y)
		var ssz := 3 if sp.t < 0.06 else 2
		var scol: Color = sp.get("col", g.C_GOLD)
		n.draw_rect(Rect2(sx - ssz, sy, ssz * 2 + 1, 1), Color.WHITE)
		n.draw_rect(Rect2(sx, sy - ssz, 1, ssz * 2 + 1), Color.WHITE)
		n.draw_rect(Rect2(sx - 1, sy - 1, 3, 3), scol)
	for rz in g.resonances:
		var ra: float = 1.0 - rz.r / 260.0
		var rcol: Color = [g.C_GOLD, g.C_FLAME, Color("ff6ad5"), Color.WHITE][mini(rz.tier, 3)]
		var rw := int((2.0 + rz.tier) * ra) + 2
		g.PX.ring(n, rz.pos.round(), rz.r, rcol.darkened(0.6), rw + 1, 0.8)
		g.PX.ring(n, rz.pos.round(), rz.r, rcol, rw - 1, 0.8)
		g.PX.ring(n, rz.pos.round(), rz.r * 0.85, g.C_CREAM, 1, 0.8, 2)
		if rz.r < 60.0:
			var pw: float = (9.0 + rz.tier * 2) * ra
			n.draw_rect(Rect2(rz.pos.x - pw / 2.0, rz.pos.y - 120, pw, 120), rcol)
			n.draw_rect(Rect2(rz.pos.x - 1, rz.pos.y - 120, 3, 120), g.C_CREAM)
	for o in g.pops:
		var k: float = o.t / 0.25
		PX.dot_ring(n, o.pos.round(), o.size * (0.3 + k), 1.0, o.col, 3.0, 0.0, 2 if k < 0.5 else 1)
	var max_hp: float = g._comp_max_hp()
	for c in [g.paul] + g.comps:
		if c != g.paul and c.level == 0:
			continue
		var x: float = roundf(c.pos.x)
		var y: float = roundf(c.pos.y)
		if on_fire:
			var fl = int(g.t * 12.0) % 2
			n.draw_rect(Rect2(x - 1 + fl, y - 31, 2, 1), g.C_CREAM)
			n.draw_rect(Rect2(x - 1, y - 30, 3, 2), g.C_GOLD)
			n.draw_rect(Rect2(x - 1, y - 28, 3, 1), g.C_FLAME)
			continue
		if c == g.paul:
			continue
		for gi in int(c.get("garment", 0)):
			# 頭上的小衣服：一件一個
			n.draw_rect(Rect2(x - 5 + gi * 4, y - 34, 3, 3), Color("e8d8b0"))
			n.draw_rect(Rect2(x - 4 + gi * 4, y - 33, 1, 1), Color("c87a5a"))
		if c.hp < max_hp and c.down <= 0.0:
			n.draw_rect(Rect2(x - 5, y - 29, 10, 2), Color("0b080d"))
			n.draw_rect(Rect2(x - 5, y - 29, roundf(10.0 * c.hp / max_hp), 2), g.C_HEAL if c.hp > max_hp * 0.35 else g.C_RED)
		if c.down > 0.0:
			var frac: float = 1.0 - c.down / g.D.companion_rules.down_seconds
			n.draw_rect(Rect2(x - 5, y - 12, 10, 2), Color("0b080d"))
			n.draw_rect(Rect2(x - 5, y - 12, roundf(10.0 * frac), 2), g.C_CREAM)
		if c.alert > 0.0:
			n.draw_rect(Rect2(x - 2, y - 34, 5, 7), g.C_CREAM)
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
	if g._school_on("講道"):
		for e in g.enemies:
			var mc: int = int(e.get("msg", 0))
			if mc <= 0 or e.dead:
				continue
			var ex: float = roundf(e.pos.x) - mc * 2.0
			var ey: float = roundf(e.pos.y) - 20.0
			for i in mc:
				n.draw_rect(Rect2(ex + i * 4 - 1, ey - 1, 4, 4), Color("0c1e1c"))
				n.draw_rect(Rect2(ex + i * 4, ey, 2, 2), g.TAG_COL["講道"])
	# 被說服的敵人：頭上一個金色的光環
	for e in g.enemies:
		if float(e.get("ally", 0.0)) > 0.0 and not e.dead:
			var hx: float = roundf(e.pos.x)
			var hy: float = roundf(e.pos.y) - 21.0
			n.draw_rect(Rect2(hx - 4, hy, 9, 1), g.C_GOLD)
			n.draw_rect(Rect2(hx - 5, hy + 1, 1, 1), g.C_GOLD)
			n.draw_rect(Rect2(hx + 5, hy + 1, 1, 1), g.C_GOLD)
	# 門徒：小門徒（米白色的小人，快離開時閃爍）
	for m in g.minions:
		if m.life < 2.0 and int(g.t * 8.0) % 2 == 0:
			continue
		var mx: float = roundf(m.pos.x)
		var my: float = roundf(m.pos.y) - (3.0 if m.hop > 0.0 else 0.0)
		PX.person(n, mx, my, Color.WHITE, Color.WHITE)
		if m.hop > 0.0:
			n.draw_rect(Rect2(mx + 3, my - 7, 3, 1), g.C_CREAM)
	# 詩歌：全場的詩歌（金色的同心圈＋飛出去的音符）
	for sg in g.songs:
		var k: float = sg.t / 0.9
		var c0: Vector2 = sg.pos.round()
		for j in 3:
			var rr: float = 20.0 + (k * 260.0) - j * 26.0
			if rr > 0.0:
				n.draw_arc(c0, rr, 0.0, TAU, 64, [g.C_GOLD, g.C_CREAM, g.C_FLAME][j], 3.0 - j)
		for j in 10:
			var a := j * TAU / 10.0 + k * 1.5
			var np: Vector2 = (c0 + Vector2(cos(a), sin(a) * 0.8) * (16.0 + k * 140.0)).round()
			n.draw_rect(Rect2(np.x - 1, np.y - 1, 4, 3), Color("1a1008"))
			n.draw_rect(Rect2(np.x, np.y, 2, 2), g.C_GOLD)
			n.draw_rect(Rect2(np.x + 2, np.y - 5, 1, 6), g.C_GOLD)
			n.draw_rect(Rect2(np.x + 2, np.y - 5, 2, 1), g.C_GOLD)
	# 醫治：聖光（白綠色的十字光柱＋擴散的圈）
	for hl in g.holies:
		var k: float = hl.t / 0.7
		var c1: Vector2 = hl.pos.round()
		var w: float = 9.0 * (1.0 - k) + 2.0
		n.draw_rect(Rect2(c1.x - w / 2.0 - 1, c1.y - 110, w + 2, 110), Color("1a3a1e"))
		n.draw_rect(Rect2(c1.x - w / 2.0, c1.y - 110, w, 110), g.C_HEAL)
		n.draw_rect(Rect2(c1.x - 1, c1.y - 110, 2, 110), Color.WHITE)
		n.draw_rect(Rect2(c1.x - 14, c1.y - 30, 28, 4), g.C_HEAL)
		n.draw_rect(Rect2(c1.x - 14, c1.y - 29, 28, 2), Color.WHITE)
		n.draw_arc(c1, hl.r * minf(1.0, k * 2.0), 0.0, TAU, 48, g.C_HEAL, 3.0)
		n.draw_arc(c1, hl.r * minf(1.0, k * 2.0) - 4.0, 0.0, TAU, 48, Color.WHITE, 1.0)
	# 天降大雨：藍白色的雨線
	if not g.rains.is_empty():
		var v = g._view_rect()
		for i in 70:
			var rx: float = v.position.x + PX.hash2(i, 11) * v.size.x
			var ry: float = v.position.y + fmod(PX.hash2(i, 5) * v.size.y + g.t * 260.0, v.size.y)
			n.draw_rect(Rect2(roundf(rx), roundf(ry), 1, 6), Color("8fd0ff"))
			n.draw_rect(Rect2(roundf(rx), roundf(ry) + 4, 1, 2), Color.WHITE)
	# 同行合擊的加倍：頭上一個橘色的小火焰
	for k in g.bond_buff:
		var bm = g._member(k)
		if not bm.is_empty():
			var bx2: float = roundf(bm.pos.x)
			var by2: float = roundf(bm.pos.y) - 27.0 - (int(g.t * 8.0) % 2)
			n.draw_rect(Rect2(bx2 - 2, by2, 5, 4), Color("5a1a08"))
			n.draw_rect(Rect2(bx2 - 1, by2, 3, 3), g.C_FLAME)
			n.draw_rect(Rect2(bx2, by2 - 1, 1, 2), g.C_GOLD)
	# 已融合的流派：主角腳下兩色的光點互相繞（一組融合一對）
	var fi := 0
	for f in g.D.fusions:
		if not g._fused(f.a, f.b):
			continue
		var fa: float = g.t * 2.2 + fi * 1.3
		for j in 2:
			var ang := fa + j * PI
			var op: Vector2 = (g.paul.pos + Vector2(cos(ang) * (12.0 + fi * 2.0), 2.0 + sin(ang) * 4.0)).round()
			n.draw_rect(Rect2(op.x - 1, op.y - 1, 4, 4), Color("140c10"))
			n.draw_rect(Rect2(op.x, op.y, 2, 2), g.TAG_COL.get([f.a, f.b][j], g.C_GOLD))
		fi += 1
	# 主角腳下：讚美（金）與恩膏（綠）的小量條
	var bars := []
	if g._school_on("詩歌"):
		bars.append([g.praise / maxf(1.0, g._sv("詩歌", "praise_need")), g.C_GOLD])
	if g._school_on("醫治"):
		bars.append([g.anoint / maxf(1.0, g._sv("醫治", "anoint_need")), g.C_HEAL])
	var px: float = roundf(g.paul.pos.x) - 8.0
	var py: float = roundf(g.paul.pos.y) + 9.0
	for i in bars.size():
		n.draw_rect(Rect2(px - 1, py + i * 4 - 1, 18, 4), Color("0b080d"))
		n.draw_rect(Rect2(px, py + i * 4, roundf(16.0 * clampf(bars[i][0], 0.0, 1.0)), 2), bars[i][1])


# ---------- 寶箱與進化 ----------

