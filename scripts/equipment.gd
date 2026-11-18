extends RefCounted
## 局外裝備（信物）的純邏輯：掉落時擲一件、算穿著後的加成。不碰存檔，方便單獨測試。
## 詞綴 id 就是永久恩典（data/meta.json 的 bread.upgrades）的 id，一條 = 該恩典 +1 級。


## 依權重抽稀有度；min_rarity 是保底（例如 Boss 至少精良）
static func pick_rarity(cfg: Dictionary, rng: RandomNumberGenerator, min_rarity := 0) -> int:
	var rars: Array = cfg.rarities
	var total := 0
	for i in range(min_rarity, rars.size()):
		total += int(rars[i].weight)
	var r := rng.randi_range(1, total)
	for i in range(min_rarity, rars.size()):
		r -= int(rars[i].weight)
		if r <= 0:
			return i
	return rars.size() - 1


## 擲一件裝備。seq 是流水號（存檔裡的 equip.seq），當作這件的 id
static func roll(cfg: Dictionary, rng: RandomNumberGenerator, rarity: int, seq: int) -> Dictionary:
	var slot: Dictionary = cfg.slots[rng.randi_range(0, cfg.slots.size() - 1)]
	var pool: Array = cfg.affix_pool
	var aff := []
	for i in int(cfg.rarities[rarity].affixes):
		aff.append(pool[rng.randi_range(0, pool.size() - 1)])
	var names: Array = slot.names
	return {"id": seq, "slot": slot.id, "rarity": rarity, "name": names[rng.randi_range(0, names.size() - 1)], "aff": aff}


## 穿著中的裝備替某個恩典 id 加了多少（已套上該恩典的等級上限）
static func bonus(upgrades: Array, worn: Array, id: String) -> float:
	var n := 0
	for it in worn:
		for a in it.aff:
			if a == id:
				n += 1
	if n == 0:
		return 0.0
	for u in upgrades:
		if u.id == id:
			return mini(n, int(u.max)) * float(u.per)
	return 0.0
