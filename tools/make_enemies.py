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


# ---------- 新城市的敵人 ----------
def idol(c, f):
    # 偶像（雅典）：站在台座上的石像，眼睛發光
    c.blob(10, 16, 6, 2.5, ("#6a665e", "#9a958a", "#c8c2b2"), 0, 50)
    c.blob(10, 10, 3.5, 5.5, ("#8a8478", "#b8b2a4", "#e0dace"), 0, 51)
    c.blob(10, 4, 2.5, 2.5, ("#8a8478", "#b8b2a4", "#e0dace"), 0, 52)
    col = "#ff5a3a" if f else "#ffb03a"
    c.px(9, 4, col)
    c.px(11, 4, col)
    c.outline("#3a362e")


def curious(c, f):
    # 好奇（雅典）：大眼睛的小影子，到處張望（徒 17:21）
    c.blob(10, 12, 5, 5, ("#1e2a4a", "#34466e", "#4f6494"), 0.2, 53 + f)
    for side in (-1, 1):
        c.blob(10 + side * 2.5, 10, 2, 2, ("#c8d8f0", "#e8f0ff", "#ffffff"), 0, 54)
        c.px(10 + side * 2.5 + (1 if f else -1), 10, "#101828")
    c.px(4, 5 - f, "#ffe14d")
    c.px(4, 6 - f, "#ffe14d")
    c.px(4, 8 - f, "#ffe14d")
    c.outline()


