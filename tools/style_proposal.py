"""史詩感風格提案的視覺示範（不進遊戲）：把基準截圖做「調色示範」並排成前後對比，另外畫配色板。
這只是氛圍示範，不是最後的美術：最後會改 tools/make_*.py 的素材與程式裡的色彩。
用法：python tools/style_proposal.py <基準截圖資料夾> <輸出資料夾>
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# 配色（名稱、色碼、用途）
PALETTE = [
    ("夜靛 Night Indigo", "#0b0d24", "背景暗部、陰影"),
    ("暮紫 Dusk Violet", "#2a2550", "中暗部、UI 底板"),
    ("青銅 Ember Bronze", "#8a5a48", "石牆、皮革、中間調"),
    ("帝金 Imperial Gold", "#e8b060", "主強調：光、勝利、重要文字"),
    ("象牙 Radiant Ivory", "#fff0c8", "最亮：高光、標題"),
    ("緋紅 Crimson", "#a8283c", "危險、敵意、血量"),
    ("聖藍 Holy Azure", "#5ab8e8", "聖靈、FEVER、特效冷光"),
    ("月桂 Laurel", "#6fbf73", "治療、生命"),
]
STOPS = [(0.0, "#0b0d24"), (0.28, "#2a2550"), (0.55, "#8a5a48"), (0.8, "#e8b060"), (1.0, "#fff0c8")]


def hex2rgb(h: str) -> np.ndarray:
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], dtype=float)


def grade(img: Image.Image) -> Image.Image:
    """史詩感調色：保留原本的色相與細節，只做『輕微壓暗 + 暗部偏靛 + 亮部偏金 + 提高飽和 + 暈邊』。
    不用漸層映射（會把所有顏色壓成同一條色帶、肤色變黑）、不用光暈模糊（會讓像素畫變糊）。"""
    rgb = img.convert("RGB")
    a = np.asarray(rgb, dtype=float) / 255.0
    lum = a @ np.array([0.299, 0.587, 0.114])
    hsv = np.asarray(rgb.convert("HSV"), dtype=float) / 255.0
    hue, sat, val = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    # 肤色保護：橘色相、中等飽和、不太暗 → 幾乎不調（只留下暈邊）
    skin = ((hue > 0.02) & (hue < 0.095) & (sat > 0.25) & (sat < 0.8) & (val > 0.45)).astype(float)
    skin = np.asarray(Image.fromarray((skin * 255).astype("uint8")).filter(ImageFilter.MaxFilter(3)), dtype=float)[..., None] / 255.0
    # 1) 輕微壓暗（保留色相與飽和）：lum ** 1.4 的倍率，暗處多壓一點
    scale = (np.clip(lum, 1e-4, 1) ** 1.4) / np.clip(lum, 1e-4, 1)
    out = a * scale[..., None]
    # 2) 暗部偏夜靛、亮部偏帝金（很輕）
    out = out + ((1 - lum) ** 2)[..., None] * (hex2rgb("#2a2a6a") / 255.0) * 0.16
    out = out + (lum ** 3)[..., None] * (hex2rgb("#e8b060") / 255.0) * 0.08
    # 3) 提高飽和
    g = out.mean(-1, keepdims=True)
    out = np.clip(g + (out - g) * 1.4, 0, 1)
    # 4) 肤色與其他部分混回原色
    out = out * (1 - skin * 0.9) + a * (0.97) * skin * 0.9
    # 5) 暈邊（輕）
    h, w = lum.shape
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
    out *= (1 - 0.42 * np.clip(r - 0.4, 0, 1) ** 1.3)[..., None]
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype("uint8"))


def font(size: int) -> ImageFont.FreeTypeFont:
    for p in ("C:/Windows/Fonts/msjh.ttc", "C:/Windows/Fonts/mingliu.ttc"):
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def pair(src: Path, dst: Path) -> None:
    a = Image.open(src).convert("RGB")
    b = grade(a)
    board = Image.new("RGB", (1280 + 12, 360), "#101018")
    board.paste(a, (0, 0))
    board.paste(b, (652, 0))
    d = ImageDraw.Draw(board)
    for x, t in ((8, "現在"), (660, "史詩感（調色示範）")):
        d.rectangle((x - 4, 4, x + 8 + 14 * len(t), 28), fill="#000000aa")
        d.text((x, 6), t, font=font(16), fill="#fff0c8")
    board.save(dst)


def palette_sheet(dst: Path) -> None:
    w, rh = 960, 64
    img = Image.new("RGB", (w, 56 + rh * len(PALETTE)), "#14141c")
    d = ImageDraw.Draw(img)
    d.text((16, 14), "史詩感配色（8 色，640×360 像素風內使用，另可用其間的漸層階）", font=font(20), fill="#fff0c8")
    for i, (name, hx, use) in enumerate(PALETTE):
        y = 56 + i * rh
        d.rectangle((16, y + 6, 136, y + rh - 6), fill=hx)
        d.text((152, y + 8), f"{name}  {hx}", font=font(18), fill="#fff0c8")
        d.text((152, y + 34), use, font=font(15), fill="#b8b4c8")
    img.save(dst)


def main(src_dir: str, out_dir: str) -> None:
    src, out = Path(src_dir), Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for i, name in enumerate(("bot_start", "bot_link", "bot_fever", "bot_cards", "free3_start"), 1):
        pair(src / f"{name}.png", out / f"compare_{i}_{name}.png")
    palette_sheet(out / "palette.png")
    print("done:", sorted(p.name for p in out.glob("*.png")))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
