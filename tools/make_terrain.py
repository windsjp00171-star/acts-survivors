"""產生各城市的地面與場景物件（程式畫的像素圖）。

用法：python tools/make_terrain.py
輸出：assets/sprites/ground_<城市>.png（128×128、可無縫平鋪）與各種物件圖。
腓立比沿用原本的 ground.png。各城市用哪些物件寫在 data/stages.json 的 props。
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
S = 128


def hx(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def h(x, y, s=0):
    v = (x * 374761393 + y * 668265263 + s * 2246822519) & 0xFFFFFFFF
    v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
    return (v ^ (v >> 16)) / 4294967296


def pnoise(x, y, g, s=0):
    """可平鋪的平滑雜訊（週期 S）"""
    n = S // g
    ix, iy = x // g, y // g
    fx, fy = (x % g) / g, (y % g) / g
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    w = lambda i: i % n
    a, b = h(w(ix), w(iy), s), h(w(ix + 1), w(iy), s)
    c, d = h(w(ix), w(iy + 1), s), h(w(ix + 1), w(iy + 1), s)
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy


def ground(name, fn):
    im = Image.new("RGBA", (S, S))
    for y in range(S):
        for x in range(S):
            im.putpixel((x, y), hx(fn(x, y)))
    im.save(os.path.join(OUT, "ground_%s.png" % name))


# ---------- 地面 ----------
def g_thessalonica(x, y):
    # 紅土路：深淺不一的赭紅色土，散著小石子
    n = pnoise(x, y, 16, 1) * 0.7 + pnoise(x, y, 32, 2) * 0.3 + (h(x, y, 3) - 0.5) * 0.1
    if h(x, y, 4) > 0.985:
        return "#c8b8a0"
    return "#c47a52" if n > 0.62 else "#a8603e" if n > 0.45 else "#8e4e34"


def g_corinth(x, y):
    # 港口：淺色沙地，鋪了一排排不規則的石板
    n = pnoise(x, y, 16, 5)
    row = (y // 16)
    off = 8 if row % 2 else 0
    bx, by = (x + off) % 16, y % 16
    if n > 0.55 and (bx == 0 or by == 0):
        return "#8a8070"
    if n > 0.55:
        return "#c8bca4" if h((x + off) // 16, row, 6) > 0.5 else "#bcb098"
    return "#e8d4a8" if h(x, y, 7) > 0.15 else "#d8c090"


def g_ephesus(x, y):
    # 大道：灰紫色的石板路，縫裡長草
    bx, by = x % 32, y % 16
    off = 16 if (y // 16) % 2 else 0
    bx = (x + off) % 32
    if bx == 0 or by == 0:
        return "#5b6b2f" if h(x, y, 8) < 0.35 else "#4a4450"
    v = h((x + off) // 32, y // 16, 9)
    base = ["#8a8494", "#7e7888", "#948ea0"][int(v * 3)]
    return "#a8a2b4" if h(x, y, 10) > 0.97 else base


def g_athens(x, y):
    # 大理石廣場：白色方磚、淡灰色紋路
    bx, by = x % 16, y % 16
    if bx == 0 or by == 0:
        return "#b8b4a8"
    vein = abs(math.sin((x * 0.4 + y * 0.25) + pnoise(x, y, 16, 11) * 6))
    t = h(x // 16, y // 16, 12)
    base = "#f0ece0" if t > 0.5 else "#e6e0d0"
    return "#d0cabc" if vein < 0.06 else base


def g_jerusalem(x, y):
    # 石灰岩：金黃色的大石塊，錯縫砌
    row = y // 12
    off = 12 if row % 2 else 0
    bx, by = (x + off) % 24, y % 12
    if bx == 0 or by == 0:
        return "#a0804a"
    t = h((x + off) // 24, row, 13)
    base = ["#e0c080", "#d4b070", "#e8cc90"][int(t * 3)]
    return "#c8a464" if h(x, y, 14) > 0.93 else base


def g_malta(x, y):
    # 海邊沙灘：淺黃色的沙、浪留下的波紋、小貝殼
    n = pnoise(x, y, 32, 15)
    wave = math.sin((y + n * 20) * 0.5)
    if wave > 0.93:
        return "#f4e8c8"
    if h(x, y, 16) > 0.993:
        return "#f0d0d0"
    return "#e8d49c" if n > 0.5 else "#dcc48c"


def g_rome(x, y):
    # 羅馬大道：深色玄武岩鵝卵石，灰色砂漿
    cx, cy = x // 8, y // 8
    best, second = 9e9, 9e9
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            px = (cx + dx) * 8 + h((cx + dx) % 16, (cy + dy) % 16, 17) * 8
            py = (cy + dy) * 8 + h((cx + dx) % 16, (cy + dy) % 16, 18) * 8
            d = (x - px) ** 2 + (y - py) ** 2
            if d < best:
                second, best = best, d
            elif d < second:
                second = d
    if math.sqrt(second) - math.sqrt(best) < 1.2:
        return "#8a8478"
    t = h(x // 8, y // 8, 19)
    return ["#4a4650", "#56525c", "#3e3a44"][int(t * 3)]


def g_patmos(x, y):
    # 拔摩海島：深灰褐色的火山岩地，岩縫間有一點點苔與海鹽
    n = pnoise(x, y, 16, 20) * 0.6 + pnoise(x, y, 32, 21) * 0.4
    crack = abs(pnoise(x, y, 8, 22) - 0.5) < 0.03
    if crack:
        return "#2e2a30"
    if h(x, y, 23) > 0.992:
        return "#e8e4dc"
    if n > 0.66 and h(x, y, 24) > 0.6:
        return "#5a6a3a"
    return "#6a6068" if n > 0.55 else "#5a5058" if n > 0.4 else "#4c444c"


# ---------- 物件 ----------
class C:
    def __init__(self, w, h_):
        self.im = Image.new("RGBA", (w, h_), (0, 0, 0, 0))
        self.w, self.h = w, h_

    def px(self, x, y, col):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.im.putpixel((x, y), hx(col) if isinstance(col, str) else col)

    def rect(self, x, y, w, h_, col):
        for yy in range(int(y), int(y + h_)):
            for xx in range(int(x), int(x + w)):
                self.px(xx, yy, col)

    def oval(self, cx, cy, rx, ry, cols, seed=0, rough=0.0):
        for y in range(self.h):
            for x in range(self.w):
                dx, dy = (x - cx) / rx, (y - cy) / ry
                v = dx * dx + dy * dy
                if v > 1 or (v > 0.7 and h(x, y, seed) < rough):
                    continue
                l = -dx * 0.5 - dy * 0.6 + (h(x, y, seed + 3) - 0.5) * 0.4
                self.px(x, y, cols[2] if l > 0.4 else cols[1] if l > -0.3 else cols[0])

    def outline(self, col="#26201a"):
        get = lambda x, y: 0 <= x < self.w and 0 <= y < self.h and self.im.getpixel((x, y))[3] > 0
        pts = [(x, y) for y in range(self.h) for x in range(self.w)
               if not get(x, y) and any(get(x + a, y + b) for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
        for x, y in pts:
            self.px(x, y, col)

    def save(self, name):
        self.im.save(os.path.join(OUT, name + ".png"))


def column(name, height, broken=False):
    c = C(14, height + 6)
    top = 3
    c.rect(1, top, 12, 3, "#e8e4d8")             # 柱頭
    c.rect(2, height + 2, 10, 3, "#d8d4c8")      # 柱基
    for y in range(top + 3, height + 2):
        for x in range(3, 11):
            col = "#f4f0e4" if x in (4, 5) else "#d8d4c8" if x in (8, 9) else "#e8e4d8"
            if x in (6, 10):
                col = "#c8c4b8"
            c.px(x, y, col)
    if broken:
        for x in range(1, 13):
            for y in range(0, top + 6 + int(h(x, 1, 2) * 4)):
                c.px(x, y, (0, 0, 0, 0))
    c.outline("#6a665e")
    c.save(name)


def statue():
    c = C(16, 30)
    c.rect(1, 22, 14, 7, "#c8c4b8")
    c.rect(1, 22, 14, 1, "#e8e4d8")
    c.oval(8, 15, 4, 8, ("#b8b4a8", "#d8d4c8", "#f0ece0"), 3)
    c.oval(8, 5, 2.5, 2.5, ("#b8b4a8", "#d8d4c8", "#f0ece0"), 4)
    c.outline("#6a665e")
    c.save("statue")


def olive(name, seed):
    c = C(30, 30)
    for y in range(15, 30):
        x = 15 + math.sin(y * 0.5 + seed) * 1.5
        c.rect(x - 1, y, 3, 1, "#6a5a48")
    for i in range(5):
        c.oval(8 + h(i, seed) * 14, 7 + h(i, seed, 1) * 8, 5 + h(i, seed, 2) * 3, 4, ("#5a6a4a", "#7a8a68", "#a0ac90"), seed + i, 0.2)
    c.outline("#2a3020")
    c.save(name)


def palm(name, seed):
    c = C(30, 38)
    for y in range(12, 38):
        x = 15 + (38 - y) * 0.12 * (1 if seed % 2 else -1)
        c.rect(x - 1, y, 3, 1, "#8a6a48" if y % 3 else "#6a5038")
    cx = 15 + 26 * 0.12 * (1 if seed % 2 else -1)
    for a in range(7):
        ang = -math.pi + a * math.pi / 6
        for r in range(12):
            x = cx + math.cos(ang) * r
            y = 12 + math.sin(ang) * r * 0.6 + (r * r) * 0.04
            c.px(x, y, "#4a7a3a" if r < 8 else "#6a9a4a")
            c.px(x, y + 1, "#3a5a2a")
    c.outline("#203018")
    c.save(name)


def wall(name, w):
    c = C(w, 18)
    for y in range(2, 18):
        row = (y - 2) // 4
        for x in range(w):
            off = 4 if row % 2 else 0
            # 灰褐色的粗石牆，和金黃色的石灰岩地面分得開
            if (x + off) % 8 == 0 or (y - 2) % 4 == 0:
                c.px(x, y, "#4a4038")
            else:
                c.px(x, y, "#8a7c6a" if h((x + off) // 8, row, 30) > 0.5 else "#7a6c5a")
    for x in range(w):
        c.px(x, 1, "#a89880")
    c.outline("#2a221a")
    # 牆腳的影子
    for x in range(w):
        c.px(x, 17, (20, 14, 8, 110))
    c.save(name)


def arch():
    c = C(40, 40)
    for x in range(40):
        for y in range(4, 40):
            inside = (x - 20) ** 2 / 100 + (y - 24) ** 2 / 196 < 1 and y > 14
            if inside or y > 36:
                continue
            c.px(x, y, "#c8b898" if (x // 6 + y // 5) % 2 else "#bcac8c")
    c.rect(0, 2, 40, 3, "#e0d0b0")
    c.outline("#5a4a30")
    c.save("arch")


def cypress(name):
    c = C(14, 36)
    c.rect(6, 30, 2, 6, "#5a4030")
    for y in range(2, 31):
        w = 5 * math.sin(min(1, (y - 2) / 22) * math.pi * 0.55)
        for x in range(14):
            if abs(x - 7) < w:
                c.px(x, y, "#2a4a2a" if x > 7 else "#3a5a34")
    c.outline("#142014")
    c.save(name)


def amphora():
    c = C(10, 16)
    c.oval(5, 10, 3.5, 5, ("#8a4a2a", "#b0603a", "#d08050"), 40)
    c.rect(4, 2, 3, 4, "#a05a34")
    c.px(2, 4, "#a05a34")
    c.px(8, 4, "#a05a34")
    c.outline("#3a2010")
    c.save("amphora")


def shell():
    c = C(8, 6)
    c.oval(4, 3, 3.5, 2.5, ("#d8a8a0", "#f0c8c0", "#fff0e8"), 41)
    c.outline("#8a6058")
    c.save("shell")


def pool():
    c = C(36, 18)
    for y in range(18):
        for x in range(36):
            v = ((x - 18) / 17) ** 2 + ((y - 9) / 8) ** 2 + (h(x, y, 42) - 0.5) * 0.15
            if v < 1:
                c.px(x, y, "#3a8ab8" if v < 0.5 else "#5aa8d0" if v < 0.85 else "#f0e8d0")
    c.save("pool")


def driftwood():
    c = C(20, 8)
    for x in range(2, 18):
        y = 4 + math.sin(x * 0.5) * 1
        c.rect(x, y, 1, 2, "#a08868" if x % 4 else "#806848")
    c.outline("#3a2a18")
    c.save("driftwood")


def crag(name, seed, w, h_):
    # 拔摩的岩塊：深色火山岩，頂上一點白色鹽霜
    c = C(w, h_)
    c.oval(w / 2, h_ * 0.6, w / 2 - 1, h_ * 0.42, ("#2e2830", "#4a4250", "#6a6070"), seed, 0.15)
    c.oval(w * 0.4, h_ * 0.35, w * 0.28, h_ * 0.3, ("#3a3440", "#5a5262", "#7a7084"), seed + 1, 0.1)
    for i in range(4):
        c.px(w * 0.3 + i * 2, h_ * 0.18 + (i % 2), "#e8e4dc")
    c.outline("#141016")
    c.save(name)


def scroll_stone():
    # 寫著字的石版（啟 1:11 你所看見的當寫在書上）
    c = C(14, 18)
    c.rect(2, 2, 10, 15, "#8a8478")
    c.rect(3, 3, 8, 13, "#b8b2a4")
    for yy in range(5, 15, 2):
        c.rect(4, yy, 6 if yy % 4 else 4, 1, "#5a564c")
    c.outline("#2a261e")
    c.save("tablet")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("thessalonica", g_thessalonica), ("corinth", g_corinth), ("ephesus", g_ephesus), ("athens", g_athens),
                     ("jerusalem", g_jerusalem), ("malta", g_malta), ("rome", g_rome), ("patmos", g_patmos)]:
        ground(name, fn)
    column("column_1", 26)
    column("column_2", 26, broken=True)
    statue()
    olive("olive_1", 1)
    olive("olive_2", 2)
    palm("palm_1", 1)
    palm("palm_2", 2)
    wall("wall_1", 34)
    wall("wall_2", 22)
    arch()
    cypress("cypress")
    amphora()
    shell()
    pool()
    driftwood()
    crag("crag_1", 50, 26, 20)
    crag("crag_2", 53, 18, 14)
    scroll_stone()
    print("done")
