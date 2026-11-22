"""用 LPC（Liberated Pixel Cup）開源素材產生地面、場景物件與敵人走路圖，畫法和 make_people_lpc.py 的人物同一套。

用法：python tools/make_world_lpc.py
輸入：tools/lpc_src/world、tools/lpc_src/mobs（授權與作者寫在下面的 CREDITS，全部是 OGA-BY 3.0）
輸出：assets/sprites/hd/<名字>.png   兩倍解析度；main.gd 的 _tex() 有同名的就用它、以一半大小畫，碰撞與程式不用改
      assets/sprites/mobs/<敵人>.png  4 排（上、左、下、右）× N 格，每格是正方形
      data/credits_world.json         遊戲內作者名單用
"""
import json
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
W_SRC, M_SRC = ROOT / "tools" / "lpc_src" / "world", ROOT / "tools" / "lpc_src" / "mobs"
HD, MOBS = ROOT / "assets" / "sprites" / "hd", ROOT / "assets" / "sprites" / "mobs"
T = 32

CREDITS = [
    ("LPC Revised（地形、牆、屋頂、石柱、物件）", "Eliza Wyatt (DeathsDarling), Lanea Zimmerman (Sharm), Hyptosis, Demetrius", "https://github.com/ElizaWy/LPC"),
    ("LPC Imp", "Stephen Challener (Redshrike), William.Thompsonj", "https://opengameart.org/content/lpc-imp"),
    ("LPC Golem", "Stephen Challener (Redshrike), William.Thompsonj", "https://opengameart.org/content/lpc-golem"),
    ("LPC Spider", "Stephen Challener (Redshrike), William.Thompsonj", "https://opengameart.org/content/lpc-spider"),
    ("LPC Beetle", "Stephen Challener (Redshrike)", "https://opengameart.org/content/lpc-beetle"),
    ("Bat (Rework)", "bagzie, Jordan Irwin (AntumDeluge)", "https://opengameart.org/content/bat-rework"),
    ("King Cobra", "Jordan Irwin (AntumDeluge)", "https://opengameart.org/content/king-cobra"),
    ("LPC Frogman", "Stephen Challener (Redshrike), Evert", "https://opengameart.org/content/lpc-frogman"),
    ("Gothicvania Magic Pack 9（爆炸、火花、落雷；CC0）", "ansimuz", "https://opengameart.org/content/gothicvania-magic-pack-9"),
    ("LPC Horses（改作）", "bluecarrot16, Jordan Irwin (AntumDeluge)", "https://opengameart.org/content/lpc-horses-rework"),
]


def src(d: Path, name: str) -> Image.Image:
    return Image.open(d / name).convert("RGBA")


def w(name: str, *box: int) -> Image.Image:
    im = src(W_SRC, name + ".png")
    return im.crop(box) if box else im


def tone(im: Image.Image, rgb: tuple) -> Image.Image:
    return ImageChops.multiply(im, Image.new("RGBA", im.size, rgb + (255,)))


# ---------- 地面：256×256、可平鋪（世界 128×128） ----------
N = 8


def ground(name: str, base: list, color: tuple, stamps: list, seed: int) -> None:
    rnd = random.Random(seed)
    im = Image.new("RGBA", (N * T, N * T))
    for x in range(N):
        for y in range(N):
            im.paste(rnd.choice(base), (x * T, y * T))
    for st, at in stamps:
        for dx in (-N * T, 0, N * T):   # 超出邊的部分繞回另一邊，平鋪才接得起來
            for dy in (-N * T, 0, N * T):
                im.alpha_composite(*_clip(st, at[0] + dx, at[1] + dy))
    im = tone(im, color)
    im.putalpha(255)
    im.save(HD / f"{name}.png", optimize=True)


def _clip(st: Image.Image, x: int, y: int):
    big = Image.new("RGBA", (N * T, N * T))
    big.paste(st, (x, y))
    return big, (0, 0)


