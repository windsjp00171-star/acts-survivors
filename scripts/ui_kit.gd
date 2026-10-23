class_name UIKit
## 介面共用的字型、顏色、樣式。

const INK := Color("f4ead2")
const GOLD := Color("ffd75e")
const CREAM := Color("fff4c2")
const SKY := Color("4fd8ff")
const HEAL := Color("7be08a")
const RED := Color("e8481c")
const BRONZE := Color("c9a46b")
const MUTED := Color("a8977c")
const DARK := Color("0b080d")
const PANEL := Color("241a2e")

static var _font: Font


## 遊戲內建的中文字型（tools/make_font.py 產生的子集）；缺字時退回系統字型
## 設定「字大一點」：所有文字放大約兩成（給長輩與看不清楚小字的人）
static func big(size: int) -> int:
	return roundi(size * 1.2) if bool(Save.data.get("bigtext_on", false)) else size


static func font() -> Font:
	if _font == null:
		var f: FontFile = load("res://assets/fonts/NotoSansTC-Game.otf")
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(["Noto Sans CJK TC", "Noto Sans TC", "Microsoft JhengHei", "PingFang TC", "Heiti TC", "sans-serif"])
		f.fallbacks = [sys]
		_font = f
	return _font


static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font()
	ls.font_size = big(size)
	ls.font_color = color
	ls.outline_size = 2
	ls.outline_color = Color("140c10", 0.85)
	ls.shadow_size = 0
	ls.shadow_offset = Vector2(1, 1)
	ls.shadow_color = Color(0, 0, 0, 0.6)
	l.label_settings = ls
	return l


static func box(bg: Color, border: Color, pad := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.content_margin_left = pad + 2
	s.content_margin_right = pad + 2
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


static func button(text: String, size := 14, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", big(size))
	var fg := Color("2a1a14") if primary else INK
	for st in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", MUTED)
	if primary:
		b.add_theme_stylebox_override("normal", box(BRONZE, DARK, 6))
		b.add_theme_stylebox_override("hover", box(GOLD, DARK, 6))
		b.add_theme_stylebox_override("focus", box(GOLD, DARK, 6))
		b.add_theme_stylebox_override("pressed", box(CREAM, DARK, 6))
	else:
		b.add_theme_stylebox_override("normal", box(PANEL, BRONZE, 6))
		b.add_theme_stylebox_override("hover", box(Color("3a2a40"), GOLD, 6))
		b.add_theme_stylebox_override("focus", box(Color("3a2a40"), GOLD, 6))
		b.add_theme_stylebox_override("pressed", box(Color("5a4420"), CREAM, 6))
	b.add_theme_stylebox_override("disabled", box(Color("1a1420"), Color("3a3040"), 6))
	b.pressed.connect(func(): Sfx.play("ui", 0.0))
	return b


static func sprite_icon(key: String, scale := 3) -> TextureRect:
	var tr := TextureRect.new()
	var path := "res://assets/sprites/%s_0.png" % key
	if ResourceLoader.exists(path):
		tr.texture = load(path)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.custom_minimum_size = Vector2(26, 24) * scale * 0.75
	return tr
