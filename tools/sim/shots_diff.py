"""比對兩個截圖資料夾是否逐像素相同。
用法：python tools/sim/shots_diff.py <基準資料夾> <新資料夾>
基準裡有的檔案，新資料夾缺少也算失敗。UNSTABLE 列出的是機器人場景中提示橫幅會變動的畫面，
只比橫幅區域以外的像素。結構重構（階段 3–4、A）要求全部相同；風格階段不用這個。
"""
import sys
from pathlib import Path
from PIL import Image, ImageChops

# 已知會變動的區域（x0, y0, x1, y1）：提示橫幅
UNSTABLE = {"bot_hz.png": (100, 231, 540, 290), "bot_pause.png": (100, 231, 540, 290)}


def diff_count(a: Path, b: Path, mask: tuple[int, int, int, int] | None) -> int:
    ia, ib = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
    if ia.size != ib.size:
        return -1
    if mask:
        black = Image.new("RGB", (mask[2] - mask[0], mask[3] - mask[1]))
        ia, ib = ia.copy(), ib.copy()
        ia.paste(black, mask[:2])
        ib.paste(black, mask[:2])
    d = ImageChops.difference(ia, ib).convert("L").point(lambda v: 255 if v else 0)
    return d.histogram()[255]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    base, new = Path(sys.argv[1]), Path(sys.argv[2])
    fails = 0
    files = sorted(base.glob("*.png"))
    for f in files:
        g = new / f.name
        if not g.exists():
            print("MISSING", f.name)
            fails += 1
            continue
        n = diff_count(f, g, UNSTABLE.get(f.name))
        if n != 0:
            print("DIFF", f.name, "尺寸不同" if n < 0 else f"{n} 像素")
            fails += 1
    print(f"RESULT {'FAIL' if fails else 'PASS'}（{len(files)} 張，{fails} 張不同）")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