def grounds() -> None:
    ter = "terrain_summer"
    sq = lambda x, y: w(ter, x, y, x + T, y + T)
    sand = [sq(96, 160)] * 8 + [sq(128, 160), sq(160, 160)]
    dirt = [sq(96 + T * i, 96 + T * j) for i in range(3) for j in range(2)]
    grass = [sq(96, 64)] * 5 + [sq(96 + T * i, 64) for i in range(3)] + [sq(96 + T * i, 32) for i in range(3)]
    flag = lambda col, row: [w("tile_c", col * 64 + a, row * 64 + b, col * 64 + a + T, row * 64 + b + T) for a in (0, T) for b in (0, T)]
    cob = w(ter, 288, 96, 352, 160)          # 沙裡的一片石子
    dsand = w(ter, 288, 0, 384, 96)          # 土裡的一片沙
    hot = w(ter, 288, 160, 384, 256)         # 沙裡的深色沙
    patch = w(ter, 0, 0, 96, 96)             # 一叢草地（邊緣透明）
    tuft = w(ter, 64, 192, 96, 224)
    bit = w(ter, 64, 224, 96, 256)
    hole = w(ter, 192, 96, 256, 160)         # 草裡的一塊土
    spot = w(ter, 192, 256, 256, 320)        # 草裡的一塊沙
    g3 = [(patch, (32, 32)), (tuft, (160, 64)), (bit, (192, 192))]
    ground("ground_jerusalem", sand, (216, 204, 180), [(cob, (32, 64)), (cob, (160, 160)), (bit, (192, 32))], 1)
    ground("ground", grass, (235, 240, 215), [(hole, (128, 32)), (hole, (32, 160))], 2)
    ground("ground_camp", grass, (215, 225, 190), [(spot, (160, 96))], 3)
    ground("ground_antioch", dirt, (235, 220, 205), g3, 4)
    ground("ground_athens", flag(0, 0), (244, 240, 230), [(bit, (64, 64)), (bit, (160, 192))], 5)
    ground("ground_corinth", sand, (242, 226, 192), [(cob, (64, 32)), (cob, (160, 128)), (cob, (0, 160))], 6)
    ground("ground_desert", sand, (250, 226, 178), [(hot, (96, 96))], 7)
    ground("ground_ephesus", flag(0, 2), (214, 205, 222), [(tuft, (64, 160)), (bit, (192, 64))], 8)
    ground("ground_field", dirt, (240, 214, 150), [(patch, (0, 32)), (patch, (128, 128)), (tuft, (192, 32))], 9)
    ground("ground_fucheng", dirt, (214, 190, 178), [(patch, (96, 64)), (bit, (32, 192))], 10)
    ground("ground_joppa", flag(0, 1), (238, 228, 214), [(bit, (128, 64))], 11)
    ground("ground_malta", sand, (255, 240, 208), [(hot, (64, 128))], 12)
    ground("ground_patmos", dirt, (112, 118, 165), [(tuft, (64, 64)), (bit, (192, 160))], 13)
    ground("ground_rome", flag(1, 1), (190, 190, 196), [(bit, (96, 192))], 14)
    ground("ground_thessalonica", dirt, (224, 148, 118), [(dsand, (96, 96)), (bit, (32, 32))], 15)


# ---------- 物件 ----------
def out(name: str, im: Image.Image) -> None:
    box = im.getbbox()
    im.crop(box).save(HD / f"{name}.png", optimize=True)


def strip3(im: Image.Image, bw: int) -> Image.Image:
    """96 寬的三格圖拉成 bw 寬：左右邊不動、中間重複"""
    r = Image.new("RGBA", (bw, im.height))
    mid = im.crop((T, 0, 2 * T, im.height))
    for x in range(T, bw - T, T):
        r.paste(mid.crop((0, 0, min(T, bw - T - x), im.height)), (x, 0))
    r.paste(im.crop((0, 0, T, im.height)), (0, 0))
    r.paste(im.crop((2 * T, 0, 3 * T, im.height)), (bw - T, 0))
    return r


