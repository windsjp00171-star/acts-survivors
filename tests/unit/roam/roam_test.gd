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


func _stays_within_leash() -> void:
	var d := Roam.decide(_me(), _world({"foes": [Vector2(float(R.leash) + 20.0, 0)]}), R)
	_expect(d.state == Roam.WANDER, "不該追到離主角太遠的地方")


func _spreads_out() -> void:
	var a := Vector2(60, 0)
	var b := Vector2(20, 70)
	var d := Roam.decide(_me({"pos": Vector2(50, 0)}), _world({"foes": [a, b], "mates": [a, a]}), R)
	_expect(d.pos.distance_to(b) < d.pos.distance_to(a), "別人在打的就換一群，不要全擠在一起")


func _gathers_before_boss() -> void:
	var g := Roam.decide(_me(), _world({"gather": true}), R)
	_expect(g.state == Roam.GATHER, "Boss 快出現時要先回主角身邊集合")
	_expect(g.pos.distance_to(Vector2.ZERO) <= float(R.gather_r) + 1.0, "集合要站在主角附近")
	var sees := Roam.decide(_me(), _world({"gather": true, "boss": Vector2(90, 0)}), R)
	_expect(sees.state == Roam.BOSS, "Boss 出來後改去打 Boss，不是繼續集合")
	var hurt := Roam.decide(_me({"hp_k": float(R.retreat_hp) - 0.05}), _world({"gather": true}), R)
	_expect(hurt.state == Roam.BACK, "快倒了還是先退回休息")


func _trouble_rule() -> void:
	_expect(Roam.hero_in_trouble(float(R.aid_hp) - 0.01, 0, R), "血少要算有難")
	_expect(Roam.hero_in_trouble(1.0, int(R.aid_crowd), R), "被圍要算有難")
	_expect(not Roam.hero_in_trouble(1.0, 0, R), "沒事不該叫人")
