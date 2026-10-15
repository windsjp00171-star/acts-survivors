"""產生遊戲用的中文字型子集（網頁版沒辦法用系統字型，所以要把字型包進遊戲）。

只留下遊戲裡真的有用到的字：掃過 data/*.json 和 scripts/*.gd，再加上英數與常用標點。
新增文字（同伴、對話、生平…）之後，要再跑一次：python tools/make_font.py
字型：思源黑體（Noto Sans CJK TC Medium），SIL Open Font License。
"""
import glob
import os
from fontTools import subset
from fontTools.ttLib import TTCollection

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = "/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc"
OUT = os.path.join(ROOT, "assets", "fonts", "NotoSansTC-Game.otf")

chars = set()
for pat in ["data/*.json", "scripts/*.gd"]:
    for f in glob.glob(os.path.join(ROOT, pat)):
        chars |= set(open(f, encoding="utf-8").read())
chars |= set(chr(c) for c in range(0x20, 0x7F))
chars |= set("，。、；：！？「」『』（）《》〈〉…—–～・●○◆◇★☆✓✗✕▶▼▲←→↑↓＋－×÷％　０１２３４５６７８９ⅡⅠ")
chars = {c for c in chars if ord(c) >= 0x20}

ttc = TTCollection(SRC)
font = ttc.fonts[3]                      # Noto Sans CJK TC Medium
opts = subset.Options()
opts.layout_features = ["*"]
opts.name_IDs = ["*"]
opts.notdef_outline = True
sub = subset.Subsetter(opts)
sub.populate(text="".join(sorted(chars)))
sub.subset(font)
font.save(OUT)
print(f"{len(chars)} 個字 → {OUT}  {os.path.getsize(OUT) // 1024} KB")
