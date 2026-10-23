"""產生人物的像素圖（24×24：身體 18×22，兩格走路動畫＋進化版）。

用法：python tools/make_people.py
輸入：tools/people_src/<key>_0.png、_1.png（原本 14×17 的人物，當作「設定圖」：髮色、膚色、袍子、腰帶、鬍子、長髮、手上的東西都從這裡讀）
輸出：assets/sprites/<key>_0.png、_1.png、_evo_0.png、_evo_1.png

要改一個人的樣子：改他的設定圖（14×17，好畫），再跑一次這支程式；或在 OVERRIDES 裡指定。
新增人物：在 people_src 放一張 14×17 的設定圖（可以用 make_people_src 的 person() 產生）。
進化版：頭上一圈光環、腰帶變金色。
"""
import os

from PIL import Image

HERE = os.path.dirname(__file__)
SRC = os.path.join(HERE, "people_src")
OUT = os.path.join(HERE, "..", "assets", "sprites")
W, H = 26, 24
OX, OY = 3, 2          # 身體模板放在畫布的位置

# 身體模板（18×22）：a 外框、b 頭髮、B 頭髮暗面、c 皮膚、C 皮膚暗面、d 眼睛、e 袍子、E 袍子亮面、i 袍子暗面、f 腰帶、h 手、j 鞋
T = [
    "..................",
    "......aaaaaa......",
    "....aabbbbbbaa....",
    "...abbbbbbbbbba...",
    "...abbbbbbbbbBa...",
    "..abbcccccccbBba..",
    "..abccccccccccba..",
    "..acccdccccdccca..",
    "..acccdccccdccCa..",
    "..aCcccccccccCCa..",
    "...aCccccccccCa...",
    "....aaccccccaa....",
    "...aEeeeEeeeeia...",
    "..aEEeeeEeeeeeia..",
    ".ahEeeeeEeeeeiiha.",
    ".ahffffffffffffha.",
    "..aEeeeeEeeeeiia..",
    "..aEeeeeeeeeeiia..",
    "..aEeeeeeeeeeiia..",
    "...aiiiiiiiiiia...",
    "....ajja..ajja....",
    "....aaaa..aaaa....",
]
# 舊的 14×17 模板（用來分出「身體」和「手上的東西」）
OLD = [
    "..............",
    "..............",
    "..............",
    "....aaaaa.....",
    "...abbbbba....",
    "..abbbbbbba...",
    "..abcccccba...",
    "..acdcccdca...",
    "...accccca....",
    "...aeefeea....",
    "..aceefeea....",
    "..aieefeea....",
    "..aieeeeea....",
    "..aiieeeiia...",
    "...aaaaaaa....",
    "....jj.jj.....",
    "..............",
]

# 個別調整：手上的東西想放別的位置、或模板讀錯時
OVERRIDES = {
    "paul": {"bald": True},
}


def hexc(c):
    return "#%02x%02x%02x" % c[:3]


def shade(c, k):
    r, g, b = int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16)
    return "#%02x%02x%02x" % (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)))


def rgba(c):
    return (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), 255)


def read_spec(key):
    im = Image.open(os.path.join(SRC, key + "_0.png")).convert("RGBA")
    g = lambda x, y: im.getpixel((x, y))
    skin = hexc(g(5, 6))
    hair = hexc(g(3, 5))
    spec = {
        "skin": skin, "hair": hair, "robe": hexc(g(4, 11)), "sash": hexc(g(6, 11)), "dark": hexc(g(3, 13)),
        "feet": hexc(g(4, 15)),
        "bald": hexc(g(5, 4)) == skin,
        "beard": hexc(g(5, 8)) if g(5, 8)[3] and hexc(g(5, 8)) != skin else None,
        "long": g(2, 8)[3] > 0 and hexc(g(2, 8)) == hair,
    }
    spec.update(OVERRIDES.get(key, {}))
    return spec


def items(key, f):
    """舊圖上不屬於身體的像素（手上的東西、頭上的冠冕……）→ [(x, y, rgba)]"""
    im = Image.open(os.path.join(SRC, "%s_%d.png" % (key, f))).convert("RGBA")
    mask = [list(r) for r in OLD]
    if f == 1:
        mask = mask[1:] + [list("..............")]
        mask[14] = list("..............")
        mask[15] = list("...jj...jj....")
    out = []
    for y in range(17):
        for x in range(14):
            p = im.getpixel((x, y))
            if p[3] and mask[y][x] == ".":
                out.append((x, y, p))
    return out


