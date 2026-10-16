"""產生同伴的像素圖（14×17，兩格走路動畫＋進化版）。

用法：python tools/make_people.py
輸出：assets/sprites/<key>_0.png、_1.png、_evo_0.png、_evo_1.png

造型照原本同伴的樣子：深色外框、頭髮、臉、袍子中間一條腰帶，手上拿著他的東西。
進化版頭上多一圈光環、腰帶變金色。
"""
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")

# 基本身形（取自原本的同伴）：a 外框、b 頭髮、c 皮膚、d 眼睛、e 袍子、f 腰帶、i 袍子暗面、j 腳
BODY = [
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
FEET_1 = "...jj...jj...."   # 第二格：腳張開


def hx(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def person(key, hair, robe, robe_dark, sash, skin="#e3a878", beard=None, long_hair=False, item=None, crown=False):
    for evo in (False, True):
        for f in (0, 1):
            im = Image.new("RGBA", (14, 17), (0, 0, 0, 0))
            rows = [list(r) for r in BODY]
            if f == 1:
                # 走路：整個人往上一格、腳張開
                rows = rows[1:] + [list("..............")]
                rows[14] = list("..............")
                rows[15] = list(FEET_1)
            pal = {"a": "#2a1a14", "b": hair, "c": skin, "d": "#1b1420", "e": robe, "f": "#ffd75e" if evo else sash,
                   "i": robe_dark, "j": "#6b4a2a"}
            for y, row in enumerate(rows):
                for x, ch in enumerate(row):
                    if ch in pal:
                        im.putpixel((x, y), hx(pal[ch]))
            dy = -1 if f == 1 else 0
            px = lambda x, y, col: im.putpixel((x, y + dy), hx(col)) if 0 <= x < 14 and 0 <= y + dy < 17 else None
            if beard:
                for x in range(4, 9):
                    px(x, 8, beard)
                px(5, 9, beard)
                px(7, 9, beard)
            if long_hair:
                for y in (7, 8, 9, 10):
                    px(2, y, hair)
                    px(10, y, hair)
            if crown:
                for x in (4, 6, 8):
                    px(x, 2, "#ffd75e")
                for x in range(4, 9):
                    px(x, 3, "#ffd75e")
            if item:
                item(px, f)
            if evo:
                for x in range(4, 9):
                    px(x, 0 if f == 0 else 1, "#ffd75e")
                px(3, 1 if f == 0 else 2, "#fff4c2")
                px(9, 1 if f == 0 else 2, "#fff4c2")
            im.save(os.path.join(OUT, "%s%s_%d.png" % (key, "_evo" if evo else "", f)))


# 手上的東西（畫在右手邊 9–13 欄）
def torch_jar(px, f):
    for y in (10, 11, 12):
        px(10, y, "#2a1408")
        px(11, y, "#b8703a")
        px(12, y, "#2a1408")
    px(11, 9, "#2a1408")
    px(11, 8 - f, "#ff8a2a")
    px(11, 7 - f, "#ffd75e")


def scroll(px, f):
    for y in (10, 11, 12):
        px(10, y, "#2a1a14")
        px(11, y, "#f4ead2")
        px(12, y, "#2a1a14")
    px(11, 11, "#c0392b")


def staff_branch(px, f):
    for y in range(3, 15):
        px(11, y, "#8a6438")
    px(12, 3, "#5a8a2a")
    px(12, 4, "#7aaa3a")
    px(10, 4, "#5a8a2a")


def shell_rope(px, f):
    # 約拿：背著一個水袋
    for y in (10, 11, 12):
        px(10, y, "#2a3a4a")
        px(11, y, "#6a9ac0")
        px(12, y, "#2a3a4a")
    px(11, 10, "#a8d8f0")


def scepter(px, f):
    for y in range(6, 13):
        px(11, y, "#ffd75e")
    px(10, 5, "#ffd75e")
    px(11, 5, "#fff4c2")
    px(12, 5, "#ffd75e")


def timbrel(px, f):
    # 米利暗：一面圓鼓，邊上有小鈴
    for x, y in [(10, 9), (11, 9), (12, 9), (9, 10), (13, 10), (9, 11), (13, 11), (9, 12), (13, 12), (10, 13), (11, 13), (12, 13)]:
        px(x, y, "#2a1408")
    for x in (10, 11, 12):
        for y in (10, 11, 12):
            px(x, y, "#f0d8a0")
    px(9 + 4 * f, 10, "#ffd75e")


def glory(px, f):
    # 耶穌：頭上一圈光（不是進化，是祂本來的榮耀）；手上有釘痕
    for x in range(4, 9):
        px(x, 1, "#ffd75e")
    px(3, 2, "#fff4c2")
    px(9, 2, "#fff4c2")
    px(2, 11, "#c0392b")


def walking_staff(px, f):
    for y in range(6, 15):
        px(11, y, "#6b4a2a")
    px(11, 5, "#8a6438")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    person("gideon", "#3a2414", "#8a5a30", "#5e3b22", "#c8302a", beard="#3a2414", item=torch_jar)
    person("daniel", "#1a1420", "#6a3a8a", "#4a2a64", "#ffd75e", item=scroll)
    person("jonah", "#4a3020", "#5a7a90", "#3a5a70", "#e0d4b8", beard="#4a3020", item=shell_rope)
    person("noah", "#e8e4dc", "#c8c0a8", "#9a9280", "#3a7ad0", beard="#f4f0e8", item=staff_branch)
    person("esther", "#2a1420", "#c060c0", "#8a3a8a", "#ffd75e", long_hair=True, crown=True, item=scepter)
    person("miriam", "#5a2a14", "#ff8aa0", "#c85a70", "#fff4c2", long_hair=True, item=timbrel)
    person("jesus", "#4a2c18", "#f4f0e6", "#cfc6b4", "#b0302a", beard="#4a2c18", long_hair=True, item=glory)
    person("ananias", "#9a9288", "#6a7a4a", "#4a5a32", "#e0d4b8", beard="#c8c0b4", item=walking_staff)
    person("disciple", "#2a1a10", "#7a6a8a", "#5a4a6a", "#d8c8a0")
    print("done")
