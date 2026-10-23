"""過場的像素背景圖（assets/cuts/*.png，256×144、32 色）。

用 AI（Pollinations 的 FLUX，免費、不用金鑰）照 tools/cuts/prompts.json 畫成像素風的空場景（不畫人），
再用程式裁切、縮小、減色成跟遊戲一樣的大格子像素；人物由 title.gd 疊上遊戲裡的角色圖。
用法：python3 tools/make_cuts.py [場景 …]（需要網路可以連到 image.pollinations.ai）
注意：正式販售前要確認 Pollinations 與模型的使用條款允許商業使用。
"""
import json, os, subprocess, sys, time, urllib.parse
from PIL import Image, ImageEnhance, ImageFilter
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PX = "pixel art background, 16-bit SNES JRPG cutscene style, chunky large pixels, low resolution, limited 32 color palette, flat shading, wide shot, empty scene with no people, no characters, no text, "

import sys
from PIL import Image, ImageEnhance, ImageFilter
def pixelize(src, dst, w=320, colors=48):
    im=Image.open(src).convert("RGB")
    W,H=im.size; im=im.crop((0,0,W,int(H*0.93)))              # 去掉右下角浮水印那一條
    tw,th=w,int(w*9/16); r=max(tw/im.width, th/im.height)
    im=im.resize((round(im.width*r),round(im.height*r)),Image.LANCZOS)
    l=(im.width-tw)//2; t=(im.height-th)//2; im=im.crop((l,t,l+tw,t+th))
    im=ImageEnhance.Contrast(im).enhance(1.08); im=ImageEnhance.Color(im).enhance(1.1)
    im=im.filter(ImageFilter.UnsharpMask(1,60,2))
    im=im.quantize(colors=colors,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).convert("RGB")
    im.save(dst)
    im.resize((tw*4,th*4),Image.NEAREST).save(dst.replace(".png","_x4.png"))



def main():
    P = json.load(open(os.path.join(ROOT, "tools/cuts/prompts.json"), encoding="utf-8"))
    for k, (p, seed) in P.items():
        if sys.argv[1:] and k not in sys.argv[1:]:
            continue
        url = "https://image.pollinations.ai/prompt/" + urllib.parse.quote(PX + p) + "?width=1280&height=720&model=flux&nologo=true&seed=%d" % seed
        raw = os.path.join(ROOT, "build", "cut_%s.jpg" % k)
        os.makedirs(os.path.dirname(raw), exist_ok=True)
        for _ in range(3):
            r = subprocess.run(["curl", "-s", "-o", raw, "-w", "%{http_code}", "--max-time", "180", url], capture_output=True, text=True)
            if r.stdout == "200":
                break
            time.sleep(8)
        dst = os.path.join(ROOT, "assets/cuts/%s.png" % k)
        pixelize(raw, dst, w=256, colors=32)
        os.remove(dst.replace(".png", "_x4.png"))
        print(k, r.stdout)


if __name__ == "__main__":
    main()
