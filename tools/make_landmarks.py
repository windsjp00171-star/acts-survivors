"""產生每座城市的地標（比一般物件大、擋路，地圖上偶爾遇到一座）。

用法：python tools/make_landmarks.py
輸出：assets/sprites/lm_<名字>.png。各城市用哪一座寫在 data/stages.json 的 landmarks。
光從左上來：左上亮、右下暗，外框深褐色。都是使徒行傳裡真的出現過、或當時真的有的東西。
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from make_terrain import C, h  # noqa: E402

INK = "#2a1e16"
WOOD = ["#4a3020", "#6b4a2a", "#8a6438", "#a87c4a"]
LIME = ["#a0804a", "#c8a464", "#e0c080", "#f0d8a0"]       # 耶路撒冷的金色石灰岩
MARBLE = ["#9a968c", "#c8c4b8", "#e6e2d6", "#f8f4ea"]
STONE = ["#5e5850", "#7a746a", "#9a948a", "#bab4a8"]
DARK = ["#2e2a30", "#3e3a44", "#56525c", "#6e6a74"]
CLAY = ["#8a6a48", "#a8845c", "#c4a074", "#dcbc90"]
BRICK = ["#7a2e22", "#a84030", "#c0563e", "#d87a5a"]
LINEN = ["#9a8460", "#bca47a", "#d8c49a", "#efe2c0"]
PURPLE = ["#4a2048", "#6e3068", "#8e4488", "#b066a8"]
GREEN = ["#3e5a2a", "#55743a", "#6e8e48", "#8aaa5a"]
WATER = ["#2e4a6a", "#3e6a8a", "#5a8aaa", "#9ac4d8"]


def save(c, name):
    c.save("lm_" + name)


def shadow(c, cx, cy, rx, ry=3):
    for y in range(c.h):
        for x in range(c.w):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1 and c.im.getpixel((x, y))[3] == 0:
                c.px(x, y, (20, 14, 8, 80))


def blocks(c, x0, y0, w, hgt, pal, bw=6, bh=4, seed=0):
    """砌石牆：錯縫的方石，石縫深、上緣亮"""
    for y in range(y0, y0 + hgt):
        row = (y - y0) // bh
        off = (bw // 2) if row % 2 else 0
        for x in range(x0, x0 + w):
            bx = (x - x0 + off) % bw
            by = (y - y0) % bh
            if bx == 0 or by == bh - 1:
                col = pal[0]
            elif by == 0:
                col = pal[3]
            else:
                t = h((x - x0 + off) // bw, row, seed)
                col = pal[2] if t > 0.35 else pal[1]
            c.px(x, y, col)


def side_shade(c, x0, y0, w, hgt, frac=0.25):
    """右邊一條陰影（立體感）"""
    for y in range(y0, y0 + hgt):
        for x in range(x0 + int(w * (1 - frac)), x0 + w):
            r, g, b, a = c.im.getpixel((x, y))
            if a:
                c.px(x, y, (int(r * 0.78), int(g * 0.78), int(b * 0.8), a))


def column(c, x, top, bottom, pal, w=5):
    c.rect(x - 1, top, w + 2, 2, pal[3])
    c.rect(x - 1, top + 1, w + 2, 1, pal[1])
    for y in range(top + 2, bottom - 2):
        for k in range(w):
            c.px(x + k, y, pal[3] if k == 1 else pal[1] if k == w - 1 else pal[2] if k % 2 == 0 else pal[2])
            if k == 3:
                c.px(x + k, y, pal[1])
    c.rect(x - 1, bottom - 2, w + 2, 2, pal[2])
    c.rect(x - 1, bottom - 1, w + 2, 1, pal[0])


def roof_tri(c, cx, y_top, half, y_base, pal):
    for y in range(y_top, y_base + 1):
        k = (y - y_top) * half / max(1, (y_base - y_top))
        for x in range(int(cx - k), int(cx + k) + 1):
            c.px(x, y, pal[3] if y == y_base else pal[2] if x < cx else pal[1])


def door(c, x, y, w, hgt, arch=True, col="#2a1a12"):
    c.rect(x, y, w, hgt, col)
    if arch:
        c.rect(x + 1, y - 1, w - 2, 1, col)


# ---------- 耶路撒冷：馬可樓房（五旬節，徒 1:13；2:1）----------
def upperroom():
    c = C(56, 52)
    shadow(c, 28, 49, 26)
    blocks(c, 6, 22, 44, 27, LIME, 8, 5, 1)          # 一樓
    blocks(c, 14, 8, 34, 15, LIME, 8, 5, 2)          # 樓上的房間
    side_shade(c, 6, 22, 44, 27, 0.22)
    side_shade(c, 14, 8, 34, 15, 0.22)
    c.rect(4, 21, 48, 2, WOOD[2])                    # 樓板的木樑
    c.rect(4, 21, 48, 1, WOOD[3])
    c.rect(12, 6, 38, 2, WOOD[1])                    # 平屋頂
    c.rect(12, 6, 38, 1, LIME[3])
    for i in range(12):                              # 外牆的石階（上樓房）
        c.rect(2 + i, 47 - i * 2, 5, 2, LIME[3])
        c.rect(2 + i, 48 - i * 2, 5, 1, LIME[0])
    door(c, 30, 36, 7, 13)                           # 門
    c.rect(22, 12, 6, 6, "#2a1a12")                  # 樓上的窗，裡面有光
    c.rect(23, 13, 4, 4, "#ffd75e")
    c.rect(36, 12, 6, 6, "#2a1a12")
    c.rect(37, 13, 4, 4, "#ffb040")
    c.rect(40, 28, 5, 5, "#2a1a12")
    for x in (24, 38):                               # 窗上的火焰舌頭（2:3）
        c.px(x + 1, 9, "#ff8a2a")
        c.px(x + 1, 10, "#ffd75e")
    c.outline(INK)
    save(c, "upperroom")


# ---------- 耶路撒冷：城門（司提反被推到城外，徒 7:58）----------
def citygate(name, pal, seed, banner=None):
    c = C(64, 50)
    shadow(c, 32, 47, 30)
    blocks(c, 2, 8, 18, 39, pal, 6, 4, seed)         # 兩座塔樓
    blocks(c, 44, 8, 18, 39, pal, 6, 4, seed + 1)
    blocks(c, 18, 16, 28, 31, pal, 6, 4, seed + 2)   # 門樓
    side_shade(c, 44, 8, 18, 39, 0.35)
    for x0 in (2, 44):                               # 城垛
        for k in range(0, 18, 4):
            c.rect(x0 + k, 4, 3, 4, pal[2])
            c.px(x0 + k, 4, pal[3])
    for k in range(18, 46, 4):
        c.rect(k, 12, 3, 4, pal[2])
    for y in range(26, 47):                          # 拱門
        half = 7 if y > 30 else int(math.sqrt(max(0, 49 - (30 - y) ** 2 * 1.9)))
        c.rect(32 - half, y, half * 2, 1, "#1e140e")
    for y in range(30, 47, 3):                       # 敞開的木門
        c.rect(25, y, 2, 2, WOOD[1])
        c.rect(37, y, 2, 2, WOOD[1])
    c.rect(9, 20, 3, 6, "#1e140e")                   # 箭孔
    c.rect(52, 20, 3, 6, "#1e140e")
    if banner:
        for y in range(20, 30):
            c.rect(10, y, 3, 1, banner)
            c.rect(51, y, 3, 1, banner)
    c.outline(INK)
    save(c, name)


# ---------- 撒馬利亞：打穀場 ----------
def threshing():
    c = C(60, 32)
    for y in range(c.h):
        for x in range(c.w):
            d = ((x - 30) / 28) ** 2 + ((y - 17) / 13) ** 2
            if d <= 1:
                col = STONE[2] if d > 0.82 else CLAY[2] if h(x, y, 30) > 0.3 else CLAY[1]
                if d > 0.82 and (x + y) % 5 == 0:
                    col = STONE[0]
                if d <= 0.82 and h(x, y, 31) > 0.86:
                    col = "#e0b85a"
                c.px(x, y, col)
    for cx, cy in ((20, 12), (38, 16)):              # 兩堆麥子
        for y in range(cy - 7, cy + 2):
            w = int((y - cy + 8) * 1.2)
            for x in range(cx - w, cx + w + 1):
                c.px(x, y, "#e0b85a" if x < cx else "#c89a40")
                if (x + y) % 4 == 0:
                    c.px(x, y, "#f0d070")
    c.rect(44, 22, 12, 3, WOOD[2])                   # 打穀板
    c.rect(44, 22, 12, 1, WOOD[3])
    c.rect(54, 18, 1, 5, WOOD[1])                    # 木叉
    c.px(53, 17, WOOD[1])
    c.px(55, 17, WOOD[1])
    c.outline(INK)
    save(c, "threshing")


# ---------- 約帕：硝皮匠西門的房子，彼得在屋頂上禱告（徒 10:9）----------
def rooftop():
    c = C(54, 46)
    shadow(c, 27, 43, 25)
    for y in range(14, 43):
        for x in range(4, 50):
            col = MARBLE[2] if x < 40 else MARBLE[1]
            if h(x, y, 40) > 0.94:
                col = MARBLE[1]
            if x == 4:
                col = MARBLE[3]
            c.px(x, y, col)
    c.rect(2, 11, 50, 4, MARBLE[3])                  # 平屋頂的矮牆
    c.rect(2, 14, 50, 1, MARBLE[0])
    c.rect(4, 9, 4, 3, WOOD[2])                      # 屋頂上的帳篷頂
    c.rect(4, 2, 1, 9, WOOD[1])
    for y in range(2, 9):
        c.rect(5, y, 8 - abs(y - 5), 1, LINEN[3] if y < 5 else LINEN[2])
    door(c, 24, 30, 7, 13, col="#1e2a3a")
    c.rect(10, 22, 6, 6, "#1e2a3a")
    c.rect(38, 22, 6, 6, "#1e2a3a")
    for x0, col in ((42, "#a8603e"), (46, "#8a5a3a")):  # 晾著的獸皮（硝皮匠）
        c.rect(x0, 30, 4, 7, col)
        c.px(x0, 30, "#c47a52")
    c.rect(41, 29, 10, 1, WOOD[1])
    c.outline(INK)
    save(c, "rooftop")


# ---------- 安提阿：柱廊大街 ----------
def colonnade():
    c = C(72, 46)
    shadow(c, 36, 43, 34)
    c.rect(2, 4, 68, 5, MARBLE[2])                   # 橫楣
    c.rect(2, 4, 68, 1, MARBLE[3])
    c.rect(2, 8, 68, 1, MARBLE[0])
    for x in range(4, 68, 4):
        c.px(x, 6, MARBLE[1])
    c.rect(1, 2, 70, 2, BRICK[2])                    # 屋瓦
    c.rect(1, 2, 70, 1, BRICK[3])
    for x in range(4, 68, 13):
        column(c, x, 9, 43, MARBLE)
    c.rect(2, 41, 68, 3, STONE[2])                   # 台基
    c.rect(2, 41, 68, 1, STONE[3])
    c.outline(INK)
    save(c, "colonnade")


# ---------- 腓立比：河邊（呂底亞，徒 16:13-14）----------
def riverside():
    c = C(70, 34)
    for y in range(10, 30):                          # 一段河
        for x in range(0, 70):
            edge = 10 + math.sin(x * 0.18) * 2
            edge2 = 28 + math.sin(x * 0.15 + 1) * 2
            if edge <= y <= edge2:
                col = WATER[1] if h(x, y, 50) > 0.2 else WATER[2]
                if (y + x // 6) % 6 == 0:
                    col = WATER[3]
                if abs(y - edge) < 1 or abs(y - edge2) < 1:
                    col = "#8a7a52"
                c.px(x, y, col)
    for x0, col in ((6, PURPLE), (20, PURPLE)):      # 兩個染缸
        c.rect(x0, 2, 10, 9, STONE[1])
        c.rect(x0, 2, 10, 1, STONE[3])
        c.rect(x0 + 1, 3, 8, 2, col[2])
        c.px(x0 + 2, 3, col[3])
    for y in range(4, 14):                           # 晾著的紫色布
        c.rect(48, y, 14, 1, PURPLE[2] if y % 3 else PURPLE[1])
    c.rect(46, 2, 1, 14, WOOD[1])
    c.rect(63, 2, 1, 14, WOOD[1])
    c.rect(46, 3, 18, 1, WOOD[2])
    for x in (36, 40):                               # 河邊的蘆葦
        c.rect(x, 4, 1, 7, GREEN[1])
        c.rect(x, 3, 1, 2, "#8a6a3a")
    c.outline(INK)
    save(c, "riverside")


# ---------- 帖撒羅尼迦：會堂（徒 17:1-2）----------
def synagogue():
    c = C(58, 46)
    shadow(c, 29, 43, 27)
    blocks(c, 4, 16, 50, 27, STONE, 8, 4, 60)
    side_shade(c, 4, 16, 50, 27, 0.2)
    roof_tri(c, 29, 4, 28, 16, BRICK)
    c.rect(1, 15, 56, 2, STONE[3])
    for x in (12, 22, 32, 42):
        column(c, x, 18, 43, MARBLE, 4)
    door(c, 25, 31, 8, 12)
    c.rect(26, 8, 6, 5, "#2a1a12")                   # 山牆上的圓窗
    c.rect(27, 9, 4, 3, "#ffd75e")
    c.outline(INK)
    save(c, "synagogue")


# ---------- 雅典：亞略巴古（徒 17:19）與「未識之神」的壇（17:23）----------
def areopagus():
    c = C(70, 44)
    shadow(c, 35, 41, 33)
    for y in range(6, 42):                           # 一塊大岩石山丘
        half = 33 * math.sqrt(max(0.0, 1 - ((y - 42) / 36) ** 2))
        for x in range(int(35 - half), int(35 + half) + 1):
            l = -(x - 35) / 33 * 0.6 - (y - 24) / 40
            col = "#c8bca8" if l > 0.35 else "#a8a090" if l > -0.1 else "#8a8274" if l > -0.5 else "#6e675c"
            if h(x, y, 70) > 0.93:
                col = "#6e675c"
            c.px(x, y, col)
    for i in range(8):                               # 鑿在岩石上的台階
        c.rect(14 + i * 2, 40 - i * 3, 6, 2, "#d8ccb8")
        c.rect(14 + i * 2, 41 - i * 3, 6, 1, "#8a8274")
    c.rect(44, 8, 10, 7, MARBLE[2])                  # 小祭壇
    c.rect(44, 8, 10, 1, MARBLE[3])
    c.rect(45, 10, 8, 1, MARBLE[0])                  # 刻字
    c.rect(46, 12, 5, 1, MARBLE[0])
    c.outline(INK)
    save(c, "areopagus")


# ---------- 哥林多：審判台（迦流，徒 18:12）----------
def bema():
    c = C(56, 40)
    shadow(c, 28, 37, 26)
    blocks(c, 4, 18, 48, 19, MARBLE, 12, 4, 80)      # 高台
    side_shade(c, 4, 18, 48, 19, 0.2)
    for i in range(4):                               # 前面的台階（越下面越寬）
        y = 23 + i * 4
        c.rect(20 - i * 3, y, 16 + i * 6, 3, MARBLE[2])
        c.rect(20 - i * 3, y, 16 + i * 6, 1, MARBLE[3])
        c.rect(20 - i * 3, y + 3, 16 + i * 6, 1, MARBLE[0])
        c.px(20 - i * 3, y + 1, MARBLE[0])
        c.px(35 + i * 3, y + 1, MARBLE[0])
    c.rect(22, 8, 12, 10, WOOD[2])                   # 審判官的椅子
    c.rect(22, 8, 12, 2, WOOD[3])
    c.rect(22, 4, 2, 6, WOOD[1])
    c.rect(32, 4, 2, 6, WOOD[1])
    c.rect(24, 12, 8, 2, "#8a2a3a")
    c.outline(INK)
    save(c, "bema")


# ---------- 以弗所：大劇場（徒 19:29）----------
def theater():
    c = C(76, 44)
    shadow(c, 38, 41, 36)
    for y in range(4, 42):                           # 半圓的看台，一排一排
        for x in range(2, 74):
            dx, dy = (x - 38) / 36, (y - 42) / 38
            d = dx * dx + dy * dy
            if d > 1 or d < 0.22:
                continue
            row = int(d * 12)
            col = MARBLE[2] if row % 2 else MARBLE[1]
            if int(d * 24) % 2 == 0 and row % 2:
                col = MARBLE[3]
            if abs(dx) < 0.03 or abs(abs(math.atan2(dy, dx)) - 2.3) < 0.03 or abs(abs(math.atan2(dy, dx)) - 0.85) < 0.03:
                col = MARBLE[0]                      # 走道
            c.px(x, y, col)
    c.rect(20, 34, 36, 8, "#c8b898")                 # 舞台
    c.rect(20, 34, 36, 1, "#e0d0b0")
    for x in (24, 34, 44):
        column(c, x, 30, 42, MARBLE, 3)
    c.outline(INK)
    save(c, "theater")


# ---------- 耶路撒冷：所羅門廊（徒 3:11；5:12）----------
def portico():
    c = C(72, 52)
    shadow(c, 36, 49, 34)
    blocks(c, 0, 44, 72, 6, LIME, 12, 3, 90)         # 台階
    blocks(c, 4, 38, 64, 6, LIME, 12, 3, 91)
    c.rect(4, 6, 64, 6, LIME[2])                     # 屋頂與橫楣
    c.rect(4, 6, 64, 1, LIME[3])
    c.rect(4, 11, 64, 1, LIME[0])
    c.rect(2, 3, 68, 3, "#c8a050")
    c.rect(2, 3, 68, 1, "#e8c070")
    for x in range(6, 66, 9):
        column(c, x, 12, 39, MARBLE, 5)
    c.outline(INK)
    save(c, "portico")


# ---------- 米利大：擱淺的船（徒 27:41）----------
def wreck():
    c = C(68, 40)
    shadow(c, 34, 37, 32)
    for y in range(18, 36):                          # 斜躺的船身
        for x in range(4, 64):
            top = 18 + (x - 4) * 0.12
            bottom = 34 - abs(x - 34) * 0.12
            if top <= y <= bottom:
                col = WOOD[2] if (y // 3) % 2 else WOOD[1]
                if x > 52 and h(x, y, 100) > 0.6:
                    continue                         # 船尾被浪打壞了
                c.px(x, y, col)
    for x in range(6, 52, 6):
        c.rect(x, 18, 1, 16, WOOD[0])
    for y in range(2, 22):                           # 斷掉的桅杆
        c.px(20 + (22 - y) // 5, y, WOOD[1])
        c.px(21 + (22 - y) // 5, y, WOOD[0])
    for y in range(6, 14):                           # 破帆
        c.rect(23, y, 9 - (y - 6), 1, LINEN[3] if y % 2 else LINEN[2])
    c.rect(0, 34, 18, 2, WATER[2])                   # 浪花
    c.rect(2, 33, 6, 1, WATER[3])
    c.outline(INK)
    save(c, "wreck")


# ---------- 羅馬：水道橋 ----------
def aqueduct():
    c = C(80, 52)
    shadow(c, 40, 49, 38)
    for y in range(4, 50):
        for x in range(0, 80):
            ax = x % 20
            in_arch = y > 22 and 4 <= ax <= 15 and not (y < 28 and ((ax - 9.5) / 6) ** 2 + ((y - 28) / 6) ** 2 > 1)
            if in_arch:
                continue
            row = (y - 4) // 3
            off = 3 if row % 2 else 0
            col = "#c48a5a" if (x + off) % 6 else "#9a6a42"
            if (y - 4) % 3 == 2:
                col = "#9a6a42"
            if ax >= 16:
                col = "#a8744a" if col != "#9a6a42" else "#8a5a3a"
            c.px(x, y, col)
    c.rect(0, 4, 80, 4, "#d8a070")                   # 頂上的水道
    c.rect(0, 4, 80, 1, "#e8b888")
    c.rect(0, 2, 80, 2, WATER[2])
    c.outline(INK)
    save(c, "aqueduct")


# ---------- 拔摩海島：山洞（約翰在這裡看見異象）----------
def cave():
    c = C(64, 46)
    shadow(c, 32, 44, 30)
    for y in range(4, 44):
        half = 30 * math.sqrt(max(0.0, 1 - ((y - 44) / 40) ** 2))
        for x in range(int(32 - half), int(32 + half) + 1):
            l = -(x - 32) / 30 * 0.6 - (y - 24) / 40
            col = DARK[3] if l > 0.4 else DARK[2] if l > -0.1 else DARK[1] if l > -0.5 else DARK[0]
            if h(x, y, 110) > 0.95:
                col = "#5a6a3a"
            c.px(x, y, col)
    for y in range(22, 44):                          # 洞口
        half = 9 * math.sqrt(max(0.0, 1 - ((y - 44) / 22) ** 2))
        for x in range(int(30 - half), int(30 + half) + 1):
            c.px(x, y, "#0e0a10")
    for y in range(34, 44):                          # 洞裡透出來的光
        c.rect(28, y, 4, 1, "#3a2e1a" if y < 38 else "#5a4626")
    c.rect(29, 40, 2, 3, "#ffd75e")
    c.outline("#140e14")
    save(c, "cave")


# ---------- 府城：看西街的醫館（馬雅各，1865）----------
def clinic():
    c = C(60, 46)
    shadow(c, 30, 43, 28)
    for y in range(16, 43):
        for x in range(4, 56):
            brick = (x + (2 if (y // 2) % 2 else 0)) % 4 == 0 or y % 2 == 0
            col = BRICK[0] if brick else (BRICK[2] if h(x, y, 120) > 0.3 else BRICK[1])
            if x >= 46 and not brick:
                col = BRICK[1]
            c.px(x, y, col)
    for y in range(6, 16):                           # 紅瓦屋頂、燕尾
        w = (y - 6) * 3
        c.rect(14 - w // 2, y, 32 + w, 1, BRICK[1] if y % 2 else BRICK[2])
    c.rect(2, 15, 56, 1, BRICK[0])
    c.rect(13, 5, 34, 1, BRICK[0])
    for d in (0, 1, 2):
        c.px(12 - d, 4 - d, BRICK[0])
        c.px(47 + d, 4 - d, BRICK[0])
    c.rect(24, 28, 12, 15, "#3a2416")                # 敞開的店門
    c.rect(25, 29, 10, 14, "#5a3a22")
    c.rect(27, 33, 6, 3, LINEN[3])                   # 裡面的藥櫃
    c.rect(27, 37, 6, 3, LINEN[2])
    c.rect(22, 19, 16, 6, WOOD[2])                   # 招牌（沒寫字，木頭底）
    c.rect(22, 19, 16, 1, WOOD[3])
    c.rect(24, 21, 12, 2, LINEN[3])
    for x0 in (8, 42):                               # 窗櫺
        c.rect(x0, 26, 8, 7, "#3a2416")
        for k in range(x0 + 1, x0 + 8, 2):
            c.rect(k, 26, 1, 7, WOOD[2])
    c.rect(19, 18, 2, 4, "#c84a2a")                  # 燈籠
    c.rect(39, 18, 2, 4, "#c84a2a")
    c.outline("#3a1a12")
    save(c, "clinic")


if __name__ == "__main__":
    upperroom()
    citygate("gate_jerusalem", LIME, 3)
    citygate("gate_damascus", ["#8a7a62", "#a8987a", "#c8b894", "#e0d0ac"], 5, "#4a6a8a")
    threshing()
    rooftop()
    colonnade()
    riverside()
    synagogue()
    areopagus()
    bema()
    theater()
    portico()
    wreck()
    aqueduct()
    cave()
    clinic()
    print("ok")
