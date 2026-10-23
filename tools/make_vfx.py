"""產生技能特效的像素圖（跟人物、地面同一套畫法：實心色塊、深色外框、不用半透明漸層）。

用法：python tools/make_vfx.py
輸出：assets/sprites/fx_<名字>.png。多格動畫是橫向排成一條（每格一樣寬），遊戲裡用 region 一格一格播。
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from make_terrain import h, hx  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
WHITE = "#ffffff"
CREAM = "#fff4c2"
GOLD = "#ffd75e"
FLAME = "#ff8a2a"
RED = "#c8301a"
DARKRED = "#5a1a08"


class Strip:
    def __init__(self, w, hh, n):
        self.w, self.h, self.n = w, hh, n
        self.im = Image.new("RGBA", (w * n, hh), (0, 0, 0, 0))
        self.f = 0

    def px(self, x, y, col):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.im.putpixel((x + self.f * self.w, y), hx(col) if isinstance(col, str) else col)

    def rect(self, x, y, w, hh, col):
        for yy in range(int(y), int(y + hh)):
            for xx in range(int(x), int(x + w)):
                self.px(xx, yy, col)

    def disc(self, cx, cy, r, col, ry=None):
        ry = ry or r
        for y in range(self.h):
            for x in range(self.w):
                if ((x + 0.5 - cx) / r) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.px(x, y, col)

    def ring(self, cx, cy, r, w, col, ry_k=1.0):
        for y in range(self.h):
            for x in range(self.w):
                d = math.sqrt((x + 0.5 - cx) ** 2 + ((y + 0.5 - cy) / ry_k) ** 2)
                if r - w <= d <= r:
                    self.px(x, y, col)

    def save(self, name):
        self.im.save(os.path.join(OUT, "fx_" + name + ".png"))


def spark():
    """打中的火花：十字星，一格比一格小"""
    s = Strip(11, 11, 4)
    for f, (arm, core) in enumerate([(5, 2), (4, 1), (3, 1), (1, 0)]):
        s.f = f
        c = 5
        for k in range(-arm, arm + 1):
            col = WHITE if abs(k) <= core else CREAM
            s.px(c + k, c, col)
            s.px(c, c + k, col)
        if f < 2:
            for k in (-2, 2):
                s.px(c + k, c + k, GOLD)
                s.px(c + k, c - k, GOLD)
        if f == 0:
            s.rect(c - 1, c - 1, 3, 3, WHITE)
    s.save("spark")


def boom():
    """爆開：白色的芯 → 金色的火球 → 一圈碎塊 → 煙"""
    s = Strip(32, 32, 6)
    for f in range(6):
        s.f = f
        c = 15.5
        if f == 0:
            s.disc(c, c, 6, WHITE)
            s.ring(c, c, 8, 2, CREAM)
        elif f == 1:
            s.disc(c, c, 10, GOLD)
            s.disc(c, c, 7, CREAM)
            s.disc(c, c, 4, WHITE)
            s.ring(c, c, 12, 2, FLAME)
        elif f == 2:
            s.disc(c, c, 12, FLAME)
            s.disc(c - 1, c - 1, 9, GOLD)
            s.disc(c - 2, c - 2, 5, CREAM)
            s.ring(c, c, 14, 2, RED)
        elif f == 3:
            for i in range(10):
                a = i * math.tau / 10 + 0.3
                r = 12 + (i % 3)
                s.rect(c + math.cos(a) * r - 1, c + math.sin(a) * r - 1, 3, 3, FLAME if i % 2 else GOLD)
            s.ring(c, c, 11, 3, RED)
            s.disc(c, c, 6, "#8a5a40")
        elif f == 4:
            for i in range(10):
                a = i * math.tau / 10 + 0.5
                s.rect(c + math.cos(a) * 14, c + math.sin(a) * 14, 2, 2, RED)
            s.disc(c, c - 1, 7, "#6a5a58")
            s.disc(c - 2, c - 3, 4, "#8a7a78")
        else:
            s.disc(c + 2, c - 3, 5, "#5a4a4a")
            s.disc(c - 3, c - 1, 3, "#6a5a58")
    s.save("boom")


def fire_col():
    """以利亞的火柱：從天上落下的火（16×60，4 格搖曳）"""
    s = Strip(16, 64, 4)
    for f in range(4):
        s.f = f
        for y in range(64):
            wob = math.sin(y * 0.35 + f * 1.6) * 1.5
            w = 3 + (y / 64) * 4 + (h(y, f, 3) > 0.7)
            c = 8 + wob * (1 - y / 70)
            for x in range(16):
                d = abs(x + 0.5 - c)
                if d <= w + 1:
                    col = DARKRED
                    if d <= w:
                        col = RED
                    if d <= w * 0.7:
                        col = FLAME
                    if d <= w * 0.35:
                        col = GOLD
                    if d <= 0.8 and y > 8:
                        col = CREAM
                    s.px(x, y, col)
        for i in range(5):                       # 往上飛的火星
            yy = (i * 13 + f * 5) % 60
            s.px(8 + math.sin(i + f) * 6, yy, GOLD)
    s.save("firecol")


def glory_col():
    """司提反的光柱：天開了，白金色的光（20×90，4 格閃動）"""
    s = Strip(20, 90, 4)
    for f in range(4):
        s.f = f
        for y in range(90):
            for x in range(20):
                d = abs(x + 0.5 - 10)
                w = 7 + math.sin(y * 0.2 + f * 1.5) * 0.8
                if d <= w:
                    col = GOLD if d > w - 1.2 else CREAM if d > 2.2 else WHITE
                    if d > w - 1.2 and (y + f * 3) % 7 < 2:
                        continue
                    s.px(x, y, col)
        for i in range(6):
            yy = (i * 15 + f * 6) % 88
            s.px(3 + (i * 7) % 14, yy, WHITE)
    s.save("glorycol")


def water_col():
    """約拿的大魚吐出來的水柱"""
    s = Strip(14, 56, 4)
    for f in range(4):
        s.f = f
        for y in range(56):
            w = 3 + y / 56 * 3
            c = 7 + math.sin(y * 0.4 + f * 1.6)
            for x in range(14):
                d = abs(x + 0.5 - c)
                if d <= w + 1:
                    col = "#1a3a6a" if d > w else "#3a7ad0" if d > w * 0.5 else "#8fd0ff"
                    if d <= 0.7:
                        col = WHITE
                    s.px(x, y, col)
    s.save("watercol")


def shield():
    """護盾：主角身邊轉的小盾牌（信德的藤牌）"""
    s = Strip(9, 11, 2)
    for f in range(2):
        s.f = f
        rows = ["..aaaaa..", ".abbbbba.", "abbcccbba", "abcccccba", "abcccccba", "abbcccbba", ".abbcbba.", "..abbba..", "...aba...", "....a...."]
        pal = {"a": "#1a2a4a", "b": "#6ab0f0", "c": "#cfe8ff"}
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch in pal:
                    s.px(x, y + 1, pal[ch])
        s.px(3, 3, WHITE)
        if f == 1:
            s.px(4, 2, WHITE)
            s.px(5, 4, WHITE)
    s.save("shield")


def note():
    """詩歌聲波上的音符"""
    s = Strip(6, 8, 1)
    for y in range(6):
        s.px(4, y, "#2a1a14")
    s.px(5, 1, "#2a1a14")
    s.rect(1, 5, 4, 3, "#2a1a14")
    s.rect(2, 5, 2, 2, CREAM)
    s.px(4, 1, GOLD)
    s.px(4, 2, GOLD)
    s.save("note")


def heal():
    """醫治：往上飄的綠色光點（菱形，3 格）"""
    s = Strip(7, 7, 3)
    for f, r in enumerate([3, 2, 1]):
        s.f = f
        for y in range(7):
            for x in range(7):
                d = abs(x - 3) + abs(y - 3)
                if d <= r:
                    s.px(x, y, "#2a6a3a" if d == r else "#7af0a0" if d > 0 else WHITE)
    s.save("heal")


def net():
    """彼得的網：一張圓網，結點亮一點"""
    s = Strip(41, 33, 1)
    cx, cy = 20, 16
    for y in range(33):
        for x in range(41):
            dx, dy = (x - cx) / 20, (y - cy) / 16
            d = dx * dx + dy * dy
            if d > 1:
                continue
            if d > 0.86:
                s.px(x, y, "#6b4a2a")
            elif (x + y) % 5 == 0 or (x - y) % 5 == 0:
                s.px(x, y, "#e8dcc0" if (x + y) % 5 == 0 and (x - y) % 5 == 0 else "#c8b48a")
    for i in range(10):
        a = i * math.tau / 10
        s.rect(cx + math.cos(a) * 19, cy + math.sin(a) * 15, 2, 2, "#8a8a9a")   # 網上的鉛墜
    s.save("net")


def cloth():
    """呂底亞的紫布：鋪在地上的一大片布，邊上有金色的流蘇"""
    s = Strip(48, 32, 1)
    for y in range(32):
        for x in range(48):
            dx, dy = (x - 23.5) / 23.5, (y - 15.5) / 15.5
            d = dx * dx + dy * dy
            if d > 1:
                continue
            col = "#6e3068" if (y // 3) % 2 else "#8e4488"
            if (x + y) % 9 == 0:
                col = "#b066a8"
            if d > 0.85:
                col = GOLD if (x + y) % 3 else "#c8a040"
            s.px(x, y, col)
    s.save("cloth")


def smoke():
    s = Strip(12, 12, 4)
    for f in range(4):
        s.f = f
        r = 3 + f
        s.disc(6, 6, r, "#8a7a78" if f < 2 else "#6a5a58")
        s.disc(5, 5, max(1, r - 2), "#b0a8a0" if f < 2 else "#8a7a78")
    s.save("smoke")


def splash():
    """水花（打到浸濕、洪水、紅海）"""
    s = Strip(20, 14, 4)
    for f in range(4):
        s.f = f
        for i in range(7):
            a = math.pi + i * math.pi / 6
            r = 3 + f * 2.2
            x, y = 10 + math.cos(a) * r, 11 + math.sin(a) * r * 1.2
            s.rect(x - 1, y - 1, 2 if f > 1 else 3, 2 if f > 1 else 3, "#8fd0ff" if i % 2 else WHITE)
        s.rect(6 - f, 12, 8 + f * 2, 1, "#3a7ad0")
    s.save("splash")


def lightning_end():
    """閃電打中的地方：一團藍白色的電光"""
    s = Strip(13, 13, 3)
    for f in range(3):
        s.f = f
        c = 6
        for i in range(6):
            a = i * math.tau / 6 + f * 0.6
            for k in range(2, 6 - f):
                s.px(c + math.cos(a) * k + (k % 2), c + math.sin(a) * k, "#9fe0ff" if k > 3 else WHITE)
        s.rect(c - 1, c - 1, 3, 3, WHITE)
    s.save("zapend")


def beam_tile():
    """光束的一節（16×9，橫向重複）：深色邊、本色、亮芯、白芯"""
    s = Strip(16, 9, 1)
    for x in range(16):
        for y in range(9):
            d = abs(y - 4)
            col = "#00000000"
            if d == 4:
                col = (40, 40, 40, 255)
            elif d == 3:
                col = (90, 90, 90, 255)
            elif d == 2:
                col = (170, 170, 170, 255)
            elif d == 1:
                col = (225, 225, 225, 255)
            else:
                col = (255, 255, 255, 255)
            if isinstance(col, tuple):
                s.px(x, y, col)
        if x % 8 == 3:
            s.px(x, 1, (255, 255, 255, 255))
    s.save("beam")   # 灰階：遊戲裡用 modulate 上色，所以同一張圖給每位同伴自己的顏色


if __name__ == "__main__":
    spark()
    boom()
    fire_col()
    glory_col()
    water_col()
    shield()
    note()
    heal()
    net()
    cloth()
    smoke()
    splash()
    lightning_end()
    beam_tile()
    print("ok")