def house() -> Image.Image:
    bw, roof_h, wall_h = 80, 48, 58
    roof = w("adobe_brick_roof", 32, 128, 128, 228)
    r = strip3(roof, bw)
    body = Image.new("RGBA", (bw, roof_h + wall_h))
    body.paste(strip3(w("adobe_stucco_wall", 0, 0, 96, 96), bw).crop((0, 96 - wall_h, bw, 96)), (0, roof_h))
    top = Image.new("RGBA", (bw, roof_h))
    top.paste(r.crop((0, 0, bw, roof_h // 2)), (0, 0))
    top.paste(r.crop((0, 100 - roof_h // 2, bw, 100)), (0, roof_h // 2))
    body.paste(top, (0, 0))
    d = ImageDraw.Draw(body)
    y = roof_h + wall_h
    for x in range(8, bw - 8, 16):   # 伸出牆外的屋樑
        d.rectangle((x, roof_h + 4, x + 4, roof_h + 8), fill=(78, 46, 40, 255))
        d.rectangle((x + 1, roof_h + 4, x + 3, roof_h + 6), fill=(176, 108, 62, 255))
    cx = bw // 2 - 12
    d.rectangle((cx, y - 40, cx + 23, y), fill=(86, 55, 44, 255))
    d.rectangle((cx + 3, y - 37, cx + 20, y), fill=(43, 24, 33, 255))
    for x in (9, bw - 22):
        d.rectangle((x, y - 38, x + 12, y - 24), fill=(86, 55, 44, 255))
        d.rectangle((x + 2, y - 36, x + 10, y - 26), fill=(43, 24, 33, 255))
    return tone(body, (255, 230, 192))


def wall(bw: int) -> Image.Image:
    return tone(strip3(w("jagged_wall", 0, 0, 96, 96), bw).crop((0, 0, bw, 36)), (255, 232, 196))


def props() -> None:
    out("house", house())
    out("wall_1", wall(68))
    out("wall_2", wall(44))
    tree = lambda row, col, t: tone(w("trees_summer", 128 + 96 * col, row, 224 + 96 * col, row + 112), t)
    out("olive_1", tree(0, 0, (232, 228, 190)))
    out("olive_2", tree(0, 1, (214, 220, 178)))
    for i, (row, col) in enumerate(((0, 1), (128, 0), (256, 0)), 1):
        out(f"tree_{i}", tree(row, col, (255, 255, 255)))
    out("cypress", w("plants_summer", 0, 64, 32, 128))
    rock = lambda dy, *b: w("rocks", b[0], b[1] + dy, b[2], b[3] + dy)
    out("rock_1", rock(128, 64, 62, 124, 92))
    out("rock_2", rock(128, 128, 66, 160, 94))
    out("rock_3", rock(128, 0, 96, 60, 126))
    out("stones", rock(128, 62, 94, 124, 126))
    out("crag_1", rock(0, 0, 0, 64, 92))
    out("crag_2", rock(0, 128, 0, 192, 62))
    pil = w("stone_pillar", 0, 0, 32, 96)
    out("column_1", pil)
    broken = pil.crop((0, 40, 32, 96))
    ImageDraw.Draw(broken).polygon([(0, 0), (32, 0), (32, 6), (24, 1), (17, 8), (9, 2), (0, 9)], fill=(0, 0, 0, 0))
    out("column_2", broken)
    out("amphora", w("vases", 0, 0, 32, 64))
    out("bush", w("plants_summer", 0, 0, 32, 32))
    out("dry_bush", w("plants_autumn", 32, 0, 64, 32))
    out("wheat", w("plants_autumn", 352, 0, 384, 64))
    out("decal_tuft", w("terrain_summer", 64, 224, 96, 256))
    out("decal_tuft_dry", tone(w("terrain_autumn", 64, 224, 96, 256), (255, 235, 200)))
    out("decal_pebbles", rock(128, 160, 66, 192, 92))
    out("decal_potsherd", rock(128, 160, 98, 192, 124))


# ---------- 敵人 ----------
VIOLET = ((14, 8, 26), (44, 22, 66), (98, 54, 120), (190, 130, 190), (255, 214, 170))
CRIMSON = ((24, 6, 14), (78, 14, 34), (150, 36, 44), (226, 104, 70), (255, 214, 150))
INDIGO = ((10, 10, 28), (28, 34, 78), (58, 74, 138), (134, 150, 206), (228, 230, 255))
OCHRE = ((24, 14, 20), (76, 44, 46), (150, 92, 62), (222, 164, 92), (255, 232, 170))
TEAL = ((10, 16, 26), (24, 48, 62), (52, 98, 104), (128, 176, 160), (232, 240, 200))
BONE = ((20, 18, 28), (66, 60, 78), (128, 120, 132), (196, 190, 190), (246, 240, 226))


def shade(im: Image.Image, ramp: tuple, mix: float) -> Image.Image:
    """把原色依明暗換成指定色階（保留一點原色）：敵人整體偏暗紫，一眼和人物分開"""
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            v = (r * 0.3 + g * 0.59 + b * 0.11) / 255 * (len(ramp) - 1)
            k = min(int(v), len(ramp) - 2)
            c = [ramp[k][n] + (ramp[k + 1][n] - ramp[k][n]) * (v - k) for n in range(3)]
            px[x, y] = tuple(int(c[n] * mix + (r, g, b)[n] * (1 - mix)) for n in range(3)) + (a,)
    return im


def sheet(name: str, cw: int, ch: int, rows: tuple, cols: tuple, cell: int = 64, drop: int = 3, zoom: float = 1) -> Image.Image:
    """取出四排（上、左、下、右）放進正方形格子，腳底對齊格子底部往上 drop"""
    im = src(M_SRC, name + ".png")
    if name == "beetle":   # 底色是洋紅、格線是白色
        data = [(0, 0, 0, 0) if (p[0] > 200 and p[1] < 60 and p[2] > 200) or p[:3] == (255, 255, 255) else p for p in im.getdata()]
        im.putdata(data)
    cells = [[im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)) for c in cols] for r in rows]
    if zoom != 1:
        cells = [[c.resize((int(c.width * zoom), int(c.height * zoom)), Image.Resampling.NEAREST) for c in row] for row in cells]
    foot = max(c.getbbox()[3] for row in cells for c in row if c.getbbox())
    o = Image.new("RGBA", (cell * len(cols), cell * 4))
    for r, row in enumerate(cells):
        for k, c in enumerate(row):
            b = c.getbbox()
            x = cell * k + cell // 2 - c.width // 2
            y = cell * r + cell - drop - foot
            tile = Image.new("RGBA", (cell, cell))
            tile.paste(c, (x - cell * k, y - cell * r))
            o.paste(tile, (cell * k, cell * r))
            assert b, (name, r, k, "空格")
    return o


# 敵人名：(來源, 格寬, 格高, 上左下右的排, 取哪幾格, 色階, 保留比例, 其他)
IMP, SPI, GOL, COB = (1, 3, 0, 2), (0, 1, 2, 3), (0, 1, 2, 3), (0, 3, 2, 1)
WALK = (4, 5, 6, 7, 8, 9)
MOB = {
    "fear": ("bat", 32, 32, (2, 3, 0, 1), (1, 2, 3, 2), VIOLET, 0.7, {"drop": 16}),
    "curious": ("bat", 32, 32, (2, 3, 0, 1), (1, 2, 3, 2), OCHRE, 0.75, {"drop": 16}),
    "fear_b": ("bat", 32, 32, (2, 3, 0, 1), (1, 2, 3, 2), CRIMSON, 0.6, {"drop": 16}),
    "strife_b": ("spider", 64, 64, SPI, WALK, VIOLET, 0.8, {}),
    "lies_b": ("cobra", 64, 64, COB, (0, 1, 2, 1), VIOLET, 0.7, {"zoom": 0.625}),
    "sleep_b": ("beetle", 49, 49, (1, 3, 0, 2), (0, 1, 2, 3), INDIGO, 0.7, {}),
    "strife": ("spider", 64, 64, SPI, WALK, CRIMSON, 0.8, {}),
    "sleep": ("spider", 64, 64, SPI, WALK, INDIGO, 0.8, {}),
    "lies": ("cobra", 64, 64, COB, (0, 1, 2, 1), TEAL, 0.7, {"zoom": 0.625}),
    "viper": ("cobra", 64, 64, COB, (0, 1, 2, 1), CRIMSON, 0.6, {"zoom": 0.625}),
    "riot": ("imp_sword", 64, 64, IMP, (0, 1, 2, 3), OCHRE, 0.65, {}),
    "pride": ("imp_shield", 64, 64, IMP, (0, 1, 2, 3), OCHRE, 0.85, {}),
    "sorcery": ("imp", 64, 64, IMP, (0, 1, 2, 3), INDIGO, 0.8, {}),
    "accuser": ("imp_pitchfork", 64, 64, IMP, (0, 1, 2, 3), VIOLET, 0.85, {}),
    "idol": ("golem", 64, 64, GOL, (0, 1, 2, 3, 4, 5, 6), OCHRE, 0.85, {}),
    "power": ("golem", 64, 64, GOL, (0, 1, 2, 3, 4, 5, 6), VIOLET, 0.75, {}),
    "locust": ("beetle", 49, 49, (1, 3, 0, 2), (0, 1, 2, 3), OCHRE, 0.6, {}),
    "frog": ("frogman", 80, 96, (4, 5, 6, 7), (0, 1, 2, 3, 4, 5), TEAL, 0.55, {}),
    "terror": ("imp_pitchfork", 64, 64, IMP, (0, 1, 2, 3), CRIMSON, 0.55, {"zoom": 2, "cell": 128}),
    "rider_white": ("horse_white", 64, 85, (0, 3, 2, 1), (0, 1, 2, 1), BONE, 0.2, {"cell": 96}),
    "rider_red": ("horse_white", 64, 85, (0, 3, 2, 1), (0, 1, 2, 1), CRIMSON, 0.3, {"cell": 96, "coat": (214, 84, 62)}),
    "rider_black": ("horse_white", 64, 85, (0, 3, 2, 1), (0, 1, 2, 1), INDIGO, 0.0, {"cell": 96, "coat": (70, 68, 84)}),
    "rider_pale": ("horse_white", 64, 85, (0, 3, 2, 1), (0, 1, 2, 1), TEAL, 0.0, {"cell": 96, "coat": (170, 196, 160)}),
}
RIDER_CLOAK = {"rider_white": BONE, "rider_red": CRIMSON, "rider_black": INDIGO, "rider_pale": TEAL}


def add_rider(o: Image.Image, key: str) -> Image.Image:
    """騎士：LPC 人物（哥尼流的盔甲）的上半身放到馬背上"""
    man = shade(Image.open(ROOT / "assets" / "sprites" / "lpc" / "cornelius.png"), RIDER_CLOAK[key], 0.8)
    c = 96
    for r in range(4):
        body = man.crop((0, r * 64, 64, r * 64 + 64)).crop((8, 10, 56, 50))
        for k in range(o.width // c):
            dy = 1 if k % 2 else 0
            o.alpha_composite(body, (k * c + 24, r * c + (20 if r in (1, 3) else 8) + dy))
    return o


def mobs() -> None:
    for key, (name, cw, ch, rows, cols, ramp, mix, kw) in MOB.items():
        kw = dict(kw)
        coat = kw.pop("coat", None)
        im = shade(sheet(name, cw, ch, rows, cols, **kw), ramp, mix)
        if coat:
            im = tone(im, coat)
        if key in RIDER_CLOAK:
            im = add_rider(im, key)
        a = im.getchannel("A")   # 提亮一點：一大群擠在一起、老兵又會再染暗，太深會糊成一團
        im = ImageEnhance.Brightness(im.convert("RGB")).enhance(1.0 if key in RIDER_CLOAK else 1.3).convert("RGBA")
        im.putalpha(a)
        im.save(MOBS / f"{key}.png", optimize=True)


# ---------- 攻擊特效（Gothicvania，CC0）：爆炸、擊中火花、落雷尾端；兩倍解析度、同名取代舊圖 ----------
FX_SRC = ROOT / "tools" / "lpc_src" / "fx"


def fx_frame(name: str, n: int) -> Image.Image:
    return Image.open(FX_SRC / f"{name}{n}.png").convert("RGBA")


def fx_sheet(name: str, picks: tuple, size: int, crop=None) -> Image.Image:
    o = Image.new("RGBA", (size * len(picks), size))
    for i, n in enumerate(picks):
        im = fx_frame(name, n)
        if crop:
            im = im.crop(crop)
        o.paste(im.resize((size, size), Image.Resampling.NEAREST), (i * size, 0))
    return o


def fx() -> None:
    fx_sheet("FireBomb_Fire-bomb", (8, 9, 10, 11, 12, 14), 64).save(HD / "fx_boom.png", optimize=True)
    sp = fx_sheet("spark_spark", (2, 3, 4, 6), 22)
    r_, g_, b_, a_ = sp.split()
    Image.merge("RGBA", (b_, g_, r_, a_)).save(HD / "fx_spark.png", optimize=True)   # 藍光對調成暖金色，和聖靈的光一致
    fx_sheet("Lightning_Lightning", (5, 6, 7), 26, crop=(0, 64, 64, 128)).save(HD / "fx_zapend.png", optimize=True)


def main() -> None:
    HD.mkdir(parents=True, exist_ok=True)
    MOBS.mkdir(parents=True, exist_ok=True)
    grounds()
    props()
    mobs()
    fx()
    doc = {"_說明": "地圖與敵人素材的作者名單（tools/make_world_lpc.py 產生），遊戲內「日誌」頁底下顯示。", "license": "OGA-BY 3.0",
           "items": [{"name": n, "authors": a, "url": u} for n, a, u in CREDITS]}
    (ROOT / "data" / "credits_world.json").write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(len(list(HD.glob("*.png"))), "hd,", len(MOB), "mobs")


if __name__ == "__main__":
    main()
