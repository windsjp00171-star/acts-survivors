extends SceneTree
## 局外裝備測試。跑法：tests/unit/equipment/run.sh（用暫存 APPDATA，不碰真實存檔）
## 守住三件事：①掉出來的東西符合稀有度與保底 ②裝備給的加成不會超過花餅買滿（上限）③沒掉過裝備的舊存檔完全不受影響

const SaveScript := preload("res://scripts/save.gd")
const Equipment := preload("res://scripts/equipment.gd")

var fails := 0


func _initialize() -> void:
	await process_frame   # 樹還沒啟動時 add_child 不會觸發 _ready，meta 會是空的
	var s: Node = SaveScript.new()
	root.add_child(s)
	_roll_matches_rarity(s)
	_rarity_floor(s)
	_bonus_is_capped(s)
	_old_save_untouched(s)
	_wear_sell_and_json_roundtrip(s)
	print("RESULT ", "FAIL (%d)" % fails if fails else "PASS")
	quit(1 if fails else 0)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", msg)


func _rng(seed_: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	return r


func _roll_matches_rarity(s: Node) -> void:
	var cfg: Dictionary = s.equip_cfg
	for rar in cfg.rarities.size():
		var it := Equipment.roll(cfg, _rng(rar + 1), rar, 7)
		_expect(it.aff.size() == int(cfg.rarities[rar].affixes), "稀有度 %d 的詞綴數要等於資料表" % rar)
		_expect(it.aff.all(func(a): return cfg.affix_pool.has(a)), "詞綴只能從詞綴表抽")
	_expect(Equipment.roll(cfg, _rng(5), 2, 1) == Equipment.roll(cfg, _rng(5), 2, 1), "同一個種子要擲出同一件（測試與重現用）")


func _rarity_floor(s: Node) -> void:
	var cfg: Dictionary = s.equip_cfg
	var r := _rng(3)
	var low := 0
	for i in 400:
		if Equipment.pick_rarity(cfg, r, 1) == 0:
			low += 1
	_expect(low == 0, "Boss 保底至少精良：不能再抽到普通")


func _bonus_is_capped(s: Node) -> void:
	var ups: Array = s.meta.bread.upgrades
	var might: Dictionary = ups.filter(func(u): return u.id == "might")[0]
	var worn := [{"aff": ["might", "might", "might", "might", "might"]}]
	_expect(is_equal_approx(Equipment.bonus(ups, worn, "might"), int(might.max) * float(might.per)), "裝備堆再多也不能超過恩典上限（否則比花餅買滿還強）")
	_expect(Equipment.bonus(ups, worn, "haste") == 0.0, "沒有的詞綴不加成")
	_expect(Equipment.bonus(ups, [], "might") == 0.0, "沒穿東西不加成")


func _old_save_untouched(s: Node) -> void:
	s.load_profile()
	_expect(not s.data.has("equip"), "沒掉過裝備的存檔不該多出 equip 欄位（舊存檔與存檔碼不受影響）")
	var base: float = s.up_value("vigor")
	_expect(s.equip_worn().is_empty() and not s.data.has("equip"), "查詢穿著中的裝備不該順手建立欄位")
	_expect(is_equal_approx(base, 0.0), "全新存檔沒有永久恩典，堅忍加成為 0")


func _wear_sell_and_json_roundtrip(s: Node) -> void:
	s.load_profile()
	var item := {"id": 1, "slot": "staff", "rarity": 1, "name": "牧羊杖", "aff": ["vigor", "vigor"]}
	_expect(s.equip_add(item), "行囊沒滿時可以放進去")
	_expect(is_equal_approx(s.up_value("vigor"), 0.0), "放進行囊但沒穿，不加成")
	s.equip_wear(1)
	_expect(is_equal_approx(s.up_value("vigor"), 20.0), "穿上後堅忍 +20（兩條詞綴，每條 +10）")
	# 存檔本來就是 JSON：整數會變浮點，穿著狀態要還認得
	s.data = JSON.parse_string(JSON.stringify(s.data))
	_expect(is_equal_approx(s.up_value("vigor"), 20.0), "存檔往返後穿著狀態還在")
	var bread0 := int(s.data.get("bread", 0))
	var gain: int = s.equip_sell(1)
	_expect(gain == int(s.equip_cfg.rarities[1].sell) and int(s.data.bread) == bread0 + gain, "賣掉換到對應稀有度的餅")
	_expect(is_equal_approx(s.up_value("vigor"), 0.0) and s.equip_state().bag.is_empty(), "賣掉穿著中的東西，加成一起消失、行囊清空")
	for i in int(s.equip_cfg.bag_max):
		s.equip_add({"id": 100 + i, "slot": "cloak", "rarity": 0, "name": "x", "aff": ["might"]})
	_expect(not s.equip_add({"id": 999, "slot": "cloak", "rarity": 0, "name": "x", "aff": ["might"]}), "行囊滿了要擋下來")
