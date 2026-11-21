"""人物高解析度版示範（52×68，遊戲裡以 0.5 倍繪製，世界座標與碰撞不變）。

風格參考 RO 一類的 Q 版：約 2.5 頭身但身體纖細（不是胖）、大眼睛帶高光、頭髮有份量、
柔和的三階明暗、外框用「該部位的深色」而不是全黑。只學風格方向，不沿用任何現成素材。

用法：python tools/make_people_hd.py <輸出資料夾> [人物 key ...]    （預設保羅、彼得、司提反）
沿用 make_people.py 的設定圖讀法（髮色、膚色、袍子、鬍子、手上的東西）；不動 assets/sprites。
輸出：<key>_0.png、<key>_1.png（走路兩格），有進化設定圖的再加 <key>_evo_0.png、_evo_1.png。
"""
import os
import sys

from PIL import Image, ImageDraw

import make_people as mp

W, H = 52, 68
CX = 26
HEAD_CY, HEAD_R = 21, 12          # 頭：大
TOP = 33                          # 肩膀高度
HAND_Y = TOP + 13                 # 手的高度（手上的東西也對齊這裡）
WAIST, HEM, FEET = TOP + 11, 60, 61


def rgb(h):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), 255)


def sh(c, k):
    return tuple(min(255, int(v * k)) for v in c[:3]) + (255,)


def body(s, f, evo):
    """回傳還沒加外框的人物（RGBA）。f=1 是走路的第二格。"""
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    skin, hair, robe = rgb(s["skin"]), rgb(s["hair"]), rgb(s["robe"])
    sash = rgb("#ffd75e") if evo else rgb(s["sash"])
    feet = rgb(s["feet"])
    bob = 1 if f == 1 else 0
    sway = 2 if f == 1 else 0
    top, waist, hem, hy = TOP - bob, WAIST - bob, HEM - bob, HEAD_CY - bob

    # 腳與小腿（細）
    d.rectangle([CX - 6 + sway, hem - 1, CX - 2 + sway, FEET + 3 - bob], fill=feet)
    d.rectangle([CX + 2 - sway, hem - 1, CX + 6 - sway, FEET + 3 - bob], fill=feet)
    # 袍子：窄肩、收腰、下襬微開
    d.polygon([(CX - 7, top), (CX + 7, top), (CX + 6, waist), (CX + 10, hem), (CX - 10, hem), (CX - 6, waist)], fill=robe)
    d.polygon([(CX - 7, top), (CX - 3, top), (CX - 3, waist), (CX - 5, hem), (CX - 10, hem), (CX - 6, waist)], fill=sh(robe, 1.15))
    d.polygon([(CX + 3, top), (CX + 7, top), (CX + 6, waist), (CX + 10, hem), (CX + 5, hem), (CX + 3, waist)], fill=sh(robe, 0.78))
    d.line([(CX, waist + 3), (CX - 1, hem - 2)], fill=sh(robe, 0.85))
    d.rectangle([CX - 10, hem - 2, CX + 10, hem], fill=sh(robe, 0.72))
    # 袖子與手（細）
    for sx in (-1, 1):
        d.polygon([(CX + sx * 7, top), (CX + sx * 10, top + 2), (CX + sx * 11, HAND_Y - bob - 2), (CX + sx * 8, HAND_Y - bob - 2)],
                  fill=sh(robe, 1.1 if sx < 0 else 0.8))
        d.ellipse([CX + sx * 10 - 2, HAND_Y - bob - 3, CX + sx * 10 + 2, HAND_Y - bob + 1], fill=skin)
    # 腰帶
    d.rectangle([CX - 6, waist - 2, CX + 6, waist], fill=sash)
    d.rectangle([CX + 2, waist - 1, CX + 4, waist + 4], fill=sh(sash, 0.85))
    # 脖子與頭（大）
    d.rectangle([CX - 2, top - 3, CX + 2, top], fill=sh(skin, 0.85))
    d.ellipse([CX - HEAD_R, hy - HEAD_R, CX + HEAD_R, hy + HEAD_R], fill=skin)
    d.pieslice([CX - HEAD_R, hy - HEAD_R, CX + HEAD_R, hy + HEAD_R], 300, 60, fill=sh(skin, 0.9))   # 右側暗面
    # 頭髮：比頭大一圈、有瀏海
    if not s["bald"]:
        d.pieslice([CX - HEAD_R - 2, hy - HEAD_R - 2, CX + HEAD_R + 2, hy + HEAD_R], 180, 360, fill=hair)
        d.pieslice([CX - HEAD_R - 2, hy - HEAD_R - 2, CX + HEAD_R + 2, hy + HEAD_R], 300, 360, fill=sh(hair, 0.75))
        for i, x in enumerate(range(CX - HEAD_R, CX + HEAD_R, 4)):   # 鋸齒瀏海
            d.polygon([(x, hy - 3), (x + 4, hy - 3), (x + 2, hy - (1 if i % 2 else 0))], fill=hair)
        d.rectangle([CX - HEAD_R - 2, hy - 3, CX - HEAD_R + 1, hy + 6], fill=hair)
        d.rectangle([CX + HEAD_R - 1, hy - 3, CX + HEAD_R + 2, hy + 6], fill=sh(hair, 0.75))
        d.line([(CX - 6, hy - HEAD_R + 1), (CX - 2, hy - HEAD_R)], fill=sh(hair, 1.3))   # 頭髮亮點
    else:
        d.ellipse([CX - 5, hy - HEAD_R + 2, CX, hy - HEAD_R + 5], fill=sh(skin, 1.15))
        d.rectangle([CX - HEAD_R, hy - 2, CX - HEAD_R + 2, hy + 4], fill=hair)
        d.rectangle([CX + HEAD_R - 2, hy - 2, CX + HEAD_R, hy + 4], fill=sh(hair, 0.75))
    if s["long"]:
        d.rectangle([CX - HEAD_R - 2, hy, CX - HEAD_R + 1, top + 6], fill=hair)
        d.rectangle([CX + HEAD_R - 1, hy, CX + HEAD_R + 2, top + 6], fill=sh(hair, 0.75))
    # 眼睛：有眼白的小眼睛（白底、深色瞳孔朝前）加眉毛與微笑，臉才有「人」的感覺；純黑點加空白臉會像恐怖遊戲
    brow = sh(hair if not s["bald"] else skin, 0.6)
    for ex in (CX - 8, CX + 3):
        d.rectangle([ex, hy + 1, ex + 4, hy + 5], fill=(250, 246, 238, 255))
        d.rectangle([ex + 1, hy + 2, ex + 3, hy + 5], fill=(58, 38, 30, 255))
        d.point((ex + 1, hy + 2), fill=(255, 255, 255, 255))
        d.line([(ex - 1, hy - 1), (ex + 5, hy - 2)], fill=brow, width=2)
    d.rectangle([CX - 11, hy + 7, CX - 9, hy + 8], fill=(238, 150, 140, 255))   # 淡淡的腮紅
    d.rectangle([CX + 9, hy + 7, CX + 11, hy + 8], fill=(238, 150, 140, 255))
    if s["beard"]:
        # 下巴的鬍子：上緣平直（不往臉頰翹），嘴巴在鬍子上方，才不會像咧嘴
        b = rgb(s["beard"])
        d.polygon([(CX - 7, hy + 10), (CX + 7, hy + 10), (CX + 6, hy + 12), (CX + 3, hy + 15), (CX - 3, hy + 15), (CX - 6, hy + 12)], fill=b)
        d.polygon([(CX + 3, hy + 10), (CX + 7, hy + 10), (CX + 6, hy + 12), (CX + 3, hy + 15)], fill=sh(b, 0.75))
    d.line([(CX - 3, hy + 9), (CX - 2, hy + 10), (CX + 2, hy + 10), (CX + 3, hy + 9)], fill=(170, 80, 70, 255), width=1)
    if evo:
        d.ellipse([CX - 9, hy - HEAD_R - 7, CX + 9, hy - HEAD_R - 2], outline=rgb("#ffd75e"), width=2)
    return im


