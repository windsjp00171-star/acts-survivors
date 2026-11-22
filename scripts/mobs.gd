extends RefCounted
## 敵人走路圖（LPC 素材，tools/make_world_lpc.py 產生）：4 排（上、左、下、右）× N 格，每格正方形，遊戲裡用一半大小畫。

const People := preload("res://scripts/people.gd")
const WALK_FPS := 7.0
const FOOT := 6.0   # 腳底在敵人中心點往下幾格（命中圈以中心點算）

static var _sheets := {}


static func _path(key: String) -> String:
	return "res://assets/sprites/mobs/%s.png" % key


static func has(key: String) -> bool:
	return _sheets.has(key) or ResourceLoader.exists(_path(key))


## 整張圖（半大小）
static func _sheet(key: String) -> Texture2D:
	if not _sheets.has(key):
		var im: Image = (load(_path(key)) as Texture2D).get_image()
		var tx := ImageTexture.create_from_image(im)
		tx.set_size_override(Vector2i(im.get_width() / 2, im.get_height() / 2))
		_sheets[key] = tx
	return _sheets[key]


static func setup(node: Sprite2D, key: String) -> void:
	var tx := _sheet(key)
	var cell := tx.get_height() / 4
	node.texture = tx
	node.vframes = 4
	node.hframes = tx.get_width() / cell
	node.centered = false
	node.offset = Vector2(-cell / 2.0, FOOT - cell)


static func pose(node: Sprite2D, dir: Vector2, t: float) -> void:
	node.frame = People.facing(dir, People.DOWN) * node.hframes + int(t * WALK_FPS) % node.hframes


## 單格（原始大小）：圖鑑用
static func frame(key: String) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = load(_path(key))
	var c := a.atlas.get_height() / 4
	a.region = Rect2(0, People.DOWN * c, c, c)
	return a
