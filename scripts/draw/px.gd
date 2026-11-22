extends RefCounted
## 像素繪圖小工具（從 main.gd 抽出）：全是靜態函式，只靠傳進來的 Node2D `n` 畫，不讀 main 的狀態。
## 呼叫方式 PX.ring(n, ...)。顏色先沿用原本的字面值，美術階段 A 再收進 token。

const GOLD := Color("ffd75e")   # 同 main.gd 的 C_GOLD


## 呂底亞的紫布：一片橢圓的布（一橫條一橫條畫，邊上金色流蘇），在原解析度畫才不會變成大方塊
static func cloth(n: Node2D, c: Vector2, r: float, a: float, evo: bool) -> void:
	var ry := r * 0.62
	for yy in range(-int(ry), int(ry) + 1):
		var half := floorf(r * sqrt(maxf(0.0, 1.0 - pow(yy / ry, 2.0))))
		if half < 1.0:
			continue
		var col := Color("6e3068") if posmod(yy, 4) < 2 else Color("8e4488")
		n.draw_rect(Rect2(c.x - half, c.y + yy, half * 2.0 + 1.0, 1), Color(col, a))
		n.draw_rect(Rect2(c.x - half, c.y + yy, 1, 1), Color(GOLD if evo else Color("c8a040"), a))
		n.draw_rect(Rect2(c.x + half, c.y + yy, 1, 1), Color(GOLD if evo else Color("c8a040"), a))
	ring(n, c, r, Color(GOLD, a), 1, 0.62, 1)


## 彼得的網：斜格子的漁網＋一圈網邊和鉛墜
static func net(n: Node2D, c: Vector2, r: float, a: float, col: Color) -> void:
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
	ring(n, c, r, Color(Color("6b4a2a"), a), 2, 0.75)
	for i in 10:
		var ang := i * TAU / 10.0
		n.draw_rect(Rect2((c + Vector2(cos(ang) * r, sin(ang) * ry)).round() - Vector2(1, 1), Vector2(3, 3)), Color(Color("8a8a9a"), a))


## 一條像素線（每一步畫一個 w×w 的方塊）
static func line(n: Node2D, a: Vector2, b: Vector2, col: Color, w := 1) -> void:
	var d := b - a
	var steps := maxi(1, int(maxf(absf(d.x), absf(d.y))))
	var off := Vector2(w / 2, w / 2)
	for i in steps + 1:
		var p := (a + d * (float(i) / steps)).round() - off
		n.draw_rect(Rect2(p, Vector2(w, w)), col)


## 像素圓環（橢圓：ky 是上下壓扁的比例）
static func ring(n: Node2D, c: Vector2, r: float, col: Color, w := 1, ky := 0.75, gap := 0) -> void:
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

static func dot_ring(n: Node2D, center: Vector2, r: float, squash: float, col: Color, every: float, ph: float, thick := 1) -> void:
	var count := maxi(12, int(r * TAU / every))
	for k in count:
		var a := k / float(count) * TAU + ph
		n.draw_rect(Rect2(round(center.x + cos(a) * r), round(center.y + sin(a) * r * squash), thick, thick), col)


## 小人（小門徒、慕道的人）：用門徒的人物圖縮小畫，衣服顏色用染色分辨
static var _small: Texture2D


static func person(n: Node2D, x: float, y: float, robe: Color, _sash: Color) -> void:
	if _small == null:
		_small = preload("res://scripts/people.gd").frame("disciple")
	n.draw_texture_rect(_small, Rect2(x - 8, y - 14, 17, 15.7), false, Color.WHITE.lerp(robe, 0.45))


## 座標雜湊成 0~1（不用亂數，同一格永遠同樣結果）
static func hash2(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h) / 4294967296.0
