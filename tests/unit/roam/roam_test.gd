extends SceneTree
## 「分頭行動」同伴智能測試。跑法：tests/unit/roam/run.sh
## 守住玩家在意的事：王出來大家往王那邊去、主角有難會來支援、快倒了會退回來、不會追到太遠、不會全部擠去打同一隻

const Roam := preload("res://scripts/roam.gd")

var R: Dictionary
var fails := 0


func _initialize() -> void:
	R = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json")).roam
	_boss_draws_everyone()
	_hero_in_trouble_gets_help()
	_hurt_companion_retreats_and_rests()
	_stays_within_leash()
	_spreads_out()
	_trouble_rule()
	_gathers_before_boss()
	_roles()
	_attackers_patrol_far()
	_rally_when_hero_nearly_dead()
	_healer_heals_hero_first()
	print("RESULT ", "FAIL (%d)" % fails if fails else "PASS")
	quit(1 if fails else 0)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", msg)


func _me(over := {}) -> Dictionary:
	var m := {"pos": Vector2(40, 0), "hp_k": 1.0, "range": 60.0, "rank": 0, "i": 0, "n": 4, "t": 0.0, "resting": false}
	m.merge(over, true)
	return m


func _world(over := {}) -> Dictionary:
	var w := {"hero": Vector2.ZERO, "hero_trouble": false, "boss": null, "foes": [Vector2(60, 0)], "mates": []}
	w.merge(over, true)
	return w


func _boss_draws_everyone() -> void:
	var boss := Vector2(90, 40)
	for i in 4:
		var d := Roam.decide(_me({"i": i, "rank": i}), _world({"boss": boss}), R)
		_expect(d.state == Roam.BOSS, "王出來時第 %d 位沒有往王去" % i)
		_expect(d.pos.distance_to(boss) < 70.0, "第 %d 位離王太遠：%s" % [i, d.pos])


func _hero_in_trouble_gets_help() -> void:
	var near := Roam.decide(_me({"rank": 0}), _world({"hero_trouble": true, "boss": Vector2(90, 0)}), R)
	_expect(near.state == Roam.AID, "主角有難，最近的同伴應該先來救，連王都先放下")
	var far := Roam.decide(_me({"rank": int(R.aid_count)}), _world({"hero_trouble": true}), R)
	_expect(far.state == Roam.FIGHT, "不用全隊都跑來，其餘的繼續打")


func _hurt_companion_retreats_and_rests() -> void:
	var low := Roam.decide(_me({"hp_k": float(R.retreat_hp) - 0.05}), _world({"hero_trouble": true, "boss": Vector2(90, 0)}), R)
	_expect(low.state == Roam.BACK, "快倒了應該先退回來")
	var rest := Roam.decide(_me({"hp_k": (float(R.retreat_hp) + float(R.return_hp)) / 2.0, "resting": true}), _world(), R)
	_expect(rest.state == Roam.BACK, "休息還沒好就跑出去會來回抖動")
	var ok := Roam.decide(_me({"hp_k": float(R.return_hp) + 0.01, "resting": true}), _world(), R)
	_expect(ok.state == Roam.FIGHT, "休息好了要回去打")


## 使用者要的是：攻擊型各自出去打、往不同方向散開，不是圍在主角身邊；但不能跑到看不見的地方
## 橫式畫面（640×360、鏡頭 2.5 倍）看得到主角四周約 ±128 × ±72
const VIEW_HALF := Vector2(128, 72)


func _attackers_patrol_far() -> void:
	var spots := []
	for i in 4:
		var d := Roam.decide(_me({"i": i, "role": "attacker"}), _world({"foes": []}), R)
		_expect(d.state == Roam.WANDER, "沒敵人時應該去巡邏")
		_expect(d.pos.length() > 50.0, "攻擊型巡邏點離主角太近（%.0f），又會圍在身邊" % d.pos.length())
		_expect(absf(d.pos.x) <= VIEW_HALF.x and absf(d.pos.y) <= VIEW_HALF.y, "第 %d 位巡邏點跑出畫面：%s" % [i, d.pos])
		spots.append(d.pos)
	_expect(spots[0].distance_to(spots[2]) > 150.0, "攻擊型應該往不同方向散開")
	var heal := Roam.decide(_me({"role": "healer"}), _world({"foes": []}), R)
	_expect(heal.pos.length() < 100.0, "醫療沒事時待在主角附近，方便補血")