def place_items(px, its, f):
    """手上的東西放大 1.5 倍、對準新的手（右手、左手、頭頂各一個對齊點）"""
    sh = 1 if f == 1 else 0          # 走路那一格整個人往上一格，舊圖的座標先放回原位
    for x, y, p in its:
        y0 = y + sh
        if y0 <= 2 and 3 <= x <= 10:
            ax, ay, nx0, ny0 = 6.5, 3, 11.5, 3        # 頭頂
        elif x >= 10:
            ax, ay, nx0, ny0 = 11, 11, 21, 17         # 右手
        elif x <= 2:
            ax, ay, nx0, ny0 = 1, 11, 2, 17           # 左手
        else:
            ax, ay, nx0, ny0 = 6.5, 11, 11.5, 17
        x0 = nx0 + (x - ax) * 1.5
        yy0 = ny0 + (y0 - ay) * 1.5
        for xx in range(int(x0), int(x0 + 1.5) if int(x0 + 1.5) > int(x0) else int(x0) + 1):
            for yy in range(int(yy0), int(yy0 + 1.5) if int(yy0 + 1.5) > int(yy0) else int(yy0) + 1):
                px(xx, yy - sh, p)


def person(key):
    s = read_spec(key)
    for evo in (False, True):
        if evo and not os.path.exists(os.path.join(SRC, key + "_evo_0.png")):
            continue
        for f in (0, 1):
            im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            rows = [list(r) for r in T]
            if f == 1:
                rows = rows[1:] + [list("..................")]
                rows[19] = list("....ajja....ajja..")
                rows[20] = list("....aaaa....aaaa..")
                rows[21] = list("..................")
            pal = {"a": "#2a1a14", "b": s["hair"], "B": shade(s["hair"], 0.72), "c": s["skin"], "C": shade(s["skin"], 0.86),
                   "d": "#1b1420", "e": s["robe"], "E": shade(s["robe"], 1.16), "i": s["dark"],
                   "f": "#ffd75e" if evo else s["sash"], "j": s["feet"], "h": s["skin"]}
            if s["bald"]:
                for y in (2, 3, 4):
                    for x in range(18):
                        if rows[y][x] in "bB":
                            rows[y][x] = "c"
            for y, row in enumerate(rows):
                for x, ch in enumerate(row):
                    if ch in pal:
                        im.putpixel((x + OX, y + OY), rgba(pal[ch]))
            dy = -1 if f == 1 else 0

            def px(x, y, col):
                y += dy if False else 0
                if 0 <= x < W and 0 <= y < H:
                    im.putpixel((int(x), int(y)), col if isinstance(col, tuple) else rgba(col))

            def bp(x, y, col):    # 身體座標（模板）→ 畫布
                px(x + OX, y + OY + dy, col)

            if s["bald"]:
                bp(6, 2, shade(s["skin"], 1.12))
                bp(7, 2, shade(s["skin"], 1.12))
            bp(6, 7, "#5a4a6a")   # 眼睛的亮點
            bp(11, 7, "#5a4a6a")
            if s["long"]:
                for y in range(5, 14):
                    bp(2, y, s["hair"])
                    bp(15, y, shade(s["hair"], 0.8))
                bp(1, 8, "#2a1a14")
                bp(16, 8, "#2a1a14")
                for y in range(9, 14):
                    bp(1, y, "#2a1a14")
                    bp(16, y, "#2a1a14")
            if s["beard"]:
                b, bd = s["beard"], shade(s["beard"], 0.8)
                for x in range(4, 14):
                    bp(x, 10, b)
                for x in range(5, 13):
                    bp(x, 11, b)
                for x in range(6, 12):
                    bp(x, 12, bd if x in (6, 11) else b)
                bp(4, 9, b)
                bp(13, 9, bd)
                bp(3, 9, b)
                bp(8, 9, "#8a4a3a")   # 嘴
                bp(9, 9, "#8a4a3a")
            else:
                bp(8, 9, shade(s["skin"], 0.7))
                bp(9, 9, shade(s["skin"], 0.7))
            place_items(lambda x, y, c: px(x, y + dy, c), items(key, f), f)
            if evo:
                for x in range(7, 13):
                    bp(x, -1, "#ffd75e")
                bp(6, 0, "#fff4c2")
                bp(13, 0, "#fff4c2")
            # 外框：身體以外的東西也補一圈深色（手上的東西才不會糊在背景裡）
            im.save(os.path.join(OUT, "%s%s_%d.png" % (key, "_evo" if evo else "", f)))


if __name__ == "__main__":
    keys = sorted({n.rsplit("_", 1)[0] for n in os.listdir(SRC) if n.endswith("_0.png") and "_evo" not in n})
    for k in keys:
        person(k)
    print(len(keys), "people")
