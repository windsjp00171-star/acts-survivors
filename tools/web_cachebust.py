"""網頁版換檔名：把 build/web/index.pck 改名成 index-<版本>.pck，並改 index.html 讓遊戲讀新檔名。

每一版的遊戲資料檔名都不一樣，瀏覽器就不會一直用舊版的快取。
用法：匯出 Web 之後執行 python tools/web_cachebust.py
"""
import glob
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "..")
WEB = os.path.join(ROOT, "build", "web")

ver = re.search(r'version/name="([^"]+)"', open(os.path.join(ROOT, "export_presets.cfg"), encoding="utf-8").read()).group(1)
pack = "index-%s.pck" % ver
for old in glob.glob(os.path.join(WEB, "index-*.pck")):
    os.remove(old)
os.replace(os.path.join(WEB, "index.pck"), os.path.join(WEB, pack))
p = os.path.join(WEB, "index.html")
s = open(p, encoding="utf-8").read()
assert '"index.pck":' in s
s = s.replace('"index.pck":', '"%s":' % pack).replace('"executable":"index",', '"executable":"index","mainPack":"%s",' % pack)
assert '"mainPack":"%s"' % pack in s
open(p, "w", encoding="utf-8").write(s)
print(pack)