def outline(im):
    """外框：用旁邊那個部位的深色（不是全黑），看起來比較柔"""
    src = im.copy()
    px = src.load()
    out = im.load()
    for y in range(H):
        for x in range(W):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and px[nx, ny][3]:
                    c = px[nx, ny]
                    out[x, y] = (int(c[0] * 0.35), int(c[1] * 0.3), int(c[2] * 0.35), 255)
                    break
    return im


def put_items(im, key, f):
    """手上的東西：舊的 14×17 設定圖放大 3 倍，對齊兩隻手與頭頂"""
    hy = HAND_Y - (1 if f == 1 else 0)
    for x, y, p in mp.items(key, f):
        if y <= 2 and 3 <= x <= 10:
            ax, ay, nx, ny = 6.5, 3, CX, 2
        elif x >= 10:
            ax, ay, nx, ny = 11, 11, CX + 13, hy
        elif x <= 2:
            ax, ay, nx, ny = 1, 11, CX - 13, hy
        else:
            ax, ay, nx, ny = 6.5, 11, CX, hy
        x0, y0 = int(nx + (x - ax) * 3), int(ny + (y - ay) * 3)
        for dx in range(3):
            for dy in range(3):
                if 0 <= x0 + dx < W and 0 <= y0 + dy < H:
                    im.putpixel((x0 + dx, y0 + dy), p)


def person(key, out_dir):
    s = mp.read_spec(key)
    for evo in (False, True):
        if evo and not os.path.exists(os.path.join(mp.SRC, key + "_evo_0.png")):
            continue
        for f in (0, 1):
            im = outline(body(s, f, evo))
            put_items(im, key, f)
            im.save(os.path.join(out_dir, "%s%s_%d.png" % (key, "_evo" if evo else "", f)))


if __name__ == "__main__":
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    for k in sys.argv[2:] or ["paul", "peter", "stephen"]:
        person(k, out_dir)
    print("done →", out_dir)
