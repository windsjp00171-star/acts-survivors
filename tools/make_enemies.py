"""產生敵人與 Boss 的像素圖（程式畫的，不用外部素材）。

用法：python tools/make_enemies.py
輸出：assets/sprites/<名字>_0.png、_1.png（兩格動畫）；Boss 是 boss_<城市>.png

敵人 21×21，腳底大約在第 13 列（遊戲裡 offset 是 (-10, -13)）。
Boss 40×40。想改造型就改下面對應的函式。
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")


def hx(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def h(x, y, s=0):
    """固定的雜訊（同一個座標永遠一樣）"""
    v = (x * 374761393 + y * 668265263 + s * 2246822519) & 0xFFFFFFFF
    v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
    return (v ^ (v >> 16)) / 4294967296


class Canvas:
    def __init__(self, w, h_):
        self.im = Image.new("RGBA", (w, h_), (0, 0, 0, 0))
        self.w, self.h = w, h_

    def px(self, x, y, col):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.im.putpixel((x, y), hx(col) if isinstance(col, str) else col)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.im.getpixel((x, y))[3] > 0
        return False

    def blob(self, cx, cy, rx, ry, cols, rough=0.0, seed=0):
        """橢圓：cols = (暗, 中, 亮)，左上亮、右下暗"""
        for y in range(self.h):
            for x in range(self.w):
                dx, dy = (x - cx) / rx, (y - cy) / ry
                v = dx * dx + dy * dy
                if v > 1 or (v > 0.72 and h(x, y, seed) < rough):
                    continue
                l = -dx * 0.4 - dy * 0.6 + (h(x, y, seed + 9) - 0.5) * 0.3
                self.px(x, y, cols[2] if l > 0.45 else cols[1] if l > -0.25 else cols[0])

    def outline(self, col="#140c14"):
        """外框：所有不透明像素旁邊的透明格塗上深色"""
        pts = []
        for y in range(self.h):
            for x in range(self.w):
                if not self.get(x, y) and any(self.get(x + a, y + b) for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    pts.append((x, y))
        for x, y in pts:
            self.px(x, y, col)

    def save(self, name):
        self.im.save(os.path.join(OUT, name + ".png"))


def frames(name, fn, size=21):
    for f in (0, 1):
        c = Canvas(size, size)
        fn(c, f)
        c.save("%s_%d" % (name, f))


# ---------- 一般敵人的第二種造型 ----------
def fear_b(c, f):
    # 懼怕・幽影：拖著長尾巴的鬼影，大眼睛
    for y in range(4, 19):
        k = (y - 4) / 14
        w = 6.5 * math.sin(min(1, k * 1.6) * math.pi / 2) * (1 - max(0, k - 0.6) * 1.8)
        sway = math.sin(y * 0.6 + f * 2.2) * k * 2.2
        for x in range(21):
            d = abs(x - 10 - sway)
            if d < w:
                self_col = "#1a0f24" if d < w * 0.45 else "#3b1e52" if d < w * 0.8 else "#6b3a8c"
                c.px(x, y, self_col)
    for x in (7, 8, 12, 13):
        for y in (8, 9, 10):
            c.px(x, y, "#e9d6ff")
    c.px(8 - f, 9, "#1a0f24")
    c.px(13 - f, 9, "#1a0f24")
    c.px(10, 13, "#b07ad0")
    c.outline()


def strife_b(c, f):
    # 紛爭・對撞：兩顆長角的頭互相頂著
    off = 1 if f else 0
    for side in (-1, 1):
        cx = 10 + side * (4 - off)
        c.blob(cx, 11, 4.2, 4, ("#2a0f1e", "#4a1838", "#a0406a"), 0.2, side + 3)
        for i in range(4):
            c.px(cx + side * (2 + i), 7 - i // 2, "#e0c8b0" if i < 3 else "#a08870")
        c.px(cx - side, 10, "#ff7aa8")
    c.px(10, 6 - f, "#ffd75e")
    c.px(10, 5 - f, "#ff8a2a")
    c.outline()


def lies_b(c, f):
    # 謊言・蛇：盤起來的蛇，分岔的舌頭
    for i in range(60):
        a = i * 0.21 + f * 0.3
        r = 2.5 + i * 0.1
        x, y = 10 + math.cos(a) * r, 13 + math.sin(a) * r * 0.55
        c.px(x, y, "#c8e070" if i % 9 == 0 else "#6e8a48")
        c.px(x, y + 1, "#3a5028")
    c.blob(10, 7, 3, 2.5, ("#3a5028", "#6e8a48", "#9ab868"), 0, 5)
    c.px(9, 6, "#ffe14d")
    c.px(11, 6, "#ffe14d")
    t = 9 + f
    c.px(10, t, "#e8481c")
    c.px(9, t + 1, "#e8481c")
    c.px(11, t + 1, "#e8481c")
    c.outline()


def sleep_b(c, f):
    # 沉睡・飛蛾：垂著翅膀、半睜的眼睛
    flap = 1 if f else 0
    for side in (-1, 1):
        for y in range(6, 16):
            for x in range(21):
                dx = (x - 10) * side
                if 1 <= dx <= 8 - abs(y - 10 - flap) * 0.7 and h(x, y, 4) > 0.08:
                    c.px(x, y, "#34466e" if dx < 5 else "#4f6494")
    c.blob(10, 11, 2, 5, ("#1e2a4a", "#34466e", "#9fb4e0"), 0, 2)
    c.px(9, 8, "#9fb4e0")
    c.px(11, 8, "#9fb4e0")
    for i, (x, y) in enumerate([(15, 3), (17, 2), (16, 4)]):
        c.px(x, y - flap, "#9fb4e0")
    c.outline()


# ---------- 各城市的敵人 ----------
def riot(c, f):
    # 暴動：三個戴頭巾的人擠在一起，舉著火把
    for i, (x, y) in enumerate([(6, 12), (14, 12), (10, 10)]):
        c.blob(x, y + 2, 3.2, 4, ("#5a2018", "#8a3a2a", "#c06040"), 0.1, i)
        c.blob(x, y - 2, 2.2, 2.2, ("#3a1a12", "#6a3020", "#9a5030"), 0, i + 7)
        c.px(x - 1, y - 2, "#ffb08a")
        c.px(x + 1, y - 2, "#ffb08a")
    # 火把
    for y in range(3, 9):
        c.px(16, y, "#6b4a2a")
    flame = [(16, 2), (15, 1 + f), (17, 1 + (1 - f)), (16, 0)]
    for x, y in flame:
        c.px(x, y, "#ff8a2a")
    c.px(16, 1, "#ffd75e")
    # 舉起的拳頭
    c.px(4, 5 + f, "#c06040")
    c.px(4, 6 + f, "#8a3a2a")
    c.outline()


def pride(c, f):
    # 自高：鼓起來的身體，頭抬得很高，戴著小王冠
    puff = 0.4 * f
    c.blob(10, 12, 6.5 + puff, 6 + puff, ("#8a6018", "#c8902a", "#ffd75e"), 0.05, 3)
    for x, y in [(7, 4), (8, 5), (10, 3), (12, 5), (13, 4), (9, 5), (11, 5), (10, 4)]:
        c.px(x, y + 1 - f, "#ffd75e")
    c.px(10, 3 - f, "#e8481c")
    # 往上翹的眼睛和鼻子
    c.px(8, 9, "#2a1a08")
    c.px(12, 9, "#2a1a08")
    c.px(8, 8, "#fff4c2")
    c.px(12, 8, "#fff4c2")
    c.px(10, 10, "#8a6018")
    c.px(10, 9, "#8a6018")
    c.outline()


def sorcery(c, f):
    # 邪術：連帽的長袍，只露一隻發光的眼，旁邊繞著符文
    for y in range(4, 18):
        w = 1 + (y - 4) * 0.45
        for x in range(21):
            d = abs(x - 10)
            if d < w:
                c.px(x, y, "#2a1440" if d < w - 1.5 else "#4a2470" if d < w - 0.6 else "#7a4aa8")
    c.blob(10, 8, 2.4, 2, ("#0a0410", "#0a0410", "#1a0c24"), 0, 1)
    c.px(10, 8, "#7affd8")
    c.px(9, 8, "#2ad8a8")
    c.px(11, 8, "#2ad8a8")
    for i in range(4):
        a = i * math.pi / 2 + f * math.pi / 4
        x, y = 10 + math.cos(a) * 8, 11 + math.sin(a) * 5
        c.px(x, y, "#c8a0ff")
        c.px(x + 1, y, "#7a4aa8")
    c.outline("#0a0410")


def terror(c, f):
    # 恐嚇（菁英）：長角的巨大黑影，張大的嘴，紅眼睛
    c.blob(10, 12, 7.5, 7, ("#140a1c", "#2a1440", "#4a2470"), 0.25, 8 + f)
    for side in (-1, 1):
        for i in range(6):
            c.px(10 + side * (4 + i * 0.6), 6 - i * 0.8, "#c8b8a8" if i < 4 else "#8a7a6a")
    c.px(7, 10, "#ff3a2a")
    c.px(8, 10, "#ff3a2a")
    c.px(12, 10, "#ff3a2a")
    c.px(13, 10, "#ff3a2a")
    mouth = 2 + f
    for x in range(7, 14):
        for y in range(13, 13 + mouth):
            c.px(x, y, "#0a0004")
        if x % 2:
            c.px(x, 13, "#e8e0d0")
    c.outline("#05020a")


def apathy(c, f):
    # 冷漠（考驗）：不冷不熱、癱成一灘的灰色團塊，眼皮半垂
    c.blob(10, 13, 7.5, 4.5 - 0.3 * f, ("#5a5a60", "#7a7a80", "#a8a8b0"), 0.1, 6)
    for x in (6, 7, 8, 12, 13, 14):
        c.px(x, 11, "#d8d8e0")
    for x in (7, 8, 12, 13):
        c.px(x, 12, "#1a1a20")
    for x in range(8, 13):
        c.px(x, 15, "#2a2a30")
    c.px(4, 16 + f, "#a8a8b0")
    c.px(16, 17 - f, "#a8a8b0")
    c.outline()


# ---------- Boss（40×40，各城市一隻） ----------
def boss_thessalonica():
    # 騷亂：一大團擠在一起的人群，很多眼睛和火把
    c = Canvas(40, 40)
    c.blob(20, 24, 17, 13, ("#3a1410", "#6a2818", "#a04a30"), 0.2, 11)
    for i in range(9):
        x, y = 8 + (i * 7) % 26, 16 + (i * 5) % 14
        c.blob(x, y, 2.5, 2.5, ("#2a0c08", "#4a1a10", "#7a3020"), 0, i)
        c.px(x - 1, y, "#ff7a4a")
        c.px(x + 1, y, "#ff7a4a")
    for x in (6, 20, 33):
        for y in range(4, 12):
            c.px(x, y, "#6b4a2a")
        for dx, dy in ((0, 3), (-1, 2), (1, 2), (0, 1)):
            c.px(x + dx, dy, "#ff8a2a")
        c.px(x, 2, "#ffd75e")
    c.outline()
    c.save("boss_thessalonica")


def boss_corinth():
    # 分門結黨：一個身體被扯成兩半，各戴一頂王冠，互相瞪著
    c = Canvas(40, 40)
    for side in (-1, 1):
        cx = 20 + side * 8
        c.blob(cx, 24, 9, 12, ("#5a3a10", "#a07020", "#e0b040"), 0.15, side + 20)
        for x in range(-4, 5):
            c.px(cx + x, 10 - (2 if x % 2 == 0 else 0), "#ffd75e")
            c.px(cx + x, 11, "#ffd75e")
        c.px(cx, 7, "#e8481c")
        c.px(cx + side * -3, 20, "#ff3a2a")
        c.px(cx + side * -2, 20, "#ff3a2a")
    c.outline()
    # 中間裂開（外框之後才挖，才看得出是一道縫）
    for y in range(12, 38):
        for dx in (-1, 0, 1):
            c.px(20 + dx + (1 if y % 4 < 2 else 0), y, (0, 0, 0, 0))
    c.save("boss_corinth")


def boss_ephesus():
    # 銀匠的騷動：銀色的神龕，柱子中間有一隻眼睛，周圍繞著銀幣
    c = Canvas(40, 40)
    for x in range(8, 32):
        for y in range(30, 34):
            c.px(x, y, "#9a9aa8" if y > 31 else "#c8c8d4")
    for px_ in (10, 15, 24, 29):
        for y in range(14, 30):
            c.px(px_, y, "#e0e0ea")
            c.px(px_ + 1, y, "#9a9aa8")
    for y in range(7, 14):
        w = (y - 6) * 2.4
        for x in range(40):
            if abs(x - 20) < w:
                c.px(x, y, "#c8c8d4" if y < 12 else "#9a9aa8")
    c.blob(20, 22, 4.5, 4, ("#1a0c16", "#3a2430", "#5a3a48"), 0, 3)
    c.px(20, 22, "#ff5a3a")
    c.px(19, 22, "#ff5a3a")
    for i in range(8):
        a = i * math.pi / 4
        x, y = 20 + math.cos(a) * 18, 22 + math.sin(a) * 15
        c.px(x, y, "#e8e8f0")
        c.px(x + 1, y, "#9a9aa8")
        c.px(x, y + 1, "#9a9aa8")
    c.outline()
    c.save("boss_ephesus")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("fear_b", fear_b), ("strife_b", strife_b), ("lies_b", lies_b), ("sleep_b", sleep_b),
                     ("riot", riot), ("pride", pride), ("sorcery", sorcery), ("terror", terror), ("apathy", apathy)]:
        frames(name, fn)
    boss_thessalonica()
    boss_corinth()
    boss_ephesus()
    print("done")
