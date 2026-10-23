"""產生地面上的小細節（貼在地上、不擋路）：裂縫、碎陶片、草叢、小花、水窪、落葉……

用法：python tools/make_decals.py
輸出：assets/sprites/decal_<名字>.png。各城市用哪些寫在 data/stages.json 的 decals。
地面圖是 128×128 一直重複，撒上這些小東西，看起來就不會一格一格的。
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from make_terrain import C, h  # noqa: E402


def save(c, name):
    c.save("decal_" + name)


def crack(name, seed, col="#00000000"):
    """石板或土地的裂縫：細細的、會分岔的暗線（半透明，蓋在什麼地面上都合）"""
    c = C(20, 12)
    x, y = 2.0, 6.0
    for i in range(16):
        c.px(x, y, (20, 14, 10, 110))
        if h(i, 1, seed) > 0.8:
            bx, by = x, y
            for k in range(3):
                by += 1 if h(i, k, seed + 1) > 0.5 else -1
                bx += 1
                c.px(bx, by, (20, 14, 10, 80))
        x += 1
        y += (1 if h(i, 2, seed) > 0.7 else -1 if h(i, 3, seed) > 0.7 else 0)
        y = max(1, min(10, y))
    save(c, name)


def pebbles(name, seed, cols=("#8a8478", "#a8a294", "#6e685e")):
    c = C(14, 8)
    for i in range(6):
        x, y = int(h(i, 0, seed) * 11) + 1, int(h(i, 1, seed) * 5) + 1
        col = cols[i % len(cols)]
        c.px(x, y, col)
        if i % 2 == 0:
            c.px(x + 1, y, col)
            c.px(x + 1, y + 1, (20, 14, 10, 90))
    save(c, name)


def potsherd(name, seed):
    """碎陶片（近東的地上到處都是）"""
    c = C(12, 8)
    for i in range(3):
        x, y = int(h(i, 0, seed) * 8) + 1, int(h(i, 1, seed) * 4) + 1
        c.rect(x, y, 3 if i else 2, 2, "#b8643e")
        c.px(x, y, "#d8845a")
        c.px(x + 1, y + 2, (20, 14, 10, 80))
    save(c, name)


def tuft(name, seed, cols=("#4e6630", "#6a8640", "#8aa452")):
    c = C(10, 8)
    for i in range(5):
        x = 1 + i * 2
        hgt = 3 + int(h(i, 0, seed) * 4)
        for k in range(hgt):
            c.px(x + (1 if k > 2 and i % 2 else 0), 7 - k, cols[min(2, k // 2)])
    save(c, name)


def flowers(name, seed, petal, center="#f0c040"):
    c = C(14, 9)
    for i in range(4):
        x, y = int(h(i, 0, seed) * 10) + 2, int(h(i, 1, seed) * 4) + 3
        c.px(x, y + 1, "#4e6630")
        c.px(x, y + 2, "#4e6630")
        c.px(x - 1, y, petal)
        c.px(x + 1, y, petal)
        c.px(x, y - 1, petal)
        c.px(x, y, center)
    save(c, name)


def leaves(name, seed, cols=("#8a6a2a", "#a8803a", "#6a7a3a")):
    c = C(16, 10)
    for i in range(6):
        x, y = int(h(i, 0, seed) * 13) + 1, int(h(i, 1, seed) * 7) + 1
        col = cols[i % len(cols)]
        c.px(x, y, col)
        c.px(x + 1, y, col)
        c.px(x + (1 if i % 2 else 0), y + 1, col)
    save(c, name)


def puddle(name, w, hh, water="#5a7a8a", light="#9ab8c4"):
    c = C(w, hh)
    cx, cy = w / 2 - 0.5, hh / 2 - 0.5
    for y in range(hh):
        for x in range(w):
            d = ((x - cx) / (w / 2)) ** 2 + ((y - cy) / (hh / 2)) ** 2
            d += (h(x, y, 7) - 0.5) * 0.2
            if d < 1.0:
                c.px(x, y, (20, 14, 10, 70) if d > 0.75 else water)
    c.rect(int(cx) - 2, int(cy) - 1, 3, 1, light)
    c.px(int(cx) + 2, int(cy) + 1, light)
    save(c, name)


def ripple(name, seed, col=(255, 250, 230, 90), dark=(80, 60, 30, 60)):
    """沙地上風吹出來的波紋"""
    c = C(22, 10)
    for k in range(3):
        for x in range(2, 20):
            y = 2 + k * 3 + round(math.sin(x * 0.5 + k + seed) * 1.0)
            c.px(x, y, col)
            c.px(x, y + 1, dark)
    save(c, name)


def footprints(name):
    c = C(20, 10)
    for i in range(4):
        x, y = 2 + i * 5, 3 + (i % 2) * 3
        c.rect(x, y, 2, 1, (60, 40, 20, 80))
        c.px(x + 1, y + 1, (60, 40, 20, 60))
    save(c, name)


def moss(name, seed):
    c = C(16, 10)
    for y in range(10):
        for x in range(16):
            d = ((x - 7.5) / 8) ** 2 + ((y - 4.5) / 5) ** 2
            if d < 1 and h(x, y, seed) > 0.35 + d * 0.5:
                c.px(x, y, (90, 120, 50, 150) if h(x, y, seed + 1) > 0.4 else (70, 100, 40, 150))
    save(c, name)


def straw(name, seed):
    c = C(14, 8)
    for i in range(7):
        x, y = int(h(i, 0, seed) * 9) + 1, int(h(i, 1, seed) * 6) + 1
        for k in range(4):
            c.px(x + k, y + (k if i % 2 else -k) // 3, "#e0b85a" if k % 2 else "#c89a40")
    save(c, name)


def seaweed(name, seed):
    c = C(14, 8)
    for i in range(4):
        x, y = int(h(i, 0, seed) * 9) + 2, int(h(i, 1, seed) * 4) + 2
        for k in range(4):
            c.px(x + k, y + round(math.sin(k + i)), "#3e5a3a" if k % 2 else "#4e6a3a")
    save(c, name)


def tidepool(name):
    puddle(name, 18, 9, water="#3e5a6a", light="#8ab0c0")


if __name__ == "__main__":
    crack("crack_1", 1)
    crack("crack_2", 7)
    pebbles("pebbles", 3)
    pebbles("pebbles_dark", 4, ("#3e3a44", "#56525c", "#2e2a30"))
    pebbles("pebbles_red", 5, ("#8e4e34", "#c8b8a0", "#6a3a26"))
    potsherd("potsherd", 9)
    tuft("tuft", 11)
    tuft("tuft_dry", 12, ("#8a7a4a", "#a8945a", "#c8b070"))
    flowers("flowers_w", 13, "#f4e8f0")
    flowers("flowers_y", 14, "#f0c040", "#c87a2a")
    flowers("flowers_p", 15, "#c8a0e0")
    leaves("leaves", 16)
    leaves("leaves_olive", 17, ("#6a7a4a", "#8a9a5a", "#5a6a3a"))
    leaves("leaves_red", 18, ("#a8503a", "#c87a3a", "#8a6a2a"))
    puddle("puddle", 20, 10)
    tidepool("tidepool")
    ripple("ripple", 0)
    footprints("footprints")
    moss("moss", 21)
    straw("straw", 22)
    seaweed("seaweed", 23)
    print("ok")
