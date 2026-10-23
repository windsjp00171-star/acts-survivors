"""產生安提阿營地的像素圖（程式畫，跟地面、人物同一套畫法）。

用法：python tools/make_camp.py
輸出：assets/sprites/camp_<名字>.png。營火的火焰、旗子、祭壇與工坊的火在 scripts/camp.gd 執行時才畫（會動）。
光從左上來：左上亮、右下暗，外框深褐色。
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from make_terrain import C, h  # noqa: E402

INK = "#2a1e16"
WOOD = ["#4a3020", "#6b4a2a", "#8a6438", "#a87c4a"]      # 暗 → 亮
STONE = ["#5e5850", "#7a746a", "#9a948a", "#bab4a8"]
CLAY = ["#8a6a48", "#a8845c", "#c4a074", "#dcbc90"]
LINEN = ["#9a8460", "#bca47a", "#d8c49a", "#efe2c0"]
PURPLE = ["#4a2048", "#6e3068", "#8e4488", "#b066a8"]
GREEN = ["#3e5a2a", "#55743a", "#6e8e48", "#8aaa5a"]


def shadow(c, cx, cy, rx, ry=2):
    for y in range(c.h):
        for x in range(c.w):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1 and c.im.getpixel((x, y))[3] == 0:
                c.px(x, y, (20, 14, 8, 80))


def stones_row(c, x0, x1, y, hgt, pal, seed):
    """一排不規則的石塊（左上亮、右下暗、石縫深色）"""
    x = x0
    while x < x1:
        w = 3 + int(h(x, y, seed) * 3)
        w = min(w, x1 - x)
        for yy in range(y, y + hgt):
            for xx in range(x, x + w):
                edge_r = xx == x + w - 1 or yy == y + hgt - 1
                edge_l = xx == x or yy == y
                col = pal[0] if edge_r else pal[3] if edge_l else pal[2] if h(xx, yy, seed + 1) > 0.25 else pal[1]
                c.px(xx, yy, col)
        x += w


def save(c, name):
    c.save("camp_" + name)


# ---------- 地面 ----------
def ground():
    """營地四周的草地（可平鋪）；營地中間踩出來的泥土地和小路在 camp.gd 依建設的位置畫"""
    from make_terrain import pnoise, hx
    from PIL import Image
    S = 128
    im = Image.new("RGBA", (S, S))
    for y in range(S):
        for x in range(S):
            n = pnoise(x, y, 32, 140) * 0.7 + pnoise(x, y, 16, 141) * 0.3
            g = n + (h(x, y, 142) - 0.5) * 0.08
            col = "#7a9448" if g > 0.58 else "#6a8640" if g > 0.4 else "#5e7838"
            tuft = h(x // 2, y // 3, 143)
            if tuft > 0.93 and y % 3 == 0:
                col = "#8aa452"
            elif tuft > 0.93 and y % 3 == 2:
                col = "#4e6630"
            if h(x, y, 144) > 0.996:
                col = ["#f4e8f0", "#f0c040", "#c8a0e0"][int(h(x, y, 145) * 3)]
            if h(x, y, 146) > 0.997:
                col = "#9a948a"
            im.putpixel((x, y), hx(col))
    im.save(os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "ground_camp.png"))


# ---------- 營火 ----------
def fire():
    c = C(22, 12)
    shadow(c, 11, 9, 10, 2)
    for i in range(7):                      # 一圈石頭
        import math
        a = i * math.tau / 7 + 0.3
        x, y = 11 + math.cos(a) * 8, 7 + math.sin(a) * 3
        c.rect(x - 1, y - 1, 3, 2, STONE[2] if math.sin(a) < 0 else STONE[1])
        c.px(x - 1, y - 1, STONE[3])
    c.rect(6, 6, 10, 2, WOOD[1])            # 交叉的木柴
    c.rect(6, 6, 10, 1, WOOD[2])
    c.rect(8, 5, 6, 1, WOOD[0])
    c.rect(9, 7, 4, 1, "#3a2418")           # 炭
    c.px(10, 7, "#c84a1c")
    c.outline(INK)
    save(c, "fire")


# ---------- 帳棚 ----------
def tent(name, w, hgt, pal, stripe):
    c = C(w + 4, hgt + 5)
    cx = (w + 4) // 2
    base = hgt + 2
    shadow(c, cx, base + 1, w // 2 + 1, 2)
    for y in range(2, base + 1):
        half = (y - 2) * (w / 2) / (base - 2)
        for x in range(int(cx - half), int(cx + half) + 1):
            left = x < cx
            col = pal[2] if left else pal[1]
            if abs(x - cx) < 1:
                col = pal[3]
            if stripe and (x - cx + 64) % 6 in (0, 1) and y > 4:
                col = stripe[2] if left else stripe[1]
            if y == base:
                col = pal[0]
            c.px(x, y, col)
    # 門：三角形的暗開口，掀起來的門簾
    dh = int((base - 2) * 0.6)
    for y in range(base - dh, base):
        half = (y - (base - dh)) * 0.45
        for x in range(int(cx - half), int(cx + half) + 1):
            c.px(x, y, "#2a1e22")
    for y in range(base - dh, base):
        k = int((y - (base - dh)) * 0.45)
        c.px(cx - k - 1, y, pal[3])
    c.rect(cx, 0, 1, 3, WOOD[1])            # 帳棚桿
    c.px(cx - 1, base, WOOD[0])
    c.px(2, base, WOOD[0])                  # 營釘
    c.px(w + 1, base, WOOD[0])
    c.outline(INK)
    save(c, name)


# ---------- 見證牆、日誌、路標 ----------
def board():
    c = C(34, 28)
    shadow(c, 17, 26, 15)
    for x0 in (3, 29):
        c.rect(x0, 8, 2, 18, WOOD[1])
        c.rect(x0, 8, 1, 18, WOOD[2])
    c.rect(1, 3, 32, 16, WOOD[0])
    for y in range(4, 18):                  # 木板（橫條）
        c.rect(2, y, 30, 1, WOOD[2] if (y // 3) % 2 else WOOD[3] if y % 3 == 0 else WOOD[2])
        if y % 3 == 0:
            c.rect(2, y, 30, 1, WOOD[1])
    c.rect(0, 2, 34, 2, WOOD[1])            # 小屋簷
    c.rect(0, 2, 34, 1, WOOD[3])
    c.outline(INK)
    save(c, "board")


def note():
    """見證牆上貼的一張紙（依見證錄完成數量貼上去）"""
    c = C(4, 4)
    c.rect(0, 0, 4, 4, LINEN[3])
    c.rect(0, 3, 4, 1, LINEN[1])
    c.px(1, 1, "#8a7a5a")
    c.px(2, 1, "#8a7a5a")
    save(c, "note")


def logpost():
    c = C(20, 26)
    shadow(c, 10, 24, 5)
    c.rect(9, 10, 2, 15, WOOD[1])
    c.rect(9, 10, 1, 15, WOOD[2])
    c.rect(1, 3, 18, 13, WOOD[1])
    c.rect(2, 4, 16, 11, LINEN[3])
    c.rect(2, 14, 16, 1, LINEN[1])
    for i in range(4):
        c.rect(4, 6 + i * 2, 12 - (i % 2) * 4, 1, "#8a7a5a")
    c.rect(1, 2, 18, 1, WOOD[2])
    c.outline(INK)
    save(c, "log")


def sign():
    c = C(26, 24)
    shadow(c, 11, 22, 5)
    c.rect(10, 4, 2, 18, WOOD[1])
    c.rect(10, 4, 1, 18, WOOD[2])
    for y in range(5, 11):                  # 指向東方的箭頭板
        r = 22 if y in (5, 10) else 23 if y in (6, 9) else 24
        c.rect(2, y, r - 2, 1, WOOD[3] if y == 5 else WOOD[2] if y < 9 else WOOD[1])
    c.rect(4, 7, 14, 1, WOOD[0])
    for y in range(13, 17):                 # 指回營地的小板
        c.rect(3 if y in (13, 16) else 2, y, 15, 1, WOOD[2] if y < 15 else WOOD[1])
    c.rect(5, 14, 9, 1, WOOD[0])
    c.outline(INK)
    save(c, "sign")


def table(name, w):
    """矮木桌（擘餅的桌子／愛筵長桌），上面放餅和杯"""
    c = C(w + 4, 16)
    shadow(c, (w + 4) // 2, 13, w // 2 + 2, 2)
    c.rect(2, 7, w, 3, WOOD[2])
    c.rect(2, 7, w, 1, WOOD[3])
    c.rect(2, 9, w, 1, WOOD[1])
    for x0 in (3, w - 1):
        c.rect(x0, 10, 2, 3, WOOD[0])
    k = 0
    for x in range(5, w - 3, 7):
        if k % 2 == 0:                      # 一個圓餅
            c.rect(x, 5, 4, 2, CLAY[2])
            c.rect(x + 1, 4, 2, 1, CLAY[3])
            c.px(x + 3, 6, CLAY[1])
        else:                               # 一個陶杯
            c.rect(x + 1, 3, 2, 4, "#8a3a2a")
            c.px(x + 1, 3, "#b05a40")
        k += 1
    if w >= 30:                             # 長桌兩邊的坐墊
        for x in range(4, w, 8):
            c.rect(x, 13, 4, 2, PURPLE[2] if (x // 8) % 2 else "#4a6a8a")
    c.outline(INK)
    save(c, name)


# ---------- 用見證蓋的建設 ----------
def well():
    c = C(24, 30)
    shadow(c, 12, 28, 11)
    for y in range(18, 27):                 # 石頭井欄（圓柱，左亮右暗）
        for x in range(3, 21):
            t = (x - 3) / 17
            col = STONE[3] if t < 0.2 else STONE[2] if t < 0.55 else STONE[1] if t < 0.85 else STONE[0]
            if (y - 18) % 3 == 0 or (x + (y // 3) * 2) % 6 == 0:
                col = STONE[0]
            c.px(x, y, col)
    for x in range(3, 21):                  # 井口（深色水面）
        c.px(x, 17, STONE[3])
    c.rect(5, 16, 14, 1, "#1e3448")
    c.rect(4, 17, 16, 1, STONE[2])
    for x0 in (3, 19):                      # 木架
        c.rect(x0, 4, 2, 13, WOOD[1])
        c.px(x0, 4, WOOD[3])
    c.rect(2, 3, 20, 2, WOOD[2])
    c.rect(2, 3, 20, 1, WOOD[3])
    for y in range(0, 3):                   # 小屋頂
        c.rect(5 - y, y, 14 + y * 2, 1, "#a65a3a" if y < 2 else "#8a4a30")
    c.rect(11, 5, 1, 7, "#c8b48a")          # 繩子和水桶
    c.rect(9, 12, 5, 4, WOOD[2])
    c.rect(9, 12, 5, 1, WOOD[3])
    c.rect(9, 14, 5, 1, WOOD[0])
    c.outline(INK)
    save(c, "well")


def tower():
    c = C(26, 50)
    shadow(c, 13, 48, 10)
    for x0, x1 in ((5, 7), (18, 20)):       # 兩根柱子
        for y in range(14, 48):
            c.rect(x0, y, 2, 1, WOOD[1])
            c.px(x0, y, WOOD[2])
    for y in range(18, 46, 6):              # 斜撐
        for i in range(12):
            c.px(7 + i, y + i // 2, WOOD[0])
    for y in range(20, 48, 4):              # 梯子
        c.rect(10, y, 6, 1, WOOD[2])
    c.rect(10, 18, 1, 30, WOOD[1])
    c.rect(15, 18, 1, 30, WOOD[1])
    c.rect(2, 12, 22, 4, WOOD[2])           # 平台與欄杆
    c.rect(2, 12, 22, 1, WOOD[3])
    c.rect(2, 15, 22, 1, WOOD[0])
    for x in range(3, 24, 4):
        c.rect(x, 7, 1, 5, WOOD[1])
    c.rect(2, 7, 22, 1, WOOD[2])
    for y in range(0, 7):                   # 茅草屋頂
        w = 4 + y * 3
        for x in range(13 - w // 2, 13 + w // 2 + 1):
            c.px(x, y, "#c8a050" if x < 13 else "#a88038")
            if (x + y) % 3 == 0:
                c.px(x, y, "#8a6a2a")
    c.outline(INK)
    save(c, "tower")


def altar():
    """祭壇：用沒鑿過的石頭疊起來（出 20:25），火在 camp.gd 畫"""
    c = C(26, 18)
    shadow(c, 13, 16, 12)
    stones_row(c, 2, 24, 11, 4, STONE, 61)
    stones_row(c, 4, 22, 7, 4, STONE, 62)
    stones_row(c, 6, 20, 4, 3, STONE, 63)
    c.rect(8, 3, 10, 1, "#3a2418")          # 柴
    c.rect(9, 2, 8, 1, WOOD[1])
    c.outline(INK)
    save(c, "altar")


def library():
    """書房：小石屋、平屋頂（近東的房子），門口一排裝書卷的陶罐"""
    c = C(40, 36)
    shadow(c, 20, 34, 18)
    for y in range(10, 33):
        for x in range(3, 37):
            col = CLAY[2] if x < 30 else CLAY[1]
            if h(x, y, 70) > 0.93:
                col = CLAY[1] if x < 30 else CLAY[0]
            if x == 3:
                col = CLAY[3]
            c.px(x, y, col)
    c.rect(30, 10, 1, 23, CLAY[0])          # 牆角
    c.rect(1, 7, 38, 4, WOOD[1])            # 平屋頂與屋簷的木樑
    c.rect(1, 7, 38, 1, WOOD[3])
    for x in range(3, 37, 4):
        c.rect(x, 11, 2, 1, WOOD[0])
    c.rect(4, 5, 32, 2, CLAY[3])            # 屋頂上的矮牆
    c.rect(14, 18, 10, 15, "#3a2416")       # 門
    c.rect(15, 19, 8, 14, "#5a3a22")
    for y in range(20, 32, 3):              # 門裡看得到的書架
        c.rect(15, y, 8, 1, "#3a2416")
        for x in range(15, 23, 2):
            c.px(x, y - 1, LINEN[3] if (x + y) % 4 else LINEN[2])
    c.rect(6, 16, 5, 5, "#3a2416")          # 小窗
    c.rect(6, 16, 5, 1, CLAY[0])
    c.rect(27, 16, 5, 5, "#3a2416")
    for x0 in (4, 26, 32):                  # 陶罐
        c.rect(x0, 28, 4, 5, "#a8603e")
        c.rect(x0 + 1, 27, 2, 1, "#c47a52")
        c.px(x0, 28, "#c47a52")
        c.px(x0 + 3, 31, "#7a3e26")
    c.rect(17, 3, 4, 2, LINEN[3])           # 屋頂上曬的書卷
    c.px(17, 3, LINEN[1])
    c.outline(INK)
    save(c, "library")


def garden(stage):
    """園子：三畦田。stage 0 還沒種、1 正在長、2 可以收成"""
    c = C(34, 18)
    for r in range(3):
        y = 3 + r * 5
        for x in range(2 + r, 32 - r):
            c.px(x, y, "#6a4a30")
            c.px(x, y + 1, "#5a3e28")
            c.px(x, y + 2, "#4a3020")
        for x in range(4 + r, 31 - r, 4):
            if stage == 0:
                continue
            elif stage == 1:
                c.rect(x, y - 2, 1, 3, GREEN[2])
                c.px(x - 1, y - 1, GREEN[3])
                c.px(x + 1, y - 2, GREEN[1])
            else:
                c.rect(x, y - 3, 1, 4, GREEN[1])
                c.px(x - 1, y - 2, GREEN[2])
                c.px(x + 1, y - 2, GREEN[2])
                c.rect(x - 1, y - 4, 3, 2, ["#d84a3a", "#e8b030", "#8a4aa0"][(x + r) % 3])
                c.px(x - 1, y - 4, "#fff4c2")
    for x in range(0, 34, 3):               # 籬笆
        c.rect(x, 15, 1, 3, WOOD[1])
    c.rect(0, 16, 34, 1, WOOD[2])
    c.outline(INK)
    save(c, "garden_%d" % stage)


def forge():
    c = C(34, 34)
    shadow(c, 17, 32, 15)
    for y in range(12, 31):                 # 石砌的爐子
        stones_row(c, 4, 22, y, 1, STONE, 80 + y // 3)
    stones_row(c, 4, 22, 12, 3, STONE, 81)
    c.rect(9, 19, 8, 7, "#2a1410")          # 爐口（火在 camp.gd 畫）
    c.rect(10, 18, 6, 1, "#2a1410")
    c.rect(15, 0, 6, 13, STONE[1])          # 煙囪
    c.rect(15, 0, 2, 13, STONE[2])
    c.rect(14, 0, 8, 2, STONE[0])
    c.rect(23, 24, 8, 3, "#4a4a52")         # 鐵砧
    c.rect(24, 24, 6, 1, "#7a7a86")
    c.rect(25, 27, 4, 4, "#3a3a42")
    c.rect(24, 30, 6, 1, "#3a3a42")
    c.rect(27, 19, 1, 5, WOOD[2])           # 鎚子
    c.rect(26, 18, 3, 2, "#5a5a64")
    c.outline(INK)
    save(c, "forge")


def granary():
    """倉房：泥磚圓頂穀倉，門口幾袋麥子"""
    c = C(32, 34)
    shadow(c, 16, 32, 14)
    import math
    for y in range(2, 31):
        for x in range(3, 29):
            dx = (x - 15.5) / 12.5
            top = 2 + (1 - math.sqrt(max(0.0, 1 - dx * dx))) * 12
            if y < top:
                continue
            l = -dx * 0.8 - (y - 16) / 30
            col = CLAY[3] if l > 0.45 else CLAY[2] if l > -0.1 else CLAY[1] if l > -0.6 else CLAY[0]
            if y in (12, 20) and h(x, y, 90) > 0.3:
                col = CLAY[0]
            c.px(x, y, col)
    c.rect(12, 20, 8, 11, "#3a2416")        # 門
    c.rect(13, 19, 6, 1, "#3a2416")
    c.rect(13, 21, 6, 10, "#5a3a22")
    c.rect(14, 6, 4, 3, "#3a2416")          # 頂上的小窗
    for x0 in (2, 22, 26):                  # 麥袋
        c.rect(x0, 26, 5, 5, LINEN[2])
        c.rect(x0, 26, 5, 1, LINEN[3])
        c.rect(x0 + 4, 27, 1, 4, LINEN[1])
        c.rect(x0 + 1, 25, 3, 1, "#e0b85a")
    c.outline(INK)
    save(c, "granary")


def lamp():
    c = C(6, 14)
    c.rect(2, 4, 2, 10, WOOD[1])
    c.px(2, 4, WOOD[2])
    c.rect(1, 3, 4, 1, WOOD[2])
    c.rect(1, 1, 4, 2, "#c47a52")           # 陶油燈
    c.px(1, 1, "#e0a070")
    c.outline(INK)
    save(c, "lamp")


def banner_pole():
    c = C(5, 32)
    shadow(c, 2, 30, 2, 1)
    c.rect(2, 1, 1, 30, WOOD[1])
    c.px(2, 0, "#ffd75e")
    c.rect(1, 29, 3, 2, STONE[1])
    c.outline(INK)
    save(c, "banner")


if __name__ == "__main__":
    ground()
    fire()
    tent("tent_big", 52, 24, LINEN, PURPLE)
    tent("tent_small", 34, 16, ["#7a6a50", "#9a8868", "#b8a684", "#d0c0a0"], None)
    board()
    note()
    logpost()
    sign()
    table("supper", 24)
    table("table", 38)
    well()
    tower()
    altar()
    library()
    for s in range(3):
        garden(s)
    forge()
    granary()
    lamp()
    banner_pole()
    print("ok")
