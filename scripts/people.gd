extends RefCounted
## 人物圖（LPC 部件拼的走路圖，tools/make_people_lpc.py 產生）：取整張圖、擺姿勢、取單格。
## 一張 576×256：9 格（0 站姿、1–8 走路）× 4 排（上、左、下、右），每格 64×64。
## 遊戲裡用一半大小畫（set_size_override），世界座標、碰撞、伸縮動畫都不用改，細節多一倍。

const UP := 0
const LEFT := 1
const DOWN := 2
const RIGHT := 3
const COLS := 9
const ROWS := 4
const CELL := 64
const WALK_FPS := 10.0
const FOOT := Vector2(-16, -31)   # 腳底對到節點原點

static var _sheets := {}


static func _path(key: String, evo: bool) -> String:
	var p := "res://assets/sprites/lpc/%s%s.png" % [key, "_evo" if evo else ""]
	return p if ResourceLoader.exists(p) else "res://assets/sprites/lpc/%s.png" % key


static func has(key: String) -> bool:
	return ResourceLoader.exists("res://assets/sprites/lpc/%s.png" % key)


## 整張走路圖（半大小）
static func sheet(key: String, evo := false) -> Texture2D:
	var p := _path(key, evo)
	if not _sheets.has(p):
		var im: Image = (load(p) as Texture2D).get_image()
		var t := ImageTexture.create_from_image(im)
		t.set_size_override(Vector2i(im.get_width() / 2, im.get_height() / 2))
		_sheets[p] = t
	return _sheets[p]


## 面向哪一排：左右為主，明顯往上或往下才換；沒在動就維持原來的
static func facing(d: Vector2, now: int) -> int:
	if d.length() < 0.01:
		return now
	if absf(d.x) >= absf(d.y) * 0.8:
		return RIGHT if d.x > 0.0 else LEFT
	return DOWN if d.y > 0.0 else UP


static func pose(node: Sprite2D, key: String, evo: bool, row: int, moving: bool, t: float) -> void:
	node.texture = sheet(key, evo)
	node.hframes = COLS
	node.vframes = ROWS
	node.centered = false
	node.offset = FOOT
	node.flip_h = false
	node.frame = row * COLS + (1 + int(t * WALK_FPS) % (COLS - 1) if moving else 0)


## 單格（原始大小）：給頭像、標題畫面用。預設裁成和舊人物圖一樣的 26:24 比例
static func frame(key: String, row := DOWN, col := 0, evo := false) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = load(_path(key, evo))
	var r := Rect2(2, 5, 60, 57) if evo else Rect2(6, 14, 52, 48)
	a.region = Rect2(Vector2(col, row) * CELL + r.position, r.size)
	return a
