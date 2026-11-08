extends CanvasLayer
## 史詩感全螢幕調色（自動載入，名稱 Grade）。參數在 scripts/draw/post_grade_epic.gdshader。
## arpg（宣教之路 2 試作）場景自動排除，維持原本的外觀；命令列加 --nograde 關閉（結構重構的逐像素基準用）。

const SHADER := preload("res://scripts/draw/post_grade_epic.gdshader")

var rect: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--nograde" in OS.get_cmdline_user_args():
		set_process(false)
		return
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER
	rect.material = m
	add_child(rect)


func _process(_dt: float) -> void:
	var s := get_tree().current_scene
	rect.visible = s == null or not s.scene_file_path.ends_with("arpg.tscn")