## 主角血少（aid_hp 以下）只來最近幾位；快死了（rally_hp 以下）全員都回來
func _rally_when_hero_nearly_dead() -> void:
	var far_rank := int(R.aid_count) + 1
	var some := Roam.decide(_me({"rank": far_rank}), _world({"hero_trouble": true, "hero_hp_k": float(R.aid_hp) - 0.05}), R)
	_expect(some.state != Roam.AID, "血少但還撐得住：遠的同伴繼續打")
	var all := Roam.decide(_me({"rank": far_rank}), _world({"hero_trouble": true, "hero_hp_k": float(R.rally_hp) - 0.05}), R)
	_expect(all.state == Roam.AID, "主角快死了，遠的同伴也要回來")


## 醫療：主角和同伴都受傷時，先去補主角
func _healer_heals_hero_first() -> void:
	var mate := {"pos": Vector2(50, 0), "hp_k": 0.3}
	var hero := {"pos": Vector2.ZERO, "hp_k": 0.5, "hero": true}
	var d := Roam.decide(_me({"pos": Vector2(60, 0), "role": "healer"}), _world({"hurt": [mate, hero]}), R)
	_expect(d.state == Roam.HEAL, "有人受傷，醫療應該去補")
	_expect(d.pos.distance_to(Vector2.ZERO) < float(R.heal_r), "主角受傷時醫療要先到主角身邊")


func _stays_within_leash() -> void:
	var d := Roam.decide(_me(), _world({"foes": [Vector2(float(R.leash_attacker) + 20.0, 0)]}), R)
	_expect(d.state == Roam.WANDER, "不該追到離主角太遠的地方")


func _spreads_out() -> void:
	# 兩群敵人都在這位同伴的地盤裡（巡邏點在主角右邊 patrol_r）
	var p := Vector2(float(R.patrol_r), 0)
	var a := p + Vector2(10, 0)
	var b := p + Vector2(-30, 70)
	var d := Roam.decide(_me({"pos": p + Vector2(-10, 0)}), _world({"foes": [a, b], "mates": [a, a]}), R)
	_expect(d.pos.distance_to(b) < d.pos.distance_to(a), "別人在打的就換一群，不要全擠在一起")


func _gathers_before_boss() -> void:
	var g := Roam.decide(_me(), _world({"gather": true}), R)
	_expect(g.state == Roam.GATHER, "Boss 快出現時要先回主角身邊集合")
	_expect(g.pos.distance_to(Vector2.ZERO) <= float(R.gather_r) + 1.0, "集合要站在主角附近")
	var sees := Roam.decide(_me(), _world({"gather": true, "boss": Vector2(90, 0)}), R)
	_expect(sees.state == Roam.BOSS, "Boss 出來後改去打 Boss，不是繼續集合")
	var hurt := Roam.decide(_me({"hp_k": float(R.retreat_hp) - 0.05}), _world({"gather": true}), R)
	_expect(hurt.state == Roam.BACK, "快倒了還是先退回休息")


func _roles() -> void:
	var sick := {"pos": Vector2(150, 40), "hp_k": float(R.heal_below) - 0.2}
	var healer := Roam.decide(_me({"role": "healer"}), _world({"hurt": [sick], "foes": []}), R)
	_expect(healer.state == Roam.HEAL and healer.pos.distance_to(sick.pos) < float(R.heal_r), "醫療角色要去受傷的同伴身邊")
	var far := {"pos": Vector2(float(R.heal_range) + 100.0, 0), "hp_k": 0.1}
	_expect(Roam.decide(_me({"role": "healer"}), _world({"hurt": [far], "foes": []}), R).state != Roam.HEAL, "太遠的不去")
	_expect(Roam.decide(_me({"role": "attacker"}), _world({"hurt": [sick]}), R).state == Roam.FIGHT, "攻擊角色不管補血，照樣打敵人")
	var far_foe := Vector2(float(R.leash_guard) + 40.0, 0)
	_expect(Roam.decide(_me({"role": "guard"}), _world({"foes": [far_foe]}), R).state == Roam.GUARD, "守衛不離主角太遠，沒事就守在身邊")
	_expect(Roam.decide(_me({"role": "attacker"}), _world({"foes": [far_foe]}), R).state == Roam.FIGHT, "攻擊角色會追得比較遠")
	var aid := Roam.decide(_me({"role": "guard", "rank": int(R.aid_count) + 3}), _world({"hero_trouble": true}), R)
	_expect(aid.state == Roam.AID, "主角有難，守衛不分遠近都會衝回來")


func _trouble_rule() -> void:
	_expect(Roam.hero_in_trouble(float(R.aid_hp) - 0.01, 0, R), "血少要算有難")
	_expect(Roam.hero_in_trouble(1.0, int(R.aid_crowd), R), "被圍要算有難")
	_expect(not Roam.hero_in_trouble(1.0, 0, R), "沒事不該叫人")
