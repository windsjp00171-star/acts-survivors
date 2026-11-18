"""人物新比例（約 4.3 頭身）的示範產生器：只輸出到指定資料夾，不動 assets/sprites。

用法：python tools/make_people_v2.py <輸出資料夾> [人物 key ...]    （預設保羅、彼得、司提反）
沿用 make_people.py 的設定圖讀法（髮色、膚色、袍子、鬍子、手上的東西），只換身體模板與畫布。
畫布 26×34（舊的 26×24）：頭 6×7、肩窄、腰收、長袍到腳踝。
輸出：<key>_0.png、<key>_1.png（走路兩格）、<key>_evo_*.png（有進化設定圖時），以及 compare.png（新舊 8 倍對照）。
"""
import os
import sys

from PIL import Image

import make_people as mp

W, H = 26, 34
OX, OY = 3, 2

# 身體模板（18 寬）：a 外框、b 頭髮、B 頭髮暗面、c 皮膚、C 皮膚暗面、d 眼睛、e 袍子、E 袍子亮面、i 袍子暗面、f 腰帶、h 手、j 鞋
T = [
    "..................",
    "......aaaaaa......",
    ".....abbbbbba.....",
    ".....abbbbbBa.....",
    ".....abccccba.....",
    ".....acdccdca.....",
    ".....acccccCa.....",
    ".....aaccccaa.....",
    "......acCCca......",
    "...aEEeeeeeeiia...",
    "..aEEeeeEeeeeiia..",
    "..aEEeeeEeeeeiia..",
    "..aEeeeeEeeeeiia..",
    "..aEeeeeEeeeeiia..",
    "..aEeeeeEeeeeiia..",
    "..aEeeeeEeeeeiia..",
    "..ahEeeeEeeeeiha..",
    "...affffffffffa...",
    "...aEeeeEeeeeia...",
    "...aEeeeEeeeeia...",
    "...aEeeeeeeeeia...",
    "...aEeeeeeeeeia...",
    "...aEeeeeeeeeia...",
    "..aEeeeeEeeeeiia..",
    "..aEeeeeEeeeeiia..",
    "..aEeeeeeeeeeiia..",
    "..aEeeeeeeeeeiia..",
    "..aEeeeeeeeeeiia..",
    "..aiiiiiiiiiiiia..",
    "....ajja..ajja....",
    "....aaaa..aaaa....",
]
HAND_ROW = next(i for i, r in enumerate(T) if "h" in r)
FEET = len(T) - 2


def place_items(px, its, f):
    """手上的東西放大 1.5 倍、對準新的手（右手、左手、頭頂各一個對齊點）"""
    sh = 1 if f == 1 else 0
    hy = OY + HAND_ROW
    for x, y, p in its:
        y0 = y + sh
        if y0 <= 2 and 3 <= x <= 10:
            ax, ay, nx0, ny0 = 6.5, 3, 11.5, 3
        elif x >= 10:
            ax, ay, nx0, ny0 = 11, 11, 20, hy
        elif x <= 2:
            ax, ay, nx0, ny0 = 1, 11, 3, hy
        else:
            ax, ay, nx0, ny0 = 6.5, 11, 11.5, hy
        x0 = nx0 + (x - ax) * 1.5
        yy0 = ny0 + (y0 - ay) * 1.5
        for xx in range(int(x0), max(int(x0 + 1.5), int(x0) + 1)):
            for yy in range(int(yy0), max(int(yy0 + 1.5), int(yy0) + 1)):
                px(xx, yy - sh, p)


def person(key, out):
    s = mp.read_spec(key)
    for evo in (False, True):
        if evo and not os.path.exists(os.path.join(mp.SRC, key + "_evo_0.png")):
            continue
        for f in (0, 1):
            im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            rows = [list(r) for r in T]
            if f == 1:
                rows = rows[1:] + [list("." * 18)]
                rows[FEET - 1] = list("....ajja.ajja.....")
                rows[FEET] = list("....aaaa.aaaa......")
                rows[FEET + 1] = list("." * 18)
            pal = {"a": "#2a1a14", "b": s["hair"], "B": mp.shade(s["hair"], 0.72), "c": s["skin"], "C": mp.shade(s["skin"], 0.86),
                   "d": "#1b1420", "e": s["robe"], "E": mp.shade(s["robe"], 1.16), "i": s["dark"],
                   "f": "#ffd75e" if evo else s["sash"], "j": s["feet"], "h": s["skin"]}
            if s["bald"]:
                for y in (2, 3, 4):
                    for x in range(18):
                        if rows[y][x] in "bB":
                            rows[y][x] = "c"
            for y, row in enumerate(rows):
                for x, ch in enumerate(row):
                    if ch in pal:
                        im.putpixel((x + OX, y + OY), mp.rgba(pal[ch]))
            dy = -1 if f == 1 else 0

            def px(x, y, col):
                if 0 <= x < W and 0 <= y < H:
                    im.putpixel((int(x), int(y)), col if isinstance(col, tuple) else mp.rgba(col))

            def bp(x, y, col):
                px(x + OX, y + OY + dy, col)

            if s["bald"]:
                bp(8, 2, mp.shade(s["skin"], 1.12))
                bp(9, 2, mp.shade(s["skin"], 1.12))
            if s["long"]:
                for y in range(4, 11):
                    bp(5, y, s["hair"])
                    bp(12, y, mp.shade(s["hair"], 0.8))
                for y in range(5, 11):
                    bp(4, y, "#2a1a14")
                    bp(13, y, "#2a1a14")
            if s["beard"]:
                b, bd = s["beard"], mp.shade(s["beard"], 0.8)
                bp(6, 6, b)
                bp(11, 6, bd)
                for x in range(6, 12):
                    bp(x, 7, bd if x == 11 else b)
                for x in range(7, 11):
                    bp(x, 8, b)
                for x in (8, 9):
                    bp(x, 9, b)
                    bp(x, 6, "#8a4a3a")   # 嘴
            else:
                bp(8, 6, mp.shade(s["skin"], 0.7))
                bp(9, 6, mp.shade(s["skin"], 0.7))
            place_items(lambda x, y, c: px(x, y + dy, c), mp.items(key, f), f)
            if evo:
                for x in range(6, 12):
                    bp(x, -1, "#ffd75e")
                bp(5, 0, "#fff4c2")
                bp(12, 0, "#fff4c2")
            im.save(os.path.join(out, "%s%s_%d.png" % (key, "_evo" if evo else "", f)))


def compare(keys, out, scale=8):
    """上排舊、下排新（同一個縮放），腳底對齊。"""
    cols = len(keys)
    sheet = Image.new("RGBA", (cols * 32 * scale, (24 + 34 + 4) * scale), (40, 30, 50, 255))
    for i, k in enumerate(keys):
        old = Image.open(os.path.join(mp.OUT, k + "_0.png")).convert("RGBA")
        new = Image.open(os.path.join(out, k + "_0.png")).convert("RGBA")
        for im, top in ((old, 2), (new, 24 + 4)):
            big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
            sheet.paste(big, ((i * 32 + 3) * scale, top * scale), big)
    sheet.save(os.path.join(out, "compare.png"))


if __name__ == "__main__":
    out = sys.argv[1]
    keys = sys.argv[2:] or ["paul", "peter", "stephen"]
    os.makedirs(out, exist_ok=True)
    assert all(len(r) == 18 for r in T), [i for i, r in enumerate(T) if len(r) != 18]
    for k in keys:
        person(k, out)
    compare(keys, out)
    print(len(keys), "people →", out)
