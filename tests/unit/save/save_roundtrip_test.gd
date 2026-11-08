extends SceneTree
## 存檔往返測試：重構期間守住「舊存檔、舊存檔碼永遠讀得回來」。
##   跑法：tests/unit/save/run.sh（會用暫存 APPDATA，不碰真實存檔）
##   重新產生黃金樣本（只有確定要改相容性時才做）：run.sh --gen
## 黃金樣本 golden/*.code 是「某個版本匯出的存檔碼」。之後的程式必須還讀得進來，
## 而且讀出來的資料要和 golden/*.json（當時的讀檔結果）一致。

const SaveScript := preload("res://scripts/save.gd")
const PROFILES := ["fresh", "after_ch1", "mid"]
const GOLDEN := "res://tests/unit/save/golden/"
const PROFILE_DIR := "res://tools/sim/profiles/"

var fails := 0


func _initialize() -> void:
	await process_frame   # 樹還沒啟動時 add_child 不會觸發 _ready，meta 會是空的
	var gen := "--gen" in OS.get_cmdline_user_args()
	for name in PROFILES:
		var s := _fresh_save()
		_install(PROFILE_DIR + name + ".json")
		s.load_profile()
		if gen:
			_write_golden(name, s)
		else:
			_check_roundtrip(name, s)
			_check_golden(name)
		s.free()
	if not gen:
		print("RESULT ", "FAIL (%d)" % fails if fails else "PASS")
	quit(1 if fails else 0)


func _fresh_save() -> Node:
	var s: Node = SaveScript.new()
	root.add_child(s)   # _ready 會讀 meta/story 並 load_profile
	return s


func _install(res_path: String) -> void:
	var f := FileAccess.open("user://profile.json", FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(res_path))
	f.close()


## 經過 JSON 一圈再比：存檔本來就是 JSON，整數／浮點的表示法不該造成誤判
func _canon(d: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(d)), "", true)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL: ", msg)


func _check_roundtrip(name: String, s: Node) -> void:
	var before := _canon(s.data)
	# 1. 存檔碼匯出再匯入
	var err: String = s.import_code(s.export_code())
	_expect(err == "", "%s 匯入自己匯出的存檔碼失敗：%s" % [name, err])
	_expect(_canon(s.data) == before, "%s 存檔碼往返後資料不同" % name)
	# 2. 寫檔再讀檔
	s.save_profile()
	s.load_profile()
	_expect(_canon(s.data) == before, "%s 寫檔再讀檔後資料不同" % name)
	# 3. 壞掉的存檔碼要被擋下來，而且不能動到資料
	for bad in ["", "ACTS1:", "ACTS1:%%%", "XYZ:abc"]:
		_expect(s.import_code(bad) != "", "%s 壞存檔碼『%s』居然成功" % [name, bad])
	_expect(_canon(s.data) == before, "%s 壞存檔碼動到了資料" % name)


func _check_golden(name: String) -> void:
	var code_path := GOLDEN + name + ".code"
	var json_path := GOLDEN + name + ".json"
	if not FileAccess.file_exists(code_path):
		_expect(false, "缺黃金樣本 %s（先跑 run.sh --gen）" % code_path)
		return
	var s := _fresh_save()
	var err: String = s.import_code(FileAccess.get_file_as_string(code_path))
	_expect(err == "", "%s 黃金存檔碼讀不進來：%s" % [name, err])
	var want = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	_expect(_canon(s.data) == _canon(want), "%s 黃金存檔碼讀出的資料和當時不同" % name)
	s.free()


func _write_golden(name: String, s: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN))
	var c := FileAccess.open(GOLDEN + name + ".code", FileAccess.WRITE)
	c.store_string(s.export_code())
	c.close()
	var j := FileAccess.open(GOLDEN + name + ".json", FileAccess.WRITE)
	j.store_string(JSON.stringify(s.data, "  ", true))
	j.close()
	print("golden written: ", name)
