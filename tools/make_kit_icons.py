"""產生職業技能的小圖示（12×12，技能列、升級卡用）。

用法：python3 tools/make_kit_icons.py
輸出：assets/sprites/icon_<技能 id>.png、icon_main_<主角>.png。
保羅的圖示是 make_vfx.py 裡手畫的；其他主角的用這裡的「圖形＋顏色」組出來：
先畫實心的形狀（主色＋亮色），最後自動描一圈深色外框，跟人物同一套畫法。
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
INK = (42, 26, 20, 255)


def hx(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


class G:
    """12×12 的小畫布：px 存每一格的顏色（0 主色、1 亮色、2 暗色）。"""

    def __init__(self):
        self.p = {}

    def dot(self, x, y, k=0):
        x, y = int(round(x)), int(round(y))
        if 1 <= x <= 10 and 1 <= y <= 10:
            self.p[(x, y)] = k

    def rect(self, x, y, w, h, k=0):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.dot(xx, yy, k)

    def disc(self, cx, cy, r, k=0, ry=None):
        ry = ry or r
        for y in range(12):
            for x in range(12):
                if ((x + 0.5 - cx) / r) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.dot(x, y, k)

    def ring(self, cx, cy, r, k=0, w=1.0):
        for y in range(12):
            for x in range(12):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if r - w <= d <= r:
                    self.dot(x, y, k)

    def line(self, x0, y0, x1, y1, k=0):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            self.dot(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, k)


def g_net(g):
    for i in range(0, 12, 3):
        g.line(1 + i, 1, 1, 1 + i)
        g.line(10 - i, 10, 10, 10 - i)
        g.line(1 + i, 10, 1, 10 - i, 1)
        g.line(10 - i, 1, 10, 1 + i, 1)


def g_wave(g):
    for row, k in ((3, 1), (6, 0), (9, 0)):
        for x in range(1, 11):
            g.dot(x, row + (1 if (x // 2) % 2 else 0), k)


def g_drop(g):
    g.disc(6, 7.5, 3.2)
    g.line(6, 2, 4, 6)
    g.line(6, 2, 8, 6)
    g.rect(5, 3, 2, 3)
    g.dot(5, 7, 1)
    g.dot(5, 8, 1)


def g_shield(g):
    g.rect(2, 2, 8, 5)
    for y in range(7, 11):
        g.rect(2 + (y - 6), y, 8 - 2 * (y - 6), 1)
    g.rect(4, 3, 4, 2, 1)


def g_heart(g):
    g.disc(4.2, 4.5, 2.2)
    g.disc(7.8, 4.5, 2.2)
    for y in range(5, 11):
        g.rect(2 + (y - 5), y, 8 - 2 * (y - 5), 1)
    g.dot(3, 4, 1)


def g_fish(g):
    g.disc(5, 6, 3.5, 0, 2.2)
    g.line(8, 6, 10, 3)
    g.line(8, 6, 10, 9)
    g.dot(3, 5, 2)
    g.line(3, 7, 6, 7, 1)


def g_rock(g):
    g.rect(2, 4, 8, 6)
    g.rect(3, 3, 6, 1)
    g.rect(3, 4, 3, 2, 1)
    g.line(6, 6, 8, 9, 2)


def g_bolt(g):
    g.line(7, 1, 4, 6)
    g.line(4, 6, 8, 6)
    g.line(8, 6, 5, 10)
    g.line(7, 2, 5, 6, 1)


def g_sun(g):
    g.disc(6, 6, 2.7)
    g.dot(5, 5, 1)
    for i in range(8):
        a = i * math.pi / 4 + math.pi / 8
        g.dot(6 + math.cos(a) * 4.6, 6 + math.sin(a) * 4.6, 1)


def g_pillar(g):
    g.rect(5, 1, 3, 8, 1)
    g.rect(4, 2, 1, 6)
    g.rect(8, 2, 1, 6)
    g.disc(6.5, 9.5, 4, 0, 1.2)


def g_halo(g):
    g.ring(6, 3, 2.6, 1)
    g.disc(6, 7.5, 2.6)
    g.dot(5, 7, 2)
    g.dot(7, 7, 2)


def g_bread(g):
    g.disc(6, 7, 4.5, 0, 2.8)
    g.line(4, 5, 5, 7, 1)
    g.line(7, 5, 8, 7, 1)


def g_lamp(g):
    g.disc(6, 8, 4, 0, 1.8)
    g.rect(9, 7, 2, 1)
    g.rect(5, 3, 2, 3, 1)
    g.dot(6, 2, 1)


def g_flame(g):
    g.disc(6, 7.5, 3)
    g.line(6, 1, 4, 6)
    g.line(6, 1, 8, 5)
    g.disc(6, 8, 1.5, 1)


def g_arrows(g):
    for dx in (-3, 0, 3):
        g.line(2, 8 + dx * 0.3 - 2, 9, 3 + dx, 0)
        g.dot(9, 3 + dx, 1)


def g_target(g):
    g.ring(6, 6, 5, 0)
    g.ring(6, 6, 3, 1)
    g.dot(6, 6, 0)
    g.dot(5, 6, 0)


def g_rays(g):
    for i in range(8):
        a = i * math.pi / 4 + math.pi / 8
        g.line(6 + math.cos(a) * 1.5, 6 + math.sin(a) * 1.5, 6 + math.cos(a) * 4.8, 6 + math.sin(a) * 4.8, i % 2)


def g_leaf(g):
    for i in range(8):
        w = math.sin(i / 7 * math.pi) * 2.5
        g.line(2 + i - w * 0.7, 9 - i - w * 0.7, 2 + i + w * 0.7, 9 - i + w * 0.7)
    g.line(2, 10, 9, 2, 2)


def g_house(g):
    for y in range(2, 6):
        g.rect(6 - (y - 1), y, 2 * (y - 1) + 1, 1, 1)
    g.rect(3, 6, 7, 4)
    g.rect(5, 7, 2, 3, 2)


def g_cloth(g):
    g.rect(2, 3, 8, 6)
    for x in range(2, 10, 2):
        g.dot(x, 9, 1)
        g.dot(x + 1, 10, 1)
    g.line(3, 4, 8, 4, 1)


def g_horn(g):
    g.line(2, 8, 7, 4)
    g.line(2, 9, 7, 5)
    g.disc(8.5, 4, 2.2)
    g.dot(2, 9, 1)
    g.dot(8, 4, 2)


def g_wind(g):
    for row, ln in ((3, 7), (6, 9), (9, 6)):
        g.line(1, row, ln, row, 0 if row != 6 else 1)
        g.dot(ln + 1, row - 1)
    g.dot(9, 4)


def g_grapes(g):
    for (x, y) in ((4, 5), (7, 5), (5.5, 7.5), (3, 7.5), (8, 7.5), (5.5, 10)):
        g.disc(x, y, 1.4)
    g.dot(4, 4, 1)
    g.line(6, 1, 6, 4, 2)
    g.rect(7, 2, 3, 1, 1)


def g_feet(g):
    g.disc(4, 4, 1.7, 0, 2.3)
    g.disc(8, 8, 1.7, 0, 2.3)
    g.rect(3, 7, 2, 1)
    g.rect(7, 1, 2, 1)
    g.dot(4, 3, 1)
    g.dot(8, 7, 1)


def g_wheel(g):
    g.ring(6, 6, 5, 0, 1.2)
    for i in range(6):
        a = i * math.pi / 3
        g.line(6, 6, 6 + math.cos(a) * 4, 6 + math.sin(a) * 4, 1)


def g_people(g):
    for x, k in ((3, 0), (6, 1), (9, 0)):
        g.disc(x, 4, 1.3, k)
        g.rect(x - 1, 6, 3, 4, k)


def g_loop(g):
    g.ring(6, 6, 4.5, 0, 1.4)
    g.rect(8, 1, 3, 2, 1)
    g.dot(9, 3, 1)


def g_boom(g):
    g.ring(6, 6, 5.2, 1, 1)
    g.ring(6, 6, 3, 0, 1)
    g.dot(6, 6, 1)


def g_potion(g):
    g.disc(6, 7.5, 3.3)
    g.rect(5, 2, 2, 3, 2)
    g.rect(4, 1, 4, 1, 2)
    g.rect(4, 7, 4, 2, 1)


def g_cymbal(g):
    g.disc(4, 5, 3, 0, 1.6)
    g.disc(8, 8, 3, 0, 1.6)
    g.dot(4, 5, 1)
    g.dot(8, 8, 1)


def g_dash(g):
    g.line(1, 9, 9, 3)
    g.line(1, 7, 6, 3, 1)
    g.line(4, 10, 10, 5, 1)


def g_seven(g):
    for i in range(7):
        a = i * 2 * math.pi / 7 - math.pi / 2
        g.disc(6 + math.cos(a) * 3.8, 6 + math.sin(a) * 3.8, 1.0, i % 2)


def g_eye(g):
    g.disc(6, 6, 5, 0, 2.5)
    g.disc(6, 6, 1.8, 2)
    g.dot(5, 5, 1)


GLYPH = {k[2:]: v for k, v in globals().items() if k.startswith("g_")}

# 技能 → (圖形, 主色, 亮色)
COL = {"heal": ("#4ac87a", "#b8f5c8"), "gold": ("#e0a020", "#fff4c2"), "blue": ("#3a7ad0", "#9fd8ff"), "red": ("#c0392b", "#ff8a6a"),
       "fire": ("#e0601a", "#ffd75e"), "purple": ("#7a3a8a", "#d8a0e0"), "stone": ("#8a8070", "#d8d0c0"), "teal": ("#2a9a8a", "#9fefe0"),
       "net": ("#c8a46b", "#f4ead2"), "green": ("#3a8a2a", "#9fe070"), "pale": ("#9fb8ff", "#ffffff")}
ICONS = {
    # 主角本來的招式
    "main_peter": ("net", "net"), "main_stephen": ("pillar", "gold"), "main_john": ("bolt", "blue"), "main_tim": ("arrows", "gold"),
    "main_philip": ("dash", "teal"), "main_lydia": ("cloth", "purple"), "main_maxwell": ("potion", "teal"), "main_asaph": ("cymbal", "gold"),
    # 彼得
    "haul": ("net", "net"), "leap": ("wave", "blue"), "fisher": ("fish", "blue"), "rock": ("rock", "stone"), "shadow": ("heart", "heal"),
    "bold": ("boom", "gold"), "walk": ("feet", "heal"),
    # 司提反
    "wisdom": ("eye", "blue"), "pillars": ("pillar", "gold"), "face": ("halo", "gold"), "serve": ("bread", "net"), "forgive": ("heart", "gold"),
    "word": ("rays", "fire"), "temple": ("pillar", "pale"),
    # 約翰
    "thunder": ("bolt", "blue"), "love": ("heart", "red"), "lamps": ("seven", "gold"), "voice": ("wave", "blue"), "abide": ("shield", "blue"),
    "light": ("rays", "gold"), "mother": ("halo", "heal"),
    # 提摩太
    "flee": ("feet", "teal"), "workman": ("arrows", "gold"), "divide": ("target", "red"), "fan": ("flame", "fire"), "soldier": ("shield", "red"),
    "lois": ("heart", "heal"), "deposit": ("shield", "gold"),
    # 腓利
    "caught": ("wind", "pale"), "chariot": ("wheel", "net"), "unclean": ("boom", "purple"), "joy": ("sun", "gold"), "daughters": ("people", "teal"),
    "water": ("drop", "blue"), "run": ("dash", "teal"),
    # 呂底亞
    "household": ("house", "purple"), "purple": ("cloth", "purple"), "heart": ("heart", "purple"), "river": ("wave", "blue"),
    "baptize": ("drop", "pale"), "comfort": ("heart", "heal"), "dye": ("drop", "purple"),
    # 馬雅各
    "clinic": ("house", "heal"), "balm": ("potion", "heal"), "bind": ("cloth", "net"), "pool": ("wave", "teal"), "leaves": ("leaf", "green"),
    "fever": ("drop", "heal"), "sun": ("sun", "gold"),
    # 亞薩
    "sanctuary": ("shield", "pale"), "remember": ("loop", "gold"), "shepherd": ("heart", "heal"), "trumpet": ("horn", "gold"),
    "judge": ("pillar", "red"), "tempest": ("wind", "stone"), "vine": ("grapes", "purple"),
}


def make(name, glyph, col):
    g = G()
    GLYPH[glyph](g)
    main, light = COL[col]
    dark = tuple(int(c * 0.55) for c in hx(main)[:3]) + (255,)
    pal = {0: hx(main), 1: hx(light), 2: dark}
    im = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    for (x, y), k in g.p.items():
        im.putpixel((x, y), pal[k])
    # 外框：空的格子旁邊有東西，就描深色
    for y in range(12):
        for x in range(12):
            if (x, y) in g.p:
                continue
            if any((x + dx, y + dy) in g.p for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                im.putpixel((x, y), INK)
    im.save(os.path.join(OUT, "icon_%s.png" % name))


if __name__ == "__main__":
    for name, (glyph, col) in ICONS.items():
        make(name, glyph, col)
    print(len(ICONS), "icons")