def accuser(c, f):
    # 誣告（耶路撒冷）：伸長手指著人的黑袍身影
    for y in range(5, 19):
        w = 2 + (y - 5) * 0.35
        for x in range(21):
            if abs(x - 9) < w:
                c.px(x, y, "#2a2030" if abs(x - 9) < w - 1 else "#4a3a50")
    c.blob(9, 5, 2.5, 2.5, ("#2a2030", "#3a2a40", "#5a4a60"), 0, 55)
    c.px(8, 5, "#ff7a4a")
    c.px(10, 5, "#ff7a4a")
    for i in range(6):
        c.px(11 + i, 9 - (i // 3) + f, "#c8a080")
    c.px(17, 7 + f, "#e8c0a0")
    c.outline()


def viper(c, f):
    # 毒蛇（馬爾他）：從柴堆裡竄出來的小蛇（徒 28:3）
    for i in range(16):
        x = 3 + i
        y = 13 + math.sin(i * 0.8 + f * 1.5) * 2
        c.px(x, y, "#6a7a2a" if i % 3 else "#a0a040")
        c.px(x, y + 1, "#3a4a18")
    c.blob(18, 12, 2.2, 1.8, ("#3a4a18", "#6a7a2a", "#a0a040"), 0, 56)
    c.px(19, 11, "#ff3a2a")
    c.px(20, 13 + f, "#e8481c")
    c.outline()


def power(c, f):
    # 權勢（羅馬）：戴頭盔、拿盾牌的黑色重甲兵
    c.blob(10, 12, 5.5, 6, ("#1a1820", "#2e2a36", "#46404e"), 0, 57)
    c.blob(10, 5, 3.5, 3, ("#4a3a1a", "#8a6a2a", "#c8a040"), 0, 58)
    for x in range(8, 13):
        c.px(x, 2 - f, "#c8302a")
    c.px(9, 6, "#ff3a2a")
    c.px(11, 6, "#ff3a2a")
    c.blob(5, 12, 2.5, 4, ("#5a1a14", "#8a2a1e", "#b8402a"), 0, 59)
    c.px(5, 12, "#c8a040")
    c.outline("#0a0810")


def boss_athens():
    # 滿城偶像（徒 17:16）：一群大小石像擠成一座小山，眼睛都在發光
    c = Canvas(40, 40)
    for i, (x, y, s) in enumerate([(10, 26, 1.0), (30, 26, 1.0), (20, 20, 1.4), (14, 32, 0.8), (26, 32, 0.8)]):
        c.blob(x, y + 6 * s, 5 * s, 2 * s, ("#6a665e", "#9a958a", "#c8c2b2"), 0, 60 + i)
        c.blob(x, y, 3.5 * s, 6 * s, ("#8a8478", "#b8b2a4", "#e0dace"), 0, 65 + i)
        c.blob(x, y - 7 * s, 2.5 * s, 2.5 * s, ("#8a8478", "#b8b2a4", "#e0dace"), 0, 70 + i)
        c.px(x - 1, y - 7 * s, "#ff5a3a")
        c.px(x + 1, y - 7 * s, "#ff5a3a")
    c.outline("#3a362e")
    c.save("boss_athens")


def boss_jerusalem():
    # 四十人的誓約（徒 23:12）：一大群蒙面人，手裡的短刀閃著光
    c = Canvas(40, 40)
    c.blob(20, 26, 17, 12, ("#1a1420", "#2e2436", "#463a50"), 0.2, 75)
    for i in range(10):
        x, y = 7 + (i * 9) % 27, 17 + (i * 7) % 15
        c.blob(x, y, 2.5, 2.5, ("#1a1420", "#2e2436", "#3e3446"), 0, 76 + i)
        c.px(x, y, "#ffb08a")
        c.px(x + 3, y - 3, "#e0e0f0")
        c.px(x + 4, y - 4, "#ffffff")
    c.outline("#08060a")
    c.save("boss_jerusalem")


def boss_malta():
    # 友拉革羅風（徒 27:14）：捲成漩渦的暴風雲，裡面有閃電
    c = Canvas(40, 40)
    for i in range(260):
        a = i * 0.21
        r = 3 + i * 0.065
        x, y = 20 + math.cos(a) * r, 20 + math.sin(a) * r * 0.8
        col = "#4a5a70" if i % 4 else "#8a9ab0"
        c.px(x, y, col)
        c.px(x + 1, y, "#2a3448")
    for x, y in [(18, 14), (19, 16), (17, 18), (18, 20), (20, 22)]:
        c.px(x, y, "#ffe14d")
        c.px(x + 1, y, "#fff4c2")
    c.outline("#101828")
    c.save("boss_malta")


def boss_rome():
    # 黑暗的權勢（西 1:13）：戴王冠的巨大黑影，張開雙翼
    c = Canvas(40, 40)
    for side in (-1, 1):
        for i in range(14):
            for j in range(10 - i // 2):
                c.px(20 + side * (6 + i), 14 + j + i * 0.4, "#1a1420" if j > 2 else "#3a2a40")
    c.blob(20, 24, 8, 12, ("#0e0a12", "#1e1626", "#36283e"), 0.1, 85)
    for x in range(14, 27):
        c.px(x, 10 - (2 if x % 3 == 0 else 0), "#c8a040")
        c.px(x, 11, "#c8a040")
    c.px(17, 18, "#ff3a2a")
    c.px(18, 18, "#ff3a2a")
    c.px(22, 18, "#ff3a2a")
    c.px(23, 18, "#ff3a2a")
    c.outline("#050308")
    c.save("boss_rome")


# ---------- 拔摩海島（啟示錄） ----------
def locust(c, f):
    # 蝗蟲（啟 9:3–7）：金褐色的身體、透明翅膀快速拍動，頭上像戴著金冠
    c.blob(10, 12, 5.5, 2.8, ("#4a3410", "#8a6420", "#c89a3a"), 0, 90)
    c.blob(15, 11, 2.2, 2.2, ("#4a3410", "#8a6420", "#c89a3a"), 0, 91)
    for x in (14, 15, 16):
        c.px(x, 8, "#ffd75e")
    c.px(16, 11, "#ff3a2a")
    wy = 7 if f else 9
    for i in range(6):
        c.px(7 + i, wy - (i % 2), "#d8e0f0")
        c.px(7 + i, wy + 1 - (i % 2), "#a8b4c8")
    for i in range(3):
        c.px(6 + i * 3, 15, "#4a3410")
        c.px(5 + i * 3, 16, "#4a3410")
    c.outline()


def frog(c, f):
    # 污靈（啟 16:13）：像青蛙的污穢的靈，黃綠色、鼓起的眼睛
    y0 = 1 if f else 0
    c.blob(10, 13 - y0, 6, 4.5, ("#2a3a14", "#4a6a1e", "#7a9a2e"), 0.1, 92)
    for side in (-1, 1):
        c.blob(10 + side * 3, 8 - y0, 1.8, 1.8, ("#c8c84a", "#e8e86a", "#ffffa0"), 0, 93)
        c.px(10 + side * 3, 8 - y0, "#101008")
        c.px(10 + side * 6, 16, "#2a3a14")
        c.px(10 + side * 7, 17, "#2a3a14")
    for x in range(7, 14):
        c.px(x, 15 - y0, "#1a2408")
    c.outline("#0e1406")


def rider(col_dark, col_mid, col_light, accent, seed):
    def fn(c, f):
        # 騎士（啟 6:2–8）：馬身、騎在上面的人，手上拿著各自的東西
        leg = 1 if f else 0
        c.blob(10, 13, 6.5, 3.5, (col_dark, col_mid, col_light), 0, seed)
        c.blob(16, 10, 2.5, 2.2, (col_dark, col_mid, col_light), 0, seed + 1)
        for lx in (6, 8, 12, 14):
            for yy in range(16, 20):
                c.px(lx + (leg if lx in (6, 12) else -leg), yy, col_dark)
        c.blob(9, 7, 2.2, 3, ("#2a2030", "#4a3a50", "#6a5a70"), 0, seed + 2)
        c.blob(9, 3, 1.8, 1.8, ("#8a6040", "#c08a60", "#e0b080"), 0, seed + 3)
        for i in range(5):
            c.px(11 + i, 6 - i, accent)
        c.px(17, 9, "#ff3a2a")
        c.outline()
    return fn


def boss_patmos():
    # 大紅龍（啟 12:3）：七個頭、十個角，尾巴拖下天上星辰的三分之一
    c = Canvas(40, 40)
    c.blob(20, 28, 12, 8, ("#5a0e10", "#9a1e1a", "#d0402a"), 0.1, 95)
    for i in range(14):
        c.px(30 + i * 0.6, 33 + math.sin(i * 0.7) * 2, "#9a1e1a")
        c.px(30 + i * 0.6, 34 + math.sin(i * 0.7) * 2, "#5a0e10")
    for i in range(7):
        a = math.pi * (1.1 + i * 0.13)
        nx, ny = 20 + math.cos(a) * 14, 22 + math.sin(a) * 14
        for k in range(8):
            c.px(20 + (nx - 20) * k / 8, 24 + (ny - 24) * k / 8, "#9a1e1a")
            c.px(21 + (nx - 20) * k / 8, 24 + (ny - 24) * k / 8, "#5a0e10")
        c.blob(nx, ny, 2.3, 2, ("#5a0e10", "#b02a20", "#e05a3a"), 0, 96 + i)
        c.px(nx, ny, "#ffd75e")
        c.px(nx - 1, ny - 2, "#e8dcc0")
        if i % 2 == 0:
            c.px(nx + 1, ny - 2, "#e8dcc0")
            c.px(nx + 1, ny - 3, "#e8dcc0")
    for x, y in [(4, 6), (8, 3), (34, 5), (37, 10), (2, 14)]:
        c.px(x, y, "#fff4c2")
    c.outline("#1a0406")
    c.save("boss_patmos")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("fear_b", fear_b), ("strife_b", strife_b), ("lies_b", lies_b), ("sleep_b", sleep_b),
                     ("riot", riot), ("pride", pride), ("sorcery", sorcery), ("terror", terror), ("apathy", apathy),
                     ("idol", idol), ("curious", curious), ("accuser", accuser), ("viper", viper), ("power", power),
                     ("locust", locust), ("frog", frog),
                     ("rider_white", rider("#8a8a94", "#d0d0d8", "#ffffff", "#e8dcc0", 100)),
                     ("rider_red", rider("#5a0e10", "#b02a20", "#e05a3a", "#e0e0f0", 104)),
                     ("rider_black", rider("#0a0a10", "#22222c", "#3a3a48", "#c8a040", 108)),
                     ("rider_pale", rider("#4a6a5a", "#8aaa96", "#c0d8c8", "#2a2030", 112))]:
        frames(name, fn)
    boss_athens()
    boss_jerusalem()
    boss_malta()
    boss_rome()
    boss_thessalonica()
    boss_corinth()
    boss_ephesus()
    boss_patmos()
    print("done")
