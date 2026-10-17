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


def g_field(x, y):
    # 撒馬利亞：綠色的草地裡一塊塊金黃的麥田，零星的小花
    n = pnoise(x, y, 32, 40) * 0.75 + pnoise(x, y, 16, 41) * 0.25
    if n > 0.6:
        # 麥田：一行行斜斜的麥稈
        return "#e0b85a" if (x + y // 2) % 4 else "#c89a40"
    if h(x, y, 42) > 0.992:
        return "#f4e8f0" if h(x, y, 43) > 0.5 else "#f0c040"
    g = n + (h(x, y, 44) - 0.5) * 0.12
    return "#7a9a48" if g > 0.45 else "#6a8a3e" if g > 0.3 else "#5c7a36"


def g_desert(x, y):
    # 往大馬色的路：白亮的沙地，風吹出的沙紋，小石子
    n = pnoise(x, y, 32, 45)
    ripple = math.sin((x * 0.35 + y * 0.9) + n * 9)
    if h(x, y, 46) > 0.99:
        return "#8a7a62"
    if ripple > 0.9:
        return "#f4e4bc"
    if ripple < -0.92:
        return "#c8b07c"
    return "#e8d4a0" if n > 0.45 else "#dcc690"


def g_joppa(x, y):
    # 約帕的碼頭：大塊淺色石板，石縫裡積著沙，有些石板被海水打濕
    row = y // 20
    off = 10 if row % 2 else 0
    bx, by = (x + off) % 20, y % 20
    wet = pnoise(x, y, 32, 47) > 0.62
    if bx == 0 or by == 0:
        return "#c8b48a"
    t = h((x + off) // 20, row, 48)
    base = ["#d8d0c0", "#ccc4b2", "#e0d8c8"][int(t * 3)]
    if wet:
        base = ["#c4bcac", "#bab2a2", "#ccc4b4"][int(t * 3)]
    return "#f0ece0" if h(x, y, 49) > 0.985 else base


def g_antioch(x, y):
    # 安提阿的柱廊大街：灰藍色的石板，縫裡長出綠草
    row = y // 16
    off = 8 if row % 2 else 0
    bx, by = (x + off) % 16, y % 16
    if bx == 0 or by == 0:
        return "#5a7a3a" if h(x, y, 50) < 0.45 else "#4a5058"
    t = h((x + off) // 16, row, 51)
    base = ["#8a96a0", "#7c8892", "#96a2aa"][int(t * 3)]
    return "#6a8a4a" if pnoise(x, y, 32, 52) > 0.7 and h(x, y, 53) > 0.5 else base


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


def g_fucheng(x, y):
    # 府城的街：踩實的黃土路，有些地方鋪了舊紅磚（磚縫灰白、邊角磨圓），偶爾一點青苔
    n = pnoise(x, y, 16, 31) * 0.6 + pnoise(x, y, 32, 32) * 0.4
    patch = pnoise(x, y, 32, 34)
    if patch > 0.66:
        row = y // 4
        bx = (x + (row % 2) * 4) // 8
        if (x + (row % 2) * 4) % 8 == 0 or y % 4 == 0:
            return "#9a8068"
        return "#b4886a" if h(bx, row, 35) > 0.5 else "#a87e62"
    if h(x, y, 33) > 0.99:
        return "#e0d0b0"
    if h(x, y, 36) > 0.996:
        return "#6a7a4a"
    return "#c4a47a" if n > 0.62 else "#b49470" if n > 0.42 else "#a48662"


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


def house():
    # 耶路撒冷的平頂屋：白灰牆、木門、小窗、屋頂一圈矮牆，外面一道樓梯（上到樓房去）
    c = C(32, 28)
    c.rect(4, 8, 22, 19, "#e8dcc4")
    c.rect(4, 8, 22, 2, "#f4ecd8")
    for y in range(10, 27):
        c.px(25, y, "#c8b898")
    c.rect(3, 6, 24, 2, "#d8ccb4")
    c.rect(12, 18, 6, 9, "#6a4a2a")
    c.rect(13, 19, 4, 8, "#8a643a")
    c.rect(7, 12, 3, 3, "#3a2a1a")
    c.rect(19, 12, 3, 3, "#3a2a1a")
    # 外牆的樓梯：一階一階往上到屋頂
    for y in range(9, 27):
        w = min(6, (y - 9) // 3 + 1)
        c.rect(26, y, w, 1, "#d0c4aa" if (y - 9) % 3 else "#f0e6d0")
    c.outline("#4a3a24")
    for x in range(32):
        c.px(x, 27, (20, 14, 8, 90))
    c.save("house")


def stones():
    # 一堆拳頭大的石頭
    c = C(16, 9)
    for i, (x, y, r) in enumerate([(4, 6, 2.6), (9, 6, 3.0), (13, 7, 2.0), (6.5, 3.5, 2.2), (11, 3.5, 2.0)]):
        c.oval(x, y, r + 0.6, r, ("#7a7268", "#9a9288", "#c0b8ac"), 60 + i)
    c.outline("#3a342c")
    c.save("stones")


def well():
    # 雅各井：圓形石井欄、木架、吊著水桶
    c = C(20, 24)
    c.oval(10, 18, 9, 5, ("#7a7060", "#9a9080", "#b8ae9c"), 61)
    c.oval(10, 17, 6, 3, ("#1a2430", "#24323e", "#2e4050"), 62)
    c.rect(2, 4, 2, 13, "#6a4a2a")
    c.rect(16, 4, 2, 13, "#6a4a2a")
    c.rect(2, 3, 16, 2, "#8a643a")
    c.rect(9, 5, 1, 6, "#c8b898")
    c.rect(8, 10, 3, 3, "#7a5430")
    c.outline("#2a221a")
    c.save("well")


def wheat():
    # 麥子：一叢金黃的麥穗（田已經發白，可以收割了）
    c = C(12, 15)
    for i in range(6):
        x = 1 + i * 2 + (h(i, 0, 63) - 0.5)
        top = 2 + int(h(i, 1, 63) * 3)
        for y in range(top + 3, 15):
            c.px(x + (y - 15) * 0.05 * (i - 2.5), y, "#b89040")
        for y in range(top, top + 4):
            c.px(x, y, "#f0cc6a" if y % 2 else "#d8a848")
            c.px(x + 1, y, "#d8a848")
    c.outline("#5a4418")
    c.save("wheat")


def milestone():
    # 羅馬里程碑：一根矮石柱，刻著字
    c = C(10, 18)
    c.rect(2, 3, 6, 14, "#c8c0b0")
    c.rect(2, 3, 2, 14, "#d8d2c4")
    c.rect(1, 15, 8, 3, "#a8a090")
    for y in (6, 8, 10):
        c.rect(3, y, 4, 1, "#7a7468")
    c.outline("#3a362e")
    c.save("milestone")


def dry_bush():
    # 曠野的乾草叢
    c = C(14, 9)
    for i in range(9):
        a = math.pi * (0.1 + 0.8 * i / 8)
        for r in range(7):
            c.px(7 + math.cos(a) * r, 8 - math.sin(a) * r * 1.0, "#a08850" if r < 5 else "#c8b070")
    c.outline("#4a3a20")
    c.save("dry_bush")


def boat():
    # 拉上岸的漁船
    c = C(36, 16)
    for x in range(36):
        d = abs(x - 18) / 18
        top = 6 + int(d * d * 4)
        for y in range(top, 14 - int(d * 3)):
            c.px(x, y, "#8a5a32" if y > top + 1 else "#b07a46")
    c.rect(4, 7, 28, 1, "#5a3a20")
    c.rect(17, 0, 2, 8, "#6a4a2a")
    c.outline("#2a1a10")
    for x in range(3, 33):
        c.px(x, 15, (20, 14, 8, 90))
    c.save("boat")


def nets():
    # 曬漁網：兩根竿子中間掛著網
    c = C(26, 18)
    c.rect(1, 2, 2, 16, "#6a4a2a")
    c.rect(23, 2, 2, 16, "#6a4a2a")
    for x in range(3, 23):
        sag = int(math.sin((x - 3) / 20 * math.pi) * 3)
        for y in range(3 + sag, 14 + sag):
            if (x + y) % 3 == 0 or (x - y) % 3 == 0:
                c.px(x, y, "#c8b890")
    c.outline("#3a2e1e")
    c.save("nets")


def stall():
    # 市集的攤子：條紋布篷、木桌、上面擺著水果和陶罐
    c = C(30, 26)
    for x in range(30):
        for y in range(3, 9):
            c.px(x, y, "#c84a3a" if (x // 3) % 2 else "#f0e0c0")
    for x in range(0, 30, 3):
        c.px(x + 1, 9, "#c84a3a")
    c.rect(2, 9, 2, 16, "#6a4a2a")
    c.rect(26, 9, 2, 16, "#6a4a2a")
    c.rect(3, 17, 24, 3, "#8a643a")
    c.rect(3, 20, 24, 5, "#6a4a2a")
    for i, col in enumerate(["#e8a030", "#c03a2a", "#7aa040", "#e8a030", "#a05a34"]):
        c.oval(7 + i * 4, 15.5, 1.8, 1.6, (col, col, "#fff0c0"), 70 + i)
    c.outline("#2a1a10")
    for x in range(30):
        c.px(x, 25, (20, 14, 8, 90))
    c.save("stall")


def dye():
    # 晾著的紫色布（推雅推喇城賣紫色布的呂底亞）
    c = C(24, 20)
    c.rect(1, 2, 2, 18, "#6a4a2a")
    c.rect(21, 2, 2, 18, "#6a4a2a")
    c.rect(1, 2, 22, 2, "#8a643a")
    for x in range(3, 21):
        L = 10 + int(math.sin(x * 0.7) * 2)
        for y in range(4, 4 + L):
            c.px(x, y, "#8a3a9a" if x % 6 < 3 else "#6a2a7a")
        c.px(x, 4 + L, "#4a1a5a")
    c.outline("#2a1a24")
    c.save("dye")


def stairs():
    # 聖殿外院的臺階（保羅站在臺階上對百姓說話）
    c = C(38, 16)
    for i in range(4):
        j = 3 - i     # 上面最窄，下面最寬
        c.rect(j * 3, 3 + i * 3, 38 - j * 6, 3, "#e8d4a0" if i % 2 else "#dcc690")
        c.rect(j * 3, 3 + i * 3, 38 - j * 6, 1, "#f4e4bc")
    c.outline("#6a5634")
    c.save("stairs")


def scroll_stone():
    # 寫著字的石版（啟 1:11 你所看見的當寫在書上）
    c = C(14, 18)
    c.rect(2, 2, 10, 15, "#8a8478")
    c.rect(3, 3, 8, 13, "#b8b2a4")
    for yy in range(5, 15, 2):
        c.rect(4, yy, 6 if yy % 4 else 4, 1, "#5a564c")
    c.outline("#2a261e")
    c.save("tablet")


def redhouse():
    # 府城的紅磚厝：紅磚牆、紅瓦屋頂、屋脊兩端翹起來的燕尾、木門與窗櫺
    c = C(34, 28)
    for y in range(11, 27):
        for x in range(4, 30):
            brick = (x + (2 if (y // 2) % 2 else 0)) % 4 == 0 or y % 2 == 0
            c.px(x, y, "#8a3a2a" if brick else ("#c0563e" if h(x, y, 80) > 0.3 else "#b04c36"))
    for y in range(5, 11):              # 屋頂（往兩邊斜下來）
        w = (y - 5) * 2
        c.rect(10 - w // 2, y, 14 + w, 1, "#a84030" if y % 2 else "#c45a40")
    c.rect(3, 10, 28, 1, "#7a2e22")
    c.rect(9, 4, 16, 1, "#7a2e22")      # 屋脊
    c.px(8, 3, "#7a2e22")               # 燕尾
    c.px(7, 2, "#7a2e22")
    c.px(25, 3, "#7a2e22")
    c.px(26, 2, "#7a2e22")
    c.rect(14, 18, 6, 9, "#4a2e1a")     # 木門
    c.rect(15, 19, 2, 8, "#6a4426")
    c.rect(17, 19, 2, 8, "#6a4426")
    for x0 in (6, 23):                  # 窗櫺
        c.rect(x0, 14, 5, 4, "#3a2416")
        for k in range(x0 + 1, x0 + 5, 2):
            c.rect(k, 14, 1, 4, "#8a6438")
    c.outline("#3a1a12")
    for x in range(34):
        c.px(x, 27, (20, 14, 8, 90))
    c.save("redhouse")


def banyan():
    # 榕樹：粗樹幹、垂下來的氣根、寬寬的樹冠
    c = C(38, 36)
    for y in range(16, 36):
        c.rect(16 - (1 if y > 31 else 0), y, 6 + (2 if y > 31 else 0), 1, "#6a5040" if y % 4 else "#5a4232")
    for i in range(8):
        c.oval(5 + h(i, 90) * 28, 6 + h(i, 91) * 10, 6 + h(i, 92) * 3, 4.5, ("#2e5a2a", "#3e7a36", "#5e9a4a"), 90 + i, 0.25)
    for k, x in enumerate((7, 11, 26, 30)):
        for y in range(16, 22 + k % 2 * 4):
            c.px(x, y, "#5a4232")
    c.outline("#1a2a14")
    c.save("banyan")


def lantern():
    # 掛在竹竿上的紅燈籠
    c = C(12, 30)
    c.rect(5, 4, 2, 26, "#8a7a3a")
    c.rect(5, 4, 6, 1, "#8a7a3a")
    c.oval(9, 10, 2.6, 3.4, ("#a82018", "#d8382a", "#ff7a5a"), 95)
    c.rect(8, 6, 3, 1, "#2a1a10")
    c.rect(8, 14, 3, 1, "#2a1a10")
    c.px(9, 15, "#ffd75e")
    c.outline("#2a1410")
    c.save("lantern")


def bamboo():
    # 竹叢：一節一節的青竹，頂上幾片葉子
    c = C(20, 34)
    for i, (x, top) in enumerate([(5, 6), (9, 2), (13, 5), (16, 10)]):
        for y in range(top, 34):
            c.px(x, y, "#4a7a2a" if (y - top) % 6 else "#2a4a1a")
            c.px(x + 1, y, "#6a9a3a" if (y - top) % 6 else "#2a4a1a")
        for k in range(3):
            yy = top + 3 + k * 6
            c.px(x + 2, yy, "#5a9a3a")
            c.px(x + 3, yy + 1, "#5a9a3a")
            c.px(x - 1, yy + 2, "#5a9a3a")
            c.px(x - 2, yy + 3, "#5a9a3a")
    c.outline("#1a2a10")
    c.save("bamboo")


def oxcart():
    # 牛車：木板車斗、兩個大木輪
    c = C(26, 16)
    c.rect(2, 4, 20, 5, "#8a643a")
    c.rect(2, 4, 20, 1, "#a8804a")
    for x in range(2, 22, 4):
        c.rect(x, 4, 1, 5, "#6a4a2a")
    c.rect(20, 8, 6, 1, "#6a4a2a")       # 車轅
    for cx in (7, 17):
        c.oval(cx, 11, 4, 4, ("#4a321e", "#5e4028", "#6a4a2a"), 96)
        c.oval(cx, 11, 1.2, 1.2, ("#2a1a10", "#2a1a10", "#2a1a10"), 97)
    c.outline("#2a1a10")
    c.save("oxcart")


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
    for name, fn in [("field", g_field), ("desert", g_desert), ("joppa", g_joppa), ("antioch", g_antioch)]:
        ground(name, fn)
    house()
    stones()
    well()
    wheat()
    milestone()
    dry_bush()
    boat()
    nets()
    stall()
    dye()
    stairs()
    ground("fucheng", g_fucheng)
    redhouse()
    banyan()
    lantern()
    bamboo()
    oxcart()
    print("done")
