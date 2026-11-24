extends RefCounted
## 「分頭行動」隊形的判斷：每位同伴自己決定現在要做什麼、往哪裡站。純計算，不碰場景，數字在 data/game.json 的 roam。
## 優先順序：自己快倒了就退回主角身邊 > 主角有危險去支援 > Boss 出現去打 Boss > 附近的敵人 > 沒事做就在主角附近走動

const BACK := "back"     # 退回主角身邊休息
const AID := "aid"       # 去支援主角
const BOSS := "boss"     # 往 Boss 移動
const FIGHT := "fight"   # 打附近的敵人
const WANDER := "wander"
const GATHER := "gather" # Boss 快出現：先回主角身邊集合
const HEAL := "heal"     # 醫療角色：去受傷的同伴身邊補血
const GUARD := "guard"   # 守衛角色：守在主角身邊


## 該去支援主角的情況：血少，或被一群敵人貼身
static func hero_in_trouble(hp_k: float, crowd: int, R: Dictionary) -> bool:
	return hp_k < float(R.aid_hp) or crowd >= int(R.aid_crowd)


## me：{pos, hp_k, range, role（attacker／healer／guard）, rank（離主角由近到遠第幾位）, i, n, t, resting}
## world：{hero, hero_trouble, boss（Vector2 或 null）, foes（位置）, mates（其他同伴的目標位置）, hurt（受傷同伴的 {pos, hp_k}）}
static func decide(me: Dictionary, world: Dictionary, R: Dictionary) -> Dictionary:
	var hero: Vector2 = world.hero
	var role: String = me.get("role", "attacker")
	var leash: float = float(R.get("leash_" + role, R.leash))
	var reach: float = clampf(float(me.range) * float(R.stand), float(R.stand_min), float(R.stand_max))
	if float(me.hp_k) < float(R.retreat_hp) or (bool(me.resting) and float(me.hp_k) < float(R.return_hp)):
		return {"state": BACK, "pos": hero + _ring(me, float(R.back_r))}
	if bool(world.hero_trouble) and (role == "guard" or int(me.rank) < int(R.aid_count)):
		return {"state": AID, "pos": hero + _ring(me, float(R.aid_r))}
	if bool(world.get("gather", false)) and world.boss == null:
		return {"state": GATHER, "pos": hero + _ring(me, float(R.gather_r))}
	if world.boss != null:
		return {"state": BOSS, "pos": world.boss + _ring(me, maxf(reach, float(R.boss_r)))}
	if role == "healer":
		var sick := Vector2.INF
		var sick_d := float(R.heal_range)
		for h: Dictionary in world.get("hurt", []):
			var d: float = me.pos.distance_to(h.pos)
			if float(h.hp_k) < float(R.heal_below) and d < sick_d:
				sick_d = d
				sick = h.pos
		if sick != Vector2.INF:
			return {"state": HEAL, "pos": sick + _ring(me, float(R.heal_r) * 0.5)}
	# 攻擊型各有一塊遠處的地盤（巡邏點附近），只打地盤裡或撞到身上的敵人；主角身邊的留給主角
	var patrol: Vector2 = hero + _ring(me, float(R.get("patrol_r", R.wander_r)))
	var best := Vector2.INF
	var best_s := INF
	for f: Vector2 in world.foes:
		if f.distance_to(hero) > leash:
			continue
		if role == "attacker" and R.has("zone_r") and f.distance_to(patrol) > float(R.zone_r) and f.distance_to(me.pos) > float(R.self_r):
			continue
		var s: float = f.distance_to(me.pos)
		for m: Vector2 in world.mates:
			if m.distance_to(f) < float(R.share_r):
				s += float(R.share_cost)   # 別人已經在打了，儘量分開
		if s < best_s:
			best_s = s
			best = f
	if best != Vector2.INF:
		var away: Vector2 = me.pos - best
		away = away.normalized() if away.length() > 0.5 else Vector2.RIGHT
		return {"state": FIGHT, "pos": best + away * reach}
	if role == "guard":
		return {"state": GUARD, "pos": hero + _ring(me, float(R.guard_r))}
	# 攻擊型沒敵人可打：各自往不同方向跑遠去巡邏（像別的玩家在地圖另一頭）；醫療在主角附近走動
	return {"state": WANDER, "pos": patrol if role == "attacker" else hero + _ring(me, float(R.wander_r))}


## 同伴各站一個方向，慢慢轉，不會疊在一起
static func _ring(me: Dictionary, r: float) -> Vector2:
	var a: float = TAU * float(me.i) / maxf(1.0, float(me.n)) + float(me.t) * 0.15
	return Vector2(cos(a), sin(a) * 0.8) * r
